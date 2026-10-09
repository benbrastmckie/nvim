#!/usr/bin/env bash
# archive-task.sh - Archive a single task from active state to archive
#
# Usage: archive-task.sh <task_number> <project_name> [--dry-run] [--session-id SID]
#
# Operations:
#   A. Move task entry from state.json active_projects to archive/state.json completed_projects
#      (archive/state.json is a DIFFERENT file from specs/state.json, reached via
#      state-write.sh's --state-file flag -- both this write and step B below go through the
#      same mutex-guarded writer)
#   B. Remove task entry from state.json active_projects (routed through state-write.sh)
#   C. Regenerate TODO.md from state.json (task no longer in active_projects, so not rendered)
#   D. Move task directory from specs/ to specs/archive/
#
# Handles both padded (015_slug) and unpadded (15_slug) directory formats.
#
# --session-id SID   Optional. Attributes the specs/.scope-lock mutex acquisition (via
#                     state-write.sh) to this session. If omitted, a session_id is generated
#                     inline using the same portable pattern command-gate-in.sh uses, so this
#                     script remains callable standalone.
#
# Exit codes:
#   0 - Success
#   1 - Error (missing arguments, files not found, jq failure)

set -euo pipefail

# --- Arguments ---
task_number=""
project_name=""
dry_run=false
session_id=""
positional=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      dry_run=true
      shift
      ;;
    --session-id)
      session_id="${2:-}"
      shift 2
      ;;
    --session-id=*)
      session_id="${1#--session-id=}"
      shift
      ;;
    *)
      positional+=("$1")
      shift
      ;;
  esac
done
task_number="${positional[0]:-}"
project_name="${positional[1]:-}"

if [ -z "$task_number" ] || [ -z "$project_name" ]; then
  echo "Usage: archive-task.sh <task_number> <project_name> [--dry-run] [--session-id SID]" >&2
  exit 1
fi

if [ -z "$session_id" ]; then
  # shellcheck disable=SC2034  # _EARLY_SCRIPT_DIR is used immediately below, not unused
  _EARLY_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "${_EARLY_SCRIPT_DIR}/lib/common.sh"
  unset _EARLY_SCRIPT_DIR
  session_id="$(common_session_id)"
fi

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
STATE_FILE="$PROJECT_ROOT/specs/state.json"
ARCHIVE_DIR="$PROJECT_ROOT/specs/archive"
ARCHIVE_STATE_FILE="$ARCHIVE_DIR/state.json"
# shellcheck disable=SC2034  # Deprecated script; TODO_FILE is unread today but kept as a documented path constant.
TODO_FILE="$PROJECT_ROOT/specs/TODO.md"

# --- Validate inputs ---
if [ ! -f "$STATE_FILE" ]; then
  echo "error: state.json not found at $STATE_FILE" >&2
  exit 1
fi

# --- Ensure archive directory exists ---
if ! $dry_run; then
  mkdir -p "$ARCHIVE_DIR"
fi

# --- Initialize archive/state.json if missing ---
if [ ! -f "$ARCHIVE_STATE_FILE" ]; then
  if ! $dry_run; then
    "$SCRIPT_DIR/state-write.sh" \
      '{ "archived_projects": [], "completed_projects": [] }' \
      --init --state-file "$ARCHIVE_STATE_FILE" --session-id "$session_id" \
      || { echo "error: state-write.sh failed to initialize $ARCHIVE_STATE_FILE" >&2; exit 1; }
  fi
fi

# --- Extract task entry from state.json ---
task_entry=$(jq --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  "$STATE_FILE" 2>/dev/null)

if [ -z "$task_entry" ] || [ "$task_entry" = "null" ]; then
  echo "error: task $task_number not found in active_projects" >&2
  exit 1
fi

task_status=$(echo "$task_entry" | jq -r '.status // "completed"')

if $dry_run; then
  echo "[dry-run] Would archive task $task_number ($project_name, status: $task_status)"
  # Determine directory
  padded_num=$(printf "%03d" "$task_number")
  if [ -d "$PROJECT_ROOT/specs/${padded_num}_${project_name}" ]; then
    echo "[dry-run] Would move: specs/${padded_num}_${project_name} -> specs/archive/${padded_num}_${project_name}"
  elif [ -d "$PROJECT_ROOT/specs/${task_number}_${project_name}" ]; then
    echo "[dry-run] Would move: specs/${task_number}_${project_name} -> specs/archive/${padded_num}_${project_name}"
  else
    echo "[dry-run] Note: no directory found for task $task_number (would skip)"
  fi
  exit 0
fi

# --- A. Move task entry to archive/state.json ---
# Determine target array in archive based on status
if [ "$task_status" = "abandoned" ]; then
  archive_array="archived_projects"
else
  archive_array="completed_projects"
fi

"$SCRIPT_DIR/state-write.sh" \
  '.[$array] += [$entry]' \
  --state-file "$ARCHIVE_STATE_FILE" \
  --session-id "$session_id" \
  --argjson entry "$task_entry" \
  --arg array "$archive_array" \
  || { echo "error: state-write.sh failed to archive task $task_number to $archive_array" >&2; exit 1; }

echo "Archived state entry for task $task_number to $archive_array"

# --- B. Remove task from state.json active_projects ---
# Use del() pattern -- Issue #1132-safe (avoids != operator). Routed through state-write.sh, the
# single mutex-guarded specs/state.json writer.
"$SCRIPT_DIR/state-write.sh" \
  'del(.active_projects[] | select(.project_number == $num))' \
  --session-id "$session_id" \
  --argjson num "$task_number" \
  || { echo "error: state-write.sh failed to remove task $task_number from active_projects" >&2; exit 1; }

echo "Removed task $task_number from active_projects"

# --- C. Regenerate TODO.md from state.json ---
# Task is no longer in active_projects, so generate-todo.sh will not render it.
# This is a best-effort step -- warn on failure but don't abort
GENERATE_TODO="$SCRIPT_DIR/generate-todo.sh"
if [ -f "$GENERATE_TODO" ]; then
  bash "$GENERATE_TODO" 2>/dev/null \
    || echo "Warning: generate-todo.sh failed (non-fatal)" >&2
  echo "Regenerated TODO.md after archiving task $task_number"
else
  echo "Note: generate-todo.sh not found -- skipping TODO.md regeneration" >&2
fi

# --- D. Move project directory to archive ---
padded_num=$(printf "%03d" "$task_number")

# Check padded directory first, then fall back to unpadded for legacy
if [ -d "$PROJECT_ROOT/specs/${padded_num}_${project_name}" ]; then
  src="$PROJECT_ROOT/specs/${padded_num}_${project_name}"
elif [ -d "$PROJECT_ROOT/specs/${task_number}_${project_name}" ]; then
  src="$PROJECT_ROOT/specs/${task_number}_${project_name}"
else
  src=""
fi

# Always archive to padded directory
dst="${ARCHIVE_DIR}/${padded_num}_${project_name}"

if [ -n "$src" ] && [ -d "$src" ]; then
  mv "$src" "$dst"
  echo "Moved: $(basename "$src") -> archive/${padded_num}_${project_name}/"
else
  echo "Note: no directory for task $task_number (skipped)"
fi

exit 0
