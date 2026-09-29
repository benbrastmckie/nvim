#!/usr/bin/env bash
# orchestrator-postflight.sh — Shared postflight pipeline for research, plan, and implement operations
#
# Usage:
#   bash .claude/scripts/orchestrator-postflight.sh \
#       TASK_NUMBER PROJECT_NAME PADDED_NUM SESSION_ID OPERATION_TYPE [TASK_TYPE]
#
# Arguments:
#   TASK_NUMBER     Unpadded task number (e.g. 657)
#   PROJECT_NAME    Task slug from state.json (e.g. create_shared_orchestrator_postflight)
#   PADDED_NUM      Zero-padded task number (e.g. 657)
#   SESSION_ID      Session identifier (e.g. sess_1736700000_abc123)
#   OPERATION_TYPE  One of: research | plan | implement
#   TASK_TYPE       (Optional) Task type for meta-skip logic (e.g. meta, general). Used by implement
#                   to decide whether to write roadmap_items.
#
# Operation Mappings:
#   research  -> success_status: "researched",  artifact_type: "research",  artifact_kind: "report"
#                git commit: NO (matches existing researcher behavior)
#                stage 7a: increment next_artifact_number
#   plan      -> success_status: "planned",     artifact_type: "plan",      artifact_kind: "plan"
#                git commit: YES
#   implement -> success_status: "implemented", artifact_type: "summary",   artifact_kind: "summary"
#                git commit: YES
#                note: for implement, status update + completion_data + roadmap_items + memory_candidates
#                      must be handled INLINE in the skill before calling this script.
#                      This script handles: link artifacts, generate-todo, TTS, git commit, cleanup.
#
# Stages (implemented inside this script):
#   Stage 6:  Read .return-meta.json (status, artifact_path, artifact_type, artifact_summary,
#             memory_candidates, reflection; implement also reads completion_summary,
#             roadmap_items, handoff_path)
#   Stage 6a: Validate artifact via validate-artifact.sh (non-blocking)
#   Stage 6b: Emit orchestrator_status event, plus a second independent reflection event when a
#             reflection object is present (non-blocking)
#   Stage 7:  Call update-task-status.sh postflight (research and plan only; implement does inline)
#   Stage 7a: Increment next_artifact_number via state-write.sh (research only)
#   Stage 7b: Write completion_summary + roadmap_items to state.json (implement only)
#   Stage 7c: Propagate memory_candidates via state-write.sh, --argjson payload (all operations)
#   Stage 7d: Write reflection to state.json via state-write.sh, --argjson, overwrite semantics
#             (implement-only, gated on status == implemented; non-blocking)
#   Stage 8:  Link artifacts in state.json via two state-write.sh calls with --arg atype
#             (Issue #1132 safe)
#   Stage 8a: Regenerate TODO.md via generate-todo.sh (non-blocking)
#   Stage 8b: Fire TTS lifecycle notification via lifecycle-notify.sh in background (non-blocking)
#   Stage 9:  Git commit with operation-specific message (plan and implement only; non-blocking)
#   Stage 10: Cleanup marker files (.postflight-pending, .postflight-loop-guard, .return-meta.json,
#             .continuation-loop-guard for implement)
#
# Error handling:
#   - Non-success status: skips status update and git commit; still runs cleanup
#   - Missing metadata file: sets status="failed", still runs cleanup
#   - All postflight steps except status update are non-blocking (|| true or background)
#
# jq Safety:
#   - All jq filter expressions use --arg / --argjson to avoid Issue #1132
#   - select(.type == "X" | not) is used instead of select(.type != "X")
#
# Exit codes:
#   0 - Postflight completed (even if status was non-success — cleanup always runs)
#   1 - Fatal: missing required arguments
#
# Downstream dependencies:
#   - Historical: the three base lifecycle skills (research/plan/implement) called this script
#     for their postflight stages before they were deleted. No current caller invokes this
#     script directly (skill-orchestrate handles research/plan/implement postflight inline via
#     skill-base.sh instead) -- confirmed orphaned by a repo-wide grep for actual invocation
#     sites (`bash .../orchestrator-postflight.sh` / `source .../orchestrator-postflight.sh`).
#     Retained for reference; see skill-git-workflow/SKILL.md for the current commit-scope
#     execution sites.

