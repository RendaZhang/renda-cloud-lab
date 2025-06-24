terraform {
  backend "s3" {
    bucket         = "phase2-tf-state-renda-cloud-lab" # 新建的桶名
    key            = "eks/lab/terraform.tfstate"       # 桶里的路径对象
    region         = "ap-southeast-1"
    dynamodb_table = "tf-state-lock"                   # 新建的锁表名
    encrypt        = true
  }
}