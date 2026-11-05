#!/usr/bin/env bash
# test-task-reference-patterns-lib.sh - Dedicated fixture-driven suite for the shared parser in
# lib/task-reference-patterns.sh: strip_exempt_regions, exempt_line_mask, and
# marker_balance_report. Neither existing suite (test-check-task-references.sh,
# test-validate-no-task-references.sh) exercises the parser directly -- both only exercise it
# indirectly through a consumer. This suite pins the parser's own depth-counting and
# well-formedness-verdict behavior in isolation.
#
# Follows context/standards/shell-script-testing.md's pass()/fail()/info() + PASSED/FAILED
# counters + mktemp -d workdir + trap EXIT cleanup convention, matching this directory's house
# style (see test-check-task-references.sh, test-validate-no-task-references.sh).
#
# On this file's own marker hygiene: every fixture case below needs the literal marker
# substrings (the begin/end tokens the parser keys on) to exist as real byte content when fed to
# the functions under test -- including deliberately UNBALANCED fixtures (an unterminated begin,
# a stray end), which is the whole point of several cases. Writing those substrings directly in
# this file's own source would make THIS file's own marker-hygiene trace count them, including
# the deliberately-unbalanced ones. Every marker token used as fixture data is therefore composed
# at runtime from concatenated parts (never written as a contiguous literal in this file's
# source), and every literal task-number citation used as fixture content lives in its own
# variable assignment carrying a trailing inline exemption comment, mirroring this directory's
# existing convention (see test-git-commit-phase.sh, test-check-task-references.sh) rather than
# inventing a new one.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (the
# shared library not found, or it fails to source cleanly).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
LIB_SRC="$SCRIPT_DIR/../lib/task-reference-patterns.sh"

PASSED=0
FAILED=0

if [[ ! -f "$LIB_SRC" ]]; then
  echo "ERROR: expected shared library at $LIB_SRC" >&2
  exit 2
fi
# shellcheck source=/dev/null
source "$LIB_SRC" || { echo "ERROR: failed to source $LIB_SRC" >&2; exit 2; }

