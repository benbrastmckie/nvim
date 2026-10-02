#!/usr/bin/env bash
# zotero-write.sh - Write operations via Zotero Web API through zot
#
# Category A: CLI Wrapper
#
# Usage:
#   zotero-write.sh <operation> <key> [options...]
#
# Operations:
#   note-add KEY "text"                     - Add note to item
#   tag-add KEY TAG                         - Add tag to item
#   tag-remove KEY TAG                      - Remove tag from item
#   attach-file KEY FILEPATH                - Upload file as child attachment
#   item-add --pdf PATH [--doi DOI]         - Create a NEW Zotero item (+ PDF attachment via
#                                              `zot add --pdf`, single atomic call). Unlike every
#                                              other operation above, item-add takes NO existing
#                                              KEY argument -- it creates one. `--doi DOI` is an
#                                              optional companion to `--pdf` (passed through to
#                                              `zot add` alongside `--pdf`); when `--pdf` is
#                                              omitted entirely, `--doi DOI` alone falls back to
#                                              a DOI-only item create with NO attachment -- the
#                                              caller MUST treat that as "no PDF attached" and
#                                              surface it honestly, never as a full success.
#   item-add-json [--record-json JSON]      - Create a NEW Zotero item from a fully-formed JSON
#                                              item body (bare object, or a translation-server
#                                              array -- element 0 is used). Body read from
#                                              --record-json or stdin when omitted. Closes the
#                                              capability gap `zot add` has no answer for: there
#                                              is no JSON-body input anywhere in its option set
#                                              (confirmed via `zot add --help`), so this operation
#                                              POSTs the Zotero Web API's items endpoint directly
#                                              -- the ONE exception to this script's otherwise
#                                              pure `zot`-wrapper (Category A) posture. Like
#                                              item-add, takes NO existing KEY argument.
#
# Options:
#   --dry-run                    - Preview operation; do not execute
#   --idempotency-key KEY        - Idempotency key for attach-file, item-add, and item-add-json
#                                   (item-add-json hashes it into a 32-char hex Zotero-Write-Token)
#   --record-json JSON           - item-add-json only: the item body. Read from stdin when
#                                   omitted (e.g. piped from a translation-server response).
#
# Exit codes:
#   0 - Success (or dry-run preview completed)
#   1 - API error; attachment upload failed; key not found; file not found; empty item-add-json body
#   2 - ZOTERO_API_KEY not set; zot not installed; item-add-json library-ID unresolvable
#
# item-add empirical note: `zot add --pdf`'s exact `data.*` envelope field names (item key,
# attachment key, storage-path) are NOT independently confirmed in this repository -- a live
# call has not yet been made against the production library. `zotero-write.sh` itself does not
# need to parse the envelope (it passes `zot`'s stdout straight through, same as every other
# operation here); the caller (`literature-ingest-online.sh`) is the one that inspects `.data.*`
# and does so defensively across several plausible field-name candidates. See
# `context/project/literature/patterns/zotero-item-creation.md` for the full note and the
# required live-confirmation follow-up.
#
# item-add-json envelope-normalization exception: this is the ONE operation in this script that
# does not simply pass `zot`'s stdout through -- it POSTs the Web API directly (no JSON-body path
# exists in `zot add`) and normalizes the Web API's native `{successful, success, failed}` batch
# response into the SAME `{"ok":…,"data":{"key":…}}` shape every other operation's caller already
# expects, with the full original response nested under `.data.raw`. This keeps
# `extract_envelope_field '.data.key'` working unchanged for every caller. On a non-2xx response,
# or a 2xx whose `.failed` is non-empty, the normalized envelope is `{"ok":false,"error":{…}}`
# carrying the API's own message verbatim -- never a fabricated success. The library ID is
# resolved via a ladder ($ZOT_LIBRARY_ID -> `zot config show`'s "Library ID:" line -> exit 2),
# never hard-coded. See `context/project/literature/patterns/zotero-item-creation.md` for detail.
#
# Environment variables:
#   ZOTERO_API_KEY - Web API key (required for all write operations)
#   ZOT_DATA_DIR   - Path to Zotero data directory

set -euo pipefail

