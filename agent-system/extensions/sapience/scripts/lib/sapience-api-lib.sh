#!/usr/bin/env bash
# sapience-api-lib.sh - Shared host/token resolution and authenticated HTTP helpers for every
# Sapience script in this extension that talks to app.spnc.ai.
#
# This is the extension's first scripts/lib/ file. It deliberately RESOLVES, rather than
# contradicts, sapience-remember.sh's own header note that ITS copy of this same host/token
# resolution logic was forced to stay duplicated by that task's narrower file_scope: this file is
# the shared home that duplication was always meant to converge on, once a task with a wide
# enough file_scope came along to build it. sapience-remember.sh and sapience-retrieve.sh are
# NOT retroactively migrated onto this library by this change -- doing so is out of this task's
# scope -- but every script this task adds (sapience-project-bind.sh, sapience-vault-read.sh)
# sources this file instead of re-deriving the precedence a fourth and fifth time.
#
# Sourced (never executed) by a consumer immediately after its own SCRIPT_DIR bootstrap:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   # shellcheck disable=SC1091
#   source "${SCRIPT_DIR}/lib/sapience-api-lib.sh"
#   sapience_api_init || exit 1
#   body="$(sapience_post "/v1/people/projects/share" "$json_body")" || exit 1
#   response="$(sapience_get "/v1/docs" "limit=50")" || exit 1
#
# CONTRACT:
#   - Sets no shell options of its own (no `set -e`/`-u`/`-o pipefail`) -- sourcing this file
#     must never change the calling script's error-handling behavior. Every function below is
#     written to behave correctly whether or not the caller has `set -e` active.
#   - sapience_api_init MUST be called once, before either HTTP helper, in every consumer. It
#     resolves $sapience_host and $sapience_token into the CALLING SHELL (this file is sourced,
#     not executed in a subshell, so a plain assignment here reaches the caller directly) and
#     returns 1 with a stderr message when no token can be resolved. Neither HTTP helper
#     re-resolves credentials on its own -- they rely on sapience_api_init having already run.
#   - The token is read into sapience_token exactly once, inside sapience_api_init, and is never
#     echoed, printed, or logged by this file. `set -x` is explicitly suppressed (saved and
#     restored) around the one line that reads the token out of config.json, so a caller running
#     under `set -x` cannot leak it into its own trace either (the read line itself is traced in
#     THIS file only if the caller's `set -x` was already active when sourcing began, and even
#     then the printed command is the `jq` invocation, never the resulting value).
#   - Under SAPIENCE_DRY_RUN=1, both sapience_post and sapience_get print what they WOULD send
#     (method, URL, body) with the token redacted, and make no network call at all. Redaction
#     covers both a token carried in a JSON body field (sapience_post, mirroring
#     sapience-remember.sh's `jq '.token = "***REDACTED***"'` pattern) and a token carried as a
#     URL query parameter (sapience_get) -- the URL print redacts it out of the URL itself, not
#     only out of a body that may not exist for a GET.
#   - sapience_get folds in sapience-retrieve.sh's bounded one-retry-on-503-with-`starting:true`
#     cold-start behavior, ONCE, here -- so every consumer's call sites inherit it for free
#     rather than each re-adding the same retry loop.
#
# Credential/host precedence mirrors ~/.sapience/mcp.py exactly (confirmed verbatim at that
# file's lines 42-44 during this task's planning pass): SAPIENCE_HOST env, else
# ~/.sapience/config.json's .host, else the https://app.spnc.ai literal; SAPIENCE_TOKEN env,
# else that same file's .token.
#
# No reference, anywhere in this file, to sapience_remember / sapience_wrapup /
# sapience_handoff / sapience_adddoc as a write path (rules/sapience-write-path.md). This
# library has no write-shaped helper of its own; a future write-path consumer composes its POST
# body and calls sapience_post exactly like any other caller.

