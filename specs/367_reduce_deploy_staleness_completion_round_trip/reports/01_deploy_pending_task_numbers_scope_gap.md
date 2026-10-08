# Research Report: Task #367

**Task**: 367 - Reduce the deploy-staleness completion round trip without weakening the completion-deploy gate
**Started**: 2026-10-08T06:00:00Z
**Completed**: 2026-10-08T06:35:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/update-task-status.sh`, `command-gate-out.sh`,
  `orchestrate-cycle-plan.sh`, `orchestrate-cycle-postflight.sh`, `skill-base.sh`,
  `reconcile-task-status.sh`, `scripts/lib/redeploy-checkpoint-lib.sh`,
  `scripts/lib/deploy-ledger-lib.sh`, `scripts/tests/test-lint-deploy-caller-wrap.sh`
- Documentation: `context/patterns/batch-orchestration-guardrails.md`,
  `context/patterns/regeneration-is-manual-only.md`, `skills/skill-orchestrate/SKILL.md`
- Git history: the actual 2026-10-07 incident commits (task 356, 358, 361; sessions
  `sess_1791361777_314fa0` and `sess_1791392970_a0a292`)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Cause identified, with evidence**: the automatic "post-deploy reconcile pass" that
  `/orchestrate`'s Inter-Cycle Redeploy Checkpoint runs (`run_post_deploy_reconcile_pass()` in
  `scripts/lib/redeploy-checkpoint-lib.sh:51`) only ever considers tasks that are members of the
  **current `/orchestrate` invocation's own `task_numbers` list** — the loop that decides which
  tasks are deploy-pending is `for _dp_t in $(mt_get_json '.task_numbers' | jq -r '.[]' ...)` in
  `scripts/orchestrate-cycle-plan.sh:874`. A task refused by the completion-deploy gate in one
  invocation is **structurally invisible** to the automatic mechanism in any later invocation
  that does not happen to name that exact task number again. This is a sharper, directly
  code-readable variant of cause (b) from the dispatch (the reconcile pass ran, and would run
  again, but the candidate set it draws from never contained the stranded tasks) — not the
  "exactly three clean-success branches" restriction the dispatch anticipated, but a narrower,
  upstream scoping gap in what counts as a candidate at all.
- **Confirmed by the actual incident**: tasks 356 and 358 were refused with exit 6 at
  `2026-10-07T09:33-09:34` inside session `sess_1791361777_314fa0` (commits `b80565ca0`,
  `92453ba91`, both titled `task N: orchestration paused (cycle 3)`). No further automated
  activity touched either task from that session. Both were only promoted roughly three hours
  later, in an **unrelated session** (`sess_1791392970_a0a292`, which had `task_numbers = [361]`
  only) by a commit (`45122f702`, `"task 356, 358: promote stranded completions and stamp plan
  files"`) whose message says in plain language that `reconcile-task-status.sh` was replayed by
  hand against each task. This is the exact "extra redeploy cycle plus a reconcile-task-status.sh
  call" cost named in the dispatch, and it happened precisely because neither task was a member
  of `sess_1791392970_a0a292`'s `task_numbers`.
- **The mechanism that exists is correct, not broken**: by direct code reading,
  `deploy_pending_bool == "true"` unconditionally forces `deploy_ledger_decide()` to return `run`
  (`scripts/lib/deploy-ledger-lib.sh:178`, never skipped by the durable ledger);
  `cycle_modified_files` accumulates even across an exit-6 refusal (task 252's regression-anchor
  fix, `orchestrate-cycle-postflight.sh:1736-1753`, landed 2026-09-22, well before this incident);
  and the checkpoint (and its reconcile pass) runs strictly before Eligibility, the no-eligible
  circuit breaker, and the all-terminal check every cycle. None of this is the defect. The defect
  is that the checkpoint's own candidate set is drawn from the invocation's `task_numbers`, not
  from `specs/state.json` as a whole.
