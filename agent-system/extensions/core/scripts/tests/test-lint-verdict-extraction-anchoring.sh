#!/usr/bin/env bash
# test-lint-verdict-extraction-anchoring.sh - Both-polarity fixture test for
# scripts/lint/lint-verdict-extraction-anchoring.sh.
#
# The lint's job is to fail distinctly on two bad verdict-token extraction shapes -- a bare
# unanchored `grep -F '[FAIL]'`/`grep -F '[VIOLATION]'`, and a naive line-start-anchored
# `grep -E '^\[FAIL\]'`/`grep -E '^\[VIOLATION\]'` that is SGR-blind -- while staying silent on
# a correct helper-routed extraction, on every intended exemption (comment lines, the lint's own
# source), and on an unrelated grep/bracketed-token line. It also pins the producer-side half of
# the contract: the lint's own emitted verdict rows must themselves be selectable by
# `verify_deploy_extract_verdict_lines`, so the lint does not violate the very rule it enforces.
# This suite plants synthetic fixtures in a scratch directory and asserts both polarities; it
# never depends on the live tree being clean for most cases (Case 10 is the one deliberate
# exception -- the standing "is the gate not red on the live tree" assertion) and never mutates
# the repository.
#
# Structural model: test-lint-hook-registration-paths.sh (mktemp -d WORKDIR, deploy-tree-first /
# source-store-fallback candidate resolution, common_test_pass/_fail/_info helpers).
#
# No on-disk fixture files are committed -- every fixture below is built and torn down inside the
# mktemp -d WORKDIR.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.
# Note this is a test OF a lint: its exit code reports test success, not lint success.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"
LINT_SCRIPT="$(common_test_resolve_candidate "lint-verdict-extraction-anchoring.sh" \
  "$REPO_ROOT/.claude/scripts/lint/lint-verdict-extraction-anchoring.sh" \
  "$SCRIPT_DIR/../lint/lint-verdict-extraction-anchoring.sh")" || exit 2

HELPER_LIB="$(common_test_resolve_candidate "gate-verdict-extract-lib.sh" \
  "$REPO_ROOT/.claude/scripts/lib/gate-verdict-extract-lib.sh" \
  "$SCRIPT_DIR/../lib/gate-verdict-extract-lib.sh")" || exit 2
# shellcheck source=../lib/gate-verdict-extract-lib.sh
source "$HELPER_LIB"

PASSED=0
FAILED=0
common_test_workdir_init

# =====================================================================
# Case 1 (FAILING): a bare `grep -F '[FAIL]'` applied to a captured producer-output variable.
# =====================================================================
common_test_info "=== FAILING: unanchored grep -F '[FAIL]' ==="

CASE1_DIR="$WORKDIR/case1"
mkdir -p "$CASE1_DIR"
cat > "$CASE1_DIR/producer.sh" << 'EOF'
#!/usr/bin/env bash
output="$(some_producer)"
while IFS= read -r line; do
  echo "$line"
done < <(printf '%s\n' "$output" | grep -F '[FAIL]')
EOF

case1_out="$(bash "$LINT_SCRIPT" "$CASE1_DIR" 2>&1)"
case1_rc=$?
if [[ $case1_rc -ne 0 ]]; then
  common_test_pass "unanchored grep -F '[FAIL]' exits non-zero"
else
  common_test_fail "unanchored grep -F '[FAIL]' exited 0 (expected non-zero):
$case1_out"
fi
if grep -q '\[VIOLATION\].*unanchored verdict-token extraction' <<< "$case1_out"; then
  common_test_pass "unanchored shape reported with the unanchored remedy text"
else
  common_test_fail "unanchored shape not reported with the expected remedy text:
$case1_out"
fi

# =====================================================================
# Case 2 (FAILING): a bare `grep -E '^\[FAIL\]'` -- naive line-start anchor, SGR-blind.
# =====================================================================
common_test_info "=== FAILING: naive-anchor grep -E '^\[FAIL\]' ==="

