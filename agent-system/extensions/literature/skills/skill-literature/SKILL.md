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

Full pipeline ingestion: convert PDF/DJVU to markdown, chunk hierarchically, index in global SQLite FTS5 database, and optionally load into local specs/literature/.

### Ingest Step 1: Resolve Source Path

```bash
if [ -z "$file" ]; then
  echo "Error: --ingest requires a path or --zotero key."
  echo "Usage: /literature --ingest <path> | /literature --ingest --zotero <key>"
  exit 1
fi
```

### Ingest Step 2: Invoke literature-ingest.sh

Find the ingest script relative to the skill's script directory:

```bash
SCRIPT_DIR="$(dirname "$0")/../../scripts"
INGEST_SCRIPT="$SCRIPT_DIR/literature-ingest.sh"

if [ ! -x "$INGEST_SCRIPT" ]; then
  echo "Error: literature-ingest.sh not found at: $INGEST_SCRIPT"
  exit 1
fi

# Route to ingest script with appropriate flags
if [ -n "$zotero_key" ]; then
  "$INGEST_SCRIPT" --zotero "$zotero_key" "$@"
else
  "$INGEST_SCRIPT" "$file" "$@"
fi
```

Where:
- `$file` is the source path (PDF, DJVU, or directory)
- `$zotero_key` is the Zotero citation key (if using `--zotero`)
- Remaining `$@` may include `--no-local` or `--local` flags

### Ingest Step 3: Display Result

The `literature-ingest.sh` script outputs a summary to stdout on completion. Relay this output to the user verbatim, then add:

```
To search the ingested literature: /literature --search "query"
Or use --lit flag in research/plan/implement commands to enable agent search.
```

### Ingest Examples

```bash
# Ingest a single PDF
/literature --ingest ~/Papers/modal-logic.pdf

# Ingest all PDFs in a directory
/literature --ingest ~/Papers/modal-logic/

# Ingest from Zotero (requires zotero-library.json)
/literature --ingest --zotero "BlackburnDeRijkeVenema2001"

# Ingest and skip local loading prompt
/literature --ingest ~/Papers/modal-logic.pdf --no-local

# Ingest and automatically load into specs/literature/
/literature --ingest ~/Papers/modal-logic.pdf --local
```

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

Check index.json against the filesystem for stale entries, missing files, and token count drift.

### Validate Step 1: Load Index

```bash
if [ ! -f "$index_file" ]; then
  echo "## Literature Validation"
  echo ""
  echo "No index.json found at $index_file."
  echo "Run /literature to see status, or /literature --convert to convert files and create the index."
  exit 0
fi

# Iterate entries as WHOLE RECORDS (one compact-JSON object per line), never as bare
# `.path` strings. Driving the loop off `.entries[] | .path` collapses a `.path`-less
# entry (a schema-shape defect, e.g. a stub written by an older literature-ingest.sh)
# into the literal string "null" -- which then resolves to a nonexistent file
# "$lit_dir/null" and gets misreported as a missing FILE ("null (missing)") rather than
# surfaced as the schema defect it actually is. Reading each entry as a full record
# lets Step 2 below classify a path-less/id-less entry correctly before ever touching
# the filesystem.
entries=$(jq -c '.entries[]' "$index_file" 2>/dev/null)
```

### Validate Step 2: Check Each Entry

For each indexed entry, check:

1. Existence at `specs/literature/{entry.path}`: `-f` for file-path entries, `-d` for
   directory-path entries (book/parent-level records whose `path` ends in `/`)
2. Token count drift (recount vs stored, flag if >20% different) — applies to file-path entries
   only; directory-path entries have no single content file to recount against
3. Required schema fields present — **top-level document entries only** (`parent_doc` null or
   empty; a section/chunk entry is held only to checks 1, 2, and 4, never to this one): `doc_type`,
   `source_format`, `authors`, `title`. This is the full field list the check enforces; `id`/`path`
   are covered separately by the schema-shape bucket above, and `keywords`/`summary` are not
   enforced by any check today.