set -euo pipefail

# Source the shared skill-lifecycle library for skill_propagate_completion_summary (Stage 7b
# below). Not sourced elsewhere in this script, so it is sourced once here at the top.
source .claude/scripts/skill-base.sh

# ─────────────────────────────────────────────────────────────────────────────
# Observable-but-non-fatal wrapper around events-append.sh.
#
# Replaces the bare `bash .claude/scripts/events-append.sh ... || echo "WARNING..." >&2` idiom
# at Stage 6b's two call sites below. ALWAYS returns 0 (this script runs under `set -e`, so a
# non-zero return here would abort the rest of postflight -- unacceptable for a non-blocking
# event append). Distinguishes "helper missing/not executable" from "helper present but exited
# non-zero" in both a one-time-per-process stderr WARNING and a durable sentinel marker under
# .claude/tmp/, generalizing the pattern already used by skill-base.sh's identical helper.
#
# Usage: _events_append_observable ".claude/scripts/events-append.sh" --event-type ... [args...]
_EVENTS_APPEND_OBSERVABLE_WARNED=""
_events_append_observable() {
  local helper_path="$1"
  shift
  local kind="" exit_code=""
  if [ ! -x "$helper_path" ]; then
    kind="missing"
  else
    if "$helper_path" "$@" >/dev/null 2>&1; then
      exit_code=0
    else
      exit_code=$?
      kind="failed"
    fi
  fi
  if [ -n "$kind" ]; then
    if [ -z "$_EVENTS_APPEND_OBSERVABLE_WARNED" ]; then
      if [ "$kind" = "missing" ]; then
        echo "[postflight] WARNING: events-append.sh helper missing or not executable at ${helper_path} (non-blocking)" >&2
      else
        echo "[postflight] WARNING: events-append.sh helper present but failed (exit ${exit_code}) at ${helper_path} (non-blocking)" >&2
      fi
      _EVENTS_APPEND_OBSERVABLE_WARNED=1
    fi
    mkdir -p ".claude/tmp" 2>/dev/null
    printf '{"kind":"%s","helper_path":"%s","exit_code":"%s","ts":"%s"}\n' \
      "$kind" "$helper_path" "$exit_code" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      >> ".claude/tmp/events-append-observable.log" 2>/dev/null
  fi
  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────────────────────────────────────
if [ $# -lt 5 ]; then
  echo "Usage: $0 TASK_NUMBER PROJECT_NAME PADDED_NUM SESSION_ID OPERATION_TYPE [TASK_TYPE]" >&2
  echo "" >&2
  echo "Arguments:" >&2
  echo "  TASK_NUMBER     Unpadded task number" >&2
  echo "  PROJECT_NAME    Task slug from state.json" >&2
  echo "  PADDED_NUM      Zero-padded task number" >&2
  echo "  SESSION_ID      Session identifier" >&2
  echo "  OPERATION_TYPE  research | plan | implement" >&2
  echo "  TASK_TYPE       (Optional) task type; used by implement to skip roadmap_items for meta" >&2
  exit 1
fi

task_number="$1"
project_name="$2"
padded_num="$3"
session_id="$4"
operation_type="$5"
task_type="${6:-general}"

# Start timer for the unified event store's Stage 6b duration (covers this postflight pipeline,
# from argument parsing through status resolution below).
_postflight_t0=$(date +%s.%N)

task_dir="specs/${padded_num}_${project_name}"
metadata_file="${task_dir}/.return-meta.json"

# ─────────────────────────────────────────────────────────────────────────────
# Operation type mapping
# ─────────────────────────────────────────────────────────────────────────────
case "$operation_type" in
  research)
    success_status="researched"
    artifact_type="research"
    artifact_kind="report"
    do_git_commit="false"
    do_status_update="true"
    do_artifact_increment="true"
    commit_message="task ${task_number}: complete research"
    ;;
  plan)
    success_status="planned"
    artifact_type="plan"
    artifact_kind="plan"
    do_git_commit="true"
    do_status_update="true"
    do_artifact_increment="false"
    commit_message="task ${task_number}: create implementation plan"
    ;;
  implement)
    success_status="implemented"
    artifact_type="summary"
    artifact_kind="summary"
    do_git_commit="true"
    do_status_update="false"
    do_artifact_increment="false"
    commit_message="task ${task_number}: complete implementation"
    ;;
  *)
    echo "Error: Unknown operation type '${operation_type}'. Expected: research, plan, implement" >&2
    exit 1
    ;;
