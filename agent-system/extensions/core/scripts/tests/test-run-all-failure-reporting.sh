#!/usr/bin/env bash
# test-run-all-failure-reporting.sh - Regression suite for run-all.sh's per-suite failure naming
# and end-of-run failure roster contract (Defect 1 of the harness-fix task: "failing suites are
# never named"). Proves a deliberately-failing fixture suite IS named -- both inline and in the
# consolidated roster -- so the "zero [FAIL] markers" symptom this task fixed can never silently
# regress.
#
# Structural model: test-run-all-parallel.sh's synthetic-fixture-directory pattern (a minimal
# source-store-shaped tree under a mktemp WORKDIR, with the REAL run-all.sh copied in so its own
# SCRIPT_DIR resolution stays inside the fixture, never the real repo's 105-suite battery).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUN_ALL_SRC="$CORE_DIR/tests/run-all.sh"

if [ ! -f "$RUN_ALL_SRC" ]; then
  echo "ERROR: expected $RUN_ALL_SRC" >&2
  exit 2
fi

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); [ -n "${2:-}" ] && echo "$2"; }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

EXT_ROOT="$WORKDIR/exts"
TESTS_DIR="$EXT_ROOT/core/scripts/tests"
mkdir -p "$TESTS_DIR"
echo '{}' > "$EXT_ROOT/core/manifest.json"
cp "$RUN_ALL_SRC" "$TESTS_DIR/run-all.sh"
chmod +x "$TESTS_DIR/run-all.sh"
FIXTURE_RUNNER="$TESTS_DIR/run-all.sh"

# ── Fixture suites: 3 quick passes + 2 deliberately-failing (named so their paths are
# unambiguous in the output) ────────────────────────────────────────────────────────────────
for n in 1 2 3; do
  cat > "$TESTS_DIR/test-fixture-pass$n.sh" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$TESTS_DIR/test-fixture-pass$n.sh"
done
cat > "$TESTS_DIR/test-fixture-fail-a.sh" << 'EOF'
#!/usr/bin/env bash
echo "deliberate fixture failure a"
exit 1
EOF
cat > "$TESTS_DIR/test-fixture-fail-b.sh" << 'EOF'
#!/usr/bin/env bash
echo "deliberate fixture failure b"
exit 1
EOF
chmod +x "$TESTS_DIR/test-fixture-fail-a.sh" "$TESTS_DIR/test-fixture-fail-b.sh"
# 3 pass + 2 fail = 5 discovered fixture suites total.
FIXTURE_TOTAL=5
FAIL_PATH_A="$TESTS_DIR/test-fixture-fail-a.sh"
FAIL_PATH_B="$TESTS_DIR/test-fixture-fail-b.sh"

check_naming_and_roster() {
  # Usage: check_naming_and_roster LABEL OUTPUT
  # Asserts, against one run-all.sh invocation's captured stdout+stderr:
  #   - both failing fixtures are named in an inline [FAIL] <path> line
  #   - both failing fixtures' paths appear in the end-of-run roster block
  #   - the roster header's count matches the tally line's failed count (2)
  #   - the total count of literal `[FAIL]` token occurrences equals the number of failing
  #     fixtures (2) -- proving the roster did not reintroduce the token and double it
  local label="$1" out="$2"

  if printf '%s\n' "$out" | grep -qF "[FAIL] $FAIL_PATH_A" && \
     printf '%s\n' "$out" | grep -qF "[FAIL] $FAIL_PATH_B"; then
    pass "$label: both failing fixtures named in an inline [FAIL] <path> line"
  else
    fail "$label: inline [FAIL] naming missing for one or both fixtures" "$out"
  fi

  if printf '%s\n' "$out" | grep -q '^\[run-all\] Failing suites (2):$'; then
    pass "$label: roster header present with count 2"
  else
    fail "$label: roster header missing or wrong count" "$out"
  fi

  if printf '%s\n' "$out" | grep -qF "    $FAIL_PATH_A" && \
     printf '%s\n' "$out" | grep -qF "    $FAIL_PATH_B"; then
    pass "$label: both failing fixtures' paths appear in the roster block"
  else
    fail "$label: roster block missing one or both fixture paths" "$out"
  fi

  local tally_failed
  tally_failed="$(printf '%s\n' "$out" | grep -oE '^\[run-all\] [0-9]+ passed, [0-9]+ failed' | grep -oE '[0-9]+ failed' | grep -oE '^[0-9]+')"
  if [ "$tally_failed" = "2" ]; then
    pass "$label: tally line's failed count (2) matches the roster header's count"
  else
    fail "$label: tally line's failed count ('$tally_failed') does not match roster count (2)" "$out"
  fi

  local fail_token_count
  fail_token_count="$(printf '%s\n' "$out" | grep -oF '[FAIL]' | wc -l | tr -d ' ')"
  if [ "$fail_token_count" = "2" ]; then
    pass "$label: total [FAIL] token occurrences (2) equals the failing-suite count -- roster did not double-count"
  else
    fail "$label: total [FAIL] token occurrences ($fail_token_count) does not equal 2 -- roster may have reintroduced the token" "$out"
  fi
}

