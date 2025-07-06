#!/usr/bin/env bash
# ------------------------------------------------------------
# Renda Cloud Lab · post-teardown.sh
# 功能: 清理 EKS 控制面相关的 CloudWatch Log Group
# Usage: bash scripts/post-teardown.sh
# ------------------------------------------------------------
set -euo pipefail

# 可通过环境变量覆盖
REGION="${REGION:-us-east-1}"
PROFILE="${PROFILE:-phase2-sso}"
LOG_GROUP="${LOG_GROUP:-/aws/eks/dev/cluster}"
CLUSTER_NAME="${CLUSTER_NAME:-dev}"
NAT_NAME="${NAT_NAME:-lab-nat}"
ALB_NAME="${ALB_NAME:-alb-demo}"
ASG_PREFIX="${ASG_PREFIX:-eks-ng-mixed}"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

delete_log_group() {
  log "🧹 清理 CloudWatch Log Group: $LOG_GROUP"
  if aws logs describe-log-groups \
        --log-group-name-prefix "$LOG_GROUP" \
        --region "$REGION" \
        --profile "$PROFILE" | grep -q "\"logGroupName\": \"$LOG_GROUP\""; then
    aws logs delete-log-group \
      --log-group-name "$LOG_GROUP" \
      --region "$REGION" \
      --profile "$PROFILE"
    log "✅ 已删除日志组 $LOG_GROUP"
  else
    log "ℹ️ 日志组 $LOG_GROUP 不存在，跳过删除"
  fi
}

# 检查 NAT 网关是否删除
check_nat_gateway_deleted() {
  log "🔍 检查 NAT 网关 $NAT_NAME 是否已删除"
  local count
  count=$(aws ec2 describe-nat-gateways \
    --region "$REGION" --profile "$PROFILE" \
    --filter "Name=tag:Name,Values=$NAT_NAME" \
    --query "NatGateways[?State!='deleted']" --output json | jq length)
  if [ "$count" -eq 0 ]; then
    log "✅ NAT 网关已删除"
  else
    log "❌ NAT 网关仍存在，请检查 AWS 控制台"
  fi
}

# 检查 ALB 是否删除
check_alb_deleted() {
  log "🔍 检查 ALB $ALB_NAME 是否已删除"
  if aws elbv2 describe-load-balancers --names "$ALB_NAME" \
       --region "$REGION" --profile "$PROFILE" >/dev/null 2>&1; then
    log "❌ ALB $ALB_NAME 仍存在"
  else
    log "✅ ALB 已删除"
  fi
}

# 检查 EKS 集群是否删除
check_eks_cluster_deleted() {
  log "🔍 检查 EKS 集群 $CLUSTER_NAME 是否已删除"
  if aws eks describe-cluster --name "$CLUSTER_NAME" \
       --region "$REGION" --profile "$PROFILE" >/dev/null 2>&1; then
    log "❌ EKS 集群仍存在"
  else
    log "✅ EKS 集群已删除"
  fi
}

# 检查 SNS 通知是否解绑
check_sns_unbound() {
  log "🔍 检查 SNS 通知是否解绑"
  local asgs
  asgs=$(aws autoscaling describe-auto-scaling-groups \
    --region "$REGION" --profile "$PROFILE" \
    --query "AutoScalingGroups[?starts_with(AutoScalingGroupName, '$ASG_PREFIX')].AutoScalingGroupName" \
    --output text)
  if [ -z "$asgs" ]; then
    log "✅ 未找到匹配的 ASG, SNS 绑定已解除"
  else
    local asg
    for asg in $asgs; do
      local ncount
      ncount=$(aws autoscaling describe-auto-scaling-groups \
        --region "$REGION" --profile "$PROFILE" \
        --auto-scaling-group-names "$asg" \
        --query 'AutoScalingGroups[0].NotificationConfigurations' \
        --output json | jq length)
      if [ "$ncount" -eq 0 ]; then
        log "✅ ASG $asg 未配置通知"
      else
        log "❌ ASG $asg 仍存在通知绑定"
      fi
    done
  fi
}

# === 主流程 ===
delete_log_group
check_nat_gateway_deleted
check_alb_deleted
check_eks_cluster_deleted
check_sns_unbound
log "✅ Post teardown checks completed"
