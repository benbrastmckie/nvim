#!/usr/bin/env bash
# test-validate-no-task-references.sh - Fixture-driven regression suite for
# validate-no-task-references.sh's separator-aware task/phase citation regex AND its blocking
# PreToolUse behavior (exit code 2 on a match, exit 0 otherwise).
#
# Drives the hook as a real subprocess: copies it byte-for-byte into an isolated
# mktemp -d workdir (alongside a copy of the shared lib/task-reference-patterns.sh library at
# the same relative path the hook expects: <workdir>/hooks/validate-no-task-references.sh sources
# <workdir>/scripts/lib/task-reference-patterns.sh) and pipes a synthetic PreToolUse JSON payload
# ({"tool_input":{"file_path":...,"content":...}}) on stdin for every case, asserting on the
# hook's EXIT CODE (2 = blocked, 0 = allowed) rather than its stdout -- the hook no longer emits
# JSON on stdout at all post-flip; it writes a stderr message and exits 2 on a match, or exits 0
# silently. The hook itself is never instrumented or modified for testability -- it never learns
# it is under test.
#
# Follows the core shell-test convention in
# context/standards/shell-script-testing.md: pass()/fail()/info() helpers, PASSED/FAILED
# integer counters, mktemp -d workdir with a trap EXIT cleanup, exit 0 on all-pass and
# exit 1 on any-fail.
#
# NOTE on this file's own task-ref-ok markers: the fixture blocks below deliberately embed
# literal "task-ref-ok:begin"/"task-ref-ok:end" tokens as TEST DATA (verifying the hook
# recognizes them in scanned content) as well as literal task-number digits as fixture input.
# check-task-references.sh's shared strip_exempt_regions is a simple line-based TOGGLE, not a
# nesting-aware parser -- an inner "task-ref-ok:end" closes ANY still-open region, including an
# outer one. Marker regions in this file are therefore kept non-nested (each self-contained
# begin/end pair stands alone, never inside another one), and any fixture line that must remain
# LITERALLY UNMARKED as far as the hook's own content-scan is concerned (to test the blocking
# path) is instead exempted at the FILE level via a trailing inline `# task-ref-ok` bash comment
# on a variable-assignment line, which strip_exempt_regions strips as a whole raw line without
# that comment ever becoming part of the shell string value the hook receives.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SRC="$SCRIPT_DIR/../../hooks/validate-no-task-references.sh"
LIB_SRC="$SCRIPT_DIR/../lib/task-reference-patterns.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

if [ ! -f "$HOOK_SRC" ]; then
  echo "ERROR: expected validate-no-task-references.sh at $HOOK_SRC" >&2
  exit 1
fi

if [ ! -f "$LIB_SRC" ]; then
  echo "ERROR: expected shared library task-reference-patterns.sh at $LIB_SRC" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required to build synthetic PreToolUse payloads and is not on PATH" >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# Mirror the hook's expected sibling layout: hooks/validate-no-task-references.sh sources
# ../scripts/lib/task-reference-patterns.sh relative to its OWN directory.
mkdir -p "$WORKDIR/hooks" "$WORKDIR/scripts/lib"
HOOK="$WORKDIR/hooks/validate-no-task-references.sh"
cp "$HOOK_SRC" "$HOOK"
chmod +x "$HOOK"
cp "$LIB_SRC" "$WORKDIR/scripts/lib/task-reference-patterns.sh"

# run_hook <file_path> <content>
# Builds a synthetic PreToolUse payload via jq (safe against quotes/parens in content) and
# pipes it to the copied hook. Echoes "EXITCODE|STDERR" so callers can assert on both.
run_hook() {
  local file_path="$1" content="$2" out exit_code
  out="$(jq -n --arg fp "$file_path" --arg c "$content" \
    '{tool_input: {file_path: $fp, content: $c}}' \
    | bash "$HOOK" 2>&1 1>/dev/null)"
  exit_code=$?
  printf '%s|%s' "$exit_code" "$out"
}

