#!/usr/bin/env bash
# test-record-version-patterns.sh - Fixture-driven regression suite for
# scripts/lib/record-version-patterns.sh, the single sourced anchor for record-versioning-
# language detection patterns, durable-axis discrimination, BLOCKING/ADVISORY tiering, and the
# path-level/marker-level exemption helpers (see
# context/standards/record-version-exemptions.md's "Exemption Taxonomy" and "Forbidden
# Categories and Tiers" sections for the policy this library implements).
#
# Structural model: scripts/tests/test-phase-heading-patterns.sh (pass()/fail()/info() helpers,
# PASSED/FAILED integer counters, exit 0 on all-pass / exit 1 on any-fail, deploy-tree-first /
# source-store-fallback library resolution). This suite sources the library directly rather than
# driving a subprocess, since the library exports shell functions and pattern variables meant to
# be sourced, not a standalone executable.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (library
# not found at any candidate path).
#
# NOTE on this file's own version-ok markers: the BLOCKING-positive fixture block below
# deliberately embeds literal record-versioning-language strings as TEST DATA (the exact
# vocabulary the library exists to detect). Per this repo's own
# rules/no-record-versioning-in-deliverables.md, the *source lines of this test file itself*
# that contain those literal strings must be marked exempt (Exemption Taxonomy category: test
# fixture for the reference-pattern detector itself) or the repo-wide lint
# (scripts/check-record-versioning.sh) and the write-time guard hook would both flag this file.
# The fixture block is wrapped in a single version-ok:begin/end pair (mirroring this convention's
# existing precedent in scripts/tests/test-check-task-references.sh for the sibling
# task-reference lint). The BLOCKING-negative, ADVISORY, and heading-form-discriminator fixture
# blocks below do NOT need marking: this file is itself a non-markdown (`.sh`) path, so Phase 2's
# path-class gate already excludes the heading branch when the lint scans this file, and the
# other blocks' content never matches the non-heading BLOCKING group's case-sensitive pass.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

LIB_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/lib/record-version-patterns.sh"
  "$SCRIPT_DIR/../lib/record-version-patterns.sh"
)
LIB=""
for candidate in "${LIB_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    LIB="$candidate"
    break
  fi
done
if [[ -z "$LIB" ]]; then
  echo "ERROR: shared library record-version-patterns.sh not found at any of:" >&2
  for candidate in "${LIB_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi
# shellcheck disable=SC1090
. "$LIB"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
# shellcheck disable=SC2329
info() { echo "[INFO] $1"; }

# =====================================================================
# Helper: run a single line through the full consumer pipeline (durable-axis strip, then marker
# strip, then the BLOCKING or ADVISORY match via `rv_grep_blocking`/`rv_grep_advisory`, never the
# raw `$RV_BLOCKING_ERE`/`$RV_ADVISORY_ERE` directly) and report whether it survived to match.
# `<path>` defaults to a markdown path so every pre-existing assertion below -- none of which was
# written to be path-sensitive -- keeps its prior, path-class-agnostic verdict unchanged; a case
# testing the Phase 2 path-class gate or the non-markdown case-sensitivity narrowing passes a
# `.sh`/non-markdown path explicitly as the third argument.
# =====================================================================
blocking_fires() {
  local line="$1" path="${2:-fixture.md}"
  printf '%s\n' "$line" | strip_durable_axis_lines | strip_exempt_regions | rv_grep_blocking "$path" | grep -q .
}
advisory_fires() {
  local line="$1" path="${2:-fixture.md}"
  printf '%s\n' "$line" | strip_durable_axis_lines | strip_exempt_regions | rv_grep_advisory "$path" | grep -q .
}

