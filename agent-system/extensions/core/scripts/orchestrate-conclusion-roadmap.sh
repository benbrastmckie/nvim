#!/usr/bin/env bash
# orchestrate-conclusion-roadmap.sh - The single executable copy of /orchestrate's
# conclusion-stage roadmap-update step (context/contracts/conclusion-stage.md's "### Step 5 -
# Roadmap update"), invoked unconditionally from Move 4's finalize sequence so the regenerate
# cannot be skipped by a lead ending its turn early before Move 5 ever runs.
#
# SOLE CALL SITE: skills/skill-orchestrate/SKILL.md's Move 4, immediately after the Batch Gate
# Stage (orchestrate-batch-gate.sh) and before the consolidated output is rendered. Sibling of
# that script at the same call site, differing on exactly one axis: the batch gate is
# trigger-gated on `.implement_agents` being non-empty, this script is UNCONDITIONAL. A
# research-only or plan-only dispatch still moves a task's status, which changes what
# `--regenerate` would render from specs/state.json -- gating this step on an implement dispatch
# would reintroduce the lead-discretion-dependent skip this script exists to close. It fires on
# every exit status alike: `all_terminal`, `no_eligible_stuck`, `max_cycles`, and every `partial`.
#
# WHAT THIS SCRIPT DOES: transcribes Step 5's body verbatim -- no logic change, no new primitive
# beyond the five the contract already names (lib/roadmap-preflight-lib.sh classify,
# roadmap-integration.sh --regenerate, git-commit-scoped.sh, lint/lint-roadmap-batch-proposals.sh,
# events-append.sh/issue-record.sh for the degrade path). context/contracts/conclusion-stage.md
# keeps the authoritative prose description and points here as the sole executor; editing this
# script's sequence without also re-reading that contract (and vice versa) drifts the two apart.
#
# Preflight classify, before --regenerate is ever called: this stage has no interactive surface
# (orchestrate runs autonomously, no confirmation gate between phases), so it cannot obtain the
# approval a write-mode call onto an `absent` or `unknown` ROADMAP.md would need.
#   - classic/stage: --regenerate, the scoped commit, then the advisory batch-proposal lint
#     (exit code never acted on).
#   - absent/unknown: --regenerate and the commit are skipped entirely; specs/ROADMAP.md is left
#     untouched. This call site NEVER scaffolds and NEVER auto-writes. Degrades loudly at three
#     surfaces instead: a named structured warning in this step's own output; a durable
#     `roadmap_regenerate_blocked` event plus its own scoped commit of specs/events.jsonl; then a
#     best-effort per-task-directory issue-record.sh loop (additive, never a substitute for the
#     events write).
#
# Usage:
#   orchestrate-conclusion-roadmap.sh --session SID --state-file PATH [--dry-run]
#
# --state-file PATH is the multi-task state file directly (the same file
# orchestrate-cycle-plan.sh/orchestrate-cycle-postflight.sh call mt_state_file, typically
# specs/.orchestration/.orchestrator-multi-state-<session_id>.json), never specs/state.json --
# modeled on orchestrate-batch-gate.sh's own contract. Task numbers for the degrade loop are read
# from that file's `.task_numbers`; task directories are resolved through the sanctioned
# task-lookup helper (scripts/lib/task-lookup-lib.sh), never an ad hoc glob.
#
# --dry-run: computes and prints the same outcome block, but performs no write and no commit --
# `--regenerate --dry-run` under classic/stage, and no events-append.sh/issue-record.sh/
# git-commit-scoped.sh call at all under either branch. The pending marker (below) is not
# written under --dry-run either.
#
# PENDING MARKER: this script's last action (outside --dry-run) is writing
# <specs_dir>/.orchestration/.conclusion-pending-<session_id>.json (path resolved via
# scripts/lib/runtime-file-patterns.sh's runtime_conclusion_pending_marker_path, shared with
# hooks/orchestrate-conclusion-backstop.sh so the two never duplicate the path), carrying
# session_id, cc_session_id, continuation_count: 0, and created_ts. The backstop hook blocks a
# Claude Code session's Stop event while its own correlated marker is live, and
# context/contracts/conclusion-stage.md's Move 5 Step 6 deletes the marker as its own final
# action once the rest of the conclusion stage has run.
#
# OUTCOME BLOCK: emitted to STDOUT (everything else in this script is stderr diagnostics) as one
# named, parseable block so Move 4 can fold it into the report Move 5 Step 6 emits: the verdict,
# the roadmap-integration.sh `OUTCOME:` line verbatim (classic/stage only -- the degrade branch
# never invokes --regenerate, so no `OUTCOME:` line is ever printed on that branch), the commit
# sha or "none", and the advisory lint's findings (classic/stage only).
#
# NOT RUNNABLE FROM THE SOURCE STORE: deploy-root-guard.sh (sourced below) fails loudly when
# invoked from agent-system/extensions/core/scripts/. Deploy first (bash
# .claude/scripts/deploy-headless.sh, or the picker's [Reload All]/[Regenerate]), then exercise
# the deployed .claude/scripts/orchestrate-conclusion-roadmap.sh copy.
#
# Invocation is foreground, not backgrounded: unlike the Batch Gate Stage (which wraps a full
# verify-deploy.sh run and needs the nohup/pid-capture/bounded-kill-0 idiom), a classify plus an
# idempotent regenerate is a sub-second operation.
#
# Exit codes:
#   0 - ran to completion (including the absent/unknown degrade branch)
#   2 - usage error (missing/invalid arguments, --state-file not found or not valid JSON)
#
# Sets no shell options a caller inherits (this script runs as its own process, invoked by
# skill-orchestrate/SKILL.md's Move 4; it is never sourced).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy-root-guard.sh
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/task-lookup-lib.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/runtime-file-patterns.sh"

