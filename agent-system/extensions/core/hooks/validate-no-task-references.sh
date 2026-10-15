#!/usr/bin/env bash
# PreToolUse hook: BLOCKS task-number citations in authored deliverables via exit code 2.
# Triggers on Write/Edit to any path outside specs/** (task-management artifacts are exempt --
# task numbers are expected there). Blocking: denies the write via exit 2 + stderr message when
# a citation is found; exits 0 (silent) otherwise, and fails OPEN (exit 0) if its own shared
# pattern library cannot be sourced -- a broken guard must never block every write in the repo.
#
# Modeled on guard-destructive-git.sh: blocks via exit code 2 + a stderr message (NOT
# permissionDecision: deny, which is documented-buggy for allow-listed Write/Edit tool calls --
# see settings.json's permissions.allow bare "Write"/"Edit" entries and GH issues #4669, #13214,
# #18312). MUST be registered bare (no `2>/dev/null || echo '{}'` wrapper) -- that wrapper
# converts exit 2 into exit 0 and silently disables the block; see root-files/settings.json's
# PreToolUse registration.
#
# Rationale: .claude/rules/no-task-references-in-deliverables.md -- deliverable files (code,
# docs, .claude/ context/standards/etc.) must not cite ephemeral task-management metadata like
# "task N" or "tasks N-M", since task numbers are renumbered during vault operations and are
# meaningless to a future reader with no access to (or interest in) the task tracker. Durable
# anchors (filenames, section headings, decision-record names) should be used instead. The
# Exemption Taxonomy (now in context/standards/task-reference-exemptions.md, the rule's lazy
# companion) documents every marker-exempted category (command-usage
# examples, quoted historical anti-patterns, test fixtures, memory frontmatter provenance, etc.)
# -- this hook consumes that taxonomy mechanically via strip_exempt_regions, never re-implementing
# exemption logic of its own.

set -euo pipefail

# ─── Shared pattern/exemption library ────────────────────────────────────────────────────────
# Sourced from the hook's own directory (siblings under .claude/: hooks/ and scripts/), so
# resolution is independent of the tool's cwd. Neither TASK_SEP, TASK_PATTERN, PHASE_PATTERN,
# nor exemption logic is defined here after this rewrite -- see
# context/standards/task-reference-exemptions.md's Exemption Taxonomy (companion to
# rules/no-task-references-in-deliverables.md) for the single source of
# truth both this hook and check-task-references.sh consume.
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$HOOK_DIR/../scripts/lib/task-reference-patterns.sh"
if [ ! -f "$LIB" ]; then
  echo "WARNING: validate-no-task-references.sh: shared library not found at $LIB -- failing open (not blocking)" >&2
  exit 0
fi
# shellcheck disable=SC1090
# Explicit fail-open on a sourcing failure (e.g. a syntax error in the library), not just a
# missing file -- honors this hook's own documented "fails OPEN if its own shared pattern
# library cannot be sourced" contract (see header) even under set -e, where an unguarded `.`
# failure would otherwise abort the whole hook rather than falling through to exit 0.
if ! . "$LIB"; then
  echo "WARNING: validate-no-task-references.sh: shared library at $LIB failed to source -- failing open (not blocking)" >&2
  exit 0
fi

# ─── Parse tool input from stdin (PreToolUse hook input), env-var fallback ───────────────────
# Mirrors guard-destructive-git.sh's stdin parsing pattern; the CLAUDE_TOOL_INPUT env fallback
# preserves the prior PostToolUse-era parsing shape for callers that still set it.

HOOK_SYSTEM_DEFECT_RECORD="$HOOK_DIR/../scripts/system-defect-record.sh"
CC_SESSION_ID=""
CWD=""
if [ -t 0 ]; then
  FILE=$(echo "$CLAUDE_TOOL_INPUT" 2>/dev/null | jq -r '.file_path // empty' 2>/dev/null) || true
  CONTENT=$(echo "$CLAUDE_TOOL_INPUT" 2>/dev/null | jq -r '.content // .new_string // empty' 2>/dev/null) || true
