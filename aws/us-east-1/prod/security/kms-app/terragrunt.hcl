# =============================================================================
# PRODUCTION KMS APPLICATION ENCRYPTION KEY
# =============================================================================
# This configuration deploys a production-grade KMS key for application
# encryption with enhanced security, compliance, and multi-region support

# Include root configuration (backend, providers)
include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

# Include environment-common KMS configuration
include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/security/kms.hcl"
  expose = true
  merge_strategy = "deep"
}

# Include region configuration
include "region" {
  path = find_in_parent_folders("region.hcl")
  expose = true
}

# Include environment configuration
include "env" {
  path = find_in_parent_folders("env.hcl")
  expose = true
}

# Include account configuration
include "account" {
  path = find_in_parent_folders("account.hcl")
  expose = true
}

locals {
  # Merge all exposed configurations
  root_vars = include.root.locals
  env_vars = include.env.locals
  region_vars = include.region.locals
  account_vars = include.account.locals
  common_vars = include.envcommon.locals
  
  # Production-specific overrides
  environment = "prod"
  region = "us-east-1"
  account_id = "345678901234"
  
  # Production KMS key alias
  key_alias = "prod-use1-app-encryption"
}

# Dependencies - none for KMS as it's foundational

# Module source from Terraform Registry
terraform {
  source = "tfr:///terraform-aws-modules/kms/aws?version=2.2.0"
}

