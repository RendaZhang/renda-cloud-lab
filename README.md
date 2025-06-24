# Renda Cloud Lab

> *专注于云计算技术研究与开发的开源实验室，提供高效、灵活的云服务解决方案，支持多场景应用。*

<p align="center">
  <img src="https://img.shields.io/badge/AWS-EKS%20%7C%20Terraform%20%7C%20Helm-232F3E?logo=amazonaws&logoColor=white" />
  <img src="https://img.shields.io/badge/License-MIT-blue.svg" />
  <img src="https://img.shields.io/badge/Status-Active-brightgreen" />
</p>

**Renda Cloud Lab** 是一个持续演进的实验型代码库，聚焦云原生基础设施、自动化运维与 AI 工作负载集成。仓库内容围绕以下主题展开：

* **IaC (Infrastructure as Code)** — Terraform、eksctl、Pulumi、GitOps
* **容器编排** — Kubernetes、Helm、Argo CD、Karpenter
* **可观测性与 SRE** — OpenTelemetry、Prometheus、Grafana、Chaos Engineering
* **生成式 AI Sidecar** — Spring AI + AWS Bedrock / Vertex AI
* **成本与安全护栏** — Spot、IRSA、Budgets、Trivy、OPA Gatekeeper

本仓库倾向于 **“代码优先”**：只存放可运行的脚本、模块与架构图；文字笔记与文章另行维护。

---

## 🗂 目录结构

```text
├─ infra/                  # IaC 模块与环境定义
│  └─ aws/                 #  ├─ Terraform backend / providers / vars
├─ charts/                 # Helm Charts（按功能拆分）
├─ scripts/                # 一键启停 / 自动化工具
├─ diagrams/               # 架构图（PlantUML / PNG）
├─ .github/workflows/      # GitHub Actions — CI / CD / Lint / Plan
└─ README.md
```

| 目录             | 说明                                              |
| -------------- | ----------------------------------------------- |
| **infra/aws/** | S3 + DynamoDB 远端状态，Region = `ap-southeast-1`    |
| **charts/**    | 业务与系统 Helm Chart，遵循 OCI 规范                      |
| **scripts/**   | `scale-nodegroup-zero.sh`、`clean-up.sh` 等成本控制脚本 |
| **diagrams/**  | 系统架构与流量拓扑图（Mermaid / PlantUML）                  |

---

## 🚀 快速开始

```bash
# 克隆仓库（示例使用 Gitee，GitHub 自动镜像）
$ git clone git@gitee.com:<your-id>/renda-cloud-lab.git
$ cd renda-cloud-lab

# 初始化 Terraform backend
$ cd infra/aws && terraform init && terraform plan

# 部署实验集群 / 关闭
$ bash scripts/provision-cluster.sh   # 部署
$ bash scripts/scale-nodegroup-zero.sh   # 休眠
```

### 前置条件

* AWS 账户 & CLI (`aws configure`)
* 已创建远端 S3 Bucket 与 DynamoDB Lock Table
* IAM `eks-admin-role` ARN 写入 `terraform.tfvars`

---

## 💰 成本护栏

| 资源            | 策略                                       | 估算/月\*            |
| ------------- | ---------------------------------------- | ----------------- |
| **EKS 控制面**   | 实验时段启用，非活动期 `scale 0` / `delete cluster` | \~US \$20 – \$30  |
| **NodeGroup** | Spot + Auto Scaler                       | 视实验强度动态变化         |
| **监控 / AI**   | `sample_limit`、Budget Alarm              | 可控制在 \~US \$20 以内 |

\* 以上数字基于 ap-southeast-1 区域估算，仅供参考。

---

## 🛠 技术栈（核心组件）

| 类别            | 组件                                                                |
| ------------- | ----------------------------------------------------------------- |
| IaC           | Terraform 1.8, eksctl 0.180                                       |
| 容器            | Docker 26, Kubernetes 1.33                                        |
| GitOps        | Helm v3, Argo CD 2.10                                             |
| Observability | OpenTelemetry Collector, Amazon Managed Prometheus, Grafana Cloud |
| Chaos         | Chaos Mesh 2.7                                                    |
| AI Sidecar    | Spring AI, AWS Bedrock (Titan), LangChain4j                       |

---

## 🤝 贡献指南

1. Fork ➜ 新建分支 ➜ 提 PR
2. 通过 `pre-commit`（`terraform fmt` / `tflint` / `yamllint`）
3. CI 通过后 Maintainer 合并

欢迎提交 **实验脚本、模块、架构图** 或改进成本护栏的想法。如需讨论，请开启 Issue 并附上背景与设计思路。

---

## 📜 许可证

本仓库采用 **[MIT License](LICENSE)**，欢迎自由使用与二次创作。

---

> ⏰ **Maintainer**：@Renda — 如果本项目对你有帮助，请点 ⭐ Star 支持！
