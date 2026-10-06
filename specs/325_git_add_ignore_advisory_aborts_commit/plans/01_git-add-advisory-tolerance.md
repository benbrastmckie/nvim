# Implementation Plan: Task #325

- **Task**: 325 - Stop git-commit-scoped.sh from aborting the whole commit when `git add` emits its gitignore advisory for a tracked, ignore-matched path
- **Status**: [IMPLEMENTING]
- **Effort**: 3.25 hours
- **Dependencies**: None (siblings 304 and 322 share the script but have distinct fix sites — see Non-Goals)
- **Research Inputs**: specs/325_git_add_ignore_advisory_aborts_commit/reports/01_git-add-ignore-advisory.md
- **Artifacts**: plans/01_git-add-advisory-tolerance.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/rules/source-store-deploy-boundary.md
  - .claude/rules/no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`git-commit-scoped.sh` trusts `git add`'s exit code at whole-call granularity. For a positive
pathspec naming a file that is **tracked** but whose path matches a `.gitignore` rule via a
parent-directory pattern, git prints the "ignored by one of your .gitignore files" advisory, exits
**1**, and **still stages the file correctly** — so the script's `if ! git add ...; then exit 2; fi`
guard aborts before `git commit` is ever reached, and no commit is made at all. The fix replaces
that blind exit-code check with a post-add verification of **actual index state** per positive
pathspec: the add's exit code is trusted in neither direction, and the commit proceeds only when
every positive entry demonstrably landed. This is deliberately a single-site change inside the
`git add` step of one script, plus regression coverage and one standards-doc subsection.

Definition of done: a scoped commit naming a tracked, ignore-matched path lands (verified via
`git log`/`git show`, not exit code); a genuine add failure — nothing staged — still refuses with
exit 2 and names the failing path(s); the regression suite proves both, and fails when the fix is
stubbed out.

### Research Integration

Four findings from `reports/01_git-add-ignore-advisory.md` are load-bearing here:

1. **The defect shape**: the advisory exit 1 is a false negative; the file *is* staged. Reproduced
   independently in an isolated scratch repo on git 2.54.0.
2. **`git check-ignore -q` cannot be used** as a pre-check: it is index-aware and reports
   "not ignored" (exit 1) for exactly the tracked paths this defect is about, directly
   contradicting `git add`. The fix must therefore be post-add, on actual index state — never a
   smarter pre-check, and never `-f`/`--ignore-errors` (which would also force-add genuinely
   untracked, genuinely-should-stay-ignored paths).
3. **The advisory is per-path-transparent within a batch**: a valid sibling path in the same
   `git add` call still lands. By contrast, the out-of-repo-pathspec trigger owned by the sibling
   task at the Case 1 admission predicate is a hard `fatal:` (exit 128) that stages **nothing**,
   including valid siblings. The two therefore need different fixes, and this plan must not
   paper over the hard-failure case — hence verifying index state rather than tolerating the
   exit code.
4. **The directory-move sibling task cannot rely on this fix**: a file moved by plain `mv` into an
   ignore-matched destination is a brand-new *untracked* path at that destination and `git add`
   genuinely drops it. The post-add verification below correctly flags that as a genuine failure
   rather than silently accepting it, so no change here unblocks that case. Phase 3 records the
   tracked-vs-moved distinction durably in `git-staging-scope.md` (by mechanism, with no
   task-number reference).

### Prior Plan Reference

No prior plan. `plans/` is empty; this is round 1.

### Roadmap Alignment

No `roadmap_path` and no `roadmap_flag` were provided in this dispatch, so `specs/ROADMAP.md` was
not consulted and no roadmap-review/roadmap-update phases are included.

## Goals & Non-Goals

**Goals**:
- Stop a tracked, ignore-matched positive pathspec from aborting the whole scoped commit.
- Base the add's success/failure decision on verified index state per positive pathspec, not on
  `git add`'s exit code in either direction.
- Preserve the existing refusal (exit 2, nothing committed) for a **genuine** add failure, and
  name exactly which path(s) failed and why.
