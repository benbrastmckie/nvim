# Implementation Summary: Task #494

- **Task**: 494 - Exempt a task own artifact directory from the phase-commit containment predicate
- **Status**: [COMPLETED]
- **Started**: 2026-11-06T09:47:45Z
- **Completed**: 2026-11-06T10:55:00Z
- **Effort**: 3 hours
- **Dependencies**: None (this record is the predecessor; two open tasks each depend on it)
- **Artifacts**: plans/01_own-task-dir-containment-member.md, summaries/01_own-task-dir-containment-member-summary.md
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, git-staging-scope.md, source-store-deploy-boundary.md

## Overview

`git-commit-phase.sh`'s Phase-Commit Containment Self-Check (one of three Containment sites
documented in `git-staging-scope.md`) widened its `file_scope_arr` with the shared
engine-written-state allowlist but never with the dispatching task's own resolved artifact
directory, unlike the other two sites, which both already carried that member. This task adds
the member as a per-site splice, pins the behavior with three new regression fixtures, narrows
two now-overbroad prose claims plus records a staging-seed/containment asymmetry and a
`missing_key`-yet-dropped resolution in `git-staging-scope.md`, and redeploys. All four plan
phases completed and are committed.

## What Changed

- `agent-system/extensions/core/scripts/git-commit-phase.sh` — spliced
  `file_scope_arr+=("${task_dir}/")` plus an explanatory comment inside the Containment
  Self-Check's existing non-empty `file_scope_arr` guard, admitting the committing task's own
  resolved artifact directory as an implicit, unconditional in-scope member, mirroring the two
  sibling Containment sites that already carried it.
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` — appended Case 15
  (own-directory acceptance: zero scope-excursion issue records), Case 16 (paired negative: a
  genuine out-of-territory path still drops, warns, and is recorded in the same run), and Case
  17 (fail-open preserved across a missing, empty, and malformed `file_scope`).
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — recorded the new
  own-task-directory member and how each of the three Containment sites obtains it; narrowed the
  "site 3 subsumes site 2" / "deliberately redundant" claims to the engine-written-state
  allowlist gap specifically (site 2 is load-bearing for the task-directory member, since it
  drops an uncontained path from its own pathspec before `git-commit-scoped.sh` is ever
  invoked); recorded the staging-seed/containment asymmetry; recorded the `missing_key`-yet-
  dropped resolution.
- Deployed `.claude/` tree regenerated via `deploy-headless.sh` to carry all three changes.

## Decisions

- The member is a per-site splice, not a shared-library addition to
  `engine-written-state-paths-lib.sh` — that library's own header rejects any task-owned
  `specs/{NNN}_*/` path, since a per-task directory is authored by one task's own dispatch
  rather than engine-written on behalf of every/many tasks.
- Empirical correction to the dispatch's live-symptom framing, established via a red-proof run
  against a splice-stripped scratch copy of the pre-fix script: the own-task-directory path
  still lands in the commit even without the fix, because the script's unconditional
  `stage_paths` directory-level seed already stages the whole task directory regardless of the
  Containment Self-Check's own filtering. The provable, fixable defect is therefore a spurious
  `WARNING: ... dropping out-of-scope path` plus a spurious `scope excursion` row written to the
  task's own `issues.jsonl` for a path that was never actually out of scope — noise and
  misclassification, not an actual silent omission from the commit in this configuration. This
  matches the dispatch's own acceptance phrasing ("zero scope-excursion issue records emitted")
  and is recorded in the new fixtures' comments and in the doc record.
- The `missing_key`-yet-dropped question required no second code change: `orchestrator-
  postflight.sh`'s additive `--file-scope-add` write-back can populate a previously-absent
  `file_scope` between an earlier review and a later phase commit, so a "no declared scope"
  observation and a later drop are both correct readings at two different points in a task's
  lifecycle. The fail-open posture is unchanged and remains deliberate.

## Plan Deviations

- **Phase 3 verification**: `verify-deploy.sh --skip-slow --only-gate 3,4` did not pass cleanly
  immediately after the doc edit — gate 4 passed, but gate 3 (doc-lint) reported FAIL for two
  reasons both resolved by Phase 4's redeploy rather than by anything further in Phase 3: (a)
  Phase 1/2's own already-committed, not-yet-deployed script drift; (b) an `index-entries.json`
  line-count mismatch for the edited doc file, whose fix script refuses to run outside a
  deployed tree by design. Confirmed resolved after Phase 4's redeploy (gate 3 reports extension
  `core` PASS; the sole remaining FAIL is the pre-existing `lean` finding below).
- **Phase 4 gate scope**: the dispatch's own Batch Gate Deferral directive (added after the plan
  was authored) superseded the plan's literal instruction to independently run the complete,
  unnarrowed gate set — this dispatch is one of several `implement`-phase dispatches in one
  multi-task `/orchestrate` batch, and the full gate runs once at the batch level instead.
  Discharged Phase 4 against the scoped tier the directive names
  (`run-all.sh --only test-git-commit-phase.sh,test-git-commit-scoped.sh`, PASS 2/2;
  `verify-deploy.sh --skip-slow --only-gate 3,4`, gate 4 PASS, gate 3 PASS for `core`). A full,
  unnarrowed run was also executed once (before re-reading the directive) and fully triaged: all
  4 of 41 failing checks are outside this task's `file_scope` — pre-existing `lean` extension
  manifest/orphan drift (commits `41d544812`/`ce5b1588b`) and an unrelated `memory` extension
  doc finding, both already named in advance by the dispatching orchestrator, plus 8 NEW-flagged
  orchestrator-lifecycle shell-suite failures (neither `test-git-commit-phase.sh` nor
  `test-git-commit-scoped.sh` among them), one of which explicitly reports the shared `specs/`
  tree changing mid-suite — consistent with concurrently-dispatched siblings in this same batch,
  not a regression from this task's three-file edit.

## Verification

- Build: N/A (shell scripts and markdown; `bash -n`/`shellcheck` clean on both edited scripts,
  no new findings beyond pre-existing, byte-identical SC1091 info notes)
- Tests: Passed — `run-all.sh --only test-git-commit-phase.sh,test-git-commit-scoped.sh` green
  (32 assertions, including the three new fixtures) on both the source-store and the
  redeployed `.claude/` tree.
- Files verified: Yes — deployed `git-commit-phase.sh` carries the splice, deployed
  `test-git-commit-phase.sh` carries Cases 15-17, deployed `git-staging-scope.md` carries the
  Phase 3 record; `git status --short` confirms no unexpected source-store path changed by the
  deploy.

## Impacts

- Every future mid-dispatch phase commit issued through `git-commit-phase.sh` for a task whose
  declared `file_scope` omits its own artifact directory will no longer emit a spurious
  drop-warning or a spurious `scope excursion` issue-log entry for a path inside that directory.
- `git-staging-scope.md`'s "Three Containment sites, not one" section now accurately states
  which claims about site 3 subsuming site 2 hold only for the engine-written-state allowlist
  gap, preventing a future reader from deleting the Containment Self-Check as redundant and
  reopening this exact gap.

## Follow-ups

- None filed by this task. Two already-open tasks (declaring the same three files) depend on
  this record and are unblocked by its completion: one concerning an extension's own manifest
  registration, the other concerning stale hand-authored `file_scope` for source paths.
- The pre-existing `lean` extension manifest/orphan drift and the `memory` extension `/ide` doc
  reference observed during Phase 4's full-gate triage are outside this task's scope and were
  already independently flagged by the dispatching orchestrator; no new follow-up filed here.

## References

- `specs/494_phase_commit_task_own_artifact_scope_carveout/reports/01_phase-commit-own-task-dir-carveout.md`
- `specs/494_phase_commit_task_own_artifact_scope_carveout/plans/01_own-task-dir-containment-member.md`
- `specs/494_phase_commit_task_own_artifact_scope_carveout/progress/phase-{1,2,3,4}-progress.json`
- `specs/494_phase_commit_task_own_artifact_scope_carveout/handoffs/`
- `agent-system/extensions/core/context/standards/git-staging-scope.md`
