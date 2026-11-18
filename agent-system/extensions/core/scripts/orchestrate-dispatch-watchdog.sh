#!/usr/bin/env bash
# orchestrate-dispatch-watchdog.sh - Bounded watchdog launched BESIDE a cycle's dispatches (same
# Move 2 message, never awaited), so a silent dispatch is detected in minutes rather than only
# once postflight runs after every Move 2 Agent call returns.
#
# WHY THIS SCRIPT EXISTS: skill-orchestrate's Move 3 computes stall_suspected/stranded_suspected
# only after ALL of a cycle's dispatched Agent calls have already returned -- it is wired
# downstream of the exact event (a silent, stranded dispatch) it exists to detect the absence
# of. The detector this script needs already exists (dispatch-strand-probe.sh, a read-only,
# fail-closed classifier of one task's dispatch as live/stranded/unknown); the missing piece was
# an invocation site UPSTREAM of the blocking wait, not a new detector. This script is that
# invocation site: it polls the existing probe, per task, on its own clock, independent of
# whether any dispatch has returned yet.
#
# THE ORCHESTRATOR NEVER AWAITS THIS SCRIPT. It is launched backgrounded (nohup ... &, pid
# captured by the launcher only for a later, non-blocking `kill -0` reap -- never a wait) in the
# SAME Move 2 message as that cycle's Agent calls. Move 3's first act is to read this script's
# durable alert file -- never to wait on this process's own exit. Awaiting a background
# process's completion notification is exactly the detach-then-await-a-notification antipattern
# bounded-build-waiter.md's Canonical Agent-Contract Bullet forbids (lint-agent-contracts.sh
# Check K); this script introduces no such shape because nothing downstream ever blocks on ITS
# exit, only reads the file it may have written.
#
# OBSERVED GUARANTEE (Decision 5): the plan's own open question -- whether a background
# process's exit notification reaches the orchestrator during its blocked turn or only at turn
# end -- is MOOT BY CONSTRUCTION for this script, not merely unobserved. Nothing downstream ever
# consumes this process's own exit or its notification at all (see the paragraph above): Move 3
# reads the alert FILE this process may have written, on its own schedule, independent of
# whether this process has exited yet. There is therefore no notification-timing question left
# to observe for THIS mechanism; the detection-latency guarantee it actually provides is bounded
# instead by --poll-interval (how often the file can be written) and by how soon Move 3 itself
# next runs (same as today, unchanged) -- both measured quantities, neither a notification-
# timing assumption in either direction.
#
# CANONICAL BOUNDED-WAITER IDIOM, CONSUMED NOT RESTATED: this script's own poll loop is bounded
# by exactly the shape bounded-build-waiter.md's "## The Canonical Idiom" names -- an outer
# `timeout N` wrapping a loop, never an unbounded watch. It does not edit that file's own copied
# Canonical Agent-Contract Bullet or Forbidden-Shape Lint Anchor text.
#
# FORBIDDEN SHAPES, NEVER USED: `ps | grep`, `pgrep -f`, or any other process-name lookup.
# dispatch-strand-probe.sh already owns process-identification concerns (and explicitly rejects a
# descendant walk and system load as signals -- see its own header); this script adds nothing on
# top of its verdict.
#
# USAGE:
#   orchestrate-dispatch-watchdog.sh --session SID --alert-file PATH \
#       [--poll-interval SEC] [--outer-bound SEC] [--repo-root DIR] \
#       TASK:DISPATCH_SEQ [TASK:DISPATCH_SEQ ...]
#
#   --session SID       Required. This cycle's orchestrator session id, recorded on every alert
#                        row for traceability.
#   --alert-file PATH    Required. Durable alert sink (JSON Lines, append-only). Relative paths
#                        resolve against the resolved repo root.
#   --poll-interval SEC  Optional. Seconds between probe sweeps. Default 60.
#   --outer-bound SEC    Optional. Hard wall-clock bound for the whole watchdog run. Default
#                        3000 (50 minutes -- comfortably inside a typical cycle's own dispatch
#                        wall-clock, well above the probe's own quiescence thresholds).
#   --repo-root DIR      Optional. Overrides repo-root resolution (mirrors every other
#                        scripts/*.sh caller's convention).
#   TASK:DISPATCH_SEQ    One or more bare task numbers, each paired with the dispatch_seq this
#                        cycle minted for it (colon-separated, no spaces). At least one required.
#
# BEHAVIOR: polls dispatch-strand-probe.sh for every task once per --poll-interval, until EITHER
# a `stranded` verdict is observed for some task (acts on the FIRST one found: writes one alert
# row, prints one loud operator-visible line, and exits 1 naming that task -- it does not keep
# polling the rest of this cycle's tasks once one alert has fired, since a fresh watchdog is
# launched for each cycle's own dispatch set) OR --outer-bound elapses with no stranded verdict
# (exits 0, writes nothing). A `live` or `unknown` verdict for a task is silently not-alerted and
# that task is polled again next sweep. An alert already present in --alert-file for a given
# {task, dispatch_seq} pair is never re-written (idempotent per that key) -- re-checked at each
# sweep in case a sibling process (or a retried watchdog launch) already recorded it.
#
# Exit codes:
#   0 - outer bound reached, or all tasks reached a terminal non-stranded state, with no alert
#       written.
#   1 - a stranded verdict was observed and one alert row was written.
#   2 - usage error (missing --session/--alert-file, malformed TASK:DISPATCH_SEQ, no tasks given,
#       or a missing collaborator script).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=deploy-root-guard.sh
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 2

