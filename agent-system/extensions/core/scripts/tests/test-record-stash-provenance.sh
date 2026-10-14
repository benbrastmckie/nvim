#!/usr/bin/env bash
# test-record-stash-provenance.sh - Fixture-driven regression suite for
# scripts/lib/stash-provenance-lib.sh and hooks/record-stash-provenance.sh (the PostToolUse
# writer half of the stash-ownership ledger guard-destructive-git.sh's Phase 3 predicate reads).
#
# Same convention as test-guard-destructive-git.sh / test-please-grant.sh:
# pass()/fail()/info() helpers, PASSED/FAILED integer counters, mktemp -d workdirs with a
# trap EXIT cleanup, exit 0 on all-pass and exit 1 on any-fail.
#
# STASH_PROVENANCE_STATE_DIR is overridden to a scratch location under this suite's own WORKDIR
# for every invocation, per stash-provenance-lib.sh's own test-isolation convention -- this
# suite never writes into the source store's own tmp/ directory.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$SCRIPT_DIR/../lib/stash-provenance-lib.sh"
HOOK="$SCRIPT_DIR/../../hooks/record-stash-provenance.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

for f in "$LIB" "$HOOK"; do
  [ -f "$f" ] || { echo "ERROR: expected file at $f" >&2; exit 2; }
done
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required" >&2; exit 2; }

# shellcheck source=../lib/stash-provenance-lib.sh
source "$LIB"

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# make_repo
# A fresh git repo with one tracked file, committed, then dirtied -- echoes the repo path.
make_repo() {
  local d
  d="$(mktemp -d -p "$WORKDIR")"
  git -C "$d" init -q
  git -C "$d" config user.email "test@example.com"
  git -C "$d" config user.name "Test Suite"
  echo "line one" > "$d/tracked.txt"
  git -C "$d" add tracked.txt
  git -C "$d" commit -q -m "initial commit"
  echo "line two" >> "$d/tracked.txt"
  echo "$d"
}

# run_hook_post_in <repo> <session_id>
# Drives record-stash-provenance.sh as a real subprocess, cwd set inside <repo>, with a
# synthetic PostToolUse payload naming a Bash tool call under <session_id>.
run_hook_post_in() {
  local repo="$1" sid="$2"
  ( cd "$repo" && jq -n --arg sid "$sid" '{tool_name:"Bash", session_id:$sid, tool_input:{command:"git stash push"}}' \
    | bash "$HOOK" ) >/dev/null 2>/dev/null
}

# =====================================================================
# Case 1: a call that creates a new stash appends exactly one line to the owned-file.
# =====================================================================
STASH_PROVENANCE_STATE_DIR="$(mktemp -d -p "$WORKDIR")"
export STASH_PROVENANCE_STATE_DIR
repo1="$(make_repo)"
sid1="sess_test_owned_1"
(
  cd "$repo1" || exit 1
  sp_snapshot_pre "$sid1"
  git stash push -u >/dev/null 2>&1
)
run_hook_post_in "$repo1" "$sid1"
owned_file1="$(sp_owned_file "$sid1")"
owned_lines1=0
[ -f "$owned_file1" ] && owned_lines1=$(wc -l < "$owned_file1" | tr -d ' ')
if [ "$owned_lines1" -eq 1 ]; then
  pass "a call that creates a new stash appends exactly one line to the owned-file"
else
  fail "expected exactly 1 line in owned-file after a real stash push, got $owned_lines1"
fi
rm -rf "$repo1"

# =====================================================================
# Case 2: a call that creates NO new stash (including the "push saved nothing" shape) appends
# nothing.
# =====================================================================
STASH_PROVENANCE_STATE_DIR="$(mktemp -d -p "$WORKDIR")"
export STASH_PROVENANCE_STATE_DIR
repo2="$(make_repo)"
# Make the tree clean first, so "git stash push -- tracked.txt" genuinely saves nothing.
git -C "$repo2" checkout -q -- tracked.txt
sid2="sess_test_noop_1"
(
  cd "$repo2" || exit 1
  sp_snapshot_pre "$sid2"
  git stash push -- tracked.txt >/dev/null 2>&1   # "No local changes to save" -- the incident shape
)
run_hook_post_in "$repo2" "$sid2"
owned_file2="$(sp_owned_file "$sid2")"
if [ ! -f "$owned_file2" ] || [ ! -s "$owned_file2" ]; then
  pass "a call that saves nothing (push-saved-nothing shape) appends nothing to the owned-file"
