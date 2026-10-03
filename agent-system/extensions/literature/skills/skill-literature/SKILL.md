---
name: skill-literature
description: Manage specs/literature/ — scan, convert PDFs/DJVUs, maintain index.json. Invoke for /literature command.
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

# Literature Skill (Direct Execution)

Direct execution skill for managing `specs/literature/` directories. Handles PDF/DJVU-to-markdown conversion, index.json maintenance, and filesystem validation. Runs inline using AskUserQuestion for interactivity.

**Key behavior**: Users see scan results and proposed keywords/summaries BEFORE any files are written. Users confirm chunk boundaries and metadata before conversion completes.

## Context References

Reference (do not load eagerly):
- Path: `@specs/literature/index.json` - Current literature index
- Path: `@specs/702_create_literature_command/reports/01_lit-command.md` - Research findings

---

## Execution

### Step 1: Parse Arguments

Extract mode, optional file, and optional query from skill args:

```bash
# Parse from skill args: "mode={mode} file={file}" or "mode=search query={query text}"
mode=$(echo "$ARGUMENTS" | grep -oP 'mode=\K\S+' | head -1)
file=$(echo "$ARGUMENTS" | grep -oP 'file=\K\S+' | head -1)

# Extract query: everything after "query=" (supports spaces in query text)
query=$(echo "$ARGUMENTS" | sed 's/.*query=//' | sed 's/^[[:space:]]*//')

# Default to status mode if not specified
if [ -z "$mode" ]; then
  mode="status"
fi

# Resolve file path (may be relative or absolute)
if [ -n "$file" ]; then
  if [[ "$file" != /* ]]; then
    file="specs/literature/$file"
  fi
fi
```

### Step 2: Generate Session ID

```bash
source .claude/scripts/lib/common.sh
session_id="$(common_session_id)"
# Two-tier fallback: use LITERATURE_DIR if set and exists, otherwise use per-project specs/literature/
if [ -n "${LITERATURE_DIR:-}" ] && [ -d "$LITERATURE_DIR" ]; then
  lit_dir="$LITERATURE_DIR"
else
  lit_dir="specs/literature"
fi
index_file="$lit_dir/index.json"
# Determine sources/ prefix for centralized repo
if [ -n "${LITERATURE_DIR:-}" ] && [ "$lit_dir" = "$LITERATURE_DIR" ]; then
  sources_prefix="sources/"
else
  sources_prefix=""
fi
```

### Step 3: Check Tool Availability

Detect available conversion tools:

```bash
has_pdftotext=$(which pdftotext 2>/dev/null && echo "yes" || echo "no")
has_pdfinfo=$(which pdfinfo 2>/dev/null && echo "yes" || echo "no")
has_djvutxt=$(which djvutxt 2>/dev/null && echo "yes" || echo "no")
```

### Step 4: Dispatch to Mode Handler

Route to the appropriate mode:

```bash
case "$mode" in
  status)   handle_status ;;
  scan)     handle_scan ;;
  convert)  handle_convert ;;
  validate) handle_validate ;;
  index)    handle_index ;;
  search)   handle_search ;;
  ingest)   handle_ingest ;;
  rebuild)  handle_rebuild ;;
  *)
    echo "Error: Unknown mode '$mode'. Available: status, scan, convert, validate, index, search, ingest, rebuild"
    exit 1
    ;;
esac
```

---

## Mode: Ingest

READ .claude/context/project/literature/patterns/literature-ingest-mode.md now and follow it exactly.

---

## Mode: Status (Default)

Show health report: processed vs unprocessed files and index.json state.

### Status Step 1: Check Directory

```bash
if [ ! -d "$lit_dir" ]; then
  echo "## Literature Status"
  echo ""
  echo "No specs/literature/ directory found."
  echo "Create it and add PDF/DJVU files to get started."
  echo ""
  echo "**Tool Availability**:"
  echo "- pdftotext: $has_pdftotext"
  echo "- djvutxt: $has_djvutxt ($([ "$has_djvutxt" = "no" ] && echo 'install: nix-env -iA nixpkgs.djvulibre' || echo 'available'))"
  exit 0
fi
```

### Status Step 2: Scan for Files

```bash
# Find all PDF and DJVU source files
pdf_files=$(find "$lit_dir" -name "*.pdf" 2>/dev/null | sort)
djvu_files=$(find "$lit_dir" -name "*.djvu" 2>/dev/null | sort)
all_source_files="$pdf_files $djvu_files"

# Find all markdown files (excluding any in subdirectory source_files/)
md_files=$(find "$lit_dir" -name "*.md" -not -path "*/source_files/*" 2>/dev/null | sort)
```

### Status Step 3: Read Index

