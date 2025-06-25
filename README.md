# Renda Cloud Lab

- Last Updated: June 25, 2025, 19:50 (UTC+8)
- 作者: 张人大（Renda Zhang）

> *专注于云计算技术研究与开发的开源实验室，提供高效、灵活的云服务解决方案，支持多场景应用。*

<p align="center">
  <img src="https://img.shields.io/badge/AWS-EKS%20%7C%20Terraform%20%7C%20Helm-232F3E?logo=amazonaws&logoColor=white" />
  <img src="https://img.shields.io/badge/License-MIT-blue.svg" />
  <img src="https://img.shields.io/badge/Status-Active-brightgreen" />
</p>

## 项目简介

**Renda Cloud Lab** 项目涵盖 **AWS 云服务、EKS、GitOps、可观测性、SRE 以及 AI Sidecar** 等前沿主题。通过该实验室，开发者可以实践基础设施即代码、容器编排、持续交付、混沌工程和 AI 工作负载集成等技术场景。项目采用 **“代码优先”** 原则，仅存放可运行的脚本、模块和架构图（文字笔记与文章另行维护），随着实践不断演进更新。

## 核心模块说明

本项目围绕云原生领域的多个核心模块展开，包括但不限于：

* **IaC (Infrastructure as Code)** — 使用 Terraform、eksctl 等工具管理 AWS 基础设施，探索 Pulumi 等多种 IaC 实践
* **容器 & 编排** — 基于 Docker 容器、Kubernetes (托管于 EKS) 进行应用部署，利用 Karpenter 实现弹性伸缩
* **CI/CD & GitOps** — 集成 AWS CodePipeline 持续集成流水线，结合 Argo CD 与 Helm 实现 GitOps 持续部署
* **可观测性 & SRE** — 引入 OpenTelemetry、Prometheus、Grafana 构建可观测体系，并通过 Chaos Mesh 落实 Chaos Engineering（混沌工程）实践
* **生成式 AI Sidecar** — 基于 Spring Boot + Spring AI 框架，集成 AWS Bedrock (如 Titan 大模型) / GCP Vertex AI 等生成式 AI 服务，实现应用智能化
* **成本 & 安全护栏** — 利用 Spot 实例、IRSA、AWS Budgets 控制成本，并通过 Trivy 镜像扫描、OPA Gatekeeper 策略等保障集群安全

上述模块相互协作，构成了一个完整的云原生学习与实验环境。

## 🗂 目录结构

```text
├─ infra/                  # IaC 模块与环境定义
│  └─ aws/                 #   Terraform 配置（backend / providers / vars 等）
├─ charts/                 # Helm Charts（按功能拆分的应用和系统组件）
├─ scripts/                # 基础设施启停与自动化脚本（如一键部署、节点伸缩、清理等）
├─ diagrams/               # 架构图表（Mermaid / PlantUML / PNG 等）
├─ .github/workflows/      # CI/CD 工作流（Terraform 计划、Lint 检查等）
└─ README.md
```

