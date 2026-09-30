# Implementation Plan: Task #268

- **Task**: 268 - lake-build-guard false-green (cross-tree guard-state clone)
- **Status**: [IMPLEMENTING]
- **Effort**: 4.5 hours
- **Dependencies**: None
- **Research Inputs**: `specs/268_lake_build_guard_false_green_scope_key/reports/01_false_green_scope_key_defect.md`
- **Artifacts**: plans/01_cross-tree-guard-state-clone.md (this file)
- **Standards**:
  - `.claude/context/formats/plan-format.md`
  - `.claude/context/standards/status-markers.md`
  - `.claude/rules/artifact-formats.md`
  - `.claude/rules/state-management.md`
  - `.claude/rules/source-store-deploy-boundary.md`
  - `.claude/context/standards/shell-script-testing.md`
- **Type**: general
- **Lean Intent**: false

## Overview

Research reproduced a real, deterministic false green rooted in `dispatch-worktree.sh`'s
`cp -al` hardlink clone of `.lake/`, but through a different mechanism than the dispatch's
literal hypothesis (d): the five `build-guard.*` state files become the SAME INODE in every
provisioned worktree, so a worktree build's `finalize_record()` (`> "$RESULT_PATH"`,
truncate-in-place) silently overwrites the main tree's record, log and captured output, and a
subsequent `result --dir <main>` without `--expect-pid` reports the foreign tree's
`exit_status=0` verdict as the main tree's own. The same shared inode also makes
`build-guard.lock` serialize builds across trees, defeating the very "mode 2" build-contention
isolation per-dispatch worktrees exist to provide. This plan fixes the root cause at the clone
step (exclude `build-guard.*` from the `.lake/` hardlink clone), pins both consequences with
deterministic regression tests, pins the incidental protection that keeps `decide_sharing()`'s
replay branch safe across trees, and records the hazard in the two scripts' own headers.
Definition of done: the two new `test-dispatch-worktree.sh` cases fail before the fix and pass
after it, `run-all.sh` is green, and the fix is redeployed to `.claude/`.

### Research Integration

The research report is load-bearing for three planning decisions and is followed, not
re-litigated:

- **Hypotheses (a) and (b) are ruled out** by code reading plus existing mutation coverage
  (`compute_scope_key()` is fed an identical `lake_args` vector at both call sites;
  `decide_sharing()`'s scope branch correctly short-circuits on an empty `record_scope_key`, and
  it is the only replay decision path). **No change is planned to `LAKE_SUBCOMMANDS`,
  `compute_scope_key()`, or `decide_sharing()`'s scope condition.**
- **Literal hypothesis (d) is refuted by direct reproduction**: `compute_fingerprint()`'s hashed
  pre-image embeds each file's own path string (`stat -c '%n %s %y'`; even in `hash` mode
  `sha256sum`'s `<hash>  <filename>` output embeds the filename), so two worktree paths can never
  produce equal fingerprints and a real cross-tree `build` always reruns. This protection is
  incidental, not designed — Phase 3 pins it.
- **The confirmed defect is "(d), amended"**: same root cause (`cp -al` at
  `dispatch-worktree.sh` `cmd_provision()`), but exploited through `result`'s unguarded read and
  the shared lock file. The research's recommended fix (exclude `build-guard.*` from the clone) is
  adopted over the dispatch's alternative (tree identity in the record), because the record-side
  fix alone leaves `build-guard.lock` a shared inode and so does not close the lock-contention
  half. The research's correction to the dispatch's `--git-common-dir` aside is also adopted: that
  path is identical across every worktree of one repository and would provide zero protection.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no ROADMAP.md consultation performed.

## Goals & Non-Goals

**Goals**:

- Give every provisioned worktree independent (non-hardlinked) `build-guard.*` state while
  keeping `.lake/build/`'s olean cache fully shared — the actual reason `.lake/` is cloned.
- Close both confirmed consequences at the root: cross-tree record/log clobbering (a genuine
  false green) and cross-tree `flock` serialization.
