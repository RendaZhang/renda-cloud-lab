# 每日 Terraform 重建与销毁流程操作文档

* Last Updated: July 5, 2025, 4:00 (UTC+8)
* 作者: 张人大（Renda Zhang）

## 🌅 每日重建流程 (Morning Rebuild Procedure)

### 操作目的与背景 (Purpose & Background)

每日早晨的重建流程旨在恢复前一晚为节省成本而释放的云资源，以便白天开展实验或开发工作。通过在早晨自动部署必要的基础设施（如 NAT 网关、ALB 负载均衡）并确保 EKS 集群正常运行，我们可以在确保功能完整的同时，将不必要的云开销降至最低。这一策略利用 Terraform 和脚本实现云资源的 **“日间启用，夜间销毁”**——每天上午重建环境、晚上销毁高成本资源，从而保留基础设施状态以便快速重建，并避免不必要的支出。

⚠️ **注意**：截至 2025-06-28，我们已将 EKS 集群（控制面与节点组）导入 Terraform 状态，由 Terraform 全权管理。因此每日重建与销毁可完全依赖 Terraform 一键完成，无需再单独运行 eksctl 命令或维护 eksctl 的 YAML 配置文件。这意味着下面涉及 eksctl 的集群创建步骤仅在首次集群创建或参考历史配置时使用，日常流程中已不再需要。

### 步骤与命令详解 (Steps and Commands)

1. **AWS SSO 登录 (AWS SSO Login)**：在进行任何 AWS 资源操作之前，需使用 AWS Single Sign-On 登录获取临时凭证。推荐直接执行 `make aws-login`，它会调用 `aws sso login --profile phase2-sso` 并输出登录状态。

   ```bash
   make aws-login
   ```

   *预期输出*: 登录成功后终端无明显输出。如果凭证有效期已过，则上述命令会提示打开浏览器进行重新认证。完成登录后，可继续后续步骤。

2. **启动基础设施 (Start Infrastructure)**：首先启动基础网络和必要组件，包括 NAT 网关和 ALB。此步骤会创建 VPC 下的网络出口 (NAT Gateway，需要 Elastic IP) 和集群入口 (Application Load Balancer) 等资源，为 EKS 集群提供所需的网络环境。

   * **Makefile 命令**：执行 `make start` 一键应用 Terraform 模板来创建 NAT 网关和 ALB。该命令内部会在 `infra/aws` 目录下调用 `terraform apply`，将变量 `create_nat`、`create_alb` 设置为 true（`create_eks` 亦默认为 true）。这样将启用 NAT 和 ALB 相关资源，并确保 EKS 集群资源包含在部署中。如果前一晚执行了集群销毁，则此步骤会通过 Terraform **新建** EKS 控制面和节点组；若集群尚存在于 Terraform 状态中，Terraform 将识别已有集群且不重复创建，仅验证配置一致性。

   * **手动 Terraform 命令**：等价操作是手动运行 Terraform 部署。在终端中切换到项目目录的 `infra/aws` 路径，然后执行以下命令：

     ```bash
     terraform apply -auto-approve \
       -var="region=us-east-1" \
       -var="create_nat=true" \
       -var="create_alb=true" \
       -var="create_eks=true"
     ```

     上述命令会根据 Terraform 配置在区域 `us-east-1` 中创建启用 NAT 和 ALB 的基础设施，以及包含 EKS 集群的相关资源部署。其中 `-auto-approve` 用于自动确认，无需人工交互。变量 `create_nat=true` 和 `create_alb=true` 启用 NAT 网关与 ALB 资源的创建。`create_eks=true` 则包含 EKS 集群及节点组资源的创建或保持。Terraform 将使用 **远端状态后端**（S3 Bucket: `phase2-tf-state-us-east-1`，DynamoDB 锁表: `tf-state-lock`）记录此次部署的状态。

     *预期输出*: Terraform 执行成功后，将显示各资源创建明细和总结。例如，可能看到类似输出：

     ```plaintext
     module.nat.aws_eip.nat[0]: Creation complete after 5s [id=eip-0abc12345d6ef7890]
     module.nat.aws_nat_gateway.ngw[0]: Creation complete after 10s [id=nat-0123456789abcdef0]
     module.alb.aws_lb.this: Creation complete after 15s [id=alb-12ABC34DEFGH5678]
     Apply complete! Resources: 6 added, 0 changed, 0 destroyed.
     ```

     上述示例中，Terraform 成功创建了 NAT 网关 (`nat-0123456789abcdef0`)、分配了 EIP (`eip-0abc12345d6ef7890`)，以及 ALB 负载均衡实例 (`alb-12ABC34DEFGH5678`) 等资源，并报告新增了 6 个资源。

