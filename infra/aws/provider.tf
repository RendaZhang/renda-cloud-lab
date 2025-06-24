provider "aws" {
  region              = var.region
  profile             = "phase2-sso"   # 本机使用的 profile
  default_tags = {
    project = "phase2-sprint"
  }
}