#!/usr/bin/env bash
# test-deploy-baseline-lib.sh - Unit coverage for scripts/lib/deploy-baseline-lib.sh, the single
# shared home of the pre/post verify-deploy.sh --findings snapshot and new-findings set
# difference algorithm both command-gate-out.sh's rc==6 handler and orchestrate-cycle-plan.sh's
# inter-cycle redeploy checkpoint now source (see the header of the library itself, and
# context/patterns/batch-orchestration-guardrails.md's "### The Inter-Cycle Redeploy Checkpoint"
# subsection for the three-branch contract this library serves).
#
# Coverage:
#   deploy_findings_snapshot   -- exit 0 -> findings (or empty); exit 1 -> findings; exit 2 -> the
#                                  single synthesized sentinel line; a clean run (no FINDING lines)
#                                  must not abort the caller under set -e -o pipefail.
#   deploy_baseline_new_findings -- identical sets -> empty; superset -> exactly the added lines;
#                                  the documented pre-exit-0/post-exit-2 case -> non-empty (the
#                                  sentinel itself counts as a newly-introduced finding).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (the
# library was not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB="$CORE_DIR/lib/deploy-baseline-lib.sh"

if [[ ! -f "$LIB" ]]; then
  echo "ERROR: expected $LIB" >&2
  exit 2
fi

# shellcheck source=/dev/null
source "$LIB"

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

write_fake_verify() {
  # Usage: write_fake_verify <path> <exit_code> <findings_lines...>
  local path="$1" rc="$2"; shift 2
  {
    echo '#!/usr/bin/env bash'
    for line in "$@"; do
      printf 'echo %q\n' "$line"
    done
    echo "exit $rc"
  } > "$path"
  chmod +x "$path"
}

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# deploy_findings_snapshot
# ═══════════════════════════════════════════════════════════════════════════════════════════════

# Case 1: exit 0, no FINDING lines (the ordinary clean case) -- must be empty AND must not abort
# the calling shell under set -e -o pipefail (this is the exact bug class this suite pins: a
# `grep` with zero matches, uncaught, would otherwise kill the caller's script).
VERIFY_CLEAN="$WORKDIR/verify-clean.sh"
write_fake_verify "$VERIFY_CLEAN" 0 "[verify-deploy] PASS -- 14 check(s), 0 failure(s)"
case_1_out="$( (set -euo pipefail; source "$LIB"; deploy_findings_snapshot "$VERIFY_CLEAN") )"
case_1_result="$?"
if [ "$case_1_result" = "0" ] && [ -z "$case_1_out" ]; then
  pass "deploy_findings_snapshot: exit-0 clean run does not abort under set -e -o pipefail, and returns empty"
else
  fail "deploy_findings_snapshot: exit-0 clean run (result=$case_1_result, out='$case_1_out')"
fi

# Case 2: exit 1 with FINDING lines -- returned sorted and deduplicated.
VERIFY_FAIL="$WORKDIR/verify-fail.sh"
write_fake_verify "$VERIFY_FAIL" 1 \
  "FINDING gate3 something wrong" \
  "FINDING gate1 something else wrong" \
  "FINDING gate3 something wrong"
out2="$(deploy_findings_snapshot "$VERIFY_FAIL")"
expected2="$(printf 'FINDING gate1 something else wrong\nFINDING gate3 something wrong')"
if [ "$out2" = "$expected2" ]; then
  pass "deploy_findings_snapshot: exit-1 findings returned sorted and deduplicated"
else
  fail "deploy_findings_snapshot: exit-1 findings mismatch (got: '$out2')"
fi

# Case 3: exit 2 ("cannot run") -- folded into the single sentinel line, regardless of whatever
# prose the fake script printed (never treated as ordinary FINDING lines).
VERIFY_CANNOT_RUN="$WORKDIR/verify-cannotrun.sh"
write_fake_verify "$VERIFY_CANNOT_RUN" 2 "some unrelated prose, no FINDING prefix"
out3="$(deploy_findings_snapshot "$VERIFY_CANNOT_RUN")"
if [ "$out3" = "FINDING gate0 [SENTINEL] verify-deploy could not run (exit 2)" ]; then
  pass "deploy_findings_snapshot: exit-2 folds to the single sentinel line"
else
  fail "deploy_findings_snapshot: exit-2 sentinel mismatch (got: '$out3')"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# deploy_baseline_new_findings
# ═══════════════════════════════════════════════════════════════════════════════════════════════

# Case 4: identical sets -> empty.
pre4="FINDING gate1 a
FINDING gate2 b"
post4="FINDING gate1 a
FINDING gate2 b"
new4="$(deploy_baseline_new_findings "$pre4" "$post4")"
if [ -z "$new4" ]; then
  pass "deploy_baseline_new_findings: identical sets produce empty diff"
else
  fail "deploy_baseline_new_findings: identical sets produced '$new4' (expected empty)"
fi

# Case 5: superset -> exactly the added line(s).
pre5="FINDING gate1 a"
post5="FINDING gate1 a
FINDING gate2 b"
new5="$(deploy_baseline_new_findings "$pre5" "$post5")"
if [ "$new5" = "FINDING gate2 b" ]; then
  pass "deploy_baseline_new_findings: superset returns exactly the added line"
else
  fail "deploy_baseline_new_findings: superset mismatch (got: '$new5')"
fi

# Case 6: the documented pre-exit-0/post-exit-2 case -- pre has no sentinel, post does -> the
# sentinel itself is a new finding, non-empty diff (this is what makes the checkpoint's branch
# (b) fire on a redeploy that succeeded yet cannot be verified at all).
pre6=""
post6="FINDING gate0 [SENTINEL] verify-deploy could not run (exit 2)"
new6="$(deploy_baseline_new_findings "$pre6" "$post6")"
if [ "$new6" = "FINDING gate0 [SENTINEL] verify-deploy could not run (exit 2)" ]; then
  pass "deploy_baseline_new_findings: pre-clean/post-cannot-run makes the sentinel a new finding (non-empty)"
else
  fail "deploy_baseline_new_findings: pre-exit-0/post-exit-2 case mismatch (got: '$new6')"
fi

# Case 7: empty/empty -> empty (both sides clean).
new7="$(deploy_baseline_new_findings "" "")"
if [ -z "$new7" ]; then
  pass "deploy_baseline_new_findings: empty/empty produces empty diff"
else
  fail "deploy_baseline_new_findings: empty/empty produced '$new7' (expected empty)"
fi

echo ""
echo "Results: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
