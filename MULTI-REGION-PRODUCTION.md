# Multi-Region Production Infrastructure

## Overview

This document outlines the functional terragrunt code setup for both production regions in the terraform-yov project.

## Regional Configuration

### US-East-1 (Primary Region)
- **Region Code**: `us-east-1`
- **Short Name**: `use1`
- **VPC CIDR**: `10.30.0.0/16`
- **Availability Zones**: `us-east-1a`, `us-east-1b`, `us-east-1c`

#### Network Configuration
- **Public Subnets**: `10.30.1.0/24`, `10.30.2.0/24`, `10.30.3.0/24`
- **Private Subnets**: `10.30.11.0/24`, `10.30.12.0/24`, `10.30.13.0/24`
- **Database Subnets**: `10.30.21.0/24`, `10.30.22.0/24`, `10.30.23.0/24`
- **Intra Subnets**: `10.30.31.0/24`, `10.30.32.0/24`, `10.30.33.0/24`

#### Infrastructure Components
- **Database ID**: `prod-use1-primary-db`
- **EKS Cluster**: `prod-use1-eks-main`
- **KMS Key Alias**: `prod-use1-app-encryption`
- **Parameter Group**: `prod-use1-postgres15-optimized`

### EU-Central-2 (Secondary Region)
- **Region Code**: `eu-central-2`
- **Short Name**: `euc2`
- **VPC CIDR**: `10.60.0.0/16`
- **Availability Zones**: `eu-central-2a`, `eu-central-2b`, `eu-central-2c`

#### Network Configuration
- **Public Subnets**: `10.60.1.0/24`, `10.60.2.0/24`, `10.60.3.0/24`
- **Private Subnets**: `10.60.11.0/24`, `10.60.12.0/24`, `10.60.13.0/24`
- **Database Subnets**: `10.60.21.0/24`, `10.60.22.0/24`, `10.60.23.0/24`
- **Intra Subnets**: `10.60.31.0/24`, `10.60.32.0/24`, `10.60.33.0/24`

#### Infrastructure Components
- **Database ID**: `prod-euc2-primary-db`
- **EKS Cluster**: `prod-euc2-eks-main`
- **KMS Key Alias**: `prod-euc2-app-encryption`
- **Parameter Group**: `prod-euc2-postgres15-optimized`

## Directory Structure

```
terraform-yov/
├── aws/
│   ├── us-east-1/
│   │   ├── region.hcl
│   │   └── prod/
│   │       ├── env.hcl
│   │       ├── networking/
│   │       │   └── vpc/
│   │       │       └── terragrunt.hcl
│   │       ├── security/
│   │       │   └── kms-app/
│   │       │       └── terragrunt.hcl
│   │       ├── data/
│   │       │   └── rds-primary/
│   │       │       └── terragrunt.hcl
│   │       └── compute/
│   │           └── eks-main/
│   │               └── terragrunt.hcl
│   └── eu-central-2/
│       ├── region.hcl
│       └── prod/
│           ├── env.hcl
│           ├── networking/
│           │   └── vpc/
│           │       └── terragrunt.hcl
│           ├── security/
│           │   └── kms-app/
│           │       └── terragrunt.hcl
│           ├── data/
│           │   └── rds-primary/
│           │       └── terragrunt.hcl
│           └── compute/
│               └── eks-main/
│                   └── terragrunt.hcl
├── _envcommon/
│   ├── networking/
│   │   └── vpc.hcl
│   ├── security/
│   │   └── kms.hcl
│   ├── data/
│   │   └── rds.hcl
│   └── compute/
│       └── eks.hcl
└── root.hcl
```

## Key Configuration Updates Made

### 1. Database Configuration Updates
- Updated RDS database identifiers to be region-specific
- Updated VPC CIDR blocks for security group rules
- Updated cross-region backup destinations
- Updated parameter group and option group names

### 2. VPC Configuration Updates
- Updated region identifiers
- Updated EKS cluster tags to be region-specific
- Updated all CIDR blocks to use region-specific ranges

### 3. EKS Configuration Updates
- Updated cluster names to be region-specific
- Updated all references from `use1` to `euc2` for EU region

### 4. KMS Configuration Updates
- Updated region identifiers
- Updated key alias names to be region-specific

## Deployment Commands

### US-East-1 Production
```powershell
cd "C:\Users\cathe\OneDrive\Desktop\github\terraform-yov\aws\us-east-1\prod"
terragrunt run-all plan
terragrunt run-all apply
```

### EU-Central-2 Production
```powershell
cd "C:\Users\cathe\OneDrive\Desktop\github\terraform-yov\aws\eu-central-2\prod"
terragrunt run-all plan
terragrunt run-all apply
```

## Cross-Region Features

### Disaster Recovery
- **US-East-1** → Backup regions: `us-west-2`, `eu-west-1`
- **EU-Central-2** → Backup regions: `eu-west-1`, `eu-central-1`

### Cross-Region Replication
Both regions support:
- S3 cross-region replication
- RDS cross-region backup
- DynamoDB cross-region replication

### Compliance
- **US-East-1**: SOX, PCI-DSS, CCPA compliance
- **EU-Central-2**: GDPR, SOX, PCI-DSS, Swiss Data Protection Act compliance

## Prerequisites

Before deploying, ensure:

1. **AWS Credentials**: Valid AWS credentials are configured
2. **Terraform State**: S3 buckets and DynamoDB tables exist for remote state
3. **IAM Roles**: Required execution roles exist in the target account
4. **KMS Keys**: Terraform state encryption keys exist

## Validation

To validate the configuration:

```powershell
# Run the validation script
.\check-production-regions.ps1

# Or manually check each region
cd aws\us-east-1\prod
terragrunt run-all validate

cd ..\..\..\eu-central-2\prod
terragrunt run-all validate
```

## Security Considerations

### Network Isolation
- Each region uses non-overlapping CIDR blocks
- Database subnets are isolated from public internet
- Security groups restrict access to necessary ports only

### Encryption
- All data encrypted at rest using KMS
- Data in transit encrypted using TLS
- Region-specific KMS keys for data sovereignty

### Monitoring
- VPC Flow Logs enabled for all regions
- Enhanced monitoring for production workloads
- Cross-region monitoring dashboards

## Next Steps

1. **Deploy Foundation**: Start with VPC and KMS in both regions
2. **Deploy Data Layer**: Deploy RDS databases with cross-region backup
3. **Deploy Compute**: Deploy EKS clusters with appropriate scaling
4. **Validate Connectivity**: Test cross-region communication
5. **Setup Monitoring**: Configure CloudWatch and alerting
6. **Test DR Procedures**: Validate disaster recovery processes

---

**Status**: ✅ Both production regions have functional terragrunt code
**Last Updated**: August 8, 2025
