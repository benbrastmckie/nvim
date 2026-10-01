#!/usr/bin/env bash
# update-task-status.sh - Centralized task status update script
#
# Updates task status atomically across:
#   1. state.json (status field, timestamps, session_id)
#   2. TODO.md (regenerated from state.json via generate-todo.sh)
#   3. Plan file (optional, via update-plan-status.sh)
#
# Usage:
#   .claude/scripts/update-task-status.sh <operation> <task_number> <target_status> <session_id> [--dry-run] [--allow-pr-ready] [--phase-check=warn|refuse] [--file-scope-add=<json-array>] [--research-questions=<json-array>] [--hold-reason=<string>]
#
# Arguments:
#   operation     - "preflight" or "postflight"
#   task_number   - Task number (integer)
#   target_status - "research", "plan", "implement", "pr_ready", "needs_research", "partial",
#                    "blocked", "hold", or "unhold" (pr_ready is reserved for task_type == "pr"
#                    unless --allow-pr-ready is passed; needs_research/partial/blocked are
#                    postflight-only task-level termini -- see map_status() below for the
#                    preflight rejection; hold/unhold are PREFLIGHT-only -- see map_status()'s own
#                    comment for why a hold is the deliberate exception to that pattern)
#   session_id    - Session identifier string
#
# Exit codes:
#   0 - Success or no-op (already at target status)
#   1 - Validation error (bad arguments)
#   2 - state.json update failed
#   3 - plan file update failed after state.json was written, on implement postflight only
#       (retry after fixing the plan file; the state.json write is idempotent and will no-op
#       on retry, so the plan/phase updates re-fire and the retry is genuinely effective)
#   4 - Phase-accounting backstop refused the transition (the task's plan file shows incomplete
#       phases); no state.json write and no plan-file status stamp occurred. Only reachable when
#       --phase-check=refuse is explicitly passed on a postflight implement call.
#   5 - Environment error: the shared library scripts/lib/phase-heading-patterns.sh could not be
#       found at any candidate path. Distinct from every other exit code so a missing dependency
#       is never mistaken for a phase-accounting refusal or a validation error.
#   6 - Postflight completion-deploy gate refused the transition: the task's own
#       .return-meta.json modified_files overlap agent-system/extensions/** AND the deploy is
#       provably behind (see the "PHASE 0.5" block below). No state.json write and no plan-file
#       status stamp occurred. This is an ORDERING constraint, not an exclusion -- the task stays
#       at its current status and the next postflight retry (after a deploy runs) converges
#       normally. Unlike --phase-check=refuse (exit 4), this backstop is UNCONDITIONAL --
#       always active on postflight/implement, no opt-in flag. It is CHECK-ONLY: it never invokes
#       the deploy/regeneration script or the deploy-verification script itself. See
#       context/patterns/batch-orchestration-guardrails.md's
#       "### The Postflight Completion-Deploy Gate" subsection for the full contract.
#
# Optional flag: --phase-check=warn|refuse
#   Absent by default. When absent, this script behaves exactly as it did before the flag
#   existed. When present, and only when operation==postflight and target_status==implement,
#   the script independently counts the task plan file's own `### Phase N: ... [STATUS]`
#   headings (never a caller-supplied count) and acts on conclusive on-disk evidence of
#   incompleteness: `warn` logs loudly and proceeds, `refuse` exits 4 without writing anything.
#   Passing the flag with any other operation/target_status pair is silently ignored.
#
# Optional flag: --file-scope-add=<json-array>
#   Absent by default (byte-for-byte no-op). Additive-only union-merge of the given JSON array of
#   repo-relative path strings onto the target task's existing `file_scope` in specs/state.json --
#   never a replacement, never subtractive. Implements the "Unknown-Footprint Convention" from
#   docs/reference/standards/multi-task-creation-standard.md's Component 4a: research may discover
#   concrete files not covered by the task's creation-time file_scope, and proposes them via
#   `proposed_file_scope` in .return-meta.json (see context/formats/return-metadata-file.md); this
#   flag is the consumer that merges the proposal in.
#   VALUE must parse as a JSON array of strings (`jq -e 'type == "array" and (all(.[]; type ==
#   "string"))'`) -- a malformed value is a hard validation error (exit 1) with a named message,
#   never a silent no-op, so a typo cannot quietly drop coverage.
#   RESTRICTED to operation==postflight && target_status in {research, plan}. The plan branch is
#   the plan-postflight consumer point: context/formats/plan-format.md's "Files to modify"
#   per-phase field is harvested via scripts/plan-file-scope-harvest.sh and forwarded here from
#   every plan-postflight call site (orchestrator-postflight.sh, reconcile-task-status.sh's two
#   call sites, and skill-reviser/SKILL.md, so /revise and reconciliation self-heal both
#   re-harvest too). Any other operation/target_status combination is a validation error naming
#   both permitted target statuses.
#   The merge rides along inside update_state_json()'s existing single state-write.sh invocation
#   (`.file_scope = ((.file_scope // []) + $add | unique)`, scoped to the matching
#   active_projects[] entry) -- never a second write. An empty array, or an array whose members
#   are all already present, leaves file_scope byte-for-byte unchanged. Semantics are identical
#   for both target statuses: additive union, never a replacement, never subtractive.
#
# Optional flag: --research-questions=<json-array>
#   Absent by default (byte-for-byte no-op). Structurally a sibling of --file-scope-add above,
#   with ONE deliberate difference: OVERWRITE-ON-WRITE, not additive union-merge. A planner that
#   returns `needs_research` a second time (e.g. after a research round that still left a gap)
#   fully replaces the task's `research_questions` field in specs/state.json rather than
#   accumulating stale questions from a prior round -- see context/formats/return-metadata-file.md's
#   `### research_questions (optional)` field spec for the producer/consumer narrative.
#   VALUE must parse as a JSON array of strings, validated the same way --file-scope-add is (a
#   malformed value is a hard validation error, exit 1, never a silent no-op).
#   RESTRICTED to operation==postflight && target_status==needs_research. Any other combination
#   is a validation error naming the restriction.
#   The write rides along inside update_state_json()'s existing single state-write.sh invocation,
#   scoped to the matching active_projects[] entry -- never a second write.
#
# Optional flag: --hold-reason=<string>
#   Required (non-empty) when operation==preflight && target_status==hold -- a malformed (empty)
#   value, or an absent flag when setting a hold, is a hard validation error (exit 1), never a
#   silent no-op, matching --file-scope-add/--research-questions's own shape. RESTRICTED to
#   operation==preflight && target_status==hold; passing it with any other combination is a
#   validation error naming the restriction (it is meaningless on `unhold`, which CLEARS
#   hold_reason rather than setting it).
#   Writing a hold sets THREE fields in the same state-write.sh invocation this flag rides along
#   in: hold_reason (this flag's value), held_at (today's date, YYYY-MM-DD, derived from the same
#   timestamp this call already computes for last_updated -- no second `date` call), and
#   prior_status (the task's status immediately before this write -- or, if the task is ALREADY
#   held and this is a reason update, the EXISTING prior_status is preserved rather than
#   overwritten with "hold" itself, which would otherwise break the eventual unhold). See
#   map_status()'s own preflight:hold arm and the unhold preamble immediately below it for the
#   reversal half of this field triple.
#
# Phase-heading grammar: sourced from scripts/lib/phase-heading-patterns.sh, the single anchor
# for the canonical `### Phase N: {name} [STATUS]` shape, the closed status-marker enum, and
# non-conforming-heading detection -- see context/formats/plan-format.md's "Canonical
# phase-heading shape" subsection. This script never re-derives the grammar inline.

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
STATE_FILE="$PROJECT_ROOT/specs/state.json"

# --- Shared phase-heading pattern library ---
# Deploy-tree-first / source-store-fallback candidate list, matching check-task-references.sh's
# resolution of task-reference-patterns.sh. Never falls through to an inline pattern: a missing
# library is a loud environment error (exit 5), not a silent degradation.
PHASE_LIB_CANDIDATES=(
  "$PROJECT_ROOT/.claude/scripts/lib/phase-heading-patterns.sh"
  "$PROJECT_ROOT/agent-system/extensions/core/scripts/lib/phase-heading-patterns.sh"
)
PHASE_LIB=""
for _candidate in "${PHASE_LIB_CANDIDATES[@]}"; do
  if [[ -f "$_candidate" ]]; then
    PHASE_LIB="$_candidate"
    break
  fi
