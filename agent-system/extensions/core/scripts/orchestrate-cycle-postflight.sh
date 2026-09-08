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
#   (a.0) Stray-handoff sweep (Phase 7 addition — absorbed from the single-task-only
#       orchestrate-stage5-gates.sh so BOTH engines get it; see the "decide and record the
#       reasoning either way" note at this section's own call site for the decision record).
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
#   (k) Hard-mode churn detection (originating plan's Decision 3, item 2 HARD): when --hard,
#       calls orchestrate-churn.sh with this cycle's dispatch_status/blockers/phases_completed and
#       persists an audit REQUEST (never a dispatch) to aux_pending[task] in the resolved state
#       store (`$defect_store` — the same loop-guard-file-or-multi-state-file resolution WORK (d)
#       already uses). Base-mode drift and blocker-research aux signals are recorded the same way,
#       on their own triggers, mutually exclusive with the churn signal by hard_mode. Informational
#       only: none of this changes `verdict`, `halt`, or `infra_exempt_cycle`. The NEXT cycle's
#       orchestrate-cycle-plan.sh turns a recorded aux_pending entry into an `aux_dispatch[]` row.
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
#     [--dispatch-start-ts N] [--command-suffix SUFFIX] [--hard] [--dry-run]
#
# Output: one compact JSON line on stdout:
#   {task, phase, status, phases_completed, phases_total, verdict, user_decision?, halt,
#    infra_exempt_cycle, aux_signal, note}
#   verdict ∈ ok|defer|blocked|failed|ask_user
#   halt: true only when dispatch_status was off-schema (garbage/unrecognized) — the ONE case
#     that still means "stop the whole /orchestrate invocation" (mirrors the single-task engine's
#     historical `EXIT (partial)`). A genuine in-vocabulary verdict="failed"
#     (dispatch_status="failed") leaves halt=false — the task stays in-flight for the next cycle.
#   infra_exempt_cycle: true only when this cycle was exempted from the cycle_count budget by the
#     corroborated infra-failure discrimination (WORK (a)'s recovery-declined branch) — the ONE
#     case where the caller must NOT increment cycle_count. Every other verdict="defer" (partial
#     dispatch, or implemented with the completion-claim gate refused) charges a cycle normally.
#   aux_signal: null, or WORK (k)'s informational record of what (if anything) was persisted to
#     `aux_pending[task]` this cycle — {kind: "divergence-audit", target, verbatim_goal} |
#     {kind: "drift-inspection"} | {kind: "blocker-research", blocker_desc}. Never changes
#     verdict/halt/infra_exempt_cycle; the NEXT cycle's orchestrate-cycle-plan.sh is what actually
#     turns a recorded aux_pending entry into a dispatch.
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
         [--dispatch-start-ts N] [--command-suffix SUFFIX] [--hard] [--dry-run]
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
hard_mode="false"
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
    --hard) hard_mode="true"; shift ;;
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

# is_live: false under --dry-run. Gates EVERY mutating call in this script (defect recording,
# status transition, artifact link, round advance, commit, multi-state update, lock release) —
# per this script's own --dry-run contract ("identical decision output, zero side effects").
# Read-only calls (orchestrate-recover-outcome.sh, skill_corroborate_phase_counts' count-only
# greps) are NOT gated — they never mutate anything regardless of dry_run.
#
# KNOWN, DELIBERATE EXCEPTION: skill_gate_completion_claim (scripts/skill-base.sh) makes its own
# internal, non-fatal, best-effort system-defect-record.sh call in its Case 3/3 refuse branch.
# That call is NOT gated by is_live, because skill_gate_completion_claim is a shared decision
# function this script does not own or duplicate — skipping the call entirely under --dry-run
# would also lose the allow/refuse decision the output JSON's implemented_gate_passed field
# needs. This is a narrow, named, non-blocking side effect (a defect-log entry, not a state
# mutation) and is recorded here rather than silently overreaching into shared code.
is_live() { [ "$dry_run" != "true" ]; }

handoff_file="${TASK_DIR}/.orchestrator-handoff.json"
notice_prefix="[orchestrate]"
attributed_path="agent-system/extensions/core/skills/skill-orchestrate/SKILL.md"
detecting_site_prefix="skill-orchestrate/SKILL.md"

# ─── WORK (a.0): stray-handoff sweep (both engines, by construction) ───────────────────────────
# Historically single-task-only (orchestrate-stage5-gates.sh, called only from single-task
# Stage 5). A mechanism-agnostic backstop for a handoff written outside its task directory (the
# validate-handoff-location.sh PostToolUse hook cannot see a Bash-redirect write). Bounded to two
# exact paths (repo root, specs/), never a recursive find. Decided here, at Phase 7 cutover time
# (the originating dispatch left this as an open "decide and record the reasoning either way"
# question): absorbed into this ONE script rather than either (a) left single-task-only via a
# separate orchestrate-stage5-gates.sh call bolted onto both call sites, or (b) dropped
# entirely for multi-task's sake. Run unconditionally, every call, exactly like the pre-dedup
# inline code and the old orchestrate-stage5-gates.sh's own "always run" placement — never gated
# on handoff_stale, since a stray file sits OUTSIDE handoff_file and this check does not touch
# handoff_file at all.
for stray in "${PROJECT_ROOT}/.orchestrator-handoff.json" "${PROJECT_ROOT}/specs/.orchestrator-handoff.json"; do
  if [ -e "$stray" ]; then
    echo "${notice_prefix} ERROR: STRAY HANDOFF at $stray — a writer produced the handoff outside its task directory." >&2
    echo "${notice_prefix} The correct destination is $handoff_file." >&2
    if is_live; then
      record_result=$(bash "${SCRIPT_DIR}/system-defect-record.sh" \
        --defect-class HANDOFF_MISLOCATED \
        --detecting-site "${detecting_site_prefix}:cycle-postflight-stray-handoff" \
        --task "$task_number" --session "$session_id" \
        --message "stray handoff found at $stray, outside its task directory" \
        --attributed-path "$attributed_path" \
        --extra-detail-json "$(jq -c -n --arg stray "$stray" '{stray_path: $stray}')" \
        2>/dev/null) || echo "Note: system-defect recording failed (non-fatal)" >&2
      skill_orchestrate_append_detected_defect "$defect_store" "$notice_prefix" \
        "HANDOFF_MISLOCATED" "$attributed_path" \
        "${detecting_site_prefix}:cycle-postflight-stray-handoff" \
        "stray handoff found at $stray, outside its task directory" \
        "$record_result"
      mv "$stray" "${TASK_DIR}/.stray-handoff-$(date -u +%s).json" 2>/dev/null \
        && echo "${notice_prefix} Stray moved into ${TASK_DIR}/ for inspection." >&2 \
        || echo "${notice_prefix} WARNING: could not move stray aside; remove it manually before the next cycle." >&2
    else
      echo "${notice_prefix} [dry-run] would record HANDOFF_MISLOCATED and move the stray handoff aside — no write performed." >&2
    fi
  fi
