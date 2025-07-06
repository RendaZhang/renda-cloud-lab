# Billing API provider alias for AWS Budgets
provider "aws" {
  alias   = "billing"
  region  = var.region  # Use the same region as the main provider
  profile = var.profile # Use the same profile as the main provider

  # profile = var.billing_profile  # reserved for future use
  # assume_role { role_arn = var.billing_role_arn }
}
