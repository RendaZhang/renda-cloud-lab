# Renda Cloud Lab

* Last Updated: June 28, 2025, 19:30 (UTC+8)
* 作者: 张人大（Renda Zhang）

> *专注于云计算技术研究与开发的开源实验室，提供高效、灵活的云服务解决方案，支持多场景应用。*

<p align="center">
  <img src="https://img.shields.io/badge/AWS-EKS%20%7C%20Terraform%20%7C%20eksctl%20%7C%20Helm-232F3E?logo=amazonaws&logoColor=white" />
  <img src="https://img.shields.io/badge/License-MIT-blue.svg" />
  <img src="https://img.shields.io/badge/Status-Active-brightgreen" />
</p>

## 项目简介

**Renda Cloud Lab** 项目涵盖 **AWS 云服务、EKS、GitOps、可观测性、SRE 以及 AI Sidecar** 等前沿主题。通过该实验室，开发者可以实践基础设施即代码、容器编排、持续交付、混沌工程和 AI 工作负载集成等技术场景。项目采用 **“代码优先”** 原则，仅存放可运行的脚本、模块和架构图，随着实践不断演进更新。

## 核心模块说明

本项目围绕云原生领域的多个核心模块展开，包括但不限于：

* **IaC (Infrastructure as Code)** — 使用 Terraform、eksctl 等工具管理 AWS 基础设施，探索 Pulumi 等多种 IaC 实践
* **容器 & 编排** — 基于 Docker 容器、Kubernetes (托管于 EKS) 进行应用部署，利用 Karpenter 实现弹性伸缩
* **CI/CD & GitOps** — 集成 AWS CodePipeline 持续集成流水线，结合 Argo CD 与 Helm 实现 GitOps 持续部署
* **可观测性 & SRE** — 引入 OpenTelemetry、Prometheus、Grafana 构建可观测体系，并通过 Chaos Mesh 落实 Chaos Engineering（混沌工程）实践
* **生成式 AI Sidecar** — 基于 Spring Boot + Spring AI 框架，集成 AWS Bedrock (如 Titan 大模型) / GCP Vertex AI 等生成式 AI 服务，实现应用智能化
* **成本 & 安全护栏** — 利用 Spot 实例、IRSA、AWS Budgets 控制成本，并通过 Trivy 镜像扫描、OPA Gatekeeper 策略等保障集群安全

上述模块相互协作，构成了一个完整的云原生实验环境。

## 🗂 目录结构

```text
├─ infra/                  # IaC 模块与环境定义  
│  ├─ aws/                 # Terraform 配置（backend / providers / vars 等）  
│  └─ eksctl/              # eksctl YAML (EKS cluster & nodegroups)  
├─ docs/                   # 设计与流程文档（如 lifecycle.md）  
├─ charts/                 # Helm Charts（按功能拆分的应用和系统组件）  
├─ scripts/                # 基础设施启停与自动化脚本（如一键部署、节点伸缩、清理等）  
│  └─ logs/                # 执行日志输出目录（已在 .gitignore 中排除）  
├─ diagrams/               # 架构图表（Terraform graph 可视化图）
│  ├─ terraform-architecture.dot  # Terraform graph 原始输出
│  ├─ terraform-architecture.svg  # SVG 架构图（推荐）
│  ├─ terraform-architecture.png  # PNG 快速预览图
│  └─ terraform-architecture.md   # 图表生成与解读指南
└─ README.md
```

