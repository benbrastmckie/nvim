#!/usr/bin/env bash
# PostToolUse hook: detect direct writes to .claude/ paths during /meta execution
# Triggers on Write/Edit targeting .claude/ system files
# Returns additionalContext (advisory) with corrective message - does NOT block
#
# This mirrors validate-plan-write.sh but for the /meta anti-bypass pattern.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_DEFECT_RECORD="$SCRIPT_DIR/../scripts/system-defect-record.sh"

# Parse file path from stdin (PostToolUse hook input)
CC_SESSION_ID=""
CWD=""
if [ -t 0 ]; then
  # Fallback: try env var
  FILE=$(echo "${CLAUDE_TOOL_INPUT:-}" 2>/dev/null | jq -r '.file_path // empty' 2>/dev/null) || true
else
  INPUT=$(cat) || true
  FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || true
  if [ -z "$FILE" ]; then
    FILE=$(echo "${CLAUDE_TOOL_INPUT:-}" 2>/dev/null | jq -r '.file_path // empty' 2>/dev/null) || true
  fi
  CC_SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null) || CC_SESSION_ID=""
  CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null) || CWD=""
fi

# Early exit for empty path (~1ms)
if [ -z "$FILE" ]; then
  echo '{}'
  exit 0
fi

# Skip specs/ paths - those are legitimate task management writes
case "$FILE" in
  specs/*|*/specs/*)
    echo '{}'
    exit 0
    ;;
esac

# Check if the path targets .claude/ system files
is_meta_path=false
case "$FILE" in
  .claude/commands/*|*/.claude/commands/*)
    is_meta_path=true
    ;;
  .claude/skills/*|*/.claude/skills/*)
    is_meta_path=true
    ;;
  .claude/agents/*|*/.claude/agents/*)
    is_meta_path=true
    ;;
  .claude/rules/*|*/.claude/rules/*)
    is_meta_path=true
    ;;
  .claude/context/*|*/.claude/context/*)
    is_meta_path=true
    ;;
  .claude/extensions/*|*/.claude/extensions/*)
    is_meta_path=true
    ;;
  .claude/scripts/*|*/.claude/scripts/*)
    is_meta_path=true
    ;;
  .claude/hooks/*|*/.claude/hooks/*)
    is_meta_path=true
    ;;
  */CLAUDE.md)
    is_meta_path=true
    ;;
esac

if [ "$is_meta_path" = "false" ]; then
  echo '{}'
  exit 0
fi

# Deliverable 2(c): record this detection. Signal B's attribution work is largely already done
# here -- FILE is the deploy path already resolved above; the recorder applies the deploy→source
# transform itself. --session omitted (D5 fallback synthesizes one); CC_SESSION_ID threaded as
# the correlation key.
bash "$SYSTEM_DEFECT_RECORD" \
  --defect-class SOURCE_STORE_BOUNDARY_VIOLATION \
  --detecting-site "hooks/validate-meta-write.sh" \
  --message "direct write to .claude/ system file detected: $FILE" \
  --attributed-path "$FILE" \
  ${CC_SESSION_ID:+--cc-session-id "$CC_SESSION_ID"} \
  ${CWD:+--cwd "$CWD"} \
  >/dev/null 2>&1 || echo "Note: system-defect recording failed (non-fatal)" >&2

# Path matches a .claude/ system file - inject corrective context
# This is ADVISORY only (additionalContext), not blocking
cat << 'EOF'
{"additionalContext": "WARNING: .claude/ under this repo is a gitignored, disposable deploy artifact regenerated from a source store. This write will be silently wiped by the next regeneration. Edit the source store instead: read <project-root>/.claude-extensions.json, select the entry under extensions for the owning extension (core for core system files, the extension's own name for extension-owned files), and edit under that entry's source_dir instead. See .claude/rules/source-store-deploy-boundary.md for the full resolution procedure and the unreachable-source-store fallback. This is advisory only and does not block the write."}
EOF

exit 0
