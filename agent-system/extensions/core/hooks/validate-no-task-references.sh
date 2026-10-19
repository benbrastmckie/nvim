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
# -- this hook consumes that taxonomy mechanically via the shared library, never re-implementing
# exemption logic of its own.
#
# Write vs. Edit resolution basis: a Write's `content` is already the complete, self-contained
# new file -- its exemption decision is made from that payload alone, and the on-disk file (the
# STALE pre-write state) is never consulted. An Edit's `new_string` is only a fragment, so a
# file-wide marker pair living outside the edited span is otherwise invisible to a payload-only
# scan; the Edit path below reconstructs the post-edit file (on-disk content with `old_string`
# spliced to `new_string`) and resolves exemption region-aware, over the inserted lines only,
# against that reconstruction. Any edit this reconstruction cannot trust (a new file, an
# absent/unmatched `old_string`, an ambiguous occurrence count, an unreadable target) degrades to
# exactly today's payload-only scan of `new_string` alone -- never a looser or stricter verdict
# than before this resolution existed.

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
# preserves the prior PostToolUse-era parsing shape for callers that still set it. TOOL_JSON ends
# up holding whichever source resolved a non-empty file_path -- the stdin envelope's own
# `.tool_input` object (nested shape) or CLAUDE_TOOL_INPUT itself (flat shape) -- and every field
# below (file_path, content, old_string, new_string, replace_all) is read from that one object,
# so the two parsing paths cannot drift on which source backs which field.

HOOK_SYSTEM_DEFECT_RECORD="$HOOK_DIR/../scripts/system-defect-record.sh"
CC_SESSION_ID=""
CWD=""
if [ -t 0 ]; then
  TOOL_JSON="${CLAUDE_TOOL_INPUT:-}"
else
  INPUT=$(cat) || true
  TOOL_JSON="$(echo "$INPUT" 2>/dev/null | jq -c '.tool_input // {}' 2>/dev/null)" || TOOL_JSON="{}"
  FILE_CHECK=$(echo "$TOOL_JSON" 2>/dev/null | jq -r '.file_path // empty' 2>/dev/null) || true
  if [ -z "$FILE_CHECK" ]; then
    TOOL_JSON="${CLAUDE_TOOL_INPUT:-}"
  fi
  CC_SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null) || CC_SESSION_ID=""
  CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null) || CWD=""
fi

FILE=$(echo "$TOOL_JSON" 2>/dev/null | jq -r '.file_path // empty' 2>/dev/null) || true

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

# ─── Shared pattern-match + block helper (used by both the Write and Edit paths below) ─────────
# scan_and_block <scannable-content>
#
# Runs the two pattern checks (PHASE_PATTERN, then TASK_PATTERN, preserving that order) against
# the given already-exemption-resolved content, and exits 2 with the existing stderr guidance and
# system-defect-record call on a match. Returns normally (never exits) when neither pattern
# matches, so the caller proceeds to its own exit 0.
scan_and_block() {
  local scannable="$1"

  if printf '%s' "$scannable" | grep -qiE "$PHASE_PATTERN"; then
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

  if printf '%s' "$scannable" | grep -qiE "$TASK_PATTERN"; then
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
}

# ─── Tool-path discrimination: by field presence, never by tool_name ──────────────────────────
# The existing suites' synthetic payloads carry only tool_input (no tool_name at all), and the
# CLAUDE_TOOL_INPUT env fallback carries no tool name either -- a tool_name dependency would
# silently change which path the tests exercise. `content` present means Write; `old_string` or
# `new_string` present means Edit. Neither present (some other Write/Edit variant, or a
# degenerate fixture) falls through the Write branch, where an empty CONTENT exits 0 exactly as
# before this phase existed.
HAS_CONTENT=$(echo "$TOOL_JSON" 2>/dev/null | jq -r 'has("content")' 2>/dev/null) || HAS_CONTENT="false"
HAS_OLD=$(echo "$TOOL_JSON" 2>/dev/null | jq -r 'has("old_string")' 2>/dev/null) || HAS_OLD="false"
HAS_NEW=$(echo "$TOOL_JSON" 2>/dev/null | jq -r 'has("new_string")' 2>/dev/null) || HAS_NEW="false"

if [ "$HAS_CONTENT" != "true" ] && { [ "$HAS_OLD" = "true" ] || [ "$HAS_NEW" = "true" ]; }; then
  TOOL_MODE="edit"
else
  TOOL_MODE="write"
fi

if [ "$TOOL_MODE" = "write" ]; then
  # ─── Write path: UNCHANGED. CONTENT comes only from this call's own complete new content; the
  # on-disk file (the stale pre-write state) is never read here -- it would be the wrong basis
  # for a Write's exemption decision entirely. ──────────────────────────────────────────────────
  CONTENT=$(echo "$TOOL_JSON" 2>/dev/null | jq -r '.content // .new_string // empty' 2>/dev/null) || true

  # No content captured (e.g. a Write/Edit variant this hook doesn't recognize) -- nothing to
  # scan, never block.
  if [ -z "$CONTENT" ]; then
    exit 0
  fi

  # Strip marker-exempted regions (Exemption Taxonomy categories 2-4, 6-7) before matching,
  # exactly as check-task-references.sh does -- neither consumer implements exemption filtering
  # itself.
  SCANNABLE="$(printf '%s' "$CONTENT" | strip_exempt_regions)" || true
  scan_and_block "$SCANNABLE"
  exit 0
fi

