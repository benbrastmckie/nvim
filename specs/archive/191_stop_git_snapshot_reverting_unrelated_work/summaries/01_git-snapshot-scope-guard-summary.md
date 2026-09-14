# Implementation Summary: Task #191

- **Task**: 191 - Stop plan-mandated git-snapshot from reverting task-unrelated uncommitted work
- **Status**: [COMPLETED]
- **Started**: 2026-09-09T20:21:00Z
- **Completed**: 2026-09-09T22:10:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_git-snapshot-scope-guard.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`git-snapshot.sh`'s default and `--branch` modes reverted the entire dirty working tree,
including tracked modifications unrelated to the task being snapshotted -- the exact incident
this task was created to close. Implemented a runtime out-of-scope refusal guard inside the
script itself (classifying every dirty tracked path against the task's declared `file_scope`,
refusing and naming offending paths unless `--allow-out-of-scope` is passed), a canonical
one-directional path-containment predicate shared from the existing `file-scope-overlap.sh`
library, a fixture regression suite proving the defect and the fix, task-identified stash
messages, and four documentation/contract edits steering plan authors away from the unsafe bare
default-mode idiom.

## What Changed

- `agent-system/extensions/core/scripts/tests/test-git-snapshot.sh` -- New fixture suite: a
  self-check, the core out-of-scope refusal case, a negative-control (all-in-scope) case, and a
  `--no-revert` regression case. Proven RED against the unfixed script, GREEN after Phase 3.
- `agent-system/extensions/core/manifest.json` -- registered the new test file.
- `agent-system/extensions/core/scripts/lib/file-scope-overlap.sh` -- additive
  `path_covered_by_scope()` function (one-directional containment: exact match, directory
  prefix, or glob-pattern match), leaving `scopes_overlap()`/`FILE_SCOPE_OVERLAP_JQ_DEFS`
  untouched.
- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md` -- new "Containment
  vs. Overlap" subsection defining the one-directional rule and its glob-only extension.
- `agent-system/extensions/core/scripts/git-snapshot.sh` -- the guard itself: sources the lib
  (via the same `if ! . file; then` idiom `task-lock.sh` uses, required because
  `FILE_SCOPE_OVERLAP_JQ_DEFS`'s `read -r -d ''` always returns exit 1 at EOF under `set -e`);
  adds an independent `--allow-out-of-scope` boolean; classifies dirty tracked paths before any
  mutation; refuses (naming paths) for default/`--branch` modes when any path is out of scope,
  or fail-closed when `file_scope` is absent/empty or `jq`/`state.json` is unavailable; warns
  (non-blocking) on out-of-scope untracked paths; leaves `--no-revert` completely unguarded and
  behaviorally unchanged; and now embeds the owning task number in every stash message
  (`git-snapshot-{task}-{ts}`).
- `agent-system/extensions/core/agents/planner-agent.md` -- new MUST NOT bullet (renumbered the
  list to fix a pre-existing duplicate-4 collision while adding it) forbidding emission of a
  bare precautionary `git-snapshot.sh {N}` plan step.
- `agent-system/extensions/core/context/formats/plan-format.md` -- Rollback/Contingency
  cross-reference to `recovery.md`'s rollback rung and the default-vs-`--no-revert` distinction.
- `agent-system/extensions/core/rules/git-workflow.md` -- updated the rollback recipe and
  exemption text to document the guard and the `--allow-out-of-scope` override.
- `agent-system/extensions/core/context/contracts/recovery.md` -- rung (c) now documents the
  guard and the override form for a genuine whole-tree rollback.
- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` -- deliberate
  `eager_load.baseline_bytes` bump (63973 -> 64450), documented inline, made necessary by
  `git-workflow.md`'s required growth.

## Decisions

- Guard applies to BOTH `default` and `--branch` modes (D2), not only the literal word
  "default" -- `--branch` is equally reverting.
- Only dirty TRACKED paths trigger refusal (D3); out-of-scope untracked paths are WARN-only on
  stderr, never blocking.
- No-`file_scope` (or missing `jq`/`specs/state.json`) fails CLOSED in reverting modes (D4) --
  an undeclared scope is precisely the state that produced the incident.
