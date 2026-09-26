#!/usr/bin/env bash
# test-run-all-parallel.sh - Regression suite for run-all.sh's --jobs N parallel-pool flag: the
# --jobs 1 (default) behavior-preservation contract, count/[FAIL]-set parity under --jobs N,
# genuine wall-clock concurrency, and the RUN_ALL_NESTED=1 nested-invocation guard.
#
# Structural model: test-verify-deploy-context-budget.sh (pass()/fail()/info() helpers, PASSED/
# FAILED counters, mktemp WORKDIR with trap EXIT cleanup). Runs against a SYNTHETIC, tiny fixture
# (a handful of fake test-*.sh suites under a minimal source-store-shaped tree), never the real
# 96-suite battery -- this suite must itself be fast and deterministic.
#
# Fixture shape: $WORKDIR/exts/core/manifest.json (source-store detection anchor) plus
# $WORKDIR/exts/core/scripts/tests/{run-all.sh copy, test-*.sh fixture suites}. The REAL run-all.sh
# under test is copied into the fixture (not symlinked) so its own SCRIPT_DIR resolution walks the
# fixture tree, not the real repo -- this suite never touches the real repo's 96 suites.
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

# ── Fake suites: 2 quick passes, 1 quick fail, 1 non-executable (SKIP), 3 suites that each sleep
# ~0.6s (for the concurrency-timing case) ──────────────────────────────────────────────────────
cat > "$TESTS_DIR/test-fixture-pass1.sh" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$TESTS_DIR/test-fixture-pass2.sh" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$TESTS_DIR/test-fixture-fail1.sh" << 'EOF'
#!/usr/bin/env bash
echo "deliberate fixture failure"
exit 1
EOF
cat > "$TESTS_DIR/test-fixture-noexec.sh" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TESTS_DIR/test-fixture-pass1.sh" "$TESTS_DIR/test-fixture-pass2.sh" "$TESTS_DIR/test-fixture-fail1.sh"
chmod -x "$TESTS_DIR/test-fixture-noexec.sh"

for n in a b c; do
  cat > "$TESTS_DIR/test-fixture-slow-$n.sh" << 'EOF'
#!/usr/bin/env bash
sleep 0.6
exit 0
EOF
  chmod +x "$TESTS_DIR/test-fixture-slow-$n.sh"
done
# 2 quick pass + 1 quick fail + 1 non-executable (SKIP) + 3 slow = 7 discovered fixture suites total.
FIXTURE_TOTAL=7

# =====================================================================
# Case 1: --jobs 1 (explicit) and no --jobs at all (implicit default) produce byte-identical
# output -- confirms the default is genuinely --jobs 1, not something else.
# =====================================================================
default_out="$(bash "$FIXTURE_RUNNER" --quiet 2>&1)"
explicit1_out="$(bash "$FIXTURE_RUNNER" --quiet --jobs 1 2>&1)"
if [ "$default_out" = "$explicit1_out" ]; then
  pass "case1: no --jobs and --jobs 1 produce byte-identical output"
else
  fail "case1: no --jobs and --jobs 1 differ" "$(diff <(echo "$default_out") <(echo "$explicit1_out"))"
fi

# =====================================================================
# Case 2: --jobs N discovers and runs the same suite set as --jobs 1 (count assertion + [FAIL]
# set parity).
# =====================================================================
jobs3_out="$(bash "$FIXTURE_RUNNER" --quiet --jobs 3 2>&1)"
default_summary="$(printf '%s\n' "$default_out" | grep '^\[run-all\] ')"
jobs3_summary="$(printf '%s\n' "$jobs3_out" | grep '^\[run-all\] ')"
if [ "$default_summary" = "$jobs3_summary" ]; then
  pass "case2: --jobs 3 summary line matches --jobs 1 ($default_summary)"
else
  fail "case2: --jobs 3 summary differs from --jobs 1" "1: $default_summary
3: $jobs3_summary"
fi
default_fails="$(printf '%s\n' "$default_out" | grep '^\[FAIL\] ' | xargs -n1 basename 2>/dev/null | sort)"
jobs3_fails="$(printf '%s\n' "$jobs3_out" | grep '^\[FAIL\] ' | xargs -n1 basename 2>/dev/null | sort)"
if [ "$default_fails" = "$jobs3_fails" ]; then
  pass "case2: --jobs 3 [FAIL] set matches --jobs 1"
else
  fail "case2: --jobs 3 [FAIL] set differs from --jobs 1" "1: $default_fails
