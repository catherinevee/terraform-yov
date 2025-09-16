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

variable "dynamodb_tables" {
  description = "Map of DynamoDB table configurations"
  type = map(object({
    billing_mode   = string
    hash_key       = string
    range_key      = optional(string)
    read_capacity  = optional(number)
    write_capacity = optional(number)
    attributes = list(object({
      name = string
      type = string
    }))
    global_secondary_indexes = optional(list(object({
      name            = string
      hash_key        = string
      range_key       = optional(string)
      projection_type = string
      read_capacity   = optional(number)
      write_capacity  = optional(number)
    })))
    enable_streams                = optional(bool)
    stream_view_type              = optional(string)
    enable_point_in_time_recovery = optional(bool)
    enable_ttl                    = optional(bool)
    ttl_attribute                 = optional(string)
  }))
  default = {}
}

variable "enable_multi_region" {
  description = "Enable DynamoDB global tables"
  type        = bool
  default     = false
}

variable "replica_regions" {
  description = "List of regions for DynamoDB global table replicas"
  type        = list(string)
  default     = []
}

variable "enable_aurora" {
  description = "Enable Aurora Serverless v2 for reporting"
  type        = bool
  default     = true
}

variable "aurora_config" {
  description = "Aurora Serverless v2 configuration"
  type = object({
    engine_version               = string
    database_name                = string
    master_username              = string
    min_capacity                 = number
    max_capacity                 = number
    backup_retention_period      = number
    preferred_backup_window      = string
    preferred_maintenance_window = string
    enable_http_endpoint         = bool
  })
  default = {
    engine_version               = "8.0.mysql_aurora.3.04.0"
    database_name                = "reporting"
    master_username              = "admin"
    min_capacity                 = 0.5
    max_capacity                 = 16
    backup_retention_period      = 7
    preferred_backup_window      = "03:00-04:00"
    preferred_maintenance_window = "sun:04:00-sun:05:00"
    enable_http_endpoint         = true
  }
}

variable "vpc_subnet_ids" {
  description = "VPC subnet IDs for Aurora"
  type        = list(string)
  default     = []
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
  default     = ""
}

variable "enable_autoscaling" {
  description = "Enable DynamoDB auto-scaling"
  type        = bool
  default     = true
}

variable "autoscaling_config" {
  description = "DynamoDB auto-scaling configuration"
  type = object({
    target_tracking_read  = number
    target_tracking_write = number
    min_read_capacity     = number
    max_read_capacity     = number
    min_write_capacity    = number
    max_write_capacity    = number
  })
  default = {
    target_tracking_read  = 70
    target_tracking_write = 70
    min_read_capacity     = 5
    max_read_capacity     = 40000
    min_write_capacity    = 5
    max_write_capacity    = 40000
  }
}