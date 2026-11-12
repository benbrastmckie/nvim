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
- **(b) Agent-system changes**, recorded as evidence for a later, deliberate consumer — never
  dispatched or executed by this stage.
- **(c) Follow-up tasks**, recorded as evidence for the same deliberate consumer — never created
  as task directories by this stage.

Only channel (a) executes anything. Channels (b) and (c) append their classified proposals,
with citations, to the durable evidence store (see "The Executable Stage Body" below) and do
nothing else — no dispatch, no task creation, no `specs/state.json` write. Channel (a) fires
**only** on its own separate, explicit user approval, and no channel may fire on another
channel's approval. This invariant is the stage's load-bearing acceptance claim and is proven
mechanically, not only stated in prose — see "The Approval Ledger" below and
`scripts/orchestrate-conclusion-aggregate.sh`'s `--record-approval` / `--check-approval` pair.

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
channel item — nothing remains to propose. A null or omitted `resolution` is read identically to
`open`: `issue-record.sh` never requires the flag, so an entry written without it must still be
reachable here rather than silently dropped. Four field states are therefore possible —`open`,
`worked_around`, `fixed_inline`, and null/omitted — and the predicate above accounts for all
four, not three.

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

## The Implicit-Open Tally

`--aggregate`'s output also carries `implicit_open_count`: the count of non-win candidates that
reached classification because their `resolution` was null or omitted, rather than an explicit
`"open"`. This is informational only — it preserves the provenance signal the null-to-`open`
coalescing in "The Filter Predicate" above would otherwise discard, so the user can see how many
of a batch's proposals rest on an author's omission rather than an explicit mark. Like the
unknown-class tally above, it is never a decision this stage makes unilaterally — it carries no
channel, gates nothing, and does not change which channel a proposal lands in.

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

## Roadmap Generator Caller Status

The roadmap generator's caller split — including this stage as a `--regenerate` caller, and the
ruling on whether `/todo`/`/review` wire the generator's other modes — is documented in full in
`context/patterns/roadmap-update.md`. This stage's own roadmap-update step (see "## The
Executable Stage Body") is that contract's documented conclusion-stage caller.

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

## The Executable Stage Body

Executed verbatim by the orchestrate lead, once per invocation, immediately after Move 4's full
finalization sequence (consolidated output, residue check, session-registry release,
`.dispatch/` removal, and the multi-task `.return-meta.json` write) has completed — never
interleaved with it, never run for a per-task Move 3. This section follows the same
single-executable-block pattern as `context/patterns/lit-stage4a-flow.md`: every instruction
below is direct and executable, not commented-out pseudocode. Tool and commit surfaces are
governed by `context/standards/postflight-tool-restrictions.md`'s "Conclusion Stage (Move 5) Tool
Restrictions" section; nothing below expands that surface.

### Step 1 — Aggregate

Invoke the aggregator with this invocation's session id and the full list of tasks the
invocation touched this run:

```bash
aggregate_json=$(bash .claude/scripts/orchestrate-conclusion-aggregate.sh --aggregate \
  --session "$session_id" --tasks "${touched_tasks[*]}")
```

Parse `$aggregate_json` for `proposals[]` (each carrying `class`, `citations[] = [{task,
entry_id}]`, `citations_remainder` (an integer, `0` when nothing was withheld), `severity_max`,
`suggested_channel_hints[]`), `wins[]`, `unknown_classes[]`, `implicit_open_count`, and
`no_contribution_tasks[]`.

**Citation render cap**: `citations[]` renders at most the first 10 entries of a class's full
candidate set; `citations_remainder` names the exact count withheld (never a silent truncation —
when 10 or fewer candidates exist, `citations_remainder` is `0` and every one is rendered). This
is the read-side half of the general occurrence-collapse rule (`context/formats/issue-log.md`'s
"Occurrence Collapse" subsection is the write-side half): a long outage emitting scores of
same-class rows, or a single dispatch emitting dozens of same-path rows, produces a readable
proposal rather than an unbounded list. The full candidate set is never discarded — it remains
intact in the per-task `issues.jsonl` logs the aggregator itself read from; the cap narrows only
what this one render shows. A rendered proposal citing a capped class MUST surface the withheld
count (e.g. "...and 5 more") rather than silently rendering only the first 10.

