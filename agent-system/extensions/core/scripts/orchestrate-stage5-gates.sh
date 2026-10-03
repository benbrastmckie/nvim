#!/usr/bin/env bash
# orchestrate-stage5-gates.sh — Shared Stage 5 stray-handoff sweep + outcome-recovery block for
# both orchestrate engines (dedup of the orchestrate-skill-body duplication). Covers exactly the
# segment that sits strictly AFTER the `dispatch-seq-gate:end` sentinel (locked, never touched —
# see specs/055_dedupe_orchestrate_skill_bodies/locked-regions.md) and STRICTLY BEFORE the
# handoff-present branch's own `handoff=$(cat "$handoff_file")` parse (also left untouched — the
# ~13 literal `$handoff`-anchored jq reads test-handoff-reader-parity.sh polices by name never
# move out of the SKILL.md bodies). Two pieces, always run together as one call:
#
#   1. Stray-handoff sweep: a mechanism-agnostic backstop for a handoff written outside its task
#      directory (the validate-handoff-location.sh PostToolUse hook cannot see a Bash-redirect
#      write). Bounded to two exact paths (repo root, specs/), never a recursive find.
#   2. Outcome-recovery orchestration: reachable only when the expected handoff is missing or
#      stale. Consults orchestrate-recover-outcome.sh's `.return-meta.json` fallback, and on a
#      recovered outcome, runs the widened evidence-corroboration narrative (the
#      PHASES_ZERO_ON_SUCCESS arm calling skill_corroborate_phase_counts, and the sibling
#      ARTIFACTS_SHAPE_MISMATCH arm). On a non-recovered outcome, runs infra-failure
#      discrimination (two corroborating signals required to exempt the work-cycle budget) and
#      the sanctioned phase-marker recovery grep (diagnostic only, never drives a status
#      transition).
#
# This script performs writes (unlike orchestrate-recover-outcome.sh, which is read-only by
# contract): it may `mv` a stray handoff aside, call system-defect-record.sh, append to
# `.detected_defects` on the loop guard, and update the loop guard's `infra_failures` and
# `last_recovered_phases_completed`/`last_recovered_phases_total` fields — exactly the same
# mutations the pre-dedup inline code performed, now issued from one place instead of two.
#
# Usage:
#   orchestrate-stage5-gates.sh <task_dir> <task_number> <session_id> <handoff_file> \
#     <handoff_stale> <dispatch_start_ts> <loop_guard_file> <notice_prefix> \
#     <skill_attributed_path> <detecting_site_prefix> <dispatch_was_transport_error> \
#     <cycle_count> [plan_path]
#
# where <notice_prefix> is `[orchestrate]` (the sole caller, skill-orchestrate/SKILL.md, passes
# this literally regardless of effort mode — the deleted standalone hard-mode engine's own
# `[hard-orchestrate]` prefix has no live emitter any more), <skill_attributed_path> is
# the calling SKILL.md's repo-relative path (used verbatim as --attributed-path), and
# <detecting_site_prefix> is `skill-orchestrate/SKILL.md`
# (used to build e.g. `skill-orchestrate/SKILL.md:stage-5-stray-handoff`). <plan_path> is
# optional; when empty, the script re-derives the latest plan the same way the inline code did
# (`ls -1 "${task_dir}/plans/"*.md | sort -V | tail -1`).
#
# Output: a single-line compact JSON object on stdout. Fields:
#   stray_found            bool    true if a stray handoff was detected (and moved aside, best-effort)
#   have_outcome           bool    true only when an outcome was recovered this call
#   recovered              bool    mirrors orchestrate-recover-outcome.sh's own field
#   dispatch_status        string  set ONLY when recovered=true; "" otherwise — callers must NOT
#                                    overwrite their own dispatch_status variable when this is ""
#   phases_completed       int     set ONLY when recovered=true (post-corroboration value)
#   phases_total           int     set ONLY when recovered=true (post-corroboration value)
#   plan_markers_verified  string  set ONLY when recovered=true ("absent" or "true")
#   handoff_artifact_path/type/summary   string  set ONLY when recovered=true
#   recovered_reported_status  string  diagnostic, non-recovered branch only ("" otherwise)
#   infra_exempt_cycle     bool    non-recovered branch only (default false)
#   meta_touched            bool    non-recovered branch only (default false)
#   recovered_completed/recovered_total  int  diagnostic phase-marker-grep counts, non-recovered
#                                               branch only (0 otherwise)
#
# Exit codes: 0 on normal completion (regardless of recovered true/false — mirrors
# orchestrate-recover-outcome.sh's own "the JSON is still meaningful on a non-recovered outcome"
# convention, but this script's own success/failure is about ITS OWN execution, not the nested
# recovery outcome, so it always exits 0 unless a usage/environment error prevents it from
# running at all). 2 — usage error or jq unavailable.

