# Implementation Summary: Task #541

- **Task**: 541 - Stop git-snapshot.sh's --no-revert artifacts from contaminating phase commits with OTHER tasks' files
- **Status**: [COMPLETED]
- **Started**: 2026-11-23T04:32:00Z
- **Completed**: 2026-11-23T06:08:58Z
- **Effort**: ~2 hours
- **Dependencies**: specs/535_phase_commit_drops_own_plan_artifact (completed)
- **Artifacts**: plans/01_snapshot-artifact-containment-fix.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closed both halves of the snapshot-artifact containment defect: `git-snapshot.sh`'s
`--no-revert` untracked-file enumeration was repository-wide and unfiltered, and
`git-commit-phase.sh`'s fixed task-directory pathspec staged whatever it found there with no
containment check. Each defect is fixed at its own site, a new ephemeral runtime-file class
member closes the gap for every consumer repository, and two regression cases — demonstrated
failing against the unmodified scripts before either fix landed — now pin the fix in place.

## What Changed

- `agent-system/extensions/core/scripts/git-snapshot.sh` — lifted the `file_scope` resolution
  into a shared `resolve_task_file_scope()` function; `--no-revert`'s untracked-file backup is
  now filtered through it (own-directory always admitted), with a named, non-silent
  own-directory-only fallback when `file_scope` cannot be resolved, and `--allow-out-of-scope`
  restoring the repository-wide backup. Header/usage docs updated to match.
- `agent-system/extensions/core/scripts/git-commit-phase.sh` — the fixed `stage_paths` seed now
  conditionally excludes both `working-progress-*.patch` and `untracked-backup-*` via an explicit
  `:(exclude)` pathspec entry whenever a concrete on-disk hit is not already gitignored, mirroring
  `git-commit-scoped.sh`'s own conditional-injection idiom.
- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` — registered
  `untracked-backup` as the 28th ephemeral runtime-file class member (directory-class, glob-style
  basename); generalized `runtime_file_dir_basename_for_hit()` to resolve a glob-style basename
  against a hit's real path segments, confirmed backward-compatible for every pre-existing
  fixed-literal member.
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` — added the
  Class Table row and the durable-patch counterpart note; regenerated the Consumer Repo Setup
  fenced block (confirmed byte-identical to the library's emitted block).
- `agent-system/extensions/core/context/patterns/checkpoint-before-overflow.md` — stated both
  artifacts' dispositions in the `--no-revert` checkpoint procedure.
- `agent-system/extensions/core/index-entries.json` — resynced `line_count` for both edited
  markdown files.
- `specs/.gitignore` — regenerated managed block now carries the new pattern.
- `agent-system/extensions/core/scripts/tests/test-git-snapshot.sh` — new containment-scoping
  case (Half 1), demonstrated failing against the unmodified script.
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` — new Case 42 (Half 2),
  demonstrated failing against the unmodified script.
- `agent-system/extensions/core/scripts/tests/test-runtime-file-tracking.sh` — Case 5's
  hardcoded class-member count updated from 27 to 28 (a necessary consequence of the new member,
  not independently requested).

## Decisions

- Narrowed the `--no-revert` backup to `file_scope` rather than leaving it repository-wide: that
  mode reverts nothing, so narrowing it loses no recovery value for the dispatching task while a
  repository-wide copy writes other tasks' files into a directory the commit wrapper stages
  wholesale.
- `untracked-backup-*/` joined the ephemeral runtime-file class; `working-progress-*.patch` did
  not — the backup is a duplicate of content that is itself untracked and never deleted by the
  mode that writes it, while the patch is the only durable record of the snapshot's tracked-change
  diff and remains tracked-eligible by that script's own documented design. The phase-commit
  exclusion is therefore load-bearing for the patch and a redundant-by-design second line of
  defense for the backup directory; both entries were added regardless.
- This repository's own hand-added root `.gitignore` line covering the backup pattern was left
  untouched — it predates this task, is outside the declared edit surface, and a duplicate ignore
  pattern is harmless.

## Plan Deviations

- **Task 4.5** altered: ran the source-store copy of `init-specs.sh` directly instead of the
  deployed path literally named in the plan, since the deployed library was still stale
  pre-deploy and `init-specs.sh` has no deploy-root-guard to work around.
- **Task 4.7** altered: `test-runtime-file-tracking.sh` deliberately prefers the deployed tree
  when present, so running it pre-deploy validated the still-consistent stale tree rather than
  the new edits; supplemented with direct verification against the source-store copies
  (byte-identity check, lockstep array check, `check-runtime-file-tracking.sh` run directly, both
  deploy-harness fixtures), all green, then re-confirmed by the suite itself after Phase 5's
  deploy.
- **Task 5.1** altered: deployed twice — the first deploy surfaced `test-runtime-file-tracking.sh`'s
  own pre-existing hardcoded class-member count (27) going stale from the new 28th member; fixed
  it and deployed a second time. Both deploys reported `RESULT=landed_verify_clean`.

## Verification

- Build: N/A
- Tests: Passed — `test-git-snapshot.sh` 8/8, `test-git-commit-phase.sh` 106/106,
  `test-runtime-file-tracking.sh` 15/15, `test-deploy-orphans.sh` 8/8, `test-deploy-propagation.sh`
  10/10, all against the deployed copies; `verify-touched.sh` (no arguments, full dispatch diff)
  98/98 across 59 selected suites.
- Files verified: Yes

## Impacts

- `--no-revert` is once again safe to use as the sanctioned defensive checkpoint inside a
  phase-committing dispatch, without risking another task's untracked files landing in this
  task's commit.
- Every consumer repository now inherits the `untracked-backup-*/` ignore pattern from the shared
  library, closing the gap that let the originating incident reproduce in one repository but not
  another whose root `.gitignore` had the pattern by hand.

## Follow-ups

- Porting the same conditional `:(exclude)` entries to `scripts/orchestrate-cycle-postflight.sh`'s
  structurally identical fixed-scope seed (recorded as a Non-Goal here; logged in the issue log).
- Removing the one still-tracked `working-progress-*.patch` file noted in the originating record
  remains optional cleanup, not performed here.

## References

- Plan: `specs/541_snapshot_artifacts_contaminate_phase_commits/plans/01_snapshot-artifact-containment-fix.md`
- Report: `specs/541_snapshot_artifacts_contaminate_phase_commits/reports/01_snapshot-artifact-containment-fix.md`
