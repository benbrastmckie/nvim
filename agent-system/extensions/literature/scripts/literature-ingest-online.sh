#!/usr/bin/env bash
# literature-ingest-online.sh - Online-discovery -> Zotero+PDF -> ingest bridge.
#
# Wires a single literature-discover.sh Tier-2/Tier-3 discovery record into: Zotero
# item-creation-or-attach (via zotero-write.sh's item-add/attach-file operations), the
# UNMODIFIED literature-ingest.sh pipeline (convert/chunk/index), a post-ingest index.json
# metadata patch, and specs/literature-index.json sub-index registration.
#
# ============================================================================================
# STABLE CONTRACT -- this header documents the input schema, directive tokens, and exit codes.
# This interface is depended on by other tooling built on top of the online-ingest bridge; do
# not change field names, token spellings, or exit-code numbers here without updating every
# downstream consumer (including commands/literature.md's Mode A wiring).
# ============================================================================================
#
# USAGE:
#   literature-ingest-online.sh --record '<json>' [--dry-run] [--idempotency-key KEY]
#   echo '<json>' | literature-ingest-online.sh [--dry-run] [--idempotency-key KEY]
#
# INPUT SCHEMA (one element of literature-discover.sh's JSON output array):
#   {
#     "title":     string,           # required
#     "authors":   string[],         # required (may be empty array)
#     "year":      integer|null,     # required key, nullable
#     "doc_id":    string,           # required. Tier 1: global index doc_id (not applicable to
#                                     # this bridge). Tier 2: Zotero citation_key. Tier 3:
#                                     # derived (doi-slug | arxiv_<id> | ss_<paperId> |
#                                     # unknown_<slug>).
#     "status":    "in_zotero_no_pdf" | "open_access" | "paywall",
#                                     # ("available"/"in_zotero" records do not need this bridge
#                                     # -- they already have a local file or attached PDF -- and
#                                     # are rejected as a usage error, exit 64.)
#     "tier":      2 | 3,
#     "doi":       string|null,      # tier 3 only; absent/null on tier 2
#     "arxiv_id":  string|null,      # tier 3 only; absent/null on tier 2. NOTE: there is no
#                                     # literal "arxiv" status -- arXiv hits are
#                                     # status=="open_access" with arxiv_id set. This script
#                                     # treats "arxiv" as that derived condition, never as a
#                                     # fourth status string.
#     "pdf_url":   string|null       # tier 3 only; absent/null on tier 2
#   }
#
# DIRECTIVE TOKENS (stdout, exactly ONE line, nothing else on stdout; rationale to stderr):
#   ONLINE_INGEST_NO_PDF                 No PDF is available or discoverable for this record
#                                         (status=="paywall"; status=="open_access" with no
#                                         usable pdf_url; or an in_zotero_no_pdf record whose
#                                         resolved Zotero item has no DOI / no Unpaywall OA
#                                         location). Honest, non-actionable stop. NO Zotero
#                                         write, NO download attempted. Never fabricated.
#   ONLINE_INGEST_DOWNLOAD_FAILED        curl failure (non-2xx / network) OR the downloaded
#                                         bytes failed the mandatory `%PDF` magic-byte gate.
#                                         NO Zotero write is ever attempted after this token.
#   ONLINE_INGEST_ZOTERO_CREATE_FAILED   `zotero-write.sh item-add` (create-item path) failed.
#   ONLINE_INGEST_ZOTERO_RESOLVE_FAILED  in_zotero_no_pdf path: could not resolve the discovery
#                                         record's citation_key to a real Zotero item key (tier
#                                         "absent" from zotero-resolve-pdf.sh, or a hard
#                                         resolver failure). Never invents a key.
#   ONLINE_INGEST_ZOTERO_ATTACH_FAILED   `zotero-write.sh attach-file` (existing-item path)
#                                         failed.
#   ONLINE_INGEST_PIPELINE_FAILED        The delegated, UNMODIFIED literature-ingest.sh call
#                                         (convert/chunk/index) exited non-zero for this file.
#   ONLINE_INGEST_INGESTED               Full success via the create-item (open_access/arXiv)
#                                         path: Zotero item + PDF created and attached, corpus
#                                         chunks produced, index.json patched, sub-index
#                                         registered.
#   ONLINE_INGEST_ATTACHED               Full success via the attach-to-existing
#                                         (in_zotero_no_pdf) path: PDF attached to the existing
#                                         Zotero item (or found already attached, in the
#                                         corrective edge case documented in Phase 6 below),
#                                         then ingested/patched/registered same as above.
#   ONLINE_INGEST_DUPLICATE_DETECTED     create-item path only: the DOI-normalized live-library
#                                         dedup check found an existing Zotero item whose `.doi`
#                                         matches the record's (normalized) DOI. Hard stop --
#                                         deliberately stricter than the non-blocking
#                                         check_duplicate_title() -- because the Web API performs
#                                         no server-side dedup. NO Zotero write is attempted.
#   ONLINE_INGEST_DEDUP_CHECK_FAILED     create-item path only: the live dedup check itself could
#                                         not be performed (zotero-read.sh search failed or
#                                         returned unparseable output). Never conflated with "no
#                                         duplicate found" -- stops rather than proceeding without
#                                         a dedup guarantee, consistent with this script's
#                                         never-fabricate posture.
#
# EXPORT FRESHNESS + LIVE DEDUP GUARD: before either the create-item or the attach-to-existing
# branch runs its Zotero write, this script consults zotero-export-freshness.sh.
# ZOTERO_EXPORT_FRESH is the only clean pass; ZOTERO_EXPORT_STALE,
# ZOTERO_EXPORT_FRESHNESS_UNKNOWN, and ZOTERO_EXPORT_FRESHNESS_ABSENT are all treated as "not
# confirmed fresh" (matching zotero-search.sh's own treatment) and mark the run as requiring
# live-library re-verification of the classification -- re-verify-then-proceed, never an
# unconditional refusal, because the export is persistently stale in normal operation and an
# unconditional refusal would block all ingest. The concrete re-verification mechanism is the
# DOI-normalized, live-library dedup check (check_live_doi_duplicate(), see below), which
# performs a hard stop (ONLINE_INGEST_DUPLICATE_DETECTED, create-item path only) on a confirmed
# duplicate. A non-fresh classification with no DOI to check falls through honestly (logged, not
# silently treated as a pass) to the existing, non-blocking check_duplicate_title() heuristic.
#
# EXIT CODES:
#   0   ONLINE_INGEST_INGESTED or ONLINE_INGEST_ATTACHED printed (full success)
#   1   ONLINE_INGEST_NO_PDF printed (honest stop, no side effects)
#   2   ONLINE_INGEST_DOWNLOAD_FAILED printed
#   3   ONLINE_INGEST_ZOTERO_CREATE_FAILED printed
#   4   ONLINE_INGEST_ZOTERO_RESOLVE_FAILED printed
#   5   ONLINE_INGEST_ZOTERO_ATTACH_FAILED printed
#   6   ONLINE_INGEST_PIPELINE_FAILED printed
#   7   ONLINE_INGEST_DUPLICATE_DETECTED printed
#   8   ONLINE_INGEST_DEDUP_CHECK_FAILED printed
#   64  Argument/usage error or malformed/unsupported input record. NO directive token is
#       printed to stdout for this case (usage text goes to stderr only) -- callers can
#       distinguish "never classified" from every classified terminal state above by checking
#       whether stdout produced a token at all.
#
# --dry-run: stops immediately after classification succeeds (i.e. for a resolvable record --
#   ONLINE_INGEST_RESOLVABLE-equivalent internal state, or the in_zotero_no_pdf path). It prints
#   the classification's directive token PLUS a human-readable preview of the planned
#   `zotero-write.sh item-add`/`attach-file` and `literature-ingest.sh` invocations to stderr,
#   with NO PDF download, NO Zotero write, and NO delegated ingest call. The resolvable path DOES
#   perform the real, read-only export-freshness check and (when a DOI is present) the real
#   DOI-normalized live-library dedup check (a `zot search` read, never a write) and honors a
#   confirmed-duplicate hard stop exactly as the real path would -- an honest preview, not a
#   simulation, since neither check has a side effect. This mirrors "would run" previews used by
#   zotero-write.sh's own `--dry-run` operations. Exit code follows the same table above (0 for a
#   resolvable classification with no duplicate, 1 for ONLINE_INGEST_NO_PDF, 7 for a
#   dry-run-detected ONLINE_INGEST_DUPLICATE_DETECTED, etc).
#
# ENVIRONMENT:
#   LITERATURE_DIR    Global library root (default: ~/Projects/Literature), same convention as
#                      literature-ingest.sh/literature-discover.sh.
#   USER_EMAIL         Contact email for Unpaywall lookups (default: benbrastmckie@gmail.com),
#                      same convention as literature-discover.sh's tier3_search().
#
# NON-GOALS (do not modify): literature-ingest.sh, literature-convert.sh, literature-chunk.sh,
# literature-build-index.sh are all invoked unmodified. This script owns ONLY: classification,
# download+verification, the new zotero-write.sh item-add/attach-file calls, storage
# re-pointing, the post-ingest index.json metadata patch, and sub-index registration.
#
# See also: context/project/literature/patterns/zotero-item-creation.md (empirically confirmed
# -- and NOT confirmed -- `zot add --pdf` envelope fields, the magic-byte gate, and the storage
# re-pointing step).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LITERATURE_DIR="${LITERATURE_DIR:-$HOME/Projects/Literature}"
USER_EMAIL="${USER_EMAIL:-benbrastmckie@gmail.com}"
GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

