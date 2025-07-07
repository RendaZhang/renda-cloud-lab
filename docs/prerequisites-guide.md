<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
## 目录 (Table of Contents)

- [前置条件操作指南 (Prerequisites Setup Guide)](#%E5%89%8D%E7%BD%AE%E6%9D%A1%E4%BB%B6%E6%93%8D%E4%BD%9C%E6%8C%87%E5%8D%97-prerequisites-setup-guide)
  - [1. AWS 账户及 CLI 配置 (AWS Account & CLI)](#1-aws-%E8%B4%A6%E6%88%B7%E5%8F%8A-cli-%E9%85%8D%E7%BD%AE-aws-account--cli)
  - [2. Terraform 后端设置 (Terraform Backend Setup)](#2-terraform-%E5%90%8E%E7%AB%AF%E8%AE%BE%E7%BD%AE-terraform-backend-setup)
  - [3. DNS 域名（可选）(DNS Domain Optional)](#3-dns-%E5%9F%9F%E5%90%8D%E5%8F%AF%E9%80%89dns-domain-optional)
  - [4. 本地环境准备 (Local Environment)](#4-%E6%9C%AC%E5%9C%B0%E7%8E%AF%E5%A2%83%E5%87%86%E5%A4%87-local-environment)
  - [5. 运行预检脚本 (Run Preflight Script)](#5-%E8%BF%90%E8%A1%8C%E9%A2%84%E6%A3%80%E8%84%9A%E6%9C%AC-run-preflight-script)
  - [6. AWS SSO 登录 (AWS SSO Login)](#6-aws-sso-%E7%99%BB%E5%BD%95-aws-sso-login)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

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
