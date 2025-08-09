# =============================================================================
# PRODUCTION ENVIRONMENT CONFIGURATION - EU-WEST-1
# =============================================================================
# This file contains production-specific configurations with enterprise-grade
# features, high availability, and performance optimization

locals {
  # Environment identification
  environment      = "prod"
  environment_full = "production"

  # Environment-specific configurations
  env_config = {
    # Resource sizing for production workloads (enterprise-grade)
    sizing = {
      # EC2 instances - production-optimized instances
      web_tier_instance_type      = "m5.xlarge"     # High memory for web loads
      app_tier_instance_type      = "c5.2xlarge"    # Compute-optimized for apps
      database_tier_instance_type = "r5.4xlarge"    # Memory-optimized for DB

      # Auto Scaling - production capacity with growth room
      web_tier_min_size     = 3     # Multi-AZ + 1 for availability
      web_tier_max_size     = 20    # Scale for peak loads
      web_tier_desired_size = 6     # Start with capacity

      app_tier_min_size     = 3     # Multi-AZ + 1 for availability
      app_tier_max_size     = 15    # Scale for processing loads
      app_tier_desired_size = 6     # Start with capacity

      # RDS - production database configuration
      rds_instance_class        = "db.r6g.2xlarge"   # High-performance instances
      rds_allocated_storage     = 500                # Large initial storage
      rds_max_allocated_storage = 2000               # Growth capacity

      # ElastiCache - high-performance caching
      elasticache_node_type       = "cache.r6g.xlarge"  # Memory-optimized cache
      elasticache_num_cache_nodes = 3                    # Full redundancy

      # EKS - production Kubernetes cluster
      eks_node_instance_types = ["m5.xlarge", "c5.2xlarge", "r5.xlarge"]  # Mixed workloads
      eks_min_nodes           = 6                                          # High availability base
      eks_max_nodes           = 50                                         # Scale for demand
      eks_desired_nodes       = 12                                         # Production start
    }

    # High availability and disaster recovery
    high_availability = {
      multi_az                = true    # Full multi-AZ deployment
      cross_region_replication = true   # DR to eu-central-1
      auto_failover           = true    # Automatic failover
      backup_retention_days   = 30     # Long-term backups
      point_in_time_recovery  = true   # Granular recovery
      read_replicas          = true    # Read scaling
    }

    # Performance optimization
    performance = {
      provisioned_iops        = true    # High IOPS for database
      enhanced_networking     = true    # SR-IOV networking
      placement_groups        = true    # Optimized placement
      dedicated_tenancy       = false   # Shared tenancy for cost
      nitro_enclaves         = true    # Secure computing
      graviton_processors    = true    # ARM-based performance
    }

    # Monitoring and observability - enterprise-grade
    monitoring = {
      detailed_monitoring     = true
      enhanced_monitoring     = true
      performance_insights    = true
      cloudwatch_logs        = true
      custom_metrics         = true
      alerting_enabled       = true
      log_retention_days     = 365    # Long-term retention
      x_ray_tracing          = true   # Application tracing
      aws_config             = true   # Compliance monitoring
      cloudtrail             = true   # Audit logging
    }

    # Auto-scaling policies
    auto_scaling = {
      scale_up_threshold     = 70     # CPU threshold for scaling up
      scale_down_threshold   = 30     # CPU threshold for scaling down
      scale_up_cooldown      = 300    # Cooldown period (5 min)
      scale_down_cooldown    = 600    # Cooldown period (10 min)
      predictive_scaling     = true   # ML-based scaling
    }
  }

  # Environment-specific tags
  environment_tags = {
    Environment        = local.environment
    EnvironmentType    = "production"
    CriticalityLevel   = "critical"
    DataClassification = "confidential"
    BusinessImpact     = "critical"
    SLA                = "99.9%"    # High availability SLA
    MaintenanceWindow  = "sun_03-04"
    BackupRequired     = "true"
    MonitoringLevel    = "comprehensive"
    ComplianceRequired = "true"
    DRRequired         = "true"
    EncryptionRequired = "enterprise"
    CostOptimized      = "performance"
    AutoShutdown       = "disabled"  # Always available
    DataResidency      = "EU"
    GDPRCompliant      = "true"
    SOCCompliant       = "true"
    ISO27001Compliant  = "true"
    PCI_DSS_Required   = "true"
    ChangeManagement   = "strict"
    ApprovalRequired   = "true"
  }

  # Security configuration - enterprise-grade
  security_config = {
    encryption_at_rest         = true
    encryption_in_transit      = true
    kms_customer_managed_keys  = true   # Customer-managed encryption
    secrets_manager            = true
    parameter_store_secure     = true
    iam_roles_strict           = true
    network_acls              = true
    security_groups_strict     = true
    vpc_flow_logs             = true
    waf_enabled               = true
    waf_sql_injection_protection = true
    waf_xss_protection        = true
    guard_duty_enabled        = true
    security_hub_enabled      = true
    inspector_enabled         = true
    macie_enabled             = true    # Data discovery and protection
    certificate_transparency   = true
    dns_filtering             = true
  }

  # Compliance and governance
  compliance_config = {
    gdpr_compliance           = true
    data_residency_eu         = true
    audit_logging            = true
    change_tracking          = true
    access_logging           = true
    encryption_everywhere    = true
    data_classification      = true
    privacy_by_design        = true
    right_to_be_forgotten    = true
    data_portability         = true
    breach_notification      = true
  }
}
