#!/usr/bin/env bash
# zotero-chunk.sh - Extract full text from a Zotero item PDF and chunk into sections
#
# Category B: Chunk Management Pipeline
#
# Usage:
#   zotero-chunk.sh <zotero_key> [--output-dir DIR] [--pages N-M]
#
# Arguments:
#   <zotero_key>       - 8-char Zotero item key (required)
#   --output-dir DIR   - Override chunk storage directory (default: specs/literature/{citation_key}/)
#   --pages N-M        - Restrict extraction to page range (reserved for future use)
#
# Pipeline steps:
#   1. Read entry for zotero_key from specs/zotero-index.json
#   2. Extract citation_key, pdf_path, has_pdf from index entry
#   3. literature-convert.sh <pdf_path> <tmp_dir> -> markdown file
#   4. literature-chunk.sh <md_file> <chunk_dir> --doc-id <citation_key>
#   5. Sum token_count values from chunks.json manifest
#   6. Update specs/zotero-index.json: has_chunks, chunk_dir, chunk_count, token_count, last_updated
#   7. literature-build-index.sh --local -> rebuild FTS5 search database
#
# Exit codes:
#   0 - Success; index updated
#   1 - PDF extraction failed; chunking failed; index update failed
#   2 - Item not in specs/zotero-index.json; has_pdf is false; jq not available
#
# Dependencies: literature-convert.sh, literature-chunk.sh, literature-build-index.sh, jq

set -euo pipefail

# ---------------------------------------------------------------------------
# Path resolution
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Walk up from SCRIPT_DIR to find the repo root (the directory containing .claude/). A fixed
# "../../../.." depth is WRONG here: it assumes this script always runs from the nested
# extension source tree (.claude/extensions/literature/scripts/, 4 levels below repo root), but
# provides.scripts deploys this script FLAT into {repo}/.claude/scripts/ in every consuming repo
# (only 2 levels below repo root) -- see .claude/context/guides/extension-development.md. A fixed
# 4-level walk-up from the flat location lands 2 directories ABOVE the actual repo root. Walking
# up dynamically until a `.claude` directory is found resolves correctly from either location.
PROJECT_ROOT="$SCRIPT_DIR"
while [ "$PROJECT_ROOT" != "/" ] && [ ! -d "$PROJECT_ROOT/.claude" ]; do
  PROJECT_ROOT="$(dirname "$PROJECT_ROOT")"
done
if [ ! -d "$PROJECT_ROOT/.claude" ]; then
  echo "Error: could not locate repo root (no .claude/ directory found above $SCRIPT_DIR)" >&2
  exit 2
fi
ZOTERO_INDEX="$PROJECT_ROOT/specs/zotero-index.json"
LITERATURE_SCRIPTS_DIR="$PROJECT_ROOT/.claude/scripts"

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

