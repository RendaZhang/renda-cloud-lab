// ---------------------------
// Provider 配置
// aws: 访问 AWS 资源并设置统一标签
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
