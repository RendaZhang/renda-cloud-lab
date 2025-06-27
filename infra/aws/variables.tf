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