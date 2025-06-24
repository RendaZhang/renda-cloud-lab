# Renda Cloud Lab

> **目标**：8 周跑通 Docker → EKS → GitOps → Chaos → Observability → Bedrock Sidecar  
> **账单护栏**：AWS ≤ ¥1 500（常规 ≤ ¥600）

## 目录导航
| 目录 | 说明 |
|------|------|
| `infra/aws/` | Terraform & eksctl 配置 |
| `charts/` | Helm Chart – Task Manager |
| `docs/` | Day-x 学习笔记、截图 |
| `scripts/` | 一键启停 / 清理脚本 |
| `.github/workflows/` | GitHub Actions (CI / Plan) |

## 快速开始
```bash
# 1. 拉仓库
git clone git@gitee.com:<you>/java-cloudnative-sprint-2025.git
cd java-cloudnative-sprint-2025

# 2. 初始化 Terraform backend
cd infra/aws
terraform init && terraform plan

# 3. 创建 / 关闭集群示例
bash scripts/scale-nodegroup-zero.sh   # 周末关停
