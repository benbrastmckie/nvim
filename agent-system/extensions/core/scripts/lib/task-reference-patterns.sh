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
# insensitive, so pair with `-i`), call `is_exempt_path <path>` (which covers both documented
# path-level exempt zones, specs/** and the .memory/** vault), and pipe content through
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
# Returns 0 (exempt) for the two documented path-level exempt zones, 1 (not exempt) for
# everything else. Mirrors the hook's exemption case statement so both repo-relative and
# absolute-prefixed paths are covered.
#
#   specs/**    task-management artifacts, where task numbers are expected and not a citation
#               problem.
#   .memory/**  the memory vault. Every file the memory system writes there carries a
#               provenance field naming the task that produced it (`source: "Task N: ..."` in a
#               memory's frontmatter, and the same string mirrored into memory-index.json), so
#               the vault reports one finding per memory plus one per index entry -- a count that
#               grows with every harvest and never reaches zero. That provenance is structured
#               data written by memory-harvest.sh and /learn, not deliverable prose, and the
#               alternative (an inline marker on each frontmatter line) cannot hold: the index is
#               regenerated wholesale, so its markers would be dropped on every rebuild.
#
# Both zones are layout-independent, which is what makes them safe as a fixed exempt set in a
# lint consumed by repos of differing layout: `specs/` is this system's own task directory and
# `.memory/` is the vault root the memory extension declares in its manifest. See
# context/standards/task-reference-exemptions.md's "Design Principle" section -- the hazard that
# section names is a hard-coded list of SCAN ROOTS, which silently scanned nothing in a consumer
# repo; a documented exempt set subtracted from repo-wide scope is the shape it prescribes.
is_exempt_path() {
  local path="$1"
  case "$path" in
    specs/*|*/specs/*)
      return 0
      ;;
    .memory/*|*/.memory/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# ─── Content-level exemption: marker convention ────────────────────────────────────────────────
#
# Marker convention (documented in context/standards/task-reference-exemptions.md's Exemption
# Taxonomy section, and named by this section without embedding the literal marker tokens, which
# is itself the hazard -- a mention of the full literal in prose is parsed exactly like a real
# marker by the parser below, and three of the five imbalances this repo's own hygiene pass
# found were exactly that):
#   - Block form: a line containing the begin marker opens an exempt region that runs through
#     (and includes) the next line containing the end marker. Comment syntax is irrelevant --
#     markdown, shell, Lua -- because the token is matched as a plain substring, not parsed as a
#     comment.
#   - Inline form: any single line containing the bare marker token (that is not itself a
#     begin/end marker line) is itself exempt.
#   - Both forms REQUIRE a trailing reason naming one of the Exemption Taxonomy's categories.
#     The reason is carried on the begin marker (block form) or on the inline marker line
#     (inline form); the end marker itself may be bare.
#
# Resolution algorithm (depth-counting with an explicit well-formedness verdict, replacing a
# plain boolean toggle): the parser below walks the content once, pushing a line onto a stack on
# a begin marker and popping on an end marker (a stray end marker with nothing on the stack is
# inert -- counted but closes nothing). If the stack is empty at EOF, every begin/end pair
# resolved correctly and the file's marker-delimited regions are exempt exactly as they always
# were. If the stack is NOT empty at EOF, the outermost entry remaining on it (the first begin
# marker pushed that was never popped) names the start of a span that runs to EOF and is NOT
# exempt at all -- it is emitted as ordinary scannable content, regardless of any further nested
# structure inside that span, because an outer promise that never closes backs nothing it
# contains. A bare inline-marker line keeps its own exemption even inside that non-exempt span,
# since it makes no claim about anything other than itself. A line carrying both a begin marker
# and an end marker is a self-contained pair with no effect on the stack. This verdict is why a
# tree-wide marker-hygiene pass had to land before this parser did: an unterminated begin marker
# or a stray end marker now has teeth it never had under the old toggle.
#
# Three entry points share one parser so the two consumers of this library -- the repo-wide lint
# and the write-time hook -- can never diverge on what counts as exempt:
#   - strip_exempt_regions: reads content on stdin, writes it back on stdout with every exempt
#     line removed. Unchanged signature; this is what both consumers already called.
#   - exempt_line_mask: reads content on stdin, writes exactly one "1" (exempt) or "0" (not
#     exempt) per input line, in order. Never strips -- the caller maps mask positions back to
#     line numbers. This is what a region-aware caller (resolving a specific inserted span rather
#     than a whole file) consumes.
#   - marker_balance_report: reads content on stdin, writes one diagnostic line naming the
#     unresolved depth, the first unclosed begin marker's line number, and any stray-end count,
#     when the parse is invalid (unresolved depth above zero, or at least one stray end), and
#     writes nothing when the parse is well-formed.
_trp_scan() {
  local mode="$1"
  awk -v MODE="$mode" '
    {
      lines[NR] = $0
      has_begin = ($0 ~ /task-ref-ok:begin/)
      has_end   = ($0 ~ /task-ref-ok:end/)
      if (has_begin && has_end) {
        kind[NR] = "both"
      } else if (has_begin) {
        kind[NR] = "begin"
        stackn++
        stack[stackn] = NR
      } else if (has_end) {
        kind[NR] = "end"
        if (stackn > 0) { stackn-- } else { stray++ }
      } else if ($0 ~ /task-ref-ok/) {
        kind[NR] = "inline"
      } else {
        kind[NR] = "plain"
      }
    }
    END {
      n = NR
      eof_depth = stackn
      badline = (stackn > 0) ? stack[1] : 0
      depth = 0
      for (i = 1; i <= n; i++) {
        if (badline > 0 && i >= badline) {
          exempt[i] = (kind[i] == "inline") ? 1 : 0
        } else if (kind[i] == "begin") {
          exempt[i] = 1
          depth++
        } else if (kind[i] == "end") {
          exempt[i] = 1
          if (depth > 0) depth--
        } else if (kind[i] == "both" || kind[i] == "inline") {
          exempt[i] = 1
        } else if (depth > 0) {
          exempt[i] = 1
        } else {
          exempt[i] = 0
        }
      }
      if (MODE == "strip") {
        for (i = 1; i <= n; i++) { if (!exempt[i]) print lines[i] }
      } else if (MODE == "mask") {
        for (i = 1; i <= n; i++) { print exempt[i] + 0 }
      } else if (MODE == "report") {
        if (eof_depth > 0 || stray > 0) {
          fu = (badline > 0) ? badline : "-"
          printf "eof_depth=%d first_unclosed=%s stray=%d\n", eof_depth, fu, stray
        }
      }
    }
  '
}

strip_exempt_regions() {
  _trp_scan strip
}

exempt_line_mask() {
  _trp_scan mask
}

marker_balance_report() {
  _trp_scan report
}
