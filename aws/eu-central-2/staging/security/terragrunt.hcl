# =============================================================================
# STAGING SECURITY CONFIGURATION
# =============================================================================
# Security resources for eu-central-2 staging environment

# Include the root configuration
include "root" {
  path   = find_in_parent_folders("terragrunt.hcl")
  expose = true
}

locals {
  # Read configuration files directly
  region_config = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_config    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  account_config = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  # Staging-specific overrides
  environment = "staging"
  region      = "eu-central-2"
  
  # Get VPC CIDR from networking
  vpc_cidr = local.region_config.locals.regional_networking.vpc_cidrs.staging  # 10.60.0.0/16
}

# Use local Terraform configuration
terraform {
  source = "."
}

# Staging-specific security inputs (production-like but with staging access)
inputs = {
  # VPC configuration (from networking dependency)
  vpc_id = dependency.networking.outputs.vpc_id
  
  # Staging-specific VPC CIDR
  vpc_cidr = local.vpc_cidr

  # Environment tags
  tags = merge(
    local.env_config.locals.environment_tags,
    {
      Name        = "staging-euc2-security"
      Environment = "staging"
      Region      = "eu-central-2"
      ManagedBy   = "terragrunt"
      Terraform   = "true"
      Component   = "security"
      CostCenter  = "staging"
      TestingTier = "security"
    }
  )
}

# Dependencies
dependency "networking" {
  config_path = "../networking/vpc"
  
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    vpc_id              = "vpc-mock12345"
    vpc_cidr_block      = "10.60.0.0/16"
    public_subnet_ids   = ["subnet-mock1", "subnet-mock2", "subnet-mock3"]
    private_subnet_ids  = ["subnet-mock4", "subnet-mock5", "subnet-mock6"]
    database_subnet_ids = ["subnet-mock7", "subnet-mock8", "subnet-mock9"]
    database_subnet_group = "staging-euc2-vpc"
  }
}
