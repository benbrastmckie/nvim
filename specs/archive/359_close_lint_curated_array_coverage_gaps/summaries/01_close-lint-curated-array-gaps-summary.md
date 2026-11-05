# Implementation Summary: Close lint curated array coverage gaps

- **Task**: 359 - Close lint curated array coverage gaps
- **Status**: [COMPLETED]
- **Started**: 2026-10-17T09:52:30Z
- **Completed**: 2026-10-17T13:30:00Z
- **Effort**: ~4 hours
- **Dependencies**: None
- **Artifacts**: plans/01_close-lint-curated-array-gaps.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`lint-agent-contracts.sh` asserted contract-bullet coverage against hand-curated path arrays
with two measured drifts: the two books implementation agents were absent from Check C's and
Check G's arrays, and no research agent carried the bounded-wait bullet pair Check H enforces
for implementation agents. This task normalized the books files' bullet text before registering
them, propagated the bounded-wait pair to the measured 11-of-23 exposed research-agent subset
behind a new Check M, added a completeness-net check (Check N) so the next drift fails the lint
instead of waiting to be discovered by measurement, and extended the test suite to pin all of it.
The lint exits 0, four deliberate-removal demonstrations each FAIL by name and restore to exit 0,
the extended test suite is green (61 assertions, up from 37), shellcheck is clean, and the
source store is redeployed.

## What Changed

- `agent-system/extensions/core/context/contracts/no-task-references-bullet.md` — added the
  single-physical-line instruction; added `books` to the extension and placement-example
  enumerations.
- `agent-system/extensions/core/context/contracts/plan-status-ownership.md` — added the
  single-physical-line instruction; In-Scope Enumeration 14 -> 16 files, with the two books
  files' addition recorded alongside the prior `founder-implement-agent.md` sweep-result note.
- `agent-system/extensions/books/agents/books-implementation-agent.md` — unwrapped and
  byte-normalized the Check C MUST NOT bullet (also dropped two extraneous backtick pairs
  discovered during normalization, not just the wrap); moved the Check G bullet out of MUST DO
  into MUST NOT with the same normalization; renumbered the MUST NOT list into one continuous
  sequence (the pre-existing restart at "9." after item 12 is now fixed as a byproduct).
- `agent-system/extensions/books/agents/books-implementation-hard-agent.md` — replaced the
  abbreviated Check C paraphrase with the canonical sentence; added a new MUST NOT item
  carrying the Check G bullet (previously wholly absent).
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` — new
  "Research-Agent Bounded-Wait Scope (Measured)" section recording the 11-file in-scope set
  with per-file evidence and the 12-file exclusion set with per-file reasons; the "Item 4
  Ruling" subsection amended with a pointer to it (original reasoning preserved).
- 10 research agents (`books-research-agent.md`, `books-research-hard-agent.md`,
  `cslib-research-agent.md`, `cslib-research-hard-agent.md`, `nix-research-agent.md`,
  `neovim-research-agent.md`, `web-research-agent.md`, `python-research-agent.md`,
  `rust-research-agent.md`, `z3-research-agent.md`) — appended the bounded-wait MUST/MUST NOT
  bullet pair as the next sequential item in each existing Critical Requirements list.
- `core/agents/general-research-agent.md` — added a new "Local Wait Discipline" subsection
  alongside the existing remote-wait section, carrying the same bullet pair.
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` — registered both books
  paths in `IN_SCOPE_RELATIVE_PATHS` (Check C) and `OWNERSHIP_IN_SCOPE_RELATIVE_PATHS` (Check G);
  added both books files to `HEARTBEAT_ADOPTION_MIGRATION_INVENTORY_DATED_20261008` (an
  incidental Check I ripple from the Check G expansion, resolved as a WARN not a FAIL); added
  `BOUNDED_WAIT_RESEARCH_IN_SCOPE_RELATIVE_PATHS` (11 entries) and
  `check_m_bounded_wait_research_contract_bullet` (Check M), wired into `main()` after Check L;
  added `CHECK_G_EXCLUDED_RELATIVE_PATHS` (3 entries, promoted from fragment prose) and
  `CHECK_M_EXCLUDED_RELATIVE_PATHS` (12 entries) plus `check_n_curated_array_completeness`
  (Check N, three glob-based nets), wired into `main()` after Check M.
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` — 24 new assertions
  (61 total, up from 37): Check M missing-bullet/near-miss fixtures, two line-wrap pinning
  fixtures (Check C and Check G, each wrapped), Check N positive/negative fixtures, books PASS
  fixtures for Check C/G, and explicit not-found coverage for the 9 remaining Phase-4-registered
  research-agent paths without a dedicated fixture.
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts-heartbeat.sh` — fixed an
  unplanned ripple from the Check G array expansion: its own hardcoded 14-entry mirror of
  `OWNERSHIP_IN_SCOPE_RELATIVE_PATHS` was updated to 16 entries and its WARN-count assertions
  updated (13->15, 12->14). Committed outside this task's declared `file_scope` (a real,
  necessary fix for a ripple this task's own in-scope edits caused).

## Decisions

- **Line-wrap ruling: hold bullets unwrapped by convention, not lint-side whitespace
  normalization.** `no-task-references-bullet.md` and `plan-status-ownership.md` now state the
  single-physical-line requirement explicitly (mirroring `bounded-build-waiter.md`'s existing
  wording), and two dedicated fixtures pin a correctly-worded-but-wrapped bullet as a FAIL,
  proving the convention is enforced, not merely documented. Rationale: whitespace-normalizing
  `grep -qF` would require either collapsing text before matching or switching to a multi-line-
  aware regex, either of which widens matching semantics for every existing caller of Checks
  C/G/H/M, not just this one historical wrap.
