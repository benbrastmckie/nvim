# Research Report: Task #299

**Task**: 299 - Detect plan revision landing concurrently with a live implement dispatch
**Started**: 2026-10-09T04:50:00Z
**Completed**: 2026-10-09T04:54:00Z
**Effort**: medium
**Dependencies**: None (do not batch with #289, #273, #274, #275, #285, #263, #250, #165, #272, #265, #293 per the dispatch's shared-file-contention note)
**Sources/Inputs**: - Codebase (agent-system/extensions/core/scripts, agents, context/contracts, skills/skill-orchestrate, context/config), direct measurement (`wc -c`), git/state.json cross-check
**Artifacts**: - this report
**Standards**: report-format.md, source-store-deploy-boundary.md

## Executive Summary

- Both defects named in the task description are confirmed exactly as described, with current
  line numbers re-verified (they have shifted since the description was written — itself a small
  irony given the task's subject): the AUX DECISION/EMISSION blocks in
  `orchestrate-cycle-plan.sh` (now ~1310-1465) run before bucketing, and
  `orchestrate-build-dispatch.sh`'s implement-phase "## Plan" block (now line ~495) emits only
  `plan_path`, no staleness signal.
- `reviser-agent.md` has zero notification machinery of any kind (confirmed: no `SendMessage`,
  `notify`, or concurrent-dispatch language anywhere in the file) — Remedy 1 is a net-new
  obligation, not a tightening of an existing one.
- **New finding, not identified in the task description**: Remedy 1's literal framing
  ("reviser-agent messages the live implement dispatch") has an unresolved addressing gap.
  `skills/skill-orchestrate/SKILL.md`'s Move 2 explicitly forwards only `agent`
  (`subagent_type`) and `model` as Agent-tool arguments — no dispatched agent is given a `name:`,
  and nothing in `agent-system/extensions/core` uses `SendMessage` for cross-dispatch
  coordination (one unrelated hit in `hooks/please-grant.sh`). A file-sentinel mechanism
  (mirroring the existing `.blocker-research.json`/`.drift-inspection.json` idiom) sidesteps this
  gap entirely and composes cleanly with Remedy 2; see Recommendations.
- **New finding**: the byte-budget interaction is tighter than the task description states. Task
  #289 has already landed — `ORCHESTRATOR_BUDGET_GATE_MODE` now defaults to `hard` (not `warn`),
  and `skills/skill-orchestrate/SKILL.md` measures 21,476 B against its 21,500 B ceiling: **24
  bytes of headroom**, not a future concern. Any SKILL.md prose addition for this task must be
  net-neutral-or-negative in bytes from the moment it lands.
- Two more adjacent-but-insufficient mechanisms were found beyond the two the task description
  already names (the `--territory` re-read note and `pre-edit-gate.md`): `context/contracts/
  territory.md`'s "Plan-Section Territory" section governs which agent may edit which checklist
  items when **multiple implementation agents** split phases of the same plan (a mechanism for
  currently-disabled parallel-wave dispatch) — a different hazard (concurrent writers) from this
  task's (a writer and a stale reader), and no existing mechanism anywhere tracks a plan file's
  mtime/hash for staleness detection.
- The recommended OPEN DECISION resolution (c) — emit the notification instruction
  unconditionally in every `plan-revision` aux dispatch file — is confirmed as genuinely the
  cheapest correct option; verified against the actual AUX EMISSION code path, which indeed
  cannot know about sibling bucketing at build time.

## Context & Scope

Researched the two landing sites named for each remedy, the one open design decision the task
description defers to research/plan, the byte-budget constraint, and the "genuinely new, not
already covered" claims about Remedy 2 and the rejected Remedy 3. Confirmed every file:line
reference against the current tree (several have drifted since the task description was
written), and investigated one mechanism question the description does not address: how
"message the live implement dispatch" is actually supposed to work given the current dispatch
contract.

Out of scope (per the task description): the header-only-correction-label line-range-excerpt
finding (DEFERRED OBSERVATION), and reordering the AUX DECISION block after bucketing (rejected
option (a)), and deferring plan-revision one cycle (REJECTED ALTERNATIVE, Remedy 3).

## Findings

### Codebase Patterns

**Defect confirmed (orchestrate-cycle-plan.sh).** The AUX DECISION comment block
(`orchestrate-cycle-plan.sh:1310-1318` in the current tree) states mutual exclusion is asserted
only between `drift-inspection` and `divergence-audit`; `plan-revision` has no exclusion against
anything, including the task's own `implement` dispatch row. The AUX EMISSION block that builds
`aux_dispatch[]` rows (starting ~line 1412) runs unconditionally before the all-terminal check,
eligibility, classification, force-phase consumption, admission, and dispatch-candidate bucketing
— all of which happen later in the same script. This is the mechanical reason Remedy 1 cannot be
conditioned on "is an implement row live this cycle" without either passing a new flag computed
after bucketing (rejected option (b)) or reordering the decision (rejected option (a)).
`aux_fixed_agent()` confirms `plan-revision` always resolves to `reviser-agent`.

**Defect confirmed (orchestrate-build-dispatch.sh).** The implement-phase block
(now at `scripts/orchestrate-build-dispatch.sh:494-497`) is:

```bash
if [ "$phase" = "implement" ]; then
  echo "## Plan"
  echo ""
  echo "- plan_path: ${plan_path}"
  echo ""
```

No mtime, hash, or revision marker is ever included. The `--territory` payload's "generic
re-read-before-editing" note (lines ~76-82) is confirmed scoped to target files an agent is about
to **edit**, not the plan instructing it — it never mentions `plan_path` or plan content at all.

**`reviser-agent.md` confirmed empty of notification machinery.** `grep -n -i
"notify\|SendMessage\|message.*implement\|concurrent" agents/reviser-agent.md` returns zero
matches. Its execution flow (Stage 0 metadata -> Stage 1 parse -> Stage 2 mode -> Stage 3/4 load
plan+research -> Stage 5a/5b synthesize -> Stage 6 metadata -> Stage 7 return text) has no step
that could plausibly have produced the BimodalLogic incident's save -- confirming the task
description's claim that the save was a one-off discretionary act, not something the current
contract would reproduce reliably.

**`pre-edit-gate.md` confirmed orthogonal, as claimed.** Its entire mechanism (probe-before-edit,
Reasoned Exclusions table) validates a plan's **claims about the codebase** (a file list, a
candidate count) against the tree. It has no concept of the plan file's own staleness relative to
a prior read of itself — confirmed by reading its full "A planning-time list is a hypothesis"
section, which frames the hypothesis strictly as "about the codebase."

**One more adjacent-but-insufficient mechanism, not named in the task description:**
`context/contracts/territory.md`'s "Plan-Section Territory" section (lines 144-150) governs
multiple **implementation** agents splitting phases of the *same* plan file concurrently (each
edits only its own phase's checklist items; the preamble is read-only) — this is the mechanism
for the currently-disabled parallel-wave dispatch mode. It addresses a different hazard
(concurrent writers racing each other) from this task's (one writer, reviser-agent, racing one
stale reader, the implement agent) and does not mention reviser-agent, revision, or staleness at
all. Worth naming explicitly in the plan so it is not mistaken for coverage a third time.

**No existing plan-staleness-detection primitive anywhere.** Searched for `plan_mtime`,
`plan_hash`, and similar across `scripts/*.sh`, `context/**/*.md`, `agents/*.md`: zero hits.
Whatever Remedy 1/2 build will be the first instance of this primitive in the codebase, not an
extension of one.

**`general-implementation-agent.md`'s tension line confirmed, verbatim and in context.** Line 59:
"4. Do NOT re-read the full plan unless necessary (the handoff References section points to
deeper context if needed)" sits under **Successor Behavior** (lines 55-60), scoped to resuming
from a handoff. The agent's *primary* (non-successor) path has no equivalent "don't re-read"
instruction to reconcile with — Stage 2 ("Load and Parse Implementation Plan") and Stage 4
("Execute File Operations Loop ... For each phase starting from resume point") are where a
Remedy 2 instruction would land for the common case; the Successor Behavior line needs a narrow,
explicit carve-out ("re-read the specific excerpted phase before writing, even as a successor")
rather than a blanket override, per the task description's own instruction to keep the
reconciliation narrow.

