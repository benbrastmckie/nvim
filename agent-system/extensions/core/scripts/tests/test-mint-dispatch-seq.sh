#!/usr/bin/env bash
# test-mint-dispatch-seq.sh - Regression suite for skill_orchestrate_mint_dispatch_seq()
# (scripts/skill-base.sh), the single shared implementation both orchestrate engines reach
# through byte-identical named shims (mint_dispatch_seq()).
#
# This suite closes a coverage gap neither existing dispatch_seq suite provides:
# test-handoff-dispatch-identity.sh injects dispatch_seq as a fixture and exercises only the
# downstream Stage 5 comparison; test-orchestrate-cycle-plan.sh's Group 8 and
# test-force-phases.sh's dispatch_seq-durability cases exercise the batch engine's OWN durable
# seeding/flush call sites end to end, but not this shared mint function's own internals in
# isolation. Neither calls the mint function itself. Fixed defect: an earlier body
# derived the minted value from an ambient shell variable (`dispatch_seq_counter=$((dispatch_seq_counter
# + 1))`), which is unset in a fresh shell/subprocess and silently collapses every mint to 1 for
# any caller that does not hold a single long-lived shell across the whole orchestration loop.
# The fixed body derives the value exclusively by reading `.dispatch_seq_counter` back out of the
# loop guard file. Cases A-D below directly reproduce that fresh-shell / fresh-subprocess /
# poisoned-ambient-value failure shape; Cases E-F cover the adjacent invariants (budget-override
# continuity, missing-field self-heal) the fix must not regress.
#
# Structural model: test-skill-base-lifecycle.sh (mktemp -d WORKDIR with an EXIT-trap cleanup,
# deploy-tree-first / source-store-fallback candidate resolution, sourced -- not subprocessed --
# skill-base.sh itself for same-shell cases, pass()/fail()/info() helpers with integer counters,
# exit 0 all-pass / 1 any-fail / 2 environment error).
#
# ISOLATION CONTRACT: every case operates against a guard fixture file under this suite's own
# mktemp -d WORKDIR. The real specs/ tree and .claude/ tree are never written to; a contamination
# guard at the end of this suite confirms the real specs/ tree's git status is unchanged.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (a
# required script was not found at any candidate path).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
# REPO_ROOT resolution must work from BOTH invocation sites this suite supports: the
# source-store copy (agent-system/extensions/core/scripts/tests/) and the deployed copy
# (.claude/scripts/tests/), which sit at different depths below the repo root. Resolve via the
# git worktree root first (depth-independent) and only fall back to the fixed-depth guess
# (matching the source-store depth) when SCRIPT_DIR is not inside a git work tree.
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

# ─── candidate resolution: deployed tree first, source-store fallback ─────────────────────────

SKILL_BASE="$(common_test_resolve_subject "skill-base.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/skill-base.sh" \
  "$SCRIPT_DIR/../skill-base.sh")" || exit 2
common_test_declare_subject "$SKILL_BASE"

PASSED=0
FAILED=0


common_test_info "resolved skill-base.sh: $SKILL_BASE"

common_test_workdir_init

BASELINE_SPECS_STATUS="$(cd "$REPO_ROOT" && git status --short specs/ 2>/dev/null)"

GUARD="$WORKDIR/guard.json"

# shellcheck disable=SC1090
. "$SKILL_BASE"

# =====================================================================
# Case A: fresh shell (ambient dispatch_seq_counter explicitly unset before the first mint in
# this process) -- the exact precondition the pre-fix body assumed and did not hold.
# =====================================================================
common_test_info "=== Case A: fresh shell ==="
unset dispatch_seq_counter
echo '{"dispatch_seq_counter": 1}' > "$GUARD"

result_a="$(skill_orchestrate_mint_dispatch_seq "$GUARD")"
persisted_a="$(jq -r '.dispatch_seq_counter' "$GUARD")"

if [[ "$result_a" == "2" ]]; then
  common_test_pass "Case A: fresh-shell mint against guard counter=1 returns 2 on stdout"
else
  common_test_fail "Case A: expected stdout 2, got '$result_a'"
fi
if [[ "$persisted_a" == "2" ]]; then
  common_test_pass "Case A: fresh-shell mint persists 2 to the guard file"
else
  common_test_fail "Case A: expected persisted .dispatch_seq_counter 2, got '$persisted_a'"
fi

# =====================================================================
# Case B: repeat call in the same shell, same guard -- proves no double-increment and no
# skipped increment now that the ambient variable is stale (holds 2 from Case A) rather than
# unset.
# =====================================================================
common_test_info "=== Case B: repeat call, same shell ==="
result_b="$(skill_orchestrate_mint_dispatch_seq "$GUARD")"
persisted_b="$(jq -r '.dispatch_seq_counter' "$GUARD")"

if [[ "$result_b" == "3" ]]; then
  common_test_pass "Case B: repeat call in the same shell returns 3 on stdout"
else
  common_test_fail "Case B: expected stdout 3, got '$result_b'"
fi
if [[ "$persisted_b" == "3" ]]; then
  common_test_pass "Case B: repeat call persists 3 to the guard file"
else
  common_test_fail "Case B: expected persisted .dispatch_seq_counter 3, got '$persisted_b'"
fi