3. **创建 EKS 控制平面 (Create EKS Control Plane)** *(首次创建可选 / 历史参考)*：基础网络就绪后，创建或导入 EKS 集群的控制平面和节点组。如果集群已经由 Terraform 管理，此步骤可跳过。

   ⚠️ **说明**：以下基于 eksctl 的创建过程仅适用于首次创建集群或参考历史配置。在 EKS 集群已导入 Terraform 后，日常不需要再执行这些命令，集群的创建与销毁将由 Terraform 自动完成。

   * **手动 eksctl 命令**：直接运行 eksctl 命令创建集群（仅首次需要）：

     ```bash
     eksctl create cluster -f infra/eksctl/eksctl-cluster.yaml \
       --profile phase2-sso --region us-east-1
     ```

     该命令将读取 eksctl 提供的 YAML 配置文件，创建名为 `dev` 的 EKS 集群（包含控制平面和名为 “ng-mixed” 的节点组）。执行过程中，eksctl 会在后台使用 CloudFormation 在既有 VPC 子网中创建控制面节点并启动指定数量的工作节点。完成后，本地 `~/.kube/config` 将配置好凭据和上下文，方便通过 kubectl 访问集群。

     *预期输出*: eksctl 成功创建集群后，终端会输出集群创建进度及结果。例如：

     ```plaintext
     [ℹ]  eksctl version 0.180.0
     [ℹ]  using region us-east-1
     [✔]  EKS cluster "dev" in "us-east-1" region is ready
     [✔]  saved kubeconfig as "/home/<user>/.kube/config"
     [ℹ]  nodegroup "ng-mixed" has 2 node(s) running
     ```

     以上示例表示 EKS 控制平面及默认节点组已创建完毕，并已将凭据保存到 kubeconfig 文件。若集群已存在，则 eksctl 会返回错误提示集群名称冲突。在这种情况下，请确认前一晚是否已正确销毁集群，或采用导入方式将现有集群纳入 Terraform 管理，以避免重复创建错误。

   * **Terraform 导入 (Terraform Import)**：若采用 eksctl 首次创建集群与节点组，集群就绪后应立即执行仓库提供的脚本 `scripts/tf-import.sh`，一键将 EKS 控制面、节点组、OIDC Provider 及 IRSA 角色导入 Terraform 状态，便于后续完全由 Terraform 管理。

     ```bash
     bash scripts/tf-import.sh
     ```

     脚本会自动解析当前集群名称、节点组及账户信息，并依次运行 `terraform import` 命令。导入完成后，可通过下列命令验证状态：

     ```bash
     terraform state list | grep eks
     ```

     正常情况下将看到 EKS 集群、节点组以及 OIDC Provider 等资源都已列在 Terraform 状态中。随后，执行计划检查确保资源完全同步：

     ```bash
     terraform plan -var="region=us-east-1"
     ```

     理想情况下，Plan 结果应显示 **No changes**（无更改），例如：

     ```plaintext
     No changes. Infrastructure is up-to-date.
     ```

     这表明 Terraform 配置与现有基础设施完全一致，没有 drift。如果出现任何要新增、修改或销毁的提示，说明导入可能有遗漏或配置不匹配，需要进一步检查。在确认 Plan 显示 *No changes* 后，即可放心进行日常的 Terraform 启停操作而不会破坏状态一致性。

4. **验证 Terraform 状态一致 (Verify Terraform State Consistency)**：经过上述部署和（如适用）导入步骤后，务必验证 Terraform 状态与实际资源无偏差。这一步通常通过 Terraform Plan 已在上面完成：确认 `terraform plan` 返回 *No changes* 即表示所有资源状态一致。若 Plan 显示无变更，则每日的重建过程可以保证不会因状态漂移而产生意外更改。

   > 提示：在今后的日常流程中，若怀疑 Terraform 状态与实际资源不同步，可随时运行 `terraform plan` 进行检查。一旦发现 drift，应立即排查原因或通过 `terraform import` 等手段修正，以确保 Terraform 管理的资源与真实环境匹配。

