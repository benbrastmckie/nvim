#!/usr/bin/env bash
# curl-stub.sh — PATH-shadowing curl stub for literature-discover.sh Tier 3 tests AND
# zotero-generate-export.sh Path 1 tests.
#
# Dispatches canned HTTP responses by request host (Tier 3 providers) or by request path
# (the Zotero local API, since it shares host:port `localhost:23119` with the Better BibTeX
# RPC endpoint), keyed off per-host/per-route environment variables, so both fallback chains
# can be driven deterministically without any real network call. Install by copying or
# symlinking this file as `curl` into a scratch directory prepended to PATH before invoking
# the script under test — every caller in this extension calls bare `curl`, never an absolute
# path or `command curl`, so a PATH-shadowing stub actually intercepts it.
#
# Host -> env var mapping (Tier 3 providers; all optional; default code is 200, default body
# is the matching fixture under ./fixtures/):
#   api.semanticscholar.org   CURL_STUB_SS_CODE        / CURL_STUB_SS_BODY
#   api.openalex.org          CURL_STUB_OPENALEX_CODE  / CURL_STUB_OPENALEX_BODY
#   api.crossref.org          CURL_STUB_CROSSREF_CODE  / CURL_STUB_CROSSREF_BODY
#   api.unpaywall.org         CURL_STUB_UNPAYWALL_CODE / CURL_STUB_UNPAYWALL_BODY
#
# Path-based routes on localhost:23119 / 127.0.0.1:23119 (the Zotero local API and the
# Better BibTeX RPC endpoint share this host:port, so they are dispatched on URL PATH, not
# host, to avoid misrouting one into the other):
#   */api/users/0/items*          Zotero local API items endpoint (format=csljson or
#                                  format=json, paginated via start=/limit=). See
#                                  "Zotero local-API env knobs" below.
#   */better-bibtex/json-rpc*     Better BibTeX JSON-RPC endpoint. CURL_STUB_BBT_CODE
#                                  (default 200) / CURL_STUB_BBT_BODY (default an empty
#                                  `{"result":{}}` citekey map, so no item gets an
#                                  enriched citekey and synthesis is exercised instead).
#
# Zotero local-API env knobs (all optional):
#   CURL_STUB_ZOTERO_API_CODE      HTTP code for the items endpoint (default 200).
#   CURL_STUB_ZOTERO_TOTAL         Total library item count backing Total-Results and the
#                                  pagination window (default 0 -- an empty library).
#   CURL_STUB_ZOTERO_RATIO         Item-type distribution modulus fed to
#                                  generate-zotero-page-fixtures.sh (default 10): one in
#                                  every RATIO items is an annotation (present in the raw
#                                  window, absent from the csljson body -- the short-page
#                                  quirk), one is an attachment and one is a note (present
#                                  in both, mistyped as CSL "document" in csljson -- the
#                                  itemType-filter quirk), the rest are bibliographic.
#   CURL_STUB_ZOTERO_PAD_BYTES     Bytes of filler in each bibliographic/document csljson
#                                  item's "abstract" field (default 0), used to force a
#                                  single page past the 131072-byte MAX_ARG_STRLEN boundary.
#   CURL_STUB_ZOTERO_FAIL_AT       A `start` value at which this request (whichever format)
#                                  simulates a curl transport failure (exit 28, no stdout).
#   CURL_STUB_ZOTERO_MALFORMED_AT  A `start` value at which this request (whichever format)
#                                  returns a non-JSON body instead of the generated page.
#   CURL_STUB_ZOTERO_RAW_FAIL_AT       Like FAIL_AT, but format=json-only (does not also catch
#                                      the format=csljson fetch or the no-start probe request).
#   CURL_STUB_ZOTERO_RAW_MALFORMED_AT  Like MALFORMED_AT, but format=json-only.
#
# A *_CODE value of "curl_fail" simulates a curl transport failure: nonzero exit
# (28, curl's own timeout code), no stdout at all — this is how a stubbed scenario
# exercises the `curl_exit` failure branch, distinct from a stubbed non-200 response.
#
# CURL_STUB_LOG, if set, has one line appended per invocation: "URL=<url> ARGS=<argv>"
# — used by tests asserting a header was (or was not) sent, e.g. S2_API_KEY's
# x-api-key header, or that a BBT-RPC URL was never served an items body.
#
# Recognizes four curl invocation shapes:
#   curl -s -w '\n%{http_code}' --max-time N "$url"        -> body, then a literal
#                                                              newline, then the code
#   curl -s --max-time N "$url"                             -> body only (Unpaywall path)
#   curl -s -o /dev/null -w '%{http_code}' ... "$url"       -> the bare 3-digit code ONLY,
#                                                              no body at all (the local-API
#                                                              probe shape: probe_zotero_api()/
#                                                              probe_bbt_rpc())
#   curl -s -D "$hdrfile" -o "$outfile" -w '%{http_code}' "$url"
#                                                            -> body written to $outfile,
#                                                              synthetic response headers
#                                                              (Total-Results, Link) written
#                                                              to $hdrfile, bare code to stdout
# Any other flag is accepted and ignored; only -w's format string, -o/-D's target paths, and
# the URL argument affect this stub's output shape.

