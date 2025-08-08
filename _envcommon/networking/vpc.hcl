# =============================================================================
# SHARED VPC CONFIGURATION
# =============================================================================
# This file contains reusable VPC configuration that can be inherited
# by different environments with environment-specific customizations

# Include hierarchical configurations
include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

include "region" {
  path = find_in_parent_folders("region.hcl")
  expose = true
}

include "env" {
  path = find_in_parent_folders("env.hcl")
  expose = true
}

include "account" {
  path = find_in_parent_folders("account.hcl")
  expose = true
}

locals {
  # Extract values from included configurations
  root_vars = include.root.locals
  region_vars = include.region.locals
  env_vars = include.env.locals
  account_vars = include.account.locals
  
  environment = local.env_vars.environment
  region = local.region_vars.aws_region
  region_short = local.region_vars.aws_region_short
  
  # VPC naming
  vpc_name = "${local.environment}-${local.region_short}-vpc"
  
  # Get environment-specific network configuration
  vpc_cidr = local.region_vars.regional_networking.vpc_cidrs[local.environment]
  public_subnets = local.region_vars.regional_networking.subnet_strategy.public_subnets[local.environment]
  private_subnets = local.region_vars.regional_networking.subnet_strategy.private_subnets[local.environment]
  database_subnets = local.region_vars.regional_networking.subnet_strategy.database_subnets[local.environment]
  intra_subnets = local.region_vars.regional_networking.subnet_strategy.intra_subnets[local.environment]
  
  # Availability zones
  azs = local.region_vars.availability_zones
  
  # Environment-specific VPC configurations
  vpc_configs = {
    dev = {
      enable_nat_gateway = true
      single_nat_gateway = true
      one_nat_gateway_per_az = false
      enable_vpn_gateway = false
      enable_dns_hostnames = true
      enable_dns_support = true
      enable_dhcp_options = true
      dhcp_options_domain_name = "${local.region}.compute.internal"
      dhcp_options_domain_name_servers = ["AmazonProvidedDNS"]
      
      # Cost optimization for dev
      create_igw = true
      map_public_ip_on_launch = true
      
      # Flow logs
      enable_flow_log = true
      flow_log_destination_type = "cloud-watch-logs"
      flow_log_destination_arn = ""  # Will be created
      flow_log_traffic_type = "ALL"
      flow_log_retention_in_days = 7
    }
    
    staging = {
      enable_nat_gateway = true
      single_nat_gateway = false
      one_nat_gateway_per_az = true
      enable_vpn_gateway = false
      enable_dns_hostnames = true
      enable_dns_support = true
      enable_dhcp_options = true
      dhcp_options_domain_name = "${local.region}.compute.internal"
      dhcp_options_domain_name_servers = ["AmazonProvidedDNS"]
      
      # Enhanced networking for staging
      create_igw = true
      map_public_ip_on_launch = false
      
      # Flow logs
      enable_flow_log = true
      flow_log_destination_type = "cloud-watch-logs"
      flow_log_destination_arn = ""
      flow_log_traffic_type = "ALL"
      flow_log_retention_in_days = 14
    }
    
    prod = {
      enable_nat_gateway = true
      single_nat_gateway = false
      one_nat_gateway_per_az = true
      enable_vpn_gateway = true
      enable_dns_hostnames = true
      enable_dns_support = true
      enable_dhcp_options = true
      dhcp_options_domain_name = "${local.region}.compute.internal"
      dhcp_options_domain_name_servers = ["AmazonProvidedDNS"]
      
      # Production security settings
      create_igw = true
      map_public_ip_on_launch = false
      
      # Enhanced flow logs for production
      enable_flow_log = true
      flow_log_destination_type = "s3"
      flow_log_destination_arn = ""  # Will reference S3 bucket
      flow_log_traffic_type = "ALL"
      flow_log_retention_in_days = 90
      flow_log_max_aggregation_interval = 60
      
      # Network ACLs for additional security
      manage_default_network_acl = true
      default_network_acl_ingress = [
        {
          rule_no    = 100
          action     = "allow"
          from_port  = 0
          to_port    = 65535
          protocol   = "tcp"
          cidr_block = local.vpc_cidr
        },
        {
          rule_no    = 110
          action     = "allow"
          from_port  = 0
          to_port    = 65535
          protocol   = "udp"
          cidr_block = local.vpc_cidr
        }
      ]
      default_network_acl_egress = [
        {
          rule_no    = 100
          action     = "allow"
          from_port  = 0
          to_port    = 65535
          protocol   = "tcp"
          cidr_block = "0.0.0.0/0"
        },
        {
          rule_no    = 110
          action     = "allow"
          from_port  = 0
          to_port    = 65535
          protocol   = "udp"
          cidr_block = "0.0.0.0/0"
        }
      ]
    }
  }
  
  current_vpc_config = local.vpc_configs[local.environment]
  
  # Network Access Control Lists
  network_acls = {
    public = [
      {
        rule_number = 100
        protocol = "tcp"
        rule_action = "allow"
        from_port = 80
        to_port = 80
        cidr_block = "0.0.0.0/0"
      },
      {
        rule_number = 110
        protocol = "tcp"
        rule_action = "allow"
        from_port = 443
        to_port = 443
        cidr_block = "0.0.0.0/0"
      },
      {
        rule_number = 120
        protocol = "tcp"
        rule_action = "allow"
        from_port = 1024
        to_port = 65535
        cidr_block = "0.0.0.0/0"
      }
    ]
    
    private = [
      {
        rule_number = 100
        protocol = "tcp"
        rule_action = "allow"
        from_port = 0
        to_port = 65535
        cidr_block = local.vpc_cidr
      },
      {
        rule_number = 110
        protocol = "udp"
        rule_action = "allow"
        from_port = 0
        to_port = 65535
        cidr_block = local.vpc_cidr
      }
    ]
    
    database = [
      {
        rule_number = 100
        protocol = "tcp"
        rule_action = "allow"
        from_port = 3306
        to_port = 3306
        cidr_block = local.vpc_cidr
      },
      {
        rule_number = 110
        protocol = "tcp"
        rule_action = "allow"
        from_port = 5432
        to_port = 5432
        cidr_block = local.vpc_cidr
      },
      {
        rule_number = 120
        protocol = "tcp"
        rule_action = "allow"
        from_port = 6379
        to_port = 6379
        cidr_block = local.vpc_cidr
      }
    ]
  }
}

