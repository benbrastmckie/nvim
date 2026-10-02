#!/usr/bin/env bash
# test-orchestrate-batch-admit.sh - Regression suite covering TWO defects:
#
#   (1) The original A/C/D chain: a candidate deferring in_batch against a lower-numbered peer
#       that is itself deferring this cycle, even though the deferring peer never actually
#       dispatches and therefore poses no concurrent-write hazard. orchestrate-batch-admit.sh's
#       in_batch collision predicate must narrow to "defer only against a peer that is ITSELF
#       admitted this cycle" (computed via a greedy ascending-project_number walk), not "any
#       lower-numbered peer that merely appears in the argument list". Cases 1-3 below.
#
#   (2) Admission posture for an ABSENT file_scope, plus cross-session visibility for a solo
#       self-modifying candidate (the split ruling recorded in this script's own header): an
#       absent/null/empty file_scope is currently indistinguishable from a scope that provably
#       collides with nothing, and a solo self-modifying candidate's verdict carries no
#       cross-session collision result at all even when a live foreign session's covered scope
#       overlaps it. Cases IN-BATCH-ABSENCE, CROSS-BATCH-ABSENCE, SOLO-SELF-MOD-CROSS-SESSION,
#       PHASE-EXEMPT-ABSENCE, and the $schema-literal pin below.
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
# Fixture case: IN-BATCH-ABSENCE -- 8 non-terminal co-dispatched candidates, every one with an
# absent file_scope (missing key, literal null, or empty array -- all three sub-states mixed).
# Reproduces the observed 8-task in-batch incident: orchestrate-batch-admit.sh currently admits
# all 8 with zero defers, because the absent-scope early-exit branch short-circuits before the
# collision scan (or any new absent-scope-aware defer) ever runs.
# =============================================================================
NUM_IA1=301
NUM_IA2=302
NUM_IA3=303
NUM_IA4=304
NUM_IA5=305
NUM_IA6=306
NUM_IA7=307
NUM_IA8=308

ia_json=$(jq \
  --argjson n1 "$NUM_IA1" --argjson n2 "$NUM_IA2" --argjson n3 "$NUM_IA3" --argjson n4 "$NUM_IA4" \
  --argjson n5 "$NUM_IA5" --argjson n6 "$NUM_IA6" --argjson n7 "$NUM_IA7" --argjson n8 "$NUM_IA8" \
  '.active_projects += [
    {"project_number": $n1, "project_name": "ia_missing_1", "status": "not_started", "task_type": "general", "dependencies": []},
    {"project_number": $n2, "project_name": "ia_null_1", "status": "not_started", "task_type": "general", "file_scope": null, "dependencies": []},
    {"project_number": $n3, "project_name": "ia_empty_1", "status": "not_started", "task_type": "general", "file_scope": [], "dependencies": []},
    {"project_number": $n4, "project_name": "ia_missing_2", "status": "not_started", "task_type": "general", "dependencies": []},
    {"project_number": $n5, "project_name": "ia_null_2", "status": "not_started", "task_type": "general", "file_scope": null, "dependencies": []},
    {"project_number": $n6, "project_name": "ia_empty_2", "status": "not_started", "task_type": "general", "file_scope": [], "dependencies": []},
    {"project_number": $n7, "project_name": "ia_missing_3", "status": "not_started", "task_type": "general", "dependencies": []},
    {"project_number": $n8, "project_name": "ia_null_3", "status": "not_started", "task_type": "general", "file_scope": null, "dependencies": []}
  ]' "$STATE_FILE")
echo "$ia_json" > "$STATE_FILE"

