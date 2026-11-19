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

echo ""
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
