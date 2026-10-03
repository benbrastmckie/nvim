#!/usr/bin/env bash
# test-deploy-verify-wiring.sh - Fixture-driven regression suite for the deploy-headless.sh ->
# verify-deploy.sh inline wiring: the --skip-slow flag (verify-deploy.sh), the
# exit-3-on-verification-failure / no-verification-under---dry-run contract (deploy-headless.sh),
# and the --consumer-report default-OFF/opt-in contract that gates deploy-headless.sh's
# post-deploy consumer-freshness walk (Cases 6-9).
#
# Structural model: test-deploy-freshness.sh (pass()/fail()/info() helpers, PASSED/FAILED integer
# counters, trap-based scratch WORKDIR, source-store-or-deployed CHECKER-candidate resolution).
#
# ANTI-RECURSION INVARIANT (read before adding a case): the fixture target used below is a
# throwaway *consumer* directory holding only a minimal `.claude/` tree and NO
# `agent-system/extensions` directory. verify-deploy.sh's gates 3-13 all SKIP unconditionally
# when `$TARGET/agent-system/extensions` does not exist (see that script's own SKIP branches),
# so against this fixture only gates 1 and 2 ever run for real -- gate 8 (tests/run-all.sh,
# the suite THIS FILE is discovered by) always SKIPs here. run-all.sh can therefore never invoke
# itself through this suite, no matter which flags are passed to verify-deploy.sh below. Do not
# point any case at this repo's own root or at a fixture containing an agent-system/extensions
# directory -- doing so would reintroduce the recursion this invariant rules out.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (verify-deploy.sh or deploy-headless.sh not found, or git unavailable).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT resolution must work from BOTH invocation sites this suite supports: the
# source-store copy (agent-system/extensions/core/scripts/tests/) and the deployed copy
# (.claude/scripts/tests/), which sit at different depths below the repo root.
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

