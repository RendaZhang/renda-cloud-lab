# 每日 Terraform 重建与销毁流程操作文档

* Last Updated: July 6, 2025, 23:20 (UTC+8)
* 作者: 张人大（Renda Zhang）

## 🌅 每日重建流程 (Morning Rebuild Procedure)

### 操作目的与背景 (Purpose & Background)

 每日早晨的重建流程旨在恢复前一晚为节省成本而释放的云资源，以便白天开展实验或开发工作。通过在早晨自动部署必要的基础设施（如 NAT 网关、ALB 负载均衡）并确保 EKS 集群正常运行，我们可以在确保功能完整的同时，将不必要的云开销降至最低。这一策略利用 Terraform 和脚本实现云资源的 **“日间启用，夜间销毁”**——每天上午重建环境、晚上销毁高成本资源，从而保留基础设施状态以便快速重建，并避免不必要的支出。
此外，本仓库已通过 Terraform 创建 AWS Budgets（默认 90 USD），当花费接近阈值时会以邮件提醒。(AWS Budgets are provisioned via Terraform with a default 90 USD limit to email alerts when spending nears the threshold.)


### 步骤与命令详解 (Steps and Commands)

1. **AWS SSO 登录 (AWS SSO Login)**：在进行任何 AWS 资源操作之前，需使用 AWS Single Sign-On 登录获取临时凭证。推荐直接执行 `make aws-login`，它会调用 `aws sso login --profile phase2-sso` 并输出登录状态。

   ```bash
   make aws-login
   ```

   *预期输出*: 登录成功后终端无明显输出。如果凭证有效期已过，则上述命令会提示打开浏览器进行重新认证。完成登录后，可继续后续步骤。

2. **(仅首次) 创建 Spot Interruption SNS Topic** (First-Time Topic Setup)：若还未创建 `spot-interruption-topic`，可以在控制台手动操作，或执行下面的命令并订阅邮箱：

   ```bash
   aws sns create-topic --name spot-interruption-topic \
     --profile phase2-sso --region us-east-1 \
     --output text --query 'TopicArn'
   export SPOT_TOPIC_ARN=arn:aws:sns:us-east-1:123456789012:spot-interruption-topic
   aws sns subscribe --topic-arn $SPOT_TOPIC_ARN \
     --protocol email --notification-endpoint you@example.com \
     --profile phase2-sso --region us-east-1
   ```

   打开邮箱点击 **Confirm** 完成订阅。该 Topic 只需创建一次，后续执行 `make post-recreate` 会自动绑定最新 ASG。
   (Open your mailbox and click **Confirm** to finalize the subscription. The topic only needs to be created once; later runs of `make post-recreate` will subscribe the latest ASG automatically.)

3. **启动基础设施 (Start Infrastructure)**：首先启动基础网络和必要组件，包括 NAT 网关和 ALB。此步骤会创建 VPC 下的网络出口 (NAT Gateway，需要 Elastic IP) 和集群入口 (Application Load Balancer) 等资源，为 EKS 集群提供所需的网络环境。

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

     *预期输出*: Terraform 执行成功后，将显示各资源创建明细和总结。


4. **验证 Terraform 状态一致 (Verify Terraform State Consistency)**：Terraform 执行完成后，建议再次运行 `terraform plan`，确保状态与实际资源无偏差。Plan 返回 *No changes* 即表示资源完全同步，可放心进入下一步。

   > 提示：在今后的日常流程中，若怀疑 Terraform 状态与实际资源不同步，可随时运行 `terraform plan` 进行检查。一旦发现 drift，应立即排查原因或通过 `terraform import` 等手段修正，以确保 Terraform 管理的资源与真实环境匹配。

