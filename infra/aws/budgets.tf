// ---------------------------
// AWS Budgets 预算与提醒配置
// 通过 Billing API provider 创建月度预算，当实际花费超出阈值时发送邮件提醒
// TODO: 如需使用 SNS 进行通知，可取消注释并配置 subscriber_sns_topic_arns
// ---------------------------

locals {
  budget_name = "Phase2-Monthly-Budget" # 预算名称，便于在控制台识别
}

resource "aws_budgets_budget" "monthly_cost" {
  provider = aws.billing               # 使用带 alias 的 billing provider
  count    = var.create_budget ? 1 : 0 # 根据变量决定是否创建预算

  name         = local.budget_name    # 预算名称
  budget_type  = "COST"               # 预算类型：成本预算
  limit_amount = var.budget_limit_usd # 每月预算上限（美元）
  limit_unit   = "USD"                # 预算单位
  time_unit    = "MONTHLY"            # 预算周期：每月

  notification {
    notification_type   = "ACTUAL"                       # 以实际花费为准
    comparison_operator = "GREATER_THAN"                 # 超出阈值触发
    threshold           = var.budget_alert_threshold_pct # 触发阈值百分比
    threshold_type      = "PERCENTAGE"                   # 阈值类型：百分比

    subscriber_email_addresses = [var.budget_email] # 接收提醒的邮箱

    # subscriber_sns_topic_arns = [aws_sns_topic.spot_topic.arn]  # TODO: 通过 SNS 发送通知
  }
}
