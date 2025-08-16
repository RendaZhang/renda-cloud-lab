// ---------------------------
// Provider 配置
// aws: 访问 AWS 资源并设置统一标签
// helm: 通过本地 kubeconfig 与集群交互
// ---------------------------

provider "aws" {
  region  = var.region  # 默认区域
  profile = var.profile # 使用的 AWS CLI profile
  default_tags {
    tags = {
      project = "phase2-sprint" # 所有资源统一打上项目标签
    }
  }
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config" # 本地 kubeconfig 路径
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config" # 与 helm 共用 kubeconfig
}
