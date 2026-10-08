# Research Report: Task #354

**Task**: 354 - Decide whether general-implementation-agent.md's Local Long-Running Command Discipline needs a third case covering an agent that dispatches a subagent and waits on it
**Started**: 2026-10-08
**Completed**: 2026-10-08
**Effort**: Small (documentation-only decision; no code paths change)
**Dependencies**: Follow-up to task 343 (added the mechanism-mandating local-gate case and the three-way deadline fork)
**Sources/Inputs**: Codebase (agent-system/extensions/core), the harness's own built-in Agent-tool instructions visible in this session, the dispatch file's provenance narrative
**Artifacts**: `specs/354_bound_agent_wait_on_dispatched_subagent/reports/01_dispatched-subagent-wait.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The gap is real and verbatim-verifiable: `general-implementation-agent.md`'s "Local
  Long-Running Command Discipline" names exactly two cases (CI/remote, local gate/build) and is
  silent on a dispatched agent itself invoking the `Agent` tool and waiting on the result.
- No confirmed stranding incident supports this gap today. The one incident that looked like
  evidence (a research dispatch "stranded... on a backgrounded fork probe") was a misdiagnosis:
  the dispatch was alive and actively rewriting its report the whole time; the orchestrator's
  theory that it was "waiting on" the fork was never substantiated, and the only *confirmed*
  defect from that incident is a fork prompt-scoping hazard already fixed elsewhere
  (`docs/fork-patterns.md`'s "Fork Prompt Scoping Hazard" section).
- The capability for the hazard to become real is nonetheless demonstrably present: this very
  session runs inside a multi-agent ("teammate") harness mode where `Agent`-tool dispatches can
  be asynchronous/backgrounded and addressed later by name — a mode distinct from, and not
  discussed anywhere in, this codebase's own dispatch contracts, which assume (and one Agent-tool
  instance explicitly states) "only synchronous subagents are supported." The already-occurred
  fork-probe incident proves a dispatched agent **does** sometimes issue a nested `Agent` call
  mid-dispatch, not merely that `skill-orchestrate` itself does.
- **Decision (middle ruling, refined)**: close the textual gap with a narrow, flat rule, not a
  bounded-deadline-and-poll allowance copied verbatim from the local-gate case. The CI and
  local-gate cases both have a foreground-pollable liveness primitive (`gh run view`'s status
  call; `kill -0 "$pid"`). A harness-level async subagent dispatch has no such primitive — its
  own documented contract is "don't race... the notification arrives as a user-role message in a
  later turn; it is never something you write yourself." A "bounded wait with a defined action at
  the deadline" is therefore not mechanically available for this case the way it is for the
  other two; the three-way deadline fork does **not** transfer verbatim, contrary to the
  dispatch's own tentative framing, and the report records this as a specific finding rather than
  assuming the transfer. The correct rule is: synchronous nested delegation (the `Agent` call
  blocks in the same tool invocation until the result is in hand) is **not** a background wait at
  all and needs no new discipline beyond saying so explicitly; async/backgrounded nested
  delegation, ended by letting the turn close to await a later notification, is prohibited
  outright — not bounded, because nothing to bound it with exists.
- This ruling does not reopen `stall_suspected`'s trigger (no new evidence is produced here) and
  does not forbid ordinary nested delegation (the fork-probe pattern itself, already corrected for
  prompt scoping, remains fully permitted when synchronous).
- A companion finding, recorded as the dispatch's "side-benefit": the correct live-vs-stranded
  probe for a dispatch being watched externally is artifact mtimes plus live child-process
  checks, never "has a handoff file appeared" — the research phase never writes one in any mode,
  so its absence is not evidence of anything. This belongs beside the existing `stall_suspected`
  documentation in `docs/architecture/orchestrate-state-machine.md`, which already states the
  no-handoff-for-research fact but has never generalized it into standalone probe guidance.

## Context & Scope

Task 343 added a mechanism-mandating local-gate case to
`agents/general-implementation-agent.md`'s "Local Long-Running Command Discipline" (the
`bounded-build-waiter.md` idiom: captured PID, `kill -0` liveness loop, outer `timeout`) sitting
alongside the pre-existing CI/remote case (`external-process-wait.md`'s bounded `gh run
watch`/`gh run view` pair). Its implementer confirmed by diff that the new mandate was scoped
exactly to "a local verification, gate, build, or test process" and explicitly declined to widen
it to cover a dispatched agent waiting on a subagent it spawned, flagging that as a distinct,
deferred defect class. This task is that follow-up: decide, narrowly, whether that third case
needs covering, and either implement the ruling or record the reasoned decision not to.

The investigation was scoped to:
1. Whether the textual gap is real (read the mandate directly).
2. Whether the one cited incident is actual evidence of a stranding hazard, or a misdiagnosis (as
   the dispatch itself warns it may be).
3. What delegation/dispatch mechanisms this codebase documents today for an agent to invoke a
   further subagent, and whether any of them structurally resembles the Bash
   `run_in_background`/Monitor hazard the existing two cases guard against.
4. Where a ruling, if any, should live, and how the "diagnose liveness" side-finding should be
   documented.

`stall_suspected`'s trigger predicate was explicitly out of scope for modification (task 343
already recorded the non-widening as a deliberate ruling); this report does not reopen it and no
new evidence surfaced here would justify doing so.

## Findings

### The textual gap, confirmed

`agents/general-implementation-agent.md:165-226` (Local Long-Running Command Discipline) opens
with: *"distinct from the external/remote case above: a build, test harness or lint sweep run on
this machine"* and defines the local-gate mandate entirely in terms of `bounded-build-waiter.md`'s
PID/`kill -0`/`timeout` idiom. Neither this section nor the CI/remote section above it
(`external-process-wait.md`'s bounded `gh run watch` pair) mentions an `Agent`-tool dispatch at
all. The gap named in the dispatch is real and exactly as described.

### The cited incident does not establish a stranding hazard

Re-reading the provenance narrative carefully: a research dispatch ran long (17+ minutes) and was
suspected stalled by the orchestrator watching it. The suspicion rested on the dispatch having
spawned a backgrounded `subagent_type: "fork"` probe; the orchestrator's working theory was that
the research dispatch was itself blocked waiting on that fork. **That theory was never
substantiated and was retracted**: file mtimes showed the research dispatch actively rewriting
its own report throughout the window, meaning it was doing ordinary, unrelated work the whole
time, not blocked on anything. The dispatch finished normally. The ONE confirmed defect from that
incident is unrelated to waiting at all: the fork probe itself was scoped only positively ("return
X") and, because a `subagent_type: "fork"` dispatch inherits the entire calling session's context
(not just the forking turn's instructions), it autonomously completed a full, unrelated research
deliverable and sent a premature completion message — a **prompt-scoping** defect, already fixed
by the capped addendum in `docs/fork-patterns.md`'s "Fork Prompt Scoping Hazard" section.

Conclusion: there is no measured case of a dispatched agent actually stranding itself by
backgrounding a subagent dispatch and ending its turn to await the result. The dispatch file's own
instruction not to treat the incident as confirmed evidence is correct, and this report does not
treat it as such.

### The capability for the hazard is nonetheless real, not hypothetical

Despite the absence of a confirmed incident, three independent facts establish that the *shape* of
hazard described in the "FOR EXTENDING" argument is mechanically possible, not merely
speculative:

1. **A dispatched agent already does invoke `Agent` mid-dispatch.** The fork-probe incident is
   direct proof: a research-phase dispatch (not `skill-orchestrate` itself) issued a nested
   `Agent(subagent_type: "fork", ...)` call from within its own turn. `docs/fork-patterns.md`'s
   "No recursive forks" constraint ("a forked subagent cannot itself fork") restricts only what a
   *fork* may do next — it says nothing against an ordinary dispatched agent (research or
   implementation) itself issuing a fork or other nested `Agent` call, and this codebase's own
   agent files impose no tool restriction that would prevent it (`general-implementation-agent.md`
   carries no `tools:`/`allowed-tools:` frontmatter restriction at all, i.e. it has every tool,
   `Agent` included).
2. **Asynchronous/backgrounded `Agent` dispatch exists at the harness level and is active in this
   very session.** The `Agent` tool's own built-in description (harness-level, not authored in
   this codebase) states for this session specifically: "The `run_in_background` and `name`
   parameters are not available in this context. Only synchronous subagents are supported" — the
   deliberate phrasing implies these parameters **are** available in other contexts. This
   session's own "Agent teammate communication" system reminder names several concurrently
   running, independently addressable background agents (`main`, `impl-284`, `research-335`, …),
   which is exactly that async/backgrounded mode in active use one level up from this dispatch.
   Nothing in this codebase's own contracts (`docs/guides/creating-agents.md`,
   `docs/guides/creating-skills.md`, `context/patterns/fork-patterns.md`,
   `context/patterns/skill-lifecycle.md`) engages with this async mode at all — it is invisible to
   the agent-system's own documentation even though it is a real, live capability of the
   underlying tool the agent-system's own dispatched agents can reach.
3. **The existing mandate's rationale generalizes cleanly.** The stated reason the local-gate case
   needed its own mandate — *"the harness's own asynchronous detach-then-await-notification path
   hands the dispatch back unfinished with nothing guaranteed to resume it"* — is not specific to
   Bash. It is a property of any harness mechanism that lets a tool call return control before its
   result is ready, leaving a later notification as the only completion signal. An async `Agent`
   dispatch fits that description exactly.

### Why the three-way deadline fork does *not* transfer verbatim (a specific, load-bearing finding)

The dispatch's "FOR EXTENDING" argument proposes that task 343's three-way deadline fork
(writer-alive / writer-dead-with-result / enumerated exclusion) "would apply almost verbatim."
Checked against the actual mechanics, it does not, and the difference matters for what to write:

- The CI case has a foreground-pollable status primitive: `gh run view --json status,conclusion`.
- The local-gate case has a foreground-pollable liveness primitive: `kill -0 "$pid"` against a
  captured PID.
- **A harness-level async `Agent` dispatch has no such primitive available to the dispatching
  agent.** The `Agent` tool's own instructions are explicit and symmetric with this absence:
  "Don't peek" (do not read the fork's output file mid-flight), "Don't race" (never fabricate or
  predict a fork's result), and the completion signal "arrives as a user-role message in a later
  turn; it is never something you write yourself." There is no sanctioned way to spin a bounded
  `timeout N` poll loop against an in-flight async subagent dispatch from inside the same turn,
  because the turn's own tool-call boundary is exactly what separates "dispatched" from
  "notified" — unlike a Bash background job, where the dispatching turn can keep running
  `kill -0`/log-read iterations in the foreground while the child keeps writing to a file it can
  inspect.

This means a deadline-and-poll allowance, if written by analogy to the other two cases, would
describe a mechanism that does not exist and could not be followed. The correct rule shape is
therefore narrower and flatter: distinguish the *synchronous* case (no new rule needed — this is
not a background wait) from the *asynchronous* case (prohibited outright — there being no bounded
alternative to offer in its place), rather than writing a third "bounded wait with a deadline"
clause that would misdescribe the available tooling.

### Ordinary nested delegation must not be swept in

The "AGAINST" argument in the dispatch is correct and is preserved by the ruling above: a
synchronous `Agent` call — one that blocks in the same tool invocation until the subagent's result
returns — is the normal, intended delegation primitive (`skill-orchestrate`'s own
`blocker-research`/`drift-inspection` fork dispatches use exactly this shape, and so, per the
fork-probe incident, does at least one dispatched agent's own nested probe call). It has no
turn-ending choice point and so cannot reproduce the detach-then-forget defect the existing mandate
guards against; it behaves like any other tool call whose duration varies (a slow `WebFetch`, a
large `Grep`), not like `Bash(run_in_background: true)`. A blanket prohibition on "awaiting a
dispatched subagent" would therefore forbid a pattern this system already relies on and has
already fixed (for prompt scoping) rather than banned.

### `stall_suspected` is already correctly scoped; no new evidence changes that

`orchestrate-cycle-postflight.sh`'s `stall_suspected` field fires only for `phase="plan"` or
`"implement"`, specifically because, per its own inline comment, *"The research phase never sets
it, because `report_missing` and the D4 message-findings recovery already own that path."* The
misdiagnosis in the cited incident happened in spite of this already-correct gating — the
orchestrator's wrong "no handoff yet -> stalled" heuristic was not the mechanical
`stall_suspected` check at all (which is git-commit-gated and phase-gated, and never considers
handoff presence/absence in the first place), but an separate, ad hoc judgment applied by whatever
was watching the research dispatch. This confirms the dispatch's own instruction not to reopen
`stall_suspected`'s trigger: no defect in that field is implicated, and generalizing its predicate
with an OR against handoff-absence would (per `docs/architecture/handoff-schema.md`'s "Readers
MUST check freshness" section, which this field's own header already cites) destroy its only
discriminating signal for an unrelated reason. No new evidence from this investigation changes
that standing ruling.

### Where the probe-diagnostic side-finding belongs

`docs/architecture/orchestrate-state-machine.md`'s "Abandoned Wrap-Up" section is already the
established home for "how do we tell whether an unresponsive-looking dispatch actually died"
reasoning, and already states the research-phase-never-writes-a-handoff fact as part of
`stall_suspected`'s own scoping rationale. It has never generalized that fact into standalone
guidance for a human or agent *externally watching* a dispatch (the situation the cited incident
was actually in) to use. That is the natural, discoverable location for the new note the
acceptance criteria ask for, rather than a new standalone file: the probe answers precisely the
question that section's neighboring content already poses, for a reader already in the right
place to find it.

## Decisions

1. **The mandate is extended, narrowly** — Decision: adopt a refined middle position (per the
   dispatch's "A MIDDLE RULING...may be the right one" language, but corrected on mechanics):
   permit and explicitly bless synchronous nested subagent delegation as outside this discipline
   entirely (it is not a background wait); prohibit outright — not bound with a deadline, because
   no bounded-poll mechanism exists for it — ending a dispatched agent's own turn to await an
   async/backgrounded subagent dispatch it issued. This is a correction of the dispatch's own
   tentative "three-way deadline fork... would apply almost verbatim" framing: it does not, for
   the reasons in "Why the three-way deadline fork does not transfer verbatim" above, and the
   ruling is written to match the actually-available mechanics rather than copy the local-gate
   shape blind.
2. **No blanket prohibition on dispatching and awaiting a subagent** — the ordinary, synchronous
   fork-probe pattern (already corrected for prompt scoping elsewhere) remains fully permitted;
   this decision explicitly carves it out so a future reader does not conflate "don't background
   it and walk away" with "don't delegate at all."
3. **No change to `stall_suspected`'s trigger predicate** — no new evidence was produced here that
   would justify reopening `docs/architecture/handoff-schema.md`'s "Readers MUST check freshness"
   non-widening ruling; this report affirmatively confirms the standing decision rather than
   silently leaving it untouched.
4. **Correct home for the extended mandate**: `agents/general-implementation-agent.md`'s own
   "Local Long-Running Command Discipline" section, as a third, clearly delimited subsection
   following the existing CI and local-gate subsections — consistent with
   `bounded-build-waiter.md`'s own classification note naming that file as "the contract's
   authoritative home" for this kind of prose. `bounded-build-waiter.md`'s canonical
   generated-copy bullet pair is **not** the right place to fold this into, because that bullet
   pair is specifically the PID/`kill -0`/`timeout` idiom, which (per the finding above) does not
   apply to an async subagent dispatch at all — folding this case into that pair would misstate
   the mechanism as available when it is not. A separate, short pointer is added to both
   `bounded-build-waiter.md`'s and `external-process-wait.md`'s "Related Documentation" sections
   instead, naming the new subsection so a reader of either file can find the third case, without
   duplicating the PID-based idiom onto a case that cannot use it.
5. **Correct home for the probe-diagnostic side-finding**: a new short subsection in
   `docs/architecture/orchestrate-state-machine.md`, placed immediately after "Abandoned
   Wrap-Up", naming explicitly: artifact mtimes (actively changing = alive) and live child
   processes discriminate a working dispatch from a stranded one; the presence or absence of a
   handoff file does not, because the research phase never writes one in any mode (already stated
   locally in that section) and, more generally, a dispatch simply not having reached its closing
   write yet looks identical to one that never will. This is recorded as a reusable diagnostic
   for whatever is externally watching a dispatch (an operator, an orchestrator session, a
   teammate relay), not a change to any mechanical check.
6. **This phase does not implement the edit.** Per this agent's own research-phase contract (this
   dispatch's `phase: research`), the concrete text changes are recommended below for the
   plan/implement phases to apply; research records the ruling and its exact intended wording so
   implementation is mechanical, rather than editing `agent-system/extensions/core/**` directly
   from a research dispatch.

## Recommendations

Recommended for the plan/implement phases (source-store edits under
`agent-system/extensions/core/**`, per this task's description; redeploy afterward if any deployed
file changes):

1. **`agents/general-implementation-agent.md`** — append a third subsection to the existing
   "Local Long-Running Command Discipline" section (after the local-gate subsection, before Stage
   6b or wherever the section currently ends), to this effect:

   > **Dispatched-Subagent Wait Discipline** (distinct from both cases above: this dispatched
   > agent itself invoking the `Agent` tool to delegate to a further subagent, e.g. a
   > `subagent_type: "fork"` probe, and needing that subagent's result before proceeding).
   >
   > **Permitted, and outside this discipline entirely**: an ordinary synchronous `Agent`-tool
   > call that blocks in the same tool invocation until the subagent's result is returned. This is
   > the normal, intended nested-delegation primitive (the same shape `skill-orchestrate` itself
   > uses for blocker-research and drift-inspection forks) — it has no turn-ending choice point
   > and is not a background wait, so nothing here restricts it.
   >
   > **MUST NOT** issue a subagent dispatch in any asynchronous/backgrounded mode (any mode where
   > the `Agent` call returns control before the subagent's result is ready, leaving a
   > notification to arrive later) and then end this turn to await that notification. Unlike the
   > CI and local-gate cases above, there is no sanctioned way to bound this with a deadline-plus-
   > poll loop — a backgrounded subagent dispatch exposes no PID or status call this agent can
   > inspect from inside its own turn (see `docs/fork-patterns.md`'s fork-mechanics narrative);
   > the only sanctioned way to use its result within this dispatch is to have awaited it
   > synchronously in the first place. Ending the turn to wait reproduces the identical defect
   > named for the other two cases: the harness's asynchronous detach-then-await-notification path
   > hands the dispatch back unfinished with nothing guaranteed to resume it.
   >
   > This does not forbid or discourage ordinary nested delegation — only an async/backgrounded
   > dispatch left unresolved at turn end.

2. **`context/patterns/bounded-build-waiter.md`** and **`context/patterns/external-process-wait.md`**
   — add one line each to "Related Documentation" pointing at the new subsection above (e.g. *"
   `agents/general-implementation-agent.md`'s 'Dispatched-Subagent Wait Discipline' — the
   complementary nested-subagent-dispatch case; neither this file's PID-liveness idiom nor the
   CI-status-poll idiom applies to it, see that subsection for why"*). Do not fold the new case
   into either file's own canonical idiom.

3. **`docs/architecture/orchestrate-state-machine.md`** — insert a new subsection immediately
   after "Abandoned Wrap-Up", titled something like "Diagnosing Dispatch Liveness: mtimes and
   Processes, Not Handoff Presence", stating: artifact mtimes actively advancing, and a live child
   process tree, are the correct signals that a dispatch being watched externally is still
   working; a missing handoff file is not evidence of a stall by itself, because (a) the research
   phase never writes one in any mode (already true of `stall_suspected`'s own scoping) and (b)
   more generally, "hasn't reached its closing write yet" and "never will" are indistinguishable
   from handoff-absence alone. Cross-reference `stall_suspected`'s own commit-gated design as the
   worked example of getting this right mechanically.

4. **Follow-up, not in this change's scope**: if a dispatched agent's nested async subagent use
   grows beyond the single measured fork-probe case, propagate recommendation 1's MUST-NOT bullet
   to other in-scope implementation/research agents using the exact generated-copy-source +
   `lint-agent-contracts.sh` pattern `bounded-build-waiter.md` already established for the
   local-gate bullet pair (its "Canonical Agent-Contract Bullet" section), rather than hand-copying
   prose independently per agent file.

## Risks & Mitigations

- **Risk**: writing a prohibition that is never actually exercised (since no stranding has been
  confirmed) adds mandate text for a hazard that may never materialize.
  **Mitigation**: the rule is a single short MUST NOT plus an explicit permitted carve-out — low
  cost to carry, and it closes a textual silence the dispatch's own provenance already flags as a
  real gap independent of whether the hazard has fired yet. The dispatch's own framing treats the
  textual gap as worth closing regardless of confirmed incidence ("Establish whether the hazard is
  real before writing a prohibition for it" was answered: the *capability* is real and demonstrated
  via the fork-probe incident; the *specific stranding* is not, and the ruling is written to match
  that — a flat MUST NOT rather than an elaborate mechanism-mandating apparatus like task 343's).
- **Risk**: a future reader copies the local-gate's deadline-and-poll shape onto this new case by
  analogy, introducing dead or misleading advice (a `kill -0`-style loop against something with no
  PID).
  **Mitigation**: the recommended wording explicitly states why no bounded-poll allowance is
  offered, rather than leaving the asymmetry implicit.
- **Risk**: the new probe-diagnostic subsection could be read as weakening or replacing
  `stall_suspected`'s mechanical check.
  **Mitigation**: recommendation 3 above frames the note as guidance for an external, non-
  mechanical watcher (operator, orchestrator session, teammate relay), explicitly pointing at
  `stall_suspected`'s existing commit-gated design as the correct worked example, not a competing
  mechanism.

## Context Extension Recommendations

- **Topic**: harness-level asynchronous/backgrounded `Agent`-tool dispatch (the "teammate" mode
  visible in this very session: `run_in_background`/`name` params, `SendMessage`-addressable
  background agents).
  **Gap**: no file under `agent-system/extensions/core/docs/` or `context/` currently
  acknowledges this mode exists at all; `docs/fork-patterns.md` and
  `docs/guides/creating-agents.md` describe only the synchronous, single-session dispatch model
  `skill-orchestrate` itself uses.
  **Recommendation**: once recommendation 1 above lands, consider a short standalone note (or an
  addendum to `docs/fork-patterns.md`) naming the async/teammate mode explicitly, so a future
  agent author does not have to rediscover its existence the way this investigation did.

## Appendix

### Files read

- `agent-system/extensions/core/agents/general-implementation-agent.md` (Local Long-Running
  Command Discipline section, delegation_depth worked example)
- `agent-system/extensions/core/agents/meta-builder-agent.md` (Agent-tool/subagent_type reference)
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` (full file: Required
  Rules, Canonical Agent-Contract Bullet / Generated-Copy Source section, classification rulings)
- `agent-system/extensions/core/context/patterns/external-process-wait.md` (full file)
- `agent-system/extensions/core/docs/fork-patterns.md` (full file: fork mechanics, Fork Prompt
  Scoping Hazard, Constraints table)
- `agent-system/extensions/core/context/contracts/wrap-up.md` (Teardown Precedes the Terminal
  Handoff Write)
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` (Abandoned
  Wrap-Up section, stall-reprompt field schema)
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (`stall_suspected`
  computation and its inline rationale comments)
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` ("Readers MUST check
  freshness" section)
- `agent-system/extensions/core/docs/guides/creating-agents.md`,
  `docs/guides/creating-skills.md` (checked for any documented async/background Agent-dispatch
  parameter; none found)
- This session's own harness-level Agent tool description and "Agent teammate communication"
  system reminder (used as direct evidence that async/backgrounded Agent dispatch is a live
  harness capability, not a hypothetical)

### Search queries / greps used

- `grep -n "Local Long-Running Command Discipline" -A 80 agents/general-implementation-agent.md`
- `grep -rn "run_in_background" --include="*.md"` (confirmed every occurrence refers to Bash's
  parameter, none to an Agent-tool parameter, within this codebase's own docs)
- `grep -n "stall_suspected" scripts/orchestrate-cycle-postflight.sh`
- `grep -rn "delegation_depth"` (checked whether general-implementation-agent documents its own
  nested dispatch; found only self-describing metadata, not a dispatch mechanism)
- `grep -n "No recursive forks" -B3 -A3 docs/fork-patterns.md`
