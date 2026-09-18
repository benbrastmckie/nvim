#!/usr/bin/env bash
# test-conflict-predicate.sh - Isolated-temp-root suite pinning the converged conflict-detection
# predicate: the shared lib (scripts/lib/file-scope-overlap.sh), task-lock.sh's cmd_acquire
# session pass, and orchestrate-batch-admit.sh's v4 session_active/corroborated_by additions.
#
# Never touches the real specs/ tree. Builds a throwaway root satisfying deploy-root-guard.sh's
# ".claude/scripts/ or .opencode/scripts/, two levels under root" check by copying the real
# task-lock.sh, orchestrate-batch-admit.sh, deploy-root-guard.sh, and
# lib/file-scope-overlap.sh byte-for-byte into $TMPROOT/.claude/scripts/ (and
# $TMPROOT/.claude/scripts/lib/), alongside fixture state.json and specs/.sessions/ entries at
# controlled epoch timestamps -- no sleeping. Modeled directly on test-session-registry.sh's and
# test-task-lock-reap.sh's precedent (temp-root construction, pass/fail/info helpers, cleanup
# trap). No testability hooks are added to production code anywhere in this suite.
#
# Exit 0 when all cases PASS, exit 1 when any case FAILS.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# --- Locate the real scripts this suite copies byte-for-byte ---
for req in task-lock.sh orchestrate-batch-admit.sh deploy-root-guard.sh lib/file-scope-overlap.sh lib/common.sh lib/task-lookup-lib.sh; do
  if [ ! -f "$SCRIPT_DIR/$req" ]; then
    echo "ERROR: expected $req alongside this script in $SCRIPT_DIR" >&2
    exit 1
  fi
done

# --- Build the isolated temp root ---
TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/conflict-predicate-test.XXXXXX")"

cleanup() {
  [ -n "${TMPROOT:-}" ] && [ -d "$TMPROOT" ] && rm -rf "$TMPROOT"
}
trap cleanup EXIT

mkdir -p "$TMPROOT/.claude/scripts/lib"
mkdir -p "$TMPROOT/specs/.sessions"
mkdir -p "$TMPROOT/.claude/context/reference"
cp "$SCRIPT_DIR/task-lock.sh" "$TMPROOT/.claude/scripts/task-lock.sh"
cp "$SCRIPT_DIR/orchestrate-batch-admit.sh" "$TMPROOT/.claude/scripts/orchestrate-batch-admit.sh"
cp "$SCRIPT_DIR/deploy-root-guard.sh" "$TMPROOT/.claude/scripts/deploy-root-guard.sh"
cp "$SCRIPT_DIR/lib/file-scope-overlap.sh" "$TMPROOT/.claude/scripts/lib/file-scope-overlap.sh"
cp "$SCRIPT_DIR/lib/common.sh" "$TMPROOT/.claude/scripts/lib/common.sh"
cp "$SCRIPT_DIR/lib/task-lookup-lib.sh" "$TMPROOT/.claude/scripts/lib/task-lookup-lib.sh"
chmod +x "$TMPROOT/.claude/scripts/task-lock.sh" "$TMPROOT/.claude/scripts/orchestrate-batch-admit.sh"
if [ -f "$SCRIPT_DIR/../context/reference/orchestrator-critical-paths.json" ]; then
  cp "$SCRIPT_DIR/../context/reference/orchestrator-critical-paths.json" "$TMPROOT/.claude/context/reference/orchestrator-critical-paths.json"
fi

TL="$TMPROOT/.claude/scripts/task-lock.sh"
BA="$TMPROOT/.claude/scripts/orchestrate-batch-admit.sh"
SESSIONS_DIR="$TMPROOT/specs/.sessions"
STATE_FILE="$TMPROOT/specs/state.json"

# --- Timestamp helpers (no sleeping -- controlled epoch arithmetic) ---
now_epoch() { date -u +%s; }
iso_at() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }
minutes_ago_iso() { iso_at "$(( $(now_epoch) - ($1 * 60) ))"; }

write_session_fixture() {
  # write_session_fixture <session_id> <pid> <covered_numbers_json> <file_scope_json> <heartbeat_minutes_ago>
  local session_id="$1" pid="$2" covered_numbers_json="$3" file_scope_json="$4" mins_ago="$5"
  local ts
  ts=$(minutes_ago_iso "$mins_ago")
  jq -n \
    --arg session_id "$session_id" \
    --argjson pid "$pid" \
    --arg pid_source "test-fixture" \
    --arg command "/test $session_id" \
    --argjson task_numbers "$covered_numbers_json" \
    --argjson file_scope "$file_scope_json" \
    --arg ts "$ts" \
    '{session_id: $session_id, pid: $pid, pid_source: $pid_source, command: $command, task_numbers: $task_numbers, file_scope: $file_scope, started_at: $ts, heartbeat_at: $ts}' \
    > "$SESSIONS_DIR/${session_id}.json"
}

