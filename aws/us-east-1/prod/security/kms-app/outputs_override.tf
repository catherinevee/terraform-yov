# Override outputs to mark grants as sensitive
# This fixes the error: "Output refers to sensitive values"

output "grants" {
  description = "A map of grants created and their attributes"
  value       = module.kms.grants
  sensitive   = true
}
