#!/bin/bash
set -e

echo "更新架构图..."
cd infra/aws

# 刷新 Terraform 状态
terraform init -upgrade -reconfigure
terraform refresh -input=false

# 生成新图表
terraform graph > ../../diagrams/terraform-architecture.dot
terraform graph | dot -Tsvg > ../../diagrams/terraform-architecture.svg
terraform graph | dot -Tpng > ../../diagrams/terraform-architecture.png

echo "图表已更新到 diagrams/ 目录"
