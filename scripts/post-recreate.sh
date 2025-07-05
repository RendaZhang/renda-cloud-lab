#!/usr/bin/env bash
# ------------------------------------------------------------
# Renda Cloud Lab · post-recreate.sh
# 功能：
#   1. 获取最新的 EKS NodeGroup 生成的 ASG 名称
#   2. 若之前未绑定，则为该 ASG 配置 SNS Spot Interruption 通知
#   3. 更新本地 kubeconfig 以连接最新创建的集群
#   4. 通过 Helm 安装或升级 cluster-autoscaler
#   5. 自动写入绑定日志，避免重复执行
# 使用：
#   bash scripts/post-recreate.sh
# ------------------------------------------------------------

set -euo pipefail

# === 可配置参数 ===
PROFILE="phase2-sso"
REGION="us-east-1"
CLUSTER_NAME="dev"
ASG_PREFIX="eks-ng-mixed"
TOPIC_ARN="arn:aws:sns:${REGION}:563149051155:spot-interruption-topic"
STATE_FILE="scripts/.last-asg-bound"
AUTOSCALER_ROLE_ARN="arn:aws:iam::563149051155:role/eks-cluster-autoscaler"

# === 函数定义 ===
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
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

# 安装或升级 Cluster Autoscaler
install_autoscaler() {
  log "🚀 Installing or upgrading Cluster Autoscaler via Helm..."
  if ! helm repo list | grep -q '^autoscaler'; then
    log "🔧 Adding autoscaler Helm repo"
    helm repo add autoscaler https://kubernetes.github.io/autoscaler
  fi
  helm repo update
  k8s_version=$(kubectl version -o json | jq -r '.serverVersion.gitVersion' | sed 's/^v//')
  helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler -n kube-system --create-namespace \
    --set awsRegion=$REGION \
    --set autoDiscovery.clusterName=$CLUSTER_NAME \
    --set rbac.serviceAccount.create=true \
    --set rbac.serviceAccount.name=cluster-autoscaler \
    --set extraArgs.balance-similar-node-groups=true \
    --set extraArgs.skip-nodes-with-system-pods=false \
    --set rbac.serviceAccount.annotations."eks.amazonaws.com/role-arn"="$AUTOSCALER_ROLE_ARN" \
    --set image.tag=$k8s_version
  log "✅ Helm install completed"
  kubectl -n kube-system get pod -l app.kubernetes.io/name=aws-cluster-autoscaler
}

# === 主流程 ===
log "📣 开始执行 post-recreate 脚本"

log "🎯 Updating local kubeconfig for EKS cluster..."
aws eks update-kubeconfig \
  --region "$REGION" \
  --name "$CLUSTER_NAME" \
  --profile "$PROFILE"

install_autoscaler

asg_name=$(get_latest_asg)
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
