#!/usr/bin/env bash
# sapience-project-bind.sh - Three modes over this repo's binding to a Sapience project:
#   (1) pick mode (no --name, no --project): lists the caller's accepted and owned projects and
#       exits non-zero, writing and POSTing nothing.
#   (2) bind mode (--project <name|id>): resolves the value to exactly one already-accepted or
#       owned project and registers this repository with it through the link route.
#   (3) create mode (--name <display name>, unchanged from before this script had the other two
#       modes): confirm-or-refuse creation of a FRESH Sapience project, shared with one
#       collaborator, with the binding persisted the same way.
#
# Usage: sapience-project-bind.sh                                          # pick (list, exit non-zero)
#        sapience-project-bind.sh --project "<name or id>" --confirm [--force]
#        sapience-project-bind.sh --project "<name or id>"                 # bind dry-run (default)
#        sapience-project-bind.sh --name "<display name>" --confirm [--to <person id>]
#        sapience-project-bind.sh --name "<display name>"                 # create dry-run (default)
#
# --name and --project are mutually exclusive: two different modes, never silently preferring
# one. --confirm requires one of them; given alone it is refused (nothing to confirm).
#
# The create path (--name) is the ONE outward-facing mutation that notifies a collaborator
# immediately: POST /v1/people/projects/share. It therefore MUST happen interactively, with the
# user confirming the project NAME, never autonomously and never during an unattended run. Both
# an explicit --name and a separate, non-default --confirm flag are required before any network
# call fires; omitting either refuses with a non-zero exit and no call. The default posture (no
# --confirm) is --dry-run: print the literal payload this script would send (to, project.kind,
# project.key, follow) and exit 0 without a network call.
#
# The bind path (--project) registers this repository with a project the caller already belongs
# to (accepted member or owner) via POST /v1/people/projects/<cid>/link. Default posture (no
# --confirm) is dry-run: print the literal {"repo": "<slug>"} payload and exit 0 without a POST
# (the one resolving GET /v1/people/projects lookup above already fired, unlike create-mode
# dry-run, which makes no network call at all). --confirm POSTs and classifies the outcome by
# HTTP status ONLY, never by parsing vendor or server prose: 2xx with ok:true writes the file and
# reports success; 404 (the feature not available for this account, or the cid/membership lookup
# missing) writes the file anyway and reports that the server does not read it yet (bound
# locally only); 403 (not an accepted member) writes nothing and refuses; any other outcome is a
# loud failure that writes nothing. A prior binding to a DIFFERENT project is never silently
# replaced -- re-run with --force to overwrite it.
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
# lacking `ok: true` is a loud, non-zero-exit failure, never a success-shaped guess. The link
# route's 404 is the ONE deliberate exception to "non-2xx is a failure": it still writes the
# file (see above).
#
# Single-writer invariant: write_link_file() is the ONLY site in this file that writes
# .sapience/project.json -- the create path (`.share.id`) and the bind path (the picked row's own
# id, captured before the POST) both route through it. The link response's own `project` field,
# when present, is the {kind, key, name} descriptor dict -- NEVER a channel cid, unlike the share
# response's `.share.id` -- and no code path in this file reads a cid out of it.
#
# No reference, anywhere in this file, to sapience_remember / sapience_wrapup / sapience_handoff
# / sapience_adddoc as a write path (rules/sapience-write-path.md). The one write this script
# performs goes through sapience-api-lib.sh's sapience_post, a direct authenticated POST, not an
# MCP tool call.
#
# Exit codes:
#   0 - dry-run printed (no --confirm), the share/link succeeded and .sapience/project.json was
#       written, the link route returned 404 (written locally only), or (pick mode) the listing
#       printed
#   1 - bad arguments (both --name and --project, --confirm with neither, missing --name's or
#       --to's value, ambiguous --to, --project matching zero or more than one row, pick mode
#       with no rows), unresolvable repo toplevel, no token configured, curl transport failure,
#       non-JSON response, invalid key/repo value, an existing conflicting link without --force
#   2 - the server reported a failure-shaped response on the create path (non-2xx status, empty
#       `to`, missing `ok: true`), or the link route returned 403 (join the project first) or any
#       other non-2xx/non-404 outcome on the bind path

