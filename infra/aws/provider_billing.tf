# Billing API provider alias for AWS Budgets
provider "aws" {
  alias  = "billing"
  region = "us-east-1"

  # profile = var.billing_profile  # reserved for future use
  # assume_role { role_arn = var.billing_role_arn }
}
