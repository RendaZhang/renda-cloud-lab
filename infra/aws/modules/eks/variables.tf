variable "create" {
  description = "是否创建 EKS 相关资源"
  type        = bool
}

variable "cluster_name" {
  description = "EKS 集群名称"
  type        = string
}

variable "private_subnet_ids" {
  description = "集群使用的私有子网 ID 列表"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "集群使用的公有子网 ID 列表"
  type        = list(string)
}

variable "nodegroup_name" {
  description = "节点组名称"
  type        = string
}

variable "nodegroup_capacity_type" {
  description = "EKS node group capacity type"
  type        = string
  default     = "ON_DEMAND"
}

variable "instance_types" {
  description = "EC2 instance types for the EKS node group"
  type        = list(string)
  default     = ["t3.small", "t3.medium"]
}

variable "cluster_log_types" {
  description = "Control plane log types to enable"
  type        = list(string)
  default     = ["api", "authenticator"]
}

variable "vpc_id" {
  description = "VPC ID where the cluster will be deployed"
  type        = string
}

variable "ssh_cidrs" {
  description = "CIDR blocks allowed to SSH to nodes"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "nodeport_cidrs" {
  description = "CIDR blocks allowed to access NodePort services"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "eksctl_version" {
  description = "Version of eksctl to use"
  type        = string
  default     = "0.210.0"
}
