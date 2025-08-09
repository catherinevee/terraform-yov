# =============================================================================
# PRODUCTION VPC DEPLOYMENT
# =============================================================================
# This configuration deploys a production-grade VPC with all security
# and compliance features enabled

# Include root configuration (backend, providers)
include "root" {
  path   = find_in_parent_folders("terragrunt.hcl")
  expose = true
}

# Include environment-common VPC configuration
include "envcommon" {
  path           = "${dirname(find_in_parent_folders("terragrunt.hcl"))}/_envcommon/networking/vpc.hcl"
  expose         = true
  merge_strategy = "deep"
}

# Include region configuration
include "region" {
  path   = find_in_parent_folders("region.hcl")
  expose = true
}

# Include environment configuration
include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

# Include account configuration
include "account" {
  path   = find_in_parent_folders("account.hcl")
  expose = true
}

locals {
  # Merge all exposed configurations
  root_vars    = include.root.locals
  env_vars     = include.env.locals
  region_vars  = include.region.locals
  account_vars = include.account.locals
  common_vars  = include.envcommon.locals

  # Production-specific overrides
  environment = "prod"
  region      = "us-east-1"

  # VPC Flow Logs S3 bucket for production
  flow_logs_s3_bucket     = "yov-vpc-flow-logs-${local.account_vars.account_ids.prod}-${local.region}"
  flow_logs_s3_key_prefix = "vpc-flow-logs/${local.environment}/"
}

# Dependencies - none for VPC as it's foundational

# Module source from Terraform Registry
terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws?version=5.1.0"
}

