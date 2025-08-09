# =============================================================================
# SHARED EKS CONFIGURATION
# =============================================================================
# This file contains reusable EKS configuration that can be inherited
# by different environments with environment-specific customizations

# Note: This file provides shared configuration but does not include other files
# to avoid nested include issues. The main terragrunt.hcl handles all includes.

locals {
  # Default EKS configurations that can be overridden by environments
  eks_configs = {
    dev = {
      cluster_version = "1.27"
      instance_types  = ["t3.medium", "t3.large"]
      capacity_type   = "SPOT"
      desired_size    = 2
      min_size        = 1
      max_size        = 10
    }
    
    staging = {
      cluster_version = "1.28"
      instance_types  = ["m5.large", "m5.xlarge"]
      capacity_type   = "ON_DEMAND"
      desired_size    = 3
      min_size        = 2
      max_size        = 15
    }
    
    prod = {
      cluster_version = "1.28"
      instance_types  = ["m5.xlarge", "m5.2xlarge"]
      capacity_type   = "ON_DEMAND"
      desired_size    = 6
      min_size        = 3
      max_size        = 50
    }
  }
}

# Expose inputs at the top level so terragrunt can access them via include.envcommon.inputs
inputs = {
  # EKS cluster endpoint configuration
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  
  # Cluster service CIDR
  cluster_service_ipv4_cidr = "172.20.0.0/16"
  
  # Common EKS add-ons for all environments
  cluster_addons = {
    coredns = {
      addon_version = "v1.10.1-eksbuild.6"
    }
    vpc-cni = {
      addon_version = "v1.14.1-eksbuild.1"
    }
    kube-proxy = {
      addon_version = "v1.28.2-eksbuild.2"
    }
    aws-ebs-csi-driver = {
      addon_version = "v1.25.0-eksbuild.1"
    }
  }
  
  # Common tags for all EKS resources
  tags = {
    Terraform = "true"
    Component = "eks"
    ManagedBy = "terragrunt"
  }
}
