// Billing API provider alias for AWS Budgets 操作
// TODO: 若需要使用独立的计费账号，可配置 billing_profile 或 assume_role
provider "aws" {
  alias   = "billing"   # 使用别名以区分主 provider
  region  = var.region  # 与主 provider 保持相同区域
  profile = var.profile # 使用相同的凭证 profile

  # profile = var.billing_profile    # 预留：单独的 billing profile
  # assume_role { role_arn = var.billing_role_arn } # 预留：跨账号访问角色
}
