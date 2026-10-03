#!/usr/bin/env bash
# please-grant.sh — UserPromptSubmit hook: the ONE tamper-resistant mint path for a push grant.
#
# Recognises exactly four literal prompt prefixes -- /please, /merge, /tag, /pr -- and mints
# nothing at all for any other prompt (including one that merely mentions "push" or "/please"
# without being one). This is the mint path's whole security property: a UserPromptSubmit hook
# fires only on this Claude Code session's own prompt-submission pipeline. Two facts verified
# empirically during Phase 1 before this file was written (recorded in the Phase 1 progress
# file and the implementation summary):
#   - A dispatched subagent (launched via the Agent/Task tool) NEVER triggers this hook at all --
#     confirmed by dispatching a throwaway subagent whose instructions literally began with
#     "/please push ..." and observing zero log entries from a temporary diagnostic hook.
#   - An inter-agent SendMessage delivery INTO this session (e.g. from a teammate agent) DOES
#     fire this hook, but the payload's .prompt field arrives wrapped in
#     `<agent-message from="...">...</agent-message>` tags -- confirmed the same way, including
#     with a relayed message whose body literally started with "/please push ...". Because the
#     prefix check below is a strict, anchored startswith (never a substring search), a
#     wrapped payload can never match -- the wrapper tag itself is the first four bytes, not a
#     slash. This is why the match below MUST stay startswith-anchored and must never be
#     loosened to a "contains" check.
#
# Never exits non-zero: a UserPromptSubmit hook that fails must not block the user's own prompt.
# Every failure path (ambiguous grammar, categorical exclusion, write failure) is reported via a
# stdout line (which Claude Code injects as prompt context) and results in NO grant, never a
# non-zero exit. Accordingly this file intentionally does NOT use `set -e` -- every risky
# command is individually guarded instead, so a single failure degrades to "no grant minted"
# rather than aborting the hook before it can print anything or echo its JSON response.
set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="${HOOK_DIR}/../scripts/lib/push-grant-lib.sh"

exit_ok() {
  echo '{}'
  exit 0
}

[ -r "$LIB" ] || exit_ok
# shellcheck source=../scripts/lib/push-grant-lib.sh
source "$LIB" || exit_ok

INPUT="$(cat 2>/dev/null)" || INPUT=""
PROMPT="$(printf '%s' "$INPUT" | jq -r '.prompt // ""' 2>/dev/null)" || PROMPT=""
[ -n "$PROMPT" ] || exit_ok

# Strip at most one leading space/tab run so "  /please ..." still recognises -- the prompt box
# itself does not usually produce leading whitespace, but this costs nothing and matches the
# tolerance convention in hooks/wezterm-task-number.sh.
STRIPPED="${PROMPT#"${PROMPT%%[![:space:]]*}"}"

REQUEST_TEXT="$STRIPPED"
MINT_SOURCE=""
REMOTE=""
REF=""
FORCE="0"
ACTION_CLASS=""
REST=""

case "$STRIPPED" in
  /please[[:space:]]*|/please)
    MINT_SOURCE="please"
    REST="${STRIPPED#/please}"
    ;;
  /merge|/merge[[:space:]]*)
    MINT_SOURCE="merge"
    ;;
  /tag|/tag[[:space:]]*)
    MINT_SOURCE="tag"
    ;;
  /pr|/pr[[:space:]]*)
    MINT_SOURCE="pr"
    ;;
  *)
    # Covers both "doesn't start with any of the four prefixes" and an agent-relayed message
    # wrapped in <agent-message ...> tags -- neither is one of our four prefixes, so this
    # branch is reached and the hook exits silently with no output and no grant, exactly as the
    # design requires.
    exit_ok
    ;;
esac

# --- /merge, /tag, /pr: mint from repo state at prompt time, no free-text parsing -----------
if [ "$MINT_SOURCE" = "merge" ] || [ "$MINT_SOURCE" = "pr" ]; then
  ACTION_CLASS="push_branch"
  REMOTE="origin"
  REF="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" || REF=""
  FORCE="0"
  [ -n "$REF" ] && [ "$REF" != "HEAD" ] || exit_ok
