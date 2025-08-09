# =============================================================================
# VPC INFRASTRUCTURE - EU-WEST-1 DEVELOPMENT
# =============================================================================
# This configuration creates a VPC infrastructure for development environment
# using terraform registry modules with cost-optimized settings

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

# Local variables combining configurations
locals {
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  
  environment = local.env_vars.locals.environment
  regional_networking = local.region_vars.locals.regional_networking
  vpc_config = {
    cidr_block       = local.regional_networking.vpc_cidrs[local.environment]
    public_subnets   = local.regional_networking.subnet_strategy.public_subnets[local.environment]
    private_subnets  = local.regional_networking.subnet_strategy.private_subnets[local.environment]
    database_subnets = local.regional_networking.subnet_strategy.database_subnets[local.environment]
  }
  availability_zones = local.region_vars.locals.availability_zones
}

# Terraform configuration
terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws?version=5.8.1"
}

# Input variables for the VPC module
inputs = {
  # Basic VPC configuration
  name = "vpc-${local.environment}-eu-west-1"
  cidr = local.vpc_config.cidr_block

  # Availability zones - use 2 AZs for development (cost optimization)
  azs = slice(local.availability_zones, 0, 2)

  # Subnets configuration - simplified for development
  private_subnets = local.vpc_config.private_subnets
  public_subnets  = local.vpc_config.public_subnets
  
  # Database subnets for RDS
  database_subnets = local.vpc_config.database_subnets
  create_database_subnet_group = true
  create_database_subnet_route_table = true

  # Internet connectivity
  enable_nat_gateway = true
  single_nat_gateway = true  # Cost optimization for dev
  enable_vpn_gateway = false # Not needed for dev

  # DNS configuration
  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC Flow Logs - basic for development
  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true
  flow_log_destination_type            = "cloud-watch-logs"
  flow_log_cloudwatch_log_group_retention_in_days = 7  # Short retention for dev

  # DHCP options
  enable_dhcp_options              = true
  dhcp_options_domain_name         = "eu-west-1.compute.internal"
  dhcp_options_domain_name_servers = ["AmazonProvidedDNS"]

  # Default security group
  manage_default_security_group = true
  default_security_group_ingress = []
  default_security_group_egress = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  # Network ACLs - basic for development
  manage_default_network_acl = true
  default_network_acl_ingress = [
    {
      rule_no    = 100
      action     = "allow"
      from_port  = 0
      to_port    = 0
      protocol   = "-1"
      cidr_block = "0.0.0.0/0"
    }
  ]
  default_network_acl_egress = [
    {
      rule_no    = 100
      action     = "allow"
      from_port  = 0
      to_port    = 0
      protocol   = "-1"
      cidr_block = "0.0.0.0/0"
    }
  ]

  # Public subnet configuration
  map_public_ip_on_launch = true

  # Route table configuration
  create_igw = true

  # Tags
  tags = merge(
    local.env_vars.locals.environment_tags,
    local.region_vars.locals.region_tags,
    {
      Name                = "vpc-${local.environment}-eu-west-1"
      Component          = "networking"
      Terragrunt         = "true"
      TerraformModule    = "terraform-aws-modules/vpc/aws"
      ModuleVersion      = "5.8.1"
      VPCType           = "development"
      CostOptimized     = "true"
      SingleNATGateway  = "true"
      FlowLogsRetention = "7-days"
    }
  )

  # Subnet tags
  public_subnet_tags = {
    Name = "public-subnet-${local.environment}-eu-west-1"
    Type = "public"
    Tier = "web"
  }

  private_subnet_tags = {
    Name = "private-subnet-${local.environment}-eu-west-1"
    Type = "private"
    Tier = "application"
  }

  database_subnet_tags = {
    Name = "database-subnet-${local.environment}-eu-west-1"
    Type = "database"
    Tier = "data"
  }

  # VPC endpoint tags
  vpc_endpoint_tags = {
    Name = "vpc-endpoint-${local.environment}-eu-west-1"
    Type = "vpc-endpoint"
  }

  # Internet gateway tags
  igw_tags = {
    Name = "igw-${local.environment}-eu-west-1"
    Type = "internet-gateway"
  }

  # NAT gateway tags
  nat_gateway_tags = {
    Name = "nat-gateway-${local.environment}-eu-west-1"
    Type = "nat-gateway"
    Count = "single"  # Cost optimization indicator
  }

  # Route table tags
  public_route_table_tags = {
    Name = "rt-public-${local.environment}-eu-west-1"
    Type = "public-route-table"
  }

  private_route_table_tags = {
    Name = "rt-private-${local.environment}-eu-west-1"
    Type = "private-route-table"
  }

  database_route_table_tags = {
    Name = "rt-database-${local.environment}-eu-west-1"
    Type = "database-route-table"
  }
}
