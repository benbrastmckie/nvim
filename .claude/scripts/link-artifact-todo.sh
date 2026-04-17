#!/usr/bin/env bash
# link-artifact-todo.sh - Automate TODO.md artifact linking
#
# Implements the four-case artifact linking logic from
# .claude/context/patterns/artifact-linking-todo.md
#
# Usage:
#   .claude/scripts/link-artifact-todo.sh <task_number> <field_name> <next_field> <artifact_path> [--dry-run]
#
# Arguments:
#   task_number    - Task number (integer)
#   field_name     - Field to link under: "**Research**", "**Plan**", or "**Summary**"
#   next_field     - Field that follows: "**Plan**", "**Description**", or "**Summary**"
#   artifact_path  - Full path like specs/421_slug/plans/01_plan.md
#
# Parameterization map:
#   research -> field_name="**Research**"  next_field="**Plan**"
#   plan     -> field_name="**Plan**"      next_field="**Description**"
#   summary  -> field_name="**Summary**"   next_field="**Description**"
#
# Exit codes:
#   0 - Success or no-op (already linked)
#   1 - Validation error
#   2 - Task entry not found
#   3 - Edit failed

set -uo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TODO_FILE="$PROJECT_ROOT/specs/TODO.md"

# --- Parse arguments ---
DRY_RUN=false
POSITIONAL_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *) POSITIONAL_ARGS+=("$arg") ;;
  esac
done

task_number="${POSITIONAL_ARGS[0]:-}"
field_name="${POSITIONAL_ARGS[1]:-}"
next_field="${POSITIONAL_ARGS[2]:-}"
artifact_path="${POSITIONAL_ARGS[3]:-}"

# --- Validation ---
if [[ -z "$task_number" || -z "$field_name" || -z "$next_field" || -z "$artifact_path" ]]; then
  echo "Usage: $0 <task_number> <field_name> <next_field> <artifact_path> [--dry-run]" >&2
  echo "  field_name: '**Research**', '**Plan**', or '**Summary**'" >&2
  echo "  next_field: '**Plan**', '**Description**', or '**Summary**'" >&2
  exit 1
fi

if ! [[ "$task_number" =~ ^[0-9]+$ ]]; then
  echo "Error: task_number must be a positive integer, got '$task_number'" >&2
  exit 1
fi

if [[ ! -f "$TODO_FILE" ]]; then
  echo "Error: TODO.md not found at $TODO_FILE" >&2
  exit 1
fi

# --- Strip specs/ prefix for TODO.md-relative links ---
todo_link_path="${artifact_path#specs/}"
artifact_filename=$(basename "$artifact_path")

# --- Helper: grep that returns empty string instead of failing ---
# Uses -- to separate options from patterns (patterns may start with -)
safe_grep() {
  grep "$@" 2>/dev/null || true
}

# --- Find task entry ---
heading_line=$(safe_grep -n "^### ${task_number}\." "$TODO_FILE" | head -1 | cut -d: -f1)

if [[ -z "$heading_line" ]]; then
  echo "Error: task $task_number entry not found in TODO.md" >&2
  exit 2
fi

# Determine the end of the task entry (next ### heading or end of file)
next_heading_line=$(tail -n +"$((heading_line + 1))" "$TODO_FILE" | safe_grep -n "^### " | head -1 | cut -d: -f1)
if [[ -n "$next_heading_line" ]]; then
  entry_end=$((heading_line + next_heading_line - 1))
else
  entry_end=$(wc -l < "$TODO_FILE")
fi

# Extract the task entry block
entry_block=$(sed -n "${heading_line},${entry_end}p" "$TODO_FILE")

# --- Case 4: Link already present ---
if echo "$entry_block" | grep -qF "$todo_link_path"; then
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] Case 4: artifact '$todo_link_path' already linked -- no-op"
  fi
  exit 0
fi

# --- Determine which case applies ---
# Check if field_name line exists in the entry
field_line_relative=$(echo "$entry_block" | safe_grep -nF -- "- ${field_name}:" | head -1 | cut -d: -f1)

if [[ -z "$field_line_relative" ]]; then
  # --- Case 1: No existing field line ---
  # Find the next_field line to insert before (try dash-prefixed first, then bare)
  next_field_line=$(sed -n "${heading_line},${entry_end}p" "$TODO_FILE" | safe_grep -nF -- "- ${next_field}:" | head -1 | cut -d: -f1)

  if [[ -z "$next_field_line" ]]; then
    # Try bare format (e.g., **Description**: without dash prefix)
    next_field_line=$(sed -n "${heading_line},${entry_end}p" "$TODO_FILE" | safe_grep -nF -- "${next_field}:" | head -1 | cut -d: -f1)
  fi

  if [[ -z "$next_field_line" && "$next_field" != "**Description**" ]]; then
    # Fallback: try **Description** as anchor when primary next_field not found
    next_field_line=$(sed -n "${heading_line},${entry_end}p" "$TODO_FILE" | safe_grep -nF -- "- **Description**:" | head -1 | cut -d: -f1)
    if [[ -z "$next_field_line" ]]; then
      next_field_line=$(sed -n "${heading_line},${entry_end}p" "$TODO_FILE" | safe_grep -nF -- "**Description**:" | head -1 | cut -d: -f1)
    fi
  fi

  if [[ -z "$next_field_line" ]]; then
    echo "Error: could not find insertion point (${next_field} or **Description**) for task $task_number" >&2
    exit 3
  fi

  actual_next_line=$((heading_line + next_field_line - 1))
  new_line="- ${field_name}: [${todo_link_path}]"

  # Blank line preservation: if the line before the insertion point is blank,
  # insert before the blank line so it remains between the new field and the next field
  prev_line_content=$(sed -n "$((actual_next_line - 1))p" "$TODO_FILE")
  if [[ -z "$prev_line_content" ]]; then
    actual_next_line=$((actual_next_line - 1))
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] Case 1: Insert new field line before line $actual_next_line"
    echo "[dry-run]   + $new_line"
    exit 0
  fi

  sed -i "${actual_next_line}i\\${new_line}" "$TODO_FILE"
  echo "OK: Case 1 - inserted ${field_name} link for task $task_number"
  exit 0
