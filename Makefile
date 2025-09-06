AWS_PROFILE = phase2-sso
TF_DIR      = infra/aws
REGION      = us-east-1
EKSCTL_YAML = infra/eksctl/eksctl-cluster.yaml
CLUSTER     = dev

# --- 新增：脚本路径与开关 ---
SCRIPTS_DIR           ?= scripts
PRE_TEARDOWN          ?= $(SCRIPTS_DIR)/pre-teardown.sh
POST_TEARDOWN         ?= $(SCRIPTS_DIR)/post-teardown.sh
POST_RECREATE         ?= $(SCRIPTS_DIR)/post-recreate.sh
DRY_RUN               ?= false          # true 仅打印将执行的操作
UNINSTALL_METRICS     ?= true           # pre-teardown 默认卸载 metrics-server
UNINSTALL_ADOT        ?= true           # pre-teardown 默认卸载 ADOT Collector
UNINSTALL_GRAFANA     ?= true           # pre-teardown 默认卸载 Grafana
ENABLE_CHAOS_MESH     ?= false          # post-recreate 可选安装 Chaos Mesh
UNINSTALL_CHAOS_MESH  ?= true           # pre-teardown 默认卸载 Chaos Mesh

.PHONY: check check-auto preflight aws-login init plan start post-recreate start-all \
        scale-zero stop pre-teardown post-teardown stop-all destroy-all logs clean \
        update-diagrams lint

## 🛠️ 环境检查（工具版本、路径等）
check:
	@echo "🔎 检查 CLI 工具链状态..."
	@bash scripts/check-tools.sh --log

## 自动安装全部缺失工具
check-auto:
	@echo "🔧 自动安装缺失工具..."
	@bash scripts/check-tools.sh --auto --log

## 🧪 预检 AWS Service Quota 等限制
preflight:
	@bash scripts/preflight.sh

## 🔑 登录 AWS SSO
aws-login:
	@echo "🔑 正在登录 AWS SSO..."
	aws sso login --profile $(AWS_PROFILE)

## 🧰 初始化 Terraform
init:
	@echo "Initializing Terraform..."
	terraform -chdir=$(TF_DIR) init -reconfigure

## ▶ 显示当前计划（Terraform 管理 NAT / EKS 控制面）
plan:
	@echo "Planning Terraform changes..."
	terraform -chdir=$(TF_DIR) plan \
		-var="region=$(REGION)" \
		-var="create_nat=true" \
		-var="create_eks=true"

## ☀ 启动 NAT、EKS 控制面
start:
	@echo "Applying Terraform changes to start NAT and EKS..."
	terraform -chdir=$(TF_DIR) apply -auto-approve -input=false \
		-var="region=$(REGION)" \
		-var="create_nat=true" \
		-var="create_eks=true"

## 📨 运行 Spot 通知自动绑定并刷新本地 kubeconfig 以及使用 Helm 部署
post-recreate:
	@echo "Running post-recreate tasks..."
	@mkdir -p scripts/logs
	@REGION=$(REGION) PROFILE=$(AWS_PROFILE) CLUSTER_NAME=$(CLUSTER) \
		ENABLE_CHAOS_MESH=$(ENABLE_CHAOS_MESH) \
		bash $(POST_RECREATE) | tee scripts/logs/post-recreate.log

## 🚀 一键全流程（重建集群 + 通知绑定）
start-all: start post-recreate

## 🌙 缩容所有 EKS 节点组至 0
scale-zero:
	@echo "🌙 Scaling down all EKS node groups to zero..."
	@bash scripts/scale-nodegroup-zero.sh

## 🌙 销毁 NAT 以及 EKS 控制面（采用“三开关”方式）
stop: scale-zero
	@echo "Stopping all resources (NAT and EKS control plane)..."
	terraform -chdir=$(TF_DIR) apply -auto-approve -input=false \
		-var="region=$(REGION)" \
		-var="create_nat=false" \
		-var="create_eks=false"

