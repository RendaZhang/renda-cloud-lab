#!/usr/bin/env bash
# ------------------------------------------------------------
# Renda Cloud Lab · post-recreate.sh
# 需要使用 Terraform 成功启动了基础设施（NAT + ALB + EKS + IRSA）后，
# 再使用本脚本进行部署层的自动化操作。
# 确保将集群资源的创建与 Kubernetes 服务的部署进行解耦。
#
# 必需的环境变量（需在运行前设置或由集群自动注入）：
# 如下三个自定义变量需要在 ${ROOT_DIR}/task-api/k8s/base/configmap.yaml 中定义
#   S3_BUCKET
#   S3_PREFIX
#   AWS_REGION
# 如下两个会由 EKS 自动注入
#   AWS_ROLE_ARN
#   AWS_WEB_IDENTITY_TOKEN_FILE
#
# 功能：
#   1. 更新本地 kubeconfig 并等待集群 API 就绪
#   2. 创建/更新 AWS Load Balancer Controller 所需的 ServiceAccount（IRSA）
#   3. 确保 task-api 的 ServiceAccount 存在并带 IRSA 注解
#   4. 通过 Helm 安装或升级 AWS Load Balancer Controller
#   5. 通过 Helm 安装或升级 ${AUTOSCALER_RELEASE_NAME}
#   6. 检查 NAT 网关、ALB、EKS 控制面和节点组等状态
#   7. 获取最新的 EKS NodeGroup 生成的 ASG 名称
#   8. 若之前未绑定，则为该 ASG 配置 SNS Spot Interruption 通知
#   9. 自动写入绑定日志，避免重复执行
#  10. 部署 task-api（镜像由 task-api 子项目构建并固定 ECR digest，配置探针/资源，并创建 PodDisruptionBudget）并在集群内冒烟
#  11. 发布 Ingress，等待公网 ALB 就绪并做 HTTP 冒烟
#  12. 安装 metrics-server（--kubelet-insecure-tls）
#  13. 部署 HPA（CPU 60%，min=2/max=10，含 behavior）
#  14. 检查 task-api
# 使用：
#   bash scripts/post-recreate.sh
# ------------------------------------------------------------

set -euo pipefail

# === 可配置参数 ===
CLOUD_PROVIDER="aws"
# 可通过环境变量覆盖
PROFILE=${AWS_PROFILE:-phase2-sso}
REGION=${REGION:-us-east-1}
AWS_PROFILE=${PROFILE}
AWS_REGION=${REGION}
ACCOUNT_ID=${ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --profile "$PROFILE" --output text)}
echo "使用 AWS 账号: $ACCOUNT_ID"

CLUSTER_NAME="dev"
NODEGROUP_NAME="ng-mixed"
KUBE_DEFAULT_NAMESPACE="kube-system"
ASG_PREFIX="eks-${NODEGROUP_NAME}"

# === 应用部署参数（可被环境变量覆盖）===
# k8s 命名空间（需与清单中的 metadata.namespace 一致）
NS="${NS:-svc-task}"
# Deployment/Service 的名称与容器名
APP="${APP:-task-api}"
# PodDisruptionBudget 名称（与 Deployment 同名 + "-pdb"）
PDB_NAME="${PDB_NAME:-${APP}-pdb}"
# ECR 仓库名
ECR_REPO="${ECR_REPO:-task-api}"
# IRSA 角色名称与 ARN（应用级 ServiceAccount 使用）
TASK_API_ROLE_NAME="dev-task-api-irsa"
TASK_API_ROLE_ARN="arn:${CLOUD_PROVIDER}:iam::${ACCOUNT_ID}:role/${TASK_API_ROLE_NAME}"
TASK_API_SERVICE_ACCOUNT_NAME="${TASK_API_SERVICE_ACCOUNT_NAME:-${APP}}"
# 要部署的 task-api 镜像 tag（也可用 latest）。若设置 IMAGE_DIGEST 则优先生效。
# 如更新 task-api 源码，请先构建并推送新镜像，然后调整此处 tag 或设置 IMAGE_DIGEST。
IMAGE_TAG="${IMAGE_TAG:-0.1.0-2508272044}"
# k8s 清单所在目录（ns-sa.yaml / configmap.yaml / deploy-svc.yaml / pdb.yaml）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
K8S_BASE_DIR="${K8S_BASE_DIR:-${ROOT_DIR}/task-api/k8s/base}"
# 若想固定某个 digest，可在运行前 export IMAGE_DIGEST=sha256:...

