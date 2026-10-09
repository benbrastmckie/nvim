#!/usr/bin/env bash
# zotero-attach-chunks.sh - Upload local markdown chunks as Zotero child attachments
#
# Category B: Chunk Management Pipeline
#
# Usage:
#   zotero-attach-chunks.sh <zotero_key> [--dry-run]
#
# Arguments:
#   <zotero_key>  - 8-char Zotero item key (required)
#   --dry-run     - Preview uploads without executing
#
# Pipeline steps:
#   1. Read chunk_dir from specs/zotero-index.json for the given key
#   2. Exit 2 if has_chunks is false or chunk_dir is null
#   3. Resolve chunk_dir relative to PROJECT_ROOT; verify directory exists
#   4. For each .md file in chunk_dir (sorted lexicographically, excluding chunks.json):
#      zotero-write.sh attach-file KEY chunk.md --idempotency-key "chunk-{KEY}-{N}"
#   5. Print summary: N succeeded, M failed
#
# Exit codes:
#   0 - All chunks uploaded (or dry-run completed)
#   1 - One or more chunk uploads failed
#   2 - ZOTERO_API_KEY not set; item not in index; has_chunks is false; chunk_dir missing
#
# Dependencies: zotero-write.sh, jq

set -euo pipefail

# ---------------------------------------------------------------------------
# Path resolution
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ZOTERO_INDEX="$PROJECT_ROOT/specs/zotero-index.json"
ZOTERO_WRITE_SH="$SCRIPT_DIR/zotero-write.sh"

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

show_usage() {
  cat >&2 << 'USAGE'
Usage: zotero-attach-chunks.sh <zotero_key> [--dry-run]

Arguments:
  <zotero_key>  8-char Zotero item key (required)
  --dry-run     Preview uploads without executing

Exit codes:
  0 - All chunks uploaded (or dry-run completed)
  1 - One or more chunk uploads failed
  2 - ZOTERO_API_KEY not set; item not in index; has_chunks is false; chunk_dir missing
USAGE
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

KEY="${1:-}"
DRY_RUN=false

if [[ -z "$KEY" ]]; then
  echo "zotero-attach-chunks.sh: zotero_key required" >&2
  show_usage
  exit 2
fi

shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help|-h)
      show_usage
      exit 0
      ;;
    *)
      echo "zotero-attach-chunks.sh: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Prerequisite checks
# ---------------------------------------------------------------------------

if ! command -v jq &>/dev/null; then
  echo "zotero-attach-chunks.sh: jq not installed" >&2
  exit 2
fi

if [[ -z "${ZOTERO_API_KEY:-}" ]]; then
  echo "zotero-attach-chunks.sh: ZOTERO_API_KEY not set" >&2
  echo "Run /zotero --setup or: export ZOTERO_API_KEY=your_key" >&2
  exit 2
fi

if [[ ! -f "$ZOTERO_INDEX" ]]; then
  echo "zotero-attach-chunks.sh: specs/zotero-index.json not found" >&2
  echo "Run /zotero --setup to initialize the per-repo index." >&2
  exit 2
fi

if [[ ! -f "$ZOTERO_WRITE_SH" ]]; then
  echo "zotero-attach-chunks.sh: zotero-write.sh not found at: $ZOTERO_WRITE_SH" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Index lookup
# ---------------------------------------------------------------------------

echo "Looking up $KEY in index..." >&2

entry="$(jq -r --arg k "$KEY" '.entries[] | select(.zotero_key == $k)' "$ZOTERO_INDEX" 2>/dev/null || echo "")"

if [[ -z "$entry" ]]; then
  echo "zotero-attach-chunks.sh: key $KEY not found in index" >&2
  echo "See skills/skill-literature/SKILL.md 'Sub-Index Management > Add: Append a Document Entry' for the jq append pattern that registers an entry." >&2
  exit 2
fi

has_chunks="$(echo "$entry" | jq -r '.has_chunks // false')"
chunk_dir_raw="$(echo "$entry" | jq -r '.chunk_dir // ""')"

if [[ "$has_chunks" != "true" ]]; then
  echo "zotero-attach-chunks.sh: item $KEY has no chunks (has_chunks=false)" >&2
  echo "Run: zotero-chunk.sh $KEY" >&2
  exit 2
fi

if [[ -z "$chunk_dir_raw" || "$chunk_dir_raw" == "null" ]]; then
  echo "zotero-attach-chunks.sh: chunk_dir is null for key $KEY" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Resolve chunk_dir against PROJECT_ROOT
# ---------------------------------------------------------------------------

# chunk_dir in index is stored as a relative path from PROJECT_ROOT
if [[ "$chunk_dir_raw" == /* ]]; then
  # Absolute path stored directly
  CHUNK_DIR="$chunk_dir_raw"
else
  CHUNK_DIR="$PROJECT_ROOT/$chunk_dir_raw"
fi

if [[ ! -d "$CHUNK_DIR" ]]; then
  echo "zotero-attach-chunks.sh: chunk directory not found: $CHUNK_DIR" >&2
  echo "Run: zotero-chunk.sh $KEY to regenerate chunks." >&2
  exit 2
fi

echo "Chunk directory: $CHUNK_DIR" >&2

# ---------------------------------------------------------------------------
# Collect chunk files
# ---------------------------------------------------------------------------

shopt -s nullglob
chunk_files=("$CHUNK_DIR"/chunk_*.md)
shopt -u nullglob

if [[ ${#chunk_files[@]} -eq 0 ]]; then
  echo "zotero-attach-chunks.sh: no chunk_*.md files found in $CHUNK_DIR" >&2
  exit 2
fi

# Sort lexicographically (already sorted by glob, but be explicit). chunk_files is already
# confirmed non-empty by the guard above, so no empty-array mapfile edge case applies here.
mapfile -t sorted_chunks < <(printf '%s\n' "${chunk_files[@]}" | sort)

total=${#sorted_chunks[@]}
echo "Found $total chunk files to upload." >&2

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[dry-run] Would upload $total chunks for key $KEY" >&2
fi

# ---------------------------------------------------------------------------
# Upload loop
# ---------------------------------------------------------------------------

success_count=0
fail_count=0
counter=0

for chunk_file in "${sorted_chunks[@]}"; do
  counter=$((counter + 1))
  chunk_basename="$(basename "$chunk_file")"
  idempotency_key="chunk-$KEY-$counter"

  echo "[$counter/$total] Uploading $chunk_basename..." >&2

  upload_args=(attach-file "$KEY" "$chunk_file" --idempotency-key "$idempotency_key")
  if [[ "$DRY_RUN" == "true" ]]; then
    upload_args+=(--dry-run)
  fi

  if bash "$ZOTERO_WRITE_SH" "${upload_args[@]}"; then
    success_count=$((success_count + 1))
    echo "[$counter/$total] OK: $chunk_basename"
  else
    fail_count=$((fail_count + 1))
    echo "[$counter/$total] FAILED: $chunk_basename" >&2
  fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "Upload summary: $success_count succeeded, $fail_count failed (of $total total)"

if [[ "$fail_count" -gt 0 ]]; then
  exit 1
fi

exit 0
