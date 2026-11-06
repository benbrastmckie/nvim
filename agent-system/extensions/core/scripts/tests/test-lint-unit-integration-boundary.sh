#!/usr/bin/env bash
# test-lint-unit-integration-boundary.sh - Both-polarity fixture test for
# scripts/lint/lint-unit-integration-boundary.sh.
#
# Plants a synthetic tests directory and a synthetic classification data file in a mktemp -d
# WORKDIR (never mutates the real corpus) and exercises every case the lint's own header
# documents: a conforming unit suite, a conforming integration suite, a DELIBERATELY-VIOLATING
# unit suite that actually references run-all.sh (proving the enforcement fires rather than
# passing vacuously), an unclassified discovered suite (coverage-gap violation), an
# integration-class row with no reason recorded, an unrecognized class value, a stale row (INFO
# only, not a violation), and the real corpus's own live classification file (zero violations).
#
# Structural model: test-lint-test-harness-adoption.sh (deploy-tree-first / source-store-fallback
# candidate resolution via the shared harness, common_test_pass/_fail/_info trio).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.
# Note this is a test OF a lint: its exit code reports test success, not lint success.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"
LINT_SCRIPT="$(common_test_resolve_subject "lint-unit-integration-boundary.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lint/lint-unit-integration-boundary.sh" \
  "$SCRIPT_DIR/../lint/lint-unit-integration-boundary.sh")" || exit 2
common_test_declare_subject "$LINT_SCRIPT"

PASSED=0
FAILED=0
common_test_workdir_init

# =====================================================================
# Case 1 (PASSING): a conforming fixture -- one unit suite with no heavyweight reference, one
# integration suite that legitimately invokes run-all.sh, both correctly classified. Zero
# violations expected.
# =====================================================================
common_test_info "=== PASSING: conforming unit + integration fixture ==="

CASE1_DIR="$WORKDIR/case1"
mkdir -p "$CASE1_DIR"
cat > "$CASE1_DIR/test-unit-ok.sh" << 'EOF'
#!/usr/bin/env bash
echo "a plain unit suite with no heavyweight dependency"
EOF
cat > "$CASE1_DIR/test-integration-ok.sh" << 'EOF'
#!/usr/bin/env bash
bash ./run-all.sh --only test-unit-ok.sh
EOF
cat > "$CASE1_DIR/suite-classification.data" << 'EOF'
test-unit-ok.sh	unit	-
test-integration-ok.sh	integration	invokes:run-all.sh
EOF

case1_out="$(bash "$LINT_SCRIPT" --tests-dir "$CASE1_DIR" 2>&1)"
case1_rc=$?
if [[ $case1_rc -eq 0 ]]; then
  common_test_pass "conforming fixture: exits 0"
else
  common_test_fail "conforming fixture: exited $case1_rc (expected 0):
$case1_out"
fi
if echo "$case1_out" | grep -q '\[PASS\].*0 violation(s) across 2 discovered suite(s)'; then
  common_test_pass "conforming fixture: reports 0 violations across 2 discovered suites"
else
  common_test_fail "conforming fixture: unexpected summary:
$case1_out"
fi

# =====================================================================
# Case 2 (FAILING): a unit-classified suite that actually references run-all.sh -- the
# deliberately-violating fixture proving the enforcement fires rather than passing vacuously.
# =====================================================================
common_test_info "=== FAILING: unit-classified suite references run-all.sh ==="

CASE2_DIR="$WORKDIR/case2"
mkdir -p "$CASE2_DIR"
cat > "$CASE2_DIR/test-mislabeled.sh" << 'EOF'
#!/usr/bin/env bash
# this suite claims to be a pure unit test but actually shells out to the full battery
bash ./run-all.sh
EOF
cat > "$CASE2_DIR/suite-classification.data" << 'EOF'
test-mislabeled.sh	unit	-
EOF

case2_out="$(bash "$LINT_SCRIPT" --tests-dir "$CASE2_DIR" 2>&1)"
case2_rc=$?
if [[ $case2_rc -ne 0 ]]; then
  common_test_pass "deliberately-violating fixture: exits non-zero"
