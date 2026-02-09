#!/bin/bash
# Test mode validation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "🧪 Testing Mode Validation"
echo "=========================="

cd "$PROJECT_ROOT"

PASSED=0
FAILED=0

# Test 1: Valid mode "block" should pass
echo -n "Test 1: Valid mode (block)... "
cat > shared/config.yaml << EOF
ip_access_rules:
  - ip: "10.10.10.10"
    mode: "block"
    scope: "account"
    notes: "Test"
EOF

if terraform plan -detailed-exitcode > /dev/null 2>&1 || [ $? -eq 2 ]; then
  echo "✅ PASS"
  PASSED=$((PASSED + 1))
else
  echo "❌ FAIL"
  FAILED=$((FAILED + 1))
fi

# Test 2: Valid mode "challenge" should pass
echo -n "Test 2: Valid mode (challenge)... "
cat > shared/config.yaml << EOF
ip_access_rules:
  - ip: "10.10.10.10"
    mode: "challenge"
    scope: "account"
    notes: "Test"
EOF

if terraform plan -detailed-exitcode > /dev/null 2>&1 || [ $? -eq 2 ]; then
  echo "✅ PASS"
  PASSED=$((PASSED + 1))
else
  echo "❌ FAIL"
  FAILED=$((FAILED + 1))
fi

# Test 3: Invalid mode "bloke" should fail
echo -n "Test 3: Invalid mode (bloke)... "
cat > shared/config.yaml << EOF
ip_access_rules:
  - ip: "10.10.10.10"
    mode: "bloke"
    scope: "account"
    notes: "Test"
EOF

if terraform plan > /dev/null 2>&1; then
  echo "❌ FAIL (should have rejected)"
  FAILED=$((FAILED + 1))
else
  echo "✅ PASS (correctly rejected)"
  PASSED=$((PASSED + 1))
fi

# Test 4: Invalid mode "allow" should fail
echo -n "Test 4: Invalid mode (allow)... "
cat > shared/config.yaml << EOF
ip_access_rules:
  - ip: "10.10.10.10"
    mode: "allow"
    scope: "account"
    notes: "Test"
EOF

if terraform plan > /dev/null 2>&1; then
  echo "❌ FAIL (should have rejected)"
  FAILED=$((FAILED + 1))
else
  echo "✅ PASS (correctly rejected)"
  PASSED=$((PASSED + 1))
fi

# Restore original config
git checkout shared/config.yaml 2>/dev/null || true

echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [ $FAILED -gt 0 ]; then
  exit 1
fi

exit 0
