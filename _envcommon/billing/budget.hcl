# =============================================================================
# AWS BUDGETS - ENVIRONMENT COMMON CONFIGURATION
# =============================================================================
# Common configuration for AWS Budgets across all environments
# Provides cost monitoring, alerts, and financial governance

locals {
  # Common budget configuration
  budget_common_config = {
    # Standard budget type and unit
    budget_type  = "COST"
    limit_unit   = "USD"
    time_unit    = "MONTHLY"
    
    # Cost filters for comprehensive monitoring
    cost_filters = {
      Service = [
        "Amazon Elastic Compute Cloud - Compute",
        "Amazon Relational Database Service",
        "Amazon Simple Storage Service",
        "Amazon Elastic Kubernetes Service",
        "AWS Key Management Service",
        "Amazon CloudWatch",
        "AWS Lambda",
        "Amazon Elastic Container Service"
      ]
    }
    
    # Standard notification settings
    notification_settings = {
      # Alert thresholds
      thresholds = [50, 75, 90, 100, 110]
      threshold_type = "PERCENTAGE"
      
      # Notification types
      notification_type = "ACTUAL"
      comparison_operator = "GREATER_THAN"
      
      # Subscriber configuration (to be overridden per environment)
      subscriber_type = "EMAIL"
    }
    
    # Auto-adjust budget settings
    auto_adjust_data = {
      auto_adjust_type                = "HISTORICAL"
      historical_options_budget_months = 3
    }
    
    # Common budget tags
    common_tags = {
      Service           = "aws-budgets"
      Purpose           = "cost-monitoring"
      AlertManagement   = "enabled"
      CostGovernance    = "active"
      FinancialControl  = "automated"
      BudgetType        = "monthly"
      MonitoringLevel   = "comprehensive"
    }
  }
  
  # Environment-specific naming patterns
  budget_naming = {
    prefix = "yov-budget"
  }
  
  # Default budget limits by environment (to be overridden)
  default_budget_limits = {
    dev  = 500
    prod = 2000
  }
}