5. **绑定 Spot 实例通知 (Bind Spot Interruption Notification)**：为确保集群工作节点的 Spot 实例中断通知能够被及时捕获，需在集群重建后重新绑定 SNS 通知。

   * **Makefile 命令**：执行 `make post-recreate` 调用脚本自动为当前 EKS 节点组的 Auto Scaling Group (ASG) 订阅 Spot Interruption SNS 主题。该脚本会自动检索名称以 `eks-ng-mixed` 开头的最新 ASG，并将其与预先创建的 SNS Topic (`spot-interruption-topic`) 进行绑定。脚本设计有幂等性，会记录上次绑定的 ASG 名称，防止重复操作。

   * **手动 CLI 命令**：亦可手动执行脚本或使用 AWS CLI 完成相同操作。推荐直接运行仓库提供的脚本：

     ```bash
     bash scripts/post-recreate.sh
     ```

     该脚本执行后，会在控制台输出绑定过程日志，并将日志保存到 `scripts/logs/post-recreate.log` 文件。手动方式也可采用 AWS CLI 调用 `aws autoscaling put-notification-configuration`，但需先查询最新 ASG 名称并提供 SNS Topic Arn。使用仓库脚本可避免出错并简化操作。此外，该脚本在更新 kubeconfig 后会自动通过 Helm 安装/升级 Cluster Autoscaler，确保节点自动扩缩容组件始终与集群版本保持一致。

     *预期输出*: 脚本成功绑定通知后，将输出类似日志：

     ```plaintext
     [2025-06-28 09:00:01] 📣 开始执行 post-recreate 脚本
     [2025-06-28 09:00:02] 🔄 绑定 SNS 通知到 ASG: eks-ng-mixed-NodeGroup-1A2B3C4D5E
     [2025-06-28 09:00:03] ✅ 已绑定并记录最新 ASG: eks-ng-mixed-NodeGroup-1A2B3C4D5E
     ```

     如果该 ASG 之前已经绑定过通知，脚本会输出 “当前 ASG 已绑定过，无需重复绑定”，以避免重复操作。

💡 **改进说明**：上述重建流程在启用 Terraform 接管 EKS 集群后得到了优化。现在，Makefile 命令已统一集成 Terraform 操作，并在首次导入后避免了 eksctl 与 Terraform 并行管理资源可能导致的状态不一致问题。例如，我们已**将 EKS 集群完全交由 Terraform 管理**，无需每日运行 eksctl，这减少了 Terraform 配置中硬编码依赖（如之前固定节点 IAM Role ARN、启动模板 ID 等）的维护负担。今后，可考虑在 Makefile 的 `start` 或 `all` 目标中自动检查 AWS SSO 登录状态，以确保每次运行 Terraform 前凭证有效；另外，在 `make start` 脚本中加入对集群存在与否的判断（例如通过 AWS CLI 或 Terraform 状态查询），如目标集群已存在则跳过创建步骤，从而进一步提高流程健壮性。

### 常见错误与排查指引 (Common Errors & Troubleshooting)

* **Terraform 状态锁定 (State lock)**：如果在执行 Terraform 命令时遇到类似 *“Error: Error acquiring the state lock”* 的错误，说明先前的 Terraform 进程未正常解锁状态文件。遇到这种情况，可登录 AWS 控制台删除 DynamoDB 锁定表 (`tf-state-lock`) 中相应的锁条目，或使用命令行强制解锁：

  ```bash
  terraform force-unlock <锁ID> -force
  ```

  *排查提示*: 锁 ID 会在错误信息中提供。**务必确认没有其他 Terraform 进程在运行**后再执行强制解锁，避免并发修改状态。

* **AWS 凭证过期 (SSO Token Expired)**：如果命令行出现 `ExpiredToken`、`InvalidClientTokenId` 等错误，通常是 AWS SSO 凭证已过期或未登录所致。解决办法是在当前终端重新执行 `aws sso login --profile phase2-sso` 登录，然后重试相关 Terraform 或 AWS CLI 操作。为了防止长时间操作期间凭证失效，建议在重要步骤前确认凭证有效（可通过 `aws sts get-caller-identity --profile phase2-sso` 验证）。