assert_blocking() {
  local label="$1" line="$2" path="${3:-fixture.md}"
  if blocking_fires "$line" "$path"; then
    pass "BLOCKING positive: $label"
  else
    fail "BLOCKING positive: $label -- expected a match, got none for: $line"
  fi
}
assert_not_blocking() {
  local label="$1" line="$2" path="${3:-fixture.md}"
  if blocking_fires "$line" "$path"; then
    fail "BLOCKING negative: $label -- unexpectedly matched: $line"
  else
    pass "BLOCKING negative: $label"
  fi
}
assert_advisory() {
  local label="$1" line="$2" path="${3:-fixture.md}"
  if advisory_fires "$line" "$path"; then
    pass "ADVISORY positive: $label"
  else
    fail "ADVISORY positive: $label -- expected a match, got none for: $line"
  fi
}

# =====================================================================
# BLOCKING positives -- synthesized from the dispatch's forbidden-vocabulary list.
# =====================================================================
# version-ok:begin fixture-content block, test fixture for the record-version detector itself
# (Exemption Taxonomy category: test fixture for the reference-pattern detector itself; see this
# file's header NOTE for why these literal lines must be marked)
assert_blocking "page-level label, heading form" \
  "## The widget convention (v2)"
assert_blocking "page-level label, Status line form" \
  '**Status**: v2, accepted 2026-01-01; supersedes v1'
assert_blocking "version-qualified supersession, 'supersedes v1'" \
  "This record supersedes v1 of the convention entirely."
assert_blocking "version-qualified supersession, v-token then supersede" \
  "v2 of this document supersedes the earlier draft."
assert_blocking "(v1 Decision N) attribution" \
  "Rejected on cost grounds. (v1 Decision 4)"
assert_blocking "migration claim: carried forward from v1" \
  "This field was carried forward from v1 without modification."
assert_blocking "migration claim: every v1 field removed" \
  "Every v1 field removed in favor of the new shape."
assert_blocking "bare-past-tense escalated by adjacent v-token" \
  "This clause no longer applies now that v2 ships."
# version-ok:end

# =====================================================================
# Heading-form discriminator (Phase 2): path-class gating (the heading sub-branches apply only
# to a markdown path) plus label-position narrowing within markdown (bare-parenthesized at any
# heading level; page-title restricted to H1). The two must-pass cases named explicitly by the
# plan: the pre-existing H2 bare-parenthesized positive above must still fire, and every
# pre-existing real negative above must still not fire -- both already re-confirmed by the full
# suite run above this block landed.
# =====================================================================

# True positives: markdown H1 page-title labels -- confirmed real, un-swept instances.
assert_blocking "markdown H1 page-title label, un-swept instance (Himalaya)" \
  "# Himalaya Plugin Architecture V2: Elegant Module Distribution"
assert_blocking "markdown H1 page-title label, un-swept instance (Draft System)" \
  "# Draft System v2 Documentation"

# True negatives: label-position narrowing within markdown.
assert_not_blocking "markdown non-H1 heading, bare vN with no parens (external-tool version)" \
  "### Tailwind v4 Optimizations"
assert_not_blocking "markdown H2 heading, parenthesized-with-noun (the numbered-ruling idiom)" \
  "## Admission Posture for an Absent file_scope (v6 Ruling)"

# True negatives: path-class gating -- a `#`-prefixed line in a non-markdown path is a shell
# comment, not an ATX heading, so the heading sub-branches must not fire at all.
assert_not_blocking "non-markdown path, heading-shaped shell comment" \
  "# V3 safety gate" "fixture.sh"

# True negatives: non-markdown case-sensitivity narrowing. Each line reproduces the measured
# collision shape (an uppercase `V<N>` internal-invariant label adjacent to past-tense-escalation
# vocabulary) that flooded under case-INsensitive matching; matched case-sensitively against a
# non-markdown path, the lowercase-only `v[0-9]+` sub-pattern no longer matches the uppercase
# `V<N>` label.
assert_not_blocking "non-markdown path, uppercase V<N> label adjacent to 'used to'" \
  "the --task flag (V5 contended-path lease) and used to resolve the task directory" "fixture.sh"