# Production-specific VPC inputs
inputs = merge(
  # Base VPC configuration
  {
    # VPC basic configuration
    name = "prod-use1-vpc"
    cidr = "10.30.0.0/16"

    # Availability zones
    azs = ["us-east-1a", "us-east-1b", "us-east-1c"]

    # Subnets
    private_subnets  = ["10.30.11.0/24", "10.30.12.0/24", "10.30.13.0/24"]
    public_subnets   = ["10.30.1.0/24", "10.30.2.0/24", "10.30.3.0/24"]
    database_subnets = ["10.30.21.0/24", "10.30.22.0/24", "10.30.23.0/24"]

    # NAT Gateway configuration
    enable_nat_gateway = true
    single_nat_gateway = false
    one_nat_gateway_per_az = true

    # DNS
    enable_dns_hostnames = true
    enable_dns_support   = true

    # Default tags
    tags = {
      Name        = "prod-use1-vpc"
      Environment = "prod"
      Region      = "us-east-1"
      ManagedBy   = "terragrunt"
      Terraform   = "true"
      Component   = "vpc"
    }

    # Subnet tags
    private_subnet_tags = {
      Name = "prod-use1-private"
      Tier = "private"
    }

    public_subnet_tags = {
      Name = "prod-use1-public"  
      Tier = "public"
    }

    database_subnet_tags = {
      Name = "prod-use1-database"
      Tier = "database"
    }
  },
  {
    # Production-specific VPC Flow Logs configuration
    enable_flow_log                      = true
    create_flow_log_cloudwatch_log_group = true
    create_flow_log_cloudwatch_iam_role  = true
    flow_log_destination_type            = "cloud-watch-logs"
    flow_log_traffic_type                = "ALL"
    flow_log_max_aggregation_interval    = 60 # 1 minute for production

    # Production VPC endpoints for security and cost optimization
    enable_s3_endpoint       = true
    enable_dynamodb_endpoint = true

    # Additional production tags
    tags = merge(
      {
        Name        = "prod-use1-vpc"
        Environment = "prod"
        Region      = "us-east-1"
        ManagedBy   = "terragrunt"
        Terraform   = "true"
        Component   = "vpc"
      },
      {
        CriticalityLevel    = "high"
        DataClassification  = "confidential"
        ComplianceRequired  = "SOX-PCI-GDPR"
        BackupRequired      = "true"
        MonitoringLevel     = "enhanced"
        DRRequired          = "true"
        ProductionVPC       = "true"
        FlowLogsEnabled     = "true"
        NetworkACLsEnabled  = "true"
        VPCEndpointsEnabled = "true"
        CostCenter          = "TECH-INFRA-001"
        BusinessUnit        = "Engineering"
      }
    )

    # Production-specific subnet tags for EKS
    private_subnet_tags = merge(
      {
        Name = "prod-use1-private"
        Tier = "private"
      },
      {
        "kubernetes.io/cluster/prod-use1-eks-main"       = "owned"
        "kubernetes.io/cluster/prod-use1-eks-monitoring" = "shared"
        SubnetTier                                       = "application"
        EKSClusterAccess                                 = "allowed"
      }
    )

    public_subnet_tags = merge(
      {
        Name = "prod-use1-public"  
        Tier = "public"
      },
      {
        "kubernetes.io/cluster/prod-use1-eks-main" = "owned"
        SubnetTier                                 = "web"
        PublicAccess                               = "restricted"
      }
    )

    # Enhanced database subnet configuration for production
    database_subnet_tags = merge(
      {
        Name = "prod-use1-database"
        Tier = "database"
      },
      {
        DatabaseTier       = "production"
        EncryptionRequired = "true"
        BackupRequired     = "true"
        HighAvailability   = "true"
        MultiAZ            = "required"
      }
    )

    # Production Network ACL rules - more restrictive
    private_inbound_acl_rules = [
      # Allow HTTP/HTTPS from public subnets
      {
        rule_number = 100
        protocol    = "tcp"
        rule_action = "allow"
        from_port   = 80
        to_port     = 80
        cidr_block  = "10.30.1.0/24" # Public subnet 1
      },
      {
        rule_number = 101
        protocol    = "tcp"
        rule_action = "allow"
        from_port   = 80
        to_port     = 80
        cidr_block  = "10.30.2.0/24" # Public subnet 2
      },
      {
        rule_number = 102
        protocol    = "tcp"
        rule_action = "allow"
        from_port   = 80
        to_port     = 80
        cidr_block  = "10.30.3.0/24" # Public subnet 3
      },
      {
        rule_number = 110
        protocol    = "tcp"
        rule_action = "allow"
        from_port   = 443
        to_port     = 443
        cidr_block  = "10.30.1.0/24" # Public subnet 1
      },
      {
        rule_number = 111
        protocol    = "tcp"
        rule_action = "allow"
        from_port   = 443
        to_port     = 443
        cidr_block  = "10.30.2.0/24" # Public subnet 2
      },
      {
        rule_number = 112
        protocol    = "tcp"
        rule_action = "allow"
        from_port   = 443
        to_port     = 443
        cidr_block  = "10.30.3.0/24" # Public subnet 3
      },
      # Allow internal VPC communication
      {
        rule_number = 200
        protocol    = "tcp"
        rule_action = "allow"
        from_port   = 0
        to_port     = 65535
        cidr_block  = "10.30.0.0/16" # Entire VPC
      },
      {
        rule_number = 210
        protocol    = "udp"
        rule_action = "allow"
        from_port   = 0
        to_port     = 65535
        cidr_block  = "10.30.0.0/16" # Entire VPC
      },
      # Allow return traffic
      {
        rule_number = 300
        protocol    = "tcp"
        rule_action = "allow"
        from_port   = 1024
        to_port     = 65535
        cidr_block  = "0.0.0.0/0"
      }
    ]

    # Enhanced database ACL rules
    database_inbound_acl_rules = [
      # PostgreSQL from private subnets only
      {
        rule_number = 100
        protocol    = "tcp"
        rule_action = "allow"
        from_port   = 5432
        to_port     = 5432
        cidr_block  = "10.30.11.0/24" # Private subnet 1
      },
      {
        rule_number = 101
        protocol    = "tcp"
        rule_action = "allow"
        from_port   = 5432
        to_port     = 5432
        cidr_block  = "10.30.12.0/24" # Private subnet 2
      },
      {
        rule_number = 102
        protocol    = "tcp"
        rule_action = "allow"
        from_port   = 5432
        to_port     = 5432
        cidr_block  = "10.30.13.0/24" # Private subnet 3
      },
      # Redis from private subnets only
      {
        rule_number = 110
        protocol    = "tcp"
        rule_action = "allow"
        from_port   = 6379
        to_port     = 6379
        cidr_block  = "10.30.11.0/24" # Private subnet 1
      },
      {
        rule_number = 111
        protocol    = "tcp"
        rule_action = "allow"
        from_port   = 6379
        to_port     = 6379
        cidr_block  = "10.30.12.0/24" # Private subnet 2
      },
      {
        rule_number = 112
        protocol    = "tcp"
        rule_action = "allow"
        from_port   = 6379
        to_port     = 6379
        cidr_block  = "10.30.13.0/24" # Private subnet 3
      }
    ]

    # Restrict public subnet access for production
    public_inbound_acl_rules = [
      # Only HTTPS in production
      {
        rule_number = 100
        protocol    = "tcp"
        rule_action = "allow"
        from_port   = 443
        to_port     = 443
        cidr_block  = "0.0.0.0/0"
      },
      # HTTP for redirect to HTTPS only
      {
        rule_number = 110
        protocol    = "tcp"
        rule_action = "allow"
        from_port   = 80
        to_port     = 80
        cidr_block  = "0.0.0.0/0"
      },
      # Return traffic
      {
        rule_number = 200
        protocol    = "tcp"
        rule_action = "allow"
        from_port   = 1024
        to_port     = 65535
        cidr_block  = "0.0.0.0/0"
      }
    ]
  }
)