* **Elastic IP 配额不足 (EIP Quota)**：NAT 网关创建需要分配公有 IP (EIP)。AWS 默认每区最多提供 5 个 Elastic IP。如果环境中已有多个 EIP 占用，Terraform 在创建 NAT 网关时可能报错 `Error: Error creating NAT Gateway: InsufficientAddressCapacity` 或相关配额错误。此时应检查账户的 EIP 使用情况：执行 `aws ec2 describe-addresses --region us-east-1 --profile phase2-sso` 查看已分配的 EIP 数量。如已达到上限，可释放不需要的 EIP，或通过提交 AWS Support 工单申请提高配额。

* **集群创建失败或超时 (EKS Cluster Creation Failure)**：如果 Terraform 或 eksctl 创建 EKS 集群的步骤失败（例如网络不通或权限问题导致 EKS 控制面创建失败），请首先检查 Terraform 部署的基础设施是否全部创建成功（VPC、子网、路由等是否就绪）。常见原因包括：未正确配置 EKS Admin Role（变量 `eks_admin_role_arn` 是否设置了正确的 IAM 角色 ARN），可能导致 EKS 控制面创建权限不足；或者之前已有同名集群未删除干净导致名称冲突。对于权限问题，可确认 Terraform 配置中的 IAM Role ARN 是否正确。如是名称冲突，需确保将现有的同名集群删除或导入 Terraform 管理：可以通过 AWS CLI 或控制台删除残留的集群\*\*（不再建议使用 eksctl 删除集群，因为现已改用 Terraform 管理集群）\*\*，然后重新执行部署。若创建过程长时间无响应，可登录 AWS 控制台查看 EKS 集群状态或 CloudFormation 服务（如果此前使用 eksctl 创建过集群，eksctl 会在 CloudFormation 中留下管理栈）查看相关事件日志，以找到失败原因并针对性处理（例如等待较长时间以让资源创建完成，或在出现配额不足时参考上面的步骤检查并提升配额）。

* **Terraform 计划有意外更改 (Unexpected Terraform Plan Changes)**：如果在日常运行 `terraform plan` 或 `make start/stop` 时看到有非预期的资源更改（如计划销毁或新建集群等），应检查是否有人工在 AWS 控制台或其他工具中修改了基础设施（例如修改了安全组规则、删除了某些资源等）。此时建议谨慎执行 Terraform，先弄清变更来源。如确实存在 drift，可通过 Terraform Import 或手动调整 Terraform 配置来消除不一致，然后再次运行 plan 验证无变动后再进行 apply。

## ✅ 验收清单 (Morning Checklist)

早晨重建流程完成后，可根据以下清单逐项核实环境已正确重建：

* ✅ **NAT 网关**：已创建并分配 Elastic IP，状态为 *Available*（可通过 AWS 控制台 VPC 页面或 CLI 命令确认）。
* ✅ **ALB 负载均衡**：已创建并处于 *active* 状态，监听相应端口。若配置了自定义域名 (`lab.rendazhang.com`)，可验证该域名已解析到新的 ALB DNS 地址。
* ✅ **EKS 控制平面**：集群状态为 *ACTIVE*。可以通过 `eksctl get cluster --name dev --region us-east-1` （或 `aws eks describe-cluster --name dev`）检查集群存在且状态正常。kubectl 配置已更新，执行 `kubectl get nodes` 可以看到节点状态为 Ready（如果有节点运行）。
* ✅ **节点组及自动伸缩**：默认节点组正常运行。如当前无工作负载且启用了自动扩缩容，节点数可能已自动缩减至 0。这种情况下，`kubectl get nodes` 可能暂时无节点列表，这是预期行为——后续有新工作负载调度时，节点会自动启动。
* ✅ **Cluster Autoscaler**：运行 `kubectl --namespace=kube-system get pods -l "app.kubernetes.io/name=aws-cluster-autoscaler,app.kubernetes.io/instance=cluster-autoscaler"`，Pod 应处于 `Running` 且其 ServiceAccount 注解含有 `role-arn`
* ✅ **Spot 中断通知**：确认 Spot 通知订阅成功。可登录 AWS 控制台查看 SNS 主题 *spot-interruption-topic* 的订阅列表，应包含最新的 Auto Scaling Group（名称以 *eks-ng-mixed* 开头）。或者检查脚本日志 `scripts/logs/post-recreate.log`，最后一行应显示“已绑定最新 ASG”且名称匹配当前集群节点组。

