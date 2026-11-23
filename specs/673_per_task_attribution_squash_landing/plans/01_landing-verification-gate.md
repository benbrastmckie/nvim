# Implementation Plan: Task #673

- **Task**: 673 - Land one reviewable commit per completed task on the integration branch and verify it before the status write
- **Status**: [IMPLEMENTING]
- **Effort**: 11 hours
- **Dependencies**: 669 (completed)
- **Research Inputs**: specs/673_per_task_attribution_squash_landing/reports/01_isolation-off-landing-ruling.md
- **Artifacts**: plans/01_landing-verification-gate.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The ruling in `specs/decisions/isolation-off-landing-verification-and-review-time-squash.md`
(L1 to L5) turns "landing" into a five-part verification (V1 to V5) plus a recorded proof, run
before the completion status write, and hands the per-task squash to the review step. This plan
builds that: a standalone predicate script with its negative fixtures, a reorder of the cycle
postflight so leftover work is committed before the check, an unconditional gate at the one
site every completion path shares (`update-task-status.sh postflight <N> implement`), and the
retirement of the `milestone-ref-land.sh` calls with `milestone-review-handoff.sh` re-pointed at
the integration branch and the proofs. Done means: a completion write cannot happen without the
predicate passing, shown by negative fixtures observed failing, and the repository is never
without a pre-completion landing check during the transition.

All deliverable edits go to the source store, `agent-system/extensions/core/**` (resolved from
`.claude-extensions.json`: `source_dir` is this repository's own
`agent-system/extensions/core`), then a redeploy. No task number, no literal branch name, no
consumer-repository path and no record-versioning phrasing in any file under `agent-system/**`.

### Research Integration

Integrated from the report and the ruling record:

- Option B at landing, option C's squash at review time, option A rejected. Nothing is picked or
  squashed on the integration branch.
- The predicate V1 to V5, the proof element shape, the idempotence short-circuit, the two-batch
  behaviour (V4 refusal, refs intact by construction), second-repository commits recorded and
  not verified, the review-submission interface, and the five-step retirement order.
- The ordering obligation: commit leftovers, verify, write status, completion commit.
- The choke-point hole: the gate goes in `update-task-status.sh`, alternative (a) of the report.
- The report's 30-line `verify` function in `reports/01_fixtures/options-abc.sh` is the port
  source for the predicate, and its E1 cases are the port source for the negative fixtures.

### Premise Re-Validation

Checked on 2026-11-23 against the report, the ruling record and the live source store.

| Carried claim | Result |
|---|---|
| Source store is the edit target (description line 3) | Confirmed. `jq -r .extensions.core.source_dir .claude-extensions.json` prints this repository's `agent-system/extensions/core`. |
| The contradiction (description line 11) | Confirmed and ruled; the ruling record exists (246 lines). |
| Option A's idiom is what `milestone-ref-land.sh` implements (line 15) | Confirmed, and option A is rejected by the ruling. Not built. |
| Landing commit subject `task {N}: {title}` (line 25) | Amended by L1 to L3. No new commit subject: the existing `task {N}: complete implementation` commit carries the body. |
| Refusal on a commit "attributable to no task" (line 26) | Amended: re-keyed to effect, which is V4. |
| "One reviewable unit per completed task" (line 40) | Stands, as one landing proof per task. |
| "A completion status write cannot occur without the landing verification" (line 42) | Stands, and is why the gate is placed in `update-task-status.sh`. |
| Report: five completion-write callers, tagged CORPUS-UNVERIFIED | Re-derived with a second pattern (`update-task-status.sh\b.*postflight` and `skill_postflight_update` over `scripts/`, `scripts/lib/`, `hooks/`). It found more: `orchestrator-postflight.sh:339`, `command-gate-out.sh:203` and `:305`, `skill-base.sh:1124`, `orchestrate-close-status-bind.sh:143` (writes `partial` only). Every one reaches `update-task-status.sh`. The caller list is not complete by enumeration, which confirms the single-site placement. |
| Report: postflight call-site line numbers (1378 to 1380, 1411, 1883, 2119, 2255, 2617, 2641) | Re-derived by `grep -n`; all match today. |
| Report: per-cycle commit "exits 2 to 6 log UNCOMMITTED and proceed" | Partly stale. Lines 2254 to 2261 already demote a just-completed task to `partial` on commit exit 2, 3, 4 or 5. The live shapes that remain are exit 1, 6, 8 and 9, a path dropped as a `file_scope` excursion, and an empty `modified_files`. The reorder is still required. |
| Report: `update-task-status.sh` "needs adding to `file_scope`" | Already declared in the task's `file_scope` in `specs/state.json`. |
| Report: 14 tasks, 0 refusals with state territory excluded; 108 of 700 unattributed; 438 reused numbers | CARRIED-UNVERIFIED from the report's `corpus-predicate.sh` run. Not re-run here; no phase depends on the exact figures. |
| `update-task-status.sh` exit codes 0 to 6 are taken | Confirmed from the script header. Exit 7 is free. |

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`specs/ROADMAP.md` lists 673 after `integration_branch_admission_and_batch_worktree` (669,
completed) and ahead of `stack_pr_submission_from_integration_branch` (685) and
`branch_topology_documentation_parity` (675), both blocked on this task. This plan delivers the
proof record and interface 685 consumes, and leaves the two narrative documents to 675.