4. `authors` field shape: present and an array, all elements are strings, and no element looks
   like an unsplit comma-joined multi-author string (see authors-shape check below). This catches
   regressions from any future writer that reintroduces the malformed schema this check guards against —
   see `.claude/context/project/literature/domain/literature-index.md` for the tooling ownership
   boundary and `.claude/scripts/literature-normalize-authors.sh` for the companion fix-up tool.

```bash
stale_entries=()
drift_entries=()
schema_warnings=()
authors_shape_warnings=()
schema_shape_defects=()

while IFS= read -r entry_json; do
  [ -z "$entry_json" ] && continue

  entry_id=$(echo "$entry_json" | jq -r '.id // .doc_id // empty')
  entry_path=$(echo "$entry_json" | jq -r '.path // empty')

  # --- Schema-shape bucket, reported separately from stale entries ---
  # An entry missing .id (and .doc_id), missing .path, or carrying a .path that is not
  # sources/-prefixed is a SCHEMA-SHAPE defect (the entry itself is malformed), not a
  # missing-file defect (the entry is well-formed but its target vanished). Classifying
  # it here, before any filesystem check runs, is what ends the old "null (missing)"
  # misreport: a .path-less entry never reaches the file-existence check below at all.
  shape_defects=()
  [ -z "$entry_id" ] && shape_defects+=("missing .id/.doc_id")
  if [ -z "$entry_path" ]; then
    shape_defects+=("missing .path")
  elif [[ "$entry_path" != sources/* ]]; then
    shape_defects+=("path not sources/-prefixed: $entry_path")
  fi
  if [ "${#shape_defects[@]}" -gt 0 ]; then
    label="${entry_id:-<no id>}"
    joined=$(IFS=", "; echo "${shape_defects[*]}")
    schema_shape_defects+=("$label ($joined)")
    # A path-less entry has no filesystem target to check and no .path to key the
    # existing per-path checks below on -- skip straight to the next entry rather than
    # falling through into checks that assume entry_path is usable.
    [ -z "$entry_path" ] && continue
  fi

  full_path="$lit_dir/$entry_path"

  # Directory-path entries (trailing slash, or resolves to a directory on disk) are a
  # legitimate second schema variant: parent-level records for a book split into many
  # semantic chunks (doc_type: "book", token_count: 0 by design). They have no single
  # content file to recount tokens against, so existence is the sufficient check.
  if [[ "$entry_path" == */ ]] || [ -d "$full_path" ]; then
    if [ ! -d "$full_path" ]; then
      stale_entries+=("$entry_path (missing directory)")
      continue
    fi
  elif [ ! -f "$full_path" ]; then
    stale_entries+=("$entry_path (missing)")
    continue
  else
    # Recount tokens (file-path entries only)
    char_count=$(wc -c < "$full_path" 2>/dev/null || echo 0)
    current_tokens=$(( char_count / 4 + 20 ))
    stored_tokens=$(echo "$entry_json" | jq -r '.token_count // 0')

    if [ -n "$stored_tokens" ] && [ "$stored_tokens" -gt 0 ]; then
      # Calculate drift percentage
      diff=$(( current_tokens - stored_tokens ))
      if [ "$diff" -lt 0 ]; then diff=$(( -diff )); fi
      drift_pct=$(( diff * 100 / stored_tokens ))
      if [ "$drift_pct" -gt 20 ]; then
        drift_entries+=("$entry_path (stored: $stored_tokens, actual: $current_tokens, drift: ${drift_pct}%)")
      fi
    fi
  fi

  # Check for required schema fields (new in schema v2). Reads the already-parsed
  # entry record directly (no re-query by path needed). Scoped to top-level document
  # entries only (parent_doc null/empty), reusing literature-coverage-delta.sh's
  # canonical top-level predicate verbatim -- section/chunk entries lack these fields
  # by design and are not expected to carry them. A directory-path (book/parent) entry
  # is itself top-level, so it remains covered.
  missing_fields=$(echo "$entry_json" | jq -r '
    if (.parent_doc == null or .parent_doc == "") then
      [
        (if .doc_type == null or .doc_type == "" then "doc_type" else empty end),
        (if .source_format == null or .source_format == "" then "source_format" else empty end),
        (if .authors == null then "authors" else empty end),
        (if .title == null or .title == "" then "title" else empty end)
      ] | join(", ")
    else
      ""
    end
  ' 2>/dev/null || echo "")
  if [ -n "$missing_fields" ]; then
    schema_warnings+=("$entry_path (missing fields: $missing_fields)")
  fi

  # Check authors field shape (catch non-array or comma-joined authors so any
  # future writer that reintroduces the malformed schema is caught by routine validation).
  # The "possibly-comma-joined" heuristic is conservative: it flags an array element only
  # when it contains 2+ ", " occurrences, or exactly one ", " followed by a second
  # non-initial capitalized name-like token (2+ letters). This avoids false positives on
  # legitimate single-author "Last, First" or "Last, First M." formatting (the pattern the
  # former zotero index-add script itself produced), while still catching packed multi-author strings
  # like "Patrick Blackburn, Maarten de Rijke, Yde Venema" or two-author strings like
  # "Patrick Blackburn, Maarten de Rijke". Mirror this same heuristic in
  # literature-normalize-authors.sh so validate and normalize stay consistent. Also reads
  # the already-parsed entry record directly, so this covers directory-path entries too.
  authors_shape=$(echo "$entry_json" | jq -r '
    def is_comma_joined:
      ( [scan(", ")] | length ) as $n
      | if $n >= 2 then true
        elif $n == 1 then
          ( (split(", ")[1]) | ([scan("[A-Z][a-zA-Z]+")] | length) ) >= 2
        else false
        end;
    [
      (if .authors != null and (.authors | type) != "array" then "authors:not-array" else empty end),
      (if (.authors | type) == "array" and (.authors | any(type != "string")) then "authors:non-string-element" else empty end),
      (if (.authors | type) == "array" and (.authors | any(type == "string" and is_comma_joined)) then "authors:possibly-comma-joined" else empty end)
    ] | join(", ")
  ' 2>/dev/null || echo "")
  if [ -n "$authors_shape" ]; then
    authors_shape_warnings+=("$entry_path ($authors_shape)")
  fi
done <<< "$entries"
```

