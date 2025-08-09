# =============================================================================
# DEVELOPMENT DATA CONFIGURATION
# =============================================================================
# Database and data services for eu-central-2 development environment

# Include the regional configuration
include {
  path = find_in_parent_folders()
}

# Include configurations
locals {
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  
  # Extract configurations
  regional_networking = local.region_vars.locals.regional_networking
  env_config    = local.env_vars.locals.env_config
  
  # Data configuration for development (cost-optimized)
  data_config = {
    # RDS configuration (cost-optimized)
    rds = {
      # Primary database (cost-optimized)
      primary = {
        identifier = "dev-euc2-primary-db"
        
        # Engine configuration
        engine         = "postgres"
        engine_version = "15.13"
        family         = "postgres15"
        major_engine_version = "15"
        
        # Instance configuration (cost-optimized)
        instance_class    = "db.t3.micro"  # Smallest instance for dev
        allocated_storage = 20             # Minimal storage
        max_allocated_storage = 100        # Limited auto-scaling
        storage_type      = "gp2"          # Standard storage (cheaper)
        storage_encrypted = true
        kms_key_id       = null            # Will use KMS key from security
        
        # Multi-AZ and backup (cost-optimized)
        multi_az               = false  # Single AZ for cost savings
        backup_retention_period = 7     # Shorter retention
        backup_window          = "03:00-04:00"
        maintenance_window     = "sun:02:00-sun:03:00"
        copy_tags_to_snapshot  = true
        skip_final_snapshot    = false  # Keep final snapshot for security
        deletion_protection    = true   # Enable deletion protection
        
        # Database configuration
        db_name  = "devapp"
        username = "devuser"
        port     = 5432
        
        # Parameter group (basic)
        create_db_parameter_group = true
        parameter_group_name     = "dev-euc2-postgres15"
        parameter_group_description = "Parameter group for PostgreSQL 15 in development"
        parameters = [
          {
            name  = "log_statement"
            value = "all"  # Log all statements for debugging
          },
          {
            name  = "log_min_duration_statement"
            value = "1000"  # Log slow queries (1 second)
          },
          {
            name  = "shared_preload_libraries"
            value = "pg_stat_statements"
          }
        ]
        
        # Option group (basic)
        create_db_option_group = false  # Not needed for PostgreSQL
        
        # Subnet group
        create_db_subnet_group = true
        db_subnet_group_name   = "dev-euc2-db-subnet-group"
        subnet_ids            = null  # Will be set from networking dependency
        
        # Security groups
        vpc_security_group_ids = null  # Will be set from security dependency
        
        # Monitoring (enhanced for security)
        monitoring_interval             = 60    # Enable enhanced monitoring
        monitoring_role_arn            = null   # Will be created automatically
        performance_insights_enabled   = true   # Enable for security monitoring
        performance_insights_retention_period = 7
        create_monitoring_role         = true   # Create monitoring role
        
        # Automated backups
        restore_to_point_in_time = null  # No PITR for dev
        
        # Tags
        tags = {
          Name        = "dev-euc2-primary-db"
          Environment = "development"
          Database    = "primary"
          Engine      = "postgres"
          Version     = "15.13"
          Tier        = "database"
        }
      }
      
      # No read replica for development to save costs
      # read_replica = {} # Commented out for cost savings
    }
    
    # ElastiCache configuration (cost-optimized)
    elasticache = {
      # Redis cache (cost-optimized)
      redis = {
        cluster_id      = "dev-euc2-redis"
        node_type       = "cache.t3.micro"  # Smallest cache instance
        num_cache_nodes = 1                 # Single node
        port            = 6379
        
        # Engine configuration
        engine               = "redis"
        engine_version       = "7.0"
        parameter_group_name = "default.redis7"
        
        # Subnet and security
        subnet_group_name = "dev-euc2-cache-subnet-group"
        subnet_ids       = null  # Will be set from networking dependency
        security_group_ids = null  # Will be set from security dependency
        
        # Availability and backup (cost-optimized)
        availability_zone           = "eu-central-2a"  # Single AZ
        automatic_failover_enabled  = false           # Single node
        multi_az_enabled           = false           # Single AZ
        
        # Backup configuration (minimal)
        snapshot_retention_limit = 1                  # Minimal snapshots
        snapshot_window         = "03:00-04:00"
        
        # Maintenance
        maintenance_window = "sun:02:00-sun:03:00"
        
        # Encryption (disabled for cost)
        at_rest_encryption_enabled = false  # Disabled for cost in dev
        transit_encryption_enabled = false  # Disabled for cost in dev
        auth_token                = null
        
        # Notification
        notification_topic_arn = null
        
        # Logging (disabled for cost)
        log_delivery_configuration = []
        
        # Tags
        tags = {
          Name        = "dev-euc2-redis"
          Environment = "development"
          Service     = "cache"
          Engine      = "redis"
          Version     = "7.0"
          Tier        = "cache"
        }
      }
    }
    
    # S3 configuration (for application data and backups)
    s3 = {
      # Application data bucket
      app_data = {
        bucket_name = "dev-euc2-app-data-${random_id.bucket_suffix.hex}"
        
        # Versioning (disabled for cost)
        versioning_enabled = false
        
        # Encryption
        encryption = {
          sse_algorithm     = "aws:kms"
          kms_master_key_id = null  # Will use KMS key from security
        }
        
        # Lifecycle (aggressive cleanup for dev)
        lifecycle_rules = [
          {
            id     = "delete_old_objects"
            status = "Enabled"
            
            expiration = {
              days = 30  # Delete objects after 30 days
            }
            
            noncurrent_version_expiration = {
              days = 7  # Delete old versions quickly
            }
            
            abort_incomplete_multipart_upload = {
              days_after_initiation = 1
            }
          }
        ]
        
        # Public access (blocked)
        block_public_acls       = true
        block_public_policy     = true
        ignore_public_acls      = true
        restrict_public_buckets = true
        
        # Logging (disabled for cost)
        logging_enabled = false
        
        # Notification (none for dev)
        notification_configuration = {}
        
        # Tags
        tags = {
          Name        = "dev-euc2-app-data"
          Environment = "development"
          Purpose     = "application-data"
          DataType    = "non-critical"
        }
      }
      
      # Backup bucket (minimal)
      backup = {
        bucket_name = "dev-euc2-backup-${random_id.bucket_suffix.hex}"
        
        # Versioning (enabled for backups)
        versioning_enabled = true
        
        # Encryption
        encryption = {
          sse_algorithm     = "aws:kms"
          kms_master_key_id = null
        }
        
        # Lifecycle (short retention for dev)
        lifecycle_rules = [
          {
            id     = "backup_lifecycle"
            status = "Enabled"
            
            expiration = {
              days = 14  # Delete backups after 2 weeks
            }
            
            noncurrent_version_expiration = {
              days = 7
            }
            
            transition = [
              {
                days          = 7
                storage_class = "STANDARD_IA"  # Move to cheaper storage
              }
            ]
          }
        ]
        
        # Public access (blocked)
        block_public_acls       = true
        block_public_policy     = true
        ignore_public_acls      = true
        restrict_public_buckets = true
        
        # Tags
        tags = {
          Name        = "dev-euc2-backup"
          Environment = "development"
          Purpose     = "backup"
          DataType    = "backup"
        }
      }
    }
    
    # Data migration and ETL (minimal for dev)
    data_pipeline = {
      # DMS (disabled for cost savings)
      dms_enabled = false
      
      # Glue (disabled for cost savings)
      glue_enabled = false
      
      # Data lake (disabled for cost savings)
      data_lake_enabled = false
    }
    
    # Search (disabled for cost savings)
    opensearch = {
      enabled = false  # Disable OpenSearch for cost savings in dev
    }
  }
  
  # Random suffix for S3 buckets
  random_id = {
    bucket_suffix = {
      byte_length = 4
    }
  }
}

