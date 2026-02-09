#!/bin/bash
# auto-import-drift.sh - Automatically import unmanaged Cloudflare rules
# This script is run by CI/CD when drift is detected

set -e

echo "🔄 Auto-Import Unmanaged Rules"
echo "=============================="
echo ""

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
  echo "❌ Error: terraform.tfvars not found"
  exit 1
fi

# Extract values from terraform.tfvars
API_TOKEN=$(grep 'cloudflare_api_token' terraform.tfvars | cut -d'"' -f2)
ACCOUNT_ID=$(grep 'cloudflare_account_id' terraform.tfvars | cut -d'"' -f2)
ZONE_ID=$(grep 'cloudflare_zone_id' terraform.tfvars | cut -d'"' -f2)

if [ -z "$API_TOKEN" ]; then
  echo "❌ Error: API token not configured"
  exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  echo "❌ Error: jq is not installed"
  exit 1
fi

echo "📋 Step 1: Fetching rules from Cloudflare..."

# Fetch current rules from Cloudflare
curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/firewall/access_rules/rules" \
  -H "Authorization: Bearer ${API_TOKEN}" \
  -H "Content-Type: application/json" > /tmp/cf-account-rules.json

curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/firewall/access_rules/rules" \
  -H "Authorization: Bearer ${API_TOKEN}" \
  -H "Content-Type: application/json" > /tmp/cf-zone-rules.json

# Count rules
CF_ACCOUNT_COUNT=$(jq '.result | length' /tmp/cf-account-rules.json 2>/dev/null || echo "0")
CF_ZONE_COUNT=$(jq '.result | length' /tmp/cf-zone-rules.json 2>/dev/null || echo "0")
CF_TOTAL=$((CF_ACCOUNT_COUNT + CF_ZONE_COUNT))

echo "  Found: $CF_TOTAL rules ($CF_ACCOUNT_COUNT account, $CF_ZONE_COUNT zone)"

# Get Terraform state
echo ""
echo "📋 Step 2: Checking Terraform state..."

if [ ! -f "terraform.tfstate" ]; then
  TF_COUNT=0
else
  TF_COUNT=$(terraform state list 2>/dev/null | grep -c "cloudflare_access_rule.ip_rules" || echo "0")
fi

echo "  Terraform manages: $TF_COUNT rules"

# Check for drift
if [ "$CF_TOTAL" -le "$TF_COUNT" ]; then
  echo ""
  echo "✅ No unmanaged rules found"
  exit 0
fi

echo ""
echo "📥 Step 3: Importing unmanaged rules..."

# Get IPs from Terraform state
if [ -f "terraform.tfstate" ]; then
  terraform state list | grep "cloudflare_access_rule.ip_rules" | \
    sed 's/.*\["//;s-"\]$//' > /tmp/tf-rules.txt
else
  touch /tmp/tf-rules.txt
fi

# Backup config.yaml
cp shared/config.yaml shared/config.yaml.backup.$(date +%Y%m%d_%H%M%S)

IMPORTED_COUNT=0

# Process account-level rules
echo ""
echo "  Importing account-level rules..."
jq -c '.result[]' /tmp/cf-account-rules.json | while read -r rule; do
  IP=$(echo "$rule" | jq -r '.configuration.value')
  MODE=$(echo "$rule" | jq -r '.mode')
  NOTES=$(echo "$rule" | jq -r '.notes // "Imported from Cloudflare"')
  RULE_ID=$(echo "$rule" | jq -r '.id')
  
  RULE_KEY="account-${IP//\//-}"
  
  # Check if already in Terraform
  if ! grep -q "^${RULE_KEY}$" /tmp/tf-rules.txt; then
    echo "    Importing: $IP (ID: $RULE_ID)"
    
    # Add to config.yaml
    echo "  - ip: \"$IP\"" >> shared/config.yaml
    echo "    mode: \"$MODE\"" >> shared/config.yaml
    echo "    scope: \"account\"" >> shared/config.yaml
    echo "    notes: \"$NOTES (auto-imported on $(date +%Y-%m-%d))\"" >> shared/config.yaml
    
    # Import into Terraform state
    terraform import "module.security.cloudflare_access_rule.ip_rules[\"${RULE_KEY}\"]" \
      "accounts/${ACCOUNT_ID}/${RULE_ID}" 2>/dev/null || echo "      ⚠️  Import failed (may already exist)"
    
    IMPORTED_COUNT=$((IMPORTED_COUNT + 1))
  fi
done

# Process zone-level rules
echo ""
echo "  Importing zone-level rules..."
jq -c '.result[]' /tmp/cf-zone-rules.json | while read -r rule; do
  IP=$(echo "$rule" | jq -r '.configuration.value')
  MODE=$(echo "$rule" | jq -r '.mode')
  NOTES=$(echo "$rule" | jq -r '.notes // "Imported from Cloudflare"')
  RULE_ID=$(echo "$rule" | jq -r '.id')
  
  RULE_KEY="zone-${IP//\//-}"
  
  # Check if already in Terraform
  if ! grep -q "^${RULE_KEY}$" /tmp/tf-rules.txt; then
    echo "    Importing: $IP (ID: $RULE_ID)"
    
    # Add to config.yaml
    echo "  - ip: \"$IP\"" >> shared/config.yaml
    echo "    mode: \"$MODE\"" >> shared/config.yaml
    echo "    scope: \"zone\"" >> shared/config.yaml
    echo "    notes: \"$NOTES (auto-imported on $(date +%Y-%m-%d))\"" >> shared/config.yaml
    
    # Import into Terraform state
    terraform import "module.security.cloudflare_access_rule.ip_rules[\"${RULE_KEY}\"]" \
      "zones/${ZONE_ID}/${RULE_ID}" 2>/dev/null || echo "      ⚠️  Import failed (may already exist)"
    
    IMPORTED_COUNT=$((IMPORTED_COUNT + 1))
  fi
done

echo ""
echo "=============================="
echo "✅ Auto-import complete!"
echo ""
echo "Summary:"
echo "  Imported: $IMPORTED_COUNT rules"
echo "  Config updated: shared/config.yaml"
echo ""

if [ "$IMPORTED_COUNT" -gt 0 ]; then
  echo "⚠️  IMPORTANT: Review the imported rules in shared/config.yaml"
  echo "   These rules were manually added in Cloudflare and have been auto-imported."
  exit 0
else
  echo "✅ No new rules to import"
  exit 0
fi
