
variable "vpc_cidr" {
  description = "VPC CIDR block for internal access"
  type        = string
  default     = "10.0.0.0/16"
}
# =============================================================================
# PRODUCTION ENVIRONMENT CONFIGURATION - EU-CENTRAL-2
# =============================================================================
# This file contains production-specific configurations including
# environment variables, resource sizing, and production-grade settings

locals {
  # Environment identification
  environment      = "prod"
  environment_full = "production"

  # Environment-specific configurations
  env_config = {
    # Resource sizing for production workloads
    sizing = {
      # EC2 instances
      web_tier_instance_type      = "m5.xlarge"
      app_tier_instance_type      = "c5.2xlarge"
      database_tier_instance_type = "r5.4xlarge"

      # Auto Scaling
      web_tier_min_size     = 3
      web_tier_max_size     = 20
      web_tier_desired_size = 6

      app_tier_min_size     = 3
      app_tier_max_size     = 15
      app_tier_desired_size = 5

      # RDS
      rds_instance_class        = "db.r6g.2xlarge"
      rds_allocated_storage     = 500
      rds_max_allocated_storage = 2000

      # ElastiCache
      elasticache_node_type       = "cache.r6g.xlarge"
      elasticache_num_cache_nodes = 3

      # EKS
      eks_node_instance_types = ["m5.xlarge", "m5.2xlarge"]
      eks_min_nodes           = 3
      eks_max_nodes           = 20
      eks_desired_nodes       = 6
    }

    # Performance and reliability settings
    performance = {
      # Database
      rds_multi_az                              = true
      rds_backup_retention_period               = 30
      rds_backup_window                         = "03:00-04:00"
      rds_maintenance_window                    = "sun:04:00-sun:05:00"
      rds_performance_insights_enabled          = true
      rds_performance_insights_retention_period = 7
      rds_enhanced_monitoring_interval          = 60

      # ElastiCache
      elasticache_automatic_failover_enabled = true
      elasticache_multi_az_enabled           = true
      elasticache_snapshot_retention_limit   = 7
      elasticache_snapshot_window            = "03:00-05:00"

      # Load Balancer
      alb_idle_timeout        = 60
      alb_deletion_protection = true
      alb_access_logs_enabled = true

      # Auto Scaling
      auto_scaling_health_check_type         = "ELB"
      auto_scaling_health_check_grace_period = 300
      auto_scaling_termination_policies      = ["OldestInstance"]
    }

    # Security settings for production
    security = {
      # Encryption
      encryption_at_rest_required    = true
      encryption_in_transit_required = true

      # Access control
      public_subnet_access = false
      ssh_access_enabled   = false
      rdp_access_enabled   = false

      # Network ACLs
      restrict_default_security_group = true
      enable_vpc_flow_logs            = true

      # IAM
      enforce_mfa              = true
      password_policy_enforced = true
      access_key_rotation_days = 90

      # Logging and monitoring
      cloudtrail_enabled   = true
      config_enabled       = true
      guardduty_enabled    = true
      security_hub_enabled = true

      # Backup and recovery
      backup_required        = true
      point_in_time_recovery = true
      cross_region_backup    = true
    }

    # Monitoring and alerting
    monitoring = {
      # CloudWatch
      detailed_monitoring = true
      enhanced_monitoring = true
      log_retention_days  = 90

      # Metrics and alarms
      cpu_alarm_threshold    = 80
      memory_alarm_threshold = 85
      disk_alarm_threshold   = 90

      # Application monitoring
      enable_x_ray_tracing      = true
      enable_container_insights = true

      # Log aggregation
      centralized_logging    = true
      log_forwarding_enabled = true

      # Synthetic monitoring
      canary_monitoring_enabled = true
      health_check_enabled      = true
    }

    # Compliance and governance
    compliance = {
      # Data classification
      data_classification = "confidential"

      # Regulatory compliance
      sox_compliance              = true
      pci_dss_compliance          = true
      gdpr_compliance             = true
      ccpa_compliance             = false # Not applicable in EU
      data_sovereignty_compliance = true
      swiss_data_protection_act   = true

      # Audit requirements
      audit_logging_enabled      = true
      change_management_required = true
      approval_workflow_enabled  = true

      # Data retention (GDPR compliant)
      data_retention_years   = 7
      log_retention_years    = 3
      backup_retention_years = 7
      gdpr_data_portability  = true
      gdpr_right_to_erasure  = true
    }

    # Business continuity
    business_continuity = {
      # High availability
      multi_az_deployment      = true
      cross_region_replication = true

      # Disaster recovery
      rpo_hours            = 1
      rto_hours            = 4
      dr_testing_frequency = "quarterly"

      # Backup strategy
      backup_frequency      = "daily"
      backup_retention_days = 90
      backup_cross_region   = true
      backup_encryption     = true

      # Maintenance windows (CET timezone)
      maintenance_window_day         = "sunday"
      maintenance_window_time        = "04:00-06:00"
      maintenance_notification_hours = 48
    }

    # Cost management
    cost_management = {
      # Resource optimization
      right_sizing_enabled    = true
      unused_resource_cleanup = true

      # Reserved instances
      reserved_instance_coverage_target = 75
      savings_plan_coverage_target      = 50

      # Cost monitoring
      budget_alerts_enabled  = true
      cost_anomaly_detection = true

      # Tagging for cost allocation
      cost_center_tagging_required = true
      project_tagging_required     = true
      owner_tagging_required       = true
    }
  }

  # Environment-specific tags
  environment_tags = {
    Environment         = local.environment
    EnvironmentType     = "production"
    CriticalityLevel    = "high"
    DataClassification  = "confidential"
    BusinessImpact      = "high"
    SLA                 = "99.9%"
    MaintenanceWindow   = "sun:04:00-sun:06:00"
    BackupRequired      = "true"
    MonitoringLevel     = "enhanced"
    ComplianceRequired  = "true"
    DRRequired          = "true"
    EncryptionRequired  = "true"
    DataResidency       = "EU"
    GDPRCompliant       = "true"
    SwissDataProtection = "true"
  }

  # Application-specific configurations
  applications = {
    web_application = {
      instance_type             = "m5.xlarge"
      min_capacity              = 3
      max_capacity              = 20
      desired_capacity          = 6
      health_check_grace_period = 300
      health_check_type         = "ELB"
    }

    api_application = {
      instance_type             = "c5.2xlarge"
      min_capacity              = 3
      max_capacity              = 15
      desired_capacity          = 5
      health_check_grace_period = 300
      health_check_type         = "ELB"
    }

    background_workers = {
      instance_type             = "m5.large"
      min_capacity              = 2
      max_capacity              = 10
      desired_capacity          = 3
      health_check_grace_period = 600
      health_check_type         = "EC2"
    }
  }

  # Database configurations
  databases = {
    primary_database = {
      engine                       = "postgres"
      engine_version               = "15.4"
      instance_class               = "db.r6g.2xlarge"
      allocated_storage            = 500
      max_allocated_storage        = 2000
      multi_az                     = true
      backup_retention_period      = 30
      backup_window                = "03:00-04:00"
      maintenance_window           = "sun:04:00-sun:05:00"
      performance_insights_enabled = true
      monitoring_interval          = 60
      deletion_protection          = true
    }

    read_replica = {
      instance_class               = "db.r6g.xlarge"
      publicly_accessible          = false
      auto_minor_version_upgrade   = false
      backup_retention_period      = 0
      performance_insights_enabled = false
    }

    cache_cluster = {
      engine                     = "redis"
      node_type                  = "cache.r6g.xlarge"
      num_cache_nodes            = 3
      parameter_group_name       = "default.redis7"
      port                       = 6379
      subnet_group_name          = "cache-subnet-group"
      automatic_failover_enabled = true
      multi_az_enabled           = true
      snapshot_retention_limit   = 7
      snapshot_window            = "03:00-05:00"
      at_rest_encryption_enabled = true
      transit_encryption_enabled = true
    }
  }

  # Network configurations
  networking = {
    # Load balancer settings
    load_balancer = {
      type                             = "application"
      scheme                           = "internet-facing"
      idle_timeout                     = 60
      deletion_protection              = true
      enable_cross_zone_load_balancing = true
      enable_http2                     = true
      enable_deletion_protection       = true

      # SSL/TLS settings
      ssl_policy      = "ELBSecurityPolicy-TLS-1-2-2017-01"
      certificate_arn = "arn:aws:acm:eu-central-2:345678901234:certificate/12345678-1234-1234-1234-123456789012"
    }

    # Security group rules
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
          }
        ]
      }

      app_tier = {
        ingress_rules = [
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
          }
        ]
      }
    }
  }
}
