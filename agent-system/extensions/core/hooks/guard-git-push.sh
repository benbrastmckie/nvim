#!/usr/bin/env bash
# guard-git-push.sh
# PreToolUse hook, registered on matcher "Bash|Write|Edit", with TWO responsibilities that
# share one file because both derive their path constants from push-grant-lib.sh and both exist
# to protect the same security property (a grant can only ever come from the tamper-resistant
# mint path in hooks/please-grant.sh):
#
#   A. Bash: block every un-granted `git push` (any form), and allow exactly the one push a
#      live, verifying, fresh, target-matching grant authorizes -- consuming that grant.
#   B. Write/Edit (and a Bash command whose argv or redirection targets the grant store or the
#      key path): block UNCONDITIONALLY. No grant, no snapshot, no override exempts a write to
#      the grant store -- this is the model's write channel into the one thing that must stay
#      tamper-resistant. Wiring any new write-capable tool (a future MCP filesystem server, for
#      example) requires revisiting this matcher list; it is not closed by construction.
#
# Blocks via exit code 2 + stderr (NOT permissionDecision: deny, which is documented-buggy for
# allow-listed Bash(git:*) commands -- GH issues #4669, #13214, #18312, exactly as
# guard-destructive-git.sh's own header already documents for the same reason).
#
# Argv-anchoring: reuses guard-destructive-git.sh's COMMAND_SCAN technique (quote-strip via
# `sed -z`, then comment-strip) VERBATIM rather than inventing a second scheme, and inherits its
# documented blind spot symmetrically: a QUOTED directory/glob-shaped token is invisible to this
# scan exactly as it is there. See that file's header for the full rationale.
#
# Argv parsing for `git push` is deliberately NOT a full git CLI parser -- it recognises the
# common forms (bare, explicit remote/refspec, -u/--set-upstream, --force, -f, --force-with-lease
# [=<ref>], --mirror, --all, --tags, --prune, --delete/-d, a `src:dst` or `:dst` refspec, `HEAD`)
# and resolves an omitted remote/refspec the way bare `git push` itself does (the current
# branch's configured upstream, else `origin` + current branch). An argv form outside this list
# is treated as UNRESOLVED, which -- per the fail-closed direction -- falls through to "no
# matching grant" rather than being silently allowed.

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="${HOOK_DIR}/../scripts/lib/push-grant-lib.sh"

INPUT="$(cat 2>/dev/null)" || INPUT=""
TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)" || TOOL_NAME=""
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)" || COMMAND=""
FILE_PATH="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)" || FILE_PATH=""

[ -r "$LIB" ] || exit 0
# shellcheck source=../scripts/lib/push-grant-lib.sh
source "$LIB" || exit 0

GRANT_DIR_PREFIX="$(pg_grant_dir)"
KEY_PATH_LITERAL="$(pg_key_path)"

# --- Responsibility B: tamper guard on the grant store and the key path --------------------
# Write/Edit targeting the grant directory or the key path -- exit 2 unconditionally, no
# exemption of any kind.
if [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "Edit" ]; then
  if [ -n "$FILE_PATH" ]; then
    case "$FILE_PATH" in
      "${GRANT_DIR_PREFIX}"/*|"${GRANT_DIR_PREFIX}"|"$KEY_PATH_LITERAL")
        echo "BLOCKED: ${TOOL_NAME} to the push-grant store ('$FILE_PATH') is never permitted." >&2
        echo "The grant store's tamper-resistance depends on the model having no write channel" >&2
        echo "into it. This path is reachable only through hooks/please-grant.sh (the mint" >&2
        echo "hook) and the grant-consuming guards -- never through a direct Write/Edit." >&2
        exit 2
        ;;
    esac
  fi
  exit 0
fi

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Same quote-strip (sed -z, slurp mode) then comment-strip (line mode) as
# guard-destructive-git.sh -- see that file's header for the full rationale; not re-derived here.
COMMAND_SCAN=$(printf '%s' "$COMMAND" \
  | sed -z -e 's/"[^"]*"/""/g' -e "s/'[^']*'/''/g" \
  | sed -e 's/\(^\|[[:space:]]\)#.*$//')

# A Bash command whose scanned text targets the grant dir or the key path (redirection,
# rm/mv/cp/chmod targeting either, etc.) -- exit 2 unconditionally, same as the Write/Edit case.
# This is a coarse substring check by design (any mention of either path in a Bash command that
# is not itself a sanctioned consumer is refused) -- sanctioned consumers never reach this file
# at all (they are scripts invoked BY name, not by writing into the grant store's bytes).
if printf '%s' "$COMMAND_SCAN" | grep -qF "$GRANT_DIR_PREFIX" || printf '%s' "$COMMAND_SCAN" | grep -qF "$KEY_PATH_LITERAL"; then
  echo "BLOCKED: this Bash command references the push-grant store or its key path" >&2
  echo "('${GRANT_DIR_PREFIX}' / '${KEY_PATH_LITERAL}'). Direct access to either is never" >&2
  echo "permitted from an agent -- the grant store's tamper-resistance depends on the model" >&2
  echo "having no write (or read-for-the-key) channel into it." >&2
  exit 2
fi

# --- Responsibility A: the push guard itself -------------------------------------------------

PUSH_SEGMENTS=$(echo "$COMMAND_SCAN" | grep -oE '(^|[;&|][[:space:]]*)git[[:space:]]+push[^;&|]*') || true
[ -n "$PUSH_SEGMENTS" ] || exit 0

# Only the FIRST matching segment is evaluated -- a command chaining more than one `git push`
# invocation is vanishingly rare and, if it occurs, the second segment is re-scanned on its own
# next invocation; this hook never needs to reason about two pushes in one command string.
SEG="$(printf '%s\n' "$PUSH_SEGMENTS" | head -n1)"
SEG_REST="$(printf '%s' "$SEG" | sed -E 's/^[;&|]*[[:space:]]*git[[:space:]]+push[[:space:]]*//')"

