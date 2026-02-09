# Cloudflare IP Access Rules Management

Terraform setup for managing Cloudflare IP access rules.

## 🎯 How It Works

1. **config.yaml** contains all Cloudflare IP access rules
2. **Users** clone repo, add rules to config.yaml
3. **Run** `terraform plan` and `terraform apply` to push to Cloudflare

## 🚀 Quick Start

### First-Time Setup (Import Existing Rules)

If you have existing IP access rules in Cloudflare:

```bash
# 1. Clone repo
git clone https://github.com/sshukla90/tf-Cloudflare.git
cd tf-Cloudflare

# 2. Configure API token
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars and add your API token

# 3. Run initial import script
./scripts/init.sh
```

The `init.sh` script will:
- ✅ Fetch all existing rules from Cloudflare
- ✅ Generate `shared/config.yaml` with all rules
- ✅ Initialize Terraform
- ✅ Import rules into Terraform state
- ✅ Verify everything is in sync

### Adding New Rules (After Initial Setup)

```bash
# 1. Edit shared/config.yaml - ADD your rule to the list
ip_access_rules:
  # ... existing rules ...
  
  # Your new rule
  - ip: "1.1.1.1"
    mode: "block"
    scope: "account"
    notes: "Added by John Doe on 2026-02-09 - DDoS attack - Ticket: SEC-1234"

# 2. Plan changes
terraform plan

# 3. Apply changes
terraform apply

# 4. Commit and push
git add shared/config.yaml
git commit -m "Block 1.1.1.1 - DDoS attack (SEC-1234)"
git push
```

## 📋 Configuration Fields

```yaml
- ip: "X.X.X.X"              # Required: IP address or CIDR (e.g., "1.1.1.1" or "10.0.0.0/24")
  mode: "block"              # Required: block, challenge, whitelist, js_challenge, managed_challenge
  scope: "account"           # Optional: "account" (default) or "zone"
  notes: "Description"       # Required: Who, when, why (include ticket number)
```

## 🔧 Architecture

```
cf-internal/
├── main.tf                  # Calls security module
├── provider.tf              # Cloudflare provider v5
├── variables.tf             # Global variables
├── terraform.tfvars         # API token, Account/Zone IDs (gitignored)
├── terraform.tfvars.example # Template for tfvars
├── output.tf                # Outputs
├── shared/
│   └── config.yaml          # IP access rules (source of truth)
└── security/                # Terraform module
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

## 🔐 Configuration

### terraform.tfvars

```hcl
cloudflare_api_token  = "your-api-token-here"
cloudflare_account_id = "a646a5b04f5bd1a4cdcaaf82711d8de1"
cloudflare_zone_id    = "52d3466c4c4cbbf14ffee4f0f779a931"
config_file_path      = "./shared/config.yaml"
```

**Note**: `terraform.tfvars` is gitignored for security. Use `terraform.tfvars.example` as a template.

## 📚 Documentation

- **Initial Setup Script**: [scripts/init.sh](scripts/init.sh) - Automated first-time import
- **Initial Import Guide**: [docs/INITIAL-IMPORT.md](docs/INITIAL-IMPORT.md) - Manual import process
- **Testing Guide**: [docs/TESTING.md](docs/TESTING.md) - Manual testing workflow
- **Security Module**: [security/README.md](security/README.md) - Module documentation

## ✅ Best Practices

1. **Always include ticket number** in notes
2. **Be specific** about why the rule is needed
3. **Check for duplicates** before adding
4. **Run terraform plan** before apply

## 🚨 Important

- ✅ **config.yaml** is the source of truth
- ✅ **Always run** `terraform plan` before `apply`
- ✅ **After initial import**, all rules must be added via Terraform
- ✅ **Never** make manual changes in Cloudflare dashboard

## 📞 Support

Questions? Ask in `#platform-team` Slack channel.

## 🚀 Quick Start for Users

### Adding a New IP Rule

```bash
# 1. Clone and create branch
git clone <repo-url>
cd cf-internal
git checkout -b block-ip-1.1.1.1

# 2. Edit shared/config.yaml - ADD your rule to the list
# Don't replace the file! Just add to existing rules:

ip_access_rules:
  # ... existing rules ...
  
  # Your new rule
  - ip: "1.1.1.1"
    mode: "block"
    scope: "account"
    notes: "Added by John Doe on 2026-02-09 - DDoS attack - Ticket: SEC-1234"

# 3. Commit and create PR
git add shared/config.yaml
git commit -m "Block 1.1.1.1 - DDoS attack (SEC-1234)"
git push origin block-ip-1.1.1.1

# 4. Create PR in GitHub
# 5. Wait for approval
# 6. Done! CI applies automatically after merge
```

## 📋 Configuration Fields

```yaml
- ip: "X.X.X.X"              # Required: IP address or CIDR (e.g., "1.1.1.1" or "10.0.0.0/24")
  mode: "block"              # Required: block, challenge, whitelist, js_challenge, managed_challenge
  scope: "account"           # Optional: "account" (default) or "zone"
  notes: "Description"       # Required: Who, when, why (include ticket number)
```

## 👥 For Approvers (Platform Team)

1. Review PR
2. Check `terraform plan` output (posted by CI as comment)
3. Approve or request changes
4. Merge → CI automatically applies to Cloudflare

## 🔧 Architecture

```
cf-internal/
├── main.tf                  # Calls security module
├── provider.tf              # Cloudflare provider v5
├── variables.tf             # Global variables
├── terraform.tfvars         # Account/Zone IDs, API token
├── output.tf                # Outputs
├── shared/
│   └── config.yaml          # IP access rules (source of truth)
├── security/                # Terraform module
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
└── .github/
    └── workflows/
        └── terraform.yml    # CI/CD automation
```

## 🔐 Setup (One-Time)

### 1. Add GitHub Secret

GitHub → Settings → Secrets → Actions:
- Name: `CLOUDFLARE_API_TOKEN`
- Value: `xW0b_hrxy-otoWEmFiQST1RT_Ak9hqCJLbVqzi8U`

### 2. Enable Branch Protection

GitHub → Settings → Branches → Add rule for `main`:
- ✅ Require pull request reviews (1+ approvers)
- ✅ Require status checks to pass (Terraform Plan)
- ✅ Restrict push to Platform Team only

### 3. Initial Import (One-Time)

If you have existing rules in Cloudflare, import them once:

```bash
# This is done ONCE by Platform Team to populate config.yaml
# After this, all rules must be added via Terraform only

# See docs/INITIAL-IMPORT.md for instructions
```

## 📚 Documentation

- **Initial Import Guide**: [docs/INITIAL-IMPORT.md](docs/INITIAL-IMPORT.md)
- **PR Workflow Details**: [docs/PR-WORKFLOW.md](docs/PR-WORKFLOW.md)
- **Security Module**: [security/README.md](security/README.md)

## ✅ Best Practices

1. **Always include ticket number** in notes
2. **Be specific** about why the rule is needed
3. **Use descriptive branch names**: `block-ip-1.1.1.1`
4. **One rule per PR** (easier to review)
5. **Check for duplicates** before adding

## 🚨 Important Rules

- ✅ **Master branch** is the source of truth
- ✅ **All changes** go through PR
- ✅ **Only CI/CD** applies to Cloudflare
- ✅ **Never** run `terraform apply` locally
- ✅ **After initial import**, all rules must be added via Terraform

## 📞 Support

Questions? Ask in `#platform-team` Slack channel.
