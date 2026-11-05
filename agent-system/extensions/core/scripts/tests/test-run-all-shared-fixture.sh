#!/usr/bin/env bash
# test-run-all-shared-fixture.sh - Regression suite for the corpus-consolidation
# task: run-all.sh's shared deployed-tree fixture, built once before any suite runs and lent
# READ-ONLY to every suite named in SHARED_FIXTURE_CONSUMERS, never reconstructed per suite.
#
# Pins three contracts that must never silently regress:
#   1. When a declared consumer suite is selected, the fixture is built exactly once (not once
#      per consumer) and the consuming suite can see it via RUN_ALL_SHARED_FIXTURE.
#   2. When NO declared consumer is selected, the fixture is NOT built at all -- the cost of an
#      unused fixture must never be paid by a run that has no use for it.
#   3. The lent fixture is genuinely read-only: a suite that attempts to write into it fails
#      loudly (the write itself is denied), never silently succeeding and corrupting a sibling
#      suite's view of the same tree.
#
# Structural model: test-run-all-failure-reporting.sh's synthetic-fixture-directory pattern (a
# minimal source-store-shaped tree under a mktemp WORKDIR, with the REAL run-all.sh copied in so
# its own SCRIPT_DIR/MODE resolution stays inside the fixture, never the real repo's own
# battery). deploy-headless.sh itself is replaced with a cheap stub here -- this suite proves
# run-all.sh's OWN build/lend/enforce mechanism, not deploy-headless.sh's real behavior (that is
# test-deploy-orphans.sh's and test-deploy-propagation.sh's job, against the real script).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUN_ALL_SRC="$CORE_DIR/tests/run-all.sh"

if [ ! -f "$RUN_ALL_SRC" ]; then
  echo "ERROR: expected $RUN_ALL_SRC" >&2
  exit 2
fi

PASSED=0
FAILED=0
common_test_workdir_init

EXT_ROOT="$WORKDIR/exts"
CORE_SCRIPTS="$EXT_ROOT/core/scripts"
TESTS_DIR="$CORE_SCRIPTS/tests"
mkdir -p "$TESTS_DIR"
echo '{}' > "$EXT_ROOT/core/manifest.json"
cp "$RUN_ALL_SRC" "$TESTS_DIR/run-all.sh"
chmod +x "$TESTS_DIR/run-all.sh"
FIXTURE_RUNNER="$TESTS_DIR/run-all.sh"

DEPLOY_LOG="$WORKDIR/deploy-call-log.txt"
: > "$DEPLOY_LOG"

# ── Stub deploy-headless.sh: never runs nvim or writes real content. Just proves WHETHER and
# HOW MANY TIMES it was invoked (via SFC_TEST_DEPLOY_LOG, exported below) and plants a cheap
# .claude/MARKER file so a consuming suite can tell it got a real tree. ─────────────────────
cat > "$CORE_SCRIPTS/deploy-headless.sh" << 'EOF'
#!/usr/bin/env bash
target=""
for a in "$@"; do
  case "$a" in
    --skip-verify|--dry-run|--wipe) : ;;
    *) target="$a" ;;
  esac
done
mkdir -p "$target/.claude"
echo "stub-deployed" > "$target/.claude/MARKER"
if [ -n "${SFC_TEST_DEPLOY_LOG:-}" ]; then
  echo "invoked" >> "$SFC_TEST_DEPLOY_LOG"
fi
exit 0
EOF
chmod +x "$CORE_SCRIPTS/deploy-headless.sh"

# ── Fixture suites ────────────────────────────────────────────────────────────────────────────
cat > "$TESTS_DIR/test-fixture-pass1.sh" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TESTS_DIR/test-fixture-pass1.sh"

# A stub named exactly "test-deploy-orphans.sh" -- matching run-all.sh's own hardcoded
# SHARED_FIXTURE_CONSUMERS basename, so this suite proves the REAL consumer-detection logic
# without needing to make that list overridable for testability.
#
# Evidence is written to SFC_TEST_EVIDENCE_LOG rather than echoed to stdout: run-all.sh only
# surfaces a suite's captured output when that suite FAILS (a PASSING suite's stdout is
# discarded after the [PASS] line), so a file is the only channel this outer test can read
# regardless of the stub's own exit code.
cat > "$TESTS_DIR/test-deploy-orphans.sh" << 'EOF'
#!/usr/bin/env bash
ok=true
log() { [ -n "${SFC_TEST_EVIDENCE_LOG:-}" ] && echo "$1" >> "$SFC_TEST_EVIDENCE_LOG"; }
if [ -n "${RUN_ALL_SHARED_FIXTURE:-}" ] && [ -f "$RUN_ALL_SHARED_FIXTURE/.claude/MARKER" ]; then
  log "CONSUMER_SAW_FIXTURE"
else
  log "CONSUMER_MISSING_FIXTURE"
  ok=false
