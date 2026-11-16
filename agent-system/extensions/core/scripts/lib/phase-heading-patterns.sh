#!/usr/bin/env bash
# phase-heading-patterns.sh - Single source of truth for phase-heading parsing AND the per-phase
# enterability fields it governs.
#
# This is the ONLY place the canonical `### Phase N: {name} [STATUS]` grammar, the closed
# status-marker enum, non-conforming-heading detection, AND the phase-level enterability
# predicate (marker-plus-`Depends on`-closure) are defined. It implements the policy documented
# in `context/formats/plan-format.md`'s "Canonical phase-heading shape" subsection -- that
# document is the prose source of truth for the grammar; this file is its sole executable
# anchor. Every consumer sources this file rather than re-deriving an inline pattern; the current
# consumer list is found live via `grep -rl 'phase-heading-patterns.sh' agent-system/extensions`
# (the same self-verifying "grep for sourcers" mechanism `task-reference-patterns.sh`'s consumers
# are found by).
#
# Scope note (deliberate widening): this library originally scoped itself to heading GRAMMAR
# only. It now also owns the `Depends on` field parser and the enterability predicate built on
# top of that grammar -- a related but distinct kind of reasoning (closure over a dependency
# graph, not pattern matching). This is a deliberate choice (keep the marker alternation beside
# the one it narrows, reuse this file's existing unit-test home) rather than splitting into a
# second library; see `phase_is_enterable`/`select_enterable_phase` below for the executable
# contract and `PHASE_STATUS_ENTERABLE_ALT`'s own comment for why it is a NEW alternation rather
# than a narrowing of `PHASE_STATUS_OPEN_ALT`.
#
# Usage: `source` this file, then use the exported constants/arrays directly with `grep -E`
# (canonical forms) or plain `grep` (BRE compatibility aliases), and call `extract_phase_number`,
# `nonconforming_phase_headings`, `warn_nonconforming`, `phase_marker_of`,
# `phase_dependency_numbers`, `phase_is_enterable`, and `select_enterable_phase` as documented
# below.
#
# Ordering contract for filtered scans: PHASE_HEADING_ERE filters to conforming headings only, so
# a non-conforming heading is not merely unmatched by a PHASE_HEADING_ERE-based grep -- it is
# INVISIBLE to it. A consumer that derives a SELECTION or a COUNT from such a filtered grep
# without checking the whole file first will silently select the next conforming candidate (or
# undercount) instead of surfacing the non-conforming heading. Therefore: any consumer that
# derives a selection or a count from a PHASE_HEADING_ERE-filtered grep MUST call
# `has_nonconforming_phase_headings <file>` over the WHOLE FILE FIRST, before the filtered scan,
# and take a named INCONCLUSIVE branch on a hit -- never merely a warning on the way to trusting
# the filtered result anyway. Use the boolean predicate `has_nonconforming_phase_headings`; the
# `nonconforming_phase_headings <file> | grep -q .` pipe form is FORBIDDEN (unsafe under
# `pipefail` -- see that function's own header comment for the race). The reference
# implementation of this ordering is `update-task-status.sh`'s phase-check (D3) gate: whole-file
# check first, named INCONCLUSIVE branch second, filtered count/selection trusted only in the
# else branch.

# ─── Canonical grammar (ERE) ───────────────────────────────────────────────────────────────────
# The phase-number token is an integer with at most one optional decimal sub-level: `3`, `3.1`;
# never `3.1.2`, never `3a`. Letter-suffixed sub-phases are deliberately not supported -- see
# plan-format.md's "Canonical phase-heading shape" subsection for the D1 rationale. Copied
# verbatim from that section's canonical regex table, not re-derived.

# ERE heading match: the number token followed immediately by a colon. This is deliberately the
# gate `extract_phase_number` below runs BEFORE extracting anything -- a non-conforming token
# (`3a`, `3.1.2`, `III`) fails this match entirely rather than partially matching a prefix.
PHASE_HEADING_ERE='^### Phase [0-9]+(\.[0-9]+)?:'

