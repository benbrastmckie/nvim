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
DEPLOY_BASELINE_LIB="$CORE_DIR/lib/deploy-baseline-lib.sh"
if [ ! -f "$DEPLOY_BASELINE_LIB" ]; then
  echo "ERROR: expected $DEPLOY_BASELINE_LIB" >&2
  exit 2
fi
# shellcheck source=../lib/deploy-baseline-lib.sh
source "$DEPLOY_BASELINE_LIB"

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

# Non-vacuousness: adding a matching known-failures.txt row for case B's fixture must flip the
# outcome to non-blocking (exit 0, WARN-FINDING, zero FINDING gate8 lines) -- confirming case B's
# FAIL/FINDING assertions above are sensitive to fixture content, not vacuously true.
FX_B_NOVAC="$WORKDIR/case-b-novac"
mkdir -p "$FX_B_NOVAC"
cp -a "$FX_B/." "$FX_B_NOVAC/"
cat > "$(fixture_tests_dir "$FX_B_NOVAC")/known-failures.txt" << 'EOF'
test-fail-new.sh|real-defect|deliberate fixture classification|test-owner
EOF
case_b_novac_rc=0
case_b_novac_out="$(run_gate8 "$FX_B_NOVAC")" || case_b_novac_rc=$?
if [ "$case_b_novac_rc" -eq 0 ]; then
  common_test_pass "non-vacuousness/case B: adding a matching known-failures.txt row flips the outcome to exit 0"
else
  common_test_fail "non-vacuousness/case B: expected exit 0 once the fixture is manifest-listed, got $case_b_novac_rc" "$case_b_novac_out"
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

# Non-vacuousness: injecting an unlisted (NEW) failure into the clean fixture must make the
# [PASS] assertion above fail -- confirming it is sensitive to fixture content, not vacuously
# true regardless of what the fixture contains.
FX_C_NOVAC="$WORKDIR/case-c-novac"
mkdir -p "$FX_C_NOVAC"
cp -a "$FX_C/." "$FX_C_NOVAC/"
cat > "$(fixture_tests_dir "$FX_C_NOVAC")/test-fail-injected.sh" << 'EOF'
#!/usr/bin/env bash
echo "deliberately injected failure (non-vacuousness probe)"
exit 1
EOF
chmod +x "$(fixture_tests_dir "$FX_C_NOVAC")/test-fail-injected.sh"
case_c_novac_out="$(run_gate8 "$FX_C_NOVAC")"
if printf '%s\n' "$case_c_novac_out" | grep -q 'run-all\.sh: all discovered suites passed'; then
  common_test_fail "non-vacuousness/case C: injecting a failure unexpectedly left the clean-case [PASS] message intact" "$case_c_novac_out"
else
  common_test_pass "non-vacuousness/case C: injecting an unlisted failure flips the clean-case [PASS] assertion (message no longer present)"
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

# =====================================================================
# Consumer: deploy_findings_snapshot (scripts/lib/deploy-baseline-lib.sh) -- the function
# orchestrate-batch-gate.sh's pre/post comparison is built on. deploy_findings_snapshot's own
# `grep '^FINDING '` filter is strict-prefix -- it does not match `WARN-FINDING `, so Case A's
# all-expected outcome must contribute zero gate8 rows to the snapshot.
# =====================================================================
snapshot_a_1="$(deploy_findings_snapshot "$VERIFY_DEPLOY" --only-gate 8 "$FX_A")"
if printf '%s\n' "$snapshot_a_1" | grep -q '^FINDING gate8 '; then
  common_test_fail "consumer/deploy_findings_snapshot: case A unexpectedly produced a ^FINDING gate8 row" "$snapshot_a_1"
else
  common_test_pass "consumer/deploy_findings_snapshot: case A (all-expected) produces zero ^FINDING gate8 rows"
fi

# =====================================================================
# Pre/post baseline skew: two successive deploy_findings_snapshot captures over the SAME
# unchanged Case A fixture must both show zero gate8 rows -- the all-expected outcome can never
# appear in one capture and not the other, because it never appears in either. This is the
# dispatch's own pre/post baseline-skew question, answered by construction and confirmed by two
# observed captures rather than asserted on reasoning alone.
# =====================================================================
snapshot_a_2="$(deploy_findings_snapshot "$VERIFY_DEPLOY" --only-gate 8 "$FX_A")"
snapshot_a_1_gate8="$(printf '%s\n' "$snapshot_a_1" | grep '^FINDING gate8 ' || true)"
snapshot_a_2_gate8="$(printf '%s\n' "$snapshot_a_2" | grep '^FINDING gate8 ' || true)"
if [ -z "$snapshot_a_1_gate8" ] && [ -z "$snapshot_a_2_gate8" ]; then
  common_test_pass "baseline-skew: two successive captures over case A both show zero gate8 rows (cannot skew pre/post)"
else
  common_test_fail "baseline-skew: expected zero gate8 rows in both captures" "capture1:[$snapshot_a_1_gate8] capture2:[$snapshot_a_2_gate8]"
fi

