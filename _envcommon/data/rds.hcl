# =============================================================================
# SHARED RDS CONFIGURATION
# =============================================================================
# This file contains reusable RDS configuration that can be inherited
# by different environments with environment-specific customizations

# Note: This file provides shared configuration but does not include other files
# to avoid nested include issues. The main terragrunt.hcl handles all includes.

locals {
  # Default RDS configurations that can be overridden by environments
  rds_configs = {
    dev = {
      engine                     = "postgres"
      engine_version            = "15.4"
      instance_class            = "db.t3.micro"
      allocated_storage         = 20
      max_allocated_storage     = 100
      multi_az                  = false
      backup_retention_period   = 7
      backup_window            = "03:00-04:00"
      maintenance_window       = "sun:04:00-sun:05:00"
      deletion_protection      = false
      skip_final_snapshot      = true
    }
    
    staging = {
      engine                     = "postgres"
      engine_version            = "15.4"
      instance_class            = "db.r6g.large"
      allocated_storage         = 100
      max_allocated_storage     = 500
      multi_az                  = true
      backup_retention_period   = 14
      backup_window            = "03:00-04:00"
      maintenance_window       = "sun:04:00-sun:05:00"
      deletion_protection      = true
      skip_final_snapshot      = false
    }
    
    prod = {
      engine                     = "postgres"
      engine_version            = "15.4"
      instance_class            = "db.r6g.2xlarge"
      allocated_storage         = 500
      max_allocated_storage     = 2000
      multi_az                  = true
      backup_retention_period   = 30
      backup_window            = "03:00-04:00"
      maintenance_window       = "sun:04:00-sun:05:00"
      deletion_protection      = true
      skip_final_snapshot      = false
    }
  }
}

# Expose inputs at the top level so terragrunt can access them via include.envcommon.inputs
inputs = {
    # Basic RDS configuration
    port                             = 5432
    username                         = "postgres"
    manage_master_user_password      = true
    storage_encrypted                = true
    performance_insights_enabled     = true
    monitoring_interval              = 60
    enabled_cloudwatch_logs_exports  = ["postgresql"]
    
    # Parameter and option groups
    family               = "postgres15"
    major_engine_version = "15"
    
    # Common tags for all RDS resources
    tags = {
      Terraform = "true"
      Component = "rds"
      ManagedBy = "terragrunt"
    }
}
