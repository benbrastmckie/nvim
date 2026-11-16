#!/usr/bin/env bash
# test-orchestrate-conclusion-backstop.sh - Regression suite for
# hooks/orchestrate-conclusion-backstop.sh, the Stop-hook backstop that blocks a session's stop
# while /orchestrate's Move 5 conclusion stage has not yet run (context/contracts/
# conclusion-stage.md).
#
# Structural model: test-subagent-postflight-marker.sh's SCRIPT_DIR-relative hook path (resolves
# in both source-store and deployed layouts with no branching: scripts/tests/../../hooks/ ==
# core/hooks/ or .claude/hooks/), pass()/fail()/info() helpers, PASSED/FAILED counters,
# mktemp -d fixtures with trap cleanup EXIT, exit 0 all-pass / 1 any-fail. The hook under test
# has no dependency on deploy-root-guard.sh or lib/common.sh (plain bash + jq, reading
# specs/.orchestration/ relative to cwd), so every case runs the hook directly, in place, as a
# real subprocess -- no scratch sandbox tree needed beyond a disposable cwd.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
# Resolves to agent-system/extensions/core/hooks/ in source-store mode and .claude/hooks/ in
# deployed mode, with no branching.
HOOK="$SCRIPT_DIR/../../hooks/orchestrate-conclusion-backstop.sh"

if [ ! -f "$HOOK" ]; then
  echo "ERROR: expected file not found at $HOOK" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required to build fixtures and is not on PATH" >&2
  exit 1
fi

PASSED=0
FAILED=0

common_test_workdir_init

# make_fixture -- a fresh scratch dir with specs/.orchestration/ (no marker yet). Echoes the dir.
make_fixture() {
  local d
  d="$(mktemp -d -p "$WORKDIR")"
  mkdir -p "$d/specs/.orchestration"
  echo "$d"
}

# write_marker <fixture_dir> <session_id> <cc_session_id> <continuation_count>
write_marker() {
  local d="$1" sid="$2" ccsid="$3" count="$4"
  jq -n --arg sid "$sid" --arg ccsid "$ccsid" --argjson c "$count" \
    '{session_id: $sid, cc_session_id: $ccsid, continuation_count: $c, created_ts: "2026-01-01T00:00:00Z"}' \
    > "$d/specs/.orchestration/.conclusion-pending-${sid}.json"
}

# run_hook <fixture_dir> <cc_sid_on_stdin> [stop_hook_active_bool] -- runs the hook as a real
# subprocess with cwd set to <fixture_dir>, piping a synthetic Stop-event payload. Echoes stdout.
run_hook() {
  local d="$1" cc_sid="$2" sha="${3:-false}"
  ( cd "$d" && jq -n --arg sid "$cc_sid" --argjson sha "$sha" '{session_id: $sid, stop_hook_active: $sha}' | bash "$HOOK" 2>/dev/null )
}

# =====================================================================================
# Case 1: no matching marker -- prints {} and exits 0.
# =====================================================================================
d1="$(make_fixture)"
out1="$(run_hook "$d1" "cc-nomatch")"
rc1=$?
rm -rf "$d1"
if [ "$rc1" -eq 0 ] && [ "$out1" = "{}" ]; then
  common_test_pass "Case 1: no matching marker prints {} and exits 0"
else
  common_test_fail "Case 1: expected {} and exit 0, got rc=$rc1 out=$out1"
fi

# =====================================================================================
# Case 2: a matching marker blocks on stdout with exit 0, and its continuation_count is
# incremented in place.
# =====================================================================================
d2="$(make_fixture)"
write_marker "$d2" "sess_case2" "cc-case2" 0
out2="$(run_hook "$d2" "cc-case2")"
rc2=$?
marker2_count="$(jq -r '.continuation_count' "$d2/specs/.orchestration/.conclusion-pending-sess_case2.json" 2>/dev/null)"
rm -rf "$d2"
if [ "$rc2" -eq 0 ] && echo "$out2" | jq -e '.decision == "block"' >/dev/null 2>&1; then
  common_test_pass "Case 2: a matching marker blocks on stdout with exit 0"
