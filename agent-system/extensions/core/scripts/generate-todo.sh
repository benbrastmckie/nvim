#!/usr/bin/env bash
#
# generate-todo.sh - Generate the entire TODO.md from state.json
#
# Usage:
#   generate-todo.sh [OPTIONS]
#
# Options:
#   --todo FILE       Path to output TODO.md (default: specs/TODO.md)
#   --state FILE      Path to state.json (default: specs/state.json)
#   --dry-run         Print generated content to stdout; do not write file
#   --log FILE        Path to log file (default: .agent-logs/generate-todo.log)
#   --no-log          Suppress all log output
#
# The generated file contains:
#   1. YAML frontmatter: ---\nnext_project_number: N\n---
#   2. # TODO heading
#   3. ## Task Order section (delegated to generate-task-order.sh --print)
#   4. ## Tasks section with all entries in descending project_number order
#
# Terminal tasks (completed/abandoned/expanded) appear in ## Tasks but not ## Task Order.
# Atomic write via mktemp + mv ensures no partial/corrupted output.
#
# Logging: append-only to .agent-logs/generate-todo.log with ISO timestamps.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1

# --- Shared status-vocabulary library ---
# Single sourced anchor for the closed 13-value task-status enum and its state.json-value ->
# TODO.md-marker mapping -- see context/schemas/state-schema.json's definitions.taskStatus and
# scripts/lib/status-vocabulary.sh's own header. Deploy-tree-first / source-store-fallback
# candidate list, matching update-task-status.sh's resolution of phase-heading-patterns.sh. Never
# falls through to an inline mapping: a missing library is a loud environment error, not a silent
# degradation back to the old permissive catch-all.
VOCAB_LIB_CANDIDATES=(
  "${SCRIPT_DIR}/lib/status-vocabulary.sh"
  "${PROJECT_ROOT}/agent-system/extensions/core/scripts/lib/status-vocabulary.sh"
)
VOCAB_LIB=""
for _vocab_candidate in "${VOCAB_LIB_CANDIDATES[@]}"; do
  if [[ -f "$_vocab_candidate" ]]; then
    VOCAB_LIB="$_vocab_candidate"
    break
  fi
done
if [[ -z "$VOCAB_LIB" ]]; then
  echo "ERROR: shared library status-vocabulary.sh not found at any of:" >&2
  for _vocab_candidate in "${VOCAB_LIB_CANDIDATES[@]}"; do
    echo "  $_vocab_candidate" >&2
  done
  exit 1
fi
# shellcheck disable=SC1090
. "$VOCAB_LIB"

# ============================================================================
# Default Values
# ============================================================================

TODO_FILE="${PROJECT_ROOT}/specs/TODO.md"
STATE_FILE="${PROJECT_ROOT}/specs/state.json"
DRY_RUN=0
LOG_FILE="${PROJECT_ROOT}/.agent-logs/generate-todo.log"
NO_LOG=0

# ============================================================================
# Parse Arguments
# ============================================================================

