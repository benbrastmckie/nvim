#!/usr/bin/env bash
# test-subagent-postflight-marker.sh - Fixture-driven regression suite for the
# malformed-postflight-marker fix: subagent-postflight.sh's diagnosable block reason and
# events-log-lifecycle.sh's deviation-event telemetry, both guarded by `jq empty` against a
# marker that fails to parse as JSON.
#
# Structural model: test-guard-destructive-git.sh's SCRIPT_DIR-relative hook path (resolves in
# both source-store and deployed layouts with no branching), pass()/fail()/info() helpers,
# PASSED/FAILED counters, mktemp -d fixtures with trap cleanup EXIT, exit 0 all-pass / 1 any-fail.
#
# subagent-postflight.sh has no dependency on its own script-path depth (it locates markers via
# `find specs ...` against cwd), so its cases run the source-store or deployed hook directly, in
# place, as a real subprocess -- exactly like test-guard-destructive-git.sh does.
#
# events-log-lifecycle.sh is different: events-append.sh (which it shells out to) resolves its
# write target via `deploy-root-guard.sh` + a script-path-depth calculation that (a) REFUSES to
# run at all from a source-store path (deploy-root-guard.sh requires the immediate parent
# directory to be named `.claude` or `.opencode`) and (b) even when deployed, always resolves to
# THIS repo's real specs/events.jsonl regardless of the subprocess's cwd -- there is no way to
# redirect it via cwd alone. Driving it in place would therefore either hard-fail outside a
# deployed tree, or (if deployed) silently append test rows into the real events store. The
# events companion case instead builds an ISOLATED copy of the four files it needs
# (events-log-lifecycle.sh, events-append.sh, deploy-root-guard.sh, lib/common.sh) under a fresh
# mktemp -d tree shaped as <tmp>/.claude/{hooks,scripts,scripts/lib}/ with <tmp>/specs/ as a
# sibling -- satisfying deploy-root-guard.sh's parent-name check while anchoring
# events-append.sh's root resolution entirely inside the disposable fixture, never touching the
# real repo's specs/events.jsonl.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
# This single relative path resolves to agent-system/extensions/core/hooks/ in source-store mode
# and to .claude/hooks/ in deployed mode, with no branching -- see plan Phase 1/3.
POSTFLIGHT_HOOK="$SCRIPT_DIR/../../hooks/subagent-postflight.sh"
# Source-of-copy paths for the isolated events-companion fixture (see header comment above).
EVENTS_HOOK_SRC="$SCRIPT_DIR/../../hooks/events-log-lifecycle.sh"
EVENTS_APPEND_SRC="$SCRIPT_DIR/../events-append.sh"
DEPLOY_ROOT_GUARD_SRC="$SCRIPT_DIR/../deploy-root-guard.sh"
COMMON_LIB_SRC="$SCRIPT_DIR/../lib/common.sh"

PASSED=0
FAILED=0


for f in "$POSTFLIGHT_HOOK" "$EVENTS_HOOK_SRC" "$EVENTS_APPEND_SRC" "$DEPLOY_ROOT_GUARD_SRC" "$COMMON_LIB_SRC"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: expected file not found at $f" >&2
    exit 1
  fi
done

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required to build fixtures and is not on PATH" >&2
  exit 1
fi

common_test_workdir_init

# =====================================================================
# subagent-postflight.sh fixtures
# =====================================================================

# make_postflight_fixture <task_num> -- creates a fresh scratch dir with an empty
# specs/<task_num>_test/ task directory (no marker yet). Echoes the fixture dir.
make_postflight_fixture() {
  local task_num="$1" d
  d="$(mktemp -d -p "$WORKDIR")"
  mkdir -p "$d/specs/${task_num}_test"
  echo "$d"
}