# ---------------------------------------------------------------------------
# Dependency check
# ---------------------------------------------------------------------------

if ! command -v zot &>/dev/null; then
  echo "zotero-write.sh: zot not installed; install via: uv tool install zotero-cli-cc" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# API key check
# ---------------------------------------------------------------------------

if [[ -z "${ZOTERO_API_KEY:-}" ]]; then
  echo "zotero-write.sh: ZOTERO_API_KEY not set; run /zotero --setup or: zot config init" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Path resolution
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ZOTERO_INDEX="$PROJECT_ROOT/specs/zotero-index.json"

# ---------------------------------------------------------------------------
# ZOT_DATA_DIR resolution
# ---------------------------------------------------------------------------

if [[ -z "${ZOT_DATA_DIR:-}" ]] && [[ -f "$ZOTERO_INDEX" ]]; then
  _dir="$(jq -r '.zot_data_dir // empty' "$ZOTERO_INDEX" 2>/dev/null)"
  if [[ -n "$_dir" && -d "$_dir" ]]; then
    export ZOT_DATA_DIR="$_dir"
  fi
fi

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

show_usage() {
  cat >&2 << 'USAGE'
Usage: zotero-write.sh <operation> <key> [options...]
       zotero-write.sh item-add --pdf PATH [--doi DOI] [options...]
       zotero-write.sh item-add-json [--record-json JSON] [options...]
       zotero-write.sh orphan-clean [options...]

Operations:
  note-add KEY "text"          Add note to item KEY
  tag-add KEY TAG              Add tag TAG to item KEY
  tag-remove KEY TAG           Remove tag TAG from item KEY
  attach-file KEY FILEPATH     Upload FILEPATH as child attachment of item KEY
  item-add --pdf PATH          Create a NEW item + PDF attachment (no existing KEY; wraps
                                `zot add --pdf`). Optional `--doi DOI` alongside `--pdf`.
                                `--doi DOI` with no `--pdf` creates a DOI-only item with NO
                                attachment -- honest "no PDF attached" surfacing is the
                                caller's responsibility.
  item-add-json [--record-json JSON]
                                Create a NEW item (no existing KEY) from a fully-formed JSON
                                item body -- POSTs the Zotero Web API directly, since `zot add`
                                has no JSON-body input. Body read from stdin when
                                --record-json is omitted. Accepts a bare item object or a
                                translation-server array (element 0 used). Normalizes the Web
                                API's {successful, success, failed} response into
                                {"ok":true,"data":{"key":...,"raw":...}} on success, or
                                {"ok":false,"error":{...}} (API message verbatim) otherwise.
  orphan-clean                 Delete dead (file-less, no-copy-anywhere) orphaned attachment
                                records via `zot orphans clean --yes` (no existing KEY). Does
                                NOT expose --include-recoverable (that discards the server-side
                                copy too -- an operator action taken manually with `zot`
                                directly). Note: `zot orphans list/clean` read local SQLite, so
                                a Web-API-created orphan is invisible until a desktop sync, and
                                a record never synced to the server returns 'not_found' (remove
                                those from the Zotero desktop instead).

Options:
  --dry-run                    Preview operation without executing
  --idempotency-key VALUE      Idempotency key for attach-file/item-add/item-add-json/
                                orphan-clean (e.g. chunk-KEY-1). For item-add-json, hashed into
                                a 32-char hex Zotero-Write-Token header.
  --record-json JSON           item-add-json only: the item body (stdin used when omitted).

Exit codes:
  0 - Success (or dry-run preview completed)
  1 - API error; file not found; key not found; empty item-add-json body
  2 - ZOTERO_API_KEY not set; zot not installed; item-add-json library-ID unresolvable
USAGE
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

OPERATION="${1:-}"
if [[ -z "$OPERATION" ]]; then
  echo "zotero-write.sh: operation required" >&2
  show_usage
  exit 1
fi
shift

# item-add and item-add-json are CREATE-item operations -- they have no existing KEY to
# require/consume (their first remaining argument is a flag: --pdf/--doi or --record-json).
# -h/--help likewise take no KEY. Every other operation keeps the original mandatory-KEY-
# positional behavior unchanged.
KEY=""
if [[ "$OPERATION" != "-h" ]] && [[ "$OPERATION" != "--help" ]] && [[ "$OPERATION" != "item-add" ]] && [[ "$OPERATION" != "item-add-json" ]]; then
  KEY="${1:-}"
  if [[ -z "$KEY" ]]; then
    echo "zotero-write.sh: KEY argument required for operation: $OPERATION" >&2
    show_usage
    exit 1
  fi
  shift
fi

# Parse remaining args: extract --dry-run, --idempotency-key VALUE, --pdf/--doi (item-add), and
# positional args
DRY_RUN=false
IDEM_KEY=""
PDF_PATH=""
DOI_VAL=""
RECORD_JSON=""
POSITIONAL_ARGS=()

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --idempotency-key)
      if [[ "$#" -lt 2 ]]; then
        echo "zotero-write.sh: --idempotency-key requires a VALUE argument" >&2
        exit 1
      fi
      IDEM_KEY="$2"
      shift 2
      ;;
    --idempotency-key=*)
      IDEM_KEY="${1#--idempotency-key=}"
      shift
      ;;
    --pdf)
      if [[ "$#" -lt 2 ]]; then
        echo "zotero-write.sh: --pdf requires a PATH argument" >&2
        exit 1
      fi
      PDF_PATH="$2"
      shift 2
      ;;
    --pdf=*)
      PDF_PATH="${1#--pdf=}"
      shift
      ;;
    --doi)
      if [[ "$#" -lt 2 ]]; then
        echo "zotero-write.sh: --doi requires a DOI argument" >&2
        exit 1
      fi
      DOI_VAL="$2"
      shift 2
      ;;
    --doi=*)
      DOI_VAL="${1#--doi=}"
      shift
      ;;
    --record-json)
      if [[ "$#" -lt 2 ]]; then
        echo "zotero-write.sh: --record-json requires a JSON argument" >&2
        exit 1
      fi
      RECORD_JSON="$2"
      shift 2
      ;;
    --record-json=*)
      RECORD_JSON="${1#--record-json=}"
      shift
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Operation dispatch
# ---------------------------------------------------------------------------

