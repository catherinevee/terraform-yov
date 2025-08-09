# =============================================================================
# AWS US-EAST-1 REGION CONFIGURATION
# =============================================================================
# This file contains region-specific configurations for us-east-1

locals {
  # Region identification
  aws_region       = "us-east-1"
  aws_region_short = "use1"
  aws_region_name  = "N. Virginia"

  # Availability zones for this region
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

  # Regional network configuration
  regional_networking = {
    # VPC CIDR blocks for different environments
    vpc_cidrs = {
      dev     = "10.10.0.0/16" # 10.10.0.0 - 10.10.255.255 (65,536 IPs)
      staging = "10.20.0.0/16" # 10.20.0.0 - 10.20.255.255 (65,536 IPs)
      prod    = "10.30.0.0/16" # 10.30.0.0 - 10.30.255.255 (65,536 IPs)
    }

    # Subnet allocation strategy
    subnet_strategy = {
      public_subnets = {
        dev     = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
        staging = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]
        prod    = ["10.30.1.0/24", "10.30.2.0/24", "10.30.3.0/24"]
      }
      private_subnets = {
        dev     = ["10.10.11.0/24", "10.10.12.0/24", "10.10.13.0/24"]
        staging = ["10.20.11.0/24", "10.20.12.0/24", "10.20.13.0/24"]
        prod    = ["10.30.11.0/24", "10.30.12.0/24", "10.30.13.0/24"]
      }
      database_subnets = {
        dev     = ["10.10.21.0/24", "10.10.22.0/24", "10.10.23.0/24"]
        staging = ["10.20.21.0/24", "10.20.22.0/24", "10.20.23.0/24"]
        prod    = ["10.30.21.0/24", "10.30.22.0/24", "10.30.23.0/24"]
      }
      intra_subnets = {
        dev     = ["10.10.31.0/24", "10.10.32.0/24", "10.10.33.0/24"]
        staging = ["10.20.31.0/24", "10.20.32.0/24", "10.20.33.0/24"]
        prod    = ["10.30.31.0/24", "10.30.32.0/24", "10.30.33.0/24"]
      }
    }
  }

  # Regional service configuration
  regional_services = {
    # CloudFront edge locations (us-east-1 is required for CloudFront)
    cloudfront_enabled = true

    # Route53 hosted zones (global service, managed from us-east-1)
    route53_enabled = true

    # ACM certificates for CloudFront (must be in us-east-1)
    acm_cloudfront_enabled = true

    # WAF (global service, managed from us-east-1)
    waf_enabled = true

    # Shield Advanced
    shield_advanced_enabled = false # Enable in production if needed
  }

  # Regional compliance and data residency
  compliance_settings = {
    data_residency     = "US"
    sovereign_cloud    = false
    gdpr_applicable    = false
    ccpa_applicable    = true
    sox_compliance     = true
    pci_dss_applicable = true
    hipaa_applicable   = false
  }

  # Regional backup and disaster recovery
  disaster_recovery = {
    # Secondary region for DR
    dr_region = "us-west-2"

    # Backup regions
    backup_regions = ["us-west-2", "eu-west-1"]

    # Cross-region replication settings
    cross_region_replication = {
      s3_enabled          = true
      rds_enabled         = true
      dynamodb_enabled    = true
      elasticache_enabled = false
    }

    # RPO/RTO targets
    rpo_hours = 1
    rto_hours = 4
  }

  # Regional instance and service limits
  regional_limits = {
    # EC2 instance limits per environment
    ec2_limits = {
      dev = {
        max_instances      = 20
        max_vcpus          = 100
        max_spot_instances = 15
      }
      staging = {
        max_instances      = 50
        max_vcpus          = 250
        max_spot_instances = 35
      }
      prod = {
        max_instances      = 200
        max_vcpus          = 1000
        max_spot_instances = 0
      }
    }

    # RDS limits
    rds_limits = {
      max_db_instances  = 20
      max_db_clusters   = 10
      max_read_replicas = 15
    }

    # VPC limits
    vpc_limits = {
      max_vpcs            = 10
      max_subnets_per_vpc = 20
      max_route_tables    = 50
      max_security_groups = 100
    }
  }

  # Cost optimization for this region
  cost_optimization = {
    # Preferred instance families for cost optimization
    preferred_instance_families = ["t3", "m5", "c5", "r5"]

    # Spot instance configuration
    spot_instance_config = {
      max_price_percent_of_on_demand = 70
      diversification_strategy       = "diversified"
      allocation_strategy            = "lowest-price"
    }

    # Reserved instance recommendations
    reserved_instance_strategy = {
      term           = "1year"
      payment_option = "no-upfront"
      offering_class = "standard"
    }

    # Auto scaling policies
    auto_scaling_defaults = {
      scale_up_cooldown      = 300
      scale_down_cooldown    = 300
      target_cpu_utilization = 70
      min_capacity           = 1
      max_capacity           = 10
    }
  }

  # Regional monitoring configuration
  monitoring_config = {
    # CloudWatch settings
    cloudwatch = {
      default_retention_days = 30
      detailed_monitoring    = true
      enhanced_monitoring    = false
    }

    # VPC Flow Logs
    flow_logs = {
      enabled          = true
      traffic_type     = "ALL"
      destination_type = "cloud-watch-logs"
      retention_days   = 14
    }

    # AWS Config
    config = {
      enabled            = true
      delivery_frequency = "Daily"
      snapshot_frequency = "Daily"
    }

    # CloudTrail
    cloudtrail = {
      enabled                       = true
      include_global_service_events = true
      is_multi_region_trail         = true
      enable_log_file_validation    = true
    }
  }

  # Regional security configuration
  security_config = {
    # GuardDuty
    guardduty = {
      enabled                      = true
      finding_publishing_frequency = "FIFTEEN_MINUTES"
      datasources = {
        s3_logs            = true
        kubernetes         = true
        malware_protection = true
      }
    }

    # Security Hub
    security_hub = {
      enabled                  = true
      enable_default_standards = true
      standards = [
        "aws-foundational-security-standard",
        "cis-aws-foundations-benchmark",
        "pci-dss"
      ]
    }

    # Inspector
    inspector = {
      enabled            = true
      assessment_targets = ["ec2", "ecr"]
    }

    # Systems Manager
    ssm = {
      enabled                      = true
      patch_baseline_auto_approval = false
      maintenance_window_schedule  = "cron(0 2 ? * SUN *)" # Sundays at 2 AM
    }
  }
}