done

# ─── WORK (a): Handoff read guarded by both gates ──────────────────────────────────────────────
handoff_stale=false
if [ -f "$handoff_file" ]; then
  handoff_mtime=$(stat -c %Y "$handoff_file" 2>/dev/null || stat -f %m "$handoff_file" 2>/dev/null || echo 0)
  if [ "$handoff_mtime" -lt "$dispatch_start_ts" ]; then
    handoff_stale=true
    echo "${notice_prefix} ERROR: STALE HANDOFF — $handoff_file has mtime $handoff_mtime, older than this dispatch window ($dispatch_start_ts)." >&2
    echo "${notice_prefix} This dispatch did not write it. Treating as a missing handoff, not a successful read." >&2
    if is_live; then
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
    else
      echo "${notice_prefix} [dry-run] would record HANDOFF_STALE_OR_ABSENT (stale) — no write performed." >&2
    fi
  fi
fi

if [ -f "$handoff_file" ] && [ "$handoff_stale" != "true" ]; then
  handoff_dispatch_seq=$(jq -r '.dispatch_seq // empty' "$handoff_file" 2>/dev/null)
  if [ -z "$handoff_dispatch_seq" ]; then
    echo "${notice_prefix} WARN: handoff has no dispatch_seq field — writer predates or omits the dispatch_seq contract; degrading to mtime-only discrimination." >&2
  elif [ -n "$expected_dispatch_seq" ] && [ "$handoff_dispatch_seq" != "$expected_dispatch_seq" ]; then
    handoff_stale=true
    echo "${notice_prefix} ERROR: DISPATCH_SEQ MISMATCH — handoff carries dispatch_seq=$handoff_dispatch_seq, this cycle minted dispatch_seq=${expected_dispatch_seq}. This handoff was NOT written by the current dispatch (a still-live predecessor's late write, or a stale copy) — treating as missing." >&2
    if is_live; then
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
    else
      echo "${notice_prefix} [dry-run] would record HANDOFF_STALE_OR_ABSENT (dispatch_seq mismatch) — no write performed." >&2
    fi
  elif [ -n "$expected_dispatch_seq" ]; then
    echo "${notice_prefix} dispatch_seq match ($handoff_dispatch_seq) — handoff confirmed as this dispatch's own report." >&2
  fi
fi

# ─── D1: writer-contract allowlist (single site) ───────────────────────────────────────────────
# The complete, closed set of contractual `.orchestrator-handoff.json` writers today — verified by
# reading every core/extension agent's own contract (grep 'formally hard-mode-implement-only').
# An agent name absent from this list is a NON-writer: an absent handoff from it records no
# defect. Widening this list is a one-line edit, here, when a new hard-mode writer is added.
is_contractual_handoff_writer() {
  case "$1" in
    cslib-implementation-hard-agent|lean-implementation-hard-agent) return 0 ;;
    *) return 1 ;;
  esac
}

have_outcome=false
recovered=false
dispatch_status=""
dispatch_summary=""
phases_completed=0
phases_total=0
plan_markers_verified=""
artifact_path=""
artifact_type=""
artifact_summary=""
infra_exempt_cycle=false

if [ -f "$handoff_file" ] && [ "$handoff_stale" != "true" ]; then
  # ─── Handoff-present path ─────────────────────────────────────────────────────────────────────
  handoff=$(cat "$handoff_file")
  dispatch_status=$(echo "$handoff" | jq -r '.status // ""')
  dispatch_summary=$(echo "$handoff" | jq -r '.summary // ""')
  phases_completed=$(echo "$handoff" | jq -r '.phases_completed // 0')
  phases_total=$(echo "$handoff" | jq -r '.phases_total // 0')
  plan_markers_verified=$(echo "$handoff" | jq -r '.plan_markers_verified // "absent"')
  artifact_path=$(echo "$handoff" | jq -r '.artifacts[0].path // ""')
  artifact_type=$(echo "$handoff" | jq -r '.artifacts[0].type // ""')
  artifact_summary=$(echo "$handoff" | jq -r '.artifacts[0].summary // ""')
  echo "${notice_prefix} Dispatch result: $dispatch_status — $dispatch_summary" >&2
  [ "$phases_total" -gt 0 ] && echo "${notice_prefix} Phase progress: $phases_completed/$phases_total" >&2

  # ── WORK (c): evidence corroboration (handoff-present branch), D3/D4 precondition ─────────────
  # phases_total -eq 0 ALONE (not the recovered path's both-zero PHASES_ZERO_ON_SUCCESS signature)
  # — matches skill_gate_completion_claim's own Case 3 precondition exactly.
  if [ "$dispatch_status" = "implemented" ] && [ "$phases_total" -eq 0 ]; then
    corroboration_plan_path="${plan_path:-}"
    if [ -z "$corroboration_plan_path" ]; then
      corroboration_plan_path=$(ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1)
    fi
    cpc_line=$(skill_corroborate_phase_counts "$task_number" "$corroboration_plan_path" "$notice_prefix" "$handoff_file")
    IFS=' ' read -r cpc_a cpc_b cpc_c <<< "$cpc_line"
    phases_completed="${cpc_a#phases_completed=}"
    phases_total="${cpc_b#phases_total=}"
    plan_markers_verified="${cpc_c#plan_markers_verified=}"
  fi

  # ── Advisory ARTIFACTS_SHAPE_MISMATCH probe (handoff-present path) ─────────────────────────────
  artifacts_probe_json=$(bash "${SCRIPT_DIR}/orchestrate-recover-outcome.sh" "$TASK_DIR" "$dispatch_start_ts" 2>/dev/null)
  artifacts_probe_exit=$?
  if [ "$artifacts_probe_exit" -eq 0 ]; then
    artifacts_probe_suspect=$(echo "$artifacts_probe_json" | jq -r '.evidence_suspect // false' 2>/dev/null) || artifacts_probe_suspect=false
    artifacts_probe_reason=$(echo "$artifacts_probe_json" | jq -r '.evidence_reason // "NONE"' 2>/dev/null) || artifacts_probe_reason="NONE"
    if [ "$artifacts_probe_suspect" = "true" ] && [ "$artifacts_probe_reason" = "ARTIFACTS_SHAPE_MISMATCH" ]; then
      echo "${notice_prefix} EVIDENCE: advisory probe over this dispatch's .return-meta.json (handoff-present path) reports a non-empty artifacts array yielding no resolvable path (evidence_reason=ARTIFACTS_SHAPE_MISMATCH) — advisory only; the handoff-derived outcome above is unaffected." >&2
      if is_live; then
        probe_record_result=$(bash "${SCRIPT_DIR}/system-defect-record.sh" \
          --defect-class ARTIFACTS_SHAPE_MISMATCH \
          --detecting-site "${detecting_site_prefix}:cycle-postflight-handoff-present-probe" \
          --task "$task_number" --session "$session_id" \
          --message "advisory probe over .return-meta.json on the handoff-present path found a non-empty artifacts array yielding no path" \
          --attributed-path "$attributed_path" \
          2>/dev/null) || echo "Note: system-defect recording failed (non-fatal)" >&2
        skill_orchestrate_append_detected_defect "$defect_store" "$notice_prefix" \
          "ARTIFACTS_SHAPE_MISMATCH" "$attributed_path" \
          "${detecting_site_prefix}:cycle-postflight-handoff-present-probe" \
          "advisory probe over .return-meta.json on the handoff-present path found a non-empty artifacts array yielding no path" \
          "$probe_record_result"
      else
        echo "${notice_prefix} [dry-run] would record ARTIFACTS_SHAPE_MISMATCH (handoff-present probe) — no write performed." >&2
      fi
    fi
  fi

  have_outcome=true