- Make the tolerated-advisory path observable (a stderr NOTE), never silent.
- Durable regression coverage in the existing suite, including a negative control.
- Record the positive-pathspec side of the ignore-advisory hazard in `git-staging-scope.md`, so a
  future caller does not "fix" it with `git check-ignore -q` and silently regress.

**Non-Goals**:
- Any change to the V2 classification loop (the Case 1 admission predicate) — that is the
  out-of-repo-pathspec sibling task's fix site, and its hard `fatal:` failure must keep failing.
- Any change to the `/todo` directory-move staging call sites — the move-destination sibling task's
  fix site, which needs its own destination-ignored guard.
- Any use of `git add -f` or `--ignore-errors`.
- Any `.claude/**` edit. `.claude/` is a disposable deploy artifact regenerated from the source
  store; regeneration (`<leader>al` "Reload All", or `deploy-headless.sh`) is an operator action
  deliberately left outside this task — the more so because sibling tasks are live on this working
  tree this cycle and a regeneration would sweep in their in-flight edits.
- The adjacent `hooks/guard-destructive-git.sh` `git add --dry-run` directory-pathspec concern
  (explicitly out of scope per the dispatch).
- Any new test *file* (a new file would need manifest registration and a deploy to become
  runnable); coverage goes into the already-registered `test-git-commit-scoped.sh`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A naive "tolerate `git add`'s exit code" fix papers over the sibling out-of-repo-pathspec hard failure | H | M | The fix never tolerates an exit code; it verifies per-path index state. Phase 2 asserts the hard-failure case (exit 128, nothing staged) still refuses with exit 2 |
| `git diff --quiet -- "$p"` false-flags a directory pathspec whose excluded sub-path is tracked and modified | M | M | Pass the `:(exclude)` entries from `add_pathspecs` alongside the positive entry in the diff check, so excluded sub-paths are not counted; Phase 2 covers a directory pathspec with ephemeral excludes present |
| `set -euo pipefail` aborts on the now-captured failing `git add` before the exit code can be inspected | H | M | Use the script's own established `-e`-exempt idiom: `if out=$(cmd); then rc=0; else rc=$?; fi` — the same shape already used for `git commit` below it |
| `set -u` trips on an empty-array expansion of the new exclude/failed-path arrays | M | M | Guard every expansion behind a `${#arr[@]}` test or `${arr[@]+...}`, the pattern already used for `dropped_pathspecs` |
| Editing the deployed copy instead of the source store | M | L | The source-store path is named in every phase; Phase 4 verifies `git status --short` shows no `.claude/**` modification, and the test suite resolves scripts from the source store so no deploy is needed to run it |
| `verify-deploy.sh` gate 5 (source/deploy content-hash equality) fails because the source store is now ahead of `.claude/` | L | H | Expected and explained, not a regression: Phase 4 captures the pre-change baseline FAIL set first and attributes any gate-5 divergence to the deliberate, un-deployed source edit; redeploy stays an operator action |
| A concurrent sibling's edits confound the gate baseline | M | H | Phase 4 compares against a baseline captured in the same session and attributes each failure to a named file; a failure in a file outside this task's scope is reported, not "fixed" |
| A task number leaks into a deliverable file | M | L | Run `check-task-references.sh` in Phases 1, 3 and 4; refer to siblings by mechanism and fix site, never by number |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Replace the blind `git add` exit-code check with post-add index verification [COMPLETED]

**Goal**: `git-commit-scoped.sh` decides add success from verified index state per positive
pathspec, tolerating the gitignore-advisory false negative while still refusing a genuine failure,
with the script's own header documentation extended to match.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/git-commit-scoped.sh` immediately before
      editing (a sibling task is live on this tree this cycle). The fix site is the
      `# --- git add (guarded; ...) ---` block (currently the `has_positive_pathspec` /
      `if ! git add "${add_pathspecs[@]}"` guard around lines 388-401) — confirm the anchor text
      rather than trusting the line number. *(completed)*
- [x] Split `add_pathspecs` into two local arrays inside the guarded block:
      `add_positive_pathspecs` (non-`:(exclude)` entries) and `add_exclude_pathspecs`
      (`:(exclude)...` entries). Keep the `git add` invocation itself unchanged — it still receives
      the full `add_pathspecs` array, positives and excludes together. *(completed)*
