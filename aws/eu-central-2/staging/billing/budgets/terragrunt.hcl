# =============================================================================
# STAGING BILLING BUDGETS CONFIGURATION - EU-CENTRAL-2
# =============================================================================
# Cost monitoring and budget alerts for staging environment

# Include root configuration (backend, providers)
include "root" {
  path   = find_in_parent_folders("terragrunt.hcl")
  expose = true
}

locals {
  # Read configuration files directly
  region_config = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_config    = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  # Staging-specific overrides
  environment = "staging"
  region      = "eu-central-2"
}

# Use AWS Budgets module
terraform {
  source = "tfr:///terraform-aws-modules/budgets/aws?version=1.0.0"
}

# Staging-specific budget inputs
inputs = {
  # Budget configuration
  name         = "staging-euc2-monthly-budget"
  budget_type  = "COST"
  limit_amount = "500"  # $500 monthly limit for staging
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  
  # Time period
  time_period_start = "2025-01-01_00:00"
  time_period_end   = null  # No end date
  
  # Cost filters for staging environment
  cost_filters = {
    Region = ["eu-central-2"]
    Tag = {
      Environment = ["staging"]
    }
  }
  
  # Notifications - alert at 80% and 100%
  notifications = [
    {
      comparison_operator   = "GREATER_THAN"
      threshold            = 80
      threshold_type       = "PERCENTAGE"
      notification_type    = "ACTUAL"
      subscriber_email_addresses = [
        "devops@company.com",
        "staging-alerts@company.com"
      ]
    },
    {
      comparison_operator   = "GREATER_THAN" 
      threshold            = 100
      threshold_type       = "PERCENTAGE"
      notification_type    = "FORECASTED"
      subscriber_email_addresses = [
        "devops@company.com",
        "staging-alerts@company.com",
        "finance@company.com"
      ]
    }
  ]
  
  # Tags
  tags = {
    Name            = "staging-euc2-monthly-budget"
    Environment     = "staging"
    Region          = "eu-central-2"
    ManagedBy       = "terragrunt"
    Terraform       = "true"
    Component       = "billing"
    BudgetType      = "cost-monitoring"
    CostCenter      = "staging"
    EnvironmentType = "staging"
  }
}
