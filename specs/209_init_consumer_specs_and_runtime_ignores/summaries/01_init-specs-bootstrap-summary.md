# Implementation Summary: Task #209

- **Task**: 209 - Set up a fresh repo specs/ state and runtime-file ignore rules automatically
- **Status**: [COMPLETED]
- **Started**: 2026-09-18T00:00:00Z
- **Completed**: 2026-09-18T01:40:00Z
- **Effort**: ~1.5 hours (estimated 8 hours)
- **Dependencies**: None
- **Artifacts**: plans/01_init-specs-bootstrap.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, source-store-deploy-boundary.md

## Overview

Added an idempotent `scripts/init-specs.sh` bootstrap that creates a fresh consumer repo's
`specs/` state trio (`state.json`, `archive/state.json`, `TODO.md`), writes a managed-block
`specs/.gitignore` generated mechanically from `scripts/lib/runtime-file-patterns.sh`, and
untracks (never deletes) any already-committed ephemeral runtime-class file under `specs/`.
Wired the script into all six first-touch task-creation sites plus a defensive `/orchestrate`
call, extended the canonical runtime-file-patterns library with the missing `specs/tmp/` class
member (17th), rewrote the "Consumer Repo Setup" standards documentation to describe the new
automatic path, and added an 8-case fixture suite that pins every acceptance criterion from the
originating dispatch (including its 2026-09-14 amendment).

## What Changed

- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` — added a 17th class
  member (`tmp`, root-scoped `/specs/tmp/`, covering `hooks/tts-notify.sh`,
  `scripts/lifecycle-notify.sh`, and `scripts/state-write.sh`'s own mktemp staging files); added
  `runtime_specs_ignore_block()`, mechanically derived from `RUNTIME_FILE_PATTERNS` (a loop, not
  a second hand-written literal list), emitting the same class as `specs/`-relative patterns for
  a `specs/.gitignore` file.
- `agent-system/extensions/core/scripts/init-specs.sh` — new file. Idempotent bootstrap: creates
  `specs/`, `specs/archive/`; writes `specs/state.json` and `specs/archive/state.json` directly
  via mktemp + atomic `mv` (never through `state-write.sh --init`, which refuses the default live
  path by design); generates `specs/TODO.md` via `generate-todo.sh`; writes/refreshes a
  sentinel-delimited managed block in `specs/.gitignore`, preserving any hand-added content
  outside the sentinels; untracks (`git rm --cached` / `git rm -r --cached`, never deleting the
  working copy) any already-tracked ephemeral-class file under `specs/`, with a belt-and-braces
  skip for `.orchestrator-handoff.json`/`.return-meta.json` basenames. Never overwrites existing
  state; never commits.
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` — rewrote
  "Consumer Repo Setup": the `specs/`-scoped ignore rules are now installed automatically (no
  manual step required for a repo using only the wired call sites); discovered and documented,
  with a live verification, that `specs/.gitignore`'s own `**/.sessions/` pattern already covers
  `specs/.sessions/` (previously believed reachable only via the repo-root `.gitignore`); retained
  the root-`.gitignore` block as an optional legacy/belt-and-braces path. Added an
  "Automatic-wiring decision record" (deploy does not call `init-specs.sh`, `command-gate-in.sh`
  is not a viable choke point, coordination note with `move_session_state_files_out_of_specs_root`).
  Added a "sixth site" note and a new Class Table row for `specs/tmp/`.
- `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` — reworded Check A's
  failure message to name `init-specs.sh`/`specs/.gitignore` as the primary remediation (no logic
  change; `git check-ignore -q` already honors `specs/.gitignore` at any depth).
- Six first-touch call sites plus one defensive site, each gained a call to
  `bash .claude/scripts/init-specs.sh` immediately before their `next_project_number` read:
  `commands/task.md`, `commands/review.md`, `skills/skill-fix-it/SKILL.md`,
  `skills/skill-project-overview/SKILL.md`, `skills/skill-spawn/SKILL.md`,
  `agents/meta-builder-agent.md`, and `commands/orchestrate.md` (defensive, belt-and-braces).
- `agent-system/extensions/core/scripts/tests/test-init-specs.sh` — new file. 8 cases (23
  assertions), modeled on `test-runtime-file-tracking.sh`'s deploy-tree-first/source-store-
  fallback resolution: fresh bootstrap, idempotence, managed-block preservation, the untrack
  sweep's full ADDED ACCEPTANCE scenario (six runtime-class paths untracked, disk-preserved,
  clean tree after a scoped commit, true no-op on a second run), durable-provenance preservation,
  `check-runtime-file-tracking.sh` passing on `specs/.gitignore`-only coverage, the item (h)
  regression pin, and `specs/tmp/` ignore coverage.
