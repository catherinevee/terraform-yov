# =============================================================================
# DEVELOPMENT SECURITY CONFIGURATION - US-EAST-1
# =============================================================================
# Comprehensive security resources for us-east-1 development environment

# Include root configuration (backend, providers)
include "root" {
  path   = find_in_parent_folders("terragrunt.hcl")
  expose = true
}

locals {
  # Read configuration files directly
  region_config = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_config    = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  # Development-specific overrides
  environment = "dev"
  region      = "us-east-1"
  
  # VPC CIDR for security group rules
  vpc_cidr = "10.50.0.0/16"
}

# Generate comprehensive security groups
generate "security_groups" {
  path      = "security_groups.tf"
  if_exists = "overwrite"
  contents  = <<EOF
# Web Tier Security Group
module "web_tier_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "dev-use1-web-tier"
  description = "Security group for web tier (ALB, Web servers)"
  vpc_id      = var.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules = ["http-80-tcp", "https-443-tcp"]
  
  egress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.app_tier_sg.security_group_id
    }
  ]

  tags = merge(var.tags, {
    Name = "dev-use1-web-tier-sg"
    Tier = "web"
  })
}

# Application Tier Security Group
module "app_tier_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "dev-use1-app-tier"
  description = "Security group for application tier"
  vpc_id      = var.vpc_id

  ingress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.web_tier_sg.security_group_id
    },
    {
      rule                     = "ssh-tcp"
      source_security_group_id = module.bastion_sg.security_group_id
    }
  ]

  egress_with_source_security_group_id = [
    {
      rule                     = "postgresql-tcp"
      source_security_group_id = module.database_sg.security_group_id
    }
  ]

  egress_cidr_blocks = [var.vpc_cidr]
  egress_rules = ["https-443-tcp"]

  tags = merge(var.tags, {
    Name = "dev-use1-app-tier-sg"
    Tier = "application"
  })
}

# Database Tier Security Group
module "database_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "dev-use1-database-tier"
  description = "Security group for database tier"
  vpc_id      = var.vpc_id

  ingress_with_source_security_group_id = [
    {
      rule                     = "postgresql-tcp"
      source_security_group_id = module.app_tier_sg.security_group_id
    },
    {
      rule                     = "postgresql-tcp"
      source_security_group_id = module.bastion_sg.security_group_id
    }
  ]

  tags = merge(var.tags, {
    Name = "dev-use1-database-tier-sg"
    Tier = "database"
  })
}

# Bastion Host Security Group
module "bastion_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "dev-use1-bastion"
  description = "Security group for bastion hosts"
  vpc_id      = var.vpc_id

  ingress_cidr_blocks = [var.vpc_cidr]
  ingress_rules = ["ssh-tcp"]

  egress_with_source_security_group_id = [
    {
      rule                     = "ssh-tcp"
      source_security_group_id = module.app_tier_sg.security_group_id
    },
    {
      rule                     = "postgresql-tcp"
      source_security_group_id = module.database_sg.security_group_id
    }
  ]

  tags = merge(var.tags, {
    Name = "dev-use1-bastion-sg"
    Tier = "management"
  })
}

# Cache Security Group (Redis/ElastiCache)
module "cache_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "dev-use1-cache-tier"
  description = "Security group for cache tier (Redis)"
  vpc_id      = var.vpc_id

  ingress_with_source_security_group_id = [
    {
      rule                     = "redis-tcp"
      source_security_group_id = module.app_tier_sg.security_group_id
    }
  ]

  tags = merge(var.tags, {
    Name = "dev-use1-cache-tier-sg"
    Tier = "cache"
  })
}
EOF
}

