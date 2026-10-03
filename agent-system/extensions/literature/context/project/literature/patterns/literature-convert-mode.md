# Mode: Convert

This file is the COMPLETE and ONLY specification for skill-literature's `Mode: Convert` (`mode=convert`) execution, i.e. the behavior the dispatch table calls `handle_convert`. It MUST be followed exactly -- there is no fuller version of this content anywhere else. The `Mode: Convert` section of `skill-literature/SKILL.md` was extracted here per `context/patterns/mode-gated-section-loading.md`; the pointer at that section's former location in `SKILL.md` sends an agent here whenever `mode=convert` is dispatched.

Convert unprocessed PDF/DJVU files to markdown with interactive confirmation.

## Convert Step 1: Determine Target Files

```bash
if [ -n "$file" ]; then
  # Convert specific file
  targets=("$file")
else
  # Find all unprocessed files
  targets=()
  for src in $(find "$lit_dir" -name "*.pdf" -o -name "*.djvu" 2>/dev/null | sort); do
    basename_no_ext=$(basename "$src" | sed 's/\.[^.]*$//')
    if ! find "$lit_dir" -name "${basename_no_ext}*.md" -not -path "*/source_files/*" 2>/dev/null | grep -q .; then
      targets+=("$src")
    fi
  done
fi
```

## Convert Step 2: Check Tool Availability

Conversion engine-tier availability (pymupdf4llm, marker, `pdftotext`, `djvutxt`) is
`literature-convert.sh`'s concern, not Mode: Convert's — since Step 3b now delegates extraction
to it, a machine with a working PyMuPDF stack but no poppler-utils installed is still fully
capable of converting, so there is no longer a hard `pdftotext`-only gate here. An
all-engine-tiers-failed condition is still loud: it surfaces as `literature-convert.sh`'s own
exit 2 in Step 3b, which is skipped and reported per-file rather than aborting the whole run.
`has_pdftotext` itself is still computed above and remains in the status/scan report lines — only
this hard gate is removed.

## Convert Step 3: Process Each File

```bash
# Accumulate across all target files (not reset per-file) so Step 4's summary can report every
# gate rejection and hard conversion failure from this invocation.
gate_failed_entries=()
convert_failed_entries=()
```

For each target file:

### 3a: Get Page Count

```bash
src="$target_file"
ext="${src##*.}"
basename_no_ext=$(basename "$src" | sed 's/\.[^.]*$//')

if [ "$ext" = "djvu" ]; then
  if [ "$has_djvutxt" = "no" ]; then
    echo "Skipping $src: djvutxt not installed. Install with: nix-env -iA nixpkgs.djvulibre"
    continue
  fi
  # Get page count for DJVU
  page_count=$(djvused -e n "$src" 2>/dev/null || echo 1)
else
  # PDF: get page count
  if [ "$has_pdfinfo" = "yes" ]; then
    page_count=$(pdfinfo "$src" 2>/dev/null | grep "^Pages:" | awk '{print $2}')
  else
    page_count=1
  fi
fi
```

### 3b: Extract Full Text and Determine Chunking

First, extract the complete text from the source file (page-range extraction happens at 3d if
needed for page-range chunks; for content-aware chunking, extract all text first):

