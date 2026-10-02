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

# This suite's own "unguarded" fixture invocations (cases 1, 2, 3, 5, 7) must genuinely exercise
# run-all.sh's unnested code path, including when THIS suite is itself discovered and launched by
# an outer run-all.sh (e.g. Gate 8 recursing into verify-deploy.sh, which can land back here).
# That outer runner unconditionally exports RUN_ALL_NESTED=1 (run-all.sh's nested-invocation
# guard) into every suite it launches, and an exported variable is inherited by every child
# process this script spawns -- including the plain `bash "$FIXTURE_RUNNER" ...` calls below that
# are deliberately NOT prefixed with RUN_ALL_NESTED=1. Left inherited, those calls silently run
# forced-sequential too, so case3's "genuinely concurrent" ratio assertion fails deterministically
# whenever this suite is nested, not just under ambient load. Clearing it once here (rather than
# an `env -u RUN_ALL_NESTED` prefix repeated at every unguarded call site) restores a clean
# unnested environment for this script and everything it spawns; the one deliberate exception is
# case4's explicit `RUN_ALL_NESTED=1 bash "$FIXTURE_RUNNER" ...` prefix below, which sets the
# variable only for that single command and is unaffected by this unset.
unset RUN_ALL_NESTED

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
# Cases 3+4 (combined, RELATIVE comparison -- not absolute-ms thresholds): --jobs 3 must be
# genuinely concurrent, and RUN_ALL_NESTED=1 must force it back to sequential.
#
# Absolute wall-clock thresholds (e.g. "parallel run must finish under 1300ms") were tried first
# and found NOT robust to genuine ambient host load: on a shared dev machine running other
# unrelated heavy processes (other editor/agent sessions, builds), BOTH the parallel and the
# forced-sequential run get proportionally slower, and an absolute threshold flakes even though
# the underlying concurrency behavior is completely correct. Confirmed empirically during this
# suite's own Phase 6 flakiness gate: case3's <1300ms threshold failed twice under real ambient
# load (parallel run measured ~1.9s both times) even though relative behavior -- parallel
# meaningfully faster than forced-sequential -- remained correct throughout. Serializing this
# suite out of run-all.sh's OWN parallel pool did NOT fix it, confirming the contention source is
# external to this run entirely, not sibling suites in the same pool -- an absolute-threshold
# design cannot be rescued by scheduling.
#
# The fix: measure both runs back-to-back (minimizing the window in which ambient load could
# differ between them) and assert a RATIO -- parallel_ms must be no more than 75% of nested_ms.
# An external load multiplier inflates both measurements roughly proportionally, so the ratio
# stays meaningful regardless of host load, while a genuine "parallelism is a no-op" regression
# (parallel_ms ~= nested_ms) still fails this ratio check reliably.
# =====================================================================
t0=$(date +%s%3N)
bash "$FIXTURE_RUNNER" --quiet --jobs 3 >/dev/null 2>&1
t1=$(date +%s%3N)
parallel_ms=$((t1 - t0))

t0=$(date +%s%3N)
RUN_ALL_NESTED=1 bash "$FIXTURE_RUNNER" --quiet --jobs 3 >/dev/null 2>&1
t1=$(date +%s%3N)
nested_ms=$((t1 - t0))

info "case3/4 timing: parallel=${parallel_ms}ms nested(forced-sequential)=${nested_ms}ms"

ratio_threshold_ms=$(( nested_ms * 75 / 100 ))
if [ "$parallel_ms" -le "$ratio_threshold_ms" ]; then
  pass "case3: --jobs 3 (${parallel_ms}ms) is genuinely concurrent -- <= 75% of the forced-sequential time (${nested_ms}ms)"
else
  fail "case3: --jobs 3 (${parallel_ms}ms) is not meaningfully faster than forced-sequential (${nested_ms}ms) -- parallelism may be a no-op"
fi

if [ "$nested_ms" -ge "$parallel_ms" ]; then
  pass "case4: RUN_ALL_NESTED=1 --jobs 3 (${nested_ms}ms) is not faster than unguarded --jobs 3 (${parallel_ms}ms) -- forced sequential, not parallel"
else
  fail "case4: RUN_ALL_NESTED=1 --jobs 3 (${nested_ms}ms) was FASTER than unguarded --jobs 3 (${parallel_ms}ms) -- the nested guard may not be forcing sequential execution"
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
