# 📝 eksctl Legacy Guide (eksctl 旧版指引)

* **Last Updated:** July 6, 2025, 15:20 (UTC+8)
* **作者:** 张人大（Renda Zhang）

## ⚠️ About This Document (文档说明)

Terraform 是對于 EKS 集群的首选管理方式。此文档记录在 `create_eks=false` 时如何使用 eksctl 手动创建 EKS 集群并将其导入 Terraform。普通时只需直接使用 Terraform 即可。

Terraform is the recommended tool to manage the EKS cluster. This document explains how to create a cluster with eksctl and import it into Terraform when `create_eks=false`. Use this method only for legacy or experimental scenarios.

## 1. 创建集群 (Create the Cluster)

```bash
eksctl create cluster -f infra/eksctl/eksctl-cluster.yaml --profile phase2-sso
```

> eksctl 会生成额外的 CloudFormation 栈，删除集群时请手动清理。

## 2. 导入 Terraform (Import to Terraform)

```bash
bash scripts/tf-import.sh
```

该脚本会将 EKS 控制平面、管理节点组、OIDC 提供商以及 IRSA 等资源导入 Terraform 状态，以便之后统一管理。

This script imports the EKS control plane, managed node groups, OIDC provider and predefined IRSA roles so that Terraform can manage them consistently.

## 3. 清理 CloudFormation 栈 (Clean up Stacks)

```bash
aws cloudformation delete-stack --stack-name eksctl-dev-nodegroup-ng-mixed --region us-east-1 --profile phase2-sso
aws cloudformation delete-stack --stack-name eksctl-dev-addon-vpc-cni --region us-east-1 --profile phase2-sso
aws cloudformation delete-stack --stack-name eksctl-dev-cluster --region us-east-1 --profile phase2-sso
```

## FAQ

- **为什么仍保留 `infra/eksctl` 目录？ (Why keep `infra/eksctl`?)**
  由于历史原因和多样化使用场景，该目录依然存在，以便在必要时使用 eksctl 手动创集群并导入 Terraform。
  Terraform 已能全面创建和销毁 EKS，常见无需再依赖 eksctl。
