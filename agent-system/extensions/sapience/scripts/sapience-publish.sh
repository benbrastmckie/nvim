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

# _sapience_post_capture <path> <body> -- calls sapience_post WITHOUT wrapping it in a command
# substitution. This matters mechanically: `x="$(sapience_post ...)"` forks a subshell for the
# substitution, so sapience_post's `sapience_api_post_http_status` side-channel assignment (set
# "into the caller's shell" per that library's own contract -- true only because the LIBRARY
# FILE is sourced, not subshelled; it says nothing about how the caller invokes the function)
# is lost the instant that subshell exits. Confirmed empirically: a plain bash function setting
# a global inside `$(...)` does not propagate that global to the parent shell. The fix is to
# redirect sapience_post's stdout to a temp file instead -- a redirection on a function call does
# NOT fork a subshell -- then read the file separately. Every call site in this script that needs
# sapience_api_post_http_status afterward MUST go through this helper, never a raw
# `x="$(sapience_post ...)"`. Sets _sapience_captured_response (global, consumed by the caller
# immediately after return) and leaves sapience_api_post_http_status set exactly as
# sapience_post itself would. Returns sapience_post's own return status.
_sapience_post_capture() {
  local _scp_path="$1" _scp_body="$2" _scp_tmp _scp_rc
  _scp_tmp="$(mktemp 2>/dev/null)" || {
    echo "sapience-publish.sh: could not create a temp file for the POST response" >&2
    return 1
  }
  sapience_post "$_scp_path" "$_scp_body" > "$_scp_tmp"
  _scp_rc=$?
  _sapience_captured_response="$(cat "$_scp_tmp" 2>/dev/null)"
  rm -f "$_scp_tmp"
  unset _scp_path _scp_body _scp_tmp
  return $_scp_rc
}

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

# --- DOC_COMMENT_MAX: the server's own comment-length bound (verified against brain_server.py).
# Pre-validated locally to fail fast; the server's own 413 is still handled below as well -- a
# local check is never a substitute for handling the server's own response. ---
DOC_COMMENT_MAX=4000

# _post_comment <slug> <body> [quote] [reply_to] [resolve] -- builds the
# POST /v1/docs/<slug>/comments body as a JSON object via jq, omitting absent optional fields
# rather than sending nulls, and dispatches through sapience_post (or, under dry-run,
# SAPIENCE_DRY_RUN=1 sapience_post) from that ONE payload -- the dry-run print and the confirmed
# write share this single construction site, never a second, divergent preview string.
#
# Loud-failure handling is written against THIS endpoint's own verified 201 shape
# {slug, n, hash, author, at} -- NOT sapience-remember.sh's written/gated/set_aside fields, which
# this response has none of and must never be conflated with. A non-2xx
# sapience_api_post_http_status, or a 2xx body missing hash/n, is a non-zero exit with the
# server's message on stderr.
#
# On dry-run (the caller's DRY_RUN_FLAG != "true" / CONFIRM != "true" distinguishes which), this
# prints the literal payload and returns 0 without a network call. On a confirmed write, prints
# the outcome and returns 0 on success, 1 on a local/transport failure, 2 on a server-reported
# failure shape.
_post_comment() {
  local _slug="$1" _body="$2" _quote="${3:-}" _reply_to="${4:-}" _resolve="${5:-false}"
  local _payload _response _status _hash _n

  if [ "${#_body}" -gt "$DOC_COMMENT_MAX" ]; then
    echo "sapience-publish.sh: comment body is ${#_body} chars, exceeds DOC_COMMENT_MAX (${DOC_COMMENT_MAX}) -- refusing before any write" >&2
    return 1
  fi

  _payload="$(jq -n \
    --arg body "$_body" \
    --arg quote "$_quote" \
    --arg reply_to "$_reply_to" \
    --argjson resolve "$_resolve" \
    '{body: $body}
     + (if $quote != "" then {quote: $quote} else {} end)
     + (if $reply_to != "" then {reply_to: $reply_to} else {} end)
     + (if $resolve then {resolve: true} else {} end)')"

  if [ "$CONFIRM" != "true" ]; then
    echo "sapience-publish.sh: DRY-RUN -- POST /v1/docs/${_slug}/comments (pass --confirm to actually write; no network call made)" >&2
    SAPIENCE_DRY_RUN=1 sapience_post "/v1/docs/${_slug}/comments" "$_payload"
    return 0
  fi

  _sapience_post_capture "/v1/docs/${_slug}/comments" "$_payload" || return 1
  _response="$_sapience_captured_response"
  _status="${sapience_api_post_http_status:-}"

  case "$_status" in
    2??) : ;;
    "")
      echo "sapience-publish.sh: doc-comment: no HTTP status captured from POST /v1/docs/${_slug}/comments" >&2
      return 1
      ;;
    *)
      echo "sapience-publish.sh: doc-comment: FAILED -- POST /v1/docs/${_slug}/comments returned HTTP ${_status}: ${_response:0:300}" >&2
      return 2
      ;;
  esac

  if [ -z "$_response" ] || ! echo "$_response" | jq -e . >/dev/null 2>&1; then
    echo "sapience-publish.sh: doc-comment: FAILED -- non-JSON or empty response from POST /v1/docs/${_slug}/comments" >&2
    return 2
  fi

  _hash="$(echo "$_response" | jq -r '.hash // empty' 2>/dev/null)" || _hash=""
  _n="$(echo "$_response" | jq -r '.n // empty' 2>/dev/null)" || _n=""

  if [ -z "$_hash" ] || [ -z "$_n" ]; then
    echo "sapience-publish.sh: doc-comment: FAILED -- a 2xx response missing hash/n is not success-shaped for this endpoint: ${_response:0:300}" >&2
    return 2
  fi

  echo "sapience-publish.sh: doc-comment: written -- slug=${_slug} n=${_n} hash=${_hash}"
  return 0
}

