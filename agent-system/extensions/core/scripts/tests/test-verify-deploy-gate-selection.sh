#!/usr/bin/env bash
# test-verify-deploy-gate-selection.sh - Regression suite for verify-deploy.sh's --only-gate
# gate-selection flag (GATES_FILTER / gate_selected()): the additive, opt-in mechanism that lets a
# caller run one gate (or a named set) instead of the full 20-gate battery.
#
# Structural model: test-verify-deploy-context-budget.sh (pass()/fail()/info() helpers, PASSED/
# FAILED counters, mktemp WORKDIR with trap EXIT cleanup, real-copy rsync fixture, git-init).
# Every verify-deploy.sh invocation below passes --skip-slow -- this is a hard requirement, not a
# style choice: without it, `--only-gate 8` (or a no-flag run) would recurse into gate 8's own
# tests/run-all.sh, which is precisely the suite that discovers and runs THIS FILE (the same
# ANTI-RECURSION INVARIANT test-deploy-verify-wiring.sh documents for itself).
#
# This suite deliberately invokes the SOURCE-STORE copy of verify-deploy.sh directly
# ($CORE_DIR/verify-deploy.sh), never the deployed .claude/ copy -- the --only-gate flag it tests
# exists only in the source store until this task's Phase 7 redeploy (see
# context/rules/source-store-deploy-boundary.md and this task's own plan Risks table).
#
# Two fixtures, chosen for cost:
#   - FIXTURE_RICH: a real-copy rsync of agent-system/extensions/ (same shape and rationale as
#     test-verify-deploy-context-budget.sh's fixture) -- needed so gate 20's real per-file-ceiling
#     and eager-load checks produce real content, for case (a)'s "only gate 20's output appears"
#     assertion and case (b)'s "every gate id runs clean standalone" cross-gate-variable net.
#   - FIXTURE_CHEAP: a deploy-consumer-style fixture with NO agent-system/extensions directory
#     (mirroring test-deploy-verify-wiring.sh's ANTI-RECURSION fixture) -- gates 3-13/15/17-20 all
#     [SKIP] unconditionally against it (their own "not the source store" branch), so a no-flag
#     run still prints all 20 gate headers (case (d)) without paying full-battery cost.
# Case (c) (invalid gate id) needs no fixture at all: --only-gate argument validation happens in
# the arg-parsing loop, before TARGET is even resolved.
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
for bin in rsync git jq; do
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
# FIXTURE_RICH: real-copy rsync, same shape/rationale as test-verify-deploy-context-budget.sh.
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

# =====================================================================
# FIXTURE_CHEAP: deploy-consumer shape (no agent-system/extensions) -- gates 3-13/15/17-20 all
# [SKIP] instantly against it. Only needs a minimal .claude/ so gate1/gate2/gate14/gate16 (which
# run unconditionally or on any target) have something to inspect.
# =====================================================================
FIXTURE_CHEAP="$WORKDIR/cheap"
mkdir -p "$FIXTURE_CHEAP/.claude/scripts" "$FIXTURE_CHEAP/.claude/hooks" "$FIXTURE_CHEAP/.claude/context/schemas" "$FIXTURE_CHEAP/.claude/context/formats" "$FIXTURE_CHEAP/.claude/extensions"
echo '{}' > "$FIXTURE_CHEAP/.claude/settings.json"
git init -q "$FIXTURE_CHEAP"
git -C "$FIXTURE_CHEAP" config user.email "test@example.com"
git -C "$FIXTURE_CHEAP" config user.name "Test"

run_vd() {
  # Usage: run_vd TARGET [extra args...]
  local target="$1"; shift
  bash "$VERIFY_DEPLOY" --skip-slow "$@" "$target" 2>&1
}