- **A second, independent finding**: `context/patterns/regeneration-is-manual-only.md`'s
  "Automated Exception: The Postflight Completion-Deploy Gate" section still names
  `commands/implement.md` Step 4's batch-refusal trigger as one of its two sanctioned call sites.
  That file **no longer exists** in the source store (confirmed by direct search). The
  mechanically authoritative pair — the one `scripts/tests/test-lint-deploy-caller-wrap.sh`
  derives fresh every run, never from a hardcoded list — is `orchestrate-cycle-plan.sh` and
  `command-gate-out.sh` (also stated by name in `scripts/lib/redeploy-checkpoint-lib.sh:13-16`).
  The prose is stale and should be corrected, not the lint.
- **Recommended fix shape**: widen `run_post_deploy_reconcile_pass()` itself (in
  `scripts/lib/redeploy-checkpoint-lib.sh`, which is in this task's own `file_scope` and is
  **not** one of the excluded files) to also sweep `specs/state.json`'s `active_projects[]` for
  **any** non-terminal task whose own `.return-meta.json` carries `deploy_pending: true`,
  independent of `task_numbers` — not just the ones the invocation-scoped
  `deploy_pending_tasks_json` already names. This reuses the exact same already-sanctioned call
  site (`orchestrate-cycle-plan.sh:1169`'s unconditional, every-cycle call to
  `run_post_deploy_reconcile_pass`) and requires **zero edits** to the excluded
  `orchestrate-cycle-plan.sh`/`orchestrate-cycle-postflight.sh` files — it only widens the reach
  of an already-sanctioned trigger's existing call, exactly as Settled decision 10 permits.

## Context & Scope

This is a `meta` task whose edit target is the agent-system source store
(`agent-system/extensions/core/**`), never the deployed `.claude/**` tree. The task's own
pre-declared `file_scope` (read from `specs/state.json` at research time) is:

```
agent-system/extensions/core/scripts/lib/redeploy-checkpoint-lib.sh
agent-system/extensions/core/scripts/reconcile-task-status.sh
agent-system/extensions/core/scripts/tests/test-redeploy-checkpoint-promotion.sh
agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md
```

Note `command-gate-out.sh` is **not** in this list. This research independently arrived at the
same two implementation files before reading `file_scope`, which corroborates the direction: the
fix belongs in the shared library (plus, if needed, a small adjustment to
`reconcile-task-status.sh`), not in either of the two already-sanctioned deploy-trigger call
sites, and not in `command-gate-out.sh`.

The dispatch's own exclusions are honored: `scripts/update-task-status.sh` (the gate itself),
`scripts/orchestrate-cycle-postflight.sh` (the deferral site, contended by five open tasks), and
`scripts/orchestrate-cycle-plan.sh` (same contention reason, plus the lint-enforced inline
`deploy-headless.sh` wrap that must not move) were read for understanding but not proposed as
edit targets.

## Findings

### Codebase Patterns

**The gate itself (correct, check-only, unconditional)**. `scripts/update-task-status.sh:639-787`
("PHASE 0.5") refuses a `postflight implement` transition with exit 6 when the task's own
`.return-meta.json` `modified_files` overlap `agent-system/extensions/**` AND
`scripts/lib/deploy-freshness-lib.sh`'s `deploy_freshness_status` reports the touched extension is
provably `STALE`. It writes nothing on refusal (confirmed by reading the refusal branch itself:
the `exit 6` at line 787 is reached before any `state.json` write in that code path). This gate is
excluded from this task's edit scope by the dispatch, and this research finds no reason it should
change: the refusal is the correct behavior being protected, not the defect.

**The two sanctioned deploy-trigger call sites, both correctly implemented for their own task**.
- `scripts/command-gate-out.sh`'s `rc == 6` branch (around line 180 onward) retries **inline,
  synchronously, for the one task it is already processing**: it takes a pre/post
  `verify-deploy.sh --skip-slow` baseline pair around a `deploy-headless.sh --skip-verify` call,
  and on branch (c) (deploy landed, no new findings) retries
  `update-task-status.sh postflight ... || gate_out_retry_rc=$?` exactly once. This path has
  **zero cross-cycle cost** by construction — there is no concurrency and no "next cycle" to wait
  for, so the dispatch's claim that "the single-task `/implement` path therefore does NOT exhibit
  this defect" is confirmed by direct reading.