### Step 2 — Classify (judgment, the lead's own)

For each entry in `proposals[]`, assign it to exactly one of the three channels — (a) fix-now,
(b) agent-system change, (c) follow-up task — per `context/contracts/conclusion-stage.md`'s own
exactly-one-channel rule above. When the chosen channel differs from the proposal's
`suggested_channel_hints`, state the override visibly: name both the hint and the chosen channel
in that proposal's rendered text. Compose each channel's proposal text with its citations
(`task` + `entry_id` pairs, never omitted), and when `citations_remainder` is nonzero, append
the exact withheld count to that proposal's own text (e.g. "...and 5 more") — never a silent
truncation. Summarise `wins[]` for the report (never actioned).
Carry `unknown_classes[]`, `implicit_open_count`, and `no_contribution_tasks[]` into the report
as-is (Step 6).

### Step 3 — Channel (a)'s gate

Only channel (a) executes a consequence, so only channel (a) is gated by an `AskUserQuestion`.
When channel (a) ended up with at least one classified proposal, ask one `AskUserQuestion`
presenting its proposals and their citations only, and record the answer:

```bash
bash .claude/scripts/orchestrate-conclusion-aggregate.sh --record-approval \
  --session "$session_id" --channel a --answer yes   # or "no", per the answer given
```

Channel (a) with zero classified proposals is never asked about and is skipped entirely (no
ledger record, no Step 4a execution). **No channel may fire on another channel's approval, and
channel (a) may not fire without its own recorded "yes"** — this is enforced mechanically by
Step 4a's own `--check-approval` gate, not only by this prose. Channels (b) and (c) record their
proposals as evidence (Steps 4b/4c below) regardless of any approval state — recording has no
consequence to gate.

### Step 4a — Channel (a) execution: direct fixes

Gate:

```bash
if bash .claude/scripts/orchestrate-conclusion-aggregate.sh --check-approval \
     --session "$session_id" --channel a; then
  # proceed with channel (a) below
  :
fi
```

