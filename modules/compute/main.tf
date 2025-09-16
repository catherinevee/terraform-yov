data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_execution" {
  for_each = var.lambda_functions

  name               = "${var.project}-${var.environment}-${each.key}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  for_each = var.lambda_functions

  role       = aws_iam_role.lambda_execution[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  for_each = var.enable_vpc ? var.lambda_functions : {}

  role       = aws_iam_role.lambda_execution[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_xray" {
  for_each = var.enable_xray ? var.lambda_functions : {}

  role       = aws_iam_role.lambda_execution[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_iam_role_policy" "lambda_custom" {
  for_each = var.lambda_functions

  name = "${var.project}-${var.environment}-${each.key}-policy"
  role = aws_iam_role.lambda_execution[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/${var.project}-${var.environment}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project}-${var.environment}-*",
          "arn:aws:s3:::${var.project}-${var.environment}-*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:${var.project}-${var.environment}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = var.kms_key_arn != "" ? var.kms_key_arn : "*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "lambda" {
  for_each = var.lambda_functions

  name              = "/aws/lambda/${var.project}-${var.environment}-${each.key}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.common_tags
}

resource "aws_lambda_function" "functions" {
  for_each = var.lambda_functions

  function_name = "${var.project}-${var.environment}-${each.key}"
  description   = each.value.description
  role          = aws_iam_role.lambda_execution[each.key].arn

  runtime     = var.lambda_runtime
  handler     = each.value.handler
  memory_size = coalesce(each.value.memory_size, var.lambda_memory)
  timeout     = coalesce(each.value.timeout, var.lambda_timeout)

  filename         = "${path.module}/lambda-placeholder.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda-placeholder.zip")

  reserved_concurrent_executions = each.value.reserved_concurrency

  dynamic "environment" {
    for_each = length(keys(coalesce(each.value.environment_vars, {}))) > 0 ? [1] : []
    content {
      variables = merge(
        {
          ENVIRONMENT = var.environment
          PROJECT     = var.project
        },
        each.value.environment_vars
      )
    }
  }

  dynamic "vpc_config" {
    for_each = var.enable_vpc ? [1] : []
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }

  dynamic "dead_letter_config" {
    for_each = var.dead_letter_queue_arn != "" ? [1] : []
    content {
      target_arn = var.dead_letter_queue_arn
    }
  }

  dynamic "tracing_config" {
    for_each = var.enable_xray ? [1] : []
    content {
      mode = "Active"
    }
  }

  layers = each.value.layers

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.lambda_basic
  ]

  tags = var.common_tags
}

resource "aws_lambda_permission" "api_gateway" {
  for_each = var.lambda_functions

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.functions[each.key].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_gateway_execution_arn}/*/*"
}

resource "aws_lambda_alias" "live" {
  for_each = var.lambda_functions

  name             = "live"
  description      = "Live alias for ${each.key}"
  function_name    = aws_lambda_function.functions[each.key].function_name
  function_version = "$LATEST"

  lifecycle {
    ignore_changes = [function_version]
  }
}

resource "aws_api_gateway_resource" "lambda_resources" {
  for_each = var.lambda_functions

  rest_api_id = var.api_gateway_id
  parent_id   = var.api_gateway_root_resource_id
  path_part   = each.key
}

resource "aws_api_gateway_method" "lambda_methods" {
  for_each = var.lambda_functions

  rest_api_id   = var.api_gateway_id
  resource_id   = aws_api_gateway_resource.lambda_resources[each.key].id
  http_method   = "ANY"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "lambda_integrations" {
  for_each = var.lambda_functions

  rest_api_id = var.api_gateway_id
  resource_id = aws_api_gateway_resource.lambda_resources[each.key].id
  http_method = aws_api_gateway_method.lambda_methods[each.key].http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.functions[each.key].invoke_arn
}

resource "aws_sfn_state_machine" "orchestrator" {
  name     = "${var.project}-${var.environment}-orchestrator"
  role_arn = aws_iam_role.step_functions.arn

  definition = jsonencode({
    Comment = "API orchestration workflow"
    StartAt = "ValidateInput"
    States = {
      ValidateInput = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.functions["validate"].arn
          Payload = {
            "input.$" = "$"
          }
        }
        Next = "ProcessRequest"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next = "HandleError"
        }]
      }
      ProcessRequest = {
        Type = "Parallel"
        Branches = [
          {
            StartAt = "ProcessData"
            States = {
              ProcessData = {
                Type = "Task"
                Resource = "arn:aws:states:::lambda:invoke"
                Parameters = {
                  FunctionName = aws_lambda_function.functions["process"].arn
                  Payload = {
                    "input.$" = "$"
                  }
                }
                End = true
              }
            }
          },
          {
            StartAt = "StoreData"
            States = {
              StoreData = {
                Type = "Task"
                Resource = "arn:aws:states:::dynamodb:putItem"
                Parameters = {
                  TableName = "${var.project}-${var.environment}-data"
                  Item = {
                    "id" = {"S.$" = "$.id"}
                    "data" = {"S.$" = "$.data"}
                    "timestamp" = {"N.$" = "$.timestamp"}
                  }
                }
                End = true
              }
            }
          }
        ]
        Next = "Success"
      }
      Success = {
        Type = "Succeed"
      }
      HandleError = {
        Type = "Fail"
        Error = "ProcessingFailed"
        Cause = "An error occurred during processing"
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_functions.arn}:*"
    include_execution_data = true
    level                  = var.environment == "prod" ? "ERROR" : "ALL"
  }

  tracing_configuration {
    enabled = var.enable_xray
  }

  tags = var.common_tags
}

resource "aws_iam_role" "step_functions" {
  name = "${var.project}-${var.environment}-stepfunctions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "step_functions" {
  name = "${var.project}-${var.environment}-stepfunctions-policy"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          for k, v in aws_lambda_function.functions : v.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/${var.project}-${var.environment}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "step_functions" {
  name              = "/aws/vendedlogs/states/${var.project}-${var.environment}-orchestrator"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.common_tags
}

resource "aws_lambda_layer_version" "shared" {
  filename   = "${path.module}/lambda-layer.zip"
  layer_name = "${var.project}-${var.environment}-shared"

  compatible_runtimes = [var.lambda_runtime]

  description = "Shared dependencies for Lambda functions"
}