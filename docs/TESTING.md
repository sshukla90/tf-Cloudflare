# Testing Guide

This guide walks through testing the Terraform setup manually.

## 🧪 Test Scenario

You will act as a user who:
1. Clones the repo
2. Adds a new IP rule
3. Runs terraform init, plan, and apply

## 📋 Prerequisites

- Terraform installed
- API token configured in `terraform.tfvars`

## 🚀 Test Steps

### Step 1: Setup

```bash
# Navigate to repo
cd /home/expert/cf-internal

# Verify terraform.tfvars exists and has your API token
cat terraform.tfvars
# Should show:
# cloudflare_api_token  = "xW0b_hrxy-otoWEmFiQST1RT_Ak9hqCJLbVqzi8U"
# cloudflare_account_id = "a646a5b04f5bd1a4cdcaaf82711d8de1"
# cloudflare_zone_id    = "52d3466c4c4cbbf14ffee4f0f779a931"
```

### Step 2: Initialize Terraform

```bash
terraform init
```

**Expected Output:**
```
Initializing modules...
Initializing the backend...
Initializing provider plugins...
- Finding cloudflare/cloudflare versions matching "~> 5.0"...
- Installing cloudflare/cloudflare v5.x.x...

Terraform has been successfully initialized!
```

### Step 3: Check Current State

```bash
terraform plan
```

**Expected Output:**
```
Terraform will perform the following actions:

  # module.security.cloudflare_access_rule.ip_rules["account-198.51.100.4"] will be created
  + resource "cloudflare_access_rule" "ip_rules" {
      + id    = (known after apply)
      + mode  = "block"
      + notes = "This rule is enabled because of security incident on 2026-02-09"
      ...
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

This shows the example rule from config.yaml will be created.

### Step 4: Add Your Test Rule

Edit `shared/config.yaml`:

```yaml
ip_access_rules:
  # Existing example rule
  - ip: "198.51.100.4"
    mode: "block"
    scope: "account"
    notes: "This rule is enabled because of security incident on 2026-02-09"
  
  # YOUR NEW TEST RULE - Add this:
  - ip: "1.1.1.1"
    mode: "block"
    scope: "account"
    notes: "Added by [Your Name] on 2026-02-09 - Test rule - Ticket: TEST-001"
```

### Step 5: Plan Changes

```bash
terraform plan
```

**Expected Output:**
```
Terraform will perform the following actions:

  # module.security.cloudflare_access_rule.ip_rules["account-198.51.100.4"] will be created
  + resource "cloudflare_access_rule" "ip_rules" {
      + mode = "block"
      + notes = "This rule is enabled because of security incident on 2026-02-09"
      ...
    }

  # module.security.cloudflare_access_rule.ip_rules["account-1.1.1.1"] will be created
  + resource "cloudflare_access_rule" "ip_rules" {
      + mode = "block"
      + notes = "Added by [Your Name] on 2026-02-09 - Test rule - Ticket: TEST-001"
      ...
    }

Plan: 2 to add, 0 to change, 0 to destroy.
```

### Step 6: Apply Changes

```bash
terraform apply
```

Type `yes` when prompted.

**Expected Output:**
```
module.security.cloudflare_access_rule.ip_rules["account-198.51.100.4"]: Creating...
module.security.cloudflare_access_rule.ip_rules["account-1.1.1.1"]: Creating...
module.security.cloudflare_access_rule.ip_rules["account-198.51.100.4"]: Creation complete after 2s [id=...]
module.security.cloudflare_access_rule.ip_rules["account-1.1.1.1"]: Creation complete after 2s [id=...]

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
```

### Step 7: Verify in Cloudflare

1. Go to Cloudflare Dashboard
2. Navigate to: Security → WAF → Tools → IP Access Rules
3. Verify both rules appear:
   - `198.51.100.4` - blocked
   - `1.1.1.1` - blocked

### Step 8: Test Update

Edit `shared/config.yaml` - change mode for your test rule:

```yaml
  - ip: "1.1.1.1"
    mode: "challenge"  # Changed from "block"
    scope: "account"
    notes: "Added by [Your Name] on 2026-02-09 - Test rule - Ticket: TEST-001"
```

Run:
```bash
terraform plan
```

**Expected Output:**
```
  # module.security.cloudflare_access_rule.ip_rules["account-1.1.1.1"] will be updated in-place
  ~ resource "cloudflare_access_rule" "ip_rules" {
      ~ mode = "block" -> "challenge"
      ...
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```

Apply:
```bash
terraform apply
```

### Step 9: Test Delete

Remove your test rule from `shared/config.yaml`:

```yaml
ip_access_rules:
  # Keep only the original example
  - ip: "198.51.100.4"
    mode: "block"
    scope: "account"
    notes: "This rule is enabled because of security incident on 2026-02-09"
  
  # Removed the 1.1.1.1 rule
```

Run:
```bash
terraform plan
```

**Expected Output:**
```
  # module.security.cloudflare_access_rule.ip_rules["account-1.1.1.1"] will be destroyed
  - resource "cloudflare_access_rule" "ip_rules" {
      - mode = "challenge"
      ...
    }

Plan: 0 to add, 0 to change, 1 to destroy.
```

Apply:
```bash
terraform apply
```

## ✅ Test Checklist

- [ ] `terraform init` succeeds
- [ ] `terraform plan` shows correct resources
- [ ] `terraform apply` creates rules in Cloudflare
- [ ] Rules appear in Cloudflare dashboard
- [ ] Can update rule (change mode)
- [ ] Can delete rule (remove from config.yaml)
- [ ] Validation works (try invalid IP, invalid mode, missing notes)

## 🧪 Validation Tests

### Test Invalid IP
Add to config.yaml:
```yaml
  - ip: "invalid-ip"
    mode: "block"
    notes: "Test"
```

Run `terraform plan`:
```
Error: Invalid IP format for 'invalid-ip'. Must be a valid IPv4 address or CIDR range.
```

### Test Invalid Mode
```yaml
  - ip: "2.2.2.2"
    mode: "allow"  # Invalid
    notes: "Test"
```

Run `terraform plan`:
```
Error: Invalid mode 'allow' for IP 2.2.2.2. Must be one of: block, challenge, whitelist, js_challenge, managed_challenge
```

### Test Missing Notes
```yaml
  - ip: "3.3.3.3"
    mode: "block"
    # Missing notes
```

Run `terraform plan`:
```
Error: Notes field is required for IP 3.3.3.3
```

## 🎉 Success Criteria

All tests pass ✅
- Rules created successfully
- Rules updated successfully
- Rules deleted successfully
- Validation catches errors
- Cloudflare dashboard shows correct rules

## 📝 Notes

- Keep the example rule (`198.51.100.4`) for reference
- Use test IPs that won't affect production
- Clean up test rules after testing
