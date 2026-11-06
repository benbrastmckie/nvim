#!/usr/bin/env bash
# test-lint-subject-resolution-declaration.sh - Both-polarity fixture test for
# scripts/lint/lint-subject-resolution-declaration.sh.
#
# The lint's job is to fail distinctly on each of the three undeclared/silently-ordered
# subject-resolution shapes (a hand-duplicated local resolve_candidate() function, an inline
# CANDIDATES-array for-loop, and a common_test_resolve_candidate call against a .claude/scripts
# deployed candidate with no explicit mode) plus the missing-declaration case (a
# common_test_resolve_subject call with no paired common_test_declare_subject), while staying
# silent on a correct explicit-mode-plus-declaration suite and on every allowlisted file. This
# suite plants synthetic fixtures in a scratch directory and asserts both polarities; it never
# depends on the live tree being clean for most cases (the one deliberate exception is the
# standing "is the gate not red on the live tree" assertion) and never mutates the repository.
#
# Structural model: test-lint-verdict-extraction-anchoring.sh (mktemp -d WORKDIR,
# common_test_resolve_subject / common_test_declare_subject -- this suite dogfeeds the explicit
# helper it is itself testing, rather than the implicit common_test_resolve_candidate shape --
# common_test_pass/_fail/_info helpers).
#
# No on-disk fixture files are committed -- every fixture below is built and torn down inside the
# mktemp -d WORKDIR.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.
# Note this is a test OF a lint: its exit code reports test success, not lint success.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"
LINT_SCRIPT="$(common_test_resolve_subject "lint-subject-resolution-declaration.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lint/lint-subject-resolution-declaration.sh" \
  "$SCRIPT_DIR/../lint/lint-subject-resolution-declaration.sh")" || exit 2
common_test_declare_subject "$LINT_SCRIPT"

PASSED=0
FAILED=0
common_test_workdir_init

# =====================================================================
# Case 1 (FAILING): hand-duplicate shape -- a local resolve_candidate() function.
# =====================================================================
common_test_info "=== FAILING: hand-duplicate resolve_candidate() function ==="

CASE1_DIR="$WORKDIR/case1"
mkdir -p "$CASE1_DIR"
cat > "$CASE1_DIR/test-seeded-hand-dup.sh" << 'EOF'
#!/usr/bin/env bash
resolve_candidate() {
  for c in "$@"; do
    [ -f "$c" ] && { printf '%s\n' "$c"; return 0; }
  done
  return 1
}
EOF

case1_out="$(bash "$LINT_SCRIPT" "$CASE1_DIR" 2>&1)"
case1_rc=$?
if [[ $case1_rc -ne 0 ]]; then
  common_test_pass "hand-duplicate resolve_candidate() exits non-zero"
else
  common_test_fail "hand-duplicate resolve_candidate() exited 0 (expected non-zero):
$case1_out"
fi
if grep -q '\[VIOLATION\].*test-seeded-hand-dup\.sh.*hand-duplicate shape' <<< "$case1_out"; then
  common_test_pass "hand-duplicate shape reported, naming the seeded file"
else
  common_test_fail "hand-duplicate shape not reported as expected:
$case1_out"
fi

# =====================================================================
# Case 2 (FAILING): inline shape -- a CANDIDATES-array for-loop, no named function.
# =====================================================================
common_test_info "=== FAILING: inline CANDIDATES-array for-loop ==="

CASE2_DIR="$WORKDIR/case2"
mkdir -p "$CASE2_DIR"
cat > "$CASE2_DIR/test-seeded-inline-loop.sh" << 'EOF'
#!/usr/bin/env bash
FOO_CANDIDATES=(
  "/a/foo.sh"
  "/b/foo.sh"
)
for candidate in "${FOO_CANDIDATES[@]}"; do
  if [ -f "$candidate" ]; then
    FOO="$candidate"
    break
  fi
done
EOF

case2_out="$(bash "$LINT_SCRIPT" "$CASE2_DIR" 2>&1)"
case2_rc=$?
if [[ $case2_rc -ne 0 ]]; then
  common_test_pass "inline CANDIDATES-array for-loop exits non-zero"
else
  common_test_fail "inline CANDIDATES-array for-loop exited 0 (expected non-zero):
$case2_out"
fi
if grep -q '\[VIOLATION\].*test-seeded-inline-loop\.sh.*inline CANDIDATES-array' <<< "$case2_out"; then
  common_test_pass "inline-loop shape reported, naming the seeded file"
else
  common_test_fail "inline-loop shape not reported as expected:
$case2_out"
fi

# =====================================================================
# Case 3 (FAILING): missing-declaration shape -- resolve_subject with no paired declare_subject.
# =====================================================================
common_test_info "=== FAILING: common_test_resolve_subject without common_test_declare_subject ==="

CASE3_DIR="$WORKDIR/case3"
mkdir -p "$CASE3_DIR"
cat > "$CASE3_DIR/test-seeded-missing-declaration.sh" << 'EOF'
#!/usr/bin/env bash
SUBJECT="$(common_test_resolve_subject "foo" "deployed" "/a/foo.sh" "/b/foo.sh")"
echo "resolved: $SUBJECT"
EOF

case3_out="$(bash "$LINT_SCRIPT" "$CASE3_DIR" 2>&1)"
case3_rc=$?
if [[ $case3_rc -ne 0 ]]; then
  common_test_pass "missing-declaration shape exits non-zero"
else
  common_test_fail "missing-declaration shape exited 0 (expected non-zero):
