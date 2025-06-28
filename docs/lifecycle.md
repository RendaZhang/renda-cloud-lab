# ☁️ EKS 云原生集群生命周期流程文档

本项目支持使用 Terraform + eksctl + Bash 脚本统一管理 EKS 集群的每日销毁与重建流程，并自动恢复关键运行时配置（如 Spot Interruption SNS 通知绑定）。本文件记录从初始化到销毁的全生命周期操作流程，适用于开发、测试和生产演练场景。

---

## 🛠 准备工作

### ✅ 本地依赖要求

请先确保本地已安装如下工具：

| 工具        | 说明             |
| --------- | -------------- |
| AWS CLI   | 用于账户授权与状态查询    |
| Terraform | IaC 主引擎，管理资源声明 |
| eksctl    | EKS 控制面辅助工具    |
| Helm      | 可选，管理集群内组件     |

执行以下命令检查工具：

```bash
make check
```

### ✅ AWS SSO 登录

使用以下命令登录 AWS：

```bash
aws sso login --profile phase2-sso
```

---

## ☀ 集群每日重建流程

> 可通过 `make all` 一键执行

```bash
make all
```

等价于手动执行：

1. 启动基础设施（NAT + ALB + EKS）

```bash
make start
```

2. 使用 `eksctl` 创建控制面（仅首次）

```bash
make start-cluster
```

3. 自动为 ASG 绑定 Spot Interruption SNS 通知

```bash
make post-recreate
```

该脚本具备：

* 自动识别当前 ASG 名称
* 防重复绑定（本地记录 `.last-asg-bound`）
* 日志输出到 `scripts/logs/post-recreate.log`

---

## 🌙 日常关闭资源以节省成本

若你只需暂时关闭资源：

```bash
make stop
```

> 该操作不会删除 VPC、Route Table、KMS 等基础结构

---

## 💣 一键彻底销毁所有资源

适用于彻底重建或环境迁移：

```bash
make destroy-all
```

> 会同时调用 `eksctl delete cluster` 与 `terraform destroy`

---

## 📜 查看日志与清理状态

### 查看最近执行日志：

```bash
make logs
```

### 清理状态缓存文件（可选）：

```bash
make clean
```

---

## 🔁 脚本自动化逻辑说明（post-recreate.sh）

核心路径：`scripts/post-recreate.sh`

* 自动查找当前 ASG 名称（以 `eks-ng-mixed` 为前缀）
* 若尚未绑定 SNS 通知，则绑定：

  * `autoscaling:EC2_INSTANCE_TERMINATE`
  * SNS Topic：`spot-interruption-topic`
* 状态记录：`scripts/.last-asg-bound`
* 日志：`scripts/logs/post-recreate.log`

---

## ✅ 推荐 gitignore 配置

```gitignore
scripts/.last-asg-bound
scripts/logs/*
!scripts/logs/.gitkeep
```

---

## 📦 后续规划（可选）

* 将 SNS Topic 与 Budget 也纳入 Terraform 管理
* 支持通知绑定覆盖多个 NodeGroup
* 整合 GitHub Actions 自动执行 `make all`
