
variable "vpc_cidr" {
  description = "VPC CIDR block for internal access"
  type        = string
  default     = "10.0.0.0/16"
}
# =============================================================================
# DEVELOPMENT ENVIRONMENT CONFIGURATION
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

    # Performance and reliability settings (relaxed for dev)
    performance = {
      # Database - single AZ for cost savings
      rds_multi_az                              = false  # Single AZ for dev
      rds_backup_retention_period               = 7      # Shorter retention
      rds_backup_window                         = "03:00-04:00"
      rds_maintenance_window                    = "sun:04:00-sun:05:00"
      rds_performance_insights_enabled          = false  # Disabled for cost
      rds_performance_insights_retention_period = 7
      rds_enhanced_monitoring_interval          = 0      # Disabled for cost

      # ElastiCache - simpler setup
      elasticache_automatic_failover_enabled = false  # Single node
      elasticache_multi_az_enabled           = false  # Single AZ
      elasticache_snapshot_retention_limit   = 1      # Minimal snapshots
      elasticache_snapshot_window            = "03:00-05:00"

      # Load Balancer - basic settings
      alb_idle_timeout        = 60
      alb_deletion_protection = false  # Easier to tear down dev
      alb_access_logs_enabled = false  # Reduce costs

      # Auto Scaling - more aggressive scaling for cost
      auto_scaling_health_check_type         = "EC2"  # Faster/cheaper than ELB
      auto_scaling_health_check_grace_period = 300
      auto_scaling_termination_policies      = ["OldestInstance"]
    }

    # Security settings for development (balanced security/cost)
    security = {
      # Encryption - basic encryption
      encryption_at_rest_required    = true
      encryption_in_transit_required = false  # Optional for dev

      # Access control - more permissive for dev
      public_subnet_access = true   # Allow for development access
      ssh_access_enabled   = true   # For debugging
      rdp_access_enabled   = false

      # Network ACLs - basic protection
      restrict_default_security_group = false  # More permissive for dev
      enable_vpc_flow_logs            = false  # Disabled for cost

      # IAM - basic policies
      enforce_mfa              = false  # Not required for dev
      password_policy_enforced = false
      access_key_rotation_days = 180    # Longer rotation

      # Logging and monitoring - minimal
      cloudtrail_enabled   = false  # Disabled for cost
      config_enabled       = false  # Disabled for cost
      guardduty_enabled    = false  # Disabled for cost
      security_hub_enabled = false  # Disabled for cost

      # Backup and recovery - minimal
      backup_required        = false  # Not critical for dev
      point_in_time_recovery = false
      cross_region_backup    = false
    }

    # Monitoring and alerting (cost-optimized)
    monitoring = {
      # CloudWatch - basic monitoring
      detailed_monitoring = false  # Basic monitoring only
      enhanced_monitoring = false  # Disabled for cost
      log_retention_days  = 7      # Shorter retention

      # Metrics and alarms - higher thresholds
      cpu_alarm_threshold    = 90  # Less sensitive
      memory_alarm_threshold = 95  # Less sensitive
      disk_alarm_threshold   = 95  # Less sensitive

      # Application monitoring - disabled for cost
      enable_x_ray_tracing      = false
      enable_container_insights = false

      # Log aggregation - disabled for cost
      centralized_logging    = false
      log_forwarding_enabled = false

      # Synthetic monitoring - disabled
      canary_monitoring_enabled = false
      health_check_enabled      = false
    }

    # Compliance and governance (minimal for dev)
    compliance = {
      # Data classification
      data_classification = "public"  # Non-sensitive dev data

      # Regulatory compliance - not required for dev
      sox_compliance     = false
      pci_dss_compliance = false
      gdpr_compliance    = false  # Simplified for dev
      ccpa_compliance    = false

      # Audit requirements - minimal
      audit_logging_enabled      = false
      change_management_required = false
      approval_workflow_enabled  = false

      # Data retention - minimal
      data_retention_years   = 1
      log_retention_years    = 1
      backup_retention_years = 1
    }

    # Business continuity (minimal for dev)
    business_continuity = {
      # High availability - not required
      multi_az_deployment      = false
      cross_region_replication = false

      # Disaster recovery - relaxed
      rpo_hours            = 24  # Daily acceptable for dev
      rto_hours            = 8   # Half day acceptable
      dr_testing_frequency = "annually"

      # Backup strategy - minimal
      backup_frequency      = "weekly"  # Less frequent
      backup_retention_days = 7         # Shorter retention
      backup_cross_region   = false     # Single region
      backup_encryption     = false     # Simplified

      # Maintenance windows - flexible
      maintenance_window_day         = "sunday"
      maintenance_window_time        = "02:00-04:00"  # Earlier, less critical
      maintenance_notification_hours = 24             # Shorter notice
    }

    # Cost management (aggressive cost optimization)
    cost_management = {
      # Resource optimization
      right_sizing_enabled    = true
      unused_resource_cleanup = true

      # Reserved instances - not recommended for dev
      reserved_instance_coverage_target = 0   # Spot/on-demand only
      savings_plan_coverage_target      = 0

      # Cost monitoring
      budget_alerts_enabled  = true
      cost_anomaly_detection = true

      # Tagging for cost allocation
      cost_center_tagging_required = true
      project_tagging_required     = true
      owner_tagging_required       = true

      # Spot instances for cost savings
      spot_instance_usage_target = 80  # Aggressive spot usage for dev
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
    MaintenanceWindow  = "sun:02:00-sun:04:00"
    BackupRequired     = "false"
    MonitoringLevel    = "basic"
    ComplianceRequired = "false"
    DRRequired         = "false"
    EncryptionRequired = "basic"
    CostOptimized      = "true"
    AutoShutdown       = "enabled"  # Shut down overnight/weekends
  }

  # Application-specific configurations (cost-optimized)
  applications = {
    web_application = {
      instance_type             = "t3.medium"
      min_capacity              = 1
      max_capacity              = 2
      desired_capacity          = 1
      health_check_grace_period = 300
      health_check_type         = "EC2"
      spot_instance_enabled     = true  # Use spot for cost savings
    }

    api_application = {
      instance_type             = "t3.large"
      min_capacity              = 1
      max_capacity              = 2
      desired_capacity          = 1
      health_check_grace_period = 300
      health_check_type         = "EC2"
      spot_instance_enabled     = true
    }

    background_workers = {
      instance_type             = "t3.medium"
      min_capacity              = 0  # Can scale to zero
      max_capacity              = 2
      desired_capacity          = 0  # Start with zero
      health_check_grace_period = 600
      health_check_type         = "EC2"
      spot_instance_enabled     = true
    }
  }

  # Database configurations (cost-optimized)
  databases = {
    primary_database = {
      engine                       = "postgres"
      engine_version               = "15.13"
      instance_class               = "db.t3.micro"      # Smallest instance
      allocated_storage            = 20                 # Minimal storage
      max_allocated_storage        = 100               # Limited growth
      multi_az                     = false              # Single AZ
      backup_retention_period      = 7                 # Shorter retention
      backup_window                = "03:00-04:00"
      maintenance_window           = "sun:02:00-sun:03:00"
      performance_insights_enabled = false             # Disabled for cost
      monitoring_interval          = 0                 # No enhanced monitoring
      deletion_protection          = false             # Easy to delete dev
      storage_type                 = "gp2"             # Standard storage
      skip_final_snapshot          = true              # Skip final snapshot
    }

    # No read replica for dev to save costs
    # read_replica = {} # Commented out

    cache_cluster = {
      engine                     = "redis"
      node_type                  = "cache.t3.micro"    # Smallest cache
      num_cache_nodes            = 1                   # Single node
      parameter_group_name       = "default.redis7"
      port                       = 6379
      subnet_group_name          = "cache-subnet-group"
      automatic_failover_enabled = false              # Single node
      multi_az_enabled           = false              # Single AZ
      snapshot_retention_limit   = 1                  # Minimal snapshots
      snapshot_window            = "03:00-04:00"
      at_rest_encryption_enabled = false              # Simplified for dev
      transit_encryption_enabled = false
    }
  }

  # Network configurations (simplified)
  networking = {
    # Load balancer settings - basic
    load_balancer = {
      type                             = "application"
      scheme                           = "internet-facing"
      idle_timeout                     = 60
      deletion_protection              = false              # Easy to delete
      enable_cross_zone_load_balancing = false              # Single AZ
      enable_http2                     = true
      enable_deletion_protection       = false

      # SSL/TLS settings - basic
      ssl_policy      = "ELBSecurityPolicy-TLS-1-2-2017-01"
      certificate_arn = null  # Use self-signed or Let's Encrypt for dev
    }

    # Security group rules - more permissive for dev
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
            description = "HTTP from internet"
          },
          {
            from_port   = 8080
            to_port     = 8080
            protocol    = "tcp"
            cidr_blocks = [var.vpc_cidr]
            description = "Development port"
          }
        ]
      }

      app_tier = {
        ingress_rules = [
          {
            from_port   = 22
            to_port     = 22
            protocol    = "tcp"
            cidr_blocks = [var.vpc_cidr]  # More permissive for dev
            description = "SSH access for debugging"
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
            cidr_blocks = ["10.40.0.0/16"]  # Allow from entire VPC for dev
            description = "PostgreSQL from VPC for development"
          }
        ]
      }
    }
  }

  # Auto-shutdown configuration for cost savings
  auto_shutdown = {
    enabled = true
    schedule = {
      # Shutdown at 6 PM UTC (7 PM CET), start at 7 AM UTC (8 AM CET)
      shutdown_cron = "0 18 * * MON-FRI"  # Weekdays 6 PM
      startup_cron  = "0 7 * * MON-FRI"   # Weekdays 7 AM
      weekend_shutdown = true              # Shutdown weekends completely
    }
    resources = ["ec2", "rds", "elasticache", "eks"]
  }
}
