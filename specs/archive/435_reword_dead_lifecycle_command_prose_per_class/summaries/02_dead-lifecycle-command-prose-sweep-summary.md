# Implementation Summary: Task #435

- **Task**: 435 - Reword, per class and per site, the architectural and phase-versus-command prose naming the three deleted lifecycle commands, with a blanket find-and-replace explicitly forbidden
- **Status**: [COMPLETED]
- **Started**: 2026-11-07
- **Completed**: 2026-11-09
- **Effort**: ~22 hours across 15 phases and 21 dispatches
- **Dependencies**: Task 434 (companion lint, completed), Task 407 (artifact-round derivation, completed)
- **Artifacts**: plans/01_dead-lifecycle-command-prose-sweep.md, reports/01_dead-lifecycle-command-prose.md, reports/02_class-decision-collation.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Reworded 223 source-store files naming the three deleted lifecycle commands (`/implement`,
`/research`, `/plan`) across `agent-system/extensions/**` (excluding `core/docs/`, scoped out to
two dedicated documentation records), applying a per-site, per-class rubric rather than a
blanket substitution. Phase 1 reconciled the baseline and resolved the revise.md incidentals
(record-versioning language, a stale artifact-numbering claim); Phases 2-14 swept core and the
21 other extensions by directory/extension, each closing with its own commit and green
per-phase verification; Phase 15 reconciled the whole corpus, redeployed the source store, and
ran the full gate set, closing `[COMPLETED WITH EXCLUSIONS]` on three independently-confirmed
pre-existing, out-of-scope gate findings.

## What Changed

- 223 files across `agent-system/extensions/core/` (context, scripts, commands, agents, skills,
  rules, templates, hooks, merge-sources, root-files, README.md, manifest.json,
  index-entries.json) and 21 other extensions — reworded per the Classification Rubric: Class 1
  (phase-versus-command prose) to phase-name or dispatch-noun-phrase framing; Class 2
  (architectural/dispatch-model reference) to `research`/`plan`/`implement`-phase framing or an
  `/orchestrate --research`/`--plan`/`--implement` invocation form where the original text
  specifically illustrated literal CLI usage.
- `agent-system/extensions/core/commands/revise.md` — the two folded-in incidentals: restated the
  "no longer" record-versioning sentence as current behavior only, and reworded the stale
  artifact-numbering claim per Task 407's landed outcome.
- `specs/435_.../reports/02_class-decision-collation.md` — new collation artifact indexing every
  per-site class-3 (leave-alone) decision across all 14 sweep phases, the gate-24 blind spots
  discovered along the way, and the named follow-up residue (Phase 5/10 coherence items).
- No file under `agent-system/extensions/core/docs/` was touched (explicit scope exclusion —
  tasks 467/468 own that tree).

## Decisions

- Partitioned the 223-file sweep by extension, then by core subdirectory, sizing each phase at
  6-25 files rather than attempting the whole corpus in one phase.
- Discovered and used a third occurrence class beyond the dispatch's two: sites where the dead
  command name IS the data (the companion lint's own detection strings, AWK regex-delimiter
  coincidences, live wezterm-hook regex comments, a historical-record migration-guide column) —
  left alone rather than reworded, since rewording would corrupt behavior or falsify history.
- Phase 15 relied on `deploy-headless.sh`'s own fast-gate pass (`--skip-slow`) rather than
  independently re-running the full `verify-deploy.sh` sweep, consistent with this dispatch's
  Batch Gate Deferral directive (the full/slow gate set runs once at the batch level).
