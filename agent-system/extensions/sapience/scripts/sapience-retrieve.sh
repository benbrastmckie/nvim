#!/usr/bin/env bash
# sapience-retrieve.sh - Repo-scoped Sapience vault retrieval for dispatch-time context injection
#
# Usage: sapience-retrieve.sh <description> <task_type> [focus_prompt]
#
# Queries GET /v1/search filtered to this repo's tag (embedded in each KO's `provenance` string
# as a literal "[repo:<slug>]" substring, filtered on read via `source=`) and emits the SAME
# <memory-context> envelope every Stage 4a call site's consumer contract expects. Repo-scoping
# works ONLY through that provenance tag; the vault's `project` field is
# a dead end (`/v1/search` silently ignores `&project=`). See
# context/project/sapience/domain/per-repo-scoping.md for the full mechanism, why it is the only
# one that works, and the sibling write path (sapience-remember.sh).
#
# Exit 0 with the envelope on stdout when at least one matching KO survives the token budget.
# Exit 1 (empty stdout) on every BENIGN no-match path: missing args, unresolvable repo slug, no
# keywords extracted, no token configured, zero hits, or zero hits surviving the token budget --
# none of these indicate a problem worth recording, so retrieval degrades silently exactly as
# before.
# Exit 2 (empty stdout, one diagnostic line on stderr) on a GENUINE transport/HTTP failure: a
# curl transport error (connection refused, timeout, DNS failure, ...), a non-2xx HTTP status,
# or a non-JSON response body. This is the split a caller needs to distinguish "nothing matched"
# from "the backend is actually down" -- the stderr line carries the HTTP status (when any) and
# a length-bounded excerpt of the response body, so a diagnostic such as a 503's own
# `{"error": "...", "starting": true, ...}` sentence survives rather than being discarded. A 2xx
# response with a JSON body that merely contains zero hits is NOT this branch -- it stays exit 1,
# so a benign zero-hit search never floods a caller's log.
#
# One bounded retry on the narrow cold-start signal only: when, and only when, a response is
# HTTP 503 with a JSON body carrying `.starting == true` (a strict boolean check, never a truthy
# string), this script sleeps the server's own `retry_after` hint -- clamped into
# [RETRY_DELAY_MIN, RETRY_DELAY_MAX] with RETRY_DELAY_DEFAULT used when the hint is missing or
# non-numeric -- and issues exactly one more request. A second 503 (cold-start or otherwise), any
# 4xx, a non-JSON body, or a curl transport error is never retried and falls through to the same
# unchanged exit-2 diagnostic. Worst-case added wall clock on the cold-start path is therefore
# ~36s (8s first `--max-time` + 20s clamp ceiling + 8s second `--max-time`), versus ~8s on every
# other path; the terminal fail-open degrade (exit 2, caller records non-fatally, proceeds with
# an empty memory_context) is unchanged in every case. No second network call on the non-retried
# success or failure paths: the status is read from the SAME request via `curl --write-out`.
#
# Constants:
#   TOKEN_BUDGET=2000          - Maximum total tokens to include
#   MAX_ENTRIES=5              - Maximum number of entries (also sent as the request's limit=)
#   RETRY_DELAY_DEFAULT=15     - Fallback delay (seconds) when retry_after is missing/non-numeric;
#                                the measured value this vault reports during cold start
#   RETRY_DELAY_MIN=1          - Clamp floor for the honored retry_after hint
#   RETRY_DELAY_MAX=20         - Clamp ceiling for the honored retry_after hint
#
# Credential/host precedence mirrors ~/.sapience/mcp.py exactly: SAPIENCE_HOST env, else
# ~/.sapience/config.json's .host, else the https://app.spnc.ai literal; SAPIENCE_TOKEN env,
# else that file's .token. The token is read into a local variable once and is never echoed,
# printed, logged, or passed to `set -x` -- it appears only inside the URL handed to curl.

set -euo pipefail

# --- Constants ---
TOKEN_BUDGET=2000
MAX_ENTRIES=5
RETRY_DELAY_DEFAULT=15
RETRY_DELAY_MIN=1
RETRY_DELAY_MAX=20

# --- Arguments ---
description="${1:-}"
task_type="${2:-}"
focus_prompt="${3:-}"

if [ -z "$description" ] || [ -z "$task_type" ]; then
  exit 1
fi

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1

# --- Keyword extraction: lowercase, split on non-alpha, stop-word filter, length>3, dedupe,
# top 10 -- self-contained on $combined_text and $STOP_WORDS. ---
combined_text="$description $focus_prompt"

