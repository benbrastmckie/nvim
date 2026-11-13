#!/usr/bin/env bash
# verify-sapience-context-scoping.sh - Read-only residual probe for the primary-session
# content-scoping gap on POST /v1/cli/context (the endpoint behind the UserPromptSubmit and
# PreToolUse hooks).
#
# Modeled on verify-sapience-mcp.sh's header/exit-code style. THIS SCRIPT MAKES NO VAULT WRITE
# AND NO LOCAL MUTATION -- it issues two read-shaped POST /v1/cli/context requests (the same
# shape sapience_cli.py's own `hook prompt` handler sends) and compares their responses. A
# "residual holds" result (project still ignored) is the EXPECTED, green state today -- that is
# not a failure of this probe, it is confirmation of the measured gap documented in
# context/project/sapience/domain/injection-site-scoping.md. The day the vendor ask in that file
# lands, this probe's "residual lifted" outcome is what detects it, rather than the gap being
# assumed closed or re-discovered by accident.
#
# Usage: verify-sapience-context-scoping.sh [--print] [--help]
#
# Options:
#   --print   Also print the returned `text` block from the real-project call, so a reader can
#             confirm the channel still delivers content (not only that project= is ignored).
#   --help    Show this help message.
#
# Config resolution (mirrors ~/.sapience/sapience_cli.py's config() function exactly):
#   SAPIENCE_HOST env, else ~/.sapience/config.json's .host, else https://app.spnc.ai.
#   SAPIENCE_TOKEN env, else ~/.sapience/config.json's .token.
#   A missing config file, missing host, or missing token exits with a NAMED reason on stderr
#   and no stack trace (exit 3) -- this is a probe, never a gate anything depends on.
#
# The repository slug sent as the "real project" value is resolved the same way
# sapience-remember.sh resolves it: basename of `git rev-parse --show-toplevel`.
#
# Outcomes (each printed on its own line, exactly one per run):
#   RESIDUAL_HOLDS   - the two calls returned byte-identical text/visible bodies. project= is
#                       still ignored on this endpoint. Exit 0.
#   RESIDUAL_LIFTED  - the two calls returned DIFFERENT text/visible bodies. The vendor ask may
#                       have landed -- see context/project/sapience/domain/injection-site-scoping.md
#                       before relying on this alone. Exit 0 (this is good news, not a failure).
#   INCONCLUSIVE     - a non-200 status, an empty body, or a network failure on either call.
#                       Exit 2. Never asserts RESIDUAL_HOLDS or RESIDUAL_LIFTED on partial data.
#
# Exit codes:
#   0 - a conclusive outcome was reached (RESIDUAL_HOLDS or RESIDUAL_LIFTED)
#   2 - INCONCLUSIVE (non-200, empty body, or network failure)
#   3 - config error: missing config file, missing host, or missing token (named reason on
#       stderr, no stack trace)
#   1 - bad arguments
#
# The token is read into a shell variable once and is passed ONLY in the Authorization header
# built in-process by curl's -H flag. It is never echoed, never written to a file, and never
# included in any error message or --print output below.

set -uo pipefail

PRINT_BLOCK="false"

usage() {
  cat >&2 <<'USAGE'
Usage: verify-sapience-context-scoping.sh [--print] [--help]

Read-only probe: replays the two-call POST /v1/cli/context "project" comparison and reports
one of RESIDUAL_HOLDS, RESIDUAL_LIFTED, or INCONCLUSIVE. Makes no vault write and no local
mutation.

Options:
  --print   Also print the real-project call's returned text block (evidence the channel still
            delivers content).
  --help    Show this help message.

Exit codes:
  0 - conclusive outcome reached (RESIDUAL_HOLDS or RESIDUAL_LIFTED)
  2 - INCONCLUSIVE (non-200, empty body, or network failure)
  3 - config error (missing config file, host, or token)
  1 - bad arguments
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --print)
      PRINT_BLOCK="true"; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "verify-sapience-context-scoping.sh: unknown flag: $1" >&2
      usage
      exit 1 ;;
  esac
done

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"

# --- Repo slug (same resolution as sapience-remember.sh: basename of git toplevel) ---
repo_toplevel="$(git -C "${PROJECT_ROOT:-.}" rev-parse --show-toplevel 2>/dev/null)" || repo_toplevel=""
if [ -z "$repo_toplevel" ]; then
  repo_toplevel="$(git rev-parse --show-toplevel 2>/dev/null)" || repo_toplevel=""
fi
if [ -z "$repo_toplevel" ]; then
  echo "verify-sapience-context-scoping.sh: could not resolve a git toplevel (run from inside a git repository)" >&2
  exit 3
fi
repo_slug="$(basename "$repo_toplevel")"
if [ -z "$repo_slug" ]; then
  echo "verify-sapience-context-scoping.sh: empty repo slug resolved from $repo_toplevel" >&2
  exit 3
