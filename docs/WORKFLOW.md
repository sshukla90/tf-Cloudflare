# Production Workflow with Auto-Import

This document explains the workflow for managing Cloudflare IP access rules with automatic drift handling.

## 🎯 The Flow

```
┌─────────────┐
│ 1. User     │ Clone repo, create branch, add rule to config.yaml
│   Clone     │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ 2. Create   │ Push branch, create Pull Request
│   PR        │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ 3. CI/CD    │ ✅ Drift Check
│   Checks    │ ✅ Auto-Import (if drift found)
│             │ ✅ Terraform Plan
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ 4. Platform │ Review PR + auto-imported rules
│   Team      │ Approve if looks good
│   Review    │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ 5. Merge    │ Merge PR to main branch
│   to Main   │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ 6. Auto     │ ✅ Terraform Apply (automatic)
│   Deploy    │ ✅ Changes pushed to Cloudflare Production
└─────────────┘
```

## 📋 Step-by-Step

### For Users (Adding Rules)

1. **Clone and branch**:
   ```bash
   git clone https://github.com/sshukla90/tf-Cloudflare.git
   cd tf-Cloudflare
   git checkout -b block-ip-1.1.1.1
   ```

2. **Add rule** to `shared/config.yaml`:
   ```yaml
   ip_access_rules:
     # ... existing rules ...
     
     - ip: "1.1.1.1"
       mode: "block"
       scope: "account"
       notes: "Added by John Doe on 2026-02-09 - DDoS attack - Ticket: SEC-1234"
   ```

3. **Create PR**:
   ```bash
   git add shared/config.yaml
   git commit -m "Block 1.1.1.1 - DDoS attack (SEC-1234)"
   git push origin block-ip-1.1.1.1
   # Create PR in GitHub
   ```

4. **Wait for CI/CD** - Automatically:
   - ✅ Checks for drift
   - ✅ **Auto-imports** any manual rules (if found)
   - ✅ Runs `terraform plan`
   - ✅ Posts results as PR comment

5. **Wait for approval** from Platform Team

6. **Done!** After merge, changes automatically apply to Cloudflare

### For Platform Team (Reviewers)

1. **Review PR**:
   - Check the IP is correct
   - Verify the reason and ticket number
   - **Check for auto-imported rules** (if any)
   - Review the `terraform plan` output

2. **If drift was auto-imported**:
   - CI will post a comment: "✅ Drift Auto-Imported!"
   - Review the auto-imported rules in `config.yaml`
   - Verify they should be kept
   - **Important**: Educate the person who added manual rules

3. **Approve**:
   - Click "Approve" in GitHub
   - Optionally add comments

4. **Merge**:
   - Click "Merge pull request"
   - CI automatically applies to Cloudflare

## 🔄 Auto-Import Process

### What Happens When Drift is Detected

**Scenario**: Someone manually added a rule `2.2.2.2` in Cloudflare dashboard

**On PR creation**:
1. CI detects drift (Cloudflare has more rules than Terraform)
2. **Auto-import script runs**:
   - Fetches the unmanaged rule from Cloudflare
   - Adds it to `shared/config.yaml`
   - Imports it into Terraform state
   - Commits changes back to the PR
3. CI posts comment: "✅ Drift Auto-Imported!"
4. Platform Team reviews the auto-imported rules
5. If approved, merge proceeds normally

**Result**: No manual intervention needed from users!

## 🔍 CI/CD Checks (Automatic)

### On Pull Request

**1. Drift Detection**:
- Compares Cloudflare vs Terraform state
- If drift found → Auto-import

**2. Auto-Import** (if needed):
- Fetches unmanaged rules from Cloudflare
- Adds to `config.yaml`
- Imports into Terraform state
- Commits to PR branch
- Posts comment for Platform Team review

**3. Terraform Plan**:
- Shows what will change
- Posts plan as PR comment
- Validates configuration

### On Merge to Main

**Terraform Apply** (automatic):
- Applies changes to Cloudflare Production
- No manual intervention needed

## ⚠️ What Happens if Someone Adds Manual Rules?

**Example**: Security team member adds `2.2.2.2` manually in Cloudflare

**Next PR (any PR)**:
```
✅ Drift Auto-Imported!

Manual changes were detected in Cloudflare and have been automatically imported.

What happened:
- Found unmanaged rule: 2.2.2.2
- Auto-imported into shared/config.yaml
- Imported into Terraform state

Action Required (Platform Team):
1. Review the auto-imported rules
2. Verify the rules are correct
3. Approve this PR if everything looks good

Note: These rules were manually added in Cloudflare. Going forward, all changes should be made via this repo.
```

**Platform Team**:
- Reviews the auto-imported rule
- Verifies it's legitimate
- Approves the PR
- **Educates** the person who added it manually

## ✅ Success Flow Example

**User creates PR**:
```
PR #123: Block 1.1.1.1 - DDoS attack
```

**CI/CD runs**:
```
✅ Drift Check: Passed (no manual changes)
✅ Terraform Plan: Passed
   Plan: 1 to add, 0 to change, 0 to destroy
```

**Platform Team reviews**:
```
✅ IP looks correct
✅ Ticket number provided
✅ Plan output looks good
→ Approved
```

**Merge to main**:
```
✅ PR merged
✅ Terraform Apply: Running...
✅ Terraform Apply: Success!
   1 rule added to Cloudflare
```

## 🔐 Security & Permissions

- **Users**: Only need Git access (no Cloudflare access)
- **CI/CD**: Has Cloudflare API token (in GitHub Secrets)
- **Platform Team**: Reviews all changes before apply
- **Audit trail**: Git history shows all changes

## 📊 Benefits

1. **No Cloudflare access needed** - Users only need Git
2. **Auto-import drift** - Manual rules automatically imported
3. **Platform Team control** - Reviews all changes
4. **Audit trail** - Git history
5. **Safe** - Plan shown before apply
6. **Fast** - Automatic deployment after merge

## 🎓 Training Users

Share this checklist:

```
✅ Clone repo
✅ Create branch
✅ Add rule to config.yaml
✅ Create PR
✅ Wait for CI checks (green ✅)
✅ Wait for Platform Team approval
✅ Merge
✅ Done! (automatic apply)

❌ Never make manual changes in Cloudflare
❌ If urgent, manual changes will be auto-imported on next PR
```

## 🔧 Setup (One-Time)

1. **GitHub Secrets**: Add `CLOUDFLARE_API_TOKEN`
2. **Branch Protection**: 
   - Require pull request reviews
   - Require status checks to pass
3. **Permissions**: 
   - Users: Git access only
   - CI/CD: Cloudflare API token
   - Platform Team: PR approval rights

## 🚨 Role of init.sh

**`init.sh` is for FIRST-TIME setup only**:
- Run once when setting up the repo
- Imports ALL existing Cloudflare rules
- Creates initial `config.yaml`
- Sets up Terraform state

**After initial setup**:
- Don't run `init.sh` again
- Use the auto-import in CI/CD instead
- Auto-import handles ongoing drift

That's it! Simple, safe, and automated. 🎉
