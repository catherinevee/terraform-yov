# =============================================================================
# STAGING ENVIRONMENT CONFIGURATION - EU-WEST-1
# =============================================================================
# This file contains staging-specific configurations with production-like
# features but cost-optimized sizing for pre-production testing

locals {
  # Environment identification
  environment      = "staging"
  environment_full = "staging"

  # Environment-specific configurations
  env_config = {
    # Resource sizing for staging workloads (production-like but smaller)
    sizing = {
      # EC2 instances - production-class but smaller sizes
      web_tier_instance_type      = "m5.large"     # Production-class, smaller size
      app_tier_instance_type      = "c5.xlarge"    # Production-class, smaller size
      database_tier_instance_type = "r5.xlarge"    # Production-class, smaller size

      # Auto Scaling - production patterns but lower capacity
      web_tier_min_size     = 2     # Multi-AZ minimum
      web_tier_max_size     = 6     # Scale capability
      web_tier_desired_size = 2     # Start with 2 for testing

      app_tier_min_size     = 2     # Multi-AZ minimum
      app_tier_max_size     = 4     # Scale capability
      app_tier_desired_size = 2     # Start with 2 for testing

      # RDS - production features with smaller capacity
      rds_instance_class        = "db.t3.small"    # Burstable but larger than dev
      rds_allocated_storage     = 100              # Moderate storage
      rds_max_allocated_storage = 500              # Growth capability

      # ElastiCache - production setup but smaller
      elasticache_node_type       = "cache.t3.small"  # Production-class cache
      elasticache_num_cache_nodes = 2                  # Multi-AZ for testing

      # EKS - production-like node configuration
      eks_node_instance_types = ["m5.large", "c5.large"]  # Production instance types
      eks_min_nodes           = 2                          # Multi-AZ minimum
      eks_max_nodes           = 8                          # Scale capability
      eks_desired_nodes       = 3                          # Production-like start
    }

    # High availability configuration
    high_availability = {
      multi_az                = true   # Production feature testing
      cross_region_replication = false # Within region only for staging
      auto_failover           = true   # Test failover capabilities
      backup_retention_days   = 7      # Shorter than production
    }

    # Monitoring and alerting - production-like
    monitoring = {
      detailed_monitoring     = true
      enhanced_monitoring     = true
      performance_insights    = true
      cloudwatch_logs        = true
      custom_metrics         = true
      alerting_enabled       = true
      log_retention_days     = 30     # Shorter than production
    }
  }

  # Environment-specific tags
  environment_tags = {
    Environment        = local.environment
    EnvironmentType    = "staging"
    CriticalityLevel   = "medium"
    DataClassification = "internal"
    BusinessImpact     = "medium"
    SLA                = "99%"     # Near-production SLA
    MaintenanceWindow  = "sun_02-04"
    BackupRequired     = "true"
    MonitoringLevel    = "enhanced"
    ComplianceRequired = "true"
    DRRequired         = "false"   # Within region only
    EncryptionRequired = "standard"
    CostOptimized      = "balanced"
    AutoShutdown       = "disabled" # Keep running for testing
    DataResidency      = "EU"
    GDPRCompliant      = "true"
    TestingPurpose     = "pre-production"
    ProductionLike     = "true"
  }

  # Security configuration - production-like
  security_config = {
    encryption_at_rest      = true
    encryption_in_transit   = true
    secrets_manager         = true
    iam_roles_strict        = true
    network_acls            = true
    security_groups_strict  = true
    vpc_flow_logs          = true
    waf_enabled            = true    # Test WAF rules
    guard_duty_enabled     = true    # Security monitoring
  }
}