fi

# Field line exists -- determine if inline or multi-line
field_actual_line=$((heading_line + field_line_relative - 1))
field_line_content=$(sed -n "${field_actual_line}p" "$TODO_FILE")

# Check if the field line has an inline link (content after the colon)
# Use parameter expansion to extract value after "field_name: "
field_prefix="- ${field_name}: "
if [[ "$field_line_content" == "${field_prefix}"* ]]; then
  field_value="${field_line_content#${field_prefix}}"
elif [[ "$field_line_content" == "- ${field_name}:" ]]; then
  field_value=""
else
  field_value=""
fi

if [[ -z "$field_value" || "$field_value" == "$field_line_content" ]]; then
  # Field line exists but is empty (multi-line header) -- this is Case 3
  # Find the next_field line to insert before
  next_field_line_abs=$(sed -n "$((field_actual_line+1)),${entry_end}p" "$TODO_FILE" | safe_grep -nF -- "- ${next_field}:" | head -1 | cut -d: -f1)
  if [[ -z "$next_field_line_abs" ]]; then
    next_field_line_abs=$(sed -n "$((field_actual_line+1)),${entry_end}p" "$TODO_FILE" | safe_grep -nF -- "${next_field}:" | head -1 | cut -d: -f1)
    if [[ -z "$next_field_line_abs" && "$next_field" != "**Description**" ]]; then
      # Fallback: try **Description** as anchor when primary next_field not found
      next_field_line_abs=$(sed -n "$((field_actual_line+1)),${entry_end}p" "$TODO_FILE" | safe_grep -nF -- "- **Description**:" | head -1 | cut -d: -f1)
      if [[ -z "$next_field_line_abs" ]]; then
        next_field_line_abs=$(sed -n "$((field_actual_line+1)),${entry_end}p" "$TODO_FILE" | safe_grep -nF -- "**Description**:" | head -1 | cut -d: -f1)
      fi
    fi
    if [[ -z "$next_field_line_abs" ]]; then
      echo "Error: could not find ${next_field} after ${field_name} for task $task_number" >&2
      exit 3
    fi
    insert_before=$((field_actual_line + next_field_line_abs))
  else
    insert_before=$((field_actual_line + next_field_line_abs))
  fi

  new_bullet="  - [${todo_link_path}]"

  # Blank line preservation: if the line before the insertion point is blank,
  # insert before the blank line so it remains between the artifact list and the next field
  prev_line_content=$(sed -n "$((insert_before - 1))p" "$TODO_FILE")
  if [[ -z "$prev_line_content" ]]; then
    insert_before=$((insert_before - 1))
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] Case 3: Append bullet before line $insert_before"
    echo "[dry-run]   + $new_bullet"
    exit 0
  fi

  sed -i "${insert_before}i\\${new_bullet}" "$TODO_FILE"
  echo "OK: Case 3 - appended ${field_name} bullet for task $task_number"
  exit 0
fi

# Field has inline content -- check if it's a link (bracket-only [path] or markdown [text](url))
if echo "$field_value" | grep -qE '^\[.*\](\(.*\))?$'; then
  # --- Case 2: Existing inline single link ---
  existing_link="$field_value"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] Case 2: Convert inline to multi-line"
    echo "[dry-run]   existing: $field_line_content"
    echo "[dry-run]   new:"
    echo "[dry-run]     - ${field_name}:"
    echo "[dry-run]       - ${existing_link}"
    echo "[dry-run]       - [${todo_link_path}]"
    exit 0
  fi

  # Use awk for reliable multi-line replacement
  awk -v line="$field_actual_line" -v field="$field_name" -v existing="$existing_link" -v linkpath="$todo_link_path" '
    NR == line {
      print "- " field ":"
      print "  - " existing
      print "  - [" linkpath "]"
      next
    }
    { print }
  ' "$TODO_FILE" > "$TODO_FILE.tmp" && mv "$TODO_FILE.tmp" "$TODO_FILE"

  echo "OK: Case 2 - converted ${field_name} to multi-line for task $task_number"
  exit 0
fi

# Field has non-link inline content (e.g., "TBD" or "None") -- replace with link
if [[ "$DRY_RUN" == "true" ]]; then
  echo "[dry-run] Replacing ${field_name} value with artifact link"
  echo "[dry-run]   old: $field_line_content"
  echo "[dry-run]   new: - ${field_name}: [${todo_link_path}]"
  exit 0
fi

sed -i "${field_actual_line}s|.*|- ${field_name}: [${todo_link_path}]|" "$TODO_FILE"
echo "OK: Replaced ${field_name} value with link for task $task_number"
exit 0