done
if [[ -z "$PHASE_LIB" ]]; then
  echo "Error: shared library phase-heading-patterns.sh not found at any of:" >&2
  for _candidate in "${PHASE_LIB_CANDIDATES[@]}"; do
    echo "  $_candidate" >&2
  done
  exit 5
fi
# shellcheck disable=SC1090
. "$PHASE_LIB"

# --- Shared status-vocabulary library ---
# Single sourced anchor for the closed 12-value task-status enum -- see
# context/schemas/state-schema.json's definitions.taskStatus and
# scripts/lib/status-vocabulary.sh's own header. Same deploy-tree-first / source-store-fallback
# resolution as the phase-heading library above; a missing library is a loud environment error
# (exit 5, matching the phase-heading library's own exit code for the same failure class), never
# a silent degradation.
VOCAB_LIB_CANDIDATES=(
  "$PROJECT_ROOT/.claude/scripts/lib/status-vocabulary.sh"
  "$PROJECT_ROOT/agent-system/extensions/core/scripts/lib/status-vocabulary.sh"
)
VOCAB_LIB=""
for _candidate in "${VOCAB_LIB_CANDIDATES[@]}"; do
  if [[ -f "$_candidate" ]]; then
    VOCAB_LIB="$_candidate"
    break
  fi
done
if [[ -z "$VOCAB_LIB" ]]; then
  echo "Error: shared library status-vocabulary.sh not found at any of:" >&2
  for _candidate in "${VOCAB_LIB_CANDIDATES[@]}"; do
    echo "  $_candidate" >&2
  done
  exit 5
fi
# shellcheck disable=SC1090
. "$VOCAB_LIB"

# --- specs/state.json read-modify-write + TODO.md regen below ---
# Routed through state-write.sh, the single mutex-guarded specs/state.json writer every other
# writer in this codebase shares (see scripts/state-write.sh's own header for the full
# acquire -> mktemp -> jq transform -> jq empty validate -> mv -> optional in-mutex TODO.md
# regen -> release sequence). This supersedes this script's own former acquire_state_mutex /
# release_state_mutex pair, which failed OPEN on a specs/.scope-lock acquire timeout (proceeding
# with the write despite being unable to serialize it) -- state-write.sh is fail-CLOSED instead
# (an ABORT on acquire timeout), the accepted trade-off for this codebase-wide conversion. The mutex is
# still NOT reentrant: state-write.sh itself honors SCOPE_MUTEX_HELD=1 as guest mode exactly as
# acquire_state_mutex did, so this script invoked as a Stage 7 child of
# orchestrator-postflight.sh (which acquires the same mutex before calling this script) still
# runs as a guest with no nested acquire.
#
# No staging-file cleanup trap is needed here any more: state-write.sh owns its own private
# mktemp path and EXIT trap internally, scoped to its own process.

# --- Parse arguments ---
DRY_RUN=false
ALLOW_PR_READY=false
PHASE_CHECK=""
FILE_SCOPE_ADD=""
RESEARCH_QUESTIONS=""
HOLD_REASON=""
POSITIONAL_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --allow-pr-ready) ALLOW_PR_READY=true ;;
    --phase-check=*) PHASE_CHECK="${arg#--phase-check=}" ;;
    --file-scope-add=*) FILE_SCOPE_ADD="${arg#--file-scope-add=}" ;;
    --research-questions=*) RESEARCH_QUESTIONS="${arg#--research-questions=}" ;;
    --hold-reason=*) HOLD_REASON="${arg#--hold-reason=}" ;;
    *) POSITIONAL_ARGS+=("$arg") ;;
  esac
done

operation="${POSITIONAL_ARGS[0]:-}"
task_number="${POSITIONAL_ARGS[1]:-}"
target_status="${POSITIONAL_ARGS[2]:-}"
session_id="${POSITIONAL_ARGS[3]:-}"

# --- Validation ---
if [[ -z "$operation" || -z "$task_number" || -z "$target_status" || -z "$session_id" ]]; then
  echo "Usage: $0 <operation> <task_number> <target_status> <session_id> [--dry-run] [--allow-pr-ready] [--phase-check=warn|refuse] [--file-scope-add=<json-array>] [--research-questions=<json-array>] [--hold-reason=<string>]" >&2
  echo "  operation:     preflight | postflight" >&2
  echo "  target_status: research | plan | implement | pr_ready | needs_research | partial | blocked | hold | unhold (pr_ready requires task_type==pr unless --allow-pr-ready; needs_research/partial/blocked are postflight-only; hold/unhold are preflight-only)" >&2
  exit 1
fi

if [[ "$operation" != "preflight" && "$operation" != "postflight" ]]; then
  echo "Error: operation must be 'preflight' or 'postflight', got '$operation'" >&2
  exit 1
fi

if [[ "$target_status" != "research" && "$target_status" != "plan" && "$target_status" != "implement" && "$target_status" != "pr_ready" && "$target_status" != "needs_research" && "$target_status" != "partial" && "$target_status" != "blocked" && "$target_status" != "hold" && "$target_status" != "unhold" ]]; then
  echo "Error: target_status must be 'research', 'plan', 'implement', 'pr_ready', 'needs_research', 'partial', 'blocked', 'hold', or 'unhold', got '$target_status'" >&2
  exit 1
fi

# hold/unhold are PREFLIGHT-only (Decision 5: a hold is human-initiated, not derived from a
# dispatch outcome -- see map_status()'s own preflight:hold comment for the full reasoning).
# Neither is meaningful as a postflight target: there is no dispatch outcome that resolves to
# "pause this task" or "resume this task", so postflight:hold/postflight:unhold are hard
# validation errors rather than silently accepted and misinterpreted.
if [[ ( "$target_status" == "hold" || "$target_status" == "unhold" ) && "$operation" != "preflight" ]]; then
  echo "Error: target_status '$target_status' is only valid with operation=preflight (got operation='$operation')." >&2
  exit 1
fi

if ! [[ "$task_number" =~ ^[0-9]+$ ]]; then
  echo "Error: task_number must be a positive integer, got '$task_number'" >&2
  exit 1
fi

# A typo'd --phase-check value must never SILENTLY disable the very protection the caller
# intended to enable, so a bad value is a hard validation error rather than a fallback to no-op.
if [[ -n "$PHASE_CHECK" && "$PHASE_CHECK" != "warn" && "$PHASE_CHECK" != "refuse" ]]; then
  echo "Error: --phase-check must be 'warn' or 'refuse', got '$PHASE_CHECK'" >&2
  exit 1
fi

# --file-scope-add validation: a malformed value is a hard validation error, never a silent
# no-op, so a typo cannot quietly drop coverage (same precedent as --phase-check above). Follows
# --phase-check's own guard shape: only validate when the flag was actually passed.
if [[ -n "$FILE_SCOPE_ADD" ]]; then
  if ! echo "$FILE_SCOPE_ADD" | jq -e 'type == "array" and (all(.[]; type == "string"))' >/dev/null 2>&1; then
    echo "Error: --file-scope-add value must be a JSON array of strings, got: $FILE_SCOPE_ADD" >&2
    exit 1
  fi
  # Restricted to operation==postflight && target_status in {research, plan} (the
  # research-postflight write-back consumer point plus the plan-postflight harvest consumer
  # point). Any other combination is a validation error naming both permitted target statuses,
  # never a silent no-op.
  if [[ "$operation" != "postflight" || ( "$target_status" != "research" && "$target_status" != "plan" ) ]]; then
    echo "Error: --file-scope-add is only valid with operation=postflight and target_status in {research, plan} (got operation='$operation', target_status='$target_status')." >&2
    exit 1
  fi
fi

