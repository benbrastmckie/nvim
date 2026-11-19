#!/usr/bin/env bash
# test-batch-gate-pending-marker.sh - Unit-level suite for lib/batch-gate-marker-lib.sh, the
# single source of truth for the batch-gate-pending marker's path convention and staleness
# window (gate-ceiling-fit Phase 4/5). The write-side behavior (orchestrate-cycle-plan.sh writing
# on a real implement dispatch, not on a research-only cycle) is pinned in
# test-orchestrate-cycle-plan.sh's own Group 4/5 (that script's existing fixture already stands
# up the one precondition that matters -- a real dispatch -- far more cheaply than a dedicated
# fixture here could); the discharge-removal behavior (orchestrate-batch-gate.sh removing it, and
# the --dry-run/idempotent-absence cases) is pinned in test-orchestrate-batch-gate.sh's Case 11.
# This suite owns the LIBRARY's own pure functions: path construction, staleness-window honoring,
# fail-open on malformed input, and the warning text. Phase 5 extends this file with the entry
# guards' own refusal/scoped/nested/stale/override/absent cases.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

# ANTI-RECURSION / ANTI-INHERITANCE INVARIANT: this suite's own Cases 7-13 test verify-deploy.sh
# and run-all.sh's entry guards specifically in their NON-nested, NON-guest shape -- but this
# suite is itself one of gate 8's own discovered suites, which gate 8's own run-all.sh runs
# with RUN_ALL_NESTED=1 (and, transitively, VERIFY_DEPLOY_NESTED=1/GATE_MUTEX_HELD) already
# exported. Those three vars are plain exported shell variables, inherited by every child
# process unless explicitly cleared -- left inherited, every verify-deploy.sh/run-all.sh
# subprocess THIS suite spawns would silently run in nested/guest mode, exempting it from the
# very guard these cases exist to exercise (a nested/guest call is BY DESIGN never refused), and
# every rc/output assertion below would fail not because of a real defect but because this
# suite was itself discovered and run nested. Measured live: this suite passed 20/0 standalone
# but failed within gate 8's own real battery, every time, until this fix. Mirrors
# test-deploy-verify-wiring.sh's own documented "ANTI-RECURSION INVARIANT" precedent for the
# identical class of hazard.
unset RUN_ALL_NESTED VERIFY_DEPLOY_NESTED GATE_MUTEX_HELD

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
SRC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB="$SRC_DIR/lib/batch-gate-marker-lib.sh"

if [ ! -f "$LIB" ]; then
  echo "ERROR: expected $LIB" >&2
  exit 2
fi
# shellcheck source=../lib/batch-gate-marker-lib.sh
source "$LIB"

PASSED=0
FAILED=0

common_test_workdir_init
TMPROOT="$WORKDIR"
mkdir -p "$TMPROOT/specs/.orchestration"

write_marker() {
  # Usage: write_marker <session_id> <written_at_iso> [extra jq filter applied to the base object]
  local sid="$1" wa="$2"
  jq -n -c --arg sid "$sid" --argjson pid 999 --arg wa "$wa" --argjson tn '[1]' --argjson ds '{"1": 1}' \
    '{session_id: $sid, pid: $pid, written_at: $wa, task_numbers: $tn, dispatch_seq: $ds}' \
    > "$(batch_gate_marker_path "$TMPROOT" "$sid")"
}

iso_minutes_ago() {
  date -u -d "@$(( $(date -u +%s) - ($1 * 60) ))" +%Y-%m-%dT%H:%M:%SZ
}

# ─── Case 1: path construction ────────────────────────────────────────────────────────────
expected_path="$TMPROOT/specs/.orchestration/batch-gate-pending-sess_abc.json"
got_path="$(batch_gate_marker_path "$TMPROOT" "sess_abc")"
if [ "$got_path" = "$expected_path" ]; then
  common_test_pass "Case 1: batch_gate_marker_path builds the documented path convention"
else
  common_test_fail "Case 1: expected '$expected_path', got '$got_path'"
fi

