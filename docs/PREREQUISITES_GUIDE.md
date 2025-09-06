<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
## 目录 (Table of Contents)

- [前置条件操作指南](#%E5%89%8D%E7%BD%AE%E6%9D%A1%E4%BB%B6%E6%93%8D%E4%BD%9C%E6%8C%87%E5%8D%97)
  - [前置条件](#%E5%89%8D%E7%BD%AE%E6%9D%A1%E4%BB%B6)
  - [AWS 账户及 CLI 配置](#aws-%E8%B4%A6%E6%88%B7%E5%8F%8A-cli-%E9%85%8D%E7%BD%AE)
  - [Terraform 后端设置](#terraform-%E5%90%8E%E7%AB%AF%E8%AE%BE%E7%BD%AE)
  - [DNS 域名（可选）](#dns-%E5%9F%9F%E5%90%8D%E5%8F%AF%E9%80%89)
  - [本地环境检查](#%E6%9C%AC%E5%9C%B0%E7%8E%AF%E5%A2%83%E6%A3%80%E6%9F%A5)
  - [运行预检脚本](#%E8%BF%90%E8%A1%8C%E9%A2%84%E6%A3%80%E8%84%9A%E6%9C%AC)
  - [AWS SSO 登录](#aws-sso-%E7%99%BB%E5%BD%95)
  - [Kubernetes 命名空间](#kubernetes-%E5%91%BD%E5%90%8D%E7%A9%BA%E9%97%B4)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# 前置条件操作指南

- **Last Updated:** August 28, 2025, 21:50 (UTC+8)
- **作者:** 张人大（Renda Zhang）

本文档整理了部署 **Renda Cloud Lab** 之前需要完成的准备工作，以便顺利运行 Terraform 与脚本。

---

## 前置条件

在开始部署之前，请确保满足以下前置条件：

- **AWS 账户及权限**：拥有可用的 AWS 账户，并已安装并配置 AWS CLI（例如通过 `aws configure` 或 AWS SSO 登录）。**本项目默认使用 AWS CLI 的 SSO Profile 名称 `phase2-sso`，默认区域为 `us-east-1`**，如与你的配置不同请相应调整后续命令。
- **Terraform 后端**：提前创建用于 Terraform 状态存储的 S3 Bucket 及 DynamoDB 锁定表，并在 `infra/aws/backend.tf` 中相应配置名称。默认假定 S3 Bucket 名为 `phase2-tf-state-us-east-1`，DynamoDB 表名为 `tf-state-lock`（可根据需要修改）。
- **DNS 域名**（可选）：若希望通过自定义域名访问服务，可在 Route 53 或其他 DNS 提供商中提前创建 Hosted Zone。集群启动并由 ALB Controller 创建 ALB 后，需要手动在该 Hosted Zone 中创建一条指向 ALB DNS 的 A 记录（Alias）。若不需要自定义域名，可直接使用 ALB 自动分配的域名。
- **本地环境**：安装 Terraform (~1.8+)、kubectl 以及 Helm 等必要的命令行工具，同时安装 Git 和 Make 等基础工具。
- **预检脚本**：可运行 `preflight.sh` 来检查关键 Service Quota 配额和环境依赖（未来将扩展检查 AWS CLI / Terraform / Helm 等工具链的版本与状态）。执行 `bash scripts/preflight.sh` 或 `make preflight` 可开始预检。
- **AWS SSO 登录**：在运行 Terraform 或脚本前，请执行 `make aws-login` 获取临时凭证。

---

## AWS 账户及 CLI 配置

1. 安装 [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)。
2. 通过 `aws configure sso` 或 `aws configure` 配置凭证，推荐使用 AWS SSO。
3. 创建名为 `phase2-sso` 的默认 Profile，并设置 Region `us-east-1`。

---

## Terraform 后端设置

> 先手动创建一次，之后所有环境都能复用同一个桶 / 表。

1. **创建 S3 Bucket**
   - 登录 **S3 Console → Create bucket**
   - **Bucket name**：`phase2-tf-state-us-east-1`
     * 名字全局唯一，可加 GitHub 用户名或日期后缀避免重名。
   - **Region**：`us-east-1`
   - 保持 **Block all public access** 全部勾选 ✅
   - **Object Ownership**：`ACLs disabled` + `Bucket owner preferred`
   - 启用 **Versioning** 以便回滚旧状态
   - 其他保持默认设置，点击 **Create bucket**
2. **创建 DynamoDB 表（用于锁）**
   - 进入 **DynamoDB Console → Tables → Create table**
   - **Table name**：`tf-state-lock`
   - **Partition key**：`LockID` (String)
   - **Capacity mode**：`On-demand` (PAY_PER_REQUEST)
   - 其余保持默认，点击 **Create table**
3. 在 `infra/aws/backend.tf` 中填入上述 Bucket 与表名后再执行 `terraform init`。

---

## DNS 域名（可选）

本项目不再由 Terraform 管理 Route 53。若需自定义域名，可在 Route 53 创建 Hosted Zone，并在 ALB Controller 生成 ALB 后，创建一条指向该 ALB DNS 的 A 记录（Alias）。如不设置自定义域名，可直接使用 ALB 自动分配的域名。

---

## 本地环境检查

需要安装以下工具：

Terraform (≥1.8)、kubectl、Helm、Git、Make。

可运行 `make check-auto` 自动安装缺失工具。

本项目推荐在以下环境中运行：

| 平台类型 | 是否支持 | 安装方式说明 |
| ------------------------- | ---------- | --------------- |
| macOS (Intel/ARM) | ✅ 支持 | Homebrew 自动安装 |
| Windows WSL2 (Ubuntu) | ✅ 支持 | apt / curl 自动安装 |
| Ubuntu/Debian Linux | ✅ 支持 | apt / curl 自动安装 |
| 原生 Windows CMD/Powershell | ❌ 不支持 | 请使用 WSL 运行 |
| Arch/Fedora 等 | ❌ 不支持 | 需手动安装所有工具 |

执行环境初始化建议：

```bash
make check         # 交互式检查并安装 CLI 工具
make check-auto    # 自动安装全部缺失工具（无提示）
# 日志输出位于 scripts/logs/check-tools.log
```

---

## 运行预检脚本

检查 AWS 配额及工具链是否满足要求。

在首次部署或每次更换终端/电脑时，可先执行预检脚本：

```bash
# 一键预检环境和配额
make preflight   # 等同于 bash scripts/preflight.sh
```

---

## AWS SSO 登录

在执行 Terraform 或脚本前，运行 `make aws-login` 获取临时凭证。

---

## Kubernetes 命名空间

项目中默认使用以下 Kubernetes 命名空间：

| Namespace     | 作用                                                         |
| ------------- | ------------------------------------------------------------ |
| `kube-system` | 集群核心组件所在命名空间，如 Cluster Autoscaler 与 ALB 控制器 |
| `observability` | 用于可观测性组件，例如 ADOT Collector                      |
| `svc-task`    | 示例应用 `task-api` 的运行命名空间                            |

首次部署时请确认上述命名空间已存在。若缺失，可执行 `kubectl create namespace <name>` 手动创建。