# --research-questions validation: same malformed-value-is-a-hard-error shape as --file-scope-add
# above (a typo must never silently drop the planner's question list).
if [[ -n "$RESEARCH_QUESTIONS" ]]; then
  if ! echo "$RESEARCH_QUESTIONS" | jq -e 'type == "array" and (all(.[]; type == "string"))' >/dev/null 2>&1; then
    echo "Error: --research-questions value must be a JSON array of strings, got: $RESEARCH_QUESTIONS" >&2
    exit 1
  fi
  # Restricted to operation==postflight && target_status==needs_research (the planner-postflight
  # write-back consumer point). Any other combination is a validation error naming the
  # restriction, never a silent no-op.
  if [[ "$operation" != "postflight" || "$target_status" != "needs_research" ]]; then
    echo "Error: --research-questions is only valid with operation=postflight and target_status=needs_research (got operation='$operation', target_status='$target_status')." >&2
    exit 1
  fi
fi

# --hold-reason validation: RESTRICTED to operation==preflight && target_status==hold -- it is
# meaningless on `unhold` (which CLEARS hold_reason, never sets it) and on every other
# operation/target_status combination, so passing it anywhere else is a validation error naming
# the restriction, never a silent no-op (same precedent as --file-scope-add/--research-questions
# above).
if [[ -n "$HOLD_REASON" ]]; then
  if [[ "$operation" != "preflight" || "$target_status" != "hold" ]]; then
    echo "Error: --hold-reason is only valid with operation=preflight and target_status=hold (got operation='$operation', target_status='$target_status')." >&2
    exit 1
  fi
fi

# A malformed (empty) --hold-reason, or an absent flag, is a hard validation error on
# preflight:hold specifically -- a hold with no recorded reason is never acceptable, matching the
# "a typo/omission cannot quietly drop coverage" precedent the other optional flags establish
# above. This check is unconditional on HOLD_REASON being set (unlike the restriction check
# above) because it must also catch the "flag never passed at all" case.
if [[ "$operation" == "preflight" && "$target_status" == "hold" && -z "$HOLD_REASON" ]]; then
  echo "Error: --hold-reason=<string> is required when setting target_status=hold (a hold with no recorded reason is never acceptable)." >&2
  exit 1
fi

# Only a genuinely non-empty array triggers the merge clause below -- an empty array (or an
# absent flag) skips the jq file_scope clause entirely rather than running `unique` over an
# unchanged array, so the empty/absent case is a byte-for-byte no-op (including array element
# order), not merely a content-equal one.
FILE_SCOPE_ADD_LEN=0
if [[ -n "$FILE_SCOPE_ADD" ]]; then
  FILE_SCOPE_ADD_LEN=$(echo "$FILE_SCOPE_ADD" | jq 'length')
fi

# Same "only a genuinely non-empty array triggers the write clause" shape as FILE_SCOPE_ADD_LEN
# above, except the clause below OVERWRITES research_questions rather than union-merging it (see
# the --research-questions flag's own header comment for why).
RESEARCH_QUESTIONS_LEN=0
if [[ -n "$RESEARCH_QUESTIONS" ]]; then
  RESEARCH_QUESTIONS_LEN=$(echo "$RESEARCH_QUESTIONS" | jq 'length')
fi

if [[ ! -f "$STATE_FILE" ]]; then
  echo "Error: state.json not found at $STATE_FILE" >&2
  exit 1
fi

# --- Status mapping ---
map_status() {
  local op="$1"
  local target="$2"

  case "${op}:${target}" in
    preflight:research)   STATE_STATUS="researching";   TODO_STATUS="RESEARCHING" ;;
    preflight:plan)       STATE_STATUS="planning";      TODO_STATUS="PLANNING" ;;
    preflight:implement)  STATE_STATUS="implementing";  TODO_STATUS="IMPLEMENTING" ;;
    postflight:research)  STATE_STATUS="researched";    TODO_STATUS="RESEARCHED" ;;
    postflight:plan)      STATE_STATUS="planned";       TODO_STATUS="PLANNED" ;;
    postflight:implement) STATE_STATUS="completed";     TODO_STATUS="COMPLETED" ;;
    preflight:pr_ready)  STATE_STATUS="pr_ready";      TODO_STATUS="PR READY" ;;
    postflight:pr_ready) STATE_STATUS="completed";     TODO_STATUS="COMPLETED" ;;
    # partial/blocked/needs_research are postflight-only task-level termini (state-management.md's
    # permissive transition model admits partial/blocked from [IMPLEMENTING] on timeout/error).
    # There is deliberately no preflight:partial, preflight:blocked, or preflight:needs_research
    # case here -- the catch-all below rejects that nonsensical combination with exit 1, which is
    # the desired fail-loud behavior. `hold` BREAKS this pattern, deliberately: every other
    # postflight-only status above is DERIVED from a dispatch outcome (a timeout, an error, a
    # planner's own needs_research verdict) -- there is no human sitting at a keyboard choosing to
    # set them. A hold is the opposite: it is ALWAYS human-initiated (an operator deciding to pause
    # a task), never a dispatch outcome, so `preflight:hold` is the sensible combination and a
    # postflight-only hold would be unsettable by an operator in the first place. See the
    # preflight:hold arm immediately below, and the `unhold` preamble ahead of the map_status()
    # call further down this file for the reversal half.
    preflight:hold)      STATE_STATUS="hold";          TODO_STATUS="HOLD" ;;
    postflight:partial)  STATE_STATUS="partial";       TODO_STATUS="PARTIAL" ;;
    postflight:blocked)  STATE_STATUS="blocked";       TODO_STATUS="BLOCKED" ;;
    # needs_research is a planner-only outcome: the planner declined to write a plan and is
    # asking for a research phase. It resolves to the SAME resting state (STATE_STATUS
    # "researching") that preflight:research produces, deliberately reusing the existing
    # researching -> research classifier row rather than minting a new state.json status value --
    # see context/reference/state-management-schema.md's research_questions field doc and
    # context/formats/return-metadata-file.md's needs_research status note. The token name
    # ("postflight:needs_research") stays distinct from "preflight:research" so `git blame` and
    # grep self-document which producer wrote the "researching" state.
    postflight:needs_research) STATE_STATUS="researching"; TODO_STATUS="RESEARCHING" ;;
    *)
      echo "Error: unknown operation:target_status combination '${op}:${target}'" >&2
      exit 1
      ;;
  esac
}

# --- unhold: a DYNAMIC resting state, unlike every other map_status() arm ---
# Decision 5: `preflight:unhold`'s resolved STATE_STATUS is whatever `prior_status` this task's
# own hold recorded -- not a fixed literal map_status()'s closed case statement could express.
# Resolved and validated HERE, ahead of the map_status() call, so the SAME post-map_status() enum
# backstop a few lines below still re-validates this resolved value exactly as it does for every
# other arm (never bypassed for this one dynamic case).
if [[ "$operation" == "preflight" && "$target_status" == "unhold" ]]; then
  _unhold_prior_status=$(jq -r --argjson num "$task_number" \
    '.active_projects[] | select(.project_number == ($num | tonumber)) | .prior_status // ""' \
    "$STATE_FILE")
  if [[ -z "$_unhold_prior_status" ]]; then
    echo "Error: cannot unhold task $task_number -- no prior_status recorded on this entry (never falls back to 'not_started' or any other default; fix the entry manually, or confirm the task is actually held)." >&2
    exit 1
  fi
  if ! status_vocabulary_is_valid "$_unhold_prior_status"; then
    echo "Error: cannot unhold task $task_number -- recorded prior_status '$_unhold_prior_status' is not a member of the closed task-status enum (never falls back to a default; fix the entry manually)." >&2
    exit 1
  fi
  STATE_STATUS="$_unhold_prior_status"
  TODO_STATUS="$(status_vocabulary_todo_marker "$STATE_STATUS")"
else
  map_status "$operation" "$target_status"
fi

# --- Validate the resolved resting state against the closed enum ---
# map_status()'s own case statement is closed (no `revise` case -- revising/revised stay
# unreachable by design, per the research/plan decision documented in status-vocabulary.sh's
# header), so STATE_STATUS should always already be a member of the enum. This is a defensive
# backstop against future drift (e.g. a new case arm added to map_status() without a matching
# schema/library update), not a behavior change for any of the ten combinations above -- every
# one of them resolves to a value status_vocabulary_is_valid already accepts.
if ! status_vocabulary_is_valid "$STATE_STATUS"; then
  echo "Error: map_status() resolved an off-schema resting state '${STATE_STATUS}' for '${operation}:${target_status}' (not a member of the closed task-status enum in scripts/lib/status-vocabulary.sh / context/schemas/state-schema.json). This indicates map_status() has drifted from the schema -- fix map_status() or the schema, do not bypass this check." >&2
  exit 1
