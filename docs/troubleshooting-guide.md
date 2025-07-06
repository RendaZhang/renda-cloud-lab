# 集群故障排查指南 (Troubleshooting Guide)

* Last Updated: July 6, 2025, 17:00 (UTC+8)
* 作者: 张人大（Renda Zhang）

## 简介 (Purpose)

本文档汇总了 **renda-cloud-lab** 项目在集群搭建与运维过程中常见的问题和解决方案，采用中英文混排（中文说明+英文术语）形式进行说明。每个问题包括：问题现象、背景场景、复现方式、根因分析、修复方法、相关命令和适用版本等条目，以便快速定位和解决类似故障。

## 问题分类 (Issue Categories)

* **Terraform Import**：与 Terraform 资源导入相关的问题。
* **IRSA (IAM Roles for Service Accounts)**：与 Kubernetes 服务账户 IAM 角色绑定相关的问题。
* **Helm**：Helm 部署和命名相关的问题。
* **OIDC**：与 EKS OIDC 身份提供商配置相关的问题。
* **AutoScaling (Cluster Autoscaler)**：集群自动伸缩（Cluster Autoscaler）相关的问题。
* **其他 Kubernetes 命令**：如 `kubectl` 命令使用错误等问题。

---

## Helm 部署 cluster-autoscaler 时 IRSA 注解配置错误导致 CrashLoopBackOff

* **问题现象 (What Happened)**：使用 Helm 安装 Cluster Autoscaler 后，Pod 不断重启（CrashLoopBackOff），日志提示没有权限访问 AWS API，例如缺少 `autoscaling:DescribeAutoScalingGroups` 等权限。
* **背景场景 (Context)**：在 EKS 集群上通过 Helm Chart 部署 Cluster Autoscaler，并尝试使用 IRSA (IAM Roles for Service Accounts) 方式绑定 IAM 角色。如果服务账户的注解配置错误（如注解 Key 或值不正确），则 Pod 无法获取到 IAM 角色。
* **复现方式 (How to Reproduce)**：执行如 `helm install ca autoscaler/cluster-autoscaler --namespace kube-system --set awsRegion=... --set rbac.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=""`（错误地省略或写错角色 ARN），然后查看 Pod 状态 `kubectl get pods -n kube-system | grep autoscaler`，发现 `CrashLoopBackOff`。
* **根因分析 (Root Cause)**：Cluster Autoscaler Pod 缺乏必要的 AWS 权限。具体地，IRSA 需要将 Kubernetes 服务账户注解为对应的 IAM 角色。官方要求使用如 `eks.amazonaws.com/role-arn=arn:aws:iam::ACCOUNT_ID:role/RoleName` 的格式。如果注解漏写、拼写错误或使用了错误的 IAM ARN，Pod 就不会获得对应角色权限，导致调用 AWS API 权限被拒绝而重启。
* **修复方法 (Fix / Resolution)**：检查并修正服务账户注解。确保在 Helm 参数或 Kubernetes manifest 中，使用正确的注解键 `eks.amazonaws.com/role-arn`，并指定完整的 IAM 角色 ARN。例如：

  ```bash
  kubectl annotate serviceaccount -n kube-system cluster-autoscaler eks.amazonaws.com/role-arn=arn:aws:iam::111122223333:role/ClusterAutoscalerRole
  ```

  或在 Helm 安装命令中通过 `--set rbac.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::111122223333:role/ClusterAutoscalerRole"` 指定。之后重启 Autoscaler Pod 使其重新获取 IAM 角色。还需确认 IAM 角色已附加包含 `autoscaling:Describe*`、`ec2:Describe*` 等权限的策略。
* **相关命令 (Commands Used)**：

  * 查看 Pod 日志：`kubectl -n kube-system logs deploy/cluster-autoscaler`。
  * 查看服务账户注解：`kubectl -n kube-system describe sa cluster-autoscaler`。
  * 添加注解：见上文 `kubectl annotate` 命令。
* **适用版本 (Version Info)**：EKS 版本 ≥1.18，Cluster Autoscaler Chart v9.x（具体版本根据使用情况）。

---
## Helm 安装 cluster-autoscaler 报错：wrong type for value; expected string; got map[string]interface {}