## Goals & Non-Goals

**Goals**:
- A predicate script implementing V1 to V5 with a distinct exit code per refusal, a read-only
  mode and a verify-and-record mode, and a suite whose negative fixtures were observed failing.
- An unconditional gate in `update-task-status.sh` so no caller can write `completed` for an
  implement postflight while the predicate refuses.
- The cycle postflight ordered: commit leftovers, verify, write status, completion commit; the
  completion commit's body carries the phase list, the attributed commits and any
  second-repository commits.
- One landing proof per completed task in the batch record; a re-run is a no-op.
- `milestone-ref-land.sh` unwired from postflight only after the gate is live;
  `milestone-review-handoff.sh` reads the integration branch and the proofs.

**Non-Goals**:
- Building the review ref or the per-task squash (L4). That is 685's.
- Worktree isolation, a batch branch, and the back-merge. Deferred.
- Verifying a second repository's branch. Open work of 536.
- Editing `skills/skill-orchestrate/SKILL.md` or `commands/orchestrate.md`.
- Rewriting `context/standards/git-workflow-narrative.md` or
  `context/contracts/conclusion-stage.md`. They are 675's.
- Deleting existing `refs/heads/milestone/*` refs, or pushing anything.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The gate breaks existing suites whose fixtures call an implement postflight in a `git` repository with no attributed commit | H | H | Phase 5 measures the affected suites before the gate is switched on and repairs fixtures in the same phase. A non-`git` project root passes through as inconclusive, the posture the deploy gate already takes. No environment-variable bypass is added. |
| A sibling task's redeploy copies a half-built gate out of the source-store working tree | H | M | Phase order: the predicate script lands first (Phase 2), callers learn exit 7 before anything emits it (Phase 4), and the gate block is added in one edit with its suite (Phase 5). Every commit is green by itself. |
| V5 refuses a legitimate completion because a reported path was dropped as a `file_scope` excursion | M | M | This is the ruling's intent. The refusal message names the path and the two remedies (commit it under the task's subject, or revert it). False-refusal rate is unmeasured; Phase 7 records the first live observations. |
| The reorder changes which commit carries the `completed` state files | M | M | Phase 3 keeps the completion commit after the status write and pins the order in the postflight suite. |
| Idempotence fails after the completion commit, because that commit becomes the task's last attributed commit | M | H | Decision D4 below: the end commit is the last attributed commit touching a path outside the state territory. Pinned by a fixture that re-runs after the completion commit. |
| This task's own completion is the gate's first live run | M | M | A refusal there is a finding to report and fix, never to bypass. Phase 7 states the expected proof. |
| Shared territory: `orchestrate-cycle-postflight.sh` is in eight open tasks' scope, `update-task-status.sh` overlaps 438 and 598 | M | M | Edits are confined to the landing block, the commit block and one gate block; no unrelated refactor. Batching and dependency edges are the orchestrator's. |
| Lock order between the status script's own lock and `specs/.commit-lock` | M | L | The predicate takes the commit mutex the way `milestone-ref-land.sh` does (guest when `COMMIT_MUTEX_HELD=1`, fail-open with a named warning). Phase 5 checks that no path holds the commit mutex while waiting on the status lock. |
| Subject-convention attribution trusts commit subjects | L | L | Unchanged from the amending record's defect 8. Not closed here. |

## Decisions

- **D1. Gate placement: inside `update-task-status.sh`.** It is the only site every completion
  path reaches, and the second search above found callers the first missed. Wiring each caller
  was rejected: the list cannot be proved complete.
- **D2. Script name: `task-landing-verify.sh`, suite `test-task-landing-verify.sh`.** The
  declared `file_scope` names `task-squash-land.sh`. Nothing is squashed, so that name would
  describe a mechanism the ruling rejected. The plan's `Files to modify` blocks are the new
  declaration.
