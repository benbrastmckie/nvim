# Literature Index Schema

## Overview

The literature system uses a two-level index architecture:

1. **Global index** (`$LITERATURE_DIR/index.json`) — The single source of truth for all documents in the centralized Literature/ repository. Contains full metadata for every document and chunk.

2. **Per-repo sub-index** (`specs/literature-index.json`) — A lightweight reference index for each project. Contains only `doc_id` references pointing to entries in the global index. No cached metadata — all metadata is resolved at runtime from the global index. This index is read by `literature-briefing.sh` at skill preflight time.

## Global Repository Contents

The global Literature/ repo (`$LITERATURE_DIR`, default `~/Projects/Literature/`) is the single
source of truth for all converted literature:

| Path | Contents |
|------|----------|
| `$LITERATURE_DIR/index.json` | Enriched v2 metadata (222+ entries) |
| `$LITERATURE_DIR/sources/` | Converted markdown organized by document |
| `$LITERATURE_DIR/.literature.db` | SQLite FTS5 full-text search database |
| `$LITERATURE_DIR/zotero-library.json` | Better BibTeX CSL-JSON auto-export |

See `tools/literature-dir-config.md` for how `$LITERATURE_DIR` is resolved and overridden.

## Global Index Schema (v2)

Location: `$LITERATURE_DIR/index.json` (default: `/home/benjamin/Projects/Literature/index.json`)

Each entry includes:

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique doc_id (e.g., `blackburn_2002`) |
| `path` | string | Relative path from `$LITERATURE_DIR/` |
| `token_count` | integer | Estimated token count |
| `keywords` | string[] | Search keywords |
| `summary` | string | One-sentence description |
| `authors` | string[] | Author list |
| `title` | string | Full document title |
| `year` | integer\|null | Publication year |
| `doc_type` | string | `paper`, `book`, `chapter`, or `section` |
| `source_format` | string | `pdf`, `djvu`, or `manual` |
| `parent_doc` | string\|null | Parent doc_id for chunks |
| `page_range` | string\|null | Page range in source document |
| `bib_key` | string\|null | Better BibTeX citation key |
| `zotero_key` | string\|null | Zotero internal item key |
| `zotero_path` | string\|null | Absolute path to PDF in Zotero storage |
| `project_tags` | string[]\|null | Zotero collection names as project tags |

## Per-Repo Sub-Index Schema

Location: `specs/literature-index.json` (per-project)

```json
{
  "project": "project_slug",
  "literature_dir": null,
  "entries": [
    {
      "doc_id": "blackburn_2002",
      "relevance": "Core modal logic reference",
      "added": "2026-06-01",
      "source": "manual"
    }
  ]
}
```

### Entry Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `doc_id` | string | Yes | Must match an `id` in the global index |
| `relevance` | string | No | Why this document matters for this project |
| `added` | string | No | ISO date when added to sub-index |
| `source` | string | No | How entry was added: `discover`, `manual`, or `import` |

### Design Principles

- **Reference-only**: Sub-index contains no cached metadata. All fields (title, authors, year, paths) are resolved at runtime from the global index.
- **Orphan detection**: If a `doc_id` is not found in the global index, the entry is reported as an orphan (warning logged, no crash).
- **Override support**: Optional `literature_dir` field overrides `$LITERATURE_DIR` for this project.

### Ids Are Matched Whole; Hazards Attach to Ids

A corpus id is an opaque key, matched **whole**. It is never matched, abbreviated, or grouped by
its author-year stem. Two ids that share a stem may be entirely different documents, with
different source files, different `provenance_fidelity`, and different hazards.

A `hazard` field therefore attaches to **the id it is written on**, never to the author-year the id
happens to start with. Carrying a hazard across a stem match transfers a warning to a document it
was never about — and, worse, can make a verified document look provisional (or a provisional one
look verified) to a reader who matched on the stem.

**Worked example.** Both of these are real, distinct entries in one repository sub-index:

| id | document | path under `sources/` | fidelity |
|----|----------|------------------------|----------|
| `thomas_1997` | Ehrenfeucht-Fraïssé Games, the Composition Method, and the Monadic Theory of Ordinal Words | `thomas_1997/Thomas_1997_EF_Games_Composition_Monadic.md` | `no_source_pdf` — provisional, hazard-carrying |
| `thomas_1997_languages_automata` | Languages, Automata, and Logic (handbook chapter) | `thomas_1997_languages/Thomas_1997_Languages_Automata_Logic.md` | `verified_conversion` — source PDF present |

