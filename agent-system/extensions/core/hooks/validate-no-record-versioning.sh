#!/usr/bin/env bash
# PreToolUse hook: BLOCKS record-versioning language in authored deliverables via exit code 2.
# Triggers on Write/Edit to any path outside specs/** (task-management artifacts are exempt --
# record-version language is expected there, per rules/no-record-versioning-in-deliverables.md).
# Blocking: denies the write via exit 2 + stderr message when a BLOCKING-tier finding is
# detected; exits 0 (silent) otherwise, and fails OPEN (exit 0, with a WARNING on stderr) if its
# own shared pattern library is missing OR fails to source -- a broken guard must never block
# every write in the repo.
#
# Modeled on hooks/validate-no-task-references.sh, whose header records three non-obvious
# contracts this hook inherits verbatim:
#   - BLOCK VIA EXIT CODE 2 + a stderr message, NOT via `permissionDecision: deny`, which is
#     documented-buggy for allow-listed Write/Edit tool calls (settings.json carries bare
#     "Write"/"Edit" permissions.allow entries; upstream issues #4669, #13214, #18312).
#   - FAIL OPEN (exit 0, with a WARNING on stderr) if the shared library is missing OR fails to
#     source. Both cases are guarded explicitly below, because under `set -e` an unguarded `.`
#     failure would abort before reaching the fallthrough. This fail-open polarity is the
#     deliberate OPPOSITE of the repo-wide lint's (check-record-versioning.sh) fail-CLOSED
#     polarity on the same defect class: a batch lint run by a human/CI can afford to halt loudly
#     on a stale dependency, but a write-time guard that blocked every single write in the repo
#     over its own broken dependency would be a far costlier failure mode than letting a write
#     through unchecked for one cycle.
#   - Resolve the library relative to the hook's own directory via BASH_SOURCE, so resolution is
#     independent of the tool's cwd.
#
# Rationale: .claude/rules/no-record-versioning-in-deliverables.md -- deliverable files (code,
# docs, .claude/ context/standards/etc.) must state the current design only and must not narrate
# their own draft history (a page-level version label in a heading or Status line, a
# supersession/migration claim tying the current page to an earlier numbered draft, a
# disposition table attributing a rejected alternative to an earlier draft, etc.). The
# Exemption Taxonomy
# (context/standards/record-version-exemptions.md, the rule's lazy companion) documents every
# durable-axis exemption (toolchain/software pins, file-format/schema versions, CI cache-key
# epoch segments, the dated cross-document amendment note) and the `version-ok` marker
# convention -- this hook consumes that taxonomy mechanically via the shared library, never
# re-implementing any pattern, axis-discrimination rule, or tier of its own.
#
# ADVISORY TIER AT WRITE TIME -- DELIBERATELY SILENT. A hook has only two outcomes (block or
# allow); the taxonomy's ADVISORY tier has no direct write-time expression. This hook calls
# `rv_grep_blocking` ONLY and NEVER calls `rv_grep_advisory`, and emits no advisory note either.
# Measured against the live corpus with the deployed lint: this repository carries 809 ADVISORY
# findings outside specs/** at the time this hook was written. A hook that printed an advisory
# note on every matching Write would fire across a large fraction of all prose writes in this
# repository and would train every reader to ignore it. Advisory surfacing is left entirely to
# the repo-wide lint (check-record-versioning.sh), which reports (but never blocks on) ADVISORY
# findings. This posture must stay consistent with
# context/standards/record-version-exemptions.md's Enforcement section; if that posture ever
# changes, both documents must be updated together.
#
# EDIT-PATH SCOPE -- PAYLOAD-ONLY, NOT REGION-AWARE. Unlike the task-reference sibling hook,
# this hook does NOT reconstruct the post-edit on-disk file to resolve a `version-ok` marker pair
# that lives outside the edited span. `strip_exempt_regions` in the shared library is a flat
# `in_block` toggle with no nesting concept, and no acceptance criterion for this hook exercises
# disk reconstruction. An Edit's `new_string` is scanned exactly as a Write's `content` is --
# stripped of durable-axis lines and marker-exempted lines WITHIN the payload itself, never
# consulting the on-disk file. KNOWN, ACCEPTED BLIND SPOT: an edit landing inside a file-wide
# `version-ok:begin`/`version-ok:end` region whose markers sit outside the edited span will be
# scanned (and may be blocked) as if unmarked, because the markers are invisible to a
# payload-only scan. The author's immediate escape hatch is the INLINE `version-ok` marker on the
# edited line itself (or restating the edit as a Write of the whole file). A real observed
# instance of this blind spot causing a false block is separate future scope, not silently
# absorbed here.

