#!/usr/bin/env bash
# test-state-write-regen-timing.sh - Isolated-temp-root suite proving that state-write.sh's
# `--regen-todo` mutex-release-before-regeneration fix actually holds, and that it does not break
# the no-lost-update or guest-mode-reentrancy contracts test-state-write-concurrency.sh already
# covers.
#
# Never touches the real specs/ tree. Follows test-state-write-concurrency.sh's conventions
# exactly: throwaway $TMPROOT, scripts copied byte-for-byte into $TMPROOT/.claude/scripts/, a
# fixture $TMPROOT/specs/state.json with two project entries, `pass`/`fail`/`info` helpers, exit 0
# on all pass and 1 on any failure.
#
# Controlled dependency, not a violation of "scripts under test are copied unmodified": the
# script under test here is state-write.sh. generate-todo.sh is merely a DEPENDENCY that
# --regen-todo shells out to, and this suite needs to control ITS cost/blocking behavior
# deterministically -- exactly as the precedent suite controls its own transform cost through a
# deliberately heavy jq `range` computation rather than a blind `sleep`. So this suite substitutes
# a small, environment-driven stub for generate-todo.sh instead of copying the real script. This
# also means generate-task-order.sh (a dependency of the REAL generate-todo.sh, and out of this
# task's file_scope) never needs to be copied into the fixture at all -- the stub never calls it.
#
# All polling in this suite is bounded, real-predicate polling (file existence / process
# liveness), never a blind sleep used to fake an ordering.
#
# Exit 0 when all three cases PASS, exit 1 when any case FAILS.

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

# --- Locate the real scripts to copy into the fixture ---
# Deliberately NOT generate-todo.sh (see the file-header rationale above) and NOT
# generate-task-order.sh (a dependency of the real generate-todo.sh only).
for f in state-write.sh task-lock.sh deploy-root-guard.sh lib/common.sh lib/task-lookup-lib.sh; do
  if [ ! -f "$SCRIPT_DIR/$f" ]; then
    echo "ERROR: expected $f alongside this script in $SCRIPT_DIR" >&2
    exit 1
  fi
done

# --- Build the isolated temp root ---
TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/state-write-regen-timing-test.XXXXXX")"

cleanup_root() {
  [ -n "${TMPROOT:-}" ] && [ -d "$TMPROOT" ] && rm -rf "$TMPROOT"
}
trap cleanup_root EXIT

mkdir -p "$TMPROOT/.claude/scripts/lib"
mkdir -p "$TMPROOT/specs"
cp "$SCRIPT_DIR/state-write.sh" "$TMPROOT/.claude/scripts/state-write.sh"
cp "$SCRIPT_DIR/task-lock.sh" "$TMPROOT/.claude/scripts/task-lock.sh"
cp "$SCRIPT_DIR/deploy-root-guard.sh" "$TMPROOT/.claude/scripts/deploy-root-guard.sh"
cp "$SCRIPT_DIR/lib/common.sh" "$TMPROOT/.claude/scripts/lib/common.sh"
cp "$SCRIPT_DIR/lib/task-lookup-lib.sh" "$TMPROOT/.claude/scripts/lib/task-lookup-lib.sh"

# --- Controlled generate-todo.sh stub ---
# Driven entirely by environment variables, never CLI flags, so it drop-in replaces the real
# script's no-argument invocation from state-write.sh:
#   REGEN_STUB_MARKER   - if set, touch this path immediately on start. Lets a foreground process
#                         detect "regeneration has begun" via a real predicate.
#   REGEN_STUB_RELEASE  - if set, poll (bounded, real predicate) for this path to appear before
#                         exiting 0. Bounded by REGEN_STUB_BUDGET_SEC (default 5s) so the stub can
#                         never hang a test run even if the foreground forgets to release it.
# With neither variable set, the stub is a no-op that exits 0 immediately.
cat > "$TMPROOT/.claude/scripts/generate-todo.sh" << 'STUB_EOF'
#!/usr/bin/env bash
set -uo pipefail

BUDGET_SEC="${REGEN_STUB_BUDGET_SEC:-5}"

if [ -n "${REGEN_STUB_MARKER:-}" ]; then
  touch "$REGEN_STUB_MARKER"
fi

if [ -n "${REGEN_STUB_RELEASE:-}" ]; then
  waited=0
  max_iters=$((BUDGET_SEC * 50))
  while [ ! -f "$REGEN_STUB_RELEASE" ]; do
    sleep 0.02
    waited=$((waited + 1))
    if [ "$waited" -ge "$max_iters" ]; then
      echo "ERROR: generate-todo.sh stub timed out waiting for release file $REGEN_STUB_RELEASE" >&2
      exit 1
    fi
  done