elif [ "$MINT_SOURCE" = "tag" ]; then
  ACTION_CLASS="push_tag"
  REMOTE="origin"
  REF="refs/tags/*"
  FORCE="0"
fi

# --- /please: parse the free-text grammar -----------------------------------------------------
if [ "$MINT_SOURCE" = "please" ]; then
  TEXT="${REST#"${REST%%[![:space:]]*}"}"   # strip leading whitespace after "/please"
  [ -n "$TEXT" ] || TEXT=""

  IS_BARE_FORCE=0
  case "$TEXT" in
    force\ *)
      IS_BARE_FORCE=1
      TEXT="${TEXT#force }"
      TEXT="${TEXT#"${TEXT%%[![:space:]]*}"}"
      ;;
  esac

  IS_LEASE=0
  MATCHED=0

  # Tag form: push tag <name> to <remote> [--force-with-lease]
  if [[ "$TEXT" =~ ^push[[:space:]]+tag[[:space:]]+([^[:space:]]+)[[:space:]]+to[[:space:]]+([^[:space:]]+)([[:space:]]+--force-with-lease)?[[:space:]]*$ ]]; then
    MATCHED=1
    ACTION_CLASS="push_tag"
    REF="refs/tags/*"
    REMOTE="${BASH_REMATCH[2]}"
    [ -n "${BASH_REMATCH[3]:-}" ] && IS_LEASE=1
  # Branch "to" form: push <branch> to <remote> [--force-with-lease]
  elif [[ "$TEXT" =~ ^push[[:space:]]+([^[:space:]]+)[[:space:]]+to[[:space:]]+([^[:space:]]+)([[:space:]]+--force-with-lease)?[[:space:]]*$ ]]; then
    MATCHED=1
    ACTION_CLASS="push_branch"
    REF="${BASH_REMATCH[1]}"
    REMOTE="${BASH_REMATCH[2]}"
    [ -n "${BASH_REMATCH[3]:-}" ] && IS_LEASE=1
  # Remote-branch form: push <remote> <branch> [--force-with-lease]
  elif [[ "$TEXT" =~ ^push[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)([[:space:]]+--force-with-lease)?[[:space:]]*$ ]]; then
    MATCHED=1
    ACTION_CLASS="push_branch"
    REMOTE="${BASH_REMATCH[1]}"
    REF="${BASH_REMATCH[2]}"
    [ -n "${BASH_REMATCH[3]:-}" ] && IS_LEASE=1
  fi

  # Destructive-action forms (the five classes guard-destructive-git.sh's grant check
  # recognises; see push-grant-lib.sh's PG_ACTION_CLASSES). These have no remote/force concept
  # -- REMOTE/REF/FORCE are the fixed sentinels guard-destructive-git.sh's own grant check uses
  # (REMOTE="local", REF=current branch or "HEAD" if detached, FORCE="0"), so minting here
  # produces a grant that check can actually match. The bare "force" prefix strip above does not
  # apply to this family (there is no --force-with-lease analogue for a local destructive
  # action), so IS_BARE_FORCE/IS_LEASE are simply left at 0 for this branch.
  DESTRUCTIVE_MATCHED=0
  if [ "$MATCHED" -ne 1 ]; then
    case "$TEXT" in
      "git reset --hard"|"reset --hard"|"reset hard")
        DESTRUCTIVE_MATCHED=1; ACTION_CLASS="reset_hard" ;;
      "git clean -fd"|"git clean -df"|"clean -fd"|"clean -df")
        DESTRUCTIVE_MATCHED=1; ACTION_CLASS="clean_fd" ;;
      "git stash drop"|"stash drop"|"git stash clear"|"stash clear")
        DESTRUCTIVE_MATCHED=1; ACTION_CLASS="stash_drop" ;;
      *)
        if [[ "$TEXT" =~ ^(git[[:space:]]+)?checkout[[:space:]]+--[[:space:]]+(.+)$ ]] \
          || [[ "$TEXT" =~ ^(git[[:space:]]+)?(checkout|switch)[[:space:]]+-f(orce)?$ ]]; then
          DESTRUCTIVE_MATCHED=1; ACTION_CLASS="checkout_discard"
        elif [[ "$TEXT" =~ ^(git[[:space:]]+)?restore[[:space:]]+(.+)$ ]]; then
          DESTRUCTIVE_MATCHED=1; ACTION_CLASS="restore_discard"
        fi
        ;;
    esac
    if [ "$DESTRUCTIVE_MATCHED" -eq 1 ]; then
      MATCHED=1
      REMOTE="local"
      REF="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" || REF=""
      [ -n "$REF" ] && [ "$REF" != "HEAD" ] || REF="HEAD"
      FORCE="0"
    fi
  fi

  if [ "$MATCHED" -ne 1 ]; then
    echo "please-grant: could not parse exactly one request from \"$TEXT\". Accepted push forms:" \
      "'push <remote> <branch>', 'push <branch> to <remote>', 'push tag <name> to <remote>'" \
      "(each with an optional trailing --force-with-lease). Accepted destructive forms:" \
      "'git reset --hard', 'git clean -fd', 'git checkout -- <path>', 'git restore <path>'," \
      "'git stash drop', 'git stash clear', 'git checkout -f'/'git switch -f'. No grant minted."
    exit_ok
  fi

  if [ "$DESTRUCTIVE_MATCHED" -eq 1 ]; then
    : # FORCE/REMOTE/REF already set to the destructive-class sentinels above; skip push FORCE logic.
  elif [ "$IS_BARE_FORCE" -eq 1 ]; then
    FORCE="bare"
  elif [ "$IS_LEASE" -eq 1 ]; then
    FORCE="lease"
  else
    FORCE="0"
  fi