# Production-specific KMS inputs
inputs = merge(
  include.envcommon.inputs,
  {
    # Production-specific description
    description = "Production application encryption key for us-east-1 with SOX/PCI-DSS compliance"
    
    # Enhanced key policy for production with stricter access controls
    policy = jsonencode({
      Version = "2012-10-17"
      Id = "YOVProductionApplicationKeyPolicy"
      Statement = [
        # Key administrators (no root access in production)
        {
          Sid = "AllowKeyAdministration"
          Effect = "Allow"
          Principal = {
            AWS = [
              "arn:aws:iam::345678901234:role/YOVTerragruntExecutionRole",
              "arn:aws:iam::345678901234:role/YOVKMSAdminRole",
              "arn:aws:iam::345678901234:role/YOVSecurityRole"
            ]
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
          Condition = {
            StringEquals = {
              "aws:RequestedRegion" = "us-east-1"
            }
            DateLessThan = {
              "aws:CurrentTime" = "2025-12-31T23:59:59Z"
            }
          }
        },
        # Production application roles
        {
          Sid = "AllowApplicationKeyUsage"
          Effect = "Allow"
          Principal = {
            AWS = [
              "arn:aws:iam::345678901234:role/YOVProductionApplicationRole",
              "arn:aws:iam::345678901234:role/YOVProductionEKSNodeRole",
              "arn:aws:iam::345678901234:role/YOVProductionEKSServiceRole",
              "arn:aws:iam::345678901234:role/YOVProductionLambdaExecutionRole",
              "arn:aws:iam::345678901234:role/YOVProductionECSTaskRole",
              "arn:aws:iam::345678901234:role/YOVProductionRDSRole"
            ]
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
                "ec2.us-east-1.amazonaws.com",
                "ecs.us-east-1.amazonaws.com",
                "eks.us-east-1.amazonaws.com",
                "rds.us-east-1.amazonaws.com",
                "s3.us-east-1.amazonaws.com",
                "secretsmanager.us-east-1.amazonaws.com",
                "ssm.us-east-1.amazonaws.com",
                "lambda.us-east-1.amazonaws.com",
                "elasticache.us-east-1.amazonaws.com",
                "elasticfilesystem.us-east-1.amazonaws.com"
              ]
              "aws:RequestedRegion" = "us-east-1"
            }
            StringLike = {
              "kms:EncryptionContext:Environment" = "prod*"
            }
          }
        },
        # AWS service principals with strict conditions
        {
          Sid = "AllowProductionServicePrincipals"
          Effect = "Allow"
          Principal = {
            Service = [
              "ec2.amazonaws.com",
              "ecs-tasks.amazonaws.com",
              "eks.amazonaws.com",
              "rds.amazonaws.com",
              "s3.amazonaws.com",
              "secretsmanager.amazonaws.com",
              "ssm.amazonaws.com",
              "lambda.amazonaws.com",
              "elasticache.amazonaws.com",
              "elasticfilesystem.amazonaws.com"
            ]
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
              "aws:SourceAccount" = "345678901234"
              "aws:RequestedRegion" = "us-east-1"
            }
            StringLike = {
              "kms:EncryptionContext:Environment" = "prod*"
            }
          }
        },
        # Cross-account access for shared services
        {
          Sid = "AllowCrossAccountSharedServices"
          Effect = "Allow"
          Principal = {
            AWS = [
              "arn:aws:iam::222222222222:root",  # Security account
              "arn:aws:iam::333333333333:root",  # Logging account
              "arn:aws:iam::444444444444:root"   # Shared services account
            ]
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
                "s3.us-east-1.amazonaws.com",
                "cloudtrail.us-east-1.amazonaws.com",
                "logs.us-east-1.amazonaws.com"
              ]
            }
            StringLike = {
              "kms:EncryptionContext:CrossAccount" = "SharedServices"
            }
          }
        },
        # Deny access from untrusted regions
        {
          Sid = "DenyUntrustedRegions"
          Effect = "Deny"
          Principal = "*"
          Action = "kms:*"
          Resource = "*"
          Condition = {
            StringNotEquals = {
              "aws:RequestedRegion" = [
                "us-east-1",
                "us-west-2",
                "eu-west-1"
              ]
            }
          }
        }
      ]
    })
    
    # Production key rotation - more frequent for compliance
    rotation_period_in_days = 90
    
    # Extended deletion window for production
    deletion_window_in_days = 30
    
    # Multi-region for disaster recovery
    multi_region = true
    
    # Production aliases
    aliases = [
      "alias/prod-use1-app-encryption",
      "alias/production-application-key",
      "alias/yov-prod-encryption"
    ]
    
    # Enhanced grants for production services
    grants = {
      eks_production = {
        grantee_principal = "arn:aws:iam::345678901234:role/YOVProductionEKSServiceRole"
        operations = ["Encrypt", "Decrypt", "GenerateDataKey", "CreateGrant"]
        constraints = {
          encryption_context_equals = {
            Service = "EKS"
            Environment = "production"
            Cluster = "prod-use1-eks-main"
          }
        }
        retiring_principal = "arn:aws:iam::345678901234:role/YOVKMSAdminRole"
      }
      
      rds_production = {
        grantee_principal = "arn:aws:iam::345678901234:role/YOVProductionRDSRole"
        operations = ["Encrypt", "Decrypt", "GenerateDataKey"]
        constraints = {
          encryption_context_equals = {
            Service = "RDS"
            Environment = "production"
            Database = "prod-primary-db"
          }
        }
        retiring_principal = "arn:aws:iam::345678901234:role/YOVKMSAdminRole"
      }
      
      lambda_production = {
        grantee_principal = "arn:aws:iam::345678901234:role/YOVProductionLambdaExecutionRole"
        operations = ["Encrypt", "Decrypt", "GenerateDataKey"]
        constraints = {
          encryption_context_equals = {
            Service = "Lambda"
            Environment = "production"
          }
        }
        retiring_principal = "arn:aws:iam::345678901234:role/YOVKMSAdminRole"
      }
      
      secrets_manager = {
        grantee_principal = "arn:aws:iam::345678901234:role/YOVProductionSecretsRole"
        operations = ["Encrypt", "Decrypt", "GenerateDataKey"]
        constraints = {
          encryption_context_equals = {
            Service = "SecretsManager"
            Environment = "production"
          }
        }
        retiring_principal = "arn:aws:iam::345678901234:role/YOVKMSAdminRole"
      }
    }
    
    # Production-specific tags
    tags = merge(
      include.envcommon.inputs.tags,
      {
        Name = "prod-use1-app-encryption"
        CriticalityLevel = "critical"
        DataClassification = "confidential"
        ComplianceFramework = "SOX-PCI-DSS-GDPR"
        SecurityLevel = "high"
        ProductionKey = "true"
        MultiRegion = "true"
        
        # Compliance specific tags
        SOXCompliance = "required"
        PCIDSSCompliance = "level1"
        GDPRCompliance = "required"
        AuditRequired = "quarterly"
        
        # Operational tags
        KeyAdministrator = "security-team@yov.com"
        EmergencyContact = "security-oncall@yov.com"
        KeyRotationFrequency = "90days"
        KeyRotationAlert = "security-alerts@yov.com"
        BackupRequired = "cross-region"
        
        # Cost and billing
        ChargeCode = "PROD-SECURITY-001"
        CostOptimization = "monitor"
        BudgetAlert = "enabled"
        
        # Change management
        ChangeApproval = "required"
        EmergencyAccess = "break-glass"
        Documentation = "confluence.yov.com/kms-prod"
      }
    )
  }
)