- `agent-system/extensions/core/scripts/tests/test-runtime-file-tracking.sh` — updated Case 5's
  hardcoded member count (16 → 17) so the pre-existing suite stays green after the lib's own
  17th-member addition (not in the plan's own Files-to-modify list; a necessary companion fix).
- `agent-system/extensions/core/manifest.json` — registered `init-specs.sh` and
  `tests/test-init-specs.sh` under `provides.scripts` (alphabetical position).
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` — added an
  `init-specs.sh` entry (dual-purpose like its `check-runtime-file-tracking.sh` sibling: operator-
  invokable directly, and automatically wired into every first-touch call site).

## Decisions

- `specs/archive/state.json`'s minimal shape (`{"archived_projects": [], "completed_projects": []}`)
  confirmed against its live readers (`commands/todo.md`'s own `--init` bootstrap filter) rather
  than assumed.
- Deploy (`deploy-headless.sh`) deliberately does **not** call `init-specs.sh` — `specs/`
  bootstrap is a task-lifecycle concern, not a deploy concern, and `.syncprotect` has no defined
  relationship to `specs/`. Recorded in the standards doc's decision record.
- `command-gate-in.sh` confirmed not a viable first-touch choke point (`grep -c next_project_number` = 0
  against it) — by the time any command reaches gate-in, a task, and therefore `specs/`, already
  exists.

## Plan Deviations

- Phase 1: also updated `test-runtime-file-tracking.sh`'s hardcoded member-count assertion (16 →
  17), which is not in the plan's Files-to-modify list for that phase but was required to keep
  the pre-existing suite green after the 17th class member was added.
- Phase 6: Case 4's fixture commits the untrack sweep's staged output with a plain `git commit`
  rather than invoking `git-commit-scoped.sh` itself — `git-commit-scoped.sh`'s own staging/mutex
  logic has its own dedicated `test-git-commit-scoped.sh` suite; this case verifies the
  observable outcome (clean `git status --porcelain -- specs/` after a scoped commit) that
  `git-commit-scoped.sh` would produce, which is behaviorally identical here since nothing beyond
  the sweep's own `git rm --cached` output is staged.
- Phase 7: the dispatch's ACCEPTANCE text says "redeploy and confirm in a consumer repo," but
  Phase 7's own task list substitutes a throwaway scratch repo for that confirmation (matching
  `test-init-specs.sh`'s own harness) and explicitly cautions against modifying a real user
  project's working tree to force the check. `~/Projects/Logos/Verification` exists and is clean,
  but redeploying its `.claude/` was correctly avoided as an unmandated working-tree change
  outside this task's scope — see Follow-ups.

## Verification

- Build: N/A (shell scripts + markdown; no compiled build)
- Tests: `test-init-specs.sh` 23/23 passing (both source-store and deployed copies);
  `test-runtime-file-tracking.sh` 9/9 passing (Case 3 byte-identity pin intact); `run-all.sh`
  70/79 suites passing in the deployed tree, with the 2 failing suites
  (`test-task-lock-reap.sh`, `test-state-write-regen-timing.sh`) confirmed pre-existing and
  unrelated via `git log` (last touched by task 197, never by this task; this task never touches
  `task-lock.sh`, `task-lookup-lib.sh`, or either failing test file)
- Files verified: Yes — `check-task-references.sh` PASS (no task-number leaks),
  `check-runtime-file-tracking.sh` PASS (all 3 checks) in this repo, `shellcheck` clean on every
  shell file touched (only the same two pre-existing, tolerated SC2329/SC2001 info/style codes
  already present in the sibling suite this one is modeled on)

## Impacts

- A consumer repo that has never run the task system can now create its first task without
  manually constructing `specs/state.json` by hand from the schema.
- Every scoped commit of `specs/` in a fresh consumer repo is now protected from picking up the
  system's own lock/session/dispatch scratch files from its very first task, closing the defect
  observed live in `~/Projects/Logos/Verification`'s early commit history.
- A repo where runtime-class files were already force-tracked before this policy existed can now
  self-heal via the same `init-specs.sh` call, without a separate manual remediation step.

## Follow-ups

- `~/Projects/Logos/Verification` was not redeployed as part of this task (see Plan Deviations);
  a future `/orchestrate` run against that repo (or a manual `deploy-headless.sh` there) will pick
  up `init-specs.sh` automatically via its own first-touch call sites. That repo has also since
  adopted a blanket root `/specs/` gitignore of its own, independent of this task, which makes it
  a less representative test case for the original defect than a repo that tracks `specs/`
  normally.
- The coordinating `move_session_state_files_out_of_specs_root` task (if/when undertaken) must
  re-check that `runtime_specs_ignore_block()`'s generated `specs/.gitignore` still covers
  whatever paths it relocates — noted in the standards doc's own decision record.
- `commands/orchestrate.md`'s pre-existing eager-context-budget ceiling overage (18075 B vs an
  8000 B ceiling) and the `eager_load.baseline_bytes` drift surfaced by `verify-deploy.sh` during
  this task's own deploy step are both pre-existing and unrelated to this task's edits (confirmed
  via `orchestrator-context-budget.json`'s own recorded history, which already documents the
  orchestrate.md ceiling gap as a known "Stage C follow-up," and via the fact that this task never
  touches any eagerly-loaded rule/CLAUDE.md file) — left unaddressed as out of scope.

## References

- `specs/209_init_consumer_specs_and_runtime_ignores/plans/01_init-specs-bootstrap.md`
- `specs/209_init_consumer_specs_and_runtime_ignores/reports/01_init_consumer_specs.md`
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md`
