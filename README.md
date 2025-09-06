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
    - [环境重建和销毁](#%E7%8E%AF%E5%A2%83%E9%87%8D%E5%BB%BA%E5%92%8C%E9%94%80%E6%AF%81)
  - [附录](#%E9%99%84%E5%BD%95)
  - [常见问题 (FAQ)](#%E5%B8%B8%E8%A7%81%E9%97%AE%E9%A2%98-faq)
  - [🤝 贡献指南](#-%E8%B4%A1%E7%8C%AE%E6%8C%87%E5%8D%97)
  - [🔐 License](#-license)
  - [📬 联系方式](#-%E8%81%94%E7%B3%BB%E6%96%B9%E5%BC%8F)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Renda Cloud Lab

- **最后更新**: September 07, 2025, 01:00 (UTC+08:00)
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

**Renda Cloud Lab** 项目涵盖 **AWS 云服务、EKS、可观测性、SRE** 等前沿主题。

通过该实验室，开发者可以实践基础设施即代码、容器编排、持续交付、混沌工程等技术场景。

更多需求与功能状态请参见 [功能需求与规划](docs/REQUIREMENTS.md)。

---

## 核心模块说明

本项目围绕云原生领域的多个核心模块展开，包括但不限于：

- **IaC (Infrastructure as Code)** — 使用 `Terraform` 管理 AWS 基础设施。
- **容器 & 编排** — 基于 `Docker` 容器、`Kubernetes` (托管于 EKS) 进行应用部署。
- **可观测性 & SRE** — 集成 metrics-server、ADOT Collector（remote_write 至 AMP）与 Grafana，支持可选安装 Chaos Mesh 实践混沌工程。
- **成本 & 安全护栏** — 利用 Spot 实例与 IRSA 控制成本与权限，并提供 S3 前缀生命周期清理等基础护栏。
- **自动扩缩容 (Cluster Autoscaler)** — 通过脚本式 `Helm` 安装 `cluster-autoscaler`，实现节点数量根据负载弹性伸缩
- **负载均衡控制器 (AWS Load Balancer Controller)** — Terraform 仅预置 IRSA，ServiceAccount 由 `scripts/lifecycle/post-recreate.sh` 刷新 kubeconfig 并等待集群就绪后创建并注解，Helm 安装后即可管理 ALB Ingress

上述模块相互协作，构成了一个完整的云原生实验环境。

---

## 目录结构

```text
├─ infra/                # IaC 模块与环境定义
│  ├─ aws/               # Terraform 配置（backend / providers / vars 等）
│  └─ eksctl/            # eksctl YAML (legacy - optional)
├─ docs/                 # 设计与流程文档（如 lifecycle.md）
├─ scripts/              # 基础设施启停与自动化脚本（如一键部署、节点伸缩、清理等）
│  ├─ lifecycle/         # 环境重建与销毁相关脚本
│  └─ logs/              # 执行日志输出目录（已在 .gitignore 中排除）
├─ diagrams/             # 架构图表（Terraform graph 可视化图）
└─ README.md
```

| 目录                     | 说明                                                               |
| ---------------------- | ------------------------------------------------------------------- |
| **infra/aws/**         | Terraform 模块（VPC、子网、NAT、EKS 等）和环境配置，远端状态保存在 S3/DynamoDB（默认 Region=`us-east-1`） |
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
- 每个微服务都可以拥有独立 Chart 和 `values.yaml`。

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

后续操作参考文档内容：📄 [运维手册](https://github.com/RendaZhang/renda-cloud-lab/blob/master/docs/RUNBOOK.md)

### 环境重建和销毁

具体请参考文档内容：📄 [环境重建与销毁指南](https://github.com/RendaZhang/renda-cloud-lab/blob/master/docs/ENV_REBUILD_TEARDOWN_GUIDE.md#%E7%8E%AF%E5%A2%83%E9%87%8D%E5%BB%BA%E4%B8%8E%E9%94%80%E6%AF%81%E6%8C%87%E5%8D%97)

---

## 附录

- 📄 [功能需求与规划](docs/REQUIREMENTS.md#云原生实验室功能需求与规划)
- 📄 [运维手册](https://github.com/RendaZhang/renda-cloud-lab/blob/master/docs/RUNBOOK.md#%E8%BF%90%E7%BB%B4%E6%89%8B%E5%86%8C)
- 📄 [环境重建与销毁指南](https://github.com/RendaZhang/renda-cloud-lab/blob/master/docs/ENV_REBUILD_TEARDOWN_GUIDE.md#%E7%8E%AF%E5%A2%83%E9%87%8D%E5%BB%BA%E4%B8%8E%E9%94%80%E6%AF%81%E6%8C%87%E5%8D%97)
- 📄 [集群故障排查指南](https://github.com/RendaZhang/renda-cloud-lab/blob/master/docs/TROUBLESHOOTING.md#%E9%9B%86%E7%BE%A4%E6%95%85%E9%9A%9C%E6%8E%92%E6%9F%A5%E6%8C%87%E5%8D%97)
- 📄 [AGENTS 智能体操作指南](https://github.com/RendaZhang/renda-cloud-lab/blob/master/docs/AGENTS.md#guidance-for-ai-agents)
- 📄 [eksctl 遗留指引](https://github.com/RendaZhang/renda-cloud-lab/blob/master/docs/LEGACY_EKSCTL.md#eksctl-%E6%8C%87%E5%BC%95)
- 📄 [前置条件操作指南](https://github.com/RendaZhang/renda-cloud-lab/blob/master/docs/PREREQUISITES_GUIDE.md#%E5%89%8D%E7%BD%AE%E6%9D%A1%E4%BB%B6%E6%93%8D%E4%BD%9C%E6%8C%87%E5%8D%97)

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

**每天自动销毁和重建集群环境是如何实现的？可以自定义这个调度吗？**

- 本项目通过 Makefile 脚本和 Terraform 模块实现资源的按日启停：早晨执行 `make start-all` 创建 NAT 网关以及 EKS 集群，夜晚执行 `make stop-all` 完全销毁这些资源，仅保留 VPC 等基础设施状态。
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

**如果需要使用自定义域名，该如何配置？**

- 本项目默认不再创建 Route 53 Hosted Zone 或 DNS 记录。
- 如需使用自定义域名，可在 Route 53 或其他 DNS 服务中创建对应的 Hosted Zone。
- 当 ALB Controller 为 Ingress 创建 ALB 后，通过 `kubectl get ingress` 或 AWS 控制台获取 ALB 的 DNS 名称，并在 Hosted Zone 中创建一条指向该 DNS 的 A 记录（Alias）。
- 由于 ALB 每次重建都会生成新的 DNS 名称，需要在重建后更新该记录，或使用 ExternalDNS 等自动化方案。
- 若不配置自定义域名，可直接使用 ALB 自动分配的域名访问服务。

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