- `scripts/orchestrate-cycle-plan.sh`'s Inter-Cycle Redeploy Checkpoint (`orchestrate_cycle_plan_main`,
  the `(k, part 2)` region starting ~line 791) is the batch/`/orchestrate` site. Its trigger
  predicate is `{ matched_count -gt 0 || deploy_pending_any = true }` (line 913), where
  `deploy_pending_any` is computed by a loop reading **every task named in this invocation's own
  `task_numbers`** (line 874: `for _dp_t in $(mt_get_json '.task_numbers' | jq -r '.[]' ...)`) and
  checking that task's own `.return-meta.json` for `deploy_pending == true`.

**The mechanics that make the checkpoint work when it does fire are sound and already
hardened against the obvious failure modes** (all verified by direct reading, not assumed):
- `deploy_pending_bool == "true"` unconditionally forces `deploy_ledger_decide()` to return
  `{"decision":"run", ...}` (`scripts/lib/deploy-ledger-lib.sh:178`) — the durable redeploy ledger
  can never skip a redeploy a deploy-pending task needs.
- `cycle_modified_files` — the gating signal the checkpoint reads at the top of the NEXT cycle
  (`cycle_modified_files_json=$(mt_get_json '.cycle_modified_files')` at
  `orchestrate-cycle-plan.sh:847`, consumed at `:848`) — is accumulated **unconditionally**, even
  when the `implemented)` arm's status write was refused by exit 6. This is a
  "REGRESSION ANCHOR"-guarded block at `orchestrate-cycle-postflight.sh:1736-1753`, landed by
  task 252 on **2026-09-22**, with a dedicated characterization test
  ("Characterization: cycle_modified_files accumulates across a real exit-6 deploy-pending
  postflight refusal" in `scripts/tests/test-orchestrate-cycle-postflight.sh`). This landed
  **eleven days before** the 2026-10-07 incident this task investigates, so it was already live
  and is not the defect.
- `run_post_deploy_reconcile_pass()` (`scripts/lib/redeploy-checkpoint-lib.sh:51`) runs the actual
  promotion — `reconcile-task-status.sh` per task in `post_deploy_reconcile_json` — strictly
  **before** Eligibility (`orchestrate-cycle-plan.sh:1500` `## (c) Eligibility`), the no-eligible
  circuit breaker (`:1638`), and the all-terminal check, on every cycle of every invocation
  (called unconditionally at `:1169`, outside every `if`/`else` the checkpoint's own trigger logic
  opened). A promoted task therefore becomes terminal before the SAME cycle's eligibility pass
  can even consider re-dispatching it — this is exactly the "no second, byte-identical `implement`
  dispatch is ever derived" guarantee the library's own header documents, and it is correct.
- A documented, already-closed "second residual" (`context/patterns/batch-orchestration-guardrails.md`'s
  "D6's original closure did not account for the identical-dispatch guard" subsection, landed by
  task 266 on **2026-09-28**, also before this incident) adds a streak-freeze so a deploy-pending
  task's necessarily-identical re-dispatch is never mistaken for churn and halted by the
  identical-dispatch convergence guard (`orchestrate-cycle-plan.sh:2508-2545`). `update-task-status.sh`
  clears `deploy_pending`/`deploy_pending_reason` at the single completion chokepoint on success
  (confirmed at `update-task-status.sh:1083`'s `del(.deploy_pending, .deploy_pending_reason)`),
  so the freeze cannot arm permanently.

None of this — all already landed and correct before the incident — explains why 356/358 were
stranded. **The gap is upstream of all of it**: the candidate set the checkpoint's
`deploy_pending_any` loop (and therefore `run_post_deploy_reconcile_pass`'s
`post_deploy_reconcile_json`) ever considers is `mt_get_json '.task_numbers'` — this one
invocation's own named tasks — never a scan of `specs/state.json` as a whole.

### The 2026-10-07 incident, traced through git history

A five-task `/orchestrate` batch (session `sess_1791361777_314fa0`) concurrently dispatched
implementation work for (at least) tasks 356, 357, and 358 in one cycle (confirmed by
`dispatch-metrics.sh`'s own recorded commit list for task 356's `dispatch_seq=7` entry, which
interleaves "task 357:", "task 358:", and "task 356:" phase/completion commits across one
2671-second agent transcript window — these are concurrent sibling dispatches sharing one working
tree, not one agent working three tasks). All three completed their own implementation work
(6/6 phases, own `complete implementation` commit). Postflight then ran for each:

- Task 357's transition succeeded normally (no deploy-pending issue recorded for it; its own
  `modified_files` evidently did not overlap `agent-system/extensions/**`, or the gate did not
  find staleness for whatever it touched).
- Tasks 356 and 358 were each refused by the completion-deploy gate (exit 6). Each task's own
  `issues.jsonl` recorded the refusal at `2026-10-07T09:33:55Z` / similar
  (`"Task 356's postflight completion write was refused by the completion-deploy gate (exit 6)
  ... Deferred to the next cycle's Inter-Cycle Redeploy Checkpoint to deploy and reconcile."`),
  and each produced a `task N: orchestration paused (cycle 3)` commit
  (`b80565ca0` for 356, `92453ba91` for 358) — the honest, non-"complete implementation" commit
  message `orchestrate-cycle-postflight.sh:1663-1666` produces specifically when
  `implemented_gate_passed == true && deploy_pending_refusal == true`.

Nothing in `sess_1791361777_314fa0` ever touches tasks 356 or 358 again. The next activity on
either task is roughly three hours later, in a **different session** (`sess_1791392970_a0a292`),
whose own git-visible task work is entirely about task 361 (research at `10:44`, through a plan
and six implementation phases, including a phase explicitly named `"Redeploy and Final Gate Set"`
at `12:29:10` — task 361's own plan apparently required a redeploy as a verification step). Three
commits follow in quick succession: task 361's own completion
(`df359ab9b` at `12:31:14`, `d51c99b43` at `12:31:43` — clean, no refusal, because the tree was
already fresh from 361's own phase-6 redeploy two minutes earlier), and then
`45122f702` ("task 356, 358: promote stranded completions and stamp plan files") at `12:32:07`,
whose message states plainly:

> "Both tasks had completed their work ... but their status write was refused by the completion-
> deploy gate, leaving state.json and the plan-file stamp both at IMPLEMENTING. The source store
> is fresh again after the redeploy, so reconcile-task-status.sh replayed each postflight and
> promoted both, stamping the plan files in the same operation."

This is a direct, first-person record of the exact manual remedy the dispatch describes:
`reconcile-task-status.sh` was run **by name against 356 and 358**, outside of any `/orchestrate`
cycle's own automatic loop, because `sess_1791392970_a0a292`'s own `task_numbers` was `[361]` —
the automatic mechanism never had a candidate list that included 356 or 358 to even consider.

Whether `sess_1791361777_314fa0` itself ever reached a further cycle (which, had 356/358 still
been members of ITS `task_numbers`, should have promoted them automatically per the mechanics
above) could not be established from the evidence available post-archival (the session's
transient `specs/.orchestration/.orchestrator-multi-state-sess_1791361777_314fa0.json` file is
gitignored and no longer on disk). This is noted as an open, secondary question — see Risks below
— but it does not change the fix: even if that invocation HAD run a further cycle and promoted
356/358 cleanly, the **general** problem (a deploy-pending task stranded by a batch that ends, or
whose remaining tasks all converge, before a further cycle fires) remains exactly as exposed by
this incident, because the candidate set is `task_numbers`-scoped by construction, not because
any one invocation happened to stop early.

### The stale documentation divergence

The dispatch names a documented disagreement between two sources on the sanctioned-site pair.
Resolved:

- `scripts/tests/test-lint-deploy-caller-wrap.sh` derives every genuine `deploy-headless.sh`
  caller **mechanically, fresh on every run, never from a hardcoded list** (confirmed by its own
  header comment: "every run, never a hardcoded path list, so a new caller is discovered
  automatically"). `scripts/lib/redeploy-checkpoint-lib.sh:13-16` states its own finding from this
  lint: exactly two genuine callers in the whole corpus — `orchestrate-cycle-plan.sh` and
  `command-gate-out.sh`.
- `context/patterns/regeneration-is-manual-only.md`'s "Automated Exception: The Postflight
  Completion-Deploy Gate" section (around line 141) still names its two sanctioned call sites as
  `command-gate-out.sh`'s `rc == 6` branch **and** `commands/implement.md` Step 4's batch-refusal
  trigger (described there as "the multi-task `/implement` completion path").
- `commands/implement.md` **does not exist** in the source store (`find . -iname "implement.md"
  -path "*commands*"` returns nothing). This confirms the prose is stale: `/implement`'s
  multi-task batch capability was evidently folded into `/orchestrate`'s batch engine at some
  point, and this one paragraph was never updated to match. The same document's EARLIER section
  ("Automated Exception: The Inter-Cycle Self-Modification Checkpoint", around line 83) already
  correctly names `orchestrate-cycle-plan.sh`'s checkpoint as the sanctioned site for the
  *critical-path-match* trigger, and a later "Update" paragraph (around line 155) confirms the
  *deploy-pending* override was explicitly folded into that SAME checkpoint call site
  ("`skill-orchestrate`'s Move 1 ... had its own `deploy_pending_any` override ... hoisted out of
  the narrow `matched_count -gt 0` branch"). So the mechanically authoritative pair, matching the
  lint exactly, is `{command-gate-out.sh, orchestrate-cycle-plan.sh}` for BOTH exceptions
  combined — the `commands/implement.md` reference is a dangling pointer to a deleted file and
  should simply be removed/corrected, never treated as naming a real third site.

This resolves the dispatch's acceptance criteria #5/#6 direction: the lint does not need to
change (it is already correct and already green); the prose in
`regeneration-is-manual-only.md` needs a small correction to stop citing a file that no longer
exists.

## Recommendations

1. **Widen `run_post_deploy_reconcile_pass()` in `scripts/lib/redeploy-checkpoint-lib.sh`** to, in
   addition to its existing `post_deploy_reconcile_json` loop (unchanged, still fed by the
   invocation-scoped `deploy_pending_tasks_json`), also sweep `specs/state.json`'s
   `active_projects[]` for **any** task that is (a) non-terminal and (b) carries
   `deploy_pending: true` in its own `.return-meta.json`, regardless of whether that task number
   is a member of this invocation's `task_numbers`. For each such task found, replay
   `reconcile-task-status.sh <task> <session_id>` exactly as the existing loop already does, with
   the same non-fatal "warn, record, move on" posture for a non-zero exit. This requires editing
   only the library (in-scope, not excluded) — `orchestrate-cycle-plan.sh`'s own single call site
   (`run_post_deploy_reconcile_pass` at line 1169, called unconditionally every cycle of every
   `/orchestrate` invocation, single-task or batch) needs no change at all. This is a widening of
   an *existing* sanctioned trigger's reach, not a new call site, matching Settled decision 10 and
   the precedent `regeneration-is-manual-only.md` already records for the critical-path
   predicate's own earlier widening.
   - This also means the fix benefits from running on **every** future `/orchestrate` invocation,
     including a single-task one on a completely unrelated task number — the very next time
     anyone runs `/orchestrate` on anything, any stranded deploy-pending task anywhere in
     `specs/state.json` gets a chance to be swept, without anyone needing to know it was
     stranded or run `reconcile-task-status.sh` by hand.
   - Safety is structural, not something this widening has to re-derive: `reconcile-task-status.sh`
     calls through `update-task-status.sh`'s own PHASE 0.5 gate, which is unconditional and
     check-only — sweeping a task whose extension is still genuinely stale simply re-refuses
     (exit 6) harmlessly and leaves the marker in place for the next sweep. The gate itself is
     untouched by this recommendation.
2. **`scripts/reconcile-task-status.sh`** is already in this task's `file_scope`; this research
   did not find a hard requirement to edit it (its existing per-task `postflight ... implement`
   call path already does the right thing once invoked), but the plan phase should re-confirm
   whether a system-wide sweep caller needs any small accommodation there (e.g., confirming it
   degrades safely when called for a task that turns out not to be deploy-pending at all, which
   it already should via its own artifact/handoff-driven promotion table).
3. **Correct `context/patterns/regeneration-is-manual-only.md`'s "Automated Exception: The
   Postflight Completion-Deploy Gate" section** to stop naming `commands/implement.md` Step 4 (a
   file that no longer exists) and instead state plainly that both of this exception's needs are
   served by the SAME two sites the lint enforces: `command-gate-out.sh`'s `rc == 6` branch, and
   `orchestrate-cycle-plan.sh`'s Inter-Cycle Redeploy Checkpoint (already named as the sanctioned
   site for the sibling "Inter-Cycle Self-Modification Checkpoint" exception two sections above,
   and already confirmed by that document's own later "Update" paragraph to carry the
   deploy-pending override on the same call site). This is a documentation-only correction; no
   behavior changes.
4. **Build the reproduction fixture at `scripts/tests/test-redeploy-checkpoint-promotion.sh`**
   (already named in `file_scope`) around the following shape, which directly demonstrates the
   defect and its fix:
   - Fixture state: two tasks, A (in this cycle's `task_numbers`) and B (deliberately **not** in
     this cycle's `task_numbers`, simulating a task stranded by an earlier, now-finished
     invocation), both non-terminal with `deploy_pending: true` recorded in their own
     `.return-meta.json`, both backed by a real artifact set `reconcile-task-status.sh` would
     promote once the gate stops refusing.
   - Before the fix: running the checkpoint (with a verified-fresh deploy) promotes A (it is in
     `task_numbers`) but leaves B stranded (`status` unchanged, `deploy_pending` still `true`) —
     this is the RED case that demonstrates the exact defect.
   - After the fix: the SAME run also promotes B, with no `task_numbers` membership required —
     GREEN.
   - A sibling case (acceptance #4) must show the gate still refuses when the tree is genuinely
     stale: the sweep attempts B, `update-task-status.sh` genuinely refuses again (exit 6, no
     `state.json` write), and `deploy_pending` stays `true` — this exercises the no-weakening
     requirement directly against the widened sweep, not just the pre-existing gate test
     (`scripts/tests/test-postflight-deploy-gate.sh`, which already covers the gate's own
     unconditional refusal independent of this task's change and does not need to be touched).
5. **Measure the before/after cycle count** (acceptance #3) using the exact scenario this
   research reconstructed: a task whose `implement` dispatch is refused by exit 6 inside one
   `/orchestrate` cycle, where NO further cycle of that same invocation runs (simulating "the
   batch ends" or "the operator's next action names a different task"). Before this change: the
   task requires a human-noticed, hand-run `reconcile-task-status.sh` call — effectively an
   unbounded number of dispatch cycles (zero further AUTOMATED cycles ever resolve it). After this
   change: the very next `/orchestrate` invocation on *anything* resolves it in that invocation's
   own first cycle's checkpoint, at the cost of the one redeploy the design already accepts as
   unavoidable. Report this as the "N automated cycles -> 1" (or "unbounded -> bounded by the next
   invocation") reduction, not a fabricated single number — the exact count depends on how many
   cycles the fixture's own `/orchestrate` harness takes to reach its first checkpoint.
6. **Do not touch `command-gate-out.sh`.** It is not in `file_scope`, its own single-task path has
   no analogous defect (confirmed above), and `scripts/orchestrate-cycle-plan.sh`'s own
   unconditional per-cycle call to `run_post_deploy_reconcile_pass()` is sufficient to make the
   widened sweep take effect on the next `/orchestrate` invocation regardless of which task that
   invocation targets.

## Decisions

- **Cause named**: the automatic promotion mechanism is correct and well-hardened in every
  mechanic this research traced (ledger force-run, unconditional `cycle_modified_files`
  accumulation, pre-eligibility ordering, the identical-dispatch streak-freeze, marker
  clearing-on-success) — all landed and live before the 2026-10-07 incident. The actual gap is
  that its candidate set is scoped to the CURRENT invocation's `task_numbers`
  (`orchestrate-cycle-plan.sh:874`), never a system-wide scan of `specs/state.json`. This is
  classified as a variant of cause (b) ("it ran but `post_deploy_reconcile_json` did not include
  those tasks") — for a different, narrower reason than the dispatch's own anticipated
  "restricted to exactly the three clean-success branches" explanation: the tasks were excluded
  upstream of that restriction, by never being candidates at all.
- **Fix site decided**: `scripts/lib/redeploy-checkpoint-lib.sh`'s `run_post_deploy_reconcile_pass()`,
  widened to sweep `specs/state.json` system-wide for `deploy_pending` tasks, independent of
  `task_numbers`. This requires editing neither excluded file
  (`orchestrate-cycle-plan.sh`/`orchestrate-cycle-postflight.sh`) and adds no new
  `deploy-headless.sh` caller (the sweep never calls `deploy-headless.sh` itself — only
  `reconcile-task-status.sh`, which is a data-promotion tool with no deploy trigger of its own).
- **Documentation divergence resolved**: the lint (`test-lint-deploy-caller-wrap.sh`) and
  `scripts/lib/redeploy-checkpoint-lib.sh`'s own header are authoritative — two genuine callers,
  `orchestrate-cycle-plan.sh` and `command-gate-out.sh`. `regeneration-is-manual-only.md`'s
  `commands/implement.md` Step 4 reference is stale (the file does not exist) and should be
  corrected to name `orchestrate-cycle-plan.sh`'s checkpoint, not treated as evidence of a real
  third site.
- **`command-gate-out.sh` excluded from the implementation**, consistent with the task's own
  `file_scope` and this research's independent finding that its own path has no analogous defect.

## Risks & Mitigations

- **Open question, not fully resolved by available evidence**: whether
  `sess_1791361777_314fa0` (the original stranding session) ever reached a further cycle at all.
  The session's own transient multi-state file no longer exists on disk (gitignored, cleaned up),
  so this could not be directly confirmed either way. Mitigation: the recommended fix is correct
  and sufficient regardless of the answer — it closes the `task_numbers`-scoping gap, which is
  the gap that matters whether or not that specific invocation's loop continued. The plan phase
  should not spend effort trying to definitively settle this historical sub-question; the
  reproduction fixture (Recommendation 4) demonstrates the real defect directly rather than
  depending on reconstructing exact agent-loop behavior from an already-archived session.
- **Risk of widening the sweep too broadly**: a system-wide scan of `specs/state.json` on every
  cycle of every `/orchestrate` invocation adds a bounded amount of work (one JSON scan plus one
  `.return-meta.json` read per non-terminal task) to every cycle, not just cycles that would
  otherwise have triggered the checkpoint. Mitigation: this work is cheap (no process spawn beyond
  the existing per-candidate `reconcile-task-status.sh` calls, which only fire for genuinely
  deploy-pending tasks) and is already paid, at the same big-O, by the pre-existing
  `task_numbers`-scoped loop this change extends — it is not a new order of cost, only a wider
  candidate set.
- **Risk of accidentally weakening the gate**: ruled out by construction — the widened sweep only
  ever calls `reconcile-task-status.sh`, which itself only ever calls
  `update-task-status.sh postflight ... implement`, the exact same unconditional, check-only gate
  this task is required not to weaken. Acceptance criterion #4's fixture (Recommendation 4) should
  exercise this directly against the widened code path, not merely re-assert the pre-existing
  gate test's coverage.

## Context Extension Recommendations

- **Topic**: the invocation-scoped vs. system-wide distinction in `/orchestrate`'s batch-state
  model.
- **Gap**: `context/patterns/batch-orchestration-guardrails.md`'s "The Postflight Completion-Deploy
  Gate" subsection documents the checkpoint's trigger and reconcile mechanics in detail but does
  not currently state, as an explicit invariant, that the reconcile pass's candidate set is
  bounded by the CURRENT invocation's `task_numbers` — a reader could reasonably (and, per this
  incident, incorrectly) assume the mechanism is system-wide already.
  `context/patterns/regeneration-is-manual-only.md`'s dangling `commands/implement.md` reference is
  a second, independent gap in the same neighborhood.
- **Recommendation**: once this task's fix lands, update
  `batch-orchestration-guardrails.md`'s "The Postflight Completion-Deploy Gate" subsection to state
  the widened, system-wide sweep as the current invariant (superseding the task_numbers-scoped
  description), and correct `regeneration-is-manual-only.md`'s stale file reference per
  Recommendation 3 above. Both are documentation updates that belong to this task's own
  implementation, not a new follow-up task.

## Appendix

### Search queries / commands used

- `git log --oneline | grep -i "task 356\|task 358\|task 361"` and `git show --stat` /
  `git show -- specs/state.json` on the resulting commits, to reconstruct the actual incident
  timeline and the exact manual remedy.
- `git log -S"REGRESSION ANCHOR"`, `git log -S"did not account for the identical-dispatch guard"`,
  `git log -S"run_post_deploy_reconcile_pass"` against the relevant files, to date the prior
  hardening work (tasks 252, 266, 250) relative to the 2026-10-07 incident.
- `find . -iname "implement.md" -path "*commands*"`, confirming `commands/implement.md` no longer
  exists in the source store.
- Direct reads of `scripts/update-task-status.sh` (PHASE 0.5, lines 639-787),
  `scripts/command-gate-out.sh` (the `rc == 6` branch), `scripts/orchestrate-cycle-plan.sh`
  (the Inter-Cycle Redeploy Checkpoint, Eligibility, no-eligible circuit breaker, and
  identical-dispatch streak-freeze regions), `scripts/orchestrate-cycle-postflight.sh` (the
  `implemented)` arm's `deploy_pending_refusal` handling and the `cycle_modified_files`
  accumulation block), `scripts/lib/redeploy-checkpoint-lib.sh`,
  `scripts/lib/deploy-ledger-lib.sh`, `skills/skill-orchestrate/SKILL.md` (Move 3/Move 4), and
  `context/patterns/{batch-orchestration-guardrails.md,regeneration-is-manual-only.md}`.

### References (durable anchors, no task-number citations outside this specs/** report)

- `agent-system/extensions/core/scripts/update-task-status.sh:639-787` (PHASE 0.5 gate)
- `agent-system/extensions/core/scripts/command-gate-out.sh` (`rc == 6` branch)
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh:791-1169` (Inter-Cycle Redeploy
  Checkpoint), `:874` (the `task_numbers`-scoped `deploy_pending_any` loop), `:1500-1659`
  (Eligibility / no-eligible circuit breaker), `:2508-2545` (identical-dispatch streak-freeze)
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh:1163-1171`
  (`deploy_pending_refusal` handling), `:1663-1666` (the "orchestration paused" commit-message
  branch), `:1736-1753` (unconditional `cycle_modified_files` accumulation)
- `agent-system/extensions/core/scripts/lib/redeploy-checkpoint-lib.sh:1-158`
  (`run_post_deploy_reconcile_pass`, the fix site)
- `agent-system/extensions/core/scripts/lib/deploy-ledger-lib.sh:178` (`deploy_pending` force-run)
- `agent-system/extensions/core/scripts/reconcile-task-status.sh`
- `agent-system/extensions/core/scripts/tests/test-lint-deploy-caller-wrap.sh`
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` ("The
  Postflight Completion-Deploy Gate" subsection)
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` (both "Automated
  Exception" sections)
