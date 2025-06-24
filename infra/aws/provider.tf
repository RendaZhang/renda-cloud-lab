provider "aws" {
  region              = var.region
  # profile           = "default"      # 若本机用 named profile 可解注
  default_tags = {
    project = "phase2-sprint"
  }
}