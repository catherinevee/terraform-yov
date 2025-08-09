# =================# Local variables combining configurations
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
    intra_subnets    = local.regional_networking.subnet_strategy.intra_subnets[local.environment]
  }
  availability_zones = local.region_vars.locals.availability_zones
}===================================================
# VPC INFRASTRUCTURE - EU-WEST-1 PRODUCTION
# =============================================================================
# This configuration creates a VPC infrastructure for production environment
# using terraform registry modules with enterprise-grade features

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
  region_config = local.region_vars.locals.region_config
  vpc_config = local.region_config.vpc_cidrs[local.environment]
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

  # Availability zones - use all 3 AZs for full production deployment
  azs = local.availability_zones

  # Subnets configuration - comprehensive production setup
  private_subnets = local.vpc_config.private_subnets
  public_subnets  = local.vpc_config.public_subnets
  
  # Database subnets for RDS with full multi-AZ support
  database_subnets = local.vpc_config.database_subnets
  create_database_subnet_group = true
  create_database_subnet_route_table = true
  create_database_internet_gateway_route = false  # No internet for DB subnets
  create_database_nat_gateway_route = true        # NAT for outbound only

  # ElastiCache subnets for caching layer
  elasticache_subnets = local.vpc_config.elasticache_subnets
  create_elasticache_subnet_group = true
  create_elasticache_subnet_route_table = true

  # Redshift subnets for analytics (if needed)
  redshift_subnets = local.vpc_config.redshift_subnets
  create_redshift_subnet_group = true
  create_redshift_subnet_route_table = true

  # Internet connectivity - production NAT gateway configuration
  enable_nat_gateway = true
  one_nat_gateway_per_az = true  # Full HA across all AZs
  enable_vpn_gateway = true      # For hybrid connectivity

  # DNS configuration
  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC Flow Logs - comprehensive logging for production
  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true
  flow_log_destination_type            = "cloud-watch-logs"
  flow_log_cloudwatch_log_group_retention_in_days = 365  # Long-term retention
  flow_log_traffic_type                = "ALL"           # Capture all traffic
  flow_log_log_format                  = "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${windowstart} $${windowend} $${action} $${flowlogstatus}"

  # DHCP options
  enable_dhcp_options              = true
  dhcp_options_domain_name         = "eu-west-1.compute.internal"
  dhcp_options_domain_name_servers = ["AmazonProvidedDNS"]

  # Default security group - highly restrictive for production
  manage_default_security_group = true
  default_security_group_ingress = []  # No inbound by default
  default_security_group_egress = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
      description = "HTTPS outbound only"
    }
  ]

  # Network ACLs - strict security for production
  manage_default_network_acl = true
  default_network_acl_ingress = [
    {
      rule_no    = 100
      action     = "allow"
      from_port  = 0
      to_port    = 0
      protocol   = "-1"
      cidr_block = local.vpc_config.cidr_block  # Only within VPC
    }
  ]
  default_network_acl_egress = [
    {
      rule_no    = 100
      action     = "allow"
      from_port  = 443
      to_port    = 443
      protocol   = "tcp"
      cidr_block = "0.0.0.0/0"
    },
    {
      rule_no    = 110
      action     = "allow"
      from_port  = 0
      to_port    = 0
      protocol   = "-1"
      cidr_block = local.vpc_config.cidr_block
    }
  ]

  # Public subnet configuration
  map_public_ip_on_launch = false  # No auto-assign public IPs in production

  # Route table configuration
  create_igw = true

  # VPC Endpoints for enhanced security and performance
  enable_s3_endpoint          = true
  enable_dynamodb_endpoint    = true
  enable_ec2_endpoint         = true
  enable_ssm_endpoint         = true
  enable_ssmmessages_endpoint = true
  enable_ec2messages_endpoint = true
  enable_kms_endpoint         = true
  enable_logs_endpoint        = true

  # Secondary CIDR blocks for expansion
  secondary_cidr_blocks = []  # Can be added later for growth

  # Customer gateways for VPN connectivity
  customer_gateways = {
    IP1 = {
      bgp_asn    = 65000
      ip_address = "203.0.113.12"  # Replace with actual customer gateway IP
    }
  }

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
      VPCType           = "production"
      CriticalityLevel  = "critical"
      HighAvailability  = "true"
      MultiAZNAT        = "true"
      VPCEndpoints      = "comprehensive"
      VPNGateway        = "enabled"
      FlowLogsRetention = "365-days"
      SecurityLevel     = "high"
    }
  )

  # Subnet tags with detailed classification
  public_subnet_tags = {
    Name = "public-subnet-${local.environment}-eu-west-1"
    Type = "public"
    Tier = "web"
    kubernetes.io/role/elb = "1"
    PublicIPAssignment = "disabled"
    SecurityLevel = "high"
  }

  private_subnet_tags = {
    Name = "private-subnet-${local.environment}-eu-west-1"
    Type = "private"
    Tier = "application"
    kubernetes.io/role/internal-elb = "1"
    SecurityLevel = "high"
    BackupRequired = "true"
  }

  database_subnet_tags = {
    Name = "database-subnet-${local.environment}-eu-west-1"
    Type = "database"
    Tier = "data"
    SecurityLevel = "critical"
    BackupRequired = "true"
    EncryptionRequired = "true"
    AccessRestricted = "true"
  }

  elasticache_subnet_tags = {
    Name = "elasticache-subnet-${local.environment}-eu-west-1"
    Type = "elasticache"
    Tier = "cache"
    SecurityLevel = "high"
    Performance = "optimized"
  }

  redshift_subnet_tags = {
    Name = "redshift-subnet-${local.environment}-eu-west-1"
    Type = "redshift"
    Tier = "analytics"
    SecurityLevel = "high"
    DataClassification = "confidential"
  }

  # VPC endpoint tags
  vpc_endpoint_tags = {
    Name = "vpc-endpoint-${local.environment}-eu-west-1"
    Type = "vpc-endpoint"
    SecurityEnhanced = "true"
    CostOptimized = "true"
    Performance = "optimized"
  }

  # Internet gateway tags
  igw_tags = {
    Name = "igw-${local.environment}-eu-west-1"
    Type = "internet-gateway"
    CriticalityLevel = "high"
  }

  # NAT gateway tags
  nat_gateway_tags = {
    Name = "nat-gateway-${local.environment}-eu-west-1"
    Type = "nat-gateway"
    Count = "per-az"
    HighAvailability = "true"
    CriticalityLevel = "high"
  }

  # VPN gateway tags
  vpn_gateway_tags = {
    Name = "vpn-gateway-${local.environment}-eu-west-1"
    Type = "vpn-gateway"
    HybridConnectivity = "true"
    CriticalityLevel = "high"
  }

  # Route table tags
  public_route_table_tags = {
    Name = "rt-public-${local.environment}-eu-west-1"
    Type = "public-route-table"
    SecurityLevel = "medium"
  }

  private_route_table_tags = {
    Name = "rt-private-${local.environment}-eu-west-1"
    Type = "private-route-table"
    SecurityLevel = "high"
  }

  database_route_table_tags = {
    Name = "rt-database-${local.environment}-eu-west-1"
    Type = "database-route-table"
    IsolationLevel = "maximum"
    SecurityLevel = "critical"
  }
}
