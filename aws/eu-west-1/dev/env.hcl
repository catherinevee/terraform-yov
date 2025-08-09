# =============================================================================
# DEVELOPMENT ENVIRONMENT CONFIGURATION - EU-WEST-1
# =============================================================================
# This file contains development-specific configurations with cost-optimized
# settings for non-production workloads

locals {
  # Environment identification
  environment      = "dev"
  environment_full = "development"

  # Environment-specific configurations
  env_config = {
    # Resource sizing for development workloads (cost-optimized)
    sizing = {
      # EC2 instances - smaller, burstable instances for dev
      web_tier_instance_type      = "t3.medium"    # Instead of m5.xlarge
      app_tier_instance_type      = "t3.large"     # Instead of c5.2xlarge
      database_tier_instance_type = "t3.large"     # Instead of r5.4xlarge

      # Auto Scaling - minimal for dev
      web_tier_min_size     = 1
      web_tier_max_size     = 3
      web_tier_desired_size = 1

      app_tier_min_size     = 1
      app_tier_max_size     = 2
      app_tier_desired_size = 1

      # RDS - smaller instances and storage for dev
      rds_instance_class        = "db.t3.micro"    # Instead of db.r6g.2xlarge
      rds_allocated_storage     = 20               # Instead of 500GB
      rds_max_allocated_storage = 100              # Instead of 2000GB

      # ElastiCache - minimal setup for dev
      elasticache_node_type       = "cache.t3.micro"  # Instead of cache.r6g.xlarge
      elasticache_num_cache_nodes = 1                  # Instead of 3

      # EKS - smaller node groups for dev
      eks_node_instance_types = ["t3.medium", "t3.large"]  # Instead of m5.xlarge+
      eks_min_nodes           = 1                          # Instead of 3
      eks_max_nodes           = 3                          # Instead of 20
      eks_desired_nodes       = 1                          # Instead of 6
    }
  }

  # Environment-specific tags
  environment_tags = {
    Environment        = local.environment
    EnvironmentType    = "development"
    CriticalityLevel   = "low"
    DataClassification = "public"
    BusinessImpact     = "low"
    SLA                = "95%"  # Lower SLA for dev
    MaintenanceWindow  = "sun_02-04"
    BackupRequired     = "false"
    MonitoringLevel    = "basic"
    ComplianceRequired = "false"
    DRRequired         = "false"
    EncryptionRequired = "basic"
    CostOptimized      = "true"
    AutoShutdown       = "enabled"  # Shut down overnight/weekends
    DataResidency      = "EU"
    GDPRCompliant      = "true"
  }

  # Auto-shutdown configuration for cost savings
  auto_shutdown = {
    enabled = true
    schedule = {
      # Shutdown at 6 PM GMT, start at 7 AM GMT
      shutdown_cron = "0 18 * * MON-FRI"  # Weekdays 6 PM
      startup_cron  = "0 7 * * MON-FRI"   # Weekdays 7 AM
      weekend_shutdown = true              # Shutdown weekends completely
    }
    resources = ["ec2", "rds", "elasticache", "eks"]
  }
}