- Make `--no-share` unnecessary as a defence. After this fix, a guarded build inside a dispatch
  worktree is correct with no caller-side flag and no caller-side discipline.
- Add deterministic regression coverage under
  `agent-system/extensions/core/scripts/tests/` that fails before the fix and passes after it.
- Pin the incidental fingerprint path-embedding protection so a future pure-content-hash change
  cannot silently reopen a `decide_sharing()`-level cross-tree replay.
- Record the hazard class ("exclude ephemeral runtime state from a hardlink clone") in the two
  scripts' own headers so a future sibling guard inherits it by default.

**Non-Goals**:

- No change to `compute_scope_key()`, `decide_sharing()`, or `LAKE_SUBCOMMANDS` — (a) and (b) are
  ruled out and `test-lake-build-guard.sh`'s mutation D already proves the scope condition is
  load-bearing.
- No tree-identity field added to the record format. The record format stays byte-compatible;
  the "what does an old record with no tree-identity field mean" question the dispatch asked to
  settle does not arise, because no such field is introduced. (Decision recorded below.)
- No change to `finalize_record()`'s write mechanism. (Decision recorded below.)
- No end-to-end Lean reproduction, and no change of any kind under `~/Projects/BimodalLogic` —
  the defect was fully reproduced with a fake `lake` binary and no Lean project.
- No edit to `context/patterns/batch-orchestration-guardrails.md`, despite the research's
  Context Extension Recommendation naming it — that file is in concurrent sibling task 278's
  declared `file_scope` this same cycle. (Decision recorded below; carried as a follow-up.)
- No hand-patching of any deployed copy under `.claude/**`; the source store is the edit target
  and the deployed tree is regenerated by redeploy (Phase 5).

## Decisions

Three planning judgment calls, recorded here rather than deferred:

1. **Exclusion at the clone, not tree identity in the record.** Adopted from the research's
   recommendation. The exclusion fix is strictly stronger (it closes the lock-contention half a
   record-side field cannot reach), keeps the record format forward-compatible by not changing it
   at all, and needs no change to `lake-build-guard.sh`'s logic. This also answers the dispatch's
   "decide explicitly what an old record with no tree-identity field means": the question is moot
   under the chosen fix, and that is the reason it is not answered elsewhere in this plan.
2. **`finalize_record()` keeps its `> "$RESULT_PATH"` truncate-in-place write.** Switching to
   write-temp-then-`mv` would break the hardlink and match `dispatch-worktree.sh`'s header claim
   that a clone's entries are "independently rebindable via atomic rename" — but it is only a
   partial fix (the `.log`/`.stdout`/`.stderr` captures are streamed into by the wrapped build and
   cannot be atomically renamed the same way, and `build-guard.lock` stays a shared inode
   regardless), and it adds failure modes inside the TERMINAL RECORD GUARANTEE trap path. The
   root-cause exclusion covers all five files with no such cost.
3. **Territory: `batch-orchestration-guardrails.md` is deliberately out of footprint.** Sibling
   task 278 declares it in its `file_scope` for this same cycle. The hazard note lands in
   `dispatch-worktree.sh`'s and `lake-build-guard.sh`'s own headers instead — both exclusively in
   this task's footprint — which serves the same purpose (a future sibling guard inherits the
   convention) without a cross-task write conflict.

## Territory Notes

This task's `file_scope` is harvested at plan-postflight from the per-phase **Files to modify**
lists by `plan-file-scope-harvest.sh`, which resolves the dispatch's FILE FOOTPRINT NOTE: after
this plan lands, admission can serialize this task against the separately-tracked `land`/release
silent-data-loss task that also edits `dispatch-worktree.sh`. The four files are:

- `agent-system/extensions/core/scripts/dispatch-worktree.sh`
- `agent-system/extensions/core/scripts/lake-build-guard.sh`
- `agent-system/extensions/core/scripts/tests/test-dispatch-worktree.sh`
- `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh`

