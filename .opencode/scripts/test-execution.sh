#!/usr/bin/env bash
#
# Test the .opencode command execution system
#

set -euo pipefail

echo "=== Testing .opencode Command Execution ==="

# Test basic command routing
echo "Testing task command help..."

# Execute the task command with no arguments to see help
".opencode/scripts/execute-command.sh" "task" "--help"

echo ""
echo "✓ Command execution test completed"