### Validate Step 2b: Namespace Divergence Check (hard failure, with recorded exceptions)

Compares index.json's identity space against `.literature.db`'s `chunks_data.doc_id` space,
using the same path-derived bridge `literature-search.sh`'s `get_project_doc_ids()` and
`literature-doc-key.sh` already use (never `.id` alone — see that script's header for the full
invariant). The corpus-side residue was reconciled (17 new parent entries added under their
bare directory id, 2 duplicate ingest directories quarantined and their stub index entries
removed — see `context/project/literature/domain/literature-index.md`'s FTS-namespace
subsection for the invariant and corpus history). This check now **fails the command** on any
divergence entry outside the recorded known-exceptions list below; an empty divergence bucket
(modulo those exceptions) is the expected steady state, not an aspiration.

Known exceptions (carried forward with a recorded reason, never silently expanded — adding to
this list requires the same adjudication rigor as the original corpus reconciliation, not a
quick edit to silence a new failure):
- `gabbay_2000` (index-only: no FTS chunks) — conversion rejected; stamped
  `provenance_fidelity: not_yet_converted`. Not a defect to fix by this check; re-adjudicate by
  re-converting the source, not by editing this exceptions list.

```bash
# Validate mode can be invoked without passing through Convert mode's setup, so
# resolve SCRIPT_DIR defensively here rather than assuming it is already set.
SCRIPT_DIR="${SCRIPT_DIR:-$(dirname "$0")/../../scripts}"
DOC_KEY_SCRIPT="$SCRIPT_DIR/literature-doc-key.sh"
DIVERGENCE_KNOWN_EXCEPTIONS_NOTE="known exceptions: gabbay_2000 (index-only, conversion rejected, provenance_fidelity: not_yet_converted) -- any other divergence entry fails this check"
# Bare directory ids carried as recorded exceptions to the hard-failure gate below.
# Format matches the "{id} (dir key: {dir_key})" label divergence_index_only entries use.
DIVERGENCE_KNOWN_EXCEPTION_IDS=("gabbay_2000")

divergence_fts_only=()
divergence_index_only=()
divergence_id_inconsistent=()

if [ -x "$DOC_KEY_SCRIPT" ] && [ -f "$lit_dir/.literature.db" ] && command -v sqlite3 >/dev/null 2>&1; then
  fts_ids=$(sqlite3 "$lit_dir/.literature.db" "SELECT DISTINCT doc_id FROM chunks_data;" 2>/dev/null | sort -u)
  index_keys=$("$DOC_KEY_SCRIPT" --list-keys "$index_file" 2>/dev/null | sort -u)

  # FTS doc_ids with no index coverage at all (neither .id nor path-derived key reaches them)
  while IFS= read -r fid; do
    [ -z "$fid" ] && continue
    if ! grep -qxF "$fid" <<< "$index_keys"; then
      divergence_fts_only+=("$fid")
    fi
  done <<< "$fts_ids"

  # Index dir keys (parent entries' path-derived key) with no FTS chunks under that key
  while IFS= read -r entry_json; do
    [ -z "$entry_json" ] && continue
    is_parent=$(echo "$entry_json" | jq -r 'if (.parent_doc == null or .parent_doc == "") then "yes" else "no" end')
    [ "$is_parent" != "yes" ] && continue
    p_id=$(echo "$entry_json" | jq -r '.id // .doc_id // empty')
    p_path=$(echo "$entry_json" | jq -r '.path // empty')
    [ -z "$p_id" ] && continue
    dir_key="$p_id"
    if [[ "$p_path" == sources/* ]]; then
      dir_key="${p_path#sources/}"
      dir_key="${dir_key%%/*}"
    fi
    dir_key_in_fts="no"
    grep -qxF "$dir_key" <<< "$fts_ids" && dir_key_in_fts="yes"
    if [ "$dir_key_in_fts" = "no" ]; then
      divergence_index_only+=("$p_id (dir key: $dir_key)")
    fi
    # Parent entries whose .id is neither its own path-derived key nor present in FTS
    # under EITHER lookup strategy -- i.e. completely unreachable, not merely a
    # curated-id-differs-from-FTS-id pairing. The `.id != dir_key` paired case (the 17
    # supported entries Decision C names) is deliberately NOT reported here: when
    # `dir_key` itself resolves in FTS, the path bridge already covers that entry, and
    # Decision C is explicit that a differing curated `.id` is a supported
    # configuration in that case, not a defect. Gating on `dir_key_in_fts == no` (in
    # addition to `.id` also not resolving) is what keeps this bucket at the expected
    # near-zero count on a corpus where the bridge is doing its job, rather than
    # re-flagging every one of those 17 supported pairings as broken.
    if [ "$p_id" != "$dir_key" ] && [ "$dir_key_in_fts" = "no" ] && ! grep -qxF "$p_id" <<< "$fts_ids"; then
      divergence_id_inconsistent+=("$p_id (path-derived key: $dir_key)")
    fi
  done <<< "$entries"
  divergence_check_skipped="no"
else
  echo "Warning: namespace-divergence check skipped (literature-doc-key.sh, .literature.db, or sqlite3 unavailable)" >&2
  divergence_check_skipped="yes"
fi

# --- Split divergence_index_only into recorded-known-exceptions vs. unexpected ---
# (divergence_fts_only and divergence_id_inconsistent have no recorded exceptions today --
# every entry in either bucket is unexpected and fails the check. gabbay_2000 is the sole
# recorded exception, and it only ever lands in divergence_index_only.)
divergence_index_only_known=()
divergence_index_only_unexpected=()
for item in "${divergence_index_only[@]:-}"; do
  [ -z "$item" ] && continue
  is_known="no"
  for exc in "${DIVERGENCE_KNOWN_EXCEPTION_IDS[@]}"; do
    case "$item" in
      "$exc "*) is_known="yes"; break ;;
    esac
  done
  if [ "$is_known" = "yes" ]; then
    divergence_index_only_known+=("$item")
  else
    divergence_index_only_unexpected+=("$item")
  fi
done

# --- Hard-failure gate: any unexpected divergence (in any of the three buckets), or the
# check being skipped entirely (tools unavailable -- cleanliness cannot be confirmed,
# which is not the same as clean), fails Validate mode. See Step 4 for how this combines
# with the other failure classes (schema-shape defects, etc.) into the final report verdict.
divergence_check_failed="no"
if [ "$divergence_check_skipped" = "yes" ] \
   || [ "${#divergence_fts_only[@]}" -gt 0 ] \
   || [ "${#divergence_id_inconsistent[@]}" -gt 0 ] \
   || [ "${#divergence_index_only_unexpected[@]}" -gt 0 ]; then
  divergence_check_failed="yes"
fi
```

