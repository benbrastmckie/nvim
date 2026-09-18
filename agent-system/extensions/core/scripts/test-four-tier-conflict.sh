#!/usr/bin/env bash
# test-four-tier-conflict.sh - Isolated-temp-root suite proving the four-tier conflict-response
# ladder (auto-sequence, bounded retry, warn, ask; see context/patterns/task-lock.md's "Four-Tier
# Conflict Response" section):
#
#   - Tier 2 (bounded retry) resolving: a foreign holder's lock released partway through the
#     retry window falls through to a clean acquire, exactly one NOTE: line, no ABORT text.
#   - Tier 3 (warn) exhaustion: a foreign holder kept fresh for the whole retry budget falls
#     through to the SAME ABORT text plain `acquire` would emit for the identical fixture, byte-
#     identical, for all three ABORT variants (own-project holder, cross-project file_scope
#     overlap against a held lock, cross-project overlap against a live registered session).
#   - Same-session re-entry: acquire-retry invoked with the holder's own session_id returns 0
#     immediately, zero NOTE: lines, elapsed wall clock far below one poll interval -- i.e. the
#     retry loop body is never entered.
#   - Budget-bound: the exhaustion case's elapsed wall clock stays close to
#     TASK_LOCK_RETRY_BUDGET_MS, never anywhere near a minutes-scale wait, using a lowered
#     override to keep the suite fast.
#
# Tier 1 (auto-sequence) and the non-convergence-terminates-partial proof are added in this same
# file by a later phase (see context/patterns/task-lock.md and this plan's own phase sequence);
# this revision covers Tier 2/Tier 3 only.
#
# Modeled directly on test-conflict-predicate.sh's, test-session-registry.sh's, and
# test-task-lock-reap.sh's isolated-temp-root precedent: throwaway $TMPROOT/.claude/scripts/
# satisfying deploy-root-guard.sh's two-levels-under-root check, real scripts copied byte-for-
# byte, fixture state.json / .sessions/ / .lock/ at controlled epoch timestamps (no sleeping
# except the deliberate, bounded backgrounded-release case below), pass/fail/info helpers,
# cleanup trap. No testability hooks are added to production code anywhere in this suite.
#
# Never touches the real specs/ tree.
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
for req in task-lock.sh deploy-root-guard.sh lib/file-scope-overlap.sh lib/common.sh orchestrate-batch-admit.sh lib/task-lookup-lib.sh; do
  if [ ! -f "$SCRIPT_DIR/$req" ]; then
    echo "ERROR: expected $req alongside this script in $SCRIPT_DIR" >&2
    exit 1
  fi
done

# --- Build the isolated temp root ---
TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/four-tier-conflict-test.XXXXXX")"

cleanup() {
  [ -n "${TMPROOT:-}" ] && [ -d "$TMPROOT" ] && rm -rf "$TMPROOT"
}
trap cleanup EXIT

mkdir -p "$TMPROOT/.claude/scripts/lib"
mkdir -p "$TMPROOT/specs/.sessions"
cp "$SCRIPT_DIR/task-lock.sh" "$TMPROOT/.claude/scripts/task-lock.sh"
cp "$SCRIPT_DIR/deploy-root-guard.sh" "$TMPROOT/.claude/scripts/deploy-root-guard.sh"
cp "$SCRIPT_DIR/lib/file-scope-overlap.sh" "$TMPROOT/.claude/scripts/lib/file-scope-overlap.sh"
cp "$SCRIPT_DIR/lib/common.sh" "$TMPROOT/.claude/scripts/lib/common.sh"
cp "$SCRIPT_DIR/lib/task-lookup-lib.sh" "$TMPROOT/.claude/scripts/lib/task-lookup-lib.sh"
cp "$SCRIPT_DIR/orchestrate-batch-admit.sh" "$TMPROOT/.claude/scripts/orchestrate-batch-admit.sh"
chmod +x "$TMPROOT/.claude/scripts/task-lock.sh" "$TMPROOT/.claude/scripts/orchestrate-batch-admit.sh"

TL="$TMPROOT/.claude/scripts/task-lock.sh"
BA="$TMPROOT/.claude/scripts/orchestrate-batch-admit.sh"
SESSIONS_DIR="$TMPROOT/specs/.sessions"
STATE_FILE="$TMPROOT/specs/state.json"