fi

# --- Validate task exists in state.json ---
task_exists=$(jq -r --arg num "$task_number" \
  '[.active_projects[] | select(.project_number == ($num | tonumber))] | length' \
  "$STATE_FILE")

if [[ "$task_exists" == "0" ]]; then
  echo "Error: task $task_number not found in state.json" >&2
  exit 1
fi

# --- task_type lookup (mirrors the project_name lookup pattern used below) ---
task_type=$(jq -r --arg num "$task_number" \
  '.active_projects[] | select(.project_number == ($num | tonumber)) | .task_type // "general"' \
  "$STATE_FILE")

# --- Guard: pr_ready is reserved for task_type == "pr" unless explicitly overridden ---
if [[ "$target_status" == "pr_ready" && "$task_type" == "pr" ]]; then
  : # allowed: pr-type task transitioning to pr_ready
elif [[ "$target_status" == "pr_ready" && "$ALLOW_PR_READY" == "true" ]]; then
  : # allowed: explicit override flag passed (e.g. skeleton-exhaustion routing in skill-orchestrate's hard-mode branch)
elif [[ "$target_status" == "pr_ready" ]]; then
  echo "Error: 'pr_ready' is reserved for task_type == 'pr' (task $task_number has task_type '$task_type')." >&2
  echo "       Pass --allow-pr-ready to override this guard." >&2
  exit 1
fi

# --- Idempotency check (scoped to state.json only) ---
# When state.json is already at the target status, the state.json write itself is skipped
# (state_is_noop=true) but PHASE 2 (TODO.md regen) and PHASE 3 (plan/phase file updates) below
# still run unconditionally -- both downstream scripts have their own idempotency checks, so a
# redundant call is a safe no-op. This makes plan/phase updates self-healing on retry instead of
# being silently suppressed by an unrelated state.json no-op.
current_state_status=$(jq -r --arg num "$task_number" \
  '.active_projects[] | select(.project_number == ($num | tonumber)) | .status' \
  "$STATE_FILE")

# --- unhold sanity guard: nothing to lift if the task is not actually held ---
if [[ "$target_status" == "unhold" && "$current_state_status" != "hold" ]]; then
  echo "Error: task $task_number is not held (current status: '$current_state_status') -- nothing to unhold." >&2
  exit 1
fi

# --- Hold field resolution (preflight:hold only) ---
# prior_status to persist: if the task is not already held, capture its REAL current status; if
# it IS already held (this call is a hold-reason update, not a fresh hold), preserve the
# EXISTING prior_status rather than overwriting it with "hold" itself, which would otherwise
# permanently break the eventual unhold (prior_status must never itself be "hold").
HOLD_SET=false
UNHOLD_SET=false
if [[ "$operation" == "preflight" && "$target_status" == "hold" ]]; then
  HOLD_SET=true
  if [[ "$current_state_status" == "hold" ]]; then
    HOLD_PRIOR_STATUS=$(jq -r --arg num "$task_number" \
      '.active_projects[] | select(.project_number == ($num | tonumber)) | .prior_status // ""' \
      "$STATE_FILE")
    if [[ -z "$HOLD_PRIOR_STATUS" ]]; then
      echo "Error: task $task_number is already held but carries no prior_status -- refusing to re-hold a corrupted entry; fix it manually." >&2
      exit 1
    fi
  else
    HOLD_PRIOR_STATUS="$current_state_status"
  fi
elif [[ "$target_status" == "unhold" ]]; then
  UNHOLD_SET=true
fi

# --- Hold sticky guard ---
# A hold is a deliberate, human-set pause; an ordinary preflight/postflight status write must
# never silently clear it. Only preflight:hold (above) and preflight:unhold (the explicit lift)
# may move a task OFF status=="hold" -- every OTHER operation:target_status pair, when the
# task's CURRENT status is already "hold", downgrades to a no-op on the status field alone:
# STATE_STATUS/TODO_STATUS are overridden back to hold/HOLD so the idempotency check immediately
# below makes the state.json status write a true no-op, while every other side effect (TODO.md
# regen, plan/phase file updates, hooks, events) still runs exactly as on any other path. THIS
# guard -- not the rank-based monotonic-max clamp in skill-base.sh/orchestrate-cycle-plan.sh --
# is the actual mechanism that lets an explicit /orchestrate --research/--plan/--implement
# forcing-flag override admit a held task for one dispatch while leaving status == "hold"
# afterward: "hold" is deliberately UNRANKED in status-vocabulary.sh's
# STATUS_VOCABULARY_LIFECYCLE_RANK, so status_vocabulary_would_regress(hold, implementing)
# returns false ("no regression") and that clamp alone would let the write through unguarded.
if [[ "$current_state_status" == "hold" && "$HOLD_SET" != "true" && "$UNHOLD_SET" != "true" ]]; then
  echo "NOTICE: task $task_number is held; ${operation}:${target_status} does not clear the hold -- status write skipped (status stays 'hold'). Lift the hold with 'preflight unhold' to resume ordinary status transitions." >&2
  STATE_STATUS="hold"
  TODO_STATUS="HOLD"
fi

state_is_noop=false
if [[ "$current_state_status" == "$STATE_STATUS" ]]; then
  state_is_noop=true
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] Task $task_number already at status '$STATE_STATUS' -- state.json no-op"
  fi
fi

# ============================================================
# PHASE 0: Phase-accounting backstop (opt-in via --phase-check)
# ============================================================
# Independent, script-side evidence gathering: this NEVER trusts a caller-supplied phase count.
# Accepting one would reproduce the exact fragility being fixed (a caller can pass wrong numbers
# just as easily as a handoff can omit them), so the only caller-supplied decision is the MODE.
#
# Evidence source is the plan file's own `### Phase N: {name} [STATUS]` headings -- the same
# single-line-per-phase contract plan-format.md fixes and update-phase-status.sh already treats
# as authoritative. Deliberately NOT `- [ ]`/`- [x]` checkbox counting: checkboxes are sub-phase
# task items whose granularity is unrelated to phase count, and they also appear in non-phase
# sections (e.g. "Testing & Validation"), so a whole-file checkbox ratio is not a phase signal.
#
# Plan-file resolution reuses update_plan_file()'s existing project_name -> plan_dir ->
# version-ordered-ls chain, so NO new argument is required: task_number (already a required
# positional) is sufficient.
#
# Conclusiveness convention: only "conforming phase headings exist AND at least one is not
# [COMPLETED]" is conclusive evidence of incompleteness. No plan file, no plan dir, or zero
# conforming phase headings is INCONCLUSIVE and always passes through -- deliberately mirroring
# the SKILL-layer gate's own `phases_total == 0` pass-through so the two layers never disagree
# on the meaning of "no data".
PHASE_CHECK_PLAN_FILE=""
PHASE_CHECK_TOTAL=0
PHASE_CHECK_DONE=0