```bash
if [ -f "$index_file" ]; then
  entry_count=$(jq '.entries | length' "$index_file" 2>/dev/null || echo "0")
  indexed_paths=$(jq -r '.entries[].path' "$index_file" 2>/dev/null || echo "")
else
  entry_count=0
  indexed_paths=""
fi
```

### Status Step 4: Compute Counts

```bash
# Count source files
pdf_count=$(echo "$pdf_files" | grep -c "\.pdf$" 2>/dev/null || echo 0)
djvu_count=$(echo "$djvu_files" | grep -c "\.djvu$" 2>/dev/null || echo 0)
md_count=$(echo "$md_files" | grep -c "\.md$" 2>/dev/null || echo 0)

# Identify unprocessed source files (PDFs/DJVUs without corresponding .md)
unprocessed=()
for src in $pdf_files $djvu_files; do
  basename_no_ext=$(basename "$src" | sed 's/\.[^.]*$//')
  # Check if any .md file starts with this basename
  if ! find "$lit_dir" -name "${basename_no_ext}*.md" -not -path "*/source_files/*" 2>/dev/null | grep -q .; then
    unprocessed+=("$src")
  fi
done
unprocessed_count=${#unprocessed[@]}
processed_count=$(( pdf_count + djvu_count - unprocessed_count ))
```

### Status Step 5: Display Report

```
## Literature Status

**Directory**: specs/literature/
**Source Files**: {pdf_count} PDFs, {djvu_count} DJVUs
**Converted**: {processed_count} processed, {unprocessed_count} unprocessed
**Markdown Files**: {md_count}
**Index Entries**: {entry_count}

**Tool Availability**:
- pdftotext: {has_pdftotext}
- djvutxt: {has_djvutxt} {install hint if no}

{if unprocessed_count > 0}
**Unprocessed Files** ({unprocessed_count}):
- {file1}
- {file2}
...

Run `/literature --convert` to convert all, or `/literature --scan` to see details.
{end if}

{if entry_count > 0 and md_count != entry_count}
**Index Health**: {entry_count} indexed entries, {md_count} markdown files — run `/literature --validate` to check consistency.
{end if}
```

---

## Mode: Scan

Find PDF/DJVU files lacking corresponding markdown conversions.

### Scan Step 1: Check Directory

Same as Status Step 1 — exit gracefully if directory missing.

### Scan Step 2: Find Unprocessed Files

```bash
unprocessed=()
for src in $(find "$lit_dir" -name "*.pdf" -o -name "*.djvu" 2>/dev/null | sort); do
  basename_no_ext=$(basename "$src" | sed 's/\.[^.]*$//')
  if ! find "$lit_dir" -name "${basename_no_ext}*.md" -not -path "*/source_files/*" 2>/dev/null | grep -q .; then
    unprocessed+=("$src")
  fi
done
```

### Scan Step 3: Get Page Counts

For each unprocessed file, get page count via pdfinfo:

```bash
for src in "${unprocessed[@]}"; do
  ext="${src##*.}"
  if [ "$ext" = "pdf" ]; then
    if [ "$has_pdfinfo" = "yes" ]; then
      pages=$(pdfinfo "$src" 2>/dev/null | grep "^Pages:" | awk '{print $2}')
    else
      pages="unknown"
    fi
  elif [ "$ext" = "djvu" ]; then
    if [ "$has_djvutxt" = "yes" ]; then
      # djvused can get page count: djvused -e n file.djvu
      pages=$(djvused -e n "$src" 2>/dev/null || echo "unknown")
    else
      pages="unknown (djvutxt not installed)"
    fi
  fi
  echo "- $src ($pages pages)"
done
```

### Scan Step 4: Display Results

```
## Literature Scan Results

**Unprocessed Files** ({count}):
- {file1} ({N} pages)
- {file2} ({N} pages)
...

**Tool Status**:
- pdftotext: {status}
- djvutxt: {status} {install hint if unavailable}

**Next Steps**:
- Convert all: `/literature --convert`
- Convert one: `/literature --convert path/to/file.pdf`
```

If no unprocessed files found:

```
## Literature Scan Results

All source files have been converted. No unprocessed PDFs or DJVUs found.

**Files**: {N} PDFs, {M} DJVUs — all converted
**Index**: {entry_count} entries in index.json

Run `/literature --validate` to check index.json consistency.
```

---

## Mode: Validate

READ .claude/context/project/literature/patterns/literature-validate-mode.md now and follow it exactly.

---

## Mode: Convert

READ .claude/context/project/literature/patterns/literature-convert-mode.md now and follow it exactly.

---

## Mode: Index

READ .claude/context/project/literature/patterns/literature-index-mode.md now and follow it exactly.

---

## Mode: Search

READ .claude/context/project/literature/patterns/literature-search-mode.md now and follow it exactly.

---

## Mode: Import Pipeline (Steps 8-12)

