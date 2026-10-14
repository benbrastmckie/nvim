#!/usr/bin/env bash
# Combined Stop/SubagentStop hook: log a lifecycle event into the unified event store.
#
# Registered under BOTH the Stop and SubagentStop matchers in root-files/settings.json.
# Branches on stdin's `agent_id` field (present only for a SubagentStop payload) to decide
# which correlation path to take -- the same agent_id-presence convention already used by
# memory-nudge.sh and claude-stop-notify.sh to distinguish subagent stops from top-level ones.
#
# Claude Code hook stdin carries no *agent-system workflow* session_id or task number
# directly -- it does carry Claude Code's OWN native session UUID as top-level .session_id,
# captured below as CC_SESSION_ID and threaded through unchanged as the events.jsonl
# cc_session_id field (the exact join key to that session's OTel telemetry stream; see
# context/formats/events-format.md's "Claude Code OTel Correlation" section). The workflow
# session_id and task number below are a DIFFERENT id space and still have to be
# reconstructed via existing correlation mechanisms rather than inventing a new one:
#
#   SubagentStop path: locates the `.postflight-pending` marker file the same way
#     subagent-postflight.sh does -- enumerating every marker under
#     `find specs -maxdepth 3 -name ".postflight-pending"` (plus the `specs/.postflight-pending`
#     global fallback) and selecting only the one whose `cc_session_id` field matches this
#     hook's own CC_SESSION_ID (captured below from stdin's `.session_id`). This is a deliberate
#     mirror of subagent-postflight.sh's `find_marker()` -- see that hook's header comment for
#     the full correlation rationale and the fail-safe (no match means no marker selected, never
#     an arbitrary `head -1` pick). The marker itself carries `session_id`/`skill`/`operation`
#     (see skill_create_postflight_marker in scripts/skill-base.sh); the task number is
#     recovered from the marker's parent task directory name.
#
#   Stop path: reads .claude/tmp/workflow-active-<CC_SESSION_ID> (the PER-SESSION marker form;
#     see update-task-status.sh's header comment for why it is keyed by Claude Code's native
#     session UUID rather than the agent-system session_id -- CC_SESSION_ID is already captured
#     below for the cc_session_id event field, so reading THIS session's own marker requires no
#     extra plumbing) for a task number, formatted as `"<task_number> <timestamp>"`; if that
#     specific marker is absent, falls back to a task-number regex over stdin's
#     last_assistant_message (mirroring memory-nudge.sh's `task [0-9]+` / `Task #[0-9]+`
#     extraction) -- never to a different session's marker file. The agent-system session_id
#     itself is never present in either source, so once a task number is recovered it is used to
#     look up that task's current session_id from specs/state.json's active_projects entry
#     (populated by update-task-status.sh on every preflight). If no session_id can be resolved
#     this way, the hook exits {} cleanly rather than emitting a sessionless event.
#
# Accepted trade-off: a SubagentStop may fire more than once per loop-guard continuation
# (see subagent-postflight.sh's MAX_CONTINUATIONS retry loop). This hook does not deduplicate
# repeated fires -- downstream consumers can dedupe by session_id+checkpoint if needed.
#
# Note: this hook deliberately does NOT re-read .return-meta.json -- by Stop/SubagentStop
# time it may already be cleaned up by postflight. Metadata-derived events are the
# PostToolUse hook's job (events-log-artifact.sh), which fires at Write time.
#
# Never blocks: always echoes {} (never emits a "decision" key). The events-append.sh call
# is wrapped in the observable-but-non-fatal helper below so a failure here can never surface
# to the caller or stall the session, while still producing a distinguishable, durable signal
# instead of the prior bare `|| true` silent failure.
#
# ORDERING INVARIANT this hook upholds: a UserPromptSubmit or PreToolUse hook (e.g.
# hooks/please-grant.sh's mint, or guard-git-push.sh's consume) must never append directly to
# the tracked specs/events.jsonl, because it runs BEFORE the command body it fires for -- doing
# so would dirty a tracked file ahead of that command's own precondition read (see
# scripts/lib/push-grant-lib.sh's header "Audit:" paragraph for the full hazard). Those two call
# sites instead buffer via pg_audit_buffer into a self-ignored pending-audit file. This Stop/
# SubagentStop hook is the one pipeline point guaranteed to run after the WHOLE current turn's
# command body and strictly before the next turn's UserPromptSubmit, so it is where that buffer
# gets drained via pg_audit_flush (below, before the AGENT_ID branch) -- the one flush call
# covers both the Stop and SubagentStop paths below it.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVENTS_APPEND="$SCRIPT_DIR/../scripts/events-append.sh"
PUSH_GRANT_LIB="$SCRIPT_DIR/../scripts/lib/push-grant-lib.sh"

