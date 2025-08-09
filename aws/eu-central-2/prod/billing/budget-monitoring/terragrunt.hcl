# =============================================================================
# PRODUCTION AWS BUDGETS - EU-CENTRAL-2
# =============================================================================
# This configuration deploys AWS Budgets for production environment
# cost monitoring, alerts, and financial governance

# Include root configuration (backend, providers)
include "root" {
  path   = find_in_parent_folders("terragrunt.hcl")
  expose = true
}

# Include environment-common Budget configuration
include "envcommon" {
  path           = "${dirname(find_in_parent_folders("terragrunt.hcl"))}/_envcommon/billing/budget.hcl"
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
  region      = "eu-central-2"
  account_id  = "025066254478"

  # Production budget name
  budget_name = "yov-budget-prod-euc2"
}

# Dependencies - none for Budget as it's foundational for cost monitoring

# Module source - using local terraform configuration for budgets
terraform {
  source = "."
}

# Generate budget terraform configuration
generate "budget_main" {
  path      = "main.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    resource "aws_budgets_budget" "this" {
      name         = var.budget_name
      budget_type  = var.budget_type
      limit_amount = var.limit_amount
      limit_unit   = var.limit_unit
      time_unit    = var.time_unit
      
      time_period_start = var.time_period_start
      time_period_end   = var.time_period_end
      
      dynamic "cost_filter" {
        for_each = var.cost_filters != null ? [var.cost_filters] : []
        content {
          name   = "Service"
          values = lookup(cost_filter.value, "Service", [])
        }
      }
      
      dynamic "notification" {
        for_each = var.notifications
        content {
          comparison_operator   = notification.value.comparison_operator
          threshold            = notification.value.threshold
          threshold_type       = notification.value.threshold_type
          notification_type    = notification.value.notification_type
          subscriber_email_addresses = notification.value.subscriber_email_addresses
        }
      }
      
      tags = var.tags
    }
  EOF
}

# Generate variables file
generate "variables" {
  path      = "variables.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    variable "budget_name" {
      description = "Name of the budget"
      type        = string
    }
    
    variable "budget_type" {
      description = "Type of budget"
      type        = string
      default     = "COST"
    }
    
    variable "limit_amount" {
      description = "Budget limit amount"
      type        = string
    }
    
    variable "limit_unit" {
      description = "Budget limit unit"
      type        = string
      default     = "USD"
    }
    
    variable "time_unit" {
      description = "Time unit for budget"
      type        = string
      default     = "MONTHLY"
    }
    
    variable "time_period_start" {
      description = "Budget time period start"
      type        = string
    }
    
    variable "time_period_end" {
      description = "Budget time period end"
      type        = string
    }
    
    variable "cost_filters" {
      description = "Cost filters for budget"
      type        = any
      default     = null
    }
    
    variable "notifications" {
      description = "Budget notifications"
      type        = list(any)
      default     = []
    }
    
    variable "auto_adjust_data" {
      description = "Auto adjust data configuration"
      type        = any
      default     = null
    }
    
    variable "tags" {
      description = "Resource tags"
      type        = map(string)
      default     = {}
    }
  EOF
}

