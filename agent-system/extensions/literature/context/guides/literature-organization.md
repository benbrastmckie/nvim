# Literature Organization Guide

Reference guide for the `specs/literature/` directory and the `--lit` injection system.

## Overview

The `specs/literature/` directory holds reference documents (papers, specifications, algorithm
descriptions) that agents can consult when the `--lit` flag is passed to `/orchestrate`
(with `--research`, `--plan`, or `--implement`). The directory is user-maintained and not created automatically.

Literature injection uses keyword scoring to select the most relevant files for a given task,
staying within a fixed token budget. If no `index.json` exists, the system falls back to a
lexicographic scan of all `.md` and `.txt` files in the directory.

## Directory Structure

Two organization patterns are supported:

### Flat files (single papers or short specifications)

```
specs/literature/
├── index.json
├── Smith_2023_PropositionalLogic.pdf    # gitignored source (co-located)
├── Smith_2023_PropositionalLogic.md     # converted markdown
├── Brastmckie_2024_BimodalLogic.pdf    # gitignored source (co-located)
└── Brastmckie_2024_BimodalLogic.md     # converted markdown
```

Use flat files for papers or documents that fit within the ~3000-token chunk target in a single
file. Each `.md` or `.txt` file corresponds to one entry in `index.json`.

**Source file convention**: PDF/DJVU source files are co-located with their converted markdown
in the same directory. They are gitignored via `specs/literature/**/*.pdf` and
`specs/literature/**/*.djvu`. Users must re-add source files manually after checkout.

### Subdirectory layout (books or long documents)

```
specs/literature/
├── index.json
└── Brastmckie_2024_BimodalLogic/
    ├── Brastmckie_2024_BimodalLogic.pdf  # gitignored source (co-located)
    ├── sec01_introduction.md
    ├── sec02_syntax.md
    └── sec03_semantics.md
```

Long documents are chunked into section files inside a named subdirectory. The global
`specs/literature/index.json` contains one entry per section, with `path` pointing to the
section file (e.g., `Brastmckie_2024_BimodalLogic/sec02_syntax.md`).

> **Note**: There is no per-book `index.json` inside subdirectories — only the top-level
> `specs/literature/index.json`. (The now-quarantined `literature-retrieve.sh`,
> `scripts/deprecated/literature-retrieve.sh`, formerly read only this top-level file; see
> "How --lit Injection Works" below for the current live mechanism.)

## Naming Conventions

### Flat paper files

Format: `Author_Year_Title.md`

- `Author`: Last name of first author, capitalized (e.g., `Smith`, `Brastmckie`)
- `Year`: Four-digit publication year
- `Title`: CamelCase abbreviated title (no spaces)

Examples:
- `Smith_2023_PropositionalLogic.md`
- `Brastmckie_2024_BimodalLogic.md`
- `VanBenthem_2010_ModalLogicGameSemantics.md`

### Chapter/section files inside a subdirectory

Format: `secNN_slug.md`

- `NN`: Zero-padded section number for lexicographic ordering (01, 02, 03...)
- `slug`: 2-4 word kebab-case description of the section content

Examples:
- `sec01_introduction.md`
- `sec02_syntax.md`
- `sec03_canonical-models.md`

## index.json Schema

The top-level `specs/literature/index.json` file controls keyword-scored injection. Without it,
the system falls back to a blind lexicographic scan.

### File structure

```json
{
  "entries": [
    { ... },
    { ... }
  ]
}
```

### Entry fields