esac

# Guard: ensure specs/tmp/ exists
mkdir -p specs/tmp

echo "[postflight] Starting postflight for task ${task_number} (${operation_type})"

# ─────────────────────────────────────────────────────────────────────────────
# Stage 6: Read .return-meta.json
# ─────────────────────────────────────────────────────────────────────────────
status="failed"
artifact_path=""
artifact_type_from_meta=""
artifact_summary=""
memory_candidates="[]"
completion_summary=""
roadmap_items="[]"
handoff_path=""
reflection="null"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
  # Route status/artifacts/memory_candidates through the shared skill_read_metadata chokepoint
  # (already sourced above) rather than duplicating the .artifacts[0].* jq expressions here --
  # this is the SAME normalizing chokepoint skill_read_metadata implements: a malformed
  # (bare-string) artifacts array is recovered in-memory (never rewritten on disk), loudly
  # warned on stderr, and recorded as ARTIFACTS_SHAPE_MISMATCH. See
  # context/formats/return-metadata-file.md's `artifacts (required)` section.
  skill_read_metadata "$padded_num" "$project_name"
  status="$SUBAGENT_STATUS"
  artifact_path="$ARTIFACT_PATH"
  artifact_type_from_meta="$ARTIFACT_TYPE"
  artifact_summary="$ARTIFACT_SUMMARY"
  memory_candidates="$MEMORY_CANDIDATES"
  reflection=$(jq -c '.reflection // null' "$metadata_file")

  # implement-specific fields (safe to read for all operations — will be empty for non-implement)
  completion_summary=$(jq -r '.completion_data.completion_summary // ""' "$metadata_file")
  roadmap_items=$(jq -c '.completion_data.roadmap_items // []' "$metadata_file")
  handoff_path=$(jq -r '.partial_progress.handoff_path // ""' "$metadata_file")
else
  echo "[postflight] WARNING: Invalid or missing metadata file: ${metadata_file}" >&2
  echo "[postflight] Setting status=failed and proceeding to cleanup"
  status="failed"
fi

echo "[postflight] Subagent status: ${status}"

# Use artifact_type from operation mapping if not overridden by metadata
if [ -z "$artifact_type_from_meta" ]; then
  artifact_type_from_meta="$artifact_type"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Stage 6b: Emit exactly one success/blocker/deviation event to the unified event store,
# cross-linked to specs/errors.json when present. Never fatal: absence/malformedness of
# errors.json degrades to an empty error_ref, and events-append.sh failure is swallowed.
# ─────────────────────────────────────────────────────────────────────────────
case "$status" in
  "$success_status") event_category="success" ;;
  failed|blocked) event_category="blocker" ;;
  partial) event_category="deviation" ;;
  *) event_category="deviation" ;;
esac

event_duration=$(awk -v a="$_postflight_t0" -v b="$(date +%s.%N)" 'BEGIN{printf "%.3f", b-a}')

