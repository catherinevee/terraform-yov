# =============================================================================
# OPEN POLICY AGENT (OPA) TERRAFORM POLICIES
# =============================================================================
# Enterprise security policies for Terraform using OPA Rego
# Enforces organizational standards and compliance requirements

package terraform.security

import future.keywords.in

# =============================================================================
# AWS RESOURCE NAMING STANDARDS
# =============================================================================

# Enforce naming convention for all AWS resources
naming_convention_violation[msg] {
    resource := input.resource_changes[_]
    resource.type in [
        "aws_instance",
        "aws_s3_bucket", 
        "aws_rds_instance",
        "aws_eks_cluster",
        "aws_vpc",
        "aws_subnet"
    ]
    
    name := resource.change.after.name
    not regex.match("^yov-[a-z]+-[a-z0-9-]+$", name)
    
    msg := sprintf("Resource %s does not follow naming convention 'yov-<env>-<component>'", [name])
}

# =============================================================================
# TAGGING REQUIREMENTS
# =============================================================================

# Require mandatory tags on all resources
required_tags := {
    "Environment",
    "Application", 
    "Owner",
    "CostCenter",
    "Project"
}

missing_required_tags[msg] {
    resource := input.resource_changes[_]
    resource.type in [
        "aws_instance",
        "aws_s3_bucket",
        "aws_rds_instance", 
        "aws_eks_cluster",
        "aws_vpc"
    ]
    
    existing_tags := object.get(resource.change.after, "tags", {})
    missing_tag := required_tags[_]
    not missing_tag in object.keys(existing_tags)
    
    msg := sprintf("Resource %s missing required tag: %s", [resource.address, missing_tag])
}

# =============================================================================
# SECURITY POLICIES
# =============================================================================

# Prohibit public S3 buckets
public_s3_bucket_violation[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket_public_access_block"
    
    config := resource.change.after
    
    # All public access should be blocked
    not config.block_public_acls == true
    msg := "S3 bucket must have block_public_acls enabled"
}

public_s3_bucket_violation[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket_public_access_block"
    
    config := resource.change.after
    
    not config.block_public_policy == true
    msg := "S3 bucket must have block_public_policy enabled"
}

public_s3_bucket_violation[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket_public_access_block"
    
    config := resource.change.after
    
    not config.ignore_public_acls == true
    msg := "S3 bucket must have ignore_public_acls enabled"
}

public_s3_bucket_violation[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket_public_access_block"
    
    config := resource.change.after
    
    not config.restrict_public_buckets == true
    msg := "S3 bucket must have restrict_public_buckets enabled"
}

# Require encryption for RDS instances
rds_encryption_violation[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_db_instance"
    
    config := resource.change.after
    not config.storage_encrypted == true
    
    msg := sprintf("RDS instance %s must have storage encryption enabled", [config.identifier])
}

# Require encryption for EBS volumes
ebs_encryption_violation[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_ebs_volume"
    
    config := resource.change.after
    not config.encrypted == true
    
    msg := "EBS volumes must be encrypted"
}

# =============================================================================
# NETWORK SECURITY POLICIES
# =============================================================================

# Prohibit overly permissive security group rules
overly_permissive_sg_rule[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_security_group_rule"
    
    config := resource.change.after
    config.type == "ingress"
    
    # Check for 0.0.0.0/0 in cidr_blocks
    "0.0.0.0/0" in config.cidr_blocks
    
    # Allow only specific ports for public access
    not config.from_port in [80, 443]
    
    msg := sprintf("Security group rule allows overly permissive access from 0.0.0.0/0 on port %d", [config.from_port])
}

# Require private subnets for databases
database_subnet_violation[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_db_subnet_group"
    
    # This would need to be enhanced to check actual subnet routing
    # For now, ensure naming convention indicates private subnets
    subnet_ids := resource.change.after.subnet_ids
    
    subnet_id := subnet_ids[_]
    not regex.match(".*private.*", subnet_id)
    
    msg := sprintf("Database subnet group contains non-private subnet: %s", [subnet_id])
}

# =============================================================================
# COST CONTROL POLICIES
# =============================================================================

# Limit instance types for non-production environments
expensive_instance_violation[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_instance"
    
    config := resource.change.after
    environment := object.get(config.tags, "Environment", "unknown")
    
    # Restrict expensive instance types in dev/staging
    environment in ["dev", "staging"]
    
    expensive_types := {
        "m5.large", "m5.xlarge", "m5.2xlarge", "m5.4xlarge",
        "c5.large", "c5.xlarge", "c5.2xlarge", "c5.4xlarge",
        "r5.large", "r5.xlarge", "r5.2xlarge", "r5.4xlarge"
    }
    
    config.instance_type in expensive_types
    
    msg := sprintf("Instance type %s not allowed in %s environment", [config.instance_type, environment])
}

# Limit RDS instance sizes for non-production
expensive_rds_violation[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_db_instance"
    
    config := resource.change.after
    environment := object.get(config.tags, "Environment", "unknown")
    
    environment in ["dev", "staging"]
    
    expensive_classes := {
        "db.r6g.large", "db.r6g.xlarge", "db.r6g.2xlarge",
        "db.r5.large", "db.r5.xlarge", "db.r5.2xlarge"
    }
    
    config.instance_class in expensive_classes
    
    msg := sprintf("RDS instance class %s not allowed in %s environment", [config.instance_class, environment])
}

# =============================================================================
# COMPLIANCE POLICIES
# =============================================================================

# Ensure CloudTrail is enabled
cloudtrail_required[msg] {
    # Count CloudTrail resources
    cloudtrail_count := count([
        resource |
        resource := input.resource_changes[_]
        resource.type == "aws_cloudtrail"
    ])
    
    cloudtrail_count == 0
    msg := "CloudTrail must be enabled for audit logging"
}

# Ensure VPC Flow Logs are enabled
vpc_flow_logs_required[msg] {
    vpc_resources := [
        resource |
        resource := input.resource_changes[_]
        resource.type == "aws_vpc"
    ]
    
    count(vpc_resources) > 0
    
    flow_log_count := count([
        resource |
        resource := input.resource_changes[_]
        resource.type == "aws_flow_log"
    ])
    
    flow_log_count == 0
    msg := "VPC Flow Logs must be enabled for network monitoring"
}

# =============================================================================
# POLICY AGGREGATION
# =============================================================================

# Aggregate all violations
violations := array.concat([
    naming_convention_violation,
    missing_required_tags,
    public_s3_bucket_violation,
    rds_encryption_violation,
    ebs_encryption_violation,
    overly_permissive_sg_rule,
    database_subnet_violation,
    expensive_instance_violation,
    expensive_rds_violation,
    cloudtrail_required,
    vpc_flow_logs_required
])

# Policy evaluation result
deny[msg] {
    violations[_] = msg
}
