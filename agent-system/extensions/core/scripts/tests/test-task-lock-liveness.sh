#!/usr/bin/env bash
# test-task-lock-liveness.sh - Isolated-temp-root suite proving task-lock.sh's additive
# `held-live` third check-state (Piece 2a: stale-heartbeat-but-pid-alive, consuming the shared
# session_liveness() verdict, keyed on session_id never pid) and cmd_acquire's cross-task
# overlap-pass liveness escalation (Piece 2b: ABORT on a demonstrably-live foreign holder
# instead of WARN-and-proceed).
#
# Never touches the real specs/ tree. Builds a throwaway root satisfying
# deploy-root-guard.sh's ".claude/scripts/ or .opencode/scripts/, two levels under root" check
# by copying the real task-lock.sh and its sibling deps into $TMPROOT/.claude/scripts/,
# alongside fixture state.json, .lock/holder.json, and specs/.sessions/ entries at controlled
# ages (no sleeping). Modeled directly on test-task-lock-reap.sh / test-session-registry.sh's
# precedent (temp-root construction, pass/fail/info helpers, cleanup trap, controlled-epoch
# timestamp helpers, write_holder_fixture/write_session_fixture shapes).
#
# PID-ALIVE FIXTURES use THIS TEST PROCESS'S OWN pid ($$), guaranteed alive for the suite's own
# duration -- no other live pid is available in an isolated fixture. DEAD-PID fixtures use the
# same "probe downward from a large candidate until kill -0 fails" technique
# test-session-registry.sh already established.
#
# ACCEPTANCE EVIDENCE (captured manually at implementation time, not re-derived by this suite on
# every run): running the identical stale-but-pid-alive fixture against the PRISTINE (pre-Phase-4)
# task-lock.sh via `git show HEAD:...task-lock.sh` reports `held-stale ... exit 2` (no held-live
# state exists yet); the same fixture against the modified script reports
# `held-live ... liveness_reason=pid-alive ... exit 1`. See
# specs/272_honest_session_liveness_concurrent_batches/summaries/ for the captured transcript.
#
# See context/patterns/task-lock.md's "`held-live`: stale-heartbeat-but-pid-alive" and
# "Cross-Task `file_scope` Overlap Check" sections for the full contract this suite verifies.
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
    || [ ! -f "$SRC_DIR/lib/common.sh" ] || [ ! -f "$SRC_DIR/lib/task-lookup-lib.sh" ]; then
  echo "ERROR: expected task-lock.sh, deploy-root-guard.sh, lib/common.sh, and lib/task-lookup-lib.sh alongside this suite's sibling scripts dir ($SRC_DIR)" >&2
  exit 1
fi

TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/task-lock-liveness-test.XXXXXX")"
cleanup() { [ -n "${TMPROOT:-}" ] && [ -d "$TMPROOT" ] && rm -rf "$TMPROOT"; }
trap cleanup EXIT

mkdir -p "$TMPROOT/.claude/scripts/lib"
mkdir -p "$TMPROOT/specs/.sessions"
cp "$SRC_DIR/task-lock.sh" "$TMPROOT/.claude/scripts/task-lock.sh"
cp "$SRC_DIR/deploy-root-guard.sh" "$TMPROOT/.claude/scripts/deploy-root-guard.sh"
cp "$SRC_DIR/lib/common.sh" "$TMPROOT/.claude/scripts/lib/common.sh"
cp "$SRC_DIR/lib/task-lookup-lib.sh" "$TMPROOT/.claude/scripts/lib/task-lookup-lib.sh"
chmod +x "$TMPROOT/.claude/scripts/task-lock.sh"

TL="$TMPROOT/.claude/scripts/task-lock.sh"

# --- Timestamp helpers (no sleeping -- controlled epoch arithmetic) ---
now_epoch() { date -u +%s; }
iso_at() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }
minutes_ago_iso() { iso_at "$(( $(now_epoch) - ($1 * 60) ))"; }

