# Implementation Summary: Task #324

**Completed**: 2026-10-02
**Duration**: ~30 minutes

## Overview

`verify-deploy.sh` gate 13 (whole-tree orphan detection) false-positived on
`.claude/scheduled_tasks.lock`, a session-acquired runtime lock file (contents: `sessionId`,
`pid`, `acquiredAt`) written by the external scheduled-task mechanism at execution time, never by
the copy engine — exactly the class `is_runtime_artifact()` already whitelists for
`tmp/workflow-active-*`, `RESUME.md`, `__pycache__/`, and the literature venv, but with no
matching branch. Added one exact-match branch to `is_runtime_artifact()`, extended the
companion exclusion-classes doc in the source store, and added a planted-lock regression
assertion (as Assertion F — letter E was already taken) with a negative control proving the
assertion is actually wired to the new branch.

## What Changed

- `lua/neotex/plugins/ai/shared/extensions/verify.lua` — added one exact-match branch
  (`rel == "scheduled_tasks.lock"`) plus a one-line comment to `is_runtime_artifact()`.
- `agent-system/extensions/core/context/patterns/deploy-orphan-detection.md` — extended the
  Runtime-artifact exclusion row's Examples cell and explanation with the new class member;
  clarified (rather than altered) the trailing gitignore claim after re-verification (source
  store only; deployed `.claude/` copy confirmed untouched).
- `agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh` — added a new planted
  scenario and Assertion F (plant `.claude/scheduled_tasks.lock` with realistic JSON content,
  assert it is excluded from `ORPHAN_FINDING` output), updated the header comment and the
  "A/B/C/D" literal strings to "A/B/C/D/F".

## Decisions

- Exact-match pattern, not a glob: research confirmed no sibling `*.lock` family exists under
  `.claude/`, and the doc's own anti-speculation principle rules out a preemptive glob.
- New assertion labelled **F**, not **E** as the dispatch/plan anticipated: re-reading the test
  harness surfaced that letter E is already used by the pre-existing no-false-positive baseline
  assertion (`Assertion E: unmodified scratch regenerate baseline`), which the plan's line-number
  estimate did not account for. Used F to avoid colliding with an existing label; documented the
  substitution inline in the harness and in the plan's checklist annotations.
- Re-verified the research report's aside that `scheduled_tasks.lock` is "not currently
  gitignored at the project root" directly with `git check-ignore -v`, which showed the file IS
  caught by the blanket `/.claude/` gitignore rule. Left the doc's trailing claim intact (it
  remains accurate) and added a parenthetical clarifying the mechanism instead of changing its
  truth value.
- **Task-250-vs-317 paper-trail correction**: re-confirmed per the dispatch's cross-reference
  instruction. The phrase "a sandbox orphan tmp file" cited in the dispatch lives in task 317's
  archived artifacts, not task 250's, and names a different file
  (`tmp/noop-bash-count-...`), unrelated to `scheduled_tasks.lock`. This is a documentation
  correction only; it changes nothing about the fix.

## Plan Deviations

- **Phase 2, gitignore-claim task** altered: re-verified rather than blindly trusting the
  research's aside; the claim was accurate, so it was clarified with a parenthetical rather than
  rewritten.
- **Phase 3**, three items altered: the new scenario/assertion is labelled F, not E, because E
  was already in use by the pre-existing baseline assertion.
- **Phase 4**, one item altered: the observed overall gate count after the fix was 2-of-33 (gate
  3 + gate 5), not the hypothesized 1-of-33 or 0-of-33. Investigated per the plan's Scope
  Hypothesis rather than rounded away — see Verification below.

## Verification

- `bash agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh`: 6 passed, 0 failed
  (baseline + A + B + C + D + F), exit 0.
- Negative control: with the `verify.lua` branch temporarily stubbed out, Assertion F failed as
  expected (5 passed, 1 failed); branch restored byte-identical to its committed form (confirmed
  via `git status --short` showing no diff) and re-run returned to 6 passed/0 failed.
- `verify-deploy.sh --skip-slow`, run with a placeholder `.claude/scheduled_tasks.lock` present
  (realistic `sessionId`/`pid`/`acquiredAt` JSON): **gate 13 PASS** — "no deployed-but-undeclared
  files or ghost context/index.json rows". No `ORPHAN_FINDING` line mentioned
  `scheduled_tasks.lock`. Gate 13's genuine-orphan behavior unchanged (the harness's Assertion A
  still reports the planted canary).
- Overall count observed: **2 of 33 failed** — gate 3 (doc-lint) and gate 5 (manifest-driven
  parity: "Content differs from source" for the two source-store files this task edited, plus
  "Missing scripts: scripts/migrate-state-legacy-fields.sh"). This does not match either
  hypothesized outcome (1-of-33 or 0-of-33), so per the plan's Scope Hypothesis it was
  investigated rather than rounded:
  - The "Content differs from source" findings are the expected, transient drift between this
    task's own just-committed source-store edits and the live (gitignored, undeployed) `.claude/`
    tree. Per `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`'s
    two "Automated Exception" sections, redeploying the live tree from an implementation agent is
    NOT a sanctioned call site — redeploy is driven automatically by the orchestrator's postflight
    completion-deploy gate (`command-gate-out.sh`'s `rc == 6` branch /
    `commands/implement.md` Step 4) once this task's `modified_files` are reported. Left
    unresolved here by design; expected to self-heal on the next postflight redeploy.
  - The "Missing scripts" finding is concurrent sibling task 323's own in-flight state, confirmed
    (not assumed) via `git log --oneline -- agent-system/extensions/core/manifest.json`, which
    shows `ffa70bd9e task 323 phase 1: declare the script in provides.scripts` as the most recent
    commit to that file — the sibling declared the script in the manifest but has not yet
    redeployed it. Unrelated to this task's change.
  - This task's actual target, gate 13, is unambiguously green with the lock present — the
    dispatch's acceptance criterion is satisfied regardless of the unrelated gate-5 drift.
- `git status --short -- .claude/` / `.claude/context/patterns/deploy-orphan-detection.md`:
  confirmed no modification to any file under `.claude/` from this task's edits. The placeholder
  `.claude/scheduled_tasks.lock` created for the Phase 4 check was removed afterward; no stray
  file remains.
- No task-number reference introduced in any file outside `specs/**`.

## Notes

- Territory: this task's sibling (323) owns `agent-system/extensions/core/manifest.json` and
  `README.md` — disjoint from this task's `deploy-orphan-detection.md` and
  `test-deploy-orphans.sh`. No collision observed during implementation; the sibling's commit
  (`ffa70bd9e`) was inspected via `git log`, not touched.
- `scheduled_tasks.lock`'s git-tracking status (it IS covered by the blanket `/.claude/`
  `.gitignore` rule, contrary to the research report's aside) is noted here for the record but
  required no change — it was already an out-of-scope aside in the research report and remains
  one.