```bash
# Resolve SCRIPT_DIR defensively here rather than assuming it is already set (mirrors the
# doc-key block's convention above).
SCRIPT_DIR="${SCRIPT_DIR:-$(dirname "$0")/../../scripts}"

# Delegate extraction to literature-convert.sh for BOTH pdf and djvu -- this is the single
# gated conversion path (engine-tier ladder + quality gate), replacing the two inline
# pdftotext/djvutxt call sites that used to make this a second, ungated implementation.
tmp_convert_dir=$(mktemp -d)
convert_stderr=$(mktemp)

# Capture the exit code explicitly rather than a bare `full_text=$(...)` assignment: under
# `set -e`, a bare assignment would abort this whole target loop on one file's non-zero
# exit. literature-convert.sh distinguishes exit 3 (quality-gate rejection) from exit 0
# (success) and exit 1/2 (hard failure) -- the `if VAR=$(...); then ... else ...; fi` idiom
# below is copied verbatim from literature-ingest.sh's CONVERT_STDOUT capture.
if convert_stdout=$("$SCRIPT_DIR/literature-convert.sh" "$src" "$tmp_convert_dir" 2>"$convert_stderr"); then
  convert_exit=0
else
  convert_exit=$?
fi

if [ "$convert_exit" -eq 3 ]; then
  # Quality gate rejected the output -- loud, actionable skip. No chunk files, no
  # AskUserQuestion prompt, no index.json entry, no literature-chunk.sh call are reachable
  # past this continue (Step 3c onward never runs for this file).
  gate_reason=$(grep -m1 'QUALITY GATE FAILED' "$convert_stderr" 2>/dev/null || echo "QUALITY GATE FAILED (reason unavailable)")
  echo "QUALITY GATE FAILED: $src — ${gate_reason#*QUALITY GATE FAILED: }"
  gate_failed_entries+=("$src :: ${gate_reason#*QUALITY GATE FAILED: }")
  rm -rf "$tmp_convert_dir"
  rm -f "$convert_stderr"
  continue
elif [ "$convert_exit" -ne 0 ]; then
  # Hard conversion failure (all engine tiers exhausted, or a converter crashed). Surface the
  # engine's own reason from stderr and skip -- same "no Step 3c" guarantee as the exit-3 path.
  echo "Error: conversion failed for $src (exit $convert_exit)"
  sed 's/^/  /' "$convert_stderr" >&2
  convert_failed_entries+=("$src :: conversion failed (exit $convert_exit)")
  rm -rf "$tmp_convert_dir"
  rm -f "$convert_stderr"
  continue
fi

# Exit 0: glob the tmp dir for its single .md output. This file is read for CONTENT ONLY --
# literature-convert.sh's internal $DOC_ID is a lower-cased/sanitized string distinct from
# this loop's $basename_no_ext, which every downstream derivation (output_files, chunk_dir,
# doc_title) continues to use unchanged.
md_file=$(ls "$tmp_convert_dir"/*.md 2>/dev/null | head -1)
if [ -z "$md_file" ]; then
  echo "Error: conversion reported success but no .md file found for $src (skipping)"
  rm -rf "$tmp_convert_dir"
  rm -f "$convert_stderr"
  continue
fi
full_text=$(cat "$md_file")
rm -rf "$tmp_convert_dir"
rm -f "$convert_stderr"

# Count total lines
total_lines=$(echo "$full_text" | wc -l)
LINE_THRESHOLD=4000
MERGE_MIN=500
```

**Content-aware chunking algorithm**:

