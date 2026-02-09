terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

# Read and decode YAML configuration
locals {
  config_file = file(var.config_file_path)
  config_data = yamldecode(local.config_file)
  
  # Create a map of rules with unique keys
  # Key format: "scope-ip" (e.g., "account-198.51.100.4" or "zone-203.0.113.0-24")
  ip_rules = {
    for idx, rule in local.config_data.ip_access_rules : 
    "${lookup(rule, "scope", "account")}-${replace(rule.ip, "/", "-")}" => merge(
      rule,
      { scope = lookup(rule, "scope", "account") }
    )
  }
  
  # Validation: Valid modes
  valid_modes = ["block", "challenge", "whitelist", "js_challenge", "managed_challenge"]
  
  # Validation: Valid scopes
  valid_scopes = ["account", "zone"]
}

# Validation: Check all rules have valid modes
resource "null_resource" "validate_modes" {
  for_each = local.ip_rules
  
  lifecycle {
    precondition {
      condition     = contains(local.valid_modes, each.value.mode)
      error_message = "Invalid mode '${each.value.mode}' for IP ${each.value.ip}. Must be one of: ${join(", ", local.valid_modes)}"
    }
  }
}

# Validation: Check all rules have valid scopes
resource "null_resource" "validate_scopes" {
  for_each = local.ip_rules
  
  lifecycle {
    precondition {
      condition     = contains(local.valid_scopes, each.value.scope)
      error_message = "Invalid scope '${each.value.scope}' for IP ${each.value.ip}. Must be one of: ${join(", ", local.valid_scopes)}"
    }
  }
}

# Validation: Check all rules have notes
resource "null_resource" "validate_notes" {
  for_each = local.ip_rules
  
  lifecycle {
    precondition {
      condition     = can(each.value.notes) && length(trimspace(each.value.notes)) > 0
      error_message = "Notes field is required for IP ${each.value.ip}"
    }
  }
}

# Validation: Check IP format (basic regex for IPv4)
resource "null_resource" "validate_ip_format" {
  for_each = local.ip_rules
  
  lifecycle {
    precondition {
      condition = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}(/[0-9]{1,2})?$", each.value.ip))
      error_message = "Invalid IP format for '${each.value.ip}'. Must be a valid IPv4 address or CIDR range."
    }
  }
}

# Create Cloudflare IP Access Rules
resource "cloudflare_access_rule" "ip_rules" {
  for_each = local.ip_rules
  
  configuration {
    target = "ip"
    value  = each.value.ip
  }
  
  mode  = each.value.mode
  notes = each.value.notes
  
  # Use account_id for account-level rules, zone_id for zone-level rules
  # These are mutually exclusive
  account_id = each.value.scope == "account" ? var.cloudflare_account_id : null
  zone_id    = each.value.scope == "zone" ? var.cloudflare_zone_id : null
  
  depends_on = [
    null_resource.validate_modes,
    null_resource.validate_scopes,
    null_resource.validate_notes,
    null_resource.validate_ip_format
  ]
}