- [x] Capture the add's output and exit code instead of short-circuiting, using the script's
      existing `-e`-exempt idiom: `if add_output=$(git add "${add_pathspecs[@]}" 2>&1); then
      add_exit=0; else add_exit=$?; fi`. Do not `exit` on a nonzero code at this point. *(completed)*
- [x] Add the per-path verification loop over `add_positive_pathspecs`, collecting failures into
      `genuinely_failed_adds`. A path fails when either:
      (a) `git ls-files --error-unmatch -- "$p"` is nonzero — the path is not known to the index
      at all, so nothing landed; or
      (b) `git diff --quiet -- "$p" "${add_exclude_pathspecs[@]+${add_exclude_pathspecs[@]}}"` is
      nonzero — the working tree still differs from the index for that path (a partial or failed
      stage), with the exclude entries passed through so a deliberately-excluded sub-path cannot
      false-flag a directory pathspec. *(completed)*
- [x] When `genuinely_failed_adds` is non-empty: echo the captured add output to stderr, then a
      loud ERROR naming every failing path and the reason class, and `exit 2` — preserving today's
      documented exit-code contract and the "nothing was committed" outcome. *(completed)*
- [x] When `genuinely_failed_adds` is empty but `add_exit` is nonzero: echo the captured add output
      to stderr plus a NOTE stating the exit code was tolerated because every positive pathspec
      verified present and fully staged (naming the gitignore advisory for a tracked
      ignore-matched path as the known case), then fall through to the commit. The tolerated path
      must never be silent. *(completed)*
- [x] Guard every new array expansion for `set -u` behind a `${#arr[@]}` test or the
      `${arr[@]+...}` form, matching the existing `dropped_pathspecs` treatment. *(completed)*
- [x] Extend the script's own header: add this gate to the `# Safety gates` list as the next
      unused `V` number (V7 at time of writing — confirm against the live header, which already
      documents V2, V3, V5 and V6), stating that `git add`'s exit code is unreliable in **both**
      directions and that index state is authoritative. Record the deliberate residual blind spot:
      a single newly-created, ignore-matched file *inside* a directory pathspec that already has
      other tracked files is not detected by `ls-files --error-unmatch` on the directory — which
      matches the already-settled "an ignored path swept up implicitly is silently skipped"
      behavior in `git-staging-scope.md` and is therefore intended, not a gap introduced here. *(completed)*
- [x] Update the header's `# Exit codes:` entry for `2` so it reads as "git add left one or more
      staged paths genuinely unstaged (verified against the index, not inferred from git add's
      exit code)" rather than "git add failed". *(completed)*
- [x] Confirm no caller depends on exit 2 firing for the advisory case: inspect the four
      script-level invocation sites — `orchestrator-postflight.sh`,
      `orchestrate-unwind-dispatch.sh`, `orchestrate-cycle-postflight.sh`, and
      `lib/redeploy-checkpoint-lib.sh` — and confirm each uses the `cmd || echo "WARN ...
      (non-blocking)"` idiom with no branch on exit code 2. *(completed)*
- [x] Run `bash -n` and `shellcheck` on the edited script; run
      `bash agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh --verbose` and
      `bash agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh --verbose`
      (both target this script specifically). *(completed)*
- [x] Run `bash .claude/scripts/check-task-references.sh` and confirm no task-number reference was
      introduced. *(completed)*
- [x] Commit this green sub-step (source-store script only). *(completed)*

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: the change is confined to one block in one file, and the exit-code contract
has exactly four script-level consumers (`orchestrator-postflight.sh`,
`orchestrate-unwind-dispatch.sh`, `orchestrate-cycle-postflight.sh`,
`lib/redeploy-checkpoint-lib.sh`), none of which branches on exit 2. Confirm at implementation
time with `grep -rn 'bash .*git-commit-scoped\.sh' agent-system/extensions --include="*.sh"`
(excluding `tests/`) and by reading each hit's surrounding `||` idiom; if a consumer *does* branch
on exit 2, enumerate it and re-scope before editing.

