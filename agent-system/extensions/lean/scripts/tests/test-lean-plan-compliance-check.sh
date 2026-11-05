#!/usr/bin/env bash
# test-lean-plan-compliance-check.sh -- regression suite for lean-plan-compliance-check.sh, the
# plan-compliance spot-check extracted from lean-implementation-agent.md's Final Verification
# Stage step 5.
#
# This suite is deliberately a CHARACTERIZATION suite first: cases C1-C6 pin the extraction's
# pre-existing behaviour (including the colon-anchored Goals range and the absence of a
# reserved-keyword denylist), so a later phase's polarity/denylist changes are visible as
# deliberate diffs rather than silent drift. See the suite's own call site for this task's
# Decision D2.
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
# Case C5 (characterization, pre-existing quirk): a reserved Lean keyword backticked under
# **Goals**: is harvested as a name to find, because this extraction carries NO keyword
# denylist (unlike lean-challenge-snapshot.sh's own extract_goal_names(), which does). A
# backticked `sorry` with no real `sorry` declaration in the source roots is therefore reported
# [MISSING] and the verdict is failed -- pinned here so a later phase's denylist addition is a
# visible, deliberate diff rather than silent drift.
# ===========================================================================
plan_keyword="$WORKDIR/plan_keyword.md"
cat > "$plan_keyword" <<'EOF'
## Goals & Non-Goals

**Goals**:

- `comm` -- uses `sorry` as a placeholder (not itself a Goal, but this extraction harvests it
  anyway -- see this case's own header comment).

**Non-Goals**:

- None.
EOF
out=$(bash "$TOOL_SRC" "$plan_keyword" "$ROOT" 2>&1)
rc=$?
if [ "$rc" -eq 1 ] && echo "$out" | grep -q '^  \[MISSING\] sorry' && echo "$out" | grep -q '^COMPLIANCE_CHECK: failed$'; then
  pass "C5 (characterization): a backticked reserved keyword ('sorry') is harvested as a name to find (no denylist yet) -> [MISSING], failed"
else
  fail "C5: expected the pre-denylist quirk (failed, [MISSING] sorry), got rc=$rc: $out"
fi

# ===========================================================================
# Case C6 (characterization, pre-existing quirk): the Goals-range anchor is COLON-anchored
# (`/^\*\*Goals\*\*:/`) with no parenthetical/colon-optional widening -- unlike
# lean-challenge-snapshot.sh's own (separately widened) START_RE. A parenthesised header
# (`**Goals** (...):`) therefore does NOT establish the range here, and the run is skipped --
# pinned so a later phase's colon-optional widening of THIS script is a visible, deliberate diff.
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
if [ "$rc" -eq 0 ] && echo "$out" | grep -q '^COMPLIANCE_CHECK: skipped'; then
  pass "C6 (characterization): a parenthesised '**Goals** (...):' header does NOT establish the range yet (skipped) -- colon-anchored quirk pinned"
else
  fail "C6: expected skipped (pre-widening quirk) for a parenthesised Goals header, got rc=$rc: $out"
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