reset_sessions() {
  rm -f "$SESSIONS_DIR"/*.json 2>/dev/null || true
}

# Find a definitely-dead pid for dead-pid fixtures.
DEAD_PID=999999
while kill -0 "$DEAD_PID" 2>/dev/null; do
  DEAD_PID=$(( DEAD_PID - 1 ))
done

# --- Fixture state.json: each test group gets its OWN isolated scope namespace (g21/, g22/,
# g23/, g4/) so no two groups' candidates ever accidentally collide with each other -- a shared
# "path/a.sh"-style namespace across groups would make the collision scan fire for a candidate a
# LATER group intends to test in isolation (e.g. the session-input tests need a candidate that
# NEVER collides via the state.json scan, so the session pass is the only possible defer signal).
cat > "$STATE_FILE" << 'EOF'
{
  "next_project_number": 1000,
  "active_projects": [
    {"project_number": 830, "project_name": "g21_lower", "status": "not_started", "task_type": "general", "file_scope": ["g21/x"], "dependencies": []},
    {"project_number": 831, "project_name": "g21_higher", "status": "not_started", "task_type": "general", "file_scope": ["g21/x"], "dependencies": []},
    {"project_number": 840, "project_name": "g22_candidate", "status": "not_started", "task_type": "general", "file_scope": ["g22/x"], "dependencies": []},
    {"project_number": 841, "project_name": "g22_cross_batch_collider", "status": "implementing", "task_type": "general", "file_scope": ["g22/x"], "dependencies": []},
    {"project_number": 850, "project_name": "g23_predecessor", "status": "not_started", "task_type": "general", "file_scope": ["g23/x"], "dependencies": []},
    {"project_number": 851, "project_name": "g23_edge_connected", "status": "not_started", "task_type": "general", "file_scope": ["g23/x"], "dependencies": [850]},
    {"project_number": 820, "project_name": "g4_clean_candidate", "status": "not_started", "task_type": "general", "file_scope": ["g4/clean"], "dependencies": []},
    {"project_number": 821, "project_name": "g4_edge_connected", "status": "not_started", "task_type": "general", "file_scope": ["g4/unrelated_scope"], "dependencies": [820]},
    {"project_number": 842, "project_name": "g25_idle_candidate", "status": "not_started", "task_type": "general", "file_scope": ["g25/x"], "dependencies": []},
    {"project_number": 843, "project_name": "g25_idle_collider", "status": "not_started", "task_type": "general", "file_scope": ["g25/x"], "dependencies": []}
  ]
}
EOF

info "Fixture built at $TMPROOT (dead pid probe resolved to $DEAD_PID)"

# =============================================================================
# Group 1: Overlap parity -- bash scopes_overlap() vs spliced scopes_overlap_first
# =============================================================================
source "$TMPROOT/.claude/scripts/lib/file-scope-overlap.sh"

check_parity() {
  local desc="$1" a="$2" b="$3" expected="$4"
  local bash_result
  bash_result=$(scopes_overlap "$a" "$b")
  local prog="${FILE_SCOPE_OVERLAP_JQ_DEFS}
scopes_overlap_first(\$a; \$b)"
  local jq_result
  jq_result=$(jq -n -r --argjson a "$a" --argjson b "$b" "$prog" 2>/dev/null)
  [ "$jq_result" = "null" ] && jq_result=""
  if [ "$bash_result" = "$expected" ] && [ "$jq_result" = "$expected" ]; then
    pass "1.$5: $desc (bash=\"$bash_result\" jq=\"$jq_result\")"
  else
    fail "1.$5: $desc -- expected \"$expected\", bash=\"$bash_result\" jq=\"$jq_result\""
  fi
}

check_parity "exact match" '["a/b"]' '["a/b"]' "a/b" "1"
check_parity "either-side directory-prefix" '["a/b"]' '["a/b/c.txt"]' "a/b/c.txt" "2"
check_parity "trailing-slash normalization" '["a/b/"]' '["a/b"]' "a/b" "3"
check_parity "no-overlap" '["x/y"]' '["a/b"]' "" "4"
check_parity "empty scope" '[]' '["a/b"]' "" "5"
check_parity "null scope" 'null' '["a/b"]' "" "6"

# =============================================================================
# Group 2: Bit-for-bit preservation (collision-scan branch, unchanged by the convergence)
# =============================================================================
# Case 2.1: in_batch defers only against a LOWER project_number (#831 sees #830 as a lower
# in-batch collision and defers; #830 does NOT defer against the higher-numbered #831).
v831=$("$BA" 830 831 2>/dev/null | jq -c 'select(.task_number == 831)')
v830=$("$BA" 830 831 2>/dev/null | jq -c 'select(.task_number == 830)')
c21_ok=true
[ "$(echo "$v831" | jq -r '.decision')" = "defer" ] || { c21_ok=false; info "#831 did not defer against lower in-batch #830: $v831"; }
[ "$(echo "$v831" | jq -r '.collision_scope // empty')" = "in_batch" ] || { c21_ok=false; info "#831's collision_scope was not in_batch: $v831"; }
[ "$(echo "$v830" | jq -r '.decision')" = "admit" ] || { c21_ok=false; info "#830 (lower) incorrectly deferred against higher in-batch #831: $v830"; }
if [ "$c21_ok" = true ]; then pass "2.1: in_batch defers only against a LOWER project_number"; else fail "2.1: in_batch direction case failed (see INFO lines above)"; fi

# Case 2.2: cross_batch defers unconditionally (candidate #840 has a LOWER number than #841, the
# out-of-batch colliding candidate -- still defers, since cross_batch ignores ordering entirely).
v840=$("$BA" 840 2>/dev/null | jq -c '.')
c22_ok=true
[ "$(echo "$v840" | jq -r '.decision')" = "defer" ] || { c22_ok=false; info "#840 did not defer against cross_batch #841: $v840"; }
[ "$(echo "$v840" | jq -r '.collision_scope // empty')" = "cross_batch" ] || { c22_ok=false; info "#840's collision_scope was not cross_batch: $v840"; }
[ "$(echo "$v840" | jq -r '.colliding_task_number')" = "841" ] || { c22_ok=false; info "#840 did not collide with #841: $v840"; }
if [ "$c22_ok" = true ]; then pass "2.2: cross_batch defers unconditionally regardless of project_number ordering"; else fail "2.2: cross_batch direction case failed (see INFO lines above)"; fi

# Case 2.3: a dependencies[] edge in EITHER direction excludes the pair entirely (#851 depends on
# #850 -- despite sharing an overlapping file_scope, #851 must NOT defer against #850).
v851=$("$BA" 850 851 2>/dev/null | jq -c 'select(.task_number == 851)')
c23_ok=true
[ "$(echo "$v851" | jq -r '.decision')" = "admit" ] || { c23_ok=false; info "#851 incorrectly deferred against its dependencies[]-edge-connected #850: $v851"; }
if [ "$c23_ok" = true ]; then pass "2.3: a dependencies[] edge in either direction excludes the pair from comparison entirely"; else fail "2.3: dependency-edge exclusion case failed (see INFO lines above)"; fi

# Case 2.4: self-modification runs first and short-circuits the collision scan (only meaningful
# if orchestrator-critical-paths.json is present in the fixture tree; degrade gracefully if not).
# UPDATED for the designated-candidate tie-breaker: a SOLO self-modifying candidate (the only one
# in the co-dispatch set) is its own cycle's designated candidate and now ADMITS unconditionally
# (previously it deferred whenever --invocation-count > 1); the short-circuit claim itself --
# never carrying collision_scope, regardless of decision -- is unchanged and is what this case
# still pins. A SECOND self-modifying candidate (case 2.4b) is added to pin the tie-breaker's
# defer side, which the old single-candidate fixture never exercised.
if [ -f "$TMPROOT/.claude/context/reference/orchestrator-critical-paths.json" ]; then
  crit_path=$(jq -r '(.scope_roots[0] // "") as $r | (.critical_paths[0].path // "") as $p | if $r != "" and $p != "" then ($r + "/" + $p) else "" end' "$TMPROOT/.claude/context/reference/orchestrator-critical-paths.json" 2>/dev/null)
  if [ -n "$crit_path" ]; then
    smcand=901
    smjson=$(jq --argjson n "$smcand" --arg cp "$crit_path" '.active_projects += [{"project_number": $n, "project_name": "selfmod_cand", "status": "not_started", "task_type": "meta", "file_scope": [$cp], "dependencies": []}]' "$STATE_FILE")
    echo "$smjson" > "$STATE_FILE"
    v_sm=$("$BA" --invocation-count 2 "$smcand" 830 2>/dev/null | jq -c "select(.task_number == $smcand)")
    c24_ok=true
    [ "$(echo "$v_sm" | jq -r '.decision')" = "admit" ] || { c24_ok=false; info "solo (designated) self-modifying candidate did not admit: $v_sm"; }
    [ "$(echo "$v_sm" | jq -r '.self_modifying')" = "true" ] || { c24_ok=false; info "self-modifying candidate did not carry self_modifying: true: $v_sm"; }
    [ "$(echo "$v_sm" | jq 'has("collision_scope")')" = "false" ] || { c24_ok=false; info "self-modifying verdict unexpectedly carries collision_scope (collision scan was not short-circuited): $v_sm"; }
    if [ "$c24_ok" = true ]; then pass "2.4: self-modification runs first, short-circuits the collision scan, and a solo (designated) candidate admits"; else fail "2.4: self-mod precedence case failed (see INFO lines above)"; fi

    # Case 2.4b: TWO self-modifying candidates in the same cycle -- the LOWER-numbered one is the
    # designated candidate and admits; the higher-numbered one defers with defer_reason
    # self_modifying, still carrying no collision_scope field (short-circuit preserved on the
    # defer path too).
    smcand2=902
    smjson2=$(jq --argjson n "$smcand2" --arg cp "$crit_path" '.active_projects += [{"project_number": $n, "project_name": "selfmod_cand2", "status": "not_started", "task_type": "meta", "file_scope": [$cp], "dependencies": []}]' "$STATE_FILE")
    echo "$smjson2" > "$STATE_FILE"
    v_sm_pair=$("$BA" --invocation-count 2 "$smcand" "$smcand2" 2>/dev/null)
    v_sm_lo=$(echo "$v_sm_pair" | jq -c "select(.task_number == $smcand)")
    v_sm_hi=$(echo "$v_sm_pair" | jq -c "select(.task_number == $smcand2)")
    c24b_ok=true
    [ "$(echo "$v_sm_lo" | jq -r '.decision')" = "admit" ] || { c24b_ok=false; info "designated (lower-numbered) self-modifying candidate did not admit: $v_sm_lo"; }
    [ "$(echo "$v_sm_hi" | jq -r '.decision')" = "defer" ] || { c24b_ok=false; info "non-designated (higher-numbered) self-modifying candidate did not defer: $v_sm_hi"; }
    [ "$(echo "$v_sm_hi" | jq -r '.defer_reason // empty')" = "self_modifying" ] || { c24b_ok=false; info "non-designated candidate's defer_reason was not self_modifying: $v_sm_hi"; }
    [ "$(echo "$v_sm_hi" | jq 'has("collision_scope")')" = "false" ] || { c24b_ok=false; info "non-designated candidate's defer verdict unexpectedly carries collision_scope: $v_sm_hi"; }
    if [ "$c24b_ok" = true ]; then pass "2.4b: two co-dispatched self-modifying candidates converge via the designated-candidate tie-breaker (lower admits, higher defers)"; else fail "2.4b: self-mod tie-breaker case failed (see INFO lines above)"; fi

    jq --argjson n "$smcand" --argjson n2 "$smcand2" '.active_projects |= map(select(.project_number != $n and .project_number != $n2))' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
  else
    info "2.4/2.4b: SKIPPED -- orchestrator-critical-paths.json present but empty scope_roots/critical_paths"
  fi
else
  info "2.4/2.4b: SKIPPED -- orchestrator-critical-paths.json not found in fixture tree"
fi

# Case 2.5: cross_batch against a PROVABLY IDLE task (no execution evidence) admits with a loud
# idle_overlap_advisory instead of deferring (orchestrate-batch-admit-v5 narrowing). #843 starts
# the fixture as "not_started".
v842=$("$BA" 842 2>/dev/null | jq -c '.')
c25_ok=true
[ "$(echo "$v842" | jq -r '.decision')" = "admit" ] || { c25_ok=false; info "#842 did not admit against idle cross_batch #843: $v842"; }
[ "$(echo "$v842" | jq 'has("defer_reason")')" = "false" ] || { c25_ok=false; info "#842's admit verdict unexpectedly carries defer_reason: $v842"; }
[ "$(echo "$v842" | jq 'has("idle_overlap_advisory")')" = "true" ] || { c25_ok=false; info "#842's admit verdict is missing idle_overlap_advisory: $v842"; }
[ "$(echo "$v842" | jq -r '.idle_overlap_advisory.colliding_task_number')" = "843" ] || { c25_ok=false; info "idle_overlap_advisory.colliding_task_number was not 843: $v842"; }
[ "$(echo "$v842" | jq -r '.idle_overlap_advisory.colliding_task_status')" = "not_started" ] || { c25_ok=false; info "idle_overlap_advisory.colliding_task_status was not not_started: $v842"; }
[ "$(echo "$v842" | jq -r '.idle_overlap_advisory.collision_scope')" = "cross_batch" ] || { c25_ok=false; info "idle_overlap_advisory.collision_scope was not cross_batch: $v842"; }
[ "$(echo "$v842" | jq -r '.idle_overlap_advisory.overlapping_path')" = "g25/x" ] || { c25_ok=false; info "idle_overlap_advisory.overlapping_path was not g25/x: $v842"; }
if [ "$c25_ok" = true ]; then pass "2.5: cross_batch against a provably idle task admits with idle_overlap_advisory (v5 narrowing)"; else fail "2.5: idle cross_batch admit case failed (see INFO lines above)"; fi

# Case 2.6: idle_overlap_advisory is ABSENT on a verdict with no idle cross-batch overlap at all
# -- reuses case 2.1's #830 admit (its only collision-scan partner, #831, is a HIGHER in_batch
# number so #830 never sees a hit, and neither #830 nor #831 has any idle cross-batch collider
# in this fixture). This guards against "always present" being trivially satisfied by an
# unconditional field.
v830_advisory_check=$("$BA" 830 831 2>/dev/null | jq -c 'select(.task_number == 830)')
c26_ok=true
[ "$(echo "$v830_advisory_check" | jq 'has("idle_overlap_advisory")')" = "false" ] || { c26_ok=false; info "#830 unexpectedly carries idle_overlap_advisory with no idle cross-batch overlap present: $v830_advisory_check"; }
if [ "$c26_ok" = true ]; then pass "2.6: idle_overlap_advisory is absent when no idle cross-batch overlap exists"; else fail "2.6: idle_overlap_advisory absence case failed (see INFO lines above)"; fi

# Case 2.7: pinning the in-flight SET boundary, not just one member of it -- flip #843's status
# to each of researching/planning/implementing in turn and confirm #842 defers with
# file_scope_collision/cross_batch for every one, not just "implementing".
c27_ok=true
for evidence_status in researching planning implementing; do
  jq --arg s "$evidence_status" '.active_projects |= map(if .project_number == 843 then .status = $s else . end)' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
  v842_evidence=$("$BA" 842 2>/dev/null | jq -c '.')
  [ "$(echo "$v842_evidence" | jq -r '.decision')" = "defer" ] || { c27_ok=false; info "#842 did not defer against #843 with status $evidence_status: $v842_evidence"; }
  [ "$(echo "$v842_evidence" | jq -r '.defer_reason // empty')" = "file_scope_collision" ] || { c27_ok=false; info "#842's defer_reason was not file_scope_collision with #843 status $evidence_status: $v842_evidence"; }
  [ "$(echo "$v842_evidence" | jq -r '.collision_scope // empty')" = "cross_batch" ] || { c27_ok=false; info "#842's collision_scope was not cross_batch with #843 status $evidence_status: $v842_evidence"; }
done
# Restore #843 to not_started so it does not leak a stale status into any later group.
jq '.active_projects |= map(if .project_number == 843 then .status = "not_started" else . end)' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
if [ "$c27_ok" = true ]; then pass "2.7: cross_batch defers for every in-flight status (researching/planning/implementing), pinning the boundary"; else fail "2.7: in-flight status boundary case failed (see INFO lines above)"; fi

# =============================================================================
# Group 3: Non-regression -- a file_scope_collision verdict matches the pre-v4 shape exactly,
# modulo $schema and corroborated_by
# =============================================================================
v840_full=$("$BA" 840 2>/dev/null | jq -c '.')
c3_ok=true
[ "$(echo "$v840_full" | jq -r '."$schema"')" = "orchestrate-batch-admit-v5" ] || { c3_ok=false; info "schema is not v5: $v840_full"; }
for f in task_number decision self_modifying defer_reason colliding_task_number colliding_task_status overlapping_path collision_scope reason; do
  echo "$v840_full" | jq -e "has(\"$f\")" >/dev/null 2>&1 || { c3_ok=false; info "v4 collision verdict missing pre-existing field: $f"; }
done
echo "$v840_full" | jq -e 'has("corroborated_by")' >/dev/null 2>&1 || { c3_ok=false; info "v4 collision verdict missing NEW corroborated_by field"; }
[ "$(echo "$v840_full" | jq -r '.corroborated_by | index("non_terminal_status")')" != "null" ] || { c3_ok=false; info "corroborated_by does not name non_terminal_status: $v840_full"; }
if [ "$c3_ok" = true ]; then pass "3: file_scope_collision verdict shape is v3-identical plus \$schema and corroborated_by"; else fail "3: non-regression shape case failed (see INFO lines above)"; fi

# =============================================================================
# Group 4: Session-input cases (D4 exclusions)
# =============================================================================
reset_sessions

# 4.1 live session contends
write_session_fixture "sess_live" "$$" '[899]' '["g4/clean"]' 2
v41=$("$BA" --session-id "sess_caller" 820 2>/dev/null | jq -c '.')
c41_ok=true
[ "$(echo "$v41" | jq -r '.defer_reason // empty')" = "session_active" ] || { c41_ok=false; info "live session did not produce a session_active defer: $v41"; }
if [ "$c41_ok" = true ]; then pass "4.1: a live session contends"; else fail "4.1: live-session-contends case failed (see INFO lines above)"; fi
reset_sessions

# 4.2 dead-pid does not contend
write_session_fixture "sess_dead" "$DEAD_PID" '[899]' '["g4/clean"]' 20
v42=$("$BA" --session-id "sess_caller" 820 2>/dev/null | jq -c '.')
c42_ok=true
[ "$(echo "$v42" | jq -r '.decision')" = "admit" ] || { c42_ok=false; info "dead-pid session incorrectly contended: $v42"; }
if [ "$c42_ok" = true ]; then pass "4.2: a dead-pid session does not contend"; else fail "4.2: dead-pid-excluded case failed (see INFO lines above)"; fi
reset_sessions

# 4.2b dead-pid-within-grace (below the SESSION_REGISTRY_DEAD_PID_MIN floor) STILL contends --
# the verdict must be unchanged even though the reason string now differs from pid-alive.
write_session_fixture "sess_dead_grace" "$DEAD_PID" '[899]' '["g4/clean"]' 5
list_42b=$("$TL" session-list 2>/dev/null | jq -c 'select(.session_id=="sess_dead_grace")')
v42b=$("$BA" --session-id "sess_caller" 820 2>/dev/null | jq -c '.')
c42b_ok=true
[ "$(echo "$list_42b" | jq -r '.liveness_reason')" = "dead-pid-within-grace" ] || { c42b_ok=false; info "sess_dead_grace liveness_reason was not dead-pid-within-grace: $list_42b"; }
[ "$(echo "$list_42b" | jq -r '.live')" = "true" ] || { c42b_ok=false; info "sess_dead_grace live was not true: $list_42b"; }
[ "$(echo "$v42b" | jq -r '.decision')" = "defer" ] || { c42b_ok=false; info "sess_dead_grace (dead-pid-within-grace) did not defer: $v42b"; }
[ "$(echo "$v42b" | jq -r '.defer_reason // empty')" = "session_active" ] || { c42b_ok=false; info "sess_dead_grace defer_reason was not session_active: $v42b"; }
[ "$(echo "$v42b" | jq -r '.session_liveness_reason // empty')" = "dead-pid-within-grace" ] || { c42b_ok=false; info "sess_dead_grace session_liveness_reason was not dead-pid-within-grace: $v42b"; }
if [ "$c42b_ok" = true ]; then pass "4.2b: a dead-pid-within-grace session (below the floor) still contends"; else fail "4.2b: dead-pid-within-grace-still-contends case failed (see INFO lines above)"; fi
reset_sessions

# 4.3 stale-heartbeat does not contend
write_session_fixture "sess_stale" "$$" '[899]' '["g4/clean"]' 300
v43=$("$BA" --session-id "sess_caller" 820 2>/dev/null | jq -c '.')
c43_ok=true
[ "$(echo "$v43" | jq -r '.decision')" = "admit" ] || { c43_ok=false; info "stale-heartbeat session incorrectly contended: $v43"; }
if [ "$c43_ok" = true ]; then pass "4.3: a stale-heartbeat session does not contend"; else fail "4.3: stale-heartbeat-excluded case failed (see INFO lines above)"; fi
reset_sessions

# 4.4 corrupt DOES contend. NOTE: this property is tested at the jq-harness level (calling
# session_contention() directly with a hand-built $sessions entry), not through the full
# session-list -> batch-admit integration path used by 4.1-4.3/4.5-4.7: a REAL corrupt entry
# (invalid JSON) structurally can never carry file_scope data (session-list forces
# file_scope: [] for it, since nothing can be safely read from unparseable JSON), so it can
# never actually produce an overlap hit through the integration path regardless of whether the
# liveness exclusion correctly lets it through -- that emptiness is a property of "corrupt data
# is unreadable", not of the exclusion logic being tested here. The jq-harness level isolates
# exactly the claim D4 makes: the exclusion logic itself does not filter out a "corrupt"
# liveness_reason the way it filters dead-pid/stale-heartbeat.
c44_prog="${FILE_SCOPE_OVERLAP_JQ_DEFS}
session_contention(\$cscope; \$cnum; \$own_sid; \$all; \$sessions)"
c44_all='[{"project_number": 820, "dependencies": []}]'
c44_sessions='[{"session_id": "sess_corrupt_harness", "task_numbers": [899], "file_scope": ["g4/clean"], "live": true, "liveness_reason": "corrupt"}]'
v44=$(jq -n -c --argjson cscope '["g4/clean"]' --argjson cnum 820 --arg own_sid "sess_caller" --argjson all "$c44_all" --argjson sessions "$c44_sessions" "$c44_prog" 2>/dev/null)
c44_ok=true
[ "$v44" != "null" ] && [ -n "$v44" ] || { c44_ok=false; info "session_contention() excluded a corrupt-liveness session (should DO contend, conservative direction): got null"; }
[ "$(echo "$v44" | jq -r '.liveness_reason // empty' 2>/dev/null)" = "corrupt" ] || { c44_ok=false; info "hit's liveness_reason was not corrupt: $v44"; }
if [ "$c44_ok" = true ]; then pass "4.4: session_contention() does not exclude a corrupt-liveness session (conservative direction)"; else fail "4.4: corrupt-contends case failed (see INFO lines above)"; fi
reset_sessions

# 4.5 own-session_id does not contend (self-exclusion)
write_session_fixture "sess_caller" "$$" '[899]' '["g4/clean"]' 2
v45=$("$BA" --session-id "sess_caller" 820 2>/dev/null | jq -c '.')
c45_ok=true
[ "$(echo "$v45" | jq -r '.decision')" = "admit" ] || { c45_ok=false; info "own session_id incorrectly contended against itself: $v45"; }
if [ "$c45_ok" = true ]; then pass "4.5: a session whose session_id equals the caller's own does not contend"; else fail "4.5: self-exclusion case failed (see INFO lines above)"; fi
reset_sessions

# 4.6 a session covering ONLY edge-connected numbers does not contend (#821 depends on #820)
write_session_fixture "sess_edge_only" "$$" '[821]' '["g4/clean"]' 2
v46=$("$BA" --session-id "sess_caller" 820 2>/dev/null | jq -c '.')
c46_ok=true
[ "$(echo "$v46" | jq -r '.decision')" = "admit" ] || { c46_ok=false; info "session covering only an edge-connected number incorrectly contended: $v46"; }
if [ "$c46_ok" = true ]; then pass "4.6: a session covering only edge-connected numbers does not contend"; else fail "4.6: edge-only-excluded case failed (see INFO lines above)"; fi
reset_sessions

# 4.7 a session covering one edge-connected AND one unrelated number DOES contend
write_session_fixture "sess_edge_plus" "$$" '[821, 822]' '["g4/clean"]' 2
v47=$("$BA" --session-id "sess_caller" 820 2>/dev/null | jq -c '.')
c47_ok=true
[ "$(echo "$v47" | jq -r '.defer_reason // empty')" = "session_active" ] || { c47_ok=false; info "session covering an edge-connected AND an unrelated number did not contend: $v47"; }
[ "$(echo "$v47" | jq -r '.colliding_task_number')" = "822" ] || { c47_ok=false; info "covered number was not the lowest non-excluded number (822): $v47"; }
if [ "$c47_ok" = true ]; then pass "4.7: a session covering one edge-connected and one unrelated number DOES contend"; else fail "4.7: partial-edge-contends case failed (see INFO lines above)"; fi
reset_sessions

# =============================================================================
# Group 5: Degradation cases
# =============================================================================
write_session_fixture "sess_live2" "$$" '[899]' '["g4/clean"]' 2
d5_out=$("$BA" 820 2>&1 1>/dev/null)
d5_verdict=$("$BA" 820 2>/dev/null | jq -c '.')
c51_ok=true
echo "$d5_out" | grep -qi "session-id not supplied" || { c51_ok=false; info "no stderr degradation line when --session-id omitted: $d5_out"; }
[ "$(echo "$d5_verdict" | jq -r '.decision')" = "admit" ] || { c51_ok=false; info "session verdict fired despite --session-id being omitted: $d5_verdict"; }
if [ "$c51_ok" = true ]; then pass "5.1: --session-id omitted skips the session input and prints the stderr degradation line"; else fail "5.1: D6-degradation case failed (see INFO lines above)"; fi
reset_sessions

rmdir "$SESSIONS_DIR" 2>/dev/null || true
d52_out=$("$BA" --session-id "sess_caller" 820 2>&1)
d52_exit=$?
c52_ok=true
[ "$d52_exit" -eq 0 ] || { c52_ok=false; info "missing specs/.sessions/ directory caused a non-zero exit: $d52_exit"; }
if [ "$c52_ok" = true ]; then pass "5.2: a missing specs/.sessions/ directory is not an error"; else fail "5.2: missing-sessions-dir case failed (see INFO lines above)"; fi
mkdir -p "$SESSIONS_DIR"

# =============================================================================
# Group 6: session-list cases
# =============================================================================
write_session_fixture "sess_list_live" "$$" '[899]' '["path/a.sh"]' 2
echo "not valid json" > "$SESSIONS_DIR/sess_list_corrupt.json"
before_listing=$(find "$SESSIONS_DIR" -type f -name '*.json' -exec md5sum {} \; | sort)
list_out=$("$TL" session-list 2>&1)
list_exit=$?
after_listing=$(find "$SESSIONS_DIR" -type f -name '*.json' -exec md5sum {} \; | sort)

c6_ok=true
[ "$list_exit" -eq 0 ] || { c6_ok=false; info "session-list exit code was $list_exit, expected 0"; }
line_count=$(echo "$list_out" | grep -c '.')
[ "$line_count" -eq 2 ] || { c6_ok=false; info "expected 2 NDJSON lines, got $line_count"; }
while IFS= read -r line; do
  [ -z "$line" ] && continue
  echo "$line" | jq -e . >/dev/null 2>&1 || { c6_ok=false; info "session-list line did not parse as JSON: $line"; }
  echo "$line" | jq -e 'has("live")' >/dev/null 2>&1 || { c6_ok=false; info "session-list line missing 'live': $line"; }
  echo "$line" | jq -e 'has("liveness_reason")' >/dev/null 2>&1 || { c6_ok=false; info "session-list line missing 'liveness_reason': $line"; }
done <<< "$list_out"
echo "$list_out" | grep -q '"liveness_reason":"corrupt"' || { c6_ok=false; info "corrupt entry not present with liveness_reason=corrupt: $list_out"; }
[ "$before_listing" = "$after_listing" ] || { c6_ok=false; info "specs/.sessions/ was modified by session-list"; }
if [ "$c6_ok" = true ]; then pass "6: session-list emits valid NDJSON with live/liveness_reason on every line, corrupt entry included, registry unmodified"; else fail "6: session-list case failed (see INFO lines above)"; fi
reset_sessions

# =============================================================================
# Group 7: Fail-closed case -- lib absent, both consumers exit 2 with a remedy message
# =============================================================================
mv "$TMPROOT/.claude/scripts/lib/file-scope-overlap.sh" "$TMPROOT/.claude/scripts/lib/file-scope-overlap.sh.bak"

tl_fc_out=$("$TL" acquire 820 test sess_fc 2>&1)
tl_fc_exit=$?
c71_ok=true
[ "$tl_fc_exit" -eq 2 ] || { c71_ok=false; info "task-lock.sh acquire with lib absent exited $tl_fc_exit, expected 2: $tl_fc_out"; }
echo "$tl_fc_out" | grep -qi "could not source" || { c71_ok=false; info "task-lock.sh fail-closed message missing remedy text: $tl_fc_out"; }
if [ "$c71_ok" = true ]; then pass "7.1: task-lock.sh acquire fails CLOSED (exit 2, remedy message) when the lib is absent"; else fail "7.1: task-lock.sh fail-closed case failed (see INFO lines above)"; fi

ba_fc_out=$("$BA" 820 2>&1)
ba_fc_exit=$?
c72_ok=true
[ "$ba_fc_exit" -eq 2 ] || { c72_ok=false; info "orchestrate-batch-admit.sh with lib absent exited $ba_fc_exit, expected 2: $ba_fc_out"; }
echo "$ba_fc_out" | grep -qi "could not source" || { c72_ok=false; info "orchestrate-batch-admit.sh fail-closed message missing remedy text: $ba_fc_out"; }
if [ "$c72_ok" = true ]; then pass "7.2: orchestrate-batch-admit.sh fails CLOSED (exit 2, remedy message) when the lib is absent"; else fail "7.2: orchestrate-batch-admit.sh fail-closed case failed (see INFO lines above)"; fi

mv "$TMPROOT/.claude/scripts/lib/file-scope-overlap.sh.bak" "$TMPROOT/.claude/scripts/lib/file-scope-overlap.sh"

# =============================================================================
# Group 8: deployed-tree reachability
# =============================================================================
info "8: deployed-tree reachability for scripts/lib/file-scope-overlap.sh and this suite's own file was confirmed directly against .claude/scripts/ during implementation (see the originating plan's Phase 8 completion notes) -- not re-derived here since this suite's own SCRIPT_DIR is ambiguous between a source-store and a deployed invocation and cannot reliably self-locate the deploy root."

# =============================================================================
# Group 9: session-register/acquire parity -- reproduces a multi-task batch's own
# session-register (bare session_id, union file_scope) against per-task acquire/release/heartbeat,
# pinning that a lock-touching call MUST present the SAME bare session_id the batch registered,
# never a per-task-suffixed variant. Drives the real task-lock.sh CLI end to end (no hand-written
# registry fixture) against the 820/g4_clean_candidate and 850/g23_predecessor fixture pair, which
# are not dependency-edge-connected to each other -- exactly the "unrelated batch members" shape
# the union-file_scope self-contention defect needs. This group covers
# skill-orchestrate/SKILL.md (9.5), now the sole multi-task lock-touching caller. Cases 9.6-9.8,
# the equivalent static guards over the three now-deleted lifecycle command files, were retired
# along with those files.
# =============================================================================
reset_sessions

# 9.1 Registration case: mirrors Stage MT-1's session-register call. Assert the entry exists and
# its file_scope is the union of the fixture 820/850 scopes (g4/clean, g23/x), proving the union
# is computed by the CLI itself, not hand-assembled by this test.
"$TL" session-register "sess_mt_batch" "/orchestrate (multi-task)" "820,850" >/dev/null 2>&1
reg_entry="$SESSIONS_DIR/sess_mt_batch.json"
c91_ok=true
[ -f "$reg_entry" ] || { c91_ok=false; info "9.1: session-register did not create $reg_entry"; }
if [ -f "$reg_entry" ]; then
  reg_scope=$(jq -c '.file_scope | sort' "$reg_entry" 2>/dev/null)
  [ "$reg_scope" = '["g23/x","g4/clean"]' ] || { c91_ok=false; info "9.1: registered file_scope was not the union of the 820/850 fixture pair: $reg_scope"; }
fi
if [ "$c91_ok" = true ]; then pass "9.1: session-register computes the union file_scope over the 820/850 fixture pair"; else fail "9.1: registration case failed (see INFO lines above)"; fi

# 9.2 Positive case (post-fix behavior): acquiring with the SAME bare session_id the batch
# registered must admit both fixture members -- this is the parity the fix restores.
c92_ok=true
if ! "$TL" acquire 820 research "sess_mt_batch" "/orchestrate (multi-task)" >/dev/null 2>/dev/null; then
  c92_ok=false; info "9.2: bare-id acquire on fixture 820 was refused"
fi
"$TL" release 820 "sess_mt_batch" >/dev/null 2>&1
if ! "$TL" acquire 850 research "sess_mt_batch" "/orchestrate (multi-task)" >/dev/null 2>/dev/null; then
  c92_ok=false; info "9.2: bare-id acquire on fixture 850 was refused"
fi
"$TL" release 850 "sess_mt_batch" >/dev/null 2>&1
if [ "$c92_ok" = true ]; then pass "9.2: acquire/release with the bare, registered session_id admits both fixture batch members"; else fail "9.2: register/acquire parity (positive) case failed (see INFO lines above)"; fi

# 9.3 Negative case (regression reproduction): acquiring with the per-task-suffixed variant of the
# SAME logical session contends against the batch's own registration -- this is the MT-1/MT-4
# mismatch this plan fixes. Assert both the refusal (exit 1) and that the stderr names the
# session-registry contention path specifically (via "registered session"), not some other
# refusal reason.
c93_neg_out=$("$TL" acquire 820 research "sess_mt_batch_820" "/orchestrate (multi-task)" 2>&1 1>/dev/null)
c93_neg_exit=$?
c93_ok=true
[ "$c93_neg_exit" -eq 1 ] || { c93_ok=false; info "9.3: suffixed-id acquire on fixture 820 exited $c93_neg_exit, expected 1: $c93_neg_out"; }
echo "$c93_neg_out" | grep -qi "registered session" || { c93_ok=false; info "9.3: suffixed-id refusal did not name the session-registry contention path: $c93_neg_out"; }
if [ "$c93_ok" = true ]; then pass "9.3: a per-task-suffixed session_id contends against the batch's own bare-id registration (regression reproduction)"; else fail "9.3: register/acquire parity (negative) case failed (see INFO lines above)"; fi

# 9.4 Heartbeat parity case: guards the implement-dispatch half of the fix -- the session_id a
# per-phase heartbeat presents must match the bare id the acquire used, or the heartbeat is a
# silent no-op against a foreign holder.
"$TL" acquire 820 research "sess_mt_batch" "/orchestrate (multi-task)" >/dev/null 2>&1
c94_hb_out=$("$TL" heartbeat 820 "sess_mt_batch" 2>&1)
c94_ok=true
echo "$c94_hb_out" | grep -qi "held by a different session" && { c94_ok=false; info "9.4: bare-id heartbeat on fixture 820 warned of a different-session holder: $c94_hb_out"; }
if [ "$c94_ok" = true ]; then pass "9.4: a heartbeat presenting the same bare session_id as the acquire does not warn of a foreign holder"; else fail "9.4: heartbeat parity case failed (see INFO lines above)"; fi
"$TL" release 820 "sess_mt_batch" >/dev/null 2>&1

# 9.5 Static guard case: no lock-touching task-lock.sh call in skill-orchestrate/SKILL.md may
# reintroduce the per-task-suffixed pattern. Mirrors Group 8's stance on SCRIPT_DIR ambiguity --
# info-and-skip if the file is not reachable from this invocation, rather than failing.
skill_md="$SCRIPT_DIR/../skills/skill-orchestrate/SKILL.md"
if [ -f "$skill_md" ]; then
  c95_ok=true
  bad_lines=$(grep -nE 'task-lock\.sh[[:space:]]+(acquire|release|heartbeat)' "$skill_md" | grep -F '${session_id}_${task_num}' || true)
  [ -z "$bad_lines" ] || { c95_ok=false; info "9.5: found a lock-touching call still using the per-task-suffixed session_id: $bad_lines"; }
  if [ "$c95_ok" = true ]; then pass "9.5: no lock-touching task-lock.sh call in skill-orchestrate/SKILL.md uses the per-task-suffixed session_id"; else fail "9.5: static guard case failed (see INFO lines above)"; fi
else
  info "9.5: SKIPPED -- skill-orchestrate/SKILL.md not reachable at $skill_md from this invocation"
fi

"$TL" release 820 "sess_mt_batch" >/dev/null 2>&1
"$TL" release 850 "sess_mt_batch" >/dev/null 2>&1
reset_sessions

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
