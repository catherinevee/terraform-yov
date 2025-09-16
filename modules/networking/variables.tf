variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
}

variable "api_throttle_rate" {
  description = "API Gateway throttle rate limit"
  type        = number
}

variable "api_throttle_burst" {
  description = "API Gateway throttle burst limit"
  type        = number
}

variable "api_usage_plans" {
  description = "API Gateway usage plans configuration"
  type = map(object({
    quota_limit  = number
    quota_period = string
    rate_limit   = number
    burst_limit  = number
  }))
}

variable "domain_name" {
  description = "Custom domain name for API"
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "ACM certificate ARN for custom domain"
  type        = string
  default     = ""
}

variable "enable_waf" {
  description = "Enable AWS WAF for CloudFront"
  type        = bool
  default     = true
}

variable "allowed_origins" {
  description = "Allowed CORS origins"
  type        = list(string)
  default     = ["*"]
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "enable_xray" {
  description = "Enable X-Ray tracing"
  type        = bool
  default     = false
}