# 为 ASG 配置 Spot Interruption 通知的参数
TOPIC_NAME="spot-interruption-topic"
TOPIC_ARN="arn:${CLOUD_PROVIDER}:sns:${REGION}:${ACCOUNT_ID}:${TOPIC_NAME}"
STATE_FILE="${SCRIPT_DIR}/.last-asg-bound"
# ASG 相关参数
AUTOSCALER_CHART_NAME="cluster-autoscaler"
AUTOSCALER_RELEASE_NAME=${AUTOSCALER_CHART_NAME}
AUTOSCALER_HELM_REPO_NAME="autoscaler"
AUTOSCALER_HELM_REPO_URL="https://kubernetes.github.io/autoscaler"
AUTOSCALER_SERVICE_ACCOUNT_NAME=${AUTOSCALER_CHART_NAME}
AUTOSCALER_ROLE_NAME="eks-cluster-autoscaler"
AUTOSCALER_ROLE_ARN="arn:${CLOUD_PROVIDER}:iam::${ACCOUNT_ID}:role/${AUTOSCALER_ROLE_NAME}"
DEPLOYMENT_AUTOSCALER_NAME="${AUTOSCALER_RELEASE_NAME}-${CLOUD_PROVIDER}-${AUTOSCALER_CHART_NAME}"
POD_AUTOSCALER_LABEL="app.kubernetes.io/name=${AUTOSCALER_RELEASE_NAME}"

# AWS Load Balancer Controller settings
ALBC_CHART_NAME="aws-load-balancer-controller"
ALBC_RELEASE_NAME=${ALBC_CHART_NAME}
ALBC_SERVICE_ACCOUNT_NAME=${ALBC_CHART_NAME}
ALBC_CHART_VERSION="1.8.1"
ALBC_IMAGE_TAG="v2.8.1"
ALBC_IMAGE_REPO="602401143452.dkr.ecr.${REGION}.amazonaws.com/amazon/aws-load-balancer-controller"
ALBC_HELM_REPO_NAME="eks"
ALBC_HELM_REPO_URL="https://aws.github.io/eks-charts"
POD_ALBC_LABEL="app.kubernetes.io/name=${ALBC_RELEASE_NAME}"
ALBC_ROLE_NAME="${ALBC_ROLE_NAME:-aws-load-balancer-controller}"
ALBC_ROLE_ARN="arn:${CLOUD_PROVIDER}:iam::${ACCOUNT_ID}:role/${ALBC_ROLE_NAME}"
# ---- Ingress ----
ING_FILE="${ROOT_DIR}/task-api/k8s/ingress.yaml"
# ---- HPA ----
HPA_FILE="${ROOT_DIR}/task-api/k8s/hpa.yaml"
# ---- In-cluster Smoke Test ----
SMOKE_FILE="${ROOT_DIR}/task-api/k8s/task-api-smoke.yaml"

