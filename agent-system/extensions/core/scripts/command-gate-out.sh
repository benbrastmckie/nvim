#!/usr/bin/env bash
# command-gate-out.sh — CHECKPOINT 2: Defensive status correction after skill delegation
#
# Usage: bash .claude/scripts/command-gate-out.sh "$task_number" "$operation" "$session_id"
#
# This script can be called as a subprocess (not sourced) since it only produces
# side effects (state.json updates, artifact validation) and does not export variables.
# (That describes how callers invoke THIS script — it does not restrict what this script may
# itself source internally; it sources skill-base.sh below for skill_validate_task_artifacts,
# following the same precedent orchestrator-postflight.sh already uses.)
#
# Arguments:
#   $1  task_number — The numeric task ID
#   $2  operation   — "research" | "plan" | "implement" | "orchestrate" | "revise"
#   $3  session_id  — The session ID (sess_{timestamp}_{hex}) from gate-in
#
# Note: "operation" is NOT passed verbatim as update-task-status.sh's target_status (which only
# accepts research|plan|implement|pr_ready). A separate "status_token" mapping below translates
# operation -> a valid target_status ("revise" -> "plan", "orchestrate" -> "implement").
#
# Scope: NARROW — only the shared defensive correction pattern (~25 lines).
# Implement-specific steps (completion_summary, plan file verification) stay inline
# in implement.md. Plan-specific steps (plan file status check) stay inline in plan.md.
#
# Exit Codes:
#   0 — Success (correction applied or no correction needed)
#   1 — Fatal error (state.json missing)
#
# Downstream dependencies:
#   skill-base.sh may call this script.

set -e

# Source the shared skill-lifecycle library for skill_validate_task_artifacts (the non-blocking
# artifact validation leg below). Not sourced elsewhere in this script, so it is sourced once
# here at the top, matching orchestrator-postflight.sh's precedent.
source .claude/scripts/skill-base.sh

# Source the shared deploy-baseline decision library (deploy_findings_snapshot,
# deploy_baseline_new_findings) for the rc==6 redeploy-trigger handler below. Same deployed-path
# convention as the skill-base.sh source immediately above.
source .claude/scripts/lib/deploy-baseline-lib.sh

task_number="$1"
operation="$2"
session_id="$3"
state_file="specs/state.json"

# Task lock: unconditional release, run FIRST so it executes regardless of any downstream
# branch or early exit below (missing state.json, missing .return-meta.json, etc.). Success,
# partial, and failed skill statuses all release — release is idempotent and never conditioned
# on the operation's own outcome. See .claude/context/patterns/task-lock.md for the full
# contract. Uses the SAME session_id the gate-in acquired with.
bash .claude/scripts/task-lock.sh release "$task_number" "$session_id" 2>/dev/null || true

# In-flight session registry: unconditional release, same "runs first, regardless of downstream
# branch" placement as the task-lock release immediately above. Best-effort and non-blocking. See
# .claude/context/patterns/task-lock.md's Session-Registry CLI section.
bash .claude/scripts/task-lock.sh session-release "$session_id" 2>/dev/null || true

if [ ! -f "$state_file" ]; then
  echo "ERROR: $state_file not found" >&2
  exit 1
fi

# Get project name and task directory
project_name=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .project_name' \
  "$state_file")
padded_num=$(printf "%03d" "$task_number")
task_dir="specs/${padded_num}_${project_name}"

# Read skill return metadata (non-blocking if missing)
#
# Absence here is now a meaningful diagnostic signal, not a routine event: skill_cleanup()
# (skill-base.sh) no longer deletes .return-meta.json at the skill's own Stage 9 -- deletion is
# now owned by the calling command's own last step, which runs AFTER this script (each command's
# CHECKPOINT 3 commit block, or for /revise, the step right after this gate-out call). So on
# every normal successful run this file is still present when we get here, and this branch fires
# ONLY on a genuine failure: the skill crashed before writing return metadata, or its Stage 0
# contract was violated. Neither defensive status correction below nor
# skill_validate_task_artifacts can run without this file, so both are skipped for this dispatch.
meta_file="${task_dir}/.return-meta.json"
if [ ! -f "$meta_file" ]; then
  echo "WARNING: .return-meta.json not found at $meta_file — the skill did not write return metadata (crashed before postflight, or violated its Stage 0 early-metadata contract). Defensive status correction and artifact validation cannot run for this dispatch." >&2
  # Non-blocking: continue anyway (defensive correction impossible without metadata)
  exit 0
fi

