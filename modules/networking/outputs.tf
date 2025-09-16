output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_gateway_root_resource_id" {
  description = "API Gateway root resource ID"
  value       = aws_api_gateway_rest_api.main.root_resource_id
}

output "api_gateway_url" {
  description = "API Gateway invoke URL"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "api_gateway_stage_name" {
  description = "API Gateway stage name"
  value       = aws_api_gateway_stage.main.stage_name
}

output "api_gateway_execution_arn" {
  description = "API Gateway execution ARN for Lambda permissions"
  value       = aws_api_gateway_rest_api.main.execution_arn
}

output "cloudfront_domain" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.api_cdn.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.api_cdn.id
}

output "api_keys" {
  description = "Map of API keys by usage plan"
  value = {
    for k, v in aws_api_gateway_api_key.keys : k => v.value
  }
  sensitive = true
}

output "usage_plan_ids" {
  description = "Map of usage plan IDs"
  value = {
    for k, v in aws_api_gateway_usage_plan.plans : k => v.id
  }
}

output "log_group_name" {
  description = "CloudWatch log group name for API Gateway"
  value       = aws_cloudwatch_log_group.api_gateway.name
}

output "kms_key_arn" {
  description = "KMS key ARN for log encryption"
  value       = aws_kms_key.logs.arn
}

output "waf_acl_id" {
  description = "WAF Web ACL ID"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].id : null
}