#!/usr/bin/env bash
# orchestrate-churn.sh — Task-directory-scoped churn/three-strikes detector and burnout-signal
# counter for the batch /orchestrate engine, hard mode only.
#
# Purpose (originating plan's Decision 3): single-task Stage 2's churn-state init/resume, Stage
# 5b's H6 churn detection and H5 three-strikes divergence-audit dispatch, and the Stage 3c
# burnout circuit-breaker are ported here as ONE task-directory-scoped script, called from
# `orchestrate-cycle-postflight.sh` only when hard mode is on. Two departures from a literal
# transcription of Stage 5b, both forced by the architecture and both faithful in outcome:
#
#   - Stage 5b's three-strikes branch invokes the Agent tool inline. NO script in this codebase
#     invokes the Agent tool. This script instead RETURNS `audit_requested: true` with `target`
#     and `verbatim_goal`; the caller (`orchestrate-cycle-postflight.sh`) persists that request to
#     the resolved state store, and the NEXT cycle's `orchestrate-cycle-plan.sh` emits a
#     `divergence-audit` aux row carrying the same target and verbatim goal. The dispatch still
#     happens, one cycle later, with the same agent and `orchestrator_mode: false`.
#   - Stage 5b's `phases_completed_before` was captured in single-task Stage 4's H1 branch, a
#     caller-side variable the batch engine has no equivalent of (per-cycle scripts, not a single
#     continuous shell scope). This script instead PERSISTS `phases_completed_last` in
#     `${TASK_DIR}/.orchestrator-churn-state.json` and computes the delta across INVOCATIONS
#     itself. The "skip the check entirely rather than compute a false delta" guard is preserved:
#     an absent `phases_completed_last` (first invocation for this task) skips the churn check
#     for this call, the same unset-vs-zero distinction Stage 5b's own
#     `[ -n "${phases_completed_before+x}" ]` presence check makes — never a `// 0` read here.
#
# Lazy init: Stage 2's churn-state init/resume becomes lazy initialization inside THIS script (via
# `task-lock.sh init-marker`, mirroring Stage 2's own atomic-create-on-lost-race idiom), so no
# separate init call is needed anywhere in the batch path.
#
# Burnout counter: kept in its EXISTING home, `${TASK_DIR}/.orchestrator-loop-guard`'s own
# `burnout_signals_this_session` field (Decision 1 leaves that file's schema and location in
# place) — reached via `--burnout-signal`, never via the churn-state file.
#
# Usage:
#   orchestrate-churn.sh --task-dir DIR --dispatch-status STATUS --blockers JSON \
#     --phases-completed N [--session SID]
#     Detect mode: runs the churn signature check (dispatch_status=partial AND non-empty
#     blockers AND phases_delta==0 against the previous invocation's `phases_completed_last`),
#     updates `${DIR}/.orchestrator-churn-state.json`, and returns an audit REQUEST at the
#     three-strikes threshold. Never invokes the Agent tool.
#
#   orchestrate-churn.sh --burnout-signal DIR
#     Increments `burnout_signals_this_session` in `${DIR}/.orchestrator-loop-guard` and emits the
#     existing `[orchestrate] H-orch: burnout signal detected ...` message verbatim (Stage 3c's
#     own text, ported unchanged).
#
# Output (detect mode), one compact JSON line on stdout:
#   {churn_detected: bool, target: string|null, count: int|null, audit_requested: bool,
#    verbatim_goal: string|null}
# `target`/`count` are non-null whenever `churn_detected` is true (whether or not the three-strikes
# threshold was also reached this call); `verbatim_goal` is non-null only when `audit_requested`
# is true. A first-cycle skip (absent `phases_completed_last`) returns all-false/all-null, exactly
# like a genuine non-churn cycle — the caller does not need to distinguish the two.
#
# Output (--burnout-signal), one compact JSON line on stdout: {burnout_signals_this_session: N}
#
# Exit codes: 0 for any verdict (a verdict is data, not an error — mirrors every other
# orchestrate-*.sh decision script's convention). 2 — usage error or jq unavailable.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage: orchestrate-churn.sh --task-dir DIR --dispatch-status STATUS --blockers JSON \
         --phases-completed N [--session SID]
       orchestrate-churn.sh --burnout-signal DIR