set -euo pipefail

NAME=""
CONFIRM="false"
TO_OVERRIDE=""
PROJECT_VALUE=""
FORCE="false"

usage() {
  cat >&2 <<'USAGE'
Usage: sapience-project-bind.sh                                          # pick (list, exit non-zero)
       sapience-project-bind.sh --project "<name or id>" --confirm [--force]
       sapience-project-bind.sh --project "<name or id>"                 # bind dry-run (default)
       sapience-project-bind.sh --name "<display name>" --confirm [--to <person id>]
       sapience-project-bind.sh --name "<display name>"                 # create dry-run (default)

Modes (mutually exclusive):
  (no flag)         Pick mode: list the caller's accepted and owned projects, exit non-zero
  --project N        Bind mode: register this repository with the already-accepted/owned
                     project N (matched case-insensitively against id, title, or project.key)
  --name N          Create mode: display name for a FRESH project to create and share

Optional:
  --confirm         Actually perform the outward-facing call (default: dry-run, no network
                     mutation); requires --name or --project
  --to ID           Create mode only: collaborator person id (GET /v1/people); required only
                     when this brain has more than one connection
  --force           Bind mode only: overwrite an existing .sapience/project.json bound to a
                     different project

Exit codes:
  0 - dry-run printed, the share/link succeeded and .sapience/project.json was written, or the
      link route returned 404 (written locally only; the server does not read it yet)
  1 - bad arguments, unresolvable repo toplevel, no token, curl/network failure, non-JSON
      response, invalid key/repo value, --project matching zero or more than one row, an
      existing conflicting link without --force
  2 - the server reported a failure-shaped response (create mode: non-2xx status, empty 'to',
      missing 'ok: true'; bind mode: the link route returned 403, or any other non-2xx/non-404
      outcome)
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --name)
      [ "$#" -ge 2 ] || { echo "sapience-project-bind.sh: --name requires a value" >&2; exit 1; }
      NAME="$2"; shift 2 ;;
    --project)
      [ "$#" -ge 2 ] || { echo "sapience-project-bind.sh: --project requires a value" >&2; exit 1; }
      PROJECT_VALUE="$2"; shift 2 ;;
    --confirm)
      CONFIRM="true"; shift ;;
    --to)
      [ "$#" -ge 2 ] || { echo "sapience-project-bind.sh: --to requires a value" >&2; exit 1; }
      TO_OVERRIDE="$2"; shift 2 ;;
    --force)
      FORCE="true"; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "sapience-project-bind.sh: unknown flag: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [ -n "$NAME" ] && [ -n "$PROJECT_VALUE" ]; then
  echo "sapience-project-bind.sh: --name and --project are mutually exclusive (create mode vs. bind mode) -- never silently preferring one" >&2
  exit 1
fi

if [ "$CONFIRM" = "true" ] && [ -z "$NAME" ] && [ -z "$PROJECT_VALUE" ]; then
  echo "sapience-project-bind.sh: --confirm requires --name (create mode) or --project (bind mode); neither was given" >&2
  exit 1
fi

if [ -n "$NAME" ]; then
  MODE="create"
elif [ -n "$PROJECT_VALUE" ]; then
  MODE="bind"
else
  MODE="pick"
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

# --- Derive project.key from --name as a slug (create mode only): lowercase, non-alphanumeric
# runs -> single hyphen, trimmed of leading/trailing hyphens, validated against the same
# repo-name-shaped pattern the server's own key convention expects. ---
if [ "$MODE" = "create" ]; then
  project_key="$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  if [ -z "$project_key" ] || ! [[ "$project_key" =~ $REPO_NAME_RE ]]; then
    echo "sapience-project-bind.sh: --name \"$NAME\" produced an invalid project key \"$project_key\" (expected ${REPO_NAME_RE}) -- refusing before any write" >&2
    exit 1
  fi
fi