error_ref=""
if [ -f specs/errors.json ] && jq empty specs/errors.json 2>/dev/null; then
  error_ref=$(jq -r --arg sid "$session_id" \
    '[.errors[]? | select(.context.session_id == $sid)] | sort_by(.timestamp) | last | .id // empty' \
    specs/errors.json 2>/dev/null || true)
fi

event_args=(--event-type orchestrator_status --category "$event_category" \
  --checkpoint postflight --task "$task_number" --session "$session_id" \
  --duration "$event_duration" \
  --message "Orchestrator postflight resolved status '${status}' for ${operation_type}")
if [ -n "$error_ref" ] && [ "$error_ref" != "null" ]; then
  event_args+=(--error-ref "$error_ref")
fi

_events_append_observable ".claude/scripts/events-append.sh" "${event_args[@]}"

# Second, independent event: log a completion-time reflection when present. Never reuses the
# orchestrator_status event line above; guarded and non-blocking so a reflection-event failure
# cannot affect the rest of postflight.
if [ "$reflection" != "null" ] && [ -n "$reflection" ]; then
  _events_append_observable ".claude/scripts/events-append.sh" \
    --event-type reflection --category success \
    --checkpoint postflight --task "$task_number" --session "$session_id" \
    --detail-json "$reflection" \
    --message "Completion-time reflection captured for task ${task_number}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Stage 6a: Validate artifact (non-blocking)
# ─────────────────────────────────────────────────────────────────────────────
if [ "$status" = "$success_status" ] || [ "$status" = "partial" ]; then
  if [ -n "$artifact_path" ] && [ -f "$artifact_path" ]; then
    echo "[postflight] Validating ${artifact_kind} artifact: ${artifact_path}"
    if ! bash .claude/scripts/validate-artifact.sh "$artifact_path" "$artifact_kind" --fix 2>/dev/null; then
      echo "[postflight] WARNING: ${artifact_kind} artifact has format issues (non-blocking). Review output above." >&2
    fi
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# specs/.scope-lock mutex: brackets Stages 7 through 8a (the state.json read-modify-write +
# TODO.md-regen window) — see .claude/context/patterns/task-lock.md's scope-acquire/scope-release
# section and .claude/context/standards/git-staging-scope.md's state-write hazard note. Stage 8b
# (TTS) stays explicitly OUTSIDE this mutex — it is comparatively slow and carries no
# data-integrity risk. Stage 9 (git commit) ALSO stays outside THIS mutex (the state-write
# concern is unrelated to committing), but is no longer unserialized: it now runs inside a
# second, distinct specs/.commit-lock mutex via git-commit-scoped.sh (see that script and
# task-lock.md's "Commit-Mutex CLI" section) — concurrent multi-task dispatch invalidated the
# "no data-integrity risk worth serializing" reasoning this comment used to make about commits
# specifically; see git-staging-scope.md's corrected "State-Write Serialization" section.
#
# Mutex-ownership shape (decided, not incidental): every write below (Stages 7a, 7c, 7d, 8) now
# routes through state-write.sh, the single mutex-guarded specs/state.json writer, so this
# script no longer needs to hand-roll its own acquire at all -- state-write.sh's own internal
# acquire would suffice on its own. The bracket below is kept anyway, on purpose, because it
# preserves the pre-existing ALL-STAGES-ATOMIC property (Stages 7a through 8 execute as one
# indivisible unit relative to a concurrent postflight run touching the same task, rather than
# each stage separately racing for the mutex). `POSTFLIGHT_SCOPE_STALE_SEC` is holder-declared
# (see task-lock.sh's acquire_scope_mutex), well above the measured worst-case wall-clock time
# for this span.
#
# Acquire posture (changed from fail-open): a failed acquire here no longer proceeds
# unserialized -- that fail-open branch is exactly the defect this codebase-wide conversion
# removes. Instead, on a bracket-acquire timeout, SCOPE_MUTEX_HELD is left unexported and each
# write stage below falls through to state-write.sh's OWN fail-closed acquire, made
# independently per stage. This degrades gracefully rather than hard-aborting the whole
# postflight run: the combined all-stages-atomic bracket is lost for this one run (a real but
# narrow cost, confined to the rare case where even the FIRST acquire attempt in the whole
# window times out), but no stage ever writes unserialized -- every write remains fail-closed,
# exactly like every other converted writer in this codebase.
# ─────────────────────────────────────────────────────────────────────────────
POSTFLIGHT_SCOPE_STALE_SEC=30
_scope_mutex_held_here="false"
scope_token=""
if scope_token=$(bash .claude/scripts/task-lock.sh scope-acquire "$session_id" "$POSTFLIGHT_SCOPE_STALE_SEC"); then
  _scope_mutex_held_here="true"
  # Exported so Stage 7's update-task-status.sh child (and every state-write.sh call below)
  # inherits the guard and skips its own nested acquire/release rather than self-deadlocking.
  export SCOPE_MUTEX_HELD=1
  # Installed immediately after a successful acquire: this script runs under `set -e` and can
  # exit early at several stages between here and the explicit release below. No pre-existing
  # EXIT trap exists in this script (confirmed during planning), so this is the first and only
  # trap installed.
  trap 'bash .claude/scripts/task-lock.sh scope-release "$scope_token" >&2 || true' EXIT
