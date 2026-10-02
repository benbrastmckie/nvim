# Implementation Plan: Task #317

- **Task**: 317 - Post-deploy reconcile promotion must append to the batch's `completed_tasks` ledger
- **Status**: [NOT STARTED]
- **Effort**: 4 hours
- **Dependencies**: Overlaps task 265's `file_scope` (same two files) — per this task's own dispatch, the two MUST NOT run concurrently. No blocking artifact dependency.
- **Research Inputs**: specs/317_post_deploy_reconcile_completed_tasks_ledger/reports/01_post-deploy-reconcile-ledger.md
- **Artifacts**: plans/01_reconcile-ledger-and-commit.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/source-store-deploy-boundary.md
  - .claude/context/standards/git-staging-scope.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The post-deploy reconcile pass in `orchestrate-cycle-plan.sh` promotes a deploy-unblocked task to
`completed` in `specs/state.json` but never reflects that into the batch's `.completed_tasks`
accumulator and never commits the `state.json`/`TODO.md` write — so a batch under-reports its own
`### Succeeded` table, skips `.dispatch/` cleanup for the promoted task, and leaves the durable git
record ("orchestration paused (cycle N)") contradicting `state.json`. The fix is two additions at
the single already-identified write site plus a non-vacuous RED-then-GREEN regression arm. Done
means: a reconcile-promoted task appears in `.completed_tasks`, its completion transition is
committed by its own scoped commit, and a test asserts both against source that provably failed
them beforehand.

### Research Integration

The research report settled every open question the dispatch left, and this plan implements its
decisions without re-litigating them:

- **Write site confirmed**: `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh:1132-1148`
  — the promotion loop already computes `_pdr_outcome="promoted"` from a precise
  `grep -q "promoted .* -> completed"` (which matches only the two `-> completed` transitions in
  `reconcile-task-status.sh`, never the `-> researched`/`-> planned` ones). No new detection logic
  is needed, only a new action on an already-correct condition.
- **Consequence 1 → option (a)**, append at the promotion site. Option (b) (re-derive Move 4's
  `### Succeeded` set from authoritative per-task status, making the accumulator advisory) is
  rejected: the accumulator is written correctly by `orchestrate-cycle-postflight.sh:1427` for
  every ordinary dispatch — exactly one site forgot to, and widening the reporting contract
  consumed by every completion path is disproportionate to a one-site omission.
- **Consequence 2 → the promotion issues its own scoped commit**, not "refuse to stop on
  `all_terminal`". The refuse-to-stop alternative would need a generic "is my promotion still
  uncommitted" signal built on working-tree dirtiness, which is unsafe in this script's own stated
  envelope (concurrent sibling tasks dirtying the same shared tree). A targeted explicit-file
  commit at the point of mutation needs no such signal.
- **The promotion loop is the last possible commit point**: the all-terminal check at
  `orchestrate-cycle-plan.sh:1502-1514` can `emit_and_exit` with `stop_reason="all_terminal"` in the
  same invocation, after `current_statuses` is refreshed from the just-promoted state, with no
  intervening dispatch and therefore no intervening postflight. Move 4's own residue check is
  warn-only and cannot close the gap.
- **File scope of a promotion is exactly two files** (`specs/state.json`, `specs/TODO.md`):
  `reconcile-task-status.sh`'s `link_artifact` writes only `state.json` and regenerates `TODO.md`;
  the task-directory deliverable was already committed by the earlier "orchestration paused" commit.
- **Harness state**: Group 29 Arm A already drives this exact scenario with the real
  `reconcile-task-status.sh`, but has zero `.completed_tasks` assertion and zero git involvement —
  `$WORKDIR` is not a git repository in this suite today.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no ROADMAP.md consultation performed.

## Goals & Non-Goals

**Goals**:
- A post-deploy reconcile promotion appends the promoted task number to `.completed_tasks` on the
  multi-state file, so Move 4's `### Succeeded` table and `.dispatch/` cleanup pick it up with no
  consumer change.
- A post-deploy reconcile promotion commits its own `specs/state.json` + `specs/TODO.md` transition
  via `git-commit-scoped.sh` with an explicit two-entry pathspec, so the durable git record cannot
  contradict `state.json`.
- A regression case in `scripts/tests/test-orchestrate-cycle-plan.sh` asserts both, demonstrated RED
  against unfixed source before the fix lands.