sapience_api_init || exit 1

# --- fetch_project_rows -- GET /v1/people/projects and echo the caller's accepted-or-owned row
# set as a compact JSON array on stdout. Shared by pick mode (lists every row) and bind mode
# (matches --project against this same row set).
#
# The REAL response shape is `{ok, candidates, shared, received, invites, ...}` -- never
# `{projects: [...]}` and never a bare array. The row set is `shared + received`, filtered to
# `accepted or owner`.
#
# MUST NOT reintroduce the `has("projects")` / bare-array idiom: it is WRONG for this endpoint
# and resolves to `[]` against the real shape. Two call sites elsewhere in this extension already
# use that wrong idiom -- sapience-publish.sh's `ko` subcommand and sapience-vault-read.sh's
# `notes_cid` resolution -- both OUT OF THIS TASK'S TERRITORY and deliberately left as a named
# follow-up rather than fixed here; do not copy their expression into this file.
#
# Returns 1 with a stderr message on a transport failure, an empty response, or a non-JSON body.
fetch_project_rows() {
  local _fpr_response _fpr_rows
  _fpr_response="$(sapience_get "/v1/people/projects")" || return 1
  if [ -z "$_fpr_response" ] || ! echo "$_fpr_response" | jq -e . >/dev/null 2>&1; then
    echo "sapience-project-bind.sh: non-JSON or empty response from GET /v1/people/projects" >&2
    return 1
  fi
  _fpr_rows="$(echo "$_fpr_response" | jq -c '(.shared // []) + (.received // []) | map(select(.accepted or .owner))' 2>/dev/null)" || {
    echo "sapience-project-bind.sh: could not extract rows from GET /v1/people/projects" >&2
    return 1
  }
  printf '%s' "$_fpr_rows"
  unset _fpr_response _fpr_rows
  return 0
}

# --- write_link_file <cid> <display-name> <repo-slug> -- the SOLE writer of
# .sapience/project.json on every path (create, bind-success, bind-404, and -- when vendor
# delegation is added in a later phase -- its read-back normalization too). Writes EXACTLY three
# string keys, in order project/name/repo, 2-space indent, one trailing newline --
# byte-identical to repo_link.py's link_text() serializer. Echoes the written path on stdout. ---
write_link_file() {
  local _wlf_cid="$1" _wlf_name="$2" _wlf_repo="$3" _wlf_dir _wlf_file
  _wlf_dir="${repo_toplevel}/.sapience"
  mkdir -p "$_wlf_dir"
  _wlf_file="${_wlf_dir}/project.json"
  jq -n \
    --arg project "$_wlf_cid" \
    --arg name "$_wlf_name" \
    --arg repo "$_wlf_repo" \
    '{project: $project, name: $name, repo: $repo}' > "$_wlf_file"
  printf '%s' "$_wlf_file"
  unset _wlf_cid _wlf_name _wlf_repo _wlf_dir _wlf_file
}

# --- print_bind_role_note <owner-bool> -- the caller's role on the bound project determines
# where their Sapience notes land, derived from the picked row's own `owner` flag (no extra
# call): the CREATOR's notes flow to the collaborator without a per-note confirm (follow:true,
# per the mechanical note above); a non-creator ACCEPTED MEMBER's notes land as suggestions only
# the project's author sees until confirmed. Printed on the bind success path and the 404 path
# -- both write the file, so both are a "binding to someone else's project" decision worth
# surfacing. ---
print_bind_role_note() {
  local _pbrn_owner="${1:-false}"
  if [ "$_pbrn_owner" = "true" ]; then
    echo "sapience-project-bind.sh: you are this project's creator -- your notes flow to the collaborator." >&2
  else
    echo "sapience-project-bind.sh: you are an accepted member, not the creator -- your notes land as suggestions only the project's author sees until confirmed." >&2
  fi
  unset _pbrn_owner
}

