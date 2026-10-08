#!/usr/bin/env bash
# record-version-patterns.sh - Single source of truth for record-versioning-language detection.
#
# Exports the pattern variables, the durable-axis/path/marker exemption helpers, and the
# BLOCKING/ADVISORY tiering consumed by BOTH the planned repo-wide lint
# (scripts/check-record-versioning.sh) and the planned write-time guard hook
# (hooks/validate-no-record-versioning.sh). Neither consumer defines a detection pattern, an
# axis-discrimination rule, or a tier locally -- this is the ONLY place any of that is defined.
# See context/standards/record-version-exemptions.md's "Exemption Taxonomy" and "Forbidden
# Categories and Tiers" sections (companion to rules/no-record-versioning-in-deliverables.md) for
# the policy this code implements.
#
# Usage, in the order a consumer must call it:
#   1. `source` this file.
#   2. `is_exempt_path <path>` -- a path-level check; if it returns 0, skip the file entirely
#      (specs/** task-management artifacts; zone 1 of the taxonomy).
#   3. Pipe the file's content through `strip_durable_axis_lines` -- drops lines that are
#      durable, non-record version axes (toolchain/software pins, file-format/schema versions,
#      CI cache-key epoch segments, the dated cross-document amendment note) before any
#      BLOCKING/ADVISORY pattern ever sees them. Marker-free: this is zone 3 (plus zone 4) made
#      mechanical, with no `version-ok` annotation required.
#   4. Pipe the surviving content through `strip_exempt_regions` -- removes any
#      `version-ok`/`version-ok:begin`...`version-ok:end` marked region (a user-permitted
#      exception beyond the four taxonomy zones).
#   5. `grep -E -i` what remains against `$RV_BLOCKING_ERE` for BLOCKING findings and against
#      `$RV_ADVISORY_ERE` for ADVISORY findings. Both are case-insensitive by convention --
#      always pair with `-i`.
#
# Example:
#   source scripts/lib/record-version-patterns.sh
#   is_exempt_path "$file" && continue
#   content="$(strip_durable_axis_lines < "$file" | strip_exempt_regions)"
#   printf '%s\n' "$content" | grep -niE "$RV_BLOCKING_ERE"

# ─── Detection patterns: BLOCKING ───────────────────────────────────────────────────────────────
# Each pattern keeps every `\b` to a single bracket per
# context/standards/grep-word-boundary-portability.md where a chain across a wildcard run would
# otherwise be needed (the supersession, attribution-via-proximity, and escalation patterns
# below do chain two `\b`-anchored subexpressions across a bounded wildcard run). This library is
# Class C (sourced-only) and is invoked exclusively from within a consumer `.sh` file executed as
# a subprocess -- never pasted into an agent's own top-level Bash-tool shell -- so the actual
# runtime engine is always GNU grep, not the ugrep shell-function substitution described in that
# doc. Every pattern below is still execute-tested (never reasoned about) against a real corpus
# under that exact invocation shape (`bash -c` / a `.sh` file), per the doc's Execute-Before-
# Commit Obligation.

# 1. Page-level version label: a markdown heading, or a `**Status**:` line, carrying a `v[0-9]`
#    token -- "## The X convention (v2)", "**Status**: v2, accepted <date>; supersedes v1".
# shellcheck disable=SC2034
RV_PAGE_LABEL_ERE='^#{1,6}[[:space:]].*\bv[0-9]+\b|^\*\*Status\*\*:.*\bv[0-9]+\b'

# 2. Version-qualified supersession: "supersede"/"supersedes"/"supersession" is NOT matched bare
#    (it is live, legitimate usage throughout decision-record prose) -- it is BLOCKING only when
#    a `v[0-9]` token sits within the same clause (bounded to 80 characters either direction).
# shellcheck disable=SC2034
RV_SUPERSESSION_ERE='\b(supersede[sd]?|supersession)\b.{0,80}\bv[0-9]+\b|\bv[0-9]+\b.{0,80}\b(supersede[sd]?|supersession)\b'

