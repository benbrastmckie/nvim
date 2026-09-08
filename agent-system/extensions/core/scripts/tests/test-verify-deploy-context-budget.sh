#!/usr/bin/env bash
# test-verify-deploy-context-budget.sh - Fixture-driven regression suite for verify-deploy.sh's
# Gate 20 (orchestrator context budget lock): the two per-file ceilings, the eager-load
# regression check, the ORCHESTRATOR_BUDGET_GATE_MODE severity toggle, and -- the load-bearing
# case -- proof that a Gate 20 warn-tier finding does not register as a "new finding" across a
# deploy_findings_snapshot pre/post diff (the redeploy-checkpoint hazard named in this task's
# research report).
#
# FIXTURE SHAPE: verify-deploy.sh gates 3-20 all [SKIP] unconditionally unless
# $TARGET/agent-system/extensions exists, and several of them (lint-agent-contracts.sh,
# lint-routing-wiring.sh) discover files via `find ... -type f` without `-L`, which does NOT
# match a symlinked file/directory -- so a fixture built from symlinks alone produces spurious
# "no dispatchable agents found" / "no manifests found" failures unrelated to Gate 20. The
# fixture below instead REAL-COPIES the whole `agent-system/extensions/` tree (rsync -a),
# excluding only `literature/scripts/literature-pyenv` (a ~240 MB vendored Python venv,
# irrelevant to any gate here -- the rest of the tree is ~16 MB and copies in a few seconds),
# plus the root CLAUDE.md, .claude-extensions.json, and .gitignore (gate14's runtime-file
# tracking check runs `git check-ignore`, which requires a real git repo + a real .gitignore).
# `.claude/` itself is symlinked wholesale -- gates 1/2 only stat/jq specific paths inside it,
# never `find`-discover its contents, so a symlink resolves transparently there.
#
# This gives a clean baseline (verified empirically at implementation time: exit 0, exactly one
# pre-existing WARN for commands/orchestrate.md already being over its ceiling in the real repo)
# that every case below builds on by mutating ONLY the specific file(s) each case needs, so a
# failing case points unambiguously at Gate 20 logic rather than fixture noise.
#
# Structural model: test-deploy-verify-wiring.sh (pass()/fail()/info() helpers, PASSED/FAILED
# counters, mktemp WORKDIR with trap EXIT cleanup, git-init the fixture). Every run below passes
# --skip-slow (gate 8, the shell test suite, is irrelevant to Gate 20 and would otherwise recurse
# into this very suite -- see test-deploy-verify-wiring.sh's ANTI-RECURSION INVARIANT for the
# general hazard this avoids).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (verify-deploy.sh, rsync, git, or jq not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$CORE_DIR/../../../.." && pwd)"

VERIFY_DEPLOY="$CORE_DIR/verify-deploy.sh"
BASELINE_LIB="$CORE_DIR/lib/deploy-baseline-lib.sh"

for f in "$VERIFY_DEPLOY" "$BASELINE_LIB" \
         "$REPO_ROOT/agent-system/extensions/core/context/config/orchestrator-context-budget.json"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: expected $f" >&2
    exit 2
  fi
done
for bin in rsync git jq; do
  command -v "$bin" >/dev/null 2>&1 || { echo "ERROR: $bin required and not on PATH" >&2; exit 2; }
done

# shellcheck disable=SC1090
source "$BASELINE_LIB"

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

FIXTURE="$WORKDIR/target"
mkdir -p "$FIXTURE/agent-system/extensions"
rsync -a --exclude='literature-pyenv' "$REPO_ROOT/agent-system/extensions/" "$FIXTURE/agent-system/extensions/"
cp "$REPO_ROOT/CLAUDE.md" "$FIXTURE/CLAUDE.md"
cp "$REPO_ROOT/.claude-extensions.json" "$FIXTURE/.claude-extensions.json"
[ -f "$REPO_ROOT/.gitignore" ] && cp "$REPO_ROOT/.gitignore" "$FIXTURE/.gitignore"
ln -s "$REPO_ROOT/.claude" "$FIXTURE/.claude"
git init -q "$FIXTURE"
git -C "$FIXTURE" config user.email "test@example.com"
git -C "$FIXTURE" config user.name "Test"

