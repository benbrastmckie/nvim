#!/usr/bin/env bash
# skill-base.sh — Shared skill lifecycle functions
#
# SOURCING SEMANTICS:
#   This file must be sourced within the SAME Bash tool invocation as function calls.
#   Exported variables do NOT persist across separate Bash invocations in Claude Code.
#   Pattern: source this file, then call functions, all within one bash block.
#
#   Example usage in a SKILL.md bash block:
#     source .claude/scripts/skill-base.sh
#     skill_validate_input "$task_number"
#     skill_preflight_update "$task_number" "research" "$session_id"
#
# VARIABLE EXPORTS:
#   skill_validate_input  -> TASK_DATA, TASK_TYPE, TASK_STATUS, PROJECT_NAME, PADDED_NUM, TASK_DIR,
#                            TASK_DIR_ABS, TASK_IS_ARCHIVED
#   skill_read_artifact_number -> ARTIFACT_NUMBER, ARTIFACT_PADDED
#   skill_read_metadata   -> SUBAGENT_STATUS, ARTIFACT_PATH, ARTIFACT_TYPE, ARTIFACT_SUMMARY, MEMORY_CANDIDATES
#
# CONTEXT BUDGET DEFAULTS (overridable by tier enforcement):
#   SKILL_CONTEXT_BUDGET defaults to 8000 (sonnet workers) or 15000 (opus planners).
#   Override before sourcing: SKILL_CONTEXT_BUDGET=15000 source skill-base.sh
SKILL_CONTEXT_BUDGET="${SKILL_CONTEXT_BUDGET:-8000}"

# ─────────────────────────────────────────────────────────────────────────────
# REPO ROOT ANCHOR
# This file is deployed at <repo-root>/.claude/scripts/skill-base.sh, so the repo root is two
# directories up from this file's own location. Resolving from BASH_SOURCE — rather than from
# the ambient working directory or `git rev-parse --show-toplevel` — keeps paths built below
# correct no matter where the caller's shell happens to be, and stays correct inside git
# worktrees and nested repos where `git rev-parse` answers a different question.
# Override only in tests.
SKILL_REPO_ROOT="${SKILL_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export SKILL_REPO_ROOT

# ─────────────────────────────────────────────────────────────────────────────
# SHARED LIBRARY: scripts/lib/common.sh (session-ID generation, repo-root resolution helpers,
# timestamps, logging, test helpers). Sets no shell options of its own -- see its own header
# contract. Two candidate paths: the deployed tree (this file's normal runtime context, hence
# tried first) and a source-store-relative fallback so this file can also be sourced directly
# from agent-system/extensions/core/scripts/ (e.g. by a future test suite exercising this file
# in isolation).
if [ -f "${SKILL_REPO_ROOT}/.claude/scripts/lib/common.sh" ]; then
  source "${SKILL_REPO_ROOT}/.claude/scripts/lib/common.sh"
elif [ -f "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh" ]; then
  source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
fi

# ─────────────────────────────────────────────────────────────────────────────
# SHARED LIBRARY: scripts/lib/task-lookup-lib.sh (archive-aware task lookup: active-wins entry
# lookup, active-membership predicate, archived-task-directory resolution). Same two-candidate
# resolution order as common.sh immediately above. Needed by skill_validate_input,
# skill_preflight_update, and skill_postflight_update below, all of which must find an archived
# task rather than treating it as nonexistent.
if [ -f "${SKILL_REPO_ROOT}/.claude/scripts/lib/task-lookup-lib.sh" ]; then
  source "${SKILL_REPO_ROOT}/.claude/scripts/lib/task-lookup-lib.sh"
elif [ -f "$(dirname "${BASH_SOURCE[0]}")/lib/task-lookup-lib.sh" ]; then
  source "$(dirname "${BASH_SOURCE[0]}")/lib/task-lookup-lib.sh"
fi
# Fail-SAFE, not fail-skip: if neither candidate resolved (a stale deploy, or a test sandbox that
# has not copied the new library alongside skill-base.sh), do NOT let every preflight/postflight
# status write silently no-op -- an undefined `task_lookup_is_active` call would otherwise exit
# non-zero (command not found), which `! task_lookup_is_active ...` below reads as "not active",
# skipping EVERY status write for EVERY task, archived or not. Define minimal shims that
# reproduce this task's PRE-EXISTING (active-projects-only) behavior instead, with a loud one-
# time warning, so a missing library degrades to yesterday's behavior rather than a silent global
# write outage.
if ! declare -F task_lookup_entry >/dev/null 2>&1; then
  echo "WARNING: [skill-base] scripts/lib/task-lookup-lib.sh not resolvable at either candidate path -- archive-aware lookup disabled, falling back to active-projects-only behavior (an archived task will be treated as not found/not active, matching this codebase's behavior before task-lookup-lib.sh existed)." >&2
  task_lookup_entry() {
    jq -c --argjson n "$1" '.active_projects[]? | select(.project_number == $n)' "$2" 2>/dev/null | head -1
  }
  task_lookup_is_active() {
    jq -e --argjson n "$1" 'any((.active_projects // [])[]; .project_number == $n)' "$2" >/dev/null 2>&1
  }
  task_lookup_dir() {
    printf 'specs/%03d_%s\n' "$1" "$2"
  }
fi

# ─────────────────────────────────────────────────────────────────────────────
# SHARED LIBRARY: scripts/lib/deploy-freshness-lib.sh (per-extension, path-scoped comparison of
# a repo's deployed .claude/ tree against the source store it was regenerated from -- see that
# file's own header for the STALE/FRESH/CANNOTVERIFY algorithm). Same two-candidate resolution
# order as common.sh and task-lookup-lib.sh above. This is the PER-DISPATCH surface: the same
# unchanged comparison check-deploy-freshness.sh already runs once per top-level command
# (command-gate-in.sh's CHECKPOINT 1), re-fired here at the finer per-skill/agent-dispatch
# granularity so a stale extension is named in the context of the dispatch that is actually
# about to read from it, not only on the orchestrating session's own stderr. See
# `context/patterns/regeneration-is-manual-only.md`'s "Detecting When You're Stale" section for
# the full tier writeup.
if [ -f "${SKILL_REPO_ROOT}/.claude/scripts/lib/deploy-freshness-lib.sh" ]; then
  source "${SKILL_REPO_ROOT}/.claude/scripts/lib/deploy-freshness-lib.sh"
elif [ -f "$(dirname "${BASH_SOURCE[0]}")/lib/deploy-freshness-lib.sh" ]; then
  source "$(dirname "${BASH_SOURCE[0]}")/lib/deploy-freshness-lib.sh"
fi