fi

exit 0
STUB_EOF

chmod +x "$TMPROOT/.claude/scripts/"*.sh

SW="$TMPROOT/.claude/scripts/state-write.sh"
TL="$TMPROOT/.claude/scripts/task-lock.sh"
STATE_FILE="$TMPROOT/specs/state.json"

reset_state_json() {
  cat > "$STATE_FILE" << 'EOF'
{
  "next_project_number": 3,
  "active_projects": [
    {"project_number": 1, "project_name": "case_a", "status": "implementing", "counter": 0},
    {"project_number": 2, "project_name": "case_b", "status": "implementing", "counter": 0}
  ]
}
EOF
}

reset_state_json
info "Fixture built at $TMPROOT"

# =====================================================================
# Case 1: mutex released before regeneration begins -- the regression guard. If Phase 1's
# release_mutex() call were ever moved back after the regeneration block (or removed), this case
# must FAIL: a concurrent scope-acquire attempt would then have to wait out the full
# SCOPE_MUTEX_ACQUIRE_BUDGET_MS while regeneration is still blocked, instead of succeeding
# immediately.
# =====================================================================
reset_state_json
rm -f "$TMPROOT/regen-marker" "$TMPROOT/regen-release"

(
  REGEN_STUB_MARKER="$TMPROOT/regen-marker" REGEN_STUB_RELEASE="$TMPROOT/regen-release" REGEN_STUB_BUDGET_SEC=10 \
    "$SW" '(.active_projects[] | select(.project_number == 1)) |= . + {counter: 1, marker_case1: "written"}' \
    --session-id "sess_case1_owner" --regen-todo > "$TMPROOT/case1.out" 2>&1
  echo $? > "$TMPROOT/case1.exit"
) &
PID_CASE1=$!

# Bounded poll (real predicate) for the stub's marker file -- proves regeneration has actually
# begun before we probe the mutex.
marker_seen=false
for _ in $(seq 1 500); do
  if [ -f "$TMPROOT/regen-marker" ]; then
    marker_seen=true
    break
  fi
  sleep 0.02
done

c1_ok=true
if [ "$marker_seen" != true ]; then
  c1_ok=false
  info "case1: generate-todo.sh stub's marker never appeared -- regeneration did not start"
fi

# While the stub is still blocked on its release file, the specs/.scope-lock mutex MUST already
# be free: prove it by successfully acquiring it from the foreground under a DIFFERENT session id.
acquire_token=""
if [ "$marker_seen" = true ]; then
  if acquire_token=$("$TL" scope-acquire "sess_case1_prober" 2>"$TMPROOT/case1_acquire.err"); then
    info "case1: acquired specs/.scope-lock from the foreground while the regen stub was still blocked (mutex released before regen, as required)"
  else
    c1_ok=false
    info "case1: FAILED to acquire specs/.scope-lock while the regen stub was blocked -- mutex was still held during regeneration: $(cat "$TMPROOT/case1_acquire.err" 2>/dev/null)"
  fi
fi

# Release the stub regardless of outcome so the background process can never hang the suite.
touch "$TMPROOT/regen-release"
[ -n "$acquire_token" ] && "$TL" scope-release "$acquire_token" >/dev/null 2>&1

wait "$PID_CASE1"
case1_exit=$(cat "$TMPROOT/case1.exit" 2>/dev/null || echo "?")
[ "$case1_exit" = "0" ] || { c1_ok=false; info "case1: state-write.sh --regen-todo exited $case1_exit (expected 0): $(cat "$TMPROOT/case1.out" 2>/dev/null)"; }
jq -e '.active_projects[] | select(.project_number == 1) | .marker_case1 == "written"' "$STATE_FILE" >/dev/null 2>&1 || { c1_ok=false; info "case1: expected state.json mutation missing"; }

if [ "$c1_ok" = true ]; then
  pass "1: mutex released before regeneration begins -- a concurrent scope-acquire succeeds while --regen-todo's stub is still running"
else
  fail "1: mutex-released-before-regen case failed (see INFO lines above)"
fi

# =====================================================================
# Case 2: two concurrent --regen-todo status flips both succeed with a consistent final state
# (no lost update), each mutating a DIFFERENT project entry.
# =====================================================================
reset_state_json

(
  "$SW" '(.active_projects[] | select(.project_number == 1)) |= (.counter += 1) | (.active_projects[] | select(.project_number == 1)) |= . + {marker_a: "written"}' \
    --session-id "sess_case2_a" --regen-todo > "$TMPROOT/case2_a.out" 2>&1
  echo $? > "$TMPROOT/case2_a.exit"
) &
PID_A=$!

