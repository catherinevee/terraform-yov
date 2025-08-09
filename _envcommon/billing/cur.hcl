# =============================================================================
# COST AND USAGE REPORTS (CUR) - ENVIRONMENT COMMON CONFIGURATION
# =============================================================================
# Common configuration for AWS Cost and Usage Reports across all environments
# Provides cost optimization, billing transparency, and financial governance

locals {
  # Common CUR configuration
  cur_common_config = {
    # Standard CUR format settings
    format                         = "Parquet"
    compression                   = "GZIP"
    additional_schema_elements    = ["RESOURCES"]
    s3_prefix                     = "cur-reports"
    
    # Time granularity - Daily for detailed analysis
    time_unit = "DAILY"
    
    # Additional artifacts for enhanced reporting
    additional_artifacts = [
      "REDSHIFT",
      "ATHENA"
    ]
    
    # Refresh settings for automatic updates
    refresh_closed_reports = true
    report_versioning     = "OVERWRITE_REPORT"
    
    # Standard CUR tags
    common_tags = {
      Service         = "cost-usage-reports"
      Purpose         = "billing-optimization"
      DataRetention   = "13months"
      ReportFormat    = "parquet"
      Granularity     = "daily"
      Analytics       = "athena-redshift"
      CostOptimization = "enabled"
      BillingDashboard = "enabled"
    }
  }
  
  # Environment-specific naming patterns
  cur_naming = {
    report_prefix = "yov-cur"
    bucket_prefix = "yov-cur-reports"
  }
}