assert_not_blocking "non-markdown path, uppercase V<N> label adjacent to 'no longer'" \
  "with the V8 mismatch predicate inverted, the scenario no longer exits 5" "fixture.sh"

# =====================================================================
# Durable-axis extension (Phase 3): bare major-version mentions anchored to a schema/format
# noun or to the narrow, literal named-external-tool anchor (Tailwind/Tailwind CSS). Neither
# shape is a bare `\bv[0-9]+\b` catch-all -- each requires its concrete anchor on the same line.
# =====================================================================
assert_not_blocking "durable axis: schema-anchored bare major version, noun-then-vN" \
  "## Global Index Schema (v2)"
assert_not_blocking "durable axis: named-external-tool bare major version (Tailwind CSS)" \
  "# Tailwind CSS v4 Reference"
# Re-asserted true positive: the taxonomy's own motivating case has no schema/format/tool
# anchor and must stay BLOCKING -- the durable-axis extension must not have swallowed it.
assert_blocking "re-asserted: page-level label with no durable-axis anchor" \
  "## The widget convention (v2)"

# =====================================================================
# BLOCKING negatives -- real lines drawn from the live Verification repo corpus (post-sweep),
# each of which must survive as non-BLOCKING once durable-axis stripping is applied.
# =====================================================================
assert_not_blocking "real negative: dotted semver toolchain pin" \
  "Stay on v4.31.0; Mathlib confined to Aeneas bridge packages."
assert_not_blocking "real negative: schema filename mention" \
  "see [book-cert-v2.md](../books/schema/book-cert-v2.md) for the normative schema."
assert_not_blocking "real negative: CI cache-key epoch segment" \
  "the key elan-v2-linux caches the toolchain install."
assert_not_blocking "real negative: bare 'supersedes' with no version token" \
  "This record supersedes rule 3 of documentation-architecture.md."
assert_not_blocking "real negative: bare past-tense, no adjacent version token" \
  "This clause no longer applies, for unrelated reasons."
assert_not_blocking "real negative: dated Amended-by cross-document note" \
  '**Amended by** [books/convention.md](../../books/convention.md), 2026-09-30: this decision fixes identity to the certificate.'
# shellcheck disable=SC2016
assert_not_blocking "real negative: schema self-declaration heading, backtick + trailing vN" \
  '# `book.toml` v2 — normative schema'
# shellcheck disable=SC2016
assert_not_blocking "real negative: schema self-declaration heading, vN embedded in backticks" \
  '# `book-evidence-observation-v1` — the repo-side OBSERVATION contract'
# shellcheck disable=SC2016
assert_not_blocking "real negative: filename-fragment mention inside backticks" \
  'document is amended in place rather than superseded by a `-v2` filename, following precedent.'

# =====================================================================
# ADVISORY positives.
# =====================================================================
assert_advisory "bare past-tense: no longer" "This option is no longer supported."
assert_advisory "bare past-tense: previously" "This value was previously computed differently."
assert_advisory "bare past-tense: formerly" "formerly known as the three-layer aim"
assert_advisory "bare past-tense: used to" "This workflow used to run on every push."
assert_advisory "bare past-tense: withdrawn" "The proposal is withdrawn, and the reason is now measured."

# =====================================================================
# is_exempt_path: path-level exemption (taxonomy zone 1).
# =====================================================================
if is_exempt_path "specs/280_example/reports/01.md"; then
  pass "is_exempt_path: specs/** path returns 0 (exempt)"
else
  fail "is_exempt_path: specs/** path unexpectedly returned non-zero"
fi
if is_exempt_path "nested/specs/sub/file.md"; then
  pass "is_exempt_path: nested */specs/* path returns 0 (exempt)"
else
  fail "is_exempt_path: nested */specs/* path unexpectedly returned non-zero"