STOP_WORDS="the|a|an|and|or|but|in|on|at|of|to|for|is|are|was|were|be|been|being|have|has|had|do|does|did|will|would|could|should|may|might|can|shall|not|no|with|by|from|as|into|through|during|before|after|above|below|between|out|off|over|under|again|further|then|once|here|there|when|where|why|how|all|both|each|few|more|most|other|some|such|only|own|same|so|than|too|very|just|about|up|its|it|this|that|these|those|what|which|who|whom"

keywords=$(echo "$combined_text" | \
  tr '[:upper:]' '[:lower:]' | \
  tr -cs '[:alpha:]' '\n' | \
  grep -v -E "^($STOP_WORDS)$" | \
  awk 'length > 3' | \
  sort -u | \
  head -10 | \
  tr '\n' ' ' | \
  sed 's/ *$//')

if [ -z "$keywords" ]; then
  exit 1
fi

# --- Repo slug: basename of the git toplevel, so the same script works unmodified in every repo
# the system deploys into ---
repo_toplevel="$(git -C "$PROJECT_ROOT" rev-parse --show-toplevel 2>/dev/null)" || exit 1
if [ -z "$repo_toplevel" ]; then
  exit 1
fi
repo_slug="$(basename "$repo_toplevel")"
if [ -z "$repo_slug" ]; then
  exit 1
fi

# --- Host/token resolution (mirrors ~/.sapience/mcp.py's own precedence) ---
CONFIG_FILE="${HOME}/.sapience/config.json"

sapience_host="${SAPIENCE_HOST:-}"
if [ -z "$sapience_host" ] && [ -f "$CONFIG_FILE" ]; then
  sapience_host="$(jq -r '.host // empty' "$CONFIG_FILE" 2>/dev/null)" || sapience_host=""
fi
[ -z "$sapience_host" ] && sapience_host="https://app.spnc.ai"
sapience_host="${sapience_host%/}"

sapience_token="${SAPIENCE_TOKEN:-}"
if [ -z "$sapience_token" ] && [ -f "$CONFIG_FILE" ]; then
  sapience_token="$(jq -r '.token // empty' "$CONFIG_FILE" 2>/dev/null)" || sapience_token=""
fi
if [ -z "$sapience_token" ]; then
  exit 1
fi

# --- Build and issue the request. URL-encode the bracketed repo-tag filter (rather than relying
# on the measured bracket-free substring form, which would also match a longer slug sharing this
# one's prefix) and the query keywords. ---
encoded_q="$(jq -rn --arg v "$keywords" '$v|@uri')"
encoded_source="$(jq -rn --arg v "[repo:${repo_slug}]" '$v|@uri')"
encoded_token="$(jq -rn --arg v "$sapience_token" '$v|@uri')"

url="${sapience_host}/v1/search?q=${encoded_q}&source=${encoded_source}&limit=${MAX_ENTRIES}&token=${encoded_token}"

# --- Single request, extracted into a function so the bounded cold-start retry below can
# invoke it a second time without duplicating the curl call. --write-out appends the HTTP status
# as a trailing line (never a second network call per invocation), and curl's own -S diagnostic
# is captured to a scratch file rather than discarded, so the genuine-failure branch can report
# it. Sets response_raw, curl_exit, curl_stderr. ---
issue_request() {
  local stderr_file
  stderr_file="$(mktemp 2>/dev/null)" || stderr_file="/dev/null"
  curl_exit=0
  response_raw="$(curl -sS --connect-timeout 3 --max-time 8 -H 'X-Sapience-Client: sapience-retrieve.sh' -w $'\n%{http_code}' "$url" 2>"$stderr_file")" || curl_exit=$?
  curl_stderr=""
  [ "$stderr_file" != "/dev/null" ] && curl_stderr="$(cat "$stderr_file" 2>/dev/null || true)"
  [ "$stderr_file" != "/dev/null" ] && rm -f "$stderr_file"
}

issue_request

if [ "$curl_exit" -ne 0 ]; then
  echo "sapience-retrieve.sh: genuine transport failure (curl exit ${curl_exit}): ${curl_stderr:0:300}" >&2
  exit 2
fi

http_status="${response_raw##*$'\n'}"
response="${response_raw%$'\n'*}"

