# =============================================================================
# PRODUCTION COST AND USAGE REPORTS (CUR) - US-EAST-1
# =============================================================================
# This configuration deploys AWS Cost and Usage Reports for production
# environment cost tracking, optimization, and billing transparency

# Include root configuration (backend, providers)
include "root" {
  path   = find_in_parent_folders("terragrunt.hcl")
  expose = true
}

# Include environment-common CUR configuration
include "envcommon" {
  path           = "${dirname(find_in_parent_folders("terragrunt.hcl"))}/_envcommon/billing/cur.hcl"
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
  region      = "us-east-1"
  account_id  = "025066254478"

  # Production CUR report name
  report_name = "yov-cur-prod-use1"
  bucket_name = "yov-cur-reports-025066254478-us-east-1"
}

# Dependencies - none for CUR as it's foundational for billing

# Module source - using local terraform configuration for CUR
terraform {
  source = "."
}

# Generate CUR terraform configuration
generate "cur_main" {
  path      = "main.tf"
  if_exists = "overwrite"
  contents  = <<-EOF
    resource "aws_s3_bucket" "cur_bucket" {
      bucket = var.s3_bucket
      tags   = var.tags
    }
    
    resource "aws_s3_bucket_policy" "cur_bucket_policy" {
      bucket = aws_s3_bucket.cur_bucket.id
      
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid    = "AWSCURDelivery"
            Effect = "Allow"
            Principal = {
              Service = "billingreports.amazonaws.com"
            }
            Action   = "s3:GetBucketAcl"
            Resource = aws_s3_bucket.cur_bucket.arn
            Condition = {
              StringEquals = {
                "aws:SourceAccount" = "025066254478"
              }
            }
          },
          {
            Sid    = "AWSCURDeliveryWrite"
            Effect = "Allow"
            Principal = {
              Service = "billingreports.amazonaws.com"
            }
            Action   = "s3:PutObject"
            Resource = "$${aws_s3_bucket.cur_bucket.arn}/*"
            Condition = {
              StringEquals = {
                "aws:SourceAccount" = "025066254478"
              }
            }
          }
        ]
      })
    }
    
    resource "aws_cur_report_definition" "this" {
      report_name                = var.report_name
      time_unit                  = var.time_unit
      format                     = var.format
      compression                = var.compression
      additional_schema_elements = var.additional_schema_elements
      s3_bucket                  = aws_s3_bucket.cur_bucket.bucket
      s3_prefix                  = var.s3_prefix
      s3_region                  = var.s3_region
      additional_artifacts       = var.additional_artifacts
      refresh_closed_reports     = var.refresh_closed_reports
      report_versioning          = var.report_versioning
    }
  EOF
}

# Generate variables file for CUR
generate "variables" {
  path      = "variables.tf"
  if_exists = "overwrite"
  contents  = <<-EOF
    variable "report_name" {
      description = "Name of the CUR report"
      type        = string
    }
    
    variable "s3_bucket" {
      description = "S3 bucket for CUR reports"
      type        = string
    }
    
    variable "s3_prefix" {
      description = "S3 prefix for CUR reports"
      type        = string
      default     = "cur-reports"
    }
    
    variable "s3_region" {
      description = "S3 region"
      type        = string
    }
    
    variable "format" {
      description = "Report format"
      type        = string
      default     = "Parquet"
    }
    
    variable "compression" {
      description = "Report compression"
      type        = string
      default     = "GZIP"
    }
    
    variable "additional_schema_elements" {
      description = "Additional schema elements"
      type        = list(string)
      default     = ["RESOURCES"]
    }
    
    variable "time_unit" {
      description = "Time unit for reports"
      type        = string
      default     = "DAILY"
    }
    
    variable "additional_artifacts" {
      description = "Additional artifacts"
      type        = list(string)
      default     = []
    }
    
    variable "refresh_closed_reports" {
      description = "Refresh closed reports"
      type        = bool
      default     = true
    }
    
    variable "report_versioning" {
      description = "Report versioning"
      type        = string
      default     = "OVERWRITE_REPORT"
    }
    
    variable "tags" {
      description = "Resource tags"
      type        = map(string)
      default     = {}
    }
  EOF
}

# Production-specific CUR inputs
inputs = {
  # Production CUR report configuration
  report_name     = local.report_name
  s3_bucket       = local.bucket_name
  s3_prefix       = "cur-reports/prod"
  s3_region       = local.region
  
  # Enhanced reporting for production (Parquet format requires Parquet compression)
  format                      = "Parquet"
  compression                = "Parquet"
  additional_schema_elements = ["RESOURCES"]
  time_unit                  = "DAILY"
  
  # Additional artifacts for analytics - ATHENA only (AWS limitation)
  additional_artifacts = [
    "ATHENA"
  ]
  
  # Report versioning and refresh
  refresh_closed_reports = true
  report_versioning     = "OVERWRITE_REPORT"
  
  # Production-specific tags
  tags = {
    Name                = local.report_name
    Environment         = "prod"
    Region              = "us-east-1"
    AccountId           = "025066254478"
    Service             = "cost-usage-reports"
    Purpose             = "production-billing-optimization"
    DataRetention       = "13months"
    ReportFormat        = "parquet"
    Granularity         = "daily"
    Analytics           = "athena"
    CostOptimization    = "enabled"
    BillingDashboard    = "enabled"
    CriticalityLevel    = "high"
    ComplianceFramework = "SOX-financial-reporting"
    
    # Operational tags
    BillingTeam         = "finance@yov.com"
    CostCenter          = "PROD-BILLING-001"
    BudgetMonitoring    = "enabled"
    AlertRecipients     = "finance-alerts@yov.com"
    
    # Analytics and reporting
    AthenaWorkgroup     = "cur-analytics"
    RedshiftCluster     = "billing-analytics"
    DashboardUrl        = "billing.yov.com/prod"
    ReportFrequency     = "daily"
    
    # Security and compliance
    DataClassification  = "financial"
    RetentionPolicy     = "7years"
    AccessControl       = "finance-team-only"
    AuditRequired       = "quarterly"
    
    # Terragrunt metadata
    ManagedBy  = "terragrunt"
    Terraform  = "true"
    Component  = "cur"
    Module     = "terraform-aws-modules/cur/aws"
  }
}
