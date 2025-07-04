variable "create" {
  type = bool
}

variable "cluster_name" {
  type = string
}

variable "cluster_role_arn" {
  type = string
}

variable "node_role_arn" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "nodegroup_name" {
  type = string
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
