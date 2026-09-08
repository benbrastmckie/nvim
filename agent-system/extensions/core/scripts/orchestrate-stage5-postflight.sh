#!/usr/bin/env bash
# orchestrate-stage5-postflight.sh — Shared Stage 5 postflight status-transition and
# artifact-link tail for both orchestrate engines (dedup of the orchestrate-skill-body
# duplication). Covers the `case "$dispatch_status" in ...` block (researched/planned/implemented/
# partial|failed|blocked/off-schema Tier C), the subsequent artifact-linking block, and the
# off-schema halt decision — everything from the "Shared postflight tail" comment through (but
# NOT including) the cycle_count increment, which stays with the caller because it is genuine
# orchestrator LOOP state (see below).
#
# This script performs the real state.json/TODO.md writes (skill_postflight_update,
# skill_gate_completion_claim, skill_orchestrate_propagate_completion, skill_link_artifacts,
# skill_orchestrate_append_detected_defect, system-defect-record.sh) — the same precedent
# orchestrate-stage5-gates.sh already established: a shared script MAY perform real writes, it is
# only ORCHESTRATOR LOOP CONTROL state (whether this dispatch halts the loop, whether cycle_count
# advances) that must never be decided or applied inside the script. This is the mitigation for
# the "script boundary swallows a state transition" risk: the script prints a decision JSON
# (`halt`, `offschema_dispatch_status`, `inferred_phase`, `implemented_gate_passed`) and the
# caller applies the actual `EXIT (partial)` / cycle_count transition inline, in its own prose,
# exactly where a human reviewer already expects to find it.
#
# Usage:
#   orchestrate-stage5-postflight.sh <task_number> <session_id> <task_type> <task_dir> \
#     <dispatch_status> <phases_completed> <phases_total> <plan_markers_verified> \
#     <handoff_artifact_path> <handoff_artifact_type> <handoff_artifact_summary> \
#     <notice_prefix> <tier_c_detecting_site> <skill_attributed_path> <command_suffix> \
#     <dispatch_start_ts> <handoff_file> <loop_guard_file> <cycle_count> [force_invoked]
#
# <force_invoked> (positional 20, OPTIONAL, default "false"): A2's phase-forcing signal, threaded
# from skill-orchestrate/SKILL.md Stage 3's 3c ("true" only on a cycle that popped the forced-
# phase queue). Drives two behaviors below: (1) the monotonic-max status clamp is passed through
# to skill_postflight_update on a forced researched/planned/implemented dispatch, so a forced
# earlier phase never regresses the task's status; (2) the artifact-round advance (new block
# below, after artifact linking) fires unconditionally on `researched` (P1 -- closing the
# pre-existing "/orchestrate never increments next_artifact_number" gap) and additionally on a
# FORCED `planned`/`implemented` dispatch (P2 -- the A2 requirement proper). Omitting this
# argument preserves the pre-A2 behavior exactly: no clamp, and no artifact-round advance for a
# non-research dispatch.
#
# where <tier_c_detecting_site> is the FULL literal detecting-site string for the Tier C
# (off-schema) defect record. This script has one call site today — the single-task Stage 5
# path in skill-orchestrate/SKILL.md, passing the literal `skill-orchestrate/SKILL.md:stage-5-tier-c`
# regardless of effort mode (the deleted standalone hard-mode engine's own separate `:tier-c`
# string has no live emitter any more, and this parameter is a plain string this script takes
# rather than builds — see specs/055_dedupe_orchestrate_skill_bodies/locked-regions.md's Risk row
# on detecting-site strings for why). Stage MT-4's own Tier C handling calls
# `system-defect-record.sh` directly with `skill-orchestrate/SKILL.md:stage-mt4-tier-c`, bypassing
# this script entirely — a separate call path, not a second value this script's own parameter
# takes. <command_suffix> is appended to the Tier C remedy message's `/orchestrate $task_number`
# hint; the live call site always passes the empty string today.
#
# Output: a single-line compact JSON object on stdout. Fields:
#   offschema_dispatch_status  bool    true when dispatch_status fell through to Tier C
#   implemented_gate_passed    bool    meaningful only when dispatch_status == "implemented";
#                                        true if skill_gate_completion_claim allowed the
#                                        completion propagation, false if it refused
#   artifact_linked            bool    true if skill_link_artifacts was called (a non-empty,
#                                        non-"null" handoff_artifact_path was present)
#   halt                       bool    true only when offschema_dispatch_status is true — mirrors
#                                        the pre-dedup code's off-schema-only halt condition
#   inferred_phase             string  meaningful only when offschema_dispatch_status is true
#
# Exit codes: 0 on normal completion. 2 — usage error or jq unavailable.