Same author, same year, separate directories, opposite fidelity verdicts. The `no_source_pdf`
hazard belongs to the first and must not be read onto the second; the second's
`verified_conversion` stamp must not be read onto the first.

**Practical rules.**

- When two ids share a stem, say so in *both* entries: each entry's `hazard` or `reason` names its
  own file and states explicitly that the hazard does not attach to the sibling id.
- Write a `hazard` so it is unambiguous read **in isolation** — a reader may meet it without the
  sibling entry beside it. Open with the file the hazard is about, not with the verdict.
- When citing, quote the full id. "Thomas 1997" is not a citation in a corpus that holds two of
  them.

## Directory Structure

```
$LITERATURE_DIR/                    # Global Literature/ repository
├── index.json                     # Global index (v2 schema)
├── .literature.db                 # SQLite FTS5 database (full-text search)
├── sources/                       # All document directories
│   ├── blackburn_2002/
│   │   ├── Blackburn_2002_Modal_Logic.md
│   │   ├── section01_intro.md
│   │   └── section02_syntax.md
│   └── venema_2001/
│       └── Venema_2001_Survey.md
└── zotero-library.json            # Zotero Better BibTeX CSL-JSON export (optional)
```

## Search Interface

Use `literature-search.sh` to search the global corpus via FTS5:

```bash
bash .claude/scripts/literature-search.sh "modal logic semantics"
bash .claude/scripts/literature-search.sh "modal logic" --limit 5
bash .claude/scripts/literature-search.sh "modal logic" --doc_id blackburn_2002
bash .claude/scripts/literature-search.sh blackburn_2002 --by-doc
```

Returns JSON array of matching chunks with `doc_id`, `section_path`, `score`, and `snippet` fields.

## FTS Namespace and the Never-Rename Invariant

The corpus has **two independent id namespaces** that can drift apart, and a third field that
bridges them:

- **`index.json`'s curated `.id`** — human-facing, e.g. `blackburn_2002_book`. Free to be a
  long, descriptive, hand-curated name.
- **`.literature.db`'s `chunks_data.doc_id`** — machine-authoritative, fixed at chunk time by
  `literature-chunk.sh`, e.g. `blackburn_2002` (the bare `sources/<dir>/` directory name).
- **The bridge**: an index entry's `.path`, when `sources/`-prefixed, has the FTS `doc_id` as its
  directory-name component. `sources/blackburn_2002/chunk_0001.md` bridges to FTS doc_id
  `blackburn_2002` regardless of what that entry's own `.id` says. `literature-doc-key.sh` is the
  single sourced anchor for this derivation (a sourceable function plus a `--list-keys` CLI mode
  for non-bash consumers); any reader that must address FTS derives its key this way, falling
  back to `.id` only when `.path` is absent or not `sources/`-prefixed.

**Never rename a live FTS id.** Renaming a curated `.id` to match its FTS `doc_id` (or vice
versa) is the specific operation known to break `literature-search.sh --toc`: `--toc` addresses
FTS directly by `doc_id`, so an id that no longer matches any `chunks_data` row returns `[]`
where it used to return real chunks. This was discovered by hand (via corpus history) and by
execution — reading the code did not reveal it. The fix is never to rename; it is to derive the
FTS key from `.path` via the bridge above, leaving both id spaces untouched. A curated `.id` that
differs from its document's FTS `doc_id` is a **supported configuration**, not a defect, as long
as `.path` bridges it.

**`sources/` placement and fidelity-audit targeting.** `literature-fidelity-audit.sh` targets
`sources/<dir>/` exclusively; an entry outside `sources/` is never matched or stamped with
`provenance_fidelity`. `literature-ingest.sh` places every new document under
`$LITERATURE_DIR/sources/<id>/` for exactly this reason — it is what makes a freshly ingested
document eligible for fidelity stamping (and hence default-ranked search) with zero further code
change, on top of keeping it inside the path-derived bridge's coverage. See
`context/project/literature/patterns/provenance-fidelity.md` for the full `provenance_fidelity`
enum, its detector signals, and the fail-open invariant both retrieval consumers depend on.

