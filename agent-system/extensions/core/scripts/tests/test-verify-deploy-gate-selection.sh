#!/usr/bin/env bash
# test-verify-deploy-gate-selection.sh - Regression suite for verify-deploy.sh's --only-gate
# gate-selection flag (GATES_FILTER / gate_selected()): the additive, opt-in mechanism that lets a
# caller run one gate (or a named set) instead of the full 22-gate battery.
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
# Three fixtures, chosen for cost:
#   - FIXTURE_RICH: a real-copy rsync of agent-system/extensions/ (same shape and rationale as
#     test-verify-deploy-context-budget.sh's fixture) -- needed so gate 20's real per-file-ceiling
#     and eager-load checks produce real content, for case (a)'s "only gate 20's output appears"
#     assertion and case (b)'s "every gate id runs clean standalone" cross-gate-variable net.
#   - FIXTURE_CHEAP: a deploy-consumer-style fixture with NO agent-system/extensions directory
#     (mirroring test-deploy-verify-wiring.sh's ANTI-RECURSION fixture) -- gates 3/5-13/15/17-20
#     all [SKIP] unconditionally against it (their own "not the source store" branch), so a
#     no-flag run still prints all 22 gate headers (case (d)) without paying full-battery cost.
#     NOTE: gate 4 is NOT in that SKIP list -- since gate 4's SKIP guard was removed, a no-flag
#     run against FIXTURE_CHEAP now reaches gate 4's "check-task-references.sh not deployed" FAIL
#     branch instead (FIXTURE_CHEAP's hand-built `.claude/scripts/` has no real scripts in it).
#     Case (d) asserts only that all 22 gate headers appear, which still holds regardless.
#   - FIXTURE_CONSUMER: a deploy-consumer shape (no agent-system/extensions, like FIXTURE_CHEAP)
#     whose `.claude` is a SYMLINK to a real, fully deployed tree (same technique FIXTURE_RICH
#     and test-verify-deploy-context-budget.sh's fixture already use for their own `.claude`) --
#     needed so `check-task-references.sh` is actually REACHABLE and runs a real scan, unlike
#     FIXTURE_CHEAP's hand-built empty `.claude/scripts/`, which makes a de-guarded gate 4 reach
#     the "not deployed" failure branch instead of a real check. FIXTURE_CHEAP therefore cannot
#     serve case (e)/(f)/(g)/(h) below, which need gate 4 to either genuinely pass or genuinely
#     have something to report.
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

# =====================================================================
# FIXTURE_CONSUMER: deploy-consumer shape (no agent-system/extensions, like FIXTURE_CHEAP) whose
# .claude is a SYMLINK to the real, fully deployed tree at $REPO_ROOT/.claude -- same technique
# FIXTURE_RICH uses for its own .claude. This makes check-task-references.sh (and its shared
# pattern library) actually reachable, so gate 4 runs a real scan here instead of hitting the
# "not deployed" branch FIXTURE_CHEAP's hand-built empty .claude/scripts/ would force it into.
# =====================================================================
FIXTURE_CONSUMER="$WORKDIR/consumer"
mkdir -p "$FIXTURE_CONSUMER"
ln -s "$REPO_ROOT/.claude" "$FIXTURE_CONSUMER/.claude"
git init -q "$FIXTURE_CONSUMER"
git -C "$FIXTURE_CONSUMER" config user.email "test@example.com"
git -C "$FIXTURE_CONSUMER" config user.name "Test"

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
# Case (b): every gate id 1..22 runs clean standalone against FIXTURE_RICH (cross-gate-variable
# regression net) -- no unbound-variable / unset-path crash for any of them.
# =====================================================================
case_b_all_clean=true
for n in $(seq 1 22); do
  gate_n_out="$(run_vd "$FIXTURE_RICH" --only-gate "$n")"
  gate_n_rc=$?
  if printf '%s\n' "$gate_n_out" | grep -qiE 'unbound variable|: command not found|unary operator expected'; then
    fail "case(b): gate $n crashed standalone (rc=$gate_n_rc)" "$(printf '%s\n' "$gate_n_out" | tail -5)"
    case_b_all_clean=false
  fi
done
[ "$case_b_all_clean" = "true" ] && pass "case(b): all 22 gates run clean standalone against the real-copy fixture (no cross-gate variable dependency)"

# =====================================================================
# Case (c): an invalid gate id exits 2 with a named error, and (under --findings) a FINDING gate0
# line. No fixture needed -- validation happens before TARGET is resolved.
# =====================================================================
invalid_cases=("abc" "0" "23" "1,abc" "1,99")
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
# Case (d): with no --only-gate flag, all 22 gate numbers appear in the output -- the
# "default unchanged" assertion. Uses FIXTURE_CHEAP so this stays fast (gates 3-13/15/17-20 all
# [SKIP] instantly; only gates 1/2/14/16 do any real, cheap work).
# =====================================================================
noflag_out="$(run_vd "$FIXTURE_CHEAP")"
noflag_missing=()
for n in $(seq 1 22); do
  printf '%s\n' "$noflag_out" | grep -q "^${n}\. " || noflag_missing+=("$n")
