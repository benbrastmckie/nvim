#!/usr/bin/env bash
# sapience-vault-read.sh - Read-only aggregator: local repo state plus the vault's shared state,
# in one pinned JSON envelope on stdout, for the as-yet-unwritten /sapience draft-assembly
# consumer. So a draft can respond to a collaborator's latest rather than talk past it.
#
# Usage: sapience-vault-read.sh [--since <git-ref>] [--update-cursor] [--project <cid>]
#
# Performs NO writes except the explicit, opt-in cursor update (--update-cursor only). Every
# other invocation is a pure read: local git/specs inspection plus a bounded set of authenticated
# GETs through sapience-api-lib.sh's sapience_get (never an ad hoc curl, and never an MCP write
# tool -- rules/sapience-write-path.md).
#
# ENVELOPE CONTRACT (the hand-off interface for the future draft-assembly consumer; pinned here,
# not re-derived by that consumer):
#   {
#     "schema": "sapience-vault-read/1",
#     "generated_at": "<ISO8601>",
#     "repo": {"toplevel", "name", "binding"},
#     "local": {"git": {"since", "log", "diff_stat"}, "state", "events", "errors", "sessions"},
#     "vault": {"projects", "docs", "doc_bodies", "doc_comments", "project_notes",
#               "suggestions", "notifications"},
#     "errors": [{"source", "message"}]
#   }
# Every `vault.*` key is `null` when its source failed, with the reason recorded in the
# top-level `errors[]` array (never the `local.errors` field, which is reserved for the local
# `specs/central-errors.jsonl` tail -- a deliberately different thing with the same English word).
#
# Cursor handling: `--since <git-ref>` wins; else `.sapience/last-read.json`'s recorded commit;
# else a bounded default (the last 20 commits, or everything if the repo has fewer). Only
# `--update-cursor` writes `.sapience/last-read.json` -- an ordinary read never mutates the repo.
#
# Vault-side GETs, every one through sapience_get: GET /v1/people/projects, GET /v1/docs,
# GET /v1/docs/<slug>?versions=1 (per unread doc, bounded), GET /v1/docs/<slug>/comments (same
# bound), GET /v1/people/projects/<cid>/notes, GET /v1/people/projects/suggestions,
# GET /v1/notifications.
#
# Failure posture: a single failing TOP-LEVEL source (projects, docs, project_notes,
# suggestions, notifications -- the five independently resolvable vault GETs) records into
# `errors[]` and leaves its `vault.*` key `null`, never aborting the whole read. `doc_bodies` and
# `doc_comments` are PER-DOC follow-ons to a successful `docs` fetch (bounded to
# MAX_DOC_FETCH unread docs); an individual doc's body/comments failure is recorded into
# `errors[]` too, but does not itself count toward the all-failed exit test below, since it
# cannot even be attempted when `docs` itself already failed.
#
# Exit codes:
#   0 - at least one of the five top-level vault sources succeeded (or none were attempted
#       because the token/host could not resolve is instead exit 1 below)
#   1 - no Sapience token/host could be resolved at all (an environment error, not a partial
#       outage)
#   2 - every one of the five top-level vault sources failed (indicates a broken host/token,
#       not a partial outage)
#
# No reference, anywhere in this file (including --help text), to sapience_remember /
# sapience_wrapup / sapience_handoff / sapience_adddoc as a write path.

set -uo pipefail

MAX_DOC_FETCH=10
DEFAULT_LOG_COUNT=20

SINCE_ARG=""
UPDATE_CURSOR="false"
PROJECT_CID_ARG=""

