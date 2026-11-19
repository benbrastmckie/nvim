#!/usr/bin/env bash
# sapience-publish.sh - The four Sapience write-surface publishers, behind one entry point.
#
# Usage: sapience-publish.sh doc-comment <slug> --body <text> [--quote <text>] [--reply-to <id>]
#                             [--resolve] [--confirm]
#        sapience-publish.sh doc-version <slug> --body-file <path> [--title <text>] [--confirm]
#        sapience-publish.sh dm --to <person-id> --body <text> [--confirm]
#        sapience-publish.sh ko --note <text> [--note <text> ...] [--project <cid>] [--confirm]
#
# Every subcommand is DRY-RUN BY DEFAULT: without --confirm, it prints the LITERAL payload it
# would POST (produced by the same payload-construction code path the confirmed write uses --
# never a second, divergent preview string) and makes NO network call. --confirm is the only way
# to actually write. --dry-run and --confirm are mutually exclusive (both named is a refusal).
#
# WRITE-PATH DISCIPLINE (rules/sapience-write-path.md): this script, doing a direct authenticated
# POST through lib/sapience-api-lib.sh, is the ONLY prescribed write path for all four surfaces.
# No instruction surface anywhere in this file names any of the four MCP write tools as a write
# path to use instead -- doing so would require a new MCP write grant, which the 7-tool read-only
# grant in settings-fragment.json deliberately does not carry. A Bash script call is not an MCP
# tool invocation, so none of this needs a grant change.
#
# THE KO PUBLISHER'S PROJECT KEY CANNOT BE READ LOCALLY: .sapience/project.json (written by
# sapience-project-bind.sh) stores exactly {project (cid), name, repo} -- structurally, it cannot
# carry a `key` field, because repo_link.py's parse_link refuses any secret/token/key-shaped dict
# key before this script ever sees the file. But _ko_matches_channel (extract_local.py) compares
# ko['project'] against a channel's short `key`/`workstream` slug, not the cid. So the `ko`
# subcommand resolves the key AT RUNTIME via GET /v1/people/projects, matching the binding's cid
# against that list's entries, and refuses loudly rather than guessing or falling back to the
# binding's free-text `name` field.
#
# EACH SUBCOMMAND'S LOUD-FAILURE CHECKS ARE WRITTEN AGAINST THAT ENDPOINT'S OWN VERIFIED RESPONSE
# SHAPE -- never a single generic check borrowed from a different endpoint. In particular, the
# `ko` subcommand reuses sapience-remember.sh's four-check `/ingest-kos` order verbatim
# (set_aside -> gated -> written -> ok), while `doc-comment`/`dm` check the comments endpoint's own
# {slug, n, hash, author, at} shape and `doc-version` distinguishes 409/202/404/200 as four
# distinct outcomes. These are NOT interchangeable and must never be conflated.
#
# `project_cid` is NEVER sent on any call (Non-Goals in the governing plan): the REPO_LINK_FOR
# path is confirmed dark for this token, and _project_stamp would unconditionally overwrite a
# client-set ko['project'] the day a project_cid were ever server-verified -- so this script sends
# only the plain `project` field and needs no code change when that flag eventually flips.
#
# Exit codes (general; each subcommand's own header comment states any refinement):
#   0 - dry-run printed, or the confirmed write succeeded (including doc-version's 202
#       people_propose outcome, which is a non-error alternate path, not a failure)
#   1 - bad arguments, unresolvable repo toplevel, no token, curl/network transport failure,
#       non-JSON response, local pre-validation refusal (length/pattern)
#   2 - the server reported a failure-shaped or silent-loss response for that endpoint's own
#       verified shape (see each subcommand's own section below)

set -euo pipefail

SUBCOMMAND=""
CONFIRM="false"
DRY_RUN_FLAG="false"