set -uo pipefail

# Resolve this script's OWN real directory via readlink -f, not just dirname(BASH_SOURCE):
# callers commonly install this stub as `curl` in a scratch PATH dir via `ln -s` OR `cp`. A
# symlink resolves correctly through readlink -f to the real tests/ dir (where the sibling
# generator and fixtures/ live); a cp does not, since the copy has no sibling files at all --
# CURL_STUB_TESTS_DIR is available as an explicit override for that case (unused by the
# pre-existing Tier 3 tests, which cp the stub but never exercise the Zotero routes below).
TESTS_DIR="${CURL_STUB_TESTS_DIR:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)}"
FIXTURES_DIR="$TESTS_DIR/fixtures"
ZOTERO_PAGE_GEN="$TESTS_DIR/generate-zotero-page-fixtures.sh"

url=""
want_code_suffix=false
outfile=""
hdrfile=""
args=("$@")
argc=${#args[@]}

i=0
while [ "$i" -lt "$argc" ]; do
  arg="${args[$i]}"
  case "$arg" in
    -w)
      i=$((i + 1))
      wfmt="${args[$i]:-}"
      if [[ "$wfmt" == *"%{http_code}"* ]]; then
        want_code_suffix=true
      fi
      ;;
    -o)
      i=$((i + 1))
      outfile="${args[$i]:-}"
      ;;
    -D)
      i=$((i + 1))
      hdrfile="${args[$i]:-}"
      ;;
    http://*|https://*)
      url="$arg"
      ;;
  esac
  i=$((i + 1))
done

if [ -n "${CURL_STUB_LOG:-}" ]; then
  printf 'URL=%s ARGS=%s\n' "$url" "${args[*]}" >> "$CURL_STUB_LOG"
fi

# url_query_param URL NAME DEFAULT -- extracts a single query-string parameter's value.
url_query_param() {
  local u="$1" name="$2" default="$3"
  local qs val
  qs="${u#*\?}"
  if [ "$qs" = "$u" ]; then
    echo "$default"
    return
  fi
  val="$(printf '%s\n' "$qs" | tr '&' '\n' | sed -n "s/^${name}=//p" | head -n1)"
  if [ -z "$val" ]; then
    echo "$default"
  else
    echo "$val"
  fi
}

code=""
body_file=""
body_inline=""
is_zotero_items=false

case "$url" in
  *api.semanticscholar.org*)
    code="${CURL_STUB_SS_CODE:-200}"
    body_file="${CURL_STUB_SS_BODY:-$FIXTURES_DIR/tier3-semanticscholar-200.json}"
    ;;
  *api.openalex.org*)
    code="${CURL_STUB_OPENALEX_CODE:-200}"
    body_file="${CURL_STUB_OPENALEX_BODY:-$FIXTURES_DIR/tier3-openalex-200.json}"
    ;;
  *api.crossref.org*)
    code="${CURL_STUB_CROSSREF_CODE:-200}"
    body_file="${CURL_STUB_CROSSREF_BODY:-$FIXTURES_DIR/tier3-crossref-200.json}"
    ;;
  *api.unpaywall.org*)
    code="${CURL_STUB_UNPAYWALL_CODE:-200}"
    body_file="${CURL_STUB_UNPAYWALL_BODY:-$FIXTURES_DIR/tier3-unpaywall-200.json}"
    ;;
  *localhost:23119/better-bibtex/json-rpc*|*127.0.0.1:23119/better-bibtex/json-rpc*)
    code="${CURL_STUB_BBT_CODE:-200}"
    if [ -n "${CURL_STUB_BBT_BODY:-}" ]; then
      body_file="$CURL_STUB_BBT_BODY"
    else
      body_inline='{"result":{}}'
    fi
    ;;
  *localhost:23119/api/users/0/items*|*127.0.0.1:23119/api/users/0/items*)
    is_zotero_items=true
    code="${CURL_STUB_ZOTERO_API_CODE:-200}"
    ;;
  *)
    # Unknown/unexpected host: fail loudly as a transport error rather than
    # silently serving the wrong fixture.
    exit 7
    ;;
