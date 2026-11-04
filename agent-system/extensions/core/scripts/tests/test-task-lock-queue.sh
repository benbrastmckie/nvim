#!/usr/bin/env bash
# test-task-lock-queue.sh - Isolated-temp-root suite proving task-lock.sh's per-repo
# Orchestration-Queue CLI contract (queue-register / queue-heartbeat / queue-finish /
# queue-reap / queue-list / queue-check).
#
# Never touches the real specs/ tree. Builds a throwaway root satisfying
# deploy-root-guard.sh's ".claude/scripts/ or .opencode/scripts/, two levels under root" check
# by copying the real task-lock.sh and its sibling deps into $TMPROOT/.claude/scripts/,
# alongside fixture state.json and specs/.orchestration/{queue,archive}/ entries at controlled
# ages. Modeled directly on test-session-registry.sh and test-task-lock-liveness.sh's
# precedent (temp-root construction, pass/fail/info helpers, cleanup trap, controlled-epoch
# timestamp helpers, no sleeping).
#
# See context/patterns/task-lock.md's Orchestration-Queue CLI section for the full contract
# this suite verifies.
#
# Exit 0 when all cases PASS, exit 1 when any case FAILS.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; FAILED=$((FAILED + 1)); }
info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

if [ ! -f "$SRC_DIR/task-lock.sh" ] || [ ! -f "$SRC_DIR/deploy-root-guard.sh" ] \
    || [ ! -f "$SRC_DIR/lib/common.sh" ] || [ ! -f "$SRC_DIR/lib/task-lookup-lib.sh" ] \
    || [ ! -f "$SRC_DIR/lib/file-scope-overlap.sh" ]; then
  echo "ERROR: expected task-lock.sh, deploy-root-guard.sh, lib/common.sh, lib/task-lookup-lib.sh, and lib/file-scope-overlap.sh alongside this suite's sibling scripts dir ($SRC_DIR)" >&2
  exit 1
fi

TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/task-lock-queue-test.XXXXXX")"
cleanup() { [ -n "${TMPROOT:-}" ] && [ -d "$TMPROOT" ] && rm -rf "$TMPROOT"; }
trap cleanup EXIT

mkdir -p "$TMPROOT/.claude/scripts/lib"
mkdir -p "$TMPROOT/specs"
cp "$SRC_DIR/task-lock.sh" "$TMPROOT/.claude/scripts/task-lock.sh"
cp "$SRC_DIR/deploy-root-guard.sh" "$TMPROOT/.claude/scripts/deploy-root-guard.sh"
cp "$SRC_DIR/lib/common.sh" "$TMPROOT/.claude/scripts/lib/common.sh"
cp "$SRC_DIR/lib/task-lookup-lib.sh" "$TMPROOT/.claude/scripts/lib/task-lookup-lib.sh"
cp "$SRC_DIR/lib/file-scope-overlap.sh" "$TMPROOT/.claude/scripts/lib/file-scope-overlap.sh"
chmod +x "$TMPROOT/.claude/scripts/task-lock.sh"

TL="$TMPROOT/.claude/scripts/task-lock.sh"
QUEUE_DIR="$TMPROOT/specs/.orchestration/queue"
ARCHIVE_DIR="$TMPROOT/specs/.orchestration/archive"

# --- Timestamp helpers (no sleeping -- controlled epoch arithmetic) ---
now_epoch() { date -u +%s; }
iso_at() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }
minutes_ago_iso() { iso_at "$(( $(now_epoch) - ($1 * 60) ))"; }

write_queue_fixture() {
  # write_queue_fixture <dir> <orchestration_id> <session_id> <pid> <task_numbers_json> \
  #   <file_scope_json> <state> <heartbeat_minutes_ago>
  local dir="$1" oid="$2" sid="$3" pid="$4" task_numbers_json="$5" file_scope_json="$6" \
    state="$7" mins_ago="$8"
  local ts
  ts=$(minutes_ago_iso "$mins_ago")
  mkdir -p "$dir"
  jq -n \
    --arg orchestration_id "$oid" \
    --arg session_id "$sid" \
    --argjson pid "$pid" \
    --arg pid_source "test-fixture" \
    --arg command "/orchestrate test" \
    --argjson task_numbers "$task_numbers_json" \
    --argjson file_scope "$file_scope_json" \
    --arg state "$state" \
    --arg ts "$ts" \
    '{orchestration_id: $orchestration_id, session_id: $session_id, pid: $pid,
      pid_source: $pid_source, command: $command, task_numbers: $task_numbers,
      file_scope: $file_scope, state: $state, started_at: $ts, heartbeat_at: $ts,
      finished_at: null, archived_at: null, disposition_reason: null}' \
    > "$dir/${oid}.json"
}

