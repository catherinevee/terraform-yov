# =============================================================================
# PRODUCTION VPC DEPLOYMENT
# =============================================================================
# This configuration deploys a production-grade VPC with all security
# and compliance features enabled

# Include root configuration (backend, providers)
include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

# Include environment-common VPC configuration
include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/networking/vpc.hcl"
  expose = true
  merge_strategy = "deep"
}

# Include region configuration
include "region" {
  path = find_in_parent_folders("region.hcl")
  expose = true
}

# Include environment configuration
include "env" {
  path = find_in_parent_folders("env.hcl")
  expose = true
}

# Include account configuration
include "account" {
  path = find_in_parent_folders("account.hcl")
  expose = true
}

locals {
  # Merge all exposed configurations
  root_vars = include.root.locals
  env_vars = include.env.locals
  region_vars = include.region.locals
  account_vars = include.account.locals
  common_vars = include.envcommon.locals
  
  # Production-specific overrides
  environment = "prod"
  region = "us-east-1"
  
  # VPC Flow Logs S3 bucket for production
  flow_logs_s3_bucket = "yov-vpc-flow-logs-${local.account_vars.account_ids.prod}-${local.region}"
  flow_logs_s3_key_prefix = "vpc-flow-logs/${local.environment}/"
}

# Dependencies - none for VPC as it's foundational

# Module source from Terraform Registry
terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws?version=5.1.0"
}