exit_success() {
  echo '{}'
  exit 0
}

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
        echo "[events-log-lifecycle] WARNING: events-append.sh helper missing or not executable at ${helper_path} (non-blocking)" >&2
      else
        echo "[events-log-lifecycle] WARNING: events-append.sh helper present but failed (exit ${exit_code}) at ${helper_path} (non-blocking)" >&2
      fi
      _EVENTS_APPEND_OBSERVABLE_WARNED=1
    fi
    mkdir -p "$SCRIPT_DIR/../tmp" 2>/dev/null
    printf '{"kind":"%s","helper_path":"%s","exit_code":"%s","ts":"%s"}\n' \
      "$kind" "$helper_path" "$exit_code" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      >> "$SCRIPT_DIR/../tmp/events-append-observable.log" 2>/dev/null
  fi
  return 0
}

command -v jq &>/dev/null || exit_success
# NOTE: deliberately no early `[ -x "$EVENTS_APPEND" ] || exit_success` bypass here -- that
# used to short-circuit BEFORE the call site could ever signal a missing helper, which is
# exactly the silent-failure defect this wrapper replaces. Missing/failing helper detection now
# happens inside _events_append_observable at each call site below.

# --- Read stdin JSON (hook context) ---
STDIN_JSON=""
if read -t 0.1 -r line; then
  STDIN_JSON="$line"
  while read -t 0.1 -r more; do
    STDIN_JSON="${STDIN_JSON}${more}"
  done
fi
[ -z "$STDIN_JSON" ] && STDIN_JSON='{}' || true

AGENT_ID=$(echo "$STDIN_JSON" | jq -r '.agent_id // empty' 2>/dev/null || echo "")
# Claude Code hook stdin carries a top-level .cwd field alongside .agent_id -- capture it once
# here and thread it to both the SubagentStop and Stop --cwd args below (scope 5: nullable cwd).
CWD=$(echo "$STDIN_JSON" | jq -r '.cwd // empty' 2>/dev/null || echo "")
# Claude Code's own native session UUID (top-level .session_id on every hook stdin) -- the
# exact join key to OTel's session.id. Distinct from the agent-system sess_* id resolved
# below; threaded to both the SubagentStop and Stop --cc-session-id args, same guard idiom
# already used for CWD.
CC_SESSION_ID=$(echo "$STDIN_JSON" | jq -r '.session_id // empty' 2>/dev/null || echo "")

# Drain any buffered push-grant audit records (see this file's header "ORDERING INVARIANT"
# paragraph). Guarded source so a missing/unreadable push-grant-lib.sh can never change this
# hook's output contract -- the library sets no shell options by contract, so sourcing it
# cannot trip this file's own `set -euo pipefail`. Unconditional and before the AGENT_ID
# branch so the single call covers both the Stop and SubagentStop paths below it.
# shellcheck source=../scripts/lib/push-grant-lib.sh
source "$PUSH_GRANT_LIB" 2>/dev/null || true
if command -v pg_audit_flush >/dev/null 2>&1; then
  pg_audit_flush 2>/dev/null || true
