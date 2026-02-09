output "access_rules" {
  description = "Created IP access rules with their details"
  value = {
    for key, rule in cloudflare_access_rule.ip_rules : key => {
      id       = rule.id
      ip       = rule.configuration.value
      mode     = rule.mode
      scope    = rule.account_id != null ? "account" : "zone"
      scope_id = rule.account_id != null ? rule.account_id : rule.zone_id
      notes    = rule.notes
    }
  }
}

output "import_commands" {
  description = "Commands to import existing rules (for reference)"
  value = {
    for key, rule in cloudflare_access_rule.ip_rules : key => 
      rule.account_id != null ? 
        "terraform import 'module.security.cloudflare_access_rule.ip_rules[\"${key}\"]' 'accounts/${rule.account_id}/<existing_rule_id>'" :
        "terraform import 'module.security.cloudflare_access_rule.ip_rules[\"${key}\"]' 'zones/${rule.zone_id}/<existing_rule_id>'"
  }
}

output "rule_count" {
  description = "Total number of IP access rules managed"
  value       = length(cloudflare_access_rule.ip_rules)
}
