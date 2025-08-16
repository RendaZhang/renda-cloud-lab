// Terraform 和 Provider 版本约束
// 避免因版本变动导致的兼容性问题
terraform {
  required_version = "~> 1.12" # Terraform CLI 版本要求

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # AWS Provider 版本
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}
