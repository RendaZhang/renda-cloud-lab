#!/usr/bin/env bash

set -euo pipefail

export CLUSTER_NAME=dev
export REGION=us-east-1

NG_NAME=$(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --region "$REGION" \
               --query 'nodegroups[0]' --output text --profile phase2-sso)
export NG_NAME

OIDC_ACCOUNT=$(aws sts get-caller-identity --query Account --output text --profile phase2-sso)
OIDC_ARN=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" \
                 --query 'cluster.identity.oidc.issuer' --output text \
                 --profile phase2-sso | sed -e "s|https://||")
export OIDC_ARN="arn:aws:iam::${OIDC_ACCOUNT}:oidc-provider/${OIDC_ARN}"
# Customer Managed Policy, 手动创建的需要使用完整 ARN 而不是名字
export POLICY_ARN="arn:aws:iam::563149051155:policy/EKSClusterAutoscalerPolicy"

# cluster
terraform import 'module.eks.aws_eks_cluster.this[0]' "$CLUSTER_NAME"

# nodegroup
terraform import 'module.eks.aws_eks_node_group.ng[0]' "${CLUSTER_NAME}:${NG_NAME}"

# OIDC provider
terraform import 'module.eks.aws_iam_openid_connect_provider.oidc[0]' "$OIDC_ARN"

# 导入 IAM Role 本体
terraform import module.irsa.aws_iam_role.eks_cluster_autoscaler eks-cluster-autoscaler

# 导入 IAM Role 上的 Policy 
terraform import module.irsa.aws_iam_role_policy_attachment.cluster_autoscaler_attach "eks-cluster-autoscaler/$POLICY_ARN"