else
  # ─── WORK (b): return-meta recovery (handoff missing or gated stale) ───────────────────────────
  recover_json=$(bash "${SCRIPT_DIR}/orchestrate-recover-outcome.sh" "$TASK_DIR" "$dispatch_start_ts" "$expected_dispatch_seq" 2>/dev/null)
  recover_exit=$?
  if [ "$recover_exit" -eq 0 ]; then
    recovered=$(echo "$recover_json" | jq -r '.recovered // false' 2>/dev/null) || recovered=false
  else
    recovered=false
  fi

  if [ "$recovered" = "true" ]; then
    dispatch_status=$(echo "$recover_json" | jq -r '.status')
    phases_completed=$(echo "$recover_json" | jq -r '.phases_completed // 0')
    phases_total=$(echo "$recover_json" | jq -r '.phases_total // 0')
    plan_markers_verified="absent"
    artifact_path=$(echo "$recover_json" | jq -r '.artifact_path // ""')
    artifact_type=$(echo "$recover_json" | jq -r '.artifact_type // ""')
    artifact_summary=$(echo "$recover_json" | jq -r '.artifact_summary // ""')
    echo "${notice_prefix} RECOVERY: no handoff written for this dispatch — expected outcome for this phase's writer (base-mode research/plan/implement never write one). .return-meta.json (fresh, within this dispatch window) reports status=${dispatch_status}; recovering the dispatch outcome from it." >&2
    have_outcome=true

    evidence_suspect=$(echo "$recover_json" | jq -r '.evidence_suspect // false' 2>/dev/null) || evidence_suspect=false
    evidence_reason=$(echo "$recover_json" | jq -r '.evidence_reason // "NONE"' 2>/dev/null) || evidence_reason="NONE"
    if [ "$evidence_suspect" = "true" ] && [ "$evidence_reason" = "PHASES_ZERO_ON_SUCCESS" ] && [ "$dispatch_status" = "implemented" ]; then
      corroboration_plan_path="${plan_path:-}"
      if [ -z "$corroboration_plan_path" ]; then
        corroboration_plan_path=$(ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1)
      fi
      cpc_line=$(skill_corroborate_phase_counts "$task_number" "$corroboration_plan_path" "$notice_prefix")
      IFS=' ' read -r cpc_a cpc_b cpc_c <<< "$cpc_line"
      phases_completed="${cpc_a#phases_completed=}"
      phases_total="${cpc_b#phases_total=}"
      plan_markers_verified="${cpc_c#plan_markers_verified=}"
    elif [ "$evidence_suspect" = "true" ] && [ "$evidence_reason" = "ARTIFACTS_SHAPE_MISMATCH" ]; then
      echo "${notice_prefix} EVIDENCE: recovered .return-meta.json reports status=${dispatch_status} with a non-empty artifacts array yielding no resolvable path (evidence_reason=ARTIFACTS_SHAPE_MISMATCH) — this is proof of a shape mismatch (e.g. a bare-string artifacts array), not proof of \"no artifacts\"." >&2
      if is_live; then
        record_result=$(bash "${SCRIPT_DIR}/system-defect-record.sh" \
          --defect-class ARTIFACTS_SHAPE_MISMATCH \
          --detecting-site "${detecting_site_prefix}:cycle-postflight-recovered" \
          --task "$task_number" --session "$session_id" \
          --message "recovered return-meta carried a non-empty artifacts array yielding no path" \
          --attributed-path "$attributed_path" \
          2>/dev/null) || echo "Note: system-defect recording failed (non-fatal)" >&2
        skill_orchestrate_append_detected_defect "$defect_store" "$notice_prefix" \
          "ARTIFACTS_SHAPE_MISMATCH" "$attributed_path" \
          "${detecting_site_prefix}:cycle-postflight-recovered" \
          "recovered return-meta carried a non-empty artifacts array yielding no path" \
          "$record_result"
      else
        echo "${notice_prefix} [dry-run] would record ARTIFACTS_SHAPE_MISMATCH (recovered path) — no write performed." >&2
      fi
    fi
  else
    # ─── WORK (d): writer-contract-aware recording for an ABSENT handoff ─────────────────────────
    # Only reachable here when the handoff was genuinely ABSENT (never for a present-but-stale or
    # present-but-mismatched handoff — those already recorded unconditionally above, before this
    # branch is ever reached, per D1's narrowing).
    if [ ! -f "$handoff_file" ]; then
      if is_contractual_handoff_writer "$agent_name"; then
        echo "${notice_prefix} ERROR: Skill did not write orchestrator handoff (agent '${agent_name}' is a contractual handoff writer)." >&2
        if is_live; then
          record_result=$(bash "${SCRIPT_DIR}/system-defect-record.sh" \
            --defect-class HANDOFF_STALE_OR_ABSENT \
            --detecting-site "${detecting_site_prefix}:cycle-postflight-absent-contractual-writer" \
            --task "$task_number" --session "$session_id" \
            --message "agent '${agent_name}' is a contractual handoff writer but produced no handoff, and return-meta recovery also declined" \
            --attributed-path "$attributed_path" \
            2>/dev/null) || echo "Note: system-defect recording failed (non-fatal)" >&2
          skill_orchestrate_append_detected_defect "$defect_store" "$notice_prefix" \
            "HANDOFF_STALE_OR_ABSENT" "$attributed_path" \
            "${detecting_site_prefix}:cycle-postflight-absent-contractual-writer" \
            "agent '${agent_name}' is a contractual handoff writer but produced no handoff, and return-meta recovery also declined" \
            "$record_result"
        else
          echo "${notice_prefix} [dry-run] would record HANDOFF_STALE_OR_ABSENT (absent, contractual writer) — no write performed." >&2
        fi
      else
        echo "${notice_prefix} WARN: agent name '${agent_name}' is not on the contractual handoff-writer allowlist — treated as a non-writer, no defect recorded for the absent handoff. If '${agent_name}' is a genuine new hard-mode writer, add it to is_contractual_handoff_writer() in this script." >&2
      fi
    fi

    # NOTE: default via `[ -z ] && recover_json_for_status='{}'`, never `"${recover_json:-{}}"` —
    # bash parameter-expansion default-word matching stops at the FIRST unescaped `}`, so that
    # inline idiom silently appends a stray trailing `}` to any non-empty value, corrupting the
    # JSON and forcing this read to fail closed to "unknown" via `2>/dev/null` even when
    # recover_json correctly carried a real status. See skill_orchestrate_propagate_completion's
    # own header comment in scripts/skill-base.sh for the same landmine, documented once there.
    recover_json_for_status="$recover_json"
    [ -z "$recover_json_for_status" ] && recover_json_for_status='{}'
    out_recovered_reported_status=$(echo "$recover_json_for_status" | jq -r '.status // "unknown"' 2>/dev/null) || out_recovered_reported_status="unknown"
    if [ "$out_recovered_reported_status" != "unknown" ]; then
      # Diagnostic only — this does NOT make the outcome "recovered" (have_outcome stays false,
      # so no status transition is ever attempted on the strength of this value alone). It only
      # lets the final output JSON's own `status` field echo what the agent actually reported
      # (e.g. "partial") instead of an uninformative empty string — most useful for WORK (e)'s
      # user_decision relay, where "leave status exactly as the agent left it" reads best as the
      # agent's own reported status, not blank.
      dispatch_status="$out_recovered_reported_status"
      echo "${notice_prefix} .return-meta.json reports status=${out_recovered_reported_status} (not recovered as a successful outcome)." >&2
    fi

    # ── Infra-failure discrimination (single-task: scalar; multi-task: per-task map) ─────────────
    meta_file="${TASK_DIR}/.return-meta.json"
    meta_mtime=$(stat -c %Y "$meta_file" 2>/dev/null || stat -f %m "$meta_file" 2>/dev/null || echo 0)
    if [ "$meta_mtime" -ge "$dispatch_start_ts" ]; then
      meta_touched=true
    else
      meta_touched=false
    fi

    if [ "${transport_error:-false}" = "true" ] && [ "$meta_touched" = "false" ]; then
      if is_live; then
        if [ -n "$loop_guard_file" ]; then
          infra_failures=$(jq -r '.infra_failures // 0' "$defect_store" 2>/dev/null) || infra_failures=0
          infra_failures=$((infra_failures + 1))
          jq --argjson infra "$infra_failures" --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '.infra_failures = $infra | .last_updated = $updated' \
            "$defect_store" > "${defect_store}.tmp" && mv "${defect_store}.tmp" "$defect_store"
        else
          infra_failures=$(jq -r --arg t "$task_number" '.infra_failures[$t] // 0' "$defect_store" 2>/dev/null) || infra_failures=0
          infra_failures=$((infra_failures + 1))
          jq --arg t "$task_number" --argjson infra "$infra_failures" \
            '.infra_failures[$t] = $infra' \
            "$defect_store" > "${defect_store}.tmp" && mv "${defect_store}.tmp" "$defect_store"
        fi
      else
        infra_failures="<dry-run, not incremented>"
      fi
      echo "${notice_prefix} INFRA FAILURE ${infra_failures} — Agent tool transport/API failure with no subagent footprint. Not charged against the cycle budget." >&2
      infra_exempt_cycle=true
    else
      echo "${notice_prefix} Missing handoff charged as a genuine work cycle (transport_error=${transport_error:-false}, meta_touched=${meta_touched})." >&2
    fi

    # ── Phase-marker recovery grep (sanctioned narrow exception, diagnostic only) ─────────────────
    recovery_plan_path="${plan_path:-}"
    if [ -z "$recovery_plan_path" ]; then
      recovery_plan_path=$(ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1)
    fi
    if [ -n "$recovery_plan_path" ] && [ -f "$recovery_plan_path" ]; then
      if [ -f ".claude/scripts/lib/phase-heading-patterns.sh" ]; then
        . .claude/scripts/lib/phase-heading-patterns.sh
      else
        . "${SCRIPT_DIR}/lib/phase-heading-patterns.sh"
      fi
      recovered_completed=$(grep -cE "$PHASE_HEADING_DONE_ERE" "$recovery_plan_path" 2>/dev/null) || recovered_completed=0
      recovered_total=$(grep -cE "$PHASE_HEADING_ERE" "$recovery_plan_path" 2>/dev/null) || recovered_total=0
      if has_nonconforming_phase_headings "$recovery_plan_path"; then
        warn_nonconforming "$recovery_plan_path" "orchestrate-cycle-postflight" || true
        echo "${notice_prefix} RECOVERY: non-conforming phase heading(s) in ${recovery_plan_path} — recovered phase count is unreliable (treated as unknown, not refused)." >&2
      fi
      echo "${notice_prefix} RECOVERY: handoff unusable — plan headings show ${recovered_completed}/${recovered_total} phases closed (COMPLETED or COMPLETED WITH EXCLUSIONS) in ${recovery_plan_path}." >&2
    elif [ -d "${TASK_DIR}/plans" ]; then
      echo "${notice_prefix} RECOVERY: no plan file available — phase progress cannot be recovered this cycle." >&2
    else
      echo "${notice_prefix} RECOVERY: no plans/ directory yet (normal after a research-phase dispatch) — phase progress recovery does not apply this cycle." >&2
    fi
  fi
