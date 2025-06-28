# 每日 Terraform 重建与销毁流程操作文档

* Last Updated: June 28, 2025, 19:30 (UTC+8)
* 作者: 张人大（Renda Zhang）

## 🌅 每日重建流程 (Morning Rebuild Procedure)

### 操作目的与背景 (Purpose & Background)

每日早晨的重建流程旨在恢复前一晚为节省成本而释放的云资源，以便白天开展实验或开发工作。通过在早晨自动部署必要的基础设施（如 NAT 网关、ALB 负载均衡）和确保 EKS 集群正常运行，我们可以在确保功能完整的同时，将不必要的云开销降至最低。这一策略利用 Terraform 和脚本实现云资源的 **“日间启用，夜间销毁”**，即每天上午重建环境、晚上销毁高成本资源，从而保留基础设施状态以便快速重建，并避免不必要的支出。

### 步骤与命令详解 (Steps and Commands)

1. **AWS SSO 登录 (AWS SSO Login)**：在进行任何 AWS 资源操作之前，需使用 AWS Single Sign-On 登录获取临时凭证。请确保使用配置的 AWS CLI Profile `phase2-sso` 进行登录。若未登录或凭证过期，后续 Terraform 和 AWS CLI 命令将无法访问AWS资源。

   ```bash
   aws sso login --profile phase2-sso
   ```

   *预期输出*: 登录成功后终端无明显输出。如果凭证有效期已过，则上述命令会提示打开浏览器进行重新认证。完成登录后，可继续后续步骤。

2. **启动基础设施 (Start Infrastructure)**：首先启动基础网络和必要组件，包括 NAT 网关和 ALB。此步骤会创建 VPC 下的网络出口 (NAT Gateway，需要 Elastic IP) 和集群入口 (Application Load Balancer) 等资源，为 EKS 集群提供所需的网络环境。

   * **Makefile 命令**：执行 `**make start**` 一键应用 Terraform 模板来创建 NAT 网关和 ALB。该命令内部会在 `infra/aws` 目录下调用 `terraform apply`，将变量 `create_nat`、`create_alb` 设置为 true，从而启用 NAT 和 ALB 相关资源（`create_eks` 亦为 true，以确保与 EKS 相关的IAM和子网配置就绪，但此步骤并不直接创建控制面）。
   * **手动 Terraform 命令**：等价操作是手动运行 Terraform 部署。在终端中切换到项目目录的 `infra/aws` 路径，然后执行以下命令：

     ```bash
     terraform apply -auto-approve \
       -var="region=us-east-1" \
       -var="create_nat=true" \
       -var="create_alb=true" \
       -var="create_eks=true"
     ```

     上述命令会根据 Terraform 配置在区域 `us-east-1` 中创建启用 NAT 和 ALB 的基础设施。其中 `-auto-approve` 用于自动确认，无需人工交互。变量 `create_nat=true` 和 `create_alb=true` 启用 NAT 网关与 ALB 资源的创建。`create_eks=true` 确保 Terraform 配置中与 EKS 相关的子网、IAM 等依赖资源保持就绪，但实际的 EKS 控制面稍后通过 eksctl 创建。Terraform 将使用 **远端状态后端**（S3 Bucket: `phase2-tf-state-us-east-1`，DynamoDB 锁表: `tf-state-lock`）记录此次部署的状态。
     *预期输出*: Terraform 执行成功后，将显示各资源创建明细和总结。例如，可能看到类似输出：

   ```plaintext
   module.nat.aws_eip.nat[0]: Creation complete after 5s [id=eip-0abc12345d6ef7890]
   module.nat.aws_nat_gateway.ngw[0]: Creation complete after 10s [id=nat-0123456789abcdef0]
   module.alb.aws_lb.this: Creation complete after 15s [id=alb-12ABC34DEFGH5678]
   Apply complete! Resources: 6 added, 0 changed, 0 destroyed.
   ```

   上述示例中，Terraform 成功创建了 NAT 网关 (`nat-0123456789abcdef0`)、分配了 EIP (`eip-0abc12345d6ef7890`)，以及 ALB 负载均衡实例 (`alb-12ABC34DEFGH5678`) 等资源，并报告新增了 6 个资源。