READ .claude/context/project/literature/patterns/literature-import-pipeline-mode.md now and follow it exactly.

---

## Mode: Rebuild

READ .claude/context/project/literature/patterns/literature-rebuild-mode.md now and follow it exactly.

---

## Sub-Index Management

Per-repo sub-index operations for `specs/literature-index.json`. These operations manage which documents from the global Literature/ repo are relevant to the current project. The sub-index is reference-only: it stores doc_ids and metadata is resolved at runtime from the global index.

All operations assume `$LITERATURE_DIR` is set (default: `~/Projects/Literature`) and the global index exists at `$LITERATURE_DIR/index.json`.

### Init: Create Empty Sub-Index

Creates `specs/literature-index.json` with empty entries. Safe to run in a project without an existing sub-index.

```bash
project_name=$(basename "$(pwd)")
today=$(date +%Y-%m-%d)

if [ -f "specs/literature-index.json" ]; then
  echo "Sub-index already exists at specs/literature-index.json"
  echo "Current entries: $(jq '.entries | length' specs/literature-index.json) entries"
else
  jq -n \
    --arg project "$project_name" \
    --arg today "$today" \
    '{
      "project": $project,
      "literature_dir": null,
      "created": $today,
      "entries": []
    }' > specs/literature-index.json
  echo "Created specs/literature-index.json for project: $project_name"
fi
```

### Add: Append a Document Entry

Validates that `doc_id` exists in the global index before appending. Idempotent: if the doc_id is already in the sub-index, reports a warning and skips.

```bash
# Usage: doc_id="blackburn_2002" relevance="Core reference for modal logic"
global_index="${LITERATURE_DIR:-$HOME/Projects/Literature}/index.json"
today=$(date +%Y-%m-%d)

# Validate doc_id exists in global index
if ! jq -e --arg id "$doc_id" '.entries[] | select(.id == $id)' "$global_index" >/dev/null 2>&1; then
  echo "Error: doc_id '$doc_id' not found in global index ($global_index)" >&2
  exit 1
fi

# Check if already present in sub-index
if jq -e --arg id "$doc_id" '.entries[] | select(.doc_id == $id)' specs/literature-index.json >/dev/null 2>&1; then
  echo "Warning: doc_id '$doc_id' already in sub-index — skipping" >&2
  exit 0
fi

# Append entry
tmp=$(mktemp)
jq --arg id "$doc_id" \
   --arg rel "${relevance:-}" \
   --arg today "$today" \
   '.entries += [{
     "doc_id": $id,
     "relevance": (if $rel == "" then null else $rel end),
     "added": $today,
     "source": "manual"
   }]' specs/literature-index.json > "$tmp" && mv "$tmp" specs/literature-index.json
echo "Added doc_id '$doc_id' to specs/literature-index.json"
```

### Remove: Delete a Document Entry

Removes an entry by doc_id. No-op if doc_id not present.

```bash
# Usage: doc_id="blackburn_2002"
tmp=$(mktemp)
before=$(jq '.entries | length' specs/literature-index.json)
jq --arg id "$doc_id" '
  .entries = [.entries[] | select(.doc_id == $id | not)]
' specs/literature-index.json > "$tmp" && mv "$tmp" specs/literature-index.json
after=$(jq '.entries | length' specs/literature-index.json)

if [ "$before" -eq "$after" ]; then
  echo "Warning: doc_id '$doc_id' not found in sub-index — no change"
else
  echo "Removed doc_id '$doc_id' from specs/literature-index.json"
fi
```

### List: Show Entries with Resolved Metadata

Resolves title, authors, and year from the global index for each sub-index entry.

```bash
global_index="${LITERATURE_DIR:-$HOME/Projects/Literature}/index.json"

entry_count=$(jq '.entries | length' specs/literature-index.json)
if [ "$entry_count" -eq 0 ]; then
  echo "Sub-index is empty. Run: /literature --subindex add <doc_id>"
  exit 0
fi

echo "## Sub-Index Entries ($entry_count)"
echo ""

while IFS=$'\t' read -r doc_id relevance added source; do
  # Resolve from global index
  title=$(jq -r --arg id "$doc_id" '.entries[] | select(.id == $id) | .title // "?"' "$global_index" 2>/dev/null | head -1)
  authors=$(jq -r --arg id "$doc_id" '.entries[] | select(.id == $id) | if (.authors|type)=="array" then (.authors|first) elif (.authors|type)=="string" then .authors else "?" end' "$global_index" 2>/dev/null | head -1)
  year=$(jq -r --arg id "$doc_id" '.entries[] | select(.id == $id) | (.year // "?") | tostring' "$global_index" 2>/dev/null | head -1)
  chunk_count=$(jq --arg id "$doc_id" '[.entries[] | select(.parent_doc == $id)] | length' "$global_index" 2>/dev/null || echo 0)

  status_tag=""
  if [ "$title" = "?" ] || [ -z "$title" ]; then
    status_tag=" [NOT IN GLOBAL INDEX]"
  fi

  echo "- **$doc_id**${status_tag}"
  echo "  Title: $title ($year) by $authors"
  [ "$chunk_count" -gt 0 ] && echo "  Chunks: $chunk_count"
  [ -n "$relevance" ] && [ "$relevance" != "null" ] && echo "  Relevance: $relevance"
  echo "  Added: $added (source: ${source:-manual})"
  echo ""
done < <(jq -r '.entries[] | [.doc_id, (.relevance // ""), .added, (.source // "manual")] | @tsv' specs/literature-index.json 2>/dev/null)
```

