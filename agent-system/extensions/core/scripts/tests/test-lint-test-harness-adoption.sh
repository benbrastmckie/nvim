#!/usr/bin/env bash
# test-lint-test-harness-adoption.sh - Both-polarity fixture test for
# scripts/lint/lint-test-harness-adoption.sh.
#
# The lint's job is to fail when a shell test suite calls bare pass()/fail()/info() in command
# position (including inside a case-statement arm or a single-line if/then/fi) with no local
# definition of that name AND no sourcing of lib/common.sh, and to stay silent both on the two
# legitimate shapes (a local pass()/fail()/info() definition, or sourcing lib/common.sh and
# calling common_test_pass/common_test_fail/common_test_info instead) and on prose that merely
# contains the words "pass"/"fail" outside command position. This test asserts all of that
# against synthetic fixtures written to a scratch directory, so it never depends on the live tree
# being clean and never mutates the repository.
#
# Structural model: test-lint-lifecycle-status-var.sh (mktemp -d workdir, deploy-tree-first /
# source-store-fallback candidate resolution, pass()/fail()/info() helpers).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.
# Note this is a test OF a lint: its exit code reports test success, not lint success.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

resolve_candidate() {
  local desc="$1"; shift
  local candidate
  for candidate in "$@"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  echo "ERROR: $desc not found at any of:" >&2
  for candidate in "$@"; do
    echo "  $candidate" >&2
  done
  return 1
}

LINT_SCRIPT="$(resolve_candidate "lint-test-harness-adoption.sh" \
  "$REPO_ROOT/.claude/scripts/lint/lint-test-harness-adoption.sh" \
  "$SCRIPT_DIR/../lint/lint-test-harness-adoption.sh")" || exit 2

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# =====================================================================
# Case 1 (negative polarity, the motivating incident shape): a case-statement arm and a
# single-line if/then/fi both call bare pass/fail/info with no local definition and no
# lib/common.sh sourcing -> lint must fail (exit 1) and name all three violations by file:line.
# =====================================================================
info "=== negative case: case-arm + single-line if/then/fi, no local defs, no harness source ==="

VIOLATING_FIXTURE="$WORKDIR/violating.sh"
cat > "$VIOLATING_FIXTURE" << 'EOF'
#!/usr/bin/env bash
set -uo pipefail
PASSED=0
FAILED=0
case "$1" in
  ok) pass "it worked" ;;
  *) fail "it broke" ;;
esac
if [ "$2" = "x" ]; then info "diagnostic note"; fi
EOF

if bash "$LINT_SCRIPT" "$VIOLATING_FIXTURE" >"$WORKDIR/violating-out.txt" 2>&1; then
  fail "lint exited 0 for the violating fixture (expected non-zero)"
else
  pass "lint exited non-zero for the violating fixture (case-arm + single-line if/then/fi)"
fi

if grep -q "violating.sh:6" "$WORKDIR/violating-out.txt" && \
   grep -q "violating.sh:7" "$WORKDIR/violating-out.txt" && \
   grep -q "violating.sh:9" "$WORKDIR/violating-out.txt"; then
  pass "lint reports all three violating call sites (case-arm pass, case-arm fail, if/then info) by file:line"
else
  fail "lint output did not name all three expected violating lines:
$(cat "$WORKDIR/violating-out.txt")"
fi

if grep -qc "VIOLATION" "$WORKDIR/violating-out.txt" >/dev/null 2>&1 && \
   [ "$(grep -c 'VIOLATION' "$WORKDIR/violating-out.txt")" -eq 3 ]; then
  pass "lint reports exactly 3 violations for the violating fixture"
else
  fail "lint reported $(grep -c 'VIOLATION' "$WORKDIR/violating-out.txt" 2>/dev/null || echo '?') violation(s) (expected 3)"
fi

# =====================================================================
# Case 2 (positive polarity, shape a): local pass()/fail()/info() definitions plus bare calls ->
# lint must pass (exit 0).
# =====================================================================
info "=== positive case: local pass()/fail()/info() definitions (shape a) ==="

LOCAL_DEF_FIXTURE="$WORKDIR/clean-local.sh"
cat > "$LOCAL_DEF_FIXTURE" << 'EOF'
#!/usr/bin/env bash
pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1"; }
info() { echo "[INFO] $1"; }
pass "ok"
fail "no"
info "note"
EOF

if bash "$LINT_SCRIPT" "$LOCAL_DEF_FIXTURE" >"$WORKDIR/clean-local-out.txt" 2>&1; then
  pass "lint exited 0 when pass()/fail()/info() are defined locally"
else
  fail "lint exited non-zero for a fixture with local pass()/fail()/info() definitions (unexpected):
$(cat "$WORKDIR/clean-local-out.txt")"
fi

# =====================================================================
# Case 3 (positive polarity, shape b): sourcing lib/common.sh and calling common_test_pass/
# common_test_fail/common_test_info directly -> lint must pass (exit 0).
# =====================================================================
info "=== positive case: sourcing lib/common.sh, common_test_* call sites (shape b) ==="

HARNESS_FIXTURE="$WORKDIR/clean-harness.sh"
cat > "$HARNESS_FIXTURE" << 'EOF'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
common_test_pass "ok"
common_test_fail "no"
common_test_info "note"
EOF

if bash "$LINT_SCRIPT" "$HARNESS_FIXTURE" >"$WORKDIR/clean-harness-out.txt" 2>&1; then
  pass "lint exited 0 when the suite sources lib/common.sh and calls common_test_* directly"
else
  fail "lint exited non-zero for a fixture sourcing lib/common.sh (unexpected):
$(cat "$WORKDIR/clean-harness-out.txt")"
fi

# =====================================================================
# Case 4 (false-positive control -- the exact regression this lint's own development surfaced
# against two pre-existing, unrelated suites): "pass"/"fail" appearing as ordinary English words
# inside a quoted log/description string, NOT in command position, must NOT be flagged.
# =====================================================================
info "=== control case: prose containing \"pass\"/\"fail\" outside command position ==="

PROSE_FIXTURE="$WORKDIR/prose.sh"
cat > "$PROSE_FIXTURE" << 'EOF'
#!/usr/bin/env bash
log_fail "expected gap=24/candidates=0 (keyword pass skipped). Got: $x"
log_info "s2 fail openalex answers query"
EOF

if bash "$LINT_SCRIPT" "$PROSE_FIXTURE" >"$WORKDIR/prose-out.txt" 2>&1; then
  pass "lint exited 0 for prose containing \"pass\"/\"fail\" outside command position (no false positive)"
else
  fail "lint exited non-zero for a prose-only fixture (false positive):
$(cat "$WORKDIR/prose-out.txt")"
fi

# =====================================================================
# Case 5 (--help): prints usage and exits 0.
# =====================================================================
info "=== --help: exits 0 and prints usage ==="

if HELP_OUT="$(bash "$LINT_SCRIPT" --help 2>&1)"; then
  if echo "$HELP_OUT" | grep -q "Usage: lint-test-harness-adoption.sh"; then
    pass "--help exits 0 and prints the usage line"
  else
    fail "--help exited 0 but did not print the expected usage line: $HELP_OUT"
  fi
else
  fail "--help exited non-zero (expected 0)"
fi

echo ""
echo "Results: $PASSED passed, $FAILED failed"
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
