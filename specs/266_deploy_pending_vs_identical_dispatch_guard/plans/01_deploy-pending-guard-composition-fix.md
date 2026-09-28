# Implementation Plan: Task #266

- **Task**: 266 - deploy_pending vs identical-dispatch guard: composition defect
- **Status**: [IMPLEMENTING]
- **Effort**: 7.5 hours
- **Dependencies**: None
- **Research Inputs**: `specs/266_deploy_pending_vs_identical_dispatch_guard/reports/01_deploy_pending_vs_identical_dispatch_guard.md`
- **Artifacts**: plans/01_deploy-pending-guard-composition-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

**SOURCE STORE IS THE EDIT TARGET**: every file path below is relative to
`agent-system/extensions/core/` unless explicitly prefixed `.claude/`. Never hand-author under
`.claude/**` — it is a disposable deploy artifact regenerated from the source store (see
`.claude/rules/source-store-deploy-boundary.md`). `.claude/` paths appear in this plan only as
runtime targets that the deploy produces.

## Overview

Two individually-correct `/orchestrate` mechanisms — the postflight completion-deploy gate (exit
6) and the identical-dispatch convergence guard — compose into a trap: a task refused by the gate
is deploy-blocked, necessarily re-derives a byte-identical dispatch on the next cycle, and is
halted by the guard for "churn" that is actually the deterministic signature of its own
deploy-gated situation. The fix is structural rather than a weakening of either mechanism: wire
`reconcile-task-status.sh` — the tool that already produces the correct promotion, and which the
operator had to run by hand twice — into the Inter-Cycle Redeploy Checkpoint's own clean-success
path so a deploy-unblocked task converges without any second dispatch being derived at all, add a
narrow streak-freeze backstop to the guard for the paths where that reconcile cannot conclude, and
correct the "no manual action needed" message so it is true of the delivered behavior. Definition
of done: a deploy-pending task converges to `completed` within a single run once the checkpoint's
deploy lands; a genuinely churning task with no deploy-pending marker is still halted; the exit-6
refusal is unchanged; `scripts/tests/` passes with no test weakened or deleted.

### Research Integration

The research report is integrated in full and its recommendations are adopted with one deliberate
narrowing and one addition:

- **Adopted (primary fix)**: `reconcile-task-status.sh` is invoked exactly once per `/orchestrate`
  invocation, at entry, never per-cycle (`skills/skill-orchestrate/SKILL.md` Stage MT-3). Nothing
  re-runs it after the checkpoint's own mid-run deploy lands, which is the entire timing gap.
  Phase 2 closes it inside the checkpoint's already-serialized window.
- **Adopted (backstop)**: the guard's streak counter is frozen, never the guard suppressed, and
  the flag is read from the task's **own** `.return-meta.json` at hash time — never from the
  batch-wide `deploy_pending_any` — so a sibling's deploy-pending state can never mask this task's
  genuine churn (Phase 3).
- **Adopted (message)**: `orchestrate-cycle-postflight.sh`'s DEPLOY-PENDING notice is corrected to
  match the behavior actually shipped (Phase 4), with before/after text quoted in the summary per
  the dispatch's verification item 4.
- **Rejected, with rationale recorded (Risks & Mitigations)**: moving the deploy earlier, before
  the completion write is attempted. It does not fix this defect, and it reintroduces the exact
  `specs/.deploy-lock` race that the current design's Concurrency Posture deliberately avoids by
  firing the redeploy only at the two already-serialized sites.
- **Added by this plan**: the research's flagged side finding — nothing ever clears
  `deploy_pending: true` once `skill-base.sh` sets it — is promoted from "worth flagging" to
  **Phase 1**, the plan's foundation. Without it, the Phase 3 streak-freeze would be permanently
  armed for any task that was ever deploy-pending, silently retiring the guard for that task for
  the rest of its life. Clearing the marker is what keeps the backstop narrow.

### Prior Plan Reference