Only when that gate passes: dispatch an implementation agent (`general-implementation-agent`,
per this task's D6 — no new agent type) with a purpose-built body naming the approved fix list
verbatim, its citations (`task` + `entry_id` per fix), and an explicit restatement of the
`source-store-deploy-boundary` requirement (fixes land in the source store, never hand-authored
under `.claude/**`). After the dispatch returns, commit via:

```bash
bash .claude/scripts/git-commit-scoped.sh --session "$session_id" \
  --message "orchestrate conclusion: channel (a) direct fixes" \
  -- "${channel_a_fix_paths[@]}"
```

where `channel_a_fix_paths` is exactly the set of paths the dispatched agent actually touched for
the approved fix list — never a wider pathspec.

### Step 4b — Channel (b) recording: agent-system change evidence

No gate: recording has no consequence to approve. When channel (b) ended up with at least one
classified proposal, append one `events-append.sh` line per proposal to the durable evidence
store, then commit that file alone:

```bash
bash .claude/scripts/events-append.sh \
  --event-type conclusion_proposal_recorded --category milestone --session "$session_id" \
  --message "conclusion channel (b) proposal: $class" \
  --detail-json "$(jq -c -n \
    --arg channel b --arg class "$class" --argjson citations "$citations_json" \
    --argjson citations_remainder "$citations_remainder" --arg severity_max "$severity_max" \
    --argjson suggested_channel_hints "$suggested_channel_hints_json" \
    --arg orchestrator_channel b --arg override_rationale "$override_rationale_or_null" \
    '{channel: $channel, class: $class, citations: $citations,
      citations_remainder: $citations_remainder, severity_max: $severity_max,
      suggested_channel_hints: $suggested_channel_hints, orchestrator_channel: $orchestrator_channel,
      override_rationale: ($override_rationale | if . == "" then null else . end)}')"

bash .claude/scripts/git-commit-scoped.sh --session "$session_id" \
  --message "orchestrate conclusion: channel (b) proposals recorded" -- specs/events.jsonl
```

A channel (b) with zero classified proposals is skipped entirely — no event line, no commit.
`override_rationale` is non-null only when the orchestrator's channel judgment visibly overrode
a proposal's `suggested_channel_hints` (the Hint-Versus-Decision Rule above). This evidence is
consumed later, deliberately and in batches, by `/distill --meta` — never dispatched or acted on
by this stage itself.

### Step 4c — Channel (c) recording: follow-up-task evidence

No gate: recording has no consequence to approve. When channel (c) ended up with at least one
classified proposal, append one `events-append.sh` line per proposal, in the same shape as Step
4b but with `channel: "c"` (no `--channel` flag — the aggregator's ledger channel letter is
unrelated to this recording call), then commit that file alone:

```bash
bash .claude/scripts/events-append.sh \
  --event-type conclusion_proposal_recorded --category milestone --session "$session_id" \
  --message "conclusion channel (c) proposal: $class" \
  --detail-json "$(jq -c -n \
    --arg channel c --arg class "$class" --argjson citations "$citations_json" \
    --argjson citations_remainder "$citations_remainder" --arg severity_max "$severity_max" \
    --argjson suggested_channel_hints "$suggested_channel_hints_json" \
    --arg orchestrator_channel c --arg override_rationale "$override_rationale_or_null" \
    '{channel: $channel, class: $class, citations: $citations,
      citations_remainder: $citations_remainder, severity_max: $severity_max,
      suggested_channel_hints: $suggested_channel_hints, orchestrator_channel: $orchestrator_channel,
      override_rationale: ($override_rationale | if . == "" then null else . end)}')"

bash .claude/scripts/git-commit-scoped.sh --session "$session_id" \
  --message "orchestrate conclusion: channel (c) proposals recorded" -- specs/events.jsonl
```

A channel (c) with zero classified proposals is skipped entirely — no event line, no commit. No
task is created, no task directory is populated, and `specs/state.json` is not written. This
evidence is consumed later, deliberately and in batches, by `/distill --meta` — never created as
a child task by this stage itself.

### Step 5 — Roadmap update

Invoke the existing roadmap generator's regenerate mode — never reimplementing it:

```bash
bash .claude/scripts/roadmap-integration.sh --regenerate
```

Per this task's D3: `--prune` is deliberately out of scope for this stage (it removes content
outright, a stronger unattended action than an idempotent regenerate). Commit
`specs/ROADMAP.md` alone:

```bash
bash .claude/scripts/git-commit-scoped.sh --session "$session_id" \
  --message "orchestrate conclusion: roadmap regenerate" -- specs/ROADMAP.md
```

After the regenerate and its commit, run the advisory batch-proposal lint over the freshly
regenerated file:

```bash
bash .claude/scripts/lint/lint-roadmap-batch-proposals.sh
```

Its output is ADVISORY: the exit code is never acted on, and its findings are surfaced verbatim
with Step 5's own output. This is explicitly NOT a fourth channel — it derives from
`specs/ROADMAP.md`, carries no `AskUserQuestion` gate, and the Exactly-One-Channel and
Hint-Versus-Decision rules above do not apply to it, the same posture Step 7's suggester already
carries.

### Step 7 — Suggest next batch, and gate the edge write

(Numbered 7, positioned here between Step 5 and Step 6 rather than after Step 6, because its
output must exist before Step 6's report renders it — the number is this step's stable
identity across this contract and its callers, not a claim about textual ordering.)

