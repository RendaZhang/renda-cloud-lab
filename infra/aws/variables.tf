variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "Existing VPC for EKS"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "eks_admin_role_arn" {
  description = "IAM role ARN with EKS admin permissions"
  type        = string
}