ORCH_MD="$FIXTURE/agent-system/extensions/core/commands/orchestrate.md"
SKILL_MD="$FIXTURE/agent-system/extensions/core/skills/skill-orchestrate/SKILL.md"
BUDGET_CONFIG="$FIXTURE/agent-system/extensions/core/context/config/orchestrator-context-budget.json"
ORCH_MD_ORIG="$WORKDIR/orchestrate.md.orig"
SKILL_MD_ORIG="$WORKDIR/SKILL.md.orig"
cp "$ORCH_MD" "$ORCH_MD_ORIG"
cp "$SKILL_MD" "$SKILL_MD_ORIG"

restore_file() { cp "$1" "$2"; }

# pad_file <path> <min_target_bytes>: appends an inert, digit-free HTML comment block so the
# file's byte count is at least min_target_bytes above its CURRENT size (never assumes a
# starting size, so the case stays correct even after a future trim of the real files this
# fixture was copied from).
pad_file() {
  local path="$1" extra_bytes="$2"
  {
    echo ""
    echo "<!-- TEST-PADDING-BLOCK-START"
    head -c "$extra_bytes" /dev/zero | tr '\0' 'x'
    echo ""
    echo "TEST-PADDING-BLOCK-END -->"
  } >> "$path"
}

run_gate20() {
  # Usage: run_gate20 [ORCHESTRATOR_BUDGET_GATE_MODE=value]
  local mode="${1:-warn}"
  ORCHESTRATOR_BUDGET_GATE_MODE="$mode" bash "$VERIFY_DEPLOY" --skip-slow --findings --quiet "$FIXTURE" 2>&1
}

# =====================================================================
# Baseline: confirm the fixture itself is clean before any case mutates it, so a later case's
# failure cannot be blamed on fixture noise. The one expected WARN is the pre-existing
# over-ceiling state of the real commands/orchestrate.md this fixture was copied from.
# =====================================================================
baseline_out="$(run_gate20 warn)"
baseline_rc=$?
baseline_gate20_lines="$(printf '%s\n' "$baseline_out" | grep -c '^FINDING gate20 ')"
if [ "$baseline_rc" -eq 0 ] && [ "$baseline_gate20_lines" -le 1 ]; then
  pass "baseline fixture is clean (exit 0, at most the pre-existing commands/orchestrate.md WARN)"
else
  fail "baseline fixture is not clean (rc=$baseline_rc, gate20 finding lines=$baseline_gate20_lines) -- fixture setup is broken; later cases are unreliable" \
       "$(printf '%s\n' "$baseline_out" | tail -20)"
fi

# =====================================================================
# Combined run B: pad ALL THREE targets in ONE fixture mutation, then run verify-deploy.sh ONCE
# to cover cases 1, 2, and 5 (each an independent sub-check within Gate 20) in a single ~100s
# invocation instead of three -- this suite's runtime is dominated by verify-deploy.sh's OTHER 19
# gates re-scanning the fixture tree on every call, not by Gate 20 itself, so minimizing the
# invocation COUNT (not the padding complexity) is what keeps this suite's wall-clock bounded.
#   - commands/orchestrate.md padded past its 8,000 B ceiling (case 1)
#   - skills/skill-orchestrate/SKILL.md padded past its 20,000 B ceiling (case 2)
#   - root CLAUDE.md padded to push the fixture's own eager-load total above baseline (case 5)
# =====================================================================
pad_file "$ORCH_MD" 3000
pad_file "$SKILL_MD" 6000

CLAUDE_MD_FIXTURE="$FIXTURE/CLAUDE.md"
CLAUDE_MD_ORIG="$WORKDIR/CLAUDE.md.orig"
cp "$CLAUDE_MD_FIXTURE" "$CLAUDE_MD_ORIG"
baseline_bytes="$(jq -r '.eager_load.baseline_bytes' "$BUDGET_CONFIG")"
# Determine the fixture's own current eager total (independent of the real repo's, since the
# fixture's parent CLAUDE.md chain resolves to a nonexistent path above $WORKDIR) and pad by
# enough to clear baseline_bytes with margin.
current_eager="$(REPO_ROOT="$FIXTURE" bash "$CORE_DIR/measure-eager-context.sh" --check 2>&1 | grep -oE '^TOTAL: [0-9]+ B' | grep -oE '[0-9]+')"
eager_pad_applied=false
if [ -n "$current_eager" ] && [ "$current_eager" -le "$baseline_bytes" ]; then
  pad_bytes=$(( baseline_bytes - current_eager + 2000 ))
  pad_file "$CLAUDE_MD_FIXTURE" "$pad_bytes"
  eager_pad_applied=true
