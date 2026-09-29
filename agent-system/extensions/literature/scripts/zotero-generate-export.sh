#!/usr/bin/env bash
# zotero-generate-export.sh - Assisted generation of $LITERATURE_DIR/zotero-library.json
# (Better CSL JSON shape) from the user's LOCAL Zotero installation. No network calls other
# than to the LOCAL Zotero HTTP endpoints on 127.0.0.1 -- there is no "cloud" fallback.
#
# USAGE:
#   zotero-generate-export.sh [--output PATH] [--orchestrator-mode true|false] [--force]
#
# DESCRIPTION:
#   Tries three fallback paths, in preference order, to reconstruct a Better CSL JSON
#   export equivalent to Zotero's File -> Export Library -> "Better CSL JSON" feature:
#
#     Path 1 (preferred, Zotero running, no plugin required):
#       Zotero 7's built-in local HTTP API at
#       http://127.0.0.1:23119/api/users/0/items?format=csljson, paginated.
#
#     Path 2 (enrichment, requires Zotero running + Better BibTeX plugin):
#       Better BibTeX JSON-RPC at http://localhost:23119/better-bibtex/json-rpc,
#       item.citationkey(itemKeys) -- backfills the real "citation-key" field for items
#       pulled via Path 1 (plain Zotero CSL-JSON has no citation-key; that field is a
#       Better-BibTeX-specific addition).
#
#     Path 3 (fallback, Zotero CLOSED -- the sqlite file is locked while Zotero runs):
#       Direct read of the resolved Zotero sqlite file (see ZOTERO_SQLITE_PATH below),
#       reconstructing CSL-JSON from items/itemData/itemDataValues/fieldsCombined,
#       itemCreators/creators, and itemAttachments. No citekey table exists in zotero.sqlite
#       (Better BibTeX keeps its own separate database), so citation-key is always
#       synthesized for Path 3 entries.
#
#   Every entry is guaranteed a non-null "citation-key" on output: any item lacking a real
#   Better-BibTeX citekey gets one synthesized deterministically as
#   lower(firstAuthorLast) + year + firstTitleWord, with a numeric suffix appended to
#   disambiguate collisions within the generated set. tier2_search() in
#   literature-discover.sh uses citation-key as doc_id, so a null/duplicate value would
#   break de-duplication downstream.
#
#   A one-time pull via any path is a SNAPSHOT, not Zotero's auto-refreshing "Keep updated"
#   export. A sibling ".zotero-library.meta.json" staleness stamp is written next to the
#   output file recording the generation timestamp, source path, and item count. Re-run
#   this generator (with --force if the output already exists) to refresh the snapshot.
#
# OPTIONS:
#   --output PATH               Output path for zotero-library.json. Defaults to the same
#                                resolve_library_path() order used by zotero-search.sh:
#                                  1. $ZOTERO_LIBRARY
#                                  2. $LITERATURE_DIR/zotero-library.json
#                                  3. ~/Projects/Literature/zotero-library.json
#   --orchestrator-mode true|false
#                                Default false (interactive). When true and no local Zotero
#                                data source is found at all (API unreachable AND no
#                                resolved zotero.sqlite present), emits a visible
#                                "[zotero:auto]" error notice to stderr and exits 1 -- it
#                                NEVER writes a silent empty-but-valid JSON array and NEVER
#                                no-ops silently. The caller is instructed to open Zotero
#                                (or otherwise make a data source available) and re-run.
#   --force                      Regenerate even if the output file already exists
#                                (overwrites the existing snapshot).
#   -h, --help                   Show this help message.
#
# ENVIRONMENT:
#   ZOTERO_LIBRARY      Explicit output path override (tier 1 of resolve_library_path()).
#   LITERATURE_DIR      Global library root (default: ~/Projects/Literature).
#   ZOTERO_SQLITE_PATH  Override for the Path 3 sqlite file. If unset, the sqlite path is
#                       resolved by zotero-resolve-sqlite-path.sh: (1) this env override;
#                       (2) <dataDir>/zotero.sqlite auto-detected from the default Zotero
#                       profile's prefs.js when extensions.zotero.useDataDir=true; (3)
#                       ~/Zotero/zotero.sqlite default.
#
# OUTPUT:
#   stdout: the resolved output path on success (machine-readable).
#   stderr: all diagnostics, rationale, and the manual-fallback instructions.
#
# EXIT CODES:
#   0  Export written successfully via Path 1 or Path 3 (the item array may legitimately be
#      empty if the resolved library itself has zero items -- that is NOT the same as "no
#      data source found").
#   1  No local Zotero data source found at all (API unreachable AND no resolved
#      zotero.sqlite present) -- covers BOTH --orchestrator-mode false (manual-fallback
#      instructions printed to stderr) AND --orchestrator-mode true (loud visible error
#      printed to stderr instructing the user to open Zotero; no output file is written or
#      overwritten in either case).
#   2  Argument error.
#   3  Output file already exists and --force was not given.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not found in PATH" >&2
  exit 1
