# Terraform-Yov / AP Southeast

[![Terraform](https://img.shields.io/badge/terraform-%3E%3D1.5.0-623CE4.svg?logo=terraform)](https://www.terraform.io/)
[![AWS Provider](https://img.shields.io/badge/AWS-%7E%3E5.31.0-FF9900.svg?logo=amazon-aws)](https://registry.terraform.io/providers/hashicorp/aws/latest)
[![Deploy](https://github.com/catherinevee/terraform-yov/actions/workflows/terraform-deploy.yml/badge.svg)](https://github.com/catherinevee/terraform-yov/actions/workflows/terraform-deploy.yml)
[![Cost Monitoring](https://github.com/catherinevee/terraform-yov/actions/workflows/cost-monitoring.yml/badge.svg)](https://github.com/catherinevee/terraform-yov/actions/workflows/cost-monitoring.yml)

## Infrastructure Overview

Production-ready serverless infrastructure deployed in AWS AP-Southeast regions (Singapore and Sydney). Built with Terraform, this platform provides a multi-tenant SaaS API architecture capable of handling 10M API calls daily with sub-second response times. The infrastructure leverages AWS managed services for automatic scaling, high availability, and cost optimization through pay-per-use pricing models.

## Architecture

**Compute**: Lambda, Step Functions
**API**: API Gateway REST, CloudFront CDN
**Database**: DynamoDB Global Tables, Aurora Serverless v2
**Storage**: S3, EventBridge
**Security**: Cognito, API Keys, KMS
**Monitoring**: CloudWatch, X-Ray

## Quick Start

```bash
# Prerequisites
terraform --version  # >= 1.5.0
aws configure

# Deploy
terraform init
terraform workspace select dev
terraform plan -var-file="services/api/dev/terraform.tfvars"
terraform apply -var-file="services/api/dev/terraform.tfvars"
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

## Environments

| Environment | Region | Lambda Memory | API Rate Limit | DynamoDB Mode |
|-------------|--------|---------------|----------------|---------------|
| dev | ap-southeast-1 | 512 MB | 1000/sec | On-Demand |
| staging | ap-southeast-1 | 1024 MB | 5000/sec | Provisioned |
| prod | ap-southeast-1/2 | 2048 MB | 10000/sec | Auto-scaling |

## API Configuration

### Rate Limiting

```hcl
usage_plans = {
  free    = { quota = 1000/day,    rate = 10/sec }
  basic   = { quota = 10000/day,   rate = 50/sec }
  premium = { quota = 100000/day,  rate = 100/sec }
  enterprise = { quota = 1000000/day, rate = 500/sec }
}
```

## Deployment

### Development
```bash
terraform workspace select dev
terraform apply -var-file="services/api/dev/terraform.tfvars"
```

### Production
```bash
terraform workspace select prod
terraform apply -var-file="services/api/prod/terraform.tfvars"
```

## CI/CD Pipeline

**terraform-deploy.yml**: Main deployment pipeline
- Terraform validation and security scanning
- Environment-based deployments
- Gradual Lambda rollout
- Automated rollback

**cost-monitoring.yml**: Infrastructure cost analysis
- Pull request cost impact
- Weekly cost reports
- Budget alerts

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

## Cost Optimization

- Lambda reserved concurrency
- DynamoDB auto-scaling
- S3 intelligent tiering
- CloudFront caching

**Estimated Monthly Cost (10M requests/day)**
- Lambda: $200
- API Gateway: $35
- DynamoDB: $150
- CloudFront: $50
- Total: ~$435

## Best Practices

**Terraform**
- Remote state with locking
- Version pinning
- Module versioning
- Workspace separation
- Secrets in AWS Secrets Manager

**Lambda**
- Connection pooling
- Shared layers
- Reserved concurrency
- Dead letter queues

**DynamoDB**
- Global secondary indexes
- Point-in-time recovery
- Auto-scaling
- On-demand for dev

## Troubleshooting

```bash
# Lambda logs
aws logs tail /aws/lambda/function-name --follow

# API Gateway errors
aws apigateway get-rest-apis

# DynamoDB metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ConsumedReadCapacityUnits
```

## License

MIT