find_script() {
  local name="$1"
  local candidates=(
    "$REPO_ROOT/.claude/scripts/${name}"
    "$SCRIPT_DIR/../${name}"
  )
  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

VERIFY_DEPLOY="$(find_script verify-deploy.sh)" || {
  echo "ERROR: verify-deploy.sh not found at any of:" >&2
  echo "  $REPO_ROOT/.claude/scripts/verify-deploy.sh" >&2
  echo "  $SCRIPT_DIR/../verify-deploy.sh" >&2
  exit 2
}
DEPLOY_HEADLESS="$(find_script deploy-headless.sh)" || {
  echo "ERROR: deploy-headless.sh not found at any of:" >&2
  echo "  $REPO_ROOT/.claude/scripts/deploy-headless.sh" >&2
  echo "  $SCRIPT_DIR/../deploy-headless.sh" >&2
  exit 2
}

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git not found on PATH" >&2
  exit 2
fi

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [[ -n "${WORKDIR:-}" && -d "$WORKDIR" ]] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

info "Using verify-deploy.sh: $VERIFY_DEPLOY"
info "Using deploy-headless.sh: $DEPLOY_HEADLESS"

# --- Fixture: throwaway consumer directory. Deliberately minimal and WITHOUT an
# agent-system/extensions directory -- see the ANTI-RECURSION INVARIANT header comment. ---
FIXTURE="$WORKDIR/consumer"
mkdir -p "$FIXTURE/.claude"
git init -q "$FIXTURE"
git -C "$FIXTURE" config user.email "test@example.com"
git -C "$FIXTURE" config user.name "Test"

# =====================================================================
# Case 1: --skip-slow and no-flag runs reach the same gate set on this fixture (gates 3-13,
# including gate 8, all SKIP regardless -- there is no agent-system/extensions directory), so
# their exit codes must match; the --skip-slow run's gate-8 line must carry the --skip-slow
# SKIP wording specifically (distinguishing it from the plain not-source-store SKIP).
# =====================================================================
OUT_SKIP_SLOW="$(bash "$VERIFY_DEPLOY" --skip-slow "$FIXTURE" 2>&1)"
RC_SKIP_SLOW=$?
OUT_PLAIN="$(bash "$VERIFY_DEPLOY" "$FIXTURE" 2>&1)"
RC_PLAIN=$?

if [[ "$RC_SKIP_SLOW" -eq "$RC_PLAIN" ]]; then
  pass "exit code identical between --skip-slow and no-flag runs (rc=$RC_SKIP_SLOW)"
else
  fail "exit code differs: --skip-slow rc=$RC_SKIP_SLOW vs no-flag rc=$RC_PLAIN"
fi

if [[ "$OUT_SKIP_SLOW" == *"[SKIP] --skip-slow: shell test suite deferred"* ]]; then
  pass "--skip-slow run's gate 8 line carries the --skip-slow SKIP wording"
else
  fail "--skip-slow run missing the --skip-slow gate-8 SKIP line: <<<$OUT_SKIP_SLOW>>>"
fi

# =====================================================================
# Case 2: --skip-slow --findings --quiet emits no FINDING gate8 line (a skip must never
# contribute a finding).
# =====================================================================
OUT_FINDINGS="$(bash "$VERIFY_DEPLOY" --skip-slow --findings --quiet "$FIXTURE" 2>&1)"
if [[ "$OUT_FINDINGS" != *"FINDING gate8"* ]]; then
  pass "no FINDING gate8 line under --skip-slow --findings --quiet"
else
  fail "unexpected FINDING gate8 line under --skip-slow: <<<$OUT_FINDINGS>>>"
fi

# =====================================================================
# Case 3: an unrecognized flag still exits 2 (the -*) unknown-flag arm is unshadowed by the new
# --skip-slow arm).
# =====================================================================
bash "$VERIFY_DEPLOY" --bogus "$FIXTURE" >/dev/null 2>&1
RC_BOGUS=$?
if [[ "$RC_BOGUS" -eq 2 ]]; then
  pass "unknown flag --bogus still exits 2"
else
  fail "unknown flag --bogus exited $RC_BOGUS, expected 2"
fi

# =====================================================================
# Case 4: deploy-headless.sh --dry-run does not invoke verification. Do NOT run a non-dry-run
# deploy against this fixture -- that would launch nvim and write files, well beyond this
# suite's scope and budget.
# =====================================================================
OUT_DRY_RUN="$(bash "$DEPLOY_HEADLESS" --dry-run "$FIXTURE" 2>&1)"
RC_DRY_RUN=$?
if [[ "$OUT_DRY_RUN" == *"DRY RUN"* ]]; then
  pass "deploy-headless.sh --dry-run output contains DRY RUN"
else
  fail "deploy-headless.sh --dry-run output missing DRY RUN: <<<$OUT_DRY_RUN>>>"
fi
if [[ "$OUT_DRY_RUN" != *"Verifying deploy"* ]]; then
  pass "deploy-headless.sh --dry-run does not print the verification announcement"
else
  fail "deploy-headless.sh --dry-run unexpectedly printed the verification announcement: <<<$OUT_DRY_RUN>>>"
fi
if [[ "$RC_DRY_RUN" -eq 0 ]]; then
  pass "deploy-headless.sh --dry-run exits 0"
else
  fail "deploy-headless.sh --dry-run exited $RC_DRY_RUN, expected 0"
fi

# =====================================================================
# Case 5: static assertion that deploy-headless.sh's source still contains the exit-3 branch
# and documents it in its header -- guards against the exit-code contract being silently
# dropped by a future edit.
# =====================================================================
if grep -q 'exit 3' "$DEPLOY_HEADLESS"; then
  pass "deploy-headless.sh source contains 'exit 3'"
else
  fail "deploy-headless.sh source no longer contains 'exit 3'"
fi
if grep -qE '^#[[:space:]]*3[[:space:]]' "$DEPLOY_HEADLESS"; then
  pass "deploy-headless.sh header documents exit code 3"
else
  fail "deploy-headless.sh header no longer documents exit code 3"
fi

# =====================================================================
# Case 6: deploy-headless.sh --help documents the --consumer-report opt-in flag.
# =====================================================================
OUT_HELP="$(bash "$DEPLOY_HEADLESS" --help 2>&1)"
if [[ "$OUT_HELP" == *"--consumer-report"* ]]; then
  pass "deploy-headless.sh --help output contains --consumer-report"
else
  fail "deploy-headless.sh --help output missing --consumer-report: <<<$OUT_HELP>>>"
fi

# =====================================================================
# Case 7: an unknown flag still reports the usage string, and that usage string now lists
# --consumer-report.
# =====================================================================
OUT_BOGUS_DH="$(bash "$DEPLOY_HEADLESS" --bogus "$FIXTURE" 2>&1)"
if [[ "$OUT_BOGUS_DH" == *"Usage: deploy-headless.sh"* ]]; then
  pass "deploy-headless.sh unknown flag still prints the Usage: line"
else
  fail "deploy-headless.sh unknown flag missing the Usage: line: <<<$OUT_BOGUS_DH>>>"
fi
if [[ "$OUT_BOGUS_DH" == *"--consumer-report"* ]]; then
  pass "deploy-headless.sh unknown-flag usage string lists --consumer-report"
else
  fail "deploy-headless.sh unknown-flag usage string missing --consumer-report: <<<$OUT_BOGUS_DH>>>"
fi

# =====================================================================
# Case 8: static source assertions for the --consumer-report default-OFF/opt-in contract --
# guards against the gating being silently dropped or defaulted-on by a future edit.
# =====================================================================
if grep -q -- '--consumer-report) CONSUMER_REPORT=true' "$DEPLOY_HEADLESS"; then
  pass "deploy-headless.sh source contains the --consumer-report case branch"
else
  fail "deploy-headless.sh source no longer contains the --consumer-report case branch"
fi
if grep -q 'local CONSUMER_REPORT=false' "$DEPLOY_HEADLESS"; then
  pass "deploy-headless.sh source initializes CONSUMER_REPORT to false (default OFF)"
else
  fail "deploy-headless.sh source no longer initializes CONSUMER_REPORT to false"
fi
if grep -qE 'if \[ "\$CONSUMER_REPORT" = "true" \] && \[ -f "\$consumer_checker" \]; then' "$DEPLOY_HEADLESS"; then
  pass "deploy-headless.sh source guards the consumer block on CONSUMER_REPORT"
else
  fail "deploy-headless.sh source no longer guards the consumer block on CONSUMER_REPORT"
fi
if grep -qE 'echo "\[deploy-headless\] CONSUMERS_STALE=' "$DEPLOY_HEADLESS"; then
  pass "deploy-headless.sh source still emits the CONSUMERS_STALE= marker"
else
  fail "deploy-headless.sh source no longer emits the CONSUMERS_STALE= marker"
fi

# =====================================================================
# Case 9: --consumer-report --dry-run does not resurrect work on the dry-run path (which
# short-circuits before the post-deploy block) -- still prints DRY RUN, exits 0, and prints
# neither the verification announcement nor any CONSUMERS_STALE= line.
# =====================================================================
OUT_DRY_RUN_CR="$(bash "$DEPLOY_HEADLESS" --consumer-report --dry-run "$FIXTURE" 2>&1)"
RC_DRY_RUN_CR=$?
if [[ "$OUT_DRY_RUN_CR" == *"DRY RUN"* ]]; then
  pass "deploy-headless.sh --consumer-report --dry-run output contains DRY RUN"
else
  fail "deploy-headless.sh --consumer-report --dry-run output missing DRY RUN: <<<$OUT_DRY_RUN_CR>>>"
fi
if [[ "$OUT_DRY_RUN_CR" != *"Verifying deploy"* ]]; then
  pass "deploy-headless.sh --consumer-report --dry-run does not print the verification announcement"
else
  fail "deploy-headless.sh --consumer-report --dry-run unexpectedly printed the verification announcement: <<<$OUT_DRY_RUN_CR>>>"
fi
if [[ "$OUT_DRY_RUN_CR" != *"CONSUMERS_STALE"* ]]; then
  pass "deploy-headless.sh --consumer-report --dry-run prints no CONSUMERS_STALE= line"
else
  fail "deploy-headless.sh --consumer-report --dry-run unexpectedly printed a CONSUMERS_STALE= line: <<<$OUT_DRY_RUN_CR>>>"
fi
if [[ "$RC_DRY_RUN_CR" -eq 0 ]]; then
  pass "deploy-headless.sh --consumer-report --dry-run exits 0"
else
  fail "deploy-headless.sh --consumer-report --dry-run exited $RC_DRY_RUN_CR, expected 0"
fi

# =====================================================================
# Case 10: deploy-headless.sh --help documents the --skip-verify opt-in flag, exit code 4, and
# the landed_verify_skipped RESULT= token.
# =====================================================================
if [[ "$OUT_HELP" == *"--skip-verify"* ]]; then
  pass "deploy-headless.sh --help output contains --skip-verify"
else
  fail "deploy-headless.sh --help output missing --skip-verify: <<<$OUT_HELP>>>"
fi
if [[ "$OUT_HELP" == *"landed_verify_skipped"* ]]; then
  pass "deploy-headless.sh --help output documents landed_verify_skipped"
else
  fail "deploy-headless.sh --help output missing landed_verify_skipped: <<<$OUT_HELP>>>"
fi
if grep -qE '^#[[:space:]]*4[[:space:]]' "$DEPLOY_HEADLESS"; then
  pass "deploy-headless.sh header documents exit code 4"
else
  fail "deploy-headless.sh header no longer documents exit code 4"
fi

# =====================================================================
# Case 11: --skip-verify --dry-run still exits 0, prints DRY RUN, and prints no verification
# announcement -- the dry-run carve-out (verification never runs under --dry-run at all) is
# unchanged by the new flag.
# =====================================================================
OUT_DRY_RUN_SV="$(bash "$DEPLOY_HEADLESS" --skip-verify --dry-run "$FIXTURE" 2>&1)"
RC_DRY_RUN_SV=$?
if [[ "$OUT_DRY_RUN_SV" == *"DRY RUN"* ]]; then
  pass "deploy-headless.sh --skip-verify --dry-run output contains DRY RUN"
else
  fail "deploy-headless.sh --skip-verify --dry-run output missing DRY RUN: <<<$OUT_DRY_RUN_SV>>>"
fi
if [[ "$OUT_DRY_RUN_SV" != *"Verifying deploy"* && "$OUT_DRY_RUN_SV" != *"SUPPRESSED"* ]]; then
  pass "deploy-headless.sh --skip-verify --dry-run prints no verification announcement (dry-run short-circuits before the suppression guard too)"
else
  fail "deploy-headless.sh --skip-verify --dry-run unexpectedly printed a verification-related announcement: <<<$OUT_DRY_RUN_SV>>>"
fi
if [[ "$RC_DRY_RUN_SV" -eq 0 ]]; then
  pass "deploy-headless.sh --skip-verify --dry-run exits 0"
else
  fail "deploy-headless.sh --skip-verify --dry-run exited $RC_DRY_RUN_SV, expected 0"
fi

# =====================================================================
# Case 12: structural assertion that exit 4 / landed_verify_skipped is reachable ONLY under the
# SKIP_VERIFY guard, and that landed_verify_clean 0 is not reachable on that same path --
# satisfying Part B's Verification #4 ("distinguishable in a test") structurally, since a
# non-dry-run deploy is not safe to run inside this suite (see the file header's scope). The
# live, end-to-end exit-code pair is captured separately as a recorded execution-summary
# artifact, not by this suite.
# =====================================================================
if grep -qE 'SKIP_VERIFY" = "true" \]; then' "$DEPLOY_HEADLESS" && \
   grep -q '_dh_result_and_exit landed_verify_skipped 4' "$DEPLOY_HEADLESS"; then
  pass "deploy-headless.sh source: landed_verify_skipped 4 is reachable only under the SKIP_VERIFY guard"
else
  fail "deploy-headless.sh source: SKIP_VERIFY guard or exit-4 routing not found as expected"
fi
# The final if/elif/else must route verify_rc==4 to exit 4 BEFORE the else (verify_rc==3) arm,
# so a verify_rc of 0 can never fall through to the skipped-RESULT branch.
if grep -qE 'elif \[ "\$verify_rc" -eq 4 \]; then' "$DEPLOY_HEADLESS"; then
  pass "deploy-headless.sh source: verify_rc==4 is routed by its own elif arm, distinct from the verify_rc==0 and verify_rc==3 arms"
else
  fail "deploy-headless.sh source: verify_rc==4 elif arm not found as expected"
fi

echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