fi

API_BASE="http://127.0.0.1:23119/api/users/0/items"
BBT_RPC="http://localhost:23119/better-bibtex/json-rpc"
ZOTERO_SQLITE="$("$SCRIPT_DIR/zotero-resolve-sqlite-path.sh")"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

OUTPUT_PATH=""
ORCHESTRATOR_MODE="false"
FORCE="false"

show_usage() {
  cat >&2 << 'USAGE'
USAGE:
  zotero-generate-export.sh [--output PATH] [--orchestrator-mode true|false] [--force]

Generates $LITERATURE_DIR/zotero-library.json (Better CSL JSON) from LOCAL Zotero via
three fallback paths (Zotero 7 local API, Better BibTeX citekey enrichment, direct sqlite
reconstruction). See the header comment in this script for full details.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --output)
      OUTPUT_PATH="${2:-}"
      shift 2
      ;;
    --orchestrator-mode)
      ORCHESTRATOR_MODE="${2:-false}"
      shift 2
      ;;
    --force)
      FORCE="true"
      shift
      ;;
    -h|--help)
      show_usage
      exit 0
      ;;
    *)
      echo "Warning: unrecognized argument '$1' ignored" >&2
      shift
      ;;
  esac
done

if [ "$ORCHESTRATOR_MODE" != "true" ] && [ "$ORCHESTRATOR_MODE" != "false" ]; then
  echo "Error: --orchestrator-mode must be 'true' or 'false', got: $ORCHESTRATOR_MODE" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Resolve output path (mirrors zotero-search.sh's resolve_library_path() order)
# ---------------------------------------------------------------------------
resolve_library_path() {
  if [ -n "${ZOTERO_LIBRARY:-}" ]; then
    echo "$ZOTERO_LIBRARY"
    return
  fi
  if [ -n "${LITERATURE_DIR:-}" ]; then
    echo "${LITERATURE_DIR}/zotero-library.json"
    return
  fi
  echo "${HOME}/Projects/Literature/zotero-library.json"
}

if [ -z "$OUTPUT_PATH" ]; then
  OUTPUT_PATH="$(resolve_library_path)"
fi

META_PATH="$(dirname "$OUTPUT_PATH")/.zotero-library.meta.json"

echo "Rationale: resolved output path to $OUTPUT_PATH (orchestrator-mode=$ORCHESTRATOR_MODE, force=$FORCE)." >&2

if [ -f "$OUTPUT_PATH" ] && [ "$FORCE" != "true" ]; then
  echo "zotero-library.json already exists at $OUTPUT_PATH." >&2
  echo "This generator writes a one-time SNAPSHOT, not an auto-refreshing 'Keep updated' export." >&2
  echo "Pass --force to overwrite it with a freshly generated snapshot." >&2
  exit 3
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"

# ---------------------------------------------------------------------------
# Manual-fallback instructions (mirrors zotero-search.sh lines 143-169 wording)
# ---------------------------------------------------------------------------
manual_fallback_text() {
  cat >&2 << MANUAL

Error: No local Zotero data source found (Zotero API unreachable at $API_BASE and no
zotero.sqlite found at $ZOTERO_SQLITE).

To set up Zotero CSL-JSON export manually instead:

1. Install the Better BibTeX plugin for Zotero:
   https://retorque.re/zotero-better-bibtex/

2. In Zotero, go to:
   File -> Export Library...

3. Choose format: "Better CSL JSON"
   Check "Keep updated" for automatic re-export.

4. Save to one of:
   - The path in \$ZOTERO_LIBRARY environment variable
   - \${LITERATURE_DIR}/zotero-library.json (if \$LITERATURE_DIR is set)
   - ~/Projects/Literature/zotero-library.json (default)

Or set the ZOTERO_LIBRARY environment variable to your export path:
   export ZOTERO_LIBRARY=/path/to/your/library.json

Or, to retry assisted generation instead:
   - Start Zotero (Path 1 pulls your whole library live via the local API), OR
   - Ensure the resolved Zotero sqlite file ($ZOTERO_SQLITE) exists (Path 3 reconstructs a
     snapshot while Zotero is closed -- the sqlite file is locked while Zotero is running).
     If your Zotero uses a custom Data Directory, this is auto-detected from your default
     profile's prefs.js; set \$ZOTERO_SQLITE_PATH to override the resolved path directly.
   Then re-run: zotero-generate-export.sh --output "$OUTPUT_PATH"

MANUAL
}

# ---------------------------------------------------------------------------
# Path 1: Zotero 7 built-in local API (preferred, no plugin required)
# ---------------------------------------------------------------------------
probe_zotero_api() {
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 2 --max-time 3 \
    "${API_BASE}?format=csljson&limit=1" 2>/dev/null)" || code=""
  if [ -z "$code" ]; then
    code="000"
  fi
  echo "$code"
}