fi
if [ -n "${RUN_ALL_SHARED_FIXTURE:-}" ]; then
  if echo mutated > "$RUN_ALL_SHARED_FIXTURE/.claude/MARKER" 2>/dev/null; then
    log "WRITE_SUCCEEDED_BAD"
    ok=false
  else
    log "WRITE_BLOCKED_GOOD"
  fi
fi
if $ok; then exit 0; else exit 1; fi
EOF
chmod +x "$TESTS_DIR/test-deploy-orphans.sh"

# =====================================================================================
# Case 1: a declared consumer (test-deploy-orphans.sh) is selected -- the fixture must be
# built exactly once, the consumer must see it, and a write attempt into it must be blocked.
# =====================================================================================
EVIDENCE_LOG="$WORKDIR/evidence-log.txt"
rm -f "$DEPLOY_LOG" "$EVIDENCE_LOG"; : > "$DEPLOY_LOG"; : > "$EVIDENCE_LOG"
OUT_1="$(cd "$TESTS_DIR" && SFC_TEST_DEPLOY_LOG="$DEPLOY_LOG" SFC_TEST_EVIDENCE_LOG="$EVIDENCE_LOG" bash "$FIXTURE_RUNNER" --only test-deploy-orphans.sh 2>&1)"
RC_1=$?
EVIDENCE_1="$(cat "$EVIDENCE_LOG" 2>/dev/null)"

if printf '%s\n' "$OUT_1" | grep -q 'Built shared deployed-tree fixture once'; then
  common_test_pass "Case 1: consumer selected -- run-all.sh reports building the shared fixture"
else
  common_test_fail "Case 1: expected a 'Built shared deployed-tree fixture once' line, got: $OUT_1"
fi

DEPLOY_CALLS_1=$(wc -l < "$DEPLOY_LOG" 2>/dev/null || echo 0)
if [ "$DEPLOY_CALLS_1" -eq 1 ]; then
  common_test_pass "Case 1: deploy-headless.sh invoked exactly once (built once, not per-consumer)"
else
  common_test_fail "Case 1: expected exactly 1 deploy-headless.sh invocation, saw $DEPLOY_CALLS_1"
fi

if printf '%s\n' "$EVIDENCE_1" | grep -q 'CONSUMER_SAW_FIXTURE'; then
  common_test_pass "Case 1: consumer suite observed RUN_ALL_SHARED_FIXTURE pointing at a real deployed tree"
else
  common_test_fail "Case 1: consumer suite did not see the shared fixture: evidence='$EVIDENCE_1' run-all output: $OUT_1"
fi

if printf '%s\n' "$EVIDENCE_1" | grep -q 'WRITE_BLOCKED_GOOD' && ! printf '%s\n' "$EVIDENCE_1" | grep -q 'WRITE_SUCCEEDED_BAD'; then
  common_test_pass "Case 1: a write attempt into the shared fixture was blocked (read-only lending enforced)"
else
  common_test_fail "Case 1: write-attempt enforcement did not fire as expected: evidence='$EVIDENCE_1'"
fi

if [ "$RC_1" -eq 0 ]; then
  common_test_pass "Case 1: run-all.sh reports overall PASS (consumer suite's own assertions all held)"
else
  common_test_fail "Case 1: run-all.sh reported a non-zero exit ($RC_1): $OUT_1"
fi

# =====================================================================================
# Case 2 (control): no declared consumer is selected -- the fixture must NOT be built, and
# deploy-headless.sh must never be invoked. Proves the mechanism costs nothing when unused.
# =====================================================================================
rm -f "$DEPLOY_LOG"; : > "$DEPLOY_LOG"
OUT_2="$(cd "$TESTS_DIR" && SFC_TEST_DEPLOY_LOG="$DEPLOY_LOG" bash "$FIXTURE_RUNNER" --only test-fixture-pass1.sh 2>&1)"
RC_2=$?

if printf '%s\n' "$OUT_2" | grep -q 'Built shared deployed-tree fixture'; then
  common_test_fail "Case 2: no consumer selected, but run-all.sh built the shared fixture anyway: $OUT_2"
else
  common_test_pass "Case 2: no consumer selected -- run-all.sh did not report building the shared fixture"
fi

DEPLOY_CALLS_2=$(wc -l < "$DEPLOY_LOG" 2>/dev/null || echo 0)
if [ "$DEPLOY_CALLS_2" -eq 0 ]; then
  common_test_pass "Case 2: deploy-headless.sh was never invoked (zero cost when no consumer is present)"
else
  common_test_fail "Case 2: expected 0 deploy-headless.sh invocations, saw $DEPLOY_CALLS_2"
fi

if [ "$RC_2" -eq 0 ]; then
  common_test_pass "Case 2: run-all.sh reports overall PASS"
else
  common_test_fail "Case 2: run-all.sh reported a non-zero exit ($RC_2): $OUT_2"
fi

echo ""
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -eq 0 ]; then
  exit 0
else
  exit 1
fi