**`lean-implementation-agent.md` has no equivalent "do not re-read" line at all** (confirmed via
grep for "continuation", "resume", "Successor" — no matches), so Remedy 2's lean-agent landing
site is a pure addition with no existing tension to reconcile, unlike the general agent.

**Byte-budget reality is tighter than described (new finding).** `context/config/
orchestrator-context-budget.json` shows task #289's own work already landed: `commands/
orchestrate.md` is at 19,024/21,000 B and, most relevantly, `skills/skill-orchestrate/SKILL.md`'s
ceiling was raised to 21,500 B (from the 20,000 B the task description cites) with a recorded
measurement of 21,121 B on 2026-10-06. A direct `wc -c` today shows **21,476 B** — 24 B of
headroom. Cross-checked against `specs/state.json`/`specs/TODO.md`: task #289 is no longer in
`active_projects` (consistent with having completed), and `scripts/verify-deploy.sh:207` shows
`ORCHESTRATOR_BUDGET_GATE_MODE="${ORCHESTRATOR_BUDGET_GATE_MODE:-hard}"` — the default is already
`hard`, not `warn`. This means the task description's "a concurrent task promotes ... from warn
to hard" framing is stale: the promotion already happened, independent of this task, and the
gate is live today. Any SKILL.md text this task adds needs an equal-or-greater compensating trim
found *during planning*, not deferred to "whichever lands second."

**Existing aux-dispatch test coverage pattern** (`scripts/tests/test-orchestrate-build-aux-
dispatch.sh`): `plan-revision` already has dedicated test cases (missing-flag exit 2, agent/model
resolution, drift_pct interpolation). A new unconditional notification clause in the
`plan-revision` prompt string is a natural, low-risk addition to this same test file (assert the
clause's literal text appears in the built dispatch file's `## Prompt` section for every
`plan-revision` build, regardless of `--revision-reason`).

