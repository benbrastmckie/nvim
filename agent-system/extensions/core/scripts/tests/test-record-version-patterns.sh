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
# strip, then the BLOCKING or ADVISORY match) and report whether it survived to match.
# =====================================================================
blocking_fires() {
  local line="$1"
  printf '%s\n' "$line" | strip_durable_axis_lines | strip_exempt_regions | grep -qiE "$RV_BLOCKING_ERE"
}
advisory_fires() {
  local line="$1"
  printf '%s\n' "$line" | strip_durable_axis_lines | strip_exempt_regions | grep -qiE "$RV_ADVISORY_ERE"
}

assert_blocking() {
  local label="$1" line="$2"
  if blocking_fires "$line"; then
    pass "BLOCKING positive: $label"
  else
    fail "BLOCKING positive: $label -- expected a match, got none for: $line"
  fi
}
assert_not_blocking() {
  local label="$1" line="$2"
  if blocking_fires "$line"; then
    fail "BLOCKING negative: $label -- unexpectedly matched: $line"
  else
    pass "BLOCKING negative: $label"
  fi
}
assert_advisory() {
  local label="$1" line="$2"
  if advisory_fires "$line"; then
    pass "ADVISORY positive: $label"
  else
    fail "ADVISORY positive: $label -- expected a match, got none for: $line"
  fi
}

# =====================================================================
# BLOCKING positives -- synthesized from the dispatch's forbidden-vocabulary list.
# =====================================================================
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
# strip_exempt_regions: block form and inline form, both with a trailing reason.
# =====================================================================
block_form_input=$'keep this line\nversion-ok:begin durable-axis example, category 3a\nThe widget convention (v2)\nversion-ok:end\nkeep this line too\n'
block_form_output="$(printf '%s' "$block_form_input" | strip_exempt_regions)"
if [[ "$block_form_output" == $'keep this line\nkeep this line too' ]]; then
  pass "strip_exempt_regions: block form removes the marked region, keeps surrounding lines"
else
  fail "strip_exempt_regions: block form -- unexpected output: $block_form_output"
fi

inline_form_input=$'keep this line\nThe widget convention (v2)  version-ok inline example, category 1\nkeep this line too\n'
inline_form_output="$(printf '%s' "$inline_form_input" | strip_exempt_regions)"
if [[ "$inline_form_output" == $'keep this line\nkeep this line too' ]]; then
  pass "strip_exempt_regions: inline form removes only the marked line"
else
  fail "strip_exempt_regions: inline form -- unexpected output: $inline_form_output"
fi

# =====================================================================
# strip_durable_axis_lines: each durable-axis shape is dropped; an unrelated line is kept.
# =====================================================================
durable_input=$'Lean v4.31.0 is the pinned toolchain.\nactions/checkout@v4 runs first.\nthe key pnpm-v1-linux caches node_modules.\nsee book-cert-v2.md for the schema.\nan ordinary sentence with no version language.\n'
durable_output="$(printf '%s' "$durable_input" | strip_durable_axis_lines)"
durable_line_count="$(printf '%s\n' "$durable_output" | grep -c . || true)"
if [[ "$durable_line_count" -eq 1 ]] && echo "$durable_output" | grep -qF "an ordinary sentence"; then
  pass "strip_durable_axis_lines: drops all 4 durable-axis shapes, keeps the unrelated line"
else
  fail "strip_durable_axis_lines: expected 1 surviving line, got: $durable_output"
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