# run_postflight <fixture_dir> [cc_session_id] -- runs subagent-postflight.sh as a real
# subprocess with cwd set to <fixture_dir>, piping a synthetic SubagentStop payload whose
# top-level .session_id is <cc_session_id> (default "" when omitted). Mirrors run_events_hook's
# `jq -n | bash` construction below -- the hook now reads stdin for correlation (it used to read
# none at all), so every case must pipe an explicit payload rather than inheriting the harness's
# own stdin. Echoes stdout.
run_postflight() {
  local d="$1" cc_sid="${2:-}"
  ( cd "$d" && jq -n --arg sid "$cc_sid" '{session_id: $sid}' | bash "$POSTFLIGHT_HOOK" 2>/dev/null )
}

# =====================================================================
# Fixture self-check (MUST run first): a broken fixture must fail loudly rather than let every
# later case pass vacuously via the no-marker allow-stop path. The marker now carries a
# `cc_session_id` and the payload piped to the hook carries the matching `session_id` --
# omitting either would silently reroute this case onto the no-correlation {} path instead of
# the block branch it claims to exercise (a false pass, not a fix).
# =====================================================================
self_check_dir="$(make_postflight_fixture 901)"
echo '{"reason":"self-check reason","cc_session_id":"cc-self-check-901"}' > "$self_check_dir/specs/901_test/.postflight-pending"
self_check_out="$(run_postflight "$self_check_dir" "cc-self-check-901")"
rm -rf "$self_check_dir"
if echo "$self_check_out" | jq -e '.decision == "block"' >/dev/null 2>&1; then
  common_test_pass "fixture self-check: hook reaches the block branch for a correlated well-formed marker"
else
  common_test_fail "fixture self-check: expected a block decision, got: $self_check_out"
fi

# =====================================================================
# Case (a): well-formed, correlated marker with .reason present -> passthrough unchanged
# =====================================================================
d="$(make_postflight_fixture 902)"
echo '{"reason":"custom pending reason","cc_session_id":"cc-902"}' > "$d/specs/902_test/.postflight-pending"
out="$(run_postflight "$d" "cc-902")"
rm -rf "$d"
if echo "$out" | jq -e '.reason == "custom pending reason"' >/dev/null 2>&1; then
  common_test_pass "case (a): well-formed .reason passes through unchanged"
else
  common_test_fail "case (a): expected reason 'custom pending reason', got: $out"
fi

# =====================================================================
# Case (b): well-formed, correlated marker missing .reason -> default
# "Postflight operations pending" (AC 2)
# =====================================================================
d="$(make_postflight_fixture 903)"
echo '{"cc_session_id":"cc-903"}' > "$d/specs/903_test/.postflight-pending"
out="$(run_postflight "$d" "cc-903")"
rm -rf "$d"
if echo "$out" | jq -e '.reason == "Postflight operations pending"' >/dev/null 2>&1; then
  common_test_pass "case (b): missing .reason falls back to the default (AC 2)"
else
  common_test_fail "case (b): expected default reason, got: $out"
fi

# =====================================================================
# Case (c): non-JSON (key=value shaped) marker -> its `cc_session_id` is unreadable, so
# find_marker() can never correlate it (see subagent-postflight.sh header comment) and it is
# skipped rather than selected. This is a deliberate behavior change from the pre-correlation
# fix: this hook no longer surfaces a diagnosable parse-failure block reason for an uncorrelated
# malformed marker -- that observability now lives in events-log-lifecycle.sh's
# `malformed_postflight_marker` deviation event (see the events companion cases below), which is
# not gated on correlation because it derives session_id from specs/state.json rather than from
# the marker. Assert the fail-safe holds: {} stdout (no block, no arbitrary pick) and the
# malformed marker left byte-identical on disk.
# =====================================================================
d="$(make_postflight_fixture 904)"
printf 'session_id=sess_1\nskill=foo\noperation=bar\n' > "$d/specs/904_test/.postflight-pending"
before_c="$(cat "$d/specs/904_test/.postflight-pending")"
out="$(run_postflight "$d" "cc-904-does-not-matter")"
after_c="$(cat "$d/specs/904_test/.postflight-pending" 2>/dev/null)"
rm -rf "$d"
if [ "$out" = "{}" ]; then
  common_test_pass "case (c): an uncorrelatable (non-JSON) marker is never selected -- fail-safe {} (AC 1, revised)"
