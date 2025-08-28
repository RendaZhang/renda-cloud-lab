#!/usr/bin/env bash
# ------------------------------------------------------------
# pre-teardown.sh — 在 stop-all / terraform destroy 之前执行
# 目的:
#   1) 删除所有 ALB 类型的 Ingress, 触发 ALBC 优雅回收云侧 ALB/TG
#   2) 卸载 AWS Load Balancer Controller (Helm)
#   3) (可选) 卸载 metrics-server
# 设计: 幂等、安全
# ------------------------------------------------------------
set -euo pipefail

# ====== 可通过环境变量覆盖 ======
REGION="${REGION:-us-east-1}"
PROFILE="${PROFILE:-phase2-sso}"
CLUSTER_NAME="${CLUSTER_NAME:-dev}"
ALBC_NAMESPACE="${ALBC_NAMESPACE:-kube-system}"
ALBC_RELEASE="${ALBC_RELEASE:-aws-load-balancer-controller}"
UNINSTALL_METRICS_SERVER="${UNINSTALL_METRICS_SERVER:-false}"   # true 则卸载 metrics-server
WAIT_ALB_DELETION_TIMEOUT="${WAIT_ALB_DELETION_TIMEOUT:-180}"  # 最多等待 180s 让 ALB 被回收

# ADOT Collector（OpenTelemetry Collector）可选卸载
ADOT_NAMESPACE="${ADOT_NAMESPACE:-observability}"
ADOT_RELEASE="${ADOT_RELEASE:-adot-collector}"
UNINSTALL_ADOT_COLLECTOR="${UNINSTALL_ADOT_COLLECTOR:-false}"   # true 则卸载 ADOT Collector

export AWS_PROFILE="$PROFILE"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
die() { log "❌ $*"; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "未找到命令: $1"; }

# ====== 依赖检查 ======
need aws
need kubectl
need helm
need jq

# ====== 确认集群可连通 ======
log "🔗 配置 kubeconfig：cluster=${CLUSTER_NAME}, region=${REGION}, profile=${PROFILE}"
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"
kubectl version >/dev/null || die "kubectl 无法连接到集群（请检查 EKS 状态与凭证）"

# ====== 自动发现 ALB 类型的 Ingress ======
discover_alb_ingress() {
  # 识别条件：
  # 1) spec.ingressClassName == "alb"
  # 2) 或旧式注解 kubernetes.io/ingress.class == "alb"
  kubectl get ingress -A -o json \
  | jq -r '.items[]
      | select((.spec.ingressClassName=="alb")
               or (.metadata.annotations["kubernetes.io/ingress.class"]=="alb"))
      | "\(.metadata.namespace)/\(.metadata.name)"'
}

ING_LIST=()
while IFS= read -r line; do [[ -n "$line" ]] && ING_LIST+=("$line"); done < <(discover_alb_ingress || true)

if [[ ${#ING_LIST[@]} -eq 0 ]]; then
  log "ℹ️ 未发现 ingressClass=alb 的 Ingress（可能之前已清理或未创建）。"
else
  log "🗑️  删除以下 ALB Ingress（触发优雅回收 ALB/TG）："
  printf '    - %s\n' "${ING_LIST[@]}"

  for item in "${ING_LIST[@]}"; do
    ns="${item%/*}"; name="${item#*/}"
    kubectl -n "$ns" delete ingress "$name" --ignore-not-found
    # 等待对象被 Kubernetes 删除（对象层面）；云侧 ALB 回收在下一步统一等待
    kubectl -n "$ns" wait --for=delete ingress/"$name" --timeout=60s || true
  done
fi

# ====== 等待云侧 ALB 回收（由 ALBC Finalizer 触发） ======
count_cluster_albs() {
  # 通过标签判断属于本集群的 ALB：
  #   elbv2.k8s.aws/cluster = <CLUSTER_NAME>  或  kubernetes.io/cluster/<CLUSTER_NAME> = owned|shared
  local lb_arns
  lb_arns=$(aws elbv2 describe-load-balancers --region "$REGION" \
              --query 'LoadBalancers[].LoadBalancerArn' --output text 2>/dev/null | tr '\t' '\n' || true)
  local cnt=0
  for arn in $lb_arns; do
    # 取标签并判断是否匹配
    local tags_json owned
    tags_json=$(aws elbv2 describe-tags --resource-arns "$arn" --region "$REGION" 2>/dev/null || echo '{}')
    owned=$(jq -r --arg c "$CLUSTER_NAME" '
      .TagDescriptions[0].Tags as $t
      | ([$t[] | select(.Key=="elbv2.k8s.aws/cluster" and .Value==$c)] | length > 0)
        or
        ([$t[] | select(.Key=="kubernetes.io/cluster/"+$c)] | length > 0)
    ' <<<"$tags_json" 2>/dev/null || echo "false")
    [[ "$owned" == "true" ]] && cnt=$((cnt+1))
  done
  echo "$cnt"
}

if [[ ${#ING_LIST[@]} -gt 0 ]]; then
  log "⏳ 等待最多 ${WAIT_ALB_DELETION_TIMEOUT}s 以让 ALB Controller 回收云侧 ALB..."
  SECONDS=0
  while true; do
    left=$(count_cluster_albs)
    log "   剩余与集群(${CLUSTER_NAME})相关的 ALB 数量：$left"
    if [[ "$left" -eq 0 ]]; then
      log "✅ ALB 已回收完成"
      break
    fi
    if (( SECONDS >= WAIT_ALB_DELETION_TIMEOUT )); then
      log "⚠️ 超时未完全回收（后续由 post-teardown.sh 兜底强删），继续下一步"
      break
    fi
    sleep 10
  done
else
  log "ℹ️ 无需等待 ALB 回收（未发现 ALB Ingress）"
fi

# ====== 卸载 AWS Load Balancer Controller（Helm） ======
log "🧹 卸载 Helm release: ${ALBC_RELEASE} (ns=${ALBC_NAMESPACE})"
helm -n "$ALBC_NAMESPACE" uninstall "$ALBC_RELEASE" || true

# 保险起见，确保 Deployment 消失（在 Helm 卸载后通常已不存在）
kubectl -n "$ALBC_NAMESPACE" delete deploy "$ALBC_RELEASE" --ignore-not-found

# ====== （可选）卸载 metrics-server ======
if [[ "$UNINSTALL_METRICS_SERVER" == "true" ]]; then
  log "🧹 卸载 metrics-server (可选)"
  helm -n kube-system uninstall metrics-server || true
  kubectl -n kube-system delete deploy metrics-server --ignore-not-found
else
  log "ℹ️ 未启用 UNINSTALL_METRICS_SERVER，跳过卸载 metrics-server"
fi

# ====== （可选）卸载 ADOT Collector ======
if [[ "$UNINSTALL_ADOT_COLLECTOR" == "true" ]]; then
  log "🧹 卸载 ADOT Collector (release=${ADOT_RELEASE}, ns=${ADOT_NAMESPACE})"
  helm -n "$ADOT_NAMESPACE" uninstall "$ADOT_RELEASE" || true
  kubectl -n "$ADOT_NAMESPACE" delete deploy "${ADOT_RELEASE}-opentelemetry-collector" --ignore-not-found
else
  log "ℹ️ 未启用 UNINSTALL_ADOT_COLLECTOR，跳过卸载 ADOT Collector"
fi

log "✅ pre-teardown 完成：Ingress 已删除、ALB Controller 已卸载（ALB 若仍残留将由 post-teardown 兜底清理）"