* **问题现象 (What Happened)**：执行 Helm 安装命令时，模板渲染失败并报错：
  ```
  Error: template: cluster-autoscaler/templates/serviceaccount.yaml:13:40: executing "cluster-autoscaler/templates/serviceaccount.yaml" at <$v>: wrong type for value; expected string; got map[string]interface {}
  ```
* **背景场景 (Context)**：使用 `--set` 传入 `eks.amazonaws.com/role-arn` 等包含 `.` 的键名时，Helm 会将点号解释为嵌套路径，导致注解被解析成 map。
* **复现方式 (How to Reproduce)**：示例命令：
  ```bash
  helm install ca autoscaler/cluster-autoscaler \
    --namespace kube-system \
    --set rbac.serviceAccount.annotations.eks.amazonaws.com/role-arn=arn:aws:iam::111122223333:role/ClusterAutoscalerRole
  ```
  上述命令会触发 `wrong type for value` 的错误。
* **根因分析 (Root Cause)**：未转义的点号使 Helm 将该键拆分为多级 map，而模板期望的是字符串键，导致类型不匹配。
* **修复方法 (Fix / Resolution)**：在 `--set` 中对点号使用 `\\.` 转义，例如：
  ```bash
  --set rbac.serviceAccount.annotations."eks\\.amazonaws\\.com/role-arn"="arn:aws:iam::111122223333:role/ClusterAutoscalerRole"
  ```
  或者改用 `--values values.yaml` 明确传入 YAML 结构。
* **补充建议 (Additional Tips)**：带有 IRSA 的 EKS 部署经常需要配置此注解，推荐统一使用转义或单引号 `--set 'key.with\\.dots=value'` 的形式，避免 shell 或 Helm 解析问题。
* **适用版本 (Version Info)**：Helm v3.x，Cluster Autoscaler Chart v9.x 及以上。

---

## Terraform `aws.billing` alias 报 “No valid credential sources found”

* **问题现象 (What Happened)**
  运行 `terraform plan` / `make stop-hard` 等命令时，初始化 `provider["registry.terraform.io/hashicorp/aws"].billing` 阶段失败，终端输出：
  ```
  Error: No valid credential sources found
  │
  │ Error: failed to refresh cached credentials, no EC2 IMDS role found, operation error ec2imds: GetMetadata, request canceled, context deadline exceeded
  ````

* **背景场景 (Context)**
在 budgets.tf 中为 **AWS Budgets** 声明了专用 alias：
  ```hcl
  provider "aws" {
    alias  = "billing"
    region = "us-east-1"
  }
  ````

本地通过 **AWS SSO** 登录 (`phase2-sso` profile)。如果当前 Shell 未 export `AWS_PROFILE`，或 SSO token 过期，Terraform 初始化 alias 时将走完整的 AWS SDK credential chain，最终回落至 **IMDS** 而失败。

* **根因分析 (Root Cause)**

  *alias* provider 与默认 provider 是两条独立的 credential chain。
  当 Shell 未暴露任何凭证，且不在 EC2 环境时，SDK 报 `no EC2 IMDS role found`，从而触发 *No valid credential sources found*。

* **修复方法 (Fix / Resolution)**

  1. **刷新 SSO 并导出 profile**（最简单）
     ```bash
     aws sso login --profile phase2-sso
     export AWS_PROFILE=phase2-sso    # 或在 Makefile 默认 export
     ```
  2. **在 alias provider 内显式指定 profile**
     ```hcl
     provider "aws" {
       alias   = "billing"
       region  = "us-east-1"
       profile = var.aws_profile   # 默认 "phase2-sso"
     }
     ```
  3. **CI 场景**：使用 Access Key / OIDC Role，或 `aws sso login --no-browser` 预热 token。
  4. 若只是 Fork & 无 Billing 权限，可在 `terraform apply -var="create_budget=false"` 下跳过 Budget 资源，避免 alias provider 被实例化。

* **相关命令 (Commands Used)**
  ```bash
  aws sts get-caller-identity --profile phase2-sso
  terraform providers
  terraform plan -var="create_budget=false"
  ```

* **适用版本 (Version Info)**
  * Terraform ≥ 1.6
  * AWS Provider ≥ 5.x
  * AWS CLI v2 + SSO

---

## Terraform 导入 IAM Role Policy Attachment 使用短名失败（需使用完整 ARN）

