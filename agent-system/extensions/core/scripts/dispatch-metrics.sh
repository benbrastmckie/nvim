#!/usr/bin/env bash
# dispatch-metrics.sh - The single sanctioned writer for a task's per-task
# specs/{NNN}_{slug}/metrics.jsonl per-dispatch cost-and-timing capture log.
#
# Two modes in one script (sibling shape to issue-record.sh, D1 in the implementation plan this
# script was built against):
#
#   LIVE MODE (default): append one record for the dispatch currently returning.
#     dispatch-metrics.sh (--task-dir PATH | --task N) --phase research|plan|implement|aux|conclusion|other \
#       --agent NAME --outcome completed|partial|blocked|failed|deferred \
#       --dispatch-seq N --dispatch-start-ts EPOCH --session SID \
#       [--cc-session-id UUID] [--phases-completed N] [--phases-total N]
#
#   BACKFILL MODE: derive what is still derivable for an already-completed task and append one
#   record per recovered phase-commit, every record marked backfilled:true.
#     dispatch-metrics.sh --backfill N
#
# Single responsibility: append exactly one validated JSON line per invocation to
# ${TASK_DIR}/metrics.jsonl (lazily created on first use), guarded by `flock` on
# ${TASK_DIR}/.metrics.lock — except --backfill, which may append several lines (one per
# recovered phase-commit), each individually flock-guarded. See
# context/formats/dispatch-metrics.md for the full field contract, the exact transcript join
# procedure, the three named measured traps, the omission-not-zeroing rule, the 30-day retention
# window, and the --backfill marking contract.
#
# OMISSION, NEVER ZEROING: every conditionally-present field (tokens, tool_calls, model,
# gate_runs, commits, churn, transcript, wall_clock_seconds) is DROPPED from the record when its
# underlying figure cannot be determined -- never defaulted to 0 or null. A 0 is a false
# measurement. This is an acceptance-tested property (see scripts/tests/test-dispatch-metrics.sh),
# not a convention a future edit may casually relax.
#
# Required (live mode): exactly one task-resolution form (--task-dir or --task), --phase,
# --agent, --outcome, --dispatch-seq, --session. Missing or empty refuses with nothing written
# (exit 1). --dispatch-start-ts is optional; its absence (or the fail-closed sentinel
# 9999999999) simply omits wall_clock_seconds rather than refusing the whole call.
#
# Task-directory resolution mirrors issue-record.sh's discipline exactly: --task-dir is used
# verbatim when absolute, resolved against PROJECT_ROOT when relative; --task N resolves via
# scripts/lib/task-lookup-lib.sh (task_lookup_entry / task_lookup_dir).
#
# NOT RUNNABLE FROM THE SOURCE STORE: deploy-root-guard.sh (sourced below) fails loudly when
# invoked from agent-system/extensions/core/scripts/. Deploy first (bash
# .claude/scripts/deploy-headless.sh, or the picker's [Reload All]/[Regenerate]), then exercise
# the deployed .claude/scripts/dispatch-metrics.sh copy.
#
# Every call site MUST invoke this script non-fatally -- a recording failure must never fail the
# dispatch that attempted it:
#   bash .claude/scripts/dispatch-metrics.sh ... >/dev/null 2>&1 || \
#     echo "Note: dispatch-metrics recording failed (non-fatal)" >&2
#
# Exit codes:
#   0 - Appended (one or more lines). stdout: the entry_id of the (last) appended line.
#   1 - Argument/validation error (missing/empty required argument, unrecognized closed-set
#       value, unresolvable --task number, unresolvable task directory). Nothing written.
#
# stdout: entry_id(s) on success (one per line). stderr: diagnostics, including every fail-soft
# join note.

set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage (live mode):
  dispatch-metrics.sh (--task-dir PATH | --task N) \
    --phase research|plan|implement|aux|conclusion|other --agent NAME \
    --outcome completed|partial|blocked|failed|deferred \
    --dispatch-seq N --session SID \
    [--dispatch-start-ts EPOCH] [--cc-session-id UUID] \
    [--phases-completed N] [--phases-total N]

