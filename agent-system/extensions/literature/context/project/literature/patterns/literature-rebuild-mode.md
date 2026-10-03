# Mode: Rebuild

This file is the COMPLETE and ONLY specification for skill-literature's `Mode: Rebuild` (`mode=rebuild`) execution. It MUST be followed exactly -- there is no fuller version of this content anywhere else. The `Mode: Rebuild` section of `skill-literature/SKILL.md` was extracted here per `context/patterns/mode-gated-section-loading.md`; the pointer at that section's former location in `SKILL.md` sends an agent here whenever `mode=rebuild` is dispatched.

`handle_rebuild()` brings the per-repo sub-index (`specs/literature-index.json`) into
conformance with the global Literature corpus (`$LITERATURE_DIR/index.json` +
`$LITERATURE_DIR/.literature.db`). It offers four selectable jobs — Jobs 1, 2, and 4 are
**read-only and idempotent**; Job 3 is the **only writer**, and only after an explicit
confirm-after-diff `AskUserQuestion`. `--dry-run` is accepted uniformly but only meaningfully
changes Job 3's behavior (Jobs 1/2/4 never write regardless of `--dry-run`).

## Rebuild Step 1: Parse Args and Resolve Paths

```bash
function handle_rebuild() {
  # $mode is already "rebuild" (see Step 4 dispatch); dry_run comes from the skill args
  # ("mode=rebuild dry_run={true|false}"), parsed the same way as $mode/$file in Step 1.
  dry_run=$(echo "$ARGUMENTS" | grep -oP 'dry_run=\K\S+' | head -1)
  dry_run="${dry_run:-false}"

  sub_index="specs/literature-index.json"
  global_index="${LITERATURE_DIR:-$HOME/Projects/Literature}/index.json"
  literature_db="${LITERATURE_DIR:-$HOME/Projects/Literature}/.literature.db"
```

## Rebuild Step 2: Absent-Sub-Index Deferral (checked FIRST, before any job picker)

Mirrors the `--lit` flow's `PROMPT_NEEDED`/`AUTONOMOUS_GLOBAL` precedent
(`literature-lit-flag-resolve.sh`, CLAUDE.md "Interactive Sub-Index Setup Detection") rather than
duplicating `literature-create-setup-task.sh`'s state.json-mutation logic inline.

```bash
  if [ ! -f "$sub_index" ]; then
    echo "## Rebuild: Sub-Index Absent"
    echo ""
    echo "No sub-index found at $sub_index — there is nothing to rebuild yet."
    echo ""
    setup_script=".claude/extensions/literature/scripts/literature-create-setup-task.sh"
    if [ -x "$setup_script" ] || [ -f "$setup_script" ]; then
      new_task=$("$setup_script" 2>/tmp/rebuild-setup-task-rationale.txt)
      setup_exit=$?
      if [ "$setup_exit" -eq 0 ] && [ -n "$new_task" ]; then
        echo "Created task #$new_task to populate $sub_index (see literature-create-setup-task.sh)."
        echo "Run /implement $new_task once ready, then re-run /literature --rebuild."
      else
        echo "Could not auto-create a setup task: $(cat /tmp/rebuild-setup-task-rationale.txt)"
        echo "Run .claude/extensions/literature/scripts/literature-create-setup-task.sh manually,"
        echo "or use /literature --lit on any command to trigger the same interactive setup flow."
      fi
    else
      echo "literature-create-setup-task.sh not found — use /literature --lit on any command"
      echo "to trigger the same interactive sub-index setup flow."
    fi
    return 0   # never error, never present the job picker with nothing to check
  fi
```

## Rebuild Step 3: Job Picker (AskUserQuestion, multiSelect)

Only reached when the sub-index exists. Jobs 1 & 2 are mechanical/read-only and pre-checked by
default; Jobs 3 (the only writer) & 4 (broader, corpus-wide scope) are left unchecked by default.

```json
{
  "question": "Which sub-index rebuild checks should run?",
  "header": "Sub-Index Rebuild Jobs",
  "multiSelect": true,
  "options": [
    {
      "label": "Dangling-ref lint (default on)",
      "description": "Mechanical, read-only. Flags doc_ids that no longer resolve in the global index."
    },
    {
      "label": "Schema conformance check (default on)",
      "description": "Mechanical, read-only. Checks structural minimums only (doc_id + relevance/reason present) — never flags or strips extra curation fields like hazard/citation_rule/known_corrections/audits."
    },
    {
      "label": "Coverage refresh",
      "description": "Requires judgment. Proposes newly-relevant docs from the global corpus; nothing is written without a follow-up confirm-after-diff. The only job that can write."
    },
    {
      "label": "Chunk/search-index coverage audit",
      "description": "Mechanical, read-only. Reports which sources/<dir>/ directories (and legacy chunks_dir entries) have zero FTS5 search coverage in chunks_data."
    }
  ]
}
```

