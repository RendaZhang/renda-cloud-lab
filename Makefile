AWS_PROFILE = phase2-sso
TF_DIR      = infra/aws
REGION      = us-east-1
EKSCTL_YAML = infra/eksctl/eksctl-cluster.yaml
CLUSTER     = dev

.PHONY: preflight init plan start start-cluster post-recreate stop stop-cluster stop-hard all destroy-all check logs clean

## 🛠️ 环境检查（工具版本、路径等）
check:
	@echo "🔎 检查 CLI 工具链状态..."
	@command -v aws >/dev/null      || (echo "❌ AWS CLI 未安装" && exit 1)
	@command -v terraform >/dev/null || (echo "❌ Terraform 未安装" && exit 1)
	@command -v eksctl >/dev/null    || (echo "❌ eksctl 未安装" && exit 1)
	@command -v helm >/dev/null      || (echo "❌ Helm 未安装" && exit 1)
	@echo "✅ 所有工具存在"

## 🧪 预检 AWS Service Quota 等限制
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
	terraform -chdir=$(TF_DIR) plan -var="region=$(REGION)" -var="create_nat=true" -var="create_alb=true" -var="create_eks=true"

## ☀ 启动 NAT、ALB、EKS 控制面与节点组
start:
	@echo "Applying Terraform changes to start NAT and ALB..."
	terraform -chdir=$(TF_DIR) apply -auto-approve -input=false -var="region=$(REGION)" -var="create_nat=true" -var="create_alb=true" -var="create_eks=true"

## 🌄 创建 EKS 控制面（eksctl）
start-cluster:
	@echo "Creating EKS cluster with eksctl..."
	aws sso login --profile $(AWS_PROFILE)
	eksctl create cluster -f $(EKSCTL_YAML) --profile $(AWS_PROFILE) --kubeconfig ~/.kube/config --verbose 3

## 📨 Spot Interruption SNS 通知绑定
post-recreate:
	@echo "🔁 Running post-recreate to rebind ASG Spot Notification..."
	@mkdir -p scripts/logs
	bash scripts/post-recreate.sh | tee scripts/logs/post-recreate.log

## 🌙 停用高成本资源（保留基础结构）
stop:
	@echo "Stopping NAT, ALB, and EKS..."
	aws sso login --profile $(AWS_PROFILE)
	terraform -chdir=$(TF_DIR) apply -auto-approve -input=false -var="region=$(REGION)" -var="create_nat=false" -var="create_alb=false" -var="create_eks=false"

## 🌌 删除 EKS 控制面（eksctl）
stop-cluster:
	@echo "Destroying EKS cluster with eksctl..."
	eksctl delete cluster --name $(CLUSTER) --region $(REGION) --profile $(AWS_PROFILE) || true

## 💣 一键彻底销毁 EKS + 所有 Terraform 资源
destroy-all: stop-cluster
	@echo "🔥 Destroying all Terraform resources..."
	terraform -chdir=$(TF_DIR) destroy -auto-approve -input=false -var="region=$(REGION)"

## 🚀 一键全流程（重建集群 + 通知绑定）
all: start start-cluster post-recreate

## 📜 查看日志
logs:
	@ls -lt scripts/logs | head -n 5
	@echo "--- 最近日志内容 ---"
	@echo "Post Create 日志: "
	@echo "--------------------"
	@tail -n 10 scripts/logs/post-recreate.log || echo "Post Create ❌ 无日志"
	@echo "Preflight 日志: "
	@echo "--------------------"
	@tail -n 10 scripts/logs/preflight.txt || echo "Preflight ❌ 无日志"

## 🧹 清理临时状态文件
clean:
	@rm -f scripts/.last-asg-bound
	@echo "🧹 清理完成：临时文件已删除"
