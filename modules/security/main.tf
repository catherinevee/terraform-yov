variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "common_tags" {
  type = map(string)
}

variable "tenant_isolation_mode" {
  type    = string
  default = "pool"
}

variable "alert_email" {
  type    = string
  default = ""
}

resource "aws_cognito_user_pool" "main" {
  name = "${var.project}-${var.environment}-users"

  password_policy {
    minimum_length    = 12
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  auto_verified_attributes = ["email"]

  username_attributes = ["email"]

  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = false
  }

  schema {
    name                = "tenant_id"
    attribute_data_type = "String"
    mutable             = false
  }

  schema {
    name                = "plan_type"
    attribute_data_type = "String"
    mutable             = true
  }

  user_attribute_update_settings {
    attributes_require_verification_before_update = ["email"]
  }

  mfa_configuration = var.environment == "prod" ? "OPTIONAL" : "OFF"

  software_token_mfa_configuration {
    enabled = var.environment == "prod"
  }

  tags = var.common_tags
}

resource "aws_cognito_user_pool_client" "api" {
  name         = "${var.project}-${var.environment}-api-client"
  user_pool_id = aws_cognito_user_pool.main.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  generate_secret = true

  access_token_validity  = 1
  id_token_validity      = 1
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  prevent_user_existence_errors = "ENABLED"
}

resource "aws_iam_role" "api_authorizer" {
  name = "${var.project}-${var.environment}-api-authorizer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_kms_key" "main" {
  description             = "KMS key for ${var.project} ${var.environment}"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = var.common_tags
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.project}-${var.environment}"
  target_key_id = aws_kms_key.main.key_id
}

output "cognito_user_pool_id" {
  value     = aws_cognito_user_pool.main.id
  sensitive = true
}

output "cognito_client_id" {
  value     = aws_cognito_user_pool_client.api.id
  sensitive = true
}

output "cognito_client_secret" {
  value     = aws_cognito_user_pool_client.api.client_secret
  sensitive = true
}

output "kms_key_arn" {
  value = aws_kms_key.main.arn
}

output "authorizer_role_arn" {
  value = aws_iam_role.api_authorizer.arn
}