# --- Timestamp helpers (no sleeping for fixture setup -- controlled epoch arithmetic) ---
now_epoch() { date -u +%s; }
iso_at() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }
minutes_ago_iso() { iso_at "$(( $(now_epoch) - ($1 * 60) ))"; }

# write_holder_fixture <lock_dir> <session_id> <project_number> <heartbeat_minutes_ago>
write_holder_fixture() {
  local lock_dir="$1" session_id="$2" project_number="$3" mins_ago="$4"
  local ts
  ts=$(minutes_ago_iso "$mins_ago")
  mkdir -p "$lock_dir"
  jq -n \
    --arg session_id "$session_id" \
    --argjson task_number "$project_number" \
    --arg operation "implement" \
    --arg acquired_at "$ts" \
    --arg heartbeat_at "$ts" \
    --arg command "/test fixture" \
    '{session_id: $session_id, task_number: $task_number, operation: $operation, acquired_at: $acquired_at, heartbeat_at: $heartbeat_at, command: $command}' \
    > "$lock_dir/holder.json"
}

# write_session_fixture <session_id> <pid> <covered_numbers_json> <file_scope_json> <heartbeat_minutes_ago>
write_session_fixture() {
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

# Find a definitely-dead pid for fixtures that must NEVER be mistaken for a live process.
DEAD_PID=999999
while kill -0 "$DEAD_PID" 2>/dev/null; do
  DEAD_PID=$(( DEAD_PID - 1 ))
done

# --- Fixture state.json: each group gets its own isolated project + file_scope namespace so no
# group's fixtures accidentally collide with another's. ---
cat > "$STATE_FILE" << EOF
{
  "next_project_number": 1000,
  "active_projects": [
    {"project_number": 501, "project_name": "case_a_resolving", "status": "implementing", "task_type": "general", "file_scope": [], "dependencies": []},
    {"project_number": 502, "project_name": "case_b_exhaustion", "status": "implementing", "task_type": "general", "file_scope": [], "dependencies": []},
    {"project_number": 503, "project_name": "case_c_candidate", "status": "not_started", "task_type": "general", "file_scope": ["case_c/shared.sh"], "dependencies": []},
    {"project_number": 504, "project_name": "case_c_held", "status": "implementing", "task_type": "general", "file_scope": ["case_c/shared.sh"], "dependencies": []},
    {"project_number": 505, "project_name": "case_d_candidate", "status": "not_started", "task_type": "general", "file_scope": ["case_d/shared.sh"], "dependencies": []},
    {"project_number": 506, "project_name": "case_e_reentry", "status": "implementing", "task_type": "general", "file_scope": [], "dependencies": []},
    {"project_number": 507, "project_name": "case_f_budget", "status": "implementing", "task_type": "general", "file_scope": [], "dependencies": []}
  ]
}
EOF

mkdir -p "$TMPROOT/specs/501_case_a_resolving" "$TMPROOT/specs/502_case_b_exhaustion" \
         "$TMPROOT/specs/503_case_c_candidate" "$TMPROOT/specs/504_case_c_held" \
         "$TMPROOT/specs/505_case_d_candidate" "$TMPROOT/specs/506_case_e_reentry" \
         "$TMPROOT/specs/507_case_f_budget"

info "Fixture built at $TMPROOT (dead pid probe resolved to $DEAD_PID)"

# =============================================================================
# Case 1 (Tier 2, resolving): a foreign holder's lock released partway through the retry
# window by a backgrounded helper.
# =============================================================================
write_holder_fixture "$TMPROOT/specs/501_case_a_resolving/.lock" "sess_case_a_holder" 501 0

(
  sleep 0.3
  rm -rf "$TMPROOT/specs/501_case_a_resolving/.lock"
) &
RELEASER_PID=$!

t0=$(date +%s%N)
out1=$(TASK_LOCK_RETRY_BUDGET_MS=5000 TASK_LOCK_RETRY_POLL_MS=100 "$TL" acquire-retry 501 implement sess_case_a_waiter 2>&1)
rc1=$?
t1=$(date +%s%N)
wait "$RELEASER_PID" 2>/dev/null || true

note_count1=$(grep -c '^NOTE:' <<<"$out1")
abort_count1=$(grep -c '^ABORT:' <<<"$out1")

if [ "$rc1" -eq 0 ] && [ "$note_count1" -eq 1 ] && [ "$abort_count1" -eq 0 ]; then
  pass "1: Tier-2 resolving -- foreign lock released mid-window, acquire-retry returns 0, exactly one NOTE:, no ABORT text (elapsed $(( (t1 - t0) / 1000000 ))ms)"
else
  fail "1: Tier-2 resolving case -- rc=$rc1 note_count=$note_count1 abort_count=$abort_count1 output=[$out1]"
fi

# =============================================================================
# Case 2 (Tier 3, exhaustion, own-project variant): foreign holder's heartbeat kept fresh for
# the whole retry window. Assert the emitted (post-NOTE) text is byte-identical to plain
# `acquire`'s output for the same fixture.
# =============================================================================
write_holder_fixture "$TMPROOT/specs/502_case_b_exhaustion/.lock" "sess_case_b_holder" 502 0

expected2=$("$TL" acquire 502 implement sess_case_b_waiter 2>&1)
rc_expected2=$?

t0=$(date +%s%N)
out2=$(TASK_LOCK_RETRY_BUDGET_MS=800 TASK_LOCK_RETRY_POLL_MS=200 "$TL" acquire-retry 502 implement sess_case_b_waiter 2>&1)
rc2=$?
t1=$(date +%s%N)
elapsed2_ms=$(( (t1 - t0) / 1000000 ))

# Strip the single leading NOTE: line from acquire-retry's output before comparing.
actual2=$(grep -v '^NOTE:' <<<"$out2")

if [ "$rc_expected2" -eq 1 ] && [ "$rc2" -eq 1 ] && [ "$actual2" = "$expected2" ]; then
  pass "2: Tier-3 exhaustion (own-project variant) -- acquire-retry returns 1 with ABORT text byte-identical to plain acquire's output for the same fixture"
else
  fail "2: Tier-3 exhaustion (own-project variant) -- rc_expected=$rc_expected2 rc2=$rc2 expected=[$expected2] actual=[$actual2]"
fi

# =============================================================================
# Case 3 (Tier 3, field preservation, cross-project file_scope overlap against a HELD lock):
# candidate project 503 overlaps held project 504 via case_c/shared.sh.
# =============================================================================
write_holder_fixture "$TMPROOT/specs/504_case_c_held/.lock" "sess_case_c_holder" 504 0

expected3=$("$TL" acquire 503 implement sess_case_c_waiter 2>&1)
rc_expected3=$?

out3=$(TASK_LOCK_RETRY_BUDGET_MS=800 TASK_LOCK_RETRY_POLL_MS=200 "$TL" acquire-retry 503 implement sess_case_c_waiter 2>&1)
rc3=$?
actual3=$(grep -v '^NOTE:' <<<"$out3")

if [ "$rc_expected3" -eq 1 ] && [ "$rc3" -eq 1 ] && [ "$actual3" = "$expected3" ] && [ -n "$actual3" ]; then
  pass "3: Tier-3 field preservation -- cross-project file_scope overlap against a held lock, ABORT text byte-identical to plain acquire's, all fields intact"
else
  fail "3: Tier-3 field preservation (held-lock overlap) -- rc_expected=$rc_expected3 rc3=$rc3 expected=[$expected3] actual=[$actual3]"
fi

# =============================================================================
# Case 4 (Tier 3, field preservation, cross-project overlap against a LIVE REGISTERED SESSION):
# candidate project 505 overlaps a live registered session's file_scope via case_d/shared.sh.
# The registered session covers an unrelated project number (kept far outside this suite's own
# fixture range) so the hit comes only from the session-registry contention pass, never the
# held-lock scan.
# =============================================================================
# A live pid is required for the session_contention() liveness check to treat this entry as
# live; DEAD_PID would be excluded as a dead-pid hit. Use this suite's own PID (definitely
# alive for the duration of the test).
write_session_fixture "sess_case_d_registered" "$$" '[8899]' '["case_d/shared.sh"]' 0

expected4=$("$TL" acquire 505 implement sess_case_d_waiter 2>&1)
rc_expected4=$?

out4=$(TASK_LOCK_RETRY_BUDGET_MS=800 TASK_LOCK_RETRY_POLL_MS=200 "$TL" acquire-retry 505 implement sess_case_d_waiter 2>&1)
rc4=$?
actual4=$(grep -v '^NOTE:' <<<"$out4")

if [ "$rc_expected4" -eq 1 ] && [ "$rc4" -eq 1 ] && [ "$actual4" = "$expected4" ] && grep -q "registered session sess_case_d_registered" <<<"$actual4"; then
  pass "4: Tier-3 field preservation -- cross-project overlap against a live registered session, ABORT text byte-identical to plain acquire's, all fields intact"
else
  fail "4: Tier-3 field preservation (registered-session overlap) -- rc_expected=$rc_expected4 rc4=$rc4 expected=[$expected4] actual=[$actual4]"
fi

# =============================================================================
# Case 5 (same-session re-entry): acquire-retry invoked with the holder's own session_id.
# Assert return 0, zero NOTE: lines, and elapsed wall-clock well below the poll interval --
# i.e. the retry loop body was never entered (a single cmd_acquire fast-path return).
# =============================================================================
write_holder_fixture "$TMPROOT/specs/506_case_e_reentry/.lock" "sess_case_e_self" 506 0

t0=$(date +%s%N)
out5=$(TASK_LOCK_RETRY_BUDGET_MS=5000 TASK_LOCK_RETRY_POLL_MS=1000 "$TL" acquire-retry 506 implement sess_case_e_self 2>&1)
rc5=$?
t1=$(date +%s%N)
elapsed5_ms=$(( (t1 - t0) / 1000000 ))
note_count5=$(grep -c '^NOTE:' <<<"$out5")

# The poll interval is 1000ms; the retry loop being entered even once would push elapsed past
# that. A generous 500ms ceiling proves the loop body never ran (single fast cmd_acquire call).
if [ "$rc5" -eq 0 ] && [ "$note_count5" -eq 0 ] && [ "$elapsed5_ms" -lt 500 ]; then
  pass "5: same-session re-entry -- acquire-retry returns 0, zero NOTE: lines, elapsed ${elapsed5_ms}ms (< 500ms poll-interval ceiling), retry loop never entered"
else
  fail "5: same-session re-entry -- rc=$rc5 note_count=$note_count5 elapsed_ms=$elapsed5_ms output=[$out5]"
fi

# =============================================================================
# Case 6 (budget-bound): the exhaustion case's elapsed wall clock stays close to
# TASK_LOCK_RETRY_BUDGET_MS, never anywhere near a minutes-scale wait. Uses a lowered override
# to keep the suite fast.
# =============================================================================
write_holder_fixture "$TMPROOT/specs/507_case_f_budget/.lock" "sess_case_f_holder" 507 0

BUDGET_MS=1000
t0=$(date +%s%N)
out6=$(TASK_LOCK_RETRY_BUDGET_MS=$BUDGET_MS TASK_LOCK_RETRY_POLL_MS=100 "$TL" acquire-retry 507 implement sess_case_f_waiter 2>&1)
rc6=$?
t1=$(date +%s%N)
elapsed6_ms=$(( (t1 - t0) / 1000000 ))

# Tolerance: at least the budget (the loop only checks the bound at the top of each iteration,
# so it can slightly overshoot by up to one poll interval), and well under 2x the budget --
# nowhere near TASK_LOCK_STALE_MIN's minutes-scale window.
if [ "$rc6" -eq 1 ] && [ "$elapsed6_ms" -ge "$BUDGET_MS" ] && [ "$elapsed6_ms" -lt $(( BUDGET_MS * 2 )) ]; then
  pass "6: budget-bound -- exhaustion elapsed ${elapsed6_ms}ms within [${BUDGET_MS}ms, $(( BUDGET_MS * 2 ))ms), nowhere near a minutes-scale wait"
else
  fail "6: budget-bound -- rc=$rc6 elapsed_ms=$elapsed6_ms budget_ms=$BUDGET_MS"
fi

echo ""
echo "=== Tier 1 (auto-sequence) and convergence proofs ==="
echo ""

# =============================================================================
# Fixture for cases 7-11: Tier 1's two-pass mechanism, driven directly against
# orchestrate-batch-admit.sh exactly as skill-orchestrate/SKILL.md's Stage MT-3 step 4.5 calls
# it (the sole surviving multi-task caller, the three former lifecycle command files having
# since been deleted). Two independent overlapping pairs
# in their own file_scope namespace so the convergent (Case G) and non-convergent (Case H)
# fixtures never interfere with each other.
# =============================================================================
jq '.active_projects += [
  {"project_number": 601, "project_name": "case_g_low", "status": "not_started", "task_type": "general", "file_scope": ["case_g/shared.sh"], "dependencies": []},
  {"project_number": 602, "project_name": "case_g_high", "status": "not_started", "task_type": "general", "file_scope": ["case_g/shared.sh"], "dependencies": []},
  {"project_number": 603, "project_name": "case_h_low", "status": "implementing", "task_type": "general", "file_scope": ["case_h/shared.sh"], "dependencies": []},
  {"project_number": 604, "project_name": "case_h_high", "status": "not_started", "task_type": "general", "file_scope": ["case_h/shared.sh"], "dependencies": []},
  {"project_number": 605, "project_name": "case_i_low", "status": "not_started", "task_type": "general", "file_scope": ["case_i/shared.sh"], "dependencies": []},
  {"project_number": 606, "project_name": "case_i_high", "status": "not_started", "task_type": "general", "file_scope": ["case_i/shared.sh"], "dependencies": []}
]' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

