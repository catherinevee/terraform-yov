# =============================================================================
# DEVELOPMENT BILLING CONFIGURATION
# =============================================================================
# Cost management and billing for eu-central-2 development environment

# Include the regional configuration
include {
  path = find_in_parent_folders()
}

# Include configurations
locals {
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  
  # Extract configurations
  regional_networking = local.region_vars.locals.regional_networking
  env_config    = local.env_vars.locals.env_config
  
  # Billing configuration for development (aggressive cost management)
  billing_config = {
    # Budget configuration (low thresholds for dev)
    budgets = {
      # Monthly development budget
      monthly = {
        name         = "dev-euc2-monthly-budget"
        budget_type  = "COST"
        limit_amount = "200"  # Low budget for development
        limit_unit   = "USD"
        time_unit    = "MONTHLY"
        time_period_start = "2024-01-01_00:00"
        
        # Cost filters
        cost_filters = {
          Region = ["eu-central-2"]
          Tag = {
            Environment = ["development"]
            Region      = ["eu-central-2"]
          }
        }
        
        # Notifications (aggressive alerting)
        notifications = [
          {
            comparison_operator        = "GREATER_THAN"
            threshold                 = 50   # Alert at 50% of budget
            threshold_type            = "PERCENTAGE"
            notification_type         = "ACTUAL"
            subscriber_email_addresses = ["admin@company.com"]  # Replace with actual email
            subscriber_sns_topic_arns  = []
          },
          {
            comparison_operator        = "GREATER_THAN"
            threshold                 = 80   # Alert at 80% of budget
            threshold_type            = "PERCENTAGE"
            notification_type          = "ACTUAL"
            subscriber_email_addresses = ["admin@company.com"]
            subscriber_sns_topic_arns  = []
          },
          {
            comparison_operator        = "GREATER_THAN"
            threshold                 = 100  # Alert at 100% of budget
            threshold_type            = "PERCENTAGE"
            notification_type          = "ACTUAL"
            subscriber_email_addresses = ["admin@company.com"]
            subscriber_sns_topic_arns  = []
          },
          {
            comparison_operator        = "GREATER_THAN"
            threshold                 = 90   # Forecast alert at 90%
            threshold_type            = "PERCENTAGE"
            notification_type          = "FORECASTED"
            subscriber_email_addresses = ["admin@company.com"]
            subscriber_sns_topic_arns  = []
          }
        ]
      }
      
      # Weekly development budget (additional control)
      weekly = {
        name         = "dev-euc2-weekly-budget"
        budget_type  = "COST"
        limit_amount = "50"   # Weekly limit
        limit_unit   = "USD"
        time_unit    = "WEEKLY"
        time_period_start = "2024-01-01_00:00"
        
        cost_filters = {
          Region = ["eu-central-2"]
          Tag = {
            Environment = ["development"]
            Region      = ["eu-central-2"]
          }
        }
        
        notifications = [
          {
            comparison_operator        = "GREATER_THAN"
            threshold                 = 80
            threshold_type            = "PERCENTAGE"
            notification_type          = "ACTUAL"
            subscriber_email_addresses = ["admin@company.com"]
            subscriber_sns_topic_arns  = []
          }
        ]
      }
      
      # Service-specific budgets
      ec2_budget = {
        name         = "dev-euc2-ec2-budget"
        budget_type  = "COST"
        limit_amount = "100"  # EC2 specific budget
        limit_unit   = "USD"
        time_unit    = "MONTHLY"
        time_period_start = "2024-01-01_00:00"
        
        cost_filters = {
          Region = ["eu-central-2"]
          Service = ["Amazon Elastic Compute Cloud - Compute"]
          Tag = {
            Environment = ["development"]
          }
        }
        
        notifications = [
          {
            comparison_operator        = "GREATER_THAN"
            threshold                 = 75
            threshold_type            = "PERCENTAGE"
            notification_type          = "ACTUAL"
            subscriber_email_addresses = ["admin@company.com"]
            subscriber_sns_topic_arns  = []
          }
        ]
      }
      
      rds_budget = {
        name         = "dev-euc2-rds-budget"
        budget_type  = "COST"
        limit_amount = "50"   # RDS specific budget
        limit_unit   = "USD"
        time_unit    = "MONTHLY"
        time_period_start = "2024-01-01_00:00"
        
        cost_filters = {
          Region = ["eu-central-2"]
          Service = ["Amazon Relational Database Service"]
          Tag = {
            Environment = ["development"]
          }
        }
        
        notifications = [
          {
            comparison_operator        = "GREATER_THAN"
            threshold                 = 75
            threshold_type            = "PERCENTAGE"
            notification_type          = "ACTUAL"
            subscriber_email_addresses = ["admin@company.com"]
            subscriber_sns_topic_arns  = []
          }
        ]
      }
    }
    
    # Cost anomaly detection
    cost_anomaly_detection = {
      enabled = true
      
      # Anomaly detector for development environment
      detector = {
        name         = "dev-euc2-cost-anomaly-detector"
        frequency    = "DAILY"
        monitor_type = "DIMENSIONAL"
        
        specification = {
          dimension_key = "SERVICE"
          values        = ["EC2-Instance", "RDS", "EKS", "ElastiCache"]
          match_options = ["EQUALS"]
        }
        
        cost_filters = {
          Region = ["eu-central-2"]
          Tag = {
            Environment = ["development"]
          }
        }
      }
      
      # Anomaly subscription
      subscription = {
        name      = "dev-euc2-anomaly-subscription"
        frequency = "DAILY"
        threshold = 50.0  # Alert on $50+ anomalies
        
        subscriber = {
          type    = "EMAIL"
          address = "admin@company.com"  # Replace with actual email
        }
      }
    }
    
    # Cost reports and dashboards
    cost_reports = {
      # Daily cost report
      daily_report = {
        enabled = true
        report_name = "dev-euc2-daily-cost-report"
        time_unit = "DAILY"
        format = "textORcsv"
        compression = "GZIP"
        
        # S3 configuration for reports
        s3_bucket = "dev-euc2-cost-reports-${random_string.bucket_suffix.result}"
        s3_prefix = "daily-reports/"
        s3_region = "eu-central-2"
        
        additional_schema_elements = ["RESOURCES"]
        additional_artifacts = ["REDSHIFT", "QUICKSIGHT"]
      }
      
      # Monthly detailed report
      monthly_report = {
        enabled = true
        report_name = "dev-euc2-monthly-cost-report"
        time_unit = "MONTHLY"
        format = "Parquet"
        compression = "Parquet"
        
        s3_bucket = "dev-euc2-cost-reports-${random_string.bucket_suffix.result}"
        s3_prefix = "monthly-reports/"
        s3_region = "eu-central-2"
        
        additional_schema_elements = ["RESOURCES", "SPLIT_COST_ALLOCATION_DATA"]
        additional_artifacts = ["ATHENA"]
      }
    }
    
    # Resource optimization
    resource_optimization = {
      # Trusted Advisor (requires Business/Enterprise support)
      trusted_advisor_enabled = false  # Usually not available in dev accounts
      
      # Compute Optimizer
      compute_optimizer = {
        enabled = true
        include_member_accounts = false
        
        # Enrollment
        ec2_recommendations_enabled       = true
        ebs_recommendations_enabled       = true
        lambda_recommendations_enabled    = true
        auto_scaling_recommendations_enabled = true
      }
      
      # Cost optimization recommendations
      cost_optimization_hub = {
        enabled = true
        enrollment_status = "Active"
        include_member_accounts = false
      }
    }
    
    # Tagging for cost allocation
    cost_allocation_tags = [
      "Environment",
      "Project",
      "Owner",
      "CostCenter",
      "Application",
      "Tier",
      "Service",
      "Region",
      "AutoShutdown"
    ]
    
    # Reserved instance and savings plans (not recommended for dev)
    reserved_instances = {
      enabled = false  # Don't use RIs for development
    }
    
    savings_plans = {
      enabled = false  # Don't use savings plans for development
    }
  }
}

# Random string for unique bucket names
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Terraform configuration
terraform {
  source = "${get_parent_terragrunt_dir()}/modules//billing"
}

# Input variables for the billing module
inputs = {
  # Budget configuration
  budgets = local.billing_config.budgets
  
  # Cost anomaly detection
  cost_anomaly_detection = local.billing_config.cost_anomaly_detection
  
  # Cost reports
  cost_reports = local.billing_config.cost_reports
  
  # Resource optimization
  resource_optimization = local.billing_config.resource_optimization
  
  # Cost allocation tags
  cost_allocation_tags = local.billing_config.cost_allocation_tags
  
  # Random suffix for unique resource names
  resource_suffix = random_string.bucket_suffix.result
  
  # Tags
  tags = merge(
    local.env_vars.locals.environment_tags,
    {
      Name        = "dev-euc2-billing"
      Component   = "billing"
      Module      = "billing"
      Purpose     = "development-cost-management"
      CostCenter  = "development"
      Region      = "eu-central-2"
    }
  )
  
  # Environment-specific settings
  environment = "development"
  region      = "eu-central-2"
  account_id  = get_aws_account_id()
}

# Dependencies (billing usually doesn't depend on other infrastructure)
dependencies = {
  paths = []  # Billing is typically independent
}
