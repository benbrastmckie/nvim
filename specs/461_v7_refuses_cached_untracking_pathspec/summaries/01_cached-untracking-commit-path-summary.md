# Implementation Summary: Task #461

- **Task**: 461 - Rule on and close the V7 refusal of a positive directory pathspec for a `git rm --cached` untracking whose content is still on disk
- **Status**: [COMPLETED]
- **Started**: 2026-11-10T21:30:00Z
- **Completed**: 2026-11-10T22:44:36Z
- **Effort**: ~1.25 hours
- **Dependencies**: 328, 430, 435, 446, 448 (SERIALIZATION-only or OPERATOR-LIFTABLE; none contested the ruling)
- **Artifacts**: plans/01_cached-untracking-commit-path.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Implemented the plan's ruling (option 2): the `--cached` untracking shape — index deletions whose
content remains present on disk — now has its own narrow, textually distinct classification in
`git-commit-scoped.sh`, kept separate from the existing fully-staged-deletion (directory-move)
carve-out. All five plan phases landed: classification before `git add` (Phase 1), a guarded
bare-commit path plus a V8 intent-snapshot correction (Phase 2), a six-case regression cluster
with a FAILS-before/PASSES-after demonstration (Phase 3), a durable documentation record and
header finding-list entry (Phase 4), and a redeploy with end-to-end confirmation (Phase 5).

## What Changed