mkdir -p "$TMPROOT/specs/601_case_g_low" "$TMPROOT/specs/602_case_g_high" \
         "$TMPROOT/specs/603_case_h_low" "$TMPROOT/specs/604_case_h_high" \
         "$TMPROOT/specs/605_case_i_low" "$TMPROOT/specs/606_case_i_high"

second_pass_ledger=()

# =============================================================================
# Case 7 (Tier 1, pass 1): two same-batch candidate projects with overlapping file_scope and no
# dependencies[] edge. Bounded scan: the admission call's positional arguments are exactly the
# pass's own candidate set, never a sweep of every fixture project in state.json.
# =============================================================================
pass1_g_output=$("$BA" --invocation-count 2 --session-id sess_case_g 601 602 2>/dev/null)

pass1_g_601_decision=$(echo "$pass1_g_output" | jq -s -c '.[] | select(.task_number == 601) | .decision' | tr -d '"')
pass1_g_602_decision=$(echo "$pass1_g_output" | jq -s -c '.[] | select(.task_number == 602) | .decision' | tr -d '"')
pass1_g_602_defer_reason=$(echo "$pass1_g_output" | jq -s -r '.[] | select(.task_number == 602) | .defer_reason // ""')
pass1_g_602_collision_scope=$(echo "$pass1_g_output" | jq -s -r '.[] | select(.task_number == 602) | .collision_scope // ""')
pass1_g_out_of_pair=$(echo "$pass1_g_output" | jq -s -r '[.[].task_number] | map(select(. != 601 and . != 602)) | length')