---

## 🌙 每日销毁流程 (Evening Teardown Procedure)

### 操作目的与背景 (Purpose & Background)

每日工作结束阶段，我们需要销毁当日创建的高成本云资源，以避免在闲置的夜间继续产生费用。通过夜间**关停主要资源**的流程，我们释放如 NAT 网关、ALB 等按时计费的组件，同时保留基础设施的网络和状态（例如 VPC、子网以及 Terraform State），以加速次日的环境重建。这种 **“下班关停，上班重启”** 模式确保了实验环境在非工作时段的云成本降至最低（仅可能保留少量控制面固定成本），同时保留必要的网络配置用于下次启动。

### 步骤与命令详解 (Steps and Commands)

1. **AWS SSO 登录 (AWS SSO Login)**：在销毁资源之前，先确保 AWS 登录有效（同样使用 `phase2-sso` Profile）。如果自早晨登录后已过了数小时，凭证可能过期，建议重新执行登录命令。直接运行以下命令即可：

   ```bash
   make aws-login
   ```

   登录方法同上，不再赘述。确认凭证有效后继续后续操作。

2. **停止高成本资源 (Shut Down High-Cost Resources)**：该步骤通过 Terraform 销毁白天创建的 NAT 网关、ALB 等资源，但保留基础网络框架，方便日后重建。EKS 集群的控制面通常在此操作中予以保留运行（除非选择了同时销毁集群，详见后文“硬停机”说明或下一步的完全销毁）。

   * **Makefile 命令**：执行 `make stop` 即可一键销毁当日启用的外围资源。此命令会在 `infra/aws` 目录下调用 Terraform，将 `create_nat`、`create_alb` 等变量置为 false（默认不修改 `create_eks`，集群控制面保持开启）后执行 `terraform apply`。若希望连同 EKS 控制面一起关闭，可使用 `make stop-hard`，该命令会将 `create_eks=false` 一并销毁集群。两者均内置 AWS SSO 登录检查，确保操作时具有有效权限。

   * **手动 Terraform 命令**：也可以手动执行 Terraform 实现相同效果。在 `infra/aws` 目录下运行如下命令关闭相关组件：

     **保留 EKS 集群运行（常规停止）**：

     ```bash
     terraform apply -auto-approve \
       -var="region=us-east-1" \
       -var="create_nat=false" \
       -var="create_alb=false" \
       -var="create_eks=true"
     ```

     **删除 EKS 集群（硬停机，可选）**：

     ```bash
     terraform apply -auto-approve \
       -var="region=us-east-1" \
       -var="create_nat=false" \
       -var="create_alb=false" \
       -var="create_eks=false"
     ```

     上述命令通过将 `create_nat` 和 `create_alb` 设为 false，使 Terraform 销毁 NAT 和 ALB 相关资源。区别在于 `create_eks` 的取值：保持 `create_eks=true` 时，Terraform 将保留其状态中管理的 EKS 集群及节点组资源，不对其做改动；而当 `create_eks=false` 时，Terraform 会一并销毁受其管理的 EKS 集群和节点组。这意味着选择“硬停机”会移除 EKS 控制面和所有节点（以及关联的安全组、OIDC 等 Terraform 管理的附属资源）。执行前请确认已登录 AWS 且后端状态配置正确，以免销毁过程因权限问题中断。

     *预期输出*: Terraform 会显示各资源销毁的过程和结果。例如，在未删除集群的情况下，输出可能类似：

     ```plaintext
     module.alb.aws_lb.this: Destroying... [id=alb-12ABC34DEFGH5678]
     module.alb.aws_lb.this: Destruction complete after 5s
     module.nat.aws_nat_gateway.ngw[0]: Destroying... [id=nat-0123456789abcdef0]
     module.nat.aws_nat_gateway.ngw[0]: Destruction complete after 8s
     module.nat.aws_eip.nat[0]: Destroying... [id=eip-0abc12345d6ef7890]
     module.nat.aws_eip.nat[0]: Destruction complete after 1s
     Apply complete! Resources: 0 added, 0 changed, 5 destroyed.
     ```

     上述输出表示 ALB 实例、NAT 网关及其相关 Elastic IP 等资源均已成功删除。由于在该示例中 EKS 集群被保留（未包含 `create_eks=false`），Terraform 最终报告销毁了 5 个资源。执行完毕后，高成本的公网出口和入口资源不再计费。VPC 等基础设施以及 EKS 集群仍保留在 AWS 账户中（这些保留的资源通常不产生显著额外费用）。

     如果执行的是“硬停机”并删除了 EKS 集群，Terraform 的输出将在上述基础上增加 EKS 集群及节点组的销毁日志。例如：

     ```plaintext
     module.eks.aws_eks_node_group.default: Destroying... [id=dev:ng-mixed]
     module.eks.aws_eks_node_group.default: Destruction complete after 3s
     module.eks.aws_eks_cluster.dev: Destroying... [id=dev]
     module.eks.aws_eks_cluster.dev: Destruction complete after 4s
     Apply complete! Resources: 0 added, 0 changed, 7 destroyed.
     ```

     可以看到集群和节点组资源也已删除（此示例中 Terraform 共销毁 7 个资源，包括 EKS 相关资源）。在 AWS 控制台或使用 `eksctl get cluster --name dev --region us-east-1` 命令验证时，会发现集群已不存在。**注意**：由于我们采用 Terraform 管理集群，删除操作会通过 EKS API 进行，若集群存在由 eksctl 创建的底层 CloudFormation 管理栈，它可能在 Terraform 删除集群后处于 *DELETE\_FAILED* 等状态。这种情况下，可手动登录 AWS 控制台删除残留的 CloudFormation 栈（如 `eksctl-dev-cluster`），或使用 `eksctl delete cluster --name dev --wait` 确认集群相关资源清理干净，以防止遗留资源占用。