CASE2_DIR="$WORKDIR/case2"
mkdir -p "$CASE2_DIR"
cat > "$CASE2_DIR/producer.sh" << 'EOF'
#!/usr/bin/env bash
output="$(some_producer)"
while IFS= read -r line; do
  echo "$line"
done < <(printf '%s\n' "$output" | grep -E '^\[FAIL\]')
EOF

case2_out="$(bash "$LINT_SCRIPT" "$CASE2_DIR" 2>&1)"
case2_rc=$?
if [[ $case2_rc -ne 0 ]]; then
  common_test_pass "naive-anchor grep -E '^\[FAIL\]' exits non-zero"
else
  common_test_fail "naive-anchor grep -E '^\[FAIL\]' exited 0 (expected non-zero):
$case2_out"
fi
if grep -q '\[VIOLATION\].*naive line-start-anchored extraction is SGR-blind' <<< "$case2_out" \
    && grep -q 'SGR' <<< "$case2_out"; then
  common_test_pass "naive-anchor shape reported with the SGR-specific remedy text"
else
  common_test_fail "naive-anchor shape not reported with the expected SGR-specific remedy text:
$case2_out"
fi

# =====================================================================
# Case 3 (FAILING): the same two shapes with the [VIOLATION] token instead of [FAIL].
# =====================================================================
common_test_info "=== FAILING: both shapes with the [VIOLATION] token ==="

CASE3_DIR="$WORKDIR/case3"
mkdir -p "$CASE3_DIR"
cat > "$CASE3_DIR/producer.sh" << 'EOF'
#!/usr/bin/env bash
output="$(some_producer)"
unanchored_hit="$(printf '%s\n' "$output" | grep -F '[VIOLATION]')"
naive_hit="$(printf '%s\n' "$output" | grep -E '^\[VIOLATION\]')"
EOF

case3_out="$(bash "$LINT_SCRIPT" "$CASE3_DIR" 2>&1)"
case3_rc=$?
if [[ $case3_rc -ne 0 ]]; then
  common_test_pass "[VIOLATION]-token shapes exit non-zero"
else
  common_test_fail "[VIOLATION]-token shapes exited 0 (expected non-zero):
$case3_out"
fi
if grep -q '\[VIOLATION\].*unanchored verdict-token extraction' <<< "$case3_out" \
    && grep -q '\[VIOLATION\].*naive line-start-anchored extraction is SGR-blind' <<< "$case3_out"; then
  common_test_pass "[VIOLATION]-token unanchored and naive-anchor shapes both reported distinctly"
else
  common_test_fail "[VIOLATION]-token shapes not both reported as expected:
$case3_out"
fi

# =====================================================================
# Case 4 (regression net): the unanchored and naive-anchor remedy texts must never be merged
# into one generic message.
# =====================================================================
common_test_info "=== Regression net: the two remedy messages must stay distinct ==="

case1_msg="$(grep '\[VIOLATION\]' <<< "$case1_out" | head -1)"
case2_msg="$(grep '\[VIOLATION\]' <<< "$case2_out" | head -1)"
case1_msg_text="${case1_msg#*: }"
case2_msg_text="${case2_msg#*: }"
if [[ -n "$case1_msg_text" && -n "$case2_msg_text" && "$case1_msg_text" != "$case2_msg_text" ]]; then
  common_test_pass "unanchored and naive-anchor remedy messages are distinct strings"
else
  common_test_fail "unanchored and naive-anchor remedy messages are not distinct (merged?):
case1: $case1_msg
case2: $case2_msg"
fi

# =====================================================================
# Case 5 (PASSING): a fixture routing through verify_deploy_extract_verdict_lines -- the
# correct, helper-routed call must never be flagged.
# =====================================================================
common_test_info "=== PASSING: helper-routed extraction ==="

