#!/bin/bash
# PostToolUse hook: validate artifact writes against format standards
# Triggers on Write/Edit to specs/*/plans/*.md, specs/*/reports/*.md, specs/*/summaries/*.md
# Returns additionalContext with corrective message on validation failure

set -uo pipefail

# Parse file path from stdin (PostToolUse hook input)
if [ -t 0 ]; then
  # Fallback: try env var
  FILE=$(echo "$CLAUDE_TOOL_INPUT" 2>/dev/null | jq -r '.file_path // empty' 2>/dev/null)
else
  INPUT=$(cat)
  FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  if [ -z "$FILE" ]; then
    FILE=$(echo "$CLAUDE_TOOL_INPUT" 2>/dev/null | jq -r '.file_path // empty' 2>/dev/null)
  fi
fi

# Early exit for non-artifact paths (~1ms)
if [ -z "$FILE" ]; then
  echo '{}'
  exit 0
fi

# Determine artifact type from path
artifact_type=""
case "$FILE" in
  specs/*/plans/*.md|*/specs/*/plans/*.md)
    artifact_type="plan"
    ;;
  specs/*/reports/*.md|*/specs/*/reports/*.md)
    artifact_type="report"
    ;;
  specs/*/summaries/*.md|*/specs/*/summaries/*.md)
    artifact_type="summary"
    ;;
  *)
    # Not an artifact file - exit silently
    echo '{}'
    exit 0
    ;;
esac

# Locate validate-artifact.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="${SCRIPT_DIR}/scripts/validate-artifact.sh"

if [ ! -x "$VALIDATOR" ]; then
  # Validator missing - warn but don't block
  echo '{"additionalContext": "Warning: validate-artifact.sh not found or not executable. Artifact validation skipped."}'
  exit 0
fi

# Run validation
output=$(bash "$VALIDATOR" "$FILE" "$artifact_type" 2>&1) || true
exit_code=$?

case $exit_code in
  0)
    # Valid - no feedback needed
    echo '{}'
    ;;
  1)
    # Validation errors found
    echo "{\"additionalContext\": \"ARTIFACT VALIDATION FAILED for ${artifact_type}: ${FILE}\\n${output}\\n\\nYou MUST delegate artifact creation to the appropriate skill (skill-planner, skill-researcher, skill-implementer) via the Skill tool. Direct artifact writes bypass format enforcement and produce non-conforming files. Fix the issues above or re-run the command with proper skill delegation.\"}"
    ;;
  2)
    # Auto-fixed
    echo "{\"additionalContext\": \"Artifact ${artifact_type} at ${FILE} had format issues that were auto-repaired. Review the file to ensure correctness.\"}"
    ;;
  *)
    # Other error (file not found, unknown type)
    echo '{}'
    ;;
esac

exit 0
