#!/usr/bin/env bash
# detect-noop-bash.sh
# PostToolUse hook (matcher "Bash"): classifies trivial no-op Bash commands (`:`, `true`, bare
# `date`/`date -u`, a pure-literal `echo`, `sleep <N>[smh]?`), tracks the number of CONSECUTIVE
# trivial calls per Claude Code session, and after a threshold of them in a row injects an
# advisory `additionalContext` message pointing at context/patterns/external-process-wait.md and
# context/patterns/bounded-build-waiter.md's bounded-wait idioms.
#
# Motivating incident: a subagent waiting on a ~25-minute GitHub Actions run had its foreground
# `sleep` blocked, its `gh run watch` backgrounded by the 600s Bash timeout, and its Monitor loop
# waking it on every poll -- so it filled the gaps with roughly 130 no-op Bash calls (`:`, `true`,
# `date -u`, `echo waiting`) until it had to be stopped manually. This hook cannot prevent that
# pattern (it is advisory only, per contract below) but it surfaces the corrective idiom the
# moment a filler streak starts, rather than after 130 calls.
#
# A second, measured incident (a ~62-minute, 689-call local-suite spin) showed this streak
# counter was reachable in name only: the agent alternated one trivial `echo idle` with one
# non-trivial `grep`/`tail`/`wc` read of the suite log issued solely to poll for completion, and
# the counter being DELETED on every non-trivial command meant the streak never exceeded 1 --
# mechanically replayed through this script's prior version: 0 firings across all 689 calls. See
# "Three-class accounting" below for the repair.
#
# Contract (non-negotiable):
#   - ADVISORY ONLY. This hook NEVER blocks a Bash call. It always exits 0.
#   - FAILS OPEN. Any internal error (missing jq, malformed stdin, unwritable state dir, a
#     non-Bash tool call, a missing/unsafe session id) results in `{}` on stdout and exit 0 --
#     never a crash, never a nonzero exit.
#   - RESETS on any genuine-progress command: the per-session counter is deleted, not merely
#     zeroed, so the very next trivial call restarts the streak at 1. A repeated read-only
#     inspection probe (see below) is neither counted as filler nor treated as progress, because
#     the measured incident shows it is used to disguise filler, not to make it.
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
#
# Three-class accounting (the measured-incident repair): every command is Class T (trivial, per
# is_trivial_command -- unchanged), Class P (a repeated read-only inspection probe -- NEW, see
# below), or Class W (genuine progress -- everything else). Class T increments the counter. Class
# W deletes it, exactly as before. Class P does NEITHER: it is not evidence of progress, so it
# must not clear a filler streak the way the measured incident's `grep`/`tail`/`wc` reads did --
# but it is also not filler itself, so it must not count toward the threshold either. A given
# inspection-probe SHAPE (its ordered leading words, e.g. `wc|grep|tail` -- not its exact text,
# since the log path and pattern vary call to call) is Class W the FIRST time it is seen in a
# session (it resets the counter, same as any other non-trivial command, and its shape is
# remembered) and Class P every time after that. The shape memory lives in a separate sidecar,
# `noop-bash-shapes-<session>`, independent of the counter file, so a Class-W reset never erases
# the very memory that lets a repeated shape be recognized.

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

