#!/usr/bin/env bash
# plan-file-scope-harvest.sh - Harvest the deduplicated union of every phase's "Files to modify"
# path list from a plan file, emitting a JSON array of strings on stdout.
#
# This formalizes an already-universal convention (see context/formats/plan-format.md's
# "Files to modify" per-phase field) rather than inventing a new one -- see this task's own
# reports/plans for the coverage measurement. It is the ONE consumer of that field that depends
# on list-item shape rather than only the heading string; see plan-format.md's "Consumers of this
# field" subsection for the other three (heading-name-stability-only) consumers, which this
# script's own output feeds (via callers) but never itself parses their code paths.
#
# Contract:
#   Usage:  plan-file-scope-harvest.sh <plan-file-path>
#   stdout: a compact JSON array of strings, sorted and deduplicated, e.g. ["a/b.sh","c/d.md"].
#           `[]` when the plan carries no harvestable "Files to modify" path -- this is a normal,
#           exit-0 outcome, never an error.
#   Exit codes: 0 on success (including the empty-result case above); non-zero is reserved for
#           genuine usage errors (missing argument, unreadable/missing file) and is NEVER used to
#           signal "found nothing".
#
# Grammar accepted (mirrors plan-format.md's "Files to modify" field definition verbatim -- do
# not let this comment and that definition drift apart):
#   - Block header: `**Files to modify**:` or `**Files to modify:**` (both accepted punctuation
#     forms per plan-format.md's "Field-punctuation tolerance" rule), optionally prefixed by a
#     single leading list marker (`- **Files to modify**:`) -- plan-format.md's own compact
#     example template renders every per-phase field this way, and at least one real local plan
#     (found during this phase's verification, not the research report) does too, so both the
#     bare and list-item-wrapped header forms are accepted.
#   - Inside a block, a NEW path entry starts on a line matching `^[ \t]*-[ \t]*\`` (optional
#     leading indentation, a list marker, then a backtick, allowing optional whitespace between);
#     the first backtick-delimited token on that line is the path. Any trailing
#     ` - {description}` text after the closing backtick is discarded. Leading indentation is
#     tolerated because the list-item-wrapped header form above indents its entries one level.
#   - Every other line inside the block -- an indented wrapped continuation line, a "none
#     planned" prose sentinel, or a blank line not immediately followed by another entry --
#     contributes no path. This is not a parse error; it is the documented "contributes nothing"
#     behavior from plan-format.md and this task's Risk table.
#   - The block ends at the first of: a `###` heading, a new bolded field label line (`**Field**:`
#     / `**Field:**`, itself optionally list-marker-prefixed the same way the header can be), or a
#     blank line NOT immediately followed by another entry line.
#   - `**Scope Hypothesis**:` is deliberately never treated as a second harvest source (see
#     plan-format.md's "Counts-are-hypotheses obligation" cross-reference) -- only the
#     `Files to modify` block above is read.
#
# Never stats, resolves, or filesystem-validates a harvested path. `file_scope` is documented
# "prospective, not filesystem-validated" (context/schemas/state-schema.json), and a path a plan
# names for a file it will CREATE is exactly what must be harvested, not filtered out.

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") <plan-file-path>" >&2
  exit 1
fi

PLAN_FILE="$1"

if [[ ! -f "$PLAN_FILE" ]]; then
  echo "ERROR: plan file not found or not a regular file: $PLAN_FILE" >&2
  exit 1
fi
if [[ ! -r "$PLAN_FILE" ]]; then
  echo "ERROR: plan file not readable: $PLAN_FILE" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required to emit the harvested JSON array and is not on PATH" >&2
  exit 1
fi

# awk state machine: in_block tracks whether we are currently inside a "Files to modify" block.
# One path per output line; sorting/deduplication/JSON-encoding is left to the jq stage below so
# this stage stays a pure line-oriented extractor.
#
# `strip_marker()` removes a single optional leading list marker ("- ", with any leading
# whitespace) so the header and field-label checks work identically whether a generator rendered
# the field bare (`**Files to modify**:`) or as its own list item (`- **Files to modify**:`, the
# form plan-format.md's own compact example template uses for every field). Entry-line detection
# is handled separately (it must recognize the marker, not strip it, since the marker is what
# identifies a line as an entry in the first place) and tolerates leading indentation, since the
# list-item-wrapped header form indents its entries one level.
extract_paths() {
  awk '
    function strip_marker(l,    s) {
      s = l
      sub(/^[ \t]*-[ \t]+/, "", s)
      return s
    }
    function emit_entry(l,    rest, idx, path) {
      rest = l
      sub(/^[ \t]*-[ \t]*`/, "", rest)
      idx = index(rest, "`")
      if (idx > 0) {
        path = substr(rest, 1, idx - 1)
        if (path != "") print path
      }
    }
    BEGIN { in_block = 0 }
    {
      line = $0
      stripped = strip_marker(line)
      if (in_block == 0) {
        if (stripped ~ /^\*\*Files to modify\*\*:/ || stripped ~ /^\*\*Files to modify:\*\*/) {
          in_block = 1
        }
        next
      }
      # in_block == 1 from here down.
      if (line ~ /^### /) { in_block = 0; next }
      if (stripped ~ /^\*\*[A-Za-z]/) { in_block = 0; next }
      if (line ~ /^[ \t]*-[ \t]*`/) {
        emit_entry(line)
        next
      }
      if (line ~ /^[ \t]*$/) {
        # Blank line: only stays inside the block if the very next line is another entry.
        if ((getline nextline) > 0) {
          if (nextline ~ /^[ \t]*-[ \t]*`/) {
            emit_entry(nextline)
            next
          }
          in_block = 0
          next
        }
        in_block = 0
        next
      }
      # Continuation line (wrapped description text) or a prose sentinel: contributes nothing.
      next
    }
  ' "$1"
}

extract_paths "$PLAN_FILE" | jq -R -s -c 'split("\n") | map(select(length > 0)) | unique'
