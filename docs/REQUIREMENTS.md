<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
## 目录 (Table of Contents)

- [云原生实验室功能需求与规划](#%E4%BA%91%E5%8E%9F%E7%94%9F%E5%AE%9E%E9%AA%8C%E5%AE%A4%E5%8A%9F%E8%83%BD%E9%9C%80%E6%B1%82%E4%B8%8E%E8%A7%84%E5%88%92)
  - [简介](#%E7%AE%80%E4%BB%8B)
  - [已实现能力](#%E5%B7%B2%E5%AE%9E%E7%8E%B0%E8%83%BD%E5%8A%9B)
    - [基础设施](#%E5%9F%BA%E7%A1%80%E8%AE%BE%E6%96%BD)
    - [部署与自动化](#%E9%83%A8%E7%BD%B2%E4%B8%8E%E8%87%AA%E5%8A%A8%E5%8C%96)
    - [可观测性与 SRE](#%E5%8F%AF%E8%A7%82%E6%B5%8B%E6%80%A7%E4%B8%8E-sre)
    - [成本与安全](#%E6%88%90%E6%9C%AC%E4%B8%8E%E5%AE%89%E5%85%A8)
  - [待完成功能](#%E5%BE%85%E5%AE%8C%E6%88%90%E5%8A%9F%E8%83%BD)
  - [未来规划](#%E6%9C%AA%E6%9D%A5%E8%A7%84%E5%88%92)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# 云原生实验室功能需求与规划

- **Last Updated:** September 07, 2025, 01:00 (UTC+08:00)
- **作者:** 张人大（Renda Zhang）

---

## 简介

本文件用于跟踪 Renda Cloud Lab 的功能需求，记录已实现能力、待办事项与未来规划，便于后续扩展、兼容与维护。

---

## 已实现能力

### 基础设施

- 使用 Terraform 管理 AWS VPC、子网、NAT 网关、EKS 集群及相关 IAM/IRSA 资源。
- 通过 S3 Gateway Endpoint 与 AWS Budgets 提供网络优化与成本控制。

### 部署与自动化

- 提供脚本实现环境的每日重建与销毁，如 `post-recreate.sh`、`pre-teardown.sh`、`post-teardown.sh` 与 `scale-nodegroup-zero.sh`。
- 通过 Helm 安装 `cluster-autoscaler`、`aws-load-balancer-controller`、`metrics-server` 等关键组件。

### 可观测性与 SRE

- 集成 ADOT Collector 将指标写入 Amazon Managed Prometheus。
- 部署 Prometheus、Grafana，提供监控与可视化能力。
- 支持安装 Chaos Mesh 用于混沌工程实验。

### 成本与安全

- 集成 Spot 实例与 IRSA 以降低成本并最小化权限。
- 利用 AWS Budgets 和 S3 Gateway Endpoint 等手段加强成本与安全管理。

---

## 待完成功能

- 引入 Karpenter 以增强节点弹性伸缩能力。
- 构建 CI/CD 与 GitOps 流水线（AWS CodePipeline + Argo CD）。
- 引入 Kustomize 分层管理以提升配置复用与环境覆盖能力。
- 开发生成式 AI Sidecar（Spring AI + Bedrock/Vertex AI）。
- 探索使用 Pulumi 等其他 IaC 工具。
- 添加 Trivy 镜像扫描与 OPA Gatekeeper 策略以强化安全合规。

---

## 未来规划

- **环境区分与策略**：规划并区分 dev、prod 等环境，设计配置隔离与资源配额，为多环境治理打下基础。
- **集成完整 CI/CD 流水线**：结合 AWS CodePipeline 等服务，实现从代码提交到容器镜像构建、安全扫描、部署到 EKS 的端到端自动化流水线，并提供示例应用演示持续交付过程。
- **增强 GitOps 与发布策略**：在集群中部署 Argo CD 等工具，探索应用分组管理、蓝绿部署/金丝雀发布策略，以提高部署的弹性和可靠性。
- **AI Sidecar 实践**：开发并部署示例微服务，演示如何通过 Spring AI 将大型语言模型集成到云原生应用中。例如，基于 AWS Bedrock 的 Titan 模型或 GCP Vertex AI，实现智能客服、内容推荐等场景，并提供参考架构。
- **安全与合规**：增加更多安全措施和成本护栏，如使用 OPA Gatekeeper 编写策略约束 Kubernetes 资源配置、定期镜像漏洞扫描报告、自动化成本分析通知等，帮助使用者在实践中掌握云上治理技巧。