# =====================================================================
# Case (a): --only-gate 20 runs gate 20 and no other gate's output appears.
# =====================================================================
only20_out="$(run_vd "$FIXTURE_RICH" --only-gate 20)"
only20_headers="$(printf '%s\n' "$only20_out" | grep -cE '^[0-9]+\. ')"
only20_has_gate20_header="$(printf '%s\n' "$only20_out" | grep -c '^20\. ')"
if [ "$only20_headers" -eq 1 ] && [ "$only20_has_gate20_header" -eq 1 ]; then
  pass "case(a): --only-gate 20 prints exactly one gate header, and it is gate 20's"
else
  fail "case(a): expected exactly one gate header (gate 20's), found $only20_headers header(s)" \
       "$(printf '%s\n' "$only20_out" | grep -E '^[0-9]+\. ')"
fi

# =====================================================================
# Case (b): every gate id 1..20 runs clean standalone against FIXTURE_RICH (cross-gate-variable
# regression net) -- no unbound-variable / unset-path crash for any of them.
# =====================================================================
case_b_all_clean=true
for n in $(seq 1 20); do
  gate_n_out="$(run_vd "$FIXTURE_RICH" --only-gate "$n")"
  gate_n_rc=$?
  if printf '%s\n' "$gate_n_out" | grep -qiE 'unbound variable|: command not found|unary operator expected'; then
    fail "case(b): gate $n crashed standalone (rc=$gate_n_rc)" "$(printf '%s\n' "$gate_n_out" | tail -5)"
    case_b_all_clean=false
  fi
done
[ "$case_b_all_clean" = "true" ] && pass "case(b): all 20 gates run clean standalone against the real-copy fixture (no cross-gate variable dependency)"

# =====================================================================
# Case (c): an invalid gate id exits 2 with a named error, and (under --findings) a FINDING gate0
# line. No fixture needed -- validation happens before TARGET is resolved.
# =====================================================================
invalid_cases=("abc" "0" "21" "1,abc" "1,99")
case_c_all_ok=true
for bad in "${invalid_cases[@]}"; do
  bad_out="$(bash "$VERIFY_DEPLOY" --only-gate "$bad" 2>&1)"
  bad_rc=$?
  if [ "$bad_rc" -ne 2 ]; then
    fail "case(c): --only-gate $bad expected exit 2, got $bad_rc"
    case_c_all_ok=false
    continue
  fi
  if ! printf '%s\n' "$bad_out" | grep -q "ERROR: --only-gate:"; then
    fail "case(c): --only-gate $bad exited 2 but printed no named --only-gate error" "$bad_out"
    case_c_all_ok=false
  fi
done
[ "$case_c_all_ok" = "true" ] && pass "case(c): every invalid gate id (${invalid_cases[*]}) exits 2 with a named error"

findings_bad_out="$(bash "$VERIFY_DEPLOY" --findings --only-gate 99 2>&1)"
findings_bad_rc=$?
if [ "$findings_bad_rc" -eq 2 ] && printf '%s\n' "$findings_bad_out" | grep -q '^FINDING gate0 '; then
  pass "case(c): --findings --only-gate 99 emits a FINDING gate0 line on exit 2"
else
  fail "case(c): --findings --only-gate 99 did not emit the expected FINDING gate0 line" "$findings_bad_out"
fi

# =====================================================================
# Case (d): with no --only-gate flag, all 20 gate numbers appear in the output -- the
# "default unchanged" assertion. Uses FIXTURE_CHEAP so this stays fast (gates 3-13/15/17-20 all
# [SKIP] instantly; only gates 1/2/14/16 do any real, cheap work).
# =====================================================================
noflag_out="$(run_vd "$FIXTURE_CHEAP")"
noflag_missing=()
for n in $(seq 1 20); do
  printf '%s\n' "$noflag_out" | grep -q "^${n}\. " || noflag_missing+=("$n")
done
if [ "${#noflag_missing[@]}" -eq 0 ]; then
  pass "case(d): no --only-gate flag -- all 20 gate headers appear (default unchanged)"
else
  fail "case(d): missing gate header(s) with no flag: ${noflag_missing[*]}"
fi

echo ""
echo "==================================================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "==================================================================="

[ "$FAILED" -eq 0 ] && exit 0 || exit 1
