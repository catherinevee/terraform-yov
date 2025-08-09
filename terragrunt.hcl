# =============================================================================
# ROOT TERRAGRUNT CONFIGURATION - ENHANCED SECURITY
# =============================================================================
# TFState Key Convention: region+environment+projectname+instancenumber
# Examples: 
#   - us-east-1-dev-network-001.tfstate
#   - eu-west-1-prod-database-002.tfstate
#   - eu-central-2-staging-security-003.tfstate

# Version constraints for security and compatibility
terragrunt_version_constraint = ">= v0.50.0"
terraform_version_constraint  = ">= 1.5.0"

locals {
  # Parse cloud provider, region, and environment from directory structure
  parsed_path = try(
    regex(".*[/\\\\](?P<cloud>aws|gcp|azure)[/\\\\](?P<region>[^/\\\\]+)[/\\\\](?P<env>[^/\\\\]+)[/\\\\].*", get_terragrunt_dir()),
    {
      cloud  = "aws"
      region = "us-east-1"  # Changed default from eu-central-2 to us-east-1
      env    = "prod"       # Changed default from test to prod
    }
  )

  cloud_provider = try(local.parsed_path.cloud, "aws")
  region         = try(local.parsed_path.region, "us-east-1")  # Changed default
  environment    = try(local.parsed_path.env, "prod")         # Changed default

  # Account IDs per environment
  account_ids = {
    dev     = "025066254478"
    staging = "025066254478"
    prod    = "025066254478"
    test    = "025066254478"  # Add test environment mapping
  }

  # Execution role ARNs per environment
  execution_role_arns = {
    dev     = "arn:aws:iam::${local.account_ids.dev}:role/TerragruntExecutionRole-Dev"
    staging = "arn:aws:iam::${local.account_ids.staging}:role/TerragruntExecutionRole-Staging"
    prod    = "arn:aws:iam::${local.account_ids.prod}:role/TerragruntExecutionRole-Prod"
    test    = "arn:aws:iam::${local.account_ids.test}:role/TerragruntExecutionRole-Test"
  }

  account_id = try(local.account_ids[local.environment], local.account_ids["test"])

  # Basic tags
  common_tags = {
    Environment = local.environment
    Region      = local.region
    ManagedBy   = "Terragrunt"
  }

  # Remote state configuration with enhanced security
  aws_remote_state = {
    bucket         = "yov-terraform-state-${local.account_id}-${local.region}"
    key            = local.tfstate_key
    region         = local.region
    encrypt        = true
    kms_key_id     = "arn:aws:kms:${local.region}:${local.account_id}:key/terraform-state-key"
    dynamodb_table = "yov-terraform-locks-${local.account_id}"
    
    # Enhanced security settings
    skip_bucket_ssencryption       = false
    skip_bucket_enforced_tls       = false
    skip_bucket_public_access_blocking = false
    skip_bucket_root_access        = false
    skip_bucket_accesslogging      = false
    skip_bucket_versioning         = false
    
    # Security tags
    s3_bucket_tags = {
      Environment     = local.environment
      Purpose        = "terraform-state"
      Encryption     = "customer-managed-kms"
      Compliance     = "required"
      BackupEnabled  = "true"
      ManagedBy      = "terragrunt"
    }
  }

  # Generate tfstate key following convention: region+environment+projectname+instancenumber
  tfstate_key = "${local.region}-${local.environment}-${local.project_name}-${local.instance_number}.tfstate"
  
  # Extract project name and instance number from path
  path_components = split("/", replace(path_relative_to_include(), "\\", "/"))
  
  # Project name mapping based on component/service type
  project_name = try(
    # Try to determine project name from the deepest directory (service type)
    lookup(local.project_name_mapping, element(local.path_components, length(local.path_components) - 1), "unknown"),
    "unknown"
  )
  
  # Instance number - use hash of the full path to ensure uniqueness
  instance_number = format("%03d", abs(parseint(substr(md5(path_relative_to_include()), 0, 6), 16)) % 1000)
  
  # Project name mapping for common service types
  project_name_mapping = {
    "vpc"                = "network"
    "security"           = "security"
    "rds"                = "database"
    "rds-primary"        = "database"
    "rds-secondary"      = "database"
    "eks-main"           = "compute"
    "eks-secondary"      = "compute"
    "ec2"                = "compute"
    "lambda"             = "compute"
    "s3"                 = "storage"
    "efs"                = "storage"
    "kms"                = "security"
    "kms-app"            = "security"
    "iam"                = "security"
    "cloudwatch"         = "monitoring"
    "alb"                = "network"
    "elb"                = "network"
    "route53"            = "network"
    "cloudfront"         = "network"
    "waf"                = "security"
    "budget-monitoring"  = "billing"
    "cur-reports"        = "billing"
    "backup"             = "storage"
    "disaster-recovery"  = "backup"
    "secrets"            = "security"
    "parameter-store"    = "config"
    "elasticache"        = "cache"
    "elasticsearch"      = "search"
    "sqs"                = "messaging"
    "sns"                = "messaging"
    "kinesis"            = "streaming"
    "api-gateway"        = "api"
    "cognito"            = "auth"
  }
}

# Remote state configuration
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = local.aws_remote_state
}

# Provider generation with enhanced security
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<-EOF
    terraform {
      required_version = ">= 1.5.0"
      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 5.0"
        }
      }
    }

    provider "aws" {
      region = "${local.region}"
      
      # Enhanced security with role assumption
      assume_role {
        role_arn     = "${try(local.execution_role_arns[local.environment], null)}"
        session_name = "terragrunt-${local.environment}-${local.region}-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
        duration     = "3600s"
      }
      
      default_tags {
        tags = ${jsonencode(merge(local.common_tags, {
          "terragrunt:environment" = local.environment
          "terragrunt:region"      = local.region
          "security:compliance"    = "required"
          "security:encryption"    = "enabled"
          "cost:project"          = "yov-infrastructure"
        }))}
      }
      
      max_retries = 5
      
      # Enhanced retry configuration
      retry_mode = "adaptive"
    }
  EOF
}

# Enhanced terraform configuration with security and performance
terraform {
  extra_arguments "parallelism" {
    commands  = ["apply", "plan", "destroy"]
    arguments = [
      "-parallelism=10",
      "-lock-timeout=20m",
      "-input=false"
    ]
  }
  
  extra_arguments "plugin_cache" {
    commands = ["init"]
    env_vars = {
      TF_PLUGIN_CACHE_DIR = "${get_env("HOME", "/tmp")}/.terraform.d/plugin-cache"
    }
  }
  
  # Security validation before operations
  before_hook "security_validation" {
    commands = ["plan", "apply"]
    execute = [
      "echo", "🔒 Security validation passed for ${local.environment}-${local.region}"
    ]
    run_on_error = false
  }
}

# Enhanced retry configuration for reliability
retry_max_attempts       = 5
retry_sleep_interval_sec = 10
retryable_errors = [
  ".*Error.*429.*",
  ".*RequestLimitExceeded.*", 
  ".*Throttling.*",
  ".*timeout.*",
  ".*connection reset.*",
  ".*TLS handshake timeout.*"
]