# ERE phase-number extraction: intended usage is `grep -oE "$PHASE_HEADING_ERE" | grep -oE
# '[0-9]+(\.[0-9]+)?'` -- but ONLY after the input line has already been confirmed to match
# PHASE_HEADING_ERE (see extract_phase_number). Applying the extraction grep alone, without the
# heading-match gate first, is exactly the `3a` -> `3` truncated-prefix collapse this library
# exists to eliminate -- never do that.
# shellcheck disable=SC2034  # PHASE_NUMBER_EXTRACT_ERE is exported public contract for sourcing consumers (see this file's own header); not locally unused.
PHASE_NUMBER_EXTRACT_ERE="$PHASE_HEADING_ERE"

# Anchor prefix, exported separately so a consumer building a SPECIFIC-number lookup (e.g.
# `update-phase-status.sh`'s "find the heading for phase 3" rather than "find any phase heading")
# can compose `"${PHASE_HEADING_PREFIX}${validated_number}:"` instead of hand-typing the literal
# `### Phase ` string inline.
# shellcheck disable=SC2034  # PHASE_HEADING_PREFIX is exported public contract for sourcing consumers (see this file's own header); not locally unused.
PHASE_HEADING_PREFIX='^### Phase '

# Bare number-TOKEN validator (no heading context) for validating a caller-supplied argument
# (e.g. a `phase_number` CLI argument) against the canonical grammar before using it to build a
# lookup pattern. Anchored on both ends: the whole argument must be exactly one conforming token,
# not merely contain one.
# shellcheck disable=SC2034  # PHASE_NUMBER_TOKEN_ERE is exported public contract for sourcing consumers (see this file's own header); not locally unused.
PHASE_NUMBER_TOKEN_ERE='^[0-9]+(\.[0-9]+)?$'

# BRE (`grep`, no `-E`) compatibility alias. Required-equivalent to PHASE_HEADING_ERE on every
# fixture in scripts/tests/test-phase-heading-patterns.sh -- a divergence between the two is
# exactly the drift this library exists to prevent (see that test's "Equivalence fixtures").
# shellcheck disable=SC2034  # PHASE_HEADING_BRE is exported public contract for sourcing consumers (see this file's own header); not locally unused.
PHASE_HEADING_BRE='^### Phase [0-9][0-9]*\(\.[0-9][0-9]*\)\{0,1\}:'

# Loose "claims to be a phase heading" ERE: anchored on `^### Phase ` only, matching any token and
# any bracket content. This is what makes non-conformance detectable instead of invisible -- a
# line that matches this loose form but fails PHASE_HEADING_ERE or the marker enum below is a
# non-conforming phase heading, not a non-heading line to be silently skipped.
PHASE_HEADING_LOOSE_ERE='^### Phase '

# The marker-shape character class used by the historical TOTAL count: uppercase letters and
# spaces only, satisfied by every real enum value including `COMPLETED WITH EXCLUSIONS`. Matching
# this class is necessary but NOT sufficient for conformance -- `[DESCOPED]` and `[FOOBAR]` both
# satisfy it; the enum check in nonconforming_phase_headings below is what actually validates the
# marker text.
PHASE_MARKER_CLASS_ERE='\[[A-Z][A-Z ]*\][[:space:]]*$'

# Convenience full-line forms mirroring the pre-existing TOTAL/DONE regexes verbatim (a conforming
# heading, i.e. PHASE_HEADING_ERE, followed anywhere by a marker of the matched shape). These
# match a "looks-conforming" heading; they do NOT themselves reject a marker outside the enum
# (e.g. `[DESCOPED]` still matches PHASE_HEADING_TOTAL_ERE) -- pair them with
# nonconforming_phase_headings for the enum-level check.
# shellcheck disable=SC2034  # PHASE_HEADING_TOTAL_ERE is exported public contract for sourcing consumers (see this file's own header); not locally unused.
PHASE_HEADING_TOTAL_ERE="${PHASE_HEADING_ERE}.*${PHASE_MARKER_CLASS_ERE}"
# shellcheck disable=SC2034  # PHASE_HEADING_TOTAL_BRE is exported public contract for sourcing consumers (see this file's own header); not locally unused.
PHASE_HEADING_TOTAL_BRE='^### Phase [0-9][0-9]*\(\.[0-9][0-9]*\)\{0,1\}:.*\[[A-Z][A-Z ]*\][[:space:]]*$'