show_usage() {
  cat >&2 << 'USAGE'
Usage: zotero-chunk.sh <zotero_key> [--output-dir DIR] [--pages N-M]

Arguments:
  <zotero_key>       8-char Zotero item key (required)
  --output-dir DIR   Override chunk storage directory
                     (default: specs/literature/{citation_key}/)
  --pages N-M        Restrict to page range (reserved for future use)

Exit codes:
  0 - Success; index updated
  1 - PDF extraction or chunking failed; index update failed
  2 - Item not in index; has_pdf is false; jq not available
USAGE
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

KEY="${1:-}"
OUTPUT_DIR_OVERRIDE=""
PAGES_RANGE=""

if [[ -z "$KEY" ]]; then
  echo "zotero-chunk.sh: zotero_key required" >&2
  show_usage
  exit 2
fi

shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      if [[ $# -lt 2 ]]; then
        echo "zotero-chunk.sh: --output-dir requires a DIR argument" >&2
        exit 1
      fi
      OUTPUT_DIR_OVERRIDE="$2"
      shift 2
      ;;
    --pages)
      if [[ $# -lt 2 ]]; then
        echo "zotero-chunk.sh: --pages requires a N-M argument" >&2
        exit 1
      fi
      # shellcheck disable=SC2034  # --pages is explicitly documented as "reserved for future
      # use" (see usage() and the header comment); accepted and parsed but not yet consumed.
      PAGES_RANGE="$2"
      shift 2
      ;;
    --help|-h)
      show_usage
      exit 0
      ;;
    *)
      echo "zotero-chunk.sh: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Prerequisite checks
# ---------------------------------------------------------------------------

if ! command -v jq &>/dev/null; then
  echo "zotero-chunk.sh: jq not installed" >&2
  exit 2
fi

if [[ ! -f "$ZOTERO_INDEX" ]]; then
  echo "zotero-chunk.sh: specs/zotero-index.json not found" >&2
  echo "Run /zotero --setup to initialize the per-repo index." >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Index lookup
# ---------------------------------------------------------------------------

echo "Looking up $KEY in index..." >&2

entry="$(jq -r --arg k "$KEY" '.entries[] | select(.zotero_key == $k)' "$ZOTERO_INDEX" 2>/dev/null || echo "")"

if [[ -z "$entry" ]]; then
  echo "zotero-chunk.sh: key $KEY not found in index" >&2
  echo "See skills/skill-literature/SKILL.md 'Sub-Index Management > Add: Append a Document Entry' for the jq append pattern that registers an entry." >&2
  exit 2
fi

citation_key="$(echo "$entry" | jq -r '.citation_key // ""')"
pdf_path="$(echo "$entry" | jq -r '.pdf_path // ""')"
has_pdf="$(echo "$entry" | jq -r '.has_pdf // false')"

if [[ "$has_pdf" != "true" ]]; then
  echo "zotero-chunk.sh: item $KEY has no PDF (has_pdf=false)" >&2
  echo "Ensure the PDF is accessible from the Zotero library." >&2
  exit 2
fi

if [[ -z "$pdf_path" || "$pdf_path" == "null" ]]; then
  echo "zotero-chunk.sh: pdf_path is null for key $KEY" >&2
  exit 2
fi

if [[ ! -f "$pdf_path" ]]; then
  echo "zotero-chunk.sh: PDF file not found at: $pdf_path" >&2
  exit 1
fi

echo "Found: $citation_key (PDF: $pdf_path)" >&2

# ---------------------------------------------------------------------------
# Temp dir setup with cleanup trap
# ---------------------------------------------------------------------------

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

# ---------------------------------------------------------------------------
# PDF-to-markdown conversion
# ---------------------------------------------------------------------------

echo "Converting PDF to markdown..." >&2

if ! bash "$LITERATURE_SCRIPTS_DIR/literature-convert.sh" "$pdf_path" "$TMP_DIR" >/dev/null; then
  echo "zotero-chunk.sh: PDF conversion failed for: $pdf_path" >&2
  exit 1
fi

# Locate the produced .md file by globbing
shopt -s nullglob
md_files=("$TMP_DIR"/*.md)
shopt -u nullglob

if [[ ${#md_files[@]} -eq 0 ]]; then
  echo "zotero-chunk.sh: no .md file produced by literature-convert.sh in $TMP_DIR" >&2
  exit 1
fi

TMP_MD="${md_files[0]}"
echo "Converted to markdown: $TMP_MD" >&2

# ---------------------------------------------------------------------------
# Chunking
# ---------------------------------------------------------------------------

if [[ -n "$OUTPUT_DIR_OVERRIDE" ]]; then
  CHUNK_DIR="$OUTPUT_DIR_OVERRIDE"
else
  CHUNK_DIR="$PROJECT_ROOT/specs/literature/$citation_key"
fi

mkdir -p "$CHUNK_DIR"

echo "Chunking into: $CHUNK_DIR ..." >&2

chunk_count="$(bash "$LITERATURE_SCRIPTS_DIR/literature-chunk.sh" "$TMP_MD" "$CHUNK_DIR" --doc-id "$citation_key")"

if [[ -z "$chunk_count" ]]; then
  echo "zotero-chunk.sh: literature-chunk.sh produced no output (chunk count unknown)" >&2
  chunk_count=0
fi

echo "Created $chunk_count chunks" >&2

# ---------------------------------------------------------------------------
# Token counting
# ---------------------------------------------------------------------------

CHUNKS_JSON="$CHUNK_DIR/chunks.json"

if [[ -f "$CHUNKS_JSON" ]]; then
  token_count="$(jq '[.[].token_count] | add // 0' "$CHUNKS_JSON")"
else
  echo "zotero-chunk.sh: chunks.json not found at $CHUNKS_JSON; token_count=0" >&2
  token_count=0
fi

echo "Total tokens: $token_count" >&2

# ---------------------------------------------------------------------------
# Store chunk_dir as relative path from PROJECT_ROOT
# ---------------------------------------------------------------------------

# Convert absolute CHUNK_DIR to relative path from PROJECT_ROOT
if [[ "$CHUNK_DIR" == "$PROJECT_ROOT/"* ]]; then
  chunk_dir_relative="${CHUNK_DIR#$PROJECT_ROOT/}"
else
  # If not under PROJECT_ROOT, store absolute path
  chunk_dir_relative="$CHUNK_DIR"
fi

# ---------------------------------------------------------------------------
# Index update
# ---------------------------------------------------------------------------

echo "Updating index entry for $KEY..." >&2

now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

updated_json="$(jq \
  --arg k "$KEY" \
  --argjson chunk_count "$chunk_count" \
  --argjson token_count "$token_count" \
  --arg chunk_dir "$chunk_dir_relative" \
  --arg ts "$now" \
  '.last_updated = $ts |
   .entries = [.entries[] | if .zotero_key == $k then
     . +
     {
       has_chunks: true,
       chunk_dir: $chunk_dir,
       chunk_count: $chunk_count,
       token_count: $token_count,
       last_updated: $ts
     }
   else . end]' \
  "$ZOTERO_INDEX")"

echo "$updated_json" > "$ZOTERO_INDEX"

echo "Index updated: has_chunks=true chunk_count=$chunk_count token_count=$token_count chunk_dir=$chunk_dir_relative" >&2

# ---------------------------------------------------------------------------
# FTS5 rebuild
# ---------------------------------------------------------------------------

BUILD_INDEX_SH="$LITERATURE_SCRIPTS_DIR/literature-build-index.sh"
if [[ -f "$BUILD_INDEX_SH" ]]; then
  echo "Rebuilding FTS5 search index..." >&2
  if bash "$BUILD_INDEX_SH" --local; then
    echo "FTS5 index rebuilt." >&2
  else
    echo "zotero-chunk.sh: FTS5 rebuild failed (non-fatal)" >&2
  fi
else
  echo "zotero-chunk.sh: literature-build-index.sh not found; skipping FTS5 rebuild" >&2
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo "Done: $citation_key chunked into $chunk_count chunks ($token_count tokens) at $chunk_dir_relative"
exit 0