esac

if [ "$is_zotero_items" = "true" ]; then
  total="${CURL_STUB_ZOTERO_TOTAL:-0}"
  ratio="${CURL_STUB_ZOTERO_RATIO:-10}"
  padbytes="${CURL_STUB_ZOTERO_PAD_BYTES:-0}"
  start="$(url_query_param "$url" "start" "0")"
  limit="$(url_query_param "$url" "limit" "100")"
  fmt_param="$(url_query_param "$url" "format" "csljson")"

  # FAIL_AT/MALFORMED_AT apply regardless of format (both the csljson and the raw request at
  # that start are affected, since a real page fetch failure at either format is equally a
  # failure). RAW_FAIL_AT/RAW_MALFORMED_AT are format=json-only, so a test can fail/corrupt
  # JUST the itemType cross-reference fetch for a start whose csljson fetch already succeeded
  # (needed because CURL_STUB_ZOTERO_FAIL_AT=0 would otherwise also catch the initial
  # probe_zotero_api() call, which has no start param and defaults to "0").
  if [ -n "${CURL_STUB_ZOTERO_FAIL_AT:-}" ] && [ "$start" = "$CURL_STUB_ZOTERO_FAIL_AT" ]; then
    exit 28
  fi
  if [ "$fmt_param" = "json" ] && [ -n "${CURL_STUB_ZOTERO_RAW_FAIL_AT:-}" ] && [ "$start" = "$CURL_STUB_ZOTERO_RAW_FAIL_AT" ]; then
    exit 28
  fi

  if [ -n "${CURL_STUB_ZOTERO_MALFORMED_AT:-}" ] && [ "$start" = "$CURL_STUB_ZOTERO_MALFORMED_AT" ]; then
    body_inline="THIS IS NOT VALID JSON {{{"
  elif [ "$fmt_param" = "json" ] && [ -n "${CURL_STUB_ZOTERO_RAW_MALFORMED_AT:-}" ] && [ "$start" = "$CURL_STUB_ZOTERO_RAW_MALFORMED_AT" ]; then
    body_inline="THIS IS NOT VALID JSON {{{"
  elif [ "$fmt_param" = "json" ]; then
    body_inline="$(bash "$ZOTERO_PAGE_GEN" --format raw --start "$start" --limit "$limit" --total "$total" --ratio "$ratio")"
  else
    body_inline="$(bash "$ZOTERO_PAGE_GEN" --format csljson --start "$start" --limit "$limit" --total "$total" --ratio "$ratio" --pad-bytes "$padbytes")"
  fi

  if [ -n "$hdrfile" ] && [ "$hdrfile" != "-" ]; then
    {
      printf 'HTTP/1.1 %s OK\r\n' "$code"
      printf 'Total-Results: %s\r\n' "$total"
      last_start=0
      if [ "$total" -gt 0 ] && [ "$limit" -gt 0 ]; then
        last_start=$(( ((total - 1) / limit) * limit ))
      fi
      printf 'Link: <%s?format=%s&limit=%s&start=%s>; rel="last"\r\n' \
        "${url%%\?*}" "$fmt_param" "$limit" "$last_start"
      printf '\r\n'
    } > "$hdrfile"
  fi
fi

if [ "$code" = "curl_fail" ]; then
  exit 28
fi

body=""
if [ -n "$body_inline" ] || [ "$is_zotero_items" = "true" ]; then
  body="$body_inline"
elif [ -f "$body_file" ]; then
  body="$(cat "$body_file")"
fi

if [ -n "$outfile" ] && [ "$outfile" != "-" ]; then
  if [ "$outfile" = "/dev/null" ]; then
    :
  else
    printf '%s' "$body" > "$outfile"
  fi
  if [ "$want_code_suffix" = "true" ]; then
    printf '%s' "$code"
  fi
elif [ "$want_code_suffix" = "true" ]; then
  printf '%s\n%s' "$body" "$code"
else
  printf '%s' "$body"
fi