USAGE
}

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: orchestrate-churn.sh: jq is not available." >&2
  exit 2
fi

if [ "${1:-}" = "--burnout-signal" ]; then
  burnout_task_dir="${2:-}"
  if [ -z "$burnout_task_dir" ] || [ "$#" -ne 2 ]; then
    echo "ERROR: orchestrate-churn.sh: usage: orchestrate-churn.sh --burnout-signal DIR" >&2
    exit 2
  fi
  loop_guard_file="${burnout_task_dir}/.orchestrator-loop-guard"
  mkdir -p "$burnout_task_dir"
  base="{}"
  if [ -f "$loop_guard_file" ] && jq empty "$loop_guard_file" 2>/dev/null; then
    base=$(cat "$loop_guard_file")
  fi
  burnout_signals_this_session=$(echo "$base" | jq -r '(.burnout_signals_this_session // 0) + 1')
  printf '%s\n' "$base" | jq -c \
    --argjson count "$burnout_signals_this_session" \
    --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '.burnout_signals_this_session = $count | .last_updated = $updated' \
    > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
  echo "[orchestrate] H-orch: burnout signal detected (session total: $burnout_signals_this_session) — forcing dispatch/escalation, not inline reasoning" >&2
  jq -n -c --argjson c "$burnout_signals_this_session" '{burnout_signals_this_session: $c}'
  exit 0
fi

# ─── Detect mode flag parsing ───────────────────────────────────────────────────────────────────
task_dir=""
dispatch_status=""
blockers_json=""
phases_completed=""
session_id=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --task-dir) task_dir="${2:-}"; shift 2 ;;
    --dispatch-status) dispatch_status="${2:-}"; shift 2 ;;
    --blockers) blockers_json="${2:-}"; shift 2 ;;
    --phases-completed) phases_completed="${2:-}"; shift 2 ;;
    --session) session_id="${2:-}"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *)
      echo "ERROR: orchestrate-churn.sh: unrecognized argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$task_dir" ] || [ -z "$dispatch_status" ] || [ -z "$phases_completed" ]; then
  echo "ERROR: orchestrate-churn.sh: --task-dir, --dispatch-status, and --phases-completed are required." >&2
  usage >&2
  exit 2
fi
case "$phases_completed" in
  ''|*[!0-9]*)
    echo "ERROR: orchestrate-churn.sh: --phases-completed '$phases_completed' is not a non-negative integer." >&2
    exit 2
    ;;
esac
[ -z "$blockers_json" ] && blockers_json="[]"
if ! echo "$blockers_json" | jq empty >/dev/null 2>&1; then
  echo "ERROR: orchestrate-churn.sh: --blockers is not valid JSON." >&2
  exit 2
fi

mkdir -p "$task_dir"
churn_file="${task_dir}/.orchestrator-churn-state.json"

# ─── Lazy init/resume (ported from single-task Stage 2's churn-state init/resume block) ─────────
if [ -f "$churn_file" ] && jq empty "$churn_file" 2>/dev/null; then
  # Observational-only session_id tracking (NEVER a gate — same rationale as the loop guard's own
  # treatment: session_id is regenerated per /orchestrate invocation while this file is designed
  # to survive across conversational turns; the real concurrency guard is task-lock.sh's own
  # acquire/heartbeat/release mutex).
  churn_session_id=$(jq -r '.session_id // ""' "$churn_file")
  if [ -n "$session_id" ] && [ -n "$churn_session_id" ] && [ "$churn_session_id" != "$session_id" ]; then
    echo "[orchestrate] INFO: churn state was last written by a different session_id ('${churn_session_id}' vs current '${session_id}') — expected on conversational resume, not gated." >&2
  fi