# ─── Edit path: region-aware resolution over the reconstructed post-edit file ──────────────────
NEW_STRING=$(echo "$TOOL_JSON" 2>/dev/null | jq -r '.new_string // empty' 2>/dev/null) || true
OLD_STRING=$(echo "$TOOL_JSON" 2>/dev/null | jq -r '.old_string // empty' 2>/dev/null) || true
REPLACE_ALL=$(echo "$TOOL_JSON" 2>/dev/null | jq -r '.replace_all // false' 2>/dev/null) || REPLACE_ALL="false"

# Nothing inserted -- nothing to scan, never block (mirrors the Write path's empty-CONTENT exit).
if [ -z "$NEW_STRING" ]; then
  exit 0
fi

# degrade_edit: fall back to exactly today's payload-only behavior -- scan new_string alone,
# stripped of its own markers. Used whenever the post-edit reconstruction cannot be trusted.
degrade_edit() {
  local scannable
  scannable="$(printf '%s' "$NEW_STRING" | strip_exempt_regions)" || true
  scan_and_block "$scannable"
  exit 0
}

# No old_string to locate on disk -- nothing to reconstruct against. Degrade immediately,
# without attempting a disk read at all.
if [ -z "$OLD_STRING" ]; then
  degrade_edit
fi

# Attempt the disk read. A new file, a race, or a permissions failure all degrade silently --
# no error, no warning noise, exactly today's verdict for this edit.
if ! ON_DISK="$(cat "$FILE" 2>/dev/null)"; then
  degrade_edit
fi

# count_occurrences <haystack> <needle>: a literal (non-regex), non-overlapping occurrence count
# via bash parameter expansion -- never sed, never a regex, so no needle metacharacter can alter
# the count's meaning.
count_occurrences() {
  local haystack="$1" needle="$2" count=0 rest
  if [ -z "$needle" ]; then
    printf '%s' 0
    return
  fi
  rest="$haystack"
  while :; do
    case "$rest" in
      *"$needle"*)
        count=$((count + 1))
        rest="${rest#*"$needle"}"
        ;;
      *)
        break
        ;;
    esac
  done
  printf '%s' "$count"
}

OCC_COUNT="$(count_occurrences "$ON_DISK" "$OLD_STRING")"

# Occurrence-count guard: zero occurrences, or more than one with replace_all false, is a merge
# failure -- degrade. Never a looser or stricter verdict than today's.
if [ "$OCC_COUNT" -eq 0 ]; then
  degrade_edit
fi
if [ "$OCC_COUNT" -gt 1 ] && [ "$REPLACE_ALL" != "true" ]; then
  degrade_edit
fi

NUM_REPL=1
if [ "$REPLACE_ALL" = "true" ] && [ "$OCC_COUNT" -gt 1 ]; then
  NUM_REPL="$OCC_COUNT"
fi

# nlcount <string>: the literal newline-BYTE count (never a full "line count" of a possibly
# unterminated final line) -- exactly the unit the 1-based inserted-range formula below uses.
nlcount() {
  printf '%s' "$1" | tr -cd '\n' | wc -c | tr -d '[:space:]'
}

# Splice old_string -> new_string literally via bash parameter expansion with a quoted pattern
# (never sed, never a regex), recording each insertion's 1-based line range in the merged
# content as we go: start = (newline count of the merged content so far) + 1, end = start +
# (newline count of new_string).
MERGED=""
REMAINING="$ON_DISK"
RANGE_STARTS=()
RANGE_ENDS=()
i=0
while [ "$i" -lt "$NUM_REPL" ]; do
  PREFIX="${REMAINING%%"$OLD_STRING"*}"
  SUFFIX="${REMAINING#*"$OLD_STRING"}"
  MERGED_SO_FAR="${MERGED}${PREFIX}"
  RANGE_START=$(( $(nlcount "$MERGED_SO_FAR") + 1 ))
  RANGE_END=$(( RANGE_START + $(nlcount "$NEW_STRING") ))
  RANGE_STARTS+=("$RANGE_START")
  RANGE_ENDS+=("$RANGE_END")
  MERGED="${MERGED_SO_FAR}${NEW_STRING}"
  REMAINING="$SUFFIX"
  i=$((i + 1))
done
MERGED="${MERGED}${REMAINING}"

# Run exempt_line_mask over the merged content (process substitution, not a <<< here-string --
# a here-string appends an extra trailing newline, which would desynchronize this mask array
# from the line array below by one entry whenever MERGED already ends in a newline).
mapfile -t MASK_ARR < <(printf '%s' "$MERGED" | exempt_line_mask)
mapfile -t MERGED_LINES < <(printf '%s' "$MERGED")

# The edit is exempt iff every line in every recorded inserted range is masked exempt; if so,
# exit 0 without pattern-matching those lines at all -- a covered-but-literally-matching line is
# the entire point of a marker. Otherwise collect only the non-exempt lines of the inserted
# ranges for scanning -- never the rest of the file.
ALL_EXEMPT=1
NONEXEMPT=""
for idx in "${!RANGE_STARTS[@]}"; do
  RANGE_START="${RANGE_STARTS[$idx]}"
  RANGE_END="${RANGE_ENDS[$idx]}"
  L="$RANGE_START"
  while [ "$L" -le "$RANGE_END" ]; do
    MASK_VAL="${MASK_ARR[$((L - 1))]:-0}"
    if [ "$MASK_VAL" != "1" ]; then
      ALL_EXEMPT=0
      NONEXEMPT="${NONEXEMPT}${MERGED_LINES[$((L - 1))]:-}"$'\n'
    fi
    L=$((L + 1))
  done
done

if [ "$ALL_EXEMPT" -eq 1 ]; then
  exit 0
fi

scan_and_block "$NONEXEMPT"
exit 0
