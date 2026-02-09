# Cloudflare IP Access Rules - Security Module

This module manages Cloudflare IP access rules via YAML configuration.

> [!NOTE]
> This is a **Terraform module**. It should be called from the root configuration, not executed directly.

## 📋 Quick Start

### 1. Configure Rules

Edit the configuration file at the root level:


### 2. Apply Changes

From the **root directory**:

```bash
cd /home/expert/cf-internal
terraform plan    # Preview changes
terraform apply   # Apply changes
```

> [!IMPORTANT]
> Always run Terraform commands from the **root directory** (`/home/expert/cf-internal`), not from the module directory.

---

## 🔧 Configuration Reference

### YAML Structure

```yaml
ip_access_rules:
  - ip: "<IP_ADDRESS_OR_CIDR>"
    mode: "<MODE>"
    scope: "<SCOPE>"  # Optional, defaults to "account"
    notes: "<EXPLANATION>"
```

### Field Descriptions

| Field | Required | Valid Values | Description |
|-------|----------|--------------|-------------|
| `ip` | ✅ Yes | IPv4 address or CIDR | The IP to apply the rule to (e.g., `198.51.100.4` or `203.0.113.0/24`) |
| `mode` | ✅ Yes | `block`, `challenge`, `whitelist`, `js_challenge`, `managed_challenge` | The action to take for this IP |
| `scope` | ❌ No | `account`, `zone` | Where to apply the rule (defaults to `account`) |
| `notes` | ✅ Yes | Any string | Explanation with date/reason |

---

## 📝 Common Workflows

### Adding a New Rule

1. Edit `shared/config.yaml` and add a new entry
2. Run `terraform plan` to preview
3. Run `terraform apply` to create the rule

**Example:**
```yaml
ip_access_rules:
  - ip: "192.0.2.50"
    mode: "block"
    notes: "This rule is enabled because of brute force attack on 2026-02-09"
```

### Updating an Existing Rule

1. Edit the rule in `shared/config.yaml` (change mode, notes, etc.)
2. Run `terraform plan` to see the update
3. Run `terraform apply` to apply changes

**Example:** Change from `challenge` to `block`:
```yaml
  - ip: "198.51.100.4"
    mode: "block"  # Changed from "challenge"
    notes: "This rule is enabled because escalated threat on 2026-02-10"
```

### Deleting a Rule (Unblocking)

1. Remove the entry from `shared/config.yaml`
2. Run `terraform plan` to see the deletion
3. Run `terraform apply` to remove the rule

> [!WARNING]
> There is no "disable" option. To unblock an IP, you must delete the rule entirely.

---

## 🔄 Importing Existing Rules

If you have existing rules in Cloudflare that you want to manage with Terraform:

### Step 1: Find the Rule ID

Go to Cloudflare Dashboard → Security → WAF → Tools → IP Access Rules, or use the API:

```bash
curl -X GET "https://api.cloudflare.com/client/v4/accounts/a646a5b04f5bd1a4cdcaaf82711d8de1/firewall/access_rules/rules" \
  -H "Authorization: Bearer YOUR_API_TOKEN"
```

### Step 2: Import the Rule

For **account-level** rules:
```bash
terraform import 'cloudflare_access_rule.ip_rules["account-198.51.100.4"]' 'accounts/a646a5b04f5bd1a4cdcaaf82711d8de1/<RULE_ID>'
```

For **zone-level** rules:
```bash
terraform import 'cloudflare_access_rule.ip_rules["zone-203.0.113.0-24"]' 'zones/52d3466c4c4cbbf14ffee4f0f779a931/<RULE_ID>'
```

> [!IMPORTANT]
> The key in brackets must match the format: `scope-ip` where `/` in IP is replaced with `-`
> - Example: `account-198.51.100.4` for IP `198.51.100.4`
> - Example: `zone-203.0.113.0-24` for CIDR `203.0.113.0/24`

### Step 3: Add to config.yaml

Add a matching entry to `shared/config.yaml`:

```yaml
ip_access_rules:
  - ip: "198.51.100.4"
    mode: "block"
    scope: "account"
    notes: "Imported existing rule from 2026-01-15"
```

### Step 4: Verify

Run `terraform plan` - it should show **no changes** if the import was successful.

---

## ✅ Validation

The Terraform configuration validates:

1. **IP Format**: Must be valid IPv4 (e.g., `198.51.100.4` or `203.0.113.0/24`)
2. **Mode Values**: Must be one of: `block`, `challenge`, `whitelist`, `js_challenge`, `managed_challenge`
3. **Scope Values**: Must be either `account` or `zone`
4. **Notes Field**: Must be present and non-empty

### Validation Examples

**❌ Invalid IP Format:**
```yaml
  - ip: "invalid-ip"  # Will fail validation
    mode: "block"
    notes: "Test"
```

**❌ Invalid Mode:**
```yaml
  - ip: "198.51.100.4"
    mode: "allow"  # Invalid - should be "whitelist"
    notes: "Test"
```

**❌ Missing Notes:**
```yaml
  - ip: "198.51.100.4"
    mode: "block"
    # Missing notes field - will fail validation
```

**✅ Valid Configuration:**
```yaml
  - ip: "198.51.100.4"
    mode: "block"
    scope: "account"
    notes: "This rule is enabled because of security incident on 2026-02-09"
```

---

## 🎯 Scope: Account vs Zone

### Account-Level Rules (Default)
- Apply to **all zones** under the account
- Use when blocking IPs organization-wide
- More efficient for managing global threats

```yaml
  - ip: "198.51.100.4"
    mode: "block"
    scope: "account"  # or omit - defaults to "account"
    notes: "Global threat"
```

### Zone-Level Rules
- Apply to **specific zone** only
- Use for domain-specific security
- More granular control

```yaml
  - ip: "203.0.113.0/24"
    mode: "challenge"
    scope: "zone"
    notes: "Suspicious activity on this domain only"
```

---

## 🔍 Viewing Created Rules

After applying, view the output:

```bash
terraform output access_rules
```

This shows:
- Rule IDs
- IP addresses
- Modes
- Scope (account/zone)
- Notes

---

## 🛠️ Troubleshooting

### Error: "Invalid IP format"
- Ensure IP is in correct format: `198.51.100.4` or `203.0.113.0/24`
- IPv6 is not currently supported

### Error: "Invalid mode"
- Check spelling of mode value
- Valid values: `block`, `challenge`, `whitelist`, `js_challenge`, `managed_challenge`

### Error: "Notes field is required"
- Every rule must have a `notes` field
- Notes cannot be empty

### Import fails
- Verify the rule ID is correct
- Ensure the key format matches: `scope-ip` (replace `/` with `-`)
- Check that account_id/zone_id matches the rule's scope

---

## 📚 Additional Resources

- [Cloudflare Access Rules Documentation](https://developers.cloudflare.com/waf/tools/ip-access-rules/)
- [Terraform Cloudflare Provider](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/access_rule)
