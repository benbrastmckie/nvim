#!/usr/bin/env bash
# test-runtime-file-tracking.sh - Regression suite for check-runtime-file-tracking.sh and its
# canonical class definition, scripts/lib/runtime-file-patterns.sh.
#
# This suite is the executable demonstration of the class-defect this task closes: a live
# `specs/.deploy-lock/owner` was force-tracked into commit 96fb00a40 because three independent
# enumerations of the "ephemeral orchestrator runtime state" class had drifted out of sync, and
# the one lint that exists to catch exactly this (check-runtime-file-tracking.sh) was itself one
# of the drifted enumerations. Case 1/2 below reproduce that exact incident end-to-end (tracked
# -> FAIL with the correct `git rm -r --cached` remediation -> untracked -> PASS) in a disposable
# scratch repo, never against this repo's own history or tree. Case 3 is the doc-sync pin that
# makes the markdown "Consumer Repo Setup" block (which cannot `source` a bash lib) provably
# agree with the lib. Case 4 protects the MUST NOT (durable provenance must never be gitignored).
# Case 5 asserts the lib's own arrays stay 1:1 by construction.
#
# Structural model: context/standards/shell-script-testing.md (PASSED/FAILED counters,
# pass()/fail()/info() helpers, mktemp -d scratch repo, never resolves against the live tree --
# every git operation below runs with cwd pinned to a disposable scratch repo, never this
# repository's own specs/ tree).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (git,
# the script under test, or the lib not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

# Deploy-tree-first / source-store-fallback resolution, matching every other consumer of this
# script/lib pair (see check-runtime-file-tracking.sh's own header). All three paths
# (check script, lib, standards doc) are resolved from the SAME tree root together, never mixed
# -- a deployed tree that has not yet been regenerated (e.g. mid-implementation, before this
# task's own Phase 7 redeploy) would otherwise pair a stale deployed standards doc against a
# freshly-edited source-store lib and fail Case 3 for a reason unrelated to doc-sync.
TREE_ROOTS=(
  "$REPO_ROOT/.claude"
  "$REPO_ROOT/agent-system/extensions/core"
)
CHECK_SCRIPT=""
RUNTIME_LIB=""
STANDARDS_FILE=""
for root in "${TREE_ROOTS[@]}"; do
  candidate_script="$root/scripts/check-runtime-file-tracking.sh"
  candidate_lib="$root/scripts/lib/runtime-file-patterns.sh"
  candidate_standards="$root/context/standards/orchestrator-runtime-files.md"
  if [[ -f "$candidate_script" && -f "$candidate_lib" && -f "$candidate_standards" ]]; then
    CHECK_SCRIPT="$candidate_script"
    RUNTIME_LIB="$candidate_lib"
    STANDARDS_FILE="$candidate_standards"
    break
  fi
done
if [[ -z "$CHECK_SCRIPT" ]]; then
  echo "ERROR: no tree root has check-runtime-file-tracking.sh, lib/runtime-file-patterns.sh, AND orchestrator-runtime-files.md all present together:" >&2
  for root in "${TREE_ROOTS[@]}"; do
    echo "  $root" >&2
  done
  exit 2
fi

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [[ -n "${WORKDIR:-}" && -d "$WORKDIR" ]] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

git_commit() {
  local repo="$1" msg="$2"
  git -C "$repo" -c user.email="test@test.local" -c user.name="runtime-file-tracking-test" \
    commit -q -m "$msg"
}

# =====================================================================
# Case 1 + 2 (the ACCEPTANCE demonstration): tracked specs/.deploy-lock/owner -> FAIL with the
# generalized `git rm -r --cached` remediation -> untracked -> PASS, file left on disk throughout.
# =====================================================================
REPRO="$WORKDIR/repro-repo"
mkdir -p "$REPRO"
git -C "$REPRO" init -q
# shellcheck disable=SC1090,SC1091
. "$RUNTIME_LIB"
runtime_ignore_block > "$REPRO/.gitignore"
git -C "$REPRO" add .gitignore
git_commit "$REPRO" "scratch init: onboarded consumer .gitignore"

mkdir -p "$REPRO/specs/.deploy-lock"
{ echo "pid=1"; echo "claimed_at=$(date +%s)"; echo "session=test"; } > "$REPRO/specs/.deploy-lock/owner"
git -C "$REPRO" add -f specs/.deploy-lock/owner
git_commit "$REPRO" "force-track a live deploy mutex (reproduces commit 96fb00a40)"

info "Case 1: running check-runtime-file-tracking.sh against a repo with a tracked specs/.deploy-lock/owner"
case1_output="$(cd "$REPRO" && bash "$CHECK_SCRIPT" 2>&1)"
case1_exit=$?
if [[ "$case1_exit" -eq 1 ]]; then
  pass "Case 1: exit 1 on a tracked ephemeral-class file"
else
  fail "Case 1: expected exit 1, got $case1_exit"
fi
if echo "$case1_output" | grep -qF 'git rm -r --cached "specs/.deploy-lock"'; then
  pass "Case 1: output names the -r (directory) remediation form for specs/.deploy-lock"
else
  fail "Case 1: output did NOT contain the expected 'git rm -r --cached \"specs/.deploy-lock\"' line:"
  echo "$case1_output" | sed 's/^/    /'
