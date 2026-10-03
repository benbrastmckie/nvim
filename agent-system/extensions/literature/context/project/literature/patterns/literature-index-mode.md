# Mode: Index

This file is the COMPLETE and ONLY specification for skill-literature's `Mode: Index` (`mode=index`) execution. It MUST be followed exactly -- there is no fuller version of this content anywhere else. The `Mode: Index` section of `skill-literature/SKILL.md` was extracted here per `context/patterns/mode-gated-section-loading.md`; the pointer at that section's former location in `SKILL.md` sends an agent here whenever `mode=index` is dispatched.

Add or update an index.json entry for an existing markdown file.

## Index Step 1: Validate File Exists

```bash
if [ -z "$file" ]; then
  echo "Error: --index requires a FILE argument."
  exit 1
fi

if [ ! -f "$file" ]; then
  echo "Error: File not found: $file"
  exit 1
fi

# Get relative path within specs/literature/
if [[ "$file" == "$lit_dir/"* ]]; then
  rel_path="${file#$lit_dir/}"
else
  rel_path="$(basename "$file")"
fi
```

## Index Step 2: Compute Token Count

```bash
char_count=$(wc -c < "$file" 2>/dev/null || echo 0)
token_count=$(( char_count / 4 + 20 ))
```

## Index Step 3: Auto-Generate Metadata

Same word-frequency keyword extraction and summary extraction as Convert Step 3e.

## Index Step 4: Prompt User for Bibliographic Metadata

Auto-detect `source_format` from the file extension in the filename (if present), or default to `"manual"`.

Prompt for bibliographic fields in sequence using AskUserQuestion:
- `{"question": "Authors (comma-separated, e.g. 'Alice Smith, Bob Jones') [or Enter to skip]:"}` -> parse into string array
- `{"question": "Title (full document title) [or Enter to skip]:"}` -> string
- `{"question": "Year (publication year) [or Enter to skip]:"}` -> integer or null
- `{"question": "Document type (paper/book/chapter/section) [default: paper]:"}` -> one of `paper|book|chapter|section`
- `{"question": "Source format (pdf/djvu/manual) [auto-detected: {detected_format}]:"}` -> one of `pdf|djvu|manual`
- `{"question": "Parent document ID (for chunks/sections) [or Enter if top-level]:"}` -> string or null
- `{"question": "Page range in source document (e.g. '15-47') [or Enter if not applicable]:"}` -> string or null

Then confirm keywords and summary:

```json
{
  "question": "Confirm keywords and summary for '{rel_path}' ({token_count} tokens):",
  "header": "Keywords and Summary",
  "multiSelect": false,
  "options": [
    {
      "label": "Accept auto-generated metadata",
      "description": "Keywords: {auto_keywords_preview}\nSummary: {auto_summary_preview}"
    },
    {
      "label": "Enter custom keywords",
      "description": "Manually specify keyword list"
    },
    {
      "label": "Enter custom summary",
      "description": "Manually write summary"
    },
    {
      "label": "Enter both custom",
      "description": "Specify both keywords and summary"
    }
  ]
}
```

If custom keywords requested:
```json
{"question": "Enter keywords (comma-separated):"}
```

If custom summary requested:
```json
{"question": "Enter one-sentence summary:"}
```

## Index Step 5: Write to index.json

```bash
# Initialize index.json if it does not exist
if [ ! -f "$index_file" ]; then
  echo '{"token_budget": 4000, "entries": []}' > "$index_file"
fi

entry_id=$(basename "$file" .md | tr '[:upper:]' '[:lower:]' | tr ' -' '_')

# Check if entry already exists
if jq -e --arg id "$entry_id" '.entries[] | select(.id == $id)' "$index_file" >/dev/null 2>&1; then
  # Update existing entry
  tmp=$(mktemp)
  jq --arg id "$entry_id" \
     --arg path "$rel_path" \
     --argjson tc "$token_count" \
     --argjson kw "$final_keywords" \
     --arg sum "$final_summary" \
     --argjson authors "$final_authors" \
     --arg title "$final_title" \
     --argjson year "$final_year" \
     --arg doc_type "$final_doc_type" \
     --arg source_format "$final_source_format" \
     --arg parent_doc "$final_parent_doc" \
     --arg page_range "$final_page_range" \
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
  echo "Updated existing entry '$entry_id' in $index_file"
else
  # Append new entry
  tmp=$(mktemp)
  jq --arg id "$entry_id" \
     --arg path "$rel_path" \
     --argjson tc "$token_count" \
     --argjson kw "$final_keywords" \
     --arg sum "$final_summary" \
     --argjson authors "$final_authors" \
     --arg title "$final_title" \
     --argjson year "$final_year" \
     --arg doc_type "$final_doc_type" \
     --arg source_format "$final_source_format" \
     --arg parent_doc "$final_parent_doc" \
     --arg page_range "$final_page_range" \
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
  echo "Added new entry '$entry_id' to $index_file"
fi
```

## Index Step 6: Display Result

```
## Index Entry Added

**File**: {rel_path}
**Entry ID**: {entry_id}
**Token Count**: {token_count}
**Keywords**: {keywords}
**Summary**: {summary}

**Index**: specs/literature/index.json ({N} entries total)
```
