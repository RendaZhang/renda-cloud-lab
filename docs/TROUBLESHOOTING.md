<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
## 目录 (Table of Contents)

- [集群故障排查指南](#%E9%9B%86%E7%BE%A4%E6%95%85%E9%9A%9C%E6%8E%92%E6%9F%A5%E6%8C%87%E5%8D%97)
  - [简介](#%E7%AE%80%E4%BB%8B)
    - [BUG 记录格式要求](#bug-%E8%AE%B0%E5%BD%95%E6%A0%BC%E5%BC%8F%E8%A6%81%E6%B1%82)
  - [BUG 详情](#bug-%E8%AF%A6%E6%83%85)
    - [Helm 部署 cluster-autoscaler 时 IRSA 注解配置错误导致 CrashLoopBackOff](#helm-%E9%83%A8%E7%BD%B2-cluster-autoscaler-%E6%97%B6-irsa-%E6%B3%A8%E8%A7%A3%E9%85%8D%E7%BD%AE%E9%94%99%E8%AF%AF%E5%AF%BC%E8%87%B4-crashloopbackoff)
    - [Helm 安装 cluster-autoscaler 报错：wrong type for value; expected string; got map[string]interface {}](#helm-%E5%AE%89%E8%A3%85-cluster-autoscaler-%E6%8A%A5%E9%94%99wrong-type-for-value-expected-string-got-mapstringinterface-)
    - [Terraform `aws.billing` alias 报 “No valid credential sources found”](#terraform-awsbilling-alias-%E6%8A%A5-no-valid-credential-sources-found)
    - [Terraform 导入 IAM Role Policy Attachment 使用短名失败（需使用完整 ARN）](#terraform-%E5%AF%BC%E5%85%A5-iam-role-policy-attachment-%E4%BD%BF%E7%94%A8%E7%9F%AD%E5%90%8D%E5%A4%B1%E8%B4%A5%E9%9C%80%E4%BD%BF%E7%94%A8%E5%AE%8C%E6%95%B4-arn)
    - [OIDC Provider 的 URL 固定写死导致重建失败隐患](#oidc-provider-%E7%9A%84-url-%E5%9B%BA%E5%AE%9A%E5%86%99%E6%AD%BB%E5%AF%BC%E8%87%B4%E9%87%8D%E5%BB%BA%E5%A4%B1%E8%B4%A5%E9%9A%90%E6%82%A3)
    - [创建 Deployment 失败 – 错误地将 `--requests=cpu=400m` 写在 `kubectl create` 命令中](#%E5%88%9B%E5%BB%BA-deployment-%E5%A4%B1%E8%B4%A5--%E9%94%99%E8%AF%AF%E5%9C%B0%E5%B0%86---requestscpu400m-%E5%86%99%E5%9C%A8-kubectl-create-%E5%91%BD%E4%BB%A4%E4%B8%AD)
    - [无法找到 Deployment 名称（Helm 安装时名称自动拼接）](#%E6%97%A0%E6%B3%95%E6%89%BE%E5%88%B0-deployment-%E5%90%8D%E7%A7%B0helm-%E5%AE%89%E8%A3%85%E6%97%B6%E5%90%8D%E7%A7%B0%E8%87%AA%E5%8A%A8%E6%8B%BC%E6%8E%A5)
    - [Auto-Scaling 未触发/触发后未缩容（如冷却时间问题）](#auto-scaling-%E6%9C%AA%E8%A7%A6%E5%8F%91%E8%A7%A6%E5%8F%91%E5%90%8E%E6%9C%AA%E7%BC%A9%E5%AE%B9%E5%A6%82%E5%86%B7%E5%8D%B4%E6%97%B6%E9%97%B4%E9%97%AE%E9%A2%98)
    - [NodeCreationFailure：实例未能加入集群（AL2023 nodeadm 变更）](#nodecreationfailure%E5%AE%9E%E4%BE%8B%E6%9C%AA%E8%83%BD%E5%8A%A0%E5%85%A5%E9%9B%86%E7%BE%A4al2023-nodeadm-%E5%8F%98%E6%9B%B4)
    - [NodeCreationFailure：CNI 插件未初始化导致节点无法加入集群](#nodecreationfailurecni-%E6%8F%92%E4%BB%B6%E6%9C%AA%E5%88%9D%E5%A7%8B%E5%8C%96%E5%AF%BC%E8%87%B4%E8%8A%82%E7%82%B9%E6%97%A0%E6%B3%95%E5%8A%A0%E5%85%A5%E9%9B%86%E7%BE%A4)
  - [附录](#%E9%99%84%E5%BD%95)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# 集群故障排查指南

- **Last Updated:** July 18, 2025, 20:10 (UTC+8)
- **作者:** 张人大（Renda Zhang）

--

## 简介

本文档汇总了 **renda-cloud-lab** 项目在集群搭建与运维过程中常见的问题和解决方案，。

每个问题包括：问题现象、背景场景、复现方式、根因分析、修复方法、相关命令和适用版本等条目，以便快速定位和解决类似故障。

### BUG 记录格式要求

统一的记录格式便于后续检索和统计，推荐模版如下：

```markdown
### BUG-<编号>: <标题>

- **问题状态**：新建 (New) | 已确认 (Confirmed) | 进行中 (In Progress) | 已解决 (Resolved) | 已验证 (Verified) | 重新打开 (Reopened) | 已关闭 (Closed) | 已拒绝 (Rejected) | 已延期 (Deferred) | 已阻塞 (Blocked) | 已取消 (Cancelled)
- **发现日期**：YYYY-MM-DD
- **问题现象**：
- **背景场景**：
- **复现方式**：
- **根因分析**：
- **修复方法**：
- **相关命令**：
- **适用版本**：
- **经验总结**：可选的额外说明
```

---

## BUG 详情

### Helm 部署 cluster-autoscaler 时 IRSA 注解配置错误导致 CrashLoopBackOff

- **问题状态**：已关闭 (Closed)
- **发现日期**：2025-06-29
- **问题现象**：
  - 使用 Helm 安装 Cluster Autoscaler 后，Pod 不断重启（CrashLoopBackOff），日志提示没有权限访问 AWS API，
  - 例如缺少 `autoscaling:DescribeAutoScalingGroups` 等权限。
- **背景场景**：
  - 在 EKS 集群上通过 Helm Chart 部署 Cluster Autoscaler，并尝试使用 IRSA (IAM Roles for Service Accounts) 方式绑定 IAM 角色。
  - 如果服务账户的注解配置错误（如注解 Key 或值不正确），则 Pod 无法获取到 IAM 角色。
- **复现方式**：
  - 执行如 `helm install ca autoscaler/cluster-autoscaler --namespace kube-system --set awsRegion=... --set rbac.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=""`（错误地省略或写错角色 ARN），
  - 然后查看 Pod 状态 `kubectl get pods -n kube-system | grep autoscaler`，发现 `CrashLoopBackOff`。
- **根因分析**：
  - Cluster Autoscaler Pod 缺乏必要的 AWS 权限。
  - 具体地，IRSA 需要将 Kubernetes 服务账户注解为对应的 IAM 角色。
  - 官方要求使用如 `eks.amazonaws.com/role-arn=arn:aws:iam::ACCOUNT_ID:role/RoleName` 的格式。
  - 如果注解漏写、拼写错误或使用了错误的 IAM ARN，Pod 就不会获得对应角色权限，导致调用 AWS API 权限被拒绝而重启。
- **修复方法**：
  - 检查并修正服务账户注解。确保在 Helm 参数或 Kubernetes manifest 中，使用正确的注解键 `eks.amazonaws.com/role-arn`，并指定完整的 IAM 角色 ARN。
  - 例如：
    ```bash
    kubectl annotate serviceaccount -n kube-system cluster-autoscaler eks.amazonaws.com/role-arn=arn:aws:iam::111122223333:role/ClusterAutoscalerRole
    ```
  - 或在 Helm 安装命令中通过 `--set rbac.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::111122223333:role/ClusterAutoscalerRole"` 指定。
  - 之后重启 Autoscaler Pod 使其重新获取 IAM 角色。
  - 还需确认 IAM 角色已附加包含 `autoscaling:Describe*`、`ec2:Describe*` 等权限的策略。
- **相关命令**：
  - 查看 Pod 日志：`kubectl -n kube-system logs deploy/cluster-autoscaler`。
  - 查看服务账户注解：`kubectl -n kube-system describe sa cluster-autoscaler`。
  - 添加注解：见上文 `kubectl annotate` 命令。
- **适用版本**：
  - EKS 版本 ≥1.18，Cluster Autoscaler Chart v9.x（具体版本根据使用情况）。

### Helm 安装 cluster-autoscaler 报错：wrong type for value; expected string; got map[string]interface {}

- **问题状态**：已关闭 (Closed)
- **发现日期**：2025-06-29
- **问题现象**：
  - 执行 Helm 安装命令时，模板渲染失败并报错：
    ```
    Error: template: cluster-autoscaler/templates/serviceaccount.yaml:13:40: executing "cluster-autoscaler/templates/serviceaccount.yaml" at <$v>: wrong type for value; expected string; got map[string]interface {}
    ```
- **背景场景**：
  - 使用 `--set` 传入 `eks.amazonaws.com/role-arn` 等包含 `.` 的键名时，Helm 会将点号解释为嵌套路径，导致注解被解析成 map。
- **复现方式**：
  - 示例命令：
    ```bash
    helm install ca autoscaler/cluster-autoscaler \
      --namespace kube-system \
      --set rbac.serviceAccount.annotations.eks.amazonaws.com/role-arn=arn:aws:iam::111122223333:role/ClusterAutoscalerRole
    ```
  - 上述命令会触发 `wrong type for value` 的错误。
- **根因分析**：
  - 未转义的点号使 Helm 将该键拆分为多级 map，而模板期望的是字符串键，导致类型不匹配。
- **修复方法**：
  - 在 `--set` 中对点号使用 `\\.` 转义，例如：
    ```bash
    --set rbac.serviceAccount.annotations."eks\\.amazonaws\\.com/role-arn"="arn:aws:iam::111122223333:role/ClusterAutoscalerRole"
    ````
  或者改用 `--values values.yaml` 明确传入 YAML 结构。
- **补充建议**：
  - 带有 IRSA 的 EKS 部署经常需要配置此注解，推荐统一使用转义或单引号 `--set 'key.with\\.dots=value'` 的形式，避免 shell 或 Helm 解析问题。
- **适用版本**：
  - Helm v3.x，Cluster Autoscaler Chart v9.x 及以上。

### Terraform `aws.billing` alias 报 “No valid credential sources found”

- **问题状态**：已关闭 (Closed)
- **发现日期**：2025-07-04
- **问题现象**：
  - 运行 `terraform plan` / `make stop-hard` 等命令时，初始化 `provider["registry.terraform.io/hashicorp/aws"].billing` 阶段失败。
  - 终端输出：
    ```bash
    Error: No valid credential sources found
    │
    │ Error: failed to refresh cached credentials, no EC2 IMDS role found, operation error ec2imds: GetMetadata, request canceled, context deadline exceeded
    ```
- **背景场景**：
  - 在 `budgets.tf` 中为 **AWS Budgets** 声明了专用 `alias`：
    ```hcl
    provider "aws" {
      alias  = "billing"
      region = "us-east-1"
    }
    ```
  - 本地通过 **AWS SSO** 登录 (`phase2-sso` profile)。
  - 如果当前 Shell 未 export `AWS_PROFILE`，或 SSO token 过期，Terraform 初始化 `alias` 时将走完整的 AWS SDK credential chain，最终回落至 **IMDS** 而失败。
- **根因分析**：
  - `alias` provider 与默认 provider 是两条独立的 credential chain。
  - 当 Shell 未暴露任何凭证，且不在 EC2 环境时，SDK 报 `no EC2 IMDS role found`，从而触发 `No valid credential sources found`。
- **修复方法**
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
- **相关命令**：
  ```bash
  aws sts get-caller-identity --profile phase2-sso
  terraform providers
  terraform plan -var="create_budget=false"
  ```
- **适用版本**：
  - Terraform ≥ 1.6
  - AWS Provider ≥ 5.x
  - AWS CLI v2 + SSO

### Terraform 导入 IAM Role Policy Attachment 使用短名失败（需使用完整 ARN）

- **问题状态**：已关闭 (Closed)
- **发现日期**：2025-07-04
- **问题现象**：
  - 执行 `terraform import aws_iam_role_policy_attachment.xxx ROLE_NAME/POLICY_NAME` 报错：
    - 提示 `unexpected format of ID ... expected <role-name>/<policy_arn>`，
    - 或者提示 `ValidationError: The specified value for roleName is invalid`。
- **背景场景**：
  - Terraform 管理 IAM 资源时，需要把现有的 IAM Policy Attachment 导入到 state。
  - 根据 Terraform 文档，`aws_iam_role_policy_attachment` 的 import ID 必须是 `role_name/policy_arn` 格式。如果误用短名或只用 ARN，导入会失败。
- **复现方式**：
  - 已有角色 `MyRole`，策略 ARN `arn:aws:iam::123456789012:policy/MyPolicy` 已附加在该角色上。
  - 尝试 `terraform import aws_iam_role_policy_attachment.my-attach MyRole/MyPolicy`，Terraform 会报 ID 格式错误；
  - 尝试只用 `MyRole` 或只用 ARN 导入，均报错。
- **根因分析**：
  - Terraform 要求 `aws_iam_role_policy_attachment` 的 ID 由角色名和策略 ARN 通过斜杠 `/` 连接构成。
  - 使用短名（如只写 `policy/MyPolicy`）或只写角色名都会被视为格式不对导致失败。
  - 正如官方文档所述：*“the ID is the combination of the role name and policy ARN, so you would use `role-name/arn:aws:iam::...:policy/policy-name` as the ID.”*。
- **修复方法**：
  - 在 Terraform 导入时使用完整格式。
  - 示例：
    ```bash
    terraform import aws_iam_role_policy_attachment.my_attach MyRole/arn:aws:iam::123456789012:policy/MyPolicy
    ```
  - 注意替换 `MyRole` 和策略 ARN 为实际值。这样 Terraform 就能正确识别并导入该资源。
- **相关命令**：
  - 导入命令示例：`terraform import aws_iam_role_policy_attachment.my_attach MyRole/arn:aws:iam::123456789012:policy/MyPolicy`。
  - 导入成功后，可用 `terraform state show aws_iam_role_policy_attachment.my_attach` 查看详细信息。
- **适用版本**：
  - Terraform AWS Provider v2.x 及以上，Terraform v0.12+。

### OIDC Provider 的 URL 固定写死导致重建失败隐患

- **问题状态**：已关闭 (Closed)
- **发现日期**：2025-07-04
- **问题现象**：
  - 多次拆建 EKS 集群过程中，Terraform 计划（`terraform plan`）提示 OIDC Provider 需要替换或删除。
  - 例如，集群销毁后重建时出现错误，提示已有同名 OIDC Provider 无法创建，或是 OIDC Provider URL 与集群不匹配。
- **背景场景**：
  - EKS 集群创建时，会生成一个对应的 IAM OIDC Provider，用于 IRSA 身份验证。
  - 如果在 Terraform 配置中硬编码了 OIDC 提供商的 URL（比如复制粘贴 `oidc.eks.<region>.amazonaws.com/id/<cluster-id>`），则当集群重建时，新的 OIDC Issuer URL 与旧的不同，导致 Terraform 认定资源变更。
- **复现方式**：
  - 在 Terraform 配置里直接填入某次集群的 OIDC URL，如：
  ```hcl
  resource "aws_iam_openid_connect_provider" "oidc" {
    url             = "oidc.eks.us-west-2.amazonaws.com/id/XXXXXXXXXXXXXX"
    client_id_list  = ["sts.amazonaws.com"]
    thumbprint_list = [ ... ]
  }
  ```
  第一次创建后正常；销毁集群并再次运行 Terraform 时，新的 EKS 集群会有不同的 OIDC Issuer，导致 `terraform plan` 发现 URL 改变或资源冲突。
- **根因分析**：
  - 硬编码 OIDC URL 缺乏灵活性。
  - 正确做法是动态获取当前集群的 OIDC Issuer。
  - 比如在 Terraform 模块中可以使用 `aws_eks_cluster.this[0].identity[0].oidc[0].issuer` 作为数据源，通过 `replace(..., "https://", "")` 取出不带前缀的提供商 URL。
  - 在样例代码中：
    ```hcl
    url = replace(
      try(aws_eks_cluster.this[0].identity[0].oidc[0].issuer, ""),
      "https://", ""
    )
    ```
  这样每次都从 EKS 集群中获取当前的 OIDC URL，避免固定死旧值导致资源不匹配。
- **修复方法**：
  - 修改 Terraform 配置，不手动填写 OIDC URL，而是引用 EKS 集群的属性。
  - 如上文所示，使用 `aws_eks_cluster.cluster.identity[0].oidc[0].issuer`（去掉 `https://`）动态赋值给 `aws_iam_openid_connect_provider.url`。
  - 或者使用 `eksctl get cluster -o json` 等命令实时获取集群身份提供商 URL。
  - 总之，保持 OIDC Provider 的 URL 与当前集群保持一致即可避免重建时出错。
- **相关命令**：
  - 查看集群 OIDC URL：`aws eks describe-cluster --name my-cluster --query "cluster.identity.oidc.issuer" --output text`。
  - Terraform 计划命令：`terraform plan` 查看修改结果，确保 OIDC URL 通过动态引用得来。
  - Terraform 导入（如需要）：`terraform import aws_iam_openid_connect_provider.oidc <provider_arn>` 将现有 OIDC Provider 纳入管理。
- **适用版本**：
  - Terraform AWS Provider v3.x 以上，EKS 及 eksctl 版本无特殊要求。

### 创建 Deployment 失败 – 错误地将 `--requests=cpu=400m` 写在 `kubectl create` 命令中

- **问题状态**：已关闭 (Closed)
- **发现日期**：2025-07-04
- **问题现象**：
  - 执行类似 `kubectl create deployment mydep --image=nginx --requests=cpu=400m` 命令时，出现报错提示未知标志，Deployment 未创建成功。
- **背景场景**：
  - 用户想快速创建一个 Deployment 并设置资源请求，在 `kubectl create deployment` 命令中加入了 `--requests` 参数。
  - 实际上，`kubectl create deployment` 支持的选项只有镜像、端口、副本数等常规字段，并不包含 `--requests`。
- **复现方式**：
  - 在任意 Kubernetes 集群，执行：
    ```bash
    kubectl create deployment test-dep --image=nginx --requests=cpu=400m
    ```
  - 结果会报错：`Error: unknown flag: --requests` 或忽略该参数并不设置资源。
- **根因分析**：
  - `kubectl create deployment` 子命令不支持 `--requests` 参数。
  - 其文档列出的有效标志包括 `--image`, `--port`, `--replicas` 等，并未提及资源请求相关标志。
  - `--requests` 是 `kubectl run` 的一个选项，而不是 `create deployment` 的。
  - 在不被识别的情况下，命令执行失败或忽略了资源请求配置。
- **修复方法**：
  - 应使用正确的命令或方式来设置资源请求。
  - 解决方案包括：
    - **使用 `kubectl run`**：`kubectl run test-dep --image=nginx --requests=cpu=400m` 支持 `--requests` 参数。
    - **使用 YAML 定义**：编写 Deployment YAML，在容器规格中添加 `resources.requests` 字段，然后 `kubectl apply -f`。
    - 例如：
       ```yaml
       spec:
         containers:
         - name: nginx
           image: nginx
           resources:
             requests:
               cpu: "400m"
       ```
    - **先创建后编辑**：
       - 先 `kubectl create deployment test-dep --image=nginx`，
       - 再用 `kubectl set resources deployment test-dep --requests=cpu=400m`
       - 或编辑 Deployment 进行修改。
- **相关命令**：
  - 查看 `kubectl create deployment` 文档：[kubernetes 官方参考](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_deployment/) 列举的可用标志。
  - 正确创建示例：`kubectl create deployment mydep --image=nginx --port=80 --replicas=2`。
  - 设置资源命令：`kubectl set resources deployment mydep --requests=cpu=400m`。
- **适用版本**：
  - kubectl v1.18+，Kubernetes 集群 v1.18+。

### 无法找到 Deployment 名称（Helm 安装时名称自动拼接）

- **问题状态**：已关闭 (Closed)
- **发现日期**：2025-07-04
- **问题现象**：
  - 按照期望，集群里应该有名为 `cluster-autoscaler` 的 Deployment，但执行 `kubectl get deployment` 没有找到对应名字的资源。
  - 怀疑部署失败或丢失，但实际 Helm release 正常。
- **背景场景**：
  - 使用 Helm 部署资源时，Helm 默认会将 release 名称作为前缀自动添加到 Kubernetes 资源名中。
  - 这是 Helm 的设计：所有生成的资源名通常以 `RELEASE-NAME-` 开头。
  - 如果部署时 Helm release 名称不是 `cluster-autoscaler`，则资源名不会是单纯的 `cluster-autoscaler`。
- **复现方式**：
  - 假设使用命令 `helm install autoscaler k8s-cluster-autoscaler/cluster-autoscaler` 将 Chart 安装为 release 名称 `autoscaler`，那么其生成的 Deployment 实际名为 `autoscaler-cluster-autoscaler`。
  - 执行 `kubectl get deployments` 可以看到以 `autoscaler-` 前缀开头的 Deployment，而单纯查 `kubectl get deploy cluster-autoscaler` 则找不到。
- **根因分析**：
  - Helm 默认在渲染模板时使用 `{{ .Release.Name }}` 作为资源名称的一部分。
  - 由此造成真正的 Deployment 名称中包含了 Helm release 名。
  - 例如 [kustomize issues 4897](https://github.com/kubernetes-sigs/kustomize/issues/4897) 提到 “chart 生成的资源都被前缀加上了 `RELEASE-NAME`”。因此，只用简单的资源名搜索会忽略这个前缀。
- **修复方法**：查找实际部署的名称或在安装时指定合适的 `--name`/`--set nameOverride`。常用的做法是：
  - 使用 `helm list` 查看 release 名称，或 `helm status autoscaler` 查看资源清单。
  - 执行 `kubectl get deploy -n kube-system` 并观察实际名称前缀。
  - 如果需要可读性，可以在 `values.yaml` 中使用 `nameOverride` 或 `fullnameOverride` 来去除自动前缀，或者直接将 Helm release 名称设为所需的简易名称。
- **相关命令**：
  - 查看 Helm release：`helm list -n kube-system`。
  - 获取实际 Deployment 名称：`kubectl get deployment -n kube-system | grep autoscaler`。
  - Helm 安装示例：`helm install cluster-autoscaler k8s-cluster-autoscaler/cluster-autoscaler --namespace kube-system --version 9.10.7`，默认名称会是 `cluster-autoscaler-cluster-autoscaler`。
- **适用版本**：Helm v3.x；Cluster Autoscaler Chart 最新版。

### Auto-Scaling 未触发/触发后未缩容（如冷却时间问题）

- **问题状态**：已关闭 (Closed)
- **发现日期**：2025-07-05
- **问题现象**：
  - 集群没有按预期进行自动伸缩。
  - 例如：出现大量待调度 Pod 时却不扩容，或负载减轻后节点没有按时缩容，持续闲置资源浪费成本。
- **背景场景**：
  - Cluster Autoscaler 默认有多项延迟时间参数。
  - 默认情况下，对于 AWS 等集群，**新增后缩容的延迟时间**（scale-down-delay-after-add）为 10 分钟，**节点空闲后缩容前的等待时间**（scale-down-unneeded-time）也是 10 分钟。
  - 如果工作负载短平快完成，Autoscaler 可能认为节点仍在“冷却”，暂不缩容。
- **复现方式**：部署集群后先触发扩容（新增 Pod 需求），观察节点增加。随后删除这些 Pod，理论上应触发缩容；但若等待超过默认冷却时间（10 分钟）都不缩容，可推测延迟设置较长。
- **根因分析**：
  - Cluster Autoscaler 默认的冷却时间使其不会立即缩容空闲节点。
  - Azure 官方文档列出了默认参数：`scale-down-unneeded-time=10 分钟`，`scale-down-delay-after-add=10 分钟`，`scale-down-delay-after-failure=3 分钟`等。
  - 这意味着在节点被标记为可缩容前，需要满足这些等待条件。
  - 此外，如果节点上存在不可驱逐的 Pod（如 DaemonSet），也会阻止缩容。
  - 另外，扩容不触发可能是因为 Pod 未真正处于 Pending 状态（如资源请求或节点选择有问题），或者缺少所需的 AWS 伸缩组标签等授权问题。
- **修复方法**：根据需要调整 Autoscaler 参数。常用做法：
  - **缩短冷却时间**：
    - 在 Cluster Autoscaler 部署中加入参数，如：
    ```
    --scale-down-unneeded-time=1m    # 节点闲置 1 分钟即候选缩容
    --scale-down-delay-after-add=5m   # 扩容后 5 分钟后才评估缩容
    ```
    - 这样可以更快缩容。
    - 也可以增加 `--scan-interval` 频率检查。
    - 注意短冷却可能导致过度伸缩，需要根据负载特性调整。
  - **检查最低节点数**：确保当前节点数未达到 Auto Scaling 组的 `min_size`，否则 Autoscaler 不会再缩容。
  - **检查 Pod 调度状态**：确认需要扩容的 Pod 是实际 Pending 而非因调度失败（未通过节点 taint 或亲和性等原因），以触发 Autoscaler 动作。
  - **查看日志定位问题**：`kubectl -n kube-system logs deploy/cluster-autoscaler` 中常能看到伸缩决策细节或为何不缩容的原因。
- **相关命令**：
  - 编辑 Cluster Autoscaler Deployment，添加或修改命令参数。
  - 查看当前参数：`kubectl -n kube-system describe deploy cluster-autoscaler`。
  - 日志查看：`kubectl -n kube-system logs deploy/cluster-autoscaler`。
- **适用版本**：
  - Cluster Autoscaler v1.19+，EKS + AWS Auto Scaling Group 环境。
  - AWS 每秒计费场景下缩短冷却更有意义。

### NodeCreationFailure：实例未能加入集群（AL2023 nodeadm 变更）

- **问题状态**：已关闭 (Closed)
- **发现日期**：2025-07-05
- **问题现象**：
  - 创建 Node Group 时提示 `NodeCreationFailure: Instances failed to join the kubernetes cluster`，节点日志 `/var/log/eks-bootstrap.log` 显示 `bootstrap.sh has been removed`。
- **背景场景**：
  - 自定义启动模板的 `user_data` 仍调用 `/etc/eks/bootstrap.sh`，但在 AL2023 版本的 EKS AMI 中，该脚本已被 `nodeadm` 取代。
- **复现方式**：
  - 在 Launch Template 中保留旧版 bootstrap 脚本并选择 AL2023 EKS AMI，节点启动后即会失败。
- **根因分析**：
  - AL2023 EKS AMI 不再提供 `bootstrap.sh`，导致脚本找不到文件而退出。
- **修复方法**：
  - 删除自定义 `user_data`，或改用 `nodeadm` 配置方式；默认情况下，让 EKS 托管节点组自动生成 `user_data` 即可。
- **相关命令**：
  - `journalctl -u nodeadm.service` 或查看 `/var/log/nodeadm.log` 了解初始化过程。
- **适用版本**：
  - EKS Optimized AL2023 AMI 及以上版本。

### NodeCreationFailure：CNI 插件未初始化导致节点无法加入集群

- **问题状态**：已关闭 (Closed)
- **发现日期**：2025-07-05
- **问题现象**：
  - Node Group 创建失败并出现健康检查告警：
    ```
    container runtime network not ready: NetworkReady=false reason:NetworkPluginNotReady message:Network plugin returns error: cni plugin not initialized
    ```
  - 实例启动后状态显示 `Create failed`，登录节点发现 `aws-node` DaemonSet 未部署，相关日志目录（如 `/var/log/aws-routed-eni/plugin.log`）为空。
- **背景场景**：
  - 使用 Terraform 管理 EKS 集群，在重建 Node Group 时即便确认 IAM 权限、ENI 配额、SG 入站规则等均正确，仍然出现节点无法加入集群的情况。
- **复现方式**：
  1. 通过 Terraform 配置 Node Group，但未启用 `bootstrap_self_managed_addons`。
  2. 节点实例启动后，Node Group 状态为失败。
  3. 登录 EC2 实例，执行如下命令可以看到 CNI 配置缺失：
     ```bash
     sudo ls /etc/cni/net.d/            # 目录为空
     sudo ctr --namespace k8s.io containers list | grep aws-node  # 无输出
     ```
- **根因分析**：
  - Terraform 默认不会为新建集群自动安装 VPC CNI 等核心插件。
  - 未显式设置 `bootstrap_self_managed_addons = true` 时，`aws-node` DaemonSet 不会部署到节点，导致 CNI 初始化失败。
- **修复方法**：
  - 在 EKS Terraform 模块中加入：
    ```hcl
    bootstrap_self_managed_addons = true
    ```
  - 重新执行 `terraform apply` 后，Terraform 会自动安装默认的 EKS 托管 Addon（包括 VPC CNI），节点即可成功加入集群。
- **相关命令**：
  - 查看节点列表：
    ```bash
    kubectl get nodes
    ```
  - 检查 aws-node DaemonSet：
    ```bash
    kubectl -n kube-system get daemonset aws-node -o wide
    ```
  - 登录节点查看日志：
    ```bash
    sudo journalctl -u nodeadm
    sudo ls /var/log/aws-routed-eni/
    ```
- **适用版本**：
  - Terraform AWS EKS 模块 ≥ v19.x
  - EKS Kubernetes 版本 ≥ v1.29
  - Amazon Linux 2023（AL2023）AMI

---

## 附录

- **常用 AWS CLI 命令模板**：
  - 列出角色关联的策略：
    ```bash
    aws iam list-attached-role-policies --role-name MyRole --query "AttachedPolicies[].PolicyArn"
    ```
  - 查看 EKS 集群默认安全组：
    ```bash
    aws eks describe-cluster --name my-cluster --query "cluster.vpcConfig.clusterSecurityGroupId"
    ```
  - 获取 EKS OIDC Issuer：
    ```bash
    aws eks describe-cluster --name my-cluster --query "cluster.identity.oidc.issuer"
    ```
  - 检查当前登录身份：
    ```bash
    aws sts get-caller-identity --profile phase2-sso
    ```
  - 查看最新 ASG 名称：
    ```bash
    aws autoscaling describe-auto-scaling-groups --query 'AutoScalingGroups[].AutoScalingGroupName'
    ```
- **Terraform Import 格式示例**：
  - IAM Role Policy Attachment：
    ```bash
    terraform import aws_iam_role_policy_attachment.example ROLE_NAME/arn:aws:iam::123456789012:policy/POLICY_NAME
    ```
  - 如文档所述，ID 必须是 `role-name/policy-arn` 格式。
- **Cluster Autoscaler 默认参数**：根据文档，缩容相关默认值为 `scale-down-unneeded-time=10m`、`scale-down-delay-after-add=10m`。可根据应用场景调整缩容时间配置。
- **Cluster Autoscaler 常用检查命令**：
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
- **触发扩容 / 缩容示例**：
  ```bash
  # 1. 创建一个持续占用 CPU 的 Deployment
  kubectl create deployment cpu-hog --image=busybox -- /bin/sh -c "while true; do :; done"

  # 2. 为该 Deployment 设置 CPU Request
  kubectl set resources deployment cpu-hog --requests=cpu=400m

  # 3. 扩大副本数以触发扩容
  kubectl scale deployment cpu-hog --replicas=20

  # 4. 观察节点与 Pod 调度情况
  kubectl get nodes -w
  kubectl get pods -l app=cpu-hog -w
  kubectl -n kube-system logs -l app.kubernetes.io/name=aws-cluster-autoscaler -f --tail=20

  # 5. 删除 Deployment 以观察缩容效果
  kubectl delete deployment cpu-hog
  ```
- 其他常用 kubectl 排查命令：
  ```bash
  kubectl get events --sort-by=.lastTimestamp
  kubectl get pod -A -owide
  ```