else
  echo "[postflight] NOTE: could not acquire specs/.scope-lock as a single Stage 7-8a bracket for task ${task_number} (holder busy); each write below falls through to state-write.sh's own independent fail-closed acquire instead. Stages 7a-8 lose their combined-bracket atomicity for this run, but every individual write remains safely serialized -- never silently unserialized." >&2
fi

# ─────────────────────────────────────────────────────────────────────────────
# Stage 7: Update task status (postflight) — research and plan only
# implement did this inline in the now-deleted base lifecycle implement skill before calling
# this script (historical; this script has no current caller — see the header comment)
# ─────────────────────────────────────────────────────────────────────────────
if [ "$do_status_update" = "true" ] && [ "$status" = "$success_status" ]; then
  echo "[postflight] Updating task status via update-task-status.sh..."
  # --file-scope-add write-back: two independent sources feed the same additive union-merge --
  # research forwards proposed_file_scope from .return-meta.json (below); plan instead harvests
  # the artifact's own "Files to modify" per-phase field via plan-file-scope-harvest.sh (see
  # context/formats/plan-format.md's "Consumers of this field" subsection and Decisions 1-3 in
  # this task's plan). Both degrade to no flag at all (byte-for-byte no-op) on any empty,
  # unparseable, or failed result -- a harvest failure must never block a plan postflight.
  # Absent field, null, or [] passes no flag at all (byte-for-byte no-op).
  fsa_args=()
  if [ "$operation_type" = "research" ] && [ -f "$metadata_file" ]; then
    proposed_file_scope=$(jq -c '.proposed_file_scope // [] | if (type == "array") then . else [] end' \
      "$metadata_file" 2>/dev/null)
    if [ -n "$proposed_file_scope" ] && [ "$proposed_file_scope" != "[]" ] && [ "$proposed_file_scope" != "null" ]; then
      fsa_args=(--file-scope-add="$proposed_file_scope")
    fi
  elif [ "$operation_type" = "plan" ] && [ -n "$artifact_path" ] && [ -f "$artifact_path" ]; then
    harvested_file_scope=$(bash .claude/scripts/plan-file-scope-harvest.sh "$artifact_path" 2>/dev/null) \
      || echo "[postflight] WARNING: plan-file-scope-harvest.sh failed for ${artifact_path}, skipping file_scope harvest for this postflight (non-blocking)" >&2
    if [ -n "$harvested_file_scope" ] && [ "$harvested_file_scope" != "[]" ] && [ "$harvested_file_scope" != "null" ]; then
      fsa_args=(--file-scope-add="$harvested_file_scope")
    fi
  fi
  bash .claude/scripts/update-task-status.sh postflight "$task_number" "$operation_type" "$session_id" \
    "${fsa_args[@]}" \
    || echo "[postflight] WARNING: update-task-status.sh failed (non-blocking)" >&2