else
  common_test_fail "Case 2: expected a block decision, got rc=$rc2 out=$out2"
fi
if echo "$out2" | jq -e '.reason | contains("conclusion-stage.md")' >/dev/null 2>&1; then
  common_test_pass "Case 2: the block reason names the contract path"
else
  common_test_fail "Case 2: expected the block reason to name conclusion-stage.md, got: $out2"
fi
if [ "$marker2_count" = "1" ]; then
  common_test_pass "Case 2: the marker's own continuation_count is incremented to 1"
else
  common_test_fail "Case 2: expected continuation_count=1 after one block, got: $marker2_count"
fi

# =====================================================================================
# Case 3: a mismatched cc_session_id does not block -- the foreign marker is never selected,
# and it is left completely untouched (no increment, no delete).
# =====================================================================================
d3="$(make_fixture)"
write_marker "$d3" "sess_case3" "cc-case3-real" 0
out3="$(run_hook "$d3" "cc-case3-mismatch")"
rc3=$?
marker3_after="$(cat "$d3/specs/.orchestration/.conclusion-pending-sess_case3.json" 2>/dev/null)"
rm -rf "$d3"
if [ "$rc3" -eq 0 ] && [ "$out3" = "{}" ]; then
  common_test_pass "Case 3: a mismatched cc_session_id does not block"
else
  common_test_fail "Case 3: expected {} for a mismatched session, got rc=$rc3 out=$out3"
fi
if echo "$marker3_after" | jq -e '.continuation_count == 0' >/dev/null 2>&1; then
  common_test_pass "Case 3: the foreign marker is left untouched (continuation_count still 0)"
else
  common_test_fail "Case 3: expected the foreign marker's continuation_count to stay 0, got: $marker3_after"
fi

# =====================================================================================
# Case 4: the MAX_CONTINUATIONS cap deletes the marker and stops blocking once reached.
# =====================================================================================
d4="$(make_fixture)"
write_marker "$d4" "sess_case4" "cc-case4" 3
out4="$(run_hook "$d4" "cc-case4")"
rc4=$?
marker4_exists=0
[ -f "$d4/specs/.orchestration/.conclusion-pending-sess_case4.json" ] && marker4_exists=1
rm -rf "$d4"
if [ "$rc4" -eq 0 ] && [ "$out4" = "{}" ]; then
  common_test_pass "Case 4: a marker at the MAX_CONTINUATIONS cap returns {} (stops blocking)"
else
  common_test_fail "Case 4: expected {} once the cap is reached, got rc=$rc4 out=$out4"
fi
if [ "$marker4_exists" -eq 0 ]; then
  common_test_pass "Case 4: the capped-out marker is deleted"
else
  common_test_fail "Case 4: expected the capped-out marker to be deleted"
fi

# =====================================================================================
# Case 5: stop_hook_active escapes -- {} is returned and the marker is left completely
# untouched, even though it would otherwise match and block.
# =====================================================================================
d5="$(make_fixture)"
write_marker "$d5" "sess_case5" "cc-case5" 0
out5="$(run_hook "$d5" "cc-case5" "true")"
rc5=$?
marker5_after="$(cat "$d5/specs/.orchestration/.conclusion-pending-sess_case5.json" 2>/dev/null)"
rm -rf "$d5"
if [ "$rc5" -eq 0 ] && [ "$out5" = "{}" ]; then
  common_test_pass "Case 5: stop_hook_active: true escapes with {}"
else
  common_test_fail "Case 5: expected {} under stop_hook_active, got rc=$rc5 out=$out5"
fi
if echo "$marker5_after" | jq -e '.continuation_count == 0' >/dev/null 2>&1; then
  common_test_pass "Case 5: the stop_hook_active escape never inspects or mutates the marker"
else
  common_test_fail "Case 5: expected the marker to stay untouched under stop_hook_active, got: $marker5_after"
fi

echo ""
echo "========================================"
echo "test-orchestrate-conclusion-backstop.sh Summary"
echo "========================================"
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
