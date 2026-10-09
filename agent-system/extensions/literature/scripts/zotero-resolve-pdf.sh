#!/usr/bin/env bash
# zotero-resolve-pdf.sh - Read-only doc_id -> Zotero PDF resolver.
#
# Given a doc_id and its ~/Projects/Literature/index.json record, answers: which Zotero PDF (if
# any) corresponds to it, and how confident are we? Writes nothing to the corpus or to Zotero.
# Never opens zotero.sqlite read-write; never mutates index.json or the Zotero storage tree.
#
# Usage:
#   zotero-resolve-pdf.sh --doc-id <id> [--index /path/to/index.json]
#   echo '{"doc_id":"...","record":{...}}' | zotero-resolve-pdf.sh
#
# Output: one JSON object on stdout with fields:
#   doc_id, tier (key-anchored|search-candidate|matched-no-pdf|absent), zotero_key,
#   attachment_key, resolved_path, zotero_title, zotero_year, zotero_doi, title_similarity,
#   access_mode, error (present only on hard failure)
#
# The storage root is ALWAYS derived from zotero-resolve-sqlite-path.sh's dataDir -- never
# hardcoded to the historical default profile's storage dir (that is a latent bug in
# zotero-generate-export.sh's
# fetch_path3(), not reproduced here).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_INDEX="${HOME}/Projects/Literature/index.json"
API_BASE="http://127.0.0.1:23119/api/users/0"

DOC_ID=""
INDEX_PATH="$DEFAULT_INDEX"

while [ $# -gt 0 ]; do
  case "$1" in
    --doc-id) DOC_ID="$2"; shift 2 ;;
    --index) INDEX_PATH="$2"; shift 2 ;;
    *) echo "Usage: $0 --doc-id <id> [--index path] | pipe {\"doc_id\":...,\"record\":...} on stdin" >&2; exit 2 ;;
  esac
done

emit() {
  # emit <json>
  echo "$1"
}

fail_abort() {
  local doc_id="$1"
  jq -n --arg doc_id "$doc_id" '{
    doc_id: $doc_id,
    tier: "absent",
    access_mode: "abort",
    error: "Zotero is running but its local API is unreachable. Enable it: Zotero Settings -> Advanced -> \"Allow other applications on this computer to communicate with Zotero\", then re-run."
  }'
  exit 1
}

# --- Resolve doc_id + record ---
if [ -n "$DOC_ID" ]; then
  RECORD="$(jq -c --arg id "$DOC_ID" '.entries[] | select(.id == $id)' "$INDEX_PATH" 2>/dev/null || true)"
  if [ -z "$RECORD" ] || [ "$RECORD" = "null" ]; then
    jq -n --arg doc_id "$DOC_ID" '{doc_id: $doc_id, tier: "absent", error: "doc_id not found in index"}'
    exit 0
  fi
else
  INPUT_JSON="$(cat)"
  DOC_ID="$(jq -r '.doc_id' <<<"$INPUT_JSON")"
  RECORD="$(jq -c '.record' <<<"$INPUT_JSON")"
fi

TITLE="$(jq -r '.title // ""' <<<"$RECORD")"
FIRST_AUTHOR_FULL="$(jq -r '.authors[0] // ""' <<<"$RECORD")"
FIRST_AUTHOR_LAST="$(awk '{print $NF}' <<<"$FIRST_AUTHOR_FULL")"
# shellcheck disable=SC2034  # Extracted from the input record but not consulted by the
# candidate-matching/scoring logic below, which derives its own per-candidate cand_year from
# each Zotero candidate independently for OUTPUT reporting only (zotero_year), never comparing
# it against this PDF's own DOC_YEAR for disambiguation -- a pre-existing gap (the matching
# logic even names a year-mismatch false-match case in its own comment), not introduced here.
DOC_YEAR="$(jq -r '.year // empty' <<<"$RECORD")"
EXISTING_ZKEY="$(jq -r '.zotero_key // empty' <<<"$RECORD")"

