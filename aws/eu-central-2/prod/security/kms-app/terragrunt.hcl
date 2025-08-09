# =============================================================================
# PRODUCTION KMS APPLICATION ENCRYPTION KEY
# =============================================================================
# This configuration deploys a production-grade KMS key for application
# encryption with enhanced security, compliance, and multi-region support

# Include root configuration (backend, providers)
include "root" {
  path   = find_in_parent_folders("terragrunt.hcl")
  expose = true
}

# Include environment-common KMS configuration
include "envcommon" {
  path           = "${dirname(find_in_parent_folders("terragrunt.hcl"))}/_envcommon/security/kms.hcl"
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
  environment = "prod"
  region      = "eu-central-2"
  account_id  = "025066254478"

  # Production KMS key alias
  key_alias = "prod-euc2-app-encryption"
}

# Dependencies - none for KMS as it's foundational

# Module source from Terraform Registry
terraform {
  source = "tfr:///terraform-aws-modules/kms/aws?version=2.2.0"
}

# Generate outputs override to fix sensitive data error
generate "outputs_override" {
  path      = "outputs_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    # Override the grants output to mark it as sensitive (empty since no grants defined)
    output "grants" {
      description = "A map of grants created and their attributes"
      value       = {}
      sensitive   = true
    }
  EOF
}

# Production-specific KMS inputs
inputs = {
  # Production-specific description
  description = "Production application encryption key for eu-central-2 with SOX/PCI-DSS compliance"

  # Enhanced key policy for production with stricter access controls
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "YOVProductionApplicationKeyPolicy"
    Statement = [
      # Allow full access to account root and current user
      {
        Sid    = "AllowRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::025066254478:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      # AWS service principals for common services
      {
        Sid    = "AllowAWSServices"
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
            "aws:SourceAccount" = "025066254478"
          }
        }
      }
    ]
  })

  # Explicitly disable grants to prevent IAM role dependency issues
  grants = {}

  # Production key rotation - more frequent for compliance
  rotation_period_in_days = 90

  # Extended deletion window for production
  deletion_window_in_days = 30

  # Multi-region for disaster recovery
  multi_region = true

  # Production aliases
  aliases = [
    "alias/prod-euc2-app-encryption",
    "alias/production-application-key-eu",
    "alias/yov-prod-encryption-eu"
  ]

  # Production-specific tags
  tags = {
    Name                = "prod-euc2-app-encryption"
    CriticalityLevel    = "critical"
    DataClassification  = "confidential"
    ComplianceFramework = "SOX-PCI-DSS-GDPR"
    SecurityLevel       = "high"
    ProductionKey       = "true"
    MultiRegion         = "true"

    # Compliance specific tags
    SOXCompliance    = "required"
    PCIDSSCompliance = "level1"
    GDPRCompliance   = "required"
    AuditRequired    = "quarterly"

    # Operational tags
    KeyAdministrator     = "security-team@yov.com"
    EmergencyContact     = "security-oncall@yov.com"
    KeyRotationFrequency = "90days"
    KeyRotationAlert     = "security-alerts@yov.com"
    BackupRequired       = "cross-region"

    # Cost and billing
    ChargeCode       = "PROD-SECURITY-001"
    CostOptimization = "monitor"
    BudgetAlert      = "enabled"

    # Change management
    ChangeApproval  = "required"
    EmergencyAccess = "break-glass"
    Documentation   = "confluence.yov.com/kms-prod"

    # Terragrunt metadata
    ManagedBy  = "terragrunt"
    Terraform  = "true"
    Component  = "kms"
  }
}