3: $jobs3_fails"
fi
if printf '%s\n' "$jobs3_summary" | grep -q "7 total"; then
  pass "case2: --jobs 3 discovers all $FIXTURE_TOTAL fixture suites"
else
  fail "case2: --jobs 3 did not discover all $FIXTURE_TOTAL fixture suites" "$jobs3_summary"
fi

# =====================================================================
# Case 3: --jobs 3 is genuinely concurrent -- 3 suites each sleeping ~0.6s should finish in well
# under the ~1.8s+ sequential floor. Generous threshold (1.3s) to absorb CI/host scheduling noise
# without being so loose it would pass even if parallelism were silently a no-op.
# =====================================================================
t0=$(date +%s%3N)
bash "$FIXTURE_RUNNER" --quiet --jobs 3 >/dev/null 2>&1
t1=$(date +%s%3N)
parallel_ms=$((t1 - t0))
if [ "$parallel_ms" -lt 1300 ]; then
  pass "case3: --jobs 3 completes in ${parallel_ms}ms (< 1300ms threshold -- genuinely concurrent)"
else
  fail "case3: --jobs 3 took ${parallel_ms}ms (>= 1300ms threshold -- parallelism may be a no-op)"
fi

# =====================================================================
# Case 4: the RUN_ALL_NESTED=1 guard forces sequential execution even when --jobs 3 is requested
# -- must take close to the sequential floor (>= 1700ms for 3x 0.6s slow suites), not the parallel
# time from case 3.
# =====================================================================
t0=$(date +%s%3N)
RUN_ALL_NESTED=1 bash "$FIXTURE_RUNNER" --quiet --jobs 3 >/dev/null 2>&1
t1=$(date +%s%3N)
nested_ms=$((t1 - t0))
if [ "$nested_ms" -ge 1700 ]; then
  pass "case4: RUN_ALL_NESTED=1 --jobs 3 takes ${nested_ms}ms (>= 1700ms -- forced sequential, not parallel)"
else
  fail "case4: RUN_ALL_NESTED=1 --jobs 3 took only ${nested_ms}ms -- the nested guard may not be forcing sequential execution"
fi

# =====================================================================
# Case 5: --jobs auto resolves without error (exact job count is host-dependent; the resolution
# logic itself -- nproc capped at 4 -- is exercised in isolation by this case's own exit-code
# check, not by inspecting the chosen count).
# =====================================================================
auto_out="$(bash "$FIXTURE_RUNNER" --quiet --jobs auto 2>&1)"
auto_rc=$?
if [ "$auto_rc" -eq 1 ] && printf '%s\n' "$auto_out" | grep -q "7 total"; then
  pass "case5: --jobs auto runs to completion and discovers all $FIXTURE_TOTAL fixture suites"
else
  fail "case5: --jobs auto did not complete cleanly (rc=$auto_rc)" "$auto_out"
fi

# =====================================================================
# Case 6: invalid --jobs values exit 2 with a named error.
# =====================================================================
invalid_jobs_ok=true
for bad in "abc" "0" "-1"; do
  bad_out="$(bash "$FIXTURE_RUNNER" --jobs "$bad" 2>&1)"
  bad_rc=$?
  if [ "$bad_rc" -ne 2 ] || ! printf '%s\n' "$bad_out" | grep -q "ERROR: --jobs:"; then
    fail "case6: --jobs $bad expected exit 2 with a named error, got rc=$bad_rc: $bad_out"
    invalid_jobs_ok=false
  fi
done
[ "$invalid_jobs_ok" = "true" ] && pass "case6: invalid --jobs values (abc, 0, -1) all exit 2 with a named error"

# =====================================================================
# Case 7: deleting suite-cost-hints.txt (never created in this fixture to begin with) still runs
# every discovered suite -- the hint file is purely advisory.
# =====================================================================
if [ ! -f "$TESTS_DIR/suite-cost-hints.txt" ]; then
  no_hints_out="$(bash "$FIXTURE_RUNNER" --quiet --jobs 3 2>&1)"
  if printf '%s\n' "$no_hints_out" | grep -q "7 total"; then
    pass "case7: with no suite-cost-hints.txt present, --jobs 3 still discovers/runs all $FIXTURE_TOTAL suites"
  else
    fail "case7: missing suite-cost-hints.txt affected the discovered/run count" "$no_hints_out"
  fi
else
  fail "case7: test setup error -- suite-cost-hints.txt unexpectedly exists in the fixture"
fi

echo ""
echo "==================================================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "==================================================================="

[ "$FAILED" -eq 0 ] && exit 0 || exit 1
