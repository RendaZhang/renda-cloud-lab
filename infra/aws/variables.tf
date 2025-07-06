variable "region" {
  description = "AWS region"
  type        = string
}

variable "profile" {
  description = "AWS CLI profile"
  type        = string
  default     = "phase2-sso" # 本机使用的 profile
}

variable "eks_admin_role_arn" {
  description = "IAM role ARN with EKS admin permissions"
  type        = string
}

variable "node_role_arn" {
  description = "IAM role ARN for EKS worker nodes"
  type        = string
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