# --- Fixture state.json: tasks with partially-overlapping file_scope and one dependency edge ---
cat > "$TMPROOT/specs/state.json" << 'EOF'
{
  "next_project_number": 900,
  "active_projects": [
    {"project_number": 701, "project_name": "scope_a", "status": "implementing", "task_type": "general", "file_scope": ["path/a.sh"], "dependencies": []},
    {"project_number": 702, "project_name": "scope_b", "status": "implementing", "task_type": "general", "file_scope": ["path/b.sh"], "dependencies": []},
    {"project_number": 703, "project_name": "scope_a_edge", "status": "implementing", "task_type": "general", "file_scope": ["path/a.sh"], "dependencies": [701]},
    {"project_number": 704, "project_name": "scope_c", "status": "implementing", "task_type": "general", "file_scope": ["path/c.sh"], "dependencies": []}
  ]
}
EOF

# Find a definitely-dead pid for dead-pid fixtures (same technique as test-session-registry.sh).
DEAD_PID=999999
while kill -0 "$DEAD_PID" 2>/dev/null; do
  DEAD_PID=$(( DEAD_PID - 1 ))
done

info "Fixture built at $TMPROOT (dead pid probe resolved to $DEAD_PID)"

# =====================================================================
# Case 1: queue-register creates the file with state: registered and a well-formed
# orchestration_id, printed on stdout
# =====================================================================
reg_out=$("$TL" queue-register "sess_case1" "/orchestrate 701" "701" 2>&1)
reg_exit=$?

c1_ok=true
[ "$reg_exit" -eq 0 ] || { c1_ok=false; info "queue-register exit code was $reg_exit, expected 0 ($reg_out)"; }
orch1="$reg_out"
[[ "$orch1" =~ ^orch_[0-9]+_[0-9a-f]{6}$ ]] || { c1_ok=false; info "orchestration_id '$orch1' is not well-formed"; }
entry_file="$QUEUE_DIR/${orch1}.json"
[ -f "$entry_file" ] || { c1_ok=false; info "expected entry file $entry_file not found"; }
if [ -f "$entry_file" ]; then
  for field in orchestration_id session_id pid pid_source command task_numbers file_scope state started_at heartbeat_at finished_at archived_at; do
    val=$(jq -r --arg f "$field" 'has($f)' "$entry_file" 2>/dev/null)
    [ "$val" = "true" ] || { c1_ok=false; info "entry missing required field: $field"; }
  done
  state_field=$(jq -r '.state' "$entry_file" 2>/dev/null)
  [ "$state_field" = "registered" ] || { c1_ok=false; info "state field was '$state_field', expected registered"; }
fi

if [ "$c1_ok" = true ]; then
  pass "1: queue-register creates the file with state: registered and a well-formed orchestration_id"
else
  fail "1: register case failed (see INFO lines above)"
fi

# =====================================================================
# Case 2: re-register (same orchestration_id) preserves started_at
# =====================================================================
jq --arg ts "$(minutes_ago_iso 5)" '.started_at = $ts | .heartbeat_at = $ts' "$entry_file" > "${entry_file}.tmp" && mv "${entry_file}.tmp" "$entry_file"
backdated_started=$(jq -r '.started_at' "$entry_file")
"$TL" queue-register "sess_case1" "/orchestrate 701" "701" --orchestration-id "$orch1" >/dev/null 2>&1
started_after=$(jq -r '.started_at' "$entry_file")

c2_ok=true
[ "$started_after" = "$backdated_started" ] || { c2_ok=false; info "started_at was not preserved: before=$backdated_started after=$started_after"; }

if [ "$c2_ok" = true ]; then
  pass "2: re-registering the same orchestration_id preserves started_at"
