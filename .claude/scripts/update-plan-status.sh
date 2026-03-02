#!/usr/bin/env bash
# update-plan-status.sh - Centralized plan-level status update
# Usage: .claude/scripts/update-plan-status.sh TASK_NUMBER PROJECT_NAME STATUS
#
# STATUS values: IMPLEMENTING, COMPLETED, PARTIAL, NOT_STARTED
# Outputs: Updated plan file path on success, empty on failure/no-op

set -euo pipefail

task_number="${1:-}"
project_name="${2:-}"
new_status="${3:-}"

# Validate inputs
if [[ -z "$task_number" || -z "$project_name" || -z "$new_status" ]]; then
    echo "Usage: $0 TASK_NUMBER PROJECT_NAME STATUS" >&2
    exit 1
fi

# Normalize status
case "$new_status" in
    IMPLEMENTING|implementing) new_status="IMPLEMENTING" ;;
    COMPLETED|completed) new_status="COMPLETED" ;;
    PARTIAL|partial) new_status="PARTIAL" ;;
    NOT_STARTED|not_started) new_status="NOT STARTED" ;;
    *) echo "Unknown status: $new_status" >&2; exit 1 ;;
esac

# Find plan file (padded directory)
padded_num=$(printf "%03d" "$task_number")
plan_dir="specs/${padded_num}_${project_name}/plans"

if [[ ! -d "$plan_dir" ]]; then
    # Try unpadded (legacy)
    plan_dir="specs/${task_number}_${project_name}/plans"
fi

if [[ ! -d "$plan_dir" ]]; then
    echo "Plan directory not found for task $task_number" >&2
    exit 1
fi

# Get latest plan file
plan_file=$(ls -t "$plan_dir"/implementation-*.md 2>/dev/null | head -1)
if [[ -z "$plan_file" ]]; then
    echo "No plan file found in $plan_dir" >&2
    exit 1
fi

# Check current status (idempotency)
current_status=$(grep -m1 "^- \*\*Status\*\*:" "$plan_file" | sed 's/.*\[\([^]]*\)\].*/\1/' || echo "")
if [[ "$current_status" == "$new_status" ]]; then
    # Already at target, no-op
    exit 0
fi

# Update plan-level status (first match only)
sed -i "0,/^- \*\*Status\*\*: \[.*\]/{s/^- \*\*Status\*\*: \[.*\]$/- **Status**: [${new_status}]/}" "$plan_file"

# Verify update
updated_status=$(grep -m1 "^- \*\*Status\*\*:" "$plan_file" | sed 's/.*\[\([^]]*\)\].*/\1/' || echo "")
if [[ "$updated_status" == "$new_status" ]]; then
    echo "$plan_file"
else
    echo "Failed to update status in $plan_file" >&2
    exit 1
fi
