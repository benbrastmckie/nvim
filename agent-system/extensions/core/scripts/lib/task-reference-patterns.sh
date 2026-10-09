#!/usr/bin/env bash
# task-reference-patterns.sh - Single source of truth for task-number-citation detection.
#
# Exports the pattern variables and exemption logic consumed by BOTH the repo-wide lint script
# (scripts/check-task-references.sh) and the write-time guard hook
# (hooks/validate-no-task-references.sh). Neither consumer defines TASK_SEP, TASK_PATTERN,
# PHASE_PATTERN, or exemption logic locally -- this is the ONLY place they are defined. See
# context/standards/task-reference-exemptions.md's "Exemption Taxonomy" section (companion to
# rules/no-task-references-in-deliverables.md) for the policy this
# code implements.
#
# Usage: `source` this file, then use $TASK_PATTERN / $PHASE_PATTERN with `grep -E` (case-
# insensitive, so pair with `-i`), call `is_exempt_path <path>`, and pipe content through
# `strip_exempt_regions` before scanning it.

# ─── Detection patterns ────────────────────────────────────────────────────────────────────────
# Copied verbatim from the pre-existing write-time hook (the only prior definition anywhere in
# the repo) -- not re-derived, so the lint script and the hook are guaranteed to agree byte-for-
# byte on what counts as a citation.

# Separator group between "task(s)"/"phase" and its number: whitespace (optionally followed by
# "#"), or a single "-", "_", "#". An explicit alternation, NOT a bracket class containing "-"
# (a "-" inside a bracket class can be silently read as a range operator depending on position;
# alternation avoids that trap entirely). Covers "task N", "task-N", "task_N", "task#N", and
# "Task #N" alike (using letter placeholders here rather than a concrete digit sequence, so this
# comment itself does not incidentally match the pattern it describes).
TASK_SEP='([[:space:]]+#?|[-_#])'

# Task-number citation pattern: "task N", "tasks N-M", "task-N", "task_N", "task#N", "Task #N",
# case-insensitive on the "task(s)" token (grep -i handles case; [Tt] kept for readability).
# Whole-word boundaries via \b to avoid matching inside larger identifiers (e.g. "taskbarN").
# shellcheck disable=SC2034  # Exported public contract: consumed by check-task-references.sh,
# validate-no-task-references.sh, and their test (all source this file), not locally unused.
TASK_PATTERN="\\b[Tt]asks?${TASK_SEP}[0-9]+(-[0-9]+)?\\b"

# Task-qualified compound Phase pattern: "task N phase P" or "phase P of task N" only. A bare
# "Phase N" with no adjacent task reference is deliberately NOT matched here -- it is
# indistinguishable from a document's own internal structure (plan headings, skill pipeline
# stages) and would generate constant false positives. The compound form is unambiguously a
# citation of a specs/-scoped plan's internals. Anchored on the same TASK_SEP separator group so
# a hyphenated compound like "task-N phase-P" is caught too.
# shellcheck disable=SC2034  # Same exported public contract as TASK_PATTERN above.
PHASE_PATTERN="\\b([Tt]asks?${TASK_SEP}[0-9]+[[:space:]]+[Pp]hase${TASK_SEP}[0-9]+|[Pp]hase${TASK_SEP}[0-9]+[[:space:]]+of[[:space:]]+[Tt]asks?${TASK_SEP}[0-9]+)\\b"

# ─── Path-level exemption ──────────────────────────────────────────────────────────────────────
# is_exempt_path <path>
#
# Returns 0 (exempt) for any specs/** path -- task-management artifacts, where task numbers are
# expected and not a citation problem. Mirrors the pre-existing hook's exemption case statement
# so both repo-relative and absolute-prefixed paths are covered. Returns 1 (not exempt) for
# everything else.
is_exempt_path() {
  local path="$1"
  case "$path" in
    specs/*|*/specs/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# ─── Content-level exemption: marker convention ────────────────────────────────────────────────
# strip_exempt_regions
#
# Reads content on stdin, writes it back on stdout with exempted lines removed. This is the
# function that prevents lint/hook divergence: neither consumer implements exemption filtering
# itself -- both pipe their candidate content through this function before matching TASK_PATTERN
# or PHASE_PATTERN against what remains.
#
# Marker convention (documented in context/standards/task-reference-exemptions.md's Exemption
# Taxonomy section):
#   - Block form: a line containing the substring "task-ref-ok:begin" opens an exempt region
#     that runs through (and includes) the next line containing "task-ref-ok:end". Comment
#     syntax is irrelevant -- markdown `<!-- -->`, shell `#`, Lua `--` -- because the token is
#     matched as a plain substring, not parsed as a comment.
#   - Inline form: any single line containing the substring "task-ref-ok" (that is not itself a
#     begin/end marker line already handled above) is itself exempt.
#   - Both forms REQUIRE a trailing reason naming one of the Exemption Taxonomy's categories.
#     The reason is carried on the begin marker (block form) or on the inline marker line
#     (inline form); the end marker itself may be bare. This function does not validate the
#     reason text -- that is a human-review concern at the taxonomy table, not a parseable
#     contract -- it only strips whatever lines the begin/end/inline tokens delimit.
strip_exempt_regions() {
  awk '
    /task-ref-ok:begin/ { in_block = 1; next }
    /task-ref-ok:end/   { in_block = 0; next }
    in_block             { next }
    /task-ref-ok/        { next }
    { print }
  '
}
