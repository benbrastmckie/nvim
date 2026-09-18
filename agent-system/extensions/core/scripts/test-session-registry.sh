#!/usr/bin/env bash
# test-session-registry.sh - Isolated-temp-root suite proving task-lock.sh's session-registry
# contract (session-register / session-heartbeat / session-release / session-reap).
#
# Never touches the real specs/ tree. Builds a throwaway root satisfying
# deploy-root-guard.sh's ".claude/scripts/ or .opencode/scripts/, two levels under root" check
# by copying the real task-lock.sh and deploy-root-guard.sh into $TMPROOT/.claude/scripts/,
# alongside a fixture state.json and specs/.sessions/ entries at controlled heartbeat_at ages.
# This is what makes an isolated temp root work with zero testability hooks added to production
# code -- task-lock.sh itself is copied byte-for-byte and never learns it is under test. Modeled
# directly on test-task-lock-reap.sh's precedent (temp-root construction, pass/fail/info helpers,
# cleanup trap, controlled-epoch timestamp helpers -- no sleeping).
#
# See context/patterns/task-lock.md's Session-Registry CLI section for the full subcommand
# contract this suite verifies.
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

# --- Locate the real task-lock.sh, deploy-root-guard.sh, and lib/common.sh to copy into the
# fixture ---
if [ ! -f "$SCRIPT_DIR/task-lock.sh" ] || [ ! -f "$SCRIPT_DIR/deploy-root-guard.sh" ] \
    || [ ! -f "$SCRIPT_DIR/lib/common.sh" ] || [ ! -f "$SCRIPT_DIR/lib/task-lookup-lib.sh" ]; then
  echo "ERROR: expected task-lock.sh, deploy-root-guard.sh, lib/common.sh, and lib/task-lookup-lib.sh alongside this script in $SCRIPT_DIR" >&2
  exit 1
fi

# --- Build the isolated temp root ---
TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/session-registry-test.XXXXXX")"

cleanup() {
  [ -n "${TMPROOT:-}" ] && [ -d "$TMPROOT" ] && rm -rf "$TMPROOT"
}
trap cleanup EXIT

mkdir -p "$TMPROOT/.claude/scripts/lib"
mkdir -p "$TMPROOT/specs"
cp "$SCRIPT_DIR/task-lock.sh" "$TMPROOT/.claude/scripts/task-lock.sh"
cp "$SCRIPT_DIR/deploy-root-guard.sh" "$TMPROOT/.claude/scripts/deploy-root-guard.sh"
cp "$SCRIPT_DIR/lib/common.sh" "$TMPROOT/.claude/scripts/lib/common.sh"
cp "$SCRIPT_DIR/lib/task-lookup-lib.sh" "$TMPROOT/.claude/scripts/lib/task-lookup-lib.sh"
chmod +x "$TMPROOT/.claude/scripts/task-lock.sh"

TL="$TMPROOT/.claude/scripts/task-lock.sh"

# --- Timestamp helpers (no sleeping -- controlled epoch arithmetic) ---
now_epoch() { date -u +%s; }
iso_at() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }
minutes_ago_iso() { iso_at "$(( $(now_epoch) - ($1 * 60) ))"; }

write_session_fixture() {
  # write_session_fixture <sessions_dir> <session_id> <pid> <task_numbers_json> <file_scope_json> <heartbeat_minutes_ago>
  local sessions_dir="$1" session_id="$2" pid="$3" task_numbers_json="$4" file_scope_json="$5" mins_ago="$6"
  local ts
  ts=$(minutes_ago_iso "$mins_ago")
  mkdir -p "$sessions_dir"
  jq -n \
    --arg session_id "$session_id" \
    --argjson pid "$pid" \
    --arg pid_source "test-fixture" \
    --arg command "/test $session_id" \
    --argjson task_numbers "$task_numbers_json" \
    --argjson file_scope "$file_scope_json" \
    --arg ts "$ts" \
    '{session_id: $session_id, pid: $pid, pid_source: $pid_source, command: $command, task_numbers: $task_numbers, file_scope: $file_scope, started_at: $ts, heartbeat_at: $ts}' \
    > "$sessions_dir/${session_id}.json"
}

