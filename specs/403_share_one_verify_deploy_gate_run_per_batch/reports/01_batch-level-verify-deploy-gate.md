# Research Report: Task #403

**Task**: 403 - Share one verify deploy gate run per batch
**Started**: 2026-10-14T21:34:00Z
**Completed**: 2026-10-14T21:40:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/core source store: scripts, context/formats,
context/patterns, context/standards, skills, agents)
**Artifacts**: - specs/403_share_one_verify_deploy_gate_run_per_batch/reports/01_batch-level-verify-deploy-gate.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The repository already has two of the three mechanisms this task needs, both proven in
  production, but built for a *different* purpose than the one this task needs them for; the gap
  is wiring, not invention.
- `verify-deploy.sh --only-gate N[,M,...]` (23 gates) already lets a caller run a cheap subset
  instead of the full battery, and `plan-format.md`'s `## Verification Tiers` section already
  defines `local`/`interface` as cheaper per-phase tiers — the mechanical pieces for "fall back to
  a cheaper tier" exist today; only the *final-phase* mandate forces every plan's last phase to
  `full`.
- `scripts/lib/deploy-baseline-lib.sh` already implements a confirmed, batch-scale, identity-based
  (not count-based) attribution pipeline — confirmation (drop flaky findings via a re-run) then
  attribution (match a finding's named identifier against a set of modified files) — built for
  the orchestrator's own Inter-Cycle Redeploy Checkpoint. This is the exact shape of machinery
  task 403's "how do failures get attributed back to a task's `file_scope`" open question needs,
  reusable rather than reinvented.
- The one piece that does **not** exist today is a shared, once-per-invocation, post-dispatch
  stage that runs the full gate and distributes its result across the batch's tasks. `skill-
  orchestrate`'s own loop already has the right seam for it: Move 4 (loop exit) / Move 5
  (Conclusion, "runs exactly once per invocation ... after Move 4 finalizes") is the established,
  documented precedent shape for a once-per-invocation, post-dispatch engine stage.
- A 2026-era prior task already measured and accepted a closely related trade-off (deferring
  Gate 8 in the *redeploy checkpoint*, not the *per-task plan gate*, to `--skip-slow`) and
  explicitly recorded a sibling-task rejection: single-capture Gate-8 sharing between the
  checkpoint's own pre/post pair was REJECTED because ~41 of ~105 suites resolve the DEPLOYED
  (not source-store) copy of their subject-under-test, so a pre-redeploy capture and a
  post-redeploy capture are provably NOT interchangeable for *that* purpose. That finding does
  not block task 403's design (which shares one capture across sibling *tasks* within the same
  already-deployed tree, not across a deploy boundary), but it is a directly relevant landmine to
  avoid re-triggering, and is the reason this report calls it out explicitly rather than silently
  assuming "share a capture" is always safe.
- Recommended architecture: (1) keep the per-task plan's own final-phase tier declaration
  unchanged by default (so standalone `/plan N` + `/implement N` usage is byte-for-byte
  unaffected); (2) let **dispatch-time batch awareness** — the same `concurrent_siblings`
  Territory data this very dispatch file already carries — override the final-implement-phase
  dispatch's effective obligation when and only when the task is actually being dispatched inside
  a multi-task `/orchestrate` batch; (3) add one new once-per-invocation stage, sited at Move 4
  (after the loop's last cycle, before/alongside Move 5's Conclusion), that runs the full gate
  once and attributes findings to tasks via `deploy-baseline-lib.sh`'s existing (or a lightly
  extended) attribution functions against each task's own `modified_files`/`file_scope`.

## Context & Scope

Task 403 was filed from a live observation during a 7-task `/orchestrate` batch: every plan's
final phase independently declared `**Verification Tier**: full`, so four concurrently-dispatched
implement phases each launched the complete ~104-123-suite `run-all.sh` battery via
`verify-deploy.sh`, producing load average 39.91 on 24 cores, 18 concurrent gate processes,
literally duplicated suites in flight, individual runs stretching 10-14+ minutes, a destructive
`pkill -f "run-all.sh"` by one agent that killed sibling sessions' runs, and two tasks closing
their final phase `[COMPLETED WITH EXCLUSIONS]` because sibling in-flight edits made the gate
noisy under concurrency.

This research scoped three open questions named in the task description:

1. Whether a single-task invocation keeps today's behavior unchanged.
2. How a shared run's failures get attributed back to the responsible task's `file_scope`.
3. Whether the plan-format `full` tier criterion wording needs a batch-aware variant.

It did not attempt to write code or a plan — that is `/plan 403`'s job, consuming this report.

## Findings

### Codebase Patterns

**1. The `full` tier mandate is unconditional today, and is enforced in two places, neither
mechanically strict.** `context/formats/plan-format.md`'s `## Verification Tiers` section states
a "Non-negotiable invariant": "The full gate set still runs before a phase closes and before a
task completes, unchanged... A phase declaring full names `bash .claude/scripts/verify-deploy.sh`
— or the complete set of gates it aggregates — in its own verification criteria." The final
phase — defined as the plan's highest-numbered phase, a terminal node transitively depended-on by
every other phase — "MUST depend... on every other phase," and "the final phase itself declares
`**Verification Tier**: full`... and carries no `**Tier Justification**:` line (the field is
conditional, omitted on the final phase, not merely optional there)." `agents/planner-agent.md`
(lines 403-410) repeats this as its own self-check before the plan is accepted. Enforcement of
the *field's presence* is `--strict`-mode-only and advisory by default
(`plan-format.md`'s "Enforcement level" subsection); enforcement of whether the final phase
*actually invoked* the full gate is explicitly named as "a separate, not-yet-built companion
check... a named future item, not yet built." This matters: the final-phase `full` declaration is
a textual/planning-time convention honored by the planner and the implementing agent, not a
hard gate today — which is exactly the leverage point a batch-aware variant can use without
fighting a mechanical enforcer.

**2. `verify-deploy.sh --only-gate` and Gate 8's own `--skip-slow` already separate "the full
battery" from "a cheap subset," and this separation is the one `plan-format.md` already tells a
non-final phase to use.** `verify-deploy.sh` runs 23 numbered gates; `--only-gate N[,M,...]`
restricts to named gates (gate0 argument validation is never filterable). Gate 8 is specifically
`scripts/tests/run-all.sh`, the ~105-123-suite shell battery, and is the dominant cost: measured
at 14m1.5s sequential / 6m47.4s under `--jobs auto` on a heavily loaded host, and separately
measured at 507.9s/211.9s (sequential/`--jobs 4`) on a quiet host (`context/standards/shell-
script-testing.md`). `plan-format.md`'s existing non-final-tier guidance already names two
narrowing mechanisms: a Gate-8 suite subset via `run-all.sh --only SUITE[,...]` (resolved from a
touched path by `scripts/lib/suite-selection-lib.sh`), and a gate subset via `verify-deploy.sh
--only-gate N[,M,...]`. Both already exist and are already load-bearing for `local`/`interface`
non-final phases. They are not sufficient by themselves for task 403's problem — they narrow
*what one run checks*, not *how many times the same full run happens across sibling tasks* — but
they are the vocabulary a batch-aware tier variant would extend, not replace.

**3. The attribution machinery task 403 needs already exists, built for a different gate.**
`scripts/lib/deploy-baseline-lib.sh` (sourced by both `orchestrate-cycle-plan.sh`'s Inter-Cycle
Redeploy Checkpoint and `command-gate-out.sh`'s single-task `rc==6` handler) exports:
  - `deploy_findings_snapshot` — runs `verify-deploy.sh --findings --quiet`, folds exit-2
    ("cannot run") into one synthesized `FINDING gate0 [SENTINEL]` line so the rest of the
    pipeline is a uniform line-level set difference.
  - `deploy_baseline_new_findings` — `comm -13` identity-based set difference (pre vs. post), not
    a count comparison; explicitly chosen because an exit-code-only or count-only comparison can
    mask a newly-introduced failure hiding inside an already-failing gate.
  - `deploy_baseline_confirm_new_findings` — a confirmation re-run that drops a candidate finding
    that does not reproduce (flaky under ambient load — observed concretely with
    `test-lake-build-guard.sh`).
  - `deploy_baseline_unattributable_findings` — the attribution filter: drops a confirmed finding
    only if it POSITIVELY names an identifier (`/`-bearing token, or `.sh`/`.md`/`.lua`/`.json`
    basename) that does not basename-match any entry in a supplied `modified_files` JSON array. A
    finding naming no identifier at all is NEVER dropped (fail-safe toward still-blocking).
  - `deploy_baseline_self_attributable_findings` — a per-task variant used to decide whether one
    specific deploy-pending task's OWN `modified_files` plausibly caused a pre-existing-looking
    finding, with its own documented "fail-safe toward NOT withholding" asymmetry (the opposite
    polarity from the batch-level filter, because it narrows an already-*proceeding* branch
    rather than an already-*blocking* one).

  This is precisely the two-step shape ("did it reproduce" + "does it name one of OUR files")
  task 403's open question 2 asks for, and it is already battle-tested at batch scale (it
  compares a whole batch's `cycle_modified_files` against one shared `verify-deploy.sh` snapshot).
  The gap for 403 is: today's library attributes findings to *the whole batch* (one pre/post pair,
  one `cycle_modified_files` set) for the purpose of deciding whether to defer the *next cycle's*
  dispatch — it does not yet attribute a finding to *which specific task within the batch* caused
  it. `deploy_baseline_self_attributable_findings` is the closer template for that per-task
  split (it already takes one task's own `modified_files` and answers "is this finding
  plausibly mine"), applied once per task in the batch against the one shared full-gate snapshot,
  rather than once against a single deploy-pending task as it is used today.

**4. A closely adjacent idea — sharing a *single* Gate-8 capture across the Inter-Cycle Redeploy
Checkpoint's own pre/post pair — was proposed, investigated, and REJECTED, and the reason is a
real landmine worth stating explicitly.** `context/patterns/batch-orchestration-guardrails.md`
records: "the candidate design would have captured Gate 8 ... exactly once ... and reused that
one capture identically as both the pre- and post-redeploy Gate-8 component." It was rejected
because 41 of 73 Gate-8 shell suites use a "deploy-tree-first / source-store-fallback" resolution
pattern — they prefer the DEPLOYED copy of their subject-under-test over the source-store copy,
falling back to source-store only when the deployed copy is absent — so a pre-redeploy run
exercises stale deployed copies and a post-redeploy run exercises fresh ones; sharing one capture
would make the checkpoint "categorically blind to any Gate-8-detectable regression a redeploy
itself introduces." **This does not block task 403**, because task 403's shared run is not
straddling a deploy boundary (deploy vs. not-deployed-yet) — it is one gate run against one
already-stable tree, shared across sibling *implementation tasks* that already committed their
own work before the shared gate fires. The two situations differ on the exact axis that made
sharing unsafe in the rejected case. It is cited here specifically so a future planner/implementer
does not have to rediscover it, and so the plan can state explicitly why the rejected precedent
does not transfer.

**5. The right once-per-invocation seam already exists in the loop, with a documented precedent
for "fires exactly once, after the loop's own finalization."** `skills/skill-orchestrate/SKILL.md`
documents Move 4 ("Branch" — loop-exit evaluation, consolidated-output emission, session-registry
release) and Move 5 ("Conclusion" — "Non-repeating; runs once, after Move 4 finalizes"). Move 5's
own contract document, `context/contracts/conclusion-stage.md`, is a worked precedent for
*exactly this shape of problem*: a once-per-invocation stage that aggregates evidence across every
task the invocation touched (there: per-task `issues.jsonl` logs via
`orchestrate-conclusion-aggregate.sh --aggregate`) and renders a batch-attributed result, gated
behind explicit approval for anything that *acts*. Task 403's shared gate is a different concern
(engine-level correctness verification, not issue-log review) and should NOT be folded into Move
5's existing body — that stage's "coexistence boundary" sections elsewhere in this codebase
establish a norm of keeping disjoint mechanisms disjoint even when they share a trigger point
(see the Conclusion Stage's own "Coexistence Boundary With the Skeleton-Plan Follow-Up Mechanism"
section) — but Move 5's existence proves the engine already supports adding a second,
independent once-per-invocation stage at the same seam without architectural novelty.

**6. `skill-orchestrate` explicitly frames a single task as "a batch of size one through the SAME
four-move loop, no separate single-task code path."** This directly informs open question 1. An
`/orchestrate N` invocation for one task already goes through Move 1-5 like any batch; a shared
end-of-invocation gate stage would, by construction, also fire for a size-1 "batch," changing
*where* the full gate runs (once, at the end, outside the implementing agent's own dispatch)
without changing *what* observably happens for that one task (one full-gate run, covering that
task's own modified files, before the invocation concludes). The behavior that is genuinely
"unchanged" is: a bare `/implement N` command (invoked directly, not via `/orchestrate`) never
enters this four-move loop at all — Move 4/5 do not exist on that path — so that standalone path
is unaffected by any Move-4/5-sited mechanism and must keep running the full gate inline at the
final phase, exactly as today, regardless of what changes for `/orchestrate`.

**7. The dispatch-time batch-awareness channel task 403 would need already exists and is already
populated per-dispatch.** This very dispatch file's own `## Territory` section carries a
`concurrent_siblings` array — other tasks scheduled for dispatch in the same `/orchestrate` cycle,
with their own `file_scope`. `orchestrate-build-dispatch.sh` already composes this per dispatch.
This means a final-implement-phase dispatch could be annotated, at dispatch-composition time
(not at plan-authoring time), with whether this task is part of a multi-task batch this cycle —
which is the information needed to decide whether THIS task's own final phase should run the full
gate itself (size-1, or a solo `/implement`) or defer to a shared batch-level run (multi-task
`/orchestrate`). This resolves the tension in open question 3: the plan text itself (authored once,
possibly re-used across a solo `/implement` and a later `/orchestrate` batch) does not need to
predict future batching — the *dispatch* can carry the override, the way `concurrent_siblings`
already does for territory awareness.

### External Resources

Not applicable — this is a pure agent-system architecture question internal to this repository;
no external library or documentation applies.

## Recommendations

1. **Leave the plan-authoring-time default unchanged.** Keep `plan-format.md`'s non-negotiable
   invariant and `planner-agent.md`'s self-check exactly as written: every plan's final phase
   still declares `**Verification Tier**: full` by default. This is what keeps a standalone
   `/plan N` -> `/implement N` flow (never entering the orchestrate loop) byte-for-byte unchanged,
   answering open question 1 for the one path where "unchanged" is actually required (no Move 4/5
   seam exists there to defer to).

2. **Add a batch-aware override at dispatch-composition time, not at plan-authoring time.**
   When `orchestrate-build-dispatch.sh` composes the final-implement-phase dispatch for a task
   that is part of a multi-task `/orchestrate` invocation this cycle (i.e. `concurrent_siblings`
   is non-empty, or more precisely: this is a multi-task batch, since the shared gate is useful
   even when siblings are staggered across cycles rather than co-dispatched in the same cycle),
   inject a directive analogous to the existing Territory block: "this phase's plan declares
   `full`; for THIS dispatch, verify only tier `local`/`interface` against the files this phase
   actually touched; the complete gate set runs once for the whole batch at the end of this
   `/orchestrate` invocation and its result will be attributed back to this task." This keeps the
   plan file itself reusable across both invocation styles and keeps the override visible and
   auditable at the one place (`.dispatch/N.md`) that already carries per-invocation context.

3. **Add one new, once-per-invocation engine stage at the Move 4/5 seam — not folded into Move
   5's existing Conclusion body — that runs the full gate once and attributes results.** Trigger
   condition: at least one `implement`-phase dispatch occurred this invocation (mirrors the
   existing "don't fire on every invocation regardless of relevance" rejected-alternative
   reasoning already recorded for the Inter-Cycle Redeploy Checkpoint). Scope: run
   `verify-deploy.sh` at full depth (no `--skip-slow`) exactly once, after the loop's last cycle,
   covering the union of every batch task's own `file_scope`/`modified_files` accumulated this
   invocation (the `mt_state_file` already tracks per-task `modified_files`-shaped data for the
   redeploy checkpoint's own `cycle_modified_files`; this is additive reuse, not a new tracking
   mechanism).

4. **Reuse, and lightly extend, `deploy-baseline-lib.sh` for attribution rather than building a
   new library.** `deploy_findings_snapshot` for the capture; `deploy_baseline_unattributable_
   findings`-style matching, applied once per task against that task's own `file_scope`/
   `modified_files` (not the whole-batch union, which is what today's single call already does
   for a different purpose), to answer "which task(s) does this finding plausibly belong to."
   A finding matching no task's files is a batch-level, unattributed finding — stays blocking for
   the batch as a whole, never silently dropped (mirrors the existing fail-safe-toward-
   attributable direction). Record the result the same way `verify_deploy_baseline_notices`
   already is: as a durable, rendered, batch-level record, never silently folded into one
   arbitrary task's own completion status.

5. **State explicitly, in the plan this report feeds, why the single-capture-sharing precedent
   (Finding 4) does not apply here.** This avoids both the error of reusing an idea a prior task
   already disproved for a structurally similar-sounding case, and the error of over-applying
   that rejection to a design that does not share its unsafe premise.

6. **Author the batch-aware Tier Justification variant as new vocabulary in `plan-format.md`,
   conditioned on the dispatch-time override (Recommendation 2), not as a new default.** A final
   phase dispatched under the batch override still declares `full` in the plan text (unchanged,
   per Recommendation 1) but its *dispatch-time* obligation is narrowed; document this as "the
   plan's declared tier is the ceiling the standalone path must meet; the batch override narrows
   what THIS dispatch must independently discharge, without editing the plan's own tier field" —
   this keeps `plan-format.md`'s "tiering governs granularity only, never weakens the final gate"
   invariant intact, since the full gate still runs, once, before the batch concludes.

## Decisions

- Scoped this research to the architecture question only; no code or plan changes were made.
- Confirmed, by reading `deploy-baseline-lib.sh`'s own header and the batch-orchestration-
  guardrails record of its single-capture-sharing rejection, that the rejected idea and task
  403's proposed design differ on the load-bearing axis (deploy-boundary straddling vs. not), so
  the rejection is cited as a landmine to avoid re-triggering, not as a blocker to this task.
- Resolved open question 1 (single-task invocation) by distinguishing "orchestrate size-1 batch"
  (goes through Move 1-5, in scope for the new stage) from "bare `/implement N`" (never enters
  the loop, must stay unaffected) — these are two different invocation paths, not one.
- Did not attempt to resolve exactly how `mt_state_file` should track per-task `file_scope` for
  attribution purposes at the engine-code level (field shape, key naming) — left to `/plan 403`,
  since the existing `cycle_modified_files`/`modified_files` tracking already present for the
  redeploy checkpoint is additive-reuse-shaped but its exact per-task indexing was not traced
  line-by-line in this research pass.

## Risks & Mitigations

- **Risk**: folding the new shared-gate stage into Move 5's existing Conclusion body, rather than
  as its own stage. **Mitigation**: Finding 5 and Recommendation 3 call this out explicitly;
  Move 5's own documented norm (the Skeleton-Plan Follow-Up coexistence boundary) is precedent for
  keeping disjoint once-per-invocation mechanisms disjoint even at the same trigger seam.
- **Risk**: re-deriving the single-capture-sharing idea task 403's attribution design might
  resemble, without re-checking whether the rejected premise (deploy-tree-first resolution in ~41
  suites) applies. **Mitigation**: Finding 4 states the distinguishing axis explicitly so a future
  plan/implementation does not need to re-investigate it from scratch.
- **Risk**: a shared full-gate run still pays real wall-clock cost once per invocation (an
  irreducible floor below which this task cannot go, since `plan-format.md`'s non-negotiable
  invariant is that "the full gate set still runs ... unchanged" in aggregate). **Mitigation**:
  this is the intended, accepted trade — the task's goal is "once per batch" not "never," and the
  measured baseline (14m1.5s sequential / 6m47.4s parallel for one full run) is the correct
  comparison point against today's N-per-batch cost, not against zero.
- **Risk**: attribution findings that name no identifier (the fail-safe-toward-blocking case in
  `deploy_baseline_unattributable_findings`) will, by design, remain unattributed to any single
  task and block the batch as a whole. **Mitigation**: this is the existing, deliberate,
  documented fail-safe posture of the library being reused, not a new gap this task introduces —
  flag it in the plan as expected behavior, not a defect to fix.

## Context Extension Recommendations

- **Topic**: Once-per-invocation engine stages beyond Move 5.
- **Gap**: `docs/architecture/orchestrate-state-machine.md` and `skill-orchestrate/SKILL.md`
  currently document Move 5 (Conclusion) as *the* once-per-invocation post-loop stage; there is no
  existing documented pattern name for "a second, independent once-per-invocation stage at the
  same seam." If task 403 (or a future task) adds one, the resulting pattern (trigger condition,
  sequencing relative to Move 4/5, tool-restriction surface) should get its own named subsection,
  parallel to `conclusion-stage.md`, rather than being folded as a footnote into an existing file.
- **Recommendation**: when this task reaches planning/implementation, add a short
  `context/patterns/` or `context/contracts/` file for the new stage, cross-referenced from
  `skill-orchestrate/SKILL.md`'s Move 4/5 boundary, mirroring `conclusion-stage.md`'s own
  structure (Overview, Evidence Base / Trigger, Executable Stage Body).

## Appendix

### Search queries / exploration used

- `find . -iname "*verify-deploy*"` in `agent-system/extensions/core`
- Read `scripts/verify-deploy.sh` header (gate selection, `--only-gate`, `--skip-slow`, findings
  mode)
- `grep -n "## Verification Tiers" -A 100/220 context/formats/plan-format.md`
- `grep -rn "Verification Tier"` across `docs/`, `rules/`, `agents/planner-agent.md`
- Read `agents/planner-agent.md` lines 395-420 (final-phase self-check)
- `grep -n "Inter-Cycle Redeploy Checkpoint" -A 60 context/patterns/batch-orchestration-
  guardrails.md`, then the "Confirmation and attribution filters" and "redundant-verify-deploy-
  passes task" subsections in the same file
- Read `scripts/lib/deploy-baseline-lib.sh` header (four exported functions)
- Read `skills/skill-orchestrate/SKILL.md` in full (Moves 1-5)
- Read `context/contracts/conclusion-stage.md` (Move 5 precedent shape)
- `grep -n "Suite runtime" -A 140 context/standards/shell-script-testing.md` (measured runtimes)
- `grep -n "COMPLETED WITH EXCLUSIONS" -A 15 context/standards/status-markers.md`
- `grep -n "rc==6|completion-deploy" scripts/command-gate-out.sh` (distinguishing the completion-
  deploy gate from the plan's own final-phase gate)

### Key file references

- `agent-system/extensions/core/context/formats/plan-format.md` (`## Verification Tiers`)
- `agent-system/extensions/core/agents/planner-agent.md` (lines 216-229, 324-336, 403-410)
- `agent-system/extensions/core/scripts/verify-deploy.sh` (`--only-gate`, `--skip-slow`,
  `--findings`)
- `agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh`
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` (`### The
  Inter-Cycle Redeploy Checkpoint`, `### The Same-Cycle Narrowing...`, the single-capture
  rejection subsection)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Moves 1-5)
- `agent-system/extensions/core/context/contracts/conclusion-stage.md`
- `agent-system/extensions/core/context/standards/shell-script-testing.md` (`## Suite runtime`)
- `agent-system/extensions/core/context/standards/status-markers.md` (`[COMPLETED WITH
  EXCLUSIONS]`)