```bash
# Step 1: Detect logical section boundaries using heading patterns
# Supported heading patterns (in priority order):
#   - "Chapter N" / "CHAPTER N"  -> chapter boundary
#   - "N  Title" (number + spaces + capitalized text) -> numbered section
#   - "Part I/V/X..." / "Part 1/2..." -> part boundary
#   - "## Heading" / "### Heading" (markdown headings) -> section heading

section_starts=()  # line numbers where sections begin
section_names=()   # human-readable name for each section

while IFS= read -r line_num_and_content; do
  line_num="${line_num_and_content%%:*}"
  content="${line_num_and_content#*:}"
  if echo "$content" | grep -qE '^(Chapter|CHAPTER)[[:space:]]+[0-9IVXivx]+'; then
    section_starts+=("$line_num")
    section_names+=("$(echo "$content" | sed 's/^[[:space:]]*//' | cut -c1-60)")
  elif echo "$content" | grep -qE '^[0-9]+[[:space:]]{2,}[A-Z]'; then
    section_starts+=("$line_num")
    section_names+=("$(echo "$content" | sed 's/^[[:space:]]*//' | cut -c1-60)")
  elif echo "$content" | grep -qE '^Part[[:space:]]+([IVXivx]+|[0-9]+)'; then
    section_starts+=("$line_num")
    section_names+=("$(echo "$content" | sed 's/^[[:space:]]*//' | cut -c1-60)")
  elif echo "$content" | grep -qE '^#{1,3}[[:space:]]+\S'; then
    section_starts+=("$line_num")
    section_names+=("$(echo "$content" | sed 's/^#{1,3}[[:space:]]*//' | cut -c1-60)")
  fi
done < <(echo "$full_text" | grep -n "")

# Step 2: If headings found, merge small adjacent sections
if [ "${#section_starts[@]}" -gt 0 ]; then
  # Build merged chunks: combine adjacent sections until total lines >= LINE_THRESHOLD
  merged_chunks=()   # array of "start_line:end_line:name" strings
  chunk_start="${section_starts[0]}"
  chunk_name="${section_names[0]}"
  chunk_lines=0
  
  for i in "${!section_starts[@]}"; do
    if [ "$i" -eq 0 ]; then continue; fi
    prev_start="${section_starts[$((i-1))]}"
    curr_start="${section_starts[$i]}"
    section_size=$(( curr_start - prev_start ))
    
    if [ "$(( chunk_lines + section_size ))" -lt "$MERGE_MIN" ] || \
       [ "$(( chunk_lines + section_size ))" -lt "$LINE_THRESHOLD" ]; then
      # Merge into current chunk
      chunk_lines=$(( chunk_lines + section_size ))
    else
      # Flush current chunk
      chunk_end=$(( curr_start - 1 ))
      merged_chunks+=("${chunk_start}:${chunk_end}:${chunk_name}")
      chunk_start="$curr_start"
      chunk_name="${section_names[$i]}"
      chunk_lines=0
    fi
  done
  # Flush last chunk
  merged_chunks+=("${chunk_start}:${total_lines}:${chunk_name}")

  # Build chunks and output_files arrays from merged_chunks
  chunks=()
  output_files=()
  chunk_dir="$lit_dir/${sources_prefix}${basename_no_ext}"
  mkdir -p "$chunk_dir"
  
  for i in "${!merged_chunks[@]}"; do
    entry="${merged_chunks[$i]}"
    start_line="${entry%%:*}"
    rest="${entry#*:}"
    end_line="${rest%%:*}"
    name="${rest#*:}"
    slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//' | cut -c1-40)
    nn=$(printf "%02d" $(( i + 1 )))
    chunks+=("lines:${start_line}-${end_line}")
    output_files+=("${sources_prefix}${basename_no_ext}/section${nn}_${slug}.md")
  done

# Step 3: Fallback — no headings detected, use mechanical 4000-line splits
else
  chunks=()
  output_files=()
  start=1
  part_num=1
  chunk_dir="$lit_dir/${sources_prefix}${basename_no_ext}"
  
  if [ "$total_lines" -le "$LINE_THRESHOLD" ]; then
    # Single file — no chunking needed
    chunks+=("lines:1-${total_lines}")
    output_files+=("${sources_prefix}${basename_no_ext}.md")
  else
    mkdir -p "$chunk_dir"
    while [ "$start" -le "$total_lines" ]; do
      end=$(( start + LINE_THRESHOLD - 1 ))
      if [ "$end" -gt "$total_lines" ]; then end=$total_lines; fi
      nn=$(printf "%02d" "$part_num")
      chunks+=("lines:${start}-${end}")
      output_files+=("${sources_prefix}${basename_no_ext}/${basename_no_ext}_part${nn}.md")
      start=$(( end + 1 ))
      part_num=$(( part_num + 1 ))
    done
  fi
fi
```

### 3c: Confirm Chunk Boundaries with User

If multi-chunk (more than one output file), present proposed boundaries via AskUserQuestion:

Build a description showing detected sections or line ranges:
```bash
# Build display string from chunks and output_files arrays
chunk_preview=""
for i in "${!chunks[@]}"; do
  range="${chunks[$i]#lines:}"  # strip "lines:" prefix for display
  name=$(basename "${output_files[$i]}" .md)
  chunk_preview="${chunk_preview}\n  ${name}: lines ${range}"
done
approx_tokens=$(( total_lines * 15 / 10 ))  # rough estimate: 1.5 tokens/line
```

```json
{
  "question": "Convert '{basename}' ({total_lines} lines) into {N} chunks?",
  "header": "Chunk Boundaries for {basename}",
  "multiSelect": false,
  "options": [
    {
      "label": "Accept proposed chunks ({N} files)",
      "description": "Detected sections:\n{chunk_preview}"
    },
    {
      "label": "Use single file (no chunking)",
      "description": "Convert all {total_lines} lines to one {basename}.md (~{approx_tokens} tokens)"
    },
    {
      "label": "Skip this file",
      "description": "Do not convert {basename} now"
    }
  ]
}
```