log() { echo "[ingest-online] $*" >&2; }

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

show_usage() {
  cat >&2 << 'USAGE'
Usage:
  literature-ingest-online.sh --record '<json>' [--dry-run] [--idempotency-key KEY]
  echo '<json>' | literature-ingest-online.sh [--dry-run] [--idempotency-key KEY]

<json> is a single literature-discover.sh discovery record (one array element) with status
in_zotero_no_pdf, open_access, or paywall. See the header comment block in this script for the
full input schema, directive-token list, and exit-code table (STABLE CONTRACT).
USAGE
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

RECORD_ARG=""
DRY_RUN=false
IDEM_KEY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --record)
      RECORD_ARG="${2:-}"
      shift 2
      ;;
    --record=*)
      RECORD_ARG="${1#--record=}"
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --idempotency-key)
      IDEM_KEY="${2:-}"
      shift 2
      ;;
    --idempotency-key=*)
      IDEM_KEY="${1#--idempotency-key=}"
      shift
      ;;
    -h|--help)
      show_usage
      exit 0
      ;;
    *)
      echo "literature-ingest-online.sh: unknown argument: $1" >&2
      show_usage
      exit 64
      ;;
  esac
done

if [ -n "$RECORD_ARG" ]; then
  RECORD="$RECORD_ARG"
else
  if [ -t 0 ]; then
    echo "literature-ingest-online.sh: no --record given and stdin is a terminal" >&2
    show_usage
    exit 64
  fi
  RECORD="$(cat)"
fi

if ! echo "$RECORD" | jq -e . >/dev/null 2>&1; then
  echo "literature-ingest-online.sh: --record is not valid JSON" >&2
  exit 64
fi

TITLE="$(jq -r '.title // empty' <<<"$RECORD")"
DOC_ID="$(jq -r '.doc_id // empty' <<<"$RECORD")"
STATUS="$(jq -r '.status // empty' <<<"$RECORD")"
YEAR_RAW="$(jq -r '.year // empty' <<<"$RECORD")"
DOI_RAW="$(jq -r '.doi // empty' <<<"$RECORD")"
ARXIV_ID_RAW="$(jq -r '.arxiv_id // empty' <<<"$RECORD")"
PDF_URL_RAW="$(jq -r '.pdf_url // empty' <<<"$RECORD")"
AUTHORS_JSON="$(jq -c '.authors // []' <<<"$RECORD")"

if [ -z "$TITLE" ] || [ -z "$DOC_ID" ] || [ -z "$STATUS" ]; then
  echo "literature-ingest-online.sh: record missing required field(s) (title/doc_id/status)" >&2
  exit 64
fi

case "$STATUS" in
  in_zotero_no_pdf|open_access|paywall) : ;;
  *)
    echo "literature-ingest-online.sh: status \"$STATUS\" does not need this bridge (only in_zotero_no_pdf/open_access/paywall are handled -- available/in_zotero records already have a local file or PDF)" >&2
    exit 64
    ;;
esac

# ---------------------------------------------------------------------------
# Sanitize a stable doc_id-derived staging filename, matching literature-ingest.sh's own
# BASE_DOC_ID derivation so the eventual real doc_id lines up with $DOC_ID for the metadata
# patch below.
# ---------------------------------------------------------------------------
sanitize_doc_id() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr -cs '[:alnum:]_.-' '_' | sed -E 's/_+$//'
}

