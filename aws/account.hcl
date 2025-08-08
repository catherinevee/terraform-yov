# =============================================================================
# AWS ACCOUNT CONFIGURATION
# =============================================================================
# This file contains AWS account-specific configurations including
# account IDs, default settings, and account-level resources

locals {
  # AWS Account IDs for each environment
  account_ids = {
    dev = "123456789012"      # Development account
    staging = "234567890123"  # Staging account
    prod = "345678901234"     # Production account
  }
  
  # Organization structure
  organization = {
    management_account_id = "111111111111"
    security_account_id = "222222222222"
    logging_account_id = "333333333333"
    shared_services_account_id = "444444444444"
  }
  
  # Cross-account roles for Terragrunt execution
  execution_roles = {
    dev = "arn:aws:iam::123456789012:role/YOVTerragruntExecutionRole"
    staging = "arn:aws:iam::234567890123:role/YOVTerragruntExecutionRole"
    prod = "arn:aws:iam::345678901234:role/YOVTerragruntExecutionRole"
  }
  
  # Route53 management role (typically in shared services account)
  route53_role = "arn:aws:iam::444444444444:role/YOVTerragruntRoute53Role"
  
  # Security and compliance settings
  security_contact_email = "security@yov.com"
  billing_contact_email = "billing@yov.com"
  operations_contact_email = "ops@yov.com"
  
  # Cost allocation tags - these will be applied to all resources
  cost_allocation_tags = {
    Company = "YOV"
    Division = "Technology"
    Department = "Engineering"
    BillingCode = "TECH-2024"
    CostOptimization = "enabled"
  }
  
  # Security baseline requirements
  security_baseline = {
    enforce_mfa = true
    require_encrypted_storage = true
    enable_cloudtrail = true
    enable_config = true
    enable_guardduty = true
    enable_security_hub = true
    password_policy_enforce = true
    session_timeout_hours = 8
  }
  
  # Backup and disaster recovery settings
  backup_settings = {
    dev = {
      retention_days = 7
      backup_schedule = "weekly"
      cross_region_copy = false
    }
    staging = {
      retention_days = 14
      backup_schedule = "daily"
      cross_region_copy = true
    }
    prod = {
      retention_days = 90
      backup_schedule = "daily"
      cross_region_copy = true
      point_in_time_recovery = true
    }
  }
  
  # Monitoring and alerting configuration
  monitoring_config = {
    dev = {
      detailed_monitoring = false
      log_retention_days = 7
      metric_retention_days = 30
      alerting_enabled = false
    }
    staging = {
      detailed_monitoring = true
      log_retention_days = 30
      metric_retention_days = 90
      alerting_enabled = true
    }
    prod = {
      detailed_monitoring = true
      log_retention_days = 90
      metric_retention_days = 365
      alerting_enabled = true
      enhanced_monitoring = true
    }
  }
  
  # Network ACL and security group default rules
  network_security = {
    allowed_ssh_cidrs = ["10.0.0.0/8"]  # Only internal networks
    allowed_rdp_cidrs = ["10.0.0.0/8"]  # Only internal networks
    allowed_management_cidrs = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
    deny_all_outbound_by_default = false
    enable_vpc_flow_logs = true
    flow_logs_retention_days = 14
  }
  
  # Trusted AWS services for cross-service access
  trusted_services = [
    "cloudformation.amazonaws.com",
    "ec2.amazonaws.com",
    "ecs-tasks.amazonaws.com",
    "eks.amazonaws.com",
    "lambda.amazonaws.com",
    "rds.amazonaws.com",
    "elasticloadbalancing.amazonaws.com"
  ]
  
  # KMS key policies and encryption settings
  encryption_settings = {
    default_kms_key_policy = {
      enable_key_rotation = true
      key_rotation_period_days = 365
      key_usage = "ENCRYPT_DECRYPT"
      key_spec = "SYMMETRIC_DEFAULT"
    }
    
    # Service-specific encryption requirements
    service_encryption = {
      s3_default_encryption = "AES256"
      ebs_default_encryption = true
      rds_encryption_required = true
      redshift_encryption_required = true
      elasticsearch_encryption_required = true
    }
  }
  
  # Service quotas and limits
  service_quotas = {
    dev = {
      ec2_instances = 20
      vpc_count = 5
      elastic_ips = 10
      nat_gateways = 3
      load_balancers = 5
    }
    staging = {
      ec2_instances = 50
      vpc_count = 10
      elastic_ips = 20
      nat_gateways = 6
      load_balancers = 10
    }
    prod = {
      ec2_instances = 200
      vpc_count = 20
      elastic_ips = 50
      nat_gateways = 15
      load_balancers = 25
    }
  }
  
  # Reserved instance and savings plan strategy
  cost_optimization = {
    dev = {
      use_spot_instances = true
      spot_max_price_percent = 50
      reserved_instance_coverage = 0
      savings_plan_coverage = 0
    }
    staging = {
      use_spot_instances = true
      spot_max_price_percent = 70
      reserved_instance_coverage = 25
      savings_plan_coverage = 10
    }
    prod = {
      use_spot_instances = false
      spot_max_price_percent = 0
      reserved_instance_coverage = 75
      savings_plan_coverage = 50
    }
  }
}
