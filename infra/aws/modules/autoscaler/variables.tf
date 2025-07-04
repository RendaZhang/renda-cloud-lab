variable "create" {
  type    = bool
  default = true
}

variable "cluster_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "role_arn" {
  type = string
}

variable "service_account_name" {
  type    = string
  default = "cluster-autoscaler"
}

variable "image_tag" {
  type = string
}

variable "chart_version" {
  type = string
}

variable "release_name" {
  type    = string
  default = "cluster-autoscaler"
}

variable "namespace" {
  type    = string
  default = "kube-system"
}

variable "repository" {
  type    = string
  default = "https://kubernetes.github.io/autoscaler"
}

variable "chart_name" {
  type    = string
  default = "cluster-autoscaler"
}

variable "values_file" {
  type    = string
  default = ""
}

variable "values" {
  type    = map(any)
  default = {}
}