fi

# ─── WORK (f): status transition, completion-claim gate, completion propagation ────────────────
offschema_dispatch_status=false
implemented_gate_passed="null"
inferred_phase=""

if [ "$force_invoked" = "true" ]; then
  clamp_mode="monotonic-max"
else
  clamp_mode=""
fi

if [ "$have_outcome" = "true" ]; then
  case "$dispatch_status" in
    researched)
      if is_live; then
        skill_postflight_update "$task_number" "research" "$session_id" "$dispatch_status" "" "$TASK_DIR" "$clamp_mode" >&2
      else
        echo "${notice_prefix} [dry-run] would transition task ${task_number} to researched — no write performed." >&2
      fi
      ;;
    planned)
      if is_live; then
        skill_postflight_update "$task_number" "plan" "$session_id" "$dispatch_status" "" "$TASK_DIR" "$clamp_mode" >&2
      else
        echo "${notice_prefix} [dry-run] would transition task ${task_number} to planned — no write performed." >&2
      fi
      ;;
    implemented)
      # skill_gate_completion_claim is a pure decision function (see is_live()'s own header
      # comment for its one KNOWN, DELIBERATE non-gated internal side effect) — always called,
      # even under --dry-run, so implemented_gate_passed is always a real decision in the output.
      if skill_gate_completion_claim "$task_number" "$phases_completed" "$phases_total" \
           "$plan_markers_verified" "$notice_prefix"; then
        implemented_gate_passed=true
        if is_live; then
          skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status" "warn" "$TASK_DIR" "$clamp_mode" >&2
          skill_orchestrate_propagate_completion "$task_number" "$task_type" "$TASK_DIR" \
            "$dispatch_start_ts" "${recover_json:-}" "$notice_prefix" >&2
        else
          echo "${notice_prefix} [dry-run] would transition task ${task_number} to completed and propagate completion_summary/roadmap_items — no write performed." >&2
        fi
      else
        implemented_gate_passed=false
        # Case 3/3 (phases_total==0 AND plan_markers_verified != "true") already recorded inside
        # the gate; re-derive that case here for the caller-side observation log. Case 1 (phases
        # accounting present, incomplete) is an ordinary refuse and is NOT a defect.
        if [ "${phases_total:-0}" -eq 0 ] && [ "${plan_markers_verified:-}" != "true" ]; then
          if is_live; then
            skill_orchestrate_append_detected_defect "$defect_store" "$notice_prefix" \
              "META_MISSING_AFTER_NARRATION" "$attributed_path" \
              "scripts/skill-base.sh:skill_gate_completion_claim" \
              "completion claimed with phases_total=0 and unverified plan markers" ""
          else
            echo "${notice_prefix} [dry-run] would record META_MISSING_AFTER_NARRATION — no write performed." >&2
          fi
        fi
      fi
      ;;
    partial|failed|blocked)
      echo "${notice_prefix} Dispatch status '$dispatch_status' — recognized exception outcome. No state.json transition performed; the task remains at its current in-flight status." >&2
      ;;
    *)
      offschema_dispatch_status=true
      case "$artifact_type" in
        report)  inferred_phase="research" ;;
        plan)    inferred_phase="plan" ;;
        summary) inferred_phase="implement" ;;
        *)       inferred_phase="unknown" ;;
      esac
      offschema_display="${dispatch_status:-<empty>}"
      echo "[OFF-SCHEMA DISPATCH STATUS - '${offschema_display}' is not in the handoff status vocabulary (researched|planned|implemented|needs_research|partial|failed|blocked); the dispatch may have SUCCEEDED but its outcome cannot be trusted or applied]" >&2
      echo "${notice_prefix} ERROR: task ${task_number} outcome carries an off-schema dispatch_status. Inferred phase (from artifacts[0].type, naming only — not a success signal): ${inferred_phase}. Remedy: inspect the handoff/.return-meta.json by hand, then re-run /orchestrate ${task_number}${command_suffix}." >&2
      if is_live; then
        record_result=$(bash "${SCRIPT_DIR}/system-defect-record.sh" \
          --defect-class OFF_SCHEMA_STATUS \
          --detecting-site "${detecting_site_prefix}:cycle-postflight-tier-c" \
          --task "$task_number" --session "$session_id" \
          --message "dispatch_status '${offschema_display}' is off-schema" \
          --attributed-path "$attributed_path" \
          2>/dev/null) || echo "Note: system-defect recording failed (non-fatal)" >&2
        skill_orchestrate_append_detected_defect "$defect_store" "$notice_prefix" \
          "OFF_SCHEMA_STATUS" "$attributed_path" "${detecting_site_prefix}:cycle-postflight-tier-c" \
          "dispatch_status '${offschema_display}' is off-schema" "$record_result"
      else
        echo "${notice_prefix} [dry-run] would record OFF_SCHEMA_STATUS — no write performed." >&2
      fi
      ;;
  esac