hook_exit_code() {
  local file_path="$1" content="$2"
  jq -n --arg fp "$file_path" --arg c "$content" \
    '{tool_input: {file_path: $fp, content: $c}}' \
    | bash "$HOOK" >/dev/null 2>&1
  echo $?
}

# assert_triggers <label> <file_path> <content>
# Expects exit 2 (blocked) and non-empty stderr.
assert_triggers() {
  local label="$1" file_path="$2" content="$3" result code stderr_out
  result="$(run_hook "$file_path" "$content")"
  code="${result%%|*}"
  stderr_out="${result#*|}"
  if [ "$code" -eq 2 ] && [ -n "$stderr_out" ]; then
    pass "$label: exits 2 with stderr message"
  else
    fail "$label: expected exit 2 + stderr, got exit=$code stderr='$stderr_out'"
  fi
}

# assert_silent <label> <file_path> <content>
# Expects exit 0 (allowed).
assert_silent() {
  local label="$1" file_path="$2" content="$3" code
  code="$(hook_exit_code "$file_path" "$content")"
  if [ "$code" -eq 0 ]; then
    pass "$label: exits 0 (allowed)"
  else
    fail "$label: expected exit 0, got exit=$code"
  fi
}

# task-ref-ok:begin test fixture for the reference-pattern detector itself
# =====================================================================
# Positive fixtures (must exit 2 / blocked)
# =====================================================================
assert_triggers "positive: task 788"            "lua/foo.lua" "See task 788 for context"
assert_triggers "positive: tasks 788-790"        "lua/foo.lua" "This spans tasks 788-790"
assert_triggers "positive: task-788"             "lua/foo.lua" "See task-788 for context"
assert_triggers "positive: task_788"             "lua/foo.lua" "See task_788 for context"
assert_triggers "positive: Task #788"            "lua/foo.lua" "Per Task #788 this changed"
assert_triggers "positive: task#788"             "lua/foo.lua" "Per task#788 this changed"
assert_triggers "positive: TASK 788 (uppercase)" "lua/foo.lua" "TASK 788 introduced this"
assert_triggers "positive: (task 788) parens"    "lua/foo.lua" "Behavior changed (task 788)"
assert_triggers "positive: task 926 phase 3"     "lua/foo.lua" "See task 926 phase 3 for the fix"
assert_triggers "positive: phase 3 of task 926"  "lua/foo.lua" "Introduced in phase 3 of task 926"

# =====================================================================
# Negative fixtures (must exit 0 / allowed)
# =====================================================================
assert_silent "negative: bare Phase 3 heading"     "lua/foo.lua" "### Phase 3: Something"
assert_silent "negative: ### Phase 12: name"       "lua/foo.lua" "### Phase 12: Registration"
assert_silent "negative: task list (no number)"    "lua/foo.lua" "See the task list for details"
assert_silent "negative: task force (no number)"   "lua/foo.lua" "Formed a task force to fix it"
assert_silent "negative: the tasks are (no number)" "lua/foo.lua" "the tasks are enumerated below"
assert_silent "negative: taskbar788 (no boundary)" "lua/foo.lua" "Uses the taskbar788 widget class"
assert_silent "negative: ordinary sentence"        "lua/foo.lua" "This function returns the sum of two numbers."

# =====================================================================
# Exemption fixtures: specs/** file_path always exits 0 even with positive content
# (Exemption Taxonomy category 1)
# =====================================================================
assert_silent "exemption: relative specs/ path"    "specs/926_foo/plans/01_plan.md" "See task 788 for context"
assert_silent "exemption: absolute-prefixed specs/ path" "/abs/prefix/specs/926_foo/plans/01_plan.md" "See task 788 for context"

# Memory-vault fixtures (taxonomy category 7, path-level): a memory's own frontmatter provenance
# field and the wholesale-regenerated index that mirrors it. Both carry a concrete number with no
# marker, which is the whole point of the zone being path-level rather than marker-bearing.
assert_silent "exemption: relative .memory/ memory file" ".memory/10-Memories/MEM-technique-latex-renumber.md" 'source: "Task 101: specs/101_foo/summaries/01_summary.md"'
assert_silent "exemption: absolute-prefixed .memory/ path" "/abs/prefix/.memory/memory-index.json" '"source": "Task 68: specs/068_bar/summaries/01_summary.md",'
assert_silent "exemption: .memory/ index, prose-shaped citation" ".memory/memory-index.json" "harvested from task 132"