else
  # Fresh start: create churn state atomically via init-marker; on a lost race, the resume-read
  # below (unconditional, applies to both branches) naturally picks up the winner's file.
  jq -n --arg sid "$session_id" \
    '{"session_id": $sid, "total_churn": 0, "target_churn": {}, "adversarial_triggers": 0, "audit_dispatches": 0}' \
    | bash "$SCRIPT_DIR/task-lock.sh" init-marker "$churn_file" >/dev/null 2>&1 || true
fi

total_churn=$(jq -r '.total_churn // 0' "$churn_file" 2>/dev/null) || total_churn=0
phases_completed_last=$(jq -r 'if has("phases_completed_last") then .phases_completed_last else empty end' "$churn_file" 2>/dev/null) || phases_completed_last=""

churn_detected="false"
out_target="null"
out_count="null"
audit_requested="false"
out_verbatim_goal="null"

# First-cycle skip: an absent phases_completed_last means there is no prior cycle to diff against
# — skipping (rather than treating it as 0) avoids a false-positive churn signature on this task's
# very first invocation. `phases_completed_last` is still seeded below for the NEXT invocation.
if [ -n "$phases_completed_last" ]; then
  phases_delta=$(( phases_completed - phases_completed_last ))
  has_blockers=$(echo "$blockers_json" | jq 'length > 0' 2>/dev/null) || has_blockers="false"

  if [ "$dispatch_status" = "partial" ] && [ "$has_blockers" = "true" ] && [ "$phases_delta" -eq 0 ]; then
    blocker_target=$(echo "$blockers_json" | jq -r '.[0].target // "unknown"')
    verbatim_goal=$(echo "$blockers_json" | jq -r '.[0].verbatim_goal // ""')
    current_target_churn=$(jq -r --arg target "$blocker_target" '.target_churn[$target] // 0' "$churn_file")
    new_target_churn=$((current_target_churn + 1))
    new_total_churn=$((total_churn + 1))

    jq --arg target "$blocker_target" \
       --argjson count "$new_target_churn" \
       --argjson total "$new_total_churn" \
       --arg sid "$session_id" \
      '.target_churn[$target] = $count | .total_churn = $total | .last_session_id = $sid' \
      "$churn_file" > "${churn_file}.tmp" && mv "${churn_file}.tmp" "$churn_file"

    echo "[orchestrate] H6: Churn detected on '$blocker_target' (count: $new_target_churn)" >&2

    churn_detected="true"
    out_target=$(printf '%s' "$blocker_target" | jq -R .)
    out_count="$new_target_churn"

    if [ "$new_target_churn" -ge 3 ]; then
      echo "[orchestrate] H5: Three-strikes — requesting a divergence audit for '$blocker_target'" >&2
      jq --arg target "$blocker_target" --arg sid "$session_id" \
        '.target_churn[$target] = 0 | .audit_dispatches += 1 | .last_session_id = $sid' \
        "$churn_file" > "${churn_file}.tmp" && mv "${churn_file}.tmp" "$churn_file"
      audit_requested="true"
      out_verbatim_goal=$(printf '%s' "$verbatim_goal" | jq -R .)
    fi
  fi
fi

# Seed/advance phases_completed_last for the NEXT invocation's delta, unconditionally (every call,
# churn-detected or not) — this is ordinary sliding-window bookkeeping, distinct from the churn
# counters above which are touched only on an actual churn signature.
jq --argjson pc "$phases_completed" '.phases_completed_last = $pc' \
  "$churn_file" > "${churn_file}.tmp" && mv "${churn_file}.tmp" "$churn_file"

jq -n -c \
  --argjson churn_detected "$churn_detected" \
  --argjson target "$out_target" \
  --argjson count "$out_count" \
  --argjson audit_requested "$audit_requested" \
  --argjson verbatim_goal "$out_verbatim_goal" \
  '{churn_detected: $churn_detected, target: $target, count: $count,
    audit_requested: $audit_requested, verbatim_goal: $verbatim_goal}'

exit 0