Usage (backfill mode):
  dispatch-metrics.sh --backfill N

Required (live mode):
  --task-dir PATH / --task N   Exactly one of these resolves the target task directory.
  --phase ...                   Closed enum.
  --agent NAME                  The dispatched agent's name, verbatim.
  --outcome ...                 Closed enum.
  --dispatch-seq N               Bare integer.
  --session SID                  sess_{timestamp}_{random} value.

Optional (live mode):
  --dispatch-start-ts EPOCH      Bare integer epoch seconds. Absent or the fail-closed sentinel
                                  9999999999 omits wall_clock_seconds rather than refusing.
  --cc-session-id UUID           Falls back to $CLAUDE_CODE_SESSION_ID when omitted.
  --phases-completed N / --phases-total N

Exit codes: 0 appended, 1 argument/validation error (nothing written).
See this script's header for the full contract.
USAGE
  exit 1
}

# --- Argument parsing (manual while-loop; unknown argument is a loud failure) ---
task_dir_arg=""
task_arg=""
phase_arg=""
agent_arg=""
outcome_arg=""
dispatch_seq_arg=""
dispatch_start_ts_arg=""
session_arg=""
cc_session_id_arg=""
phases_completed_arg=""
phases_total_arg=""
backfill_arg=""

if [ $# -eq 0 ]; then
  usage
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --task-dir) task_dir_arg="${2:-}"; shift 2 ;;
    --task) task_arg="${2:-}"; shift 2 ;;
    --phase) phase_arg="${2:-}"; shift 2 ;;
    --agent) agent_arg="${2:-}"; shift 2 ;;
    --outcome) outcome_arg="${2:-}"; shift 2 ;;
    --dispatch-seq) dispatch_seq_arg="${2:-}"; shift 2 ;;
    --dispatch-start-ts) dispatch_start_ts_arg="${2:-}"; shift 2 ;;
    --session) session_arg="${2:-}"; shift 2 ;;
    --cc-session-id) cc_session_id_arg="${2:-}"; shift 2 ;;
    --phases-completed) phases_completed_arg="${2:-}"; shift 2 ;;
    --phases-total) phases_total_arg="${2:-}"; shift 2 ;;
    --backfill) backfill_arg="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "error: unknown argument: $1" >&2; usage ;;
  esac
done

# --- Paths (shared by both modes) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
source "${SCRIPT_DIR}/lib/task-lookup-lib.sh"

# ─── metrics_project_slug <absolute_path> ──────────────────────────────────────────────────────
# Echoes the Claude Code project-directory slug for <absolute_path>: every non-alphanumeric
# character replaced with "-". Confirmed mapping: /home/benjamin/.config/nvim ->
# -home-benjamin--config-nvim. A standalone function (never an inline one-off `sed`) specifically
# so it can carry its own unit test -- see context/formats/dispatch-metrics.md's join procedure.
metrics_project_slug() {
  local path="${1:-}"
  printf '%s' "$path" | sed 's/[^A-Za-z0-9]/-/g'
}

# ─── metrics_append_line <task_dir> <json_line> ────────────────────────────────────────────────
# Appends exactly one line under flock -x, lazily creating metrics.jsonl on first use. Never a
# read-merge-rewrite.
metrics_append_line() {
  local task_dir="$1"
  local line="$2"
  local metrics_file="${task_dir}/metrics.jsonl"
  local lock_file="${task_dir}/.metrics.lock"
  (
    flock -x 200
    printf '%s\n' "$line" >> "$metrics_file"
  ) 200> "$lock_file"
}