3. **创建 EKS 控制平面 (Create EKS Control Plane)**：基础网络就绪后，创建或导入 EKS 集群的控制平面和节点组。

   * **Makefile 命令**：执行 `**make start-cluster**` 利用 **eksctl** 创建 EKS 集群。此命令会根据 `infra/eksctl/eksctl-cluster.yaml` 中的配置，在名称为 `dev` 的集群（Region 为 `us-east-1`）上创建控制平面和默认节点组，并将 kubeconfig 配置更新到本地文件以便后续使用。命令中使用了 `--profile phase2-sso` 指定 AWS 凭证配置，`--region us-east-1` 指定区域，`--kubeconfig ~/.kube/config` 指定更新的 kubeconfig 路径。Makefile 在执行该命令前会再次调用 AWS SSO 登录以确保权限有效。
   * **手动 eksctl 命令**：若不使用 Makefile，也可以直接运行 eksctl 命令创建集群：

     ```bash
     eksctl create cluster -f infra/eksctl/eksctl-cluster.yaml \
       --profile phase2-sso --region us-east-1
     ```

     该命令将读取 eksctl 提供的 YAML 配置文件，创建名为 `dev` 的 EKS 集群（包含控制平面和名为 “ng-mixed” 的节点组）。执行过程中，eksctl 会在后台使用 CloudFormation 创建VPC子网中的控制面节点并启动指定数量的工作节点。完成后，本地`~/.kube/config`将会配置好凭证和上下文，方便通过 kubectl 访问集群。
     *预期输出*: eksctl 成功创建集群后，终端会输出集群创建进度及结果。例如：

   ```plaintext
   [ℹ]  eksctl version 0.180.0
   [ℹ]  using region us-east-1
   [✔]  EKS cluster "dev" in "us-east-1" region is ready
   [✔]  saved kubeconfig as "/home/<user>/.kube/config"
   [ℹ]  nodegroup "ng-mixed" has 2 node(s) running
   ```

   以上示例表示 EKS 控制平面及默认节点组已创建完毕，并已将凭据保存到 kubeconfig 文件。若集群已存在，则 eksctl 会返回错误提示集群名称冲突。在这种情况下，请确认前一晚是否已正确销毁集群或使用不同名称的集群，以避免重复创建错误。

4. **绑定 Spot 实例通知 (Bind Spot Interruption Notification)**：为确保集群工作节点的 Spot 实例中断通知能够被及时捕获，需在集群重建后重新绑定 SNS 通知。

   * **Makefile 命令**：执行 `**make post-recreate**` 调用脚本自动为当前 EKS 节点组的 Auto Scaling Group (ASG) 订阅 Spot Interruption SNS 主题。该脚本会自动检索名称以 `eks-ng-mixed` 开头的最新 ASG，并将其与预先创建的 SNS Topic (`spot-interruption-topic`) 进行绑定。脚本设计有幂等性，会记录上次绑定的 ASG 名称，防止重复操作。
   * **手动 CLI 命令**：亦可手动执行脚本或使用 AWS CLI 完成相同操作。推荐直接运行仓库提供的脚本：

     ```bash
     bash scripts/post-recreate.sh
     ```

     该脚本执行后，会在控制台输出绑定过程日志，并将日志保存到 `scripts/logs/post-recreate.log` 文件。手动方式也可采用 AWS CLI 调用 `aws autoscaling put-notification-configuration`，但需先查询最新 ASG 名称并提供 SNS Topic Arn，使用脚本可避免出错。
     *预期输出*: 脚本成功绑定通知后，将输出类似日志：

   ```plaintext
   [2025-06-28 09:00:01] 📣 开始执行 post-recreate 脚本
   [2025-06-28 09:00:02] 🔄 绑定 SNS 通知到 ASG: eks-ng-mixed-NodeGroup-1A2B3C4D5E
   [2025-06-28 09:00:03] ✅ 已绑定并记录最新 ASG: eks-ng-mixed-NodeGroup-1A2B3C4D5E
   ```

   如果该 ASG 之前已经绑定过通知，脚本会输出“当前 ASG 已绑定过，无需重复绑定”，以避免重复操作。

