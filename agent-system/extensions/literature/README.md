# Literature Extension (v2.0.0)

Unified extension for managing the global Literature/ repository and per-repo sub-indices.
Handles source discovery, PDF/DJVU-to-markdown conversion, FTS5-backed search, and agent
context briefing. Absorbs the former zotero extension.

## Loading the Extension

```
Extension picker -> select "literature"
```

---

## Architecture Overview

### Single Source of Truth: Global Literature/ Repo

All converted literature lives in `~/Projects/Literature/` (configured via `LITERATURE_DIR` in
`.claude/settings.json`). The global repo contains:
- `index.json` — Enriched v2 metadata for every document (222+ entries)
- `sources/` — Converted markdown files organized by document
- `.literature.db` — SQLite FTS5 database for full-text search
- `zotero-library.json` — Better BibTeX CSL-JSON export (auto-updated by Zotero)

Per-project copies of content are **not maintained**. Agents access the global repo directly
via absolute paths.

### Per-Repo Sub-Index: `specs/literature-index.json`

Each project maintains a lightweight reference index listing which global documents are
relevant to that project. Entries are reference-only (doc_id pointers); no metadata is cached.

```json
{
  "project": "nvim",
  "literature_dir": null,
  "entries": [
    {
      "doc_id": "blackburn_2001_modal_logic",
      "relevance": "Core reference for modal logic formalization",
      "added": "2026-06-23",
      "source": "discover"
    }
  ]
}
```

Sub-index operations are provided by `/literature` (Mode B) and `skill-literature`.

### Briefing+Tools Pattern for Agents

When `--lit` is passed to `/research`, `/plan`, `/implement`, or `/orchestrate`:

1. `literature-briefing.sh` reads `specs/literature-index.json`
2. Resolves each `doc_id` against `$LITERATURE_DIR/index.json` to get metadata
3. Outputs a `<literature-briefing>` block (~300-500 tokens) into the agent prompt

Agents then use existing tools on-demand:
- **Read specific chunks**: `Read` tool with absolute paths from the briefing
- **Search full corpus**: `bash .claude/scripts/literature-search.sh "query"`
- **Browse TOC**: `bash .claude/scripts/literature-search.sh --toc doc_id`
- **Get related entries**: `bash .claude/scripts/literature-search.sh --refs doc_id`

This is strictly cheaper than full content injection (~300 tokens briefing vs 4,000-8,000
tokens injection) while enabling selective, on-demand access to the entire corpus.

---

## Commands

Two modes, one command:

| Command | Mode | Description |
|---------|------|-------------|
| `/literature N` | Discover (A) | Find sources relevant to task N |
| `/literature "query"` | Discover (A) | Find sources matching the query |
| `/literature N "query"` | Discover (A) | Find sources using task+query |
| `/literature` | Integrate (B) | Status report + scan for unprocessed files |
| `/literature ~/path/to/file.pdf` | Integrate (B) | Ingest a specific PDF/DJVU |
| `/literature ~/path/to/dir/` | Integrate (B) | Ingest all PDFs in a directory |
| `/literature --validate` | Both | Validate sub-index against global index |

### Mode A: Source Discovery

Runs a three-tier discovery pipeline via `literature-discover.sh`:
1. **Tier 1 (offline)**: Search `$LITERATURE_DIR/index.json` by title/keyword
2. **Tier 2 (local)**: Search Zotero library (`zotero-library.json`) for available PDFs
3. **Tier 3 (online)**: Ordered provider fallback chain — Semantic Scholar API -> OpenAlex ->
   Crossref, advancing only on genuine provider failure — plus Unpaywall DOI lookup and arXiv
   direct PDF resolution. Optional `S2_API_KEY` / `OPENALEX_API_KEY` env vars raise Semantic
   Scholar's/OpenAlex's rate limits; both are unset-safe (fully anonymous) by default.

Results are presented interactively. For each selected `open_access`/`paywall`/`in_zotero_no_pdf`
entry, the user is offered a choice: ingest it into the Literature corpus now (via
`literature-ingest-online.sh` — downloads and magic-byte-verifies the PDF, creates or attaches the
Zotero item, then delegates to the unmodified `literature-ingest.sh` pipeline and registers it in
`specs/literature-index.json`), or just record it in `specs/literature/SOURCES.md` for later
acquisition (the default/fallback, and the only outcome for records with no discoverable PDF).

### Mode B: Integration

Processes source files (PDF/DJVU) through the ingestion pipeline:
1. Runs `literature-ingest.sh` for conversion and FTS5 indexing
2. Updates `specs/literature-index.json` with new doc_ids
3. Marks entries as `[RESOLVED]` in `SOURCES.md`

If conversion is gate-rejected, see `context/guides/literature-organization.md`'s Converter Tier Selection section for which converter tier to force and when a tier switch will not help.

---

## --lit Flag Semantics

Pass `--lit` to any research/plan/implement command to enable literature context:

