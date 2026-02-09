#!/bin/bash
# drift-handler.sh - Unified drift detection and auto-import
# Production-grade script for managing Cloudflare IP access rule drift

set -e

# Configuration
MODE="${1:---import}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Logging functions
log_info() { echo "[INFO] $1"; }
log_success() { echo "[SUCCESS] $1"; }
log_error() { echo "[ERROR] $1"; }
log_warning() { echo "[WARNING] $1"; }

# Change to project root
cd "$PROJECT_ROOT"

log_info "Cloudflare Drift Detection and Auto-Import"
log_info "=========================================="
echo ""

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
  log_error "terraform.tfvars not found"
  exit 1
fi

# Extract values from terraform.tfvars
API_TOKEN=$(grep 'cloudflare_api_token' terraform.tfvars | cut -d'"' -f2)
ACCOUNT_ID=$(grep 'cloudflare_account_id' terraform.tfvars | cut -d'"' -f2)
ZONE_ID=$(grep 'cloudflare_zone_id' terraform.tfvars | cut -d'"' -f2)

if [ -z "$API_TOKEN" ]; then
  log_error "API token not configured in terraform.tfvars"
  exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  log_error "jq is not installed. Please install jq to continue."
  exit 1
fi

# Drift detection flags
DRIFT_DETECTED=0
COUNT_DRIFT=0
CONTENT_DRIFT=0

# Fetch rules from Cloudflare
fetch_cloudflare_rules() {
  log_info "Fetching rules from Cloudflare..."
  
  # Fetch account-level rules
  curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/firewall/access_rules/rules" \
    -H "Authorization: Bearer ${API_TOKEN}" \
    -H "Content-Type: application/json" > /tmp/cf-account-rules.json
  
  # Fetch zone-level rules (all)
  curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/firewall/access_rules/rules" \
    -H "Authorization: Bearer ${API_TOKEN}" \
    -H "Content-Type: application/json" > /tmp/cf-zone-rules-all.json
  
  # Filter zone API to only include zone-specific rules (not inherited account rules)
  jq '.result |= map(select(.scope.type == "zone"))' /tmp/cf-zone-rules-all.json > /tmp/cf-zone-rules.json
  
  # Count rules
  CF_ACCOUNT_COUNT=$(jq '.result | length' /tmp/cf-account-rules.json 2>/dev/null || echo "0")
  CF_ZONE_COUNT=$(jq '.result | length' /tmp/cf-zone-rules.json 2>/dev/null || echo "0")
  CF_TOTAL=$((CF_ACCOUNT_COUNT + CF_ZONE_COUNT))
  
  log_info "Cloudflare: $CF_TOTAL rules ($CF_ACCOUNT_COUNT account, $CF_ZONE_COUNT zone)"
}

# Get Terraform state
get_terraform_state() {
  log_info "Checking Terraform state..."
  
  if [ ! -f "terraform.tfstate" ]; then
    log_warning "No terraform.tfstate found (run 'terraform init' and 'terraform apply' first)"
    TF_COUNT=0
  else
    TF_COUNT=$(terraform state list 2>/dev/null | grep -c "cloudflare_access_rule.ip_rules" || echo "0")
  fi
  
  log_info "Terraform: $TF_COUNT rules in state"
}

# Check config.yaml
check_config() {
  log_info "Checking config.yaml..."
  
  if [ ! -f "shared/config.yaml" ]; then
    log_error "shared/config.yaml not found"
    exit 1
  fi
  
  CONFIG_COUNT=$(yq eval '.ip_access_rules | length' shared/config.yaml 2>/dev/null || \
                 grep -c "^  - ip:" shared/config.yaml 2>/dev/null || echo "0")
  log_info "Config: $CONFIG_COUNT rules defined"
}

# Detect count drift
detect_count_drift() {
  echo ""
  log_info "Checking for count drift..."
  
  if [ "$CF_TOTAL" -gt "$TF_COUNT" ]; then
    log_warning "Count drift detected: Cloudflare has MORE rules than Terraform"
    log_info "  Cloudflare: $CF_TOTAL rules"
    log_info "  Terraform:  $TF_COUNT rules"
    log_info "  Difference: $((CF_TOTAL - TF_COUNT)) unmanaged rules"
    COUNT_DRIFT=1
    DRIFT_DETECTED=1
  elif [ "$CF_TOTAL" -lt "$TF_COUNT" ]; then
    log_warning "Count drift detected: Terraform has MORE rules than Cloudflare"
    log_info "  Cloudflare: $CF_TOTAL rules"
    log_info "  Terraform:  $TF_COUNT rules"
    log_info "  Difference: $((TF_COUNT - CF_TOTAL)) rules missing in Cloudflare"
    COUNT_DRIFT=1
    DRIFT_DETECTED=1
  else
    log_success "No count drift detected"
  fi
}

