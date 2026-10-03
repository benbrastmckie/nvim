# Mode: Search

This file is the COMPLETE and ONLY specification for skill-literature's `Mode: Search` (`mode=search`) execution. It MUST be followed exactly -- there is no fuller version of this content anywhere else. The `Mode: Search` section of `skill-literature/SKILL.md` was extracted here per `context/patterns/mode-gated-section-loading.md`; the pointer at that section's former location in `SKILL.md` sends an agent here whenever `mode=search` is dispatched.

Search the Zotero library and Literature/ index, present interactive multi-select results, and trigger import for selected entries.

## Search Step 1: Resolve zotero-search.sh Path

```bash
# Find zotero-search.sh. provides.scripts deploys flat into {base_dir}/scripts/ in every
# consuming repo (never into {base_dir}/extensions/{name}/scripts/, which only ever holds a
# copied manifest.json), so the flat sibling path is the primary candidate. The nested path is
# kept only as a defensive fallback for running directly from the extension source tree
# pre-deployment.
zotero_script=""
for candidate in \
  ".claude/scripts/zotero-search.sh" \
  "$(dirname "$0")/../../scripts/zotero-search.sh" \
  ".claude/extensions/literature/scripts/zotero-search.sh"; do
  if [ -f "$candidate" ]; then
    zotero_script="$candidate"
    break
  fi
done

# Validate query is not empty
if [ -z "$query" ]; then
  echo "Error: search mode requires a query. Usage: /literature --search \"modal logic\""
  exit 1
fi

# Split query into terms for scoring
IFS=' ' read -ra query_terms <<< "$query"
```

## Search Step 2: Run zotero-search.sh (with Graceful Degradation)

```bash
zotero_results=""
zotero_available=false
zotero_exit_code=0

if [ -n "$zotero_script" ] && [ -x "$zotero_script" ]; then
  # Run zotero-search.sh with JSON output format, limit 20 results
  zotero_results=$("$zotero_script" --format=json --limit=20 "${query_terms[@]}" 2>&1) || zotero_exit_code=$?

  case "$zotero_exit_code" in
    0)
      zotero_available=true
      ;;
    1)
      # Library not found — show setup instructions (zotero-search.sh prints them to stderr)
      echo "## Zotero Library Not Configured"
      echo ""
      echo "No zotero-library.json found. To enable Zotero search:"
      echo "1. Install Zotero with Better BibTeX plugin"
      echo "2. Export your library: File > Export Library > Better CSL JSON"
      echo "3. Save as: \$LITERATURE_DIR/zotero-library.json (default: ~/Projects/Literature/zotero-library.json)"
      echo ""
      echo "Falling back to Literature/ index search only..."
      zotero_results=""
      ;;
    2)
      # No results found — continue to index-only search
      echo "No Zotero results for query: $query"
      zotero_results=""
      ;;
  esac
else
  echo "Note: zotero-search.sh not found. Searching Literature/ index only."
fi
```

## Search Step 3: Cross-Reference Zotero Results with Literature/ Index

