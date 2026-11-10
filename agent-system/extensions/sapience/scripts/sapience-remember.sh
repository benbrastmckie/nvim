#!/usr/bin/env bash
# sapience-remember.sh - Repo-tagged, explicit Sapience vault write
#
# Usage: sapience-remember.sh --subject S --value V [--predicate P] [--ko-type T]
#                              [--confidence C] [--source-loc L] [--dry-run]
#
# Posts a knowledge object (KO) to POST /ingest-kos whose `provenance` string carries a literal
# "[repo:<slug>]" tag -- the ONLY field per-repo scoping on this vault depends on, since
# `/v1/search`'s `source=` filter matches a substring of `provenance` and nothing else (see
# context/project/sapience/domain/per-repo-scoping.md). The MCP `sapience_remember` tool cannot
# produce a tagged write at all (its provenance string is fixed by the connector with no
# injectable repo marker), which is why this script posts to /ingest-kos directly.
#
# `explicit: true` is set UNCONDITIONALLY on every KO this script writes and is not reachable
# from any flag. Without it, the server's noise gate can discard a realistically-worded note
# while still answering {"ok": true, "written": 0, "gated": 1} -- a success-shaped response that
# makes the loss undetectable from the caller side. This script treats `gated >= 1`, a non-empty
# `set_aside`, and an absent/zero `written` as loud, non-zero-exit failures rather than silent
# successes, so a future gate change cannot reintroduce that silent loss.
#
# THERE IS NO DELETE API (three probed routes on this vault all 404; deletion is web-app-only).
# Every write through this script is therefore PERMANENT, and writes through /ingest-kos bypass
# the vault's `auto_approve: false` review gate entirely (that gate governs only the separate
# transcript-extraction path) -- so every write here is also UNREVIEWED. Sanctioned call site:
# task-boundary postflight, a bounded 3-8-note set per completed task. This script does not
# enforce that bound mechanically; the caller is responsible for keeping to it.
#
# Exit 0 on a genuine written >= 1. Exit non-zero (with a message on stderr naming the
# triggering response field) on: missing/unknown arguments, unresolvable repo slug, no token
# configured, curl failure, non-JSON response, or any of the three silent-loss response shapes
# (gated >= 1; a non-empty set_aside array; written absent or 0).
#
# Credential/host precedence mirrors ~/.sapience/mcp.py exactly: SAPIENCE_HOST env, else
# ~/.sapience/config.json's .host, else the https://app.spnc.ai literal; SAPIENCE_TOKEN env,
# else that file's .token. The token is read into a local variable once and is never echoed,
# printed, logged, or passed to `set -x` -- under --dry-run the printed request body redacts it.
#
# The host/token/slug resolution block below is deliberately COPIED from sapience-retrieve.sh,
# not shared via a scripts/lib/ helper -- a shared helper would add a path outside this task's
# declared file_scope. See that script for the duplicated logic's source of truth.

set -euo pipefail

# --- Defaults (mirroring ~/.sapience/mcp.py's own sapience_remember call site) ---
PREDICATE="finding is"
KO_TYPE="insight"
CONFIDENCE="0.8"
SUBJECT=""
VALUE=""
SOURCE_LOC=""
DRY_RUN="false"

usage() {
  cat >&2 <<'USAGE'
Usage: sapience-remember.sh --subject S --value V [--predicate P] [--ko-type T]
                             [--confidence C] [--source-loc L] [--dry-run]

Required:
  --subject S       KO subject
  --value V         KO object_value (the finding text)

Optional:
  --predicate P     default: "finding is"
  --ko-type T       default: "insight"
  --confidence C    default: 0.8
  --source-loc L    optional source_loc field
  --dry-run         print the request body (token redacted) and exit 0 without a request

Exit codes:
  0 - written >= 1 (or --dry-run)
  1 - bad arguments, unresolvable repo slug, no token, curl/network failure, non-JSON response
  2 - the server reported a silent-loss response shape (gated, set_aside, or written == 0)
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --subject)
      [ "$#" -ge 2 ] || { echo "sapience-remember.sh: --subject requires a value" >&2; exit 1; }
      SUBJECT="$2"; shift 2 ;;
    --value)
      [ "$#" -ge 2 ] || { echo "sapience-remember.sh: --value requires a value" >&2; exit 1; }
      VALUE="$2"; shift 2 ;;
    --predicate)
      [ "$#" -ge 2 ] || { echo "sapience-remember.sh: --predicate requires a value" >&2; exit 1; }
      PREDICATE="$2"; shift 2 ;;
    --ko-type)
      [ "$#" -ge 2 ] || { echo "sapience-remember.sh: --ko-type requires a value" >&2; exit 1; }
      KO_TYPE="$2"; shift 2 ;;
    --confidence)
      [ "$#" -ge 2 ] || { echo "sapience-remember.sh: --confidence requires a value" >&2; exit 1; }
      CONFIDENCE="$2"; shift 2 ;;
    --source-loc)
      [ "$#" -ge 2 ] || { echo "sapience-remember.sh: --source-loc requires a value" >&2; exit 1; }
      SOURCE_LOC="$2"; shift 2 ;;
    --dry-run)
      DRY_RUN="true"; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "sapience-remember.sh: unknown flag: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [ -z "$SUBJECT" ] || [ -z "$VALUE" ]; then
  echo "sapience-remember.sh: --subject and --value are both required" >&2
  exit 1