set -uo pipefail

task_number="${1:-}"
session_id="${2:-}"
task_type="${3:-}"
task_dir="${4:-}"
dispatch_status="${5:-}"
phases_completed="${6:-0}"
phases_total="${7:-0}"
plan_markers_verified="${8:-}"
handoff_artifact_path="${9:-}"
handoff_artifact_type="${10:-}"
handoff_artifact_summary="${11:-}"
notice_prefix="${12:-[orchestrate]}"
tier_c_detecting_site="${13:-}"
skill_attributed_path="${14:-}"
command_suffix="${15:-}"
dispatch_start_ts="${16:-9999999999}"
handoff_file="${17:-}"
loop_guard_file="${18:-}"
cycle_count="${19:-0}"
force_invoked="${20:-false}"

# <clamp> is "monotonic-max" only when this dispatch was forced (A2); empty otherwise, so an
# unforced cycle passes an empty 7th argument to skill_postflight_update and takes the unchanged
# (pre-A2) path.
if [ "$force_invoked" = "true" ]; then
  clamp_mode="monotonic-max"
else
  clamp_mode=""
fi

if [ "$#" -lt 18 ]; then
  echo "ERROR: orchestrate-stage5-postflight.sh: usage: orchestrate-stage5-postflight.sh <task_number> <session_id> <task_type> <task_dir> <dispatch_status> <phases_completed> <phases_total> <plan_markers_verified> <handoff_artifact_path> <handoff_artifact_type> <handoff_artifact_summary> <notice_prefix> <tier_c_detecting_site> <skill_attributed_path> <command_suffix> <dispatch_start_ts> <handoff_file> <loop_guard_file> [cycle_count]" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: orchestrate-stage5-postflight.sh: jq is not available." >&2
  exit 2
fi

export task_number cycle_count

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
fi
# shellcheck disable=SC1090
if [ -f ".claude/scripts/skill-base.sh" ]; then
  . .claude/scripts/skill-base.sh
elif [ -f "${REPO_ROOT}/.claude/scripts/skill-base.sh" ]; then
  . "${REPO_ROOT}/.claude/scripts/skill-base.sh"
else
  . "${SCRIPT_DIR}/skill-base.sh"
fi

offschema_dispatch_status=false
implemented_gate_passed="null"
artifact_linked=false
inferred_phase=""

