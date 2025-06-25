terraform {
  backend "s3" {
    bucket         = "phase2-tf-state-us-east-1" # 桶名
    key            = "eks/lab/terraform.tfstate" # 桶里的路径对象
    region         = "us-east-1"
    profile        = "phase2-sso"
    dynamodb_table = "tf-state-lock" # 锁表名     
    encrypt        = true
  }
}