# =====================================================================
# Non-vacuousness for the two probes immediately above: removing case A's known-failures.txt row
# reclassifies the failure as NEW, which must flip both probes to blocking (a ^FINDING gate8 row
# appears). Confirms the assertions above are not vacuously true regardless of fixture content.
# =====================================================================
FX_A_NOVAC="$WORKDIR/case-a-novac"
mkdir -p "$FX_A_NOVAC"
cp -a "$FX_A/." "$FX_A_NOVAC/"
rm -f "$(fixture_tests_dir "$FX_A_NOVAC")/known-failures.txt"
snapshot_a_novac="$(deploy_findings_snapshot "$VERIFY_DEPLOY" --only-gate 8 "$FX_A_NOVAC")"
if printf '%s\n' "$snapshot_a_novac" | grep -q '^FINDING gate8 '; then
  common_test_pass "non-vacuousness/case A: removing known-failures.txt's row flips the snapshot to a blocking ^FINDING gate8 row"
else
  common_test_fail "non-vacuousness/case A: expected a ^FINDING gate8 row once the matching manifest row is removed" "$snapshot_a_novac"
fi

# =====================================================================
# Consumer: deploy_findings_snapshot over Case D (mixed) -- attribution still functions. The
# accepted mixed-failure residual (Decisions: the unchanged fail()-branch extraction folds every
# failing suite's line into FINDINGS_LIST, EXPECTED ones included) means the EXPECTED suite's
# line may also appear; the assertion here is that the NEW suite's line is present, not that it
# is the ONLY line.
# =====================================================================
snapshot_d="$(deploy_findings_snapshot "$VERIFY_DEPLOY" --only-gate 8 "$FX_D")"
if printf '%s\n' "$snapshot_d" | grep -q 'test-fail-mixed-new\.sh'; then
  common_test_pass "consumer/deploy_findings_snapshot: case D's NEW suite is attributed in the snapshot"
else
  common_test_fail "consumer/deploy_findings_snapshot: expected the NEW fixture suite to appear in the snapshot" "$snapshot_d"
fi

# Non-vacuousness: classifying BOTH case D fixtures as EXPECTED must drop the snapshot to zero
# gate8 rows, proving the prior assertion was sensitive to the manifest content, not vacuous.
FX_D_NOVAC="$WORKDIR/case-d-novac"
mkdir -p "$FX_D_NOVAC"
cp -a "$FX_D/." "$FX_D_NOVAC/"
cat > "$(fixture_tests_dir "$FX_D_NOVAC")/known-failures.txt" << 'EOF'
test-fail-mixed-expected.sh|real-defect|deliberate fixture classification|test-owner
test-fail-mixed-new.sh|real-defect|deliberate fixture classification|test-owner
EOF
snapshot_d_novac="$(deploy_findings_snapshot "$VERIFY_DEPLOY" --only-gate 8 "$FX_D_NOVAC")"
if printf '%s\n' "$snapshot_d_novac" | grep -q '^FINDING gate8 '; then
  common_test_fail "non-vacuousness/case D: expected zero gate8 rows once both fixtures are manifest-listed" "$snapshot_d_novac"
else
  common_test_pass "non-vacuousness/case D: classifying both fixtures as EXPECTED drops the snapshot to zero gate8 rows"
fi

# =====================================================================
# Consumer: --skip-unchanged gate cache (gate 8 is in CACHEABLE_GATES per
# test-gate-cache-equivalence.sh) -- an all-expected run must stay cache-write-INELIGIBLE,
# matching today's fail()-path invalidation behavior exactly. warn_advisory() appends to
# GATE_DIRTY_LIST, so a second --skip-unchanged run must still execute the real check (the
# [WARN] narrative reappears) rather than short-circuiting via a [SKIP-CACHED] line.
# =====================================================================
cache_run1="$(bash "$VERIFY_DEPLOY" --skip-unchanged --only-gate 8 "$FX_A" 2>&1)"
cache_run2="$(bash "$VERIFY_DEPLOY" --skip-unchanged --only-gate 8 "$FX_A" 2>&1)"
if printf '%s\n' "$cache_run2" | grep -q '\[SKIP-CACHED\] gate8'; then
  common_test_fail "consumer/skip-unchanged cache: case A unexpectedly became cache-write-eligible (gate8 was [SKIP-CACHED] on the second run)" "$cache_run2"
else
  common_test_pass "consumer/skip-unchanged cache: case A stays cache-write-ineligible (no [SKIP-CACHED] gate8 on the second run)"
fi
if printf '%s\n' "$cache_run2" | grep -q '\[WARN\]'; then
  common_test_pass "consumer/skip-unchanged cache: the second run still executed the real check ([WARN] narrative reappeared)"
else
  common_test_fail "consumer/skip-unchanged cache: expected the second run to still execute the real check" "$cache_run1 / $cache_run2"
fi

# =====================================================================
# Consumer: zero-check-under-filter -- a --only-gate 8 selection over an all-expected case A run
# must count ONE check (warn_advisory() increments CHECKS) and exit 0, never the "the run
# attested to nothing" exit-2 branch a gate that registers zero checks would trip.
# =====================================================================
checkcount_out="$(run_gate8 "$FX_A")"
checkcount_rc=$?
if [ "$checkcount_rc" -eq 0 ] && printf '%s\n' "$checkcount_out" | grep -q 'PASS -- 1 check(s), 0 failure(s)'; then
  common_test_pass "consumer/zero-check-under-filter: --only-gate 8 over case A counts 1 check and exits 0"
else
  common_test_fail "consumer/zero-check-under-filter: expected 'PASS -- 1 check(s), 0 failure(s)' and exit 0, got rc=$checkcount_rc" "$checkcount_out"
fi

echo ""
echo "==================================================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "==================================================================="

[ "$FAILED" -eq 0 ] && exit 0 || exit 1
