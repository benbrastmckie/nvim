#!/usr/bin/env bash
# generate-zotero-page-fixtures.sh - Synthetic paged Zotero local-API fixture generator, a
# sibling helper to generate-test-fixtures.py (which is PyMuPDF/PDF-specific and does not fit
# this JSON-only need). Produces one page window's worth of items in either the csljson or the
# raw (format=json) shape, for curl-stub.sh's Zotero local-API dispatch route to serve.
#
# Models two real, empirically-verified Zotero 7 local-API quirks (see this repo's
# zotero-pdf-resolution.md pagination subsection) with a single deterministic item-type
# distribution, keyed by (index % ratio):
#   index % ratio == 0  -> annotation   (present in the RAW/format=json window; ABSENT from the
#                          csljson body entirely -- this is what makes a csljson page shorter
#                          than `limit` while Total-Results/the pagination window still counts
#                          the item, so pagination MUST be Total-Results-driven, not
#                          page-length-driven)
#   index % ratio == 1  -> attachment   (present in BOTH; csljson type is "document", never
#                          "attachment" -- the CSL .type field cannot carry the exclusion filter)
#   index % ratio == 2  -> note         (present in BOTH; csljson type is also "document")
#   otherwise           -> journalArticle (bibliographic; csljson type "article-journal")
#
# Item keys are deterministic and shared between the two formats for the same global index, so
# a raw-format itemType lookup keyed by `.key` correctly cross-references a csljson entry keyed
# by `.id | split("/") | last`.
#
# Entirely single-jq-invocation (`jq -n` + `range`): no item, however large the window, ever
# transits argv -- the same MAX_ARG_STRLEN property this whole task exists to protect.
#
# USAGE:
#   generate-zotero-page-fixtures.sh --format csljson|raw --start N --limit L --total T
#     [--ratio K] [--pad-bytes B]
#
# OPTIONS:
#   --format csljson|raw   Output shape. csljson matches format=csljson; raw matches format=json.
#   --start N               Window start offset (0-based).
#   --limit L               Window size (page size).
#   --total T               Total library item count (bounds the window: the window never
#                            extends past T, and yields an empty array when start >= T).
#   --ratio K               Item-type distribution modulus (default 10).
#   --pad-bytes B           Bytes of filler appended to each bibliographic/document item's
#                            "abstract" field (default 0), used to force a single page's byte
#                            size past the 131072-byte MAX_ARG_STRLEN boundary.
#
# OUTPUT:
#   stdout: a JSON array (the page window), never anything else.

set -euo pipefail

FORMAT=""
START=0
LIMIT=100
TOTAL=0
RATIO=10
PAD_BYTES=0

while [ $# -gt 0 ]; do
  case "$1" in
    --format) FORMAT="${2:-}"; shift 2 ;;
    --start) START="${2:-0}"; shift 2 ;;
    --limit) LIMIT="${2:-100}"; shift 2 ;;
    --total) TOTAL="${2:-0}"; shift 2 ;;
    --ratio) RATIO="${2:-10}"; shift 2 ;;
    --pad-bytes) PAD_BYTES="${2:-0}"; shift 2 ;;
    *)
      echo "generate-zotero-page-fixtures.sh: unrecognized argument '$1'" >&2
      exit 2
      ;;
  esac
done

if [ "$FORMAT" != "csljson" ] && [ "$FORMAT" != "raw" ]; then
  echo "generate-zotero-page-fixtures.sh: --format must be 'csljson' or 'raw', got: '$FORMAT'" >&2
  exit 2
fi

# Window end is bounded by TOTAL; count is 0 when the window starts at/after TOTAL.
END=$(( START + LIMIT ))
if [ "$END" -gt "$TOTAL" ]; then
  END="$TOTAL"
fi
COUNT=$(( END - START ))
if [ "$COUNT" -lt 0 ]; then
  COUNT=0
fi

jq -n \
  --argjson start "$START" \
  --argjson count "$COUNT" \
  --argjson ratio "$RATIO" \
  --argjson padbytes "$PAD_BYTES" \
  --arg fmt "$FORMAT" '
  def pad5(n): (n | tostring) as $s | ("0" * (5 - ($s | length))) + $s;
  def keyof(i): "ITEM" + pad5(i);
  def padstr: if $padbytes > 0 then ("x" * $padbytes) else "" end;

  [ range($start; $start + $count) | . as $i |
    ($i % $ratio) as $m |
    keyof($i) as $key |
    if $fmt == "raw" then
      {
        key: $key,
        data: {
          itemType: (
            if $m == 0 then "annotation"
            elif $m == 1 then "attachment"
            elif $m == 2 then "note"
            else "journalArticle"
            end
          ),
          title: ("Item " + ($i | tostring) + " Title")
        }
      }
    else
      if $m == 0 then
        empty
      else
        {
          id: ("http://zotero.org/users/0/items/" + $key),
          type: (if ($m == 1 or $m == 2) then "document" else "article-journal" end),
          title: ("Item " + ($i | tostring) + " Title"),
          abstract: padstr
        }
      end
    end
  ]
'
