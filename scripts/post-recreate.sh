#!/usr/bin/env bash
# ------------------------------------------------------------
# Renda Cloud Lab · post-recreate.sh
# 功能：
#   1. 更新本地 kubeconfig 以连接最新创建的集群
#   2. 通过 Helm 安装或升级 ${AUTOSCALER_RELEASE_NAME}
#   3. 检查 NAT 网关、ALB、EKS 控制面和节点组等状态
#   4. 获取最新的 EKS NodeGroup 生成的 ASG 名称
#   5. 若之前未绑定，则为该 ASG 配置 SNS Spot Interruption 通知
#   6. 自动写入绑定日志，避免重复执行
# 使用：
#   bash scripts/post-recreate.sh
# ------------------------------------------------------------

set -euo pipefail

# === 可配置参数 ===
CLOUD_PROVIDER="aws"
PROFILE="phase2-sso"
REGION="us-east-1"

CLUSTER_NAME="dev"
NODEGROUP_NAME="ng-mixed"
KUBE_DEFAULT_NAMESPACE="kube-system"
ASG_PREFIX="eks-${NODEGROUP_NAME}"
ACCOUNT_ID="563149051155"
TOPIC_NAME="spot-interruption-topic"
TOPIC_ARN="arn:${CLOUD_PROVIDER}:sns:${REGION}:${ACCOUNT_ID}:${TOPIC_NAME}"
STATE_FILE="scripts/.last-asg-bound"
AUTOSCALER_CHART_NAME="cluster-autoscaler"
AUTOSCALER_RELEASE_NAME=${AUTOSCALER_CHART_NAME}
AUTOSCALER_ROLE_NAME="eks-cluster-autoscaler"
AUTOSCALER_ROLE_ARN="arn:${CLOUD_PROVIDER}:iam::${ACCOUNT_ID}:role/${AUTOSCALER_ROLE_NAME}"
DEPLOYMENT_AUTOSCALER_NAME="${AUTOSCALER_RELEASE_NAME}-${CLOUD_PROVIDER}-${AUTOSCALER_CHART_NAME}"
POD_AUTOSCALER_LABEL="app.kubernetes.io/name=${AUTOSCALER_RELEASE_NAME}"

# === 函数定义 ===
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
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
  kubectl -n $KUBE_DEFAULT_NAMESPACE get pod -l $POD_AUTOSCALER_LABEL
  log "如果 Helm 部署失败，重新部署后，需要执行如下命令删除旧 Pod 让 Deployment 拉新配置: "
  log "kubectl -n $KUBE_DEFAULT_NAMESPACE delete pod -l $POD_AUTOSCALER_LABEL"
}

# 获取当前最新 ASG 名
get_latest_asg() {
  aws autoscaling describe-auto-scaling-groups \
    --region "$REGION" --profile "$PROFILE" \
    --query "AutoScalingGroups[?starts_with(AutoScalingGroupName, \`${ASG_PREFIX}\`)].AutoScalingGroupName" \
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
  if [[ -z "$asg_name" ]]; then
    log "❌ 未找到以 $ASG_PREFIX 开头的 ASG, 终止脚本"
    exit 1
  fi
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
  log "🔍 检查 Cluster Autoscaler 部署状态"
  autoscaler_status=$(check_autoscaler_status)
  log "Cluster Autoscaler status: $autoscaler_status"
  log "🔍 验证 SNS 通知绑定"
  sns_bound=$(check_sns_binding "$asg_name")
  log "SNS bindings for ASG [$asg_name]: $sns_bound"
}

# === 主流程 ===
log "📣 开始执行 post-recreate 脚本"

update_kubeconfig

install_autoscaler

log "🔍 获取最新的 ASG 名称"
asg_name=$(get_latest_asg)

ensure_sns_binding "$asg_name"

perform_health_checks "$asg_name"