* **问题现象 (What Happened)**：执行 `terraform import aws_iam_role_policy_attachment.xxx ROLE_NAME/POLICY_NAME` 报错：提示 `unexpected format of ID ... expected <role-name>/<policy_arn>`，或者提示 `ValidationError: The specified value for roleName is invalid`。
* **背景场景 (Context)**：Terraform 管理 IAM 资源时，需要把现有的 IAM Policy Attachment 导入到 state。根据 Terraform 文档，`aws_iam_role_policy_attachment` 的 import ID 必须是 `role_name/policy_arn` 格式。如果误用短名或只用 ARN，导入会失败。
* **复现方式 (How to Reproduce)**：已有角色 `MyRole`，策略 ARN `arn:aws:iam::123456789012:policy/MyPolicy` 已附加在该角色上。尝试 `terraform import aws_iam_role_policy_attachment.my-attach MyRole/MyPolicy`，Terraform 会报 ID 格式错误；尝试只用 `MyRole` 或只用 ARN 导入，均报错。
* **根因分析 (Root Cause)**：Terraform 要求 `aws_iam_role_policy_attachment` 的 ID 由角色名和策略 ARN 通过斜杠 `/` 连接构成。使用短名（如只写 `policy/MyPolicy`）或只写角色名都会被视为格式不对导致失败。正如文档所述：*“the ID is the combination of the role name and policy ARN, so you would use `role-name/arn:aws:iam::...:policy/policy-name` as the ID.”*。
* **修复方法 (Fix / Resolution)**：在 Terraform 导入时使用完整格式。示例：

  ```bash
  terraform import aws_iam_role_policy_attachment.my_attach MyRole/arn:aws:iam::123456789012:policy/MyPolicy
  ```

  注意替换 `MyRole` 和策略 ARN 为实际值。这样 Terraform 就能正确识别并导入该资源。
* **相关命令 (Commands Used)**：

  * 导入命令示例：`terraform import aws_iam_role_policy_attachment.my_attach MyRole/arn:aws:iam::123456789012:policy/MyPolicy`。
  * 导入成功后，可用 `terraform state show aws_iam_role_policy_attachment.my_attach` 查看详细信息。
* **适用版本 (Version Info)**：Terraform AWS Provider v2.x 及以上，Terraform v0.12+。

---

## OIDC Provider 的 URL 固定写死导致重建失败隐患

* **问题现象 (What Happened)**：多次拆建 EKS 集群过程中，Terraform 计划（`terraform plan`）提示 OIDC Provider 需要替换或删除。例如，集群销毁后重建时出现错误，提示已有同名 OIDC Provider 无法创建，或是 OIDC Provider URL 与集群不匹配。
* **背景场景 (Context)**：EKS 集群创建时，会生成一个对应的 IAM OIDC Provider，用于 IRSA 身份验证。如果在 Terraform 配置中硬编码了 OIDC 提供商的 URL（比如复制粘贴 `oidc.eks.<region>.amazonaws.com/id/<cluster-id>`），则当集群重建时，新的 OIDC Issuer URL 与旧的不同，导致 Terraform 认定资源变更。
* **复现方式 (How to Reproduce)**：在 Terraform 配置里直接填入某次集群的 OIDC URL，如：

  ```hcl
  resource "aws_iam_openid_connect_provider" "oidc" {
    url             = "oidc.eks.us-west-2.amazonaws.com/id/XXXXXXXXXXXXXX"
    client_id_list  = ["sts.amazonaws.com"]
    thumbprint_list = [ ... ]
  }
  ```

  第一次创建后正常；销毁集群并再次运行 Terraform 时，新的 EKS 集群会有不同的 OIDC Issuer，导致 `terraform plan` 发现 URL 改变或资源冲突。
* **根因分析 (Root Cause)**：硬编码 OIDC URL 缺乏灵活性。正确做法是动态获取当前集群的 OIDC Issuer。比如在 Terraform 模块中可以使用 `aws_eks_cluster.this[0].identity[0].oidc[0].issuer` 作为数据源，通过 `replace(..., "https://", "")` 取出不带前缀的提供商 URL。在样例代码中：

  ```hcl
  url = replace(
    try(aws_eks_cluster.this[0].identity[0].oidc[0].issuer, ""),
    "https://", ""
  )
  ```

  这样每次都从 EKS 集群中获取当前的 OIDC URL，避免固定死旧值导致资源不匹配。
