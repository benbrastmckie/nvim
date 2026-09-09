#!/usr/bin/env bash
# test-phase-heartbeat.sh - Isolated-temp-root suite proving the MECHANIZED task-lock and
# session-registry heartbeat inside update-phase-status.sh actually advances heartbeat_at
# across real phase transitions, against a real holder.json and a real session-registry entry.
#
# This is the deterministic, repeatable evidence acceptance criteria 1 and 2 require: a
# backdated fixture (acquired_at == heartbeat_at == started_at, all set to a FIXED past
# timestamp) makes the "heartbeat_at advances" assertion deterministic with no `sleep` and no
# wall-clock race -- see context/patterns/task-lock.md and this task's own plan for the full
# rationale.
#
# Structural model, matching test-task-lock-reap.sh's isolated-temp-root convention (same
# directory as this suite's own true sibling scripts, one level up from scripts/tests/): copies
# the REAL update-phase-status.sh, task-lock.sh, deploy-root-guard.sh, and their lib/
# dependencies into a throwaway $TMPROOT/.claude/scripts/ tree, satisfying
# deploy-root-guard.sh's "two levels under root" check with zero testability hooks added to
# production code. Runnable from either the source store (this file's own location under
# agent-system/extensions/core/scripts/tests/) or a deployed .claude/scripts/tests/ copy -- both
# resolve their sibling scripts one level up (../) from this file's own directory, so the suite
# always exercises whichever tree it was invoked from, never a fixed location of its own choosing.
#
# Exit 0 when all cases PASS, exit 1 when any case FAILS, exit 2 on environment error (a
# required sibling script is missing).

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

REQUIRED=(update-phase-status.sh task-lock.sh deploy-root-guard.sh)
for req in "${REQUIRED[@]}"; do
  if [ ! -f "$SRC_DIR/$req" ]; then
    echo "ERROR: expected $req alongside this suite's sibling scripts dir ($SRC_DIR)" >&2
    exit 2
  fi
done
for req in lib/common.sh lib/phase-heading-patterns.sh lib/file-scope-overlap.sh; do
  if [ ! -f "$SRC_DIR/$req" ]; then
    echo "ERROR: expected $req alongside this suite's sibling scripts dir ($SRC_DIR)" >&2
    exit 2
  fi
done

TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/phase-heartbeat-test.XXXXXX")"
cleanup() { [ -n "${TMPROOT:-}" ] && [ -d "$TMPROOT" ] && rm -rf "$TMPROOT"; }
trap cleanup EXIT

mkdir -p "$TMPROOT/.claude/scripts/lib"
cp "$SRC_DIR/update-phase-status.sh" "$TMPROOT/.claude/scripts/update-phase-status.sh"
cp "$SRC_DIR/task-lock.sh" "$TMPROOT/.claude/scripts/task-lock.sh"
cp "$SRC_DIR/deploy-root-guard.sh" "$TMPROOT/.claude/scripts/deploy-root-guard.sh"
cp "$SRC_DIR/lib/common.sh" "$TMPROOT/.claude/scripts/lib/common.sh"
cp "$SRC_DIR/lib/phase-heading-patterns.sh" "$TMPROOT/.claude/scripts/lib/phase-heading-patterns.sh"
cp "$SRC_DIR/lib/file-scope-overlap.sh" "$TMPROOT/.claude/scripts/lib/file-scope-overlap.sh"
cp "$SRC_DIR/lib/task-lookup-lib.sh" "$TMPROOT/.claude/scripts/lib/task-lookup-lib.sh"
chmod +x "$TMPROOT/.claude/scripts/update-phase-status.sh" "$TMPROOT/.claude/scripts/task-lock.sh"

UPS="$TMPROOT/.claude/scripts/update-phase-status.sh"
TL="$TMPROOT/.claude/scripts/task-lock.sh"
TRACE_LOG="$TMPROOT/.agent-logs/heartbeat-trace.log"

