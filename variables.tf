variable "primary_region" {
  description = "Primary AWS region for deployment"
  type        = string
  default     = "ap-southeast-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-\\d{1}$", var.primary_region))
    error_message = "Primary region must be a valid AWS region."
  }
}

variable "secondary_region" {
  description = "Secondary AWS region for multi-region deployment"
  type        = string
  default     = "ap-southeast-2"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-\\d{1}$", var.secondary_region))
    error_message = "Secondary region must be a valid AWS region."
  }
}

variable "app_version" {
  description = "Application version for tagging and deployment"
  type        = string
  default     = "1.0.0"

  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+$", var.app_version))
    error_message = "App version must follow semantic versioning (e.g., 1.0.0)."
  }
}

variable "domain_name" {
  description = "Domain name for the API (optional)"
  type        = string
  default     = ""
}

variable "enable_multi_region" {
  description = "Enable multi-region deployment"
  type        = bool
  default     = false
}

variable "api_usage_plans" {
  description = "API Gateway usage plans configuration"
  type = map(object({
    quota_limit  = number
    quota_period = string
    rate_limit   = number
    burst_limit  = number
  }))
  default = {
    free = {
      quota_limit  = 1000
      quota_period = "DAY"
      rate_limit   = 10
      burst_limit  = 20
    }
    basic = {
      quota_limit  = 10000
      quota_period = "DAY"
      rate_limit   = 50
      burst_limit  = 100
    }
    premium = {
      quota_limit  = 100000
      quota_period = "DAY"
      rate_limit   = 100
      burst_limit  = 200
    }
    enterprise = {
      quota_limit  = 1000000
      quota_period = "DAY"
      rate_limit   = 500
      burst_limit  = 1000
    }
  }
}

variable "lambda_runtime" {
  description = "Lambda runtime version"
  type        = string
  default     = "nodejs18.x"

  validation {
    condition = contains([
      "nodejs18.x",
      "nodejs20.x",
      "python3.11",
      "python3.12"
    ], var.lambda_runtime)
    error_message = "Lambda runtime must be a supported version."
  }
}

variable "enable_vpc" {
  description = "Enable VPC for Lambda functions (for RDS access)"
  type        = bool
  default     = true
}

variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications"
  type        = string
  default     = ""
}

variable "enable_waf" {
  description = "Enable AWS WAF for CloudFront distribution"
  type        = bool
  default     = true
}

variable "allowed_origins" {
  description = "Allowed CORS origins for API Gateway"
  type        = list(string)
  default     = ["*"]
}

variable "tenant_isolation_mode" {
  description = "Multi-tenant isolation strategy: 'pool' or 'silo'"
  type        = string
  default     = "pool"

  validation {
    condition     = contains(["pool", "silo"], var.tenant_isolation_mode)
    error_message = "Tenant isolation mode must be either 'pool' or 'silo'."
  }
}