5. **运行 Post Recreate 脚本**：该脚本自动记录日志、简化 AWS ASG 配置，并通过 Helm 确保 Cluster Autoscaler 与集群版本一致。此外，它会检查 NAT 网关、ALB、EKS 控制平面、节点组、日志组等资源是否正常，并验证 SNS 告警订阅是否生效。

   * **Makefile 命令**：执行 `make post-recreate` 调用脚本会在控制台输出日志并保存到 scripts/logs/post-recreate.log 文件中。它简化了 AWS 自动扩缩组（ASG）的通知配置，避免了手动使用 AWS CLI 的复杂操作。此外，脚本会自动通过 Helm 安装 / 升级 Cluster Autoscaler，确保节点自动扩缩容组件与集群版本一致。该脚本具有幂等性，可以多次执行。

   * **手动 CLI 命令**：亦可手动执行脚本或使用 AWS CLI 完成相同操作。推荐直接运行仓库提供的脚本：

     ```bash
     bash scripts/post-recreate.sh
     ```

该脚本执行后，会在控制台输出绑定和资源检查的日志，并将结果保存到 `scripts/logs/post-recreate.log` 文件。手动方式亦可使用 AWS CLI 完成，但需手动查询最新 ASG 名称并验证各种资源状态。脚本在更新 kubeconfig 后会自动通过 Helm 安装/升级 Cluster Autoscaler，并检查 NAT 网关、ALB、EKS 与节点组状态以及日志组与 SNS 通知配置，确保环境完全就绪。

6. **验证控制面日志与 Spot 通知 (Verify Control Plane Logs & Spot Notifications)**：

   * **控制面日志 (Control Plane Logs)**：运行以下命令，确认 `api` 与 `authenticator` 日志已启用，且 CloudWatch 日志组 `/aws/eks/dev/cluster` 已创建：

     ```bash
     aws eks describe-cluster --name dev --profile phase2-sso --region us-east-1 --query "cluster.logging.clusterLogging[?enabled].types" --output table
     aws logs describe-log-groups --profile phase2-sso --region us-east-1 --log-group-name-prefix "/aws/eks/dev/cluster" --query 'logGroups[].logGroupName' --output text
     ```

     预期输出示例：

     ```plaintext
     --------------------------
     |     DescribeCluster    |
     +------+-----------------+
     |  api |  authenticator  |
     +------+-----------------+
     /aws/eks/dev/cluster
     ```

     随后可在 **AWS Console ➜ CloudWatch ➜ Logs ➜ Log groups** 中看到 `api`、`authenticator` 等日志流。

   * **Spot 通知订阅 (Spot Notification Subscription)**：登录 **AWS Console ➜ SNS ➜ Topics ➜ `spot-interruption-topic` ➜ Subscriptions**，应看到状态为 `Confirmed`，并在绑定成功后收到邮件通知。

💡 **改进说明**：现阶段集群完全由 Terraform 管理，Makefile 已统一集成所有操作。首次导入后即可反复重建，无需再运行 eksctl，也避免了多工具并行带来的状态不一致问题。后续可在 `make start` 等命令中加入集群存在性检查，进一步提升流程健壮性。

### 常见错误与排查指引 (Common Errors & Troubleshooting)

* **Terraform 状态锁定 (State lock)**：如果在执行 Terraform 命令时遇到类似 *“Error: Error acquiring the state lock”* 的错误，说明先前的 Terraform 进程未正常解锁状态文件。遇到这种情况，可登录 AWS 控制台删除 DynamoDB 锁定表 (`tf-state-lock`) 中相应的锁条目，或使用命令行强制解锁：

  ```bash
  terraform force-unlock <锁ID> -force
  ```

  *排查提示*: 锁 ID 会在错误信息中提供。**务必确认没有其他 Terraform 进程在运行**后再执行强制解锁，避免并发修改状态。

* **AWS 凭证过期 (SSO Token Expired)**：如果命令行出现 `ExpiredToken`、`InvalidClientTokenId` 等错误，通常是 AWS SSO 凭证已过期或未登录所致。解决办法是在当前终端重新执行 `aws sso login --profile phase2-sso` 登录，然后重试相关 Terraform 或 AWS CLI 操作。为了防止长时间操作期间凭证失效，建议在重要步骤前确认凭证有效（可通过 `aws sts get-caller-identity --profile phase2-sso` 验证）。