- Closed Phase 15 `[COMPLETED WITH EXCLUSIONS]` rather than `[COMPLETED]`: three fast-gate
  findings (eager-load context budget, a lean-extension shellcheck finding, two memory-extension
  `/ide` dead-command-recommendation violations) were each independently confirmed pre-existing
  (predating this task's first commit, verified via an isolated pre-task worktree deploy) and
  unrelated to this task's `/implement`/`/research`/`/plan` charter.

## Plan Deviations

- **Task 15.4** altered: the redeploy landed at `RESULT=landed_verify_red`, not
  `landed_verify_clean` — three pre-existing, out-of-scope fast-gate findings (see Reasoned
  Exclusions on the Phase 15 heading). The redeploy itself landed correctly.
- **Task 15.6** altered: ran the fast-gate set (green except the three findings above); the
  heavy shell test suite (gate 8) was deferred to the batch-level run rather than independently
  re-run inside this phase, per the dispatch's Batch Gate Deferral directive and
  `deploy-headless.sh`'s own `--skip-slow` design.
- Phase 2 (core/context/patterns): three files' architectural claims went stale beyond mere
  command naming (citing deleted CHECKPOINT-3 blocks and an incorrect "SIX command files"
  count); reworded the dead-command tokens per rubric and added inline residue notes rather than
  restructuring (out of scope per Non-Goals) — named as a follow-up in the collation report.
- No other deviations; every other phase followed the plan as written.

## Verification

- Build: N/A (markdown/meta task, no compiled build)
- Tests: Fast gate set (33 of 41 checks, `deploy-headless.sh`'s `--skip-slow` pass) green except
  the three pre-existing findings named above; gate 8 (shell test suite) deferred to the batch
  level per the Batch Gate Deferral directive.
- Files verified: Yes — corpus-wide measurement command confirms 11 remaining occurrences, all
  mapped to recorded class-3 decisions; `git status --porcelain` after the redeploy shows no
  file outside this task's own scope.

## Impacts

- The source-store corpus no longer suggests that `/implement`, `/research`, or `/plan` are
  runnable commands in prose describing phases, dispatches, or architecture — only the
  companion lint's own detection strings and a small set of genuinely historical or
  live-regex-matching sites still name them, each with a recorded, checkable reason.
- The regenerated `.claude/CLAUDE.md` (and its per-extension merge sources) now render the
  reworded Literature Mode, Memory Extension, and Nix Extension sections correctly.
- Three gate findings remain red in the deployed tree, all pre-existing and out of this task's
  scope: the eager-load context budget overage, a lean-extension shellcheck finding, and two
  memory-extension `/ide` dead-command-recommendation violations. None block this task's own
  completion per the Reasoned Exclusions admission test.

## Follow-ups

- The eager-load context budget overage (67169 B vs 66800 B baseline), the lean-extension
  shellcheck SC2155 finding, and the two memory-extension `/ide` dead-command-recommendation
  violations are each pre-existing and belong to other tasks' territory — not re-filed here as
  new tasks, since each already has an identifiable owning area (lean extension debt, memory
  extension's `/ide` recommendation, and the orchestrator context-budget mechanism itself).
- The Phase 5/10 coherence residue (orphaned `--divide` flag, the `status-sync-manager`/
  `git-workflow-manager` fictional-abstraction language, `command-lifecycle.md`'s own
  command-file-lifecycle framing, `command-structure.md`'s worked-example premise,
  `core/README.md`'s command-table row-count mismatch, the vestigial `--remember` flag, and the
  `processes/` References sections) is named but not restructured — see
  `reports/02_class-decision-collation.md`'s "Residue Named for a Follow-Up Record" section for
  the full seven-item list, each a candidate for a dedicated future task if the operator wants
  it pursued.
- Gate 24's three detection blind spots discovered during the sweep (verb-phrasing outside the
  anchored shape, multi-command-per-line, both confirmed via direct inspection) are informational
  only — not retargeted here; belong to whoever next revisits the companion lint (task 434's
  territory).

## References

- Plan: `specs/435_reword_dead_lifecycle_command_prose_per_class/plans/01_dead-lifecycle-command-prose-sweep.md`
- Research report: `specs/435_reword_dead_lifecycle_command_prose_per_class/reports/01_dead-lifecycle-command-prose.md`
- Class-decision collation: `specs/435_reword_dead_lifecycle_command_prose_per_class/reports/02_class-decision-collation.md`
- Per-phase progress files: `specs/435_reword_dead_lifecycle_command_prose_per_class/progress/phase-{1..15}-progress.json`
- Per-phase handoffs: `specs/435_reword_dead_lifecycle_command_prose_per_class/handoffs/phase-{1..15}-handoff-*.md`