usage() {
  cat <<'EOF'
Usage: orchestrate-dispatch-watchdog.sh --session SID --alert-file PATH \
    [--poll-interval SEC] [--outer-bound SEC] [--repo-root DIR] \
    TASK:DISPATCH_SEQ [TASK:DISPATCH_SEQ ...]

Bounded watchdog over dispatch-strand-probe.sh, launched beside a cycle's own dispatches (never
awaited). Polls each given task until a stranded verdict is observed (writes one alert row,
exits 1) or --outer-bound elapses (exits 0). Never ps|grep, never pgrep -f.
EOF
}

SESSION_ID=""
ALERT_FILE=""
POLL_INTERVAL=60
OUTER_BOUND=3000
REPO_ROOT_ARG=""
declare -a TASK_PAIRS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --session)
      SESSION_ID="${2:-}"
      shift 2
      ;;
    --alert-file)
      ALERT_FILE="${2:-}"
      shift 2
      ;;
    --poll-interval)
      POLL_INTERVAL="${2:-}"
      shift 2
      ;;
    --outer-bound)
      OUTER_BOUND="${2:-}"
      shift 2
      ;;
    --repo-root)
      REPO_ROOT_ARG="${2:-}"
      shift 2
      ;;
    -*)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      TASK_PAIRS+=("$1")
      shift
      ;;
  esac
done

if [ -z "$SESSION_ID" ]; then
  echo "error: --session is required" >&2
  usage >&2
  exit 2
fi
if [ -z "$ALERT_FILE" ]; then
  echo "error: --alert-file is required" >&2
  usage >&2
  exit 2
fi
if [ "${#TASK_PAIRS[@]}" -eq 0 ]; then
  echo "error: at least one TASK:DISPATCH_SEQ pair is required" >&2
  usage >&2
  exit 2
fi
if ! [[ "$POLL_INTERVAL" =~ ^[0-9]+$ ]] || [ "$POLL_INTERVAL" -le 0 ]; then
  echo "error: --poll-interval must be a positive integer, got: $POLL_INTERVAL" >&2
  exit 2
fi
if ! [[ "$OUTER_BOUND" =~ ^[0-9]+$ ]] || [ "$OUTER_BOUND" -le 0 ]; then
  echo "error: --outer-bound must be a positive integer, got: $OUTER_BOUND" >&2
  exit 2
fi

if [ -n "$REPO_ROOT_ARG" ]; then
  PROJECT_ROOT="$REPO_ROOT_ARG"
else
  PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
fi
if [ -z "$PROJECT_ROOT" ] || [ ! -d "$PROJECT_ROOT" ]; then
  echo "error: could not resolve repo root" >&2
  exit 2
fi

PROBE="${SCRIPT_DIR}/dispatch-strand-probe.sh"
if [ ! -f "$PROBE" ]; then
  echo "error: required collaborator dispatch-strand-probe.sh not found alongside $0" >&2
  exit 2
fi