# === 函数定义 ===
# 清理临时 Job/资源，避免脚本异常退出后残留
cleanup() {
  kubectl -n "$NS" delete job task-api-smoke awscli-smoke --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT ERR

# log() {
#   echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
# }
log() {
  printf "[%s] %s\n" "$(date '+%H:%M:%S')" "$*";
}
abort() {
  printf "[%s] ❌ %s\n" "$(date '+%H:%M:%S')" "$*" >&2; exit 1;
}

# 判断 EKS 集群是否存在
cluster_exists() {
  aws eks describe-cluster \
    --name "$CLUSTER_NAME" \
    --region "$REGION" \
    --profile "$PROFILE" >/dev/null 2>&1
}

# 更新 kubeconfig 以连接 EKS 集群
update_kubeconfig() {
  log "🔄 更新 kubeconfig 以连接 EKS 集群: $CLUSTER_NAME"
  aws eks update-kubeconfig \
    --region "$REGION" \
    --name "$CLUSTER_NAME" \
    --profile "$PROFILE"
}

# 等待集群 API Server 就绪，避免后续 kubectl 操作超时
wait_cluster_ready() {
  local timeout=180
  log "⏳ 等待 EKS 集群 API 就绪..."
  SECONDS=0
  until kubectl get nodes >/dev/null 2>&1; do
    if (( SECONDS >= timeout )); then
      abort "EKS 集群 API 在 ${timeout}s 内未就绪"
    fi
    sleep 5
  done
  log "✅ EKS 集群 API 已就绪"
}

# 检查 Cluster Autoscaler 部署状态
check_autoscaler_status() {
  if ! kubectl -n $KUBE_DEFAULT_NAMESPACE get deployment $DEPLOYMENT_AUTOSCALER_NAME >/dev/null 2>&1; then
    echo "missing"
    return
  fi
  if kubectl -n $KUBE_DEFAULT_NAMESPACE get pod -l $POD_AUTOSCALER_LABEL \
      --no-headers 2>/dev/null | grep -v Running >/dev/null; then
    echo "unhealthy"
  else
    echo "healthy"
  fi
}

# 检查 AWS Load Balancer Controller 部署状态
check_albc_status() {
  if ! kubectl -n $KUBE_DEFAULT_NAMESPACE get deployment $ALBC_RELEASE_NAME >/dev/null 2>&1; then
    echo "missing"
    return
  fi
  if kubectl -n $KUBE_DEFAULT_NAMESPACE get pod -l $POD_ALBC_LABEL \
      --no-headers 2>/dev/null | grep -v Running >/dev/null; then
    echo "unhealthy"
  else
    echo "healthy"
  fi
}

# 确保 AWS Load Balancer Controller 的 ServiceAccount 存在并带注解
ensure_albc_service_account() {
  log "🛠️ 确保 ServiceAccount ${ALBC_SERVICE_ACCOUNT_NAME} 存在"
  if ! kubectl -n $KUBE_DEFAULT_NAMESPACE get sa ${ALBC_SERVICE_ACCOUNT_NAME} >/dev/null 2>&1; then
    kubectl -n $KUBE_DEFAULT_NAMESPACE create serviceaccount ${ALBC_SERVICE_ACCOUNT_NAME}
  fi
  kubectl -n $KUBE_DEFAULT_NAMESPACE annotate sa ${ALBC_SERVICE_ACCOUNT_NAME} \
    "eks.amazonaws.com/role-arn=${ALBC_ROLE_ARN}" --overwrite
}

# 确保 task-api 的 ServiceAccount 存在并带 IRSA 注解
ensure_task_api_service_account() {
  log "🛠️ 确保 task-api ServiceAccount ${TASK_API_SERVICE_ACCOUNT_NAME} 存在并带 IRSA 注解"
  if ! kubectl -n $NS get sa $TASK_API_SERVICE_ACCOUNT_NAME >/dev/null 2>&1; then
    log "创建 ServiceAccount ${TASK_API_SERVICE_ACCOUNT_NAME}"
    kubectl -n ${NS} create serviceaccount ${TASK_API_SERVICE_ACCOUNT_NAME}
  fi
  # 写入/覆盖 IRSA 注解
  kubectl -n ${NS} annotate sa ${TASK_API_SERVICE_ACCOUNT_NAME} \
    "eks.amazonaws.com/role-arn=${TASK_API_ROLE_ARN}" --overwrite
}

# ---- aws-cli IRSA smoke test ----
# Launches a temporary aws-cli Job (serviceAccount=task-api) to:
#   1) call STS get-caller-identity
#   2) write/list/read under the allowed S3 prefix
#   3) verify writes to a disallowed prefix are denied
awscli_s3_smoke() {
  log "🧪 aws-cli IRSA S3 smoke test"
  local manifest="${ROOT_DIR}/task-api/k8s/awscli-smoke.yaml"

  kubectl -n "$NS" apply -f "$manifest"

  if ! kubectl -n "$NS" wait --for=condition=complete job/awscli-smoke --timeout=180s; then
    kubectl -n "$NS" logs job/awscli-smoke || true
    kubectl -n "$NS" delete job awscli-smoke --ignore-not-found
    abort "aws-cli smoke job failed"
  fi

  kubectl -n "$NS" logs job/awscli-smoke || true
  kubectl -n "$NS" delete job awscli-smoke --ignore-not-found
  log "✅ aws-cli smoke test finished"
}


# 确认 Deployment 滚动更新就绪
check_deployment_ready() {
  log "⏳ 等待 Deployment ${APP} 就绪"
  if ! kubectl -n "$NS" rollout status deploy/"${APP}" --timeout=180s; then
    abort "Deployment ${APP} 未在 180s 内就绪"
  fi
  log "✅ Deployment ${APP} 已就绪"
}


# 集群内冒烟测试
task_api_smoke_test() {
  log "🧪 集群内冒烟测试"
  kubectl -n "${NS}" apply -f "${SMOKE_FILE}"

  if ! kubectl -n "${NS}" wait --for=condition=complete job/task-api-smoke --timeout=60s; then
    kubectl -n "${NS}" logs job/task-api-smoke || true
    kubectl -n "${NS}" delete job task-api-smoke --ignore-not-found
    abort "集群内冒烟测试失败"
  fi
  kubectl -n "${NS}" logs job/task-api-smoke || true
  kubectl -n "${NS}" delete job task-api-smoke --ignore-not-found
  log "✅ 部署与冒烟测试完成"
}

# 验证 IRSA 注入与运行时环境
verify_irsa_env() {
  log "🔎 验证 IRSA 注入与运行时环境"

  kubectl -n "${NS}" get sa "${TASK_API_SERVICE_ACCOUNT_NAME}" -o yaml | \
    grep -q "eks.amazonaws.com/role-arn" || \
    abort "ServiceAccount 未正确注解 eks.amazonaws.com/role-arn"

  local pod
  pod=$(kubectl -n "${NS}" get pods -l app="${TASK_API_SERVICE_ACCOUNT_NAME}" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  [[ -z "$pod" ]] && abort "未找到 ${APP} Pod，无法进行 IRSA 自检"

  local wait_time=0
  local max_wait=60
  local pod_status
  while [[ $wait_time -lt $max_wait ]]; do
    pod_status=$(kubectl -n "${NS}" get pod "$pod" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    [[ "$pod_status" == "Running" ]] && break
    sleep 3
    wait_time=$((wait_time+3))
  done
  [[ "$pod_status" != "Running" ]] && abort "Pod $pod 未进入 Running 状态，当前状态: $pod_status"

  local env_out
  env_out=$(kubectl -n "${NS}" exec "$pod" -- sh -lc 'env') || \
    abort "无法获取 Pod 环境变量"
  for key in S3_BUCKET S3_PREFIX AWS_REGION AWS_ROLE_ARN AWS_WEB_IDENTITY_TOKEN_FILE; do
    echo "$env_out" | grep -q "^${key}=" || abort "缺少环境变量 ${key}"
  done

  kubectl -n "${NS}" exec "$pod" -- sh -lc \
    'ls -l /var/run/secrets/eks.amazonaws.com/serviceaccount/ && \
     [ -s /var/run/secrets/eks.amazonaws.com/serviceaccount/token ]' >/dev/null || \
     abort "WebIdentity Token 缺失或为空"

  log "✅ task-api ServiceAccount IRSA 自检通过"
}

# 验证 PodDisruptionBudget
check_pdb() {
  log "🔎 验证 PodDisruptionBudget (${PDB_NAME})"

  kubectl -n "${NS}" get pdb "${PDB_NAME}" >/dev/null 2>&1 || \
    abort "缺少 PodDisruptionBudget ${PDB_NAME}"

  local pdb_min disruptions_allowed current_healthy desired_healthy
  pdb_min=$(kubectl -n "${NS}" get pdb "${PDB_NAME}" -o jsonpath='{.spec.minAvailable}')
  disruptions_allowed=$(kubectl -n "${NS}" get pdb "${PDB_NAME}" -o jsonpath='{.status.disruptionsAllowed}')
  current_healthy=$(kubectl -n "${NS}" get pdb "${PDB_NAME}" -o jsonpath='{.status.currentHealthy}')
  desired_healthy=$(kubectl -n "${NS}" get pdb "${PDB_NAME}" -o jsonpath='{.status.desiredHealthy}')

  [[ "$pdb_min" != "1" ]] && abort "PodDisruptionBudget minAvailable=$pdb_min (expected 1)"
  disruptions_allowed=${disruptions_allowed:-0}
  current_healthy=${current_healthy:-0}
  desired_healthy=${desired_healthy:-0}

  if [ "$disruptions_allowed" -lt 1 ]; then
    abort "PodDisruptionBudget disruptionsAllowed=$disruptions_allowed (<1)，可能是就绪副本不足或探针未 READY"
  fi

  if [ "$current_healthy" -lt "$desired_healthy" ]; then
    abort "PodDisruptionBudget currentHealthy=$current_healthy < desiredHealthy=$desired_healthy"
  fi

  log "✅ PodDisruptionBudget 检查通过 (allowed=${disruptions_allowed}, healthy=${current_healthy}/${desired_healthy})"
}

# 验证 ALB/Ingress/DNS
check_ingress_alb() {
  log "🔎 验证 task-api ALB、Ingress、dns"

  local outdir="${SCRIPT_DIR}/.out"; mkdir -p "$outdir"
  local dns

  log "⏳ Waiting for ALB to be provisioned ..."
  local t=0; local timeout=600
  while [[ $t -lt $timeout ]]; do
    dns=$(kubectl -n "$NS" get ing "$APP" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
    [[ -n "${dns}" ]] && break
    sleep 5; t=$((t+5))
  done
  [[ -z "${dns}" ]] && abort "Timeout waiting ALB"

  log "✅ ALB ready: http://${dns}"
  echo "${dns}" > "${outdir}/alb_${APP}_dns"

  log "🧪 ALB DNS Smoke test: "
  local smoke_retries=10
  local smoke_ok=0
  local smoke_wait=5
  for ((i=1; i<=smoke_retries; i++)); do
    if curl -sf "http://${dns}/api/hello?name=Renda" | sed -n '1p'; then
      smoke_ok=1
      break
    else
      log "⏳ Smoke test attempt $i/${smoke_retries} failed, retrying in ${smoke_wait}s..."
      sleep $smoke_wait
    fi
  done
  [[ $smoke_ok -eq 0 ]] && abort "Smoke test failed: /api/hello (DNS may not be ready or network issue)"
  curl -s "http://${dns}/actuator/health" | grep '"status":"UP"' || abort "Health check failed"
  curl -s "http://${dns}/actuator/prometheus" | grep '# HELP application_ready_time_seconds' || abort "Prometheus endpoint check failed"

  log "✅ ALB DNS Smoke test passed"
}

# 串联 task-api 各项检查
check_task_api() {
  log "🔍 检查 task-api"

  check_deployment_ready

  local fails=0
  local summary=()

  run_check() {
    local fn="$1"
    local label="$2"
    if ( "$fn" ); then
      summary+=("✅ ${label}")
    else
      summary+=("❌ ${label}")
      fails=$((fails+1))
    fi
  }

  run_check task_api_smoke_test "集群内冒烟测试"
  run_check verify_irsa_env "IRSA 环境自检"
  run_check check_pdb "PodDisruptionBudget"
  run_check check_ingress_alb "Ingress/ALB/DNS"
  run_check awscli_s3_smoke "aws-cli S3 权限"

  log "📊 task-api 检查结果汇总"
  for item in "${summary[@]}"; do
    log "$item"
  done

  if [[ $fails -gt 0 ]]; then
    abort "task-api 检查失败 (${fails} 项)"
  fi

  log "✅ task-api 检查完成"
}
# 安装或升级 AWS Load Balancer Controller
install_albc_controller() {
  local status
  status=$(check_albc_status)
  case "$status" in
    healthy)
      log "✅ AWS Load Balancer Controller 已正常运行, 跳过 Helm 部署"
      return 0
      ;;
    missing)
      log "⚙️  检测到 AWS Load Balancer Controller 未部署, 开始安装"
      ;;
    unhealthy)
      log "❌ 检测到 AWS Load Balancer Controller 状态异常, 删除旧 Pod 后重新部署"
      kubectl -n $KUBE_DEFAULT_NAMESPACE delete pod -l $POD_ALBC_LABEL --ignore-not-found
      ;;
    *)
      log "⚠️  未知的 AWS Load Balancer Controller 状态, 继续尝试安装"
      ;;
  esac

  if ! helm repo list | grep -q "^${ALBC_HELM_REPO_NAME}\b"; then
    log "🔧 添加 ${ALBC_HELM_REPO_NAME} Helm 仓库"
    helm repo add ${ALBC_HELM_REPO_NAME} ${ALBC_HELM_REPO_URL}
  fi
  helm repo update

  log "📦 应用 AWS Load Balancer Controller CRDs (version ${ALBC_CHART_VERSION})"
  tmp_dir=$(mktemp -d)
  helm pull ${ALBC_HELM_REPO_NAME}/${ALBC_CHART_NAME} --version ${ALBC_CHART_VERSION} --untar -d "$tmp_dir"
  kubectl apply -f "$tmp_dir/${ALBC_CHART_NAME}/crds"
  rm -rf "$tmp_dir"

  VPC_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --profile "$PROFILE" --query "cluster.resourcesVpcConfig.vpcId" --output text)

  log "🚀 正在通过 Helm 安装或升级 AWS Load Balancer Controller..."
  helm upgrade --install ${ALBC_RELEASE_NAME} ${ALBC_HELM_REPO_NAME}/${ALBC_CHART_NAME} \
    -n $KUBE_DEFAULT_NAMESPACE \
    --version ${ALBC_CHART_VERSION} \
    --set clusterName=$CLUSTER_NAME \
    --set region=$REGION \
    --set vpcId=$VPC_ID \
    --set serviceAccount.create=false \
    --set serviceAccount.name=${ALBC_SERVICE_ACCOUNT_NAME} \
    --set image.repository=${ALBC_IMAGE_REPO} \
    --set image.tag=${ALBC_IMAGE_TAG}

  log "🔍 等待 AWS Load Balancer Controller 就绪"
  kubectl -n $KUBE_DEFAULT_NAMESPACE rollout status deployment/${ALBC_RELEASE_NAME} --timeout=180s
  kubectl -n $KUBE_DEFAULT_NAMESPACE get pod -l $POD_ALBC_LABEL
}

