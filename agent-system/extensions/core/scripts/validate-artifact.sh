#!/usr/bin/env bash
# validate-artifact.sh - Validate artifact files against format standards
#
# Usage: validate-artifact.sh <artifact_path> <type> [--fix] [--strict]
#
# Types: report, plan, summary
# Exit codes: 0 = valid, 1 = errors found, 2 = auto-fixed, 3 = file not found, 4 = unknown type,
#             5 = environment error (plan-type only: scripts/lib/phase-heading-patterns.sh, the
#             shared phase-heading pattern library, OR scripts/lib/plan-status-line.sh, the
#             shared plan-level Status-line grammar library, could not be found at its expected
#             sibling path -- see context/formats/plan-format.md's "Canonical phase-heading
#             shape" subsection and its "Plan-level vs. phase-level markers" subsection)
#
# --fix NON-PARTICIPATION (plan-level Status-line grammar only): the Status-line grammar check
# added below deliberately does NOT participate in --fix. A malformed plan-level Status line is
# reported as an error and left byte-identical. Reasoning: (1) the existing --fix machinery in
# this script only ever inserts a placeholder for an ABSENT metadata field -- it has never
# rewritten an author-supplied value, so a grammar repair would be a new mutation class, not an
# extension of the existing one; (2) M3 (text between the prefix and the bracket) offers no
# derivable intent and M1 (no Status line at all) offers no anchor, so two of the three malformed
# shapes are unrepairable by any general rule anyway; (3) most importantly, auto-repair would
# erase the only signal that an agent hand-wrote the line, defeating the producer-side purpose
# this check exists for. This is consistent with the shipped decision recorded as decision D-A
# ("--fix remains in-place-mutating on the gate-out path in general") -- it is declined here on
# these three grounds specifically, not because in-place repair is categorically forbidden.
# Because artifact validation is non-blocking at every call site (skill-base.sh,
# orchestrator-postflight.sh all downgrade a non-zero exit to a counted warning), this error
# surfaces loudly in the aggregated counters without ever blocking a status transition.

set -euo pipefail

# --- Required metadata fields per type ---
# Update these arrays when format standards change
# Sources: .claude/context/formats/{report,plan,summary}-format.md

REPORT_METADATA=("Task" "Started" "Completed" "Effort" "Dependencies" "Sources/Inputs" "Artifacts" "Standards")
REPORT_SECTIONS=("Executive Summary" "Context & Scope" "Findings" "Decisions" "Recommendations")

# NOTE: "Verification Tier" is deliberately NOT a member of PLAN_METADATA. PLAN_METADATA drives
# a whole-document `grep -qF` existence check (see "Check metadata fields" below) that passes as
# soon as the field text appears ANYWHERE in the file -- e.g. once, in phase 1 only. Verification
# Tier is a PER-PHASE field; whole-document existence would silently under-enforce it (pass a
# plan where only one of several phases is tiered). It is checked instead by the dedicated
# per-phase-block loop in the "Plan-specific checks" section below.
#
# "Files to modify" is likewise deliberately NOT a member of PLAN_METADATA, and for the same
# reason: it is a PER-PHASE field, so a whole-document existence check would pass a plan where
# only one phase declares it. It is checked instead by the dedicated per-phase-block loop (the
# two-tier presence check, immediately after the Verification Tier loop below).
PLAN_METADATA=("Task" "Status" "Effort" "Dependencies" "Research Inputs" "Artifacts" "Standards" "Type")
PLAN_SECTIONS=("Overview" "Goals & Non-Goals" "Risks & Mitigations" "Implementation Phases" "Testing & Validation" "Artifacts & Outputs" "Rollback/Contingency")

# NOTE: SUMMARY_SECTIONS is a required *minimum*, not an exhaustive whitelist. The check loop
# below only reports a *missing* required section -- it never enumerates a document's headings
# against this array -- so a summary carrying additional sections beyond these six is accepted
# by design, not by oversight. See context/formats/summary-format.md's "Optional Sections"
# subsection for the standard's own statement of this semantics.
SUMMARY_METADATA=("Task" "Status" "Started" "Completed" "Artifacts" "Standards")
SUMMARY_SECTIONS=("Overview" "What Changed" "Decisions" "Impacts" "Follow-ups" "References")

# The array below is documentation-only: it is deliberately never wired into `required_sections`
# below and has no effect on validation. It exists solely to keep this script and
# context/formats/summary-format.md's "Optional Sections" subsection from drifting out of sync
# -- "Plan Deviations" is the dominant convention across implementation-terminus agents and is
# named explicitly in the standard as a recognized optional section.
# shellcheck disable=SC2034  # Deliberately documentation-only -- see the comment above.
SUMMARY_SECTIONS_OPTIONAL=("Plan Deviations")

# --- Arguments ---
artifact_path="${1:-}"
artifact_type="${2:-}"
fix_mode=false
strict_mode=false

shift 2 2>/dev/null || true
for arg in "$@"; do
  case "$arg" in
    --fix) fix_mode=true ;;
    --strict) strict_mode=true ;;
  esac
done

# --- Validation ---
errors=0
warnings=0
fixes=0

# NOTE: use `var=$((var + 1))` assignment form, not bare `((var++))`. Under `set -euo pipefail`,
# a bare post-increment `((var++))` evaluates to the PRE-increment value, so the 0->1 transition
# (the very first call) evaluates to arithmetic 0/false and triggers `set -e` to abort the whole
# script immediately -- silently truncating validation to a single reported issue with no
# [PASS]/[FAIL] summary. The assignment form has no such landmine.
log_error() { echo "  [ERROR] $1"; errors=$((errors + 1)); }
log_warn()  { echo "  [WARN]  $1"; warnings=$((warnings + 1)); }
log_fix()   { echo "  [FIXED] $1"; fixes=$((fixes + 1)); }
log_info()  { echo "  [INFO]  $1"; }

