<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
## 目录 (Table of Contents)

- [Renda Cloud Lab](#renda-cloud-lab)
  - [简介](#%E7%AE%80%E4%BB%8B)
  - [核心模块说明](#%E6%A0%B8%E5%BF%83%E6%A8%A1%E5%9D%97%E8%AF%B4%E6%98%8E)
  - [目录结构](#%E7%9B%AE%E5%BD%95%E7%BB%93%E6%9E%84)
  - [项目结构与职责分层原则](#%E9%A1%B9%E7%9B%AE%E7%BB%93%E6%9E%84%E4%B8%8E%E8%81%8C%E8%B4%A3%E5%88%86%E5%B1%82%E5%8E%9F%E5%88%99)
    - [Terraform 仅负责 Infra 层（集群基础设施）](#terraform-%E4%BB%85%E8%B4%9F%E8%B4%A3-infra-%E5%B1%82%E9%9B%86%E7%BE%A4%E5%9F%BA%E7%A1%80%E8%AE%BE%E6%96%BD)
    - [Helm 脚本负责部署层](#helm-%E8%84%9A%E6%9C%AC%E8%B4%9F%E8%B4%A3%E9%83%A8%E7%BD%B2%E5%B1%82)
    - [实践总结](#%E5%AE%9E%E8%B7%B5%E6%80%BB%E7%BB%93)
  - [安装部署指南](#%E5%AE%89%E8%A3%85%E9%83%A8%E7%BD%B2%E6%8C%87%E5%8D%97)
    - [前置条件](#%E5%89%8D%E7%BD%AE%E6%9D%A1%E4%BB%B6)
    - [基础设施部署](#%E5%9F%BA%E7%A1%80%E8%AE%BE%E6%96%BD%E9%83%A8%E7%BD%B2)
    - [集群启停管理](#%E9%9B%86%E7%BE%A4%E5%90%AF%E5%81%9C%E7%AE%A1%E7%90%86)
  - [常见问题 (FAQ)](#%E5%B8%B8%E8%A7%81%E9%97%AE%E9%A2%98-faq)
  - [附录](#%E9%99%84%E5%BD%95)
    - [文档](#%E6%96%87%E6%A1%A3)
    - [检查清单](#%E6%A3%80%E6%9F%A5%E6%B8%85%E5%8D%95)
    - [脚本清单](#%E8%84%9A%E6%9C%AC%E6%B8%85%E5%8D%95)
  - [未来计划](#%E6%9C%AA%E6%9D%A5%E8%AE%A1%E5%88%92)
  - [🤝 贡献指南](#-%E8%B4%A1%E7%8C%AE%E6%8C%87%E5%8D%97)
  - [🔐 License](#-license)
  - [📬 联系方式](#-%E8%81%94%E7%B3%BB%E6%96%B9%E5%BC%8F)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Renda Cloud Lab

- **最后更新**: August 17, 2025, 07:52 (UTC+08:00)
- **作者**: 张人大（Renda Zhang）

> *专注于云计算技术研究与开发的开源实验室，提供高效、灵活的云服务解决方案，支持多场景应用。*

<p align="center">
  <img src="https://img.shields.io/badge/AWS-EKS%20%7C%20Terraform%20%7C%20Helm-232F3E?logo=amazonaws&logoColor=white" />
  <img src="https://img.shields.io/badge/License-MIT-blue.svg" />
  <img src="https://img.shields.io/badge/Status-Active-brightgreen" />
</p>

---

## 简介

**Renda Cloud Lab** 实践了一套“每日自动销毁 -> 次日重建”的基础设施生命周期策略，以最大化节约 AWS 费用。云资源按需高效利用是本项目的重要考量。

**Renda Cloud Lab** 项目涵盖 **AWS 云服务、EKS、GitOps、可观测性、SRE 以及 AI Sidecar** 等前沿主题。

通过该实验室，开发者可以实践基础设施即代码、容器编排、持续交付、混沌工程和 AI 工作负载集成等技术场景。

---

## 核心模块说明

本项目围绕云原生领域的多个核心模块展开，包括但不限于：

- **IaC (Infrastructure as Code)** — 使用 `Terraform` 管理 AWS 基础设施，探索 `Pulumi` 等多种 IaC 实践。
- **容器 & 编排** — 基于 `Docker` 容器、`Kubernetes` (托管于 EKS) 进行应用部署，利用 Karpenter 实现弹性伸缩
- **CI/CD & GitOps** — 集成 `AWS CodePipeline` 持续集成流水线，结合 `Argo CD` 与 `Helm` 实现 `GitOps` 持续部署
- **可观测性 & SRE** — 引入 `OpenTelemetry`、`Prometheus`、`Grafana` 构建可观测体系，并通过 `Chaos Mesh` 落实 `Chaos Engineering`（混沌工程）实践
- **生成式 AI Sidecar** — 基于 `Spring Boot + Spring AI` 框架，集成 AWS Bedrock (如 Titan 大模型) / GCP Vertex AI 等生成式 AI 服务，实现应用智能化
- **成本 & 安全护栏** — 利用 Spot 实例、IRSA、AWS Budgets 控制成本，并通过 Trivy 镜像扫描、OPA Gatekeeper 策略等保障集群安全
- **自动扩缩容 (Cluster Autoscaler)** — 通过脚本式 `Helm` 安装 `cluster-autoscaler`，实现节点数量根据负载弹性伸缩
- **负载均衡控制器 (AWS Load Balancer Controller)** — Terraform 预置 IRSA 与 ServiceAccount，Helm 安装后即可管理 ALB Ingress

上述模块相互协作，构成了一个完整的云原生实验环境。

---

## 目录结构

```text
├─ infra/                # IaC 模块与环境定义
│  ├─ aws/               # Terraform 配置（backend / providers / vars 等）
│  └─ eksctl/            # eksctl YAML (legacy - optional)
├─ docs/                 # 设计与流程文档（如 lifecycle.md）
├─ scripts/              # 基础设施启停与自动化脚本（如一键部署、节点伸缩、清理等）
│  └─ logs/              # 执行日志输出目录（已在 .gitignore 中排除）
├─ diagrams/             # 架构图表（Terraform graph 可视化图）
└─ README.md
```

| 目录                     | 说明                                                               |
| ---------------------- | ------------------------------------------------------------------- |
| **infra/aws/**         | Terraform 模块（VPC、子网、NAT、ALB、EKS 等）和环境配置，远端状态保存在 S3/DynamoDB（默认 Region=`us-east-1`） |
| **infra/eksctl/**      | eksctl 配置（Legacy，可选，`create_eks=false` 时使用） |
| **docs/**              | 生命周期与流程说明文档，例如 `docs/lifecycle.md`（一键重建、Spot 绑定、清理指令等）   |
| **charts/**            | 应用和系统的 Helm Chart，遵循 OCI 制品规范，便于复用与扩展  |
| **scripts/**           | 脚本：如 `preflight.sh`（预检检查）、`tf-import.sh`（Terraform 导入） 等   |
| **diagrams/**          | 系统架构和流量拓扑图，帮助理解基础设施与应用关系   |
| **.github/workflows/** | GitHub Actions 配置，用于 CI 流水线（格式检查、Terraform Plan 等）  |

---

## 项目结构与职责分层原则

> Infra vs Deploy

本项目遵循云原生基础设施管理的标准分层设计，**明确将集群资源的创建与 Kubernetes 服务的部署进行解耦**，以提升可维护性、调试效率与后期扩展能力。

### Terraform 仅负责 Infra 层（集群基础设施）

Terraform 所管理的内容包括但不限于：

- VPC、子网、NAT 网关、路由表等网络资源；
- EKS 集群与托管 Node Group；
- IAM 角色与 IRSA；
- 安全组规则、服务配额与相关依赖。

Terraform 目标：**纯声明式 Infra、幂等、稳定、易重建、适合每日重建测试环境使用。**

### Helm 脚本负责部署层

所有 Kubernetes 层的应用部署，均由脚本 + Helm 完成，确保部署顺序清晰、调试灵活，避免 Terraform 状态污染。

- Helm Chart 管理 Kubernetes 原生控制器；
- 每次重建后刷新 kubeconfig 并统一部署所有控制器；
- 每个微服务都可以拥有独立 Chart 和 `values.yaml`，后期可切换至 Helmfile 或 ArgoCD。

### 实践总结

> Terraform 管控资源边界；Helm 与脚本部署工作负载。
> 两者职责清晰，互不耦合，是现代云原生团队通用的 Infra / App Layer 分离模式。

---

## 安装部署指南

以下指南将帮助你在自己的 AWS 账户中部署本实验环境，包括基础设施和示例应用的部署步骤。

### 前置条件

完整步骤参见 📄 [前置条件操作指南](https://github.com/RendaZhang/renda-cloud-lab/blob/master/docs/PREREQUISITES_GUIDE.md#%E5%89%8D%E7%BD%AE%E6%9D%A1%E4%BB%B6%E6%93%8D%E4%BD%9C%E6%8C%87%E5%8D%97)。

### 基础设施部署

**克隆仓库**：下载代码库到本地环境。

```bash
git clone https://github.com/RendaZhang/renda-cloud-lab.git
cd renda-cloud-lab
```

后续操作参考文档内容：📄 [云原生集群生命周期流程](https://github.com/RendaZhang/renda-cloud-lab/blob/master/docs/EKS_CLUSTER_LIFECYCLE_GUIDE.md)

### 集群启停管理

具体请参考文档内容：📄 [重建与销毁流程](https://github.com/RendaZhang/renda-cloud-lab/blob/master/docs/DAILY_REBUILD_TEARDOWN_GUIDE.md#terraform-%E9%87%8D%E5%BB%BA%E4%B8%8E%E9%94%80%E6%AF%81%E6%B5%81%E7%A8%8B%E6%93%8D%E4%BD%9C%E6%96%87%E6%A1%A3)

**日间启用，夜间销毁**：

通过 Makefile 脚本在每天早晨自动部署资源，夜间自动销毁计费资源。

此策略确保在活跃实验时段集群具备完整的网络出口和访问能力，而在闲置时段释放高成本资源。

基础设施的状态（如 VPC、数据存储和 Terraform 状态）会被保留，以便第二天快速重建。

**固定域名**：

借助 Route 53 的 Alias Record，将动态生成的负载均衡器 DNS 映射到固定域名（默认使用 `lab.rendazhang.com`）。

即使每天重新创建 ALB，其对外访问地址保持不变，用户和系统集成无需每日更新配置。

**弹性扩缩容**：

集群工作节点采用按需 **Spot 实例**（结合 Karpenter 或 Auto Scaling），根据负载自动伸缩。

**成本预算提醒**：

通过 Terraform 创建 AWS Budgets（默认 90 USD），当支出达到设定比例时会向指定邮箱发送警报。

通过以上措施，实验集群在确保功能完整的同时，将日常运行成本控制在低水平。

下表为启用成本控制策略下的主要资源月度费用估算：

| 资源                   | 策略                    | 估算/月               |
| -------------------- | --------------------- | ------------------ |
| **EKS 控制平面**         | 按需启用，闲置时段缩容或删除        | 约 $20 – $30 USD |
| **工作节点 (NodeGroup)** | Spot 实例 + 自动伸缩，根据负载调节 | 随实验强度动态变化          |
| **监控与 AI 辅助组件**      | 设置采样率上限、预算报警等         | 可控制在 约 $20 USD 内 |

> 上述费用为近似值，实际花费会因区域和使用情况有所不同。
> 建议设置 AWS Budgets 并结合自动关停策略，及时提醒并规避意外账单。

---

## 常见问题 (FAQ)

**如何检查本地工具和 AWS 配额是否满足实验要求？**

- 运行 `make preflight`，脚本会自动检查本地 CLI 工具版本、AWS SSO 登录状态，以及关键配额（如 ENI / vCPU / Spot 使用情况），并生成报告帮助你评估当前环境是否符合要求。

**如何将本项目部署到我的 AWS 账户？需要修改哪些配置？**

- 首先请确保满足文档中提到的所有前置条件，然后在 `infra/aws/terraform.tfvars` 中修改必要的变量以匹配你的环境。
- 例如，将 `profile` 更新为你的 AWS CLI 配置文件名，提供你自有的 S3 Bucket 和 DynamoDB 表用于 Terraform 后端存储。
- 若使用自定义域名，还需要在 Terraform 配置中将默认的 `lab.rendazhang.com` 改为你的域名并提供对应的 Hosted Zone。
- 完成配置后，按照 **安装部署指南** 中的步骤执行 Terraform 和相关脚本即可。
- 部署过程中请确保 AWS 凭证有效且有足够权限创建所需资源。
- `terraform.tfvars` 还包含 AWS Budgets 相关变量，可将 `create_budget=false` 以兼容无 Billing 权限的账号。

**每天自动销毁和重建集群环境是如何实现的？可以自定义这个调度吗？**

- 本项目通过 Makefile 脚本和 Terraform 模块实现资源的按日启停：早晨执行 `make start-all` 创建 NAT 网关、ALB 以及 EKS 集群，夜晚执行 `make stop-all` 完全销毁这些资源，仅保留 VPC 等基础设施状态。
- 你可以利用 CI/CD 平台的定时任务实现全自动调度，例如使用 GitHub Actions 的 `cron` 定时触发 `make start-all/stop-all`，或通过 AWS CodePipeline 配合 EventBridge 定时事件触发。
- 同样地，你也可以根据需要调整策略：例如，仅在工作日执行自动启停，周末保持关闭，甚至完全停用自动销毁（但需承担额外费用）。
- 调度的灵活性完全取决于你的实验需求。

**如果我希望集群长时间连续运行，是否可以不销毁资源？**

- 可以。
- 上述自动销毁策略主要用于节约成本，你可以选择不执行每日的 `make stop-all`，使集群和相关资源持续运行。
- 不过请注意，长时间运行将产生持续费用（特别是 EKS 控制平面和 NAT 网关等固定成本）。
- 建议在持续运行时仍采用其他成本控制措施，例如缩减不必要的节点、监控预算消耗等。
- 你也可以改为按需启停的方式，例如只在需要时手动运行脚本创建/删除集群。
- 总之，本项目提供的脚本和策略是可选的，用户可根据实际需求调整资源生命周期管理方式。

**默认提供的域名 `lab.rendazhang.com` 有什么作用？可以更换吗？**

- 该自定义域名通过 Route 53 Alias 记录固定解析到实验集群的 ALB，作用是在重建集群时保持对外访问地址不变。
- 如果你 Fork 本项目或在自己的账户中部署，通常无法使用 `lab.rendazhang.com` 域名。
- 此时你可以**更换为自己的域名**：方法是在你的 Route 53 中创建对应域名的 Hosted Zone，并在 Terraform 配置中将 `lab.rendazhang.com` 修改为你的域名（或如果不想使用自定义域名，也可删除 Terraform 中 `aws_route53_record` 资源直接使用 ALB 默认域名）。
- 更换域名后，需要在访问应用时使用新的域名。
- 如果不设置自定义域名，则可直接使用 AWS ALB 自动分配的域名来访问服务。

---

## 附录

### 文档

- 📄 [EKS 云原生集群生命周期流程](https://github.com/RendaZhang/renda-cloud-lab/blob/master/docs/EKS_CLUSTER_LIFECYCLE_GUIDE.md#eks-%E4%BA%91%E5%8E%9F%E7%94%9F%E9%9B%86%E7%BE%A4%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E6%B5%81%E7%A8%8B%E6%96%87%E6%A1%A3)
- 📄 [每日 Terraform 重建与销毁流程操作文档](https://github.com/RendaZhang/renda-cloud-lab/blob/master/docs/DAILY_REBUILD_TEARDOWN_GUIDE.md#terraform-%E9%87%8D%E5%BB%BA%E4%B8%8E%E9%94%80%E6%AF%81%E6%B5%81%E7%A8%8B%E6%93%8D%E4%BD%9C%E6%96%87%E6%A1%A3)
- 📄 [集群故障排查指南](https://github.com/RendaZhang/renda-cloud-lab/blob/master/docs/TROUBLESHOOTING.md#%E9%9B%86%E7%BE%A4%E6%95%85%E9%9A%9C%E6%8E%92%E6%9F%A5%E6%8C%87%E5%8D%97)
- 📄 [AGENTS 智能体操作指南](https://github.com/RendaZhang/renda-cloud-lab/blob/master/docs/AGENTS.md#guidance-for-ai-agents)
- 📄 [eksctl 遗留指引](https://github.com/RendaZhang/renda-cloud-lab/blob/master/docs/LEGACY_EKSCTL.md#eksctl-%E6%8C%87%E5%BC%95)
- 📄 [前置条件操作指南](https://github.com/RendaZhang/renda-cloud-lab/blob/master/docs/PREREQUISITES_GUIDE.md#%E5%89%8D%E7%BD%AE%E6%9D%A1%E4%BB%B6%E6%93%8D%E4%BD%9C%E6%8C%87%E5%8D%97)


### 检查清单

- 检查 Terraform 版本 ≥ 1.0
- 验证 AWS SSO 登录 token 未过期
- 检测 Helm 仓库是否就绪（如 Helm Repo 更新）
- 检查 kubectl 的 kubeconfig 是否指向目标集群

### 脚本清单

| 脚本名                     | 功能                                |
| --------------------------| -----------------------------------|
| `preflight.sh`            | 预检 AWS CLI 凭证 + Service Quotas  |
| `tf-import.sh`            | 将 EKS 集群资源导入 Terraform 状态   |
| `post-recreate.sh`        | 刷新 kubeconfig，应用 ALB 控制器 CRDs 并通过 Helm 安装/升级 AWS Load Balancer Controller、Cluster Autoscaler、metrics-server 和 HPA；部署应用 task-api（多清单 + ECR digest）、发布 Ingress 并完成冒烟验证，以及自动为最新 NodeGroup 绑定 Spot 通知 |
| `post-teardown.sh`        | 销毁集群后清理 CloudWatch 日志组、ALB/TargetGroup/安全组，并验证 NAT 网关、EKS 集群及 ASG SNS 通知等资源已删除；支持 `DRY_RUN=true` 预演 |
| `scale-nodegroup-zero.sh` | 将 EKS 集群所有 NodeGroup 实例数缩容至 0；暂停所有工作节点以降低 EC2 成本 |
| `update-diagrams.sh`      | 图表生成脚本 |

- `update-diagrams.sh` 脚本依赖：需安装 `Graphviz`
- 脚本的运行日志默认写入 `scripts/logs` 目录下；最近一次已绑定的 ASG 名缓存于 `scripts/.last-asg-bound`，两者均已在 `.gitignore` 排除。

---

## 未来计划

Renda Cloud Lab 仍在持续演进中，未来规划包括但不限于：

- **集成完整 CI/CD 流水线**：结合 `AWS CodePipeline` 等服务，实现从代码提交到容器镜像构建、安全扫描、部署到 EKS 的端到端自动化流水线，并提供示例应用演示持续交付过程。
- **增强 GitOps 与发布策略**：在集群中部署 `Argo CD` 等工具，支持多环境（Dev / Stage / Prod）的 GitOps 工作流。探索应用分组管理、蓝绿部署/金丝雀发布策略，以提高部署的弹性和可靠性。
- **丰富可观测性与混沌工程场景**：引入日志收集（`EFK` 或 `AWS OpenSearch`）、分布式追踪等组件完善 Observability，同时增加 `Chaos Mesh` 混沌实验示例（如节点故障、网络延迟），提升集群的稳健性。
- **AI Sidecar 实践**：开发并部署示例微服务，演示如何通过 Spring AI 将大型语言模型集成到云原生应用中。例如，基于 `AWS Bedrock` 的 `Titan` 模型或 `GCP Vertex AI`，实现智能客服、内容推荐等场景，并提供参考架构。
- **安全与合规**：增加更多安全措施和成本护栏，如使用 `OPA Gatekeeper` 编写策略约束 Kubernetes 资源配置、定期镜像漏洞扫描报告、自动化成本分析通知等，帮助使用者在实践中掌握云上治理技巧。

---

## 🤝 贡献指南

- Fork & clone this repo.
- 进入虚拟环境：
   ```bash
   # 如果还没安装虚拟环境，执行命令：python -m venv venv
   source venv/bin/activate
   ```
- 安装依赖并启用 **pre-commit**:
   ```bash
   pip install pre-commit
   pre-commit install
   ```
- 在每次提交前，钩子会自动运行。
- README 和 docs 下的文档会自动更新 Doctoc 目录（若本地未安装则跳过）。
- 你也可以手动触发：
  ```bash
  pre-commit run --all-files
  ```

> ✅ 所有提交必须通过 pre-commit 检查；CI 会阻止不符合规范的 PR。

---

## 🔐 License

本项目以 **MIT License** 发布，你可以自由使用与修改。请在分发时保留原始许可证声明。

---

## 📬 联系方式

- 联系人：张人大（Renda Zhang）
- 📧 邮箱：[952402967@qq.com](mailto:952402967@qq.com)

> ⏰ **Maintainer**：@Renda — 如果本项目对你有帮助，请不要忘了点亮 ⭐️ Star 支持我们！
