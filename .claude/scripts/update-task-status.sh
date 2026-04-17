#!/usr/bin/env bash
# update-task-status.sh - Centralized task status update script
#
# Updates task status atomically across:
#   1. state.json (status field, timestamps, session_id)
#   2. TODO.md task entry (- **Status**: [STATUS])
#   3. TODO.md Task Order section (**{N}** [STATUS])
#   4. Plan file (optional, via update-plan-status.sh)
#
# Usage:
#   .claude/scripts/update-task-status.sh <operation> <task_number> <target_status> <session_id> [--dry-run]
#
# Arguments:
#   operation     - "preflight" or "postflight"
#   task_number   - Task number (integer)
#   target_status - "research", "plan", or "implement"
#   session_id    - Session identifier string
#
# Exit codes:
#   0 - Success or no-op (already at target status)
#   1 - Validation error (bad arguments)
#   2 - state.json update failed
#   3 - TODO.md update failed

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_FILE="$PROJECT_ROOT/specs/state.json"
TODO_FILE="$PROJECT_ROOT/specs/TODO.md"
TMP_DIR="$PROJECT_ROOT/specs/tmp"

# --- Cleanup trap ---
cleanup() {
  rm -f "$TMP_DIR/state.json.tmp" "$TMP_DIR/todo.md.tmp" 2>/dev/null || true
}
trap cleanup EXIT

# --- Parse arguments ---
DRY_RUN=false
POSITIONAL_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *) POSITIONAL_ARGS+=("$arg") ;;
  esac
done

operation="${POSITIONAL_ARGS[0]:-}"
task_number="${POSITIONAL_ARGS[1]:-}"
target_status="${POSITIONAL_ARGS[2]:-}"
session_id="${POSITIONAL_ARGS[3]:-}"

# --- Validation ---
if [[ -z "$operation" || -z "$task_number" || -z "$target_status" || -z "$session_id" ]]; then
  echo "Usage: $0 <operation> <task_number> <target_status> <session_id> [--dry-run]" >&2
  echo "  operation:     preflight | postflight" >&2
  echo "  target_status: research | plan | implement" >&2
  exit 1
fi

if [[ "$operation" != "preflight" && "$operation" != "postflight" ]]; then
  echo "Error: operation must be 'preflight' or 'postflight', got '$operation'" >&2
  exit 1
fi

if [[ "$target_status" != "research" && "$target_status" != "plan" && "$target_status" != "implement" ]]; then
  echo "Error: target_status must be 'research', 'plan', or 'implement', got '$target_status'" >&2
  exit 1
fi

if ! [[ "$task_number" =~ ^[0-9]+$ ]]; then
  echo "Error: task_number must be a positive integer, got '$task_number'" >&2
  exit 1
fi

if [[ ! -f "$STATE_FILE" ]]; then
  echo "Error: state.json not found at $STATE_FILE" >&2
  exit 1
fi

# --- Status mapping ---
map_status() {
  local op="$1"
  local target="$2"

  case "${op}:${target}" in
    preflight:research)   STATE_STATUS="researching";   TODO_STATUS="RESEARCHING" ;;
    preflight:plan)       STATE_STATUS="planning";      TODO_STATUS="PLANNING" ;;
    preflight:implement)  STATE_STATUS="implementing";  TODO_STATUS="IMPLEMENTING" ;;
    postflight:research)  STATE_STATUS="researched";    TODO_STATUS="RESEARCHED" ;;
    postflight:plan)      STATE_STATUS="planned";       TODO_STATUS="PLANNED" ;;
    postflight:implement) STATE_STATUS="completed";     TODO_STATUS="COMPLETED" ;;
    *)
      echo "Error: unknown operation:target_status combination '${op}:${target}'" >&2
      exit 1
      ;;
  esac
}

map_status "$operation" "$target_status"

# --- Validate task exists in state.json ---
task_exists=$(jq -r --arg num "$task_number" \
  '[.active_projects[] | select(.project_number == ($num | tonumber))] | length' \
  "$STATE_FILE")

if [[ "$task_exists" == "0" ]]; then
  echo "Error: task $task_number not found in state.json" >&2
  exit 1
fi

# --- Idempotency check ---
current_state_status=$(jq -r --arg num "$task_number" \
  '.active_projects[] | select(.project_number == ($num | tonumber)) | .status' \
  "$STATE_FILE")

if [[ "$current_state_status" == "$STATE_STATUS" ]]; then
  # Already at target status, no-op
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] Task $task_number already at status '$STATE_STATUS' -- no-op"
  fi
  exit 0
fi

# --- Ensure tmp directory exists ---
mkdir -p "$TMP_DIR"

# ============================================================
# PHASE 1: Update state.json (machine state first)
# ============================================================
update_state_json() {
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] state.json: task $task_number status '$current_state_status' -> '$STATE_STATUS'"
    echo "[dry-run] state.json: last_updated -> '$ts', session_id -> '$session_id'"
    return 0
  fi

  # Use two-step jq pattern to avoid Issue #1132
  # Step 1: Update status and timestamp
  jq --arg num "$task_number" \
     --arg status "$STATE_STATUS" \
     --arg ts "$ts" \
     --arg sid "$session_id" \
    '(.active_projects[] | select(.project_number == ($num | tonumber))) |= . + {
      status: $status,
      last_updated: $ts,
      session_id: $sid
    }' "$STATE_FILE" > "$TMP_DIR/state.json.tmp"

  if [[ $? -ne 0 ]]; then
    echo "Error: jq failed to update state.json" >&2
    return 1
  fi

  # Validate the output is valid JSON
  if ! jq empty "$TMP_DIR/state.json.tmp" 2>/dev/null; then
    echo "Error: jq produced invalid JSON for state.json" >&2
    return 1
  fi

  # Atomic move
  mv "$TMP_DIR/state.json.tmp" "$STATE_FILE"
}