No prior plan. This is round 1 for task 266.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and no roadmap consultation was
performed.

## Goals & Non-Goals

**Goals**:
- A deploy-pending task converges to `completed` within the same `/orchestrate` run, in the very
  cycle whose checkpoint deploy lands, with **no second `implement` dispatch derived** — removing
  both the halt and the wasted agent round-trip.
- The identical-dispatch guard remains fully live for genuine non-convergence, including for a
  task that was deploy-pending earlier in its life and is no longer.
- `deploy_pending: true` is cleared at exactly one chokepoint when the completion write it was
  recording finally succeeds, so the marker cannot go stale.
- The DEPLOY-PENDING refusal message is true of the shipped behavior, with before/after text
  quoted in the implementation summary.
- Regression tests reproduce the composition defect and pin all four verification arms from the
  dispatch, added alongside (never in place of) the existing Group 11/27/28 coverage.

**Non-Goals**:
- Weakening, relaxing, or adding exemptions to the completion-deploy gate's exit-6 refusal. It is
  correct and is out of scope by explicit constraint.
- Weakening the identical-dispatch guard for the general case, including full suppression under a
  deploy-pending marker.
- Re-ordering the deploy to fire before the completion write is attempted (analyzed and rejected;
  a separate follow-up task if ever pursued).
- Any modification to tasks 260-264 or to anything under their task directories — they are the
  evidence record for this defect.
- Changing `reconcile-task-status.sh`'s own promotion logic, guards, or mtime gating. This plan
  changes only *when* it is called, not *what* it decides.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A new in-loop `reconcile-task-status.sh` call races a sibling task's in-flight dispatch | H | L | Place it strictly inside the checkpoint block's window, after the deploy's success is confirmed and before Move 2 issues any dispatch — the one point the Concurrency Posture already documents as having no dispatch in flight. Inherits the existing serialization; introduces no new lock. |
| Reconcile is called on a checkpoint path where the extension is not actually fresh (branch (a) deploy failed, branch (b) blocking findings) | M | M | Gate the call on the three clean-success branches only, by setting a dedicated variable inside each success branch rather than testing an outcome after the fact. Branches (a) and (b) must leave the variable untouched. |
| Streak-freeze implemented against batch-wide `deploy_pending_any` instead of the task's own marker, masking a sibling's genuine churn | H | M | Read the flag from `${task_dir}/.return-meta.json` for task `$t` at the exact point the hash is computed. Phase 5 pins this with a two-task fixture where only one task is deploy-pending. |
| The uncleared marker leaves the streak-freeze permanently armed for a once-deploy-pending task | H | H (today) | Phase 1 clears the marker at the single completion chokepoint, and Phase 5 asserts the guard halts a formerly-deploy-pending, now-cleared task on genuine repeat. |
| Clearing the marker inside `update-task-status.sh` perturbs an unrelated consumer of `.return-meta.json` | M | L | Clear only the two keys `deploy_pending` / `deploy_pending_reason`, only on a successful `postflight … implement` write, via an atomic `jq … > tmp && mv` that preserves every other key; failure to clear is a non-fatal warning, never a status-write failure. |
| Corrected message asserts a guarantee some branch does not deliver | M | M | Word the correction to the branch structure actually shipped: automatic on the clean-success paths, and pointing at the checkpoint's own named WARNING plus remedy on the failure paths. Phase 6 asserts the shipped string. |
| A test is weakened or deleted to make the change pass | H | L | Phase 8's gate diffs `scripts/tests/` for removed or loosened assertions; existing Group 11/27/28 cases are additive-only. Explicitly prohibited by the dispatch. |
| This task's own edits touch `agent-system/extensions/**`, so its own completion will hit the very gate under repair | M | H | Expected and desirable — it is a live end-to-end exercise. Phase 8 runs the deploy explicitly so the completion write is not refused, and the new reconcile path is observed in the wild. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 2, 3 |
| 5 | 5, 6, 7 | 4 |
| 6 | 8 | 5, 6, 7 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Clear `deploy_pending` at the completion chokepoint [COMPLETED]