```bash
# Parse Zotero results (JSON array of entries)
declare -A result_status  # citation_key -> "already_converted" | "pdf_available" | "pdf_not_available"
declare -A result_paths   # citation_key -> path in Literature/ index (for already_converted)
declare -a result_keys    # ordered list of citation keys

if [ -n "$zotero_results" ] && [ "$zotero_available" = "true" ]; then
  # Extract citation keys from Zotero results
  while IFS= read -r ckey; do
    result_keys+=("$ckey")

    # Check if already in Literature/ index (match on bib_key or zotero_key == citation_key)
    if [ -f "$index_file" ]; then
      match_path=$(jq -r --arg ck "$ckey" '
        .entries[] | select(
          (.bib_key == $ck) or
          (.zotero_key == $ck) or
          (.id == $ck)
        ) | .path
      ' "$index_file" 2>/dev/null | head -1)

      if [ -n "$match_path" ] && [ "$match_path" != "null" ]; then
        result_status["$ckey"]="already_converted"
        result_paths["$ckey"]="$lit_dir/$match_path"
        continue
      fi
    fi

    # Check if PDF is available via Zotero
    pdf_paths=$(echo "$zotero_results" | jq -r --arg ck "$ckey" '
      .[] | select(.citation_key == $ck) | .pdf_paths[]?
    ' 2>/dev/null)

    if [ -n "$pdf_paths" ]; then
      # Verify at least one PDF exists
      has_pdf=false
      while IFS= read -r pdf_path; do
        if [ -f "$pdf_path" ]; then
          has_pdf=true
          break
        fi
      done <<< "$pdf_paths"

      if [ "$has_pdf" = "true" ]; then
        result_status["$ckey"]="pdf_available"
      else
        result_status["$ckey"]="pdf_not_available"
      fi
    else
      result_status["$ckey"]="pdf_not_available"
    fi
  done < <(echo "$zotero_results" | jq -r '.[].citation_key' 2>/dev/null)
fi
```

## Search Step 4: Search Literature/ Index Directly

```bash
# Score index entries against query terms (keyword overlap scoring)
declare -A index_scores  # entry_id -> score
declare -a index_keys    # ordered list of index entry ids

if [ -f "$index_file" ]; then
  while IFS=$'\t' read -r entry_id entry_path entry_keywords entry_title; do
    score=0
    combined="${entry_keywords} ${entry_title}"
    combined_lower=$(echo "$combined" | tr '[:upper:]' '[:lower:]')

    for term in "${query_terms[@]}"; do
      term_lower=$(echo "$term" | tr '[:upper:]' '[:lower:]')
      if echo "$combined_lower" | grep -q "$term_lower"; then
        score=$(( score + 1 ))
      fi
    done

    if [ "$score" -gt 0 ]; then
      index_scores["$entry_id"]=$score
      index_keys+=("$entry_id")

      # Only add to results if not already present from Zotero search
      bib_key=$(jq -r --arg id "$entry_id" '.entries[] | select(.id == $id) | .bib_key // ""' "$index_file" 2>/dev/null)
      if [ -z "$bib_key" ] || [ -z "${result_status[$bib_key]+_}" ]; then
        if [ -z "${result_status[$entry_id]+_}" ]; then
          result_keys+=("$entry_id")
          result_status["$entry_id"]="already_converted"
          result_paths["$entry_id"]="$lit_dir/$entry_path"
        fi
      fi
    fi
  done < <(jq -r '.entries[] | [.id, .path, (.keywords // [] | join(" ")), (.title // "")] | @tsv' "$index_file" 2>/dev/null)
fi
```

## Search Step 5: Merge and Sort Results

```bash
# Build display array sorted by score (Zotero score + index keyword overlap)
declare -a display_entries  # "citation_key|title|authors|year|score|status" strings

for ckey in "${result_keys[@]}"; do
  # Get metadata from Zotero results or index
  if [ "$zotero_available" = "true" ] && echo "$zotero_results" | jq -e --arg ck "$ckey" '.[] | select(.citation_key == $ck)' >/dev/null 2>&1; then
    title=$(echo "$zotero_results" | jq -r --arg ck "$ckey" '.[] | select(.citation_key == $ck) | .title' 2>/dev/null | head -1)
    authors=$(echo "$zotero_results" | jq -r --arg ck "$ckey" '.[] | select(.citation_key == $ck) | .authors | join(", ")' 2>/dev/null | head -1)
    year=$(echo "$zotero_results" | jq -r --arg ck "$ckey" '.[] | select(.citation_key == $ck) | .year' 2>/dev/null | head -1)
    score=$(echo "$zotero_results" | jq -r --arg ck "$ckey" '.[] | select(.citation_key == $ck) | .score' 2>/dev/null | head -1)
  else
    # Get from Literature/ index
    title=$(jq -r --arg id "$ckey" '.entries[] | select(.id == $id) | .title // "Unknown"' "$index_file" 2>/dev/null)
    authors=$(jq -r --arg id "$ckey" '.entries[] | select(.id == $id) | (.authors // []) | join(", ")' "$index_file" 2>/dev/null)
    year=$(jq -r --arg id "$ckey" '.entries[] | select(.id == $id) | .year // "?"' "$index_file" 2>/dev/null)
    score="${index_scores[$ckey]:-0}"
  fi

  status="${result_status[$ckey]:-pdf_not_available}"
  display_entries+=("${ckey}|${title}|${authors}|${year}|${score}|${status}")
done

# Sort by score descending (simple bubble-pass sort on score field)
IFS=$'\n' display_entries=($(printf '%s\n' "${display_entries[@]}" | sort -t'|' -k5 -rn))
```

