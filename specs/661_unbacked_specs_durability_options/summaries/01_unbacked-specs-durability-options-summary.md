# Implementation Summary: Task #661

- **Task**: 661 - Unbacked specs durability options
- **Status**: [COMPLETED]
- **Started**: 2026-11-20T00:40:00Z
- **Completed**: 2026-11-20T00:50:00Z
- **Effort**: 0.75 hours
- **Dependencies**: None
- **Artifacts**: reports/01_unbacked_specs_durability.md, plans/01_unbacked-specs-durability-options.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

This task recommends one way to keep an ignored `specs/` tree recoverable. The research report
already evaluated all four options the task description names, scored each against the five
required criteria (setup cost, per-task cost, what it recovers, what it silently fails to
recover, and the disqualifying cross-branch/cross-repo churn criterion applied first), and
drafted a durability statement for the sibling documentation record to place. This phase verified
both `DONE WHEN` clauses against the report's actual text and produced this completion summary,
which carries that statement verbatim.

## What Changed

- No mechanism was built, no script was written, and no hook was added — this is the task's
  intended outcome, not an incomplete one. The task description explicitly forbids designing an
  implementation, and the recommendation itself (Option D) is to build nothing.
- No file under `agent-system/**` was touched by this task.
- Added `specs/661_unbacked_specs_durability_options/summaries/01_unbacked-specs-durability-options-summary.md`
  (this file) — the only new file this task produces.
- Advanced `specs/661_unbacked_specs_durability_options/plans/01_unbacked-specs-durability-options.md`'s
  Phase 1 heading marker on closure.

## Decisions

- **Recommendation: Option D — document the exposure and build nothing.** Options A (sibling
  repository holding only specs trees) and B (periodic orphan-branch archive commit in the same
  repository) both fail the disqualifying criterion: each gives the specs tree a second place to
  live — a remote/repository for A, a branch for B — and that second place is itself something
  every branch- or repo-enumerating surface (`git fetch --all`, `git branch -a`, CI
  branch-protection sweeps, stale-branch cleanup) must learn to skip. That is exactly the
  cross-branch/cross-repo churn class the ignored posture exists to remove, reintroduced through
  a side door.
- Option C (an external host-level file-sync or snapshot mechanism) passes the churn criterion —
  it touches git not at all — but fails on a separate, equally fatal ground: it is not a decision
  this project can make, adopt, or verify from inside the repository. "The host already runs it"
  is either already true (nothing to recommend) or false (nothing this task is permitted to make
  true). It collapses into Option D plus a line telling the reader to check their own host.
- The recommendation is stated without hedging, as the task description explicitly permits:
  documenting the exposure and building nothing is a legitimate and complete outcome here, not a
  shortfall against a harder deliverable.

## Plan Deviations

- None (implementation followed plan).

## Impacts

- No downstream behavior changes: nothing under `agent-system/**` or `.claude/**` was modified,
  so no redeploy is required and no other task's file territory is affected.
- The sibling documentation record (the docs-reframe task in this same six-task group) now has a
  ready-to-place durability statement and a durable pointer to its source, so it needs no search
  and no re-derivation when it places the statement beside the other per-posture descriptions.

## Follow-ups

- The documentation record is the recipient that places the durability statement below into the
  rules/docs surfaces it already covers. This task deliberately does not place it, and
  deliberately does not edit that record's `description` or `file_scope` in `specs/state.json` to
  point at this path — see the plan's Risks & Mitigations for why that shortcut was rejected
  (a hand-rolled rewrite of `state.json` under live sibling concurrency, with no sanctioned
  script for editing another record's description).
- No other follow-up: the research report records that no mechanism backing up an ignored specs
  tree exists anywhere in this codebase today, and this task does not change that.

### Durability statement (verbatim, for the documentation record to place)

Source: `specs/661_unbacked_specs_durability_options/reports/01_unbacked_specs_durability.md`,
under its "Recommendation for Placement" heading. Quoted byte-for-byte:

> **If the specs tree is gitignored**, task state, reports, plans, and summaries exist only on
> this working copy's disk. No commit, branch, or repository preserves them. Losing or
> discarding this working copy loses all of it, with no git history to recover from. This
> project does not provide, and does not recommend adopting, a mechanism to back up an ignored
> specs tree — a sibling repository, an archive branch, or a sync tool each either reintroduces
> the cross-branch or cross-repository overhead the ignored posture exists to avoid, or is a
> host-level concern this project cannot verify or configure. If specs/ durability matters for a
> given repository, track it instead; the tracked posture remains fully supported and carries its
> own git history for free.

## References

- `specs/661_unbacked_specs_durability_options/reports/01_unbacked_specs_durability.md` — full
  options analysis, per-option verdicts, and the drafted durability statement
- `specs/661_unbacked_specs_durability_options/plans/01_unbacked-specs-durability-options.md` —
  implementation plan for this phase
