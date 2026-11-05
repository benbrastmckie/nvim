#!/usr/bin/env bash
# test-deploy-root-guard.sh - Fixture suite for deploy-root-guard.sh: the default structural
# refusal AND the opt-in self-correcting resolution path (DEPLOY_ROOT_GUARD_SELF_CORRECT=1).
#
# Each case sources the guard inside its own `bash -c` subshell (the guard's refusal path calls
# `exit 1` directly, which would otherwise terminate this test runner) and inspects that
# subshell's stdout/stderr and exit status. Resolved SOURCE-STORE-first (mirroring
# test-manifest-scripts-sync.sh's own rationale): this suite validates the guard as it is
# developed in the source store, and preferring a deployed copy would silently test stale logic.
#
# Coverage:
#   (a) sourced from a `.claude/scripts`-shaped directory -> succeeds, REPO_ROOT left untouched
#   (b) sourced from a non-deploy directory with no opt-in -> exits 1, deploy-path message
#   (c) opt-in + a git root containing agent-system/extensions -> REPO_ROOT set, status 0
#   (d) opt-in + a git root lacking agent-system/extensions -> refusal unchanged
#   (e) opt-in inside a non-git directory -> refusal unchanged
#
# Exit codes: 0 -- all assertions PASS; 1 -- at least one assertion FAILED; 2 -- environment
# error (the guard script was not found at any candidate path).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

GUARD_CANDIDATES=(
  "$SCRIPT_DIR/../deploy-root-guard.sh"
  "$REPO_ROOT/.claude/scripts/deploy-root-guard.sh"
)
GUARD_SCRIPT=""
for candidate in "${GUARD_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    GUARD_SCRIPT="$candidate"
    break
  fi
done
if [[ -z "$GUARD_SCRIPT" ]]; then
  echo "ERROR: deploy-root-guard.sh not found at any of:" >&2
  for candidate in "${GUARD_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi
GUARD_SCRIPT="$(cd "$(dirname "$GUARD_SCRIPT")" && pwd)/$(basename "$GUARD_SCRIPT")"

PASSED=0
FAILED=0

common_test_workdir_init

REFUSAL_NEEDLE="must run from a deployed scripts/ tree"

# ─────────────────────────────────────────────────────────────────────────────────────────────
# (a) Deploy-tree-shaped sourcing directory -> succeeds, REPO_ROOT left untouched.
# ─────────────────────────────────────────────────────────────────────────────────────────────
DEPLOY_FIXTURE="$WORKDIR/fakeclaude/.claude/scripts"
mkdir -p "$DEPLOY_FIXTURE"
cp "$GUARD_SCRIPT" "$DEPLOY_FIXTURE/deploy-root-guard.sh"

OUT_A="$(bash -c '. "$1/deploy-root-guard.sh" || exit 1; echo "REPO_ROOT=[${REPO_ROOT:-}]"; exit 0' _ "$DEPLOY_FIXTURE" 2>&1)"
RC_A=$?
if [[ "$RC_A" -eq 0 ]]; then
  common_test_pass "(a) deploy-tree-shaped directory: guard sources with status 0"
else
  common_test_fail "(a) deploy-tree-shaped directory: expected status 0, got $RC_A (output: $OUT_A)"
fi
if [[ "$OUT_A" == "REPO_ROOT=[]" ]]; then
  common_test_pass "(a) deploy-tree-shaped directory: REPO_ROOT left untouched"
else
  common_test_fail "(a) deploy-tree-shaped directory: REPO_ROOT was mutated (output: $OUT_A)"
fi

# ─────────────────────────────────────────────────────────────────────────────────────────────
# (b) Non-deploy directory, no opt-in -> exits 1, deploy-path message, byte-identical to today.
# ─────────────────────────────────────────────────────────────────────────────────────────────
NONDEPLOY_FIXTURE="$WORKDIR/nondeploy/scripts"
mkdir -p "$NONDEPLOY_FIXTURE"
cp "$GUARD_SCRIPT" "$NONDEPLOY_FIXTURE/deploy-root-guard.sh"

OUT_B="$(bash -c 'unset DEPLOY_ROOT_GUARD_SELF_CORRECT; . "$1/deploy-root-guard.sh" || exit 1; echo "should not print"' _ "$NONDEPLOY_FIXTURE" 2>&1)"
RC_B=$?
if [[ "$RC_B" -eq 1 ]]; then
  common_test_pass "(b) non-deploy directory, no opt-in: exits 1"
else
  common_test_fail "(b) non-deploy directory, no opt-in: expected exit 1, got $RC_B"
fi
if grep -qF "$REFUSAL_NEEDLE" <<< "$OUT_B"; then
  common_test_pass "(b) non-deploy directory, no opt-in: emits the deploy-path refusal message"
