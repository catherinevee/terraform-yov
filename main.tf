module "networking" {
  source = "./modules/networking"

  project            = local.project
  environment        = local.environment
  common_tags        = local.common_tags
  api_throttle_rate  = local.current_config.api_throttle_rate
  api_throttle_burst = local.current_config.api_throttle_burst
  api_usage_plans    = var.api_usage_plans
  domain_name        = var.domain_name
  enable_waf         = var.enable_waf
  allowed_origins    = var.allowed_origins
  log_retention_days = local.current_config.log_retention_days
  enable_xray        = local.current_config.enable_xray
}

module "compute" {
  source = "./modules/compute"

  project                       = local.project
  environment                   = local.environment
  common_tags                   = local.common_tags
  lambda_runtime                = var.lambda_runtime
  lambda_memory                 = local.current_config.lambda_memory
  lambda_timeout                = local.current_config.lambda_timeout
  api_gateway_execution_arn     = module.networking.api_gateway_execution_arn
  api_gateway_id                = module.networking.api_gateway_id
  api_gateway_root_resource_id  = module.networking.api_gateway_root_resource_id
  enable_xray                   = local.current_config.enable_xray
  enable_vpc                    = var.enable_vpc
  log_retention_days            = local.current_config.log_retention_days

  lambda_functions = {
    validate = {
      handler     = "index.handler"
      description = "Input validation function"
      environment_vars = {
        TABLE_NAME = module.database.dynamodb_table_names[0]
      }
    }
    process = {
      handler     = "index.handler"
      description = "Request processing function"
      memory_size = local.current_config.lambda_memory * 2
      environment_vars = {
        TABLE_NAME = module.database.dynamodb_table_names[0]
      }
    }
    transform = {
      handler     = "index.handler"
      description = "Data transformation function"
      environment_vars = {
        BUCKET_NAME = module.storage.bucket_names["documents"]
      }
    }
    aggregate = {
      handler     = "index.handler"
      description = "Data aggregation function"
      reserved_concurrency = 10
      environment_vars = {
        AURORA_ENDPOINT = module.database.aurora_cluster_endpoint
        AURORA_SECRET   = module.database.aurora_secret_arn
      }
    }
  }
}

module "database" {
  source = "./modules/database"

  project              = local.project
  environment          = local.environment
  common_tags          = local.common_tags
  enable_multi_region  = var.enable_multi_region && local.environment == "prod"
  replica_regions      = var.enable_multi_region ? [var.secondary_region] : []
  enable_aurora        = local.environment != "dev"
  enable_autoscaling   = local.environment != "dev"

  dynamodb_tables = {
    tenants = {
      billing_mode   = local.current_config.dynamodb_billing_mode
      hash_key       = "tenant_id"
      range_key      = "created_at"
      read_capacity  = local.current_config.dynamodb_billing_mode == "PROVISIONED" ? 100 : null
      write_capacity = local.current_config.dynamodb_billing_mode == "PROVISIONED" ? 100 : null
      attributes = [
        { name = "tenant_id", type = "S" },
        { name = "created_at", type = "N" },
        { name = "status", type = "S" },
        { name = "plan_type", type = "S" }
      ]
      global_secondary_indexes = [
        {
          name            = "status-index"
          hash_key        = "status"
          range_key       = "created_at"
          projection_type = "ALL"
          read_capacity   = 50
          write_capacity  = 50
        },
        {
          name            = "plan-index"
          hash_key        = "plan_type"
          projection_type = "KEYS_ONLY"
          read_capacity   = 20
          write_capacity  = 20
        }
      ]
      enable_point_in_time_recovery = true
      enable_ttl = false
    }
    api_data = {
      billing_mode   = local.current_config.dynamodb_billing_mode
      hash_key       = "request_id"
      range_key      = "timestamp"
      read_capacity  = local.current_config.dynamodb_billing_mode == "PROVISIONED" ? 500 : null
      write_capacity = local.current_config.dynamodb_billing_mode == "PROVISIONED" ? 500 : null
      attributes = [
        { name = "request_id", type = "S" },
        { name = "timestamp", type = "N" },
        { name = "tenant_id", type = "S" },
        { name = "api_key", type = "S" }
      ]
      global_secondary_indexes = [
        {
          name            = "tenant-index"
          hash_key        = "tenant_id"
          range_key       = "timestamp"
          projection_type = "ALL"
          read_capacity   = 100
          write_capacity  = 100
        }
      ]
      enable_ttl = true
      ttl_attribute = "expiry"
    }
    analytics = {
      billing_mode   = "PAY_PER_REQUEST"
      hash_key       = "metric_id"
      range_key      = "window"
      attributes = [
        { name = "metric_id", type = "S" },
        { name = "window", type = "S" },
        { name = "tenant_id", type = "S" }
      ]
      global_secondary_indexes = [
        {
          name            = "tenant-metrics-index"
          hash_key        = "tenant_id"
          range_key       = "window"
          projection_type = "ALL"
        }
      ]
    }
  }
}

module "storage" {
  source = "./modules/storage"

  project            = local.project
  environment        = local.environment
  common_tags        = local.common_tags
  enable_versioning  = local.environment == "prod"
  enable_replication = var.enable_multi_region && local.environment == "prod"
  replica_region     = var.secondary_region
}

module "security" {
  source = "./modules/security"

  project              = local.project
  environment          = local.environment
  common_tags          = local.common_tags
  tenant_isolation_mode = var.tenant_isolation_mode
  alert_email          = var.alert_email
}

module "monitoring" {
  source = "./modules/monitoring"

  project                  = local.project
  environment              = local.environment
  common_tags              = local.common_tags
  enable_xray              = local.current_config.enable_xray
  log_retention_days       = local.current_config.log_retention_days
  alert_email              = var.alert_email
  lambda_function_names    = module.compute.lambda_function_names
  api_gateway_name         = module.networking.api_gateway_id
  dynamodb_table_names     = module.database.dynamodb_table_names
  cloudfront_distribution_id = module.networking.cloudfront_distribution_id
}