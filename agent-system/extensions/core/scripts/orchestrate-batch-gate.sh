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
first_findings="$(deploy_findings_snapshot "$VERIFY_DEPLOY_PATH" "$PROJECT_ROOT")"
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
  confirm_snapshot="$(deploy_findings_snapshot "$VERIFY_DEPLOY_PATH" "$PROJECT_ROOT")"
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

batch_gate_record="$(jq -n -c \
  --argjson exit_code "$gate_exit_code" \
  --arg findings "$confirmed_findings" \
  --argjson attributed "$attributed_json" \
  --arg unattributed "$unattributed_findings" \
  --arg ts "$(common_timestamp_iso 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    ran_at: $ts,
    gate_exit_code: $exit_code,
    confirmed_findings: ($findings | split("\n") | map(select(length > 0))),
    attributed: $attributed,
    unattributed: ($unattributed | split("\n") | map(select(length > 0)))
  }')"

if [ "$dry_run" = "true" ]; then
  echo "[orchestrate-batch-gate] [dry-run] would write the following batch_gate record to ${state_file}:" >&2
  echo "$batch_gate_record"
  exit 0
fi

jq --argjson bg "$batch_gate_record" '.batch_gate = $bg' "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"
echo "[orchestrate-batch-gate] batch_gate record written to ${state_file}." >&2
exit 0
