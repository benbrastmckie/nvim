#!/usr/bin/env bash
# orchestrate-batch-gate.sh - The once-per-invocation shared verify-deploy.sh gate stage for a
# multi-task /orchestrate batch (Mechanism B of the batch-shared verify-deploy-gate design;
# Mechanism A is orchestrate-build-dispatch.sh's `## Batch Gate Deferral` section).
#
# Runs the complete verify-deploy.sh gate set EXACTLY ONCE for the whole batch and attributes
# each confirmed finding back to the task(s) whose own modified_files plausibly caused it --
# reusing scripts/lib/deploy-baseline-lib.sh's existing per-task attribution function
# (deploy_baseline_self_attributable_findings) rather than building a new one. A finding
# attributable to NO task is recorded as a batch-level unattributed finding and stays blocking --
# never dropped, never assigned to one arbitrary task.
#
# SINGLE-CAPTURE DISTINCTION (read before assuming this re-triggers the rejected design recorded
# in context/patterns/batch-orchestration-guardrails.md): that design shared ONE capture across
# the Inter-Cycle Redeploy Checkpoint's own pre/post pair, straddling a DEPLOY boundary -- unsafe
# because roughly 41 of 73 Gate-8 suites resolve the DEPLOYED copy of their subject-under-test in
# preference to the source-store copy, so a pre-redeploy capture and a post-redeploy capture are
# provably not interchangeable there. THIS stage shares one capture across sibling TASKS inside
# ONE already-deployed tree, after each has already committed its own work -- it never straddles
# a deploy boundary. The two designs differ on exactly that axis; this stage does not re-trigger
# the rejection.
#
# Trigger condition: a no-op (exit 0, one explanatory line, no `batch_gate` key written) unless
# at least one implement-phase dispatch occurred this invocation -- read from the state file's
# `.implement_agents` map (populated by orchestrate-cycle-plan.sh whenever an implement dispatch
# is composed; never reset mid-invocation). Mirrors the "don't fire on every invocation
# regardless of relevance" reasoning already recorded for the Inter-Cycle Redeploy Checkpoint.
#
# Usage:
#   orchestrate-batch-gate.sh --session SID --state-file PATH [--dry-run]
#
# --state-file PATH is the multi-task state file path directly (the SAME file
# orchestrate-cycle-plan.sh/orchestrate-cycle-postflight.sh call mt_state_file -- typically
# specs/.orchestration/.orchestrator-multi-state-<session_id>.json), never specs/state.json.
# This script never reads or writes specs/state.json or any individual task's own state; its
# only durable side effect is the `batch_gate` key it adds to this one file.
#
# --dry-run: computes and prints the same summary to stdout, but writes nothing to PATH.
#
# Exit codes:
#   0 - ran (including the no-op trigger-condition-not-met case) successfully
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
source "${SCRIPT_DIR}/lib/deploy-baseline-lib.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/batch-gate-marker-lib.sh"

usage() {
  cat <<'USAGE'
Usage: orchestrate-batch-gate.sh --session SID --state-file PATH [--dry-run]
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
      echo "ERROR: orchestrate-batch-gate.sh: unrecognized argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$session_id" ] || [ -z "$state_file" ]; then
  echo "ERROR: orchestrate-batch-gate.sh: --session and --state-file are required" >&2
  usage >&2
  exit 2
fi

if [ ! -f "$state_file" ]; then
  echo "ERROR: orchestrate-batch-gate.sh: --state-file not found: $state_file" >&2
  exit 2
fi

PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
VERIFY_DEPLOY_PATH="${SCRIPT_DIR}/verify-deploy.sh"

mt_json="$(jq -c '.' "$state_file" 2>/dev/null)" || {
  echo "ERROR: orchestrate-batch-gate.sh: --state-file is not valid JSON: $state_file" >&2
  exit 2
}

# ─── Trigger condition ──────────────────────────────────────────────────────────────────────────
implement_count="$(echo "$mt_json" | jq -r '(.implement_agents // {}) | length' 2>/dev/null)" || implement_count=0
case "$implement_count" in ''|*[!0-9]*) implement_count=0 ;; esac
if [ "$implement_count" -eq 0 ]; then
  echo "[orchestrate-batch-gate] no-op: no implement-phase dispatch occurred this invocation (.implement_agents is empty) -- nothing for the shared gate stage to cover." >&2
  exit 0
fi

echo "[orchestrate-batch-gate] running the complete verify-deploy.sh gate set once for this invocation's batch..." >&2

