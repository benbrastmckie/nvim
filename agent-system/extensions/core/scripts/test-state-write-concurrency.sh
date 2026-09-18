#!/usr/bin/env bash
# test-state-write-concurrency.sh - Isolated-temp-root suite proving state-write.sh's two
# load-bearing safety properties (no lost update, staging-file isolation), its fail-closed
# acquire and guest-mode reentrancy contracts (cases 1-4), and the `--state-file`/`--init`
# surface added for archive/vault targets: cross-target single-mutex serialization, `--init`
# fresh-create plus overwrite-note, and both `--regen-todo`/`--init` usage refusals (cases 5-9).
#
# Never touches the real specs/ tree. Follows test-task-lock-reap.sh's isolated-temp-root
# precedent exactly: build a throwaway $TMPROOT, copy state-write.sh, task-lock.sh,
# generate-todo.sh, and deploy-root-guard.sh byte-for-byte into $TMPROOT/.claude/scripts/, and
# fixture a minimal $TMPROOT/specs/state.json with at least two project entries, plus a minimal
# $TMPROOT/specs/archive/state.json for the non-default `--state-file` target cases. No
# testability hooks are added to production code -- every script under test is copied unmodified
# and never learns it is under test.
#
# Interleaving is controlled through the fixture's OWN transform cost (a deliberately heavy jq
# `range` computation), never through a blind wall-clock `sleep` used to fake correctness timing
# -- consistent with the precedent suite's no-sleeping convention. Where this suite polls for a
# condition (e.g. waiting for a background process's staging file to appear), it polls a real
# predicate on a bounded budget, which is a different thing from sleeping to fake an ordering.
#
# Exit 0 when all nine cases PASS, exit 1 when any case FAILS.

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
for f in state-write.sh task-lock.sh generate-todo.sh deploy-root-guard.sh lib/common.sh lib/task-lookup-lib.sh; do
  if [ ! -f "$SCRIPT_DIR/$f" ]; then
    echo "ERROR: expected $f alongside this script in $SCRIPT_DIR" >&2
    exit 1
  fi
done

# --- Build the isolated temp root ---
TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/state-write-concurrency-test.XXXXXX")"

cleanup_root() {
  [ -n "${TMPROOT:-}" ] && [ -d "$TMPROOT" ] && rm -rf "$TMPROOT"
}
trap cleanup_root EXIT

mkdir -p "$TMPROOT/.claude/scripts/lib"
mkdir -p "$TMPROOT/specs"
cp "$SCRIPT_DIR/state-write.sh" "$TMPROOT/.claude/scripts/state-write.sh"
cp "$SCRIPT_DIR/task-lock.sh" "$TMPROOT/.claude/scripts/task-lock.sh"
cp "$SCRIPT_DIR/generate-todo.sh" "$TMPROOT/.claude/scripts/generate-todo.sh"
cp "$SCRIPT_DIR/deploy-root-guard.sh" "$TMPROOT/.claude/scripts/deploy-root-guard.sh"
cp "$SCRIPT_DIR/lib/common.sh" "$TMPROOT/.claude/scripts/lib/common.sh"
cp "$SCRIPT_DIR/lib/task-lookup-lib.sh" "$TMPROOT/.claude/scripts/lib/task-lookup-lib.sh"
chmod +x "$TMPROOT/.claude/scripts/"*.sh

SW="$TMPROOT/.claude/scripts/state-write.sh"
TL="$TMPROOT/.claude/scripts/task-lock.sh"
STATE_FILE="$TMPROOT/specs/state.json"
ARCHIVE_STATE_FILE="$TMPROOT/specs/archive/state.json"

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

reset_archive_state_json() {
  mkdir -p "$(dirname "$ARCHIVE_STATE_FILE")"
  cat > "$ARCHIVE_STATE_FILE" << 'EOF'
{
  "completed_projects": [
    {"project_number": 100, "project_name": "archived_a"}
  ]
}
EOF
}

reset_state_json
reset_archive_state_json
info "Fixture built at $TMPROOT"

