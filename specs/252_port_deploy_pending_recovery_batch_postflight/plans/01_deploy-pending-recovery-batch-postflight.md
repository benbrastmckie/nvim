# Implementation Plan: Task #252

- **Task**: 252 - Port the deploy-pending (exit 6) recovery into the batch postflight, and fix `cycle_modified_files` accumulation on a refused postflight
- **Status**: [IMPLEMENTING]
- **Effort**: 10.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/252_port_deploy_pending_recovery_batch_postflight/reports/01_deploy-pending-recovery-batch-postflight.md
- **Artifacts**: plans/01_deploy-pending-recovery-batch-postflight.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

**SOURCE STORE IS THE EDIT TARGET** for every file path named in this plan:
`agent-system/extensions/core/` — never `.claude/**`. Paths below are written relative to that
root unless stated otherwise. Per `.claude/rules/source-store-deploy-boundary.md`, a hand-edit
under `.claude/**` is silently wiped by the next regeneration.

## Overview

Close the loop that prevents any source-store-editing task from reaching `completed` under the
four-move batch engine. The implementation does **not** port `command-gate-out.sh`'s exit-6
`deploy-headless.sh` trigger into `orchestrate-cycle-postflight.sh` as a third automated
deploy-trigger site. Instead it (a) makes the refusal *honest* at the postflight layer by
capturing `skill_postflight_update`'s return code that is currently discarded, (b) guarantees
`cycle_modified_files` accumulates across a refused write, and (c) re-arms the already-sanctioned,
already-serialized Inter-Cycle Redeploy Checkpoint in `orchestrate-cycle-plan.sh` by widening its
trigger predicate so `deploy_pending` reaches the deploy body independently of the narrow
`orchestrator-critical-paths.json` allowlist match. Part 3's replay-path documentation is fully
independent and lands first, in parallel.

### Research Integration

Four findings from the research report drive the phase structure and are treated as load-bearing:

1. **The precise defect location for Part 1 is a discarded return code**, not a missing
   redeploy. `orchestrate-cycle-postflight.sh`'s `implemented)` arm (verified at lines 759-789)
   calls `skill_postflight_update ...` with no `|| rc=$?`. `skill_postflight_update` in
   `scripts/skill-base.sh` **already** captures `update-task-status.sh`'s exit 6, **already**
   annotates the task's `.return-meta.json` with `deploy_pending: true` /
   `deploy_pending_reason`, and **already** returns 6 verbatim. The annotation machinery exists
   and fires correctly; it simply has no caller inside the batch loop that reads it.

2. **`deploy_pending_any` is already computed and already wired** in
   `orchestrate-cycle-plan.sh`'s Inter-Cycle Redeploy Checkpoint (verified at ~lines 763-780): it
   loops every batch task's `.return-meta.json`, and on a hit forces `deploy_ledger_decide`'s
   decision to `run`. But it sits **inside** the `if [ "$matched_count" -gt 0 ]` branch — so it is
   only consulted after the narrow `orchestrator-critical-paths.json` allowlist has already
   matched. A `meta` task touching some other file under `agent-system/extensions/**` never
   reaches it. This is the single highest-value scoped change in the whole task.

3. **Part 2's accumulation block is, on static reading, already structurally ungated.** Verified
   directly: `orchestrate-cycle-postflight.sh` runs `set -uo pipefail` with **no `set -e`**, and
   the WORK (j) accumulation loop (lines ~1169-1176) is gated only by `[ -z "$loop_guard_file" ]`
   and `is_live` — not by `dispatch_status`, `verdict`, or the discarded rc. The dispatch's
   "the refusal aborts before" framing is therefore a **plausible-but-unverified hypothesis about
   the mechanism**, not an established fact, even though the *symptom* (`cycle_modified_files`
   was `[]`) is confirmed. Phase 1 is written as characterization-first for exactly this reason.

4. **The codebase already documents this exact residual and prescribes this exact fix.**
   `context/patterns/batch-orchestration-guardrails.md` (D6 residual, ~line 889) and
   `context/patterns/regeneration-is-manual-only.md`'s explicit non-exception paragraph (~lines
   129-142) both name widening Stage MT-3 step 7's predicate as "the proper fix", and both warn
   that a redeploy fired from inside per-task postflight "would race the fail-open
   `specs/.deploy-lock` mutex". The plan follows that pre-existing guidance rather than rebutting
   it.