# --- Fixture state.json: tasks with distinct, partially-overlapping file_scope arrays ---
cat > "$TMPROOT/specs/state.json" << 'EOF'
{
  "next_project_number": 900,
  "active_projects": [
    {"project_number": 801, "project_name": "scope_a", "status": "implementing", "task_type": "general", "file_scope": ["path/a.sh", "path/shared/"]},
    {"project_number": 802, "project_name": "scope_b", "status": "implementing", "task_type": "general", "file_scope": ["path/b.sh", "path/shared/x.md"]},
    {"project_number": 803, "project_name": "scope_c", "status": "implementing", "task_type": "general"}
  ]
}
EOF

SESSIONS_DIR="$TMPROOT/specs/.sessions"

# Find a definitely-dead pid for dead-pid fixtures: a large candidate, verified not alive.
DEAD_PID=999999
while kill -0 "$DEAD_PID" 2>/dev/null; do
  DEAD_PID=$(( DEAD_PID - 1 ))
done

info "Fixture built at $TMPROOT (dead pid probe resolved to $DEAD_PID)"

# =====================================================================
# Case 1: register writes every required field
# =====================================================================
reg_out=$("$TL" session-register "sess_case1" "/implement 801,802" "801,802" 2>&1)
reg_exit=$?

c1_ok=true
[ "$reg_exit" -eq 0 ] || { c1_ok=false; info "session-register exit code was $reg_exit, expected 0 ($reg_out)"; }
entry_file="$SESSIONS_DIR/sess_case1.json"
[ -f "$entry_file" ] || { c1_ok=false; info "expected entry file $entry_file not found"; }
if [ -f "$entry_file" ]; then
  for field in session_id pid pid_source command task_numbers file_scope started_at heartbeat_at; do
    val=$(jq -r --arg f "$field" 'has($f)' "$entry_file" 2>/dev/null)
    [ "$val" = "true" ] || { c1_ok=false; info "entry missing required field: $field"; }
  done
  session_id_field=$(jq -r '.session_id' "$entry_file" 2>/dev/null)
  [ "$session_id_field" = "sess_case1" ] || { c1_ok=false; info "session_id field mismatch: $session_id_field"; }
fi

if [ "$c1_ok" = true ]; then
  pass "1: session-register writes every required field"
else
  fail "1: register-fields case failed (see INFO lines above)"
fi

# =====================================================================
# Case 2: file_scope is the deduplicated UNION, not a concatenation
# =====================================================================
c2_ok=true
union=$(jq -c '.file_scope | sort' "$entry_file" 2>/dev/null)
expected=$(jq -n -c '["path/a.sh","path/b.sh","path/shared/","path/shared/x.md"] | sort')
[ "$union" = "$expected" ] || { c2_ok=false; info "file_scope union mismatch: got $union, expected $expected"; }

if [ "$c2_ok" = true ]; then
  pass "2: file_scope is the deduplicated UNION across a multi-task registration"
else
  fail "2: file_scope union case failed (see INFO lines above)"
fi

# =====================================================================
# Case 3: re-registering the same session_id preserves started_at, advances heartbeat_at
# =====================================================================
started_before=$(jq -r '.started_at' "$entry_file")
heartbeat_before=$(jq -r '.heartbeat_at' "$entry_file")
# Force a distinguishable heartbeat_at by backdating started_at/heartbeat_at first, then
# re-registering (no sleeping).
jq --arg ts "$(minutes_ago_iso 5)" '.started_at = $ts | .heartbeat_at = $ts' "$entry_file" > "${entry_file}.tmp" && mv "${entry_file}.tmp" "$entry_file"
backdated_started=$(jq -r '.started_at' "$entry_file")
"$TL" session-register "sess_case1" "/implement 801,802" "801,802" >/dev/null 2>&1
started_after=$(jq -r '.started_at' "$entry_file")
heartbeat_after=$(jq -r '.heartbeat_at' "$entry_file")

