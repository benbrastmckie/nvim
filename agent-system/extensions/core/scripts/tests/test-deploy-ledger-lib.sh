#!/usr/bin/env bash
# test-deploy-ledger-lib.sh - Unit coverage for scripts/lib/deploy-ledger-lib.sh, the durable
# cross-invocation redeploy ledger the inter-cycle redeploy checkpoint consults before its first
# expensive call (see context/patterns/batch-orchestration-guardrails.md's "The Inter-Cycle
# Redeploy Checkpoint" subsection, "Durable redeploy ledger" paragraph, for the full contract).
# End-to-end coverage of the checkpoint wiring itself (skip/no-skip through the real SUT,
# including the self-modifying-task acceptance criterion) lives in Group 11 of
# test-orchestrate-cycle-plan.sh; this file is unit-only, one function at a time.
#
# Coverage:
#   deploy_ledger_hash_state -- determinism, MISSING-file handling, CANNOTVERIFY on an absent
#                                source-store root.
#   deploy_ledger_read       -- accepts a well-formed ledger; rejects missing/malformed files.
#   deploy_ledger_decide     -- skip_hash (equal hash, in cap); run (equal hash, past cap);
#                                skip_attributed (changed hash, in window, shared task, delta
#                                covered by cycle_modified_files); run for each single broken
#                                conjunct (outside window, disjoint tasks, a foreign changed
#                                path, deploy_pending=true, non-eligible outcome
#                                blocking/deploy_failed, DEPLOY_LEDGER_SKIP=0).
#   deploy_ledger_write      -- round-trips through deploy_ledger_read; atomic (no partial file
#                                left behind).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (a
# required library was not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OVERLAP_LIB="$CORE_DIR/lib/file-scope-overlap.sh"
LIB="$CORE_DIR/lib/deploy-ledger-lib.sh"

for f in "$OVERLAP_LIB" "$LIB"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: expected $f" >&2
    exit 2
  fi
done

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required and is not on PATH" >&2
  exit 2
fi

# shellcheck source=/dev/null
source "$OVERLAP_LIB"
# shellcheck source=/dev/null
source "$LIB"

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

NOW="$(date +%s)"

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Fixtures shared by the hash_state cases
# ═══════════════════════════════════════════════════════════════════════════════════════════════
FIX_ROOT="$WORKDIR/fixture_a"
FIX_CORE="$FIX_ROOT/agent-system/extensions/core"
mkdir -p "$FIX_CORE/scripts"
echo "alpha content" > "$FIX_CORE/scripts/present.sh"
CRIT_FILE="$WORKDIR/critical-paths.json"
cat > "$CRIT_FILE" <<'EOF'
{
  "scope_roots": ["agent-system/extensions/core", ".claude", ".opencode"],
  "critical_paths": [
    {"path": "scripts/present.sh", "label": "present fixture file"},
    {"path": "scripts/absent.sh", "label": "deliberately-missing fixture file"}
  ]
}
EOF

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# deploy_ledger_hash_state
# ═══════════════════════════════════════════════════════════════════════════════════════════════

hs1="$(deploy_ledger_hash_state "$FIX_ROOT" "$CRIT_FILE")"
hs1_rc=$?
if [ "$hs1_rc" -eq 0 ] && [ -n "$hs1" ]; then
  pass "hash_state: succeeds when the scope root and critical-paths file both exist"
else
  fail "hash_state: expected success (rc 0, non-empty output), got rc=$hs1_rc output='$hs1'"
fi

missing_hash="$(echo "$hs1" | jq -r '.paths["scripts/absent.sh"] // "MISSING_KEY"')"
if [ "$missing_hash" = "MISSING" ]; then
  pass "hash_state: a nonexistent critical path hashes to the literal MISSING"
else
  fail "hash_state: expected 'MISSING' for scripts/absent.sh, got '$missing_hash'"
fi