else
  common_test_fail "case (c): expected {} for an uncorrelatable malformed marker, got: $out"
fi
if [ "$before_c" = "$after_c" ]; then
  common_test_pass "case (c): the malformed marker is left byte-identical on disk (not deleted, not mutated)"
else
  common_test_fail "case (c): malformed marker was mutated or removed -- before=[$before_c] after=[$after_c]"
fi

# =====================================================================
# Case (d): .reason containing a double quote, a backslash, and a literal newline, on a
# correlated marker -> stdout passes jq empty and .reason round-trips to the original string
# (AC 3)
# =====================================================================
d="$(make_postflight_fixture 905)"
jq -n '{reason: "line one\nwith \"quotes\" and \\backslash", cc_session_id: "cc-905"}' > "$d/specs/905_test/.postflight-pending"
out="$(run_postflight "$d" "cc-905")"
rm -rf "$d"
if ! echo "$out" | jq empty >/dev/null 2>&1; then
  common_test_fail "case (d): stdout is not valid JSON: $out"
else
  roundtrip="$(echo "$out" | jq -r '.reason')"
  expected="$(printf 'line one\nwith "quotes" and \\backslash')"
  if [ "$roundtrip" = "$expected" ]; then
    common_test_pass "case (d): quote/backslash/newline reason round-trips through valid JSON (AC 3)"
  else
    common_test_fail "case (d): round-trip mismatch. Expected: $(printf '%q' "$expected") Got: $(printf '%q' "$roundtrip")"
  fi
fi

# =====================================================================
# Case (e): loop-guard interaction with an uncorrelatable malformed marker -- since find_marker()
# never selects it (case (c) above), MARKER_FILE/LOOP_GUARD_FILE stay unset and main() takes the
# "no marker" path directly, never reaching check_loop_guard() at all. stdout is still {} (stop
# allowed), but -- unlike the pre-correlation fix -- the malformed marker and the pre-existing
# loop-guard file are both now left untouched rather than reset/deleted, because this hook never
# selected them as its own.
# =====================================================================
d="$(make_postflight_fixture 906)"
printf 'not=json\n' > "$d/specs/906_test/.postflight-pending"
echo "3" > "$d/specs/906_test/.postflight-loop-guard"
out="$(run_postflight "$d" "cc-906-does-not-matter")"
guard_survived=0
marker_survived=0
[ -f "$d/specs/906_test/.postflight-loop-guard" ] && guard_survived=1
[ -f "$d/specs/906_test/.postflight-pending" ] && marker_survived=1
rm -rf "$d"
if [ "$out" = "{}" ]; then
  common_test_pass "case (e): an uncorrelatable malformed marker with a pre-existing loop guard still allows the stop"
else
  common_test_fail "case (e): expected {} (stop allowed), got: $out"
fi
if [ "$guard_survived" = "1" ] && [ "$marker_survived" = "1" ]; then
  common_test_pass "case (e): neither the malformed marker nor its loop guard is touched by a session that cannot correlate it"
else
  common_test_fail "case (e): expected both the malformed marker and its loop guard to survive untouched (guard_survived=$guard_survived marker_survived=$marker_survived)"
fi

# =====================================================================
# Case (f): cross-session correlation -- two task dirs, two markers, two distinct
# `cc_session_id` values, payload matching one. The block decision must come from the matched
# marker, the foreign marker must be untouched, and no loop guard may be created in the foreign
# task dir (AC -- correlated selection / ownership).
# =====================================================================
d="$(mktemp -d -p "$WORKDIR")"
mkdir -p "$d/specs/950_owned" "$d/specs/951_foreign"
jq -n '{cc_session_id:"cc-owned-950",session_id:"sess_owned_950",skill:"skill-a",task_number:950,operation:"implement",reason:"owned reason",created:"2026-01-01T00:00:00Z",stop_hook_active:false}' \
  > "$d/specs/950_owned/.postflight-pending"
jq -n '{cc_session_id:"cc-foreign-951",session_id:"sess_foreign_951",skill:"skill-b",task_number:951,operation:"implement",reason:"foreign reason",created:"2026-01-01T00:00:00Z",stop_hook_active:false}' \
  > "$d/specs/951_foreign/.postflight-pending"
