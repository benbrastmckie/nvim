#!/usr/bin/env bash
# test-gate8-expected-new-distinction.sh - Regression suite for verify-deploy.sh's Gate 8
# expected-versus-NEW failure distinction: gate8_run() passes --fail-on-new to run-all.sh and
# branches three ways (pass/warn_advisory/fail) on the child's own EXPECTED/NEW accounting,
# instead of collapsing any non-zero run-all.sh exit into a blocking fail().
#
# Structural model: test-run-all-failure-reporting.sh's synthetic-fixture-directory pattern (a
# minimal source-store-shaped tree under a mktemp WORKDIR, with the REAL run-all.sh copied in)
# combined with test-verify-deploy-gate-selection.sh's fixture-target invocation pattern (the
# SOURCE-STORE copy of verify-deploy.sh invoked directly against a fixture TARGET, with
# --only-gate 8 so no other gate runs and the real repository corpus is never reached --
# the same ANTI-RECURSION INVARIANT test-deploy-verify-wiring.sh and
# test-verify-deploy-gate-selection.sh document for themselves).
#
# Each fixture's .claude/ is a minimal hand-built directory (gate0 only requires it to EXIST)
# that deliberately OMITS .claude/scripts/task-lock.sh: Gate 8's specs/.gate-lock acquisition
# path treats a missing deployed task-lock.sh as fail-open (a Note, not a failure), so this
# suite's fixture runs never contend for the real repository's specs/.gate-lock mutex.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUN_ALL_SRC="$CORE_DIR/tests/run-all.sh"
VERIFY_DEPLOY="$CORE_DIR/verify-deploy.sh"

if [ ! -f "$RUN_ALL_SRC" ]; then
  echo "ERROR: expected $RUN_ALL_SRC" >&2
  exit 2
fi
if [ ! -f "$VERIFY_DEPLOY" ]; then
  echo "ERROR: expected $VERIFY_DEPLOY" >&2
  exit 2
fi

PASSED=0
FAILED=0
common_test_workdir_init

# build_fixture <fixture_dir> -- a minimal Gate-8-reachable fixture: .claude/ exists (gate0's
# only requirement) but deliberately has no scripts/task-lock.sh (fail-open mutex path);
# agent-system/extensions/core/ exists with manifest.json and a copy of the real run-all.sh in
# scripts/tests/, so Gate 8's own source-store/run-all.sh-presence checks both pass.
build_fixture() {
  local fx="$1"
  mkdir -p "$fx/.claude/scripts"
  mkdir -p "$fx/agent-system/extensions/core/scripts/tests"
  echo '{}' > "$fx/agent-system/extensions/core/manifest.json"
  cp "$RUN_ALL_SRC" "$fx/agent-system/extensions/core/scripts/tests/run-all.sh"
  chmod +x "$fx/agent-system/extensions/core/scripts/tests/run-all.sh"
}

# fixture_tests_dir <fixture_dir> -- echoes the fixture's own scripts/tests/ directory, the
# location both the copied run-all.sh and its sibling fixture suites/known-failures.txt live in.
fixture_tests_dir() {
  echo "$1/agent-system/extensions/core/scripts/tests"
}

run_gate8() {
  # Usage: run_gate8 <fixture_dir> [extra verify-deploy.sh args...]
  # Deliberately never passes --skip-slow -- that would defer gate 8 entirely rather than run
  # it. --only-gate 8 alone is sufficient to keep every other gate from running.
  local fx="$1"; shift
  bash "$VERIFY_DEPLOY" --only-gate 8 "$@" "$fx" 2>&1
}

# =====================================================================
# Case A (all-expected): one failing fixture suite, classified EXPECTED by a fixture-local
# known-failures.txt. Gate 8 must exit 0, emit a [WARN] narrative, and -- under --findings --
# emit a WARN-FINDING gate8 line and zero ^FINDING gate8 lines.
# =====================================================================
FX_A="$WORKDIR/case-a"
build_fixture "$FX_A"
TD_A="$(fixture_tests_dir "$FX_A")"
cat > "$TD_A/test-fail-expected.sh" << 'EOF'
#!/usr/bin/env bash
echo "deliberate fixture failure (expected)"
exit 1
EOF
chmod +x "$TD_A/test-fail-expected.sh"
cat > "$TD_A/known-failures.txt" << 'EOF'
test-fail-expected.sh|real-defect|deliberate fixture classification|test-owner
EOF

case_a_plain="$(run_gate8 "$FX_A")"
case_a_rc=$?
if [ "$case_a_rc" -eq 0 ]; then
  common_test_pass "case A (all-expected): exit 0"
else
  common_test_fail "case A (all-expected): expected exit 0, got $case_a_rc" "$case_a_plain"
fi
if printf '%s\n' "$case_a_plain" | grep -q '\[WARN\]'; then
  common_test_pass "case A (all-expected): [WARN] narrative present"
else
  common_test_fail "case A (all-expected): expected a [WARN] narrative" "$case_a_plain"
fi

case_a_findings="$(run_gate8 "$FX_A" --findings)"
if printf '%s\n' "$case_a_findings" | grep -q '^WARN-FINDING gate8 '; then
  common_test_pass "case A (all-expected): emits a WARN-FINDING gate8 line under --findings"