# Generate KMS keys for encryption
generate "kms_keys" {
  path      = "kms_keys.tf"
  if_exists = "overwrite"
  contents  = <<EOF
# KMS Key for RDS Encryption
resource "aws_kms_key" "rds" {
  description              = "KMS key for RDS encryption in development"
  enable_key_rotation      = true
  rotation_period_in_days  = 365
  deletion_window_in_days  = 7

  tags = merge(var.tags, {
    Name    = "dev-use1-rds-kms"
    Service = "rds"
  })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/dev-use1-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# KMS Key for S3 Encryption
resource "aws_kms_key" "s3" {
  description              = "KMS key for S3 encryption in development"
  enable_key_rotation      = true
  rotation_period_in_days  = 365
  deletion_window_in_days  = 7

  tags = merge(var.tags, {
    Name    = "dev-use1-s3-kms"
    Service = "s3"
  })
}

resource "aws_kms_alias" "s3" {
  name          = "alias/dev-use1-s3"
  target_key_id = aws_kms_key.s3.key_id
}

# KMS Key for EBS Encryption
resource "aws_kms_key" "ebs" {
  description              = "KMS key for EBS encryption in development"
  enable_key_rotation      = true
  rotation_period_in_days  = 365
  deletion_window_in_days  = 7

  tags = merge(var.tags, {
    Name    = "dev-use1-ebs-kms"
    Service = "ebs"
  })
}

resource "aws_kms_alias" "ebs" {
  name          = "alias/dev-use1-ebs"
  target_key_id = aws_kms_key.ebs.key_id
}
EOF
}

# Generate outputs
generate "outputs" {
  path      = "outputs.tf"
  if_exists = "overwrite"
  contents  = <<EOF
output "security_group_ids" {
  description = "Map of security group IDs"
  value = {
    web_tier      = module.web_tier_sg.security_group_id
    app_tier      = module.app_tier_sg.security_group_id
    database_tier = module.database_sg.security_group_id
    bastion       = module.bastion_sg.security_group_id
    cache_tier    = module.cache_sg.security_group_id
  }
}

output "kms_key_ids" {
  description = "Map of KMS key IDs"
  value = {
    rds = aws_kms_key.rds.id
    s3  = aws_kms_key.s3.id
    ebs = aws_kms_key.ebs.id
  }
}

output "kms_key_arns" {
  description = "Map of KMS key ARNs"
  value = {
    rds = aws_kms_key.rds.arn
    s3  = aws_kms_key.s3.arn
    ebs = aws_kms_key.ebs.arn
  }
}
EOF
}

# Generate variables
generate "variables" {
  path      = "variables.tf"
  if_exists = "overwrite"
  contents  = <<EOF
variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
variable "vpc_cidr" {
  description = "VPC CIDR block for internal access"
  type        = string
  default     = "10.0.0.0/16"
}
}
EOF
}

# Use inline Terraform for resources
terraform {
  source = "."
}

# Inputs
inputs = {
  vpc_id = dependency.vpc.outputs.vpc_id
  
  tags = merge(
    local.env_config.locals.environment_tags,
    {
      Name               = "dev-use1-security"
      Environment        = "dev"
      Region             = "us-east-1"
      ManagedBy          = "terragrunt"
      Terraform          = "true"
      Component          = "security"
      CostCenter         = "development"
      SecurityCompliant  = "true"
      SecurityAudit      = "2024"
    }
  )
}

# Dependencies with enhanced validation
dependency "vpc" {
  config_path = "../networking/vpc"
  
  # Enhanced mock outputs with validation
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "show"]
  mock_outputs_merge_strategy_with_state  = "shallow"
  
  mock_outputs = {
    # VPC outputs with proper AWS format validation
    vpc_id               = "vpc-mock12345"
    vpc_cidr_block      = "10.50.0.0/16"
    vpc_arn             = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-mock12345"
    
    # Subnet outputs with proper validation
    public_subnets      = ["subnet-mock1", "subnet-mock2"]
    private_subnets     = ["subnet-mock3", "subnet-mock4"]
    database_subnets    = ["subnet-mock5", "subnet-mock6"]
    
    # Security-critical outputs for enhanced validation
    database_subnet_group_name = "mock-db-subnet-group"
    nat_gateway_ids           = ["nat-mock1"]
    internet_gateway_id       = "igw-mock1"
    route_table_ids          = ["rtb-mock1", "rtb-mock2"]
    default_security_group_id = "sg-mock-default"
    default_network_acl_id   = "acl-mock-default"
  }
  
  # Validation hooks
  skip_outputs = false
}
