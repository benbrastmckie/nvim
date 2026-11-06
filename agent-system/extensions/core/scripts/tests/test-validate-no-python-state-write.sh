#!/usr/bin/env bash
# test-validate-no-python-state-write.sh - Both-polarity fixture test for
# hooks/validate-no-python-state-write.sh, the write-time companion to
# scripts/lint/lint-state-writer-boundary.sh's Python-channel detection.
#
# Drives the hook as a real subprocess: copies it byte-for-byte into an isolated mktemp -d
# workdir (alongside a copy of the shared scripts/lib/state-writer-boundary-patterns-lib.sh
# library at the same relative path the hook expects:
# <workdir>/hooks/validate-no-python-state-write.sh sources
# <workdir>/scripts/lib/state-writer-boundary-patterns-lib.sh) and pipes a synthetic PreToolUse
# JSON payload ({"tool_input":{"command":...}}) on stdin for every case, asserting on the hook's
# EXIT CODE (2 = blocked, 0 = allowed) and on stderr content. The hook itself is never
# instrumented or modified for testability -- it never learns it is under test.
#
# Structural model: test-validate-no-task-references.sh (copy-into-isolated-workdir,
# jq-built synthetic payload, assert_triggers/assert_silent, shared-library-missing fixture
# pinning the fail-open polarity).
#
# NOTE on this file's own marker hygiene: this file deliberately feeds the Python
# open()-on-state.json anti-pattern as synthetic fixture COMMAND STRINGS (never executed as real
# Python -- they are piped to the HOOK under test as JSON, not run). It is on
# lint-state-writer-boundary.sh's EXCLUDED_FILES allowlist for exactly this reason, following
# test-validate-task-creation-audit.sh's existing precedent for the jq-shaped channel's own
# negative fixtures.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
HOOK_SRC="$SCRIPT_DIR/../../hooks/validate-no-python-state-write.sh"
LIB_SRC="$SCRIPT_DIR/../lib/state-writer-boundary-patterns-lib.sh"

PASSED=0
FAILED=0

if [ ! -f "$HOOK_SRC" ]; then
  echo "ERROR: expected validate-no-python-state-write.sh at $HOOK_SRC" >&2
  exit 2
fi

if [ ! -f "$LIB_SRC" ]; then
  echo "ERROR: expected shared library state-writer-boundary-patterns-lib.sh at $LIB_SRC" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required to build synthetic PreToolUse payloads and is not on PATH" >&2
  exit 2
fi

common_test_workdir_init

# Mirror the hook's expected sibling layout: hooks/validate-no-python-state-write.sh sources
# ../scripts/lib/state-writer-boundary-patterns-lib.sh relative to its OWN directory.
mkdir -p "$WORKDIR/hooks" "$WORKDIR/scripts/lib"
HOOK="$WORKDIR/hooks/validate-no-python-state-write.sh"
cp "$HOOK_SRC" "$HOOK"
chmod +x "$HOOK"
cp "$LIB_SRC" "$WORKDIR/scripts/lib/state-writer-boundary-patterns-lib.sh"

# run_hook <command> -- builds a synthetic PreToolUse Bash payload via jq (safe against quotes/
# newlines in command) and pipes it to the copied hook. Echoes "EXITCODE|STDERR" so callers can
# assert on both.
run_hook() {
  local command="$1" out exit_code
  out="$(jq -n --arg cmd "$command" '{tool_input: {command: $cmd}}' \
    | bash "$HOOK" 2>&1 1>/dev/null)"
  exit_code=$?
  printf '%s|%s' "$exit_code" "$out"
}

hook_exit_code() {
  local command="$1"
  jq -n --arg cmd "$command" '{tool_input: {command: $cmd}}' \
    | bash "$HOOK" >/dev/null 2>&1
  echo $?
}

# assert_triggers <label> <command> -- expects exit 2 (blocked) and non-empty stderr.
assert_triggers() {
  local label="$1" command="$2" result code stderr_out
  result="$(run_hook "$command")"
  code="${result%%|*}"
  stderr_out="${result#*|}"
  if [ "$code" -eq 2 ] && [ -n "$stderr_out" ]; then
    common_test_pass "$label: exits 2 with stderr message"
  else
    common_test_fail "$label: expected exit 2 + stderr, got exit=$code stderr='$stderr_out'"
  fi
}