usage() {
  cat >&2 <<'USAGE'
Usage: sapience-vault-read.sh [--since <git-ref>] [--update-cursor] [--project <cid>]

Optional:
  --since REF       Git ref to diff/log from (wins over the recorded cursor)
  --update-cursor   Record the current HEAD as the new cursor in .sapience/last-read.json
                     (the ONLY way this script writes anything; omit it for a pure read)
  --project CID     Project cid to query notes for (wins over .sapience/project.json's binding)

Exit codes:
  0 - at least one of the five top-level vault sources succeeded
  1 - no Sapience token/host could be resolved (environment error)
  2 - every one of the five top-level vault sources failed
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --since)
      [ "$#" -ge 2 ] || { echo "sapience-vault-read.sh: --since requires a value" >&2; exit 1; }
      SINCE_ARG="$2"; shift 2 ;;
    --update-cursor)
      UPDATE_CURSOR="true"; shift ;;
    --project)
      [ "$#" -ge 2 ] || { echo "sapience-vault-read.sh: --project requires a value" >&2; exit 1; }
      PROJECT_CID_ARG="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "sapience-vault-read.sh: unknown flag: $1" >&2
      usage
      exit 1 ;;
  esac
done

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
  echo "sapience-vault-read.sh: could not resolve a git toplevel from $PROJECT_ROOT" >&2
  exit 1
}
if [ -z "$repo_toplevel" ]; then
  echo "sapience-vault-read.sh: could not resolve a git toplevel from $PROJECT_ROOT" >&2
  exit 1
fi
repo_name="$(basename "$repo_toplevel")"

# --- top-level errors[] accumulator: one JSON object per line, assembled into an array at the
# end via `jq -s`. record_error never aborts the script. ---
ERRORS_FILE="$(mktemp 2>/dev/null)" || ERRORS_FILE="/dev/null"
# shellcheck disable=SC2329  # invoked indirectly via `trap cleanup EXIT` below
cleanup() { [ "$ERRORS_FILE" != "/dev/null" ] && rm -f "$ERRORS_FILE"; }
trap cleanup EXIT

record_error() {
  local source="$1" message="$2"
  jq -nc --arg source "$source" --arg message "$message" '{source: $source, message: $message}' >> "$ERRORS_FILE" 2>/dev/null
}

errors_json() {
  if [ -s "$ERRORS_FILE" ]; then
    jq -sc '.' "$ERRORS_FILE" 2>/dev/null || echo '[]'
  else
    echo '[]'
  fi
}

# =====================================================================================
# repo.binding -- read .sapience/project.json if present (never written by this script).
# =====================================================================================
binding_json='null'
link_file="${repo_toplevel}/.sapience/project.json"
if [ -f "$link_file" ] && jq -e . "$link_file" >/dev/null 2>&1; then
  binding_json="$(cat "$link_file")"
fi

# =====================================================================================
# Cursor resolution: --since wins, else .sapience/last-read.json's recorded commit, else a
# bounded default (nothing -- the DEFAULT_LOG_COUNT most recent commits, no diff base).
# =====================================================================================
cursor_file="${repo_toplevel}/.sapience/last-read.json"
since_ref="$SINCE_ARG"
if [ -z "$since_ref" ] && [ -f "$cursor_file" ]; then
  since_ref="$(jq -r '.commit // empty' "$cursor_file" 2>/dev/null)" || since_ref=""
fi
if [ -n "$since_ref" ] && ! git -C "$repo_toplevel" rev-parse --verify --quiet "${since_ref}^{commit}" >/dev/null 2>&1; then
  record_error "git" "recorded/--since ref '${since_ref}' no longer resolves in this repo; falling back to the bounded default"
  since_ref=""
fi

# =====================================================================================
# Local side: git log/diff, specs/state.json, specs/events.jsonl, specs/central-errors.jsonl,
# recent Claude Code session history. All paths resolved relative to repo_toplevel.
# =====================================================================================
if [ -n "$since_ref" ]; then
  git_log_json="$(git -C "$repo_toplevel" log --oneline "${since_ref}..HEAD" 2>/dev/null | jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null)" || git_log_json='[]'
  git_diff_stat="$(git -C "$repo_toplevel" diff --stat "${since_ref}..HEAD" 2>/dev/null)" || git_diff_stat=""