* **修复方法 (Fix / Resolution)**：修改 Terraform 配置，不手动填写 OIDC URL，而是引用 EKS 集群的属性。如上文所示，使用 `aws_eks_cluster.cluster.identity[0].oidc[0].issuer`（去掉 `https://`）动态赋值给 `aws_iam_openid_connect_provider.url`。或者使用 `eksctl get cluster -o json` 等命令实时获取集群身份提供商 URL。总之，保持 OIDC Provider 的 URL 与当前集群保持一致即可避免重建时出错。
* **相关命令 (Commands Used)**：

  * 查看集群 OIDC URL：`aws eks describe-cluster --name my-cluster --query "cluster.identity.oidc.issuer" --output text`。
  * Terraform 计划命令：`terraform plan` 查看修改结果，确保 OIDC URL 通过动态引用得来。
  * Terraform 导入（如需要）：`terraform import aws_iam_openid_connect_provider.oidc <provider_arn>` 将现有 OIDC Provider 纳入管理。
* **适用版本 (Version Info)**：Terraform AWS Provider v3.x 以上，EKS 及 eksctl 版本无特殊要求。

---

## 创建 Deployment 失败 – 错误地将 `--requests=cpu=400m` 写在 `kubectl create` 命令中

* **问题现象 (What Happened)**：执行类似 `kubectl create deployment mydep --image=nginx --requests=cpu=400m` 命令时，出现报错提示未知标志，Deployment 未创建成功。
* **背景场景 (Context)**：用户想快速创建一个 Deployment 并设置资源请求，在 `kubectl create deployment` 命令中加入了 `--requests` 参数。实际上，`kubectl create deployment` 支持的选项只有镜像、端口、副本数等常规字段，并不包含 `--requests`。
* **复现方式 (How to Reproduce)**：在任意 Kubernetes 集群，执行：

  ```bash
  kubectl create deployment test-dep --image=nginx --requests=cpu=400m
  ```

  结果会报错：`Error: unknown flag: --requests` 或忽略该参数并不设置资源。
* **根因分析 (Root Cause)**：`kubectl create deployment` 子命令不支持 `--requests` 参数。其文档列出的有效标志包括 `--image`, `--port`, `--replicas` 等，并未提及资源请求相关标志。`--requests` 是 `kubectl run` 的一个选项，而不是 `create deployment` 的。在不被识别的情况下，命令执行失败或忽略了资源请求配置。
* **修复方法 (Fix / Resolution)**：应使用正确的命令或方式来设置资源请求。解决方案包括：

  1. **使用 `kubectl run`**：`kubectl run test-dep --image=nginx --requests=cpu=400m` 支持 `--requests` 参数。
  2. **使用 YAML 定义**：编写 Deployment YAML，在容器规格中添加 `resources.requests` 字段，然后 `kubectl apply -f`。例如：

     ```yaml
     spec:
       containers:
       - name: nginx
         image: nginx
         resources:
           requests:
             cpu: "400m"
     ```
  3. **先创建后编辑**：先 `kubectl create deployment test-dep --image=nginx`，再用 `kubectl set resources deployment test-dep --requests=cpu=400m` 或编辑 Deployment 进行修改。
* **相关命令 (Commands Used)**：

  * 查看 `kubectl create deployment` 文档：[官方参考](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_deployment/) 列举的可用标志（见）。
  * 正确创建示例：`kubectl create deployment mydep --image=nginx --port=80 --replicas=2`。
  * 设置资源命令：`kubectl set resources deployment mydep --requests=cpu=400m`。
* **适用版本 (Version Info)**：kubectl v1.18+，Kubernetes 集群 v1.18+。

---

## 无法找到 Deployment 名称（Helm 安装时名称自动拼接）