### Validate Step 3: Find Unindexed Markdown Files

```bash
unindexed=()
while IFS= read -r md_file; do
  # Get path relative to lit_dir
  rel_path="${md_file#$lit_dir/}"
  if ! jq -e --arg p "$rel_path" '.entries[] | select(.path == $p)' "$index_file" >/dev/null 2>&1; then
    unindexed+=("$rel_path")
  fi
done < <(find "$lit_dir" -maxdepth 1 -name "*.md" 2>/dev/null | sort)
```

### Validate Step 4: Display Report

```
## Literature Validation Report

**Index**: specs/literature/index.json
**Total Entries**: {N}

### Schema-Shape Defects ({count}) — malformed entries (missing .id/.doc_id, missing .path, or
### .path not sources/-prefixed) — reported separately from missing FILES below
{for each schema_shape_defect entry:}
- {label} ({defects})
  These entries are malformed records, not files that vanished; the fix is to repair or remove
  the entry, not to search the filesystem for a target.

### Stale Entries ({count}) — path in index but file missing
{for each stale entry:}
- {entry_path}

### Token Count Drift ({count}) — more than 20% change from stored count
{for each drift entry:}
- {entry_path}: stored {N}, actual {M} ({pct}% drift)

### Schema Warnings ({count}) — top-level document entries missing required v2 fields
{for each schema_warning entry:}
- {entry_path}: {missing_fields}
  Run: /literature --index {file_path} to update entry with missing fields

### Authors Shape Warnings ({count}) — non-array or comma-joined authors
{for each authors_shape_warning entry:}
- {entry_path}: {authors_shape}
  Run: bash .claude/scripts/literature-normalize-authors.sh {index_file} --apply to normalize,
  or run with no flag (dry-run is the default) first to preview the change.

### Namespace Divergence (hard failure — index.json vs. .literature.db chunks_data.doc_id)
{DIVERGENCE_KNOWN_EXCEPTIONS_NOTE}

#### FTS-only doc_ids with no index coverage ({count}) — always unexpected, always fails
{for each divergence_fts_only entry:}
- {doc_id}

#### Index dir keys with no FTS chunks — recorded known exceptions ({count}, does not fail)
{for each divergence_index_only_known entry:}
- {id} (dir key: {dir_key})

#### Index dir keys with no FTS chunks — unexpected ({count}, fails)
{for each divergence_index_only_unexpected entry:}
- {id} (dir key: {dir_key})

#### Parent entries whose .id is neither its own path-derived key nor present in FTS ({count}) — always unexpected, always fails
{for each divergence_id_inconsistent entry:}
- {id} (path-derived key: {dir_key})

{if divergence_check_skipped == "yes":}
**Namespace divergence check SKIPPED** (literature-doc-key.sh, .literature.db, or sqlite3
unavailable) — cleanliness cannot be confirmed. A skipped check counts as a failure below; it is
not treated as passing.

This section fails the command on any entry outside the recorded known-exceptions list above
(divergence_check_failed). The bridge (path-derived key resolution) already covers most
divergence at read time; a bucket entry that survives the bridge and is not a recorded exception
is exactly the residue this check exists to catch — it is not informational.

### Unindexed Files ({count}) — markdown files not in index.json
{for each unindexed file:}
- {file_path}
  Run: /literature --index {file_path}

{if all clean (zero schema-shape defects AND divergence_check_failed == "no" AND zero stale
entries AND zero unindexed files):}
### Validation Passed

All {N} index entries are valid. No schema-shape defects, no stale paths, no drift, no schema
warnings, no authors-shape warnings, no namespace divergence beyond the recorded known
exceptions, no unindexed files.

{else:}
### Validation FAILED

One or more checks above did not pass — see the sections with a non-zero unexpected count.
Namespace divergence beyond the recorded known exceptions is the specific defect class this
task exists to end; do not add an entry to the known-exceptions list to silence a new failure
without the same adjudication rigor the original corpus reconciliation used (provenance-based,
byte-identical-content verification, not a guess). Fix the underlying entry (add a missing
parent entry, quarantine a duplicate, or repair a schema-shape defect) and re-run.
```