- **Curated-array mechanism: kept, with a completeness net added (Check N).** The research
  report's sweep showed curation is doing real work a filename glob cannot do (several
  founder/present agents write non-markdown artifacts that stay inside `specs/**` and are
  correctly excluded only by reading each file). What was missing was not derivation but
  coverage auditing — Check N enumerates the relevant glob subset and asserts every match is in
  an in-scope array or a recorded exclusion, so the next drift FAILs the lint instead of waiting
  to be discovered by measurement, as both of this task's own starting gaps were.
- **The research-agent bounded-wait subset is 11 of 23, not all 23** — determined by a per-file
  tool-grant read plus a full-file build-command grep, independently re-derived during
  implementation and confirmed to match the research report's split exactly. The 2 Lean research
  agents keep their separate, sanctioned bounded single-call idiom
  (`context/project/lean4/operations/long-builds.md`) untouched; the remaining 10 exclusions
  each carry their own inline reason (narrowly non-build-shaped grant, or unrealized boilerplate
  never exercised anywhere in the file).

## Plan Deviations

- None (implementation followed plan). Two incidental ripples from this task's own in-scope
  edits were discovered and fixed during implementation (the Check I heartbeat-inventory
  expansion in Phase 1, and the `test-lint-agent-contracts-heartbeat.sh` fixture-mirror drift in
  Phase 4) — both recorded in the issue log and in each phase's own checklist annotations, but
  neither changes what the plan asked for; they are consequences of doing it correctly, not
  departures from it.

## Impacts

- A future books-family agent addition, or a future implementation/research agent addition
  anywhere, now has a structural backstop: Check N fails the lint by name if it is accounted for
  nowhere, rather than relying on the next person to notice by manual measurement.
- The single-physical-line convention is now stated in all three contract fragments
  (`no-task-references-bullet.md`, `plan-status-ownership.md`, `bounded-build-waiter.md`) and
  pinned by fixtures, closing the asymmetry that let the original books-file wrap slip through
  undetected.
- 11 research agents now carry the same local bounded-wait discipline already required of every
  implementation agent, closing a partial-coverage gap the original bounded-wait propagation
  task explicitly deferred as a follow-up.

## Follow-ups

- `literature/agents/literature-agent.md` remains a deliberately deferred Check C edge case
  (writes markdown summaries into the global `~/Projects/Literature/` corpus, outside this
  repository entirely) — flagged by the research report, not folded into this task's measured
  scope, and still open for a future deliberate classification decision.
- None else outstanding; the sweep below found no further absentees.

## Check C / Check G Absentee Sweep Result

A glob-based cross-check of every `*implementation*agent.md` file in the source store against
both the (now-expanded) `IN_SCOPE_RELATIVE_PATHS` and `OWNERSHIP_IN_SCOPE_RELATIVE_PATHS` arrays
found **zero further absentees** for either check — every file matching the glob is accounted
for, corroborating the research report's broader 77-file predicate sweep. The one flagged,
not-recommended-for-action edge case is `literature/agents/literature-agent.md` (see Follow-ups).

## Deliberate-Removal Demonstration Outcomes

All four demonstrations were run against the real repository tree, confirmed to FAIL by the
named file, then restored byte-for-byte and confirmed to return the lint to exit 0:

| Demonstration | Check | File | Before | After strip | After restore |
|---|---|---|---|---|---|
| A | C | `books/agents/books-implementation-hard-agent.md` | exit 0 | exit 1, FAILs by name | exit 0, zero residual diff |
| B | G | `books/agents/books-implementation-agent.md` | exit 0 | exit 1, FAILs by name | exit 0, zero residual diff |
| C | M | `nix/agents/nix-research-agent.md` | exit 0 | exit 1, FAILs by name | exit 0, zero residual diff |
| D | N | throwaway `core/agents/demonstration-d-throwaway-research-agent.md` | n/a (file did not exist) | exit 1, FAILs by name | exit 0 after deletion |

The Lean sanctioned build-guard path was confirmed unbroken throughout: both Lean research
agents still route through the bounded single-call idiom
(`context/project/lean4/operations/long-builds.md`), are absent from Check M's in-scope array,
and are present in its exclusion array with their reason.

## Verification

- Build: N/A (no compiled artifacts)
- Tests: Passed — `test-lint-agent-contracts.sh` (61 assertions, 0 failed), plus
  `test-lint-agent-contracts-await-notification.sh`, `test-lint-agent-contracts-handoff-section.sh`,
  and `test-lint-agent-contracts-heartbeat.sh`, all green under `run-all.sh --only`.
- Files verified: Yes — `lint-agent-contracts.sh --verbose` exits 0 (420 passed, 15 warnings, 0
  failed); `lint-shellcheck.sh --verbose` exits 0 (398 files, 0 findings); `check-task-references.sh`
  clean on `agent-system/extensions`.

## References

- Plan: `specs/359_close_lint_curated_array_coverage_gaps/plans/01_close-lint-curated-array-gaps.md`
- Research report: `specs/359_close_lint_curated_array_coverage_gaps/reports/01_lint-array-coverage-gaps.md`
- Lint script: `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh`
- Test suite: `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh`
- Fragment: `agent-system/extensions/core/context/patterns/bounded-build-waiter.md`
- Phase handoffs: `specs/359_close_lint_curated_array_coverage_gaps/handoffs/`
