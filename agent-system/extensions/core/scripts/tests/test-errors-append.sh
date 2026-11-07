#!/usr/bin/env bash
# test-errors-append.sh - Regression suite for errors-append.sh, proving the two verification-bar
# claims mechanically: concurrent invocation does not lose or corrupt records (both append and
# update), and off-schema input is rejected loudly with the target file left byte-identical.
#
# Structural model: scripts/tests/test-phase-heading-patterns.sh (set -uo pipefail,
# pass()/fail()/info() helpers, PASSED/FAILED integer counters, exit 0 on all-pass / 1 on
# any-fail / 2 on environment error). Script-under-test resolution mirrors the deploy-tree-first
# / source-store-fallback candidate list used by check-task-references.sh and
# test-phase-heading-patterns.sh, so this suite runs correctly both post-deploy
# (.claude/scripts/errors-append.sh) and in a source-store-only checkout
# (agent-system/extensions/core/scripts/errors-append.sh).
#
# Harness: each case builds an isolated scratch project root under mktemp -d, with
# <scratch>/.claude/scripts/{errors-append.sh,deploy-root-guard.sh} copied in so
# deploy-root-guard.sh's `*/.claude` case matches and errors-append.sh's PROJECT_ROOT resolves to
# <scratch> -- the real script runs against a real scratch specs/ tree, never the live repo's
# specs/errors.json.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (errors-append.sh not found at any candidate path).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
# REPO_ROOT resolution must work from BOTH invocation sites this suite supports: the
# source-store copy (agent-system/extensions/core/scripts/tests/) and the deployed copy
# (.claude/scripts/tests/), which sit at different depths below the repo root. A single
# fixed levels-up count cannot be correct for both depths at once, so resolve via the git
# worktree root first (depth-independent) and only fall back to the fixed-depth guess
# (matching the source-store depth) when SCRIPT_DIR is not inside a git work tree.
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

SCRIPT_UNDER_TEST="$(common_test_resolve_subject "errors-append.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/errors-append.sh" \
  "$SCRIPT_DIR/../errors-append.sh")" || exit 2
common_test_declare_subject "$SCRIPT_UNDER_TEST"
GUARD_SCRIPT="$(common_test_resolve_subject "deploy-root-guard.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/deploy-root-guard.sh" \
  "$SCRIPT_DIR/../deploy-root-guard.sh")" || exit 2
common_test_declare_subject "$GUARD_SCRIPT"
COMMON_SCRIPT="$(common_test_resolve_subject "lib/common.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lib/common.sh" \
  "$SCRIPT_DIR/../lib/common.sh")" || exit 2
common_test_declare_subject "$COMMON_SCRIPT"

PASSED=0
FAILED=0


TOP_WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${TOP_WORKDIR:-}" ] && [ -d "$TOP_WORKDIR" ] && rm -rf "$TOP_WORKDIR"; }
trap cleanup EXIT

# --- build_scratch -- builds an isolated <scratch>/.claude/scripts/{errors-append.sh,
#     deploy-root-guard.sh} + <scratch>/specs/ tree, echoes the scratch root on stdout. ---
build_scratch() {
  local scratch
  scratch="$(mktemp -d -p "$TOP_WORKDIR")"
  mkdir -p "$scratch/.claude/scripts/lib" "$scratch/specs"
  cp "$SCRIPT_UNDER_TEST" "$scratch/.claude/scripts/errors-append.sh"
  cp "$GUARD_SCRIPT" "$scratch/.claude/scripts/deploy-root-guard.sh"
  cp "$COMMON_SCRIPT" "$scratch/.claude/scripts/lib/common.sh"
  chmod +x "$scratch/.claude/scripts/errors-append.sh"
  echo "$scratch"
}

# run_ea <scratch> [args...] -- invokes errors-append.sh from the scratch's .claude tree
run_ea() {
  local scratch="$1"; shift
  bash "$scratch/.claude/scripts/errors-append.sh" "$@"
}

# =====================================================================================
# Case: lazy creation
# =====================================================================================
{
  scratch="$(build_scratch)"
  if [ -f "$scratch/specs/errors.json" ]; then
    common_test_fail "lazy-creation: errors.json unexpectedly pre-exists in fresh scratch"
  else
    if run_ea "$scratch" append --type build_error --severity high --message "lazy create" >/dev/null 2>&1; then
      if [ -f "$scratch/specs/errors.json" ] \
        && jq -e '.errors | type == "array" and length == 1' "$scratch/specs/errors.json" >/dev/null 2>&1; then
        common_test_pass "lazy-creation: append against a scratch root with no errors.json creates it with a valid shape"
      else
        common_test_fail "lazy-creation: errors.json missing or malformed after first append"
      fi
    else
      common_test_fail "lazy-creation: append exited non-zero on a fresh scratch root"
    fi
  fi
}

