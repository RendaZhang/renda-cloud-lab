#!/usr/bin/env bash
# ------------------------------------------------------------
# Renda Cloud Lab · preflight.sh
#
# 功能：
#   1. 校验本地 AWS CLI SSO 凭证有效性
#   2. 读取关键 Service Quota 上限（Quota.Value）
#   3. 将结果打印到终端并同步写入 preflight.txt
#
# 使用：
#   bash scripts/preflight.sh
#   或 make preflight   # 如果已在 Makefile 注册
# ------------------------------------------------------------

set -eu

# -------- 基本参数（如需改 profile/region 在此改） --------
PROFILE="phase2-sso"
REGION="us-east-1"

# -------- QuotaCode → 描述映射表 --------
# 填写时务必确认对应 service-code, 见 CODES[] 映射
declare -A QUOTAS=(
  [L-DF5E4CA3]="Network ENI / Region"              # VPC
  [L-2AFB9258]="SG per ENI"                        # VPC
  [L-1216C47A]="OnDemand vCPU (Std family)"        # EC2
  [L-34B43A08]="Spot vCPU (Std family)"            # EC2
  [L-F678F1CE]="VPCs per Region"                   # VPC
  [L-53DA6B97]="ALB per Region"                    # Elastic Load Balancing
  [L-0263D0A3]="EC2-VPC Elastic IPs"               # EC2
)

# QuotaCode → service-code （必须准确）
declare -A CODES=(
  [L-DF5E4CA3]="vpc"
  [L-2AFB9258]="vpc"
  [L-F678F1CE]="vpc"
  [L-1216C47A]="ec2"
  [L-34B43A08]="ec2"
  [L-0263D0A3]="ec2"
  [L-53DA6B97]="elasticloadbalancing"
)

# -------- 需要统计“已用量”的配额 → 计算函数映射表 --------
# 语法： [QuotaCode]=函数名   —— 下面会写对应 shell 函数
declare -A CALC_FUNCS=(
  [L-DF5E4CA3]=eni_used             # Network ENI / Region
  [L-53DA6B97]=alb_used             # ALB / Region
  [L-0263D0A3]=eip_used             # Elastic IP / Region
  [L-1216C47A]=vcpu_on_demand_used  # On-Demand vCPU
  [L-34B43A08]=vcpu_spot_used       # Spot vCPU
)

# =========  已用量计算函数 =========
# 如需 jq 请提前 `sudo apt install jq` (或 brew install jq)

# 1) 已用 Network Interface 数
eni_used() {
  aws --profile "$PROFILE" --region "$REGION" \
      ec2 describe-network-interfaces \
      --filters Name=status,Values=in-use \
      --query 'length(NetworkInterfaces)' --output text
}

# 2) 已用 Application Load Balancer 数量
alb_used() {
  aws --profile "$PROFILE" --region "$REGION" \
      elbv2 describe-load-balancers \
      --query 'length(LoadBalancers)' --output text
}

# 3) 已分配 Elastic IP 总数
eip_used() {
  aws --profile "$PROFILE" --region "$REGION" \
      ec2 describe-addresses \
      --query 'length(Addresses)' --output text
}

# 4) 正在运行的 On-Demand 实例 vCPU
vcpu_on_demand_used() {
  aws --profile "$PROFILE" --region "$REGION" \
      ec2 describe-instances \
      --filters Name=instance-state-name,Values=pending,running \
               Name=instance-lifecycle,Values=on-demand \
      --query 'sum(Reservations[].Instances[].CpuOptions.CoreCount * Reservations[].Instances[].CpuOptions.ThreadsPerCore)' \
      --output text
}

# 5) 正在运行的 Spot 实例 vCPU
vcpu_spot_used() {
  aws --profile "$PROFILE" --region "$REGION" \
      ec2 describe-instances \
      --filters Name=instance-state-name,Values=pending,running \
               Name=instance-lifecycle,Values=spot \
      --query 'sum(Reservations[].Instances[].CpuOptions.CoreCount * Reservations[].Instances[].CpuOptions.ThreadsPerCore)' \
      --output text
}
# =========  计算函数结束 =========


echo -e "AWS_PROFILE=$PROFILE\nAWS_REGION=$REGION" | tee preflight.txt
echo "---------------- Quota Check ----------------" | tee -a preflight.txt

for code in "${!QUOTAS[@]}"; do
  svc="${CODES[$code]}"

  # ① 取配额上限 (Limit)
  limit=$(aws --profile "$PROFILE" --region "$REGION" \
              service-quotas get-service-quota \
              --service-code "$svc" --quota-code "$code" \
              --query 'Quota.Value' --output text 2>/dev/null || echo "N/A")

  # ② 计算已用量 (Used) —— 只有在 CALC_FUNCS 中映射的配额才计算
  if [[ -n ${CALC_FUNCS[$code]-} ]]; then
    used=$(${CALC_FUNCS[$code]} 2>/dev/null || echo "N/A")
  else
    used="-"
  fi

  # ③ 计算剩余额度 (Left)
  if [[ $limit != "N/A" && $used != "N/A" && $used != "-" ]]; then
    # 使用 bc 做浮点减法；若系统无 bc，可 apt / brew 安装
    left=$(bc <<< "$limit - $used")
  else
    left="-"
  fi

  # ④ 打印 + 写文件
  printf "%-30s %8s (limit) | %6s used | %6s left\n" \
         "${QUOTAS[$code]}" "$limit" "$used" "$left"
done | tee -a preflight.txt
echo "---------------------------------------------" | tee -a preflight.txt
