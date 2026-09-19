#!/usr/bin/env bash
# test-detect-noop-bash.sh - Fixture-driven regression suite for detect-noop-bash.sh's
# classification, threshold, reset, session-isolation, and fail-open behavior.
#
# Drives the hook as a real subprocess: pipes a synthetic PostToolUse JSON payload
# ({"tool_name":"Bash", "session_id":"...", "tool_input":{"command":"..."}}) on stdin, built with
# `jq -n --arg` so quotes/newlines in the tested command never corrupt the payload. Asserts on
# both stdout (the hook's only output channel -- either the literal string "{}" or a JSON object
# carrying `additionalContext`) and exit code (always expected to be 0 -- this hook is advisory
# only and must never signal failure to its caller).
#
# NOOP_BASH_STATE_DIR is exported to a fresh mktemp -d workdir for the whole suite so the hook
# never touches its real default state directory (`agent-system/extensions/core/tmp`, which
# exists on disk and is NOT gitignored -- see plan Decision 2). A dedicated case near the end
# asserts that directory was never created by this run.
#
# Follows the core shell-test convention in context/standards/shell-script-testing.md:
# pass()/fail()/info() helpers, PASSED/FAILED integer counters, mktemp -d workdir with trap EXIT
# cleanup, exit 0 on all-pass and exit 1 on any-fail.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# This single relative path resolves to agent-system/extensions/core/hooks/ in source-store mode
# and to .claude/hooks/ in deployed mode, with no branching -- see test-guard-destructive-git.sh
# for the identical precedent this suite follows.
HOOK="$SCRIPT_DIR/../../hooks/detect-noop-bash.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

if [ ! -f "$HOOK" ]; then
  echo "ERROR: expected detect-noop-bash.sh at $HOOK" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required to build synthetic PostToolUse payloads and is not on PATH" >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

export NOOP_BASH_STATE_DIR="$WORKDIR"

# --- Helpers -----------------------------------------------------------------------------

SESSION_SEQ_FILE="$WORKDIR/.session-seq"
echo 0 > "$SESSION_SEQ_FILE"
# fresh_session -- a new, never-before-used session id for this suite run. The counter is kept
# in a file (not a plain shell variable) because every call site invokes this via command
# substitution (`sid="$(fresh_session)"`), which forks a subshell -- an in-memory increment there
# would never be visible to the parent shell or to the next call, silently handing out the same
# session id every time.
fresh_session() {
  local n
  n=$(( $(cat "$SESSION_SEQ_FILE") + 1 ))
  echo "$n" > "$SESSION_SEQ_FILE"
  printf 'sess-test-%d-%d' "$$" "$n"
}

# count_file <session_id> -- path to that session's counter state file.
count_file() {
  printf '%s' "$NOOP_BASH_STATE_DIR/noop-bash-count-$1"
}

# run_hook <session_id> <command> [tool_name] -- builds and pipes a synthetic PostToolUse
# payload, echoing the hook's stdout. Uses the suite-wide NOOP_BASH_STATE_DIR/THRESHOLD.
run_hook() {
  local session="$1" cmd="$2" tool="${3:-Bash}"
  jq -n --arg t "$tool" --arg s "$session" --arg c "$cmd" \
    '{tool_name: $t, session_id: $s, tool_input: {command: $c}}' \
    | bash "$HOOK"
}

# run_hook_thr <threshold> <session_id> <command> -- like run_hook but with NOOP_BASH_THRESHOLD
# set for this one invocation only.
run_hook_thr() {
  local threshold="$1" session="$2" cmd="$3"
  jq -n --arg s "$session" --arg c "$cmd" \
    '{tool_name: "Bash", session_id: $s, tool_input: {command: $c}}' \
    | NOOP_BASH_THRESHOLD="$threshold" bash "$HOOK"
}

