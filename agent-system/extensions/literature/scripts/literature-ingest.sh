#!/usr/bin/env bash
# literature-ingest.sh - Main ingestion entry point for the literature pipeline
#
# Usage:
#   literature-ingest.sh <path>                  # Ingest PDF/DJVU file or directory
#   literature-ingest.sh --zotero <key>           # Ingest from Zotero key lookup
#   literature-ingest.sh <path> --no-local        # Skip local-loading prompt
#   literature-ingest.sh <path> --local           # Auto-accept local loading
#
# Pipeline:
#   1. Resolve source (file / directory / zotero key)
#   2. For each PDF/DJVU: convert to markdown (literature-convert.sh)
#   3. For each markdown: chunk (literature-chunk.sh)
#   4. Update global index.json
#   5. Rebuild global .literature.db (literature-build-index.sh --global)
#   6. Offer local loading (copy to specs/literature/, rebuild local index)
#
# Placement: every new document lands at $LITERATURE_DIR/sources/<doc_id>/, never at the
# old top-level $LITERATURE_DIR/<doc_id>/. Two reasons this is load-bearing, not cosmetic:
#   - literature-fidelity-audit.sh targets sources/<dir>/ exclusively; a top-level entry is
#     never matched or stamped with provenance_fidelity.
#   - The index-entry .path field's sources/<dir>/ component IS the bridge this extension
#     uses to derive the FTS chunks_data.doc_id from index.json (see literature-doc-key.sh).
#     A top-level entry breaks that derivation for itself.
#   literature-build-index.sh discovers manifests via a recursive `find -name chunks.json`,
#   so placement is FTS-neutral -- this is a fidelity/bridge-eligibility change, not an
#   FTS-discovery one.
#
# Environment:
#   LITERATURE_DIR  — Global library path (default: ~/Projects/Literature)
#   ZOTERO_LIBRARY_PATH — Path to zotero-library.json (default: ~/Projects/Literature/zotero-library.json)
#
# Exit codes:
#   0 — success (at least one file ingested; see the printed summary for any
#       per-file hard failures or quality-gate rejections mixed in)
#   1 — argument error
#   2 — no source files found
#   3 — all conversions failed (hard failures and/or quality-gate rejections —
#       the printed summary and log lines distinguish which)
#
# Per-file conversion outcomes: literature-convert.sh's
# exit code is checked explicitly per file, not swallowed by a `| tail -1`
# pipe. Exit 3 from literature-convert.sh (quality-gate rejection — the
# engine produced output but it failed the correctness gate) is tracked in a
# DISTINCT "Files quality-gate-failed" counter/list, separate from "Files
# failed" (hard failures: missing input, all engine tiers empty). Both are
# named explicitly in the final "=== Ingestion Summary ===" block — neither
# is silently absorbed into the other or lost in scrolled-past per-file
# stderr.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LITERATURE_DIR="${LITERATURE_DIR:-$HOME/Projects/Literature}"
ZOTERO_LIBRARY_PATH="${ZOTERO_LIBRARY_PATH:-$LITERATURE_DIR/zotero-library.json}"

log() { echo "[ingest] $*" >&2; }
log_out() { echo "[ingest] $*"; }

# --- Check required scripts ---
for script in literature-convert.sh literature-chunk.sh literature-build-index.sh; do
  if [ ! -x "$SCRIPT_DIR/$script" ]; then
    echo "[ingest] Required script not found or not executable: $SCRIPT_DIR/$script" >&2
    exit 1
  fi
done

# --- Argument parsing ---
SOURCE=""
ZOTERO_KEY=""
NO_LOCAL=0
AUTO_LOCAL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --zotero) ZOTERO_KEY="${2:-}"; shift 2 ;;
    --no-local) NO_LOCAL=1; shift ;;
    --local) AUTO_LOCAL=1; shift ;;
    -*) echo "[ingest] Unknown flag: $1" >&2; exit 1 ;;
    *) SOURCE="$1"; shift ;;
  esac
done

# --- Resolve source files ---
declare -a SOURCE_FILES=()

