# =============================================================================
# SHARED RDS CONFIGURATION
# =============================================================================
# This file contains reusable RDS configuration for PostgreSQL databases
# with environment-specific customizations and disaster recovery support

# Include hierarchical configurations
include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

include "region" {
  path = find_in_parent_folders("region.hcl")
  expose = true
}

include "env" {
  path = find_in_parent_folders("env.hcl")
  expose = true
}

include "account" {
  path = find_in_parent_folders("account.hcl")
  expose = true
}

locals {
  # Extract values from included configurations
  root_vars = include.root.locals
  region_vars = include.region.locals
  env_vars = include.env.locals
  account_vars = include.account.locals
  
  environment = local.env_vars.environment
  region = local.region_vars.aws_region
  region_short = local.region_vars.aws_region_short
  
  # Database naming
  db_identifier = "${local.environment}-${local.region_short}-primary-db"
  db_subnet_group_name = "${local.environment}-${local.region_short}-db-subnet-group"
  db_parameter_group_name = "${local.environment}-${local.region_short}-postgres15"
  
  # DR configuration based on region
  regions = {
    primary = "us-east-1"
    secondary = "eu-west-1"
    dr = "us-west-2"
  }
  
  is_primary_region = local.region == local.regions.primary
  is_dr_region = local.region == local.regions.dr
  
  # Environment-specific RDS configurations
  rds_configs = {
    dev = {
      # Engine configuration
      engine = "postgres"
      engine_version = "15.4"
      family = "postgres15"
      major_engine_version = "15"
      
      # Instance configuration
      instance_class = "db.t4g.medium"
      allocated_storage = 20
      max_allocated_storage = 100
      storage_type = "gp3"
      storage_iops = 3000
      storage_throughput = 125
      
      # High availability
      multi_az = false
      availability_zone = null
      
      # Backup configuration
      backup_retention_period = 7
      backup_window = "03:00-04:00"
      maintenance_window = "sun:04:00-sun:05:00"
      copy_tags_to_snapshot = true
      delete_automated_backups = true
      
      # Security
      storage_encrypted = true
      deletion_protection = false
      skip_final_snapshot = true
      final_snapshot_identifier_prefix = "${local.environment}-final-snapshot"
      
      # Monitoring
      performance_insights_enabled = false
      performance_insights_retention_period = 0
      enabled_cloudwatch_logs_exports = ["postgresql"]
      monitoring_interval = 0
      monitoring_role_arn = null
      
      # Network
      publicly_accessible = false
      port = 5432
      
      # Parameter group settings
      parameters = [
        {
          name = "log_statement"
          value = "all"
        },
        {
          name = "log_min_duration_statement"
          value = "1000"  # Log queries taking more than 1 second
        },
        {
          name = "shared_preload_libraries"
          value = "pg_stat_statements"
        },
        {
          name = "track_activity_query_size"
          value = "2048"
        }
      ]
      
      # Cross-region backup
      cross_region_backup = false
      backup_regions = []
    }
    
    staging = {
      # Engine configuration
      engine = "postgres"
      engine_version = "15.4"
      family = "postgres15"
      major_engine_version = "15"
      
      # Instance configuration
      instance_class = "db.r6g.large"
      allocated_storage = 100
      max_allocated_storage = 500
      storage_type = "gp3"
      storage_iops = 3000
      storage_throughput = 250
      
      # High availability
      multi_az = true
      availability_zone = null
      
      # Backup configuration
      backup_retention_period = 14
      backup_window = "03:00-04:00"
      maintenance_window = "sun:04:00-sun:05:00"
      copy_tags_to_snapshot = true
      delete_automated_backups = false
      
      # Security
      storage_encrypted = true
      deletion_protection = true
      skip_final_snapshot = false
      final_snapshot_identifier_prefix = "${local.environment}-final-snapshot"
      
      # Monitoring
      performance_insights_enabled = true
      performance_insights_retention_period = 7
      enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
      monitoring_interval = 60
      
      # Network
      publicly_accessible = false
      port = 5432
      
      # Parameter group settings
      parameters = [
        {
          name = "log_statement"
          value = "all"
        },
        {
          name = "log_min_duration_statement"
          value = "500"  # More verbose logging for staging
        },
        {
          name = "shared_preload_libraries"
          value = "pg_stat_statements"
        },
        {
          name = "track_activity_query_size"
          value = "4096"
        },
        {
          name = "log_checkpoints"
          value = "on"
        },
        {
          name = "log_connections"
          value = "on"
        },
        {
          name = "log_disconnections"
          value = "on"
        }
      ]
      
      # Cross-region backup
      cross_region_backup = true
      backup_regions = [local.regions.dr]
    }
    
    prod = {
      # Engine configuration
      engine = "postgres"
      engine_version = "15.4"
      family = "postgres15"
      major_engine_version = "15"
      
      # Instance configuration
      instance_class = "db.r6g.2xlarge"
      allocated_storage = 500
      max_allocated_storage = 2000
      storage_type = "gp3"
      storage_iops = 20000
      storage_throughput = 1000
      
      # High availability
      multi_az = true
      availability_zone = null
      
      # Backup configuration
      backup_retention_period = 30
      backup_window = "03:00-04:00"
      maintenance_window = "sun:04:00-sun:05:00"
      copy_tags_to_snapshot = true
      delete_automated_backups = false
      
      # Security
      storage_encrypted = true
      deletion_protection = true
      skip_final_snapshot = false
      final_snapshot_identifier_prefix = "${local.environment}-final-snapshot"
      
      # Monitoring
      performance_insights_enabled = true
      performance_insights_retention_period = 31  # 31 days for production
      enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
      monitoring_interval = 15  # Enhanced monitoring every 15 seconds
      
      # Network
      publicly_accessible = false
      port = 5432
      
      # Production-optimized parameter group settings
      parameters = [
        {
          name = "shared_preload_libraries"
          value = "pg_stat_statements,auto_explain"
        },
        {
          name = "log_statement"
          value = "ddl"  # Only log DDL statements in production
        },
        {
          name = "log_min_duration_statement"
          value = "2000"  # Log slow queries (2+ seconds)
        },
        {
          name = "track_activity_query_size"
          value = "4096"
        },
        {
          name = "log_checkpoints"
          value = "on"
        },
        {
          name = "log_lock_waits"
          value = "on"
        },
        {
          name = "log_temp_files"
          value = "0"
        },
        {
          name = "checkpoint_completion_target"
          value = "0.9"
        },
        {
          name = "wal_buffers"
          value = "16MB"
        },
        {
          name = "effective_cache_size"
          value = "12GB"  # Adjust based on instance memory
        },
        {
          name = "work_mem"
          value = "64MB"
        },
        {
          name = "maintenance_work_mem"
          value = "1GB"
        },
        {
          name = "max_connections"
          value = "200"
        },
        {
          name = "auto_explain.log_min_duration"
          value = "2000"
        },
        {
          name = "auto_explain.log_analyze"
          value = "true"
        },
        {
          name = "auto_explain.log_buffers"
          value = "true"
        }
      ]
      
      # Cross-region backup for DR
      cross_region_backup = true
      backup_regions = [local.regions.secondary, local.regions.dr]
    }
  }
  
  current_rds_config = local.rds_configs[local.environment]
  
  # Database credentials - using AWS Secrets Manager
  master_username = "postgres"
  master_password = null  # Will be auto-generated and stored in Secrets Manager
  manage_master_user_password = true
  
  # Option group configuration
  option_group_name = "${local.environment}-${local.region_short}-postgres15"
  option_group_options = [
    {
      option_name = "log_fdw"
      option_settings = []
    }
  ]
  
  # Security groups
  allowed_cidr_blocks = [
    local.region_vars.regional_networking.vpc_cidrs[local.environment]
  ]
  
  # CloudWatch log group
  cloudwatch_log_group_name = "/aws/rds/instance/${local.db_identifier}/postgresql"
}