# --- Constants (mirrors sapience-retrieve.sh's own cold-start retry constants) ---
SAPIENCE_API_RETRY_DELAY_DEFAULT=15
SAPIENCE_API_RETRY_DELAY_MIN=1
SAPIENCE_API_RETRY_DELAY_MAX=20

# sapience_api_init -- resolves sapience_host and sapience_token into the caller's shell.
# Returns 0 on success (a non-empty token resolved); returns 1 with a stderr message and leaves
# sapience_token empty when no token could be resolved. Idempotent: calling it twice simply
# re-resolves from the same precedence.
sapience_api_init() {
  local _sapience_config_file _sapience_prev_xtrace

  _sapience_config_file="${HOME}/.sapience/config.json"

  sapience_host="${SAPIENCE_HOST:-}"
  if [ -z "$sapience_host" ] && [ -f "$_sapience_config_file" ]; then
    sapience_host="$(jq -r '.host // empty' "$_sapience_config_file" 2>/dev/null)" || sapience_host=""
  fi
  [ -z "$sapience_host" ] && sapience_host="https://app.spnc.ai"
  sapience_host="${sapience_host%/}"

  # Suppress `set -x` around the credential read so the token can never reach a trace, even if
  # the sourcing caller already has `set -x` active. Saved/restored via the shell's own `$-`.
  case "$-" in
    *x*) _sapience_prev_xtrace="1"; set +x ;;
    *) _sapience_prev_xtrace="0" ;;
  esac

  sapience_token="${SAPIENCE_TOKEN:-}"
  if [ -z "$sapience_token" ] && [ -f "$_sapience_config_file" ]; then
    sapience_token="$(jq -r '.token // empty' "$_sapience_config_file" 2>/dev/null)" || sapience_token=""
  fi

  [ "$_sapience_prev_xtrace" = "1" ] && set -x

  unset _sapience_config_file _sapience_prev_xtrace

  if [ -z "$sapience_token" ]; then
    echo "sapience-api-lib.sh: no Sapience token resolved (SAPIENCE_TOKEN env or ~/.sapience/config.json .token)" >&2
    return 1
  fi
  return 0
}

# _sapience_redact_url <url> -- echoes <url> with any `token=...` query-parameter value replaced
# by ***REDACTED***, leaving every other character (including the rest of the query string)
# untouched. Internal helper; never calls `exit`.
_sapience_redact_url() {
  local _url="${1:-}"
  echo "$_url" | sed -E 's/([?&]token=)[^&]*/\1***REDACTED***/'
  unset _url
}

