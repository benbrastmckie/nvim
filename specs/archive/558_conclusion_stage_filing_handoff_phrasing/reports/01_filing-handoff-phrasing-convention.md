# Research Report: Task #558

**Task**: 558 - Document the convention that a task description must request a PROPOSAL PACKET,
never task FILING, from an autonomous dispatch
**Started**: 2026-11-17
**Completed**: 2026-11-17
**Effort**: small (documentation-only, single-site statement plus pointers)
**Dependencies**: None
**Sources/Inputs**: Codebase exploration (source store under
`agent-system/extensions/core/`), no web search needed
**Artifacts**: - This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The three candidate sites named in the dispatch were evaluated against what each surface's
  actual readers are. `docs/reference/standards/multi-task-creation-standard.md`'s Component 7
  ("User Confirmation") states the Foreground Requirement this convention protects, but neither
  `planner-agent.md`, `reviser-agent.md`, `spawn-agent.md`, nor `general-implementation-agent.md`
  — the agents that actually author task descriptions and plan phase text — reference that
  document today. `context/contracts/conclusion-stage.md` is, by contrast, exactly where the
  originating author was already looking (they were trying to hand off to "the conclusion
  stage" by name).
- **Recommendation**: state the convention once in `multi-task-creation-standard.md`, as a new
  subsection immediately following Component 7's existing Foreground Requirement paragraph, and
  add a short pointer-only note in `conclusion-stage.md`'s Overview (where channels (b)/(c) are
  already described as "never dispatched or executed by this stage"). This is the dispatch's
  explicitly-sanctioned "(a) composed with one of (b)/(c)" option, choosing (b) over (c) because
  (c) would require editing `orchestrate-build-dispatch.sh` plus its aux/unwind siblings to inject
  boilerplate into every dispatch regardless of whether that dispatch's own description carries
  the offending phrasing — fixing a symptom at the point of execution rather than the authoring
  surface, and at a maintenance cost the other two options don't carry.
- The "proposal packet" shape the convention should require is **not a new format**. It already
  exists: one `issue-record.sh` entry per candidate (carrying `suggested_channel: follow_up_task`
  or `agent_system`) plus a human-readable list in the dispatch's own report/plan/summary —
  exactly the shape `conclusion-stage.md`'s Steps 4b/4c already consume. No new packet
  specification should be written; only a pointer to this existing shape.
- The WHY the convention needs stating is two independently-measured facts, both already
  documented elsewhere and citable rather than re-derived: Component 7's Foreground Requirement
  (confirmation must run in the foreground skill layer, never inside a delegated background
  agent) and `docs/reference/standards/agent-frontmatter-standard.md`'s "Tool Withholding from
  Dispatched Subagents (Measured)" section (AskUserQuestion is categorically withheld from every
  `Agent`-tool dispatch, confirmed across five live configurations, independent of `tools:`
  grants).

## Context & Scope

This task documents a **phrasing convention**, not a new capability. The defect under study is
that a task description (or a plan's phase instructions, which is what the originating evidence
actually shows — see "Findings" below) can instruct an autonomous research/plan/implement
dispatch to itself file follow-up tasks. That instruction is unexecutable: the dispatch has no
reachable confirmation surface and no tool to perform the filing. The fix is documentation-only:
state, once, that a task description must ask for a proposal packet instead, and name why.

Scope boundaries carried over verbatim from the dispatch's NON-GOALS: no change to Component 7's
foreground requirement or any confirmation gate; no new capability for dispatched agents to file
tasks; no relaxation of the `AskUserQuestion` withholding; no change to the conclusion stage's
channel routing, filter predicate, or exactly-one-channel rule; no retroactive rewrite of existing
task descriptions carrying the offending phrasing.

## Findings

### Codebase Patterns

