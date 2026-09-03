#!/usr/bin/env bash
# update-plan-status.sh - Centralized plan-level status update
# Usage: .claude/scripts/update-plan-status.sh TASK_NUMBER PROJECT_NAME STATUS
#
# STATUS values: IMPLEMENTING, COMPLETED, PARTIAL, NOT_STARTED, BLOCKED, ABANDONED
#
# Outputs: the plan file path is echoed to stdout both on a successful stamp AND on the
# already-at-target no-op -- stdout alone reliably signals "the plan file is now at the
# requested status" either way. Nothing is echoed to stdout on failure; a failure always prints
# a line-numbered, content-quoting diagnostic to stderr and exits 1 (see the three classified
# malformed-shape messages below and context/formats/plan-format.md's trailing-annotation policy).
#
# Trailing-text tolerance: a plan-level Status line may carry arbitrary trailing text after the
# closing `]` (e.g. a resume annotation) -- that text is preserved verbatim across a stamp. Text
# BETWEEN the `- **Status**: ` prefix and the opening `[`, or a missing bracket pair entirely,
# is malformed and rejected loudly. See context/formats/plan-format.md's "Plan-level vs.
# phase-level markers" subsection for the full policy and examples.

set -euo pipefail

task_number="${1:-}"
project_name="${2:-}"
new_status="${3:-}"

# Validate inputs
if [[ -z "$task_number" || -z "$project_name" || -z "$new_status" ]]; then
    echo "Usage: $0 TASK_NUMBER PROJECT_NAME STATUS" >&2
    exit 1
fi

# Normalize status
# BLOCKED and ABANDONED complete the documented plan-level vocabulary (see
# .claude/context/formats/plan-format.md) ahead of later hardening work that wires call sites.
case "$new_status" in
    IMPLEMENTING|implementing) new_status="IMPLEMENTING" ;;
    COMPLETED|completed) new_status="COMPLETED" ;;
    PARTIAL|partial) new_status="PARTIAL" ;;
    NOT_STARTED|not_started) new_status="NOT STARTED" ;;
    BLOCKED|blocked) new_status="BLOCKED" ;;
    ABANDONED|abandoned) new_status="ABANDONED" ;;
    *) echo "Unknown status: $new_status" >&2; exit 1 ;;
esac

# Find plan file (padded directory)
padded_num=$(printf "%03d" "$task_number")
plan_dir="specs/${padded_num}_${project_name}/plans"

if [[ ! -d "$plan_dir" ]]; then
    # Try unpadded (legacy)
    plan_dir="specs/${task_number}_${project_name}/plans"
fi

if [[ ! -d "$plan_dir" ]]; then
    echo "Plan directory not found for task $task_number" >&2
    exit 1
fi

# Get latest plan file, version-ordered (not mtime-ordered).
# Prefer the MM_{short-slug}.md convention (artifact-formats.md); highest sequence wins.
# Fall back to a plain name sort only when no conforming file exists, so legacy-named
# plans never outrank a conforming one (a plain sort would rank "implementation-001.md"
# above "02_revised.md" because "i" sorts after "0").
plan_file=$(ls "$plan_dir"/[0-9][0-9]_*.md 2>/dev/null | sort | tail -1 || true)
if [[ -z "$plan_file" ]]; then
    plan_file=$(ls "$plan_dir"/*.md 2>/dev/null | sort | tail -1 || true)
fi
if [[ -z "$plan_file" ]]; then
    echo "No plan file found in $plan_dir" >&2
    exit 1
fi

# ─── Shared helpers: both the idempotency read and the post-sed verification read go through
# these, so the two sites cannot drift (mirrors update-phase-status.sh:295-329's idiom). ───

# plan_status_line_number FILE: line number of the first plan-level Status line, or empty if
# none exists.
plan_status_line_number() {
    grep -n "^- \*\*Status\*\*:" "$1" 2>/dev/null | head -1 | cut -d: -f1 || true
}

# plan_status_extract_token FILE LINE_NUMBER: the bracketed status token on that line.
# Anchored to the FIRST `[...]` pair via a `[^[]*` prefix (rather than a greedy `.*` prefix,
# which would match the LAST pair on a line carrying two bracket pairs) -- this must agree with
# the mutating sed below, which also only ever touches the first pair and preserves the rest of
# the line verbatim.
plan_status_extract_token() {
    sed -n "${2}s/[^[]*\[\([^]]*\)\].*/\1/p" "$1"
}

# ─── Classify the plan-level Status line BEFORE the idempotency check, so a malformed line is
# always diagnosed and never silently carried into the mutating sed. ───

status_line_number=$(plan_status_line_number "$plan_file")

if [[ -z "$status_line_number" ]]; then
    echo "Plan-level Status line not found in $plan_file" >&2
    echo "Expected a line of the form: - **Status**: [STATUS]" >&2
    exit 1
fi

status_line=$(sed -n "${status_line_number}p" "$plan_file")

if [[ "$status_line" =~ ^-\ \*\*Status\*\*:\ \[[^]]*\] ]]; then
    : # Well-formed: prefix immediately followed by a bracket pair. Any trailing text after the
      # closing bracket is tolerated by design and preserved below.
elif [[ "$status_line" =~ \[[^]]*\] ]]; then
    # M3: a bracket pair exists on the line, but text intrudes between the prefix and the
    # opening bracket (e.g. "- **Status**: see [NOTE]"). Keeping tolerance narrow to only
    # trailing text (never leading text) is deliberate -- see plan-format.md.
    echo "Plan-level Status line has unexpected text between the prefix and the bracket in $plan_file" >&2
    echo "Line ${status_line_number}: ${status_line}" >&2
    exit 1
else
    # M2: prefix present, but no [...] bracket pair anywhere on the line.
    echo "Plan-level Status line has no [STATUS] bracket pair in $plan_file" >&2
    echo "Line ${status_line_number}: ${status_line}" >&2
    exit 1
fi

# Check current status (idempotency)
current_status=$(plan_status_extract_token "$plan_file" "$status_line_number")
if [[ "$current_status" == "$new_status" ]]; then
    # Already at target, no-op -- still echo the plan path so stdout reliably signals success.
    echo "$plan_file"
    exit 0
fi

# Update plan-level status on the specific line only, preserving any trailing text after the
# closing bracket (the `$`-anchored form this replaces required the line to END at `]`, which
# made a trailing-annotation shape permanently un-stampable).
sed -i "${status_line_number}s/^- \*\*Status\*\*: \[[^]]*\]\(.*\)\$/- **Status**: [${new_status}]\1/" "$plan_file"

# Verify update
updated_status=$(plan_status_extract_token "$plan_file" "$status_line_number")
if [[ "$updated_status" == "$new_status" ]]; then
    echo "$plan_file"
else
    echo "Failed to update status in $plan_file" >&2
    echo "Wanted '${new_status}', got '${updated_status}'" >&2
    echo "Line ${status_line_number}: $(sed -n "${status_line_number}p" "$plan_file")" >&2
    exit 1
fi