## Search Step 6: Present Multi-Select Results via AskUserQuestion

```bash
# Build options array for AskUserQuestion
options=()
for entry in "${display_entries[@]}"; do
  IFS='|' read -r ckey title authors year score status <<< "$entry"

  # Format availability tag
  case "$status" in
    already_converted) tag="[IMPORTED]" ;;
    pdf_available)     tag="[PDF AVAILABLE]" ;;
    pdf_not_available) tag="[NO PDF]" ;;
  esac

  label="${tag} ${title}"
  description="Authors: ${authors:-Unknown} | Year: ${year:-?} | Score: ${score} | Key: ${ckey}"
  options+=("{\"label\": \"${label}\", \"description\": \"${description}\"}")
done

# Add escape option
options+=("{\"label\": \"Done — no import\", \"description\": \"Exit search without importing\"}")
```

Present via AskUserQuestion:
```json
{
  "question": "Search results for '{query}' ({N} results). Select entries to import:",
  "header": "Literature Search Results",
  "multiSelect": true,
  "options": [
    {
      "label": "[IMPORTED] Title of Already-Converted Paper",
      "description": "Authors: Author Name | Year: 2023 | Score: 5 | Key: author2023_title"
    },
    {
      "label": "[PDF AVAILABLE] Title of Importable Paper",
      "description": "Authors: Author Name | Year: 2022 | Score: 3 | Key: author2022_title"
    },
    {
      "label": "[NO PDF] Title of Paper Without PDF",
      "description": "Authors: Author Name | Year: 2021 | Score: 2 | Key: author2021_title"
    },
    {
      "label": "Done — no import",
      "description": "Exit search without importing"
    }
  ]
}
```

## Search Step 7: Route Selected Entries

For a `pdf_available` selection below, the import flow is triggered but is NOT specified in this
file. Import Pipeline has no `case "$mode"` dispatch arm of its own — this pointer is its only
reachable entry point from a search-driven import:
READ .claude/context/project/literature/patterns/literature-import-pipeline-mode.md now and
follow it exactly.

```bash
for selected in "${user_selections[@]}"; do
  ckey=$(extract_citation_key_from_selection "$selected")
  status="${result_status[$ckey]}"

  case "$status" in
    already_converted)
      # Show path info — already in Literature/
      path="${result_paths[$ckey]}"
      echo "Already imported: $ckey"
      echo "  Path: $path"
      ;;

    pdf_available)
      # Trigger import pipeline (Steps 8-12, specified in literature-import-pipeline-mode.md)
      handle_import "$ckey" "$zotero_results"
      ;;

    pdf_not_available)
      echo "No PDF available for: $ckey"
      echo "  Add the PDF to your Zotero library to enable import."
      ;;
  esac
done
```

**Edge case**: If both Zotero search fails (exit 1) and the index has no matching entries, display:
```
No results found for query: "{query}"

Zotero library not configured (or no matches). Literature/ index also returned no matches.
Suggestions:
  - Try broader search terms
  - Run /literature --convert to add local PDFs
  - Configure Zotero: set ZOTERO_LIBRARY or place zotero-library.json in $LITERATURE_DIR/
```