case "$OPERATION" in

  note-add)
    TEXT="${POSITIONAL_ARGS[0]:-}"
    if [[ -z "$TEXT" ]]; then
      echo "zotero-write.sh: note-add requires a text argument" >&2
      exit 1
    fi
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[dry-run] Would run: zot note $KEY --add \"$TEXT\""
      exit 0
    fi
    if ! zot note "$KEY" --add "$TEXT"; then
      echo "zotero-write.sh: note-add failed for key: $KEY" >&2
      exit 1
    fi
    ;;

  tag-add)
    TAG="${POSITIONAL_ARGS[0]:-}"
    if [[ -z "$TAG" ]]; then
      echo "zotero-write.sh: tag-add requires a TAG argument" >&2
      exit 1
    fi
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[dry-run] Would run: zot tag $KEY --add \"$TAG\""
      exit 0
    fi
    if ! zot tag "$KEY" --add "$TAG"; then
      echo "zotero-write.sh: tag-add failed for key: $KEY, tag: $TAG" >&2
      exit 1
    fi
    ;;

  tag-remove)
    TAG="${POSITIONAL_ARGS[0]:-}"
    if [[ -z "$TAG" ]]; then
      echo "zotero-write.sh: tag-remove requires a TAG argument" >&2
      exit 1
    fi
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[dry-run] Would run: zot tag $KEY --remove \"$TAG\""
      exit 0
    fi
    if ! zot tag "$KEY" --remove "$TAG"; then
      echo "zotero-write.sh: tag-remove failed for key: $KEY, tag: $TAG" >&2
      exit 1
    fi
    ;;

  attach-file)
    FILEPATH="${POSITIONAL_ARGS[0]:-}"
    if [[ -z "$FILEPATH" ]]; then
      echo "zotero-write.sh: attach-file requires a FILEPATH argument" >&2
      exit 1
    fi
    if [[ "$DRY_RUN" == "false" ]] && [[ ! -f "$FILEPATH" ]]; then
      echo "zotero-write.sh: file not found: $FILEPATH" >&2
      exit 1
    fi

    # Build command
    ZOT_CMD=(zot attach "$KEY" --file "$FILEPATH")
    if [[ "$DRY_RUN" == "true" ]]; then
      ZOT_CMD+=(--dry-run)
    fi
    if [[ -n "$IDEM_KEY" ]]; then
      ZOT_CMD+=(--idempotency-key "$IDEM_KEY")
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[dry-run] Would run: ${ZOT_CMD[*]}"
      # Still execute to get dry-run preview from zot itself
    fi

    if ! "${ZOT_CMD[@]}"; then
      echo "zotero-write.sh: attach-file failed for key: $KEY, file: $FILEPATH" >&2
      exit 1
    fi
    ;;

  item-add)
    if [[ -z "$PDF_PATH" ]] && [[ -z "$DOI_VAL" ]]; then
      echo "zotero-write.sh: item-add requires --pdf PATH or --doi DOI" >&2
      exit 1
    fi

    if [[ "$DRY_RUN" == "false" ]] && [[ -n "$PDF_PATH" ]] && [[ ! -f "$PDF_PATH" ]]; then
      echo "zotero-write.sh: file not found: $PDF_PATH" >&2
      exit 1
    fi

    # Build command: --pdf is preferred (single atomic create+attach call); a --doi passed
    # alongside --pdf is forwarded too (zot uses it to corroborate/skip its own DOI-from-PDF
    # extraction). --doi with no --pdf is the item-only fallback (no attachment).
    ZOT_CMD=(zot add)
    if [[ -n "$PDF_PATH" ]]; then
      ZOT_CMD+=(--pdf "$PDF_PATH")
    fi
    if [[ -n "$DOI_VAL" ]]; then
      ZOT_CMD+=(--doi "$DOI_VAL")
    fi
    if [[ -n "$IDEM_KEY" ]]; then
      ZOT_CMD+=(--idempotency-key "$IDEM_KEY")
    fi
    if [[ "$DRY_RUN" == "true" ]]; then
      ZOT_CMD+=(--dry-run)
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[dry-run] Would run: ${ZOT_CMD[*]}"
      # Still execute to get dry-run preview from zot itself
    fi

    if ! "${ZOT_CMD[@]}"; then
      echo "zotero-write.sh: item-add failed (pdf: ${PDF_PATH:-none}, doi: ${DOI_VAL:-none})" >&2
      exit 1
    fi

    if [[ -z "$PDF_PATH" ]] && [[ "$DRY_RUN" == "false" ]]; then
      echo "zotero-write.sh: item-add created item via --doi only -- NO PDF attached (honest surfacing, not a failure)" >&2
    fi
    ;;

  item-add-json)
    # Body from --record-json, else stdin. Reject an empty body with exit 1.
    if [[ -z "$RECORD_JSON" ]]; then
      if [[ -t 0 ]]; then
        echo "zotero-write.sh: item-add-json requires --record-json JSON or JSON on stdin" >&2
        exit 1
      fi
      RECORD_JSON="$(cat)"
    fi
    if [[ -z "$RECORD_JSON" ]]; then
      echo "zotero-write.sh: item-add-json: empty record body" >&2
      exit 1
    fi
    if ! echo "$RECORD_JSON" | jq -e . >/dev/null 2>&1; then
      echo "zotero-write.sh: item-add-json: --record-json is not valid JSON" >&2
      exit 1
    fi

    # Library-ID resolution ladder: $ZOT_LIBRARY_ID -> `zot config show`'s "Library ID:" line ->
    # exit 2 naming both sources. Never hard-coded.
    LIBRARY_ID="${ZOT_LIBRARY_ID:-}"
    if [[ -z "$LIBRARY_ID" ]]; then
      LIBRARY_ID="$(zot config show 2>/dev/null | sed -n 's/^Library ID:[[:space:]]*//p' | head -1)"
    fi
    if [[ -z "$LIBRARY_ID" ]]; then
      echo "zotero-write.sh: item-add-json: could not resolve a Zotero library ID from \$ZOT_LIBRARY_ID or 'zot config show' (no 'Library ID: <id>' line found)" >&2
      exit 2
    fi

    # Normalize: accept a bare item object or a translation-server array (take element 0); strip
    # attachments/notes/key/version (rejected by the Web API on create); wrap in a single-element
    # array (the items endpoint always takes an array).
    ITEM_OBJ="$(echo "$RECORD_JSON" | jq -c 'if type == "array" then .[0] else . end | del(.attachments, .notes, .key, .version)')"
    NORMALIZED_BODY="$(jq -cn --argjson item "$ITEM_OBJ" '[$item]')"

    ZOTERO_ITEMS_URL="https://api.zotero.org/users/${LIBRARY_ID}/items"

    CURL_HEADERS=(-H "Zotero-API-Version: 3" -H "Zotero-API-Key: ${ZOTERO_API_KEY}" -H "Content-Type: application/json")
    WRITE_TOKEN=""
    if [[ -n "$IDEM_KEY" ]]; then
      WRITE_TOKEN="$(printf '%s' "$IDEM_KEY" | sha256sum | cut -c1-32)"
      CURL_HEADERS+=(-H "Zotero-Write-Token: ${WRITE_TOKEN}")
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[dry-run] Would POST: $ZOTERO_ITEMS_URL"
      echo "[dry-run] Headers: Zotero-API-Version: 3, Zotero-API-Key: ***REDACTED***, Content-Type: application/json${WRITE_TOKEN:+, Zotero-Write-Token: $WRITE_TOKEN}"
      echo "[dry-run] Body: $NORMALIZED_BODY"
      exit 0
    fi

    CURL_EXIT=0
    HTTP_RESPONSE="$(curl -sS -w $'\n%{http_code}' -X POST "${CURL_HEADERS[@]}" --data "$NORMALIZED_BODY" "$ZOTERO_ITEMS_URL" 2>/tmp/zotero-write-curl-stderr.$$)" || CURL_EXIT=$?
    CURL_STDERR="$(cat /tmp/zotero-write-curl-stderr.$$ 2>/dev/null || true)"
    rm -f /tmp/zotero-write-curl-stderr.$$

    if [[ "$CURL_EXIT" -ne 0 ]]; then
      jq -cn --arg m "curl failed (exit $CURL_EXIT): $CURL_STDERR" '{ok:false,error:{message:$m}}'
      exit 1
    fi

    HTTP_STATUS="${HTTP_RESPONSE##*$'\n'}"
    RESPONSE_BODY="${HTTP_RESPONSE%$'\n'*}"

    if [[ "$HTTP_STATUS" =~ ^2 ]] && echo "$RESPONSE_BODY" | jq -e . >/dev/null 2>&1; then
      FAILED_COUNT="$(echo "$RESPONSE_BODY" | jq '.failed // {} | length')"
      SUCCESSFUL_COUNT="$(echo "$RESPONSE_BODY" | jq '.successful // {} | length')"
      if [[ "$FAILED_COUNT" -eq 0 ]] && [[ "$SUCCESSFUL_COUNT" -gt 0 ]]; then
        ITEM_KEY="$(echo "$RESPONSE_BODY" | jq -r '.successful | to_entries[0].value.key // empty')"
        if [[ -z "$ITEM_KEY" ]]; then
          ITEM_KEY="$(echo "$RESPONSE_BODY" | jq -r '.success | to_entries[0].value // empty')"
        fi
        jq -cn --arg key "$ITEM_KEY" --argjson raw "$RESPONSE_BODY" '{ok:true,data:{key:$key,raw:$raw}}'
        exit 0
      fi
      # 2xx but .failed is non-empty: surface the API's own message verbatim, never a fabricated
      # success.
      jq -cn --argjson raw "$RESPONSE_BODY" '{ok:false,error:{message:"item creation reported in .failed",failed:($raw.failed // {}),raw:$raw}}'
      exit 1
    fi

    # Non-2xx, or a 2xx with an unparseable body: surface the API's own response verbatim.
    jq -cn --arg status "$HTTP_STATUS" --arg body "$RESPONSE_BODY" '{ok:false,error:{http_status:$status,message:$body}}'
    exit 1
    ;;

  -h|--help)
    show_usage
    exit 0
    ;;

  *)
    echo "zotero-write.sh: unknown operation: $OPERATION" >&2
    show_usage
    exit 1
    ;;

esac
