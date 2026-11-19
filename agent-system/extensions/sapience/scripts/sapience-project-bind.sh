#!/usr/bin/env bash
# sapience-project-bind.sh - Interactive, confirm-or-refuse creation of a FRESH Sapience project,
# shared with one collaborator, with the binding persisted to this repo's .sapience/project.json.
#
# Usage: sapience-project-bind.sh --name "<display name>" --confirm [--to <person id>]
#        sapience-project-bind.sh --name "<display name>"                 # dry-run (default)
#
# This is the ONE outward-facing mutation in the sapience-project-binding-and-vault-read task
# group: POST /v1/people/projects/share notifies the named collaborator immediately. It therefore
# MUST happen interactively, with the user confirming the project NAME, never autonomously and
# never during an unattended run. Both an explicit --name and a separate, non-default --confirm
# flag are required before any network call fires; omitting either refuses with a non-zero exit
# and no call. The default posture (no --confirm) is --dry-run: print the literal payload this
# script would send (to, project.kind, project.key, follow) and exit 0 without a network call.
#
# Why creating (never reusing) a project matters MECHANICALLY, not as a preference: the server's
# project_split_confirmed computes `cross = doors & (sent | added | first_doors-if-owner-and-not-
# sent)`. As a non-creator member with auto:false, that intersection is empty, so a tagged note
# lands as a suggestion only its author sees. As the CREATOR with follow:true, notes flow to the
# collaborator without a per-note confirm. Creating the project (this script's whole job) is what
# makes this repo's seat the owner, which is what makes that flow possible at all.
#
# Collaborator discovery: GET /v1/people returns this brain's connections (`people: [{id, name,
# ...}]`) and this brain's own seat (`me_id`). Neither is ever hardcoded. When exactly one
# connection exists, it is used as the share target; otherwise --to <person id> is required to
# disambiguate (refuse loudly rather than guess).
#
# .sapience/project.json is written in repo_link.py's EXACT `link_text` format: a JSON object
# with EXACTLY three string keys, in order `project` (the channel cid), `name` (display name),
# `repo` (this repo's short name) -- two-space indent, one trailing newline, no fourth key.
# `parse_link` on the server side refuses any dict carrying a token/key/secret/password-shaped
# key, and refuses a `repo` value that is not `^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$` or that looks
# like a path -- both are validated and refused BEFORE any write here, matching that contract.
# Multiple repos are supported: each repo's own binding lives at its own toplevel, one file per
# repo, so running this script again from a different repo writes a second, independent file.
#
# DEAD PATH, recorded so it is not rediscovered: the purpose-built repo-link mechanism (this
# file consumed server-side, plus `project_cid` on every call, plus `project_room_contribute`
# writing straight into the room) is OFF for this token (REPO_LINK_FOR unset; the installed
# ~/.sapience/mcp.py has zero occurrences of `project_cid`). This script writes the identical
# file format anyway, so it needs no changes the moment that flag is enabled -- the file is
# simply committed JSON today, read back by this task's OWN scripts, not yet by the server.
#
# Loud-failure discipline on the share response, written against the CONFIRMED {ok, project, to}
# shape (never sapience-remember.sh's written/gated/set_aside field names -- this response has
# none of them): a non-2xx HTTP status, a non-JSON body, an empty `to` array, or a response
# lacking `ok: true` is a loud, non-zero-exit failure, never a success-shaped guess.
#
# No reference, anywhere in this file, to sapience_remember / sapience_wrapup / sapience_handoff
# / sapience_adddoc as a write path (rules/sapience-write-path.md). The one write this script
# performs goes through sapience-api-lib.sh's sapience_post, a direct authenticated POST, not an
# MCP tool call.
#
# Exit codes:
#   0 - dry-run printed (no --confirm), or the share succeeded and .sapience/project.json was
#       written
#   1 - bad arguments (missing --name, missing --confirm's required pairing, ambiguous --to),
#       unresolvable repo toplevel, no token configured, curl transport failure, non-JSON
#       response, invalid key/repo value
#   2 - the server reported a failure-shaped response (non-2xx status, empty `to`, missing
#       `ok: true`)

set -euo pipefail

NAME=""
CONFIRM="false"
TO_OVERRIDE=""

