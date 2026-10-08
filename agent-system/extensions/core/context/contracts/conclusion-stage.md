# Orchestration Conclusion Stage (Move 5)

## Overview

The conclusion stage is a distinct stage of `/orchestrate`, running **exactly once per
invocation**, strictly **after** the batch's own Move 4 finalization sequence has emitted its
consolidated output and closed and committed its own state. It is not a per-task step and it is
not folded into any per-dispatch postflight — see
`context/standards/postflight-tool-restrictions.md`'s "Conclusion Stage (Move 5) Tool
Restrictions" section for the boundary that keeps it a separate actor from Move 3 postflight.

The stage proposes three channels of follow-on work, derived from evidence rather than composed
from the orchestrator's own recollection of the run:

- **(a) Direct fixes** to make now, executed by a dispatched implementation agent.
- **(b) Agent-system changes**, routed to `meta-builder-agent` as a change request.
- **(c) Follow-up tasks**, created as children of the task whose issue log raised them, via the
  `parent_task` edge.

Each channel fires **only** on that channel's own separate, explicit user approval. No channel
may fire on another channel's approval, and none may fire without one. This invariant is the
stage's load-bearing acceptance claim and is proven mechanically, not only stated in prose — see
"The Approval Ledger" below and `scripts/orchestrate-conclusion-aggregate.sh`'s
`--record-approval` / `--check-approval` pair.

This file's companion section, "## The Executable Stage Body" (added once the mechanical half of
the stage exists), is the verbatim-executed procedure. This half — the derivation contract — is
loaded first and describes *where the stage's content comes from* and *how an entry becomes a
proposal*, independent of the step-by-step execution mechanics.

## The Evidence Base

The stage's proposals are not composed from memory of the run. They are **derived from the
per-task issue logs** of every task the invocation touched: `specs/{NNN}_{SLUG}/issues.jsonl`,
written by `scripts/issue-record.sh` (see `context/formats/issue-log.md` for the full schema).
That log is the sole payload source for this stage's three channels.

`.return-meta.json`'s `metadata.detected_defects` field and the "System Defects Detected" output
table documented in `commands/orchestrate.md` are a **separate, unconditional, ungated
observation channel**. They are never merged into or subsumed by this stage, for a structural
reason: they are engine-written only — populated by the orchestrator's own mechanical defect
detection — never subagent-written, and they render unconditionally on every invocation rather
than being filtered, grouped, and gated behind a per-channel approval. A gated, evidence-cited
proposal mechanism and an unconditional, ungated detection table answer different questions and
must stay visibly distinct to a future reader; see
`context/standards/postflight-tool-restrictions.md`'s Move 4 section for where that table's own
contract lives. `commands/orchestrate.md`'s `## Output` section states this sibling relationship
explicitly, so a future reader does not attempt to merge them.

## The Filter Predicate

An `issues.jsonl` entry enters classification only when its `resolution` field is `open` or
`worked_around`. An entry with `resolution: "fixed_inline"` is already closed and generates no
channel item — nothing remains to propose.

`kind: "win"` entries are an exception to the resolution filter in the opposite direction: they
are **summarised, never actioned**, regardless of `resolution`. A win is positive signal — what
the issue-log convention bought — and belongs in the stage's report so the user can see it, but
it never becomes a fix, a task, or a change request.

## The Exactly-One-Channel Rule

Every classified entry (every `open`/`worked_around`, non-win entry) lands in **exactly one** of
the three channels — (a) fix-now, (b) agent-system change, (c) follow-up task. An entry may not
appear in two channels. If an entry's nature seems to straddle two channels, the orchestrator
resolves it to the one channel where the proposed action actually executes, and may note the
secondary angle in that proposal's own text — but it is still cited from one channel only.

## The Hint-Versus-Decision Rule

An entry's own `suggested_channel` field (`fix_now` | `follow_up_task` | `agent_system`) is a
**hint**, written by whichever dispatch recorded the entry. The **orchestrator's judgment is the
decision**. When the orchestrator's classification disagrees with the hint, the override is
stated **visibly** in the proposal text — naming both the hint that was given and the channel
actually chosen, and why. A hint that is silently overridden defeats the purpose of recording it
at all.

## The Cross-Task Grouping Rule

When the same `class` of issue recurs across two or more tasks touched by this invocation, it
becomes **one proposal**, citing every contributing entry — never one proposal per task. This is
the central reason the derivation step is worth doing at all: a recurring class is invisible from
any single task's own issue log, and only becomes visible once the logs are aggregated across the
whole batch. `scripts/orchestrate-conclusion-aggregate.sh --aggregate` performs this grouping
mechanically, grouping by `class` across every touched task's log before the orchestrator applies
channel judgment on top of the grouped result.

## The Citation Requirement

Every proposal — in every channel — cites the issue-log entries it is built from, as a list of
`{task number, entry_id}` pairs. **A proposal with no citation is not presentable.** This lets the
user audit a proposal against its evidence before approving the channel that would act on it. A
proposal spanning three tasks' recurring class carries three citations, one per contributing
entry (or more, if a task logged the class more than once).

## The Unknown-Class Tally

