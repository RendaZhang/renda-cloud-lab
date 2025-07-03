region = "us-east-1"

profile = "phase2-sso"

eks_admin_role_arn = "arn:aws:iam::563149051155:role/eks-admin-role"

node_role_arn = "arn:aws:iam::563149051155:role/eksctl-dev-nodegroup-ng-mixed-NodeInstanceRole-6iVyvrDnxZQO"

# Enable control plane logs for API server and authenticator
cluster_log_types = ["api", "authenticator"]
