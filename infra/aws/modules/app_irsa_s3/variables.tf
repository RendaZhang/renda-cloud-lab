variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for the ServiceAccount"
  type        = string
}

variable "sa_name" {
  description = "Kubernetes ServiceAccount name"
  type        = string
}

variable "app_name" {
  description = "Application name"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket name (optional)"
  type        = string
  default     = null
}

variable "s3_prefix" {
  description = "S3 object prefix"
  type        = string
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN"
  type        = string
  default     = null
}

variable "oidc_provider_url" {
  description = "OIDC provider URL"
  type        = string
  default     = null
}

variable "create_irsa" {
  description = "Whether to create IAM policy and IRSA role"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "VPC ID for optional bucket policy SourceVpc restriction"
  type        = string
  default     = null
}