set -uo pipefail

task_dir="${1:-}"
task_number="${2:-}"
session_id="${3:-}"
handoff_file="${4:-}"
handoff_stale="${5:-false}"
dispatch_start_ts="${6:-9999999999}"
loop_guard_file="${7:-}"
notice_prefix="${8:-[orchestrate]}"
skill_attributed_path="${9:-}"
detecting_site_prefix="${10:-}"
dispatch_was_transport_error="${11:-false}"
cycle_count="${12:-0}"
plan_path="${13:-}"

if [ -z "$task_dir" ] || [ -z "$handoff_file" ] || [ -z "$loop_guard_file" ] || [ "$#" -lt 12 ]; then
  echo "ERROR: orchestrate-stage5-gates.sh: usage: orchestrate-stage5-gates.sh <task_dir> <task_number> <session_id> <handoff_file> <handoff_stale> <dispatch_start_ts> <loop_guard_file> <notice_prefix> <skill_attributed_path> <detecting_site_prefix> <dispatch_was_transport_error> <cycle_count> [plan_path]" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: orchestrate-stage5-gates.sh: jq is not available." >&2
  exit 2
fi

# task_number/cycle_count are read ambient by skill_orchestrate_append_detected_defect, matching
# the shim contract in scripts/skill-base.sh — export them into this process's own scope so that
# function's ambient reads resolve exactly as they did inline.
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

stray_found=false

# ── 1. Stray-handoff sweep ─────────────────────────────────────────────────────────────────────
sweep_root="${SKILL_REPO_ROOT:-$(pwd)}"
for stray in "${sweep_root}/.orchestrator-handoff.json" "${sweep_root}/specs/.orchestrator-handoff.json"; do
  if [ -e "$stray" ]; then
    stray_found=true
    echo "${notice_prefix} ERROR: STRAY HANDOFF at $stray — a writer produced the handoff outside its task directory." >&2
    echo "${notice_prefix} The correct destination is $handoff_file." >&2
    record_result=$(bash .claude/scripts/system-defect-record.sh \
      --defect-class HANDOFF_MISLOCATED \
      --detecting-site "${detecting_site_prefix}:stage-5-stray-handoff" \
      --task "$task_number" --session "$session_id" \
      --message "stray handoff found at $stray, outside its task directory" \
      --attributed-path "$skill_attributed_path" \
      --extra-detail-json "$(jq -c -n --arg stray "$stray" '{stray_path: $stray}')" \
      2>/dev/null) || echo "Note: system-defect recording failed (non-fatal)" >&2
    skill_orchestrate_append_detected_defect "$loop_guard_file" "$notice_prefix" \
      "HANDOFF_MISLOCATED" "$skill_attributed_path" \
      "${detecting_site_prefix}:stage-5-stray-handoff" \
      "stray handoff found at $stray, outside its task directory" \
      "$record_result"
    mv "$stray" "${task_dir}/.stray-handoff-$(date -u +%s).json" 2>/dev/null \
      && echo "${notice_prefix} Stray moved into ${task_dir}/ for inspection." >&2 \
      || echo "${notice_prefix} WARNING: could not move stray aside; remove it manually before the next cycle." >&2
  fi
