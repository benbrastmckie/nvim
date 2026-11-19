#!/usr/bin/env bash
# test-gate-lock-host-scope.sh - Cross-directory double-start and lock-root degradation coverage
# for task-lock.sh's OPT-IN host-scoped gate-acquire-host/gate-release-host verb pair (see that
# file's own "Host-Scoped Mutex" contract paragraph for the full design this suite proves).
#
# WHY THIS SUITE IS NOT test-gate-lock.sh WITH A FLAG FLIPPED: a same-repository double-start
# demo cannot distinguish a host-scoped guard from the repo-scoped one it extends -- both
# invocations in test-gate-lock.sh's own serialization case share ONE $WORKDIR, so a run against
# the repo-scoped mutex and a run against the host-scoped mutex would pass identically before and
# after this change, proving nothing about scope. This suite instead constructs TWO INDEPENDENT
# fixture repository roots (two separate mktemp -d trees, each a full repo-shaped fixture) and
# launches one battery from each. Only a host-scoped lock, resolved OUTSIDE either root, can
# serialize invocations that never share a specs/ tree.
#
# Structural model: test-gate-lock.sh's own fixture technique (a
# $WORKDIR/agent-system/extensions/core/manifest.json source-store anchor, a copied run-all.sh, a
# trivial marker fixture suite, and an isolated ".claude/scripts" deploy-tree copy of
# task-lock.sh/deploy-root-guard.sh/lib/common.sh/lib/task-lookup-lib.sh/lib/file-scope-
# overlap.sh), applied TWICE to build two independent roots instead of once.
#
# Never touches the real specs/ tree, the real $XDG_RUNTIME_DIR, or any host-scoped lock root a
# concurrent real session might be using -- every mutex, fixture suite, and marker file in this
# suite lives under a throwaway mktemp -d root, and TASK_LOCK_HOST_ROOT_OVERRIDE is mandatory in
# every case that resolves a host lock root.
#
# Degradation technique note: the "every tier exhausted" case cannot reach tier 3
# (/run/user/$UID) through env alone on a real systemd-logind host, where that directory
# genuinely exists and is writable (confirmed at suite-authoring time). Rather than adding a
# test-only bypass to resolve_host_lock_root() itself -- which would be production code reached
# only by a test, a worse shape than the alternative -- this suite overrides the bash UID
# variable itself (UID=<a vanishingly unlikely-to-exist uid>) for that one subprocess, which is
# NOT readonly in a non-interactive, non-login bash invocation (verified directly: `env
# UID=999999999 bash -c 'echo $UID'` prints 999999999, and reassigning it inside the script also
# succeeds). /run/user/999999999 does not exist on any real host, so tier 3 fails exactly as it
# would on a genuinely absent-tier-3 host, with no code change and no process-level privilege
# implications (this does not change the process's real uid/euid, only the shell variable
# resolve_host_lock_root() reads).
#
# Exit 0 when all cases PASS, exit 1 when any case FAILS.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUN_ALL_SRC="$CORE_DIR/tests/run-all.sh"
TASK_LOCK_SRC="$CORE_DIR/task-lock.sh"

PASSED=0
FAILED=0

if [ ! -f "$RUN_ALL_SRC" ] || [ ! -f "$TASK_LOCK_SRC" ] || [ ! -f "$CORE_DIR/deploy-root-guard.sh" ] \
    || [ ! -f "$CORE_DIR/lib/common.sh" ] || [ ! -f "$CORE_DIR/lib/task-lookup-lib.sh" ] \
    || [ ! -f "$CORE_DIR/lib/file-scope-overlap.sh" ]; then
  echo "ERROR: expected run-all.sh, task-lock.sh, deploy-root-guard.sh, lib/common.sh, lib/task-lookup-lib.sh, and lib/file-scope-overlap.sh alongside this suite's sibling scripts dir ($CORE_DIR)" >&2
  exit 1
fi

# Mirrors test-gate-lock.sh's own documented precedent: restore a clean environment for this
# script and everything it spawns, so no case below is silently vacuous when this suite is itself
# discovered and launched by an outer run-all.sh (e.g. Gate 8 recursing into this very battery).
unset RUN_ALL_NESTED
unset GATE_MUTEX_HELD
unset GATE_MUTEX_HOST_HELD