CASE5_DIR="$WORKDIR/case5"
mkdir -p "$CASE5_DIR"
cat > "$CASE5_DIR/consumer.sh" << 'EOF'
#!/usr/bin/env bash
output="$(some_producer)"
while IFS= read -r line; do
  FINDINGS_LIST+=("FINDING gate99 $line")
done < <(verify_deploy_extract_verdict_lines '[FAIL]' "$output")
EOF

case5_out="$(bash "$LINT_SCRIPT" "$CASE5_DIR" 2>&1)"
case5_rc=$?
if [[ $case5_rc -eq 0 ]]; then
  common_test_pass "helper-routed extraction is not flagged"
else
  common_test_fail "helper-routed extraction was unexpectedly flagged:
$case5_out"
fi

# =====================================================================
# Case 6 (PASSING): a fixture reproducing gate-verdict-extract-lib.sh's own shape -- the literal
# bad shapes appearing only inside `#` comment lines, plus an executable pipeline anchored on a
# variable (never a literal bracketed token).
# =====================================================================
common_test_info "=== PASSING: library-header-shaped comment + variable-anchored pipeline ==="

CASE6_DIR="$WORKDIR/case6"
mkdir -p "$CASE6_DIR"
cat > "$CASE6_DIR/lib-shape.sh" << 'EOF'
#!/usr/bin/env bash
# THE DEFECT THIS REPLACES. Every one of verify-deploy.sh's gate blocks previously extracted a
# producer's verdict lines with an UNANCHORED substring match: `grep -F '[FAIL]'` (or
# `grep -F '[VIOLATION]'`). Nor is a uniform `grep -E '^\[FAIL\]'` sufficient on its own, since
# most producers emit colored output with no TTY guard.
verify_deploy_extract_verdict_lines() {
  local _gvel_token="$1"
  local _gvel_output="$2"
  local _gvel_anchor_ere
  _gvel_anchor_ere="^$(printf '%s' "$_gvel_token" | sed -e 's/[.[\*^$()+?{|]/\\&/g')"'[[:space:]]'
  printf '%s\n' "$_gvel_output" | sed -E 's/\x1b\[[0-9;]*m//g' | grep -E "$_gvel_anchor_ere" | \
    sed -E "s/$_gvel_anchor_ere//"
}
EOF

case6_out="$(bash "$LINT_SCRIPT" "$CASE6_DIR" 2>&1)"
case6_rc=$?
if [[ $case6_rc -eq 0 ]]; then
  common_test_pass "library-header-shaped comment and variable-anchored pipeline are not flagged"
else
  common_test_fail "library-header-shaped fixture was unexpectedly flagged:
$case6_out"
fi

# =====================================================================
# Case 7 (PASSING): a fixture reproducing lint-json-channel-discipline.sh's comment shape.
# =====================================================================
common_test_info "=== PASSING: lint-json-channel-discipline.sh comment shape ==="

CASE7_DIR="$WORKDIR/case7"
mkdir -p "$CASE7_DIR"
cat > "$CASE7_DIR/comment-shape.sh" << 'EOF'
#!/usr/bin/env bash
# A here-string consumption of $var is flagged whether it feeds jq directly or feeds a
# `while read` loop -- a while-read fed through an intermediate `< <(cmd | grep ...)` process
# substitution is a different, lower-risk shape (verify-deploy.sh's nine `*_lint_output` blocks
# are exactly this -- `done < <(printf '%s\n' "$foo_lint_output" | grep -F '[FAIL]')`), so that
# shape is never flagged here without its own per-script allowlist entry.
echo "nothing executable here"
EOF

case7_out="$(bash "$LINT_SCRIPT" "$CASE7_DIR" 2>&1)"
case7_rc=$?
if [[ $case7_rc -eq 0 ]]; then
  common_test_pass "lint-json-channel-discipline.sh comment shape is not flagged"
else
  common_test_fail "comment-shape fixture was unexpectedly flagged:
