
variable "vpc_cidr" {
  description = "VPC CIDR block for internal access"
  type        = string
  default     = "10.0.0.0/16"
}
# =============================================================================
# STAGING ENVIRONMENT CONFIGURATION - EU-CENTRAL-2
# =============================================================================
# This file contains staging-specific configurations balancing cost optimization
# with production-like testing capabilities

locals {
  # Environment identification
  environment      = "staging"
  environment_full = "staging"

  # Environment-specific configurations
  env_config = {
    # Resource sizing for staging workloads (between dev and prod)
    sizing = {
      # EC2 instances - production-like but smaller
      web_tier_instance_type      = "t3.large"     # Between t3.medium and m5.xlarge
      app_tier_instance_type      = "t3.xlarge"    # Between t3.large and c5.2xlarge
      database_tier_instance_type = "t3.xlarge"    # Between t3.large and r5.4xlarge

      # Auto Scaling - moderate scaling
      web_tier_min_size     = 2
      web_tier_max_size     = 6
      web_tier_desired_size = 2

      app_tier_min_size     = 2
      app_tier_max_size     = 4
      app_tier_desired_size = 2

      # RDS - production-like engine but smaller instance
      rds_instance_class        = "db.t3.small"    # Between db.t3.micro and db.r6g.2xlarge
      rds_allocated_storage     = 100              # Between 20GB and 500GB
      rds_max_allocated_storage = 500              # Between 100GB and 2000GB

      # ElastiCache - small cluster for testing
      elasticache_node_type       = "cache.t3.small"  # Between cache.t3.micro and cache.r6g.xlarge
      elasticache_num_cache_nodes = 2                  # Between 1 and 3

      # EKS - moderate node groups for testing
      eks_node_instance_types = ["t3.large", "t3.xlarge"]  # Between t3.medium and m5.xlarge+
      eks_min_nodes           = 2                          # Between 1 and 3
      eks_max_nodes           = 6                          # Between 3 and 20
      eks_desired_nodes       = 2                          # Between 1 and 6
    }

    # Performance and reliability settings (production-like testing)
    performance = {
      # Database - multi-AZ for production-like testing
      rds_multi_az                              = true   # Production-like for testing
      rds_backup_retention_period               = 14     # Between dev (7) and prod (30)
      rds_backup_window                         = "03:00-04:00"
      rds_maintenance_window                    = "sun:04:00-sun:05:00"
      rds_performance_insights_enabled          = true   # Enabled for testing
      rds_performance_insights_retention_period = 7
      rds_enhanced_monitoring_interval          = 60     # Basic monitoring

      # ElastiCache - failover testing
      elasticache_automatic_failover_enabled = true   # Test failover scenarios
      elasticache_multi_az_enabled           = true   # Multi-AZ testing
      elasticache_snapshot_retention_limit   = 3      # Between dev (1) and prod (7)
      elasticache_snapshot_window            = "03:00-05:00"

      # Load Balancer - production-like settings
      alb_idle_timeout        = 60
      alb_deletion_protection = false  # Easier to manage than prod
      alb_access_logs_enabled = true   # For testing analysis

      # Auto Scaling - production-like for testing
      auto_scaling_health_check_type         = "ELB"   # Production-like testing
      auto_scaling_health_check_grace_period = 300
      auto_scaling_termination_policies      = ["OldestInstance"]
    }

    # Security settings for staging (production-like testing)
    security = {
      # Encryption - production-like
      encryption_at_rest_required    = true
      encryption_in_transit_required = true   # Test encryption scenarios

      # Access control - restricted like production
      public_subnet_access = false  # Test production-like access patterns
      ssh_access_enabled   = true   # Allow for debugging staging issues
      rdp_access_enabled   = false

      # Network ACLs - production-like testing
      restrict_default_security_group = true   # Test security restrictions
      enable_vpc_flow_logs            = true   # Monitor traffic patterns

      # IAM - production-like policies
      enforce_mfa              = true   # Test MFA requirements
      password_policy_enforced = true
      access_key_rotation_days = 90     # Same as production

      # Logging and monitoring - selective enabling for testing
      cloudtrail_enabled   = true   # Test audit trails
      config_enabled       = true   # Test compliance monitoring
      guardduty_enabled    = false  # Disabled for cost in staging
      security_hub_enabled = false  # Disabled for cost in staging

      # Backup and recovery - test scenarios
      backup_required        = true   # Test backup procedures
      point_in_time_recovery = true   # Test recovery scenarios
      cross_region_backup    = false  # Single region for staging
    }

    # Monitoring and alerting (comprehensive testing)
    monitoring = {
      # CloudWatch - detailed for testing
      detailed_monitoring = true   # Test monitoring capabilities
      enhanced_monitoring = true   # Test enhanced metrics
      log_retention_days  = 30     # Between dev (7) and prod (90)

      # Metrics and alarms - production-like thresholds
      cpu_alarm_threshold    = 80   # Same as production
      memory_alarm_threshold = 85   # Same as production
      disk_alarm_threshold   = 90   # Same as production

      # Application monitoring - test APM integration
      enable_x_ray_tracing      = true   # Test distributed tracing
      enable_container_insights = true   # Test container monitoring

      # Log aggregation - test log pipeline
      centralized_logging    = true   # Test log aggregation
      log_forwarding_enabled = true   # Test log forwarding

      # Synthetic monitoring - test monitoring stack
      canary_monitoring_enabled = true   # Test canary deployments
      health_check_enabled      = true   # Test health monitoring
    }

    # Compliance and governance (test compliance scenarios)
    compliance = {
      # Data classification - test data handling
      data_classification = "internal"  # Between public (dev) and confidential (prod)

      # Regulatory compliance - test compliance controls
      sox_compliance              = true   # Test SOX controls
      pci_dss_compliance          = false  # Not needed for staging
      gdpr_compliance             = true   # Test GDPR compliance
      ccpa_compliance             = false  # Not applicable in EU
      data_sovereignty_compliance = true   # Test data residency
      swiss_data_protection_act   = true   # Test Swiss DPA

      # Audit requirements - test audit capabilities
      audit_logging_enabled      = true   # Test audit logging
      change_management_required = true   # Test change processes
      approval_workflow_enabled  = false  # Simplified for staging

      # Data retention - test retention policies
      data_retention_years   = 3      # Between dev (1) and prod (7)
      log_retention_years    = 2      # Between dev (1) and prod (3)
      backup_retention_years = 3      # Between dev (1) and prod (7)
      gdpr_data_portability  = true   # Test GDPR features
      gdpr_right_to_erasure  = true   # Test GDPR features
    }

    # Business continuity (test DR scenarios)
    business_continuity = {
      # High availability - test HA scenarios
      multi_az_deployment      = true   # Test multi-AZ failover
      cross_region_replication = false  # Single region for staging

      # Disaster recovery - test DR procedures
      rpo_hours            = 4      # Between dev (24) and prod (1)
      rto_hours            = 6      # Between dev (8) and prod (4)
      dr_testing_frequency = "monthly"  # More frequent than prod

      # Backup strategy - test backup/restore
      backup_frequency      = "daily"   # Same as production
      backup_retention_days = 30       # Between dev (7) and prod (90)
      backup_cross_region   = false    # Single region for staging
      backup_encryption     = true     # Test encryption

      # Maintenance windows - flexible for testing
      maintenance_window_day         = "saturday"  # Different from prod
      maintenance_window_time        = "02:00-04:00"
      maintenance_notification_hours = 24          # Shorter than prod
    }

    # Cost management (balanced approach)
    cost_management = {
      # Resource optimization
      right_sizing_enabled    = true
      unused_resource_cleanup = true

      # Reserved instances - minimal for staging
      reserved_instance_coverage_target = 25   # Some savings but flexible
      savings_plan_coverage_target      = 25

      # Cost monitoring
      budget_alerts_enabled  = true
      cost_anomaly_detection = true

      # Tagging for cost allocation
      cost_center_tagging_required = true
      project_tagging_required     = true
      owner_tagging_required       = true

      # Spot instances - limited use for stability
      spot_instance_usage_target = 30  # Some cost savings but stable
    }
  }

  # Environment-specific tags
  environment_tags = {
    Environment         = local.environment
    EnvironmentType     = "staging"
    CriticalityLevel    = "medium"
    DataClassification  = "internal"
    BusinessImpact      = "medium"
    SLA                 = "99%"  # Lower than prod but higher than dev
    MaintenanceWindow   = "sat:02:00-sat:04:00"
    BackupRequired      = "true"
    MonitoringLevel     = "enhanced"
    ComplianceRequired  = "true"
    DRRequired          = "limited"
    EncryptionRequired  = "true"
    DataResidency       = "EU"
    GDPRCompliant       = "true"
    SwissDataProtection = "true"
    TestingEnvironment  = "true"
    ProductionLike      = "true"
    CostOptimized       = "balanced"
    AutoShutdown        = "disabled"  # Keep running for continuous testing
  }

  # Application-specific configurations (production-like testing)
  applications = {
    web_application = {
      instance_type             = "t3.large"
      min_capacity              = 2
      max_capacity              = 6
      desired_capacity          = 2
      health_check_grace_period = 300
      health_check_type         = "ELB"
      spot_instance_enabled     = false  # Stable for testing
    }

    api_application = {
      instance_type             = "t3.xlarge"
      min_capacity              = 2
      max_capacity              = 4
      desired_capacity          = 2
      health_check_grace_period = 300
      health_check_type         = "ELB"
      spot_instance_enabled     = false  # Stable for testing
    }

    background_workers = {
      instance_type             = "t3.large"
      min_capacity              = 1
      max_capacity              = 3
      desired_capacity          = 1
      health_check_grace_period = 600
      health_check_type         = "EC2"
      spot_instance_enabled     = true   # Can use spot for workers
    }
  }

  # Database configurations (production-like testing)
  databases = {
    primary_database = {
      engine                       = "postgres"
      engine_version               = "15.8"        # Latest stable version
      instance_class               = "db.t3.small" # Appropriate for staging
      allocated_storage            = 100           # Reasonable for testing
      max_allocated_storage        = 500           # Room for growth testing
      multi_az                     = true          # Test HA scenarios
      backup_retention_period      = 14            # Test backup/restore
      backup_window                = "03:00-04:00"
      maintenance_window           = "sat:02:00-sat:03:00"
      performance_insights_enabled = true          # Test performance monitoring
      monitoring_interval          = 60            # Enhanced monitoring
      deletion_protection          = false         # Easier to manage
      storage_type                 = "gp3"         # Latest storage type
      skip_final_snapshot          = false         # Test snapshot creation
    }

    # Optional read replica for testing
    read_replica = {
      instance_class               = "db.t3.micro"  # Smaller replica
      publicly_accessible          = false
      auto_minor_version_upgrade   = false
      backup_retention_period      = 0
      performance_insights_enabled = false
    }

    cache_cluster = {
      engine                     = "redis"
      node_type                  = "cache.t3.small"  # Appropriate for staging
      num_cache_nodes            = 2                 # Test clustering
      parameter_group_name       = "default.redis7"
      port                       = 6379
      subnet_group_name          = "cache-subnet-group"
      automatic_failover_enabled = true             # Test failover
      multi_az_enabled           = true             # Test multi-AZ
      snapshot_retention_limit   = 3                # Test snapshots
      snapshot_window            = "03:00-04:00"
      at_rest_encryption_enabled = true             # Test encryption
      transit_encryption_enabled = true             # Test encryption
    }
  }

  # Network configurations (production-like)
  networking = {
    # Load balancer settings - production-like
    load_balancer = {
      type                             = "application"
      scheme                           = "internet-facing"
      idle_timeout                     = 60
      deletion_protection              = false              # Easier to manage
      enable_cross_zone_load_balancing = true              # Test load balancing
      enable_http2                     = true
      enable_deletion_protection       = false

      # SSL/TLS settings - test certificates
      ssl_policy      = "ELBSecurityPolicy-TLS-1-2-2017-01"
      certificate_arn = null  # Use staging certificates
    }

    # Security group rules - production-like but with staging access
    security_groups = {
      web_tier = {
        ingress_rules = [
          {
            from_port   = 443
            to_port     = 443
            protocol    = "tcp"
            cidr_blocks = [var.vpc_cidr]
            description = "HTTPS from internet"
          },
          {
            from_port   = 80
            to_port     = 80
            protocol    = "tcp"
            cidr_blocks = [var.vpc_cidr]
            description = "HTTP redirect to HTTPS"
          },
          {
            from_port   = 8080
            to_port     = 8080
            protocol    = "tcp"
            cidr_blocks = [var.vpc_cidr]
            description = "Staging testing port"
          }
        ]
      }

      app_tier = {
        ingress_rules = [
          {
            from_port   = 22
            to_port     = 22
            protocol    = "tcp"
            cidr_blocks = ["10.60.0.0/16"]  # VPC access for debugging
            description = "SSH access for staging debugging"
          },
          {
            from_port                = 8080
            to_port                  = 8080
            protocol                 = "tcp"
            source_security_group_id = "web_tier_sg"
            description              = "App port from web tier"
          }
        ]
      }

      database_tier = {
        ingress_rules = [
          {
            from_port                = 5432
            to_port                  = 5432
            protocol                 = "tcp"
            source_security_group_id = "app_tier_sg"
            description              = "PostgreSQL from app tier"
          },
          {
            from_port   = 5432
            to_port     = 5432
            protocol    = "tcp"
            cidr_blocks = ["10.60.0.0/16"]  # VPC access for testing
            description = "PostgreSQL from VPC for testing"
          }
        ]
      }
    }
  }

  # Auto-shutdown configuration - disabled for continuous testing
  auto_shutdown = {
    enabled = false  # Keep staging running for continuous testing
    schedule = {
      # Optional weekend shutdown for cost savings
      shutdown_cron = "0 20 * * FRI"    # Friday 8 PM
      startup_cron  = "0 8 * * MON"     # Monday 8 AM
      weekend_shutdown = false          # Keep running for testing
    }
    resources = []  # No auto-shutdown for staging
  }
}