---

## Mode: Convert

Convert unprocessed PDF/DJVU files to markdown with interactive confirmation.

### Convert Step 1: Determine Target Files

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

### Convert Step 2: Check Tool Availability

Conversion engine-tier availability (pymupdf4llm, marker, `pdftotext`, `djvutxt`) is
`literature-convert.sh`'s concern, not Mode: Convert's — since Step 3b now delegates extraction
to it, a machine with a working PyMuPDF stack but no poppler-utils installed is still fully
capable of converting, so there is no longer a hard `pdftotext`-only gate here. An
all-engine-tiers-failed condition is still loud: it surfaces as `literature-convert.sh`'s own
exit 2 in Step 3b, which is skipped and reported per-file rather than aborting the whole run.
`has_pdftotext` itself is still computed above and remains in the status/scan report lines — only
this hard gate is removed.

### Convert Step 3: Process Each File

```bash
# Accumulate across all target files (not reset per-file) so Step 4's summary can report every
# gate rejection and hard conversion failure from this invocation.
gate_failed_entries=()
convert_failed_entries=()
```

For each target file:

#### 3a: Get Page Count

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

#### 3b: Extract Full Text and Determine Chunking

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

#### 3c: Confirm Chunk Boundaries with User

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

#### 3d: Write Chunk Files

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

