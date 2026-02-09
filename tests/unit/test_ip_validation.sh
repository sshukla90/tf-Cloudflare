#!/bin/bash
# Test IP validation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "🧪 Testing IP Validation"
echo "========================"

cd "$PROJECT_ROOT"

PASSED=0
FAILED=0

# Test 1: Valid IP should pass
echo -n "Test 1: Valid IP (10.10.10.10)... "
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

# Test 2: Invalid IP should fail
echo -n "Test 2: Invalid IP (999.999.999.999)... "
cat > shared/config.yaml << EOF
ip_access_rules:
  - ip: "999.999.999.999"
    mode: "block"
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

# Test 3: Valid CIDR should pass
echo -n "Test 3: Valid CIDR (10.0.0.0/24)... "
cat > shared/config.yaml << EOF
ip_access_rules:
  - ip: "10.0.0.0/24"
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

# Test 4: Invalid CIDR should fail
echo -n "Test 4: Invalid CIDR (10.0.0.0/99)... "
cat > shared/config.yaml << EOF
ip_access_rules:
  - ip: "10.0.0.0/99"
    mode: "block"
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