fetch_path1() {
  local start=0
  local limit=100
  local total=""
  local page_index=0
  local max_pages=2000
  local tmpdir
  local hdr_file page_file filtered_file http_code url
  local raw_file raw_url raw_http_code excluded_file

  tmpdir="$(mktemp -d)" || {
    echo "fetch_path1: error - mktemp -d failed; aborting, no write." >&2
    return 1
  }
  # Cleans up on every exit path, including an interrupting signal mid-loop. Each controlled
  # return point below ALSO removes tmpdir and clears the trap explicitly, so this is a
  # backstop for INT/TERM, not the only cleanup mechanism.
  trap "rm -rf '$tmpdir'" EXIT INT TERM

  while :; do
    page_file="$tmpdir/page_${page_index}.json"
    url="${API_BASE}?format=csljson&limit=${limit}&start=${start}"

    # Capture response headers only on the first request -- that is the sole place
    # Total-Results is read from; every later request needs only the body.
    if [ -z "$total" ]; then
      hdr_file="$tmpdir/hdr"
      http_code="$(curl -s -D "$hdr_file" -o "$page_file" -w '%{http_code}' \
        --connect-timeout 2 --max-time 20 "$url" 2>/dev/null)" || http_code=""
    else
      http_code="$(curl -s -o "$page_file" -w '%{http_code}' \
        --connect-timeout 2 --max-time 20 "$url" 2>/dev/null)" || http_code=""
    fi

    if [ -z "$http_code" ] || [ "$http_code" != "200" ]; then
      echo "fetch_path1: error - request for start=$start failed (http_code=${http_code:-<none>}); aborting, no write." >&2
      rm -rf "$tmpdir"
      trap - EXIT INT TERM
      return 1
    fi

    if [ ! -s "$page_file" ] || ! jq empty "$page_file" 2>/dev/null; then
      echo "fetch_path1: error - malformed or unreadable JSON body for start=$start; aborting, no write." >&2
      rm -rf "$tmpdir"
      trap - EXIT INT TERM
      return 1
    fi

    if [ -z "$total" ]; then
      total="$(grep -i '^Total-Results:' "$hdr_file" 2>/dev/null | tail -n1 | tr -d '\r' | awk '{print $2}')"
      if [ -z "$total" ] || ! [[ "$total" =~ ^[0-9]+$ ]]; then
        echo "fetch_path1: error - missing or non-numeric Total-Results header on the first response; aborting, no write." >&2
        rm -rf "$tmpdir"
        trap - EXIT INT TERM
        return 1
      fi
    fi

    # Exclude attachment/note/annotation items using Zotero's AUTHORITATIVE data.itemType,
    # cross-referenced from the same window's raw (format=json) response by item key -- NOT
    # the CSL .type string, which cannot carry this filter: Zotero maps its "attachment"
    # itemType to CSL type "document" (never "attachment"), so a `.type != "attachment"`
    # predicate is a verified no-op (0 items removed across a full live sweep). Annotation
    # items are already absent from the csljson body itself (see the genuine-end-of-
    # pagination comment below), so this exclusion set only ever actually removes
    # attachment/note keys from $page_file in practice, but is computed uniformly for all
    # three excluded types in case that ever changes.
    raw_file="$tmpdir/raw_${page_index}.json"
    raw_url="${API_BASE}?format=json&limit=${limit}&start=${start}"
    raw_http_code="$(curl -s -o "$raw_file" -w '%{http_code}' \
      --connect-timeout 2 --max-time 20 "$raw_url" 2>/dev/null)" || raw_http_code=""

    if [ -z "$raw_http_code" ] || [ "$raw_http_code" != "200" ]; then
      echo "fetch_path1: error - raw-format (itemType) request for start=$start failed (http_code=${raw_http_code:-<none>}); aborting, no write." >&2
      rm -rf "$tmpdir"
      trap - EXIT INT TERM
      return 1
    fi

    if [ ! -s "$raw_file" ] || ! jq empty "$raw_file" 2>/dev/null; then
      echo "fetch_path1: error - malformed or unreadable raw-format JSON body for start=$start; aborting, no write." >&2
      rm -rf "$tmpdir"
      trap - EXIT INT TERM
      return 1
    fi

    excluded_file="$tmpdir/excluded_${page_index}.json"
    if ! jq -c '[.[] | select(.data.itemType as $t | ($t == "attachment" or $t == "note" or $t == "annotation")) | .key]' \
      "$raw_file" > "$excluded_file" 2>/dev/null; then
      echo "fetch_path1: error - failed to compute itemType exclusion set at start=$start; aborting, no write." >&2
      rm -rf "$tmpdir"
      trap - EXIT INT TERM
      return 1
    fi

    filtered_file="$tmpdir/filtered_${page_index}.json"
    if ! jq --slurpfile excl "$excluded_file" \
      '($excl[0] // []) as $ex |
       [.[] | select( ((((.id // "") | split("/") | last)) as $k | ($ex | index($k))) == null )]' \
      "$page_file" > "$filtered_file" 2>/dev/null; then
      echo "fetch_path1: error - failed to apply itemType exclusion filter at start=$start; aborting, no write." >&2
      rm -rf "$tmpdir"
      trap - EXIT INT TERM
      return 1
    fi

    page_index=$(( page_index + 1 ))
    start=$(( start + limit ))

    if [ "$start" -ge "$total" ]; then
      # Genuine end of pagination. A short (or even zero-length) page is NOT the
      # termination signal here -- format=csljson silently drops annotation-typed rows
      # from page bodies without adjusting Total-Results or the start/limit window, so a
      # short mid-library page is normal. Total-Results is the only trustworthy signal.
      break
    fi

    if [ "$page_index" -ge "$max_pages" ]; then
      echo "fetch_path1: error - max_pages ($max_pages) reached at start=$start before reaching total=$total; aborting, no write. Raise max_pages if this is a legitimately larger library." >&2
      rm -rf "$tmpdir"
      trap - EXIT INT TERM
      return 1
    fi
  done

  local combined
  combined="$(jq -s 'add' "$tmpdir"/filtered_*.json 2>/dev/null)" || combined=""
  if [ -z "$combined" ] || ! echo "$combined" | jq empty 2>/dev/null; then
    echo "fetch_path1: error - failed to combine paged results via jq -s 'add'; aborting, no write." >&2
    rm -rf "$tmpdir"
    trap - EXIT INT TERM
    return 1
  fi

  rm -rf "$tmpdir"
  trap - EXIT INT TERM

  # Ensure every item has a "citation-key" key (null if absent, as plain Zotero CSL-JSON
  # export never includes it -- only Better BibTeX-authored exports do). A failure here is
  # routed to the same loud-abort contract as the rest of this function, not swallowed.
  local final
  final="$(echo "$combined" | jq '[.[] | . + {"citation-key": (.["citation-key"] // null)}]' 2>/dev/null)" || final=""
  if [ -z "$final" ]; then
    echo "fetch_path1: error - failed to default citation-key on the combined result; aborting, no write." >&2
    return 1
  fi
  echo "$final"
}

# ---------------------------------------------------------------------------
# Path 2: Better BibTeX JSON-RPC citekey enrichment
# ---------------------------------------------------------------------------
probe_bbt_rpc() {
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 2 --max-time 3 \
    -X POST -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","method":"item.search","params":[""],"id":0}' \
    "$BBT_RPC" 2>/dev/null)" || code=""
  if [ -z "$code" ]; then
    code="000"
  fi
  echo "$code"
}

enrich_path2() {
  local items_json="$1"

  local keys_json
  keys_json="$(echo "$items_json" | jq -c '[.[] | (.id // "") | split("/") | last] | map(select(. != ""))' 2>/dev/null || echo "[]")"

  local key_count
  key_count="$(echo "$keys_json" | jq 'length' 2>/dev/null || echo 0)"
  if [ "$key_count" -eq 0 ]; then
    echo "$items_json"
    return
  fi

  local rpc_body
  rpc_body="$(jq -n --argjson keys "$keys_json" '{jsonrpc:"2.0",method:"item.citationkey",params:[$keys],id:1}' 2>/dev/null)" || rpc_body=""

  if [ -z "$rpc_body" ]; then
    echo "$items_json"
    return
  fi

  local rpc_response
  rpc_response="$(curl -s --connect-timeout 2 --max-time 20 -X POST -H 'Content-Type: application/json' \
    -d "$rpc_body" "$BBT_RPC" 2>/dev/null)" || rpc_response=""

  if [ -z "$rpc_response" ] || ! echo "$rpc_response" | jq empty 2>/dev/null; then
    echo "Rationale: Better BibTeX JSON-RPC call failed or returned invalid JSON; citation-key enrichment skipped for this run, will synthesize deterministic keys instead." >&2
    echo "$items_json"
    return
  fi

  local citekey_map
  citekey_map="$(echo "$rpc_response" | jq -c '.result // {}' 2>/dev/null || echo "{}")"

  echo "$items_json" | jq --argjson m "$citekey_map" '
    [.[] | . as $it |
      ( ($it.id // "") | split("/") | last ) as $key |
      ($m[$key] // null) as $ck |
      if $ck != null and $ck != "" then ($it + {"citation-key": $ck}) else $it end
    ]
  ' 2>/dev/null || echo "$items_json"
}

# ---------------------------------------------------------------------------
# Path 3: direct sqlite reconstruction (fallback, Zotero closed)
# ---------------------------------------------------------------------------
fetch_path3() {
  local raw
  raw="$(sqlite3 -readonly -json "$ZOTERO_SQLITE" "
    SELECT
      it.itemID AS itemID,
      it.key AS itemKey,
      (
        SELECT idv.value FROM itemData id
        JOIN itemDataValues idv ON idv.valueID = id.valueID
        WHERE id.itemID = it.itemID
          AND id.fieldID = (SELECT fieldID FROM fieldsCombined WHERE fieldName='title' LIMIT 1)
        LIMIT 1
      ) AS title,
      (
        SELECT idv.value FROM itemData id
        JOIN itemDataValues idv ON idv.valueID = id.valueID
        WHERE id.itemID = it.itemID
          AND id.fieldID = (SELECT fieldID FROM fieldsCombined WHERE fieldName='abstractNote' LIMIT 1)
        LIMIT 1
      ) AS abstractNote,
      (
        SELECT idv.value FROM itemData id
        JOIN itemDataValues idv ON idv.valueID = id.valueID
        WHERE id.itemID = it.itemID
          AND id.fieldID = (SELECT fieldID FROM fieldsCombined WHERE fieldName='date' LIMIT 1)
        LIMIT 1
      ) AS itemDate,
      (
        SELECT json_group_array(json_object('family', c.lastName, 'given', c.firstName))
        FROM itemCreators ic JOIN creators c ON c.creatorID = ic.creatorID
        WHERE ic.itemID = it.itemID AND ic.creatorTypeID = 8
        ORDER BY ic.orderIndex
      ) AS authorsJson,
      (
        SELECT group_concat(t.name, ', ') FROM itemTags itg JOIN tags t ON t.tagID = itg.tagID
        WHERE itg.itemID = it.itemID
      ) AS tagsCsv,
      (
        SELECT json_group_array(json_object('path', ia.path, 'attKey', aitem.key))
        FROM itemAttachments ia JOIN items aitem ON aitem.itemID = ia.itemID
        WHERE ia.parentItemID = it.itemID AND ia.contentType = 'application/pdf'
      ) AS attachmentsJson
    FROM items it
    JOIN itemTypes ityp ON ityp.itemTypeID = it.itemTypeID
    JOIN libraries lib ON lib.libraryID = it.libraryID AND lib.type = 'user'
    WHERE it.itemTypeID NOT IN (1, 3, 28);
  " 2>/dev/null)" || raw="[]"

  if [ -z "$raw" ]; then
    raw="[]"
  fi
  if ! echo "$raw" | jq empty 2>/dev/null; then
    raw="[]"
  fi

  echo "$raw" | jq --arg home "$HOME" '
    def extract_year(d):
      if (d // "") == "" then null
      else
        ( [ (d | scan("[0-9]{4}")) ] | first ) as $first |
        if $first == null then null else ($first | tonumber) end
      end;

    [.[] |
      {
        "citation-key": null,
        "title": (.title // ""),
        "author": (.authorsJson // "[]" | fromjson),
        "issued": (
          extract_year(.itemDate) as $y |
          if $y == null then {"date-parts": [[]]} else {"date-parts": [[$y]]} end
        ),
        "keyword": (.tagsCsv // ""),
        "abstract": (.abstractNote // ""),
        "attachments": (
          (.attachmentsJson // "[]" | fromjson) |
          map(
            (.path // "") as $p |
            if ($p | startswith("storage:")) then
              { "path": ($home + "/Zotero/storage/" + (.attKey // "") + "/" + ($p[8:])) }
            else
              { "path": $p }
            end
          )
          | map(select(.path != ""))
        )
      }
    ]
  ' 2>/dev/null || echo "[]"
}

# ---------------------------------------------------------------------------
# Deterministic non-null citation-key synthesis (shared by all paths)
# ---------------------------------------------------------------------------
# lower(firstAuthorLast) + year + firstTitleWord, disambiguated on collision within the
# generated set by appending "-2", "-3", etc. Real (non-null, non-empty) citation-keys
# (e.g. backfilled by Path 2) are left untouched.
synthesize_citekeys() {
  local items_json="$1"
  local count
  count="$(echo "$items_json" | jq 'length' 2>/dev/null || echo 0)"

  if [ "$count" -eq 0 ]; then
    echo "[]"
    return
  fi

  declare -A basekey_counts=()
  local result='[]'
  local i

  for (( i = 0; i < count; i++ )); do
    local entry
    entry="$(echo "$items_json" | jq -c ".[$i]" 2>/dev/null)" || entry="{}"

    local existing_key
    existing_key="$(echo "$entry" | jq -r '.["citation-key"] // ""' 2>/dev/null || echo "")"

    local final_key="$existing_key"

    if [ -z "$existing_key" ] || [ "$existing_key" = "null" ]; then
      local fam yr word base
      fam="$(echo "$entry" | jq -r '(.author[0].family // "") | ascii_downcase | gsub("[^a-z0-9]"; "")' 2>/dev/null || echo "")"
      if [ -z "$fam" ]; then
        fam="noauthor"
      fi

      yr="$(echo "$entry" | jq -r '(.issued["date-parts"][0][0] // "nd") | tostring' 2>/dev/null || echo "nd")"
      if [ -z "$yr" ] || [ "$yr" = "null" ]; then
        yr="nd"
      fi

      word="$(echo "$entry" | jq -r '((.title // "") | split(" ") | map(select(length > 0)) | (.[0] // "")) | ascii_downcase | gsub("[^a-z0-9]"; "")' 2>/dev/null || echo "")"
      if [ -z "$word" ]; then
        word="notitle"
      fi

      base="${fam}${yr}${word}"

      local n="${basekey_counts[$base]:-0}"
      n=$(( n + 1 ))
      basekey_counts["$base"]="$n"

      if [ "$n" -eq 1 ]; then
        final_key="$base"
      else
        final_key="${base}-${n}"
      fi
    fi

    entry="$(echo "$entry" | jq --arg k "$final_key" '.["citation-key"] = $k' 2>/dev/null)" || continue
    result="$(echo "$result" | jq --argjson e "$entry" '. + [$e]' 2>/dev/null || echo "$result")"
  done

  echo "$result"
}

# ---------------------------------------------------------------------------
# Atomic writes
# ---------------------------------------------------------------------------
write_output() {
  local items_json="$1"
  local tmp_out
  tmp_out="${OUTPUT_PATH}.tmp.$$"
  echo "$items_json" | jq '.' > "$tmp_out"
  mv "$tmp_out" "$OUTPUT_PATH"
}

write_meta_stamp() {
  local source="$1"
  local source_path="$2"
  local item_count="$3"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  local meta
  meta="$(jq -n \
    --arg generated "$now" \
    --arg source "$source" \
    --arg source_path "$source_path" \
    --argjson count "$item_count" \
    '{
      "_generated": $generated,
      "source": $source,
      "source_path": $source_path,
      "item_count": $count,
      "note": "This is a one-time snapshot of your local Zotero library, NOT an auto-refreshing \"Keep updated\" export. Re-run zotero-generate-export.sh --force to pull a fresh snapshot."
    }')"

  local tmp_meta
  tmp_meta="${META_PATH}.tmp.$$"
  echo "$meta" | jq '.' > "$tmp_meta"
  mv "$tmp_meta" "$META_PATH"
}

# ---------------------------------------------------------------------------
# Generation control flow
# ---------------------------------------------------------------------------
ITEMS='[]'
SOURCE=""
SOURCE_PATH=""

API_PROBE="$(probe_zotero_api)"

if [ "$API_PROBE" = "200" ]; then
  echo "Rationale: Zotero local API reachable at $API_BASE; using Path 1 (live pull)." >&2
  if ! ITEMS="$(fetch_path1)"; then
    echo "[zotero:auto] Error: Path 1 (Zotero local API) failed partway through pagination. Aborting WITHOUT writing $OUTPUT_PATH -- overwriting a complete export with a truncated one is exactly the data-loss failure mode this abort exists to prevent. See the fetch_path1 diagnostic above for the specific cause. Re-run once resolved, or close Zotero so Path 3 (direct sqlite reconstruction) runs instead." >&2
    exit 1
  fi
  SOURCE="zotero7-local-api"
  SOURCE_PATH="$API_BASE"

  BBT_PROBE="$(probe_bbt_rpc)"
  if [ "$BBT_PROBE" = "200" ]; then
    echo "Rationale: Better BibTeX JSON-RPC reachable at $BBT_RPC; enriching citation-keys (Path 2)." >&2
    ITEMS="$(enrich_path2 "$ITEMS")"
    SOURCE="zotero7-local-api+bbt-citekeys"
  else
    echo "Rationale: Better BibTeX JSON-RPC not reachable (probe returned $BBT_PROBE); citation-keys will be synthesized deterministically for any item lacking one." >&2
  fi
elif [ -f "$ZOTERO_SQLITE" ] && command -v sqlite3 &>/dev/null; then
  echo "Rationale: Zotero local API not reachable (probe returned $API_PROBE); falling back to Path 3 (direct sqlite reconstruction of $ZOTERO_SQLITE while Zotero is closed)." >&2
  ITEMS="$(fetch_path3)"
  SOURCE="sqlite-reconstruction"
  SOURCE_PATH="$ZOTERO_SQLITE"
else
  if [ "$ORCHESTRATOR_MODE" = "true" ]; then
    # No local Zotero data source found at all. This branch MUST fail loudly and MUST NOT
    # write an empty (or any) zotero-library.json -- a silent empty-but-valid export
    # looks like a legitimate zero-item library to every downstream
    # consumer, masking the real "no data source" condition. Orchestrator/non-interactive
    # callers get a visible logged error and a non-zero exit instead, exactly like the
    # interactive branch below, phrased for an unattended context.
    echo "[zotero:auto] Error: no local Zotero data source found (API probe returned $API_PROBE at $API_BASE, and no zotero.sqlite at the resolved path $ZOTERO_SQLITE). Orchestrator mode does NOT write a silent empty-but-valid zotero-library.json for this condition -- doing so would be indistinguishable from a genuinely empty library. Open Zotero (Path 1, live API) or ensure the resolved sqlite path exists (Path 3), then re-run: zotero-generate-export.sh --orchestrator-mode true --output \"$OUTPUT_PATH\". If your Zotero uses a custom Data Directory, set \$ZOTERO_SQLITE_PATH to override auto-detection. No output file was written or overwritten." >&2
    exit 1
  else
    manual_fallback_text
    exit 1
  fi
fi

ITEMS="$(synthesize_citekeys "$ITEMS")"

write_output "$ITEMS"

FINAL_COUNT="$(echo "$ITEMS" | jq 'length' 2>/dev/null || echo 0)"
write_meta_stamp "$SOURCE" "$SOURCE_PATH" "$FINAL_COUNT"

echo "Rationale: wrote $FINAL_COUNT entries to $OUTPUT_PATH (source: $SOURCE)." >&2
echo "This is a ONE-TIME SNAPSHOT, not an auto-refreshing 'Keep updated' export -- re-run this generator (--force) to refresh it. Staleness stamp: $META_PATH" >&2

echo "$OUTPUT_PATH"
exit 0