resolve_plan_file_for_phase_check() {
  local project_name padded_num plan_dir plan_file
  project_name=$(jq -r --arg num "$task_number" \
    '.active_projects[] | select(.project_number == ($num | tonumber)) | .project_name' \
    "$STATE_FILE")
  if [[ -z "$project_name" || "$project_name" == "null" ]]; then
    return 0
  fi
  padded_num=$(printf "%03d" "$task_number")
  plan_dir="$PROJECT_ROOT/specs/${padded_num}_${project_name}/plans"
  if [[ ! -d "$plan_dir" ]]; then
    plan_dir="$PROJECT_ROOT/specs/${task_number}_${project_name}/plans"
  fi
  [[ -d "$plan_dir" ]] || return 0
  # Version-ordered selection (not mtime-ordered), the same two-tier rule used by
  # update_plan_file()'s preflight branch, update-plan-status.sh, and update-phase-status.sh.
  plan_file=$(ls "$plan_dir"/[0-9][0-9]_*.md 2>/dev/null | sort | tail -1 || echo "")
  if [[ -z "$plan_file" ]]; then
    plan_file=$(ls "$plan_dir"/*.md 2>/dev/null | sort | tail -1 || echo "")
  fi
  [[ -n "$plan_file" && -f "$plan_file" ]] || return 0
  PHASE_CHECK_PLAN_FILE="$plan_file"
  return 0
}

count_plan_phases() {
  # Sourced from scripts/lib/phase-heading-patterns.sh's PHASE_HEADING_TOTAL_ERE /
  # PHASE_HEADING_DONE_ERE forms rather than re-derived inline -- see that library's header and
  # context/formats/plan-format.md's "Canonical phase-heading shape" subsection. Deliberately
  # migrated from BRE to ERE (`grep -E`) here so one regex family is authoritative repo-wide; the
  # library's BRE aliases remain available as documented compatibility forms only.
  #
  # A heading is counted toward TOTAL only when it matches the exact conforming shape
  # `### Phase <N>: ... [<UPPERCASE STATUS>]` (trailing whitespace tolerated). This is necessary
  # but NOT sufficient for true conformance -- see the non-conforming-heading guard at this
  # function's call site below, which additionally rejects an out-of-enum marker (e.g.
  # `[DESCOPED]`) that still satisfies this bracket shape.
  #
  # The `VAR=$(grep -c ...) || VAR=0` form is required, not cosmetic: `grep -c` exits 1 when it
  # matches nothing (which `set -e` would otherwise treat as fatal), and the tempting
  # `$(grep -c ... || echo 0)` form emits TWO lines ("0" from grep plus "0" from echo).
  PHASE_CHECK_TOTAL=$(grep -cE "$PHASE_HEADING_TOTAL_ERE" \
    "$PHASE_CHECK_PLAN_FILE" 2>/dev/null) || PHASE_CHECK_TOTAL=0
  PHASE_CHECK_DONE=$(grep -cE "$PHASE_HEADING_DONE_ERE" \
    "$PHASE_CHECK_PLAN_FILE" 2>/dev/null) || PHASE_CHECK_DONE=0
}

# The gate runs BEFORE update_state_json below (which now owns its own mutex acquisition via
# state-write.sh), so a refusal costs no mutex acquisition and no jq write. Because PHASE 1
# (state.json flip) and PHASE 3 (update_plan_file's [COMPLETED] stamp)
# are both downstream of this point and both reachable only via this one
# operation=postflight/target_status=implement code path, this single gate blocks both of the
# defect's two effects at once.
#
# `state_is_noop == true` is excluded: a task already at 'completed' replaying postflight has
# nothing left to refuse.
if [[ -n "$PHASE_CHECK" && "$operation" == "postflight" && "$target_status" == "implement" \
      && "$state_is_noop" != "true" ]]; then
  resolve_plan_file_for_phase_check
  PHASE_CHECK_NONCONFORMING=0
  if [[ -n "$PHASE_CHECK_PLAN_FILE" ]]; then
    count_plan_phases
    # D3: a heading that looks like a phase heading but whose number token or status marker
    # falls outside the canonical vocabulary (e.g. `[DESCOPED]`, `3a`) makes the WHOLE count
    # INCONCLUSIVE, never a verdict derived from a partial match -- this is the fix for the
    # `[DESCOPED]` TOTAL-inflation defect: such a heading previously satisfied the TOTAL bracket
    # shape but never DONE, producing a permanent under-100% refusal.
    if has_nonconforming_phase_headings "$PHASE_CHECK_PLAN_FILE"; then
      PHASE_CHECK_NONCONFORMING=1
    fi
  fi

  if [[ -z "$PHASE_CHECK_PLAN_FILE" ]]; then
    echo "[phase-check] Task $task_number: no plan file resolved -- inconclusive, passing through." >&2
  elif [[ "$PHASE_CHECK_NONCONFORMING" -eq 1 ]]; then
    # Distinguishable from the "zero conforming headings" branch below: this plan HAS phase
    # headings, but at least one is non-conforming, so the count is refused rather than trusted.
    warn_nonconforming "$PHASE_CHECK_PLAN_FILE" "update-task-status" || true
    echo "[phase-check] Task $task_number: non-conforming phase heading(s) found in $(basename "$PHASE_CHECK_PLAN_FILE") -- INCONCLUSIVE (this plan HAS phase headings, but at least one falls outside the canonical vocabulary; see the warning above), passing through." >&2
  elif [[ "$PHASE_CHECK_TOTAL" -eq 0 ]]; then
    echo "[phase-check] Task $task_number: no conforming '### Phase N: ... [STATUS]' headings in $(basename "$PHASE_CHECK_PLAN_FILE") -- inconclusive, passing through." >&2
  elif [[ "$PHASE_CHECK_DONE" -ge "$PHASE_CHECK_TOTAL" ]]; then
    echo "[phase-check] Task $task_number: ${PHASE_CHECK_DONE}/${PHASE_CHECK_TOTAL} phases closed (COMPLETED or COMPLETED WITH EXCLUSIONS) in $(basename "$PHASE_CHECK_PLAN_FILE") -- proceeding." >&2
  else
    # Conclusive on-disk evidence of incompleteness.
    if [[ "$DRY_RUN" == "true" ]]; then
      # --dry-run is preview-only and never itself a failure signal, so it always exits 0 and
      # continues previewing the rest of the pipeline even under --phase-check=refuse. This lets
      # a caller preview a refusal without it looking like a script bug in a dry-run harness.
      echo "[dry-run] Phase-check (mode=${PHASE_CHECK}) would block this transition: ${PHASE_CHECK_DONE}/${PHASE_CHECK_TOTAL} phases complete in ${PHASE_CHECK_PLAN_FILE}"
    elif [[ "$PHASE_CHECK" == "refuse" ]]; then
      echo "Error: [phase-check] refusing postflight implement for task $task_number: only ${PHASE_CHECK_DONE}/${PHASE_CHECK_TOTAL} phases are closed (COMPLETED or COMPLETED WITH EXCLUSIONS) in ${PHASE_CHECK_PLAN_FILE}." >&2
      echo "       No state.json write and no plan-file status stamp occurred." >&2
      echo "       Finish the remaining phases, or correct the plan file's phase headings, and re-run." >&2
      exit 4
    else
      echo "WARNING: [phase-check] task $task_number is being marked completed with only ${PHASE_CHECK_DONE}/${PHASE_CHECK_TOTAL} phases closed (COMPLETED or COMPLETED WITH EXCLUSIONS) in ${PHASE_CHECK_PLAN_FILE}." >&2
    fi
  fi
fi

# ============================================================
# PHASE 0.5: Postflight completion-deploy gate (unconditional, check-only, exit 6)
# ============================================================
# Refuses the postflight/implement transition when this task's OWN .return-meta.json
# `modified_files` overlap `agent-system/extensions/**` (the directory-prefix rule in
# context/patterns/file-footprint-overlap.md, via scopes_overlap()) AND at least one touched
# extension is PROVABLY stale (scripts/lib/deploy-freshness-lib.sh's
# `deploy_freshness_status`). Unlike --phase-check above, this gate is UNCONDITIONAL -- no
# opt-in flag, always active on postflight/implement -- because "completed" must mean "in
# effect" for every source-store-touching task, not only ones whose caller remembered to opt in.
#
# CHECK-ONLY BY CONTRACT: this block never invokes the deploy/regeneration script or the
# deploy-verification script (their names are deliberately not spelled out literally anywhere
# in this file -- a mechanical `grep -c` for either name is part of this contract's own test
# coverage, see scripts/tests/test-postflight-deploy-gate.sh). The
# actual redeploy trigger lives exclusively at the two already-serialized call sites named in
# context/patterns/regeneration-is-manual-only.md's carve-out (command-gate-out.sh's rc==6
# branch for the single-task path; skill-orchestrate/SKILL.md's Stage MT-3 step 7 inter-cycle
# redeploy checkpoint for the multi-task batch path) --
# never here, where multi-task /implement's parallel per-task dispatch would race the
# fail-open specs/.deploy-lock mutex.
#
# Conclusiveness convention (mirrors the --phase-check block's own INCONCLUSIVE-passes-through
# posture): only "overlap AND provably stale" is conclusive evidence this transition must wait.
# Every other case -- no .return-meta.json, no/empty modified_files, no overlap, or freshness
# that cannot be established -- passes through unconditionally. This is the D4-mandated default
# permissive posture: since this gate is unconditional (not opt-in), a hard failure on ANY
# ambiguous or environment-error case would risk blocking completion system-wide.
if [[ "$operation" == "postflight" && "$target_status" == "implement" \
      && "$state_is_noop" != "true" ]]; then

  DEPLOY_CHECK_META_FILE=""
  resolve_return_meta_for_deploy_check() {
    local project_name padded_num task_dir_candidate meta_candidate
    project_name=$(jq -r --arg num "$task_number" \
      '.active_projects[] | select(.project_number == ($num | tonumber)) | .project_name' \
      "$STATE_FILE")
    if [[ -z "$project_name" || "$project_name" == "null" ]]; then
      return 0
    fi
    padded_num=$(printf "%03d" "$task_number")
    task_dir_candidate="$PROJECT_ROOT/specs/${padded_num}_${project_name}"
    if [[ ! -d "$task_dir_candidate" ]]; then
      task_dir_candidate="$PROJECT_ROOT/specs/${task_number}_${project_name}"
    fi
    meta_candidate="${task_dir_candidate}/.return-meta.json"
    [[ -f "$meta_candidate" ]] || return 0
    DEPLOY_CHECK_META_FILE="$meta_candidate"
    return 0
  }
  resolve_return_meta_for_deploy_check

  if [[ -z "$DEPLOY_CHECK_META_FILE" ]]; then
    echo "[deploy-check] Task $task_number: no .return-meta.json resolved -- inconclusive, passing through." >&2
  else
    DEPLOY_CHECK_MODIFIED_FILES="$(jq -c '.modified_files // []' "$DEPLOY_CHECK_META_FILE" 2>/dev/null)"
    if [[ -z "$DEPLOY_CHECK_MODIFIED_FILES" || "$DEPLOY_CHECK_MODIFIED_FILES" == "null" ]]; then
      DEPLOY_CHECK_MODIFIED_FILES="[]"
    fi
    DEPLOY_CHECK_MODIFIED_COUNT="$(echo "$DEPLOY_CHECK_MODIFIED_FILES" | jq 'length' 2>/dev/null)"
    [[ "$DEPLOY_CHECK_MODIFIED_COUNT" =~ ^[0-9]+$ ]] || DEPLOY_CHECK_MODIFIED_COUNT=0

    if [[ "$DEPLOY_CHECK_MODIFIED_COUNT" -eq 0 ]]; then
      echo "[deploy-check] Task $task_number: empty or absent modified_files in $(basename "$DEPLOY_CHECK_META_FILE") -- inconclusive, passing through." >&2
    else
      # --- Shared overlap predicate library (deploy-tree-first / source-store-fallback, same
      # resolution pattern as the phase-heading library above). A missing library here is
      # INCONCLUSIVE pass-through (per D4's reasoning applied uniformly across this whole
      # unconditional block), never the loud exit-5 the phase-heading/status-vocabulary
      # libraries use above -- those are pre-existing, always-sourced dependencies; this one is
      # new and local to an unconditional gate that must never system-wide-block on an
      # environment accident.
      OVERLAP_LIB_CANDIDATES=(
        "$PROJECT_ROOT/.claude/scripts/lib/file-scope-overlap.sh"
        "$PROJECT_ROOT/agent-system/extensions/core/scripts/lib/file-scope-overlap.sh"
      )
      OVERLAP_LIB=""
      for _ov_candidate in "${OVERLAP_LIB_CANDIDATES[@]}"; do
        if [[ -f "$_ov_candidate" ]]; then
          OVERLAP_LIB="$_ov_candidate"
          break
        fi
      done

      if [[ -z "$OVERLAP_LIB" ]]; then
        echo "[deploy-check] Task $task_number: shared library file-scope-overlap.sh not found -- inconclusive, passing through." >&2
      # `if ! . "$OVERLAP_LIB" ...; then` (not a bare `. "$OVERLAP_LIB"`) is required, not
      # stylistic: file-scope-overlap.sh's own FILE_SCOPE_OVERLAP_JQ_DEFS assignment uses
      # `read -r -d '' ... <<'JQDEFS'`, which returns exit 1 at heredoc EOF even on a fully
      # successful read (a documented bash `read -d ''` quirk) -- under this script's own
      # `set -e`, a bare source would abort the whole script right here. task-lock.sh's own
      # `ensure_file_scope_overlap_lib` sources this same file with the identical
      # `if ! . ... ; then` guard for the identical reason; this mirrors that precedent rather
      # than inventing a new one.
      elif ! . "$OVERLAP_LIB" 2>/dev/null; then
        echo "[deploy-check] Task $task_number: shared library file-scope-overlap.sh failed to source -- inconclusive, passing through." >&2
      else
        DEPLOY_CHECK_OVERLAP_HIT="$(scopes_overlap "$DEPLOY_CHECK_MODIFIED_FILES" '["agent-system/extensions"]')"

        if [[ -z "$DEPLOY_CHECK_OVERLAP_HIT" ]]; then
          echo "[deploy-check] Task $task_number: modified_files do not overlap agent-system/extensions/** -- not applicable, passing through." >&2
        else
          # --- Shared freshness library (same deploy-tree-first / source-store-fallback
          # resolution). Missing here is likewise INCONCLUSIVE pass-through (D4), never exit 5.
          FRESHNESS_LIB_CANDIDATES=(
            "$PROJECT_ROOT/.claude/scripts/lib/deploy-freshness-lib.sh"
            "$PROJECT_ROOT/agent-system/extensions/core/scripts/lib/deploy-freshness-lib.sh"
          )
          DEPLOY_FRESHNESS_LIB=""
          for _df_candidate in "${FRESHNESS_LIB_CANDIDATES[@]}"; do
            if [[ -f "$_df_candidate" ]]; then
              DEPLOY_FRESHNESS_LIB="$_df_candidate"
              break
            fi
          done

          if [[ -z "$DEPLOY_FRESHNESS_LIB" ]]; then
            echo "[deploy-check] Task $task_number: shared library deploy-freshness-lib.sh not found -- inconclusive, passing through." >&2
          else
            # shellcheck disable=SC1090
            . "$DEPLOY_FRESHNESS_LIB"

            # Derive the distinct set of touched extension names from modified_files entries
            # under agent-system/extensions/<name>/... (the 3rd path segment). Stale-wins over
            # cannot-verify over fresh: refuse if ANY touched extension is provably stale;
            # otherwise inconclusive-pass-through if ANY cannot be verified; otherwise proceed.
            DEPLOY_CHECK_EXT_NAMES="$(echo "$DEPLOY_CHECK_MODIFIED_FILES" | jq -r '
              .[] | select(startswith("agent-system/extensions/")) |
              split("/") | .[2]
            ' 2>/dev/null | sort -u)"

            DEPLOY_CHECK_ANY_STALE=""
            DEPLOY_CHECK_ANY_CANNOTVERIFY=""
            while IFS= read -r _ext_name; do
              [[ -n "$_ext_name" ]] || continue
              _ext_status="$(deploy_freshness_status "$PROJECT_ROOT" "$_ext_name")"
              case "$_ext_status" in
                STALE) DEPLOY_CHECK_ANY_STALE="$_ext_name" ;;
                CANNOTVERIFY) DEPLOY_CHECK_ANY_CANNOTVERIFY="$_ext_name" ;;
              esac
            done <<< "$DEPLOY_CHECK_EXT_NAMES"

            if [[ -n "$DEPLOY_CHECK_ANY_STALE" ]]; then
              if [[ "$DRY_RUN" == "true" ]]; then
                echo "[dry-run] Deploy-check would block this transition: extension '${DEPLOY_CHECK_ANY_STALE}' is stale (task $task_number touches ${DEPLOY_CHECK_OVERLAP_HIT})."
              else
                echo "Error: [deploy-check] refusing postflight implement for task $task_number: extension '${DEPLOY_CHECK_ANY_STALE}' is stale relative to its source store (touched path: ${DEPLOY_CHECK_OVERLAP_HIT})." >&2
                echo "       No state.json write and no plan-file status stamp occurred." >&2
                echo "       Remedy: run the deploy/regeneration step (or the picker's [Reload All] / 'Regenerate'), then re-run. See context/patterns/regeneration-is-manual-only.md." >&2
                exit 6
              fi
            elif [[ -n "$DEPLOY_CHECK_ANY_CANNOTVERIFY" ]]; then
              echo "[deploy-check] Task $task_number: freshness of extension '${DEPLOY_CHECK_ANY_CANNOTVERIFY}' cannot be verified -- inconclusive, passing through." >&2
            else
              echo "[deploy-check] Task $task_number: touched extension(s) verified fresh -- proceeding." >&2
            fi
          fi
        fi
      fi
    fi
  fi
fi

# ============================================================
# PHASE 1+2 (combined): Update state.json (machine state first) and regenerate TODO.md, both
# via ONE state-write.sh call with --regen-todo so TODO.md regeneration happens INSIDE the same
# critical section as the write that triggered it, rather than as a separate step after release.
# PHASE 1 is skipped (a `.` identity filter is written instead) when state_is_noop -- but PHASE 2
# (TODO.md regen) still runs unconditionally, protected by the SAME mutex a real write would use,
# preserving the pre-existing "self-healing on retry" property (PHASE 3's plan/phase updates
# below re-fire on retry even when state.json itself is already converged).
# ============================================================
update_state_json() {
  local ts
  ts="$(common_timestamp_iso)"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] state.json: task $task_number status '$current_state_status' -> '$STATE_STATUS'"
    echo "[dry-run] state.json: last_updated -> '$ts', session_id -> '$session_id'"
    if [[ "$FILE_SCOPE_ADD_LEN" -gt 0 ]]; then
      echo "[dry-run] state.json: file_scope union-merge -> add ${FILE_SCOPE_ADD}"
    fi
    if [[ "$RESEARCH_QUESTIONS_LEN" -gt 0 ]]; then
      echo "[dry-run] state.json: research_questions overwrite -> ${RESEARCH_QUESTIONS}"
    fi
    if [[ "$HOLD_SET" == "true" ]]; then
      echo "[dry-run] state.json: hold_reason -> '${HOLD_REASON}', held_at -> '${ts:0:10}', prior_status -> '${HOLD_PRIOR_STATUS}'"
    fi
    if [[ "$UNHOLD_SET" == "true" ]]; then
      echo "[dry-run] state.json: clearing hold_reason/held_at/prior_status (unhold -> '${STATE_STATUS}')"
    fi
    echo "[dry-run] TODO.md: regenerate from state.json via generate-todo.sh"
    return 0
  fi

  if [[ "$state_is_noop" == "true" ]]; then
    # Preserves the original guard exactly: the workflow-active marker write below is scoped to
    # the REAL (non-noop) write path only, matching pre-conversion behavior byte-for-byte -- a
    # noop preflight replay does not refresh the marker. A pending --file-scope-add still rides
    # along even on a status no-op (e.g. a research postflight re-run against an already
    # "researched" task proposing further paths) -- status is unaffected either way, so this
    # merge is independent of the noop/real-write branch.
    if [[ "$FILE_SCOPE_ADD_LEN" -gt 0 ]]; then
      "$SCRIPT_DIR/state-write.sh" \
        '(.active_projects[] | select(.project_number == ($num | tonumber)) | .file_scope) |= ((. // []) + $add | unique)' \
        --session-id "$session_id" \
        --arg num "$task_number" \
        --argjson add "$FILE_SCOPE_ADD" \
        --regen-todo || {
        echo "Warning: state-write.sh failed during no-op file_scope merge (non-fatal)" >&2
      }
    elif [[ "$RESEARCH_QUESTIONS_LEN" -gt 0 ]]; then
      # Mirrors the file_scope no-op branch above, except OVERWRITE (`= $rq`) rather than
      # union-merge -- a status no-op (e.g. a needs_research postflight re-run against a task
      # already at 'researching') still fully replaces the question list with this call's value.
      "$SCRIPT_DIR/state-write.sh" \
        '(.active_projects[] | select(.project_number == ($num | tonumber)) | .research_questions) = $rq' \
        --session-id "$session_id" \
        --arg num "$task_number" \
        --argjson rq "$RESEARCH_QUESTIONS" \
        --regen-todo || {
        echo "Warning: state-write.sh failed during no-op research_questions overwrite (non-fatal)" >&2
      }
    elif [[ "$HOLD_SET" == "true" ]]; then
      # Reached only when the task was ALREADY held (STATE_STATUS="hold" == current_state_status
      # made this a status no-op) -- i.e. this preflight:hold call is updating an existing hold's
      # reason, not setting a fresh one. prior_status was already resolved as the EXISTING
      # recorded value above (never overwritten with "hold" itself).
      "$SCRIPT_DIR/state-write.sh" \
        '(.active_projects[] | select(.project_number == ($num | tonumber)) | .hold_reason) = $hold_reason
         | (.active_projects[] | select(.project_number == ($num | tonumber)) | .held_at) = $held_at
         | (.active_projects[] | select(.project_number == ($num | tonumber)) | .prior_status) = $prior_status' \
        --session-id "$session_id" \
        --arg num "$task_number" \
        --arg hold_reason "$HOLD_REASON" \
        --arg held_at "${ts:0:10}" \
        --arg prior_status "$HOLD_PRIOR_STATUS" \
        --regen-todo || {
        echo "Warning: state-write.sh failed during no-op hold-reason update (non-fatal)" >&2
      }
    else
      "$SCRIPT_DIR/state-write.sh" '.' --session-id "$session_id" --regen-todo || {
        echo "Warning: state-write.sh failed during no-op TODO.md regen (non-fatal)" >&2
      }
    fi
    return 0
  fi

  # Write workflow-active marker on preflight so the Stop hook can suppress mid-workflow fires
  # (a plain file write, unrelated to the specs/state.json mutex).
  #
  # Per-session form: suffixed by Claude Code's OWN native session UUID
  # ($CLAUDE_CODE_SESSION_ID, exported into every Bash tool invocation -- the SAME id space
  # hook stdin's top-level `.session_id` field carries, captured as CC_SESSION_ID by every
  # consumer hook; see events-log-lifecycle.sh's header comment for the two-id-spaces
  # explanation). This is a DIFFERENT id space from this script's own `$session_id` positional
  # argument (the agent-system `sess_...` id, finer-grained -- regenerated per command
  # invocation within one Claude Code session), which is why the marker is keyed by the native
  # UUID rather than by `$session_id`: one Claude Code session's Stop-hook lifecycle spans
  # potentially several agent-system sessions, and the marker exists to answer "is THIS Claude
  # Code session mid-workflow", not "is this one command invocation mid-workflow". Falls back to
  # the agent-system `$session_id` when the native UUID is unavailable (e.g. a manual/test
  # invocation outside Claude Code), so the marker is always still per-invocation-unique rather
  # than silently reverting to the old shared fixed path.
  if [[ "$operation" == "preflight" ]]; then
    local marker_session_key="${CLAUDE_CODE_SESSION_ID:-$session_id}"
    mkdir -p "$SCRIPT_DIR/../tmp"
    echo "$task_number $(common_timestamp_iso)" > "$SCRIPT_DIR/../tmp/workflow-active-${marker_session_key}"
  fi

  # The --file-scope-add union-merge rides along inside this SAME state-write.sh invocation's jq
  # filter, scoped to the matching active_projects[] entry -- never a second write. Only a
  # genuinely non-empty array extends the filter; an absent flag or an empty array leaves the
  # base filter untouched (see FILE_SCOPE_ADD_LEN's byte-for-byte no-op comment above).
  local jq_filter='(.active_projects[] | select(.project_number == ($num | tonumber))) |= . + {
      status: $status,
      last_updated: $ts,
      session_id: $sid
    }'
  local jq_args=(
    --session-id "$session_id"
    --arg num "$task_number"
    --arg status "$STATE_STATUS"
    --arg ts "$ts"
    --arg sid "$session_id"
  )

  if [[ "$FILE_SCOPE_ADD_LEN" -gt 0 ]]; then
    jq_filter='(.active_projects[] | select(.project_number == ($num | tonumber))) |= . + {
      status: $status,
      last_updated: $ts,
      session_id: $sid
    } | (.active_projects[] | select(.project_number == ($num | tonumber)) | .file_scope) |= ((. // []) + $add | unique)'
    jq_args+=(--argjson add "$FILE_SCOPE_ADD")
  fi

  # The --research-questions overwrite rides along the same way, mutually exclusive with the
  # file_scope clause above by the flags' own operation/target_status restrictions (never both
  # non-zero on the same invocation). OVERWRITE (`= $rq`), not union-merge -- see the flag's own
  # header comment for why.
  if [[ "$RESEARCH_QUESTIONS_LEN" -gt 0 ]]; then
    jq_filter='(.active_projects[] | select(.project_number == ($num | tonumber))) |= . + {
      status: $status,
      last_updated: $ts,
      session_id: $sid
    } | (.active_projects[] | select(.project_number == ($num | tonumber)) | .research_questions) = $rq'
    jq_args+=(--argjson rq "$RESEARCH_QUESTIONS")
  fi

  # preflight:hold -- sets the three new fields in the SAME state-write.sh invocation as the
  # status write (never a second write). Mutually exclusive with FILE_SCOPE_ADD/RESEARCH_QUESTIONS
  # above by the flags' own operation/target_status restrictions.
  if [[ "$HOLD_SET" == "true" ]]; then
    jq_filter='(.active_projects[] | select(.project_number == ($num | tonumber))) |= . + {
      status: $status,
      last_updated: $ts,
      session_id: $sid,
      hold_reason: $hold_reason,
      held_at: $held_at,
      prior_status: $prior_status
    }'
    jq_args+=(--arg hold_reason "$HOLD_REASON" --arg held_at "${ts:0:10}" --arg prior_status "$HOLD_PRIOR_STATUS")
  fi

  # preflight:unhold -- restores STATE_STATUS (resolved to the recorded prior_status above, ahead
  # of map_status()) and clears the three hold fields via del(...) -- field OMISSION, not nulling,
  # matching this codebase's convention for present-only-in-one-state fields (completion_summary).
  if [[ "$UNHOLD_SET" == "true" ]]; then
    jq_filter='(.active_projects[] | select(.project_number == ($num | tonumber))) |= (. + {
      status: $status,
      last_updated: $ts,
      session_id: $sid
    } | del(.hold_reason, .held_at, .prior_status))'
  fi

  if ! "$SCRIPT_DIR/state-write.sh" \
    "$jq_filter" \
    "${jq_args[@]}" \
    --regen-todo; then
    return 1
  fi
}

if ! update_state_json; then
  echo "Error: failed to update state.json for task $task_number" >&2
  exit 2
fi

# ============================================================
# PHASE 3: Plan file status (optional, implement only)
# ============================================================
update_plan_file() {
  # This guard is the sole bound on every plan-file side effect below: research and plan
  # operations never reach the plan-level [STATUS] write, because target_status is never
  # "implement" for those operations. This function no longer touches any per-phase marker
  # (no "first NOT STARTED phase" convenience) -- the dispatched implementation agent owns
  # every per-phase [IN PROGRESS]/[COMPLETED] transition directly, via its own explicit
  # phase-status calls. Only update plan file for implement operations.
  if [[ "$target_status" != "implement" ]]; then
    return 0
  fi

  local plan_status
  case "$operation" in
    preflight)  plan_status="IMPLEMENTING" ;;
    postflight) plan_status="COMPLETED" ;;
  esac

  # Look up project_name from state.json
  local project_name
  project_name=$(jq -r --arg num "$task_number" \
    '.active_projects[] | select(.project_number == ($num | tonumber)) | .project_name' \
    "$STATE_FILE")

  if [[ -z "$project_name" || "$project_name" == "null" ]]; then
    echo "Warning: could not determine project_name for task $task_number" >&2
    return 0
  fi

  local plan_script="$SCRIPT_DIR/update-plan-status.sh"
  if [[ ! -x "$plan_script" ]]; then
    echo "Warning: update-plan-status.sh not found or not executable" >&2
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] Plan file: status -> [$plan_status] (via update-plan-status.sh)"
    return 0
  fi

  # Call existing script. It is already fail-loud on its own diagnostic ("Failed to update
  # status in $plan_file"); do not discard its stderr here. Branch fatal-vs-warn on operation:
  # a failed [COMPLETED] write on implement postflight leaves state.json and the plan file in
  # permanent, externally-invisible disagreement -- generate-todo.sh reads only state.json,
  # never plan files, so no other surface reveals the divergence -- making that path fatal. A
  # failed [IMPLEMENTING] write on preflight is advisory (work is starting either way), so it
  # stays a non-fatal warning.
  cd "$PROJECT_ROOT"
  if ! "$plan_script" "$task_number" "$project_name" "$plan_status"; then
    if [[ "$operation" == "postflight" ]]; then
      echo "Error: failed to update plan file status to [$plan_status] for task $task_number." >&2
      echo "       state.json was already written to '$STATE_STATUS'; this is retryable -- the" >&2
      echo "       state.json write is idempotent and will no-op on retry, while the plan/phase" >&2
      echo "       updates below re-fire until they converge." >&2
      exit 3
    else
      echo "Warning: plan file update failed (non-fatal)" >&2
      echo "         Task $task_number ($project_name): the line-numbered diagnostic from" >&2
      echo "         update-plan-status.sh above names the malformed plan-level Status line." >&2
      echo "         This is the leading indicator of a fatal failure at implement postflight" >&2
      echo "         (exit 3) if the plan file is not fixed before then." >&2
    fi
  fi
}

# state.json write + TODO.md regen already happened together, inside state-write.sh's own
# mutex-guarded critical section, via the single update_state_json call above. PHASE 3's
# plan-file update below is explicitly outside that critical section -- it does not touch
# state.json or TODO.md.

# Execute plan file update
update_plan_file

# ============================================================
# PHASE 4: Clear the deploy_pending marker at the completion chokepoint
# ============================================================
# skill-base.sh's skill_postflight_update sets `deploy_pending` / `deploy_pending_reason` on
# this task's OWN .return-meta.json when PHASE 0.5 above refuses with exit 6. Nothing ever
# cleared it, which left the identical-dispatch streak-freeze (orchestrate-cycle-plan.sh)
# permanently armed for any task that was ever deploy-pending, even long after the extension
# became fresh again. This is the single chokepoint for clearing it: both the ordinary
# `skill_postflight_update` path (skill-base.sh) and `reconcile-task-status.sh`'s direct
# `update-task-status.sh postflight <n> implement <sid>` call funnel through this same script,
# so clearing it here covers both callers without either needing its own copy. Only fires once
# the completion write for this exact transition (postflight/implement, non-noop, non-dry-run)
# has already succeeded -- by this point in the script, PHASE 0.5's exit 6 (stale extension) and
# update_state_json's/update_plan_file's own fatal exits have already returned control here, so
# reaching this line means the write went through. A noop replay (state_is_noop == true, e.g. a
# retry against an already-completed task) skips this: PHASE 0.5 does not run on that path
# either, so DEPLOY_CHECK_META_FILE is never resolved, and the marker (if any) was already
# cleared by the original successful write.
if [[ "$operation" == "postflight" && "$target_status" == "implement" \
      && "$state_is_noop" != "true" && "$DRY_RUN" != "true" ]]; then
  if [[ -n "${DEPLOY_CHECK_META_FILE:-}" ]]; then
    _dp_clear_tmp="$(mktemp)"
    if jq 'del(.deploy_pending, .deploy_pending_reason)' "$DEPLOY_CHECK_META_FILE" > "$_dp_clear_tmp" 2>/dev/null; then
      mv "$_dp_clear_tmp" "$DEPLOY_CHECK_META_FILE"
    else
      rm -f "$_dp_clear_tmp" 2>/dev/null
      echo "WARNING: [deploy-check] failed to clear deploy_pending marker in $(basename "$DEPLOY_CHECK_META_FILE") for task $task_number (non-fatal)" >&2
    fi
  fi
fi

if [[ "$DRY_RUN" != "true" ]]; then
  if [[ "$state_is_noop" == "true" ]]; then
    echo "OK: task $task_number state.json already at '$STATE_STATUS' (no-op); plan/phase updates re-applied"
  else
    echo "OK: task $task_number status -> $STATE_STATUS"
  fi
fi

exit 0
