#!/usr/bin/env bash
set -eu
# change PROFILE and REGION as needed
PROFILE=phase2-sso
REGION=us-east-1

# QuotaCode : Human-Readable Name
declare -A QUOTAS=(
  # The maximum number of network interfaces per Availability Zone in a Region.
  [L-DF5E4CA3]="Network ENI / Region"
  # The maximum number of security groups per network interface. The maximum is 16. This quota, multiplied by the quota for rules per security group, cannot exceed 1000.
  [L-2AFB9258]="SG per ENI"
  # Maximum number of vCPUs assigned to the Running On-Demand Standard (A, C, D, H, I, M, R, T, Z) instances.
  [L-1216C47A]="OnDemand vCPU"
  # The maximum number of vCPUs for all running or requested Standard (A, C, D, H, I, M, R, T, Z) Spot Instances per Region
  [L-34B43A08]="Spot vCPU"
  # The maximum number of VPCs per Region. This quota is directly tied to the maximum number of internet gateways per Region.
  [L-F678F1CE]="VPCs per Region"
  # The maximum number of Application Load Balancers per Region
  [L-53DA6B97]="ALB per Region"
  # The maximum number of Elastic IP addresses that you can allocate for EC2-VPC in this Region.
  [L-0263D0A3]="EC2-VPC Elastic IPs"
)

# This script checks the AWS service quotas for the PROFILE in REGION.
# It retrieves the quotas for various resources and outputs them in a human-readable format.
for code in "${!QUOTAS[@]}"; do
  svc=$( [[ $code == L-D* || $code == L-2A* ]] && echo vpc || echo ec2 )

  value=$(aws --profile "$PROFILE" --region "$REGION" \
          service-quotas get-service-quota \
          --service-code "$svc" --quota-code "$code" \
          --query 'Quota.Value' --output text 2>/dev/null || echo "N/A")

  echo -e "${QUOTAS[$code]}:\t${value}"
done | tee preflight.txt