fi
# The narrower, un-generalized form the pre-existing branch would have printed for anything
# other than `.lock/` -- must NOT appear, or the remediation branch was not actually generalized.
if echo "$case1_output" | grep -qF 'git rm --cached "specs/.deploy-lock/owner"'; then
  fail "Case 1: output contains the un-generalized plain-file remediation form (missing -r)"
else
  pass "Case 1: un-generalized plain-file remediation form is absent"
fi

info "Case 2: untracking specs/.deploy-lock (git rm -r --cached, file stays on disk)"
(cd "$REPRO" && git rm -r --cached specs/.deploy-lock >/dev/null)
git_commit "$REPRO" "untrack specs/.deploy-lock/"
if [[ -f "$REPRO/specs/.deploy-lock/owner" ]]; then
  pass "Case 2: specs/.deploy-lock/owner is still present on disk after untracking"
else
  fail "Case 2: specs/.deploy-lock/owner was removed from disk by the untrack -- must never happen"
fi
case2_output="$(cd "$REPRO" && bash "$CHECK_SCRIPT" 2>&1)"
case2_exit=$?
if [[ "$case2_exit" -eq 0 ]] && echo "$case2_output" | grep -q 'PASS'; then
  pass "Case 2: exit 0 / PASS after untracking"
else
  fail "Case 2: expected exit 0 and a PASS line after untracking, got exit $case2_exit:"
  echo "$case2_output" | sed 's/^/    /'
fi

# =====================================================================
# Case 3 (doc-sync pin for scope decision (d)): the markdown "Consumer Repo Setup" fenced block
# is byte-identical to runtime_ignore_block()'s output. This is the mechanism that makes the
# markdown site -- which cannot `source` a bash lib -- provably agree with it.
# =====================================================================
info "Case 3: extracting the fenced gitignore block from $STANDARDS_FILE"
extracted_block="$(awk '/^```gitignore$/{flag=1; next} /^```$/{if(flag){flag=0}} flag' "$STANDARDS_FILE")"
lib_block="$(runtime_ignore_block)"
if [[ "$extracted_block" == "$lib_block" ]]; then
  pass "Case 3: the standards file's Consumer Repo Setup block is byte-identical to runtime_ignore_block()"
else
  fail "Case 3: the standards file's block DIFFERS from runtime_ignore_block() -- doc-sync pin broken"
  diff <(echo "$extracted_block") <(echo "$lib_block") | sed 's/^/    /' || true
fi

# =====================================================================
# Case 4 (Check C guard): a repo whose .gitignore over-ignores .orchestrator-handoff.json must
# fail Check C -- protects the MUST NOT from a future over-broad pattern added to the lib.
# =====================================================================
OVERBROAD="$WORKDIR/overbroad-repo"
mkdir -p "$OVERBROAD"
git -C "$OVERBROAD" init -q
{
  runtime_ignore_block
  echo "**/.orchestrator-handoff.json"
} > "$OVERBROAD/.gitignore"
git -C "$OVERBROAD" add .gitignore
git_commit "$OVERBROAD" "scratch init: over-broad .gitignore ignoring durable provenance"

info "Case 4: running check-runtime-file-tracking.sh against a repo that over-ignores .orchestrator-handoff.json"
case4_output="$(cd "$OVERBROAD" && bash "$CHECK_SCRIPT" 2>&1)"
case4_exit=$?
if [[ "$case4_exit" -eq 1 ]] && echo "$case4_output" | grep -q 'Check C FAILED'; then
  pass "Case 4: Check C fails when .orchestrator-handoff.json is ignored"
else
  fail "Case 4: expected exit 1 with 'Check C FAILED', got exit $case4_exit:"
  echo "$case4_output" | sed 's/^/    /'
fi

# =====================================================================
# Case 5 (lib construction invariant): every member has exactly one probe and one regex --
# the two derived lists (EPHEMERAL_PROBES / b_patterns in check-runtime-file-tracking.sh) are 1:1
# with the lib's membership by construction, not by discipline.
# =====================================================================
info "Case 5: checking RUNTIME_FILE_IDS / RUNTIME_FILE_PATTERNS / RUNTIME_FILE_PROBES / RUNTIME_FILE_B_REGEX / RUNTIME_FILE_IS_DIR / RUNTIME_FILE_DIR_BASENAME are all the same length"
id_count="${#RUNTIME_FILE_IDS[@]}"
all_equal=true
for arr_name in RUNTIME_FILE_PATTERNS RUNTIME_FILE_PROBES RUNTIME_FILE_B_REGEX RUNTIME_FILE_IS_DIR RUNTIME_FILE_DIR_BASENAME; do
  declare -n arr_ref="$arr_name"
  if [[ "${#arr_ref[@]}" -ne "$id_count" ]]; then
    all_equal=false
    fail "Case 5: $arr_name has ${#arr_ref[@]} entries, expected $id_count (matching RUNTIME_FILE_IDS)"
  fi
  unset -n arr_ref
done
if [[ "$all_equal" == "true" ]]; then
  pass "Case 5: all six parallel arrays have $id_count entries (1:1 by construction)"
fi
if [[ "$id_count" -eq 22 ]]; then
  pass "Case 5: lib carries exactly 22 class members (11 pre-existing + .dispatch/ + 4 gaps + tmp + deploy-ledger + orchestration + decisions-lock + issues-lock + metrics-lock)"
else
  fail "Case 5: expected 22 class members, found $id_count"
fi

# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"
if [[ "$FAILED" -eq 0 ]]; then
  exit 0
else
  exit 1
fi