usage() {
  cat <<'USAGE'
Usage: orchestrate-conclusion-roadmap.sh --session SID --state-file PATH [--dry-run]
USAGE
}

session_id=""
state_file=""
dry_run="false"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --session) session_id="${2:-}"; shift 2 ;;
    --state-file) state_file="${2:-}"; shift 2 ;;
    --dry-run) dry_run="true"; shift ;;
    --help|-h) usage; exit 0 ;;
    *)
      echo "ERROR: orchestrate-conclusion-roadmap.sh: unrecognized argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$session_id" ] || [ -z "$state_file" ]; then
  echo "ERROR: orchestrate-conclusion-roadmap.sh: --session and --state-file are required" >&2
  usage >&2
  exit 2
fi

if [ ! -f "$state_file" ]; then
  echo "ERROR: orchestrate-conclusion-roadmap.sh: --state-file not found: $state_file" >&2
  exit 2
fi

PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
SPECS_DIR="${PROJECT_ROOT}/specs"
ROADMAP_PATH="${SPECS_DIR}/ROADMAP.md"
STATE_JSON_PATH="${SPECS_DIR}/state.json"
ROADMAP_SCRIPT="${SCRIPT_DIR}/roadmap-integration.sh"
LINT_SCRIPT="${SCRIPT_DIR}/lint/lint-roadmap-batch-proposals.sh"
EVENTS_SCRIPT="${SCRIPT_DIR}/events-append.sh"
ISSUE_SCRIPT="${SCRIPT_DIR}/issue-record.sh"
COMMIT_SCRIPT="${SCRIPT_DIR}/git-commit-scoped.sh"
ROADMAP_PREFLIGHT_LIB="${SCRIPT_DIR}/lib/roadmap-preflight-lib.sh"

mt_json="$(jq -c '.' "$state_file" 2>/dev/null)" || {
  echo "ERROR: orchestrate-conclusion-roadmap.sh: --state-file is not valid JSON: $state_file" >&2
  exit 2
}

# ─── Resolve this invocation's own task directories (degrade-loop use only) ────────────────────
# Never an ad hoc glob -- task-lookup-lib.sh's archive-aware helpers are the sanctioned resolver.
resolved_task_dirs=()
while IFS= read -r _ocr_t; do
  [ -z "$_ocr_t" ] && continue
  _ocr_entry="$(task_lookup_entry "$_ocr_t" "$STATE_JSON_PATH" 2>/dev/null)" || _ocr_entry=""
  [ -z "$_ocr_entry" ] && continue
  _ocr_pname="$(echo "$_ocr_entry" | jq -r '.project_name // empty' 2>/dev/null)"
  [ -z "$_ocr_pname" ] && continue
  _ocr_dir_rel="$(task_lookup_dir "$_ocr_t" "$_ocr_pname" "$PROJECT_ROOT" 2>/dev/null)" || continue
  resolved_task_dirs+=("${PROJECT_ROOT}/${_ocr_dir_rel}")
done < <(echo "$mt_json" | jq -r '(.task_numbers // [])[]' 2>/dev/null)
unset _ocr_t _ocr_entry _ocr_pname _ocr_dir_rel

echo "[orchestrate-conclusion-roadmap] preflight classify: ${ROADMAP_PATH}" >&2
verdict="$(bash "$ROADMAP_PREFLIGHT_LIB" classify "$ROADMAP_PATH")"
echo "[orchestrate-conclusion-roadmap] verdict=${verdict}" >&2

outcome_line=""
commit_sha="none"
lint_output=""
degrade_summary=""

