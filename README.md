# YOV Enterprise Infrastructure

## Enterprise-Grade AWS Terragrunt Infrastructure

A production-ready AWS infrastructure-as-code solution built with Terragrunt, following enterprise security standards and industry best practices. This repository provides a multi-region, multi-environment infrastructure setup for AWS.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Running Terragrunt Files](#running-terragrunt-files)
- [Directory Structure](#directory-structure)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Security](#security)
- [CI/CD Pipeline](#cicd-pipeline)
- [Multi-Region Setup](#multi-region-setup)
- [Contributing](#contributing)

## Overview

This repository contains a comprehensive enterprise AWS infrastructure solution using Terragrunt and Terraform. It implements a hierarchical architecture pattern with multi-region support, security compliance, and GitOps workflows.

### Key Features

- **Enterprise-Grade**: Production-ready with security best practices
- **Multi-Region**: AWS deployment across US-East-1 and EU-Central-2
- **Multi-Environment**: Development, Staging, and Production environments
- **Security First**: Comprehensive security scanning and policies via GitHub Actions
- **GitOps Enabled**: Complete CI/CD pipeline automation
- **Cost Optimized**: Infrastructure designed for cost efficiency
- **Production Ready**: Battle-tested enterprise infrastructure patterns

### Technology Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| **Terragrunt** | v0.50+ | Infrastructure orchestration |
| **Terraform** | v1.5+ | Infrastructure provisioning |
| **AWS Provider** | v5.0+ | AWS resource management |
| **TFSec** | Latest | Security scanning |
| **Checkov** | Latest | Policy validation |

## Architecture

### Infrastructure Hierarchy

```
Root Level (Global Configuration)
├── AWS Account (Account-Specific Settings)
│   ├── Region (us-east-1, eu-central-2, eu-west-1)
│   │   ├── Environment (dev, staging, prod)
│   │   │   ├── Networking (VPC, Subnets, Security Groups)
│   │   │   ├── Security (KMS, Secrets, IAM)
│   │   │   ├── Compute (EKS, EC2, Auto Scaling)
│   │   │   ├── Data (RDS, ElastiCache, S3)
│   │   │   └── Monitoring (CloudWatch, Alerting)
│   │   └── Shared Components (_envcommon)
│   └── Other Regions
└── Additional Cloud Providers (Future)
```

### Multi-Environment Strategy

The infrastructure supports three primary environments:
- **Development**: Testing and development workloads
- **Staging**: Pre-production validation
- **Production**: Live production workloads

### Multi-Region Deployment

- **Primary**: `us-east-1` (North Virginia)
- **Secondary**: `eu-central-2` (Zurich)  
- **Additional**: `eu-west-1` (Ireland)

## Quick Start

### Prerequisites
## AWS Backend Resource Prerequisites

This project requires the following AWS resources for Terragrunt remote state and locking:

- **S3 Bucket**: `terragrunt-state-123456789012` (replace with your AWS Account ID)
- **DynamoDB Table**: `terragrunt-state-locks-123456789012` (replace with your AWS Account ID)

These must exist and be accessible by the CI/CD runner and any user running Terragrunt locally.

### Required IAM Permissions

The CI/CD runner and users must have the following IAM permissions:

- `s3:ListBucket`, `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` on the state bucket
- `dynamodb:GetItem`, `dynamodb:PutItem`, `dynamodb:DeleteItem`, `dynamodb:DescribeTable` on the lock table

For OIDC-based authentication, ensure the GitHub Actions role has these permissions attached.

See `.github/workflows/terragrunt.yml` for pre-flight resource checks.

Ensure you have the following tools installed:

```bash
# Required tools
- Terraform >= 1.5.0
- Terragrunt >= 0.50.0
- AWS CLI >= 2.0
- Git
```

### Installation

1. **Clone repository**
   ```bash
   git clone https://github.com/catherinevee/terraform-yov.git
   cd terraform-yov
   ```

2. **Configure AWS credentials**
   ```bash
   aws configure
   # or set up AWS SSO
   aws sso login --profile your-profile
   ```

3. **Initialize and deploy development environment**
   ```bash
   cd aws/us-east-1/dev
   terragrunt run-all plan
   terragrunt run-all apply
   ```

## Running Terragrunt Files

### Prerequisites

Before running any Terragrunt commands, ensure you have:

```bash
# Required tools installed
terragrunt --version    # Should be >= 0.50.0
terraform --version     # Should be >= 1.5.0
aws --version          # Should be >= 2.0.0

# AWS credentials configured
aws configure list
# or
export AWS_PROFILE=your-profile-name
```

### Basic Terragrunt Workflow

1. **Navigate to Target Directory**
   ```bash
   # For development environment in us-east-1
   cd aws/us-east-1/dev/networking/vpc
   
   # For production environment in eu-central-2
   cd aws/eu-central-2/prod/compute/eks-main
   ```

2. **Initialize Terragrunt**
   ```bash
   # Initialize the current module
   terragrunt init
   
   # Initialize with upgrade to latest providers
   terragrunt init -upgrade
   ```

3. **Plan Infrastructure Changes**
   ```bash
   # Generate and show execution plan
   terragrunt plan
   
   # Save plan to file for review
   terragrunt plan -out=tfplan
   ```

4. **Apply Infrastructure Changes**
   ```bash
   # Apply changes interactively
   terragrunt apply
   
   # Apply saved plan
   terragrunt apply tfplan
   
   # Apply without confirmation (use carefully)
   terragrunt apply -auto-approve
   ```

5. **Destroy Infrastructure**
   ```bash
   # Destroy resources interactively
   terragrunt destroy
   
   # Destroy without confirmation (dangerous)
   terragrunt destroy -auto-approve
   ```

### Multi-Module Operations

```bash
# From any environment directory (e.g., aws/us-east-1/dev/)
cd aws/us-east-1/dev

# Plan all modules in dependency order
terragrunt run-all plan

# Apply all modules in dependency order
terragrunt run-all apply

# Destroy all modules in reverse dependency order
terragrunt run-all destroy
```

### Environment-Specific Examples

#### Development Environment
```bash
# Deploy VPC and networking
cd aws/us-east-1/dev/networking/vpc
terragrunt apply

# Deploy security components
cd ../../security/kms-app
terragrunt apply

# Deploy compute resources
cd ../compute/eks-main
terragrunt apply
```

#### Production Environment
```bash
# Production requires careful deployment order
cd aws/us-east-1/prod

# Run all dependencies in order
terragrunt run-all plan
terragrunt run-all apply
```

### Troubleshooting

```bash
# Force unlock (use with caution)
terragrunt force-unlock LOCK_ID

# Update dependency cache
terragrunt init --terragrunt-update-dependencies

# Show dependency graph
terragrunt graph-dependencies
```

## Directory Structure

The repository follows a hierarchical structure optimized for multi-region AWS deployments:

```
terraform-yov/
├── terragrunt.hcl                    # Root Terragrunt configuration
├── backend.tf                       # Terraform backend configuration
├── provider.tf                      # Terraform provider configuration
├── .github/                         # GitHub Actions workflows
│   └── workflows/
│       ├── terragrunt-deploy.yml    # Main deployment pipeline
│       ├── security-monitoring.yml  # Security scanning
│       ├── pull-request-validation.yml
│       ├── environment-promotion.yml
│       ├── infrastructure-diagrams.yml
│       ├── infrastructure-testing.yml
│       └── release-management.yml
├── aws/                             # AWS-specific configurations
│   ├── account.hcl                  # AWS account settings
│   ├── us-east-1/                   # Primary region (US East)
│   │   ├── region.hcl               # Region-specific config
│   │   ├── dev/                     # Development environment
│   │   │   ├── env.hcl              # Environment config
│   │   │   ├── networking/          # Network infrastructure
│   │   │   ├── security/            # Security components
│   │   │   ├── compute/             # Compute resources
│   │   │   └── data/                # Data services
│   │   ├── staging/                 # Staging environment
│   │   └── prod/                    # Production environment
│   ├── eu-central-2/                # Secondary region (EU Central)
│   │   ├── region.hcl
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   └── eu-west-1/                   # Additional region (EU West)
│       └── prod/
├── _envcommon/                      # Shared configurations
│   ├── networking/                  # Reusable network configs
│   ├── security/                    # Reusable security configs
│   ├── compute/                     # Reusable compute configs
│   └── data/                        # Reusable data configs
├── policies/                        # OPA security policies
├── scripts/                         # Automation scripts
│   ├── install-tools.sh             # Tool installation script
│   └── security-scan.ps1            # Security scanning script
├── MULTI-REGION-PRODUCTION.md       # Multi-region deployment guide
├── TFSTATE-NAMING-CONVENTION.md     # State file naming conventions
└── README.md                        # This file
```

### Component Details

| Directory | Purpose | Contains |
|-----------|---------|----------|
| `networking/` | Network infrastructure | VPC, Subnets, Security Groups, NACLs |
| `security/` | Security services | KMS, Secrets Manager, IAM policies |
| `compute/` | Compute resources | EKS clusters, EC2 instances, Auto Scaling |
| `data/` | Data services | RDS, ElastiCache, S3 buckets |

## Configuration

### Global Configuration

The root `terragrunt.hcl` file contains global settings that apply to all environments and regions:

- **State Management**: S3 backend with DynamoDB locking
- **Provider Configuration**: AWS provider with enhanced security
- **Tagging Strategy**: Consistent resource tagging across all infrastructure
- **Naming Conventions**: Automated resource naming following enterprise standards

### Environment Configuration

Each environment follows a consistent structure with environment-specific overrides:

```hcl
# aws/us-east-1/prod/env.hcl
locals {
  environment = "prod"
  
  # Environment-specific settings
  instance_sizes = {
    web_server    = "m5.large"
    database      = "r6g.2xlarge"
    cache         = "r6g.large"
  }
  
  # Security settings
  enable_detailed_monitoring = true
  backup_retention_days     = 30
  
  # Scaling settings
  auto_scaling = {
    min_size         = 2
    max_size         = 20
    desired_capacity = 4
  }
}
```

### Tagging Strategy

All resources are tagged consistently following enterprise standards:

```hcl
common_tags = {
  # Organizational tags
  Environment     = local.environment
  Application     = "YOV-Platform"
  Component       = "networking"
  
  # Operational tags
  Owner           = "platform-team@yov.com"
  Project         = "enterprise-infrastructure"
  Terraform       = "true"
  TerragruntRoot  = get_parent_terragrunt_dir()
  
  # Automation tags
  CreatedBy       = "terragrunt"
  CreatedDate     = formatdate("YYYY-MM-DD", timestamp())
}
```

### State File Naming Convention

The repository uses a sophisticated state file naming convention that ensures uniqueness across all deployments:

**Format**: `{region}-{environment}-{project_name}-{instance_number}.tfstate`

Examples:
- `us-east-1-dev-network-001.tfstate`
- `eu-central-2-prod-database-002.tfstate`
- `eu-west-1-staging-security-003.tfstate`

This convention is automatically applied based on the directory structure and component type.

## Deployment

### Single Environment Deployment

```bash
# Development environment
cd aws/us-east-1/dev
terragrunt run-all plan
terragrunt run-all apply

# Staging environment  
cd aws/us-east-1/staging
terragrunt run-all plan
terragrunt run-all apply

# Production environment
cd aws/us-east-1/prod
terragrunt run-all plan
terragrunt run-all apply
```

### Component-Specific Deployment

```bash
# Deploy only networking
cd aws/us-east-1/prod/networking/vpc
terragrunt apply

# Deploy only EKS cluster
cd aws/us-east-1/prod/compute/eks-main
terragrunt apply

# Deploy only RDS database
cd aws/us-east-1/prod/data/rds-primary
terragrunt apply
```

### Multi-Region Deployment

For detailed multi-region deployment instructions, see [MULTI-REGION-PRODUCTION.md](MULTI-REGION-PRODUCTION.md).

```bash
# Deploy to primary region (US East)
cd aws/us-east-1/prod
terragrunt run-all apply

# Deploy to secondary region (EU Central)
cd aws/eu-central-2/prod
terragrunt run-all apply
```

### Planning and Validation

```bash
# Plan all components in an environment
cd aws/us-east-1/dev
terragrunt run-all plan

# Validate configurations
terragrunt run-all validate

# Check formatting
terragrunt hclfmt --terragrunt-check
```

## Security

### Security Scanning

The infrastructure includes comprehensive security scanning through GitHub Actions workflows:

- **TFSec**: Terraform static security analysis
- **Checkov**: Infrastructure-as-code security and compliance scanning  
- **Trivy**: Container and filesystem vulnerability scanning
- **Semgrep**: Static analysis for security issues
- **TruffleHog**: Secrets detection and prevention

### Security Policies

- **Encryption**: All data encrypted at rest and in transit
- **Access Control**: Least privilege IAM policies
- **Network Security**: Private subnets, NACLs, Security Groups
- **Monitoring**: CloudTrail, VPC Flow Logs, GuardDuty integration
- **Compliance**: Enterprise security standards

### Secrets Management

```hcl
# Secrets are managed via AWS Secrets Manager
resource "aws_secretsmanager_secret" "app_secrets" {
  name                    = "yov-${local.environment}-app-secrets"
  description            = "Application secrets for ${local.environment}"
  recovery_window_in_days = 7
  
  tags = local.common_tags
}
```

## CI/CD Pipeline


### GitHub Actions Workflows

The repository includes comprehensive GitHub Actions workflows in `.github/workflows/`:

1. **terragrunt.yml**: Parameterized Terragrunt validation and plan pipeline
2. **terragrunt-deploy.yml**: Main deployment pipeline with security controls
3. **security-monitoring.yml**: Comprehensive security scanning and compliance
4. **pull-request-validation.yml**: PR validation with security checks
5. **environment-promotion.yml**: Secure environment promotion workflow
6. **infrastructure-diagrams.yml**: Automated infrastructure diagram generation
7. **infrastructure-testing.yml**: Multi-level testing framework
8. **release-management.yml**: Complete release management pipeline

#### terragrunt.yml Parameterization

The `terragrunt.yml` workflow is fully parameterized for maximum flexibility and security:

- **Environments**: Set via repository variable `TERRAGRUNT_ENVIRONMENTS` (default: `dev prod`)
- **AWS Region**: Set via repository variable `AWS_REGION` (default: `eu-west-2`)
- **S3 Bucket**: Set via secret `TERRAGRUNT_S3_BUCKET` (default: `terragrunt-state-123456789012`)
- **DynamoDB Table**: Set via secret `TERRAGRUNT_DYNAMODB_TABLE` (default: `terragrunt-state-locks-123456789012`)

You can override these values in your repository settings under **Variables** and **Secrets**. This allows you to reuse the workflow across multiple environments and accounts without editing the workflow file.

#### Example: Setting Variables and Secrets

1. Go to your repository **Settings > Variables** and add:
   - `TERRAGRUNT_ENVIRONMENTS` (e.g., `dev staging prod`)
   - `AWS_REGION` (e.g., `us-east-1`)

2. Go to **Settings > Secrets and variables > Actions > Secrets** and add:
   - `TERRAGRUNT_S3_BUCKET` (e.g., `my-company-terragrunt-state`)
   - `TERRAGRUNT_DYNAMODB_TABLE` (e.g., `my-company-terragrunt-locks`)

#### Workflow Features

- **Security-First Design**: Every workflow includes security scanning
- **Cost Monitoring**: Infracost integration for cost impact analysis
- **Policy Compliance**: OPA and Sentinel policy validation
- **Multi-Environment Support**: Automated deployment across environments
- **Approval Gates**: Manual approval requirements for production
- **Parameterization**: Easily adjust environments, regions, and AWS resources via repo settings

### Manual Deployment

Workflows can be triggered manually through GitHub Actions interface or CLI.

### Production Approval

Production deployments require manual approval through GitHub Environments with additional security checks.

## Multi-Region Setup

This repository supports multi-region AWS deployments with the following regions configured:

### Primary Region: US-East-1
- **Region Code**: `us-east-1`
- **VPC CIDR**: `10.30.0.0/16`
- **Environments**: dev, staging, prod

### Secondary Region: EU-Central-2  
- **Region Code**: `eu-central-2`
- **VPC CIDR**: `10.60.0.0/16`
- **Environments**: dev, staging, prod

### Additional Region: EU-West-1
- **Region Code**: `eu-west-1`
- **Environments**: prod

For detailed multi-region deployment instructions, see [MULTI-REGION-PRODUCTION.md](MULTI-REGION-PRODUCTION.md).

### Cross-Region Features

- **Disaster Recovery**: Automated backup and replication
- **Network Connectivity**: VPC peering and transit gateway support
- **Data Replication**: Cross-region RDS and S3 replication
- **Security**: Region-specific KMS keys and encryption

## Contributing

### Development Workflow

1. **Create Feature Branch**
   ```bash
   git checkout -b feature/new-component
   ```

2. **Make Changes**
   - Edit Terragrunt configurations
   - Add new infrastructure components
   - Update documentation

3. **Test Changes**
   ```bash
   # Test in development environment
   cd aws/us-east-1/dev
   terragrunt run-all plan
   ```

4. **Submit Pull Request**
   - Include security scan results (automated via GitHub Actions)
   - Add description of infrastructure changes
   - Update documentation as needed

### Code Review Checklist

- [ ] Security scan passes (automated)
- [ ] Configuration validation passes
- [ ] Documentation updated
- [ ] Follows naming conventions
- [ ] Required tags present
- [ ] Multi-region compatibility verified

### Commit Convention

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add new EKS cluster configuration
fix: resolve security group rule conflict
docs: update deployment documentation
chore: update Terragrunt to v0.50.0
```

## Support

### Documentation

- **Multi-Region Setup**: [MULTI-REGION-PRODUCTION.md](MULTI-REGION-PRODUCTION.md)
- **State Naming**: [TFSTATE-NAMING-CONVENTION.md](TFSTATE-NAMING-CONVENTION.md)
- **GitHub Actions**: `.github/workflows/` directory

### Troubleshooting

Common issues and solutions:

```bash
# State file locked
terragrunt force-unlock <lock-id>

# Permission denied
aws sts get-caller-identity

# Configuration validation failed
terragrunt run-all validate
terragrunt hclfmt
```

### Getting Help

- **Issues**: Create a GitHub issue with detailed description
- **Security Issues**: Follow responsible disclosure practices
- **Documentation**: Check existing documentation files

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- **Terragrunt Team**: For the excellent orchestration tool
- **HashiCorp**: For Terraform and enterprise tools
- **AWS**: For comprehensive cloud services
- **Security Community**: For security scanning tools and best practices

---

<div align="center">

**YOV Enterprise Infrastructure - Built for Scale, Security, and Reliability**

[![Infrastructure](https://img.shields.io/badge/Infrastructure-Terragrunt-blue)](https://terragrunt.gruntwork.io/)
[![Security](https://img.shields.io/badge/Security-TFSec%20%7C%20Checkov-green)](https://github.com/aquasecurity/tfsec)
[![AWS](https://img.shields.io/badge/Cloud-AWS-orange)](https://aws.amazon.com/)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-yellow)](https://github.com/features/actions)

</div>