Selections determine which of `run_job1`, `run_job2`, `run_job3`, `run_job4` are `true` for the
rest of `handle_rebuild()`.

## Rebuild Step 4: Report-Aggregation Shell

Each selected job appends its findings into a single multi-job report; nothing is printed
standalone. Jobs 1/2/4 bodies live in the "Job 1", "Job 2", "Job 4" subsections below (added in
later phases); Job 3 lives in its own "Job 3" subsection (also added in a later phase). This
shell is the only place that prints the report header/footer and the `dry_run` note.

```bash
  echo "## Sub-Index Rebuild Report — $(basename "$(pwd)")"
  echo ""
  if [ "$dry_run" = "true" ]; then
    echo "_dry-run active: Job 3 (coverage refresh), if selected, will print a proposed diff and write nothing. Jobs 1/2/4 never write regardless of --dry-run._"
    echo ""
  fi

  [ "$run_job1" = "true" ] && rebuild_job1_dangling_ref_lint
  [ "$run_job2" = "true" ] && rebuild_job2_schema_conformance
  [ "$run_job4" = "true" ] && rebuild_job4_coverage_audit
  # Job 3 always last: it is the only writer and its confirm-after-diff step should reflect the
  # read-only jobs' findings printed above it.
  [ "$run_job3" = "true" ] && rebuild_job3_coverage_refresh

}  # end handle_rebuild()
```

## Job 1: Dangling-Ref Lint (read-only, idempotent)

Reuses the "Sub-Index Management > Validate" block in `skill-literature/SKILL.md` almost
verbatim (see that section's note — this is the wiring that makes it reachable for the first
time), shaped for the
multi-job report instead of a standalone command.

```bash
function rebuild_job1_dangling_ref_lint() {
  orphans=()
  valid=()

  while IFS= read -r doc_id; do
    [ -z "$doc_id" ] && continue
    if jq -e --arg id "$doc_id" '.entries[] | select(.id == $id)' "$global_index" >/dev/null 2>&1; then
      valid+=("$doc_id")
    else
      orphans+=("$doc_id")
    fi
  done < <(jq -r '.entries[].doc_id' "$sub_index" 2>/dev/null)

  echo "### Job 1: Dangling-Ref Lint"
  echo ""
  echo "Valid entries: ${#valid[@]}"
  echo "Dangling (orphaned) entries: ${#orphans[@]}"
  echo ""
  if [ "${#orphans[@]}" -gt 0 ]; then
    echo "Orphaned doc_ids (not found in $global_index):"
    for id in "${orphans[@]}"; do
      echo "  - $id"
    done
    echo ""
    echo "Removal is NOT automatic — dangling refs are reported only. To remove one, run the"
    echo "Sub-Index Management > Remove operation explicitly after review."
  else
    echo "All entries resolve in the global index."
  fi
  echo ""
}
```

## Job 2: Schema Conformance — Structural Minimum Only (read-only, idempotent)

**Critical**: this job does NOT enforce the nominal `{doc_id, relevance, source}` shape. Live
sub-indexes diverge from it in load-bearing ways — cslib omits `source` entirely; BimodalLogic
uses `reason` instead of `relevance` plus `hazard`/`citation_rule`/`known_corrections`/`audits`
fields documenting a real citation-fidelity issue on `rabinovich_2014`. Flagging or stripping
those fields would destroy human curation data. The check is a structural minimum only: every
entry must have a non-empty `doc_id` AND at least one of `relevance`/`reason` present. Extra
fields of any kind are never flagged, never stripped, never rewritten.