**Goal**: Make the `deploy_pending` marker a transient record of an outstanding refusal rather
than a permanent scar, so every later consumer (the checkpoint's `deploy_pending_any` scan, and
Phase 3's streak-freeze) reads a live signal.

**Tasks**:
- [x] Read `scripts/skill-base.sh`'s `skill_postflight_update` marker-write block to capture the
      exact key names and `jq … > tmp && mv` idiom used to set the marker; mirror it for clearing. *(completed)*
- [x] In `scripts/update-task-status.sh`, on the `postflight … implement` path, after the
      completion status write succeeds (and only then), clear `deploy_pending` and
      `deploy_pending_reason` from the already-resolved `DEPLOY_CHECK_META_FILE`. *(completed)*
- [x] Reuse `resolve_return_meta_for_deploy_check`'s resolved path rather than re-deriving the
      task directory; if `DEPLOY_CHECK_META_FILE` is empty, skip silently (nothing to clear). *(completed)*
- [x] Use `jq 'del(.deploy_pending, .deploy_pending_reason)' … > tmp && mv`, preserving every
      other key; on any failure emit a `WARNING:` to stderr and continue — clearing must never
      turn a successful status write into a failure. *(completed)*
- [x] Add a comment block naming why this is the single chokepoint: both the ordinary
      `skill_postflight_update` path and `reconcile-task-status.sh`'s direct
      `update-task-status.sh postflight … implement` call funnel through it, so one site covers
      both and neither script needs its own copy. *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: this is hypothesized to be a single-site change in
`scripts/update-task-status.sh`, with no edit needed in `skill-base.sh` or
`reconcile-task-status.sh`. Confirm at implementation time by tracing both callers: verify that
`reconcile-task-status.sh`'s `implementing`/`partial` branches invoke
`update-task-status.sh postflight … implement` directly (they do, per the research report) and
that `skill_postflight_update` also terminates in that same script. If either caller bypasses it,
add the clear at that caller instead and record the divergence.

**Files to modify**:
- `scripts/update-task-status.sh` - clear the two marker keys after a successful implement-phase
  completion write

**Verification**:
- Fixture: a task dir whose `.return-meta.json` carries `deploy_pending: true` plus at least two
  unrelated keys; run `update-task-status.sh postflight <n> implement <sid>` on a state where the
  write will succeed; assert both marker keys are gone and every unrelated key is byte-identical.
- Negative: run the same command where the completion-deploy gate refuses with exit 6; assert the
  marker is still present (a refusal must not clear the record of itself).
- `bash scripts/tests/test-update-task-status.sh` (or the covering suite for this script) passes
  unchanged.

---

### Phase 2: Wire an automatic reconcile pass into the checkpoint's clean-success path [COMPLETED]

**Goal**: Make the checkpoint's own "convergence is deferred to the next cycle" promise real by
promoting every task it just unblocked in the same cycle, before that cycle's status refresh — so
the task is already terminal by the time dispatch derivation runs and no second `implement`
dispatch is ever built for it.

**Tasks**:
- [x] In `scripts/orchestrate-cycle-plan.sh`, initialize a cycle-local accumulator (e.g.
      `post_deploy_reconcile_json='[]'`) before the checkpoint block opens, so it is defined on
      every path including the ledger-skip and dry-run paths. *(completed)*
- [x] Set it to `$deploy_pending_tasks_json` inside **each of the three clean-success branches**
      only: (i) `post_findings` empty ("verify-deploy.sh clean"), (ii) branch (c) pre-existing
      findings with `new=0`, (iii) the branch-(c)-equivalent `filtered` path where every candidate
      new finding was flaky or unrelated. Leave it untouched on branch (a) (`deploy_exit` 1 or 2)
      and branch (b) (blocking findings). *(completed)*
- [x] After the checkpoint block closes and before the `── (a) Status refresh` loop, iterate the
      accumulator and run `bash "$SCRIPT_DIR/reconcile-task-status.sh" "$_t" "$session_id"` live
      (never `--dry-run`), capturing exit code and stderr per task. *(completed)*
- [x] Skip the whole loop when `dry_run` is true, matching the checkpoint's own posture — a
      dry run must remain non-mutating. *(completed)*
- [x] Emit one named stderr line per task on both outcomes, e.g.
      `[orchestrate] REDEPLOY CHECKPOINT: post-deploy reconcile for task #N — <promoted|no-op|refused>`,
      and record a structured entry in the multi-task state (a `post_deploy_reconcile_notices`
      array mirroring the existing `verify_deploy_baseline_notices` shape) so the outcome is
      visible without re-reading stderr. *(completed)*
- [x] Treat a non-zero reconcile exit as non-fatal: warn, record, and continue to the next task —
      a failed self-heal must never take down the batch loop. *(completed)*
- [x] Record the placement rationale in a comment: this window is the one point in the loop with
      no dispatch in flight, so the call inherits the existing serialization rather than
      introducing a new lock; and it must precede the status refresh so `current_statuses[$t]`
      picks up the promotion and `is_terminal_status()` excludes the task naturally, with no new
      triage-layer skip logic. *(completed)*
- [x] Note in the same comment that `deploy_pending_any` forces the ledger decision to `run`, so
      the ledger-skip path can never starve this reconcile for a deploy-pending task. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: hypothesized to be exactly three clean-success branches needing the
accumulator assignment, and one insertion point after the checkpoint block. Confirm at
implementation time by enumerating every branch inside the checkpoint that reaches
`mt_set … .deployed_critical_paths` — that assignment marks precisely the "deploy landed and is
usable" branches — and asserting the count is three. If a fourth such branch exists, cover it too
and record the correction.

**Files to modify**:
- `scripts/orchestrate-cycle-plan.sh` - accumulator initialization, three branch assignments, the
  post-checkpoint reconcile loop, and the placement-rationale comment

**Verification**:
- `bash -n scripts/orchestrate-cycle-plan.sh` clean.
- Manual trace with the Group 11 stub harness: a `deploy_pending` fixture on the clean path shows
  the reconcile line on stderr; a branch-(a) fixture (`deploy-headless.sh` exit 1) shows no
  reconcile line at all.
- Existing `bash scripts/tests/test-orchestrate-cycle-plan.sh` Group 11 passes unchanged
  (no existing case may regress).
- `--dry-run` invocation leaves `state.json` byte-identical (Group 6's no-mutation contract).

---

### Phase 3: Streak-freeze backstop in the identical-dispatch guard [COMPLETED]

**Goal**: For the residual paths where Phase 2's reconcile cannot conclude (deploy failed,
findings blocked, promotion refused by the phase-accounting backstop), stop charging a
deploy-gated re-derivation against the convergence guard — without disabling the guard.

**Tasks**:
- [x] In `scripts/orchestrate-cycle-plan.sh`'s Fix 2 hashing block, resolve task `$t`'s own task
      directory and read `.deploy_pending // false` from its `.return-meta.json`, using the same
      `lookup_project` + `task_lookup_dir` resolution the checkpoint's `deploy_pending_any` scan
      already uses. *(completed)*
- [x] When that flag is true and the hash matches the previous cycle's for the same phase, **do
      not increment** `identical_dispatch_streak[$t]`: leave it at its current persisted value
      (do not reset it to 1 either — a freeze, not a clear, so a pre-existing genuine streak is
      preserved across the deploy-gated interruption). *(completed)*
- [x] Still write `last_dispatch_hash[$t]` and `last_dispatch_phase[$t]` unchanged, so equality
      detection for the *next* cycle remains accurate. *(completed)*
- [x] Emit a distinct, named stderr notice when the freeze fires, e.g.
      `[orchestrate] IDENTICAL DISPATCH: task #N <phase> content matches the previous one, but the task is deploy-pending — streak frozen at <n>, not charged as churn.`
      It must be textually distinguishable from the existing streak notice. *(completed)*
- [x] Leave the `_idh_streak -ge 2` halt block itself completely unmodified — the freeze acts only
      on the counter's input, so the halt semantics are untouched for every non-deploy-pending
      task. *(completed)*
- [x] Leave the hash-degradation path (`sha256sum` unavailable, unreadable dispatch file)
      unmodified. *(completed)*
- [x] Add a comment recording the settled decision: freeze, not suppress; per-task marker, never
      `deploy_pending_any`; and that Phase 1's marker clearing is what keeps the freeze from
      arming permanently. *(completed)*

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: full

**Files to modify**:
- `scripts/orchestrate-cycle-plan.sh` - per-task marker read and the conditional streak increment
  inside the Fix 2 hashing block

**Verification**:
- `bash -n scripts/orchestrate-cycle-plan.sh` clean.
- Existing Group 27 (hashing/streak accounting) and Group 28 (halt) cases pass unchanged — neither
  fixture carries a `deploy_pending` marker, so neither may change behavior.
- Trace assertion: with a `deploy_pending: true` fixture, two identical cycles leave
  `identical_dispatch_streak[$t]` unchanged and issue no halt.

---

### Phase 4: Correct the DEPLOY-PENDING refusal message [COMPLETED]

**Goal**: Make the emitted message true of the behavior shipped by Phases 2-3, replacing an
assurance that did not hold in either observed incident.

**Tasks**:
- [x] Quote the current text verbatim from `scripts/orchestrate-cycle-postflight.sh`'s
      `postflight_rc -eq 6` branch into the phase's working notes, for the summary's
      before/after requirement. *(completed: before text captured — see summary)*
- [x] Replace the trailing clause so it describes the delivered two-outcome structure: the next
      cycle's checkpoint deploys **and then reconciles this task's status automatically**, with no
      manual action needed unless that deploy or its verify fails — in which case the checkpoint
      emits its own named WARNING and states the remedy. *(completed)*
- [x] Keep the leading `DEPLOY-PENDING: task ${task_number}` prefix byte-identical — two existing
      assertions in `scripts/tests/test-orchestrate-cycle-postflight.sh` match on that prefix and
      must keep passing untouched. *(completed: 127 passed, 0 failed)*
- [x] Verify by `grep -rn "no manual action needed"` across the source store that the string has
      exactly one occurrence before the edit and that the replacement leaves no stale copy
      elsewhere (including in context/ prose that quotes it). *(completed: exactly one occurrence, in the edited line itself)*

**Timing**: 0.5 hours

**Depends on**: 2, 3

**Verification Tier**: local

**Files to modify**:
- `scripts/orchestrate-cycle-postflight.sh` - the `postflight_rc -eq 6` DEPLOY-PENDING notice

**Verification**:
- `bash -n scripts/orchestrate-cycle-postflight.sh` clean.
- `grep -rn "no manual action needed" agent-system/extensions/core` returns only intended
  occurrences.
- Existing `scripts/tests/test-orchestrate-cycle-postflight.sh` prefix assertions still pass.
- Read the new sentence against the Phase 2 branch table and confirm every claim it makes maps to
  a branch that actually delivers it.

---

### Phase 5: Reproduction and regression tests in test-orchestrate-cycle-plan.sh [COMPLETED]

**Goal**: Pin verification arms 1-3 from the dispatch with a new, additive test group that
reproduces the composition defect and proves it resolved, while proving the guard still fires for
genuine churn.

**Tasks**:
- [x] Add a new group (next free number after Group 28) to
      `scripts/tests/test-orchestrate-cycle-plan.sh`, reusing Group 11's
      `write_g11_deploy_headless_stub` / `write_g11_verify_stub` helpers and Group 27's
      real-script restoration precaution. *(completed: Group 29)*
- [x] **Arm A (the defect, resolved)**: a task at `implementing` with a complete plan, a summary
      artifact, a handoff reporting `implemented`, and `deploy_pending: true`. Stub the deploy
      clean. Assert within a single run: the post-deploy reconcile line fires, the task's
      `state.json` status becomes `completed`, and **zero** `implement` dispatch rows are emitted
      for it. *(completed; confirmed to genuinely fail pre-fix — see Testing & Validation)*
- [x] **Arm B (guard still live)**: a task with a complete plan and **no** `deploy_pending`
      marker that re-derives identical dispatches across two cycles is still halted — a blocked[]
      row naming the guard, zero dispatch rows, and the `IDENTICAL DISPATCH HALT` stderr notice. *(completed)*
- [x] **Arm C (streak freeze, per-task scope)**: a two-task fixture where only one carries
      `deploy_pending: true`; drive two identical cycles on a path where the reconcile cannot
      promote (e.g. no summary artifact). Assert the deploy-pending task is not halted and its
      streak is unchanged, while the sibling without the marker still halts normally. *(completed; confirmed to genuinely fail pre-fix)*
- [x] **Arm D (marker clearing closes the freeze)**: after the Arm A promotion, assert
      `deploy_pending` is absent from that task's `.return-meta.json`, then drive a genuine
      identical-dispatch repeat and assert the guard now halts it — proving the freeze does not
      persist past the episode. *(completed: deviation — a genuine implement-phase promotion is
      terminal (`completed`), so the Arm A task cannot literally be re-dispatched; Arm D instead
      isolates the SAME invariant on a fresh candidate carrying no marker at all, which is the
      exact state Phase 1's clearing leaves behind. This arm passes both before and after the fix
      by construction — pre-fix code never read the marker either, so "absent marker -> ordinary
      halt" was never broken. Recorded honestly rather than staged to force a misleading red/green
      delta; Arms A and C are the ones that actually pin the defect.)*
- [x] **Arm E (failure path, no spurious reconcile)**: stub `deploy-headless.sh` exit 1 (branch
      (a)) with a `deploy_pending` task present; assert no reconcile line fires and the task's
      status is unchanged. *(completed)*
- [x] Reset lock dirs, multi-state files, and the Group 11 call-count markers between arms, per
      the established per-group hygiene in this file. *(completed)*
- [x] Add no assertion that loosens or replaces an existing Group 11/27/28 case. *(completed: 300 passed including all pre-existing groups, 0 failed)*

**Timing**: 1.75 hours

**Depends on**: 4

**Verification Tier**: full

**Scope Hypothesis**: five arms (A-E) are hypothesized sufficient to cover dispatch verification
items 1-3 plus the two scope risks named in Risks & Mitigations. Confirm at implementation time by
mapping each dispatch verification item and each Risks row marked H-impact to at least one arm;
add an arm for any left uncovered, and record the mapping in the summary.

**Files to modify**:
- `scripts/tests/test-orchestrate-cycle-plan.sh` - new additive test group

**Verification**:
- `bash scripts/tests/test-orchestrate-cycle-plan.sh` passes with the new group included and
  every pre-existing group still passing.
- Confirm the new arms genuinely fail against the pre-fix code: stash the Phase 2/3 edits, re-run,
  and observe Arms A/C/D fail; restore and observe them pass. Record this in the summary — an arm
  that passes both before and after proves nothing.

---

### Phase 6: Postflight test coverage for the corrected message and marker clearing [COMPLETED]

**Goal**: Pin dispatch verification items 3 and 4 — that the exit-6 refusal still fires when the
extension is genuinely stale, and that the emitted text is the corrected one.

**Tasks**:
- [x] In `scripts/tests/test-orchestrate-cycle-postflight.sh`, extend the existing DEPLOY-PENDING
      coverage with an assertion on the corrected trailing clause (a distinctive substring of the
      new wording), leaving both existing prefix assertions untouched. *(completed)*
- [x] Add a case asserting the exit-6 refusal still occurs for a genuinely stale extension: no
      `state.json` completion write, `deploy_pending: true` written to `.return-meta.json`, and
      the task left at its in-flight status. *(completed: deviation — already covered by the
      pre-existing "Characterization: cycle_modified_files accumulates across a real exit-6
      deploy-pending postflight refusal" case, which exercises a genuinely stale extension end to
      end (state.json unchanged, deploy_pending:true recorded). No new case added; verified this
      pre-existing coverage still passes.)*
- [x] Add the Phase 1 marker-clearing assertions (positive: cleared on a successful completion
      write with unrelated keys preserved; negative: preserved on an exit-6 refusal) to whichever
      suite covers `update-task-status.sh`; if no such suite exists, add them here and say so in
      the summary. *(completed in Phase 1: added as Cases 9-10 in
      `scripts/tests/test-postflight-deploy-gate.sh`, the suite whose own header already declares
      it "the fixture-driven regression suite for ... update-task-status.sh's PHASE 0.5 block",
      rather than `test-update-task-status.sh` — a better-fitting home since it already carries
      the exact source_dir/source_git_head freshness fixture machinery these assertions need.)*

**Timing**: 0.75 hours

**Depends on**: 4

**Verification Tier**: full

**Files to modify**:
- `scripts/tests/test-orchestrate-cycle-postflight.sh` - corrected-message assertion, stale-gate
  refusal case
- `scripts/tests/test-update-task-status.sh` (if present) - marker-clearing assertions

**Verification**:
- `bash scripts/tests/test-orchestrate-cycle-postflight.sh` passes, including both pre-existing
  DEPLOY-PENDING assertions.
- The marker-clearing suite passes.

---

### Phase 7: Correct the "D6 — CLOSED" documentation claim [NOT STARTED]

**Goal**: Stop `batch-orchestration-guardrails.md` asserting a convergence guarantee the composed
system did not provide, and document the two mechanisms' interaction in one place.

**Tasks**:
- [ ] In `context/patterns/batch-orchestration-guardrails.md`'s
      `**Residual — the /orchestrate path (D6) — CLOSED**` subsection, record that the original
      closure did not account for the identical-dispatch guard, and describe the composition
      defect and its resolution.
- [ ] Document the post-deploy reconcile pass: where it fires (the three clean-success branches),
      where it deliberately does not (branches (a) and (b)), and why the placement inherits the
      existing serialization.
- [ ] Document the streak-freeze backstop and the settled freeze-vs-suppress decision, including
      the per-task-marker scoping rule.
- [ ] Document the marker's lifecycle end-to-end: set by `skill-base.sh` on exit 6, cleared at the
      completion chokepoint, and why an uncleared marker would have retired the guard for that
      task.
- [ ] Add a cross-reference from the `### The Inter-Cycle Redeploy Checkpoint` section to the
      reconcile pass, so a reader arriving at either section finds the other.
- [ ] Reference scripts and functions by name, never by line number.
- [ ] Cite durable anchors only — no task-number references (this file lives outside `specs/**`).

**Timing**: 0.5 hours

**Depends on**: 4

**Verification Tier**: prose

**Files to modify**:
- `context/patterns/batch-orchestration-guardrails.md` - D6 subsection correction, checkpoint
  cross-reference

**Verification**:
- Diff read-through confirms every changed hunk is prose, with no code or executable content
  touched.
- `bash .claude/scripts/check-task-references.sh` (or the repo's task-reference lint) reports no
  new occurrences.
- Every script/function named in the new prose exists at that name in the source store.

---

### Phase 8: Full gate, deploy, and end-to-end observation [NOT STARTED]

**Goal**: Run the complete gate set, deploy the source store, and observe this task's own
completion exercising the repaired path.

**Tasks**:
- [ ] Run the full `scripts/tests/` suite; every test passes.
- [ ] Diff `scripts/tests/` against the pre-task baseline and confirm no assertion was removed,
      loosened, or skipped — additive changes only. Record the diff summary.
- [ ] Run `bash .claude/scripts/verify-deploy.sh` at full depth (no `--skip-slow`) and confirm no
      new findings relative to the pre-task baseline.
- [ ] Run `bash .claude/scripts/deploy-headless.sh` so the deployed `.claude/` mirror matches the
      source store — this task's own `modified_files` overlap `agent-system/extensions/**`, so
      without it this task's own completion write will be refused by the very gate under repair.
- [ ] Re-run `verify-deploy.sh` post-deploy and confirm clean.
- [ ] Assemble the implementation summary's before/after message quotation (dispatch verification
      item 4) and the pre-fix/post-fix test-failure evidence from Phase 5.

**Timing**: 0.75 hours

**Depends on**: 5, 6, 7

**Verification Tier**: full

**Files to modify**:
- None (verification and deploy only)

**Verification**:
- Full `scripts/tests/` suite green.
- `verify-deploy.sh` clean post-deploy.
- Test-suite diff shows additions only.
- Summary contains the verbatim before and after message text.

---

## Testing & Validation

- [ ] **Dispatch item 1**: a task with a complete plan and a `deploy_pending` marker is not halted
      by the identical-dispatch guard and converges to `completed` within a single run once the
      checkpoint's deploy lands (Phase 5 Arm A).
- [ ] **Dispatch item 2**: a task with a complete plan and no `deploy_pending` marker that
      genuinely re-derives an identical dispatch twice is still halted (Phase 5 Arms B and D).
- [ ] **Dispatch item 3**: the completion-deploy gate still refuses with exit 6 when the extension
      is genuinely stale and no deploy has run (Phase 6).
- [ ] **Dispatch item 4**: the refusal message is true of the resulting behavior, with before and
      after text quoted verbatim in the summary (Phases 4, 6, 8).
- [ ] **Dispatch item 5**: `scripts/tests/` passes, including `test-orchestrate-cycle-postflight.sh`
      and `test-orchestrate-cycle-plan.sh`, with no test weakened or deleted (Phase 8).
- [ ] Pre-fix failure evidence recorded for every new arm that claims to reproduce the defect.
- [ ] `--dry-run` remains fully non-mutating across the new reconcile path.
- [ ] No file under `.claude/**` was hand-authored; every edit landed in the source store and
      reached `.claude/` only via the deploy.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/update-task-status.sh` (modified) - marker clearing
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (modified) - post-deploy
  reconcile pass and the streak-freeze backstop
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (modified) - corrected
  DEPLOY-PENDING message
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` (modified) - new
  additive test group
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` (modified) -
  corrected-message and stale-gate assertions
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` (modified) -
  D6 correction and checkpoint cross-reference
- `specs/266_deploy_pending_vs_identical_dispatch_guard/summaries/01_*-summary.md` (new) -
  execution summary carrying the before/after message text and the pre-fix failure evidence
- Redeployed `.claude/` mirror (generated, not hand-authored)

## Rollback/Contingency

Each phase commits on its own verified-green sub-steps, so the last green commit is always the
rollback target: `git revert` the offending phase's commits, which restores the prior behavior
without disturbing earlier phases. The change is additive by construction — Phase 3 alters only
the streak counter's input and Phase 2 only adds a call after an already-serialized block — so
reverting either independently leaves the other functional, and reverting both restores exactly
today's behavior.

If a working-tree rollback is needed before those commits exist, take a durable, non-reverting
checkpoint first with `bash .claude/scripts/git-snapshot.sh 266 --no-revert`; only a genuine
whole-tree rollback uses the default reverting mode, and then per
`context/contracts/recovery.md`'s rollback rung, including its `--allow-out-of-scope` override
when the dirty tree extends past the task's declared `file_scope`.

If the deploy in Phase 8 fails or `verify-deploy.sh` reports new findings, stop: do not force the
completion write. Fix the deploy, re-run the gate, and only then complete — the completion-deploy
gate refusing at that point is the system working correctly, which is precisely what this task
must not weaken.