If user selects "Use single file": set `chunks=("lines:1-${total_lines}")`, `output_files=("${basename_no_ext}.md")`
If user selects "Skip this file": continue to next file

### 3d: Write Chunk Files

For each chunk, extract the relevant lines from `full_text` and write to the output file:

```bash
for i in "${!chunks[@]}"; do
  chunk_range="${chunks[$i]#lines:}"  # strip "lines:" prefix
  start_line="${chunk_range%-*}"
  end_line="${chunk_range#*-}"
  output_md="$lit_dir/${output_files[$i]}"

  # Ensure parent directory exists (for chunked documents in subdirectory)
  mkdir -p "$(dirname "$output_md")"

  # Extract line range from full_text
  raw_text=$(echo "$full_text" | sed -n "${start_line},${end_line}p")

  # Check if text was extracted
  if [ -z "$(echo "$raw_text" | tr -d '[:space:]')" ]; then
    echo "Warning: No text in $src lines ${start_line}-${end_line}. File may be scanned/image-only and requires OCR."
    continue
  fi

  # Build title for this chunk
  doc_title=$(basename "$src" | sed 's/\.[^.]*$//' | tr '_-' '  ' | sed 's/\b\(.\)/\u\1/g')
  section_name=$(basename "$output_md" .md | sed 's/^[^_]*_//' | tr '-_' '  ')
  chunk_header=""
  if [ "${#chunks[@]}" -gt 1 ]; then
    chunk_header=" — ${section_name} (lines ${start_line}-${end_line})"
  fi

  markdown_content="# ${doc_title}${chunk_header}

${raw_text}"

  # Write to file
  echo "$markdown_content" > "$output_md"
done
```

### 3e: Compute Token Count and Auto-Generate Metadata

After writing each chunk file:

```bash
output_md="$lit_dir/${output_files[$i]}"
char_count=$(wc -c < "$output_md" 2>/dev/null || echo 0)
token_count=$(( char_count / 4 + 20 ))

# Extract auto-generated keywords (word frequency, top 10 after stopword removal)
# Stopword list (minimal)
stopwords="the a an and or but in on at to of for is are was were be been being have has had do does did will would could should may might shall can"

# Get word frequencies, filter stopwords, take top 10
auto_keywords=$(echo "$raw_text" | \
  tr '[:upper:]' '[:lower:]' | \
  tr -cs 'a-z' '\n' | \
  grep -v '^$' | \
  grep -v -w -F "$(echo "$stopwords" | tr ' ' '\n')" | \
  grep -E '^[a-z]{4,}$' | \
  sort | uniq -c | sort -rn | head -10 | \
  awk '{print $2}' | \
  jq -R . | jq -s . 2>/dev/null || echo '[]')

# Extract summary: look for Abstract, else use first 2-3 sentences
abstract_match=$(echo "$raw_text" | grep -i -A 5 "^[[:space:]]*abstract[[:space:]]*$" | head -6 | tail -5)
if [ -n "$abstract_match" ]; then
  auto_summary="$(echo "$abstract_match" | tr '\n' ' ' | sed 's/  */ /g' | cut -c1-300)"
else
  # First 2-3 sentences
  auto_summary=$(echo "$raw_text" | tr '\n' ' ' | sed 's/  */ /g' | grep -oP '^.{0,300}[.!?]' | head -1)
  if [ -z "$auto_summary" ]; then
    auto_summary=$(echo "$raw_text" | tr '\n' ' ' | sed 's/  */ /g' | cut -c1-200)
  fi
fi
```

### 3f: Confirm Metadata with User

First prompt for bibliographic fields:

```json
{
  "question": "Enter bibliographic metadata for '{output_filename}' (or press Enter to skip each):",
  "header": "Document Metadata"
}
```

Prompt for each field in sequence using AskUserQuestion:
- `{"question": "Authors (comma-separated, e.g. 'Alice Smith, Bob Jones'):"}` -> parse into string array
- `{"question": "Title (full document title):"}` -> string
- `{"question": "Year (publication year, e.g. 2024):"}` -> integer or null
- `{"question": "Document type (paper/book/chapter/section) [default: paper]:"}`  -> one of `paper|book|chapter|section`
- `{"question": "Source format (pdf/djvu/manual) [auto-detected: {detected_format}]:"}`  -> one of `pdf|djvu|manual` (default to detected extension)