# ── Postflight status update ─────────────────────────────────────────────────────────────────
# dispatch_status accept-list: the normative enumeration of these six values is
# context/formats/return-metadata-file.md's status vocabulary. That table has a SEVENTH row,
# `in_progress`, deliberately NOT accepted here: it is early-metadata-only and never a legal
# terminal dispatch outcome, so a handoff carrying it means the writer never finished —
# correctly routed to the off-schema arm below.
case "$dispatch_status" in
  researched)
    # Position 5 is an explicit empty placeholder -- behaviorally identical to omitting it
    # (phase_check_mode="${5:-}" and its -n guard both yield the no-flag path either way) -- but
    # required to reach position 6 (task_dir_override) and position 7 (status_clamp_mode) at
    # all. Position 6 passes this script's own already-bound $task_dir, so the exit-6
    # deploy-pending annotation block reaches the task's .return-meta.json without relying on
    # the ambient env var the callee falls back to (which this script never sets). Research is
    # never itself a "forced" dispatch
    # target that could regress status (it is always at or ahead of the task's current
    # position), so clamp_mode here is effectively a no-op today; passed through uniformly for
    # symmetry with the planned/implemented arms below.
    skill_postflight_update "$task_number" "research" "$session_id" "$dispatch_status" "" "$task_dir" "$clamp_mode"
    ;;
  planned)
    skill_postflight_update "$task_number" "plan" "$session_id" "$dispatch_status" "" "$task_dir" "$clamp_mode"
    ;;
  implemented)
    # Completion-claim verification gate: a dispatch reporting "implemented" must not flip the
    # whole task to `completed` without corroborating evidence. The three-case fail-closed logic
    # lives in ONE place — skill_gate_completion_claim in skill-base.sh — so base mode, hard
    # mode, and multi-task mode cannot drift apart again.
    if skill_gate_completion_claim "$task_number" "$phases_completed" "$phases_total" \
         "$plan_markers_verified" "$notice_prefix"; then
      implemented_gate_passed=true
      # `warn`, deliberately NOT `refuse`: the script-side backstop reads the plan file's own
      # phase headings — structurally different evidence — so it is a valuable SECOND OPINION
      # here, not a veto over a decision this state machine made deliberately and loggedly.
      skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status" "warn" "$task_dir" "$clamp_mode"

      # Populate completion_summary/roadmap_items via the single shared propagation path,
      # skill_orchestrate_propagate_completion (scripts/skill-base.sh). No precomputed JSON is
      # passed — this script is a fresh process, so it always issues its own single read via
      # orchestrate-recover-outcome.sh rather than assuming a caller-side $recover_json is
      # available across the process boundary.
      skill_orchestrate_propagate_completion "$task_number" "$task_type" "$task_dir" \
        "$dispatch_start_ts" "" "$notice_prefix"
    else
      implemented_gate_passed=false
      # `skill_gate_completion_claim`'s Case 3/3 (phases_total == 0 AND plan_markers_verified !=
      # "true") already called system-defect-record.sh internally. Re-derive that case here from
      # variables this caller already holds, so the observation reaches this run's ledger without
      # reading or editing scripts/skill-base.sh. Case 1 (phases_total > 0, incomplete) is an
      # ordinary refuse and is NOT a defect — it must not append.
      if [ "${phases_total:-0}" -eq 0 ] && [ "${plan_markers_verified:-}" != "true" ]; then
        skill_orchestrate_append_detected_defect "$loop_guard_file" "$notice_prefix" \
          "META_MISSING_AFTER_NARRATION" "$skill_attributed_path" \
          "scripts/skill-base.sh:skill_gate_completion_claim" \
          "completion claimed with phases_total=0 and unverified plan markers" ""
      fi
    fi
    # On refuse: no status transition. State stays `implementing`, the gate already logged which
    # case fired, `cycle_count` still increments at the end of this stage (caller's concern), and
    # Stage 4 re-dispatches implement next cycle against the same plan.
    ;;
  partial|failed|blocked)
    # Tier B — in-enum exception outcome, explicitly recognized (never the silent catch-all).
    # Deliberately NO skill_postflight_update call: it has its own internal accept-list, so a
    # call from here would no-op one layer deeper regardless.
    echo "${notice_prefix} Dispatch status '$dispatch_status' — recognized exception outcome. No state.json transition is performed here; the task remains at its current in-flight status. This cycle's loop counter still advances." >&2
    ;;
  *)
    # Tier C — off-schema. dispatch_status is neither a success value nor a recognized exception
    # value. A silent no-op here is exactly the defect this three-tier structure exists to close.
    offschema_dispatch_status=true
    case "$handoff_artifact_type" in
      report)  inferred_phase="research" ;;
      plan)    inferred_phase="plan" ;;
      summary) inferred_phase="implement" ;;
      *)       inferred_phase="unknown" ;;
    esac
    offschema_display="${dispatch_status:-<empty>}"
    echo "[OFF-SCHEMA DISPATCH STATUS - '${offschema_display}' is not in the handoff status vocabulary (researched|planned|implemented|needs_research|partial|failed|blocked); the dispatch may have SUCCEEDED but its outcome cannot be trusted or applied]" >&2
    echo "${notice_prefix} ERROR: handoff ${handoff_file} carries an off-schema dispatch_status. Inferred phase (from artifacts[0].type, naming only — not a success signal): ${inferred_phase}. Remedy: inspect the handoff and the dispatch's own .return-meta.json by hand, then re-run /orchestrate ${task_number}${command_suffix}." >&2
    record_result=$(bash .claude/scripts/system-defect-record.sh \
      --defect-class OFF_SCHEMA_STATUS \
      --detecting-site "$tier_c_detecting_site" \
      --task "$task_number" --session "$session_id" \
      --message "handoff dispatch_status '${offschema_display}' is off-schema" \
      --attributed-path "$skill_attributed_path" \
      2>/dev/null) || echo "Note: system-defect recording failed (non-fatal)" >&2
    skill_orchestrate_append_detected_defect "$loop_guard_file" "$notice_prefix" \
      "OFF_SCHEMA_STATUS" "$skill_attributed_path" "$tier_c_detecting_site" \
      "handoff dispatch_status '${offschema_display}' is off-schema" "$record_result"
    ;;
