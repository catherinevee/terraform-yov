
variable "vpc_cidr" {
  description = "VPC CIDR block for internal access"
  type        = string
  default     = "10.0.0.0/16"
}
# =============================================================================
# STAGING VPC DEPLOYMENT
# =============================================================================
# This configuration deploys a production-like VPC for staging environment
# with balanced cost optimization and testing capabilities

# Include root configuration (backend, providers)
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
  
  # Get VPC CIDR from regional configuration
  vpc_cidr = local.region_config.locals.regional_networking.vpc_cidrs.staging  # 10.60.0.0/16
  
  # Staging availability zones (production-like - using all 3 AZs for testing)
  availability_zones = local.region_config.locals.availability_zones  # All 3 AZs
}

# Module source from Terraform Registry
terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws?version=5.8.1"
}

# Staging-specific VPC inputs (production-like configuration)
inputs = {
  # VPC basic configuration
  name = "staging-euc2-vpc"
  cidr = local.vpc_cidr

  # Availability zones (all 3 for production-like testing)
  azs = local.availability_zones

  # Subnets (production-like sizing for realistic testing)
  private_subnets  = ["10.60.2.0/24", "10.60.3.0/24", "10.60.4.0/24"]
  public_subnets   = ["10.60.1.0/26", "10.60.1.64/26", "10.60.1.128/26"]
  database_subnets = ["10.60.5.0/26", "10.60.5.64/26", "10.60.5.128/26"]

  # NAT Gateway configuration (production-like for testing HA scenarios)
  enable_nat_gateway     = true
  single_nat_gateway     = false  # Multiple NAT gateways for HA testing
  one_nat_gateway_per_az = true   # Production-like setup

  # DNS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Flow logs (enabled for testing monitoring)
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_destination_type            = "cloud-watch-logs"

  # Default security group - restrictive for staging
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

  # Network ACLs - enhanced security for staging
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
    },
    {
      rule_no    = 130
      protocol   = "tcp"
      rule_action = "allow"
      from_port  = 22
      to_port    = 22
      cidr_block = local.vpc_cidr  # SSH only from within VPC
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

  # VPC endpoints (production-like for testing)
  enable_s3_endpoint       = true
  enable_dynamodb_endpoint = true
  enable_ec2_endpoint      = true
  enable_ssm_endpoint      = true

  # Default tags
  tags = merge(
    local.env_config.locals.environment_tags,
    {
      Name               = "staging-euc2-vpc"
      Environment        = "staging"
      Region             = "eu-central-2"
      ManagedBy          = "terragrunt"
      Terraform          = "true"
      Component          = "vpc"
      CostCenter         = "staging"
      TestingTier        = "infrastructure"
      SecurityCompliant  = "true"
      SecurityEnhanced   = "true"
      FlowLogsEnabled    = "true"
      SecurityAudit      = "2024"
    }
  )

  # Subnet tags
  private_subnet_tags = {
    Name = "staging-euc2-private"
    Tier = "private"
    "kubernetes.io/cluster/staging-euc2-eks" = "owned"
    SubnetTier = "application"
    TestingSubnet = "true"
  }

  public_subnet_tags = {
    Name = "staging-euc2-public"  
    Tier = "public"
    "kubernetes.io/cluster/staging-euc2-eks" = "owned"
    SubnetTier = "web"
    TestingSubnet = "true"
  }

  database_subnet_tags = {
    Name = "staging-euc2-database"
    Tier = "database"
    DatabaseTier = "staging"
    TestingSubnet = "true"
  }

  # Flow log tags
  flow_log_cloudwatch_log_group_tags = {
    Name = "staging-euc2-vpc-flow-logs"
    Environment = "staging"
    Component = "networking"
    LogType = "vpc-flow"
  }
}