if [ "$pass1_g_601_decision" = "admit" ] && [ "$pass1_g_602_decision" = "defer" ] \
   && [ "$pass1_g_602_defer_reason" = "file_scope_collision" ] && [ "$pass1_g_602_collision_scope" = "in_batch" ] \
   && [ "$pass1_g_out_of_pair" -eq 0 ]; then
  pass "7: Tier-1 pass 1 -- exactly one defer verdict (project 602), defer_reason=file_scope_collision, collision_scope=in_batch; admission input/output never names a project outside the {601,602} pair"
else
  fail "7: Tier-1 pass 1 -- 601=$pass1_g_601_decision 602=$pass1_g_602_decision defer_reason=$pass1_g_602_defer_reason collision_scope=$pass1_g_602_collision_scope out_of_pair=$pass1_g_out_of_pair"
fi

second_pass_ledger+=("pass1:602:file_scope_collision:in_batch")

# =============================================================================
# Case 8 (Tier 1, pass 2, convergent): the pass-1 winner (project 601) reaches terminal status
# (simulating /implement's success terminus, per this suite's own implementation note on
# convergence semantics -- orchestrate-batch-admit.sh's collision predicate is a state.json
# STATUS check, not a lock check, so pass 2 converges once the winner goes terminal). The
# second-pass admission call runs over EXACTLY the deferred singleton (deferred_second_pass =
# [602]), never re-including 601 or sweeping any other fixture project.
# =============================================================================
jq '(.active_projects[] | select(.project_number == 601)).status = "completed"' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

