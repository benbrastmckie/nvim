#!/usr/bin/env bash
# dispatch-strand-probe.sh - Read-only monitoring-context consumer of task-lock.sh check's
# `held-live` state: classifies one task's in-flight dispatch as `live` / `stranded` / `unknown`.
#
# WHY THIS SCRIPT EXISTS (see context/patterns/task-lock.md's "`held-live` Interpretation Is
# Context-Dependent, Not Universal" section for the full narrative). `held-live` means "stale
# heartbeat, but the holder's own pid is still alive." During lock ACQUISITION that observation
# correctly means "a live session may be working, do not steal." During dispatch MONITORING the
# SAME observation means the opposite: a live pid with a two-hour-stale heartbeat is the
# signature of a dispatch that ended its turn on an unresolved background wait (see
# bounded-build-waiter.md's symptom 2) and will never heartbeat again, not a healthy one. Nothing
# in the orchestration loop previously read `held-live` this second way -- this script is that
# missing reader, consumed by orchestrate-cycle-postflight.sh, skill-orchestrate/SKILL.md's Move
# 3, and reconcile-task-status.sh's demotion gate.
#
# THE WEAK-EVIDENCE CAVEAT: a live pid is weaker evidence here than it is during acquisition.
# Two independent sessions inside one Claude Code process can share an ancestor `claude` pid
# (`pid_source: ancestor-claude`), so `pid-alive` can be true for an entire orchestrator run
# regardless of whether THIS ONE dispatch is productive. That is exactly why this script never
# acts on the lock term alone.
#
# THE MEASURED CONJUNCTION (never bare staleness): `stranded` iff ALL THREE hold --
#   1. heartbeat staleness: task-lock.sh check's lock_state is `held-live` or `held-stale`
#      (`free`/`held-fresh` mean the heartbeat is not stale at all).
#   2. artifact quiescence: no regular file under the task directory (excluding `.lock/` and
#      `.dispatch/`) has an mtime newer than `now - threshold_min` minutes.
#   3. commit quiescence: zero commits touching the task directory in that same window.
# Two healthy tasks were measured simultaneously `held-live` at heartbeat_age_min=32 and 41
# against a 30-minute threshold, and both completed normally minutes later -- the heartbeat
# pulses at phase and dispatch boundaries, so a long final phase legitimately crosses the
# threshold without being stranded. Staleness alone is therefore never sufficient; this script
# requires simultaneous silence on all three signals before calling a dispatch stranded.
#
# TWO SIGNALS DELIBERATELY REJECTED (not an oversight -- see the plan's Decision 3):
#   (a) A process-descendant walk. The recorded holder pid is commonly a shared ancestor `claude`
#       pid, so descendants cannot be attributed to one dispatch, and name-matching process
#       lookups (`ps | grep`, `pgrep -f`) are forbidden outright by bounded-build-waiter.md Rule
#       2.
#   (b) System load. It is global, not task-attributable, and the measured idle-load tell that
#       helped a human diagnose the live incident was an operator-grade judgement call, not a
#       mechanizable per-task signal.
#
# THRESHOLD AND EXIT CODES ARE task-lock.sh's TO OWN -- never re-derived here. This script calls
# `task-lock.sh check <task_number>` exactly once and parses its output line's TEXT PREFIX
# (free/held-fresh/held-stale/held-live) plus its appended `heartbeat_age_min=`/`threshold_min=`
# fields; it never recomputes TASK_LOCK_STALE_MIN or re-implements session_liveness().
#
# FAIL CLOSED: `check` exit 3 (resolution error), an unreadable/unresolvable task directory, a
# missing `task-lock.sh` collaborator, or any other ambiguity yields `unknown`. `unknown` is
# NEVER `stranded` -- no consumer may treat an ambiguous read as a strand.
#
# Usage: dispatch-strand-probe.sh <task_number> [--task-dir DIR] [--repo-root DIR] [--json]
#   <task_number>   Required. Bare non-negative integer.
#   --task-dir DIR  Use this task directory verbatim (absolute, or relative to the resolved
#                   repo root) instead of resolving it from state.json. The caller already
#                   holding TASK_DIR (orchestrate-cycle-postflight.sh) should always pass this.
#   --repo-root DIR Override repo-root resolution (otherwise derived from this script's own
#                   location, two levels up, mirroring every other scripts/*.sh caller).
#   --json          Accepted for explicit-intent callers; output is already one compact JSON
#                   line on every path, so this flag changes nothing. Never required.
#
# Output: exactly one compact JSON line on stdout:
#   {task, verdict, lock_state, heartbeat_age_min, threshold_min, artifact_age_min,
#    commits_in_window, evidence}
#   `verdict` is one of `live`/`stranded`/`unknown`. `lock_state` is task-lock.sh check's own
#   text prefix (or "unresolved" when check itself could not be run). `heartbeat_age_min` and
#   `threshold_min` are omitted when `lock_state` is `free` (task-lock.sh emits neither field for
#   a free lock). `evidence` is an array of short strings naming which conjunction terms fired.
#
# Exit codes:
#   0 - a verdict was produced (verdicts, including `unknown`, are DATA, not an error -- mirrors
#       orchestrate-cycle-plan.sh's and orchestrate-batch-admit.sh's own convention).
#   2 - usage error (missing/invalid <task_number>, unknown flag) or a missing collaborator
#       (task-lock.sh itself not found alongside this script).
#
# Never mutates anything: no lock acquire/heartbeat/release, no state.json write, no file touch.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=deploy-root-guard.sh
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 2
# shellcheck source=lib/task-lookup-lib.sh
source "${SCRIPT_DIR}/lib/task-lookup-lib.sh"