foreign_before_f="$(cat "$d/specs/951_foreign/.postflight-pending")"
out="$(run_postflight "$d" "cc-owned-950")"
foreign_after_f="$(cat "$d/specs/951_foreign/.postflight-pending" 2>/dev/null)"
foreign_guard_created_f=0
[ -f "$d/specs/951_foreign/.postflight-loop-guard" ] && foreign_guard_created_f=1
rm -rf "$d"
if echo "$out" | jq -e '.decision == "block" and .reason == "owned reason"' >/dev/null 2>&1; then
  common_test_pass "case (f): block decision comes from the correlated marker, not the foreign one"
else
  common_test_fail "case (f): expected block decision with reason 'owned reason', got: $out"
fi
if [ "$foreign_before_f" = "$foreign_after_f" ]; then
  common_test_pass "case (f): the foreign marker is byte-identical after the run"
else
  common_test_fail "case (f): the foreign marker was mutated -- before=[$foreign_before_f] after=[$foreign_after_f]"
fi
if [ "$foreign_guard_created_f" = "0" ]; then
  common_test_pass "case (f): no loop guard was created in the foreign task dir"
else
  common_test_fail "case (f): a loop guard was unexpectedly created in the foreign task dir"
fi

# =====================================================================
# Case (g): cap-reached deletion with a foreign marker present -- driving the correlated
# session's loop guard to MAX_CONTINUATIONS must delete only the correlated marker and its own
# loop guard; the foreign marker must survive (AC -- deletion provenance / ownership).
# =====================================================================
d="$(mktemp -d -p "$WORKDIR")"
mkdir -p "$d/specs/952_owned" "$d/specs/953_foreign"
jq -n '{cc_session_id:"cc-owned-952",session_id:"sess_owned_952",skill:"skill-a",task_number:952,operation:"implement",reason:"owned reason",created:"2026-01-01T00:00:00Z",stop_hook_active:false}' \
  > "$d/specs/952_owned/.postflight-pending"
echo "3" > "$d/specs/952_owned/.postflight-loop-guard"
jq -n '{cc_session_id:"cc-foreign-953",session_id:"sess_foreign_953",skill:"skill-b",task_number:953,operation:"implement",reason:"foreign reason",created:"2026-01-01T00:00:00Z",stop_hook_active:false}' \
  > "$d/specs/953_foreign/.postflight-pending"
out="$(run_postflight "$d" "cc-owned-952")"
owned_marker_survived_g=0
owned_guard_survived_g=0
foreign_survived_g=0
[ -f "$d/specs/952_owned/.postflight-pending" ] && owned_marker_survived_g=1
[ -f "$d/specs/952_owned/.postflight-loop-guard" ] && owned_guard_survived_g=1
[ -f "$d/specs/953_foreign/.postflight-pending" ] && foreign_survived_g=1
cap_line_g="$(grep -c 'CAP-REACHED DELETE:' "$d/.agent-logs/subagent-postflight.log" 2>/dev/null || echo 0)"
rm -rf "$d"
if [ "$out" = "{}" ] && [ "$owned_marker_survived_g" = "0" ] && [ "$owned_guard_survived_g" = "0" ]; then
  common_test_pass "case (g): the correlated marker and its loop guard are deleted at the cap"
else
  common_test_fail "case (g): expected the correlated marker+guard to be deleted at the cap, got out=$out owned_marker_survived=$owned_marker_survived_g owned_guard_survived=$owned_guard_survived_g"
fi
if [ "$foreign_survived_g" = "1" ]; then
  common_test_pass "case (g): the foreign marker survives the correlated session's cap-reached deletion"
else
  common_test_fail "case (g): the foreign marker was deleted by a cap-reached cleanup it does not own"
fi
if [ "$cap_line_g" = "1" ]; then
  common_test_pass "case (g): exactly one CAP-REACHED DELETE: line is logged"
