#!/usr/bin/env bash
# orchestrate-close-status-bind.sh - Binds a red close battery's verdict to the attributed
# task(s) it covers. A task that is itself the attributed cause of a red close does not remain
# `[COMPLETED]` on the strength of its own scoped check alone; every other implicated task keeps
# its status and carries orchestrate-batch-gate.sh's own `records/close-battery-red.jsonl`
# record (that record is the write; this script is the bind). Implementing the binding as a
# script rather than as a Move 4 prose instruction is deliberate: advisory prose is not a
# mechanism (see this task's own OWNER RULING).
#
# SOLE CALL SITE: skills/skill-orchestrate/SKILL.md's Move 4, immediately after the Batch Gate
# Stage (orchestrate-batch-gate.sh) and before the Roadmap-update stage
# (orchestrate-conclusion-roadmap.sh) -- the same foreground, sub-second siting that script
# already uses. This script reads `batch_gate.close_red_roster` from the multi-task state file
# (written by orchestrate-batch-gate.sh) and performs the status binding through the sanctioned
# status writer (`skill_postflight_update` in skill-base.sh), keeping
# orchestrate-batch-gate.sh's own "never reads or writes specs/state.json" contract intact.
#
# GATE (four-way conjunction): `batch_gate.gate_exit_code` nonzero, the task's own attributed
# finding set non-empty, not --dry-run, and the task present in this invocation's
# `completed_tasks`. The first three conjuncts are already guaranteed by every entry present in
# `batch_gate.close_red_roster` (orchestrate-batch-gate.sh's own write gate for that roster is
# exactly `gate_exit_code -ne 0 && [attributed set non-empty] && !--dry-run`) -- this script adds
# only the fourth: membership in `.completed_tasks`. A task attributed to nothing, or implicated
# only through the batch-level unattributed set, never appears in `close_red_roster` at all and
# is therefore never considered here.
#
# Demotes a qualifying task's status to `[PARTIAL]` with a named reason naming the close battery
# and the attributed findings, following the shape of the existing commit-landing demotion
# (context/standards/status-markers.md's `[COMPLETED]` subsection) rather than inventing a new
# status value or a new writer.
#
# Usage:
#   orchestrate-close-status-bind.sh --session SID --state-file PATH [--dry-run]
#
# --state-file PATH is the SAME multi-task state file orchestrate-batch-gate.sh reads/writes
# (typically specs/.orchestration/.orchestrator-multi-state-<session_id>.json), never
# specs/state.json directly -- this script's only reads of specs/state.json/TODO.md happen
# indirectly, through skill_postflight_update's own call into update-task-status.sh.
#
# --dry-run: computes and prints the same summary to stdout, demotes nothing.
#
# Exit codes:
#   0 - ran (including the no-op no-red-close case) successfully
#   2 - usage error (missing/invalid arguments, or --state-file not found)
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
source "${SCRIPT_DIR}/skill-base.sh"

usage() {
  cat <<'USAGE'
Usage: orchestrate-close-status-bind.sh --session SID --state-file PATH [--dry-run]
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
      echo "ERROR: orchestrate-close-status-bind.sh: unrecognized argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$session_id" ] || [ -z "$state_file" ]; then
  echo "ERROR: orchestrate-close-status-bind.sh: --session and --state-file are required" >&2
  usage >&2
  exit 2
fi

if [ ! -f "$state_file" ]; then
  echo "ERROR: orchestrate-close-status-bind.sh: --state-file not found: $state_file" >&2
  exit 2
fi

PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"

mt_json="$(jq -c '.' "$state_file" 2>/dev/null)" || {
  echo "ERROR: orchestrate-close-status-bind.sh: --state-file is not valid JSON: $state_file" >&2
  exit 2
}

close_red_roster_json="$(echo "$mt_json" | jq -c '.batch_gate.close_red_roster // []' 2>/dev/null)" || close_red_roster_json='[]'
roster_count="$(echo "$close_red_roster_json" | jq 'length' 2>/dev/null)"
case "$roster_count" in ''|*[!0-9]*) roster_count=0 ;; esac

if [ "$roster_count" -eq 0 ]; then
  echo "[orchestrate-close-status-bind] no-op: batch_gate.close_red_roster is empty (clean close, no implicated task, or batch gate stage did not run) -- nothing to bind." >&2
  exit 0
fi

completed_tasks_json="$(echo "$mt_json" | jq -c '.completed_tasks // []' 2>/dev/null)" || completed_tasks_json='[]'

demoted_count=0

while IFS= read -r _csb_entry; do
  [ -z "$_csb_entry" ] && continue
  _csb_task="$(echo "$_csb_entry" | jq -r '.task' 2>/dev/null)"
  [ -z "$_csb_task" ] && continue
  _csb_finding_count="$(echo "$_csb_entry" | jq -r '.finding_count // 0' 2>/dev/null)"
  _csb_record_path="$(echo "$_csb_entry" | jq -r '.path // ""' 2>/dev/null)"

  # Membership test compares as strings regardless of either side's JSON number vs. string
  # representation (task numbers travel as both across this codebase's JSON surfaces).
  _csb_is_completed="$(jq -n --argjson arr "$completed_tasks_json" --arg t "$_csb_task" \
    '($arr | map(tostring)) as $a | ($a | index($t)) != null' 2>/dev/null)"

  if [ "$_csb_is_completed" != "true" ]; then
    echo "[orchestrate-close-status-bind] task ${_csb_task}: red-close record present but task is not in this invocation's completed_tasks -- not demoted (status untouched)." >&2
    continue
  fi

  echo "[orchestrate-close-status-bind] task ${_csb_task}: attributed cause of a red close (${_csb_finding_count} finding(s), record: ${_csb_record_path}) -- demoting completed -> partial." >&2

  if [ "$dry_run" = "true" ]; then
    echo "[orchestrate-close-status-bind] [dry-run] would demote task ${_csb_task} to partial; no write performed." >&2
    demoted_count=$((demoted_count + 1))
    continue
  fi

  _csb_padded="$(printf '%03d' "$_csb_task" 2>/dev/null)" || continue
  _csb_task_dir="$(find "${PROJECT_ROOT}/specs" -maxdepth 1 -type d -name "${_csb_padded}_*" 2>/dev/null | head -1)"

  skill_postflight_update "$_csb_task" "implement" "$session_id" "partial" "" "${_csb_task_dir}" "" \
    || echo "[orchestrate-close-status-bind] WARNING: skill_postflight_update failed for task ${_csb_task} -- status may not have been demoted; investigate by hand." >&2

  demoted_count=$((demoted_count + 1))
done < <(echo "$close_red_roster_json" | jq -c '.[]' 2>/dev/null)

echo "[orchestrate-close-status-bind] summary: roster=${roster_count} demoted=${demoted_count}${dry_run:+ dry-run=$dry_run}" >&2
exit 0
