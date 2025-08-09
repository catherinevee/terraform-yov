# =============================================================================
# STAGING SECURITY CONFIGURATION - US-EAST-1
# =============================================================================
# Comprehensive security resources for us-east-1 staging environment

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
  region      = "us-east-1"
  
  # Get VPC CIDR from regional configuration
  vpc_cidr = local.region_config.locals.regional_networking.vpc_cidrs.staging  # 10.20.0.0/16
}

# Generate comprehensive security groups for staging
generate "security_groups" {
  path      = "security_groups.tf"
  if_exists = "overwrite"
  contents  = <<EOF
# Web Tier Security Group - Enhanced for staging
module "web_tier_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "staging-use1-web-tier"
  description = "Security group for web tier (ALB, Web servers) - Staging"
  vpc_id      = var.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules = ["http-80-tcp", "https-443-tcp"]
  
  egress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.app_tier_sg.security_group_id
    },
    {
      rule                     = "https-443-tcp"
      source_security_group_id = module.app_tier_sg.security_group_id
    }
  ]

  egress_cidr_blocks = [var.vpc_cidr]
  egress_rules = ["https-443-tcp"]

  tags = merge(var.tags, {
    Name = "staging-use1-web-tier-sg"
    Tier = "web"
    SecurityLevel = "enhanced"
  })
}

# Application Tier Security Group - Enhanced for staging
module "app_tier_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "staging-use1-app-tier"
  description = "Security group for application tier - Staging"
  vpc_id      = var.vpc_id

  ingress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.web_tier_sg.security_group_id
    },
    {
      rule                     = "https-443-tcp"
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
    },
    {
      rule                     = "redis-tcp"
      source_security_group_id = module.cache_sg.security_group_id
    }
  ]

  egress_cidr_blocks = [var.vpc_cidr]
  egress_rules = ["https-443-tcp", "http-80-tcp"]

  tags = merge(var.tags, {
    Name = "staging-use1-app-tier-sg"
    Tier = "application"
    SecurityLevel = "enhanced"
  })
}

# Database Tier Security Group - Enhanced for staging
module "database_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "staging-use1-database-tier"
  description = "Security group for database tier - Staging"
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
    Name = "staging-use1-database-tier-sg"
    Tier = "database"
    SecurityLevel = "high"
  })
}

# Bastion Host Security Group - Restricted for staging
module "bastion_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "staging-use1-bastion"
  description = "Security group for bastion hosts - Staging"
  vpc_id      = var.vpc_id

  # More restrictive SSH access for staging
  ingress_with_cidr_blocks = [
    {
      rule        = "ssh-tcp"
      cidr_blocks = "10.0.0.0/8"  # Only from private networks
    }
  ]

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

  egress_cidr_blocks = [var.vpc_cidr]
  egress_rules = ["https-443-tcp"]

  tags = merge(var.tags, {
    Name = "staging-use1-bastion-sg"
    Tier = "management"
    SecurityLevel = "high"
  })
}

# Cache Security Group - Enhanced for staging
module "cache_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "staging-use1-cache-tier"
  description = "Security group for cache tier (Redis) - Staging"
  vpc_id      = var.vpc_id

  ingress_with_source_security_group_id = [
    {
      rule                     = "redis-tcp"
      source_security_group_id = module.app_tier_sg.security_group_id
    }
  ]

  tags = merge(var.tags, {
    Name = "staging-use1-cache-tier-sg"
    Tier = "cache"
    SecurityLevel = "medium"
  })
}

# Monitoring Security Group
module "monitoring_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "staging-use1-monitoring"
  description = "Security group for monitoring services - Staging"
  vpc_id      = var.vpc_id

  ingress_with_source_security_group_id = [
    {
      from_port                = 9090
      to_port                  = 9090
      protocol                 = "tcp"
      source_security_group_id = module.app_tier_sg.security_group_id
    },
    {
      from_port                = 3000
      to_port                  = 3000
      protocol                 = "tcp"
      source_security_group_id = module.web_tier_sg.security_group_id
    }
  ]

  tags = merge(var.tags, {
    Name = "staging-use1-monitoring-sg"
    Tier = "monitoring"
    SecurityLevel = "medium"
  })
}
EOF
}

