provider "aws" {
  region = var.primary_region

  default_tags {
    tags = local.common_tags
  }
}

provider "aws" {
  alias  = "secondary"
  region = var.secondary_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  environment = terraform.workspace != "default" ? terraform.workspace : "dev"
  project     = "serverless-api"

  common_tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
    Owner       = "platform-team"
    CostCenter  = "engineering"
    Compliance  = "pci-dss"
    Version     = var.app_version
  }

  regions = {
    primary   = var.primary_region
    secondary = var.secondary_region
  }

  environment_config = {
    dev = {
      lambda_memory         = 512
      lambda_timeout        = 30
      api_throttle_rate     = 1000
      api_throttle_burst    = 2000
      dynamodb_billing_mode = "PAY_PER_REQUEST"
      enable_xray          = false
      log_retention_days   = 7
    }
    staging = {
      lambda_memory         = 1024
      lambda_timeout        = 60
      api_throttle_rate     = 5000
      api_throttle_burst    = 10000
      dynamodb_billing_mode = "PROVISIONED"
      enable_xray          = true
      log_retention_days   = 30
    }
    prod = {
      lambda_memory         = 2048
      lambda_timeout        = 90
      api_throttle_rate     = 10000
      api_throttle_burst    = 20000
      dynamodb_billing_mode = "PROVISIONED"
      enable_xray          = true
      log_retention_days   = 90
    }
  }

  current_config = local.environment_config[local.environment]
}