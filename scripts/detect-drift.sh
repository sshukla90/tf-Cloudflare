#!/bin/bash
# detect-drift.sh - Detect manual changes in Cloudflare not managed by Terraform
# This script compares Cloudflare's actual state with Terraform's expected state

set -e

echo "🔍 Cloudflare Drift Detection"
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

echo "📋 Fetching current state from Cloudflare..."

# Fetch current rules from Cloudflare
curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/firewall/access_rules/rules" \
  -H "Authorization: Bearer ${API_TOKEN}" \
  -H "Content-Type: application/json" > /tmp/cf-account-rules.json

curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/firewall/access_rules/rules" \
  -H "Authorization: Bearer ${API_TOKEN}" \
  -H "Content-Type: application/json" > /tmp/cf-zone-rules.json

# Count rules in Cloudflare
CF_ACCOUNT_COUNT=$(jq '.result | length' /tmp/cf-account-rules.json 2>/dev/null || echo "0")
CF_ZONE_COUNT=$(jq '.result | length' /tmp/cf-zone-rules.json 2>/dev/null || echo "0")
CF_TOTAL=$((CF_ACCOUNT_COUNT + CF_ZONE_COUNT))

echo "  Cloudflare: $CF_TOTAL rules ($CF_ACCOUNT_COUNT account, $CF_ZONE_COUNT zone)"

# Get Terraform state
echo ""
echo "📋 Checking Terraform state..."

if [ ! -f "terraform.tfstate" ]; then
  echo "⚠️  Warning: No terraform.tfstate found (run 'terraform init' and 'terraform apply' first)"
  TF_COUNT=0
else
  TF_COUNT=$(terraform state list 2>/dev/null | grep -c "cloudflare_access_rule.ip_rules" || echo "0")
  echo "  Terraform: $TF_COUNT rules in state"
fi

# Read config.yaml
echo ""
echo "📋 Checking config.yaml..."

if [ ! -f "shared/config.yaml" ]; then
  echo "❌ Error: shared/config.yaml not found"
  exit 1
fi

CONFIG_COUNT=$(yq eval '.ip_access_rules | length' shared/config.yaml 2>/dev/null || \
               grep -c "^  - ip:" shared/config.yaml 2>/dev/null || echo "0")
echo "  Config: $CONFIG_COUNT rules defined"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Detect drift
DRIFT_DETECTED=0

# Check if Cloudflare has more rules than Terraform
if [ "$CF_TOTAL" -gt "$TF_COUNT" ]; then
  echo "⚠️  DRIFT DETECTED: Cloudflare has MORE rules than Terraform state"
  echo "   Cloudflare: $CF_TOTAL rules"
  echo "   Terraform:  $TF_COUNT rules"
  echo "   Difference: $((CF_TOTAL - TF_COUNT)) unmanaged rules"
  echo ""
  DRIFT_DETECTED=1
fi

# Check if config.yaml matches Terraform state
if [ "$CONFIG_COUNT" -ne "$TF_COUNT" ] && [ "$TF_COUNT" -gt 0 ]; then
  echo "⚠️  DRIFT DETECTED: config.yaml doesn't match Terraform state"
  echo "   Config:    $CONFIG_COUNT rules"
  echo "   Terraform: $TF_COUNT rules"
  echo ""
  DRIFT_DETECTED=1
fi