`dispatch-worktree.sh` overlaps the `land`/release task's footprint. The two edits sit in
different functions (`cmd_provision()`'s clone here; `land`/release handling there), but whichever
lands second MUST re-read the whole file before editing. Three sibling tasks (278, 279, 269) are
dispatched this same cycle on this shared working tree; none of their declared files appear above,
but per `context/contracts/territory.md` re-read each file immediately before editing, stage only
this task's own hunks with an explicit path list (never a directory or glob `git add`), and never
run `git-snapshot.sh` in its reverting default mode.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Excluding `build-guard.*` is read as weakening the "share disk blocks" rationale for cloning `.lake/` | L | M | The five excluded files are small ephemeral runtime bookkeeping, not build output; `.lake/build/`'s olean cache stays fully shared. State this in the header note (Phase 4) |
| A timing-based lock-contention test is flaky under CI load and produces false reds | M | H | Deliberately not written. The lock-contention half is asserted deterministically via inode distinctness on `build-guard.lock` (Phase 1, T14), which is the root cause the timing effect follows from |
| The exclusion is implemented as a post-`cp -al` delete and a partially-failed provision leaves a stale hardlinked file behind | M | L | Implement so the guard files are never hardlinked in the first place (`--exclude`-equivalent), or delete immediately and unconditionally before the `resolved_root` assertion that can tear the worktree down; T14 asserts the end state either way |
| A future edit to `compute_fingerprint()` (e.g. a pure content hash) silently removes the incidental path-embedding that keeps `decide_sharing()` safe across trees, reopening literal (d) | H | L | Phase 3's Test C pins the behavior so such a change fails a suite |
| `provision`'s clone contract has other consumers that assume a complete `.lake/` copy | M | L | Phase 2 runs the full `run-all.sh`, which includes `test-dispatch-isolation-fixture.sh` — the other suite that references `dispatch-worktree.sh` |
| A concurrent sibling's in-flight edit to a shared file is mistaken for this task's own regression | M | M | Re-read before editing; on an unexpected failure outside this footprint, check `git log` and STOP and report rather than "fixing" it |
| The fix lands in the source store but the deployed `.claude/` copy stays stale, so live dispatches keep the defect | H | M | Phase 5 redeploys and verifies deployed-vs-source parity as an explicit gate |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2 | 1 |
| 3 | 4 | 2 |
| 4 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Pin the two confirmed consequences as failing tests [COMPLETED]

**Goal**: Add two deterministic cases to `test-dispatch-worktree.sh` that reproduce the confirmed
defect through the real `provision` code path, and confirm both FAIL against current code before
any fix exists. This is the evidence that the defect is real in this repository, not only in the
research's `/tmp` fixture.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/scripts/tests/test-dispatch-worktree.sh` in full
      (sibling tasks are live on this tree), noting the T1 `.lake/` hardlink-clone case, the
      `REQUIRED_SCRIPTS` loud-skip block, the `pass()`/`fail()`/`info()` counter idiom, and the
      `mktemp -d` + `trap cleanup EXIT` harness.
- [x] Add case **T14 (root cause, inode distinctness)**: build a scratch repo whose
      `.lake/` contains all five guard state files (`build-guard.lock`, `.result`, `.log`,
      `.stdout`, `.stderr`) plus a real build-output file (`.lake/pkg/out.olean`, reusing T1's
      shape). Run `provision`. Assert, per file, that the worktree's `build-guard.*` is NOT the
      same inode as the main tree's (`stat -c '%i'` inequality, or link count 1), AND that
      `.lake/pkg/out.olean` IS still the same inode — the sharing benefit must survive. Emit one
      named `pass`/`fail` per assertion so a partial fix is visible.
- [x] Add case **T15 (behavioural, cross-tree `result` clobbering)**: extend the harness's
      script-copy set to include `lake-build-guard.sh` (add it to `REQUIRED_SCRIPTS` so a lost
      exec bit is a loud skip, matching existing discipline). Build a scratch repo carrying a
      minimal Lean-package fixture (`lakefile.toml`, `lean-toolchain`, one `.lean` source) and an
      inline fake `lake` on `PATH` that emits a per-tree marker and exits 0. Sequence: run a
      guard `build` in the main tree with a MAIN-marker fake `lake`; `provision` a worktree; run a
      guard `build` inside the worktree with a WT-marker fake `lake` and a different scope; then
      run `result --dir <main>` with NO `--expect-pid`. Assert the reported `holder_pid` is the
      main tree's own build's pid and that the file at the reported `log_path` contains the MAIN
      marker and not the WT marker.
- [x] Follow `context/standards/shell-script-testing.md`: `set -uo pipefail`, counter idiom,
      loud-skip discipline (never a silent no-op), no reliance on the real `lake` binary, no
      write outside the `mktemp -d` workdir.
- [x] Respect `.claude/rules/no-task-references-in-deliverables.md`: any fixture task number is
      arbitrary `dispatch-worktree.sh` naming-convention data — extend the file's existing
      `task-ref-ok:begin` rationale block rather than adding a bare number outside it.
- [x] Run `bash agent-system/extensions/core/scripts/tests/test-dispatch-worktree.sh` and record
      the exact failing output for T14 and T15 (this is the reproduction evidence).

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts (i) exactly two new cases are needed, (ii) the existing
suite has 13 cases (T1-T13) all of which pass unchanged, and (iii) adding
`lake-build-guard.sh` to the harness's copy set needs no further runtime dependency beyond the
already-copied `deploy-root-guard.sh` and `lib/common.sh`. Confirm at implementation time by
running the suite before editing (baseline: all cases pass), then after (baseline cases still
pass, exactly the two new ones fail), and by grepping `lake-build-guard.sh` for `source`/`.`
directives before assuming its dependency set.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-dispatch-worktree.sh` - add cases T14 and T15; extend `REQUIRED_SCRIPTS` and the `task-ref-ok` rationale block

**Verification**:

- Suite runs to completion and exits nonzero with exactly T14's and T15's assertions failing.
- Every pre-existing case (T1-T13) still passes — no collateral breakage from the harness change.
- `bash -n` clean; no file created outside the suite's `mktemp -d` workdir (confirm by checking
  `git status --short` is unchanged apart from the suite file itself).

---

### Phase 2: Exclude `build-guard.*` from the `.lake/` hardlink clone [COMPLETED]

**Goal**: Fix the root cause in `cmd_provision()` so every provisioned worktree starts with
independent guard state, turning Phase 1's two red cases green without touching
`lake-build-guard.sh`'s logic.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/scripts/dispatch-worktree.sh` in full immediately
      before editing — it is also the `land`/release task's edit target and a sibling may have
      changed it.
- [x] In `cmd_provision()`, change the `.lake/` clone so the five `build-guard.*` files are never
      hardlinked into the worktree, leaving everything else (notably `.lake/build/`) shared.
      Prefer a form that cannot leave a stale hardlinked file behind if a later step in
      `cmd_provision()` fails; if a post-`cp -al` removal is used, place it immediately after the
      clone and before the `resolved_root` assertion, and make it unconditional
      (`rm -f` on each named path, never a glob that could reach a non-guard file).
- [x] Keep the exclusion list explicit and named (the five documented paths from
      `lake-build-guard.sh`'s header), not a wildcard over `.lake/`, so a future unrelated
      `.lake/` file is not silently dropped from the clone.
- [x] Leave the `.claude/` clone at line ~293 unchanged — no ephemeral guard state lives there
      today, and widening the change is out of scope.
- [x] Re-run `test-dispatch-worktree.sh`: T14 and T15 must now pass, T1-T13 unchanged.
- [x] Run the full suite set: `bash agent-system/extensions/core/scripts/tests/run-all.sh`.
- [x] Commit this phase's own hunks with an explicit path list.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the fix is confined to `cmd_provision()`'s `.lake/`
clone block (the `if [ -d "$PROJECT_ROOT/.lake" ]` branch) and that exactly five guard state
files must be excluded. Confirm at implementation time by re-reading
`lake-build-guard.sh`'s "RUNTIME PATHS" / state-file header block to enumerate the state files
from the source of truth rather than from this plan, and by `grep -n 'cp -al' dispatch-worktree.sh`
to confirm no second `.lake/` clone site exists.

**Files to modify**:

- `agent-system/extensions/core/scripts/dispatch-worktree.sh` - `cmd_provision()`: exclude the five `build-guard.*` state files from the `.lake/` hardlink clone

**Verification**:

- `test-dispatch-worktree.sh` exits 0 with T14 and T15 passing and T1-T13 unchanged.
  *(completed)*
- `run-all.sh` exits 0 (this is the tier-`full` gate; `test-dispatch-isolation-fixture.sh`, the
  other suite referencing this script, is inside it). *(deviation: altered — run-all.sh reports
  97 passed, 8 failed, 0 skipped, 105 total; all 8 failures confirmed pre-existing and unrelated
  to dispatch-worktree.sh/lake-build-guard.sh -- see progress/phase-2-progress.json for the full
  evidence. test-dispatch-worktree.sh (49/49) and test-lake-build-guard.sh (48/48), the two
  suites in this task's own file_scope, both pass cleanly)*
- `bash -n dispatch-worktree.sh` clean; `shellcheck` (if available in this environment) reports no
  new findings against the changed hunk. *(completed)*
- Manual confirmation that `.lake/build/`-style content is still hardlink-shared after provision
  (T14's positive assertion covers this mechanically). *(completed)*

---

### Phase 3: Pin the incidental cross-tree non-replay protection [COMPLETED]

**Goal**: Add Test C to `test-lake-build-guard.sh` asserting that `decide_sharing()` refuses to
replay a record authored in a different tree even when every other sharing condition is
satisfiable, so a future `compute_fingerprint()` change that drops path-embedding (e.g. a pure
content hash) fails a suite instead of silently reopening literal hypothesis (d).

**Tasks**:

- [x] Re-read `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh`'s fixture
      machinery (`build_fixture()`, `run_guard()`) and its existing scope_key mutation coverage
      (mutation D) to place the new case consistently.
- [x] Add **Test C**: build two fixture roots at different paths; run a real guard `build` in the
      first with a given scope; `cp -al <root1>/.lake <root2>/.lake` (the raw clone operation,
      deliberately NOT routed through `dispatch-worktree.sh` — this case pins the guard's OWN
      logic independent of Phase 2's clone fix); run a guard `build` in the second with the SAME
      scope and assert a real build occurred: the fake `lake` invocation counter incremented, the
      real-build-only `lake-build-guard: STATUS:` marker appears on stderr, and no
      `lake-build-guard: REPLAY:` marker appears.
- [x] Add a short comment above the case stating WHY it exists: the protection is incidental
      (path-embedding in `compute_fingerprint()`'s pre-image, in both `stat` and `hash` modes),
      not designed, so it needs pinning; and stating that this case must keep using a raw
      `cp -al` rather than `provision`, since routing it through the fixed clone would make it
      vacuous.
- [x] Run `bash agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh`.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts one new case suffices and that it passes against
current, unfixed code (it pins existing behavior rather than driving a change). Confirm at
implementation time by running the case before any Phase 2 change is present on the tree, or by
`git stash`-free re-verification after Phase 2 — the assertion must hold in both states, and if
it does not, that is itself the finding.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` - add Test C: cross-tree replay refusal over a raw `cp -al`-shared `.lake/`

**Verification**:

- `test-lake-build-guard.sh` exits 0 with the new case passing.
- The new case passes both with and without Phase 2's fix applied (it is orthogonal to it).
- A deliberate local mutation that strips path-embedding from `compute_fingerprint()`'s
  pre-image makes the new case FAIL (mutation check, reverted immediately — do not commit it);
  this proves the case is load-bearing rather than vacuous.

---

### Phase 4: Record the hazard class in both script headers [COMPLETED]

**Goal**: Make the "exclude ephemeral runtime state from a hardlink clone" convention discoverable
where a future sibling guard author will read it, so the hazard is inherited by default rather
than rediscovered.

**Tasks**:

- [x] In `dispatch-worktree.sh`'s header, extend the "WHY A HARDLINK CLONE, NEVER A SYMLINK"
      note: a hardlink clone shares the INODE of every pre-existing file, so any ephemeral
      runtime state file already present in a cloned directory is one file under two paths.
      Name `build-guard.*` as the confirmed, reproduced, now-excluded case (record/log clobbering
      and cross-tree `flock` serialization), and state the rule for future cloned directories.
      Note that the "independently rebindable via atomic rename" property holds only for writers
      that actually rename, and that a truncate-in-place writer does not get it.
- [x] Update the header's `RUNTIME PATHS THIS SCRIPT OWNS` / provision description if it implies
      `.lake/` is cloned in full, so the documented behavior matches the code.
- [x] In `lake-build-guard.sh`'s header, under `FAMILY CONVENTIONS` (and/or `RECORDED DEAD ENDS`),
      record that the five state files must never be hardlink-shared across trees, that
      `dispatch-worktree.sh` now excludes them at provision, and that `result --expect-pid` is the
      working caller-side mitigation for any residual case. Also record, as a dead end, that
      `--git-common-dir` is identical across every worktree of one repository and is therefore
      useless as a tree-identity source; `git rev-parse --show-toplevel` is the one that differs
      (while remaining forbidden for `ROOT` resolution, which is a different purpose).
- [x] Re-read both files immediately before editing; keep every edit inside comment regions.

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts every edit is confined to `#` comment regions in the two
scripts, with zero executable surface. Confirm at implementation time by reading the staged diff
hunk by hunk and checking every changed line begins with optional whitespace then `#`, plus
`bash -n` on both files.

**Files to modify**:

- `agent-system/extensions/core/scripts/dispatch-worktree.sh` - header: hardlink-clone inode-sharing hazard, the `build-guard.*` exclusion, corrected provision description
- `agent-system/extensions/core/scripts/lake-build-guard.sh` - header: state files must not be hardlink-shared across trees; `--git-common-dir` recorded as a dead end

**Verification**:

- Diff read-through confirms every changed hunk lies inside a comment region; no executable line
  changed.
- `bash -n` clean on both scripts (a comment edit that accidentally breaks a heredoc or quote
  would surface here).
- No task-number citation introduced outside an existing `task-ref-ok` rationale
  (`bash .claude/scripts/check-task-references.sh` if present, else grep the diff).

---

### Phase 5: Redeploy and final gate [NOT STARTED]

**Goal**: Propagate the source-store fix into the deployed `.claude/` tree that live dispatches
actually execute, and close the task on a full green gate.

**Tasks**:

- [x] Run `bash .claude/scripts/deploy-headless.sh`.
- [x] Verify deployed-vs-source parity for the four touched files by diffing
      `.claude/scripts/dispatch-worktree.sh`, `.claude/scripts/lake-build-guard.sh`,
      `.claude/scripts/tests/test-dispatch-worktree.sh` and
      `.claude/scripts/tests/test-lake-build-guard.sh` against their
      `agent-system/extensions/core/scripts/` sources — each must be identical.
- [x] Run `bash .claude/scripts/verify-deploy.sh` if present (its Gate 8 runs the suite set in
      deployed mode, which is the configuration live dispatches use).
- [x] Run `bash agent-system/extensions/core/scripts/tests/run-all.sh` once more as the final
      full gate.
- [x] Confirm `git status --short` shows no unexpected tracked modification outside this task's
      four source files (`.claude/` is gitignored, so the redeploy is expected to be invisible to
      git).

**Timing**: 0.5 hours

**Depends on**: 2, 3, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts `deploy-headless.sh` is the correct, sufficient
propagation mechanism and that no manifest or `index-entries.json` change is required (no new
file is added — both new test cases go into existing suites, and `run-all.sh` discovers suites
automatically). Confirm at implementation time by checking the deploy output names the four
files, and by confirming the suite count `run-all.sh` reports is unchanged from the pre-task
baseline.

**Files to modify**:

- none planned in the source store; this phase regenerates the gitignored `.claude/` deploy
  artifact and runs gates

**Verification**:

- `deploy-headless.sh` exits 0.
- All four deployed copies are byte-identical to their source-store originals.
- `verify-deploy.sh` (if present) exits 0.
- `run-all.sh` exits 0 with an unchanged suite count and no `[SKIP]` for either touched suite.

---

## Testing & Validation

- [ ] `test-dispatch-worktree.sh`: T14 asserts all five `build-guard.*` files are distinct inodes
      after `provision`, while `.lake/`'s build output remains hardlink-shared.
- [ ] `test-dispatch-worktree.sh`: T15 asserts `result --dir <main>` (no `--expect-pid`) reports
      the main tree's own build after an unrelated worktree build has completed — the false green
      is gone.
- [ ] Both new cases demonstrably FAIL before Phase 2 and PASS after it (record both runs).
- [ ] `test-lake-build-guard.sh`: Test C asserts no cross-tree `REPLAY:` over a raw `cp -al`-shared
      `.lake/`, and is proven load-bearing by a reverted local mutation to
      `compute_fingerprint()`.
- [ ] Every pre-existing case in both suites still passes.
- [ ] `run-all.sh` exits 0 in source-store mode, and (via `verify-deploy.sh` Gate 8, if present)
      in deployed mode.
- [ ] `bash -n` clean on all four touched files.
- [ ] No change of any kind under `~/Projects/BimodalLogic` (`git -C ~/Projects/BimodalLogic
      status --short` unchanged).

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/dispatch-worktree.sh` — `cmd_provision()` excludes the
  five `build-guard.*` state files from the `.lake/` hardlink clone; header records the hazard.
- `agent-system/extensions/core/scripts/lake-build-guard.sh` — header records the
  no-hardlink-sharing convention and the `--git-common-dir` dead end. No logic change.
- `agent-system/extensions/core/scripts/tests/test-dispatch-worktree.sh` — cases T14 and T15.
- `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` — Test C.
- Regenerated `.claude/scripts/` deploy copies of all four (gitignored).
- `specs/268_lake_build_guard_false_green_scope_key/summaries/01_*-summary.md` at implementation
  close, recording the confirmed mechanism, the before/after test evidence, and the
  `batch-orchestration-guardrails.md` note carried as a follow-up.

## Rollback/Contingency

Each phase commits its own hunks separately, so a single phase can be reverted with
`git revert <sha>` on a clean tree without disturbing the others. Phase 2 is the only phase with
executable blast radius; reverting it alone restores the previous clone behavior and leaves
Phase 1's tests in place as (correctly) failing red cases documenting the open defect.

Phases 1, 3 and 4 are independently revertible with no runtime effect. Phase 5 is idempotent:
re-running `deploy-headless.sh` after any revert brings `.claude/` back in line with whatever the
source store holds; `.claude/` is gitignored and carries nothing that needs reverting itself.

If an in-progress phase must be abandoned with uncommitted changes on the tree, this is a genuine
rollback, not a routine checkpoint: take the snapshot first per
`context/contracts/recovery.md`'s rollback rung (which names the exact `git-snapshot.sh`
invocation, including its out-of-scope override flag for a deliberate whole-tree case), then
perform the revert. Never emit a bare default-mode `git-snapshot.sh` as a precautionary
start-of-phase checkpoint; a defensive checkpoint before risky work uses `--no-revert`.
