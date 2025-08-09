# =============================================================================
# SENTINEL CONFIGURATION FOR TERRAFORM CLOUD / ENTERPRISE
# =============================================================================
# Cost control and governance policies for multi-region infrastructure

# Policy configuration
policy "enforce-instance-types" {
  source = "./cost-control/enforce-instance-types.sentinel"
  enforcement_level = "soft-mandatory"
}

policy "limit-rds-instance-sizes" {
  source = "./cost-control/limit-rds-instance-sizes.sentinel"
  enforcement_level = "soft-mandatory"
}

policy "prevent-expensive-resources" {
  source = "./cost-control/prevent-expensive-resources.sentinel"
  enforcement_level = "hard-mandatory"
}

policy "enforce-cost-tags" {
  source = "./cost-control/enforce-cost-tags.sentinel"
  enforcement_level = "soft-mandatory"
}

policy "limit-storage-sizes" {
  source = "./cost-control/limit-storage-sizes.sentinel"
  enforcement_level = "soft-mandatory"
}

policy "enforce-environment-specific-limits" {
  source = "./cost-control/enforce-environment-specific-limits.sentinel"
  enforcement_level = "soft-mandatory"
}

policy "prevent-unused-resources" {
  source = "./cost-control/prevent-unused-resources.sentinel"
  enforcement_level = "advisory"
}

policy "enforce-backup-retention-limits" {
  source = "./cost-control/enforce-backup-retention-limits.sentinel"
  enforcement_level = "soft-mandatory"
}

policy "limit-nat-gateways" {
  source = "./cost-control/limit-nat-gateways.sentinel"
  enforcement_level = "soft-mandatory"
}

policy "enforce-spot-instances" {
  source = "./cost-control/enforce-spot-instances.sentinel"
  enforcement_level = "advisory"
}

# Policy sets for different environments
policy_set "development-cost-controls" {
  source = "./policy-sets/development.hcl"
}

policy_set "staging-cost-controls" {
  source = "./policy-sets/staging.hcl"
}

policy_set "production-cost-controls" {
  source = "./policy-sets/production.hcl"
}