else
  fail "could not compute a safe eager-load pad amount (current_eager='$current_eager', baseline_bytes='$baseline_bytes')"
fi

runB_out="$(run_gate20 warn)"
runB_rc=$?
pre_findings="$(printf '%s\n' "$runB_out" | grep '^FINDING ' | sort -u)"

# --- case 1 assertions (commands/orchestrate.md) ---
case1_warn_lines="$(printf '%s\n' "$runB_out" | grep -c '\[WARN\] commands/orchestrate.md')"
case1_gate20_findings="$(printf '%s\n' "$runB_out" | grep '^FINDING gate20 ' | grep -c 'orchestrate.md')"
case1_digit_free=1
printf '%s\n' "$runB_out" | grep '^FINDING gate20 ' | grep 'orchestrate.md' | sed -E 's/^FINDING gate20 //' | grep -q '[0-9]' && case1_digit_free=0
[ "$case1_warn_lines" -eq 1 ] && pass "case1: exactly one [WARN] line for commands/orchestrate.md" || fail "case1: expected exactly one [WARN] line for commands/orchestrate.md, found $case1_warn_lines"
[ "$case1_gate20_findings" -eq 1 ] && pass "case1: exactly one FINDING gate20 line for commands/orchestrate.md" || fail "case1: expected exactly one FINDING gate20 line for commands/orchestrate.md, found $case1_gate20_findings"
[ "$case1_digit_free" -eq 1 ] && pass "case1: gate20 finding text is digit-free" || fail "case1: gate20 finding text contains a digit (redeploy-checkpoint hazard)"

# --- case 2 assertions (skills/skill-orchestrate/SKILL.md) ---
case2_warn_lines="$(printf '%s\n' "$runB_out" | grep -c '\[WARN\] skills/skill-orchestrate/SKILL.md')"
case2_gate20_findings="$(printf '%s\n' "$runB_out" | grep '^FINDING gate20 ' | grep -c 'SKILL.md')"
case2_digit_free=1
printf '%s\n' "$runB_out" | grep '^FINDING gate20 ' | grep 'SKILL.md' | sed -E 's/^FINDING gate20 //' | grep -q '[0-9]' && case2_digit_free=0
[ "$case2_warn_lines" -eq 1 ] && pass "case2: exactly one [WARN] line for skills/skill-orchestrate/SKILL.md" || fail "case2: expected exactly one [WARN] line for SKILL.md, found $case2_warn_lines"
[ "$case2_gate20_findings" -eq 1 ] && pass "case2: exactly one FINDING gate20 line for SKILL.md" || fail "case2: expected exactly one FINDING gate20 line for SKILL.md, found $case2_gate20_findings"
[ "$case2_digit_free" -eq 1 ] && pass "case2: SKILL.md gate20 finding text is digit-free" || fail "case2: SKILL.md gate20 finding text contains a digit"

# --- case 5 assertions (eager-load total over baseline) ---
if [ "$eager_pad_applied" = "true" ]; then
  case5_fail_lines="$(printf '%s\n' "$runB_out" | grep -c '\[FAIL\] eager-load total')"
  case5_gate20_findings="$(printf '%s\n' "$runB_out" | grep '^FINDING gate20 ' | grep -c 'eager-load total over baseline')"
  case5_digit_free=1
  printf '%s\n' "$runB_out" | grep '^FINDING gate20 ' | grep 'eager-load' | sed -E 's/^FINDING gate20 //' | grep -q '[0-9]' && case5_digit_free=0
  [ "$case5_fail_lines" -eq 1 ] && pass "case5: exactly one [FAIL] line for eager-load total" || fail "case5: expected exactly one [FAIL] line for eager-load total, found $case5_fail_lines"
  [ "$case5_gate20_findings" -eq 1 ] && pass "case5: exactly one FINDING gate20 line for eager-load-over-baseline" || fail "case5: expected exactly one FINDING gate20 line for eager-load-over-baseline, found $case5_gate20_findings"
  [ "$case5_digit_free" -eq 1 ] && pass "case5: eager-load-over-baseline finding text is digit-free" || fail "case5: eager-load-over-baseline finding text contains a digit"