# inspection_fingerprint <raw command string>
# Prints the command-shape fingerprint (the ordered leading words of each separator-delimited
# segment, joined by `|`) and returns 0 ONLY when the command is a repeated-read-only-inspection
# CANDIDATE: every non-empty segment's leading word is one of the read-only inspection utilities
# `cat`/`tail`/`head`/`wc`/`grep`/`ls`/`stat`/`test`/`[` (each contributes no side effect of its
# own -- it only reads file or process state), is independently classified trivial by
# is_trivial_segment (covers a bare/literal-argument `echo` used as a cosmetic separator inside
# the probe, e.g. `tail -c 200 log; echo; grep ...`), or is the `kill -0 <target>` liveness-check
# idiom specifically (handled separately below -- only the `-0` form is read-only; any other
# signal is a real action and must not qualify). Returns 1 (prints nothing meaningful) for any
# other command, including one with zero segments.
#
# The fingerprint is a SHAPE, not the literal text: two calls against different log paths or
# different grep patterns but the same ordered utility sequence (e.g. `wc|grep|tail` both times)
# fingerprint identically, which is what lets a session recognize "the same probe, again" despite
# the log path or pattern varying call to call, as the measured incident's sequence does.
#
# Quoted spans are blanked (the same `sed -z 's/"[^"]*"/""/g'` idiom guard-destructive-git.sh
# uses) BEFORE splitting into segments, unlike is_trivial_command's whole-command scan above.
# This direction matters here specifically: a quoted `|` or `[` inside a probe's own grep pattern
# (e.g. `grep -aE '^\[(FAIL|skip)\]' log`) would otherwise fragment one segment into several,
# each failing the allowlist check and pushing the verdict toward "not inspection" -- i.e. toward
# a counter reset. That is the exact failure this function exists to close (the measured
# incident's real `grep -aE '^\[(FAIL|skip)\]' ...` calls are quoted exactly this way), so unlike
# is_trivial_command's safe-direction blind spot, an unblanked split here would reproduce the
# defect rather than merely erring conservatively.
inspection_fingerprint() {
  local raw blanked seg seg_trimmed leading fp_parts seg_count
  raw="$1"
  blanked=$(printf '%s' "$raw" | sed -z -e 's/"[^"]*"/""/g' -e "s/'[^']*'/''/g") || blanked="$raw"

  fp_parts=""
  seg_count=0
  while IFS= read -r seg; do
    seg_trimmed=$(printf '%s' "$seg" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//') || seg_trimmed="$seg"
    if [ -z "$seg_trimmed" ]; then
      continue
    fi
    leading="${seg_trimmed%% *}"
    case "$leading" in
      cat|tail|head|wc|grep|ls|stat|test|'[')
        : # read-only inspection utility
        ;;
      kill)
        case "$seg_trimmed" in
          kill\ -0\ *)
            : # the sanctioned liveness-check form only
            ;;
          *)
            return 1
            ;;
        esac
        ;;
      *)
        if ! is_trivial_segment "$seg_trimmed"; then
          return 1
        fi
        ;;
    esac
    seg_count=$((seg_count + 1))
    if [ -z "$fp_parts" ]; then
      fp_parts="$leading"
    else
      fp_parts="$fp_parts|$leading"
    fi
  done < <(printf '%s\n' "$blanked" | tr -s ';&|' '\n')

  if [ "$seg_count" -eq 0 ]; then
    return 1
  fi

  printf '%s\n' "$fp_parts"
  return 0
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
SHAPES_FILE="$STATE_DIR/noop-bash-shapes-$SESSION_ID"
SHAPES_CAP=10

if ! is_trivial_command "$COMMAND"; then
  # Class P vs. Class W: see "Three-class accounting" in the header comment above. A malformed
  # or unreadable shapes sidecar is treated as "no memory" (fails toward Class W, never toward
  # Class P), per this hook's fail-open contract.
  FINGERPRINT=""
  if FINGERPRINT=$(inspection_fingerprint "$COMMAND" 2>/dev/null) && [ -n "$FINGERPRINT" ]; then
    mkdir -p "$STATE_DIR" 2>/dev/null || true
    if [ -f "$SHAPES_FILE" ] && grep -qxF "$FINGERPRINT" "$SHAPES_FILE" 2>/dev/null; then
      # Class P: a repeated inspection-probe shape. Neither resets the filler streak (it is not
      # evidence of progress -- this is the exact mechanism the measured incident exploited) nor
      # counts toward it (it is not filler either).
      echo '{}'
      exit 0
    fi

    # First-seen inspection shape: Class W behavior (reset the counter, same as any other
    # non-trivial command) plus recording the shape so a later repeat is recognized as Class P.
    rm -f "$STATE_FILE" 2>/dev/null || true
    TMP_SHAPES_FILE="$SHAPES_FILE.tmp.$$"
    if { [ -f "$SHAPES_FILE" ] && cat "$SHAPES_FILE" 2>/dev/null; printf '%s\n' "$FINGERPRINT"; } \
        | tail -n "$SHAPES_CAP" > "$TMP_SHAPES_FILE" 2>/dev/null; then
      mv -f "$TMP_SHAPES_FILE" "$SHAPES_FILE" 2>/dev/null || true
    fi
    rm -f "$TMP_SHAPES_FILE" 2>/dev/null || true
    echo '{}'
    exit 0
  fi

  # Class W: genuine progress, not a recognized inspection-probe shape at all.
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
  MESSAGE="$COUNT consecutive no-op Bash calls detected (:, true, bare date, a literal echo, or a sleep fragment -- a repeated read-only log/status probe issued solely to poll for completion counts the same way and does not reset this streak). For a remote or external wait with no local writer, see context/patterns/external-process-wait.md: a single bounded blocking wait, do independent work first, never fill the wait with :/true/date/echo/log-poll filler, and never background/Monitor a CI wait from inside a subagent. For a detached LOCAL build/gate/test process, see context/patterns/bounded-build-waiter.md: the captured-pid/kill -0/outer-timeout idiom, never run_in_background or a Monitor for it. This is advisory only and does not block."
  jq -n --arg msg "$MESSAGE" '{additionalContext: $msg}' 2>/dev/null || echo '{}'
else
  echo '{}'
fi

exit 0