case "$verdict" in
  classic|stage)
    regen_args=(--regenerate)
    [ "$dry_run" = "true" ] && regen_args+=(--dry-run)
    echo "[orchestrate-conclusion-roadmap] running: roadmap-integration.sh ${regen_args[*]}" >&2
    regen_rc=0
    regenerate_output="$(bash "$ROADMAP_SCRIPT" "${regen_args[@]}" 2>&1)" || regen_rc=$?
    printf '%s\n' "$regenerate_output" >&2
    if [ "$regen_rc" -ne 0 ]; then
      echo "ERROR: orchestrate-conclusion-roadmap.sh: roadmap-integration.sh ${regen_args[*]} failed (exit ${regen_rc})" >&2
      exit 2
    fi
    outcome_line="$(printf '%s\n' "$regenerate_output" | grep '^OUTCOME:' | tail -1)"

    if [ "$dry_run" != "true" ]; then
      commit_rc=0
      bash "$COMMIT_SCRIPT" --session "$session_id" \
        --message "orchestrate conclusion: roadmap regenerate" -- "$ROADMAP_PATH" || commit_rc=$?
      case "$commit_rc" in
        0)
          commit_sha="$(git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null || echo none)"
          ;;
        1)
          # Documented, routine "nothing to commit" outcome (ROADMAP.md content unchanged) --
          # not an error.
          commit_sha="none"
          ;;
        *)
          echo "WARNING: orchestrate-conclusion-roadmap.sh: git-commit-scoped.sh exited ${commit_rc} for specs/ROADMAP.md; treating as no commit" >&2
          commit_sha="none"
          ;;
      esac
    fi

    lint_rc=0
    lint_output="$(bash "$LINT_SCRIPT" 2>&1)" || lint_rc=$?
    echo "[orchestrate-conclusion-roadmap] advisory lint exit=${lint_rc} (never acted on)" >&2
    printf '%s\n' "$lint_output" >&2
    ;;
  absent|unknown)
    degrade_summary="roadmap regenerate blocked: specs/ROADMAP.md classifies '${verdict}', no approval surface at conclusion -- the next interactive /roadmap run's own Stage 1 preflight gate resolves it."
    echo "WARNING: [orchestrate-conclusion-roadmap] ${degrade_summary}" >&2

    if [ "$dry_run" != "true" ]; then
      bash "$EVENTS_SCRIPT" \
        --event-type roadmap_regenerate_blocked --category blocker --session "$session_id" \
        --message "roadmap regenerate blocked: specs/ROADMAP.md classifies '${verdict}', no approval surface at conclusion" \
        --detail-json "$(jq -c -n --arg verdict "$verdict" --arg path "specs/ROADMAP.md" \
          '{verdict: $verdict, path: $path}')" >/dev/null

      bash "$COMMIT_SCRIPT" --session "$session_id" \
        --message "orchestrate conclusion: roadmap regenerate blocked (${verdict})" -- "${SPECS_DIR}/events.jsonl" || true

      for _ocr_task_dir in "${resolved_task_dirs[@]}"; do
        bash "$ISSUE_SCRIPT" --task-dir "$_ocr_task_dir" \
          --kind issue --class "roadmap regenerate blocked, no approval surface" --severity costly \
          --phase conclusion --resolution open \
          --what-happened "specs/ROADMAP.md classifies '${verdict}' at /orchestrate's conclusion stage; --regenerate was skipped (no interactive approval surface here). The next interactive /roadmap run's own preflight gate resolves it." \
          >/dev/null 2>&1 || true
      done
      unset _ocr_task_dir
    fi
    ;;
  *)
    echo "ERROR: orchestrate-conclusion-roadmap.sh: unrecognized classify verdict: ${verdict}" >&2
    exit 2
    ;;
esac

# ─── Pending marker: this script's last action, skipped entirely under --dry-run ───────────────
if [ "$dry_run" != "true" ]; then
  marker_path="$(runtime_conclusion_pending_marker_path "$SPECS_DIR" "$session_id")"
  mkdir -p "$(dirname "$marker_path")"
  jq -n \
    --arg sid "$session_id" \
    --arg ccsid "${CLAUDE_CODE_SESSION_ID:-}" \
    --arg ts "$(common_timestamp_iso)" \
    '{session_id: $sid, cc_session_id: $ccsid, continuation_count: 0, created_ts: $ts}' \
    > "$marker_path"
  echo "[orchestrate-conclusion-roadmap] pending marker written: ${marker_path}" >&2
fi

# ─── Outcome block (stdout; everything above is stderr diagnostics) ────────────────────────────
echo "=== orchestrate-conclusion-roadmap: outcome ==="
echo "verdict: ${verdict}"
case "$verdict" in
  classic|stage)
    echo "${outcome_line}"
    echo "commit: ${commit_sha}"
    echo "--- advisory batch-proposal lint findings (never acted on) ---"
    if [ -n "$lint_output" ]; then
      printf '%s\n' "$lint_output"
    else
      echo "(none)"
    fi
    ;;
  absent|unknown)
    echo "regenerate: skipped (${degrade_summary})"
    echo "commit: none"
    if [ "$dry_run" = "true" ]; then
      echo "degrade surfaces: not recorded (--dry-run)"
    else
      echo "degrade surfaces: roadmap_regenerate_blocked event recorded; issue-record.sh best-effort loop ran over ${#resolved_task_dirs[@]} task director$([ "${#resolved_task_dirs[@]}" -eq 1 ] && echo y || echo ies)"
    fi
    ;;
esac
echo "=== end outcome ==="

exit 0