c3_ok=true
[ "$started_after" = "$backdated_started" ] || { c3_ok=false; info "started_at was not preserved: before=$backdated_started after=$started_after"; }
[ "$heartbeat_after" != "$backdated_started" ] || { c3_ok=false; info "heartbeat_at was not advanced past the backdated timestamp"; }

if [ "$c3_ok" = true ]; then
  pass "3: re-registering the same session_id preserves started_at and advances heartbeat_at"
else
  fail "3: re-register-preserves-started_at case failed (see INFO lines above)"
fi

# =====================================================================
# Case 4: heartbeat on a missing entry warns and exits 0 (never blocks)
# =====================================================================
hb_out=$("$TL" session-heartbeat "sess_does_not_exist" 2>&1)
hb_exit=$?

c4_ok=true
[ "$hb_exit" -eq 0 ] || { c4_ok=false; info "session-heartbeat on missing entry exit code was $hb_exit, expected 0"; }
echo "$hb_out" | grep -qi "WARN" || { c4_ok=false; info "session-heartbeat on missing entry produced no WARN"; }

if [ "$c4_ok" = true ]; then
  pass "4: session-heartbeat on a missing entry warns and exits 0"
else
  fail "4: heartbeat-missing-entry case failed (see INFO lines above)"
fi

# =====================================================================
# Case 5: release is idempotent (two consecutive releases both exit 0)
# =====================================================================
"$TL" session-register "sess_case5" "/implement 803" "803" >/dev/null 2>&1
rel1_exit=0
"$TL" session-release "sess_case5" >/dev/null 2>&1 || rel1_exit=$?
rel1_gone=true
[ -f "$SESSIONS_DIR/sess_case5.json" ] && rel1_gone=false
rel2_exit=0
"$TL" session-release "sess_case5" >/dev/null 2>&1 || rel2_exit=$?

c5_ok=true
[ "$rel1_exit" -eq 0 ] || { c5_ok=false; info "first session-release exit code was $rel1_exit, expected 0"; }
[ "$rel1_gone" = true ] || { c5_ok=false; info "entry still present after first release"; }
[ "$rel2_exit" -eq 0 ] || { c5_ok=false; info "second session-release exit code was $rel2_exit, expected 0"; }

if [ "$c5_ok" = true ]; then
  pass "5: session-release is idempotent (two consecutive releases both exit 0)"
else
  fail "5: release-idempotent case failed (see INFO lines above)"
fi