# 安装或升级 Cluster Autoscaler
install_autoscaler() {
  local status
  status=$(check_autoscaler_status)
  case "$status" in
    healthy)
      log "✅ Cluster Autoscaler 已正常运行, 跳过 Helm 部署"
      return 0
      ;;
    missing)
      log "⚙️  检测到 Cluster Autoscaler 未部署, 开始安装"
      ;;
    unhealthy)
      log "❌ 检测到 Cluster Autoscaler 状态异常, 删除旧 Pod 后重新部署"
      kubectl -n $KUBE_DEFAULT_NAMESPACE delete pod -l $POD_AUTOSCALER_LABEL --ignore-not-found
      ;;
    *)
      log "⚠️  未知的 Cluster Autoscaler 状态, 继续尝试安装"
      ;;
  esac
  log "🚀 正在通过 Helm 安装或升级 Cluster Autoscaler..."
  if ! helm repo list | grep -q "^${AUTOSCALER_HELM_REPO_NAME}\b"; then
    log "🔧 添加 ${AUTOSCALER_HELM_REPO_NAME} Helm 仓库"
    helm repo add ${AUTOSCALER_HELM_REPO_NAME} ${AUTOSCALER_HELM_REPO_URL}
  fi
  # 获取 Kubernetes 完整版本 (如 v1.33.1)
  K8S_FULL_VERSION=$(kubectl version -o json | jq -r '.serverVersion.gitVersion')
  # 提取主次版本号 (如 1.33)
  K8S_MINOR_VERSION=$(echo "$K8S_FULL_VERSION" | sed -E 's/^v([0-9]+\.[0-9]+)\..*$/\1/')
  # 允许通过环境变量覆盖 Cluster Autoscaler 版本，否则默认使用 .0 补丁版本
  if [[ -z "${AUTOSCALER_VERSION:-}" ]]; then
    AUTOSCALER_VERSION="v${K8S_MINOR_VERSION}.0"
    log "⚠️  未设置 AUTOSCALER_VERSION，自动推断为 ${AUTOSCALER_VERSION}。如遇 Helm 拉取失败，请手动指定支持的版本（如：export AUTOSCALER_VERSION=v1.33.0）"
  else
    log "📌 使用指定的 Cluster Autoscaler 版本：${AUTOSCALER_VERSION}"
  fi
  helm upgrade --install ${AUTOSCALER_RELEASE_NAME} ${AUTOSCALER_HELM_REPO_NAME}/${AUTOSCALER_CHART_NAME} -n $KUBE_DEFAULT_NAMESPACE --create-namespace \
    --set awsRegion=$REGION \
    --set autoDiscovery.clusterName=$CLUSTER_NAME \
    --set rbac.serviceAccount.create=true \
    --set rbac.serviceAccount.name=${AUTOSCALER_SERVICE_ACCOUNT_NAME} \
    --set extraArgs.balance-similar-node-groups=true \
    --set extraArgs.skip-nodes-with-system-pods=false \
    --set rbac.serviceAccount.annotations."eks\\.amazonaws\\.com/role-arn"="$AUTOSCALER_ROLE_ARN" \
    --set image.tag=$AUTOSCALER_VERSION
  log "✅ Helm install completed"
  log "🔍 检查 Cluster Autoscaler Pod 状态"
  kubectl -n $KUBE_DEFAULT_NAMESPACE rollout status deployment/${DEPLOYMENT_AUTOSCALER_NAME} --timeout=180s
  kubectl -n $KUBE_DEFAULT_NAMESPACE get pod -l $POD_AUTOSCALER_LABEL
  # "如果 Helm 部署失败，重新部署后，需要执行如下命令删除旧 Pod 让 Deployment 拉新配置: "
  # log "kubectl -n $KUBE_DEFAULT_NAMESPACE delete pod -l $POD_AUTOSCALER_LABEL"
}