### External Resources

Not applicable — this is a pure internal-mechanism task with no external library or API surface.

## Decisions

- **OPEN DECISION resolution confirmed as (c)**: emit the Remedy 1 notification instruction
  unconditionally in every `plan-revision` aux dispatch file's prompt text. Verified against the
  actual AUX EMISSION code path (runs before bucketing; no flag threading needed; inert when no
  implement dispatch is live this cycle). Options (a) and (b) remain correctly rejected/deferred
  per the task description's own reasoning, now independently re-confirmed by reading the code.
- **Remedy 1's delivery mechanism needs an explicit choice the task description does not make**:
  a file-sentinel (`${TASK_DIR}/.plan-revised.json`, written by reviser-agent, consumed by the
  implement dispatch during its own run — a new *live, intra-cycle* consumption pattern, distinct
  from the existing *cross-cycle, orchestrator-mediated* consumption of `.blocker-research.json`/
  `.drift-inspection.json`) is recommended over a literal `SendMessage` call, because no Move 2
  dispatch currently receives a `name:` argument and nothing in the codebase establishes
  cross-dispatch `SendMessage` addressing as a supported pattern. This is a planning-phase
  decision, not a settled one from research; see Recommendations for the fallback if planning
  decides to pursue the `name:`-based `SendMessage` route instead.