while [[ $# -gt 0 ]]; do
  case "$1" in
    --todo)
      shift
      TODO_FILE="${1:-}"
      [[ $# -gt 0 ]] && shift
      ;;
    --state)
      shift
      STATE_FILE="${1:-}"
      [[ $# -gt 0 ]] && shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --log)
      shift
      LOG_FILE="${1:-}"
      [[ $# -gt 0 ]] && shift
      ;;
    --no-log)
      NO_LOG=1
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: generate-todo.sh [--todo FILE] [--state FILE] [--dry-run] [--log FILE] [--no-log]" >&2
      exit 1
      ;;
  esac
done

# ============================================================================
# Logging
# ============================================================================

START_TIME=$(date +%s)

log() {
  local level="$1"
  shift
  local message="$*"
  if [[ "$NO_LOG" -eq 1 ]]; then
    return
  fi
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  mkdir -p "$(dirname "$LOG_FILE")"
  printf '[%s] generate-todo: %s %s\n' "$timestamp" "$level" "$message" >> "$LOG_FILE"
}

log_error() {
  log "ERROR" "$@"
  echo "ERROR: $*" >&2
}

# ============================================================================
# Validation
# ============================================================================

if [[ ! -f "$STATE_FILE" ]]; then
  log_error "state.json not found at ${STATE_FILE}"
  exit 1
fi

# ============================================================================
# Status Mapping
# ============================================================================

format_status() {
  local raw="$1"
  # Sourced from scripts/lib/status-vocabulary.sh -- the single anchor for the closed 13-value
  # enum and its TODO.md-marker mapping -- rather than re-typed as 13 inline case arms. Returns
  # nonzero (printing nothing) on an off-schema value; the CALLER is responsible for the loud,
  # task-identifying failure (see generate_task_entry() below) because status_vocabulary_todo_marker
  # is invoked via command substitution here, and `exit` inside a command-substitution subshell
  # would only terminate that subshell, not this script -- deliberately not done here. The
  # permissive `*)` catch-all that used to silently uppercase any unknown status into a
  # plausible-looking marker has been removed entirely; there is no fallback branch.
  status_vocabulary_todo_marker "$raw"
}

# ============================================================================
# Artifact Type Mapping
# ============================================================================

format_artifact_type() {
  local atype="$1"
  case "$atype" in
    research|report) printf '%s' "Research" ;;
    plan)            printf '%s' "Plan" ;;
    summary|implementation) printf '%s' "Summary" ;;
    *)
      # Capitalize first letter of unknown types
      local first="${atype:0:1}"
      local rest="${atype:1}"
      printf '%s' "$(echo "$first" | tr '[:lower:]' '[:upper:]')${rest}"
      ;;
  esac
}

# ============================================================================
# Generate Task Entry
# ============================================================================

# generate_task_entry: outputs a complete TODO.md task entry for one project_number.
# All fields arrive pre-extracted and already decoded by the caller (generate_todo()'s single
# full-file jq pass plus its one-base64-spawn-per-row decode) -- no jq or base64 is spawned here.
generate_task_entry() {
  local task_num="$1" project_name="$2" title="$3" status="$4" task_type="$5" topic="$6" \
        effort="$7" description="$8" deps_csv="$9" artifacts_raw="${10}" held_at="${11:-}"

  # Title fallback: derive from project_name if title is empty. (The upstream jq pass already
  # applies `// ""` / `// "general"` defaults, so a bash-level "null" string check -- as the
  # prior per-task jq round-trip carried defensively -- can never trigger and is dropped.)
  if [[ -z "$title" ]]; then
    if [[ -n "$project_name" ]]; then
      # Replace underscores with spaces and capitalize first letter
      title="${project_name//_/ }"
      title="${title^}"
    else
      title="Task ${task_num}"
    fi
  fi

  # Format status. A common confusion source named in the error: .return-meta.json uses a
  # DIFFERENT vocabulary (e.g. "in_progress") that is never a valid specs/state.json status
  # value -- see status-markers.md's Target Arguments vs. Resting States subsection.
  local status_display
  if ! status_display=$(format_status "$status"); then
    log_error "off-schema status '${status}' for task ${task_num} is not a member of the closed task-status enum (see context/schemas/state-schema.json / scripts/lib/status-vocabulary.sh). A common confusion source: .return-meta.json uses a DIFFERENT vocabulary (e.g. 'in_progress') that is never a valid specs/state.json status value. Nothing was written."
    exit 1
  fi

  # Heading
  printf '### %s. %s\n' "$task_num" "$title"

  # Effort (omit if empty)
  if [[ -n "$effort" ]]; then
    printf -- '- **Effort**: %s\n' "$effort"
  fi

  # Status
  printf -- '- **Status**: [%s]\n' "$status_display"

  # Held date (hold-status only): the TODO.md twin of state.json's held_at field, per
  # context/standards/status-markers.md's [HOLD] Required Information block.
  if [[ "$status" == "hold" && -n "$held_at" ]]; then
    printf -- '- **Held**: %s\n' "$held_at"
  fi

  # Task Type
  if [[ -n "$task_type" ]]; then
    printf -- '- **Task Type**: %s\n' "$task_type"
  fi

  # Topic (omit if empty)
  if [[ -n "$topic" ]]; then
    printf -- '- **Topic**: %s\n' "$topic"
  fi

  # Dependencies (deps_csv is a comma-joined list of task numbers, or empty when none)
  if [[ -z "$deps_csv" ]]; then
    printf -- '- **Dependencies**: None\n'
  else
    local dep_list="" d
    IFS=',' read -ra dep_arr <<< "$deps_csv"
    for d in "${dep_arr[@]}"; do
      [[ -z "$d" ]] && continue
      if [[ -z "$dep_list" ]]; then
        dep_list="Task ${d}"
      else
        dep_list="${dep_list}, Task ${d}"
      fi
    done
    printf -- '- **Dependencies**: %s\n' "$dep_list"
  fi

  # Artifacts: group by logical type
  # Types: research/report -> Research, plan -> Plan, summary/implementation -> Summary, other -> Capitalized
  # artifacts_raw is already "type|path" lines (one per artifact, newline-joined), decoded by the
  # caller -- an empty string means no artifacts.
  if [[ -n "$artifacts_raw" ]]; then
    # Collect artifacts by logical type
    # We need to group artifacts by their display type and render each group
    # Strategy: iterate all artifacts with their display types, then group by type

    # Track which display types we've already rendered headers for
    declare -A rendered_types=()
    declare -A type_artifacts=()   # display_type -> newline-separated paths
    declare -a type_order=()       # order of first appearance

    while IFS='|' read -r atype apath; do
      [[ -z "$apath" ]] && continue
      local display_type
      display_type=$(format_artifact_type "$atype")
      if [[ -z "${type_artifacts[$display_type]+x}" ]]; then
        type_order+=("$display_type")
        type_artifacts["$display_type"]=""
      fi
      # Strip specs/ prefix from path
      local short_path="${apath#specs/}"
      if [[ -z "${type_artifacts[$display_type]}" ]]; then
        type_artifacts["$display_type"]="$short_path"
      else
        type_artifacts["$display_type"]="${type_artifacts[$display_type]}
${short_path}"
      fi
    done <<< "$artifacts_raw"

    # Render each type group
    for display_type in "${type_order[@]}"; do
      local paths_str="${type_artifacts[$display_type]}"
      # Count paths by counting newlines + 1
      local path_count
      path_count=$(printf '%s' "$paths_str" | grep -c '' || true)

      if [[ "$path_count" -le 1 ]]; then
        # Single artifact: inline format
        printf -- '- **%s**: [%s]\n' "$display_type" "$paths_str"
      else
        # Multiple artifacts: multi-line list
        printf -- '- **%s**:\n' "$display_type"
        while IFS= read -r p; do
          [[ -z "$p" ]] && continue
          printf '  - [%s]\n' "$p"
        done <<< "$paths_str"
      fi
    done

    unset rendered_types type_artifacts type_order
  fi

  # Description (omit if empty/null)
  if [[ -n "$description" && "$description" != "null" ]]; then
    printf '\n'
    printf '**Description**: %s\n' "$description"
  fi
}

# ============================================================================
# Generate TODO.md Content
# ============================================================================

generate_todo() {
  # --- YAML frontmatter ---
  local next_num
  next_num=$(jq -r '.next_project_number' "$STATE_FILE")
  printf -- '---\n'
  printf 'next_project_number: %s\n' "$next_num"
  printf -- '---\n'
  printf '\n'

  log "INFO" "frontmatter written (next_project_number=${next_num})"

  # --- Title heading ---
  printf '# TODO\n'
  printf '\n'

  # --- Task Order section ---
  # generate-task-order.sh --print uses its own default state.json path.
  # We pass our STATE_FILE via a temporary symlink workaround if it differs, but
  # normally both scripts share the same PROJECT_ROOT/specs/state.json default.
  # Capture stdout and stderr SEPARATELY. Merging them (2>&1) conflates diagnostics with
  # document content: generate-task-order.sh writes non-fatal notes to stderr (the
  # "No active non-terminal tasks found" INFO on the empty-graph path, and the
  # "task(s) have no topic" Warning), and a merged capture embeds those lines verbatim into
  # TODO.md where the Task Order section belongs. stderr is for the log, never the document.
  local task_order_output task_order_err err_file
  err_file=$(mktemp -p "$(dirname "$TODO_FILE")" "task-order-err.XXXXXX")
  if task_order_output=$("${SCRIPT_DIR}/generate-task-order.sh" --print 2>"$err_file"); then
    # Empty stdout is legitimate: the empty-graph path exits 0 having printed nothing, in
    # which case the Task Order section is simply omitted rather than rendered blank.
    if [[ -n "$task_order_output" ]]; then
      printf '%s\n' "$task_order_output"
    fi
    task_order_err=$(<"$err_file")
    if [[ -n "$task_order_err" ]]; then
      log "INFO" "generate-task-order.sh: ${task_order_err}"
    fi
    rm -f "$err_file"
  else
    local exit_code=$?
    task_order_err=$(<"$err_file")
    rm -f "$err_file"
    log_error "generate-task-order.sh failed with exit code ${exit_code}: ${task_order_err}"
    exit 1
  fi

  log "INFO" "Task Order section written"

  # --- Tasks section ---
  printf '\n'
  printf '## Tasks\n'
  printf '\n'

  # Single full-file jq pass: one row per task, already sorted descending by project_number, all
  # fields this loop and generate_task_entry() need. Each task's fields are joined by the ASCII
  # Unit Separator (0x1f) and the WHOLE row is base64-encoded ONCE -- not per field -- so decode
  # is a single subprocess call per task rather than one call per field. This matters: an earlier
  # version of this rewrite base64-encoded each of the 8 text fields separately, which merely
  # traded ~8-12 jq spawns per task for ~8 `base64` spawns per task and left wall time close to
  # unchanged. One base64 spawn per task (101 total, vs. the ~800-1000+ spawns of either the
  # original or that first-draft rewrite) is what actually removes the subprocess-spawn cost.
  #
  # Because decode happens once per row (not per field), the row's internal delimiter never has
  # to survive un-encoded -- it lives entirely inside the base64 blob -- but Unit Separator is
  # still the right choice: it is not in bash's IFS-whitespace class, so splitting the DECODED
  # row with `read` never collapses an empty field (e.g. an unset effort/topic) the way tab or
  # space would (bash's `read` treats those as "IFS whitespace" and silently merges consecutive
  # occurrences, which would shift every field after an empty one left by one position).
  local task_rows
  task_rows=$(jq -r '
    .active_projects
    | sort_by(-.project_number)
    | .[]
    | [
        (.project_number | tostring),
        (.project_name // ""),
        (.title // ""),
        (.status // "not_started"),
        (.task_type // "general"),
        (.topic // ""),
        (.effort // ""),
        (.description // ""),
        ((.dependencies // []) | map(tostring) | join(",")),
        ((.artifacts // []) | map((.type // "unknown") + "|" + (.path // "")) | join("\n")),
        (.held_at // "")
      ]
      | join("\u001f")
      | @base64
  ' "$STATE_FILE")

  local total_count=0
  local active_count=0
  local terminal_count=0
  local first_entry=1

  local b64row decoded
  local -a f

  # Strip ALL trailing newlines from a free-text field in place (nameref, no subprocess). Matches
  # the trailing-newline-stripping behavior of `$(...)` command substitution, which every prior
  # per-field jq extraction (both the original per-task code and this rewrite's own first-draft
  # per-field base64 decode) got for free -- `mapfile -d` does NOT strip anything, so without this
  # a description/effort/etc. field whose raw JSON value happens to end in "\n" would leave a
  # stray blank line in the rendered output that the golden baseline never had.
  _strip_trailing_nl() {
    local -n __ref="$1"
    while [[ "$__ref" == *$'\n' ]]; do
      __ref="${__ref%$'\n'}"
    done
  }

  while IFS= read -r b64row; do
    [[ -z "$b64row" ]] && continue
    # Herestring (`<<<`), not a `printf | base64` pipe -- a pipe forks BOTH sides, a herestring
    # only forks the one external command (base64) still needs. base64 ignores the herestring's
    # own appended trailing newline, so decoding is unaffected.
    decoded=$(base64 -d <<< "$b64row")

    # Split on Unit Separator via `mapfile -d`, NOT `read`. Plain `read` is fundamentally
    # LINE-oriented -- it stops consuming input at the first real newline no matter what IFS is
    # set to, which would silently truncate a multi-line description (and blank every field after
    # it) at its first embedded newline. `mapfile -d $'\x1f'` uses Unit Separator as the record
    # terminator instead of newline, so embedded real newlines inside a field are preserved as
    # literal content rather than treated as a split point. A herestring here (unlike the base64
    # decode above) forks nothing -- `mapfile` is a shell builtin -- at the cost of an extra
    # trailing newline on the LAST field (artifacts_raw), which is harmless: it only ever produces
    # one extra empty "line" in the artifact-grouping loop below, which that loop already skips
    # via its `[[ -z "$apath" ]] && continue` guard.
    mapfile -d $'\x1f' -t f <<< "$decoded"
    local task_num="${f[0]:-}" pname="${f[1]:-}" title="${f[2]:-}" task_status="${f[3]:-}" \
          ttype="${f[4]:-}" topic="${f[5]:-}" effort="${f[6]:-}" description="${f[7]:-}" \
          deps_csv="${f[8]:-}" artifacts_raw="${f[9]:-}" held_at="${f[10]:-}"
    _strip_trailing_nl pname
    _strip_trailing_nl title
    _strip_trailing_nl ttype
    _strip_trailing_nl topic
    _strip_trailing_nl effort
    _strip_trailing_nl description
    _strip_trailing_nl held_at
    [[ -z "$task_num" ]] && continue
    total_count=$((total_count + 1))

    # Decision 7 (intentional, not an oversight): "hold" falls to the `*)` catch-all below and
    # counts as active, not terminal. A held task is non-terminal (a human-initiated pause, not
    # an archival-eligible terminus -- see is_terminal_status()'s own comment in
    # orchestrate-cycle-plan.sh), so counting it active here is correct and this split is left
    # unmodified.
    case "$task_status" in
      completed|abandoned|expanded) terminal_count=$((terminal_count + 1)) ;;
      *) active_count=$((active_count + 1)) ;;
    esac

    # Separator between entries (not before the first)
    if [[ "$first_entry" -eq 0 ]]; then
      printf '\n---\n\n'
    fi
    first_entry=0

    generate_task_entry "$task_num" "$pname" "$title" "$task_status" "$ttype" "$topic" "$effort" \
      "$description" "$deps_csv" "$artifacts_raw" "$held_at"

  done <<< "$task_rows"

  log "INFO" "Tasks section written (total=${total_count} active=${active_count} terminal=${terminal_count})"

  local end_time elapsed
  end_time=$(date +%s)
  elapsed=$((end_time - START_TIME))
  log "OK" "tasks=${total_count} (active=${active_count}, terminal=${terminal_count}) elapsed=${elapsed}s"
}

# ============================================================================
# Main
# ============================================================================

log "START" "state=${STATE_FILE} todo=${TODO_FILE}"

if [[ "$DRY_RUN" -eq 1 ]]; then
  generate_todo
else
  # Atomic write: write to temp file, then mv
  TEMP_FILE=""
  cleanup_temp() {
    if [[ -n "$TEMP_FILE" && -f "$TEMP_FILE" ]]; then
      rm -f "$TEMP_FILE"
    fi
  }
  trap cleanup_temp EXIT

  TEMP_FILE=$(mktemp -p "$(dirname "$TODO_FILE")" "todo.XXXXXX")
  generate_todo > "$TEMP_FILE"
  mv "$TEMP_FILE" "$TODO_FILE"
  TEMP_FILE=""  # Prevent cleanup from removing the now-moved file

  log "WROTE" "${TODO_FILE}"
fi