```bash
function rebuild_job2_schema_conformance() {
  violations=()
  chunk_id_violations=()

  while IFS=$'\t' read -r doc_id has_relevance_or_reason; do
    [ -z "$doc_id" ] && continue
    if [ -z "$doc_id" ] || [ "$has_relevance_or_reason" != "true" ]; then
      violations+=("$doc_id")
    fi
    # chunk-file-conventions.md: chunk_*.md files are index-only re-splits, never an
    # independently referenceable sub-index doc_id.
    if [[ "$doc_id" =~ ^chunk_[0-9]+$ ]]; then
      chunk_id_violations+=("$doc_id")
    fi
  done < <(jq -r '.entries[] | [
      (.doc_id // ""),
      ((((.relevance // "") | length) > 0) or (((.reason // "") | length) > 0) | tostring)
    ] | @tsv' "$sub_index" 2>/dev/null)

  echo "### Job 2: Schema Conformance (structural minimum only)"
  echo ""
  echo "Checked: doc_id non-empty AND (relevance OR reason) present. Extra fields (hazard,"
  echo "citation_rule, known_corrections, audits, source, added, ...) are never flagged or"
  echo "stripped — they are legitimate human curation data."
  echo ""
  if [ "${#violations[@]}" -gt 0 ]; then
    echo "Entries missing the structural minimum (${#violations[@]}):"
    for id in "${violations[@]}"; do
      echo "  - ${id:-<empty doc_id>}"
    done
  else
    echo "All entries meet the structural minimum."
  fi
  echo ""
  if [ "${#chunk_id_violations[@]}" -gt 0 ]; then
    echo "chunk_NNNN doc_ids referenced directly (${#chunk_id_violations[@]} — chunk files are"
    echo "index-only re-splits, never independently referenceable; see"
    echo ".claude/context/project/literature/patterns/chunk-file-conventions.md):"
    for id in "${chunk_id_violations[@]}"; do
      echo "  - $id"
    done
  else
    echo "No sub-index doc_id references a chunk_NNNN id directly."
  fi
  echo ""
}
```

## Job 4: Chunk/Search-Index Coverage Audit (read-only, idempotent)

Reports, per `sources/<dir>/` directory (plus every legacy top-level `chunks_dir`-schema
entry), whether the corpus's FTS5 search index (`chunks_data`) has any coverage at all. Queries
`chunks_data` exclusively — **never** `document_metadata`, which is currently empty (0 rows) in
this corpus and is not relied upon here (orphaned table, explicit non-goal).

**Expected-empty vs unexpected-empty**: `/literature --convert`
chunks and indexes every `.md` it writes (Convert Step 3h/Step 4), so a `sources/<dir>/` with a
valid `.md` and zero `chunks_data` rows is no longer explained by the old "`--convert` never
chunks" root cause — it now signals either a **regression** in the Step 3h/Step 4 wiring or a
**new, un-wired path** that writes `.md` files without going through `handle_convert()` or
`handle_ingest()`. Job 4 therefore cross-checks each `missing_dirs` entry against the filesystem
and buckets it as:
- **UNEXPECTED** — a valid `.md` exists (`find "$dirpath" -maxdepth 1 -name '*.md' -not -name
  'chunk_*.md'`, excluding `.md.bak-*` / `.md.rejected` by construction) but `chunks_data` has
  zero rows for it. A non-empty UNEXPECTED bucket is a regression signal worth investigating.
- **expected-empty (quarantined)** — no valid `.md` exists (only a `.pdf`/`.djvu` awaiting
  conversion, or only quarantine artifacts like `.md.bak-*` / `.md.rejected`, e.g.
  `gabbay_2000`, `negri_von_plato_2001`, `troelstra_schwichtenberg_2000`). This is the expected,
  correctly-excluded state — not a failure.

**Directory→doc_id resolution note**: unlike `literature-fidelity-audit.sh`'s "Target entry
resolution" (which stamps `provenance_fidelity` onto individual `index.json` chapter/section
entries via `parent_doc` fan-out), `chunks_data.doc_id` is keyed on the **`sources/<dir>/`
directory basename itself** (e.g. `blackburn_2002`, not `blackburn_2002_ch03_sec01-04` or
`blackburn_2002_book`) — confirmed by reading the live corpus. Job 4 therefore checks
`doc_id = <directory basename>` directly; it does not need the root/child fan-out logic that
provenance-stamping requires.