- **Remedy 2's correctness does not depend on Remedy 1's delivery mechanism succeeding.** Per the
  task description's own framing, Remedy 2 (re-read the excerpted phase immediately before
  writing it) is a complete backstop against the harmful outcome (writing stale content)
  regardless of whether Remedy 1's notification arrives, is addressed correctly, or arrives late.
  Remedy 1 only affects *detection latency* for phases already written against a stale read
  earlier in the same dispatch — it cannot, by itself, prevent the kind of mis-write the
  BimodalLogic incident produced. Planning should size Remedy 1's implementation effort
  accordingly: it is a latency/awareness improvement layered on top of a correctness guarantee
  Remedy 2 already provides, not the primary safety mechanism.

## Recommendations

1. **Remedy 1 landing site**: `scripts/orchestrate-build-aux-dispatch.sh`'s `plan-revision` prompt
   case (current lines ~189-195) — append one unconditional sentence instructing reviser-agent to
   signal the live implement dispatch when the revision lands. Recommend the file-sentinel form
   (`Write ${TASK_DIR_ABS}/.plan-revised.json with {revised_at, dispatch_seq, reason}` — mirroring
   the `blocker-research` prompt's own `.blocker-research.json` departure from the returned-text
   channel, already precedented three lines above in the same file) over a `SendMessage` call, to
   avoid the unresolved addressing gap. Put the actual instructional prose in a new
   `context/patterns/` file (per the BYTE-BUDGET constraint) and have both the aux dispatch file
   and any SKILL.md mention be a one-line pointer to it.
2. **Remedy 2 landing sites**: `scripts/orchestrate-build-dispatch.sh`'s implement-phase "## Plan"
   block (line ~494) should additionally pass a comparable signal — a sentinel-file check
   instruction or the plan's mtime at dispatch-build time — so the agent has something to compare
   against; and `agents/general-implementation-agent.md` Stage 4 ("Execute File Operations Loop")
   should gain a narrow instruction: "immediately before writing any edit for a phase, re-read
   that phase's section of the plan file (and check for `.plan-revised.json` newer than your
   first read, if present) — not the full plan." Mirror into
   `agent-system/extensions/lean/agents/lean-implementation-agent.md`'s equivalent phase-loop
   stage for parity, per the task description's "plus ... for parity" instruction. Reconcile with
   `general-implementation-agent.md:59`'s Successor Behavior line via a narrow carve-out sentence
   immediately after it, not a rewrite of the line itself.
3. **Byte budget**: given 24 B of headroom on SKILL.md today, plan to (a) add zero or near-zero
   bytes to SKILL.md itself (a single new pointer line, if any, and only after confirming the net
   byte delta against a fresh `wc -c` at plan-authoring time, not against this report's
   snapshot), and (b) put all substantive contract prose for both remedies in one new
   `context/patterns/` file (e.g. `context/patterns/plan-revision-notification.md`) that the aux
   dispatch prompt, `orchestrate-build-dispatch.sh`'s implement block, and both implementation
   agents all point to, rather than duplicating prose across four files.
4. **Test coverage**: extend `scripts/tests/test-orchestrate-build-aux-dispatch.sh` with a case
   asserting the new unconditional notification clause appears in every `plan-revision` build
   (both `--revision-reason blocker` and `drift`), and extend
   `scripts/tests/test-orchestrate-build-dispatch.sh` with a case asserting the implement-phase
   "## Plan" block carries whatever new staleness-check instruction Remedy 2 adds. Both test
   files already exist and already test adjacent prompt content, so this is additive, not new
   test infrastructure.
5. **Do not revisit** the rejected Remedy 3 (defer-one-cycle) or the DEFERRED OBSERVATION
   (header-only correction labels dropped by line-range excerpts) — both are correctly out of
   scope per the task description, and nothing found in this research changes that.

## Risks & Mitigations

- **Risk**: a file-sentinel approach for Remedy 1 needs its own consumption/clearing discipline
  (an uncleared `.plan-revised.json` could falsely flag a much-later, unrelated dispatch as
  racing a revision). **Mitigation**: scope the sentinel's relevance to "newer than this
  dispatch's own plan read timestamp" rather than "exists at all," and have the implement agent
  delete or timestamp-acknowledge it once seen — this is a planning-phase design detail, not
  resolved here, but the existing `.blocker-research.json`/`.drift-inspection.json` consume-and-
  clear pattern (`aux_consume_blocker_file`/`aux_consume_drift_file` in
  `orchestrate-cycle-plan.sh`) is a proven template to adapt.
