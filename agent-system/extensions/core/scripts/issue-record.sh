#!/usr/bin/env bash
# issue-record.sh - The single sanctioned writer for a task's per-task
# specs/{NNN}_{slug}/issues.jsonl capture log.
#
# Usage:
#   issue-record.sh (--task-dir PATH | --task N) --kind issue|win --class CLASS \
#     --severity blocking|costly|minor|none --what-happened "..." \
#     [--phase research|plan|implement|conclusion|other] [--dispatch-seq N] \
#     [--evidence-path PATH] [--cost-value NUM --cost-unit minutes|dispatches|gate_runs] \
#     [--resolution fixed_inline|worked_around|open] \
#     [--suggested-channel fix_now|follow_up_task|agent_system] [--tags-json '{...}'] \
#     [--session SID]
#
# Single responsibility: append exactly one validated JSON line to
# ${TASK_DIR}/issues.jsonl, lazily creating the file on first use, guarded by `flock` on
# ${TASK_DIR}/.issues.lock. See context/formats/issue-log.md for the full field contract,
# the severity scale's admission tests, the 15-class seed enum, and the CAPTURE ONLY
# boundary this script's callers must respect (nothing here surfaces, acts on, or proposes
# anything -- it only appends a line).
#
# `class` IS DELIBERATELY AN OPEN ENUM -- this is the one deliberate divergence from
# system-defect-record.sh's closed-enum-refuses-loudly posture. An unrecognized --class value
# is accepted with a stderr warning and the entry is still appended, so a genuinely new failure
# mode is recordable the first time it is hit rather than only after a schema revision. Do NOT
# "fix" this into a closed enum by analogy to system-defect-record.sh; context/formats/issue-log.md
# documents why explicitly.
#
# Required: --kind, --class, --severity, --what-happened, and exactly one task-resolution form
# (--task-dir or --task). All five are hard requirements: missing or empty refuses with nothing
# written. --class's value is validated leniently (warn, not refuse) against the seed enum below;
# every other closed-set field (--kind, --severity, --phase, --resolution,
# --suggested-channel) refuses loudly on an unrecognized value.
#
# Task-directory resolution mirrors orchestrate-record-decision.sh's discipline exactly:
# --task-dir is used verbatim when absolute, resolved against PROJECT_ROOT when relative; when
# only --task N is given, scripts/lib/task-lookup-lib.sh (task_lookup_entry / task_lookup_dir)
# resolves the task number to its directory (active, then archive, then the active path as a
# last resort). This is NOT done via task-lock.sh -- that is a different, unrelated mutex.
#
# NOT RUNNABLE FROM THE SOURCE STORE: deploy-root-guard.sh (sourced below) fails loudly when
# invoked from agent-system/extensions/core/scripts/. Deploy first (bash
# .claude/scripts/deploy-headless.sh, or the picker's [Reload All]/[Regenerate]), then exercise
# the deployed .claude/scripts/issue-record.sh copy.
#
# Every call site MUST invoke this script non-fatally -- a recording failure must never fail the
# dispatch that attempted it:
#   bash .claude/scripts/issue-record.sh ... >/dev/null 2>&1 || \
#     echo "Note: issue recording failed (non-fatal)" >&2
#
# Exit codes:
#   0 - Appended. stdout: the entry_id of the appended line.
#   1 - Argument/validation error (missing/empty required argument, malformed --tags-json,
#       unresolvable --task number, unresolvable task directory, an unrecognized value for a
#       TRUE closed-set field). Nothing written.
#
# stdout: the entry_id on success. stderr: diagnostics, including the --class leniency warning.

set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: issue-record.sh (--task-dir PATH | --task N) --kind issue|win --class CLASS \
  --severity blocking|costly|minor|none --what-happened "..." \
  [--phase research|plan|implement|conclusion|other] [--dispatch-seq N] \
  [--evidence-path PATH] [--cost-value NUM --cost-unit minutes|dispatches|gate_runs] \
  [--resolution fixed_inline|worked_around|open] \
  [--suggested-channel fix_now|follow_up_task|agent_system] [--tags-json '{...}'] \
  [--session SID]

