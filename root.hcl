# =============================================================================
# ROOT CONFIGURATION - Global settings for all Terragrunt configurations
# =============================================================================
# This file contains the foundational configuration that applies to all
# Terragrunt deployments including backend, provider generation, and common locals

locals {
  # Parse cloud provider, region, and environment from directory structure
  parsed_path = regex(".*/(?P<cloud>aws|gcp|azure)/(?P<region>[^/]+)/(?P<env>[^/]+)/.*", get_terragrunt_dir())
  
  cloud_provider = try(local.parsed_path.cloud, "aws")
  region = try(local.parsed_path.region, "eu-central-2")
  environment = try(local.parsed_path.env, "dev")
  
  # Account/Project/Subscription IDs per environment
  account_ids = {
    dev = "123456789012"
    staging = "234567890123"
    prod = "345678901234"
  }
  
  # GCP Project IDs
  gcp_project_ids = {
    dev = "yov-infrastructure-dev"
    staging = "yov-infrastructure-staging"
    prod = "yov-infrastructure-prod"
  }
  
  # Azure Subscription IDs
  azure_subscription_ids = {
    dev = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    staging = "bbbbbbbb-cccc-dddd-eeee-ffffffffffff"
    prod = "cccccccc-dddd-eeee-ffff-aaaaaaaaaaaa"
  }
  
  account_id = local.account_ids[local.environment]
  project_id = local.gcp_project_ids[local.environment]
  subscription_id = local.azure_subscription_ids[local.environment]
  subscription_id_short = substr(replace(local.subscription_id, "-", ""), 0, 8)
  
  # Region mappings for cross-cloud compatibility
  region_mappings = {
    aws = {
      primary = "eu-central-2"
      secondary = "eu-west-1"
      dr = "us-west-2"
      short_names = {
        "us-east-1" = "use1"
        "us-west-2" = "usw2"
        "eu-west-1" = "euw1"
        "eu-central-1" = "euc1"
        "eu-central-2" = "euc2"
        "ap-southeast-1" = "apse1"
      }
    }
    gcp = {
      primary = "us-central1"
      secondary = "europe-west1"
      dr = "us-west1"
      short_names = {
        "us-central1" = "usc1"
        "us-west1" = "usw1"
        "europe-west1" = "euw1"
        "asia-southeast1" = "asse1"
      }
    }
    azure = {
      primary = "East US"
      secondary = "West Europe"
      dr = "West US 2"
      short_names = {
        "East US" = "eus"
        "West US 2" = "wus2"
        "West Europe" = "weu"
        "Southeast Asia" = "sea"
      }
    }
  }
  
  region_short = local.region_mappings[local.cloud_provider].short_names[local.region]
  
  # Business and compliance metadata
  business_unit = get_env("BUSINESS_UNIT", "Engineering")
  cost_center = get_env("COST_CENTER", "CC-1001")
  project_code = get_env("PROJECT_CODE", "YOV-2024-001")
  owner_email = get_env("OWNER_EMAIL", "infrastructure@yov.com")
  team = get_env("TEAM", "Platform")
  
  # Compliance and regulatory tags
  compliance_tags = {
    DataClassification = local.environment == "prod" ? "Confidential" : "Internal"
    Compliance = local.environment == "prod" ? "SOC2-PCI-DSS-GDPR" : "None"
    DataResidency = local.region
    EncryptionRequired = "true"
    BackupRequired = local.environment == "prod" ? "true" : "false"
    DRRequired = local.environment == "prod" ? "true" : "false"
    PIIData = local.environment == "prod" ? "true" : "false"
    GDPR = contains(["eu-west-1", "eu-central-1", "europe-west1"], local.region) ? "true" : "false"
  }
  
  # Cost optimization tags
  cost_tags = {
    Environment = local.environment
    BusinessUnit = local.business_unit
    CostCenter = local.cost_center
    Project = local.project_code
    Owner = local.owner_email
    Team = local.team
    
    # Automation tags for cost savings
    AutoShutdown = local.environment == "dev" ? "true" : "false"
    WorkingHours = local.environment == "dev" ? "Mon-Fri-0800-1800-EST" : "24x7"
    AllowStop = local.environment != "prod" ? "true" : "false"
    
    # Rightsizing tags
    Resize = local.environment != "prod" ? "allowed" : "prohibited"
    ScaleDown = local.environment == "dev" ? "after-hours" : "never"
    
    # Lifecycle tags
    CreatedDate = formatdate("YYYY-MM-DD", timestamp())
    ExpiryDate = local.environment == "dev" ? 
      formatdate("YYYY-MM-DD", timeadd(timestamp(), "720h")) : "never"
    ReviewDate = formatdate("YYYY-MM-DD", timeadd(timestamp(), "2160h"))  # 90 days
  }
  
  # Operational tags
  operational_tags = {
    ManagedBy = "Terragrunt"
    ProvisionedBy = "Terraform"
    Version = get_env("GITHUB_SHA", "local")
    Repository = get_env("GITHUB_REPOSITORY", "terraform-yov")
    DeploymentMethod = get_env("GITHUB_ACTIONS", "false") == "true" ? "CI/CD" : "Manual"
    
    # Monitoring and alerting
    MonitoringLevel = local.environment == "prod" ? "Enhanced" : "Basic"
    AlertingEnabled = local.environment != "dev" ? "true" : "false"
    LogLevel = local.environment == "prod" ? "INFO" : "DEBUG"
    
    # Backup and DR
    BackupSchedule = local.environment == "prod" ? "Daily" : "Weekly"
    BackupRetention = local.environment == "prod" ? "30days" : "7days"
    DRStrategy = local.environment == "prod" ? "Active-Passive" : "None"
    RPO = local.environment == "prod" ? "1hour" : "24hours"
    RTO = local.environment == "prod" ? "4hours" : "48hours"
  }
  
  # Merge all tags
  common_tags = merge(
    local.compliance_tags,
    local.cost_tags,
    local.operational_tags,
    {
      # Dynamic tags that change with each deployment
      LastModified = timestamp()
      LastModifiedBy = get_env("USER", "terraform")
      TerraformWorkspace = get_env("TF_WORKSPACE", "default")
    }
  )
  
  # KMS and encryption settings
  gcp_kms_key = "projects/${local.project_id}/locations/${local.region}/keyRings/terraform-state/cryptoKeys/state-encryption"
  billing_project_id = get_env("GCP_BILLING_PROJECT", local.project_id)
  terraform_service_account = "terraform-sa@${local.project_id}.iam.gserviceaccount.com"
  tenant_id = get_env("ARM_TENANT_ID", "00000000-0000-0000-0000-000000000000")
}