* **Elastic IP 配额不足 (EIP Quota)**：NAT 网关创建需要分配公有 IP (EIP)。AWS 默认每区最多提供 5 个 Elastic IP。如果环境中已有多个 EIP 占用，Terraform 在创建 NAT 网关时可能报错 `Error: Error creating NAT Gateway: InsufficientAddressCapacity` 或相关配额错误。此时应检查账户的 EIP 使用情况：执行 `aws ec2 describe-addresses --region us-east-1 --profile phase2-sso` 查看已分配的 EIP 数量。如已达到上限，可释放不需要的 EIP，或通过提交 AWS Support 工单申请提高配额。

* **集群创建失败或超时 (EKS Cluster Creation Failure)**：如果 Terraform 创建 EKS 集群的步骤失败（例如网络不通或权限问题导致控制面创建失败），请首先检查 Terraform 部署的基础设施是否全部创建成功（VPC、子网、路由等是否就绪）。常见原因包括：未正确配置 EKS Role，可能导致 EKS 控制面创建权限不足；或者之前已有同名集群未删除干净导致名称冲突。对于权限问题，可确认 Terraform 配置中的 IAM Role 是否正确。如是名称冲突，需确保将现有的同名集群删除或导入 Terraform 管理：可以通过 AWS CLI 或控制台删除残留的集群，然后重新执行部署。若创建过程长时间无响应，可登录 AWS 控制台查看 EKS 集群状态或 CloudFormation 服务，找到失败原因并针对性处理。

* **Terraform 计划有意外更改 (Unexpected Terraform Plan Changes)**：如果在日常运行 `terraform plan` 或 `make start/stop` 时看到有非预期的资源更改（如计划销毁或新建集群等），应检查是否有人工在 AWS 控制台或其他工具中修改了基础设施（例如修改了安全组规则、删除了某些资源等）。此时建议谨慎执行 Terraform，先弄清变更来源。如确实存在 drift，可通过 Terraform Import 或手动调整 Terraform 配置来消除不一致，然后再次运行 plan 验证无变动后再进行 apply。

## ✅ 验收清单 (Morning Checklist)

早晨重建流程完成后，可根据以下清单逐项核实环境已正确重建：