## 🧼 在销毁前先优雅释放：删除所有 ALB Ingress → 等待回收 ALB/TG → 卸载 ALB Controller + metrics-server
pre-teardown:
	@echo "🧹 [pre-teardown] 删除 Ingress & 卸载 ALB Controller (+ metrics-server)"
	@mkdir -p scripts/logs
	@REGION=$(REGION) PROFILE=$(AWS_PROFILE) CLUSTER_NAME=$(CLUSTER) \
		UNINSTALL_METRICS_SERVER=$(UNINSTALL_METRICS) \
		UNINSTALL_ADOT_COLLECTOR=$(UNINSTALL_ADOT) \
		UNINSTALL_GRAFANA=$(UNINSTALL_GRAFANA) \
		UNINSTALL_CHAOS_MESH=$(UNINSTALL_CHAOS_MESH) \
		bash $(PRE_TEARDOWN) | tee scripts/logs/pre-teardown.log

## 🛠️ 清理残留日志组 + 兜底强删 ALB/TargetGroup/安全组（按标签）
post-teardown:
	@echo "Running post-teardown tasks..."
	@mkdir -p scripts/logs
	@REGION=$(REGION) PROFILE=$(AWS_PROFILE) CLUSTER_NAME=$(CLUSTER) \
		DRY_RUN=$(DRY_RUN) \
		bash $(POST_TEARDOWN) | tee scripts/logs/post-teardown.log

## 🧹 销毁集群后清理残留（优雅 → 销毁 → 兜底）
stop-all: pre-teardown stop post-teardown

## 💣 一键彻底销毁所有资源
destroy-all: pre-teardown stop
	@echo "🔥 Destroying all Terraform-managed resources..."
	terraform -chdir=$(TF_DIR) destroy -auto-approve -input=false \
		-var="region=$(REGION)"
	@echo "Running post-teardown cleanup..."
	@mkdir -p scripts/logs
	@REGION=$(REGION) PROFILE=$(AWS_PROFILE) CLUSTER_NAME=$(CLUSTER) \
		DRY_RUN=$(DRY_RUN) \
		bash scripts/post-teardown.sh | tee scripts/logs/post-teardown.log

## 📜 查看日志
logs:
	@ls -lt scripts/logs | head -n 5
	@echo "--- 最近日志内容 ---"
	@for f in scripts/logs/pre-teardown.log scripts/logs/post-recreate.log scripts/logs/preflight.txt scripts/logs/check-tools.log; do \
		if [ -f $$f ]; then \
		echo "`basename $$f`"; \
		echo "--------------------"; \
		tail -n 10 $$f; \
		else \
		echo "`basename $$f` ❌ 无日志"; \
		fi; \
		done

# 🧹 清理临时状态文件
clean:
	@echo "🧹 Cleaning caches and logs..."
	@rm -f scripts/.last-asg-bound
	@rm -f scripts/logs/*.log scripts/logs/*.txt 2>/dev/null || true
	@rm -f scripts/*.tmp scripts/*.bak 2>/dev/null || true
	@rm -f plan.out *.tfplan 2>/dev/null || true
	@rm -rf $(TF_DIR)/.terraform 2>/dev/null || true
	@rm -rf $(TF_DIR)/modules/*/.terraform 2>/dev/null || true
	@rm -rf $(TF_DIR)/modules/*/.terraform.lock.hcl 2>/dev/null || true
	@echo "🧹 清理完成：临时文件和日志已删除"

# 📊 更新架构图
update-diagrams:
	@echo "📊 更新架构图..."
	@bash scripts/update-diagrams.sh

## 📦 运行 pre-commit 检查（terraform fmt / tflint / yamllint 等）
lint:
	@echo "🔍 Running pre-commit checks..."
	@pre-commit run --all-files --verbose --show-diff-on-failure