# =====================================================================
# Case C: poisoned ambient value -- the calling shell holds an ambient dispatch_seq_counter with
# a wrong/stale value (99); the guard file (5) must win. This is the case that pins the fix's
# actual intent: the file is authoritative, the ambient variable is ignored entirely.
# =====================================================================
common_test_info "=== Case C: poisoned ambient value ==="
# shellcheck disable=SC2034  # Deliberately unread by this test script itself -- the whole point
# of this case is to plant a poisoned AMBIENT value that skill_orchestrate_mint_dispatch_seq
# must ignore in favor of the guard file, so the variable's "unused" status here is exactly the
# intended shape, not a mistake.
dispatch_seq_counter=99
echo '{"dispatch_seq_counter": 5}' > "$GUARD"

result_c="$(skill_orchestrate_mint_dispatch_seq "$GUARD")"
persisted_c="$(jq -r '.dispatch_seq_counter' "$GUARD")"

if [[ "$result_c" == "6" ]]; then
  common_test_pass "Case C: poisoned ambient value (99) ignored; guard counter=5 -> stdout 6"
else
  common_test_fail "Case C: expected stdout 6 (guard wins over ambient=99), got '$result_c'"
fi
if [[ "$persisted_c" == "6" ]]; then
  common_test_pass "Case C: poisoned-ambient-value call persists 6 to the guard file"
else
  common_test_fail "Case C: expected persisted .dispatch_seq_counter 6, got '$persisted_c'"
fi
unset dispatch_seq_counter

# =====================================================================
# Case D: genuinely separate subprocess -- two independent `bash -c` invocations that each
# source skill-base.sh afresh, against the same guard file. This is the faithful reproduction of
# the reported multi-tool-call execution shape (each Bash tool call is its own subprocess).
# =====================================================================
common_test_info "=== Case D: genuinely separate subprocess ==="
echo '{"dispatch_seq_counter": 10}' > "$GUARD"

result_d1="$(bash -c "source '$SKILL_BASE'; skill_orchestrate_mint_dispatch_seq '$GUARD'")"
result_d2="$(bash -c "source '$SKILL_BASE'; skill_orchestrate_mint_dispatch_seq '$GUARD'")"

if [[ "$result_d1" == "11" ]]; then
  common_test_pass "Case D: first independent subprocess mint returns 11"
else
  common_test_fail "Case D: expected first subprocess stdout 11, got '$result_d1'"
fi
if [[ "$result_d2" == "12" ]]; then
  common_test_pass "Case D: second independent subprocess mint returns 12 (consecutive, not repeated)"
else
  common_test_fail "Case D: expected second subprocess stdout 12, got '$result_d2'"
fi

# =====================================================================
# Case E: budget-continuation continuity -- a guard shaped like a post-re-init guard that
# preserved a nonzero dispatch_seq_counter (and other cross-invocation history fields) must have
# the next mint continue from it, not restart at 1. Also asserts sibling fields are untouched.
# =====================================================================
common_test_info "=== Case E: budget-continuation continuity ==="
cat > "$GUARD" << 'EOF'
{
  "cycle_count": 0,
  "dispatch_seq_counter": 37,
  "detected_defects": []
}
EOF

result_e="$(skill_orchestrate_mint_dispatch_seq "$GUARD")"
persisted_e="$(jq -r '.dispatch_seq_counter' "$GUARD")"
sibling_cycle_e="$(jq -r '.cycle_count' "$GUARD")"

if [[ "$result_e" == "38" ]]; then
  common_test_pass "Case E: post-re-init guard (counter=37) continues at 38, not restarted at 1"
else
  common_test_fail "Case E: expected stdout 38, got '$result_e'"
fi
if [[ "$persisted_e" == "38" ]]; then
  common_test_pass "Case E: post-re-init guard persists 38"
else
  common_test_fail "Case E: expected persisted .dispatch_seq_counter 38, got '$persisted_e'"
fi
if [[ "$sibling_cycle_e" == "0" ]]; then
  common_test_pass "Case E: sibling field .cycle_count is untouched by the mint"
else
  common_test_fail "Case E: expected .cycle_count to remain 0, got '$sibling_cycle_e'"
fi

# =====================================================================
# Case F: missing-field tolerance -- a guard with no dispatch_seq_counter key at all (a guard
# written before the field existed) must self-heal to 1 via the `// 0` default, not error.
# =====================================================================
common_test_info "=== Case F: missing-field tolerance ==="
echo '{"cycle_count": 0}' > "$GUARD"

result_f="$(skill_orchestrate_mint_dispatch_seq "$GUARD")"
persisted_f="$(jq -r '.dispatch_seq_counter' "$GUARD")"

if [[ "$result_f" == "1" ]]; then
  common_test_pass "Case F: guard with no dispatch_seq_counter key mints 1"
else
  common_test_fail "Case F: expected stdout 1, got '$result_f'"
fi
if [[ "$persisted_f" == "1" ]]; then
  common_test_pass "Case F: guard with no dispatch_seq_counter key persists 1"
else
  common_test_fail "Case F: expected persisted .dispatch_seq_counter 1, got '$persisted_f'"
fi

# =====================================================================
# Contamination guard: the real specs/ tree must be unaffected by this suite's run. Every case
# above operates exclusively against $GUARD under $WORKDIR.
# =====================================================================
common_test_info "=== contamination guard ==="
FINAL_SPECS_STATUS="$(cd "$REPO_ROOT" && git status --short specs/ 2>/dev/null)"
if [[ "$FINAL_SPECS_STATUS" == "$BASELINE_SPECS_STATUS" ]]; then
  common_test_pass "real specs/ tree status is unchanged relative to this suite's pre-run baseline"
else
  common_test_fail "real specs/ tree status changed during this suite (baseline vs. final differ) -- baseline:
$BASELINE_SPECS_STATUS
-- final:
$FINAL_SPECS_STATUS"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
