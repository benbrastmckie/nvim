#!/usr/bin/env bash
# test-orchestrate-batch-admit.sh - Regression suite reproducing the observed A/C/D chain: a
# candidate deferring in_batch against a lower-numbered peer that is itself deferring this cycle,
# even though the deferring peer never actually dispatches and therefore poses no concurrent-write
# hazard. orchestrate-batch-admit.sh's in_batch collision predicate must narrow to "defer only
# against a peer that is ITSELF admitted this cycle" (computed via a greedy ascending-
# project_number walk), not "any lower-numbered peer that merely appears in the argument list".
#
# Never touches the real specs/ tree. Builds a throwaway root satisfying deploy-root-guard.sh's
# ".claude/scripts/ or .opencode/scripts/, two levels under root" check by copying the real
# orchestrate-batch-admit.sh, deploy-root-guard.sh, lib/file-scope-overlap.sh, lib/common.sh,
# lib/task-lookup-lib.sh, and task-lock.sh byte-for-byte into $TMPROOT/.claude/scripts/ (and
# .claude/scripts/lib/), modeled on test-conflict-predicate.sh's isolated-temp-root harness. This
# suite lives under scripts/tests/, so the copy source is $SCRIPT_DIR/.. (the parent scripts/
# directory), not $SCRIPT_DIR itself.
#
# Exit 0 when all cases PASS, exit 1 when any case FAILS (including the expected red baseline
# recorded against the unmodified script during Phase 1 -- see that phase's completion notes for
# the pre-fix output this suite produced).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_SCRIPTS_DIR="$SCRIPT_DIR/.."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  PASSED=$((PASSED + 1))
}

fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  FAILED=$((FAILED + 1))
}

info() {
  echo -e "${YELLOW}[INFO]${NC} $1"
}

# --- Loud-skip discipline: verify all required scripts exist before running anything. ---
REQUIRED_SCRIPTS=(orchestrate-batch-admit.sh deploy-root-guard.sh task-lock.sh lib/file-scope-overlap.sh lib/common.sh lib/task-lookup-lib.sh)
missing=()
for f in "${REQUIRED_SCRIPTS[@]}"; do
  [ -f "$SRC_SCRIPTS_DIR/$f" ] || missing+=("$f")
done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "ERROR: test-orchestrate-batch-admit.sh cannot run -- missing required script(s) alongside this suite's parent directory ($SRC_SCRIPTS_DIR): ${missing[*]}" >&2
  exit 1
fi

# --- Build the isolated temp root ---
TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/batch-admit-test.XXXXXX")"

cleanup() {
  [ -n "${TMPROOT:-}" ] && [ -d "$TMPROOT" ] && rm -rf "$TMPROOT"
}
trap cleanup EXIT

mkdir -p "$TMPROOT/.claude/scripts/lib"
mkdir -p "$TMPROOT/specs/.sessions"
mkdir -p "$TMPROOT/.claude/context/reference"
cp "$SRC_SCRIPTS_DIR/orchestrate-batch-admit.sh" "$TMPROOT/.claude/scripts/orchestrate-batch-admit.sh"
cp "$SRC_SCRIPTS_DIR/deploy-root-guard.sh" "$TMPROOT/.claude/scripts/deploy-root-guard.sh"
cp "$SRC_SCRIPTS_DIR/task-lock.sh" "$TMPROOT/.claude/scripts/task-lock.sh"
cp "$SRC_SCRIPTS_DIR/lib/file-scope-overlap.sh" "$TMPROOT/.claude/scripts/lib/file-scope-overlap.sh"
cp "$SRC_SCRIPTS_DIR/lib/common.sh" "$TMPROOT/.claude/scripts/lib/common.sh"
cp "$SRC_SCRIPTS_DIR/lib/task-lookup-lib.sh" "$TMPROOT/.claude/scripts/lib/task-lookup-lib.sh"
chmod +x "$TMPROOT/.claude/scripts/orchestrate-batch-admit.sh" "$TMPROOT/.claude/scripts/task-lock.sh"
if [ -f "$SRC_SCRIPTS_DIR/../context/reference/orchestrator-critical-paths.json" ]; then
  cp "$SRC_SCRIPTS_DIR/../context/reference/orchestrator-critical-paths.json" "$TMPROOT/.claude/context/reference/orchestrator-critical-paths.json"
fi

BA="$TMPROOT/.claude/scripts/orchestrate-batch-admit.sh"
STATE_FILE="$TMPROOT/specs/state.json"