# =====================================================================
# Case set 1: default (--jobs 1, no --quiet)
# =====================================================================
default_out="$(bash "$FIXTURE_RUNNER" 2>&1)"
check_naming_and_roster "default (--jobs 1)" "$default_out"

# =====================================================================
# Case set 2: --quiet -- the naming and roster contract is NOT suppressed by --quiet.
# =====================================================================
quiet_out="$(bash "$FIXTURE_RUNNER" --quiet 2>&1)"
check_naming_and_roster "--quiet" "$quiet_out"

# =====================================================================
# Case set 3: --jobs 3 (parallel path parity) -- both --quiet and non-quiet.
# =====================================================================
jobs3_out="$(bash "$FIXTURE_RUNNER" --jobs 3 2>&1)"
check_naming_and_roster "--jobs 3" "$jobs3_out"

jobs3_quiet_out="$(bash "$FIXTURE_RUNNER" --quiet --jobs 3 2>&1)"
check_naming_and_roster "--jobs 3 --quiet" "$jobs3_quiet_out"

# =====================================================================
# Case: an all-passing fixture set prints no roster block at all and exits 0.
# =====================================================================
GREEN_EXT_ROOT="$WORKDIR/exts_green"
GREEN_TESTS_DIR="$GREEN_EXT_ROOT/core/scripts/tests"
mkdir -p "$GREEN_TESTS_DIR"
echo '{}' > "$GREEN_EXT_ROOT/core/manifest.json"
cp "$RUN_ALL_SRC" "$GREEN_TESTS_DIR/run-all.sh"
chmod +x "$GREEN_TESTS_DIR/run-all.sh"
for n in 1 2 3; do
  cat > "$GREEN_TESTS_DIR/test-fixture-pass$n.sh" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$GREEN_TESTS_DIR/test-fixture-pass$n.sh"
done
green_out="$(bash "$GREEN_TESTS_DIR/run-all.sh" 2>&1)"
green_rc=$?
if [ "$green_rc" -eq 0 ]; then
  pass "all-green fixture: exits 0"
else
  fail "all-green fixture: expected exit 0, got $green_rc" "$green_out"
fi
if printf '%s\n' "$green_out" | grep -q '^\[run-all\] Failing suites'; then
  fail "all-green fixture: unexpectedly printed a roster block" "$green_out"
else
  pass "all-green fixture: no roster block printed"
fi

# =====================================================================
# Manifest classification cases: a fixture-local known-failures.txt (never the real repo's
# manifest) classifies one failing fixture as EXPECTED and leaves the other unlisted (NEW).
# =====================================================================
if [ -f "$TESTS_DIR/known-failures.txt" ]; then
  fail "manifest setup: known-failures.txt unexpectedly already exists in the fixture"
else
  pass "missing-manifest case: no known-failures.txt present before this point (today's behavior exactly, confirmed by the case sets above)"
fi

cat > "$TESTS_DIR/known-failures.txt" << EOF
# fixture-local manifest -- classifies fail-a as EXPECTED, leaves fail-b unlisted (NEW)
test-fixture-fail-a.sh|real-defect|deliberate fixture classification|test-owner
EOF