💡 **改进建议**：当前重建流程在首次执行前需要手动 AWS SSO 登录，并假定集群不存在。如果集群未销毁重复执行 `make all` 可能出现错误。建议在 Makefile 的 `start` 或 `all` 目标中加入 AWS SSO 登录检查，以确保 Terraform 操作有有效凭证。另外，可在 `make start-cluster` 前增加对集群存在性的判断（例如通过 `eksctl get cluster`），如目标集群已存在则跳过创建或改为导入，这将避免因重复创建集群而导致的报错。长期来看，建议统一由一种工具管理 EKS 集群的创建与销毁：例如**将 EKS 集群全部交由 Terraform 管理**，或**完全使用 eksctl 管理集群**，以减少 Terraform 配置中硬编码依赖（如固定的节点角色 ARN、启动模板 ID 等）带来的维护负担。

### 常见错误与排查指引 (Common Errors & Troubleshooting)

* **Terraform 状态锁定 (State lock)**：如果在执行 Terraform 命令时遇到类似 *“Error: Error acquiring the state lock”* 的错误，说明先前的 Terraform 进程未正常解锁状态文件。遇到这种情况，可登录 AWS 控制台删除 DynamoDB 锁定表 (`tf-state-lock`) 中相应的锁条目，或使用命令行强制解锁：

  ```bash
  terraform force-unlock <锁ID> -force
  ```

  *排查提示*: 锁 ID 会在错误信息中提供。**务必确认没有其他 Terraform 进程在运行**后再执行强制解锁，避免并发修改状态。
* **AWS 凭证过期 (SSO Token Expired)**：如果命令行出现 `ExpiredToken`、`InvalidClientTokenId` 等错误，通常是 AWS SSO 凭证已过期或未登录所致。解决办法是在当前终端重新执行 `aws sso login --profile phase2-sso` 登录，然后重试相关 Terraform 或 AWS CLI 操作。为了防止长时间操作期间凭证失效，建议在重要步骤前确认凭证有效（可通过 `aws sts get-caller-identity --profile phase2-sso` 验证）。
* **Elastic IP 配额不足 (EIP Quota)**：NAT 网关创建需要分配公有 IP (EIP)。AWS 默认每区最多提供 5 个 Elastic IP。如果环境中已有多个 EIP 占用，Terraform 在创建 NAT 网关时可能报错 `Error: Error creating NAT Gateway: InsufficientAddressCapacity` 或相关配额错误。此时应检查账户的 EIP 使用情况：执行 `aws ec2 describe-addresses --region us-east-1 --profile phase2-sso` 查看已分配的 EIP 数量。如已达到上限，可释放不需要的 EIP，或通过提交 AWS Support 工单申请提高配额。
* **集群创建失败或超时**：如果 `eksctl create cluster` 步骤失败（例如网络不通或 CloudFormation 堆栈错误），请首先检查Terraform的基础设施是否全部创建成功（VPC、子网、路由等）。常见原因包括：未正确配置 EKS Admin Role (`eks_admin_role_arn`)，导致 EKS 控制面创建权限不足；或者之前已有同名集群未删除干净。对于权限问题，可确认 Terraform 配置中的 IAM Role ARN 是否正确；如是名称冲突，可使用 `eksctl delete cluster --name dev --region us-east-1 --profile phase2-sso` 清理残留集群，然后重试创建。若 eksctl 超时卡住，可登录 AWS 控制台查看 CloudFormation 事件，找到失败原因并针对性处理（例如某些资源创建耗时较长时耐心等待，或Quota不足时按上一步检查配额）。

### ✅ 验收清单 (Morning Checklist)

早晨重建流程完成后，可根据以下清单逐项核实环境已正确重建：