Then confirm keywords and summary:

```json
{
  "question": "Review auto-generated keywords and summary for '{output_filename}':",
  "header": "Keywords and Summary",
  "multiSelect": false,
  "options": [
    {
      "label": "Accept auto-generated metadata",
      "description": "Keywords: {auto_keywords_preview}\nSummary: {auto_summary_preview}"
    },
    {
      "label": "Edit keywords",
      "description": "Keep summary, modify keyword list"
    },
    {
      "label": "Edit summary",
      "description": "Keep keywords, modify summary"
    },
    {
      "label": "Edit both",
      "description": "Modify both keywords and summary before indexing"
    }
  ]
}
```

If user selects "Edit keywords", prompt:
```json
{"question": "Enter keywords (comma-separated):"}
```
Parse response into JSON array.

If user selects "Edit summary", prompt:
```json
{"question": "Enter one-sentence summary:"}
```

### 3g: Update index.json

```bash
# Generate entry ID from filename (lowercase, underscores)
# For chunked sections, include subdirectory prefix to ensure uniqueness
if [[ "${output_files[$i]}" == *"/"* ]]; then
  entry_id=$(echo "${output_files[$i]}" | sed 's/\.md$//' | tr '[:upper:]' '[:lower:]' | tr '/ -' '_')
else
  entry_id=$(basename "$output_md" .md | tr '[:upper:]' '[:lower:]' | tr ' -' '_')
fi

# Determine source format from file extension
source_format="${ext}"  # "pdf" or "djvu"

# Determine doc_type, parent_doc, and page_range for chunked vs single-file entries
if [ "${#chunks[@]}" -gt 1 ] && [[ "${output_files[$i]}" == *"/"* ]]; then
  # Chunked section entry
  final_doc_type="section"
  parent_id=$(echo "$basename_no_ext" | tr '[:upper:]' '[:lower:]' | tr ' -' '_')
  parent_doc="$parent_id"
  chunk_range_display="${chunks[$i]#lines:}"
  page_range="lines:${chunk_range_display}"
else
  # Top-level (single file or user chose no-chunk) — use values from user prompt
  # final_doc_type already set from user prompt (default "paper")
  parent_doc=""
  page_range=""
fi

# Create or update index.json
if [ ! -f "$index_file" ]; then
  echo '{"token_budget": 4000, "entries": []}' > "$index_file"
fi

# Check if entry already exists
if jq -e --arg id "$entry_id" '.entries[] | select(.id == $id)' "$index_file" >/dev/null 2>&1; then
  # Update existing entry
  tmp=$(mktemp)
  jq --arg id "$entry_id" \
     --arg path "${output_files[$i]}" \
     --argjson tc "$token_count" \
     --argjson kw "$final_keywords" \
     --arg sum "$final_summary" \
     --argjson authors "$final_authors" \
     --arg title "$final_title" \
     --argjson year "$final_year" \
     --arg doc_type "$final_doc_type" \
     --arg source_format "$source_format" \
     --arg parent_doc "$parent_doc" \
     --arg page_range "$page_range" \
     '.entries = [.entries[] | if .id == $id then . + {
       "path": $path,
       "token_count": $tc,
       "keywords": $kw,
       "summary": $sum,
       "authors": $authors,
       "title": $title,
       "year": (if $year == "null" then null else ($year | tonumber) end),
       "doc_type": $doc_type,
       "source_format": $source_format,
       "parent_doc": (if $parent_doc == "" then null else $parent_doc end),
       "page_range": (if $page_range == "" then null else $page_range end)
     } else . end]' \
     "$index_file" > "$tmp" && mv "$tmp" "$index_file"
else
  # Append new entry
  tmp=$(mktemp)
  jq --arg id "$entry_id" \
     --arg path "${output_files[$i]}" \
     --argjson tc "$token_count" \
     --argjson kw "$final_keywords" \
     --arg sum "$final_summary" \
     --argjson authors "$final_authors" \
     --arg title "$final_title" \
     --argjson year "$final_year" \
     --arg doc_type "$final_doc_type" \
     --arg source_format "$source_format" \
     --arg parent_doc "$parent_doc" \
     --arg page_range "$page_range" \
     '.entries += [{
       "id": $id,
       "path": $path,
       "token_count": $tc,
       "keywords": $kw,
       "summary": $sum,
       "authors": $authors,
       "title": $title,
       "year": (if $year == "null" then null else ($year | tonumber) end),
       "doc_type": $doc_type,
       "source_format": $source_format,
       "parent_doc": (if $parent_doc == "" then null else $parent_doc end),
       "page_range": (if $page_range == "" then null else $page_range end)
     }]' \
     "$index_file" > "$tmp" && mv "$tmp" "$index_file"
fi
```