### Concurrency Posture — The Argued Conclusion Part 1 Requires

The dispatch requires this decision to be argued, not silently omitted. **Decision: defer the
redeploy to the Inter-Cycle Redeploy Checkpoint boundary; add NO new automated deploy-trigger
site to `orchestrate-cycle-postflight.sh`.** The dispatch names "defer it to the inter-cycle
checkpoint boundary where no dispatch is in flight" as one of its acceptable options and states
that if so, "Part 2 alone may be the correct whole fix" — this plan concludes Part 2 plus a
predicate widening is the correct whole fix. The argument:

- **The gate-out trigger's own justification does not transfer.** `command-gate-out.sh` licenses
  its automated trigger on the grounds that it is "a point with NO concurrency — the true
  single-task `/implement` completion path". `SKILL.md`'s Move 2 issues every `dispatch[]` row's
  Agent call **in one message** (genuinely simultaneous). Move 3's postflight loop is sequential
  within a cycle, so two postflights never race each other — but a postflight-fired redeploy in
  cycle N could land while a sibling task's Move 2 agent session is mid-flight in cycle N+1,
  since an `/orchestrate` run routinely has several tasks each spanning several cycles. The
  premise that licenses the gate-out trigger is simply false at this call site.
- **A third trigger site would need a new lock the codebase deliberately avoids.** The existing
  `specs/.deploy-lock` mutex is documented as **fail-open**; both existing sanctioned sites are
  placed where they are precisely so they never have to rely on it. Introducing a per-cycle lock
  scoped to "after all postflights, before the next dispatch" would reinvent — with a second,
  drift-prone implementation — the boundary the Inter-Cycle Checkpoint already *is*.
- **The checkpoint boundary is already the no-dispatch-in-flight point.** It runs in
  `orchestrate-cycle-plan.sh` between cycles, already consumes `cycle_modified_files`, already
  routes through the durable `deploy_ledger_decide` ledger and the `deployed_critical_paths`
  idempotence guard, and already honors `deploy_pending`. Everything needed exists except the
  reach of one predicate.
- **Consequence for the carve-out count**: `regeneration-is-manual-only.md`'s "exactly two"
  sanctioned automated `deploy-headless.sh` trigger sites for this gate **does not change** —
  this plan adds no site. Phase 5 must therefore *preserve* the count while correcting the
  paragraph that says widening the predicate is "not attempted here". This is an explicit,
  deliberate non-change, recorded so a later pass does not read the unchanged count as an
  oversight.

**Cost of this choice, stated plainly**: convergence is deferred by one cycle rather than
happening within the same postflight. The refused task stays non-completed until the next cycle's
checkpoint redeploys and the cycle after that re-runs postflight successfully. That is strictly
better than an unserialized redeploy under a live batch, which the dispatch itself calls "a worse
defect than the one being fixed".

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the dispatch context; no roadmap consultation performed.

## Goals & Non-Goals

**Goals**:
- A task whose `modified_files` overlap `agent-system/extensions/**` reaches `completed` through
  the four-move loop with no manual deploy and no manual reconcile, demonstrated end to end.
- `cycle_modified_files` is provably non-empty after a postflight refused by the
  completion-deploy gate, within a single `/orchestrate` invocation.
- The Inter-Cycle Redeploy Checkpoint demonstrably fires on the cycle following a refusal, for a
  task whose modified files fall **outside** `orchestrator-critical-paths.json`'s curated list.
- `skill_postflight_update`'s exit 6 is no longer silently discarded: the verdict and the commit
  message stop claiming a completion that did not happen.
- The concurrency posture above is recorded in the script and in
  `context/patterns/batch-orchestration-guardrails.md`; the D6 residual is retired.
- The `reconcile-task-status.sh` replay path after an unwind is documented in two places plus a
  printed hint.

**Non-Goals**:
- Adding any new automated `deploy-headless.sh` trigger site (argued against above).
- Weakening or altering the completion-deploy gate in `update-task-status.sh`. The gate is
  correct; the missing piece is the recovery.
- Any behavioral change to the handoff-identity staleness gate. It is working as designed; Part 3
  is documentation plus at most a printed hint.