# ─── Capture: full depth (no --skip-slow), explicit TARGET, exactly once ──────────────────────
# --override-batch-gate-deferral (gate-ceiling-fit Phase 5): this script IS the one sanctioned
# discharger of the batch-gate-pending marker's own obligation -- its own unfiltered
# verify-deploy.sh calls below must never trip verify-deploy.sh's entry guard and refuse
# themselves over a marker THIS session's own cycle-plan step wrote earlier. Every other caller
# of deploy_findings_snapshot in this codebase is deliberately left unoverridden: deferring an
# unfiltered snapshot while a marker is pending is this guard's whole point for them.
first_findings="$(deploy_findings_snapshot "$VERIFY_DEPLOY_PATH" --override-batch-gate-deferral "$PROJECT_ROOT")"
first_exit=0
printf '%s\n' "$first_findings" | grep -q '\[SENTINEL\]' && first_exit=2
[ -n "$first_findings" ] && [ "$first_exit" -ne 2 ] && first_exit=1

if [ -z "$first_findings" ]; then
  echo "[orchestrate-batch-gate] shared gate run: clean (0 findings)." >&2
  gate_exit_code=0
  confirmed_findings=""
else
  # ─── Confirm: a second fresh snapshot; drop candidates that did not reproduce (flaky under
  # the ambient load this very capture just added). ────────────────────────────────────────────
  confirm_snapshot="$(deploy_findings_snapshot "$VERIFY_DEPLOY_PATH" --override-batch-gate-deferral "$PROJECT_ROOT")"
  confirmed_findings="$(deploy_baseline_confirm_new_findings "$first_findings" "$confirm_snapshot")"
  flaky_findings="$(comm -23 <(printf '%s\n' "$first_findings" | sort -u) <(printf '%s\n' "$confirmed_findings" | sort -u) 2>/dev/null || true)"
  if [ -n "$flaky_findings" ]; then
    echo "[orchestrate-batch-gate] dropped as flaky (did not reproduce on the confirmation re-run):" >&2
    printf '%s\n' "$flaky_findings" | sed 's/^/    /' >&2
  fi
  if [ -z "$confirmed_findings" ]; then
    echo "[orchestrate-batch-gate] shared gate run: every candidate finding was flaky; confirmed set is empty." >&2
    gate_exit_code=0
  else
    gate_exit_code=1
    printf '%s\n' "$confirmed_findings" | grep -q '\[SENTINEL\]' && gate_exit_code=2
  fi
fi

# ─── Attribute: for each task in .task_numbers, the subset of confirmed_findings attributable to
# that task's own invocation-scoped modified_files. A finding matching no task's files is
# recorded as a batch-level unattributed finding and stays blocking -- never dropped. ───────────
attributed_json="{}"
unattributed_findings="$confirmed_findings"
if [ -n "$confirmed_findings" ]; then
  while IFS= read -r _bg_t; do
    [ -z "$_bg_t" ] && continue
    _bg_mf="$(echo "$mt_json" | jq -c --arg t "$_bg_t" '(.invocation_modified_files // {})[$t] // []' 2>/dev/null)" || _bg_mf='[]'
    _bg_attr="$(deploy_baseline_self_attributable_findings "$confirmed_findings" "$_bg_mf")"
    if [ -n "$_bg_attr" ]; then
      attributed_json="$(jq -c --arg t "$_bg_t" --arg f "$_bg_attr" \
        '.[$t] = ($f | split("\n") | map(select(length > 0)))' <<<"$attributed_json")"
    fi
  done < <(echo "$mt_json" | jq -r '(.task_numbers // [])[]' 2>/dev/null)

  # unattributed = confirmed_findings minus every line that WAS claimed by some task's own
  # attribution above. Deliberately NOT deploy_baseline_unattributable_findings: that function's
  # own documented fail-safe NEVER prints an identifier-free line (it fail-safes toward staying
  # blocking by omission, under the assumption its caller treats "not in the unattributable set"
  # as "still blocking"). This script's own unattributed set must instead POSITIVELY CONTAIN an
  # identifier-free finding -- it is exactly as unattributed as any other finding no task claimed
  # -- so it is computed directly as the plain set complement against the union of every task's
  # own attributed lines, never via that narrowing filter.
  _bg_attributed_union="$(echo "$attributed_json" | jq -r '[.[] | .[]] | unique | .[]' 2>/dev/null)"
  unattributed_findings="$(comm -23 \
    <(printf '%s\n' "$confirmed_findings" | sort -u) \
    <(printf '%s\n' "$_bg_attributed_union" | sort -u) 2>/dev/null || true)"
fi

if [ -n "$unattributed_findings" ]; then
  echo "[orchestrate-batch-gate] UNATTRIBUTED (names no identifier matching any task's own modified_files this invocation -- stays blocking at batch level):" >&2
  printf '%s\n' "$unattributed_findings" | sed 's/^/    /' >&2
fi

confirmed_count="$(printf '%s\n' "$confirmed_findings" | grep -c . || true)"
[ -z "$confirmed_findings" ] && confirmed_count=0
unattributed_count="$(printf '%s\n' "$unattributed_findings" | grep -c . || true)"
[ -z "$unattributed_findings" ] && unattributed_count=0
echo "[orchestrate-batch-gate] summary: gate_exit_code=${gate_exit_code} confirmed=${confirmed_count} unattributed=${unattributed_count}" >&2