All fields are written by `/literature --convert` and `/literature --index`. The first four
fields were read by the now-quarantined `literature-retrieve.sh` (see "How --lit Injection
Works" below for the current live mechanism); the remaining fields are used by tooling and for
human reference.

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier (e.g., `smith2023_proplogic`); used by retrieve script for logging |
| `path` | string | File path relative to `specs/literature/`; used by retrieve script for file loading |
| `token_count` | integer | Estimated token count; used by retrieve script for greedy budget enforcement |
| `keywords` | string[] | Keywords for relevance scoring against the task description |
| `summary` | string | One-sentence description; earns a +1 bonus if any task keyword matches |
| `authors` | string[] | Author list (e.g., `["Alice Smith", "Bob Jones"]`) |
| `title` | string | Full document or section title; shown in injected context heading |
| `year` | integer\|null | Publication year (null if unknown) |
| `doc_type` | string | One of: `paper`, `book`, `chapter`, `section` |
| `source_format` | string | One of: `pdf`, `djvu`, `manual` |
| `parent_doc` | string\|null | ID of parent entry for chunks/sections; null for top-level entries |
| `page_range` | string\|null | Page range in source document (e.g., `"15-47"`); null if not applicable |

### Complete entry example (flat paper)

```json
{
  "id": "smith2023_proplogic",
  "path": "Smith_2023_PropositionalLogic.md",
  "token_count": 1850,
  "keywords": ["propositional", "logic", "syntax", "semantics", "proof"],
  "summary": "Introduces propositional logic with natural deduction and truth tables.",
  "authors": ["Alice Smith"],
  "title": "Propositional Logic: A Modern Introduction",
  "year": 2023,
  "doc_type": "paper",
  "source_format": "pdf",
  "parent_doc": null,
  "page_range": null
}
```

### Complete entry example (section of a chunked book)

```json
{
  "id": "brastmckie2024_bimodal_sec02",
  "path": "Brastmckie_2024_BimodalLogic/sec02_syntax.md",
  "token_count": 2100,
  "keywords": ["bimodal", "syntax", "formula", "operator", "modal"],
  "summary": "Defines the formal syntax of bimodal logic with operator precedence rules.",
  "authors": ["Benjamin Brastmckie"],
  "title": "BimodalLogic - Section 2: Syntax",
  "year": 2024,
  "doc_type": "section",
  "source_format": "pdf",
  "parent_doc": "brastmckie2024_bimodal",
  "page_range": "15-47"
}
```

## Chunk Sizing Policy

### Token budget

The injection system enforces a hard ceiling of **4000 tokens total** across all selected files
(`TOKEN_BUDGET=4000`). Up to 10 files may be injected (`MAX_FILES=10`).

A single file that would push the running total past the budget is silently skipped. Files are
evaluated in descending relevance score order, so lower-relevance files are skipped first.

### Recommended chunk target

Each file should target **~3000 tokens** (~2300 words) to allow room for at least one
additional file within the budget. Avoid files that exceed 4000 tokens on their own -- they
will always be skipped in index mode if any other file has been selected first.

### Token estimation formula

The script estimates tokens in fallback mode as:

```bash
est_tokens=$(( (word_count * 13 + 5) / 10 ))
```

This approximates 1.3 tokens per word. Use the same formula to populate the `token_count`
field in `index.json`:

```bash
echo $(( ($(wc -w < file.md) * 13 + 5) / 10 ))
```

Re-run this command after significant edits to keep `token_count` accurate.

## How --lit Injection Works

### End-to-end flow

The current live mechanism is `literature-briefing.sh` (invoked via
`literature-briefing-invoke.sh`), driven by each importing skill's Stage 4a block. The full
resolver-directive branching (`LIT_DISABLED`, `GLOBAL_MISSING`, `SUBINDEX_PRESENT`,
`AUTONOMOUS_GLOBAL`, `SPARSE_PROMPT_NEEDED`, `PROMPT_NEEDED`, the four interactive sub-index
setup options, sparse-coverage re-prompting, and the `orchestrator_mode` dual-consumer contract)
is canonically defined in `context/patterns/lit-stage4a-flow.md` — the single executable Stage 4a
block that `skill-orchestrate` and every domain research/implementation skill import directly and
execute verbatim. Read that file for the full mechanics; this section is
a pointer, not a second copy. At a high level: the resolved flow calls
`literature-briefing.sh`/`literature-briefing-invoke.sh` (never `literature-retrieve.sh`, which
is quarantined — see below), which resolves metadata from `specs/literature-index.json` (the
per-repo sub-index) and the global `Literature/` repository's `index.json`, and writes a
`<literature-briefing>` block into the agent prompt — never an empty block when nothing was
found (see that file's "Non-Silence Invariant").

### Mode A: keyword-scored injection (historical — describes the quarantined script)

**This subsection and Mode B below describe `literature-retrieve.sh`'s internal algorithm.**
That script is quarantined (`scripts/deprecated/literature-retrieve.sh`, removed from
`manifest.json` `provides.scripts`, zero live callers) and superseded by `literature-briefing.sh`
per the End-to-end flow above. Retained here for historical reference only — do not treat as a
description of current `--lit` behavior.

**Step 1 -- Keyword extraction**: The script combines the task description and task type,
lowercases, strips stop words, filters to tokens longer than 3 characters, deduplicates, and
takes the top 10 keywords.

**Step 2 -- Scoring**: For each `index.json` entry:
- `kw_score` = count of task keywords found in `entry.keywords[]` (case-insensitive)
- `summary_bonus` = 1 if any task keyword appears in `entry.summary`, else 0
- `total_score = kw_score + summary_bonus`
- Entries with `total_score < 1` are excluded (`MIN_SCORE=1`)
- Remaining entries are sorted descending by score

**Step 3 -- Greedy selection**: Iterates scored entries in score order. An entry is selected if:
- Fewer than 10 files have been selected so far (`MAX_FILES=10`)
- Adding the entry would not exceed the 4000-token budget (`TOKEN_BUDGET=4000`)

**Step 4 -- Output**: Selected files are wrapped in `<literature-context>` with headings
showing each file's title and relevance score.

### Mode B: fallback scan

Used when `specs/literature/index.json` does not exist, or when the task description is empty.

The script scans `specs/literature/` recursively for `*.md` and `*.txt` files, sorts them
lexicographically, and includes each file that fits within the remaining token budget (using the
`(word_count * 13 + 5) / 10` estimation). Headings show the file's basename.

**Implication**: Without `index.json`, all files in the directory are candidates regardless of
relevance, and selection is purely first-fit by alphabetical order. For more than a few papers,
create `index.json` to enable keyword scoring.

## Adding New Papers

The easiest way to add a paper is `/literature --convert` (for PDFs/DJVUs) or
`/literature --index FILE` (for existing markdown files). Both commands prompt interactively for
all required metadata.

For manual index entry creation:

### Step 1: Place the source file (co-located convention)

Copy or symlink the PDF/DJVU source file into the same `specs/literature/` directory or
subdirectory where the converted markdown will live. The source file will be gitignored.

**Flat paper** (short):
```
specs/literature/Author_Year_Title.pdf    # gitignored source
specs/literature/Author_Year_Title.md     # converted markdown
```

**Long document** (chunked):
```
specs/literature/Author_Year_Title/Author_Year_Title.pdf  # gitignored source
specs/literature/Author_Year_Title/sec01_slug.md
specs/literature/Author_Year_Title/sec02_slug.md
```

### Step 2: Convert and chunk the document

For PDFs/DJVUs, use `/literature --convert` to run the content-aware chunking algorithm, which:
1. Converts the source to text
2. Detects chapter/section headings (logical split at 4,000-line threshold)
3. Creates section files with structure-aware names (`sectionNN_slug.md`)
4. Falls back to mechanical 4,000-line splits with `_partNN.md` naming if no headings found

For manual conversion, target ~3000 tokens (~2300 words) per section file.

### Step 3: Estimate token counts

For each file, run:

```bash
echo $(( ($(wc -w < specs/literature/Author_Year_Title.md) * 13 + 5) / 10 ))
```

Record the output as the `token_count` value for that file's index entry.

### Step 4: Choose keywords

Select 5-10 keywords that capture the core concepts of the paper or section. Keywords should
match the vocabulary an agent would naturally use when describing a task that needs this paper.

Good keywords are: domain-specific nouns (`modal`, `completeness`, `canonical`), algorithm
names, formal system names, and key technical terms.

Avoid generic terms (`paper`, `introduction`, `section`) that appear in most documents.

### Step 5: Write the index entry

If `specs/literature/index.json` does not exist, create it with an empty `entries` array first:

```json
{
  "entries": []
}
```

Add one entry per file (or per section for chunked documents) to the `entries` array. Use the
template from the schema section above. Ensure:
- `id` is unique across all entries
- `path` is relative to `specs/literature/` (not an absolute path)
- `token_count` matches the estimate from Step 3
- `keywords` reflects the task vocabulary where this paper is relevant
- `summary` is a single sentence capturing the file's content
- `authors`, `title`, `year`, `doc_type`, `source_format` are filled in
- `parent_doc` and `page_range` are set for chunked section entries; null for top-level entries

### Step 6: Validate the index

```bash
jq . specs/literature/index.json
```

A clean exit with formatted output confirms the file is valid JSON.

### Step 7: Test the injection

Run a command with `--lit` and a relevant task description to verify the paper appears:

```bash
# Example: verify injection for a research task
/orchestrate 123 --research --lit
```

Check the agent context for a `<literature-context>` block containing the paper.

## Converter Tier Selection

When `/literature --convert` (or `literature-convert.sh` directly) gate-rejects a document with a
`sentence_boundary_glue_count()` failure, the operator remedy depends on *where the defect
originates* — not on whether the source was scanned or born-digital. "Scanned vs. born-digital"
is explicitly NOT the discriminator: `bacon_dorr_2024_classicism` is a very-likely born-digital
2024 paper and the fallback tier fixes it; `joyce_1999_foundations-causal-decision-theory` is
scanned and the fallback tier makes it marginally worse (4 hits on the primary tier -> 5 on the
fallback tier). Two distinct classes exist, each with its own remedy:

| | Class A: primary-tier structuring artifact | Class B: text-layer defect |
|---|---|---|
| **Where the defect lives** | Introduced by pymupdf4llm's markdown-structuring heuristics (table detection, `<sup>`/`<sub>` span wrapping) | Already present in the extracted text layer (both tiers read it via the same underlying `fitz` extraction) |
| **Fallback tier's effect** | Fixes it — bypasses the structuring layer entirely | Does nothing to it, and can add unrelated noise from its own column-clustering |
| **Confirmed cases** | `savage_1972_foundations-of-statistics` (73 hits -> 3), `bacon_dorr_2024_classicism`, the Goldblatt/Hodkinson/Venema 2003 case | `joyce_1999_foundations-causal-decision-theory` (4 hits -> 5) |
| **Document provenance** | Mixed — one scanned, two very likely born-digital | Scanned (poor-vintage OCR, a 2019 archive.org pass) |
| **Correct remedy** | Reconvert with `LITERATURE_CONVERTER=fallback` | Re-OCR the source, then reconvert — a converter-tier switch alone will not help. In-pipeline: `LITERATURE_OCR_FORCE=1 LITERATURE_CONVERTER=ocr literature-convert.sh <input.pdf> <output_dir>` (runs `ocrmypdf --force-ocr` and feeds the result back through conversion + the quality gate) |
| **Diagnostic tell** | Hits positionally concentrated in a structural region (e.g. back matter misdetected as a table), or centered on footnote/superscript markers | Hits scattered singly at otherwise-clean sentence boundaries with no structural pattern |

**Diagnostic procedure**: on a gate rejection, inspect where the `sentence_boundary_glue_count()`
hits fall in the converted markdown.
- Positionally concentrated near back matter or clustered around footnote/superscript markers
  suggests Class A — try `LITERATURE_CONVERTER=fallback` and reconvert.
- Scattered singly at otherwise-clean sentence boundaries with no structural pattern suggests
  Class B — check the source page's OCR quality; running `ocrmypdf --force-ocr` on the affected
  pages and reconverting is the correct remedy, since a tier switch alone will not help.

**Class C: no text layer (absence)**. A third, distinct failure mode — not a gate rejection at
all, and not diagnosed by inspecting hit positions the way Class A/B are. The tell: conversion
exits 2 (not 3) with a `NO TEXT LAYER:` marker in stderr, because BOTH engine tiers produced
empty output before the quality gate was ever reached — a genuinely image-only, scanned PDF with
no extractable text layer at all, as opposed to Class B's already-present-but-degraded text
layer. The remedy is the same OCR machinery as Class B's, but without `--force-ocr` (there is no
existing text layer to discard): `LITERATURE_CONVERTER=ocr literature-convert.sh <input.pdf>
<output_dir>`. `literature-ingest.sh` reports a Class C document under its own
"Files needing OCR" summary bucket, distinct from both "Files quality-gate-failed" (Class A/B)
and the generic "Files failed" (a hard failure such as a missing input file, or an
explicitly-requested engine tier that is itself unavailable — the exit code 2 is shared with
Class C, so a consumer must key off the `NO TEXT LAYER:` stderr marker, never off the bare code,
exactly as exit 3 is already keyed off the `QUALITY GATE FAILED` prefix rather than its code).

**`joyce_1999_foundations-causal-decision-theory` resolved example**: at implementation time this
Class B document converted cleanly and passed the gate at 2 hits — both known math-notation false
positives, zero genuine text-layer defects present — without any re-OCR having been performed;
because its source PDF lives outside this repository's version control, a document's measured hit
count reflects its text layer at measurement time, not a permanent property of the document.

**No automatic tier selection exists or is intended.** The discriminator above requires
inspecting where the post-conversion hits fall; it is not computable a priori from document
metadata (page count, scan status, ingestion source), so a naive auto-select would regress Class B
documents by masking a real text-layer defect behind a tier switch that does nothing for it. Note
also that `LITERATURE_CONVERTER=auto`'s fallback is an engine-availability fallback (it only
engages the fallback tier when the primary engine itself is unavailable or fails to run) — it is
not a quality-gate retry, and nothing reconverts a gate-rejected document automatically.
`LITERATURE_CONVERTER=ocr` is likewise explicit-only and never entered by `auto`: an OCR pass is
a document-scale, minutes-long operation (tens of minutes on a several-hundred-page scan), and
running it automatically inside `literature-ingest.sh`'s batch loop would silently balloon
wall-clock time for every image-only document in a directory ingest, with no way for the operator
to opt out per-document.