else
  fail "2: re-register-preserves-started_at case failed (see INFO lines above)"
fi

# =====================================================================
# Case 3: queue-heartbeat advances heartbeat_at and sets state: running
# =====================================================================
jq --arg ts "$(minutes_ago_iso 5)" '.heartbeat_at = $ts' "$entry_file" > "${entry_file}.tmp" && mv "${entry_file}.tmp" "$entry_file"
heartbeat_before=$(jq -r '.heartbeat_at' "$entry_file")
"$TL" queue-heartbeat "sess_case1" >/dev/null 2>&1
heartbeat_after=$(jq -r '.heartbeat_at' "$entry_file")
state_after_hb=$(jq -r '.state' "$entry_file")

c3_ok=true
[ "$heartbeat_after" != "$heartbeat_before" ] || { c3_ok=false; info "heartbeat_at was not advanced"; }
[ "$state_after_hb" = "running" ] || { c3_ok=false; info "state after heartbeat was '$state_after_hb', expected running"; }

if [ "$c3_ok" = true ]; then
  pass "3: queue-heartbeat advances heartbeat_at and sets state: running"
else
  fail "3: heartbeat case failed (see INFO lines above)"
fi

# =====================================================================
# Case 4: queue-heartbeat on a missing entry WARNs and exits 0
# =====================================================================
hb_out=$("$TL" queue-heartbeat "sess_does_not_exist" 2>&1)
hb_exit=$?

c4_ok=true
[ "$hb_exit" -eq 0 ] || { c4_ok=false; info "queue-heartbeat on missing entry exit code was $hb_exit, expected 0"; }
echo "$hb_out" | grep -qi "WARN" || { c4_ok=false; info "queue-heartbeat on missing entry produced no WARN"; }

if [ "$c4_ok" = true ]; then
  pass "4: queue-heartbeat on a missing entry WARNs and exits 0"
else
  fail "4: heartbeat-missing-entry case failed (see INFO lines above)"
fi