# ─── Owed-sweep discharge: this invocation's complete, unnarrowed run above is the ONLY event
# that discharges a task's own `records/full-sweep-owed.jsonl` open rows (scripts/verify-touched.sh
# / scripts/lib/unmapped-fallback-lib.sh's OWED-NOT-PAID fallback). Discharge fires ONLY when
# gate_exit_code -eq 0 (this run was clean, including the all-flaky-dropped case above) AND this
# is not a --dry-run -- a failing or skipped run discharges nothing, and a dry-run mutates
# nothing, in both cases leaving every open row exactly as it was and reported as still open. ───
owed_discharge_ts="$(common_timestamp_iso 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)"
owed_discharged_total=0
owed_open_roster_json="[]"

while IFS= read -r _bg_t; do
  [ -z "$_bg_t" ] && continue
  _bg_padded="$(printf '%03d' "$_bg_t" 2>/dev/null)" || continue
  _bg_task_dir="$(find "${PROJECT_ROOT}/specs" -maxdepth 1 -type d -name "${_bg_padded}_*" 2>/dev/null | head -1)"
  [ -z "$_bg_task_dir" ] && continue
  _bg_owed_file="${_bg_task_dir}/records/full-sweep-owed.jsonl"
  [ -f "$_bg_owed_file" ] || continue

  _bg_open_before="$(jq -s '[.[] | select(.discharged_ts == null)] | length' "$_bg_owed_file" 2>/dev/null)"
  case "$_bg_open_before" in ''|*[!0-9]*) _bg_open_before=0 ;; esac
  [ "$_bg_open_before" -eq 0 ] && continue

  if [ "$gate_exit_code" -eq 0 ] && [ "$dry_run" != "true" ]; then
    jq -c --arg ts "$owed_discharge_ts" \
      'if .discharged_ts == null then .discharged_ts = $ts else . end' \
      "$_bg_owed_file" > "${_bg_owed_file}.tmp" && mv "${_bg_owed_file}.tmp" "$_bg_owed_file"
    owed_discharged_total=$((owed_discharged_total + _bg_open_before))
  else
    _bg_still_open_json="$(jq -s --arg t "$_bg_t" \
      '[.[] | select(.discharged_ts == null) | {task: $t, path: .path}]' \
      "$_bg_owed_file" 2>/dev/null)"
    [ -z "$_bg_still_open_json" ] && _bg_still_open_json="[]"
    owed_open_roster_json="$(jq -c -n --argjson a "$owed_open_roster_json" --argjson b "$_bg_still_open_json" '$a + $b')"
  fi
done < <(echo "$mt_json" | jq -r '(.task_numbers // [])[]' 2>/dev/null)

owed_open_total="$(echo "$owed_open_roster_json" | jq 'length' 2>/dev/null)"
case "$owed_open_total" in ''|*[!0-9]*) owed_open_total=0 ;; esac
echo "[orchestrate-batch-gate] owed sweep: discharged=${owed_discharged_total} still_open=${owed_open_total}" >&2

batch_gate_record="$(jq -n -c \
  --argjson exit_code "$gate_exit_code" \
  --arg findings "$confirmed_findings" \
  --argjson attributed "$attributed_json" \
  --arg unattributed "$unattributed_findings" \
  --argjson owed_discharged "$owed_discharged_total" \
  --argjson owed_open "$owed_open_total" \
  --argjson owed_open_roster "$owed_open_roster_json" \
  --arg ts "$(common_timestamp_iso 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    ran_at: $ts,
    gate_exit_code: $exit_code,
    confirmed_findings: ($findings | split("\n") | map(select(length > 0))),
    attributed: $attributed,
    unattributed: ($unattributed | split("\n") | map(select(length > 0))),
    owed_discharged_count: $owed_discharged,
    owed_open_count: $owed_open,
    owed_open_roster: $owed_open_roster
  }')"

if [ "$dry_run" = "true" ]; then
  echo "[orchestrate-batch-gate] [dry-run] would write the following batch_gate record to ${state_file}:" >&2
  echo "$batch_gate_record"
  exit 0
fi

jq --argjson bg "$batch_gate_record" '.batch_gate = $bg' "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"
echo "[orchestrate-batch-gate] batch_gate record written to ${state_file}." >&2

# ── Batch-gate-pending marker removal (the discharge point) ─────────────────────────────────
# This run just discharged the complete-gate-set obligation the marker represents -- remove it
# now, idempotently and failure-tolerantly. A missing marker here is NORMAL, not an error: this
# script's own trigger condition above already guarantees at least one implement dispatch
# occurred THIS session, but a crash between that dispatch and this discharge, an operator
# deleting the marker by hand (sanctioned per its own escape-hatch design), or a staleness-aware
# consumer already having ignored/removed it, are all unexceptional. Never fail this stage over
# a removal that doesn't happen.
_bg_marker_file="$(batch_gate_marker_path "$PROJECT_ROOT" "$session_id")"
rm -f "$_bg_marker_file" 2>/dev/null || true
exit 0
