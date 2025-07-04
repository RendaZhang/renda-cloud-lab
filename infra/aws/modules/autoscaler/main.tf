locals {
  base_values = {
    awsRegion = var.aws_region
    autoDiscovery = {
      clusterName = var.cluster_name
    }
    rbac = {
      serviceAccount = {
        create = true
        name   = var.service_account_name
        annotations = {
          "eks.amazonaws.com/role-arn" = var.role_arn
        }
      }
    }
    extraArgs = {
      "balance-similar-node-groups" = true
      "skip-nodes-with-system-pods" = false
    }
    image = {
      tag = var.image_tag
    }
  }

  merged_values = merge(local.base_values, var.values)
  values_list = concat(
    var.values_file != "" ? [file(var.values_file)] : [],
    [yamlencode(local.merged_values)]
  )
}

resource "helm_release" "this" {
  count            = var.create ? 1 : 0
  name             = var.release_name
  repository       = var.repository
  chart            = var.chart_name
  namespace        = var.namespace
  create_namespace = true
  version          = var.chart_version

  values = local.values_list
}
