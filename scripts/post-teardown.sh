#!/usr/bin/env bash
# ------------------------------------------------------------
# Renda Cloud Lab · post-teardown.sh
# 功能: 在 IaC 销毁后兜底清理仍可能计费的资源（ALB/TargetGroup/SG 等）
# Usage:
#   bash scripts/post-teardown.sh
#   DRY_RUN=true bash scripts/post-teardown.sh   # 预演，不执行删除
# ------------------------------------------------------------
set -euo pipefail

# ===== 可通过环境变量覆盖 =====
REGION="${REGION:-us-east-1}"
PROFILE="${PROFILE:-phase2-sso}"
CLUSTER_NAME="${CLUSTER_NAME:-dev}"

# 可选：名称/前缀（保留你的原有变量）
LOG_GROUP="${LOG_GROUP:-/aws/eks/${CLUSTER_NAME}/cluster}"
NAT_NAME="${NAT_NAME:-lab-nat}"
ASG_PREFIX="${ASG_PREFIX:-eks-ng-mixed}"

# 预演模式（只打印不删）
DRY_RUN="${DRY_RUN:-false}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log "DRY-RUN: $*"
  else
    eval "$@"
  fi
}

# ---------- 基础探测 ----------
cluster_exists() {
  aws eks describe-cluster \
    --name "$CLUSTER_NAME" --region "$REGION" --profile "$PROFILE" >/dev/null 2>&1
}

# ---------- CloudWatch 日志组 ----------
delete_log_group() {
  log "🧹 清理 CloudWatch Log Group: $LOG_GROUP"
  if aws logs describe-log-groups \
        --log-group-name-prefix "$LOG_GROUP" \
        --region "$REGION" --profile "$PROFILE" \
        | grep -q "\"logGroupName\": \"$LOG_GROUP\""; then
    run "aws logs delete-log-group --log-group-name \"$LOG_GROUP\" --region \"$REGION\" --profile \"$PROFILE\""
    log "✅ 已删除日志组 $LOG_GROUP"
  else
    log "ℹ️ 日志组 $LOG_GROUP 不存在，跳过"
  fi
}