# --- Timestamp helpers (no sleeping -- controlled epoch arithmetic) ---
now_epoch() { date -u +%s; }
iso_at() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }
FIXED_PAST_ISO="$(iso_at "$(( $(now_epoch) - 3600 ))")"  # 1 hour ago, fixed

TASK_NUM=1
PROJECT_NAME="phasehbtest"
SESSION_ID="sess_phasehb_test_1"

reset_fixture() {
  rm -rf "$TMPROOT/specs"
  rm -f "$TRACE_LOG"
  mkdir -p "$TMPROOT/specs/001_${PROJECT_NAME}/plans" "$TMPROOT/specs/001_${PROJECT_NAME}/.lock" "$TMPROOT/specs/.sessions"
  cat > "$TMPROOT/specs/001_${PROJECT_NAME}/plans/01_x.md" << EOF
# Plan

### Phase 1: First [NOT STARTED]
body
### Phase 2: Second [NOT STARTED]
body
EOF
  jq -n \
    --arg sid "$SESSION_ID" \
    --argjson tn "$TASK_NUM" \
    --arg ts "$FIXED_PAST_ISO" \
    '{session_id: $sid, task_number: $tn, operation: "implement", acquired_at: $ts, heartbeat_at: $ts, command: "/implement 1", pid: 999999999, pid_source: "self"}' \
    > "$TMPROOT/specs/001_${PROJECT_NAME}/.lock/holder.json"
  jq -n \
    --arg sid "$SESSION_ID" \
    --arg ts "$FIXED_PAST_ISO" \
    '{session_id: $sid, pid: 999999999, pid_source: "self", command: "/implement 1", task_numbers: [1], file_scope: [], started_at: $ts, heartbeat_at: $ts}' \
    > "$TMPROOT/specs/.sessions/${SESSION_ID}.json"
}

holder_field() { jq -r --arg f "$2" '.[$f] // empty' "$TMPROOT/specs/001_${PROJECT_NAME}/.lock/holder.json" 2>/dev/null; }
session_field() { jq -r --arg f "$2" '.[$f] // empty' "$TMPROOT/specs/.sessions/${SESSION_ID}.json" 2>/dev/null; }

# ═══════════════════════════════════════════════════════════════════════
# Case 1+2: heartbeat_at advances past acquired_at/started_at on both records
# ═══════════════════════════════════════════════════════════════════════
info "=== Case 1+2: single call advances both heartbeat_at fields ==="
reset_fixture
stdout1=$(bash "$UPS" "$TASK_NUM" "$PROJECT_NAME" 1 IN_PROGRESS)
holder_acquired_1="$(holder_field _ acquired_at)"
holder_heartbeat_1="$(holder_field _ heartbeat_at)"
session_started_1="$(session_field _ started_at)"
session_heartbeat_1="$(session_field _ heartbeat_at)"

if [ "$holder_acquired_1" = "$FIXED_PAST_ISO" ]; then
  pass "holder.json acquired_at unchanged after one phase transition"
else
  fail "holder.json acquired_at changed: expected $FIXED_PAST_ISO, got $holder_acquired_1"
fi

if [[ "$holder_heartbeat_1" > "$holder_acquired_1" ]]; then
  pass "holder.json heartbeat_at strictly greater than acquired_at (criterion 2, task-lock half)"
else
  fail "holder.json heartbeat_at ($holder_heartbeat_1) not greater than acquired_at ($holder_acquired_1)"
fi

if [ "$session_started_1" = "$FIXED_PAST_ISO" ]; then
  pass "session entry started_at unchanged after one phase transition"
else
  fail "session entry started_at changed: expected $FIXED_PAST_ISO, got $session_started_1"
fi

if [[ "$session_heartbeat_1" > "$session_started_1" ]]; then
  pass "session entry heartbeat_at strictly greater than started_at (criterion 2, session-registry half)"
else
  fail "session entry heartbeat_at ($session_heartbeat_1) not greater than started_at ($session_started_1)"
