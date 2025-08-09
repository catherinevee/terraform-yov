# Terraform Sentinel Cost Control Policies

This directory contains a complete set of Terraform Sentinel policies designed to control and optimize AWS infrastructure costs across development, staging, and production environments.

## Overview

The cost control policy framework includes 10 policies that collectively address the major cost drivers in AWS infrastructure:

- **Compute costs** (EC2, RDS sizing)
- **Storage costs** (EBS, S3, backup retention)
- **Network costs** (NAT Gateways, data transfer)
- **Operational costs** (unused resources, logging)
- **Governance** (tagging, environment-specific limits)

## Policy Structure

### Main Configuration
- `sentinel.hcl` - Main configuration file defining all policies and enforcement levels

### Cost Control Policies
1. `enforce-instance-types.sentinel` - Controls EC2 instance types by environment
2. `limit-rds-instance-sizes.sentinel` - Manages RDS instance classes and storage
3. `prevent-expensive-resources.sentinel` - Blocks costly AWS resources
4. `enforce-cost-tags.sentinel` - Ensures proper cost tracking tags
5. `limit-storage-sizes.sentinel` - Controls storage sizes across services
6. `enforce-environment-specific-limits.sentinel` - Applies environment-based resource limits
7. `prevent-unused-resources.sentinel` - Detects potentially unused resources
8. `enforce-backup-retention-limits.sentinel` - Controls backup retention periods
9. `limit-nat-gateways.sentinel` - Manages NAT Gateway deployment
10. `enforce-spot-instances.sentinel` - Promotes Spot instance usage

## Enforcement Levels

### Hard Mandatory
Policies that **block** deployments if violated:
- Instance type restrictions in development
- RDS size limits
- Storage size limits
- Required cost tags
- Environment-specific resource limits

### Soft Mandatory
Policies that **warn** but allow deployments:
- Expensive resource usage
- Backup retention limits
- NAT Gateway optimization

### Advisory
Policies that provide **recommendations**:
- Unused resource detection
- Spot instance opportunities
- Cost optimization tips

## Environment-Specific Rules

### Development Environment
- **Compute**: Limited to t3.micro - t3.medium instances
- **RDS**: db.t3.micro - db.t3.small only
- **Storage**: Max 100GB per EBS volume
- **Requirements**: 
  - Must use Spot instances where suitable
  - Max 5 EC2 instances per region
  - AutoShutdown tags recommended
  - 7-day backup retention

### Staging Environment
- **Compute**: Up to m5.xlarge instances
- **RDS**: Up to db.r5.xlarge
- **Storage**: Max 500GB per EBS volume
- **Requirements**:
  - Spot instances strongly recommended
  - Max 10 EC2 instances per region
  - 14-day backup retention
  - 30-day log retention

### Production Environment
- **Compute**: Up to m5.4xlarge instances
- **RDS**: Up to db.r5.8xlarge
- **Storage**: Max 1TB per EBS volume
- **Requirements**:
  - Max 50 EC2 instances per region
  - Spot instances for fault-tolerant workloads
  - 35-day backup retention
  - 90-day log retention

## Cost Optimization Features

### Automatic Spot Instance Detection
- Identifies workloads suitable for Spot instances
- Calculates potential savings (60-70% typical)
- Enforces Spot usage in development
- Recommends mixed instance policies for ASGs

### Storage Cost Management
- Limits EBS volume sizes by environment
- Controls backup retention periods
- Monitors CloudWatch log retention
- Detects unattached EBS volumes

### Network Cost Control
- Limits NAT Gateway deployment
- Recommends NAT instances for development
- Suggests VPC endpoints for AWS services
- Monitors data transfer patterns

### Unused Resource Detection
- Identifies unattached Elastic IPs
- Detects load balancers without targets
- Finds standalone EBS volumes
- Checks for indefinite log retention

## Implementation Guide

### 1. Terraform Cloud/Enterprise Integration

```hcl
# In your Terraform Cloud workspace settings
enforcement_mode = "hard-mandatory"
policy_set_id = "polset-xxx"
```

### 2. Environment-Specific Policy Sets

Create separate policy sets for each environment:

```hcl
# development.hcl
policies = {
  "enforce-instance-types" = "hard-mandatory"
  "enforce-spot-instances" = "hard-mandatory"
  "limit-storage-sizes" = "hard-mandatory"
}

# production.hcl  
policies = {
  "enforce-instance-types" = "soft-mandatory"
  "prevent-expensive-resources" = "hard-mandatory"
  "enforce-cost-tags" = "hard-mandatory"
}
```

### 3. Local Testing