fi

# ─── WORK (g): artifact link + artifact-round advance ──────────────────────────────────────────
artifact_linked=false
if [ -n "$artifact_path" ] && [ "$artifact_path" != "null" ]; then
  case "$artifact_type" in
    report)  field_name='**Research**'; next_field='**Plan**' ;;
    plan)    field_name='**Plan**';     next_field='**Description**' ;;
    summary) field_name='**Summary**';  next_field='**Description**' ;;
    *)       field_name='**Summary**';  next_field='**Description**' ;;
  esac
  if is_live; then
    skill_link_artifacts "$task_number" "$artifact_path" "$artifact_type" \
      "$artifact_summary" "$field_name" "$next_field" "$session_id" >&2
  else
    echo "${notice_prefix} [dry-run] would link artifact ${artifact_path} (type=${artifact_type}) — no write performed." >&2
  fi
  artifact_linked=true
fi

do_artifact_round_advance=false
if [ "$dispatch_status" = "researched" ]; then
  do_artifact_round_advance=true
elif [ "$force_invoked" = "true" ] && { [ "$dispatch_status" = "planned" ] || [ "$dispatch_status" = "implemented" ]; }; then
  do_artifact_round_advance=true
fi
if [ "$do_artifact_round_advance" = "true" ]; then
  if is_live; then
    echo "${notice_prefix} Advancing next_artifact_number (dispatch_status=${dispatch_status}, force_invoked=${force_invoked})..." >&2
    bash "${SCRIPT_DIR}/state-write.sh" \
      '(.active_projects[] | select(.project_number == $num)).next_artifact_number =
        ((.active_projects[] | select(.project_number == $num)).next_artifact_number // 1) + 1' \
      --session-id "$session_id" \
      --argjson num "$task_number" \
      || echo "${notice_prefix} WARNING: Failed to advance next_artifact_number (non-blocking)" >&2
  else
    echo "${notice_prefix} [dry-run] would advance next_artifact_number (dispatch_status=${dispatch_status}, force_invoked=${force_invoked}) — no write performed." >&2
  fi
fi

# ─── WORK (h): modified_files vs file_scope excursion advisory (detection only) ────────────────
meta_file="${TASK_DIR}/.return-meta.json"
modified_files_json=$(jq -c '.modified_files // []' "$meta_file" 2>/dev/null) || modified_files_json='[]'
file_scope_json=$(jq -c --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .file_scope // []' "$STATE_FILE" 2>/dev/null) || file_scope_json='[]'
excursions_json='[]'
if [ "$(echo "$file_scope_json" | jq 'length')" -gt 0 ] 2>/dev/null; then
  # NOTE: the `any($fs[]; . as $f | ...)` re-binding is load-bearing, not stylistic — piping `$p`
  # into `startswith(.)` directly (`$p | startswith(.)`) rebinds `.` to `$p` itself for the
  # argument's own evaluation (jq evaluates a builtin's argument against ITS OWN input, i.e. the
  # value just piped in), making `startswith(.)` degenerate to `startswith($p)` — always true.
  # Capturing the generator's value into `$f` before touching `.` sidesteps this entirely.
  excursions_json=$(jq -c -n --argjson mf "$modified_files_json" --argjson fs "$file_scope_json" \
    '[$mf[] | select(. as $p | any($fs[]; . as $f | $p == $f or ($p | startswith($f))) | not)]' 2>/dev/null) || excursions_json='[]'
  excursion_count=$(echo "$excursions_json" | jq 'length' 2>/dev/null) || excursion_count=0
  if [ "$excursion_count" -gt 0 ]; then
    echo "${notice_prefix} ADVISORY: task ${task_number} reported modified_files outside its declared file_scope: $(echo "$excursions_json" | jq -c '.')  (detection only — no gate, no exit-code, no verdict effect)." >&2
  fi
fi

# ─── WORK (e): user_decision relay ──────────────────────────────────────────────────────────────
# Relayed VERBATIM from whichever source carries it, never re-derived or rephrased. Checked here
# (not earlier) so it reflects the SAME .return-meta.json this run already resolved outcome
# fields from — a fresh read would risk a second file open racing a concurrent writer for no
# benefit, since nothing above this point could have changed the file's own user_decision field.
user_decision_json="null"
if [ -f "$handoff_file" ] && [ "$handoff_stale" != "true" ]; then
  hd_ud=$(jq -c '.user_decision // empty' "$handoff_file" 2>/dev/null)
  [ -n "$hd_ud" ] && user_decision_json="$hd_ud"
fi
if [ "$user_decision_json" = "null" ] && [ -f "${TASK_DIR}/.return-meta.json" ]; then
  rm_ud=$(jq -c '.user_decision // empty' "${TASK_DIR}/.return-meta.json" 2>/dev/null)
  [ -n "$rm_ud" ] && user_decision_json="$rm_ud"
fi
if [ "$user_decision_json" != "null" ]; then
  echo "${notice_prefix} USER_DECISION payload present for task ${task_number} — relaying verbatim as verdict=ask_user. Status is left exactly as the agent reported it (${dispatch_status:-<empty>}); this script never asks and never writes .decisions.json." >&2
fi

# ─── Verdict resolution ──────────────────────────────────────────────────────────────────────────
# ask_user takes precedence over every other signal — a pending question is always surfaced,
# regardless of what the status ladder above did with the underlying dispatch_status.
if [ "$user_decision_json" != "null" ]; then
  verdict="ask_user"
elif [ "$offschema_dispatch_status" = "true" ]; then
  verdict="failed"
elif [ "$have_outcome" = "true" ]; then
  case "$dispatch_status" in
    researched|planned) verdict="ok" ;;
    implemented)
      if [ "$implemented_gate_passed" = "true" ]; then verdict="ok"; else verdict="defer"; fi
      ;;
    partial) verdict="defer" ;;
    failed)  verdict="failed" ;;
    blocked) verdict="blocked" ;;
    *)       verdict="failed" ;;
  esac