# assert_trivial <label> <command> -- runs <command> in a fresh session and expects it to be
# classified trivial: stdout "{}" and a counter file containing exactly "1".
assert_trivial() {
  local label="$1" cmd="$2" sid out cf
  sid="$(fresh_session)"
  out="$(run_hook "$sid" "$cmd")"
  cf="$(count_file "$sid")"
  if [ "$out" = "{}" ] && [ -f "$cf" ] && [ "$(cat "$cf")" = "1" ]; then
    pass "$label: classified trivial (count file == 1)"
  else
    info "cmd=[$cmd] out=[$out] count_file_exists=$([ -f "$cf" ] && echo yes || echo no) count=$(cat "$cf" 2>/dev/null || echo MISSING)"
    fail "$label: expected trivial classification with count file == 1"
  fi
}

# assert_nontrivial <label> <command> -- runs <command> in a fresh session and expects it to be
# classified non-trivial: stdout "{}" and NO counter file created.
assert_nontrivial() {
  local label="$1" cmd="$2" sid out cf
  sid="$(fresh_session)"
  out="$(run_hook "$sid" "$cmd")"
  cf="$(count_file "$sid")"
  if [ "$out" = "{}" ] && [ ! -f "$cf" ]; then
    pass "$label: classified non-trivial (no count file)"
  else
    info "cmd=[$cmd] out=[$out] count_file_exists=$([ -f "$cf" ] && echo yes || echo no)"
    fail "$label: expected non-trivial classification (no count file)"
  fi
}

# =====================================================================
# Classification positives (each in a fresh session; count file == 1 afterward)
# =====================================================================
assert_trivial "classify: bare colon"                  ":"
assert_trivial "classify: bare true"                    "true"
assert_trivial "classify: bare date"                     "date"
assert_trivial "classify: date -u"                       "date -u"
assert_trivial "classify: echo literal word"             "echo waiting"
assert_trivial "classify: echo quoted literal"           'echo "waiting for CI"'
assert_trivial "classify: sleep with number"             "sleep 30"
assert_trivial "classify: sleep && echo compound"        "sleep 5 && echo waiting"
assert_trivial "classify: true; date -u compound"        "true; date -u"

# =====================================================================
# Classification negatives (count file absent afterward)
# =====================================================================
# shellcheck disable=SC2016 # single-quoted deliberately: the literal $ text must survive as
# command data (the hook's own classifier must see it), not be shell-expanded by this suite.
assert_nontrivial "classify: echo with variable expansion"    'echo "Elapsed: $SECONDS"'
# shellcheck disable=SC2016 # see disable comment above -- same rationale.
assert_nontrivial "classify: echo with command substitution"  'echo $(gh run view 1)'
assert_nontrivial "classify: echo with redirection"            "echo done > log.txt"
assert_nontrivial "classify: date with append redirection"     "date >> log"
assert_nontrivial "classify: date with format argument"        "date +%s"
assert_nontrivial "classify: sleep && non-trivial command"     "sleep 5 && gh run view 1"
assert_nontrivial "classify: echo piped into tee"               "echo x | tee f"
assert_nontrivial "classify: unrelated git command"             "git status"
assert_nontrivial "classify: true && non-trivial command"       "true && make test"
assert_nontrivial "classify: trivial word inside unrelated quoted string" \
  'git commit -m "true"'

# =====================================================================
# Threshold: fires at 3, not at 4/5, fires again at 6 (default threshold)
# =====================================================================
thr_session="$(fresh_session)"
thr_out1="$(run_hook "$thr_session" "true")"
thr_out2="$(run_hook "$thr_session" "true")"
thr_out3="$(run_hook "$thr_session" "true")"
thr_out4="$(run_hook "$thr_session" "true")"
thr_out5="$(run_hook "$thr_session" "true")"
thr_out6="$(run_hook "$thr_session" "true")"

if [ "$thr_out1" = "{}" ]; then pass "threshold: 1st call is {}"; else fail "threshold: 1st call expected {}, got $thr_out1"; fi
if [ "$thr_out2" = "{}" ]; then pass "threshold: 2nd call is {}"; else fail "threshold: 2nd call expected {}, got $thr_out2"; fi
if printf '%s' "$thr_out3" | grep -q "external-process-wait.md" && printf '%s' "$thr_out3" | jq -e . >/dev/null 2>&1; then
  pass "threshold: 3rd call fires message and is valid JSON"
else
  fail "threshold: 3rd call expected message containing external-process-wait.md, got $thr_out3"
