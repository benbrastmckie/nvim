# Implementation Summary: Task #372

- **Task**: 372 - Add the conclusion stage missing report block and name its roadmap-generator caller
- **Status**: [COMPLETED]
- **Started**: 2026-10-08T22:52:03Z
- **Completed**: 2026-10-11T00:00:00Z
- **Effort**: 1.75 hours (plan estimate; actual spanned two dispatches due to a sibling-task redeploy collision)
- **Dependencies**: None (parallel-eligible with task 371; no dependencies[] edge)
- **Artifacts**: plans/01_conclusion-report-block-caller-split.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closed the one real gap this task carried (the roadmap generator's caller contract omitted
`/orchestrate`'s conclusion stage as a `--regenerate` caller) by editing four prose files in the
source store, redeploying, and running the full gate set. GAP 1 (the conclusion stage's Step 6
pointing at a missing report block) was verified already closed by prior work and required no
new diff. Phase 4 — redeploy and full verification — was blocked in a prior dispatch by sibling
task 371's live uncommitted edits; this dispatch re-confirmed that collision is resolved (task
371 is now `completed`/terminal with a clean tree), ran the redeploy, and closed the phase with
two pre-existing, out-of-scope gate failures recorded rather than fixed.

## What Changed

- `agent-system/extensions/core/context/patterns/roadmap-update.md` — named the conclusion stage
  (Move 5, Step 5) as a live caller of `--regenerate`; renamed the stale "No Live Caller Yet"
  section to "Live Callers" describing the actual split; recorded an explicit ruling that
  `/todo`→`--prune` and `/review`→`--regenerate` wiring is deliberately left open.
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` — corrected the
  `roadmap-integration.sh` entry's stale "no live caller yet" phrase to the accurate split.
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` — replaced the "Two Flags
  For the User, Not Silent Edits" section with a current-state pointer to `roadmap-update.md`;
  removed Step 5's carry-forward instruction and Step 6's now-vestigial flags clause.
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` —
  simplified the `### Conclusion` block's `**Roadmap**` line, dropping the discharged
  `{roadmap_flags}` placeholder.
- `agent-system/extensions/core/index-entries.json` — mechanical `line_count` corrections for the
  two files above whose line counts changed, produced by the sanctioned
  `generate-context-line-counts.sh --write` tool (two small follow-up commits in Phases 2 and 3).
- Deployed counterparts of all four edited files under `.claude/**` — regenerated via
  `deploy-headless.sh`; `.claude/` is gitignored in this repository, so this produces no tracked
  diff.
- No code or executable file changed; this task is pure documentation/contract prose per its own
  Non-Goals.

## Decisions

- GAP 1 was satisfied by verification with reproduced evidence (the `### Conclusion` block
  exists, covers Step 6's five items, and source/deployed copies are byte-identical) rather than
  by a new diff — per the plan's Phase 1 design, re-authoring existing, already-correct content
  was explicitly out of scope.
- The `/todo`//`review` unwired-mode question (GAP 2(b)) was closed by a recorded ruling, not by
  wiring: a mode is not wired into a command merely to make a table symmetric.
- Phase 4's redeploy was re-attempted and completed in this dispatch once the blocking collision
  (sibling task 371's live uncommitted edit) resolved on its own via 371 reaching
  `completed`/terminal status with a clean tree.
- Both gate failures surfaced by the full `verify-deploy.sh` run were investigated against
  `git log`/`git status` and confirmed pre-existing and outside this task's four-file scope, then
  closed via `[COMPLETED WITH EXCLUSIONS]` with a full Reasoned Exclusions record rather than
  "fixed" — per the dispatch's explicit instruction not to edit a sibling's or an unrelated file.

## Plan Deviations

- **Phase 4, item 2** (redeploy) altered: originally deferred in a prior dispatch by sibling task
  371's live uncommitted edit; completed in this dispatch once that collision resolved.
- **Phase 4, item 3** (run the complete gate set) altered: the phase's Verification criterion
  anticipated `verify-deploy.sh` exiting 0; the actual run reports 2 of 36 checks failed. Both
  failures are pre-existing and excluded with evidence rather than fixed (see below), so the
  phase closes `[COMPLETED WITH EXCLUSIONS]` instead of `[COMPLETED]`.

## Verification

- Build: N/A (documentation/contract prose only; no executable changed)
- Tests: `bash .claude/scripts/verify-deploy.sh` (full gate set, no `--skip-slow`) — 2 of 36
  checks failed, both pre-existing and excluded:
  - **Gate 8** (`tests/run-all.sh`): `test-verify-deploy-context-budget.sh` fails because its
    fixture runs `git init` but never `git add`, so Gate 22 discovers zero `.sh` files via
    `git ls-files` against an empty index and exits 2. Owned by sibling task 371's file scope;
    recorded as `371:iss_1791597799615_hKfFjt`. The `--skip-slow` path has no way to hit this
    gate at all, since Gate 8 is the gate `--skip-slow` defers.
  - **Gate 3** (`check-extension-docs.sh`, doc-lint): `core` FAILs with "script referenced in
    docs/skills/agents but NOT in provides.scripts: check-evidence-probes.sh". The two
    referencing comments (`skills/skill-todo/SKILL.md:550`,
    `context/patterns/task-abandon-mode.md:72`) are clean (no uncommitted edit) and last touched
    by old commits predating this task; `check-evidence-probes.sh` does not exist as a file and
    both comments describe it as a known-aspirational "WIRED_REPO form ... must be re-pointed, or
    the file promoted" reference, not a regression this task introduced. Newly observed during
    this phase (not previously documented for task 372); recorded as
    `372:iss_1791742848757_BcRCvu` with `--resolution open` and
    `--suggested-channel follow_up_task`.
- Files verified: Yes — source-store and deployed copies are byte-identical for all four scoped
  files, confirmed both before and after the redeploy via `diff -q`.

## Impacts

- `/orchestrate`'s conclusion stage, `roadmap-update.md`, `utility-scripts-inventory.md`, and
  `conclusion-stage.md` now describe a mutually consistent current state: one real caller of
  `--regenerate`, no caller of `--prune`, and no stale "no live caller" claim anywhere under
  `agent-system/**`.
- Two pre-existing gate failures remain open and tracked (not introduced or worsened by this
  task): the Gate 8 fixture gap (task 371's scope) and the new Gate 3 doc-lint finding (task 372's
  own issue log, `--suggested-channel follow_up_task`, left for a future task rather than folded
  into this one's scope).

## Follow-ups

- A follow-up task may be filed to add `check-evidence-probes.sh` to `provides.scripts` (if the
  script is promoted into a real deployed file) or to remove the two stale WIRED_REPO comments
  referencing it — tracked by `372:iss_1791742848757_BcRCvu`, `--suggested-channel follow_up_task`.
- Task 371's own fixture gap (`test-verify-deploy-context-budget.sh` missing `git add`) remains
  tracked under `371:iss_1791597799615_hKfFjt`; out of this task's scope to fix.

## References

- Plan: `specs/372_conclusion_stage_report_block_and_caller_split/plans/01_conclusion-report-block-caller-split.md`
- Report: `specs/372_conclusion_stage_report_block_and_caller_split/reports/01_conclusion-report-block-caller-split.md`
- Prior handoff: `specs/372_conclusion_stage_report_block_and_caller_split/handoffs/phase-4-handoff-20261010T010324Z.md`
- Progress: `specs/372_conclusion_stage_report_block_and_caller_split/progress/phase-4-progress.json`
