#!/usr/bin/env bash
# command-gate-in.sh — CHECKPOINT 1: Session generation, task lookup, terminal status guard,
# and a non-blocking deploy-freshness warning (see check-deploy-freshness.sh) printed just
# before returning, once the deployed tree carries it.
#
# Usage: source .claude/scripts/command-gate-in.sh "$task_number" "$operation"
#
# IMPORTANT: This script MUST be sourced (not called as a subprocess) because
# it exports variables into the calling shell. Source it within a single Bash
# tool invocation so the exported variables are visible to subsequent commands
# in that same invocation.
#
# Arguments:
#   $1  task_number — The numeric task ID to look up
#   $2  operation   — "research" | "plan" | "implement" | "revise" | "orchestrate"
#
# Note: operation == "revise" is exempt from the terminal-status guard below (skill-reviser's
# documented contract is "works regardless of task status").
#
# Exported Variables:
#   SESSION_ID    — sess_{timestamp}_{random}
#   TASK_TYPE     — Task type from state.json (e.g., "general", "meta", "neovim")
#   TASK_STATUS   — Current task status from state.json
#   PROJECT_NAME  — Project slug from state.json
#   DESCRIPTION   — Task description from state.json
#   PADDED_NUM    — Zero-padded task number (e.g., "007" for task {N})
#
# Exit Codes:
#   0   — Success; all exports set
#   1   — Task not found or terminal status
#
# Downstream dependencies:
#   skill-base.sh will source this script.

# ─────────────────────────────────────────────────────────────────────────────
# SHARED LIBRARY: scripts/lib/common.sh (session-ID generation, repo-root resolution helpers,
# timestamps, logging, test helpers). Sets no shell options of its own -- see its own header
# contract. This file itself deliberately sets no shell options either (it is sourced into a
# caller's shell -- see the module docstring above), so sourcing common.sh must not change that.
# Two candidate paths: the deployed tree (this file's normal runtime context, tried first) and a
# source-store-relative fallback so this file can also be sourced directly from
# agent-system/extensions/core/scripts/ (e.g. by a test suite exercising it in isolation).
_GATE_IN_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [ -f "${_GATE_IN_REPO_ROOT}/.claude/scripts/lib/common.sh" ]; then
  source "${_GATE_IN_REPO_ROOT}/.claude/scripts/lib/common.sh"
elif [ -f "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh" ]; then
  source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
fi
unset _GATE_IN_REPO_ROOT

gate_in() {
  local task_number="$1"
  local operation="$2"

  # Generate session ID
  SESSION_ID="$(common_session_id)"

  # Pad task number
  PADDED_NUM=$(printf "%03d" "$task_number")

  # Look up task in state.json
  local task_data
  task_data=$(jq -c --argjson num "$task_number" \
    '.active_projects[] | select(.project_number == $num)' \
    specs/state.json)

  if [ -z "$task_data" ]; then
    echo "ERROR: Task $task_number not found in state.json" >&2
    return 1
  fi

  TASK_TYPE=$(echo "$task_data" | jq -r '.task_type // "general"')
  TASK_STATUS=$(echo "$task_data" | jq -r '.status')
  PROJECT_NAME=$(echo "$task_data" | jq -r '.project_name')
  DESCRIPTION=$(echo "$task_data" | jq -r '.description // ""')

  # Guard: terminal status check (skipped for "revise" — skill-reviser's documented contract
  # is "no status-based ABORT rules; the skill works regardless of task status")
  if [ "$operation" != "revise" ]; then
    case "$TASK_STATUS" in
      completed|abandoned|expanded)
        echo "ABORT: Task $task_number is in terminal status: $TASK_STATUS" >&2
        echo "  Use --force to override (implement only), or check task status with /task --sync" >&2
        return 1
        ;;
      hold)
        # Non-terminal, so it falls outside the case arm above, yet single-command dispatch has
        # no forcing-flag plumbing of its own (that override exists only in
        # orchestrate-cycle-plan.sh's task_has_forced_phase()/effective_group machinery, reached
        # via `/orchestrate N --research|--plan|--implement`, which never calls this gate) -- a
        # held task simply ABORTs here until lifted. Preserves the "revise" exemption above
        # (skill-reviser's contract is "no status-based ABORT rules") and sits ahead of the
        # task-lock acquire below so a held task fails fast without ever touching the lock.
        local hold_reason
        hold_reason=$(echo "$task_data" | jq -r '.hold_reason // "no reason recorded"')
        echo "ABORT: Task $task_number is held: $hold_reason" >&2
        echo "  Lift the hold with: bash .claude/scripts/update-task-status.sh preflight $task_number unhold <session_id>" >&2
        echo "  Or override for exactly one dispatch with: /orchestrate $task_number --research|--plan|--implement" >&2
        return 1
        ;;
    esac
  fi

  # Task lock: acquire AFTER the terminal-status guard so terminal-status tasks fail fast
  # without ever touching the lock. See .claude/context/patterns/task-lock.md for the full
  # acquire/heartbeat/release/check contract, and its "Four-Tier Conflict Response" section for
  # where this call sits in the ladder. Same-session re-entry never self-blocks — this is
  # unchanged by the acquire-retry wrapper below, since every retried attempt is a full fresh
  # cmd_acquire entry and same-session re-entry returns 0 on the FIRST attempt every time (see
  # task-lock.sh's cmd_acquire_retry contract comment). A fresh lock held by a DIFFERENT session
  # is now retried within a bounded budget (Tier 2) before the command aborts (Tier 3) — a
  # refusal here means "still locked after the bounded retry budget," not "locked on first look."
  if ! bash .claude/scripts/task-lock.sh acquire-retry "$task_number" "$operation" "$SESSION_ID" "/$operation $task_number"; then
    return 1
  fi

  # In-flight session registry: register this single-task session. Best-effort and
  # non-blocking — a registration failure must never turn a successful lock acquire into a
  # refusal; this task changes no admission decision. See
  # .claude/context/patterns/task-lock.md's Session-Registry CLI section.
  bash .claude/scripts/task-lock.sh session-register "$SESSION_ID" "/$operation $task_number" "$task_number" 2>/dev/null || true

  # Display operation header
  local op_label
  op_label=$(echo "$operation" | tr '[:lower:]' '[:upper:]')
  echo "[$op_label] Task $task_number: $PROJECT_NAME"

  # Non-blocking deploy-freshness check: guarded on the deployed checker's own existence so a
  # tree too stale to carry it yet is a silent no-op (the gap closes on that repo's next
  # resync). Invoked with `bash` (never sourced) and its exit status discarded via `|| true` so
  # a stray failure here can never propagate into this sourced script's own return value or
  # abort the calling shell -- see check-deploy-freshness.sh's header for its always-exit-0
  # contract. Printed last, just before the exported variables become available to the caller.
  if [ -f .claude/scripts/check-deploy-freshness.sh ]; then
    bash .claude/scripts/check-deploy-freshness.sh 2>&1 || true
  fi

  export SESSION_ID TASK_TYPE TASK_STATUS PROJECT_NAME DESCRIPTION PADDED_NUM
}

gate_in "$1" "$2"