usage() {
  cat >&2 <<'USAGE'
Usage: sapience-project-bind.sh --name "<display name>" --confirm [--to <person id>]
       sapience-project-bind.sh --name "<display name>"                 # dry-run (default)

Required:
  --name N          Display name for the FRESH project to create and share

Optional:
  --confirm         Actually perform the outward-facing share (default: dry-run, no network call)
  --to ID           Collaborator person id (GET /v1/people); required only when this brain has
                     more than one connection, since the target cannot be inferred unambiguously

Exit codes:
  0 - dry-run printed, or the share succeeded and .sapience/project.json was written
  1 - bad arguments, unresolvable repo toplevel, no token, curl/network failure, non-JSON
      response, invalid key/repo value
  2 - the server reported a failure-shaped response (non-2xx status, empty 'to', missing
      'ok: true')
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --name)
      [ "$#" -ge 2 ] || { echo "sapience-project-bind.sh: --name requires a value" >&2; exit 1; }
      NAME="$2"; shift 2 ;;
    --confirm)
      CONFIRM="true"; shift ;;
    --to)
      [ "$#" -ge 2 ] || { echo "sapience-project-bind.sh: --to requires a value" >&2; exit 1; }
      TO_OVERRIDE="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "sapience-project-bind.sh: unknown flag: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [ -z "$NAME" ]; then
  echo "sapience-project-bind.sh: --name is required (this is an outward-facing mutation; the project name must be explicit, never defaulted)" >&2
  exit 1
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

repo_toplevel="$(resolve_checkout_toplevel "$PROJECT_ROOT" 2>/dev/null)" || {
  echo "sapience-project-bind.sh: could not resolve a git toplevel from $PROJECT_ROOT" >&2
  exit 1
}
if [ -z "$repo_toplevel" ]; then
  echo "sapience-project-bind.sh: could not resolve a git toplevel from $PROJECT_ROOT" >&2
  exit 1
fi
repo_slug="$(basename "$repo_toplevel")"
if [ -z "$repo_slug" ]; then
  echo "sapience-project-bind.sh: empty repo slug" >&2
  exit 1
fi

REPO_NAME_RE='^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$'
if ! [[ "$repo_slug" =~ $REPO_NAME_RE ]]; then
  echo "sapience-project-bind.sh: repo short name '$repo_slug' does not match ${REPO_NAME_RE} (repo_link.py would refuse this) -- refusing before any write" >&2
  exit 1