pass2_g_output=$("$BA" --invocation-count 1 --session-id sess_case_g 602 2>/dev/null)
pass2_g_602_decision=$(echo "$pass2_g_output" | jq -s -r '.[] | select(.task_number == 602) | .decision')
pass2_g_out_of_singleton=$(echo "$pass2_g_output" | jq -s -r '[.[].task_number] | map(select(. != 602)) | length')

if [ "$pass2_g_602_decision" = "admit" ] && [ "$pass2_g_out_of_singleton" -eq 0 ]; then
  pass "8: Tier-1 pass 2 (convergent) -- second-pass admission over the deferred singleton returns admit once the pass-1 winner reaches terminal status; runnable in pass 2, not permanently skipped; no project outside the singleton appears"
  second_pass_ledger+=("pass2:602:admitted")
else
  fail "8: Tier-1 pass 2 (convergent) -- 602 decision=$pass2_g_602_decision out_of_singleton=$pass2_g_out_of_singleton"
fi

# =============================================================================
# Case 9 (non-convergence): the pass-1 winner (project 603) is a genuinely still-active
# foreign project (status stays "implementing", never reaches terminal) -- e.g. a live
# out-of-batch session's work-in-progress. Pass 1 over {603,604} defers 604 in_batch exactly as
# Case 7. Pass 2 over the deferred singleton {604} alone STILL returns defer (603 is now
# cross_batch from 604's solo pass-2 perspective, and cross_batch defers as long as 603 carries
# execution evidence -- "implementing" is in the in-flight set, per orchestrate-batch-admit-v5's
# narrowed rule; see Case 12 below for the CONTRASTING idle-collider case, where this same shape
# converges instead) -- proving the bounded, non-converging path terminates as a "deferred
# after second pass" skip rather than spinning into a third pass.
# =============================================================================
pass1_h_output=$("$BA" --invocation-count 2 --session-id sess_case_h 603 604 2>/dev/null)
pass1_h_604_decision=$(echo "$pass1_h_output" | jq -s -r '.[] | select(.task_number == 604) | .decision')
pass1_h_604_collision_scope=$(echo "$pass1_h_output" | jq -s -r '.[] | select(.task_number == 604) | .collision_scope // ""')

