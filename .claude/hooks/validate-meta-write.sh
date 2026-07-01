#!/bin/bash
# PostToolUse hook: detect direct writes to .claude/ paths during /meta execution
# Triggers on Write/Edit targeting .claude/ system files
# Returns additionalContext (advisory) with corrective message - does NOT block
#
# This mirrors validate-plan-write.sh but for the /meta anti-bypass pattern.

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
  */CLAUDE.md)
    is_meta_path=true
    ;;
esac

if [ "$is_meta_path" = "false" ]; then
  echo '{}'
  exit 0
fi

# Path matches a .claude/ system file - inject corrective context
# This is ADVISORY only (additionalContext), not blocking
cat << 'EOF'
{"additionalContext": "WARNING: You are writing directly to a .claude/ system file. If you are executing within the /meta command context, this is a VIOLATION of the Anti-Bypass Constraint. The /meta command MUST NOT create or modify .claude/ files directly. Instead: (1) Create tasks via TODO.md and state.json, (2) Let users run /research -> /plan -> /implement to execute changes through proper skill delegation. If you are executing within /implement (general-implementation-agent), this write is legitimate and you may proceed."}
EOF

exit 0