done
if [ "${#noflag_missing[@]}" -eq 0 ]; then
  pass "case(d): no --only-gate flag -- all 22 gate headers appear (default unchanged)"
else
  fail "case(d): missing gate header(s) with no flag: ${noflag_missing[*]}"
fi

# =====================================================================
# Case (e): --only-gate 4 against FIXTURE_CONSUMER (a deploy-consumer repo, no
# agent-system/extensions) produces a real, non-[SKIP], passing gate-4 check and a non-zero
# check count. Pins Phase 2's de-guard: before that change, this would have printed [SKIP] and
# PASS -- 0 check(s).
# =====================================================================
gate4_out="$(run_vd "$FIXTURE_CONSUMER" --only-gate 4)"
gate4_rc=$?
if [ "$gate4_rc" -eq 0 ] \
   && printf '%s\n' "$gate4_out" | grep -q '^  \[PASS\] task-reference lint reports no findings' \
   && ! printf '%s\n' "$gate4_out" | grep -q '\[SKIP\]' \
   && printf '%s\n' "$gate4_out" | grep -q 'PASS -- 1 check(s), 0 failure(s)'; then
  pass "case(e): --only-gate 4 against a deploy-consumer fixture runs a real, passing, non-SKIP check"
else
  fail "case(e): --only-gate 4 against FIXTURE_CONSUMER did not produce the expected real-check output (rc=$gate4_rc)" "$gate4_out"
fi

# =====================================================================
# Case (f): an all-SKIP selection (--only-gate 3, which always SKIPs against a deploy-consumer
# repo) exits 2 with the new named zero-check message and emits no PASS -- 0 check(s) line.
# Pins Phase 3's zero-check-under-filter detection.
# =====================================================================
gate3_out="$(run_vd "$FIXTURE_CONSUMER" --only-gate 3)"
gate3_rc=$?
if [ "$gate3_rc" -eq 2 ] \
   && printf '%s\n' "$gate3_out" | grep -q 'cannot attest:.*--only-gate 3.*skipped or was deferred' \
   && ! printf '%s\n' "$gate3_out" | grep -q 'PASS -- 0 check(s)'; then
  pass "case(f): an all-SKIP --only-gate 3 selection exits 2 with the named zero-check message"
else
  fail "case(f): --only-gate 3 against FIXTURE_CONSUMER did not produce the expected zero-check result (rc=$gate3_rc)" "$gate3_out"
fi

# =====================================================================
# Case (g): --findings --only-gate 3 against FIXTURE_CONSUMER emits the FINDING gate0 sentinel
# line for the zero-check condition, matching the existing gate0 "could not run" convention.
# =====================================================================
gate3_findings_out="$(bash "$VERIFY_DEPLOY" --skip-slow --findings --only-gate 3 "$FIXTURE_CONSUMER" 2>&1)"
gate3_findings_rc=$?
if [ "$gate3_findings_rc" -eq 2 ] && printf '%s\n' "$gate3_findings_out" | grep -q '^FINDING gate0 .*--only-gate 3.*skipped or was deferred'; then
  pass "case(g): --findings --only-gate 3 emits a FINDING gate0 line for the zero-check condition"
else
  fail "case(g): --findings --only-gate 3 against FIXTURE_CONSUMER did not emit the expected FINDING gate0 line (rc=$gate3_findings_rc)" "$gate3_findings_out"
fi

# =====================================================================
# Case (h): a deferred-gate-only selection (--skip-slow --only-gate 8) reaches the same loud
# zero-check result as an all-SKIP selection -- encodes Phase 3's explicit decision that a
# deferred gate also contributes no check, so the run attests to nothing either way.
# =====================================================================
gate8_out="$(run_vd "$FIXTURE_CONSUMER" --only-gate 8)"
gate8_rc=$?
if [ "$gate8_rc" -eq 2 ] \
   && printf '%s\n' "$gate8_out" | grep -q 'cannot attest:.*--only-gate 8.*skipped or was deferred' \
   && ! printf '%s\n' "$gate8_out" | grep -q 'PASS -- 0 check(s)'; then
  pass "case(h): a deferred-gate-only --skip-slow --only-gate 8 selection reaches the same zero-check result"
else
  fail "case(h): --skip-slow --only-gate 8 against FIXTURE_CONSUMER did not produce the expected zero-check result (rc=$gate8_rc)" "$gate8_out"
fi

echo ""
echo "==================================================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "==================================================================="

[ "$FAILED" -eq 0 ] && exit 0 || exit 1