```bash
function rebuild_job4_coverage_audit() {
  echo "### Job 4: Chunk/Search-Index Coverage Audit"
  echo ""

  if [ ! -f "$literature_db" ]; then
    echo "Global literature database not found at $literature_db — cannot audit coverage."
    echo ""
    return 0
  fi

  echo "_Querying chunks_data (canonical FTS5 source). document_metadata is currently empty"
  echo "(0 rows) in this corpus and is intentionally NOT queried by this job._"
  echo ""

  missing_dirs=()
  covered_dirs=0
  quarantine_hits=()

  lit_dir="${LITERATURE_DIR:-$HOME/Projects/Literature}"
  if [ -d "$lit_dir/sources" ]; then
    while IFS= read -r dirpath; do
      dir=$(basename "$dirpath")
      count=$(sqlite3 "$literature_db" "SELECT count(*) FROM chunks_data WHERE doc_id='$dir';" 2>/dev/null || echo 0)
      if [ "${count:-0}" -eq 0 ]; then
        missing_dirs+=("$dir")
      else
        covered_dirs=$((covered_dirs + 1))
      fi
      # Defensive hazard-(b) check: quarantine artifacts must never be chunked. The chunker's
      # callers (literature-ingest.sh, handle_convert() as of #842) glob strictly on `*.md`,
      # which by construction excludes `*.md.bak-<UTC>` and `*.md.rejected` (neither filename
      # ends in exactly ".md"). Verify this holds against the real chunks.json manifest rather
      # than assuming it forever.
      if [ -f "$dirpath/chunks.json" ] && grep -qE '\.md\.(bak-|rejected)' "$dirpath/chunks.json" 2>/dev/null; then
        quarantine_hits+=("$dir")
      fi
    done < <(find "$lit_dir/sources" -mindepth 1 -maxdepth 1 -type d)
  fi

  # Classify each missing_dirs entry: UNEXPECTED (has a valid .md, wiring regressed) vs
  # expected-empty (quarantined: no valid .md, only source PDF/DJVU and/or .md.bak-*/.md.rejected).
  unexpected_dirs=()
  expected_empty_dirs=()
  for d in "${missing_dirs[@]}"; do
    valid_md=$(find "$lit_dir/sources/$d" -maxdepth 1 -name '*.md' -not -name 'chunk_*.md' 2>/dev/null | grep -vE '\.md\.(bak-|rejected)$')
    if [ -n "$valid_md" ]; then
      unexpected_dirs+=("$d")
    else
      expected_empty_dirs+=("$d")
    fi
  done

  # Legacy top-level chunks_dir-schema entries (no `path` field; live outside sources/).
  legacy_missing=()
  legacy_covered=0
  while IFS= read -r legacy_id; do
    [ -z "$legacy_id" ] && continue
    count=$(sqlite3 "$literature_db" "SELECT count(*) FROM chunks_data WHERE doc_id='$legacy_id';" 2>/dev/null || echo 0)
    if [ "${count:-0}" -eq 0 ]; then
      legacy_missing+=("$legacy_id")
    else
      legacy_covered=$((legacy_covered + 1))
    fi
  done < <(jq -r '.entries[] | select(has("chunks_dir")) | .doc_id' "$global_index" 2>/dev/null)

  echo "sources/<dir>/ directories audited: covered=$covered_dirs missing=${#missing_dirs[@]}"
  echo "  of which UNEXPECTED (valid .md, zero chunks_data — possible regression)=${#unexpected_dirs[@]}"
  echo "  of which expected-empty (quarantined, no valid .md)=${#expected_empty_dirs[@]}"
  if [ "${#unexpected_dirs[@]}" -gt 0 ]; then
    echo ""
    echo "UNEXPECTED — valid .md exists but chunks_data has zero rows (investigate: wiring"
    echo "regression in handle_convert()/handle_ingest(), or a new un-wired write path):"
    for d in "${unexpected_dirs[@]}"; do
      echo "  - $d"
    done
  fi
  if [ "${#expected_empty_dirs[@]}" -gt 0 ]; then
    echo ""
    echo "Expected-empty (quarantined — no valid .md; correctly excluded, not a failure):"
    for d in "${expected_empty_dirs[@]}"; do
      echo "  - $d"
    done
  fi
  echo ""
  echo "Legacy chunks_dir-schema entries audited: covered=$legacy_covered missing=${#legacy_missing[@]}"
  if [ "${#legacy_missing[@]}" -gt 0 ]; then
    echo ""
    echo "Legacy entries with zero FTS5 coverage:"
    for d in "${legacy_missing[@]}"; do
      echo "  - $d"
    done
  fi
  echo ""
  if [ "${#quarantine_hits[@]}" -gt 0 ]; then
    echo "WARNING: quarantine artifact (.md.bak-*/.md.rejected) found chunked in: ${quarantine_hits[*]}"
  else
    echo "No quarantine artifacts (.md.bak-*/.md.rejected) found chunked (glob-strictness assumption holds)."
  fi
  echo ""
  echo "/literature --convert chunks and indexes every .md it writes (Convert"
  echo "Step 3h/Step 4), so this job's UNEXPECTED bucket is the regression signal to watch —"
  echo "not a known root cause anymore. document_metadata remains an orphaned, always-empty"
  echo "table (explicit non-goal; not queried here)."
  echo ""
}
```

## Job 3: Coverage Refresh — the ONLY Writer (confirm-after-diff gated)