# =====================================================================
# Degenerate-input fixtures: empty file_path / empty content both exit 0
# =====================================================================
degenerate_fixture_content="See task 788 for context"  # task-ref-ok inline test fixture, category 6
degenerate_code="$(hook_exit_code "" "$degenerate_fixture_content")"
if [ "$degenerate_code" -eq 0 ]; then
  pass "degenerate: empty file_path exits 0"
else
  fail "degenerate: empty file_path expected exit 0, got exit=$degenerate_code"
fi

degenerate_code="$(hook_exit_code "lua/foo.lua" "")"
if [ "$degenerate_code" -eq 0 ]; then
  pass "degenerate: empty content exits 0"
else
  fail "degenerate: empty content expected exit 0, got exit=$degenerate_code"
fi
# task-ref-ok:end

# =====================================================================
# Exemption fixtures: one per remaining Exemption Taxonomy category (context/standards/
# task-reference-exemptions.md's "## Exemption Taxonomy" section, the rule's companion). Kept OUTSIDE the
# block above -- each begin/end pair below is self-contained (never nested inside another),
# per this file's own header note on strip_exempt_regions' toggle semantics.
# =====================================================================

# Category 2: commit-message convention example, marked -> allowed.
assert_silent "category 2: marked commit-convention example" "lua/foo.lua" \
"<!-- task-ref-ok:begin canonical rendered commit-message example -->
task 259: create LaTeX documentation for Logos system
<!-- task-ref-ok:end -->"

# Category 2 / regression anchor: the git-workflow.md self-trip case. The exact line that
# defines the sanctioned task+phase commit convention must NOT be indistinguishable from a
# violation once marked, and MUST still be caught when the marker is absent. The unmarked
# variant's literal text is file-exempted via a trailing inline comment on its assignment line
# (see this file's header note) so it reaches the hook as truly unmarked content.
assert_silent "regression anchor: task+phase commit example, MARKED" "lua/foo.lua" \
"<!-- task-ref-ok:begin canonical rendered commit-message example -->
task 259 phase 2: implement modal semantics evaluator
<!-- task-ref-ok:end -->"
unmarked_phase_fixture="task 259 phase 2: implement modal semantics evaluator"  # task-ref-ok inline test fixture, category 6
assert_triggers "regression anchor: task+phase commit example, UNMARKED" "lua/foo.lua" \
"$unmarked_phase_fixture"

# Category 3: command-usage example, marked -> allowed; unmarked -> blocked.
assert_silent "category 3: marked command-usage example" "lua/foo.lua" \
"<!-- task-ref-ok:begin command-usage example -->
/learn --task 142
<!-- task-ref-ok:end -->"
unmarked_command_usage_fixture="/learn --task 142"  # task-ref-ok inline test fixture, category 6
assert_triggers "category 3: unmarked command-usage example" "lua/foo.lua" \
"$unmarked_command_usage_fixture"

# Category 4: quoted historical anti-pattern, marked -> allowed.
assert_silent "category 4: marked quoted historical anti-pattern" "lua/foo.lua" \
"<!-- task-ref-ok:begin quoted historical anti-pattern -->
## 13. Index Freshness (tasks 823-824)
<!-- task-ref-ok:end -->"

# Category 5: placeholder-bearing prose never matches TASK_PATTERN at all -- no marker needed,
# never blocked.
assert_silent "category 5: placeholder-bearing prose, no marker" "lua/foo.lua" \
"See task {N} and specs/{NNN}_{SLUG}/ for the artifact path convention."

# Category 6: test fixture for the reference-pattern detector itself, marked -> allowed. The
# inline marker form exempts only the single line it appears on, so the marker and the fixture
# literal must share one line.
assert_silent "category 6: marked test-fixture literal" "lua/foo.lua" \
"assert_triggers \"positive: task 788\" ... \"See task 788 for context\" <!-- task-ref-ok quoting the actual fixture strings, category 6 -->"

