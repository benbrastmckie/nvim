# Research Report: Task #266

**Task**: 266 - deploy_pending vs identical-dispatch guard: composition defect
**Started**: 2026-09-28
**Completed**: 2026-09-28
**Effort**: research
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/{orchestrate-cycle-postflight.sh,orchestrate-cycle-plan.sh,update-task-status.sh,skill-base.sh,reconcile-task-status.sh}`, `agent-system/extensions/core/scripts/lib/deploy-ledger-lib.sh`, `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`, `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`, `agent-system/extensions/core/scripts/tests/{test-orchestrate-cycle-postflight.sh,test-orchestrate-cycle-plan.sh}`
**Artifacts**:
- This report: `specs/266_deploy_pending_vs_identical_dispatch_guard/reports/01_deploy_pending_vs_identical_dispatch_guard.md`
**Standards**: report-format.md, subagent-return.md

**SOURCE STORE IS THE EDIT TARGET for any follow-on plan/implementation**:
`agent-system/extensions/core/` (never `.claude/**` — `.claude/` is a disposable deploy artifact;
see `.claude/rules/source-store-deploy-boundary.md`). Every path cited below is given relative to
`agent-system/extensions/core/` unless marked `.claude/...` explicitly (deployed mirror, cited only
for orientation).

## Executive Summary

- The defect is real and precisely locatable. Two independently-correct mechanisms compose badly
  because of a **timing/ownership gap**: `reconcile-task-status.sh` — the tool that already knows
  how to promote a deploy-unblocked task to `completed` — is invoked **exactly once**, at
  `/orchestrate` entry (`skills/skill-orchestrate/SKILL.md` lines 46-54: "run the entry reconcile
  ONCE (never per-cycle)"), and **nowhere else inside the per-cycle loop**. Nothing calls it again
  after the Inter-Cycle Redeploy Checkpoint's own mid-run deploy lands.
- Because of that gap, the only way a deploy-unblocked task's `implementing` status can ever
  advance to `completed` **within the same run** is a fresh `implement` dispatch being re-derived,
  re-sent to an agent, and re-postflighted — which is wasteful even when it works, and which is
  exactly what trips the identical-dispatch guard (`orchestrate-cycle-plan.sh:2296-2347`) when the
  re-derived dispatch is byte-identical to the one already refused, because nothing about the
  task's plan/status inputs changed.
- **Recommended primary fix** (makes the guard question largely moot on the success path): after
  the Inter-Cycle Redeploy Checkpoint's deploy lands cleanly for a cycle where `deploy_pending_any`
  was the trigger, call `reconcile-task-status.sh <task> <session_id>` (live, not `--dry-run`) for
  every task named in `deploy_pending_tasks_json`, **before** this same cycle's own status refresh
  (`orchestrate-cycle-plan.sh:1035-1059`, which runs immediately after the checkpoint block ends
  at line ~1020). Reconcile already performs precisely the freshness-gated promotion the operator
  ran by hand in both observed incidents ("touched extension(s) verified fresh -- proceeding");
  wiring it in-loop makes the checkpoint's own "no manual action needed" claim true rather than
  aspirational, and it lets that cycle's already-scheduled status refresh see `completed` directly
  — the task then hits the pre-existing `is_terminal_status()` skip (line 1339: `completed` is
  terminal) and is never re-dispatched at all this cycle, so the identical-dispatch guard is never
  reached for it.
- **Recommended defense-in-depth fix for the guard itself**: do not disable the identical-dispatch
  guard for deploy-pending tasks; instead **suppress only the streak increment** (not the whole
  mechanism) when this task's own `.return-meta.json` carries `deploy_pending: true` at the moment
  this cycle's dispatch content is hashed. Rationale below (Findings > Guard Modification Choice).
  This is deliberately a backstop for the primary fix's failure paths (checkpoint deploy itself
  fails or is deferred, reconcile is inconclusive because freshness `CANNOTVERIFY`s, etc.) — with
  the primary fix in place, the backstop should rarely if ever fire in practice.
- **The "no manual action needed" message is currently false** in both observed cases and should
  be corrected regardless of which structural fix lands (a valid, low-risk partial fix on its
  own). Exact before/after text below.
- **A related, previously undocumented gap surfaced during this research**: nothing ever clears
  `deploy_pending: true` from a task's `.return-meta.json` once set (confirmed: no writer in
  `reconcile-task-status.sh` or `update-task-status.sh` clears it). This is inert for the
  identical-dispatch question once the task reaches `completed` (terminal tasks are never
  re-considered), but it does mean the Inter-Cycle Redeploy Checkpoint's `deploy_pending_any` scan
  (`orchestrate-cycle-plan.sh:804-820`, which iterates unconditionally over
  `mt_get_json '.task_numbers'` with no terminal-status filter) will keep reporting that marker
  true for a task number reused in a *future* `/orchestrate` invocation unless something clears it
  — worth flagging to the planning phase even though it is not one of the four named
  "points to settle."

## Context & Scope

Task 266 asks for research/planning only, not implementation, into a documented composition
defect between two individually-correct `/orchestrate` mechanisms:

1. **The Postflight Completion-Deploy Gate** (`update-task-status.sh:530-659`, exit code 6): a
   check-only backstop that refuses to write `state.json` to `completed` when the touched
   extension is stale relative to its source store.
2. **The identical-dispatch convergence guard** (`orchestrate-cycle-plan.sh:2296-2347`, "Fix 2"):
   halts a task for the rest of the run when its derived dispatch content matches the immediately
   preceding cycle's dispatch content twice in a row.

Constraints from the dispatch: do not weaken either mechanism for the general case; do not touch
tasks 260-264 (the evidence record); settle, but do not pre-decide, four specific design
questions; verify the fix reproduces and resolves the interaction while leaving both mechanisms
live for genuine (non-deploy-pending) cases.

## Findings

### Mechanism 1: How `deploy_pending` gets set

`skill-base.sh:968-987` (`skill_postflight_update`), on `postflight_rc == 6` from
`update-task-status.sh`:

```
if [[ "$_postflight_rc" -eq 6 ]]; then
  echo "[deploy-check] deploy-pending: task ${task_number} postflight refused ..."
  jq '. + {deploy_pending: true, deploy_pending_reason: "postflight completion-deploy gate refused (exit 6): modified_files overlap agent-system/extensions/** and the deploy is stale"}' \
    "${_task_dir}/.return-meta.json" > "$_dp_tmp" && mv "$_dp_tmp" "${_task_dir}/.return-meta.json"
fi
```

This is the durable, cross-cycle, cross-invocation signal. Nothing in the codebase clears it once
set (`grep -rn deploy_pending` across `reconcile-task-status.sh` and `update-task-status.sh`
returns no writer that removes or flips the key back to `false`).

`orchestrate-cycle-postflight.sh:808-920` (the `implemented)` arm) captures
`skill_postflight_update`'s own return code (previously discarded — see the historical D6 residual
note in `batch-orchestration-guardrails.md:963-978`) and, on `postflight_rc -eq 6`, sets
`deploy_pending_refusal=true` and emits the exact message under scrutiny, at line 914:

```
"${notice_prefix} DEPLOY-PENDING: task ${task_number}'s postflight completion write was refused
by the completion-deploy gate (exit 6). The task remains at its current in-flight status;
convergence is deferred to the next cycle's Inter-Cycle Redeploy Checkpoint
(orchestrate-cycle-plan.sh) -- no manual action needed."
```

`deploy_pending_refusal` also prevents this cycle's verdict from claiming `ok`/"complete
implementation" (lines 1109-1113, 1259-1261) — the postflight layer is honest that state.json was
NOT updated. This part of the D6 residual closure (documented in
`batch-orchestration-guardrails.md`'s "Residual — the `/orchestrate` path (D6) — CLOSED"
subsection, lines ~963-978) is sound and should not be touched.

### Mechanism 2: The Inter-Cycle Redeploy Checkpoint's `deploy_pending_any` override

`orchestrate-cycle-plan.sh:791-820`. At the start of every cycle, before Move 2 issues any
dispatch, the checkpoint scans `mt_get_json '.task_numbers'` (every task in this batch/invocation)
and reads each one's own `.return-meta.json`:

```bash
for _dp_t in $(mt_get_json '.task_numbers' | jq -r '.[]'); do
  ...
  _dp_flag="$(jq -r '.deploy_pending // false' "$_dp_meta")"
  if [ "$_dp_flag" = "true" ]; then
    deploy_pending_any="true"
    deploy_pending_tasks_json="$(... + [$_dp_t])"
  fi
done
```

The trigger condition (line 843) is `{ [ "$matched_count" -gt 0 ] || [ "$deploy_pending_any" = "true" ]; } && [ "$dry_run" != "true" ]`.
`deploy-ledger-lib.sh`'s header comment confirms `deploy_pending` always forces the ledger decision
to `run` — "A `deploy_pending` batch task always forces `run`, so a skip can never starve the
postflight completion-deploy gate's backstop." So when this path fires, `deploy-headless.sh` +
`verify-deploy.sh` actually execute (subject to the existing (a)/(b)/(c) baseline-relative outcome
contract at lines 866-1020), and on the clean-success path the extension genuinely becomes fresh.

**Critically**: this entire block (lines ~716-1020) runs and completes, then at line 1030
`cycle_modified_files` is reset for the new cycle, and at **lines 1035-1059** — immediately
following, still inside the same cycle, before any dispatch derivation — `current_statuses[$t]` is
(re-)read fresh from `state.json` for every task in `task_args`. This is the "per-cycle status
refresh" `skills/skill-orchestrate/SKILL.md` describes Move 1 as performing. So the checkpoint's
deploy landing IS temporally positioned so that a same-cycle status write would be picked up by
this same cycle's routing decision — the gap is that nothing performs that write.

### Mechanism 3: `reconcile-task-status.sh` is invoked exactly once per invocation, not per-cycle

`skills/skill-orchestrate/SKILL.md:46-54`:

```
For each task in `task_numbers`, run the entry reconcile ONCE (never per-cycle -- a later cycle's
call for a still-eligible task is fresh, not a repeat):

for task_number in "${task_numbers[@]}"; do
  recon_out=$(bash .claude/scripts/reconcile-task-status.sh "$task_number" "$session_id" 2>&1 || true)
  ...
done
```

This runs **before Move 1's first cycle**, i.e. before the task in the observed scenario had even
been refused by the completion-deploy gate. There is no second call anywhere in the loop body
(`orchestrate-cycle-plan.sh`, `orchestrate-cycle-postflight.sh`) or in `SKILL.md`'s Move 2-4
description — confirmed by `grep -rn reconcile-task-status` across `scripts/` and `skills/`: every
other reference is either the tool's own definition, a by-hand recovery pointer in
`orchestrate-unwind-dispatch.sh`'s diagnostic text, or `skill-todo`'s unrelated dry-run probe.
`reconcile-task-status.sh` itself is fully idempotent and self-healing by design (its own header:
"Self-healing reconciliation for stuck tasks... when artifacts already exist on disk"), and its
`implementing -> completed` promotion path (triggered by an existing `summaries/*.md`) re-runs
`update-task-status.sh`, which re-runs the exact same completion-deploy gate — this is why it
produced "touched extension(s) verified fresh -- proceeding" and the correct promotion both times
the operator ran it by hand. **It is the right tool, wired to the wrong cadence.**

### Mechanism 4: The identical-dispatch guard, and why a deploy-pending re-derivation necessarily trips it

`orchestrate-cycle-plan.sh:2296-2347`. Immediately after `orchestrate-build-dispatch.sh` writes a
new dispatch file for task `$t`/phase `$g` this cycle, the guard sha256-hashes its content and
compares it to `mt_json.last_dispatch_hash[$t]` (persisted across cycles within this run's
in-memory `mt_state_file`, `specs/.orchestrator-multi-state-{session_id}.json`):

```bash
if [ -n "$_idh_hash" ] && [ "$_idh_hash" = "$_idh_prev_hash" ] && [ "$g" = "$_idh_prev_phase" ]; then
  _idh_streak=$(( $(mt_get ... .identical_dispatch_streak[$t] // 0) + 1 ))
else
  _idh_streak=1
fi
...
if [ "$_idh_streak" -ge 2 ]; then
  echo "... IDENTICAL DISPATCH HALT: ... halted for the rest of the run ..."
  rm -f "$dispatch_file"
  # restore pre-dispatch status.json fields, release task lock, record identical_dispatch_halted
  continue
fi
```

Since a task's plan file, phase-heading state, and description do not change between the refused
cycle and the checkpoint-deploy cycle, `orchestrate-build-dispatch.sh`'s output for the same
`(task, phase)` pair is byte-identical both times **by construction** — this is not evidence of
churn, it is the direct, deterministic consequence of re-deriving an `implement` dispatch from
unchanged inputs. Streak reaches 1 on the cycle that produced the refused dispatch, then 2 on the
very next cycle that re-derives it (the checkpoint-deploy cycle, per the observed timeline), and
the halt fires **before** the re-dispatch is ever sent — so the agent never gets the chance to run
again and (this time, post-deploy) actually succeed.

No existing test (`test-orchestrate-cycle-plan.sh` Group 27/28, confirmed via `grep`) exercises
any interaction with `deploy_pending`; the guard's own test coverage is deliberately narrow and
correct for the general case, with no awareness of this marker at all today.

### Mechanism 5: The completion-deploy gate itself is a correct, unrelated backstop

`update-task-status.sh:530-659`. `DEPLOY_CHECK_ANY_STALE` (provably stale) refuses with exit 6 and
the exact message quoted in the dispatch context; `DEPLOY_CHECK_ANY_CANNOTVERIFY` (ambiguous)
passes through with a distinct inconclusive notice; the no-overlap / missing-library / empty-
`modified_files` cases all pass through too (fail-safe toward "don't block"). This gate's
`exit 6` refusal itself is explicitly out of scope for weakening per the dispatch's constraints,
and this research did not find any reason it needs to change — the defect is entirely in what
happens (or fails to happen) *after* the refusal, not in the refusal's own correctness.

### Documentation already claims this residual "CLOSED" — it is not, in composition with the guard

`context/patterns/batch-orchestration-guardrails.md`'s "### The Postflight Completion-Deploy Gate"
section, subsection "**Residual — the `/orchestrate` path (D6) — CLOSED**" (lines ~963-978),
describes exactly the two changes analyzed above (postflight rc capture + honest verdict; the
`deploy_pending_any` checkpoint-trigger widening) and declares the `/orchestrate` gap closed. That
claim predates (or did not account for) the identical-dispatch guard's own addition/interaction —
the guard trips specifically in a scenario this "CLOSED" section does not model (a re-derived,
byte-identical dispatch on the very next cycle after the widened checkpoint fires). Whatever fix
lands for task 266 should also correct or qualify this "CLOSED" claim so the documentation does not
continue asserting a guarantee the composed system does not currently provide.

## Points to Settle — Analysis and Recommendation (non-binding; for the planning phase)

### 1. Suppress the guard entirely for deploy-pending tasks, or merely don't increment the streak?

**Recommendation: don't increment (freeze) the streak, never fully suppress the guard.**

These are materially different in scope:
- **Full suppression** (skip the entire identical-dispatch check when
  `deploy_pending == true`) disables a real safety net for exactly this task for as long as the
  marker stays set — and per the related finding above, nothing currently clears the marker, so a
  task that (for some unrelated reason) genuinely stalls on repeated identical dispatches AFTER
  its deploy-pending episode resolved would never again be caught by this guard, because the
  now-stale `deploy_pending: true` marker is still sitting in its `.return-meta.json`.
- **Freeze-the-streak** (compute the hash and detect equality as today, but do not increment
  `identical_dispatch_streak[$t]` — leave it at its current value, or reset it to 1 — when this
  task's `.return-meta.json` carries `deploy_pending: true` at hash time) preserves the guard's
  ability to catch genuine, unrelated non-convergence for the same task later, while not charging
  the one deterministic, explainable re-derivation caused by the deploy-gate composition against
  it. Combined with the primary fix (in-loop reconcile immediately consuming the deploy-pending
  state), this condition should be rare in practice — a defense-in-depth backstop, not the primary
  mechanism.

Whichever is chosen, the recommendation is to read the flag from the **task's own**
`.return-meta.json` at the exact point the hash is computed (`orchestrate-cycle-plan.sh:2302`),
not from a batch-wide `deploy_pending_any`, so a sibling task's unrelated deploy-pending state
never masks this task's own genuine churn.

### 2. Re-postflight the deploy-pending task directly after the checkpoint's deploy lands, rather than re-dispatching at all?

**Recommendation: yes — this is the primary fix (see Executive Summary).** The work is already
done and committed (`implemented` was the reported `dispatch_status`, the plan's phases were
already verified complete by `skill_gate_completion_claim` in the SAME cycle that got refused —
`orchestrate-cycle-postflight.sh:889-915`). A fresh `implement` dispatch after a deploy-pending
refusal is not "continuing unfinished work"; it is asking an agent to redo (or worse, silently
no-op through) work already verified complete, purely to retry a status write that
`reconcile-task-status.sh` can already retry directly and far more cheaply. This is also the only
one of the four options that removes the *waste* (an unnecessary agent dispatch), not just the
halt — it converges in the very next cycle rather than the cycle after that, and it makes the
identical-dispatch question moot for the success path since no second `implement` dispatch is ever
derived.

### 3. Automatic reconcile pass over the tasks the checkpoint's deploy just unblocked?

**Recommendation: yes — this is the concrete mechanism for point 2.**
`reconcile-task-status.sh` already performs exactly the right check and got the right answer both
times in the observed incident; per its own contract, calling it repeatedly is safe (self-healing,
idempotent — a task already `completed` or not eligible is simply a no-op). The wiring point is
narrow: iterate `deploy_pending_tasks_json` (already computed at
`orchestrate-cycle-plan.sh:791-820`) and call `reconcile-task-status.sh "$t" "$session_id"` (live)
**only on the checkpoint's own clean-success path** — i.e. inside the branch(es) that already
announce `"REDEPLOY CHECKPOINT: deploy-headless.sh succeeded; verify-deploy.sh clean."` (line 912)
or the equivalent pre-existing-findings-but-reattempted success path (the (c) branch in the
(a)/(b)/(c) contract) — never on branch (a) (deploy itself failed) or branch (b) (new findings),
where the extension is not actually verified fresh and reconcile would correctly no-op or (worse)
be called when it is not yet meaningful to. Placement: after the checkpoint block, before line
1035's status refresh, so the SAME cycle's `current_statuses[$t]` reflects the promotion and
`is_terminal_status()` (line 1339) naturally excludes the task from any further routing this
cycle — no new bespoke skip logic needed at the triage layer.

### 4. Ordering: deploy before the completion write is attempted, when `modified_files` are already known to overlap `agent-system/extensions/**`?

This is a plausible alternate/complementary optimization (move the redeploy earlier, before
`update-task-status.sh`'s own exit-6 refusal ever fires, for a batch task whose own
`modified_files` are already known post-implementation-dispatch to overlap the source store) — but
it does **not by itself** resolve the identical-dispatch composition defect, because it does not
change what happens on a run where the deploy genuinely could not have been anticipated before the
refusal (e.g. a `general`-typed task incidentally touching `agent-system/extensions/**`, or a task
whose overlap is only discovered at the postflight gate itself, which is the gate's whole reason
for existing as an unconditional backstop rather than a pre-dispatch-only check). It also
reintroduces exactly the concurrency hazard the current design deliberately avoids: per-task
postflight runs inside a **parallel** batch dispatch (`SKILL.md`'s Move 2 issues every row's Agent
call in one message), so firing a deploy speculatively "before the completion write is attempted"
from inside per-task postflight would race the fail-open `specs/.deploy-lock` mutex against a
sibling task's still-in-flight dispatch — the exact hazard `batch-orchestration-guardrails.md`'s
Concurrency Posture paragraph names as the reason the redeploy trigger lives ONLY at the two
already-serialized sites (single-task `command-gate-out.sh`, and the batch checkpoint boundary).
**Recommendation: out of scope for this defect's fix; worth a separate follow-up task if pursued,**
since it is an optimization on the number of cycles-to-convergence in the general case, not a fix
for the specific guard interaction task 266 characterizes. The primary fix (point 3 above) already
gets convergence within the checkpoint's own cycle — one cycle faster than "deploy on the cycle
after the refusal, converge on the cycle after that," which is most of the benefit this ordering
change would have offered, without the concurrency cost.

### 5. Correct or downgrade the "no manual action needed" message?

**Recommendation: correct it — a valid, low-risk, non-hostage partial fix**, as the dispatch itself
suggests. Confirmed via `grep -rn "no manual action needed"` that the string appears exactly once
(`orchestrate-cycle-postflight.sh:914`) and no test (`test-orchestrate-cycle-postflight.sh`) pins
that trailing clause specifically (only the `"DEPLOY-PENDING: task ..."` prefix is asserted at
lines 1845/1891), so correcting the tail carries negligible test-update risk.

**Quoted before text** (verbatim, `orchestrate-cycle-postflight.sh:914`):
> `DEPLOY-PENDING: task ${task_number}'s postflight completion write was refused by the
> completion-deploy gate (exit 6). The task remains at its current in-flight status; convergence is
> deferred to the next cycle's Inter-Cycle Redeploy Checkpoint (orchestrate-cycle-plan.sh) -- no
> manual action needed.`

**Suggested after text** (illustrative, not a plan commitment — exact wording is a planning-phase
decision, especially once it's known whether the primary fix lands): something in the shape of
*"...convergence is deferred to the next cycle's Inter-Cycle Redeploy Checkpoint
(orchestrate-cycle-plan.sh), which also reconciles this task's status once its deploy lands -- no
manual action needed."* if the primary fix (point 3) lands, since it would then be true; or, if
only the guard-freeze backstop (point 1) lands without the reconcile wiring, something conditional
like *"...no manual action needed unless a subsequent cycle halts this task on the identical-
dispatch guard, in which case re-invoke /orchestrate once the deploy has landed."* The verification
requirement in the dispatch (item 4: "Whatever message the refusal emits is TRUE of the resulting
behavior") should gate the exact final wording against whichever structural fix is actually
implemented, not the other way around.

## Decisions

- **Terminology**: this report uses "deploy-pending task" to mean a task whose own
  `.return-meta.json` carries `deploy_pending: true` (the durable, per-task marker), and
  "checkpoint" unqualified to mean the Inter-Cycle Redeploy Checkpoint
  (`orchestrate-cycle-plan.sh`'s per-cycle block at lines ~716-1020), consistent with existing
  in-repo usage in `batch-orchestration-guardrails.md`.
- No code was modified during this research pass, per the dispatch's phase (research only) and its
  explicit prohibition on touching tasks 260-264 or weakening either gate.

## Risks & Mitigations

- **Risk**: wiring an automatic reconcile call inside `orchestrate-cycle-plan.sh` could itself
  introduce a new concurrency hazard if placed incorrectly (e.g. before the checkpoint's own
  serialized deploy, or on a cycle where a sibling task's dispatch is already in flight).
  **Mitigation**: the checkpoint block already runs at the one point in the loop `SKILL.md`
  documents as having "no dispatch in flight" (quoted directly from
  `batch-orchestration-guardrails.md`'s Concurrency Posture paragraph); placing the reconcile call
  inside that same already-serialized window, strictly after the deploy's own success is confirmed
  and strictly before Move 2 issues any dispatch, inherits that same safety property rather than
  introducing a new one.
- **Risk**: freezing the streak counter (point 1) could be implemented in a way that masks genuine
  churn if the `deploy_pending` check is read from the wrong scope (batch-wide instead of
  per-task). **Mitigation**: named explicitly above — read strictly from the task's own
  `.return-meta.json`, not `deploy_pending_any`.
- **Risk**: the uncleared `deploy_pending` marker (related finding) could cause a *later*,
  unrelated `/orchestrate` invocation reusing the same task number (unlikely but not impossible
  given task-number reuse after vault operations — see `state-management.md`) to spuriously widen
  the checkpoint trigger. **Mitigation**: out of this task's four named points to settle; flagged
  for the planning phase to decide whether to also clear `deploy_pending` on a successful
  `reconcile-task-status.sh` promotion or a successful ordinary postflight completion, as a
  belt-and-suspenders companion to whichever primary fix is chosen.

## Context Extension Recommendations

- **Topic**: Inter-Cycle Redeploy Checkpoint x identical-dispatch guard interaction.
- **Gap**: `batch-orchestration-guardrails.md`'s "CLOSED" claim for the D6 residual does not
  mention or account for the identical-dispatch guard at all — a reader following that section
  alone would reasonably believe the `/orchestrate` path fully converges today, which the
  observed-twice defect in this task's dispatch context disproves.
- **Recommendation**: once task 266's fix lands, update that "CLOSED" subsection (or add a
  cross-reference to wherever the fix is documented) so the two mechanisms' composition is
  documented together rather than each described as independently correct with no stated relationship.

## Appendix

### Search queries / exploration used

- `jq -r '.extensions.core.source_dir'` on `.claude-extensions.json` to resolve the source-store
  root before editing anything.
- `grep -rn "deploy_pending\b"` across the source store to enumerate every reader/writer of the
  marker.
- `grep -n "exit 6\|stale relative to\|no manual action"` in `orchestrate-cycle-postflight.sh`.
- `grep -n "deploy-check\|verified fresh\|stale relative to"` across `scripts/` to locate the
  completion-deploy gate's exact implementation in `update-task-status.sh`.
- Direct reads of `orchestrate-cycle-plan.sh` around the checkpoint block (lines ~716-1020), the
  status-refresh block (~1030-1059), and the identical-dispatch guard (~2296-2347).
- `grep -n "reconcile-task-status"` across `scripts/` and `skills/` to establish the single
  entry-only call site in `SKILL.md`.
- `grep -n "### The Postflight Completion-Deploy Gate\|### The Inter-Cycle Redeploy Checkpoint"` in
  `batch-orchestration-guardrails.md`, then read both subsections in full.
- `grep -n "IDENTICAL DISPATCH\|identical_dispatch"` in `test-orchestrate-cycle-plan.sh` to confirm
  existing test coverage (Group 27/28) has no deploy_pending awareness.

### References

- `agent-system/extensions/core/scripts/update-task-status.sh:530-659` — completion-deploy gate,
  exit 6.
- `agent-system/extensions/core/scripts/skill-base.sh:968-987` — `deploy_pending` marker write.
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh:808-920` —
  `deploy_pending_refusal` handling and the message under scrutiny (line 914).
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh:791-1020` — Inter-Cycle Redeploy
  Checkpoint, `deploy_pending_any` computation and widened trigger.
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh:1030-1059` — cycle-local status
  refresh, immediately following the checkpoint.
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh:1337-1342` —
  `is_terminal_status()`.
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh:2296-2347` — identical-dispatch
  guard ("Fix 2").
- `agent-system/extensions/core/scripts/reconcile-task-status.sh:1-70` — self-healing contract.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md:46-120` — entry-reconcile-once
  contract, Move 1 description.
- `agent-system/extensions/core/scripts/lib/deploy-ledger-lib.sh:1-35` — `deploy_pending` always
  forces `run`.
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md:882-995` — The
  Postflight Completion-Deploy Gate, including the "D6 — CLOSED" subsection.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh:3525-3749` — Group
  27/28, existing identical-dispatch guard test coverage.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh:1762-1894` —
  existing `deploy_pending` marker and DEPLOY-PENDING notice test coverage.