WORKDIR="$(mktemp -d)"
cleanup() { [[ -n "${WORKDIR:-}" && -d "$WORKDIR" ]] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# ─── Marker tokens, composed at runtime (never a contiguous literal in this file's source) ─────
_tok="task-ref-ok"
MARK_BEGIN="${_tok}:begin"
MARK_END="${_tok}:end"

# ─── Task-number citation literals, each in its own assignment with a trailing inline exemption
#     comment (category 6: test fixture for the reference-pattern detector itself) ─────────────
cite_a="task 5 citation"  # task-ref-ok category 6: parser test fixture citation
cite_b="task 7 citation"  # task-ref-ok category 6: parser test fixture citation
cite_c="task 9 citation"  # task-ref-ok category 6: parser test fixture citation

# =====================================================================
# Case 1: a well-formed pair. The citation inside is exempt (stripped by strip_exempt_regions,
# masked 1 by exempt_line_mask); content outside is not; the parse is well-formed (no report).
# =====================================================================
fixture1="$(printf 'before\n%s reason\n%s\nafter' "$MARK_BEGIN" "$cite_a")"
fixture1="$fixture1
$MARK_END
tail"

stripped1="$(printf '%s' "$fixture1" | strip_exempt_regions)"
expected1="$(printf 'before\ntail')"
if [[ "$stripped1" == "$expected1" ]]; then
  common_test_pass "Case 1 (well-formed pair): strip_exempt_regions removes begin/citation/end, keeps before/tail"
else
  common_test_fail "Case 1 (well-formed pair): strip mismatch, got: $stripped1"
fi

mask1="$(printf '%s' "$fixture1" | exempt_line_mask)"
expected_mask1="$(printf '0\n1\n1\n1\n1\n0')"
if [[ "$mask1" == "$expected_mask1" ]]; then
  common_test_pass "Case 1 (well-formed pair): exempt_line_mask reports 0,1,1,1,1,0"
else
  common_test_fail "Case 1 (well-formed pair): mask mismatch, got: $mask1"
fi

report1="$(printf '%s' "$fixture1" | marker_balance_report)"
if [[ -z "$report1" ]]; then
  common_test_pass "Case 1 (well-formed pair): marker_balance_report is silent (well-formed)"
else
  common_test_fail "Case 1 (well-formed pair): expected silent report, got: $report1"
fi

# =====================================================================
# Case 2: nested pairs. An edit inside the inner pair, and an edit between the inner end and the
# outer end, are both exempt; the parse is well-formed.
# =====================================================================
fixture2="$(printf '%s A\n%s B\n%s\n%s\n%s\n%s\n' \
  "$MARK_BEGIN" "$MARK_BEGIN" "$cite_a" "$MARK_END" "$cite_b" "$MARK_END")"

mask2="$(printf '%s' "$fixture2" | exempt_line_mask)"
expected_mask2="$(printf '1\n1\n1\n1\n1\n1')"
if [[ "$mask2" == "$expected_mask2" ]]; then
  common_test_pass "Case 2 (nested pairs): every line exempt -- inside the inner pair, and between inner-end and outer-end"
else
  common_test_fail "Case 2 (nested pairs): mask mismatch, got: $mask2"
fi

report2="$(printf '%s' "$fixture2" | marker_balance_report)"
if [[ -z "$report2" ]]; then
  common_test_pass "Case 2 (nested pairs): marker_balance_report is silent (well-formed)"
else
  common_test_fail "Case 2 (nested pairs): expected silent report, got: $report2"
fi

# =====================================================================
# Case 3: a stray end before any begin. The stray end is inert (closes nothing) and the report
# names it, but it does not retroactively exempt anything.
# =====================================================================
fixture3="$(printf '%s\n%s\n' "$MARK_END" "$cite_a")"

mask3="$(printf '%s' "$fixture3" | exempt_line_mask)"
expected_mask3="$(printf '1\n0')"
if [[ "$mask3" == "$expected_mask3" ]]; then
  common_test_pass "Case 3 (stray end): the stray end line itself is exempt (dropped), the citation after it is not"
else
  common_test_fail "Case 3 (stray end): mask mismatch, got: $mask3"
fi

report3="$(printf '%s' "$fixture3" | marker_balance_report)"
if [[ "$report3" == *"stray=1"* && "$report3" == *"eof_depth=0"* ]]; then
  common_test_pass "Case 3 (stray end): marker_balance_report names stray=1, eof_depth=0"
else
  common_test_fail "Case 3 (stray end): expected stray=1 eof_depth=0, got: $report3"
fi

# =====================================================================
# Case 4: an unterminated begin with a citation after it -- NOT exempt. This is the dispatch's
# core fail-closed requirement: a begin that never closes grants no exemption at all.
# =====================================================================
fixture4="$(printf 'before\n%s reason\n%s\n' "$MARK_BEGIN" "$cite_a")"

mask4="$(printf '%s' "$fixture4" | exempt_line_mask)"
expected_mask4="$(printf '0\n0\n0')"
if [[ "$mask4" == "$expected_mask4" ]]; then
  common_test_pass "Case 4 (unterminated begin): the begin line, and the citation after it, are both NOT exempt"
else
  common_test_fail "Case 4 (unterminated begin): mask mismatch, got: $mask4"
fi

report4="$(printf '%s' "$fixture4" | marker_balance_report)"
if [[ "$report4" == *"eof_depth=1"* && "$report4" == *"first_unclosed=2"* ]]; then
  common_test_pass "Case 4 (unterminated begin): marker_balance_report names eof_depth=1, first_unclosed=2"
else
  common_test_fail "Case 4 (unterminated begin): expected eof_depth=1 first_unclosed=2, got: $report4"
fi

# =====================================================================
# Case 5: an unterminated begin preceded by a well-formed pair. The earlier, well-formed pair
# stays exempt; only the span from the later, unterminated begin through EOF is not.
# =====================================================================
fixture5="$(printf '%s r1\n%s\n%s\n%s r2\n%s\n' \
  "$MARK_BEGIN" "$cite_a" "$MARK_END" "$MARK_BEGIN" "$cite_b")"

mask5="$(printf '%s' "$fixture5" | exempt_line_mask)"
expected_mask5="$(printf '1\n1\n1\n0\n0')"
if [[ "$mask5" == "$expected_mask5" ]]; then
  common_test_pass "Case 5 (unterminated begin after a well-formed pair): the earlier pair stays exempt; the later unterminated span does not"
else
  common_test_fail "Case 5 (unterminated begin after a well-formed pair): mask mismatch, got: $mask5"
fi

report5="$(printf '%s' "$fixture5" | marker_balance_report)"
if [[ "$report5" == *"eof_depth=1"* && "$report5" == *"first_unclosed=4"* ]]; then
  common_test_pass "Case 5 (unterminated begin after a well-formed pair): marker_balance_report names the LATER begin's line (4), not the earlier well-formed one"
else
  common_test_fail "Case 5 (unterminated begin after a well-formed pair): expected eof_depth=1 first_unclosed=4, got: $report5"
fi

# =====================================================================
# Case 6: the inline form -- a single line carrying the bare marker token is itself exempt, and
# opens no region (the line after it is ordinary content).
# =====================================================================
fixture6="$(printf '%s inline reason: %s\n%s\n' "$_tok" "$cite_a" "$cite_b")"

mask6="$(printf '%s' "$fixture6" | exempt_line_mask)"
expected_mask6="$(printf '1\n0')"
if [[ "$mask6" == "$expected_mask6" ]]; then
  common_test_pass "Case 6 (inline form): the marked line is exempt; it opens no region for the line after it"
else
  common_test_fail "Case 6 (inline form): mask mismatch, got: $mask6"
fi

report6="$(printf '%s' "$fixture6" | marker_balance_report)"
if [[ -z "$report6" ]]; then
  common_test_pass "Case 6 (inline form): marker_balance_report is silent (no begin/end at all)"
else
  common_test_fail "Case 6 (inline form): expected silent report, got: $report6"
fi

# =====================================================================
# Case 7: a begin and an end on the same line -- a self-contained pair with no effect on
# anything else; the line itself is exempt and opens no hanging region.
# =====================================================================
fixture7="$(printf '%s x %s\n%s\n' "$MARK_BEGIN" "$MARK_END" "$cite_a")"

mask7="$(printf '%s' "$fixture7" | exempt_line_mask)"
expected_mask7="$(printf '1\n0')"
if [[ "$mask7" == "$expected_mask7" ]]; then
  common_test_pass "Case 7 (begin+end on one line): the combined-marker line is exempt; the line after it is not"
else
  common_test_fail "Case 7 (begin+end on one line): mask mismatch, got: $mask7"
fi

report7="$(printf '%s' "$fixture7" | marker_balance_report)"
if [[ -z "$report7" ]]; then
  common_test_pass "Case 7 (begin+end on one line): marker_balance_report is silent (well-formed, no stack effect)"
else
  common_test_fail "Case 7 (begin+end on one line): expected silent report, got: $report7"
fi

# =====================================================================
# Case 8: content with no markers at all -- every line is kept by strip_exempt_regions,
# every mask entry is 0, and the report is silent.
# =====================================================================
fixture8="$(printf 'alpha\nbeta\n%s\n' "$cite_c")"

stripped8="$(printf '%s' "$fixture8" | strip_exempt_regions)"
if [[ "$stripped8" == "$fixture8" ]]; then
  common_test_pass "Case 8 (no markers): strip_exempt_regions leaves unmarked content untouched"
else
  common_test_fail "Case 8 (no markers): strip mismatch, got: $stripped8"
fi

mask8="$(printf '%s' "$fixture8" | exempt_line_mask)"
expected_mask8="$(printf '0\n0\n0')"
if [[ "$mask8" == "$expected_mask8" ]]; then
  common_test_pass "Case 8 (no markers): exempt_line_mask reports 0 for every line"
else
  common_test_fail "Case 8 (no markers): mask mismatch, got: $mask8"
fi

report8="$(printf '%s' "$fixture8" | marker_balance_report)"
if [[ -z "$report8" ]]; then
  common_test_pass "Case 8 (no markers): marker_balance_report is silent"
else
  common_test_fail "Case 8 (no markers): expected silent report, got: $report8"
fi

# =====================================================================
# Case 9: exempt_line_mask emits exactly one value per input line, across every fixture above
# (arity check) -- never more, never fewer, regardless of marker content.
# =====================================================================
arity_ok=1
for fx in "$fixture1" "$fixture2" "$fixture3" "$fixture4" "$fixture5" "$fixture6" "$fixture7" "$fixture8"; do
  in_lines=$(printf '%s' "$fx" | wc -l)
  in_lines=$((in_lines + 1))  # wc -l counts newlines; the final unterminated line still counts
  out_lines=$(printf '%s' "$fx" | exempt_line_mask | wc -l)
  if [[ "$in_lines" -ne "$out_lines" ]]; then
    arity_ok=0
    common_test_fail "Case 9 (mask arity): expected $in_lines mask lines, got $out_lines for fixture: $fx"
  fi
done
if [[ "$arity_ok" -eq 1 ]]; then
  common_test_pass "Case 9 (mask arity): exempt_line_mask emits exactly one value per input line, across all 8 fixtures"
fi

echo
echo "=== Results: $PASSED passed, $FAILED failed ==="
if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
