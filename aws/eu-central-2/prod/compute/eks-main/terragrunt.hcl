# =============================================================================
# PRODUCTION EKS MAIN CLUSTER
# =============================================================================
# This configuration deploys the main production EKS cluster with
# enterprise-grade security, high availability, and monitoring

# Include root configuration (backend, providers)
include "root" {
  path   = find_in_parent_folders("terragrunt.hcl")
  expose = true
}

# Include environment-common EKS configuration
include "envcommon" {
  path           = "${dirname(find_in_parent_folders("terragrunt.hcl"))}/_envcommon/compute/eks.hcl"
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
  environment  = "prod"
  region       = "eu-central-2"
  cluster_name = "prod-euc2-eks-main"
}

# Dependencies
dependency "vpc" {
  config_path = "../../networking/vpc"

  mock_outputs = {
    vpc_id          = "vpc-0123456789abcdef0"
    private_subnets = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1", "subnet-0123456789abcdef2"]
    intra_subnets   = ["subnet-intra-0123456789abcdef0", "subnet-intra-0123456789abcdef1"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "fmt", "show"]
}

dependency "kms" {
  config_path = "../../security/kms-app"

  mock_outputs = {
    key_arn = "arn:aws:kms:us-east-1:345678901234:key/12345678-1234-1234-1234-123456789012"
    key_id  = "12345678-1234-1234-1234-123456789012"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "fmt", "show"]
}

# Module source - using local minimal configuration instead of community module
terraform {
  source = "."
}

# Production-specific EKS inputs (simplified)
inputs = {
  # Basic cluster configuration
  cluster_name    = local.cluster_name
  cluster_version = "1.28"

  # VPC configuration
  vpc_id     = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.private_subnets

  # Endpoint configuration
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = false

  # Service CIDR
  cluster_service_ipv4_cidr = "172.20.0.0/16"

  # Tags
  tags = merge(
    include.envcommon.inputs.tags,
    {
      Name              = local.cluster_name
      ClusterType       = "production-main"
      Environment       = "production"
      CriticalityLevel  = "critical"
      ProductionCluster = "true"
      ChargeCode        = "PROD-PLATFORM-001"
    }
  )
}