fi

if [ -n "$AGENT_ID" ]; then
  # ─────────────────────────────────────────────────────────────────────────
  # SubagentStop path: marker-file correlation (mirrors subagent-postflight.sh's find_marker())
  # ─────────────────────────────────────────────────────────────────────────

  # Malformed marker: cc_session_id is unreadable, so it cannot be correlated to CC_SESSION_ID.
  # The enumeration below reaches it, does not select it, and calls this to leave a durable
  # `deviation` event -- exactly the diagnostic the original single-marker code emitted, just
  # now scoped per-marker so one malformed marker does not stop the enumeration from reaching a
  # correlated marker afterward. Recovers session_id from the marker's parent task directory
  # name via specs/state.json's active_projects entry (the marker itself is unparseable),
  # mirroring the Stop path's identical lookup further down this file. `return 0` (not
  # exit_success) on an unresolvable session_id -- skipping this marker's event must never end
  # the whole hook while other markers remain to enumerate.
  emit_malformed_marker_event() {
    local marker="$1"
    local parse_err task_dir task session_id detail_json
    local -a event_args
    # `|| true` guards against `set -euo pipefail` (this file's shell options, unlike
    # subagent-postflight.sh's) tripping on jq's non-zero parse-error exit inside the pipeline.
    parse_err=$(jq empty "$marker" 2>&1 >/dev/null | head -1) || true
    task_dir=$(dirname "$marker")
    task=""
    if [[ "$task_dir" =~ specs/([0-9]+)_ ]]; then
      task="${BASH_REMATCH[1]}"
    fi
    [ -z "$task" ] && return 0

    [ -f specs/state.json ] || return 0
    jq empty specs/state.json 2>/dev/null || return 0

    session_id=$(jq -r --argjson num "$task" \
      '.active_projects[]? | select(.project_number == $num) | .session_id // empty' \
      specs/state.json 2>/dev/null)
    [ -z "$session_id" ] && return 0

    detail_json=$(jq -n --arg path "$marker" --arg err "$parse_err" \
      '{marker_path: $path, parse_error: $err}')
    event_args=(--event-type malformed_postflight_marker --category deviation \
      --checkpoint postflight --session "$session_id" --task "$task" \
      --message "Postflight marker at ${marker} could not be parsed as JSON" \
      --detail-json "$detail_json")
    [ -n "$CWD" ] && event_args+=(--cwd "$CWD") || true
    [ -n "$CC_SESSION_ID" ] && event_args+=(--cc-session-id "$CC_SESSION_ID") || true

    _events_append_observable "$EVENTS_APPEND" "${event_args[@]}"
    return 0
  }

  # Enumerate every `.postflight-pending` marker and select only the one whose `cc_session_id`
  # matches CC_SESSION_ID. Fail-safe: on no correlated match, MARKER_FILE stays empty and the
  # branch exits cleanly below -- never an event attributed to a marker this session does not
  # own.
  MARKER_FILE=""
  marker=""
  marker_cc_session_id=""
  while IFS= read -r marker; do
    [ -z "$marker" ] && continue
    if ! jq empty "$marker" 2>/dev/null; then
      emit_malformed_marker_event "$marker"
      continue
    fi
    marker_cc_session_id=$(jq -r '.cc_session_id // empty' "$marker" 2>/dev/null)
    if [ -n "$CC_SESSION_ID" ] && [ -n "$marker_cc_session_id" ] && [ "$marker_cc_session_id" = "$CC_SESSION_ID" ]; then
      MARKER_FILE="$marker"
      break
    fi
  done < <(find specs -maxdepth 3 -name ".postflight-pending" -type f 2>/dev/null)

  # Global-fallback marker (backward compatibility during migration) is subject to the same
  # correlation check.
  if [ -z "$MARKER_FILE" ] && [ -f "specs/.postflight-pending" ]; then
    if ! jq empty "specs/.postflight-pending" 2>/dev/null; then
      emit_malformed_marker_event "specs/.postflight-pending"
    else
      marker_cc_session_id=$(jq -r '.cc_session_id // empty' "specs/.postflight-pending" 2>/dev/null)
      if [ -n "$CC_SESSION_ID" ] && [ -n "$marker_cc_session_id" ] && [ "$marker_cc_session_id" = "$CC_SESSION_ID" ]; then
        MARKER_FILE="specs/.postflight-pending"
      fi
    fi
  fi

  [ -z "$MARKER_FILE" ] && exit_success || true

  session_id=$(jq -r '.session_id // empty' "$MARKER_FILE" 2>/dev/null)
  [ -z "$session_id" ] && exit_success || true

  skill=$(jq -r '.skill // empty' "$MARKER_FILE" 2>/dev/null)
  operation=$(jq -r '.operation // empty' "$MARKER_FILE" 2>/dev/null)

  task_dir=$(dirname "$MARKER_FILE")
  task=""
  if [[ "$task_dir" =~ specs/([0-9]+)_ ]]; then
    task="${BASH_REMATCH[1]}"
  fi

  event_args=(--event-type subagent_stop --category milestone --checkpoint postflight \
    --session "$session_id" \
    --message "Subagent stop for ${skill:-unknown} (${operation:-unknown})")
  [ -n "$task" ] && event_args+=(--task "$task") || true
  [ -n "$CWD" ] && event_args+=(--cwd "$CWD") || true
  [ -n "$CC_SESSION_ID" ] && event_args+=(--cc-session-id "$CC_SESSION_ID") || true

  _events_append_observable "$EVENTS_APPEND" "${event_args[@]}"
  exit_success