- `--allow-out-of-scope` is an independent boolean (D5), never confusable with `--no-revert`.
- `path_covered_by_scope()` lives in the canonical `file-scope-overlap.sh`/
  `file-footprint-overlap.md` location as an additive sibling function, not a fourth private
  copy of path-matching logic inside `git-snapshot.sh`.

## Plan Deviations

- Phase 3: `TASK_NUM`'s derivation was relocated from inside the guard's own conditional (only
  reached by reverting modes) to unconditional scope, since `--no-revert` mode also needs it for
  Phase 4's stash-identity message but never enters that guard block.
- Phase 3: sourced `lib/file-scope-overlap.sh` via the `if ! . file; then` guard idiom (matching
  `task-lock.sh`'s `ensure_file_scope_overlap_lib()`) rather than a bare `source`, discovered
  necessary when the bare form aborted the script under `set -e` (the lib's
  `read -r -d ''`-based heredoc assignment always returns exit 1 at EOF).
- Phase 6: `deploy-headless.sh`'s Gate 20 (eager-load budget) failed after Phase 5's required
  `git-workflow.md` growth; resolved via a deliberate, documented `baseline_bytes` bump per that
  config file's own re-derivation process -- not a rework of Phase 5's content.
- Phase 6 closed as `[COMPLETED WITH EXCLUSIONS]`: `run-all.sh` surfaced 9 pre-existing,
  unrelated failures (8 share a fixture gap -- missing `lib/task-lookup-lib.sh` copy -- predating
  this task per `git log`; 1 is a `lint-json-channel-discipline.sh` finding in
  `orchestrate-triage-classify.sh`, a file this task never touched). See the plan's Phase 6
  `#### Reasoned Exclusions` table for full evidence.

## Verification

- Build: N/A
- Tests: `test-git-snapshot.sh` 4/4 PASS (source-store and deployed copies both); acceptance
  scenario (out-of-scope tracked dirty tree -> default mode refuses, names path, tree untouched)
  confirmed live against both copies; `--allow-out-of-scope` and `--branch`-mode guarding
  confirmed live; D4 no-`file_scope` fallback confirmed live; `test-guard-destructive-git.sh`
  43/43 PASS (marker contract untouched); `lint-agent-contracts.sh` 101/0/0;
  `check-task-references.sh` PASS (0 unexempted occurrences); `deploy-headless.sh` verification
  33/33 PASS. `run-all.sh`: 74 passed, 9 failed -- all 9 pre-existing and unrelated (see Plan
  Deviations / Reasoned Exclusions).
- Files verified: Yes

## Impacts

- Any future plan-mandated or ad hoc `git-snapshot.sh` invocation in default/`--branch` mode is
  now structurally incapable of silently reverting task-unrelated uncommitted work -- it refuses
  and names the paths instead, closing the exact incident this task documents.
- Snapshot stash entries are now self-identifying by task number, giving an operator enough
  information to judge which of several concurrent entries are safe to drop (no reaper was
  built or invoked, per the dispatch's explicit MUST NOT).
- `orchestrator-context-budget.json`'s eager-load ceiling moved from 63973 to 64450 bytes as a
  direct, documented consequence of the new rollback-recipe documentation.

## Follow-ups

- The 9 pre-existing `run-all.sh` failures documented in Phase 6's Reasoned Exclusions remain
  open repository defects outside this task's scope: 8 share a missing
  `lib/task-lookup-lib.sh` copy across several fixture scripts under `scripts/`, and 1 is a
  `lint-json-channel-discipline.sh` finding in `orchestrate-triage-classify.sh`.
- A stash reaper (naming which `git-snapshot-*` stash entries are safe to drop) remains
  unbuilt, as explicitly scoped out of this task.

## References

- Plan: `specs/191_stop_git_snapshot_reverting_unrelated_work/plans/01_git-snapshot-scope-guard.md`
- Research: `specs/191_stop_git_snapshot_reverting_unrelated_work/reports/01_git-snapshot-scope-guard.md`
- Progress: `specs/191_stop_git_snapshot_reverting_unrelated_work/progress/phase-{1..6}-progress.json`
