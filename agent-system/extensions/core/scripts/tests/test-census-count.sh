#!/usr/bin/env bash
# test-census-count.sh - Fixture-driven regression suite for census-count.sh, proving the
# shipped tool actually catches the three named repo-wide-count bug classes rather than merely
# handling happy-path input.
#
# Anti-vacuous-test guard: every bug-class group below asserts BOTH a naive/wrong number AND the
# tool's correct number on the SAME fixture, so a fixture that both approaches would get right
# never counts as coverage (per context/standards/shell-script-testing.md's mutation-check
# discipline, applied here to census-count.sh itself rather than to a regex fix).
#
# Follows the core shell-test convention: pass()/fail()/info() helpers, PASSED/FAILED integer
# counters, mktemp -d workdir with a trap EXIT cleanup, exit 0 on all-pass and exit 1 on any-fail.
# All fixtures are synthetic, built inline via heredocs into the temp root -- this suite never
# reads or asserts against the real repository tree.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
TOOL_SRC="$SCRIPT_DIR/../census-count.sh"

PASSED=0
FAILED=0


if [ ! -f "$TOOL_SRC" ]; then
  echo "ERROR: expected census-count.sh at $TOOL_SRC" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required by census-count.sh's occurrences subcommand and is not on PATH" >&2
  exit 1
fi

common_test_workdir_init

TOOL="$WORKDIR/census-count.sh"
cp "$TOOL_SRC" "$TOOL"
chmod +x "$TOOL"

get_field() {
  # get_field <output> <field-name>  -- extracts "field: value" from a record block.
  local output="$1" field="$2"
  echo "$output" | grep -E "^${field}: " | head -1 | sed "s/^${field}: //"
}

# =====================================================================
# Bug class 1: keyword inside a comment/directive/string vs. a real occurrence.
# One fixture per --comment-style (hash, slash, dash). Each asserts naive_count (wrong, counts
# every textual occurrence) DIFFERS from real_count (right, counts only live-code occurrences),
# and that real_count is the correct, smaller number.
# =====================================================================

mkdir -p "$WORKDIR/bug1"

cat > "$WORKDIR/bug1/hash_fixture.py" <<'EOF'
# TARGET appears here as a directive comment
def use_target():
    TARGET = 1  # TARGET also appears here inline
    s = "string containing TARGET text"
    return TARGET
EOF

out="$(bash "$TOOL" occurrences --pattern '\bTARGET\b' --path "$WORKDIR/bug1/hash_fixture.py" --comment-style hash)"
naive="$(get_field "$out" naive_count)"
real="$(get_field "$out" real_count)"
if [ "$naive" = "5" ] && [ "$real" = "2" ]; then
  common_test_pass "bug class 1 (hash style): naive=5 (wrong, counts directive/inline-comment/string) vs real=2 (right, live code only)"
else
  common_test_fail "bug class 1 (hash style): expected naive=5 real=2, got naive=$naive real=$real"
fi

cat > "$WORKDIR/bug1/slash_fixture.js" <<'EOF'
// TARGET appears in a line-comment directive
function useTarget() {
  var TARGET = 1; // TARGET also appears inline here
  /* block comment mentions TARGET too,
     spanning multiple lines with TARGET inside */
  var s = "string containing TARGET text";
  return TARGET;
}
EOF

out="$(bash "$TOOL" occurrences --pattern '\bTARGET\b' --path "$WORKDIR/bug1/slash_fixture.js" --comment-style slash)"
naive="$(get_field "$out" naive_count)"
real="$(get_field "$out" real_count)"
if [ "$naive" = "7" ] && [ "$real" = "2" ]; then
  common_test_pass "bug class 1 (slash style): naive=7 (wrong, counts //, /* */, and string occurrences) vs real=2 (right, live code only)"
else
  common_test_fail "bug class 1 (slash style): expected naive=7 real=2, got naive=$naive real=$real"
fi

cat > "$WORKDIR/bug1/dash_fixture.lua" <<'EOF'
-- TARGET appears in a directive comment
local function use_target()
  local TARGET = 1 -- TARGET also appears inline here
  local s = "string containing TARGET text"
  return TARGET
end
EOF

out="$(bash "$TOOL" occurrences --pattern '\bTARGET\b' --path "$WORKDIR/bug1/dash_fixture.lua" --comment-style dash)"
naive="$(get_field "$out" naive_count)"
real="$(get_field "$out" real_count)"
if [ "$naive" = "5" ] && [ "$real" = "2" ]; then
  common_test_pass "bug class 1 (dash style): naive=5 (wrong, counts directive/inline-comment/string) vs real=2 (right, live code only)"
else
  common_test_fail "bug class 1 (dash style): expected naive=5 real=2, got naive=$naive real=$real"
fi

# =====================================================================
# Bug class 2: a file present in the tree but outside the declared build/target graph.
# Tree = {A, B, C}; declared set = {A, B, D} (D does not exist in the tree).
# All fixtures synthetic -- never asserted against the real repo.
# =====================================================================

mkdir -p "$WORKDIR/bug2/tree"
touch "$WORKDIR/bug2/tree/A.txt" "$WORKDIR/bug2/tree/B.txt" "$WORKDIR/bug2/tree/C.txt"