if [ -z "$artifact_path" ] || [ -z "$artifact_type" ]; then
  echo "Usage: validate-artifact.sh <artifact_path> <type> [--fix] [--strict]"
  echo "Types: report, plan, summary"
  exit 4
fi

if [ ! -f "$artifact_path" ]; then
  echo "[FAIL] File not found: $artifact_path"
  exit 3
fi

if [ ! -s "$artifact_path" ]; then
  echo "[FAIL] File is empty: $artifact_path"
  exit 1
fi

# Select field/section arrays by type
case "$artifact_type" in
  report)
    metadata_fields=("${REPORT_METADATA[@]}")
    required_sections=("${REPORT_SECTIONS[@]}")
    ;;
  plan)
    metadata_fields=("${PLAN_METADATA[@]}")
    required_sections=("${PLAN_SECTIONS[@]}")
    ;;
  summary)
    metadata_fields=("${SUMMARY_METADATA[@]}")
    required_sections=("${SUMMARY_SECTIONS[@]}")
    ;;
  *)
    echo "[FAIL] Unknown artifact type: $artifact_type (expected: report, plan, summary)"
    exit 4
    ;;
esac

echo "Validating $artifact_type: $artifact_path"

# --- Check H1 title ---
if ! grep -qE '^# ' "$artifact_path"; then
  log_error "Missing H1 title heading"
fi

# --- Check metadata fields ---
missing_metadata=()
for field in "${metadata_fields[@]}"; do
  if ! grep -qF "**${field}**:" "$artifact_path"; then
    missing_metadata+=("$field")
    log_error "Missing metadata field: **${field}**:"
  fi
done