* ✅ **NAT 网关**：已创建并分配 Elastic IP，状态为 *Available*（可通过 AWS 控制台 VPC 页面或 CLI 命令确认）。
* ✅ **ALB 负载均衡**：已创建并处于 *active* 状态，监听相应端口。若配置了自定义域名 (`lab.rendazhang.com`)，可验证该域名已解析到新的 ALB DNS 地址。
* ✅ **EKS 控制平面**：集群状态为 *ACTIVE*，`eksctl get cluster --name dev --region us-east-1` 返回正常。kubectl 配置已更新，执行 `kubectl get nodes` 可以看到节点状态为 Ready（如果有节点运行）。
* ✅ **节点组及自动伸缩**：默认节点组正常运行。如当前无工作负载且启用了自动扩缩容，节点数可能已自动缩减至 0。这种情况下，`kubectl get nodes` 可能暂时无节点列表，这是预期行为。后续有新工作负载调度时，节点会自动启动。
* ✅ **Spot 中断通知**：确认 Spot 通知订阅成功。可登录 AWS 控制台查看 SNS 主题 *spot-interruption-topic* 的订阅列表，应包含最新的 Auto Scaling Group (以 *eks-ng-mixed* 开头)。或者检查脚本日志 `scripts/logs/post-recreate.log`，最后一行应显示“已绑定最新 ASG”且名称匹配当前集群节点组。

---

## 🌙 每日销毁流程 (Evening Teardown Procedure)

### 操作目的与背景 (Purpose & Background)

每日工作的结束阶段，我们需要销毁当日创建的高成本云资源，以避免在闲置的夜间继续产生费用。通过夜间**关停主要资源**的流程，我们释放如 NAT 网关、ALB 等按时计费的组件，同时保留基础设施的状态（例如 VPC、子网以及 Terraform状态）以加速次日的环境重建。这种 **“下班关停，上班重启”** 的模式确保了实验集群在非工作时段的成本几乎为零，同时保留必要的网络和数据配置用于下次启动。

### 步骤与命令详解 (Steps and Commands)

1. **AWS SSO 登录 (AWS SSO Login)**：在销毁资源之前，先确保 AWS 登录有效（同样使用 `phase2-sso` Profile）。如果自早晨登录后已过了数小时，凭证可能过期，建议重新执行登录命令以防止销毁过程中出现认证错误：

   ```bash
   aws sso login --profile phase2-sso
   ```

   登录方法同上，不再赘述。确认凭证有效后继续后续操作。

2. **停止高成本资源 (Shut Down High-Cost Resources)**：该步骤通过 Terraform 销毁白天创建的 NAT 网关、ALB 等资源，但保留基础设施的网络框架，方便日后重建。EKS 集群控制平面在此操作中将被保留（除非选择完全销毁，见下一步）。

   * **Makefile 命令**：执行 `**make stop**` 即可一键销毁当日启用的外围资源。此命令会调用 Terraform，将 `create_nat`、`create_alb` 等变量置为 false 后执行 `terraform apply`。结果是 Terraform 会删除 NAT 网关（释放其 Elastic IP）和 ALB 等所有在早晨创建的可选资源，但不会删除 VPC、子网、安全组以及（如果未特别指定）EKS 集群本身。该命令内置了 AWS SSO 登录步骤，确保操作有权限。
   * **手动 Terraform 命令**：手动执行可采用与早晨类似的 Terraform 命令，但将相关组件关闭。在 `infra/aws` 目录执行：

     ```bash
     terraform apply -auto-approve \
       -var="region=us-east-1" \
       -var="create_nat=false" \
       -var="create_alb=false" \
       -var="create_eks=false"
     ```

     该命令通过将 `create_nat` 和 `create_alb` 设为 false，使 Terraform 销毁 NAT 和 ALB 相关资源。同时传入 `create_eks=false` 意味着不保留由 Terraform 管理的 EKS 相关资源。如果 Terraform 之前有创建 EKS NodeGroup 等，也会一并移除。但由于 EKS 控制面最初是通过 eksctl 创建的，并不在 Terraform 状态内，所以这里不会删除控制面。执行前请确认已登录 AWS 且 backend 配置正确，以免销毁过程因权限问题中断。
     *预期输出*: Terraform 会显示销毁各资源的过程和结果。例如：

   ```plaintext
   module.alb.aws_lb.this: Destroying... [id=alb-12ABC34DEFGH5678]
   module.alb.aws_lb.this: Destruction complete after 5s
   module.nat.aws_nat_gateway.ngw[0]: Destroying... [id=nat-0123456789abcdef0]
   module.nat.aws_nat_gateway.ngw[0]: Destruction complete after 8s
   module.nat.aws_eip.nat[0]: Destroying... [id=eip-0abc12345d6ef7890]
   module.nat.aws_eip.nat[0]: Destruction complete after 1s
   Apply complete! Resources: 0 added, 0 changed, 5 destroyed.
   ```

   上述输出表示 ALB 实例、NAT 网关及其相关 Elastic IP 等资源均已成功删除。执行完毕后，高成本的公网出口和入口资源不再计费。VPC 等基础设施仍保留在 AWS 账户中，但这些资源通常不产生额外费用。