`issue-record.sh`'s `class` field is deliberately open, not a closed enum (see
`context/formats/issue-log.md`'s "Extensibility Rule"). This stage is the consumer that discharges
the obligation that document already records: it tallies, across every touched task, every entry
whose `class` falls outside the 15-class seed enum in `context/formats/issue-log.md`, and reports
the tally (class name and per-class count) alongside the three channels. A class that recurs often
enough across invocations is a candidate for promotion into that document's seed list in a future
revision — that promotion is a documentation change there, never an enforcement change in the
writer, and never a decision this stage makes unilaterally.

## Review Happens Only At This Stage

This is the explicit complement of `context/formats/issue-log.md`'s CAPTURE ONLY boundary: nothing
in `issues.jsonl` is surfaced, summarised, or acted on mid-run, by any dispatch, at any phase.
Review — reading the aggregated logs, classifying entries into channels, and presenting the three
gated proposals — happens exclusively here, once per invocation, after Move 4. If a mid-run
surface is ever judged necessary, it is added **by amending this contract**, never improvised
ad hoc inside `issue-record.sh`, a phase-closure dispatch, or any other writer. The two documents
(the capture-only boundary and this review-only boundary) must not drift apart.

## The Coexistence Boundary With the Skeleton-Plan Follow-Up Mechanism

This stage coexists with, and does not overturn, the existing skeleton-plan strategic-sorry
follow-up mechanism. That mechanism is narrowly scoped: it fires inside
`scripts/orchestrate-cycle-postflight.sh`'s `implemented)` case, triggers only when the final
implement handoff carries `skeleton: true` together with a non-empty `sorry_inventory[]`, and its
"the human files any follow-up with `/task`" clause is documented in
`context/standards/status-markers.md`'s `[COMPLETED]` section ("Skeleton-plan terminus"
subsection). Its payload — one entry per strategic sorry — is surfaced in the cycle's stderr
report and recorded append-only on the task's `skeleton_follow_ups` state.json array; it is never
auto-filed as a task.

This stage is a different mechanism on every one of those axes: it is task-type-agnostic (not
scoped to a skeleton Lean plan), it fires once per `/orchestrate` invocation rather than at one
task's own postflight, it derives its proposals from the aggregated `issues.jsonl` logs rather
than from a single handoff's `sorry_inventory[]`, and it gates creation behind an explicit
per-channel `AskUserQuestion` approval rather than leaving all filing to the human outside the
tool entirely.

**The two mechanisms are disjoint, not contradictory, and both stay exactly as written.** Nothing
in the skeleton-plan terminus paragraph is edited by this stage, and nothing in this stage reaches
into `orchestrate-cycle-postflight.sh`'s `implemented)` case. The alternative that was considered
and rejected — narrowly overturning the skeleton-plan mechanism's "the human files any follow-up"
clause so that channel (c) above absorbs it too — was rejected because: (1) the two mechanisms
already produce the same operational outcome by different, non-conflicting routes, so no user-
visible gap is closed by merging them; and (2) merging them would require rewriting an already-
implemented, already-documented, narrowly-scoped ruling for no behavioral gain, trading a settled
boundary for a speculative simplification. The cost this leaves standing — two adjacent mechanisms
producing follow-ups by two different routes — is accepted rather than paid for by a rewrite; a
future task may reconsider that trade once more operational experience with both exists, but this
stage does not pre-empt that reconsideration.

## Two Flags For the User, Not Silent Edits

This stage's own design surfaced two gaps in adjacent machinery that are **this task's territory
to flag, not to resolve**, because resolving either would mean editing another task's file:

1. **The roadmap generator's documented caller split** (`/review` regenerates,
   `/todo` prunes) does not currently name `/orchestrate`'s conclusion stage as a third caller,
   even though this stage's own roadmap-update step (see "## The Executable Stage Body") invokes
   its `--regenerate` mode. Whether that caller-split documentation needs a sentence added for the
   new caller is a question for whoever owns that generator's own description, not something this
   stage resolves by editing it directly.
2. **Neither `/todo` nor `/review` wires the roadmap generator's other mode to its own command
   today** — a pre-existing, independently recorded gap in the generator's own caller contract,
   unrelated to and not created by this stage. Recorded here only so a future reader sees it named
   rather than silently worked around.

Both flags are carried forward into the stage's own Step 6 report (see "## The Executable Stage
Body") so the user sees them at the moment they can act, rather than only in this file.

## Relationship to the Approval Ledger

The per-channel approval gate described above is backed by a durable ledger, written and read by
`scripts/orchestrate-conclusion-aggregate.sh`'s `--record-approval` / `--check-approval` pair: one
record per channel per invocation, under `specs/.orchestration/`. `--check-approval` is the one
deliberate fail-closed guard in this codebase's otherwise fail-open posture — an absent record, a
`no`, or a malformed ledger all read as **not approved**, never as approved by default. See that
script's own header comment for the full CLI contract; this section exists only to state that the
ledger, not prose convention alone, is what makes "no channel fires on another's approval"
mechanically true rather than merely asserted.

Deriving a proposal from this evidence base is never, by itself, approval to fire it. The
per-channel explicit-approval contract stated in the Overview above is unconditional and is not
loosened by anything in this derivation half.
