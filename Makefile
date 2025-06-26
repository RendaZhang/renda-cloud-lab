AWS_PROFILE = phase2-sso
TF_DIR      = infra/aws
REGION      = us-east-1
EKSCTL_YAML = infra/eksctl/eksctl-cluster.yaml
CLUSTER     = dev

.PHONY:  preflight init start stop stop-hard plan

## 🛠️ 预检脚本：关键 Service Quota、检查 AWS CLI、Terraform、EKSCTL
preflight:
	bash scripts/preflight.sh

## 🧰 初始化 Terraform
init:
	@echo "Initializing Terraform..."
	terraform -chdir=$(TF_DIR) init -reconfigure

## ▶ 显示当前计划
plan:
	@echo "Planning Terraform changes..."
	aws sso login --profile $(AWS_PROFILE)
	terraform -chdir=$(TF_DIR) plan -var="region=$(REGION)" -var="create_nat=true" -var="create_alb=true" -var="create_eks=false"

## ☀ 早上：重建 NAT + ALB（EKS 目前 false；等 Day 2 再打开）
start:
	@echo "Applying Terraform changes to start NAT and ALB..."
	terraform -chdir=$(TF_DIR) apply -auto-approve -var="region=$(REGION)" -var="create_nat=true" -var="create_alb=true" -var="create_eks=false"

## 🌄 放假回来：创建 EKS 集群（使用 eksctl）
start-cluster:
	@echo "Creating EKS cluster..."
	aws sso login --profile $(AWS_PROFILE)
	eksctl create cluster -f $(EKSCTL_YAML) --profile $(AWS_PROFILE) --region $(REGION) --kubeconfig ~/.kube/config

## 🌙 晚上：销毁 NAT + ALB（保留 VPC、锁表、State）
stop:
	@echo "Applying Terraform changes to stop NAT and ALB..."
	terraform -chdir=$(TF_DIR) apply -auto-approve -var="region=$(REGION)" -var="create_nat=false" -var="create_alb=false" -var="create_eks=false"

## ☠️ 假期：连同 EKS 控制面 & 节点都删光
stop-hard: stop
	@echo "Destroying EKS resources..."
	eksctl delete cluster --name $(CLUSTER) --region $(REGION) --profile $(AWS_PROFILE) || true