* **问题现象 (What Happened)**：按照文档期望，集群里应该有名为 `cluster-autoscaler` 的 Deployment，但执行 `kubectl get deployment` 没有找到对应名字的资源。怀疑部署失败或丢失，但实际 Helm release 正常。
* **背景场景 (Context)**：使用 Helm 部署资源时，Helm 默认会将 release 名称作为前缀自动添加到 Kubernetes 资源名中。这是 Helm 的设计：所有生成的资源名通常以 `RELEASE-NAME-` 开头。如果部署时 Helm release 名称不是 `cluster-autoscaler`，则资源名不会是单纯的 `cluster-autoscaler`。
* **复现方式 (How to Reproduce)**：假设使用命令 `helm install autoscaler k8s-cluster-autoscaler/cluster-autoscaler` 将 Chart 安装为 release 名称 `autoscaler`，那么其生成的 Deployment 实际名为 `autoscaler-cluster-autoscaler`。执行 `kubectl get deployments` 可以看到以 `autoscaler-` 前缀开头的 Deployment，而单纯查 `kubectl get deploy cluster-autoscaler` 则找不到。
* **根因分析 (Root Cause)**：Helm 默认在渲染模板时使用 `{{ .Release.Name }}` 作为资源名称的一部分。由此造成真正的 Deployment 名称中包含了 Helm release 名。例如 [此 Issue](https://github.com/kubernetes-sigs/kustomize/issues/4897) 提到“chart 生成的资源都被前缀加上了 `RELEASE-NAME`”。因此，只用简单的资源名搜索会忽略这个前缀。
* **修复方法 (Fix / Resolution)**：查找实际部署的名称或在安装时指定合适的 `--name`/`--set nameOverride`。常用的做法是：

  * 使用 `helm list` 查看 release 名称，或 `helm status autoscaler` 查看资源清单。
  * 执行 `kubectl get deploy -n kube-system` 并观察实际名称前缀。
  * 如果需要可读性，可以在 `values.yaml` 中使用 `nameOverride` 或 `fullnameOverride` 来去除自动前缀，或者直接将 Helm release 名称设为所需的简易名称。
* **相关命令 (Commands Used)**：

  * 查看 Helm release：`helm list -n kube-system`。
  * 获取实际 Deployment 名称：`kubectl get deployment -n kube-system | grep autoscaler`。
  * Helm 安装示例：`helm install cluster-autoscaler k8s-cluster-autoscaler/cluster-autoscaler --namespace kube-system --version 9.10.7`，默认名称会是 `cluster-autoscaler-cluster-autoscaler`。
* **适用版本 (Version Info)**：Helm v3.x；Cluster Autoscaler Chart 最新版。

---

## Auto-Scaling 未触发/触发后未缩容（如冷却时间问题）

* **问题现象 (What Happened)**：集群没有按预期进行自动伸缩。例如：出现大量待调度 Pod 时却不扩容，或负载减轻后节点没有按时缩容，持续闲置资源浪费成本。
* **背景场景 (Context)**：Cluster Autoscaler 默认有多项延迟时间参数。默认情况下，对于 AWS 等集群，**新增后缩容的延迟时间**（scale-down-delay-after-add）为 10 分钟，**节点空闲后缩容前的等待时间**（scale-down-unneeded-time）也是 10 分钟。如果工作负载短平快完成，Autoscaler 可能认为节点仍在“冷却”，暂不缩容。
* **复现方式 (How to Reproduce)**：部署集群后先触发扩容（新增 Pod 需求），观察节点增加。随后删除这些 Pod，理论上应触发缩容；但若等待超过默认冷却时间（10 分钟）都不缩容，可推测延迟设置较长。
* **根因分析 (Root Cause)**：Cluster Autoscaler 默认的冷却时间使其不会立即缩容空闲节点。Azure 官方文档列出了默认参数：`scale-down-unneeded-time=10 分钟`，`scale-down-delay-after-add=10 分钟`，`scale-down-delay-after-failure=3 分钟`等。这意味着在节点被标记为可缩容前，需要满足这些等待条件。此外，如果节点上存在不可驱逐的 Pod（如 DaemonSet），也会阻止缩容。另外，扩容不触发可能是因为 Pod 未真正处于 Pending 状态（如资源请求或节点选择有问题），或者缺少所需的 AWS 伸缩组标签等授权问题。
* **修复方法 (Fix / Resolution)**：根据需要调整 Autoscaler 参数。常用做法：

  * **缩短冷却时间**：在 Cluster Autoscaler 部署中加入参数，如：

    ```
    --scale-down-unneeded-time=1m    # 节点闲置 1 分钟即候选缩容
    --scale-down-delay-after-add=5m   # 扩容后 5 分钟后才评估缩容
    ```

    这样可以更快缩容。也可以增加 `--scan-interval` 频率检查。注意短冷却可能导致过度伸缩，需要根据负载特性调整。
  * **检查最低节点数**：确保当前节点数未达到 Auto Scaling 组的 `min_size`，否则 Autoscaler 不会再缩容。
  * **检查 Pod 调度状态**：确认需要扩容的 Pod 是实际 Pending 而非因调度失败（未通过节点 taint 或亲和性等原因），以触发 Autoscaler 动作。
  * **查看日志定位问题**：`kubectl -n kube-system logs deploy/cluster-autoscaler` 中常能看到伸缩决策细节或为何不缩容的原因。
* **相关命令 (Commands Used)**：

  * 编辑 Cluster Autoscaler Deployment，添加或修改命令参数。
  * 查看当前参数：`kubectl -n kube-system describe deploy cluster-autoscaler`。
  * 日志查看：`kubectl -n kube-system logs deploy/cluster-autoscaler`。
* **适用版本 (Version Info)**：Cluster Autoscaler v1.19+，EKS + AWS Auto Scaling Group 环境。AWS 每秒计费场景下缩短冷却更有意义。

---

## NodeCreationFailure：实例未能加入集群（AL2023 nodeadm 变更）

* **问题现象 (What Happened)**：创建 Node Group 时提示 `NodeCreationFailure: Instances failed to join the kubernetes cluster`，节点日志 `/var/log/eks-bootstrap.log` 显示 `bootstrap.sh has been removed`。
* **背景场景 (Context)**：自定义启动模板的 `user_data` 仍调用 `/etc/eks/bootstrap.sh`，但在 AL2023 版本的 EKS AMI 中，该脚本已被 `nodeadm` 取代。
* **复现方式 (How to Reproduce)**：在 Launch Template 中保留旧版 bootstrap 脚本并选择 AL2023 EKS AMI，节点启动后即会失败。
* **根因分析 (Root Cause)**：AL2023 EKS AMI 不再提供 `bootstrap.sh`，导致脚本找不到文件而退出。
* **修复方法 (Fix / Resolution)**：删除自定义 `user_data`，或改用 `nodeadm` 配置方式；默认情况下，让 EKS 托管节点组自动生成 `user_data` 即可。
* **相关命令 (Commands Used)**：`journalctl -u nodeadm.service` 或查看 `/var/log/nodeadm.log` 了解初始化过程。
* **适用版本 (Version Info)**：EKS Optimized AL2023 AMI 及以上版本。

---

## NodeCreationFailure：CNI 插件未初始化导致节点无法加入集群

* **问题现象 (What Happened)**：Node Group 创建失败并出现健康检查告警：

  ```
  container runtime network not ready: NetworkReady=false reason:NetworkPluginNotReady message:Network plugin returns error: cni plugin not initialized
  ```

  实例启动后状态显示 `Create failed`，登录节点发现 `aws-node` DaemonSet 未部署，相关日志目录（如 `/var/log/aws-routed-eni/plugin.log`）为空。

* **背景场景 (Context)**：使用 Terraform 管理 EKS 集群，在重建 Node Group 时即便确认 IAM 权限、ENI 配额、SG 入站规则等均正确，仍然出现节点无法加入集群的情况。

* **复现方式 (How to Reproduce)**：

  1. 通过 Terraform 配置 Node Group，但未启用 `bootstrap_self_managed_addons`。
  2. 节点实例启动后，Node Group 状态为失败。
  3. 登录 EC2 实例，执行如下命令可以看到 CNI 配置缺失：

     ```bash
     sudo ls /etc/cni/net.d/            # 目录为空
     sudo ctr --namespace k8s.io containers list | grep aws-node  # 无输出
     ```

* **根因分析 (Root Cause)**：Terraform 默认不会为新建集群自动安装 VPC CNI 等核心插件。未显式设置 `bootstrap_self_managed_addons = true` 时，`aws-node` DaemonSet 不会部署到节点，导致 CNI 初始化失败。

* **修复方法 (Fix / Resolution)**：在 EKS Terraform 模块中加入：

  ```hcl
  bootstrap_self_managed_addons = true
  ```

  重新执行 `terraform apply` 后，Terraform 会自动安装默认的 EKS 托管 Addon（包括 VPC CNI），节点即可成功加入集群。

* **相关命令 (Commands Used)**：

  * 查看节点列表：

    ```bash
    kubectl get nodes
    ```

  * 检查 aws-node DaemonSet：

    ```bash
    kubectl -n kube-system get daemonset aws-node -o wide
    ```

  * 登录节点查看日志：

    ```bash
    sudo journalctl -u nodeadm
    sudo ls /var/log/aws-routed-eni/
    ```

* **适用版本 (Version Info)**：

  * Terraform AWS EKS 模块 ≥ v19.x
  * EKS Kubernetes 版本 ≥ v1.29
  * Amazon Linux 2023（AL2023）AMI

---
## 附录 (Appendix)

* **常用 AWS CLI 命令模板**：

  * 列出角色关联的策略：

    ```bash
    aws iam list-attached-role-policies --role-name MyRole --query "AttachedPolicies[].PolicyArn"
    ```
  * 查看 EKS 集群默认安全组：

    ```bash
    aws eks describe-cluster --name my-cluster --query "cluster.vpcConfig.clusterSecurityGroupId"
    ```
  * 获取 EKS OIDC Issuer：

    ```bash
    aws eks describe-cluster --name my-cluster --query "cluster.identity.oidc.issuer"
    ```
  * 检查当前登录身份：

    ```bash
    aws sts get-caller-identity --profile phase2-sso
    ```
  * 查看最新 ASG 名称：

    ```bash
    aws autoscaling describe-auto-scaling-groups --query 'AutoScalingGroups[].AutoScalingGroupName'
    ```
* **Terraform Import 格式示例**：

  * IAM Role Policy Attachment：

    ```bash
    terraform import aws_iam_role_policy_attachment.example ROLE_NAME/arn:aws:iam::123456789012:policy/POLICY_NAME
    ```

    如文档所述，ID 必须是 `role-name/policy-arn` 格式。
* **Cluster Autoscaler 默认参数**：根据文档，缩容相关默认值为 `scale-down-unneeded-time=10m`、`scale-down-delay-after-add=10m`。可根据应用场景调整缩容时间配置。

* **Cluster Autoscaler 常用检查命令 (Common Troubleshooting Commands)**：

  ```bash
  # 查看 Autoscaler Pod 是否启动
  kubectl --namespace=kube-system get pods -l "app.kubernetes.io/name=aws-cluster-autoscaler,app.kubernetes.io/instance=cluster-autoscaler"

  # 确认 Pod 使用的 ServiceAccount
  kubectl -n kube-system get pod -l app.kubernetes.io/name=aws-cluster-autoscaler -o jsonpath="{.items[0].spec.serviceAccountName}"
  kubectl -n kube-system get sa cluster-autoscaler -o yaml | grep role-arn
  kubectl -n kube-system get deploy cluster-autoscaler-aws-cluster-autoscaler -o jsonpath="{.spec.template.spec.serviceAccountName}{'\n'}"

  # 重新部署后删除旧 Pod 以加载新配置
  kubectl -n kube-system delete pod -l app.kubernetes.io/name=aws-cluster-autoscaler

  # 查看 Pod 是否就绪并检查日志
  kubectl -n kube-system get pod -l app.kubernetes.io/name=aws-cluster-autoscaler
  kubectl -n kube-system logs -l app.kubernetes.io/name=aws-cluster-autoscaler --tail=30
  kubectl -n kube-system rollout status deployment/cluster-autoscaler-aws-cluster-autoscaler
  kubectl -n kube-system logs -f deployment/cluster-autoscaler-aws-cluster-autoscaler | grep -i "autoscaler"
  ```

* **触发扩容 / 缩容示例 (Trigger Scale Up/Down Example)**：

  ```bash
  # 1) 创建一个持续占用 CPU 的 Deployment
  kubectl create deployment cpu-hog --image=busybox -- /bin/sh -c "while true; do :; done"

  # 2) 为该 Deployment 设置 CPU Request
  kubectl set resources deployment cpu-hog --requests=cpu=400m

  # 3) 扩大副本数以触发扩容
  kubectl scale deployment cpu-hog --replicas=20

  # 4) 观察节点与 Pod 调度情况
  kubectl get nodes -w
  kubectl get pods -l app=cpu-hog -w
  kubectl -n kube-system logs -l app.kubernetes.io/name=aws-cluster-autoscaler -f --tail=20

  # 5) 删除 Deployment 以观察缩容效果
  kubectl delete deployment cpu-hog
  ```

* 其他常用 kubectl 排查命令：

  ```bash
  kubectl get events --sort-by=.lastTimestamp
  kubectl get pod -A -owide
  ```

**参考资料：** 以上内容参考了 AWS 官方文档及社区经验，如 \[EKS IRSA 使用指南]、Terraform 官方文档、Kubernetes `kubectl` 文档、Cluster Autoscaler 参数说明等。