else
  fail "expected no owned-file content after a no-op stash push, got: $(cat "$owned_file2" 2>/dev/null)"
fi
rm -rf "$repo2"

# =====================================================================
# Case 3: a missing/unreadable pre-file records nothing new, rather than claiming every
# currently-present sha (including a PRE-EXISTING foreign entry) is owned.
# =====================================================================
STASH_PROVENANCE_STATE_DIR="$(mktemp -d -p "$WORKDIR")"
export STASH_PROVENANCE_STATE_DIR
repo3="$(make_repo)"
# Seed a pre-existing foreign stash entry BEFORE any pre-snapshot is ever taken for this sid.
git -C "$repo3" stash push -u -m preexisting >/dev/null 2>&1
sid3="sess_test_missing_pre_1"
# Deliberately skip sp_snapshot_pre -- no pre-file exists for sid3 at all.
run_hook_post_in "$repo3" "$sid3"
owned_file3="$(sp_owned_file "$sid3")"
if [ ! -f "$owned_file3" ] || [ ! -s "$owned_file3" ]; then
  pass "a missing pre-file records nothing new (does not claim the pre-existing foreign entry)"
else
  fail "expected no owned-file content with a missing pre-file, got: $(cat "$owned_file3" 2>/dev/null)"
fi
rm -rf "$repo3"

# =====================================================================
# Case 4: an invalid or absent session_id is a no-op (both the hook's own validation and the
# library's sp_session_valid gate).
# =====================================================================
STASH_PROVENANCE_STATE_DIR="$(mktemp -d -p "$WORKDIR")"
export STASH_PROVENANCE_STATE_DIR
repo4="$(make_repo)"
(
  cd "$repo4" || exit 1
  sp_snapshot_pre "not valid!"
  git stash push -u >/dev/null 2>&1
)
run_hook_post_in "$repo4" "not valid!"
if [ ! -f "$(sp_owned_file 'not valid!')" ]; then
  pass "an invalid session_id (fails the safe-filename check) is a no-op"
else
  fail "expected no owned-file for an invalid session_id"
fi

absent_hook_out="$(cd "$repo4" && jq -n '{tool_name:"Bash", tool_input:{command:"git stash push"}}' | bash "$HOOK" 2>/dev/null)"
if [ "$absent_hook_out" = "{}" ]; then
  pass "an absent session_id field is a no-op and the hook still emits {}"
else
  fail "expected {} from the hook with an absent session_id, got: $absent_hook_out"
fi
rm -rf "$repo4"

# =====================================================================
# Case 5: sp_is_owned returns non-zero (not owned) for an unknown sha, even when the session
# has a non-empty owned-file.
# =====================================================================
STASH_PROVENANCE_STATE_DIR="$(mktemp -d -p "$WORKDIR")"
export STASH_PROVENANCE_STATE_DIR
repo5="$(make_repo)"
sid5="sess_test_unknown_sha_1"
(
  cd "$repo5" || exit 1
  sp_snapshot_pre "$sid5"
  git stash push -u >/dev/null 2>&1
)
run_hook_post_in "$repo5" "$sid5"
if sp_is_owned "$sid5" "0000000000000000000000000000000000000000"; then
  fail "sp_is_owned wrongly reported an unknown sha as owned"
else
  pass "sp_is_owned returns non-zero for an unknown sha"
fi
# And the real owned sha (whatever it is) IS reported as owned, as a positive control.
real_sha5="$(git -C "$repo5" stash list --format=%H | head -1)"
if [ -n "$real_sha5" ] && sp_is_owned "$sid5" "$real_sha5"; then
  pass "sp_is_owned (positive control) reports the actually-owned sha as owned"
else
  fail "sp_is_owned (positive control) failed to report the actually-owned sha as owned"
fi
rm -rf "$repo5"

# =====================================================================
# Case 6: sp_is_owned fails closed on an absent/invalid session id, regardless of file content.
# =====================================================================
if sp_is_owned "" "deadbeef"; then
  fail "sp_is_owned wrongly succeeded for an empty session id"
else
  pass "sp_is_owned returns non-zero for an empty session id"
fi
if sp_is_owned "not valid!" "deadbeef"; then
  fail "sp_is_owned wrongly succeeded for an invalid session id"
else
  pass "sp_is_owned returns non-zero for an invalid session id"
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
