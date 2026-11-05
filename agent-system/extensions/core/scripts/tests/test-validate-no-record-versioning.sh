#!/usr/bin/env bash
# test-validate-no-record-versioning.sh - Fixture-driven regression suite for
# validate-no-record-versioning.sh's blocking PreToolUse behavior (exit code 2 on a BLOCKING
# finding, exit 0 otherwise -- silent on an ADVISORY-only finding, by this hook's own
# advisory-silent write-time posture).
#
# Drives the hook as a real subprocess: copies it byte-for-byte into an isolated mktemp -d
# workdir (alongside a copy of the shared lib/record-version-patterns.sh library at the exact
# relative layout the hook expects: <workdir>/hooks/validate-no-record-versioning.sh sources
# <workdir>/scripts/lib/record-version-patterns.sh) and pipes a synthetic PreToolUse JSON
# payload on stdin for every case, asserting on the hook's EXIT CODE (2 = blocked, 0 = allowed)
# and on stderr emptiness/non-emptiness, never on stdout. The hook itself is never instrumented
# or modified for testability -- it never learns it is under test.
#
# Follows the core shell-test convention in context/standards/shell-script-testing.md:
# pass()/fail()/info() helpers, PASSED/FAILED integer counters, mktemp -d workdir with a
# trap EXIT cleanup, exit 0 on all-pass and exit 1 on any-fail.
#
# NOTE on this file's own marker hygiene: the fixture blocks below deliberately embed literal
# record-versioning-language strings as TEST DATA (verifying the hook recognizes them in scanned
# content). Per this repo's own rules/no-record-versioning-in-deliverables.md, the *source lines
# of this test file itself* that contain those literal strings must be marked exempt (Exemption
# Taxonomy category: test fixture for the reference-pattern detector itself) or the repo-wide
# lint and the write-time guard hook would both flag this file. Each fixture-content line that
# must remain LITERALLY UNMARKED as far as the hook's own content-scan is concerned (to test the
# blocking path) is instead exempted at the FILE level via a trailing inline `# version-ok` bash
# comment on its assignment line, mirroring the sibling suite's `# task-ref-ok` convention: the
# shared library's parser strips that comment as a whole raw line, so it never becomes part of
# the shell string value the hook receives.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
HOOK_SRC="$SCRIPT_DIR/../../hooks/validate-no-record-versioning.sh"
LIB_SRC="$SCRIPT_DIR/../lib/record-version-patterns.sh"

PASSED=0
FAILED=0

# shellcheck disable=SC2329

if [ ! -f "$HOOK_SRC" ]; then
  echo "ERROR: expected validate-no-record-versioning.sh at $HOOK_SRC" >&2
  exit 1
fi

if [ ! -f "$LIB_SRC" ]; then
  echo "ERROR: expected shared library record-version-patterns.sh at $LIB_SRC" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required to build synthetic PreToolUse payloads and is not on PATH" >&2
  exit 1
fi

common_test_workdir_init

# Mirror the hook's expected sibling layout: hooks/validate-no-record-versioning.sh sources
# ../scripts/lib/record-version-patterns.sh relative to its OWN directory.
mkdir -p "$WORKDIR/hooks" "$WORKDIR/scripts/lib"
HOOK="$WORKDIR/hooks/validate-no-record-versioning.sh"
cp "$HOOK_SRC" "$HOOK"
chmod +x "$HOOK"
cp "$LIB_SRC" "$WORKDIR/scripts/lib/record-version-patterns.sh"

# run_hook <file_path> <content>
# Builds a synthetic Write-shaped PreToolUse payload via jq (safe against quotes/parens in
# content) and pipes it to the copied hook. Echoes "EXITCODE|STDERR" so callers can assert on
# both.
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

# run_hook_edit <file_path> <old_string> <new_string>
# Builds a synthetic Edit-shaped PreToolUse payload (no on-disk file needed: this hook is
# payload-only and never reads disk for either the Write or Edit path).
run_hook_edit() {
  local file_path="$1" old_string="$2" new_string="$3" out exit_code
  out="$(jq -n --arg fp "$file_path" --arg old "$old_string" --arg new "$new_string" \
    '{tool_input: {file_path: $fp, old_string: $old, new_string: $new}}' \
    | bash "$HOOK" 2>&1 1>/dev/null)"
  exit_code=$?
  printf '%s|%s' "$exit_code" "$out"
}

