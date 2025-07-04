provider "aws" {
  region  = var.region
  profile = var.profile
  default_tags {
    tags = {
      project = "phase2-sprint"
    }
  }
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}