| 目录                     | 说明                                                                                 |
| ---------------------- | ---------------------------------------------------------------------------------- |
| **infra/aws/**         | Terraform 模块（VPC、子网、NAT、ALB、EKS 等）和环境配置，远端状态保存在 S3/DynamoDB（默认 Region=`us-east-1`） |
| **infra/eksctl/**      | eksctl 声明式配置文件。目前仅 `eksctl-cluster.yaml`，后续可放置 NodeGroup 或集群升级的 YAML 配置            |
| **docs/**              | 生命周期与流程说明文档，例如 `docs/lifecycle.md`（一键重建、Spot 绑定、清理指令等）                             |
| **charts/**            | 应用和系统的 Helm Chart，遵循 OCI 制品规范，便于复用与扩展                                              |
| **scripts/**           | 脚本：如 `preflight.sh`（预检检查）、`tf-import.sh`（Terraform 导入） 等                           |
| **diagrams/**          | 系统架构和流量拓扑图，帮助理解基础设施与应用关系                                                           |
| **.github/workflows/** | GitHub Actions 配置，用于 CI 流水线（格式检查、Terraform Plan 等）                                 |

## 安装部署指南

以下指南将帮助你在自己的 AWS 账户中部署本实验环境，包括基础设施和示例应用的部署步骤。

### 前置条件

在开始部署之前，请确保满足以下前置条件：

* **AWS 账户及权限**：拥有可用的 AWS 账户，并已安装并配置 AWS CLI（例如通过 `aws configure` 或 AWS SSO 登录）。**本项目默认使用 AWS CLI 的 SSO Profile 名称 `phase2-sso`，默认区域为 `us-east-1`**，如与你的配置不同请相应调整后续命令。建议创建一支具有管理员权限的 IAM Role（例如 `eks-admin-role`），用于 EKS 集群的管理操作。
* **Terraform 后端**：提前创建用于 Terraform 状态存储的 S3 Bucket 及 DynamoDB 锁定表，并在 `infra/aws/backend.tf` 中相应配置名称。默认假定 S3 Bucket 名为 `phase2-tf-state-us-east-1`，DynamoDB 表名为 `tf-state-lock`（可根据需要修改）。
* **DNS 域名**（可选）：若希望使用自定义域名访问集群服务，请在 Route 53 中预先创建相应 Hosted Zone（当前默认使用的子域为 `lab.rendazhang.com`）。将 Terraform 配置中的域名更新为你的域名，以便将 ALB 地址映射到固定域名。否则，可忽略 DNS 配置，直接使用自动分配的 ALB 域名访问服务。
* **本地环境**：安装 Terraform (\~1.8+)、eksctl (\~0.180+)、kubectl，以及 Helm 等必要的命令行工具。同时确保安装 Git 和 Make 等基础工具。
* **预检脚本**：可运行 `preflight.sh` 来检查关键 Service Quota 配额和环境依赖（未来将扩展检查 AWS CLI / Terraform / eksctl / Helm 等工具链的版本与状态）。执行 `bash scripts/preflight.sh` 或 `make preflight` 可开始预检。

### 基础设施部署

1. **克隆仓库**：下载代码库到本地环境。

   ```bash
   git clone https://github.com/RendaZhang/renda-cloud-lab.git  
   cd renda-cloud-lab
   ```

2. **初始化 Terraform**：切换到基础设施目录并初始化 Terraform 后端。

   ```bash
   cd infra/aws  
   terraform init -reconfigure  
   terraform plan  # 可选：查看将创建的资源计划
   ```

   确认无误后执行 apply 来部署 VPC、子网、NAT 网关、ALB 等基础网络资源：

   ```bash
   terraform apply -auto-approve
   ```

   *注意：Terraform 将根据 `terraform.tfvars` 中的配置在指定区域创建资源，并使用提供的 IAM Role ARN 设置 EKS Admin 权限。若未修改，本项目默认 Region 为 `us-east-1`。*

3. **创建 EKS 集群**：运行提供的一键脚本，使用 eksctl 创建 Kubernetes 控制平面和节点组。该操作会将集群部署在前一步 Terraform 创建的 VPC 中。

   ```bash
   # 创建 EKS 控制平面 + 托管节点组
   eksctl create cluster -f infra/eksctl/eksctl-cluster.yaml --profile phase2-sso
   ```

   eksctl 的配置文件 (`infra/eksctl/eksctl-cluster.yaml`) 默认使用 Terraform 已创建的 VPC 和子网。如果自定义了 VPC CIDR，需要同步修改该 YAML 中的子网 ID。**此外，该配置引用了一个预先创建的 IAM Role（默认命名为 `eks-admin-role`）作为集群服务角色**，此 Role 应具有 AmazonEKSClusterPolicy、AmazonEKSVPCResourceController 等必要权限。确保在创建集群前已在你的 AWS 账户中创建了此角色并在 YAML 中填入其完整 ARN。

4. **导入集群资源至 Terraform**：EKS 集群和节点组创建完成后，执行提供的脚本将这些资源导入 Terraform 状态，以便后续通过 Terraform 统一管理。

   ```bash
   # 导入 EKS 集群、节点组、OIDC 提供商、IRSA 等到 Terraform 状态
   bash scripts/tf-import.sh
   ```

   上述脚本会使用 AWS CLI 获取当前集群名称和节点组名称，并依次执行 `terraform import` 命令，将 **EKS 集群（控制平面）**、**托管节点组**、**OIDC 提供商**以及预定义的 **IRSA (IAM Roles for Service Accounts) 角色** 等资源映射到 Terraform 状态中。导入完成后，这些资源便纳入 Terraform 管理（例如后续可以通过 Terraform 管理 OIDC Provider 及 IRSA 绑定策略等），实现基础设施状态的一致性。
   *注意：此混合流程结合了 Terraform 与 eksctl 的优势——Terraform 管理底层网络和 IAM 等共享资源，eksctl 负责快速创建/销毁 EKS 控制平面和节点。在集群创建后导入 Terraform 可以保持对关键集群资源的可见性和控制权，同时又不影响底层 VPC 等资源，每次重建集群时无需重复创建网络。*

5. **验证集群**：确保本地 `kubeconfig` 已更新并指向新创建的 EKS 集群。执行简单的 Kubernetes 命令确认集群正常运行，例如：

   ```bash
   kubectl get svc  
   kubectl get nodes  
   kubectl get pods -A
   ```

   若能正常列出 Kubernetes 节点和服务，则基础设施部分部署成功。

### 应用部署

基础设施就绪后，即可在集群上部署示例应用和云原生组件：

* **部署示例应用**：使用 Helm 将提供的示例应用 Chart 安装到集群中。请根据 `charts/` 目录中的实际内容选择相应子目录并执行安装命令。例如：

  ```bash
  helm install my-app charts/my-app -n default --create-namespace
  ```

  上述命令会将示例应用部署至 Kubernetes 默认命名空间。部署完成后，可通过 `kubectl get pods` 查看应用 Pod 状态。应用对外暴露的服务将通过 AWS ALB 及 Route 53 自定义域名访问（默认域名为 `lab.rendazhang.com`，可根据需要替换为你的域名）。

* **GitOps 持续部署**：推荐安装 Argo CD 至集群（可参考官方文档）。将本仓库（或你的 Fork）配置为 Argo CD 的应用来源后，Argo CD 将持续监视 `charts/` 下的清单变更并自动同步部署到集群。这实现了 Git 提交到集群配置的自动部署流程。若偏好使用 AWS 原生 CI/CD，也可以结合 **AWS CodePipeline**，实现从代码变更到容器构建、再通过 Argo CD 或 Helm 完成部署的端到端流水线。

* **部署运维组件**：根据需要部署可观测性和混沌工程相关组件。例如，可以使用 Helm 安装 OpenTelemetry Collector、Chaos Mesh Operator 等到集群，以完善实验环境的运维功能。这些组件的示例配置可在 `charts/` 或 `scripts/` 中找到。部署后，可结合相应的仪表盘或工具验证其功能（例如访问 Grafana 查看指标数据，或触发 Chaos Mesh 实验观察集群表现）。

完成上述步骤后，你的 EKS 实验集群应已成功运行示例应用工作负载和所需的支撑组件。

## 日常工作流

### 预检检查 Preflight

在首次部署或每次更换终端/电脑时，可先执行预检脚本：

```bash
# 一键预检环境和配额
make preflight   # 等同于 bash scripts/preflight.sh
```

**该脚本将自动检查：**

* 关键 AWS Service Quota 配额上限及当前使用量（如 ENI 数量、ALB 数量、vCPU 配额等），并计算剩余额度
* 将结果输出到终端并写入 `preflight.txt` 以供存档参考

*备注：*

* *未来版本计划增加对本地工具链版本 (AWS CLI / Terraform / eksctl / Helm) 的检查，以及 AWS SSO 登录有效性的验证。*
* *如果某项配额的使用量接近上限，脚本会以显眼颜色标记并附上申请提升配额的 AWS 控制台链接。*
* *若检测到本地缺少必要工具，脚本将提示安装命令（brew/apt/choco 等）。*
* *Quota 检查中出现 “- used” 表示该配额无易于统计的实时使用量；出现 “N/A used” 则表示当前用量为 0。*

### 集群启停管理 (Start & Stop)

在日常使用中，可通过 Makefile 提供的命令快速启停集群的关键资源，以节约成本并保持环境可控：

* `make start` — **启动基础设施资源**：执行 Terraform 将 NAT 网关、ALB 等高成本资源启用，并确保 EKS 集群（控制平面及节点组）处于运行状态（集群资源现已由 Terraform 统一管理）。通常在每天实验开始时运行，恢复网络出口和对外服务能力。
* `make stop` — **停止基础设施资源**：执行 Terraform 关闭 NAT 网关、ALB 等非必要资源，并将 EKS 集群的节点组 (NodeGroup) 实例数缩容至 0，保留 EKS 控制平面和基础设施状态，但暂停对外网络访问。适用于每日实验结束时销毁高成本资源，降低支出。
* `make stop-hard` — **硬停用完整环境**：通过 Terraform 同时销毁 NAT 网关、ALB 以及 EKS 控制平面和节点组，实现完整环境的彻底停止。用于长时间暂停实验时的彻底关停，避免持续产生任何费用（除了保留的 VPC 和状态存储等）。
* `make post-recreate`   — 运行 Spot 通知自动绑定脚本，确保重建后的 ASG 已订阅 SNS
* `make all`             — `start` → `post-recreate` 一键全流程
* `make destroy-all`     — Terraform 销毁全部资源（含 NodeGroup）⚠️ 高危
* `make check`           — 本地依赖工具链检测（aws / terraform / eksctl / helm）
* `make logs`            — 快速查看最近日志目录
* `make clean`           — 删除 Spot 绑定缓存文件、清理日志
* `make update-diagrams` — 一键生成最新的 Terraform 架构图，输出到 `diagrams/` 目录中

以上命令提供了一键式的集群生命周期管理方案。你可以根据需要将它们加入定时任务，实现自动启停（详见下方成本控制说明）。请注意，在重新启动集群资源后，可能需要等待几分钟以恢复所有服务（例如新建的 NAT 网关和 ALB 就绪），应用才能重新通过域名访问。

### 推荐完整重建流程

```bash
make all          # 一键启用 NAT/ALB + 创建/导入集群 + 绑定 Spot 通知
# ... coding ...
make stop         # 下班关大件
```

## 💰 成本控制说明

云资源按需高效利用是本项目的重要考量。**Renda Cloud Lab** 实践了一套“每日自动销毁 -> 次日重建”的基础设施生命周期策略，以最大化节约 AWS 费用：

* **日间启用，夜间销毁**：通过 Makefile 脚本在每天早晨自动部署必要资源（如 NAT 网关、ALB），夜间自动销毁这些非必要资源。此策略确保在活跃实验时段集群具备完整的网络出口和访问能力，而在闲置时段释放高成本资源。基础设施的状态（如 VPC、数据存储和 Terraform 状态）会被保留，以便第二天快速重建。对于长假或暂停使用的情况，可以选择执行“硬停用”流程，销毁 EKS 控制平面及所有节点，以避免持续计费。

* **固定域名**：借助 Route 53 的 Alias Record，将动态生成的负载均衡器 DNS 映射到固定域名（默认使用 `lab.rendazhang.com`）。即使每天重新创建 ALB，其对外访问地址保持不变，用户和系统集成无需每日更新配置。

* **弹性扩缩容**：集群工作节点采用按需 **Spot 实例**（结合 Karpenter 或 Auto Scaling），根据负载自动伸缩。在无工作负载时可将节点数缩至 0 以节省开销（提供了 `scripts/scale-nodegroup-zero.sh` 脚本可一键将节点组缩容至 0）。恢复实验时，只需重新部署应用或产生新负载，节点便会按需启动。

* **Spot 中断预警**：`post-recreate.sh` 会自动把最新 NodeGroup 的 ASG 订阅到 `spot-interruption-topic`，确保节点被回收前 2 分钟触发 SNS → 邮件/ChatOps，方便预留时间将应用流量疏散或触发自动化操作。

通过以上措施，实验集群在确保功能完整的同时，将日常运行成本控制在低水平。如需了解每天晚上关机、早上重建的具体操作步骤及故障排查，请参阅 [每日 EKS 重建与销毁操作指南](docs/daily-rebuild-teardown-guide.md)。下表为启用成本控制策略下的主要资源月度费用估算：

| 资源                   | 策略                    | 估算/月               |
| -------------------- | --------------------- | ------------------ |
| **EKS 控制平面**         | 按需启用，闲置时段缩容或删除        | \~ \$20 – \$30 USD |
| **工作节点 (NodeGroup)** | Spot 实例 + 自动伸缩，根据负载调节 | 随实验强度动态变化          |
| **监控与 AI 辅助组件**      | 设置采样率上限、预算报警等         | 可控制在 \~ \$20 USD 内 |

*上述费用为近似值，实际花费会因区域和使用情况有所不同。建议设置 AWS Budgets 并结合自动关停策略，及时提醒并规避意外账单。如果需要长时间连续运行集群，可暂时停用上述自动销毁策略，但务必留意由此产生的额外费用。*

## 常见问题 (FAQ)

* **问：如何检查本地工具和 AWS 配额是否满足实验要求？**
  **答**：运行 `make preflight`，脚本会自动检查本地 CLI 工具版本、AWS SSO 登录状态，以及关键配额（如 ENI / vCPU / Spot 使用情况），并生成报告帮助你评估当前环境是否符合要求。

* **问：如何将本项目部署到我的 AWS 账户？需要修改哪些配置？**
  **答**：首先请确保满足文档中提到的所有前置条件，然后在 `infra/aws/terraform.tfvars` 中修改必要的变量以匹配你的环境。例如，将 `profile` 更新为你的 AWS CLI 配置文件名，提供你自有的 S3 Bucket 和 DynamoDB 表用于 Terraform 后端存储，并替换 `eks_admin_role_arn` 为你账户中具有管理员权限的 IAM Role。若使用自定义域名，还需要在 Terraform 配置中将默认的 `lab.rendazhang.com` 改为你的域名并提供对应的 Hosted Zone。完成配置后，按照**安装部署指南**中的步骤执行 Terraform 和相关脚本即可。部署过程中请确保 AWS 凭证有效且有足够权限创建所需资源。

* **问：每天自动销毁和重建集群环境是如何实现的？可以自定义这个调度吗？**
  **答**：本项目通过 Makefile 脚本和 Terraform 模块实现资源的按日启停：早晨执行 `make start` 创建 NAT 网关、ALB 等资源，夜晚执行 `make stop` 销毁这些资源并保留基础设施状态。你可以利用 CI/CD 平台的定时任务实现全自动调度，例如使用 GitHub Actions 的 `cron` 定时触发 `make start/stop`，或通过 AWS CodePipeline 配合 EventBridge 定时事件触发。同样地，你也可以根据需要调整策略：例如，仅在工作日执行自动启停，周末保持关闭，甚至完全停用自动销毁（但需承担额外费用）。调度的灵活性完全取决于你的实验需求。

* **问：如果我希望集群长时间连续运行，是否可以不销毁资源？**
  **答**：可以。上述自动销毁策略主要用于节约成本，你可以选择不执行每日的 `make stop`，使集群和相关资源持续运行。不过请注意，长时间运行将产生持续费用（特别是 EKS 控制平面和 NAT 网关等固定成本）。建议在持续运行时仍采用其他成本控制措施，例如缩减不必要的节点、监控预算消耗等。你也可以改为按需启停的方式，例如只在需要时手动运行脚本创建/删除集群。总之，本项目提供的脚本和策略是可选的，用户可根据实际需求调整资源生命周期管理方式。

* **问：默认提供的域名 `lab.rendazhang.com` 有什么作用？可以更换吗？**
  **答**：该自定义域名通过 Route 53 Alias 记录固定解析到实验集群的 ALB，作用是在重建集群时保持对外访问地址不变。如果你 Fork 本项目或在自己的账户中部署，通常无法使用 `lab.rendazhang.com` 域名。此时你可以**更换为自己的域名**：方法是在你的 Route 53 中创建对应域名的 Hosted Zone，并在 Terraform 配置中将 `lab.rendazhang.com` 修改为你的域名（或如果不想使用自定义域名，也可删除 Terraform 中 `aws_route53_record` 资源直接使用 ALB 默认域名）。更换域名后，需要在访问应用时使用新的域名。如果不设置自定义域名，则可直接使用 AWS ALB 自动分配的域名来访问服务。

* **问：为什么同时使用 Terraform 和 eksctl 两种方式来创建集群？**
  **答**：本项目采用 Terraform 管理底层网络和周边资源（如 VPC、子网、NAT 网关、ALB、IAM 等），而将 EKS 集群本身的创建交由 eksctl 工具执行。这种协同方式主要出于便利和效率的考虑：Terraform 保留底层网络状态，便于多次反复部署，而 eksctl 在创建和删除 Kubernetes 控制平面方面更加快捷。通过先使用 eksctl 创建集群再导入 Terraform，我们既保持了对集群相关资源（如 OIDC 提供商、IRSA 角色）的基础设施即代码管理，又能够在不影响 VPC 等共享资源的情况下频繁重建集群。此外，eksctl 对 EKS 的配置更直观（如节点组规格、Spot 配置、IAM 集成等）。未来我们计划评估 Terraform 官方的 EKS 模块，以决定是否启用 Terraform 对集群的直接创建管理（即打开 Terraform 配置中的 `create_eks` 开关），或者进一步提升 eksctl 脚本的可定制性，实现从 VPC 到 EKS 集群的一站式部署。

## 附录

### 文档

> 📘 [EKS 云原生集群生命周期流程](docs/lifecycle.md)
> 📘 [每日 EKS 重建与销毁操作指南](docs/daily-rebuild-teardown-guide.md)

### 检查清单

* 检查 Terraform 版本 ≥ 1.8，eksctl 版本 ≥ 0.180
* 验证 AWS SSO 登录 token 未过期
* 检测 Helm 仓库是否就绪（如 Helm Repo 更新）
* 检查 kubectl 的 kubeconfig 是否指向目标集群

### 脚本清单

| 脚本名                    | 功能                                                       |
| ------------------------- | --------------------------------------------------------- |
| `preflight.sh`            | 预检 AWS CLI 凭证 + Service Quotas                         | 
| `tf-import.sh`            | 将 EKS 集群资源导入 Terraform 状态                          |
| `post-recreate.sh`        | 自动为最新 NodeGroup 对应的 ASG 绑定 Spot Interruption SNS 通知；带幂等检查 |
| `scale-nodegroup-zero.sh` | 将 EKS 集群所有 NodeGroup 实例数缩容至 0；暂停所有工作节点以降低 EC2 成本    |
| `update-diagrams.sh`      | 图表生成脚本                                                              |

* `update-diagrams.sh` 脚本依赖：需安装 Graphviz
* 脚本的运行日志默认写入 `scripts/logs` 目录下；最近一次已绑定的 ASG 名缓存于 `scripts/.last-asg-bound`，两者均已在 `.gitignore` 排除。

## 未来计划

Renda Cloud Lab 仍在持续演进中，未来规划包括但不限于：

* **eksctl 配置模块化**：将 NodeGroup、Addon 等拆分为独立 YAML 文件，统一放置在 `infra/eksctl/` 目录，并结合 `make start` 自动引用，以提高集群配置的灵活性。
* **预检脚本扩展**：增加本地依赖工具检查、配额趋势监控，并考虑将结果上传至 Slack / Telegram 实现远程提醒。
* **集群自动化部署完善**：视实际情况决定是否使用 Terraform 模块直接创建 EKS 集群（即完全 IaC 化集群），或增强 eksctl 脚本以实现从 VPC 到集群的一键部署。
* **集成完整 CI/CD 流水线**：结合 AWS CodePipeline 等服务，实现从代码提交到容器镜像构建、安全扫描、部署到 EKS 的端到端自动化流水线，并提供示例应用演示持续交付过程。
* **增强 GitOps 与发布策略**：在集群中部署 Argo CD 等工具，支持多环境（Dev/Stage/Prod）的 GitOps 工作流。探索应用分组管理、蓝绿部署/金丝雀发布策略，以提高部署的弹性和可靠性。
* **丰富可观测性与混沌工程场景**：引入日志收集（EFK 或 AWS OpenSearch）、分布式追踪等组件完善 Observability，同时增加 Chaos Mesh 混沌实验示例（如节点故障、网络延迟），提升集群的稳健性。
* **AI Sidecar 实践**：开发并部署示例微服务，演示如何通过 Spring AI 将大型语言模型集成到云原生应用中。例如，基于 AWS Bedrock 的 Titan 模型或 GCP Vertex AI，实现智能客服、内容推荐等场景，并提供参考架构。
* **安全与合规**：增加更多安全措施和成本护栏，如使用 OPA Gatekeeper 编写策略约束 Kubernetes 资源配置、定期镜像漏洞扫描报告、自动化成本分析通知等，帮助使用者在实践中掌握云上治理技巧。

以上路线图将根据社区反馈和技术发展进行调整。如果你对本项目有任何建议或希望增加的功能，欢迎提出 Issue 或参与贡献。

## 🤝 贡献指南

1. **Fork 仓库**，新建功能分支，完成开发后提交 Pull Request。
2. 在每次提交代码前，请运行 `make lint` 或直接执行 `pre-commit run --all-files`，自动完成：Terraform 代码格式化（terraform fmt -recursive）；Terraform 静态分析（tflint）；YAML 配置检查（yamllint）等。
3. CI 流水线通过后，维护者会对 PR 进行审核和合并。如有任何问题会在 PR 下反馈。

非常欢迎社区贡献新的**实验脚本、Terraform 模块、架构图**，或任何改进成本控制的创意！如果有大的想法需要讨论，请提前创建 Issue 并详细描述背景和设计思路。

## 📜 许可证

本项目采用 **MIT 协议** 开源发布。这意味着你可以自由地使用、修改并重新发布本仓库的内容，只需在分发时附上原始许可证声明。

---

> ⏰ **Maintainer**：@Renda — 如果本项目对你有帮助，请不要忘了点亮 ⭐️ Star 支持我们！