# Category 7: memory vault frontmatter provenance field, marked inline -> allowed.
assert_silent "category 7: marked memory frontmatter provenance" ".memory/10-Memories/MEM-example.md" \
"topic: \"task-595\"  # task-ref-ok inline, category 7"

# =====================================================================
# Shared-library-missing fixture: hook must fail OPEN (exit 0), never block every write in
# the repo just because its own dependency vanished.
# =====================================================================
NOLIBDIR="$(mktemp -d)"
mkdir -p "$NOLIBDIR/hooks"
cp "$HOOK_SRC" "$NOLIBDIR/hooks/validate-no-task-references.sh"
chmod +x "$NOLIBDIR/hooks/validate-no-task-references.sh"
nolib_fixture_content="See task 788 for context"  # task-ref-ok inline test fixture, category 6
nolib_out="$(jq -n --arg fp "lua/foo.lua" --arg c "$nolib_fixture_content" \
  '{tool_input: {file_path: $fp, content: $c}}' \
  | bash "$NOLIBDIR/hooks/validate-no-task-references.sh" 2>&1 1>/dev/null)"
nolib_code=$?
rm -rf "$NOLIBDIR"
if [ "$nolib_code" -eq 0 ] && [ -n "$nolib_out" ]; then
  pass "shared-library-missing: fails open (exit 0) with a warning"
else
  fail "shared-library-missing: expected exit 0 + warning, got exit=$nolib_code out='$nolib_out'"
fi

# ─── run_hook_edit: Edit-shaped payload (old_string/new_string), region-aware against the
#     reconstructed post-edit file ────────────────────────────────────────────────────────────
# run_hook_edit <file_path> <disk_content> <old_string> <new_string> [replace_all]
# Writes disk_content to file_path (creating parent dirs under WORKDIR as needed), then pipes a
# synthetic Edit-shaped PreToolUse payload to the hook, built via jq -n --arg (safe against
# quotes/parens), mirroring run_hook/hook_exit_code's shape. replace_all, if given, is passed as
# a JSON boolean; omitted means absent from the payload (the hook then defaults it to false).
run_hook_edit() {
  local file_path="$1" disk_content="$2" old_string="$3" new_string="$4" replace_all="${5:-}"
  local out exit_code
  mkdir -p "$(dirname "$file_path")"
  printf '%s' "$disk_content" > "$file_path"
  if [ -n "$replace_all" ]; then
    out="$(jq -n --arg fp "$file_path" --arg old "$old_string" --arg new "$new_string" --argjson ra "$replace_all" \
      '{tool_input: {file_path: $fp, old_string: $old, new_string: $new, replace_all: $ra}}' \
      | bash "$HOOK" 2>&1 1>/dev/null)"
  else
    out="$(jq -n --arg fp "$file_path" --arg old "$old_string" --arg new "$new_string" \
      '{tool_input: {file_path: $fp, old_string: $old, new_string: $new}}' \
      | bash "$HOOK" 2>&1 1>/dev/null)"
  fi
  exit_code=$?
  printf '%s|%s' "$exit_code" "$out"
}

hook_edit_exit_code() {
  local result
  result="$(run_hook_edit "$@")"
  printf '%s' "${result%%|*}"
}

# ─── Marker tokens for the Edit-path fixtures below, composed at runtime (never a contiguous
#     literal in this file's own source). Several of the dispatch's six cases are deliberately
#     constructed on-disk fixtures (an unterminated begin, nested pairs) that this file's own
#     marker-hygiene trace must never see as real occurrences, regardless of what each case
#     needs to leave balanced or unbalanced on disk at test time. ───────────────────────────────
edit_tok="task-ref-ok"
EDIT_MARK_BEGIN="${edit_tok}:begin"
EDIT_MARK_END="${edit_tok}:end"

EDIT_WORKDIR="$WORKDIR/edit-fixtures"
mkdir -p "$EDIT_WORKDIR"