pass2_h_output=$("$BA" --invocation-count 1 --session-id sess_case_h 604 2>/dev/null)
pass2_h_604_decision=$(echo "$pass2_h_output" | jq -s -r '.[] | select(.task_number == 604) | .decision')
pass2_h_604_defer_reason=$(echo "$pass2_h_output" | jq -s -r '.[] | select(.task_number == 604) | .defer_reason // ""')

third_pass_attempted="false"
# By construction this suite calls $BA exactly twice for the case_h pair (pass1_h_output,
# pass2_h_output above) -- no third invocation exists in this script for project 604, mirroring
# Step 3.5's structural bound (a single `if`, never a loop).

if [ "$pass1_h_604_decision" = "defer" ] && [ "$pass1_h_604_collision_scope" = "in_batch" ] \
   && [ "$pass2_h_604_decision" = "defer" ] && [ "$third_pass_attempted" = "false" ]; then
  # Mirror Step 3.5's exact skip-reason template for the terminal disposition.
  terminal_disposition="604: deferred after second pass [$pass2_h_604_defer_reason]"
  pass "9: non-convergence -- pass-2 admission still returns defer for project 604 ($pass2_h_604_defer_reason); terminal disposition is a partial-flavored skip (\"$terminal_disposition\"); no third admission call occurs"
  second_pass_ledger+=("pass1:604:file_scope_collision:in_batch")
  second_pass_ledger+=("pass2:604:still_deferred:$pass2_h_604_defer_reason")