fi
if is_exempt_path "agent-system/extensions/core/rules/foo.md"; then
  fail "is_exempt_path: non-specs path unexpectedly returned 0 (exempt)"
else
  pass "is_exempt_path: non-specs path returns 1 (not exempt)"
fi

# =====================================================================
# strip_exempt_regions: block form and inline form, both with a trailing reason. BLANKS the
# marked lines in place (never deletes -- see the library header's blanking note), so the
# expected output keeps one empty line per stripped source line, preserving line position.
# =====================================================================
block_form_input=$'keep this line\nversion-ok:begin durable-axis example, category 3a\nThe widget convention (v2)\nversion-ok:end\nkeep this line too\n'
block_form_output="$(printf '%s' "$block_form_input" | strip_exempt_regions)"
if [[ "$block_form_output" == $'keep this line\n\n\n\nkeep this line too' ]]; then
  pass "strip_exempt_regions: block form blanks the marked region, keeps surrounding lines and line count"
else
  fail "strip_exempt_regions: block form -- unexpected output: $block_form_output"
fi

inline_form_input=$'keep this line\nThe widget convention (v2)  version-ok inline example, category 1\nkeep this line too\n'
inline_form_output="$(printf '%s' "$inline_form_input" | strip_exempt_regions)"
if [[ "$inline_form_output" == $'keep this line\n\nkeep this line too' ]]; then
  pass "strip_exempt_regions: inline form blanks only the marked line"
else
  fail "strip_exempt_regions: inline form -- unexpected output: $inline_form_output"
fi

# =====================================================================
# strip_durable_axis_lines: each durable-axis shape is blanked; an unrelated line is kept.
# =====================================================================
durable_input=$'Lean v4.31.0 is the pinned toolchain.\nactions/checkout@v4 runs first.\nthe key pnpm-v1-linux caches node_modules.\nsee book-cert-v2.md for the schema.\nan ordinary sentence with no version language.\n'
durable_output="$(printf '%s' "$durable_input" | strip_durable_axis_lines)"
durable_line_count="$(printf '%s\n' "$durable_output" | grep -c . || true)"
if [[ "$durable_line_count" -eq 1 ]] && echo "$durable_output" | grep -qF "an ordinary sentence"; then
  pass "strip_durable_axis_lines: drops all 4 durable-axis shapes, keeps the unrelated line"
else
  fail "strip_durable_axis_lines: expected 1 surviving line, got: $durable_output"
fi
durable_total_lines="$(printf '%s\n' "$durable_output" | wc -l)"
if [[ "$durable_total_lines" -eq 5 ]]; then
  pass "strip_durable_axis_lines: blanks in place -- total line count unchanged (5 in, 5 out)"
else
  fail "strip_durable_axis_lines: expected 5 total lines (position-preserving blank), got: $durable_total_lines"
fi

# =====================================================================
# Blank-preservation: a line AFTER a stripped durable-axis line keeps its REAL line number once
# piped through rv_grep_blocking -- the concrete line-number-fidelity regression this phase
# fixes (measured drift: a finding reported at a post-strip line N was really at N+1).
# =====================================================================
blank_preservation_input=$'Lean v4.31.0 is the pinned toolchain.\n## The widget convention (v2)\n'
blank_preservation_output="$(printf '%s' "$blank_preservation_input" | strip_durable_axis_lines | strip_exempt_regions | rv_grep_blocking "fixture.md")"
if printf '%s\n' "$blank_preservation_output" | grep -qE '^2:'; then
  pass "blank-preservation: a finding after a blanked durable-axis line reports its REAL line number (2, not 1)"
else
  fail "blank-preservation: expected a finding at line 2, got: $blank_preservation_output"
fi

# =====================================================================
# rv_is_markdown_path: the single place the markdown/non-markdown path class is decided.
# =====================================================================
if rv_is_markdown_path "docs/README.md"; then
  pass "rv_is_markdown_path: *.md path returns 0 (markdown)"