if [ -n "$ZOTERO_KEY" ]; then
  # Zotero key resolution
  if [ ! -f "$ZOTERO_LIBRARY_PATH" ]; then
    echo "[ingest] Zotero library not found: $ZOTERO_LIBRARY_PATH" >&2
    exit 1
  fi

  log "Looking up Zotero key: $ZOTERO_KEY"
  PDF_PATH=$(python3 << PYEOF
import json
import sys

zotero_path = "$ZOTERO_LIBRARY_PATH"
key = "$ZOTERO_KEY"

try:
    with open(zotero_path) as f:
        library = json.load(f)
except Exception as e:
    print(f"[ingest] Error reading Zotero library: {e}", file=sys.stderr)
    sys.exit(1)

# Search for key in library entries
entries = library if isinstance(library, list) else library.get('entries', library.get('items', []))

for entry in entries:
    entry_key = entry.get('key', '') or entry.get('zotero_key', '') or entry.get('id', '')
    if entry_key == key or key.lower() in str(entry_key).lower():
        # Look for PDF path
        pdf = entry.get('pdf_path') or entry.get('file', '') or entry.get('attachment', '')
        if pdf and (pdf.endswith('.pdf') or pdf.endswith('.djvu')):
            print(pdf)
            sys.exit(0)
        attachments = entry.get('attachments', [])
        for att in attachments:
            att_path = att.get('path', '') if isinstance(att, dict) else str(att)
            if att_path.endswith('.pdf') or att_path.endswith('.djvu'):
                print(att_path)
                sys.exit(0)

print(f"[ingest] No PDF found for Zotero key: {key}", file=sys.stderr)
sys.exit(1)
PYEOF
)
  if [ -n "$PDF_PATH" ] && [ -f "$PDF_PATH" ]; then
    SOURCE_FILES+=("$PDF_PATH")
  else
    echo "[ingest] Could not resolve Zotero key to PDF: $ZOTERO_KEY" >&2
    exit 2
  fi