# sapience_post <path> <json-body> -- authenticated POST to <path> (relative, e.g.
# "/v1/people/projects/share") with <json-body> as the request body. The token travels as a URL
# query parameter (matching sapience-remember.sh's own /ingest-kos call convention), never in a
# header. Echoes the raw response body on stdout and returns 0 on a transport success (ANY HTTP
# status -- the caller inspects the body/status itself, matching sapience-remember.sh's own
# curl-exit-only transport check); returns 1 on a genuine curl transport failure with a message
# on stderr. The resolved HTTP status is additionally left in sapience_api_post_http_status (set
# into the CALLER's shell, since this file is sourced, not subshelled) for a caller that needs to
# distinguish a non-2xx status from a 2xx one carrying a failure-shaped body -- captured via
# `curl --write-out` on the SAME request, never a second network call.
#
# Under SAPIENCE_DRY_RUN=1: prints "POST <url-with-redacted-token>" then the body with
# `.token = "***REDACTED***"` merged in (if the body is a JSON object) on stdout, makes no
# network call, leaves sapience_api_post_http_status unset, and returns 0.
sapience_post() {
  local _path="${1:-}" _body="${2:-}"
  local _encoded_token _url _raw _curl_exit _dry_body

  if [ -z "${sapience_token:-}" ]; then
    echo "sapience-api-lib.sh: sapience_post called before sapience_api_init resolved a token" >&2
    unset _path _body
    return 1
  fi

  _encoded_token="$(jq -rn --arg v "$sapience_token" '$v|@uri')"
  _url="${sapience_host}${_path}?token=${_encoded_token}"

  if [ "${SAPIENCE_DRY_RUN:-}" = "1" ]; then
    echo "POST $(_sapience_redact_url "$_url")"
    if [ -n "$_body" ] && echo "$_body" | jq -e 'type == "object"' >/dev/null 2>&1; then
      _dry_body="$(echo "$_body" | jq '. + {token: "***REDACTED***"}' 2>/dev/null)" || _dry_body="$_body"
    else
      _dry_body="$_body"
    fi
    echo "$_dry_body"
    unset _path _body _encoded_token _url _dry_body
    return 0
  fi

  _curl_exit=0
  _raw="$(curl -sS --connect-timeout 3 --max-time 8 \
    -H 'content-type: application/json' \
    -H 'X-Sapience-Client: sapience-api-lib.sh' \
    --data "$_body" \
    -w $'\n%{http_code}' \
    "$_url" 2>/dev/null)" || _curl_exit=$?

  if [ "$_curl_exit" -ne 0 ]; then
    echo "sapience-api-lib.sh: POST ${_path}: curl transport failure (exit ${_curl_exit})" >&2
    unset _path _body _encoded_token _url _raw _curl_exit
    return 1
  fi

  # shellcheck disable=SC2034 # consumed by the sourcing caller, not within this file
  sapience_api_post_http_status="${_raw##*$'\n'}"
  printf '%s' "${_raw%$'\n'*}"
  unset _path _body _encoded_token _url _raw _curl_exit
  return 0
}

# _sapience_get_once <url> -- issues exactly one GET request, setting (into the CALLER's shell,
# since this is called from within sapience_get, not a subshell) sapience_api_curl_exit,
# sapience_api_http_status, and sapience_api_response. --write-out appends the HTTP status as a
# trailing line on the SAME request, never a second network call per invocation. Internal helper.
_sapience_get_once() {
  local _url="$1" _raw _stderr_file
  _stderr_file="$(mktemp 2>/dev/null)" || _stderr_file="/dev/null"
  sapience_api_curl_exit=0
  _raw="$(curl -sS --connect-timeout 3 --max-time 8 \
    -H 'X-Sapience-Client: sapience-api-lib.sh' \
    -w $'\n%{http_code}' "$_url" 2>"$_stderr_file")" || sapience_api_curl_exit=$?
  [ "$_stderr_file" != "/dev/null" ] && rm -f "$_stderr_file"
  sapience_api_http_status="${_raw##*$'\n'}"
  sapience_api_response="${_raw%$'\n'*}"
  unset _url _raw _stderr_file
  return 0
}

