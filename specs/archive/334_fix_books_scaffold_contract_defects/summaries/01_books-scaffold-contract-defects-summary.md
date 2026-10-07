# Implementation Summary: Task #334

- **Task**: 334 - Fix two books-extension scaffold contract defects: the hard implementation
  agent's artifacts shape and hand-rolled task lookups in both hard skills
- **Status**: [COMPLETED]
- **Started**: 2026-10-03T22:08:15Z
- **Completed**: 2026-10-03T22:42:12Z
- **Effort**: ~0.75 hours
- **Dependencies**: None
- **Artifacts**: plans/01_books-scaffold-contract-defects.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Fixed both standing lint failures in the books extension scaffold: the hard implementation
agent's missing object-shaped `artifacts`/terminal-`status` template, and the hand-rolled
full-record task lookup in both hard SKILL.md files. Also discharged the task's broader mandate
-- ruling on why a completion postflight cleared a task carrying two standing lint failures --
by naming `verify-deploy.sh` as the concrete command that satisfies `plan-format.md`'s `full`
verification tier, closing the ambiguity that let two independent plans narrow "full" to
self-chosen validator subsets.

## What Changed

- `agent-system/extensions/books/agents/books-implementation-hard-agent.md` -- Stage 7 now
  carries the literal fenced JSON `artifacts`/`status` template copied from the passing sibling
  `books-implementation-agent.md`, with the hard agent's own three-value status vocabulary note
  kept.
- `agent-system/extensions/books/skills/skill-books-implementation-hard/SKILL.md` -- Stage 1's
  hand-rolled `'.active_projects[] | select(.project_number == $num)'` jq lookup replaced with
  `source .claude/scripts/skill-base.sh` + `skill_validate_input`, matching the
  `skill-web-implementation` canonical pattern. Dead not-found/terminal-state branches removed.
- `agent-system/extensions/books/skills/skill-books-research-hard/SKILL.md` -- same replacement
  applied. This file's prior hand-rolled lookup had no terminal-state check at all;
  `skill_validate_input` adds one as an intentional tightening (recorded in the commit message,
  not an accidental behavior change).