done

have_outcome=false
recovered=false
out_dispatch_status=""
out_phases_completed=0
out_phases_total=0
out_plan_markers_verified=""
out_artifact_path=""
out_artifact_type=""
out_artifact_summary=""
out_recovered_reported_status=""
out_infra_exempt_cycle=false
out_meta_touched=false
out_recovered_completed=0
out_recovered_total=0

if [ ! -f "$handoff_file" ] || [ "$handoff_stale" = "true" ]; then
  # ── 2. Outcome recovery: .return-meta.json fallback ──────────────────────────────────────────
  recover_json=$(bash .claude/scripts/orchestrate-recover-outcome.sh "$task_dir" "${dispatch_start_ts:-9999999999}" 2>/dev/null)
  recover_exit=$?
  if [ "$recover_exit" -eq 0 ]; then
    recovered=$(echo "$recover_json" | jq -r '.recovered // false' 2>/dev/null) || recovered=false
  else
    recovered=false
  fi

  if [ "$recovered" = "true" ]; then
    out_dispatch_status=$(echo "$recover_json" | jq -r '.status')
    out_phases_completed=$(echo "$recover_json" | jq -r '.phases_completed // 0')
    out_phases_total=$(echo "$recover_json" | jq -r '.phases_total // 0')
    out_plan_markers_verified="absent"
    out_artifact_path=$(echo "$recover_json" | jq -r '.artifact_path // ""')
    out_artifact_type=$(echo "$recover_json" | jq -r '.artifact_type // ""')
    out_artifact_summary=$(echo "$recover_json" | jq -r '.artifact_summary // ""')
    # ORPHANED SCRIPT (zero call sites -- see docs/architecture/orchestrate-cycle-postflight.md's
    # "What Remains Orphaned" section). This positional interface carries no `phase` argument, so
    # the notice stays phase-agnostic rather than naming one; the false "base-mode
    # research/plan/implement never write one" parenthetical this line previously carried has
    # been removed rather than reproduced -- see orchestrate-cycle-postflight.sh's own
    # phase-conditional severity split for the live, corrected notice.
    echo "${notice_prefix} RECOVERY: no handoff written for this dispatch. .return-meta.json (fresh, within this dispatch window) reports status=${out_dispatch_status}; recovering the dispatch outcome from it." >&2
    have_outcome=true

    # ── Evidence corroboration (widened detection trigger) ─────────────────────────────────────
    evidence_suspect=$(echo "$recover_json" | jq -r '.evidence_suspect // false' 2>/dev/null) || evidence_suspect=false
    evidence_reason=$(echo "$recover_json" | jq -r '.evidence_reason // "NONE"' 2>/dev/null) || evidence_reason="NONE"
    if [ "$evidence_suspect" = "true" ] && [ "$evidence_reason" = "PHASES_ZERO_ON_SUCCESS" ] && [ "$out_dispatch_status" = "implemented" ]; then
      corroboration_plan_path="$plan_path"
      if [ -z "$corroboration_plan_path" ]; then
        corroboration_plan_path=$(ls -1 "${task_dir}/plans/"*.md 2>/dev/null | sort -V | tail -1)
      fi
      # Empty handoff-path argument (4th arg omitted): there is no handoff to validate on the
      # recovery path — the whole reason this branch exists is that no handoff was written this
      # dispatch — so the log-only validate-handoff.sh diagnostic inside the shared function must
      # never fire here.
      cpc_line=$(skill_corroborate_phase_counts "$task_number" "$corroboration_plan_path" "$notice_prefix")
      IFS=' ' read -r cpc_a cpc_b cpc_c <<< "$cpc_line"
      out_phases_completed="${cpc_a#phases_completed=}"
      out_phases_total="${cpc_b#phases_total=}"
      out_plan_markers_verified="${cpc_c#plan_markers_verified=}"
    elif [ "$evidence_suspect" = "true" ] && [ "$evidence_reason" = "ARTIFACTS_SHAPE_MISMATCH" ]; then
      echo "${notice_prefix} EVIDENCE: recovered .return-meta.json reports status=${out_dispatch_status} with a non-empty artifacts array yielding no resolvable path (evidence_reason=ARTIFACTS_SHAPE_MISMATCH) — this is proof of a shape mismatch (e.g. a bare-string artifacts array), not proof of \"no artifacts\"." >&2
      record_result=$(bash .claude/scripts/system-defect-record.sh \
        --defect-class ARTIFACTS_SHAPE_MISMATCH \
        --detecting-site "${detecting_site_prefix}:stage-5-recovered" \
        --task "$task_number" --session "$session_id" \
        --message "recovered return-meta carried a non-empty artifacts array yielding no path" \
        --attributed-path "$skill_attributed_path" \
        2>/dev/null) || echo "Note: system-defect recording failed (non-fatal)" >&2
      skill_orchestrate_append_detected_defect "$loop_guard_file" "$notice_prefix" \
        "ARTIFACTS_SHAPE_MISMATCH" "$skill_attributed_path" \
        "${detecting_site_prefix}:stage-5-recovered" \
        "recovered return-meta carried a non-empty artifacts array yielding no path" \
        "$record_result"
    fi
  else
    if [ "$handoff_stale" = "true" ]; then
      echo "${notice_prefix} ERROR: Skill did not write a handoff for THIS dispatch (a stale one from an earlier cycle is present)."
    else
      echo "${notice_prefix} ERROR: Skill did not write orchestrator handoff."
    fi
    echo "This may mean orchestrator_mode was not propagated correctly, or the handoff was written outside the task directory."
    out_recovered_reported_status=$(echo "${recover_json:-{}}" | jq -r '.status // "unknown"' 2>/dev/null) || out_recovered_reported_status="unknown"
    if [ "$out_recovered_reported_status" != "unknown" ]; then
      echo "${notice_prefix} .return-meta.json reports status=${out_recovered_reported_status} (not recovered as a successful outcome)." >&2
    fi

    # ── Infra-failure discrimination ────────────────────────────────────────────────────────────
    meta_file="${task_dir}/.return-meta.json"
    window_start="${dispatch_start_ts:-9999999999}"
    meta_mtime=$(stat -c %Y "$meta_file" 2>/dev/null || stat -f %m "$meta_file" 2>/dev/null || echo 0)
    if [ "$meta_mtime" -ge "$window_start" ]; then
      out_meta_touched=true
    else
      out_meta_touched=false
    fi

    if [ "${dispatch_was_transport_error:-false}" = "true" ] && [ "$out_meta_touched" = "false" ]; then
      infra_failures=$(jq -r '.infra_failures // 0' "$loop_guard_file" 2>/dev/null) || infra_failures=0
      infra_failures=$((infra_failures + 1))
      jq --argjson infra "$infra_failures" \
         --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '.infra_failures = $infra | .last_updated = $updated' \
        "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
      echo "${notice_prefix} INFRA FAILURE ${infra_failures} — Agent tool transport/API failure with no subagent footprint. Not charged against MAX_CYCLES." >&2
      out_infra_exempt_cycle=true
    else
      echo "${notice_prefix} Missing handoff charged as a genuine work cycle (transport_error=${dispatch_was_transport_error:-false}, meta_touched=${out_meta_touched})." >&2
    fi

    # ── Phase-marker recovery grep (sanctioned narrow exception) ───────────────────────────────
    recovery_plan_path="$plan_path"
    if [ -z "$recovery_plan_path" ]; then
      recovery_plan_path=$(ls -1 "${task_dir}/plans/"*.md 2>/dev/null | sort -V | tail -1)
    fi
    if [ -n "$recovery_plan_path" ] && [ -f "$recovery_plan_path" ]; then
      # shellcheck disable=SC1091
      if [ -f ".claude/scripts/lib/phase-heading-patterns.sh" ]; then
        . .claude/scripts/lib/phase-heading-patterns.sh
      else
        . "${SCRIPT_DIR}/lib/phase-heading-patterns.sh"
      fi
      out_recovered_completed=$(grep -cE "$PHASE_HEADING_DONE_ERE" "$recovery_plan_path" 2>/dev/null) || out_recovered_completed=0
      out_recovered_total=$(grep -cE "$PHASE_HEADING_ERE" "$recovery_plan_path" 2>/dev/null) || out_recovered_total=0
      if has_nonconforming_phase_headings "$recovery_plan_path"; then
        warn_nonconforming "$recovery_plan_path" "orchestrate-recovery" || true
        echo "${notice_prefix} RECOVERY: non-conforming phase heading(s) in ${recovery_plan_path} — recovered phase count is unreliable (treated as unknown, not refused)." >&2
      fi
      echo "${notice_prefix} RECOVERY: handoff unusable — plan headings show ${out_recovered_completed}/${out_recovered_total} phases closed (COMPLETED or COMPLETED WITH EXCLUSIONS) in ${recovery_plan_path}." >&2

      prev_recovered=$(jq -r '.last_recovered_phases_completed // -1' "$loop_guard_file" 2>/dev/null) || prev_recovered=-1
      if [ "$prev_recovered" = "$out_recovered_completed" ]; then
        echo "${notice_prefix} RECOVERY: no phase progress since the previous recovery event (still ${out_recovered_completed}/${out_recovered_total}). Dispatches are not advancing the plan." >&2
      fi
      jq --argjson rc "$out_recovered_completed" --argjson rt "$out_recovered_total" \
         --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '.last_recovered_phases_completed = $rc
         | .last_recovered_phases_total = $rt
         | .last_updated = $updated' \
        "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
    elif [ -d "${task_dir}/plans" ]; then
      echo "${notice_prefix} RECOVERY: no plan file available — phase progress cannot be recovered this cycle." >&2
    else
      echo "${notice_prefix} RECOVERY: no plans/ directory yet (normal after a research-phase dispatch) — phase progress recovery does not apply this cycle." >&2
    fi
  fi