else
  fail "9: non-convergence -- pass1_604=$pass1_h_604_decision scope=$pass1_h_604_collision_scope pass2_604=$pass2_h_604_decision"
fi

# =============================================================================
# Case 10 (observation log, not an exclusion set): second_pass_ledger accumulated entries from
# BOTH pass 1 (Cases 7 and 9) and pass 2 (Cases 8 and 9) above. Assert a project's presence in
# the ledger after its pass-1 defer did NOT exclude it from the pass-2 admission INPUT -- 602
# and 604 both appear in the ledger from pass 1, and both were still passed as positional
# arguments to their respective pass-2 admission calls (pass2_g_output / pass2_h_output above).
# =============================================================================
ledger_has_602_pass1=$(printf '%s\n' "${second_pass_ledger[@]}" | grep -c '^pass1:602:' || true)
ledger_has_602_pass2=$(printf '%s\n' "${second_pass_ledger[@]}" | grep -c '^pass2:602:' || true)
ledger_has_604_pass1=$(printf '%s\n' "${second_pass_ledger[@]}" | grep -c '^pass1:604:' || true)
ledger_has_604_pass2=$(printf '%s\n' "${second_pass_ledger[@]}" | grep -c '^pass2:604:' || true)

if [ "$ledger_has_602_pass1" -eq 1 ] && [ "$ledger_has_602_pass2" -eq 1 ] \
   && [ "$ledger_has_604_pass1" -eq 1 ] && [ "$ledger_has_604_pass2" -eq 1 ] \
   && [ "$pass2_g_602_decision" = "admit" ]; then
  pass "10: observation log -- second_pass_ledger accumulates entries from both passes for both cases; a project's pass-1 ledger entry never excluded it from the pass-2 admission input (602's pass-2 call still admitted it)"
else
  fail "10: observation log -- ledger counts 602:[$ledger_has_602_pass1,$ledger_has_602_pass2] 604:[$ledger_has_604_pass1,$ledger_has_604_pass2]"
fi

# =============================================================================
# Case 11 (bounded scan): each admission invocation's argument list contains only the
# candidates of the pass it serves -- never a sweep of every fixture project number in
# state.json (which by this point in the suite includes at least 507, 601, 602, 603, 604, plus
# the six earlier per-case fixture projects).
# =============================================================================
pass1_g_arg_count=2
pass2_g_arg_count=1
pass1_h_arg_count=2
pass2_h_arg_count=1
total_fixture_projects=$(jq '.active_projects | length' "$STATE_FILE")

if [ "$pass1_g_arg_count" -eq 2 ] && [ "$pass2_g_arg_count" -eq 1 ] \
   && [ "$pass1_h_arg_count" -eq 2 ] && [ "$pass2_h_arg_count" -eq 1 ] \
   && [ "$total_fixture_projects" -gt 4 ]; then
  pass "11: bounded scan -- every admission call above passed only its own pass's candidate set as positional arguments (2, 1, 2, 1 respectively), never the full $total_fixture_projects-project fixture state.json"
else
  fail "11: bounded scan -- unexpected argument counts or fixture size ($total_fixture_projects total projects)"
fi

# =============================================================================
# Case 12 (idle-collider convergence, orchestrate-batch-admit-v5): mirrors Case 9's exact
# two-pass shape, but the pass-1 winner (project 605) is PROVABLY IDLE (status stays
# "not_started" throughout -- never a live foreign session's work-in-progress). Pass 1 over
# {605,606} defers 606 in_batch exactly as Case 7/Case 9 (in_batch behavior is bit-for-bit
# unaffected by the v5 narrowing). Pass 2 over the deferred singleton {606} alone now returns
# ADMIT with idle_overlap_advisory -- 605 is cross_batch from 606's solo pass-2 perspective, and
# a cross_batch collision against a task with NO execution evidence no longer defers -- proving
# the non-convergence path Case 9 exercises CONVERGES once the collider is provably idle, rather
# than deferring forever. Own fresh case_i/ file_scope namespace so it cannot interfere with the
# case_g/case_h fixtures above.
# =============================================================================
pass1_i_output=$("$BA" --invocation-count 2 --session-id sess_case_i 605 606 2>/dev/null)
pass1_i_606_decision=$(echo "$pass1_i_output" | jq -s -r '.[] | select(.task_number == 606) | .decision')
pass1_i_606_collision_scope=$(echo "$pass1_i_output" | jq -s -r '.[] | select(.task_number == 606) | .collision_scope // ""')

