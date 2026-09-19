#!/usr/bin/env bash
# detect-noop-bash.sh
# PostToolUse hook (matcher "Bash"): classifies trivial no-op Bash commands (`:`, `true`, bare
# `date`/`date -u`, a pure-literal `echo`, `sleep <N>[smh]?`), tracks the number of CONSECUTIVE
# trivial calls per Claude Code session, and after a threshold of them in a row injects an
# advisory `additionalContext` message pointing at context/patterns/external-process-wait.md and
# its bounded-wait idiom.
#
# Motivating incident: a subagent waiting on a ~25-minute GitHub Actions run had its foreground
# `sleep` blocked, its `gh run watch` backgrounded by the 600s Bash timeout, and its Monitor loop
# waking it on every poll -- so it filled the gaps with roughly 130 no-op Bash calls (`:`, `true`,
# `date -u`, `echo waiting`) until it had to be stopped manually. This hook cannot prevent that
# pattern (it is advisory only, per contract below) but it surfaces the corrective idiom the
# moment a filler streak starts, rather than after 130 calls.
#
# Contract (non-negotiable):
#   - ADVISORY ONLY. This hook NEVER blocks a Bash call. It always exits 0.
#   - FAILS OPEN. Any internal error (missing jq, malformed stdin, unwritable state dir, a
#     non-Bash tool call, a missing/unsafe session id) results in `{}` on stdout and exit 0 --
#     never a crash, never a nonzero exit.
#   - RESETS on any non-trivial command: the per-session counter is deleted, not merely zeroed,
#     so the very next trivial call restarts the streak at 1.
#
# State: a per-session counter file under a session-scoped directory outside specs/**, following
# the `.claude/tmp/<purpose>-<CC_SESSION_ID>` precedent set by claude-stop-notify.sh's
# workflow-active marker. Defaults to `$SCRIPT_DIR/../tmp` (i.e. `.claude/tmp` in the deploy
# tree); overridable via NOOP_BASH_STATE_DIR so tests never write into the source store's own
# `agent-system/extensions/core/tmp/` (which exists on disk and is NOT gitignored).
#
# Threshold: NOOP_BASH_THRESHOLD (positive integer; any other value, including unset, empty, 0,
# negative, or non-numeric, falls back to the default of 3). The message fires when the streak
# first reaches the threshold, then again every `threshold` further consecutive trivial calls
# (count 3, 6, 9, ... for the default) -- a single message at the threshold can be lost in a long
# filler streak, while firing on every call from the threshold onward would add noise to every
# filler turn.
#
# Classification is deliberately conservative in one direction only: a FALSE NEGATIVE (calling a
# genuinely harmless command "not trivial") is harmless -- it just means the counter resets one
# call early. A FALSE POSITIVE (calling a command with real side effects "trivial") is the defect
# to avoid, since it would suppress the very corrective nudge this hook exists to give. Every
# ambiguous case below is resolved toward "not trivial".

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# is_trivial_segment <segment>
# A single semicolon/pipe/ampersand-delimited segment of a (comment-stripped) command. Returns
# 0 (trivial) for an exact `:`, `true`, `date`, or `date -u`; a `sleep <N>` optionally suffixed
# with s/m/h; a bare `echo`/`echo -n`; or `echo`/`echo -n` followed by arguments already known
# (by the caller's whole-command scan) to contain none of $, `, >, <, ( -- the only remaining
# check here is for glob characters (*, ?, [), which are only meaningful in an echo argument.
# Returns 1 (non-trivial) for anything else, including an unrecognized command/segment.
is_trivial_segment() {
  local seg trimmed sleep_re echo_bare_re args
  seg="$1"
  trimmed=$(printf '%s' "$seg" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//') || trimmed="$seg"

  # Empty segments arise from collapsed separators (e.g. "&&" -> one boundary); they carry no
  # command at all and are vacuously trivial so they never break an otherwise-all-trivial line.
  if [ -z "$trimmed" ]; then
    return 0
  fi

  case "$trimmed" in
    ":"|"true"|"date"|"date -u"|"echo"|"echo -n")
      return 0
      ;;
  esac

  sleep_re='^sleep[[:space:]]+[0-9]+[smh]?$'
  if [[ "$trimmed" =~ $sleep_re ]]; then
    return 0
  fi

  echo_bare_re='^echo(\ -n)?\ (.+)$'
  if [[ "$trimmed" =~ $echo_bare_re ]]; then
    args="${BASH_REMATCH[2]:-}"
    # The whole-command scan in is_trivial_command already rejected $, `, >, <, ( anywhere in
    # the command, so only glob characters remain to check here.
    if printf '%s' "$args" | grep -qE '[][*?]'; then
      return 1
    fi
    return 0
  fi

  return 1
}