# ─── Closed status-marker enum ─────────────────────────────────────────────────────────────────
# Six values, closed. `[DESCOPED]` is deliberately NOT a member -- see plan-format.md and
# status-markers.md's `[COMPLETED WITH EXCLUSIONS]` subsection for why whole-phase descoping uses
# `[COMPLETED WITH EXCLUSIONS]` instead (D2).
PHASE_STATUS_ENUM=(
  "NOT STARTED"
  "IN PROGRESS"
  "COMPLETED"
  "COMPLETED WITH EXCLUSIONS"
  "PARTIAL"
  "BLOCKED"
)

# DONE alternation: the single definition every accounting/recovery site must use for "this phase
# is closed." `COMPLETED WITH EXCLUSIONS` counting as closed is the fix for the orchestration
# skills' `recovered_completed` drift (Phase 7 of the plan that introduced this library).
PHASE_STATUS_DONE_ALT='COMPLETED|COMPLETED WITH EXCLUSIONS'
# shellcheck disable=SC2034  # PHASE_STATUS_DONE_ERE is exported public contract for sourcing consumers (see this file's own header); not locally unused.
PHASE_STATUS_DONE_ERE="\\[(${PHASE_STATUS_DONE_ALT})\\]"
# shellcheck disable=SC2034  # PHASE_HEADING_DONE_ERE is exported public contract for sourcing consumers (see this file's own header); not locally unused.
PHASE_HEADING_DONE_ERE="${PHASE_HEADING_ERE}.*\\[(${PHASE_STATUS_DONE_ALT})\\][[:space:]]*\$"
# shellcheck disable=SC2034  # PHASE_HEADING_DONE_BRE is exported public contract for sourcing consumers (see this file's own header); not locally unused.
PHASE_HEADING_DONE_BRE='^### Phase [0-9][0-9]*\(\.[0-9][0-9]*\)\{0,1\}:.*\[\(COMPLETED\|COMPLETED WITH EXCLUSIONS\)\][[:space:]]*$'

# OPEN alternation: every non-terminal, non-closed phase-heading marker. Used by resume-scan sites
# (`next_phase` greps) to find the next phase to work on. UNCHANGED, and kept byte-identical in
# meaning, by the ENTERABLE split immediately below: this alternation still answers "is this
# phase closed or not", nothing more, for every present and future sourcing consumer.
PHASE_STATUS_OPEN_ALT='NOT STARTED|IN PROGRESS|PARTIAL|BLOCKED'
# shellcheck disable=SC2034  # PHASE_STATUS_OPEN_ERE is exported public contract for sourcing consumers (see this file's own header); not locally unused.
PHASE_STATUS_OPEN_ERE="\\[(${PHASE_STATUS_OPEN_ALT})\\]"

# ENTERABLE alternation: a NEW, separately named export -- never a redefinition of
# PHASE_STATUS_OPEN_ALT above, which keeps all four of its members and its established meaning
# for any other consumer. OPEN means "not closed" (a phase-accounting question). ENTERABLE means
# "a dispatch may be scoped into this phase right now" (a dispatch-admission question), and the
# two are not the same question: ENTERABLE excludes `BLOCKED` because both sanctioned meanings of
# a `[BLOCKED]` phase heading -- a pre-decided decision gate that never executes, and a phase
# merely waiting on an external unblock -- are wrong to dispatch into, and nothing in the marker
# text itself distinguishes the two. A marker being in this set is necessary but not sufficient
# for enterability; see `phase_is_enterable` below for the full predicate (marker AND `Depends on`
# closure).
PHASE_STATUS_ENTERABLE_ALT='NOT STARTED|IN PROGRESS|PARTIAL'
# shellcheck disable=SC2034  # PHASE_STATUS_ENTERABLE_ERE is exported public contract for sourcing consumers (see this file's own header); not locally unused.
PHASE_STATUS_ENTERABLE_ERE="\\[(${PHASE_STATUS_ENTERABLE_ALT})\\]"
# shellcheck disable=SC2034  # PHASE_HEADING_ENTERABLE_ERE is exported public contract for sourcing consumers (see this file's own header); not locally unused.
PHASE_HEADING_ENTERABLE_ERE="${PHASE_HEADING_ERE}.*\\[(${PHASE_STATUS_ENTERABLE_ALT})\\][[:space:]]*\$"

