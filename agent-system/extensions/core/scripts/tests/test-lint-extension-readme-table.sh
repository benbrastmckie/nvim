#!/usr/bin/env bash
# test-lint-extension-readme-table.sh - Fixture-driven regression test for
# scripts/lint/lint-extension-readme-table.sh.
#
# Proves the lint's bidirectional diff on synthetic fixtures: a clean table passes, a missing
# row fails and names the directory, an extra row fails and names the dangling row, and `core`
# is exempted and visibly reported as such under --verbose even when it has no table row. An
# additional environment-error case proves a root with no README.md exits 2, never a silent 0.
# All fixtures are synthetic, written to a scratch directory; this suite never depends on the
# live tree being clean and never mutates the repository.
#
# Structural model: test-lint-dead-command-recommendations.sh (mktemp -d workdir, deploy-tree-
# first / source-store-fallback candidate resolution, common_test_pass/_fail/_info helpers).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.
# Note this is a test OF a lint: its exit code reports test success, not lint success.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"
LINT_SCRIPT="$(common_test_resolve_candidate "lint-extension-readme-table.sh" \
  "$REPO_ROOT/.claude/scripts/lint/lint-extension-readme-table.sh" \
  "$SCRIPT_DIR/../lint/lint-extension-readme-table.sh")" || exit 2

PASSED=0
FAILED=0
common_test_workdir_init

# ---------------------------------------------------------------------------
# Fixture helper: writes a synthetic extensions root into "$1" with a README.md carrying a
# `## Available Extensions` table whose rows are the names in "$2" (space-separated), and
# subdirectories for every name in "$3" (space-separated) -- deliberately including `core` in
# every fixture (added by the caller, not by this helper) so the exemption is exercised by
# construction, never by omission.
# ---------------------------------------------------------------------------
write_fixture() {
  local root="$1"
  local row_names="$2"
  local dir_names="$3"

  mkdir -p "$root"
  local d
  for d in $dir_names; do
    mkdir -p "$root/$d"
  done

  {
    echo "# Test fixture"
    echo ""
    echo "## Available Extensions"
    echo ""
    echo "| Extension | Task Type | Description | Docs |"
    echo "|-----------|----------|-------------|------|"
    local r
    for r in $row_names; do
      echo "| $r | $r | Fixture description for $r | [README]($r/README.md) |"
    done
    echo ""
    echo "## Loading Extensions"
    echo ""
    echo "Not part of the table."
  } > "$root/README.md"
}

# =====================================================================
# Case 1: clean table -- directories core, alpha, beta; rows for alpha and beta. Lint exits 0.
# =====================================================================
common_test_info "=== Case 1: clean table ==="

CASE1_ROOT="$WORKDIR/case1"
write_fixture "$CASE1_ROOT" "alpha beta" "core alpha beta"

if bash "$LINT_SCRIPT" "$CASE1_ROOT" >"$WORKDIR/case1-out.txt" 2>&1; then
  common_test_pass "lint exits 0 on a clean table with no drift"
else
  common_test_fail "lint rejected a clean table (expected exit 0):
$(cat "$WORKDIR/case1-out.txt")"
fi

# =====================================================================
# Case 2: missing row -- directories core, alpha, beta; row for alpha only. Lint exits non-zero
# and names beta on a [VIOLATION]-tagged line.
# =====================================================================
common_test_info "=== Case 2: missing row ==="

CASE2_ROOT="$WORKDIR/case2"
write_fixture "$CASE2_ROOT" "alpha" "core alpha beta"

if bash "$LINT_SCRIPT" "$CASE2_ROOT" >"$WORKDIR/case2-out.txt" 2>&1; then
  common_test_fail "lint exited 0 despite a directory (beta) with no table row (expected non-zero)"
else
  common_test_pass "lint exits non-zero when a directory has no table row"
fi

if grep -q '\[VIOLATION\]' "$WORKDIR/case2-out.txt" && grep -q "'beta'" "$WORKDIR/case2-out.txt"; then
  common_test_pass "lint names the missing directory (beta) on a [VIOLATION]-tagged line"
else
  common_test_fail "lint output did not name the missing directory on a [VIOLATION] line:
$(cat "$WORKDIR/case2-out.txt")"
fi

# =====================================================================
# Case 3: extra row -- directories core, alpha; rows for alpha and ghost. Lint exits non-zero
# and names ghost on a [VIOLATION]-tagged line.
# =====================================================================
common_test_info "=== Case 3: extra (dangling) row ==="

CASE3_ROOT="$WORKDIR/case3"
write_fixture "$CASE3_ROOT" "alpha ghost" "core alpha"

if bash "$LINT_SCRIPT" "$CASE3_ROOT" >"$WORKDIR/case3-out.txt" 2>&1; then
  common_test_fail "lint exited 0 despite a dangling row (ghost) naming no real directory (expected non-zero)"
else
  common_test_pass "lint exits non-zero when a table row names no real directory"
fi

if grep -q '\[VIOLATION\]' "$WORKDIR/case3-out.txt" && grep -q "'ghost'" "$WORKDIR/case3-out.txt"; then
  common_test_pass "lint names the dangling row (ghost) on a [VIOLATION]-tagged line"
else
  common_test_fail "lint output did not name the dangling row on a [VIOLATION] line:
$(cat "$WORKDIR/case3-out.txt")"
fi

# =====================================================================
# Case 4: core exemption -- directories core, alpha; row for alpha only, deliberately with no
# core row. Lint exits 0, and under --verbose reports core as [EXEMPT] rather than silently
# absent from the output.
# =====================================================================
common_test_info "=== Case 4: core exemption, visible under --verbose ==="

CASE4_ROOT="$WORKDIR/case4"
write_fixture "$CASE4_ROOT" "alpha" "core alpha"

if bash "$LINT_SCRIPT" --verbose "$CASE4_ROOT" >"$WORKDIR/case4-out.txt" 2>&1; then
  common_test_pass "lint exits 0 when core has no table row (core is exempt by construction)"
else
  common_test_fail "lint rejected core's absence from the table (expected exit 0, core is exempt):
$(cat "$WORKDIR/case4-out.txt")"
fi

if grep -q '\[EXEMPT\]' "$WORKDIR/case4-out.txt" && grep -qi 'core' "$WORKDIR/case4-out.txt"; then
  common_test_pass "lint reports core as [EXEMPT] under --verbose, visibly rather than silently"
else
  common_test_fail "lint did not visibly report core's exemption under --verbose:
$(cat "$WORKDIR/case4-out.txt")"
fi

if grep -q '\[VIOLATION\]' "$WORKDIR/case4-out.txt"; then
  common_test_fail "lint flagged a violation on the core-exemption fixture (expected none):
$(cat "$WORKDIR/case4-out.txt")"
else
  common_test_pass "lint reports no violation on the core-exemption fixture"
fi

# =====================================================================
# Case 5 (environment error): a root with no README.md exits 2, never a silent 0.
# =====================================================================
common_test_info "=== Case 5: environment error -- missing README.md ==="

CASE5_ROOT="$WORKDIR/case5"
mkdir -p "$CASE5_ROOT/core" "$CASE5_ROOT/alpha"

bash "$LINT_SCRIPT" "$CASE5_ROOT" >"$WORKDIR/case5-out.txt" 2>&1
case5_rc=$?

if [ "$case5_rc" -eq 2 ]; then
  common_test_pass "lint exits 2 when the extensions root has no README.md"
else
  common_test_fail "lint exited $case5_rc (expected 2) for a root with no README.md:
$(cat "$WORKDIR/case5-out.txt")"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
