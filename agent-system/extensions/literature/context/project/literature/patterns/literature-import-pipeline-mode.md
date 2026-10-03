# Mode: Import Pipeline (Steps 8-12)

This file is the COMPLETE and ONLY specification for skill-literature's `Mode: Import Pipeline` (Steps 8-12, invoked from Search Step 7 for each `pdf_available` entry -- it has no `case "$mode"` dispatch arm of its own) execution. It MUST be followed exactly -- there is no fuller version of this content anywhere else. The `Mode: Import Pipeline` section of `skill-literature/SKILL.md` was extracted here per `context/patterns/mode-gated-section-loading.md`; the pointer at that section's former location in `SKILL.md`, and the pointer inside `literature-search-mode.md`'s Step 7, both send an agent here.

Import pipeline triggered from search selection for PDF-available entries. Invoked from Search Step 7 for each `pdf_available` entry.

## Import Step 8: Confirm Import

```bash
function handle_import() {
  local ckey="$1"
  local zotero_results="$2"

  # Extract Zotero metadata for this entry
  local title=$(echo "$zotero_results" | jq -r --arg ck "$ckey" '.[] | select(.citation_key == $ck) | .title' 2>/dev/null)
  local authors=$(echo "$zotero_results" | jq -r --arg ck "$ckey" '.[] | select(.citation_key == $ck) | .authors | join(", ")' 2>/dev/null)
  local year=$(echo "$zotero_results" | jq -r --arg ck "$ckey" '.[] | select(.citation_key == $ck) | .year' 2>/dev/null)
  local pdf_path=$(echo "$zotero_results" | jq -r --arg ck "$ckey" '.[] | select(.citation_key == $ck) | .pdf_paths[0]' 2>/dev/null)
  local abstract=$(echo "$zotero_results" | jq -r --arg ck "$ckey" '.[] | select(.citation_key == $ck) | .abstract_snippet' 2>/dev/null)
```

Present confirmation:
```json
{
  "question": "Import '{title}' ({year}) by {authors}?",
  "header": "Confirm Import",
  "multiSelect": false,
  "options": [
    {
      "label": "Yes — import and convert",
      "description": "Symlink PDF, convert to markdown, update index with Zotero metadata"
    },
    {
      "label": "Skip this entry",
      "description": "Do not import '{title}'"
    }
  ]
}
```

If user selects "Skip this entry": return without importing.

## Import Step 9: Create PDF Symlink

```bash
  # Ensure pdfs/ directory exists in Literature/ repo
  mkdir -p "$lit_dir/pdfs"

  # Symlink path: $LITERATURE_DIR/pdfs/{citation_key}.pdf
  symlink_path="$lit_dir/pdfs/${ckey}.pdf"

  if [ -L "$symlink_path" ]; then
    echo "Symlink already exists: $symlink_path (skipping creation)"
  elif [ -f "$symlink_path" ]; then
    echo "File already exists at symlink path: $symlink_path (skipping)"
  else
    ln -s "$pdf_path" "$symlink_path"
    echo "Created symlink: $symlink_path -> $pdf_path"
  fi
```

## Import Step 10: Run Convert with Pre-Populated Zotero Metadata

```bash
  # Pre-populate metadata from Zotero to reduce user prompts during convert
  # Pass as environment variables read by handle_convert()
  export PREFILL_TITLE="$title"
  export PREFILL_AUTHORS="$authors"
  export PREFILL_YEAR="$year"
  export PREFILL_DOC_TYPE="paper"
  export PREFILL_SOURCE_FORMAT="pdf"

  # Call existing handle_convert() with the symlinked PDF path
  file="$symlink_path"
  handle_convert

  # Clear prefill variables
  unset PREFILL_TITLE PREFILL_AUTHORS PREFILL_YEAR PREFILL_DOC_TYPE PREFILL_SOURCE_FORMAT
```

**Note**: handle_convert() checks PREFILL_* variables before prompting the user for each field:
```bash
# In handle_convert Convert Step 3f (metadata prompts), check PREFILL_* first:
if [ -n "${PREFILL_TITLE:-}" ]; then
  final_title="$PREFILL_TITLE"
else
  # ... prompt user
fi
```

## Import Step 11: Patch Index Entry with Zotero-Specific Fields

```bash
  # After handle_convert() writes the index entry, patch it with Zotero-specific fields
  # The entry_id is derived from the symlink basename (citation_key)
  entry_id=$(echo "$ckey" | tr '[:upper:]' '[:lower:]' | tr ' -' '_')

  # Get additional Zotero fields
  local zotero_key=$(echo "$zotero_results" | jq -r --arg ck "$ckey" '.[] | select(.citation_key == $ck) | .zotero_key // ""' 2>/dev/null)
  local zotero_path="$pdf_path"
  local bib_key="$ckey"
  # project_tags: derive from Zotero collections if available, else empty array
  local project_tags=$(echo "$zotero_results" | jq -r --arg ck "$ckey" '.[] | select(.citation_key == $ck) | .collections // []' 2>/dev/null)

  # Patch index.json with Zotero-specific fields via jq
  if jq -e --arg id "$entry_id" '.entries[] | select(.id == $id)' "$index_file" >/dev/null 2>&1; then
    tmp=$(mktemp)
    jq --arg id "$entry_id" \
       --arg zotero_key "$zotero_key" \
       --arg zotero_path "$zotero_path" \
       --arg bib_key "$bib_key" \
       --argjson project_tags "$project_tags" \
       '.entries = [.entries[] | if .id == $id then . + {
         "zotero_key": (if $zotero_key == "" then null else $zotero_key end),
         "zotero_path": $zotero_path,
         "bib_key": $bib_key,
         "project_tags": $project_tags
       } else . end]' \
       "$index_file" > "$tmp" && mv "$tmp" "$index_file"
    echo "Patched index entry '$entry_id' with Zotero metadata"
  else
    echo "Warning: index entry '$entry_id' not found after convert — Zotero fields not patched"
  fi
```

## Import Step 12: Git Commit to Literature/ Repo

```bash
  # Non-blocking git commit in $LITERATURE_DIR — targeted staging (never a repo-wide add) so an
  # import only commits the files this import produced, not unrelated stray edits elsewhere in
  # the separate Literature/ repo. Mirrors .claude/context/standards/git-staging-scope.md's
  # under-stage direction, adapted to this import's own artifact set (symlink, converted
  # markdown, index.json) since Literature/ is a separate git repo with no task-dir concept.
  # Left as a raw `git add` + `git commit -m` rather than migrated to git-commit-scoped.sh: the
  # Literature/ repo is a content-only repo with no agent-system deployed in it (no
  # .claude/scripts/git-commit-scoped.sh exists there to invoke), and the pathspec set here is
  # already correctly targeted, so raw git is the only option available in that repo.
  if [ -d "$lit_dir/.git" ]; then
    (
      cd "$lit_dir" && \
      git add "pdfs/${ckey}.pdf" "index.json" \
        $(find . -maxdepth 2 -name "${entry_id}*.md" -not -path "./source_files/*" 2>/dev/null) && \
      git commit -m "import: $title ($year)" 2>&1 | head -5
    ) || echo "Note: git commit in $lit_dir failed (non-blocking)"
  fi

  echo ""
  echo "Import complete: $ckey"
  echo "  Markdown: $lit_dir/{converted_path}"
  echo "  Index: $index_file (entry: $entry_id)"
}  # end handle_import()
```

**Processing order**: Import processes entries sequentially (one at a time) to support interactive convert prompts. Each entry completes its full import pipeline (steps 9-12) before the next entry begins.