$case3_out"
fi
if grep -q '\[VIOLATION\].*test-seeded-missing-declaration\.sh.*without a paired common_test_declare_subject' <<< "$case3_out"; then
  common_test_pass "missing-declaration shape reported, naming the seeded file"
else
  common_test_fail "missing-declaration shape not reported as expected:
$case3_out"
fi

# =====================================================================
# Case 4 (FAILING): unmigrated-implicit-order shape -- common_test_resolve_candidate against a
# .claude/scripts deployed candidate, no explicit mode.
# =====================================================================
common_test_info "=== FAILING: unmigrated implicit-order common_test_resolve_candidate ==="

CASE4_DIR="$WORKDIR/case4"
mkdir -p "$CASE4_DIR"
cat > "$CASE4_DIR/test-seeded-unmigrated.sh" << 'EOF'
#!/usr/bin/env bash
FOO="$(common_test_resolve_candidate "foo.sh" \
  "$REPO_ROOT/.claude/scripts/foo.sh" \
  "$SCRIPT_DIR/../foo.sh")" || exit 2
EOF

case4_out="$(bash "$LINT_SCRIPT" "$CASE4_DIR" 2>&1)"
case4_rc=$?
if [[ $case4_rc -ne 0 ]]; then
  common_test_pass "unmigrated implicit-order shape exits non-zero"
else
  common_test_fail "unmigrated implicit-order shape exited 0 (expected non-zero):
$case4_out"
fi
if grep -q '\[VIOLATION\].*test-seeded-unmigrated\.sh.*unmigrated implicit-order shape' <<< "$case4_out"; then
  common_test_pass "unmigrated-implicit-order shape reported, naming the seeded file"
else
  common_test_fail "unmigrated-implicit-order shape not reported as expected:
$case4_out"
fi

# =====================================================================
# Case 5 (PASSING): a fixture using the explicit helper correctly -- resolve_subject paired with
# declare_subject -- must never be flagged.
# =====================================================================
common_test_info "=== PASSING: correct explicit-mode-plus-declaration pair ==="

CASE5_DIR="$WORKDIR/case5"
mkdir -p "$CASE5_DIR"
cat > "$CASE5_DIR/test-seeded-correct.sh" << 'EOF'
#!/usr/bin/env bash
SUBJECT="$(common_test_resolve_subject "foo" "deployed" "/a/foo.sh" "/b/foo.sh")"
common_test_declare_subject "$SUBJECT"
EOF

case5_out="$(bash "$LINT_SCRIPT" "$CASE5_DIR" 2>&1)"
case5_rc=$?
if [[ $case5_rc -eq 0 ]]; then
  common_test_pass "correct explicit-mode-plus-declaration pair is not flagged"
else
  common_test_fail "correct fixture was unexpectedly flagged:
$case5_out"
fi

# =====================================================================
# Case 6 (PASSING): an allowlisted file is not flagged, even though its content trips a shape --
# mirror one of the lint's own baked-in allowlist entries under a matching relative path.
# =====================================================================
common_test_info "=== PASSING: an allowlisted file is not flagged ==="

CASE6_DIR="$WORKDIR/case6/agent-system/extensions/core/scripts/tests"
mkdir -p "$CASE6_DIR"
cat > "$CASE6_DIR/test-force-phases.sh" << 'EOF'
#!/usr/bin/env bash
resolve_candidate() {
  for c in "$@"; do
    [ -f "$c" ] && { printf '%s\n' "$c"; return 0; }
  done
  return 1
}
EOF

case6_out="$(bash "$LINT_SCRIPT" "$WORKDIR/case6" --verbose 2>&1)"
case6_rc=$?
if [[ $case6_rc -eq 0 ]]; then
  common_test_pass "an allowlisted file (test-force-phases.sh) is not flagged despite tripping a shape"
else
  common_test_fail "allowlisted file was unexpectedly flagged:
$case6_out"
fi
if grep -q '\[EXEMPT\].*test-force-phases\.sh' <<< "$case6_out"; then
  common_test_pass "the allowlisted file is reported as [EXEMPT] under --verbose"
else
  common_test_fail "the allowlisted file was not reported as [EXEMPT] under --verbose:
$case6_out"
fi

# =====================================================================
# Case 7 (regression net): a clean, unrelated fixture with no candidate/resolve/declare tokens at
# all is never flagged (no over-matching).
# =====================================================================
common_test_info "=== PASSING: unrelated fixture, no over-matching ==="

CASE7_DIR="$WORKDIR/case7"
mkdir -p "$CASE7_DIR"
cat > "$CASE7_DIR/test-unrelated.sh" << 'EOF'
#!/usr/bin/env bash
echo "nothing to see here"
EOF

case7_out="$(bash "$LINT_SCRIPT" "$CASE7_DIR" 2>&1)"
case7_rc=$?
if [[ $case7_rc -eq 0 ]]; then
  common_test_pass "unrelated fixture is not flagged (no over-matching)"
else
  common_test_fail "unrelated fixture was unexpectedly flagged:
$case7_out"
fi

# =====================================================================
# Case 8 (live-corpus case): run the lint with no positional argument against the real source
# store -- the standing assertion that the gate is not red on the live tree.
# =====================================================================
common_test_info "=== Live-corpus case: default corpus against the real source store ==="

case8_out="$(bash "$LINT_SCRIPT" 2>&1)"
case8_rc=$?
if [[ $case8_rc -eq 0 ]]; then
  common_test_pass "default corpus against the live source store exits 0"
else
  common_test_fail "default corpus against the live source store did not exit 0 (rc=$case8_rc):
$case8_out"
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
