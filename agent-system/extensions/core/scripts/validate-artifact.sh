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