$case7_out"
fi

# =====================================================================
# Case 8 (PASSING): an unrelated grep and an unrelated bracketed token -- no over-matching.
# =====================================================================
common_test_info "=== PASSING: unrelated grep and unrelated bracketed token ==="

CASE8_DIR="$WORKDIR/case8"
mkdir -p "$CASE8_DIR"
cat > "$CASE8_DIR/unrelated.sh" << 'EOF'
#!/usr/bin/env bash
grep -F '[PASS]' output.log
grep -E '^\[INFO\]' output.log
grep -F 'some unrelated literal' output.log
EOF

case8_out="$(bash "$LINT_SCRIPT" "$CASE8_DIR" 2>&1)"
case8_rc=$?
if [[ $case8_rc -eq 0 ]]; then
  common_test_pass "unrelated grep / unrelated bracketed token is not flagged (no over-matching)"
else
  common_test_fail "unrelated-token fixture was unexpectedly flagged:
$case8_out"
fi

# =====================================================================
# Case 9 (producer-side self-check, dispatch's explicit requirement): capture the lint's own
# stdout from a multi-violation fixture, pipe it through verify_deploy_extract_verdict_lines,
# and assert the selected line count and content equal the lint's own reported finding set.
# =====================================================================
common_test_info "=== Producer-side self-check: lint output round-trips through the helper ==="

CASE9_DIR="$WORKDIR/case9"
mkdir -p "$CASE9_DIR"
cp "$CASE1_DIR/producer.sh" "$CASE9_DIR/unanchored.sh"
cp "$CASE2_DIR/producer.sh" "$CASE9_DIR/naive-anchor.sh"
cp "$CASE3_DIR/producer.sh" "$CASE9_DIR/both-violation-token.sh"

case9_out="$(bash "$LINT_SCRIPT" "$CASE9_DIR" 2>&1)"
case9_rc=$?
# The lint's own authoritative finding count, from its summary line (never a raw substring grep
# on the finding text -- a flagged source line can legitimately quote the bracketed token again
# in its own message continuation, as case3's fixture text does, which would over-count a naive
# `grep -c '\[VIOLATION\]'` on the whole output).
case9_reported_total="$(grep -oE 'Total violations: [0-9]+' <<< "$case9_out" | grep -oE '[0-9]+' || true)"
case9_selected="$(verify_deploy_extract_verdict_lines '[VIOLATION]' "$case9_out")"
case9_selected_count="$(printf '%s\n' "$case9_selected" | grep -c . || true)"

if [[ $case9_rc -ne 0 && "$case9_reported_total" -eq 4 ]]; then
  common_test_pass "multi-violation fixture produces the expected 4 reported violations"
else
  common_test_fail "multi-violation fixture did not report exactly 4 violations (got '$case9_reported_total', rc=$case9_rc):
$case9_out"
fi
if [[ "$case9_selected_count" -eq "$case9_reported_total" ]]; then
  common_test_pass "verify_deploy_extract_verdict_lines selects exactly the lint's own real finding set ($case9_selected_count == $case9_reported_total)"
else
  common_test_fail "verify_deploy_extract_verdict_lines selected $case9_selected_count lines but the lint reported $case9_reported_total:
--- raw ---
$case9_out
--- selected ---
$case9_selected"
fi

# =====================================================================
# Case 10 (live-corpus case): run the lint with no positional argument against the real source
# store -- the standing assertion that the gate is not red on the live tree.
# =====================================================================
common_test_info "=== Live-corpus case: default corpus against the real source store ==="

case10_out="$(bash "$LINT_SCRIPT" 2>&1)"
case10_rc=$?
if [[ $case10_rc -eq 0 ]]; then
  common_test_pass "default corpus against the live source store exits 0"
else
  common_test_fail "default corpus against the live source store did not exit 0 (rc=$case10_rc):
$case10_out"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