else
  git_log_json="$(git -C "$repo_toplevel" log --oneline -n "$DEFAULT_LOG_COUNT" 2>/dev/null | jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null)" || git_log_json='[]'
  git_diff_stat=""
fi
[ -z "$git_log_json" ] && git_log_json='[]'

git_json="$(jq -nc --arg since "$since_ref" --argjson log "$git_log_json" --arg diff_stat "$git_diff_stat" \
  '{since: (if $since == "" then null else $since end), log: $log, diff_stat: (if $diff_stat == "" then null else $diff_stat end)}')"

state_file="${repo_toplevel}/specs/state.json"
if [ -f "$state_file" ] && jq -e . "$state_file" >/dev/null 2>&1; then
  state_json="$(jq -c '{completed_projects: ((.completed_projects // [])[-20:])}' "$state_file" 2>/dev/null)" || { state_json='null'; record_error "state" "specs/state.json present but failed to parse its completed_projects"; }
else
  state_json='null'
  record_error "state" "specs/state.json not found or not valid JSON at ${state_file}"
fi

events_file="${repo_toplevel}/specs/events.jsonl"
if [ -f "$events_file" ]; then
  events_json="$(tail -n 20 "$events_file" 2>/dev/null | jq -c '.' 2>/dev/null | jq -sc '.' 2>/dev/null)" || events_json='[]'
  [ -z "$events_json" ] && events_json='[]'
else
  events_json='[]'
fi

central_errors_file="${repo_toplevel}/specs/central-errors.jsonl"
if [ -f "$central_errors_file" ]; then
  local_errors_json="$(tail -n 20 "$central_errors_file" 2>/dev/null | jq -c '.' 2>/dev/null | jq -sc '.' 2>/dev/null)" || local_errors_json='[]'
  [ -z "$local_errors_json" ] && local_errors_json='[]'
else
  local_errors_json='[]'
fi

# Recent Claude Code session history: best-effort, never a failure if absent -- the
# ~/.claude/projects/<slugified-toplevel-path>/ convention (slug: '/' -> '-', confirmed against
# this machine's own live tool-results path during this task).
sessions_json='[]'
cc_slug="$(echo "$repo_toplevel" | sed 's/\//-/g')"
cc_sessions_dir="${HOME}/.claude/projects/${cc_slug}"
if [ -d "$cc_sessions_dir" ]; then
  sessions_json="$(
    find "$cc_sessions_dir" -maxdepth 1 -type f -name '*.jsonl' -printf '%T@ %f\n' 2>/dev/null \
      | sort -rn | head -n 10 \
      | awk '{ts=$1; $1=""; sub(/^ /,""); print ts"\t"$0}' \
      | jq -R -s -c '
          split("\n") | map(select(length > 0)) |
          map(split("\t")) |
          map({session_file: .[1], mtime: (.[0] | tonumber | floor)})
        ' 2>/dev/null
  )" || sessions_json='[]'
  [ -z "$sessions_json" ] && sessions_json='[]'
fi

local_json="$(jq -nc --argjson git "$git_json" --argjson state "$state_json" \
  --argjson events "$events_json" --argjson errors "$local_errors_json" --argjson sessions "$sessions_json" \
  '{git: $git, state: $state, events: $events, errors: $errors, sessions: $sessions}')"

# =====================================================================================
# Vault side. Five independently resolvable top-level sources; doc_bodies/doc_comments are
# per-doc follow-ons bounded to MAX_DOC_FETCH unread docs.
# =====================================================================================
if ! sapience_api_init; then
  exit 1
fi

vault_success_count=0

projects_json='null'
_resp="$(sapience_get "/v1/people/projects")"; _rc=$?
if [ "$_rc" -eq 0 ] && [ -n "$_resp" ] && echo "$_resp" | jq -e . >/dev/null 2>&1; then
  projects_json="$_resp"
  vault_success_count=$((vault_success_count + 1))
else
  record_error "projects" "GET /v1/people/projects failed or returned a non-JSON body"