case "$SUBCOMMAND" in
  doc-comment)
    if [ "${#SUBCOMMAND_ARGS[@]}" -eq 0 ]; then
      echo "sapience-publish.sh: doc-comment: a <slug> is required" >&2
      exit 1
    fi
    DC_SLUG="${SUBCOMMAND_ARGS[0]}"
    DC_BODY=""
    DC_QUOTE=""
    DC_REPLY_TO=""
    DC_RESOLVE="false"
    _dc_args=("${SUBCOMMAND_ARGS[@]:1}")
    _i=0
    while [ "$_i" -lt "${#_dc_args[@]}" ]; do
      case "${_dc_args[$_i]}" in
        --body)
          DC_BODY="${_dc_args[$((_i + 1))]:-}"; _i=$((_i + 2)) ;;
        --quote)
          DC_QUOTE="${_dc_args[$((_i + 1))]:-}"; _i=$((_i + 2)) ;;
        --reply-to)
          DC_REPLY_TO="${_dc_args[$((_i + 1))]:-}"; _i=$((_i + 2)) ;;
        --resolve)
          DC_RESOLVE="true"; _i=$((_i + 1)) ;;
        *)
          echo "sapience-publish.sh: doc-comment: unknown flag: ${_dc_args[$_i]}" >&2
          exit 1
          ;;
      esac
    done
    if [ -z "$DC_BODY" ]; then
      echo "sapience-publish.sh: doc-comment: --body is required" >&2
      exit 1
    fi
    sapience_api_init || exit 1
    _post_comment "$DC_SLUG" "$DC_BODY" "$DC_QUOTE" "$DC_REPLY_TO" "$DC_RESOLVE"
    exit $?
    ;;
  doc-version)
    # --- DOC_SLUG_RE / DOC_BODY_MAX: the server's own pre-validation bounds (verified against
    # brain_server.py). Pre-validated locally to fail fast; the server's own 400/413 are still
    # handled below too -- local validation is never a substitute for handling the server's own
    # response. ---
    DOC_SLUG_RE='^[a-z0-9][a-z0-9._-]{0,79}$'
    DOC_BODY_MAX=200000

    if [ "${#SUBCOMMAND_ARGS[@]}" -eq 0 ]; then
      echo "sapience-publish.sh: doc-version: a <slug> is required" >&2
      exit 1
    fi
    DV_SLUG="${SUBCOMMAND_ARGS[0]}"
    DV_BODY_FILE=""
    DV_TITLE=""
    _dv_args=("${SUBCOMMAND_ARGS[@]:1}")
    _i=0
    while [ "$_i" -lt "${#_dv_args[@]}" ]; do
      case "${_dv_args[$_i]}" in
        --body-file)
          DV_BODY_FILE="${_dv_args[$((_i + 1))]:-}"; _i=$((_i + 2)) ;;
        --title)
          DV_TITLE="${_dv_args[$((_i + 1))]:-}"; _i=$((_i + 2)) ;;
        *)
          echo "sapience-publish.sh: doc-version: unknown flag: ${_dv_args[$_i]}" >&2
          exit 1
          ;;
      esac
    done

    if [ -z "$DV_BODY_FILE" ]; then
      echo "sapience-publish.sh: doc-version: --body-file is required" >&2
      exit 1
    fi
    if ! [[ "$DV_SLUG" =~ $DOC_SLUG_RE ]]; then
      echo "sapience-publish.sh: doc-version: slug \"${DV_SLUG}\" does not match ${DOC_SLUG_RE} -- refusing before any network call" >&2
      exit 1
    fi
    if [ ! -f "$DV_BODY_FILE" ]; then
      echo "sapience-publish.sh: doc-version: --body-file \"${DV_BODY_FILE}\" does not exist" >&2
      exit 1
    fi
    DV_BODY="$(cat "$DV_BODY_FILE")"
    if [ "${#DV_BODY}" -gt "$DOC_BODY_MAX" ]; then
      echo "sapience-publish.sh: doc-version: body is ${#DV_BODY} chars, exceeds DOC_BODY_MAX (${DOC_BODY_MAX}) -- refusing before any network call" >&2
      exit 1
    fi

    sapience_api_init || exit 1

    # --- Always fetch the doc's OWN current `rev` immediately before writing, and send THAT as
    # base_rev -- never a caller-supplied value, which could race stale. This is the single most
    # consequential correctness property of this subcommand (Decision/Research Integration
    # finding 2): _docs_save compares base_rev against doc_rev(prev); base_hash is only a
    # secondary fallback, and omitting base_rev does NOT skip the check. sapience_get is called
    # directly here (not through _sapience_post_capture, which is POST-only) -- this call's own
    # HTTP status is not consumed, only the body's .rev, so the ordinary $(...) form is safe
    # here (no sapience_api_post_http_status side-channel is needed from a GET). ---
    DV_GET_RESPONSE="$(sapience_get "/v1/docs/${DV_SLUG}")" || exit 1
    if [ -z "$DV_GET_RESPONSE" ] || ! echo "$DV_GET_RESPONSE" | jq -e . >/dev/null 2>&1; then
      echo "sapience-publish.sh: doc-version: non-JSON or empty response from GET /v1/docs/${DV_SLUG} -- cannot resolve base_rev, refusing to write" >&2
      exit 1
    fi
    DV_BASE_REV="$(echo "$DV_GET_RESPONSE" | jq -r '.rev // empty' 2>/dev/null)" || DV_BASE_REV=""
    if [ -z "$DV_BASE_REV" ]; then
      echo "sapience-publish.sh: doc-version: GET /v1/docs/${DV_SLUG} response carried no rev -- cannot resolve base_rev, refusing to write: ${DV_GET_RESPONSE:0:300}" >&2
      exit 1
    fi

    # base_rev's JSON type is never assumed (the server may use a numeric counter or an opaque
    # string token) -- coerced to a number only when the fetched value parses as one, else kept
    # as a JSON string, so this never sends base_rev as a quoted number when the server expects
    # a bare integer, nor crashes `--argjson` on a non-numeric token.
    DV_BASE_REV_JSON="$(jq -n --arg v "$DV_BASE_REV" '$v | (try tonumber catch $v)' 2>/dev/null)" || DV_BASE_REV_JSON="\"${DV_BASE_REV}\""

    DV_PAYLOAD="$(jq -n \
      --arg body "$DV_BODY" \
      --argjson base_rev "$DV_BASE_REV_JSON" \
      --arg title "$DV_TITLE" \
      '{body: $body, base_rev: $base_rev} + (if $title != "" then {title: $title} else {} end)')"

    if [ "$CONFIRM" != "true" ]; then
      echo "sapience-publish.sh: DRY-RUN -- POST /v1/docs/${DV_SLUG} (base_rev=${DV_BASE_REV}, the rev just fetched -- pass --confirm to actually write; no write call made, though the GET above DID run to resolve the real base_rev)" >&2
      SAPIENCE_DRY_RUN=1 sapience_post "/v1/docs/${DV_SLUG}" "$DV_PAYLOAD"
      exit 0
    fi

    _sapience_post_capture "/v1/docs/${DV_SLUG}" "$DV_PAYLOAD" || exit 1
    DV_RESPONSE="$_sapience_captured_response"
    DV_STATUS="${sapience_api_post_http_status:-}"

    if [ -z "$DV_STATUS" ]; then
      echo "sapience-publish.sh: doc-version: no HTTP status captured from POST /v1/docs/${DV_SLUG}" >&2
      exit 1
    fi

    # --- Four distinct outcomes, read from sapience_api_post_http_status plus the response
    # body -- one POST, no secondary HTTP call to discover the status. Never conflated: a
    # head_moved conflict and a people_propose alternate path are NOT the same shape, and
    # neither is sapience-remember.sh's written/gated/set_aside shape (that is a different
    # endpoint entirely). ---
    case "$DV_STATUS" in
      409)
        DV_CODE="$(echo "$DV_RESPONSE" | jq -r '.code // empty' 2>/dev/null)" || DV_CODE=""
        if [ "$DV_CODE" = "head_moved" ]; then
          echo "sapience-publish.sh: doc-version: REFUSED -- head_moved (the doc changed since base_rev=${DV_BASE_REV} was fetched; NOTHING WAS WRITTEN; never retried or overwritten automatically). Server's current head:" >&2
          echo "$DV_RESPONSE" | jq -c '.head // {}' >&2 2>/dev/null || echo "${DV_RESPONSE:0:300}" >&2
          exit 2
        fi
        echo "sapience-publish.sh: doc-version: FAILED -- HTTP 409 with unexpected code \"${DV_CODE}\" (nothing written): ${DV_RESPONSE:0:300}" >&2
        exit 2
        ;;
      202)
        echo "sapience-publish.sh: doc-version: proposed, awaiting owner (can_edit:false routed this through people_propose rather than a direct save -- this is NOT \"saved\")"
        exit 0
        ;;
      404)
        DV_CODE="$(echo "$DV_RESPONSE" | jq -r '.code // empty' 2>/dev/null)" || DV_CODE=""
        if [ "$DV_CODE" = "share_gone" ]; then
          echo "sapience-publish.sh: doc-version: REFUSED -- share_gone (a shared-* slug with no existing document cannot be created by this route; nothing was written)" >&2
          exit 2
        fi
        echo "sapience-publish.sh: doc-version: FAILED -- HTTP 404 with unexpected code \"${DV_CODE}\" (nothing written): ${DV_RESPONSE:0:300}" >&2
        exit 2
        ;;
      2??)
        DV_NEW_REV="$(echo "$DV_RESPONSE" | jq -r '.rev // empty' 2>/dev/null)" || DV_NEW_REV=""
        echo "sapience-publish.sh: doc-version: saved -- slug=${DV_SLUG} new_rev=${DV_NEW_REV:-unknown}"
        exit 0
        ;;
      *)
        echo "sapience-publish.sh: doc-version: FAILED -- POST /v1/docs/${DV_SLUG} returned HTTP ${DV_STATUS}: ${DV_RESPONSE:0:300}" >&2
        exit 2
        ;;
    esac
    ;;
  dm)
    DM_TO=""
    DM_BODY=""
    _i=0
    while [ "$_i" -lt "${#SUBCOMMAND_ARGS[@]}" ]; do
      case "${SUBCOMMAND_ARGS[$_i]}" in
        --to)
          DM_TO="${SUBCOMMAND_ARGS[$((_i + 1))]:-}"; _i=$((_i + 2)) ;;
        --body)
          DM_BODY="${SUBCOMMAND_ARGS[$((_i + 1))]:-}"; _i=$((_i + 2)) ;;
        *)
          echo "sapience-publish.sh: dm: unknown flag: ${SUBCOMMAND_ARGS[$_i]}" >&2
          exit 1
          ;;
      esac
    done
    if [ -z "$DM_TO" ] || [ -z "$DM_BODY" ]; then
      echo "sapience-publish.sh: dm: --to and --body are both required" >&2
      exit 1
    fi

    sapience_api_init || exit 1

    DM_DM_PAYLOAD="$(jq -n --arg to "$DM_TO" '{to: $to}')"

    if [ "$CONFIRM" != "true" ]; then
      echo "sapience-publish.sh: DRY-RUN -- dm is two writes; printing both literal payloads in sequence (pass --confirm to actually write; no network call made)" >&2
      echo "sapience-publish.sh: DRY-RUN -- POST /v1/people/dm" >&2
      SAPIENCE_DRY_RUN=1 sapience_post "/v1/people/dm" "$DM_DM_PAYLOAD"
      echo "sapience-publish.sh: DRY-RUN -- POST /v1/docs/<slug>/comments (slug unknown until the DM call above resolves; shown with a placeholder slug; same _post_comment payload-construction path the confirmed write uses -- never a second, divergent preview string)" >&2
      _post_comment "<slug>" "$DM_BODY"
      exit 0
    fi

    _sapience_post_capture "/v1/people/dm" "$DM_DM_PAYLOAD" || exit 1
    DM_RESPONSE="$_sapience_captured_response"
    DM_STATUS="${sapience_api_post_http_status:-}"

    case "$DM_STATUS" in
      201) DM_OUTCOME="new conversation created" ;;
      200) DM_OUTCOME="existing conversation reused" ;;
      2??) DM_OUTCOME="2xx (unexpected status ${DM_STATUS}, treated as success)" ;;
      "")
        echo "sapience-publish.sh: dm: no HTTP status captured from POST /v1/people/dm" >&2
        exit 1
        ;;
      *)
        echo "sapience-publish.sh: dm: FAILED -- POST /v1/people/dm returned HTTP ${DM_STATUS}: ${DM_RESPONSE:0:300} (never reaching the comment POST)" >&2
        exit 2
        ;;
    esac

    if [ -z "$DM_RESPONSE" ] || ! echo "$DM_RESPONSE" | jq -e . >/dev/null 2>&1; then
      echo "sapience-publish.sh: dm: FAILED -- non-JSON or empty response from POST /v1/people/dm (never reaching the comment POST)" >&2
      exit 2
    fi

    DM_SLUG="$(echo "$DM_RESPONSE" | jq -r '.slug // empty' 2>/dev/null)" || DM_SLUG=""
    if [ -z "$DM_SLUG" ]; then
      echo "sapience-publish.sh: dm: FAILED -- POST /v1/people/dm response carried no slug (never reaching the comment POST): ${DM_RESPONSE:0:300}" >&2
      exit 2
    fi

    echo "sapience-publish.sh: dm: ${DM_OUTCOME} (slug=${DM_SLUG})" >&2
    _post_comment "$DM_SLUG" "$DM_BODY"
    exit $?
    ;;
  ko)
    # --- Flag parsing: --note is repeatable (each occurrence is one KO's finding text), and
    # --project overrides runtime key resolution. The existing 3-8-note-per-task bound (owned by
    # the caller, e.g. a future /sapience picker) is the ONLY size bound -- this subcommand adds
    # no second, independently-sized cap of its own (Non-Goals). Each --note becomes one KO's
    # object_value, with subject/predicate/ko_type/confidence defaulted exactly as
    # sapience-remember.sh defaults them (this subcommand's CLI is deliberately simpler than
    # sapience-remember.sh's single-note --subject/--value interface, since --note is meant for
    # the multi-note batch case the plan's Goals describe). ---
    KO_NOTES=()
    KO_PROJECT_OVERRIDE=""
    _i=0
    while [ "$_i" -lt "${#SUBCOMMAND_ARGS[@]}" ]; do
      case "${SUBCOMMAND_ARGS[$_i]}" in
        --note)
          KO_NOTES+=("${SUBCOMMAND_ARGS[$((_i + 1))]:-}"); _i=$((_i + 2)) ;;
        --project)
          KO_PROJECT_OVERRIDE="${SUBCOMMAND_ARGS[$((_i + 1))]:-}"; _i=$((_i + 2)) ;;
        *)
          echo "sapience-publish.sh: ko: unknown flag: ${SUBCOMMAND_ARGS[$_i]}" >&2
          exit 1
          ;;
      esac
    done

    if [ "${#KO_NOTES[@]}" -eq 0 ]; then
      echo "sapience-publish.sh: ko: at least one --note is required" >&2
      exit 1
    fi

    sapience_api_init || exit 1

    # --- Resolve the project KEY at runtime (Decision D5). --project wins; else
    # .sapience/project.json's .project (cid), resolved via the worktree block above; then
    # GET /v1/people/projects, unwrapped with the SAME defensive pattern sapience-vault-read.sh
    # uses for this exact endpoint, matching the binding's cid to recover .key. Refuses loudly
    # (non-zero exit, NOTHING posted) on no binding, a failed list call, or no matching entry --
    # never falls back to an untagged write, and never derives the key from the binding's
    # free-text `name` field. ---
    if [ -n "$KO_PROJECT_OVERRIDE" ]; then
      KO_PROJECT_KEY="$KO_PROJECT_OVERRIDE"
    else
      KO_REPO_TOPLEVEL="$(resolve_checkout_toplevel "$PROJECT_ROOT" 2>/dev/null)" || {
        echo "sapience-publish.sh: ko: could not resolve a git toplevel from ${PROJECT_ROOT} -- refusing to write untagged" >&2
        exit 1
      }
      KO_LINK_FILE="${KO_REPO_TOPLEVEL}/.sapience/project.json"
      KO_BINDING_CID=""
      if [ -f "$KO_LINK_FILE" ] && jq -e . "$KO_LINK_FILE" >/dev/null 2>&1; then
        KO_BINDING_CID="$(jq -r '.project // empty' "$KO_LINK_FILE" 2>/dev/null)" || KO_BINDING_CID=""
      fi
      if [ -z "$KO_BINDING_CID" ]; then
        echo "sapience-publish.sh: ko: no project binding resolved (no --project, and no ${KO_LINK_FILE}) -- refusing to write untagged" >&2
        exit 1
      fi

      KO_PROJECTS_RESPONSE="$(sapience_get "/v1/people/projects")" || exit 1
      if [ -z "$KO_PROJECTS_RESPONSE" ] || ! echo "$KO_PROJECTS_RESPONSE" | jq -e . >/dev/null 2>&1; then
        echo "sapience-publish.sh: ko: non-JSON or empty response from GET /v1/people/projects -- refusing to write untagged" >&2
        exit 1
      fi
      KO_PROJECT_KEY="$(echo "$KO_PROJECTS_RESPONSE" | jq -r --arg cid "$KO_BINDING_CID" '
        (if has("projects") then .projects elif (type == "array") then . else [] end) // [] |
        map(select((.cid // .id // "") == $cid)) | .[0].key // empty
      ' 2>/dev/null)" || KO_PROJECT_KEY=""

      if [ -z "$KO_PROJECT_KEY" ]; then
        echo "sapience-publish.sh: ko: binding cid ${KO_BINDING_CID} did not match any entry in GET /v1/people/projects (or that entry had no key) -- refusing to write untagged" >&2
        exit 1
      fi
    fi

    # --- Build the KOs array: explicit:true unconditionally on every KO (no flag can turn it
    # off, matching sapience-remember.sh), project:"<resolved key>" on every KO, and NEVER
    # project_cid -- the REPO_LINK_FOR path is confirmed dark for this token and _project_stamp
    # would unconditionally overwrite a client-set ko['project'] the day it is ever
    # server-verified, so this subcommand sends only the plain project field (Non-Goals). ---
    KO_NOTES_JSON="$(printf '%s\n' "${KO_NOTES[@]}" | jq -R -s 'split("\n") | map(select(length > 0))')"
    KO_PAYLOAD="$(jq -n \
      --argjson notes "$KO_NOTES_JSON" \
      --arg project "$KO_PROJECT_KEY" \
      '{
        kos: ($notes | map({
          subject: "finding",
          predicate: "finding is",
          object_value: .,
          ko_type: "insight",
          confidence: 0.8,
          project: $project,
          explicit: true
        })),
        source: "sapience-publish.sh"
      }')"

    if [ "$CONFIRM" != "true" ]; then
      echo "sapience-publish.sh: DRY-RUN -- POST /ingest-kos (project=${KO_PROJECT_KEY}, ${#KO_NOTES[@]} note(s) -- pass --confirm to actually write; no network call made)" >&2
      SAPIENCE_DRY_RUN=1 sapience_post "/ingest-kos" "$KO_PAYLOAD"
      exit 0
    fi

    _sapience_post_capture "/ingest-kos" "$KO_PAYLOAD" || exit 1
    KO_RESPONSE="$_sapience_captured_response"

    if [ -z "$KO_RESPONSE" ] || ! echo "$KO_RESPONSE" | jq -e . >/dev/null 2>&1; then
      echo "sapience-publish.sh: ko: non-JSON or empty response from /ingest-kos" >&2
      exit 1
    fi

    # --- Loud-failure interpretation, reused VERBATIM in order and semantics from
    # sapience-remember.sh: set_aside -> gated -> written -> ok, ALL FOUR checked regardless of
    # order so none can be silently skipped. Written against _ingest_kos's verified field set
    # (ok, written, threads, gated, rejected, filtered, plus conditional set_aside/staged) --
    # the dispatch-text paraphrase listing a `spend` field does NOT match this handler; `spend`
    # is /ingest-kos's OWN top-level reply field per the dispatch's write-surface #4 note, never
    # read or checked here because none of the four loud-failure conditions depend on it. ---
    KO_SET_ASIDE_LEN="$(echo "$KO_RESPONSE" | jq '.set_aside // [] | length' 2>/dev/null)" || KO_SET_ASIDE_LEN=0
    KO_GATED="$(echo "$KO_RESPONSE" | jq -r '.gated // 0' 2>/dev/null)" || KO_GATED=0
    KO_WRITTEN="$(echo "$KO_RESPONSE" | jq -r '.written // 0' 2>/dev/null)" || KO_WRITTEN=0
    KO_OK="$(echo "$KO_RESPONSE" | jq -r '.ok // false' 2>/dev/null)" || KO_OK=false

    if [ "$KO_SET_ASIDE_LEN" != "0" ] && [ -n "$KO_SET_ASIDE_LEN" ]; then
      KO_WHY="$(echo "$KO_RESPONSE" | jq -r '[.set_aside[] | ((.why // "set aside") + " (id " + (.id // "" | tostring) + ")")] | join("; ")' 2>/dev/null)"
      echo "sapience-publish.sh: ko: FAILED -- server returned a non-empty 'set_aside' array (nothing written yet, recoverable in the web app): ${KO_WHY}" >&2
      exit 2
    fi

    if [ "$KO_GATED" != "0" ] && [ "$KO_GATED" != "null" ] && [ -n "$KO_GATED" ]; then
      echo "sapience-publish.sh: ko: FAILED -- server returned gated=${KO_GATED} (noise filter discarded the note; response ok=${KO_OK} is NOT success here)" >&2
      exit 2
    fi

    if [ "$KO_WRITTEN" = "0" ] || [ "$KO_WRITTEN" = "null" ] || [ -z "$KO_WRITTEN" ]; then
      echo "sapience-publish.sh: ko: FAILED -- server returned written=${KO_WRITTEN:-0} (nothing was durably stored)" >&2
      exit 2
    fi

    if [ "$KO_OK" != "true" ]; then
      echo "sapience-publish.sh: ko: FAILED -- server returned ok=${KO_OK}" >&2
      exit 2
    fi

    echo "sapience-publish.sh: ko: written=${KO_WRITTEN} project=${KO_PROJECT_KEY}"
    exit 0
    ;;
esac