elif [ "$infra_exempt_cycle" = "true" ]; then
  verdict="defer"
else
  # Genuinely missing handoff, recovery also declined, not an infra-exempt cycle — the historical
  # multi-task fallback ("Add to failed_tasks") applies uniformly to both engines here.
  verdict="failed"
fi

# ─── WORK (k): hard-mode churn detection; base-mode drift and blocker-research aux signals ─────
# Informational only — none of this ever changes verdict/halt/infra_exempt_cycle, and every write
# below targets `$defect_store` (the same loop-guard-file-or-multi-state-file resolution WORK (d)
# already uses), never state.json. `aux_pending[task]` is read and cleared by the NEXT cycle's
# orchestrate-cycle-plan.sh, which turns it into an `aux_dispatch[]` row (Decision 2) — this
# script never dispatches anything itself.
churn_verdict_json="null"
aux_signal_json="null"
if [ "$hard_mode" = "true" ] && [ "$have_outcome" = "true" ] && [ -n "${handoff:-}" ]; then
  # H6/H5 (Decision 3): the churn signature and three-strikes threshold require a genuine
  # handoff (blockers is a handoff-only field) — mirrors single-task Stage 5b's own
  # `[ -n "${handoff:-}" ]` presence gate exactly, never applied on the return-meta recovery path.
  churn_blockers_json=$(echo "$handoff" | jq -c '.blockers // []' 2>/dev/null) || churn_blockers_json="[]"
  if is_live; then
    churn_verdict_json=$(bash "${SCRIPT_DIR}/orchestrate-churn.sh" \
      --task-dir "$TASK_DIR" --dispatch-status "$dispatch_status" \
      --blockers "$churn_blockers_json" --phases-completed "$phases_completed" \
      --session "$session_id") || churn_verdict_json="null"
    churn_audit_requested=$(echo "${churn_verdict_json:-null}" | jq -r '.audit_requested // false' 2>/dev/null) || churn_audit_requested="false"
    if [ "$churn_audit_requested" = "true" ]; then
      churn_target=$(echo "$churn_verdict_json" | jq -r '.target')
      churn_goal=$(echo "$churn_verdict_json" | jq -r '.verbatim_goal')
      jq --arg t "$task_number" --arg target "$churn_target" --arg goal "$churn_goal" \
        '.aux_pending[$t] = {kind: "divergence-audit", target: $target, verbatim_goal: $goal}' \
        "$defect_store" > "${defect_store}.tmp" && mv "${defect_store}.tmp" "$defect_store"
      aux_signal_json=$(jq -n -c --arg target "$churn_target" --arg goal "$churn_goal" \
        '{kind: "divergence-audit", target: $target, verbatim_goal: $goal}')
      echo "${notice_prefix} H5: divergence-audit REQUESTED for task ${task_number} target '${churn_target}' — the next cycle's orchestrate-cycle-plan.sh will emit the aux_dispatch[] row." >&2
    fi
  else
    echo "${notice_prefix} [dry-run] would call orchestrate-churn.sh for task ${task_number} — no write performed." >&2
  fi