# TDD red/green convention (see this suite's header): this assertion checks the TARGET
# post-fix posture from the start -- exactly one admit (the lowest-numbered candidate) and seven
# `absent_file_scope` defers, each naming the admitted candidate as `designated_absent_candidate`
# and carrying none of the file_scope_collision-only fields. It is EXPECTED TO FAIL against
# today's unmodified script (which currently admits all 8, zero defers -- the
# Logos/Verification 8-task incident) and is expected to start PASSING once Phase 3 lands the
# designated-absent-candidate tie-breaker and the new defer_reason. Not yet flipped by any later
# phase -- this IS the final-form assertion.
out_ia=$("$BA" --invocation-count 8 "$NUM_IA1" "$NUM_IA2" "$NUM_IA3" "$NUM_IA4" "$NUM_IA5" "$NUM_IA6" "$NUM_IA7" "$NUM_IA8" 2>/dev/null)
ia_admit_count=$(echo "$out_ia" | jq -r '.decision' | grep -c '^admit$' || true)
ia_defer_count=$(echo "$out_ia" | jq -r '.decision' | grep -c '^defer$' || true)
ia_admit_task=$(echo "$out_ia" | jq -r 'select(.decision == "admit") | .task_number')
ia_wrong_reason=$(echo "$out_ia" | jq -r 'select(.decision == "defer") | select(.defer_reason != "absent_file_scope") | .task_number' | grep -c . || true)
ia_stray_collision_fields=$(echo "$out_ia" | jq -r 'select(.decision == "defer") | select(has("colliding_task_number") or has("overlapping_path") or has("collision_scope") or has("corroborated_by")) | .task_number' | grep -c . || true)
ia_designated_mismatch=$(echo "$out_ia" | jq -r --argjson expect "$NUM_IA1" 'select(.decision == "defer") | select((.designated_absent_candidate // -1) != $expect) | .task_number' | grep -c . || true)

ia_ok=true
[ "$ia_admit_count" = "1" ] || { ia_ok=false; info "IN-BATCH-ABSENCE: expected 1 admit, got $ia_admit_count (out: $out_ia)"; }
[ "$ia_defer_count" = "7" ] || { ia_ok=false; info "IN-BATCH-ABSENCE: expected 7 defers, got $ia_defer_count (out: $out_ia)"; }
[ "$ia_admit_task" = "$NUM_IA1" ] || { ia_ok=false; info "IN-BATCH-ABSENCE: expected the lowest-numbered candidate ($NUM_IA1) to admit, got '$ia_admit_task' (out: $out_ia)"; }
[ "$ia_wrong_reason" = "0" ] || { ia_ok=false; info "IN-BATCH-ABSENCE: $ia_wrong_reason defer(s) lacked defer_reason == absent_file_scope (out: $out_ia)"; }
[ "$ia_stray_collision_fields" = "0" ] || { ia_ok=false; info "IN-BATCH-ABSENCE: $ia_stray_collision_fields defer(s) carried a file_scope_collision-only field (out: $out_ia)"; }
[ "$ia_designated_mismatch" = "0" ] || { ia_ok=false; info "IN-BATCH-ABSENCE: $ia_designated_mismatch defer(s) named the wrong designated_absent_candidate (expected $NUM_IA1) (out: $out_ia)"; }
if [ "$ia_ok" = true ]; then
  pass "IN-BATCH-ABSENCE: lowest-numbered absent-scope candidate admits, the other 7 defer with absent_file_scope (the Logos/Verification 8-task incident)"
else
  fail "IN-BATCH-ABSENCE: target-posture assertion failed -- EXPECTED until Phase 3 lands the absent_file_scope defer_reason (see INFO lines above)"
fi

jq --argjson n1 "$NUM_IA1" --argjson n2 "$NUM_IA2" --argjson n3 "$NUM_IA3" --argjson n4 "$NUM_IA4" \
   --argjson n5 "$NUM_IA5" --argjson n6 "$NUM_IA6" --argjson n7 "$NUM_IA7" --argjson n8 "$NUM_IA8" \
  '.active_projects |= map(select(
      .project_number != $n1 and .project_number != $n2 and .project_number != $n3 and
      .project_number != $n4 and .project_number != $n5 and .project_number != $n6 and
      .project_number != $n7 and .project_number != $n8
    ))' \
  "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