# --- Derive storage root (never hardcode the historical default profile's storage dir) ---
ZOTERO_SQLITE="$(bash "$SCRIPT_DIR/zotero-resolve-sqlite-path.sh")"
ZOTERO_DATA_DIR="$(dirname "$ZOTERO_SQLITE")"
ZOTERO_STORAGE_ROOT="$ZOTERO_DATA_DIR/storage"

if [ ! -d "$ZOTERO_STORAGE_ROOT" ]; then
  jq -n --arg doc_id "$DOC_ID" --arg root "$ZOTERO_STORAGE_ROOT" \
    '{doc_id: $doc_id, tier: "absent", error: ("derived Zotero storage root does not exist: " + $root)}'
  exit 1
fi

# --- Determine access mode ---
HTTP_CODE="$(curl -sf -m 5 -o /dev/null -w '%{http_code}' "$API_BASE/items?limit=1" 2>/dev/null || echo "000")"
if [ "$HTTP_CODE" = "200" ]; then
  ACCESS_MODE="live-api"
elif pgrep -f 'zotero-bin' >/dev/null 2>&1; then
  ACCESS_MODE="abort"
else
  ACCESS_MODE="sqlite-readonly"
fi

if [ "$ACCESS_MODE" = "abort" ]; then
  fail_abort "$DOC_ID"
fi

TITLE_SIM_PY="$SCRIPT_DIR/.zotero-title-sim.py"

title_similarity() {
  # title_similarity <a> <b> -> float 0..1
  python3 "$TITLE_SIM_PY" "$1" "$2"
}

# --- live-api access mode ---
zotero_search_query() {
  # zotero_search_query <query> -> JSON array (possibly empty)
  local result
  result="$(curl -s -G "$API_BASE/items" \
    --data-urlencode "q=$1" \
    --data-urlencode "itemType=-attachment" \
    --data-urlencode "limit=5" 2>/dev/null || echo "[]")"
  if ! jq -e 'type == "array"' <<<"$result" >/dev/null 2>&1; then result="[]"; fi
  echo "$result"
}

