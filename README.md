# Terraform-Yov / AP Southeast

[![Terraform](https://img.shields.io/badge/terraform-%3E%3D1.5.0-623CE4.svg?logo=terraform)](https://www.terraform.io/)
[![AWS Provider](https://img.shields.io/badge/AWS-%7E%3E5.31.0-FF9900.svg?logo=amazon-aws)](https://registry.terraform.io/providers/hashicorp/aws/latest)
[![Workspaces](https://img.shields.io/badge/Workspaces-Enabled-success.svg?logo=terraform)](#workspaces)
[![OIDC](https://img.shields.io/badge/OIDC-Enabled-success.svg?logo=amazon-aws)](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
[![Deploy](https://github.com/catherinevee/terraform-yov/actions/workflows/terraform-deploy.yml/badge.svg)](https://github.com/catherinevee/terraform-yov/actions/workflows/terraform-deploy.yml)
[![Cost Monitoring](https://github.com/catherinevee/terraform-yov/actions/workflows/cost-monitoring.yml/badge.svg)](https://github.com/catherinevee/terraform-yov/actions/workflows/cost-monitoring.yml)

## Overview

Production-ready serverless multi-tenant SaaS platform for AWS AP-Southeast regions. Designed to handle 10M+ daily API calls with sub-second latency through managed AWS services and automatic scaling.

## Tech Stack

| Layer | Services |
|-------|----------|
| Compute | Lambda, Step Functions |
| API | API Gateway REST, CloudFront CDN |
| Database | DynamoDB Global Tables, Aurora Serverless v2 |
| Storage | S3, EventBridge |
| Security | Cognito, API Keys, KMS, WAF |
| Monitoring | CloudWatch, X-Ray, SNS |

## Quick Start

```bash
# Initialize
terraform init
terraform workspace new dev

# Deploy
terraform apply -var-file="services/api/dev/terraform.tfvars" -auto-approve

# Verify
aws dynamodb list-tables | grep serverless-api
```

## Project Structure

```
terraform-yov/
├── modules/              # Reusable Terraform modules
│   ├── networking/       # API Gateway, CloudFront, Route53
│   ├── compute/          # Lambda, Step Functions
│   ├── database/         # DynamoDB, Aurora
│   ├── storage/          # S3, EventBridge
│   ├── security/         # Cognito, IAM
│   └── monitoring/       # CloudWatch, X-Ray
├── services/            # Service configurations
│   └── api/
│       ├── dev/         # Development environment
│       ├── staging/     # Staging environment
│       └── prod/        # Production environment
└── .github/workflows/   # CI/CD pipelines
```

## Environment Configuration

| Environment | Memory | Rate Limit | DynamoDB | X-Ray | Logs |
|-------------|--------|------------|----------|-------|------|
| `dev` | 512 MB | 1K/sec | On-Demand | No | 7d |
| `staging` | 1 GB | 5K/sec | Provisioned | Yes | 30d |
| `prod` | 2 GB | 10K/sec | Auto-scale | Yes | 90d |

## API Usage Plans

| Plan | Daily Quota | Rate | Burst |
|------|-------------|------|-------|
| Free | 1K | 10/sec | 20 |
| Basic | 10K | 50/sec | 100 |
| Premium | 100K | 100/sec | 200 |
| Enterprise | 1M | 500/sec | 1000 |

## Workspaces

This project uses Terraform workspaces for environment isolation. Each workspace maintains separate state and automatically configures environment-specific settings.

```bash
# List available workspaces
terraform workspace list

# Create/select a workspace
terraform workspace select dev    # or staging, prod
```

## Deployment Commands

```bash
# Deploy to specific environment
make deploy ENV=dev      # Development
make deploy ENV=staging  # Staging
make deploy ENV=prod     # Production

# Or manually
terraform workspace select <env>
terraform apply -var-file="services/api/<env>/terraform.tfvars"
```

## CI/CD Pipelines

| Workflow | Trigger | Actions |
|----------|---------|---------|
| `terraform-deploy.yml` | Push to main/develop | Validate → Security Scan → Plan → Deploy |
| `cost-monitoring.yml` | PR / Weekly | Infracost analysis & budget alerts |

## Security

- Encryption at rest (KMS)
- TLS 1.3 in transit
- WAF protection
- API key authentication
- Cognito user pools
- Least-privilege IAM

## Monitoring

- CloudWatch dashboards
- X-Ray distributed tracing
- Custom metrics and alarms
- SNS alert notifications
- DynamoDB auto-scaling
- Lambda dead letter queues

## Cost Breakdown (10M req/day)

| Service | Monthly Cost | Optimization |
|---------|--------------|-------------|
| Lambda | $200 | Reserved concurrency |
| API Gateway | $35 | Usage plans |
| DynamoDB | $150 | Auto-scaling |
| CloudFront | $50 | Edge caching |
| **Total** | **~$435** | 70% savings vs on-demand |

## Key Features

### Infrastructure as Code
- Terraform workspaces for environment isolation
- Automated security scanning (Checkov, Trivy)
- Version-pinned providers and modules
- GitOps deployment workflow

### High Availability
- Multi-region deployment (Singapore + Sydney)
- Global DynamoDB tables with auto-failover
- CloudFront edge locations
- Lambda dead letter queues

### Security
- End-to-end encryption (TLS 1.3 + KMS)
- WAF protection against OWASP Top 10
- Least-privilege IAM policies
- Secrets rotation via Secrets Manager

## Operations

```bash
# View logs
aws logs tail /aws/lambda/serverless-api-dev --follow

# Check metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Errors \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Sum

# Destroy infrastructure
terraform destroy -var-file="services/api/dev/terraform.tfvars"
```

## Requirements

- Terraform >= 1.5.0
- AWS CLI configured
- AWS IAM OIDC Provider for GitHub Actions
- IAM Role: `terraform-yov-github-actions`
- GitHub Actions secrets:
  - `TF_API_TOKEN` (optional)
  - `INFRACOST_API_KEY` (optional)

## License

MIT