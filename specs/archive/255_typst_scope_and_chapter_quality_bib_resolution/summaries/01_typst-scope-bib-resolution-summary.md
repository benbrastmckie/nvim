# Implementation Summary: Task #255

- **Task**: 255 - Reconcile typst extension scope ownership and fix chapter-quality-check.sh Rule 1.3 bib resolution
- **Status**: [COMPLETED]
- **Started**: 2026-09-29T00:00:00Z
- **Completed**: 2026-09-29T01:35:00Z
- **Effort**: ~1.75 hours
- **Dependencies**: None
- **Artifacts**: plans/01_typst-scope-bib-resolution.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md

## Overview

Fixed two consecutive defects that jointly disabled the typst extension's chapter-quality
machinery: (1) `EXTENSION.md`'s declared Scope and `manifest.json`'s `keyword_overrides`
misrouted chapter/manual-prose work to `general`, so the typst agents that run the chapter-quality
gate were never dispatched; (2) `chapter-quality-check.sh`'s BLOCKING Rule 1.3 (citation keys
resolve in the `.bib`) silently went unevaluated for the two commonest real-world layouts — a
multi-file manual whose root document alone declares the bibliography, and any repo carrying a
vendored `.bib`. All four phases landed as three separate source-store commits
(`agent-system/extensions/typst/`), each independently green.

## What Changed

- `agent-system/extensions/typst/EXTENSION.md` — rewrote the `### Scope` section: typst now
  explicitly owns "the presentation quality of existing document content" (chapter/manual prose
  review, condensing, the chapter-quality gate), while originating/verifying new mathematical
  content stays with `lean4`/`formal`/`general`. Aligned with the `**Scope note**` already carried
  verbatim by `textbook-standards.md` and `type-theory-foundations.md`.