3. **（可选）彻底销毁所有资源 (Optional: Full Teardown of All Resources)**：如果需要完全销毁整个实验环境（包括 EKS 控制平面以及所有基础设施），可选择执行此可选步骤。**请谨慎对待**完整销毁操作——它将删除**所有**由 Terraform 创建或管理的资源，并清空整个环境。

   * **Makefile 命令**：执行 `make destroy-all` 触发一键完全销毁流程。该命令会先调用 `make stop-hard` 删除 EKS 控制面，再运行 `terraform destroy` 一次性删除包括 NAT 网关、ALB、VPC、子网、安全组、IAM 角色等在内的所有资源。由于集群已纳入 Terraform 状态管理，不再需要单独运行 eksctl 删除集群。`make destroy-all` 会确保首先关闭任何仍在运行的组件，然后清理 Terraform 状态中记录的所有资源。执行前请再次确认 AWS 凭证有效且无重要资源遗漏在状态外。

   * **手动销毁命令**：完整销毁也可通过一条 Terraform 指令完成。在 `infra/aws` 目录下执行：

     ```bash
     terraform destroy -auto-approve -var="region=us-east-1"
     ```

     该命令将基于 Terraform 状态清单删除所有 AWS 资源，包括 EKS 集群控制面、节点组以及 VPC 等网络基础架构。由于使用了 `-auto-approve`，命令将直接执行销毁，无需交互确认。

     *预期输出*: 完全销毁完成后，Terraform 将提示所有资源删除完毕，例如：`Destroy complete! Resources: 30 destroyed.`。此时在 AWS 控制台应看不到与实验相关的任何资源。由于我们使用了远端 S3 后端，Terraform 状态文件本身会保留在状态后端中，但其中已不再有任何资源记录。**请注意**：完全销毁后，下次重建前需要重新执行 `terraform init` 初始化，以确保 Terraform 能正确连接远端后端并重新创建所需资源（由于状态文件清空后，Terraform 本地可能需要重新获取后端配置）。

   > ℹ️ **说明**：在过去的流程中，由于 EKS 集群并未纳入 Terraform，一键销毁需要先通过 eksctl 删除集群再 Terraform Destroy。如今我们已简化为 Terraform 独立完成所有删除工作，但在执行完全销毁时仍需小心。完整销毁会移除**所有**资源，执行前请确认不再需要保留任何环境数据。

💡 **成本优化提示**：对于每日仅关闭部分资源的场景，如果想进一步节省成本，可考虑在夜间停用时对 EKS 集群采取额外措施。例如，将节点组实例数缩容至 0（如果白天未自动缩容）可确保没有 EC2 实例在夜间运行。本项目提供了辅助脚本 `scripts/scale-nodegroup-zero.sh` 实现一键将节点组缩容至0的功能，可将其集成到销毁流程中作为附加步骤。此外，如果确定每晚都不使用集群，也可考虑使用 `make stop-hard` 实现“硬停机”：该命令在 `make stop` 基础上额外删除了 EKS 控制面，适用于连续多日不使用环境的情形。请根据实际需求选择合适的销毁程度，在成本优化与第二天的重建时间之间取得平衡。

