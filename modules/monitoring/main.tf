variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "common_tags" {
  type = map(string)
}

variable "enable_xray" {
  type    = bool
  default = false
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "alert_email" {
  type    = string
  default = ""
}

variable "lambda_function_names" {
  type = map(string)
}

variable "api_gateway_name" {
  type = string
}

variable "dynamodb_table_names" {
  type = list(string)
}

variable "cloudfront_distribution_id" {
  type = string
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project}-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", { stat = "Sum" }],
            [".", "Errors", { stat = "Sum" }],
            [".", "Duration", { stat = "Average" }],
            [".", "Throttles", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Lambda Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApiGateway", "4XXError", { stat = "Sum" }],
            [".", "5XXError", { stat = "Sum" }],
            [".", "Count", { stat = "Sum" }],
            [".", "Latency", { stat = "Average" }]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "API Gateway Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", { stat = "Sum" }],
            [".", "ConsumedWriteCapacityUnits", { stat = "Sum" }],
            [".", "UserErrors", { stat = "Sum" }],
            [".", "SystemErrors", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "DynamoDB Metrics"
        }
      }
    ]
  })
}

resource "aws_sns_topic" "alerts" {
  name = "${var.project}-${var.environment}-alerts"

  kms_master_key_id = "alias/aws/sns"

  tags = var.common_tags
}

resource "aws_sns_topic_subscription" "email" {
  count = var.alert_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = var.lambda_function_names

  alarm_name          = "${each.value}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Lambda function ${each.value} error rate too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = each.value
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "api_4xx" {
  alarm_name          = "${var.project}-${var.environment}-api-4xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = 60
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "API Gateway 4xx errors too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ApiName = var.api_gateway_name
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${var.project}-${var.environment}-api-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "API Gateway 5xx errors detected"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ApiName = var.api_gateway_name
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_throttles" {
  for_each = toset(var.dynamodb_table_names)

  alarm_name          = "${each.value}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ConditionalCheckFailedRequests"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "DynamoDB table ${each.value} throttling detected"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    TableName = each.value
  }

  tags = var.common_tags
}

data "aws_region" "current" {}

output "dashboard_url" {
  value = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}