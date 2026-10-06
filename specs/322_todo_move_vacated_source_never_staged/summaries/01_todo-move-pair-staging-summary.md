# Implementation Summary: Task #322

- **Task**: 322 - todo_move_vacated_source_never_staged
- **Status**: [COMPLETED]
- **Started**: 2026-10-05
- **Completed**: 2026-10-06
- **Effort**: ~4 hours (across two dispatch sessions)
- **Dependencies**: None (cross-references only: tasks 302, 318, 328 — not dependency edges)
- **Artifacts**: plans/01_todo-move-pair-staging.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`/todo`'s archival recipe performed directory moves but accumulated only each move's
destination into the commit pathspec, leaving every vacated source path's removal unstaged — a
verified regression from the explicit-pathspec migration, measured live at 173 unstaged ` D`
entries and a wrong `phantom_paths: 109` baked into committed state. This task paired both
endpoints of every move at all affected sites in both recipe copies (`commands/todo.md` and
`skill-todo/SKILL.md`), hoisted the invariant into `context/standards/git-staging-scope.md` as a
named rule, added a two-part regression suite (behavioral fixture plus static recipe-text
assertions) that fails on the pre-fix shape, and redeployed with the complete gate set passing
except for one pre-existing, out-of-scope failure.

## What Changed

- `agent-system/extensions/core/commands/todo.md` — three `stage_paths+=` sites (Step 5D, Step
  5E.1, Step 5F) changed from staging only the move destination to staging both the vacated
  source and the destination together, each with an inline anti-simplification comment citing
  the new standard section by name.
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` — introduced a `moved_paths[]`
  accumulator declared at the top of Stage 10, threaded through all seven of its move sites
  (three prose-level, four bash-level), and consumed by Stage 15's `git add`, which now stages
  `"${moved_paths[@]}"` explicitly and no longer stages a bare `specs/archive/` directory token.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — new
  `## Rename and Directory-Move Staging` section (positioned between `## Forbidden Operations`
  and `## Commit-Level Path Scoping and Cross-Process Serialization`) naming the invariant as a
  positive requirement, explaining the failure mode and why no existing gate catches an
  omission, and cross-referenced from `## Forbidden Operations`.
- `agent-system/extensions/core/scripts/tests/test-todo-move-pair-staging.sh` — new regression
  suite: a behavioral half (one paired case plus one dest-only negative control per affected
  site shape, run in a throwaway git fixture, asserting no unstaged ` D` entries, matching
  `delete mode`/`create mode` counts, and `phantom_paths: 0`) and a static half (asserting both
  recipes' real text, and the standard's text, actually use the pattern). One pre-existing bug
  in the inherited draft of this file — a stray literal backslash before a backtick in a grep
  pattern — was found and fixed during verification; the file now passes 41/41.
- `agent-system/extensions/core/manifest.json` — one-line `provides.scripts` addition
  declaring the new test file, required for the doc-lint deploy gate to recognize it as a
  declared (not stray) script.
- Redeployed `.claude/` copies of all five files, confirmed byte-identical to their source-store
  originals.

## Decisions

- Fixed the inherited test file's own grep-pattern bug (literal backslash before a backtick)
  rather than treating the resulting failure as a defect in `SKILL.md` — verified by inspecting
  the actual Stage 15 line text, which matched the intended literal form exactly.
- Verified the suite's detective power directly: reverted Phase 1's fix in a throwaway scratch
  copy of the source store (never the real file) and confirmed the suite's static assertion
  correctly goes red, proving it would have caught the live regression.
- Investigated rather than assumed attribution for two "NEW" full-suite failures surfaced by
  `run-all.sh`/`verify-deploy.sh`: confirmed both are pre-existing and out of this task's scope
  by (a) stashing an unrelated pre-existing uncommitted change in the orchestrator
  cycle-planning script and reproducing the identical failure count with it removed, and (b)
  confirming the other failure sits in a wholly different extension (typst) with no file-scope
  overlap. Recorded the attribution in the plan rather than fixing either out-of-scope issue.

## Plan Deviations

- **Phase 5** altered: one additional one-line fix-forward edit was required in
  `agent-system/extensions/core/manifest.json` (declaring the new test script in
  `provides.scripts`) beyond the plan's originally-scoped four files, needed for the doc-lint
  gate to pass. No behavioral content was added — a pure declaration entry.

## Verification

- Build: N/A (markdown/shell, no compiled artifact)
- Tests: `test-todo-move-pair-staging.sh` 41 passed, 0 failed. `scripts/tests/run-all.sh
  --quiet --jobs auto` (117 suites): 111 passed, 4 failed, 2 skipped — the new suite passes;
  2 failures are pre-existing/expected, 2 are pre-existing/out-of-scope (confirmed by
  attribution investigation, not assumed).
- Files verified: Yes — all four source-store edits plus the manifest.json declaration,
  redeployed and byte-identical in `.claude/`.
- Lints: `lint-directory-pathspec-boundary.sh` (0 violations across 1248 files),
  `lint-scoped-commit-boundary.sh` (0 violations across 1248 files), `check-task-references.sh`
  (0 unexempted occurrences) all pass clean.
- `verify-deploy.sh` (full gate set): `FAIL -- 1 of 34 check(s) failed`, the one failure being
  Gate 8 (`run-all.sh`), itself attributable entirely to the two pre-existing, out-of-scope
  failures above — not to anything introduced by this task. All 33 other checks pass clean.

## Impacts

- The next `/todo` archival run that moves at least one task directory will stage both the
  vacated source's removal and the new destination together, closing the measured defect
  (unstaged ` D` entries, missing `delete mode` records, inflated `phantom_paths`).
- The named standard section gives future readers (and future static checks) a citable rule
  for any new rename/move call site added to either recipe.
- The new regression suite is discovered automatically by `run-all.sh`'s glob and will fail
  loudly if either recipe's pairing is ever simplified back to a single-token or
  bare-directory pathspec.

## Follow-ups

- **Live confirmation deferred by design** (stated in the plan's own Testing & Validation
  section, not hidden): the next real `/todo` archival run should show
  `git status --porcelain | grep '^ D specs/'` as empty. This cannot be executed by this task
  because `/todo` is an agent-executed markdown recipe with no scripted entry point.
- Two pre-existing, unrelated full-suite failures remain open, out of this task's scope: one in
  the orchestrator cycle-planning script's stranded-dispatch/identical-dispatch-halt test
  coverage (a feature gap between the committed test file and the script under test), and one
  advisory-threshold case in a different extension's element-density lint suite. Neither is
  introduced or worsened by this task.
- Whether the too-narrow-pathspec detection this suite's static half performs is worth
  promoting to a repo-wide lint remains an open question for a separate, already-identified
  piece of work on lint-gate wiring; this task deliberately did not pre-empt that question.

## References

- `specs/322_todo_move_vacated_source_never_staged/plans/01_todo-move-pair-staging.md`
- `specs/322_todo_move_vacated_source_never_staged/reports/01_todo-move-vacated-source-staging.md`
- `agent-system/extensions/core/context/standards/git-staging-scope.md`
