# =============================================================================
# DEVELOPMENT RDS DATABASE CONFIGURATION - US-EAST-1
# =============================================================================
# Cost-optimized PostgreSQL database for development environment

# Include root configuration (backend, providers)
include "root" {
  path   = find_in_parent_folders("terragrunt.hcl")
  expose = true
}

locals {
  # Read configuration files directly
  region_config = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_config    = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  # Development-specific overrides
  environment = "dev"
  region      = "us-east-1"
}

# Use RDS module
terraform {
  source = "tfr:///terraform-aws-modules/rds/aws?version=6.7.0"
}

# Development-specific RDS inputs
inputs = {
  # Basic identification
  identifier             = "dev-use1-postgres"
  identifier_prefix      = null
  custom_iam_instance_profile = null
  
  # Engine configuration - cost optimized for development
  engine                      = "postgres"
  engine_version             = "15.8"
  instance_class             = "db.t3.micro"  # Smallest instance for development
  allocated_storage          = 20             # Minimal storage
  max_allocated_storage      = 100            # Allow some growth
  storage_type               = "gp2"          # General purpose SSD (cheaper than gp3)
  storage_encrypted          = true
  kms_key_id                 = dependency.security.outputs.kms_key_ids.rds  # Use dedicated KMS key
  
  # Database configuration
  db_name  = "devdb"
  username = "postgres"
  port     = 5432
  
  # Password management
  create_random_password = true
  random_password_length = 16
  
  # Network & Security
  vpc_security_group_ids = [dependency.security.outputs.security_group_ids.database_tier]
  db_subnet_group_name   = dependency.vpc.outputs.database_subnet_group_name
  publicly_accessible    = false
  
  # Availability & Reliability - minimal for development
  multi_az               = false  # Single AZ for cost savings
  availability_zone      = "us-east-1a"
  
  # Backup & Maintenance - enhanced security for development
  backup_retention_period = 7     # Adequate backup retention
  backup_window          = "03:00-04:00"  # Early morning
  maintenance_window     = "sun:04:00-sun:05:00"
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot  = true
  skip_final_snapshot    = false  # Keep final snapshot for security
  deletion_protection    = true   # Enable deletion protection
  
  # Performance Insights - enabled for security monitoring
  performance_insights_enabled = true
  performance_insights_retention_period = 7
  
  # Monitoring - enhanced for security
  monitoring_interval = 60  # Enable enhanced monitoring
  create_monitoring_role = true
  
  # CloudWatch logs - enabled for security
  enabled_cloudwatch_logs_exports = ["postgresql"]
  
  # Network security
  publicly_accessible = false  # Never publicly accessible
  ca_cert_identifier  = "rds-ca-ecc384-g1"  # Use latest CA certificate
  
  # Blue/Green deployment - disabled for development
  blue_green_update = {}
  
  # Network type
  network_type = "IPV4"
  
  # Tags
  tags = {
    Name           = "dev-use1-postgres"
    Environment    = "dev"
    Region         = "us-east-1"
    ManagedBy      = "terragrunt"
    Terraform      = "true"
    Component      = "database"
    CostCenter     = "development"
    CostOptimized  = "true"
    AutoShutdown   = "enabled"
    EnvironmentType = "development"
    DatabaseEngine = "postgresql"
    DatabaseVersion = "15.8"
  }
}

# Dependencies with enhanced security validation
dependency "vpc" {
  config_path = "../../networking/vpc"
  
  # Enhanced mock outputs for security validation
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "show"]
  mock_outputs_merge_strategy_with_state  = "shallow"
  
  mock_outputs = {
    vpc_id                    = "vpc-mock12345"
    vpc_cidr_block           = "10.50.0.0/16"
    database_subnet_group_name = "mock-db-subnet-group"
    database_subnets          = ["subnet-mock5", "subnet-mock6"]
    private_subnets          = ["subnet-mock3", "subnet-mock4"]
    
    # Security validation outputs
    nat_gateway_ids          = ["nat-mock1"]
    internet_gateway_id      = "igw-mock1"
    default_security_group_id = "sg-mock-default"
  }
  
  skip_outputs = false
}

dependency "security" {
  config_path = "../../security"
  
  # Enhanced security dependency validation
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "show"]
  mock_outputs_merge_strategy_with_state  = "shallow"
  
  mock_outputs = {
    security_group_ids = {
      database_tier = "sg-mock12345"
      web_tier      = "sg-mock23456"
      app_tier      = "sg-mock34567"
      bastion       = "sg-mock45678"
      cache_tier    = "sg-mock56789"
    }
    kms_key_ids = {
      rds = "arn:aws:kms:us-east-1:123456789012:key/mock-rds-key"
      s3  = "arn:aws:kms:us-east-1:123456789012:key/mock-s3-key"
      ebs = "arn:aws:kms:us-east-1:123456789012:key/mock-ebs-key"
    }
    kms_key_arns = {
      rds = "arn:aws:kms:us-east-1:123456789012:key/mock-rds-key"
      s3  = "arn:aws:kms:us-east-1:123456789012:key/mock-s3-key"
      ebs = "arn:aws:kms:us-east-1:123456789012:key/mock-ebs-key"
    }
  }
  
  skip_outputs = false
}