- **D3. Exit codes.** Predicate script: `0` pass (including the idempotent no-op), `2` usage or
  environment, `10` V1, `11` V2, `12` V4, `13` V5. `update-task-status.sh`: new exit `7`,
  "landing verification refused", with no state write and no plan-file stamp.
- **D4. End commit.** The task's last attributed commit that touches at least one path outside
  `BATCH_ADMISSION_STATE_TERRITORY`. The ruling says "its last attributed commit"; read
  literally, the completion commit (state files only) would replace it and no re-run could be a
  no-op. Phase 1 records this clarification in the ruling record.
- **D5. Inconclusive cases pass through, named.** Not a `git` work tree, `jq` or `git` missing,
  or the task absent from both state files: the gate prints one named line and proceeds. This is
  the deploy gate's documented posture. A `git` work tree with an empty V2 set is conclusive and
  refuses.
- **D6. Integration branch resolution.** The batch record that lists the task (found by
  `task_numbers` membership, newest `admitted_at`); else the declared `integration_branch`; else
  the branch `HEAD` symbolically names. With neither record nor declaration V1 still refuses a
  detached `HEAD`.
- **D7. No batch record: verify, do not record.** A completion outside an admitted batch has no
  record to append to. The predicate still gates the write and prints one notice that no proof
  was recorded. The ruling's V2 fallback covers a task with no proof.
- **D8. `milestone-ref-land.sh` stays on disk, unwired.** The ruling retires it "as a landing
  mechanism" and leaves existing refs alone; it does not order the file deleted. Deleting it
  would leave two documents owned by 675 naming a missing script, and 685 builds its review ref
  with the same plumbing. Its header is revised to state what it is: a snapshot utility that no
  lifecycle script calls. Deletion or reuse is left to 685 and 675.
- **D9. Refusal variable.** `milestone_landing_refusal` and the verdict key `milestone_landing`
  are renamed `landing_refusal` and `landing` in Phase 6, when the milestone calls go. Both
  names are read only inside `orchestrate-cycle-postflight.sh` and its suite (one `grep -rl`
  over the source store).
- **D10. No user decision is raised.** The report's one non-blocking note (the integration
  branch keeps one commit per phase) is already stated in the ruling record.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 2 |
| 3 | 4 | 3 |
| 4 | 5 | 4 |
| 5 | 6 | 5 |
| 6 | 7 | 1, 6 |

Phases within the same wave can execute in parallel.

### Phase 1: Record the amendments and clarifications [COMPLETED]

**Goal**: The amending record points at the ruling that amends it, and the ruling record states
the three clarifications this plan makes.

**Tasks**:
- [x] Confirm both records exist:
      `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md` (sections
      `### R3, amended`, `## Isolation-off repositories (Option L1)`,
      `## Built-mechanism verdicts`) and
      `specs/decisions/isolation-off-landing-verification-and-review-time-squash.md`. Both were
      present at plan time, and the first carried zero `Amended by` notes. If either is missing,
      stop and report; do not recreate a record from this plan. *(completed)*
- [x] Add one dated note under each of the three sections of the amending record, in the form
      `**Amended by** specs/decisions/isolation-off-landing-verification-and-review-time-squash.md, 2026-11-23:`
      followed by one sentence naming what changed for the isolation-off path. Change no other
      text in that record. *(completed)*
- [x] Append a short "Implementation clarifications" section to the ruling record stating D2
      (script name), D3 (exit codes), D4 (end commit definition) and D8 (the script file stays,
      unwired), each in one or two sentences. *(completed)*
- [x] Record issues and wins with `issue-record.sh` as they arise, here and in every later phase. *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: Both files lie under `specs/**`, so the covering check is the diff read-through of the two records, confirming each hunk is an added note or the one appended section.

**Files to modify**:
- `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md` - three dated `Amended by` notes
- `specs/decisions/isolation-off-landing-verification-and-review-time-squash.md` - appended clarifications section

**Verification**:
- `grep -c 'Amended by' specs/decisions/batch-worktree-isolation-and-task-squash-landing.md`
  prints `3`.
- `git diff` on the amending record shows additions only.

---

### Phase 2: The landing predicate, the proof writer and their suite [NOT STARTED]

**Goal**: `task-landing-verify.sh` implements V1 to V5 and the proof, exercised by a suite whose
negative fixtures were each observed failing before the check that catches them existed. Nothing
calls the script yet.

