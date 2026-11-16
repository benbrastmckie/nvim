#!/usr/bin/env bash
# orchestrate-conclusion-backstop.sh - Stop hook: refuses to let an orchestrate session end its
# turn while /orchestrate's Move 5 conclusion stage has not yet run, mechanizing the backstop
# half of the Move 4/5 reorder (context/contracts/conclusion-stage.md).
#
# Purpose: `orchestrate-conclusion-roadmap.sh` writes a *pending* marker at Move 4 (the
# conclusion-stage pending marker, scripts/lib/runtime-file-patterns.sh's
# runtime_conclusion_pending_marker_path) and Move 5 Step 6 deletes it as its own final action
# once the rest of the conclusion stage (channels (a)/(b)/(c), Step 7's next-batch suggestion,
# and Step 6's report) has run. A session whose marker is still live when it tries to stop has
# not finished Move 5 -- this hook blocks that stop.
#
# Structural model: hooks/subagent-postflight.sh (the proven `.postflight-pending` shape),
# adapted for this marker's own field schema and glob. Marker selection is correlated to the
# stopping Claude Code session via each marker's `cc_session_id` field against hook stdin's
# top-level `.session_id` -- identical correlation discipline, identical fail-safe: on no
# correlated match, act on NO marker, never an arbitrary pick.
#
# DELIBERATE DIVERGENCE from subagent-postflight.sh's `stop_hook_active` check: that precedent
# reads a `stop_hook_active` field FROM THE MARKER itself, which its own writer
# (skill_create_postflight_marker, scripts/skill-base.sh) always sets to the literal `false` --
# a vestigial, currently-inert field kept for historical schema parity, not a live signal. This
# hook instead reads `stop_hook_active` from HOOK STDIN directly, Claude Code's own native,
# harness-maintained flag that is genuinely `true` when a Stop event is itself the result of a
# previous Stop hook's block decision -- the textbook mechanism "hooks cannot call hooks" exists
# to use. Functionally equivalent intent (the escape this hook's own loop-guard pair needs),
# correctly wired to a live signal rather than a dead one.
#
# MAX_CONTINUATIONS cap: unlike subagent-postflight.sh's separate sibling `.postflight-loop-guard`
# file, this hook's own counter (`continuation_count`) lives INSIDE the pending marker itself --
# the schema orchestrate-conclusion-roadmap.sh's header already commits to. Incremented on every
# block; once it reaches MAX_CONTINUATIONS, the marker is deleted and the stop is allowed, logged
# as a cap-reached delete.
#
# Returns (stdout, exit 0 always on the decision path -- see root-files/settings.json's
# `2>/dev/null || echo '{}'` wrapper note below):
#   {"decision": "block", "reason": "..."} - Move 5 has not finished; prevents the stop
#   {}                                     - inert: no correlated marker, stop_hook_active,
#                                             cap reached, or a malformed/unreadable marker
#
# Registered in root-files/settings.json's `Stop` array as
# `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/orchestrate-conclusion-backstop.sh 2>/dev/null || echo '{}'`.
# The block decision is written to stdout with exit 0 (never a non-zero exit on the decision
# path), so that `|| echo '{}'` fallback arm can never swallow a real block decision -- it only
# ever fires on a genuine crash of this script itself.

MAX_CONTINUATIONS=3

log_debug() {
  local LOG_DIR=".agent-logs"
  local LOG_FILE="$LOG_DIR/orchestrate-conclusion-backstop.log"
  mkdir -p "$LOG_DIR" 2>/dev/null
  echo "[$(date -Iseconds)] $1" >> "$LOG_FILE" 2>/dev/null
}

# Read hook stdin (bounded, never blocks on an absent/terminal stdin).
STDIN_JSON=""
if read -t 0.1 -r line; then
  STDIN_JSON="$line"
  while read -t 0.1 -r more; do
    STDIN_JSON="${STDIN_JSON}${more}"
  done