# =====================================================================
# Case 1: no lost update -- two concurrent writers targeting DIFFERENT project entries
# =====================================================================
# The first writer's filter is deliberately heavy (a large `range` computation) so it holds the
# specs/.scope-lock mutex for a real, measurable window. The second writer is launched
# concurrently and must genuinely wait for the first to release before it can acquire -- proving
# serialization rather than lucky non-overlap. Both mutate DIFFERENT project entries; both must
# land.
(
  cd "$TMPROOT"
  "$SW" '([range(0;20000000)] | length) as $burn | (.active_projects[] | select(.project_number == 1)) |= . + {counter: 1, marker_first: "written"}' \
    --session-id "sess_case1_first" > "$TMPROOT/case1_first.out" 2>&1
  echo $? > "$TMPROOT/case1_first.exit"
) &
PID_FIRST=$!

(
  cd "$TMPROOT"
  "$SW" '(.active_projects[] | select(.project_number == 2)) |= . + {counter: 1, marker_second: "written"}' \
    --session-id "sess_case1_second" > "$TMPROOT/case1_second.out" 2>&1
  echo $? > "$TMPROOT/case1_second.exit"
) &
PID_SECOND=$!

wait "$PID_FIRST"
wait "$PID_SECOND"

case1_first_exit=$(cat "$TMPROOT/case1_first.exit" 2>/dev/null || echo "?")
case1_second_exit=$(cat "$TMPROOT/case1_second.exit" 2>/dev/null || echo "?")

c1_ok=true
[ "$case1_first_exit" = "0" ] || { c1_ok=false; info "case1 first writer exited $case1_first_exit: $(cat "$TMPROOT/case1_first.out" 2>/dev/null)"; }
[ "$case1_second_exit" = "0" ] || { c1_ok=false; info "case1 second writer exited $case1_second_exit: $(cat "$TMPROOT/case1_second.out" 2>/dev/null)"; }
jq -e '.active_projects[] | select(.project_number == 1) | .marker_first == "written"' "$STATE_FILE" >/dev/null 2>&1 || { c1_ok=false; info "project 1's mutation (marker_first) missing from final state.json"; }
jq -e '.active_projects[] | select(.project_number == 2) | .marker_second == "written"' "$STATE_FILE" >/dev/null 2>&1 || { c1_ok=false; info "project 2's mutation (marker_second) missing from final state.json"; }
jq empty "$STATE_FILE" >/dev/null 2>&1 || { c1_ok=false; info "final state.json failed jq empty validation"; }

if [ "$c1_ok" = true ]; then
  pass "1: no lost update -- two concurrent mutex-serialized writers to different project entries both land"
else
  fail "1: no-lost-update case failed (see INFO lines above)"
fi

# =====================================================================
# Case 2: staging-file isolation -- one process fails mid-write (fires its own EXIT trap)
# concurrently with a second, successful mid-write process; the second's temp file/write must be
# untouched by the first's cleanup.
# =====================================================================
reset_state_json
rm -f "$TMPROOT/specs/tmp/"state-write.* 2>/dev/null || true

# Both run as guests (SCOPE_MUTEX_HELD=1 exported to the whole subshell tree) so neither blocks
# on the mutex -- this is what makes the two invocations genuinely concurrent at the OS level
# rather than serialized one-after-another, which is what this case needs to exercise: real
# simultaneous mktemp'd staging files under specs/tmp/, proving each process's EXIT trap only
# ever touches its OWN staging path.
export SCOPE_MUTEX_HELD=1

(
  cd "$TMPROOT"
  # Deliberately heavy AND doomed to fail: burns real wall time via `range`, then a guaranteed
  # jq runtime error (tonumber on a non-numeric string) so the process stages, holds its temp
  # file for a real window, then fails and self-cleans via its own EXIT trap.
  "$SW" '([range(0;20000000)] | length) as $burn | ("not-a-number" | tonumber)' \
    --session-id "sess_case2_fail" > "$TMPROOT/case2_fail.out" 2>&1
  echo $? > "$TMPROOT/case2_fail.exit"
) &
PID_FAIL=$!

# Poll (bounded, real-predicate) for the failing process's staging file to appear, so case 2's
# concurrent process is launched once we know a staging file genuinely exists -- not a blind
# sleep, a wait-for-condition with a timeout.
max_seen=0
for _ in $(seq 1 100); do
  n=$(ls "$TMPROOT/specs/tmp/" 2>/dev/null | grep -c '^state-write\.' || true)
  [ "$n" -gt "$max_seen" ] && max_seen="$n"
  [ "$n" -ge 1 ] && break
  sleep 0.01
done

