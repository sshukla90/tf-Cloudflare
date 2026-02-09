#!/bin/bash
# Run all tests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Running All Tests"
echo "===================="
echo ""

TOTAL_PASSED=0
TOTAL_FAILED=0

# Run unit tests
for test in "$SCRIPT_DIR"/unit/test_*.sh; do
  if [ -f "$test" ]; then
    echo "Running $(basename "$test")..."
    if bash "$test"; then
      TOTAL_PASSED=$((TOTAL_PASSED + 1))
    else
      TOTAL_FAILED=$((TOTAL_FAILED + 1))
    fi
    echo ""
  fi
done

echo "===================="
echo "Final Results:"
echo "  ✅ Passed: $TOTAL_PASSED"
echo "  ❌ Failed: $TOTAL_FAILED"
echo "===================="

if [ $TOTAL_FAILED -gt 0 ]; then
  exit 1
fi

exit 0