fi
[ -z "$STDIN_JSON" ] && STDIN_JSON='{}'

CC_SESSION_ID=$(echo "$STDIN_JSON" | jq -r '.session_id // empty' 2>/dev/null || echo "")

# Live, harness-maintained escape: a Stop event that is itself the product of a previous Stop
# hook's own block decision. Inert immediately -- never select or mutate any marker on this path.
if [ "$(echo "$STDIN_JSON" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ]; then
  log_debug "STOP-HOOK-ACTIVE ESCAPE: cc_session_id=$CC_SESSION_ID (no marker inspected)"
  echo '{}'
  exit 0
fi

MARKER_FILE=""

find_marker() {
  local enumerated=0
  local marker marker_cc_session_id

  while IFS= read -r marker; do
    [ -z "$marker" ] && continue
    enumerated=$((enumerated + 1))
    jq empty "$marker" 2>/dev/null || continue
    marker_cc_session_id=$(jq -r '.cc_session_id // empty' "$marker" 2>/dev/null)
    if [ -n "$CC_SESSION_ID" ] && [ -n "$marker_cc_session_id" ] && [ "$marker_cc_session_id" = "$CC_SESSION_ID" ]; then
      MARKER_FILE="$marker"
      return 0
    fi
  done < <(find specs/.orchestration -maxdepth 1 -name ".conclusion-pending-*.json" -type f 2>/dev/null)

  if [ -z "$MARKER_FILE" ]; then
    log_debug "No correlated marker: enumerated $enumerated marker(s), stopping CC_SESSION_ID='$CC_SESSION_ID'"
  fi
}

main() {
  find_marker

  if [ -z "$MARKER_FILE" ] || [ ! -f "$MARKER_FILE" ]; then
    log_debug "No conclusion-pending marker, allowing stop"
    echo '{}'
    exit 0
  fi

  log_debug "Conclusion-pending marker found at: $MARKER_FILE"

  if ! jq empty "$MARKER_FILE" 2>/dev/null; then
    log_debug "Malformed marker, allowing stop: $MARKER_FILE"
    echo '{}'
    exit 0
  fi

  local count session_id
  count=$(jq -r '.continuation_count // 0' "$MARKER_FILE" 2>/dev/null)
  case "$count" in ''|*[!0-9]*) count=0 ;; esac
  session_id=$(jq -r '.session_id // empty' "$MARKER_FILE" 2>/dev/null)

  if [ "$count" -ge "$MAX_CONTINUATIONS" ]; then
    log_debug "CAP-REACHED DELETE: marker=$MARKER_FILE count=$count >= $MAX_CONTINUATIONS session_id=$session_id cc_session_id=$CC_SESSION_ID"
    rm -f "$MARKER_FILE"
    echo '{}'
    exit 0
  fi

  # Increment the marker's own continuation_count (in place) before returning the block decision.
  local tmp_marker="${MARKER_FILE}.tmp"
  if jq --argjson c "$((count + 1))" '.continuation_count = $c' "$MARKER_FILE" > "$tmp_marker" 2>/dev/null; then
    mv "$tmp_marker" "$MARKER_FILE"
  else
    rm -f "$tmp_marker" 2>/dev/null
  fi
  log_debug "Loop guard incremented to $((count + 1)) for marker=$MARKER_FILE"

  local reason
  reason="/orchestrate's Move 5 conclusion stage has not finished for session ${session_id} (context/contracts/conclusion-stage.md). Remaining: channel (a)/(b)/(c) classification and recording, Step 7's next-batch suggestion, and Step 6's combined report -- the pending marker at ${MARKER_FILE} is deleted only once Step 6's own final action runs. Continue executing the Executable Stage Body instead of ending this turn."
  log_debug "Blocking stop: $reason"
  echo "{\"decision\": \"block\", \"reason\": $(jq -n --arg r "$reason" '$r')}"
  exit 0
}

main
