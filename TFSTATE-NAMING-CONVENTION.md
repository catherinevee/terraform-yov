# Terraform State File Naming Convention Documentation

## Overview
The terraform-yov project now uses a standardized naming convention for all Terraform state files following the pattern:
**`region+environment+projectname+instancenumber`**

## Naming Convention Pattern
```
{region}-{environment}-{projectname}-{instancenumber}.tfstate
```

### Components Explained

1. **Region**: AWS region (e.g., us-east-1, eu-west-1, eu-central-2)
2. **Environment**: Environment type (dev, staging, prod)
3. **Project Name**: Service/component type based on directory structure
4. **Instance Number**: 3-digit hash-based unique identifier (001-999)

## Project Name Mapping

The project name is automatically determined from the service directory name:

| Directory Name     | Project Name | Purpose                    |
|-------------------|--------------|----------------------------|
| vpc               | network      | VPC and networking         |
| security          | security     | Security groups, KMS       |
| rds               | database     | RDS databases              |
| rds-primary       | database     | Primary RDS instances      |
| rds-secondary     | database     | Secondary/replica RDS      |
| eks-main          | compute      | Primary EKS clusters       |
| eks-secondary     | compute      | Secondary EKS clusters     |
| ec2               | compute      | EC2 instances              |
| lambda            | compute      | Lambda functions           |
| s3                | storage      | S3 buckets                 |
| efs               | storage      | EFS file systems           |
| kms               | security     | KMS key management         |
| kms-app           | security     | Application-specific KMS   |
| iam               | security     | IAM roles and policies     |
| cloudwatch        | monitoring   | CloudWatch resources       |
| alb               | network      | Application Load Balancers |
| elb               | network      | Elastic Load Balancers     |
| route53           | network      | DNS and Route53            |
| cloudfront        | network      | CDN and CloudFront         |
| waf               | security     | Web Application Firewall   |
| budget-monitoring | billing      | Cost and budget monitoring |
| cur-reports       | billing      | Cost and usage reports     |
| backup            | storage      | Backup configurations      |
| disaster-recovery | backup       | DR configurations          |
| secrets           | security     | Secrets Manager            |
| parameter-store   | config       | Parameter Store            |
| elasticache       | cache        | ElastiCache                |
| elasticsearch     | search       | Elasticsearch              |
| sqs               | messaging    | SQS queues                 |
| sns               | messaging    | SNS topics                 |
| kinesis           | streaming    | Kinesis streams            |
| api-gateway       | api          | API Gateway                |
| cognito           | auth         | Cognito authentication     |

## Example State File Names

### Current Examples from Implementation

#### US East 1 Region
```
us-east-1-dev-network-842.tfstate      # VPC infrastructure
us-east-1-dev-security-XXX.tfstate     # Security groups
us-east-1-dev-database-XXX.tfstate     # RDS PostgreSQL
```

#### EU West 1 Region
```
eu-west-1-dev-network-566.tfstate      # VPC infrastructure (dev)
eu-west-1-staging-network-748.tfstate  # VPC infrastructure (staging)
eu-west-1-prod-network-XXX.tfstate     # VPC infrastructure (prod)
```

#### EU Central 2 Region
```
eu-central-2-dev-network-XXX.tfstate      # VPC infrastructure
eu-central-2-staging-network-XXX.tfstate  # VPC infrastructure
eu-central-2-prod-network-XXX.tfstate     # VPC infrastructure
```

### Hypothetical Examples for Other Services

#### Database Services
```
us-east-1-prod-database-001.tfstate     # Primary RDS cluster
us-east-1-prod-database-002.tfstate     # Read replica
eu-west-1-staging-database-045.tfstate  # Staging database
```

#### Compute Services
```
us-east-1-prod-compute-123.tfstate      # EKS main cluster
us-east-1-prod-compute-124.tfstate      # EKS secondary cluster
eu-west-1-dev-compute-567.tfstate       # Development EKS
```

#### Security Services
```
us-east-1-prod-security-234.tfstate     # Security groups
us-east-1-prod-security-235.tfstate     # KMS keys
eu-west-1-staging-security-678.tfstate  # Staging security
```

#### Storage Services
```
us-east-1-prod-storage-345.tfstate      # S3 buckets
us-east-1-prod-storage-346.tfstate      # EFS file systems
eu-west-1-dev-storage-789.tfstate       # Development storage
```

## Implementation Details

### Configuration Location
The naming convention is implemented in the root `terragrunt.hcl` file:

```hcl
# Generate tfstate key following convention: region+environment+projectname+instancenumber
tfstate_key = "${local.region}-${local.environment}-${local.project_name}-${local.instance_number}.tfstate"
```

### Instance Number Generation
The instance number is generated using a hash of the full path to ensure uniqueness:
```hcl
instance_number = format("%03d", abs(parseint(substr(md5(path_relative_to_include()), 0, 6), 16)) % 1000)
```

### S3 Bucket Structure
State files are stored in regional S3 buckets:
```
yov-terraform-state-{account-id}-{region}
├── us-east-1-dev-network-842.tfstate
├── us-east-1-dev-security-XXX.tfstate
├── us-east-1-dev-database-XXX.tfstate
├── eu-west-1-dev-network-566.tfstate
├── eu-west-1-staging-network-748.tfstate
└── ...
```

## Benefits

1. **Consistency**: All state files follow the same naming pattern
2. **Clarity**: Easy to identify region, environment, and service type
3. **Uniqueness**: Hash-based instance numbers prevent conflicts
4. **Organization**: Logical grouping by region and environment
5. **Scalability**: Pattern scales across multiple regions/environments
6. **Automation**: Automatic generation based on directory structure

## Migration Impact

- **Backend Configuration Changed**: All existing environments will detect backend configuration changes
- **State Migration Required**: Use `terraform init -migrate-state` to migrate existing state
- **No Data Loss**: Migration preserves all existing infrastructure state
- **Gradual Rollout**: Can be applied environment by environment

## Usage

The naming convention is automatically applied to all new terragrunt configurations. No manual intervention required for new deployments.

For existing deployments, run:
```bash
terragrunt init -migrate-state
```

This will migrate the state file to the new naming convention while preserving all existing infrastructure.