else
  fail "rv_is_markdown_path: *.md path unexpectedly returned non-zero"
fi
if rv_is_markdown_path "notes.markdown"; then
  pass "rv_is_markdown_path: *.markdown path returns 0 (markdown)"
else
  fail "rv_is_markdown_path: *.markdown path unexpectedly returned non-zero"
fi
if rv_is_markdown_path "scripts/check-record-versioning.sh"; then
  fail "rv_is_markdown_path: *.sh path unexpectedly returned 0 (markdown)"
else
  pass "rv_is_markdown_path: *.sh path returns 1 (not markdown)"
fi

# =====================================================================
# rv_grep_blocking / rv_grep_advisory: same verdicts as the direct-ERE assertions above, through
# the matching-function seam neither consumer bypasses.
# =====================================================================
rv_blocking_fires() {
  printf '%s\n' "$1" | strip_durable_axis_lines | strip_exempt_regions | rv_grep_blocking "fixture.md" | grep -q .
}
rv_advisory_fires() {
  printf '%s\n' "$1" | strip_durable_axis_lines | strip_exempt_regions | rv_grep_advisory "fixture.md" | grep -q .
}
if rv_blocking_fires "## The widget convention (v2)"; then
  pass "rv_grep_blocking: agrees with the direct-ERE BLOCKING positive"
else
  fail "rv_grep_blocking: expected a match for the page-level label fixture, got none"
fi
if rv_blocking_fires "Stay on v4.31.0; Mathlib confined to Aeneas bridge packages."; then
  fail "rv_grep_blocking: unexpectedly matched a durable-axis real negative"
else
  pass "rv_grep_blocking: agrees with the direct-ERE BLOCKING negative"
fi
if rv_advisory_fires "This option is no longer supported."; then
  pass "rv_grep_advisory: agrees with the direct-ERE ADVISORY positive"
else
  fail "rv_grep_advisory: expected a match for the bare past-tense fixture, got none"
fi

# =====================================================================
# rv_grep_blocking exit-status contract on a NON-MARKDOWN path: a regression guard for a defect
# caught during implementation, where the non-markdown branch's merged-and-sorted pipeline always
# returned `sort`'s own exit status (0) regardless of whether any line actually matched, silently
# breaking the grep-compatible 0=found/1=not-found contract a direct caller of this function (as
# opposed to one piping its output through `grep -q .`, which is immune) would rely on.
# =====================================================================
if printf '%s\n' "the --task flag (V5 contended-path lease) and used to resolve" \
     | strip_durable_axis_lines | strip_exempt_regions | rv_grep_blocking "fixture.sh" >/dev/null; then
  fail "rv_grep_blocking: non-markdown path with NO findings unexpectedly exited 0"
else
  pass "rv_grep_blocking: non-markdown path with no findings exits 1 (not merely empty output)"
fi
if printf '%s\n' "This record supersedes v1 of the convention entirely." \
     | strip_durable_axis_lines | strip_exempt_regions | rv_grep_blocking "fixture.sh" >/dev/null; then
  pass "rv_grep_blocking: non-markdown path WITH a finding exits 0"
else
  fail "rv_grep_blocking: non-markdown path with a real finding unexpectedly exited non-zero"
fi

# =====================================================================
# Grouping variables exist and are non-empty (both consumers inherit tiering from these, never
# defining their own).
# =====================================================================
if [[ -n "${RV_BLOCKING_ERE:-}" ]]; then
  pass "RV_BLOCKING_ERE is exported and non-empty"
else
  fail "RV_BLOCKING_ERE is missing or empty"
fi
if [[ -n "${RV_ADVISORY_ERE:-}" ]]; then
  pass "RV_ADVISORY_ERE is exported and non-empty"
else
  fail "RV_ADVISORY_ERE is missing or empty"
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