# 3. The "(v1 Decision N)"-shaped attribution of a rejected alternative to an earlier draft.
# shellcheck disable=SC2034
RV_ATTRIBUTION_ERE='\([Vv][0-9]+ [Dd]ecision [0-9]+\)'

# 4. Version-qualified migration claims: "carried forward from v1", "every v1 field removed".
# shellcheck disable=SC2034
RV_MIGRATION_CLAIM_ERE='\bcarried forward from v[0-9]+\b|\bevery v[0-9]+ [a-z]+ removed\b'

# 5. Escalation of the bare-past-tense ADVISORY vocabulary (pattern 6 below) to BLOCKING: fires
#    only when the same line ALSO carries a `v[0-9]` token. Because strip_durable_axis_lines has
#    already dropped every durable-axis line by the time this is evaluated (per the Usage
#    ordering above), a `v[0-9]` token surviving to this point is presumptively the record-
#    version axis, not a toolchain/schema/cache-key pin.
# shellcheck disable=SC2034
RV_PAST_TENSE_ESCALATION_ERE='\b(no longer|previously|formerly|used to|withdrawn)\b.{0,80}\bv[0-9]+\b|\bv[0-9]+\b.{0,80}\b(no longer|previously|formerly|used to|withdrawn)\b'

# The full BLOCKING group. Both consumers match against this single variable so neither chooses
# its own BLOCKING set.
# shellcheck disable=SC2034
RV_BLOCKING_ERE="${RV_PAGE_LABEL_ERE}|${RV_SUPERSESSION_ERE}|${RV_ATTRIBUTION_ERE}|${RV_MIGRATION_CLAIM_ERE}|${RV_PAST_TENSE_ESCALATION_ERE}"

# ─── Detection patterns: ADVISORY ───────────────────────────────────────────────────────────────

# 6. Bare past-tense vocabulary with no adjacent `v[0-9]` token. Empirically the most false-
#    positive-prone category (8+ matches in accepted, non-versioning decision-record prose) --
#    ADVISORY only, never BLOCKING on its own. See pattern 5 above for its BLOCKING escalation.
# shellcheck disable=SC2034
RV_PAST_TENSE_ERE='\b(no longer|previously|formerly|used to|withdrawn)\b'

# 7. Low-confidence disposition-table heuristic: a heading matching "relates? to vN", or a
#    pipe-delimited table header row carrying both a decision-number column and a `v[0-9]`-shaped
#    column label. Undercalibrated pending a real positive instance (see the taxonomy standard).
#    The table-row half is the exact compositional shape documented as the worked example in
#    grep-word-boundary-portability.md -- verified matching under GNU grep (this library's only
#    real invocation context), not evaluated under ugrep's `-E` engine.
# shellcheck disable=SC2034
RV_DISPOSITION_HEADING_ERE='^#{1,6}.*\brelates?[[:space:]]+to[[:space:]]+v[0-9]+\b'
# shellcheck disable=SC2034
RV_DISPOSITION_TABLE_ERE='\|[^|]*[Dd]ecision[^|]*\|[^|]*\bv[0-9]+\b[^|]*\||\|[^|]*\bv[0-9]+\b[^|]*\|[^|]*[Dd]ecision[^|]*\|'

# The full ADVISORY group.
# shellcheck disable=SC2034
RV_ADVISORY_ERE="${RV_PAST_TENSE_ERE}|${RV_DISPOSITION_HEADING_ERE}|${RV_DISPOSITION_TABLE_ERE}"

# ─── Path-level exemption ──────────────────────────────────────────────────────────────────────
# is_exempt_path <path>
#
# Returns 0 (exempt) for any specs/** path -- the primary exemption (taxonomy zone 1), confirmed
# explicitly by the repository owner. Returns 1 (not exempt) for everything else. Zone 2 (git
# commit messages, PR/branch metadata) is not a file path and has no path-level check here.
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

