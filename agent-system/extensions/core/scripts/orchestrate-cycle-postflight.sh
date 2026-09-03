#!/usr/bin/env bash
# orchestrate-cycle-postflight.sh — Per-task postflight composer for /orchestrate (Stage A.4 of
# specs/PATH.md, "The four moves per cycle"). ONE script performing everything the orchestrator
# lead does after a single dispatched agent returns, for BOTH engines (single-task Stage 5 and
# multi-task Stage MT-4 step 1 onward), emitting one compact JSON line. This is the third and
# last of the per-cycle scripts, alongside orchestrate-build-dispatch.sh (pre-dispatch) and
# orchestrate-cycle-plan.sh (dispatch-plan composition).
#
# WHY THIS SCRIPT EXISTS: single-task Stage 5 already applies two gates before trusting
# `.orchestrator-handoff.json` — an mtime staleness gate and a `dispatch_seq` identity gate (the
# only check that can discriminate a woken predecessor's late write, which always carries a
# NEWER mtime and so passes the mtime check looking exactly like an on-time report). Multi-task
# Stage MT-4 step 1 has NEITHER: it trusts the handoff whenever the file exists. Porting the gate
# pair verbatim would still leave two independently-maintained postflight bodies that can drift
# apart on everything else (status transition, artifact linking, completion-claim gating,
# defect recording). This script performs the WHOLE postflight body once, so both engines are
# structurally incapable of disagreeing.
#
# WORK performed, in order (each maps to a lettered item in this task's own dispatch WORK list):
#   (a) Handoff read guarded by the mtime staleness gate (fail-closed 9999999999 default) and the
#       dispatch_seq identity gate.
#   (b) Return-meta recovery via orchestrate-recover-outcome.sh (now dispatch_seq-aware, D2).
#   (c) Phase-count corroboration via skill_corroborate_phase_counts (count-only greps).
#   (d) Writer-contract-aware recording (D1): an absent handoff from a contractual non-writer
#       records no defect; a present-but-stale/mismatched handoff always records, regardless of
#       writer contract.
#   (e) user_decision relay: verdict=ask_user, payload relayed verbatim, status left as-is. This
#       script NEVER asks and NEVER writes .decisions.json.
#   (f) Status transition via skill_postflight_update, with the monotonic-max clamp for forced
#       phases threaded from --force-invoked.
#   (g) Artifact link (same-type supersession) and the artifact-round advance (unconditional on
#       researched; additionally on a forced planned/implemented) — closing the multi-task gap.
#   (h) modified_files vs file_scope excursion advisory — detection only, never a gate.
#   (i) Per-task scoped commit via git-commit-scoped.sh (never a batch commit).
#   (j) Multi-state update and per-task lock release.
#
# MUST NOT (Context Flatness Constraint and gate-integrity invariants):
#   - Read report, plan, summary, or handoff PROSE. Only named-field jq reads and count-only
#     greps against phase headings ever touch those files.
#   - Ever perform a batch commit — every commit is per-task and scoped.
#   - Weaken either the mtime gate or the dispatch_seq gate, or the fail-closed 9999999999
#     sentinel, for any caller.
#   - Ask the user (AskUserQuestion or any equivalent) — user_decision is RELAYED, never resolved
#     here. The lead asks; this script only detects and relays the payload.
#   - Move specs/state.json by any path other than update-task-status.sh / state-write.sh (both
#     reached only through the skill-base.sh helpers this script calls).
#
# Two-engine contract: single-task callers pass --loop-guard-file (the resolved defect/infra
# store is that file); multi-task callers omit it (the resolved store is the derived multi-state
# file, `<dirname STATE_FILE>/.orchestrator-multi-state-<session_id>.json`, matching
# orchestrate-cycle-plan.sh's own derivation exactly). Both stores carry `.detected_defects` with
# the identical entry shape (see skill_orchestrate_append_detected_defect's header in
# scripts/skill-base.sh), so one recording code path serves both.
#
# Dispatch-identity inputs (--dispatch-seq / --dispatch-start-ts): recorded scope decision, not
# in the originating plan's literal flag enumeration — the single-task engine has never persisted
# a per-cycle dispatch_seq/dispatch_start_ts anywhere (only the loop guard's cumulative
# dispatch_seq_counter survives across Bash invocations; the per-cycle minted value and the
# dispatch window start are threaded as orchestrator-turn-local shell variables the lead already
# holds from Stage 4, mint_dispatch_seq() and `date -u +%s`). Multi-task mode, by contrast, DOES
# persist both per-task in the multi-state file (`dispatch_seq[$t]` / `dispatch_start_ts[$t]`,
# Stage MT-1). This script therefore accepts both as OPTIONAL flags — the lead passes them
# explicitly for single-task (it already has the values in hand, exactly as it already does for
# --session/--state-file), and multi-task callers may omit them, in which case this script
# derives them from the multi-state file it already resolved. Whichever source wins, an unset
# dispatch_start_ts fails closed to 9999999999 (never trusts a handoff by default) and an unset
# dispatch_seq degrades to mtime-only discrimination with a named WARN (never a hard failure) —
# identical posture to the two gates' existing behavior and to orchestrate-recover-outcome.sh's
# own D2 addition.
#
# Usage:
#   orchestrate-cycle-postflight.sh <task_number> --session SID --state-file F --phase P \
#     --task-dir DIR --task-type TYPE --agent NAME \
#     [--plan-path PATH] [--cycle-count N] [--transport-error true|false] \
#     [--force-invoked true|false] [--loop-guard-file PATH] [--dispatch-seq N] \
#     [--dispatch-start-ts N] [--command-suffix SUFFIX] [--dry-run]
#
# Output: one compact JSON line on stdout:
#   {task, phase, status, phases_completed, phases_total, verdict, user_decision?, note}
#   verdict ∈ ok|defer|blocked|failed|ask_user
#
# Exit codes: 0 — a decision was printed on stdout, regardless of its verdict (verdicts are data,
# not errors — mirrors orchestrate-cycle-plan.sh's and orchestrate-batch-admit.sh's convention).
# 2 — usage error or a missing required collaborator (jq unavailable, skill-base.sh not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1