- **Risk**: if planning instead chooses the literal `SendMessage` route, it must first settle
  whether Move 2 dispatches are addressable by name at all in the actual runtime (this report
  found no codebase evidence either way — SKILL.md's documented Agent-tool arguments exclude
  `name:`, but the real harness may auto-assign an addressable identifier regardless of what
  SKILL.md's prose asks the orchestrating agent to pass). **Mitigation**: treat this as a
  prerequisite spike for planning, not an assumption; the file-sentinel route avoids needing the
  answer at all and is recommended for exactly this reason.
- **Risk**: landing this task concurrently with any of #289, #273, #274, #275, #285, #263 (all
  touch `skill-orchestrate/SKILL.md`), #250, #165, #272, #265, #293 (touch
  `orchestrate-cycle-plan.sh`), or #263 (touches `orchestrate-build-dispatch.sh`) risks a byte-
  budget or merge collision given the near-zero SKILL.md headroom. **Mitigation**: already
  flagged by the task description as a batch-admission constraint; re-confirmed here as still
  current (#289 has since left `active_projects`, so it is no longer a live collision risk, but
  the others were not independently re-checked and should be re-verified at plan/dispatch time).

## Context Extension Recommendations

- **Topic**: live, intra-cycle cross-dispatch notification (as opposed to the existing cross-
  cycle, orchestrator-mediated aux-file consumption pattern).
- **Gap**: no `context/patterns/` file documents a sanctioned mechanism for one live dispatch to
  signal another live dispatch of the same task within the same `/orchestrate` cycle. The closest
  existing precedent (`.blocker-research.json`/`.drift-inspection.json`) is consumed by the
  *orchestrator* on a *later* cycle, not by a sibling *agent* during the *same* cycle — a
  materially different consumption model this task will need to establish.
- **Recommendation**: if the plan phase adopts the file-sentinel route for Remedy 1, capture the
  resulting convention (sentinel shape, freshness check, consume/clear discipline) as a new
  `context/patterns/plan-revision-notification.md` (or similarly named) file — both because the
  BYTE-BUDGET constraint already pushes the prose there, and because this will likely be the
  template for any *future* live-notification need between concurrent same-task dispatches.

## Appendix

- Searches/greps used: `grep -n` for `SendMessage`/`notify`/`concurrent` across
  `agents/reviser-agent.md`; `grep -rln "SendMessage"` across
  `agent-system/extensions/core`; `grep -rn "excerpt"` across the same tree; `grep -rn
  "plan_mtime\|plan_hash\|...checksum"` across scripts/context/agents; `wc -c
  skills/skill-orchestrate/SKILL.md`; `jq` reads of `context/config/orchestrator-context-budget.json`
  and `specs/state.json`.
- Files read in full or in relevant part: `scripts/orchestrate-cycle-plan.sh` (lines
  1220-1510), `scripts/orchestrate-build-aux-dispatch.sh` (lines 1-70, 170-245),
  `scripts/orchestrate-build-dispatch.sh` (lines 55-75, 420-540), `agents/general-implementation-
  agent.md` (lines 1-180), `agents/reviser-agent.md` (structure + grep), `extensions/lean/agents/
  lean-implementation-agent.md` (lines 1-90 + grep), `context/contracts/pre-edit-gate.md` (lines
  1-80), `context/contracts/territory.md` (lines 1-15, 144-196), `skills/skill-orchestrate/
  SKILL.md` (lines 130-175), `context/config/orchestrator-context-budget.json`,
  `scripts/verify-deploy.sh` (ORCHESTRATOR_BUDGET_GATE_MODE lines), `scripts/tests/test-
  orchestrate-build-aux-dispatch.sh` (plan-revision test cases).
