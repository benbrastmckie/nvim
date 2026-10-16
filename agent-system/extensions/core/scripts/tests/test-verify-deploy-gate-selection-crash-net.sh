#!/usr/bin/env bash
# test-verify-deploy-gate-selection-crash-net.sh - Cross-gate-variable crash-regression net: every
# registered gate id 1..23 runs STANDALONE (`--only-gate <n>`) against a real-copy fixture, and
# none of them crashes (unbound variable / command-not-found / unary-operator-expected).
#
# SPLIT OUT of test-verify-deploy-gate-selection.sh (re-aim gate-cost-model work, "Cut the Two
# Verify-Deploy-Testing Stragglers" phase): this one case -- exercising all 23 gates for real,
# standalone, against a real corpus -- measured at ~149.7s of a ~186s suite total (80% of the
# suite's cost, dominated by a single real gate-3 run at ~114.7s), while every OTHER case in the
# parent suite (now 17 of them) sums to roughly 33s. The assertion genuinely needs the full
# battery (it is a crash net across every gate id, not a narrowable selection -- `--only-gate`
# already narrows each individual call to one gate, so there is nothing further to narrow without
# dropping gate coverage, which this task's Non-Goals forbid). Splitting it into its own suite
# does not reduce the total work done; it lets run-all.sh's scheduler place this one genuinely
# large, well-hinted unit on its own worker slot instead of forcing 17 cheap cases to serialize
# behind it inside one process. See test-verify-deploy-gate-selection.sh's own header for the
# cross-reference and shell-script-testing.md's per-gate before/after table (Phase 13).
#
# This suite deliberately invokes the SOURCE-STORE copy of verify-deploy.sh directly
# ($CORE_DIR/verify-deploy.sh), never the deployed .claude/ copy -- same rationale as its parent
# suite (context/rules/source-store-deploy-boundary.md).
#
# FIXTURE_RICH: a real-copy rsync of agent-system/extensions/ (same shape/rationale as the parent
# suite's own FIXTURE_RICH and test-verify-deploy-context-budget.sh's fixture) -- needed so every
# gate's real per-file checks have real content to scan, which is the whole point of a crash net.
# Deliberately NOT git-added/committed (same as the parent suite's own FIXTURE_RICH): adding and
# committing 390+ files would itself cost real wall-clock time with no crash-detection benefit --
# git-tracked-file-dependent gates (e.g. gate 22, lint-shellcheck.sh) correctly hit their own
# "no files found" branch against an un-indexed fixture and are still exercised for the property
# this suite actually checks (no CRASH), even though they do not get a tracked-file finding-set
# exercise here -- that finding-set-level proof belongs to Phase 9's per-gate equivalence suite
# and to the live-repo full-sweep run, neither of which this crash net duplicates.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (verify-deploy.sh, rsync, git, or jq not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$CORE_DIR/../../../.." && pwd)"

VERIFY_DEPLOY="$CORE_DIR/verify-deploy.sh"

if [ ! -f "$VERIFY_DEPLOY" ]; then
  echo "ERROR: expected $VERIFY_DEPLOY" >&2
  exit 2
fi
for bin in rsync git; do
  command -v "$bin" >/dev/null 2>&1 || { echo "ERROR: $bin required and not on PATH" >&2; exit 2; }
done

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); [ -n "${2:-}" ] && echo "$2"; }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# =====================================================================
# FIXTURE_RICH: real-copy rsync, same shape/rationale as the parent suite's own FIXTURE_RICH.
# =====================================================================
FIXTURE_RICH="$WORKDIR/rich"
mkdir -p "$FIXTURE_RICH/agent-system/extensions"
rsync -a --exclude='literature-pyenv' "$REPO_ROOT/agent-system/extensions/" "$FIXTURE_RICH/agent-system/extensions/"
cp "$REPO_ROOT/CLAUDE.md" "$FIXTURE_RICH/CLAUDE.md"
cp "$REPO_ROOT/.claude-extensions.json" "$FIXTURE_RICH/.claude-extensions.json"
[ -f "$REPO_ROOT/.gitignore" ] && cp "$REPO_ROOT/.gitignore" "$FIXTURE_RICH/.gitignore"
ln -s "$REPO_ROOT/.claude" "$FIXTURE_RICH/.claude"
git init -q "$FIXTURE_RICH"
git -C "$FIXTURE_RICH" config user.email "test@example.com"
git -C "$FIXTURE_RICH" config user.name "Test"

run_vd() {
  # Usage: run_vd TARGET [extra args...]
  local target="$1"; shift
  bash "$VERIFY_DEPLOY" --skip-slow "$@" "$target" 2>&1
}

# =====================================================================
# Case (b): every gate id 1..23 runs clean standalone against FIXTURE_RICH (cross-gate-variable
# regression net) -- no unbound-variable / unset-path crash for any of them.
# =====================================================================
case_b_all_clean=true
for n in $(seq 1 23); do
  gate_n_out="$(run_vd "$FIXTURE_RICH" --only-gate "$n")"
  gate_n_rc=$?
  if printf '%s\n' "$gate_n_out" | grep -qiE 'unbound variable|: command not found|unary operator expected'; then
    fail "case(b): gate $n crashed standalone (rc=$gate_n_rc)" "$(printf '%s\n' "$gate_n_out" | tail -5)"
    case_b_all_clean=false
  fi
done
[ "$case_b_all_clean" = "true" ] && pass "case(b): all 23 gates run clean standalone against the real-copy fixture (no cross-gate variable dependency)"

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "==================================================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "==================================================================="

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
