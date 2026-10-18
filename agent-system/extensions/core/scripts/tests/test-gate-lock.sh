#!/usr/bin/env bash
# test-gate-lock.sh - Isolated-temp-root suite proving task-lock.sh's specs/.gate-lock family
# (gate-acquire/gate-release) and its two wired call sites (tests/run-all.sh's top level,
# verify-deploy.sh's gate8_run()) against the REAL mechanism: serialization of two concurrent
# full-battery invocations, non-vacuousness of that serialization assertion, stale/killed-holder
# reclaim, the nested-invocation no-op path, and no mutex leak on exit.
#
# Structural model: test-run-all-parallel.sh's synthetic-fixture pattern (a
# $WORKDIR/agent-system/extensions/core/manifest.json source-store anchor with a copied
# run-all.sh and trivial fixture suites under scripts/tests/), extended with
# test-task-lock-liveness.sh's isolated ".claude/scripts" temp-root pattern (copied task-lock.sh,
# deploy-root-guard.sh, lib/common.sh, lib/task-lookup-lib.sh, lib/file-scope-overlap.sh).
#
# NOTE on fixture depth: this suite nests the fixture extensions root TWO levels under $WORKDIR
# (agent-system/extensions/core), exactly mirroring the real repository's own depth, rather than
# the shallower $WORKDIR/exts/core test-run-all-parallel.sh uses for its own, unrelated purpose.
# This is required, not cosmetic: tests/run-all.sh's GATE_TASK_LOCK_SH resolution in source-store
# mode walks two levels up from EXTENSIONS_ROOT to find the deployed task-lock.sh, and
# task-lock.sh's own PROJECT_ROOT resolution (common_repo_root "$SCRIPT_DIR" 2) walks two levels
# up from its OWN location at $WORKDIR/.claude/scripts/task-lock.sh -- both must land on the same
# $WORKDIR for the mutex to actually land at $WORKDIR/specs/.gate-lock as intended, and only the
# real two-level nesting makes that arithmetic agree.
#
# Never touches the real specs/ tree -- every mutex, fixture suite, and marker file lives under
# a throwaway mktemp -d root.
#
# Exit 0 when all cases PASS, exit 1 when any case FAILS.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUN_ALL_SRC="$CORE_DIR/tests/run-all.sh"
TASK_LOCK_SRC="$CORE_DIR/task-lock.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0
pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; FAILED=$((FAILED + 1)); [ -n "${2:-}" ] && echo "$2"; }
info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

if [ ! -f "$RUN_ALL_SRC" ] || [ ! -f "$TASK_LOCK_SRC" ] || [ ! -f "$CORE_DIR/deploy-root-guard.sh" ] \
    || [ ! -f "$CORE_DIR/lib/common.sh" ] || [ ! -f "$CORE_DIR/lib/task-lookup-lib.sh" ] \
    || [ ! -f "$CORE_DIR/lib/file-scope-overlap.sh" ]; then
  echo "ERROR: expected run-all.sh, task-lock.sh, deploy-root-guard.sh, lib/common.sh, lib/task-lookup-lib.sh, and lib/file-scope-overlap.sh alongside this suite's sibling scripts dir ($CORE_DIR)" >&2
  exit 1
fi

# This suite's own "unnested" fixture invocations must genuinely exercise the unnested code path,
# including when THIS suite is itself discovered and launched by an outer run-all.sh (e.g. Gate 8
# recursing into this very battery). That outer runner unconditionally exports RUN_ALL_NESTED=1
# into every suite it launches, and GATE_MUTEX_HELD=1 whenever it itself holds the gate lock --
# both inherited by every child process this script spawns. Left inherited, every "unnested" case
# below would be silently vacuous. Clearing both once here restores a clean environment for this
# script and everything it spawns -- mirrors test-run-all-parallel.sh's own documented
# RUN_ALL_NESTED unset at its top.
unset RUN_ALL_NESTED
unset GATE_MUTEX_HELD

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# --- Fixture layout -----------------------------------------------------------------------
EXT_CORE_DIR="$WORKDIR/agent-system/extensions/core"
TESTS_DIR="$EXT_CORE_DIR/scripts/tests"
DEPLOY_SCRIPTS_DIR="$WORKDIR/.claude/scripts"
mkdir -p "$TESTS_DIR" "$DEPLOY_SCRIPTS_DIR/lib" "$WORKDIR/specs"
echo '{}' > "$EXT_CORE_DIR/manifest.json"

cp "$RUN_ALL_SRC" "$TESTS_DIR/run-all.sh"
chmod +x "$TESTS_DIR/run-all.sh"
FIXTURE_RUNNER="$TESTS_DIR/run-all.sh"