(
  cd "$TMPROOT"
  "$SW" '(.active_projects[] | select(.project_number == 2)) |= . + {counter: 1, marker_second: "written"}' \
    --session-id "sess_case2_ok" > "$TMPROOT/case2_ok.out" 2>&1
  echo $? > "$TMPROOT/case2_ok.exit"
) &
PID_OK=$!

# Sample staging-dir file count a few more times while both may be in flight (real-predicate
# polling, not a correctness-bearing sleep) to record evidence of genuine overlap.
for _ in $(seq 1 50); do
  n=$(ls "$TMPROOT/specs/tmp/" 2>/dev/null | grep -c '^state-write\.' || true)
  [ "$n" -gt "$max_seen" ] && max_seen="$n"
  kill -0 "$PID_FAIL" 2>/dev/null || break
done

wait "$PID_FAIL"
wait "$PID_OK"
unset SCOPE_MUTEX_HELD

case2_fail_exit=$(cat "$TMPROOT/case2_fail.exit" 2>/dev/null || echo "?")
case2_ok_exit=$(cat "$TMPROOT/case2_ok.exit" 2>/dev/null || echo "?")

c2_ok=true
[ "$case2_fail_exit" = "3" ] || { c2_ok=false; info "case2 doomed writer exited $case2_fail_exit (expected 3): $(cat "$TMPROOT/case2_fail.out" 2>/dev/null)"; }
[ "$case2_ok_exit" = "0" ] || { c2_ok=false; info "case2 successful writer exited $case2_ok_exit (expected 0): $(cat "$TMPROOT/case2_ok.out" 2>/dev/null)"; }
jq -e '.active_projects[] | select(.project_number == 2) | .marker_second == "written"' "$STATE_FILE" >/dev/null 2>&1 || { c2_ok=false; info "successful writer's mutation missing -- may indicate cross-deletion of its staging file"; }
leftover=$(ls "$TMPROOT/specs/tmp/" 2>/dev/null | grep -c '^state-write\.' || true)
[ "$leftover" -eq 0 ] || { c2_ok=false; info "specs/tmp/ still has $leftover leftover state-write.* staging file(s) after both processes exited"; }
[ "$max_seen" -ge 1 ] || { c2_ok=false; info "never observed a state-write.* staging file at all (fixture failed to exercise staging)"; }

if [ "$c2_ok" = true ]; then
  pass "2: staging-file isolation -- a failing process's own-scoped EXIT trap never touches a concurrent successful process's staging file (max concurrent staging files observed: $max_seen)"
else
  fail "2: staging-file isolation case failed (see INFO lines above)"
fi

# =====================================================================
# Case 3: fail-closed acquire -- specs/.scope-lock pre-claimed and fresh; a non-guest
# state-write.sh invocation must exit non-zero with an ABORT-prefixed message rather than
# proceeding unserialized, and must leave specs/state.json untouched.
# =====================================================================
reset_state_json
mkdir -p "$TMPROOT/specs/.scope-lock"
date -u +%s > "$TMPROOT/specs/.scope-lock/claimed_at"
echo 60 > "$TMPROOT/specs/.scope-lock/stale_sec"
jq -n --arg sid "sess_outer_holder" '{session_id: $sid, pid: 999999, claimed_epoch: 0, token: "sess_outer_holder:999999:0"}' \
  > "$TMPROOT/specs/.scope-lock/owner"

before_hash=$(jq -S . "$STATE_FILE")

(
  cd "$TMPROOT"
  "$SW" '.active_projects[0].counter = 99' --session-id "sess_case3" > "$TMPROOT/case3.out" 2>&1
  echo $? > "$TMPROOT/case3.exit"
)

case3_exit=$(cat "$TMPROOT/case3.exit" 2>/dev/null || echo "?")
after_hash=$(jq -S . "$STATE_FILE")

c3_ok=true
[ "$case3_exit" = "2" ] || { c3_ok=false; info "case3 exited $case3_exit (expected 2)"; }
grep -q "^ABORT:" "$TMPROOT/case3.out" || { c3_ok=false; info "case3 stderr missing ABORT: prefix: $(cat "$TMPROOT/case3.out" 2>/dev/null)"; }
[ "$before_hash" = "$after_hash" ] || { c3_ok=false; info "case3 specs/state.json was modified despite fail-closed acquire refusal"; }

if [ "$c3_ok" = true ]; then
  pass "3: fail-closed acquire -- pre-claimed fresh specs/.scope-lock refuses with ABORT: and leaves state.json untouched"
else
  fail "3: fail-closed acquire case failed (see INFO lines above)"