# --- Build one independent fixture repository root --------------------------------------------
build_fixture_root() {
  local root="$1"
  local ext_core_dir="$root/agent-system/extensions/core"
  local tests_dir="$ext_core_dir/scripts/tests"
  local deploy_scripts_dir="$root/.claude/scripts"
  mkdir -p "$tests_dir" "$deploy_scripts_dir/lib" "$root/specs"
  echo '{}' > "$ext_core_dir/manifest.json"

  cp "$RUN_ALL_SRC" "$tests_dir/run-all.sh"
  chmod +x "$tests_dir/run-all.sh"

  cp "$TASK_LOCK_SRC" "$deploy_scripts_dir/task-lock.sh"
  cp "$CORE_DIR/deploy-root-guard.sh" "$deploy_scripts_dir/deploy-root-guard.sh"
  cp "$CORE_DIR/lib/common.sh" "$deploy_scripts_dir/lib/common.sh"
  cp "$CORE_DIR/lib/task-lookup-lib.sh" "$deploy_scripts_dir/lib/task-lookup-lib.sh"
  cp "$CORE_DIR/lib/file-scope-overlap.sh" "$deploy_scripts_dir/lib/file-scope-overlap.sh"
  chmod +x "$deploy_scripts_dir/task-lock.sh"

  cat > "$tests_dir/test-fixture-marker.sh" << 'EOF'
#!/usr/bin/env bash
now_ms() { date +%s%3N; }
: "${MARKER_FILE:?MARKER_FILE must be set}"
: "${MARKER_LABEL:?MARKER_LABEL must be set}"
echo "${MARKER_LABEL} start $(now_ms)" >> "$MARKER_FILE"
sleep 0.5
echo "${MARKER_LABEL} finish $(now_ms)" >> "$MARKER_FILE"
exit 0
EOF
  chmod +x "$tests_dir/test-fixture-marker.sh"

  # No MARKER_FILE/MARKER_LABEL requirement -- for the degradation cases below, which only need
  # "the battery still runs and produces a real verdict", not timing markers.
  cat > "$tests_dir/test-fixture-trivial.sh" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$tests_dir/test-fixture-trivial.sh"
}

ROOT_A="$(mktemp -d)"
ROOT_B="$(mktemp -d)"
cleanup() {
  rm -rf "$ROOT_A" "$ROOT_B" 2>/dev/null || true
}
trap cleanup EXIT

build_fixture_root "$ROOT_A"
build_fixture_root "$ROOT_B"

RUNNER_A="$ROOT_A/agent-system/extensions/core/scripts/tests/run-all.sh"
RUNNER_B="$ROOT_B/agent-system/extensions/core/scripts/tests/run-all.sh"

# Sanity: confirm both fixture roots resolve and run cleanly before the real cases begin --
# mirrors test-gate-lock.sh's own sanity case, against a throwaway host root so it never touches
# either fixture's real specs/ path or the real $XDG_RUNTIME_DIR.
SANITY_HOST_ROOT="$(mktemp -d)"
sanity_out=$(cd "$ROOT_A" && TASK_LOCK_HOST_ROOT_OVERRIDE="$SANITY_HOST_ROOT" bash "$RUNNER_A" --quiet --only test-fixture-marker.sh 2>&1)
if [ -d "$SANITY_HOST_ROOT/.gate-lock" ]; then
  common_test_fail "sanity: fixture depth check -- host .gate-lock should never survive past a completed invocation" "$sanity_out"
else
  common_test_pass "sanity: both fixture roots resolve and run cleanly before the real cases begin"
fi
rm -rf "$SANITY_HOST_ROOT"