skill_status=$(jq -r '.status' "$meta_file")

# Defensive status correction: map skill status to task status
# Only applies when skill reports completion but state.json is stale
#
# status_token is the value passed to update-task-status.sh's target_status positional arg,
# which only accepts research|plan|implement|pr_ready. It is deliberately distinct from
# "operation": "revise" produces a "planned" state.json status (expected_status) but must pass
# "plan" (not "revise") as target_status; "orchestrate" produces a "completed" state.json status
# but must pass "implement" (not "orchestrate") — this maps "orchestrate" to a valid
# update-task-status.sh target_status instead of passing it through verbatim.
case "$operation" in
  research)    expected_status="researched"; status_token="research" ;;
  plan)        expected_status="planned";    status_token="plan" ;;
  implement)   expected_status="completed";  status_token="implement" ;;
  orchestrate) expected_status="completed";  status_token="implement" ;;
  revise)      expected_status="planned";    status_token="plan" ;;
  *)           expected_status="";           status_token="" ;;
esac

# skill_status accept-list: the normative enumeration of these three success values is
# context/formats/return-metadata-file.md's status vocabulary for .return-meta.json — keep this
# list and that table in sync rather than letting them drift independently. This branch is live
# for operation=orchestrate (not dead code): once the skill-orchestrate writer emits
# "implemented" instead of the format's forbidden "completed", a desynced state.json correctly
# falls through this accept-list and reaches the correction below.
if [ -n "$expected_status" ] && { [ "$skill_status" = "implemented" ] || \
   [ "$skill_status" = "researched" ] || [ "$skill_status" = "planned" ]; }; then

  # Get current status from state.json using safe jq pattern (no != operator per Issue #1132)
  current_status=$(jq -r --argjson num "$task_number" \
    '.active_projects[] | select(.project_number == $num) | .status' \
    "$state_file")

  if [ "$current_status" != "$expected_status" ] && [ "$skill_status" != "partial" ] && [ "$skill_status" != "failed" ]; then
    echo "[gate-out] Defensive correction: status is '$current_status', skill reports '$skill_status'. Applying correction to '$expected_status'."
    # A defensive corrector has no fresh handoff to trust, so it is exactly the case the
    # script-side backstop is built for: only the implement token gets --phase-check=refuse (the
    # flag is silently ignored elsewhere, but passing it only where it applies keeps intent
    # legible). stderr is deliberately no longer discarded for this call -- swallowing it would
    # hide the refusal's reason, which is the only actionable part of the message.
    gate_out_phase_check=""
    if [ "$status_token" = "implement" ]; then
      gate_out_phase_check="--phase-check=refuse"
    fi
    # --file-scope-add write-back (research only): this defensive corrector already has
    # $meta_file open above (it read $skill_status from it) -- a third live research-postflight
    # call site alongside skill_postflight_update (skill-base.sh) and orchestrator-postflight.sh
    # Stage 7, found via a fresh grep at implementation time rather than trusted from the plan's
    # two-site Scope Hypothesis. Wired here rather than left out of scope: this is exactly the
    # failure-recovery path where the primary call site's own write-back may have been the thing
    # that got skipped, so leaving this site unwired would silently drop the proposal in the one
    # scenario it matters most.
    gate_out_fsa=""
    if [ "$status_token" = "research" ] && [ -f "$meta_file" ]; then
      gate_out_proposed_fs=$(jq -c '.proposed_file_scope // [] | if (type == "array") then . else [] end' \
        "$meta_file" 2>/dev/null)
      if [ -n "$gate_out_proposed_fs" ] && [ "$gate_out_proposed_fs" != "[]" ] && [ "$gate_out_proposed_fs" != "null" ]; then
        gate_out_fsa="--file-scope-add=${gate_out_proposed_fs}"
      fi
    fi
    gate_out_rc=0
    bash .claude/scripts/update-task-status.sh postflight "$task_number" "$status_token" "$session_id" ${gate_out_phase_check} ${gate_out_fsa} || gate_out_rc=$?
    if [ "$gate_out_rc" -eq 4 ]; then
      echo "[gate-out] Phase-accounting backstop refused the defensive correction for task $task_number (plan file shows incomplete phases). Leaving status as '$current_status'." >&2
    elif [ "$gate_out_rc" -eq 6 ]; then
      # Postflight completion-deploy gate refused (deploy-pending, update-task-status.sh's
      # "PHASE 0.5" check-only backstop): this gate-out call is a point with NO concurrency --
      # the true single-task /implement completion path -- so it is one of the two sanctioned
      # automated deploy-trigger sites named in
      # context/patterns/regeneration-is-manual-only.md's carve-out. The failure contract below
      # is the SAME baseline-relative (a)/(b)/(c) contract
      # context/patterns/batch-orchestration-guardrails.md's "### The Inter-Cycle Redeploy
      # Checkpoint" subsection documents -- reused here, not restated as a separate mechanism.
      gate_out_matched_paths="$(jq -r '.modified_files // [] | .[] | select(startswith("agent-system/extensions/"))' "$meta_file" 2>/dev/null | tr '\n' ' ')"
      echo "[gate-out] Postflight completion-deploy gate refused task $task_number (deploy-pending: modified_files overlap agent-system/extensions/** and the deploy is stale). Matched path(s): ${gate_out_matched_paths:-<unresolved>}. Running the sanctioned single-task redeploy trigger." >&2

      # Sorted, deduplicated FINDING lines from a --findings run, with verify-deploy.sh exit 2
      # ("cannot run") folded into the SAME findings vocabulary as one synthesized sentinel line
      # rather than special-cased -- deploy_findings_snapshot (scripts/lib/deploy-baseline-lib.sh,
      # sourced at the top of this file), matching the Inter-Cycle Redeploy Checkpoint's own
      # "Exit-2 resolution" rule and shared with that checkpoint's own call site so the two
      # cannot drift apart again.
      gate_out_pre_findings="$(deploy_findings_snapshot .claude/scripts/verify-deploy.sh)"

      gate_out_deploy_rc=0
      gate_out_deploy_log="$(bash .claude/scripts/deploy-headless.sh 2>&1)" || gate_out_deploy_rc=$?

      if [ "$gate_out_deploy_rc" -eq 1 ] || [ "$gate_out_deploy_rc" -eq 2 ]; then
        # Branch (a): the redeploy itself failed to land -- NO baseline consultation, do not
        # re-attempt the transition. Exit 3 is deliberately excluded from this branch: it means
        # the deploy LANDED but inline verification reported failures, which belongs to the
        # baseline-relative comparison below, not here.
        echo "[gate-out] Redeploy trigger FAILED for task $task_number (deploy-headless.sh exited ${gate_out_deploy_rc} -- the deploy did not land). Leaving status as '$current_status'." >&2
        printf '%s\n' "$gate_out_deploy_log" | tail -20 >&2
      else
        gate_out_post_findings="$(deploy_findings_snapshot .claude/scripts/verify-deploy.sh)"
        gate_out_new_findings="$(deploy_baseline_new_findings "$gate_out_pre_findings" "$gate_out_post_findings")"

        if [ -n "$gate_out_new_findings" ]; then
          # Branch (b): at least one newly-introduced finding relative to the pre-redeploy
          # baseline -- do not re-attempt.
          echo "[gate-out] Redeploy trigger for task $task_number introduced NEW verify-deploy finding(s) relative to the pre-redeploy baseline -- refusing to re-attempt. Leaving status as '$current_status'." >&2
          printf '%s\n' "$gate_out_new_findings" >&2
        else
          # Branch (c): the deploy landed and every post-redeploy finding was already present
          # pre-redeploy (the expected case today, per deploy-headless.sh's universal exit 3).
          # Announced loudly, then the transition is re-attempted exactly once.
          gate_out_pre_count=$(printf '%s\n' "$gate_out_pre_findings" | grep -c '^FINDING' || true)
          gate_out_post_count=$(printf '%s\n' "$gate_out_post_findings" | grep -c '^FINDING' || true)
          gate_out_deployed_count="$(printf '%s\n' "$gate_out_deploy_log" | grep -oE '(Resynced|Wiped and regenerated) [0-9]+ extension' | grep -oE '[0-9]+' | head -1)"
          echo "[PRE-EXISTING VERIFY-DEPLOY FAILURE] task $task_number: redeploy landed (${gate_out_deployed_count:-unknown} extension(s) deployed); post-deploy findings (${gate_out_post_count}) are all pre-existing (pre-deploy: ${gate_out_pre_count} findings); deploy-headless.sh exit ${gate_out_deploy_rc}. Proceeding." >&2
          echo "[gate-out] Re-attempting postflight for task $task_number after a successful redeploy." >&2
          gate_out_retry_rc=0
          bash .claude/scripts/update-task-status.sh postflight "$task_number" "$status_token" "$session_id" || gate_out_retry_rc=$?
          if [ "$gate_out_retry_rc" -eq 0 ]; then
            echo "[gate-out] Task $task_number transition succeeded after redeploy (${gate_out_deployed_count:-unknown} extension(s) deployed, verify-deploy: ${gate_out_post_count} pre-existing finding(s), no new)." >&2
          elif [ "$gate_out_retry_rc" -eq 6 ]; then
            # Never re-attempt more than once per gate-out invocation: a second refusal after a
            # successful redeploy is a real signal (e.g. a still-overlapping newer commit), not
            # a loop to retry away.
            echo "[gate-out] Task $task_number still refused (deploy-pending) after a successful redeploy -- this is a real signal, not re-attempted again. Leaving status as '$current_status'." >&2
          else
            echo "WARNING: [gate-out] re-attempt after redeploy failed with exit ${gate_out_retry_rc} for task $task_number — manual correction may be needed" >&2
          fi
        fi
      fi
    elif [ "$gate_out_rc" -ne 0 ]; then
      echo "WARNING: update-task-status.sh failed — manual correction may be needed" >&2
    fi
  fi