SANITIZED_DOC_ID="$(sanitize_doc_id "$DOC_ID")"
STAGING_DIR="$LITERATURE_DIR/.online-ingest-staging"
STAGING_PATH="$STAGING_DIR/${SANITIZED_DOC_ID}.pdf"

# ---------------------------------------------------------------------------
# Helper: emit exactly one directive token to stdout, rationale to stderr, then exit.
# ---------------------------------------------------------------------------
directive_stop() {
  local token="$1" code="$2" rationale="$3"
  log "$rationale"
  echo "$token"
  exit "$code"
}

# ---------------------------------------------------------------------------
# Helper: download + mandatory %PDF magic-byte verification. Never falls through to a Zotero
# write on failure of either curl or the magic-byte check.
# ---------------------------------------------------------------------------
download_and_verify() {
  local url="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if ! curl -sL --fail --max-time 30 -o "$dest" "$url" 2>/tmp/ingest-online-curl-stderr.$$; then
    log "download failed for $url: $(cat /tmp/ingest-online-curl-stderr.$$ 2>/dev/null)"
    rm -f /tmp/ingest-online-curl-stderr.$$ "$dest"
    return 1
  fi
  rm -f /tmp/ingest-online-curl-stderr.$$
  local magic
  magic="$(head -c4 "$dest" 2>/dev/null || true)"
  if [ "$magic" != "%PDF" ]; then
    log "magic-byte check failed for $url: expected %PDF, got \"$magic\" (likely an HTML landing/cookie-wall page, not a real PDF)"
    rm -f "$dest"
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Helper: optional, non-blocking pre-create duplicate-title check against the global
# index.json. A single bounded .zotero-title-sim.py --batch invocation scores $title against
# every index.json title in one process (short-circuiting on normalized-equality matches),
# replacing the former one-subprocess-per-title loop. Hard-timed at 10s and fail-open: any
# timeout, non-zero exit, or unparseable output is treated as "no duplicate found" and this
# function always returns 0. Recommendation-only per the plan -- logs a warning, never blocks.
# ---------------------------------------------------------------------------
check_duplicate_title() {
  local title="$1"
  local idx="$LITERATURE_DIR/index.json"
  [ -f "$idx" ] || return 0
  local result
  result="$(jq -r '.entries[]?.title // empty' "$idx" 2>/dev/null | timeout 10 python3 "$SCRIPT_DIR/.zotero-title-sim.py" --batch "$title" 2>/dev/null)" || true
  if [ -z "$result" ] || [[ "$result" != *$'\t'* ]]; then
    log "duplicate-title check skipped (timed out, failed, or produced no output; non-blocking, proceeding)"
    return 0
  fi
  local best_sim="${result%%$'\t'*}"
  local best_title="${result#*$'\t'}"
  [[ "$best_sim" =~ ^[0-9]+(\.[0-9]+)?$ ]] || return 0
  if [ -n "$best_title" ] && awk -v s="$best_sim" 'BEGIN{exit !(s>=0.85)}'; then
    log "WARNING: possible duplicate -- existing index.json entry \"$best_title\" has title similarity $best_sim to \"$title\" (non-blocking recommendation-only check; proceeding)"
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Helper: classify $LITERATURE_DIR/zotero-library.json's freshness relative to the live Zotero
# sqlite database via zotero-export-freshness.sh. ZOTERO_EXPORT_FRESH is the only clean pass;
# every other token (STALE, FRESHNESS_UNKNOWN, FRESHNESS_ABSENT) is "not confirmed fresh" and
# sets EXPORT_NEEDS_REVERIFICATION=true rather than stopping outright -- re-verify-then-proceed,
# matching how zotero-search.sh already treats these same tokens. Sets three globals:
#   EXPORT_FRESHNESS_TOKEN         the raw directive token
#   EXPORT_FRESHNESS_CONFIRMED     "true" only for ZOTERO_EXPORT_FRESH
#   EXPORT_NEEDS_REVERIFICATION    "true" for anything else; consumed by
#                                  check_live_doi_duplicate() below as the concrete
#                                  re-verification mechanism.
# ---------------------------------------------------------------------------
check_export_freshness() {
  local rc=0
  EXPORT_FRESHNESS_TOKEN="$("$SCRIPT_DIR/zotero-export-freshness.sh" 2>/tmp/ingest-online-freshness-stderr.$$)" || rc=$?
  local rationale
  rationale="$(cat /tmp/ingest-online-freshness-stderr.$$ 2>/dev/null || true)"
  rm -f /tmp/ingest-online-freshness-stderr.$$
  if [ "$rc" -ne 0 ] || [ -z "$EXPORT_FRESHNESS_TOKEN" ]; then
    log "WARNING: zotero-export-freshness.sh failed or produced no token (exit $rc); treating as not confirmed fresh: $rationale"
    EXPORT_FRESHNESS_TOKEN="ZOTERO_EXPORT_FRESHNESS_UNKNOWN"
  fi
  case "$EXPORT_FRESHNESS_TOKEN" in
    ZOTERO_EXPORT_FRESH)
      log "Export freshness: $EXPORT_FRESHNESS_TOKEN -- $rationale"
      EXPORT_FRESHNESS_CONFIRMED=true
      EXPORT_NEEDS_REVERIFICATION=false
      ;;
    *)
      log "WARNING: export freshness not confirmed ($EXPORT_FRESHNESS_TOKEN): $rationale -- live-library re-verification required before any item creation."
      EXPORT_FRESHNESS_CONFIRMED=false
      EXPORT_NEEDS_REVERIFICATION=true
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Helper: normalize a DOI for exact-equality comparison -- lowercase, and strip a leading
# https://doi.org/, http://doi.org/, or bare doi.org/ prefix. Load-bearing, not defensive-only:
# `zot search` with the URL-prefixed form returns zero hits while the bare lowercase form
# returns one, so an un-normalized comparison would silently miss real duplicates.
# ---------------------------------------------------------------------------
normalize_doi() {
  local doi="$1"
  doi="$(echo "$doi" | tr '[:upper:]' '[:lower:]')"
  doi="${doi#https://doi.org/}"
  doi="${doi#http://doi.org/}"
  doi="${doi#doi.org/}"
  echo "$doi"
}

# ---------------------------------------------------------------------------
# Helper: DOI-normalized, live-library duplicate check via `zotero-read.sh search`, which reads
# the live SQLite database (never the stale zotero-library.json export). A bare "search returned
# something" is NOT a match -- `zot search` also matches title/author/tag text, so results are
# filtered to an exact match on the normalized `.data[].doi` field (also normalized, since the
# live database stores DOIs in their original, non-lowercased case).
#
# Return codes (never both prints output AND returns non-zero for the same call):
#   0  duplicate found -- stdout is the matched item's key
#   1  no duplicate found
#   2  dedup could not be performed (zotero-read.sh failed or returned unparseable output) --
#      never conflated with "no duplicate found"
# ---------------------------------------------------------------------------
check_live_doi_duplicate() {
  local normalized_doi="$1"
  local search_out rc=0
  search_out="$("$SCRIPT_DIR/zotero-read.sh" search "$normalized_doi" 2>/tmp/ingest-online-dedup-stderr.$$)" || rc=$?
  local stderr_out
  stderr_out="$(cat /tmp/ingest-online-dedup-stderr.$$ 2>/dev/null || true)"
  rm -f /tmp/ingest-online-dedup-stderr.$$

  if [ "$rc" -ne 0 ]; then
    log "ERROR: zotero-read.sh search failed (exit $rc) while checking for a live duplicate of doi=$normalized_doi: $stderr_out"
    return 2
  fi
  if ! echo "$search_out" | jq -e . >/dev/null 2>&1; then
    log "ERROR: zotero-read.sh search returned unparseable output while checking doi=$normalized_doi"
    return 2
  fi

  local matched_key
  matched_key="$(jq -r --arg doi "$normalized_doi" '
      [ .[]? | select(
          (.doi // "" | ascii_downcase
            | sub("^https://doi\\.org/"; "")
            | sub("^http://doi\\.org/"; "")
            | sub("^doi\\.org/"; ""))
          == $doi
        ) ] | .[0].key // empty
    ' <<<"$search_out")"

  if [ -n "$matched_key" ]; then
    echo "$matched_key"
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# Helper: the resolvable (create-item) branch's pre-download checks -- DOI-normalized live
# dedup, which also serves as the concrete re-verification mechanism Phase 3's freshness gate
# defers to. Shared verbatim between the real resolvable path and its --dry-run preview: the
# dedup check is read-only (a `zot search`), so running it (and honoring its hard stop) under
# --dry-run is a genuine preview of the real path, not a simulation of one. A confirmed
# duplicate or a failed dedup check both stop via directive_stop() -- safe under --dry-run too,
# since directive_stop() never performs a write.
# ---------------------------------------------------------------------------
resolvable_predownload_checks() {
  if [ -z "$DOI_RAW" ]; then
    log "doc_id=$DOC_ID carries no DOI; DOI-normalized live dedup cannot run. Falling through to the non-blocking title-similarity check (dedup NOT silently treated as passed)."
    return 0
  fi

  NORMALIZED_DOI="$(normalize_doi "$DOI_RAW")"
  if [ "$EXPORT_NEEDS_REVERIFICATION" = "true" ]; then
    log "Export freshness not confirmed ($EXPORT_FRESHNESS_TOKEN); the DOI-normalized live-library dedup check below is the required re-verification against the live library."
  fi

  local dedup_rc=0
  DEDUP_MATCH_KEY="$(check_live_doi_duplicate "$NORMALIZED_DOI")" || dedup_rc=$?
  case "$dedup_rc" in
    0)
      directive_stop "ONLINE_INGEST_DUPLICATE_DETECTED" 7 \
        "DOI-normalized live-library dedup found an existing Zotero item (key=$DEDUP_MATCH_KEY) matching doi=$NORMALIZED_DOI for doc_id=$DOC_ID; refusing to create a duplicate item. The Web API performs no server-side dedup, so this check is the only guard against it."
      ;;
    1)
      log "DOI-normalized live-library dedup: no existing item found for doi=$NORMALIZED_DOI (doc_id=$DOC_ID); proceeding."
      ;;
    *)
      directive_stop "ONLINE_INGEST_DEDUP_CHECK_FAILED" 8 \
        "DOI-normalized live-library dedup could not be performed for doc_id=$DOC_ID (doi=$NORMALIZED_DOI): zotero-read.sh search failed or returned unparseable output. Refusing to proceed without a dedup guarantee, consistent with this script's never-fabricate posture."
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Helper: extract the first non-empty/non-null value across several plausible jq field paths
# on a JSON envelope. `zot add --pdf`'s exact data.* field names are NOT independently
# confirmed against a real call yet -- see
# zotero-item-creation.md. This defensive multi-path lookup is the mitigation.
# ---------------------------------------------------------------------------
extract_envelope_field() {
  local envelope="$1"
  shift
  local path val
  for path in "$@"; do
    val="$(jq -r "$path // empty" <<<"$envelope" 2>/dev/null || true)"
    if [ -n "$val" ] && [ "$val" != "null" ]; then
      echo "$val"
      return 0
    fi
  done
  return 1
}