# ─── Durable-axis exemption (marker-free) ──────────────────────────────────────────────────────
# strip_durable_axis_lines
#
# Reads content on stdin, writes it back on stdout with every line matching a durable, non-
# record version axis removed. This is taxonomy zone 3 (the three durable axes) plus zone 4 (the
# dated cross-document amendment note) made mechanical -- no `version-ok` marker is ever required
# for a durable-axis line, because the line was never a record-versioning violation to begin with.
#
# Durable-axis shapes dropped (one line per match is enough to drop the whole line):
#   - dotted semver               e.g. `Lean v4.31.0`, `v0.1.0`, `v4.34.0-rc2`
#   - `@vN` action/toolchain pins  e.g. `actions/checkout@v4`
#   - hyphen-embedded CI cache-key epoch segments
#                                  e.g. `pnpm-v1-`, `lake-recheck-v3-`, `elan-v2-`
#   - schema/file-format artifact filename or heading slugs
#                                  e.g. `book-cert-v2.md`, `book-toml-v2-schema.md`,
#                                  `book-evidence-snapshot-v1.md`
#   - backtick-quoted schema/filename identifiers carrying a `vN` component, whether the `vN` is
#     embedded inside the backtick span itself (`` `book-evidence-observation-v1` ``, `` `-v2` ``
#     filename-fragment mentions) or immediately follows a closing backtick
#     (`` `book.toml` v2 ``, `` `book.cert.json` v2 ``) -- a schema document's own self-
#     declaration of its format version in a title or body is axis (b), not a page-level draft-
#     history label, even though the surface shape (heading + `vN`) otherwise looks identical to
#     forbidden category 1
#   - the dated `**Amended by** <doc>, <date>:` cross-document amendment note (zone 4) -- this
#     records a real, dated change to an accepted decision, not a draft lineage.
strip_durable_axis_lines() {
  # shellcheck disable=SC2016
  grep -viE \
    -e '\bv[0-9]+\.[0-9]+' \
    -e '@v[0-9]+\b' \
    -e '[a-z]+-v[0-9]+-' \
    -e 'v[0-9]+(-[a-z]+)?\.md\b' \
    -e '`[^`]*v[0-9]+[^`]*`' \
    -e '`[^`]+`[[:space:]]v[0-9]+\b' \
    -e '\*\*Amended by\*\*|\*\*Amended by[^*]*\*\*,? *[0-9]{4}-[0-9]{2}-[0-9]{2}:'
}

# ─── Content-level exemption: marker convention ────────────────────────────────────────────────
# strip_exempt_regions
#
# Reads content on stdin, writes it back on stdout with exempted lines removed. Neither consumer
# implements exemption filtering itself -- both pipe their candidate content through this
# function before matching $RV_BLOCKING_ERE or $RV_ADVISORY_ERE against what remains.
#
# Marker convention (documented in context/standards/record-version-exemptions.md's Marker
# Convention section):
#   - Block form: a line containing the substring "version-ok:begin" opens an exempt region that
#     runs through (and includes) the next line containing "version-ok:end". Comment syntax is
#     irrelevant -- markdown `<!-- -->`, shell `#`, Lua `--` -- because the token is matched as a
#     plain substring, not parsed as a comment.
#   - Inline form: any single line containing the substring "version-ok" (that is not itself a
#     begin/end marker line already handled above) is itself exempt.
#   - Both forms REQUIRE a trailing reason naming one of the Exemption Taxonomy's categories, on
#     the begin marker (block form) or the inline marker line (inline form); the end marker
#     itself may be bare. This function does not validate the reason text -- that is a human-
#     review concern at the taxonomy table, not a parseable contract -- it only strips whatever
#     lines the begin/end/inline tokens delimit. Beyond the four taxonomy zones, this marker is
#     the ONLY sanctioned way to permit version language, and only with explicit user permission.
strip_exempt_regions() {
  awk '
    /version-ok:begin/ { in_block = 1; next }
    /version-ok:end/   { in_block = 0; next }
    in_block             { next }
    /version-ok/        { next }
    { print }
  '
}
