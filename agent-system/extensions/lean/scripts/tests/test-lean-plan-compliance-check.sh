#!/usr/bin/env bash
# test-lean-plan-compliance-check.sh -- regression suite for lean-plan-compliance-check.sh, the
# plan-compliance spot-check extracted from lean-implementation-agent.md's Final Verification
# Stage step 5.
#
# This suite is deliberately a CHARACTERIZATION suite first: cases C1-C6 pin the extraction's
# pre-existing behaviour. Cases C5 and C6 are now SUPERSEDED (explicitly, not silently
# re-baselined) by a later phase's reserved-keyword denylist and colon-optional Goals-range
# widening respectively -- see each case's own header comment. Cases C9-C13 cover that same
# later phase's additions: refutation polarity passing (C9) and failing (C10) on a genuinely
# absent/present identifier, a must-exist plan unaffected by the new field's absence (C11), an
# explicitly declared non-refutation polarity value skipping rather than guessing (C12), and the
# archived refutation plan's own Goals shape reproducing the original symptom as a regression
# (C13: failed without the polarity declaration, passed with it). See the suite's own call site
# for this task's Decision D2.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_SRC="$SCRIPT_DIR/../lean-plan-compliance-check.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }

if [ ! -f "$TOOL_SRC" ]; then
  echo "ERROR: expected lean-plan-compliance-check.sh at $TOOL_SRC" >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

ROOT="$WORKDIR/root"
mkdir -p "$ROOT"
cat > "$ROOT/Basic.lean" <<'EOF'
theorem comm (n m : Nat) : n + m = m + n := sorry

theorem assoc (n m k : Nat) : (n + m) + k = n + (m + k) := sorry

theorem newProof (n : Nat) : n = n := by
  exact oldProof n
EOF

# ===========================================================================
# Case C1: a must-exist plan whose Goals block names a real declaration -> passed, [OK] line.
# ===========================================================================
plan_pass="$WORKDIR/plan_pass.md"
cat > "$plan_pass" <<'EOF'
## Goals & Non-Goals

**Goals**:

- `comm` -- commutativity of addition.

**Non-Goals**:

- None.
EOF
out=$(bash "$TOOL_SRC" "$plan_pass" "$ROOT" 2>&1)
rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -q '^  \[OK\] comm' && echo "$out" | grep -q '^COMPLIANCE_CHECK: passed$'; then
  pass "C1: must-exist plan with a real declaration -> passed, [OK] line, exit 0"
else
  fail "C1: expected passed/exit 0 with an [OK] line for comm, got rc=$rc: $out"
fi

# ===========================================================================
# Case C2: a must-exist plan naming a genuinely missing declaration -> failed, [MISSING] line,
# exit 1. This is the behaviour-preservation pair's "has a genuinely missing declaration" fixture.
# ===========================================================================
plan_missing="$WORKDIR/plan_missing.md"
cat > "$plan_missing" <<'EOF'
## Goals & Non-Goals

**Goals**:

- `comm` -- commutativity of addition.
- `nonexistentName` -- deliberately absent from the source root.

**Non-Goals**:

- None.
EOF
out=$(bash "$TOOL_SRC" "$plan_missing" "$ROOT" 2>&1)
rc=$?
if [ "$rc" -eq 1 ] && echo "$out" | grep -q '^  \[MISSING\] nonexistentName' && echo "$out" | grep -q '^COMPLIANCE_CHECK: failed$'; then
  pass "C2: must-exist plan with a genuinely missing declaration -> failed, [MISSING] line, exit 1"
else
  fail "C2: expected failed/exit 1 with a [MISSING] line for nonexistentName, got rc=$rc: $out"
fi

# ===========================================================================
# Case C3: no plan file (nonexistent path) -> skipped, exit 0 -- never a hard crash.
# ===========================================================================
out=$(bash "$TOOL_SRC" "$WORKDIR/does_not_exist.md" "$ROOT" 2>&1)
rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -q '^COMPLIANCE_CHECK: skipped'; then
  pass "C3: nonexistent plan file -> skipped, exit 0"
else
  fail "C3: expected skipped/exit 0 for a nonexistent plan file, got rc=$rc: $out"
fi

# ===========================================================================
# Case C4: a Goals block with no backticked identifiers -> skipped, exit 0.
# ===========================================================================
plan_empty="$WORKDIR/plan_empty.md"
cat > "$plan_empty" <<'EOF'
## Goals & Non-Goals

**Goals**:

No backticked identifiers in this block at all.

**Non-Goals**:

- None.
EOF
out=$(bash "$TOOL_SRC" "$plan_empty" "$ROOT" 2>&1)
rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -q '^COMPLIANCE_CHECK: skipped'; then
  pass "C4: a Goals block with no backticked identifiers -> skipped, exit 0"
else
  fail "C4: expected skipped/exit 0 for an identifier-free Goals block, got rc=$rc: $out"
fi