write_holder_fixture() {
  # write_holder_fixture <lock_dir> <task_number> <session_id> <heartbeat_minutes_ago>
  local lock_dir="$1" task_number="$2" session_id="$3" mins_ago="$4"
  local ts
  ts=$(minutes_ago_iso "$mins_ago")
  mkdir -p "$lock_dir"
  jq -n \
    --arg session_id "$session_id" \
    --argjson task_number "$task_number" \
    --arg operation "implement" \
    --arg ts "$ts" \
    --arg command "/implement $task_number" \
    '{session_id: $session_id, task_number: $task_number, operation: $operation, acquired_at: $ts, heartbeat_at: $ts, command: $command}' \
    > "$lock_dir/holder.json"
}

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

SESSIONS_DIR="$TMPROOT/specs/.sessions"
OWN_PID="$$"

# Find a definitely-dead pid for dead-pid fixtures (same technique as test-session-registry.sh).
DEAD_PID=999999
while kill -0 "$DEAD_PID" 2>/dev/null; do
  DEAD_PID=$(( DEAD_PID - 1 ))
done

# --- Fixture state.json: four tasks, one per cmd_check case below ---
cat > "$TMPROOT/specs/state.json" << EOF
{
  "next_project_number": 900,
  "active_projects": [
    {"project_number": 701, "project_name": "pid_alive_case", "status": "implementing", "task_type": "general"},
    {"project_number": 702, "project_name": "no_entry_case", "status": "implementing", "task_type": "general"},
    {"project_number": 703, "project_name": "corrupt_entry_case", "status": "implementing", "task_type": "general"},
    {"project_number": 704, "project_name": "dead_pid_case", "status": "implementing", "task_type": "general"}
  ]
}
EOF

info "Fixture built at $TMPROOT (own pid=$OWN_PID, dead pid probe resolved to $DEAD_PID)"

# ═══════════════════════════════════════════════════════════════════════
# Case 1: stale heartbeat (33 min, > TASK_LOCK_STALE_MIN=30) + registered session with a LIVE
# pid + fresh-enough registry heartbeat (33 min, < SESSION_REGISTRY_REAP_MIN=240) --
# session_liveness() must report pid-alive, and cmd_check must report held-live, exit 1.
# ═══════════════════════════════════════════════════════════════════════
info "=== Case 1: stale-but-pid-alive -> held-live, exit 1 ==="
LOCK_DIR_1="$TMPROOT/specs/701_pid_alive_case/.lock"
write_holder_fixture "$LOCK_DIR_1" 701 "sess_case1" 33
write_session_fixture "$SESSIONS_DIR" "sess_case1" "$OWN_PID" "[701]" "[]" 33

out1=$("$TL" check 701 2>&1); rc1=$?

if [ "$rc1" -eq 1 ]; then
  pass "(1a) exit code 1 (same code held-fresh already uses: 'a live session may be working')"
else
  fail "(1a) exit code was $rc1, expected 1"
fi
if [[ "$out1" == held-live* ]]; then
  pass "(1b) output line uses the held-live prefix"
else
  fail "(1b) output did not start with held-live: $out1"
fi
if [[ "$out1" == *"liveness_reason=pid-alive"* ]]; then
  pass "(1c) output carries liveness_reason=pid-alive"
else
  fail "(1c) output missing liveness_reason=pid-alive: $out1"
fi
if [[ "$out1" == *"heartbeat_age_min=33"* && "$out1" == *"threshold_min=30"* ]]; then
  pass "(1d) output preserves heartbeat_age_min/threshold_min fields, matching the pre-existing shape"
else
  fail "(1d) output missing expected age/threshold fields: $out1"
fi

# ═══════════════════════════════════════════════════════════════════════
# Case 2: stale heartbeat, but NO session-registry entry at all for the holder's session --
# must fall back to the pre-existing held-stale line, byte-for-byte, exit 2.
# ═══════════════════════════════════════════════════════════════════════
info "=== Case 2: missing registry entry -> held-stale (unchanged), exit 2 ==="
LOCK_DIR_2="$TMPROOT/specs/702_no_entry_case/.lock"
write_holder_fixture "$LOCK_DIR_2" 702 "sess_case2_no_entry" 33
# Deliberately: no specs/.sessions/sess_case2_no_entry.json written.