### Content-Based OCR-Misrecognition Detection: A Measured Negative Result

A content-based OCR-misrecognition detector — one that reads the extracted TEXT for a corruption
signature, rather than the metadata-only scan-pipeline check documented below — was evaluated and
found non-viable on this corpus. This is recorded here so the same dead end is not rebuilt.

**Four signal families were tried**, each progressively refined against 11 known scan-pipeline
corpus documents (real Acrobat Capture/Import/Image-Conversion-Plug-in or ABBYY FineReader
provenance) and 6 born-digital dense-math negative controls:
1. Whole-document out-of-vocabulary (OOV) rate.
2. Whole-document mixed-alphanumeric-symbol density.
3. Prose-line-restricted anomaly rate (the OOV/density signal computed only over lines classified
   as ordinary prose, excluding headings/tables/math blocks).
4. Embedded-corruption-token rate (a narrower pattern targeting the specific garbled-character
   sequences OCR misrecognition produces).

**None separated the two groups at any threshold.** The decisive counter-example: a genuine
Acrobat Image Conversion scan (`blackburn_2002`) scored 15.69 hits/10k words, while born-digital
dense-math controls scored 153.95/10k (`venema_2007`) and 306.22/10k (`ahrens_north`) — the
negative controls repeatedly outscored the real positive by an order of magnitude. Narrowing the
signal did not close the gap: at the fourth round's narrowest refinement, `blackburn_2002` still
scored only 2.70/10k against `ahrens_north`'s 84.55/10k.