# =====================================================================================
# Case: shape-conformance -- every produced record carries all 7 required fields; top level is
# an object with an errors array (never a bare array).
# =====================================================================================
{
  scratch="$(build_scratch)"
  run_ea "$scratch" append --type build_error --severity high --message "shape check" >/dev/null 2>&1
  doc="$scratch/specs/errors.json"
  if jq -e 'type == "object" and (has("errors")) and (.errors | type == "array")' "$doc" >/dev/null 2>&1 \
    && jq -e '.errors[0] | [has("id"),has("timestamp"),has("type"),has("severity"),has("message"),has("context"),has("fix_status")] | all' "$doc" >/dev/null 2>&1; then
    common_test_pass "shape-conformance: top level is object-with-array; record carries all 7 required fields"
  else
    common_test_fail "shape-conformance: document or record shape did not match the schema"
  fi
}

# =====================================================================================
# Case: concurrency (the flock test) -- N (>= 20) parallel append invocations must not lose or
# duplicate records.
# =====================================================================================
{
  scratch="$(build_scratch)"
  N=25
  pids=()
  for i in $(seq 1 "$N"); do
    run_ea "$scratch" append --type build_error --severity medium --message "concurrent $i" >/dev/null 2>&1 &
    pids+=($!)
  done
  ok=true
  for pid in "${pids[@]}"; do
    wait "$pid" || ok=false
  done
  doc="$scratch/specs/errors.json"
  if [ "$ok" = "true" ] && jq -e '. as $d | ($d.errors | type == "array")' "$doc" >/dev/null 2>&1; then
    count=$(jq '.errors | length' "$doc")
    unique_count=$(jq '[.errors[].id] | unique | length' "$doc")
    if [ "$count" -eq "$N" ] && [ "$unique_count" -eq "$N" ]; then
      common_test_pass "concurrency: $N parallel appends yield exactly $N unique records in a still-parsing document"
    else
      common_test_fail "concurrency: expected $N records with $N unique ids, got count=$count unique=$unique_count"
    fi
  else
    common_test_fail "concurrency: one or more append invocations failed, or the document no longer parses"
  fi
}

# =====================================================================================
# Case: concurrent-update -- M parallel update invocations on DISTINCT ids must all land, with
# an unchanged record count.
# =====================================================================================
{
  scratch="$(build_scratch)"
  M=10
  ids=()
  for i in $(seq 1 "$M"); do
    id=$(run_ea "$scratch" append --type build_error --severity low --message "seed $i")
    ids+=("$id")
  done
  pids=()
  for id in "${ids[@]}"; do
    run_ea "$scratch" update --id "$id" --fix-status fixed >/dev/null 2>&1 &
    pids+=($!)
  done
  ok=true
  for pid in "${pids[@]}"; do
    wait "$pid" || ok=false
  done
  doc="$scratch/specs/errors.json"
  count=$(jq '.errors | length' "$doc" 2>/dev/null || echo -1)
  fixed_count=$(jq '[.errors[] | select(.fix_status == "fixed")] | length' "$doc" 2>/dev/null || echo -1)
  if [ "$ok" = "true" ] && [ "$count" -eq "$M" ] && [ "$fixed_count" -eq "$M" ]; then
    common_test_pass "concurrent-update: $M parallel updates on distinct ids all land, record count unchanged"
  else
    common_test_fail "concurrent-update: expected count=$M fixed=$M, got count=$count fixed=$fixed_count"
  fi
}

# =====================================================================================
# Off-schema rejection cases: each asserts exit code 1 AND a byte-identical file afterwards.
# =====================================================================================
assert_rejected() {
  local label="$1" scratch="$2"; shift 2
  local doc="$scratch/specs/errors.json"
  local before after
  before=$(md5sum "$doc" 2>/dev/null || echo "ABSENT")
  if run_ea "$scratch" "$@" >/dev/null 2>&1; then
    common_test_fail "$label: expected exit 1, got exit 0"
    return
  fi
  after=$(md5sum "$doc" 2>/dev/null || echo "ABSENT")
  if [ "$before" = "$after" ]; then
    common_test_pass "$label: exited 1 and left the target file byte-identical"
  else
    common_test_fail "$label: exited 1 but the target file changed"
  fi
}