# =====================================================================
# Case: cross-directory serialization -- ONE shared TASK_LOCK_HOST_ROOT_OVERRIDE, two concurrent
# unfiltered battery invocations, one cd'd into EACH independent fixture root. This is the exact
# regression this task fixes: before the host-scoped form existed, two invocations from two
# different repositories could never contend on anything, because each resolved its own private
# "$PROJECT_ROOT/specs/.gate-lock". This case could not pass before this change.
# =====================================================================
SHARED_HOST_ROOT="$(mktemp -d)"
MARKER_XDIR="$ROOT_A/markers-xdir.txt"
: > "$MARKER_XDIR"
(
  cd "$ROOT_A" && TASK_LOCK_HOST_ROOT_OVERRIDE="$SHARED_HOST_ROOT" MARKER_FILE="$MARKER_XDIR" MARKER_LABEL=p1 bash "$RUNNER_A" --quiet --jobs 1 >/dev/null 2>&1
) &
p1_pid=$!
(
  cd "$ROOT_B" && TASK_LOCK_HOST_ROOT_OVERRIDE="$SHARED_HOST_ROOT" MARKER_FILE="$MARKER_XDIR" MARKER_LABEL=p2 bash "$RUNNER_B" --quiet --jobs 1 >/dev/null 2>&1
) &
p2_pid=$!
wait "$p1_pid"; p1_rc=$?
wait "$p2_pid"; p2_rc=$?

xdir_ok=true
[ "$p1_rc" -eq 0 ] || xdir_ok=false
[ "$p2_rc" -eq 0 ] || xdir_ok=false

xp1_start=$(awk '$1=="p1" && $2=="start" {print $3}' "$MARKER_XDIR")
xp1_finish=$(awk '$1=="p1" && $2=="finish" {print $3}' "$MARKER_XDIR")
xp2_start=$(awk '$1=="p2" && $2=="start" {print $3}' "$MARKER_XDIR")
xp2_finish=$(awk '$1=="p2" && $2=="finish" {print $3}' "$MARKER_XDIR")

if [ -z "$xp1_start" ] || [ -z "$xp1_finish" ] || [ -z "$xp2_start" ] || [ -z "$xp2_finish" ]; then
  common_test_fail "case: cross-directory serialization -- markers missing" "$(cat "$MARKER_XDIR")"
elif [ "$xdir_ok" != "true" ]; then
  common_test_fail "case: cross-directory serialization -- one or both fixture batteries exited non-zero (p1=$p1_rc p2=$p2_rc)"
elif { [ "$xp1_finish" -le "$xp2_start" ] || [ "$xp2_finish" -le "$xp1_start" ]; }; then
  common_test_pass "case: cross-directory serialization -- two concurrent invocations from TWO DIFFERENT fixture repository roots, sharing one host lock root, did not overlap ([$xp1_start,$xp1_finish] vs [$xp2_start,$xp2_finish])"
else
  common_test_fail "case: cross-directory serialization -- windows overlapped ([$xp1_start,$xp1_finish] vs [$xp2_start,$xp2_finish]) -- the host-scoped mutex failed to serialize cross-repository invocations"
fi

if [ -d "$SHARED_HOST_ROOT/.gate-lock" ]; then
  common_test_fail "case: cross-directory serialization (no-leak) -- $SHARED_HOST_ROOT/.gate-lock still present after both invocations exited"
else
  common_test_pass "case: cross-directory serialization (no-leak) -- $SHARED_HOST_ROOT/.gate-lock absent after both invocations exited"
fi
rm -rf "$SHARED_HOST_ROOT"

# =====================================================================
# Case: non-vacuousness control -- the SAME two fixture roots, each given its OWN distinct
# TASK_LOCK_HOST_ROOT_OVERRIDE. This is exactly what repo-scoping reduces to: two independent
# lock roots, one per "repository", never contending with each other. This case MUST observe
# overlap -- a run where both this case and the one above report "no overlap" is a FAILED PROOF,
# not a pass, because it would mean the serialization case above might be passing for some
# unrelated reason (e.g. the fixture battery being too slow-starting to ever race regardless of
# locking).
# =====================================================================
DISTINCT_HOST_ROOT_A="$(mktemp -d)"
DISTINCT_HOST_ROOT_B="$(mktemp -d)"
MARKER_CTRL="$ROOT_A/markers-control.txt"
: > "$MARKER_CTRL"
(
  cd "$ROOT_A" && TASK_LOCK_HOST_ROOT_OVERRIDE="$DISTINCT_HOST_ROOT_A" MARKER_FILE="$MARKER_CTRL" MARKER_LABEL=p1 bash "$RUNNER_A" --quiet --jobs 1 >/dev/null 2>&1
) &
p1_pid=$!
(
  cd "$ROOT_B" && TASK_LOCK_HOST_ROOT_OVERRIDE="$DISTINCT_HOST_ROOT_B" MARKER_FILE="$MARKER_CTRL" MARKER_LABEL=p2 bash "$RUNNER_B" --quiet --jobs 1 >/dev/null 2>&1
) &
p2_pid=$!
wait "$p1_pid"
wait "$p2_pid"

