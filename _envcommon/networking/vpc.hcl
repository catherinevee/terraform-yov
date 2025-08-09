# =============================================================================
# SHARED VPC CONFIGURATION
# =============================================================================
# This file contains reusable VPC configuration that can be inherited
# by different environments with environment-specific customizations

# Note: This file provides shared configuration but does not include other files
# to avoid nested include issues. The main terragrunt.hcl handles all includes.

locals {
  # Default VPC configurations that can be overridden by environments
  vpc_configs = {
    dev = {
      cidr                 = "10.10.0.0/16"
      azs                  = ["us-east-1a", "us-east-1b"]
      private_subnets      = ["10.10.11.0/24", "10.10.12.0/24"]
      public_subnets       = ["10.10.1.0/24", "10.10.2.0/24"]
      database_subnets     = ["10.10.21.0/24", "10.10.22.0/24"]
      intra_subnets        = ["10.10.31.0/24", "10.10.32.0/24"]
      enable_nat_gateway   = true
      enable_vpn_gateway   = false
      single_nat_gateway   = true
      enable_dns_hostnames = true
      enable_dns_support   = true
    }
    
    staging = {
      cidr                 = "10.20.0.0/16"
      azs                  = ["us-east-1a", "us-east-1b", "us-east-1c"]
      private_subnets      = ["10.20.11.0/24", "10.20.12.0/24", "10.20.13.0/24"]
      public_subnets       = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]
      database_subnets     = ["10.20.21.0/24", "10.20.22.0/24", "10.20.23.0/24"]
      intra_subnets        = ["10.20.31.0/24", "10.20.32.0/24", "10.20.33.0/24"]
      enable_nat_gateway   = true
      enable_vpn_gateway   = false
      single_nat_gateway   = false
      enable_dns_hostnames = true
      enable_dns_support   = true
    }
    
    prod = {
      cidr                 = "10.30.0.0/16"
      azs                  = ["us-east-1a", "us-east-1b", "us-east-1c"]
      private_subnets      = ["10.30.11.0/24", "10.30.12.0/24", "10.30.13.0/24"]
      public_subnets       = ["10.30.1.0/24", "10.30.2.0/24", "10.30.3.0/24"]
      database_subnets     = ["10.30.21.0/24", "10.30.22.0/24", "10.30.23.0/24"]
      intra_subnets        = ["10.30.31.0/24", "10.30.32.0/24", "10.30.33.0/24"]
      enable_nat_gateway   = true
      enable_vpn_gateway   = false
      single_nat_gateway   = false
      enable_dns_hostnames = true
      enable_dns_support   = true
    }
  }
}

# Expose inputs at the top level so terragrunt can access them via include.envcommon.inputs
inputs = {
    # VPC Flow Logs
    enable_flow_log                      = true
    create_flow_log_cloudwatch_log_group = true
    create_flow_log_cloudwatch_iam_role  = true
    flow_log_destination_type            = "cloud-watch-logs"
    flow_log_destination_arn             = ""
    
    # DHCP Options
    enable_dhcp_options              = true
    dhcp_options_domain_name         = "ec2.internal"
    dhcp_options_domain_name_servers = ["AmazonProvidedDNS"]
    
    # Default Security Group
    manage_default_security_group  = true
    default_security_group_ingress = []
    default_security_group_egress  = []
    
    # Subnet tags - these are what the VPC terragrunt file is looking for
    private_subnet_tags = {
      SubnetType = "private"
      Tier       = "application"
    }
    
    public_subnet_tags = {
      SubnetType = "public"
      Tier       = "web"
    }
    
    database_subnet_tags = {
      SubnetType = "database"
      Tier       = "data"
    }
    
    intra_subnet_tags = {
      SubnetType = "intra"
      Tier       = "isolated"
    }
    
    # Common tags for all VPC resources
    tags = {
      Terraform = "true"
      Component = "vpc"
      ManagedBy = "terragrunt"
    }
}
