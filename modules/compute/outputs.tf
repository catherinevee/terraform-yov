output "lambda_function_arns" {
  description = "Map of Lambda function ARNs"
  value = {
    for k, v in aws_lambda_function.functions : k => v.arn
  }
}

output "lambda_function_names" {
  description = "Map of Lambda function names"
  value = {
    for k, v in aws_lambda_function.functions : k => v.function_name
  }
}

output "lambda_function_invoke_arns" {
  description = "Map of Lambda function invoke ARNs"
  value = {
    for k, v in aws_lambda_function.functions : k => v.invoke_arn
  }
}

output "lambda_execution_role_arns" {
  description = "Map of Lambda execution role ARNs"
  value = {
    for k, v in aws_iam_role.lambda_execution : k => v.arn
  }
}

output "lambda_log_group_names" {
  description = "Map of Lambda CloudWatch log group names"
  value = {
    for k, v in aws_cloudwatch_log_group.lambda : k => v.name
  }
}

output "lambda_alias_arns" {
  description = "Map of Lambda alias ARNs"
  value = {
    for k, v in aws_lambda_alias.live : k => v.arn
  }
}

output "step_functions_arn" {
  description = "Step Functions state machine ARN"
  value       = aws_sfn_state_machine.orchestrator.arn
}

output "step_functions_name" {
  description = "Step Functions state machine name"
  value       = aws_sfn_state_machine.orchestrator.name
}

output "step_functions_role_arn" {
  description = "Step Functions execution role ARN"
  value       = aws_iam_role.step_functions.arn
}

output "lambda_layer_arn" {
  description = "Shared Lambda layer ARN"
  value       = aws_lambda_layer_version.shared.arn
}

output "lambda_layer_version" {
  description = "Shared Lambda layer version"
  value       = aws_lambda_layer_version.shared.version
}