# Terraform module source
terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws?version=5.1.0"
}

# Common inputs for VPC module
inputs = merge(
  {
    # Basic VPC configuration
    name = local.vpc_name
    cidr = local.vpc_cidr
    
    # Availability zones and subnets
    azs = local.azs
    public_subnets = local.public_subnets
    private_subnets = local.private_subnets
    database_subnets = local.database_subnets
    intra_subnets = local.intra_subnets
    
    # Database subnet group
    create_database_subnet_group = true
    create_database_subnet_route_table = true
    create_database_internet_gateway_route = false
    create_database_nat_gateway_route = true
    
    # Public subnet configuration
    map_public_ip_on_launch = local.current_vpc_config.map_public_ip_on_launch
    
    # Internet Gateway
    create_igw = local.current_vpc_config.create_igw
    
    # NAT Gateway configuration
    enable_nat_gateway = local.current_vpc_config.enable_nat_gateway
    single_nat_gateway = local.current_vpc_config.single_nat_gateway
    one_nat_gateway_per_az = local.current_vpc_config.one_nat_gateway_per_az
    
    # VPN Gateway
    enable_vpn_gateway = local.current_vpc_config.enable_vpn_gateway
    
    # DNS configuration
    enable_dns_hostnames = local.current_vpc_config.enable_dns_hostnames
    enable_dns_support = local.current_vpc_config.enable_dns_support
    
    # DHCP options
    enable_dhcp_options = local.current_vpc_config.enable_dhcp_options
    dhcp_options_domain_name = local.current_vpc_config.dhcp_options_domain_name
    dhcp_options_domain_name_servers = local.current_vpc_config.dhcp_options_domain_name_servers
    
    # Network ACLs
    manage_default_network_acl = try(local.current_vpc_config.manage_default_network_acl, false)
    default_network_acl_ingress = try(local.current_vpc_config.default_network_acl_ingress, [])
    default_network_acl_egress = try(local.current_vpc_config.default_network_acl_egress, [])
    
    # Public network ACLs
    public_dedicated_network_acl = true
    public_inbound_acl_rules = [
      {
        rule_number = 100
        protocol = "tcp"
        rule_action = "allow"
        from_port = 80
        to_port = 80
        cidr_block = "0.0.0.0/0"
      },
      {
        rule_number = 110
        protocol = "tcp"
        rule_action = "allow"
        from_port = 443
        to_port = 443
        cidr_block = "0.0.0.0/0"
      },
      {
        rule_number = 120
        protocol = "tcp"
        rule_action = "allow"
        from_port = 1024
        to_port = 65535
        cidr_block = "0.0.0.0/0"
      }
    ]
    public_outbound_acl_rules = [
      {
        rule_number = 100
        protocol = "tcp"
        rule_action = "allow"
        from_port = 0
        to_port = 65535
        cidr_block = "0.0.0.0/0"
      },
      {
        rule_number = 110
        protocol = "udp"
        rule_action = "allow"
        from_port = 0
        to_port = 65535
        cidr_block = "0.0.0.0/0"
      }
    ]
    
    # Private network ACLs
    private_dedicated_network_acl = true
    private_inbound_acl_rules = [
      {
        rule_number = 100
        protocol = "tcp"
        rule_action = "allow"
        from_port = 0
        to_port = 65535
        cidr_block = local.vpc_cidr
      },
      {
        rule_number = 110
        protocol = "udp"
        rule_action = "allow"
        from_port = 0
        to_port = 65535
        cidr_block = local.vpc_cidr
      },
      {
        rule_number = 120
        protocol = "tcp"
        rule_action = "allow"
        from_port = 1024
        to_port = 65535
        cidr_block = "0.0.0.0/0"
      }
    ]
    private_outbound_acl_rules = [
      {
        rule_number = 100
        protocol = "tcp"
        rule_action = "allow"
        from_port = 0
        to_port = 65535
        cidr_block = "0.0.0.0/0"
      },
      {
        rule_number = 110
        protocol = "udp"
        rule_action = "allow"
        from_port = 0
        to_port = 65535
        cidr_block = "0.0.0.0/0"
      }
    ]
    
    # Database network ACLs
    database_dedicated_network_acl = true
    database_inbound_acl_rules = [
      {
        rule_number = 100
        protocol = "tcp"
        rule_action = "allow"
        from_port = 3306
        to_port = 3306
        cidr_block = local.vpc_cidr
      },
      {
        rule_number = 110
        protocol = "tcp"
        rule_action = "allow"
        from_port = 5432
        to_port = 5432
        cidr_block = local.vpc_cidr
      },
      {
        rule_number = 120
        protocol = "tcp"
        rule_action = "allow"
        from_port = 6379
        to_port = 6379
        cidr_block = local.vpc_cidr
      }
    ]
    database_outbound_acl_rules = [
      {
        rule_number = 100
        protocol = "tcp"
        rule_action = "allow"
        from_port = 1024
        to_port = 65535
        cidr_block = local.vpc_cidr
      }
    ]
    
    # VPC Flow Logs
    enable_flow_log = local.current_vpc_config.enable_flow_log
    flow_log_destination_type = local.current_vpc_config.flow_log_destination_type
    flow_log_traffic_type = local.current_vpc_config.flow_log_traffic_type
    flow_log_retention_in_days = local.current_vpc_config.flow_log_retention_in_days
    flow_log_max_aggregation_interval = try(local.current_vpc_config.flow_log_max_aggregation_interval, 600)
    
    # VPC Endpoints for cost optimization and security
    enable_s3_endpoint = true
    enable_dynamodb_endpoint = true
    
    # Additional VPC endpoints for production
    vpc_endpoint_ids = local.environment == "prod" ? [
      # EC2 endpoints
      "com.amazonaws.${local.region}.ec2",
      "com.amazonaws.${local.region}.ec2messages",
      "com.amazonaws.${local.region}.ssm",
      "com.amazonaws.${local.region}.ssmmessages",
      # ECS endpoints
      "com.amazonaws.${local.region}.ecs",
      "com.amazonaws.${local.region}.ecs-agent",
      "com.amazonaws.${local.region}.ecs-telemetry",
      # ECR endpoints
      "com.amazonaws.${local.region}.ecr.dkr",
      "com.amazonaws.${local.region}.ecr.api",
      # CloudWatch endpoints
      "com.amazonaws.${local.region}.logs",
      "com.amazonaws.${local.region}.monitoring",
      # KMS endpoint
      "com.amazonaws.${local.region}.kms",
      # Secrets Manager endpoint
      "com.amazonaws.${local.region}.secretsmanager"
    ] : []
    
    # Tags
    tags = merge(
      local.root_vars.common_tags,
      local.env_vars.environment_tags,
      {
        Name = local.vpc_name
        Purpose = "MainVPC"
        Tier = "Network"
        CIDRBlock = local.vpc_cidr
      }
    )
    
    # Subnet tags
    public_subnet_tags = {
      Name = "${local.vpc_name}-public"
      Type = "Public"
      Tier = "Web"
      "kubernetes.io/role/elb" = "1"  # For ALB ingress
    }
    
    private_subnet_tags = {
      Name = "${local.vpc_name}-private"
      Type = "Private"
      Tier = "Application"
      "kubernetes.io/role/internal-elb" = "1"  # For NLB
    }
    
    database_subnet_tags = {
      Name = "${local.vpc_name}-database"
      Type = "Database"
      Tier = "Data"
      BackupRequired = "true"
    }
    
    intra_subnet_tags = {
      Name = "${local.vpc_name}-intra"
      Type = "Intra"
      Tier = "Management"
    }
    
    # Route table tags
    public_route_table_tags = {
      Name = "${local.vpc_name}-public-rt"
      Type = "Public"
    }
    
    private_route_table_tags = {
      Name = "${local.vpc_name}-private-rt"
      Type = "Private"
    }
    
    database_route_table_tags = {
      Name = "${local.vpc_name}-database-rt"
      Type = "Database"
    }
    
    intra_route_table_tags = {
      Name = "${local.vpc_name}-intra-rt"
      Type = "Intra"
    }
    
    # Gateway tags
    igw_tags = {
      Name = "${local.vpc_name}-igw"
      Purpose = "InternetGateway"
    }
    
    nat_gateway_tags = {
      Name = "${local.vpc_name}-nat"
      Purpose = "NATGateway"
    }
    
    nat_eip_tags = {
      Name = "${local.vpc_name}-nat-eip"
      Purpose = "NATGatewayEIP"
    }
    
    # DHCP options tags
    dhcp_options_tags = {
      Name = "${local.vpc_name}-dhcp-options"
      Purpose = "DHCPOptions"
    }
  }
)
