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

variable "lambda_runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "nodejs18.x"
}

variable "lambda_memory" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 512
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_functions" {
  description = "Map of Lambda function configurations"
  type = map(object({
    handler              = string
    description          = string
    memory_size          = optional(number)
    timeout              = optional(number)
    reserved_concurrency = optional(number)
    environment_vars     = optional(map(string))
    layers               = optional(list(string))
  }))
  default = {}
}

variable "api_gateway_execution_arn" {
  description = "API Gateway execution ARN for Lambda permissions"
  type        = string
}

variable "api_gateway_id" {
  description = "API Gateway REST API ID"
  type        = string
}

variable "api_gateway_root_resource_id" {
  description = "API Gateway root resource ID"
  type        = string
}

variable "enable_xray" {
  description = "Enable X-Ray tracing for Lambda"
  type        = bool
  default     = false
}

variable "enable_vpc" {
  description = "Enable VPC configuration for Lambda"
  type        = bool
  default     = false
}

variable "vpc_subnet_ids" {
  description = "VPC subnet IDs for Lambda"
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "VPC security group IDs for Lambda"
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "dead_letter_queue_arn" {
  description = "Dead letter queue ARN for failed Lambda invocations"
  type        = string
  default     = ""
}

variable "kms_key_arn" {
  description = "KMS key ARN for Lambda environment variable encryption"
  type        = string
  default     = ""
}