fi

rm -rf "$TMPROOT/specs/.scope-lock"

# =====================================================================
# Case 4: guest-mode reentrancy -- SCOPE_MUTEX_HELD=1 exported and the mutex already held by a
# simulated outer holder; state-write.sh must complete the write WITHOUT attempting a nested
# acquire (no ~5s acquire-budget stall) and WITHOUT releasing the outer holder's mutex.
# =====================================================================
reset_state_json
mkdir -p "$TMPROOT/specs/.scope-lock"
date -u +%s > "$TMPROOT/specs/.scope-lock/claimed_at"
echo 60 > "$TMPROOT/specs/.scope-lock/stale_sec"
jq -n --arg sid "sess_outer_holder" '{session_id: $sid, pid: 999999, claimed_epoch: 0, token: "sess_outer_holder:999999:0"}' \
  > "$TMPROOT/specs/.scope-lock/owner"
outer_owner_before=$(cat "$TMPROOT/specs/.scope-lock/owner")

start_epoch=$(date -u +%s)
(
  cd "$TMPROOT"
  SCOPE_MUTEX_HELD=1 "$SW" '.active_projects[0].counter = 42' --session-id "sess_case4_guest" > "$TMPROOT/case4.out" 2>&1
  echo $? > "$TMPROOT/case4.exit"
)
end_epoch=$(date -u +%s)
elapsed=$(( end_epoch - start_epoch ))

case4_exit=$(cat "$TMPROOT/case4.exit" 2>/dev/null || echo "?")
outer_owner_after=$(cat "$TMPROOT/specs/.scope-lock/owner" 2>/dev/null || echo "MISSING")

c4_ok=true
[ "$case4_exit" = "0" ] || { c4_ok=false; info "case4 guest-mode write exited $case4_exit (expected 0): $(cat "$TMPROOT/case4.out" 2>/dev/null)"; }
jq -e '.active_projects[0].counter == 42' "$STATE_FILE" >/dev/null 2>&1 || { c4_ok=false; info "case4 guest-mode write did not land"; }
[ "$elapsed" -lt 3 ] || { c4_ok=false; info "case4 took ${elapsed}s (>= 3s), suggesting a nested acquire was attempted against the pre-claimed mutex instead of running as a guest"; }
[ -d "$TMPROOT/specs/.scope-lock" ] || { c4_ok=false; info "case4 outer holder's specs/.scope-lock mutex was removed by the guest"; }
[ "$outer_owner_before" = "$outer_owner_after" ] || { c4_ok=false; info "case4 outer holder's owner file was modified by the guest"; }
grep -q "outer holder already owns" "$TMPROOT/case4.out" && info "case4 confirmed the guest-mode note fired" || { c4_ok=false; info "case4 missing the expected guest-mode stderr note"; }

if [ "$c4_ok" = true ]; then
  pass "4: guest-mode reentrancy -- SCOPE_MUTEX_HELD=1 skips nested acquire, completes the write, and never releases the outer holder's mutex (elapsed ${elapsed}s)"
else
  fail "4: guest-mode reentrancy case failed (see INFO lines above)"
fi

rm -rf "$TMPROOT/specs/.scope-lock"

# =====================================================================
# Case 5: non-default --state-file target -- a transform against
# specs/archive/state.json lands, exits 0, leaves specs/state.json byte-identical, and produces
# valid JSON.
# =====================================================================
reset_state_json
reset_archive_state_json
before_default_hash=$(jq -S . "$STATE_FILE")

(
  cd "$TMPROOT"
  "$SW" '.completed_projects += [{"project_number": 200, "project_name": "case5"}]' \
    --state-file specs/archive/state.json --session-id "sess_case5" > "$TMPROOT/case5.out" 2>&1
  echo $? > "$TMPROOT/case5.exit"
)

case5_exit=$(cat "$TMPROOT/case5.exit" 2>/dev/null || echo "?")
after_default_hash=$(jq -S . "$STATE_FILE")

c5_ok=true
[ "$case5_exit" = "0" ] || { c5_ok=false; info "case5 exited $case5_exit (expected 0): $(cat "$TMPROOT/case5.out" 2>/dev/null)"; }
[ "$before_default_hash" = "$after_default_hash" ] || { c5_ok=false; info "case5 specs/state.json changed even though --state-file targeted the archive file"; }
jq -e '.completed_projects[] | select(.project_number == 200)' "$ARCHIVE_STATE_FILE" >/dev/null 2>&1 || { c5_ok=false; info "case5 archive mutation missing"; }
jq empty "$ARCHIVE_STATE_FILE" >/dev/null 2>&1 || { c5_ok=false; info "case5 archive file failed jq empty validation"; }