**Files to modify**:
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` - replace the blind
  `if ! git add ...; then exit 2; fi` guard with captured-output + per-path index-state
  verification; extend the header's safety-gate list and exit-code 2 description

**Verification**:
- `bash -n` clean and `shellcheck` reports no new finding on the edited script.
- Both boundary lints (`lint-scoped-commit-boundary.sh`, `lint-directory-pathspec-boundary.sh`)
  pass with `--verbose`.
- The header's safety-gate list and exit-code 2 entry describe the new behavior; no stale
  "git add failed" wording remains.
- `git status --short` shows exactly one modified file for this phase, under
  `agent-system/extensions/core/scripts/`, and nothing under `.claude/`.
- The four enumerated direct dependents are confirmed not to branch on exit code 2.
- `check-task-references.sh` reports no new occurrence.

---

### Phase 2: Regression coverage in the existing suite [NOT STARTED]

**Goal**: `test-git-commit-scoped.sh` proves the advisory case now commits, the genuine-failure
case still refuses, and both assertions fail when the fix is stubbed out.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` and reuse its
      existing harness verbatim: `build_repo`, `add_ephemeral`, `run_commit`, the `pass`/`fail`
      counters, and the `mktemp -d` + `trap cleanup EXIT` discipline. Note that
      `SRC_SCRIPTS_DIR="$SCRIPT_DIR/.."` resolves to the **source store** copy of the script, so
      this suite exercises the Phase 1 edit with **no deploy required**.
- [ ] Extend `build_repo` (or add a sibling helper) so a scratch repo can carry a tracked file
      under a directory that `.gitignore` matches via a parent-directory rule — i.e. commit the
      file first, *then* add the ignore rule, reproducing the live `specs/archive/state.json`
      shape.
- [ ] Add a case: tracked, ignore-matched path passed alone as a positive pathspec. Assert the
      commit **landed** via `git rev-list --count HEAD` incrementing and `git show --name-only`
      containing the path — never exit code alone.
- [ ] Add a case: the same tracked, ignore-matched path **batched** with an ordinary modified path
      in one invocation. Assert both paths appear in the resulting commit.
- [ ] Add a case: the tolerated-advisory invocation emits the stderr NOTE (tolerated nonzero add
      exit) — proving the tolerance is observable rather than silent.
- [ ] Add a genuine-failure case: a positive pathspec that `git add` hard-fails on with nothing
      staged (an out-of-repo absolute path such as `/etc/hostname`, batched with an otherwise-valid
      modified path). Assert exit 2, no new commit, and that the ERROR names the failing path —
      this is the assertion that proves the fix does not paper over the sibling task's hard
      failure.
- [ ] Add a case: a brand-new **untracked**, ignore-matched file named as an explicit positive
      pathspec still does not get committed (no `-f` behavior crept in), and is reported rather
      than silently accepted.
- [ ] Add a case: a directory pathspec in a fully-covered repo with ephemeral paths present
      (reuse `add_ephemeral`) still commits and still excludes them — proving the exclude entries
      passed into the `git diff --quiet` check do not false-flag the directory.
- [ ] Negative control: temporarily restore the old `if ! git add ...; then exit 2; fi` guard in a
      scratch copy of the script, confirm the new advisory cases FAIL, then restore the fix and
      confirm green. Record the observed failure output in the phase notes.
- [ ] Run the full suite: `bash agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh`.
      All pre-existing T1-T10 and V1-V8 cases must still pass.