fi

# --- Config resolution (mirrors sapience_cli.py's config() precedence exactly) ---
CONFIG_FILE="${HOME}/.sapience/config.json"

if [ -z "${SAPIENCE_HOST:-}" ] && [ ! -f "$CONFIG_FILE" ]; then
  echo "verify-sapience-context-scoping.sh: no config file at $CONFIG_FILE and SAPIENCE_HOST not set" >&2
  exit 3
fi

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
  echo "verify-sapience-context-scoping.sh: no Sapience token resolved (SAPIENCE_TOKEN env or ${CONFIG_FILE}'s .token)" >&2
  exit 3
fi

# --- The probe request shape, mirroring sapience_cli.py's `hook prompt` handler's own body
# exactly (event, session_id, level, view_lines, prompt, project). VIS_LINES there is 15. ---
PROMPT_TEXT="What is the current state of the roadmap, open tasks, and any recent decisions about Sapience scoping?"
SENTINEL_PROJECT="zzz-nonexistent-sentinel-project-probe"

post_context() {
  # $1 = project value, $2 = session_id suffix
  local project="$1" sid="$2" body
  body="$(jq -n \
    --arg event "prompt" \
    --arg session_id "verify-sapience-context-scoping-${sid}" \
    --arg level "rich" \
    --argjson view_lines 15 \
    --arg prompt "$PROMPT_TEXT" \
    --arg project "$project" \
    '{event: $event, session_id: $session_id, level: $level, view_lines: $view_lines, prompt: $prompt, project: $project}')"

  curl -sS --connect-timeout 3 --max-time 8 \
    -w '\n%{http_code}' \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer ${sapience_token}" \
    -H 'User-Agent: verify-sapience-context-scoping.sh/1' \
    --data "$body" \
    "${sapience_host}/v1/cli/context" 2>/dev/null
}

raw_real="$(post_context "$repo_slug" "real")" || raw_real=""
http_real="${raw_real##*$'\n'}"
body_real="${raw_real%$'\n'*}"

raw_sentinel="$(post_context "$SENTINEL_PROJECT" "sentinel")" || raw_sentinel=""
http_sentinel="${raw_sentinel##*$'\n'}"
body_sentinel="${raw_sentinel%$'\n'*}"

# --- Inconclusive gate: either call must be a 200 with a non-empty, JSON-parseable body. ---
inconclusive="false"
reason=""

if [ -z "$raw_real" ] || [ "$http_real" != "200" ]; then
  inconclusive="true"; reason="real-project call: http=${http_real:-none} (network failure or non-200)"
elif ! echo "$body_real" | jq -e . >/dev/null 2>&1; then
  inconclusive="true"; reason="real-project call: non-JSON body"
fi

if [ "$inconclusive" = "false" ]; then
  if [ -z "$raw_sentinel" ] || [ "$http_sentinel" != "200" ]; then
    inconclusive="true"; reason="sentinel call: http=${http_sentinel:-none} (network failure or non-200)"
  elif ! echo "$body_sentinel" | jq -e . >/dev/null 2>&1; then
    inconclusive="true"; reason="sentinel call: non-JSON body"
  fi
fi

if [ "$inconclusive" = "true" ]; then
  echo "INCONCLUSIVE -- ${reason}"
  exit 2
fi

text_real="$(echo "$body_real" | jq -r '.text // ""')"
visible_real="$(echo "$body_real" | jq -r '.visible // ""')"
text_sentinel="$(echo "$body_sentinel" | jq -r '.text // ""')"
visible_sentinel="$(echo "$body_sentinel" | jq -r '.visible // ""')"

if [ "$text_real" = "$text_sentinel" ] && [ "$visible_real" = "$visible_sentinel" ]; then
  echo "RESIDUAL_HOLDS -- project= is still ignored on POST /v1/cli/context (real project '${repo_slug}' and sentinel project both returned byte-identical text/visible bodies)"
  if [ "$PRINT_BLOCK" = "true" ]; then
    echo ""
    echo "--- returned text block (real-project call; evidence the channel still delivers content) ---"
    echo "$text_real"
  fi
  exit 0
else
  echo "RESIDUAL_LIFTED -- the real-project and sentinel-project calls returned DIFFERENT text/visible bodies. The vendor ask in context/project/sapience/domain/injection-site-scoping.md may have landed -- re-verify before relying on this alone (a single differing call is not proof of a hard pre-filter)."
  if [ "$PRINT_BLOCK" = "true" ]; then
    echo ""
    echo "--- returned text block (real-project call) ---"
    echo "$text_real"
    echo ""
    echo "--- returned text block (sentinel-project call) ---"
    echo "$text_sentinel"
  fi
  exit 0
fi
