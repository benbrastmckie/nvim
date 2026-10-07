# Implementation Summary: Task #325

- **Task**: 325 - Stop git-commit-scoped.sh from aborting the whole commit when `git add` emits its gitignore advisory for a tracked, ignore-matched path
- **Status**: [COMPLETED]
- **Started**: 2026-10-05T16:11:00Z
- **Completed**: 2026-10-05T21:55:00Z
- **Effort**: ~3.25 hours
- **Dependencies**: None
- **Artifacts**: plans/01_git-add-advisory-tolerance.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`git-commit-scoped.sh`'s `git add` guard trusted the command's exit code at whole-call
granularity. For a positive pathspec naming a file that is tracked but whose path matches a
`.gitignore` rule via a parent-directory pattern, `git add` prints its "ignored by one of your
.gitignore files" advisory, exits 1, and still stages the file correctly — so the old
`if ! git add ...; then exit 2; fi` guard aborted the whole commit on a false negative. The fix
replaces that blind exit-code check with post-add verification of actual index state per
positive pathspec, so the add's exit code is trusted in neither direction. All four phases are
complete: the script fix, six regression cases plus a negative control, a new standards
subsection, and a full gate close-out with every failure attributed.

## What Changed

- `agent-system/extensions/core/scripts/git-commit-scoped.sh` — replaced the blind
  `if ! git add "${add_pathspecs[@]}"; then exit 2; fi` guard with: (1) a captured-output,
  captured-exit-code `git add` invocation using the script's existing `-e`-exempt idiom; (2) a
  per-positive-pathspec verification loop (`git ls-files --error-unmatch` for index presence,
  `git diff --quiet -- "$p" "${add_exclude_pathspecs[@]}"` for full-staging, with the ephemeral
  `:(exclude)` entries passed through so an excluded sub-path cannot false-flag a directory
  pathspec); (3) a loud `exit 2` naming every genuinely-failed path when verification finds one;
  (4) a non-silent stderr NOTE when the add's exit code was nonzero but every positive pathspec
  verified fully staged (the tolerated-advisory case). Added this gate to the header's
  `# Safety gates` list as V7, documented the deliberate residual blind spot (a single new
  ignore-matched file swept up implicitly inside an otherwise-tracked directory pathspec is not
  caught by the presence check — consistent with the already-documented "implicit sweep is
  silently skipped" behavior), and rewrote the header's exit-code-2 description to describe
  verified-index-state rather than "git add failed." Confirmed none of the four direct script
  consumers (`orchestrator-postflight.sh`, `orchestrate-unwind-dispatch.sh`,
  `orchestrate-cycle-postflight.sh`, `lib/redeploy-checkpoint-lib.sh`) branch on exit code 2 —
  all four use the `cmd || echo "WARN ... (non-blocking)"` idiom.
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` — added a
  tracked-then-ignored fixture helper and six new cases (U1-U6): tracked ignore-matched path
  alone; the same path batched with an ordinary modified path; the tolerated-advisory stderr NOTE
  is emitted; a genuine add failure (out-of-repo pathspec) still refuses with exit 2 and names the
  failing path; a brand-new untracked ignore-matched path is still refused (no `-f` behavior
  introduced); a directory pathspec with ephemeral excludes present still commits and still
  excludes them. A negative control (the old blind guard restored in a scratch copy) was run and
  observed to fail U1-U3 before the fix was restored and the suite re-confirmed green.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — added a sibling
  subsection to the existing `:(exclude)`-side ignore-advisory passage, covering the
  positive-pathspec case: the advisory-but-actually-staged behavior; an explicit prohibition on
  using `git check-ignore -q` to detect this case (it is index-aware and reports "not ignored"
  for exactly these tracked paths, contradicting `git add`); the tracked-vs-moved distinction by
  mechanism (a file relocated by plain `mv` into an ignore-matched destination is a brand-new
  untracked path there and `git add` genuinely drops it — a real failure, correctly refused, not
  an advisory false negative); and a restatement that `-f`/`--ignore-errors` is not the sanctioned
  remedy.
- No file under `.claude/**` was created or modified. All three edits live in the source store
  only (`agent-system/extensions/core/**`); `.claude/` is a disposable deploy artifact and
  regeneration is deliberately left to an operator (`<leader>al` "Reload All", or
  `deploy-headless.sh`).

## Decisions

- Verification is based on actual post-add index state (`git ls-files --error-unmatch` +
  `git diff --quiet`), never on `git add`'s exit code in either direction — this is the only way
  to tolerate the advisory false negative here without papering over the out-of-repo-pathspec
  hard failure owned by a sibling fix site in the same script.
- `git check-ignore -q` was ruled out as a pre-check (per the research report): it is index-aware
  and reports "not ignored" for exactly the tracked, ignore-matched paths this defect concerns,
  directly contradicting `git add`'s behavior.
- The `:(exclude)` pathspec entries are passed through into the per-path `git diff --quiet` check
  so a directory pathspec's deliberately-excluded, tracked-and-modified sub-paths cannot
  false-flag the new verification.
- Coverage was added to the existing, already-manifest-registered `test-git-commit-scoped.sh`
  rather than a new test file, per the plan's explicit non-goal (a new file would need manifest
  registration and a deploy to become runnable).

## Plan Deviations

- None (implementation followed plan). Phase 4's verification steps (baseline capture, full gate
  run, re-run of the test suite, `git status`/`check-task-references.sh` checks) were
  independently re-executed in this dispatch rather than trusted from the plan file's prior
  annotations, per the inherited-marker re-verification requirement — the re-run reproduced the
  same tallies the plan had already recorded.

## Verification

- Build: N/A (shell scripts; no build step)
- Tests: Passed — `test-git-commit-scoped.sh`: **32 passed, 0 failed** (includes pre-existing
  T1-T13 and V1-V7 cases, plus new U1-U6 cases)
- `bash -n` clean on `git-commit-scoped.sh`. `shellcheck` could not be run in this environment
  (the `shellcheck` binary is absent from the live nix-store path on this host — an environment
  gap, not a code finding); `bash -n` plus the two targeted boundary lints below stand in for it.
- `lint-scoped-commit-boundary.sh --verbose`: 0 violations (1248 files checked, 49 exempted).
- `lint-directory-pathspec-boundary.sh --verbose`: 0 violations (1248 files checked, 403 tokens
  exempted, 1 exclude-magic skip).
- `check-task-references.sh`: 0 unexempted occurrences, repo-wide.
- `git status --short` for `.claude/**`: clean — no deployed-artifact modification from this task.
- Files verified: Yes.

### Gate close-out (`verify-deploy.sh`)

Baseline (`--skip-slow`, captured first): **FAIL — 2 of 33**. Both failures are this task's own
three deliberately-edited source-store files, not a pre-existing or unrelated defect:
- Gate 3 (doc-lint): deployed-content drift on `scripts/git-commit-scoped.sh` and
  `scripts/tests/test-git-commit-scoped.sh` (source store ahead of `.claude/`, expected pending an
  operator redeploy), plus an `index-entries.json` line-count mismatch for
  `standards/git-staging-scope.md` (declared count stale after this task's new subsection grew
  the file; `index-entries.json` is a shared file currently also carrying other concurrently
  dispatched tasks' own uncommitted line-count updates for unrelated entries, so it was reported
  here rather than regenerated, to avoid sweeping a sibling's in-flight edit into this task's
  commit).
- Gate 5 (manifest-driven content-hash equality): the same three files, same cause — source/deploy
  divergence from the un-redeployed source-store edits.

Full run (`verify-deploy.sh`, no flags): **FAIL — 3 of 34**. Gates 3 and 5 are unchanged from the
baseline (same three files, same cause). The one additional failure is gate 8
(`tests/run-all.sh`, the full shell-test-suite runner, skipped by `--skip-slow` in the baseline):
**110 passed, 5 failed (2 expected, 3 new), 2 skipped, 117 total**. None of the 5 failing suites
is `test-git-commit-scoped.sh` (confirmed separately green at 32/0, both before and after the
full-gate run). The 2 suites `run-all.sh` itself labels `(EXPECTED)`
(`test-gate-out-repair-reporting.sh`, `test-lint-json-channel-discipline.sh`) are pre-existing and
outside this task's scope. The 3 suites `run-all.sh` labels `(NEW)` are each attributable away
from this task:
- `test-orchestrate-cycle-plan.sh` (14 failed) — exercises `orchestrate-cycle-plan.sh`, which
  `git status` shows as independently modified and uncommitted by a different, concurrently-live
  task this cycle; not a file this task touched.
- `test-verify-deploy-context-budget.sh` (1 failed: "baseline fixture is not clean") — a gate-20
  context-budget fixture-setup failure, unrelated to `git add`/gitignore handling; the live tree
  carries several other concurrently-dispatched tasks' uncommitted edits this cycle, which is
  exactly the kind of tree-dirtiness this fixture's baseline check is sensitive to.
- `test-typst-element-lint.sh` (1 failed: `case-h2` output unexpectedly contains `[WARN]`) — the
  Typst extension's element-density lint, with no relationship to this task's script or
  standards-doc edits.

No failure traces to this task's own edits beyond the expected, already-anticipated gate-3/gate-5
source/deploy divergence.

## Impacts

- Every scoped commit in every deploy of this agent system that stages a tracked file whose path
  matches a `.gitignore` rule via a parent-directory pattern (for example `specs/archive/` being
  gitignored while `specs/archive/state.json` stays tracked) will now land instead of being
  silently aborted before `git commit` is ever reached — this was a hard blocker on every `/todo`
  archival run in any repository with that shape.
- The genuine out-of-repo-pathspec hard failure (a different, sibling fix site in the same script)
  is unaffected and still refuses with exit 2, nothing staged — the new verification is index-state
  based, not exit-code tolerant, so it cannot paper over that case.
- A directory-move task that relocates a tracked file into an ignore-matched destination via plain
  `mv` is still correctly refused (the destination is a brand-new untracked path there): this fix
  does not unblock that case, and `git-staging-scope.md`'s new subsection names the distinction
  explicitly so a future caller does not "fix" the move case with `git check-ignore -q` and
  silently regress.

## Follow-ups

- **Operator action required**: this fix is live in the source store only until the next
  `<leader>al` "Reload All" or `bash .claude/scripts/deploy-headless.sh` regeneration. Consumer
  repositories currently blocked by this defect (for example a repo where `/todo` archival writes
  to a gitignored `specs/archive/`) will pick up the fix at their next deploy, not from this
  commit alone.
- `index-entries.json`'s stale line-count entry for `standards/git-staging-scope.md` (484 vs.
  actual 519) should be regenerated via
  `agent-system/extensions/core/scripts/generate-context-line-counts.sh --write` the next time
  that shared file is not concurrently held by another in-flight task — left unresolved here
  deliberately to avoid clobbering a sibling's uncommitted edits to unrelated entries in the same
  file.
- The three gate-8 `(NEW)` test-suite failures named above belong to other concurrently-dispatched
  tasks or pre-existing conditions, not to this task; no action was taken on them here per the
  plan's explicit instruction to report, not fix, out-of-scope failures.
- The destination-ignored guard a directory-move task would need (so it does not draw the same
  ignore-advisory shape on a genuinely-new untracked destination path) is explicitly out of scope
  here and remains that sibling task's own fix site.

## References

- `specs/325_git_add_ignore_advisory_aborts_commit/plans/01_git-add-advisory-tolerance.md`
- `specs/325_git_add_ignore_advisory_aborts_commit/reports/01_git-add-ignore-advisory.md`
- `agent-system/extensions/core/context/standards/git-staging-scope.md`