# ─── Case 2: a fresh marker is pending ────────────────────────────────────────────────────
rm -f "$TMPROOT/specs/.orchestration"/batch-gate-pending-*.json
write_marker "sess_fresh" "$(iso_minutes_ago 1)"
if batch_gate_marker_is_pending "$TMPROOT"; then
  common_test_pass "Case 2: a 1-minute-old marker is pending (well under the default staleness window)"
else
  common_test_fail "Case 2: a fresh marker was not reported pending"
fi
age="$(batch_gate_marker_age_sec "$(batch_gate_marker_path "$TMPROOT" "sess_fresh")")"
if [ -n "$age" ] && [ "$age" -ge 55 ] && [ "$age" -le 120 ]; then
  common_test_pass "Case 2: batch_gate_marker_age_sec reports a plausible age (${age}s for a 1-minute-old marker)"
else
  common_test_fail "Case 2: implausible age reported: '$age'"
fi

# ─── Case 3: a stale marker (older than the window) is ignored ───────────────────────────
rm -f "$TMPROOT/specs/.orchestration"/batch-gate-pending-*.json
write_marker "sess_stale" "$(iso_minutes_ago $(( (BATCH_GATE_MARKER_STALE_SEC / 60) + 10 )))"
if batch_gate_marker_is_pending "$TMPROOT"; then
  common_test_fail "Case 3: a marker older than the staleness window was wrongly reported pending"
else
  common_test_pass "Case 3: a marker older than the staleness window (${BATCH_GATE_MARKER_STALE_SEC}s) is ignored"
fi
warning_out="$(batch_gate_marker_pending_warning "$TMPROOT")"
if echo "$warning_out" | grep -q "WARNING.*stale\|WARNING.*ignored"; then
  common_test_pass "Case 3: a loud, named warning is printed for the stale marker"
else
  common_test_fail "Case 3: expected a loud warning for the stale marker, got: '$warning_out'"
fi

# ─── Case 4: an exactly-at-threshold marker is treated as stale (strict less-than freshness) -
rm -f "$TMPROOT/specs/.orchestration"/batch-gate-pending-*.json
write_marker "sess_boundary" "$(iso_minutes_ago $(( BATCH_GATE_MARKER_STALE_SEC / 60 )))"
if batch_gate_marker_is_pending "$TMPROOT"; then
  common_test_fail "Case 4: a marker at (or past) the exact staleness boundary was wrongly reported pending"
else
  common_test_pass "Case 4: a marker at the staleness boundary is treated as stale (strict <, never <=)"
fi

# ─── Case 5: fail-open on malformed input (missing written_at, unparseable timestamp, absent
# file) -- never treated as fresh/pending. ────────────────────────────────────────────────
rm -f "$TMPROOT/specs/.orchestration"/batch-gate-pending-*.json
jq -n -c --arg sid "sess_malformed" --argjson pid 1 '{session_id: $sid, pid: $pid}' \
  > "$(batch_gate_marker_path "$TMPROOT" "sess_malformed")"
if batch_gate_marker_is_pending "$TMPROOT"; then
  common_test_fail "Case 5: a marker with no written_at was wrongly reported pending"
else
  common_test_pass "Case 5: a marker missing written_at degrades to stale (fail-open)"
fi
age_missing="$(batch_gate_marker_age_sec "$(batch_gate_marker_path "$TMPROOT" "sess_malformed")")"
if [ -z "$age_missing" ]; then
  common_test_pass "Case 5: batch_gate_marker_age_sec returns empty for a marker missing written_at"
else
  common_test_fail "Case 5: expected empty age for a malformed marker, got '$age_missing'"
fi
age_absent="$(batch_gate_marker_age_sec "$TMPROOT/specs/.orchestration/batch-gate-pending-does-not-exist.json")"
if [ -z "$age_absent" ]; then
  common_test_pass "Case 5: batch_gate_marker_age_sec returns empty for a nonexistent marker file"
else
  common_test_fail "Case 5: expected empty age for a nonexistent marker, got '$age_absent'"
