# Simple Production Workflow

This document explains the streamlined workflow for managing Cloudflare IP access rules.

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
│ 3. CI/CD    │ ✅ Drift Check (blocks if manual changes found)
│   Checks    │ ✅ Terraform Plan (shows what will change)
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ 4. Platform │ Review PR, check plan output
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

4. **Wait for checks** - CI/CD will automatically:
   - ✅ Check for drift (fails if manual changes exist)
   - ✅ Run `terraform plan`
   - ✅ Post plan output as PR comment

5. **Wait for approval** from Platform Team

6. **Done!** After merge, changes automatically apply to Cloudflare

### For Platform Team (Reviewers)

1. **Review PR**:
   - Check the IP is correct
   - Verify the reason and ticket number
   - Review the `terraform plan` output (posted by CI)

2. **Check for drift**:
   - CI automatically checks
   - PR will be blocked if drift detected
   - User must fix drift before merge

3. **Approve**:
   - Click "Approve" in GitHub
   - Optionally add comments

4. **Merge**:
   - Click "Merge pull request"
   - CI automatically applies to Cloudflare

## 🔍 CI/CD Checks (Automatic)

### On Pull Request

**Drift Check** (runs first):
- Compares Cloudflare vs Terraform state
- **Blocks PR if drift detected**
- Posts comment with details

**Terraform Plan** (runs after drift check passes):
- Shows what will change
- Posts plan as PR comment
- Validates configuration

### On Merge to Main

**Terraform Apply** (automatic):
- Applies changes to Cloudflare Production
- No manual intervention needed
- Runs only after PR is merged

## ⚠️ What Happens if Drift is Detected?

**Scenario**: Someone manually added a rule in Cloudflare

**On PR**:
```
❌ Drift Check Failed

⚠️ Drift Detected!

Manual changes were found in Cloudflare that are not managed by Terraform.

Action Required:
1. Run ./scripts/detect-drift.sh locally to see details
2. Import the unmanaged rules or delete them from Cloudflare
3. Update this PR with the changes

This PR cannot be merged until drift is resolved.
```

**User must**:
1. Run `./scripts/detect-drift.sh` locally
2. Import the manual rule OR delete it from Cloudflare
3. Update the PR
4. CI will re-run checks

## 🚫 Blocked Scenarios

**PR is blocked if**:
- ❌ Drift detected (manual changes in Cloudflare)
- ❌ Terraform plan fails (invalid configuration)
- ❌ Validation fails (invalid IP, mode, etc.)

**User must fix the issue before merge is allowed.**

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

## 🔐 Security

- API token stored in GitHub Secrets
- Only CI/CD can apply to production
- All changes reviewed before apply
- Audit trail via Git history

## 📊 Benefits

1. **No manual applies** - Everything automated
2. **Drift prevention** - Blocks PRs if manual changes exist
3. **Code review** - Platform team approves all changes
4. **Audit trail** - Git history shows who changed what
5. **Safe** - Plan runs before apply, reviewers see changes
6. **Fast** - Automatic apply after merge

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

❌ Never run terraform apply locally
❌ Never make manual changes in Cloudflare
```

## 🔧 Setup (One-Time)

1. **GitHub Secrets**: Add `CLOUDFLARE_API_TOKEN`
2. **Branch Protection**: Require PR reviews + status checks
3. **Team Training**: Educate on the workflow

That's it! Simple and safe. 🎉