# =============================================================================
# Case 1/Case 2 fixture: four non-terminal, non-self-modifying candidates A < B < C < D, no
# dependencies[] edges. A and C share one path ("scope/a"); C and D share a DIFFERENT path
# ("scope/c"); D overlaps neither A nor B; B is scope-disjoint from all three.
# =============================================================================
NUM_A=101
NUM_B=102
NUM_C=103
NUM_D=104

cat > "$STATE_FILE" << EOF
{
  "next_project_number": 1000,
  "active_projects": [
    {"project_number": $NUM_A, "project_name": "chain_a", "status": "not_started", "task_type": "general", "file_scope": ["scope/a"], "dependencies": []},
    {"project_number": $NUM_B, "project_name": "chain_b", "status": "not_started", "task_type": "general", "file_scope": ["scope/b"], "dependencies": []},
    {"project_number": $NUM_C, "project_name": "chain_c", "status": "not_started", "task_type": "general", "file_scope": ["scope/a", "scope/c"], "dependencies": []},
    {"project_number": $NUM_D, "project_name": "chain_d", "status": "not_started", "task_type": "general", "file_scope": ["scope/c", "scope/d"], "dependencies": []}
  ]
}
EOF

info "Fixture built at $TMPROOT (A=$NUM_A B=$NUM_B C=$NUM_C D=$NUM_D)"

# =============================================================================
# Case 1: the reported chain. A admits (no lower-numbered collision). C defers on A
# (in_batch, colliding_task_number == A) -- correct both before and after the fix. D must ADMIT:
# its only overlap is with C, and C itself is deferring this cycle (not admitted), so D is not
# blocked by a peer that will never actually dispatch. Pre-fix, D incorrectly defers on C (the
# in_batch predicate tested only "C is lower-numbered and in the argument list", never whether C
# itself was admitted) -- this assertion is the red baseline this suite starts against.
# =============================================================================
out1=$("$BA" --invocation-count 4 "$NUM_A" "$NUM_B" "$NUM_C" "$NUM_D" 2>/dev/null)
v1_a=$(echo "$out1" | jq -c "select(.task_number == $NUM_A)")
v1_b=$(echo "$out1" | jq -c "select(.task_number == $NUM_B)")
v1_c=$(echo "$out1" | jq -c "select(.task_number == $NUM_C)")
v1_d=$(echo "$out1" | jq -c "select(.task_number == $NUM_D)")

c1_ok=true
[ "$(echo "$v1_a" | jq -r '.decision')" = "admit" ] || { c1_ok=false; info "1: A did not admit: $v1_a"; }
[ "$(echo "$v1_b" | jq -r '.decision')" = "admit" ] || { c1_ok=false; info "1: B did not admit: $v1_b"; }
[ "$(echo "$v1_c" | jq -r '.decision')" = "defer" ] || { c1_ok=false; info "1: C did not defer: $v1_c"; }
[ "$(echo "$v1_c" | jq -r '.defer_reason // empty')" = "file_scope_collision" ] || { c1_ok=false; info "1: C's defer_reason was not file_scope_collision: $v1_c"; }
[ "$(echo "$v1_c" | jq -r '.collision_scope // empty')" = "in_batch" ] || { c1_ok=false; info "1: C's collision_scope was not in_batch: $v1_c"; }
[ "$(echo "$v1_c" | jq -r '.colliding_task_number // empty')" = "$NUM_A" ] || { c1_ok=false; info "1: C's colliding_task_number was not A ($NUM_A): $v1_c"; }
[ "$(echo "$v1_d" | jq -r '.decision')" = "admit" ] || { c1_ok=false; info "1: D did not admit despite its only collision (C) being itself deferred this cycle -- this is the reported defect: $v1_d"; }
if [ "$c1_ok" = true ]; then
  pass "1: A admits, C defers on A (in_batch), D admits despite overlapping only the deferring C"
else
  fail "1: reported A/C/D chain case failed (see INFO lines above)"
fi

# =============================================================================
# Case 2: output-ordering contract. Positional arguments passed out of ascending order (D C A B)
# must still be emitted in EXACTLY that caller-argument order -- the admitted-set walk computes
# decisions in ascending project_number order internally, but NDJSON emission must not leak that
# internal ordering.
# =============================================================================
out2=$("$BA" --invocation-count 4 "$NUM_D" "$NUM_C" "$NUM_A" "$NUM_B" 2>/dev/null)
seq2=$(echo "$out2" | jq -r '.task_number' | paste -sd, -)
expected_seq2="$NUM_D,$NUM_C,$NUM_A,$NUM_B"
c2_ok=true
[ "$seq2" = "$expected_seq2" ] || { c2_ok=false; info "2: emitted task_number sequence was '$seq2', expected '$expected_seq2'"; }
if [ "$c2_ok" = true ]; then
  pass "2: NDJSON emission preserves caller-argument order for out-of-ascending-order arguments (D C A B)"