**Tasks**:
- [ ] Add to `scripts/lib/batch-admission-lib.sh`, without changing any existing function's
      signature: a lookup returning the batch record that lists a task (by `task_numbers`
      membership, newest `admitted_at`), and an appender that adds one element to
      `landing_proofs` by tmp-file-then-rename. Extend `test-batch-admission-lib.sh` for both.
- [ ] Write `scripts/task-landing-verify.sh`. Arguments: task number, `--session SID`,
      `--check` (read-only, never writes a proof), optional `--modified-files-from FILE`
      (a `.return-meta.json`), and `--print-body` (emit the commit-body block from an existing
      proof). Port the `verify` function from
      `specs/673_per_task_attribution_squash_landing/reports/01_fixtures/options-abc.sh`.
- [ ] Implement, in order: V1 (`HEAD` symbolic and equal to the resolved integration branch,
      D6); V2 (non-merge commits on that branch whose subject matches the task's `task {N}:` or
      `task {N} phase` convention, committed at or after the task's `created` timestamp read
      from `specs/state.json`, falling back to `specs/archive/state.json`); V3 (union of touched
      paths less `BATCH_ADMISSION_STATE_TERRITORY`); V4 (blob at the tip equals blob at the end
      commit, D4, for each path; on mismatch print `git log <end>..<tip> -- <path>`); V5 (no
      path of the set, and no reported modified path inside the repository and outside the state
      territory, differs between the working tree and the tip, untracked reported files
      included).
- [ ] Refusals print one line naming the check, the offending path or commit, and the remedy,
      and exit with D3's codes. A refusal writes nothing.
- [ ] Verify-and-record mode: under `specs/.commit-lock` (guest when `COMMIT_MUTEX_HELD=1`,
      fail-open with a named warning, as `milestone-ref-land.sh` does), append the proof with
      the ruling's fields: `task_number`, `session_id`, `landed_at`, `integration_branch`,
      `commits`, `end_commit`, `tip_at_verification`, `paths`, `shared_paths`, `phases`,
      `source_store_commits`. `phases` comes from the task's plan file's completed phase
      headings; `source_store_commits` from the return metadata where reported, else empty.
- [ ] Idempotence: an existing proof for the task whose `end_commit` equals the current end
      commit makes the run a passing no-op that appends nothing.
- [ ] Inconclusive cases per D5 exit 0 with one named line. No record per D7: verify, print the
      notice, append nothing.
- [ ] Write `scripts/tests/test-task-landing-verify.sh` on scratch repositories. For each
      negative fixture, first run it against a deliberately weakened predicate (the one check
      under test disabled by a test-only seam in the fixture copy, never in the shipped script)
      or against the pre-check commit, observe the fixture failing to refuse, and record that
      observation in the task's issue log as a `win` entry naming the fixture. Cases: clean
      two-task interleave passes; edited-never-committed refuses V5; reported new file never
      committed refuses V5; foreign commit over a task path after the end commit refuses V4 for
      that task and names the commit while the sibling passes (the two-batch case); detached
      `HEAD` refuses V1; no attributed commit refuses V2; a reused task number older than
      `created` is not attributed; state-territory paths are excluded; re-run after a recorded
      proof is a no-op; re-run after a later state-only attributed commit is still a no-op (D4);
      a dependent task editing the same file later does not fail the earlier task; no batch
      record verifies without recording; non-`git` root passes through; `--check` writes
      nothing; a refusal leaves every ref and the batch record byte-identical.
- [ ] Register both new files in `manifest.json` and add the suite's row to
      `scripts/tests/suite-classification.data` (class `unit`), in this phase.
- [ ] Document the `landing_proofs` element shape in
      `context/standards/orchestrator-runtime-files.md`, beside the existing batch-record
      description, stating the current shape only.

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: interface

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over this phase's seven declared paths covers the new script, the two added library functions and the two registries the manifest-sync and boundary lints read.

**Scope Hypothesis**: Seven files, and no existing function in `batch-admission-lib.sh` changes signature. Confirm with `git diff --stat` at phase end and by the pre-existing groups of `test-batch-admission-lib.sh` passing unmodified. The document edit is expected to leave `index-entries.json`'s `line_count` to the Phase 7 redeploy's auto-repair, as it did for the same document's last edit.