# is_trivial_command <raw command string>
# Returns 0 (trivial) only when EVERY non-empty &&/||/;/|/&-delimited segment of the command is
# itself trivial per is_trivial_segment, AND the command contains none of $, `, >, <, ( anywhere
# (including inside quotes -- e.g. `echo "$SECONDS"` must be rejected even though the $ sits
# inside a double-quoted string, since it still undergoes shell expansion). Checking the raw text
# rather than a quote-blanked variant is deliberate here: unlike guard-destructive-git.sh's
# free-text-prose problem, an echo argument's quoted content IS the thing that would actually be
# printed/expanded, so it must stay visible to this scan.
#
# Segment splitting below is NOT quote-aware (a literal ;/&/| inside a quoted argument would
# incorrectly create a segment boundary). This is an accepted, safe-direction blind spot: a
# broken segment from such a split will not match any trivial pattern, so it can only ever
# produce a false "non-trivial" verdict, never a false "trivial" one.
is_trivial_command() {
  local raw nocomment seg all_trivial
  raw="$1"

  # Best-effort trailing-comment strip, per line (a bash comment runs only to end of its own
  # line). Not quote-aware: a literal '#' inside a quoted argument would also be stripped, which
  # again can only push a segment toward "non-trivial", never the reverse.
  nocomment=$(printf '%s' "$raw" | sed -e 's/\(^\|[[:space:]]\)#.*$//') || nocomment="$raw"

  if printf '%s' "$nocomment" | grep -qE '\$|`|>|<|\('; then
    return 1
  fi

  all_trivial=1
  while IFS= read -r seg; do
    if ! is_trivial_segment "$seg"; then
      all_trivial=0
      break
    fi
  done < <(printf '%s\n' "$nocomment" | tr -s ';&|' '\n')

  [ "$all_trivial" -eq 1 ]
}

# --- Read and parse the PostToolUse payload. Any failure here falls through to `{}` / exit 0. ---
INPUT=$(cat) || INPUT=""

if ! command -v jq >/dev/null 2>&1; then
  echo '{}'
  exit 0
fi

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null) || TOOL_NAME=""
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || COMMAND=""
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null) || SESSION_ID=""

if [ "$TOOL_NAME" != "Bash" ] || [ -z "$COMMAND" ] || [ -z "$SESSION_ID" ]; then
  echo '{}'
  exit 0
fi

# Restrict the session id to a safe filename character set before it ever touches a path. Do NOT
# invent a fallback session key for a value that fails this check -- per design, an unsafe or
# absent session id means "do not count", not "count under a synthetic key".
if ! [[ "$SESSION_ID" =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo '{}'
  exit 0
fi

STATE_DIR="${NOOP_BASH_STATE_DIR:-$SCRIPT_DIR/../tmp}"
STATE_FILE="$STATE_DIR/noop-bash-count-$SESSION_ID"

if ! is_trivial_command "$COMMAND"; then
  rm -f "$STATE_FILE" 2>/dev/null || true
  echo '{}'
  exit 0
fi

mkdir -p "$STATE_DIR" 2>/dev/null || true

COUNT=0
if [ -f "$STATE_FILE" ]; then
  RAW_COUNT=$(cat "$STATE_FILE" 2>/dev/null) || RAW_COUNT=""
  if [[ "$RAW_COUNT" =~ ^[0-9]+$ ]]; then
    COUNT="$RAW_COUNT"
  fi
fi
COUNT=$((COUNT + 1))

TMP_STATE_FILE="$STATE_FILE.tmp.$$"
if printf '%s\n' "$COUNT" > "$TMP_STATE_FILE" 2>/dev/null; then
  mv -f "$TMP_STATE_FILE" "$STATE_FILE" 2>/dev/null || true
fi
rm -f "$TMP_STATE_FILE" 2>/dev/null || true

THRESHOLD_RAW="${NOOP_BASH_THRESHOLD:-}"
if [[ "$THRESHOLD_RAW" =~ ^[1-9][0-9]*$ ]]; then
  THRESHOLD="$THRESHOLD_RAW"
else
  THRESHOLD=3
fi

if [ "$COUNT" -ge "$THRESHOLD" ] && [ "$(( (COUNT - THRESHOLD) % THRESHOLD ))" -eq 0 ]; then
  MESSAGE="$COUNT consecutive no-op Bash calls detected (:, true, bare date, a literal echo, or a sleep fragment). See context/patterns/external-process-wait.md: use a single bounded blocking wait (a timeout below the Bash-tool ceiling paired with a status re-check), do independent work first, and never fill the wait with :/true/date/echo filler or background/Monitor a CI wait from inside a subagent. This is advisory only and does not block."
  jq -n --arg msg "$MESSAGE" '{additionalContext: $msg}' 2>/dev/null || echo '{}'
else
  echo '{}'
fi

exit 0