present_hash="$(echo "$hs1" | jq -r '.paths["scripts/present.sh"] // "MISSING_KEY"')"
expected_present_hash="$(sha256sum "$FIX_CORE/scripts/present.sh" | awk '{print $1}')"
if [ "$present_hash" = "$expected_present_hash" ]; then
  pass "hash_state: an existing critical path hashes to its real sha256sum"
else
  fail "hash_state: expected '$expected_present_hash' for scripts/present.sh, got '$present_hash'"
fi

hs2="$(deploy_ledger_hash_state "$FIX_ROOT" "$CRIT_FILE")"
if [ "$hs1" = "$hs2" ]; then
  pass "hash_state: deterministic across repeated calls against an unchanged tree"
else
  fail "hash_state: expected identical output across repeated calls, got '$hs1' vs '$hs2'"
fi

echo "alpha content CHANGED" > "$FIX_CORE/scripts/present.sh"
hs3="$(deploy_ledger_hash_state "$FIX_ROOT" "$CRIT_FILE")"
agg1="$(echo "$hs1" | jq -r '.aggregate')"
agg3="$(echo "$hs3" | jq -r '.aggregate')"
if [ -n "$agg1" ] && [ -n "$agg3" ] && [ "$agg1" != "$agg3" ]; then
  pass "hash_state: aggregate changes when a critical path's content changes"
else
  fail "hash_state: expected aggregate to change after editing scripts/present.sh (got '$agg1' vs '$agg3')"
fi

NO_ROOT_DIR="$WORKDIR/no_core_root"
mkdir -p "$NO_ROOT_DIR"
deploy_ledger_hash_state "$NO_ROOT_DIR" "$CRIT_FILE" > /tmp/hs_cannotverify_$$ 2>/dev/null
hs_absent_rc=$?
hs_absent_out="$(cat /tmp/hs_cannotverify_$$ 2>/dev/null)"
rm -f /tmp/hs_cannotverify_$$
if [ "$hs_absent_rc" -eq 2 ] && [ -z "$hs_absent_out" ]; then
  pass "hash_state: CANNOTVERIFY (rc 2, empty output) when the agent-system/extensions/core scope root is absent"
else
  fail "hash_state: expected rc=2 and empty output for an absent scope root, got rc=$hs_absent_rc output='$hs_absent_out'"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# deploy_ledger_read
# ═══════════════════════════════════════════════════════════════════════════════════════════════

GOOD_LEDGER="$WORKDIR/good-ledger.json"
jq -n -c --argjson now "$NOW" '{
  schema: "deploy-ledger-v1", aggregate: "abc123", paths: {"scripts/present.sh": "abc123"},
  verified_at: $now, verify_outcome: "clean", task_numbers: [182], session_id: "sess_test", cycle: 1
}' > "$GOOD_LEDGER"

read_out="$(deploy_ledger_read "$GOOD_LEDGER")"
read_rc=$?
if [ "$read_rc" -eq 0 ] && [ -n "$read_out" ]; then
  pass "read: accepts a well-formed deploy-ledger-v1 file"
else
  fail "read: expected success reading a well-formed ledger, got rc=$read_rc"
fi

MISSING_LEDGER="$WORKDIR/does-not-exist.json"
deploy_ledger_read "$MISSING_LEDGER" > /tmp/read_missing_$$ 2>/dev/null
read_missing_rc=$?
read_missing_out="$(cat /tmp/read_missing_$$)"
rm -f /tmp/read_missing_$$
if [ "$read_missing_rc" -ne 0 ] && [ -z "$read_missing_out" ]; then
  pass "read: a missing ledger file returns nonzero and empty output"
else
  fail "read: expected failure+empty output for a missing file, got rc=$read_missing_rc output='$read_missing_out'"
fi

MALFORMED_LEDGER="$WORKDIR/malformed-ledger.json"
echo "{ this is not valid json" > "$MALFORMED_LEDGER"
deploy_ledger_read "$MALFORMED_LEDGER" > /tmp/read_malformed_$$ 2>/dev/null
read_malformed_rc=$?
read_malformed_out="$(cat /tmp/read_malformed_$$)"
rm -f /tmp/read_malformed_$$
if [ "$read_malformed_rc" -ne 0 ] && [ -z "$read_malformed_out" ]; then
  pass "read: malformed JSON returns nonzero and empty output"