fi

# ─────────────────────────────────────────────────────────────────────────────
# Stage 7a: Increment next_artifact_number (research only)
# Routed through state-write.sh (replacing the former non-atomic python3 json.load/json.dump
# in-place write, which had no temp file and no atomicity at all). The jq filter
# `.next_artifact_number = (.next_artifact_number // 1) + 1` matches the research report's
# exact recommended transform.
# ─────────────────────────────────────────────────────────────────────────────
if [ "$do_artifact_increment" = "true" ] && [ "$status" = "$success_status" ]; then
  echo "[postflight] Incrementing next_artifact_number..."
  bash .claude/scripts/state-write.sh \
    '(.active_projects[] | select(.project_number == $num)).next_artifact_number =
      ((.active_projects[] | select(.project_number == $num)).next_artifact_number // 1) + 1' \
    --session-id "$session_id" \
    --argjson num "$task_number" \
    || echo "[postflight] WARNING: Failed to increment next_artifact_number (non-blocking)" >&2
fi

# ─────────────────────────────────────────────────────────────────────────────
# Stage 7b: Write completion_summary + roadmap_items (implement only)
# NOTE: For implement, the skill's inline Stage 7 already handles this.
# This block is here as a safety net when the shared script is called for implement
# and the inline stage did NOT already write these fields.
# The skill controls whether this runs by setting SKIP_COMPLETION_DATA=true before calling.
# Delegates to skill_propagate_completion_summary (skill-base.sh, sourced at the top of this
# script) — one of six call sites converged on that single guarded-write implementation.
# ─────────────────────────────────────────────────────────────────────────────
if [ "$operation_type" = "implement" ] && [ "${SKIP_COMPLETION_DATA:-false}" != "true" ]; then
  if [ "$status" = "implemented" ]; then
    skill_propagate_completion_summary "$task_number" "$completion_summary" "$roadmap_items" "$task_type" "$session_id" \
      || echo "[postflight] WARNING: Failed to write completion_summary/roadmap_items (non-blocking)" >&2
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Stage 7c: Propagate memory_candidates (all operations, append semantics)
# Routed through state-write.sh (replacing the former non-atomic python3 json.load/json.dump
# in-place write) with the payload passed via --argjson, matching the jq filter
# `.memory_candidates += $new` recommended by the research report -- the same
# interpolation-avoidance Stage 7d's reflection write below already uses deliberately, so
# memory_candidates' free-text content (quotes, newlines) can never break the write the way the
# old `'''${memory_candidates}'''` python string literal could.
# ─────────────────────────────────────────────────────────────────────────────
if [ "$memory_candidates" != "[]" ] && [ -n "$memory_candidates" ]; then
  echo "[postflight] Propagating memory_candidates to state.json..."
  bash .claude/scripts/state-write.sh \
    '(.active_projects[] | select(.project_number == $num)).memory_candidates =
      ((.active_projects[] | select(.project_number == $num)).memory_candidates // []) + $new' \
    --session-id "$session_id" \
    --argjson num "$task_number" \
    --argjson new "$memory_candidates" \
    || echo "[postflight] WARNING: Failed to propagate memory_candidates (non-blocking)" >&2
fi

# ─────────────────────────────────────────────────────────────────────────────
# Stage 7d: Write reflection (implement only, overwrite semantics)
# Uses jq --argjson rather than a shell-interpolated string literal: reflection's four free-text
# fields may contain embedded quotes/newlines that would break naive string interpolation.
# --argjson passes the JSON value safely without string interpolation. Guarded and non-blocking:
# a failure here must not affect the completion_summary/roadmap_items/memory_candidates handling
# above. Routed through state-write.sh, replacing the former hand-rolled
# specs/tmp/state.json-staged jq/mv sequence.
# ─────────────────────────────────────────────────────────────────────────────
if [ "$operation_type" = "implement" ] && [ "$status" = "implemented" ] && [ "$reflection" != "null" ] && [ -n "$reflection" ]; then
  echo "[postflight] Writing reflection to state.json..."
  bash .claude/scripts/state-write.sh \
    '(.active_projects[] | select(.project_number == $num)).reflection = $refl' \
    --session-id "$session_id" \
    --argjson num "$task_number" \
    --argjson refl "$reflection" \
    || echo "[postflight] WARNING: Failed to write reflection (non-blocking)" >&2
fi

# ─────────────────────────────────────────────────────────────────────────────
# Stage 8: Link artifacts in state.json (two-step jq, Issue #1132 safe), each step routed
# through state-write.sh, replacing the former hand-rolled specs/tmp/state.json-staged jq/mv
# sequences.
# ─────────────────────────────────────────────────────────────────────────────
if [ -n "$artifact_path" ]; then
  echo "[postflight] Linking artifact: ${artifact_path} (type: ${artifact_type_from_meta})"

  # Step 1: Filter out existing artifacts of the same type
  # Uses --arg atype pattern (Issue #1132 safe) + "| not" instead of !=
  bash .claude/scripts/state-write.sh \
    '(.active_projects[] | select(.project_number == $num)).artifacts =
      [(.active_projects[] | select(.project_number == $num)).artifacts // [] | .[] | select(.type == $atype | not)]' \
    --session-id "$session_id" \
    --arg atype "$artifact_type_from_meta" \
    --argjson num "$task_number" \
    || echo "[postflight] WARNING: Step 1 artifact filter failed (non-blocking)" >&2

  # Step 2: Add new artifact entry
  bash .claude/scripts/state-write.sh \
    '(.active_projects[] | select(.project_number == $num)).artifacts += [{"path": $path, "type": $atype, "summary": $summary}]' \
    --session-id "$session_id" \
    --arg path "$artifact_path" \
    --arg atype "$artifact_type_from_meta" \
    --arg summary "$artifact_summary" \
    --argjson num "$task_number" \
    || echo "[postflight] WARNING: Step 2 artifact add failed (non-blocking)" >&2
fi

# ─────────────────────────────────────────────────────────────────────────────
# Stage 8a: Regenerate TODO.md (non-blocking)
# ─────────────────────────────────────────────────────────────────────────────
echo "[postflight] Regenerating TODO.md..."
bash .claude/scripts/generate-todo.sh || echo "[postflight] WARNING: generate-todo.sh failed (non-fatal)" >&2

# ─────────────────────────────────────────────────────────────────────────────
# Release the specs/.scope-lock mutex: the Stages 7-8a critical section (state.json
# read-modify-write + TODO.md regen) ends here. Stage 8b (TTS) and Stage 10 (cleanup) run
# OUTSIDE any mutex — this boundary is the research verdict and must not drift. Stage 9 (git
# commit) runs outside THIS mutex too, but is no longer unserialized: git-commit-scoped.sh
# brackets Stage 9's own git add + git commit pair in the DISTINCT specs/.commit-lock mutex (see
# that script and task-lock.md's "Commit-Mutex CLI" section) — a two-mutex arrangement, not a
# single mutex spanning both windows. Explicit release + trap clear (rather than leaving the
# EXIT trap to fire at script end) so THIS mutex is not held for the remainder of postflight's
# tail.
# ─────────────────────────────────────────────────────────────────────────────
if [ "$_scope_mutex_held_here" = "true" ]; then
  bash .claude/scripts/task-lock.sh scope-release "$scope_token" >&2 || true
  trap - EXIT
  unset SCOPE_MUTEX_HELD
  _scope_mutex_held_here="false"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Stage 8b: Lifecycle TTS notification (non-blocking, background)
# Fires lifecycle notification for tab color and TTS. TTS is automatically
# suppressed during orchestration via the orchestrate-active marker in
# lifecycle-notify.sh. Standalone completions fire TTS unconditionally.
# implemented->completed: wezterm.lua only has "completed" in its color table.
# ─────────────────────────────────────────────────────────────────────────────
lifecycle_script=".claude/scripts/lifecycle-notify.sh"
if [ -f "$lifecycle_script" ]; then
  notify_status="$status"
  [ "$notify_status" = "implemented" ] && notify_status="completed"
  bash "$lifecycle_script" "$notify_status" &
fi

# ─────────────────────────────────────────────────────────────────────────────
# Stage 9: Git commit (plan and implement only; non-blocking)
# Targeted, work-scoped staging per .claude/context/standards/git-staging-scope.md —
# never stage the entire working tree — via .claude/scripts/git-commit-scoped.sh, the single
# sanctioned implementation of path-scoped, mutex-serialized committing (see that script and
# git-staging-scope.md's "Commit-Level Path Scoping and Cross-Process Serialization" section).
# Fail-safe direction is to under-stage with a loud warning rather than over-stage and pull in a
# concurrent session's stray edits. The helper folds in the former Stage 9b honest-commit-message
# scan (via --honest-index-rows) and the canonical ephemeral-runtime-file exclusion set
# automatically — neither needs to be re-derived here.
# ─────────────────────────────────────────────────────────────────────────────
if [ "$do_git_commit" = "true" ]; then
  echo "[postflight] Creating git commit (targeted staging via git-commit-scoped.sh): ${commit_message}"

  # Base scope for both plan and implement: the task directory + shared index files.
  stage_paths=("${task_dir}/" "specs/TODO.md" "specs/state.json")

  if [ "$operation_type" = "implement" ]; then
    # Explicitly include the plan file (already covered by task_dir/ above; staged
    # explicitly too per the git-staging-scope.md contract).
    plan_file=$(ls "${task_dir}"/plans/*.md 2>/dev/null | head -1)
    if [ -n "$plan_file" ]; then
      stage_paths+=("$plan_file")
    fi

    # Agent self-reported modified_files (implement-specific; see return-metadata-file.md).
    modified_files_count=0
    while IFS= read -r f; do
      if [ -n "$f" ]; then
        stage_paths+=("$f")
        modified_files_count=$((modified_files_count + 1))
      fi
    done < <(jq -r '.modified_files[]? // empty' "$metadata_file" 2>/dev/null)

    if [ "$modified_files_count" -eq 0 ]; then
      echo "[postflight] WARNING: no modified_files reported; source-file changes NOT committed automatically. Review and commit manually." >&2
    fi
  fi

  bash .claude/scripts/git-commit-scoped.sh \
    --message "$commit_message" \
    --session "$session_id" \
    --honest-index-rows "$task_number" \
    -- "${stage_paths[@]}" \
    || echo "[postflight] NOTE: Nothing to commit or git commit failed (non-blocking)" >&2

  # Surface any residual uncommitted changes rather than silently ignoring them.
  residual="$(git status --porcelain 2>/dev/null)"
  if [ -n "$residual" ]; then
    echo "[postflight] WARNING: working tree has uncommitted changes after targeted commit. Review and commit manually if needed:" >&2
    echo "$residual" >&2
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Stage 10: Cleanup marker files
# ─────────────────────────────────────────────────────────────────────────────
echo "[postflight] Cleaning up marker files..."
rm -f "${task_dir}/.postflight-pending" \
      "${task_dir}/.postflight-loop-guard" \
      "${task_dir}/.return-meta.json" 2>/dev/null || true

# Cleanup continuation-loop-guard for implement operation
if [ "$operation_type" = "implement" ]; then
  rm -f "${task_dir}/.continuation-loop-guard" 2>/dev/null || true
fi

echo "[postflight] Postflight complete for task ${task_number} (${operation_type}: ${status})"
exit 0