case "$ALERT_FILE" in
  /*) ;;
  *) ALERT_FILE="$PROJECT_ROOT/$ALERT_FILE" ;;
esac
mkdir -p "$(dirname "$ALERT_FILE")" 2>/dev/null || true

declare -a TASKS=()
declare -A DISPATCH_SEQ_OF=()
for pair in "${TASK_PAIRS[@]}"; do
  if [[ ! "$pair" =~ ^[0-9]+:[0-9]+$ ]]; then
    echo "error: malformed TASK:DISPATCH_SEQ pair: $pair (expected e.g. 610:20)" >&2
    exit 2
  fi
  tnum="${pair%%:*}"
  dseq="${pair##*:}"
  TASKS+=("$tnum")
  DISPATCH_SEQ_OF["$tnum"]="$dseq"
done

# Idempotency: a {task, dispatch_seq} pair already present in the alert file is never
# re-alerted. Checked once at startup (not re-checked mid-run) -- this process is the only
# writer of its own alert rows during its own lifetime, so a race is only possible against a
# PRIOR watchdog's already-completed write, which this startup check already sees.
alert_already_present() {
  local tnum="$1" dseq="$2"
  [ -f "$ALERT_FILE" ] || return 1
  jq -e --argjson t "$tnum" --argjson d "$dseq" \
    'select(.task == $t and .dispatch_seq == $d)' \
    "$ALERT_FILE" >/dev/null 2>&1
}

write_alert() {
  local tnum="$1" dseq="$2" verdict="$3" heartbeat_age="$4" evidence_json="$5"
  local now_iso
  now_iso="$(common_timestamp_iso 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)"
  jq -nc --argjson t "$tnum" --argjson d "$dseq" --arg v "$verdict" \
    --arg hb "$heartbeat_age" --argjson ev "$evidence_json" --arg s "$SESSION_ID" --arg ts "$now_iso" \
    '{task: $t, dispatch_seq: $d, verdict: $v, heartbeat_age_min: ($hb | select(. != "") | tonumber // null), evidence: $ev, session_id: $s, detected_at: $ts}' \
    >> "$ALERT_FILE"
}

# The bounded poll loop itself: an outer `timeout` wrapping a sleep-and-sweep loop, exactly the
# shape bounded-build-waiter.md's Canonical Idiom names (an outer bound on an otherwise-open
# wait), consumed here rather than restated. Run as a single foreground `timeout N ...`
# invocation of THIS SAME SCRIPT re-exec'd in an internal sweep-loop mode, rather than
# reconstructing functions/arrays as a string for a nested `bash -c` -- simpler to read, lint,
# and test than string-interpolating bash source, with identical bounding semantics.
if [ "${_WATCHDOG_INTERNAL_SWEEP_LOOP:-0}" = "1" ]; then
  while true; do
    for tnum in "${TASKS[@]}"; do
      dseq="${DISPATCH_SEQ_OF[$tnum]}"
      if alert_already_present "$tnum" "$dseq"; then
        continue
      fi
      probe_out="$(bash "$PROBE" "$tnum" --repo-root "$PROJECT_ROOT" 2>/dev/null)"
      verdict="$(jq -r '.verdict // "unknown"' <<<"$probe_out" 2>/dev/null)"
      if [ "$verdict" = "stranded" ]; then
        heartbeat_age="$(jq -r '.heartbeat_age_min // ""' <<<"$probe_out" 2>/dev/null)"
        evidence_json="$(jq -c '.evidence // []' <<<"$probe_out" 2>/dev/null)"
        [ -z "$evidence_json" ] && evidence_json="[]"
        write_alert "$tnum" "$dseq" "$verdict" "$heartbeat_age" "$evidence_json"
        echo "WATCHDOG ALERT: task $tnum (dispatch_seq=$dseq) classified STRANDED by dispatch-strand-probe.sh (heartbeat_age_min=${heartbeat_age:-unknown}) -- see $ALERT_FILE" >&2
        exit 1
      fi
    done
    sleep "$POLL_INTERVAL"
  done
fi

export _WATCHDOG_INTERNAL_SWEEP_LOOP=1
timeout "$OUTER_BOUND" bash "${BASH_SOURCE[0]}" --session "$SESSION_ID" --alert-file "$ALERT_FILE" \
  --poll-interval "$POLL_INTERVAL" --outer-bound "$OUTER_BOUND" --repo-root "$PROJECT_ROOT" \
  "${TASK_PAIRS[@]}"
rc=$?

if [ "$rc" -eq 124 ]; then
  echo "orchestrate-dispatch-watchdog.sh: outer bound (${OUTER_BOUND}s) reached with no stranded verdict observed; exiting clean." >&2
  exit 0
fi
exit "$rc"