- [ ] Commit this green sub-step.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: six new cases plus one negative control, in one existing test file, with no
new test file and no manifest change. Confirm at implementation time that the suite's final
PASSED/FAILED tally grew by exactly the number of added assertions and that `FAILED` is 0; if the
existing harness cannot build the tracked-then-ignored fixture without a new helper, note the
added helper explicitly rather than silently widening the file's structure.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` - add the
  tracked-ignore-matched, batched, NOTE-emission, genuine-failure, untracked-ignored, and
  directory-with-ephemerals cases, plus the fixture helper they need

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` exits 0 with
  `FAILED=0` and every new case reported `[PASS]`.
- Every new assertion verifies commit landing via `git log`/`git show --name-only`, not exit code
  alone.
- The negative control was observed to FAIL with the fix stubbed out, and the failure output is
  recorded in the phase notes.
- `shellcheck` reports no new finding on the test file.

---

### Phase 3: Record the positive-pathspec hazard in the staging-scope standard [NOT STARTED]

**Goal**: `git-staging-scope.md` documents the positive-pathspec side of the ignore-advisory
hazard, so a future caller cannot "fix" it with `git check-ignore -q` and silently regress.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/context/standards/git-staging-scope.md`, in particular
      the existing passage documenting the `:(exclude)`-side hazard ("Naming a path already covered
      by `.gitignore` in an explicit `:(exclude)...` pathspec entry makes `git add` ... refuse the
      WHOLE add").
- [ ] Add a short sibling subsection covering the positive-pathspec case: a **tracked** path whose
      path matches an ignore rule via a parent-directory pattern draws the same advisory and a
      nonzero `git add` exit, but — unlike the exclude case — **does not actually fail**; the file
      is staged.
- [ ] State explicitly that `git check-ignore -q` must **not** be used to detect this case: it is
      index-aware and reports "not ignored" for exactly these tracked paths, contradicting
      `git add`. Name `--no-index` as the only form that agrees, and state that neither is needed
      because the sanctioned implementation verifies post-add index state instead.
- [ ] State the tracked-vs-moved distinction by mechanism: a file relocated by plain `mv` into an
      ignore-matched destination is a brand-new *untracked* path there, so `git add` genuinely
      drops it — a real failure, not an advisory false negative, which this verification correctly
      refuses rather than tolerates. Any caller that intends such a move must carry its own
      destination-ignored guard. Refer to it by mechanism and fix site only; introduce no task
      number.
- [ ] Note that `git add -f`/`--ignore-errors` is not the sanctioned remedy, because it would also
      force-add genuinely untracked, genuinely-should-stay-ignored paths.
- [ ] Run `bash .claude/scripts/check-task-references.sh` and confirm no task-number reference was
      introduced.
- [ ] Commit this green sub-step.

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: one new subsection in one file, placed adjacent to the existing exclude-side
passage, with no change to the CANDIDATE-array block or to any other scope section. Confirm at
implementation time by diff-reading that the only added hunk is the new subsection and that no
existing sentence was reworded.

**Files to modify**:
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - add the
  positive-pathspec ignore-advisory subsection beside the existing `:(exclude)`-side passage

**Verification**:
- Diff read-through confirms every changed hunk is prose inside the new subsection; no code block
  or CANDIDATE-array content was altered.
- The subsection names all four points: the advisory-but-staged behavior, the `check-ignore -q`
  prohibition, the tracked-vs-moved distinction, and the `-f` prohibition.
- `check-task-references.sh` reports no new occurrence.
- No file under `.claude/` was touched.

---

### Phase 4: Full gate and deploy-boundary close-out [NOT STARTED]

**Goal**: the full repository gate set is run and accounted for, with the source/deploy divergence
explicitly attributed rather than left as an unexplained failure.

**Tasks**:
- [ ] Capture a **baseline** `bash .claude/scripts/verify-deploy.sh --skip-slow` result *before*
      drawing any conclusion, recording the gate numbers and file names of every pre-existing
      failure (sibling tasks are live on this tree this cycle).
- [ ] Run `bash .claude/scripts/verify-deploy.sh` (or `--skip-slow`, stating which form was run)
      and record the full PASS/FAIL tally.
- [ ] Attribute every failure by name. Specifically expect gate 5 (manifest-driven category parity
      and content-hash equality) to register the source store being ahead of `.claude/` for
      `git-commit-scoped.sh`, `test-git-commit-scoped.sh`, and `git-staging-scope.md` — this is
      the deliberate, documented consequence of editing the source store without redeploying, not
      a regression. Any failure in a file outside this task's scope is **reported**, not fixed.
- [ ] Re-run the full `test-git-commit-scoped.sh` suite once more against the final tree state and
      confirm `FAILED=0`.
- [ ] Confirm `git status --short` shows no modification under `.claude/` attributable to this
      task.
- [ ] Run `bash .claude/scripts/check-task-references.sh` over the final tree.
- [ ] Record, in the implementation summary rather than in any deliverable file, that the fix is
      live in the source store only until an operator regeneration (`<leader>al` "Reload All", or
      `deploy-headless.sh`) — and that consumer repositories blocked by this defect pick it up at
      their next deploy, not from this commit.
- [ ] Commit the final green state.

**Timing**: 0.5 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Scope Hypothesis**: the only new gate failures relative to the captured baseline are gate-5
source/deploy divergences naming this task's three edited files. Confirm by diffing the baseline
failure set against the post-change failure set; any additional failure is investigated and
reported before the phase closes.

**Files to modify**:
- none planned (verification-only phase; no file edits expected)

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` was run (form stated) and its complete gate set
  accounted for, with every failure named and attributed against the pre-change baseline.
- `test-git-commit-scoped.sh` exits 0 with `FAILED=0` on the final tree.
- `git status --short` shows no `.claude/**` modification from this task.
- `check-task-references.sh` reports no occurrence outside `specs/**`.
- The summary states the source-store-only reach of the fix and names redeploy as an operator
  action.

## Testing & Validation

- [ ] Tracked, ignore-matched positive pathspec: the commit lands (verified via
      `git rev-list --count` and `git show --name-only`).
- [ ] Same path batched with an ordinary path: both land in one commit.
- [ ] Tolerated-advisory invocation emits the stderr NOTE (not silent).
- [ ] Genuine add failure (out-of-repo pathspec, nothing staged): exit 2, no commit, failing path
      named — the sibling task's hard failure is not papered over.
- [ ] Brand-new untracked ignore-matched path named explicitly: still not committed; no `-f`
      behavior introduced.
- [ ] Directory pathspec with ephemeral runtime paths present: commits, excludes them, and is not
      false-flagged by the new diff check.
- [ ] Negative control: the new advisory cases FAIL against the pre-fix guard.
- [ ] Pre-existing T1-T10 and V1-V8 cases all still pass.
- [ ] `shellcheck` and `bash -n` clean on both edited shell files.
- [ ] `lint-scoped-commit-boundary.sh --verbose` and `lint-directory-pathspec-boundary.sh --verbose`
      pass.
- [ ] `verify-deploy.sh` run with every failure named and attributed against the baseline.
- [ ] `check-task-references.sh` clean.
- [ ] No file under `.claude/` modified.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/git-commit-scoped.sh` — post-add index-state verification
  replacing the blind exit-code guard; header safety-gate and exit-code-2 documentation extended.
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` — six new regression
  cases plus the tracked-then-ignored fixture helper.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — new positive-pathspec
  ignore-advisory subsection.
- `specs/325_git_add_ignore_advisory_aborts_commit/summaries/01_*-summary.md` — implementation
  summary, including the baseline-vs-post gate attribution and the source-store-only reach note.
- No deployed `.claude/**` artifact is produced or modified by this task.

## Rollback/Contingency

All three edits are additive-or-local within three files in the source store, each committed as
its own green sub-step, so reverting is a per-file `git revert` of the relevant commit — no
working-tree discard is required and no snapshot is needed for the ordinary case.

If a rollback must instead discard uncommitted work mid-phase, that is a genuine rollback: take a
durable checkpoint first per `context/contracts/recovery.md`'s rollback rung (which names the
exact `git-snapshot.sh` invocation shape, including its out-of-scope override flag for a
deliberate whole-tree case), then run the destructive command. Do **not** emit a bare, reverting
`git-snapshot.sh` as a routine start-of-phase precaution; an ordinary defensive checkpoint uses
`--no-revert`.

Contingency if the per-path `git diff --quiet` check proves too noisy in practice (for example a
directory pathspec whose tracked-but-excluded sub-path is modified in a shape the exclude
pass-through does not cover): narrow the verification to the `git ls-files --error-unmatch`
presence check alone, which still tolerates the advisory and still catches a nothing-staged
failure, and record the narrowed coverage explicitly in the script header rather than leaving the
weaker check undocumented.
