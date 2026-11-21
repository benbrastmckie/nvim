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
#
# PROJECT-KEY RESOLUTION (linked-repo tagging): when this repo carries a `.sapience/project.json`
# binding (written by sapience-project-bind.sh), the KO body additionally carries a plain
# `project: "<key>"` field, resolved at runtime via GET /v1/people/projects -- the SAME shape
# `sapience-publish.sh ko` already implements (its runtime-resolution block and its defensive
# response-unwrapping), copied here rather than extracted to a shared helper for the same
# file_scope reason as the host/token/slug block above. An explicit `--project-key <key>` flag
# short-circuits the GET entirely (consumed by postflight-sapience-notes.sh): the flag wins, then
# the binding file, then nothing.
#
# DEGRADE RULE (deliberately differs from `sapience-publish.sh ko`, which REFUSES to write
# untagged on any resolution failure -- that script serves a human-confirmed single write, where
# refusing and surfacing the error to the person is the right failure mode. This script serves a
# bounded postflight set written non-interactively at task-boundary time, where losing a note
# entirely is the worse failure):
#   - No `.sapience/project.json` at all           -> write UNTAGGED, byte-identical to today.
#   - Binding present but resolution fails (no GET
#     token/host issue aside -- a non-JSON response,
#     no matching entry, or a matching entry with no
#     `key`)                                       -> write UNTAGGED, with a WARNING on stderr.
#   Neither case is ever a refusal, and neither case ever drops the note.
#
# NON-GOAL: `project_cid` is NEVER sent on any call. The REPO_LINK_FOR path that would make the
# server trust a client-supplied cid is confirmed dark for this token, and `_project_stamp` would
# unconditionally overwrite a client-set `ko['project']` the day that path is ever
# server-verified -- so this script sends only the plain `project` (key) field, exactly like
# `sapience-publish.sh ko`, and needs no code change when that flag eventually flips.

set -euo pipefail

# --- Defaults (mirroring ~/.sapience/mcp.py's own sapience_remember call site) ---
PREDICATE="finding is"
KO_TYPE="insight"
CONFIDENCE="0.8"
SUBJECT=""
VALUE=""
SOURCE_LOC=""
DRY_RUN="false"
PROJECT_KEY_OVERRIDE=""

usage() {
  cat >&2 <<'USAGE'
Usage: sapience-remember.sh --subject S --value V [--predicate P] [--ko-type T]
                             [--confidence C] [--source-loc L] [--project-key K] [--dry-run]

Required:
  --subject S       KO subject
  --value V         KO object_value (the finding text)

Optional:
  --predicate P     default: "finding is"
  --ko-type T       default: "insight"
  --confidence C    default: 0.8
  --source-loc L    optional source_loc field
  --project-key K   short-circuits runtime project-key resolution (wins over any
                     .sapience/project.json binding; no GET /v1/people/projects made)
  --dry-run         print the request body (token redacted) and exit 0 without a request

Project tagging: with no .sapience/project.json binding and no --project-key, the body carries
no `project` field at all (byte-identical to pre-tagging behavior). With a binding (or
--project-key) but resolution fails, the body still carries no `project` field, and a warning is
printed to stderr -- this never refuses and never drops the note. `project_cid` is never sent.

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
    --project-key)
      [ "$#" -ge 2 ] || { echo "sapience-remember.sh: --project-key requires a value" >&2; exit 1; }
      PROJECT_KEY_OVERRIDE="$2"; shift 2 ;;
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

# --- Repo slug: basename of the parent checkout's git toplevel (copied from
# sapience-retrieve.sh; see that script). This is the WRITE side -- an untreated worktree would
# tag a KO `[repo:<throwaway-worktree-name>]`, which neither the checkout's nor the worktree's
# query could ever retrieve, so this resolution must match the read side exactly. ---
repo_toplevel="$(resolve_checkout_toplevel "$PROJECT_ROOT" 2>/dev/null)" || {
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

# --- Project-key resolution (see header: PROJECT-KEY RESOLUTION / DEGRADE RULE). --project-key
# wins outright, with no GET. Otherwise: no $repo_toplevel/.sapience/project.json binding means
# no tag at all (byte-identical to pre-tagging behavior); a binding present triggers
# GET /v1/people/projects, matched against the binding's cid the SAME defensive way
# sapience-publish.sh's ko subcommand does -- but unlike that subcommand, every failure path here
# degrades to an UNTAGGED write with a stderr warning rather than refusing. project_key stays ""
# (never set) on every degrade path; the body-construction step below omits the `project` field
# entirely whenever project_key is empty. ---
project_key=""
if [ -n "$PROJECT_KEY_OVERRIDE" ]; then
  project_key="$PROJECT_KEY_OVERRIDE"
else
  link_file="${repo_toplevel}/.sapience/project.json"
  binding_cid=""
  if [ -f "$link_file" ] && jq -e . "$link_file" >/dev/null 2>&1; then
    binding_cid="$(jq -r '.project // empty' "$link_file" 2>/dev/null)" || binding_cid=""
  fi
  if [ -n "$binding_cid" ]; then
    encoded_token_for_get="$(jq -rn --arg v "$sapience_token" '$v|@uri')"
    projects_url="${sapience_host}/v1/people/projects?token=${encoded_token_for_get}"
    projects_response="$(curl -sS --connect-timeout 3 --max-time 8 \
      -H 'X-Sapience-Client: sapience-remember.sh' \
      "$projects_url" 2>/dev/null)" || projects_response=""
    if [ -z "$projects_response" ] || ! echo "$projects_response" | jq -e . >/dev/null 2>&1; then
      echo "sapience-remember.sh: WARNING -- non-JSON or empty response from GET /v1/people/projects; writing untagged" >&2
    else
      project_key="$(echo "$projects_response" | jq -r --arg cid "$binding_cid" '
        (if has("projects") then .projects elif (type == "array") then . else [] end) // [] |
        map(select((.cid // .id // "") == $cid)) | .[0].key // empty
      ' 2>/dev/null)" || project_key=""
      if [ -z "$project_key" ]; then
        echo "sapience-remember.sh: WARNING -- binding cid ${binding_cid} did not match any entry in GET /v1/people/projects (or that entry had no key); writing untagged" >&2
      fi
    fi
  fi
fi

# --- Build the request body. explicit is set to true unconditionally -- there is no flag that
# can turn it off. project_cid is NEVER sent (see header Non-Goal). ---
body="$(jq -n \
  --arg token "$sapience_token" \
  --arg subject "$SUBJECT" \
  --arg predicate "$PREDICATE" \
  --arg object_value "$VALUE" \
  --arg ko_type "$KO_TYPE" \
  --argjson confidence "$CONFIDENCE" \
  --arg provenance "$provenance" \
  --arg source_loc "$SOURCE_LOC" \
  --arg project "$project_key" \
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
      } + (if $source_loc != "" then {source_loc: $source_loc} else {} end)
        + (if $project != "" then {project: $project} else {} end))
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