# skill_deploy_freshness_stale_names: thin, always-safe wrapper around
# deploy_freshness_stale_names for the per-dispatch call site below (and reused unchanged by
# orchestrate-build-dispatch.sh's dispatch-brief injection, so the library call is derived in
# exactly one place). Prints one stale extension name per line against $SKILL_REPO_ROOT, or
# nothing at all on ANY failure mode: the library itself not resolvable (deploy-first stale-copy
# hazard), no .claude-extensions.json, missing jq/git, or a genuinely clean tree. Never aborts,
# always returns 0 -- mirroring check-deploy-freshness.sh's own always-exit-0 contract so a
# caller under `set -e` is never at risk from this call.
skill_deploy_freshness_stale_names() {
  if ! declare -F deploy_freshness_stale_names >/dev/null 2>&1; then
    return 0
  fi
  deploy_freshness_stale_names "$SKILL_REPO_ROOT" 2>/dev/null || true
  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# EXTENSION HOOKS: Lifecycle hook invocation for loaded extensions.
#
# Extensions may declare hook scripts in manifest.json under a top-level
# "hooks" object (distinct from "provides.hooks" which are file-copy targets):
#
#   "hooks": {
#     "preflight": "scripts/my-preflight.sh",
#     "context_injection": "scripts/my-context.sh",
#     "verification": "scripts/my-verify.sh",
#     "postflight": "scripts/my-postflight.sh"
#   }
#
# Hook scripts are called with 5 positional args:
#   $1 = task_number   $2 = task_type   $3 = task_dir   $4 = session_id   $5 = operation
#
# Missing hook keys or absent extensions.json are silently skipped.
# ─────────────────────────────────────────────────────────────────────────────

# skill_get_extension_dir: Map task_type to extension directory via extensions.json
# Usage: skill_get_extension_dir "$task_type"
# Outputs: absolute path to extension directory, or empty string if not found
skill_get_extension_dir() {
  local task_type="$1"
  # Extension selection manifest lives at the PROJECT ROOT (not inside .claude/)
  # so it survives a .claude/ wipe -- preset-scoped filename for Claude Code.
  local extensions_json=".claude-extensions.json"
  if [ ! -f "$extensions_json" ]; then
    return 0
  fi
  # Find extension with matching task_type
  local ext_name
  ext_name=$(jq -r --arg tt "$task_type" \
    '.loaded_extensions // [] | .[] | select(.task_type == $tt) | .name' \
    "$extensions_json" 2>/dev/null | head -1)
  if [ -z "$ext_name" ] || [ "$ext_name" = "null" ]; then
    return 0
  fi
  echo ".claude/extensions/${ext_name}"
}

# skill_run_extension_hook: Execute a lifecycle hook for the current task_type
# Usage: skill_run_extension_hook "$hook_name" "$task_number" "$task_type" "$task_dir" "$session_id" "$operation"
# hook_name: preflight | context_injection | verification | postflight
# Silently skips if: extensions.json missing, extension not loaded, hook not declared, script not found
skill_run_extension_hook() {
  local hook_name="$1"
  local task_number="$2"
  local task_type="$3"
  local task_dir="$4"
  local session_id="$5"
  local operation="$6"

  local ext_dir
  ext_dir=$(skill_get_extension_dir "$task_type")
  if [ -z "$ext_dir" ]; then
    return 0
  fi

  local manifest="${ext_dir}/manifest.json"
  if [ ! -f "$manifest" ]; then
    return 0
  fi

  local hook_script
  hook_script=$(jq -r --arg h "$hook_name" '.hooks[$h] // empty' "$manifest" 2>/dev/null)
  if [ -z "$hook_script" ]; then
    return 0
  fi

  local hook_path="${ext_dir}/${hook_script}"
  if [ ! -x "$hook_path" ]; then
    return 0
  fi

  echo "[skill-base] Running extension hook: ${hook_name} (${hook_path})"
  "$hook_path" "$task_number" "$task_type" "$task_dir" "$session_id" "$operation" || \
    echo "[skill-base] WARNING: Extension hook '${hook_name}' exited non-zero (non-blocking)"
}

# ─────────────────────────────────────────────────────────────────────────────
# Observable-but-non-fatal wrapper around events-append.sh.
#
# Replaces the bare `bash .claude/scripts/events-append.sh ... || true` idiom, which failed
# SILENTLY when the helper was missing -- the defect that hid the events store's non-deployment
# for a full day. This wrapper ALWAYS returns 0 to its caller (a missing/failing events helper
# must never become fatal to the enclosing skill lifecycle stage), but distinguishes "helper
# missing/not executable" from "helper present but exited non-zero" in both a one-time-per-process
# stderr WARNING and a durable sentinel marker under .claude/tmp/, so the failure is surfaceable
# instead of silently swallowed.
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
        echo "[skill-base] WARNING: events-append.sh helper missing or not executable at ${helper_path} (non-blocking)" >&2
      else
        echo "[skill-base] WARNING: events-append.sh helper present but failed (exit ${exit_code}) at ${helper_path} (non-blocking)" >&2
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

# ORCHESTRATOR MODE: Support for skill-orchestrate dispatch.
# .orchestrator-handoff.json is a hard-mode-implement-only artifact: only the hard-mode
# implementation agent writes it (via the Write tool, per context/contracts/wrap-up.md's H9
# contract). Base-mode research/plan/implement return via .return-meta.json, recovered by
# orchestrate-recover-outcome.sh. Research agents never write a handoff at all.
# See: .claude/docs/architecture/handoff-schema.md and
# .claude/context/schemas/orchestrator-handoff-schema.json

# ─────────────────────────────────────────────────────────────────────────────
# Stage 1: Validate input task number
# Usage: skill_validate_input "$task_number" ["$allow_terminal"]
# Exports: TASK_DATA, TASK_TYPE, TASK_STATUS, PROJECT_NAME, PADDED_NUM, TASK_DIR, TASK_DIR_ABS,
#          TASK_IS_ARCHIVED
# Exit 1 if task not found in EITHER active_projects or the archive, or (absent allow_terminal)
# in a terminal state.
#
# Optional 2nd positional: `allow_terminal` ("true"/empty). Absent or empty (every existing call
# site, byte-for-byte) preserves today's behavior exactly: the completed/abandoned/expanded block
# below still hard-exits. When "true" (a forced `/orchestrate` dispatch), that block is SKIPPED
# and a named notice is emitted to stderr instead, recording that a forced dispatch is proceeding
# against a terminal task. This is opt-in and default-off by construction — nothing but an
# explicit forced-phase caller ever passes it.
skill_validate_input() {
  local task_number="$1"
  local allow_terminal="${2:-}"
  PADDED_NUM=$(printf "%03d" "$task_number")
  # Archive-aware lookup (task-lookup-lib.sh, sourced above): active projects win; the archive is
  # consulted only when the number is absent from active_projects, so an archived task is found
  # here instead of hitting the not-found exit below.
  TASK_DATA=$(task_lookup_entry "$task_number" specs/state.json)
  if [ -z "$TASK_DATA" ]; then
    echo "ERROR: Task $task_number not found in state.json" >&2
    exit 1
  fi
  TASK_TYPE=$(echo "$TASK_DATA" | jq -r '.task_type // "general"')
  TASK_STATUS=$(echo "$TASK_DATA" | jq -r '.status')
  PROJECT_NAME=$(echo "$TASK_DATA" | jq -r '.project_name')
  DESCRIPTION=$(echo "$TASK_DATA" | jq -r '.description // ""')
  # Archive-aware directory resolution (task-lookup-lib.sh): an archived task's dispatch file and
  # artifacts land in specs/archive/{NNN}_{slug}/, next to its existing reports and plans, rather
  # than a hardcoded specs/{NNN}_{slug} that no longer exists (and would otherwise be silently
  # re-created as a fresh, empty, WRONG sibling directory).
  TASK_DIR=$(task_lookup_dir "$task_number" "$PROJECT_NAME" "$SKILL_REPO_ROOT")
  # Absolute companion to TASK_DIR. TASK_DIR stays relative because many existing consumers
  # depend on its relative form; TASK_DIR_ABS is the anchor to hand to dispatched agents and
  # to build write destinations from.
  TASK_DIR_ABS="${SKILL_REPO_ROOT}/${TASK_DIR}"
  if task_lookup_is_active "$task_number" specs/state.json; then
    TASK_IS_ARCHIVED="false"
  else
    TASK_IS_ARCHIVED="true"
  fi
  # Block terminal states (unless a forced dispatch explicitly opted in via allow_terminal).
  if [ "$TASK_STATUS" = "completed" ] || [ "$TASK_STATUS" = "abandoned" ] || [ "$TASK_STATUS" = "expanded" ]; then
    if [ "$allow_terminal" = "true" ]; then
      echo "NOTICE: [skill-base] Task $task_number is in terminal state [$TASK_STATUS]; proceeding because a forced dispatch explicitly opted in (allow_terminal=true)." >&2
    else
      echo "ERROR: Task $task_number is in terminal state [$TASK_STATUS]" >&2
      exit 1
    fi
  fi
  export TASK_DATA TASK_TYPE TASK_STATUS PROJECT_NAME DESCRIPTION PADDED_NUM TASK_DIR TASK_DIR_ABS TASK_IS_ARCHIVED
}

# ─────────────────────────────────────────────────────────────────────────────
# Stage 2: Update status to in-progress variant
# Usage: skill_preflight_update "$task_number" "$operation" "$session_id" ["$status_clamp_mode"]
# operation: "research" | "plan" | "implement" | "revise"
# Calls extension hook: hooks.preflight (after status update)
#
# Optional 4th argument: `status_clamp_mode`, mirroring skill_postflight_update's own clamp
# parameter exactly. Absent or empty (every existing call site, byte-for-byte) preserves today's
# behavior. `"monotonic-max"` resolves scripts/lib/status-vocabulary.sh (same two-candidate order
# skill_postflight_update's own clamp uses), maps `operation` to the resting state
# update-task-status.sh's own map_status() would write (research->researching, plan->planning,
# implement->implementing -- preflight's operation is always one of these three, never
# needs_research, so no special case is needed here the way postflight's clamp needs one), and
# on a regression SKIPS the update-task-status.sh call below with a named `[monotonic-max]`
# notice -- while still running the extension hook and the lifecycle event exactly as on any
# other path. Never a refusal: this function always returns 0.
#
# Archive-absent guard (ahead of the clamp, unconditional on status_clamp_mode): when the task is
# absent from active_projects (task_lookup_is_active false -- an archived task), the status write
# is skipped entirely with a named notice. Without this, an archived task's preflight write
# reaches update-task-status.sh's "task not found in state.json" exit 1 and kills the cycle under
# `set -e`. The archive is read-only everywhere in this codebase; this is the write-side half of
# that contract.
skill_preflight_update() {
  local task_number="$1"
  local operation="$2"
  local session_id="$3"
  local status_clamp_mode="${4:-}"
  local _t0
  _t0=$(date +%s.%N)
  local _skip_write=false

  if ! task_lookup_is_active "$task_number" specs/state.json; then
    _skip_write=true
    echo "NOTICE: [skill-base] task ${task_number}: preflight status write skipped -- task is archived (the archive is read-only; no in-progress status can be recorded for a task no longer in active_projects)." >&2
  elif [[ "$status_clamp_mode" == "monotonic-max" ]]; then
    # Same two-candidate resolution order skill_postflight_update's own clamp uses.
    if [[ -f "${SKILL_REPO_ROOT}/.claude/scripts/lib/status-vocabulary.sh" ]]; then
      source "${SKILL_REPO_ROOT}/.claude/scripts/lib/status-vocabulary.sh"
    elif [[ -f "$(dirname "${BASH_SOURCE[0]}")/lib/status-vocabulary.sh" ]]; then
      source "$(dirname "${BASH_SOURCE[0]}")/lib/status-vocabulary.sh"
    fi
    if declare -F status_vocabulary_would_regress >/dev/null 2>&1; then
      local _preflight_target=""
      case "$operation" in
        research) _preflight_target="researching" ;;
        plan)     _preflight_target="planning" ;;
        implement) _preflight_target="implementing" ;;
      esac
      if [[ -n "$_preflight_target" ]]; then
        local _clamp_current_status
        _clamp_current_status=$(task_lookup_entry "$task_number" specs/state.json | jq -r '.status // ""' 2>/dev/null)
        if [[ -n "$_clamp_current_status" ]] && status_vocabulary_would_regress "$_clamp_current_status" "$_preflight_target"; then
          _skip_write=true
          echo "[monotonic-max] task ${task_number}: forced ${operation} preflight would regress status from '${_clamp_current_status}' to '${_preflight_target}' — skipping the status write."
        fi
      fi
    else
      echo "WARNING: [skill-base] status_clamp_mode=monotonic-max requested but status_vocabulary_would_regress is not resolvable (deploy-first stale-copy hazard?) — clamp not applied, status write proceeds normally." >&2
    fi
  fi

  if [[ "$_skip_write" != "true" ]]; then
    bash .claude/scripts/update-task-status.sh preflight "$task_number" "$operation" "$session_id"
  fi

  # PER-DISPATCH DEPLOY-FRESHNESS SURFACE (see the deploy-freshness-lib.sh sourcing block near
  # the top of this file). Runs unconditionally -- independent of the archive-/clamp-skip guard
  # above -- exactly once per skill/agent dispatch, at the moment a stale instruction file is
  # actually about to be read. Non-blocking: a stale result is a loud stderr WARN, never a
  # refusal, and every failure mode (library not resolvable, no .claude-extensions.json, missing
  # jq/git, or a genuinely clean tree) degrades to silence. Deliberately does NOT touch
  # specs/.freshness-warn-streak.json -- that counter is a consecutive-COMMAND-invocation count
  # owned exclusively by check-deploy-freshness.sh; incrementing it per dispatch here would
  # corrupt its documented meaning.
  local _stale_extensions
  _stale_extensions="$(skill_deploy_freshness_stale_names)"
  if [[ -n "$_stale_extensions" ]]; then
    echo "WARN: [skill-base] deployed .claude/ tree is STALE relative to the source store for extension(s): $(echo "$_stale_extensions" | tr '\n' ' ' | sed 's/ *$//')" >&2
    echo "WARN: [skill-base] documented commands/instructions sourced from those extensions' deployed files may be out of date. A fresh-looking file elsewhere in the SAME tree does not mean the tree is current -- staleness here is per-extension, not whole-tree." >&2
    echo "WARN: [skill-base] verify against the source store (agent-system/extensions/<name>/) before relying on a command from a stale extension's deployed copy. Remedy: redeploy via 'bash .claude/scripts/deploy-headless.sh' -- never hand-patch the deployed .claude/** file, which would mask this divergence instead of fixing it." >&2
  fi

  # Extension hook: preflight (runs after status update) -- unconditional, exactly as before this
  # change, regardless of whether the write above ran or was clamp-/archive-skipped.
  skill_run_extension_hook "preflight" "$task_number" "${TASK_TYPE:-}" "${TASK_DIR:-}" "$session_id" "$operation"
  # Unified event store: one non-blocking milestone event per lifecycle stage
  local _dur
  _dur=$(awk -v a="$_t0" -v b="$(date +%s.%N)" 'BEGIN{printf "%.3f", b-a}')
  _events_append_observable ".claude/scripts/events-append.sh" \
    --event-type lifecycle_stage --category milestone \
    --checkpoint preflight --duration "$_dur" --task "$task_number" --session "$session_id" \
    --message "Preflight stage completed for ${operation}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Stage 3: Create postflight-pending marker file