# =============================================================================
# REMOTE STATE CONFIGURATION
# =============================================================================
remote_state {
  backend = local.cloud_provider == "aws" ? "s3" : local.cloud_provider == "gcp" ? "gcs" : "azurerm"
  
  generate = {
    path = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  
  config = local.cloud_provider == "aws" ? {
    # S3 backend for AWS
    bucket = "yov-terraform-state-${local.account_id}-${local.region}"
    key = "${path_relative_to_include()}/terraform.tfstate"
    region = local.region
    encrypt = true
    kms_key_id = "arn:aws:kms:${local.region}:${local.account_id}:alias/terraform-state"
    dynamodb_table = "yov-terraform-locks-${local.account_id}"
    
    # Security hardening
    skip_bucket_versioning = false
    skip_bucket_ssencryption = false
    skip_bucket_public_access_blocking = false
    skip_bucket_enforced_tls = false
    skip_bucket_root_access = false
    enable_lock_table_ssencryption = true
    
    # Access logging
    accesslogging_bucket_name = "yov-terraform-state-logs-${local.account_id}-${local.region}"
    accesslogging_target_prefix = "state-access-logs/"
    
    # Bucket tags
    s3_bucket_tags = merge(
      local.common_tags,
      {
        Purpose = "TerraformState"
        DataClassification = "Confidential"
        BackupPolicy = "Daily"
        Compliance = "SOC2-PCI-DSS"
      }
    )
    
    # DynamoDB tags
    dynamodb_table_tags = merge(
      local.common_tags,
      {
        Purpose = "TerraformLocks"
      }
    )
  } : local.cloud_provider == "gcp" ? {
    # GCS backend for GCP
    bucket = "yov-terraform-state-${local.project_id}"
    prefix = "${path_relative_to_include()}"
    project = local.project_id
    location = local.region
    
    # Encryption
    encryption_key = local.gcp_kms_key
    
    # Versioning
    enable_bucket_versioning = true
    enable_bucket_lifecycle_rules = true
    
  } : {
    # Azure backend
    resource_group_name = "yov-terraform-state-rg"
    storage_account_name = "yovtfstate${local.subscription_id_short}"
    container_name = "tfstate"
    key = "${path_relative_to_include()}/terraform.tfstate"
    
    # Encryption
    use_azuread_auth = true
    subscription_id = local.subscription_id
  }
}

# =============================================================================
# PROVIDER GENERATION
# =============================================================================
generate "provider" {
  path = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents = local.cloud_provider == "aws" ? <<-EOF
    provider "aws" {
      region = "${local.region}"
      
      # Assume role for cross-account access
      assume_role {
        role_arn = "arn:aws:iam::${local.account_id}:role/YOVTerragruntExecutionRole"
        session_name = "terragrunt-${local.environment}-${formatdate("YYYYMMDD-hhmm", timestamp())}"
        external_id = "${get_env("EXTERNAL_ID", "")}"
      }
      
      # Default tags for all resources
      default_tags {
        tags = ${jsonencode(local.common_tags)}
      }
      
      # Retry configuration
      max_retries = 3
      
      # Skip certain validations for faster operations
      skip_metadata_api_check = false
      skip_region_validation = false
      skip_credentials_validation = false
    }
    
    # Additional providers for multi-region
    provider "aws" {
      alias = "us_east_1"
      region = "us-east-1"
      
      assume_role {
        role_arn = "arn:aws:iam::${local.account_id}:role/YOVTerragruntExecutionRole"
        session_name = "terragrunt-${local.environment}-us-east-1"
      }
      
      default_tags {
        tags = ${jsonencode(local.common_tags)}
      }
    }
    
    # Provider for Route53 (always in us-east-1)
    provider "aws" {
      alias = "route53"
      region = "us-east-1"
      
      assume_role {
        role_arn = "arn:aws:iam::${local.account_id}:role/YOVTerragruntRoute53Role"
        session_name = "terragrunt-route53"
      }
    }
    
    # Provider for CloudFront (us-east-1 only)
    provider "aws" {
      alias = "cloudfront"
      region = "us-east-1"
      
      assume_role {
        role_arn = "arn:aws:iam::${local.account_id}:role/YOVTerragruntExecutionRole"
        session_name = "terragrunt-cloudfront"
      }
    }
  EOF
  : local.cloud_provider == "gcp" ? <<-EOF
    provider "google" {
      project = "${local.project_id}"
      region = "${local.region}"
      
      # Service account impersonation
      impersonate_service_account = "${local.terraform_service_account}"
      
      # Request timeout
      request_timeout = "60s"
      
      # Batching configuration
      batching {
        enable_batching = true
        send_after = "10s"
      }
      
      # User project override for quota and billing
      user_project_override = true
      billing_project = "${local.billing_project_id}"
    }
    
    provider "google-beta" {
      project = "${local.project_id}"
      region = "${local.region}"
      
      impersonate_service_account = "${local.terraform_service_account}"
      
      batching {
        enable_batching = true
        send_after = "10s"
      }
    }
    
    # Multi-region provider for global resources
    provider "google" {
      alias = "global"
      project = "${local.project_id}"
      region = "us-central1"
      
      impersonate_service_account = "${local.terraform_service_account}"
    }
  EOF
  : <<-EOF
    provider "azurerm" {
      features {
        resource_group {
          prevent_deletion_if_contains_resources = ${local.environment == "prod"}
        }
        
        key_vault {
          purge_soft_delete_on_destroy = ${local.environment != "prod"}
          recover_soft_deleted_key_vaults = true
          purge_soft_deleted_keys_on_destroy = false
          purge_soft_deleted_secrets_on_destroy = false
          purge_soft_deleted_certificates_on_destroy = false
        }
        
        virtual_machine {
          delete_os_disk_on_deletion = ${local.environment != "prod"}
          graceful_shutdown = true
          skip_shutdown_and_force_delete = false
        }
        
        virtual_machine_scale_set {
          roll_instances_when_required = true
          scale_to_zero_before_deletion = true
        }
        
        template_deployment {
          delete_nested_items_during_deletion = ${local.environment != "prod"}
        }
        
        log_analytics_workspace {
          permanently_delete_on_destroy = ${local.environment != "prod"}
        }
        
        cognitive_account {
          purge_soft_delete_on_destroy = ${local.environment != "prod"}
        }
        
        api_management {
          purge_soft_delete_on_destroy = ${local.environment != "prod"}
          recover_soft_deleted = true
        }
        
        app_configuration {
          purge_soft_delete_on_destroy = ${local.environment != "prod"}
          recover_soft_deleted = true
        }
        
        application_insights {
          disable_generated_rule = false
        }
        
        machine_learning {
          purge_soft_deleted_workspace_on_destroy = ${local.environment != "prod"}
        }
      }
      
      subscription_id = "${local.subscription_id}"
      tenant_id = "${local.tenant_id}"
      
      # Use Azure CLI or OIDC authentication
      use_cli = false
      use_oidc = true
      use_msi = false
      
      # OIDC Configuration for GitHub Actions
      oidc_token = "${get_env("ARM_OIDC_TOKEN", "")}"
      client_id = "${get_env("ARM_CLIENT_ID", "")}"
      
      # Skip provider registration for faster deployments
      skip_provider_registration = false
      
      # Enhanced networking features
      partner_id = "00000000-0000-0000-0000-000000000000"  # Microsoft Partner ID if applicable
      
      # Disable certain validations for faster operations
      disable_correlation_request_id = false
      disable_terraform_partner_id = false
    }
    
    # Provider for Azure AD operations (v3.x syntax)
    provider "azuread" {
      tenant_id = "${local.tenant_id}"
      client_id = "${get_env("ARM_CLIENT_ID", "")}"
      use_oidc = true
      oidc_token = "${get_env("ARM_OIDC_TOKEN", "")}"
      use_cli = false
      use_msi = false
    }
    
    # Provider for Azure Resource Manager Stack operations
    provider "azapi" {
      subscription_id = "${local.subscription_id}"
      tenant_id = "${local.tenant_id}"
      client_id = "${get_env("ARM_CLIENT_ID", "")}"
      use_oidc = true
      oidc_token = "${get_env("ARM_OIDC_TOKEN", "")}"
    }
  EOF
}

# =============================================================================
# VERSION CONSTRAINTS
# =============================================================================
generate "versions" {
  path = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<-EOF
    terraform {
      required_version = ">= 1.9.0, < 2.0.0"
      
      required_providers {
        ${local.cloud_provider == "aws" ? <<-PROVIDERS
        aws = {
          source = "hashicorp/aws"
          version = "~> 5.67"
        }
        PROVIDERS
        : local.cloud_provider == "gcp" ? <<-PROVIDERS
        google = {
          source = "hashicorp/google"
          version = "~> 6.8"
        }
        google-beta = {
          source = "hashicorp/google-beta"
          version = "~> 6.8"
        }
        PROVIDERS
        : <<-PROVIDERS
        azurerm = {
          source = "hashicorp/azurerm"
          version = "~> 4.3"
        }
        azuread = {
          source = "hashicorp/azuread"
          version = "~> 3.0"
        }
        azapi = {
          source = "azure/azapi"
          version = "~> 2.0"
        }
        PROVIDERS
        }
        
        # Common providers
        random = {
          source = "hashicorp/random"
          version = "~> 3.6"
        }
        null = {
          source = "hashicorp/null"
          version = "~> 3.2"
        }
        local = {
          source = "hashicorp/local"
          version = "~> 2.5"
        }
        tls = {
          source = "hashicorp/tls"
          version = "~> 4.0"
        }
        time = {
          source = "hashicorp/time"
          version = "~> 0.12"
        }
      }
    }
  EOF
}

# =============================================================================
# SECURITY HOOKS AND COMPLIANCE
# =============================================================================
terraform {
  # Pre-execution security scans
  before_hook "security_scan" {
    commands = ["plan", "apply"]
    execute = ["pwsh", "-Command", "${get_parent_terragrunt_dir()}/scripts/security-scan.ps1"]
    run_on_error = false
  }
  
  before_hook "tfsec" {
    commands = ["plan"]
    execute = ["tfsec", ".", "--config-file", "${get_parent_terragrunt_dir()}/.tfsec.yml", "--minimum-severity", "HIGH", "--format", "json"]
    run_on_error = false
  }
  
  before_hook "checkov" {
    commands = ["apply"]
    execute = ["checkov", "-d", ".", "--framework", "terraform", "--output", "json", "--output-file-path", "checkov-report.json"]
    run_on_error = false
  }
  
  before_hook "cost_estimate" {
    commands = ["plan"]
    execute = ["infracost", "breakdown", "--path", ".", "--format", "json", "--out-file", "infracost.json"]
    run_on_error = false
  }
  
  # Policy validation
  before_hook "opa_policy" {
    commands = ["apply"]
    execute = ["opa", "eval", "-d", "${get_parent_terragrunt_dir()}/policies", "-i", "plan.json", "data.terraform.deny[msg]"]
    run_on_error = false
  }
  
  # Audit logging
  after_hook "audit_log" {
    commands = ["apply", "destroy"]
    execute = ["pwsh", "-Command", "${get_parent_terragrunt_dir()}/scripts/audit-log.ps1", 
               "-TerragruntDir", "${get_terragrunt_dir()}", 
               "-User", "${get_env("USERNAME", "terraform")}",
               "-RunId", "${get_env("GITHUB_RUN_ID", "local")}"]
    run_on_error = true
  }
  
  # Backup state before destroy
  before_hook "backup_state" {
    commands = ["destroy"]
    execute = ["pwsh", "-Command", "${get_parent_terragrunt_dir()}/scripts/backup-state.ps1"]
    run_on_error = false
  }
  
  # Drift detection
  after_hook "drift_detection" {
    commands = ["apply"]
    execute = ["pwsh", "-Command", "${get_parent_terragrunt_dir()}/scripts/detect-drift.ps1"]
    run_on_error = false
  }
}

# =============================================================================
# TERRAFORM EXTRA ARGUMENTS
# =============================================================================
terraform {
  extra_arguments "common_vars" {
    commands = get_terraform_commands_that_need_vars()
    
    required_var_files = [
      "${get_parent_terragrunt_dir()}/common.tfvars"
    ]
    
    optional_var_files = [
      "${get_parent_terragrunt_dir()}/${local.environment}.tfvars",
      "${get_terragrunt_dir()}/local.tfvars"
    ]
  }
  
  extra_arguments "parallelism" {
    commands = ["apply", "plan", "destroy"]
    arguments = ["-parallelism=10"]
  }
  
  extra_arguments "retry" {
    commands = ["apply", "destroy"]
    arguments = ["-auto-approve=false"]
    env_vars = {
      TF_MAX_RETRIES = "3"
    }
  }
  
  extra_arguments "no_color" {
    commands = get_terraform_commands_that_need_vars()
    arguments = ["-no-color"]
    env_vars = {
      TF_IN_AUTOMATION = "true"
    }
  }
}

# =============================================================================
# ERROR HANDLING AND RETRY CONFIGURATION
# =============================================================================
terraform {
  error_hook "on_error" {
    commands = ["apply", "destroy"]
    execute = ["pwsh", "-Command", "${get_parent_terragrunt_dir()}/scripts/on-error.ps1", 
               "-ErrorType", "terraform_error",
               "-TerragruntDir", "${get_terragrunt_dir()}"]
    on_errors = [
      ".*Error creating.*",
      ".*Error updating.*",
      ".*Error deleting.*",
      ".*Error reading.*",
      ".*timeout.*",
      ".*connection refused.*"
    ]
  }
}

# Retry configuration
retry_max_attempts = 3
retry_sleep_interval_sec = 5

# Prevent destroy for critical resources in production
prevent_destroy = local.environment == "prod" ? true : false