# ---------------------------------------------------------------------------
# Helper: resolve the durable Zotero-managed storage/<attachmentKey>/<filename> path from a
# zotero-write.sh item-add/attach-file JSON envelope. Falls back to a directory glob if the
# filename field is not found. Returns non-zero (caller falls back to the staging path) if
# nothing resolves.
# ---------------------------------------------------------------------------
resolve_storage_path_from_envelope() {
  local envelope="$1"

  local att_key=""
  att_key="$(extract_envelope_field "$envelope" \
    '.data.attachment.key' '.data.attachmentKey' '.data.attachment_key' \
    '.data.attachments[0].key' '.data.attachments[0].itemKey')" || return 1

  local att_filename=""
  att_filename="$(extract_envelope_field "$envelope" \
    '.data.attachment.filename' '.data.filename' \
    '.data.attachments[0].filename')" || true

  local zotero_sqlite zotero_data_dir storage_root
  zotero_sqlite="$("$SCRIPT_DIR/zotero-resolve-sqlite-path.sh")"
  zotero_data_dir="$(dirname "$zotero_sqlite")"
  storage_root="$zotero_data_dir/storage"

  if [ -n "$att_filename" ]; then
    local candidate="$storage_root/$att_key/$att_filename"
    if [ -f "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  fi

  local att_dir="$storage_root/$att_key"
  if [ -d "$att_dir" ]; then
    local found
    found="$(find "$att_dir" -maxdepth 1 -name '*.pdf' 2>/dev/null | head -1)"
    if [ -n "$found" ]; then
      echo "$found"
      return 0
    fi
  fi

  return 1
}

# ---------------------------------------------------------------------------
# Helper: post-ingest global index.json metadata patch. Scoped as new logic in THIS script
# only (literature-ingest.sh's core loop is never modified). Idempotent: re-running for the
# same doc_id updates the entry in place, never duplicates.
# ---------------------------------------------------------------------------
patch_global_index() {
  local doc_id="$1" title="$2" authors_json="$3" year_json="$4" doi_json="$5" \
        arxiv_json="$6" zkey_json="$7" zpath_json="$8"
  local idx="$LITERATURE_DIR/index.json"
  if [ ! -f "$idx" ]; then
    log "WARNING: global index.json not found at $idx; cannot patch metadata for $doc_id"
    return 1
  fi
  local tmp
  tmp="$(mktemp)"
  jq --arg doc_id "$doc_id" --arg title "$title" \
     --argjson authors "$authors_json" --argjson year "$year_json" \
     --argjson doi "$doi_json" --argjson arxiv_id "$arxiv_json" \
     --argjson zotero_key "$zkey_json" --argjson zotero_path "$zpath_json" \
     '.entries |= map(if .doc_id == $doc_id then
        . + {title: $title, authors: $authors, year: $year, doi: $doi,
             arxiv_id: $arxiv_id, zotero_key: $zotero_key, zotero_path: $zotero_path}
      else . end)' "$idx" > "$tmp" && mv "$tmp" "$idx"
  log "Patched global index.json entry for doc_id=$doc_id with real metadata"
}