**Who actually authors the offending phrasing.** The verbatim evidence quoted in the dispatch
("The dispatch defers task filing to 'the conclusion stage'...") was logged at `phase: plan`,
`dispatch_seq: 2` — i.e. the problematic instruction originated in a **plan artifact's phase
text**, not necessarily (or only) in the `specs/state.json`/TODO.md task-description field. A
plan is authored by `planner-agent` or `reviser-agent`, and consumed by
`general-implementation-agent`. Checked all four of these agent files
(`agents/planner-agent.md`, `agents/reviser-agent.md`, `agents/spawn-agent.md`,
`agents/general-implementation-agent.md`) for any reference to
`multi-task-creation-standard.md` or "Component 7" — none exists. By contrast, every surface
that `multi-task-creation-standard.md` already lists as a reference implementation (`/task`,
`/meta`, `/fix-it`, `/review`, `meta-builder-agent`, `skill-fix-it`) *does* reference it. This is
the concrete version of the dispatch's own weigh-note for site (a): "a reader composing a task
description may not consult it" — confirmed, specifically for the plan-authoring and
implementation-executing agents, which are exactly the agents most likely to write or receive
"defer filing to the conclusion stage" phrasing.

**Where the originating author's attention already was.** The quoted evidence names "the
conclusion stage" specifically — the author was consciously trying to route the hand-off through
that mechanism and reasoned about it by that name. A short, pointed clarification placed in
`context/contracts/conclusion-stage.md`'s own Overview (which already states, for channels (b)
and (c): "never dispatched or executed by this stage ... no task creation") is the most direct
hook for catching exactly this failure mode, because it sits next to the sentence the author was
relying on when they wrote the offending phrase.

**The channel (b)/(c) mechanism already discharges the Component 7 gate, just not
synchronously.** Re-reading `conclusion-stage.md`'s Step 4b/4c closely: neither step dispatches
anything or creates a task directory. Both only append one `events-append.sh` line per
classified proposal to `specs/events.jsonl` and commit that file. The dispatch's own framing
("its Step 4b channel already routes agent-system change requests through a confirmed dispatch
to the task-creating agent") describes the *eventual* consumption path, not an immediate one:
`conclusion-stage.md`'s own Overview says this evidence is recorded "for a later, deliberate
consumer" and Step 4b/4c both say it is "consumed later, deliberately and in batches, by
`/distill --meta`" (this codebase's current command for that sub-mode is `/telemetry --meta`,
per `commands/telemetry.md`, which delegates to `meta-builder-agent` — a surface that *does*
implement the full Component 1-8 multi-task-creation standard, including Component 7's
foreground confirmation). So the chain is: dispatch records evidence (no confirmation needed,
nothing executes) -> conclusion stage aggregates and classifies it (still no task created) ->
a later, separate, deliberately-batched `/telemetry --meta` invocation performs the actual
Component 7-compliant confirmed creation. The convention under this task only needs to tell a
task/plan author to feed the front of this chain — the existing chain already resolves to a
foreground confirmation downstream.