resolve_live_api() {
  local candidates="[]"

  # Search path: try the full title, then progressively drop the last word (right-truncation)
  # down to a 2-word minimum -- corpus title strings sometimes carry a trailing
  # descriptor/disambiguator word that is not part of the real bibliographic title (e.g. a
  # slug-derived "Intuitionistic" suffix), and Zotero's quick search requires all query tokens
  # to be present, so an over-specific query silently returns zero hits. Stop at the first
  # query that yields any result.
  if [ -n "$TITLE" ]; then
    local -a words
    read -r -a words <<<"$TITLE"
    local wc="${#words[@]}"
    local try_words="$wc"
    while [ "$try_words" -ge 2 ] && [ "$(jq 'length' <<<"$candidates")" = "0" ]; do
      local query
      query="$(printf '%s ' "${words[@]:0:$try_words}")"
      candidates="$(zotero_search_query "${query% }")"
      try_words=$((try_words - 1))
    done
    # Always also try the full title once even if wc < 2 (single-word titles).
    if [ "$(jq 'length' <<<"$candidates")" = "0" ] && [ "$wc" -lt 2 ]; then
      candidates="$(zotero_search_query "$TITLE")"
    fi
  fi

  # Author fallback only if title search (in all truncations) found nothing.
  local author_candidates="[]"
  if [ "$(jq 'length' <<<"$candidates")" = "0" ] && [ -n "$FIRST_AUTHOR_LAST" ]; then
    author_candidates="$(zotero_search_query "$FIRST_AUTHOR_LAST")"
    candidates="$author_candidates"
  fi

  local n
  n="$(jq 'length' <<<"$candidates")"
  if [ "$n" = "0" ]; then
    jq -n --arg doc_id "$DOC_ID" --arg mode "$ACCESS_MODE" \
      '{doc_id: $doc_id, tier: "absent", access_mode: $mode}'
    return 0
  fi

  # Evaluate every candidate; select the one with the HIGHEST title similarity among those that
  # have a resolvable PDF attachment (never just the first one found in API order -- a
  # low-similarity item appearing earlier in results must not shadow a better match).
  #
  # MIN_SIMILARITY floors out author-only-fallback collisions: a common surname (e.g. "Liu") can
  # coincidentally match an unrelated item in a philosophy/logic library with a low title
  # similarity (empirically observed: 0.12-0.34 for the arXiv hardware-verification cluster,
  # which the research phase confirmed has zero true representation in this Zotero library).
  # Genuine matches observed so far score >= 0.52 (pnueli's Lamport year-mismatch, itself a
  # false positive but a *plausible* one correctly deferred to Phase 4) up to 1.0 (exact-title
  # key-anchored hits). 0.4 sits between the two clusters.
  local MIN_SIMILARITY="0.4"
  local best_pdf_sim="-1" best_pdf_key="" best_pdf_att="" best_pdf_path="" best_pdf_title="" best_pdf_year="" best_pdf_doi=""
  local best_bib_sim="-1" best_bib_key="" best_bib_title="" best_bib_year="" best_bib_att=""
  local i cand_key cand_title cand_year cand_doi
  for i in $(seq 0 $((n - 1))); do
    cand_key="$(jq -r --argjson i "$i" '.[$i].key' <<<"$candidates")"
    cand_title="$(jq -r --argjson i "$i" '.[$i].data.title // ""' <<<"$candidates")"
    cand_year="$(jq -r --argjson i "$i" '.[$i].data.date // "" | (scan("[0-9]{4}") // "") ' <<<"$candidates" 2>/dev/null || echo "")"
    cand_doi="$(jq -r --argjson i "$i" '.[$i].data.DOI // null' <<<"$candidates")"

    local sim
    sim="$(title_similarity "$TITLE" "$cand_title" 2>/dev/null || echo "0.0")"

    local children
    children="$(curl -s "$API_BASE/items/$cand_key/children" 2>/dev/null || echo "[]")"
    if ! jq -e 'type == "array"' <<<"$children" >/dev/null 2>&1; then children="[]"; fi

    local pdf_att
    pdf_att="$(jq -c '[.[] | select(.data.contentType == "application/pdf")] | first // empty' <<<"$children")"

    if [ -n "$pdf_att" ] && [ "$pdf_att" != "null" ]; then
      local att_key att_filename resolved_path
      att_key="$(jq -r '.key' <<<"$pdf_att")"
      att_filename="$(jq -r '.data.filename // ""' <<<"$pdf_att")"
      resolved_path="$ZOTERO_STORAGE_ROOT/$att_key/$att_filename"
      if [ -f "$resolved_path" ] && awk -v s="$sim" -v b="$best_pdf_sim" -v m="$MIN_SIMILARITY" 'BEGIN{exit !(s>b && s>=m)}'; then
        best_pdf_sim="$sim"; best_pdf_key="$cand_key"; best_pdf_att="$att_key"
        best_pdf_path="$resolved_path"; best_pdf_title="$cand_title"; best_pdf_year="$cand_year"
        best_pdf_doi="$cand_doi"
      fi
    fi

    # Track the best bibliographic match regardless of PDF, for the matched-no-pdf fallback.
    # Same MIN_SIMILARITY floor applies -- a coincidental surname match must not be reported as
    # a confirmed bibliographic identification.
    if [ -n "$children" ] && [ "$children" != "[]" ] && awk -v s="$sim" -v b="$best_bib_sim" -v m="$MIN_SIMILARITY" 'BEGIN{exit !(s>b && s>=m)}'; then
      local html_att
      html_att="$(jq -c '[.[] | select(.data.itemType == "attachment")] | first // empty' <<<"$children")"
      best_bib_sim="$sim"; best_bib_key="$cand_key"; best_bib_title="$cand_title"; best_bib_year="$cand_year"
      best_bib_att="$(jq -r 'if . == null or . == "" then "" else (.data.filename // .data.contentType // "") end' <<<"$html_att")"
    fi
  done

  if [ -n "$best_pdf_key" ]; then
    local tier
    if [ -n "$EXISTING_ZKEY" ]; then tier="key-anchored"; else tier="search-candidate"; fi
    jq -n \
      --arg doc_id "$DOC_ID" --arg tier "$tier" --arg mode "$ACCESS_MODE" \
      --arg zkey "$best_pdf_key" --arg attkey "$best_pdf_att" --arg path "$best_pdf_path" \
      --arg ztitle "$best_pdf_title" --arg zyear "$best_pdf_year" --arg zdoi "$best_pdf_doi" \
      --argjson sim "$best_pdf_sim" \
      '{
        doc_id: $doc_id, tier: $tier, access_mode: $mode,
        zotero_key: $zkey, attachment_key: $attkey, resolved_path: $path,
        zotero_title: $ztitle, zotero_year: ($zyear | select(. != "") // null),
        zotero_doi: ($zdoi | if . == "" or . == "null" then null else . end),
        title_similarity: $sim
      }'
    return 0
  fi

  if [ -n "$best_bib_key" ]; then
    jq -n \
      --arg doc_id "$DOC_ID" --arg mode "$ACCESS_MODE" \
      --arg zkey "$best_bib_key" --arg ztitle "$best_bib_title" \
      --arg zyear "$best_bib_year" --arg att "$best_bib_att" \
      --argjson sim "$best_bib_sim" \
      '{
        doc_id: $doc_id, tier: "matched-no-pdf", access_mode: $mode,
        zotero_key: $zkey, zotero_title: $ztitle,
        zotero_year: ($zyear | select(. != "") // null),
        matched_attachment: ($att | select(. != "") // null),
        title_similarity: $sim
      }'
    return 0
  fi

  jq -n --arg doc_id "$DOC_ID" --arg mode "$ACCESS_MODE" '{doc_id: $doc_id, tier: "absent", access_mode: $mode}'
}

# --- sqlite-readonly fallback (only used when Zotero is closed) ---
resolve_sqlite_readonly() {
  if ! command -v sqlite3 >/dev/null 2>&1; then
    jq -n --arg doc_id "$DOC_ID" --arg mode "$ACCESS_MODE" \
      '{doc_id: $doc_id, tier: "absent", access_mode: $mode, error: "sqlite3 not available"}'
    return 0
  fi

  local raw
  raw="$(sqlite3 -readonly -json "$ZOTERO_SQLITE" "
    SELECT
      it.key AS itemKey,
      (SELECT idv.value FROM itemData id JOIN itemDataValues idv ON idv.valueID = id.valueID
       WHERE id.itemID = it.itemID
         AND id.fieldID = (SELECT fieldID FROM fieldsCombined WHERE fieldName='title' LIMIT 1)
       LIMIT 1) AS title,
      (SELECT idv.value FROM itemData id JOIN itemDataValues idv ON idv.valueID = id.valueID
       WHERE id.itemID = it.itemID
         AND id.fieldID = (SELECT fieldID FROM fieldsCombined WHERE fieldName='date' LIMIT 1)
       LIMIT 1) AS itemDate,
      (SELECT idv.value FROM itemData id JOIN itemDataValues idv ON idv.valueID = id.valueID
       WHERE id.itemID = it.itemID
         AND id.fieldID = (SELECT fieldID FROM fieldsCombined WHERE fieldName='DOI' LIMIT 1)
       LIMIT 1) AS doi,
      (SELECT json_group_array(json_object('path', ia.path, 'attKey', aitem.key, 'contentType', ia.contentType))
       FROM itemAttachments ia JOIN items aitem ON aitem.itemID = ia.itemID
       WHERE ia.parentItemID = it.itemID) AS attachmentsJson
    FROM items it
    JOIN itemTypes ityp ON ityp.itemTypeID = it.itemTypeID
    JOIN libraries lib ON lib.libraryID = it.libraryID AND lib.type = 'user'
    WHERE it.itemTypeID NOT IN (1, 3, 28);
  " 2>/dev/null)" || raw="[]"
  if [ -z "$raw" ]; then raw="[]"; fi
  if ! jq -e 'type == "array"' <<<"$raw" >/dev/null 2>&1; then raw="[]"; fi

  local best_key="" best_title="" best_year="" best_doi="null" best_att="" best_sim="-1" best_has_pdf="false"
  local n
  n="$(jq 'length' <<<"$raw")"
  local i cand_key cand_title cand_year cand_doi
  for i in $(seq 0 $((n - 1))); do
    cand_title="$(jq -r --argjson i "$i" '.[$i].title // ""' <<<"$raw")"
    [ -z "$cand_title" ] && continue
    local sim
    sim="$(title_similarity "$TITLE" "$cand_title" 2>/dev/null || echo "0.0")"
    if awk -v s="$sim" -v b="$best_sim" 'BEGIN{exit !(s>b)}'; then
      cand_key="$(jq -r --argjson i "$i" '.[$i].itemKey' <<<"$raw")"
      cand_year="$(jq -r --argjson i "$i" '.[$i].itemDate // "" | (scan("[0-9]{4}") // "")' <<<"$raw" 2>/dev/null || echo "")"
      cand_doi="$(jq -r --argjson i "$i" '.[$i].doi // "null"' <<<"$raw")"
      local pdf_path att_key
      pdf_path="$(jq -r --argjson i "$i" '(.[$i].attachmentsJson // "[]" | fromjson) | map(select(.contentType == "application/pdf")) | first.path // empty' <<<"$raw")"
      att_key="$(jq -r --argjson i "$i" '(.[$i].attachmentsJson // "[]" | fromjson) | map(select(.contentType == "application/pdf")) | first.attKey // empty' <<<"$raw")"
      best_sim="$sim"; best_key="$cand_key"; best_title="$cand_title"; best_year="$cand_year"; best_doi="$cand_doi"
      if [ -n "$pdf_path" ]; then
        best_has_pdf="true"
        best_att="$att_key:${pdf_path#storage:}"
      else
        best_has_pdf="false"
        best_att=""
      fi
    fi
  done

  if [ -z "$best_key" ]; then
    jq -n --arg doc_id "$DOC_ID" --arg mode "$ACCESS_MODE" '{doc_id: $doc_id, tier: "absent", access_mode: $mode}'
    return 0
  fi

  if [ "$best_has_pdf" = "true" ]; then
    local att_key="${best_att%%:*}"
    local filename="${best_att#*:}"
    local resolved_path="$ZOTERO_STORAGE_ROOT/$att_key/$filename"
    if [ -f "$resolved_path" ]; then
      local tier
      if [ -n "$EXISTING_ZKEY" ]; then tier="key-anchored"; else tier="search-candidate"; fi
      jq -n \
        --arg doc_id "$DOC_ID" --arg tier "$tier" --arg mode "$ACCESS_MODE" \
        --arg zkey "$best_key" --arg attkey "$att_key" --arg path "$resolved_path" \
        --arg ztitle "$best_title" --arg zyear "$best_year" --arg zdoi "$best_doi" \
        --argjson sim "$best_sim" \
        '{
          doc_id: $doc_id, tier: $tier, access_mode: $mode,
          zotero_key: $zkey, attachment_key: $attkey, resolved_path: $path,
          zotero_title: $ztitle, zotero_year: ($zyear | select(. != "") // null),
          zotero_doi: ($zdoi | if . == "" or . == "null" then null else . end),
          title_similarity: $sim
        }'
      return 0
    fi
  fi

  jq -n \
    --arg doc_id "$DOC_ID" --arg mode "$ACCESS_MODE" \
    --arg zkey "$best_key" --arg ztitle "$best_title" --arg zyear "$best_year" --argjson sim "$best_sim" \
    '{doc_id: $doc_id, tier: "matched-no-pdf", access_mode: $mode, zotero_key: $zkey, zotero_title: $ztitle, zotero_year: ($zyear | select(. != "") // null), title_similarity: $sim}'
}

case "$ACCESS_MODE" in
  live-api) resolve_live_api ;;
  sqlite-readonly) resolve_sqlite_readonly ;;
esac