elif [ "$hard_mode" != "true" ] && [ "$dispatch_status" = "partial" ] && [ "$phases_total" -gt 0 ]; then
  # Base-mode drift signal (Decision 2): mutually exclusive with the divergence-audit branch
  # above by construction (hard_mode is a single flag for the whole cycle-plan invocation, so
  # exactly one of the two `if`/`elif` arms above can ever fire for a given cycle).
  drift_pct_x100=$(( phases_completed * 10000 / phases_total ))
  if [ "$drift_pct_x100" -lt 7000 ]; then
    if is_live; then
      jq --arg t "$task_number" \
        '.aux_pending[$t] = {kind: "drift-inspection"}' \
        "$defect_store" > "${defect_store}.tmp" && mv "${defect_store}.tmp" "$defect_store"
      aux_signal_json='{"kind":"drift-inspection"}'
      echo "${notice_prefix} Drift signal recorded for task ${task_number} (${phases_completed}/${phases_total} phases, below the 70% threshold) — the next cycle's orchestrate-cycle-plan.sh will emit the aux_dispatch[] row." >&2
    else
      echo "${notice_prefix} [dry-run] would record a drift-inspection aux signal for task ${task_number} — no write performed." >&2
    fi
  fi
fi

if [ "$verdict" = "blocked" ]; then
  # Blocker-research aux signal: unconditional on hard_mode (single-task Stage 6's own Blocker
  # Escalation handler applies in either mode) — naturally disjoint from both branches above since
  # dispatch_status="blocked" can never also be "partial".
  blocker_desc=$(jq -r --argjson num "$task_number" \
    '.active_projects[] | select(.project_number == $num) | .blockers // "Unspecified blocker"' \
    "$STATE_FILE" 2>/dev/null) || blocker_desc="Unspecified blocker"
  if is_live; then
    jq --arg t "$task_number" --arg d "$blocker_desc" \
      '.aux_pending[$t] = {kind: "blocker-research", blocker_desc: $d}' \
      "$defect_store" > "${defect_store}.tmp" && mv "${defect_store}.tmp" "$defect_store"
    aux_signal_json=$(jq -n -c --arg d "$blocker_desc" '{kind: "blocker-research", blocker_desc: $d}')
    echo "${notice_prefix} Blocker-research signal recorded for task ${task_number} — the next cycle's orchestrate-cycle-plan.sh will emit the aux_dispatch[] row." >&2
  else
    echo "${notice_prefix} [dry-run] would record a blocker-research aux signal for task ${task_number} — no write performed." >&2
  fi
fi

# ─── WORK (i): per-task scoped commit ───────────────────────────────────────────────────────────
if is_live; then
  stage_paths=("${TASK_DIR}/" "$(dirname "$STATE_FILE")/TODO.md" "$STATE_FILE")
  [ -n "${plan_path:-}" ] && [ "$phase" = "implement" ] && stage_paths+=("$plan_path")
  meta_file="${TASK_DIR}/.return-meta.json"
  modified_count=0
  while IFS= read -r f; do
    if [ -n "$f" ]; then
      stage_paths+=("$f")
      modified_count=$((modified_count + 1))
    fi
  done < <(jq -r '.modified_files[]? // empty' "$meta_file" 2>/dev/null)

  if [ "$modified_count" -eq 0 ]; then
    echo "[postflight] WARNING: no modified_files reported for task #${task_number}; source-file changes NOT committed automatically. Review and commit manually." >&2
  fi

  case "$dispatch_status" in
    researched) commit_message="task ${task_number}: complete research" ;;
    planned)    commit_message="task ${task_number}: create implementation plan" ;;
    implemented)
      if [ "$implemented_gate_passed" = "true" ]; then
        commit_message="task ${task_number}: complete implementation"
      else
        commit_message="task ${task_number}: orchestration paused (cycle ${cycle_count})"
      fi
      ;;
    partial) commit_message="task ${task_number}: orchestration paused (cycle ${cycle_count})" ;;
    failed|blocked) commit_message="task ${task_number}: orchestration dispatch ${dispatch_status}" ;;
    *) commit_message="task ${task_number}: orchestration dispatch off-schema" ;;
  esac

  # Redirected to stderr: git-commit-scoped.sh prints its own commit summary to STDOUT, which
  # would otherwise corrupt this script's own single-JSON-line stdout contract (every caller of
  # this script parses stdout as exactly one JSON object).
  bash "${SCRIPT_DIR}/git-commit-scoped.sh" \
    --message "$commit_message" \
    --session "$session_id" \
    --honest-index-rows "$task_number" \
    -- "${stage_paths[@]}" >&2 \
    || echo "${notice_prefix} WARNING: commit failed for task ${task_number} (non-blocking) — proceeding to lock release." >&2