# =============================================================================
# Fixture case: CROSS-BATCH-ABSENCE -- one absent-scope candidate, one OUT-OF-BATCH task
# (status "implementing", broad declared scope) that is NOT a positional argument. Reproduces
# the cross-session incident: the current bare admit carries no advisory naming the suppressed
# overlap because the absent-scope early-exit branch never reaches the collision scan at all.
# =============================================================================
NUM_CBA=309
NUM_CBA_OTHER=310

cba_json=$(jq \
  --argjson nc "$NUM_CBA" --argjson no "$NUM_CBA_OTHER" \
  '.active_projects += [
    {"project_number": $nc, "project_name": "cba_candidate", "status": "not_started", "task_type": "general", "dependencies": []},
    {"project_number": $no, "project_name": "cba_other_broad_scope", "status": "implementing", "task_type": "general", "file_scope": ["FormalSystem/", "Tests/", "docs/", "typst/", "README.md"], "dependencies": []}
  ]' "$STATE_FILE")
echo "$cba_json" > "$STATE_FILE"

# TDD red/green convention: checks the TARGET post-fix posture (decision stays "admit" -- this
# is the deliberate advisory-only ruling, never blocking -- but the verdict must additionally
# carry absent_scope_advisory naming the missing_key sub-state and no defer_reason). EXPECTED TO
# FAIL against today's unmodified script (the field does not exist yet) and expected to start
# PASSING once Phase 2 lands the advisory field.
out_cba=$("$BA" --invocation-count 1 "$NUM_CBA" 2>/dev/null)
v_cba=$(echo "$out_cba" | jq -c "select(.task_number == $NUM_CBA)")

cba_ok=true
[ "$(echo "$v_cba" | jq -r '.decision')" = "admit" ] || { cba_ok=false; info "CROSS-BATCH-ABSENCE: candidate did not admit: $v_cba"; }
[ "$(echo "$v_cba" | jq -r '.absent_scope_advisory.scope_state // "MISSING"')" = "missing_key" ] || { cba_ok=false; info "CROSS-BATCH-ABSENCE: absent_scope_advisory.scope_state was not \"missing_key\": $v_cba"; }
[ "$(echo "$v_cba" | jq -r 'has("defer_reason")')" = "false" ] || { cba_ok=false; info "CROSS-BATCH-ABSENCE: unexpectedly carries defer_reason (this ruling never blocks cross-batch absence): $v_cba"; }
if [ "$cba_ok" = true ]; then
  pass "CROSS-BATCH-ABSENCE: absent-scope candidate admits (deliberate advisory-only ruling) carrying absent_scope_advisory naming the missing_key sub-state (the BimodalLogic cross-batch incident)"
else
  fail "CROSS-BATCH-ABSENCE: target-posture assertion failed -- EXPECTED until Phase 2 lands the absent_scope_advisory field (see INFO lines above)"
fi

jq --argjson nc "$NUM_CBA" --argjson no "$NUM_CBA_OTHER" \
  '.active_projects |= map(select(.project_number != $nc and .project_number != $no))' \
  "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

