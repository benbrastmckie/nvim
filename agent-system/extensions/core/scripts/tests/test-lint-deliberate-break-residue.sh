#!/usr/bin/env bash
# test-lint-deliberate-break-residue.sh - Both-direction fixture test for
# scripts/lint/lint-deliberate-break-residue.sh, plus the detector's own self-exclusion property.
#
# The lint's job is to fire on an anchored-start `while false &&` guard (Check A) and on a
# leftover `*.anchor-bak` file (Check B), while staying silent on a quoted occurrence of the same
# phrase and on its own corpus (including this suite's own source text). This suite asserts all
# four cases against synthetic fixtures written to a scratch directory, and separately against
# the real source store for the negative control -- it never writes to any real source-store
# path itself.
#
# Structural model: test-lint-scoped-commit-boundary.sh (mktemp -d workdir, deploy-tree-first /
# source-store-fallback subject resolution via common_test_resolve_subject plus the mandatory
# common_test_declare_subject line, common_test_pass/_fail/_info helpers, conventional
# Passed:/Failed: summary).
#
# SELF-EXCLUSION, SOLVED EXPLICITLY: Case 1's planted fixture line must begin (after leading
# whitespace) with the literal guard the lint detects, but no line of THIS suite's own source may
# begin that way, or the lint would fire on this very file. The planted line is therefore
# assembled from two separate shell variables at write time (plant_a / plant_b below), neither of
# which, on its own source line, begins with that phrase -- never a path exclusion, which would
# also blind the detector to a real mutation planted in a test file (exactly where the
# anti-pattern's source lives).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.
# Note this is a test OF a lint: its exit code reports test success, not lint success.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"
LINT_SCRIPT="$(common_test_resolve_subject "lint-deliberate-break-residue.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lint/lint-deliberate-break-residue.sh" \
  "$SCRIPT_DIR/../lint/lint-deliberate-break-residue.sh")" || exit 2
common_test_declare_subject "$LINT_SCRIPT"

PASSED=0
FAILED=0
common_test_workdir_init

# =====================================================================
# Case 1 (positive, Check A): a planted anchored-start `while false &&` guard
# =====================================================================
common_test_info "=== Case 1: planted anchored-start 'while false &&' guard (Check A) ==="

CASE1_DIR="$WORKDIR/case1/agent-system/extensions/core/scripts"
mkdir -p "$CASE1_DIR"
CASE1_FIXTURE="$CASE1_DIR/synthetic-regressed-accumulator.sh"

# Assembled from two pieces so that NEITHER resulting source line of this suite itself begins
# with the guard text -- the explicit solution to the detector's self-exclusion problem (see
# header). plant_a ends right before the guard would start; plant_b carries the rest.
plant_a="  "
plant_b="while false && IFS= read -r f; do"
{
  echo "#!/usr/bin/env bash"
  printf '%s%s\n' "$plant_a" "$plant_b"
  echo "  echo \"\$f\""
  echo "done"
} > "$CASE1_FIXTURE"

if bash "$LINT_SCRIPT" "$WORKDIR/case1" >"$WORKDIR/case1-out.txt" 2>&1; then
  common_test_fail "lint exited 0 for a planted anchored-start 'while false &&' guard (expected non-zero)"
else
  common_test_pass "lint exited non-zero for a planted anchored-start 'while false &&' guard"
fi

if grep -q "\[VIOLATION\].*synthetic-regressed-accumulator.sh:2" "$WORKDIR/case1-out.txt"; then
  common_test_pass "lint reports a [VIOLATION] line naming the planted file and line"
else
  common_test_fail "lint output did not name the planted violation file:line:
$(cat "$WORKDIR/case1-out.txt")"
fi

# =====================================================================
# Case 2 (positive, Check B): a leftover *.anchor-bak file
# =====================================================================
common_test_info "=== Case 2: leftover *.anchor-bak file (Check B) ==="

CASE2_DIR="$WORKDIR/case2/agent-system/extensions/core/scripts"
mkdir -p "$CASE2_DIR"
CASE2_FIXTURE="$CASE2_DIR/orchestrate-cycle-postflight.sh.anchor-bak"
echo "# synthetic leftover backup" > "$CASE2_FIXTURE"

if bash "$LINT_SCRIPT" "$WORKDIR/case2" >"$WORKDIR/case2-out.txt" 2>&1; then
  common_test_fail "lint exited 0 for a leftover *.anchor-bak file (expected non-zero)"
else
  common_test_pass "lint exited non-zero for a leftover *.anchor-bak file"
fi

if grep -q "\[VIOLATION\].*orchestrate-cycle-postflight.sh.anchor-bak" "$WORKDIR/case2-out.txt"; then
  common_test_pass "lint reports a [VIOLATION] line naming the leftover *.anchor-bak file"
else
  common_test_fail "lint output did not name the leftover *.anchor-bak file:
$(cat "$WORKDIR/case2-out.txt")"
fi

# =====================================================================
# Case 3 (negative control, self-exclusion): the real source store is clean, including the
# existing sed replacement string and this suite's own fixture-construction code
# =====================================================================
common_test_info "=== Case 3: negative control against the real source store (self-exclusion) ==="

if [ -n "$REPO_ROOT" ] && [ -d "$REPO_ROOT/agent-system/extensions" ]; then
  if bash "$LINT_SCRIPT" "$REPO_ROOT/agent-system/extensions" >"$WORKDIR/case3-out.txt" 2>&1; then
    common_test_pass "lint exits 0 against the real source store (no residue, including this suite's own fixture code)"
  else
    common_test_fail "lint reported residue against the real source store (unexpected):
$(cat "$WORKDIR/case3-out.txt")"
  fi

  if grep -q "test-orchestrate-cycle-postflight.sh" "$WORKDIR/case3-out.txt"; then
    common_test_fail "lint fired on test-orchestrate-cycle-postflight.sh's own sed replacement string (self-exclusion failed):
$(cat "$WORKDIR/case3-out.txt")"
  else
    common_test_pass "lint did not fire on test-orchestrate-cycle-postflight.sh's sed replacement string"
  fi

  if grep -q "test-lint-deliberate-break-residue.sh" "$WORKDIR/case3-out.txt"; then
    common_test_fail "lint fired on this suite's own fixture-construction code (self-exclusion failed):
$(cat "$WORKDIR/case3-out.txt")"
  else
    common_test_pass "lint did not fire on this suite's own fixture-construction code"
  fi
else
  common_test_fail "could not resolve the real source store under REPO_ROOT ($REPO_ROOT) -- case 3 cannot run"
fi

# =====================================================================
# Case 4 (clean-tree control): the phrase appears only inside a quoted string, on a line that
# does not itself start with the guard
# =====================================================================
common_test_info "=== Case 4: clean tree (phrase present only inside a quoted string) ==="

CASE4_DIR="$WORKDIR/case4/agent-system/extensions/core/scripts"
mkdir -p "$CASE4_DIR"
CASE4_FIXTURE="$CASE4_DIR/synthetic-unrelated-script.sh"
cat > "$CASE4_FIXTURE" << 'FIXTURE_EOF'
#!/usr/bin/env bash
echo "this line mentions while false && only as quoted text, never as a guard"
FIXTURE_EOF

if bash "$LINT_SCRIPT" "$WORKDIR/case4" >"$WORKDIR/case4-out.txt" 2>&1; then
  common_test_pass "lint exits 0 for a quoted, non-anchored occurrence of the phrase"
else
  common_test_fail "lint flagged a quoted, non-anchored occurrence of the phrase as a violation:
$(cat "$WORKDIR/case4-out.txt")"
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