else
  common_test_fail "case (g): expected exactly one CAP-REACHED DELETE: log line, got $cap_line_g"
fi

# =====================================================================
# Case (h): legacy marker with no `cc_session_id` key at all -- the fail-safe, asserted as
# intended behavior. {} on stdout, no block, marker untouched.
# =====================================================================
d="$(make_postflight_fixture 954)"
echo '{"reason":"legacy reason"}' > "$d/specs/954_test/.postflight-pending"
before_h="$(cat "$d/specs/954_test/.postflight-pending")"
out="$(run_postflight "$d" "cc-some-active-session")"
after_h="$(cat "$d/specs/954_test/.postflight-pending" 2>/dev/null)"
rm -rf "$d"
if [ "$out" = "{}" ]; then
  common_test_pass "case (h): a legacy marker with no cc_session_id key is never selected -- fail-safe {}"
else
  common_test_fail "case (h): expected {} for a legacy marker with no cc_session_id key, got: $out"
fi
if [ "$before_h" = "$after_h" ]; then
  common_test_pass "case (h): the legacy marker is left byte-identical on disk"
else
  common_test_fail "case (h): the legacy marker was mutated or removed -- before=[$before_h] after=[$after_h]"
fi

# =====================================================================
# events-log-lifecycle.sh companion case (AC 4): isolated deployed-layout fixture (see header
# comment) so events-append.sh's root resolution never touches the real repo's events.jsonl.
# =====================================================================

# make_events_fixture -- builds an isolated <tmp>/.claude/{hooks,scripts,scripts/lib}/ tree
# (copies of the four files under test) plus a sibling <tmp>/specs/ directory. Echoes the tmp
# root.
make_events_fixture() {
  local d
  d="$(mktemp -d -p "$WORKDIR")"
  mkdir -p "$d/.claude/hooks" "$d/.claude/scripts/lib" "$d/specs"
  cp "$EVENTS_HOOK_SRC" "$d/.claude/hooks/events-log-lifecycle.sh"
  cp "$EVENTS_APPEND_SRC" "$d/.claude/scripts/events-append.sh"
  cp "$DEPLOY_ROOT_GUARD_SRC" "$d/.claude/scripts/deploy-root-guard.sh"
  cp "$COMMON_LIB_SRC" "$d/.claude/scripts/lib/common.sh"
  chmod +x "$d/.claude/hooks/events-log-lifecycle.sh" "$d/.claude/scripts/events-append.sh" \
    "$d/.claude/scripts/deploy-root-guard.sh"
  echo "$d"
}

# run_events_hook <fixture_root> <agent_id> <cwd_field> <cc_session_id> -- runs the isolated
# copy of events-log-lifecycle.sh as a subprocess with cwd set to <fixture_root>, piping a
# synthetic SubagentStop payload. Echoes stdout.
run_events_hook() {
  local root="$1" agent_id="$2" cwd_field="$3" cc_sid="$4"
  ( cd "$root" && jq -n --arg aid "$agent_id" --arg cwd "$cwd_field" --arg sid "$cc_sid" \
      '{agent_id: $aid, cwd: $cwd, session_id: $sid}' \
    | bash "$root/.claude/hooks/events-log-lifecycle.sh" 2>/dev/null )
}

# --- Sub-case: malformed marker + matching specs/state.json entry -> exactly one deviation
# event with a valid session_id ---
events_root="$(make_events_fixture)"
mkdir -p "$events_root/specs/907_test"
printf 'session_id=sess_1\nskill=foo\n' > "$events_root/specs/907_test/.postflight-pending"
jq -n '{active_projects: [{project_number: 907, session_id: "sess_1_abcdef", task_type: "meta", status: "implementing"}]}' \
  > "$events_root/specs/state.json"
events_out="$(run_events_hook "$events_root" "agent1" "$events_root" "cc-uuid-1")"
event_count=0
if [ -f "$events_root/specs/events.jsonl" ]; then
  event_count="$(wc -l < "$events_root/specs/events.jsonl" | tr -d ' ')"