# ---------- 兜底删除：ALB / TargetGroup / SG ----------
# 说明：
# - 依据标签删除，避免误伤。匹配以下两类标签任意其一即视为本集群资源：
#   * elbv2.k8s.aws/cluster = $CLUSTER_NAME
#   * kubernetes.io/cluster/$CLUSTER_NAME = (owned|shared)
delete_alb_and_tg_for_cluster() {
  log "🧹 扫描并删除属于集群 ${CLUSTER_NAME} 的 ALB 与 TargetGroups ..."

  # 列出所有 ALB ARNs
  mapfile -t LB_ARNS < <(aws elbv2 describe-load-balancers \
    --region "$REGION" --profile "$PROFILE" \
    --query 'LoadBalancers[].LoadBalancerArn' --output text 2>/dev/null | tr '\t' '\n' | sed '/^$/d')

  local to_delete_lbs=()
  for arn in "${LB_ARNS[@]:-}"; do
    # 读取标签
    local tags_json
    tags_json=$(aws elbv2 describe-tags --resource-arns "$arn" \
      --region "$REGION" --profile "$PROFILE" 2>/dev/null || echo '{}')

    # 判断是否属于本集群
    local owned
    owned=$(jq -r --arg c "$CLUSTER_NAME" '
      .TagDescriptions[0].Tags as $t
      | ([$t[] | select(.Key=="elbv2.k8s.aws/cluster" and .Value==$c)] | length > 0)
        or
        ([$t[] | select(.Key=="kubernetes.io/cluster/"+$c)] | length > 0)
      ' <<<"$tags_json" 2>/dev/null || echo "false")

    if [[ "$owned" == "true" ]]; then
      to_delete_lbs+=("$arn")
    fi
  done

  if [[ ${#to_delete_lbs[@]} -eq 0 ]]; then
    log "ℹ️ 未发现与集群 ${CLUSTER_NAME} 相关的 ALB"
  else
    log "🔎 发现 ${#to_delete_lbs[@]} 个 ALB 待删除"
    for lb_arn in "${to_delete_lbs[@]}"; do
      local lb_name
      lb_name=$(aws elbv2 describe-load-balancers --load-balancer-arns "$lb_arn" \
        --region "$REGION" --profile "$PROFILE" \
        --query 'LoadBalancers[0].LoadBalancerName' --output text 2>/dev/null || echo "$lb_arn")
      log "➡️ 删除 ALB: $lb_name"

      # 记录与该 LB 关联的 Target Groups，LB 删除后再删 TG
      mapfile -t LBTGS < <(aws elbv2 describe-target-groups \
        --load-balancer-arn "$lb_arn" \
        --region "$REGION" --profile "$PROFILE" \
        --query 'TargetGroups[].TargetGroupArn' --output text 2>/dev/null | tr '\t' '\n' | sed '/^$/d')

      run "aws elbv2 delete-load-balancer --load-balancer-arn \"$lb_arn\" --region \"$REGION\" --profile \"$PROFILE\""

      # 等待 LB 删除完成（轮询 30 次，每次 5 秒）
      for i in {1..30}; do
        if aws elbv2 describe-load-balancers --load-balancer-arns "$lb_arn" \
             --region "$REGION" --profile "$PROFILE" >/dev/null 2>&1; then
          sleep 5
        else
          break
        fi
      done

      # 删除与之关联的 Target Groups
      for tg in "${LBTGS[@]:-}"; do
        log "   ↳ 删除 TargetGroup: $tg"
        run "aws elbv2 delete-target-group --target-group-arn \"$tg\" --region \"$REGION\" --profile \"$PROFILE\" || true"
      done
    done
  fi

  # 再次兜底：清除“属于本集群且未被使用”的 TG
  log "🧹 清理遗留的、带集群标签的孤儿 TargetGroups ..."
  mapfile -t TG_ARNS < <(aws elbv2 describe-target-groups \
    --region "$REGION" --profile "$PROFILE" \
    --query 'TargetGroups[].TargetGroupArn' --output text 2>/dev/null | tr '\t' '\n' | sed '/^$/d')

  for tg_arn in "${TG_ARNS[@]:-}"; do
    local tg_desc tg_lbs tg_tags_json attach_cnt is_owned
    tg_desc=$(aws elbv2 describe-target-groups --target-group-arns "$tg_arn" \
      --region "$REGION" --profile "$PROFILE" 2>/dev/null || echo '{}')
    attach_cnt=$(jq -r '.TargetGroups[0].LoadBalancerArns | length' <<<"$tg_desc" 2>/dev/null || echo "0")

    tg_tags_json=$(aws elbv2 describe-tags --resource-arns "$tg_arn" \
      --region "$REGION" --profile "$PROFILE" 2>/dev/null || echo '{}')
    is_owned=$(jq -r --arg c "$CLUSTER_NAME" '
      .TagDescriptions[0].Tags as $t
      | ([$t[] | select(.Key=="elbv2.k8s.aws/cluster" and .Value==$c)] | length > 0)
        or
        ([$t[] | select(.Key=="kubernetes.io/cluster/"+$c)] | length > 0)
      ' <<<"$tg_tags_json" 2>/dev/null || echo "false")

    if [[ "$is_owned" == "true" && "$attach_cnt" -eq 0 ]]; then
      log "   ↳ 删除孤儿 TargetGroup: $tg_arn"
      run "aws elbv2 delete-target-group --target-group-arn \"$tg_arn\" --region \"$REGION\" --profile \"$PROFILE\" || true"
    fi
  done
}

delete_alb_security_groups() {
  log "🧹 清理由 ALB Controller 创建、并打了集群标签的安全组 ..."

  # 1) 通过 elbv2.k8s.aws/cluster=<cluster> 标签筛选
  mapfile -t SG1 < <(aws ec2 describe-security-groups \
    --region "$REGION" --profile "$PROFILE" \
    --filters "Name=tag:elbv2.k8s.aws/cluster,Values=${CLUSTER_NAME}" \
    --query 'SecurityGroups[].GroupId' --output text 2>/dev/null | tr '\t' '\n' | sed '/^$/d')

  # 2) 通过 kubernetes.io/cluster/<cluster> 标签键筛选
  mapfile -t SG2 < <(aws ec2 describe-security-groups \
    --region "$REGION" --profile "$PROFILE" \
    --filters "Name=tag-key,Values=kubernetes.io/cluster/${CLUSTER_NAME}" \
    --query 'SecurityGroups[].GroupId' --output text 2>/dev/null | tr '\t' '\n' | sed '/^$/d')

  # 去重
  declare -A SEEN; local sgs=()
  for id in "${SG1[@]:-}" "${SG2[@]:-}"; do
    [[ -n "${id:-}" && -z "${SEEN[$id]:-}" ]] && SEEN[$id]=1 && sgs+=("$id")
  done

  if [[ ${#sgs[@]} -eq 0 ]]; then
    log "ℹ️ 未发现需要清理的安全组"
    return
  fi

  for sg in "${sgs[@]}"; do
    # 确保 SG 未被引用/未附着 ENI，否则删除会失败
    local attached
    attached=$(aws ec2 describe-network-interfaces \
      --region "$REGION" --profile "$PROFILE" \
      --filters "Name=group-id,Values=${sg}" \
      --query 'NetworkInterfaces | length(@)' --output text 2>/dev/null || echo "0")

    if [[ "$attached" != "0" ]]; then
      log "   ⚠️ 安全组 $sg 仍被 ${attached} 个 ENI 引用，跳过"
      continue
    fi

    log "   ↳ 删除安全组: $sg"
    run "aws ec2 delete-security-group --group-id \"$sg\" --region \"$REGION\" --profile \"$PROFILE\" || true"
  done
}

# ---------- 只做检查（不删）的保留项 ----------
check_nat_gateway_deleted() {
  log "🔍 检查 NAT 网关 ${NAT_NAME} 是否已删除"
  local count
  count=$(aws ec2 describe-nat-gateways \
    --region "$REGION" --profile "$PROFILE" \
    --filter "Name=tag:Name,Values=${NAT_NAME}" \
    --query "NatGateways[?State!='deleted'] | length(@)" --output text 2>/dev/null || echo "0")
  if [[ "$count" == "0" ]]; then
    log "✅ NAT 网关已删除"
  else
    log "❌ NAT 网关仍存在，请检查 IaC 或控制台"
  fi
}

check_eks_cluster_deleted() {
  log "🔍 检查 EKS 集群 ${CLUSTER_NAME} 是否已删除"
  if aws eks describe-cluster --name "$CLUSTER_NAME" \
       --region "$REGION" --profile "$PROFILE" >/dev/null 2>&1; then
    log "❌ EKS 集群仍存在"
  else
    log "✅ EKS 集群已删除"
  fi
}

check_sns_unbound() {
  log "🔍 检查 ASG 的 SNS 通知是否解绑（前缀：${ASG_PREFIX}）"
  local asgs
  asgs=$(aws autoscaling describe-auto-scaling-groups \
    --region "$REGION" --profile "$PROFILE" \
    --query "AutoScalingGroups[?starts_with(AutoScalingGroupName, '${ASG_PREFIX}')].AutoScalingGroupName" \
    --output text 2>/dev/null)
  if [[ -z "${asgs:-}" ]]; then
    log "✅ 未找到匹配的 ASG, SNS 绑定已解除"
  else
    local asg
    for asg in $asgs; do
      local ncount
      ncount=$(aws autoscaling describe-auto-scaling-groups \
        --region "$REGION" --profile "$PROFILE" \
        --auto-scaling-group-names "$asg" \
        --query 'AutoScalingGroups[0].NotificationConfigurations | length(@)' \
        --output text 2>/dev/null || echo "0")
      if [[ "$ncount" == "0" ]]; then
        log "✅ ASG ${asg} 未配置通知"
      else
        log "❌ ASG ${asg} 仍存在通知绑定"
      fi
    done
  fi
}

# ========== 主流程 ==========
if cluster_exists; then
  log "⚠️ 检测到 EKS 集群 ${CLUSTER_NAME} 仍存在，疑似未执行销毁操作；为避免误删，脚本退出。"
  exit 0
fi

delete_log_group
delete_alb_and_tg_for_cluster
delete_alb_security_groups
check_nat_gateway_deleted
check_eks_cluster_deleted
check_sns_unbound
log "✅ Post teardown cleanup completed"
