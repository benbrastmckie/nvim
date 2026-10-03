#!/usr/bin/env bash
# orchestrate-record-decision.sh - The single sanctioned writer for a task's
# specs/{NNN}_{slug}/.decisions.json file.
#
# Usage:
#   orchestrate-record-decision.sh --task N --session SID --cycle C \
#     --question "..." --answer "..."
#
# Required:
#   --task N          Bare (unpadded) task/project number.
#   --session SID     sess_{timestamp}_{random} value (the loop's own session id).
#   --cycle C         Bare non-negative integer: the loop cycle during which the question was
#                      asked and answered.
#   --question "..."  The question text exactly as surfaced to AskUserQuestion.
#   --answer "..."    The user's chosen answer (or free-text response).
#
# Single responsibility: append exactly one schema-valid entry to that task's
# specs/{NNN}_{slug}/.decisions.json, per docs/architecture/handoff-schema.md's "Decisions File
# Schema" section -- a bare top-level JSON array, four required fields per entry (question,
# answer, cycle [integer], timestamp [ISO 8601 UTC]). NEVER an object wrapper
# ({"decisions": [...]}) -- that exact shape is the observed failure this script exists to make
# unreachable. Lazily creates the file ([]) on first use. Additive only: existing entries are
# never removed or rewritten by a later append.
#
# Write mechanics follow errors-append.sh's append subcommand exactly: flock -x held across the
# entire read -> merge -> validate-merged-document -> atomic-mv sequence. The document ROOT (not
# a nested key) is what is validated as type == "array" both before merging and after -- a
# pre-existing object-wrapped file is REFUSED, never silently coerced. On any failure the
# pre-existing file is left byte-identical and nothing is written.
#
# Task-directory resolution sources scripts/lib/task-lookup-lib.sh (task_lookup_entry,
# task_lookup_dir) rather than shelling out to task-lock.sh -- this script never acquires or
# releases the task lock itself; .decisions.lock is a dedicated, unrelated mutex (see
# context/standards/orchestrator-runtime-files.md).
#
# NOT RUNNABLE FROM THE SOURCE STORE: deploy-root-guard.sh (sourced below) fails loudly when
# invoked from agent-system/extensions/core/scripts/. Deploy first (bash
# .claude/scripts/deploy-headless.sh, or the picker's [Reload All]/[Regenerate]), then exercise
# the deployed .claude/scripts/orchestrate-record-decision.sh copy.
#
# Call sites invoke this script non-fatally only where the surrounding contract already treats a
# recording failure as non-blocking; skill-orchestrate/SKILL.md's Move 4 treats a nonzero exit as
# a loud failure to surface to the user, since the whole point of this script is that nothing
# else records the answer.
#
# Exit codes:
#   0 - Appended. stdout: the number of entries now in the file (post-append, for caller sanity).
#   1 - Argument/validation error (missing/empty required argument, malformed --task/--cycle,
#       unresolvable task number). Nothing written.
#   2 - The existing .decisions.json fails root-level array-type validation, or the merged
#       document fails post-merge shape validation. Nothing written; the pre-existing file (if
#       any) is left byte-identical.

set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: orchestrate-record-decision.sh --task N --session SID --cycle C \
  --question "..." --answer "..."

Required:
  --task N          Bare (unpadded) task/project number
  --session SID      sess_{timestamp}_{random} value
  --cycle C          Bare non-negative integer loop cycle number
  --question "..."   The question text exactly as surfaced to AskUserQuestion
  --answer "..."     The user's chosen answer (or free-text response)

Exit codes: 0 appended, 1 argument/validation error (nothing written),
2 existing-or-merged-document shape validation failure (nothing written).
See this script's header for the full contract.
USAGE
  exit 1
}

# --- Argument parsing (manual while-loop; unknown argument is a loud failure) ---
task_arg=""
session_arg=""
cycle_arg=""
question_arg=""
answer_arg=""

if [ $# -eq 0 ]; then
  usage
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --task) task_arg="${2:-}"; shift 2 ;;
    --session) session_arg="${2:-}"; shift 2 ;;
    --cycle) cycle_arg="${2:-}"; shift 2 ;;
    --question) question_arg="${2:-}"; shift 2 ;;
    --answer) answer_arg="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "error: unknown argument: $1" >&2; usage ;;
  esac