### 3h: Chunk and Index

Immediately after Convert Step 3g writes `output_md` and its `index.json` entry for this output
file, chunk it so the document is searchable without a separate `--ingest`. Use the shared
per-document `basename_no_ext` as `--doc-id` for **every** output file of this source (not
Step 3g's per-section `entry_id`), so multi-section conversions land all sections under one
`doc_id` — matching Job 4's `doc_id = <sources/dir basename>` check.

```bash
# Resolve literature-chunk.sh via the same SCRIPT_DIR/scripts convention Ingest Step 2 uses.
SCRIPT_DIR="$(dirname "$0")/../../scripts"
CHUNK_SCRIPT="$SCRIPT_DIR/literature-chunk.sh"

# output_md and basename_no_ext are already set from Steps 3d/3a above for this output file.
# dirname "$output_md" is already sources/<dir>-prefixed by construction (Step 3d's mkdir -p
# "$(dirname "$output_md")") — never introduce a $LITERATURE_DIR/$DOC_ID/ top-level path here.
chunk_count=0
if [ -x "$CHUNK_SCRIPT" ]; then
  # Guarded assignment (mirrors literature-ingest.sh's CHUNK_COUNT pattern): a chunking
  # failure is logged but never aborts the rest of the convert loop.
  chunk_count=$("$CHUNK_SCRIPT" "$output_md" "$(dirname "$output_md")" --doc-id "$basename_no_ext" 2>/dev/null || echo 0)
  if [ "${chunk_count:-0}" -eq 0 ]; then
    echo "Warning: chunking produced 0 chunks for $output_md (non-fatal; index rebuild at Step 4 will not cover it)."
  fi
else
  echo "Warning: literature-chunk.sh not found at $CHUNK_SCRIPT — skipping chunk step for $output_md (non-fatal)."
fi
```

## Convert Step 4: Display Summary

After all target files have been processed (all Step 3 iterations, including 3h, complete),
rebuild the search index exactly once per invocation so every chunk written above is queryable.
Branch on the same condition Step 2 already used to set `sources_prefix`:

```bash
if [ -n "${LITERATURE_DIR:-}" ] && [ "$lit_dir" = "$LITERATURE_DIR" ]; then
  "$SCRIPT_DIR/literature-build-index.sh" --global 2>&1 | sed 's/^/[convert] /' >&2 || \
    echo "Warning: literature-build-index.sh --global failed (non-fatal; chunks are on disk, index rebuild can be retried via /literature --rebuild)."
else
  "$SCRIPT_DIR/literature-build-index.sh" --local 2>&1 | sed 's/^/[convert] /' >&2 || \
    echo "Warning: literature-build-index.sh --local failed (non-fatal; chunks are on disk, index rebuild can be retried)."
fi
```

```
## Conversion Complete

**Files Converted**: {N}

| Output File | Lines | Tokens | Chunks | Status |
|-------------|-------|--------|--------|--------|
| {file1.md}  | 1-4000      | 3,500  | {chunk_count1} | Written, indexed |
| {file2.md}  | 4001-8000   | 3,200  | {chunk_count2} | Written, indexed |
...

**Index Updated**: specs/literature/index.json ({entry_count} entries)
**Search Index**: rebuilt ({global|local}) — converted documents are immediately searchable via
`literature-search.sh` with no separate `--ingest` step required.

**Skipped Files**:
- {file.djvu} — djvutxt not installed (install: nix-env -iA nixpkgs.djvulibre)
- {scan.pdf} — No text extracted (OCR required for scanned PDFs)
- {file} — QUALITY GATE FAILED: {reason}
- {file} — conversion failed (exit {code}): {reason}
```

A file listed under Skipped Files for either of the last two reasons was **not** written to
`index.json` and was **not** chunked — a gate rejection or hard conversion failure is a full skip,
never a partial or silent one.