# --- Pick mode (no --name, no --project): list the caller's accepted and owned projects and
# exit non-zero, writing and POSTing nothing. ---
if [ "$MODE" = "pick" ]; then
  pick_rows="$(fetch_project_rows)" || exit 1
  pick_count="$(echo "$pick_rows" | jq 'length' 2>/dev/null)" || pick_count=0
  if [ -z "$pick_count" ] || [ "$pick_count" = "0" ]; then
    echo "sapience-project-bind.sh: you are not on any shared project yet (GET /v1/people/projects returned no accepted/owned rows); create one with --name instead" >&2
    exit 1
  fi
  echo "$pick_rows" | jq -r '
    .[] | (.title // .project.name // .id // "(untitled)") + "  (" + (.id // "") + ")  [" +
    (if .owner then "creator" else "member" end) + "]"'
  exit 1
fi

# --- Bind mode (--project <name|id>): resolve the value to exactly one accepted-or-owned row,
# case-insensitively against id, title, and project.key, then register this repository with it
# through POST /v1/people/projects/<cid>/link (D1/D2). ---
if [ "$MODE" = "bind" ]; then
  bind_rows="$(fetch_project_rows)" || exit 1
  bind_needle="$(echo "$PROJECT_VALUE" | tr '[:upper:]' '[:lower:]')"
  bind_matches="$(echo "$bind_rows" | jq -c --arg needle "$bind_needle" '
    map(select(
      ((.id // "") | ascii_downcase) == $needle or
      ((.title // "") | ascii_downcase) == $needle or
      ((.project.key // "") | ascii_downcase) == $needle
    ))' 2>/dev/null)" || bind_matches="[]"
  bind_match_count="$(echo "$bind_matches" | jq 'length' 2>/dev/null)" || bind_match_count=0
  if [ "$bind_match_count" != "1" ]; then
    echo "sapience-project-bind.sh: --project \"$PROJECT_VALUE\" matched ${bind_match_count} project(s) (expected exactly 1) -- run with no arguments to list the caller's accepted and owned projects and pick one unambiguously" >&2
    exit 1
  fi
  bind_cid="$(echo "$bind_matches" | jq -r '.[0].id // empty')"
  bind_display_name="$(echo "$bind_matches" | jq -r '.[0].title // .[0].project.name // .[0].id // empty')"
  bind_owner="$(echo "$bind_matches" | jq -r '.[0].owner // false')"
  if [ -z "$bind_cid" ]; then
    echo "sapience-project-bind.sh: --project \"$PROJECT_VALUE\" resolved to a row with no usable id -- refusing before any write" >&2
    exit 1
  fi

  bind_link_file="${repo_toplevel}/.sapience/project.json"

  # Existing-link guard: a prior binding to a DIFFERENT project is never silently replaced.
  # Checked before any dry-run print or POST, on both postures, since it is about whether this
  # invocation should proceed at all, not only about the write itself.
  if [ -f "$bind_link_file" ] && [ "$FORCE" != "true" ]; then
    bind_existing_cid="$(jq -r '.project // empty' "$bind_link_file" 2>/dev/null)" || bind_existing_cid=""
    if [ -n "$bind_existing_cid" ] && [ "$bind_existing_cid" != "$bind_cid" ]; then
      echo "sapience-project-bind.sh: ${bind_link_file} is already bound to a different project (${bind_existing_cid}) -- re-run with --force to overwrite it with \"$bind_display_name\" (${bind_cid}); refusing before any write" >&2
      exit 1
    fi
  fi

  bind_link_payload="$(jq -n --arg repo "$repo_slug" '{repo: $repo}')"

  # --- Bind-mode dry-run posture (default, no --confirm): print the literal link payload and
  # exit 0 WITHOUT POSTing. One deliberate asymmetry from create-mode dry-run (D2): the
  # fetch_project_rows() GET above already fired -- a read, not a mutation -- while create-mode
  # dry-run makes no network call at all. ---
  if [ "$CONFIRM" != "true" ]; then
    echo "sapience-project-bind.sh: DRY-RUN -- pass --confirm to actually link this repository to \"$bind_display_name\" (${bind_cid}) (no POST made; the GET /v1/people/projects lookup above already fired)" >&2
    SAPIENCE_DRY_RUN=1 sapience_post "/v1/people/projects/${bind_cid}/link" "$bind_link_payload"
    exit 0
  fi

  echo "sapience-project-bind.sh: linking this repository to \"$bind_display_name\" (${bind_cid})..." >&2
  # NOT `bind_response="$(sapience_post ...)"`: command substitution forks a subshell, so
  # sapience_api_post_http_status -- a plain (non-local) global assignment inside sapience_post,
  # meant to reach the caller -- never crosses back out and reads as empty here, silently
  # defeating the status-only branch below. Redirecting stdout to a temp file instead keeps the
  # call in THIS shell, so the assignment lands where this script can read it.
  bind_response_tmp="$(mktemp)" || { echo "sapience-project-bind.sh: FAILED -- could not create a temp file for the link response" >&2; exit 2; }
  sapience_post "/v1/people/projects/${bind_cid}/link" "$bind_link_payload" > "$bind_response_tmp"
  bind_post_rc=$?
  bind_response="$(cat "$bind_response_tmp" 2>/dev/null)"
  rm -f "$bind_response_tmp"
  [ "$bind_post_rc" -eq 0 ] || exit 1

  # MUST NOT: bind_cid is the PICKED ROW's own id, captured above before this POST. The link
  # response's own `project` field, when present, is the {kind, key, name} descriptor dict --
  # NEVER a channel cid, unlike the share response's `.share.id` read in the create path below.
  # Nothing in this branch reads a cid out of $bind_response; classification below is by HTTP
  # status only, never by parsing response or vendor prose.
  case "${sapience_api_post_http_status:-}" in
    2??)
      if [ -z "$bind_response" ] || ! echo "$bind_response" | jq -e . >/dev/null 2>&1; then
        echo "sapience-project-bind.sh: FAILED -- non-JSON or empty response from POST /v1/people/projects/${bind_cid}/link: ${bind_response:0:300}" >&2
        exit 2
      fi
      bind_ok="$(echo "$bind_response" | jq -r '.ok // false' 2>/dev/null)" || bind_ok="false"
      if [ "$bind_ok" != "true" ]; then
        echo "sapience-project-bind.sh: FAILED -- link route returned ok=${bind_ok}: ${bind_response:0:300}" >&2
        exit 2
      fi
      bind_written_file="$(write_link_file "$bind_cid" "$bind_display_name" "$repo_slug")"
      print_bind_role_note "$bind_owner"
      echo "sapience-project-bind.sh: linked and registered with \"$bind_display_name\" (${bind_cid}); wrote ${bind_written_file}" >&2
      echo "sapience-project-bind.sh: commit this file: ${bind_written_file}"
      exit 0
      ;;
    404)
      bind_written_file="$(write_link_file "$bind_cid" "$bind_display_name" "$repo_slug")"
      print_bind_role_note "$bind_owner"
      echo "sapience-project-bind.sh: the server did not accept the link (HTTP 404 from the link route) and does not read this file yet -- binding recorded locally only; wrote ${bind_written_file}" >&2
      echo "sapience-project-bind.sh: commit this file: ${bind_written_file}"
      exit 0
      ;;
    403)
      echo "sapience-project-bind.sh: REFUSED -- join the project first (HTTP 403 from the link route: not an accepted member); wrote nothing" >&2
      exit 2
      ;;
    *)
      echo "sapience-project-bind.sh: FAILED -- POST /v1/people/projects/${bind_cid}/link returned HTTP ${sapience_api_post_http_status:-<none>}: ${bind_response:0:300}" >&2
      exit 2
      ;;
  esac
fi

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

# --- Persist the binding through the SOLE write_link_file() writer (see its own header for the
# exact byte format). ---
link_file="$(write_link_file "$project_cid" "$NAME" "$repo_slug")"

echo "sapience-project-bind.sh: shared \"${NAME}\" with ${to_len} recipient(s); wrote ${link_file}" >&2
echo "sapience-project-bind.sh: commit this file: ${link_file}"
exit 0
