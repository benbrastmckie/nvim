#!/usr/bin/env bash
# test-validate-bounded-waiter.sh - Fixture-driven regression suite for
# validate-bounded-waiter.sh's three-way conjunction matcher (loop + sleep + name-match).
#
# Drives the hook as a real subprocess: pipes a synthetic PreToolUse JSON payload
# ({"tool_input":{"command": "..."}}) on stdin, built with `jq -n --arg` so quotes/newlines in
# the tested command never corrupt the payload. Asserts on the hook's EXIT CODE (2 = blocked,
# 0 = allowed) as the primary signal -- this hook's only output channel is stderr, so the
# `test-guard-destructive-git.sh` exit-code convention applies, not
# `test-detect-noop-bash.sh`'s stdout-JSON assertions. Every blocked case additionally asserts
# that stderr carries the canonical `kill -0` idiom. The hook itself is never instrumented or
# modified for testability; it never learns it is under test.
#
# IMPORTANT: once validate-bounded-waiter.sh is registered and deployed, a Bash heredoc carrying
# any of these fixture command strings is itself a blockable Bash command (the fixture strings
# ARE the banned shapes). This file MUST be authored and edited with the Write/Edit tools, never
# a Bash heredoc.
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
# and test-detect-noop-bash.sh for the identical precedent this suite follows.
HOOK="$SCRIPT_DIR/../../hooks/validate-bounded-waiter.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

if [ ! -f "$HOOK" ]; then
  echo "ERROR: expected validate-bounded-waiter.sh at $HOOK" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required to build synthetic PreToolUse payloads and is not on PATH" >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# --- Helpers -------------------------------------------------------------------------------

# run_hook <command> -- pipes a synthetic PreToolUse payload for <command> into the hook.
# Writes stdout to $WORKDIR/out, stderr to $WORKDIR/err, and echoes the exit code.
run_hook() {
  local cmd="$1" code
  jq -n --arg c "$cmd" '{tool_input: {command: $c}}' \
    | bash "$HOOK" >"$WORKDIR/out" 2>"$WORKDIR/err"
  code=$?
  echo "$code"
}

# assert_blocked <label> <command> -- expects exit 2 AND stderr carrying the kill -0 idiom.
assert_blocked() {
  local label="$1" cmd="$2" code
  code="$(run_hook "$cmd")"
  if [ "$code" -eq 2 ]; then
    if grep -q 'kill -0' "$WORKDIR/err"; then
      pass "$label: blocked (exit 2) with kill -0 idiom in stderr"
    else
      fail "$label: exit 2 but stderr did not carry the kill -0 idiom"
    fi
  else
    fail "$label: expected exit 2, got exit=$code"
  fi
}

# assert_allowed <label> <command> -- expects exit 0.
assert_allowed() {
  local label="$1" cmd="$2" code
  code="$(run_hook "$cmd")"
  if [ "$code" -eq 0 ]; then
    pass "$label: allowed (exit 0)"
  else
    fail "$label: expected exit 0, got exit=$code"
  fi
}

# =====================================================================
# Must-block cases (the five bad shapes, including the [b]racket variant)
# =====================================================================
assert_blocked "must-block: until ! pgrep -f ... self-match" \
  "until ! pgrep -f 'distsys/check.sh' >/dev/null 2>&1; do sleep 20; done"
assert_blocked "must-block: while pgrep -f ... positive-test variant" \
  "while pgrep -f 'distsys/check.sh'; do sleep 20; done"
assert_blocked "must-block: until ! ps aux | grep ..." \
  "until ! ps aux | grep -q 'bash check.sh'; do sleep 8; done"
assert_blocked "must-block: until ! ps -ef | grep ..." \
  "until ! ps -ef | grep -q 'bash check.sh'; do sleep 8; done"
assert_blocked "must-block: [b]racket variant of ps | grep does NOT exempt" \
  "until ! ps aux | grep -q '[b]ash check.sh'; do sleep 8; done"

# =====================================================================
# Flag-clustering regressions -- pin the bare-word pgrep ruling (Phase 1): a future narrowing
# to an enumerated flag list must fail these loudly.
# =====================================================================
assert_blocked "flag-clustering: pgrep -af" \
  "until pgrep -af 'x/check.sh'; do sleep 5; done"