fi
rm -f "$TMPROOT/specs/.orchestration"/batch-gate-pending-*.json
if batch_gate_marker_is_pending "$TMPROOT"; then
  common_test_fail "Case 5: no markers at all was wrongly reported pending"
else
  common_test_pass "Case 5: no markers at all is correctly reported not-pending"
fi

# ─── Case 6: multiple markers -- ANY non-stale marker makes the predicate pending ──────────
rm -f "$TMPROOT/specs/.orchestration"/batch-gate-pending-*.json
write_marker "sess_multi_stale" "$(iso_minutes_ago $(( (BATCH_GATE_MARKER_STALE_SEC / 60) + 10 )))"
write_marker "sess_multi_fresh" "$(iso_minutes_ago 1)"
if batch_gate_marker_is_pending "$TMPROOT"; then
  common_test_pass "Case 6: a mix of one stale and one fresh marker is reported pending (the fresh one governs)"
else
  common_test_fail "Case 6: a fresh marker among a stale one was not reported pending"
fi
rm -f "$TMPROOT/specs/.orchestration"/batch-gate-pending-*.json

rm -f "$TMPROOT/specs/.orchestration"/batch-gate-pending-*.json

# ═══════════════════════════════════════════════════════════════════════════════════════════
# PHASE 5 CASES: the entry guards in verify-deploy.sh and run-all.sh -- the consumer half of
# the marker this suite's own Cases 1-6 already prove correct at the library level.
#
# Invoked directly from their real source-store location (never copied): both scripts resolve
# their OWN collaborators (gate-registry-lib.sh, etc.) relative to their own script directory,
# which is unaffected by TARGET -- only the files THIS guard itself reads
# (batch-gate-marker-lib.sh, the marker file) are resolved under the scratch TARGET passed as
# the positional argument, so a minimal scratch TARGET (a bare .claude/ dir plus a real copy of
# the lib at the documented nested path) is enough to reach and exercise the guard without a
# full rich fixture. The signal checked is deliberately narrow: exit status 3 and/or a
# "DEFERRED" line, never full gate correctness (irrelevant to what this guard decides).
# ═══════════════════════════════════════════════════════════════════════════════════════════
VERIFY_DEPLOY="$SRC_DIR/verify-deploy.sh"
RUN_ALL="$SRC_DIR/tests/run-all.sh"
for req in "$VERIFY_DEPLOY" "$RUN_ALL"; do
  if [ ! -f "$req" ]; then
    echo "ERROR: expected $req" >&2
    exit 2
  fi
done

TMPTARGET="$(mktemp -d "${TMPDIR:-/tmp}/batch-gate-entry-guard-test.XXXXXX")"
cleanup_target() { [ -n "${TMPTARGET:-}" ] && [ -d "$TMPTARGET" ] && rm -rf "$TMPTARGET"; }
trap cleanup_target EXIT
mkdir -p "$TMPTARGET/.claude" "$TMPTARGET/specs/.orchestration" \
         "$TMPTARGET/agent-system/extensions/core/scripts/lib" \
         "$TMPTARGET/agent-system/extensions/core/scripts/tests"
cp "$LIB" "$TMPTARGET/agent-system/extensions/core/scripts/lib/batch-gate-marker-lib.sh"
# A throwaway, path-mirrored copy of run-all.sh, resolved entirely under TMPTARGET -- NEVER the
# real repo's own specs/.orchestration/. A fixed-name marker in the REAL repo's own
# specs/.orchestration/ (an earlier draft of this suite) was measured live to leak under a
# SIGKILL-bypassed-trap condition (run-all.sh's own per-suite timeout, under extreme host load,
# kills a slow suite before its EXIT trap can fire) -- a $$-unique filename closes the race
# between two CONCURRENT instances of this same suite, but a kill-before-cleanup can still leak
# a file into shared, production state; an isolated TMPTARGET has no such consequence. A bare
# `: > manifest.json` is enough to satisfy run-all.sh's own source-store MODE detection (it only
# checks the file's existence, never its content).
: > "$TMPTARGET/agent-system/extensions/core/manifest.json"
cp "$RUN_ALL" "$TMPTARGET/agent-system/extensions/core/scripts/tests/run-all.sh"
RUN_ALL_FIXTURE="$TMPTARGET/agent-system/extensions/core/scripts/tests/run-all.sh"
# A single trivial suite, so run-all.sh's own discovery is non-empty (TOTAL_DISCOVERED > 0) --
# with zero discovered suites it refuses with its own "zero test suites discovered" harness
# error (exit 2) BEFORE ever reaching the entry guard this case means to exercise. The guard
# fires before any suite runs regardless, so this stub's own content is never executed.
printf '#!/usr/bin/env bash\nexit 0\n' > "$TMPTARGET/agent-system/extensions/core/scripts/tests/test-stub.sh"
chmod +x "$TMPTARGET/agent-system/extensions/core/scripts/tests/test-stub.sh"