#### 3e: Compute Token Count and Auto-Generate Metadata

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

#### 3f: Confirm Metadata with User

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

#### 3g: Update index.json

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

#### 3h: Chunk and Index

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

### Convert Step 4: Display Summary

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

---

## Mode: Index

Add or update an index.json entry for an existing markdown file.

### Index Step 1: Validate File Exists

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

### Index Step 2: Compute Token Count

```bash
char_count=$(wc -c < "$file" 2>/dev/null || echo 0)
token_count=$(( char_count / 4 + 20 ))
```

### Index Step 3: Auto-Generate Metadata

Same word-frequency keyword extraction and summary extraction as Convert Step 3e.

### Index Step 4: Prompt User for Bibliographic Metadata

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

### Index Step 5: Write to index.json

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

### Index Step 6: Display Result

```
## Index Entry Added

**File**: {rel_path}
**Entry ID**: {entry_id}
**Token Count**: {token_count}
**Keywords**: {keywords}
**Summary**: {summary}

**Index**: specs/literature/index.json ({N} entries total)
```

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
**Job 1 (`rebuild_job1_dangling_ref_lint`)** under "Mode: Rebuild" above, invoked via
`/literature --rebuild`. It previously referenced a `--subindex` flag that was never parsed
anywhere in `literature.md` (dead documentation). This section is kept only as a pointer so the
Sub-Index Management catalogue stays complete; do not add a second, divergent implementation
here — edit `rebuild_job1_dangling_ref_lint` under "Mode: Rebuild" instead.

---

## Error Handling

See `rules/error-handling.md` for general patterns. Skill-specific behaviors:

- **specs/literature/ missing**: Not an error for status/scan — report and suggest next steps
- **index.json missing**: Initialize with empty structure for convert/index modes; warn for validate
- **Conversion engine-tier availability**: No longer a Mode: Convert concern — Convert Step 3b
  delegates extraction to `literature-convert.sh`, which owns the engine-tier ladder
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
  never chunked — Mode: Convert only reports it in the Skipped Files summary, it never appears as
  a partial or silent success.
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
- Import pipeline: symlink PDF to `$LITERATURE_DIR/pdfs/{citation_key}.pdf`, convert via handle_convert() with PREFILL_* env vars, patch index with Zotero fields, git commit (non-blocking)