### 常见错误与排查指引 (Common Errors & Troubleshooting)

* **资源依赖导致的销毁失败**：执行 `make stop` 或 Terraform 销毁时，可能遇到因为资源依赖顺序导致的错误。例如，NAT 网关有时需要等待关联的网络接口释放才可完全删除。如果 Terraform 销毁过程出现超时或依赖错误，可尝试再次运行销毁命令。如多次重试仍失败，登录 AWS 控制台检查相关资源状态：确保 NAT 网关已变为 *deleted* 状态，Elastic IP 是否仍分配等。必要时可手动释放未自动删除的资源（例如仍绑定的弹性网卡），然后再执行 Terraform 销毁。

* **AWS 凭证问题**：与早晨步骤类似，若销毁过程中遇到权限相关错误（例如 AWS API 调用失败），请确认 AWS SSO 登录是否仍在有效期内。如果自动调用的 `aws sso login` 未成功，建议手动重新登录后再执行销毁操作。

* **EKS 集群删除缓慢 (Cluster Deletion Slowness)**：如果选择执行了包含 EKS 集群删除的销毁操作，有时集群的删除可能需要较长时间。尤其当集群内仍有自定义的附加组件（Add-ons）或 AWS 上残留的负载均衡、弹性网卡等资源时，删除过程可能卡顿。Terraform 在删除 EKS 集群时如果长时间无响应，可通过 AWS 控制台的 EKS 页面查看集群删除进度。如集群由 eksctl 创建过，亦可检查 CloudFormation 中对应的栈（例如 `eksctl-dev-cluster`）是否存在删除失败的事件；如果某些资源（如安全组或 ENI）阻碍了 CloudFormation 栈删除，可手动删除这些残留资源，然后再次执行 Terraform 销毁或直接删除 CloudFormation 栈。在必要情况下，也可以使用 AWS CLI（`aws eks delete-cluster` 等）或 eksctl 带 `--wait` 参数辅助监控删除进程。总之，确保所有相关资源都清理后，Terraform 销毁才能顺利完成。

完成上述夜间关停流程后，环境便仅剩下不计费或低成本的基础部分（如 VPC 等）。第二天早晨即可按照前述步骤，通过 Terraform 一键重建所有资源，实现完整的**一键销毁与重建**循环，而无需额外手动干预 EKS 集群。本指南确保用户每日都能完全依赖 Terraform 管理基础设施，实现成本最优化和操作简便化。

## ✅ 销毁清单验证 (Evening Checklist)

* ✅ **NAT 网关已删除 (NAT Gateway removed)**：
  `aws ec2 describe-nat-gateways --region us-east-1 --profile phase2-sso` 应返回空列表或状态为 `deleted`。
* ✅ **ALB 已删除 (ALB removed)**：
  运行 `aws elbv2 describe-load-balancers --region us-east-1 --profile phase2-sso` 不再包含实验负载均衡。
* ✅ **EKS 集群状态 (EKS cluster state)**：
  如执行 `make stop-hard`，`aws eks list-clusters --region us-east-1 --profile phase2-sso` 中不应出现集群名称；若仅执行 `make stop`，集群依旧存在但工作节点应已缩容至 0。
* ✅ **Spot 通知解绑 (Spot notification unsubscribed)**：
  检查 `scripts/logs/stop.log` 或 SNS 控制台，确认 Auto Scaling Group 已无 Spot 中断订阅。
* ❌ **VPC 与子网保留 (VPC & subnets retained)**：
  `aws ec2 describe-vpcs --region us-east-1 --profile phase2-sso` 及 `aws ec2 describe-subnets` 仍会列出网络资源。
* ❌ **Terraform 状态存储保留 (State bucket retained)**：
  `aws s3 ls s3://phase2-tf-state-us-east-1 --profile phase2-sso` 可看到状态文件。

若上述项目均符合预期，即表示夜间销毁流程顺利完成。若发现未删除的资源，可重新运行 Terraform 或检查日志排查原因。