usage() {
  cat <<'EOF'
Usage: dispatch-strand-probe.sh <task_number> [--task-dir DIR] [--repo-root DIR] [--json]

Read-only probe: classifies one task's dispatch as live/stranded/unknown by combining
task-lock.sh check's heartbeat-staleness signal with artifact and commit quiescence over the
task directory. Emits one compact JSON line on stdout, exit 0 for every verdict. Never mutates
anything.
EOF
}

task_number=""
task_dir_arg=""
repo_root_arg=""

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --task-dir)
      task_dir_arg="${2:-}"
      shift 2
      ;;
    --repo-root)
      repo_root_arg="${2:-}"
      shift 2
      ;;
    --json)
      # No-op: output is already one compact JSON line on every path.
      shift
      ;;
    -*)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [ -n "$task_number" ]; then
        echo "error: unexpected extra argument: $1" >&2
        exit 2
      fi
      task_number="$1"
      shift
      ;;
  esac
done

if [ -z "$task_number" ]; then
  echo "error: <task_number> is required" >&2
  usage >&2
  exit 2
fi
if ! [[ "$task_number" =~ ^[0-9]+$ ]]; then
  echo "error: <task_number> must be a bare non-negative integer, got: $task_number" >&2
  exit 2
fi

if [ -n "$repo_root_arg" ]; then
  PROJECT_ROOT="$repo_root_arg"
else
  PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
fi
if [ -z "$PROJECT_ROOT" ] || [ ! -d "$PROJECT_ROOT" ]; then
  echo "error: could not resolve repo root" >&2
  exit 2
fi

if [ ! -f "${SCRIPT_DIR}/task-lock.sh" ]; then
  echo "error: required collaborator task-lock.sh not found alongside $0" >&2
  exit 2
fi

