#!/usr/bin/env bash
# git-push-granted.sh — the sanctioned, explicit-argument wrapper for a consent-gated git push.
#
# Shaped on git-commit-scoped.sh: SCRIPT_DIR resolution, lib/common.sh, common_repo_root,
# deploy-root-guard.sh -- this script, like git-commit-scoped.sh, MUST run from a deployed tree
# (.claude/scripts/ or .opencode/scripts/), never the source store directly.
#
# IMPORTANT DIVERGENCE from git-commit-scoped.sh's mutex: that script fails OPEN on a lock
# acquire failure (proceeds unserialized), reasoning the worst residual case is a safe
# index.lock race. This wrapper has no such safe residual -- every verification step here
# (grant lookup, HMAC check, categorical exclusion) FAILS CLOSED: any read/verify/lock problem
# refuses the push rather than proceeding. Do not inherit git-commit-scoped.sh's fail-open
# direction into this file.
#
# Usage:
#   git-push-granted.sh --remote <name> --ref <branch-or-tag> [--force-with-lease] [--tag] \
#       [--session <sid>] [--revoke] [--help]
#
# --revoke deletes every live grant and exits 0 (used by /merge and /tag cancel paths so a
# cancelled flow does not leave a live grant for the rest of the 600s window).
#
# Exit codes:
#   0 - push performed (grant consumed) or --revoke completed
#   1 - usage error
#   2 - refused: no matching grant, categorically excluded, or the push itself failed

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
source "${SCRIPT_DIR}/lib/push-grant-lib.sh" || { echo "ERROR: push-grant-lib.sh unavailable" >&2; exit 1; }

usage() {
  cat >&2 <<'USAGE'
Usage: git-push-granted.sh --remote <name> --ref <branch-or-tag> [--force-with-lease] [--tag] \
    [--session <sid>] [--revoke] [--help]

Pushes exactly the (remote, ref) pair a live, matching, unconsumed grant authorizes, consuming
that grant. Refuses (exit 2) on any categorical exclusion or missing/invalid/mismatched grant --
never infers or widens the request. --tag selects ACTION_CLASS=push_tag matching (the grant's
own REF field is the literal pattern "refs/tags/*" for a tag grant; this flag tells the wrapper
which ACTION_CLASS to match against, it is not itself part of the pushed refspec).
USAGE
  exit 1
}

remote=""
ref=""
force="0"
is_tag=0
session_id=""
do_revoke=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --remote) [ "$#" -ge 2 ] || usage; remote="$2"; shift 2 ;;
    --ref) [ "$#" -ge 2 ] || usage; ref="$2"; shift 2 ;;
    --force-with-lease) force="lease"; shift ;;
    --tag) is_tag=1; shift ;;
    --session) [ "$#" -ge 2 ] || usage; session_id="$2"; shift 2 ;;
    --revoke) do_revoke=1; shift ;;
    -h|--help) usage ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage ;;
  esac
done

cd "$PROJECT_ROOT" || exit 2

if [ "$do_revoke" -eq 1 ]; then
  pg_grant_revoke
  echo "git-push-granted.sh: all live grants revoked."
  exit 0
fi

[ -n "$remote" ] && [ -n "$ref" ] || usage

ACTION_CLASS="push_branch"
MATCH_REF="$ref"
if [ "$is_tag" -eq 1 ]; then
  ACTION_CLASS="push_tag"
  MATCH_REF="refs/tags/${ref}"
fi

# Categorical exclusions, checked before any grant lookup -- refuse ambiguous/excluded requests
# rather than inferring around them (the V2/V3/V4 "refuse ambiguous input" precedent).
EXCLUDE_REASON="$(pg_categorical_excluded "$ACTION_CLASS" "$remote" "$MATCH_REF" "$force" 0 0 0 0 0 1)"
if [ -n "$EXCLUDE_REASON" ]; then
  echo "ERROR: refused -- $EXCLUDE_REASON" >&2
  exit 2
fi

if ! pg_grant_consume "$ACTION_CLASS" "$remote" "$MATCH_REF" "$force" "git-push-granted.sh"; then
  echo "ERROR: no matching, fresh, verifying grant for ${ACTION_CLASS} ${remote} ${MATCH_REF}" \
    "(force=${force}). Run /please push ${remote} ${ref}$( [ "$force" = lease ] && echo ' --force-with-lease' ) first." >&2
  exit 2
fi

PUSH_ARGS=(push "$remote" "$ref")
[ "$force" = "lease" ] && PUSH_ARGS+=(--force-with-lease)

if ! git "${PUSH_ARGS[@]}"; then
  echo "ERROR: git push failed after the grant was already consumed. The grant is gone; a new" >&2
  echo "/please request is required to retry." >&2
  exit 2
fi

echo "git-push-granted.sh: pushed ${remote} ${ref} (force=${force})."
exit 0