assert_blocked "flag-clustering: pgrep -fa" \
  "until pgrep -fa 'x/check.sh'; do sleep 5; done"
assert_blocked "flag-clustering: pgrep -x -f" \
  "until pgrep -x -f 'x/check.sh'; do sleep 5; done"
assert_blocked "flag-clustering: pgrep --full" \
  "until pgrep --full 'x/check.sh'; do sleep 5; done"
assert_blocked "flag-clustering: bare pgrep, no flags" \
  "until pgrep 'x/check.sh'; do sleep 5; done"

# =====================================================================
# No-exemption pin: kill -0 alongside a name-match test inside a loop still blocks.
# =====================================================================
assert_blocked "no-exemption: kill -0 plus pgrep inside loop still blocks" \
  "until ! pgrep -f 'x/check.sh' >/dev/null; do kill -0 \$pid 2>/dev/null; sleep 1; done"

# =====================================================================
# Must-allow cases
# =====================================================================
assert_allowed "must-allow: bare pgrep (no loop, no sleep)" \
  "pgrep -f 'x/check.sh'"
assert_allowed "must-allow: bare ps aux | grep (no loop, no sleep)" \
  "ps aux | grep 'x/check.sh'"
assert_allowed "must-allow: one-shot name-match conditional outside a loop" \
  "if pgrep -f 'x/check.sh'; then echo up; fi"
assert_allowed "must-allow: canonical kill -0 waiter" \
  'timeout 300 bash -c '"'"'while kill -0 "$1" 2>/dev/null; do sleep 10; done'"'"' _ "$pid"'
assert_allowed "must-allow: ps -p \"\$pid\" loop (a PID test, not a name match)" \
  'until ! ps -p "$pid" >/dev/null; do sleep 5; done'
assert_allowed "must-allow: log-sentinel poll (no process-name match)" \
  "until grep -q DONE build.log; do sleep 10; done"
assert_allowed "must-allow: no-op filler echo idle (not this hook's territory)" \
  "echo idle"
assert_allowed "must-allow: no-op filler bare true (not this hook's territory)" \
  "true"

# =====================================================================
# Fail-open cases
# =====================================================================

# jq masked off PATH -- following detect-noop-bash.sh's own `command -v jq` gate as the shape to
# replicate. Uses an absolute bash binary path (resolved via the suite's own, unmodified PATH)
# so the child process itself is still found once PATH is overridden for it.
BASH_BIN="$(command -v bash)"
jq -n --arg c "until pgrep -f x; do sleep 1; done" '{tool_input: {command: $c}}' \
  > "$WORKDIR/jq-masked-payload.json"
env -i PATH=/nonexistent "$BASH_BIN" "$HOOK" < "$WORKDIR/jq-masked-payload.json" \
  >"$WORKDIR/out" 2>"$WORKDIR/err"
jq_masked_code=$?
if [ "$jq_masked_code" -eq 0 ]; then
  pass "fail-open: jq masked off PATH -> exit 0"
else
  fail "fail-open: jq masked off PATH -> expected exit 0, got exit=$jq_masked_code"
fi

# Empty stdin.
printf '' | bash "$HOOK" >"$WORKDIR/out" 2>"$WORKDIR/err"
empty_code=$?
if [ "$empty_code" -eq 0 ]; then
  pass "fail-open: empty stdin -> exit 0"
else
  fail "fail-open: empty stdin -> expected exit 0, got exit=$empty_code"
fi

# Non-JSON stdin.
printf 'this is not json' | bash "$HOOK" >"$WORKDIR/out" 2>"$WORKDIR/err"
nonjson_code=$?
if [ "$nonjson_code" -eq 0 ]; then
  pass "fail-open: non-JSON stdin -> exit 0"
else
  fail "fail-open: non-JSON stdin -> expected exit 0, got exit=$nonjson_code"
fi

# Well-formed payload with no tool_input.command.
jq -n '{tool_input: {}}' | bash "$HOOK" >"$WORKDIR/out" 2>"$WORKDIR/err"
nocommand_code=$?
if [ "$nocommand_code" -eq 0 ]; then
  pass "fail-open: well-formed payload with no tool_input.command -> exit 0"
else
  fail "fail-open: well-formed payload with no tool_input.command -> expected exit 0, got exit=$nocommand_code"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
