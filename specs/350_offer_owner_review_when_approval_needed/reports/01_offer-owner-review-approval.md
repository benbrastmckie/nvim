# Research Report: Task #350

- **Task**: 350 - Offer the owner the review path when a books task reaches a point that needs
  an approval, instead of requiring the owner to know to run /approve
- **Started**: 2026-10-17T08:21:00Z
- **Completed**: 2026-10-17T08:45:00Z
- **Effort**: ~1.5 hours (research only)
- **Dependencies**: `add_approve_command_owner_labeled_approvals` (archived as task 349 in this
  repository; `owner_labeled_agent_assisted_approvals` in the Logos/Verification repository, not
  readable from this session)
- **Sources/Inputs**: codebase exploration only (no web search) — see Appendix for the full file
  list
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- The plumbing this task is told to reuse is already generic and complete: `user_decision` on
  `.return-meta.json` is relayed by `orchestrate-cycle-postflight.sh` into `verdict=ask_user`
  purely by field presence (no text-pattern classification of any kind), and
  `skill-orchestrate`'s Move 3/Move 4 already accumulate and batch-relay it. **No change to
  `skill-orchestrate/SKILL.md`, `orchestrate-cycle-postflight.sh`, or
  `orchestrate-record-decision.sh` is needed** — contradicting the three script/skill entries in
  task 350's own originating `proposed_file_scope`, which was a pre-research guess.
- The detection in scope item (1) can only live in the **books agent definitions**, never in
  postflight: postflight's verdict derivation is a fixed status-string lookup table with no
  access to a dispatch's raw gate stdout/stderr, and the `user_decision` contract is explicitly
  producer-owned by the agent, with postflight required to relay verbatim and never originate or
  reinterpret it. "Both" is not a real third option here — it would mean postflight
  second-guessing a signal it cannot see.