# --- Auto-fix missing metadata (--fix mode) ---
if [ "$fix_mode" = true ] && [ ${#missing_metadata[@]} -gt 0 ]; then
  # Anchor search is restricted to lines naming a KNOWN metadata field for this artifact type
  # (built from metadata_fields itself, so it can never drift from the arrays it serves) --
  # never an arbitrary bold bullet elsewhere in the document, e.g. a "- **Files verified**: Yes
  # -- ..." bullet in a Verification section. Accepts both the bullet form "- **Field**:" and
  # the bare form "**Field**:" (the convention actually used by every real artifact).
  field_alt=""
  for field in "${metadata_fields[@]}"; do
    field_esc=$(printf '%s' "$field" | sed -e 's/[][\.*^$/]/\\&/g')
    field_alt="${field_alt:+${field_alt}|}${field_esc}"
  done
  # `|| true` guards against set -e/pipefail aborting this assignment when grep finds zero
  # matches (grep's own exit 1 would otherwise propagate through the pipeline and silently kill
  # the whole script here, before the "Cannot auto-fix" warning or the terminal [FAIL]/[PASS]
  # line -- the same crash class this phase exists to remove, latent on the no-anchor path).
  last_meta_line=$(grep -nE "^-?[[:space:]]*\*\*(${field_alt})\*\*:" "$artifact_path" | tail -1 | cut -d: -f1) || true

  if [ -n "$last_meta_line" ]; then
    # Rewrite via an awk pass to a temp file + mv. The missing-field placeholder lines (never
    # artifact content) are passed on awk's stdin via getline, so no document content is ever
    # interpolated into a shell or sed expression again.
    tmp_file=$(mktemp)
    printf -- '- **%s**: TBD\n' "${missing_metadata[@]}" | awk -v anchor="$last_meta_line" '
      { print }
      NR == anchor {
        while ((getline line < "/dev/stdin") > 0) print line
      }
    ' "$artifact_path" > "$tmp_file"
    mv "$tmp_file" "$artifact_path"

    for field in "${missing_metadata[@]}"; do
      log_fix "Inserted placeholder: - **${field}**: TBD"
    done

    # Reduce error count for fixed fields
    errors=$((errors - ${#missing_metadata[@]}))
  else
    log_warn "Cannot auto-fix: no existing metadata lines found to anchor insertion"
  fi
fi

# --- Check required sections ---
for section in "${required_sections[@]}"; do
  if ! grep -qE "^##+ ${section}" "$artifact_path"; then
    log_error "Missing required section: ## ${section}"
  fi
done

# --- Carried-figure source-naming well-formedness check (advisory-first; see
# context/formats/report-format.md's "## Carried-Figure Discipline" / "Enforcement level"
# subsection for the full rule). Scoped to report and plan artifacts only --
# summary-format.md carries no carried-figure obligation. This checks only that every mark of
# a fixed literal token in CFD_TOKENS below names a non-empty designator before its closing
# bracket: a well-formedness check on each token's syntax, never a semantic contradiction check
# (see that subsection's Reasoned Exclusions for why resolve-checking the named source and
# missing-mark detection are both out of scope). CARRIED-UNVERIFIED is the original token
# (Carried-Figure Discipline's own mark); CORPUS-UNVERIFIED is the Out-of-scope paragraph's new
# token for a recommendation that asserts a measurable property of the live corpus;
# COVERAGE-UNVERIFIED is the Enumeration-completeness paragraph's new disclosure mark for an
# enumeration the author believes complete but did not cross-check with a second,
# differently-shaped pattern. All three are different claim shapes, sharing the same mechanical
# surface because each is "a literal token must name a non-empty designator" with no semantic
# component.
#
# Newlines are flattened before matching because real marks in the corpus wrap across source
# lines; a per-line `grep -E` would miss them. An occurrence immediately preceded by a backtick
# or a backslash is a MENTION of the token (inside inline code, a `grep` literal, or an escaped
# regex) rather than a mark on a carried figure, and is suppressed -- measured against the live
# corpus, this is a required property of the check, not an optimization: without it, a document
# that merely discusses the token (this script's own test suite and report-format.md itself)
# draws spurious advisories. The designator window is bounded so one unclosed occurrence cannot
# consume text up to an arbitrarily distant later closing bracket, which would otherwise hide a
# genuinely malformed mark that follows it.
#
# PROMOTION CRITERION (do not promote either condition, for any token in CFD_TOKENS, from log_warn to
# log_error as part of an unrelated change): promote only once a corpus-wide sweep confirms zero
# advisories fire across every non-terminal report/plan artifact under specs/ -- the same bar
# already applied to the Verification Tier and Files to modify advisories above. Promotion to
# blocking is explicitly NOT part of this change.
if [ "$artifact_type" = "report" ] || [ "$artifact_type" = "plan" ]; then
  CFD_TOKENS=("CARRIED-UNVERIFIED" "CORPUS-UNVERIFIED" "COVERAGE-UNVERIFIED")
  _cfd_window=500
  for _cfd_token in "${CFD_TOKENS[@]}"; do
    _cfd_counts=$(awk -v token="$_cfd_token" -v win="$_cfd_window" '
      { flat = flat $0 " " }
      END {
        tok = "[" token ":"
        toklen = length(tok)
        n = length(flat)
        pos = 1
        empty_n = 0
        unclosed_n = 0
        while (1) {
          rel = index(substr(flat, pos), tok)
          if (rel == 0) break
          idx = pos + rel - 1
          pre = (idx > 1) ? substr(flat, idx - 1, 1) : ""
          if (pre != "`" && pre != "\\") {
            wstart = idx + toklen
            wlen = win
            if (wstart + wlen - 1 > n) wlen = n - wstart + 1
            if (wlen < 0) wlen = 0
            window = substr(flat, wstart, wlen)
            close_pos = index(window, "]")
            if (close_pos == 0) {
              unclosed_n++
            } else {
              desig = substr(window, 1, close_pos - 1)
              gsub(/^[ \t]+/, "", desig)
              gsub(/[ \t]+$/, "", desig)
              if (desig == "") empty_n++
            }
          }
          pos = idx + toklen
        }
        print empty_n, unclosed_n
      }
    ' "$artifact_path")
    read -r _cfd_empty_count _cfd_unclosed_count <<< "$_cfd_counts"
    if [ "${_cfd_empty_count:-0}" -gt 0 ]; then
      log_warn "${_cfd_empty_count} ${_cfd_token} mark(s) have an empty or whitespace-only source designator -- a named source is mandatory (context/formats/report-format.md's Carried-Figure Discipline)"
    fi
    if [ "${_cfd_unclosed_count:-0}" -gt 0 ]; then
      log_warn "${_cfd_unclosed_count} ${_cfd_token} mark(s) have no closing bracket within the designator window -- an unclosed mark cannot be confirmed to name a source"
    fi
  done
fi

# --- Plan-specific checks ---
if [ "$artifact_type" = "plan" ]; then
  # --- Shared phase-heading pattern library (lazy: only the "plan" branch needs it) ---
  # Resolved as this script's own lib/ sibling via ${BASH_SOURCE[0]} (never "$0", which breaks
  # under indirect invocation) -- this single form is correct in BOTH the deployed tree
  # (.claude/scripts/validate-artifact.sh -> .claude/scripts/lib/...) and the source store
  # (agent-system/extensions/core/scripts/validate-artifact.sh -> .../scripts/lib/...) without
  # needing a REPO_ROOT-guessing candidate list, because the library is always this script's own
  # lib/ sibling in either tree. Never falls through to an inline pattern: a missing library is a
  # loud environment error (exit 5), not a silent degradation. See
  # context/formats/plan-format.md's "Canonical phase-heading shape" subsection.
  _validate_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  _phase_lib_candidates=(
    "$_validate_script_dir/lib/phase-heading-patterns.sh"
  )
  _phase_lib=""
  for _candidate in "${_phase_lib_candidates[@]}"; do
    if [ -f "$_candidate" ]; then
      _phase_lib="$_candidate"
      break
    fi
  done
  if [ -z "$_phase_lib" ]; then
    echo "Error: shared library phase-heading-patterns.sh not found at any of:" >&2
    for _candidate in "${_phase_lib_candidates[@]}"; do
      echo "  $_candidate" >&2
    done
    exit 5
  fi
  # shellcheck disable=SC1090
  . "$_phase_lib"

  # --- Shared source-store path library (lazy, fail-soft: only the "plan" branch's Files-to-
  # modify authoring-shape advisory scan below needs source_store_unexpanded_variable). Unlike
  # the two libraries above, an unavailable library here degrades to "no unexpanded-variable
  # advisory this run" rather than a loud exit 5 -- this check is itself advisory-only (never
  # fails the artifact), so its own dependency failure stays advisory-only too. ---
  # shellcheck disable=SC1091
  . "$_validate_script_dir/lib/source-store-path-lib.sh" 2>/dev/null || true

  # --- Shared plan-level Status-line grammar library (lazy: only the "plan" branch needs it) ---
  # Same lazy, ${BASH_SOURCE[0]}-relative, exit-5-on-missing idiom as phase-heading-patterns.sh
  # above -- correct in both the source store and the deployed tree. Never falls through to an
  # inline pattern.
  _status_line_lib_candidates=(
    "$_validate_script_dir/lib/plan-status-line.sh"
  )
  _status_line_lib=""
  for _candidate in "${_status_line_lib_candidates[@]}"; do
    if [ -f "$_candidate" ]; then
      _status_line_lib="$_candidate"
      break
    fi
  done
  if [ -z "$_status_line_lib" ]; then
    echo "Error: shared library plan-status-line.sh not found at any of:" >&2
    for _candidate in "${_status_line_lib_candidates[@]}"; do
      echo "  $_candidate" >&2
    done
    exit 5
  fi
  # shellcheck disable=SC1090
  . "$_status_line_lib"

  # --- Shared suite-selection library (lazy: only the Tier Justification measurement check
  # below needs it). Same lazy, ${BASH_SOURCE[0]}-relative, exit-5-on-missing idiom as the two
  # libraries above -- correct in both the source store and the deployed tree. The library sets
  # no shell options and never calls `exit` itself (see its own header contract), so sourcing it
  # is safe under this script's `set -euo pipefail` posture.
  _suite_selection_lib_candidates=(
    "$_validate_script_dir/lib/suite-selection-lib.sh"
  )
  _suite_selection_lib=""
  for _candidate in "${_suite_selection_lib_candidates[@]}"; do
    if [ -f "$_candidate" ]; then
      _suite_selection_lib="$_candidate"
      break
    fi
  done
  if [ -z "$_suite_selection_lib" ]; then
    echo "Error: shared library suite-selection-lib.sh not found at any of:" >&2
    for _candidate in "${_suite_selection_lib_candidates[@]}"; do
      echo "  $_candidate" >&2
    done
    exit 5
  fi
  # shellcheck disable=SC1090
  . "$_suite_selection_lib"

  # --- Plan-level Status-line grammar check (error level: DEFECT 2 -- the validator previously
  # checked only field PRESENCE via the whole-document grep above, so a hand-typed, bracket-losing
  # value like "- **Status**: COMPLETED" validated as [PASS]. Landed at error, not warn, because a
  # repo-wide sweep of every specs/*/plans/*.md and specs/archive/*/plans/*.md file found zero
  # non-conforming plans as of this check's authoring -- see this task's own summary for the sweep
  # command and count. No --fix participation: see the header comment above for the reasoning. ---
  _status_classification="$(plan_status_classify "$artifact_path")"
  _status_shape="${_status_classification%% *}"
  if [ "$_status_shape" != "OK" ]; then
    _status_error_msg="$(plan_status_error_message "$_status_classification")"
    _status_line_num="$(echo "$_status_classification" | awk '{print $2}')"
    if [ -n "$_status_line_num" ]; then
      log_error "${_status_error_msg} (line ${_status_line_num})"
    else
      log_error "${_status_error_msg}"
    fi
  fi

  # Check for at least one Phase heading. Uses the LOOSE "claims to be a phase heading" form
  # (PHASE_HEADING_LOOSE_ERE) rather than the canonical form, so a plan whose only headings are
  # non-conforming (e.g. all `3a`/`3b`/`3c`) is correctly routed to the non-conforming check below
  # rather than misreported here as having no phase headings at all.
  if ! grep -qE "$PHASE_HEADING_LOOSE_ERE" "$artifact_path"; then
    log_error "Missing Phase headings (expected: ### Phase N: {name} [STATUS])"
  fi

  # Check for Dependency Analysis table
  if ! grep -qF "Dependency Analysis" "$artifact_path"; then
    log_warn "Missing Dependency Analysis table under Implementation Phases"
  fi

  # --- Non-conforming phase-heading check (D3: advisory-first, --strict enforces) ---
  # Fixes the phase-number reporting collapse where distinct non-conforming headings (e.g.
  # `3a`/`3b`/`3c`) were previously chained through a single grep -oE extraction and could be
  # mis-attributed to one number. extract_phase_number below never returns a truncated prefix.
  # Message text is delegated to the library's warn_nonconforming rather than composed locally,
  # so the `[DESCOPED]` -> `[COMPLETED WITH EXCLUSIONS]` replacement guidance lives in ONE place.
  _nonconforming_findings="$(nonconforming_phase_headings "$artifact_path")"
  if [ -n "$_nonconforming_findings" ]; then
    _nonconforming_count=$(printf '%s\n' "$_nonconforming_findings" | wc -l | tr -d ' ')
    warn_nonconforming "$artifact_path" "validate-artifact" || true
    if [ "$strict_mode" = true ]; then
      log_error "${_nonconforming_count} non-conforming phase heading(s) found (letter-suffixed number, extra decimal level, or unrecognized status marker -- see the NON-CONFORMING PHASE HEADING warnings above for per-heading detail)"
    else
      log_warn "${_nonconforming_count} non-conforming phase heading(s) found (letter-suffixed number, extra decimal level, or unrecognized status marker -- see the NON-CONFORMING PHASE HEADING warnings above for per-heading detail)"
    fi
  fi

  # --- Per-phase Verification Tier check (advisory-first, D3: warn not error) ---
  # Promotion criterion (per context/formats/plan-format.md's "Enforcement level" subsection):
  # promote this from log_warn to log_error once no non-terminal plan under specs/ lacks the
  # field. Until then, default mode stays advisory (exits 0 on tier warnings alone) so legacy
  # plans authored before this vocabulary existed keep passing; --strict enforces it today via
  # the existing total_issues=$((errors + warnings)) branch below.
  #
  # NOTE: do NOT promote this Verification Tier advisory to an error as part of this migration --
  # out of scope, and its documented promotion criterion (above) is unmet.
  mapfile -t phase_line_nums < <(grep -nE "$PHASE_HEADING_ERE" "$artifact_path" | cut -d: -f1)
  if [ "${#phase_line_nums[@]}" -gt 0 ]; then
    total_lines=$(wc -l < "$artifact_path")
    _ftm_omitting_phases=()
    # The final phase (highest-numbered, last heading in the file) carries no Tier
    # Justification line by standard -- the Tier Justification measurement check below must
    # never warn on its absence. See plan-format.md's "`**Tier Justification**:` -- required on
    # every non-final phase" subsection.
    _final_phase_idx=$(( ${#phase_line_nums[@]} - 1 ))
    # Cross-phase ceiling consistency (advisory-first; see plan-format.md's "Cross-phase
    # ceiling consistency obligation" and its paired "Enforcement level (Cross-phase ceiling
    # consistency)" subsection for the full rule and promotion criterion). Accumulated per unit
    # word across all phases in this plan, consumed by the whole-document scan after the loop.
    declare -A _ceiling_unit_sum=()
    declare -A _ceiling_unit_phases=()
    for i in "${!phase_line_nums[@]}"; do
      start_line="${phase_line_nums[$i]}"
      phase_heading=$(sed -n "${start_line}p" "$artifact_path")
      phase_num=$(extract_phase_number "$phase_heading") || phase_num=""
      if [ $((i + 1)) -lt "${#phase_line_nums[@]}" ]; then
        end_line=$(( phase_line_nums[$((i + 1))] - 1 ))
      else
        end_line="$total_lines"
      fi
      phase_block=$(sed -n "${start_line},${end_line}p" "$artifact_path")
      # Accept both punctuation conventions (D7): **Verification Tier**: and **Verification Tier:**
      tier_value=$(echo "$phase_block" | grep -oE '\*\*Verification Tier\*\*:[[:space:]]*[A-Za-z]+|\*\*Verification Tier:\*\*[[:space:]]*[A-Za-z]+' | head -1 | grep -oE '[A-Za-z]+$' || true)
      if [ -z "$tier_value" ]; then
        log_warn "Phase ${phase_num} missing **Verification Tier** field"
      elif ! echo "$tier_value" | grep -qE '^(prose|local|interface|full)$'; then
        log_warn "Phase ${phase_num} has unrecognized **Verification Tier** value: ${tier_value}"
      fi

      # --- Files to modify header-presence test (two-tier, D3-style: see the deferred emission
      # block below the loop for the tier rationale). Accepts both punctuation conventions and
      # an optional single leading list marker, mirroring plan-file-scope-harvest.sh's
      # strip_marker() grammar verbatim rather than inventing a third grammar: this script never
      # parses list-item path entries (that remains the harvester's sole territory), it only
      # tests whether the header line itself is present anywhere in the phase's own block.
      if ! echo "$phase_block" | grep -qE '^[[:space:]]*(-[[:space:]]+)?\*\*Files to modify\*\*:|^[[:space:]]*(-[[:space:]]+)?\*\*Files to modify:\*\*'; then
        _ftm_omitting_phases+=("$phase_num")
      fi

      # --- Files to modify authoring-shape advisory scan (advisory-first; see plan-format.md's
      # paired "Enforcement level (Files to modify authoring shape)" subsection for the full rule
      # and promotion criterion). Surfaces the #417 authoring shapes at plan-acceptance time,
      # where the author can still fix them, rather than at implement time via a harvester drop:
      # (i) a wrapped-continuation entry line whose immediately following line, leading
      # whitespace stripped, itself begins with a backtick; (ii) an entry line carrying a second
      # backtick-delimited path joined by a comma; (iii) an entry naming a deployed-tree path
      # (`.claude`, `.claude/`, or prefixed `.claude/`) instead of the `__WHOLE_TREE__` sentinel;
      # (iv) an entry carrying an unexpanded shell-variable shape (a `$` followed by an
      # identifier, or a `${...}` form) instead of the source-store path as it is actually
      # spelled on disk -- the same shape plan-file-scope-harvest.sh's own final refusal stage
      # refuses at harvest time, surfaced here earlier still, at plan-acceptance time. Uses the
      # same shared `source_store_unexpanded_variable` predicate (lazily sourced, fail-soft,
      # above); shape (iv) is skipped entirely when that library did not source.
      # Body-only capture (header line excluded via `next`), stopping at the first blank line or
      # the next bolded field label -- the same block-termination shape the Tier Justification
      # capture just below already uses, so this check introduces no new capture grammar.
      _ftm_block=$(echo "$phase_block" | awk '
        /^[[:space:]]*(-[[:space:]]+)?\*\*Files to modify\*\*:|^[[:space:]]*(-[[:space:]]+)?\*\*Files to modify:\*\*/ { capture=1; next }
        capture && /^[[:space:]]*$/ { exit }
        capture && /^[[:space:]]*(-[[:space:]]+)?\*\*[A-Za-z]/ { exit }
        capture { print }
      ')
      if [ -n "$_ftm_block" ]; then
        mapfile -t _ftm_lines <<< "$_ftm_block"
        _ftm_shape_continuation=0
        _ftm_shape_commajoin=0
        _ftm_shape_claude=0
        _ftm_shape_unexpanded=0
        for ((_ftm_i = 0; _ftm_i < ${#_ftm_lines[@]}; _ftm_i++)); do
          _ftm_line="${_ftm_lines[$_ftm_i]}"
          # Entry-line test (optional leading list marker, same anchoring the header-presence
          # test above and the harvester's own strip_marker()/entry grammar use).
          if [[ "$_ftm_line" =~ ^[[:space:]]*-[[:space:]]*\` ]]; then
            # Shape (iii): the entry's first backtick-delimited token is a deployed-tree path.
            _ftm_entry_path=$(echo "$_ftm_line" | sed -E 's/^[[:space:]]*-[[:space:]]*`([^`]*)`.*/\1/')
            if [[ "$_ftm_entry_path" == ".claude" || "$_ftm_entry_path" == ".claude/" || "$_ftm_entry_path" == .claude/* ]]; then
              _ftm_shape_claude=1
            fi
            # Shape (iv): the entry's first backtick-delimited token carries an unexpanded
            # shell-variable shape. Skipped entirely when the library did not source above.
            if declare -F source_store_unexpanded_variable >/dev/null 2>&1 \
               && source_store_unexpanded_variable "$_ftm_entry_path"; then
              _ftm_shape_unexpanded=1
            fi
            # Shape (ii): a second backtick-delimited path joined by a comma on the same line.
            if echo "$_ftm_line" | grep -qE '`[^`]*`[[:space:]]*,[[:space:]]*`[^`]*`'; then
              _ftm_shape_commajoin=1
            fi
            # Shape (i): the immediately following line, leading whitespace stripped, itself
            # begins with a backtick (the wrapped-continuation shape -- it carries no leading
            # `- ` marker, so the harvester's entry grammar reads it as prose, not a second
            # entry).
            if [ $((_ftm_i + 1)) -lt "${#_ftm_lines[@]}" ]; then
              _ftm_next_stripped=$(echo "${_ftm_lines[$((_ftm_i + 1))]}" | sed -E 's/^[[:space:]]+//')
              if [[ "$_ftm_next_stripped" == \`* ]]; then
                _ftm_shape_continuation=1
              fi
            fi
          fi
        done
        if [ "$_ftm_shape_continuation" -eq 1 ]; then
          log_warn "Phase ${phase_num} Files to modify: a wrapped-continuation line begins with a backtick but carries no leading '- ' marker, so it is read as prose, not a second entry -- give it its own '- \`path\`' line"
        fi
        if [ "$_ftm_shape_commajoin" -eq 1 ]; then
          log_warn "Phase ${phase_num} Files to modify: an entry line joins a second backtick-delimited path with a comma -- only the first path is harvested; give each path its own '- \`path\`' line"
        fi
        if [ "$_ftm_shape_claude" -eq 1 ]; then
          log_warn "Phase ${phase_num} Files to modify: a deployed-tree (.claude/**) path is named directly -- it is never a legitimate file_scope member (rules/source-store-deploy-boundary.md); declare a whole-deployed-tree claim with the \`__WHOLE_TREE__\` sentinel instead"
        fi
        if [ "$_ftm_shape_unexpanded" -eq 1 ]; then
          log_warn "Phase ${phase_num} Files to modify: an entry carries an unexpanded shell-variable shape (a \$VAR or \${VAR} form) -- no such variable is ever expanded on the commit path, so it will be refused at harvest time and match nothing; write the source-store path as it is actually spelled on disk instead (agent-system/extensions/<name>/...)"
        fi
      fi

      # --- Tier Justification measurement check (advisory-first; see plan-format.md's
      # "`**Tier Justification**:` -- required on every non-final phase" subsection and its
      # paired "Enforcement level (Tier Justification measurement)" subsection for the full rule
      # and promotion criterion). Re-derives suite_selection_select's actual output for this
      # phase's own touched paths and compares it against this phase's own Tier Justification
      # claim, in BOTH directions: a claimed suite the selector does not return (fabrication) and
      # a suite the selector returns that the claim omits (under-verification) -- including the
      # __FULL_SWEEP__ sentinel as a measurable claim in its own right, per the defect this check
      # closes. Bounded to suite_selection_select-grounded claims only: a phase whose Tier
      # Justification names neither a suite nor the sentinel (the `full`-tier or `--only-gate`
      # gate-subset shape) is out of this check's scope and is passed over silently. Never runs
      # on the final phase, which carries no justification line by standard.
      if [ "$i" -ne "$_final_phase_idx" ]; then
        # Anchored to line-start (optional leading list marker): a bare substring match would
        # also capture a TASK bullet that merely mentions the field name in backticks (e.g.
        # "- [x] In the `**Tier Justification**:` subsection, add ..."), which precedes the real
        # field line in document order and carries no suite tokens of its own -- exactly the
        # false-sentinel-claim misread this anchoring prevents.
        _tier_just_block=$(echo "$phase_block" | awk '
          /^[[:space:]]*(-[[:space:]]+)?\*\*Tier Justification\*\*:|^[[:space:]]*(-[[:space:]]+)?\*\*Tier Justification:\*\*/ { capture=1 }
          capture { print; if ($0 ~ /^[[:space:]]*$/) exit }
        ')
        if [ -n "$_tier_just_block" ]; then
          # Claim extraction: scan the whole justification block for suite-basename tokens,
          # regardless of whether they appear after a structured `--only SUITE[,SUITE,...]`
          # invocation or in an earlier free-text "measured ... returns `SUITE SUITE`" clause --
          # both are the same underlying claim, and the corpus uses both surface forms
          # interchangeably. A `--only` match never false-positives on the sibling `--only-gate`
          # gate-subset mechanism: "--only-gate" has no whitespace directly after "--only", so it
          # cannot match either extraction below.
          mapfile -t _tj_claimed < <(echo "$_tier_just_block" | grep -oE 'test-[A-Za-z0-9_-]+\.sh' | sort -u)
          if [ "${#_tj_claimed[@]}" -gt 0 ]; then
            _tj_claim_kind="suitelist"
          elif echo "$_tier_just_block" | grep -qF "$SUITE_SELECTION_FULL_SWEEP_SENTINEL"; then
            _tj_claim_kind="sentinel"
          else
            _tj_claim_kind=""
          fi

          if [ -n "$_tj_claim_kind" ]; then
            # Collect this phase's own touched paths via the harvester, reusing its grammar
            # verbatim on a single phase block written to a temp file (confirmed to emit exactly
            # that phase's own paths -- see this task's own Scope Hypothesis). Drop the reserved
            # `__WHOLE_TREE__` sentinel and any non-path placeholder entry (Decision D3) before
            # calling the selector; an empty remaining set skips the check for this phase without
            # emitting anything.
            _tj_tmp_phase_file=$(mktemp)
            printf '%s\n' "$phase_block" > "$_tj_tmp_phase_file"
            _tj_harvested_json=$(bash "$_validate_script_dir/plan-file-scope-harvest.sh" "$_tj_tmp_phase_file" 2>/dev/null) || _tj_harvested_json='[]'
            rm -f "$_tj_tmp_phase_file"
            mapfile -t _tj_touched_raw < <(echo "$_tj_harvested_json" | jq -r '.[]' 2>/dev/null)
            _tj_touched=()
            for _tj_p in "${_tj_touched_raw[@]}"; do
              [ "$_tj_p" = "__WHOLE_TREE__" ] && continue
              case "$_tj_p" in
                */*|*.*) _tj_touched+=("$_tj_p") ;;
              esac
            done

            if [ "${#_tj_touched[@]}" -gt 0 ]; then
              mapfile -t _tj_actual < <(suite_selection_select "${_tj_touched[@]}")
              _tj_actual_is_sentinel=false
              if [ "${#_tj_actual[@]}" -eq 1 ] && [ "${_tj_actual[0]}" = "$SUITE_SELECTION_FULL_SWEEP_SENTINEL" ]; then
                _tj_actual_is_sentinel=true
              fi

              if [ "$_tj_claim_kind" = "sentinel" ]; then
                if [ "$_tj_actual_is_sentinel" = false ]; then
                  log_warn "Phase ${phase_num} Tier Justification claims the __FULL_SWEEP__ sentinel (no suite covers this phase) but suite_selection_select returns real suite(s) for its touched paths: ${_tj_actual[*]} -- unmeasured/false sentinel claim"
                fi
              else
                # suitelist claim
                if [ "$_tj_actual_is_sentinel" = true ]; then
                  log_warn "Phase ${phase_num} Tier Justification names suite(s) (${_tj_claimed[*]}) but suite_selection_select returns the __FULL_SWEEP__ sentinel for its touched paths -- no suite actually covers them (fabricated claim)"
                else
                  _tj_missing=()
                  for _tj_a in "${_tj_actual[@]}"; do
                    _tj_found=false
                    for _tj_c in "${_tj_claimed[@]}"; do
                      if [ "$_tj_a" = "$_tj_c" ]; then
                        _tj_found=true
                        break
                      fi
                    done
                    [ "$_tj_found" = false ] && _tj_missing+=("$_tj_a")
                  done
                  _tj_extra=()
                  for _tj_c in "${_tj_claimed[@]}"; do
                    _tj_found=false
                    for _tj_a in "${_tj_actual[@]}"; do
                      if [ "$_tj_a" = "$_tj_c" ]; then
                        _tj_found=true
                        break
                      fi
                    done
                    [ "$_tj_found" = false ] && _tj_extra+=("$_tj_c")
                  done
                  if [ "${#_tj_missing[@]}" -gt 0 ]; then
                    log_warn "Phase ${phase_num} Tier Justification under-verifies: suite_selection_select additionally returns (${_tj_missing[*]}) for this phase's touched paths, not named in the justification"
                  fi
                  if [ "${#_tj_extra[@]}" -gt 0 ]; then
                    log_warn "Phase ${phase_num} Tier Justification fabricates coverage: suite(s) (${_tj_extra[*]}) named that suite_selection_select does not return for this phase's touched paths"
                  fi
                fi
              fi
            fi
          fi
        fi
      fi

      # --- Cross-phase ceiling consistency: per-phase accumulation step (advisory-first; see
      # the header comment above the two `declare -A` lines preceding this loop). Reads a
      # numeric-with-unit token out of this phase's own **Scope Hypothesis** paragraph (both
      # punctuation conventions, mirroring the Verification Tier check above) and accumulates a
      # running sum per distinct unit word, remembering which phases contributed. The whole-
      # document ceiling-citation / conformance-assertion scan and its log_warn emission happen
      # once, after this loop -- never here -- because a ceiling citation and a conformance
      # assertion both live in plan-level prose, not inside a single phase block.
      #
      # NOTE: do NOT promote this check to log_error as part of an unrelated migration -- its
      # documented promotion criterion (plan-format.md's "Enforcement level (Cross-phase
      # ceiling consistency)" subsection) is unmet, and the extraction below is a deliberately
      # lossy heuristic: a miss here means a missed warning, never a suppressed stricter
      # finding (same tolerance already accepted for the Verification Tier and Files to modify
      # checks above).
      _scope_hyp_block=$(echo "$phase_block" | awk '
        /\*\*Scope Hypothesis\*\*:|\*\*Scope Hypothesis:\*\*/ { capture=1 }
        capture { print; if ($0 ~ /^[[:space:]]*$/) exit }
      ')
      if [ -n "$_scope_hyp_block" ]; then
        while IFS= read -r _tok; do
          [ -z "$_tok" ] && continue
          _num_part=$(echo "$_tok" | grep -oE '^[0-9]+(-[0-9]+)?')
          _unit_word=$(echo "$_tok" | grep -oE '[A-Za-z]+$' | tr '[:upper:]' '[:lower:]')
          if [ -z "$_num_part" ] || [ -z "$_unit_word" ]; then
            continue
          fi
          # Normalize to a singular stem (strip one trailing "s") so a plural per-phase
          # estimate ("60 added lines") and a singular, hyphen-joined ceiling citation
          # ("a 1500-line limit") are recognized as the SAME unit word -- a substring match on
          # the stem matches both the singular and plural surface forms in the scan below.
          _unit_word="${_unit_word%s}"
          if [ -z "$_unit_word" ]; then
            continue
          fi
          if [[ "$_num_part" == *-* ]]; then
            _value="${_num_part#*-}"
          else
            _value="$_num_part"
          fi
          _prev_sum=${_ceiling_unit_sum[$_unit_word]:-0}
          _ceiling_unit_sum[$_unit_word]=$((_prev_sum + _value))
          _ceiling_unit_phases[$_unit_word]="${_ceiling_unit_phases[$_unit_word]:-}${_ceiling_unit_phases[$_unit_word]:+ }${phase_num}"
        done < <(echo "$_scope_hyp_block" | grep -oE '[0-9]+(-[0-9]+)?[[:space:]]+(added[[:space:]]+)?[A-Za-z]+' || true)
      fi
    done

    # --- Deferred two-tier "Files to modify" presence emission (D3: per-phase omission warns,
    # --strict enforces via the existing total_issues=$((errors + warnings)) branch below, exactly
    # as the Verification Tier check above; whole-plan omission -- every phase in this file omits
    # the field -- errors unconditionally, since that is the shape that leaves
    # plan-file-scope-harvest.sh with nothing to harvest and the task's file_scope null and
    # invisible to the admission overlap gate). Emitted AFTER the loop, once, so the two tiers
    # never double-report for the same plan.
    #
    # Promotion criterion (per context/formats/plan-format.md's "Enforcement level" subsection for
    # this field): promote the per-phase warning to an error once no non-terminal plan under
    # specs/ has any phase lacking the field. Until then, default mode stays advisory on the
    # per-phase tier (a plan with only some phases omitting it still exits 0 on warnings alone);
    # the whole-plan tier is error-by-default already, landed at that level because a
    # plan-time sweep found exactly one whole-plan miss across the active-plan corpus, repaired as
    # this change's own regression fixture -- see this field's "Enforcement level" subsection in
    # plan-format.md for the measured residue.
    if [ "${#_ftm_omitting_phases[@]}" -eq "${#phase_line_nums[@]}" ]; then
      log_error "Every phase omits the **Files to modify** field -- plan-file-scope-harvest.sh harvests nothing, file_scope stays null, and this task is invisible to the admission overlap gate"
    else
      for _ftm_phase_num in "${_ftm_omitting_phases[@]}"; do
        log_warn "Phase ${_ftm_phase_num} missing **Files to modify** field"
      done
    fi

    # --- Cross-phase ceiling consistency: whole-document ceiling-citation / conformance-
    # assertion scan (advisory-first; see the accumulation step's header comment above and
    # plan-format.md's "Cross-phase ceiling consistency obligation" / "Enforcement level
    # (Cross-phase ceiling consistency)" subsections for the full rule and promotion criterion).
    # Fires only when all three hold for the SAME unit word: per-phase estimates accumulated
    # above, a ceiling citation (a digit, a ceiling-indicating word, and the unit word all on
    # one line -- deliberately strict to keep false positives low), and a conformance
    # assertion (stays/remains [well] under/within/below) naming the same unit word anywhere in
    # the document. `--strict` promotes a hit via the existing total_issues=$((errors +
    # warnings)) branch below; no new strictness logic is added for this check.
    for _unit_word in "${!_ceiling_unit_sum[@]}"; do
      _ceiling_sum="${_ceiling_unit_sum[$_unit_word]}"
      _ceiling_line=$(grep -E '[0-9]' "$artifact_path" | grep -iE '(ceiling|limit|budget|cap)' | grep -iE "${_unit_word}" | head -1 || true)
      if [ -z "$_ceiling_line" ]; then
        continue
      fi
      _ceiling_value=$(echo "$_ceiling_line" | grep -oE '[0-9]+' | head -1 || true)
      if [ -z "$_ceiling_value" ]; then
        continue
      fi
      _conformance_line=$(grep -iE '(stays|remains)[[:space:]]+(well[[:space:]]+)?(under|within|below)' "$artifact_path" | grep -iE "${_unit_word}" | head -1 || true)
      if [ -z "$_conformance_line" ]; then
        continue
      fi
      # Best-effort stated starting baseline for this unit word (e.g. "a 959-line starting
      # file"); absence means baseline 0 -- never treated as a fact, only ever added to the sum.
      _baseline_line=$(grep -iE "[0-9]+-?${_unit_word}[^.]{0,40}(starting|baseline)" "$artifact_path" | head -1 || true)
      _baseline=0
      if [ -n "$_baseline_line" ]; then
        _baseline=$(echo "$_baseline_line" | grep -oE '[0-9]+' | head -1 || true)
        [ -z "$_baseline" ] && _baseline=0
      fi
      _ceiling_total=$((_ceiling_sum + _baseline))
      if [ "$_ceiling_total" -gt "$_ceiling_value" ]; then
        log_warn "Per-phase ${_unit_word} estimates (phases:${_ceiling_unit_phases[$_unit_word]}) sum to ${_ceiling_total} (incl. baseline ${_baseline}), past the cited ${_ceiling_value}-${_unit_word} ceiling this plan also asserts it stays within"
      fi
    done
  fi
fi

# --- Summary ---
total_issues=$((errors + warnings))
if [ "$strict_mode" = true ]; then
  total_issues=$((errors + warnings))
else
  total_issues=$errors
fi

if [ $fixes -gt 0 ]; then
  echo "[FIXED] $fixes field(s) auto-repaired, $errors error(s), $warnings warning(s) remaining"
  exit 2
elif [ $total_issues -eq 0 ]; then
  echo "[PASS] $artifact_type artifact is valid ($warnings warning(s))"
  exit 0
else
  echo "[FAIL] $errors error(s), $warnings warning(s)"
  exit 1
fi
