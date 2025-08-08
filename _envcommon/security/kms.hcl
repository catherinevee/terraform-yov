# =============================================================================
# SHARED KMS CONFIGURATION
# =============================================================================
# This file contains reusable KMS key configuration for application-level
# encryption across different services and environments

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
  account_id = local.account_vars.account_ids[local.environment]
  
  # KMS key naming
  key_alias = "${local.environment}-${local.region_vars.aws_region_short}-app-encryption"
  key_description = "Application encryption key for ${local.environment} environment in ${local.region}"
  
  # Environment-specific KMS configurations
  kms_configs = {
    dev = {
      key_usage = "ENCRYPT_DECRYPT"
      key_spec = "SYMMETRIC_DEFAULT"
      enable_key_rotation = true
      rotation_period_in_days = 365
      deletion_window_in_days = 7
      multi_region = false
      
      # Relaxed key policy for development
      enable_cross_account_access = false
      enable_root_access = true
      
      # Tags
      key_purpose = "development-encryption"
      compliance_required = false
    }
    
    staging = {
      key_usage = "ENCRYPT_DECRYPT"
      key_spec = "SYMMETRIC_DEFAULT"
      enable_key_rotation = true
      rotation_period_in_days = 365
      deletion_window_in_days = 14
      multi_region = false
      
      # Moderate key policy for staging
      enable_cross_account_access = false
      enable_root_access = true
      
      # Tags
      key_purpose = "staging-encryption"
      compliance_required = true
    }
    
    prod = {
      key_usage = "ENCRYPT_DECRYPT"
      key_spec = "SYMMETRIC_DEFAULT"
      enable_key_rotation = true
      rotation_period_in_days = 90  # More frequent rotation for production
      deletion_window_in_days = 30
      multi_region = true  # Multi-region for DR
      
      # Strict key policy for production
      enable_cross_account_access = true
      enable_root_access = false  # More restrictive
      
      # Tags
      key_purpose = "production-encryption"
      compliance_required = true
    }
  }
  
  current_kms_config = local.kms_configs[local.environment]
  
  # Service principals that can use this key
  service_principals = [
    "ec2.amazonaws.com",
    "ecs-tasks.amazonaws.com",
    "eks.amazonaws.com",
    "rds.amazonaws.com",
    "s3.amazonaws.com",
    "secretsmanager.amazonaws.com",
    "ssm.amazonaws.com",
    "lambda.amazonaws.com",
    "elasticache.amazonaws.com",
    "elasticfilesystem.amazonaws.com",
    "cloudformation.amazonaws.com",
    "autoscaling.amazonaws.com"
  ]
  
  # Cross-account access for shared services (production only)
  cross_account_principals = local.environment == "prod" ? [
    "arn:aws:iam::${local.account_vars.organization.security_account_id}:root",
    "arn:aws:iam::${local.account_vars.organization.logging_account_id}:root",
    "arn:aws:iam::${local.account_vars.organization.shared_services_account_id}:root"
  ] : []
  
  # IAM roles that can administer the key
  key_administrators = [
    "arn:aws:iam::${local.account_id}:role/YOVTerragruntExecutionRole",
    "arn:aws:iam::${local.account_id}:role/YOVKMSAdminRole",
    "arn:aws:iam::${local.account_id}:role/YOVSecurityRole"
  ]
  
  # IAM roles/users that can use the key
  key_users = concat([
    "arn:aws:iam::${local.account_id}:role/YOVApplicationRole",
    "arn:aws:iam::${local.account_id}:role/YOVEKSNodeRole",
    "arn:aws:iam::${local.account_id}:role/YOVEKSServiceRole",
    "arn:aws:iam::${local.account_id}:role/YOVLambdaExecutionRole",
    "arn:aws:iam::${local.account_id}:role/YOVECSTaskRole"
  ], local.cross_account_principals)
  
  # Generate KMS key policy
  key_policy = jsonencode({
    Version = "2012-10-17"
    Id = "YOVApplicationKeyPolicy"
    Statement = concat([
      # Root account access (conditional)
      local.current_kms_config.enable_root_access ? {
        Sid = "EnableRootUserPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Action = "kms:*"
        Resource = "*"
      } : null,
      # Key administrators
      {
        Sid = "AllowKeyAdministration"
        Effect = "Allow"
        Principal = {
          AWS = local.key_administrators
        }
        Action = [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion",
          "kms:RotateKeyOnDemand"
        ]
        Resource = "*"
      },
      # Key users
      {
        Sid = "AllowKeyUsage"
        Effect = "Allow"
        Principal = {
          AWS = local.key_users
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = [
              "ec2.${local.region}.amazonaws.com",
              "ecs.${local.region}.amazonaws.com",
              "eks.${local.region}.amazonaws.com",
              "rds.${local.region}.amazonaws.com",
              "s3.${local.region}.amazonaws.com",
              "secretsmanager.${local.region}.amazonaws.com",
              "ssm.${local.region}.amazonaws.com",
              "lambda.${local.region}.amazonaws.com",
              "elasticache.${local.region}.amazonaws.com",
              "elasticfilesystem.${local.region}.amazonaws.com"
            ]
          }
        }
      },
      # Service principals
      {
        Sid = "AllowServicePrincipals"
        Effect = "Allow"
        Principal = {
          Service = local.service_principals
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.account_id
          }
        }
      }
    ], local.current_kms_config.enable_cross_account_access ? [{
      # Cross-account access for shared services
      Sid = "AllowCrossAccountAccess"
      Effect = "Allow"
      Principal = {
        AWS = local.cross_account_principals
      }
      Action = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      Resource = "*"
      Condition = {
        StringEquals = {
          "kms:ViaService" = [
            "s3.${local.region}.amazonaws.com",
            "cloudtrail.${local.region}.amazonaws.com",
            "logs.${local.region}.amazonaws.com"
          ]
        }
      }
    }] : [])
  })
}

