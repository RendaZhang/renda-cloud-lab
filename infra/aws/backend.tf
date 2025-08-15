// Terraform 远程状态配置，使用 S3 存储状态并通过 DynamoDB 加锁
// TODO: 如需迁移到其他环境或账户，请修改 bucket、key、region 等参数
terraform {
  backend "s3" {
    bucket         = "phase2-tf-state-us-east-1" # 存储 Terraform 状态的 S3 桶名称
    key            = "eks/lab/terraform.tfstate" # 状态文件在 S3 桶中的路径
    region         = "us-east-1"                 # S3 桶所在区域
    profile        = "phase2-sso"                # 本地使用的 AWS CLI profile
    dynamodb_table = "tf-state-lock"             # Terraform 状态锁的 DynamoDB 表
    encrypt        = true                        # 开启服务端加密
  }
}