elif [ -n "$SOURCE" ]; then
  if [ -f "$SOURCE" ]; then
    # Single file
    EXT="${SOURCE##*.}"
    EXT="${EXT,,}"
    if [[ "$EXT" == "pdf" || "$EXT" == "djvu" ]]; then
      SOURCE_FILES+=("$SOURCE")
    else
      echo "[ingest] Unsupported file type: $EXT (supported: pdf, djvu)" >&2
      exit 1
    fi
  elif [ -d "$SOURCE" ]; then
    # Directory: collect all PDFs and DJVUs
    while IFS= read -r f; do
      SOURCE_FILES+=("$f")
    done < <(find "$SOURCE" -maxdepth 2 \( -name "*.pdf" -o -name "*.djvu" \) | sort)

    if [ ${#SOURCE_FILES[@]} -eq 0 ]; then
      echo "[ingest] No PDF or DJVU files found in: $SOURCE" >&2
      exit 2
    fi
  else
    echo "[ingest] Source not found: $SOURCE" >&2
    exit 1
  fi
else
  echo "[ingest] Usage: $0 <path|--zotero key> [--no-local|--local]" >&2
  exit 1
fi

log "Found ${#SOURCE_FILES[@]} source file(s) to ingest"

# --- Ensure global library directory exists ---
mkdir -p "$LITERATURE_DIR"

# --- Process each source file ---
PROCESSED=0
FAILED=0
GATE_FAILED=0
OCR_NEEDED=0
declare -a INGESTED_DOC_IDS=()
declare -a GATE_FAILED_ENTRIES=()  # "file :: reason" for the final summary
declare -a OCR_NEEDED_ENTRIES=()   # "file :: reason" for the final summary

for source_file in "${SOURCE_FILES[@]}"; do
  log "Processing: $source_file"

  # Derive base doc_id from filename
  BASENAME=$(basename "$source_file")
  BASE_DOC_ID="${BASENAME%.*}"
  BASE_DOC_ID=$(echo "$BASE_DOC_ID" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr -cs '[:alnum:]_.-' '_')
  BASE_DOC_ID="${BASE_DOC_ID%_}"

  # Output directory for this document. Placed under sources/<id>/, matching the
  # already-fully-consolidated corpus layout (0 of 399 index entries have a non-
  # sources/-prefixed .path) -- see the pipeline comment block above for why this
  # placement matters beyond mere convention.
  DOC_DIR="$LITERATURE_DIR/sources/$BASE_DOC_ID"

  # Check for re-ingestion: warn if doc_id already exists
  GLOBAL_INDEX="$LITERATURE_DIR/index.json"
  if [ -f "$GLOBAL_INDEX" ]; then
    EXISTING=$(python3 -c "
import json
with open('$GLOBAL_INDEX') as f:
    idx = json.load(f)
entries = idx if isinstance(idx, list) else idx.get('entries', [])
existing = next((e for e in entries if e.get('doc_id','') == '$BASE_DOC_ID'), None)
print('yes' if existing else 'no')
" 2>/dev/null || echo "no")
    if [ "$EXISTING" == "yes" ]; then
      log "WARNING: Re-ingesting '$BASE_DOC_ID' — deleting old chunks"
      rm -rf "$DOC_DIR"
    fi
  fi

  mkdir -p "$DOC_DIR"

  # Step 1: Convert to markdown
  TMP_MD_DIR=$(mktemp -d)
  CONVERT_STDERR_FILE=$(mktemp)
  log "Converting: $BASENAME"

  # Capture the exit code explicitly: literature-convert.sh
  # now distinguishes exit 3 (quality-gate rejection) from exit 0 (success) and
  # exit 1/2 (hard failure). The `if CONVERT_STDOUT=$(...); then` form keeps
  # this under `set -e` safely — a plain `VAR=$(pipeline)` assignment would
  # abort the whole ingest run on any single file's non-zero exit.
  # shellcheck disable=SC2034  # CONVERT_STDOUT's captured value is never read -- the variable
  # assignment is structurally required for the `if VAR=$(...); then` idiom explained above,
  # which keeps this under set -e safely while still cleanly capturing CONVERT_EXIT below.
  if CONVERT_STDOUT=$("$SCRIPT_DIR/literature-convert.sh" "$source_file" "$TMP_MD_DIR" 2>"$CONVERT_STDERR_FILE"); then
    CONVERT_EXIT=0
  else
    CONVERT_EXIT=$?
  fi

  if [ "$CONVERT_EXIT" -eq 3 ]; then
    # Quality gate rejected the output — loud failure, NOT a generic failure.
    # Log distinctly, accumulate for the final gate-failed summary, and move on.
    GATE_REASON=$(grep -m1 'QUALITY GATE FAILED' "$CONVERT_STDERR_FILE" 2>/dev/null || echo "QUALITY GATE FAILED (reason unavailable)")
    log "QUALITY GATE FAILED: $BASENAME — ${GATE_REASON#*QUALITY GATE FAILED: }"
    GATE_FAILED_ENTRIES+=("$source_file :: ${GATE_REASON#*QUALITY GATE FAILED: }")
    GATE_FAILED=$((GATE_FAILED + 1))
    rm -rf "$TMP_MD_DIR"
    rm -f "$CONVERT_STDERR_FILE"
    # DOC_DIR was freshly mkdir -p'd above (line ~214) and is empty at this point -- the
    # pre-existing re-ingestion branch above already guarantees it is fresh-this-iteration
    # before conversion runs, so an unconditional rm -rf here cannot destroy a populated
    # corpus directory. Without this, a quality-gate-rejected file leaves an orphaned, empty,
    # unindexed sources/<doc_id>/ directory behind.
    rm -rf "$DOC_DIR"
    continue
  elif [ "$CONVERT_EXIT" -eq 2 ] && grep -q 'NO TEXT LAYER:' "$CONVERT_STDERR_FILE" 2>/dev/null; then
    # Exit 2 is OVERLOADED (see literature-convert.sh's header): this branch
    # keys off the distinctive `NO TEXT LAYER:` stderr marker (colon required
    # — literature-convert.sh's bash-level generic failure line ALSO mentions
    # the bare phrase "NO TEXT LAYER" in prose without a trailing colon, as an
    # explanatory aside; matching without the colon false-positive-matched
    # that line during verification), NEVER the bare exit code, so the
    # primary-tier-unavailable exit-2 case (no marker) falls through to the
    # generic hard-failure branch below untouched. Mirrors the exit-3 branch
    # above exactly.
    OCR_REASON=$(grep -m1 'NO TEXT LAYER:' "$CONVERT_STDERR_FILE" 2>/dev/null || echo "NO TEXT LAYER: (reason unavailable)")
    log "NEEDS OCR: $BASENAME — ${OCR_REASON#*NO TEXT LAYER: }"
    OCR_NEEDED_ENTRIES+=("$source_file :: ${OCR_REASON#*NO TEXT LAYER: }")
    OCR_NEEDED=$((OCR_NEEDED + 1))
    rm -rf "$TMP_MD_DIR"
    rm -f "$CONVERT_STDERR_FILE"
    # Same orphan-directory leak as the quality-gate branch above: DOC_DIR is
    # fresh-this-iteration (see the re-ingestion branch above), so this rm -rf is safe.
    rm -rf "$DOC_DIR"
    continue
  elif [ "$CONVERT_EXIT" -ne 0 ]; then
    log "ERROR: Conversion failed for $BASENAME (exit $CONVERT_EXIT)"
    sed 's/^/[ingest]   /' "$CONVERT_STDERR_FILE" >&2
    rm -rf "$TMP_MD_DIR"
    rm -f "$CONVERT_STDERR_FILE"
    FAILED=$((FAILED + 1))
    # Same orphan-directory leak as the quality-gate branch above.
    rm -rf "$DOC_DIR"
    continue
  fi

  rm -f "$CONVERT_STDERR_FILE"

  # Exit 0: the last line of stdout is the doc_id, but derive it from the
  # actual output filename too (belt-and-suspenders against stdout noise).
  # `|| true` is load-bearing, not decorative: under this script's `set -eo pipefail`, when
  # literature-convert.sh exits 0 but writes no .md (the branch immediately below exists
  # specifically to catch this), the unmatched `*.md` glob makes `ls` exit non-zero, and
  # pipefail propagates that through `head`/`xargs` to the whole command substitution --
  # without the guard, `set -e` kills the script outright with a bare, unexplained exit
  # instead of ever reaching the `if [ -z "$DOC_ID" ]` handling two lines down.
  DOC_ID=$(ls "$TMP_MD_DIR"/*.md 2>/dev/null | head -1 | xargs -I{} basename {} .md) || true

  if [ -z "$DOC_ID" ] || ! ls "$TMP_MD_DIR"/*.md >/dev/null 2>&1; then
    log "ERROR: Conversion reported success but no .md file found for $BASENAME"
    rm -rf "$TMP_MD_DIR"
    FAILED=$((FAILED + 1))
    # Same orphan-directory leak as the quality-gate branch above -- DOC_DIR still points at
    # sources/$BASE_DOC_ID here (the DOC_ID reassignment below never runs on this branch).
    rm -rf "$DOC_DIR"
    continue
  fi

  MD_FILE=$(ls "$TMP_MD_DIR"/*.md | head -1)
  DOC_ID=$(basename "$MD_FILE" .md)

  # Update DOC_DIR to use the actual doc_id, still under sources/<id>/
  DOC_DIR="$LITERATURE_DIR/sources/$DOC_ID"
  mkdir -p "$DOC_DIR"

  # Optional, safety-bounded cleanup: when the converter-derived $DOC_ID differs from
  # $BASE_DOC_ID, the earlier mkdir -p at line ~214 (sources/$BASE_DOC_ID) is now unused.
  # rmdir (never rm -rf) is the guard here -- it fails harmlessly on a non-empty directory,
  # which is exactly the protection needed against destroying a pre-existing populated corpus
  # directory that happens to share $BASE_DOC_ID's name for an unrelated reason.
  if [ "$DOC_ID" != "$BASE_DOC_ID" ]; then
    rmdir "$LITERATURE_DIR/sources/$BASE_DOC_ID" 2>/dev/null || true
  fi

  log "doc_id: $DOC_ID"

  # Step 2: Chunk the markdown
  log "Chunking: $MD_FILE"
  CHUNK_COUNT=$("$SCRIPT_DIR/literature-chunk.sh" "$MD_FILE" "$DOC_DIR" --doc-id "$DOC_ID" 2>/dev/null || echo "0")
  rm -rf "$TMP_MD_DIR"

  if [ "$CHUNK_COUNT" -eq 0 ] || [ ! -f "$DOC_DIR/chunks.json" ]; then
    log "ERROR: Chunking failed for $DOC_ID"
    FAILED=$((FAILED + 1))
    # DOC_DIR was reassigned above to sources/$DOC_ID (the converter-derived id, which may
    # differ from $BASE_DOC_ID) and freshly mkdir -p'd; same orphan-directory leak as the
    # quality-gate branch above.
    rm -rf "$DOC_DIR"
    continue
  fi

  log "Created $CHUNK_COUNT chunks in $DOC_DIR"

  # Step 3: Write document metadata
  INGESTED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  cat > "$DOC_DIR/metadata.json" << METAEOF
{
  "doc_id": "$DOC_ID",
  "title": "$DOC_ID",
  "authors": [],
  "year": null,
  "source_path": "$source_file",
  "chunks_dir": "$DOC_DIR",
  "chunk_count": $CHUNK_COUNT,
  "ingested_at": "$INGESTED_AT"
}
METAEOF

  # Step 3b: Resolve real title/authors/year from Zotero when this ingest came in via
  # --zotero <key> (the resolved key from the source-resolution block above is threaded
  # through to here; ZOTERO_KEY is empty for a plain local-PDF ingest). Looked up via
  # zotero-read.sh (the zot CLI wrapper), NOT the legacy zotero-library.json PDF-path
  # lookup used above -- that file only resolves a PDF path, it does not carry
  # title/authors/year. Written to a temp JSON file (never interpolated directly into
  # the Step 4 python heredoc below) so a title/author containing a quote, backslash,
  # or backtick cannot corrupt the unquoted heredoc's Python syntax.
  ZOTERO_META_FILE=$(mktemp)
  echo "{}" > "$ZOTERO_META_FILE"
  if [ -n "$ZOTERO_KEY" ] && [ -x "$SCRIPT_DIR/zotero-read.sh" ]; then
    ZOTERO_ITEM_JSON=$(bash "$SCRIPT_DIR/zotero-read.sh" item "$ZOTERO_KEY" 2>/dev/null) || ZOTERO_ITEM_JSON=""
    if [ -n "$ZOTERO_ITEM_JSON" ] && echo "$ZOTERO_ITEM_JSON" | jq -e '.title' >/dev/null 2>&1; then
      # authors: individual "First Last" strings from creator_type == "author" only
      # (editors/translators excluded) -- never a comma-joined string, matching
      # --validate's authors-shape check. year: first 4-digit run in Zotero's date
      # string (format varies, e.g. "2012-00-00 2012"), or null if none found.
      echo "$ZOTERO_ITEM_JSON" | jq -c '{
        title: (.title // null),
        authors: [.creators[]? | select(.creator_type == "author")
                  | ((.first_name // "") + " " + (.last_name // ""))
                  | gsub("^\\s+|\\s+$"; "")
                  | select(length > 0)],
        year: ((.date // "") | capture("(?<y>[0-9]{4})")? .y | tonumber? )
      }' > "$ZOTERO_META_FILE" 2>/dev/null || echo "{}" > "$ZOTERO_META_FILE"
    else
      log "WARNING: Zotero key '$ZOTERO_KEY' did not resolve to item metadata -- honest partial (unresolved metadata) written instead"
    fi
  fi

  # Step 4: Update global index.json with a canonical parent entry (id == the bare
  # id literature-chunk.sh stamped into chunks.json's doc_id, and hence into
  # chunks_data.doc_id -- NEVER a longer curated form; see the id-assignment comment
  # below) plus one child entry per chunks.json row (Decision B: 1:1 granularity, so
  # the briefing's chunk count and --toc's chunk count agree by construction).
  SOURCE_EXT="${source_file##*.}"
  SOURCE_FORMAT=$(echo "$SOURCE_EXT" | tr '[:upper:]' '[:lower:]')
  python3 << PYEOF
import json
import os

index_path = "$LITERATURE_DIR/index.json"
doc_id = "$DOC_ID"
doc_dir = "$DOC_DIR"
zotero_key = "$ZOTERO_KEY"
zotero_meta_file = "$ZOTERO_META_FILE"

with open(zotero_meta_file) as f:
    zmeta = json.load(f)
os.remove(zotero_meta_file)

# Honest partial (never fabricated): only trust Zotero-resolved title/authors/year
# when Zotero actually returned a title. Otherwise keep the bare-id / [] / null
# placeholders and stamp metadata_status so --validate and a human can tell "not yet
# enriched" apart from "enriched to these values" -- never silently indistinguishable.
zotero_title = zmeta.get('title')
metadata_resolved = bool(zotero_title)
if metadata_resolved:
    parent_title = zotero_title
    parent_authors = zmeta.get('authors') or []
    parent_year = zmeta.get('year')
    metadata_status = "resolved"
else:
    parent_title = doc_id
    parent_authors = []
    parent_year = None
    metadata_status = "unresolved"
source_file = "$source_file"
ingested_at = "$INGESTED_AT"
source_format = "$SOURCE_FORMAT"

# Read or create index
if os.path.isfile(index_path):
    try:
        with open(index_path) as f:
            idx = json.load(f)
    except Exception:
        idx = {"entries": []}
else:
    idx = {"entries": []}

# Normalize to entries list
entries = idx if isinstance(idx, list) else idx.get('entries', [])
if isinstance(idx, dict) and 'entries' not in idx:
    idx = {"entries": entries}
elif isinstance(idx, list):
    idx = {"entries": idx}

# Idempotent pre-write removal: drop the existing parent entry AND all of its
# existing children for this doc_id before appending, so a re-ingest never
# accumulates duplicate parents or orphaned stale children. Matches on either
# .id or the legacy .doc_id key (belt-and-braces back-compat with the 35
# existing dual-keyed entries) for the parent, and on .parent_doc == doc_id
# for children.
idx['entries'] = [
    e for e in idx['entries']
    if not (
        (e.get('id') == doc_id or e.get('doc_id') == doc_id)
        and not e.get('parent_doc')
    )
    and e.get('parent_doc') != doc_id
]

# Load this document's chunks.json (already written by literature-chunk.sh above)
# to project real per-chunk fields into 1:1 child entries -- never synthesized.
chunks_path = os.path.join(doc_dir, "chunks.json")
with open(chunks_path) as f:
    chunks = json.load(f)

def kw_to_list(raw):
    # chunks.json's own keywords field is a whitespace-separated string (see
    # literature-chunk.sh output); index.json's established convention elsewhere
    # in the corpus is a JSON array (e.g. SKILL.md's convert flow, existing
    # curated entries) -- convert here rather than introduce a second shape.
    if isinstance(raw, list):
        return raw
    if isinstance(raw, str):
        return raw.split()
    return []

doc_total_tokens = sum(int(c.get('token_count') or 0) for c in chunks)

# Document-level keywords/summary are a straight projection of real chunk data
# (union of chunk keywords, first chunk's summary) -- never fabricated. title/
# authors/year stay honest placeholders here (bare id / [] / null); Phase 6
# populates them from Zotero where available.
doc_keywords = []
for c in chunks:
    for kw in kw_to_list(c.get('keywords')):
        if kw not in doc_keywords:
            doc_keywords.append(kw)
doc_summary = chunks[0].get('summary', '') if chunks else ''

# THE ANTI-RENAME INVARIANT: this id MUST equal chunks_data.doc_id (the same bare
# id literature-chunk.sh already stamped into every row of chunks.json/the FTS
# database for this document). Renaming it to a curated long form is the specific
# operation known to break literature-search.sh's --toc flag and project-filtered
# search -- see literature-doc-key.sh's header for the full invariant.
parent_entry = {
    "id": doc_id,
    "doc_id": doc_id,
    "parent_doc": None,
    "path": f"sources/{doc_id}/",
    "title": parent_title,
    "authors": parent_authors,
    "year": parent_year,
    "metadata_status": metadata_status,
    # Parent token_count is 0, not the document total, when children exist --
    # matching the corpus's own established convention (see corpus commit
    # e6ce8bd9's baier_katoen_2008/vardi_wolper_1986 parent entries and its
    # commit message: "Parent token_count is 0 to avoid double-counting against
    # the children"). literature-briefing.sh's chunk_count>0 branch sums
    # children's token_count AND adds the parent's token_count; a non-zero
    # document-total value here would double the reported token count.
    "token_count": 0,
    "chunk_count": len(chunks),
    "doc_type": "paper",
    "source_format": source_format,
    "keywords": doc_keywords,
    "summary": doc_summary,
    "source_path": source_file,
    "ingested_at": ingested_at,
}
if zotero_key:
    parent_entry["zotero_key"] = zotero_key

child_entries = []
for c in chunks:
    child_entries.append({
        "id": c.get("chunk_id"),
        "doc_id": doc_id,
        "parent_doc": doc_id,
        "path": f"sources/{doc_id}/{c.get('source_path', '')}",
        "title": c.get("title", ""),
        "keywords": kw_to_list(c.get("keywords")),
        "summary": c.get("summary", ""),
        "token_count": int(c.get("token_count") or 0),
        "ingested_at": ingested_at,
    })

idx['entries'].append(parent_entry)
idx['entries'].extend(child_entries)

with open(index_path, 'w') as f:
    json.dump(idx, f, indent=2)

print(f"Updated index.json: {len(idx['entries'])} total entries ({len(child_entries)} children for {doc_id}, doc total {doc_total_tokens} tokens)", file=__import__('sys').stderr)
PYEOF

  INGESTED_DOC_IDS+=("$DOC_ID")
  PROCESSED=$((PROCESSED + 1))
  log_out "Ingested: $DOC_ID ($CHUNK_COUNT chunks)"
done

if [ "$PROCESSED" -eq 0 ]; then
  if [ "$GATE_FAILED" -gt 0 ] || [ "$OCR_NEEDED" -gt 0 ]; then
    log "All files failed to process (${GATE_FAILED} rejected by the conversion quality gate, ${OCR_NEEDED} needing OCR, ${FAILED} hard-failed)"
  else
    log "All files failed to process"
  fi
  exit 3
fi

# Step 5: Rebuild global database
log "Rebuilding global literature database..."
"$SCRIPT_DIR/literature-build-index.sh" --global 2>&1 | sed 's/^/[ingest] /' >&2

# Step 6: Offer local loading
if [ "$NO_LOCAL" -eq 1 ]; then
  log "Local loading skipped (--no-local)"
elif [ "$AUTO_LOCAL" -eq 1 ]; then
  log "Auto-accepting local loading (--local)"
  do_local_loading=1
else
  # Interactive prompt
  echo ""
  echo "Ingested: ${INGESTED_DOC_IDS[*]}"
  echo "Load into specs/literature/ in current repo? [y/N]"
  read -r -t 30 REPLY || REPLY="N"
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    do_local_loading=1
  else
    do_local_loading=0
  fi
fi

if [ "${do_local_loading:-0}" -eq 1 ]; then
  GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  LOCAL_LIT_DIR="$GIT_ROOT/specs/literature"
  mkdir -p "$LOCAL_LIT_DIR"

  for doc_id in "${INGESTED_DOC_IDS[@]}"; do
    DOC_SRC="$LITERATURE_DIR/sources/$doc_id"
    DOC_DST="$LOCAL_LIT_DIR/$doc_id"

    if [ -d "$DOC_SRC" ]; then
      log "Copying $doc_id to local specs/literature/"
      mkdir -p "$DOC_DST"
      cp -r "$DOC_SRC"/* "$DOC_DST/"

      # Add global_id field to local chunk metadata
      if [ -f "$DOC_DST/chunks.json" ]; then
        python3 << PYEOF
import json
with open("$DOC_DST/chunks.json") as f:
    chunks = json.load(f)
for chunk in chunks:
    chunk['global_id'] = chunk.get('doc_id', '')
with open("$DOC_DST/chunks.json", 'w') as f:
    json.dump(chunks, f, indent=2)
PYEOF
      fi
    fi
  done

  log "Rebuilding local literature database..."
  "$SCRIPT_DIR/literature-build-index.sh" --local 2>&1 | sed 's/^/[ingest] /' >&2
  log "Local loading complete"
fi

# --- Summary ---
echo ""
echo "=== Ingestion Summary ==="
echo "Files processed: $PROCESSED"
echo "Files failed: $FAILED"
echo "Files quality-gate-failed: $GATE_FAILED"
if [ "$GATE_FAILED" -gt 0 ]; then
  echo "  (quality-gate-rejected files — NOT ingested, .rejected sibling written by literature-convert.sh):"
  for entry in "${GATE_FAILED_ENTRIES[@]}"; do
    echo "  - ${entry}"
  done
fi
echo "Files needing OCR: $OCR_NEEDED"
if [ "$OCR_NEEDED" -gt 0 ]; then
  echo "  (no extractable text layer — NOT ingested; re-run with LITERATURE_CONVERTER=ocr):"
  for entry in "${OCR_NEEDED_ENTRIES[@]}"; do
    echo "  - ${entry}"
  done
fi
echo "Documents ingested: ${INGESTED_DOC_IDS[*]}"
echo "Global library: $LITERATURE_DIR"
if [ -f "$LITERATURE_DIR/.literature.db" ]; then
  DB_SIZE=$(du -sh "$LITERATURE_DIR/.literature.db" 2>/dev/null | cut -f1)
  echo "Global database: $LITERATURE_DIR/.literature.db ($DB_SIZE)"
fi
echo ""
echo "To search: literature-search.sh \"your query\""