esac

# ── Artifact linking ─────────────────────────────────────────────────────────────────────────
if [ -n "$handoff_artifact_path" ] && [ "$handoff_artifact_path" != "null" ]; then
  case "$handoff_artifact_type" in
    report)
      field_name='**Research**'
      next_field='**Plan**'
      ;;
    plan)
      field_name='**Plan**'
      next_field='**Description**'
      ;;
    summary)
      field_name='**Summary**'
      next_field='**Description**'
      ;;
    *)
      field_name='**Summary**'
      next_field='**Description**'
      ;;
  esac
  skill_link_artifacts "$task_number" "$handoff_artifact_path" "$handoff_artifact_type" \
    "$handoff_artifact_summary" "$field_name" "$next_field"
  artifact_linked=true
fi

# ── Artifact-round advance (A2 P1/P2) ────────────────────────────────────────────────────────
# WHY THIS SITE, not skill_postflight_update: the base lifecycle research skill (since deleted)
# used to perform its own inline next_artifact_number increment AND also call
# skill_postflight_update -- folding the advance into skill_postflight_update itself would have
# double-incremented that skill's own round. This matches the convention
# context/patterns/skill-postflight-flow.md already documents ("An importing skill that needs
# this increment keeps that one state-write.sh call inline"). This script is /orchestrate-only,
# so it is the correct, single site for /orchestrate's own advance.
#
# WHY NOT scripts/orchestrator-postflight.sh: that script's Stage 7a already performs the
# identical increment, but it has ZERO call sites in skill-orchestrate/SKILL.md and is now fully
# orphaned (no live caller at all -- it belonged to the now-deleted base lifecycle skills'
# postflight). Editing it would be inert for this command. See
# this task's plan for the full correction record; do not re-derive this from scratch.
#
# Gate: fires on `researched` UNCONDITIONALLY (P1 -- closing the pre-existing "/orchestrate never
# increments next_artifact_number" gap, which a forced round could not otherwise extend) OR on a
# FORCED `planned`/`implemented` dispatch (P2 -- the A2 requirement proper: a forced phase always
# opens a new MM_ round). An unforced planned/implemented dispatch does NOT advance -- it shares
# the round its preceding research already opened, exactly as skill_read_artifact_number's
# "prev" mode already assumes. Non-blocking on failure, matching the warning style of the
# orchestrator-postflight.sh Stage 7a original this transform is proven against.
do_artifact_round_advance=false
if [ "$dispatch_status" = "researched" ]; then
  do_artifact_round_advance=true
elif [ "$force_invoked" = "true" ] && { [ "$dispatch_status" = "planned" ] || [ "$dispatch_status" = "implemented" ]; }; then
  do_artifact_round_advance=true
fi
if [ "$do_artifact_round_advance" = "true" ]; then
  echo "${notice_prefix} Advancing next_artifact_number (dispatch_status=${dispatch_status}, force_invoked=${force_invoked})..."
  bash .claude/scripts/state-write.sh \
    '(.active_projects[] | select(.project_number == $num)).next_artifact_number =
      ((.active_projects[] | select(.project_number == $num)).next_artifact_number // 1) + 1' \
    --session-id "$session_id" \
    --argjson num "$task_number" \
    || echo "${notice_prefix} WARNING: Failed to advance next_artifact_number (non-blocking)" >&2
fi

# ── Off-schema halt decision (never applied here — see file header) ─────────────────────────
if [ "$offschema_dispatch_status" = "true" ]; then
  halt=true
else
  halt=false
fi

jq -n -c \
  --argjson offschema_dispatch_status "$offschema_dispatch_status" \
  --argjson implemented_gate_passed "$implemented_gate_passed" \
  --argjson artifact_linked "$artifact_linked" \
  --argjson halt "$halt" \
  --arg inferred_phase "$inferred_phase" \
  '{offschema_dispatch_status: $offschema_dispatch_status,
    implemented_gate_passed: $implemented_gate_passed,
    artifact_linked: $artifact_linked, halt: $halt, inferred_phase: $inferred_phase}'

exit 0