- `agent-system/extensions/core/context/formats/plan-format.md` -- the `## Verification Tiers`
  table's `full` row now names `bash .claude/scripts/verify-deploy.sh` explicitly; a new
  paragraph binds a `full` declaration to that command (or its aggregated gate set); the
  `### Enforcement level` subsection records the not-yet-built content check (does a `full`
  phase's own task list actually reach a full-gate invocation?) as a named future item.
- `agent-system/extensions/core/index-entries.json` -- corrected the `formats/plan-format.md`
  entry's `line_count` (591 -> 599) to track the file's own line additions from the edit above.

## Decisions

- Discharged the general defect via remedy (b) -- naming `verify-deploy.sh` as the `full` tier's
  concrete command -- not remedy (a), a new plan-file content lint. (a) is recorded as a named
  future item rather than built now; see the plan's own Decisions section for the full rationale.
- Used `skill_validate_input` (skill-layer convention), not `gate_in` (command-layer), matching
  `skill-web-implementation` and `skill-spawn`.
- Replaced the Stage 1 fence rather than deleting it, to keep an explicit local validation step
  next to each hard skill's own Stage 1.5 hard-mode work, matching the `skill-web-*` pattern.
- No allowlist entry added to `lint-task-lookup-adoption.sh`'s `EXCLUDED_FILES`: that list is a
  shrinking, individually-reasoned exception register for pending migrations, not a precedent
  for new entries.
- No redeploy phase: both target lints resolve the repository root and scan
  `agent-system/extensions` directly, so the source-store fix sufficed for both named gates.
  (This Non-Goal interacts with Phase 5's findings -- see Plan Deviations below.)

## Plan Deviations

- **Phase 5's verification expectation** ("`verify-deploy.sh --skip-slow` fully green, 33 of
  33") was not met as literally stated; the phase closed `[COMPLETED WITH EXCLUSIONS]` instead
  of `[COMPLETED]`, with a full Reasoned Exclusions record in the plan. This is not a deviation
  in the edits made -- all four planned files were edited exactly as specified in Phases 1-4 --
  but a deviation in the phase's closing marker, driven by two observations the plan's Scope
  Hypothesis did not anticipate:
  1. This task's own Phase 4 edit to `plan-format.md` necessarily left the deployed
     `.claude/context/formats/plan-format.md` copy stale (content-differs-from-source), because
     the plan's own Non-Goals explicitly bar a redeploy phase. This is expected, documented
     staleness under `source-store-deploy-boundary.md`, not a new defect.
  2. Concurrently-dispatched sibling task 285 landed its own phases 1-2
     (commits `2cacb40ff`, `c763a6f83`) on this shared tree during this same cycle, adding
     `scripts/orchestrate-record-decision.sh` and touching
     `scripts/lib/runtime-file-patterns.sh` / `context/standards/orchestrator-runtime-files.md`
     -- also not yet redeployed. Confirmed via `git log` and `git status --porcelain` (its
     `manifest.json` edit is uncommitted-in-flight) before classifying, per the territory
     contract; none of these paths are in this task's "Files to modify" lists, so they were
     reported, not fixed.
  - Both named gates this task exists to fix (6: agent-contracts lint, 18: task-lookup-adoption
    lint) are fully clean. The two newly-observed `verify-deploy.sh` FAILs (gates 3 and 5) are
    fully attributed and recorded as Reasoned Exclusions in the plan's Phase 5 section, with
    `git log`/`git status` evidence per row.

## Verification

- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose`: 195
  passed, 0 failed (was 2 FAILs, both on `books-implementation-hard-agent.md`) -- PASS.
- `bash agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh --verbose`: 0
  violations (was 2, one per hard SKILL.md) -- PASS.
- `bash .claude/scripts/verify-deploy.sh --skip-slow`: FAIL 2 of 33 (gates 3 doc-lint and 5
  manifest-driven verify.lua; both fully attributed to deploy-tree staleness -- this task's own
  Non-Goal-protected `plan-format.md` edit, plus concurrent sibling task 285's in-flight,
  not-yet-redeployed edits). Gates 6 and 18 -- this task's own target gates -- both PASS.
- `bash .claude/scripts/check-task-references.sh --quiet`: PASS, 0 unexempted occurrences.
- `grep -rn 'active_projects\[\] | select' agent-system/extensions/books/`: no matches.
- Every edited path begins with `agent-system/extensions/`; nothing hand-authored under
  `.claude/**`.

## Impacts

- `books-implementation-hard-agent.md` dispatches will now write a metadata file that passes
  both Check E (terminal status) and Check F (object-shaped artifacts) of
  `lint-agent-contracts.sh`.
- Both books hard skills now route task lookups through `skill_validate_input`, inheriting its
  terminal-state exit and matching the codebase-wide convention; `skill-books-research-hard`
  gains a terminal-state check it previously lacked.
- Any future plan phase declaring `**Verification Tier**: full` now has an unambiguous concrete
  command (`verify-deploy.sh`) to cite, closing the mechanism that let a `full`-tier phase's
  task list silently narrow to a self-chosen validator subset.

## Follow-ups

- Build the plan-file content lint (recorded as a future item in `plan-format.md`'s
  `### Enforcement level` subsection and in this task's plan Decisions): flag a `full`-tier
  phase whose own task list never reaches a full-gate invocation. Deliberately not built here --
  it would immediately flag historical, already-`[COMPLETED]` plans and needs its own
  research/scoping.
- Once sibling task 285 completes and the tree is redeployed, re-run
  `bash .claude/scripts/verify-deploy.sh --skip-slow` to confirm the deploy-drift FAILs (gates 3
  and 5) clear on their own, with no further action from this task.

## References

- Plan: `specs/334_fix_books_scaffold_contract_defects/plans/01_books-scaffold-contract-defects.md`
- Research: `specs/334_fix_books_scaffold_contract_defects/reports/01_books-scaffold-contract-defects.md`
- Handoff: `specs/334_fix_books_scaffold_contract_defects/handoffs/phase-4-handoff-20261003T223502Z.md`