- Any edit to `orchestrate-cycle-plan.sh` beyond what re-arming the checkpoint strictly requires.
  Its decomposition is another open task's declared scope.
- A parallel test suite. Both affected suites are extended in place.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Phase 1's characterization test passes against unmodified code, making "fix accumulation" a no-op relative to the dispatch's literal framing | M | H | Planned for: Phase 1 is explicitly characterization-first. A green result is valuable negative evidence, is retained as permanent coverage (Acceptance #4), and redirects effort to Phase 3, which the evidence says is the piece actually missing. Record the finding in the phase notes rather than porting a redundant fix. |
| The real mechanism is cross-invocation loss (each fresh `/orchestrate` starts a new multi-state file with `cycle_modified_files: []`), not an intra-invocation gap | H | M | Phase 1 scopes its assertion to a **single invocation**. If the test proves intra-invocation accumulation is sound, Phase 1's second half pivots to the cross-invocation question; the durable `deploy_pending` marker on `.return-meta.json` (which survives invocations) is the already-existing mitigation and is what Phase 3's widening consumes. |
| Widening the checkpoint predicate too broadly raises redeploy frequency and cost | M | M | Route the widened branch **through** `deploy_ledger_decide` and the `deployed_critical_paths` idempotence guard, never around them. Both exist specifically to bound this. Phase 3 verification asserts the ledger is still consulted on the widened path. |
| Predicate widening changes the meaning of a heavily cross-referenced mechanism (the guardrails doc's own stated reason for deferring it) | H | M | Phase 5 updates every cross-reference in the same round: the D6 paragraph, the `regeneration-is-manual-only.md` non-exception paragraph, and the in-script comment. Phase 5 depends on Phase 3 so the docs describe shipped behavior, not intent. |
| Capturing the rc flips `verdict` from `ok` to a non-`ok` value and changes downstream cycle routing in an unintended way | H | M | Phase 2 changes `verdict`/commit-message bookkeeping only for the refused case, reusing the existing `defer` vocabulary (already the `implemented_gate_passed=false` value) rather than inventing one. Phase 2 verification runs the full `test-orchestrate-cycle-postflight.sh` suite (1509 lines) to catch routing regressions. |
| Editing two regions of `orchestrate-cycle-postflight.sh` in parallel phases produces a conflict | L | M | Phases 1 and 2 both touch that file and are deliberately serialized (2 depends on 1) rather than run in the same wave. |
| Acceptance #1's end-to-end demonstration is hard to stage without a real multi-cycle run | M | H | Phase 4 is a dedicated phase with its own budget, staging a fixture task whose `modified_files` lie under `agent-system/extensions/**` but outside the critical-path allowlist — the exact general case the blast-radius framing names. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 6 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |
| 4 | 4, 5 | 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Characterize and Guarantee `cycle_modified_files` Accumulation Across a Refused Postflight [COMPLETED]

**Goal**: Establish empirically — not by assumption — whether the WORK (j) accumulation block
survives an exit-6 refusal within a single invocation, then guarantee it does. This is Part 2,
the independently valuable, lower-risk half that introduces no new deploy-trigger site.

**Tasks**:
- [x] Write a characterization case in `scripts/tests/test-orchestrate-cycle-postflight.sh` that
      drives a fixture task through `implemented)` with `update-task-status.sh` forced into its
      exit-6 branch (`modified_files` overlapping `agent-system/extensions/**` plus a stale
      deployed tree), then asserts the multi-state file's `cycle_modified_files` is non-empty
      afterward. Follow the suite's existing fixture and `pass()`/`fail()`/`info()` conventions.
      *(completed: real exit-6 refusal via a stale-extension fixture, modelled on
      test-postflight-deploy-gate.sh's Case 1)*
- [x] Run it against **unmodified** code and record the result verbatim in the phase notes. This
      is the decision point: green means the block is already ungated (confirming the static
      reading) and the dispatch's mechanism hypothesis is wrong; red means a real intra-invocation
      gap exists. *(completed: GREEN against unmodified code -- see phase-1-progress.json
      phase_notes)*
- [ ] If red: fix the gap so accumulation runs regardless of the status-write outcome, **without**
      disturbing the block's ordering. The existing comment explains it accumulates there rather
      than re-reading later because the scoped commit may already have removed
      `.return-meta.json`; the fix must preserve that ordering constraint, not hoist the read.
      *(deviation: skipped — characterization came back GREEN, not red; no gap existed)*
- [x] If green: do **not** port a redundant fix. Instead add a second assertion that the fixture's
      `.return-meta.json` carries `deploy_pending: true` after the refusal (the durable marker
      Phase 3 consumes), and note in the phase record that Part 2's literal framing was already
      satisfied structurally. *(completed)*
- [x] Add a guard comment at the accumulation block naming this test as its regression anchor, so
      a later refactor cannot silently re-gate it. *(completed)*
- [x] Commit green on its own, independent of every later phase. *(completed)*

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: full

**Scope Hypothesis**: The research's static read asserts the WORK (j) block at
`scripts/orchestrate-cycle-postflight.sh` lines ~1169-1176 is gated only by
`[ -z "$loop_guard_file" ]` and `is_live`, with no `set -e` in effect (`set -uo pipefail` at line
132). Confirm both by direct inspection at implementation time before choosing the red or green
branch above — the entire phase shape turns on it, and line numbers may have moved.

**Files to modify**:
- `scripts/tests/test-orchestrate-cycle-postflight.sh` - new exit-6 refusal case asserting
  non-empty `cycle_modified_files` and the `deploy_pending` marker; extend, never duplicate
- `scripts/orchestrate-cycle-postflight.sh` - WORK (j) block: guard comment always; an ordering-
  preserving un-gating only if the characterization test comes back red

**Verification**:
- `bash scripts/tests/test-orchestrate-cycle-postflight.sh` green, including the new case
- The new case fails if the accumulation block is artificially re-gated (verify by temporarily
  wrapping it in a false condition, confirming red, then reverting)
- `bash -n scripts/orchestrate-cycle-postflight.sh` clean
- Phase notes record the unmodified-code result verbatim

---

### Phase 2: Stop Discarding `skill_postflight_update`'s Return Code in the `implemented)` Arm [COMPLETED]

**Goal**: Make a refused completion honest at the postflight layer. Today `implemented_gate_passed`
is set `true` by the separate phase-accounting gate *before* the status write is even attempted,
so an exit-6 refusal leaves `verdict="ok"` and a commit message reading "complete implementation"
for a task that is still `implementing`. No new deploy trigger is added here — this is visibility
and correct bookkeeping only.

**Tasks**:
- [x] In the `implemented)` case arm (~lines 759-789), capture the return code:
      `skill_postflight_update ... || postflight_rc=$?`, initialized to 0. *(completed)*
- [x] On `postflight_rc -eq 6`, set a distinct flag (e.g. `deploy_pending_refusal=true`) and emit a
      clearly-prefixed stderr notice naming the task, the refusal, and the fact that convergence is
      deferred to the next cycle's Inter-Cycle Redeploy Checkpoint. The notice is the operator-
      facing half of the deferred-convergence posture. *(completed: "DEPLOY-PENDING: task N's
      postflight completion write was refused..." notice)*
- [x] Route the flag into the `verdict` computation (~line 963) so a deploy-pending refusal yields
      `defer` rather than `ok`. Reuse the existing `defer` vocabulary — "in-flight, retry the same
      phase next cycle" is exactly correct here. Do not invent a new verdict value. *(completed)*
- [x] Route the flag into the commit-message selection (~lines 1101-1109) so the refused case no
      longer claims `complete implementation`; reuse the existing
      `orchestration paused (cycle N)` message. *(completed)*
- [x] Leave `skill_gate_completion_claim`'s own semantics untouched — it answers a different
      question (phase accounting) and must keep answering it independently. *(completed: untouched)*
- [x] Preserve the single-retry posture by **not** adding a retry here at all: there is no
      redeploy at this site, so there is nothing to re-attempt. Record that in an in-line comment
      pointing at `command-gate-out.sh:211` for the contrast. *(completed)*
- [x] Extend `scripts/tests/test-orchestrate-cycle-postflight.sh` with cases asserting
      `verdict=defer` and the paused commit message on a refused implemented postflight, and
      asserting the unrefused path still yields `verdict=ok` with the completion message.
      *(completed: candidates #710 (refused) and #711 (unrefused contrast))*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts three edit points in one file — the `implemented)` arm
(~759-789), the `verdict` case (~963), and the commit-message case (~1101-1109). Confirm all
three by grep at implementation time (`grep -n 'implemented_gate_passed' \
scripts/orchestrate-cycle-postflight.sh`) before editing; if a fourth consumer of
`implemented_gate_passed` exists, decide explicitly whether it also needs the refusal signal
rather than leaving it unexamined.

**Files to modify**:
- `scripts/orchestrate-cycle-postflight.sh` - rc capture in the `implemented)` arm; refusal flag
  threaded into `verdict` and the commit message; explanatory comment on the no-retry posture
- `scripts/tests/test-orchestrate-cycle-postflight.sh` - verdict and commit-message cases for
  both the refused and unrefused implemented paths

**Verification**:
- `bash scripts/tests/test-orchestrate-cycle-postflight.sh` fully green (all 1509+ lines of
  existing coverage, not just the new cases) — this suite is the routing-regression net
- `bash scripts/tests/test-postflight-deploy-gate.sh` still green (unchanged behavior expected)
- `bash -n scripts/orchestrate-cycle-postflight.sh` clean
- Manual read-back: a refused implemented postflight produces `verdict=defer`, the paused commit
  message, and the stderr deferred-convergence notice

---

### Phase 3: Re-Arm the Inter-Cycle Redeploy Checkpoint — Widen Its Trigger Predicate [COMPLETED]

**Goal**: The core of Part 1 under the deferred-convergence posture. Make `deploy_pending` reach
the checkpoint's deploy body independently of the narrow `orchestrator-critical-paths.json`
allowlist match, so a `meta` task touching any file under `agent-system/extensions/**` converges
without operator intervention.

**Tasks**:
- [x] Hoist the `deploy_pending_any` computation (~lines 763-780) **out** of the
      `if [ "$matched_count" -gt 0 ]` branch so it is computed before the branch decision. It
      already reads each batch task's `.return-meta.json` for `deploy_pending: true`; only its
      placement is wrong. *(completed)*
- [x] Widen the branch condition so the deploy body is reachable when
      `matched_count -gt 0` **OR** `deploy_pending_any = true`. Keep `dry_run != true` as-is.
      *(completed)*
- [x] Adjust the checkpoint's announcement so the widened path names its own reason
      (deploy-pending marker on task N) rather than printing a misleading
      "touched 0 orchestrator-critical path(s)" line. *(completed)*
- [x] Route the widened path **through** `deploy_ledger_decide` and the `deployed_critical_paths`
      idempotence guard — never around them. `deploy_pending_any` already forces the ledger
      decision to `run`; that interaction must be preserved exactly, not bypassed. *(completed:
      unchanged, structurally shared code path)*
- [x] Reuse `deploy_findings_snapshot` / `deploy_baseline_new_findings` from
      `scripts/lib/deploy-baseline-lib.sh` exactly as the existing body already does. Add **no**
      third copy of the (a)/(b)/(c) failure contract — the library exists specifically to stop
      these two call sites from drifting, and a third copy reintroduces that drift. *(completed:
      untouched; single home confirmed via grep)*
- [x] Preserve the unconditional `mt_set '.cycle_modified_files = []'` reset (~line 959) and its
      wrapper structure — it deliberately runs whether or not the inner body fired. *(completed:
      untouched)*
- [x] Add an in-script comment recording the concurrency posture: why the redeploy lives here and
      not in per-task postflight, naming the fail-open `specs/.deploy-lock` race and Move 2's
      one-message parallel dispatch as the reasons. *(completed)*
- [x] Extend `scripts/tests/test-postflight-deploy-gate.sh` with the refusal-then-recovery path:
      a task whose modified files are under `agent-system/extensions/**` but **outside** the
      critical-path allowlist still trips the checkpoint via `deploy_pending_any`. *(completed:
      Case 8 (stale-then-fresh recovery sequence on update-task-status.sh's own gate) added to
      test-postflight-deploy-gate.sh; the checkpoint's own widened-predicate mechanics (which live
      in orchestrate-cycle-plan.sh, not update-task-status.sh) are covered by test-
      orchestrate-cycle-plan.sh's Group 11 case (s) instead — the correct suite for that script,
      per Acceptance #4's naming of test-orchestrate-cycle-postflight.sh and
      test-postflight-deploy-gate.sh together with this phase's own Files-to-modify list)*
- [x] Confirm no edit to `orchestrate-cycle-plan.sh` outside the checkpoint block. If any change
      appears to require touching its decomposition, stop and record it rather than proceeding —
      that is another task's declared scope. *(completed: diff confined to lines ~756-819, inside
      the checkpoint block spanning ~695-961; verified via `git diff --stat` and reading the diff)*

**Timing**: 2.5 hours

**Depends on**: 1, 2

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts the checkpoint spans `scripts/orchestrate-cycle-plan.sh`
~695-961 with `matched_count` gating at ~761, `deploy_pending_any` at ~763-780, and the reset at
~959. Confirm with `grep -n 'matched_count\|deploy_pending_any\|cycle_modified_files' \
scripts/orchestrate-cycle-plan.sh` before editing, and confirm the edit diff touches **only** line
ranges inside the checkpoint block — the scope-discipline constraint is verified by reading the
diff, not assumed.

**Files to modify**:
- `scripts/orchestrate-cycle-plan.sh` - Inter-Cycle Redeploy Checkpoint only: hoist
  `deploy_pending_any`, widen the branch condition, correct the announcement, add the
  concurrency-posture comment
- `scripts/tests/test-postflight-deploy-gate.sh` - refusal-then-recovery case for a non-allowlisted
  path under `agent-system/extensions/**`; extend, never duplicate

**Verification**:
- `bash scripts/tests/test-postflight-deploy-gate.sh` green including the new case
- `bash scripts/tests/test-orchestrate-cycle-postflight.sh` green (no cross-regression)
- `bash -n scripts/orchestrate-cycle-plan.sh` clean
- `git diff scripts/orchestrate-cycle-plan.sh` shows changes confined to the checkpoint block
- A ledger-consult assertion proves the widened path still calls `deploy_ledger_decide` (the
  cost bound), not a bypass
- `grep -c 'deploy_findings_snapshot' scripts/lib/deploy-baseline-lib.sh` confirms the library is
  still the single home of the (a)/(b)/(c) contract — no third implementation introduced

---

### Phase 4: Demonstrate the Closed Loop End to End [NOT STARTED]

**Goal**: Satisfy Acceptance #1 and #2 as *demonstrations*, not assertions. The dispatch is
explicit that "demonstrated end to end, not asserted" is the bar.

**Tasks**:
- [ ] Stage a fixture task whose `modified_files` lie under `agent-system/extensions/**` but
      **outside** `context/reference/orchestrator-critical-paths.json`'s curated list — the
      general case the dispatch's blast-radius framing names, and the case Phase 3 exists to cover.
- [ ] Drive it through the four-move loop with a deliberately stale deployed tree so the
      completion-deploy gate refuses the first postflight with exit 6.
- [ ] Capture and record, as evidence: the exit-6 refusal; `cycle_modified_files` non-empty
      afterward; `deploy_pending: true` on the task's `.return-meta.json`; the checkpoint firing on
      the following cycle with its widened-path announcement; the task reaching `completed` with
      **no** manual `deploy-headless.sh` and **no** manual `reconcile-task-status.sh`.
- [ ] Confirm the no-longer-happening failure: no fresh `implement` dispatch is prepared against
      an already-4/4-complete plan.
- [ ] Record the evidence in the task's summary artifact — the demonstration transcript is the
      acceptance artifact, so it must survive beyond the session.
- [ ] Verify no test was weakened or deleted to reach green (Acceptance #5): diff the two suites
      against their pre-task state and confirm every change is additive.

**Timing**: 2 hours

**Depends on**: 3

**Verification Tier**: full

**Files to modify**:
- None expected. This phase produces evidence. Any code change it forces means an earlier phase
  was incomplete — return to that phase rather than patching here.

**Verification**:
- The full transcript shows refusal -> accumulation -> checkpoint fires -> `completed`, with no
  manual step in between
- `git diff` of both test suites against their pre-task state is additive only: no removed
  assertion, no loosened comparison, no deleted case
- Both suites green on a final clean run

---

### Phase 5: Document the Concurrency Posture and Retire the D6 Residual [NOT STARTED]

**Goal**: Acceptance #3. Record the deferred-convergence posture where future readers will look
for it, and retire the two documentation paragraphs that will otherwise be stale the moment
Phase 3 lands.

**Tasks**:
- [ ] In `context/patterns/batch-orchestration-guardrails.md`'s
      `### The Postflight Completion-Deploy Gate` subsection: rewrite the
      **"Residual — the `/orchestrate` path (D6, not fixed by this mechanism)"** paragraph
      (~line 889) to record that the residual is now closed, by what change, and with what posture.
      Its two "not attempted here" / "not attempted by this mechanism" phrasings both become false
      on landing and must go.
- [ ] Add to that same subsection a short, explicit statement of the concurrency posture and its
      cost: convergence is deferred by one cycle in exchange for never firing a redeploy while a
      Move 2 dispatch may be in flight.
- [ ] In `context/patterns/regeneration-is-manual-only.md`: update the explicit non-exception
      paragraph (~lines 129-142), which currently says widening Stage MT-3 step 7's predicate is
      "the proper fix ... not attempted here", to record that it **was** done.
- [ ] **Preserve the "exactly two" sanctioned-site count** in that file and state in the prose
      that the count is deliberately unchanged because this task added no third trigger site —
      so a later reader does not mistake the unchanged count for an oversight. This is the one
      point where the dispatch's "update the count if it changes" instruction resolves to a
      deliberate non-change, and it must be said out loud.
- [ ] Cross-check every other reference to the D6 residual
      (`grep -rn 'D6' context/ docs/`) and update any that the change falsifies.

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: local

**Files to modify**:
- `context/patterns/batch-orchestration-guardrails.md` - D6 residual paragraph rewritten to
  closed; concurrency posture and its cost added to the completion-deploy-gate subsection
- `context/patterns/regeneration-is-manual-only.md` - non-exception paragraph updated; "two" count
  preserved with an explicit note on why it did not change

**Verification**:
- `grep -n 'not attempted here\|not attempted by this mechanism' context/patterns/*.md` returns no
  hit attached to the D6 residual
- The "exactly two" count is still present in `regeneration-is-manual-only.md`, now with its
  deliberate-non-change rationale adjacent
- Prose read-back: the documented behavior matches what Phase 3 actually shipped, verified by
  reading the diff of Phase 3 alongside the new prose
- No task-number reference lands in any file outside `specs/**` (per
  `.claude/rules/no-task-references-in-deliverables.md`) — cite the mechanism and the file, not
  a task number

---

### Phase 6: Document the Replay Path After an Unwind [NOT STARTED]

**Goal**: Part 3. Close the documented gap between `orchestrate-unwind-dispatch.sh` succeeding and
the operator knowing what to run next. Fully independent of Parts 1 and 2 — no shared file, no
shared mechanism.

**Tasks**:
- [ ] In `docs/architecture/orchestrate-state-machine.md`'s
      `## Unwinding an Unconsumed Dispatch` section (~lines 255-302), add a short "what to run
      afterwards" passage: when the task's artifacts show the work already completed (a
      `summaries/*.md` exists), run
      `reconcile-task-status.sh <task_number> <session_id>` — **not** a direct re-run of
      `orchestrate-cycle-postflight.sh` or `/orchestrate`.
- [ ] Name the concrete failure the direct re-run produces, since that is what makes the guidance
      stick: a fresh dispatch window the existing handoff predates, yielding
      `ERROR: STALE HANDOFF`, a false `verdict: failed` on complete work, a spurious
      `HANDOFF_STALE_OR_ABSENT` row in `detected_defects`, and a misleading
      "orchestration dispatch off-schema" commit.
- [ ] State explicitly that this is the handoff-identity gate **working as designed** against a
      timestamp the unwind never touches — so no reader mistakes the passage for a bug report and
      "fixes" the gate.
- [ ] Mirror the pointer in `skills/skill-orchestrate/SKILL.md`'s Move 1 unwind pointer
      (~lines 104-109): one sentence plus the cross-reference, not a second copy of the passage.
- [ ] Append a one-line hint to `scripts/orchestrate-unwind-dispatch.sh`'s existing success
      message (~line 398, immediately before `exit 0`) naming `reconcile-task-status.sh` as the
      likely next step. A printed line only — no branching, no new exit code, no change to the
      refusal gate or to the handoff-identity gate.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `docs/architecture/orchestrate-state-machine.md` - replay-path passage in the unwind section
- `skills/skill-orchestrate/SKILL.md` - one-sentence pointer in the Move 1 unwind reference
- `scripts/orchestrate-unwind-dispatch.sh` - one appended line in the success output; no
  behavioral change

**Verification**:
- `bash -n scripts/orchestrate-unwind-dispatch.sh` clean
- `bash scripts/orchestrate-unwind-dispatch.sh --help` (or a `--dry-run` invocation) still behaves
  identically apart from the added line; the refusal gate's five conditions are untouched
- `git diff scripts/orchestrate-unwind-dispatch.sh` shows exactly one added output line and no
  control-flow change
- Both docs name `reconcile-task-status.sh` and cross-reference each other

---

## Testing & Validation

- [ ] `bash scripts/tests/test-orchestrate-cycle-postflight.sh` green, extended with: exit-6
      refusal preserves `cycle_modified_files`; `deploy_pending` marker present; `verdict=defer`
      and paused commit message on refusal; `verdict=ok` and completion message when unrefused
- [ ] `bash scripts/tests/test-postflight-deploy-gate.sh` green, extended with the
      refusal-then-recovery path for a non-allowlisted `agent-system/extensions/**` path
- [ ] Both suites extended in place — no parallel suite created (Acceptance #4)
- [ ] No test weakened or deleted: additive-only diff confirmed in Phase 4 (Acceptance #5)
- [ ] `bash -n` clean on all three modified scripts
- [ ] End-to-end demonstration transcript captured in the summary artifact (Acceptance #1, #2)
- [ ] Concurrency posture present in both the script comment and
      `batch-orchestration-guardrails.md` (Acceptance #3)
- [ ] No edit anywhere under `.claude/**`: `git status --short` shows changes only under
      `agent-system/extensions/core/` and `specs/`

## Artifacts & Outputs

- `scripts/orchestrate-cycle-postflight.sh` - rc capture, honest verdict and commit message,
  accumulation guard comment
- `scripts/orchestrate-cycle-plan.sh` - widened checkpoint predicate plus concurrency-posture
  comment, confined to the checkpoint block
- `scripts/orchestrate-unwind-dispatch.sh` - one-line replay-path hint
- `scripts/tests/test-orchestrate-cycle-postflight.sh` - new refusal, accumulation, verdict, and
  commit-message cases
- `scripts/tests/test-postflight-deploy-gate.sh` - new refusal-then-recovery case
- `context/patterns/batch-orchestration-guardrails.md` - D6 retired, posture documented
- `context/patterns/regeneration-is-manual-only.md` - non-exception paragraph updated, count
  deliberately preserved
- `docs/architecture/orchestrate-state-machine.md` - post-unwind replay path
- `skills/skill-orchestrate/SKILL.md` - mirrored replay-path pointer
- `specs/252_port_deploy_pending_recovery_batch_postflight/summaries/01_*.md` - execution summary
  carrying the Phase 4 demonstration evidence

## Rollback/Contingency

Every phase commits green on its own, so rollback is per-phase `git revert` of that phase's
commit. Phase 1 and Phase 6 are independently valuable and safe to keep even if later phases are
reverted: Phase 1 is coverage plus at most an ordering-preserving un-gating, and Phase 6 is
documentation plus a printed line.

The highest-risk single change is Phase 3's predicate widening, because it alters when an
automated redeploy fires. If it proves too broad in practice (excessive redeploys), the narrowing
fallback is to gate the widened OR-branch on `deploy_pending_any` **alone** — dropping any
broader `agent-system/extensions/**` path matching — which restricts firing to tasks the
completion-deploy gate has already positively refused. That is a strictly smaller predicate than
the one this plan ships and still satisfies Acceptance #1, so it is a safe landing point rather
than a full revert.

If Phase 4's demonstration fails, do **not** patch within Phase 4: return to Phase 2 or 3, since a
failed demonstration means the mechanism is incomplete rather than the evidence being wrong.

No production data or external state is touched; a redeploy is idempotent and reversible by
re-running `deploy-headless.sh`, so there is no irreversible step anywhere in this plan.