# --- Resolve the task directory --------------------------------------------------------------
if [ -n "$task_dir_arg" ]; then
  case "$task_dir_arg" in
    /*) TASK_DIR="$task_dir_arg" ;;
    *) TASK_DIR="$PROJECT_ROOT/$task_dir_arg" ;;
  esac
else
  STATE_FILE="$PROJECT_ROOT/specs/state.json"
  task_entry="$(task_lookup_entry "$task_number" "$STATE_FILE" 2>/dev/null)"
  project_name="$(echo "${task_entry:-}" | jq -r '.project_name // empty' 2>/dev/null)"
  if [ -z "$project_name" ]; then
    echo "{\"task\": ${task_number}, \"verdict\": \"unknown\", \"lock_state\": \"unresolved\", \"evidence\": [\"task_dir_unresolved\"]}"
    exit 0
  fi
  task_dir_rel="$(task_lookup_dir "$task_number" "$project_name" "$PROJECT_ROOT" 2>/dev/null)"
  TASK_DIR="$PROJECT_ROOT/$task_dir_rel"
fi

if [ ! -d "$TASK_DIR" ]; then
  echo "{\"task\": ${task_number}, \"verdict\": \"unknown\", \"lock_state\": \"unresolved\", \"evidence\": [\"task_dir_missing\"]}"
  exit 0
fi

# --- Step 1: task-lock.sh check, exactly once -------------------------------------------------
# `if VAR=$(cmd); then ... else rc=$?; fi` rather than a bare assignment: under this script's own
# (unset -e, but callers may source it under -e) invocation discipline, and matching
# reconcile-task-status.sh's demote_stranded_status()/orchestrate-batch-admit.sh's identical
# fix, a bare `lock_check_output=$(cmd); lock_check_exit=$?` is fragile under a caller's `-e` if
# this script is ever sourced rather than exec'd. check's own routine nonzero exits (1 for
# held-fresh/held-live, 2 for held-stale, 3 for a resolution error) are all expected outcomes,
# never environment errors.
lock_check_output=""
lock_check_exit=0
if lock_check_output=$(bash "${SCRIPT_DIR}/task-lock.sh" check "$task_number" 2>&1); then
  lock_check_exit=0
else
  lock_check_exit=$?
fi

# --- Step 2: classify by TEXT PREFIX, never by exit code alone -------------------------------
# held-fresh and held-live BOTH exit 1 (task-lock.sh reuses held-fresh's exit code for held-live
# by design -- see context/patterns/task-lock.md's "Naming and exit-code design" paragraph), so
# the exit code alone cannot distinguish them. Only the output line's leading word can.
lock_state="unknown"
heartbeat_stale=false
case "$lock_check_output" in
  free*)
    lock_state="free"
    heartbeat_stale=false
    ;;
  held-fresh*)
    lock_state="held-fresh"
    heartbeat_stale=false
    ;;
  held-live*)
    lock_state="held-live"
    heartbeat_stale=true
    ;;
  held-stale*)
    lock_state="held-stale"
    heartbeat_stale=true
    ;;
  *)
    lock_state="unresolved"
    heartbeat_stale=false
    ;;
esac
if [ "$lock_check_exit" -eq 3 ]; then
  lock_state="unresolved"
fi

evidence=()
verdict="unknown"
heartbeat_age_min=""
threshold_min=""
artifact_age_min=""
commits_in_window=""

if [ "$lock_state" = "unresolved" ]; then
  evidence+=("lock_check_unresolved")
  verdict="unknown"
elif [ "$heartbeat_stale" = "false" ]; then
  # free or held-fresh: the heartbeat itself is not stale -- live, no quiescence probe needed.
  verdict="live"
  evidence+=("heartbeat_fresh_or_no_lock")
else
  # held-live or held-stale: heartbeat IS stale. Parse the appended fields off the SAME line
  # task-lock.sh already emitted -- never recomputed.
  heartbeat_age_min="$(grep -oE 'heartbeat_age_min=[0-9]+' <<<"$lock_check_output" | head -n1 | cut -d= -f2)"
  threshold_min="$(grep -oE 'threshold_min=[0-9]+' <<<"$lock_check_output" | head -n1 | cut -d= -f2)"
  evidence+=("heartbeat_stale")

  if [ -z "$heartbeat_age_min" ] || [ -z "$threshold_min" ]; then
    # Could not parse the fields task-lock.sh is documented to always append on a stale line --
    # ambiguous. Fail closed.
    verdict="unknown"
    evidence+=("heartbeat_fields_unparseable")
  else
    now_epoch="$(date -u +%s)"
    cutoff_epoch=$(( now_epoch - (threshold_min * 60) ))

    # --- Artifact quiescence: newest mtime of any regular file under TASK_DIR, excluding
    # .lock/ (its holder.json carries the heartbeat itself -- including it would make this term
    # vacuous, since the heartbeat write would always count as "movement") and .dispatch/.
    newest_mtime="$(find "$TASK_DIR" -type f \
      -not -path "${TASK_DIR}/.lock/*" -not -path "${TASK_DIR}/.dispatch/*" \
      -printf '%T@\n' 2>/dev/null | sort -rn | head -n1)"
    newest_mtime="${newest_mtime%.*}"
    artifact_quiescent=true
    if [ -n "$newest_mtime" ]; then
      artifact_age_min=$(( (now_epoch - newest_mtime) / 60 ))
      if [ "$newest_mtime" -ge "$cutoff_epoch" ]; then
        artifact_quiescent=false
      fi
    fi

    # --- Commit quiescence: same `git log --since=@<cutoff>` shape
    # orchestrate-cycle-postflight.sh's stall_suspected block already uses, so the two signals
    # cannot drift into two different notions of "a commit landed."
    commits_in_window="$(git -C "$PROJECT_ROOT" log --oneline --since="@${cutoff_epoch}" -- "$TASK_DIR" 2>/dev/null | grep -c . || true)"
    commits_in_window="${commits_in_window:-0}"
    commit_quiescent=true
    [ "${commits_in_window:-0}" -gt 0 ] 2>/dev/null && commit_quiescent=false

    if [ "$artifact_quiescent" = "true" ]; then
      evidence+=("artifact_quiescent")
    else
      evidence+=("artifact_moved")
    fi
    if [ "$commit_quiescent" = "true" ]; then
      evidence+=("commit_quiescent")
    else
      evidence+=("commit_landed")
    fi

    if [ "$artifact_quiescent" = "true" ] && [ "$commit_quiescent" = "true" ]; then
      verdict="stranded"
    else
      verdict="live"
    fi
  fi
fi

# --- Emit one compact JSON line ---------------------------------------------------------------
evidence_json="$(printf '%s\n' "${evidence[@]}" | jq -R . | jq -sc .)"
jq -nc \
  --argjson task "$task_number" \
  --arg verdict "$verdict" \
  --arg lock_state "$lock_state" \
  --arg heartbeat_age_min "$heartbeat_age_min" \
  --arg threshold_min "$threshold_min" \
  --arg artifact_age_min "$artifact_age_min" \
  --arg commits_in_window "$commits_in_window" \
  --argjson evidence "$evidence_json" \
  '{task: $task, verdict: $verdict, lock_state: $lock_state}
   + (if $heartbeat_age_min == "" then {} else {heartbeat_age_min: ($heartbeat_age_min | tonumber)} end)
   + (if $threshold_min == "" then {} else {threshold_min: ($threshold_min | tonumber)} end)
   + (if $artifact_age_min == "" then {} else {artifact_age_min: ($artifact_age_min | tonumber)} end)
   + (if $commits_in_window == "" then {} else {commits_in_window: ($commits_in_window | tonumber)} end)
   + {evidence: $evidence}'

exit 0
