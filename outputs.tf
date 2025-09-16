output "api_gateway_url" {
  description = "API Gateway invoke URL"
  value       = module.networking.api_gateway_url
}

output "cloudfront_domain" {
  description = "CloudFront distribution domain name"
  value       = module.networking.cloudfront_domain
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.security.cognito_user_pool_id
  sensitive   = true
}

output "cognito_client_id" {
  description = "Cognito App Client ID"
  value       = module.security.cognito_client_id
  sensitive   = true
}

output "dynamodb_tables" {
  description = "DynamoDB table names"
  value       = module.database.dynamodb_tables
}

output "s3_buckets" {
  description = "S3 bucket names"
  value       = module.storage.bucket_names
}

output "lambda_function_names" {
  description = "Lambda function names"
  value       = module.compute.lambda_function_names
}

output "api_keys" {
  description = "API Gateway API keys"
  value       = module.networking.api_keys
  sensitive   = true
}

output "monitoring_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = module.monitoring.dashboard_url
}

output "environment" {
  description = "Current deployment environment"
  value       = local.environment
}

output "regions" {
  description = "Deployment regions"
  value       = local.regions
}