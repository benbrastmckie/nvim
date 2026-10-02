# Implementation Summary: Task #317

- **Task**: 317 - Post-deploy reconcile promotion must append to the batch's `completed_tasks` ledger
- **Status**: [COMPLETED]
- **Started**: 2026-10-02T00:00:00Z
- **Completed**: 2026-10-02T01:20:00Z
- **Effort**: ~2 hours
- **Dependencies**: None (overlapped task 265's `file_scope` on `skill-orchestrate/SKILL.md` only in principle; this implementation never touched that file, so no actual conflict occurred)
- **Artifacts**: plans/01_reconcile-ledger-and-commit.md
- **Standards**: .claude/context/formats/plan-format.md, .claude/context/standards/status-markers.md, .claude/rules/artifact-formats.md, .claude/rules/source-store-deploy-boundary.md, .claude/context/standards/git-staging-scope.md

## Overview

The post-deploy reconcile pass in `orchestrate-cycle-plan.sh` promoted a deploy-unblocked task to
`completed` in `specs/state.json` but never reflected that into the batch's `.completed_tasks`
accumulator and never committed the write, so a batch under-reported its own `### Succeeded` table
and left the durable git record ("orchestration paused") contradicting `state.json`. Both gaps are
now closed at the single promotion site, backed by a new regression arm demonstrated RED against
unfixed source before the fix landed.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — in the post-deploy reconcile
  promotion loop, gated on `_pdr_outcome = "promoted"`: (1) appends the promoted task number to
  `.completed_tasks` via `mt_set`, mirroring `orchestrate-cycle-postflight.sh`'s own idiom; (2)
  issues the promotion's own scoped commit via `git-commit-scoped.sh` with an explicit two-file
  pathspec (`specs/state.json`, `specs/TODO.md`), non-blocking on failure (a
  `REDEPLOY CHECKPOINT WARNING` and continue, never an abort); (3) extended the block's header
  comment with the ledger-and-commit obligation and a cross-reference to the existing CONCURRENCY
  POSTURE / "no dispatch in flight" placement invariant the commit's safety rides on.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — Group 29 gained
  Arm F: drives a real post-deploy reconcile promotion inside an arm-scoped real git repository
  (`git init` at arm start, `rm -rf "$WORKDIR/.git"` at arm end) and asserts (i) the promotion
  appears in `.completed_tasks`, (ii) HEAD advances via the commit, and (iii) no uncommitted
  residue remains in `specs/state.json`/`specs/TODO.md`. The real `git-commit-scoped.sh` was
  installed into the sandbox (no stub) so the assertion exercises the actual commit path.

## Decisions

- Chose option (a) (append at the promotion site) over option (b) (re-derive Move 4's reporting
  from authoritative per-task status) — the accumulator is already written correctly everywhere
  else; only this one site omitted it, so narrowing the fix to that site was proportionate.
- Chose "the promotion issues its own scoped commit" over "refuse to stop on `all_terminal`" — a
  working-tree-dirtiness-based stop-refusal would be unsafe given this script's own documented
  posture toward concurrent sibling tasks dirtying the same shared tree; a targeted explicit-file
  commit at the point of mutation needs no such signal.
- Used the REAL `git-commit-scoped.sh` in the regression arm (never a stub), so a silently-failing
  commit call could not produce a false-GREEN result.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (shell scripts; `bash -n` clean on both modified files)
- Tests: Passed — `test-orchestrate-cycle-plan.sh`: 340 passed, 0 failed (including the new Arm F,
  RED-then-GREEN demonstrated). `test-orchestrate-cycle-postflight.sh`: 153 passed, 0 failed. Full
  10-suite gate enumerated via `ls ... | grep -iE 'reconcile|commit-scoped|postflight|cycle'`: all
  10 GREEN.
- Files verified: Yes

## Impacts

- A post-deploy reconcile promotion now appears correctly in a batch's `### Succeeded` table and
  `.dispatch/` cleanup set (Move 4 of `skill-orchestrate/SKILL.md`), with no consumer-side change
  required.
- The durable git record can no longer contradict `specs/state.json` for a reconcile-promoted
  task: the promotion's own commit lands before the engine can stop on `all_terminal`.

## Follow-ups

- `verify-deploy.sh` (run as part of this task's own completion-deploy step) reports 2 of 33
  checks failing, both pre-existing and unrelated to this task's scope: (1) a doc-lint gap —
  `agent-system/extensions/core/scripts/migrate-state-legacy-fields.sh` (added by task 279, already
  committed) is not yet declared in core's `manifest.json` `provides.scripts`; (2) a sandbox orphan
  tmp file (`tmp/noop-bash-count-...`) unrelated to any task's deliverable. Neither names a file
  this task touched; flagged here per Observation Duty rather than fixed, since both are outside
  this task's own scope.

## References

- Plan: specs/317_post_deploy_reconcile_completed_tasks_ledger/plans/01_reconcile-ledger-and-commit.md
- Research: specs/317_post_deploy_reconcile_completed_tasks_ledger/reports/01_post-deploy-reconcile-ledger.md
- Progress: specs/317_post_deploy_reconcile_completed_tasks_ledger/progress/phase-{1,2,3,4}-progress.json
- Handoff: specs/317_post_deploy_reconcile_completed_tasks_ledger/handoffs/phase-1-handoff-*.md