* ✅ **NAT 网关**：已创建并分配 Elastic IP，状态为 *Available*（可通过 AWS 控制台 VPC 页面或 CLI 命令确认）。
* ✅ **ALB 负载均衡**：已创建并处于 *active* 状态，监听相应端口。若配置了自定义域名 (`lab.rendazhang.com`)，可验证该域名已解析到新的 ALB DNS 地址。
* ✅ **EKS 控制平面**：集群状态为 *ACTIVE*。可以通过 `aws eks describe-cluster --name dev --region us-east-1 --profile phase2-sso` 检查集群存在且状态正常。kubectl 配置已更新，执行 `kubectl get nodes` 可以看到节点状态为 Ready（如果有节点运行）。
* ✅ **节点组及自动伸缩**：默认节点组正常运行。如当前无工作负载且启用了自动扩缩容，节点数可能已自动缩减至 0。这种情况下，`kubectl get nodes` 可能暂时无节点列表，这是预期行为——后续有新工作负载调度时，节点会自动启动。
* ✅ **Cluster Autoscaler**：运行 `kubectl --namespace=kube-system get pods -l "app.kubernetes.io/name=aws-cluster-autoscaler,app.kubernetes.io/instance=cluster-autoscaler"`，Pod 应处于 `Running` 且其 ServiceAccount 注解含有 `role-arn`
* ✅ **控制面日志与 LogGroup**：执行 `aws eks describe-cluster` 与 `aws logs describe-log-groups`，应看到 `api`、`authenticator` 日志已启用，且存在 `/aws/eks/dev/cluster` 日志组。
* ✅ **SNS 通知**：确认 Spot 通知订阅成功。可登录 AWS 控制台查看 SNS 主题 *spot-interruption-topic* 的订阅列表，应包含最新的 Auto Scaling Group（名称以 *eks-ng-mixed* 开头）。或者检查脚本日志 `scripts/logs/post-recreate.log`，最后一行应显示“已绑定最新 ASG”且名称匹配当前集群节点组。

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

   * **Makefile 命令**：执行 `make stop` 即可一键销毁当日启用的外围资源。此命令会在 `infra/aws` 目录下调用 Terraform，将 `create_nat`、`create_alb` 等变量置为 false（默认不修改 `create_eks`，集群控制面保持开启）后执行 `terraform apply`。若希望连同 EKS 控制面一起关闭，可使用 `make stop-hard`，该命令会将 `create_eks=false` 一并销毁集群。如需额外清理 CloudWatch 日志组，可使用 `make stop-all`，它会在 `stop-hard` 基础上调用 `post-teardown.sh`。

   * **手动 Terraform 命令**：也可以手动执行 Terraform 实现相同效果。在 `infra/aws` 目录下运行如下命令关闭相关组件：

     **删除 NAT 和 ALB 资源，保留 EKS 集群运行（常规停止）**：

     ```bash
     terraform apply -auto-approve \
       -var="region=us-east-1" \
       -var="create_nat=false" \
       -var="create_alb=false" \
       -var="create_eks=true"
     ```

     **删除 NAT, ALB & EKS 集群（硬停机）**：

     ```bash
     terraform apply -auto-approve \
       -var="region=us-east-1" \
       -var="create_nat=false" \
       -var="create_alb=false" \
       -var="create_eks=false"
     ```

     上述命令通过将 `create_nat` 和 `create_alb` 设为 false，使 Terraform 销毁 NAT 和 ALB 相关资源。区别在于 `create_eks` 的取值：保持 `create_eks=true` 时，Terraform 将保留其状态中管理的 EKS 集群及节点组资源，不对其做改动；而当 `create_eks=false` 时，Terraform 会一并销毁受其管理的 EKS 集群和节点组。这意味着选择“硬停机”会移除 EKS 控制面和所有节点（以及关联的安全组、OIDC 等 Terraform 管理的附属资源）。执行前请确认已登录 AWS 且后端状态配置正确，以免销毁过程因权限问题中断。

     上述命令执行完毕后，高成本的公网出口和入口资源不再计费。VPC 等基础设施以及 EKS 集群仍保留在 AWS 账户中（这些保留的资源通常不产生显著额外费用）。

    执行硬停机命令后，可通过 `aws eks list-clusters --region us-east-1 --profile phase2-sso` 确认集群已不存在。
    **注意**：若历史上曾使用 eksctl 创建过集群，可能在 CloudFormation 中留下 `eksctl-dev-cluster` 等栈。Terraform 删除集群后，请手动删除这些栈，以防资源残留。
   * **Makefile 命令**：执行 `make destroy-all` 触发一键完全销毁流程。该命令会先调用 `make stop-hard` 删除 EKS 控制面，再运行 `terraform destroy` 一次性删除包括 NAT 网关、ALB、VPC、子网、安全组、IAM 角色等在内的所有资源。最后会自动执行 `post-teardown.sh` 清理 CloudWatch 日志组。`make destroy-all` 会确保首先关闭任何仍在运行的组件，然后清理 Terraform 状态中记录的所有资源。执行前请再次确认 AWS 凭证有效且无重要资源遗漏在状态外。

   * **手动销毁命令**：完整销毁也可通过一条 Terraform 指令完成。在 `infra/aws` 目录下执行：

     ```bash
     terraform destroy -auto-approve -var="region=us-east-1"
     ```

     该命令将基于 Terraform 状态清单删除所有 AWS 资源，包括 EKS 集群控制面、节点组以及 VPC 等网络基础架构。由于使用了 `-auto-approve`，命令将直接执行销毁，无需交互确认。

     *预期输出*: 完全销毁完成后，Terraform 将提示所有资源删除完毕，例如：`Destroy complete! Resources: 30 destroyed.`。此时在 AWS 控制台应看不到与实验相关的任何资源。由于我们使用了远端 S3 后端，Terraform 状态文件本身会保留在状态后端中，但其中已不再有任何资源记录。

     **请注意**：完全销毁后，下次重建前需要重新执行 `terraform init` 初始化，以确保 Terraform 能正确连接远端后端并重新创建所需资源（由于状态文件清空后，Terraform 本地可能需要重新获取后端配置）。