# ─── metrics_commits_and_churn <repo_root> <since_epoch> <session_id> ──────────────────────────
# Echoes a JSON object `{commits:{...}|null, churn:{...}|null}` on stdout. Derives the commit set
# via `git log --since="@<since_epoch>" --grep="<session_id>"` over <repo_root>; derives churn via
# `git log --numstat` over that same commit set, summed separately for pathspec `specs/` and
# `':!specs/'`. Both halves are omitted (null) when the git query fails, the repo root is not a
# git tree, or no commits match. Never sums a missing figure as 0.
metrics_commits_and_churn() {
  local repo_root="$1"
  local since_epoch="$2"
  local sess_id="$3"
  local commits_json="null"
  local churn_json="null"

  if ! git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "{\"commits\":null,\"churn\":null}"
    return 0
  fi

  local subjects_raw count
  subjects_raw=""
  count=0
  if [ -n "$sess_id" ] && [ -n "$since_epoch" ] && [ "$since_epoch" != "9999999999" ]; then
    subjects_raw=$(git -C "$repo_root" log --since="@${since_epoch}" --grep="$sess_id" \
      --pretty=format:'%s' 2>/dev/null || true)
  fi
  if [ -n "$subjects_raw" ]; then
    count=$(printf '%s\n' "$subjects_raw" | grep -c '^' || true)
    commits_json=$(printf '%s\n' "$subjects_raw" | jq -R -s -c --argjson n "$count" \
      'split("\n") | map(select(length > 0)) | {count: $n, subjects: .}' 2>/dev/null) || commits_json="null"

    local specs_stat outside_stat
    specs_stat=$(git -C "$repo_root" log --since="@${since_epoch}" --grep="$sess_id" \
      --numstat --pretty=format:'' -- specs/ 2>/dev/null | \
      awk '{a+=$1; r+=$2} END {if (NR>0) printf "%d %d\n", (a?a:0), (r?r:0)}' || true)
    outside_stat=$(git -C "$repo_root" log --since="@${since_epoch}" --grep="$sess_id" \
      --numstat --pretty=format:'' -- . ':!specs/' 2>/dev/null | \
      awk '{a+=$1; r+=$2} END {if (NR>0) printf "%d %d\n", (a?a:0), (r?r:0)}' || true)

    local specs_added=0 specs_removed=0 outside_added=0 outside_removed=0
    if [ -n "$specs_stat" ]; then
      specs_added=$(echo "$specs_stat" | awk '{print $1}')
      specs_removed=$(echo "$specs_stat" | awk '{print $2}')
    fi
    if [ -n "$outside_stat" ]; then
      outside_added=$(echo "$outside_stat" | awk '{print $1}')
      outside_removed=$(echo "$outside_stat" | awk '{print $2}')
    fi
    churn_json=$(jq -c -n \
      --argjson sa "$specs_added" --argjson sr "$specs_removed" \
      --argjson oa "$outside_added" --argjson or "$outside_removed" \
      '{specs: {added: $sa, removed: $sr}, outside_specs: {added: $oa, removed: $or}}')
  fi

  jq -c -n --argjson commits "$commits_json" --argjson churn "$churn_json" \
    '{commits: $commits, churn: $churn}'
}

# ════════════════════════════════════════════════════════════════════════════════════════════
# BACKFILL MODE DISPATCH (Phase 4 replaces this stub body with the real implementation)
# ════════════════════════════════════════════════════════════════════════════════════════════
if [ -n "$backfill_arg" ]; then
  echo "error: --backfill mode is not yet available in this build of dispatch-metrics.sh" >&2
  exit 1
fi

# ════════════════════════════════════════════════════════════════════════════════════════════
# LIVE MODE
# ════════════════════════════════════════════════════════════════════════════════════════════

# --- Validate required arguments (refuse, nothing written) ---
if [ -z "$task_dir_arg" ] && [ -z "$task_arg" ]; then
  echo "error: exactly one of --task-dir or --task is required" >&2
  usage
fi
if [ -n "$task_dir_arg" ] && [ -n "$task_arg" ]; then
  echo "error: --task-dir and --task are mutually exclusive; pass exactly one" >&2
  usage
fi

if [ -z "$phase_arg" ] || [ -z "$agent_arg" ] || [ -z "$outcome_arg" ] || \
   [ -z "$dispatch_seq_arg" ] || [ -z "$session_arg" ]; then
  echo "error: --phase, --agent, --outcome, --dispatch-seq, and --session are all required" >&2
  usage
