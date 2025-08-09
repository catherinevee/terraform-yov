# =============================================================================
# PRODUCTION PRIMARY RDS DATABASE
# =============================================================================
# This configuration deploys the primary production PostgreSQL database
# with high availability, enhanced monitoring, and cross-region backup

# Include root configuration (backend, providers)
include "root" {
  path   = find_in_parent_folders("terragrunt.hcl")
  expose = true
}

# Include environment-common RDS configuration
include "envcommon" {
  path           = "${dirname(find_in_parent_folders("terragrunt.hcl"))}/_envcommon/data/rds.hcl"
  expose         = true
  merge_strategy = "deep"
}

# Include region configuration
include "region" {
  path   = find_in_parent_folders("region.hcl")
  expose = true
}

# Include environment configuration
include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

# Include account configuration
include "account" {
  path   = find_in_parent_folders("account.hcl")
  expose = true
}

locals {
  # Merge all exposed configurations
  root_vars    = include.root.locals
  env_vars     = include.env.locals
  region_vars  = include.region.locals
  account_vars = include.account.locals
  common_vars  = include.envcommon.locals

  # Production-specific overrides
  environment   = "prod"
  region        = "eu-central-2"
  db_identifier = "prod-euc2-primary-db"

  # Production-specific database configuration
  production_db_config = local.env_vars.databases.primary_database
}