# 获取当前最新 ASG 名
get_latest_asg() {
  aws autoscaling describe-auto-scaling-groups \
    --region "$REGION" --profile "$PROFILE" \
    --query "AutoScalingGroups[?starts_with(AutoScalingGroupName, '$ASG_PREFIX')].AutoScalingGroupName" \
    --output text | head -n1
}

# 绑定 SNS 通知
bind_sns_notification() {
  local asg_name="$1"
  log "🔄 绑定 SNS 通知到 ASG: $asg_name"
  aws autoscaling put-notification-configuration \
    --auto-scaling-group-name "$asg_name" \
    --topic-arn "$TOPIC_ARN" \
    --notification-types "autoscaling:EC2_INSTANCE_TERMINATE" \
    --region "$REGION" --profile "$PROFILE"
}

# 确保 SNS 绑定到最新 ASG
ensure_sns_binding() {
  local asg_name="$1"
  if [[ -f "$STATE_FILE" ]]; then
    last_bound_asg=$(cat "$STATE_FILE")
  else
    last_bound_asg=""
  fi
  if [[ "$asg_name" == "$last_bound_asg" ]]; then
    log "✅ 当前 ASG [$asg_name] 已绑定过, 无需重复绑定"
  else
    bind_sns_notification "$asg_name"
    echo "$asg_name" > "$STATE_FILE"
    log "✅ 已绑定并记录最新 ASG: $asg_name"
  fi
}

