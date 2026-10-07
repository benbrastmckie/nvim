#!/usr/bin/env bash
# PreToolUse hook: BLOCKS a Write or Edit that alters or deletes a line already present in a
# books/book-convention-evidence/NN-*.md file, via exit code 2. Permits a pure append, creation
# of a new NN-*.md, README.md (the directory's migration-contract document, excluded exactly as
# the companion gate excludes it), and every out-of-scope path -- the hook is inert wherever the
# books/book-convention-evidence/ directory does not exist.
#
# Companion gate: books/scripts/check-evidence-append-only.sh is the commit-time check over
# BASE..HEAD plus the working tree. Its committed-deletions count SUMS deletions PER COMMIT and
# is therefore MONOTONIC: a later commit that restores a deleted line does not clear the count,
# it ADDS to it, so the only remedy for a COMMITTED finding is a history rewrite of the offending
# commit(s). This hook is the complementary PREVENTION leg: it stops the uncommitted case --
# cheaply remediable by definition -- from ever becoming a committed one.
#
# Blocks via exit code 2 + stderr, never `permissionDecision: deny` -- documented-buggy for
# allow-listed Write/Edit tool calls (see settings.json's permissions.allow bare "Write"/"Edit"
# entries and GH issues #4669, #13214, #18312). Modeled on
# core/hooks/validate-no-task-references.sh.
#
# MUST be registered bare (no `2>/dev/null || echo '{}'` wrapper). That wrapper converts exit 2
# into exit 0 and silently disables the block -- see email/settings-fragment.json for the
# precedent this hook deliberately does NOT follow.
#
# Fails OPEN (exit 0 + stderr WARNING) on two separately guarded internal-error classes, since
# this hook sources no shared library and has exactly one real dependency:
#   1. presence  -- `jq` is not on PATH.
#   2. usability -- `jq` is present but the captured stdin does not parse as JSON.
# A broken guard must never block every write in the repo.
#
# Ruling 2 (trailing-uncommitted-entry): only lines present in `git show HEAD:<path>` (the
# FLOOR) are immutable; the uncommitted tail of the same file (DISK minus the FLOOR prefix) may
# be edited freely -- including a genuine in-place correction within that tail, not merely an
# append -- because that is exactly the boundary the companion gate can and cannot punish: an
# uncommitted deletion is cheaply remediable and never needs a history rewrite. For Edit, this is
# two independent allow patterns: (a) old_string is a suffix of the CURRENT on-disk content and
# new_string begins with old_string (a pure append, from either the floor or an existing tail);
# or (b) old_string is a suffix of the TAIL alone (a free edit confined entirely to the
# uncommitted region, which by construction can never reach back into the floor). Fallback: when
# the HEAD lookup cannot produce a version (no git checkout, new file, shallow/detached state),
# the floor and the on-disk content collapse to the same value and the tail is empty -- a
# strictly STRICTER prefix test, and NOT the fail-open case above; the two must not be conflated.
#
# The predicate is deliberately byte-string tests only (prefix/suffix), never line-oriented
# (`diff`, newline-splitting, per-line arrays): the measured incident this hook exists to prevent
# was a single-character substitution buried inside a single ~7800-character line, a shape a
# line-oriented implementation could pass every other fixture case while missing entirely.
#
# Scope: paths matching books/book-convention-evidence/NN-*.md (NN = exactly two digits).
# README.md is excluded. Both absolute and repo-relative file_path are handled via the
# PreToolUse payload's own `cwd` field. A non-matching path, or a repository lacking the
# directory entirely, exits 0 silently.
#
# Known limitations (recorded, not fixed here):
#   (a) The deploying repo's verify-deploy.sh registration gate checks only three hardcoded
#       core event:script pairs, so this registration is NOT regression-protected by tooling. A
#       generic "every provides.hooks entry is registered somewhere" check is a separate concern.
#   (b) The harness's own PreToolUse dispatch of this hook can only be observed from an
#       interactive session whose project directory is the deploying repo -- verification instead
#       drives the deployed copy directly with a constructed payload. Reproduction recipe for an
#       operator who wants the end-to-end observation: open a session in the deploying repo and
#       attempt an in-place Edit of a line already committed in a books/book-convention-evidence/
#       NN-*.md file.

set -euo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROG="$(basename "${BASH_SOURCE[0]}")"

# ─── Fail-open guard 1: dependency presence ──────────────────────────────────────────────────
if ! command -v jq >/dev/null 2>&1; then
  echo "WARNING: ${PROG} (${HOOK_DIR}/${PROG}): jq not found on PATH -- failing open (not blocking)" >&2
  exit 0
fi

# ─── Read the PreToolUse JSON payload from stdin ─────────────────────────────────────────────
# A real hook invocation is always piped; a bare interactive invocation with no redirection has
# no payload to inspect, so exit silently rather than block on `cat` waiting for stdin.
if [ -t 0 ]; then
  exit 0
fi
INPUT="$(cat)" || true

# ─── Fail-open guard 2: payload usability (separate from guard 1, per inherited contract) ────
if ! printf '%s' "$INPUT" | jq -e . >/dev/null 2>&1; then
  echo "WARNING: ${PROG}: guard 2 (payload usability) -- stdin did not parse as JSON -- failing open (not blocking)" >&2
  exit 0
fi

TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)" || TOOL_NAME=""
CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)" || CWD=""
FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)" || FILE=""
CONTENT="$(printf '%s' "$INPUT" | jq -r '.tool_input.content // empty' 2>/dev/null)" || CONTENT=""
OLD_STRING="$(printf '%s' "$INPUT" | jq -r '.tool_input.old_string // empty' 2>/dev/null)" || OLD_STRING=""
NEW_STRING="$(printf '%s' "$INPUT" | jq -r '.tool_input.new_string // empty' 2>/dev/null)" || NEW_STRING=""

# ─── Early exits (inherited contract, verbatim) ──────────────────────────────────────────────
if [ -z "$FILE" ]; then
  exit 0
fi
if [ -z "$CONTENT" ] && [ -z "$OLD_STRING" ] && [ -z "$NEW_STRING" ]; then
  exit 0
fi

# ─── Resolve the absolute path, independent of the hook's own cwd ───────────────────────────
if [ -z "$CWD" ]; then
  CWD="$PWD"
fi
case "$FILE" in
  /*) ABS_FILE="$FILE" ;;
  *) ABS_FILE="${CWD%/}/$FILE" ;;
esac
if command -v realpath >/dev/null 2>&1; then
  if NORM_FILE="$(realpath -m "$ABS_FILE" 2>/dev/null)"; then
    ABS_FILE="$NORM_FILE"
  fi
fi

# ─── Scope match, performed before any subprocess ────────────────────────────────────────────
BASENAME="$(basename "$ABS_FILE")"
if [ "$BASENAME" = "README.md" ]; then
  exit 0
fi
case "$ABS_FILE" in
  */books/book-convention-evidence/[0-9][0-9]-*.md) : ;;
  *) exit 0 ;;
esac

# ─── Creation of a new NN-*.md is always allowed ─────────────────────────────────────────────
if [ ! -e "$ABS_FILE" ]; then
  exit 0
fi

# ─── Compute the immutable floor, the current disk content, and the mutable tail (Ruling 2) ──
REPO_ROOT=""
if REPO_ROOT="$(git -C "$(dirname "$ABS_FILE")" rev-parse --show-toplevel 2>/dev/null)"; then
  :
else
  REPO_ROOT=""
fi

FLOOR=""
DISK=""
HAVE_HEAD=0
RELPATH=""
if [ -n "$REPO_ROOT" ]; then
  case "$ABS_FILE" in
    "$REPO_ROOT"/*) RELPATH="${ABS_FILE#"$REPO_ROOT"/}" ;;
    *) RELPATH="" ;;
  esac
fi
if [ -n "$RELPATH" ] && FLOOR="$(git -C "$REPO_ROOT" show "HEAD:$RELPATH" 2>/dev/null)"; then
  HAVE_HEAD=1
  DISK="$(cat "$ABS_FILE" 2>/dev/null)" || DISK=""
else
  # Fallback: not a checkout at HEAD for this path (no git, new file not yet committed, shallow
  # or detached state). Floor and disk collapse to the same value -- strictly STRICTER on-disk
  # prefix test, NOT the fail-open case above.
  FLOOR="$(cat "$ABS_FILE" 2>/dev/null)" || FLOOR=""
  DISK="$FLOOR"
fi

TAIL=""
if [ "$HAVE_HEAD" -eq 1 ] && [[ "$DISK" == "$FLOOR"* ]]; then
  TAIL="${DISK:${#FLOOR}}"
fi

# ─── The predicate: byte-string tests only, no line splitting ───────────────────────────────
case "$TOOL_NAME" in
  Write)
    # The floor must survive as a byte-exact prefix of the new content; anything after it --
    # the old tail, a corrected tail, or nothing at all -- is free (Ruling 2).
    if [[ "$CONTENT" == "$FLOOR"* ]]; then
      exit 0
    fi
    ;;
  Edit)
    # Conservative on purpose: needs no simulation of Edit semantics and no reasoning about
    # replace_all uniqueness.
    if [ -n "$OLD_STRING" ]; then
      # Pattern (a): a pure append relative to the CURRENT on-disk content -- old_string is its
      # suffix and new_string begins with old_string, so the floor (and any existing tail) is
      # preserved byte-for-byte and only trailing content is added.
      if [[ "$DISK" == *"$OLD_STRING" ]] && [[ "$NEW_STRING" == "$OLD_STRING"* ]]; then
        exit 0
      fi
      # Pattern (b): a free edit confined entirely to the uncommitted tail -- old_string is a
      # suffix of TAIL alone, which by construction (TAIL's length never exceeds DISK minus
      # FLOOR) cannot reach back into the floor, so new_string may be anything.
      if [ -n "$TAIL" ] && [[ "$TAIL" == *"$OLD_STRING" ]]; then
        exit 0
      fi
    fi
    ;;
  *)
    exit 0
    ;;
esac

# ─── Refusal: all three required facts, inline ───────────────────────────────────────────────
echo "BLOCKED: ${ABS_FILE} is an append-only book-convention-evidence file." >&2
echo "Per books/scripts/check-evidence-append-only.sh (the companion commit-time gate), its" >&2
echo "deleted-line counter SUMS deletions PER COMMIT and is therefore MONOTONIC: a later commit" >&2
echo "that restores this line does not clear a committed deletion, it ADDS to the count -- the" >&2
echo "only remedy for a committed finding is a history rewrite of the offending commit(s)." >&2
echo "Append a new, dated entry instead of modifying or deleting an existing line." >&2
exit 2
