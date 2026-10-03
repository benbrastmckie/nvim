# Report != Termination: The Shared Root Cause

**Created**: 2026-08-12
**Purpose**: State once, canonically, the shared root cause behind a class of orchestrator
run-state-integrity defects, so individual fix sites can point at it instead of restating it.
**Audience**: `skill-orchestrate` (both effort modes, one engine), every dispatched agent that
writes a handoff or a territory declaration, and any future author of a mechanism that assumes a
dispatched agent is gone once it has reported.
**Related**: `../standards/orchestrator-runtime-files.md` (handoff tracking rationale),
`../contracts/territory.md` (Territory Declaration Template), `../formats/handoff-artifact.md`,
`docs/architecture/handoff-schema.md`

---

## The Model

**The system must never treat "a dispatched agent reported a result" as "that agent has
terminated."** A dispatch can resume after reporting — via a stale watcher/monitor it armed
before reporting, or via an operator-initiated resume of that same dispatch — and continue
running, committing, and writing files concurrently with whatever the orchestrator dispatches
next. Every mechanism that assumes single-writer exclusivity after a report is read must be
built to tolerate a still-live predecessor, not merely a finished one.

A "report" (a tool return, a handoff write, a `.return-meta.json` write) is evidence that the
dispatched agent reached a checkpoint where it chose to communicate state outward. It is not
evidence that the process producing that agent's behavior has stopped running. Any downstream
consumer that reads a report and then acts as though the reporting agent is now inert is making
an assumption the report itself never asserted.

## Two Named Instances

1. **Late handoff write inside the successor's dispatch window (Defect A)**: a woken predecessor
   writes `.orchestrator-handoff.json` after the orchestrator has already begun its next dispatch
   cycle. That write's mtime is necessarily *newer* than the moment the successor's dispatch
   window opened, so it falls inside the window by construction. Any staleness gate that relies
   on mtime alone — "is this handoff's mtime within my dispatch window?" — is structurally blind
   to this case: the late write looks exactly like a fresh, on-time report from the dispatch the
   orchestrator is actually waiting on. Discriminating the two requires content the woken
   predecessor cannot have produced — an orchestrator-minted `dispatch_seq` it never saw — not a
   timestamp comparison.

2. **Territory assertion read by a woken predecessor (Defect 5)**: a per-dispatch territory
   declaration that asserts "no other agent is concurrently active" is false the instant a
   predecessor wakes and resumes work, and the woken predecessor has no way to recognize its own
   liveness as the exception that assertion failed to name — it was told, truthfully at the time
   the declaration was written, that it owned exclusive territory, and nothing in that assertion
   invites it to reconsider once it wakes. A sound territory contract asserts only what is
   locally checkable (which files *this* dispatch owns) and instructs the agent to STOP and
   report anything it observes that contradicts exclusive ownership, rather than asserting a
   global absence of concurrency it cannot verify.

## Tear Down Watchers/Monitors Before Reporting

Because a wake path through a self-armed watcher or monitor is the concrete mechanism behind
both instances above, every agent that arms a watcher/monitor process during its own dispatch
MUST tear it down before reporting a terminal result. This reduces the wake path at its source
rather than only tolerating its consequences downstream. An agent that reports while a
watcher/monitor is still armed leaves exactly the conditions this pattern describes: a process
that can wake, observe stale context, and act as though it is still the current dispatch. The
same obligation applies before the watched build itself is cancelled or superseded (for example,
a re-run or a replacement build), not only before reporting — that transition is what orphans a
waiter loop even when the dispatch that armed it never reports at all.

## Where This Is Referenced

This file is the single statement of the model. Fix sites point at it with a one-line pointer —
they do not restate it:

- `skill-orchestrate/SKILL.md`'s Move 3 staleness-gate comment block (covering both effort
  modes; the formerly-separate hard-mode engine's own mirrored block was merged into this one)
- `context/contracts/territory.md`'s Territory Declaration Template
- `context/standards/orchestrator-runtime-files.md`'s `.orchestrator-handoff.json` tracking
  rationale entry
- the lean extension's `agents/lean-implementation-agent.md`'s Final Verification Stage build
  step ("Verify build passes")
- the lean extension's `agents/lean-implementation-hard-agent.md`'s Stage 4 step D ("Verify Phase
  Completion") and Stage 6 step 4 ("Verify build passes")