# 检查 NAT 网关状态
check_nat_gateway() {
  aws ec2 describe-nat-gateways \
    --region "$REGION" --profile "$PROFILE" \
    --query "NatGateways[?State=='available']" --output json | jq length
}

# 检查 ALB 状态
check_alb() {
  aws elbv2 describe-load-balancers \
    --region "$REGION" --profile "$PROFILE" \
    --query "LoadBalancers[?Type=='application']" --output json | jq length
}

# 检查 EKS 集群状态
check_eks_cluster() {
  aws eks describe-cluster \
    --region "$REGION" --profile "$PROFILE" \
    --name "$CLUSTER_NAME" \
    --query 'cluster.status' --output text
}

# 检查节点组状态
check_nodegroup() {
  aws eks describe-nodegroup \
    --region "$REGION" --profile "$PROFILE" \
    --cluster-name "$CLUSTER_NAME" \
    --nodegroup-name "$NODEGROUP_NAME" \
    --query 'nodegroup.status' --output text
}

# 检查日志组存在
check_log_group() {
  aws logs describe-log-groups \
    --region "$REGION" --profile "$PROFILE" \
    --log-group-name-prefix "/aws/eks/${CLUSTER_NAME}/cluster" \
    --query 'logGroups[*].logGroupName' --output text
}

