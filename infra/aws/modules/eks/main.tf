resource "aws_eks_cluster" "this" {
  count    = var.create ? 1 : 0
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  vpc_config {
    subnet_ids = var.private_subnet_ids
  }
}

resource "aws_eks_node_group" "ng" {
  count           = var.create ? 1 : 0
  cluster_name    = var.cluster_name
  node_group_name = var.nodegroup_name
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids
  scaling_config {
    desired_size = 3
    max_size     = 6
    min_size     = 0
  }
}

resource "aws_iam_openid_connect_provider" "oidc" {
  count           = var.create ? 1 : 0
  url             = "https://oidc.eks.us-east-1.amazonaws.com/id/E0204AE78E971608F5B7BDCE0379F55F"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
}