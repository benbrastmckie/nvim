# Implementation Summary: Task #340

- **Task**: 340 - Retarget the books extension to the split convention record and pin the convention version
- **Status**: [COMPLETED]
- **Started**: 2026-10-05T18:00:00Z
- **Completed**: 2026-10-05T20:35:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: None
- **Artifacts**: plans/02_split-retarget-and-version-pin.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

The books extension was retargeted from the obsolete flat `docs/book-convention.md` record shape
to the consuming repository's actual split shape (one file per decision under
`docs/book-convention/NN-slug.md`, a paired `docs/book-convention-evidence/NN-slug.md`, and a
slim flat index). All seven planned phases landed: the observer's discovery grammar and
promotion comparison, four new test fixtures that remove the prior false green, both `/books`
sub-modes' shape-tolerant research steps, six retargeted line-range anchors plus three refreshed
figures, a new `convention_version` pin with a non-blocking preflight comparison, and a full
line-count reconciliation plus gate sweep.

## What Changed

- `agent-system/extensions/books/scripts/books-observe.sh` — per-record heading-regex table
  (`RECORD_HEADING_RE`, `DIR_HEADING_RE`), directory expansion via `git ls-tree` at `h`/`h^`,
  generalized `extract_validated_by_pairs` (awk `-v` heading regex, generic `#`-prefix strip),
  new `marker_value_prefix()` value-prefix-only promotion comparison (cuts at the literal
  evidence-pointer phrase, U+2192), `source_path` on every promotion entry.
- `agent-system/extensions/books/scripts/tests/test-books-observe.sh` — Case 1 relabeled as the
  flat-index shape specifically; four new cases (8: directory shape, 9: transitional
  flat+directory, 10: fault-frame `### Decision N — ...` heading grammar, 11: pointer-only edit
  must not count as a promotion). 59 passed, 0 failed; a negative control confirmed cases 8–10
  fail against the pre-fix observer (7 assertions), proving the false green is gone.
- `agent-system/extensions/books/context/project/books/patterns/books-revise-submode.md` — the
  Mandatory Preliminary Research Step now enumerates both shapes, quotes the one-line reduced
  marker plus its paired evidence path, and the Edge Case Check 4 hard return fires only when
  neither shape exists.
- `agent-system/extensions/books/context/project/books/patterns/books-review-submode.md` — added
  a live-marker step to the Burdens table (two new columns), a convention-version line in the
  dated report header template, and a degraded-report Edge Case Check for an unresolvable Decision.
- Six anchors retargeted from `docs/book-convention.md:LINE-RANGE` to
  `docs/book-convention/NN-slug.md` paths in `standards/metadata-split.md`,
  `domain/book-toml-v2.md`, `domain/certificate-ledger-and-records.md`,
  `domain/identity-and-versioning.md`, `domain/layer-vocabulary-and-matrix.md`,
  `domain/status-and-trust-vocabularies.md`.
- `context/project/books/README.md` — refreshed slim-index line count (343 lines, measured
  2026-10-05 at `a07ae5f`), new "Convention version pin and staleness comparison" section.
- `context/project/books/tools/tooling-inventory.md`, `domain/known-gap-register.md` — refreshed
  shape description and date/SHA/pin reference; the 2/15/1 census left byte-identical (verified
  against `a07ae5f`).
- `agent-system/extensions/books/manifest.json` — new top-level `convention_version` /
  `measured_at_commit` pin.
- `context/project/books/standards/observation-record.md` — optional `convention_version` field;
  snapshot-probe absence re-confirmed directly.
- `agent-system/extensions/books/skills/skill-books-review/SKILL.md` — one-line pointer to the
  new comparison section from the Shared Sub-Mode Skeleton.
- `agent-system/extensions/books/index-entries.json` — all 10 drifted `line_count` entries
  reconciled (scoped to this extension only).

## Decisions

- Pinned Phase 5's figures (README.md's line count, known-gap-register.md's date/SHA) to the
  research-cited commit `a07ae5f` rather than the consuming repository's advancing live HEAD, to
  keep the 2/15/1 census and the slim-index line count internally consistent and because the
  plan's own Non-Goals forbid corpus-wide re-measurement.
- Pinned Phase 6's `convention_version` to the genuinely live value (`0.1.0-pre` at `d255518`)
  rather than the research-time "unversioned" finding, after discovering the consuming
  repository had, between research and implementation, landed its own Decision 19 ("Convention
  versioning and lockstep") specifying this exact mechanism — pinning a value already known
  false on day one would have defeated the comparison's purpose.
- Scoped `generate-context-line-counts.sh --write` to the books extension only via an `EXT_DIR`
  override (a temp directory symlinking just `agent-system/extensions/books`), since the script
  has no built-in per-extension flag and running it unscoped would have touched every other
  extension's `index-entries.json`.

## Plan Deviations

- None (implementation followed plan). Two design choices decided during implementation
  (the `a07ae5f` figure anchor and the live `convention_version` value) are documented above as
  Decisions, not deviations: the plan explicitly left the convention_version value to be "read
  from the record" at implementation time, and the figure-anchor choice applies the plan's own
  "do not touch the 2/15/1 census" instruction consistently rather than contradicting it.

## Verification

- Build: N/A (no compiled artifact)
- Tests: Passed — `test-books-observe.sh` (59/0), `test-books-gate.sh` (44/0),
  `test-books-certify.sh` (9/0); the whole-repo `tests/run-all.sh` (116 suites) separately
  confirms all three books suites PASS
- `check-extension-docs.sh`: books extension PASS (Rule R included); whole-repo exit is nonzero
  only from pre-existing core/lean/email/nix/nvim drift unrelated to this task
- `verify-deploy.sh`: same pre-existing-drift caveat as above
- `check-task-references.sh`: PASS, 0 occurrences
- `git status --short -- .claude/`: empty
- Files verified: Yes

## Impacts

- The observer now resolves `Validated by` promotions correctly against the consuming
  repository's actual (split) record shape, across all three governed records, including the
  fault-frame heading grammar it previously mis-read.
- The `/books --revise` and `/books --review` sub-modes no longer silently drop every candidate
  bearing a decision the old flat-file-only research step could not quote.
- A `convention_version` pin now exists for future staleness detection, genuinely in sync with
  the consuming repository's live Decision 19 mechanism.

## Follow-ups

- The consuming repository's live HEAD had already advanced to 19 decisions (adding Decision 19
  itself) by the time of this implementation; a future task should re-verify the known-gap-register
  census once the corpus is next refreshed, since it is anchored to `a07ae5f` (18 decisions,
  2/15/1) and will need updating when this task's own figures are next touched.
- `known-gap-register.md:17`'s "docs/book-convention.md carries one marker per decision" sentence
  is now imprecise (the flat index carries zero remaining decision markers in the reference
  consuming repository) but was left untouched as outside this task's explicitly scoped task list
  for that file.

## References

- `specs/340_retarget_books_extension_split_convention_record/plans/02_split-retarget-and-version-pin.md`
- `specs/340_retarget_books_extension_split_convention_record/reports/01_seed-books-extension-split-retarget.md`
- `specs/340_retarget_books_extension_split_convention_record/reports/02_split-retarget-grammar-and-anchors.md`
- `specs/340_retarget_books_extension_split_convention_record/issues.jsonl`