else
  fail "2: output-ordering contract case failed (see INFO lines above)"
fi

# =============================================================================
# Case 3 (symmetry across defer reasons): a self-modification-caused defer must ALSO keep a
# lower-numbered in-batch peer out of the admitted set -- the narrowing is uniform across
# defer_reason values, not special-cased to file_scope_collision alone. A_sm is the designated
# self-modifying candidate (lowest self-modifying number this cycle) and admits; B_sm is a
# co-dispatched self-modifying candidate that defers on the tie-breaker; C_sm is NOT
# self-modifying and overlaps only B_sm's ORDINARY (non-critical) file_scope entry. C_sm must
# admit despite B_sm being lower-numbered and in-batch, because B_sm itself deferred.
# Guarded: skipped gracefully if orchestrator-critical-paths.json is absent or empty in this
# fixture tree, mirroring test-conflict-predicate.sh's Case 2.4 precedent.
# =============================================================================
if [ -f "$TMPROOT/.claude/context/reference/orchestrator-critical-paths.json" ]; then
  crit_path=$(jq -r '(.scope_roots[0] // "") as $r | (.critical_paths[0].path // "") as $p | if $r != "" and $p != "" then ($r + "/" + $p) else "" end' "$TMPROOT/.claude/context/reference/orchestrator-critical-paths.json" 2>/dev/null)
  if [ -n "$crit_path" ]; then
    NUM_A_SM=205
    NUM_B_SM=206
    NUM_C_SM=207
    sm_json=$(jq \
      --argjson na "$NUM_A_SM" --argjson nb "$NUM_B_SM" --argjson nc "$NUM_C_SM" \
      --arg cp "$crit_path" \
      '.active_projects += [
        {"project_number": $na, "project_name": "sm_designated", "status": "not_started", "task_type": "meta", "file_scope": [$cp], "dependencies": []},
        {"project_number": $nb, "project_name": "sm_nondesignated", "status": "not_started", "task_type": "meta", "file_scope": [$cp, "scope/shared"], "dependencies": []},
        {"project_number": $nc, "project_name": "sm_overlap_victim", "status": "not_started", "task_type": "general", "file_scope": ["scope/shared"], "dependencies": []}
      ]' "$STATE_FILE")
    echo "$sm_json" > "$STATE_FILE"

    out3=$("$BA" --invocation-count 3 "$NUM_A_SM" "$NUM_B_SM" "$NUM_C_SM" 2>/dev/null)
    v3_a=$(echo "$out3" | jq -c "select(.task_number == $NUM_A_SM)")
    v3_b=$(echo "$out3" | jq -c "select(.task_number == $NUM_B_SM)")
    v3_c=$(echo "$out3" | jq -c "select(.task_number == $NUM_C_SM)")

    c3_ok=true
    [ "$(echo "$v3_a" | jq -r '.decision')" = "admit" ] || { c3_ok=false; info "3: designated self-modifying A_sm did not admit: $v3_a"; }
    [ "$(echo "$v3_b" | jq -r '.decision')" = "defer" ] || { c3_ok=false; info "3: non-designated self-modifying B_sm did not defer: $v3_b"; }
    [ "$(echo "$v3_b" | jq -r '.defer_reason // empty')" = "self_modifying" ] || { c3_ok=false; info "3: B_sm's defer_reason was not self_modifying: $v3_b"; }
    [ "$(echo "$v3_c" | jq -r '.decision')" = "admit" ] || { c3_ok=false; info "3: C_sm did not admit despite overlapping only the deferring (self_modifying) B_sm -- narrowing must be uniform across defer reasons: $v3_c"; }
    if [ "$c3_ok" = true ]; then
      pass "3: a self_modifying-caused defer also keeps a lower-numbered in-batch peer out of the admitted set"
    else
      fail "3: defer-reason-symmetry case failed (see INFO lines above)"
    fi

    jq --argjson na "$NUM_A_SM" --argjson nb "$NUM_B_SM" --argjson nc "$NUM_C_SM" \
      '.active_projects |= map(select(.project_number != $na and .project_number != $nb and .project_number != $nc))' \
      "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
  else
    info "3: SKIPPED -- orchestrator-critical-paths.json present but empty scope_roots/critical_paths"
  fi
else
  info "3: SKIPPED -- orchestrator-critical-paths.json not found in fixture tree"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