```bash
/research 42 --lit        # Research with literature briefing
/implement 42 --lit       # Implement with literature briefing
/orchestrate 42 --lit     # Full lifecycle with literature briefing
```

**What changes**: `<literature-briefing>` block appears in agent prompt (not `<literature-context>`).
Agents get a compact catalog of available papers with paths; they fetch what they need.

**When to use**: Any task that implements from a paper, proves a theorem, or requires
verifiable citations. The briefing costs ~300 tokens; follow-up reads cost tokens proportional
to what the agent actually reads.

No `--zot` flag exists. All Zotero functionality is accessed via Mode A discovery or the
`zotero-search.sh` script directly.

---

## Zotero Integration

Zotero integration is internal to this extension (absorbed from the former zotero extension).
Scripts are in `.claude/extensions/literature/scripts/zotero-*.sh`.

### Setup

1. Install **Better BibTeX** plugin for Zotero
2. File > Export Library > Better CSL JSON > "Keep updated"
3. Save to `~/Projects/Literature/zotero-library.json`
4. The export auto-updates whenever Zotero is open

### Available Scripts

| Script | Purpose | Deployed |
|--------|---------|----------|
| `zotero-search.sh` | Search CSL-JSON export by keyword (used by Mode A) | Yes |
| `zotero-read.sh` | Read item metadata and PDFs via `zot` CLI | No — inactive, see below |
| `zotero-write.sh` | Write/attach files to Zotero items; create new items with PDF attachment (`item-add`) or from a fully-formed JSON body (`item-add-json`); clean dead orphaned attachment records (`orphan-clean`) | No — inactive, see below |
| `zotero-setup.sh` | Setup wizard: detect data dir, validate, configure | No — inactive, see below |
| `zotero-chunk.sh` | Extract PDF text and chunk into sections | No — inactive, see below |
| `zotero-attach-chunks.sh` | Upload chunks as Zotero child attachments | No — inactive, see below |
| `cite-extract.sh` | Extract citation patterns from markdown artifacts | Yes |
| `literature-ingest-online.sh` | Online-discovery -> Zotero+PDF -> ingest bridge (classify/download-verify/create-or-attach/delegate/patch) | Declared in `manifest.json`; its classification/download/delegate/patch logic works standalone, but its create-item and attach-to-existing paths call `zotero-write.sh`, which is itself still blocked on the external `zot` CLI (see below) |

### Deployment Status