# =====================================================================
# Liveness fixtures: dead-pid (above floor), dead-pid-within-grace (below floor),
# stale-heartbeat (live pid, old heartbeat), pid-alive (live pid, young heartbeat), corrupt
# =====================================================================
rm -f "$QUEUE_DIR"/*.json 2>/dev/null

write_queue_fixture "$QUEUE_DIR" "orch_dead_old" "sess_dead_old" "$DEAD_PID" '[702]' '[]' "running" 20
write_queue_fixture "$QUEUE_DIR" "orch_dead_young" "sess_dead_young" "$DEAD_PID" '[702]' '[]' "running" 5
write_queue_fixture "$QUEUE_DIR" "orch_live_stale" "sess_live_stale" "$$" '[702]' '[]' "running" 300
write_queue_fixture "$QUEUE_DIR" "orch_live_young" "sess_live_young" "$$" '[702]' '[]' "running" 2

mkdir -p "$QUEUE_DIR"
echo "not valid json" > "$QUEUE_DIR/orch_corrupt.json"
corrupt_epoch=$(( $(now_epoch) - (300 * 60) ))
touch -d "@$corrupt_epoch" "$QUEUE_DIR/orch_corrupt.json"

# =====================================================================
# Case 5: queue-list reports liveness_reason correctly: pid-alive, dead-pid, stale-heartbeat,
# corrupt (run BEFORE reap consumes any entries)
# =====================================================================
list_out=$("$TL" queue-list 2>&1)
list_exit=$?

c5_ok=true
[ "$list_exit" -eq 0 ] || { c5_ok=false; info "queue-list exit code was $list_exit, expected 0"; }

dead_old_entry=$(echo "$list_out" | jq -c 'select(.orchestration_id=="orch_dead_old")' 2>/dev/null)
dead_old_reason=$(echo "$dead_old_entry" | jq -r '.liveness_reason' 2>/dev/null)
[ "$dead_old_reason" = "dead-pid" ] || { c5_ok=false; info "orch_dead_old liveness_reason was '$dead_old_reason', expected dead-pid"; }

live_stale_entry=$(echo "$list_out" | jq -c 'select(.orchestration_id=="orch_live_stale")' 2>/dev/null)
live_stale_reason=$(echo "$live_stale_entry" | jq -r '.liveness_reason' 2>/dev/null)
[ "$live_stale_reason" = "stale-heartbeat" ] || { c5_ok=false; info "orch_live_stale liveness_reason was '$live_stale_reason', expected stale-heartbeat"; }

live_young_entry=$(echo "$list_out" | jq -c 'select(.orchestration_id=="orch_live_young")' 2>/dev/null)
live_young_reason=$(echo "$live_young_entry" | jq -r '.liveness_reason' 2>/dev/null)
live_young_live=$(echo "$live_young_entry" | jq -r '.live' 2>/dev/null)
[ "$live_young_reason" = "pid-alive" ] || { c5_ok=false; info "orch_live_young liveness_reason was '$live_young_reason', expected pid-alive"; }
[ "$live_young_live" = "true" ] || { c5_ok=false; info "orch_live_young live was '$live_young_live', expected true"; }

corrupt_entry=$(echo "$list_out" | jq -c 'select(.entry_file=="orch_corrupt.json")' 2>/dev/null)
corrupt_reason=$(echo "$corrupt_entry" | jq -r '.liveness_reason' 2>/dev/null)
corrupt_live=$(echo "$corrupt_entry" | jq -r '.live' 2>/dev/null)
[ "$corrupt_reason" = "corrupt" ] || { c5_ok=false; info "corrupt entry liveness_reason was '$corrupt_reason', expected corrupt"; }
[ "$corrupt_live" = "true" ] || { c5_ok=false; info "corrupt entry live was '$corrupt_live', expected true"; }

if [ "$c5_ok" = true ]; then
  pass "5: queue-list reports pid-alive/dead-pid/stale-heartbeat/corrupt liveness_reason correctly"
else
  fail "5: liveness-reason case failed (see INFO lines above)"
fi

# =====================================================================
# Case 6: no second liveness computation -- session_liveness is the only liveness function
# =====================================================================
c6_ok=true
liveness_def_count=$(grep -c '^session_liveness()' "$SRC_DIR/task-lock.sh" 2>/dev/null) || liveness_def_count=0
[ "$liveness_def_count" -eq 1 ] || { c6_ok=false; info "session_liveness() defined $liveness_def_count times, expected exactly 1"; }
queue_list_calls=$(grep -A40 '^cmd_queue_list()' "$SRC_DIR/task-lock.sh" | grep -c 'session_liveness "\$f"')
[ "$queue_list_calls" -ge 1 ] || { c6_ok=false; info "cmd_queue_list does not call session_liveness()"; }

if [ "$c6_ok" = true ]; then
  pass "6: queue-list consumes session_liveness() with no second liveness computation"
else
  fail "6: liveness-consumption case failed (see INFO lines above)"
fi

# =====================================================================
# Phase 2: queue-finish / queue-reap
# =====================================================================
rm -f "$QUEUE_DIR"/*.json "$ARCHIVE_DIR"/*.json 2>/dev/null

finish_orch=$("$TL" queue-register "sess_finish" "/orchestrate 701" "701" 2>&1)
finish_live_file="$QUEUE_DIR/${finish_orch}.json"
finish_archive_file="$ARCHIVE_DIR/${finish_orch}.json"

"$TL" queue-finish "sess_finish" >/dev/null 2>&1
finish_exit=$?

# =====================================================================
# Case 7: finish moves the record (never-delete-without-archive: archive file existence is
# asserted BEFORE live file absence)
# =====================================================================
c7_ok=true
[ "$finish_exit" -eq 0 ] || { c7_ok=false; info "queue-finish exit code was $finish_exit, expected 0"; }
[ -f "$finish_archive_file" ] || { c7_ok=false; info "archive file $finish_archive_file was not created"; }
[ ! -f "$finish_live_file" ] || { c7_ok=false; info "live file $finish_live_file still exists after finish"; }
if [ -f "$finish_archive_file" ]; then
  archived_state=$(jq -r '.state' "$finish_archive_file" 2>/dev/null)
  archived_finished_at=$(jq -r '.finished_at' "$finish_archive_file" 2>/dev/null)
  archived_archived_at=$(jq -r '.archived_at' "$finish_archive_file" 2>/dev/null)
  [ "$archived_state" = "archived" ] || { c7_ok=false; info "archived state was '$archived_state', expected archived"; }
  [ -n "$archived_finished_at" ] && [ "$archived_finished_at" != "null" ] || { c7_ok=false; info "archived finished_at not set"; }
  [ -n "$archived_archived_at" ] && [ "$archived_archived_at" != "null" ] || { c7_ok=false; info "archived archived_at not set"; }
fi
list_live_after_finish=$("$TL" queue-list 2>&1 | jq -c --arg oid "$finish_orch" 'select(.orchestration_id==$oid)' 2>/dev/null)
[ -z "$list_live_after_finish" ] || { c7_ok=false; info "finished entry still appears in live queue-list"; }
list_archived_after_finish=$("$TL" queue-list --archived 2>&1 | jq -c --arg oid "$finish_orch" 'select(.orchestration_id==$oid)' 2>/dev/null)
[ -n "$list_archived_after_finish" ] || { c7_ok=false; info "finished entry does not appear in queue-list --archived"; }

if [ "$c7_ok" = true ]; then
  pass "7: queue-finish archives the record (archive exists before live file is gone); live listing drops it, archived listing shows it"
else
  fail "7: finish case failed (see INFO lines above)"
fi

# =====================================================================
# Case 8: finish is idempotent on an already-archived or absent entry
# =====================================================================
finish2_exit=0
"$TL" queue-finish "sess_finish" >/dev/null 2>&1 || finish2_exit=$?
finish3_exit=0
"$TL" queue-finish "sess_never_registered" >/dev/null 2>&1 || finish3_exit=$?

c8_ok=true
[ "$finish2_exit" -eq 0 ] || { c8_ok=false; info "second queue-finish (already archived) exit code was $finish2_exit, expected 0"; }
[ "$finish3_exit" -eq 0 ] || { c8_ok=false; info "queue-finish on an absent entry exit code was $finish3_exit, expected 0"; }

if [ "$c8_ok" = true ]; then
  pass "8: queue-finish is idempotent on an already-archived or absent entry"
else
  fail "8: finish-idempotent case failed (see INFO lines above)"
fi

# =====================================================================
# Reap fixtures
# =====================================================================
rm -f "$QUEUE_DIR"/*.json "$ARCHIVE_DIR"/*.json 2>/dev/null

write_queue_fixture "$QUEUE_DIR" "orch_reap_dead" "sess_reap_dead" "$DEAD_PID" '[702]' '[]' "running" 20
write_queue_fixture "$QUEUE_DIR" "orch_reap_stale" "sess_reap_stale" "$$" '[702]' '[]' "running" 300
write_queue_fixture "$QUEUE_DIR" "orch_reap_alive" "sess_reap_alive" "$$" '[702]' '[]' "running" 2

# =====================================================================
# Case 9: queue-reap --dry-run mutates nothing
# =====================================================================
dry_out=$("$TL" queue-reap --dry-run 2>&1)
dry_exit=$?

c9_ok=true
[ "$dry_exit" -eq 0 ] || { c9_ok=false; info "queue-reap --dry-run exit code was $dry_exit, expected 0"; }
for f in orch_reap_dead orch_reap_stale orch_reap_alive; do
  [ -f "$QUEUE_DIR/${f}.json" ] || { c9_ok=false; info "dry-run removed $f"; }
done
echo "$dry_out" | grep -q "would reap" || { c9_ok=false; info "dry-run output missing 'would reap'"; }

if [ "$c9_ok" = true ]; then
  pass "9: queue-reap --dry-run reports would-reap candidates and mutates nothing"
else
  fail "9: reap-dry-run case failed (see INFO lines above)"
fi

# =====================================================================
# Case 10: live queue-reap archives dead-pid and stale-heartbeat entries, leaves pid-alive
# entry untouched
# =====================================================================
live_reap_out=$("$TL" queue-reap 2>&1)
live_reap_exit=$?

c10_ok=true
[ "$live_reap_exit" -eq 0 ] || { c10_ok=false; info "queue-reap exit code was $live_reap_exit, expected 0"; }
[ ! -f "$QUEUE_DIR/orch_reap_dead.json" ] || { c10_ok=false; info "orch_reap_dead was NOT reaped"; }
[ -f "$ARCHIVE_DIR/orch_reap_dead.json" ] || { c10_ok=false; info "orch_reap_dead has no archive counterpart"; }
[ ! -f "$QUEUE_DIR/orch_reap_stale.json" ] || { c10_ok=false; info "orch_reap_stale was NOT reaped"; }
[ -f "$ARCHIVE_DIR/orch_reap_stale.json" ] || { c10_ok=false; info "orch_reap_stale has no archive counterpart"; }
[ -f "$QUEUE_DIR/orch_reap_alive.json" ] || { c10_ok=false; info "orch_reap_alive was incorrectly reaped"; }
if [ -f "$ARCHIVE_DIR/orch_reap_dead.json" ]; then
  dead_disposition=$(jq -r '.disposition_reason' "$ARCHIVE_DIR/orch_reap_dead.json" 2>/dev/null)
  [ "$dead_disposition" = "dead-pid" ] || { c10_ok=false; info "orch_reap_dead disposition_reason was '$dead_disposition', expected dead-pid"; }
fi
if [ -f "$ARCHIVE_DIR/orch_reap_stale.json" ]; then
  stale_disposition=$(jq -r '.disposition_reason' "$ARCHIVE_DIR/orch_reap_stale.json" 2>/dev/null)
  [ "$stale_disposition" = "stale-heartbeat" ] || { c10_ok=false; info "orch_reap_stale disposition_reason was '$stale_disposition', expected stale-heartbeat"; }
fi

if [ "$c10_ok" = true ]; then
  pass "10: queue-reap archives dead-pid/stale-heartbeat entries (with disposition_reason set) and leaves pid-alive entry untouched"
else
  fail "10: live-reap case failed (see INFO lines above)"
fi

# =====================================================================
# Phase 3: queue-check refusal matrix
# =====================================================================
rm -f "$QUEUE_DIR"/*.json "$ARCHIVE_DIR"/*.json 2>/dev/null

# =====================================================================
# Case 11 (a): no live entries -> exit 0
# =====================================================================
check_a_out=$("$TL" queue-check "sess_checker" "701" 2>&1)
check_a_exit=$?

c11_ok=true
[ "$check_a_exit" -eq 0 ] || { c11_ok=false; info "(a) no-conflict queue-check exit code was $check_a_exit, expected 0 ($check_a_out)"; }

if [ "$c11_ok" = true ]; then
  pass "11a: queue-check with no live entries exits 0"
else
  fail "11a: no-conflict case failed (see INFO lines above)"
fi

# =====================================================================
# Case 11 (b): overlapping file_scope, unrelated task number -> exit 1, refusal names
# orchestration_id, overlapping path, colliding task number
# =====================================================================
write_queue_fixture "$QUEUE_DIR" "orch_conflict" "sess_other" "$$" '[702]' '["path/a.sh"]' "running" 2

check_b_out=$("$TL" queue-check "sess_checker" "701" 2>&1)
check_b_exit=$?

c11b_ok=true
[ "$check_b_exit" -eq 1 ] || { c11b_ok=false; info "(b) conflict queue-check exit code was $check_b_exit, expected 1 ($check_b_out)"; }
echo "$check_b_out" | grep -qF "orch_conflict" || { c11b_ok=false; info "(b) refusal message missing orchestration_id orch_conflict"; }
echo "$check_b_out" | grep -qF "path/a.sh" || { c11b_ok=false; info "(b) refusal message missing overlapping path path/a.sh"; }
echo "$check_b_out" | grep -qF "701" || { c11b_ok=false; info "(b) refusal message missing colliding task number 701"; }

if [ "$c11b_ok" = true ]; then
  pass "11b: queue-check refuses an overlapping-scope conflict with the orchestration_id, path, and task number named"
else
  fail "11b: conflict-refused case failed (see INFO lines above)"
fi

# =====================================================================
# Case 11 (c): same conflict with --allow-scope-collision -> exit 0 with WARN
# =====================================================================
check_c_out=$("$TL" queue-check "sess_checker" "701" --allow-scope-collision 2>&1)
check_c_exit=$?

c11c_ok=true
[ "$check_c_exit" -eq 0 ] || { c11c_ok=false; info "(c) override queue-check exit code was $check_c_exit, expected 0 ($check_c_out)"; }
echo "$check_c_out" | grep -qi "WARN" || { c11c_ok=false; info "(c) override output missing WARN"; }

if [ "$c11c_ok" = true ]; then
  pass "11c: --allow-scope-collision downgrades the refusal to a WARN and exits 0"
else
  fail "11c: override-warns case failed (see INFO lines above)"
fi

rm -f "$QUEUE_DIR"/*.json 2>/dev/null

# =====================================================================
# Case 11 (d): conflicting entry whose session is dead-pid -> exit 0 (liveness exclusion)
# =====================================================================
write_queue_fixture "$QUEUE_DIR" "orch_dead_conflict" "sess_dead_conflict" "$DEAD_PID" '[702]' '["path/a.sh"]' "running" 20

check_d_out=$("$TL" queue-check "sess_checker" "701" 2>&1)
check_d_exit=$?

c11d_ok=true
[ "$check_d_exit" -eq 0 ] || { c11d_ok=false; info "(d) dead-entry queue-check exit code was $check_d_exit, expected 0 ($check_d_out)"; }

if [ "$c11d_ok" = true ]; then
  pass "11d: a conflicting entry whose session is dead-pid is excluded (exit 0)"
else
  fail "11d: dead-entry-excluded case failed (see INFO lines above)"
fi

rm -f "$QUEUE_DIR"/*.json 2>/dev/null

# =====================================================================
# Case 11 (e): conflicting entry covers only a dependency-edge-connected task number -> exit 0
# =====================================================================
write_queue_fixture "$QUEUE_DIR" "orch_edge_conflict" "sess_edge_conflict" "$$" '[703]' '["path/a.sh"]' "running" 2

check_e_out=$("$TL" queue-check "sess_checker" "701" 2>&1)
check_e_exit=$?

c11e_ok=true
[ "$check_e_exit" -eq 0 ] || { c11e_ok=false; info "(e) edge-connected queue-check exit code was $check_e_exit, expected 0 ($check_e_out)"; }

if [ "$c11e_ok" = true ]; then
  pass "11e: a conflicting entry covering only a dependency-edge-connected task number is excluded (exit 0)"
else
  fail "11e: dependency-edge-excluded case failed (see INFO lines above)"
fi

rm -f "$QUEUE_DIR"/*.json 2>/dev/null

# =====================================================================
# Case 11 (f): an entry carrying our own session_id -> exit 0 (self-exclusion)
# =====================================================================
write_queue_fixture "$QUEUE_DIR" "orch_self" "sess_checker" "$$" '[702]' '["path/a.sh"]' "running" 2

check_f_out=$("$TL" queue-check "sess_checker" "701" 2>&1)
check_f_exit=$?

c11f_ok=true
[ "$check_f_exit" -eq 0 ] || { c11f_ok=false; info "(f) self queue-check exit code was $check_f_exit, expected 0 ($check_f_out)"; }

if [ "$c11f_ok" = true ]; then
  pass "11f: an entry carrying our own session_id is excluded (self-exclusion, exit 0)"
else
  fail "11f: self-excluded case failed (see INFO lines above)"
fi

rm -f "$QUEUE_DIR"/*.json 2>/dev/null

# =====================================================================
# Case 11 (g): an ARCHIVED entry with overlapping scope -> exit 0 (archive is never an
# admission input)
# =====================================================================
write_queue_fixture "$ARCHIVE_DIR" "orch_archived_conflict" "sess_archived_conflict" "$$" '[702]' '["path/a.sh"]' "archived" 2

check_g_out=$("$TL" queue-check "sess_checker" "701" 2>&1)
check_g_exit=$?

c11g_ok=true
[ "$check_g_exit" -eq 0 ] || { c11g_ok=false; info "(g) archived-entry queue-check exit code was $check_g_exit, expected 0 ($check_g_out)"; }

if [ "$c11g_ok" = true ]; then
  pass "11g: an archived entry with overlapping scope is never consulted as an admission input (exit 0)"
else
  fail "11g: archived-entry-excluded case failed (see INFO lines above)"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
