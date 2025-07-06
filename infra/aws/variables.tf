variable "region" {
  description = "AWS region"
  type        = string
}

variable "profile" {
  description = "AWS CLI profile"
  type        = string
  default     = "phase2-sso" # 本机使用的 profile
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "dev"
}

variable "nodegroup_name" {
  description = "Name of the EKS node group"
  type        = string
  default     = "ng-mixed"
}

variable "nodegroup_capacity_type" {
  description = "EKS node group capacity type"
  type        = string
  default     = "ON_DEMAND" # 可选值：ON_DEMAND, SPOT
}

variable "irsa_role_name" {
  description = "Name of the IRSA role"
  type        = string
  default     = "eks-cluster-autoscaler"
}

variable "service_account_name" {
  description = "Name of the ServiceAccount in Kubernetes"
  type        = string
  default     = "cluster-autoscaler"
}

variable "kubernetes_default_namespace" {
  description = "Default Kubernetes namespace for the ServiceAccount"
  type        = string
  default     = "kube-system"
}

variable "eksctl_version" {
  description = "Version of eksctl to use"
  type        = string
  default     = "0.210.0"
}

variable "cluster_log_types" {
  description = "Control plane log types to enable"
  type        = list(string)
  default     = ["api", "authenticator"]
}

variable "create_nat" {
  type    = bool
  default = true
}

variable "create_alb" {
  type    = bool
  default = true
}

variable "create_eks" {
  type    = bool
  default = true
}

variable "instance_types" {
  description = "EC2 instance types for the EKS node group"
  type        = list(string)
  default     = ["t3.small", "t3.medium"]
}

variable "ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access to nodes"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "nodeport_cidrs" {
  description = "CIDR blocks allowed for NodePort services"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "create_budget" {
  description = "Whether to create AWS Budgets via Terraform"
  type        = bool
  default     = true
}

variable "budget_limit_usd" {
  description = "Monthly cost limit in USD"
  type        = number
  default     = 90
}

variable "budget_email" {
  description = "Email address for cost alert"
  type        = string
  default     = "rendazhang@qq.com"
}

variable "budget_alert_threshold_pct" {
  description = "Alert threshold percentage"
  type        = number
  default     = 80
}

/* Reserved for future dedicated billing role/profile
variable "billing_profile" {
  description = "AWS CLI named profile for Billing API"
  type        = string
  default     = null
}

variable "billing_role_arn" {
  description = "IAM Role ARN for Budget operations"
  type        = string
  default     = null
}
*/