(
  "$SW" '(.active_projects[] | select(.project_number == 2)) |= (.counter += 1) | (.active_projects[] | select(.project_number == 2)) |= . + {marker_b: "written"}' \
    --session-id "sess_case2_b" --regen-todo > "$TMPROOT/case2_b.out" 2>&1
  echo $? > "$TMPROOT/case2_b.exit"
) &
PID_B=$!

wait "$PID_A"
wait "$PID_B"

case2_a_exit=$(cat "$TMPROOT/case2_a.exit" 2>/dev/null || echo "?")
case2_b_exit=$(cat "$TMPROOT/case2_b.exit" 2>/dev/null || echo "?")

c2_ok=true
[ "$case2_a_exit" = "0" ] || { c2_ok=false; info "case2: writer A exited $case2_a_exit (expected 0): $(cat "$TMPROOT/case2_a.out" 2>/dev/null)"; }
[ "$case2_b_exit" = "0" ] || { c2_ok=false; info "case2: writer B exited $case2_b_exit (expected 0): $(cat "$TMPROOT/case2_b.out" 2>/dev/null)"; }
jq -e '.active_projects[] | select(.project_number == 1) | (.marker_a == "written" and .counter == 1)' "$STATE_FILE" >/dev/null 2>&1 || { c2_ok=false; info "case2: writer A's mutation missing or counter wrong"; }
jq -e '.active_projects[] | select(.project_number == 2) | (.marker_b == "written" and .counter == 1)' "$STATE_FILE" >/dev/null 2>&1 || { c2_ok=false; info "case2: writer B's mutation missing or counter wrong"; }
jq empty "$STATE_FILE" >/dev/null 2>&1 || { c2_ok=false; info "case2: final state.json failed jq empty validation"; }

if [ "$c2_ok" = true ]; then
  pass "2: two concurrent --regen-todo status flips both succeed with a consistent final state (no lost update)"
else
  fail "2: concurrent-status-flips case failed (see INFO lines above)"
fi

# =====================================================================
# Case 3: guest mode still serializes regeneration -- an inner state-write.sh --regen-todo call,
# run with SCOPE_MUTEX_HELD=1 inherited from a simulated outer holder, must NOT release the outer
# holder's specs/.scope-lock mutex (release_mutex() must be a no-op there, per MUTEX_OWNED_HERE).
# =====================================================================
reset_state_json
mkdir -p "$TMPROOT/specs/.scope-lock"
date -u +%s > "$TMPROOT/specs/.scope-lock/claimed_at"
echo 60 > "$TMPROOT/specs/.scope-lock/stale_sec"
jq -n --arg sid "sess_outer_holder" '{session_id: $sid, pid: 999999, claimed_epoch: 0, token: "sess_outer_holder:999999:0"}' \
  > "$TMPROOT/specs/.scope-lock/owner"
outer_owner_before=$(cat "$TMPROOT/specs/.scope-lock/owner")

SCOPE_MUTEX_HELD=1 "$SW" '(.active_projects[] | select(.project_number == 1)) |= . + {marker_case3: "written"}' \
  --session-id "sess_case3_guest" --regen-todo > "$TMPROOT/case3.out" 2>&1
case3_exit=$?
outer_owner_after=$(cat "$TMPROOT/specs/.scope-lock/owner" 2>/dev/null || echo "MISSING")

c3_ok=true
[ "$case3_exit" = "0" ] || { c3_ok=false; info "case3: guest-mode --regen-todo write exited $case3_exit (expected 0): $(cat "$TMPROOT/case3.out" 2>/dev/null)"; }
jq -e '.active_projects[] | select(.project_number == 1) | .marker_case3 == "written"' "$STATE_FILE" >/dev/null 2>&1 || { c3_ok=false; info "case3: guest-mode write did not land"; }
[ -d "$TMPROOT/specs/.scope-lock" ] || { c3_ok=false; info "case3: outer holder's specs/.scope-lock mutex was removed by the inner --regen-todo call"; }
[ "$outer_owner_before" = "$outer_owner_after" ] || { c3_ok=false; info "case3: outer holder's owner file was modified by the inner call"; }

if [ "$c3_ok" = true ]; then
  pass "3: guest mode still serializes regeneration -- an inner --regen-todo call never releases the outer holder's mutex"
else
  fail "3: guest-mode-regen case failed (see INFO lines above)"
fi

rm -rf "$TMPROOT/specs/.scope-lock"

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