**1:1 chunk-granularity rule for script-written entries.** A script-written parent entry
(`literature-ingest.sh`'s Step 4) carries `parent_doc: null` and `chunk_count` equal to the
number of `chunks.json` rows; it writes exactly one child entry per chunk
(`parent_doc: "<id>"`), so the briefing's reported chunk count and `--toc`'s chunk count agree by
construction. The parent's own `token_count` is written as `0`, not the document total, when
children exist — `literature-briefing.sh`'s per-repo chunk-count branch sums the children's
`token_count` and separately adds the parent's, so a non-zero document-total value there would
double-count (this was discovered by execution and matches the same convention already used by
the two hand-added parent entries for `baier_katoen_2008`/`vardi_wolper_1986`). Coarser,
human-curated part-level granularity remains legitimate for hand-curated legacy entries; it is
not what a script produces unattended going forward.

### Reader Survey

Every script in the extension that keys on `.id`/`.doc_id`/`chunks_data.doc_id`, surveyed:

| Script | Keys on | Verdict |
|---|---|---|
| `literature-ingest.sh` (Step 4 writer) | writes canonical `.id == .doc_id == chunks_data.doc_id` parent + 1:1 children | **Fixed.** Was writing a stub entry neither `literature-briefing.sh` nor the curated schema recognized. |
| `literature-briefing.sh` (3 lookup sites + metadata extraction) | `(.id // .doc_id) == $id` | **Fixed.** Was `.id`-only; now tolerates a stub-shaped `.doc_id`-only entry, defense-in-depth behind the writer fix. |
| `literature-search.sh` (`get_project_doc_ids` → project-filtered search) | union of path-derived key and `.id` | **Fixed.** Was building its allow-list from `.id` alone while filtering `chunks_data.doc_id`, silently excluding every document whose curated `.id` differs from its FTS `doc_id`. |
| `literature-search.sh` (`--toc`/`--read`/`--doc`, and the four inline `prefix = "sources/"` fidelity-map sites) | `chunks_data.doc_id` directly (native FTS space); fidelity lookup keyed on the `sources/`-prefix directory name | **Not an offender; cited as precedent.** These sites already implement the path-derived bridge correctly and are deliberately left un-refactored — `literature-doc-key.sh` mirrors this exact pattern for new callers rather than routing these through it. |
| `skill-literature/SKILL.md` (`/literature --validate`) | iterates `.entries[]` as whole records; adds the namespace-divergence check via `literature-doc-key.sh --list-keys` and `sqlite3` against `.literature.db` | **Fixed.** Was driving its loop off `.entries[] | .path`, so a `.path`-less entry became the literal string `"null"` and was misreported as a missing file rather than a schema-shape defect. |
| `literature-fidelity-audit.sh` | `.path` starting with `sources/<dir>/` | **Not an offender; deliberate exclusion**, self-documented in the script's own header (see the header note update below). |
| `literature-discover.sh` (Tier 1 lookup) | `.id // .doc_id // ""` | **Not an offender; a positive precedent.** Already tolerant of both key shapes before this task existed — the pattern `literature-briefing.sh`'s fix mirrors. |
| `zotero-attach-chunks.sh` | `specs/zotero-index.json`'s `zotero_key`, a wholly separate file/namespace | **Not applicable.** Confirmed: never touches `index.json`. |
| `literature-normalize-authors.sh` | `.entries[].authors` uniformly, no id/doc_id keying at all | **Not applicable.** Orthogonal schema axis (author-array shape). |
| `zotero-resolve-pdf.sh` | `select(.id == $id)` | **Not a distinct bug.** Exposed to the same disagreement risk as any `.id`-only consumer, resolved as a side effect of this task's fixes rather than by a separate code change. |
| `zotero-generate-export.sh` | `.id` referenced only as a Zotero API item URL's trailing path segment | **Not applicable.** A different "id" entirely (Zotero item key), not `index.json`'s document id. |
| `test-lit-pipeline.sh` | Section F fixtures deliberately use a `.doc_id`-only parent (no `.id`) and a curated-`.id`-differs-from-FTS-`doc_id` pairing | **Fixed** (was a coverage gap: Section E's shared fixture used one id for both namespaces, always, so it could never catch this defect class). |

**Source-store vs. deploy**: everything documented in this section lives under
`agent-system/extensions/literature/` (the source store). It reaches the deployed
`.claude/scripts/`/`.claude/skills/` tree only on the next deploy. All execution-based
verification behind this section's fixes invoked the source-store scripts by absolute path
directly, never the deployed copies, so none of it depended on (or was masked by) a deploy having
happened.

## Related

- `tools/literature-dir-config.md` — `$LITERATURE_DIR` resolution and the two-tier fallback
- `domain/extension-dependencies.md` — what this extension does and does not auto-load
- `patterns/agent-exploration.md` — how agents navigate the indexed corpus
- `scripts/literature-doc-key.sh` — the single sourced anchor for the `.path`-to-FTS-key
  derivation cited throughout this section
