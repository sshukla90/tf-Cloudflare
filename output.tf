# Aggregated outputs from all modules

# Security Module Outputs
output "security_access_rules" {
  description = "IP access rules from security module"
  value       = module.security.access_rules
}

output "security_rule_count" {
  description = "Total number of IP access rules managed"
  value       = module.security.rule_count
}

output "security_import_commands" {
  description = "Import commands for existing rules"
  value       = module.security.import_commands
}
