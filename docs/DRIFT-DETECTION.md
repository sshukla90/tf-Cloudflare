# Drift Detection & Prevention

This document explains how to detect and prevent manual changes (drift) in Cloudflare.

## 🚨 What is Drift?

**Drift** occurs when someone makes manual changes in the Cloudflare dashboard that are not managed by Terraform.

**Example**:
- Terraform manages 5 IP rules
- Someone manually adds 1 rule via Cloudflare dashboard
- Cloudflare now has 6 rules, but Terraform only knows about 5
- **Drift detected!** ⚠️

## 🔍 Drift Detection Script

### Manual Detection

Run the drift detection script anytime:

```bash
./scripts/detect-drift.sh
```

**Output if drift detected**:
```
⚠️  DRIFT DETECTED: Cloudflare has MORE rules than Terraform state
   Cloudflare: 6 rules
   Terraform:  5 rules
   Difference: 1 unmanaged rules

📌 Rules in Cloudflare NOT managed by Terraform:

  ⚠️  2.2.2.2 (account-level)
      Mode: block
      Notes: Manually added for testing
      Rule ID: abc123...

      To import into Terraform:
      terraform import 'module.security.cloudflare_access_rule.ip_rules["account-2.2.2.2"]' 'accounts/.../abc123...'
```

### Automated Detection (CI/CD)

The drift detection runs automatically:

1. **Daily at 9 AM UTC** (scheduled)
2. **On every Pull Request** that changes `config.yaml` or `*.tf` files
3. **Manual trigger** via GitHub Actions

## 🔧 How It Works

The script compares three sources:

1. **Cloudflare API** - Actual rules in Cloudflare
2. **Terraform State** - Rules Terraform knows about
3. **config.yaml** - Rules defined in code

If these don't match → **Drift detected!**

## 🛠️ Fixing Drift

### Option 1: Import the Manual Rule

If the manual rule should be kept:

```bash
# 1. Add to config.yaml
echo '  - ip: "2.2.2.2"
    mode: "block"
    scope: "account"
    notes: "Imported manual rule - now managed by Terraform"' >> shared/config.yaml

# 2. Import into Terraform state
terraform import 'module.security.cloudflare_access_rule.ip_rules["account-2.2.2.2"]' \
  'accounts/a646a5b04f5bd1a4cdcaaf82711d8de1/<RULE_ID>'

# 3. Verify
terraform plan  # Should show no changes

# 4. Commit
git add shared/config.yaml
git commit -m "Import manual rule 2.2.2.2"
git push
```

### Option 2: Delete the Manual Rule

If the manual rule was a mistake:

```bash
# 1. Delete from Cloudflare dashboard
# 2. Verify
./scripts/detect-drift.sh  # Should show no drift
```

## 🚀 CI/CD Integration

### GitHub Actions

The workflow is already set up in `.github/workflows/drift-detection.yml`.

**Features**:
- ✅ Runs daily at 9 AM UTC
- ✅ Runs on every PR
- ✅ Comments on PR if drift detected
- ✅ Can be manually triggered

### Azure DevOps

For Azure DevOps, create a pipeline:

```yaml
# azure-pipelines.yml

trigger:
  branches:
    include:
      - main
  paths:
    include:
      - shared/config.yaml
      - '**/*.tf'

schedules:
  - cron: "0 9 * * *"
    displayName: Daily drift detection
    branches:
      include:
        - main

pool:
  vmImage: 'ubuntu-latest'

steps:
  - task: TerraformInstaller@0
    inputs:
      terraformVersion: '1.14.0'

  - script: |
      sudo apt-get update && sudo apt-get install -y jq
    displayName: 'Install dependencies'

  - script: |
      terraform init
    displayName: 'Terraform Init'
    env:
      TF_VAR_cloudflare_api_token: $(CLOUDFLARE_API_TOKEN)

  - script: |
      chmod +x scripts/detect-drift.sh
      ./scripts/detect-drift.sh
    displayName: 'Detect Drift'
    env:
      TF_VAR_cloudflare_api_token: $(CLOUDFLARE_API_TOKEN)
    continueOnError: false

  - task: PublishTestResults@2
    condition: always()
    inputs:
      testResultsFormat: 'JUnit'
      testResultsFiles: '**/drift-results.xml'
```

**Setup**:
1. Add `CLOUDFLARE_API_TOKEN` as a secret variable in Azure DevOps
2. Create the pipeline from `azure-pipelines.yml`
3. Enable scheduled runs

## 🔔 Notifications

### Slack Notification

Add to the drift detection script or CI/CD:

```bash
# In drift-detection.yml or detect-drift.sh
if [ "$DRIFT_DETECTED" -eq 1 ]; then
  curl -X POST -H 'Content-type: application/json' \
    --data '{"text":"⚠️ Cloudflare Drift Detected! Check GitHub Actions for details."}' \
    $SLACK_WEBHOOK_URL
fi
```

### Email Notification

Configure in your CI/CD platform to send emails on failure.

## 📋 Best Practices

1. **Run drift detection before every deployment**
2. **Set up daily scheduled checks**
3. **Block PRs if drift is detected**
4. **Educate team**: All changes must go through Terraform
5. **Use Cloudflare audit logs** to track who made manual changes

## 🚫 Preventing Drift

### 1. Restrict Cloudflare Access

- Limit who can make changes in Cloudflare dashboard
- Use API tokens with minimal permissions
- Enable audit logging

### 2. Use Remote State

- Terraform Cloud or S3 backend
- Prevents state file loss
- Enables state locking

### 3. Enforce via CI/CD

- All changes via PR
- Drift detection on every PR
- Block merge if drift detected

### 4. Documentation

- Document the process clearly
- Train team members
- Add warnings in Cloudflare dashboard (if possible)

## 🎯 Summary

**Drift Detection Script**: `./scripts/detect-drift.sh`
- Compares Cloudflare vs Terraform state
- Shows unmanaged rules
- Provides import commands

**Automated Detection**: GitHub Actions / Azure DevOps
- Runs daily
- Runs on PRs
- Sends notifications

**Prevention**: Process + Automation
- All changes via Terraform
- Drift detection in CI/CD
- Team training