fi

# ─────────────────────────────────────────────────────────────────────────
# Stop path: workflow-active marker, else last_assistant_message pattern fallback
# ─────────────────────────────────────────────────────────────────────────
task=""
if [ -n "$CC_SESSION_ID" ]; then
  WORKFLOW_ACTIVE="$SCRIPT_DIR/../tmp/workflow-active-${CC_SESSION_ID}"
  if [ -f "$WORKFLOW_ACTIVE" ]; then
    task=$(awk '{print $1}' "$WORKFLOW_ACTIVE" 2>/dev/null)
  fi
fi

if [ -z "$task" ]; then
  MESSAGE=$(echo "$STDIN_JSON" | jq -r '.last_assistant_message // empty' 2>/dev/null || echo "")
  CHECK="${MESSAGE:0:2000}"
  if [[ "$CHECK" =~ [Tt]ask\ ([0-9]+) ]]; then
    task="${BASH_REMATCH[1]}"
  elif [[ "$CHECK" =~ Task\ \#([0-9]+) ]]; then
    task="${BASH_REMATCH[1]}"
  fi
fi

# No task recovered -- there is no reliable session_id source without it; exit cleanly.
[ -z "$task" ] && exit_success || true

# Neither correlation source carries session_id directly; recover it from the task's
# current state.json entry (populated by update-task-status.sh on every preflight).
[ -f specs/state.json ] || exit_success
jq empty specs/state.json 2>/dev/null || exit_success

session_id=$(jq -r --argjson num "$task" \
  '.active_projects[]? | select(.project_number == $num) | .session_id // empty' \
  specs/state.json 2>/dev/null)
[ -z "$session_id" ] && exit_success || true

event_args=(--event-type session_stop --category milestone --session "$session_id" \
  --task "$task" --message "Session stop observed for task ${task}")
[ -n "$CWD" ] && event_args+=(--cwd "$CWD") || true
[ -n "$CC_SESSION_ID" ] && event_args+=(--cc-session-id "$CC_SESSION_ID") || true

_events_append_observable "$EVENTS_APPEND" "${event_args[@]}"
exit_success