- `agent-system/extensions/core/scripts/git-commit-scoped.sh` — added `is_cached_untracking_shape()`
  (Verified Finding V11, a five-conjunct enumerate-and-verify predicate), a new
  `cached_untracking_pathspecs` ledger, a new V2-loop case routing a matching pathspec into
  `filtered_pathspecs` only (never `add_pathspecs` or `dropped_pathspecs`); a V12 index-equivalence
  guard and a `run_scoped_commit` helper selecting a bare `git commit` for the cached-untracking
  shape (proven scope-equivalent before use, refusing with exit 2 on any foreign staged content);
  a `v8_cached_untracking_members` correction to the V8 pre-commit intent snapshot so a correctly
  committed untracking is recorded as `absent`, never hashed; a distinct stderr NOTE; and two new
  header finding-list entries (V11, V12) summarizing the shape and its resolution.
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` — added
  `build_repo_cached_untracked` harness helper and a six-case `Y1`-`Y6` cluster: the headline
  gitignored regression, the non-gitignored silent-revert pin, NOTE-distinctness, the
  partial-untracking rejection, the out-of-repository (V9) interaction pin, and the
  foreign-staged-content refusal.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — added a new
  "Cached-Untracking Staging" section (Rule / Failure mode this rule prevents / Why no existing
  gate catches it / Identifying this shape in a log / Canonical illustration), documenting the
  sanctioned recipe and both historical symptom texts.
- Deployed `.claude/` tree — regenerated via `deploy-headless.sh`; all three changed files
  confirmed byte-identical to their source-store originals.

## Decisions

- **The ruling is option (2)**, not (1) or (3): the untracking shape gets its own carve-out,
  sited BEFORE `git add` (not in the post-add V7 loop the task description initially framed as
  the fix site), because only a pre-add intervention can stop the non-gitignored silent-revert
  symptom. V7's own exact-exit-code (1/0/128) discrimination is left completely untouched.
- A single predicate change is insufficient: the shape needed handling at three points
  (classification, the commit invocation itself via a guarded bare commit, and the V8 intent
  snapshot) because no pathspec-scoped `git commit -- <paths>` form — directory, explicit file
  list, or `--only` — can express a deletion whose content remains on disk (`--only` semantics
  re-read the working tree fresh at commit time).
- Y3's NOTE-distinctness test asserts absence of the OTHER note's own wording rather than a blind
  substring search for "source half of a directory move", since the new NOTE's own text contains
  that phrase in negated form by design (see Plan Deviations).

## Plan Deviations

- **Phase 2 / Phase 3 (clarification, not a defect)**: the new NOTE's text states "this is NOT
  the source half of a directory move" per the phase's own task instruction, which necessarily
  contains that phrase in negated form. Phase 3's NOTE-distinctness case therefore asserts absence
  of the OTHER note's own distinguishing wording ("accepted ... positive pathspec(s) as
  fully-staged deletions") rather than a literal substring search for the shared phrase.
- **Phase 3**: 6 new cases (`Y1`-`Y6`), not the Scope Hypothesis's estimated 7 — every Tasks-list
  bullet and VERIFY-section requirement is covered by 6; "confirm W1/W3 unchanged" is satisfied by
  the existing suite passing rather than a new case.
- **Phase 5 (altered, per the dispatch's Batch Gate Deferral directive)**: the plan's literal
  "run the complete gate set, no `--only-gate` narrowing" instruction was superseded by this
  dispatch's own Batch Gate Deferral directive for a final phase declaring
  `**Verification Tier**: full`. The phase was discharged against the scoped `run-all.sh --only`
  16-suite covering set (14 passed, 2 failed — the same 2 pre-existing out-of-scope failures
  already recorded below) rather than an independently-run full gate. An exploratory full
  `verify-deploy.sh` run was performed anyway; its 4 failures were all root-caused to
  cross-task noise from this same `/orchestrate` batch's concurrently-scheduled sibling tasks
  (gate-lock contention, ambient load, and orphan/dead-command findings entirely inside the
  memory extension's territory) or an already-documented pre-existing finding — none attributable
  to this task's own three changed files. Full detail in `progress/phase-5-progress.json`.

## Verification

- Build: N/A (shell scripts; `bash -n` exits 0 on both edited scripts)
- Tests: `test-git-commit-scoped.sh` — 76 passed, 0 failed (70 pre-existing + 6 new). FAILS-before
  demonstration confirmed 5 of the 6 new cases fail against the pre-Phase-1 script (71 passed, 5
  failed), proving the regression suite actually exercises this fix.
- Files verified: Yes — deployed tree confirmed byte-identical to the source store for all three
  changed files.
- REQUIRED OUTCOME: confirmed end-to-end against the deployed script in a scratch repo —
  `git rm -r --cached <dir>` followed by an ordinary `git-commit-scoped.sh ... -- <dir>` commits
  cleanly with no relocation at any point.
- Pre-existing, out-of-scope suite failures observed and recorded (not fixed, not in this task's
  `file_scope`): `test-orchestrate-cycle-postflight.sh` and `test-redeploy-checkpoint-promotion.sh`
  (verified identical failure counts against the unmodified pre-Phase-1 script).

## Impacts

- An agent can now commit a `git rm -r --cached <dir>` untracking directly, in both the
  gitignored and non-gitignored cases, without relocating any file out of the working tree — the
  REQUIRED OUTCOME the originating report asked for.
- `context/standards/git-staging-scope.md` now carries a durable, discoverable record of the
  shape, its two symptom texts, and the sanctioned recipe, so a future agent does not re-derive
  the relocate-the-directory workaround.
- No change to V7's own exact-exit-code discrimination, the gitignore-advisory tolerance, the
  `add_exclude_pathspecs` handling, `git-commit-phase.sh`, or the settled bare-directory-pathspec
  policy — all explicitly out of scope and left untouched.

## Follow-ups

- None required by this task. The 4 cross-task-noise findings from the exploratory full
  `verify-deploy.sh` run (gate-lock contention, a gate-10 timeout, memory-extension orphans, and
  a memory-extension dead-command-recommendation finding) are recorded in the issue log for
  visibility; none require action from this task, and the memory-extension findings are already
  inside a concurrently-scheduled sibling task's own territory.

## References

- Plan: `specs/461_v7_refuses_cached_untracking_pathspec/plans/01_cached-untracking-commit-path.md`
- Report: `specs/461_v7_refuses_cached_untracking_pathspec/reports/01_v7-cached-untracking-ruling.md`
- Progress files: `specs/461_v7_refuses_cached_untracking_pathspec/progress/phase-{1..5}-progress.json`
- Handoffs: `specs/461_v7_refuses_cached_untracking_pathspec/handoffs/phase-{1..4}-handoff-*.md`