**The proposal-packet shape already exists and needs no new specification.** Checked for an
existing "proposal packet" format: no file in the source store uses that phrase (`grep -rl
"proposal packet"` returns nothing). But the shape the originating workaround built — "a
reconciled proposal packet plus `issues.jsonl` `follow_up_task` entries" — maps exactly onto two
already-documented pieces:
1. `context/formats/issue-log.md`'s `suggested_channel` field (`fix_now` \| `follow_up_task` \|
   `agent_system`), explicitly a **hint**, never an auto-filing trigger (`context/formats/
   issue-log.md` and `conclusion-stage.md`'s "The Hint-Versus-Decision Rule").
2. `conclusion-stage.md`'s Steps 1-2 (`orchestrate-conclusion-aggregate.sh --aggregate`), which
   reads every touched task's `issues.jsonl`, groups by `class`, and classifies into channels (a)
   fix-now / (b) agent-system change / (c) follow-up task — with every proposal carrying
   `{task, entry_id}` citations per the Citation Requirement.

The "human-readable list in the dispatch's own report/plan/summary" half of the packet is simply
ordinary report/plan/summary prose — no new artifact type is needed. The convention's
deliverable is therefore a **pointer** to this existing shape (name the two things: "an
`issue-record.sh` entry per candidate, carrying a `suggested_channel`" and "a rendered list in
the dispatch's own artifact"), not a fresh packet-format specification.

**The skeleton-plan follow-up mechanism is a disjoint precedent, not a model to imitate.**
`conclusion-stage.md`'s "The Coexistence Boundary With the Skeleton-Plan Follow-Up Mechanism"
section documents a narrower, Lean-specific mechanism (`sorry_inventory[]` on a skeleton-plan
implement handoff, surfaced in the cycle's stderr report, recorded on
`skeleton_follow_ups[]`) that explicitly leaves filing to "the human... with `/task`" — i.e. it
already follows the "never auto-file" discipline this task's convention wants to generalize. It
is cited in the dispatch as a check against re-specifying something that already exists; it
does not need to be touched, extended, or pointed at from the new convention, because it is a
different consumer (the human, directly) of the same underlying principle, not an alternate
packet format.

**Why the instruction is categorically unexecutable (citable, not re-derived).** Two
already-measured facts jointly establish this, and the convention should cite both rather than
restate Component 7's text as if it were new:
1. `multi-task-creation-standard.md` Component 7, "Foreground Requirement": "Confirmation MUST
   execute in the foreground skill layer (not inside a delegated background agent).
   `AskUserQuestion` called from background agents (spawned via Task tool) does not reliably
   surface to users."
2. `docs/reference/standards/agent-frontmatter-standard.md`'s "Tool Withholding from Dispatched
   Subagents (Measured)" section: `AskUserQuestion` is categorically withheld from every
   `Agent`-tool dispatch of a named `subagent_type`, independent of `tools:`/`disallowedTools:`
   configuration — measured across five live dispatches and four distinct configurations
   (no-`tools:`-line inheritance, an explicit allowlist naming the tool, "All tools"
   registration, and a `fork` continuation). This is a stronger, mechanically-verified claim than
   Component 7's own "does not reliably surface" phrasing — the tool is not merely unreliable
   from a dispatch, it is unreachable.

A related, structurally similar precedent already exists for a different unreachable-confirmation
case: `context/standards/push-consent-relay.md` documents that a dispatched agent cannot call
`AskUserQuestion` to request push authorization either, and instead emits a `user_decision`
(`context/standards/user-decision-contract.md`) that the orchestrator relays at the next natural
batching point. That mechanism is **not** a fit for this task's problem (it is a single-task,
single-question relay for an irreversible-cost decision, not a cross-task, batched,
evidence-aggregating mechanism like the conclusion stage), and the dispatch's NON-GOALS already
rule out inventing any new capability — but it is useful supporting evidence that "agent cannot
reach `AskUserQuestion`, so route the decision through a different channel entirely" is already
an established design pattern in this codebase, reinforcing that the conclusion-stage/issues.jsonl
route is the correct application of that same established pattern here, not a novel one.

### External Resources

Not applicable — this is a purely internal documentation/convention task with no external
dependency, library, or API surface.

## Recommendations

**Site**: state the convention once in `docs/reference/standards/multi-task-creation-standard.md`,
as a new subsection immediately after Component 7's existing "Foreground Requirement" paragraph
(the subsection currently ends at the "Reference implementation: `skill-meta` Stage 2.5..." line).
Name:
- The **forbidden shape**: a task description (or a plan's phase text) that instructs an
  autonomous dispatch to itself file, create, or confirm creation of a follow-up task or
  agent-system change request.
- The **required shape**: a task description that instead asks the dispatch to (1) record one
  `issue-record.sh` entry per candidate, carrying `suggested_channel: follow_up_task` or
  `agent_system` as appropriate, and (2) render the same candidates as a human-readable list in
  its own report/plan/summary — leaving the actual confirmed creation to a foreground surface
  (the orchestration conclusion stage's channels (b)/(c), eventually consumed by
  `/telemetry --meta`, or a human directly via `/task`/`/spawn` outside orchestration).
- The **why**: cite Component 7's own Foreground Requirement (already stated two paragraphs
  above the new subsection) plus `agent-frontmatter-standard.md`'s measured
  `AskUserQuestion`-withholding section, by path — do not restate either in full.

**Pointer site**: add one or two sentences to `conclusion-stage.md`'s Overview, immediately after
the existing "never dispatched or executed by this stage" / "never created as task directories by
this stage" language for channels (b)/(c), stating that a task description or plan naming this
stage as the filer is malformed, and pointing to the new subsection in
`multi-task-creation-standard.md` for the full convention. This is the composition the dispatch
explicitly sanctions ("(a) composed with one of (b)/(c)"), chosen over composing with (c)
(`orchestrate-build-dispatch.sh` and its aux/unwind siblings) because:
- (c) would require coordinated edits across three dispatch-composition scripts to inject
  boilerplate into **every** dispatch regardless of whether that dispatch's own task description
  carries the offending phrasing — a maintenance and noise cost the dispatch's own weigh-note
  already flags ("treats a symptom... rather than preventing the phrasing").
- (b) alone (without (a)) would under-reach: it only catches the case where "the conclusion
  stage" is named explicitly, not the general case of any instruction telling a dispatch to file
  directly by some other route.
- (a) alone (without (b)) would under-reach the specific failure mode this task was raised from:
  the plan author who writes "let the conclusion stage file what survives" is, per the verbatim
  evidence, already reasoning from the conclusion-stage document's own vocabulary, and is not
  shown to consult `multi-task-creation-standard.md` while doing so.

No change is recommended to `conclusion-stage.md`'s channel routing, filter predicate, or
exactly-one-channel rule, nor to any confirmation gate, nor to the skeleton-plan follow-up
mechanism — all out of scope per the dispatch's NON-GOALS and left untouched by this
recommendation.

**Verification note carried into the plan phase**: the dispatch's Acceptance item (4) calls for
redeploying via `bash .claude/scripts/deploy-headless.sh` and confirming `RESULT=landed_verify_clean`
after the edits land — this is an implementation-phase action, noted here only so the plan phase
inherits it without re-deriving it from the dispatch body.

## Decisions

- **Primary site chosen**: `multi-task-creation-standard.md`, Component 7-adjacent. Rejected
  alternative: conclusion-stage.md alone, because it would not reach the general case (any
  dispatch instructed to file, not only one that names the conclusion stage).
- **Secondary site chosen**: a pointer-only note in `conclusion-stage.md`'s Overview. Rejected
  alternative: `orchestrate-build-dispatch.sh` (and aux/unwind variants) boilerplate injection,
  because it treats the dispatch-time symptom rather than the authoring-time phrasing, and
  carries a three-script maintenance surface for a universal (not targeted) insertion.
- **No new packet format specified.** The "proposal packet" is a pointer to the existing
  `issue-record.sh` `suggested_channel` field plus ordinary report/plan/summary prose — confirmed
  by exhaustive search (`grep -rl "proposal packet"` returns no hits in the source store today),
  so there is no existing differently-worded convention this report's recommendation would
  duplicate or need to reconcile against.
- **Skeleton-plan mechanism left untouched and unreferenced from the new convention.** It is a
  disjoint, narrower precedent (Lean-specific, human-filed) that already follows the same
  never-auto-file discipline; pointing the new convention at it would conflate two
  independently-correct mechanisms without adding information.

## Risks & Mitigations

- **Risk**: stating the convention in `multi-task-creation-standard.md` might be read as applying
  only to the Component-1-8 multi-task creation surfaces that document otherwise governs (per the
  dispatch's own weigh-note). **Mitigation**: the new subsection's own text should state explicitly
  that it applies to *any* task description or plan-phase instruction, not only multi-task-creator
  output — this is a wording concern for the implementation phase, not a siting concern; flagged
  here so the plan phase does not silently narrow the convention's scope to match the surrounding
  document's usual audience.
- **Risk**: a future reader might still miss both sites if they are composing a task description
  from a third surface not covered by either pointer (e.g. a future extension's own task-creation
  skill). **Mitigation**: out of scope for this task — the NON-GOALS explicitly exclude adding new
  enforcement, and the dispatch's Acceptance criteria only require the convention be stated once
  with pointers, not that every possible authoring surface be independently taught it.
- **Unrelated latent drift noticed during research (not actioned)**: `issue-log.md`'s seed enum
  has grown to 17 classes, but `scripts/orchestrate-build-dispatch.sh:925`,
  `scripts/orchestrate-conclusion-aggregate.sh:16`, `context/contracts/phase-closure.md:208`, and
  `context/contracts/conclusion-stage.md:117` still cite a stale "15-class" figure. This is
  unrelated to task 558's own scope (NON-GOALS excludes unrelated changes) and has been recorded
  as an `issues.jsonl` entry (`kind: issue`, `class: design-record defect or ambiguity`,
  `severity: minor`, `suggested_channel: follow_up_task`) for the conclusion stage to pick up on
  its own merits, rather than folded into this task's own deliverable.

## Context Extension Recommendations

None — this is a `task_type: meta` task; per this agent's governing contract, this section is
omitted/set to none for meta tasks.

## Appendix

**Search queries / commands used**:
- `jq -r '.extensions.core.source_dir' .claude-extensions.json` — resolve the source store.
- `grep -n "Component 7"` over `docs/reference/standards/multi-task-creation-standard.md`.
- Full read of `context/contracts/conclusion-stage.md` (all sections, including Overview, The
  Exactly-One-Channel Rule, The Hint-Versus-Decision Rule, The Coexistence Boundary With the
  Skeleton-Plan Follow-Up Mechanism, and Steps 1-7 of The Executable Stage Body).
- Full read of `context/formats/issue-log.md` (entry field table, seed class enum, extensibility
  rule, `tags` seam).
- `grep -rln "multi-task-creation-standard"` across the source store — found 19 referencing
  files, none of which are `planner-agent.md`, `reviser-agent.md`, `spawn-agent.md`, or
  `general-implementation-agent.md`.
- `grep -rln "proposal packet\|reconciled proposal"` — zero hits, confirming no pre-existing,
  differently-worded packet specification to point at instead.
- `grep -n "15-class seed enum\|17-class seed enum"` across `scripts/` and `context/` — found the
  stale-figure drift recorded as an issue (see Risks & Mitigations).
- Read of `docs/reference/standards/agent-frontmatter-standard.md`'s "Tool Withholding from
  Dispatched Subagents (Measured)" section and `context/standards/push-consent-relay.md` for the
  WHY citation and the structurally similar existing precedent.

**References**:
- `docs/reference/standards/multi-task-creation-standard.md` (Component 7, recommended primary
  site)
- `context/contracts/conclusion-stage.md` (recommended pointer site; Steps 4b/4c; "The
  Coexistence Boundary With the Skeleton-Plan Follow-Up Mechanism")
- `context/formats/issue-log.md` (`suggested_channel` field; existing packet-shape building
  block)
- `docs/reference/standards/agent-frontmatter-standard.md` ("Tool Withholding from Dispatched
  Subagents (Measured)")
- `context/standards/push-consent-relay.md` and `context/standards/user-decision-contract.md`
  (structurally similar existing precedent, not a fit for this task's mechanism)
- `commands/telemetry.md` (current name of the `/distill --meta` consumer `conclusion-stage.md`
  cites)