# =====================================================================
# Case 1 (dispatch): Edit inside a file-wide pair -- exit 0. This is the dispatch's own
# observation, asserted directly.
# =====================================================================
case1_file="$EDIT_WORKDIR/case1.lua"
case1_disk="$(printf -- '-- before\n-- %s reason\n-- middle\n-- %s\n-- after\n' "$EDIT_MARK_BEGIN" "$EDIT_MARK_END")"
case1_new="-- middle, see task 701"  # task-ref-ok inline test fixture, category 6
case1_code="$(hook_edit_exit_code "$case1_file" "$case1_disk" "-- middle" "$case1_new")"
if [ "$case1_code" -eq 0 ]; then
  pass "Case 1 (dispatch): Edit inside a file-wide pair exits 0"
else
  fail "Case 1 (dispatch): expected exit 0, got exit=$case1_code"
fi

# =====================================================================
# Case 2 (dispatch): Edit outside any pair in a file that has one -- exit 2.
# =====================================================================
case2_file="$EDIT_WORKDIR/case2.lua"
case2_disk="$(printf -- '-- unmarked\n-- %s reason\n-- inside\n-- %s\n' "$EDIT_MARK_BEGIN" "$EDIT_MARK_END")"
case2_new="-- unmarked, see task 702"  # task-ref-ok inline test fixture, category 6
case2_code="$(hook_edit_exit_code "$case2_file" "$case2_disk" "-- unmarked" "$case2_new")"
if [ "$case2_code" -eq 2 ]; then
  pass "Case 2 (dispatch): Edit outside any pair exits 2"
else
  fail "Case 2 (dispatch): expected exit 2, got exit=$case2_code"
fi

# =====================================================================
# Case 3 (dispatch): unterminated marker -- exit 2. The begin that never closes exempts nothing.
# =====================================================================
case3_file="$EDIT_WORKDIR/case3.lua"
case3_disk="$(printf -- '-- before\n-- %s reason, never closed\n-- editme\n' "$EDIT_MARK_BEGIN")"
case3_new="-- editme, see task 703"  # task-ref-ok inline test fixture, category 6
case3_code="$(hook_edit_exit_code "$case3_file" "$case3_disk" "-- editme" "$case3_new")"
if [ "$case3_code" -eq 2 ]; then
  pass "Case 3 (dispatch): unterminated marker exits 2"
else
  fail "Case 3 (dispatch): expected exit 2, got exit=$case3_code"
fi

# =====================================================================
# Case 4 (dispatch): nested pairs -- exit 0 for an edit inside the inner (B) pair, and exit 0
# for a second edit between B's end and A's end (still inside A only).
# =====================================================================
case4_file="$EDIT_WORKDIR/case4.lua"
case4_disk="$(printf -- '-- %s A\n-- %s B\n-- inner-b\n-- %s\n-- between-b-and-a\n-- %s\n' \
  "$EDIT_MARK_BEGIN" "$EDIT_MARK_BEGIN" "$EDIT_MARK_END" "$EDIT_MARK_END")"
case4_new_inner="-- inner-b, task 704"  # task-ref-ok inline test fixture, category 6
case4_code_inner="$(hook_edit_exit_code "$case4_file" "$case4_disk" "-- inner-b" "$case4_new_inner")"
if [ "$case4_code_inner" -eq 0 ]; then
  pass "Case 4a (dispatch): nested pairs, edit inside the B-within-A nest exits 0"
else
  fail "Case 4a (dispatch): expected exit 0, got exit=$case4_code_inner"
fi
case4_new_between="-- between-b-and-a, task 705"  # task-ref-ok inline test fixture, category 6
case4_code_between="$(hook_edit_exit_code "$case4_file" "$case4_disk" "-- between-b-and-a" "$case4_new_between")"
if [ "$case4_code_between" -eq 0 ]; then
  pass "Case 4b (dispatch): nested pairs, edit between end-B and end-A (still inside A) exits 0"
else
  fail "Case 4b (dispatch): expected exit 0, got exit=$case4_code_between"
fi

# =====================================================================
# Case 5 (dispatch): Write of a new file -- no on-disk read is attempted at all. Exit 0 for
# clean content, exit 2 for a citation-bearing content, no crash/stderr noise either way.
# =====================================================================
case5_file="$EDIT_WORKDIR/case5-new.lua"
if [ -e "$case5_file" ]; then
  fail "Case 5 (dispatch) setup: $case5_file unexpectedly exists before the Write fixture runs"