### Validate: Check All doc_ids Exist in Global Index

**Migrated**: this dangling-ref check is now wired up and reachable as
**Job 1 (`rebuild_job1_dangling_ref_lint`)**, specified in
`.claude/context/project/literature/patterns/literature-rebuild-mode.md` (the "Mode: Rebuild"
stub above dispatches there), invoked via `/literature --rebuild`. It previously referenced a
`--subindex` flag that was never parsed anywhere in `literature.md` (dead documentation). This
section is kept only as a pointer so the Sub-Index Management catalogue stays complete; do not
add a second, divergent implementation here — edit `rebuild_job1_dangling_ref_lint` in
`literature-rebuild-mode.md` instead.

---

## Error Handling

See `rules/error-handling.md` for general patterns. Skill-specific behaviors:

- **specs/literature/ missing**: Not an error for status/scan — report and suggest next steps
- **index.json missing**: Initialize with empty structure for convert/index modes; warn for validate
- **Conversion engine-tier availability**: No longer a Mode: Convert concern — Convert Step 3b
  (see `.claude/context/project/literature/patterns/literature-convert-mode.md`) delegates
  extraction to `literature-convert.sh`, which owns the engine-tier ladder
  (pymupdf4llm -> ... -> pdftotext/djvutxt) and reports total tier exhaustion as its own exit 2
  (see the next bullet).
- **djvutxt missing**: Soft warning — skip DJVU files with message, continue processing PDFs
- **Quality gate rejection (`literature-convert.sh` exit 3)**: Skip the file with the gate's own
  reason surfaced via a `QUALITY GATE FAILED` operator message; listed under Skipped Files, never
  written to `index.json`, never chunked.
- **Engine-tier exhaustion or hard conversion failure (`literature-convert.sh` exit 1/2)**: Skip
  the file with the engine's own reason from its stderr; listed under Skipped Files, continue
  processing the remaining targets.
- **Invariant**: a gate-rejected or hard-failed document is never written to `index.json` and
  never chunked — Mode: Convert (`literature-convert-mode.md`) only reports it in the Skipped
  Files summary, it never appears as a partial or silent success.
- **jq failure**: Use two-step write pattern (write to tmp file, then mv) to avoid corruption
- **Git commit failure**: Non-blocking — log and continue
- **zotero-library.json not found**: Exit code 1 from zotero-search.sh — show setup instructions, fall back to index-only search
- **zotero-search.sh returns no results**: Exit code 2 — continue to index-only search; combine results
- **Broken PDF symlink**: Validate mode will detect broken symlinks in pdfs/ directory; non-blocking for import
- **Duplicate import**: Check index for existing bib_key/zotero_key match before importing; show [IMPORTED] tag

## Standards Reference

- Token counting: `chars / 4 + 20` (matches memory-harvest.sh pattern)
- Chunking: content-aware logical splitting at 4,000-line threshold — divide at chapter/section headings; merge small adjacent sections; fall back to mechanical 4,000-line splits when no headings detected
- Source file convention: PDF/DJVU source files are co-located with their converted markdown in the same `specs/literature/` directory or subdirectory. Source files are gitignored via `specs/literature/**/*.pdf` and `specs/literature/**/*.djvu` patterns. Users must add source files manually after checkout.
- Index schema: root `specs/literature/index.json` uses `entries[]` with enriched metadata fields (authors, title, year, doc_type, source_format, parent_doc, page_range, bib_key, zotero_key, zotero_path, project_tags)
- Drift threshold: >20% change in token count triggers validation warning
- Zotero search: invokes `.claude/extensions/literature/scripts/zotero-search.sh` with `--format=json --limit=20 {query_terms}`; handles exit codes 0 (success), 1 (library not found), 2 (no results)
- Import pipeline (`literature-import-pipeline-mode.md`): symlink PDF to
  `$LITERATURE_DIR/pdfs/{citation_key}.pdf`, convert via `handle_convert()` (specified in
  `literature-convert-mode.md`) with PREFILL_* env vars, patch index with Zotero fields, git
  commit (non-blocking)