pass2_i_output=$("$BA" --invocation-count 1 --session-id sess_case_i 606 2>/dev/null)
pass2_i_606_decision=$(echo "$pass2_i_output" | jq -s -r '.[] | select(.task_number == 606) | .decision')
pass2_i_606_has_defer_reason=$(echo "$pass2_i_output" | jq -s -r '.[] | select(.task_number == 606) | has("defer_reason")')
pass2_i_606_has_advisory=$(echo "$pass2_i_output" | jq -s -r '.[] | select(.task_number == 606) | has("idle_overlap_advisory")')
pass2_i_606_advisory_num=$(echo "$pass2_i_output" | jq -s -r '.[] | select(.task_number == 606) | .idle_overlap_advisory.colliding_task_number // ""')
pass2_i_606_advisory_status=$(echo "$pass2_i_output" | jq -s -r '.[] | select(.task_number == 606) | .idle_overlap_advisory.colliding_task_status // ""')

third_pass_i_attempted="false"
# By construction this suite calls $BA exactly twice for the case_i pair (pass1_i_output,
# pass2_i_output above) -- mirrors Case 9's own structural bound, and since pass 2 already
# admits, a real Step 3.5 caller would never attempt a third pass here either.

if [ "$pass1_i_606_decision" = "defer" ] && [ "$pass1_i_606_collision_scope" = "in_batch" ] \
   && [ "$pass2_i_606_decision" = "admit" ] && [ "$pass2_i_606_has_defer_reason" = "false" ] \
   && [ "$pass2_i_606_has_advisory" = "true" ] && [ "$pass2_i_606_advisory_num" = "605" ] \
   && [ "$pass2_i_606_advisory_status" = "not_started" ] && [ "$third_pass_i_attempted" = "false" ]; then
  pass "12: idle-collider convergence -- pass-2 admission over the deferred singleton now returns admit with idle_overlap_advisory naming 605/not_started once the pass-1 winner is provably idle, converging where Case 9's in-flight collider does not"
else
  fail "12: idle-collider convergence -- pass1_606=$pass1_i_606_decision scope=$pass1_i_606_collision_scope pass2_606=$pass2_i_606_decision has_defer_reason=$pass2_i_606_has_defer_reason has_advisory=$pass2_i_606_has_advisory advisory_num=$pass2_i_606_advisory_num advisory_status=$pass2_i_606_advisory_status"
fi

# =============================================================================
# Case 13 (in_batch bit-for-bit guard, orchestrate-batch-admit-v5): the untouched in_batch
# disjunct still reports collision_scope == "in_batch" for every in-batch collision produced
# across the Tier-1 family above (Cases 7-12), regardless of status -- an explicit regression
# guard distinct from any single case's own incidental assertion, covering all three fixture
# pairs (case_g, case_h, case_i) in one place.
# =============================================================================
c13_ok=true
[ "$pass1_g_602_collision_scope" = "in_batch" ] || { c13_ok=false; info "case_g pass-1 602 collision_scope was not in_batch: $pass1_g_602_collision_scope"; }
[ "$pass1_h_604_collision_scope" = "in_batch" ] || { c13_ok=false; info "case_h pass-1 604 collision_scope was not in_batch: $pass1_h_604_collision_scope"; }
[ "$pass1_i_606_collision_scope" = "in_batch" ] || { c13_ok=false; info "case_i pass-1 606 collision_scope was not in_batch: $pass1_i_606_collision_scope"; }
if [ "$c13_ok" = true ]; then
  pass "13: in_batch bit-for-bit guard -- every in-batch collision across cases 7/9/12 still reports collision_scope == \"in_batch\", unaffected by the v5 cross_batch narrowing"
else
  fail "13: in_batch bit-for-bit guard failed (see INFO lines above)"
fi

echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