# ---------------------------------------------------------------------------
# Helper: upsert an entry into the per-repo sub-index (specs/literature-index.json), mirroring
# the jq-upsert sketch already in commands/literature.md step_2.5. Idempotent (remove-then-
# append), so a repeat run updates in place rather than duplicating rows.
# ---------------------------------------------------------------------------
upsert_subindex() {
  local doc_id="$1"
  local sub_idx="$GIT_ROOT/specs/literature-index.json"
  if [ ! -f "$sub_idx" ]; then
    echo '{"entries": []}' > "$sub_idx"
  fi
  local added
  added="$(date -u +%Y-%m-%d)"
  local tmp
  tmp="$(mktemp)"
  jq --arg doc_id "$doc_id" --arg added "$added" \
     '.entries |= ([.[]? | select(.doc_id != $doc_id)] +
        [{doc_id: $doc_id, relevance: "discovered via online-ingest bridge", added: $added, source: "discover"}])' \
     "$sub_idx" > "$tmp" && mv "$tmp" "$sub_idx"
  log "Registered doc_id=$doc_id in $sub_idx (source: discover)"
}

# ---------------------------------------------------------------------------
# Helper: delegate to the UNMODIFIED literature-ingest.sh, capture its stdout to recover the
# real ingested doc_id (which may legitimately differ from $SANITIZED_DOC_ID -- see
# literature-ingest.sh's own belt-and-suspenders comment). Returns 1 on any non-zero exit.
# ---------------------------------------------------------------------------
run_ingest_pipeline() {
  local pdf_path="$1"
  local ingest_script="$SCRIPT_DIR/literature-ingest.sh"
  if [ ! -x "$ingest_script" ]; then
    log "ERROR: literature-ingest.sh not found or not executable at $ingest_script"
    return 1
  fi

  local stdout_capture exit_code
  if stdout_capture=$("$ingest_script" "$pdf_path" --no-local 2>&1); then
    exit_code=0
  else
    exit_code=$?
  fi

  echo "$stdout_capture" | sed 's/^/[ingest-online]   /' >&2

  if [ "$exit_code" -ne 0 ]; then
    return 1
  fi

  # literature-ingest.sh's log_out() prefixes stdout lines with "[ingest] ", so the per-file
  # success line actually reads "[ingest] Ingested: <doc_id> (N chunks)", not a bare "Ingested:
  # " line -- match that first; fall back to the un-prefixed final-summary line ("Documents
  # ingested: <doc_id>", printed via plain `echo`) if the per-file line is ever not found.
  INGESTED_REAL_DOC_ID="$(echo "$stdout_capture" | grep -m1 '^\[ingest\] Ingested: ' | sed -E 's/^\[ingest\] Ingested: ([^ ]+).*/\1/')"
  if [ -z "$INGESTED_REAL_DOC_ID" ]; then
    INGESTED_REAL_DOC_ID="$(echo "$stdout_capture" | grep -m1 '^Documents ingested: ' | sed -E 's/^Documents ingested: ([^ ]+).*/\1/')"
  fi
  if [ -z "$INGESTED_REAL_DOC_ID" ]; then
    log "WARNING: literature-ingest.sh exited 0 but no ingested-doc_id line was found; falling back to sanitized doc_id"
    INGESTED_REAL_DOC_ID="$SANITIZED_DOC_ID"
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Helper: shared ONLINE_INGEST_PIPELINE_FAILED diagnostic pointer, used verbatim by both
# directive_stop sites below (resolvable/create-item path and existing_no_pdf/attach path) so
# the two rationales cannot drift. Message text ONLY -- no automatic retry, tier selection, or
# classifier: the converter-tier characterization (context/guides/literature-organization.md,
# "Converter Tier Selection" section) established that Class A and Class B gate-rejection
# classes respond OPPOSITELY to the fallback converter tier, and that "No automatic tier
# selection exists or is intended." The remedy stays a manual operator decision.
#
# Note on the "preserved rejected markdown" the plan for this fix originally assumed: it is NOT
# actually preserved through this delegation path -- literature-ingest.sh writes
# literature-convert.sh's .rejected sibling into its own `mktemp -d` TMP_MD_DIR, then `rm -rf`s
# that directory on the quality-gate-rejection continue branch before returning. This hint is
# corrected accordingly: it points at re-running literature-convert.sh manually against the
# still-durable resolved PDF path, not at a file that no longer exists by the time this rationale
# is read.
# ---------------------------------------------------------------------------
pipeline_failed_diagnostic_hint() {
  local doc_id="$1" resolved_path="$2"
  cat << HINT
Diagnostic pointer for doc_id=$doc_id: literature-ingest.sh's own log output above already
carries the raw failure reason (e.g. "QUALITY GATE FAILED: ..." for a quality-gate rejection).
Its .rejected sibling markdown is NOT preserved here -- literature-ingest.sh deletes its
temporary working directory before returning. To inspect the annotated hit positions yourself,
manually re-run: literature-convert.sh "$resolved_path" <output-dir>, then inspect the resulting
<output-dir>/<doc_id>.md.rejected. Apply the manual remedy from
context/guides/literature-organization.md's "Converter Tier Selection" section: hits positionally
concentrated near a structural region or footnote/superscript markers (Class A) -- reconvert with
LITERATURE_CONVERTER=fallback; hits scattered singly at otherwise-clean sentence boundaries
(Class B) -- re-OCR the source first, then reconvert (in-pipeline: LITERATURE_OCR_FORCE=1
LITERATURE_CONVERTER=ocr). A genuinely image-only source (Class C: conversion exits 2, not 3,
with a NO TEXT LAYER: stderr marker) needs the same OCR mode WITHOUT the force flag:
LITERATURE_CONVERTER=ocr. This is a MANUAL decision only: no automatic tier or mode selection or
retry is performed, since Classes A/B/C respond differently to the fallback engine and to OCR.
HINT
}

# ---------------------------------------------------------------------------
# Helper: year -> jq-safe JSON (null if empty/non-numeric)
# ---------------------------------------------------------------------------
year_to_json() {
  local y="$1"
  if [ -z "$y" ] || [ "$y" = "null" ] || ! [[ "$y" =~ ^[0-9]+$ ]]; then
    echo "null"
  else
    echo "$y"
  fi
}

str_or_null_json() {
  local s="$1"
  if [ -z "$s" ] || [ "$s" = "null" ]; then
    echo "null"
  else
    jq -n --arg s "$s" '$s'
  fi
}

YEAR_JSON="$(year_to_json "$YEAR_RAW")"
DOI_JSON="$(str_or_null_json "$DOI_RAW")"
ARXIV_JSON="$(str_or_null_json "$ARXIV_ID_RAW")"

# ===========================================================================
# Classification (mirrors zotero-export-status.sh's honest directive-token pattern)
# ===========================================================================

if [ "$STATUS" = "in_zotero_no_pdf" ]; then
  CLASSIFICATION="existing_no_pdf"
  log "Classified doc_id=$DOC_ID as existing_no_pdf (status=in_zotero_no_pdf): attach-to-existing-item path."
elif [ "$STATUS" = "open_access" ] && [ -n "$PDF_URL_RAW" ]; then
  CLASSIFICATION="resolvable"
  if [ -n "$ARXIV_ID_RAW" ]; then
    log "Classified doc_id=$DOC_ID as resolvable (status=open_access, arxiv_id=$ARXIV_ID_RAW present): create-item path."
  else
    log "Classified doc_id=$DOC_ID as resolvable (status=open_access, pdf_url present): create-item path."
  fi
else
  # status == "paywall", or open_access with no usable pdf_url.
  directive_stop "ONLINE_INGEST_NO_PDF" 1 \
    "doc_id=$DOC_ID status=$STATUS has no usable PDF (paywall, or open_access with no pdf_url); no download attempted, no fabricated source. Falls back to today's SOURCES.md-only behavior."
fi

# ===========================================================================
# --dry-run: stop here with a preview of planned invocations, no side effects.
# ===========================================================================
if [ "$DRY_RUN" = "true" ]; then
  check_export_freshness
  if [ "$CLASSIFICATION" = "resolvable" ]; then
    log "[dry-run] Export freshness: $EXPORT_FRESHNESS_TOKEN (needs_reverification=$EXPORT_NEEDS_REVERIFICATION)"
    resolvable_predownload_checks
    log "[dry-run] DOI-normalized live-library dedup passed (or no DOI to check); would proceed"
    log "[dry-run] Would download: $PDF_URL_RAW -> $STAGING_PATH"
    log "[dry-run] Would run: $SCRIPT_DIR/zotero-write.sh item-add --pdf $STAGING_PATH ${DOI_RAW:+--doi $DOI_RAW} --idempotency-key ${IDEM_KEY:-online-ingest-$SANITIZED_DOC_ID}"
    log "[dry-run] Would run: $SCRIPT_DIR/literature-ingest.sh <resolved_storage_or_staging_path> --no-local"
    log "[dry-run] Would patch $LITERATURE_DIR/index.json and register $GIT_ROOT/specs/literature-index.json for doc_id=$DOC_ID"
    echo "ONLINE_INGEST_INGESTED"
    exit 0
  else
    log "[dry-run] Export freshness: $EXPORT_FRESHNESS_TOKEN (needs_reverification=$EXPORT_NEEDS_REVERIFICATION; attach-to-existing path performs no dedup check, matching the real path)"
    log "[dry-run] Would resolve doc_id=$DOC_ID's citation_key to a real Zotero item key via zotero-resolve-pdf.sh"
    log "[dry-run] Would (if a PDF URL is discoverable) download + verify, then run: $SCRIPT_DIR/zotero-write.sh attach-file <resolved_key> $STAGING_PATH --idempotency-key ${IDEM_KEY:-online-ingest-attach-$SANITIZED_DOC_ID}"
    log "[dry-run] Would run: $SCRIPT_DIR/literature-ingest.sh <resolved_storage_or_staging_path> --no-local"
    log "[dry-run] Would patch $LITERATURE_DIR/index.json and register $GIT_ROOT/specs/literature-index.json for doc_id=$DOC_ID"
    echo "ONLINE_INGEST_ATTACHED"
    exit 0
  fi
fi

# ===========================================================================
# Resolvable (open_access / arXiv) path: download + verify + create-item + delegate + patch
# ===========================================================================
if [ "$CLASSIFICATION" = "resolvable" ]; then
  check_export_freshness

  resolvable_predownload_checks

  check_duplicate_title "$TITLE"

  if ! download_and_verify "$PDF_URL_RAW" "$STAGING_PATH"; then
    directive_stop "ONLINE_INGEST_DOWNLOAD_FAILED" 2 \
      "download or %PDF magic-byte verification failed for doc_id=$DOC_ID, pdf_url=$PDF_URL_RAW; no Zotero write attempted."
  fi
  log "Downloaded and verified PDF for doc_id=$DOC_ID at $STAGING_PATH"

  ZW_CMD=("$SCRIPT_DIR/zotero-write.sh" item-add --pdf "$STAGING_PATH")
  if [ -n "$DOI_RAW" ]; then
    ZW_CMD+=(--doi "$DOI_RAW")
  elif [ -n "$ARXIV_ID_RAW" ]; then
    # `zot add --pdf`'s _add_from_pdf hard-fails (exit 3, "No DOI found in PDF") when it cannot
    # regex a DOI out of the PDF's own first two pages -- see zotero-item-creation.md Sec 1. For
    # an arXiv-only record (no real doi, but an arxiv_id) we bypass that regex entirely by
    # passing arXiv's own mechanical DataCite DOI as --doi. This is NOT a resolved,
    # Crossref-registered published-venue DOI -- it is a fallback identifier that exists solely
    # to satisfy zot's DOI requirement so the item gets created at all. Crossref will not
    # resolve it, so the created item is metadata-bare on the Zotero side (accepted tradeoff,
    # documented in zotero-item-creation.md Sec 1/6); the corpus-side index.json metadata is
    # unaffected since DOI_JSON below still reflects the real (null) doi, never this synthesized
    # one.
    SYNTH_DOI="10.48550/arXiv.$ARXIV_ID_RAW"
    log "doc_id=$DOC_ID has no real DOI but arxiv_id=$ARXIV_ID_RAW; using synthesized arXiv DOI $SYNTH_DOI as a --doi fallback to bypass zot add --pdf's PDF-text DOI regex (never treated as a resolved published-venue DOI)."
    ZW_CMD+=(--doi "$SYNTH_DOI")
  fi
  ZW_CMD+=(--idempotency-key "${IDEM_KEY:-online-ingest-$SANITIZED_DOC_ID}")

  ITEM_ADD_EXIT=0
  ITEM_ADD_STDOUT="$("${ZW_CMD[@]}" 2>/tmp/ingest-online-item-add-stderr.$$)" || ITEM_ADD_EXIT=$?
  ITEM_ADD_STDERR="$(cat /tmp/ingest-online-item-add-stderr.$$ 2>/dev/null || true)"
  rm -f /tmp/ingest-online-item-add-stderr.$$

  if [ "$ITEM_ADD_EXIT" -ne 0 ]; then
    # The PDF was already downloaded and %PDF-verified at $STAGING_PATH above; item-add failing
    # after that point must not leak it -- remove it before stopping (download_and_verify()
    # already handles its own two failure branches, so this is the only staging leak on this path).
    rm -f "$STAGING_PATH"
    directive_stop "ONLINE_INGEST_ZOTERO_CREATE_FAILED" 3 \
      "zotero-write.sh item-add failed for doc_id=$DOC_ID (exit $ITEM_ADD_EXIT): $ITEM_ADD_STDERR"
  fi
  log "Created Zotero item for doc_id=$DOC_ID via item-add"

  ZOTERO_ITEM_KEY="$(extract_envelope_field "$ITEM_ADD_STDOUT" '.data.key' '.data.item.key' '.data.itemKey')" || ZOTERO_ITEM_KEY=""
  RESOLVED_PDF_PATH="$(resolve_storage_path_from_envelope "$ITEM_ADD_STDOUT")" || {
    log "WARNING: could not resolve Zotero-managed storage path from the item-add envelope; falling back to the staging download path ($STAGING_PATH) -- source_path/zotero_path will point at a less durable location. Flagged as a follow-up, not a silent success."
    RESOLVED_PDF_PATH="$STAGING_PATH"
  }
  log "Using PDF path for ingest delegation: $RESOLVED_PDF_PATH"

  if ! run_ingest_pipeline "$RESOLVED_PDF_PATH"; then
    directive_stop "ONLINE_INGEST_PIPELINE_FAILED" 6 \
      "literature-ingest.sh delegate failed for doc_id=$DOC_ID (source: $RESOLVED_PDF_PATH)

$(pipeline_failed_diagnostic_hint "$DOC_ID" "$RESOLVED_PDF_PATH")"
  fi
  log "literature-ingest.sh reported ingested doc_id=$INGESTED_REAL_DOC_ID"

  ZKEY_JSON="$(str_or_null_json "$ZOTERO_ITEM_KEY")"
  ZPATH_JSON="$(str_or_null_json "$RESOLVED_PDF_PATH")"
  patch_global_index "$INGESTED_REAL_DOC_ID" "$TITLE" "$AUTHORS_JSON" "$YEAR_JSON" \
    "$DOI_JSON" "$ARXIV_JSON" "$ZKEY_JSON" "$ZPATH_JSON" || true
  upsert_subindex "$INGESTED_REAL_DOC_ID"

  echo "ONLINE_INGEST_INGESTED"
  exit 0
fi

# ===========================================================================
# Existing-no-pdf (in_zotero_no_pdf) path: resolve real key -> attach -> delegate -> patch
# ===========================================================================
if [ "$CLASSIFICATION" = "existing_no_pdf" ]; then
  check_export_freshness
  if [ "$EXPORT_NEEDS_REVERIFICATION" = "true" ]; then
    log "Export freshness not confirmed ($EXPORT_FRESHNESS_TOKEN) for doc_id=$DOC_ID; flagging for visibility. This branch resolves the real Zotero item key live via zotero-resolve-pdf.sh below (never from the stale export), and already handles a stale-snapshot classification via its own non-empty resolved_path corrective edge case -- that existing behavior is unchanged by this gate."
  fi

  RESOLVER_RECORD="$(jq -n --arg title "$TITLE" --argjson authors "$AUTHORS_JSON" --argjson year "$YEAR_JSON" \
    '{title: $title, authors: $authors, year: $year, zotero_key: null}')"

  RESOLVE_EXIT=0
  RESOLVE_OUT="$(jq -n --arg doc_id "$DOC_ID" --argjson record "$RESOLVER_RECORD" '{doc_id: $doc_id, record: $record}' \
    | "$SCRIPT_DIR/zotero-resolve-pdf.sh" 2>/tmp/ingest-online-resolve-stderr.$$)" || RESOLVE_EXIT=$?
  RESOLVE_STDERR="$(cat /tmp/ingest-online-resolve-stderr.$$ 2>/dev/null || true)"
  rm -f /tmp/ingest-online-resolve-stderr.$$

  if [ "$RESOLVE_EXIT" -ne 0 ]; then
    directive_stop "ONLINE_INGEST_ZOTERO_RESOLVE_FAILED" 4 \
      "zotero-resolve-pdf.sh hard-failed for doc_id=$DOC_ID: $RESOLVE_STDERR"
  fi

  RESOLVE_TIER="$(jq -r '.tier // "absent"' <<<"$RESOLVE_OUT")"
  if [ "$RESOLVE_TIER" = "absent" ]; then
    directive_stop "ONLINE_INGEST_ZOTERO_RESOLVE_FAILED" 4 \
      "could not resolve doc_id=$DOC_ID's citation_key to a real Zotero item key (tier=absent); refusing to invent one."
  fi

  ZOTERO_ITEM_KEY="$(jq -r '.zotero_key // empty' <<<"$RESOLVE_OUT")"
  EXISTING_RESOLVED_PATH="$(jq -r '.resolved_path // empty' <<<"$RESOLVE_OUT")"
  ZOTERO_DOI="$(jq -r '.zotero_doi // empty' <<<"$RESOLVE_OUT")"

  if [ -z "$ZOTERO_ITEM_KEY" ]; then
    directive_stop "ONLINE_INGEST_ZOTERO_RESOLVE_FAILED" 4 \
      "zotero-resolve-pdf.sh returned tier=$RESOLVE_TIER but no zotero_key for doc_id=$DOC_ID"
  fi
  log "Resolved doc_id=$DOC_ID to Zotero item key $ZOTERO_ITEM_KEY (tier=$RESOLVE_TIER)"

  if [ -n "$EXISTING_RESOLVED_PATH" ]; then
    # Corrective edge case: the Tier-2 in_zotero_no_pdf classification came from a stale
    # zotero-library.json snapshot, but the resolver's live/sqlite check found the item
    # already HAS a PDF attached. Skip download+attach entirely; use it directly.
    log "Zotero item $ZOTERO_ITEM_KEY already has a PDF attached at $EXISTING_RESOLVED_PATH (stale in_zotero_no_pdf snapshot) -- skipping attach-file, using it directly."
    RESOLVED_PDF_PATH="$EXISTING_RESOLVED_PATH"
  else
    check_duplicate_title "$TITLE"

    PDF_URL_FOR_ATTACH=""
    if [ -n "$ZOTERO_DOI" ] && [ "$ZOTERO_DOI" != "null" ]; then
      UW_RESULT="$(curl -s --max-time 10 "https://api.unpaywall.org/v2/${ZOTERO_DOI}?email=${USER_EMAIL}" 2>/dev/null || true)"
      if [ -n "$UW_RESULT" ]; then
        OA_URL="$(jq -r '.best_oa_location.url // empty' <<<"$UW_RESULT" 2>/dev/null || true)"
        [ -n "$OA_URL" ] && [ "$OA_URL" != "null" ] && PDF_URL_FOR_ATTACH="$OA_URL"
      fi
    fi

    if [ -z "$PDF_URL_FOR_ATTACH" ]; then
      directive_stop "ONLINE_INGEST_NO_PDF" 1 \
        "resolved existing Zotero item $ZOTERO_ITEM_KEY for doc_id=$DOC_ID but no PDF URL is discoverable (no DOI on the resolved item, or Unpaywall found no OA location); honest stop, no fabricated download."
    fi

    if ! download_and_verify "$PDF_URL_FOR_ATTACH" "$STAGING_PATH"; then
      directive_stop "ONLINE_INGEST_DOWNLOAD_FAILED" 2 \
        "download or %PDF magic-byte verification failed for doc_id=$DOC_ID, pdf_url=$PDF_URL_FOR_ATTACH; no Zotero write attempted."
    fi
    log "Downloaded and verified PDF for doc_id=$DOC_ID at $STAGING_PATH (via Unpaywall DOI lookup)"

    ATTACH_EXIT=0
    ATTACH_STDOUT="$("$SCRIPT_DIR/zotero-write.sh" attach-file "$ZOTERO_ITEM_KEY" "$STAGING_PATH" \
      --idempotency-key "${IDEM_KEY:-online-ingest-attach-$SANITIZED_DOC_ID}" 2>/tmp/ingest-online-attach-stderr.$$)" || ATTACH_EXIT=$?
    ATTACH_STDERR="$(cat /tmp/ingest-online-attach-stderr.$$ 2>/dev/null || true)"
    rm -f /tmp/ingest-online-attach-stderr.$$

    if [ "$ATTACH_EXIT" -ne 0 ]; then
      # Same staging leak as the create-item path above: the PDF was already downloaded and
      # %PDF-verified at $STAGING_PATH; attach-file failing after that must not leak it.
      rm -f "$STAGING_PATH"
      directive_stop "ONLINE_INGEST_ZOTERO_ATTACH_FAILED" 5 \
        "zotero-write.sh attach-file failed for doc_id=$DOC_ID, key=$ZOTERO_ITEM_KEY (exit $ATTACH_EXIT): $ATTACH_STDERR"
    fi
    log "Attached PDF to existing Zotero item $ZOTERO_ITEM_KEY for doc_id=$DOC_ID"

    RESOLVED_PDF_PATH="$(resolve_storage_path_from_envelope "$ATTACH_STDOUT")" || {
      log "WARNING: could not resolve Zotero-managed storage path from the attach-file envelope; falling back to the staging download path ($STAGING_PATH). Flagged as a follow-up, not a silent success."
      RESOLVED_PDF_PATH="$STAGING_PATH"
    }
  fi

  log "Using PDF path for ingest delegation: $RESOLVED_PDF_PATH"

  if ! run_ingest_pipeline "$RESOLVED_PDF_PATH"; then
    directive_stop "ONLINE_INGEST_PIPELINE_FAILED" 6 \
      "literature-ingest.sh delegate failed for doc_id=$DOC_ID (source: $RESOLVED_PDF_PATH)

$(pipeline_failed_diagnostic_hint "$DOC_ID" "$RESOLVED_PDF_PATH")"
  fi
  log "literature-ingest.sh reported ingested doc_id=$INGESTED_REAL_DOC_ID"

  ZKEY_JSON="$(str_or_null_json "$ZOTERO_ITEM_KEY")"
  ZPATH_JSON="$(str_or_null_json "$RESOLVED_PDF_PATH")"
  patch_global_index "$INGESTED_REAL_DOC_ID" "$TITLE" "$AUTHORS_JSON" "$YEAR_JSON" \
    "$DOI_JSON" "$ARXIV_JSON" "$ZKEY_JSON" "$ZPATH_JSON" || true
  upsert_subindex "$INGESTED_REAL_DOC_ID"

  echo "ONLINE_INGEST_ATTACHED"
  exit 0
fi

# Unreachable: CLASSIFICATION is always set to "resolvable" or "existing_no_pdf" above, or the
# script has already exited via directive_stop for ONLINE_INGEST_NO_PDF.
echo "literature-ingest-online.sh: internal error -- unclassified state" >&2
exit 64
