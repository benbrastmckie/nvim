#!/usr/bin/env bash
# literature-term-match.sh - Shared Tier 1 keyword-matching helper (source-only)
#
# Usage (sourced, never executed directly):
#   source "$SCRIPT_DIR/literature-term-match.sh"
#   mapfile -t FILTERED_TERMS < <(filter_terms "$SEARCH_TERMS")
#   term_matches "$haystack" "$needle"
#
# Call sites:
#   - literature-discover.sh (Tier 1: global LITERATURE_DIR/index.json title/keyword search)
#   - literature-coverage-delta.sh (topic-scoped coverage-delta guard, keyword pass)
#
# Contract (not an implementation detail -- both call sites depend on this exact behavior):
#   - to_lower(): case-fold a string for case-insensitive comparison.
#   - term_matches(haystack, needle): case-insensitive substring match, true/false via exit code.
#   - STOP_WORDS: space-separated short-word list filter_terms() strips, alongside any term
#     under 3 characters.
#   - filter_terms(input): splits input on whitespace, lowercases, drops stop words and terms
#     under 3 characters, prints one filtered term per line.
#   - MULTI_TERM_MATCH_THRESHOLD (5): the match-strength trigger. A caller's own matching loop
#     (this file does not implement one) must apply "accept-on-first-hit" when the filtered term
#     count is at or below this threshold, and require >= 2 distinct term hits when it exceeds
#     the threshold. This asymmetric behavior is deliberate (short, hand-typed queries are not
#     penalized; long, capped task descriptions are) and is the caller's responsibility to
#     preserve, not this file's -- it only supplies the pieces.
#
# Implementation note (fork-free): to_lower() and term_matches() are pure-bash (`${var,,}` /
# `[[ == *needle* ]]`), not `echo | tr` / `echo | grep -qF` pipelines -- fork/exec was measured as
# the dominant cost of the callers' keyword-matching loops. The external contract above (case-
# insensitive substring match, true/false via exit code) is unchanged. Two narrow behavioral
# deltas versus the old pipe-based implementation are known and accepted, not defects:
#   - `${var,,}` is locale-aware and case-folds non-ASCII uppercase (e.g. Greek `Π` -> `π`) where
#     `tr '[:upper:]' '[:lower:]'` operates bytewise and never touches non-ASCII. This can only
#     ever ADD a match relative to the old behavior, never remove one. See the implementation
#     summary for the task that introduced this change for the full-corpus divergence audit.
#   - `${1,,}` neither strips a trailing newline from its argument (the old `$(echo "$1" | tr ...)`
#     did, via command substitution) nor treats a leading `-n`/`-e` argument as an `echo` option
#     (the old implementation could swallow one). Both call sites only ever pass single-line,
#     already-tokenized terms/titles/keywords, so neither delta is reachable in practice today.
#
# This file has no `set -e` and is guarded against double-sourcing (BASH_SOURCE-keyed guard
# variable) since a sourced helper must never alter the sourcing script's shell options or be
# re-defined redundantly when sourced from more than one call path in the same process.

if [ -n "${_LITERATURE_TERM_MATCH_SOURCED:-}" ]; then
  return 0 2>/dev/null || exit 0
fi
_LITERATURE_TERM_MATCH_SOURCED=1

# ---------------------------------------------------------------------------
# Helper: lowercase for case-insensitive matching (fork-free pure-bash; see the
# implementation note in the header contract above for the two accepted
# behavioral deltas versus the prior `echo | tr` pipeline).
# ---------------------------------------------------------------------------
to_lower() {
  printf '%s' "${1,,}"
}

# ---------------------------------------------------------------------------
# Helper: check if term appears in string (case-insensitive; fork-free
# pure-bash substring test, replacing the prior `echo | grep -qF` pipeline)
# ---------------------------------------------------------------------------
term_matches() {
  local haystack
  haystack="${1,,}"
  local needle
  needle="${2,,}"
  [[ "$haystack" == *"$needle"* ]]
}

# ---------------------------------------------------------------------------
# Split input into an array, filter stop words and short terms
# ---------------------------------------------------------------------------
STOP_WORDS="a an the in on at of to and or for by with from is are was were"

filter_terms() {
  local input="$1"
  local terms=()
  IFS=' ' read -ra raw_terms <<< "$input"
  for raw in "${raw_terms[@]}"; do
    term=$(to_lower "$raw")
    # Skip short terms
    if [ "${#term}" -lt 3 ]; then
      continue
    fi
    # Skip stop words
    is_stop=false
    for stop in $STOP_WORDS; do
      if [ "$term" = "$stop" ]; then
        is_stop=true
        break
      fi
    done
    if [ "$is_stop" = "false" ]; then
      terms+=("$term")
    fi
  done
  printf '%s\n' "${terms[@]:-}"
}

# Match-strength threshold trigger: see the header contract above. Kept as a plain assignment
# (not readonly) so a caller may override it before sourcing if ever needed, matching the
# original literature-discover.sh definition this was extracted from verbatim.
# shellcheck disable=SC2034  # Exported public contract: read by literature-briefing.sh,
# literature-discover.sh, literature-coverage-delta.sh, and literature-search.sh (all source
# this file), not locally unused.
MULTI_TERM_MATCH_THRESHOLD=5
