# Automated Testing Guide

## 🧪 How GitHub Actions Runs Tests Automatically

### Overview
Every time you create a PR, GitHub Actions automatically runs tests to validate your changes **before** any human review.

---

## 📁 Test Structure

```
tests/
├── run_tests.sh              # Main test runner
├── unit/
│   ├── test_ip_validation.sh       # Tests IP format validation
│   ├── test_mode_validation.sh     # Tests mode validation
│   └── test_duplicate_detection.sh # Tests duplicate detection
└── fixtures/
    └── (test data files)
```

---

## 🔄 How It Works

### 1. You Push Code
```bash
git push origin my-feature-branch
```

### 2. GitHub Actions Triggers
GitHub automatically runs `.github/workflows/terraform.yml`

### 3. Tests Run Automatically
```yaml
- name: Run Automated Tests
  run: ./tests/run_tests.sh
```

### 4. You See Results
**On PR page**:
- ✅ **Tests Passed** - Green checkmark
- ❌ **Tests Failed** - Red X with error details

---

## 🧪 What Gets Tested

### Test 1: IP Validation (`test_ip_validation.sh`)
**Tests**:
- ✅ Valid IP (10.10.10.10) → Should PASS
- ❌ Invalid IP (999.999.999.999) → Should FAIL
- ✅ Valid CIDR (10.0.0.0/24) → Should PASS
- ❌ Invalid CIDR (10.0.0.0/99) → Should FAIL

**Example Output**:
```
🧪 Testing IP Validation
========================
Test 1: Valid IP (10.10.10.10)... ✅ PASS
Test 2: Invalid IP (999.999.999.999)... ✅ PASS (correctly rejected)
Test 3: Valid CIDR (10.0.0.0/24)... ✅ PASS
Test 4: Invalid CIDR (10.0.0.0/99)... ✅ PASS (correctly rejected)

Results: 4 passed, 0 failed
```

---

### Test 2: Mode Validation (`test_mode_validation.sh`)
**Tests**:
- ✅ Valid mode "block" → Should PASS
- ✅ Valid mode "challenge" → Should PASS
- ❌ Invalid mode "bloke" → Should FAIL
- ❌ Invalid mode "allow" → Should FAIL

**Example Output**:
```
🧪 Testing Mode Validation
==========================
Test 1: Valid mode (block)... ✅ PASS
Test 2: Valid mode (challenge)... ✅ PASS
Test 3: Invalid mode (bloke)... ✅ PASS (correctly rejected)
Test 4: Invalid mode (allow)... ✅ PASS (correctly rejected)

Results: 4 passed, 0 failed
```

---

### Test 3: Duplicate Detection (`test_duplicate_detection.sh`)
**Tests**:
- ✅ No duplicates → Should PASS
- ❌ Duplicate IP+scope → Should FAIL
- ✅ Same IP different scope → Should PASS

**Example Output**:
```
🧪 Testing Duplicate Detection
==============================
Test 1: No duplicates... ✅ PASS
Test 2: Duplicate IP+scope... ✅ PASS (correctly detected)
Test 3: Same IP different scope... ✅ PASS

Results: 3 passed, 0 failed
```

---

## 📊 GitHub Actions Workflow

### Complete Test Flow
```yaml
name: Terraform CI/CD

on:
  pull_request:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
      
      - name: Terraform Init
        run: terraform init
      
      # 🧪 AUTOMATED TESTS RUN HERE
      - name: Run Automated Tests
        run: ./tests/run_tests.sh
      
      - name: Drift Detection
        run: ./scripts/drift-handler.sh --check-only
      
      - name: Terraform Plan
        run: terraform plan
```

---

## 👀 What You See on PR

### When Tests Pass ✅
```
✅ Run Automated Tests — Passed in 45s
✅ Drift Detection — Passed in 2m 15s
✅ Terraform Plan — Passed in 1m 30s
```

**PR Status**: Ready for review

---

### When Tests Fail ❌
```
❌ Run Automated Tests — Failed in 12s
⏸️ Drift Detection — Skipped
⏸️ Terraform Plan — Skipped
```