fi

# --- Validate --phase against the closed set (fail loudly, write nothing) ---
case "$phase_arg" in
  research|plan|implement|aux|conclusion|other) ;;
  *)
    echo "error: invalid --phase '$phase_arg' (must be one of: research|plan|implement|aux|conclusion|other)" >&2
    exit 1
    ;;
esac

# --- Validate --outcome against the closed set (fail loudly, write nothing) ---
case "$outcome_arg" in
  completed|partial|blocked|failed|deferred) ;;
  *)
    echo "error: invalid --outcome '$outcome_arg' (must be one of: completed|partial|blocked|failed|deferred)" >&2
    exit 1
    ;;
esac

# --- Validate --dispatch-seq is a bare integer ---
if ! [[ "$dispatch_seq_arg" =~ ^[0-9]+$ ]]; then
  echo "error: --dispatch-seq must be a bare non-negative integer, got: $dispatch_seq_arg" >&2
  exit 1
fi

# --- Validate --task is a bare integer if given ---
if [ -n "$task_arg" ]; then
  if ! [[ "$task_arg" =~ ^[0-9]+$ ]]; then
    echo "error: --task must be a bare non-negative integer, got: $task_arg" >&2
    exit 1
  fi
fi

# --- Validate --dispatch-start-ts is a bare integer if given (sentinel/empty handled below) ---
if [ -n "$dispatch_start_ts_arg" ] && ! [[ "$dispatch_start_ts_arg" =~ ^[0-9]+$ ]]; then
  echo "error: --dispatch-start-ts must be a bare non-negative integer, got: $dispatch_start_ts_arg" >&2
  exit 1
fi

# --- Validate --phases-completed / --phases-total are bare integers if given ---
if [ -n "$phases_completed_arg" ] && ! [[ "$phases_completed_arg" =~ ^[0-9]+$ ]]; then
  echo "error: --phases-completed must be a bare non-negative integer, got: $phases_completed_arg" >&2
  exit 1
fi
if [ -n "$phases_total_arg" ] && ! [[ "$phases_total_arg" =~ ^[0-9]+$ ]]; then
  echo "error: --phases-total must be a bare non-negative integer, got: $phases_total_arg" >&2
  exit 1
fi

# --- Resolve the task directory (mirrors issue-record.sh exactly) ---
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

# --- task (bare integer) for the record: prefer --task; else derive from TASK_DIR's NNN prefix ---
task_number_out="$task_arg"
if [ -z "$task_number_out" ]; then
  task_number_out=$(basename "$TASK_DIR" | sed -n 's/^0*\([0-9]\+\)_.*/\1/p')
fi

# --- Generate entry_id and timestamp (mirrors issue-record.sh's entry_id construction) ---
timestamp_ms=$(date -u +%s%3N)
random6=$(tr -dc 'a-zA-Z0-9' < /dev/urandom 2>/dev/null | head -c 6 || true)
if [ -z "$random6" ] || [ "${#random6}" -lt 6 ]; then
  random6=$(printf '%06x' "$RANDOM$RANDOM" | tail -c 6)
fi
entry_id="met_${timestamp_ms}_${random6}"
recorded_at="$(common_timestamp_iso)"

# --- wall_clock_seconds: omitted (never negative, never absurd) when dispatch_start_ts is ---
# --- absent or the fail-closed sentinel 9999999999 (Trap (a): this is NOT events.jsonl's ---
# --- duration_seconds, which is the hook script's own 0.2-2.6s runtime, not phase/dispatch ---
# --- duration). ---
wall_clock_seconds_json="null"
if [ -n "$dispatch_start_ts_arg" ] && [ "$dispatch_start_ts_arg" != "9999999999" ]; then
  now_epoch=$(date -u +%s)
  computed=$((now_epoch - dispatch_start_ts_arg))
  if [ "$computed" -ge 0 ]; then
    wall_clock_seconds_json="$computed"
  fi
fi