fi
case "$repo_slug" in
  */*|*..*)
    echo "sapience-project-bind.sh: repo short name '$repo_slug' looks path-shaped -- refusing before any write" >&2
    exit 1
    ;;
esac

# --- Derive project.key from --name as a slug: lowercase, non-alphanumeric runs -> single
# hyphen, trimmed of leading/trailing hyphens, validated against the same repo-name-shaped
# pattern the server's own key convention expects. ---
project_key="$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
if [ -z "$project_key" ] || ! [[ "$project_key" =~ $REPO_NAME_RE ]]; then
  echo "sapience-project-bind.sh: --name \"$NAME\" produced an invalid project key \"$project_key\" (expected ${REPO_NAME_RE}) -- refusing before any write" >&2
  exit 1
fi

sapience_api_init || exit 1

# --- Dry-run posture (default, no --confirm): print the LITERAL payload shape and exit 0
# WITHOUT a network call -- not even the GET /v1/people discovery call below, which is a
# network request too. A placeholder stands in for the collaborator id (the dispatch's own
# creation-call template shows the same "<person id>" placeholder shape), unless --to was given
# explicitly, in which case the real value the confirmed run would use is shown instead. ---
if [ "$CONFIRM" != "true" ]; then
  dry_to="${TO_OVERRIDE:-<person id>}"
  dry_payload="$(jq -n \
    --arg to "$dry_to" \
    --arg key "$project_key" \
    '{to: [$to], project: {kind: "project", key: $key}, follow: true}')"
  echo "sapience-project-bind.sh: DRY-RUN -- pass --confirm to actually share this (no network call made)" >&2
  SAPIENCE_DRY_RUN=1 sapience_post "/v1/people/projects/share" "$dry_payload"
  exit 0
fi

# --- Discover the collaborator person id and this brain's own me_id at runtime (never
# hardcoded), unless --to was given explicitly. GET /v1/people: {ok, people: [{id, name, ...}],
# count, me, me_id}. ---
if [ -n "$TO_OVERRIDE" ]; then
  collaborator_id="$TO_OVERRIDE"
  me_id=""
else
  people_response="$(sapience_get "/v1/people")" || exit 1
  if [ -z "$people_response" ] || ! echo "$people_response" | jq -e . >/dev/null 2>&1; then
    echo "sapience-project-bind.sh: non-JSON or empty response from GET /v1/people" >&2
    exit 1
  fi
  me_id="$(echo "$people_response" | jq -r '.me_id // empty' 2>/dev/null)" || me_id=""
  people_count="$(echo "$people_response" | jq -r '.people // [] | length' 2>/dev/null)" || people_count=0

  if [ "$people_count" = "1" ]; then
    collaborator_id="$(echo "$people_response" | jq -r '.people[0].id // empty' 2>/dev/null)"
  else
    echo "sapience-project-bind.sh: GET /v1/people returned ${people_count} connection(s); pass --to <person id> to disambiguate (never guessing among multiple connections)" >&2
    exit 1
  fi

  if [ -z "$collaborator_id" ]; then
    echo "sapience-project-bind.sh: could not resolve a collaborator person id from GET /v1/people" >&2
    exit 1
  fi
fi

# --- Build the share payload for the confirmed, real request. ---
payload="$(jq -n \
  --arg to "$collaborator_id" \
  --arg key "$project_key" \
  '{to: [$to], project: {kind: "project", key: $key}, follow: true}')"

echo "sapience-project-bind.sh: sharing a fresh project \"${NAME}\" (key=${project_key}) with person ${collaborator_id} (me_id=${me_id})..." >&2

response="$(sapience_post "/v1/people/projects/share" "$payload")" || exit 1

if [ "${sapience_api_post_http_status:-}" != "" ]; then
  case "$sapience_api_post_http_status" in
    2??) : ;;
    *)
      echo "sapience-project-bind.sh: FAILED -- POST /v1/people/projects/share returned HTTP ${sapience_api_post_http_status}: ${response:0:300}" >&2
      exit 2
      ;;
  esac
fi

if [ -z "$response" ] || ! echo "$response" | jq -e . >/dev/null 2>&1; then
  echo "sapience-project-bind.sh: FAILED -- non-JSON or empty response from /v1/people/projects/share" >&2
  exit 2
fi

ok="$(echo "$response" | jq -r '.ok // false' 2>/dev/null)" || ok="false"
to_len="$(echo "$response" | jq '.to // [] | length' 2>/dev/null)" || to_len=0
# The channel cid is `.share.id` -- confirmed against brain_server.py's _people_project_share,
# which sets `out['share'] = row` where `row = people_share_project(...)` returns
# `project_public(ch, tok)`, and `project_public` -> `people_public` sets `id: ch.get('id', '')`.
# This is the SAME cid repo_link.py's `project` field names (never `.project.key`, which is only
# the slug this script itself sent in the request, not the server-minted channel id).
project_cid="$(echo "$response" | jq -r '.share.id // empty' 2>/dev/null)" || project_cid=""

if [ "$ok" != "true" ]; then
  echo "sapience-project-bind.sh: FAILED -- server returned ok=${ok}: ${response:0:300}" >&2
  exit 2
fi

if [ "$to_len" = "0" ] || [ -z "$to_len" ]; then
  echo "sapience-project-bind.sh: FAILED -- server returned an empty 'to' array (nothing was shared): ${response:0:300}" >&2
  exit 2
fi

if [ -z "$project_cid" ]; then
  echo "sapience-project-bind.sh: FAILED -- response carried no resolvable project identifier: ${response:0:300}" >&2
  exit 2
fi

# --- Persist the binding: EXACTLY three string keys, in order project/name/repo, 2-space
# indent, one trailing newline -- byte-identical to repo_link.py's link_text() serializer. ---
mkdir -p "${repo_toplevel}/.sapience"
link_file="${repo_toplevel}/.sapience/project.json"
jq -n \
  --arg project "$project_cid" \
  --arg name "$NAME" \
  --arg repo "$repo_slug" \
  '{project: $project, name: $name, repo: $repo}' > "$link_file"

echo "sapience-project-bind.sh: shared \"${NAME}\" with ${to_len} recipient(s); wrote ${link_file}"
exit 0
