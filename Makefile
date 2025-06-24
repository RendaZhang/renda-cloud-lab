AWS_PROFILE = phase2-sso
TF_DIR      = infra/aws
REGION      = us-east-1

.PHONY:  start stop stop-hard plan

## ▶ 显示当前计划
plan:
	aws sso login --profile $(AWS_PROFILE)
	terraform -chdir=$(TF_DIR) plan -var="region=$(REGION)" -var="create_nat=true" -var="create_alb=true" -var="create_eks=false"

## ☀ 早上：重建 NAT + ALB（EKS 目前 false；等 Day 2 再打开）
start:
	aws sso login --profile $(AWS_PROFILE)
	terraform -chdir=$(TF_DIR) apply -auto-approve -var="region=$(REGION)" -var="create_nat=true" -var="create_alb=true" -var="create_eks=false"

## 🌙 晚上：销毁 NAT + ALB（保留 VPC、锁表、State）
stop:
	terraform -chdir=$(TF_DIR) apply -auto-approve -var="region=$(REGION)" -var="create_nat=false" -var="create_alb=false" -var="create_eks=false"

## ☠️ 假期：连同 EKS 控制面 & 节点都删光
stop-hard: stop
	eksctl delete cluster --name dev --region $(REGION) || true
