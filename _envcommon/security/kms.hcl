# =============================================================================
# SHARED KMS CONFIGURATION
# =============================================================================
# This file contains reusable KMS configuration that can be inherited
# by different environments with environment-specific customizations

# Note: This file provides shared configuration but does not include other files
# to avoid nested include issues. The main terragrunt.hcl handles all includes.

locals {
  # Default KMS configurations that can be overridden by environments
  kms_configs = {
    dev = {
      deletion_window_in_days = 7
      enable_key_rotation     = false
      multi_region           = false
    }
    
    staging = {
      deletion_window_in_days = 14
      enable_key_rotation     = true
      multi_region           = false
    }
    
    prod = {
      deletion_window_in_days = 30
      enable_key_rotation     = true
      multi_region           = true
    }
  }
}

# Expose inputs at the top level so terragrunt can access them via include.envcommon.inputs
inputs = {
    # Basic KMS key configuration
    key_usage                = "ENCRYPT_DECRYPT"
    key_spec                 = "SYMMETRIC_DEFAULT"
    enable_default_policy    = true
    
    # Common tags for all KMS resources - this is what the KMS terragrunt file expects
    tags = {
      Terraform = "true"
      Component = "kms"
      ManagedBy = "terragrunt"
    }
}