- `agent-system/extensions/typst/manifest.json` — extended `keyword_overrides.typst.keywords` from
  8 to 13 entries, adding `"typst chapter"`, `"typst chapters"`, `"typst manual"`,
  `"chapter quality"`, `"chapter prose"` (verified against no collision with `cslib`/`email`/
  `latex`/`rust`'s own keyword sets).
- `agent-system/extensions/typst/scripts/chapter-quality-check.sh` — `resolve_bibliography` now
  tries three branches in order: (a) declared path in the checked file (unchanged), (b) **new**
  nearest-ancestor `#bibliography("...")` declaration walked up to the repo root, with a
  permissive extractor that matches multi-argument declarations, (c) single `*.bib` candidate
  under root with `.lake`/`.git`/`node_modules`/`target`/`build` pruned from the search (was
  branch (b), now hardened). Added a `RULE_SEVERITY` map, a severity-aware `emit_not_evaluated`
  ([WARN] + `TOTAL_BLOCKING_SKIPPED` counter for a skipped BLOCKING rule), a qualified PASSED
  banner, and a Summary "Skipped:" line. Header contract (bibliography-resolution bullet, new
  NOT-EVALUATED SURFACING bullet) updated in the same commits as the corresponding code.
- `agent-system/extensions/typst/scripts/tests/test-chapter-quality-check.sh` — added case-l
  (ancestor bib, multi-arg, positive), case-l-neg (negative twin), case-m (vendored-`.bib`
  exclusion), case-n (qualified banner), case-o (ADVISORY-only unqualified banner), an explicit
  `dirscan` NOT-EVALUATED assertion for `nested/violation.typ`, and a disposition comment on
  case-f (re-examined, left unmodified). Suite grew from 59 to 83 passed, 0 failed throughout.

## Decisions

- The `typst`/`lean4`/`formal`/`general` boundary is: typst owns presentation and measurable
  quality of prose/chapters (including theorem *presentation*); originating or mathematically
  verifying new content routes elsewhere. This matches the `**Scope note**` two context files
  already carried, rather than inventing a new boundary.
- Kept branch (a) (declared path in the checked file) and its `filedir` fallback completely
  unmodified, per the task's explicit constraint — the new ancestor branch (b) is inserted
  strictly between (a) and the (now-hardened) single-candidate branch (c).
- Branch (b)'s ancestor walk uses a *permissive* extractor (no required closing paren) distinct
  from branch (a)'s narrow one, so a multi-argument `#bibliography(...)` call — the real shape
  found in Logos/Verification's root document — resolves without loosening branch (a)'s contract.
- A NOT EVALUATED BLOCKING rule now prints at `[WARN]` and qualifies the PASSED banner; the exit
  code stays 0 in every case. This was a deliberate visibility-only change, argued in the header:
  the never-fail-on-unresolved-bibliography posture is preserved, but a reader who only checks the
  last output line is no longer misled.
- `RULE_SEVERITY` is a declared lookup table (not a hardcoded check at the `1.3` call site), so any
  future BLOCKING rule that can go NOT EVALUATED wires into the loud-surfacing behavior
  automatically.

## Plan Deviations

- The plan's "Add a KNOWN LIMITATIONS bullet" task item (Phase 2) was folded into the rewritten
  bibliography-resolution bullet itself rather than added as a separate header bullet, since it is
  a qualifier on that same contract rather than an independent limitation.
- No other deviations. All four phases executed as planned, in the planned order, with the planned
  file scope.

## Verification

- Build: N/A (bash scripts, no build step)
- Tests: Passed — `test-chapter-quality-check.sh` grew from a 59-passed/0-failed baseline to
  83 passed, 0 failed (case-a and case-e, the declared-path-branch cases, unchanged throughout)
- Files verified: Yes

## ACCEPTANCE Table

| # | Item | Evidence |
|---|------|----------|
| 1 | `EXTENSION.md`'s Scope consistent with every file under `context/project/typst/` | Read all five files (`chapter-quality.md`, `textbook-standards.md`, `type-theory-foundations.md`, `theorem-environments.md`, `chapter-template.md`); rewritten Scope wording aligns with the `**Scope note**` already carried by the first two, and disclaims none of the five |
| 2 | `"review and condense the typst manual chapters"` self-detects as `typst` | Ran `detect_task_type` directly (sourced `task-type-detect.sh`): returned `typst` (was `general` pre-fix); confirmed again in Phase 4 regression |
| 3 | No added keyword hijacks another extension | Audited `cslib`/`email`/`latex`/`rust` `keyword_overrides` sets — none of the 5 new phrases present in any |
| 4 | Rule 1.3 evaluates for an `#include`d chapter whose root document declares the bibliography | Live run against `/home/benjamin/Projects/Logos/Verification/typst/manual/chapters/01-introduction.typ`: output changed from `Rule 1.3 NOT EVALUATED` to `Rule 1.3 evaluated against .../bibliography.bib`, resolved via the new ancestor-walk branch (b) against `LogosVerificationManual.typ`'s multi-argument declaration |
| 5 | Rule 1.3 evaluates despite a vendored `.bib` under `.lake/` | Confirmed the vendored `.lake/packages/mathlib/docs/references.bib` still exists in that exact repo; unfiltered `find` returns 2 `.bib` candidates, the new pruned `find` returns exactly 1 (the real one) — demonstrated directly against this repo's file layout |
| 6 | `test-chapter-quality-check.sh` green, case-f disposition recorded | 83 passed, 0 failed; case-f re-examined and left unmodified with an explanatory disposition comment (genuinely bib-less, non-git, `root == filedir`, zero ancestor range) |
| 7 | Header lines match implemented resolution contract | Bibliography-resolution bullet rewritten to name all three branches in order and all five excluded directory patterns; NOT-EVALUATED SURFACING bullet added documenting the `[WARN]`/banner-qualifier behavior |
| 8 | No test weakened or deleted | case-a, case-e, case-f, and all pre-existing cases retain their original assertions unchanged; only new cases and one new assertion (on the pre-existing `dirscan` case) were added |

## Impacts

- Chapter/manual-quality tasks now route to the correct agents and gates instead of falling
  through to `general`.
- The chapter-quality gate's BLOCKING Rule 1.3 now actually fires in the two most common
  real-world layouts, closing a gap where a "PASSED" banner was previously misleading.

## Follow-ups

- Updating `context/project/typst/README.md`'s load lists to mention `chapter-quality.md` was
  identified by research as a good follow-up but is outside this task's declared `file_scope`
  (explicit Non-Goal in the plan).
- Deployment to `.claude/` in this repo and the 5 consumer repos (Logos/Verification,
  Logos/ModelChecker, BimodalLogic, SPSDemo) is a separate, user-driven regeneration step; none of
  it was performed here, per the source-store-deploy-boundary rule.
- `scripts/typst-element-lint.sh` and `index-entries.json` carry pre-existing, unrelated
  uncommitted modifications from before this task started; they were deliberately left untouched
  and uncommitted throughout.

## References

- `specs/255_typst_scope_and_chapter_quality_bib_resolution/plans/01_typst-scope-bib-resolution.md`
- `specs/255_typst_scope_and_chapter_quality_bib_resolution/reports/01_typst-scope-bib-resolution.md`
- `specs/255_typst_scope_and_chapter_quality_bib_resolution/progress/phase-1-progress.json` through `phase-4-progress.json`
- Commits: `0fe3dd883` (phase 1), `65a3fc11b` (phase 2), `48a73ce02` (phase 3)