set -euo pipefail

# ─── Shared pattern/exemption library ────────────────────────────────────────────────────────
# Sourced from the hook's own directory (siblings under .claude/: hooks/ and scripts/), so
# resolution is independent of the tool's cwd. No pattern, axis-discrimination rule, or tier is
# defined here -- see scripts/lib/record-version-patterns.sh and
# context/standards/record-version-exemptions.md's Exemption Taxonomy (companion to
# rules/no-record-versioning-in-deliverables.md) for the single source of truth both this hook
# and check-record-versioning.sh consume.
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$HOOK_DIR/../scripts/lib/record-version-patterns.sh"
if [ ! -f "$LIB" ]; then
  echo "WARNING: validate-no-record-versioning.sh: shared library not found at $LIB -- failing open (not blocking)" >&2
  exit 0
fi
# shellcheck disable=SC1090
# Explicit fail-open on a sourcing failure (e.g. a syntax error in the library), not just a
# missing file -- honors this hook's own documented "fails OPEN if its own shared pattern
# library cannot be sourced" contract (see header) even under set -e, where an unguarded `.`
# failure would otherwise abort the whole hook rather than falling through to exit 0.
if ! . "$LIB"; then
  echo "WARNING: validate-no-record-versioning.sh: shared library at $LIB failed to source -- failing open (not blocking)" >&2
  exit 0
fi

# A library found and sourced cleanly but missing an expected function is a stale/incompatible
# library (predates the two-tier is_exempt_path/strip_durable_axis_lines/strip_exempt_regions/
# rv_grep_blocking/rv_grep_advisory API) -- fail OPEN here too, with the same WARNING shape,
# rather than letting an undefined-function call abort under set -e or silently produce a false
# verdict.
for required_fn in is_exempt_path strip_durable_axis_lines strip_exempt_regions \
                   rv_grep_blocking rv_grep_advisory; do
  if ! declare -F "$required_fn" >/dev/null 2>&1; then
    echo "WARNING: validate-no-record-versioning.sh: shared library at $LIB is missing required function '$required_fn' -- stale or incompatible version -- failing open (not blocking)" >&2
    exit 0
  fi
done

# ─── Parse tool input from stdin (PreToolUse hook input), env-var fallback ───────────────────
# Mirrors validate-no-task-references.sh's stdin parsing pattern; the CLAUDE_TOOL_INPUT env
# fallback preserves the prior PostToolUse-era parsing shape for callers that still set it. No
# session-id/cwd capture here (unlike the sibling hook) -- this hook makes no
# system-defect-record.sh call, see the DEVIATION comment below for why.
if [ -t 0 ]; then
  TOOL_JSON="${CLAUDE_TOOL_INPUT:-}"
else
  INPUT=$(cat) || true
  TOOL_JSON="$(echo "$INPUT" 2>/dev/null | jq -c '.tool_input // {}' 2>/dev/null)" || TOOL_JSON="{}"
  FILE_CHECK=$(echo "$TOOL_JSON" 2>/dev/null | jq -r '.file_path // empty' 2>/dev/null) || true
  if [ -z "$FILE_CHECK" ]; then
    TOOL_JSON="${CLAUDE_TOOL_INPUT:-}"
  fi
fi

FILE=$(echo "$TOOL_JSON" 2>/dev/null | jq -r '.file_path // empty' 2>/dev/null) || true

# Non-file tools (no file_path resolved) -- exit silently, never block.
if [ -z "$FILE" ]; then
  exit 0
fi