else
  common_test_fail "case A (all-expected): expected a WARN-FINDING gate8 line" "$case_a_findings"
fi
if printf '%s\n' "$case_a_findings" | grep -q '^FINDING gate8 '; then
  common_test_fail "case A (all-expected): unexpectedly emitted a ^FINDING gate8 line" "$case_a_findings"
else
  common_test_pass "case A (all-expected): zero ^FINDING gate8 lines"
fi

# =====================================================================
# Case B (genuinely-NEW): the same shape of failing fixture suite, but with no known-failures.txt
# row naming it. Gate 8 must fail, emit a [FAIL] narrative, and emit at least one ^FINDING gate8
# line naming the fixture.
# =====================================================================
FX_B="$WORKDIR/case-b"
build_fixture "$FX_B"
TD_B="$(fixture_tests_dir "$FX_B")"
cat > "$TD_B/test-fail-new.sh" << 'EOF'
#!/usr/bin/env bash
echo "deliberate fixture failure (new)"
exit 1
EOF
chmod +x "$TD_B/test-fail-new.sh"

case_b_plain="$(run_gate8 "$FX_B")"
case_b_rc=$?
if [ "$case_b_rc" -ne 0 ]; then
  common_test_pass "case B (genuinely-NEW): non-zero exit"
else
  common_test_fail "case B (genuinely-NEW): expected non-zero exit, got 0" "$case_b_plain"
fi
if printf '%s\n' "$case_b_plain" | grep -q '\[FAIL\]'; then
  common_test_pass "case B (genuinely-NEW): [FAIL] narrative present"
else
  common_test_fail "case B (genuinely-NEW): expected a [FAIL] narrative" "$case_b_plain"
fi

case_b_findings="$(run_gate8 "$FX_B" --findings)"
if printf '%s\n' "$case_b_findings" | grep -q '^FINDING gate8 '; then
  common_test_pass "case B (genuinely-NEW): emits at least one ^FINDING gate8 line"
else
  common_test_fail "case B (genuinely-NEW): expected at least one ^FINDING gate8 line" "$case_b_findings"
fi

# =====================================================================
# Case C (clean): every fixture suite passes, no roster header emitted. Gate 8 must exit 0 and
# emit a [PASS] narrative -- confirming the all-expected branch did not swallow the clean case.
# =====================================================================
FX_C="$WORKDIR/case-c"
build_fixture "$FX_C"
TD_C="$(fixture_tests_dir "$FX_C")"
for n in 1 2 3; do
  cat > "$TD_C/test-pass$n.sh" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$TD_C/test-pass$n.sh"
done

case_c_out="$(run_gate8 "$FX_C")"
case_c_rc=$?
if [ "$case_c_rc" -eq 0 ]; then
  common_test_pass "case C (clean): exit 0"
else
  common_test_fail "case C (clean): expected exit 0, got $case_c_rc" "$case_c_out"
fi
if printf '%s\n' "$case_c_out" | grep -q '\[PASS\]'; then
  common_test_pass "case C (clean): [PASS] narrative present"
else
  common_test_fail "case C (clean): expected a [PASS] narrative" "$case_c_out"
fi
if printf '%s\n' "$case_c_out" | grep -q '\[WARN\]'; then
  common_test_fail "case C (clean): unexpectedly emitted a [WARN] narrative" "$case_c_out"
else
  common_test_pass "case C (clean): no [WARN] narrative"
fi

# =====================================================================
# Case D (mixed): two failing fixture suites, one manifest-listed (EXPECTED) and one not (NEW).
# Gate 8 must fail and emit at least one ^FINDING gate8 line -- the behavior Phase 3's
# consumer-level assertions re-verify for attribution.
# =====================================================================
FX_D="$WORKDIR/case-d"
build_fixture "$FX_D"
TD_D="$(fixture_tests_dir "$FX_D")"
cat > "$TD_D/test-fail-mixed-expected.sh" << 'EOF'
#!/usr/bin/env bash
echo "deliberate fixture failure (mixed, expected)"
exit 1
EOF
cat > "$TD_D/test-fail-mixed-new.sh" << 'EOF'
#!/usr/bin/env bash
echo "deliberate fixture failure (mixed, new)"
exit 1
EOF
chmod +x "$TD_D/test-fail-mixed-expected.sh" "$TD_D/test-fail-mixed-new.sh"
cat > "$TD_D/known-failures.txt" << 'EOF'
test-fail-mixed-expected.sh|real-defect|deliberate fixture classification|test-owner
EOF

case_d_out="$(run_gate8 "$FX_D")"
case_d_rc=$?
if [ "$case_d_rc" -ne 0 ]; then
  common_test_pass "case D (mixed): non-zero exit"
else
  common_test_fail "case D (mixed): expected non-zero exit, got 0" "$case_d_out"
fi

case_d_findings="$(run_gate8 "$FX_D" --findings)"
if printf '%s\n' "$case_d_findings" | grep -q '^FINDING gate8 '; then
  common_test_pass "case D (mixed): emits at least one ^FINDING gate8 line"
else
  common_test_fail "case D (mixed): expected at least one ^FINDING gate8 line" "$case_d_findings"
fi

echo ""
echo "==================================================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "==================================================================="

[ "$FAILED" -eq 0 ] && exit 0 || exit 1