fi

# ═══════════════════════════════════════════════════════════════════════
# Case 3: second call -- heartbeat_at advances again (or is >= due to same-second ticks),
# and remains > acquired_at. Not flaky at sub-second granularity.
# ═══════════════════════════════════════════════════════════════════════
info "=== Case 3: heartbeat_at advances across a second consecutive phase transition ==="
stdout2=$(bash "$UPS" "$TASK_NUM" "$PROJECT_NAME" 2 IN_PROGRESS)
holder_heartbeat_2="$(holder_field _ heartbeat_at)"
holder_acquired_2="$(holder_field _ acquired_at)"

if [[ "$holder_heartbeat_2" > "$holder_acquired_2" ]]; then
  pass "holder.json heartbeat_at still greater than acquired_at after second transition"
else
  fail "holder.json heartbeat_at ($holder_heartbeat_2) not greater than acquired_at ($holder_acquired_2) after second transition"
fi

if [[ "$holder_heartbeat_2" > "$holder_heartbeat_1" || "$holder_heartbeat_2" = "$holder_heartbeat_1" ]]; then
  pass "holder.json heartbeat_at monotonically non-decreasing across two transitions (criterion 1)"
else
  fail "holder.json heartbeat_at went backwards: $holder_heartbeat_1 -> $holder_heartbeat_2"
fi

# ═══════════════════════════════════════════════════════════════════════
# Case 4: stdout contract -- byte-identical to the pre-change contract (plan path alone), exit 0
# ═══════════════════════════════════════════════════════════════════════
info "=== Case 4: stdout contract ==="
expected_path="$TMPROOT/specs/001_${PROJECT_NAME}/plans/01_x.md"
if [ "$stdout1" = "$expected_path" ]; then
  pass "stdout is the plan file path alone on the first call"
else
  fail "stdout mismatch on first call: expected [$expected_path], got [$stdout1]"
fi
if [ "$stdout2" = "$expected_path" ]; then
  pass "stdout is the plan file path alone on the second call"
else
  fail "stdout mismatch on second call: expected [$expected_path], got [$stdout2]"
fi

# ═══════════════════════════════════════════════════════════════════════
# Case 5: never-blocking across every no-op class
# ═══════════════════════════════════════════════════════════════════════
info "=== Case 5: never-blocking no-op classes ==="

# 5a: .lock/ absent entirely
reset_fixture
rm -rf "$TMPROOT/specs/001_${PROJECT_NAME}/.lock"
out=$(bash "$UPS" "$TASK_NUM" "$PROJECT_NAME" 1 IN_PROGRESS); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "$expected_path" ]; then
  pass "5a: .lock/ absent -- exit 0, stdout unchanged"
else
  fail "5a: .lock/ absent -- exit=$rc stdout=[$out]"
fi
if grep -q "noop:no-holder" "$TRACE_LOG" 2>/dev/null; then
  pass "5a: noop:no-holder trace line written"
else
  fail "5a: no noop:no-holder trace line found in $TRACE_LOG"
fi

# 5b: corrupt holder.json
reset_fixture
echo "not valid json" > "$TMPROOT/specs/001_${PROJECT_NAME}/.lock/holder.json"
out=$(bash "$UPS" "$TASK_NUM" "$PROJECT_NAME" 1 IN_PROGRESS); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "$expected_path" ]; then
  pass "5b: corrupt holder.json -- exit 0, stdout unchanged"
else
  fail "5b: corrupt holder.json -- exit=$rc stdout=[$out]"
fi
if grep -q "noop:unparseable-holder" "$TRACE_LOG" 2>/dev/null; then
  pass "5b: noop:unparseable-holder trace line written"
else
  fail "5b: no noop:unparseable-holder trace line found in $TRACE_LOG"
fi

