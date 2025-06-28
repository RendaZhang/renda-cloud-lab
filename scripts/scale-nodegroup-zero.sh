#!/bin/bash

set -euo pipefail

CLUSTER_NAME="dev"
REGION="us-east-1"
PROFILE="phase2-sso"

echo "🔍 获取 NodeGroup 列表中..."

NODEGROUPS=$(aws eks list-nodegroups \
  --cluster-name "$CLUSTER_NAME" \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query 'nodegroups' --output text)

if [[ -z "$NODEGROUPS" ]]; then
  echo "❌ 未找到任何 NodeGroup，终止操作。"
  exit 1
fi

for NG in $NODEGROUPS; do
  echo "📦 当前处理节点组：$NG"

  echo "🔄 更新 NodeGroup [$NG] DesiredSize = 0 ..."
  aws eks update-nodegroup-config \
    --cluster-name "$CLUSTER_NAME" \
    --nodegroup-name "$NG" \
    --scaling-config minSize=0,maxSize=1,desiredSize=0 \
    --region "$REGION" \
    --profile "$PROFILE" > /dev/null

  echo "✅ [$NG] 缩容请求已提交。"
done

echo "🎉 所有托管节点组已缩容至 0 完成。"