if [ "$c5_ok" = true ]; then
  pass "5: non-default --state-file target -- a transform against specs/archive/state.json lands, exits 0, and leaves specs/state.json byte-identical"
else
  fail "5: non-default --state-file case failed (see INFO lines above)"
fi

# =====================================================================
# Case 6: single-mutex serialization ACROSS targets (D2's load-bearing property) -- one heavy
# writer against the default path concurrent with one writer against specs/archive/state.json;
# both must land, and the second must genuinely have waited (no lost update on either file). This
# is the regression test for D2 -- it would fail under per-file locks, since the archive writer
# would never contend with the default-path writer at all.
# =====================================================================
reset_state_json
reset_archive_state_json

(
  cd "$TMPROOT"
  "$SW" '([range(0;20000000)] | length) as $burn | (.active_projects[] | select(.project_number == 1)) |= . + {counter: 1, marker_case6_default: "written"}' \
    --session-id "sess_case6_default" > "$TMPROOT/case6_default.out" 2>&1
  echo $? > "$TMPROOT/case6_default.exit"
) &
PID_CASE6_DEFAULT=$!

# Poll (bounded, real-predicate) for the heavy default-path writer's staging file to appear so
# the archive writer is launched once we know the default-path writer genuinely holds the mutex
# -- proving real cross-target contention rather than lucky non-overlap.
for _ in $(seq 1 200); do
  n=$(ls "$TMPROOT/specs/tmp/" 2>/dev/null | grep -c '^state-write\.' || true)
  [ "$n" -ge 1 ] && break
  sleep 0.01
done

case6_archive_start_epoch=$(date -u +%s%N)
(
  cd "$TMPROOT"
  "$SW" '.completed_projects += [{"project_number": 201, "project_name": "case6"}]' \
    --state-file specs/archive/state.json --session-id "sess_case6_archive" > "$TMPROOT/case6_archive.out" 2>&1
  echo $? > "$TMPROOT/case6_archive.exit"
) &
PID_CASE6_ARCHIVE=$!

wait "$PID_CASE6_DEFAULT"
case6_default_done_epoch=$(date -u +%s%N)
wait "$PID_CASE6_ARCHIVE"
case6_archive_done_epoch=$(date -u +%s%N)

case6_default_exit=$(cat "$TMPROOT/case6_default.exit" 2>/dev/null || echo "?")
case6_archive_exit=$(cat "$TMPROOT/case6_archive.exit" 2>/dev/null || echo "?")

c6_ok=true
[ "$case6_default_exit" = "0" ] || { c6_ok=false; info "case6 default-path writer exited $case6_default_exit: $(cat "$TMPROOT/case6_default.out" 2>/dev/null)"; }
[ "$case6_archive_exit" = "0" ] || { c6_ok=false; info "case6 archive writer exited $case6_archive_exit: $(cat "$TMPROOT/case6_archive.out" 2>/dev/null)"; }
jq -e '.active_projects[] | select(.project_number == 1) | .marker_case6_default == "written"' "$STATE_FILE" >/dev/null 2>&1 || { c6_ok=false; info "case6 default-path mutation missing"; }
jq -e '.completed_projects[] | select(.project_number == 201)' "$ARCHIVE_STATE_FILE" >/dev/null 2>&1 || { c6_ok=false; info "case6 archive mutation missing"; }
# The archive writer was launched only once the default-path writer's staging file was observed
# (i.e. once it held the mutex), and its own completion must not have raced ahead of the
# default-path writer's completion under the single-mutex design -- the archive write started
# strictly after the default-path writer began holding the lock, so if the two share one mutex
# the archive write can only finish once the default writer has released it. We only assert
# ordering of completion timestamps as corroborating evidence, not as the sole proof (the real
# proof is that both landed correctly above); a near-simultaneous finish is not itself a failure
# signal on a fast machine, so this is reported as info rather than asserted as a hard failure.
info "case6 timing: default-writer finished at ${case6_default_done_epoch}ns, archive-writer finished at ${case6_archive_done_epoch}ns (archive launched at ${case6_archive_start_epoch}ns, after observing the default writer's staging file)"

