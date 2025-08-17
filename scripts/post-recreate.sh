#!/usr/bin/env bash
# ------------------------------------------------------------
# Renda Cloud Lab · post-recreate.sh
# 需要使用 Terraform 成功启动了基础设施（NAT + ALB + EKS + IRSA）后，
# 再使用本脚本进行部署层的自动化操作。
# 确保将集群资源的创建与 Kubernetes 服务的部署进行解耦。
# 功能：
#   1. 更新本地 kubeconfig 以连接最新创建的集群
#   2. 通过 Helm 安装或升级 AWS Load Balancer Controller
#   3. 通过 Helm 安装或升级 ${AUTOSCALER_RELEASE_NAME}
#   4. 检查 NAT 网关、ALB、EKS 控制面和节点组等状态
#   5. 获取最新的 EKS NodeGroup 生成的 ASG 名称
#   6. 若之前未绑定，则为该 ASG 配置 SNS Spot Interruption 通知
#   7. 自动写入绑定日志，避免重复执行
#   8. 部署 task-api（固定 ECR digest，配置探针/资源）并在集群内冒烟
#   9. 发布 Ingress，等待公网 ALB 就绪并做 HTTP 冒烟
#  10. 安装 metrics-server（--kubelet-insecure-tls）
#  11. 部署 HPA（CPU 60%，min=2/max=10，含 behavior）
# 使用：
#   bash scripts/post-recreate.sh
# ------------------------------------------------------------

set -euo pipefail

# === 可配置参数 ===
CLOUD_PROVIDER="aws"
# 可通过环境变量覆盖
PROFILE=${AWS_PROFILE:-phase2-sso}
REGION=${REGION:-us-east-1}
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
# ECR 仓库名
ECR_REPO="${ECR_REPO:-task-api}"
# 要部署的镜像 tag（也可用 latest）。若设置 IMAGE_DIGEST 则优先生效。
IMAGE_TAG="${IMAGE_TAG:-0.1.0}"
# k8s 清单所在目录（ns-sa.yaml / configmap.yaml / deploy-svc.yaml）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
K8S_BASE_DIR="${K8S_BASE_DIR:-${ROOT_DIR}/task-api/k8s/base}"
# 若你想固定某个 digest，可在运行前 export IMAGE_DIGEST=sha256:...

# 为 ASG 配置 Spot Interruption 通知的参数
TOPIC_NAME="spot-interruption-topic"
TOPIC_ARN="arn:${CLOUD_PROVIDER}:sns:${REGION}:${ACCOUNT_ID}:${TOPIC_NAME}"
STATE_FILE="${SCRIPT_DIR}/.last-asg-bound"
# ASG 相关参数
AUTOSCALER_CHART_NAME="cluster-autoscaler"
AUTOSCALER_RELEASE_NAME=${AUTOSCALER_CHART_NAME}
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
# ---- Ingress ----
ING_FILE="${ROOT_DIR}/task-api/k8s/ingress.yaml"
# ---- HPA ----
HPA_FILE="${ROOT_DIR}/task-api/k8s/hpa.yaml"

