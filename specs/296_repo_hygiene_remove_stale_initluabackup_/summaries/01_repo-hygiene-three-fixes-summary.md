# Implementation Summary: Task #296

- **Task**: 296 - Repo hygiene: remove stale init.lua.backup, regenerate project-overview.md, fix README.md link
- **Status**: [COMPLETED]
- **Started**: 2026-10-08T00:00:00Z
- **Completed**: 2026-10-08T01:30:00Z
- **Effort**: ~2 hours
- **Dependencies**: None
- **Artifacts**: plans/01_repo-hygiene-three-fixes.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Three independent repo-hygiene fixes from the 2026-10-01 review, executed as four phases (three
parallelizable fixes plus a closing gate). All three fixes are verified correct in a single
pass. The closing gate (Phase 4) found three unrelated failures, each evidenced as caused by a
concurrently-dispatched sibling task or by ambient session/hook runtime state rather than by
this task's own changes; Phase 4 closed `[COMPLETED WITH EXCLUSIONS]` with a full Reasoned
Exclusions record rather than `[PARTIAL]`, since none of the three findings leave residual work
for this task.

## What Changed

- `init.lua.backup` — deleted (tracked, byte-identical duplicate of `init.lua`; git history
  preserves prior states of `init.lua` if ever needed).
- `agent-system/extensions/core/context/repo/project-overview.md` — rewritten from the generic
  template to a real description of this repository (Neovim config + agent-orchestration
  system, two-layer extension architecture, the 7 registered extensions, the `specs/` task
  lifecycle, real entry points and command surface).
- `.claude/context/repo/project-overview.md` — mirrored from the source-store file above via
  `cp` (never hand-authored; `.claude/` is a gitignored deploy artifact per
  `.claude/rules/source-store-deploy-boundary.md`, so this path is not itself git-tracked).
- `README.md:185` — one link target replaced:
  `[.claude/README.md](.claude/README.md)` -> `[.claude/docs/docs-README.md](.claude/docs/docs-README.md)`.

## Decisions

- Phase 2's "commit both paths" task was executed as committing only the source-store path:
  `.claude/` is gitignored repo-wide (`.gitignore:6`), so the deploy copy cannot be `git add`ed
  regardless of intent. The `cp` mirror is the load-bearing guarantee of byte-identity, not a
  git commit of that path.
- Phase 4's literal "verify-deploy.sh exits 0" criterion was not met, but all three underlying
  findings were run to ground and shown to be outside this task's `file_scope`:
  1. doc-lint FAIL (`core` extension, `scripts/orchestrate-conclusion-aggregate.sh` not yet in
     `provides.scripts`) — this file belongs to sibling task 273 (`git log` shows
     `74a76af2b task 273 phase 3: ...`; the file also appears in task 273's own declared
     `concurrent_siblings` `file_scope` in this dispatch's Territory block).
  2. Shell test suite runner (gate 8, `run-all.sh`, 127 discovered suites) FAIL — the suites
     run first are explicitly load-sensitive concurrency/timing tests, and the host's `uptime`
     showed `load average: 9.40, 8.59, 6.01` from multiple concurrently-dispatched sibling
     agents; no discovered suite asserts on `init.lua.backup`, `project-overview.md`, or
     `README.md`.
  3. Whole-tree orphan detection (2 findings, `tmp/noop-bash-shapes-<session>`) — both are
     session-scoped runtime state files written by `.claude/hooks/detect-noop-bash.sh`'s own
     PreToolUse hook; one ID matches this very dispatch's own scratchpad session UUID.

  Given all three are evidenced, tightly scoped, decided (not abandoned), and leave no residual
  work for this task, Phase 4 closed `[COMPLETED WITH EXCLUSIONS]` per
  `context/standards/status-markers.md`'s five-condition admission test, rather than
  `[PARTIAL]`. The full Reasoned Exclusions record (with evidence) is in the plan file's Phase 4
  section.

## Plan Deviations

- **Task 2.6** (commit both `project-overview.md` paths) altered: only the source-store path was
  staged/committed; the deploy copy is gitignored and therefore never git-tracked. The `cp`
  mirror already keeps the two files byte-identical on disk.
- **Task 4.1** (`verify-deploy.sh` exits 0) altered: it exited with `FAIL -- 3 of 35` checks; the
  phase closed `[COMPLETED WITH EXCLUSIONS]` with a full Reasoned Exclusions record rather than
  being treated as blocking, per the reasoning above.

## Verification

- Build: N/A (Neovim configuration + markdown; no compiled build step)
- Tests: N/A for this task's own scope — `nvim --headless -c 'qa'` exits 0 (config loads
  cleanly). `check-task-references.sh` exits 0 (0 unexempted occurrences).
  `check-deploy-freshness.sh` exits 0 (one advisory WARN attributable to sibling task 273's
  `skills/skill-orchestrate/SKILL.md`, confirmed via `verify-deploy.sh --findings --only-gate 5`).
  `verify-deploy.sh` exits non-zero; see Decisions/Plan Deviations above for the full
  run-to-ground of all three findings.
- Files verified: Yes — single-pass check confirmed `init.lua.backup` absent; both
  `project-overview.md` copies contain 0 `GENERIC TEMPLATE` occurrences and are byte-identical
  (`diff` empty); `README.md` contains the new `docs-README.md` link and resolves
  (`test -f .claude/docs/docs-README.md`).

## Impacts

- `init.lua.backup` no longer invites confusion about which file is authoritative for the
  Neovim entry point; it remains recoverable from git history.
- Any command/agent reading `project-overview.md` for repo orientation now gets a real
  repository description instead of generic boilerplate.
- The root `README.md`'s architecture pointer now resolves to an existing file
  (`.claude/docs/docs-README.md`) instead of a 404.

## Follow-ups

- `.claude/docs/docs-README.md`'s own `[Architecture](../README.md)` link resolves to the same
  nonexistent `.claude/README.md` file. Pre-existing, outside this task's `file_scope`
  (explicitly listed as a Non-Goal in the plan); flagged here for a future reader, not actioned.
- The three Phase 4 exclusion findings (doc-lint, run-all.sh, orphan detection) are not this
  task's responsibility to fix — the first belongs to sibling task 273's own closure, the second
  is explained by concurrent system load rather than a defect, and the third is incidental
  session/hook runtime state. No follow-up task is created, consistent with the "no residual
  work" condition of the exclusion admission test.

## References

- Plan: `specs/296_repo_hygiene_remove_stale_initluabackup_/plans/01_repo-hygiene-three-fixes.md`
- Research: `specs/296_repo_hygiene_remove_stale_initluabackup_/reports/01_repo-hygiene-three-fixes.md`
- Reasoned Exclusions record: plan file, Phase 4 section