read -ra TOKENS <<< "$SEG_REST" || true

FORCE="0"
IS_MIRROR=0
IS_ALL=0
IS_TAGS_FLAG=0
IS_PRUNE=0
IS_DELETE_FLAG=0
REMOTE_ARG=""
REFSPECS=()

for tok in "${TOKENS[@]:-}"; do
  [ -n "$tok" ] || continue
  case "$tok" in
    --force-with-lease|--force-with-lease=*)
      [ "$FORCE" = "bare" ] || FORCE="lease"
      continue
      ;;
    --force)
      FORCE="bare"
      continue
      ;;
    --mirror) IS_MIRROR=1; continue ;;
    --all) IS_ALL=1; continue ;;
    --tags) IS_TAGS_FLAG=1; continue ;;
    --prune) IS_PRUNE=1; continue ;;
    --delete) IS_DELETE_FLAG=1; continue ;;
    -u|--set-upstream|--dry-run|-n|-v|--verbose|-q|--quiet|--follow-tags|--atomic|--no-verify) continue ;;
    -*)
      # Short-option cluster: a bare -f (force) anywhere in the cluster counts as bare force,
      # UNLESS this exact token already matched --force-with-lease above (long-form only, never
      # clustered, so no collision is possible here).
      case "$tok" in
        -*f*) FORCE="bare" ;;
      esac
      case "$tok" in
        -*d*) IS_DELETE_FLAG=1 ;;
      esac
      continue
      ;;
    *)
      if [ -z "$REMOTE_ARG" ] && [ "${#REFSPECS[@]}" -eq 0 ]; then
        REMOTE_ARG="$tok"
      else
        REFSPECS+=("$tok")
      fi
      ;;
  esac
done

# Resolve remote.
if [ -n "$REMOTE_ARG" ]; then
  REMOTE="$REMOTE_ARG"
else
  REMOTE="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)" || REMOTE=""
  REMOTE="${REMOTE%%/*}"
  [ -n "$REMOTE" ] || REMOTE="origin"
fi

IS_DELETE_REFSPEC=0
REF=""
REFSPEC_COUNT="${#REFSPECS[@]}"

if [ "$REFSPEC_COUNT" -eq 0 ]; then
  REF="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" || REF=""
elif [ "$REFSPEC_COUNT" -ge 1 ]; then
  FIRST_SPEC="${REFSPECS[0]}"
  case "$FIRST_SPEC" in
    *:*)
      DST="${FIRST_SPEC#*:}"
      SRC="${FIRST_SPEC%%:*}"
      if [ -z "$DST" ] || [ -z "$SRC" ]; then
        IS_DELETE_REFSPEC=1
        REF="${DST:-$SRC}"
      else
        REF="$DST"
      fi
      ;;
    HEAD)
      REF="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" || REF="HEAD"
      ;;
    *)
      REF="$FIRST_SPEC"
      ;;
  esac
fi
[ "$REFSPEC_COUNT" -ge 1 ] || REFSPEC_COUNT=1   # bare push: exactly one implicit refspec

if [ "$IS_DELETE_FLAG" = "1" ]; then
  IS_DELETE_REFSPEC=1
fi

# Tag-vs-branch classification: a bare `git push <remote> <name>` (no explicit refs/heads or
# refs/tags prefix) is how /tag's own STEP 8 pushes (skill-tag/SKILL.md, commands/tag.md) --
# git itself resolves <name> by matching it against local refs. A grant minted for push_tag
# (REF="refs/tags/*") can never match ACTION_CLASS=push_branch, so this hook must classify the
# SAME way git does: a local refs/tags/<name> that is NOT also a local refs/heads/<name> means
# this is a tag push. Without this, /tag's own push would be blocked by its own grant.
ACTION_CLASS="push_branch"
MATCH_REF="$REF"
if git rev-parse --verify --quiet "refs/tags/${REF}" >/dev/null 2>&1 \
  && ! git rev-parse --verify --quiet "refs/heads/${REF}" >/dev/null 2>&1; then
  ACTION_CLASS="push_tag"
  MATCH_REF="refs/tags/*"
fi

# --- Order of checks, strictly: exclusion before grant lookup ---------------------------------
EXCLUDE_REASON="$(pg_categorical_excluded "$ACTION_CLASS" "$REMOTE" "$MATCH_REF" "$FORCE" \
  "$IS_MIRROR" "$IS_ALL" "$IS_TAGS_FLAG" "$IS_PRUNE" "$IS_DELETE_REFSPEC" "$REFSPEC_COUNT")"
if [ -n "$EXCLUDE_REASON" ]; then
  echo "BLOCKED: $EXCLUDE_REASON" >&2
  echo "This exclusion applies even with an otherwise-valid grant -- categorical exclusions are" >&2
  echo "checked before any grant lookup." >&2
  exit 2
fi

if pg_grant_consume "$ACTION_CLASS" "$REMOTE" "$MATCH_REF" "$FORCE" "guard-git-push.sh"; then
  exit 0
fi

echo "BLOCKED: git push (remote='$REMOTE' ref='$REF' force='$FORCE') has no matching grant." >&2
echo "No grant, an expired grant, a wrong branch/remote/force, or a HEAD moved since the mint" >&2
echo "all produce this same refusal (fail-closed)." >&2
echo "To authorize this push, a human must type: /please push ${REMOTE} ${REF}" >&2
echo "then run: bash .claude/scripts/git-push-granted.sh --remote ${REMOTE} --ref ${REF}" >&2
exit 2