- Today, **no books agent (plain or hard, research or implementation) invokes the fail-closed
  gate that would surface a `check-approvals.sh`-class failure at all.** `books-gate.sh` (the
  advisory `--gate` tier) covers only layer-lint + closure, and Stage 5's fixed verification
  (`lake build`, `books-tool validate/check`, the certifier's `--check`) never runs
  `full-gate.sh`/`check.sh`. The approvals-stage failure this task must detect can only occur
  when a **plan-directed** Bash step in a books dispatch runs that gate — so the new instruction
  must be a cross-cutting rule ("whenever you run a gate command and it fails this specific way"),
  not a hook on one fixed numbered stage.
- The exact absent-or-stale failure signature (`check-approvals.sh`'s stderr/exit convention)
  lives entirely in the companion Logos/Verification repository, unreadable from this session.
  This is a real, named gap: the plan phase must pin that literal signature (by reading the
  script directly, or by coordinating with the sibling Verification-repo task) before the
  detection rule can be written as anything more precise than "any non-zero exit from this gate,"
  which would misclassify ordinary proof/build failures as approval requests.
- `agent-system/extensions/core/context/standards/push-consent-relay.md` is a near-identical
  precedent already built and documented for the same structural problem (a dispatched agent
  cannot reach `AskUserQuestion`; its sanctioned endpoint needs a human's own deliberate action).
  Its design — the relay's YES answer **mints nothing**; it tells the human the exact command to
  type themselves — is the right template for this task's hand-off option, and it resolves scope
  item (3)'s no-human requirement by construction rather than by inventing new detection: the
  "enter review now" option should never auto-invoke `/approve`; it should surface the exact
  `/approve <component> [--task N]` line for the owner to type in their own next turn, which
  lands on `skill-approve`'s own existing `orchestrator_mode: true` Stage 2 refusal if anyone
  ever tries to run it from inside an autonomous dispatch anyway — a second, independent stop,
  not a duplicated one.

## Context & Scope

This is a detection-and-offer task over existing interaction plumbing (`user_decision` →
`pending_ask_user[]` → batched `AskUserQuestion` in Move 4 → `orchestrate-record-decision.sh`),
explicitly forbidden from building any new interaction channel. The task is scoped to four
questions: (1) where the detection belongs (agent definitions, postflight classification, or
both, with a recorded reason); (2) the semantics of three offered options (enter review now,
defer, decline) with decline/defer never weakening the gate; (3) a no-human-attached refusal that
must mirror the `/approve` command's own refusal case; (4) a hand-off to `/approve` that invokes
rather than duplicates its review logic. The companion `/approve` command, `approve.sh`, and
`check-approvals.sh` are explicitly out of scope; this research treats them as fixed external
contracts to read and match, not to design.

Research was codebase-only: the full `agent-system/extensions/{core,books,approvals}` trees in
this repository, plus the archived task 349 (`specs/archive/349_add_approve_command_owner_labeled_approvals/`)
whose plan, summary, and shipped files define `/approve`'s actual shape. The companion
Logos/Verification repository (where `components/*/approve.sh` and `check-approvals.sh` actually
live) is a separate repository not present in this session's working directory and was not read.

## Findings

### The plumbing this task must reuse — confirmed complete, confirmed generic

- `context/standards/user-decision-contract.md` (core extension): `user_decision` is set on
  `.return-meta.json` by the producing agent only, with a fixed shape
  (`question`, `options[]`, `recommended`, `blocking`). "The orchestrator never asks the user on
  its own, and never decides on the user's behalf. Agents decide." `options[]` entries are flat,
  self-describing strings with no `description` field.
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh:1617-1670`: the relay is
  mechanical and unconditional — if `.user_decision` is present on the handoff or
  `.return-meta.json` (handoff takes precedence), `verdict` is forced to `ask_user` *before*
  every other status-to-verdict mapping runs, and the comment at line 1622 states plainly: "this
  script never asks and never writes `.decisions.json`." The rest of the verdict derivation
  (lines ~1631-1663) is a flat lookup from the agent's own reported `status` string
  (`researched`/`planned`/`implemented`/`partial`/`failed`/`blocked`/`needs_research`) to a
  verdict — there is no stage-output text scanning, no domain-specific pattern matching, and no
  access in this script to a dispatch's raw command stdout/stderr at all. It only ever sees what
  the agent already wrote into its own artifacts.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`: Move 3 (`190-241`)
  accumulates every `verdict=ask_user` row into `mt_state_file`'s `pending_ask_user[]`,
  keyed `{task, decision}`. Move 4 (`282-307`) — after every task's Move 3 has run this cycle —
  calls `AskUserQuestion` once per entry, **batched**, in the root session (the only place it is
  reachable), then calls `orchestrate-record-decision.sh` per answer and clears the task's entry.
  A non-blocking decision proceeds on `recommended` without asking, "surfaced in the consolidated
  output" instead.
- `orchestrate-record-decision.sh`: the single sanctioned writer of `.decisions.json`, append-only,
  four required fields (`question`, `answer`, `cycle`, `timestamp`). Purely a recording of what
  was asked and answered — never an authorization token, never read by anything that changes gate
  or approval state.

**Conclusion**: every piece of plumbing the task description names as "already measured" is
real, reachable, and needs zero modification. The task's own `proposed_file_scope` (recorded at
task-creation time in `.return-meta.json`, before any research) names
`skill-orchestrate/SKILL.md`, `orchestrate-cycle-postflight.sh`, and
`orchestrate-record-decision.sh` as likely touch points. Research does not support touching any
of the three — the generic relay already does everything this task needs of it, and touching it
would be exactly the "new interaction machinery" the dispatch's own "KEEP IT MODEST" section warns
against as a drifted design.

### Where detection can live — ruling, with its reason

**Ruling: the books agent definitions, not postflight, and not "both."**

Reasons, in order of how directly they settle the question:

1. **Postflight has no raw signal to classify.** `orchestrate-cycle-postflight.sh` reads
   `.return-meta.json`/the handoff and a fixed small set of artifact-existence/git-state probes —
   never a dispatch's own captured command output. Unless the agent itself preserves the
   distinguishing text somewhere postflight reads, postflight has structurally nothing to pattern-
   match against. "Postflight classification" as a candidate seam presupposes a signal postflight
   does not have.
2. **The `user_decision` contract is explicitly producer-owned.** `user-decision-contract.md`'s
   own words: "Agents decide... never invented or requested by the orchestrator itself," and the
   "Producer Ownership" section states any later writer (naming `skill-orchestrate`'s own
   postflight stage explicitly) "MUST merge onto the existing file and leave `user_decision`
   untouched rather than overwrite it." A postflight-side classifier that *originates* a
   `user_decision` from stage-result text would be the orchestrator deciding on the user's behalf
   about what counts as an approval need — the exact inversion the contract's opening sentence
   rules out.
3. **"Both" collapses to "agent only."** Since postflight cannot originate or reinterpret
   `user_decision`, a "both" design could only mean: the agent sets it, and postflight
   additionally re-validates or double-classifies the same signal. That is strictly additional
   machinery with no payoff — nothing in postflight's current architecture needs a second opinion
   on a field it already relays unconditionally — so it fails the dispatch's own "KEEP IT MODEST"
   bar.
4. **The agent is the only party present at the moment of failure with the information needed.**
   Whatever gate command surfaces "absent-or-stale approvals" runs inside the dispatched agent's
   own Bash calls; the agent is the only thing that ever sees the gate's actual stderr/exit.

This settles scope item (1): the detection rule is added to the books agent definitions that can
run a gate command during their own work — currently the plain and hard **implementation** agents
(`books-implementation-agent.md`, `books-implementation-hard-agent.md`). Postflight and
`skill-orchestrate` require no change.

### Where in the books agents — no single fixed hook exists today

`books-implementation-agent.md` Stage 5 ("Final Verification", lines 153-202) runs a fixed
sequence: `lake build`, `books-tool validate`/`check`, and — only "when the plan's scope reaches
graph-wide certification" — the certify driver's `--check`. None of these three commands is the
fail-closed, per-component `full-gate.sh`/`check.sh` pipeline that (per the companion `/approve`
work's own comments, in `agent-system/extensions/approvals/scripts/approve-guard.sh`) is where a
`components/*/scripts/check-approvals.sh`-class check would actually run. `books-gate.sh` (the
advisory `--gate` tier wired into the same Stage 5, lines 158-197) is explicitly two legs only —
layer-lint and a `Books.Meta` import/require closure check — and has no approvals leg at all.
`books-research-agent.md` only *reads* certifier output for live-tree verification before
planning; it does not run or depend on the component gate either.

Per `context/project/books/domain/gate-tiers.md`, the fail-closed `full-gate.sh` is a ~10-minute,
consent-gated, per-component script resolved by a route and typically invoked directly by a
person or by a plan-directed Bash step when a task's own plan calls for a component-gate run —
never a fixed numbered stage every books dispatch runs automatically (that would make the
~10-minute tier mandatory on every dispatch, which gate-tiers.md documents as neither how it is
used today nor something any current tier promotion criterion justifies).

**Consequence for design**: the new recognition rule cannot be phrased as "add a check after
Stage 5's certify `--check`" — it has no fixed home today. It must instead be a cross-cutting
instruction (most naturally sited near Stage 5's existing gate-tier guidance, but worded to apply
to *any* gate/check command the dispatch runs, plan-directed or fixed) of the shape: "whenever a
component-gate command this dispatch runs fails specifically on the approvals leg's
absent-or-stale-records signature, do not report a bare verification failure — set `user_decision`
instead, per the shape below." `books-research-agent.md` is unlikely to need the same instruction,
since research dispatches do not run build/gate commands at all in the current contract.

### The exact detection signature is an open gap, not yet pinned

The task description's own motivating episode ("nineteen specifications needed re-approval after
a namespace move... the stale `framed_channel` specifications") is confirmed, independently, by
`agent-system/extensions/approvals/context/project/approvals/standards/approval-artifact-convention.md`
line 49, which names the exact same episode as the no-task adhoc-review precedent `/approve` was
built to cover. That confirms the scenario is real and that `check-approvals.sh` is the component-
owned script in question — but `check-approvals.sh` and `approve.sh` live exclusively in the
Logos/Verification repository (per task 350's own Out of Scope section and per 349's summary,
"Agents write prose; PEOPLE write records" is a *different* contract — `books/tool/approve-
guarantees.sh` — not this one). Neither script's source is present anywhere under
`agent-system/` in this repository, so this research cannot state the literal stderr text or exit
code `check-approvals.sh` uses to distinguish "absent-or-stale" from any other red.

The one available indirect evidence is `approve-guard.sh`'s own comment (naming
`check_by`/`check_assisted_by` as the precedent it mirrors) and this codebase's house convention
— visible in `approve-guard.sh` itself — of refusal messages shaped `refused (<reason-tag>):
<detail>` on stderr with a non-zero exit. It is plausible but **not confirmed** that
`check-approvals.sh`/`full-gate.sh`'s underlying `check.sh` follows the same convention. A coarse
rule ("any non-zero exit from the component gate means approval is needed") would be wrong and
risky: `check.sh` fails for many unrelated reasons (sorry count, SPDX header, extraction audit —
see `gate-tiers.md`'s "Checks" row for `full-gate.sh`), and misclassifying an ordinary proof
failure as "approval needed" would be a false, confusing offer. **The plan phase must read the
actual `check-approvals.sh`/`check.sh` text (in the Logos/Verification repository, or via the
sibling task `owner_labeled_agent_assisted_approvals`) to pin the literal distinguishing marker
before the detection instruction can be written precisely.** This research flags the gap rather
than guessing at the marker.

### The hand-off design — a close, already-built precedent to reuse exactly

`agent-system/extensions/core/context/standards/push-consent-relay.md` solves a structurally
identical problem: a dispatched agent's sanctioned endpoint (a `git push`) requires an action only
a human can take, `AskUserQuestion` is unreachable from the dispatch, and the relay must not let
a "yes" become a disguised self-authorization. Its resolution, verified empirically in that
document (a `ToolSearch` for `AskUserQuestion` from inside a dispatch returns no matching
deferred tool) and load-bearing for this task too:

> "The relay answer is not the mint... A YES answer tells the human the exact `/please` line to
> type; the human's own prompt submission is the only mint path."

This is the right template for scope item (4)'s hand-off. The "enter review now" option's
relayed answer should be the literal `/approve <component> [--task N]` invocation line (component
and scope/task filled in from what the detecting agent already knows), for the owner to type
themselves in a later, separate turn — never an automatic chained `Agent`/Bash invocation of
`/approve` from inside the same autonomous cycle. Three independent reasons converge on this,
not one:

1. `skill-approve`'s own Stage 2 (`agent-system/extensions/approvals/skills/skill-approve/SKILL.md:45-51`)
   already refuses to proceed when its own delegation context carries `orchestrator_mode: true` —
   "An autonomous `/orchestrate` cycle must never answer this prompt on the owner's behalf." If
   task 350's hand-off tried to auto-invoke `/approve` from within an autonomous dispatch, it
   would hit this refusal immediately — confirming the hand-off must not even attempt it.
2. `/approve`'s whole flow is direct-execution-only, declaring `AskUserQuestion` in its own
   `allowed-tools`, "by design," specifically because it cannot be delegated
   (`approvals/README.md`'s "Why `/approve` Is Never Dispatched"). There is no mechanism by which
   a books agent — itself a dispatched subagent — could invoke `/approve`'s interactive flow even
   if it tried.
3. The push-consent-relay precedent's own stated rationale generalizes directly: "an automated
   process asking a human to type a specific, pre-chosen authorization-granting string" handled
   correctly requires "the human must take a wholly separate, later action... There is no path
   from 'agent asks' to [the sensitive action happening] that skips the human's own deliberate
   keystroke." The same applies here: owner-labeled approval must stay genuinely owner-initiated.

This design satisfies scope item (3) (the no-human-attached case) **by construction, not by new
detection**: the question is always safe to queue via `user_decision` regardless of whether a
human happens to be present at the moment it is raised (the relay waits for the next natural
batching point, same as every other `user_decision`); and the one place that genuinely requires a
present human — actually running `/approve`'s `AskUserQuestion` — is already, and independently,
guarded by `skill-approve`'s own Stage 2. Task 350's books-side detection never needs to probe for
human presence itself; it only needs to never auto-invoke `/approve`, which the design above
already guarantees.

### Decline and defer semantics — confirmed to need no new mechanism

- **Decline**: nothing in the current codebase has a path that would mark an absent-or-stale
  approval record as approved, waived, or downgraded as a side effect of answering a
  `user_decision` (recorded answers only ever land in `.decisions.json`, which
  `push-consent-relay.md`'s own "Replay Hazard" section confirms is purely informational and is
  never consulted by any guard/gate). The honesty requirement in scope item (2) — "declining
  leaves the gate leg RED" — is therefore the natural, do-nothing consequence of this design, not
  something that needs to be built: the only genuine risk is a *future* implementer adding a
  shortcut that reads `.decisions.json` and treats a recorded "decline" answer as grounds to
  suppress the stage-failure classification. This should be stated explicitly as a prohibition in
  the implementing plan, not left implicit.
- **Defer**: "the need survives the deferral and is raised again on a later run" is likewise the
  natural consequence of adding no suppression state: since nothing in this design marks a task
  "already asked, do not ask again," the exact same detection rule fires on the next dispatch that
  hits the same gate failure, and a fresh `user_decision` is raised. No new state file or
  re-prompt-suppression counter is needed, and adding one would be exactly the kind of new
  machinery the dispatch's "KEEP IT MODEST" section warns against.

### A concrete recommendation for the `user_decision` shape

Based on the contract's documented three qualifying shapes and the `blocking` semantics in
`user-decision-contract.md`:

- `blocking: false`, `recommended` = the "defer" option. Reasoning: "entering review now" cannot
  be the non-blocking default, because nothing can act on it without a human's own keystroke (the
  same structural reason `push-consent-relay.md`'s push-class decisions are always `blocking:
  true`) — recommending it as the silent default would be procedurally meaningless. "Decline"
  must never be a silent default (scope item (2)'s honesty requirement reads naturally as "the
  owner must affirmatively choose to decline," not have it chosen for them). "Defer" is the one
  option that is genuinely free to take as a default: fully reversible, costs nothing, and is
  exactly the shape `user-decision-contract.md` names for `blocking: false` — "reversible choices
  where proceeding on the agent's best judgment costs nothing if the user later disagrees."
- `options[]` as three flat, self-describing strings (no `description` field exists on this
  schema) naming the component/task/scope explicitly in each string, mirroring
  `push-consent-relay.md`'s own worked example (e.g. `"Enter review now — run /approve
  <component> --task <N> yourself in your next turn"`, `"Defer — ask again on a later run"`,
  `"Decline — leave <component>'s approval records as-is; the gate stays red"`).

## Decisions

- **Detection seam (scope item 1)**: books agent definitions only — specifically the plain and
  hard **implementation** agents (`books-implementation-agent.md`,
  `books-implementation-hard-agent.md`), as a cross-cutting rule rather than a fixed Stage 5
  sub-step, since no fixed hook exists today and the fail-closed gate is plan-directed, not
  automatic. Postflight and `skill-orchestrate` require no change — the generic relay already
  does everything needed, and the `user_decision` contract's producer-ownership model forecloses
  postflight from originating or reinterpreting the signal. Reason recorded here per the
  dispatch's own requirement that the ruling carry its reason, not merely its choice.
- **Hand-off mechanism (scope item 4)**: the "enter review now" option's relayed answer is the
  literal `/approve <component> [--task N]` command line for the owner to type themselves — never
  an automatic chained invocation — reusing `push-consent-relay.md`'s YES-mints-nothing design
  exactly rather than inventing a books-specific variant.
- **No-human case (scope item 3)**: resolved by the hand-off design above, not by new detection in
  the books agent; `skill-approve`'s existing `orchestrator_mode: true` Stage 2 refusal is the
  mirror this task's dispatch text asks for, reached naturally because the hand-off never attempts
  to invoke `/approve` autonomously in the first place.
- **Decline/defer (scope item 2)**: require no new state or mechanism; both are the natural
  consequence of adding no suppression/approval-shortcut logic. The plan should state the
  "never suppress on decline" rule as an explicit prohibition for a future implementer to find.

## Recommendations

1. Do not modify `skill-orchestrate/SKILL.md`, `orchestrate-cycle-postflight.sh`, or
   `orchestrate-record-decision.sh`. Scope the implementing plan to the books agent definitions
   (`books-implementation-agent.md`, `books-implementation-hard-agent.md`) plus whatever shared
   books context doc records the recognition rule and the ruling's reason (a natural home:
   alongside `context/project/books/domain/gate-tiers.md`, which already documents what each gate
   tier does and does not check).
2. Before writing the detection instruction's literal text, read `check-approvals.sh` and/or
   `check.sh`/`full-gate.sh` directly (in the Logos/Verification repository, or via the sibling
   task `owner_labeled_agent_assisted_approvals`) to pin the exact absent-or-stale failure
   signature. Do not substitute "any non-zero exit from the gate" — that would misclassify
   unrelated gate failures (sorry count, SPDX, extraction audit) as approval requests.
3. Phrase the new books-agent instruction as a cross-cutting rule triggered by the gate's output
   shape, not as a fixed addition to Stage 5's numbered sequence, since the fail-closed gate is
   plan-directed rather than automatically run by every dispatch today.
4. Shape the `user_decision` exactly as: `blocking: false`, `recommended` = the "defer" option,
   three flat self-describing `options[]` strings naming the component/task explicitly, following
   `push-consent-relay.md`'s worked example format.
5. Implement the "enter review now" hand-off as a relayed command line for the owner to type,
   never as an automatic `/approve` invocation from within the autonomous dispatch — this is both
   the only mechanism that actually works (`/approve` cannot be delegated) and the thing that
   satisfies the no-human-attached requirement without new detection logic.
6. State explicitly, as a line in the plan and in the books agent instruction itself, that a
   recorded "decline" or "defer" answer must never be read by any later check as grounds to treat
   the approval requirement as satisfied, waived, or downgraded — closing off the one way this
   design could regress from "honest red" to "silently green" even though nothing currently does
   that.
7. Treat `books-research-agent.md` as out of scope for the detection instruction unless a future
   reading of research-dispatch plans shows a research agent ever runs a component gate command
   (not observed in current agent definitions).

## Risks & Mitigations

- **Risk**: the detection marker text is unconfirmed (see Findings). **Mitigation**: the plan
  phase must read the real script before finalizing the instruction; this report names the exact
  file and repository to read, and recommends against a coarse substitute.
- **Risk**: a future edit could make "decline" or "defer" silently satisfy the approval
  requirement by having some other check read `.decisions.json` as evidence of resolution.
  **Mitigation**: state the prohibition explicitly in both the plan and the books-agent
  instruction (Recommendation 6), and consider a test asserting that a recorded decline answer
  does not change `check-approvals.sh`'s own verdict (bounded by what is testable from this
  repository — the real script is external).
- **Risk**: adding the recognition rule to only the plain and hard implementation agents misses a
  path if a future books dispatch type runs a component gate elsewhere (e.g. a hypothetical
  books-certify-only dispatch). **Mitigation**: word the rule once, in a shared books context doc
  both agent files reference, so a future third agent definition can adopt it by reference rather
  than by copy-paste drift (the existing `--gate` advisory tier text is already duplicated
  verbatim across the plain/hard agent files, which is the precedent to avoid repeating a third
  time if a shared doc is feasible).

## Context Extension Recommendations

- **Topic**: the component gate's approvals leg and its failure signature.
- **Gap**: `context/project/books/domain/gate-tiers.md` documents every tier's checks in detail
  but does not mention an approvals/`check-approvals.sh` leg at all — because, per this research,
  that leg lives entirely in the consumer repository and has never been described from the
  agent-system side. Once the plan phase pins the real signature (Recommendation 2), it should be
  recorded in a books-domain context file (e.g. a new section in `gate-tiers.md` or a dedicated
  `domain/approvals-detection.md`) so future books-agent work does not have to re-derive it by
  reading the external script again.

## Appendix

### Files read

- `specs/350_offer_owner_review_when_approval_needed/.dispatch/13.md` (this dispatch)
- `specs/350_offer_owner_review_when_approval_needed/.return-meta.json` (task-creation metadata)
- `specs/state.json` (task 350's entry)
- `specs/archive/349_add_approve_command_owner_labeled_approvals/summaries/01_approve-command-owner-labeled-approvals-summary.md`
- `agent-system/extensions/approvals/README.md`
- `agent-system/extensions/approvals/commands/approve.md`
- `agent-system/extensions/approvals/skills/skill-approve/SKILL.md`
- `agent-system/extensions/approvals/scripts/approve-guard.sh`
- `agent-system/extensions/approvals/context/project/approvals/standards/approval-artifact-convention.md`
- `agent-system/extensions/core/context/standards/user-decision-contract.md`
- `agent-system/extensions/core/context/standards/push-consent-relay.md`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Move 3/Move 4 sections)
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (user_decision relay and
  verdict-derivation sections)
- `agent-system/extensions/core/scripts/orchestrate-record-decision.sh`
- `agent-system/extensions/books/agents/books-implementation-agent.md`
- `agent-system/extensions/books/agents/books-implementation-hard-agent.md`
- `agent-system/extensions/books/agents/books-research-agent.md`
- `agent-system/extensions/books/context/project/books/domain/gate-tiers.md`
- `agent-system/extensions/books/context/project/books/standards/reconciliation-contract.md`
- `agent-system/extensions/books/context/project/books/tools/tooling-inventory.md`
- `agent-system/extensions/books/scripts/books-gate.sh` (header and derivation logic)

### Searches performed

- `grep -rn "component gate\|approvals stage\|absent-or-stale"` across `agent-system/`
- `grep -rln "check-approvals\|approvals.yaml"` across `agent-system/`
- `grep -n "Move 3\|Move 4\|pending_ask_user\|ask_user"` in `skill-orchestrate/SKILL.md`
- `grep -n "ask_user\|user_decision"` in `orchestrate-cycle-postflight.sh`
- `grep -n "full-gate\|check\.sh"` across the books extension's context/patterns files

### Not available to this research

- The Logos/Verification repository's `components/*/approve.sh`, `check-approvals.sh`, and
  `full-gate.sh`/`check.sh` source — a separate repository, not present in this session's working
  directory. The exact absent-or-stale detection marker must be read from there during planning.
