locals {
  budget_name = "Phase2-Monthly-Budget"
}

resource "aws_budgets_budget" "monthly_cost" {
  provider = aws.billing
  count    = var.create_budget ? 1 : 0

  name         = local.budget_name
  budget_type  = "COST"
  limit_amount = var.budget_limit_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    notification_type   = "ACTUAL"
    comparison_operator = "GREATER_THAN"
    threshold           = var.budget_alert_threshold_pct
    threshold_type      = "PERCENTAGE"

    subscriber_email_addresses = [var.budget_email]

    # subscriber_sns_topic_arns = [aws_sns_topic.spot_topic.arn]
  }
}