fi
if [ "$thr_out4" = "{}" ]; then pass "threshold: 4th call is {}"; else fail "threshold: 4th call expected {}, got $thr_out4"; fi
if [ "$thr_out5" = "{}" ]; then pass "threshold: 5th call is {}"; else fail "threshold: 5th call expected {}, got $thr_out5"; fi
if printf '%s' "$thr_out6" | grep -q "external-process-wait.md"; then
  pass "threshold: 6th call fires message again"
else
  fail "threshold: 6th call expected message, got $thr_out6"
fi

# =====================================================================
# Reset: a non-trivial call removes the counter; the next trivial call restarts at 1
# =====================================================================
reset_session="$(fresh_session)"
run_hook "$reset_session" "true" >/dev/null
run_hook "$reset_session" "true" >/dev/null
run_hook "$reset_session" "git status" >/dev/null
reset_cf="$(count_file "$reset_session")"
if [ ! -f "$reset_cf" ]; then
  pass "reset: non-trivial call removes the counter file"
else
  fail "reset: expected counter file removed after non-trivial call, found count=$(cat "$reset_cf")"
fi

reset_out1="$(run_hook "$reset_session" "true")"
if [ "$reset_out1" = "{}" ] && [ -f "$reset_cf" ] && [ "$(cat "$reset_cf")" = "1" ]; then
  pass "reset: trivial call after reset restarts the counter at 1"
else
  fail "reset: expected count == 1 after reset, got out=[$reset_out1] count=$(cat "$reset_cf" 2>/dev/null || echo MISSING)"
fi

reset_out2="$(run_hook "$reset_session" "true")"
if [ "$reset_out2" = "{}" ]; then
  pass "reset: 2nd call after reset is still {} (below threshold)"
else
  fail "reset: 2nd call after reset expected {}, got $reset_out2"
fi

# =====================================================================
# Session isolation: a streak in one session does not affect another session's counter
# =====================================================================
iso_a="$(fresh_session)"
iso_b="$(fresh_session)"
run_hook "$iso_a" "true" >/dev/null
run_hook "$iso_a" "true" >/dev/null
run_hook "$iso_a" "true" >/dev/null
iso_b_out="$(run_hook "$iso_b" "true")"
iso_b_cf="$(count_file "$iso_b")"
if [ "$iso_b_out" = "{}" ] && [ -f "$iso_b_cf" ] && [ "$(cat "$iso_b_cf")" = "1" ]; then
  pass "session isolation: session B's own 1st call is unaffected by session A's streak"
else
  fail "session isolation: expected session B count == 1, got out=[$iso_b_out] count=$(cat "$iso_b_cf" 2>/dev/null || echo MISSING)"
fi

# =====================================================================
# Fail-open: every malformed/edge-case input still exits 0 with stdout "{}"
# =====================================================================
fo_out="$(printf '' | bash "$HOOK")"
fo_code=$?
if [ "$fo_code" -eq 0 ] && [ "$fo_out" = "{}" ]; then
  pass "fail-open: empty stdin -> exit 0, {}"
else
  fail "fail-open: empty stdin expected exit 0 + {}, got exit=$fo_code out=[$fo_out]"
fi

fo_out="$(printf 'this is not json at all' | bash "$HOOK")"
fo_code=$?
if [ "$fo_code" -eq 0 ] && [ "$fo_out" = "{}" ]; then
  pass "fail-open: non-JSON stdin -> exit 0, {}"
else
  fail "fail-open: non-JSON stdin expected exit 0 + {}, got exit=$fo_code out=[$fo_out]"
fi

fo_sid="$(fresh_session)"
fo_out="$(run_hook "$fo_sid" "true" "Write")"
fo_code=$?
fo_cf="$(count_file "$fo_sid")"
if [ "$fo_code" -eq 0 ] && [ "$fo_out" = "{}" ] && [ ! -f "$fo_cf" ]; then
  pass "fail-open: non-Bash tool_name -> exit 0, {}, no counting"
else
  fail "fail-open: non-Bash tool_name expected exit 0 + {} + no count file, got exit=$fo_code out=[$fo_out]"
fi