# Detect content drift
detect_content_drift() {
  echo ""
  log_info "Checking for content drift..."
  
  if [ "$TF_COUNT" -eq 0 ]; then
    log_info "No Terraform state to compare"
    return
  fi
  
  CONTENT_DRIFT_FOUND=0
  
  # Get list of rules from Terraform state
  terraform state list 2>/dev/null | grep "cloudflare_access_rule.ip_rules" | while read -r tf_resource; do
    # Extract rule key (e.g., "account-1.1.1.1")
    RULE_KEY=$(echo "$tf_resource" | sed 's/.*\["\(.*\)"\]/\1/')
    SCOPE=$(echo "$RULE_KEY" | cut -d'-' -f1)
    IP=$(echo "$RULE_KEY" | cut -d'-' -f2- | sed 's/-/\//g')
    
    # Get mode from Terraform state
    TF_MODE=$(terraform state show "$tf_resource" 2>/dev/null | grep "^\s*mode\s*=" | awk -F'"' '{print $2}')
    
    # Get mode from Cloudflare
    if [ "$SCOPE" = "account" ]; then
      CF_MODE=$(jq -r ".result[] | select(.configuration.value == \"$IP\") | .mode" /tmp/cf-account-rules.json 2>/dev/null)
    else
      CF_MODE=$(jq -r ".result[] | select(.configuration.value == \"$IP\") | .mode" /tmp/cf-zone-rules.json 2>/dev/null)
    fi
    
    # Compare modes
    if [ -n "$CF_MODE" ] && [ "$CF_MODE" != "$TF_MODE" ]; then
      log_warning "Content drift: $IP ($SCOPE)"
      log_info "  Cloudflare: mode=$CF_MODE"
      log_info "  Terraform:  mode=$TF_MODE"
      CONTENT_DRIFT_FOUND=1
    fi
  done
  
  if [ "$CONTENT_DRIFT_FOUND" -eq 0 ]; then
    log_success "No content drift detected"
  else
    CONTENT_DRIFT=1
    DRIFT_DETECTED=1
  fi
}

# Check for duplicate IPs in config.yaml
check_duplicates() {
  log_info "Checking for duplicate IPs in config.yaml..."
  
  # Extract IP:scope pairs and check for duplicates
  DUPLICATES=$(yq eval '.ip_access_rules[] | "\(.ip):\(.scope // "account")"' shared/config.yaml 2>/dev/null | \
    sort | uniq -d)
  
  if [ -n "$DUPLICATES" ]; then
    log_error "Duplicate IP+scope combinations found in config.yaml:"
    echo "$DUPLICATES" | while read -r dup; do
      IP=$(echo "$dup" | cut -d':' -f1)
      SCOPE=$(echo "$dup" | cut -d':' -f2)
      log_error "  - $IP (scope: $SCOPE)"
    done
    exit 1
  fi
  
  log_success "No duplicates found in config.yaml"
}