fi

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1

# --- Repo slug (copied from sapience-retrieve.sh; see that script) ---
repo_toplevel="$(git -C "$PROJECT_ROOT" rev-parse --show-toplevel 2>/dev/null)" || {
  echo "sapience-remember.sh: could not resolve a git toplevel from $PROJECT_ROOT" >&2
  exit 1
}
if [ -z "$repo_toplevel" ]; then
  echo "sapience-remember.sh: could not resolve a git toplevel from $PROJECT_ROOT" >&2
  exit 1
fi
repo_slug="$(basename "$repo_toplevel")"
if [ -z "$repo_slug" ]; then
  echo "sapience-remember.sh: empty repo slug" >&2
  exit 1
fi

# --- Host/token resolution (copied from sapience-retrieve.sh; see that script) ---
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
  echo "sapience-remember.sh: no Sapience token resolved (SAPIENCE_TOKEN env or ~/.sapience/config.json .token)" >&2
  exit 1
fi

# --- provenance: the one field per-repo scoping depends on. Carries the literal "[repo:<slug>]"
# tag plus a human-meaningful remainder naming the writing surface. ---
provenance="[repo:${repo_slug}] via sapience-remember.sh (Claude Code dispatch)"

# --- Build the request body. explicit is set to true unconditionally -- there is no flag that
# can turn it off. ---
body="$(jq -n \
  --arg token "$sapience_token" \
  --arg subject "$SUBJECT" \
  --arg predicate "$PREDICATE" \
  --arg object_value "$VALUE" \
  --arg ko_type "$KO_TYPE" \
  --argjson confidence "$CONFIDENCE" \
  --arg provenance "$provenance" \
  --arg source_loc "$SOURCE_LOC" \
  '{
    token: $token,
    kos: [
      ({
        subject: $subject,
        predicate: $predicate,
        object_value: $object_value,
        ko_type: $ko_type,
        confidence: $confidence,
        provenance: $provenance,
        explicit: true
      } + (if $source_loc != "" then {source_loc: $source_loc} else {} end))
    ],
    source: "sapience-remember.sh"
  }')"

if [ "$DRY_RUN" = "true" ]; then
  echo "$body" | jq '.token = "***REDACTED***"'
  exit 0
fi

encoded_token="$(jq -rn --arg v "$sapience_token" '$v|@uri')"
url="${sapience_host}/ingest-kos?token=${encoded_token}"

response="$(curl -sS --connect-timeout 3 --max-time 8 \
  -H 'content-type: application/json' \
  -H 'X-Sapience-Client: sapience-remember.sh' \
  --data "$body" \
  "$url" 2>/dev/null)" || {
  echo "sapience-remember.sh: curl request to /ingest-kos failed" >&2
  exit 1
}

if [ -z "$response" ] || ! echo "$response" | jq -e . >/dev/null 2>&1; then
  echo "sapience-remember.sh: non-JSON or empty response from /ingest-kos" >&2
  exit 1
fi

# --- Loud-failure interpretation. Checked in the vendor client's own branch order: set_aside
# first, then gated, then written/ok. All three are checked regardless of order so none can be
# silently skipped. ---
set_aside_len="$(echo "$response" | jq '.set_aside // [] | length' 2>/dev/null)" || set_aside_len=0
gated="$(echo "$response" | jq -r '.gated // 0' 2>/dev/null)" || gated=0
written="$(echo "$response" | jq -r '.written // 0' 2>/dev/null)" || written=0
ok="$(echo "$response" | jq -r '.ok // false' 2>/dev/null)" || ok=false

if [ "$set_aside_len" != "0" ] && [ -n "$set_aside_len" ]; then
  why="$(echo "$response" | jq -r '[.set_aside[] | ((.why // "set aside") + " (id " + (.id // "" | tostring) + ")")] | join("; ")' 2>/dev/null)"
  echo "sapience-remember.sh: FAILED -- server returned a non-empty 'set_aside' array (nothing written yet, recoverable in the web app): ${why}" >&2
  exit 2
fi

if [ "$gated" != "0" ] && [ "$gated" != "null" ] && [ -n "$gated" ]; then
  echo "sapience-remember.sh: FAILED -- server returned gated=${gated} (noise filter discarded the note; response ok=${ok} is NOT success here)" >&2
  exit 2
fi

if [ "$written" = "0" ] || [ "$written" = "null" ] || [ -z "$written" ]; then
  echo "sapience-remember.sh: FAILED -- server returned written=${written:-0} (nothing was durably stored)" >&2
  exit 2
fi

if [ "$ok" != "true" ]; then
  echo "sapience-remember.sh: FAILED -- server returned ok=${ok}" >&2
  exit 2
fi

echo "sapience-remember.sh: written=${written} subject=\"${SUBJECT}\" provenance=\"${provenance}\""
exit 0