fi

# Non-blocking artifact validation (link repair). Instrumented: skill_validate_task_artifacts
# now aggregates fix/error/warning counts across the sweep into SKILL_VALIDATE_* globals (see
# its header comment in skill-base.sh for the D-A/D-B reasoning), and this call site reports
# them unconditionally below -- for the repaired case AND the clean case alike -- so a --fix
# repair is never invisible.
if [ -d "$task_dir" ]; then
  skill_validate_task_artifacts "$task_dir"
  echo "[gate-out] Artifact validation for task ${task_number}: ${SKILL_VALIDATE_FIXES:-0} field(s) auto-repaired, ${SKILL_VALIDATE_ERRORS:-0} error(s), ${SKILL_VALIDATE_WARNINGS:-0} warning(s) remaining."
  if [ "${SKILL_VALIDATE_FIXES:-0}" -gt 0 ]; then
    echo "[gate-out] Auto-repaired artifact(s): ${SKILL_VALIDATE_FIXED_FILES}"
  fi

  # D-C: the report above is console-only and ephemeral. Mirror skill_validate_artifact's own
  # pattern and additionally emit one durable specs/events.jsonl row per gate-out run, so the
  # counts survive past scrollback in automated (non-interactive) runs. category is
  # deviation-discriminated the same way skill_validate_artifact discriminates by status: a
  # nonzero fix or error count is a deviation from the plan, a fully clean sweep is a milestone.
  gate_out_repair_category="milestone"
  if [ "${SKILL_VALIDATE_FIXES:-0}" -gt 0 ] || [ "${SKILL_VALIDATE_ERRORS:-0}" -gt 0 ]; then
    gate_out_repair_category="deviation"
  fi
  gate_out_repair_detail_json=$(jq -c -n \
    --argjson fixes "${SKILL_VALIDATE_FIXES:-0}" \
    --argjson errors "${SKILL_VALIDATE_ERRORS:-0}" \
    --argjson warnings "${SKILL_VALIDATE_WARNINGS:-0}" \
    --arg files "${SKILL_VALIDATE_FIXED_FILES:-}" \
    '{fixes: $fixes, errors: $errors, warnings: $warnings,
      fixed_files: (if $files == "" then [] else ($files | split(",")) end)}')
  _events_append_observable ".claude/scripts/events-append.sh" \
    --event-type artifact_auto_repair --category "$gate_out_repair_category" \
    --task "$task_number" --session "$session_id" --checkpoint gate_out \
    --message "Artifact validation for task ${task_number}: ${SKILL_VALIDATE_FIXES:-0} field(s) auto-repaired, ${SKILL_VALIDATE_ERRORS:-0} error(s), ${SKILL_VALIDATE_WARNINGS:-0} warning(s) remaining" \
    --detail-json "$gate_out_repair_detail_json"
fi

# NOTE: this script MUST NOT delete .return-meta.json. Two reasons: (1) skill-orchestrate never
# calls skill_cleanup and its own postflight stage merges onto .return-meta.json rather than
# deleting it, so deleting it here would regress /orchestrate's completion/resume behavior; (2)
# for /research and /plan, the calling command's own CHECKPOINT 3 commit block runs AFTER this
# script and still needs to read and stage the file -- deleting it here would reintroduce the
# same class of bug this file's lifecycle-ordering fix was written to eliminate. Deletion is
# owned exclusively by each calling command's own last step; see
# context/patterns/skill-postflight-flow.md's reader table for the full per-command mapping.
