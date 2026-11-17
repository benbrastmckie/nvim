#!/usr/bin/env bash
# PostToolUse hook: log unified-event-store events for Write/Edit calls that touch a
# task's .return-meta.json.
#
# Integration: appended to the existing PostToolUse "Write|Edit" matcher's hooks array in
# root-files/settings.json, alongside validate-plan-write.sh's entry.
#
# Cheap early-exit: file_path is checked against one narrow path pattern BEFORE any
# jq/lock work is paid for, so this hook is near-zero-cost on the vast majority of
# Write/Edit calls it fires for (mirrors validate-plan-write.sh / validate-meta-write.sh).
#
# Never blocks: always echoes {} (never emits a "decision" key). Every events-append.sh
# call goes through the observable-but-non-fatal helper below so a failure here can never
# surface to the caller or stall the session, while still producing a distinguishable,
# durable signal instead of the prior bare `|| true` silent failure.
#
# See context/formats/events-format.md for the event field contract.

set -euo pipefail

# Observable-but-non-fatal wrapper around events-append.sh -- see the identical helper in
# scripts/skill-base.sh and scripts/orchestrator-postflight.sh for the full contract comment.
# ALWAYS returns 0; distinguishes "missing" vs "failed (exit N)" in a stderr WARNING plus a
# durable sentinel marker under .claude/tmp/.
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
        echo "[events-log-artifact] WARNING: events-append.sh helper missing or not executable at ${helper_path} (non-blocking)" >&2
      else
        echo "[events-log-artifact] WARNING: events-append.sh helper present but failed (exit ${exit_code}) at ${helper_path} (non-blocking)" >&2
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

# --- Parse file_path from stdin (PostToolUse hook input), mirroring the stdin-then-env
#     fallback pattern used by validate-plan-write.sh / validate-meta-write.sh ---
# Also capture the top-level .cwd field from the same parsed stdin JSON when available (scope 5:
# nullable cwd) -- the CLAUDE_TOOL_INPUT env fallback carries no .cwd, so CWD stays empty
# (written as null by events-append.sh) in that edge case. Same treatment for .session_id
# (Claude Code's own native session UUID, captured as CC_SESSION_ID -- the exact join key to
# OTel's session.id); the CLAUDE_TOOL_INPUT fallback carries no .session_id either, so
# CC_SESSION_ID stays empty (written as null) in that same edge case.
CWD=""
CC_SESSION_ID=""
if [ -t 0 ]; then
  FILE=$(echo "${CLAUDE_TOOL_INPUT:-}" | jq -r '.file_path // empty' 2>/dev/null)
else
  INPUT=$(cat)
  FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  if [ -z "$FILE" ]; then
    FILE=$(echo "${CLAUDE_TOOL_INPUT:-}" | jq -r '.file_path // empty' 2>/dev/null)
  fi
  CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
  CC_SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
fi

# Early exit for empty path (~1ms) -- no jq/lock work paid for below this point unless matched
if [ -z "$FILE" ]; then
  echo '{}'
  exit 0
fi

# Determine match type from the one narrow path pattern this hook cares about. Any other
# path exits immediately without touching jq/flock -- the hot-path cost this hook must
# stay cheap on.
match_type=""
case "$FILE" in
  specs/*/.return-meta.json|*/specs/*/.return-meta.json)
    match_type="return_meta"
    ;;
  *)
    echo '{}'
    exit 0
    ;;
esac

# Guard: file must exist and parse as valid JSON before any field extraction (mirrors
# skill_read_metadata's jq empty guard -- tolerates a mid-write or since-deleted file).
if [ ! -f "$FILE" ] || ! jq empty "$FILE" 2>/dev/null; then
  echo '{}'
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVENTS_APPEND="${SCRIPT_DIR}/scripts/events-append.sh"

# NOTE: deliberately no early `[ ! -x "$EVENTS_APPEND" ] && exit` bypass here -- that used to
# short-circuit BEFORE the call site could ever signal a missing helper, which is exactly the
# silent-failure defect this wrapper replaces. Missing/failing helper detection now happens
# inside _events_append_observable at each call site below.

if [ "$match_type" = "return_meta" ]; then
  session_id=$(jq -r '.metadata.session_id // empty' "$FILE" 2>/dev/null)
  status=$(jq -r '.status // empty' "$FILE" 2>/dev/null)

  # session_id is required by events-append.sh -- skip silently if absent (e.g. a
  # hand-authored or mid-write metadata file that hasn't reached Stage 0's full write yet)
  if [ -n "$session_id" ]; then
    # Task number is embedded in the directory name, not the file content
    task=""
    if [[ "$FILE" =~ specs/([0-9]+)_[^/]+/\.return-meta\.json$ ]]; then
      task="${BASH_REMATCH[1]}"
    fi

    case "$status" in
      failed|blocked) category="blocker" ;;
      partial) category="deviation" ;;
      in_progress) category="milestone" ;;
      *) category="success" ;;
    esac

    event_args=(--event-type artifact_write --category "$category" --session "$session_id" \
      --message "Artifact metadata written with status '${status:-unknown}'")
    [ -n "$task" ] && event_args+=(--task "$task") || true
    [ -n "$CWD" ] && event_args+=(--cwd "$CWD") || true
    [ -n "$CC_SESSION_ID" ] && event_args+=(--cc-session-id "$CC_SESSION_ID") || true

    _events_append_observable "$EVENTS_APPEND" "${event_args[@]}"
  fi
fi

echo '{}'
exit 0