```bash
# Install Sentinel CLI
# Test individual policies
sentinel test -run=enforce-instance-types

# Test all policies
sentinel test
```

## Cost Savings Potential

### Typical Monthly Savings by Policy

| Policy | Development | Staging | Production |
|--------|-------------|---------|------------|
| Spot Instances | 60-70% | 40-50% | 20-30% |
| Instance Sizing | 30-40% | 20-30% | 10-15% |
| Storage Limits | 20-30% | 15-20% | 10-15% |
| NAT Gateway Control | $30-90/month | $30-180/month | Variable |
| Backup Optimization | 20-40% | 15-25% | 10-20% |
| Unused Resource Prevention | Variable | Variable | Variable |

### Example Cost Impact

**Development Environment (per month):**
- Without policies: ~$500-1000
- With policies: ~$200-400
- **Savings: 50-60%**

**Staging Environment (per month):**
- Without policies: ~$1000-2000  
- With policies: ~$600-1200
- **Savings: 30-40%**

**Production Environment (per month):**
- Savings vary based on workload characteristics
- **Typical savings: 15-25%**

## Compliance and Governance

### Required Tags for Cost Tracking
- `Environment` - dev/staging/prod
- `CostCenter` - Department or project code
- `ManagedBy` - Team or individual responsible
- `Project` - Project or application name

### Optional Cost Optimization Tags
- `AutoShutdown` - true/false for development resources
- `SpotExempt` - true to exempt from Spot requirements
- `Purpose` - Detailed resource purpose
- `CostOptimized` - Special cost optimization status

## Monitoring and Reporting

### Cost Tracking Integration
- Policies work with AWS Cost Explorer tags
- Enable detailed billing reports
- Use AWS Budgets for threshold alerts
- Implement cost anomaly detection

### Policy Violation Tracking
- Monitor Sentinel policy failures
- Track cost optimization compliance
- Generate monthly cost reports
- Identify optimization opportunities

## Customization

### Modifying Limits

Edit the policy files to adjust limits:

```sentinel
# In enforce-instance-types.sentinel
allowed_types = {
  "dev": ["t3.micro", "t3.small"],      # Restrict further
  "staging": ["t3.medium", "m5.large"], # Allow larger
  "prod": ["m5.large", "m5.xlarge"],    # Custom production limits
}
```

### Adding New Policies

1. Create new policy file in `cost-control/`
2. Add policy definition to `sentinel.hcl`
3. Test with `sentinel test`
4. Deploy to policy set

### Environment-Specific Overrides

```sentinel
# Custom environment detection
if strings.contains(address, "special-project") {
  return "custom"
}
```

## Troubleshooting

### Common Policy Violations

1. **Instance Type Violations**
   - Check environment tagging
   - Verify instance type against allowed list
   - Consider environment-specific requirements

2. **Storage Size Violations**
   - Review storage requirements
   - Split large volumes if possible
   - Request exemption with justification

3. **Missing Cost Tags**
   - Add required tags to resources
   - Use consistent tag values
   - Implement tag inheritance

### Debugging Policies

```bash
# Test with verbose output
sentinel test -verbose

# Test specific scenarios
sentinel test -run=test-dev-instance-types

# Validate syntax
sentinel fmt
```

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Terraform Plan and Policy Check
on: [pull_request]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Terraform Plan
        run: terraform plan -out=plan.tfplan
      - name: Sentinel Policy Check
        run: sentinel test policies/
```

### Policy as Code Benefits

- **Version Control** - Track policy changes
- **Code Review** - Review policy modifications
- **Automated Testing** - Test policies in CI/CD
- **Consistent Enforcement** - Apply same rules across environments

## Support and Maintenance

### Regular Reviews
- Monthly policy effectiveness review
- Quarterly cost savings analysis
- Annual policy limit adjustments
- Continuous optimization opportunities

### Policy Updates
- AWS service updates and new features
- Cost optimization best practices
- Business requirement changes
- Compliance requirement updates

## Getting Started

1. **Deploy Policies**
   ```bash
   # Copy policies to Terraform Cloud policy set
   # Or integrate with local Sentinel CLI
   ```

2. **Configure Enforcement**
   - Set appropriate enforcement levels
   - Create environment-specific policy sets
   - Test with non-production workloads

3. **Monitor Results**
   - Track policy violations
   - Measure cost savings
   - Gather team feedback
   - Iterate and improve

4. **Optimize Regularly**
   - Review cost reports monthly
   - Update limits based on usage patterns
   - Add new policies for emerging cost drivers
   - Share best practices across teams

For questions or support, please refer to the Sentinel documentation or contact the platform engineering team.

