
variable "vpc_cidr" {
  description = "VPC CIDR block for internal access"
  type        = string
  default     = "10.0.0.0/16"
}
# =============================================================================
# DEVELOPMENT SECURITY CONFIGURATION
# =============================================================================
# Security resources for eu-central-2 development environment

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
  
  # Security configuration for development (relaxed but secure)
  security_config = {
    # KMS configuration (cost-optimized)
    kms = {
      # Single KMS key for all services to reduce costs
      create_ebs_key     = true
      create_rds_key     = true
      create_s3_key      = true
      create_lambda_key  = false  # Use AWS managed keys
      create_logs_key    = false  # Use AWS managed keys
      create_backup_key  = false  # No backup in dev
      
      # Key rotation (less frequent for dev)
      enable_key_rotation = true
      rotation_period_days = 365  # Annual rotation for dev
      
      # Key deletion (shorter window for dev)
      deletion_window_in_days = 7  # Shorter window for faster cleanup
    }
    
    # Security groups for development workloads
    security_groups = {
      # Web tier - more permissive for development
      web_tier = {
        name_prefix = "dev-euc2-web"
        description = "Security group for web tier in development"
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
          },
          {
            from_port   = 3000
            to_port     = 3000
            protocol    = "tcp"
            cidr_blocks = [var.vpc_cidr]
            description = "React dev server"
          },
          {
            from_port   = 8081
            to_port     = 8081
            protocol    = "tcp"
            cidr_blocks = [var.vpc_cidr]
            description = "Additional dev port"
          }
        ]
        egress_rules = [
          {
            from_port   = 0
            to_port     = 0
            protocol    = "-1"
            cidr_blocks = [var.vpc_cidr]
            description = "All outbound traffic"
          }
        ]
      }
      
      # Application tier - allow SSH for debugging
      app_tier = {
        name_prefix = "dev-euc2-app"
        description = "Security group for application tier in development"
        ingress_rules = [
          {
            from_port   = 22
            to_port     = 22
            protocol    = "tcp"
            cidr_blocks = [var.vpc_cidr]  # More permissive for dev debugging
            description = "SSH access for debugging"
          },
          {
            from_port                = 8080
            to_port                  = 8080
            protocol                 = "tcp"
            source_security_group_id = null  # Will be set to web tier SG
            description              = "Application port from web tier"
          },
          {
            from_port                = 8081
            to_port                  = 8081
            protocol                 = "tcp"
            source_security_group_id = null  # Will be set to web tier SG
            description              = "Secondary app port from web tier"
          },
          {
            from_port   = 9090
            to_port     = 9090
            protocol    = "tcp"
            cidr_blocks = ["10.40.0.0/16"]
            description = "Metrics endpoint from VPC"
          }
        ]
        egress_rules = [
          {
            from_port   = 0
            to_port     = 0
            protocol    = "-1"
            cidr_blocks = [var.vpc_cidr]
            description = "All outbound traffic"
          }
        ]
      }
      
      # Database tier - allow VPC access for development
      database_tier = {
        name_prefix = "dev-euc2-db"
        description = "Security group for database tier in development"
        ingress_rules = [
          {
            from_port   = 5432
            to_port     = 5432
            protocol    = "tcp"
            cidr_blocks = ["10.40.0.0/16"]  # Allow from entire VPC for dev
            description = "PostgreSQL from VPC"
          },
          {
            from_port                = 5432
            to_port                  = 5432
            protocol                 = "tcp"
            source_security_group_id = null  # Will be set to app tier SG
            description              = "PostgreSQL from application tier"
          },
          {
            from_port   = 6379
            to_port     = 6379
            protocol    = "tcp"
            cidr_blocks = ["10.40.0.0/16"]
            description = "Redis from VPC"
          }
        ]
        egress_rules = []  # No outbound for database tier
      }
      
      # EKS cluster security group
      eks_cluster = {
        name_prefix = "dev-euc2-eks-cluster"
        description = "Security group for EKS cluster in development"
        ingress_rules = [
          {
            from_port   = 443
            to_port     = 443
            protocol    = "tcp"
            cidr_blocks = ["10.40.0.0/16"]
            description = "HTTPS API access from VPC"
          },
          {
            from_port   = 443
            to_port     = 443
            protocol    = "tcp"
            cidr_blocks = [var.vpc_cidr]  # More permissive for dev
            description = "HTTPS API access for development"
          }
        ]
        egress_rules = [
          {
            from_port   = 0
            to_port     = 0
            protocol    = "-1"
            cidr_blocks = [var.vpc_cidr]
            description = "All outbound traffic"
          }
        ]
      }
      
      # EKS node group security group
      eks_nodes = {
        name_prefix = "dev-euc2-eks-nodes"
        description = "Security group for EKS nodes in development"
        ingress_rules = [
          {
            from_port                = 0
            to_port                  = 65535
            protocol                 = "tcp"
            source_security_group_id = null  # Will be set to cluster SG
            description              = "All traffic from EKS cluster"
          },
          {
            from_port   = 22
            to_port     = 22
            protocol    = "tcp"
            cidr_blocks = ["10.40.0.0/16"]
            description = "SSH access from VPC"
          },
          {
            from_port   = 30000
            to_port     = 32767
            protocol    = "tcp"
            cidr_blocks = ["10.40.0.0/16"]
            description = "NodePort services from VPC"
          }
        ]
        egress_rules = [
          {
            from_port   = 0
            to_port     = 0
            protocol    = "-1"
            cidr_blocks = [var.vpc_cidr]
            description = "All outbound traffic"
          }
        ]
      }
      
      # Load balancer security group
      alb = {
        name_prefix = "dev-euc2-alb"
        description = "Security group for Application Load Balancer in development"
        ingress_rules = [
          {
            from_port   = 443
            to_port     = 443
            protocol    = "tcp"
            cidr_blocks = ["0.0.0.0/0"]
            description = "HTTPS from internet"
          },
          {
            from_port   = 80
            to_port     = 80
            protocol    = "tcp"
            cidr_blocks = [var.vpc_cidr]
            description = "HTTP from internet"
          }
        ]
        egress_rules = [
          {
            from_port   = 0
            to_port     = 0
            protocol    = "-1"
            cidr_blocks = ["10.40.0.0/16"]
            description = "All traffic to VPC"
          }
        ]
      }
    }
    
    # WAF configuration (basic for development)
    waf = {
      enabled = false  # Disabled for cost savings in dev
      
      # If enabled, basic rules
      rules = {
        rate_limit_per_ip = 2000  # Higher limit for dev
        geo_blocking = []         # No geo blocking for dev
        ip_whitelist = []         # No IP restrictions for dev
        sql_injection_protection = true
        xss_protection = true
        size_restriction = true
      }
    }
    
    # Network ACLs (basic for development)
    network_acls = {
      # More permissive NACLs for development
      custom_nacls = false  # Use default NACLs for simplicity
      
      # If custom NACLs are needed
      public_nacl_rules = [
        {
          rule_number = 100
          protocol    = "tcp"
          rule_action = "allow"
          from_port   = 80
          to_port     = 80
          cidr_block  = "0.0.0.0/0"
        },
        {
          rule_number = 110
          protocol    = "tcp"
          rule_action = "allow"
          from_port   = 443
          to_port     = 443
          cidr_block  = "0.0.0.0/0"
        },
        {
          rule_number = 120
          protocol    = "tcp"
          rule_action = "allow"
          from_port   = 1024
          to_port     = 65535
          cidr_block  = "0.0.0.0/0"
        }
      ]
    }
  }
}