# ===========================================================================
# Case C5 -- SUPERSEDED by this phase's reserved-keyword denylist (recorded explicitly, not
# silently re-baselined): the pre-Phase-6 quirk asserted a backticked `sorry` was harvested as a
# name to find ([MISSING], failed). The denylist now excludes it; with only `comm` (a real
# declaration in ROOT) remaining after the denylist subtracts `sorry`, the verdict is now passed.
# ===========================================================================
plan_keyword="$WORKDIR/plan_keyword.md"
cat > "$plan_keyword" <<'EOF'
## Goals & Non-Goals

**Goals**:

- `comm` -- uses `sorry` as a placeholder (not itself a Goal; the denylist now excludes it from
  the harvest -- see this case's own header comment).

**Non-Goals**:

- None.
EOF
out=$(bash "$TOOL_SRC" "$plan_keyword" "$ROOT" 2>&1)
rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -q '^  \[OK\] comm' && ! echo "$out" | grep -q 'sorry' && echo "$out" | grep -q '^COMPLIANCE_CHECK: passed$'; then
  pass "C5 (superseded by Phase 6 denylist): a backticked reserved keyword ('sorry') is no longer harvested -> comm alone is checked, passed"
else
  fail "C5: expected the denylist to exclude 'sorry' (passed, [OK] comm only), got rc=$rc: $out"
fi

# ===========================================================================
# Case C6 -- SUPERSEDED by this phase's colon-optional Goals-range widening (recorded
# explicitly, not silently re-baselined): the pre-Phase-6 quirk asserted a parenthesised
# `**Goals** (...):` header did NOT establish the range (skipped). It now does, matching
# lean-challenge-snapshot.sh's own START_RE widening, and `comm` is found and passes.
# ===========================================================================
plan_paren="$WORKDIR/plan_paren.md"
cat > "$plan_paren" <<'EOF'
## Goals & Non-Goals

**Goals** (identifier set equals the declaration below):

- `comm` -- commutativity of addition.

**Non-Goals**:

- None.
EOF
out=$(bash "$TOOL_SRC" "$plan_paren" "$ROOT" 2>&1)
rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -q '^  \[OK\] comm' && echo "$out" | grep -q '^COMPLIANCE_CHECK: passed$'; then
  pass "C6 (superseded by Phase 6 colon-optional widening): a parenthesised '**Goals** (...):' header now establishes the range -> comm found, passed"
else
  fail "C6: expected the widened range to find comm (passed), got rc=$rc: $out"
fi

# ===========================================================================
# Case C9: refutation polarity, all named identifiers genuinely absent -> passed.
# ===========================================================================
plan_refutation_pass="$WORKDIR/plan_refutation_pass.md"
cat > "$plan_refutation_pass" <<'EOF'
## Goals & Non-Goals

- **Goal Polarity**: refutation

**Goals**:

- `badLemma` -- must not exist anywhere in the tree.

**Non-Goals**:

- None.
EOF
out=$(bash "$TOOL_SRC" "$plan_refutation_pass" "$ROOT" 2>&1)
rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -q '^  \[OK\] badLemma' && echo "$out" | grep -q '^COMPLIANCE_CHECK: passed$'; then
  pass "C9: refutation polarity with all named identifiers genuinely absent -> passed"
else
  fail "C9: expected passed for a refutation plan with all identifiers absent, got rc=$rc: $out"
fi

# ===========================================================================
# Case C10: refutation polarity, one named identifier present (it must not be) -> failed,
# naming it with [PRESENT].
# ===========================================================================
plan_refutation_fail="$WORKDIR/plan_refutation_fail.md"
cat > "$plan_refutation_fail" <<'EOF'
## Goals & Non-Goals

- **Goal Polarity**: refutation

**Goals**:

- `comm` -- must not exist anywhere in the tree (but it does, in ROOT).

**Non-Goals**:

- None.
EOF
out=$(bash "$TOOL_SRC" "$plan_refutation_fail" "$ROOT" 2>&1)
rc=$?
if [ "$rc" -eq 1 ] && echo "$out" | grep -q '^  \[PRESENT\] comm' && echo "$out" | grep -q '^COMPLIANCE_CHECK: failed$'; then
  pass "C10: refutation polarity with one named identifier present -> failed, naming it [PRESENT]"
else
  fail "C10: expected failed naming comm as [PRESENT], got rc=$rc: $out"
fi

# ===========================================================================
# Case C11: a must-exist plan (no Goal Polarity field at all) is unaffected by the new field's
# absence -- re-confirms the C1 characterization case still passes identically.
# ===========================================================================
out=$(bash "$TOOL_SRC" "$plan_pass" "$ROOT" 2>&1)
rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -q '^  \[OK\] comm' && echo "$out" | grep -q '^COMPLIANCE_CHECK: passed$'; then
  pass "C11: a must-exist plan with no Goal Polarity field is unaffected (still passed, [OK] comm)"
else
  fail "C11: expected the C1 must-exist case to still pass unaffected, got rc=$rc: $out"
fi

# ===========================================================================
# Case C12: mixed polarity -- a plan that explicitly declares a non-"refutation" Goal Polarity
# value (e.g. "mixed") cannot be expressed by this single global field, so the script records
# skipped with a stated reason rather than guessing must-exist or must-be-absent.
# ===========================================================================
plan_mixed="$WORKDIR/plan_mixed.md"
cat > "$plan_mixed" <<'EOF'
## Goals & Non-Goals

- **Goal Polarity**: mixed

**Goals**:

- `comm`, `badLemma`.

**Non-Goals**:

- None.
EOF
out=$(bash "$TOOL_SRC" "$plan_mixed" "$ROOT" 2>&1)
rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -q '^COMPLIANCE_CHECK: skipped'; then
  pass "C12: an explicitly declared non-refutation Goal Polarity value ('mixed') -> skipped with a stated reason"
else
  fail "C12: expected skipped for a declared 'mixed' polarity, got rc=$rc: $out"
fi

# ===========================================================================
# Case C13 (regression): the archived refutation plan's actual Goals shape
# (specs/archive/805_jointly_derived_cell_index_gate/plans/02_joint-index-gate-closeout.md,
# re-derived at test-authoring time rather than hand-typed: box, LadderCons,
# ladderCons_localRun, ladderRealized, sorry, stab) produces `failed` under the pre-fix script
# (no polarity support -- every name reported [MISSING] against an empty source root) and
# `passed` under the fixed one once a Goal Polarity: refutation line is present.
# ===========================================================================
plan_805="$WORKDIR/plan_805.md"
cat > "$plan_805" <<'EOF'
## Goals & Non-Goals

**Goals**:
- Attest mechanically that no weakened, same-named substitute for `ladderRealized`, `LadderCons`
  or `ladderCons_localRun` was published anywhere, under that name or another, and that the
  `box`/`stab` clause is untouched, and that the probe compiles `sorry`-free.

**Non-Goals**:
- None.
EOF
plan_805_no_polarity="$WORKDIR/plan_805_no_polarity.md"
cp "$plan_805" "$plan_805_no_polarity"
plan_805_with_polarity="$WORKDIR/plan_805_with_polarity.md"
sed '/^\*\*Goals\*\*:/i - **Goal Polarity**: refutation' "$plan_805" > "$plan_805_with_polarity"

EMPTY_ROOT="$WORKDIR/empty_root"
mkdir -p "$EMPTY_ROOT"
: > "$EMPTY_ROOT/Placeholder.lean"

out_nopol=$(bash "$TOOL_SRC" "$plan_805_no_polarity" "$EMPTY_ROOT" 2>&1)
rc_nopol=$?
out_withpol=$(bash "$TOOL_SRC" "$plan_805_with_polarity" "$EMPTY_ROOT" 2>&1)
rc_withpol=$?
if [ "$rc_nopol" -eq 1 ] && echo "$out_nopol" | grep -q '^COMPLIANCE_CHECK: failed$' \
   && [ "$rc_withpol" -eq 0 ] && echo "$out_withpol" | grep -q '^COMPLIANCE_CHECK: passed$'; then
  pass "C13 (regression): the archived refutation plan's real Goals shape -> failed without polarity, passed with it declared"
else
  fail "C13: expected failed (no polarity, rc=$rc_nopol) then passed (with polarity, rc=$rc_withpol)" "no-polarity: $out_nopol
with-polarity: $out_withpol"
fi

# ===========================================================================
# Case C7: the replacement_targets integrity sweep -- a plan whose prose names the NEW goal as a
# replacement for an OLD identifier, where the new declaration's body still mentions the old
# name (a stale delegation), is caught as [INTEGRITY FAIL] and fails even though the [OK]/
# [MISSING] sweep alone would have passed.
# ===========================================================================
plan_integrity="$WORKDIR/plan_integrity.md"
cat > "$plan_integrity" <<'EOF'
## Goals & Non-Goals

**Goals**:

- `newProof` -- replacement for `oldProof`.

**Non-Goals**:

- None.
EOF
out=$(bash "$TOOL_SRC" "$plan_integrity" "$ROOT" 2>&1)
rc=$?
if [ "$rc" -eq 1 ] && echo "$out" | grep -q '^  \[INTEGRITY FAIL\] newProof delegates to oldProof' && echo "$out" | grep -q '^COMPLIANCE_CHECK: failed$'; then
  pass "C7: a new declaration that still delegates to its stated replacement target -> [INTEGRITY FAIL], failed"
else
  fail "C7: expected an [INTEGRITY FAIL] line and failed verdict, got rc=$rc: $out"
fi

# ===========================================================================
# Case C8: usage error -- fewer than two arguments (no lean_root given) -> exit 2.
# ===========================================================================
out=$(bash "$TOOL_SRC" "$plan_pass" 2>&1)
rc=$?
if [ "$rc" -eq 2 ]; then
  pass "C8: missing lean_root argument -> exit 2 (usage error)"
else
  fail "C8: expected exit 2 for a missing lean_root argument, got rc=$rc: $out"
fi

echo ""
echo "================================================================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================================================================"

[ "$FAILED" -eq 0 ] && exit 0 || exit 1