# ─── extract_phase_number <heading_line> ───────────────────────────────────────────────────────
# Prints the canonical number token (`3`, `3.1`, ...) on stdout and returns 0 when the heading
# conforms to PHASE_HEADING_ERE. Prints nothing and returns 1 when it does not -- e.g. `3a`,
# `3.1.2`, `III`, or a missing number. This function MUST NOT return a truncated prefix: the
# heading-match gate below runs BEFORE any extraction, so a non-conforming token never partially
# matches.
extract_phase_number() {
  local heading="$1"
  if ! printf '%s\n' "$heading" | grep -qE "$PHASE_HEADING_ERE"; then
    return 1
  fi
  local matched number
  matched=$(printf '%s\n' "$heading" | grep -oE "$PHASE_HEADING_ERE")
  number=$(printf '%s\n' "$matched" | grep -oE '[0-9]+(\.[0-9]+)?')
  if [[ -z "$number" ]]; then
    return 1
  fi
  printf '%s\n' "$number"
  return 0
}

# ─── _phase_marker_text <heading_line> ─────────────────────────────────────────────────────────
# Internal helper: extracts the bracket content of a trailing `[...]` on the line, regardless of
# whether it is a recognized marker or even uppercase -- deliberately permissive (any character
# except `]`) so an arbitrary unknown marker (lowercase, digits, punctuation) is still captured
# and reported by name rather than silently treated as "no marker at all". Empty output means no
# trailing bracket was found on the line.
_phase_marker_text() {
  local heading="$1"
  printf '%s\n' "$heading" \
    | grep -oE '\[[^][]*\][[:space:]]*$' \
    | sed -E 's/^\[//; s/\][[:space:]]*$//'
}

# ─── _phase_marker_is_valid <marker_text> ──────────────────────────────────────────────────────
# Internal helper: returns 0 iff marker_text is exactly one of the six closed enum values.
_phase_marker_is_valid() {
  local marker="$1" candidate
  for candidate in "${PHASE_STATUS_ENUM[@]}"; do
    [[ "$marker" == "$candidate" ]] && return 0
  done
  return 1
}

# ─── nonconforming_phase_headings <file> ───────────────────────────────────────────────────────
# Emits `linenum:heading` for every line matching the loose "claims to be a phase heading" ERE
# but failing either the canonical number-token grammar or the closed marker enum. Emits nothing
# for a file with zero such lines (including a file with zero phase headings at all -- that is
# the pre-existing, separately-handled "no conforming headings" INCONCLUSIVE case, not a
# non-conformance finding).
nonconforming_phase_headings() {
  local file="$1"
  local linenum heading marker
  while IFS=: read -r linenum heading; do
    [[ -z "$heading" ]] && continue
    local number_ok=1
    grep -qE "$PHASE_HEADING_ERE" <<< "$heading" || number_ok=0
    marker=$(_phase_marker_text "$heading")
    local marker_ok=1
    if [[ -z "$marker" ]] || ! _phase_marker_is_valid "$marker"; then
      marker_ok=0
    fi
    if [[ "$number_ok" -eq 0 || "$marker_ok" -eq 0 ]]; then
      printf '%s:%s\n' "$linenum" "$heading"
    fi
  done < <(grep -nE "$PHASE_HEADING_LOOSE_ERE" "$file" 2>/dev/null)
}

# ─── has_nonconforming_phase_headings <file> ───────────────────────────────────────────────────
# Returns 0 (true) if <file> contains at least one non-conforming phase heading, 1 (false)
# otherwise. Callers MUST use this rather than `nonconforming_phase_headings <file> | grep -q .`:
# that pipe form is racy under `set -o pipefail`. `grep -q` exits after its first match and closes
# the pipe; if the producer side is still writing (realistic here, since each loop iteration runs
# several greps and is not instantaneous), the producer receives SIGPIPE and, under pipefail, the
# pipeline's reported exit status becomes the producer's non-zero signal-exit code (141) rather
# than reliably reflecting whether any output existed. This function avoids the race by capturing
# the full output via command substitution (which reads to EOF, never closing early) before
# testing it for emptiness.
has_nonconforming_phase_headings() {
  local file="$1"
  local findings
  findings="$(nonconforming_phase_headings "$file")"
  [[ -n "$findings" ]]
}

