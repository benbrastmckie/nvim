#!/usr/bin/env bash
#
# Test the command execution system
#

set -euo pipefail

echo "=== Testing .opencode Command Execution ==="

# Set test environment
export OPENCODE_ROOT="$(pwd)/.opencode"

# Test 1: Simple task command execution
echo "Test 1: /task --help"
".opencode/scripts/execute-command.sh" "task" "--help" || {
  echo "✗ Test 1 FAILED: Could not execute task command"
  exit 1
}

echo ""
echo "✓ Test 1 PASSED: Command execution works"
echo ""

# Test 2: LEAN-specific command
echo "Test 2: /lean-build --help"
".opencode/scripts/execute-command.sh" "lean-build" "--help" || {
  echo "✗ Test 2 FAILED: Could not execute lean-build command"
  exit 1
}

echo ""
echo "✓ Test 2 PASSED: LEAN command execution works"
echo ""

# Test 3: Research command with task
echo "Test 3: /research 673"
".opencode/scripts/execute-command.sh" "research" "673" || {
  echo "✗ Test 3 FAILED: Could not execute research command"
  exit 1
}

echo ""
echo "✓ Test 3 PASSED: Research command execution works"
echo ""

echo "=== All Tests Passed ==="
echo "✓ Command execution infrastructure is working"
echo "✓ Core commands route properly"
echo "✓ LEAN-specific commands integrate correctly"
echo "✓ Ready for Phase 2 component integration"