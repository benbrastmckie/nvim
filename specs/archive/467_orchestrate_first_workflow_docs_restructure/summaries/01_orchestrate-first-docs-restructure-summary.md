# Implementation Summary: Task #467

- **Task**: 467 - Restructure the user-facing agent system workflow documentation around an orchestrate-first spine
- **Status**: [COMPLETED]
- **Started**: 2026-11-04
- **Completed**: 2026-11-04
- **Effort**: ~2.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_orchestrate-first-docs-restructure.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, documentation-policy.md, no-task-references-in-deliverables.md, no-record-versioning-in-deliverables.md

## Overview

Five source-store documentation files were rewritten so the user-facing workflow documentation
teaches the command surface that actually exists: `/task` -> `/orchestrate` -> `/todo`, with
`/orchestrate`'s `--research`/`--plan`/`--implement` forcing flags carrying the stepwise
human-in-the-loop review path the removed `/research`/`/plan`/`/implement` command sections used
to serve. All six plan phases closed; the source store was redeployed via `deploy-headless.sh`.

## What Changed

- `agent-system/extensions/README.md` — added 4 missing "Available Extensions" table rows
  (books, cslib, email, literature), bringing the table to 21 rows matching the enumerated
  extension directory set exactly.
- `agent-system/extensions/core/docs/guides/user-guide.md` — rewrote the Quick Start cycle
  around `/task` -> `/orchestrate N` -> `/todo`; added a second, explicit stepwise walkthrough
  (`/orchestrate N --research` -> `/orchestrate N --plan` -> `/revise N` ->
  `/orchestrate N --implement` -> `/todo`); retargeted the former `/research`/`/plan`/
  `/implement` command subsections' explanatory content into `/orchestrate`'s forcing-flag
  coverage; rewrote the Status Progression table, Command Summary Table, Status Transitions
  diagram, and Language Routing table; gave `/orchestrate` full-surface treatment (batch syntax,
  all 16 Options-table flags, `[HOLD]`/`[PR READY]` semantics, cycle budgets, resumption
  behavior); added `/project-overview`, `/please`, and `/zulip` command subsections; added a
  top-level `## Extensions` section linking to the extension catalog.
- `agent-system/extensions/core/docs/guides/user-installation.md` — replaced the stale
  "Structured Workflow" bullet and Available Commands table with the `/orchestrate`-driven spine;
  fixed a broken `Commands Reference` link (wrong relative depth) in both its occurrences.
- `agent-system/extensions/core/docs/docs-README.md` — added an `### Extensions` entry linking to
  the extension catalog and naming the `<leader>ac`/`<leader>ao` load bindings; corrected a
  pre-existing mislabeled link in `### Project Documentation` that pointed at the wrong target;
  tightened the `## Examples` description of `research-flow-example.md`.
- `agent-system/extensions/core/docs/examples/research-flow-example.md` — stripped 4
  record-versioning spans (opening paragraph, a "used to carry here" clause, a closing
  attribution aside, and the `Document Version: 3.0` footer), leaving the
  `/orchestrate {N} --research` walkthrough content untouched.

## Decisions

- The plan's literal three-command stepwise walkthrough (`--research` -> `/revise N` ->
  `--implement`) omits a necessary plan-creation step; inserted an explicit
  `/orchestrate N --plan` between them so the walkthrough is actually executable (`--implement`
  requires an existing plan artifact; `/revise` on a plan-less task only updates the description).
- Fixed two genuinely broken relative links encountered directly while doing each phase's own
  scoped work (`user-installation.md`'s Commands Reference link; `docs-README.md`'s
  Project Documentation link, which would have duplicated the newly-added Extensions entry's
  target). Left untouched: a separate, pre-existing, out-of-scope nav-bar link pattern in
  `user-guide.md`/`user-installation.md` that predates this task.
- Closed the final phase `[COMPLETED WITH EXCLUSIONS]` for two reasoned, evidenced exclusions
  (the pre-existing nav-bar links above, and an unrelated `verify-deploy.sh` gate-18 failure in a
  test fixture file last touched by an unrelated prior task) — both pass the five-condition
  admission test and leave no residual work for this task.

## Plan Deviations

- **Task 2.3** altered: inserted an explicit `/orchestrate N --plan` step into the stepwise
  walkthrough (see Decisions above).
- **Task 4.3** altered: fixed the Commands Reference link's relative depth in
  `user-installation.md` (it was genuinely broken, one level too shallow).
- **Task 4.5** altered: corrected `docs-README.md`'s pre-existing "Project Documentation" link to
  the true project root, to avoid a duplicate-target conflict with the newly-added Extensions
  entry.
- **Phase 6** closed `[COMPLETED WITH EXCLUSIONS]`: 12 pre-existing broken nav-bar links and one
  unrelated `verify-deploy.sh` gate-18 failure — see the plan's Phase 6 Reasoned Exclusions table
  for the full evidenced record.

## Verification

- Build: N/A (documentation-only task)
- Tests: `lint-dead-command-recommendations.sh` green across the whole corpus;
  `run-all.sh --only test-lint-dead-command-recommendations.sh` and
  `verify-deploy.sh --only-gate 3` both green (scoped discharge per this dispatch's Batch Gate
  Deferral directive); full gate set ran once via `deploy-headless.sh` and reported one
  unrelated failure (excluded, see above).
- Files verified: Yes — all 5 edited files confirmed on disk; 4 of 5 deployed copies
  byte-for-byte match the source store (the 5th, the extension catalog, has no deployed
  counterpart by design).

## Impacts

- A reader following `user-guide.md`'s Quick Start, or either walkthrough, can now execute every
  command named — none of the three removed commands (`/research`, `/plan`, `/implement`) are
  presented as invocable anywhere in the touched corpus.
- The extension catalog is now discoverable from both `user-guide.md` and `docs-README.md`, and
  its own table matches reality.
- `/project-overview`, `/please`, and `/zulip` are now documented in the user-facing guide.

## Follow-ups

- Recorded via `issue-record.sh` (not filed as tasks, per this task's scope): the pre-existing
  nav-bar link defects in `user-guide.md`/`user-installation.md`; the unrelated gate-18 failure
  in `test-state-write-concurrency.sh`; the stale `/plan`/`/implement` wording still present in
  `agent-system/extensions/core/commands/project-overview.md` (a command definition file outside
  this task's five-file scope); and a recommendation for a future
  `lint-extension-readme-table.sh` to mechanically check the extension catalog table against the
  real directory set (explicitly a Non-Goal of this task, not built here).

## References

- Plan: `specs/467_orchestrate_first_workflow_docs_restructure/plans/01_orchestrate-first-docs-restructure.md`
- Research report: `specs/467_orchestrate_first_workflow_docs_restructure/reports/01_orchestrate-first-docs-restructure.md`
- Progress files: `specs/467_orchestrate_first_workflow_docs_restructure/progress/phase-{1..6}-progress.json`
- Handoffs: `specs/467_orchestrate_first_workflow_docs_restructure/handoffs/phase-{1..6}-handoff-*.md`