**Files to modify**:
- `agent-system/extensions/core/scripts/task-landing-verify.sh` - new: the predicate and proof writer
- `agent-system/extensions/core/scripts/tests/test-task-landing-verify.sh` - new: positive, negative, idempotence and two-batch fixtures
- `agent-system/extensions/core/scripts/lib/batch-admission-lib.sh` - record lookup by task, proof appender
- `agent-system/extensions/core/scripts/tests/test-batch-admission-lib.sh` - cases for the two added functions
- `agent-system/extensions/core/manifest.json` - register the script and the suite
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - one `unit` row
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - `landing_proofs` element shape

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-task-landing-verify.sh` passes, and each
  negative fixture has a recorded observed-failing entry in the issue log.
- `bash agent-system/extensions/core/scripts/tests/test-batch-admission-lib.sh` passes.
- `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` exits 0.
- `shellcheck` is clean on the new script and suite, and the suite carries its exec bit.
- `grep -rn 'task-landing-verify' agent-system/extensions/core/scripts --include='*.sh' -l`
  lists only the script and its suite: nothing calls it yet.

---

### Phase 3: Commit leftovers before the completion write [NOT STARTED]

**Goal**: In the cycle postflight, a just-implemented task's leftover work is committed before
the landing check and the status write, and the completion commit follows the write. The
milestone calls stay where they are.

**Tasks**:
- [ ] Read WORK (f) through WORK (j) of `scripts/orchestrate-cycle-postflight.sh` and its header
      before editing; the header documents an order dependence between WORK (h) and WORK (i)
      that must survive.
- [ ] For an `implemented` dispatch whose phase-accounting gate passed, move the staging and
      commit of leftover `modified_files` (excursion drop-and-warn unchanged) ahead of the
      milestone landing block and the status write. Its subject follows the task's
      `task {N}:` convention so V2 attributes it; it never reads "complete implementation".
- [ ] Keep the existing per-cycle commit after the status write as the completion commit. It now
      carries the state files the write changed, with the subject
      `task {N}: complete implementation` only under the same conjunction as today.
- [ ] Re-derive the exit-code handling for both commits against
      `context/standards/git-staging-scope.md`'s table. A failure of the leftover commit with
      exit 2, 3, 4 or 5 now happens before the write: the write is skipped and the task stays
      in flight, where today it is written and then demoted. Exit 1, 6, 8 and 9 keep their
      current meaning. Every other dispatch status keeps today's single commit, byte for byte.
- [ ] Extend `test-orchestrate-cycle-postflight.sh`: the leftover commit precedes the status
      write (assert by commit order and by the state file's content at the leftover commit); a
      leftover-commit failure leaves the status un-completed; a non-`implemented` dispatch
      produces the same commits as before.

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: interface

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over this phase's two declared paths runs every suite the selector resolves for the cycle postflight script, which is the whole set its reordered commit block can break.

**Scope Hypothesis**: Two files. No caller of the cycle postflight depends on there being exactly one commit per implemented cycle. Confirm by grepping the suites `verify-touched.sh` selects for commit-count assertions before editing, and by that run staying green.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - leftover commit ahead of the landing check and the status write
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - ordering and failure cases

**Verification**:
- The postflight suite passes, including the new ordering cases.
- The single-JSON-line stdout contract of the script is unchanged (its existing suite group).
- `grep -c 'milestone-ref-land.sh' agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`
  is unchanged from before the phase: the milestone check is still wired.

---

### Phase 4: Teach the cycle postflight the refusal and the commit body [NOT STARTED]

**Goal**: The cycle postflight treats exit 7 from the status write as a landing refusal and
writes the landing proof's content into the completion commit's body. Nothing emits exit 7 yet,
so this phase changes no live behaviour except the body.

**Tasks**:
- [ ] Where the script captures `postflight_rc` from `skill_postflight_update`, add an exit-7
      arm beside the exit-6 arm: set the landing refusal, print one `LANDING-REFUSED` line
      naming the task and pointing at the predicate's own line above, record one issue-log entry
      (class "landing verification", severity `costly`), and skip everything a completed task
      would get. The verdict and the commit subject must not claim completion; the conjunction
      at the four gating sites already reads the refusal variable.
- [ ] After a successful completion write, obtain the body block with
      `task-landing-verify.sh <N> --session <SID> --print-body` and pass it in the completion
      commit's message after the subject: the phase list, the attributed commits oldest first,
      the end commit, and any second-repository commits as repository identifier plus commit.
      When no proof exists (D7) the body carries the session line only, as today.
- [ ] Extend the postflight suite: a stubbed status write returning 7 yields no completion
      subject, a `defer` verdict and the issue-log entry; a normal completion's commit body
      carries the phase list and the commit list.
- [ ] Confirm, by reading each, how the other callers treat a nonzero exit other than 6:
      `skill-base.sh` (returns it verbatim), `command-gate-out.sh` (generic warning, no
      completion), `reconcile-task-status.sh` (exits with it), `lib/redeploy-checkpoint-lib.sh`
      (keys on the "promoted" line), `orchestrate-stage5-postflight.sh` and
      `orchestrator-postflight.sh`. Record the result per caller in the phase's notes.

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: interface

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over this phase's two declared paths runs every suite the selector resolves for the cycle postflight script, covering the new exit arm and the commit-body change.

**Scope Hypothesis**: Two files; none of the six other callers needs an edit, because each already treats an unrecognized nonzero exit as "not completed". Read at plan time: `command-gate-out.sh` lines 203 to 320, `reconcile-task-status.sh` lines 685 to 695 and 745 to 752, `skill-base.sh` lines 1124 to 1190. Confirm the remaining three by reading. If a caller would claim completion after exit 7, make the minimal edit there, add that path to this phase's `Files to modify` block before committing, and record the widening as a deviation.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - exit-7 arm, completion commit body
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - refusal and body cases

**Verification**:
- The postflight suite passes with the two new groups.
- A per-caller note exists for all six other callers.

---

### Phase 5: The gate at the completion choke point [NOT STARTED]

**Goal**: `update-task-status.sh postflight <N> implement` refuses with exit 7, writing nothing,
whenever the predicate refuses. From this phase on, two pre-completion landing checks run side
by side in the cycle postflight.

**Tasks**:
- [ ] Before editing, measure the blast radius: list the suites that drive an implement
      postflight (`grep -lE` for `update-task-status.sh`, `skill_postflight_update`,
      `reconcile-task-status.sh`, `command-gate-out.sh` and `orchestrate-cycle-postflight.sh`
      over `scripts/tests/`), run them green, and note which build a `git` fixture.
- [ ] Add a block after the completion-deploy gate, under the same guard
      (`postflight`, `implement`, not a state no-op, not `--dry-run` for the recording half):
      invoke the sibling `task-landing-verify.sh` in verify-and-record mode with the task's
      `.return-meta.json` as the modified-files source. Exit 10 to 13 from it: print the
      refusal, state that no `state.json` write and no plan-file stamp occurred, and `exit 7`.
      Exit 0: proceed. Exit 2 or a missing sibling script: one named inconclusive line, proceed
      (D5). Under `--dry-run` call `--check` and report what would happen.
- [ ] Add exit 7 to the script's header exit-code table, in the same style as exit 6.
- [ ] Write `scripts/tests/test-postflight-landing-gate.sh`: a completion with landed work
      writes `completed` and one proof; work left uncommitted refuses with exit 7 and leaves
      `state.json` and the plan file byte-identical (the negative fixture for the owned
      criterion: observe it writing `completed` with the gate block absent, record that
      observation as a `win` entry, then observe exit 7 with it present); the reconcile
      promotion path (`reconcile-task-status.sh`) is refused the same way; a second call after
      completion is a no-op; a non-`git` root passes through; `--dry-run` writes nothing.
- [ ] Repair every existing fixture the gate now refuses by giving it the commits a real task
      would have, never by weakening the gate. Re-run the measured suite list.
- [ ] Check lock order: no path holds `specs/.commit-lock` while waiting for the status
      script's own lock, and the reverse nesting occurs at one site only.
- [ ] Register the new suite in `manifest.json` and `suite-classification.data`.

**Timing**: 2 hours

**Depends on**: 4

**Verification Tier**: full

**Tier Justification**: `update-task-status.sh` is the single completion choke point reached by the cycle postflight, the reconcile path, gate-out and the redeploy checkpoint, so a behaviour change there reaches every suite that completes a task, which no one-hop dependent list covers.

**Scope Hypothesis**: At plan time 32 suites under `scripts/tests/` matched the five-name pattern above, and 4 matched `postflight[^|]*implement`. How many build a `git` fixture and so need seeding is unknown. Confirm by the measurement in the first task. If the repair needs more than this phase's time, stop with the gate block uncommitted, record the measured count, and return `partial`; do not commit a gate that leaves a suite red. Any repaired suite is added to this phase's `Files to modify` block before its commit.

**Files to modify**:
- `agent-system/extensions/core/scripts/update-task-status.sh` - landing gate block, exit 7
- `agent-system/extensions/core/scripts/tests/test-postflight-landing-gate.sh` - new: gate fixtures including the observed-failing negative
- `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` - fixture seeding where the gate applies
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - fixture seeding where the gate applies
- `agent-system/extensions/core/manifest.json` - register the suite
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - one `unit` row

**Verification**:
- `test-postflight-landing-gate.sh` passes and its negative fixture has both observations
  recorded.
- Every suite in the measured list passes.
- `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` exits 0.
- Under `/orchestrate`, this phase's in-dispatch obligation is
  `bash agent-system/extensions/core/scripts/verify-touched.sh` over its touched paths, with the
  complete gate set deferred to the orchestration close; standalone, it runs
  `bash .claude/scripts/verify-deploy.sh`.

---

### Phase 6: Unwire the milestone landing and re-point the review handoff [NOT STARTED]

**Goal**: Postflight no longer calls `milestone-ref-land.sh`; the gate from Phase 5 is the
pre-completion landing check. `milestone-review-handoff.sh` reads the integration branch and
the landing proofs.

**Tasks**:
- [ ] Confirm Phase 5's gate is committed and its suite green before removing anything.
- [ ] In `orchestrate-cycle-postflight.sh`, remove the two `milestone-ref-land.sh` calls and
      their comment block, and rename the refusal variable and the verdict key per D9 at every
      site. State the current mechanism in the replacing comment; no history narration.
- [ ] Update the postflight suite's milestone groups to the renamed key and to the gate.
- [ ] Rewrite `milestone-review-handoff.sh` steps 3 to 6: no milestone-ref existence or
      commit-count check; per done task, list the completion subject, the attributed commit
      count and the end commit from the task's landing proof, falling back to V2 attribution
      with the mandatory `created` bound for a task with no proof; flag a task whose proof has
      a non-empty `shared_paths`; set `review.ref` to the resolved integration branch (D6, never
      a literal); print the `/please` push request for that branch, then `/merge`. It still
      never pushes and never creates a request. Its call site and arguments are unchanged.
- [ ] Rewrite `test-milestone-review-handoff.sh` for the new range, including a no-proof task
      and a `shared_paths` task, and keep its assertion that the script names no push or forge
      command.
- [ ] Revise the header of `milestone-ref-land.sh` per D8 and update
      `test-milestone-ref-land.sh` only where it asserts header text.
- [ ] Update `context/patterns/ref-plumbing-landing.md`: the idiom stays documented; the
      statement that it lands a task's work at completion is replaced by the current mechanism,
      pointing at `task-landing-verify.sh` and at the ruling record's review-submission
      interface for where the idiom is used.
- [ ] Run the doc lint and the task-reference lint. If either flags
      `context/standards/git-workflow-narrative.md` or `context/contracts/conclusion-stage.md`
      because of this phase's edits, make the smallest edit that clears the finding, add the
      path to this phase's `Files to modify` block, and record it as a deviation with a note
      for 675. Otherwise leave both files untouched.

**Timing**: 2 hours

**Depends on**: 5

**Verification Tier**: interface

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over this phase's seven declared paths covers the renamed verdict key's one consumer suite, the handoff script's suite and the conclusion-roadmap suite that calls it.

**Scope Hypothesis**: Seven files; the verdict key `milestone_landing` has no reader outside `orchestrate-cycle-postflight.sh` and its suite (one `grep -rl milestone_landing` over the source store at plan time returned exactly those two). Re-run that grep, and a second one over `skills/`, `commands/` and `context/` for `milestone_landing`, before renaming. The two narrative documents are excluded unless a lint forces an edit; no task in this phase requires editing them otherwise.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - remove milestone calls, rename refusal variable and verdict key
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - renamed key, gate-based groups
- `agent-system/extensions/core/scripts/milestone-review-handoff.sh` - range and review ref from the integration branch and the proofs
- `agent-system/extensions/core/scripts/tests/test-milestone-review-handoff.sh` - rewritten cases
- `agent-system/extensions/core/scripts/milestone-ref-land.sh` - header only
- `agent-system/extensions/core/scripts/tests/test-milestone-ref-land.sh` - header assertions only, if any
- `agent-system/extensions/core/context/patterns/ref-plumbing-landing.md` - current landing mechanism

**Verification**:
- `grep -c 'milestone-ref-land.sh' agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`
  prints `0`, and `test-postflight-landing-gate.sh` is green in the same commit: at no commit is
  the repository without a pre-completion landing check.
- The postflight, review-handoff, milestone-ref-land and conclusion-roadmap suites pass.
- `grep -nE 'git push|gh |glab ' agent-system/extensions/core/scripts/milestone-review-handoff.sh`
  matches only the header's own prohibition text, as its suite asserts.
- No literal branch name in any file this phase edits.

---

### Phase 7: Redeploy and close [NOT STARTED]

**Goal**: The deployed tree carries the gate, and the four owned criteria are each tied to
suite evidence.

**Tasks**:
- [ ] Redeploy with `bash agent-system/extensions/core/scripts/deploy-headless.sh`; check its
      exit status. If its `line_count` auto-repair changes `index-entries.json` for the two
      documents edited in Phases 2 and 6, stage that file in this phase's commit.
- [ ] Confirm the deployed copies exist: `.claude/scripts/task-landing-verify.sh`,
      `.claude/scripts/tests/test-task-landing-verify.sh`,
      `.claude/scripts/tests/test-postflight-landing-gate.sh`.
- [ ] Run the deployed predicate once in this repository with `--check` against an already
      completed task and report its result; a refusal is a finding to record, not to fix here.
- [ ] Tie each owned criterion to its evidence in the summary: the ruling record (criterion 1);
      the two-task interleave and proof cases (criterion 2); the sibling-still-lands case
      (criterion 3); the gate suite's observed-failing negative fixture (criterion 4).
- [ ] Confirm `skills/skill-orchestrate/SKILL.md` and `commands/orchestrate.md` are
      byte-identical to their state before the task (`git diff --stat` over the task's commits).
- [ ] Run the task-reference lint and the record-versioning lint over every file this task
      edited under `agent-system/**`.
- [ ] State in the summary that this task's own completion passes through the new gate, what
      proof is expected, and that V5's false-refusal rate remains unmeasured.

**Timing**: 1 hour

**Depends on**: 1, 6

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - only if the redeploy's `line_count` auto-repair changes it (coupled generated surface of the Phase 2 and Phase 6 document edits)
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-touched.sh` over this task's full touched
  set is green against the redeployed tree.
- `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` exits 0.
- The task-reference and record-versioning lints report no new finding.
- As the final phase, the in-dispatch obligation is the scoped touched-path check above plus an
  explicit deferral of the complete gate set (`bash .claude/scripts/verify-deploy.sh`) to the
  orchestration close under `/orchestrate`, never an independent full-battery run as this
  phase's own criterion. A standalone, non-orchestrated run of this phase runs the complete
  gate set directly.

## Testing & Validation

- [ ] Each of V1, V2, V4 and V5 refuses in a fixture, with its own exit code, naming the path or
      commit; each negative fixture was observed failing first and that is recorded.
- [ ] A completion with work left uncommitted exits 7 from `update-task-status.sh` and leaves
      `state.json` and the plan file byte-identical, through the cycle postflight and through
      the reconcile path.
- [ ] Two interleaved tasks each get one proof with their phase list; `HEAD` names the same
      branch before and after.
- [ ] A foreign commit over one task's path refuses that task with V4, names the commit, changes
      no ref, and the sibling lands.
- [ ] A re-run after a recorded proof, and after the completion commit, is a no-op.
- [ ] The leftover commit precedes the status write; the completion commit follows it and its
      body lists phases, commits and second-repository commits.
- [ ] No `milestone-ref-land.sh` call remains in postflight, and the gate suite is green at that
      same commit.
- [ ] The review handoff lists per-task subject, commit count and end commit from the proofs and
      names the resolved integration branch.
- [ ] `skills/skill-orchestrate/SKILL.md` and `commands/orchestrate.md` byte-identical.
- [ ] No task number, literal branch name, consumer-repository path or record-versioning
      phrasing in any file under `agent-system/**` touched by this task.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/task-landing-verify.sh` and
  `scripts/tests/test-task-landing-verify.sh`
- `agent-system/extensions/core/scripts/tests/test-postflight-landing-gate.sh`
- Edited: `update-task-status.sh`, `orchestrate-cycle-postflight.sh`,
  `milestone-review-handoff.sh`, `milestone-ref-land.sh` (header), `lib/batch-admission-lib.sh`,
  their suites, `manifest.json`, `scripts/tests/suite-classification.data`,
  `context/standards/orchestrator-runtime-files.md`, `context/patterns/ref-plumbing-landing.md`
- Edited records: the two files under `specs/decisions/` named in Phase 1
- `specs/673_per_task_attribution_squash_landing/summaries/01_landing-verification-gate-summary.md`

## Rollback/Contingency

Each phase is one or more green commits and can be reverted alone with `git revert` in reverse
phase order; no history is rewritten. The order matters in one place: Phase 6 must be reverted
before Phase 5, so that the milestone check is back before the gate goes, and a revert of either
is followed by a redeploy. If the gate refuses legitimate completions after deployment, revert
Phase 6 and Phase 5 together and redeploy; Phases 2 to 4 are inert without the gate and can
stay. If Phase 5's fixture repair overruns, the phase returns `partial` with the gate block
uncommitted, and the milestone check remains the pre-completion verification. No step here
discards uncommitted work; should one become necessary, use the rollback rung of
`context/contracts/recovery.md`.