Proposes newly-relevant global-corpus documents that are absent from this repo's sub-index, and
appends them **only** after an explicit `AskUserQuestion` confirmation of a shown diff.
Additions only — never deletes or rewrites an existing entry (never touches BimodalLogic-style
rich curation fields, never uses the "Remove" block). `--dry-run` skips the confirm+write step
and only prints the proposed diff; Jobs 1/2/4 never write regardless of `--dry-run`.

**Rebuild Job 3 Step A — Candidate generation (LLM-driven matching)**:

This step requires judgment, not pure mechanical bash — no existing script performs this
matching. Determine this repo's domain signals (repo basename via `basename "$(pwd)"`, recent
task titles/descriptions from `specs/state.json` if present, README topic sentences), then scan
`$global_index`'s `entries[]` for candidates whose `project_tags`, `keywords`, or `summary`
plausibly match that domain:

```bash
# Read current sub-index doc_ids to exclude already-present entries
existing_ids=$(jq -r '.entries[].doc_id' "$sub_index" 2>/dev/null)

# Pull a lightweight candidate pool: entries whose project_tags array already names this repo,
# unioned with entries an LLM judges keyword/summary-relevant to the domain signals above.
# project_tags-based candidates are the highest-confidence signal (another repo's --lit or
# discover-mode run already tagged this doc as relevant to THIS project by name).
repo_name=$(basename "$(pwd)")
tag_candidates=$(jq -r --arg repo "$repo_name" \
  '.entries[] | select(.project_tags? and (.project_tags | index($repo))) | .id' \
  "$global_index" 2>/dev/null)
```

The agent then reviews `tag_candidates` (and any keyword/summary-matched candidates it
identifies by reading entry `keywords`/`summary`/`title` fields against the domain signals),
excludes anything already in `$existing_ids`, and drafts a `relevance` annotation per candidate
explaining why it belongs in this repo's sub-index.

**Rebuild Job 3 Step B — Validate candidates** (reuses the "Add" block's validation half only):

```bash
# For each candidate doc_id, confirm it still resolves in the global index before proposing it
# (mirrors the existing Sub-Index Management > Add block's validation, never its write).
for doc_id in $candidate_doc_ids; do
  if ! jq -e --arg id "$doc_id" '.entries[] | select(.id == $id)' "$global_index" >/dev/null 2>&1; then
    echo "Warning: candidate '$doc_id' no longer resolves in global index — dropping" >&2
    continue
  fi
done
```

**Rebuild Job 3 Step C — Confirm-after-diff gate** (always shown, even under `--dry-run`):

```json
{
  "question": "Add these documents to specs/literature-index.json?",
  "header": "Coverage Refresh — Proposed Additions",
  "multiSelect": true,
  "options": [
    {
      "label": "{doc_id} — {title}",
      "description": "Proposed relevance: {relevance}. Currently absent from your sub-index."
    }
  ]
}
```

If there are zero candidates, print `"No new coverage-refresh candidates found."` and skip the
gate entirely (nothing to confirm).

**Rebuild Job 3 Step D — Append-only write (skipped entirely under `--dry-run`)**:

```bash
function rebuild_job3_coverage_refresh() {
  echo "### Job 3: Coverage Refresh"
  echo ""

  # ... Steps A-C above produce $confirmed_doc_ids (only entries the user checked) ...

  if [ "$dry_run" = "true" ]; then
    echo "_dry-run: no write performed. Proposed additions were shown above for review only._"
    echo ""
    return 0
  fi

  if [ -z "${confirmed_doc_ids:-}" ]; then
    echo "No additions confirmed — sub-index unchanged."
    echo ""
    return 0
  fi

  today=$(date +%Y-%m-%d)
  for doc_id in $confirmed_doc_ids; do
    relevance="${candidate_relevance[$doc_id]:-}"
    tmp=$(mktemp)
    jq --arg id "$doc_id" \
       --arg rel "$relevance" \
       --arg today "$today" \
       '.entries += [{
         "doc_id": $id,
         "relevance": (if $rel == "" then null else $rel end),
         "added": $today,
         "source": "rebuild"
       }]' "$sub_index" > "$tmp" && mv "$tmp" "$sub_index"
    echo "Added '$doc_id' to $sub_index"
  done
  echo ""
  echo "Existing entries (including any BimodalLogic-style rich curation fields) were not"
  echo "touched — this job only ever appends new entries."
  echo ""
}
```

Dangling-ref removals are never performed by any rebuild job — a dangling ref found by Job 1
requires its own separate, explicitly confirmed removal action (Sub-Index Management > Remove),
never automatic cleanup.