# Terraform module source
terraform {
  source = "tfr:///terraform-aws-modules/kms/aws?version=2.2.0"
}

# Common inputs for KMS module
inputs = {
  # Key configuration
  description = local.key_description
  key_usage = local.current_kms_config.key_usage
  key_spec = local.current_kms_config.key_spec
  
  # Key policy
  policy = local.key_policy
  
  # Key rotation
  enable_key_rotation = local.current_kms_config.enable_key_rotation
  rotation_period_in_days = local.current_kms_config.rotation_period_in_days
  
  # Deletion protection
  deletion_window_in_days = local.current_kms_config.deletion_window_in_days
  
  # Multi-region key
  multi_region = local.current_kms_config.multi_region
  
  # Key alias
  aliases = ["alias/${local.key_alias}"]
  
  # Grants (for service integrations)
  grants = {
    lambda = {
      grantee_principal = "arn:aws:iam::${local.account_id}:role/YOVLambdaExecutionRole"
      operations = ["Encrypt", "Decrypt", "GenerateDataKey"]
      constraints = {
        encryption_context_equals = {
          Service = "Lambda"
          Environment = local.environment
        }
      }
    }
    
    eks = {
      grantee_principal = "arn:aws:iam::${local.account_id}:role/YOVEKSServiceRole"
      operations = ["Encrypt", "Decrypt", "GenerateDataKey"]
      constraints = {
        encryption_context_equals = {
          Service = "EKS"
          Environment = local.environment
        }
      }
    }
    
    rds = {
      grantee_principal = "arn:aws:iam::${local.account_id}:role/YOVRDSRole"
      operations = ["Encrypt", "Decrypt", "GenerateDataKey"]
      constraints = {
        encryption_context_equals = {
          Service = "RDS"
          Environment = local.environment
        }
      }
    }
  }
  
  # Tags
  tags = merge(
    local.root_vars.common_tags,
    local.env_vars.environment_tags,
    {
      Name = local.key_alias
      Purpose = "ApplicationEncryption"
      KeyType = "Application"
      Compliance = local.current_kms_config.compliance_required ? "Required" : "Optional"
      KeyRotation = "Enabled"
      MultiRegion = local.current_kms_config.multi_region ? "true" : "false"
      
      # Compliance tags
      DataClassification = local.environment == "prod" ? "Confidential" : "Internal"
      EncryptionStandard = "AES-256"
      KeyManagement = "AWS-KMS"
      
      # Operational tags
      BackupKey = local.environment == "prod" ? "Required" : "Optional"
      KeyAdministrator = "SecurityTeam"
      KeyRotationFrequency = "${local.current_kms_config.rotation_period_in_days}days"
      
      # Cost allocation
      Service = "Security"
      Component = "Encryption"
      CostCenter = local.account_vars.cost_allocation_tags.CostCenter
    }
  )
}