done

# --- Validate before any work: all five arguments non-empty ---
if [ -z "$task_arg" ] || [ -z "$session_arg" ] || [ -z "$cycle_arg" ] || \
   [ -z "$question_arg" ] || [ -z "$answer_arg" ]; then
  echo "error: --task, --session, --cycle, --question, and --answer are all required" >&2
  usage
fi

if ! [[ "$task_arg" =~ ^[0-9]+$ ]]; then
  echo "error: --task must be a bare non-negative integer, got: $task_arg" >&2
  exit 1
fi

if ! [[ "$cycle_arg" =~ ^[0-9]+$ ]]; then
  echo "error: --cycle must be a bare non-negative integer, got: $cycle_arg" >&2
  exit 1
fi

# Loose sess_ convention check -- not strict enough to reject a valid id (timestamp/random
# segment shapes are not re-validated here), just enough to reject an obviously-wrong value.
if ! [[ "$session_arg" =~ ^sess_ ]]; then
  echo "error: --session does not look like a sess_{timestamp}_{random} id: $session_arg" >&2
  exit 1
fi

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
source "${SCRIPT_DIR}/lib/task-lookup-lib.sh"

STATE_FILE="$PROJECT_ROOT/specs/state.json"
task_entry="$(task_lookup_entry "$task_arg" "$STATE_FILE")"
if [ -z "$task_entry" ]; then
  echo "error: task $task_arg does not resolve to any entry in $STATE_FILE (active or archived)" >&2
  exit 1
fi
project_name="$(echo "$task_entry" | jq -r '.project_name // empty')"
if [ -z "$project_name" ]; then
  echo "error: task $task_arg's state.json entry has no project_name" >&2
  exit 1
fi

task_dir_rel="$(task_lookup_dir "$task_arg" "$project_name" "$PROJECT_ROOT")"
TASK_DIR="$PROJECT_ROOT/$task_dir_rel"
if [ ! -d "$TASK_DIR" ]; then
  echo "error: resolved task directory does not exist: $TASK_DIR" >&2
  exit 1
fi

DECISIONS_FILE="$TASK_DIR/.decisions.json"
LOCK_FILE="$TASK_DIR/.decisions.lock"

# --- Build the entry with jq -c -n (never string concatenation) ---
timestamp="$(common_timestamp_iso)"
record="$(jq -c -n \
  --arg question "$question_arg" \
  --arg answer "$answer_arg" \
  --argjson cycle "$cycle_arg" \
  --arg timestamp "$timestamp" \
  '{question: $question, answer: $answer, cycle: $cycle, timestamp: $timestamp}')"

# --- Append under flock -x, holding the lock across the entire read -> merge -> validate ->
#     mv sequence. Validates the MERGED document's ROOT (not a nested key) before the mv. ---
(
  flock -x 200

  if [ ! -f "$DECISIONS_FILE" ]; then
    printf '%s\n' '[]' > "$DECISIONS_FILE"
  fi

  current="$(cat "$DECISIONS_FILE")"
  if ! echo "$current" | jq -e 'type == "array"' > /dev/null 2>&1; then
    echo "error: $DECISIONS_FILE does not have the expected bare top-level array shape; refusing to write" >&2
    exit 2
  fi

  tmp_file="${DECISIONS_FILE%/*}/.decisions.json.tmp.$$"
  if ! echo "$current" | jq --argjson rec "$record" '. += [$rec]' > "$tmp_file" 2>/dev/null; then
    rm -f "$tmp_file"
    echo "error: failed to build merged .decisions.json document" >&2
    exit 2
  fi

  if ! jq -e '(type == "array") and (length >= 1)' "$tmp_file" > /dev/null 2>&1; then
    rm -f "$tmp_file"
    echo "error: merged document failed shape validation; aborting write" >&2
    exit 2
  fi

  mv "$tmp_file" "$DECISIONS_FILE"
) 200> "$LOCK_FILE"

jq 'length' "$DECISIONS_FILE"
exit 0