# ─── warn_nonconforming <file> <label> ─────────────────────────────────────────────────────────
# Prints a loud, per-heading, actionable block to stderr for every non-conforming heading in
# <file>, naming the offending heading, its line number, and the specific reason (bad number
# token vs. unrecognized marker vs. both). When the unrecognized marker is exactly `DESCOPED`,
# the message names `[COMPLETED WITH EXCLUSIONS]` as the replacement (D2). <label> identifies the
# calling site in output (e.g. the script/skill name) so multi-site output stays attributable.
#
# Returns 0 if no non-conforming heading was found, 1 if at least one was (the caller uses this
# to decide whether to take the INCONCLUSIVE branch per D3 -- never a hard refusal).
warn_nonconforming() {
  local file="$1"
  local label="$2"
  local found=0
  local linenum heading marker reason number_ok
  while IFS=: read -r linenum heading; do
    found=1
    reason=""
    number_ok=1
    grep -qE "$PHASE_HEADING_ERE" <<< "$heading" || number_ok=0
    if [[ "$number_ok" -eq 0 ]]; then
      reason="non-conforming phase-number token (letter suffix, extra decimal level, or malformed heading)"
    fi
    marker=$(_phase_marker_text "$heading")
    if [[ -z "$marker" ]] || ! _phase_marker_is_valid "$marker"; then
      if [[ -n "$reason" ]]; then
        reason="${reason}; also an unrecognized status marker"
      else
        reason="unrecognized status marker"
      fi
      if [[ "$marker" == "DESCOPED" ]]; then
        reason="${reason} -- use [COMPLETED WITH EXCLUSIONS] instead of [DESCOPED] (see status-markers.md)"
      fi
    fi
    echo "NON-CONFORMING PHASE HEADING [$label] ${file}:${linenum}: ${heading}" >&2
    echo "  Reason: ${reason}" >&2
  done < <(nonconforming_phase_headings "$file")

  if [[ "$found" -eq 1 ]]; then
    return 1
  fi
  return 0
}

# ─── phase_marker_of <file> <phase_number> ─────────────────────────────────────────────────────
# Prints the marker text (bracket contents, e.g. `NOT STARTED`) of <phase_number>'s conforming
# heading in <file>. Returns 1 when <phase_number> is not a valid PHASE_NUMBER_TOKEN_ERE token, or
# no heading for it exists in <file>. The lookup anchor (`^### Phase <n>:`) cannot partially match
# a longer number (e.g. "31" against "3") because the number token must be followed immediately by
# `:`, mirroring PHASE_HEADING_ERE's own anti-truncation guarantee.
phase_marker_of() {
  local file="$1" phase_number="$2"
  [[ -z "$file" || -z "$phase_number" ]] && return 1
  grep -qE "$PHASE_NUMBER_TOKEN_ERE" <<< "$phase_number" || return 1
  local escaped_number heading marker
  escaped_number="${phase_number//./\\.}"
  heading=""
  heading=$(grep -E "^### Phase ${escaped_number}:" "$file" 2>/dev/null | head -1) || heading=""
  [[ -z "$heading" ]] && return 1
  marker="$(_phase_marker_text "$heading")"
  [[ -z "$marker" ]] && return 1
  printf '%s\n' "$marker"
  return 0
}