else
  common_test_fail "deliberately-violating fixture: exited 0 (expected non-zero):
$case2_out"
fi
if echo "$case2_out" | grep -q '\[VIOLATION\].*test-mislabeled\.sh' && echo "$case2_out" | grep -q 'run-all.sh'; then
  common_test_pass "deliberately-violating fixture: names the offending suite and the heavyweight tool"
else
  common_test_fail "deliberately-violating fixture: violation not reported as expected:
$case2_out"
fi

# =====================================================================
# Case 3 (FAILING): a discovered suite with no row in the classification data file at all --
# the coverage-gap violation.
# =====================================================================
common_test_info "=== FAILING: discovered suite has no classification row ==="

CASE3_DIR="$WORKDIR/case3"
mkdir -p "$CASE3_DIR"
cat > "$CASE3_DIR/test-classified.sh" << 'EOF'
#!/usr/bin/env bash
echo "classified"
EOF
cat > "$CASE3_DIR/test-unclassified.sh" << 'EOF'
#!/usr/bin/env bash
echo "never mentioned in the data file"
EOF
cat > "$CASE3_DIR/suite-classification.data" << 'EOF'
test-classified.sh	unit	-
EOF

case3_out="$(bash "$LINT_SCRIPT" --tests-dir "$CASE3_DIR" 2>&1)"
case3_rc=$?
if [[ $case3_rc -ne 0 ]]; then
  common_test_pass "coverage-gap fixture: exits non-zero"
else
  common_test_fail "coverage-gap fixture: exited 0 (expected non-zero):
$case3_out"
fi
if echo "$case3_out" | grep -q '\[VIOLATION\].*test-unclassified\.sh'; then
  common_test_pass "coverage-gap fixture: names the unclassified suite"
else
  common_test_fail "coverage-gap fixture: violation not reported as expected:
$case3_out"
fi

# =====================================================================
# Case 4 (FAILING): an integration-class row with no reason recorded (reason field is "-").
# =====================================================================
common_test_info "=== FAILING: integration row with no reason ==="

CASE4_DIR="$WORKDIR/case4"
mkdir -p "$CASE4_DIR"
cat > "$CASE4_DIR/test-no-reason.sh" << 'EOF'
#!/usr/bin/env bash
bash ./verify-deploy.sh
EOF
cat > "$CASE4_DIR/suite-classification.data" << 'EOF'
test-no-reason.sh	integration	-
EOF

case4_out="$(bash "$LINT_SCRIPT" --tests-dir "$CASE4_DIR" 2>&1)"
case4_rc=$?
if [[ $case4_rc -ne 0 ]]; then
  common_test_pass "missing-reason fixture: exits non-zero"
else
  common_test_fail "missing-reason fixture: exited 0 (expected non-zero):
$case4_out"
fi
if echo "$case4_out" | grep -q '\[VIOLATION\].*test-no-reason\.sh' && echo "$case4_out" | grep -qi 'no reason recorded'; then
  common_test_pass "missing-reason fixture: reports the missing-reason violation"
else
  common_test_fail "missing-reason fixture: violation not reported as expected:
$case4_out"
fi

# =====================================================================
# Case 5 (FAILING): an unrecognized class value.
# =====================================================================
common_test_info "=== FAILING: unrecognized class value ==="

CASE5_DIR="$WORKDIR/case5"
mkdir -p "$CASE5_DIR"
cat > "$CASE5_DIR/test-bad-class.sh" << 'EOF'
#!/usr/bin/env bash
echo "ok"
EOF
cat > "$CASE5_DIR/suite-classification.data" << 'EOF'
test-bad-class.sh	slow	-
EOF

case5_out="$(bash "$LINT_SCRIPT" --tests-dir "$CASE5_DIR" 2>&1)"
case5_rc=$?
if [[ $case5_rc -ne 0 ]]; then
  common_test_pass "unrecognized-class fixture: exits non-zero"
else
  common_test_fail "unrecognized-class fixture: exited 0 (expected non-zero):