# --- cc_session_id: --cc-session-id, falling back to $CLAUDE_CODE_SESSION_ID ---
cc_session_id_out="$cc_session_id_arg"
if [ -z "$cc_session_id_out" ]; then
  cc_session_id_out="${CLAUDE_CODE_SESSION_ID:-}"
fi

# --- commits/churn (transcript-free) ---
cc_result=$(metrics_commits_and_churn "$PROJECT_ROOT" "${dispatch_start_ts_arg:-}" "$session_arg")
commits_json=$(echo "$cc_result" | jq -c '.commits')
churn_json=$(echo "$cc_result" | jq -c '.churn')

# --- Transcript join (Phase 3 populates these; absent here means always-omitted until then) ---
model_json="null"
tokens_json="null"
tool_calls_json="null"
gate_runs_json="null"
transcript_json="null"
if command -v metrics_transcript_join >/dev/null 2>&1; then
  join_result=$(metrics_transcript_join "$PROJECT_ROOT" "$cc_session_id_out" "$task_number_out" "$dispatch_seq_arg")
  model_json=$(echo "$join_result" | jq -c '.model')
  tokens_json=$(echo "$join_result" | jq -c '.tokens')
  tool_calls_json=$(echo "$join_result" | jq -c '.tool_calls')
  gate_runs_json=$(echo "$join_result" | jq -c '.gate_runs')
  transcript_json=$(echo "$join_result" | jq -c '.transcript')
fi

phases_completed_json="null"
[ -n "$phases_completed_arg" ] && phases_completed_json="$phases_completed_arg"
phases_total_json="null"
[ -n "$phases_total_arg" ] && phases_total_json="$phases_total_arg"

# --- Build exactly one line via jq -c -n (never string concatenation). Every optional field is ---
# --- DROPPED from the object (via the `+ (if ... then {} else {...} end)` idiom) when its ---
# --- source is null/empty -- never defaulted to 0. Substituting 0 here is a correctness ---
# --- defect, not a style choice. ---
line=$(jq -c -n \
  --arg entry_id "$entry_id" \
  --arg recorded_at "$recorded_at" \
  --argjson task "${task_number_out:-null}" \
  --arg phase "$phase_arg" \
  --arg agent "$agent_arg" \
  --arg outcome "$outcome_arg" \
  --argjson dispatch_seq "$dispatch_seq_arg" \
  --arg session_id "$session_arg" \
  --argjson wall_clock_seconds "$wall_clock_seconds_json" \
  --arg cc_session_id "$cc_session_id_out" \
  --argjson model "$model_json" \
  --argjson tokens "$tokens_json" \
  --argjson tool_calls "$tool_calls_json" \
  --argjson phases_completed "$phases_completed_json" \
  --argjson phases_total "$phases_total_json" \
  --argjson commits "$commits_json" \
  --argjson churn "$churn_json" \
  --argjson gate_runs "$gate_runs_json" \
  --argjson transcript "$transcript_json" \
  '{
    entry_id: $entry_id,
    recorded_at: $recorded_at,
    task: $task,
    phase: $phase,
    agent: $agent,
    outcome: $outcome,
    dispatch_seq: $dispatch_seq,
    session_id: $session_id,
    backfilled: false
  }
  + (if $wall_clock_seconds == null then {} else {wall_clock_seconds: $wall_clock_seconds} end)
  + (if $cc_session_id == "" then {} else {cc_session_id: $cc_session_id} end)
  + (if $model == null then {} else {model: $model} end)
  + (if $tokens == null then {} else {tokens: $tokens} end)
  + (if $tool_calls == null then {} else {tool_calls: $tool_calls} end)
  + (if $phases_completed == null then {} else {phases_completed: $phases_completed} end)
  + (if $phases_total == null then {} else {phases_total: $phases_total} end)
  + (if $commits == null then {} else {commits: $commits} end)
  + (if $churn == null then {} else {churn: $churn} end)
  + (if $gate_runs == null then {} else {gate_runs: $gate_runs} end)
  + (if $transcript == null then {} else {transcript: $transcript} end)
  ')

metrics_append_line "$TASK_DIR" "$line"

echo "$entry_id"
exit 0