fi

jq -n -c \
  --argjson stray_found "$stray_found" \
  --argjson have_outcome "$have_outcome" \
  --argjson recovered "$recovered" \
  --arg dispatch_status "$out_dispatch_status" \
  --argjson phases_completed "$out_phases_completed" \
  --argjson phases_total "$out_phases_total" \
  --arg plan_markers_verified "$out_plan_markers_verified" \
  --arg artifact_path "$out_artifact_path" \
  --arg artifact_type "$out_artifact_type" \
  --arg artifact_summary "$out_artifact_summary" \
  --arg recovered_reported_status "$out_recovered_reported_status" \
  --argjson infra_exempt_cycle "$out_infra_exempt_cycle" \
  --argjson meta_touched "$out_meta_touched" \
  --argjson recovered_completed "$out_recovered_completed" \
  --argjson recovered_total "$out_recovered_total" \
  '{stray_found: $stray_found, have_outcome: $have_outcome, recovered: $recovered,
    dispatch_status: $dispatch_status, phases_completed: $phases_completed,
    phases_total: $phases_total, plan_markers_verified: $plan_markers_verified,
    handoff_artifact_path: $artifact_path, handoff_artifact_type: $artifact_type,
    handoff_artifact_summary: $artifact_summary,
    recovered_reported_status: $recovered_reported_status,
    infra_exempt_cycle: $infra_exempt_cycle, meta_touched: $meta_touched,
    recovered_completed: $recovered_completed, recovered_total: $recovered_total}'

exit 0