else
  echo "${notice_prefix} [dry-run] would commit task ${task_number}'s changes — no commit performed." >&2
fi

# ─── WORK (j): multi-state update and per-task lock release (multi-task engine only) ───────────
# Single-task callers (--loop-guard-file given) hold the task lock across the WHOLE invocation,
# releasing it once at the outer command-gate-out.sh boundary this per-cycle script does not
# own, and have no "multi-state" bookkeeping at all (current_statuses/completed_tasks/failed_tasks
# are inherently multi-task concepts — there is only ever one task in single-task mode). Both
# steps below are therefore scoped to the multi-task engine (loop_guard_file empty) only.
if [ -z "$loop_guard_file" ]; then
  if is_live; then
    fresh_status=$(jq -r --argjson num "$task_number" \
      '.active_projects[] | select(.project_number == $num) | .status // ""' "$STATE_FILE" 2>/dev/null)
    jq --arg t "$task_number" --arg fs "${fresh_status:-}" \
      '.current_statuses[$t] = $fs' \
      "$mt_state_file" > "${mt_state_file}.tmp" && mv "${mt_state_file}.tmp" "$mt_state_file"

    if [ "$fresh_status" = "completed" ]; then
      jq --argjson t "$task_number" '.completed_tasks = ((.completed_tasks // []) + [$t] | unique)' \
        "$mt_state_file" > "${mt_state_file}.tmp" && mv "${mt_state_file}.tmp" "$mt_state_file"
    fi
    if [ "$dispatch_status" = "failed" ] || [ "$dispatch_status" = "blocked" ] || [ "$offschema_dispatch_status" = "true" ]; then
      jq --argjson t "$task_number" '.failed_tasks = ((.failed_tasks // []) + [$t] | unique)' \
        "$mt_state_file" > "${mt_state_file}.tmp" && mv "${mt_state_file}.tmp" "$mt_state_file"
    fi

    # Accumulate modified_files into cycle_modified_files HERE (not re-read later) — the
    # scoped commit above may have already cleaned up ephemeral per-task files, and cleanup can
    # remove .return-meta.json before Stage MT-3 step 7's overlap computation would otherwise run.
    while IFS= read -r f; do
      [ -n "$f" ] && jq --arg f "$f" '.cycle_modified_files = ((.cycle_modified_files // []) + [$f] | unique)' \
        "$mt_state_file" > "${mt_state_file}.tmp" && mv "${mt_state_file}.tmp" "$mt_state_file"
    done < <(jq -r '.modified_files[]? // empty' "${TASK_DIR}/.return-meta.json" 2>/dev/null)

    bash "${SCRIPT_DIR}/task-lock.sh" release "$task_number" "$session_id"
  else
    echo "${notice_prefix} [dry-run] would update multi-state bookkeeping and release the per-task lock for task ${task_number} — no write, no release performed." >&2
  fi
fi

# ─── Final output ────────────────────────────────────────────────────────────────────────────────
# `halt` and `infra_exempt_cycle` are caller-side loop-control signals a bare `verdict` string
# cannot carry unambiguously: verdict="failed" is produced BOTH by a genuine in-vocabulary
# dispatch_status="failed" (no halt — the task stays in-flight, the next cycle re-evaluates it)
# AND by an off-schema dispatch_status (halt — the outcome cannot be trusted at all), and
# verdict="defer" is produced both by a corroborated infra-exempt cycle (do not charge
# cycle_count) and by ordinary in-budget outcomes (partial dispatch, or implemented with the
# completion-claim gate refused — both DO charge cycle_count). Exposing the two underlying
# booleans directly, rather than asking every caller to re-derive them from `verdict`, is what
# lets both engines apply the identical loop-control decision this script does not own (see the
# file header's MUST NOT list — this script never applies EXIT/cycle_count itself).
if [ "$user_decision_json" != "null" ]; then
  jq -n -c \
    --argjson task "$task_number" \
    --arg phase "$phase" \
    --arg status "$dispatch_status" \
    --argjson phases_completed "$phases_completed" \
    --argjson phases_total "$phases_total" \
    --arg verdict "$verdict" \
    --argjson user_decision "$user_decision_json" \
    --argjson halt "$offschema_dispatch_status" \
    --argjson infra_exempt_cycle "$infra_exempt_cycle" \
    --argjson aux_signal "$aux_signal_json" \
    --arg note "" \
    '{task: $task, phase: $phase, status: $status, phases_completed: $phases_completed,
      phases_total: $phases_total, verdict: $verdict, user_decision: $user_decision,
      halt: $halt, infra_exempt_cycle: $infra_exempt_cycle, aux_signal: $aux_signal, note: $note}'
else
  jq -n -c \
    --argjson task "$task_number" \
    --arg phase "$phase" \
    --arg status "$dispatch_status" \
    --argjson phases_completed "$phases_completed" \
    --argjson phases_total "$phases_total" \
    --arg verdict "$verdict" \
    --argjson halt "$offschema_dispatch_status" \
    --argjson infra_exempt_cycle "$infra_exempt_cycle" \
    --argjson aux_signal "$aux_signal_json" \
    --arg note "" \
    '{task: $task, phase: $phase, status: $status, phases_completed: $phases_completed,
      phases_total: $phases_total, verdict: $verdict, halt: $halt,
      infra_exempt_cycle: $infra_exempt_cycle, aux_signal: $aux_signal, note: $note}'
fi

exit 0