write_target_marker() {
  # Usage: write_target_marker <session_id> <written_at_iso>
  jq -n -c --arg sid "$1" --argjson pid 42 --arg wa "$2" --argjson tn '[1]' --argjson ds '{"1": 1}' \
    '{session_id: $sid, pid: $pid, written_at: $wa, task_numbers: $tn, dispatch_seq: $ds}' \
    > "$TMPTARGET/specs/.orchestration/batch-gate-pending-$1.json"
}
clear_target_markers() { rm -f "$TMPTARGET/specs/.orchestration"/batch-gate-pending-*.json; }

# ─── Case 7: an unfiltered call is refused with the reserved status (exit 3) while a
# non-stale marker is pending -- both verify-deploy.sh and run-all.sh. ──────────────────────
clear_target_markers
write_target_marker "sess_vd_refuse" "$(iso_minutes_ago 1)"
vd_out="$(bash "$VERIFY_DEPLOY" --quiet "$TMPTARGET" 2>&1)"; vd_rc=$?
if [ "$vd_rc" -eq 3 ] && echo "$vd_out" | grep -q "DEFERRED"; then
  common_test_pass "Case 7: verify-deploy.sh unfiltered + pending marker -> exit 3 with a DEFERRED line"
else
  common_test_fail "Case 7: verify-deploy.sh expected exit 3 + DEFERRED, got rc=$vd_rc: $vd_out"
fi
# run-all.sh's guard check: run against RUN_ALL_FIXTURE (the throwaway, path-mirrored copy
# under TMPTARGET -- see its own setup comment above for why this is NEVER the real repo). Its
# own repo-root resolution lands on TMPTARGET, the SAME tree write_target_marker/
# clear_target_markers already manage for the verify-deploy.sh cases above, so no separate
# marker-management code is needed here at all.
ra_out="$(bash "$RUN_ALL_FIXTURE" --quiet 2>&1)"; ra_rc=$?
if [ "$ra_rc" -eq 3 ] && echo "$ra_out" | grep -q "DEFERRED"; then
  common_test_pass "Case 7: run-all.sh unfiltered + pending marker -> exit 3 with a DEFERRED line"
else
  common_test_fail "Case 7: run-all.sh expected exit 3 + DEFERRED, got rc=$ra_rc: $ra_out"
fi

# ─── Case 8: a scoped call (--only-gate / --only) is never refused, marker or not. ──────────
clear_target_markers
write_target_marker "sess_vd_scoped" "$(iso_minutes_ago 1)"
vd_scoped_out="$(bash "$VERIFY_DEPLOY" --only-gate 1 --quiet "$TMPTARGET" 2>&1)"; vd_scoped_rc=$?
if [ "$vd_scoped_rc" -ne 3 ] && ! echo "$vd_scoped_out" | grep -q "DEFERRED"; then
  common_test_pass "Case 8: verify-deploy.sh --only-gate is never refused by the entry guard"
else
  common_test_fail "Case 8: verify-deploy.sh --only-gate was wrongly refused (rc=$vd_scoped_rc): $vd_scoped_out"
fi

