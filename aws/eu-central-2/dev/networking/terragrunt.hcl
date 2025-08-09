# =============================================================================
# DEVELOPMENT VPC DEPLOYMENT
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
  region      = "eu-central-2"
  
  # Get VPC CIDR from regional configuration
  vpc_cidr = local.region_config.locals.regional_networking.vpc_cidrs.dev  # 10.40.0.0/16
  
  # Development availability zones (cost-optimized - using 2 AZs instead of 3)
  availability_zones = slice(local.region_config.locals.availability_zones, 0, 2)  # Use first 2 AZs
}

# Module source from Terraform Registry
terraform {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-vpc.git?ref=v5.8.1"
}

# Development-specific VPC inputs
inputs = {
  # VPC basic configuration
  name = "dev-euc2-vpc"
  cidr = local.vpc_cidr

  # Availability zones (2 for cost optimization)
  azs = local.availability_zones

  # Subnets (smaller allocations for development)
  private_subnets  = ["10.40.2.0/24", "10.40.3.0/24"]
  public_subnets   = ["10.40.1.0/26", "10.40.1.64/26"]
  database_subnets = ["10.40.4.0/26", "10.40.4.64/26"]

  # NAT Gateway configuration (cost-optimized)
  enable_nat_gateway     = true
  single_nat_gateway     = true   # Single NAT for cost savings
  one_nat_gateway_per_az = false  # Override production setting

  # DNS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Flow logs (disabled for cost)
  enable_flow_log = false

  # VPC endpoints (minimal for cost)
  enable_s3_endpoint       = true   # Free tier
  enable_dynamodb_endpoint = false  # Disabled for cost

  # Default tags
  tags = merge(
    local.env_config.locals.environment_tags,
    {
      Name        = "dev-euc2-vpc"
      Environment = "dev"
      Region      = "eu-central-2"
      ManagedBy   = "terragrunt"
      Terraform   = "true"
      Component   = "vpc"
      CostCenter  = "development"
    }
  )

  # Subnet tags
  private_subnet_tags = {
    Name = "dev-euc2-private"
    Tier = "private"
    "kubernetes.io/cluster/dev-euc2-eks" = "owned"
    SubnetTier = "application"
  }

  public_subnet_tags = {
    Name = "dev-euc2-public"  
    Tier = "public"
    "kubernetes.io/cluster/dev-euc2-eks" = "owned"
    SubnetTier = "web"
  }

  database_subnet_tags = {
    Name = "dev-euc2-database"
    Tier = "database"
    DatabaseTier = "development"
  }
}
