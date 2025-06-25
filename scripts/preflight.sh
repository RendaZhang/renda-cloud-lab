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

echo -e "AWS_PROFILE=$PROFILE\nAWS_REGION=$REGION" | tee preflight.txt
echo "---------------- Quota Check ----------------" | tee -a preflight.txt

for code in "${!QUOTAS[@]}"; do
  svc="${CODES[$code]}"

  value=$(aws --profile "$PROFILE" --region "$REGION" \
              service-quotas get-service-quota \
              --service-code "$svc" --quota-code "$code" \
              --query 'Quota.Value' --output text \
              2>/dev/null || echo "N/A")

  printf "%-30s\t%s\n" "${QUOTAS[$code]}" "${value}" | tee -a preflight.txt
done