usage() {
  cat <<'USAGE'
Usage: orchestrate-cycle-postflight.sh <task_number> --session SID --state-file F --phase P \
         --task-dir DIR --task-type TYPE --agent NAME \
         [--plan-path PATH] [--cycle-count N] [--transport-error true|false] \
         [--force-invoked true|false] [--loop-guard-file PATH] [--dispatch-seq N] \
         [--dispatch-start-ts N] [--command-suffix SUFFIX] [--dry-run]
USAGE
}

# ─── Flag parsing (shape copied from orchestrate-cycle-plan.sh) ────────────────────────────────
task_number=""
session_id=""
state_file_arg=""
phase=""
task_dir_arg=""
plan_path=""
task_type=""
agent_name=""
cycle_count="0"
transport_error="false"
force_invoked="false"
loop_guard_file=""
dispatch_seq_flag=""
dispatch_start_ts_flag=""
command_suffix=""
dry_run="false"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --session) session_id="${2:-}"; shift 2 ;;
    --state-file) state_file_arg="${2:-}"; shift 2 ;;
    --phase) phase="${2:-}"; shift 2 ;;
    --task-dir) task_dir_arg="${2:-}"; shift 2 ;;
    --plan-path) plan_path="${2:-}"; shift 2 ;;
    --task-type) task_type="${2:-}"; shift 2 ;;
    --agent) agent_name="${2:-}"; shift 2 ;;
    --cycle-count) cycle_count="${2:-0}"; shift 2 ;;
    --transport-error) transport_error="${2:-false}"; shift 2 ;;
    --force-invoked) force_invoked="${2:-false}"; shift 2 ;;
    --loop-guard-file) loop_guard_file="${2:-}"; shift 2 ;;
    --dispatch-seq) dispatch_seq_flag="${2:-}"; shift 2 ;;
    --dispatch-start-ts) dispatch_start_ts_flag="${2:-}"; shift 2 ;;
    --command-suffix) command_suffix="${2:-}"; shift 2 ;;
    --dry-run) dry_run="true"; shift ;;
    --help|-h) usage; exit 0 ;;
    --*)
      echo "ERROR: orchestrate-cycle-postflight.sh: unrecognized flag: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [ -z "$task_number" ]; then
        task_number="$1"
      else
        echo "ERROR: orchestrate-cycle-postflight.sh: unexpected extra positional argument: $1" >&2
        usage >&2
        exit 2
      fi
      shift
      ;;
  esac
done

if [ -z "$task_number" ] || [ -z "$session_id" ] || [ -z "$state_file_arg" ] || \
   [ -z "$phase" ] || [ -z "$task_dir_arg" ] || [ -z "$task_type" ] || [ -z "$agent_name" ]; then
  echo "ERROR: orchestrate-cycle-postflight.sh: <task_number>, --session, --state-file, --phase, --task-dir, --task-type, and --agent are all required." >&2
  usage >&2
  exit 2
