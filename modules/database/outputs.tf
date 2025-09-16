output "dynamodb_tables" {
  description = "Map of DynamoDB table names and ARNs"
  value = {
    for k, v in aws_dynamodb_table.tables : k => {
      name       = v.name
      arn        = v.arn
      stream_arn = v.stream_arn
    }
  }
}

output "dynamodb_table_names" {
  description = "List of DynamoDB table names"
  value       = [for t in aws_dynamodb_table.tables : t.name]
}

output "dynamodb_table_arns" {
  description = "Map of DynamoDB table ARNs"
  value = {
    for k, v in aws_dynamodb_table.tables : k => v.arn
  }
}

output "dynamodb_stream_arns" {
  description = "Map of DynamoDB stream ARNs"
  value = {
    for k, v in aws_dynamodb_table.tables : k => v.stream_arn
  }
}

output "aurora_cluster_endpoint" {
  description = "Aurora cluster endpoint"
  value       = var.enable_aurora && length(var.vpc_subnet_ids) > 0 ? aws_rds_cluster.aurora_serverless[0].endpoint : null
}

output "aurora_cluster_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = var.enable_aurora && length(var.vpc_subnet_ids) > 0 ? aws_rds_cluster.aurora_serverless[0].reader_endpoint : null
}

output "aurora_cluster_id" {
  description = "Aurora cluster ID"
  value       = var.enable_aurora && length(var.vpc_subnet_ids) > 0 ? aws_rds_cluster.aurora_serverless[0].id : null
}

output "aurora_database_name" {
  description = "Aurora database name"
  value       = var.enable_aurora && length(var.vpc_subnet_ids) > 0 ? aws_rds_cluster.aurora_serverless[0].database_name : null
}

output "aurora_secret_arn" {
  description = "Aurora password secret ARN"
  value       = var.enable_aurora && length(var.vpc_subnet_ids) > 0 ? aws_secretsmanager_secret.aurora_password[0].arn : null
  sensitive   = true
}

output "aurora_security_group_id" {
  description = "Aurora security group ID"
  value       = var.enable_aurora && length(var.vpc_subnet_ids) > 0 ? aws_security_group.aurora[0].id : null
}