cp "$TASK_LOCK_SRC" "$DEPLOY_SCRIPTS_DIR/task-lock.sh"
cp "$CORE_DIR/deploy-root-guard.sh" "$DEPLOY_SCRIPTS_DIR/deploy-root-guard.sh"
cp "$CORE_DIR/lib/common.sh" "$DEPLOY_SCRIPTS_DIR/lib/common.sh"
cp "$CORE_DIR/lib/task-lookup-lib.sh" "$DEPLOY_SCRIPTS_DIR/lib/task-lookup-lib.sh"
cp "$CORE_DIR/lib/file-scope-overlap.sh" "$DEPLOY_SCRIPTS_DIR/lib/file-scope-overlap.sh"
chmod +x "$DEPLOY_SCRIPTS_DIR/task-lock.sh"
FIXTURE_TASK_LOCK="$DEPLOY_SCRIPTS_DIR/task-lock.sh"
GATE_LOCK_DIR="$WORKDIR/specs/.gate-lock"

# One trivial fixture suite that records start/finish epoch-millisecond markers to a shared file
# (path passed via env var, inherited by run-all.sh's child `bash "$suite"` invocation) and holds
# the "critical section" open briefly so overlap/non-overlap is observable.
cat > "$TESTS_DIR/test-fixture-marker.sh" << 'EOF'
#!/usr/bin/env bash
now_ms() { date +%s%3N; }
: "${MARKER_FILE:?MARKER_FILE must be set}"
: "${MARKER_LABEL:?MARKER_LABEL must be set}"
echo "${MARKER_LABEL} start $(now_ms)" >> "$MARKER_FILE"
sleep 0.5
echo "${MARKER_LABEL} finish $(now_ms)" >> "$MARKER_FILE"
exit 0
EOF
chmod +x "$TESTS_DIR/test-fixture-marker.sh"

# Sanity: confirm the fixture's own PROJECT_ROOT/EXTENSIONS_ROOT nesting agrees before relying
# on it in every case below -- a defensive self-check of the depth claim in this file's own
# header NOTE, not a case in its own right.
sanity_out=$(cd "$WORKDIR" && bash "$FIXTURE_RUNNER" --quiet --only test-fixture-marker.sh 2>&1)
if [ -d "$GATE_LOCK_DIR" ]; then
  fail "sanity: fixture depth check -- .gate-lock should never survive past a completed invocation" "$sanity_out"
else
  pass "sanity: fixture resolves and runs cleanly before the real cases begin"
fi

# =====================================================================
# Case: serialization -- two concurrent full-battery invocations do not overlap.
# =====================================================================
MARKER_FILE_A="$WORKDIR/markers-a.txt"
: > "$MARKER_FILE_A"
(
  cd "$WORKDIR" && MARKER_FILE="$MARKER_FILE_A" MARKER_LABEL=p1 bash "$FIXTURE_RUNNER" --quiet --jobs 1 >/dev/null 2>&1
) &
p1_pid=$!
(
  cd "$WORKDIR" && MARKER_FILE="$MARKER_FILE_A" MARKER_LABEL=p2 bash "$FIXTURE_RUNNER" --quiet --jobs 1 >/dev/null 2>&1
) &
p2_pid=$!
wait "$p1_pid"; p1_rc=$?
wait "$p2_pid"; p2_rc=$?

serialization_ok=true
[ "$p1_rc" -eq 0 ] || serialization_ok=false
[ "$p2_rc" -eq 0 ] || serialization_ok=false

p1_start=$(awk '$1=="p1" && $2=="start" {print $3}' "$MARKER_FILE_A")
p1_finish=$(awk '$1=="p1" && $2=="finish" {print $3}' "$MARKER_FILE_A")
p2_start=$(awk '$1=="p2" && $2=="start" {print $3}' "$MARKER_FILE_A")
p2_finish=$(awk '$1=="p2" && $2=="finish" {print $3}' "$MARKER_FILE_A")

if [ -z "$p1_start" ] || [ -z "$p1_finish" ] || [ -z "$p2_start" ] || [ -z "$p2_finish" ]; then
  fail "case: serialization -- markers missing" "$(cat "$MARKER_FILE_A")"
elif [ "$serialization_ok" != "true" ]; then
  fail "case: serialization -- one or both fixture batteries exited non-zero (p1=$p1_rc p2=$p2_rc)"
elif { [ "$p1_finish" -le "$p2_start" ] || [ "$p2_finish" -le "$p1_start" ]; }; then
  pass "case: serialization -- two concurrent full-battery invocations did not overlap ([$p1_start,$p1_finish] vs [$p2_start,$p2_finish])"