fi

case "$task_number" in
  ''|*[!0-9]*)
    echo "ERROR: orchestrate-cycle-postflight.sh: '$task_number' is not a non-negative integer task_number." >&2
    exit 2
    ;;
esac

case "$phase" in
  research|plan|implement) ;;
  *)
    echo "ERROR: orchestrate-cycle-postflight.sh: --phase must be one of research|plan|implement, got '$phase'." >&2
    exit 2
    ;;
esac

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: orchestrate-cycle-postflight.sh: jq is not available." >&2
  exit 2
fi

case "$state_file_arg" in
  /*) STATE_FILE="$state_file_arg" ;;
  *) STATE_FILE="$PROJECT_ROOT/$state_file_arg" ;;
esac

case "$task_dir_arg" in
  /*) TASK_DIR="$task_dir_arg" ;;
  *) TASK_DIR="$PROJECT_ROOT/$task_dir_arg" ;;
esac

# shellcheck disable=SC1090
if [ -f ".claude/scripts/skill-base.sh" ]; then
  . .claude/scripts/skill-base.sh
elif [ -f "${PROJECT_ROOT}/.claude/scripts/skill-base.sh" ]; then
  . "${PROJECT_ROOT}/.claude/scripts/skill-base.sh"
elif [ -f "${SCRIPT_DIR}/skill-base.sh" ]; then
  . "${SCRIPT_DIR}/skill-base.sh"
else
  echo "ERROR: orchestrate-cycle-postflight.sh: could not locate skill-base.sh." >&2
  exit 2
fi

# task_number/cycle_count are read AMBIENT by skill_orchestrate_append_detected_defect (matching
# orchestrate-stage5-gates.sh's own contract) — export them into this process's own scope.
export task_number cycle_count

# ─── Multi-state path derivation (byte-identical to orchestrate-cycle-plan.sh) ─────────────────
mt_state_file="$(dirname "$STATE_FILE")/.orchestrator-multi-state-${session_id}.json"

# ─── Resolved defect/infra store: loop guard (single-task) or multi-state file (multi-task) ────
if [ -n "$loop_guard_file" ]; then
  defect_store="$loop_guard_file"
else
  defect_store="$mt_state_file"
fi

if [ ! -f "$defect_store" ]; then
  echo "ERROR: orchestrate-cycle-postflight.sh: resolved defect store not found at $defect_store (loop guard or multi-state file must already exist — it is initialized by the caller before this script ever runs)." >&2
  exit 2
fi

# ─── Dispatch-identity resolution (recorded scope decision — see header) ───────────────────────
if [ -n "$dispatch_start_ts_flag" ]; then
  dispatch_start_ts="$dispatch_start_ts_flag"
elif [ -z "$loop_guard_file" ] && [ -f "$mt_state_file" ]; then
  dispatch_start_ts=$(jq -r --arg t "$task_number" '.dispatch_start_ts[$t] // empty' "$mt_state_file" 2>/dev/null)
fi
dispatch_start_ts="${dispatch_start_ts:-9999999999}"

if [ -n "$dispatch_seq_flag" ]; then
  expected_dispatch_seq="$dispatch_seq_flag"
elif [ -z "$loop_guard_file" ] && [ -f "$mt_state_file" ]; then
  expected_dispatch_seq=$(jq -r --arg t "$task_number" '.dispatch_seq[$t] // empty' "$mt_state_file" 2>/dev/null)
fi
expected_dispatch_seq="${expected_dispatch_seq:-}"

handoff_file="${TASK_DIR}/.orchestrator-handoff.json"
notice_prefix="[orchestrate]"
attributed_path="agent-system/extensions/core/skills/skill-orchestrate/SKILL.md"
detecting_site_prefix="skill-orchestrate/SKILL.md"

# ─── WORK (a): Handoff read guarded by both gates ──────────────────────────────────────────────
handoff_stale=false
if [ -f "$handoff_file" ]; then
  handoff_mtime=$(stat -c %Y "$handoff_file" 2>/dev/null || stat -f %m "$handoff_file" 2>/dev/null || echo 0)
  if [ "$handoff_mtime" -lt "$dispatch_start_ts" ]; then
    handoff_stale=true
    echo "${notice_prefix} ERROR: STALE HANDOFF — $handoff_file has mtime $handoff_mtime, older than this dispatch window ($dispatch_start_ts)." >&2
    echo "${notice_prefix} This dispatch did not write it. Treating as a missing handoff, not a successful read." >&2
    record_result=$(bash "${SCRIPT_DIR}/system-defect-record.sh" \
      --defect-class HANDOFF_STALE_OR_ABSENT \
      --detecting-site "${detecting_site_prefix}:cycle-postflight-stale-handoff" \
      --task "$task_number" --session "$session_id" \
      --message "handoff mtime $handoff_mtime predates this dispatch window ($dispatch_start_ts)" \
      --attributed-path "$attributed_path" \
      2>/dev/null) || echo "Note: system-defect recording failed (non-fatal)" >&2
    skill_orchestrate_append_detected_defect "$defect_store" "$notice_prefix" \
      "HANDOFF_STALE_OR_ABSENT" "$attributed_path" \
      "${detecting_site_prefix}:cycle-postflight-stale-handoff" \
      "handoff mtime $handoff_mtime predates this dispatch window ($dispatch_start_ts)" \
      "$record_result"
  fi
fi

if [ -f "$handoff_file" ] && [ "$handoff_stale" != "true" ]; then
  handoff_dispatch_seq=$(jq -r '.dispatch_seq // empty' "$handoff_file" 2>/dev/null)
  if [ -z "$handoff_dispatch_seq" ]; then
    echo "${notice_prefix} WARN: handoff has no dispatch_seq field — writer predates or omits the dispatch_seq contract; degrading to mtime-only discrimination." >&2
  elif [ -n "$expected_dispatch_seq" ] && [ "$handoff_dispatch_seq" != "$expected_dispatch_seq" ]; then
    handoff_stale=true
    echo "${notice_prefix} ERROR: DISPATCH_SEQ MISMATCH — handoff carries dispatch_seq=$handoff_dispatch_seq, this cycle minted dispatch_seq=${expected_dispatch_seq}. This handoff was NOT written by the current dispatch (a still-live predecessor's late write, or a stale copy) — treating as missing." >&2
    record_result=$(bash "${SCRIPT_DIR}/system-defect-record.sh" \
      --defect-class HANDOFF_STALE_OR_ABSENT \
      --detecting-site "${detecting_site_prefix}:cycle-postflight-dispatch-seq-mismatch" \
      --task "$task_number" --session "$session_id" \
      --message "handoff dispatch_seq=$handoff_dispatch_seq does not match this cycle's minted dispatch_seq=${expected_dispatch_seq}" \
      --attributed-path "$attributed_path" \
      2>/dev/null) || echo "Note: system-defect recording failed (non-fatal)" >&2
    skill_orchestrate_append_detected_defect "$defect_store" "$notice_prefix" \
      "HANDOFF_STALE_OR_ABSENT" "$attributed_path" \
      "${detecting_site_prefix}:cycle-postflight-dispatch-seq-mismatch" \
      "handoff dispatch_seq=$handoff_dispatch_seq does not match this cycle's minted dispatch_seq=${expected_dispatch_seq}" \
      "$record_result"
  elif [ -n "$expected_dispatch_seq" ]; then
    echo "${notice_prefix} dispatch_seq match ($handoff_dispatch_seq) — handoff confirmed as this dispatch's own report." >&2
  fi
fi

# ─── Provisional output (extended by later phases) ─────────────────────────────────────────────
# This is a placeholder emission so the script is runnable end-to-end from Phase 2 on; Phase 3-5
# replace this tail with the full recovery/status/commit/lock pipeline.
if [ -f "$handoff_file" ] && [ "$handoff_stale" != "true" ]; then
  provisional_status=$(jq -r '.status // ""' "$handoff_file" 2>/dev/null)
  provisional_phases_completed=$(jq -r '.phases_completed // 0' "$handoff_file" 2>/dev/null)
  provisional_phases_total=$(jq -r '.phases_total // 0' "$handoff_file" 2>/dev/null)
else
  provisional_status=""
  provisional_phases_completed=0
  provisional_phases_total=0
fi

jq -n -c \
  --argjson task "$task_number" \
  --arg phase "$phase" \
  --arg status "$provisional_status" \
  --argjson phases_completed "$provisional_phases_completed" \
  --argjson phases_total "$provisional_phases_total" \
  --arg verdict "ok" \
  --arg note "PROVISIONAL (Phase 2 of 5) — recovery, status transition, commit, and lock release not yet implemented." \
  '{task: $task, phase: $phase, status: $status, phases_completed: $phases_completed,
    phases_total: $phases_total, verdict: $verdict, note: $note}'

exit 0