out="$(bash "$TOOL" membership \
  --tree-cmd "find '$WORKDIR/bug2/tree' -type f -name '*.txt' -printf '%f\n'" \
  --declared-cmd "printf 'A.txt\nB.txt\nD.txt\n'")"

tree_count="$(get_field "$out" tree_count)"
declared_count="$(get_field "$out" declared_count)"
only_in_tree="$(echo "$out" | sed -n '/^ONLY_IN_TREE:$/,/^ONLY_IN_DECLARED:$/p' | sed '1d;$d')"
only_in_declared="$(echo "$out" | sed -n '/^ONLY_IN_DECLARED:$/,/^note:/p' | sed '1d;$d')"

b2_ok=true
[ "$tree_count" = "3" ] || { b2_ok=false; common_test_info "expected tree_count=3, got $tree_count"; }
[ "$declared_count" = "3" ] || { b2_ok=false; common_test_info "expected declared_count=3, got $declared_count"; }
[ "$only_in_tree" = "C.txt" ] || { b2_ok=false; common_test_info "expected ONLY_IN_TREE exactly 'C.txt', got '$only_in_tree'"; }
[ "$only_in_declared" = "D.txt" ] || { b2_ok=false; common_test_info "expected ONLY_IN_DECLARED exactly 'D.txt', got '$only_in_declared'"; }

if [ "$b2_ok" = true ]; then
  common_test_pass "bug class 2: membership correctly reports ONLY_IN_TREE=C.txt, ONLY_IN_DECLARED=D.txt (declared-set diff, not transitive reachability)"
else
  common_test_fail "bug class 2: membership case failed (see INFO lines above)"
fi

# task-ref-ok:begin test fixture for the reference-pattern detector itself
# =====================================================================
# Bug class 3: separator/suffix variants missed by a naive whitespace-only regex.
# Own copy of the separator fixture set (not a cross-reference to the hook's own test suite).
# Ground truth verified directly: of the 5 named forms, only 2 contain a literal whitespace
# separator ("task 788", "tasks 788-790"), so a naive whitespace-only pattern run through this
# SAME tool catches those 2 and misses the other 3 (task-788, task_788, Task #788) -- proving the
# tool's separator-aware pattern distinguishes them rather than passing both patterns identically.
# =====================================================================

mkdir -p "$WORKDIR/bug3"
cat > "$WORKDIR/bug3/forms.txt" <<'EOF'
task 788
task-788
task_788
Task #788
tasks 788-790
EOF

correct_out="$(bash "$TOOL" occurrences \
  --pattern '[Tt]asks?([[:space:]]+#?|[-_#])[0-9]+(-[0-9]+)?' \
  --path "$WORKDIR/bug3/forms.txt" --comment-style none)"
naive_out="$(bash "$TOOL" occurrences \
  --pattern '[Tt]asks?[[:space:]]+[0-9]+(-[0-9]+)?' \
  --path "$WORKDIR/bug3/forms.txt" --comment-style none)"

correct_count="$(get_field "$correct_out" real_count)"
naive_count="$(get_field "$naive_out" real_count)"

if [ "$correct_count" = "5" ] && [ "$naive_count" = "2" ]; then
  common_test_pass "bug class 3: separator-aware pattern matches all 5 named forms (task 788, task-788, task_788, Task #788, tasks 788-790); naive whitespace-only pattern run through the same tool matches only 2 of 5, missing task-788/task_788/Task #788"
else
  common_test_fail "bug class 3: expected correct_count=5 naive_count=2, got correct_count=$correct_count naive_count=$naive_count"
fi
# task-ref-ok:end

# =====================================================================
# Cross-check fixtures: agreeing pair (MATCH, exit 0) and disagreeing pair (MISMATCH, exit != 0).
# =====================================================================

bash "$TOOL" cross-check --a-cmd "echo 12" --b-cmd "echo 12" >/dev/null 2>&1
match_exit=$?
if [ "$match_exit" -eq 0 ]; then
  common_test_pass "cross-check: agreeing commands report MATCH and exit 0"
else
  common_test_fail "cross-check: agreeing commands expected exit 0, got $match_exit"
fi

bash "$TOOL" cross-check --a-cmd "echo 12" --b-cmd "echo 13" >/dev/null 2>&1
mismatch_exit=$?
if [ "$mismatch_exit" -ne 0 ]; then
  common_test_pass "cross-check: disagreeing commands report MISMATCH and exit non-zero"
else
  common_test_fail "cross-check: disagreeing commands expected non-zero exit, got $mismatch_exit"
fi

# =====================================================================
# Record-block fixture: the emitted record block must contain the verbatim command string, so
# the derive-once/record-the-command guarantee is mechanically enforced, not merely documented.
# =====================================================================

mkdir -p "$WORKDIR/recordblock"
echo "MARKER_KEYWORD appears once" > "$WORKDIR/recordblock/f.txt"
record_out="$(bash "$TOOL" occurrences --pattern 'MARKER_KEYWORD' --path "$WORKDIR/recordblock/f.txt" --comment-style none)"
command_line="$(get_field "$record_out" command)"

if echo "$command_line" | grep -qF -- "--pattern 'MARKER_KEYWORD'" && echo "$command_line" | grep -qF -- "$WORKDIR/recordblock/f.txt"; then
  common_test_pass "record-block: emitted 'command:' line contains the verbatim --pattern and --path values"
else
  common_test_fail "record-block: expected verbatim command string in output, got: $command_line"
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