fi
if [ "$events_out" = "{}" ] && [ "$event_count" = "1" ] \
  && jq -e '.category == "deviation" and (.session_id | test("^sess_[0-9]+_[a-zA-Z0-9]+$")) and .event_type == "malformed_postflight_marker"' \
       "$events_root/specs/events.jsonl" >/dev/null 2>&1; then
  common_test_pass "events companion: malformed marker + matching state.json -> exactly one deviation event (AC 4)"
else
  common_test_fail "events companion: expected exactly one deviation event and {} stdout. stdout=$events_out count=$event_count"
fi
rm -rf "$events_root"

# --- Sub-case: malformed marker, NO matching specs/state.json entry -> no event appended,
# hook still echoes {} and exits 0 ---
events_root2="$(make_events_fixture)"
mkdir -p "$events_root2/specs/908_test"
printf 'session_id=sess_1\nskill=foo\n' > "$events_root2/specs/908_test/.postflight-pending"
jq -n '{active_projects: []}' > "$events_root2/specs/state.json"
events_out2="$(run_events_hook "$events_root2" "agent1" "$events_root2" "cc-uuid-1")"
if [ "$events_out2" = "{}" ] && [ ! -f "$events_root2/specs/events.jsonl" ]; then
  common_test_pass "events companion: no matching state.json entry -> no event, clean {} exit"
else
  common_test_fail "events companion: expected no event and {} stdout with no matching state.json entry. stdout=$events_out2"
fi
rm -rf "$events_root2"

# --- Sub-case: cross-session correlation -- two well-formed markers with two distinct
# cc_session_id values; payload matches one. Exactly one event line is appended, its session_id
# is the correlated marker's, and its cc_session_id equals the payload's (AC -- event
# attribution). ---
events_root3="$(make_events_fixture)"
mkdir -p "$events_root3/specs/955_owned" "$events_root3/specs/956_foreign"
jq -n '{cc_session_id:"cc-owned-955",session_id:"sess_owned_955",skill:"skill-a",operation:"implement"}' \
  > "$events_root3/specs/955_owned/.postflight-pending"
jq -n '{cc_session_id:"cc-foreign-956",session_id:"sess_foreign_956",skill:"skill-b",operation:"implement"}' \
  > "$events_root3/specs/956_foreign/.postflight-pending"
events_out3="$(run_events_hook "$events_root3" "agent1" "$events_root3" "cc-owned-955")"
event_count3=0
if [ -f "$events_root3/specs/events.jsonl" ]; then
  event_count3="$(wc -l < "$events_root3/specs/events.jsonl" | tr -d ' ')"
fi
if [ "$events_out3" = "{}" ] && [ "$event_count3" = "1" ] \
  && jq -e '.event_type == "subagent_stop" and .session_id == "sess_owned_955" and .cc_session_id == "cc-owned-955"' \
       "$events_root3/specs/events.jsonl" >/dev/null 2>&1; then
  common_test_pass "events companion: cross-session correlation -- exactly one event, correlated session_id, matching cc_session_id"
else
  common_test_fail "events companion: expected exactly one correlated subagent_stop event. stdout=$events_out3 count=$event_count3"
fi
rm -rf "$events_root3"

# --- Sub-case: cross-session no-match -- a well-formed marker exists but its cc_session_id
# does not match the payload's; zero lines appended (fail-safe, never an arbitrary pick). ---
events_root4="$(make_events_fixture)"
mkdir -p "$events_root4/specs/957_owned"
jq -n '{cc_session_id:"cc-owned-957",session_id:"sess_owned_957",skill:"skill-a",operation:"implement"}' \
  > "$events_root4/specs/957_owned/.postflight-pending"
events_out4="$(run_events_hook "$events_root4" "agent1" "$events_root4" "cc-nomatch")"
if [ "$events_out4" = "{}" ] && [ ! -f "$events_root4/specs/events.jsonl" ]; then
  common_test_pass "events companion: cross-session no-match -> zero lines appended, clean {} exit (fail-safe)"
else
  common_test_fail "events companion: expected no event and {} stdout on cross-session no-match. stdout=$events_out4"
fi
rm -rf "$events_root4"

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