fo_out="$(jq -n --arg c "true" '{tool_name: "Bash", tool_input: {command: $c}}' | bash "$HOOK")"
fo_code=$?
if [ "$fo_code" -eq 0 ] && [ "$fo_out" = "{}" ]; then
  pass "fail-open: missing session_id -> exit 0, {}"
else
  fail "fail-open: missing session_id expected exit 0 + {}, got exit=$fo_code out=[$fo_out]"
fi

unwritable_dir="$WORKDIR/unwritable-parent"
mkdir -p "$unwritable_dir"
chmod 555 "$unwritable_dir"
fo_sid="$(fresh_session)"
fo_out="$(jq -n --arg s "$fo_sid" --arg c "true" '{tool_name: "Bash", session_id: $s, tool_input: {command: $c}}' \
  | NOOP_BASH_STATE_DIR="$unwritable_dir/nested" bash "$HOOK" 2>/dev/null)"
fo_code=$?
chmod 755 "$unwritable_dir"
if [ "$fo_code" -eq 0 ] && [ "$fo_out" = "{}" ]; then
  pass "fail-open: unwritable state dir -> exit 0, {}"
else
  fail "fail-open: unwritable state dir expected exit 0 + {}, got exit=$fo_code out=[$fo_out]"
fi

# =====================================================================
# NOOP_BASH_THRESHOLD override: a valid override changes the firing point; an invalid value
# falls back to the default of 3.
# =====================================================================
thr2_session="$(fresh_session)"
thr2_out1="$(run_hook_thr 2 "$thr2_session" "true")"
thr2_out2="$(run_hook_thr 2 "$thr2_session" "true")"
if [ "$thr2_out1" = "{}" ]; then
  pass "threshold override: 1st call (NOOP_BASH_THRESHOLD=2) is {}"
else
  fail "threshold override: 1st call expected {}, got $thr2_out1"
fi
if printf '%s' "$thr2_out2" | grep -q "external-process-wait.md"; then
  pass "threshold override: 2nd call fires with NOOP_BASH_THRESHOLD=2"
else
  fail "threshold override: 2nd call expected message, got $thr2_out2"
fi

badthr_session="$(fresh_session)"
badthr_out1="$(run_hook_thr "abc" "$badthr_session" "true")"
badthr_out2="$(run_hook_thr "abc" "$badthr_session" "true")"
badthr_out3="$(run_hook_thr "abc" "$badthr_session" "true")"
if [ "$badthr_out1" = "{}" ] && [ "$badthr_out2" = "{}" ]; then
  pass "threshold override: invalid value (abc) does not fire early"
else
  fail "threshold override: invalid value expected {} for calls 1-2, got [$badthr_out1] [$badthr_out2]"
fi
if printf '%s' "$badthr_out3" | grep -q "external-process-wait.md"; then
  pass "threshold override: invalid value falls back to default threshold of 3"
else
  fail "threshold override: invalid value expected fallback fire at 3rd call, got $badthr_out3"
fi

# Zero and negative overrides must also fall back to the default of 3, not divide-by-zero or
# fire immediately.
zero_session="$(fresh_session)"
zero_out1="$(run_hook_thr 0 "$zero_session" "true")"
zero_out2="$(run_hook_thr 0 "$zero_session" "true")"
zero_out3="$(run_hook_thr 0 "$zero_session" "true")"
if [ "$zero_out1" = "{}" ] && [ "$zero_out2" = "{}" ] && printf '%s' "$zero_out3" | grep -q "external-process-wait.md"; then
  pass "threshold override: NOOP_BASH_THRESHOLD=0 falls back to default of 3"
else
  fail "threshold override: NOOP_BASH_THRESHOLD=0 expected fallback to 3, got [$zero_out1] [$zero_out2] [$zero_out3]"
fi

# =====================================================================
# No stray state directory created under the source store's own tmp/ (Decision 2)
# =====================================================================
SOURCE_STORE_TMP="$SCRIPT_DIR/../../tmp"
if [ ! -d "$SOURCE_STORE_TMP" ]; then
  pass "no stray tmp dir created under agent-system/extensions/core/tmp"
else
  fail "stray tmp dir created at $SOURCE_STORE_TMP -- NOOP_BASH_STATE_DIR override not honored"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