Required:
  --task-dir PATH / --task N   Exactly one of these resolves the target task directory.
  --kind issue|win             Closed enum.
  --class CLASS                Open/extensible -- see context/formats/issue-log.md's seed enum.
  --severity blocking|costly|minor|none
                                Closed enum -- see the format doc's severity scale.
  --what-happened "..."        Free prose, one paragraph. Required and non-empty.

Optional:
  --phase research|plan|implement|conclusion|other
  --dispatch-seq N              Bare integer.
  --evidence-path PATH
  --cost-value NUM --cost-unit minutes|dispatches|gate_runs
                                 Both or neither -- a lone value or unit refuses.
  --resolution fixed_inline|worked_around|open
  --suggested-channel fix_now|follow_up_task|agent_system
  --tags-json '{...}'           Must parse as a JSON object when present.
  --session SID                 sess_{timestamp}_{random} value.

Exit codes: 0 appended, 1 argument/validation error (nothing written).
See this script's header for the full contract.
USAGE
  exit 1
}

# --- Argument parsing (manual while-loop; unknown argument is a loud failure) ---
task_dir_arg=""
task_arg=""
kind_arg=""
class_arg=""
severity_arg=""
what_happened_arg=""
phase_arg=""
dispatch_seq_arg=""
evidence_path_arg=""
cost_value_arg=""
cost_unit_arg=""
resolution_arg=""
suggested_channel_arg=""
tags_json_arg=""
session_arg=""

if [ $# -eq 0 ]; then
  usage
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --task-dir) task_dir_arg="${2:-}"; shift 2 ;;
    --task) task_arg="${2:-}"; shift 2 ;;
    --kind) kind_arg="${2:-}"; shift 2 ;;
    --class) class_arg="${2:-}"; shift 2 ;;
    --severity) severity_arg="${2:-}"; shift 2 ;;
    --what-happened) what_happened_arg="${2:-}"; shift 2 ;;
    --phase) phase_arg="${2:-}"; shift 2 ;;
    --dispatch-seq) dispatch_seq_arg="${2:-}"; shift 2 ;;
    --evidence-path) evidence_path_arg="${2:-}"; shift 2 ;;
    --cost-value) cost_value_arg="${2:-}"; shift 2 ;;
    --cost-unit) cost_unit_arg="${2:-}"; shift 2 ;;
    --resolution) resolution_arg="${2:-}"; shift 2 ;;
    --suggested-channel) suggested_channel_arg="${2:-}"; shift 2 ;;
    --tags-json) tags_json_arg="${2:-}"; shift 2 ;;
    --session) session_arg="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "error: unknown argument: $1" >&2; usage ;;
  esac
done

# --- Validate required arguments (refuse, nothing written) ---
if [ -z "$task_dir_arg" ] && [ -z "$task_arg" ]; then
  echo "error: exactly one of --task-dir or --task is required" >&2
  usage
fi
if [ -n "$task_dir_arg" ] && [ -n "$task_arg" ]; then
  echo "error: --task-dir and --task are mutually exclusive; pass exactly one" >&2
  usage
fi

if [ -z "$kind_arg" ] || [ -z "$class_arg" ] || [ -z "$severity_arg" ] || [ -z "$what_happened_arg" ]; then
  echo "error: --kind, --class, --severity, and --what-happened are all required" >&2
  usage
fi

# --- Validate --kind against the closed set (fail loudly, write nothing) ---
case "$kind_arg" in
  issue|win) ;;
  *)
    echo "error: invalid --kind '$kind_arg' (must be one of: issue|win)" >&2
    exit 1
    ;;
esac

# --- Validate --severity against the closed set (fail loudly, write nothing) ---
case "$severity_arg" in
  blocking|costly|minor|none) ;;
  *)
    echo "error: invalid --severity '$severity_arg' (must be one of: blocking|costly|minor|none)" >&2
    exit 1
    ;;
esac

# --- Validate --phase against the closed set when present ---
if [ -n "$phase_arg" ]; then
  case "$phase_arg" in
    research|plan|implement|conclusion|other) ;;
    *)
      echo "error: invalid --phase '$phase_arg' (must be one of: research|plan|implement|conclusion|other)" >&2
      exit 1
      ;;
  esac
