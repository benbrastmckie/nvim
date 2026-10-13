# Implementation Summary: Task #375

- **Task**: 375 - Caller-side phase-commit completeness check
- **Status**: [COMPLETED]
- **Started**: 2026-10-09T14:17:00Z
- **Completed**: 2026-10-09T15:30:00Z
- **Effort**: ~5.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_caller-side-completeness-check.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

The incident this task closed was a caller-side omission: a phase commit's `stage_paths` array
was hand-typed, one of ten regenerated files was never named, and `git-commit-scoped.sh`
committed exactly what it was given and exited 0 — the script behaved correctly throughout. This
implementation adds `git-commit-phase.sh`, a mechanized wrapper that derives the stage list from
a phase's own progress-file `files_touched` arrays, performs a post-commit completeness check,
mechanizes a piped-invocation lint rule, migrates both phase-commit call sites in
`general-implementation-agent.md`, and corrects three durable records that carried disproven
claims about the incident.

## What Changed

- `agent-system/extensions/core/scripts/git-commit-phase.sh` — new; derives the phase-commit
  stage list from `files_touched`, ports the Phase-Commit Containment Self-Check mechanically,
  invokes `git-commit-scoped.sh` unpiped, and runs a post-commit `git status --porcelain`
  completeness check over every derived path, exiting 6 (reserved, never colliding with the
  wrapped script's 0-5 vocabulary) and naming each dirty path when one is found.
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` — new; 9-case fixture
  suite (N-vs-N-1 acceptance via a planted pre-commit hook, derivation union/dedup, `--objective`
  narrowing, 3 fail-open paths, 2 containment-port paths, exit-code pass-through). 16/16
  assertions pass.
- `agent-system/extensions/core/agents/general-implementation-agent.md` — both phase-commit call
  sites (Stage 4B-iii per-objective, Phase Checkpoint Protocol step 5 per-phase) migrated from a
  hand-typed `stage_paths` + direct `git-commit-scoped.sh` call to a single
  `git-commit-phase.sh` invocation with explicit per-code handling; the Phase-Commit Containment
  Self-Check section rewritten to describe mechanical enforcement.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — cross-referenced
  `git-commit-phase.sh` as the sanctioned per-phase implementation; corrected the "ten generated
  Typst files" miscount to nine (removing `zigzag.typ`, which was never part of the commit being
  described) and the resulting out-of-scope count from nine to eight; recorded the scope of the
  `git-commit-phase.sh` migration (other per-extension implementation agents sharing the same
  hand-typed shape, cross-referenced rather than migrated — see Plan Deviations).
- `agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh` — added Rule 2:
  detects a `git-commit-scoped.sh`/`git-commit-phase.sh` invocation piped into another command
  without `set -o pipefail` in effect, with its own enumeration record (zero existing piped
  invocation templates found) and KNOWN LIMITATION note.
- `agent-system/extensions/core/scripts/tests/test-lint-scoped-commit-boundary.sh` — added 4
  fixtures for Rule 2 (piped flagged, pipefail-exempt, unpiped clean, test-assertion-pipe clean);
  fixed a pre-existing `grep -q`/`set -o pipefail` SIGPIPE race in the existing `--verbose`
  assertion (Case 5), surfaced deterministically by Rule 2's added trailing output.
- `~/Projects/Logos/Verification/specs/224_review_and_refactor_fragile_gate_infrastructure/issues.jsonl`
  (cross-repo) — appended entry `iss_1791557306352_fsTbel` correcting `iss_1791495993077_nD5IuJ`'s
  false claim that `zigzag.typ` was listed in the commit's `stage_paths`, citing the transcript
  evidence; committed in that repository alone (`f0b2166c`), scoped to the one file, no push.
- `specs/374_diagnose_silent_staging_drop_in_git_commit_scoped/issues.jsonl` — appended entry
  `iss_1791557241371_31W0Zc` correcting `iss_1791536517779_09aSQf`'s inverted commit-provenance
  claim, with reproduced occurrence-count and `git log` measurements.

## Decisions

- The settled operator decision (relayed via this task's `.decisions.json`) to append AND commit
  the Verification-repo correction, scoped to that one file via that tree's own
  `git-commit-scoped.sh`, with no push, was followed exactly.
- Exit code 6 is reserved for the completeness-check failure and never collides with
  `git-commit-scoped.sh`'s own 0-5 vocabulary; every other inner code passes through verbatim,
  including "nothing to commit" (1), which correctly becomes 6 when paired with a dirty
  `files_touched` path (the exact silent-drop shape this script exists to catch).

## Plan Deviations

- **Phase 3, "re-grep for other hand-typed `stage_paths` arrays"** altered: the re-grep found
  roughly 14 other per-extension implementation agents (lean, nix, rust, typst, books, latex,
  web, python, z3, cslib, epidemiology, founder, nvim, and a web skill) sharing the identical
  hand-typed shape, each with its own Phase Checkpoint Protocol copied from the same template
  `general-implementation-agent.md`'s two sites were migrated from. Full migration of all of them
  was well beyond this phase's 1-hour budget and this task's own WHY/ACCEPTANCE sections, which
  name only `general-implementation-agent.md`'s two sites. Took the task's own explicitly-offered
  lighter-weight option instead: cross-referenced the finding in `git-staging-scope.md`'s new
  "Scope of the `git-commit-phase.sh` migration" passage so a future task can pick it up.
- **Phase 6, full gate set**: closed `[COMPLETED WITH EXCLUSIONS]` rather than `[COMPLETED]`. 3
  pre-existing, deterministic, reproducible test failures (`test-detect-noop-bash.sh`,
  `test-lint-deploy-caller-wrap.sh`, `test-orchestrate-build-aux-dispatch.sh`) are unrelated to
  any of this task's 5 phases and touch no file in this task's `file_scope`. See the plan's
  Phase 6 Reasoned Exclusions record for the full evidence.

## Verification

- Build: N/A (no compiled artifact)
- Tests: `test-git-commit-phase.sh` 16/16 pass; `test-lint-scoped-commit-boundary.sh` 13/13 pass;
  full `tests/run-all.sh`: 126 passed, 3 failed (all 3 pre-existing and unrelated — see Plan
  Deviations)
- Files verified: Yes — deployed `.claude/scripts/git-commit-phase.sh` confirmed byte-identical
  to the source-store copy and executable
- `verify-deploy.sh` full battery: 34 of 35 checks pass (the lone failure is gate 8, for the same
  3 unrelated suites)
- `check-extension-docs.sh`, `lint-agent-contracts.sh`, `lint-scoped-commit-boundary.sh
  --verbose`, `lint-directory-pathspec-boundary.sh`, `check-task-references.sh`: all exit 0

## Impacts

- Every future phase commit (both per-objective green-substep commits and per-phase closing
  commits) in `general-implementation-agent.md`'s workflow now derives its stage list
  mechanically and is verified complete against HEAD after the commit, closing the exact class of
  silent-drop incident this task was opened for.
- A piped phase-commit invocation (hiding the real exit code, including `git-commit-phase.sh`'s
  own new exit 6) is now a standing lint finding, wired into `verify-deploy.sh` gate 17 for free.
- Three durable records that carried disproven causal claims about the `fc9f786e` incident are
  now corrected, in both the Verification repository and this one.

## Follow-ups

- Migrate (or further cross-reference) the ~14 other per-extension implementation agents sharing
  the same hand-typed phase-commit `stage_paths` shape to `git-commit-phase.sh` — see
  `git-staging-scope.md`'s "Scope of the `git-commit-phase.sh` migration" note.
- The 3 pre-existing, unrelated test failures discovered during Phase 6 (`test-detect-noop-bash.sh`,
  `test-lint-deploy-caller-wrap.sh`, `test-orchestrate-build-aux-dispatch.sh`) are not in
  `known-failures.txt` and were not investigated further here, since they are out of this task's
  scope — worth a dedicated follow-up task.
- Whether `specs/.commit-lock` should fail closed remains an already-flagged, separate follow-up
  (unchanged by this task).

## References

- `specs/375_caller_side_phase_commit_completeness_check/reports/01_caller-side-completeness-check.md`
- `specs/375_caller_side_phase_commit_completeness_check/plans/01_caller-side-completeness-check.md`
- `agent-system/extensions/core/scripts/git-commit-phase.sh` (header carries the full incident
  account and exit-code mapping)