**Click on failed test to see**:
```
🧪 Testing IP Validation
========================
Test 1: Valid IP (10.10.10.10)... ✅ PASS
Test 2: Invalid IP (999.999.999.999)... ❌ FAIL (should have rejected)

Results: 1 passed, 1 failed
Error: Process completed with exit code 1.
```

**PR Status**: ❌ Blocked, cannot merge

---

## 🔧 Running Tests Locally

### Run All Tests
```bash
cd /home/expert/cf-internal
./tests/run_tests.sh
```

### Run Single Test
```bash
./tests/unit/test_ip_validation.sh
```

### Run Specific Test
```bash
cd /home/expert/cf-internal
bash tests/unit/test_mode_validation.sh
```

---

## ✍️ Writing New Tests

### Example: Add Test for Notes Validation
```bash
#!/bin/bash
# tests/unit/test_notes_validation.sh

echo "🧪 Testing Notes Validation"

# Test 1: Empty notes should fail
cat > shared/config.yaml << EOF
ip_access_rules:
  - ip: "10.10.10.10"
    mode: "block"
    scope: "account"
    notes: ""
EOF

if terraform plan > /dev/null 2>&1; then
  echo "❌ FAIL (should reject empty notes)"
  exit 1
else
  echo "✅ PASS (correctly rejected)"
fi

# Restore config
git checkout shared/config.yaml
exit 0
```

**Make it executable**:
```bash
chmod +x tests/unit/test_notes_validation.sh
```

**It will run automatically** on next PR!

---

## 📧 Notifications

### Email Notifications
**When tests fail**, you get:
```
Subject: [GitHub] Check failed on PR #123

Your PR "Add new IP rule" has failing checks:
❌ Run Automated Tests

Click here to view details: [Link to PR]
```

### PR Comments
**Bot posts**:
```
## ❌ Tests Failed

The automated tests have detected issues:

**Failed Test**: IP Validation
**Error**: Invalid IP format for '999.999.999.999'

Please fix and push again.
```

---

## 🎯 Benefits of Automated Testing

### For Users
- ✅ **Instant feedback** - Know immediately if changes are valid
- ✅ **No waiting** - Don't need Platform Team to spot basic errors
- ✅ **Learn faster** - See what's wrong and fix it

### For Platform Team
- ✅ **Less review time** - Only review PRs that pass tests
- ✅ **Catch bugs early** - Before manual review
- ✅ **Consistent validation** - Same checks every time

### For Everyone
- ✅ **Prevent regressions** - Tests catch when something breaks
- ✅ **Documentation** - Tests show how things should work
- ✅ **Confidence** - Know changes won't break production

---

## 📈 Test Coverage

**Current Coverage**:
- ✅ IP format validation
- ✅ Mode validation
- ✅ Duplicate detection
- ⚠️ Notes validation (manual)
- ⚠️ Scope validation (manual)

**Future Tests** (nice to have):
- Integration tests with Cloudflare API
- Performance tests (large config files)
- Security tests (injection attempts)

---

## 🚀 Next Steps

### Already Working
1. Tests run automatically on every PR ✅
2. PR blocked if tests fail ✅
3. Email notifications sent ✅

### To Enable (Optional)
4. Add more test scenarios
5. Add integration tests
6. Add performance tests

---

## 💡 Pro Tips

1. **Run tests locally** before pushing
   ```bash
   ./tests/run_tests.sh
   ```

2. **Check test logs** in GitHub Actions for details

3. **Tests are fast** - Usually complete in < 1 minute

4. **Tests are free** - GitHub Actions free tier is generous

5. **Add tests for bugs** - When you find a bug, add a test for it

---

## 🎓 Summary

**How it works**:
1. You push code → GitHub Actions runs tests automatically
2. Tests validate IP, mode, duplicates
3. You see results on PR page (✅ or ❌)
4. If ❌, fix and push again
5. If ✅, Platform Team reviews

**No manual work needed** - Tests run automatically every time!