# =============================================================================
# Fixture case: SOLO-SELF-MOD-CROSS-SESSION -- a solo self-modifying candidate whose verdict
# today carries NO cross-session collision result even when a live foreign session's covered
# scope overlaps it (the absorbed cross-session-blindness probe: two live registered sessions
# whose covered scopes overlap, each pinned to this test script's OWN pid via --pid $$ so
# session_liveness reports "pid-alive" for the full duration of this suite). Guarded exactly like
# Case 3 above: skipped gracefully if orchestrator-critical-paths.json is absent or empty in this
# fixture tree.
# =============================================================================
if [ -f "$TMPROOT/.claude/context/reference/orchestrator-critical-paths.json" ]; then
  crit_path_scs=$(jq -r '(.scope_roots[0] // "") as $r | (.critical_paths[0].path // "") as $p | if $r != "" and $p != "" then ($r + "/" + $p) else "" end' "$TMPROOT/.claude/context/reference/orchestrator-critical-paths.json" 2>/dev/null)
  if [ -n "$crit_path_scs" ]; then
    NUM_SCS_CAND=320
    NUM_SCS_FOREIGN_TASK=321

    scs_json=$(jq \
      --argjson ncand "$NUM_SCS_CAND" --argjson nforeign "$NUM_SCS_FOREIGN_TASK" \
      --arg cp "$crit_path_scs" \
      '.active_projects += [
        {"project_number": $ncand, "project_name": "scs_candidate", "status": "not_started", "task_type": "meta", "file_scope": [$cp], "dependencies": []},
        {"project_number": $nforeign, "project_name": "scs_foreign_covered", "status": "not_started", "task_type": "meta", "file_scope": [$cp], "dependencies": []}
      ]' "$STATE_FILE")
    echo "$scs_json" > "$STATE_FILE"

    OWN_SID="sess_scsowntest_000001"
    FOREIGN_SID="sess_scsforeigntest_000002"
    "$TMPROOT/.claude/scripts/task-lock.sh" session-register "$OWN_SID" "/orchestrate $NUM_SCS_CAND" "$NUM_SCS_CAND" --pid $$ >/dev/null 2>&1 || true
    "$TMPROOT/.claude/scripts/task-lock.sh" session-register "$FOREIGN_SID" "/orchestrate $NUM_SCS_FOREIGN_TASK" "$NUM_SCS_FOREIGN_TASK" --pid $$ >/dev/null 2>&1 || true

    # TDD red/green convention: checks the TARGET post-fix posture (decision stays "admit",
    # self_modifying stays true -- this fix never changes the decision -- but the verdict must
    # additionally carry cross_session_hazard naming the foreign session and the overlapping
    # path). EXPECTED TO FAIL against today's unmodified script (the field does not exist yet)
    # and expected to start PASSING once Phase 4 lands it.
    out_scs=$("$BA" --invocation-count 1 --session-id "$OWN_SID" "$NUM_SCS_CAND" 2>/dev/null)
    v_scs=$(echo "$out_scs" | jq -c "select(.task_number == $NUM_SCS_CAND)")

    scs_ok=true
    [ "$(echo "$v_scs" | jq -r '.decision')" = "admit" ] || { scs_ok=false; info "SOLO-SELF-MOD-CROSS-SESSION: did not admit: $v_scs"; }
    [ "$(echo "$v_scs" | jq -r '.self_modifying')" = "true" ] || { scs_ok=false; info "SOLO-SELF-MOD-CROSS-SESSION: self_modifying was not true: $v_scs"; }
    [ "$(echo "$v_scs" | jq -r '.cross_session_hazard.session_id // "MISSING"')" = "$FOREIGN_SID" ] || { scs_ok=false; info "SOLO-SELF-MOD-CROSS-SESSION: cross_session_hazard.session_id did not name the foreign session ($FOREIGN_SID): $v_scs"; }
    [ "$(echo "$v_scs" | jq -r '.cross_session_hazard.overlapping_path // "MISSING"')" = "$crit_path_scs" ] || { scs_ok=false; info "SOLO-SELF-MOD-CROSS-SESSION: cross_session_hazard.overlapping_path did not name $crit_path_scs: $v_scs"; }
    [ "$(echo "$v_scs" | jq -r 'has("defer_reason")')" = "false" ] || { scs_ok=false; info "SOLO-SELF-MOD-CROSS-SESSION: unexpectedly carries defer_reason (a solo self-modifying candidate must never defer): $v_scs"; }
    if [ "$scs_ok" = true ]; then
      pass "SOLO-SELF-MOD-CROSS-SESSION: solo self-modifying candidate admits carrying cross_session_hazard naming the foreign session's overlapping covered scope (the cross-session-blindness probe)"
    else
      fail "SOLO-SELF-MOD-CROSS-SESSION: target-posture assertion failed -- EXPECTED until Phase 4 lands the cross_session_hazard field (see INFO lines above)"
    fi

    rm -f "$TMPROOT/specs/.sessions/${OWN_SID}.json" "$TMPROOT/specs/.sessions/${FOREIGN_SID}.json" 2>/dev/null || true
    jq --argjson ncand "$NUM_SCS_CAND" --argjson nforeign "$NUM_SCS_FOREIGN_TASK" \
      '.active_projects |= map(select(.project_number != $ncand and .project_number != $nforeign))' \
      "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
  else
    info "SOLO-SELF-MOD-CROSS-SESSION: SKIPPED -- orchestrator-critical-paths.json present but empty scope_roots/critical_paths"
  fi