fi

# --- Validate --resolution against the closed set when present ---
if [ -n "$resolution_arg" ]; then
  case "$resolution_arg" in
    fixed_inline|worked_around|open) ;;
    *)
      echo "error: invalid --resolution '$resolution_arg' (must be one of: fixed_inline|worked_around|open)" >&2
      exit 1
      ;;
  esac
fi

# --- Validate --suggested-channel against the closed set when present ---
if [ -n "$suggested_channel_arg" ]; then
  case "$suggested_channel_arg" in
    fix_now|follow_up_task|agent_system) ;;
    *)
      echo "error: invalid --suggested-channel '$suggested_channel_arg' (must be one of: fix_now|follow_up_task|agent_system)" >&2
      exit 1
      ;;
  esac
fi

# --- Validate --dispatch-seq is a bare integer if given ---
if [ -n "$dispatch_seq_arg" ]; then
  if ! [[ "$dispatch_seq_arg" =~ ^[0-9]+$ ]]; then
    echo "error: --dispatch-seq must be a bare non-negative integer, got: $dispatch_seq_arg" >&2
    exit 1
  fi
fi

# --- Validate --task is a bare integer if given ---
if [ -n "$task_arg" ]; then
  if ! [[ "$task_arg" =~ ^[0-9]+$ ]]; then
    echo "error: --task must be a bare non-negative integer, got: $task_arg" >&2
    exit 1
  fi
fi

# --- Validate --cost-value / --cost-unit: both or neither ---
if [ -n "$cost_value_arg" ] && [ -z "$cost_unit_arg" ]; then
  echo "error: --cost-value was given without --cost-unit; both or neither are required" >&2
  exit 1
fi
if [ -z "$cost_value_arg" ] && [ -n "$cost_unit_arg" ]; then
  echo "error: --cost-unit was given without --cost-value; both or neither are required" >&2
  exit 1
fi
if [ -n "$cost_value_arg" ]; then
  if ! [[ "$cost_value_arg" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "error: --cost-value must be a non-negative number, got: $cost_value_arg" >&2
    exit 1
  fi
  case "$cost_unit_arg" in
    minutes|dispatches|gate_runs) ;;
    *)
      echo "error: invalid --cost-unit '$cost_unit_arg' (must be one of: minutes|dispatches|gate_runs)" >&2
      exit 1
      ;;
  esac
fi

# --- Validate --tags-json parses as a JSON object when present (fail loudly, write nothing) ---
if [ -n "$tags_json_arg" ]; then
  if ! echo "$tags_json_arg" | jq -e 'type == "object"' > /dev/null 2>&1; then
    echo "error: --tags-json is not valid JSON (or not a JSON object): $tags_json_arg" >&2
    exit 1
  fi
fi

# --- Validate --class leniently: warn to stderr and proceed when outside the seed enum. The
#     seed list below is a comment-only convenience copy -- context/formats/issue-log.md is the
#     authoritative source; keep the two in sync by hand. ---
# Seed enum (15 classes; context/formats/issue-log.md is authoritative):
#   design-record defect or ambiguity | gate collision | missing cheap verification tier |
#   vacuous or silent pass | tooling bug or gap | resource/OOM including misdiagnosis |
#   plan scope-hypothesis wrong | planned feature absent |
#   language or module-system gotcha | environment | cross-task ownership/territory |
#   stale deploy or source-store boundary | orchestration defect | stale workaround |
#   cost-forced exclusion or substituted verification
ISSUE_SEED_CLASSES=(
  "design-record defect or ambiguity"
  "gate collision"
  "missing cheap verification tier"
  "vacuous or silent pass"
  "tooling bug or gap"
  "resource/OOM including misdiagnosis"
  "plan scope-hypothesis wrong"
  "planned feature absent"
  "language or module-system gotcha"
  "environment"
  "cross-task ownership/territory"
  "stale deploy or source-store boundary"
  "orchestration defect"
  "stale workaround"
  "cost-forced exclusion or substituted verification"
)
class_known="false"
for seed_class in "${ISSUE_SEED_CLASSES[@]}"; do
  if [ "$class_arg" = "$seed_class" ]; then
    class_known="true"
    break
  fi