# Dependencies
dependency "vpc" {
  config_path = "${get_terragrunt_dir()}/../../networking/vpc"
  
  mock_outputs = {
    vpc_id = "vpc-mock123456789"
    database_subnets = ["subnet-mock-db-1a", "subnet-mock-db-1b", "subnet-mock-db-1c"]
    database_subnet_group_name = "mock-db-subnet-group"
    private_subnets = ["subnet-mock-private-1a", "subnet-mock-private-1b", "subnet-mock-private-1c"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "fmt", "show"]
}

dependency "kms" {
  config_path = "${get_terragrunt_dir()}/../../security/kms-app"
  
  mock_outputs = {
    key_arn = "arn:aws:kms:us-east-1:123456789012:key/mock-uuid"
    key_id = "mock-uuid"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "fmt", "show"]
}

# Conditional dependency on primary region database for read replicas
dependency "primary_db" {
  config_path = local.is_primary_region ? null : 
    "../../../../${local.regions.primary}/${local.environment}/data/rds-primary"
  
  skip = local.is_primary_region
  
  mock_outputs = {
    db_instance_id = "mock-db-instance"
    db_instance_arn = "arn:aws:rds:us-east-1:123456789012:db:mock"
    db_instance_endpoint = "mock.cluster-ro-abcdef.us-east-1.rds.amazonaws.com"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "fmt", "show"]
}

# Terraform module source
terraform {
  source = "tfr:///terraform-aws-modules/rds/aws?version=6.1.0"
}

# Common inputs for RDS module
inputs = merge(
  local.is_primary_region ? {
    # Primary database configuration
    identifier = local.db_identifier
    
    # Engine configuration
    engine = local.current_rds_config.engine
    engine_version = local.current_rds_config.engine_version
    family = local.current_rds_config.family
    major_engine_version = local.current_rds_config.major_engine_version
    
    # Instance configuration
    instance_class = local.current_rds_config.instance_class
    allocated_storage = local.current_rds_config.allocated_storage
    max_allocated_storage = local.current_rds_config.max_allocated_storage
    storage_type = local.current_rds_config.storage_type
    iops = local.current_rds_config.storage_iops
    storage_throughput = local.current_rds_config.storage_throughput
    
    # Credentials
    db_name = "yov_${local.environment}"
    username = local.master_username
    password = local.master_password
    manage_master_user_password = local.manage_master_user_password
    master_user_secret_kms_key_id = dependency.kms.outputs.key_arn
    
    # High availability
    multi_az = local.current_rds_config.multi_az
    availability_zone = local.current_rds_config.availability_zone
    
    # Network configuration
    vpc_id = dependency.vpc.outputs.vpc_id
    subnet_ids = dependency.vpc.outputs.database_subnets
    db_subnet_group_name = try(dependency.vpc.outputs.database_subnet_group_name, null)
    create_db_subnet_group = try(dependency.vpc.outputs.database_subnet_group_name, null) == null
    
    # Security
    publicly_accessible = local.current_rds_config.publicly_accessible
    port = local.current_rds_config.port
    
    vpc_security_group_ids = []  # Will be created by security group module
    create_db_security_group = true
    security_group_name = "${local.db_identifier}-sg"
    security_group_description = "Security group for ${local.db_identifier}"
    security_group_rules = {
      postgres_ingress = {
        type = "ingress"
        from_port = 5432
        to_port = 5432
        protocol = "tcp"
        cidr_blocks = local.allowed_cidr_blocks
        description = "PostgreSQL access from VPC"
      }
    }
    
    # Encryption
    storage_encrypted = local.current_rds_config.storage_encrypted
    kms_key_id = dependency.kms.outputs.key_arn
    
    # Backup configuration
    backup_retention_period = local.current_rds_config.backup_retention_period
    backup_window = local.current_rds_config.backup_window
    maintenance_window = local.current_rds_config.maintenance_window
    copy_tags_to_snapshot = local.current_rds_config.copy_tags_to_snapshot
    delete_automated_backups = local.current_rds_config.delete_automated_backups
    
    # Cross-region backup
    backup_cross_region_destinations = local.current_rds_config.cross_region_backup ? 
      local.current_rds_config.backup_regions : []
    
    # Deletion protection
    deletion_protection = local.current_rds_config.deletion_protection
    skip_final_snapshot = local.current_rds_config.skip_final_snapshot
    final_snapshot_identifier_prefix = local.current_rds_config.final_snapshot_identifier_prefix
    
    # Monitoring
    performance_insights_enabled = local.current_rds_config.performance_insights_enabled
    performance_insights_retention_period = local.current_rds_config.performance_insights_retention_period
    performance_insights_kms_key_id = dependency.kms.outputs.key_arn
    
    enabled_cloudwatch_logs_exports = local.current_rds_config.enabled_cloudwatch_logs_exports
    cloudwatch_log_group_retention_in_days = local.environment == "prod" ? 90 : 30
    cloudwatch_log_group_kms_key_id = dependency.kms.outputs.key_arn
    
    monitoring_interval = local.current_rds_config.monitoring_interval
    monitoring_role_arn = local.current_rds_config.monitoring_interval > 0 ? 
      "arn:aws:iam::${local.account_vars.account_ids[local.environment]}:role/rds-monitoring-role" : null
    
    # Parameter group
    create_db_parameter_group = true
    parameter_group_name = local.db_parameter_group_name
    parameter_group_description = "Custom parameter group for ${local.db_identifier}"
    parameters = local.current_rds_config.parameters
    
    # Option group
    create_db_option_group = true
    option_group_name = local.option_group_name
    option_group_description = "Custom option group for ${local.db_identifier}"
    options = local.option_group_options
    
  } : {
    # Read replica configuration
    identifier = "${local.environment}-${local.region_short}-replica-db"
    
    # Replicate from primary
    replicate_source_db = dependency.primary_db.outputs.db_instance_arn
    
    # Instance configuration for replica
    instance_class = local.environment == "prod" ? "db.r6g.xlarge" : "db.t4g.medium"
    
    # Network configuration
    vpc_id = dependency.vpc.outputs.vpc_id
    subnet_ids = dependency.vpc.outputs.database_subnets
    
    # Security
    publicly_accessible = false
    
    vpc_security_group_ids = []
    create_db_security_group = true
    security_group_name = "${local.environment}-${local.region_short}-replica-db-sg"
    security_group_description = "Security group for read replica in ${local.region}"
    security_group_rules = {
      postgres_ingress = {
        type = "ingress"
        from_port = 5432
        to_port = 5432
        protocol = "tcp"
        cidr_blocks = local.allowed_cidr_blocks
        description = "PostgreSQL access from VPC"
      }
    }
    
    # Encryption
    storage_encrypted = true
    kms_key_id = dependency.kms.outputs.key_arn
    
    # Read replica specific settings
    skip_final_snapshot = true
    backup_retention_period = 0  # No backups for read replicas
    
    # Monitoring for read replica
    performance_insights_enabled = local.environment == "prod"
    performance_insights_retention_period = local.environment == "prod" ? 7 : 0
    performance_insights_kms_key_id = dependency.kms.outputs.key_arn
    
    monitoring_interval = local.environment == "prod" ? 60 : 0
    monitoring_role_arn = local.environment == "prod" ? 
      "arn:aws:iam::${local.account_vars.account_ids[local.environment]}:role/rds-monitoring-role" : null
  },
  {
    # Common configuration for both primary and replica
    tags = merge(
      local.root_vars.common_tags,
      local.env_vars.environment_tags,
      {
        Name = local.is_primary_region ? local.db_identifier : "${local.environment}-${local.region_short}-replica-db"
        Purpose = "ApplicationDatabase"
        DatabaseRole = local.is_primary_region ? "Primary" : "ReadReplica"
        Engine = "PostgreSQL"
        EngineVersion = local.current_rds_config.engine_version
        
        # Security tags
        EncryptionEnabled = "true"
        DataClassification = local.environment == "prod" ? "Confidential" : "Internal"
        BackupEnabled = local.is_primary_region ? "true" : "false"
        
        # Operational tags
        MaintenanceWindow = local.current_rds_config.maintenance_window
        BackupWindow = local.is_primary_region ? local.current_rds_config.backup_window : "N/A"
        MonitoringEnabled = local.current_rds_config.performance_insights_enabled ? "true" : "false"
        
        # DR tags
        DisasterRecovery = local.is_dr_region ? "true" : "false"
        CrossRegionBackup = local.current_rds_config.cross_region_backup ? "true" : "false"
        
        # Cost tags
        Service = "Database"
        Component = "PostgreSQL"
        CostCenter = local.account_vars.cost_allocation_tags.CostCenter
      }
    )
  }
)
