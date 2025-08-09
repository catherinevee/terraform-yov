# =============================================================================
# RDS POSTGRESQL DATABASE - EU-WEST-1 DEVELOPMENT
# =============================================================================
# This configuration creates a PostgreSQL RDS instance for development
# using terraform registry modules with cost-optimized settings

# Include environment and region configurations
include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = find_in_parent_folders("env.hcl")
}

include "region" {
  path = find_in_parent_folders("region.hcl")
}

# Local variables
locals {
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  
  environment = local.env_vars.locals.environment
  region_config = local.region_vars.locals.region_config
  sizing = local.env_vars.locals.env_config.sizing
}

# Dependencies
dependency "vpc" {
  config_path = "../networking/vpc"
  mock_outputs = {
    vpc_id               = "vpc-mock-id"
    database_subnets     = ["subnet-mock-1", "subnet-mock-2"]
    database_subnet_group = "mock-db-subnet-group"
  }
}

dependency "security" {
  config_path = "../security"
  mock_outputs = {
    database_security_group_id = "sg-mock-database"
  }
}

# Terraform configuration
terraform {
  source = "tfr:///terraform-aws-modules/rds/aws?version=6.7.0"
}

# Input variables for the RDS module
inputs = {
  # Database identification
  identifier = "postgresql-${local.environment}-eu-west-1"

  # Database engine configuration
  engine               = "postgres"
  engine_version       = "15.8"
  family              = "postgres15"
  major_engine_version = "15"
  instance_class      = local.sizing.rds_instance_class

  # Storage configuration - cost-optimized for development
  allocated_storage     = local.sizing.rds_allocated_storage
  max_allocated_storage = local.sizing.rds_max_allocated_storage
  storage_type         = "gp3"
  storage_encrypted    = true
  kms_key_id          = "alias/aws/rds"  # AWS managed key for dev

  # Database configuration
  db_name  = "devdb"
  username = "dbadmin"
  port     = 5432

  # Password management
  manage_master_user_password = true
  master_user_secret_kms_key_id = "alias/aws/rds"

  # High availability - disabled for cost optimization in dev
  multi_az = false

  # Network configuration
  db_subnet_group_name   = dependency.vpc.outputs.database_subnet_group
  vpc_security_group_ids = [dependency.security.outputs.database_security_group_id]

  # Backup configuration - minimal for development
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "Sun:04:00-Sun:05:00"
  
  # Backup final snapshot
  skip_final_snapshot       = true  # Skip for development
  deletion_protection      = false  # Allow deletion in dev
  delete_automated_backups = true   # Clean up backups on deletion

  # Performance Insights - basic for development
  performance_insights_enabled          = false  # Disabled for cost savings
  performance_insights_retention_period = 7

  # Enhanced monitoring - disabled for cost savings
  monitoring_interval = 0

  # Database parameters - development optimized
  parameters = [
    {
      name  = "log_statement"
      value = "all"
    },
    {
      name  = "log_min_duration_statement"
      value = "1000"  # Log slow queries > 1 second
    },
    {
      name  = "shared_preload_libraries"
      value = "pg_stat_statements"
    },
    {
      name  = "max_connections"
      value = "100"  # Lower limit for development
    },
    {
      name  = "work_mem"
      value = "4096"  # 4MB work memory
    }
  ]

  # Option group parameters
  options = []

  # Automated minor version upgrade
  auto_minor_version_upgrade = true

  # Database replica configuration - none for development
  create_db_option_group    = false
  create_db_parameter_group = true

  # CloudWatch log exports
  enabled_cloudwatch_logs_exports = ["postgresql"]
  cloudwatch_log_group_retention_in_days = 7  # Short retention for dev

  # Database subnet group
  create_db_subnet_group = false  # Use VPC module's subnet group

  # Random password configuration
  create_random_password = false  # Use AWS Secrets Manager instead

  # Tags
  tags = merge(
    local.env_vars.locals.environment_tags,
    local.region_vars.locals.region_tags,
    {
      Name              = "postgresql-${local.environment}-eu-west-1"
      Component         = "database"
      DatabaseEngine    = "postgresql"
      DatabaseVersion   = "15.8"
      InstanceClass     = local.sizing.rds_instance_class
      StorageType       = "gp3"
      MultiAZ           = "false"
      Terragrunt        = "true"
      TerraformModule   = "terraform-aws-modules/rds/aws"
      ModuleVersion     = "6.7.0"
      CostOptimized     = "true"
      DevelopmentOnly   = "true"
      PerformanceInsights = "disabled"
      EnhancedMonitoring = "disabled"
    }
  )

  # DB subnet group tags
  db_subnet_group_tags = {
    Name = "db-subnet-group-${local.environment}-eu-west-1"
    Type = "database-subnet-group"
  }

  # DB parameter group tags
  db_parameter_group_tags = {
    Name = "db-parameter-group-${local.environment}-eu-west-1"
    Type = "database-parameter-group"
    Engine = "postgresql"
    Version = "15"
  }

  # Security group tags (if creating one)
  security_group_tags = {
    Name = "rds-sg-${local.environment}-eu-west-1"
    Type = "database-security-group"
  }
}
