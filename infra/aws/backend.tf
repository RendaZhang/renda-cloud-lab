terraform {
  backend "s3" {
    bucket         = "phase2-tf-state-renda-cloud-lab" # 桶名
    key            = "eks/lab/terraform.tfstate"       # 桶里的路径对象
    region         = "ap-southeast-1"
    profile        = "phase2-sso"
    dynamodb_table = "tf-state-lock"                   # 锁表名
    use_lockfile   = true      
    encrypt        = true
  }
}