fi

docs_json='null'
_resp="$(sapience_get "/v1/docs")"; _rc=$?
if [ "$_rc" -eq 0 ] && [ -n "$_resp" ] && echo "$_resp" | jq -e . >/dev/null 2>&1; then
  docs_json="$_resp"
  vault_success_count=$((vault_success_count + 1))
else
  record_error "docs" "GET /v1/docs failed or returned a non-JSON body"
fi

# --- doc_bodies / doc_comments: per-doc follow-ons, bounded to MAX_DOC_FETCH docs flagged
# unread in the docs list above -- so the "draft can respond to a collaborator's latest"
# without fetching every doc's full body on every invocation. Only attempted when `docs`
# itself succeeded; an individual doc's failure is recorded but does not count toward the
# all-five-failed exit test (it was never one of the five top-level sources). ---
doc_bodies_json='{}'
doc_comments_json='{}'
if [ "$docs_json" != "null" ]; then
  unread_slugs="$(echo "$docs_json" | jq -r '
    (if has("docs") then .docs elif (type == "array") then . else [] end) // [] |
    map(select(.unread == true)) | .[].slug // empty
  ' 2>/dev/null)"
  bodies_tmp="$(mktemp 2>/dev/null)" || bodies_tmp="/dev/null"
  comments_tmp="$(mktemp 2>/dev/null)" || comments_tmp="/dev/null"
  fetch_count=0
  while IFS= read -r slug; do
    [ -z "$slug" ] && continue
    [ "$fetch_count" -ge "$MAX_DOC_FETCH" ] && break
    fetch_count=$((fetch_count + 1))

    _body_resp="$(sapience_get "/v1/docs/${slug}" "versions=1")"; _body_rc=$?
    if [ "$_body_rc" -eq 0 ] && [ -n "$_body_resp" ] && echo "$_body_resp" | jq -e . >/dev/null 2>&1; then
      jq -nc --arg slug "$slug" --argjson body "$_body_resp" '{($slug): $body}' >> "$bodies_tmp" 2>/dev/null
    else
      record_error "doc_bodies" "GET /v1/docs/${slug}?versions=1 failed or returned a non-JSON body"
    fi

    _comments_resp="$(sapience_get "/v1/docs/${slug}/comments")"; _comments_rc=$?
    if [ "$_comments_rc" -eq 0 ] && [ -n "$_comments_resp" ] && echo "$_comments_resp" | jq -e . >/dev/null 2>&1; then
      jq -nc --arg slug "$slug" --argjson comments "$_comments_resp" '{($slug): $comments}' >> "$comments_tmp" 2>/dev/null
    else
      record_error "doc_comments" "GET /v1/docs/${slug}/comments failed or returned a non-JSON body"
    fi
  done <<< "$unread_slugs"

  if [ -s "$bodies_tmp" ]; then
    doc_bodies_json="$(jq -sc 'add' "$bodies_tmp" 2>/dev/null)" || doc_bodies_json='{}'
  fi
  if [ -s "$comments_tmp" ]; then
    doc_comments_json="$(jq -sc 'add' "$comments_tmp" 2>/dev/null)" || doc_comments_json='{}'
  fi
  [ "$bodies_tmp" != "/dev/null" ] && rm -f "$bodies_tmp"
  [ "$comments_tmp" != "/dev/null" ] && rm -f "$comments_tmp"
fi

# --- project_notes: needs a bound project cid -- --project wins, else .sapience/project.json's
# binding, else the sole entry of /v1/people/projects (never guessed among several). ---
project_notes_json='null'
notes_cid="$PROJECT_CID_ARG"
if [ -z "$notes_cid" ] && [ "$binding_json" != "null" ]; then
  notes_cid="$(echo "$binding_json" | jq -r '.project // empty' 2>/dev/null)"
