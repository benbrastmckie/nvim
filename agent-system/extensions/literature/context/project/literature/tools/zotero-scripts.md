# Zotero Script Inventory

The scripts below ship with the literature extension under `scripts/`. Deployment to
`.claude/scripts/` follows from the extension being registered active in
`.claude-extensions.json`; see the README's "Deployment Status" section for the current,
per-script live/inactive record — this inventory is not itself a deployment claim.

| Script | Purpose |
|--------|---------|
| `zotero-search.sh` | Search the CSL-JSON export by keyword (used by `/literature` Mode A) |
| `zotero-read.sh` | Read item metadata and PDFs via the `zot` CLI |
| `zotero-write.sh` | Write/attach files to Zotero items; create new items with a PDF attachment (`item-add`, wrapping `zot add --pdf`), create a new item from a fully-formed JSON body (`item-add-json`, the one operation that POSTs the Web API directly instead of wrapping `zot`), and clean dead orphaned attachment records (`orphan-clean`, wrapping `zot orphans clean --yes`) |
| `zotero-setup.sh` | Setup wizard: detect the data dir, validate, configure |
| `zotero-chunk.sh` | Extract PDF text and chunk it into sections |
| `zotero-attach-chunks.sh` | Upload chunks as Zotero child attachments |
| `cite-extract.sh` | Extract citation patterns from markdown artifacts |
| `literature-ingest-online.sh` | Online-discovery -> Zotero+PDF -> ingest bridge: classifies a discovery record, downloads and magic-byte-verifies the PDF, creates/attaches the Zotero item, delegates to `literature-ingest.sh`, and patches index/sub-index metadata |

## Argument Gotcha

`zotero-search.sh` scores query terms independently and OR-combines them, so each search word
must be passed as a SEPARATE argument. A single quoted multi-word phrase is treated as one term
and matches nothing. See `patterns/agent-exploration.md` ("Two Search Tools") for the full
comparison against `literature-search.sh`.

## Duplicate-Title Dedup Check

`literature-ingest-online.sh`'s `check_duplicate_title()` is a recommendation-only,
non-blocking guard that runs before either Zotero-write path (create-item or
attach-to-existing). It scores the incoming title against every title in the global
`index.json` and, on a match at or above the 0.85 similarity threshold, logs a `WARNING:
possible duplicate --` line to stderr — it never gates or delays ingestion, and always returns
success.

The check is a single bounded invocation, not a per-title loop: `check_duplicate_title()` pipes
every `index.json` title through one `python3 .zotero-title-sim.py --batch <title>` call under
a `timeout 10`, rather than spawning a subprocess per candidate. `.zotero-title-sim.py --batch`
reads existing titles on stdin, short-circuits to score `1.0` on the first normalized-equality
match (skipping `SequenceMatcher` scoring entirely for that title), and otherwise keeps the
first strict-maximum `SequenceMatcher` ratio (ties broken by index order, matching the original
per-title loop). `.zotero-title-sim.py`'s original 2-argv CLI form
(`sim.py TITLE_A TITLE_B` -> a single float) is unchanged and still backs
`zotero-resolve-pdf.sh`'s `title_similarity()`.

Fail-open semantics: a timeout, non-zero exit, empty output, or an output line that does not
parse as `<score><TAB><title>` is treated as "no duplicate found" — the function always returns
0. This bounds the check's cost to the 10s timeout in the worst case (measured at roughly 1s
against an 11,793-entry index in practice), instead of the multi-minute, unbounded stall of the
former one-`python3`-process-per-title loop.

See `agent-system/extensions/literature/scripts/tests/test-title-sim-dedup.sh` for the
regression suite locking in the threshold, the WARNING text, the tie-break order, the
2-argv/batch contracts, and the fail-open paths.

## The `zot` CLI's `delete`/`orphans`/`trash` family

`zot` ships a wider library-maintenance surface than this extension's own context files
previously documented: `delete`, `orphans clean`/`orphans list`, `trash list`/`trash restore`,
and `duplicates --by doi|title|both`. `zotero-write.sh orphan-clean` wraps `orphans clean` (see
above); the rest are operator-run via `zot` directly, not through this choke-point. In
particular, `zot duplicates --by doi|title|both` is a whole-library, operator-facing dedup sweep
— explicitly distinct from this bridge's own pre-write `check_duplicate_title()` /
`check_live_doi_duplicate()` checks, and subject to the same local-SQLite sync-lag caveat as
`orphans list/clean` (see `patterns/zotero-item-creation.md` Section 2).

## Related

- `domain/zotero-integration.md` — export setup and the `zot` CLI
- `patterns/zotero-item-creation.md` — how `literature-ingest-online.sh` creates items
- `patterns/zotero-pdf-resolution.md` — resolving a `doc_id` to its Zotero PDF
- `patterns/cite-workflow.md` — where `cite-extract.sh` is used