if ! update_state_json; then
  echo "Error: failed to update state.json for task $task_number" >&2
  exit 2
fi

# ============================================================
# PHASE 2: Update TODO.md task entry status
# ============================================================
update_todo_task_entry() {
  if [[ ! -f "$TODO_FILE" ]]; then
    echo "Warning: TODO.md not found at $TODO_FILE, skipping task entry update" >&2
    return 1
  fi

  # Find the task entry heading line number: ### {N}. ...
  local heading_line
  heading_line=$(grep -n "^### ${task_number}\." "$TODO_FILE" | head -1 | cut -d: -f1)

  if [[ -z "$heading_line" ]]; then
    echo "Warning: task $task_number entry not found in TODO.md Tasks section" >&2
    return 0
  fi

  # Find the Status line within the next 10 lines after the heading
  # Tolerant pattern: matches both canonical "- **Status**:" and space-indented " **Status**:"
  # Some task entries use space-indented format without leading dash
  local status_line
  status_line=$(sed -n "$((heading_line+1)),$((heading_line+10))p" "$TODO_FILE" \
    | grep -n -E '^\s*-?\s*\*\*Status\*\*: \[' | head -1 | cut -d: -f1)

  if [[ -z "$status_line" ]]; then
    echo "Warning: no Status line found for task $task_number in TODO.md" >&2
    return 0
  fi

  # Calculate actual line number in file
  local actual_line=$((heading_line + status_line))

  # Check if already at target
  local current_todo_status
  current_todo_status=$(sed -n "${actual_line}p" "$TODO_FILE" | sed 's/.*\[\([^]]*\)\].*/\1/')

  if [[ "$current_todo_status" == "$TODO_STATUS" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[dry-run] TODO.md task entry: already at [$TODO_STATUS] -- skip"
    fi
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] TODO.md task entry (line $actual_line): [$current_todo_status] -> [$TODO_STATUS]"
    return 0
  fi

  # Replace the status on that specific line
  sed -i "${actual_line}s/\[${current_todo_status}\]/[${TODO_STATUS}]/" "$TODO_FILE"
}

# ============================================================
# PHASE 3: Update TODO.md Task Order section
# ============================================================
update_todo_task_order() {
  if [[ ! -f "$TODO_FILE" ]]; then
    echo "Warning: TODO.md not found, skipping Task Order update" >&2
    return 1
  fi

  # Find the line matching **{N}** with a status marker in Task Order
  local order_line
  order_line=$(grep -n -E "^- \*\*${task_number}\*\* \[" "$TODO_FILE" | head -1 | cut -d: -f1)

  if [[ -z "$order_line" ]]; then
    echo "Warning: task $task_number not found in TODO.md Task Order section" >&2
    return 0
  fi

  # Check if already at target
  local current_order_status
  current_order_status=$(sed -n "${order_line}p" "$TODO_FILE" | sed 's/.*\[\([^]]*\)\].*/\1/')

  if [[ "$current_order_status" == "$TODO_STATUS" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[dry-run] TODO.md Task Order: already at [$TODO_STATUS] -- skip"
    fi
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] TODO.md Task Order (line $order_line): [$current_order_status] -> [$TODO_STATUS]"
    return 0
  fi

  # Replace the status on that specific line
  sed -i "${order_line}s/\[${current_order_status}\]/[${TODO_STATUS}]/" "$TODO_FILE"
}

# ============================================================
# PHASE 4: Plan file status (optional, implement only)
# ============================================================
update_plan_file() {
  # Only update plan file for implement operations
  if [[ "$target_status" != "implement" ]]; then
    return 0
  fi

  local plan_status
  case "$operation" in
    preflight)  plan_status="IMPLEMENTING" ;;
    postflight) plan_status="COMPLETED" ;;
  esac

  # Look up project_name from state.json
  local project_name
  project_name=$(jq -r --arg num "$task_number" \
    '.active_projects[] | select(.project_number == ($num | tonumber)) | .project_name' \
    "$STATE_FILE")

  if [[ -z "$project_name" || "$project_name" == "null" ]]; then
    echo "Warning: could not determine project_name for task $task_number" >&2
    return 0
  fi

  local plan_script="$SCRIPT_DIR/update-plan-status.sh"
  if [[ ! -x "$plan_script" ]]; then
    echo "Warning: update-plan-status.sh not found or not executable" >&2
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] Plan file: status -> [$plan_status] (via update-plan-status.sh)"
    return 0
  fi

  # Call existing script; non-fatal if it fails
  cd "$PROJECT_ROOT"
  "$plan_script" "$task_number" "$project_name" "$plan_status" 2>/dev/null || {
    echo "Warning: plan file update failed (non-fatal)" >&2
  }
}

# Execute TODO.md updates
todo_failed=false

if ! update_todo_task_entry; then
  todo_failed=true
fi

if ! update_todo_task_order; then
  todo_failed=true
fi

# Execute plan file update
update_plan_file

# Report result
if [[ "$todo_failed" == "true" && "$DRY_RUN" != "true" ]]; then
  echo "Warning: TODO.md updates had issues (state.json was updated successfully)" >&2
  exit 3
fi

if [[ "$DRY_RUN" != "true" ]]; then
  echo "OK: task $task_number status -> $STATE_STATUS"
fi

exit 0
