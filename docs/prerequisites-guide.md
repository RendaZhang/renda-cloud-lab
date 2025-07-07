# 前置条件操作指南 (Prerequisites Setup Guide)

* **Last Updated:** July 6, 2025, 23:50 (UTC+8)
* **作者:** 张人大（Renda Zhang）

本文档整理了部署 **Renda Cloud Lab** 之前需要完成的准备工作，以便顺利运行 Terraform 与脚本。
This document provides the step-by-step prerequisites for deploying **Renda Cloud Lab**, including AWS setup and local tool installation.

---

## 1. AWS 账户及 CLI 配置 (AWS Account & CLI)

1. 安装 [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)。
2. 通过 `aws configure sso` 或 `aws configure` 配置凭证，推荐使用 AWS SSO。
3. 创建名为 `phase2-sso` 的默认 Profile，并设置 Region `us-east-1`。

## 2. Terraform 后端设置 (Terraform Backend Setup)

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

## 3. DNS 域名（可选）(DNS Domain Optional)

若希望使用自定义域名访问服务，请在 Route 53 创建 Hosted Zone，
并在 Terraform 配置中将默认域 `lab.rendazhang.com` 改为你的域名。未设置时可直接使用 ALB 自动分配的域名。

## 4. 本地环境准备 (Local Environment)

安装以下工具：Terraform (≥1.8)、kubectl、Helm、Git、Make。可运行 `make check-auto` 自动安装缺失工具。

## 5. 运行预检脚本 (Run Preflight Script)

执行 `bash scripts/preflight.sh` 或 `make preflight`，检查 AWS 配额及工具链是否满足要求。

## 6. AWS SSO 登录 (AWS SSO Login)

在执行 Terraform 或脚本前，运行 `make aws-login` 获取临时凭证。
