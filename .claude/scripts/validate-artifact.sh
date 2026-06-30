#!/usr/bin/env bash
# validate-artifact.sh - Validate artifact files against format standards
#
# Usage: validate-artifact.sh <artifact_path> <type> [--fix] [--strict]
#
# Types: report, plan, summary
# Exit codes: 0 = valid, 1 = errors found, 2 = auto-fixed, 3 = file not found, 4 = unknown type

set -euo pipefail

# --- Required metadata fields per type ---
# Update these arrays when format standards change
# Sources: .claude/context/formats/{report,plan,summary}-format.md

REPORT_METADATA=("Task" "Started" "Completed" "Effort" "Dependencies" "Sources/Inputs" "Artifacts" "Standards")
REPORT_SECTIONS=("Executive Summary" "Context & Scope" "Findings" "Decisions" "Recommendations")

PLAN_METADATA=("Task" "Status" "Effort" "Dependencies" "Research Inputs" "Artifacts" "Standards" "Type")
PLAN_SECTIONS=("Overview" "Goals & Non-Goals" "Risks & Mitigations" "Implementation Phases" "Testing & Validation" "Artifacts & Outputs" "Rollback/Contingency")

SUMMARY_METADATA=("Task" "Status" "Started" "Completed" "Artifacts" "Standards")
SUMMARY_SECTIONS=("Overview" "What Changed" "Decisions" "Impacts" "Follow-ups" "References")

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

log_error() { echo "  [ERROR] $1"; ((errors++)); }
log_warn()  { echo "  [WARN]  $1"; ((warnings++)); }
log_fix()   { echo "  [FIXED] $1"; ((fixes++)); }
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
  # Find the last existing metadata line (starts with "- **")
  last_meta_line=$(grep -n '^- \*\*' "$artifact_path" | tail -1 | cut -d: -f1)

  if [ -n "$last_meta_line" ]; then
    # Build insertion text for missing fields
    insert_text=""
    for field in "${missing_metadata[@]}"; do
      insert_text="${insert_text}- **${field}**: TBD\n"
    done

    # Insert after last metadata line using sed
    sed -i "${last_meta_line}a\\
$(echo -e "$insert_text" | sed 's/$//' | head -c -1)" "$artifact_path"

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
  # Check for at least one Phase heading
  if ! grep -qE '^### Phase [0-9]+' "$artifact_path"; then
    log_error "Missing Phase headings (expected: ### Phase N: {name} [STATUS])"
  fi

  # Check for Dependency Analysis table
  if ! grep -qF "Dependency Analysis" "$artifact_path"; then
    log_warn "Missing Dependency Analysis table under Implementation Phases"
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
