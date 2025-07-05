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

# === 主流程 ===
delete_log_group