# sapience_get <path> [query-string] -- authenticated GET to <path> (relative), optionally with
# an already-encoded <query-string> (e.g. "limit=50&versions=1") appended ahead of the token
# parameter. The token travels as a URL query parameter, URL-encoded via the same
# `jq -rn --arg v "$tok" '$v|@uri'` pattern sapience-retrieve.sh already uses.
#
# Folds in sapience-retrieve.sh's bounded one-retry-on-cold-start behavior: when, and only when,
# a response is HTTP 503 with a JSON body carrying `.starting == true` (a strict boolean check),
# this sleeps the server's own `retry_after` hint -- clamped into
# [SAPIENCE_API_RETRY_DELAY_MIN, SAPIENCE_API_RETRY_DELAY_MAX], with
# SAPIENCE_API_RETRY_DELAY_DEFAULT used when the hint is missing/non-numeric -- and issues exactly
# one more request. A second 503, any 4xx, a non-JSON body, or a curl transport error is never
# retried.
#
# Echoes the raw response body on stdout and returns 0 on ANY HTTP status reached via a
# successful transport (the caller inspects status/body itself); returns 1 on a genuine curl
# transport failure, with a message on stderr.
#
# Under SAPIENCE_DRY_RUN=1: prints "GET <url-with-redacted-token>" on stdout, makes no network
# call, and returns 0 -- the token is redacted OUT OF THE URL itself here, not only out of a
# body, since a GET has no body to redact.
sapience_get() {
  local _path="${1:-}" _query="${2:-}"
  local _encoded_token _url _retry_after_raw _retry_delay

  if [ -z "${sapience_token:-}" ]; then
    echo "sapience-api-lib.sh: sapience_get called before sapience_api_init resolved a token" >&2
    unset _path _query
    return 1
  fi

  _encoded_token="$(jq -rn --arg v "$sapience_token" '$v|@uri')"
  if [ -n "$_query" ]; then
    _url="${sapience_host}${_path}?${_query}&token=${_encoded_token}"
  else
    _url="${sapience_host}${_path}?token=${_encoded_token}"
  fi

  if [ "${SAPIENCE_DRY_RUN:-}" = "1" ]; then
    echo "GET $(_sapience_redact_url "$_url")"
    unset _path _query _encoded_token _url
    return 0
  fi

  _sapience_get_once "$_url"

  if [ "$sapience_api_curl_exit" -ne 0 ]; then
    echo "sapience-api-lib.sh: GET ${_path}: curl transport failure (exit ${sapience_api_curl_exit})" >&2
    unset _path _query _encoded_token _url
    return 1
  fi

  if [ "$sapience_api_http_status" = "503" ] && [ -n "$sapience_api_response" ] && \
     echo "$sapience_api_response" | jq -e . >/dev/null 2>&1 && \
     echo "$sapience_api_response" | jq -e '.starting == true' >/dev/null 2>&1; then
    _retry_after_raw="$(echo "$sapience_api_response" | jq -r '.retry_after // empty' 2>/dev/null)" || _retry_after_raw=""
    if [[ "$_retry_after_raw" =~ ^[0-9]+$ ]]; then
      _retry_delay="$_retry_after_raw"
    else
      _retry_delay="$SAPIENCE_API_RETRY_DELAY_DEFAULT"
    fi
    if [ "$_retry_delay" -lt "$SAPIENCE_API_RETRY_DELAY_MIN" ]; then
      _retry_delay="$SAPIENCE_API_RETRY_DELAY_MIN"
    elif [ "$_retry_delay" -gt "$SAPIENCE_API_RETRY_DELAY_MAX" ]; then
      _retry_delay="$SAPIENCE_API_RETRY_DELAY_MAX"
    fi
    echo "sapience-api-lib.sh: cold start (HTTP 503, starting=true) on GET ${_path} -- retrying once after ${_retry_delay}s" >&2
    sleep "$_retry_delay"
    _sapience_get_once "$_url"
    if [ "$sapience_api_curl_exit" -ne 0 ]; then
      echo "sapience-api-lib.sh: GET ${_path}: curl transport failure on retry (exit ${sapience_api_curl_exit})" >&2
      unset _path _query _encoded_token _url _retry_after_raw _retry_delay
      return 1
    fi
  fi

  printf '%s' "$sapience_api_response"
  unset _path _query _encoded_token _url _retry_after_raw _retry_delay
  return 0
}