$case5_out"
fi
if echo "$case5_out" | grep -q '\[VIOLATION\].*test-bad-class\.sh' && echo "$case5_out" | grep -qi "unrecognized class 'slow'"; then
  common_test_pass "unrecognized-class fixture: reports the unrecognized-class violation"
else
  common_test_fail "unrecognized-class fixture: violation not reported as expected:
$case5_out"
fi

# =====================================================================
# Case 6 (PASSING): a stale classification row (names a suite no longer on disk) is an INFO note,
# never a violation.
# =====================================================================
common_test_info "=== PASSING: stale classification row is INFO only, not a violation ==="

CASE6_DIR="$WORKDIR/case6"
mkdir -p "$CASE6_DIR"
cat > "$CASE6_DIR/test-still-here.sh" << 'EOF'
#!/usr/bin/env bash
echo "still here"
EOF
cat > "$CASE6_DIR/suite-classification.data" << 'EOF'
test-still-here.sh	unit	-
test-long-gone.sh	unit	-
EOF

case6_out="$(bash "$LINT_SCRIPT" --tests-dir "$CASE6_DIR" --verbose 2>&1)"
case6_rc=$?
if [[ $case6_rc -eq 0 ]]; then
  common_test_pass "stale-row fixture: exits 0 despite the stale row"
else
  common_test_fail "stale-row fixture: exited $case6_rc (expected 0):
$case6_out"
fi
if echo "$case6_out" | grep -q '\[INFO\].*1 stale classification row'; then
  common_test_pass "stale-row fixture: discloses the stale row count as INFO"
else
  common_test_fail "stale-row fixture: stale-row disclosure not reported as expected:
$case6_out"
fi

# =====================================================================
# Case 7 (environment error): a missing data file and a missing tests directory each exit 2.
# =====================================================================
common_test_info "=== ENV ERROR: missing data file / missing tests directory ==="

CASE7_DIR="$WORKDIR/case7"
mkdir -p "$CASE7_DIR"
cat > "$CASE7_DIR/test-whatever.sh" << 'EOF'
#!/usr/bin/env bash
echo "whatever"
EOF

case7a_rc=0
bash "$LINT_SCRIPT" --tests-dir "$CASE7_DIR" >/dev/null 2>&1 || case7a_rc=$?
if [[ $case7a_rc -eq 2 ]]; then
  common_test_pass "missing data file: exits 2"
else
  common_test_fail "missing data file: exited $case7a_rc (expected 2)"
fi

case7b_rc=0
bash "$LINT_SCRIPT" --tests-dir "$WORKDIR/does-not-exist" >/dev/null 2>&1 || case7b_rc=$?
if [[ $case7b_rc -eq 2 ]]; then
  common_test_pass "missing tests directory: exits 2"
else
  common_test_fail "missing tests directory: exited $case7b_rc (expected 2)"
fi

# =====================================================================
# Case 8 (PASSING, real corpus): the live suite-classification.data against the live
# core/scripts/tests/ directory reports zero violations -- the actual deliverable this phase's
# verification criteria require ("the lint reports zero findings over the live corpus after
# classification"). Skips gracefully (INFO, not a failure) when the real tree is unreachable,
# matching this corpus's own loud-skip-vs-silent-pass convention for an environment gap rather
# than a lint defect.
# =====================================================================
common_test_info "=== PASSING: live corpus reports zero violations ==="

LIVE_TESTS_DIR="$(dirname "$LINT_SCRIPT")/../tests"
if [[ -d "$LIVE_TESTS_DIR" ]] && [[ -f "$LIVE_TESTS_DIR/suite-classification.data" ]]; then
  live_out="$(bash "$LINT_SCRIPT" --tests-dir "$LIVE_TESTS_DIR" 2>&1)"
  live_rc=$?
  if [[ $live_rc -eq 0 ]]; then
    common_test_pass "live corpus: suite-classification.data reports zero violations"
  else
    common_test_fail "live corpus: unexpected violation(s) against the real tree:
$live_out"
  fi
else
  common_test_info "live corpus directory/data file not found next to $LINT_SCRIPT -- skipping live-corpus case"
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