else
  INPUT=$(cat) || true
  FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || true
  CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null) || true
  if [ -z "$FILE" ]; then
    FILE=$(echo "$CLAUDE_TOOL_INPUT" 2>/dev/null | jq -r '.file_path // empty' 2>/dev/null) || true
    CONTENT=$(echo "$CLAUDE_TOOL_INPUT" 2>/dev/null | jq -r '.content // .new_string // empty' 2>/dev/null) || true
  fi
  CC_SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null) || CC_SESSION_ID=""
  CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null) || CWD=""
fi

# Non-file tools (no file_path resolved) -- exit silently, never block.
if [ -z "$FILE" ]; then
  exit 0
fi

# Exempt specs/** (task-management artifacts, Exemption Taxonomy category 1) and .memory/**
# (the memory vault's provenance fields, category 7): the rule's own path-level scope
# exclusions, via the shared library so both consumers agree byte-for-byte.
if is_exempt_path "$FILE"; then
  exit 0
fi

# No content captured (e.g. a Write/Edit variant this hook doesn't recognize) -- nothing to scan,
# never block.
if [ -z "$CONTENT" ]; then
  exit 0
fi

# Strip marker-exempted regions (Exemption Taxonomy categories 2-4, 6-7) before matching, exactly
# as check-task-references.sh does -- neither consumer implements exemption filtering itself.
SCANNABLE="$(printf '%s' "$CONTENT" | strip_exempt_regions)" || true

if printf '%s' "$SCANNABLE" | grep -qiE "$PHASE_PATTERN"; then
  echo "BLOCKED: $FILE appears to cite a task-qualified phase reference (e.g. 'task N phase P' or 'phase P of task N')." >&2
  echo "Per .claude/rules/no-task-references-in-deliverables.md, deliverable files outside specs/** must not cite" >&2
  echo "ephemeral task-management metadata -- task numbers (and phase references scoped to them) are renumbered" >&2
  echo "during vault operations and are meaningless to a future reader. Reference a durable anchor instead (a" >&2
  echo "sibling document's filename, a section heading, a decision-record name, or a verified fact) rather than" >&2
  echo "the task/phase number. If this citation is intentional (command-usage example, quoted historical" >&2
  echo "anti-pattern, test fixture, etc.), wrap it in a task-ref-ok marker per the Exemption Taxonomy." >&2
  bash "$HOOK_SYSTEM_DEFECT_RECORD" \
    --defect-class TASK_REFERENCE_IN_DELIVERABLE \
    --detecting-site "hooks/validate-no-task-references.sh:phase-pattern" \
    --message "task-qualified phase reference detected in $FILE" \
    --attributed-path "$FILE" \
    ${CC_SESSION_ID:+--cc-session-id "$CC_SESSION_ID"} \
    ${CWD:+--cwd "$CWD"} \
    >/dev/null 2>&1 || echo "Note: system-defect recording failed (non-fatal)" >&2
  exit 2
fi

if printf '%s' "$SCANNABLE" | grep -qiE "$TASK_PATTERN"; then
  echo "BLOCKED: $FILE appears to cite a task number (e.g. 'task N', 'tasks N-M', 'task-N', 'task_N', or 'Task #N')." >&2
  echo "Per .claude/rules/no-task-references-in-deliverables.md, deliverable files outside specs/** must not cite" >&2
  echo "ephemeral task-management metadata -- task numbers are renumbered during vault operations and are" >&2
  echo "meaningless to a future reader. Reference a durable anchor instead (a sibling document's filename, a" >&2
  echo "section heading, a decision-record name, or a verified fact) rather than the task number. If this" >&2
  echo "citation is intentional (command-usage example, quoted historical anti-pattern, test fixture, etc.)," >&2
  echo "wrap it in a task-ref-ok marker per the Exemption Taxonomy." >&2
  bash "$HOOK_SYSTEM_DEFECT_RECORD" \
    --defect-class TASK_REFERENCE_IN_DELIVERABLE \
    --detecting-site "hooks/validate-no-task-references.sh:task-pattern" \
    --message "task number citation detected in $FILE" \
    --attributed-path "$FILE" \
    ${CC_SESSION_ID:+--cc-session-id "$CC_SESSION_ID"} \
    ${CWD:+--cwd "$CWD"} \
    >/dev/null 2>&1 || echo "Note: system-defect recording failed (non-fatal)" >&2
  exit 2
fi

exit 0