This section is the authoritative record of which zotero/cite artifacts are live vs.
intentionally undeployed, and why (established by the zotero/cite deployment-status audit, then
reconciled after the extension's first-time activation).

**Active — the extension is registered in `.claude-extensions.json` (`status: "active"`) and
deployed byte-for-byte from this directory to `.claude/scripts/`, `.claude/skills/`,
`.claude/commands/`, `.claude/agents/`, and `.claude/context/`.** This includes every script in
`manifest.json` `provides.scripts` except the two named as intentionally superseded below —
in particular:
- `zotero-read.sh`, `zotero-write.sh`, `zotero-setup.sh` — `zot` v0.10.0 and a
  `library+files+write` API key are both available; these are deployed and confirmed
  byte-identical to their source copies. `zotero-write.sh` is the single write choke-point,
  called from `literature-ingest-online.sh`'s `item-add`/`item-add-json`/`attach-file`/
  `orphan-clean` calls (see `context/project/literature/patterns/zotero-item-creation.md` for the
  live-confirmed envelope evidence).
- `cite-extract.sh`, `skill-cite/`, `cite.md` — the `/cite` trio.
- `zotero-search.sh` — already load-bearing via a source-path fallback in
  `skill-literature/SKILL.md`; deployed for consistency with the other live scripts.

`jq -r '.extensions.literature.status' .claude-extensions.json` remains the source of truth for
"is this deployed right now" — this table records what that command currently reports, not an
aspirational plan.

**Inactive (intentionally NOT deployed — superseded, remain source-only in this directory)**:

| Artifact | Reason |
|----------|--------|
| `zotero-chunk.sh` | Superseded by the read-only briefing+tools design; write-back-to-Zotero chunking is orthogonal to the current pipeline. No live caller. |
| `zotero-attach-chunks.sh` | Superseded by the same read-only design. No live caller. |

**Removed**: the former zotero index-add and index-remove scripts — dead code;
their add/remove-from-index logic is reimplemented inline via `jq` in
`skill-literature/SKILL.md`. Both were quarantined via `git mv` (never hard-deleted) into
`.claude/extensions/literature/scripts/deprecated/` and dropped from `manifest.json`
`provides.scripts`; see `scripts/deprecated/README.md` for the quarantine note.

The two intentionally superseded scripts above remain declared in `manifest.json`
`provides.scripts` but are absent from `.claude/scripts/` — this is intentional. The drift guard
(`check-extension-docs.sh` `check_deployed_script_drift()`) skips scripts whose deployed copy is
absent (it only `FAIL`s on *content mismatch* when both source and deployed copies exist), so
leaving these undeployed produces an expected `info "script not deployed, skipping drift check"`
line, not a failure.

**Correction to `reports/01_install-status-research.md`**: that report
characterized `test-lit-pipeline.sh` as source-only/never-deployed alongside the seven zotero
scripts above. Later verification found this is no longer accurate:
`test-lit-pipeline.sh` **is** deployed at `.claude/scripts/test-lit-pipeline.sh`, byte-identical
to this source copy, added by the `--lit` integration test script addition ("add --lit
integration test script", commit `eb84ce9f8`, 2026-06-23) as a standalone 33-check
integration-test harness for the `--lit` pipeline — an unrelated concern to the zotero/cite
surface this audit addresses. The audit did not deploy it and leaves it as-is (deployed,
owned by that earlier addition); the drift guard compares it against source and finds
no mismatch, so it does not appear in the "skipping drift check" list above. Its `provides.scripts`
declaration and deployed copy are consistent, not drift.

### Extension Tracking Gap — Closed

The literature extension previously had no entry in the project-root extension manifest
(`.claude-extensions.json`), even though the `/cite` trio and `zotero-search.sh` were already
live. That gap is now closed: the extension was registered via the ordinary extension-loader
flow (never by hand-authoring `.claude-extensions.json` — the `merged_sections` metadata it
carries is loader-owned state), and `jq -r '.extensions.literature.status'
.claude-extensions.json` reports `active` with a populated `installed_files` array.

---

## Content-Aware Chunking

Documents are split at logical section boundaries (chapters, numbered sections, markdown
headings) with a 4,000-line threshold. Adjacent small sections are merged. Falls back to
mechanical 4,000-line splits when no headings are detected.

Output naming:
- Structure-detected: `{dirname}/sectionNN_{slug}.md`
- Mechanical fallback: `{dirname}/{basename}_partNN.md`

---

## Global Index Schema (v2)

Each `index.json` entry in the global repo includes:

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier (`doc_id`) |
| `path` | string | Path relative to `$LITERATURE_DIR` |
| `token_count` | integer | Estimated token count |
| `keywords` | string[] | Search and scoring keywords |
| `summary` | string | One-sentence description |
| `authors` | string[] | Author list |
| `title` | string | Full document or section title |
| `year` | integer\|null | Publication year |
| `doc_type` | string | `paper`, `book`, `chapter`, or `section` |
| `source_format` | string | `pdf`, `djvu`, or `manual` |
| `parent_doc` | string\|null | Parent entry ID for section chunks |
| `page_range` | string\|null | Page/line range in source document |
| `bib_key` | string\|null | BibTeX key from source .bib file |
| `zotero_key` | string\|null | Zotero/Better BibTeX canonical item key |
| `zotero_path` | string\|null | Path to PDF in Zotero storage |
| `project_tags` | string[] | Originating project names |

---

## Tool Requirements

- **pdftotext** (from poppler_utils): Required for PDF conversion
- **pdfinfo** (from poppler_utils): Used for page count detection
- **djvutxt** (from djvulibre): Required for DJVU conversion (optional)
- **zot** (zotero-cli-cc v0.10.0): Required for the Zotero write-back path (`zotero-write.sh`,
  `zotero-read.sh`, `zotero-setup.sh`); read-only discovery (Mode A Tier 2, `zotero-search.sh`)
  still works from the CSL-JSON export without it.

Install via Nix: `nix-env -iA nixpkgs.poppler_utils nixpkgs.djvulibre`

---

## Provided Artifacts

| Type | Name | Purpose |
|------|------|---------|
| Agent | literature-agent.md | Briefing+tools architecture description |
| Skill | skill-literature | All conversion, index, and sub-index operations |
| Skill | skill-cite | Citation verification against Literature/ and Zotero |
| Command | /literature | Discover (Mode A) and integrate (Mode B) entry point |
| Command | /cite | Citation verification command |
| Script | scripts/literature-briefing.sh | Generates `<literature-briefing>` blocks for agents |
| Script | scripts/literature-discover.sh | Three-tier source discovery pipeline |
| Script | scripts/literature-ingest-online.sh | Online-discovery -> Zotero+PDF -> ingest bridge (classify/download-verify/create-or-attach/delegate/patch) |
| Script | scripts/literature-combining-audit.sh | Read-only corpus-wide detector for silently dropped combining marks (a bare U+0338 grep cannot find the silent-drop class) |
| Script | scripts/literature-repair-combining.sh | Backup-guarded, anchored, dry-run-default in-place repair engine for detected combining-mark occurrences |

Both `literature-combining-audit.sh` and `literature-repair-combining.sh` import the shared
`literature_combining_detect.py` module, so detection and repair locate and classify occurrences
identically. `literature-convert.sh` composes overlays inline via
`literature_combining_overlay.py`, which also exposes a `--self-test` fixture mode used to verify
the composition logic from a deployed copy.
