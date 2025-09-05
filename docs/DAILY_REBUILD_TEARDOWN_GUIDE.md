<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
## 目录 (Table of Contents)

- [Terraform 重建与销毁流程操作文档](#terraform-%E9%87%8D%E5%BB%BA%E4%B8%8E%E9%94%80%E6%AF%81%E6%B5%81%E7%A8%8B%E6%93%8D%E4%BD%9C%E6%96%87%E6%A1%A3)
  - [简介](#%E7%AE%80%E4%BB%8B)
    - [命名空间说明](#%E5%91%BD%E5%90%8D%E7%A9%BA%E9%97%B4%E8%AF%B4%E6%98%8E)
      - [kube-system](#kube-system)
      - [svc-task](#svc-task)
      - [observability](#observability)
      - [chaos-testing](#chaos-testing)
    - [构建并推送 task-api 镜像](#%E6%9E%84%E5%BB%BA%E5%B9%B6%E6%8E%A8%E9%80%81-task-api-%E9%95%9C%E5%83%8F)
  - [重建流程](#%E9%87%8D%E5%BB%BA%E6%B5%81%E7%A8%8B)
    - [AWS SSO 登录和基本准备](#aws-sso-%E7%99%BB%E5%BD%95%E5%92%8C%E5%9F%BA%E6%9C%AC%E5%87%86%E5%A4%87)
    - [Makefile 命令 - start-all](#makefile-%E5%91%BD%E4%BB%A4---start-all)
    - [常见错误与排查指引](#%E5%B8%B8%E8%A7%81%E9%94%99%E8%AF%AF%E4%B8%8E%E6%8E%92%E6%9F%A5%E6%8C%87%E5%BC%95)
    - [重建验收清单](#%E9%87%8D%E5%BB%BA%E9%AA%8C%E6%94%B6%E6%B8%85%E5%8D%95)
  - [销毁流程](#%E9%94%80%E6%AF%81%E6%B5%81%E7%A8%8B)
    - [AWS SSO 登录](#aws-sso-%E7%99%BB%E5%BD%95)
    - [Makefile 命令 - stop-all](#makefile-%E5%91%BD%E4%BB%A4---stop-all)
    - [Makefile 命令 - destroy-all](#makefile-%E5%91%BD%E4%BB%A4---destroy-all)
    - [可选参数与开关（teardown 阶段）](#%E5%8F%AF%E9%80%89%E5%8F%82%E6%95%B0%E4%B8%8E%E5%BC%80%E5%85%B3teardown-%E9%98%B6%E6%AE%B5)
    - [常见错误与排查指引](#%E5%B8%B8%E8%A7%81%E9%94%99%E8%AF%AF%E4%B8%8E%E6%8E%92%E6%9F%A5%E6%8C%87%E5%BC%95-1)
    - [销毁清单验证](#%E9%94%80%E6%AF%81%E6%B8%85%E5%8D%95%E9%AA%8C%E8%AF%81)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Terraform 重建与销毁流程操作文档

- **最后更新**: August 28, 2025, 19:22 (UTC+08:00)
- **作者**: 张人大（Renda Zhang）

---

## 简介

为了避免云资源在闲置的期间继续产生费用，我们需要销毁创建的高成本云资源。利用 Terraform 和脚本实现高成本云资源的 **忙碌时重建，闲置时完全销毁** —— 比如每日上午重建环境 + 晚上销毁收费资源。这种 **闲置关停，忙碌重启** 模式确保了实验环境在非工作时段的云成本降至最低，同时保留必要的网络配置用于下次启动。

重建流程旨在快速自动恢复停用期间为节省成本而释放的云资源，以便开展实验或开发工作。通过自动部署必要的基础设施，我们可以在确保功能完整的同时，将不必要的云开销降至最低。

销毁流程通过 **关停收费资源**，释放如 NAT 网关、ALB 等按时计费的组件，同时保留基础设施的网络和状态（例如 VPC、子网以及 Terraform State），以加速下一次环境重建。

**提示**：

> - 本仓库已通过 Terraform 创建 AWS Budgets（默认 90 USD），当花费接近阈值时会以邮件提醒。
> - 完成关停流程后，环境便仅剩下不计费或低成本的基础部分（如 VPC 等）。
> - 若历史上曾使用 eksctl 创建过集群，可能在 CloudFormation 中留下 `eksctl-dev-cluster` 等栈。Terraform 删除集群后，请手动删除这些栈，以防资源残留。
> - 需要重建的时候，即可按照流程步骤，通过 Terraform 一键重建所有资源，实现完整的 **一键销毁与重建** 循环，而无需额外手动干预 EKS 集群。
> - ECR 不随每日销毁而删除，`task-api` 的容器镜像源自本仓库 `task-api/` 子项目。若该项目有改动，需要在 `task-api` 目录构建并推送新镜像到 ECR。生产/预发推荐 **固定镜像 digest**（`image: ...@sha256:...`），避免 `:latest` 漂移；ECR 生命周期策略建议至少保留最近 **5–10** 个 tag 或保留 **7 天** 的 untagged，以便快速回滚。
> - 应用级 S3 桶（如 task-api）设置了 `prevent_destroy`，不会在日常 `stop-all` / `destroy-all` 流程中删除；对应 IRSA Role 仅在 `create_eks=true` 时创建。
> - Amazon Route 53 不包含在重建与销毁流程里面，如果有使用的话，仍然会每月固定扣费 0.5 美金。
> - AMP Workspace **默认保留**，在采集侧（如 ADOT Collector）按需缩放副本数（`scale replicas=0/1`）来“关/开”采集。若采用 **AWS 托管采集器（scraper）**，其生命周期独立于 Workspace，需单独创建/删除。

### 命名空间说明

#### kube-system

系统级组件（例如 AWS Load Balancer Controller、Cluster Autoscaler、metrics-server 等）默认安装在 `kube-system` 命名空间。
Terraform 变量 `kubernetes_default_namespace` 与脚本变量 `KUBE_DEFAULT_NAMESPACE` 控制该命名空间。

#### svc-task

示例应用 `task-api` 及其关联资源（Deployment、Service、ConfigMap、PodDisruptionBudget 等）位于 `svc-task` 命名空间。
Shell 脚本变量 `NS` 和 Terraform 变量 `task_api_namespace` 均默认指向该命名空间。

#### observability

可观测性组件（例如 ADOT Collector、Grafana）部署在 `observability` 命名空间。
它由脚本变量 `ADOT_NAMESPACE`/`GRAFANA_NAMESPACE` 和 Terraform 变量 `adot_namespace` 控制。

#### chaos-testing

混沌工程组件 `Chaos Mesh` 在开启时会部署到 `chaos-testing` 命名空间，仅包含 controller 与 daemonset。

### 构建并推送 task-api 镜像

1. **确认节点架构**，以选择正确的 `--platform`：

    ```bash
    kubectl get nodes -o custom-columns=NAME:.metadata.name,ARCH:.status.nodeInfo.architecture
    ```

2. **进入子项目**：

    ```bash
    cd task-api
    ```

3. **变量与登录**：

    ```bash
    # 基本变量
    export PROFILE="phase2-sso"
    # —— 统一导出 AWS_PROFILE，省去每条命令 --profile ——
    export AWS_PROFILE="$PROFILE"
    export AWS_REGION=us-east-1
    export ECR_REPO=task-api
    export APP=task-api
    export NS=svc-task
    # 可追踪 tag
    export VERSION="0.1.0-$(date +%y%m%d%H%M)"

    # 账户与仓库 URI
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    REMOTE="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"

    # 确认/创建仓库并登录（若已存在会跳过）
    aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$AWS_REGION" >/dev/null 2>&1 \
      || aws ecr create-repository --repository-name "$ECR_REPO" --image-tag-mutability IMMUTABLE --region "$AWS_REGION"
    aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    ```

4. **本地构建镜像（下例以 `linux/amd64` 为例，可按需替换）**：

    ```bash
    docker system prune -a
    docker build --platform=linux/amd64 -t "${APP}:${VERSION}" .
    ```

5. 可使用 `docker run` 在本地冒烟：

    ```bash
    docker run -d -p 8080:8080 --name my-task "${APP}:${VERSION}"
    curl http://localhost:8080/actuator/health
    curl http://localhost:8080/actuator/prometheus
    docker stop my-task && docker rm my-task
    ```

6. **推送到 ECR 并记录 digest**：

    ```bash
    REMOTE="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/task-api"
    docker tag "${APP}:${VERSION}" "${REMOTE}:${VERSION}"
    docker tag "${APP}:${VERSION}" "$REMOTE:latest"
    docker push "${REMOTE}:${VERSION}"
    # 推送成功会回显各层与 digest

    # 读取本次镜像的 digest
    DIGEST=$(aws ecr describe-images \
      --repository-name "$ECR_REPO" \
      --image-ids imageTag="$VERSION" \
      --query 'imageDetails[0].imageDigest' \
      --output text \
      --region "$AWS_REGION")
    echo "DIGEST=$DIGEST"
    printf 'export DIGEST=%s\n' "$DIGEST" > scripts/.last_image

    # 清理本地镜像
    docker system prune -a
    ```

7. **给 ECR 镜像加新的 latest 标签**：

    ```bash
    # 拉取 ECR 镜像到本地
    docker system prune -a
    docker pull "${REMOTE}:${VERSION}"
    docker images
    # 打新标签
    docker tag "${REMOTE}:${VERSION}" "$REMOTE:latest"
    # 修改为 MUTABLE（需管理员权限）
    aws ecr put-image-tag-mutability \
    --repository-name $APP \
    --image-tag-mutability MUTABLE \
    --region $AWS_REGION
    # 推送 latest 标签
    docker push "$REMOTE:latest"
    # 改回 IMMUTABLE
    aws ecr put-image-tag-mutability \
    --repository-name $APP \
    --image-tag-mutability IMMUTABLE \
    --region $AWS_REGION
    # 本地清理
    docker system prune -a
    docker images -a
    docker ps -a
    ```

8. **更新部署引用**：
   - 将新的 digest 写入 `task-api/k8s/base/deploy-svc.yaml`。
   - 把最新的 tag `${VERSION}` 的值同步更新到 `scripts/post-recreate.sh` 的 `IMAGE_TAG` 的默认值中。
   - 可以在执行 `post-recreate.sh` 时通过 `IMAGE_TAG`/`IMAGE_DIGEST` 传入。

---

## 重建流程

### AWS SSO 登录和基本准备

在进行任何 AWS 资源操作之前，需使用 AWS Single Sign-On 登录获取临时凭证。

推荐直接执行：

```bash
make aws-login
```

它会调用 `aws sso login --profile phase2-sso` 并输出登录状态。

**预期输出**:

登录成功后终端无明显输出。

如果凭证有效期已过，则上述命令会提示打开浏览器进行重新认证。完成登录后，可继续后续步骤。

**(仅首次) 创建 Spot Interruption SNS Topic**：

若还未创建 `spot-interruption-topic`，可以在控制台手动操作，或执行下面的命令并订阅邮箱：

```bash
aws sns create-topic --name spot-interruption-topic \
  --profile phase2-sso --region us-east-1 \
  --output text --query 'TopicArn'
export SPOT_TOPIC_ARN=arn:aws:sns:us-east-1:123456789012:spot-interruption-topic
aws sns subscribe --topic-arn $SPOT_TOPIC_ARN \
  --protocol email --notification-endpoint you@example.com \
  --profile phase2-sso --region us-east-1
```

打开邮箱点击 **Confirm** 完成订阅。

**注意**：

该 Topic 只需创建一次，后续执行 `make post-recreate` 会自动绑定最新 ASG。

### Makefile 命令 - start-all

`make start-all` 命令会先执行 `make start` 一键启用基础的云资源（该命令内部会在 `infra/aws` 目录下调用 `terraform apply`，将变量 `create_nat`、`create_alb`、`create_eks` 设置为 true），然后执行 `make post-recreate`，一键完成：

- 刷新 kubeconfig 并等待集群就绪；
- 创建/注解 AWS Load Balancer Controller 的 ServiceAccount（IRSA），应用 CRDs 并通过 Helm 安装/升级 Controller；
- 安装/升级 Cluster Autoscaler、metrics-server、Grafana，并部署 HPA；
- 检查 NAT/ALB/节点组/SNS 绑定；
- 确保应用级 ServiceAccount 带 IRSA 注解；
- 部署/更新 `task-api` 及其 PodDisruptionBudget，并执行集群内冒烟；
- 发布 Ingress 并做 ALB DNS 冒烟；
- 运行 aws-cli Job 验证 STS 身份及 S3 前缀权限；
- 安装/升级 ADOT Collector（OpenTelemetry Collector）并配置向 Amazon Managed Prometheus（AMP）进行 remote_write（SigV4 签名 + IRSA）。
- （可选）默认不开启，只有当 `ENABLE_CHAOS_MESH=true` 时，才会通过 Helm 在 `chaos-testing` 命名空间安装 Chaos Mesh 核心组件（仅 controller + daemonset）。

### 常见错误与排查指引

**ImagePullBackOff / ErrImagePull**：

EKS 节点无法从 ECR 拉镜像。

检查节点角色是否有最小化 ECR 读权限（ecr:GetAuthorizationToken 等），以及子网是否能出网（NAT 就绪）。

可以先确认是否已解析出镜像 digest 并成功下发到 Deployment。

**Terraform 创建 ServiceAccount TLS 超时**：

若在 `terraform apply` 阶段通过 Kubernetes Provider 创建 AWS Load Balancer Controller 的 ServiceAccount 时出现 `context deadline exceeded` 或 TLS 握手超时，原因通常是 kubeconfig 仍指向旧集群。

解决方式：先执行 `aws eks update-kubeconfig` 刷新凭证，或直接使用 `make start-all`，该命令会在 `post-recreate` 脚本中等待集群就绪后自动创建并注解该 ServiceAccount。

**CrashLoopBackOff（健康检查失败）**：

若 liveness/readiness 配置了 Actuator 路径，请核对应用端点是否为 `/actuator/health/liveness` 与 `/actuator/health/readiness`；必要时临时放宽阈值，确保先完成闭环，再逐步收紧。

**Pending（无可调度节点）**：

若节点组按空闲自动缩至 0，首次部署时需要几分钟冷启动；检查 Cluster Autoscaler 是否 `Running` 且 IRSA 生效，然后观察 `kubectl get events -A` 与 `kubectl get nodes`。

**Terraform 状态锁定**：

如果在执行 Terraform 命令时遇到类似 `Error: Error acquiring the state lock` 的错误，

说明先前的 Terraform 进程未正常解锁状态文件。

遇到这种情况，可登录 AWS 控制台删除 DynamoDB 锁定表 (`tf-state-lock`) 中相应的锁条目，或使用命令行强制解锁：

```bash
terraform force-unlock <锁ID> -force
```

排查提示:

- 锁 ID 会在错误信息中提供。
- **务必确认没有其他 Terraform 进程在运行** 后再执行强制解锁，避免并发修改状态。

**AWS 凭证过期**：

如果命令行出现 `ExpiredToken`、`InvalidClientTokenId` 等错误，通常是 AWS SSO 凭证已过期或未登录所致。

解决办法是在当前终端重新执行 `aws sso login --profile phase2-sso` 登录，然后重试相关 Terraform 或 AWS CLI 操作。

为了防止长时间操作期间凭证失效，建议在重要步骤前确认凭证有效。

可通过 `aws sts get-caller-identity --profile phase2-sso` 验证。

**Elastic IP 配额不足**：

NAT 网关创建需要分配公有 IP (EIP)。AWS 默认每区最多提供 5 个 Elastic IP。

如果环境中已有多个 EIP 占用，

Terraform 在创建 NAT 网关时可能报错 `Error: Error creating NAT Gateway: InsufficientAddressCapacity` 或相关配额错误。

此时应检查账户的 EIP 使用情况：执行 `aws ec2 describe-addresses --region us-east-1 --profile phase2-sso` 查看已分配的 EIP 数量。

如已达到上限，可释放不需要的 EIP，或通过提交 AWS Support 工单申请提高配额。

**集群创建失败或超时**：

如果 Terraform 创建 EKS 集群的步骤失败（例如网络不通或权限问题导致控制面创建失败），

请首先检查 Terraform 部署的基础设施是否全部创建成功（VPC、子网、路由等是否就绪）。

常见原因包括：

- 未正确配置 EKS Role，可能导致 EKS 控制面创建权限不足；
- 或者之前已有同名集群未删除干净导致名称冲突。

对于权限问题，可确认 Terraform 配置中的 IAM Role 是否正确。

如是名称冲突，需确保将现有的同名集群删除或导入 Terraform 管理：可以通过 AWS CLI 或控制台删除残留的集群，然后重新执行部署。

若创建过程长时间无响应，可登录 AWS 控制台查看 EKS 集群状态或 CloudFormation 服务，找到失败原因并针对性处理。

**Terraform 计划有意外更改**：

如果在日常运行 `terraform plan` 或 `make start/stop` 时看到有非预期的资源更改（如计划销毁或新建集群等），应检查是否有人工在 AWS 控制台或其他工具中修改了基础设施（例如修改了安全组规则、删除了某些资源等）。

此时建议谨慎执行 Terraform，先弄清变更来源。

如确实存在 drift，可通过 Terraform Import 或手动调整 Terraform 配置来消除不一致，然后再次运行 plan 验证无变动后再进行 apply。

### 重建验收清单

- [x] **验证 Terraform 状态一致**：
  - Terraform 执行完成后，建议再次运行 `terraform plan`，确保状态与实际资源无偏差。Plan 返回 *No changes* 即表示资源完全同步，可放心进入下一步。
  > 提示：在今后的日常流程中，若怀疑 Terraform 状态与实际资源不同步，可随时运行 `terraform plan` 进行检查。
  > 一旦发现 drift，应立即排查原因或通过 `terraform import` 等手段修正，以确保 Terraform 管理的资源与真实环境匹配。
- [x] **NAT 网关**：
  - 已创建并分配 Elastic IP，状态为 *Available*（可通过 AWS 控制台 VPC 页面或 CLI 命令确认）。
- [x] **ALB 负载均衡**：
  - 已创建并处于 *active* 状态，监听相应端口。
  - 若配置了自定义域名 (`lab.rendazhang.com`)，可验证该域名已解析到新的 ALB DNS 地址。
- [x] **EKS 控制平面**：
  - 集群状态为 `ACTIVE`。
  - 检查集群存在且状态正常：
    ```bash
    aws eks describe-cluster --name dev --region us-east-1 --profile phase2-sso
    ```
  - kubectl 配置已更新，
  - 执行 `kubectl get nodes` 可以看到节点状态为 Ready（如果有节点运行）。
- [x] **节点组及自动伸缩**：
  - 默认节点组正常运行。
  - 如当前无工作负载且启用了自动扩缩容，节点数可能已自动缩减至 0。
  - 这种情况下，`kubectl get nodes` 可能暂时无节点列表，这是预期行为——后续有新工作负载调度时，节点会自动启动。
- [x] **Cluster Autoscaler**：
  - 运行：
    ```bash
    kubectl --namespace=kube-system get pods -l "app.kubernetes.io/name=aws-cluster-autoscaler,app.kubernetes.io/instance=cluster-autoscaler"
    ```
  - Pod 应处于 `Running` 且其 ServiceAccount 注解含有 `role-arn`
- [x] **控制面日志与 LogGroup**：
  - 执行：
    ```bash
    aws eks describe-cluster
    aws logs describe-log-groups
    ```
  - 应看到 `api`、`authenticator` 日志已启用，
  - 且存在 `/aws/eks/dev/cluster` 日志组。
- [x] **SNS 通知**：
  - 确认 Spot 通知订阅成功。
  - 可登录 AWS 控制台查看 SNS 主题 `spot-interruption-topic` 的订阅列表，
  - 应包含最新的 Auto Scaling Group（名称以 `eks-ng-mixed*` 开头）。
  - 或者检查脚本日志 `scripts/logs/post-recreate.log`，
  - 最后一行应显示 “已绑定最新 ASG” 且名称匹配当前集群节点组。
- [x] **端到端验活（本地）**：
  - 使用 `kubectl port-forward` 在本机开 8080 端口，把流量“隧道”进集群的 Service：
    ```bash
    kubectl -n svc-task port-forward svc/task-api 8080:8080
    ```
  - 另开终端验证：
    ```bash
    curl -s "http://127.0.0.1:8080/api/hello?name=Renda"
    curl -s "http://127.0.0.1:8080/actuator/health"
    ```
  - 看到业务响应与 `"status":"UP"` 即表示**已在 EKS 集群内正常运行**；该方法仅用于开发/验活，关闭命令窗口后转发即失效。
- [x] **应用层（task-api）**
  - `kubectl -n svc-task get deploy,svc` 中 `deploy/task-api` READY，`svc/task-api` 为 ClusterIP。
  - 集群内冒烟（脚本已自动执行）：
    ```bash
    kubectl -n svc-task run curl- --generate-name --image=curlimages/curl:8.8.0 --restart=Never --attach --rm -- \
      sh -lc "set -e; \
        curl -sf http://task-api.svc-task.svc.cluster.local:8080/api/hello?name=Renda >/dev/null; \
        curl -sf http://task-api.svc-task.svc.cluster.local:8080/actuator/health | grep -q '\"status\":\"UP\"'"
    ```
- [x] **IRSA 与环境变量自检（task-api）**
  - 验证 ServiceAccount 注解、环境变量以及 WebIdentity Token：
    ```bash
    export TASK_API_SERVICE_ACCOUNT_NAME="task-api"
    export NS="svc-task"
    kubectl -n "$NS" get sa "$TASK_API_SERVICE_ACCOUNT_NAME" -o yaml | grep -n "eks.amazonaws.com/role-arn"
    POD=$(kubectl -n "$NS" get pods -l app="$TASK_API_SERVICE_ACCOUNT_NAME" -o jsonpath='{.items[0].metadata.name}')
    kubectl -n "$NS" exec "$POD" -- sh -lc 'env | grep -E "S3_BUCKET|S3_PREFIX|AWS_REGION|AWS_ROLE_ARN|AWS_WEB_IDENTITY_TOKEN_FILE"'
    kubectl -n "$NS" exec "$POD" -- sh -lc 'ls -l /var/run/secrets/eks.amazonaws.com/serviceaccount/ && [ -s /var/run/secrets/eks.amazonaws.com/serviceaccount/token ] && echo "token OK"'
    ```
  - **预期**：
    * `S3_BUCKET/S3_PREFIX/AWS_REGION` 三个自定义变量存在；
    * `AWS_ROLE_ARN` 与 `AWS_WEB_IDENTITY_TOKEN_FILE` 由 EKS 自动注入；
    * 输出 `token OK` 表示投影令牌已正确挂载。
- [x] **IRSA S3 权限冒烟（aws-cli Job）**
  - 运行临时 Job 验证 STS 与 S3 前缀权限：
    ```bash
    kubectl apply -f task-api/k8s/awscli-smoke.yaml
    kubectl -n svc-task wait --for=condition=complete job/awscli-smoke --timeout=180s
    kubectl -n svc-task logs job/awscli-smoke
    kubectl -n svc-task delete job awscli-smoke --ignore-not-found
    ```
  - **预期**：日志包含 STS 身份信息，可在允许前缀写入/列举/读取，并在不允许前缀写入时得到 `AccessDenied`。
- [x] **ADOT Collector（OpenTelemetry Collector）**：
  - 部署健康：
    ```bash
    kubectl -n observability get deploy,pod -l app.kubernetes.io/instance=adot-collector
    ```
    期望 Deployment 可用且 Pod 为 `Running`。
  - IRSA 注解：
    ```bash
    kubectl -n observability get sa adot-collector -o yaml | rg 'eks.amazonaws.com/role-arn'
    ```
    期望显示 `arn:aws:iam::563149051155:role/adot-collector`；
  - AMP 写入验证（在 AMP 查询控制台）：
    - `otelcol_receiver_accepted_metric_points`
    - 或按应用指标查询，如：`sum by (k8s_namespace,k8s_pod)(rate(http_server_requests_seconds_count[5m]))`
- [x] **Grafana**：
  - 部署健康：
    ```bash
    kubectl -n observability get pods -l app.kubernetes.io/instance=grafana
    ```
    期望 Pod 为 `Running`。
  - 端口转发验证：
    ```bash
    kubectl -n observability port-forward svc/grafana 3000:80 &
    curl -s http://127.0.0.1:3000/api/health
    ```
    应返回 `{"status":"ok"}`，验证完成后结束转发。

---

## 销毁流程

### AWS SSO 登录

在销毁资源之前，先确保 AWS 登录有效（同样使用 `phase2-sso` Profile）。

如果自登录后已过了数小时，凭证可能过期，建议重新执行登录命令。

直接运行以下命令即可：

```bash
make aws-login
```

登录方法同上，不再赘述。确认凭证有效后继续后续操作。

### Makefile 命令 - stop-all

`make stop-all` 会依次执行：首先运行 `pre-teardown.sh` 删除所有 ALB 类型 Ingress，并卸载 AWS Load Balancer Controller（可选卸载 metrics-server、ADOT Collector、Grafana 与 Chaos Mesh，同时清理所有混沌实验对象），随后执行 `make stop` 一键销毁 NAT 网关、ALB 以及 EKS 控制面和节点组（保留基础网络框架以便下次重建），最后调用 `post-teardown.sh` 清理 CloudWatch 日志组、ALB/TargetGroup 及相关安全组，并再次验证 NAT 网关、EKS 集群与 ASG SNS 通知等资源是否完全删除。

执行前请确认已登录 AWS 且后端状态配置正确，以免销毁过程因权限问题中断。

命令执行完毕后，所有收费资源不再计费。

VPC 等基础设施仍保留在 AWS 账户中（这些保留的资源通常不产生显著额外费用）。

执行 `make stop-all` 命令后，可通过以下命令手动确认集群已不存在：

```bash
aws eks list-clusters --region us-east-1 --profile phase2-sso
```

### Makefile 命令 - destroy-all

执行 `make destroy-all` 触发一键完全销毁流程。

该命令首先运行 `pre-teardown.sh` 删除 ALB 类型 Ingress 并卸载 AWS Load Balancer Controller（可选卸载 metrics-server、ADOT Collector、Grafana 与 Chaos Mesh，并清理所有混沌实验对象），随后调用 `make stop` 删除 EKS 控制面，接着执行 `terraform destroy` 一次性删除包括 NAT 网关、ALB、VPC、子网、安全组、IAM 角色等在内的所有资源，最后由 `post-teardown.sh` 清理 CloudWatch 日志组、ALB/TargetGroup 与安全组并再次验证所有资源均已删除。

`make destroy-all` 会确保首先关闭任何仍在运行的组件，然后清理 Terraform 状态中记录的所有资源。

执行前请再次确认 AWS 凭证有效且无重要资源遗漏在状态外。

**预期输出**:

完全销毁完成后，Terraform 将提示所有资源删除完毕，例如：`Destroy complete! Resources: ... destroyed.`。此时在 AWS 控制台应看不到与实验相关的任何资源。

由于我们使用了远端 S3 后端，Terraform 状态文件本身会保留在状态后端中，但其中已不再有任何资源记录。

**请注意**：

完全销毁后，下次重建前需要重新执行 `terraform init` 初始化，以确保 Terraform 能正确连接远端后端并重新创建所需资源。因为状态文件清空后，Terraform 本地可能需要重新获取后端配置。

### 可选参数与开关（teardown 阶段）

- `UNINSTALL_METRICS`（Makefile 变量，默认 `true`）：控制 `pre-teardown.sh` 是否卸载 `metrics-server`。
- `UNINSTALL_ADOT`（Makefile 变量，默认 `true`）：控制 `pre-teardown.sh` 是否卸载 `ADOT Collector`（Helm release: `adot-collector`，ns: `observability`）。
- `UNINSTALL_GRAFANA`（Makefile 变量，默认 `true`）：控制 `pre-teardown.sh` 是否卸载 `Grafana`（Helm release: `grafana`，ns: `observability`）。
- `UNINSTALL_CHAOS_MESH`（Makefile 变量，默认 `true`）：控制 `pre-teardown.sh` 是否卸载 `Chaos Mesh`（Helm release: `chaos-mesh`，ns: `chaos-testing`）。
- 直接调用脚本时可使用同义环境变量：
  - `UNINSTALL_METRICS_SERVER=true bash scripts/pre-teardown.sh`
  - `UNINSTALL_ADOT_COLLECTOR=false bash scripts/pre-teardown.sh`
  - `UNINSTALL_GRAFANA=false bash scripts/pre-teardown.sh`
  - `UNINSTALL_CHAOS_MESH=false bash scripts/pre-teardown.sh`
- 其他：
  - `WAIT_ALB_DELETION_TIMEOUT`（默认 180）：等待 ALB 回收的最长秒数。
  - `DRY_RUN`（仅 `post-teardown.sh`，默认 `false`）：只打印将执行的删除动作而不实际删除。

### 常见错误与排查指引

**资源依赖导致的销毁失败**：

执行 `make stop-all` 或 Terraform 销毁时，可能遇到因为资源依赖顺序导致的错误。

例如，NAT 网关有时需要等待关联的网络接口释放才可完全删除。

如果 Terraform 销毁过程出现超时或依赖错误，可尝试再次运行销毁命令。

如多次重试仍失败，登录 AWS 控制台检查相关资源状态：确保 NAT 网关已变为 `deleted` 状态，Elastic IP 是否仍分配等。

必要时可手动释放未自动删除的资源（例如仍绑定的弹性网卡），然后再执行 Terraform 销毁。

**AWS 凭证问题**：

与重建步骤类似，若销毁过程中遇到权限相关错误（例如 AWS API 调用失败），请确认 AWS SSO 登录是否仍在有效期内。

如果自动调用的 `aws sso login` 未成功，建议手动重新登录后再执行销毁操作。

**EKS 集群删除缓慢**：

当集群内仍有自定义的附加组件或残留的负载均衡、弹性网卡等资源时，Terraform 删除可能卡顿。

必要时手动清理相关资源，然后再次执行 Terraform 销毁。

### 销毁清单验证

- [x] **Terraform 状态存储保留**：
  - 执行如下命令，预期可看到状态文件：
    ```bash
    aws s3 ls s3://phase2-tf-state-us-east-1 --profile phase2-sso
    ```
- [x] **VPC 与子网保留**：
  - 执行如下命令，预期会列出网络资源：
    ```bash
    aws ec2 describe-vpcs --region us-east-1 --profile phase2-sso
    aws ec2 describe-subnets
    ```
- [x] **NAT 网关已删除**：
  - 执行如下命令，预期应当返回空列表或状态为 `deleted`：
    ```bash
    aws ec2 describe-nat-gateways --region us-east-1 --profile phase2-sso
    ```
- [x] **ALB 与 TargetGroup 已删除**：
  - `pre-teardown.sh` 会先删除所有 ALB 类型 Ingress 并卸载 AWS Load Balancer Controller，以触发云侧 ALB/TG 优雅回收；
  - 运行以下命令检查，预期不再包含实验负载均衡：
    ```bash
    aws elbv2 describe-load-balancers --region us-east-1 --profile phase2-sso
    ```
  - `post-teardown.sh` 会兜底清理无负载均衡器关联的孤立 TargetGroup。
- [x] **ALB Controller 安全组已删除**：
  - `pre-teardown.sh` 卸载 ALB Controller 后，脚本会删除带有集群标签的安全组，可额外在 EC2 控制台或命令行确认。
- [x] **EKS 集群状态**：
  ```bash
  aws eks list-clusters --region us-east-1 --profile phase2-sso
  ```
  - 预期集群名称不出现，表明 EKS 已被成功删除。
- [x] **Spot 通知解绑**：
  - 执行 `post-teardown.sh` 脚本会自动检查 ASG 是否仍绑定通知，
  - 也可在 SNS 控制台确认。
- [x] **CloudWatch -> Log Group 已经删除。**