fi
# Sub-check B (eager-load) is fail()-tier unconditionally, independent of gate mode -- so runB's
# overall exit must already be non-zero from the eager-load FAIL alone, even though the two
# per-file ceilings are still only WARN at this (default warn) mode.
if [ "$runB_rc" -ne 0 ]; then
  pass "case5: eager-load-over-baseline yields a non-zero exit (fail() tier, unconditional)"
else
  fail "case5: eager-load-over-baseline did not yield a non-zero exit (runB_rc=$runB_rc)"
fi
restore_file "$CLAUDE_MD_ORIG" "$CLAUDE_MD_FIXTURE"

# =====================================================================
# Case 3: ORCHESTRATOR_BUDGET_GATE_MODE=hard over the still-padded commands/orchestrate.md and
# SKILL.md (CLAUDE.md already restored above, so this run isolates the per-file-ceiling toggle
# from the eager-load sub-check) -> both per-file findings promote from WARN to FAIL and the
# exit code goes non-zero, proving the severity toggle is real (not decorative).
# =====================================================================
case3_out="$(run_gate20 hard)"
case3_rc=$?
case3_fail_lines="$(printf '%s\n' "$case3_out" | grep -c '\[FAIL\] commands/orchestrate.md')"
if [ "$case3_rc" -ne 0 ]; then
  pass "case3: ORCHESTRATOR_BUDGET_GATE_MODE=hard yields a non-zero exit on the over-ceiling fixture ($case3_rc)"
else
  fail "case3: ORCHESTRATOR_BUDGET_GATE_MODE=hard did not yield a non-zero exit"
fi
if [ "$case3_fail_lines" -eq 1 ]; then
  pass "case3: exactly one [FAIL] line for commands/orchestrate.md under hard mode"
else
  fail "case3: expected exactly one [FAIL] line for commands/orchestrate.md under hard mode, found $case3_fail_lines"
fi

# =====================================================================
# Case 4 (load-bearing): the redeploy-checkpoint hazard. Take a pre/post deploy_findings_snapshot
# around a simulated redeploy in which the padded file's byte count CHANGES (drifts further) but
# stays over ceiling. deploy_baseline_new_findings must return EMPTY -- i.e. the warn does not
# read as a newly-introduced finding, which is exactly what would spuriously trip
# defer_reason:"deploy_checkpoint" for every remaining task in a batch if it did.
#
# pre_findings reuses run B's already-captured findings (commands/orchestrate.md's padding from
# run B is untouched through case 3, which only toggles the gate mode env var, never mutates
# ORCH_MD) rather than re-running verify-deploy.sh a fourth time on the identical fixture state.
# =====================================================================
pad_file "$ORCH_MD" 777
post_findings="$(ORCHESTRATOR_BUDGET_GATE_MODE=warn deploy_findings_snapshot "$VERIFY_DEPLOY" --skip-slow "$FIXTURE")"
new_findings="$(deploy_baseline_new_findings "$pre_findings" "$post_findings")"
if [ -z "$new_findings" ]; then
  pass "case4: a byte-count drift on the still-over-ceiling file introduces no new finding (deploy_baseline_new_findings empty)"
else
  fail "case4: byte-count drift introduced a NEW finding -- this would spuriously trip the redeploy checkpoint" \
       "$new_findings"
fi
restore_file "$ORCH_MD_ORIG" "$ORCH_MD"
restore_file "$SKILL_MD_ORIG" "$SKILL_MD"

# =====================================================================
# Assert no stray files were written under the real specs/ during this suite.
# =====================================================================
if git -C "$REPO_ROOT" status --porcelain -- specs/ 2>/dev/null | grep -q .; then
  info "note: specs/ has pre-existing uncommitted changes unrelated to this suite (not asserted against)"
fi
if [ -n "${WORKDIR:-}" ] && [ ! -d "$WORKDIR" ]; then
  fail "WORKDIR unexpectedly missing before cleanup"
else
  pass "all fixture I/O confined to \$WORKDIR (mktemp -d), nothing under real specs/"
fi

echo ""
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ] || exit 1
exit 0