else
  common_test_fail "(b) non-deploy directory, no opt-in: refusal message missing (output: $OUT_B)"
fi

# ─────────────────────────────────────────────────────────────────────────────────────────────
# (c) Opt-in + a git root containing agent-system/extensions -> REPO_ROOT set, status 0.
# ─────────────────────────────────────────────────────────────────────────────────────────────
GOODROOT_FIXTURE="$WORKDIR/goodroot"
mkdir -p "$GOODROOT_FIXTURE/agent-system/extensions" "$GOODROOT_FIXTURE/scripts"
cp "$GUARD_SCRIPT" "$GOODROOT_FIXTURE/scripts/deploy-root-guard.sh"
( cd "$GOODROOT_FIXTURE" && git init -q && git config user.email t@t.com && git config user.name t )

OUT_C="$(bash -c 'DEPLOY_ROOT_GUARD_SELF_CORRECT=1; . "$1/scripts/deploy-root-guard.sh" || exit 1; echo "REPO_ROOT=[${REPO_ROOT:-}] OPT_IN=[${DEPLOY_ROOT_GUARD_SELF_CORRECT:-unset}]"; exit 0' _ "$GOODROOT_FIXTURE" 2>&1)"
RC_C=$?
if [[ "$RC_C" -eq 0 ]]; then
  common_test_pass "(c) opt-in + valid root: guard sources with status 0"
else
  common_test_fail "(c) opt-in + valid root: expected status 0, got $RC_C (output: $OUT_C)"
fi
EXPECTED_C="REPO_ROOT=[$(cd "$GOODROOT_FIXTURE" && pwd)] OPT_IN=[unset]"
if [[ "$OUT_C" == "$EXPECTED_C" ]]; then
  common_test_pass "(c) opt-in + valid root: REPO_ROOT set to the git toplevel and opt-in variable unset"
else
  common_test_fail "(c) opt-in + valid root: expected '$EXPECTED_C', got '$OUT_C'"
fi

# ─────────────────────────────────────────────────────────────────────────────────────────────
# (d) Opt-in + a git root lacking agent-system/extensions -> refusal unchanged.
# ─────────────────────────────────────────────────────────────────────────────────────────────
BADROOT_FIXTURE="$WORKDIR/badroot"
mkdir -p "$BADROOT_FIXTURE/scripts"
cp "$GUARD_SCRIPT" "$BADROOT_FIXTURE/scripts/deploy-root-guard.sh"
( cd "$BADROOT_FIXTURE" && git init -q && git config user.email t@t.com && git config user.name t )

OUT_D="$(bash -c 'DEPLOY_ROOT_GUARD_SELF_CORRECT=1; . "$1/scripts/deploy-root-guard.sh" || exit 1; echo "should not print"' _ "$BADROOT_FIXTURE" 2>&1)"
RC_D=$?
if [[ "$RC_D" -eq 1 ]]; then
  common_test_pass "(d) opt-in + git root without agent-system/extensions: exits 1"
else
  common_test_fail "(d) opt-in + git root without agent-system/extensions: expected exit 1, got $RC_D"
fi
if grep -qF "$REFUSAL_NEEDLE" <<< "$OUT_D"; then
  common_test_pass "(d) opt-in + git root without agent-system/extensions: refusal unchanged"
else
  common_test_fail "(d) opt-in + git root without agent-system/extensions: refusal message missing (output: $OUT_D)"
fi

# ─────────────────────────────────────────────────────────────────────────────────────────────
# (e) Opt-in inside a non-git directory -> refusal unchanged.
# ─────────────────────────────────────────────────────────────────────────────────────────────
NONGIT_FIXTURE="$WORKDIR/nongit/scripts"
mkdir -p "$NONGIT_FIXTURE"
cp "$GUARD_SCRIPT" "$NONGIT_FIXTURE/deploy-root-guard.sh"

OUT_E="$(bash -c 'DEPLOY_ROOT_GUARD_SELF_CORRECT=1; . "$1/deploy-root-guard.sh" || exit 1; echo "should not print"' _ "$NONGIT_FIXTURE" 2>&1)"
RC_E=$?
if [[ "$RC_E" -eq 1 ]]; then
  common_test_pass "(e) opt-in inside non-git directory: exits 1"
else
  common_test_fail "(e) opt-in inside non-git directory: expected exit 1, got $RC_E"
fi
if grep -qF "$REFUSAL_NEEDLE" <<< "$OUT_E"; then
  common_test_pass "(e) opt-in inside non-git directory: refusal unchanged"
else
  common_test_fail "(e) opt-in inside non-git directory: refusal message missing (output: $OUT_E)"
fi

echo ""
echo "====================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "====================================="

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