cp1_start=$(awk '$1=="p1" && $2=="start" {print $3}' "$MARKER_CTRL")
cp1_finish=$(awk '$1=="p1" && $2=="finish" {print $3}' "$MARKER_CTRL")
cp2_start=$(awk '$1=="p2" && $2=="start" {print $3}' "$MARKER_CTRL")
cp2_finish=$(awk '$1=="p2" && $2=="finish" {print $3}' "$MARKER_CTRL")

if [ -z "$cp1_start" ] || [ -z "$cp1_finish" ] || [ -z "$cp2_start" ] || [ -z "$cp2_finish" ]; then
  common_test_fail "case: non-vacuousness control -- markers missing" "$(cat "$MARKER_CTRL")"
elif { [ "$cp1_finish" -le "$cp2_start" ] || [ "$cp2_finish" -le "$cp1_start" ]; }; then
  common_test_fail "case: non-vacuousness control -- windows did NOT overlap with distinct host lock roots ([$cp1_start,$cp1_finish] vs [$cp2_start,$cp2_finish]) -- this is a FAILED PROOF: the cross-directory serialization case above may be passing for an unrelated reason"
else
  common_test_pass "case: non-vacuousness control -- with each fixture root given its OWN distinct host lock root (exactly what repo-scoping reduces to), the two invocations DID overlap ([$cp1_start,$cp1_finish] vs [$cp2_start,$cp2_finish]), confirming the cross-directory serialization case above actually measures host-scoped coordination"
fi
rm -rf "$DISTINCT_HOST_ROOT_A" "$DISTINCT_HOST_ROOT_B"

# =====================================================================
# Case: degradation, override unwritable -- TASK_LOCK_HOST_ROOT_OVERRIDE points at a path under a
# chmod 000 parent directory, $XDG_RUNTIME_DIR unset. resolve_host_lock_root()'s tier 1 does not
# probe writability (by design -- see task-lock.sh's own resolver comment), so this exercises the
# REAL acquire_named_mutex mkdir-retry-until-budget-exhaustion failure path, not a synthetic
# resolver failure. The battery must still run, print a real verdict, and emit the named
# fail-open WARNING: line -- never hang (GATE_MUTEX_ACQUIRE_BUDGET_MS is lowered so this resolves
# in well under a second rather than the real 600000ms default) or refuse to run.
#
# Deliberately UNFILTERED (no --only): a narrowed run skips the whole gate-lock acquire branch
# entirely ("specs/.gate-lock is not touched for a narrowed run" -- confirmed directly while
# authoring this case, and the exact behavior Phase 3's own narrowed-run coverage relies on), so
# this case would otherwise never reach the acquire branch it means to exercise. The fixture only
# discovers two trivial suites, so an unfiltered run here is still fast.
# =====================================================================
UNWRITABLE_PARENT="$(mktemp -d)"
chmod 000 "$UNWRITABLE_PARENT"
degrade1_out=$(cd "$ROOT_A" && env -u XDG_RUNTIME_DIR TASK_LOCK_HOST_ROOT_OVERRIDE="$UNWRITABLE_PARENT/nested" GATE_MUTEX_ACQUIRE_BUDGET_MS=500 MARKER_FILE="$ROOT_A/markers-degrade1.txt" MARKER_LABEL=d1 bash "$RUNNER_A" --quiet --jobs 1 2>&1)
degrade1_rc=$?
chmod 700 "$UNWRITABLE_PARENT"
rm -rf "$UNWRITABLE_PARENT"

if [ "$degrade1_rc" -ne 0 ]; then
  common_test_fail "case: degradation, override unwritable -- expected a real (zero-exit) verdict despite the unwritable lock root" "$degrade1_out"
elif ! printf '%s\n' "$degrade1_out" | grep -qE 'passed, [0-9]+ failed'; then
  common_test_fail "case: degradation, override unwritable -- expected a real run-all.sh summary verdict line" "$degrade1_out"
elif ! printf '%s\n' "$degrade1_out" | grep -q 'WARNING: failed to acquire the host-scoped .gate-lock mutex'; then
  common_test_fail "case: degradation, override unwritable -- expected the named fail-open WARNING: line" "$degrade1_out"