# Generate enhanced KMS keys for staging
generate "kms_keys" {
  path      = "kms_keys.tf"
  if_exists = "overwrite"
  contents  = <<EOF
# KMS Key for RDS Encryption - Enhanced for staging
resource "aws_kms_key" "rds" {
  description              = "KMS key for RDS encryption in staging"
  enable_key_rotation      = true
  rotation_period_in_days  = 365
  deletion_window_in_days  = 10  # Longer for staging safety

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::$${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow RDS Service"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = "staging-use1-rds-kms"
    Service = "rds"
    SecurityLevel = "high"
  })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/staging-use1-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# KMS Key for S3 Encryption - Enhanced for staging
resource "aws_kms_key" "s3" {
  description              = "KMS key for S3 encryption in staging"
  enable_key_rotation      = true
  rotation_period_in_days  = 365
  deletion_window_in_days  = 10

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::$${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow S3 Service"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = "staging-use1-s3-kms"
    Service = "s3"
    SecurityLevel = "high"
  })
}

resource "aws_kms_alias" "s3" {
  name          = "alias/staging-use1-s3"
  target_key_id = aws_kms_key.s3.key_id
}

# KMS Key for EBS Encryption
resource "aws_kms_key" "ebs" {
  description              = "KMS key for EBS encryption in staging"
  enable_key_rotation      = true
  rotation_period_in_days  = 365
  deletion_window_in_days  = 10

  tags = merge(var.tags, {
    Name    = "staging-use1-ebs-kms"
    Service = "ebs"
    SecurityLevel = "high"
  })
}

resource "aws_kms_alias" "ebs" {
  name          = "alias/staging-use1-ebs"
  target_key_id = aws_kms_key.ebs.key_id
}

# KMS Key for Secrets Manager
resource "aws_kms_key" "secrets" {
  description              = "KMS key for Secrets Manager in staging"
  enable_key_rotation      = true
  rotation_period_in_days  = 365
  deletion_window_in_days  = 10

  tags = merge(var.tags, {
    Name    = "staging-use1-secrets-kms"
    Service = "secrets-manager"
    SecurityLevel = "critical"
  })
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/staging-use1-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}
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
    monitoring    = module.monitoring_sg.security_group_id
  }
}

output "kms_key_ids" {
  description = "Map of KMS key IDs"
  value = {
    rds     = aws_kms_key.rds.id
    s3      = aws_kms_key.s3.id
    ebs     = aws_kms_key.ebs.id
    secrets = aws_kms_key.secrets.id
  }
}

output "kms_key_arns" {
  description = "Map of KMS key ARNs"
  value = {
    rds     = aws_kms_key.rds.arn
    s3      = aws_kms_key.s3.arn
    ebs     = aws_kms_key.ebs.arn
    secrets = aws_kms_key.secrets.arn
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

variable "vpc_cidr" {
  description = "VPC CIDR block for security group rules"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
EOF
}

# Use local Terraform configuration
terraform {
  source = "."
}

# Staging-specific security inputs (production-like but with staging access)
inputs = {
  # VPC configuration (from networking dependency)
  vpc_id = dependency.vpc.outputs.vpc_id
  
  # Staging-specific VPC CIDR
  vpc_cidr = local.vpc_cidr

  # Environment tags
  tags = merge(
    local.env_config.locals.environment_tags,
    {
      Name               = "staging-use1-security"
      Environment        = "staging"
      Region             = "us-east-1"
      ManagedBy          = "terragrunt"
      Terraform          = "true"
      Component          = "security"
      CostCenter         = "staging"
      TestingTier        = "security"
      SecurityCompliant  = "true"
      SecurityEnhanced   = "true"
      SecurityAudit      = "2024"
    }
  )
}

# Dependencies
dependency "vpc" {
  config_path = "../networking/vpc"
  
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    vpc_id              = "vpc-mock12345"
    vpc_cidr_block      = "10.20.0.0/16"
    public_subnet_ids   = ["subnet-mock1", "subnet-mock2", "subnet-mock3"]
    private_subnet_ids  = ["subnet-mock4", "subnet-mock5", "subnet-mock6"]
    database_subnet_ids = ["subnet-mock7", "subnet-mock8", "subnet-mock9"]
    database_subnet_group = "staging-use1-vpc"
  }
}