usage() {
  cat >&2 <<'USAGE'
Usage: sapience-publish.sh doc-comment <slug> --body <text> [--quote <text>] [--reply-to <id>]
                            [--resolve] [--confirm]
       sapience-publish.sh doc-version <slug> --body-file <path> [--title <text>] [--confirm]
       sapience-publish.sh dm --to <person-id> --body <text> [--confirm]
       sapience-publish.sh ko --note <text> [--note <text> ...] [--project <cid>] [--confirm]

Every subcommand is dry-run by default: without --confirm, it prints the literal payload it
would POST and makes no network call. Pass --confirm to actually write. --dry-run and --confirm
together are refused.

Subcommands:
  doc-comment   Post a comment on a doc (POST /v1/docs/<slug>/comments)
  doc-version   Save a new doc version with base_rev concurrency (POST /v1/docs/<slug>)
  dm            Send a direct message, reusing an existing conversation when one exists
  ko            Write a repo-tagged knowledge object (POST /ingest-kos), project key resolved
                at runtime

Exit codes:
  0 - dry-run printed, or the confirmed write succeeded
  1 - bad arguments, unresolvable repo toplevel, no token, curl/network transport failure,
      non-JSON response, local pre-validation refusal
  2 - the server reported a failure-shaped or silent-loss response for that endpoint
USAGE
}

if [ "$#" -eq 0 ]; then
  echo "sapience-publish.sh: a subcommand is required" >&2
  usage
  exit 1
fi

SUBCOMMAND="$1"; shift

case "$SUBCOMMAND" in
  doc-comment|doc-version|dm|ko|-h|--help) : ;;
  *)
    echo "sapience-publish.sh: unknown subcommand: $SUBCOMMAND" >&2
    usage
    exit 1
    ;;
esac

if [ "$SUBCOMMAND" = "-h" ] || [ "$SUBCOMMAND" = "--help" ]; then
  usage
  exit 0
fi

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/sapience-api-lib.sh"

# === BEGIN sapience-worktree-checkout-resolution (byte-identical in every copy: this hook,
# verify-sapience-mcp.sh, sapience-retrieve.sh, sapience-remember.sh, and
# verify-sapience-context-scoping.sh -- test-sapience-mcp-registration.sh's lockstep case
# extracts this marker-delimited block from each copy and asserts they are all byte-identical).
# Resolves a directory (default: cwd) to its git toplevel, following a linked worktree to its
# PARENT CHECKOUT rather than the worktree itself. Echoes the toplevel path and returns 0, or
# returns 1 with no output when the directory is not inside a git repository at all.
#
# Detection: compare `git rev-parse --git-dir` against `--git-common-dir`. Equal (including
# both failing, on a non-git path) means "not a linked worktree -- behave exactly like a bare
# `git rev-parse --show-toplevel`". Unequal means "linked worktree -- the common dir's PARENT
# directory is the checkout". `--git-common-dir` returns a relative path at a checkout root but
# an absolute path from inside a worktree, so it is absolutized before its parent is taken.
resolve_checkout_toplevel() {
    local dir="${1:-.}" git_dir common_dir
    git_dir="$(git -C "$dir" rev-parse --git-dir 2>/dev/null)" || return 1
    common_dir="$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null)" || return 1
    if [ "$git_dir" = "$common_dir" ]; then
        git -C "$dir" rev-parse --show-toplevel 2>/dev/null
        return $?
    fi
    case "$common_dir" in
        /*) : ;;
        *) common_dir="$(cd "$dir" 2>/dev/null && pwd)/$common_dir" ;;
    esac
    (cd "$common_dir/.." 2>/dev/null && pwd)
}
# === END sapience-worktree-checkout-resolution ===

# --- Shared flag parsing. Each subcommand below re-walks "$@" for its own flags; the generic
# --confirm/--dry-run/--help trio is intercepted here first so every subcommand gets identical
# mutual-exclusion behavior for free. Unrecognized flags are left in SUBCOMMAND_ARGS for the
# subcommand's own parser to interpret or reject. ---
SUBCOMMAND_ARGS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --confirm)
      CONFIRM="true"; shift ;;
    --dry-run)
      DRY_RUN_FLAG="true"; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      SUBCOMMAND_ARGS+=("$1"); shift ;;
  esac
done

if [ "$CONFIRM" = "true" ] && [ "$DRY_RUN_FLAG" = "true" ]; then
  echo "sapience-publish.sh: --dry-run and --confirm are mutually exclusive" >&2
  exit 1
fi

case "$SUBCOMMAND" in
  doc-comment)
    echo "sapience-publish.sh: doc-comment: not yet implemented" >&2
    exit 1
    ;;
  doc-version)
    echo "sapience-publish.sh: doc-version: not yet implemented" >&2
    exit 1
    ;;
  dm)
    echo "sapience-publish.sh: dm: not yet implemented" >&2
    exit 1
    ;;
  ko)
    echo "sapience-publish.sh: ko: not yet implemented" >&2
    exit 1
    ;;
esac