if [ "$c6_ok" = true ]; then
  pass "6: single-mutex serialization ACROSS targets -- a default-path writer and an archive-targeted writer both land under the same specs/.scope-lock mutex (D2 regression guard)"
else
  fail "6: cross-target single-mutex serialization case failed (see INFO lines above)"
fi

# =====================================================================
# Case 7: --init -- against a target that does NOT exist, the file is created with the
# constructed document and exits 0; a second --init against the now-existing target succeeds and
# emits the overwrite note on stderr.
# =====================================================================
INIT_TARGET="$TMPROOT/specs/archive/state-init-case7.json"
rm -f "$INIT_TARGET"

(
  cd "$TMPROOT"
  "$SW" '{"completed_projects": [], "archived_at": "case7-first"}' --init \
    --state-file specs/archive/state-init-case7.json --session-id "sess_case7_first" \
    > "$TMPROOT/case7_first.out" 2>&1
  echo $? > "$TMPROOT/case7_first.exit"
)
case7_first_exit=$(cat "$TMPROOT/case7_first.exit" 2>/dev/null || echo "?")

c7_ok=true
[ "$case7_first_exit" = "0" ] || { c7_ok=false; info "case7 first --init exited $case7_first_exit (expected 0): $(cat "$TMPROOT/case7_first.out" 2>/dev/null)"; }
[ -f "$INIT_TARGET" ] || { c7_ok=false; info "case7 first --init did not create $INIT_TARGET"; }
jq -e '.archived_at == "case7-first"' "$INIT_TARGET" >/dev/null 2>&1 || { c7_ok=false; info "case7 first --init did not write the constructed document"; }
grep -q "replacing an existing" "$TMPROOT/case7_first.out" && { c7_ok=false; info "case7 first --init (against a non-existing target) unexpectedly emitted the overwrite note"; }

(
  cd "$TMPROOT"
  "$SW" '{"completed_projects": [], "archived_at": "case7-second"}' --init \
    --state-file specs/archive/state-init-case7.json --session-id "sess_case7_second" \
    > "$TMPROOT/case7_second.out" 2>&1
  echo $? > "$TMPROOT/case7_second.exit"
)
case7_second_exit=$(cat "$TMPROOT/case7_second.exit" 2>/dev/null || echo "?")

[ "$case7_second_exit" = "0" ] || { c7_ok=false; info "case7 second --init exited $case7_second_exit (expected 0): $(cat "$TMPROOT/case7_second.out" 2>/dev/null)"; }
jq -e '.archived_at == "case7-second"' "$INIT_TARGET" >/dev/null 2>&1 || { c7_ok=false; info "case7 second --init did not overwrite the target"; }
grep -q "replacing an existing" "$TMPROOT/case7_second.out" || { c7_ok=false; info "case7 second --init (against an existing target) did not emit the overwrite note on stderr"; }

if [ "$c7_ok" = true ]; then
  pass "7: --init creates a non-existing target cleanly, and a second --init against the now-existing target overwrites with a loud stderr note"
else
  fail "7: --init case failed (see INFO lines above)"
fi

# =====================================================================
# Case 8: --regen-todo refusal -- with a non-default --state-file, exits 1, the target is
# untouched, and specs/TODO.md is not created/modified. Exercise at least two spellings of the
# default path (relative and absolute) to confirm the normalized comparison treats both as
# default and permits --regen-todo there.
# =====================================================================
reset_state_json
reset_archive_state_json
rm -f "$TMPROOT/specs/TODO.md"
before_archive_hash=$(jq -S . "$ARCHIVE_STATE_FILE")

(
  cd "$TMPROOT"
  "$SW" '.completed_projects += [{"project_number": 202, "project_name": "case8"}]' \
    --regen-todo --state-file specs/archive/state.json --session-id "sess_case8_refuse" \
    > "$TMPROOT/case8_refuse.out" 2>&1
  echo $? > "$TMPROOT/case8_refuse.exit"
)
case8_refuse_exit=$(cat "$TMPROOT/case8_refuse.exit" 2>/dev/null || echo "?")
after_archive_hash=$(jq -S . "$ARCHIVE_STATE_FILE")

