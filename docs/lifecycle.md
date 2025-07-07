<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
## 目录 (Table of Contents)

-  [☁️ EKS 云原生集群生命周期流程文档 (EKS Cluster Lifecycle Guide)](#-eks-%E4%BA%91%E5%8E%9F%E7%94%9F%E9%9B%86%E7%BE%A4%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E6%B5%81%E7%A8%8B%E6%96%87%E6%A1%A3-eks-cluster-lifecycle-guide)
  -  [🛠 准备工作 (Preparation)](#-%E5%87%86%E5%A4%87%E5%B7%A5%E4%BD%9C-preparation)
    -  [✅ 本地依赖要求 (Local Requirements)](#-%E6%9C%AC%E5%9C%B0%E4%BE%9D%E8%B5%96%E8%A6%81%E6%B1%82-local-requirements)
    -  [✅ AWS SSO 登录 (AWS SSO Login)](#-aws-sso-%E7%99%BB%E5%BD%95-aws-sso-login)
  -  [☀ 集群每日重建流程 (Daily Rebuild Steps)](#-%E9%9B%86%E7%BE%A4%E6%AF%8F%E6%97%A5%E9%87%8D%E5%BB%BA%E6%B5%81%E7%A8%8B-daily-rebuild-steps)
  -  [🌙 日常关闭资源以节省成本 (Stopping Resources for Cost Saving)](#-%E6%97%A5%E5%B8%B8%E5%85%B3%E9%97%AD%E8%B5%84%E6%BA%90%E4%BB%A5%E8%8A%82%E7%9C%81%E6%88%90%E6%9C%AC-stopping-resources-for-cost-saving)
  -  [💣 一键彻底销毁所有资源 (Full Teardown)](#-%E4%B8%80%E9%94%AE%E5%BD%BB%E5%BA%95%E9%94%80%E6%AF%81%E6%89%80%E6%9C%89%E8%B5%84%E6%BA%90-full-teardown)
  -  [📜 查看日志与清理状态 (Logs and Cleanup)](#-%E6%9F%A5%E7%9C%8B%E6%97%A5%E5%BF%97%E4%B8%8E%E6%B8%85%E7%90%86%E7%8A%B6%E6%80%81-logs-and-cleanup)
    -  [查看最近执行日志 (Recent Logs)](#%E6%9F%A5%E7%9C%8B%E6%9C%80%E8%BF%91%E6%89%A7%E8%A1%8C%E6%97%A5%E5%BF%97-recent-logs)
    -  [清理状态缓存文件（可选） (Clean Cached State)](#%E6%B8%85%E7%90%86%E7%8A%B6%E6%80%81%E7%BC%93%E5%AD%98%E6%96%87%E4%BB%B6%E5%8F%AF%E9%80%89-clean-cached-state)
  -  [该指令将删除 `.last-asg-bound` 缓存、清空 `scripts/logs/` 下的所有
日志以及计划文件，保持目录整洁。](#%E8%AF%A5%E6%8C%87%E4%BB%A4%E5%B0%86%E5%88%A0%E9%99%A4-last-asg-bound-%E7%BC%93%E5%AD%98%E6%B8%85%E7%A9%BA-scriptslogs-%E4%B8%8B%E7%9A%84%E6%89%80%E6%9C%89%0A%E6%97%A5%E5%BF%97%E4%BB%A5%E5%8F%8A%E8%AE%A1%E5%88%92%E6%96%87%E4%BB%B6%E4%BF%9D%E6%8C%81%E7%9B%AE%E5%BD%95%E6%95%B4%E6%B4%81)
  -  [🔁 脚本自动化逻辑说明（post-recreate.sh） (Automation Logic)](#-%E8%84%9A%E6%9C%AC%E8%87%AA%E5%8A%A8%E5%8C%96%E9%80%BB%E8%BE%91%E8%AF%B4%E6%98%8Epost-recreatesh-automation-logic)
  -  [✅ 推荐 gitignore 配置 (Recommended gitignore)](#-%E6%8E%A8%E8%8D%90-gitignore-%E9%85%8D%E7%BD%AE-recommended-gitignore)
  -  [📦 后续规划（可选） (Future Work)](#-%E5%90%8E%E7%BB%AD%E8%A7%84%E5%88%92%E5%8F%AF%E9%80%89-future-work)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# ☁️ EKS 云原生集群生命周期流程文档 (EKS Cluster Lifecycle Guide)

* **Last Updated:** July 6, 2025, 22:20 (UTC+8)
* **作者:** 张人大（Renda Zhang）

本项目以 Terraform 为核心管理工具，配合 Bash 脚本完成 EKS 集群的每日销毁与重建，并自动恢复关键运行时配置（如 Spot Interruption SNS 通知绑定）。本文档记录从初始化到销毁的全生命周期操作流程，适用于开发、测试和生产演练场景。

This guide documents the entire lifecycle of an EKS cluster, including daily teardown and rebuild automation via Terraform and Bash scripts. It explains how to restore critical runtime configuration such as Spot Interruption SNS bindings. The workflow is suitable for development, testing and production experiments.

---

## 🛠 准备工作 (Preparation)

### ✅ 本地依赖要求 (Local Requirements)

请先确保本地已安装如下工具：

| 工具        | 说明             |
| --------- | -------------- |
| AWS CLI   | 用于账户授权与状态查询    |
| Terraform | IaC 主引擎，管理资源声明 |
| Helm      | 可选，管理集群内组件     |

执行以下命令检查并按需安装 CLI 工具：

```bash
make check
# 或跳过提示直接安装
make check-auto
```

### ✅ AWS SSO 登录 (AWS SSO Login)

使用以下命令登录 AWS：

```bash
make aws-login
```

---

## ☀ 集群每日重建流程 (Daily Rebuild Steps)

> 可通过 `make start-all` 一键执行

```bash
make start-all
```

首次使用前，请先在 AWS Console 或通过下列命令创建 `spot-interruption-topic` 并订阅邮箱 (create once before the first run):

```bash
aws sns create-topic --name spot-interruption-topic \
  --profile phase2-sso --region us-east-1 \
  --output text --query 'TopicArn'
export SPOT_TOPIC_ARN=arn:aws:sns:us-east-1:123456789012:spot-interruption-topic
aws sns subscribe --topic-arn $SPOT_TOPIC_ARN \
  --protocol email --notification-endpoint you@example.com \
  --profile phase2-sso --region us-east-1
```

打开邮箱确认订阅即可。之后执行 `make post-recreate` 会自动将最新的 NodeGroup ASG 绑定到该主题。

等价于手动执行：

1. 启动基础设施（NAT + ALB + EKS）

```bash
make start
```

> Terraform 模块 `eks` 会自动启用控制面日志（`api`、`authenticator`），无需额外命令。

2. 运行 Spot 通知自动绑定并刷新本地 kubeconfig 以及使用 Helm 部署

```bash
make post-recreate
```

该脚本具备：

* 更新本地的 kubeconfig
* 通过 Helm 安装或升级 cluster-autoscaler
* 自动识别当前 ASG 名称并绑定 SNS 通知
* 检查 NAT 网关、ALB、EKS 控制平面、节点组及日志组状态
* 防重复绑定（本地记录 `.last-asg-bound`）
* 日志输出到 `scripts/logs/post-recreate.log`

---

## 🌙 日常关闭资源以节省成本 (Stopping Resources for Cost Saving)

若你只需暂时关闭资源：

```bash
# 删除 NAT 和 ALB，保留 EKS 集群运行
make stop
# 或者：
# 删除 NAT 和 ALB 以及 EKS 集群
make stop-hard
# 若同时需要清理 EKS CloudWatch 日志组
make stop-all
```

> 该操作不会删除 VPC、Route Table、KMS 等基础结构；`stop-all` 会在销毁集群后额外执行 `scripts/post-teardown.sh` 清理日志组并检查 NAT 网关、ALB、EKS 等资源是否完全移除

---

## 💣 一键彻底销毁所有资源 (Full Teardown)

适用于彻底重建或环境迁移：

```bash
make destroy-all
```

> 将先运行 `make stop-hard` 删除 EKS 控制面，随后执行 `terraform destroy` 清理所有基础设施，并在最后调用 `post-teardown.sh` 删除日志组并验证资源删除情况 (first runs `make stop-hard` to remove the EKS control plane, then calls `terraform destroy` followed by `post-teardown.sh` to delete the log group and run final checks)

---

## 📜 查看日志与清理状态 (Logs and Cleanup)

### 查看最近执行日志 (Recent Logs)

```bash
make logs
```

该命令会自动列出 `scripts/logs/` 目录下的最近文件，并依次显示
`post-recreate.log`、`preflight.txt`、`check-tools.log` 等日志的最后
10 行，便于排查问题。

### 清理状态缓存文件（可选） (Clean Cached State)

```bash
make clean
```
该指令将删除 `.last-asg-bound` 缓存、清空 `scripts/logs/` 下的所有
日志以及计划文件，保持目录整洁。
---

## 🔁 脚本自动化逻辑说明（post-recreate.sh） (Automation Logic)

核心路径：`scripts/post-recreate.sh`

* 更新 kubeconfig 以连接 EKS 集群
* 自动安装/升级 cluster-autoscaler (Helm)
* 自动查找当前 ASG 名称（以 `eks-ng-mixed` 为前缀）并检查 SNS 通知绑定
* 验证 NAT 网关、ALB、EKS 控制面、节点组和日志组状态
* 若尚未绑定 SNS 通知，则绑定：
  * `autoscaling:EC2_INSTANCE_TERMINATE`
  * SNS Topic：`spot-interruption-topic`
* 状态记录：`scripts/.last-asg-bound`
* 日志：`scripts/logs/post-recreate.log`

---

## ✅ 推荐 gitignore 配置 (Recommended gitignore)

```gitignore
scripts/.last-asg-bound
scripts/logs/*
!scripts/logs/.gitkeep
```

---

## 📦 后续规划（可选） (Future Work)

* 支持通知绑定覆盖多个 NodeGroup
* 整合 GitHub Actions 自动执行 `make start-all`
