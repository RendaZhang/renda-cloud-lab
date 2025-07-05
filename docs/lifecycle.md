# ☁️ EKS 云原生集群生命周期流程文档 (EKS Cluster Lifecycle Guide)

* Last Updated: June 28, 2025, 19:30 (UTC+8)
* 作者: 张人大（Renda Zhang）

本项目以 Terraform 为核心管理工具，配合一次性的 eksctl 集群创建和 Bash 脚本，完成 EKS 集群的每日销毁与重建流程，并自动恢复关键运行时配置（如 Spot Interruption SNS 通知绑定）。集群首次可由 eksctl 创建，随后通过 `scripts/tf-import.sh` 导入到 Terraform 管理，日常操作均由 Terraform 与脚本完成。本文档记录从初始化到销毁的全生命周期操作流程，适用于开发、测试和生产演练场景。

This guide documents the entire lifecycle of an EKS cluster, including daily teardown and rebuild automation via Terraform, eksctl and Bash scripts. It explains how to restore critical runtime configuration such as Spot Interruption SNS bindings. The workflow is suitable for development, testing and production experiments.

---

## 🛠 准备工作 (Preparation)

### ✅ 本地依赖要求 (Local Requirements)

请先确保本地已安装如下工具：

| 工具        | 说明             |
| --------- | -------------- |
| AWS CLI   | 用于账户授权与状态查询    |
| Terraform | IaC 主引擎，管理资源声明 |
| eksctl    | EKS 控制面辅助工具    |
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

> 可通过 `make all` 一键执行

```bash
make all
```

等价于手动执行：

1. 启动基础设施（NAT + ALB + EKS）

```bash
make start
```

> Terraform 模块 `eks` 会自动启用控制面日志（`api`、`authenticator`），不再需要
> 手动执行 `eksctl utils update-cluster-logging`。

2. 自动为 ASG 绑定 Spot Interruption SNS 通知

```bash
make post-recreate
```

该脚本具备：

* 自动识别当前 ASG 名称
* 防重复绑定（本地记录 `.last-asg-bound`）
* 更新本地的 kubeconfig
* 通过 Helm 安装或升级 cluster-autoscaler
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
```

> 该操作不会删除 VPC、Route Table、KMS 等基础结构

---

## 💣 一键彻底销毁所有资源 (Full Teardown)

适用于彻底重建或环境迁移：

```bash
make destroy-all
```

> 将先运行 `make stop-hard` 删除 EKS 控制面，随后执行 `terraform destroy` 清理所有基础设施 (first runs `make stop-hard` to remove the EKS control plane, then calls `terraform destroy` to delete all resources)

---

## 📜 查看日志与清理状态 (Logs and Cleanup)

### 查看最近执行日志 (Recent Logs)

```bash
make logs
```

### 清理状态缓存文件（可选） (Clean Cached State)

```bash
make clean
```

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
* 整合 GitHub Actions 自动执行 `make all`