# Production-specific Budget inputs
inputs = {
  # Create budget
  budget_name  = local.budget_name
  budget_type  = "COST"
  limit_amount = "1500"  # €1500/month for EU production (slightly lower than US)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  
  # Time period for budget
  time_period_start = "2025-01-01_00:00"
  time_period_end   = "2030-12-31_23:59"
  
  # Cost filters for production services
  cost_filters = {
    Service = [
      "Amazon Elastic Compute Cloud - Compute",
      "Amazon Relational Database Service", 
      "Amazon Simple Storage Service",
      "Amazon Elastic Kubernetes Service",
      "AWS Key Management Service",
      "Amazon CloudWatch",
      "AWS Lambda",
      "Amazon Elastic Container Service",
      "Amazon ElastiCache",
      "Amazon Elastic Load Balancing",
      "Amazon Route 53",
      "AWS Certificate Manager"
    ]
  }
  
  # Enhanced notification configuration for production
  notifications = [
    {
      comparison_operator   = "GREATER_THAN"
      threshold            = 50
      threshold_type       = "PERCENTAGE"
      notification_type    = "ACTUAL"
      subscriber_email_addresses = [
        "finance@yov.com",
        "ops-eu@yov.com",
        "cto@yov.com"
      ]
    },
    {
      comparison_operator   = "GREATER_THAN"
      threshold            = 75
      threshold_type       = "PERCENTAGE"
      notification_type    = "ACTUAL"
      subscriber_email_addresses = [
        "finance@yov.com",
        "ops-eu@yov.com",
        "cto@yov.com",
        "ceo@yov.com"
      ]
    },
    {
      comparison_operator   = "GREATER_THAN"
      threshold            = 90
      threshold_type       = "PERCENTAGE"
      notification_type    = "ACTUAL"
      subscriber_email_addresses = [
        "finance@yov.com",
        "ops-eu@yov.com",
        "cto@yov.com",
        "ceo@yov.com"
      ]
    },
    {
      comparison_operator   = "GREATER_THAN"
      threshold            = 100
      threshold_type       = "PERCENTAGE"
      notification_type    = "ACTUAL"
      subscriber_email_addresses = [
        "finance@yov.com",
        "ops-eu@yov.com",
        "cto@yov.com",
        "ceo@yov.com"
      ]
    },
    {
      comparison_operator   = "GREATER_THAN"
      threshold            = 110
      threshold_type       = "PERCENTAGE"
      notification_type    = "ACTUAL"
      subscriber_email_addresses = [
        "finance@yov.com",
        "ops-eu@yov.com",
        "cto@yov.com",
        "ceo@yov.com"
      ]
    }
  ]
  
  # Auto-adjust budget based on historical data
  auto_adjust_data = {
    auto_adjust_type                = "HISTORICAL"
    historical_options_budget_months = 3
  }
  
  # Production-specific tags
  tags = {
    Name                = local.budget_name
    Environment         = "prod"
    Region              = "eu-central-2"
    AccountId           = "025066254478"
    Service             = "aws-budgets"
    Purpose             = "production-cost-monitoring"
    BudgetAmount        = "1500USD"
    MonitoringLevel     = "comprehensive"
    AlertThresholds     = "50-75-90-100-110"
    NotificationTier    = "executive"
    CriticalityLevel    = "high"
    ComplianceFramework = "SOX-financial-controls"
    DataResidency       = "eu-central-2"
    GDPRCompliance      = "required"
    
    # Financial governance
    CostCenter          = "PROD-BUDGET-002"
    BudgetOwner         = "finance@yov.com"
    CostOptimization    = "active"
    FinancialControl    = "automated"
    BudgetType          = "monthly"
    SpendingCategory    = "infrastructure"
    
    # Regional considerations
    Currency            = "USD-with-EUR-tracking"
    RegionalBudget      = "eu-production"
    DataLocalization    = "eu-central-2"
    PrivacyCompliance   = "GDPR"
    
    # Operational tags
    AlertManagement     = "enabled"
    EscalationPolicy    = "finance-ops-exec-eu"
    DashboardIntegration = "enabled"
    ReportingFrequency  = "weekly"
    ReviewCadence       = "monthly"
    
    # Automation and integration
    SlackAlerts         = "enabled"
    EmailAlerts         = "enabled"
    APIIntegration      = "finance-system"
    CostAnomalyDetection = "enabled"
    TimeZone            = "CET"
    
    # Terragrunt metadata
    ManagedBy  = "terragrunt"
    Terraform  = "true"
    Component  = "budget"
    Module     = "terraform-aws-modules/budgets/aws"
  }
}