# 检查 SNS 绑定
check_sns_binding() {
  local asg_name="$1"
  aws autoscaling describe-auto-scaling-groups \
    --region "$REGION" --profile "$PROFILE" \
    --auto-scaling-group-names "$asg_name" \
    --query "AutoScalingGroups[0].NotificationConfigurations[?TopicARN=='${TOPIC_ARN}']" \
    --output json | jq length
}

# 进行基础资源检查
perform_health_checks() {
  local asg_name="$1"
  log "🔍 开始执行基础资源健康检查..."
  log "🔍 检查 NAT 网关状态"
  nat_count=$(check_nat_gateway)
  log "NAT Gateway count: $nat_count"
  log "🔍 检查 ALB 状态"
  alb_count=$(check_alb)
  log "ALB count: $alb_count"
  log "🔍 检查 EKS 集群状态"
  eks_status=$(check_eks_cluster)
  log "EKS cluster status: $eks_status"
  log "🔍 检查节点组状态"
  node_status=$(check_nodegroup)
  log "NodeGroup status: $node_status"
  log "🔍 检查 LogGroup 是否存在"
  log_group=$(check_log_group)
  log "LogGroup: $log_group"
  log "🔍 检查 AWS Load Balancer Controller 部署状态"
  albc_status=$(check_albc_status)
  log "AWS Load Balancer Controller status: $albc_status"
  log "🔍 检查 Cluster Autoscaler 部署状态"
  autoscaler_status=$(check_autoscaler_status)
  log "Cluster Autoscaler status: $autoscaler_status"
  log "🔍 验证 SNS 通知绑定"
  sns_bound=$(check_sns_binding "$asg_name")
  log "SNS bindings for ASG [$asg_name]: $sns_bound"
}

# === 部署 task-api 到 EKS（幂等）===
deploy_task_api() {
  # ===== 前置：AWS 身份与 kubeconfig =====
  log "🔐 使用 profile=${PROFILE} region=${REGION}"
  ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text --profile "${PROFILE}")" || abort "无法获取 AWS 账号 ID"
  log "👤 AWS Account: ${ACCOUNT_ID}"

  log "🔧 配置 kubeconfig（cluster=${CLUSTER_NAME}）"
  aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${REGION}" --profile "${PROFILE}" >/dev/null

  # ===== 应用 Kubernetes 清单 =====
  if [[ ! -d "${K8S_BASE_DIR}" ]]; then
    abort "未找到 k8s 清单目录：${K8S_BASE_DIR}"
  fi
  log "🗂️  apply 清单：ns-sa.yaml"
  kubectl -n "${NS}" apply -f "${K8S_BASE_DIR}/ns-sa.yaml"
  ensure_task_api_service_account  # 确保应用级 SA 带 IRSA 注解
  log "🗂️  apply 清单：configmap.yaml"
  kubectl -n "${NS}" apply -f "${K8S_BASE_DIR}/configmap.yaml"
  log "🗂️  apply 清单：deploy-svc.yaml"
  kubectl -n "${NS}" apply -f "${K8S_BASE_DIR}/deploy-svc.yaml"
  log "🗂️  apply 清单：pdb.yaml"
  # PodDisruptionBudget 确保在节点维护或滚动升级等自愿中断场景下，至少保留 1 个可用 Pod
  kubectl -n "${NS}" apply -f "${K8S_BASE_DIR}/pdb.yaml"

  # ===== 解析镜像（优先使用固定 digest）=====
  if [[ -n "${IMAGE_DIGEST:-}" ]]; then
    DIGEST="${IMAGE_DIGEST}"
    log "📌 使用固定 digest：${DIGEST}"
  else
    log "🔎 从 ECR 获取 ${ECR_REPO}:${IMAGE_TAG} 的 digest"
    set +e
    DIGEST="$(aws ecr describe-images \
      --repository-name "${ECR_REPO}" \
      --image-ids imageTag="${IMAGE_TAG}" \
      --query 'imageDetails[0].imageDigest' \
      --output text --region "${REGION}" --profile "${PROFILE}")"
    rc=$?
    set -e
    if [[ $rc -ne 0 || -z "${DIGEST}" || "${DIGEST}" == "None" ]]; then
      abort "ECR 中未找到镜像 ${ECR_REPO}:${IMAGE_TAG} 的 digest，请先推送镜像或调整 IMAGE_TAG"
    fi
  fi
  IMAGE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_REPO}@${DIGEST}"

  # ===== 若已部署且健康则跳过镜像更新 =====
  skip_deploy=false
  current_image=""
  if kubectl -n "${NS}" get deploy "${APP}" >/dev/null 2>&1; then
    current_image=$(kubectl -n "${NS}" get deploy "${APP}" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "")
    if [[ "$current_image" == "${IMAGE}" ]]; then
      # 检查是否所有 Pod 均为 Running
      if ! kubectl -n "${NS}" get pods -l app="${APP}" --no-headers 2>/dev/null | grep -v Running >/dev/null; then
        log "✅ 镜像 ${IMAGE} 已部署且运行正常，跳过镜像更新"
        skip_deploy=true
      else
        log "⚠️ 镜像一致但存在异常 Pod，重新部署"
      fi
    fi
  fi

  if [[ "${skip_deploy}" != true ]]; then
    # ===== 用 set image 覆盖镜像，并记录 rollout 历史 =====
    log "🖼️  将部署镜像：${IMAGE}"
    log "♻️  更新 Deployment 镜像并等待滚动完成"
    kubectl -n "${NS}" set image deploy/"${APP}" "${APP}"="${IMAGE}" --record
    kubectl -n "${NS}" rollout status deploy/"${APP}" --timeout=180s
    kubectl -n "${NS}" get deploy,svc -o wide
  fi
}

