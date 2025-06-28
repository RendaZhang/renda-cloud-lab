variable "name" {
  description = "Name of the IRSA Role"
  type        = string
}

variable "namespace" {
  description = "K8s Namespace of the ServiceAccount"
  type        = string
}

variable "service_account_name" {
  description = "Name of the ServiceAccount in Kubernetes"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster"
  type        = string
}

variable "oidc_provider_url_without_https" {
  description = "OIDC provider URL (without https://)"
  type        = string
}
