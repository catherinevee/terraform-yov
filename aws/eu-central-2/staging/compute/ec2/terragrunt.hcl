# =============================================================================
# STAGING EC2 COMPUTE CONFIGURATION - EU-CENTRAL-2
# =============================================================================
# Production-like EC2 instances for staging environment testing

# Include root configuration (backend, providers)
include "root" {
  path   = find_in_parent_folders("terragrunt.hcl")
  expose = true
}

locals {
  # Read configuration files directly
  region_config = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_config    = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  # Staging-specific overrides
  environment = "staging"
  region      = "eu-central-2"
}

# Use EC2 module
terraform {
  source = "tfr:///terraform-aws-modules/ec2-instance/aws?version=5.6.1"
}

# Staging-specific EC2 inputs
inputs = {
  # Instance configuration - production-like but smaller
  name = "staging-euc2-web"
  
  ami                    = "ami-0c02fb55956c7d316"  # Amazon Linux 2023 AMI
  instance_type          = "t3.large"               # Production-like but cost-optimized
  key_name               = "staging-euc2-keypair"   # Create this separately
  monitoring             = true                     # Enable detailed monitoring
  vpc_security_group_ids = [dependency.security.outputs.web_tier_security_group_id]
  subnet_id              = dependency.vpc.outputs.private_subnet_ids[0]
  
  # Root volume
  root_block_device = [
    {
      volume_type = "gp3"
      volume_size = 50
      encrypted   = true
      tags = {
        Name = "staging-euc2-web-root"
      }
    }
  ]
  
  # User data for staging configuration
  user_data = base64encode(templatefile("${get_terragrunt_dir()}/user-data.sh", {
    environment = "staging"
    region      = "eu-central-2"
  }))
  
  # Tags
  tags = {
    Name              = "staging-euc2-web"
    Environment       = "staging"
    Region            = "eu-central-2"
    ManagedBy         = "terragrunt"
    Terraform         = "true"
    Component         = "compute"
    Tier             = "web"
    CostCenter       = "staging"
    EnvironmentType  = "staging"
    TestingTier      = "compute"
    ProductionLike   = "true"
    AutoShutdown     = "disabled"  # Keep running for continuous testing
  }
}

# Dependencies
dependency "vpc" {
  config_path = "../../networking/vpc"
  
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    vpc_id               = "vpc-mock12345"
    private_subnet_ids   = ["subnet-mock4", "subnet-mock5", "subnet-mock6"]
    public_subnet_ids    = ["subnet-mock1", "subnet-mock2", "subnet-mock3"]
  }
}

dependency "security" {
  config_path = "../../security"
  
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    web_tier_security_group_id = "sg-mock1"
    security_group_ids = {
      web_tier      = "sg-mock1"
      app_tier      = "sg-mock2"
      database_tier = "sg-mock3"
    }
  }
}