💡 **成本优化提示**：对于每日仅关闭部分资源的场景，如果想进一步节省成本，可考虑在夜间停用时对 EKS 集群采取额外措施。例如，将节点组实例数缩容至 0（如果白天未自动缩容）可确保没有 EC2 实例在夜间运行。本项目提供了辅助脚本 `scripts/scale-nodegroup-zero.sh` 实现一键将节点组缩容至0的功能，可将其集成到销毁流程中作为附加步骤。此外，如果确定每晚都不使用集群，也可考虑使用 `make stop-hard` 实现“硬停机”：该命令在 `make stop` 基础上额外删除了 EKS 控制面，适用于连续多日不使用环境的情形。请根据实际需求选择合适的销毁程度，在成本优化与第二天的重建时间之间取得平衡。

### 常见错误与排查指引 (Common Errors & Troubleshooting)

* **资源依赖导致的销毁失败**：执行 `make stop` 或 Terraform 销毁时，可能遇到因为资源依赖顺序导致的错误。例如，NAT 网关有时需要等待关联的网络接口释放才可完全删除。如果 Terraform 销毁过程出现超时或依赖错误，可尝试再次运行销毁命令。如多次重试仍失败，登录 AWS 控制台检查相关资源状态：确保 NAT 网关已变为 *deleted* 状态，Elastic IP 是否仍分配等。必要时可手动释放未自动删除的资源（例如仍绑定的弹性网卡），然后再执行 Terraform 销毁。

* **AWS 凭证问题**：与早晨步骤类似，若销毁过程中遇到权限相关错误（例如 AWS API 调用失败），请确认 AWS SSO 登录是否仍在有效期内。如果自动调用的 `aws sso login` 未成功，建议手动重新登录后再执行销毁操作。

* **EKS 集群删除缓慢 (Cluster Deletion Slowness)**：如果选择执行了包含 EKS 集群删除的销毁操作，有时删除过程可能较长。尤其当集群内仍有自定义的附加组件或残留的负载均衡、弹性网卡等资源时，Terraform 删除可能卡顿。此时可在 AWS 控制台查看集群删除进度，并检查 CloudFormation 是否存在未删除的栈（例如 `eksctl-dev-cluster` 等旧栈）。必要时手动清理相关资源，然后再次执行 Terraform 销毁。

完成上述夜间关停流程后，环境便仅剩下不计费或低成本的基础部分（如 VPC 等）。第二天早晨即可按照前述步骤，通过 Terraform 一键重建所有资源，实现完整的**一键销毁与重建**循环，而无需额外手动干预 EKS 集群。本指南确保用户每日都能完全依赖 Terraform 管理基础设施，实现成本最优化和操作简便化。

## ✅ 销毁清单验证 (Evening Checklist)

* ✅ **Terraform 状态存储保留 (State bucket retained)**：
  `aws s3 ls s3://phase2-tf-state-us-east-1 --profile phase2-sso` 可看到状态文件。
* ✅ **VPC 与子网保留 (VPC & subnets retained)**：
  `aws ec2 describe-vpcs --region us-east-1 --profile phase2-sso` 及 `aws ec2 describe-subnets` 仍会列出网络资源。
* ❌ **NAT 网关已删除 (NAT Gateway removed)**：
  `aws ec2 describe-nat-gateways --region us-east-1 --profile phase2-sso` 应返回空列表或状态为 `deleted`。
* ❌ **ALB 已删除 (ALB removed)**：
  运行 `aws elbv2 describe-load-balancers --region us-east-1 --profile phase2-sso` 不再包含实验负载均衡。
* ❌ **EKS 集群状态 (EKS cluster state)**：
  如执行 `make stop-hard`，`aws eks list-clusters --region us-east-1 --profile phase2-sso` 中不应出现集群名称；若仅执行 `make stop`，集群依旧存在但工作节点应已缩容至 0。
* ❌ **Spot 通知解绑 (Spot notification unsubscribed)**：
  检查 `scripts/logs/stop.log` 或 SNS 控制台，确认 Auto Scaling Group 已无 Spot 中断订阅。
* ❌ **CloudWatch -> Log Group 已经删除。**

若上述项目均符合预期，即表示夜间销毁流程顺利完成。若发现未删除的资源，可重新运行 Terraform 或检查日志排查原因。