# --- Bounded cold-start retry: fires only when this exact response is a 503 whose body parses
# as JSON with a strict-boolean `.starting == true` -- never a plain 503, a 4xx, a non-JSON
# body, or a curl transport error (already exited above). Exactly one retry; the second
# response's transport check and status/body split are re-applied below, then both the
# no-retry and post-retry paths fall through to the SAME case block. ---
if [ "$http_status" = "503" ] && [ -n "$response" ] && \
   echo "$response" | jq -e . >/dev/null 2>&1 && \
   echo "$response" | jq -e '.starting == true' >/dev/null 2>&1; then
  retry_after_raw="$(echo "$response" | jq -r '.retry_after // empty' 2>/dev/null)" || retry_after_raw=""
  if [[ "$retry_after_raw" =~ ^[0-9]+$ ]]; then
    retry_delay="$retry_after_raw"
  else
    retry_delay="$RETRY_DELAY_DEFAULT"
  fi
  if [ "$retry_delay" -lt "$RETRY_DELAY_MIN" ]; then
    retry_delay="$RETRY_DELAY_MIN"
  elif [ "$retry_delay" -gt "$RETRY_DELAY_MAX" ]; then
    retry_delay="$RETRY_DELAY_MAX"
  fi

  echo "sapience-retrieve.sh: cold start (HTTP 503, starting=true) -- retrying once after ${retry_delay}s (server-hinted, clamped to [${RETRY_DELAY_MIN}, ${RETRY_DELAY_MAX}])" >&2
  sleep "$retry_delay"
  issue_request

  if [ "$curl_exit" -ne 0 ]; then
    echo "sapience-retrieve.sh: genuine transport failure (curl exit ${curl_exit}): ${curl_stderr:0:300}" >&2
    exit 2
  fi

  http_status="${response_raw##*$'\n'}"
  response="${response_raw%$'\n'*}"
fi

case "$http_status" in
  2??)
    : # proceed to the JSON/hit-extraction path below
    ;;
  *)
    echo "sapience-retrieve.sh: genuine failure -- HTTP ${http_status}: ${response:0:300}" >&2
    exit 2
    ;;
esac

if [ -z "$response" ] || ! echo "$response" | jq -e . >/dev/null 2>&1; then
  echo "sapience-retrieve.sh: genuine failure -- non-JSON body (HTTP ${http_status}): ${response:0:300}" >&2
  exit 2
fi

# --- Normalize the hit list: a "results" array when present, else the bare top-level array,
# else nothing (mirrors the vendor client's own `r.get('results', r) or []` defensive read). ---
hits="$(echo "$response" | jq -c '
  (if has("results") then .results elif (type == "array") then . else [] end) // [] |
  map(select((.subject // "") != "" or (.object_value // "") != ""))
' 2>/dev/null)" || hits=""

if [ -z "$hits" ] || [ "$hits" = "[]" ] || [ "$hits" = "null" ]; then
  exit 1
fi

# --- Greedy selection within the token budget. Each hit's cost is estimated from its rendered
# text length (~4 chars/token) since there is no local token_count field to read. ---
selected="$(echo "$hits" | jq --argjson budget "$TOKEN_BUDGET" --argjson max "$MAX_ENTRIES" '
  map(
    . as $k |
    ((($k.subject // "") + " " + ($k.predicate // "") + " " + ($k.object_value // "")) | length) as $chars |
    ($k + {_tc: (($chars / 4) | ceil)})
  ) |
  reduce .[] as $entry (
    {selected: [], total_tokens: 0, count: 0};
    if .count < $max and (.total_tokens + $entry._tc) <= $budget then
      .selected += [$entry] |
      .total_tokens += $entry._tc |
      .count += 1
    else .
    end
  ) | .selected
' 2>/dev/null)" || selected=""

if [ -z "$selected" ] || [ "$selected" = "[]" ] || [ "$selected" = "null" ]; then
  exit 1
fi

# --- Emit the envelope with real newlines and printf '%s' (never '%b', which would reinterpret
# a literal backslash escape sequence inside server-sourced KO text). ---
output="<memory-context>
The following memories from previous sessions may be relevant to this task.

"

entry_count=0
while IFS= read -r entry_json; do
  subject="$(echo "$entry_json" | jq -r '.subject // ""')"
  predicate="$(echo "$entry_json" | jq -r '.predicate // ""')"
  object_value="$(echo "$entry_json" | jq -r '.object_value // ""')"
  score="$(echo "$entry_json" | jq -r '.score // .relevance // 0')"
  title="$subject"
  [ -z "$title" ] && title="(untitled)"
  body="${predicate}: ${object_value}"
  output="${output}### ${title} (relevance: ${score})
${body}

"
  entry_count=$((entry_count + 1))
done < <(echo "$selected" | jq -c '.[]')

if [ "$entry_count" -eq 0 ]; then
  exit 1
fi

output="${output}</memory-context>"

printf '%s' "$output"
exit 0