- The promotion block's header comment states the ledger-and-commit obligation, so a future
  promotion branch added to this loop does not reintroduce the gap.

**Non-Goals**:
- Option (b): no change to Move 4's reporting derivation, to `skill-orchestrate/SKILL.md`, or to
  `docs/architecture/orchestrate-state-machine.md`. Research confirmed the existing consumer
  documentation is already correct once the accumulator is complete.
- No new retry, escalation, or blocking posture for a failed commit — a commit failure here stays
  non-blocking, matching every other commit-failure path in this codebase.
- No change to the `all_terminal` stop condition or to `emit_and_exit`.
- No re-implementation of the `.status` vs `.persisted_status` fix (already shipped, different
  defect — a single postflight's self-report, not a batch ledger bypassing postflight).
- No concurrent execution with task 265 (shared `file_scope` on both files).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `git init` on `$WORKDIR` leaks into Groups 31-33b, which run after Group 29 in the same shared sandbox | M | M | Scope the repo to the new arm: `git init` at arm start, `rm -rf "$WORKDIR/.git"` at arm end. Phase 1's verification runs the WHOLE suite (not just Group 29) to prove no cross-group fallout either way. |
| `git-commit-scoped.sh` fails in the fixture for an environmental reason (missing `user.email`, no initial commit for `rev-parse HEAD`) and the arm looks GREEN-by-accident or flaky | H | M | Follow `test-orchestrate-cycle-postflight.sh:86-121`'s established precedent exactly: `git init -q`, `git config user.email`/`user.name`, then an initial fixture commit before `run_sut`. Assert HEAD *advanced* (before/after `rev-parse`), not merely that a commit exists. |
| A stub for `git-commit-scoped.sh` would pass while the real commit silently fails | H | L | Use the REAL `git-commit-scoped.sh` copied into `$WORKDIR/.claude/scripts/`, per research's explicit rejection of a stub for this assertion. |
| `git-commit-scoped.sh`'s V5 contended-path refusal (exit 3) leaves a `completed` status uncommitted | M | L | Accepted, pre-existing residual risk class, identical in kind to `orchestrate-cycle-postflight.sh:1392`'s own non-blocking posture; Move 4's residue check still surfaces it warn-only. Not widened by this change. |
| A future refactor moves the promotion loop out of its "no dispatch in flight" window, breaking the commit's concurrency assumption | M | L | Phase 4 extends the block header comment to name the commit's dependence on that placement invariant, so a future mover sees it. |
| Both files overlap task 265's `file_scope`, risking a merge/territory collision | M | M | Serialize: do not run concurrently with task 265 (dispatch-level dependency edge already recorded). |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel. Every wave here holds one phase: Phases 2 and 3
edit the same ~16-line loop in the same file and are deliberately serialized rather than parallelized.

---

### Phase 1: Add the RED regression arm to Group 29 [NOT STARTED]

**Goal**: A new arm in `test-orchestrate-cycle-plan.sh` Group 29 that drives a post-deploy reconcile
promotion in a real git repository and asserts the ledger append, the commit, and the absence of
uncommitted residue — demonstrated RED against unfixed source, so the assertions are known
non-vacuous.

**Tasks**:
- [ ] Copy the real `git-commit-scoped.sh` into the sandbox alongside Group 29's other real
      collaborators: `cp "$CORE_DIR/git-commit-scoped.sh" "$WORKDIR/.claude/scripts/git-commit-scoped.sh"`
      (and `chmod +x`). Confirm its own dependencies are already real in this suite: `lib/common.sh`,
      `deploy-root-guard.sh`, `task-lock.sh` (all present per the suite's `require_file` preamble).
- [ ] Add a new arm (Arm F) immediately after Arm E, reusing `g29_seed_state_and_mt` +
      `g29_write_task_fixture` with a fresh synthetic task number and `deploy_pending=true`,
      `with_summary=true` — the same shape as Arm A.
- [ ] Make `$WORKDIR` a git repository scoped to this arm, mirroring
      `test-orchestrate-cycle-postflight.sh:86-121`: `git init -q "$WORKDIR"`,
      `git -C "$WORKDIR" config user.email`/`user.name`, then stage and commit an initial fixture
      commit (`git -C "$WORKDIR" add specs .claude && git -C "$WORKDIR" commit -q -m fixture`) so
      `git rev-parse HEAD` resolves. Exclude the nested `g29-source-repo` from staging if git
      complains about it (it is a nested repo and should stay untracked).
- [ ] Capture `before_head="$(git -C "$WORKDIR" rev-parse HEAD)"` before `run_sut`.
- [ ] Run the SUT with the usual Group 29 stubs (`write_g11_verify_stub`,
      `write_g11_deploy_headless_stub 0`) and assert the existing baseline still holds for this arm
      (stderr `post-deploy reconcile for task #<N> ... promoted`, `state.json` status `completed`) so
      a RED result is attributable to the new assertions, not a broken fixture.
- [ ] Add the three NEW assertions:
      (i) `jq -r '.completed_tasks' "$mt_state_file"` contains the promoted task number;
      (ii) `git -C "$WORKDIR" rev-parse HEAD` differs from `before_head`;
      (iii) `git -C "$WORKDIR" status --porcelain -- specs/state.json specs/TODO.md` is empty.
- [ ] Tear the repo down at arm end (`rm -rf "$WORKDIR/.git"`) so Groups 31-33b see the same
      sandbox they do today.
- [ ] Run the arm against UNFIXED source and record the RED evidence: assertion (i) must fail
      (`.completed_tasks` lacks the number) and assertions (ii)/(iii) must fail (HEAD unchanged,
      residue present). Capture the actual failing output in the phase's commit body or progress
      notes — a RED claim without captured output is not evidence.
- [ ] Run the ENTIRE suite and confirm Groups 1-33b are unchanged in pass count except for the new
      arm's expected failures.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts (a) exactly one file is modified
(`scripts/tests/test-orchestrate-cycle-plan.sh`) and (b) exactly three new assertions are added.
Confirm at implementation time by `git status --short` after the edit (expect a single modified
path) and by counting the new `pass`/`fail` pairs in the arm. If a `require_file` entry for
`git-commit-scoped.sh` must also be added to the suite preamble, that is still the same single file
— but if a *second* file turns out to need changing, stop and record why before proceeding.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - add the
  `git-commit-scoped.sh` copy into the Group 29 collaborator installation block, add Arm F with the
  git-repo setup/teardown and the three new assertions

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` runs to
  completion (exit 1 expected at this phase, from the new arm only).
- The new arm's three assertions FAIL with output naming the missing ledger entry and the unchanged
  HEAD — captured verbatim as the RED evidence.
- Every pre-existing case in Groups 1-33b still passes; the delta in `[FAIL]` lines is exactly the
  new arm's.

---

### Phase 2: Append the promoted task to `.completed_tasks` [NOT STARTED]

**Goal**: A promotion reflects itself into the batch ledger, turning Phase 1's assertion (i) GREEN
and restoring both Move 4 consumers (the `### Succeeded` table and the `.dispatch/` cleanup set).

**Tasks**:
- [ ] In `scripts/orchestrate-cycle-plan.sh`'s promotion loop (the `_pdr_outcome` block, currently
      lines 1132-1148), add — gated on the already-computed `_pdr_outcome = "promoted"` condition —
      an `mt_set` append mirroring `orchestrate-cycle-postflight.sh:1427`'s idiom:
      `mt_set --argjson t "$_pdr_t" '.completed_tasks = ((.completed_tasks // []) + [$t] | unique)'`.
- [ ] Rely on the existing `mt_save` at the end of the loop rather than adding a per-iteration save
      (avoids an extra temp-file write per promoted task in a multi-promotion cycle). Confirm
      `.completed_tasks` needs no additional default guard — it is already `//= []` at initial
      mt_json construction (`orchestrate-cycle-plan.sh:542`).
- [ ] Confirm the append does NOT fire for `refused` or `no-op` outcomes, nor for the
      `-> researched` / `-> planned` promotions (the existing `grep -q "promoted .* -> completed"`
      already excludes them).
- [ ] Re-run Phase 1's arm: assertion (i) GREEN; (ii)/(iii) still RED.

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: Asserts exactly one edit site in one file (the promotion loop). Confirm by
`grep -n 'completed_tasks' scripts/orchestrate-cycle-plan.sh` showing exactly one new occurrence
beyond the pre-existing `//= []` default and any pre-existing reads.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - add the `.completed_tasks`
  append inside the post-deploy reconcile promotion loop

**Verification**:
- The regression arm's `.completed_tasks` assertion passes.
- `bash -n scripts/orchestrate-cycle-plan.sh` clean.
- The full `test-orchestrate-cycle-plan.sh` suite shows no NEW failures beyond the arm's still-RED
  commit assertions.
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` still
  passes (the sibling accumulator writer is untouched, but its own `.completed_tasks` cases must
  stay green).

---

### Phase 3: Issue the promotion's own scoped commit [NOT STARTED]

**Goal**: The promotion commits its own `state.json`/`TODO.md` transition before the all-terminal
check can exit, turning Phase 1's assertions (ii) and (iii) GREEN — closing the defect where the
durable git record contradicts `state.json`.

**Tasks**:
- [ ] In the same promotion loop, immediately after the `.completed_tasks` append (same iteration,
      inside the `_pdr_outcome = "promoted"` path), call `git-commit-scoped.sh` mirroring
      `orchestrate-cycle-postflight.sh:1392`'s call shape minus the task-directory entry:
      `--message "task ${_pdr_t}: complete implementation (post-deploy reconcile)"`,
      `--session "$session_id"`, `--task "$_pdr_t"`, then `--` followed by an EXPLICIT two-entry
      pathspec: `"$STATE_FILE"` and `"$(dirname "$STATE_FILE")/TODO.md"`.
- [ ] Use an explicit file list, never a directory or glob pathspec, per
      `.claude/context/standards/git-staging-scope.md`'s directory-pathspec rule.
- [ ] Make a non-zero exit NON-BLOCKING: `|| echo "[orchestrate] REDEPLOY CHECKPOINT WARNING: ..."
      >&2`, naming the task and that the `completed` status is on disk but left uncommitted for a
      later commit to pick up. Continue the loop for remaining tasks. This matches this file's own
      existing `REDEPLOY CHECKPOINT WARNING` idiom (lines 922, 928, 984) and postflight's
      non-blocking commit-failure posture.
- [ ] Route `git-commit-scoped.sh`'s stdout away from this script's own stdout contract. Confirm how
      this script's stdout is structured before choosing: if the entry point already has a
      `exec 3>&1 1>&2`-style diagnostic redirect in force at this point (as postflight does, which
      is why its own call site needs no `>&2`), no per-call redirect is needed; otherwise add an
      explicit `>&2`. Verify by checking the SUT's stdout is still exactly one parseable JSON object
      in the regression arm.
- [ ] Re-run Phase 1's arm: assertions (ii) HEAD advanced and (iii) no residue both GREEN.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: Asserts the promotion's complete file footprint is exactly two paths
(`specs/state.json`, `specs/TODO.md`) and that one edit site in one file is needed. Confirm at
implementation time by `git -C "$WORKDIR" status --porcelain` in the regression arm BEFORE the
commit assertion: if any third path is dirty from the promotion itself, the pathspec is incomplete
and must be widened to name that path explicitly (never by substituting a directory pathspec).

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - add the scoped-commit call and
  its non-blocking warning fallback inside the promotion loop

**Verification**:
- The regression arm's HEAD-advanced and no-residue assertions pass.
- `git log -1 --format=%s` in the fixture repo reads
  `task <N>: complete implementation (post-deploy reconcile)` — distinguishable from the ordinary
  postflight message, so the git record says why the commit exists.
- The SUT's stdout in the arm is still exactly one parseable JSON object
  (`jq . <<<"$LAST_STDOUT"` succeeds).
- `bash -n scripts/orchestrate-cycle-plan.sh` clean.
- Full `test-orchestrate-cycle-plan.sh` suite GREEN (zero `[FAIL]`).

---

### Phase 4: Document the invariant and run the final gate [NOT STARTED]

**Goal**: The promotion block's header comment states the ledger-and-commit obligation and its
dependence on the serialized placement, and the complete gate set confirms the change is safe to
land across every affected suite.

**Tasks**:
- [ ] Extend the existing post-deploy-reconcile header comment (currently
      `orchestrate-cycle-plan.sh:1111-1131`) in place — no new standalone context file, per the
      research's Context Extension Recommendation — with one paragraph stating: (a) a promotion MUST
      append to `.completed_tasks`, because Move 4 derives both the `### Succeeded` table and the
      `.dispatch/` cleanup set from it; (b) a promotion MUST commit its own `state.json`/`TODO.md`,
      because the all-terminal check can exit this same invocation with no intervening postflight;
      (c) the commit rides this block's existing "no dispatch in flight" placement invariant, so a
      future mover of this code must preserve it or re-derive a replacement.
- [ ] Add a short inline comment at the commit call cross-referencing the block header's
      CONCURRENCY POSTURE note.
- [ ] Verify the comment edit stays inside comment boundaries (no hunk crosses out of a `#` region).
- [ ] Run the repo-wide gate set for this change class: `test-orchestrate-cycle-plan.sh`,
      `test-orchestrate-cycle-postflight.sh`, and any suite covering `reconcile-task-status.sh` or
      `git-commit-scoped.sh` — enumerate them with
      `ls agent-system/extensions/core/scripts/tests/ | grep -iE 'reconcile|commit-scoped|postflight|cycle'`
      and run each, rather than assuming the two named ones are exhaustive.
- [ ] Confirm the source-store boundary held: `git status --short` shows changes ONLY under
      `agent-system/extensions/core/` (plus `specs/`), never under `.claude/**`.
- [ ] Deploy the source store so the deployed `.claude/scripts/orchestrate-cycle-plan.sh` matches
      source — this is what the completion-deploy gate requires before the task can reach
      `completed`. The orchestrate engine's own inter-cycle redeploy checkpoint normally performs
      this; if running outside that flow, run the repo's headless deploy explicitly and confirm the
      deployed copy carries both new behaviors.

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: Asserts that the two named test suites are the complete gate set for this
change. This is a hypothesis, not a fact — confirm by the `ls | grep -iE` enumeration above before
declaring the gate complete, and run every suite it names.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - extend the post-deploy
  reconcile block header comment and add the commit-site cross-reference comment

**Verification**:
- Every enumerated test suite exits 0.
- `git status --short` shows no modification under `.claude/**`.
- The deployed `.claude/scripts/orchestrate-cycle-plan.sh` contains both the `.completed_tasks`
  append and the `git-commit-scoped.sh` call (`grep` both in the deployed copy).
- Diff read-through confirms the comment hunks lie entirely inside `#` comment regions.

---

## Testing & Validation

- [ ] The new Group 29 arm demonstrated RED against unfixed source, with the failing output captured
      (non-vacuous assertion requirement from the dispatch's "Close By").
- [ ] `.completed_tasks` on the multi-state file contains the reconcile-promoted task number.
- [ ] A commit lands for the promotion (HEAD advances) with a message naming the reconcile origin.
- [ ] `git status --porcelain -- specs/state.json specs/TODO.md` is empty after the promotion — no
      uncommitted completion transition left behind.
- [ ] The append fires for `-> completed` promotions only, never for `refused`, `no-op`,
      `-> researched`, or `-> planned`.
- [ ] A commit failure is non-blocking: the loop continues for remaining tasks and emits a
      `REDEPLOY CHECKPOINT WARNING`.
- [ ] The SUT's stdout remains exactly one parseable JSON object.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — zero FAIL.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — zero FAIL.
- [ ] Groups 31-33b unaffected by the arm's temporary git repository.
- [ ] All edits under `agent-system/extensions/core/`; nothing hand-authored under `.claude/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — `.completed_tasks` append,
  scoped commit, extended header comment (3 edits, one loop)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — Group 29 Arm F with
  three new assertions and the real `git-commit-scoped.sh` installed
- `specs/317_post_deploy_reconcile_completed_tasks_ledger/summaries/01_*-summary.md` — execution
  summary (written at implement time)
- Captured RED-then-GREEN evidence for the new arm, recorded in the Phase 1 and Phase 3 commit
  bodies or progress notes

## Rollback/Contingency

Both source edits are additive and confined to one ~16-line loop plus one comment block, so
reverting is a per-phase `git revert` of the phase's own commit — the commit-per-green-substep
granularity makes each phase independently revertible. Phase 2 (ledger append) and Phase 3 (commit)
are separable: if the commit call proves unsafe in the real engine, revert Phase 3 alone and the
ledger fix still stands, leaving consequence 2 open but consequence 1 closed. If the test harness's
temporary git repository causes cross-group fallout that cannot be contained by the
`rm -rf "$WORKDIR/.git"` teardown, revert Phase 1's harness change and re-implement the commit
assertion in a dedicated single-purpose test script instead of inside this shared sandbox.

If a genuine rollback of uncommitted working-tree state is needed, snapshot first per
`.claude/context/contracts/recovery.md`'s rollback rung before running any destructive git command —
never as a routine start-of-phase precaution.