# 部署 taskapi ingress
deploy_task_api_ingress() {
  log "📦 Apply Ingress (${APP}) ..."
  # 若无变更就不 apply（0=无差异，1=有差异，>1=出错）
  if kubectl -n "$NS" diff -f "$ING_FILE" >/dev/null 2>&1; then
    log "≡ No changes"
  else
    kubectl -n "$NS" apply -f "$ING_FILE"
  fi
}

### ---- metrics-server (Helm) ----
deploy_metrics_server() {
  log "🔍 检查 metrics-server 状态..."
  if kubectl -n "$KUBE_DEFAULT_NAMESPACE" get deployment metrics-server >/dev/null 2>&1; then
    local replicas available
    replicas=$(kubectl -n "$KUBE_DEFAULT_NAMESPACE" get deployment metrics-server -o jsonpath='{.status.replicas}')
    available=$(kubectl -n "$KUBE_DEFAULT_NAMESPACE" get deployment metrics-server -o jsonpath='{.status.availableReplicas}')
    replicas=${replicas:-0}
    available=${available:-0}
    if [[ "$replicas" -gt 0 && "$replicas" == "$available" ]]; then
      log "✅ metrics-server 已部署且健康，跳过安装"
      return
    fi
    log "⚠️ metrics-server 存在但未就绪，重新部署"
  fi

  log "📦 Installing metrics-server ..."
  helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1
  helm upgrade --install metrics-server metrics-server/metrics-server \
    --namespace "$KUBE_DEFAULT_NAMESPACE" \
    --version 3.12.1 \
    --set args={--kubelet-insecure-tls}
  kubectl -n "$KUBE_DEFAULT_NAMESPACE" rollout status deploy/metrics-server --timeout=180s
}

### ---- HPA for task-api ----
deploy_taskapi_hpa() {
  log "📦 Apply HPA for task-api ..."
  kubectl -n "$NS" apply -f "$HPA_FILE"
  log "🔎 Describe HPA"
  kubectl -n "$NS" describe hpa task-api | sed -n '1,60p' || true
}

# === 主流程 ===
log "📣 开始执行 post-recreate 脚本"

if ! cluster_exists; then
  log "⚠️  未找到 EKS 集群 $CLUSTER_NAME，可能已销毁，脚本退出"
  exit 0
fi

log "🔍 获取最新的 ASG 名称"
asg_name=$(get_latest_asg)
if [[ -z "$asg_name" ]]; then
  abort "未找到以 $ASG_PREFIX 开头的 ASG, 终止脚本"
fi

update_kubeconfig

wait_cluster_ready  # 确保集群 API 就绪，避免后续操作超时

ensure_albc_service_account

install_albc_controller

install_autoscaler

ensure_sns_binding "$asg_name"

perform_health_checks "$asg_name"

deploy_task_api

deploy_task_api_ingress

deploy_metrics_server

deploy_taskapi_hpa

check_task_api