fi
if [ -z "$notes_cid" ] && [ "$projects_json" != "null" ]; then
  _proj_count="$(echo "$projects_json" | jq -r '
    (if has("projects") then .projects elif (type == "array") then . else [] end) // [] | length
  ' 2>/dev/null)" || _proj_count=0
  if [ "$_proj_count" = "1" ]; then
    notes_cid="$(echo "$projects_json" | jq -r '
      (if has("projects") then .projects elif (type == "array") then . else [] end) // [] | .[0].cid // .[0].id // empty
    ' 2>/dev/null)"
  fi
fi

if [ -n "$notes_cid" ]; then
  _resp="$(sapience_get "/v1/people/projects/${notes_cid}/notes")"; _rc=$?
  if [ "$_rc" -eq 0 ] && [ -n "$_resp" ] && echo "$_resp" | jq -e . >/dev/null 2>&1; then
    project_notes_json="$_resp"
    vault_success_count=$((vault_success_count + 1))
  else
    record_error "project_notes" "GET /v1/people/projects/${notes_cid}/notes failed or returned a non-JSON body"
  fi
else
  record_error "project_notes" "no bound project cid resolved (no --project, no .sapience/project.json binding, and /v1/people/projects did not resolve to exactly one project)"
fi

suggestions_json='null'
_resp="$(sapience_get "/v1/people/projects/suggestions")"; _rc=$?
if [ "$_rc" -eq 0 ] && [ -n "$_resp" ] && echo "$_resp" | jq -e . >/dev/null 2>&1; then
  suggestions_json="$_resp"
  vault_success_count=$((vault_success_count + 1))
else
  record_error "suggestions" "GET /v1/people/projects/suggestions failed or returned a non-JSON body"
fi

notifications_json='null'
_resp="$(sapience_get "/v1/notifications")"; _rc=$?
if [ "$_rc" -eq 0 ] && [ -n "$_resp" ] && echo "$_resp" | jq -e . >/dev/null 2>&1; then
  notifications_json="$_resp"
  vault_success_count=$((vault_success_count + 1))
else
  record_error "notifications" "GET /v1/notifications failed or returned a non-JSON body"
fi

vault_json="$(jq -nc \
  --argjson projects "$projects_json" \
  --argjson docs "$docs_json" \
  --argjson doc_bodies "$doc_bodies_json" \
  --argjson doc_comments "$doc_comments_json" \
  --argjson project_notes "$project_notes_json" \
  --argjson suggestions "$suggestions_json" \
  --argjson notifications "$notifications_json" \
  '{projects: $projects, docs: $docs, doc_bodies: $doc_bodies, doc_comments: $doc_comments,
    project_notes: $project_notes, suggestions: $suggestions, notifications: $notifications}')"

# =====================================================================================
# --update-cursor: the ONLY write this script performs. Records current HEAD.
# =====================================================================================
if [ "$UPDATE_CURSOR" = "true" ]; then
  new_cursor="$(git -C "$repo_toplevel" rev-parse HEAD 2>/dev/null)" || new_cursor=""
  if [ -n "$new_cursor" ]; then
    mkdir -p "${repo_toplevel}/.sapience"
    jq -nc --arg commit "$new_cursor" --arg updated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{commit: $commit, updated_at: $updated_at}' > "$cursor_file"
  fi
fi

# =====================================================================================
# Assemble and emit the pinned envelope.
# =====================================================================================
repo_json="$(jq -nc --arg toplevel "$repo_toplevel" --arg name "$repo_name" --argjson binding "$binding_json" \
  '{toplevel: $toplevel, name: $name, binding: $binding}')"

generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

jq -nc \
  --arg schema "sapience-vault-read/1" \
  --arg generated_at "$generated_at" \
  --argjson repo "$repo_json" \
  --argjson local "$local_json" \
  --argjson vault "$vault_json" \
  --argjson errors "$(errors_json)" \
  '{schema: $schema, generated_at: $generated_at, repo: $repo, local: $local, vault: $vault, errors: $errors}'

if [ "$vault_success_count" -eq 0 ]; then
  exit 2
fi
exit 0