# ─── phase_dependency_numbers <file> <phase_number> ────────────────────────────────────────────
# Prints the phase's EFFECTIVE dependency numbers, one per line, implementing plan-format.md's
# per-phase `**Depends on**:` / `**Depends on:**` field (BOTH live bold-marker spellings are
# accepted -- the corpus has real occurrences of the minority `**Depends on:**` form). Rules, all
# of them:
#   - Scan from the phase's own heading line to just before the next `^### ` heading (or EOF) for
#     the FIRST line matching the field label in either spelling, with an optional leading list
#     bullet (`- **Depends on**: ...`).
#   - Strip the label and trim. A value equal to `none` (case-insensitive) yields an EMPTY set
#     (phase_dependency_numbers prints nothing and returns 0).
#   - Otherwise split on commas, trim each token, and validate each against the already-exported
#     PHASE_NUMBER_TOKEN_ERE. ALL-OR-NOTHING: if ANY token fails validation (including an empty
#     value), the whole parse is discarded and the absence default applies below.
#   - Absence default (field missing entirely, or parse discarded): every conforming phase number
#     appearing STRICTLY EARLIER in file order than this phase -- plan-format.md's documented
#     "absence means sequential (depends on all prior phases)", never "no dependency". This is
#     the deliberately conservative choice: under-gating is exactly the failure mode this
#     predicate exists to remove, so an unparseable or missing field must never be read as "no
#     dependency".
# Returns 1 only when <file>/<phase_number> are missing/invalid or no heading for <phase_number>
# exists in <file>.
phase_dependency_numbers() {
  local file="$1" phase_number="$2"
  [[ -z "$file" || -z "$phase_number" ]] && return 1
  grep -qE "$PHASE_NUMBER_TOKEN_ERE" <<< "$phase_number" || return 1

  local escaped_number heading_linenum total_lines next_heading_linenum body_end
  escaped_number="${phase_number//./\\.}"
  heading_linenum=""
  heading_linenum=$(grep -nE "^### Phase ${escaped_number}:" "$file" 2>/dev/null | head -1 | cut -d: -f1) || heading_linenum=""
  [[ -z "$heading_linenum" ]] && return 1

  total_lines=0
  total_lines=$(wc -l < "$file" 2>/dev/null) || total_lines=0
  next_heading_linenum=""
  next_heading_linenum=$(awk -v start="$heading_linenum" 'NR > start && /^### / {print NR; exit}' "$file" 2>/dev/null) || next_heading_linenum=""
  if [[ -z "$next_heading_linenum" ]]; then
    body_end="$total_lines"
  else
    body_end=$((next_heading_linenum - 1))
  fi

  local dep_line=""
  if [[ "$body_end" -gt "$heading_linenum" ]]; then
    dep_line=$(sed -n "$((heading_linenum + 1)),${body_end}p" "$file" 2>/dev/null \
      | grep -E '^[[:space:]]*(-[[:space:]]*)?\*\*Depends on(\*\*:|:\*\*)' | head -1) || dep_line=""
  fi

  local use_default=0
  if [[ -z "$dep_line" ]]; then
    use_default=1
  else
    local value
    value=$(printf '%s\n' "$dep_line" \
      | sed -E 's/^[[:space:]]*(-[[:space:]]*)?\*\*Depends on(\*\*:|:\*\*)[[:space:]]*//; s/[[:space:]]+$//') || value=""
    if [[ "${value,,}" == "none" ]]; then
      return 0
    fi
    local -a raw_tokens=()
    IFS=',' read -r -a raw_tokens <<< "$value"
    local -a dep_tokens=()
    local all_ok=1
    local tok trimmed
    for tok in "${raw_tokens[@]}"; do
      trimmed=$(printf '%s' "$tok" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
      if [[ -z "$trimmed" ]] || ! grep -qE "$PHASE_NUMBER_TOKEN_ERE" <<< "$trimmed"; then
        all_ok=0
        break
      fi
      dep_tokens+=("$trimmed")
    done
    if [[ "$all_ok" -eq 1 && "${#dep_tokens[@]}" -gt 0 ]]; then
      printf '%s\n' "${dep_tokens[@]}"
      return 0
    fi
    use_default=1
  fi

  if [[ "$use_default" -eq 1 ]]; then
    local ln rest num
    while IFS=: read -r ln rest; do
      [[ "$ln" -lt "$heading_linenum" ]] || continue
      num=""
      num=$(extract_phase_number "$rest") || num=""
      [[ -n "$num" ]] && printf '%s\n' "$num"
    done < <(grep -nE "$PHASE_HEADING_ERE" "$file" 2>/dev/null)
  fi
  return 0
}

# ─── phase_is_enterable <file> <heading_line> ──────────────────────────────────────────────────
# Returns 0 only when <heading_line>'s own marker is in PHASE_STATUS_ENTERABLE_ALT AND every
# number phase_dependency_numbers reports for it resolves to a heading in <file> whose marker is
# in PHASE_STATUS_DONE_ALT. On refusal (non-zero return), prints exactly ONE short
# machine-readable reason token on stdout:
#   marker                   -- the heading's own marker is not in PHASE_STATUS_ENTERABLE_ALT
#                                (covers BLOCKED and any non-conforming/unrecognized marker)
#   unmet-dependency:<n>      -- dependency phase <n> exists but is not DONE yet
#   dangling-dependency:<n>   -- dependency phase <n> names a phase with no heading in the file
# Only the FIRST failing dependency is reported, not every one -- select_enterable_phase below
# composes its own per-heading diagnostic line around this single token, so one token per call is
# sufficient and keeps the reason machine-parseable.
phase_is_enterable() {
  local file="$1" heading_line="$2"
  local phase_number
  phase_number=$(extract_phase_number "$heading_line") || phase_number=""
  if [[ -z "$phase_number" ]] || ! grep -qE "$PHASE_HEADING_ENTERABLE_ERE" <<< "$heading_line"; then
    printf '%s\n' "marker"
    return 1
  fi

  local dep_numbers
  dep_numbers="$(phase_dependency_numbers "$file" "$phase_number")" || dep_numbers=""
  [[ -z "$dep_numbers" ]] && return 0

  local dep dep_marker
  while IFS= read -r dep; do
    [[ -z "$dep" ]] && continue
    dep_marker=""
    dep_marker=$(phase_marker_of "$file" "$dep") || dep_marker=""
    if [[ -z "$dep_marker" ]]; then
      printf 'dangling-dependency:%s\n' "$dep"
      return 1
    fi
    if ! grep -qE "$PHASE_STATUS_DONE_ERE" <<< "[${dep_marker}]"; then
      printf 'unmet-dependency:%s\n' "$dep"
      return 1
    fi
  done <<< "$dep_numbers"

  return 0
}

# ─── select_enterable_phase <file> ─────────────────────────────────────────────────────────────
# Three-way selector replacing a plain `grep PHASE_HEADING_ERE.*PHASE_STATUS_OPEN_ERE | head -1`:
#   exit 0 -- prints the first (lowest file-order) ENTERABLE heading line on stdout.
#   exit 3 -- at least one heading matched PHASE_STATUS_OPEN_ERE (it is "open" in the
#             pre-existing, unchanged sense) but NONE was enterable; prints one
#             `<phase>:<marker>:<reason>` diagnostic line per rejected heading, in file order.
#   exit 4 -- no heading matched PHASE_STATUS_OPEN_ERE at all -- the pre-existing fallthrough
#             condition (nothing left open), preserved as its own distinct code so callers never
#             collapse "nothing open" and "open but none enterable" into one boolean.
# Callers MUST capture with the `rc=0; out=$(select_enterable_phase "$file") || rc=$?` idiom
# (never a `| grep -q` pipe, and never relying on the exit status of a plain `$(...)` assignment
# under `set -e` without that guard) -- see this file's module header for the SIGPIPE/pipefail
# rationale this convention exists to avoid.
select_enterable_phase() {
  local file="$1"
  [[ -z "$file" || ! -f "$file" ]] && return 4

  local open_headings
  open_headings="$(grep -E "${PHASE_HEADING_ERE} .*${PHASE_STATUS_OPEN_ERE}" "$file" 2>/dev/null)" || open_headings=""
  [[ -z "$open_headings" ]] && return 4

  local heading phase_number marker reason
  while IFS= read -r heading; do
    [[ -z "$heading" ]] && continue
    reason=$(phase_is_enterable "$file" "$heading") && {
      printf '%s\n' "$heading"
      return 0
    }
  done <<< "$open_headings"

  # None of the open headings were enterable: emit one diagnostic line per rejected heading, in
  # file order, and refuse with exit 3 (distinct from exit 4's "nothing open at all").
  while IFS= read -r heading; do
    [[ -z "$heading" ]] && continue
    phase_number=$(extract_phase_number "$heading") || phase_number="?"
    marker="$(_phase_marker_text "$heading")"
    reason=$(phase_is_enterable "$file" "$heading") || true
    printf '%s:%s:%s\n' "$phase_number" "$marker" "$reason"
  done <<< "$open_headings"
  return 3
}