manifest_out="$(bash "$FIXTURE_RUNNER" 2>&1)"
if printf '%s\n' "$manifest_out" | grep -qF '(1 expected, 1 NEW)'; then
  pass "manifest: tally shows (1 expected, 1 NEW) when one of two failures is manifest-listed"
else
  fail "manifest: expected '(1 expected, 1 NEW)' in tally" "$manifest_out"
fi
if printf '%s\n' "$manifest_out" | grep -qF "$FAIL_PATH_A (EXPECTED)"; then
  pass "manifest: roster annotates the listed fixture (EXPECTED)"
else
  fail "manifest: roster did not annotate the listed fixture (EXPECTED)" "$manifest_out"
fi
if printf '%s\n' "$manifest_out" | grep -qF "$FAIL_PATH_B (NEW)"; then
  pass "manifest: roster annotates the unlisted fixture (NEW)"
else
  fail "manifest: roster did not annotate the unlisted fixture (NEW)" "$manifest_out"
fi
manifest_prefix="$(printf '%s\n' "$manifest_out" | grep -oE '^\[run-all\] [0-9]+ passed, [0-9]+ failed')"
if [ "$manifest_prefix" = "[run-all] 3 passed, 2 failed" ]; then
  pass "manifest: leading 'N passed, M failed' prefix is byte-identical to the pre-manifest form"
else
  fail "manifest: leading tally prefix changed" "$manifest_prefix"
fi

# --fail-on-new: exits nonzero because fail-b is NEW (unlisted).
bash "$FIXTURE_RUNNER" --fail-on-new >/dev/null 2>&1
fail_on_new_rc=$?
if [ "$fail_on_new_rc" -ne 0 ]; then
  pass "--fail-on-new: exits nonzero when at least one failure is NEW"
else
  fail "--fail-on-new: expected nonzero exit with an unlisted failure present, got 0"
fi

# Now classify BOTH failing fixtures as EXPECTED -- --fail-on-new must exit 0.
cat > "$TESTS_DIR/known-failures.txt" << EOF
test-fixture-fail-a.sh|real-defect|deliberate fixture classification|test-owner
test-fixture-fail-b.sh|real-defect|deliberate fixture classification|test-owner
EOF
all_expected_out="$(bash "$FIXTURE_RUNNER" 2>&1)"
if printf '%s\n' "$all_expected_out" | grep -qF '(2 expected, 0 NEW)'; then
  pass "manifest: tally shows (2 expected, 0 NEW) when both failures are manifest-listed"
else
  fail "manifest: expected '(2 expected, 0 NEW)' in tally" "$all_expected_out"
fi
bash "$FIXTURE_RUNNER" --fail-on-new >/dev/null 2>&1
all_expected_rc=$?
if [ "$all_expected_rc" -eq 0 ]; then
  pass "--fail-on-new: exits 0 when every failure is manifest-listed (EXPECTED)"
else
  fail "--fail-on-new: expected exit 0 when all failures are EXPECTED, got $all_expected_rc"
fi
# Default (no --fail-on-new) exit-code semantics are unchanged: still nonzero even though every
# failure is EXPECTED -- EXPECTED does not mean "does not count as a failure" without the flag.
bash "$FIXTURE_RUNNER" >/dev/null 2>&1
default_with_manifest_rc=$?
if [ "$default_with_manifest_rc" -ne 0 ]; then
  pass "default exit code (no --fail-on-new) stays nonzero even when all failures are EXPECTED"
else
  fail "default exit code changed to 0 with a manifest present -- default semantics must be unaffected"
fi

# Deleting known-failures.txt restores the pre-manifest tally and roster exactly.
rm -f "$TESTS_DIR/known-failures.txt"
post_delete_out="$(bash "$FIXTURE_RUNNER" 2>&1)"
if [ "$post_delete_out" = "$default_out" ]; then
  pass "deleting known-failures.txt restores byte-identical pre-manifest output"
else
  fail "deleting known-failures.txt did not restore the original output" "$(diff <(echo "$default_out") <(echo "$post_delete_out"))"
fi

echo ""
echo "==================================================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "==================================================================="

[ "$FAILED" -eq 0 ] && exit 0 || exit 1