# Usage: skill_create_postflight_marker "$padded_num" "$project_name" "$session_id" "$skill_name" "$operation"
#
# SHAPE A (the settled, canonical marker schema -- the single production writer of
# .postflight-pending): cc_session_id, session_id, skill, task_number, operation, reason,
# created, stop_hook_active. This is the fullest shape observed across the pre-unification corpus
# (six mutually incompatible shapes), so unifying onto it loses no field. `task_number` is
# derived from the already-passed `padded_num` (stripped of leading zeros) rather than added as a
# new 6th parameter -- the function signature stays 5-arg so the 9 existing `source`-sites are
# unaffected. `stop_hook_active` is retained as `false` because it is a behavioral field the
# hard-mode variants had dropped by drift, not by deliberate design. `cc_session_id` is Claude
# Code's native session UUID ($CLAUDE_CODE_SESSION_ID, the same id space as hook stdin's
# top-level `.session_id` -- see update-task-status.sh's `workflow-active-<key>` marker for
# in-repo precedent), distinct from the agent-system `session_id` field above; it is the
# correlation key both subagent-postflight.sh and events-log-lifecycle.sh read to select only the
# marker owned by the stopping session.
skill_create_postflight_marker() {
  local padded_num="$1"
  local project_name="$2"
  local session_id="$3"
  local skill_name="$4"
  local operation="$5"
  local task_dir="specs/${padded_num}_${project_name}"
  # Strip leading zeros (avoids octal interpretation) to derive the unpadded task_number.
  local task_number=$((10#$padded_num))
  mkdir -p "$task_dir"
  cat > "${task_dir}/.postflight-pending" << EOF
{
  "cc_session_id": "${CLAUDE_CODE_SESSION_ID:-}",
  "session_id": "${session_id}",
  "skill": "${skill_name}",
  "task_number": ${task_number},
  "operation": "${operation}",
  "reason": "Postflight pending: status update, artifact linking, git commit",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "stop_hook_active": false
}
EOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Stage 4: Extension context injection (hook invocation only)
# Usage: skill_context_injection "$task_number" "$session_id" "$operation"
# Calls extension hook: hooks.context_injection
# This function provides a call site for extensions to inject domain-specific
# context before agent delegation. The hook receives task metadata via positional args.
skill_context_injection() {
  local task_number="$1"
  local session_id="$2"
  local operation="${3:-research}"
  local _t0
  _t0=$(date +%s.%N)
  skill_run_extension_hook "context_injection" "$task_number" "${TASK_TYPE:-}" "${TASK_DIR:-}" "$session_id" "$operation"
  # Unified event store: one non-blocking milestone event per lifecycle stage
  local _dur
  _dur=$(awk -v a="$_t0" -v b="$(date +%s.%N)" 'BEGIN{printf "%.3f", b-a}')
  _events_append_observable ".claude/scripts/events-append.sh" \
    --event-type lifecycle_stage --category milestone \
    --checkpoint context_injection --duration "$_dur" --task "$task_number" --session "$session_id" \
    --message "Context injection stage completed for ${operation}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Stage 3a: Read artifact number for this task
# Usage: skill_read_artifact_number "$task_number" "$padded_num" "$project_name" "$artifact_dir" "$mode"
# mode: "current" (researcher: use next_artifact_number as-is)
#        "prev"    (planner/implementer: use next_artifact_number - 1)
# Exports: ARTIFACT_NUMBER, ARTIFACT_PADDED
skill_read_artifact_number() {
  local task_number="$1"
  local padded_num="$2"
  local project_name="$3"
  local artifact_dir="$4"  # "reports/" | "plans/" | "summaries/"
  local mode="${5:-prev}"
  local next_num
  # Archive-aware (task-lookup-lib.sh, sourced at the top of this file): active projects win, the
  # archive is consulted only when the number is absent from active_projects. Without this, an
  # archived task's next_artifact_number was invisible here (the old inline jq only ever read
  # .active_projects), forcing every archived-task call down the legacy fallback below even
  # though the archived record itself still carries the real next_artifact_number verbatim (see
  # skill-todo's archival jq, which copies the whole active_projects entry unmodified).
  next_num=$(task_lookup_entry "$task_number" specs/state.json | jq -r '.next_artifact_number // 1')
  if [ "$next_num" = "null" ] || [ -z "$next_num" ]; then
    # Legacy fallback: count existing artifacts in directory. Prefers the ambient TASK_DIR set by
    # skill_validate_input (this function's only call site always runs after it, in the same
    # process) -- archive-aware, so an archived task's fallback counts against
    # specs/archive/{NNN}_{slug}/, not a nonexistent specs/{NNN}_{slug}/. Falls back to
    # reconstructing the active-only path when TASK_DIR is unset, preserving today's exact
    # behavior for any caller that never ran skill_validate_input.
    local count fallback_task_dir
    fallback_task_dir="${TASK_DIR:-specs/${padded_num}_${project_name}}"
    # `|| count=0` guards the glob-miss case: under `set -e -o pipefail`, `ls` on a non-matching
    # glob exits non-zero and would otherwise abort the whole script here.
    count=$(ls "${fallback_task_dir}/${artifact_dir}"*[0-9][0-9]*.md 2>/dev/null | wc -l) || count=0
    ARTIFACT_NUMBER=$((count + 1))
  elif [ "$mode" = "current" ]; then
    ARTIFACT_NUMBER="$next_num"
  else
    # mode = "prev": planner/implementer share the same round as preceding research
    if [ "$next_num" -le 1 ]; then
      ARTIFACT_NUMBER=1
    else
      ARTIFACT_NUMBER=$((next_num - 1))
    fi
  fi
  ARTIFACT_PADDED=$(printf "%02d" "$ARTIFACT_NUMBER")
  export ARTIFACT_NUMBER ARTIFACT_PADDED
}

# ─────────────────────────────────────────────────────────────────────────────
# Stage 6: Read agent metadata file
# Usage: skill_read_metadata "$padded_num" "$project_name"
# Exports: SUBAGENT_STATUS, ARTIFACT_PATH, ARTIFACT_TYPE, ARTIFACT_SUMMARY, MEMORY_CANDIDATES
skill_read_metadata() {
  local padded_num="$1"
  local project_name="$2"
  local meta_file="specs/${padded_num}_${project_name}/.return-meta.json"
  if [ ! -f "$meta_file" ] || ! jq empty "$meta_file" 2>/dev/null; then
    echo "Error: Invalid or missing metadata file: $meta_file" >&2
    SUBAGENT_STATUS="failed"
    ARTIFACT_PATH=""
    ARTIFACT_TYPE=""
    ARTIFACT_SUMMARY="Agent did not write metadata"
    MEMORY_CANDIDATES="[]"
  else
    SUBAGENT_STATUS=$(jq -r '.status' "$meta_file")

    # ─── Read-side artifacts-shape normalization (chokepoint) ──────────────────────────────
    # Per context/formats/return-metadata-file.md's `artifacts (required)` four-layer posture:
    # this is the ONE consumer chokepoint that normalizes a malformed (bare-string) `artifacts`
    # array so the artifact link is not silently lost -- IN MEMORY ONLY, the on-disk file is
    # never rewritten here (contrast with `validate-return-meta.sh --fix`, which does rewrite,
    # opt-in only). Every promotion is loud (stderr banner) and recorded
    # (ARTIFACTS_SHAPE_MISMATCH). This does NOT widen the normative schema -- see
    # context/contracts/return-meta-artifacts-template.md.
    #
    # Deploy-tree-first / source-store-fallback candidate resolution, matching
    # skill_corroborate_phase_counts' own resolution below so this function works both
    # post-deploy (.claude/scripts/lib/...) and in a source-store-only checkout
    # (agent-system/extensions/core/scripts/lib/...).
    local _ram_lib_candidates=(
      ".claude/scripts/lib/return-meta-artifacts-lib.sh"
      "$(dirname "${BASH_SOURCE[0]}")/lib/return-meta-artifacts-lib.sh"
    )
    local _ram_lib=""
    local _ram_candidate
    for _ram_candidate in "${_ram_lib_candidates[@]}"; do
      if [ -f "$_ram_candidate" ]; then
        _ram_lib="$_ram_candidate"
        break
      fi
    done

    local _artifacts_raw _artifacts_normalized
    _artifacts_raw=$(jq -c '.artifacts // []' "$meta_file" 2>/dev/null || echo '[]')

    if [ -n "$_ram_lib" ] && echo "$_artifacts_raw" | jq -e 'any(.[]; type == "string")' >/dev/null 2>&1; then
      # shellcheck disable=SC1090
      source "$_ram_lib"
      _artifacts_normalized=$(normalize_artifacts_array "$_artifacts_raw" 2>/dev/null)

      # Loud stderr banner naming the file, each offending index, and its inferred type --
      # same banner family as the existing `[postflight] WARNING:` / `[hard-orchestrate]
      # EVIDENCE:` lines.
      local _ram_len _ram_i _ram_el _ram_path _ram_type
      _ram_len=$(echo "$_artifacts_raw" | jq 'length')
      for ((_ram_i = 0; _ram_i < _ram_len; _ram_i++)); do
        _ram_el=$(echo "$_artifacts_raw" | jq -c ".[$_ram_i]")
        if echo "$_ram_el" | jq -e 'type == "string"' >/dev/null 2>&1; then
          _ram_path=$(echo "$_ram_el" | jq -r '.')
          _ram_type=$(infer_artifact_type "$_ram_path")
          echo "[skill-base] WARNING: ARTIFACTS_SHAPE_MISMATCH in ${meta_file}: artifacts[${_ram_i}] is a bare string ('${_ram_path}'), normalized in-memory to type='${_ram_type}' (on-disk file left unchanged; run validate-return-meta.sh --fix to repair on disk)" >&2
        fi
      done

      # Record the defect (non-blocking -- a recorder failure must never break postflight).
      # Attribution: the agent that produced the malformed shape, read from the file's own
      # metadata.agent_type. --session omitted (this function receives no session_id
      # parameter); system-defect-record.sh's D5 fallback synthesizes one when absent.
      local _ram_agent_type _ram_task_number
      _ram_agent_type=$(jq -r '.metadata.agent_type // ""' "$meta_file" 2>/dev/null)
      _ram_task_number=$((10#$padded_num))
      if [ -n "$_ram_agent_type" ]; then
        bash .claude/scripts/system-defect-record.sh \
          --defect-class ARTIFACTS_SHAPE_MISMATCH \
          --detecting-site "scripts/skill-base.sh:skill_read_metadata" \
          --task "$_ram_task_number" \
          --message "bare-string artifacts array in ${meta_file}, normalized read-side by skill_read_metadata" \
          --dispatched-agent "$_ram_agent_type" \
          >/dev/null 2>&1 || echo "Note: system-defect recording failed (non-fatal)" >&2
      fi
    else
      _artifacts_normalized="$_artifacts_raw"
    fi

    ARTIFACT_PATH=$(echo "$_artifacts_normalized" | jq -r '.[0].path // ""' 2>/dev/null)
    ARTIFACT_TYPE=$(echo "$_artifacts_normalized" | jq -r '.[0].type // ""' 2>/dev/null)
    ARTIFACT_SUMMARY=$(echo "$_artifacts_normalized" | jq -r '.[0].summary // ""' 2>/dev/null)
    MEMORY_CANDIDATES=$(jq -c '.memory_candidates // []' "$meta_file")
  fi
  export SUBAGENT_STATUS ARTIFACT_PATH ARTIFACT_TYPE ARTIFACT_SUMMARY MEMORY_CANDIDATES
}

# ─────────────────────────────────────────────────────────────────────────────
# Stage 6a: Validate artifact exists and meets format requirements (non-blocking)
# Usage: skill_validate_artifact "$status" "$artifact_path" "$artifact_kind" ["$task_number" "$session_id" "$operation"]
# artifact_kind: "report" | "plan" | "summary"
# Validation only runs when status matches a success state
# Calls extension hook: hooks.verification (after artifact validation)
skill_validate_artifact() {
  local status="$1"
  local artifact_path="$2"
  local artifact_kind="$3"
  local task_number="${4:-}"
  local session_id="${5:-}"
  local operation="${6:-}"
  local _t0
  _t0=$(date +%s.%N)
  if [ "$status" != "failed" ] && [ -n "$artifact_path" ] && [ -f "$artifact_path" ]; then
    echo "Validating ${artifact_kind} artifact..."
    if ! bash .claude/scripts/validate-artifact.sh "$artifact_path" "$artifact_kind" --fix 2>/dev/null; then
      echo "WARNING: ${artifact_kind} artifact has format issues (non-blocking). Review output above."
    fi
  fi
  # Extension hook: verification (runs after artifact validation, non-blocking)
  if [ -n "$task_number" ]; then
    skill_run_extension_hook "verification" "$task_number" "${TASK_TYPE:-}" "${TASK_DIR:-}" "$session_id" "$operation"
  fi
  # Unified event store: one non-blocking event per lifecycle stage.
  # category is discriminated by status: a failed/blocked/partial verification is a
  # deviation from the plan, not a clean milestone.
  if [ -n "$task_number" ]; then
    local _dur _category
    _dur=$(awk -v a="$_t0" -v b="$(date +%s.%N)" 'BEGIN{printf "%.3f", b-a}')
    case "$status" in
      failed|blocked|partial) _category="deviation" ;;
      *) _category="milestone" ;;
    esac
    _events_append_observable ".claude/scripts/events-append.sh" \
      --event-type lifecycle_stage --category "$_category" \
      --checkpoint verification --duration "$_dur" --task "$task_number" --session "$session_id" \
      --message "Verification stage completed for ${artifact_kind} (status: ${status})"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Validate every artifact in a task directory against its correct per-file type
# Usage: skill_validate_task_artifacts "$task_dir"
# Non-blocking directory-wide sweep, distinct from skill_validate_artifact above (which
# validates exactly one known (path, kind) pair). validate-artifact.sh takes exactly one file
# and one type per invocation, so a whole-directory sweep needs its own abstraction — centralizing
# it here is what keeps the per-file-type convention (reports/*.md -> report, plans/*.md -> plan,
# summaries/*.md -> summary) from drifting again at future call sites.
#
# RETURN CHANNEL: this function stays non-blocking (always `return 0`), so its aggregate results
# are reported to the caller through four uppercase globals -- the same convention already used
# for TASK_DIR/ARTIFACT_PATH/SUBAGENT_STATUS elsewhere in this file. All four are reset
# unconditionally at function entry, before the sweep loop, so a caller never reads a stale value
# left over from a prior invocation:
#   SKILL_VALIDATE_FIXES        -- total auto-repaired field count across every artifact swept
#   SKILL_VALIDATE_ERRORS       -- total error count (includes one synthetic error per
#                                  validation-could-not-run result -- see the `*` case below)
#   SKILL_VALIDATE_WARNINGS     -- total warning count
#   SKILL_VALIDATE_FIXED_FILES  -- comma-joined paths of every artifact whose own fix count > 0
#
# DECISION D-A (recorded durably here, not only in the authoring plan): `--fix` remains
# in-place-mutating on this gate-out path. The mutation is narrow and self-flagging --
# validate-artifact.sh's fix block only ever inserts a literal `- **Field**: TBD` placeholder for
# a missing metadata field; it never fabricates prose and never touches required sections, so it
# cannot manufacture a false appearance of completeness. Every artifact under specs/ is
# git-tracked, so the mutation's *content* was always auditable via `git diff` -- what was
# missing was a record that a repair happened at all, which is what this function's four globals
# and command-gate-out.sh's report line now supply. Disabling --fix here would turn every trivial
# missing-metadata-field omission into a hard stop in an otherwise-automated lifecycle step, which
# the reporting gap this closes does not itself justify. Residual risk carried forward on
# purpose: exit 2 conflates "fixed and now fully clean" with "fixed a field but a required
# *section* is still missing" -- both cases share one exit code in validate-artifact.sh. This
# function surfaces the errors-remaining count *alongside* the fix count specifically so the
# second case stays visible instead of reintroducing a narrower silence one field over.
#
# DECISION D-B (resolves the open scope fork in the research that led to this design):
# validate-artifact.sh's existing terminal summary line is parsed here; that script is not
# modified. This keeps the change contained to the two files this capability touches instead of
# widening blast radius onto a script with many callers. The fragility a machine-readable output
# format would have removed is instead removed by pinning: the regression suite for this function
# asserts all three summary-line shapes verbatim, so a future wording change fails loudly in that
# suite rather than silently degrading these counts back to zero.
#
# See specs/013_instrument_gate_out_auto_repair_reporting/reports/01_gate-out-repair-reporting.md
# for the full call-chain trace behind both decisions.
skill_validate_task_artifacts() {
  local task_dir="$1"
  local subdir type f rc out last_line
  local file_fixes file_errors file_warnings

  # Unconditional reset -- before the loop, always, so a caller can never observe a stale value
  # from a previous invocation of this function.
  SKILL_VALIDATE_FIXES=0
  SKILL_VALIDATE_ERRORS=0
  SKILL_VALIDATE_WARNINGS=0
  SKILL_VALIDATE_FIXED_FILES=""

  for pair in "reports:report" "plans:plan" "summaries:summary"; do
    subdir="${pair%%:*}"
    type="${pair##*:}"
    for f in "$task_dir"/"$subdir"/*.md; do
      [ -e "$f" ] || continue
      echo "Validating ${type} artifact: ${f}"
      # set -e-safe capture: `out=$(...) || rc=$?` never aborts the caller under `set -e`, and
      # the immediate `echo "$out"` below keeps the human-visible console log byte-identical to
      # what this function printed before this change.
      rc=0
      out=$(bash .claude/scripts/validate-artifact.sh "$f" "$type" --fix 2>/dev/null) || rc=$?
      echo "$out"

      # Parse validate-artifact.sh's terminal summary line (always its last printed line) under
      # exit-code discrimination (D-B). Exit 3/4/5 are validation-could-not-run states carrying
      # no counts at all -- the `*` default below records one explicit error rather than falling
      # through to zero, which would hide a real failure behind an apparent all-clear.
      last_line=$(printf '%s\n' "$out" | tail -1)
      file_fixes=0
      file_errors=0
      file_warnings=0
      case "$rc" in
        0)
          # "[PASS] {type} artifact is valid (W warning(s))"
          if [[ "$last_line" =~ \(([0-9]+)\ warning ]]; then
            file_warnings="${BASH_REMATCH[1]}"
          else
            # Unrecognized exit-0 shape: never silently zero (D-B's own mitigation applied to
            # itself) -- an unparseable summary line is reported as one error, not an all-clear.
            file_errors=1
          fi
          ;;
        1)
          # "[FAIL] E error(s), W warning(s)" -- the counted shape. validate-artifact.sh also
          # exits 1 for the uncounted "[FAIL] File is empty: ..." shape, which this regex does
          # NOT match; the else branch below covers that case (and any other unrecognized exit-1
          # shape) with an explicit error rather than a silent zero.
          if [[ "$last_line" =~ ([0-9]+)\ error\(s\),\ ([0-9]+)\ warning ]]; then
            file_errors="${BASH_REMATCH[1]}"
            file_warnings="${BASH_REMATCH[2]}"
          else
            file_errors=1
          fi
          ;;
        2)
          # "[FIXED] N field(s) auto-repaired, E error(s), W warning(s) remaining"
          if [[ "$last_line" =~ ^\[FIXED\]\ ([0-9]+)\ field\(s\)\ auto-repaired,\ ([0-9]+)\ error\(s\),\ ([0-9]+)\ warning ]]; then
            file_fixes="${BASH_REMATCH[1]}"
            file_errors="${BASH_REMATCH[2]}"
            file_warnings="${BASH_REMATCH[3]}"
          else
            file_errors=1
          fi
          ;;
        *)
          # Validation could not run at all (file not found, unknown type, missing usage args,
          # or the shared phase-heading library missing). Never silently reported as zero.
          file_errors=1
          ;;
      esac

      SKILL_VALIDATE_FIXES=$((SKILL_VALIDATE_FIXES + ${file_fixes:-0}))
      SKILL_VALIDATE_ERRORS=$((SKILL_VALIDATE_ERRORS + ${file_errors:-0}))
      SKILL_VALIDATE_WARNINGS=$((SKILL_VALIDATE_WARNINGS + ${file_warnings:-0}))
      if [ "${file_fixes:-0}" -gt 0 ]; then
        if [ -z "$SKILL_VALIDATE_FIXED_FILES" ]; then
          SKILL_VALIDATE_FIXED_FILES="$f"
        else
          SKILL_VALIDATE_FIXED_FILES="${SKILL_VALIDATE_FIXED_FILES},${f}"
        fi
      fi

      if [ "$rc" -ne 0 ]; then
        echo "WARNING: ${type} artifact ${f} has format issues (non-blocking): ${file_fixes:-0} fixed, ${file_errors:-0} error(s), ${file_warnings:-0} warning(s). Review output above." >&2
      fi
    done
  done
  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Stage 7: Update status to completed variant
# Usage: skill_postflight_update "$task_number" "$operation" "$session_id" "$status" \
#          ["$phase_check_mode"] ["$task_dir_override"] ["$status_clamp_mode"]
# Argument 6 (optional): task_dir_override -- the task directory to use for the exit-6
#          deploy-pending annotation block, instead of the ambient ${TASK_DIR:-}. Defaults to
#          ${TASK_DIR:-} when absent or empty, so every existing 4-arg/5-arg caller is unchanged.
# Only updates state when status is a success value (researched/planned/implemented) or the
# planner-only needs_research verdict (writes state.json status "researching" plus the
# planner's research_questions -- see the needs_research case arm below)
# Calls extension hook: hooks.postflight (after status update, non-blocking)
#
# RETURN VALUE: as of the postflight completion-deploy gate (update-task-status.sh's exit 6),
# this function returns update-task-status.sh's OWN exit code verbatim (0 on success, 4 on a
# --phase-check=refuse refusal, 6 on a deploy-pending refusal, etc.) rather than implicitly
# returning whatever the trailing hook/events legs happen to exit with. Before this change, a
# refusal was invisible to every caller: the function's own return value was determined by its
# LAST executed statement (the events-append call), never by update-task-status.sh's rc, so a
# refusal was silently swallowed one layer up. The hook and events legs below still run
# UNCONDITIONALLY regardless of this rc, exactly as before -- only the final `return` changed.
#
# Optional 7th argument: `status_clamp_mode` (A2's monotonic-max clamp). Absent or empty (every
# existing 4-arg and 5-arg call site, byte-for-byte) preserves today's behavior exactly.
# `"monotonic-max"` resolves scripts/lib/status-vocabulary.sh, maps the operation/status pair to
# its resting state the same way update-task-status.sh's own map_status() does, compares it
# against the task's CURRENT status via status_vocabulary_would_regress, and on a regression
# SKIPS the update-task-status.sh invocation below with a named `[monotonic-max]` notice --
# while still running the extension hook and the lifecycle event exactly as on any other path --
# and returns 0 (a clamp skip is never a refusal code). This inherits the deploy-first hazard
# this task's plan documents for scripts/lib/status-vocabulary.sh: a caller exercising this mode
# must run under a scratchpad harness carrying the source-store copy, or resolution will silently
# reach the deployed (old) copy that lacks status_vocabulary_would_regress.
#
# `needs_research` and the monotonic-max clamp -- DECIDED, not left to chance: the clamp below
# calls `status_vocabulary_would_regress "$_clamp_current_status" "$status"` using the raw
# `$status` value this function was called with (e.g. under a forced `--plan` dispatch, a
# planner-declined task passes literal status "needs_research", never the resolved state.json
# resting value "researching"). `"needs_research"` is deliberately absent from
# `STATUS_VOCABULARY_LIFECYCLE_RANK` in scripts/lib/status-vocabulary.sh -- it is not a linear
# lifecycle-progress value, it is a fork. An unranked target makes `status_vocabulary_would_regress`
# return 1 (no regression) UNCONDITIONALLY, regardless of the task's current rank. The accepted,
# intended consequence: the monotonic-max clamp can NEVER skip a `needs_research` status write,
# even under `clamp_mode=monotonic-max` on a forced `--plan` dispatch where the task is already
# at `planning` (rank 3) and the write would otherwise look like a regression to `researching`
# (rank 1). This matches this task's own routing principle -- the classifier only routes on the
# recorded verdict, never on orchestrator discretion -- so a planner-issued needs_research verdict
# must always reach state.json, never be silently swallowed by a clamp designed for ordinary
# forward-progress statuses.
#
# Optional 6th argument: `task_dir_override`. Absent or empty (every existing 4-arg and 5-arg
# call site, byte-for-byte) falls back to the ambient `${TASK_DIR:-}`, preserving today's exact
# behavior. When supplied, it is used instead of the ambient variable inside the exit-6
# deploy-pending annotation block below, so a non-skill caller that never runs
# `skill_validate_input` (and therefore never has `TASK_DIR` set) can still reach that block --
# this is how `/orchestrate`'s own postflight call sites reach it. NOT TOUCHED by this addition
# (stated explicitly so a later reader can see the boundary was deliberate): the `phase_check_args`
# array and its empty-array expansion, the `_postflight_rc` capture and its final `return` line,
# the `skill_run_extension_hook` call's own `"${TASK_DIR:-}"` argument, the `_events_append_observable`
# call, and the non-success `*)` arm below.
skill_postflight_update() {
  local task_number="$1"
  local operation="$2"
  local session_id="$3"
  local status="$4"
  # Optional 5th argument: phase-check mode ("warn" or "refuse"), forwarded to
  # update-task-status.sh's opt-in phase-accounting backstop. ABSENT is the default for every
  # existing caller and means the flag is not passed at all, preserving today's exact behavior
  # byte-for-byte. The empty-array expansion pattern below is the same one already used by
  # reconcile-task-status.sh's dry_run_flag=() handling.
  local phase_check_mode="${5:-}"
  local status_clamp_mode="${7:-}"
  local phase_check_args=()
  if [[ -n "$phase_check_mode" ]]; then
    phase_check_args=(--phase-check="$phase_check_mode")
  fi
  # Optional 6th positional: task_dir_override. Defaults to the ambient ${TASK_DIR:-} so every
  # existing 4-arg/5-arg call site resolves identically to before. Exists so non-skill callers
  # (which never run skill_validate_input, and therefore never have TASK_DIR set) can still reach
  # the exit-6 deploy-pending annotation block below.
  local _task_dir="${6:-${TASK_DIR:-}}"
  local _t0
  _t0=$(date +%s.%N)
  local _postflight_rc=0
  # `_skip_write` (formerly `_clamp_skip`) gates the actual update-task-status.sh call below for
  # EITHER of two independent reasons: the archive-absent guard immediately below (unconditional,
  # any status), or the monotonic-max clamp further down (opt-in via status_clamp_mode, ranked
  # statuses only). Defaults false -- every existing 4-arg/5-arg call site against an active task
  # takes neither branch and is completely unaffected.
  local _skip_write=false

  # Archive-absent guard (ahead of the clamp, unconditional on status_clamp_mode): the archive is
  # read-only everywhere in this codebase. Without this, an archived task's postflight write
  # reaches update-task-status.sh's "task not found in state.json" exit 1 and kills the cycle
  # under `set -e`.
  if ! task_lookup_is_active "$task_number" specs/state.json; then
    _skip_write=true
    echo "NOTICE: [skill-base] task ${task_number}: postflight status write skipped -- task is archived (the archive is read-only; artifact link, if any, is still applied by the caller)." >&2
  elif [[ "$status_clamp_mode" == "monotonic-max" ]]; then
    # Same two-candidate resolution order skill-base.sh's own lib/common.sh source (top of this
    # file) already uses: SKILL_REPO_ROOT-qualified deployed path first, source-store-relative
    # BASH_SOURCE fallback second. Do not invent a third order.
    if [[ -f "${SKILL_REPO_ROOT}/.claude/scripts/lib/status-vocabulary.sh" ]]; then
      source "${SKILL_REPO_ROOT}/.claude/scripts/lib/status-vocabulary.sh"
    elif [[ -f "$(dirname "${BASH_SOURCE[0]}")/lib/status-vocabulary.sh" ]]; then
      source "$(dirname "${BASH_SOURCE[0]}")/lib/status-vocabulary.sh"
    fi
    if declare -F status_vocabulary_would_regress >/dev/null 2>&1; then
      # Archive-aware comparator (task-lookup-lib.sh): task_lookup_entry falls back to the
      # archive when the number is absent from active_projects. The archive-absent guard above
      # already handles the fully-archived case; this keeps the comparator correct (rather than
      # silently empty, which disables the clamp) for any future caller that reaches this branch
      # for a task resolvable only via the archive.
      local _clamp_current_status
      _clamp_current_status=$(task_lookup_entry "$task_number" specs/state.json | jq -r '.status // ""' 2>/dev/null)
      if [[ -n "$_clamp_current_status" ]] && status_vocabulary_would_regress "$_clamp_current_status" "$status"; then
        _skip_write=true
        echo "[monotonic-max] task ${task_number}: forced ${operation} would regress status from '${_clamp_current_status}' to '${status}' — skipping the status write (artifact link, if any, is still applied by the caller)."
      fi
    else
      echo "WARNING: [skill-base] status_clamp_mode=monotonic-max requested but status_vocabulary_would_regress is not resolvable (deploy-first stale-copy hazard?) — clamp not applied, status write proceeds normally." >&2
    fi
  fi
  case "$status" in
    researched|planned|implemented)
      if [[ "$_skip_write" == "true" ]]; then
        :
      else
        # --file-scope-add write-back: two independent sources, mirroring
        # orchestrator-postflight.sh's Stage 7 branch (this function is the OTHER, actually-live
        # plan-postflight path -- orchestrator-postflight.sh itself has no live callers; see its
        # own header note -- so both must carry the harvest, not only the orphaned one). research
        # reads proposed_file_scope from this task's own .return-meta.json; plan instead harvests
        # the latest plan artifact's own "Files to modify" per-phase field via
        # plan-file-scope-harvest.sh (never re-implementing extraction). Both forward the result
        # as --file-scope-add=<json> so update-task-status.sh's additive union-merge picks it up
        # in the same postflight write. Same empty-array-expansion pattern as phase_check_args
        # above -- an absent field, null, or [] passes no flag at all (byte-for-byte no-op).
        local _fsa_args=()
        if [[ "$operation" == "research" && -n "${_task_dir}" && -f "${_task_dir}/.return-meta.json" ]]; then
          local _proposed_fs
          _proposed_fs=$(jq -c '.proposed_file_scope // [] | if (type == "array") then . else [] end' \
            "${_task_dir}/.return-meta.json" 2>/dev/null)
          if [[ -n "$_proposed_fs" && "$_proposed_fs" != "[]" && "$_proposed_fs" != "null" ]]; then
            _fsa_args=(--file-scope-add="$_proposed_fs")
          fi
        elif [[ "$operation" == "plan" && -n "${_task_dir}" && -d "${_task_dir}/plans" ]]; then
          local _plan_file _harvested_fs
          # Version-ordered latest plan file, same convention as reconcile-task-status.sh's
          # find_latest_artifact() and update-task-status.sh's resolve_plan_file_for_phase_check().
          # `|| true`: an existing-but-empty plans/ dir makes the glob a literal nonexistent
          # filename under set -e -o pipefail; that is a legitimate no-plan-yet state, not an error.
          _plan_file=$(ls -1 "${_task_dir}/plans/"*.md 2>/dev/null | sort -V | tail -1 || true)
          if [[ -n "$_plan_file" && -f "$_plan_file" ]]; then
            _harvested_fs=$(bash .claude/scripts/plan-file-scope-harvest.sh "$_plan_file" 2>/dev/null) \
              || echo "WARNING: [skill-base] plan-file-scope-harvest.sh failed for $_plan_file, skipping file_scope harvest for this postflight (non-blocking)" >&2
            if [[ -n "$_harvested_fs" && "$_harvested_fs" != "[]" && "$_harvested_fs" != "null" ]]; then
              _fsa_args=(--file-scope-add="$_harvested_fs")
            fi
          fi
        fi
        bash .claude/scripts/update-task-status.sh postflight "$task_number" "$operation" "$session_id" "${phase_check_args[@]}" "${_fsa_args[@]}" || _postflight_rc=$?
      fi
      ;;
    partial)
      if [[ "$_skip_write" == "true" ]]; then
        :
      else
        # target_status is the literal "partial" token, NOT "$operation" -- mirrors the
        # needs_research arm below (target_status is a fixed outcome token, independent of which
        # phase dispatched). update-task-status.sh's map_status() resolves postflight:partial to
        # STATE_STATUS="partial" (state-management.md's permissive transition model: any non-
        # terminal status admits partial/blocked on timeout/error). Caller gates this arm on a
        # non-empty handoff blockers[] -- see orchestrate-cycle-postflight.sh's `partial)` arm.
        bash .claude/scripts/update-task-status.sh postflight "$task_number" partial "$session_id" "${phase_check_args[@]}" || _postflight_rc=$?
      fi
      ;;
    needs_research)
      if [[ "$_skip_write" == "true" ]]; then
        :
      else
        # --research-questions write-back: read research_questions from this task's own
        # .return-meta.json (planner-produced, see context/formats/return-metadata-file.md's
        # ### research_questions (optional) section) and forward it so
        # update-task-status.sh's overwrite-on-write persists it in the same postflight write.
        # Structurally the _fsa_args sibling above, but OVERWRITE not merge -- see that flag's
        # own header comment in update-task-status.sh.
        local _rq_args=()
        if [[ -n "${_task_dir}" && -f "${_task_dir}/.return-meta.json" ]]; then
          local _research_questions
          _research_questions=$(jq -c '.research_questions // [] | if (type == "array") then . else [] end' \
            "${_task_dir}/.return-meta.json" 2>/dev/null)
          if [[ -n "$_research_questions" && "$_research_questions" != "[]" && "$_research_questions" != "null" ]]; then
            _rq_args=(--research-questions="$_research_questions")
          fi
        fi
        # target_status is the literal "needs_research" token, NOT "$operation" -- this is a
        # planner-only outcome and update-task-status.sh's map_status() resolves
        # postflight:needs_research to STATE_STATUS="researching" independent of which phase
        # ($operation, always "plan" on this path) dispatched the planner.
        bash .claude/scripts/update-task-status.sh postflight "$task_number" needs_research "$session_id" "${phase_check_args[@]}" "${_rq_args[@]}" || _postflight_rc=$?
      fi
      ;;
    *)
      echo "[skill-base] Non-success status '${status}' — postflight status update skipped"
      ;;
  esac

  # On a deploy-pending refusal (exit 6) specifically: emit a named line and record a
  # deploy_pending reason into the task's own .return-meta.json, so /orchestrate's and the team
  # skills' own reporting surfaces the deferral instead of showing an unexplained
  # non-completion (the D6 residual mitigation named in the plan's Risks table). Best-effort and
  # non-blocking -- a failure to annotate .return-meta.json never escalates past a warning, since
  # the authoritative outcome is already update-task-status.sh's own rc.
  if [[ "$_postflight_rc" -eq 6 ]]; then
    echo "[deploy-check] deploy-pending: task ${task_number} postflight refused by the completion-deploy gate (exit 6) — modified_files overlap agent-system/extensions/** and the deploy is stale."
    if [[ -n "${_task_dir}" && -f "${_task_dir}/.return-meta.json" ]]; then
      local _dp_tmp
      _dp_tmp="$(mktemp)"
      if jq '. + {deploy_pending: true, deploy_pending_reason: "postflight completion-deploy gate refused (exit 6): modified_files overlap agent-system/extensions/** and the deploy is stale"}' \
        "${_task_dir}/.return-meta.json" > "$_dp_tmp" 2>/dev/null; then
        mv "$_dp_tmp" "${_task_dir}/.return-meta.json"
      else
        rm -f "$_dp_tmp" 2>/dev/null
        echo "WARNING: [skill-base] failed to record deploy_pending reason into ${_task_dir}/.return-meta.json" >&2
      fi
    fi
  fi

  # Extension hook: postflight (runs after status update, non-blocking)
  skill_run_extension_hook "postflight" "$task_number" "${TASK_TYPE:-}" "${TASK_DIR:-}" "$session_id" "$operation"
  # Unified event store: one non-blocking milestone event per lifecycle stage
  local _dur
  _dur=$(awk -v a="$_t0" -v b="$(date +%s.%N)" 'BEGIN{printf "%.3f", b-a}')
  _events_append_observable ".claude/scripts/events-append.sh" \
    --event-type lifecycle_stage --category milestone \
    --checkpoint postflight --duration "$_dur" --task "$task_number" --session "$session_id" \
    --message "Postflight stage completed for ${operation} (status: ${status})"

  return "$_postflight_rc"
}

# ─────────────────────────────────────────────────────────────────────────────
# Stage 7a: Propagate memory candidates to state.json
# Usage: skill_propagate_memory_candidates "$task_number" "$memory_candidates_json" ["$session_id"]
#
# Reads the `memory_candidates` array a subagent emitted in the task's `.return-meta.json` (the
# caller extracts it via `skill_read_metadata` or an equivalent `jq -c '.memory_candidates // []'`
# read) and appends it to the task's state.json entry using append semantics -- merged with any
# existing candidates from prior operations, never overwritten. This is a distinct function from
# `skill_propagate_completion_summary` below, which does NOT handle `memory_candidates` today;
# the two propagate different `.return-meta.json` fields and are kept separate rather than
# folded together; keeping them distinct means an existing `skill_propagate_completion_summary`
# call site is never accidentally widened to also start writing `memory_candidates`.
#
# Follows `skill_propagate_completion_summary`'s established conventions: writes are routed
# through "${SKILL_REPO_ROOT}/.claude/scripts/state-write.sh" (SKILL_REPO_ROOT-qualified, not a
# bare relative path, so this keeps working when invoked from a fixture repo via SKILL_REPO_ROOT
# override), and session_id (3rd arg, optional) is self-generated via `common_session_id` when
# omitted, exactly as that function's 5th-arg session_id handling.
skill_propagate_memory_candidates() {
  local task_number="$1"
  local memory_candidates="$2"
  local session_id="${3:-}"
  if [ -z "$session_id" ]; then
    session_id="$(common_session_id)"
  fi
  if [ -n "$memory_candidates" ] && [ "$memory_candidates" != "[]" ]; then
    "${SKILL_REPO_ROOT}/.claude/scripts/state-write.sh" \
      '(.active_projects[] | select(.project_number == $num)).memory_candidates =
        ((.active_projects[] | select(.project_number == $num)).memory_candidates // []) + $new_candidates' \
      --session-id "$session_id" \
      --argjson num "$task_number" \
      --argjson new_candidates "$memory_candidates" \
      || echo "WARNING: state-write.sh failed to write memory_candidates (non-blocking)" >&2
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Stage 7a-skel: Propagate skeleton follow-ups to state.json
# Usage: skill_propagate_skeleton_follow_ups "$task_number" "$follow_ups_json" ["$session_id"]
#
# Reads the enriched, strategic-only `sorry_inventory` entries orchestrate-cycle-postflight.sh's
# `implemented)` case derives from a skeleton=true final implement handoff, and appends them to
# the task's state.json entry using append-only semantics -- merged with any existing follow-ups
# from a prior skeleton completion, never overwritten. This is a distinct function from
# `skill_propagate_memory_candidates` above and `skill_propagate_completion_summary` below:
# all three propagate different `.return-meta.json`/handoff fields and are kept separate rather
# than folded together, so widening one call site never accidentally starts writing a field it
# was never meant to touch.
#
# Report-only: this function creates no tasks. The entries it records are surfaced to the human,
# who files follow-ups with /task; see context/reference/state-management-schema.md's
# "Skeleton Follow-Ups Field" subsection for the full lifecycle (Producer/Consumer/Semantics).
#
# Follows `skill_propagate_memory_candidates`'s established conventions: writes are routed
# through "${SKILL_REPO_ROOT}/.claude/scripts/state-write.sh" (SKILL_REPO_ROOT-qualified, not a
# bare relative path, so this keeps working when invoked from a fixture repo via SKILL_REPO_ROOT
# override), and session_id (3rd arg, optional) is self-generated via `common_session_id` when
# omitted.
skill_propagate_skeleton_follow_ups() {
  local task_number="$1"
  local follow_ups_json="$2"
  local session_id="${3:-}"
  if [ -z "$session_id" ]; then
    session_id="$(common_session_id)"
  fi
  if [ -n "$follow_ups_json" ] && [ "$follow_ups_json" != "[]" ]; then
    "${SKILL_REPO_ROOT}/.claude/scripts/state-write.sh" \
      '(.active_projects[] | select(.project_number == $num)).skeleton_follow_ups =
        ((.active_projects[] | select(.project_number == $num)).skeleton_follow_ups // []) + $new_follow_ups' \
      --session-id "$session_id" \
      --argjson num "$task_number" \
      --argjson new_follow_ups "$follow_ups_json" \
      || echo "WARNING: state-write.sh failed to write skeleton_follow_ups (non-blocking)" >&2
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Stage 7b: Propagate completion_summary + roadmap_items to state.json
# Usage: skill_propagate_completion_summary "$task_number" "$completion_summary" "$roadmap_items" "$task_type" ["$session_id"]
#
# Single shared implementation of the guarded completion-data write, replacing what were
# previously three independently-maintained copies (the base lifecycle implement skill, the
# deleted standalone hard-mode implementer skill, and the orphaned orchestrator-postflight.sh
# Stage 7b -- all three since deleted). Every
# caller — general-implementation-agent's own producer path AND all four /orchestrate paths
# (base single-task, base multi-task Stage MT-4, hard single-task, hard multi-task via inherited
# MT-4) — converges on this one function.
#
# Guard semantics (unchanged from the prior three copies):
#   - completion_summary is written only when non-empty.
#   - roadmap_items is written only when task_type is not "meta" AND the value is neither
#     empty nor the literal string "[]".
#
# Routes both writes through state-write.sh, the single mutex-guarded specs/state.json writer
# (${SKILL_REPO_ROOT}/.claude/scripts/state-write.sh -- the SKILL_REPO_ROOT-qualified path, not a
# relative one, so this function keeps working when invoked from a fixture repo via
# SKILL_REPO_ROOT override, exactly like the generate-todo.sh call in skill_link_artifacts
# below). Still uses jq --arg/--argjson exclusively (never shell-interpolated Python string
# literals), so arbitrary prose in a summary — quotes, newlines, triple-quotes, backslashes —
# cannot break the write.
#
# session_id (5th arg, optional) attributes the specs/.scope-lock mutex acquisition. When
# invoked from inside an outer SCOPE_MUTEX_HELD=1 critical section (e.g.
# orchestrator-postflight.sh's Stage 7-8a bracket, this function's normal calling context),
# state-write.sh runs as a guest and never attempts a nested acquire regardless of which
# session_id is passed. If omitted, a session_id is generated via the shared
# scripts/lib/common.sh's common_session_id (the single source every session-ID call site now
# shares -- see command-gate-in.sh), so every existing caller keeps working unchanged.
skill_propagate_completion_summary() {
  local task_number="$1"
  local completion_summary="$2"
  local roadmap_items="$3"
  local task_type="$4"
  local session_id="${5:-}"
  if [ -z "$session_id" ]; then
    session_id="$(common_session_id)"
  fi
  if [ -n "$completion_summary" ]; then
    "${SKILL_REPO_ROOT}/.claude/scripts/state-write.sh" \
      '(.active_projects[] | select(.project_number == $num)).completion_summary = $summary' \
      --session-id "$session_id" \
      --argjson num "$task_number" \
      --arg summary "$completion_summary" \
      || echo "WARNING: state-write.sh failed to write completion_summary (non-blocking)" >&2
  fi
  if [ "$task_type" != "meta" ] && [ "$roadmap_items" != "[]" ] && [ -n "$roadmap_items" ]; then
    "${SKILL_REPO_ROOT}/.claude/scripts/state-write.sh" \
      '(.active_projects[] | select(.project_number == $num)).roadmap_items = $items' \
      --session-id "$session_id" \
      --argjson num "$task_number" \
      --argjson items "$roadmap_items" \
      || echo "WARNING: state-write.sh failed to write roadmap_items (non-blocking)" >&2
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Stage 8: Link artifacts to state.json and TODO.md
# Usage: skill_link_artifacts "$task_number" "$artifact_path" "$artifact_type" "$artifact_summary" "$field_name" "$next_field" ["$session_id"]
# artifact_type: "research" | "plan" | "summary"
# field_name:   '**Research**' | '**Plan**' | '**Summary**'
# next_field:   '**Plan**' (research) | '**Description**' (plan/summary)
# Uses two-step jq pattern to avoid Issue #1132 (!=  escaping bug), both steps routed through
# state-write.sh -- see skill_propagate_completion_summary's header comment above for the full
# SKILL_REPO_ROOT-qualified-path and session_id/self-generation rationale, identical here.
#
# Append-only note (rules/state-management.md's "Artifacts Are Append-Only (With Same-Type
# Supersession)" subsection): Step 1's removal below is a same-type, 1-for-1 "latest pointer"
# swap -- it drops every existing entry of $artifact_type before Step 2 adds exactly one new
# entry of that same type. This is the one sanctioned exception to append-only and is exempt by
# construction under validate-state.sh --deep's per-type artifact-loss invariant
# (removed(T) <= added(T)), since this call always nets zero or a 1-for-1 replace. Do NOT
# generalize this pattern into a wholesale `.artifacts = [...]` assignment elsewhere -- that
# replaces the whole array and silently discards every artifact link not re-included, which the
# invariant is designed to catch.
skill_link_artifacts() {
  local task_number="$1"
  local artifact_path="$2"
  local artifact_type="$3"
  local artifact_summary="$4"
  local field_name="${5:-'**Summary**'}"
  local next_field="${6:-'**Description**'}"
  local session_id="${7:-}"
  if [ -z "$session_id" ]; then
    session_id="$(common_session_id)"
  fi
  if [ -n "$artifact_path" ]; then
    # Step 1: Remove existing artifacts of same type (use "| not" pattern — Issue #1132 safe)
    "${SKILL_REPO_ROOT}/.claude/scripts/state-write.sh" \
      '(.active_projects[] | select(.project_number == $num)).artifacts =
        [(.active_projects[] | select(.project_number == $num)).artifacts // [] | .[] | select(.type == $atype | not)]' \
      --session-id "$session_id" \
      --argjson num "$task_number" \
      --arg atype "$artifact_type" \
      || echo "WARNING: state-write.sh failed removing same-type artifacts (non-blocking)" >&2
    # Step 2: Add new artifact entry
    "${SKILL_REPO_ROOT}/.claude/scripts/state-write.sh" \
      '(.active_projects[] | select(.project_number == $num)).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
      --session-id "$session_id" \
      --argjson num "$task_number" \
      --arg path "$artifact_path" \
      --arg type "$artifact_type" \
      --arg summary "$artifact_summary" \
      || echo "WARNING: state-write.sh failed adding artifact entry (non-blocking)" >&2
    # Regenerate TODO.md from state.json (replaces link-artifact-todo.sh call)
    bash "${SKILL_REPO_ROOT}/.claude/scripts/generate-todo.sh" || echo "WARNING: generate-todo.sh failed (non-fatal)"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Stage 8a: Lifecycle TTS notification
# Usage: skill_lifecycle_notify "$state_status"
#
# Single shared implementation of the TTS + WezTerm tab-coloring notification body every
# lifecycle skill's Stage 8a hand-copies today (11 near-identical inline blocks pre-unification).
# Guards on the notify script's presence, backgrounds the invocation, and never blocks --
# exactly the shape every existing inline copy already shares (see e.g.
# `skill-reviser/SKILL.md`'s "Stage 8b: Lifecycle TTS Notification").
skill_lifecycle_notify() {
  local state_status="$1"
  local lifecycle_script=".claude/scripts/lifecycle-notify.sh"
  if [ -z "$state_status" ]; then
    echo "WARNING: skill_lifecycle_notify called with an empty status argument -- no lifecycle notification will be sent. This usually means the caller passed an unset/misnamed variable (e.g. a stale \$STATE_STATUS instead of \$status) as its Stage 8a argument." >&2
    return 0
  fi
  if [ -f "$lifecycle_script" ]; then
    bash "$lifecycle_script" "$state_status" &
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Stage 9/10: Cleanup temporary files
# Usage: skill_cleanup "$padded_num" "$project_name"
# Removes .postflight-pending and .postflight-loop-guard only. .return-meta.json
# is NOT removed here: this function runs at the skill's own Stage 9, which
# always fires before the calling command's command-gate-out.sh (defensive
# status correction, skill_validate_task_artifacts) and, further downstream,
# the command's own CHECKPOINT 3 commit block (or, for /revise, the step right
# after gate-out) ever read the file. Deleting it here made that entire body
# structurally unreachable. Ownership of .return-meta.json's deletion belongs
# to the calling command's own last step that consumes it -- see each of
# commands/{research,plan,implement,revise,orchestrate}.md for its site, and
# skill-spawn/SKILL.md Stage 16 for the one caller with no command-level
# consumer, which deletes the file inline itself.
# Note: Implementer also removes .continuation-loop-guard inline (after calling this)
skill_cleanup() {
  local padded_num="$1"
  local project_name="$2"
  local task_dir="specs/${padded_num}_${project_name}"
  rm -f "${task_dir}/.postflight-pending" \
        "${task_dir}/.postflight-loop-guard" 2>/dev/null || true
}

# ───────────────────────────────────────────────────────────────────────────
# Completion-claim verification gate
# Usage: skill_gate_completion_claim "$task_number" "$phases_completed" \
#          "$phases_total" "$plan_markers_verified" "$log_prefix"
#
#   $1 = task_number            : task number, named in every log line
#   $2 = phases_completed       : integer from the handoff's TOP-LEVEL field (jq '// 0')
#   $3 = phases_total           : integer from the handoff's TOP-LEVEL field (jq '// 0')
#   $4 = plan_markers_verified  : "true" | "false" | "absent" (jq '// "absent"')
#   $5 = log_prefix             : "[orchestrate]" or "[hard-orchestrate]"
#
# Returns 0 = ALLOW the completed transition; 1 = REFUSE it. On a refuse the caller MUST skip
# skill_postflight_update entirely, leave the task at `implementing`, and let the surrounding
# cycle counter increment as usual, so the next cycle re-dispatches implement and the existing
# MAX_CYCLES / MAX_CYCLES_MT caps bound the retry.
#
# All evidence is read from fields the caller already parsed out of
# .orchestrator-handoff.json. This function never reads a plan file, report, or summary, and
# never invokes the Stage 5 phase-marker recovery grep — that exception is scoped to the
# missing/stale-handoff branch and this gate fires only when a handoff IS present and fresh.
#
# This unification is a deliberate behavior change from the two inline gates it replaces:
#   - base mode LOSES its `phases_total == 0` blind allow (it used to unconditionally allow
#     completion when phase accounting was absent; it now requires plan_markers_verified=true).
#   - hard mode LOSES its `phases_total == 0` blind refuse (it used to unconditionally refuse
#     when phase accounting was absent; it now allows on plan_markers_verified=true).
#   Both are replaced by the single corroborated Case 3 fallback below.
#
# This function is the ONLY place the three-case logic may live. Inlining a copy at a call site
# is the drift this refactor exists to prevent — call this function from every site instead.
skill_gate_completion_claim() {
  local task_number="$1"
  local phases_completed="$2"
  local phases_total="$3"
  local plan_markers_verified="$4"
  local log_prefix="$5"

  # Sanitize: a non-integer is missing evidence, not an arithmetic error. Coerce to 0 so it
  # always falls through to Case 3 (fail closed) rather than crashing `-ge`/`-gt` under `set -e`.
  [[ "$phases_completed" =~ ^[0-9]+$ ]] || phases_completed=0
  [[ "$phases_total" =~ ^[0-9]+$ ]] || phases_total=0

  if [ "$phases_total" -gt 0 ] && [ "$phases_completed" -ge "$phases_total" ]; then
    # Case 2: phase accounting present and complete — the only unconditional allow.
    echo "${log_prefix} COMPLETION-CLAIM GATE case 2/3 (phase accounting present and complete) task ${task_number}: ${phases_completed}/${phases_total} — allowing completion." >&2
    return 0
  fi

  if [ "$phases_total" -gt 0 ]; then
    # Case 1: phase accounting present but incomplete — always refuse.
    echo "${log_prefix} COMPLETION-CLAIM GATE case 1/3 (phase accounting present, incomplete) task ${task_number}: ${phases_completed}/${phases_total} — refusing completion; task stays implementing." >&2
    return 1
  fi

  # Case 3: phases_total == 0, i.e. accounting absent or malformed. Fall back to the
  # corroborating plan_markers_verified signal.
  if [ "$plan_markers_verified" = "true" ]; then
    echo "${log_prefix} COMPLETION-CLAIM GATE case 3/3 (phase accounting absent, plan_markers_verified=true) task ${task_number}: allowing completion on the corroborating marker signal." >&2
    return 0
  fi

  # Deliverable 2(b): record this Case 3/3 refuse (handoff-writer defect suspected). Attribution
  # is derived mechanically from log_prefix via a fixed two-entry lookup (D2's decision, recorded
  # here so a future reader does not re-open the question): the handoff-write contract each
  # engine imposes on its own dispatches genuinely lives in that engine's own SKILL.md. A 6th
  # `dispatched_agent` parameter on this shared function was considered and rejected as
  # disproportionate — it would change a shared function's signature at three call sites for a
  # marginal attribution gain; this mechanical log_prefix-derived lookup gets the same signal
  # without doing so. An unrecognized log_prefix resolves to a deliberately unresolvable
  # placeholder, so the recorder itself refuses (Signal B attribution unresolvable) and the note
  # below is absorbed non-fatally — this function's own return value is never affected either way.
  # "[hard-orchestrate]" was the standalone hard-mode engine's own log_prefix; that file is
  # deleted and no live caller passes this label any more -- skill-orchestrate/SKILL.md's single
  # call site (both effort modes) always passes "[orchestrate]". The arm is removed rather than
  # retargeted since it is genuinely unreachable, not merely renamed.
  case "$log_prefix" in
    "[orchestrate]") gate_attributed_path="agent-system/extensions/core/skills/skill-orchestrate/SKILL.md" ;;
    *)                gate_attributed_path="unresolved:${log_prefix}" ;;
  esac
  bash .claude/scripts/system-defect-record.sh \
    --defect-class META_MISSING_AFTER_NARRATION \
    --detecting-site "scripts/skill-base.sh:skill_gate_completion_claim" \
    --task "$task_number" \
    --message "completion-claim gate case 3/3 refuse: phase accounting absent and plan_markers_verified is not true" \
    --attributed-path "$gate_attributed_path" \
    >/dev/null 2>&1 || echo "Note: system-defect recording failed (non-fatal)" >&2

  echo "${log_prefix} COMPLETION-CLAIM GATE case 3/3 (phase accounting absent, plan_markers_verified=${plan_markers_verified}) task ${task_number}: refusing completion — handoff-writer defect suspected; task stays implementing." >&2
  return 1
}

# ───────────────────────────────────────────────────────────────────────────
# Shared plan-heading corroboration
# Usage: skill_corroborate_phase_counts "$task_number" "$plan_path" "$log_prefix" ["$handoff_path"]
#
#   $1 = task_number   : task number, named in every log line
#   $2 = plan_path     : path to the plan file to corroborate against (may be empty)
#   $3 = log_prefix    : "[orchestrate]" or "[hard-orchestrate]"
#   $4 = handoff_path  : OPTIONAL. When non-empty and the file exists, validate-handoff.sh is
#                        invoked against it as a log-only, non-gating producer-defect diagnostic
#                        (D5/B1 below). Its exit status never influences this function's own
#                        return value. Pass an EMPTY string on the recovery-path call sites
#                        (Phase 7 of the plan that introduced this function) — there is no
#                        handoff to validate on that path.
#
# Prints exactly one line on stdout, shell-assignable via `read` (callers MUST NOT `eval` it):
#   phases_completed=<int> phases_total=<int> plan_markers_verified=<true|absent>
#
# Returns 0 when corroborated (plan_markers_verified=true), 1 otherwise — including the
# non-conforming-heading case and the no-plan-file case. Both are "not corroborated", never a
# crash.
#
# This is a faithful lift of the three-way branch that used to live inline, once per engine, in
# the recovered=true branch of skill-orchestrate/SKILL.md Stage 5 (and its Stage MT-4 step 1, plus
# the now-deleted standalone hard-mode engine's own Stage 5 mirror) — this function changes WHERE
# the logic lives, never the branch outcomes. All recovery-path call sites were migrated to call
# this function rather than keep their own copy; see skill-orchestrate/SKILL.md's Stage 5 / Stage
# MT-4 for the call sites, and the "Evidence corroboration" comment they still carry.
#
# ── D3 (deliberate divergence, UPDATED): trigger precondition is now `dispatch_status ==
# "implemented"` alone, not `phases_total -eq 0` alone ───────────────────────────────────────────
# This function's ORIGINAL sole caller was orchestrate-cycle-postflight.sh's Case 3 shape
# (`phases_total == 0`); the corroboration-trigger widening described in
# context/standards/status-markers.md's "Decision gates and contingency branches" subsection
# extended that caller's own precondition to ALSO cover the Case 1 shape (`phases_total > 0` but
# `phases_completed < phases_total`), so this function is now reached for BOTH shapes. This
# function itself is unchanged: it still writes only phases_completed / phases_total /
# plan_markers_verified, and only from an INDEPENDENT artifact (the plan file's own headings) —
# never from the handoff's own values. It does not re-derive its caller's trigger precondition
# internally; the caller alone decides when to invoke it (see orchestrate-cycle-postflight.sh's
# own corroboration-block comment for the current, full precondition).
#
# ── D4 (structural, not a promise): the completion gate is never weakened ────────────────────────
# The gate itself (skill_gate_completion_claim) still refuses UNCONDITIONALLY on
# `phases_total > 0 && phases_completed < phases_total` (Case 1) — that refusal logic is
# byte-unchanged. What changed is only which INPUTS the gate sees: its caller now corroborates the
# plan's own markers BEFORE invoking it, and gates the resulting overwrite on
# `plan_markers_verified == "true"`, so a non-corroborating result never touches
# phases_completed/phases_total at all — the caller's Case 1 refusal is then reached with the
# handoff's own (unmodified, honestly understated or accurate) counters, exactly as before this
# function existed. A corroborated correction therefore never OVERRIDES a refusal; it can only
# supply independent evidence that moves an otherwise-Case-1-shaped call into Case 2 when the
# plan's own markers genuinely show every phase closed.
skill_corroborate_phase_counts() {
  local task_number="$1"
  local plan_path="$2"
  local log_prefix="$3"
  local handoff_path="${4:-}"

  # Deploy-tree-first / source-store-fallback candidate resolution, matching
  # scripts/tests/test-phase-heading-patterns.sh's own resolution so this function works both
  # post-deploy (.claude/scripts/lib/...) and in a source-store-only checkout
  # (agent-system/extensions/core/scripts/lib/...).
  local _cpc_lib_candidates=(
    ".claude/scripts/lib/phase-heading-patterns.sh"
    "$(dirname "${BASH_SOURCE[0]}")/lib/phase-heading-patterns.sh"
  )
  local _cpc_lib=""
  local _cpc_candidate
  for _cpc_candidate in "${_cpc_lib_candidates[@]}"; do
    if [ -f "$_cpc_candidate" ]; then
      _cpc_lib="$_cpc_candidate"
      break
    fi
  done
  if [ -z "$_cpc_lib" ]; then
    echo "${log_prefix} Evidence corroboration: phase-heading-patterns.sh not found at any candidate path for task ${task_number} — leaving plan_markers_verified=absent." >&2
    echo "phases_completed=0 phases_total=0 plan_markers_verified=absent"
    return 1
  fi
  # shellcheck disable=SC1090
  . "$_cpc_lib"

  # Never treat a missing/empty plan path as corroboration.
  if [ -z "$plan_path" ] || [ ! -f "$plan_path" ]; then
    echo "${log_prefix} Evidence corroboration: no plan file found to corroborate against for task ${task_number} — leaving plan_markers_verified=absent." >&2
    echo "phases_completed=0 phases_total=0 plan_markers_verified=absent"
    return 1
  fi

  # `x=$(grep -c ...) || x=0` idiom, never `$(grep -c ... || echo 0)` — the latter emits two
  # lines on zero matches.
  local _cpc_total _cpc_completed
  _cpc_total=$(grep -cE "$PHASE_HEADING_ERE" "$plan_path" 2>/dev/null) || _cpc_total=0
  _cpc_completed=$(grep -cE "$PHASE_HEADING_DONE_ERE" "$plan_path" 2>/dev/null) || _cpc_completed=0

  local _cpc_rc=1
  local _cpc_out_completed=0
  local _cpc_out_total=0
  local _cpc_out_verified="absent"

  if has_nonconforming_phase_headings "$plan_path"; then
    warn_nonconforming "$plan_path" "corroborate-phase-counts" || true
    echo "${log_prefix} Evidence corroboration: non-conforming phase heading(s) in ${plan_path} — counts unreliable; leaving plan_markers_verified=absent." >&2
    _cpc_rc=1
  elif [ "$_cpc_total" -gt 0 ] && [ "$_cpc_completed" -eq "$_cpc_total" ]; then
    _cpc_out_completed="$_cpc_completed"
    _cpc_out_total="$_cpc_total"
    _cpc_out_verified="true"
    echo "[UNVERIFIED PHASES CORROBORATED] task ${task_number}: plan headings in ${plan_path} show ${_cpc_completed}/${_cpc_total} phases closed (COMPLETED or COMPLETED WITH EXCLUSIONS). Corroborated by an independent source — correcting phase counts and setting plan_markers_verified=true." >&2
    _cpc_rc=0
  else
    # False-positive guard: no contradiction to resolve (a plan with zero phase headings, or a
    # genuine partial-completion plan). Leave plan_markers_verified=absent and the counts at 0/0
    # — do not treat this as a second trigger.
    echo "${log_prefix} Evidence corroboration: non-corroborating (plan headings show ${_cpc_completed}/${_cpc_total} in ${plan_path}) — leaving plan_markers_verified=absent." >&2
    _cpc_rc=1
  fi

  if [ -n "$handoff_path" ] && [ -f "$handoff_path" ]; then
    # Log-only, non-gating producer-defect diagnostic (D5/B1). Never allowed to influence this
    # function's own return value — guarded with `|| true` because validate-handoff.sh runs under
    # `set -euo pipefail` and exits non-zero on any failed check.
    bash .claude/scripts/validate-handoff.sh "$handoff_path" >&2 || true
  fi

  echo "phases_completed=${_cpc_out_completed} phases_total=${_cpc_out_total} plan_markers_verified=${_cpc_out_verified}"
  return "$_cpc_rc"
}

# ── Orchestrate-engine dedup: named-shim targets ─────────────────────────────────────────────────
# The three functions below are the single home for logic that used to be verbatim-twinned
# (byte-identical, or identical-but-for-a-notice-prefix) between skill-orchestrate/SKILL.md's
# base-mode Stage 2/4/5 and the now-deleted standalone hard-mode engine's own Stage 2 and
# Stage 4/5 — since merged into this one file's `$hard_mode`-forked branches.
# skill-orchestrate/SKILL.md keeps a <=3-line local function with the SAME NAME the pre-dedup
# code used (`mint_dispatch_seq`, `append_detected_defect`, `hard_orchestrate_propagate_completion`),
# delegating to these shared implementations — "named-shim preservation". HISTORICAL NOTE
# (checked during the per-run cycle-budget task): the two tests this paragraph used to name as
# the reason for that preservation (one of which, test-loop-guard-budget-override.sh, is now
# deleted along with the `--continue-budget` mechanism it covered) no longer `eval`/stub these
# names by exact string match — a `grep -rl append_detected_defect` over scripts/tests/ today
# finds nothing. The named-shim convention itself is left unchanged (harmless either way, and
# still the documented contract for skill-orchestrate/SKILL.md's own local shims), but the
# specific test-coupling rationale this paragraph gave is stale and not restated here.
#
# Per the "no ambient global for a value that differs per engine" rule, `loop_guard_file` and the
# notice prefix are always explicit parameters below. `task_number` and `cycle_count` remain
# ambient (read directly, matching the pre-dedup inline bodies) because they are the SAME-SHAPED
# value in both engines' calling scope, not per-engine-differing state.

# skill_orchestrate_mint_dispatch_seq <loop_guard_file>
# Increments the dispatch_seq_counter persisted in the loop guard and returns the new value on
# stdout. Call immediately before every Agent dispatch that writes .orchestrator-handoff.json,
# adjacent to the dispatch_start_ts capture (Defect A). Persisting on every mint (not only at
# Stage 3b) guarantees the value survives a resume and is never repeated within this task, even
# across separate /orchestrate invocations. The new value is derived EXCLUSIVELY by reading
# `.dispatch_seq_counter` back out of `$loop_guard_file` -- never from any ambient shell
# variable -- so the result is correct even when each stage of the calling loop runs in its own
# fresh shell/subprocess (the precondition an earlier ambient-variable-based body silently
# assumed and did not hold, causing every mint to collapse to 1). See
# context/patterns/dispatch-report-not-termination.md for why an orchestrator-minted value is
# required rather than content the dispatched agent could echo unprompted.
skill_orchestrate_mint_dispatch_seq() {
  local loop_guard_file="$1"
  local new_seq
  new_seq=$(jq -r '(.dispatch_seq_counter // 0) + 1' "$loop_guard_file")
  jq --argjson seq "$new_seq" \
     --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '.dispatch_seq_counter = $seq | .last_updated = $updated' \
    "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
  echo "$new_seq"
}

# skill_orchestrate_append_detected_defect <loop_guard_file> <notice_prefix> <class>
#   <attributed_path> <site> <detail> [record_result]
# Appends one entry to `.detected_defects` on the given loop guard file and emits the
# `[system-defect:auto]` notice on stderr itself, so no call site can append without announcing.
# The append is UNCONDITIONAL: never gated on the recorder's exit code, nor on a
# `SUPPRESSED:recursion_guard`/`SUPPRESSED:duplicate` value on its stdout. `record_result` records
# that outcome for the operator; it never decides whether the entry exists. `.detected_defects +=
# [...]` is safe against a guard file written before the field existed: jq's `null + [x]` is
# `[x]`, so the log self-heals rather than erroring.
skill_orchestrate_append_detected_defect() {
  local loop_guard_file="$1" notice_prefix="$2" class="$3" attributed_path="$4" site="$5" \
        detail="$6" record_result="${7:-}"
  jq --argjson entry "$(jq -c -n \
        --argjson task "$task_number" --arg class "$class" --arg path "$attributed_path" \
        --arg site "$site" --argjson cycle "${cycle_count:-0}" --arg detail "$detail" \
        --arg rr "$record_result" \
        '{task:$task, defect_class:$class, attributed_source_path:$path,
          detecting_site:$site, cycle:$cycle, detail:$detail,
          record_result: (if $rr == "" then null else $rr end)}')" \
      '.detected_defects += [$entry]' \
      "$loop_guard_file" > "${loop_guard_file}.tmp" \
    && mv "${loop_guard_file}.tmp" "$loop_guard_file"
  echo "${notice_prefix} [system-defect:auto] queued for postflight summary — defect_class=${class} attributed_path=${attributed_path} detecting_site=${site}" >&2
}

# skill_orchestrate_propagate_completion <task_number> <task_type> <task_dir> <dispatch_start_ts>
#   [precomputed_json] [notice_prefix]
# Single propagation path for every terminal "implemented" exit in both orchestrate engines. A
# new terminal exit path added to either SKILL.md MUST call this helper rather than re-inlining a
# completion-propagation block. When precomputed_json is non-empty, it is used directly (avoiding
# a second .return-meta.json read within the same cycle — e.g. the Stage 5 `implemented` tail,
# which already has $recover_json from the recovery branch above it). Otherwise this helper
# issues the one read via orchestrate-recover-outcome.sh itself. notice_prefix defaults to
# `[orchestrate]`; the hard engine's shim passes `[hard-orchestrate]`.
skill_orchestrate_propagate_completion() {
  local task_number="$1"
  local task_type="$2"
  local task_dir="$3"
  local dispatch_start_ts_arg="$4"
  local precomputed_json="${5:-}"
  local notice_prefix="${6:-[orchestrate]}"

  local completion_json
  if [ -n "$precomputed_json" ]; then
    completion_json="$precomputed_json"
  else
    completion_json=$(bash .claude/scripts/orchestrate-recover-outcome.sh "$task_dir" "$dispatch_start_ts_arg" 2>/dev/null)
  fi
  # NOTE: default via `[ -z ] && completion_json='{}'`, never `"${completion_json:-{}}"` — bash
  # parameter-expansion default-word matching stops at the FIRST unescaped `}`, so that inline
  # idiom silently appends a stray trailing `}` to any non-empty value, corrupting the JSON and
  # forcing every jq call below to fail closed to "" via `2>/dev/null`.
  [ -z "${completion_json:-}" ] && completion_json='{}'

  local completion_summary roadmap_items
  completion_summary=$(echo "$completion_json" | jq -r '.completion_summary // ""' 2>/dev/null) || completion_summary=""
  roadmap_items=$(echo "$completion_json" | jq -c '.roadmap_items // []' 2>/dev/null) || roadmap_items="[]"

  skill_propagate_completion_summary "$task_number" "$completion_summary" "$roadmap_items" "$task_type"

  if [ -z "$completion_summary" ]; then
    local completion_reason
    completion_reason=$(echo "$completion_json" | jq -r '.reason // "unknown"' 2>/dev/null) || completion_reason="unknown"
    echo "${notice_prefix} WARNING: task completed with empty completion_summary (reason=${completion_reason})" >&2
  fi
}

# skill_orchestrate_merge_return_meta <meta_file> <detected_defects_json> <status> <cycles_used>
#   <final_state>
# Shared Stage 8 postflight merge for both orchestrate engines' clean-exit and partial-exit
# `.return-meta.json` writes. Merges onto the existing file rather than overwriting wholesale: an
# earlier writer (the implementation agent) already populated modified_files/completion_data/etc.
# on this same path, and this call MUST NOT clobber fields it does not own.
#
# `detected_defects_json` is a resolved JSON array STRING, not a loop-guard path. This is a
# deliberate deviation from a naive "pass the loop-guard path and read inside" signature: the
# base-mode and hard-mode clean-exit call sites in skill-orchestrate/SKILL.md (formerly two
# separate engines, now `$hard_mode`-forked branches in this one file) read this value at
# DIFFERENT points relative to their own `rm -f "$loop_guard_file"` cleanup — base mode's
# clean-exit path reads it BEFORE that rm, in an earlier fence, and carries the ambient value
# forward (its own metadata-write section runs AFTER cleanup); hard mode's clean-exit path reads
# it in the SAME fence, BEFORE its own later `rm -f`. If this function read the loop guard
# itself, the base-mode clean-exit call would silently resolve to "[]" (the guard is already gone
# by the time that call happens), losing the real observation log. Requiring the caller to
# resolve the value at the same point the pre-dedup inline code did preserves this asymmetry
# exactly rather than papering over it.
skill_orchestrate_merge_return_meta() {
  local meta_file="$1" detected_defects_json="$2" status="$3" cycles_used="$4" final_state="$5"
  local task_summaries_dir
  task_summaries_dir="$(dirname "$meta_file")/summaries"
  mkdir -p "$task_summaries_dir"
  local existing_meta tmp_meta
  existing_meta=$(cat "$meta_file" 2>/dev/null || echo '{}')
  tmp_meta=$(mktemp)
  echo "$existing_meta" | jq \
    --arg status "$status" \
    --argjson cycles "$cycles_used" \
    --arg final_state "$final_state" \
    --argjson detected_defects "$detected_defects_json" \
    '. * {
      "status": $status,
      "metadata": {
        "cycles_used": $cycles,
        "final_state": $final_state,
        "detected_defects": $detected_defects
      }
    }' > "$tmp_meta" && mv "$tmp_meta" "$meta_file"
}