# Exempt specs/** (task-management artifacts, Exemption Taxonomy zone 1) -- the rule's own
# path-level scope exclusion, via the shared library so every consumer agrees byte-for-byte.
if is_exempt_path "$FILE"; then
  exit 0
fi

# ─── Tool-path discrimination: by field presence, never by tool_name ──────────────────────────
# `content` present means Write; `old_string` or `new_string` present (without `content`) means
# Edit. Neither present falls through the Write branch, where an empty CONTENT exits 0 exactly
# as before.
HAS_CONTENT=$(echo "$TOOL_JSON" 2>/dev/null | jq -r 'has("content")' 2>/dev/null) || HAS_CONTENT="false"
HAS_OLD=$(echo "$TOOL_JSON" 2>/dev/null | jq -r 'has("old_string")' 2>/dev/null) || HAS_OLD="false"
HAS_NEW=$(echo "$TOOL_JSON" 2>/dev/null | jq -r 'has("new_string")' 2>/dev/null) || HAS_NEW="false"

if [ "$HAS_CONTENT" != "true" ] && { [ "$HAS_OLD" = "true" ] || [ "$HAS_NEW" = "true" ]; }; then
  CONTENT=$(echo "$TOOL_JSON" 2>/dev/null | jq -r '.new_string // empty' 2>/dev/null) || true
else
  CONTENT=$(echo "$TOOL_JSON" 2>/dev/null | jq -r '.content // empty' 2>/dev/null) || true
fi

# No content captured -- nothing to scan, never block.
if [ -z "$CONTENT" ]; then
  exit 0
fi

# ─── Scan: strip_durable_axis_lines, then strip_exempt_regions, then rv_grep_blocking ONLY ─────
# Never calls rv_grep_advisory -- see the header's "ADVISORY TIER AT WRITE TIME" note. The
# pipeline order matters: a durable-axis line (a toolchain pin, a schema filename, a CI
# cache-key segment) must be blanked BEFORE the blocking patterns ever see it, or an ordinary
# docs/ write citing one of those axes would be falsely blocked.
SCANNABLE="$(printf '%s' "$CONTENT" | strip_durable_axis_lines | strip_exempt_regions)" || true

if FINDING="$(printf '%s' "$SCANNABLE" | rv_grep_blocking "$FILE" 2>/dev/null)" && [ -n "$FINDING" ]; then
  echo "BLOCKED: $FILE appears to introduce record-versioning language (a page-level version" >&2
  echo "label, a version-qualified supersession/migration claim, or a '(v1 Decision N)'" >&2
  echo "attribution)." >&2
  echo "Per .claude/rules/no-record-versioning-in-deliverables.md, deliverable files outside" >&2
  echo "specs/** must state the current design only and must not narrate their own draft" >&2
  echo "history. Reference a durable anchor instead (a filename, a section heading, a" >&2
  echo "decision-record name, or a verified fact) rather than a version label or supersession" >&2
  echo "claim. If this is a durable axis (a toolchain/software pin, a file-format/schema" >&2
  echo "version, or a CI cache-key epoch segment) that was not recognized as such, or this" >&2
  echo "citation is otherwise intentional (a quoted historical anti-pattern, a test fixture," >&2
  echo "etc.), wrap it in a version-ok / version-ok:begin / version-ok:end marker per the" >&2
  echo "Exemption Taxonomy (context/standards/record-version-exemptions.md)." >&2
  # DEVIATION from the sibling hook's shape: no system-defect-record.sh call here. The closed
  # Signal A vocabulary (context/patterns/system-defect-discrimination.md) has no instance for
  # "record-versioning language in a deliverable" -- the closest neighbor
  # (TASK_REFERENCE_IN_DELIVERABLE) names a different violation. That document states its own
  # extension policy explicitly: "a closed, extensible list -- extending it is a future task's
  # decision, not silently done by a detection site." Silently passing an invalid --defect-class
  # here would make this non-fatal call fail on every single block, every time, which is worse
  # than simply not calling it. Extending the enum is left to separate, dedicated work.
  exit 2
fi

exit 0
