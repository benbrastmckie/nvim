#!/usr/bin/env bash
# test-redeploy-remedy-lib.sh - Regression suite for scripts/lib/redeploy-remedy-lib.sh, the
# single definition of the redeploy-remedy text every converted emission site routes through.
#
# Proves the hard constraints the plan this library was built under requires: both functions'
# output contains the `deploy-headless.sh` substring, begins no physical line with `WARN:`,
# emits no trailing newline, is idempotent under double-source, and that a caller using
# Decision 1(c)'s guarded-source snippet with the library ABSENT falls back to a no-op
# `redeploy_remedy_fragment` rather than failing.
#
# Structural model: scripts/tests/test-issue-record.sh (set -uo pipefail, pass()/fail()/info()
# helpers, PASSED/FAILED integer counters, exit 0 all-pass / 1 any-fail / 2 environment error).
# No filesystem fixture is needed -- this library is pure functions with no I/O -- so this
# suite sources it directly, source-store-first with a deployed-tree fallback.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

LIB_CANDIDATES=(
  "$SCRIPT_DIR/../lib/redeploy-remedy-lib.sh"
  "$REPO_ROOT/.claude/scripts/lib/redeploy-remedy-lib.sh"
)

LIB_UNDER_TEST=""
for candidate in "${LIB_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    LIB_UNDER_TEST="$candidate"
    break
  fi
done

if [[ -z "$LIB_UNDER_TEST" ]]; then
  echo "ENV ERROR: redeploy-remedy-lib.sh not found at any candidate path" >&2
  exit 2
fi

PASSED=0
FAILED=0

pass() { PASSED=$((PASSED + 1)); echo "  [PASS] $1"; }
fail() { FAILED=$((FAILED + 1)); echo "  [FAIL] $1"; }
info() { echo "$1"; }

info "=== test-redeploy-remedy-lib.sh ==="
info "Library under test: $LIB_UNDER_TEST"

# shellcheck source=/dev/null
. "$LIB_UNDER_TEST"

# Case 1: both functions defined after source.
if declare -F redeploy_remedy_fragment >/dev/null 2>&1; then
  pass "redeploy_remedy_fragment is defined after source"
else
  fail "redeploy_remedy_fragment is NOT defined after source"
fi
if declare -F redeploy_remedy >/dev/null 2>&1; then
  pass "redeploy_remedy is defined after source"
else
  fail "redeploy_remedy is NOT defined after source"
fi

fragment_out="$(redeploy_remedy_fragment)"
full_out="$(redeploy_remedy)"

# Case 2: deploy-headless.sh substring in both.
case "$fragment_out" in
  *deploy-headless.sh*) pass "redeploy_remedy_fragment output contains 'deploy-headless.sh'" ;;
  *) fail "redeploy_remedy_fragment output missing 'deploy-headless.sh': $fragment_out" ;;
esac
case "$full_out" in
  *deploy-headless.sh*) pass "redeploy_remedy output contains 'deploy-headless.sh'" ;;
  *) fail "redeploy_remedy output missing 'deploy-headless.sh': $full_out" ;;
esac

# Case 3: no physical line begins with WARN:.
if printf '%s\n' "$fragment_out" | grep -q '^WARN:'; then
  fail "redeploy_remedy_fragment output begins a physical line with WARN:"
else
  pass "redeploy_remedy_fragment output begins no physical line with WARN:"
fi
if printf '%s\n' "$full_out" | grep -q '^WARN:'; then
  fail "redeploy_remedy output begins a physical line with WARN:"
else
  pass "redeploy_remedy output begins no physical line with WARN:"
fi

# Case 4: no trailing newline (command substitution already strips a SINGLE trailing newline,
# so probe with printf '%s' captured via wc -c against the known string length instead).
fragment_raw="$(redeploy_remedy_fragment; printf 'X')"
if [[ "${fragment_raw: -1}" == "X" && "${fragment_raw: -2:1}" != $'\n' ]]; then
  pass "redeploy_remedy_fragment emits no trailing newline"
else
  fail "redeploy_remedy_fragment appears to emit a trailing newline"
fi
full_raw="$(redeploy_remedy; printf 'X')"
if [[ "${full_raw: -1}" == "X" && "${full_raw: -2:1}" != $'\n' ]]; then
  pass "redeploy_remedy emits no trailing newline"
else
  fail "redeploy_remedy appears to emit a trailing newline"
fi

# Case 5: no task-number reference (a bare integer preceded by "task" word-boundary).
if printf '%s%s' "$fragment_out" "$full_out" | grep -qE '[Tt]ask #?[0-9]+'; then
  fail "output contains a task-number reference"
else
  pass "output contains no task-number reference"
fi

# Case 6: double-source idempotence (safe to source twice, no error, same output).
before="$(redeploy_remedy_fragment)"
# shellcheck source=/dev/null
. "$LIB_UNDER_TEST"
# shellcheck source=/dev/null
. "$LIB_UNDER_TEST"
after="$(redeploy_remedy_fragment)"
if [[ "$before" == "$after" ]]; then
  pass "double/triple-source is idempotent (identical output)"
else
  fail "double-source changed output: before=[$before] after=[$after]"
fi

# Case 7: degrade-safe fallback -- Decision 1(c)'s guarded-source snippet, with the library
# pointed at a nonexistent path, must define a no-op redeploy_remedy_fragment and must not exit
# non-zero.
(
  set -uo pipefail
  unset -f redeploy_remedy_fragment redeploy_remedy 2>/dev/null
  _RR_LIB="/nonexistent/path/redeploy-remedy-lib.sh"
  # shellcheck source=/dev/null
  [ -f "$_RR_LIB" ] && . "$_RR_LIB"
  declare -F redeploy_remedy_fragment >/dev/null 2>&1 || redeploy_remedy_fragment() { printf '%s' ""; }
  degraded_out="$(redeploy_remedy_fragment)"
  if [[ -z "$degraded_out" ]]; then
    exit 0
  else
    exit 1
  fi
)
degrade_rc=$?
if [[ "$degrade_rc" -eq 0 ]]; then
  pass "degrade-safe guarded source with a missing lib defines a no-op fragment and exits 0"
else
  fail "degrade-safe guarded source did not behave as expected (rc=$degrade_rc)"
fi

info ""
info "=== Results: $PASSED passed, $FAILED failed ==="
if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