# Auto-import unmanaged rules
auto_import_rules() {
  echo ""
  log_info "Auto-importing unmanaged rules..."
  
  # Get IPs from Terraform state
  if [ -f "terraform.tfstate" ]; then
    terraform state list 2>/dev/null | grep "cloudflare_access_rule.ip_rules" | \
      awk -F'["' '{print $2}' | sed 's/"]$//' > /tmp/tf-rules.txt
  else
    touch /tmp/tf-rules.txt
  fi
  
  # Backup config.yaml
  BACKUP_FILE="shared/config.yaml.backup.$(date +%Y%m%d_%H%M%S)"
  cp shared/config.yaml "$BACKUP_FILE"
  log_info "Backed up config.yaml to $BACKUP_FILE"
  
  # Use temp file for counter (avoid subshell issue)
  echo "0" > /tmp/import_count.txt
  
  # Process account-level rules
  echo ""
  log_info "Importing account-level rules..."
  jq -c '.result[]' /tmp/cf-account-rules.json 2>/dev/null | while read -r rule; do
    IP=$(echo "$rule" | jq -r '.configuration.value')
    MODE=$(echo "$rule" | jq -r '.mode')
    NOTES=$(echo "$rule" | jq -r '.notes // "No notes provided"')
    RULE_ID=$(echo "$rule" | jq -r '.id')
    
    RULE_KEY="account-${IP//\//-}"
    
    # Check if already in Terraform
    if ! grep -q "^${RULE_KEY}$" /tmp/tf-rules.txt; then
      log_info "Importing: $IP (ID: $RULE_ID)"
      
      # Add to config.yaml (preserve original notes)
      echo "  - ip: \"$IP\"" >> shared/config.yaml
      echo "    mode: \"$MODE\"" >> shared/config.yaml
      echo "    scope: \"account\"" >> shared/config.yaml
      echo "    notes: \"$NOTES\"" >> shared/config.yaml
      
      # Import into Terraform state
      terraform import "module.security.cloudflare_access_rule.ip_rules[\"${RULE_KEY}\"]" \
        "accounts/${ACCOUNT_ID}/${RULE_ID}" 2>/dev/null || log_warning "Import may have failed (rule might already exist)"
      
      # Increment counter
      COUNT=$(cat /tmp/import_count.txt)
      echo $((COUNT + 1)) > /tmp/import_count.txt
    fi
  done
  
  # Process zone-level rules
  echo ""
  log_info "Importing zone-level rules..."
  jq -c '.result[]' /tmp/cf-zone-rules.json 2>/dev/null | while read -r rule; do
    IP=$(echo "$rule" | jq -r '.configuration.value')
    MODE=$(echo "$rule" | jq -r '.mode')
    NOTES=$(echo "$rule" | jq -r '.notes // "No notes provided"')
    RULE_ID=$(echo "$rule" | jq -r '.id')
    
    RULE_KEY="zone-${IP//\//-}"
    
    # Check if already in Terraform
    if ! grep -q "^${RULE_KEY}$" /tmp/tf-rules.txt; then
      log_info "Importing: $IP (ID: $RULE_ID)"
      
      # Add to config.yaml (preserve original notes)
      echo "  - ip: \"$IP\"" >> shared/config.yaml
      echo "    mode: \"$MODE\"" >> shared/config.yaml
      echo "    scope: \"zone\"" >> shared/config.yaml
      echo "    notes: \"$NOTES\"" >> shared/config.yaml
      
      # Import into Terraform state
      terraform import "module.security.cloudflare_access_rule.ip_rules[\"${RULE_KEY}\"]" \
        "zones/${ZONE_ID}/${RULE_ID}" 2>/dev/null || log_warning "Import may have failed (rule might already exist)"
      
      # Increment counter
      COUNT=$(cat /tmp/import_count.txt)
      echo $((COUNT + 1)) > /tmp/import_count.txt
    fi
  done
  
  # Read final count
  IMPORTED_COUNT=$(cat /tmp/import_count.txt)
  rm -f /tmp/import_count.txt
  
  echo ""
  log_success "Auto-import complete"
  log_info "Imported: $IMPORTED_COUNT rules"
  log_info "Config updated: shared/config.yaml"
  
  if [ "$IMPORTED_COUNT" -gt 0 ]; then
    log_warning "Review the imported rules in shared/config.yaml"
    log_info "These rules were manually added in Cloudflare and have been auto-imported"
  fi
}

# Main execution
case "$MODE" in
  --check-only)
    fetch_cloudflare_rules
    get_terraform_state
    check_config
    detect_count_drift
    detect_content_drift
    
    echo ""
    log_info "========================================"
    if [ "$DRIFT_DETECTED" -eq 1 ]; then
      log_error "Drift detected"
      log_info "  Count drift:   $([ $COUNT_DRIFT -eq 1 ] && echo 'Yes' || echo 'No')"
      log_info "  Content drift: $([ $CONTENT_DRIFT -eq 1 ] && echo 'Yes' || echo 'No')"
      exit 1
    else
      log_success "No drift detected"
      log_info "Terraform state matches Cloudflare"
      exit 0
    fi
    ;;
    
  --import)
    fetch_cloudflare_rules
    get_terraform_state
    check_config
    check_duplicates
    detect_count_drift
    detect_content_drift
    
    if [ "$DRIFT_DETECTED" -eq 1 ]; then
      if [ "$COUNT_DRIFT" -eq 1 ]; then
        auto_import_rules
      else
        log_warning "Only content drift detected (no auto-import needed)"
        log_info "Run 'terraform plan' to see what will be updated"
      fi
    else
      log_success "No drift detected - nothing to import"
    fi
    
    exit 0
    ;;
    
  *)
    log_error "Invalid mode: $MODE"
    echo ""
    echo "Usage: $0 [--check-only|--import]"
    echo ""
    echo "Modes:"
    echo "  --check-only  Detect drift and report (exit 1 if drift found)"
    echo "  --import      Detect drift and auto-import unmanaged rules (default)"
    exit 1
    ;;
esac