3. **（可选）彻底销毁所有资源 (Optional: Full Teardown of All Resources)**：如果在某些情况下需要完全销毁整个实验环境（包括 EKS 控制平面及所有基础设施），可选择执行此可选步骤。不过请谨慎对待完整销毁操作——它将删除**所有**由 Terraform 创建的资源以及集群本身。

   * **Makefile 命令**：执行 `**make destroy-all**` 触发一键完全销毁流程。该命令首先调用 `make stop-cluster` 使用 eksctl 删除名为 `dev` 的 EKS 集群控制面和所有节点组。随后，`make destroy-all` 会调用 `terraform destroy` 销毁剩余的所有资源（包括 VPC、子网、安全组、网络ACL等）。此操作等价于从 AWS 中移除所有与本实验环境相关的资源，执行前请确保确实不再需要保留任何内容。
   * **手动命令组合**：完整销毁也可手动分两步完成：首先使用 eksctl 删除 EKS 集群，然后执行 Terraform destroy。

     1. **删除 EKS 集群控制面**：

        ```bash
        eksctl delete cluster --name dev --region us-east-1 --profile phase2-sso
        ```

        等待上述命令完成，确认输出显示 EKS 集群及其所有节点组已删除。此过程中，eksctl 将删除控制面的所有管理节点以及云中由 EKS 创建的附属资源（如托管的安全组、CloudFormation 栈等）。
     2. **销毁剩余基础设施**：

        ```bash
        terraform destroy -auto-approve -var="region=us-east-1"
        ```

        该命令会基于 Terraform 状态将余下的所有AWS资源删除，包括VPC、本地网关、路由表、IAM角色等。由于使用了 `-auto-approve`，命令将直接执行销毁，无需交互确认。
        *预期输出*: 完全销毁完成后，Terraform 将提示所有资源删除完毕，例如：`Destroy complete! Resources: 25 destroyed.`。此时在 AWS 控制台应看不到与实验相关的任何资源。S3 后端存储的 Terraform state 文件仍会保留，但其中不再有资源记录。请注意，完全销毁后，**下次重建前需要重新执行** `terraform init` **初始化**，以确保Terraform能正确连接后端状态并重建环境。

💡 **改进建议**：对于每日只执行部分资源关闭的场景，可以考虑在夜间停用时自动缩容或停止集群工作节点，从而进一步节省成本。例如，**将节点组实例数缩至 0**（如果尚未自动缩容）可确保没有 EC2 实例在夜间运行。本项目已经提供了辅助脚本 `scripts/scale-nodegroup-zero.sh` 实现一键缩容节点组至0的功能，可将其集成到销毁流程中作为附加步骤。此外，如果确定每晚都不使用集群，也可考虑使用 `make stop-hard` 实现“硬停机”：该命令在 `make stop` 基础上额外删除了 EKS 控制面，适用于连续多日不使用环境的情形。请根据实际需求选择合适的销毁程度，在成本优化与第二天的重建时间之间取得平衡。

