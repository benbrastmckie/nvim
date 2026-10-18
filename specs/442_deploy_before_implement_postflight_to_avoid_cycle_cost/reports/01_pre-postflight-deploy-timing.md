# Research Report: Task #442

**Task**: 442 - Evaluate deploying before implement-phase postflight so a stale deploy tree does
not cost a full orchestration cycle per task
**Started**: 2026-10-18T03:08:03Z
**Completed**: 2026-10-18T03:40:00Z
**Effort**: medium
**Dependencies**: 426
**Sources/Inputs**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (the completion-deploy
  gate consumer, `implemented)` arm)
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (the Inter-Cycle Redeploy
  Checkpoint, including its self-overwrite-hazard header comment)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Move 1-4 definitions)
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`'s "The
  Inter-Cycle Redeploy Checkpoint" and "The Postflight Completion-Deploy Gate" subsections
- `agent-system/extensions/core/scripts/tests/test-lint-deploy-caller-wrap.sh` (the two-caller
  structural invariant)
- `specs/440_fix_file_scope_glob_containment_predicate/issues.jsonl` and
  `specs/441_resolve_source_store_verification_invocation_contract/issues.jsonl` (the two
  originating issue-log entries)
**Artifacts**:
- `specs/442_deploy_before_implement_postflight_to_avoid_cycle_cost/reports/01_pre-postflight-deploy-timing.md`
  (this report)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The concurrency objection the existing documentation gives for never firing a redeploy from
  inside per-task postflight ("a sibling task's own still-in-flight dispatch") does not describe
  a hazard that exists at the **once-per-batch, ahead-of-the-sweep** moment this task asks about:
  `skill-orchestrate/SKILL.md` Move 3 explicitly runs only after every Move 2 Agent call has
  already returned, so there is no same-cycle, same-session dispatch in flight at that boundary —
  the identical cycle-synchronicity argument the guardrails document already uses to dismiss
  "Direction 3" for the Inter-Cycle Checkpoint applies here unchanged.
- The residual hazard that **does** survive at that boundary (the fail-open `deploy-lock` mutex
  racing a **different**, concurrently-running `/orchestrate` or multi-task `/implement` session)
  is not new: it is already accepted, at the same degree, by both of the two sanctioned trigger
  sites today (`orchestrate-cycle-plan.sh`'s checkpoint, `command-gate-out.sh`'s single-task
  path).
- So a once-per-batch pre-sweep deploy is **theoretically safe** by the same reasoning the system
  already relies on — but it is not a free change. It would make `orchestrate-cycle-postflight.sh`
  (or a new call site at the Move 2/Move 3 boundary) a **third genuine caller** of
  `deploy-headless.sh`, which `test-lint-deploy-caller-wrap.sh` mechanically asserts does not
  exist today, and it would need to re-thread the (a)/(b)/(c) baseline-relative branches, the
  confirmation/attribution filters, the `deployed_critical_paths` idempotence guard, and the
  durable ledger that the Inter-Cycle Checkpoint already owns — rather than reimplementing them —
  plus the same self-overwrite-hazard function-wrap mitigation if the call lives inside a
  continuing script.
- The cost the change would remove is already small and already fully self-resolving: the
  deploy/verify pass is paid once either way (and is already optimized via
  `--skip-verify`/`--skip-slow`/the durable ledger); the reconcile pass that promotes a
  deploy-pending task to `completed` already runs **inside** the following cycle's Move 1, before
  that cycle's own dispatch derivation, so no task is ever re-dispatched. What is actually
  "wasted" is one additional, mostly-empty Move 1→2→3→4 round trip (an empty `dispatch[]`, a
  no-op Move 3 loop, a Move 4 `all_terminal` stop) — not a repeated deploy, not a repeated
  implementation, not a repeated verify.
- **Recommendation**: do not add a third `deploy-headless.sh` trigger site. The existing
  one-cycle deferral is a correctly-scoped application of this system's own "defer, never fail"
  default, it already costs only a cheap extra loop iteration, and the mechanism it would be
  grafted onto has already needed several non-trivial hardening passes (the D6 closure, the
  identical-dispatch-guard interaction, the self-attribution screen, the marker lifecycle) to
  reach its current correctness bar at just its existing two call sites. Record this finding in
  `batch-orchestration-guardrails.md` per the dispatch's own fallback instruction, with the
  `deployed_critical_paths` plus the Move 2/Move 3 boundary caveat so a later pass does not
  re-propose the same change without re-deriving why it was not taken.

## Context & Scope

Both task 440 and task 441 (cited here because this report lives under `specs/**`, the
task-number exemption) completed their implement-phase work correctly, but each one's postflight
completion write was refused by the completion-deploy gate (`update-task-status.sh` exit 6)
because the deployed `.claude/` tree was stale relative to `agent-system/extensions/core/` at
that exact moment. Both refusals self-resolved, with no manual intervention, at the next cycle's
Inter-Cycle Redeploy Checkpoint. The orchestrate lead that spawned this task deliberately routed
it as an orchestrator-sequencing question (not a `fix_now` repository defect), asking: should the
orchestrator deploy earlier in the cycle — per task, or once per batch ahead of the postflight
sweep — so the refusal (and its one-cycle deferral) happens less often, without weakening the
gate's fail-closed posture in any way.

This report traces the actual mechanics of (1) `skill-orchestrate/SKILL.md`'s Move 1-4 structure,
(2) the completion-deploy gate inside `orchestrate-cycle-postflight.sh`, (3) the Inter-Cycle
Redeploy Checkpoint inside `orchestrate-cycle-plan.sh`, and (4) the structural invariant
(`test-lint-deploy-caller-wrap.sh`) that currently limits `deploy-headless.sh` to exactly two
callers — to determine whether a pre-postflight-sweep deploy is safe at the point in the cycle
the task names, and whether it is worth doing.

## Findings

### Codebase Patterns

**Move structure and the actual postflight timing.** `skill-orchestrate/SKILL.md` documents five
moves per `/orchestrate` invocation: Move 1 (`orchestrate-cycle-plan.sh` — status refresh,
eligibility, admission, the Inter-Cycle Redeploy Checkpoint, dispatch composition), Move 2
(Dispatch — every `dispatch[]`/`aux_dispatch[]` row's Agent call issued in **one message**,
genuinely simultaneous), Move 3 (Postflight — "**After ALL Agent calls from Move 2 complete**
(never interleaved with dispatch), run this once per `dispatch[]` row", a sequential `while`
loop calling `orchestrate-cycle-postflight.sh` once per task), and Move 4 (Branch/loop-or-finish).
The multi-task `/implement` command mirrors this: `commands/implement.md` Step 4 "is already
serial (it runs once, after all of Step 3's parallel dispatches have returned)."

This matters directly: by the time **any** call to `orchestrate-cycle-postflight.sh` happens in a
given cycle, every sibling task dispatched that same cycle has already returned, and (per Move
2's own per-task scoped commit, which "lands, unconditionally, BEFORE the Move 1 redeploy
checkpoint for that same cycle ever evaluates") every sibling's commit has already landed too. The
"Direction 3" discussion in `batch-orchestration-guardrails.md` ("Considered and found ALREADY
SATISFIED — redeploy-boundary serialization") already establishes this same fact for the
Inter-Cycle Checkpoint's own position at the *start* of the *next* cycle: "Dispatch is
CYCLE-SYNCHRONOUS by construction... There is no cross-cycle concurrency for the checkpoint to
race against: by the time a redeploy fires, every sibling dispatched in that cycle has already
returned and committed." The Move 2/Move 3 boundary **within the same cycle** satisfies the
identical precondition — it is, if anything, a tighter serialization point than the start of the
next cycle, since it sits immediately after the same guarantee the Direction-3 analysis already
relies on.

**The stated concurrency objection, read precisely.** `batch-orchestration-guardrails.md`'s
"Concurrency posture" paragraph (under "The Postflight Completion-Deploy Gate") gives the reason
the redeploy "still lives at the checkpoint boundary, never in per-task postflight": "Move 2
issues every `dispatch[]` row's Agent call in ONE message (genuinely simultaneous); a redeploy
fired from inside `orchestrate-cycle-postflight.sh` would therefore race the fail-open
`specs/.deploy-lock` mutex against a sibling task's own still-in-flight dispatch." Taken literally
against the **same cycle's own** siblings, this does not hold, for the reason above: Move 3 never
runs while a same-cycle sibling's dispatch is still in flight — that is precisely what "After ALL
Agent calls from Move 2 complete (never interleaved with dispatch)" rules out by construction. The
hazard that genuinely survives is **cross-session**: this repository routinely runs multiple
concurrent `/orchestrate` (or multi-task `/implement`) sessions against the same working tree (the
active-agent roster visible in this very session — multiple independent research/plan/implement
agents running in parallel across unrelated tasks — is itself a live instance of that pattern).
`deploy-headless.sh`'s own locking is explicitly "a fail-open `specs/.deploy-lock/` mutex," so a
redeploy fired from **any** trigger point can in principle race a **different** session's
in-flight Move 2 dispatch. Critically, this exact residual risk already exists, at the same
degree, at both of today's two sanctioned call sites: the Inter-Cycle Checkpoint (which fires at
the start of *this* session's Move 1, with no guarantee about what a different session's Move 2
is doing at that instant) and `command-gate-out.sh`'s single-task path (licensed on "no
concurrency" meaning only *this* task's own completion, not on any claim about other sessions). A
once-per-batch pre-sweep deploy would not introduce a new category of hazard beyond what the
system already accepts — it would only add a third occurrence of a risk the system has already
decided, twice, is acceptable.

**The structural cost of adding a third trigger site.** `scripts/tests/test-lint-deploy-caller-wrap.sh`
mechanically classifies every textual reference to `deploy-headless.sh` across the extension tree
and asserts: "classification: exactly the two known genuine caller sites
(`orchestrate-cycle-plan.sh`, `command-gate-out.sh`) were found" — a hard `fail` otherwise (not a
silent pass). The test's own comment states this is "a REGRESSION guard, not a hardcoded
allowlist that ignores new callers," so a new genuine caller is still discovered and
structurally checked (each caller must wrap everything from its deploy call through true EOF
inside one function, invoked as the file's last statement — the fix for the self-overwrite hazard
documented at the top of `orchestrate-cycle-plan.sh`), but the count assertion itself would need
deliberate updating. This is not a blocker, but it is a concrete, non-zero implementation cost
that a once-per-batch pre-sweep deploy would incur, and it is exactly the kind of structural
invariant this document's own hard constraint (preserve the fail-closed posture; do not weaken
the gate) is designed to protect by making any new caller visible rather than silent.

**What the current one-cycle deferral actually costs.** `batch-orchestration-guardrails.md`'s "D6
… CLOSED" discussion states plainly that the checkpoint's post-deploy reconcile pass "fires on
exactly the checkpoint's three clean-success branches... directly inside the Inter-Cycle Redeploy
Checkpoint's own already-serialized window, immediately after the checkpoint's deploy is confirmed
to have landed and BEFORE the cycle's own status refresh and dispatch derivation run" — so "by the
time the cycle's status refresh reads `current_statuses[$t]`, a deploy-unblocked task has already
been promoted to `completed`... so no second `implement` dispatch is ever derived for it at all."
Combined with the identical-dispatch guard's streak-freeze backstop (added for the residual paths
the reconcile pass cannot itself conclude), a deploy-pending task is never re-implemented and never
re-dispatched. The deploy/verify pass itself is already heavily optimized at this call site: the
`--skip-verify` opt-in ("this checkpoint's own `deploy-headless.sh` call: ~2m17s to ~8s on a
heavily-loaded measuring host") and the durable `deploy-ledger-lib.sh` hash/attributed skip rules
mean the deploy cost is paid once either way, not duplicated by deferral. What the deferral
actually spends is one additional, largely empty Move 1→2→3→4 round trip for the affected
task(s): Move 1 does the real (necessary) reconcile work, and Move 2/3/4 pass through with an
empty `dispatch[]` for those tasks. The two originating issue-log entries corroborate this —
both are logged at severity `costly`, not `blocking`, with `resolution: worked_around` — consistent
with a bounded, self-resolving cost rather than a correctness or wall-clock-dominant one.

**The established pattern this mechanism already follows.** `batch-orchestration-guardrails.md`'s
"Defer-Not-Fail: The Standing Default" section states this system's standing default response to
every admission-time (and, by direct analogy, completion-time) conflict is deferral, never a
harder failure mode: "admission conflicts are transient by construction — they clear once the
colliding or blocking task terminates." The completion-deploy gate's exit-6 refusal, followed by
automatic reconciliation at the next cycle boundary, is exactly this pattern applied to deploy
staleness rather than to task-to-task scheduling conflicts. Treating the existing one-cycle
deferral as a defect to engineer away, rather than as a correct instance of an already-endorsed
system-wide default, cuts against this document's own stated philosophy.

### External Resources

Not applicable — this is a pure codebase/architecture question with no external library or
framework dependency; no web research was performed.

## Decisions

- The literal "sibling task's own still-in-flight dispatch" concurrency objection in
  `batch-orchestration-guardrails.md`'s Concurrency posture paragraph does not, on inspection,
  describe a same-cycle, same-session hazard at the Move 2/Move 3 boundary — Move 3 is
  constructed to run strictly after every Move 2 dispatch has returned. The real residual
  hazard at that boundary is cross-session lock contention, which is already accepted at the
  two existing trigger sites.
- A once-per-batch, ahead-of-the-sweep deploy is therefore judged **theoretically safe** rather
  than structurally unsafe — this report does not reach the "deferral is structurally necessary
  for correctness" verdict the dispatch names as one valid outcome.
- It is nonetheless judged **not worth building**, because (a) it would require becoming a third
  mechanically-audited genuine caller of `deploy-headless.sh`, re-threading the existing
  baseline/ledger/confirmation-filter machinery rather than duplicating it, and re-verifying the
  self-overwrite-hazard wrap; and (b) the cost it would remove is already small, already bounded,
  and already fully self-resolving without operator intervention — one mostly-empty extra loop
  iteration, not a repeated deploy, verify, or implementation pass.
- This verdict is a cost/benefit judgment, not a safety verdict — the "document why the deferral
  is structurally necessary" framing the dispatch offers as a fallback is a close but not exact
  fit; this report recommends the plan/implement phases record the cost/benefit reasoning above
  (not a pure safety argument) in `batch-orchestration-guardrails.md`, since the dispatch itself
  asks for the reasoning to be recorded either way rather than left undocumented.

## Recommendations

- **No behavioral change.** Do not add a pre-postflight-sweep deploy trigger, per task or per
  batch. Leave the completion-deploy gate's exit 6 refusal and its recovery via the Inter-Cycle
  Redeploy Checkpoint exactly as they are today — this fully satisfies the hard constraint (the
  fail-closed posture is untouched, by construction, since nothing about the gate changes).
- **Document the finding** in `batch-orchestration-guardrails.md`, as a new subsection
  immediately following "The Postflight Completion-Deploy Gate" (or as a clearly-marked addition
  within it), covering: (a) the Move 2/Move 3 cycle-synchronicity fact that narrows the stated
  concurrency objection to a cross-session hazard rather than a same-cycle one; (b) the
  `test-lint-deploy-caller-wrap.sh` two-caller invariant as the concrete structural cost a third
  trigger site would incur; (c) the observation that the deferred cost is already bounded to one
  mostly-empty loop iteration, not a repeated deploy/verify/implementation pass; and (d) the
  explicit conclusion that this was evaluated and intentionally left unimplemented, so a later
  pass does not re-propose it without re-deriving this reasoning. A draft of this addition,
  written without task-number references or record-versioning language (since it will land under
  `agent-system/**`), follows in the Appendix for the plan/implement phases to adapt verbatim or
  near-verbatim.
- **No script changes** are recommended to `orchestrate-cycle-postflight.sh` or
  `orchestrate-cycle-plan.sh` beyond whatever doc-adjacent comment cross-references the
  implement/plan phases judge useful; the file_scope entries naming those two scripts can be
  satisfied by this documentation-only outcome plus the `batch-orchestration-guardrails.md` edit.

## Risks & Mitigations

- **Risk**: a later task re-discovers the same observation (two exit-6 refusals in one batch) and
  re-proposes the same change without reading this report. **Mitigation**: the recommended
  `batch-orchestration-guardrails.md` addition exists specifically to make this reasoning
  discoverable at the same subsection a future reader would naturally check first.
- **Risk**: if a future measurement shows the "extra loop iteration" cost is not actually small
  (e.g., cycle latency dominated by something other than script execution — orchestrator
  reasoning/context overhead between cycles), the cost/benefit balance in this report could shift.
  **Mitigation**: the documented addition should state the cost claim as "bounded to one
  additional loop iteration, not a repeated deploy/verify/implementation pass" rather than citing
  a specific wall-clock number this report did not itself measure, so it remains accurate even if
  per-cycle orchestration overhead changes.
- **Risk**: none to the fail-closed posture itself — this recommendation changes no gate logic,
  so there is no new risk surface on that axis.

## Context Extension Recommendations

- **Topic**: `orchestrate-cycle-plan.sh`'s own header comment.
- **Gap**: the header states "Everything from 'After all Agent tool calls complete' onward
  (per-task postflight, commits, the handoff/`.return-meta.json` read, and
  `cycle_modified_files` accumulation) is NOT this script's job — that is a separate,
  **not-yet-built** postflight composer." `orchestrate-cycle-postflight.sh` already exists and
  implements exactly that role (2412 lines, invoked at Move 3). This phrasing predates that
  script's construction and is now stale.
- **Recommendation**: a future, separately-scoped documentation pass should update that comment
  to name `orchestrate-cycle-postflight.sh` directly rather than describing it as unbuilt. Noted
  here as incidental to this research, not acted on — it is outside this task's own `file_scope`
  framing and not load-bearing for the recommendation above.

## Appendix

### Search queries / investigation steps used

- Resolved the source-store location for `core` via `.claude-extensions.json`'s
  `extensions.core.source_dir`, then read every cited script/doc from
  `agent-system/extensions/core/...` directly (never the deployed `.claude/` mirror).
- Read `orchestrate-cycle-postflight.sh`'s `implemented)` arm (around its exit-6 capture and
  `DEPLOY-PENDING` stderr message) and `orchestrate-cycle-plan.sh`'s Inter-Cycle Redeploy
  Checkpoint and self-overwrite-hazard header comment.
- Read `skill-orchestrate/SKILL.md` Move 1 through Move 4 in full to establish the exact
  same-cycle sequencing guarantee ("After ALL Agent calls from Move 2 complete... never
  interleaved with dispatch").
- Read `batch-orchestration-guardrails.md`'s "The Inter-Cycle Redeploy Checkpoint" and "The
  Postflight Completion-Deploy Gate" subsections in full (roughly 619-1290 of that file).
- Read `scripts/tests/test-lint-deploy-caller-wrap.sh` to confirm the exactly-two-callers
  structural assertion and its "regression guard, not hardcoded allowlist" framing.
- Cross-checked the two originating issue-log entries
  (`specs/440_fix_file_scope_glob_containment_predicate/issues.jsonl`,
  `specs/441_resolve_source_store_verification_invocation_contract/issues.jsonl`) for severity
  and resolution framing.

### Draft addition for `batch-orchestration-guardrails.md` (task-number-free, non-record-versioning)

> **Evaluated and intentionally not built: a pre-postflight-sweep deploy trigger.** A proposal to
> fire the redeploy once per batch, immediately after Move 2's dispatches return and before Move
> 3's per-task postflight sweep begins (rather than waiting for the following cycle's Inter-Cycle
> Checkpoint), was evaluated and deliberately left unimplemented. The stated concurrency objection
> above ("a sibling task's own still-in-flight dispatch") does not describe a hazard at that exact
> boundary: Move 3 runs only after every Move 2 Agent call has already returned, by the same
> cycle-synchronicity argument this document's own Direction-3 discussion already establishes for
> the Inter-Cycle Checkpoint's position at the start of the following cycle. The hazard that does
> survive there — a different, concurrently-running orchestration session racing the fail-open
> deploy-lock mutex — already exists, at the same degree, at both of today's two sanctioned
> trigger sites, so a once-per-batch pre-sweep deploy would not add a new category of risk.
>
> It was left unimplemented on cost/benefit grounds instead: it would make the chosen call site a
> third genuine caller of the deploy/regeneration script, which the structural lint guard
> (`scripts/tests/test-lint-deploy-caller-wrap.sh`) mechanically asserts does not exist today and
> would need to be deliberately widened, and it would require re-threading (not duplicating) the
> existing baseline-relative branches, confirmation/attribution filters, idempotence guard, and
> durable ledger onto the new call site, plus the same self-overwrite-hazard wrap discipline. The
> cost this would remove is already bounded and already fully self-resolving: the deploy/verify
> pass is paid once regardless of which boundary triggers it, and the post-deploy reconcile pass
> already promotes a deploy-pending task to completed before the following cycle's own dispatch
> derivation runs, so nothing is ever re-implemented or re-dispatched. What remains is one
> additional, largely empty cycle round trip — a cost judged smaller than the risk of adding a
> third trigger site to a mechanism that has already required several non-trivial correctness
> passes at just its existing two.