# assert_silent <label> <command> -- expects exit 0 (allowed).
assert_silent() {
  local label="$1" command="$2" code
  code="$(hook_exit_code "$command")"
  if [ "$code" -eq 0 ]; then
    common_test_pass "$label: exits 0 (allowed)"
  else
    common_test_fail "$label: expected exit 0, got exit=$code"
  fi
}

# =====================================================================
# Positive fixtures (must exit 2 / blocked)
# =====================================================================

assert_triggers "positive: default-ensure_ascii json.dump via open() on live state.json" \
'python3 -c "
import json
data = json.load(open('"'"'specs/state.json'"'"'))
json.dump(data, open('"'"'specs/state.json'"'"', '"'"'w'"'"'))
"'

assert_triggers "positive: explicit ensure_ascii=False still blocked" \
'python3 -c "
import json
data = json.load(open('"'"'specs/state.json'"'"'))
json.dump(data, open('"'"'specs/state.json'"'"', '"'"'w'"'"'), ensure_ascii=False)
"'

assert_triggers "positive: with-open idiom open() line" \
'python3 -c "
import json
with open('"'"'specs/state.json'"'"', '"'"'w'"'"') as f:
    json.dump({}, f)
"'

assert_triggers "positive: archive target, append mode" \
'python3 -c "
import json
with open('"'"'specs/archive/state.json'"'"', '"'"'a'"'"') as f:
    json.dump({}, f)
"'

assert_triggers "positive: vault-root target, in-place r+ mode" \
'python3 -c "
import json
with open(f\"{vault_root}/state.json\", '"'"'r+'"'"') as f:
    data = json.load(f)
    f.seek(0)
    json.dump(data, f)
"'

# =====================================================================
# Negative fixtures (must exit 0 / allowed)
# =====================================================================

assert_silent "negative: read-only open(), no mode" \
'python3 -c "
import json
with open('"'"'specs/state.json'"'"') as f:
    data = json.load(f)
"'

assert_silent "negative: read-only open(), explicit r mode" \
'python3 -c "
import json
with open('"'"'specs/state.json'"'"', '"'"'r'"'"') as f:
    data = json.load(f)
"'

assert_silent "negative: equivalent state-write.sh invocation" \
".claude/scripts/state-write.sh '.foo = \$val' --arg val bar --session-id sess_123"

assert_silent "negative: ordinary command, no state.json at all" \
"echo hello world"

assert_silent "negative: open() on an unrelated JSON file" \
'python3 -c "
import json
json.dump({}, open('"'"'manifest.json'"'"', '"'"'w'"'"'))
"'

# =====================================================================
# Shared-library-missing fixture: hook must fail OPEN (exit 0), never block every Bash call in
# the session just because its own dependency vanished.
# =====================================================================
NOLIBDIR="$(mktemp -d)"
mkdir -p "$NOLIBDIR/hooks"
cp "$HOOK_SRC" "$NOLIBDIR/hooks/validate-no-python-state-write.sh"
chmod +x "$NOLIBDIR/hooks/validate-no-python-state-write.sh"
nolib_fixture_command='python3 -c "
import json
json.dump({}, open('"'"'specs/state.json'"'"', '"'"'w'"'"'))
"'
nolib_out="$(jq -n --arg cmd "$nolib_fixture_command" '{tool_input: {command: $cmd}}' \
  | bash "$NOLIBDIR/hooks/validate-no-python-state-write.sh" 2>&1 1>/dev/null)"
nolib_code=$?
rm -rf "$NOLIBDIR"
if [ "$nolib_code" -eq 0 ] && [ -n "$nolib_out" ]; then
  common_test_pass "shared-library-missing: fails open (exit 0) with a warning"
else
  common_test_fail "shared-library-missing: expected exit 0 + warning, got exit=$nolib_code out='$nolib_out'"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