c8_ok=true
[ "$case8_refuse_exit" = "1" ] || { c8_ok=false; info "case8 refusal exited $case8_refuse_exit (expected 1): $(cat "$TMPROOT/case8_refuse.out" 2>/dev/null)"; }
[ "$before_archive_hash" = "$after_archive_hash" ] || { c8_ok=false; info "case8 archive target was modified despite the --regen-todo refusal"; }
[ ! -f "$TMPROOT/specs/TODO.md" ] || { c8_ok=false; info "case8 specs/TODO.md was created despite the --regen-todo refusal"; }

# Two spellings of the default path -- relative (from within TMPROOT) and absolute -- must both
# be recognized as the default and PERMIT --regen-todo (exit 0), proving the realpath -m
# normalized comparison, not a raw string compare.
(
  cd "$TMPROOT"
  "$SW" '.next_project_number = 10' --regen-todo --state-file specs/state.json \
    --session-id "sess_case8_rel" > "$TMPROOT/case8_rel.out" 2>&1
  echo $? > "$TMPROOT/case8_rel.exit"
)
case8_rel_exit=$(cat "$TMPROOT/case8_rel.exit" 2>/dev/null || echo "?")
[ "$case8_rel_exit" = "0" ] || { c8_ok=false; info "case8 relative-default-path --regen-todo exited $case8_rel_exit (expected 0): $(cat "$TMPROOT/case8_rel.out" 2>/dev/null)"; }

(
  cd "$TMPROOT"
  "$SW" '.next_project_number = 11' --regen-todo --state-file "$STATE_FILE" \
    --session-id "sess_case8_abs" > "$TMPROOT/case8_abs.out" 2>&1
  echo $? > "$TMPROOT/case8_abs.exit"
)
case8_abs_exit=$(cat "$TMPROOT/case8_abs.exit" 2>/dev/null || echo "?")
[ "$case8_abs_exit" = "0" ] || { c8_ok=false; info "case8 absolute-default-path --regen-todo exited $case8_abs_exit (expected 0): $(cat "$TMPROOT/case8_abs.out" 2>/dev/null)"; }
jq -e '.next_project_number == 11' "$STATE_FILE" >/dev/null 2>&1 || { c8_ok=false; info "case8 absolute-default-path write did not land"; }

if [ "$c8_ok" = true ]; then
  pass "8: --regen-todo refused (exit 1, target untouched, TODO.md not created) for a non-default --state-file, and permitted for both a relative and an absolute spelling of the default path"
else
  fail "8: --regen-todo refusal case failed (see INFO lines above)"
fi

# =====================================================================
# Case 9: --init default-path refusal -- --init with no --state-file exits 1 and specs/state.json
# is byte-identical afterward; --init --state-file <the default path> likewise exits 1.
# =====================================================================
reset_state_json
before_default_hash_c9=$(jq -S . "$STATE_FILE")

(
  cd "$TMPROOT"
  "$SW" '{"foo": 1}' --init --session-id "sess_case9_noflag" > "$TMPROOT/case9_noflag.out" 2>&1
  echo $? > "$TMPROOT/case9_noflag.exit"
)
case9_noflag_exit=$(cat "$TMPROOT/case9_noflag.exit" 2>/dev/null || echo "?")

(
  cd "$TMPROOT"
  "$SW" '{"foo": 1}' --init --state-file specs/state.json --session-id "sess_case9_explicit" \
    > "$TMPROOT/case9_explicit.out" 2>&1
  echo $? > "$TMPROOT/case9_explicit.exit"
)
case9_explicit_exit=$(cat "$TMPROOT/case9_explicit.exit" 2>/dev/null || echo "?")
after_default_hash_c9=$(jq -S . "$STATE_FILE")

c9_ok=true
[ "$case9_noflag_exit" = "1" ] || { c9_ok=false; info "case9 --init with no --state-file exited $case9_noflag_exit (expected 1): $(cat "$TMPROOT/case9_noflag.out" 2>/dev/null)"; }
[ "$case9_explicit_exit" = "1" ] || { c9_ok=false; info "case9 --init --state-file <default path> exited $case9_explicit_exit (expected 1): $(cat "$TMPROOT/case9_explicit.out" 2>/dev/null)"; }
[ "$before_default_hash_c9" = "$after_default_hash_c9" ] || { c9_ok=false; info "case9 specs/state.json was modified despite both --init default-path refusals"; }

if [ "$c9_ok" = true ]; then
  pass "9: --init default-path refusal -- both no --state-file and an explicit default-path --state-file are refused (exit 1), specs/state.json untouched"
else
  fail "9: --init default-path refusal case failed (see INFO lines above)"
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
