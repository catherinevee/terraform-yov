
variable "vpc_cidr" {
  description = "VPC CIDR block for internal access"
  type        = string
  default     = "10.0.0.0/16"
}
# =============================================================================
# DEVELOPMENT VPC DEPLOYMENT - US-EAST-1
# =============================================================================
# Cost-optimized VPC for development environment

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
  
  # Development VPC CIDR (use a different range than production)
  vpc_cidr = "10.50.0.0/16"  # Different from production 10.30.0.0/16
  
  # Development availability zones (cost-optimized - using 2 AZs instead of 3)
  availability_zones = ["us-east-1a", "us-east-1b"]  # Use first 2 AZs
}

# Module source from Terraform Registry
terraform {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-vpc.git?ref=v5.8.1"
}

# Development-specific VPC inputs
inputs = {
  # VPC basic configuration
  name = "dev-use1-vpc"
  cidr = local.vpc_cidr

  # Availability zones (2 for cost optimization)
  azs = local.availability_zones

  # Subnets (smaller allocations for development)
  private_subnets  = ["10.50.2.0/24", "10.50.3.0/24"]
  public_subnets   = ["10.50.1.0/26", "10.50.1.64/26"]
  database_subnets = ["10.50.4.0/26", "10.50.4.64/26"]

  # NAT Gateway configuration (cost-optimized)
  enable_nat_gateway     = true
  single_nat_gateway     = true   # Single NAT for cost savings
  one_nat_gateway_per_az = false  # Override production setting

  # DNS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Flow logs (enabled for security monitoring)
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_max_aggregation_interval    = 60

  # Default security group - restrictive
  manage_default_security_group = true
  default_security_group_ingress = []  # No inbound by default
  default_security_group_egress = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = [var.vpc_cidr]
    }
  ]

  # Network ACLs - basic security for dev
  manage_default_network_acl = true
  default_network_acl_ingress = [
    {
      rule_no    = 100
      protocol   = "-1"
      rule_action = "allow"
      cidr_block = local.vpc_cidr
    },
    {
      rule_no    = 110
      protocol   = "tcp"
      rule_action = "allow"
      from_port  = 80
      to_port    = 80
      cidr_block = "0.0.0.0/0"
    },
    {
      rule_no    = 120
      protocol   = "tcp"
      rule_action = "allow"
      from_port  = 443
      to_port    = 443
      cidr_block = "0.0.0.0/0"
    }
  ]

  default_network_acl_egress = [
    {
      rule_no    = 100
      protocol   = "-1"
      rule_action = "allow"
      cidr_block = "0.0.0.0/0"
    }
  ]

  # VPC endpoints for security
  enable_s3_endpoint       = true
  enable_dynamodb_endpoint = true  # Enable for security

  # Default tags (RDS-compatible with security compliance)
  tags = {
    Name               = "dev-use1-vpc"
    Environment        = "dev"
    Region             = "us-east-1"
    ManagedBy          = "terragrunt"
    Terraform          = "true"
    Component          = "vpc"
    CostCenter         = "development"
    CostOptimized      = "true"
    AutoShutdown       = "enabled"
    EnvironmentType    = "development"
    SecurityCompliant  = "true"
    FlowLogsEnabled    = "true"
    SecurityAudit      = "2024"
  }

  # Subnet tags
  private_subnet_tags = {
    Name = "dev-use1-private"
    Tier = "private"
    "kubernetes.io/cluster/dev-use1-eks" = "owned"
    SubnetTier = "application"
  }

  public_subnet_tags = {
    Name = "dev-use1-public"  
    Tier = "public"
    "kubernetes.io/cluster/dev-use1-eks" = "owned"
    SubnetTier = "web"
  }

  database_subnet_tags = {
    Name = "dev-use1-database"
    Tier = "database"
    DatabaseTier = "development"
  }
}