out2=$("$TL" check 702 2>&1); rc2=$?
if [ "$rc2" -eq 2 ] && [[ "$out2" == held-stale* ]] && [[ "$out2" != *"liveness_reason"* ]]; then
  pass "(2) missing registry entry falls back to held-stale/exit 2, no liveness_reason field"
else
  fail "(2) expected held-stale/exit 2 with no liveness_reason, got exit=$rc2 out=[$out2]"
fi

# ═══════════════════════════════════════════════════════════════════════
# Case 3: stale heartbeat + a CORRUPT registry entry (unparseable JSON) -- session_liveness()
# reports "corrupt" first, short-circuiting every other check -- must fall back to held-stale.
# ═══════════════════════════════════════════════════════════════════════
info "=== Case 3: corrupt registry entry -> held-stale (unchanged), exit 2 ==="
LOCK_DIR_3="$TMPROOT/specs/703_corrupt_entry_case/.lock"
write_holder_fixture "$LOCK_DIR_3" 703 "sess_case3_corrupt" 33
echo "not valid json" > "$SESSIONS_DIR/sess_case3_corrupt.json"

out3=$("$TL" check 703 2>&1); rc3=$?
if [ "$rc3" -eq 2 ] && [[ "$out3" == held-stale* ]] && [[ "$out3" != *"liveness_reason"* ]]; then
  pass "(3) corrupt registry entry falls back to held-stale/exit 2, no liveness_reason field"
else
  fail "(3) expected held-stale/exit 2 with no liveness_reason, got exit=$rc3 out=[$out3]"
fi

# ═══════════════════════════════════════════════════════════════════════
# Case 4: stale heartbeat + registered session with a DEAD pid, old enough to exceed
# SESSION_REGISTRY_DEAD_PID_MIN (10 min default) -- session_liveness() reports dead-pid, which
# is NOT pid-alive -- must fall back to held-stale.
# ═══════════════════════════════════════════════════════════════════════
info "=== Case 4: dead-pid registry entry -> held-stale (unchanged), exit 2 ==="
LOCK_DIR_4="$TMPROOT/specs/704_dead_pid_case/.lock"
write_holder_fixture "$LOCK_DIR_4" 704 "sess_case4_deadpid" 33
write_session_fixture "$SESSIONS_DIR" "sess_case4_deadpid" "$DEAD_PID" "[704]" "[]" 33

out4=$("$TL" check 704 2>&1); rc4=$?
if [ "$rc4" -eq 2 ] && [[ "$out4" == held-stale* ]] && [[ "$out4" != *"liveness_reason"* ]]; then
  pass "(4) dead-pid registry entry falls back to held-stale/exit 2, no liveness_reason field"
else
  fail "(4) expected held-stale/exit 2 with no liveness_reason, got exit=$rc4 out=[$out4]"
fi

# ═══════════════════════════════════════════════════════════════════════
# Case 5: never_heartbeated fingerprint still works unchanged on a fresh (non-stale) lock --
# proves the additive held-live branch did not disturb the pre-existing held-fresh path at all.
# ═══════════════════════════════════════════════════════════════════════
info "=== Case 5: held-fresh path completely unaffected by the held-live addition ==="
LOCK_DIR_5="$TMPROOT/specs/705_fresh_unaffected/.lock"
mkdir -p "$TMPROOT/specs/705_fresh_unaffected"
write_holder_fixture "$LOCK_DIR_5" 705 "sess_case5_fresh" 0
out5=$("$TL" check 705 2>&1); rc5=$?
if [ "$rc5" -eq 1 ] && [[ "$out5" == held-fresh* ]]; then
  pass "(5) a fresh lock still reports held-fresh/exit 1, unchanged"
else
  fail "(5) expected held-fresh/exit 1, got exit=$rc5 out=[$out5]"
fi

# ═══════════════════════════════════════════════════════════════════════
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