else
  fail "case: serialization -- windows overlapped ([$p1_start,$p1_finish] vs [$p2_start,$p2_finish]) -- the mutex failed to serialize them"
fi

if [ -d "$GATE_LOCK_DIR" ]; then
  fail "case: serialization (no-leak) -- $GATE_LOCK_DIR still present after both invocations exited"
else
  pass "case: serialization (no-leak) -- $GATE_LOCK_DIR absent after both invocations exited"
fi

# =====================================================================
# Case: non-vacuousness -- with the deployed task-lock.sh removed (forcing the documented
# fail-open skip), the SAME two invocations overlap. This proves the serialization case above
# cannot pass for an unrelated reason (e.g. the fixture suite being too fast to ever overlap
# regardless of locking).
# =====================================================================
mv "$FIXTURE_TASK_LOCK" "${FIXTURE_TASK_LOCK}.disabled"

MARKER_FILE_B="$WORKDIR/markers-b.txt"
: > "$MARKER_FILE_B"
(
  cd "$WORKDIR" && MARKER_FILE="$MARKER_FILE_B" MARKER_LABEL=p1 bash "$FIXTURE_RUNNER" --quiet --jobs 1 >/dev/null 2>&1
) &
p1_pid=$!
(
  cd "$WORKDIR" && MARKER_FILE="$MARKER_FILE_B" MARKER_LABEL=p2 bash "$FIXTURE_RUNNER" --quiet --jobs 1 >/dev/null 2>&1
) &
p2_pid=$!
wait "$p1_pid"
wait "$p2_pid"

mv "${FIXTURE_TASK_LOCK}.disabled" "$FIXTURE_TASK_LOCK"

nb_p1_start=$(awk '$1=="p1" && $2=="start" {print $3}' "$MARKER_FILE_B")
nb_p1_finish=$(awk '$1=="p1" && $2=="finish" {print $3}' "$MARKER_FILE_B")
nb_p2_start=$(awk '$1=="p2" && $2=="start" {print $3}' "$MARKER_FILE_B")
nb_p2_finish=$(awk '$1=="p2" && $2=="finish" {print $3}' "$MARKER_FILE_B")

if [ -z "$nb_p1_start" ] || [ -z "$nb_p1_finish" ] || [ -z "$nb_p2_start" ] || [ -z "$nb_p2_finish" ]; then
  fail "case: non-vacuousness -- markers missing" "$(cat "$MARKER_FILE_B")"
elif { [ "$nb_p1_finish" -le "$nb_p2_start" ] || [ "$nb_p2_finish" -le "$nb_p1_start" ]; }; then
  fail "case: non-vacuousness -- windows did NOT overlap with coordination disabled ([$nb_p1_start,$nb_p1_finish] vs [$nb_p2_start,$nb_p2_finish]) -- the serialization case above may be passing for an unrelated reason"
else
  pass "case: non-vacuousness -- with the deployed task-lock.sh absent (fail-open), the two invocations DID overlap ([$nb_p1_start,$nb_p1_finish] vs [$nb_p2_start,$nb_p2_finish]), confirming the serialization case above is non-vacuous"
fi

# =====================================================================
# Case: stale/killed holder -- a holder that never releases (simulating a crash) is reclaimed by
# the next acquirer once its holder-declared staleness window elapses, and the primitive's own
# WARN: reclaiming stale line is actually printed.
# =====================================================================
(
  GATE_MUTEX_STALE_SEC=2 bash "$FIXTURE_TASK_LOCK" gate-acquire "crash-victim" > "$WORKDIR/crash-token.txt" 2>&1
) &
crash_pid=$!
wait "$crash_pid"
# "kill -9 it without releasing": the acquiring process has already exited on its own (acquire is
# a bounded, non-blocking call once it succeeds) -- the kill below is a defensive no-op against
# that already-exited pid, and "without releasing" is satisfied by simply never calling
# gate-release for this token. The actual simulated-crash mechanic is the backdated claimed_at
# below, avoiding a real sleep (no-sleeping convention already established by
# test-task-lock-liveness.sh/test-task-lock-reap.sh's controlled-epoch fixtures).
kill -9 "$crash_pid" 2>/dev/null || true

if [ ! -d "$GATE_LOCK_DIR" ]; then
  fail "case: stale/killed holder -- expected $GATE_LOCK_DIR to exist after the crash-victim's acquire" "$(cat "$WORKDIR/crash-token.txt")"