fi

[ -n "$MINT_SOURCE" ] && [ -n "$ACTION_CLASS" ] && [ -n "$REMOTE" ] && [ -n "$REF" ] || exit_ok

HEAD_SHA="$(git rev-parse HEAD 2>/dev/null)" || HEAD_SHA=""
[ -n "$HEAD_SHA" ] || exit_ok

# --- Categorical exclusions, checked BEFORE any mint ------------------------------------------
EXCLUDE_REASON="$(pg_categorical_excluded "$ACTION_CLASS" "$REMOTE" "$REF" "$FORCE" 0 0 0 0 0 1)"
if [ -n "$EXCLUDE_REASON" ]; then
  echo "please-grant: refused -- $EXCLUDE_REASON. No grant minted."
  exit_ok
fi

# A bare "force" request is syntactically valid but NEVER mintable (the exclusion check above
# already refuses it for push_branch/push_tag's default-branch and bare-force rules, but a
# non-default-branch bare force is excluded unconditionally too -- belt-and-suspenders in case
# pg_categorical_excluded's bare-force branch is ever narrowed).
if [ "$FORCE" = "bare" ]; then
  echo "please-grant: refused -- bare --force is never grant-authorizable. No grant minted."
  exit_ok
fi

# At most one grant is ever live.
pg_grant_revoke || true

GRANT_PATH="$(pg_grant_mint "$ACTION_CLASS" "$REMOTE" "$REF" "$FORCE" "$HEAD_SHA" "$REQUEST_TEXT" "$MINT_SOURCE")"
if [ -z "$GRANT_PATH" ]; then
  echo "please-grant: failed to mint a grant (internal error). No grant minted."
  exit_ok
fi

SHORT_SHA="${HEAD_SHA:0:7}"
case "$ACTION_CLASS" in
  push_branch|push_tag)
    echo "please-grant: granted ${ACTION_CLASS} to ${REMOTE} ${REF} (${SHORT_SHA}, force=${FORCE})," \
      "expires in ${PG_EXPIRY_WINDOW}s. Push via: bash .claude/scripts/git-push-granted.sh" \
      "--remote ${REMOTE} --ref ${REF}$( [ "$FORCE" = lease ] && echo ' --force-with-lease' )"
    ;;
  *)
    echo "please-grant: granted ${ACTION_CLASS} on branch ${REF} (${SHORT_SHA})," \
      "expires in ${PG_EXPIRY_WINDOW}s. Run the matching git command directly --" \
      "hooks/guard-destructive-git.sh consumes this grant the one time that command runs."
    ;;
esac

exit_ok