# sapience_project_link_read <toplevel> -- resolves <toplevel>/.sapience/project.json, the ONLY
# location sapience-project-bind.sh's write_link_file() ever writes. Echoes the link file's
# compact JSON ({"project":...,"name":...,"repo":...}) on stdout and returns 0 on a valid
# binding. Returns 1 with NO output and NO stderr noise when the file is absent, unreadable, not
# JSON, or fails validation -- a missing or invalid link is the ordinary "no link" case this
# function's every caller treats as a silent fallback, never an error to surface.
#
# Validation mirrors the server's own repo_link.py parse_link() field for field: the parsed JSON
# must be an object carrying EXACTLY the three string keys `project` (cid), `name` (display
# name), `repo` (short name) -- no fourth key of any shape. This exact-three-key check refuses a
# token/key/secret/password-shaped extra key structurally (any such object has 4+ keys, not 3),
# rather than via a separate key-name pattern. `repo` must additionally match
# ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ and must not look path-shaped (contains "/" or ".."), the
# same two checks sapience-project-bind.sh already applies before its own write.
#
# BOUNDARY, stated explicitly rather than left for a future reader to re-derive: this function
# takes an ALREADY-RESOLVED checkout toplevel as its one argument and contains no copy of the
# sapience-worktree-checkout-resolution block nine other call sites in this extension share
# byte-identically (test-sapience-mcp-registration.sh Case 30's lockstep set) -- resolving the
# toplevel is the CALLER's job, same as every other function in this file. It also performs a
# SINGLE-LOCATION lookup only, deliberately NOT repo_link.py's own upward, 40-level find_link()
# walk -- the two agree wherever the link file sits at the repository root, which is the only
# place write_link_file() ever writes it, so the narrower lookup matches what every existing
# write path already relies on.
sapience_project_link_read() {
  local _spl_toplevel="${1:-}" _spl_file _spl_raw _spl_keys _spl_repo

  if [ -z "$_spl_toplevel" ] || [ ! -f "${_spl_toplevel}/.sapience/project.json" ]; then
    unset _spl_toplevel
    return 1
  fi
  _spl_file="${_spl_toplevel}/.sapience/project.json"

  _spl_raw="$(cat "$_spl_file" 2>/dev/null)" || {
    unset _spl_toplevel _spl_file
    return 1
  }
  if [ -z "$_spl_raw" ] || ! echo "$_spl_raw" | jq -e 'type == "object"' >/dev/null 2>&1; then
    unset _spl_toplevel _spl_file _spl_raw
    return 1
  fi

  _spl_keys="$(echo "$_spl_raw" | jq -c '[keys[]] | sort' 2>/dev/null)" || _spl_keys=""
  if [ "$_spl_keys" != '["name","project","repo"]' ]; then
    unset _spl_toplevel _spl_file _spl_raw _spl_keys
    return 1
  fi

  if ! echo "$_spl_raw" | jq -e \
    '(.project | type == "string") and (.name | type == "string") and (.repo | type == "string")' \
    >/dev/null 2>&1; then
    unset _spl_toplevel _spl_file _spl_raw _spl_keys
    return 1
  fi

  _spl_repo="$(echo "$_spl_raw" | jq -r '.repo')"
  if ! [[ "$_spl_repo" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]]; then
    unset _spl_toplevel _spl_file _spl_raw _spl_keys _spl_repo
    return 1
  fi
  case "$_spl_repo" in
    */*|*..*)
      unset _spl_toplevel _spl_file _spl_raw _spl_keys _spl_repo
      return 1
      ;;
  esac

  echo "$_spl_raw" | jq -c '.'
  unset _spl_toplevel _spl_file _spl_raw _spl_keys _spl_repo
  return 0
}

# sapience_project_link_cid <toplevel> -- convenience wrapper over sapience_project_link_read for
# a caller that only needs the project cid, so it does not re-parse the JSON at its own call
# site. Echoes just the `project` field on stdout and returns 0 on a valid binding; returns 1
# with no output under the exact same no-link/invalid-link cases sapience_project_link_read
# rejects (see that function's own contract above for the full list).
sapience_project_link_cid() {
  local _spc_toplevel="${1:-}" _spc_link

  _spc_link="$(sapience_project_link_read "$_spc_toplevel")" || {
    unset _spc_toplevel _spc_link
    return 1
  }
  echo "$_spc_link" | jq -r '.project'
  unset _spc_toplevel _spc_link
  return 0
}