### 常见错误与排查指引 (Common Errors & Troubleshooting)

* **资源依赖导致的销毁失败**：执行 `make stop` 或 Terraform 销毁时，可能遇到因为资源依赖顺序导致的失败。例如，NAT 网关有时需要等待关联的网络接口释放才可完全删除。如果 Terraform 销毁过程出现超时或依赖错误，可尝试再次运行销毁命令。如多次重试仍失败，登录 AWS 控制台检查相关资源状态：确保 NAT 网关已变为 *deleted* 状态，Elastic IP 是否仍分配等。必要时可手动释放卡住的资源，然后再执行 Terraform 销毁。
* **AWS 凭证问题**：类似于早晨步骤，若销毁过程中遇到权限相关错误（例如 AWS API 调用失败），请确认 AWS SSO 登录是否仍在有效期内。如果自动调用的 `aws sso login` 未成功，建议手动登录后重新执行销毁。
* **集群删除卡顿**：如果选择执行了完整销毁（包含 EKS 集群删除），有时 eksctl 删除集群可能需要较长时间，尤其当集群内仍有自建的自定义资源（如自托管的Add-ons或ELB未删除干净）。可以通过 `eksctl delete cluster` 增加 `--wait` 参数以等待删除完成，或通过 AWS 控制台的 CloudFormation 服务查看 `eksctl-dev-cluster` 栈的删除进度。如某些资源导致 CloudFormation 栈删除失败（例如某些安全组被保留），可根据错误提示手动删除残留资源，然后再次执行集群删除命令。

### ✅ 验收清单 (Evening Checklist)

结束当日环境销毁后，请根据以下清单核实关键资源已成功清理或按预期保留：

* ✅ **NAT 网关**：已删除。通过 AWS 控制台查看 VPC -> NAT Gateways，应不再有白天创建的 NAT 网关实例。如果有残留，状态应为 *deleted* 并在短时间后消失。对应分配的 Elastic IP 也应自动释放回地址池，可在 EC2控制台的 Elastic IP 列表中确认释放情况。
* ✅ **ALB 负载均衡**：已删除。检查 EC2 控制台的负载均衡器列表，确认不再存在白天创建的 ALB。如果使用了自定义域名，DNS 记录仍保留但其 Alias 目标将指向无效的 ALB ARN（属预期情况，可在下次重建时恢复映射）。
* ✅ **EKS 集群**：根据选择的销毁程度决定处理结果：

  * *部分销毁（常规 make stop）*: EKS 控制平面仍保留。登录 EKS 控制台确认 `dev` 集群处于 Active 状态。此时由于节点可能缩容为0，集群无运行节点属于正常现象。
  * *完整销毁（make destroy-all）*: 集群应已从 EKS 控制台消失。执行 `eksctl get cluster --region us-east-1` 将不再列出 `dev` 集群。
* ✅ **Terraform 状态**：检查 Terraform 远端状态文件。部分销毁的情况下，状态文件中应仍保存着基础设施资源（VPC 等）的信息，而 NAT、ALB 等资源应标记为已销毁。完整销毁后，Terraform 状态文件中不应残留任何资源记录。若状态不一致或锁定（参考上文状态锁问题），可在下次运行前进行清理或解锁操作。
* ✅ **成本监控**：确认 AWS 账户当天的费用记录正常。经过 nightly teardown，预计持续计费的主要资源应仅剩下少量基础设施（例如保留的弹性IP如果有保留、或EKS控制面每日按时收费部分）。建议养成查看 AWS Billing 或 Budgets 报告的习惯，确保销毁流程达到预期的节费效果。如果发现费用未下降，排查是否有资源未删除干净（如遗留的 EC2 实例、EIP 等）。

---

以上每日重建与销毁流程可帮助您在开发实验中高效地启停云资源。请根据实际需要调整流程，例如工作日启用/周末停用，或在特定场景采用完整销毁策略。通过合理运用 Terraform 和自动化脚本，云环境的管理将更为安全、可控，同时避免不必要的开支。
