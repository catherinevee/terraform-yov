# =============================================================================
# STAGING RDS DATABASE CONFIGURATION - US-EAST-1
# =============================================================================
# Production-like PostgreSQL database for staging environment with balanced 
# cost optimization and testing capabilities

# Include root configuration (backend, providers)
include "root" {
  path   = find_in_parent_folders("terragrunt.hcl")
  expose = true
}

locals {
  # Read configuration files directly
  region_config = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_config    = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  # Staging-specific overrides
  environment = "staging"
  region      = "us-east-1"
}

# Use RDS module
terraform {
  source = "tfr:///terraform-aws-modules/rds/aws?version=6.7.0"
}

# Staging-specific RDS inputs (production-like for testing)
inputs = {
  # Basic identification
  identifier             = "staging-use1-postgres"
  identifier_prefix      = null
  custom_iam_instance_profile = null
  
  # Engine configuration - production-like but cost-optimized
  engine                      = "postgres"
  engine_version             = "15.8"
  instance_class             = "db.t3.small"    # Larger than dev but smaller than prod
  allocated_storage          = 100              # Reasonable for staging testing
  max_allocated_storage      = 500              # Allow growth for testing
  storage_type               = "gp3"            # Latest storage type for testing
  storage_encrypted          = true
  
  # Database configuration
  db_name  = "stagingdb"
  username = "postgres"
  port     = 5432
  
  # Password management - use AWS Secrets Manager for staging
  manage_master_user_password = true
  master_user_secret_kms_key_id = null  # Use default AWS managed key
  
  # Network & Security - Enhanced for staging
  vpc_security_group_ids = [dependency.security.outputs.security_group_ids.database_tier]
  db_subnet_group_name   = dependency.vpc.outputs.database_subnet_group_name
  publicly_accessible    = false
  ca_cert_identifier     = "rds-ca-ecc384-g1"  # Use latest CA certificate
  
  # KMS encryption
  kms_key_id = dependency.security.outputs.kms_key_ids.rds
  
  # Availability & Reliability - production-like for testing
  multi_az               = true   # Test multi-AZ scenarios
  availability_zone      = null   # Let AWS choose for multi-AZ
  
  # Backup & Maintenance - production-like but shorter retention
  backup_retention_period = 14    # 2 weeks for staging
  backup_window          = "03:00-04:00"  # Early morning EST
  maintenance_window     = "sat:02:00-sat:03:00"  # Saturday maintenance
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot  = true
  skip_final_snapshot    = false  # Take final snapshot for staging
  deletion_protection    = false  # Allow deletion but safer than dev
  
  # Performance Insights - enabled for testing monitoring
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  
  # Monitoring - enhanced for testing
  monitoring_interval = 60  # Enhanced monitoring for staging
  
  # Parameter and option groups - use defaults but allow custom later
  create_db_parameter_group = false
  create_db_option_group   = false
  
  # CloudWatch logs - enabled for testing log collection
  enabled_cloudwatch_logs_exports = ["postgresql"]
  
  # Blue/Green deployment - disabled for staging
  blue_green_update = {}
  
  # Network type
  network_type = "IPV4"
  
  # Tags
  tags = {
    Name              = "staging-use1-postgres"
    Environment       = "staging"
    Region            = "us-east-1"
    ManagedBy         = "terragrunt"
    Terraform         = "true"
    Component         = "database"
    CostCenter        = "staging"
    EnvironmentType   = "staging"
    DatabaseEngine    = "postgresql"
    DatabaseVersion   = "15.8"
    TestingTier       = "database"
    ProductionLike    = "true"
    CostOptimized     = "balanced"
    DataClassification = "internal"
    CCPACompliant     = "true"
    BackupRequired    = "true"
    MonitoringLevel   = "enhanced"
  }
}

# Dependencies
dependency "vpc" {
  config_path = "../../networking/vpc"
  
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    vpc_id                    = "vpc-mock12345"
    database_subnet_group_name = "mock-db-subnet-group"
    database_subnets          = ["subnet-mock7", "subnet-mock8", "subnet-mock9"]
  }
}

dependency "security" {
  config_path = "../../security"
  
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    security_group_ids = {
      web_tier      = "sg-mock1"
      app_tier      = "sg-mock2"
      database_tier = "sg-mock3"
      bastion       = "sg-mock4"
      cache_tier    = "sg-mock5"
      monitoring    = "sg-mock6"
    }
    kms_key_ids = {
      rds     = "arn:aws:kms:us-east-1:123456789012:key/mock-rds-key"
      s3      = "arn:aws:kms:us-east-1:123456789012:key/mock-s3-key"
      ebs     = "arn:aws:kms:us-east-1:123456789012:key/mock-ebs-key"
      secrets = "arn:aws:kms:us-east-1:123456789012:key/mock-secrets-key"
    }
  }
}