# =====================================================================
# Reap fixtures: dead-pid young/old, live-pid young/old, corrupt
# =====================================================================
rm -f "$SESSIONS_DIR"/*.json 2>/dev/null

# TASK_LOCK_STALE_MIN/REAP_MIN irrelevant here; session-registry defaults are
# SESSION_REGISTRY_DEAD_PID_MIN=10, SESSION_REGISTRY_REAP_MIN=240 (not overridden -- exercised at
# real production thresholds).
write_session_fixture "$SESSIONS_DIR" "sess_dead_old" "$DEAD_PID" '[801]' '[]' 20    # dead pid, 20min > 10min floor
write_session_fixture "$SESSIONS_DIR" "sess_dead_young" "$DEAD_PID" '[802]' '[]' 5   # dead pid, 5min < 10min floor
write_session_fixture "$SESSIONS_DIR" "sess_live_stale" "$$" '[803]' '[]' 300        # live pid, 300min > 240min
write_session_fixture "$SESSIONS_DIR" "sess_live_young" "$$" '[801]' '[]' 2          # live pid, 2min < 240min

mkdir -p "$SESSIONS_DIR"
echo "not valid json" > "$SESSIONS_DIR/sess_corrupt.json"
corrupt_epoch=$(( $(now_epoch) - (300 * 60) ))
touch -d "@$corrupt_epoch" "$SESSIONS_DIR/sess_corrupt.json"

# =====================================================================
# Case 5a: session-list reports liveness_reason correctly across the dead-pid-within-grace
# boundary -- dead-pid-within-grace (below floor), dead-pid (above floor), pid-alive (live pid).
# Run against the full untouched fixture set, BEFORE Case 6/7/8's live reap consumes
# sess_dead_old (it would no longer be listable afterward).
# =====================================================================
list_out=$("$TL" session-list 2>&1)
list_exit=$?

c5a_ok=true
[ "$list_exit" -eq 0 ] || { c5a_ok=false; info "session-list exit code was $list_exit, expected 0"; }

dead_young_entry=$(echo "$list_out" | jq -c 'select(.session_id=="sess_dead_young")' 2>/dev/null)
dead_young_reason=$(echo "$dead_young_entry" | jq -r '.liveness_reason' 2>/dev/null)
dead_young_live=$(echo "$dead_young_entry" | jq -r '.live' 2>/dev/null)
[ "$dead_young_reason" = "dead-pid-within-grace" ] || { c5a_ok=false; info "sess_dead_young liveness_reason was '$dead_young_reason', expected dead-pid-within-grace"; }
[ "$dead_young_live" = "true" ] || { c5a_ok=false; info "sess_dead_young live was '$dead_young_live', expected true"; }

dead_old_entry=$(echo "$list_out" | jq -c 'select(.session_id=="sess_dead_old")' 2>/dev/null)
dead_old_reason=$(echo "$dead_old_entry" | jq -r '.liveness_reason' 2>/dev/null)
dead_old_live=$(echo "$dead_old_entry" | jq -r '.live' 2>/dev/null)
[ "$dead_old_reason" = "dead-pid" ] || { c5a_ok=false; info "sess_dead_old liveness_reason was '$dead_old_reason', expected dead-pid"; }
[ "$dead_old_live" = "false" ] || { c5a_ok=false; info "sess_dead_old live was '$dead_old_live', expected false"; }

live_young_entry=$(echo "$list_out" | jq -c 'select(.session_id=="sess_live_young")' 2>/dev/null)
live_young_reason=$(echo "$live_young_entry" | jq -r '.liveness_reason' 2>/dev/null)
live_young_live=$(echo "$live_young_entry" | jq -r '.live' 2>/dev/null)
[ "$live_young_reason" = "pid-alive" ] || { c5a_ok=false; info "sess_live_young liveness_reason was '$live_young_reason', expected pid-alive"; }
[ "$live_young_live" = "true" ] || { c5a_ok=false; info "sess_live_young live was '$live_young_live', expected true"; }

if [ "$c5a_ok" = true ]; then
  pass "5a: session-list reports dead-pid-within-grace/dead-pid/pid-alive correctly at the grace-floor boundary"
else
  fail "5a: dead-pid-within-grace reason-string case failed (see INFO lines above)"
fi

# =====================================================================
# Case 6: session-reap --dry-run removes nothing (run FIRST, against the full fixture)
# =====================================================================
dry_run_out=$("$TL" session-reap --dry-run 2>&1)
dry_run_exit=$?

c6_ok=true
[ "$dry_run_exit" -eq 0 ] || { c6_ok=false; info "session-reap --dry-run exit code was $dry_run_exit, expected 0"; }
for f in sess_dead_old sess_dead_young sess_live_stale sess_live_young sess_corrupt; do
  [ -f "$SESSIONS_DIR/${f}.json" ] || { c6_ok=false; info "dry-run removed $f"; }
done
echo "$dry_run_out" | grep -qF "sess_dead_old" || { c6_ok=false; info "dry-run output missing sess_dead_old"; }
echo "$dry_run_out" | grep -q "would reap" || { c6_ok=false; info "dry-run output missing 'would reap'"; }
echo "$dry_run_out" | grep -E "would reap.*sess_dead_young" >/dev/null && { c6_ok=false; info "dry-run output incorrectly selected sess_dead_young (dead-pid-within-grace must not be reaped)"; }

if [ "$c6_ok" = true ]; then
  pass "6: session-reap --dry-run reports would-reap candidates, removes nothing, and does not select sess_dead_young"
else
  fail "6: dry-run case failed (see INFO lines above)"
fi

# =====================================================================
# Live reap: exercises cases 7, 8, 9, 10
# =====================================================================
live_out=$("$TL" session-reap 2>&1)
live_exit=$?
live_ok_base=true
[ "$live_exit" -eq 0 ] || { live_ok_base=false; info "live session-reap exit code was $live_exit, expected 0"; }

# --- Case 7: dead-pid entry older than SESSION_REGISTRY_DEAD_PID_MIN is reaped, reason dead-pid ---
c7_ok=$live_ok_base
[ -f "$SESSIONS_DIR/sess_dead_old.json" ] && { c7_ok=false; info "sess_dead_old was NOT reaped"; }
echo "$live_out" | grep -qF "sess_dead_old" || { c7_ok=false; info "live output missing sess_dead_old"; }
echo "$live_out" | grep -E "reaped:.*sess_dead_old.*reason=dead-pid" >/dev/null || { c7_ok=false; info "live output missing reason=dead-pid for sess_dead_old"; }

if [ "$c7_ok" = true ]; then
  pass "7: dead-pid entry older than SESSION_REGISTRY_DEAD_PID_MIN is reaped with reason dead-pid"
else
  fail "7: dead-pid-old case failed (see INFO lines above)"
fi

# --- Case 8: dead-pid entry YOUNGER than the floor is NOT reaped ---
c8_ok=true
[ -f "$SESSIONS_DIR/sess_dead_young.json" ] || { c8_ok=false; info "sess_dead_young (below dead-pid floor) was incorrectly reaped"; }
echo "$live_out" | grep -qF "sess_dead_young" && { c8_ok=false; info "sess_dead_young unexpectedly appeared in live reap output"; }

if [ "$c8_ok" = true ]; then
  pass "8: dead-pid entry younger than SESSION_REGISTRY_DEAD_PID_MIN is NOT reaped (the floor guard)"
else
  fail "8: dead-pid-young-floor-guard case failed (see INFO lines above)"
fi

# --- Case 9: live-pid entry -- young survives, old (past SESSION_REGISTRY_REAP_MIN) reaped stale-heartbeat ---
c9_ok=$live_ok_base
[ -f "$SESSIONS_DIR/sess_live_young.json" ] || { c9_ok=false; info "sess_live_young (below stale-heartbeat threshold) was incorrectly reaped"; }
[ -f "$SESSIONS_DIR/sess_live_stale.json" ] && { c9_ok=false; info "sess_live_stale was NOT reaped despite exceeding SESSION_REGISTRY_REAP_MIN"; }
echo "$live_out" | grep -E "reaped:.*sess_live_stale.*reason=stale-heartbeat" >/dev/null || { c9_ok=false; info "live output missing reason=stale-heartbeat for sess_live_stale"; }

if [ "$c9_ok" = true ]; then
  pass "9: live-pid entry is not reaped below SESSION_REGISTRY_REAP_MIN, reaped with reason stale-heartbeat above it"
else
  fail "9: live-pid-reap-min case failed (see INFO lines above)"
fi

# --- Case 10: corrupt/unparseable entry falls back to file mtime, reported not silently ignored ---
c10_ok=$live_ok_base
[ -f "$SESSIONS_DIR/sess_corrupt.json" ] && { c10_ok=false; info "sess_corrupt (mtime-stale) was NOT reaped"; }
echo "$live_out" | grep -qF "sess_corrupt" || { c10_ok=false; info "live output missing a line for sess_corrupt"; }
echo "$live_out" | grep -E "sess_corrupt.*missing/unparseable" >/dev/null || { c10_ok=false; info "live output missing the missing/unparseable annotation for sess_corrupt"; }

if [ "$c10_ok" = true ]; then
  pass "10: corrupt/unparseable entry falls back to file mtime and is reported, never silently ignored"
else
  fail "10: corrupt-entry case failed (see INFO lines above)"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
