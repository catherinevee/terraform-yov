# =============================================================================
# SECURITY GROUPS - EU-WEST-1 DEVELOPMENT
# =============================================================================
# This configuration creates security groups for development environment
# using terraform registry modules with development-appropriate security

# Include environment and region configurations
include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = find_in_parent_folders("env.hcl")
}

include "region" {
  path = find_in_parent_folders("region.hcl")
}

# Local variables
locals {
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  
  environment = local.env_vars.locals.environment
  regional_networking = local.region_vars.locals.regional_networking
  vpc_config = {
    cidr_block = local.regional_networking.vpc_cidrs[local.environment]
  }
}

# Dependency on VPC
dependency "vpc" {
  config_path = "../networking/vpc"
  mock_outputs = {
    vpc_id = "vpc-mock-id"
  }
}

# Terraform configuration
terraform {
  source = "tfr:///terraform-aws-modules/security-group/aws?version=5.1.2"
}

# Generate security groups configuration
generate "security_groups" {
  path      = "security_groups.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
# =============================================================================
# MULTIPLE SECURITY GROUPS FOR DEVELOPMENT ENVIRONMENT
# =============================================================================

# Web Tier Security Group (ALB/ELB)
module "web_tier_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "5.1.2"

  name        = "web-tier-sg-$${local.environment}-eu-west-1"
  description = "Security group for web tier (ALB/ELB) - Development"
  vpc_id      = "$${var.vpc_id}"

  # Ingress rules - HTTP/HTTPS from internet
  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules = ["http-80-tcp", "https-443-tcp"]
  
  # Custom ingress for development
  ingress_with_cidr_blocks = [
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      description = "Development server port"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  # Egress to application tier
  egress_with_source_security_group_id = [
    {
      from_port                = 8080
      to_port                  = 8080
      protocol                 = "tcp"
      description              = "To application tier"
      source_security_group_id = module.app_tier_sg.security_group_id
    }
  ]

  tags = merge(
    local.environment_tags,
    local.region_tags,
    {
      Name = "web-tier-sg-$${local.environment}-eu-west-1"
      Tier = "web"
      Type = "web-security-group"
    }
  )
}

# Application Tier Security Group
module "app_tier_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "5.1.2"

  name        = "app-tier-sg-$${local.environment}-eu-west-1"
  description = "Security group for application tier - Development"
  vpc_id      = "$${var.vpc_id}"

  # Ingress from web tier
  ingress_with_source_security_group_id = [
    {
      from_port                = 8080
      to_port                  = 8080
      protocol                 = "tcp"
      description              = "From web tier"
      source_security_group_id = module.web_tier_sg.security_group_id
    },
    {
      from_port                = 22
      to_port                  = 22
      protocol                 = "tcp"
      description              = "SSH from bastion (development)"
      source_security_group_id = module.bastion_sg.security_group_id
    }
  ]

  # Egress to database tier
  egress_with_source_security_group_id = [
    {
      from_port                = 5432
      to_port                  = 5432
      protocol                 = "tcp"
      description              = "To PostgreSQL database"
      source_security_group_id = module.database_sg.security_group_id
    }
  ]

  # Egress for package updates and internet access
  egress_cidr_blocks = [var.vpc_cidr]
  egress_rules = ["https-443-tcp", "http-80-tcp"]

  tags = merge(
    local.environment_tags,
    local.region_tags,
    {
      Name = "app-tier-sg-$${local.environment}-eu-west-1"
      Tier = "application"
      Type = "app-security-group"
    }
  )
}

# Database Security Group
module "database_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "5.1.2"

  name        = "database-sg-$${local.environment}-eu-west-1"
  description = "Security group for database tier - Development"
  vpc_id      = "$${var.vpc_id}"

  # Ingress from application tier
  ingress_with_source_security_group_id = [
    {
      from_port                = 5432
      to_port                  = 5432
      protocol                 = "tcp"
      description              = "PostgreSQL from application tier"
      source_security_group_id = module.app_tier_sg.security_group_id
    },
    {
      from_port                = 5432
      to_port                  = 5432
      protocol                 = "tcp"
      description              = "PostgreSQL from bastion (development)"
      source_security_group_id = module.bastion_sg.security_group_id
    }
  ]

  # No egress rules - database should not initiate outbound connections
  egress_rules = []

  tags = merge(
    local.environment_tags,
    local.region_tags,
    {
      Name = "database-sg-$${local.environment}-eu-west-1"
      Tier = "database"
      Type = "database-security-group"
    }
  )
}

