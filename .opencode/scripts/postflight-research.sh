#!/bin/bash
# postflight-research.sh - Research postflight with correct jq pattern
#
# Usage: ./postflight-research.sh TASK_NUMBER ARTIFACT_PATH [ARTIFACT_SUMMARY]
#
# This script updates specs/state.json after research completion using the
# two-step jq pattern to avoid Issue #1132 (OpenCode Bash tool escaping bug).
#
# See: .opencode/context/core/patterns/jq-escaping-workarounds.md

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 TASK_NUMBER ARTIFACT_PATH [ARTIFACT_SUMMARY]"
    echo ""
    echo "Arguments:"
    echo "  TASK_NUMBER      Task number to update"
    echo "  ARTIFACT_PATH    Path to research report (relative to project root)"
    echo "  ARTIFACT_SUMMARY Optional summary of research findings"
    exit 1
fi

task_number="$1"
artifact_path="$2"
artifact_summary="${3:-Research report}"
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

echo "Updating task $task_number with research artifact..."

# Step 1: Update status and timestamps
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "researched" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    researched: $ts
  }' "$state_file" > /tmp/state.json && mv /tmp/state.json "$state_file"

echo "  Status updated to 'researched'"

# Step 2: Filter out existing research artifacts (two-step pattern for Issue #1132)
jq '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
    [(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type != "research")]' \
  "$state_file" > /tmp/state.json && mv /tmp/state.json "$state_file"

# Step 3: Add new research artifact
jq --arg path "$artifact_path" \
   --arg summary "$artifact_summary" \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts += [{"path": $path, "type": "research", "summary": $summary}]' \
  "$state_file" > /tmp/state.json && mv /tmp/state.json "$state_file"

echo "  Artifact linked: $artifact_path"
echo "Done."