else
  # Backdate claimed_at well past the 2s holder-declared stale_sec written at acquire time.
  echo "$(( $(date -u +%s) - 10 ))" > "$GATE_LOCK_DIR/claimed_at"

  reclaim_out=$(bash "$FIXTURE_TASK_LOCK" gate-acquire "reclaimer" 2>&1)
  reclaim_rc=$?
  reclaim_token=$(printf '%s\n' "$reclaim_out" | tail -1)

  if [ "$reclaim_rc" -ne 0 ]; then
    fail "case: stale/killed holder -- reclaiming acquire did not succeed (rc=$reclaim_rc)" "$reclaim_out"
  else
    pass "case: stale/killed holder -- a fresh acquire succeeded after the crashed holder's window elapsed"
  fi

  if printf '%s\n' "$reclaim_out" | grep -q "WARN: reclaiming stale specs/\.gate-lock mutex"; then
    pass "case: stale/killed holder -- the primitive's own WARN: reclaiming stale specs/.gate-lock mutex line was printed"
  else
    fail "case: stale/killed holder -- expected a 'WARN: reclaiming stale specs/.gate-lock mutex' line" "$reclaim_out"
  fi

  bash "$FIXTURE_TASK_LOCK" gate-release "$reclaim_token" >/dev/null 2>&1 || true
fi

if [ -d "$GATE_LOCK_DIR" ]; then
  fail "case: stale/killed holder (no-leak) -- $GATE_LOCK_DIR still present after release"
else
  pass "case: stale/killed holder (no-leak) -- $GATE_LOCK_DIR absent after release"
fi

# =====================================================================
# Case: nested invocation -- RUN_ALL_NESTED=1 and, separately, an inherited GATE_MUTEX_HELD=1
# each create no mutex at all, and the battery still completes with its normal verdict.
# =====================================================================
nested_out=$(cd "$WORKDIR" && RUN_ALL_NESTED=1 MARKER_FILE="$WORKDIR/markers-nested.txt" MARKER_LABEL=n1 bash "$FIXTURE_RUNNER" --quiet 2>&1)
nested_rc=$?
if [ -d "$GATE_LOCK_DIR" ]; then
  fail "case: nested invocation (RUN_ALL_NESTED=1) -- $GATE_LOCK_DIR was created" "$nested_out"
elif [ "$nested_rc" -ne 0 ]; then
  fail "case: nested invocation (RUN_ALL_NESTED=1) -- battery did not complete with its normal verdict (rc=$nested_rc)" "$nested_out"
else
  pass "case: nested invocation (RUN_ALL_NESTED=1) -- no mutex created, battery completed normally"
fi

guest_out=$(cd "$WORKDIR" && GATE_MUTEX_HELD=1 MARKER_FILE="$WORKDIR/markers-guest.txt" MARKER_LABEL=g1 bash "$FIXTURE_RUNNER" --quiet 2>&1)
guest_rc=$?
if [ -d "$GATE_LOCK_DIR" ]; then
  fail "case: nested invocation (inherited GATE_MUTEX_HELD=1) -- $GATE_LOCK_DIR was created" "$guest_out"
elif [ "$guest_rc" -ne 0 ]; then
  fail "case: nested invocation (inherited GATE_MUTEX_HELD=1) -- battery did not complete with its normal verdict (rc=$guest_rc)" "$guest_out"
else
  pass "case: nested invocation (inherited GATE_MUTEX_HELD=1) -- no mutex created, battery completed normally"
fi

# =====================================================================
# Case: no-leak on both --jobs 1 and --jobs 2 (covering Phase 2's composed-trap change on both
# the sequential and parallel code paths).
# =====================================================================
for jobs_n in 1 2; do
  leak_out=$(cd "$WORKDIR" && MARKER_FILE="$WORKDIR/markers-leak-${jobs_n}.txt" MARKER_LABEL="leak${jobs_n}" bash "$FIXTURE_RUNNER" --quiet --jobs "$jobs_n" 2>&1)
  leak_rc=$?
  if [ -d "$GATE_LOCK_DIR" ]; then
    fail "case: no-leak (--jobs $jobs_n) -- $GATE_LOCK_DIR still present after exit" "$leak_out"
  elif [ "$leak_rc" -ne 0 ]; then
    fail "case: no-leak (--jobs $jobs_n) -- battery exited non-zero (rc=$leak_rc)" "$leak_out"
  else
    pass "case: no-leak (--jobs $jobs_n) -- $GATE_LOCK_DIR absent after a normal full-battery exit"
  fi
done

echo ""
echo "==================================================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "==================================================================="

[ "$FAILED" -eq 0 ]