# Production-specific VPC inputs
inputs = merge(
  include.envcommon.inputs,
  {
    # Production-specific VPC Flow Logs configuration
    enable_flow_log = true
    flow_log_destination_type = "s3"
    flow_log_destination_arn = "arn:aws:s3:::${local.flow_logs_s3_bucket}/${local.flow_logs_s3_key_prefix}"
    flow_log_traffic_type = "ALL"
    flow_log_retention_in_days = 90
    flow_log_max_aggregation_interval = 60  # 1 minute for production
    flow_log_log_format = "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${windowstart} $${windowend} $${action} $${flowlogstatus}"
    
    # Production VPC endpoints for security and cost optimization
    enable_s3_endpoint = true
    enable_dynamodb_endpoint = true
    
    # Additional production tags
    tags = merge(
      include.envcommon.inputs.tags,
      {
        CriticalityLevel = "high"
        DataClassification = "confidential"
        ComplianceRequired = "SOX-PCI-GDPR"
        BackupRequired = "true"
        MonitoringLevel = "enhanced"
        DRRequired = "true"
        ProductionVPC = "true"
        FlowLogsEnabled = "true"
        NetworkACLsEnabled = "true"
        VPCEndpointsEnabled = "true"
        CostCenter = local.account_vars.cost_allocation_tags.CostCenter
        BusinessUnit = local.account_vars.cost_allocation_tags.BusinessUnit
      }
    )
    
    # Production-specific subnet tags for EKS
    private_subnet_tags = merge(
      include.envcommon.inputs.private_subnet_tags,
      {
        "kubernetes.io/cluster/prod-use1-eks-main" = "owned"
        "kubernetes.io/cluster/prod-use1-eks-monitoring" = "shared"
        SubnetTier = "application"
        EKSClusterAccess = "allowed"
      }
    )
    
    public_subnet_tags = merge(
      include.envcommon.inputs.public_subnet_tags,
      {
        "kubernetes.io/cluster/prod-use1-eks-main" = "owned"
        SubnetTier = "web"
        PublicAccess = "restricted"
      }
    )
    
    # Enhanced database subnet configuration for production
    database_subnet_tags = merge(
      include.envcommon.inputs.database_subnet_tags,
      {
        DatabaseTier = "production"
        EncryptionRequired = "true"
        BackupRequired = "true"
        HighAvailability = "true"
        MultiAZ = "required"
      }
    )
    
    # Production Network ACL rules - more restrictive
    private_inbound_acl_rules = [
      # Allow HTTP/HTTPS from public subnets
      {
        rule_number = 100
        protocol = "tcp"
        rule_action = "allow"
        from_port = 80
        to_port = 80
        cidr_block = "10.30.1.0/24"  # Public subnet 1
      },
      {
        rule_number = 101
        protocol = "tcp"
        rule_action = "allow"
        from_port = 80
        to_port = 80
        cidr_block = "10.30.2.0/24"  # Public subnet 2
      },
      {
        rule_number = 102
        protocol = "tcp"
        rule_action = "allow"
        from_port = 80
        to_port = 80
        cidr_block = "10.30.3.0/24"  # Public subnet 3
      },
      {
        rule_number = 110
        protocol = "tcp"
        rule_action = "allow"
        from_port = 443
        to_port = 443
        cidr_block = "10.30.1.0/24"  # Public subnet 1
      },
      {
        rule_number = 111
        protocol = "tcp"
        rule_action = "allow"
        from_port = 443
        to_port = 443
        cidr_block = "10.30.2.0/24"  # Public subnet 2
      },
      {
        rule_number = 112
        protocol = "tcp"
        rule_action = "allow"
        from_port = 443
        to_port = 443
        cidr_block = "10.30.3.0/24"  # Public subnet 3
      },
      # Allow internal VPC communication
      {
        rule_number = 200
        protocol = "tcp"
        rule_action = "allow"
        from_port = 0
        to_port = 65535
        cidr_block = "10.30.0.0/16"  # Entire VPC
      },
      {
        rule_number = 210
        protocol = "udp"
        rule_action = "allow"
        from_port = 0
        to_port = 65535
        cidr_block = "10.30.0.0/16"  # Entire VPC
      },
      # Allow return traffic
      {
        rule_number = 300
        protocol = "tcp"
        rule_action = "allow"
        from_port = 1024
        to_port = 65535
        cidr_block = "0.0.0.0/0"
      }
    ]
    
    # Enhanced database ACL rules
    database_inbound_acl_rules = [
      # PostgreSQL from private subnets only
      {
        rule_number = 100
        protocol = "tcp"
        rule_action = "allow"
        from_port = 5432
        to_port = 5432
        cidr_block = "10.30.11.0/24"  # Private subnet 1
      },
      {
        rule_number = 101
        protocol = "tcp"
        rule_action = "allow"
        from_port = 5432
        to_port = 5432
        cidr_block = "10.30.12.0/24"  # Private subnet 2
      },
      {
        rule_number = 102
        protocol = "tcp"
        rule_action = "allow"
        from_port = 5432
        to_port = 5432
        cidr_block = "10.30.13.0/24"  # Private subnet 3
      },
      # Redis from private subnets only
      {
        rule_number = 110
        protocol = "tcp"
        rule_action = "allow"
        from_port = 6379
        to_port = 6379
        cidr_block = "10.30.11.0/24"  # Private subnet 1
      },
      {
        rule_number = 111
        protocol = "tcp"
        rule_action = "allow"
        from_port = 6379
        to_port = 6379
        cidr_block = "10.30.12.0/24"  # Private subnet 2
      },
      {
        rule_number = 112
        protocol = "tcp"
        rule_action = "allow"
        from_port = 6379
        to_port = 6379
        cidr_block = "10.30.13.0/24"  # Private subnet 3
      }
    ]
    
    # Restrict public subnet access for production
    public_inbound_acl_rules = [
      # Only HTTPS in production
      {
        rule_number = 100
        protocol = "tcp"
        rule_action = "allow"
        from_port = 443
        to_port = 443
        cidr_block = "0.0.0.0/0"
      },
      # HTTP for redirect to HTTPS only
      {
        rule_number = 110
        protocol = "tcp"
        rule_action = "allow"
        from_port = 80
        to_port = 80
        cidr_block = "0.0.0.0/0"
      },
      # Return traffic
      {
        rule_number = 200
        protocol = "tcp"
        rule_action = "allow"
        from_port = 1024
        to_port = 65535
        cidr_block = "0.0.0.0/0"
      }
    ]
  }
)
