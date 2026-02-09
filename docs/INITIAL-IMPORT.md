# Initial Import of Existing Cloudflare Rules

This is a **one-time process** to import existing Cloudflare IP access rules into Terraform management.

## ⚠️ Important

- This should be done **once** by the Platform Team
- After import, **all rules must be added via Terraform** (no manual changes in Cloudflare)
- This populates `shared/config.yaml` with all existing rules

## 📋 Prerequisites

- Terraform installed
- Cloudflare API token configured
- Access to Cloudflare dashboard

## 🔧 Import Process

### Step 1: Fetch Existing Rules

```bash
# Fetch account-level rules
curl -X GET "https://api.cloudflare.com/client/v4/accounts/a646a5b04f5bd1a4cdcaaf82711d8de1/firewall/access_rules/rules" \
  -H "Authorization: Bearer xW0b_hrxy-otoWEmFiQST1RT_Ak9hqCJLbVqzi8U" \
  -H "Content-Type: application/json" | jq '.' > account-rules.json

# Fetch zone-level rules
curl -X GET "https://api.cloudflare.com/client/v4/zones/52d3466c4c4cbbf14ffee4f0f779a931/firewall/access_rules/rules" \
  -H "Authorization: Bearer xW0b_hrxy-otoWEmFiQST1RT_Ak9hqCJLbVqzi8U" \
  -H "Content-Type: application/json" | jq '.' > zone-rules.json
```

### Step 2: Generate config.yaml

Manually create `shared/config.yaml` from the fetched rules:

```yaml
ip_access_rules:
  # Account-level rules
  - ip: "198.51.100.4"
    mode: "block"
    scope: "account"
    notes: "Imported from Cloudflare on 2026-02-09"
  
  # Zone-level rules
  - ip: "203.0.113.0/24"
    mode: "challenge"
    scope: "zone"
    notes: "Imported from Cloudflare on 2026-02-09"
  
  # ... add all existing rules ...
```

### Step 3: Import into Terraform State

For each rule, import into Terraform state:

```bash
cd /home/expert/cf-internal

# Initialize Terraform
terraform init

# Import account-level rules
terraform import 'module.security.cloudflare_access_rule.ip_rules["account-198.51.100.4"]' \
  'accounts/a646a5b04f5bd1a4cdcaaf82711d8de1/<RULE_ID_FROM_JSON>'

# Import zone-level rules
terraform import 'module.security.cloudflare_access_rule.ip_rules["zone-203.0.113.0-24"]' \
  'zones/52d3466c4c4cbbf14ffee4f0f779a931/<RULE_ID_FROM_JSON>'

# Repeat for all rules
```

**Note**: The key format is `scope-ip` where `/` in CIDR is replaced with `-`.

### Step 4: Verify

```bash
# Should show no changes if import was successful
terraform plan
```

Output should be:
```
No changes. Your infrastructure matches the configuration.
```

### Step 5: Commit to Master

```bash
git add shared/config.yaml
git commit -m "Initial import of existing Cloudflare rules"
git push origin main
```

## 🔒 After Import

**From this point forward:**
- ✅ All new rules must be added via Terraform (PR workflow)
- ❌ No manual changes in Cloudflare dashboard
- ✅ `shared/config.yaml` is the source of truth

## 🛠️ Helper Script (Optional)

Create a script to automate import:

```bash
#!/bin/bash
# import-all-rules.sh

# Read account rules and import
jq -r '.result[] | "\(.id) \(.configuration.value)"' account-rules.json | while read -r id ip; do
  key="account-${ip//\//-}"
  echo "Importing $key..."
  terraform import "module.security.cloudflare_access_rule.ip_rules[\"$key\"]" \
    "accounts/a646a5b04f5bd1a4cdcaaf82711d8de1/$id"
done

# Read zone rules and import
jq -r '.result[] | "\(.id) \(.configuration.value)"' zone-rules.json | while read -r id ip; do
  key="zone-${ip//\//-}"
  echo "Importing $key..."
  terraform import "module.security.cloudflare_access_rule.ip_rules[\"$key\"]" \
    "zones/52d3466c4c4cbbf14ffee4f0f779a931/$id"
done
```

## ✅ Verification Checklist

- [ ] Fetched all existing rules from Cloudflare
- [ ] Created `shared/config.yaml` with all rules
- [ ] Imported all rules into Terraform state
- [ ] Ran `terraform plan` - shows no changes
- [ ] Committed config.yaml to master
- [ ] Documented that manual changes are no longer allowed

## 📝 Communication

After import, notify the team:

> 🎉 Cloudflare IP access rules are now managed by Terraform!
> 
> **Going forward:**
> - Add rules via PR to `shared/config.yaml`
> - No manual changes in Cloudflare dashboard
> - See README.md for workflow
