# Seed Report: Retarget the books extension to the split record and pin the convention version

- **Task**: N1 (global, `~/.config/nvim` specs) - Retarget the books extension to the split convention record and pin the convention version it was measured against
- **Started**: 2026-10-05
- **Completed**: 2026-10-05 (seed only)
- **Effort**: ESTIMATE 1 to 2 working days. Two script fixes with fixture updates, one pattern-file edit, six citation retargets, a figure refresh, one new field, one preflight comparison.
- **Dependencies**: none hard. V1 (Verification repo) settles the version line's name and value; this task ships the pin mechanism tolerant of an absent line ("unversioned") so it can land first.
- **Sources/Inputs** (all under `~/.config/nvim/agent-system/extensions/books/` unless stated):
  - `scripts/books-observe.sh:131-135` (awk `^## Decision` heading lookback), `:312` (`validated_by_files="docs/book-convention.md docs/architecture-decisions.md docs/fault-frame-design.md"`), `:395` (`books/tool/book-snapshot.sh` probe), `:439` (`schema_version: "observation-v1"`).
  - `scripts/tests/test-books-observe.sh:106-127`: fixture writes a flat `## Decision 13` record; stays green against the obsolete shape.
  - `context/project/books/patterns/books-revise-submode.md` "Mandatory Preliminary Research Step" and Edge Case 4: reads `docs/book-convention.md`; drops any candidate whose marker it cannot quote verbatim.
  - Line-anchor citations now dangling: `standards/metadata-split.md:4`, `domain/book-toml-v2.md:8`, `domain/certificate-ledger-and-records.md:8`, `domain/identity-and-versioning.md:9`, `domain/layer-vocabulary-and-matrix.md:7-8`, `domain/status-and-trust-vocabularies.md:7`.
  - Stale figures: `context/project/books/README.md:10,26` ("3,212 lines", "eighteen markers"), `tools/tooling-inventory.md:134`, `domain/known-gap-register.md:3,27-28` (git `7281c81`; census 2/15/1 vs the record's own 1/15/2).
  - Reference implementation in the consuming repo: `~/Projects/Logos/Verification/books/scripts/lint-validated-by.sh:191-241` (`DIR_HEADING_RE='^# Decision [0-9]+[[:space:]]*:'`, `expand_dir_shape()`, unconditional flat-path scan) and `:461-473` (evidence-pair union for citation resolution).
  - Split marker form: `~/Projects/Logos/Verification/docs/book-convention-evidence/README.md:84-93` (one line, 150-300 characters, ends with `→ full exercise history and citations: [...](../book-convention-evidence/NN-slug.md)`).
  - `~/Projects/Logos/Verification/docs/fault-frame-design.md` uses `### Decision N —` headings: the observer's single regex already mis-reads it (12 markers attributed to at most one heading).
  - Deployment status: `~/Projects/Logos/Verification/.claude-extensions.json` has no `books` entry; `specs/books-evidence/` does not exist there; zero observation records exist anywhere.
- **Artifacts**: this report
- **Standards**: source-store-deploy-boundary.md, no-task-references-in-deliverables.md, shell-strict-mode.md, report-format.md

## Project Context

- **Upstream Dependencies**: the consuming repository's record shape (frozen slugs in its evidence README) and its lint's discovery grammar.
- **Downstream Dependents**: N2 (guardrails cite the retargeted anchors), Verification 185 (backfill runs this observer), every `/books` run.
- **Alternative Paths**: have the observer shell out to the repo's `lint-validated-by.sh` for marker extraction (rejected for the join: the observer must run standalone in any consuming repository, per its own D4/D3 decisions; but the *grammar* should be copied, not reinvented).
- **Potential Extensions**: none; keep the extension at its current surface.

## Executive Summary

- The extension is correct against a file shape that no longer exists. Three artifacts fail against the split today, two of them silently: the observer's promotion detector sees only Decision 18; `/books --revise` drops every candidate bearing Decisions 1-17; the test suite stays green.
- The fix is to adopt the consuming repo's own directory-tolerant discovery (one flat file plus `docs/book-convention/*.md` with `# Decision N:` headings), parse the reduced marker's trailing evidence pointer, and give the fixture the new shape.
- The corpus's six line-range anchors become file anchors (`docs/book-convention/NN-slug.md`), the only stable form the split guarantees.
- A `convention_version` pin replaces the prose git SHA as the staleness handle: the corpus declares the version it was measured against; at research/implement preflight for `books`-topic tasks and at every `/books` run, the record's version line is compared and a mismatch is reported once as a warning (the record wins; the corpus is stale), never blocking.
- Nothing new is added to the command surface.

## Context & Scope

In scope: `scripts/books-observe.sh` (path discovery, heading grammar per record, evidence-pointer tolerance, `convention_version` field on the observation record, `book-snapshot.sh --json` contract confirmed); `scripts/tests/test-books-observe.sh` (directory-shaped fixture, fault-frame heading fixture, false-green removed); `patterns/books-revise-submode.md` and `patterns/books-review-submode.md` (read decision files and quote the reduced marker; report header carries the version); the six anchor retargets; the figure refresh in `README.md`, `tooling-inventory.md`, `known-gap-register.md`; `standards/observation-record.md` version-marker note; the pin itself (`manifest.json` `convention_version` or a header field in `context/project/books/README.md`, whichever `check-extension-docs.sh` accepts) and the preflight comparison in the two research/implementation skills. Out of scope: any rule file (N2); any repo-side script; deployment into any consuming repository (owner action).

## Findings

### Observer fix, concretely

Replace the single `validated_by_files` string with a per-record table mirroring `lint-validated-by.sh:195-203`: `book-convention.md` with heading `^## Decision [0-9]+:` for the flat file and `^# Decision [0-9]+[[:space:]]*:` for `docs/book-convention/*.md`; `architecture-decisions.md` with `^## Decision`; `fault-frame-design.md` with `^### Decision [0-9]+[[:space:]]*(—|-)`. Promotion detection compares the marker's `<value>` prefix only (before the ` → full exercise history` pointer), so an evidence-link edit is not misread as a promotion.

### Revise sub-mode fix, concretely

The mandatory research step enumerates `docs/book-convention/*.md` sorted by numeric prefix plus any `## Decision` heading remaining in the flat file; the "durable heading text" is the H1 of the decision file; the marker quoted verbatim is the one-line reduced marker; the step also records the evidence file path so a proposal can cite the exercise history. Edge Case 4's hard return triggers only if neither shape exists.

### Pin semantics

`convention_version: "<X.Y.Z>"` in the corpus header plus `measured_at_commit` (the SHA already in prose). Comparison reads `- **Convention version**:` from the consuming repo's `docs/book-convention.md`; absent line means "unversioned" and the comparison reports "record is unversioned" once. No blocking, no hook (the extension has none and should not gain one for this).

### Test suite

Add fixtures: directory-shaped record with a reduced marker and evidence pointer; flat-plus-directory transitional record; fault-frame heading grammar; a promotion where only the pointer text changed (must not count). Remove nothing else.

## Recommendations

1. Land the observer and fixture fix first (one phase), the revise/review pattern edits second, the anchors and figures third, the pin fourth.
2. Copy the repo lint's grammar verbatim and cite it by path in the script header, so the two stay recognisably the same.
3. Run `verify-deploy.sh`, `check-extension-docs.sh` and `check-task-references.sh` against `extensions/books` as the gate; the books suites must all pass with the new fixtures.
