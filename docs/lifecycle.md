# ☁️ EKS 云原生集群生命周期流程文档 (EKS Cluster Lifecycle Guide)

* Last Updated: July 6, 2025, 15:20 (UTC+8)
* 作者: 张人大（Renda Zhang）

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
* 自动识别当前 ASG 名称
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

> 该操作不会删除 VPC、Route Table、KMS 等基础结构；`stop-all` 会在销毁集群后额外执行 `scripts/post-teardown.sh` 清理 EKS CloudWatch 日志组

---

## 💣 一键彻底销毁所有资源 (Full Teardown)

适用于彻底重建或环境迁移：

```bash
make destroy-all
```

> 将先运行 `make stop-hard` 删除 EKS 控制面，随后执行 `terraform destroy` 清理所有基础设施，并在最后调用 `post-teardown.sh` 删除 CloudWatch 日志组 (first runs `make stop-hard` to remove the EKS control plane, then calls `terraform destroy` followed by `post-teardown.sh` to delete the log group)

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
* 自动查找当前 ASG 名称（以 `eks-ng-mixed` 为前缀）
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

* 将 SNS Topic 与 Budget 也纳入 Terraform 管理
* 支持通知绑定覆盖多个 NodeGroup
* 整合 GitHub Actions 自动执行 `make start-all`