# Bastion Host Security Group (for development access)
module "bastion_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "5.1.2"

  name        = "bastion-sg-$${local.environment}-eu-west-1"
  description = "Security group for bastion host - Development"
  vpc_id      = "$${var.vpc_id}"

  # SSH access from specific IPs (development team)
  ingress_cidr_blocks = [var.vpc_cidr]  # Restrict this in production
  ingress_rules = ["ssh-tcp"]

  # Egress to private subnets
  egress_cidr_blocks = ["$${local.vpc_config.cidr_block}"]
  egress_rules = ["ssh-tcp"]

  # Internet access for updates
  egress_with_cidr_blocks = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "HTTPS for updates"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "HTTP for updates"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  tags = merge(
    local.environment_tags,
    local.region_tags,
    {
      Name = "bastion-sg-$${local.environment}-eu-west-1"
      Tier = "management"
      Type = "bastion-security-group"
      Purpose = "development-access"
    }
  )
}

# EKS Security Group (for Kubernetes)
module "eks_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "5.1.2"

  name        = "eks-sg-$${local.environment}-eu-west-1"
  description = "Security group for EKS cluster - Development"
  vpc_id      = "$${var.vpc_id}"

  # EKS cluster communication
  ingress_with_source_security_group_id = [
    {
      from_port                = 443
      to_port                  = 443
      protocol                 = "tcp"
      description              = "EKS cluster API"
      source_security_group_id = module.app_tier_sg.security_group_id
    }
  ]

  # Ingress from within cluster
  ingress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 65535
      protocol    = "tcp"
      description = "Cluster internal communication"
      cidr_blocks = local.vpc_config.cidr_block
    }
  ]

  # Egress for cluster operations
  egress_cidr_blocks = [var.vpc_cidr]
  egress_rules = ["all-all"]

  tags = merge(
    local.environment_tags,
    local.region_tags,
    {
      Name = "eks-sg-$${local.environment}-eu-west-1"
      Tier = "container"
      Type = "eks-security-group"
      KubernetesCluster = "eks-$${local.environment}-eu-west-1"
    }
  )
}

# Cache Security Group (for ElastiCache)
module "cache_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "5.1.2"

  name        = "cache-sg-$${local.environment}-eu-west-1"
  description = "Security group for ElastiCache - Development"
  vpc_id      = "$${var.vpc_id}"

  # Redis access from application tier
  ingress_with_source_security_group_id = [
    {
      from_port                = 6379
      to_port                  = 6379
      protocol                 = "tcp"
      description              = "Redis from application tier"
      source_security_group_id = module.app_tier_sg.security_group_id
    }
  ]

  # No egress rules - cache should not initiate outbound connections
  egress_rules = []

  tags = merge(
    local.environment_tags,
    local.region_tags,
    {
      Name = "cache-sg-$${local.environment}-eu-west-1"
      Tier = "cache"
      Type = "cache-security-group"
    }
  )
}

# Local variables for use in modules
locals {
  environment_tags = $${jsonencode(local.env_vars.locals.environment_tags)}
  region_tags = $${jsonencode(local.region_vars.locals.region_tags)}
  vpc_config = $${jsonencode(local.vpc_config)}
}

# Variables
variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
}
variable "vpc_cidr" {
  description = "VPC CIDR block for internal access"
  type        = string
  default     = "10.0.0.0/16"
}

# Outputs
output "web_tier_security_group_id" {
  description = "ID of the web tier security group"
  value       = module.web_tier_sg.security_group_id
}

output "app_tier_security_group_id" {
  description = "ID of the application tier security group"
  value       = module.app_tier_sg.security_group_id
}

output "database_security_group_id" {
  description = "ID of the database security group"
  value       = module.database_sg.security_group_id
}

output "bastion_security_group_id" {
  description = "ID of the bastion security group"
  value       = module.bastion_sg.security_group_id
}

output "eks_security_group_id" {
  description = "ID of the EKS security group"
  value       = module.eks_sg.security_group_id
}

output "cache_security_group_id" {
  description = "ID of the cache security group"
  value       = module.cache_sg.security_group_id
}
EOF
}

# Input variables
inputs = {
  vpc_id = dependency.vpc.outputs.vpc_id
}