# assert_triggers <label> <file_path> <content>
# Expects exit 2 (blocked) and non-empty stderr.
assert_triggers() {
  local label="$1" file_path="$2" content="$3" result code stderr_out
  result="$(run_hook "$file_path" "$content")"
  code="${result%%|*}"
  stderr_out="${result#*|}"
  if [ "$code" -eq 2 ] && [ -n "$stderr_out" ]; then
    common_test_pass "$label: exits 2 with stderr message"
  else
    common_test_fail "$label: expected exit 2 + stderr, got exit=$code stderr='$stderr_out'"
  fi
}

# assert_silent <label> <file_path> <content>
# Expects exit 0 (allowed), with no assertion on stderr content.
assert_silent() {
  local label="$1" file_path="$2" content="$3" code
  code="$(hook_exit_code "$file_path" "$content")"
  if [ "$code" -eq 0 ]; then
    common_test_pass "$label: exits 0 (allowed)"
  else
    common_test_fail "$label: expected exit 0, got exit=$code"
  fi
}

# assert_truly_silent <label> <file_path> <content>
# Expects exit 0 AND empty stderr -- used for the advisory-only case, which must never print
# anything (this hook's advisory-silent posture, not merely "doesn't block").
assert_truly_silent() {
  local label="$1" file_path="$2" content="$3" result code stderr_out
  result="$(run_hook "$file_path" "$content")"
  code="${result%%|*}"
  stderr_out="${result#*|}"
  if [ "$code" -eq 0 ] && [ -z "$stderr_out" ]; then
    common_test_pass "$label: exits 0 with no stderr output (advisory-silent)"
  else
    common_test_fail "$label: expected exit 0 + empty stderr, got exit=$code stderr='$stderr_out'"
  fi
}

# =====================================================================
# Blocking cases (expect exit 2 + non-empty, rule-naming stderr)
# =====================================================================
blocking_heading_fixture="## The widget convention (v2)"  # version-ok inline test fixture, category: test fixture for the reference-pattern detector itself
assert_triggers "blocking: unmarked bare-parenthesized heading on markdown path" \
  "docs/notes.md" "$blocking_heading_fixture"

blocking_supersession_fixture="This record supersedes v1 of the convention entirely."  # version-ok inline test fixture, category: test fixture for the reference-pattern detector itself
assert_triggers "blocking: supersession clause with vN token in the same clause" \
  "docs/notes.md" "$blocking_supersession_fixture"

blocking_edit_new="## The widget convention (v2)"  # version-ok inline test fixture, category: test fixture for the reference-pattern detector itself
result="$(run_hook_edit "docs/notes.md" "old heading" "$blocking_edit_new")"
code="${result%%|*}"
stderr_out="${result#*|}"
if [ "$code" -eq 2 ] && [ -n "$stderr_out" ]; then
  common_test_pass "blocking: Edit-shaped payload with blocking new_string exits 2 with stderr"
else
  common_test_fail "blocking: Edit-shaped payload expected exit 2 + stderr, got exit=$code stderr='$stderr_out'"
fi

# Rule-naming check: the stderr message must name the rule file, so an author knows which
# policy document to consult.
result="$(run_hook "docs/notes.md" "$blocking_heading_fixture")"
stderr_out="${result#*|}"
if printf '%s' "$stderr_out" | grep -q "no-record-versioning-in-deliverables.md"; then
  common_test_pass "blocking: stderr message names the rule file"
else
  common_test_fail "blocking: stderr message does not name the rule file: '$stderr_out'"
fi

# =====================================================================
# Allowed cases (expect exit 0)
# =====================================================================
assert_silent "exemption: same blocking content at relative specs/** path" \
  "specs/926_foo/plans/01_plan.md" "$blocking_heading_fixture"
assert_silent "exemption: same blocking content at absolute-prefixed specs/** path" \
  "/abs/prefix/specs/926_foo/plans/01_plan.md" "$blocking_heading_fixture"

advisory_only_fixture="This option is no longer supported."
assert_truly_silent "advisory-only: bare past-tense vocabulary, no adjacent vN token" \
  "docs/notes.md" "$advisory_only_fixture"

marked_inline_fixture="## The widget convention (v2)  version-ok inline test fixture"  # version-ok inline test fixture, category: test fixture for the reference-pattern detector itself
assert_silent "marker: inline version-ok on the blocking line" \
  "docs/notes.md" "$marked_inline_fixture"