else
  fail "read: expected failure+empty output for malformed JSON, got rc=$read_malformed_rc"
fi

INCOMPLETE_LEDGER="$WORKDIR/incomplete-ledger.json"
jq -n -c '{schema: "deploy-ledger-v1", aggregate: "abc123"}' > "$INCOMPLETE_LEDGER"
deploy_ledger_read "$INCOMPLETE_LEDGER" > /tmp/read_incomplete_$$ 2>/dev/null
read_incomplete_rc=$?
read_incomplete_out="$(cat /tmp/read_incomplete_$$)"
rm -f /tmp/read_incomplete_$$
if [ "$read_incomplete_rc" -ne 0 ] && [ -z "$read_incomplete_out" ]; then
  pass "read: a ledger missing required keys (verified_at, verify_outcome, task_numbers) is rejected"
else
  fail "read: expected failure+empty output for an incomplete ledger, got rc=$read_incomplete_rc"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# deploy_ledger_decide
# ═══════════════════════════════════════════════════════════════════════════════════════════════

make_ledger() {
  # Usage: make_ledger <aggregate> <paths_json> <age_sec> <verify_outcome> <task_numbers_json>
  local agg="$1" paths="$2" age="$3" outcome="$4" tasks="$5"
  jq -n -c --arg agg "$agg" --argjson paths "$paths" --argjson vat "$((NOW - age))" \
    --arg outcome "$outcome" --argjson tasks "$tasks" '{
      schema: "deploy-ledger-v1", aggregate: $agg, paths: $paths, verified_at: $vat,
      verify_outcome: $outcome, task_numbers: $tasks, session_id: "sess_fixture", cycle: 1
    }'
}

SAME_PATHS='{"scripts/present.sh": "aaa111"}'
CHANGED_PATHS_CUR='{"scripts/fake-critical.sh": "new222"}'
CHANGED_PATHS_LEDGER='{"scripts/fake-critical.sh": "old111"}'

# Case: skip_hash (equal hash, in cap -- age well under DEPLOY_LEDGER_MAX_AGE_SEC default 86400)
ledger_eq_fresh="$(make_ledger "aaa111" "$SAME_PATHS" 60 "clean" "[182]")"
hash_eq="$(jq -n -c --argjson p "$SAME_PATHS" '{aggregate:"aaa111", paths:$p}')"
d1="$(deploy_ledger_decide "$ledger_eq_fresh" "$hash_eq" "$NOW" '[]' '[182]' "false")"
if [ "$(echo "$d1" | jq -r '.decision')" = "skip_hash" ]; then
  pass "decide: skip_hash when the aggregate hash is unchanged and the ledger is within the max-age cap"
else
  fail "decide: expected skip_hash, got $(echo "$d1" | jq -c '.')"
fi

# Case: run (equal hash, past cap -- age beyond DEPLOY_LEDGER_MAX_AGE_SEC default 86400)
ledger_eq_stale="$(make_ledger "aaa111" "$SAME_PATHS" 100000 "clean" "[182]")"
d2="$(deploy_ledger_decide "$ledger_eq_stale" "$hash_eq" "$NOW" '[]' '[182]' "false")"
if [ "$(echo "$d2" | jq -r '.decision')" = "run" ]; then
  pass "decide: run when the aggregate hash is unchanged but the ledger is past the max-age cap"
else
  fail "decide: expected run (stale equal-hash ledger), got $(echo "$d2" | jq -c '.')"
fi