# Terraform configuration
terraform {
  source = "${get_parent_terragrunt_dir()}/modules//security"
}

# Input variables for the security module
inputs = {
  # VPC configuration (from networking dependency)
  vpc_id = dependency.networking.outputs.vpc_id
  
  # KMS keys configuration
  kms_keys = {
    ebs = {
      description         = "KMS key for EBS encryption in development"
      enable_key_rotation = local.security_config.kms.enable_key_rotation
      deletion_window     = local.security_config.kms.deletion_window_in_days
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid    = "Enable IAM User Permissions"
            Effect = "Allow"
            Principal = {
              AWS = "arn:aws:iam::${get_aws_account_id()}:root"
            }
            Action   = "kms:*"
            Resource = "*"
          },
          {
            Sid    = "Allow EBS service"
            Effect = "Allow"
            Principal = {
              Service = "ec2.amazonaws.com"
            }
            Action = [
              "kms:Decrypt",
              "kms:GenerateDataKey*",
              "kms:ReEncrypt*",
              "kms:DescribeKey"
            ]
            Resource = "*"
          }
        ]
      })
    }
    
    rds = {
      description         = "KMS key for RDS encryption in development"
      enable_key_rotation = local.security_config.kms.enable_key_rotation
      deletion_window     = local.security_config.kms.deletion_window_in_days
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid    = "Enable IAM User Permissions"
            Effect = "Allow"
            Principal = {
              AWS = "arn:aws:iam::${get_aws_account_id()}:root"
            }
            Action   = "kms:*"
            Resource = "*"
          },
          {
            Sid    = "Allow RDS service"
            Effect = "Allow"
            Principal = {
              Service = "rds.amazonaws.com"
            }
            Action = [
              "kms:Decrypt",
              "kms:GenerateDataKey*",
              "kms:ReEncrypt*",
              "kms:DescribeKey"
            ]
            Resource = "*"
          }
        ]
      })
    }
    
    s3 = {
      description         = "KMS key for S3 encryption in development"
      enable_key_rotation = local.security_config.kms.enable_key_rotation
      deletion_window     = local.security_config.kms.deletion_window_in_days
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid    = "Enable IAM User Permissions"
            Effect = "Allow"
            Principal = {
              AWS = "arn:aws:iam::${get_aws_account_id()}:root"
            }
            Action   = "kms:*"
            Resource = "*"
          },
          {
            Sid    = "Allow S3 service"
            Effect = "Allow"
            Principal = {
              Service = "s3.amazonaws.com"
            }
            Action = [
              "kms:Decrypt",
              "kms:GenerateDataKey*",
              "kms:ReEncrypt*",
              "kms:DescribeKey"
            ]
            Resource = "*"
          }
        ]
      })
    }
  }
  
  # Security groups configuration
  security_groups = local.security_config.security_groups
  
  # WAF configuration (disabled for cost)
  enable_waf = local.security_config.waf.enabled
  
  # Network ACLs (use defaults)
  create_custom_nacls = local.security_config.network_acls.custom_nacls
  
  # Tags
  tags = merge(
    local.env_vars.locals.environment_tags,
    {
      Name        = "dev-euc2-security"
      Component   = "security"
      Module      = "security"
      Purpose     = "development-security"
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