# Random ID for unique bucket names
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Terraform configuration
terraform {
  source = "${get_parent_terragrunt_dir()}/modules//data"
}

# Input variables for the data module
inputs = {
  # VPC configuration from networking
  vpc_id              = dependency.networking.outputs.vpc_id
  database_subnet_ids = dependency.networking.outputs.database_subnet_ids
  private_subnet_ids  = dependency.networking.outputs.private_subnet_ids
  
  # Security group IDs from security module
  database_security_group_id = dependency.security.outputs.security_group_ids.database_tier
  
  # KMS key IDs from security module
  kms_key_ids = {
    rds = dependency.security.outputs.kms_key_ids.rds
    s3  = dependency.security.outputs.kms_key_ids.s3
  }
  
  # RDS configuration
  rds_config = local.data_config.rds
  
  # ElastiCache configuration
  elasticache_config = local.data_config.elasticache
  
  # S3 configuration
  s3_config = local.data_config.s3
  
  # Random suffix for bucket names
  bucket_suffix = random_id.bucket_suffix.hex
  
  # Tags
  tags = merge(
    local.env_vars.locals.environment_tags,
    {
      Name        = "dev-euc2-data"
      Component   = "data"
      Module      = "data"
      Purpose     = "development-data"
      CostCenter  = "development"
      Region      = "eu-central-2"
    }
  )
}

# Dependencies
dependency "networking" {
  config_path = "../networking"
  
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    vpc_id             = "vpc-mock12345"
    public_subnet_ids  = ["subnet-mock1", "subnet-mock2"]
    private_subnet_ids = ["subnet-mock3", "subnet-mock4"]
    database_subnet_ids = ["subnet-mock5", "subnet-mock6"]
  }
}

dependency "security" {
  config_path = "../security"
  
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    security_group_ids = {
      database_tier = "sg-mock-db"
    }
    kms_key_ids = {
      rds = "arn:aws:kms:eu-central-2:123456789012:key/mock-rds-key"
      s3  = "arn:aws:kms:eu-central-2:123456789012:key/mock-s3-key"
    }
  }
}