else
  info "SOLO-SELF-MOD-CROSS-SESSION: SKIPPED -- orchestrator-critical-paths.json not found in fixture tree"
fi

# =============================================================================
# Fixture case: PHASE-EXEMPT-ABSENCE -- an absent-scope candidate co-dispatched with a second,
# ordinary candidate under a --phase-map mapping it to "plan". This case is NOT a red baseline:
# the current script's absent-scope early-exit branch admits unconditionally regardless of
# --phase-map or --invocation-count, so it is already green today. It MUST stay green across
# every later phase in this plan -- the false-positive guard that a research/plan dispatch should
# never be blocked merely because its IMPLEMENTATION footprint happens to be absent/declared.
# =============================================================================
NUM_PEA=330
NUM_PEA2=331

pea_json=$(jq \
  --argjson np "$NUM_PEA" --argjson np2 "$NUM_PEA2" \
  '.active_projects += [
    {"project_number": $np, "project_name": "pea_candidate", "status": "not_started", "task_type": "general", "dependencies": []},
    {"project_number": $np2, "project_name": "pea_sibling", "status": "not_started", "task_type": "general", "file_scope": ["scope/pea2"], "dependencies": []}
  ]' "$STATE_FILE")
echo "$pea_json" > "$STATE_FILE"

out_pea=$("$BA" --invocation-count 2 --phase-map "${NUM_PEA}:plan" "$NUM_PEA" "$NUM_PEA2" 2>/dev/null)
v_pea=$(echo "$out_pea" | jq -c "select(.task_number == $NUM_PEA)")

pea_ok=true
[ "$(echo "$v_pea" | jq -r '.decision')" = "admit" ] || { pea_ok=false; info "PHASE-EXEMPT-ABSENCE: candidate did not admit: $v_pea"; }
if [ "$pea_ok" = true ]; then
  pass "PHASE-EXEMPT-ABSENCE: an absent-scope candidate mapped to the plan phase group still admits (forward-looking false-positive guard)"
else
  fail "PHASE-EXEMPT-ABSENCE: false-positive guard failed (see INFO lines above)"
fi

jq --argjson np "$NUM_PEA" --argjson np2 "$NUM_PEA2" \
  '.active_projects |= map(select(.project_number != $np and .project_number != $np2))' \
  "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

# =============================================================================
# Fixture case: schema-literal pin -- exactly ONE assertion in this suite reads the raw $schema
# string value. Every other new assertion added by this phase reads decision/defer_reason/field
# presence only, per this suite's own documented convention (see the header's two-defect list).
# =============================================================================
out_schema=$("$BA" --invocation-count 1 "$NUM_A" 2>/dev/null)
schema_ok=true
[ "$(echo "$out_schema" | jq -r '."$schema"')" = "orchestrate-batch-admit-v5" ] || { schema_ok=false; info "SCHEMA-LITERAL: schema was not v5: $out_schema"; }
if [ "$schema_ok" = true ]; then
  pass "SCHEMA-LITERAL: \$schema reads orchestrate-batch-admit-v5 (will be bumped to v6 in a later phase)"
else
  fail "SCHEMA-LITERAL: schema-literal pin failed (see INFO lines above)"
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