# ─── Case 9: a nested invocation is unaffected (byte-identical guard path) regardless of a
# pending marker. ─────────────────────────────────────────────────────────────────────────
clear_target_markers
write_target_marker "sess_vd_nested" "$(iso_minutes_ago 1)"
vd_nested_out="$(VERIFY_DEPLOY_NESTED=1 bash "$VERIFY_DEPLOY" --quiet "$TMPTARGET" 2>&1)"; vd_nested_rc=$?
if [ "$vd_nested_rc" -ne 3 ] && ! echo "$vd_nested_out" | grep -q "DEFERRED"; then
  common_test_pass "Case 9: verify-deploy.sh a nested invocation is never refused by the entry guard"
else
  common_test_fail "Case 9: verify-deploy.sh nested invocation was wrongly refused (rc=$vd_nested_rc): $vd_nested_out"
fi

# ─── Case 10: a guest invocation (GATE_MUTEX_HELD inherited) is unaffected regardless of a
# pending marker. ─────────────────────────────────────────────────────────────────────────
clear_target_markers
write_target_marker "sess_vd_guest" "$(iso_minutes_ago 1)"
vd_guest_out="$(GATE_MUTEX_HELD=1 bash "$VERIFY_DEPLOY" --quiet "$TMPTARGET" 2>&1)"; vd_guest_rc=$?
if [ "$vd_guest_rc" -ne 3 ] && ! echo "$vd_guest_out" | grep -q "DEFERRED"; then
  common_test_pass "Case 10: verify-deploy.sh a guest invocation is never refused by the entry guard"
else
  common_test_fail "Case 10: verify-deploy.sh guest invocation was wrongly refused (rc=$vd_guest_rc): $vd_guest_out"
fi

# ─── Case 11: a stale marker is ignored (never refused), with a loud named warning. ──────────
clear_target_markers
write_target_marker "sess_vd_stale" "$(iso_minutes_ago $(( (BATCH_GATE_MARKER_STALE_SEC / 60) + 10 )))"
vd_stale_out="$(bash "$VERIFY_DEPLOY" --quiet "$TMPTARGET" 2>&1)"; vd_stale_rc=$?
if [ "$vd_stale_rc" -ne 3 ] && ! echo "$vd_stale_out" | grep -q "DEFERRED"; then
  common_test_pass "Case 11: verify-deploy.sh a stale marker is never refused"
else
  common_test_fail "Case 11: verify-deploy.sh stale marker was wrongly refused (rc=$vd_stale_rc): $vd_stale_out"
fi
if echo "$vd_stale_out" | grep -qi "WARNING.*ignored\|WARNING.*stale"; then
  common_test_pass "Case 11: verify-deploy.sh prints a loud named warning for the ignored stale marker"
else
  common_test_fail "Case 11: verify-deploy.sh expected a loud stale-marker warning, got: $vd_stale_out"
fi

# ─── Case 12: --override-batch-gate-deferral is honored even with a fresh, pending marker. ──
clear_target_markers
write_target_marker "sess_vd_override" "$(iso_minutes_ago 1)"
vd_override_out="$(bash "$VERIFY_DEPLOY" --override-batch-gate-deferral --quiet "$TMPTARGET" 2>&1)"; vd_override_rc=$?
if [ "$vd_override_rc" -ne 3 ] && ! echo "$vd_override_out" | grep -q "DEFERRED"; then
  common_test_pass "Case 12: verify-deploy.sh --override-batch-gate-deferral is honored despite a pending marker"
else
  common_test_fail "Case 12: verify-deploy.sh override was wrongly refused (rc=$vd_override_rc): $vd_override_out"
fi

# ─── Case 13: an absent marker leaves output byte-identical to today's (never refused). ─────
clear_target_markers
vd_absent_out="$(bash "$VERIFY_DEPLOY" --quiet "$TMPTARGET" 2>&1)"; vd_absent_rc=$?
if [ "$vd_absent_rc" -ne 3 ] && ! echo "$vd_absent_out" | grep -q "DEFERRED"; then
  common_test_pass "Case 13: verify-deploy.sh an absent marker is never refused"
else
  common_test_fail "Case 13: verify-deploy.sh absent-marker case was wrongly refused (rc=$vd_absent_rc): $vd_absent_out"
fi
clear_target_markers

echo ""
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