else
  pass "Case 5 (dispatch) setup: $case5_file does not exist on disk (confirms the Write path reads nothing)"
fi
case5_clean_code="$(hook_exit_code "$case5_file" "clean content, no citation")"
if [ "$case5_clean_code" -eq 0 ]; then
  pass "Case 5a (dispatch): Write of a new file, clean content, exits 0"
else
  fail "Case 5a (dispatch): expected exit 0, got exit=$case5_clean_code"
fi
case5_citation_content="citation-bearing content: task 706"  # task-ref-ok inline test fixture, category 6
case5_citation_code="$(hook_exit_code "$case5_file" "$case5_citation_content")"
if [ "$case5_citation_code" -eq 2 ]; then
  pass "Case 5b (dispatch): Write of a new file, citation-bearing content, exits 2"
else
  fail "Case 5b (dispatch): expected exit 2, got exit=$case5_citation_code"
fi

# =====================================================================
# Case 6 (dispatch): Write that would remove a marker -- the Write's content keeps the citation
# but drops the markers. Exit 2: the Write path never falls back to stale on-disk markers to
# rescue content that no longer carries its own.
# =====================================================================
case6_file="$EDIT_WORKDIR/case6.lua"
case6_disk="$(printf -- '-- %s reason\n-- see task 707 here\n-- %s\n' "$EDIT_MARK_BEGIN" "$EDIT_MARK_END")"  # task-ref-ok inline test fixture, category 6
printf '%s' "$case6_disk" > "$case6_file"
case6_write_content="see task 707 here"  # task-ref-ok inline test fixture, category 6
case6_code="$(hook_exit_code "$case6_file" "$case6_write_content")"
if [ "$case6_code" -eq 2 ]; then
  pass "Case 6 (dispatch): Write that drops on-disk markers but keeps the citation exits 2"
else
  fail "Case 6 (dispatch): expected exit 2, got exit=$case6_code"
fi

# =====================================================================
# Degenerate Edit cases: old_string absent from the on-disk file, and an unreadable target --
# both must take the degrade path (today's payload-only scan of new_string alone), exactly as
# before this phase's region-aware resolution existed.
# =====================================================================
degen_edit_file="$EDIT_WORKDIR/degen-absent.lua"
degen_edit_disk="$(printf -- '-- %s reason\n-- unrelated inside\n-- %s\n' "$EDIT_MARK_BEGIN" "$EDIT_MARK_END")"
degen_edit_new="-- this text never appears on disk, task 708"  # task-ref-ok inline test fixture, category 6
degen_edit_code="$(hook_edit_exit_code "$degen_edit_file" "$degen_edit_disk" "-- this text does not appear on disk" "$degen_edit_new")"
if [ "$degen_edit_code" -eq 2 ]; then
  pass "Degenerate Edit (old_string absent from disk): degrades to a payload-only scan, exits 2 on the unmarked new_string citation"
else
  fail "Degenerate Edit (old_string absent from disk): expected exit 2, got exit=$degen_edit_code"
fi

unreadable_file="$EDIT_WORKDIR/unreadable.lua"
printf '%s' "content" > "$unreadable_file"
chmod 000 "$unreadable_file"
unreadable_new="content, task 709"  # task-ref-ok inline test fixture, category 6
unreadable_out="$(jq -n --arg fp "$unreadable_file" --arg old "content" --arg new "$unreadable_new" \
  '{tool_input: {file_path: $fp, old_string: $old, new_string: $new}}' \
  | bash "$HOOK" 2>&1 1>/dev/null)"
unreadable_code=$?
chmod 644 "$unreadable_file"
if [ "$unreadable_code" -eq 2 ]; then
  pass "Degenerate Edit (unreadable target): degrades to a payload-only scan, exits 2 on the unmarked new_string citation"
else
  fail "Degenerate Edit (unreadable target): expected exit 2, got exit=$unreadable_code out='$unreadable_out'"
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