# 5c: unresolvable task directory (nonexistent task number/project name)
reset_fixture
out=$(bash "$UPS" 999 "nonexistent_project_xyz" 1 IN_PROGRESS 2>/tmp/phase_hb_5c_err.txt); rc=$?
if [ "$rc" -ne 0 ]; then
  pass "5c: unresolvable task directory -- script still exits non-zero as before (plan-dir-not-found is a pre-existing validation error, not a heartbeat regression)"
else
  fail "5c: unresolvable task directory unexpectedly exited 0"
fi
rm -f /tmp/phase_hb_5c_err.txt

# ═══════════════════════════════════════════════════════════════════════
# Case 6: mismatch trace -- explicit 5th session_id differing from holder's
# ═══════════════════════════════════════════════════════════════════════
info "=== Case 6: 5th-argument session_id mismatch ==="
reset_fixture
pre_heartbeat="$(holder_field _ heartbeat_at)"
bash "$UPS" "$TASK_NUM" "$PROJECT_NAME" 1 IN_PROGRESS "sess_wrong_session" >/dev/null
post_heartbeat="$(holder_field _ heartbeat_at)"
if [ "$pre_heartbeat" = "$post_heartbeat" ]; then
  pass "mismatched 5th-arg session_id does NOT advance heartbeat_at"
else
  fail "mismatched 5th-arg session_id advanced heartbeat_at anyway ($pre_heartbeat -> $post_heartbeat)"
fi
if grep -q "noop:session-mismatch" "$TRACE_LOG" 2>/dev/null; then
  pass "noop:session-mismatch trace line written"
else
  fail "no noop:session-mismatch trace line found in $TRACE_LOG"
fi

# ═══════════════════════════════════════════════════════════════════════
# Case 7: never_heartbeated fingerprint flips across a real phase-transition heartbeat
# ═══════════════════════════════════════════════════════════════════════
info "=== Case 7: never_heartbeated fingerprint (wired to task-lock.sh check) ==="
reset_fixture
check_out_before=$(bash "$TL" check "$TASK_NUM" 2>&1)
if [[ "$check_out_before" == *"never_heartbeated=true"* ]]; then
  pass "fresh never-heartbeated fixture lock reports never_heartbeated=true before any phase transition"
else
  fail "expected never_heartbeated=true before transition, got: $check_out_before"
fi
bash "$UPS" "$TASK_NUM" "$PROJECT_NAME" 1 IN_PROGRESS >/dev/null
check_out_after=$(bash "$TL" check "$TASK_NUM" 2>&1)
if [[ "$check_out_after" == *"never_heartbeated=false"* ]]; then
  pass "same lock reports never_heartbeated=false after the mechanized phase-transition heartbeat"
else
  fail "expected never_heartbeated=false after transition, got: $check_out_after"
fi

# ═══════════════════════════════════════════════════════════════════════
# Case 8: PHASE_HEARTBEAT_DISABLE opt-out
# ═══════════════════════════════════════════════════════════════════════
info "=== Case 8: PHASE_HEARTBEAT_DISABLE opt-out ==="
reset_fixture
pre_heartbeat="$(holder_field _ heartbeat_at)"
PHASE_HEARTBEAT_DISABLE=1 bash "$UPS" "$TASK_NUM" "$PROJECT_NAME" 1 IN_PROGRESS >/dev/null
post_heartbeat="$(holder_field _ heartbeat_at)"
if [ "$pre_heartbeat" = "$post_heartbeat" ]; then
  pass "PHASE_HEARTBEAT_DISABLE=1 leaves holder.json heartbeat_at untouched"
else
  fail "PHASE_HEARTBEAT_DISABLE=1 still advanced heartbeat_at ($pre_heartbeat -> $post_heartbeat)"
fi
if [ ! -f "$TRACE_LOG" ]; then
  pass "PHASE_HEARTBEAT_DISABLE=1 writes no trace log at all"
else
  fail "PHASE_HEARTBEAT_DISABLE=1 unexpectedly wrote a trace log: $(cat "$TRACE_LOG")"
fi

# ═══════════════════════════════════════════════════════════════════════
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