# Detailed comparison: Find unmanaged rules
if [ "$DRIFT_DETECTED" -eq 1 ]; then
  echo "🔍 Analyzing unmanaged rules..."
  echo ""
  
  # Get IPs from Terraform state
  if [ -f "terraform.tfstate" ]; then
    terraform state list | grep "cloudflare_access_rule.ip_rules" | \
      sed 's/.*\["//;s-"\]$//' > /tmp/tf-rules.txt
  else
    touch /tmp/tf-rules.txt
  fi
  
  # Get IPs from Cloudflare (account-level)
  jq -r '.result[] | "account-\(.configuration.value)"' /tmp/cf-account-rules.json | \
    sed 's/\//-/g' > /tmp/cf-account-rules.txt
  
  # Get IPs from Cloudflare (zone-level)
  jq -r '.result[] | "zone-\(.configuration.value)"' /tmp/cf-zone-rules.json | \
    sed 's/\//-/g' > /tmp/cf-zone-rules.txt
  
  cat /tmp/cf-account-rules.txt /tmp/cf-zone-rules.txt > /tmp/cf-all-rules.txt
  
  # Find rules in Cloudflare but not in Terraform
  echo "📌 Rules in Cloudflare NOT managed by Terraform:"
  echo ""
  
  UNMANAGED_FOUND=0
  while IFS= read -r cf_rule; do
    if ! grep -q "^${cf_rule}$" /tmp/tf-rules.txt; then
      UNMANAGED_FOUND=1
      
      # Get details from Cloudflare
      SCOPE=$(echo "$cf_rule" | cut -d'-' -f1)
      IP=$(echo "$cf_rule" | cut -d'-' -f2- | sed 's/-/\//g')
      
      if [ "$SCOPE" = "account" ]; then
        DETAILS=$(jq -r ".result[] | select(.configuration.value == \"$IP\") | \"\(.mode) | \(.notes)\"" /tmp/cf-account-rules.json)
        RULE_ID=$(jq -r ".result[] | select(.configuration.value == \"$IP\") | .id" /tmp/cf-account-rules.json)
      else
        DETAILS=$(jq -r ".result[] | select(.configuration.value == \"$IP\") | \"\(.mode) | \(.notes)\"" /tmp/cf-zone-rules.json)
        RULE_ID=$(jq -r ".result[] | select(.configuration.value == \"$IP\") | .id" /tmp/cf-zone-rules.json)
      fi
      
      MODE=$(echo "$DETAILS" | cut -d'|' -f1 | xargs)
      NOTES=$(echo "$DETAILS" | cut -d'|' -f2- | xargs)
      
      echo "  ⚠️  $IP ($SCOPE-level)"
      echo "      Mode: $MODE"
      echo "      Notes: $NOTES"
      echo "      Rule ID: $RULE_ID"
      echo ""
      echo "      To import into Terraform:"
      if [ "$SCOPE" = "account" ]; then
        echo "      terraform import 'module.security.cloudflare_access_rule.ip_rules[\"${cf_rule}\"]' 'accounts/${ACCOUNT_ID}/${RULE_ID}'"
      else
        echo "      terraform import 'module.security.cloudflare_access_rule.ip_rules[\"${cf_rule}\"]' 'zones/${ZONE_ID}/${RULE_ID}'"
      fi
      echo ""
    fi
  done < /tmp/cf-all-rules.txt
  
  if [ "$UNMANAGED_FOUND" -eq 0 ]; then
    echo "  ✅ No unmanaged rules found (drift is in Terraform state only)"
    echo ""
  fi
fi

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$DRIFT_DETECTED" -eq 1 ]; then
  echo "❌ DRIFT DETECTED - Manual changes found!"
  echo ""
  echo "Recommended actions:"
  echo "  1. Import unmanaged rules using the commands above"
  echo "  2. Add them to shared/config.yaml"
  echo "  3. Run 'terraform plan' to verify"
  echo "  4. Commit changes to Git"
  echo ""
  echo "Or, if these rules should be removed:"
  echo "  1. Delete them from Cloudflare dashboard"
  echo "  2. Run 'terraform plan' to verify"
  echo ""
  exit 1
else
  echo "✅ NO DRIFT DETECTED - Terraform state matches Cloudflare!"
  echo ""
  echo "Summary:"
  echo "  Cloudflare: $CF_TOTAL rules"
  echo "  Terraform:  $TF_COUNT rules"
  echo "  Config:     $CONFIG_COUNT rules"
  echo ""
  exit 0
fi
