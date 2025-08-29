<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
## 目录 (Table of Contents)

- [集群故障排查指南](#%E9%9B%86%E7%BE%A4%E6%95%85%E9%9A%9C%E6%8E%92%E6%9F%A5%E6%8C%87%E5%8D%97)
  - [简介](#%E7%AE%80%E4%BB%8B)
    - [BUG 记录格式要求](#bug-%E8%AE%B0%E5%BD%95%E6%A0%BC%E5%BC%8F%E8%A6%81%E6%B1%82)
    - [常见坑与退路](#%E5%B8%B8%E8%A7%81%E5%9D%91%E4%B8%8E%E9%80%80%E8%B7%AF)
  - [BUG 详情](#bug-%E8%AF%A6%E6%83%85)
    - [BUG-001: Helm 部署 cluster-autoscaler 时 IRSA 注解配置错误导致 CrashLoopBackOff](#bug-001-helm-%E9%83%A8%E7%BD%B2-cluster-autoscaler-%E6%97%B6-irsa-%E6%B3%A8%E8%A7%A3%E9%85%8D%E7%BD%AE%E9%94%99%E8%AF%AF%E5%AF%BC%E8%87%B4-crashloopbackoff)
    - [BUG-002: Helm 安装 cluster-autoscaler 报错：wrong type for value; expected string; got map[string]interface {}](#bug-002-helm-%E5%AE%89%E8%A3%85-cluster-autoscaler-%E6%8A%A5%E9%94%99wrong-type-for-value-expected-string-got-mapstringinterface-)
    - [BUG-003: Terraform `aws.billing` alias 报 “No valid credential sources found”](#bug-003-terraform-awsbilling-alias-%E6%8A%A5-no-valid-credential-sources-found)
    - [BUG-004: Terraform 导入 IAM Role Policy Attachment 使用短名失败（需使用完整 ARN）](#bug-004-terraform-%E5%AF%BC%E5%85%A5-iam-role-policy-attachment-%E4%BD%BF%E7%94%A8%E7%9F%AD%E5%90%8D%E5%A4%B1%E8%B4%A5%E9%9C%80%E4%BD%BF%E7%94%A8%E5%AE%8C%E6%95%B4-arn)
    - [BUG-005: OIDC Provider 的 URL 固定写死导致重建失败隐患](#bug-005-oidc-provider-%E7%9A%84-url-%E5%9B%BA%E5%AE%9A%E5%86%99%E6%AD%BB%E5%AF%BC%E8%87%B4%E9%87%8D%E5%BB%BA%E5%A4%B1%E8%B4%A5%E9%9A%90%E6%82%A3)
    - [BUG-006: 创建 Deployment 失败 – 错误地将 `--requests=cpu=400m` 写在 `kubectl create` 命令中](#bug-006-%E5%88%9B%E5%BB%BA-deployment-%E5%A4%B1%E8%B4%A5--%E9%94%99%E8%AF%AF%E5%9C%B0%E5%B0%86---requestscpu400m-%E5%86%99%E5%9C%A8-kubectl-create-%E5%91%BD%E4%BB%A4%E4%B8%AD)
    - [BUG-007: 无法找到 Deployment 名称（Helm 安装时名称自动拼接）](#bug-007-%E6%97%A0%E6%B3%95%E6%89%BE%E5%88%B0-deployment-%E5%90%8D%E7%A7%B0helm-%E5%AE%89%E8%A3%85%E6%97%B6%E5%90%8D%E7%A7%B0%E8%87%AA%E5%8A%A8%E6%8B%BC%E6%8E%A5)
    - [BUG-008: Auto-Scaling 未触发/触发后未缩容（如冷却时间问题）](#bug-008-auto-scaling-%E6%9C%AA%E8%A7%A6%E5%8F%91%E8%A7%A6%E5%8F%91%E5%90%8E%E6%9C%AA%E7%BC%A9%E5%AE%B9%E5%A6%82%E5%86%B7%E5%8D%B4%E6%97%B6%E9%97%B4%E9%97%AE%E9%A2%98)
    - [BUG-009: NodeCreationFailure：实例未能加入集群（AL2023 nodeadm 变更）](#bug-009-nodecreationfailure%E5%AE%9E%E4%BE%8B%E6%9C%AA%E8%83%BD%E5%8A%A0%E5%85%A5%E9%9B%86%E7%BE%A4al2023-nodeadm-%E5%8F%98%E6%9B%B4)
    - [BUG-010: NodeCreationFailure：CNI 插件未初始化导致节点无法加入集群](#bug-010-nodecreationfailurecni-%E6%8F%92%E4%BB%B6%E6%9C%AA%E5%88%9D%E5%A7%8B%E5%8C%96%E5%AF%BC%E8%87%B4%E8%8A%82%E7%82%B9%E6%97%A0%E6%B3%95%E5%8A%A0%E5%85%A5%E9%9B%86%E7%BE%A4)
    - [BUG-011: Terraform 初始化时因缓存问题导致 Registry 连接失败](#bug-011-terraform-%E5%88%9D%E5%A7%8B%E5%8C%96%E6%97%B6%E5%9B%A0%E7%BC%93%E5%AD%98%E9%97%AE%E9%A2%98%E5%AF%BC%E8%87%B4-registry-%E8%BF%9E%E6%8E%A5%E5%A4%B1%E8%B4%A5)
    - [BUG-012: Ingress 无法自动创建 ALB – 子网缺少 AWS Load Balancer Controller 所需标签](#bug-012-ingress-%E6%97%A0%E6%B3%95%E8%87%AA%E5%8A%A8%E5%88%9B%E5%BB%BA-alb--%E5%AD%90%E7%BD%91%E7%BC%BA%E5%B0%91-aws-load-balancer-controller-%E6%89%80%E9%9C%80%E6%A0%87%E7%AD%BE)
    - [BUG-013: Terraform 创建 AWS Load Balancer Controller ServiceAccount 时 TLS 握手超时](#bug-013-terraform-%E5%88%9B%E5%BB%BA-aws-load-balancer-controller-serviceaccount-%E6%97%B6-tls-%E6%8F%A1%E6%89%8B%E8%B6%85%E6%97%B6)
    - [BUG-014: S3 Bucket Policy 过宽 Deny 导致 Terraform 管理面 403（PutLifecycle/GetPolicy）](#bug-014-s3-bucket-policy-%E8%BF%87%E5%AE%BD-deny-%E5%AF%BC%E8%87%B4-terraform-%E7%AE%A1%E7%90%86%E9%9D%A2-403putlifecyclegetpolicy)
    - [BUG-015: `terraform plan` 报 “aws\_s3\_bucket has been deleted” 的误判（刷新被 403 误导）](#bug-015-terraform-plan-%E6%8A%A5-aws%5C_s3%5C_bucket-has-been-deleted-%E7%9A%84%E8%AF%AF%E5%88%A4%E5%88%B7%E6%96%B0%E8%A2%AB-403-%E8%AF%AF%E5%AF%BC)
    - [BUG-016: `BucketAlreadyExists` 创建冲突（资源已存在但不在 tfstate）](#bug-016-bucketalreadyexists-%E5%88%9B%E5%BB%BA%E5%86%B2%E7%AA%81%E8%B5%84%E6%BA%90%E5%B7%B2%E5%AD%98%E5%9C%A8%E4%BD%86%E4%B8%8D%E5%9C%A8-tfstate)
    - [BUG-017: `aws_vpc_endpoint` 提示 deprecated 属性（service\_name 组成方式）](#bug-017-aws_vpc_endpoint-%E6%8F%90%E7%A4%BA-deprecated-%E5%B1%9E%E6%80%A7service%5C_name-%E7%BB%84%E6%88%90%E6%96%B9%E5%BC%8F)
    - [BUG-018: 通过 Terraform 创建 K8s ServiceAccount 偶发 TLS 握手超时](#bug-018-%E9%80%9A%E8%BF%87-terraform-%E5%88%9B%E5%BB%BA-k8s-serviceaccount-%E5%81%B6%E5%8F%91-tls-%E6%8F%A1%E6%89%8B%E8%B6%85%E6%97%B6)
    - [BUG-019: Grafana AMP 数据源使用错误类型导致认证失败](#bug-019-grafana-amp-%E6%95%B0%E6%8D%AE%E6%BA%90%E4%BD%BF%E7%94%A8%E9%94%99%E8%AF%AF%E7%B1%BB%E5%9E%8B%E5%AF%BC%E8%87%B4%E8%AE%A4%E8%AF%81%E5%A4%B1%E8%B4%A5)
    - [BUG-020: Grafana AMP 数据源错误配置 assumeRoleArn 导致 403 权限错误](#bug-020-grafana-amp-%E6%95%B0%E6%8D%AE%E6%BA%90%E9%94%99%E8%AF%AF%E9%85%8D%E7%BD%AE-assumerolearn-%E5%AF%BC%E8%87%B4-403-%E6%9D%83%E9%99%90%E9%94%99%E8%AF%AF)
  - [附录](#%E9%99%84%E5%BD%95)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# 集群故障排查指南

- **Last Updated:** August 26, 2025, 08:15 (UTC+08:00)
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

### 常见坑与退路

- **Ingress 没地址**：先确认 AWS Load Balancer Controller 是否就绪、子网/集群标签是否正确、ServiceAccount 注解的 IAM Role 是否匹配。
- **ALB 健康检查失败**：核对探针路径与端口，应用冷启动时可适当增大 `initialDelaySeconds`。
- **HPA 不触发**：临时降低 `averageUtilization`（如 30%）、下调 `requests.cpu`（如 50m），或加大压测并发与时长。
- **镜像/架构不匹配**：ARM64 节点构建镜像时需指定 `--platform=linux/arm64`。

---

## BUG 详情

### BUG-001: Helm 部署 cluster-autoscaler 时 IRSA 注解配置错误导致 CrashLoopBackOff

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

### BUG-002: Helm 安装 cluster-autoscaler 报错：wrong type for value; expected string; got map[string]interface {}

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

### BUG-003: Terraform `aws.billing` alias 报 “No valid credential sources found”

- **问题状态**：已关闭 (Closed)
- **发现日期**：2025-07-04
- **问题现象**：
  - 运行 `terraform plan` / `make stop` 等命令时，初始化 `provider["registry.terraform.io/hashicorp/aws"].billing` 阶段失败。
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

### BUG-004: Terraform 导入 IAM Role Policy Attachment 使用短名失败（需使用完整 ARN）

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

### BUG-005: OIDC Provider 的 URL 固定写死导致重建失败隐患

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

### BUG-006: 创建 Deployment 失败 – 错误地将 `--requests=cpu=400m` 写在 `kubectl create` 命令中

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

### BUG-007: 无法找到 Deployment 名称（Helm 安装时名称自动拼接）

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

### BUG-008: Auto-Scaling 未触发/触发后未缩容（如冷却时间问题）

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

### BUG-009: NodeCreationFailure：实例未能加入集群（AL2023 nodeadm 变更）

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

### BUG-010: NodeCreationFailure：CNI 插件未初始化导致节点无法加入集群

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

### BUG-011: Terraform 初始化时因缓存问题导致 Registry 连接失败

- **问题状态**：已关闭 (Closed)
- **发现日期**：2025-07-06
- **问题现象**：
  执行 `terraform init` 时出现以下错误：
  ```
  Error: Failed to query available provider packages
  Could not retrieve the list of available versions for provider hashicorp/time:
  could not connect to registry.terraform.io: failed to request discovery document:
  Get "https://registry.terraform.io/.well-known/terraform.json": EOF
  ```
- **背景场景**：
  - Terraform 版本：>=1.5.0
  - 操作环境：Linux/macOS 终端
  - 触发条件：长期运行的 Terraform 项目或多次切换分支后
- **复现方式**：
  1. 在包含 `.terraform` 缓存目录的项目中
  2. 执行 `terraform init -reconfigure`
  3. 网络正常但出现 EOF 错误
- **根因分析**：
  Terraform 本地缓存（`.terraform` 目录）损坏或状态锁定文件（`terraform.tfstate*`）异常，导致：
  - Provider 元数据缓存过期但未自动清理
  - 锁文件冲突阻止新网络连接
  - 索引文件损坏导致 Registry 查询失败
- **修复方法**：
  **清理缓存并强制重建**：
  ```bash
  # 删除缓存目录和状态锁文件
  rm -rf .terraform* terraform.tfstate*

  # 重新初始化
  terraform init -reconfigure
  ```
- **相关命令**：
  ```bash
  # 诊断命令（网络检查）
  curl -v https://registry.terraform.io/.well-known/terraform.json

  # 替代修复（仅清理插件缓存）
  rm -rf ~/.terraform.d/plugin-cache/*
  ```
- **适用版本**：
  - Terraform >=1.0.0
  - 所有官方 Provider（aws/time/tls/helm 等）
- **经验总结**：
  > 💡 **缓存管理黄金法则**：
  > 1. Terraform 的 `.terraform` 不是版本控制内容，应随时可删除重建
  > 2. 频繁切换项目分支时，建议在 `.gitignore` 添加：
  >    ```gitignore
  >    # Terraform
  >    .terraform*
  >    *.tfstate*
  >    ```
  > 3. 对于团队协作，使用远程状态存储（如 S3）避免本地状态文件冲突

### BUG-012: Ingress 无法自动创建 ALB – 子网缺少 AWS Load Balancer Controller 所需标签

- **问题状态**：已关闭 (Closed)
- **发现日期**：2025-08-17
- **问题现象**：
  - 通过 Ingress 暴露服务后，AWS Load Balancer Controller 长时间未创建 ALB。
  - Controller 日志提示 `failed to resolve subnets` 或 `no suitable subnets found`。
- **背景场景**：
  - 使用 Terraform 自建 VPC/子网，但未为子网添加 K8s/ALB Controller 标准标签。
- **复现方式**：
  1. 在缺少标签的子网中部署 EKS 集群并安装 AWS Load Balancer Controller。
  2. 创建 Ingress 资源并等待 ALB 自动创建。
  3. 观察到 ALB 未生成，控制器日志出现上述错误。
- **根因分析**：
  - 公有与私有子网均缺少 `kubernetes.io/cluster/<cluster_name> = shared` 标签。
  - 公有子网缺少 `kubernetes.io/role/elb = 1`；私有子网缺少 `kubernetes.io/role/internal-elb = 1`。
- **修复方法**：
  - 在 Terraform 中为子网添加如下标签示例：
    ```hcl
    # 公有子网
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"

    # 私有子网
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
    ```
- **相关命令**：
  - 查看子网标签：
    ```bash
    aws ec2 describe-subnets --filters "Name=tag:kubernetes.io/cluster/dev,Values=shared"
    ```
  - 应用 Terraform 配置：
    ```bash
    terraform apply
    ```
- **适用版本**：
  - AWS Load Balancer Controller v2.x，EKS ≥1.29
- **经验总结**：
  - ALB 控制器依赖子网标签进行自动发现。自建 VPC 时务必为公有/私有子网打上标准标签。

### BUG-013: Terraform 创建 AWS Load Balancer Controller ServiceAccount 时 TLS 握手超时

- **问题状态**：已关闭 (Closed)
- **发现日期**：2025-08-17
- **问题现象**：
  - Terraform `kubernetes_service_account` 资源报错 `context deadline exceeded` 或 `TLS handshake timeout`。
- **背景场景**：
  - Terraform 通过 Kubernetes Provider 创建 `aws-load-balancer-controller` 的 ServiceAccount，但 kubeconfig 仍指向旧集群。
- **复现方式**：
  1. 未执行 `aws eks update-kubeconfig` 刷新凭证。
  2. 运行 `terraform apply` 创建该 ServiceAccount。
  3. 观察到 TLS 握手超时错误。
- **根因分析**：
  - kubeconfig 未更新导致 Terraform 无法与新的 EKS API 服务器完成 TLS 握手。
- **修复方法**：
  - 在 `post-recreate.sh` 中先刷新 kubeconfig 并通过脚本创建/注解该 ServiceAccount。
  - 或在 Terraform 前手动运行 `aws eks update-kubeconfig`。
- **相关命令**：
  ```bash
  aws eks update-kubeconfig --name <cluster> --region us-east-1 --profile phase2-sso
  ```
- **适用版本**：
  - Terraform v1.x，AWS Load Balancer Controller v2.x
- **经验总结**：
  - 涉及集群 API 的 Terraform 资源在重建后需确保 kubeconfig 已刷新；依赖集群状态的对象更适合在脚本中处理。

### BUG-014: S3 Bucket Policy 过宽 Deny 导致 Terraform 管理面 403（PutLifecycle/GetPolicy）

- **问题状态**：已关闭 (Closed)
- **发现日期**：2025-08-26
- **问题现象**：
  - `terraform apply` 在创建/更新 `aws_s3_bucket_lifecycle_configuration` 与 `aws_s3_bucket_policy` 时失败：
    - `AccessDenied: ... is not authorized to perform: s3:PutLifecycleConfiguration ... with an explicit deny in a resource-based policy`
    - `AccessDenied: ... is not authorized to perform: s3:GetBucketPolicy ... with an explicit deny in a resource-based policy`
- **背景场景**：
  - 桶：`dev-task-api-welcomed-anteater`
  - 采用 Bucket Policy 做安全基线（强制 TLS、限制 VPC 访问）
  - 管理身份：AWS SSO 管理员，从公网端点操作
- **复现方式**：
  1. 在 Bucket Policy 中对 `Action: "s3:*"` 使用显式 `Deny`，并附加 `aws:SecureTransport=false` 或/和 `aws:SourceVpc` 条件；
  2. 本机运行 `terraform apply` 更新生命周期或读取策略；
  3. 触发 403。
- **根因分析**：
  - Bucket Policy 的 **显式 Deny** 覆盖了**管理面**动作（如 `PutBucketLifecycleConfiguration`、`GetBucketPolicy`）；
  - Terraform 从公网端点调用这些 API，被资源策略直接拒绝。
- **修复方法**：
  1. **收敛 Deny 到“数据面”**：仅 `["s3:GetObject","s3:PutObject","s3:DeleteObject"]`；
  2. 若使用 VPC 限制，将条件改为 `StringNotEqualsIfExists` 避免无 `aws:SourceVpc` 上下文时误伤；
  3. 用管理员账号在控制台 **S3 > Bucket > Permissions > Bucket policy > Edit** 先“解锁”成新策略；
  4. 再 `terraform apply` 让 HCL 与远端一致。
- **相关命令**：
  ```bash
  aws s3api get-bucket-policy --bucket dev-task-api-welcomed-anteater --query Policy | jq -r .
  terraform plan -refresh-only && terraform apply -refresh-only
  terraform apply
  ```
- **适用版本**：
  - Terraform v1.x，hashicorp/aws provider v5.x
- **经验总结**：
  - **显式 Deny 总是优先生效**；限制“列目录/读写对象”放在 **IAM identity policy** 更合适，Bucket Policy 只做“数据面护栏”。

### BUG-015: `terraform plan` 报 “aws\_s3\_bucket has been deleted” 的误判（刷新被 403 误导）

- **问题状态**：已关闭 (Closed)
- **发现日期**：2025-08-26
- **问题现象**：
  - 第二次执行 `terraform plan` 显示：
    - `# module.task_api.aws_s3_bucket.this has been deleted`
- **背景场景**：
  - 刚通过控制台或其他路径更新了 Bucket Policy
  - 策略中对 `s3:ListBucket` 也做了 Deny（且带 `aws:SourceVpc` 条件）
- **复现方式**：
  1. Bucket Policy 对 `s3:ListBucket` 做 Deny（VPC 外 403）；
  2. 本机运行 `terraform plan`；
  3. Provider 刷新远端状态时遭 403 → 误判资源被外部删除。
- **根因分析**：
  - `plan` 前会执行 **refresh**；刷新调用读取桶元数据/位置/策略；
  - 由于 `ListBucket` 被 Deny，刷新 403，被当作 NotFound。
- **修复方法**：
  1. 从 Bucket Policy 的 Deny 中**移除 `s3:ListBucket`**；
  2. 仅保留对象级动作 `Get/Put/DeleteObject` 的 Deny；
  3. 执行刷新对齐：
     ```bash
     terraform plan -refresh-only
     terraform apply -refresh-only
     terraform plan
     ```
- **相关命令**：
  ```bash
  aws s3api get-bucket-policy --bucket dev-task-api-welcomed-anteater --query Policy | jq -r .
  ```
- **适用版本**：
  - Terraform v1.x，hashicorp/aws provider v5.x
- **经验总结**：
  - **刷新 ≠ 数据面**；避免用资源策略阻断 Terraform 的**管理面/读取**路径。

### BUG-016: `BucketAlreadyExists` 创建冲突（资源已存在但不在 tfstate）

- **问题状态**：已关闭 (Closed)
- **发现日期**：2025-08-26
- **问题现象**：
  - `terraform apply` 创建 `aws_s3_bucket` 报：`Error: creating S3 Bucket (...): BucketAlreadyExists`
- **背景场景**：
  - 桶名全局唯一；目标桶已存在（本账号或他人账号）
- **复现方式**：
  1. 目标桶先手工或其他流程创建；
  2. Terraform 尝试再次创建相同名字。
- **根因分析**：
  - 资源已存在但 **tfstate 未托管** 或模块路径/资源地址变更导致重复创建计划。
- **修复方法**：
  - 若为**自有桶**：`terraform import` 将现有资源纳入状态（同时导入 PublicAccess/SSE/Ownership/Policy/Lifecycle 等关联资源），随后 `terraform plan/apply`；
  - 若非自有桶：更换为**唯一新桶名**，或采用随机后缀。
- **相关命令**：
  ```bash
  aws s3api head-bucket --bucket dev-task-api-welcomed-anteater
  terraform import module.task_api.aws_s3_bucket.this dev-task-api-welcomed-anteater
  ```
- **适用版本**：
  - Terraform v1.x，hashicorp/aws provider v5.x
- **经验总结**：
  - 资源迁移/重构时优先 **import**；模块路径变更可用 `terraform state mv` 调整地址。

### BUG-017: `aws_vpc_endpoint` 提示 deprecated 属性（service\_name 组成方式）

- **问题状态**：已关闭 (Closed)
- **发现日期**：2025-08-26
- **问题现象**：
  - Plan/Apply 警告：`The attribute "name" is deprecated`
- **背景场景**：
  - 使用 `data.aws_region.current.name` 组装 `service_name`。
- **复现方式**：
  - `service_name = "com.amazonaws.${data.aws_region.current.name}.s3"`
- **根因分析**：
  - Provider 标记 `data.aws_region.current.name` 为 deprecated 场景。
- **修复方法**：
  - 改为 `data.aws_region.current.id` 或直接用 `var.region`：
    - `service_name = "com.amazonaws.${var.region}.s3"`
- **相关命令**：无（静态代码调整）
- **适用版本**：
  - hashicorp/aws provider v5.x
- **经验总结**：
  - 对 region 文字，优先来源于输入变量/`data...id`，减少未来兼容性告警。

### BUG-018: 通过 Terraform 创建 K8s ServiceAccount 偶发 TLS 握手超时

- **问题状态**：已关闭 (Closed)
- **发现日期**：2025-08-26
- **问题现象**：
  - `kubernetes_service_account` 在 `apply` 时失败：
    - `TLS handshake timeout`（10 秒内未完成）
- **背景场景**：
  - 本地 kubeconfig/令牌过期；或 EKS API 临时网络不稳
- **复现方式**：
  1. 长时间未刷新 `kubeconfig`；
  2. 直接 `terraform apply` 创建 SA。
- **根因分析**：
  - Kubernetes provider 连接 EKS API 失败（凭证过期/上下文错误）。
- **修复方法**：
  1. 先执行 `aws eks update-kubeconfig --name dev --region us-east-1`；
  2. 将 SA 管理改由 **`post-recreate.sh` 脚本**（你已实施），避免 provider 与集群状态耦合；
  3. Terraform 专注于 IAM/IRSA 等云侧资源。
- **相关命令**：
  ```bash
  aws eks update-kubeconfig --name dev --region us-east-1 --profile phase2-sso
  kubectl -n svc-task get sa task-api -o yaml
  ```
- **适用版本**：
  - Terraform v1.x，hashicorp/kubernetes provider v2.x，EKS 1.2x
- **经验总结**：
  - **平台级组件/集群对象**可脚本化安装（Helm/Kubectl），让 Terraform 主要管理 **云侧/IAM**，减少跨面耦合与脆弱点。

### BUG-019: Grafana AMP 数据源使用错误类型导致认证失败

- **问题状态**：已关闭 (Closed)
- **发现日期**：2025-08-29
- **问题现象**：Grafana 测试 AMP 数据源时显示 "Authentication methods: No Authentication"，点击 Test 返回 403 Forbidden 错误
- **背景场景**：在 EKS 集群中部署 Grafana，通过 IRSA 配置访问 Amazon Managed Prometheus 工作区
- **复现方式**：在 Grafana 数据源配置中使用 `type: prometheus` 而不是 AMP 专用类型
- **根因分析**：Grafana 的 AMP 数据源插件需要专用数据类型 `grafana-amazonprometheus-datasource` 来正确识别和处理 AWS 认证流程
- **修复方法**：将数据源类型从 `type: prometheus` 改为 `type: grafana-amazonprometheus-datasource`
- **相关命令**：
```yaml
# 错误配置
type: prometheus

# 正确配置
type: grafana-amazonprometheus-datasource
```
- **适用版本**：Grafana 11.5.0 + grafana-amazonprometheus-datasource 插件 v2.x
- **经验总结**：AMP 数据源需要专用类型才能正确支持 AWS 认证机制，使用通用 Prometheus 类型无法处理 SigV4 签名认证

### BUG-020: Grafana AMP 数据源错误配置 assumeRoleArn 导致 403 权限错误

- **问题状态**：已关闭 (Closed)
- **发现日期**：2025-08-29
- **问题现象**：即使使用正确的数据源类型，测试 AMP 数据源仍返回 403 Forbidden 错误，Web 界面显示 "Assume Role ARN" 和 "Default Region" 为空的可输入框
- **背景场景**：在已配置 IRSA 的 EKS 环境中，Grafana Pod 已通过服务账户获得正确的 IAM 角色权限
- **复现方式**：在数据源 jsonData 中配置 `assumeRoleArn` 参数，导致重复 AssumeRole 操作
- **根因分析**：当 Pod 已通过 IRSA 获得有效角色凭证时，在数据源配置中再次指定 `assumeRoleArn` 会导致插件尝试重复 AssumeRole 操作，造成权限冲突和 403 错误
- **修复方法**：移除 `assumeRoleArn` 配置，让插件直接使用 Pod 通过 IRSA 获取的 IAM 角色凭证，并显式启用 SigV4 认证
- **相关命令**：
```yaml
# 修复后的配置
jsonData:
  authType: default
  defaultRegion: us-east-1
  httpMethod: POST
  sigV4Auth: true
  sigV4AuthType: default
  sigV4Region: us-east-1
# 不再配置 assumeRoleArn
```
- **适用版本**：Grafana 11.5.0 + grafana-amazonprometheus-datasource 插件 v2.x
- **经验总结**：在已启用 IRSA 的环境中，Grafana AMP 数据源应直接使用 Pod 获得的角色凭证，避免重复配置 assumeRoleArn。需要显式启用 SigV4 认证 (`sigV4Auth: true`) 并指定认证类型 (`sigV4AuthType: default`)

---

## 附录

- **常用 Terraform 命令**：
  - 删除缓存目录和状态锁文件（仅在你**有把握**且无用状态时使用）
    ```bash
    rm -rf .terraform* terraform.tfstate*
    ```
    > ⚠️ 警告：删除 `terraform.tfstate*` 会“遗失”与真实资源的映射，谨慎使用；遇到锁问题优先用 `terraform force-unlock`。
  - 初始化/升级 Providers 与模块
    ```bash
    terraform init
    terraform init -upgrade
    ```
  - 代码格式化与语法校验
    ```bash
    terraform fmt -recursive
    terraform validate
    ```
  - 预览变更（常用组合）
    ```bash
    # 基本预览
    terraform plan

    # 仅刷新远端状态，查看漂移
    terraform plan -refresh-only

    # 输出到文件，便于“计划→执行”两步走
    terraform plan -out=plan.tfplan

    # 指定变量/变量文件
    terraform plan -var="env=dev" -var-file=env/dev.tfvars
    ```
  - 执行变更
    ```bash
    terraform apply         # 互动确认
    terraform apply -auto-approve
    terraform apply plan.tfplan    # 执行已保存的计划
    ```
  - 仅刷新状态并写回（对齐 tfstate 与真实资源）
    ```bash
    terraform apply -refresh-only
    ```
  - 查看状态与资源详情
    ```bash
    terraform show
    terraform state list
    terraform state show module.task_api.aws_s3_bucket.this
    ```
  - 导入已有资源进状态（常见场景：手工创建过的资源）
    ```bash
    terraform import module.task_api.aws_s3_bucket.this dev-task-api-welcomed-anteater
    ```
  - 移动/更名状态中的资源地址（重构模块名/资源名时）
    ```bash
    terraform state mv module.old.aws_s3_bucket.this module.task_api.aws_s3_bucket.this
    ```
  - 从状态中移除资源（不再由 TF 管理；不会删除真实资源）
    ```bash
    terraform state rm module.task_api.aws_s3_bucket_policy.this
    ```
  - 强制解锁（遇到 “state lock” 无法释放时）
    ```bash
    terraform force-unlock <LOCK_ID>
    ```
  - 输出变量（人类可读 / 机器可读）
    ```bash
    terraform output
    terraform output -json
    ```
  - 工作空间（多环境隔离：dev/stage/prod）
    ```bash
    terraform workspace list
    terraform workspace new dev
    terraform workspace select dev
    terraform workspace delete old-env
    ```
  - 精准定位/限域变更（谨慎使用 `-target`，易造成漂移）
    ```bash
    terraform plan   -target=module.task_api.aws_s3_bucket.this
    terraform apply  -target=module.task_api.aws_s3_bucket.this
    ```
  - 销毁资源（危险操作，建议只在沙箱/自动化销毁流程中使用）
    ```bash
    terraform destroy
    terraform destroy -target=module.task_api.aws_s3_bucket.this
    ```
  - 诊断日志（排错用）
    ```bash
    TF_LOG=DEBUG TF_LOG_PATH=./tf.log terraform plan
    ```
  - Provider/平台锁定（生成 `.terraform.lock.hcl`，保证团队一致性）
    ```bash
    terraform providers lock -platform=linux_amd64 -platform=darwin_amd64 -platform=windows_amd64
    ```
  - 生成资源依赖图（需本地安装 graphviz）
    ```bash
    terraform graph | dot -Tsvg > graph.svg
    ```
  - 与 Terraform Cloud/Enterprise 交互（如有使用）
    ```bash
    terraform login
    terraform logout
    ```
  - 环境变量注入变量值（无需在命令行显式 `-var`）

    ```bash
    export TF_VAR_env=dev
    export TF_VAR_region=us-east-1
    terraform plan
    ```
  - 标记/取消标记资源为“需要替换”（少用；适合触发特定资源重建）
    ```bash
    terraform taint   module.task_api.aws_s3_bucket.this
    terraform untaint module.task_api.aws_s3_bucket.this
    ```
    > ℹ️ 在 1.x 版本中 `taint/untaint` 仍可用，但官方更推荐通过**变更配置**或**生命周期策略**来驱动替换。
- **常用 AWS CLI 命令**：
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