**Each refinement round closed exactly one false-positive class and exposed a different one**:
- Round 1 -> Round 2: proper nouns.
- Round 2 -> Round 3: typographic quotes.
- Round 3 -> Round 4: citation-year author codes, combining-mark diacritics, and LaTeX macro
  leakage.
- Round 4's own residual false-positive class: em/en-dash and slash compounds, and inline HTML
  sub/superscript leakage.

**Conclusion**: the metadata-only scan-pipeline provenance check
(`literature_quality_gate.scan_pipeline_provenance`, consumed by both
`literature-fidelity-audit.sh`'s scan-source gate and `literature-convert.sh`'s conversion-time
advisory) is very likely the ceiling for this corpus, not a stepping stone toward a
content-based replacement. It is a bounded, known-signature Creator/Producer allowlist —
**provenance-only, and advisory only**: a `True` result is never a quality-gate rejection, never
a withheld certification, and never a converter-tier selector. Scan provenance does not predict
remedy — two scanned corpus documents from the Converter Tier Selection table above illustrate
this directly: `savage_1972_foundations-of-statistics` is Class A (the fallback tier fixes it)
while `joyce_1999_foundations-causal-decision-theory` is Class B (the fallback tier does not),
even though both are scans.

**One avenue remains untried**: a genuinely independent second extraction — comparing the
existing text layer against a **fresh** `ocrmypdf`/Tesseract pass on the same page images —
would sidestep the blind spot all four tried signal families and both existing engine tiers
share (they all read the same already-degraded `fitz`-extracted text layer). This was
deliberately excluded from the four rounds above for cost reasons: a full Tesseract pass over a
several-hundred-page document is a document-scale, minutes-long operation, unsuited to the
automatic per-conversion gate. It belongs in an on-demand audit command, if pursued at all.

## Maintenance

- **Token counts go stale**: After editing a file, re-estimate its `token_count` using the
  formula above and update `index.json`.
- **Irrelevant files are selected**: Tighten `keywords` to better match task vocabulary, or
  remove generic keywords.
- **Files are never selected**: Check that `keywords` overlaps with terms appearing in the task
  descriptions for the tasks that should use this paper.
- **Budget exhausted before high-priority files**: Reduce chunk sizes or split large files.