# invalid --severity
{
  scratch="$(build_scratch)"
  run_ea "$scratch" append --type x --severity high --message "seed" >/dev/null 2>&1
  assert_rejected "reject: invalid --severity" "$scratch" append --type x --severity bogus --message "m"
}

# missing --message
{
  scratch="$(build_scratch)"
  run_ea "$scratch" append --type x --severity high --message "seed" >/dev/null 2>&1
  assert_rejected "reject: missing --message" "$scratch" append --type x --severity high
}

# non-integer --task
{
  scratch="$(build_scratch)"
  run_ea "$scratch" append --type x --severity high --message "seed" >/dev/null 2>&1
  assert_rejected "reject: non-integer --task" "$scratch" append --type x --severity high --message "m" --task abc
}

# malformed --delegation-path-json (valid JSON but not an array)
{
  scratch="$(build_scratch)"
  run_ea "$scratch" append --type x --severity high --message "seed" >/dev/null 2>&1
  assert_rejected "reject: malformed --delegation-path-json" "$scratch" append --type x --severity high --message "m" --delegation-path-json '{"a":1}'
}

# invalid --auto-recoverable
{
  scratch="$(build_scratch)"
  run_ea "$scratch" append --type x --severity high --message "seed" >/dev/null 2>&1
  assert_rejected "reject: invalid --auto-recoverable" "$scratch" append --type x --severity high --message "m" --auto-recoverable maybe
}

# update --fix-status resolved
{
  scratch="$(build_scratch)"
  id=$(run_ea "$scratch" append --type x --severity high --message "seed")
  assert_rejected "reject: update --fix-status resolved" "$scratch" update --id "$id" --fix-status resolved
}

# update with an unmatched --id
{
  scratch="$(build_scratch)"
  run_ea "$scratch" append --type x --severity high --message "seed" >/dev/null 2>&1
  assert_rejected "reject: update with unmatched --id" "$scratch" update --id err_nonexistent --fix-status fixed
}

# update against an absent errors.json (never lazily creates)
{
  scratch="$(build_scratch)"
  if run_ea "$scratch" update --id err_nonexistent --fix-status fixed >/dev/null 2>&1; then
    common_test_fail "reject: update against absent errors.json: expected exit 1, got exit 0"
  elif [ -f "$scratch/specs/errors.json" ]; then
    common_test_fail "reject: update against absent errors.json: file was created (must never lazily create)"
  else
    common_test_pass "reject: update against absent errors.json: exited 1 and did not create the file"
  fi
}

# =====================================================================================
# Case: update correctness -- fix_status/fix_task/fixed_date set, sibling records untouched.
# =====================================================================================
{
  scratch="$(build_scratch)"
  id1=$(run_ea "$scratch" append --type build_error --severity high --message "seed1")
  id2=$(run_ea "$scratch" append --type build_error --severity high --message "seed2")
  run_ea "$scratch" update --id "$id1" --fix-status fixed --fix-task 7 >/dev/null 2>&1  # task-ref-ok inline, category 3: command-usage example, --fix-task takes a number
  doc="$scratch/specs/errors.json"
  rec1_ok=$(jq -e --arg id "$id1" '.errors[] | select(.id == $id) | (.fix_status == "fixed") and (.fix_task == 7) and (.fixed_date != null)' "$doc" >/dev/null 2>&1 && echo yes || echo no)
  rec2_ok=$(jq -e --arg id "$id2" '.errors[] | select(.id == $id) | .fix_status == "unfixed"' "$doc" >/dev/null 2>&1 && echo yes || echo no)
  if [ "$rec1_ok" = "yes" ] && [ "$rec2_ok" = "yes" ]; then
    common_test_pass "update: sets fix_status/fix_task/fixed_date and leaves sibling records untouched"
  else
    common_test_fail "update: rec1_ok=$rec1_ok rec2_ok=$rec2_ok"
  fi
}

# =====================================================================================
# Case: bare-array corruption -- update against a corrupted bare-array document exits 1 with a
# shape error, not a silent rewrite.
# =====================================================================================
{
  scratch="$(build_scratch)"
  id=$(run_ea "$scratch" append --type x --severity high --message "seed")
  echo '[]' > "$scratch/specs/errors.json"
  assert_rejected "reject: bare-array corrupted document" "$scratch" update --id "$id" --fix-status fixed
}

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
