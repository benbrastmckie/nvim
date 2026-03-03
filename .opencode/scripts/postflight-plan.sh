#!/bin/bash
# postflight-plan.sh - Planning postflight with correct jq pattern
#
# Usage: ./postflight-plan.sh TASK_NUMBER ARTIFACT_PATH [ARTIFACT_SUMMARY]
#
# This script updates specs/state.json after plan creation using the
# two-step jq pattern to avoid Issue #1132 (OpenCode Bash tool escaping bug).
#
# See: .opencode/context/core/patterns/jq-escaping-workarounds.md

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 TASK_NUMBER ARTIFACT_PATH [ARTIFACT_SUMMARY]"
    echo ""
    echo "Arguments:"
    echo "  TASK_NUMBER      Task number to update"
    echo "  ARTIFACT_PATH    Path to implementation plan (relative to project root)"
    echo "  ARTIFACT_SUMMARY Optional summary of plan"
    exit 1
fi

task_number="$1"
artifact_path="$2"
artifact_summary="${3:-Implementation plan}"
state_file="specs/state.json"

# Validate state file exists
if [ ! -f "$state_file" ]; then
    echo "Error: $state_file not found"
    exit 1
fi

# Validate task exists
task_exists=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .project_number' \
  "$state_file")

if [ -z "$task_exists" ]; then
    echo "Error: Task $task_number not found in specs/state.json"
    exit 1
fi

echo "Updating task $task_number with plan artifact..."

# Step 1: Update status and timestamps
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "planned" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    planned: $ts
  }' "$state_file" > /tmp/state.json && mv /tmp/state.json "$state_file"

echo "  Status updated to 'planned'"

# Step 2: Filter out existing plan artifacts (two-step pattern for Issue #1132)
jq '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
    [(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type != "plan")]' \
  "$state_file" > /tmp/state.json && mv /tmp/state.json "$state_file"

# Step 3: Add new plan artifact
jq --arg path "$artifact_path" \
   --arg summary "$artifact_summary" \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts += [{"path": $path, "type": "plan", "summary": $summary}]' \
  "$state_file" > /tmp/state.json && mv /tmp/state.json "$state_file"

echo "  Artifact linked: $artifact_path"
echo "Done."