Invoke the next-batch suggester (Mode A) in its default, non-`--write-edges` form. This step
is itself still INFORMATIONAL: it derives from `specs/state.json`, never `issues.jsonl`, and is
therefore NOT a fourth channel — the Exactly-One-Channel and Hint-Versus-Decision rules above
do not apply to it. The `edges` approval key introduced below is likewise NOT a fourth channel:
it is an independent, non-channel approval key, gated and read through the exact same
fail-closed `orchestrate-conclusion-aggregate.sh --record-approval`/`--check-approval`
mechanism as a channel, under its own `edges` key — so no channel's approval ever satisfies
`edges`, and an `edges` approval never satisfies any channel's gate.

```bash
suggest_output=$(bash .claude/scripts/orchestrate-suggest-next-batch.sh --next-batch --session-id "$session_id")
```

Its rendered output folds into Step 6's report below (the `**Suggested next batch**:` line in
the `### Conclusion` block) rather than forming a separate report section — see
`context/patterns/orchestrate-batch-results-template.md`'s Conclusion block for the exact
render shape, including the no-suggestible-batch, colliding-pair-sequence, multi-option, and
cap-reached cases.

**Edge-write gate.** When `$suggest_output` contains at least one line matching `proposed edge:`
(i.e. at least one colliding pair was found and an edge was proposed — see
`orchestrate-suggest-next-batch.sh`'s own `propose_edge_for_pair()`), gate the write behind one
explicit approval:

1. Ask one `AskUserQuestion` presenting the proposed edge(s) and their ordered-sequence line(s)
   only (never the joint-batch option lines, which carry no edge to approve), and record the
   answer under the dedicated `edges` key:

   ```bash
   bash .claude/scripts/orchestrate-conclusion-aggregate.sh --record-approval \
     --session "$session_id" --channel edges --answer yes   # or "no", per the answer given
   ```

2. Gate on that same key:

   ```bash
   if bash .claude/scripts/orchestrate-conclusion-aggregate.sh --check-approval \
        --session "$session_id" --channel edges; then
     # proceed with the write below
     :
   fi
   ```

3. Only when that gate passes, re-invoke the suggester with `--write-edges`, which performs the
   write and then RE-PROBES the same candidate set through the real admission check, showing
   both members flip to `admit`:

   ```bash
   bash .claude/scripts/orchestrate-suggest-next-batch.sh --next-batch --session-id "$session_id" --write-edges
   ```

   Fold that re-probe evidence into Step 6's report alongside the original suggestion, so the
   report shows both the proposed edge and its confirmed post-write admission.

A run with ZERO proposed edges is never asked about and skips this gate entirely — no
`AskUserQuestion`, no ledger record for `edges`, no second invocation — mirroring channel (a)'s
own zero-proposal posture in Step 3 above. A DECLINED approval leaves `specs/state.json`
byte-identical: the default (non-`--write-edges`) invocation above never mutates state, and the
write exists only inside the gated, `--write-edges` second invocation that a declined approval
never reaches.

### Step 6 — Report

Emit the conclusion report: the wins summary, channel (a)'s outcome (approved-and-executed,
declined, or not-asked-because-empty) with its citations, channels (b) and (c)'s outcome
(recorded-to-`specs/events.jsonl` with a proposal count, or not-recorded-because-empty) naming
`/distill --meta` as the command that will consume it, the unknown-class tally, the
zero-contribution dispatch list (`no_contribution_tasks[]`, cross-referenced with
`context/contracts/phase-closure.md`'s mandatory-attempt requirement — a listed task either
genuinely had nothing to record, or skipped the attestation). Render per
`context/patterns/orchestrate-batch-results-template.md`'s conclusion report block. Step 5's
advisory batch-proposal-lint findings (if any) appear with Step 5's own output above, not as a
separate section of this report.
