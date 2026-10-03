# Mode: Validate

This file is the COMPLETE and ONLY specification for skill-literature's `Mode: Validate` (`mode=validate`) execution. It MUST be followed exactly -- there is no fuller version of this content anywhere else. The `Mode: Validate` section of `skill-literature/SKILL.md` was extracted here per `context/patterns/mode-gated-section-loading.md`; the pointer at that section's former location in `SKILL.md` sends an agent here whenever `mode=validate` is dispatched.

Check index.json against the filesystem for stale entries, missing files, and token count drift.

## Validate Step 1: Load Index

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

## Validate Step 2: Check Each Entry

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

## Validate Step 2b: Namespace Divergence Check (hard failure, with recorded exceptions)

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

## Validate Step 3: Find Unindexed Markdown Files

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

## Validate Step 4: Display Report

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