done
if [ "$class_known" = "false" ]; then
  echo "warning: --class '$class_arg' is outside the 15-class seed enum (see context/formats/issue-log.md); recording it anyway -- class is deliberately open/extensible" >&2
fi

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
source "${SCRIPT_DIR}/lib/task-lookup-lib.sh"

# --- Resolve the task directory ---
if [ -n "$task_dir_arg" ]; then
  case "$task_dir_arg" in
    /*) TASK_DIR="$task_dir_arg" ;;
    *) TASK_DIR="$PROJECT_ROOT/$task_dir_arg" ;;
  esac
else
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
fi

if [ ! -d "$TASK_DIR" ]; then
  echo "error: resolved task directory does not exist: $TASK_DIR" >&2
  exit 1
fi

ISSUES_FILE="$TASK_DIR/issues.jsonl"
LOCK_FILE="$TASK_DIR/.issues.lock"

# --- Generate entry_id and timestamp (mirrors events-append.sh's event_id construction) ---
timestamp_ms=$(date -u +%s%3N)
random6=$(tr -dc 'a-zA-Z0-9' < /dev/urandom 2>/dev/null | head -c 6 || true)
if [ -z "$random6" ] || [ "${#random6}" -lt 6 ]; then
  # Fallback if /dev/urandom is unavailable or too slow to yield 6 chars
  random6=$(printf '%06x' "$RANDOM$RANDOM" | tail -c 6)
fi
entry_id="iss_${timestamp_ms}_${random6}"
timestamp="$(common_timestamp_iso)"

# --- task_dir written to the entry is always repo-relative ---
case "$TASK_DIR" in
  "$PROJECT_ROOT"/*) task_dir_rel_out="${TASK_DIR#"$PROJECT_ROOT"/}" ;;
  *) task_dir_rel_out="$TASK_DIR" ;;
esac

cost_json='null'
if [ -n "$cost_value_arg" ]; then
  cost_json="$(jq -c -n --argjson value "$cost_value_arg" --arg unit "$cost_unit_arg" '{value: $value, unit: $unit}')"
fi

tags_arg="$tags_json_arg"
if [ -z "$tags_arg" ]; then
  tags_arg='{}'
fi

# --- Build exactly one line via jq -c -n (never string concatenation) ---
line=$(jq -c -n \
  --arg entry_id "$entry_id" \
  --arg timestamp "$timestamp" \
  --arg kind "$kind_arg" \
  --arg class "$class_arg" \
  --arg severity "$severity_arg" \
  --arg phase "$phase_arg" \
  --arg dispatch_seq "$dispatch_seq_arg" \
  --arg what_happened "$what_happened_arg" \
  --arg evidence_path "$evidence_path_arg" \
  --argjson estimated_cost "$cost_json" \
  --arg resolution "$resolution_arg" \
  --arg suggested_channel "$suggested_channel_arg" \
  --argjson tags "$tags_arg" \
  --arg task_dir "$task_dir_rel_out" \
  --arg session_id "$session_arg" \
  '{
    entry_id: $entry_id,
    timestamp: $timestamp,
    kind: $kind,
    class: $class,
    severity: $severity,
    phase: (if $phase == "" then null else $phase end),
    dispatch_seq: (if $dispatch_seq == "" then null else ($dispatch_seq | tonumber) end),
    what_happened: $what_happened,
    evidence_path: (if $evidence_path == "" then null else $evidence_path end),
    estimated_cost: $estimated_cost,
    resolution: (if $resolution == "" then null else $resolution end),
    suggested_channel: (if $suggested_channel == "" then null else $suggested_channel end),
    tags: $tags,
    task_dir: $task_dir,
    session_id: (if $session_id == "" then null else $session_id end)
  }')

# --- Append under flock, lazily creating issues.jsonl on first use ---
(
  flock -x 200
  printf '%s\n' "$line" >> "$ISSUES_FILE"
) 200> "$LOCK_FILE"

echo "$entry_id"
exit 0