# === 函数定义 ===
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
  if ! helm repo list | grep -q '^autoscaler'; then
    log "🔧 添加 autoscaler Helm 仓库"
    helm repo add autoscaler https://kubernetes.github.io/autoscaler
  fi
  helm repo update
  # 获取 Kubernetes 完整版本 (如 v1.33.1)
  K8S_FULL_VERSION=$(kubectl version -o json | jq -r '.serverVersion.gitVersion')
  # 提取主次版本号 (如 1.33)
  K8S_MINOR_VERSION=$(echo "$K8S_FULL_VERSION" | sed -E 's/^v([0-9]+\.[0-9]+)\..*$/\1/')
  # 确定 Cluster Autoscaler 版本 (总是使用 .0 补丁版本)
  AUTOSCALER_VERSION="v${K8S_MINOR_VERSION}.0"
  helm upgrade --install ${AUTOSCALER_RELEASE_NAME} autoscaler/${AUTOSCALER_CHART_NAME} -n $KUBE_DEFAULT_NAMESPACE --create-namespace \
    --set awsRegion=$REGION \
    --set autoDiscovery.clusterName=$CLUSTER_NAME \
    --set rbac.serviceAccount.create=true \
    --set rbac.serviceAccount.name=${AUTOSCALER_RELEASE_NAME} \
    --set extraArgs.balance-similar-node-groups=true \
    --set extraArgs.skip-nodes-with-system-pods=false \
    --set rbac.serviceAccount.annotations."eks\\.amazonaws\\.com/role-arn"="$AUTOSCALER_ROLE_ARN" \
    --set image.tag=$AUTOSCALER_VERSION
  log "✅ Helm install completed"
  log "🔍 检查 Cluster Autoscaler Pod 状态"
  kubectl -n $KUBE_DEFAULT_NAMESPACE rollout status deployment/${DEPLOYMENT_AUTOSCALER_NAME} --timeout=180s
  kubectl -n $KUBE_DEFAULT_NAMESPACE get pod -l $POD_AUTOSCALER_LABEL
  log "如果 Helm 部署失败，重新部署后，需要执行如下命令删除旧 Pod 让 Deployment 拉新配置: "
  log "kubectl -n $KUBE_DEFAULT_NAMESPACE delete pod -l $POD_AUTOSCALER_LABEL"
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
  log "🗂️  apply 清单：configmap.yaml"
  kubectl -n "${NS}" apply -f "${K8S_BASE_DIR}/configmap.yaml"
  log "🗂️  apply 清单：deploy-svc.yaml"
  kubectl -n "${NS}" apply -f "${K8S_BASE_DIR}/deploy-svc.yaml"

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
  log "🖼️  将部署镜像：${IMAGE}"

  # ===== 用 set image 覆盖镜像，并记录 rollout 历史 =====
  log "♻️  更新 Deployment 镜像并等待滚动完成"
  kubectl -n "${NS}" set image deploy/"${APP}" "${APP}"="${IMAGE}" --record
  kubectl -n "${NS}" rollout status deploy/"${APP}" --timeout=180s
  kubectl -n "${NS}" get deploy,svc -o wide

  # ===== 集群内冒烟测试 =====
  log "🧪 集群内冒烟测试：/api/hello 与 /actuator/health"
  kubectl -n "${NS}" run curl --image=curlimages/curl:8.8.0 -i --rm -q --restart=Never -- \
    sh -lc "set -e; \
      curl -sf http://${APP}.${NS}.svc.cluster.local:8080/api/hello?name=Renda >/dev/null; \
      curl -sf http://${APP}.${NS}.svc.cluster.local:8080/actuator/health | grep -q '\"status\":\"UP\"'"
  log "✅ 部署与冒烟测试完成"
}

# 部署 taskapi ingress
deploy_taskapi_ingress() {
  set -euo pipefail
  local outdir="${SCRIPT_DIR}/.out"; mkdir -p "$outdir"

  log "📦 Apply Ingress (${APP}) ..."
  # 若无变更就不 apply（0=无差异，1=有差异，>1=出错）
  if kubectl -n "$NS" diff -f "$ING_FILE" >/dev/null 2>&1; then
    log "≡ No changes"
  else
    kubectl apply -f "$ING_FILE"
  fi

  # 如果已经有 ALB，就直接复用并返回
  local dns
  dns=$(kubectl -n "$NS" get ing "$APP" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  if [[ -n "${dns}" ]]; then
    log "✅ ALB ready: http://${dns}"
    echo "${dns}" > "${outdir}/alb_${APP}_dns"
    return 0
  fi

  log "⏳ Waiting for ALB to be provisioned ..."
  local t=0; local timeout=600
  while [[ $t -lt $timeout ]]; do
    dns=$(kubectl -n "$NS" get ing "$APP" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
    [[ -n "${dns}" ]] && break
    sleep 5; t=$((t+5))
  done
  [[ -z "${dns}" ]] && { log "❌ Timeout waiting ALB"; return 1; }

  log "✅ ALB ready: http://${dns}"
  echo "${dns}" > "${outdir}/alb_${APP}_dns"

  log "🧪 Smoke"
  curl -s "http://${dns}/api/hello?name=Renda" | sed -n '1p'
  curl -s "http://${dns}/actuator/health" | sed -n '1p'
}

### ---- metrics-server (Helm) ----
deploy_metrics_server() {
  log "📦 Installing metrics-server ..."
  helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ >/dev/null 2>&1 || true
  helm repo update >/dev/null
  helm upgrade --install metrics-server metrics-server/metrics-server \
    --namespace $KUBE_DEFAULT_NAMESPACE \
    --version 3.12.1 \
    --set args={--kubelet-insecure-tls}
  kubectl -n $KUBE_DEFAULT_NAMESPACE rollout status deploy/metrics-server --timeout=180s
}

### ---- HPA for task-api ----
deploy_taskapi_hpa() {
  log "📦 Apply HPA for task-api ..."
  kubectl apply -f "$HPA_FILE"
  log "🔎 Describe HPA"
  kubectl -n svc-task describe hpa task-api | sed -n '1,60p' || true
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
  log "❌ 未找到以 $ASG_PREFIX 开头的 ASG, 终止脚本"
  exit 1
fi

update_kubeconfig

install_albc_controller

install_autoscaler

ensure_sns_binding "$asg_name"

perform_health_checks "$asg_name"

deploy_task_api

deploy_taskapi_ingress

deploy_metrics_server

deploy_taskapi_hpa