# Case: skip_attributed (changed hash, in recency window, shared task, delta covered by mods)
ledger_changed_recent="$(make_ledger "bbb333" "$CHANGED_PATHS_LEDGER" 300 "clean" "[182]")"
hash_changed="$(jq -n -c --argjson p "$CHANGED_PATHS_CUR" '{aggregate:"ccc444", paths:$p}')"
mods_covering='["agent-system/extensions/core/scripts/fake-critical.sh"]'
d3="$(deploy_ledger_decide "$ledger_changed_recent" "$hash_changed" "$NOW" "$mods_covering" '[182]' "false")"
if [ "$(echo "$d3" | jq -r '.decision')" = "skip_attributed" ]; then
  pass "decide: skip_attributed when recent, sharing a task number, and the delta is covered by cycle_modified_files"
else
  fail "decide: expected skip_attributed, got $(echo "$d3" | jq -c '.')"
fi
attributing="$(echo "$d3" | jq -c '.attributing_tasks')"
if [ "$attributing" = "[182]" ]; then
  pass "decide: skip_attributed names the attributing task number(s)"
else
  fail "decide: expected attributing_tasks == [182], got '$attributing'"
fi

# Case: run -- outside the recency window (changed hash, shared task, covered, but too old)
ledger_changed_old="$(make_ledger "bbb333" "$CHANGED_PATHS_LEDGER" 5000 "clean" "[182]")"
d4="$(deploy_ledger_decide "$ledger_changed_old" "$hash_changed" "$NOW" "$mods_covering" '[182]' "false")"
if [ "$(echo "$d4" | jq -r '.decision')" = "run" ]; then
  pass "decide: run when the changed-hash ledger is outside the recency window (self-modifying case, no longer recent)"
else
  fail "decide: expected run (outside recency window), got $(echo "$d4" | jq -c '.')"
fi

# Case: run -- disjoint task numbers (changed hash, in window, covered, but no shared task)
d5="$(deploy_ledger_decide "$ledger_changed_recent" "$hash_changed" "$NOW" "$mods_covering" '[999]' "false")"
if [ "$(echo "$d5" | jq -r '.decision')" = "run" ]; then
  pass "decide: run when the ledger's task numbers are disjoint from this batch's own"
else
  fail "decide: expected run (disjoint task numbers), got $(echo "$d5" | jq -c '.')"
fi

# Case: run -- a foreign changed path (in window, shared task, but the changed path is NOT
# covered by cycle_modified_files -- i.e. something else changed the source store)
mods_foreign='["agent-system/extensions/core/scripts/some-unrelated-file.sh"]'
d6="$(deploy_ledger_decide "$ledger_changed_recent" "$hash_changed" "$NOW" "$mods_foreign" '[182]' "false")"
if [ "$(echo "$d6" | jq -r '.decision')" = "run" ]; then
  pass "decide: run when a changed critical path is not explained by this batch's own modified files"
else
  fail "decide: expected run (foreign changed path), got $(echo "$d6" | jq -c '.')"
fi

# Case: run -- deploy_pending override forces run despite an otherwise-matching hash
d7="$(deploy_ledger_decide "$ledger_eq_fresh" "$hash_eq" "$NOW" '[]' '[182]' "true")"
if [ "$(echo "$d7" | jq -r '.decision')" = "run" ]; then
  pass "decide: run when deploy_pending_bool=true, overriding an otherwise-matching hash skip"
else
  fail "decide: expected run (deploy_pending override), got $(echo "$d7" | jq -c '.')"
fi

# Case: run -- non-eligible outcome "blocking" (negative record, never skip-eligible)
ledger_blocking="$(make_ledger "aaa111" "$SAME_PATHS" 60 "blocking" "[182]")"
d8="$(deploy_ledger_decide "$ledger_blocking" "$hash_eq" "$NOW" '[]' '[182]' "false")"
if [ "$(echo "$d8" | jq -r '.decision')" = "run" ]; then
  pass "decide: run when the ledger's verify_outcome is 'blocking' (non-eligible negative record)"
else
  fail "decide: expected run (blocking outcome), got $(echo "$d8" | jq -c '.')"
fi

