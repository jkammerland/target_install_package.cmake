#!/bin/bash
set -e

echo "=== CPack Regression Tests ==="

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Run test 1
echo ""
echo "Running Test 1..."
bash test-single-component.sh

# Return to base directory
cd "$SCRIPT_DIR"

# Run test 2
echo ""
echo "Running Test 2..."
bash test-custom-generators.sh

echo ""
echo "✅ All regression tests passed!"