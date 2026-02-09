#!/bin/bash
# Test duplicate detection

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "🧪 Testing Duplicate Detection"
echo "=============================="

cd "$PROJECT_ROOT"

PASSED=0
FAILED=0

# Test 1: No duplicates should pass
echo -n "Test 1: No duplicates... "
cat > shared/config.yaml << EOF
ip_access_rules:
  - ip: "10.10.10.10"
    mode: "block"
    scope: "account"
    notes: "Test 1"
  - ip: "20.20.20.20"
    mode: "block"
    scope: "account"
    notes: "Test 2"
EOF

if ./scripts/drift-handler.sh --check-only > /dev/null 2>&1; then
  echo "✅ PASS"
  PASSED=$((PASSED + 1))
else
  # Check if it's just drift (acceptable)
  if ./scripts/drift-handler.sh --check-only 2>&1 | grep -q "No duplicates found"; then
    echo "✅ PASS"
    PASSED=$((PASSED + 1))
  else
    echo "❌ FAIL"
    FAILED=$((FAILED + 1))
  fi
fi

# Test 2: Duplicate IP+scope should fail
echo -n "Test 2: Duplicate IP+scope... "
cat > shared/config.yaml << EOF
ip_access_rules:
  - ip: "10.10.10.10"
    mode: "block"
    scope: "account"
    notes: "Test 1"
  - ip: "10.10.10.10"
    mode: "block"
    scope: "account"
    notes: "Test 2"
EOF

if ./scripts/drift-handler.sh --check-only > /dev/null 2>&1; then
  echo "❌ FAIL (should have detected duplicate)"
  FAILED=$((FAILED + 1))
else
  if ./scripts/drift-handler.sh --check-only 2>&1 | grep -q "Duplicate IP+scope"; then
    echo "✅ PASS (correctly detected)"
    PASSED=$((PASSED + 1))
  else
    echo "❌ FAIL (wrong error)"
    FAILED=$((FAILED + 1))
  fi
fi

# Test 3: Same IP different scope should pass
echo -n "Test 3: Same IP different scope... "
cat > shared/config.yaml << EOF
ip_access_rules:
  - ip: "10.10.10.10"
    mode: "block"
    scope: "account"
    notes: "Test 1"
  - ip: "10.10.10.10"
    mode: "block"
    scope: "zone"
    notes: "Test 2"
EOF

if ./scripts/drift-handler.sh --check-only 2>&1 | grep -q "Duplicate IP+scope"; then
  echo "❌ FAIL (should allow different scopes)"
  FAILED=$((FAILED + 1))
else
  echo "✅ PASS"
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