# Dependencies
dependency "vpc" {
  config_path = "../../networking/vpc"

  mock_outputs = {
    vpc_id                     = "vpc-0123456789abcdef0"
    database_subnets           = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1", "subnet-0123456789abcdef2"]
    database_subnet_group_name = "prod-euc2-vpc-db"
    private_subnets            = ["subnet-private-0123456789abcdef0", "subnet-private-0123456789abcdef1"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "fmt", "show"]
}

dependency "kms" {
  config_path = "../../security/kms-app"

  mock_outputs = {
    key_arn = "arn:aws:kms:eu-central-2:345678901234:key/12345678-1234-1234-1234-123456789012"
    key_id  = "12345678-1234-1234-1234-123456789012"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "fmt", "show"]
}

# Module source from Terraform Registry
terraform {
  source = "tfr:///terraform-aws-modules/rds/aws?version=6.1.0"
}

# Production-specific RDS inputs
inputs = merge(
  include.envcommon.inputs,
  {
    # Production database identifier
    identifier = local.db_identifier

    # Production engine configuration from env.hcl
    engine               = local.production_db_config.engine
    engine_version       = local.production_db_config.engine_version
    family               = "postgres15"
    major_engine_version = "15"

    # Production instance configuration
    instance_class        = local.production_db_config.instance_class
    allocated_storage     = local.production_db_config.allocated_storage
    max_allocated_storage = local.production_db_config.max_allocated_storage
    storage_type          = "io2" # Higher performance storage for production
    iops                  = 30000 # High IOPS for production workloads
    storage_throughput    = 1000

    # Production database name and credentials
    db_name                       = "yov_production"
    username                      = "yov_admin"
    password                      = null # Auto-generated and stored in Secrets Manager
    manage_master_user_password   = true
    master_user_secret_kms_key_id = dependency.kms.outputs.key_arn

    # High availability for production
    multi_az          = local.production_db_config.multi_az
    availability_zone = null # Let AWS choose for optimal placement

    # Network configuration with enhanced security
    vpc_id                 = dependency.vpc.outputs.vpc_id
    subnet_ids             = dependency.vpc.outputs.database_subnets
    db_subnet_group_name   = dependency.vpc.outputs.database_subnet_group_name
    create_db_subnet_group = false # Use existing from VPC module

    # Enhanced security configuration
    publicly_accessible = false
    port                = 5432

    # Custom security group for production
    vpc_security_group_ids     = []
    create_db_security_group   = true
    security_group_name        = "${local.db_identifier}-sg"
    security_group_description = "Production PostgreSQL database security group"
    security_group_rules = {
      # PostgreSQL access from private subnets only
      postgres_ingress_private = {
        type        = "ingress"
        from_port   = 5432
        to_port     = 5432
        protocol    = "tcp"
        cidr_blocks = ["10.60.11.0/24", "10.60.12.0/24", "10.60.13.0/24"] # Private subnets only
        description = "PostgreSQL access from application tier"
      }

      # PostgreSQL access from EKS cluster (if deployed)
      postgres_ingress_eks = {
        type        = "ingress"
        from_port   = 5432
        to_port     = 5432
        protocol    = "tcp"
        cidr_blocks = ["10.60.31.0/24", "10.60.32.0/24", "10.60.33.0/24"] # Intra subnets for EKS
        description = "PostgreSQL access from EKS cluster"
      }
    }

    # Production encryption
    storage_encrypted = true
    kms_key_id        = dependency.kms.outputs.key_arn

    # Production backup configuration
    backup_retention_period  = local.production_db_config.backup_retention_period
    backup_window            = local.production_db_config.backup_window
    maintenance_window       = local.production_db_config.maintenance_window
    copy_tags_to_snapshot    = true
    delete_automated_backups = false

    # Cross-region backup for disaster recovery
    backup_cross_region_destinations = ["eu-west-1", "eu-central-1"]

    # Production deletion protection
    deletion_protection              = local.production_db_config.deletion_protection
    skip_final_snapshot              = false
    final_snapshot_identifier_prefix = "prod-final-snapshot"

    # Enhanced monitoring for production
    performance_insights_enabled          = local.production_db_config.performance_insights_enabled
    performance_insights_retention_period = 31 # 31 days retention
    performance_insights_kms_key_id       = dependency.kms.outputs.key_arn

    # CloudWatch logs configuration
    enabled_cloudwatch_logs_exports        = ["postgresql", "upgrade"]
    cloudwatch_log_group_retention_in_days = 90
    cloudwatch_log_group_kms_key_id        = dependency.kms.outputs.key_arn

    # Enhanced monitoring every 15 seconds for production
    monitoring_interval = local.production_db_config.monitoring_interval
    monitoring_role_arn = "arn:aws:iam::345678901234:role/YOVRDSEnhancedMonitoringRole"

    # Production-optimized parameter group
    create_db_parameter_group   = true
    parameter_group_name        = "prod-euc2-postgres15-optimized"
    parameter_group_description = "Production-optimized PostgreSQL 15 parameter group"
    parameters = [
      # Connection settings
      {
        name  = "max_connections"
        value = "500" # Higher connection limit for production
      },

      # Memory settings optimized for r6g.2xlarge (64GB RAM)
      {
        name  = "shared_buffers"
        value = "16GB" # 25% of total memory
      },
      {
        name  = "effective_cache_size"
        value = "48GB" # 75% of total memory
      },
      {
        name  = "work_mem"
        value = "128MB" # For complex queries
      },
      {
        name  = "maintenance_work_mem"
        value = "2GB" # For maintenance operations
      },

      # WAL settings for high write performance
      {
        name  = "wal_buffers"
        value = "64MB"
      },
      {
        name  = "checkpoint_completion_target"
        value = "0.9"
      },
      {
        name  = "max_wal_size"
        value = "4GB"
      },
      {
        name  = "min_wal_size"
        value = "1GB"
      },

      # Query planner settings
      {
        name  = "random_page_cost"
        value = "1.1" # Optimized for SSD storage
      },
      {
        name  = "seq_page_cost"
        value = "1.0"
      },
      {
        name  = "effective_io_concurrency"
        value = "200" # For io2 storage
      },

      # Logging settings for production
      {
        name  = "log_statement"
        value = "ddl" # Log DDL statements only
      },
      {
        name  = "log_min_duration_statement"
        value = "5000" # Log queries taking more than 5 seconds
      },
      {
        name  = "log_checkpoints"
        value = "on"
      },
      {
        name  = "log_lock_waits"
        value = "on"
      },
      {
        name  = "log_temp_files"
        value = "0" # Log all temp files
      },
      {
        name  = "log_autovacuum_min_duration"
        value = "1000" # Log autovacuum operations
      },

      # Extensions for monitoring and performance
      {
        name  = "shared_preload_libraries"
        value = "pg_stat_statements,auto_explain,pg_prewarm"
      },
      {
        name  = "pg_stat_statements.track"
        value = "all"
      },
      {
        name  = "pg_stat_statements.max"
        value = "10000"
      },
      {
        name  = "auto_explain.log_min_duration"
        value = "5000"
      },
      {
        name  = "auto_explain.log_analyze"
        value = "true"
      },
      {
        name  = "auto_explain.log_buffers"
        value = "true"
      },
      {
        name  = "auto_explain.log_timing"
        value = "true"
      },

      # Autovacuum settings
      {
        name  = "autovacuum_max_workers"
        value = "6"
      },
      {
        name  = "autovacuum_naptime"
        value = "30s" # More frequent autovacuum
      },
      {
        name  = "autovacuum_vacuum_cost_limit"
        value = "2000"
      },

      # Background writer settings
      {
        name  = "bgwriter_delay"
        value = "50ms"
      },
      {
        name  = "bgwriter_lru_maxpages"
        value = "200"
      }
    ]

    # Production option group
    create_db_option_group   = true
    option_group_name        = "prod-euc2-postgres15-options"
    option_group_description = "Production PostgreSQL 15 option group"
    options                  = [] # PostgreSQL uses extensions instead of options

    # Production-specific tags
    tags = merge(
      include.envcommon.inputs.tags,
      {
        Name               = local.db_identifier
        DatabaseType       = "Primary"
        CriticalityLevel   = "critical"
        DataClassification = "confidential"

        # Production specific
        ProductionDatabase = "true"
        HighAvailability   = "true"
        CrossRegionBackup  = "true"

        # Compliance
        SOXCompliance    = "required"
        PCIDSSCompliance = "level1"
        GDPRCompliance   = "required"
        DataRetention    = "7years"

        # Operational
        MaintenanceWindow   = local.production_db_config.maintenance_window
        BackupWindow        = local.production_db_config.backup_window
        MonitoringEnabled   = "enhanced"
        PerformanceInsights = "enabled"

        # Performance
        StorageType      = "io2"
        IOPS             = "30000"
        InstanceClass    = local.production_db_config.instance_class
        AllocatedStorage = "${local.production_db_config.allocated_storage}GB"

        # Security
        EncryptionAtRest    = "enabled"
        EncryptionInTransit = "required"
        NetworkAccess       = "private-only"
        DeletionProtection  = "enabled"

        # DR and backup
        BackupRetention        = "${local.production_db_config.backup_retention_period}days"
        PointInTimeRecovery    = "enabled"
        CrossRegionReplication = "enabled"

        # Contacts and documentation
        DatabaseAdministrator = "dba-team@yov.com"
        OnCallTeam            = "database-oncall@yov.com"
        DocumentationURL      = "https://wiki.yov.com/databases/production"
        RunbookURL            = "https://runbook.yov.com/databases/production"

        # Cost and billing
        ChargeCode       = "PROD-DATABASE-001"
        CostOptimization = "monitor-optimize"
        BudgetAlert      = "enabled"
        CostReview       = "monthly"
      }
    )
  }
)