| 目录                     | 说明                                                                                              |
| ---------------------- | ----------------------------------------------------------------------------------------------- |
| **infra/aws/**         | Terraform 模块（VPC, 子网, NAT, ALB 等）和环境配置，远端状态保存在 S3/DynamoDB（默认 Region=`us-east-1`）               |
| **charts/**            | 应用和系统的 Helm Chart，遵循 OCI 制品规范，便于复用与扩展                                                           |
| **scripts/**           | 运维脚本：如 `provision-cluster.sh`（创建 EKS 集群）、`scale-nodegroup-zero.sh`（节点归零休眠）、`clean-up.sh`（资源清理）等 |
| **diagrams/**          | 系统架构和流量拓扑图，帮助理解基础设施与应用关系                                                                        |
| **.github/workflows/** | GitHub Actions 配置，用于CI流水线（格式检查、Terraform Plan等）                                                 |

## 安装部署指南

以下指南将帮助你在自己的 AWS 账户中部署本实验环境，包括基础设施和示例应用的部署步骤。

### 前置条件

在开始部署之前，请确保满足以下前置条件：

* **AWS 账户及权限**：拥有可用的 AWS 账户，并已安装并配置 AWS CLI（如使用 `aws configure` 或 AWS SSO 登录）。建议创建一支具有管理员权限的 IAM Role（例如 `eks-admin-role`），用于 EKS 集群的管理操作。
* **Terraform 后端**：提前创建用于 Terraform 状态存储的 S3 Bucket 及 DynamoDB Lock Table，并在 `infra/aws/backend.tf` 中相应配置名称。默认配置假定 S3 Bucket 名为 `phase2-tf-state-us-east-1` 且 DynamoDB 表名为 `tf-state-lock`（可根据需要修改）。
* **DNS 域名**（可选）：若希望使用自定义域名访问集群服务，请在 Route 53 中预先创建相应 Hosted Zone（例如当前默认使用的 `lab.rendazhang.com` 域名）。将 Terraform 配置中的域名更新为你的域名，以映射 ALB 到固定域名。否则，可忽略 DNS 配置，直接使用自动分配的 ALB 域名访问。
* **本地环境**：安装 Terraform (\~1.8+)、eksctl (\~0.180+)、kubectl，以及 Helm 等必要的命令行工具。同时确保安装 Git 和 Make 等基础工具。
* **预检脚本**: 目前可以运行 preflight.sh 来检查关键 Service Quota 的数量，以后会加上对本地工具链 (AWS CLI / Terraform / eksctl / Helm 等)的健康检查 。

### 基础设施部署

1. **克隆仓库**：下载代码库到本地环境。

   ```bash
   git clone https://github.com/RendaZhang/renda-cloud-lab.git
   cd renda-cloud-lab
   ```

2. **初始化 Terraform**：切换到基础设施目录并初始化 Terraform 后端。

   ```bash
   cd infra/aws
   terraform init
   terraform plan  # 可选：查看将创建的资源计划
   ```

   确认无误后执行 apply 来部署 VPC、子网、NAT 网关、ALB 等基础资源：

   ```bash
   terraform apply -auto-approve
   ```

   *注意：Terraform 会根据 `terraform.tfvars` 中的配置在指定区域创建资源，并使用提供的 IAM Role ARN 设置 EKS Admin 权限。如未修改，本项目默认 Region 为 `us-east-1`。*

3. **创建 EKS 集群**：运行提供的一键脚本使用 eksctl 创建 Kubernetes 控制平面和节点组。该脚本会将集群部署在前一步创建的 VPC 中，并绑定预先提供的 IAM Role 作为集群管理员。

   ```bash
   # 返回仓库根目录
   cd ../../
   bash scripts/provision-cluster.sh
   ```

   初始集群创建完成后，可通过 `kubectl get nodes --watch` 观察节点启动情况。集群默认命名为 “dev”，如需自定义名称或参数请修改脚本或 Terraform 变量配置。

4. **验证集群**：确保本地 `kubeconfig` 已更新并指向新创建的 EKS 集群。执行简单的 Kubernetes 命令确认集群正常运行，例如：

   ```bash
   kubectl get svc
   kubectl get pods -A
   ```

   若能正常列出 Kubernetes 对象，则基础设施部分部署成功。

### 应用部署

基础设施就绪后，即可在集群上部署示例应用和云原生组件：

* **部署示例应用**：使用 Helm 将提供的示例应用 Chart 安装到集群中。请根据 `charts/` 目录中的实际内容选择相应子目录并执行安装命令。例如：

  ```bash
  helm install my-app charts/my-app -n default
  ```

  上述命令会将示例应用部署至默认命名空间（首次使用需加 `--create-namespace`）。部署完成后，可通过 `kubectl get pods` 查看应用 Pod 状态。应用对外暴露的服务将通过 AWS ALB 及 Route 53 自定义域名访问（例如 `lab.rendazhang.com`，可替换为你的域名）。

* **GitOps 持续部署**：推荐安装 Argo CD 至集群（可参考官方文档部署）。将本仓库（或你的 Fork）配置为 Argo CD 的应用源后，Argo CD 将持续监视 `charts/` 下的清单变更并自动同步部署到集群。这实现了 Git 提交到集群配置的自动化部署流程。如需使用 AWS 原生 CI/CD，也可以结合 **AWS CodePipeline** 实现应用的构建与部署（例如代码提交触发镜像构建，并通过 Argo CD 或 Helm 完成部署）。

* **部署运维组件**：根据需要部署可观测性和混沌工程相关组件。例如，可以使用 Helm 安装 OpenTelemetry Collector、Chaos Mesh Operator 等到集群，以完善实验环境功能。这些组件的示例配置也可在 `charts/` 或 `scripts/` 中找到。部署后，可结合相应的仪表盘或工具验证其功能（如访问 Grafana 查看指标等）。

完成上述步骤后，你的 EKS 实验集群应已成功运行起应用工作负载和所需的支撑组件。

## 日常工作流

### 预检检查 Preflight

在首次部署或每次更换终端 / 电脑时，可先执行：

```bash
# 一键预检
make preflight # 等同于 bash scripts/preflight.sh
# 输出示例：
SG per ENI:     5.0
Spot vCPU:      32.0
Network ENI / Region:   5000.0
OnDemand vCPU:  16.0
```

**该脚本将：**

- 检查关键 Service Quota
- 生成 preflight.txt 供存档

**备注**

- TODO: 本地工具链版本 (AWS CLI / Terraform / eksctl / Helm)
- TODO: AWS SSO 登录有效性
- TODO: 如果某项配额低于需求，脚本会以显眼颜色标记，并附带下一步 URL (Console Quota Increase)。
- TODO: 若检测到本地缺少 Terraform / eksctl 等工具，脚本会提示对应安装命令（brew / apt / choco）。
- 若计划把脚本扩展为更完整的 “Doctor” 工具，可考虑单独新建 `scripts/doctor.sh`，并在 README 留链接。
- Quota Check 中出现 - used 表示该配额无易于统计的实时“已用量”；出现 N/A used 表示当前用量为 0。


## 💰 成本控制说明

云资源按需高效利用是本项目的重要考量。**Renda Cloud Lab** 实践了一套“每日自动销毁 -> 重建”的基础设施生命周期策略，以最大化节约 AWS 费用：

* **日间启用，夜间销毁**：通过 Makefile 脚本在每天早晨自动部署必要资源（如 NAT 网关、ALB），夜间自动销毁这些非必要资源。此策略确保在活跃实验时段集群具备完整网络出口和访问能力，而在闲置时段释放高成本资源。基础设施的状态（如 VPC、数据存储和 Terraform 状态）将被保留，以便第二天快速重建。对于长假或暂停使用的情况，可以选择执行 “硬停用” 流程，销毁 EKS 控制平面及所有节点，以避免持续计费。
* **固定域名**：借助 Route 53 的 Alias Record，将动态生成的负载均衡器DNS映射到固定域名（默认 `lab.rendazhang.com`）。即使每天重新创建 ALB，其访问域名保持不变，方便用户和系统集成。
* **弹性扩缩容**：集群工作节点采用按需 **Spot 实例**（结合 Karpenter 或 Auto Scaling），根据负载自动伸缩。在无工作负载时可将节点数缩至0以节省开销（提供了 `scripts/scale-nodegroup-zero.sh` 脚本一键将节点缩容至 0）。恢复实验时，只需重新部署或产生新负载，节点便会按需启动。

通过以上措施，实验集群可在确保功能完整的同时，将日常运行成本控制在低水平。下表为启用成本控制策略下的主要资源月度费用估算：

| 资源                   | 策略                          | 估算/月            |
| -------------------- | --------------------------- | ----------------- |
| **EKS 控制平面**         | 按需启用，闲置时段执行 `scale 0` 或删除集群 | \~\$20 – \$30 USD |
| **工作节点 (NodeGroup)** | Spot 实例 + 自动伸缩，根据工作负载实时调节   | 随实验强度动态变化         |
| **监控与 AI 组件**        | 设置采样率上限、预算报警等               | 可控制在 \~\$20 USD 内 |

**上述费用为近似值，实际花费视区域和使用情况可能有所不同。

此外，建议设置 AWS Budgets 和自动关停策略，及时提醒并规避意外账单。如果需要长时间运行集群，可暂时停用上述自动销毁策略，但务必留意由此产生的额外费用。

## 常见问题 (FAQ)

* **问：如何检查本地工具和 AWS 配额是否满足实验要求？**
  
  答：运行 make preflight，脚本会自动检查 CLI 工具版本、AWS SSO 登录状态、关键配额 (ENI / vCPU / Spot) 并生成报告。

* **问：如何将本项目部署到我的 AWS 账户？需要修改哪些配置？**
  
  答：首先请确保满足文档中提到的所有前置条件，然后在 `infra/aws/terraform.tfvars` 中修改必要的变量以匹配你的环境。例如，将 `profile` 更改为你的 AWS CLI 配置文件名，提供你自有的 S3 Bucket 和 DynamoDB 表用于 Terraform 后端，以及替换 `eks_admin_role_arn` 为你账户中具有管理员权限的 IAM Role。若使用自定义域名，还需要在 Terraform 配置中替换默认的 `lab.rendazhang.com` 域名为你的域名并提供对应的 Hosted Zone。完成配置后，按照**安装部署指南**中的步骤执行 Terraform 和脚本即可。部署过程中请确保 AWS 凭证有效且有足够权限创建所需资源。

* **问：每天自动销毁和重建集群环境是如何实现的？可以自定义这个调度吗？**
  
  答：本项目通过 Makefile 和 Terraform 实现资源的按日启停：早晨执行 `make start` 创建 NAT 网关、ALB 等，夜晚执行 `make stop` 销毁这些资源并保留基础设施状态。你可以利用 CI/CD 平台的定时任务实现全自动调度，例如使用 GitHub Actions 的 `cron` 定时触发 `make start/stop`，或通过 AWS CodePipeline 配合 EventBridge 定时事件触发。同样地，你也可以根据需要调整策略：例如，只在工作日执行自动启停，周末保持关闭，甚至完全停用自动销毁（但需承担额外费用）。调度的灵活性完全取决于你的需求。

* **问：如果我希望集群长时间连续运行，是否可以不销毁资源？**
  
  答：可以。上述自动销毁策略主要用于节约成本，你可以选择不执行每日的 `make stop`，使集群和相关资源一直运行。不过请注意，长时间运行将产生持续费用（特别是 EKS 控制平面和 NAT 网关等固定成本）。建议在持续运行时仍采用其他成本控制措施，例如缩减不必要的节点、监控预算消耗等。你也可以改用按需的方式，例如只在需要时手动运行脚本创建/删除集群。总之，本项目提供的脚本和策略是可选的，用户可根据实际需求调整资源生命周期管理方式。

* **问：默认使用的域名 `lab.rendazhang.com` 有什么作用？可以更换吗？**
  
  答：该自定义域名通过 Route 53 固定解析到实验集群的 ALB，主要作用是在重建集群时保持访问地址不变。如果你 Fork 本项目或在自己的账户中部署，通常没有对该域名的控制权。你可以选择**更换为自己的域名**：方法是在你的 Route 53 中创建相应域名的 Hosted Zone，并在 Terraform 配置中将 `lab.rendazhang.com` 修改为你的域名（或直接删除 `aws_route53_record` 资源改用 ALB 默认域名）。更换后，需要在应用访问时使用新的域名。若不设置自定义域名，也可以直接使用 AWS ALB 自动分配的域名来访问服务。

* **问：为什么同时使用 Terraform 和 eksctl 两种方式来创建集群？**
  
  答：本项目采用 Terraform 管理网络和周边资源（VPC、子网、网关等），而将 EKS 集群本身的创建交由 eksctl 脚本执行。这种混合方式主要出于便利和效率考虑：Terraform 保留底层网络状态，便于多次反复部署，而 eksctl 在创建和销毁 Kubernetes 控制面方面更为快捷。通过将 EKS 从 Terraform 状态中解耦，我们可以在不影响 VPC 等共享资源的情况下频繁重建集群。此外，eksctl 对 EKS 的配置更直观，如指定节点配置、IAM 集成等。在未来，我们计划评估 Terraform 官方的 EKS 模块，以可能实现 Terraform 对集群的直接管理。

## 附录 / 脚本清单

- 检查 terraform ≥ 1.7，eksctl ≥ 0.180
- 验证 aws sso login token 不过期
- 检测 Helm repo 是否就绪
- 检查 kubectl kubeconfig 是否指向目标集群

## 未来计划

Renda Cloud Lab 仍在持续演进中，未来规划包括但不限于：

* **预检脚本持续扩展**： 增加本地依赖检查、配额趋势监控、结果上传至 Slack / Telegram 以便远程提醒。
* **完善集群自动化部署**：将 EKS 集群创建纳入 Terraform 管理（启用 `create_eks` 开关）或提升 eksctl 脚本的可定制性，实现从 VPC 到集群的一站式部署。
* **集成完整 CI/CD 流水线**：结合 AWS CodePipeline 等服务，实现从代码提交到容器镜像构建、安全扫描、部署到 EKS 的端到端流水线，并提供示例应用演示持续交付过程。
* **增强 GitOps 与部署策略**：在集群中部署 Argo CD 等工具，支持多环境（Dev/Stage/Prod）下的 GitOps 工作流。探索应用分组部署、蓝绿发布/金丝雀发布策略，以提高部署弹性和可靠性。
* **丰富可观测性与混沌工程场景**：引入日志收集（如 EFK 或 AWS OpenSearch）、分布式追踪等组件完善 Observability，同时增加 Chaos Mesh 混沌实验示例（如节点故障、网络延迟模拟），助力提升集群稳健性。
* **AI Sidecar 实践**：开发并部署示例微服务，演示如何通过 Spring AI 将大型语言模型集成到云原生应用中。例如，基于 AWS Bedrock 的 Titan 或调用 GCP Vertex AI 模型，实现智能客服、推荐等场景，并提供参考架构。
* **安全与合规**：加入更多安全措施和成本护栏，如使用 OPA Gatekeeper 编写策略约束 Kubernetes 资源配置、定期镜像漏洞扫描报告、配置自动化的成本分析通知等，帮助使用者在实战中掌握云上治理技巧。

以上路线图将根据社区反馈和技术发展进行调整。如果你对本项目有任何建议或希望看到的功能，欢迎提出 Issue 或参与贡献。

## 🤝 贡献指南

1. **Fork 仓库**，新建功能分支，完成开发后提交 Pull Request。
2. 提交前请运行 `pre-commit` 进行代码检查和格式化（已包含 `terraform fmt`、`tflint`、`yamllint` 等钩子）。确保所有检查通过，以提高代码合入效率。
3. CI 流水线通过后，维护者会对 PR 进行审核和合并。如有任何问题会在 PR 下反馈。

非常欢迎社区贡献新的**实验脚本、Terraform 模块、架构图**，或任何改进成本控制的创意！如果有大的想法需要讨论，请提前创建 Issue 并详细描述背景和设计思路。

## 📜 许可证

本项目采用 **MIT 协议** 开源发布。这意味着你可以自由地使用、修改并重新发布本仓库的内容，只需在分发时附上原始许可证声明。

---

> ⏰ **Maintainer**：@Renda — 如果本项目对你有帮助，请不要忘了点亮 ⭐️ Star 支持我们！