marked_block_fixture="$(printf '<!-- version-ok:begin quoted historical anti-pattern -->\n## The widget convention (v2)\n<!-- version-ok:end -->\n')"  # version-ok inline test fixture, category: test fixture for the reference-pattern detector itself
assert_silent "marker: version-ok:begin/version-ok:end block around the blocking line" \
  "docs/notes.md" "$marked_block_fixture"

durable_axis_fixture="$(printf 'Stay on v4.31.0 for now.\nSchema file is book-cert-v2.md.\nCache key: elan-v2-linux.\n')"
assert_silent "durable-axis: toolchain pin + schema filename + CI cache-key segment, all three axes" \
  "docs/notes.md" "$durable_axis_fixture"

non_markdown_heading_fixture="# The widget convention (v2)"  # version-ok inline test fixture, category: test fixture for the reference-pattern detector itself
assert_silent "path-class: heading sub-branch excluded off a non-markdown path" \
  "scripts/foo.sh" "$non_markdown_heading_fixture"

# =====================================================================
# Degraded-library cases (expect exit 0 plus non-empty warning stderr)
# =====================================================================
NOLIBDIR="$(mktemp -d)"
mkdir -p "$NOLIBDIR/hooks"
cp "$HOOK_SRC" "$NOLIBDIR/hooks/validate-no-record-versioning.sh"
chmod +x "$NOLIBDIR/hooks/validate-no-record-versioning.sh"
nolib_out="$(jq -n --arg fp "docs/notes.md" --arg c "$blocking_heading_fixture" \
  '{tool_input: {file_path: $fp, content: $c}}' \
  | bash "$NOLIBDIR/hooks/validate-no-record-versioning.sh" 2>&1 1>/dev/null)"
nolib_code=$?
rm -rf "$NOLIBDIR"
if [ "$nolib_code" -eq 0 ] && [ -n "$nolib_out" ]; then
  common_test_pass "shared-library-missing: fails open (exit 0) with a warning"
else
  common_test_fail "shared-library-missing: expected exit 0 + warning, got exit=$nolib_code out='$nolib_out'"
fi

STALEDIR="$(mktemp -d)"
mkdir -p "$STALEDIR/hooks" "$STALEDIR/scripts/lib"
cp "$HOOK_SRC" "$STALEDIR/hooks/validate-no-record-versioning.sh"
chmod +x "$STALEDIR/hooks/validate-no-record-versioning.sh"
cat > "$STALEDIR/scripts/lib/record-version-patterns.sh" << 'STALEEOF'
#!/usr/bin/env bash
# Deliberately minimal/stale stand-in: defines is_exempt_path but NOT
# strip_durable_axis_lines/strip_exempt_regions/rv_grep_blocking/rv_grep_advisory.
is_exempt_path() {
  case "$1" in
    specs/*|*/specs/*) return 0 ;;
    *) return 1 ;;
  esac
}
STALEEOF
stale_out="$(jq -n --arg fp "docs/notes.md" --arg c "$blocking_heading_fixture" \
  '{tool_input: {file_path: $fp, content: $c}}' \
  | bash "$STALEDIR/hooks/validate-no-record-versioning.sh" 2>&1 1>/dev/null)"
stale_code=$?
rm -rf "$STALEDIR"
if [ "$stale_code" -eq 0 ] && [ -n "$stale_out" ]; then
  common_test_pass "stale-library (missing rv_grep_blocking): fails open (exit 0) with a warning"
else
  common_test_fail "stale-library: expected exit 0 + warning, got exit=$stale_code out='$stale_out'"
fi

# =====================================================================
# Degenerate-input fixtures: empty file_path / empty content both exit 0
# =====================================================================
degenerate_fixture_content="$blocking_heading_fixture"
degenerate_code="$(hook_exit_code "" "$degenerate_fixture_content")"
if [ "$degenerate_code" -eq 0 ]; then
  common_test_pass "degenerate: empty file_path exits 0"
else
  common_test_fail "degenerate: empty file_path expected exit 0, got exit=$degenerate_code"
fi

degenerate_code="$(hook_exit_code "docs/notes.md" "")"
if [ "$degenerate_code" -eq 0 ]; then
  common_test_pass "degenerate: empty content exits 0"
else
  common_test_fail "degenerate: empty content expected exit 0, got exit=$degenerate_code"
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