# Case: run -- non-eligible outcome "deploy_failed" (negative record, never skip-eligible)
ledger_failed="$(make_ledger "aaa111" "$SAME_PATHS" 60 "deploy_failed" "[182]")"
d9="$(deploy_ledger_decide "$ledger_failed" "$hash_eq" "$NOW" '[]' '[182]' "false")"
if [ "$(echo "$d9" | jq -r '.decision')" = "run" ]; then
  pass "decide: run when the ledger's verify_outcome is 'deploy_failed' (non-eligible negative record)"
else
  fail "decide: expected run (deploy_failed outcome), got $(echo "$d9" | jq -c '.')"
fi

# Case: run -- DEPLOY_LEDGER_SKIP=0 operator kill switch overrides an otherwise-matching hash
d10="$(DEPLOY_LEDGER_SKIP=0 deploy_ledger_decide "$ledger_eq_fresh" "$hash_eq" "$NOW" '[]' '[182]' "false")"
if [ "$(echo "$d10" | jq -r '.decision')" = "run" ]; then
  pass "decide: run when DEPLOY_LEDGER_SKIP=0, overriding an otherwise-matching hash skip"
else
  fail "decide: expected run (DEPLOY_LEDGER_SKIP=0), got $(echo "$d10" | jq -c '.')"
fi

# Case: run -- no ledger evidence at all (empty ledger_json)
d11="$(deploy_ledger_decide "" "$hash_eq" "$NOW" '[]' '[182]' "false")"
if [ "$(echo "$d11" | jq -r '.decision')" = "run" ]; then
  pass "decide: run when no ledger evidence exists (empty ledger_json)"
else
  fail "decide: expected run (no ledger evidence), got $(echo "$d11" | jq -c '.')"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# deploy_ledger_write -- round-trips through deploy_ledger_read
# ═══════════════════════════════════════════════════════════════════════════════════════════════

WRITE_TARGET="$WORKDIR/nested/dir/deploy-ledger.json"
hash_for_write="$(jq -n -c '{aggregate:"deadbeef", paths:{"scripts/present.sh":"deadbeef"}}')"
if deploy_ledger_write "$WRITE_TARGET" "$hash_for_write" "clean" '[182]' "sess_write_test" 3; then
  pass "write: returns success and creates missing parent directories"
else
  fail "write: expected success writing to a nested, not-yet-existing directory"
fi

if [ -f "$WRITE_TARGET" ]; then
  pass "write: ledger file exists after a successful write"
else
  fail "write: expected ledger file to exist at $WRITE_TARGET"
fi

roundtrip="$(deploy_ledger_read "$WRITE_TARGET")"
roundtrip_rc=$?
if [ "$roundtrip_rc" -eq 0 ] && [ -n "$roundtrip" ]; then
  pass "write+read: a freshly-written ledger round-trips through deploy_ledger_read"
else
  fail "write+read: expected the freshly-written ledger to read back successfully, rc=$roundtrip_rc"
fi

rt_agg="$(echo "$roundtrip" | jq -r '.aggregate')"
rt_outcome="$(echo "$roundtrip" | jq -r '.verify_outcome')"
rt_tasks="$(echo "$roundtrip" | jq -c '.task_numbers')"
if [ "$rt_agg" = "deadbeef" ] && [ "$rt_outcome" = "clean" ] && [ "$rt_tasks" = "[182]" ]; then
  pass "write+read: round-tripped fields (aggregate, verify_outcome, task_numbers) match what was written"
else
  fail "write+read: expected aggregate=deadbeef outcome=clean tasks=[182], got aggregate=$rt_agg outcome=$rt_outcome tasks=$rt_tasks"
fi

leftover_tmp="$(find "$WORKDIR/nested/dir" -maxdepth 1 -name '*.tmp.*' 2>/dev/null)"
if [ -z "$leftover_tmp" ]; then
  pass "write: no leftover .tmp.* file after a successful atomic write"
else
  fail "write: expected no leftover tmp file, found '$leftover_tmp'"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
echo ""
echo "Results: $PASSED passed, $FAILED failed"
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