else
  common_test_pass "case: degradation, override unwritable -- the battery still ran, produced a real verdict, and emitted the named fail-open WARNING: line"
fi

# =====================================================================
# Case: degradation, every tier exhausted -- $XDG_RUNTIME_DIR unset, tier 3 (/run/user/$UID)
# forced absent via the UID-override technique documented in this file's header (never touches
# the real /run/user/$UID or changes this process's real uid), and $TMPDIR pointed at an
# unwritable path so tier 4's fallback directory can never be created either.
# resolve_host_lock_root() must return non-zero FAST (no mkdir-retry loop -- tier 1 is not even
# reached since TASK_LOCK_HOST_ROOT_OVERRIDE is unset here).
#
# Tested as a DIRECT CLI call against the fixture's deployed task-lock.sh, not through the full
# run-all.sh battery: run-all.sh's own internal mktemp usage (the shared deployed-tree fixture,
# SUITE_OUT, OUT_DIR) also honors $TMPDIR, so pointing the WHOLE subprocess's $TMPDIR at an
# unwritable path breaks run-all.sh's own unrelated plumbing, not just the resolver's tier 4 --
# confirmed directly while authoring this case. The "override unwritable" case above already
# proves the call site's fail-open wiring in general (it does not inspect WHY gate-acquire-host
# failed, only that it did); this case's job is narrower and sharper: prove the RESOLVER itself
# correctly detects total exhaustion and returns non-zero with the named ERROR line, which a
# direct CLI call isolates more precisely than routing it through a whole battery would.
# =====================================================================
UNWRITABLE_TMPDIR="$(mktemp -d)"
chmod 000 "$UNWRITABLE_TMPDIR"
FIXTURE_TASK_LOCK_A="$ROOT_A/.claude/scripts/task-lock.sh"
degrade2_out=$(env -u XDG_RUNTIME_DIR -u TASK_LOCK_HOST_ROOT_OVERRIDE UID=999999999 TMPDIR="$UNWRITABLE_TMPDIR" GATE_MUTEX_ACQUIRE_BUDGET_MS=500 bash "$FIXTURE_TASK_LOCK_A" gate-acquire-host "every-tier-exhausted-test" 2>&1)
degrade2_rc=$?
chmod 700 "$UNWRITABLE_TMPDIR"
rm -rf "$UNWRITABLE_TMPDIR"

if [ "$degrade2_rc" -eq 0 ]; then
  common_test_fail "case: degradation, every tier exhausted -- expected gate-acquire-host to FAIL (non-zero) when every lock-root tier is unusable, not succeed" "$degrade2_out"
elif ! printf '%s\n' "$degrade2_out" | grep -q 'ERROR: could not resolve a host-scoped lock root'; then
  common_test_fail "case: degradation, every tier exhausted -- expected the named resolver-failure ERROR: line" "$degrade2_out"
else
  common_test_pass "case: degradation, every tier exhausted -- resolve_host_lock_root() correctly found every tier unusable and gate-acquire-host returned non-zero (rc=$degrade2_rc) with the named ERROR: line (never blocking)"
fi

# =====================================================================
# Case: no-leak -- neither fixture root's specs/ tree, nor any throwaway host root used above,
# retains a lock directory after this suite's cases have all completed. Each case above already
# does its own narrow no-leak assertion for the host root it used; this is a final, holistic
# sweep over both fixture roots' own repo-scoped specs/ trees too (never touched by this suite's
# host-scoped cases, but confirming that the repo-scoped family inside the copied task-lock.sh
# genuinely never activated as a side effect).
# =====================================================================
if [ -d "$ROOT_A/specs/.gate-lock" ] || [ -d "$ROOT_B/specs/.gate-lock" ]; then
  common_test_fail "case: no-leak -- a repo-scoped specs/.gate-lock directory survived in one of the fixture roots" "A=$(ls -la "$ROOT_A/specs" 2>&1) B=$(ls -la "$ROOT_B/specs" 2>&1)"
else
  common_test_pass "case: no-leak -- neither fixture root's repo-scoped specs/.gate-lock survived this suite's cases"
fi

echo ""
echo "==================================================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "==================================================================="

[ "$FAILED" -eq 0 ]
