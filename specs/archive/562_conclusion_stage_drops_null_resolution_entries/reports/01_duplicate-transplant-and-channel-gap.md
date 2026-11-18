# Research Report: Task #562

**Task**: 562 - conclusion stage drops null-resolution issue-log entries
**Started**: 2026-11-15T19:03:39Z
**Completed**: 2026-11-15T19:40:00Z
**Effort**: 1 hour
**Dependencies**: None
**Sources/Inputs**:
- `specs/562_conclusion_stage_drops_null_resolution_entries/.dispatch/2.md` (this dispatch)
- `specs/archive/373_null_resolution_entries_unreachable_by_conclusion_stage/` (absorbing duplicate record, full artifact set)
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` and its deployed mirror `.claude/context/contracts/conclusion-stage.md`
- `agent-system/extensions/core/context/formats/issue-log.md` and its deployed mirror `.claude/context/formats/issue-log.md`
- `agent-system/extensions/core/scripts/orchestrate-conclusion-aggregate.sh` and its deployed mirror
- `agent-system/extensions/core/context/patterns/cross-repo-task-migration.md`
- Live reproduction run: `bash .claude/scripts/orchestrate-conclusion-aggregate.sh --aggregate --session sess_research562_repro --tasks "436"` against `specs/436_orient_command_with_scout_agent_retire_review/issues.jsonl`
**Artifacts**: `specs/562_conclusion_stage_drops_null_resolution_entries/reports/01_duplicate-transplant-and-channel-gap.md` (this report)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The resolution-field half of the defect this record describes is **already fixed and
  deployed**: `conclusion-stage.md`'s Filter Predicate now reads a null/omitted `resolution` on a
  non-win entry identically to `open`, with an informational `implicit_open_count` tally added to
  both the contract and `orchestrate-conclusion-aggregate.sh`'s output. Verified byte-identical
  between the core-extension source store and the deployed `.claude/` mirror for all three files.
- The absorbing duplicate (archived, completed, terminal) lives in this same repository's
  `specs/archive/` tree, not in a separate repository as the dispatch's own disposition text
  assumed. Its fix is confirmed correct by independent inspection, not merely by trusting its own
  summary.
- Both items this record's text says are "still owed" to that absorbing record have now been
  independently re-derived: (i) a fresh second reproduction, from a different, currently-live
  task's issue log, including a `costly`-severity entry, reproducing the same proposal-volume
  pattern; (ii) confirmation that the `suggested_channel`-null question is a **genuine, still-live
  documentation gap** — the absorbing record settled it as code-behavior-safe but never wrote an
  explicit sentence into either contract document the way it did for `resolution`.
- This repository's own `cross-repo-task-migration.md` already states the exact rule this
  record's disposition block was searching a foreign repository for: "If amending the absorbing
  record is not possible, do not abandon the duplicate. Report it and leave it open." The
  absorbing record is terminal (`[COMPLETED]`), so it cannot be amended; this report discharges
  that reporting obligation.
- Recommended next action is narrow and concrete: a plan phase adding one documentation sentence
  each to `conclusion-stage.md`'s Hint-Versus-Decision Rule and `issue-log.md`'s
  `suggested_channel` row, stating explicitly that a null/omitted hint is acceptable and carries
  no override obligation — closing the one sub-question the absorbing record left unwritten. No
  further code change is indicated.

## Context & Scope

This dispatch's own text carries a disposition block ("DISPOSITION PENDING 2026-11-04") asserting
the underlying defect was already fixed and abandonment was correct in principle, but blocked on a
precondition: two items held only by this record had to be transplanted into the absorbing
duplicate before abandonment, and the absorbing record was reported closed with no live target to
amend. The question of what to do when the absorbing record is already closed was deferred to a
foreign repository's record, whose identifier does not resolve in this repository's task space
after migration.

The scope of this research pass was therefore not to re-litigate which of the three original
remedy options to land — that question is already decided and implemented — but to:

1. Verify, independently rather than by trusting the dispatch text, that the fix is actually live
   and correctly deployed in this repository.
2. Re-derive the two transplant items from first principles rather than trusting the snapshot
   figures carried in the record's prior text.
3. Determine what this repository's own conventions say should happen when a duplicate's
   absorbing record turns out to be terminal, now that the migration that created this ambiguity
   is complete and both records live in one task space.
4. Decide a concrete recommendation for the next phase.

## Findings

### The resolution-field defect is fixed, live, and deployed correctly

Confirmed by direct inspection, not by reading the absorbing record's own summary:

- `agent-system/extensions/core/context/contracts/conclusion-stage.md`'s "The Filter Predicate"
  section states explicitly: "A null or omitted `resolution` is read identically to `open`:
  `issue-record.sh` never requires the flag, so an entry written without it must still be
  reachable here rather than silently dropped. Four field states are therefore possible — `open`,
  `worked_around`, `fixed_inline`, and null/omitted." A dedicated "The Implicit-Open Tally"
  section documents `implicit_open_count` as informational, carrying no channel and gating
  nothing.
- `agent-system/extensions/core/context/formats/issue-log.md`'s `resolution` field row states: "A
  null or omitted value is treated identically to `"open"` by the conclusion stage's filter —
  there is no way to write a schema-legal `kind: "issue"` entry whose resolution is permanently
  unreachable by that stage."
- `agent-system/extensions/core/scripts/orchestrate-conclusion-aggregate.sh` implements this at
  line 267 (`select(.kind != "win" and ((.resolution // "open") as $r | $r == "open" or $r ==
  "worked_around")))`) and line 269 (`implicit_open_count` computed from entries whose
  `.resolution == null`).
- All three files are byte-identical between the core-extension source store and the deployed
  `.claude/` mirror (`diff` against each pair produced no output), so there is no stale-deploy gap
  hiding behind a correct source edit.

This matches option (b) from the record's original three-way decision ("widen the Filter
Predicate to treat null-or-absent resolution as open"), composed with the "surface the gap" half
of option (c) (the `implicit_open_count` tally) — not option (a) (tightening the writer), which
the absorbing record's own report rejected as unable to satisfy a regression-fixture acceptance
test against already-written, non-retroactively-editable data.

### The absorbing duplicate is local, terminal, and its remedy is independently correct

The record this task's text names as the absorbing record — `null_resolution_entries_unreachable_by_conclusion_stage`
— is task 373 in this repository, now at `specs/archive/373_null_resolution_entries_unreachable_by_conclusion_stage/`,
status `implemented` / `[COMPLETED]` (a terminal state per this repository's status-transition
model: no further transitions are legal from `[COMPLETED]`, `[ABANDONED]`, or `[EXPANDED]`). Its
own summary (`summaries/01_null-resolution-remedy-summary.md`) independently confirms the same
remedy described above, and its research report's "Decisions" section states the rejection of
option (a) for the same acceptance-test reason. Its own gate record shows 4/4 plan phases closed,
12/12 regression-suite cases passing, and a proof against a real two-task fixture (proposals 0 to
3 after the fix).

### Transplant item (i): independent second reproduction, re-derived fresh

The dispatch's own text names a fixture (task 749, 11 entries, all null-resolution) that is not
present in this repository — it is a path from the repository this record migrated from, carried
over verbatim rather than translated, and cannot be re-derived here.

A fresh, independent reproduction was obtained instead from a currently-live task in this
repository, `specs/436_orient_command_with_scout_agent_retire_review/issues.jsonl` (9
`kind:"issue"` entries, all `resolution: null`, all `suggested_channel: null`, spanning 8
`minor`-severity entries and 1 `costly`-severity entry — "incomplete prior-artifact finding").
Running the aggregator read-only (`--aggregate` only reads `issues.jsonl` files and emits one JSON
document on stdout; it performs no writes) produced:

```
implicit_open_count: 9
proposals: 7 (one class, "pre-existing gate finding", grouping 3 of the 9 entries into one
  proposal; the remaining 6 classes each contribute one proposal)
wins: 3 (kind:"win" entries correctly exempted from the filter despite also carrying
  resolution: null)
severity_max on the "incomplete prior-artifact finding" proposal: costly
```

This independently corroborates both named transplant requirements for item (i): a second
reproduction from a different run (task 436 rather than the originally-cited task), including one
entry at `costly` severity, and a proposal-volume datum consistent with the original dispatch's
observation that a single task's worth of null-resolution entries can meaningfully move the
proposal count (9 candidates to 7 proposals here, versus 7 candidates to a then-dropped 0 in the
pre-fix case the original dispatch cited).

### Transplant item (ii): the suggested_channel disagreement is real and still unresolved

The absorbing record's own research report addresses `suggested_channel` directly, in its
"Verifying the sub-question answers already given" section: "`suggested_channel`'s null-handling
claim (aggregator line ~262 filters nulls out of the hint list) — confirmed correct on inspection;
no issue here." This settles the question as benign at the level of code behavior and goes no
further.

This record's own text asks a different, narrower question that the absorbing record's report
never reaches: whether a null hint is *acceptable by design* or whether the writer should require
one, "and say so in the same place the resolution decision is recorded" — i.e., as an explicit
documentation sentence paralleling the one written for `resolution`. Checking both documents
directly:

- `conclusion-stage.md`'s "The Hint-Versus-Decision Rule" section describes `suggested_channel` as
  "a hint, written by whichever dispatch recorded the entry," and describes the orchestrator's
  override obligation when a hint and the orchestrator's judgment disagree — but contains no
  sentence addressing the null/omitted case at all, unlike "The Filter Predicate" immediately
  above it, which explicitly names all four possible states of `resolution`.
- `issue-log.md`'s `suggested_channel` field row reads only "A hint for the conclusion stage.
  Never a decision — nothing reads this field to act automatically," with no null-specific
  language, again unlike the `resolution` row's explicit null sentence.
- The aggregator code already behaves safely either way: line 281 builds
  `suggested_channel_hints` via `map(select(. != null))`, so a null hint simply contributes
  nothing to the hints array rather than breaking the override logic. The fresh task-436
  reproduction above confirms this in practice — all 7 proposals carried an empty
  `suggested_channel_hints: []`, with no error or malformed output.

So the two records are not in disagreement about what currently *happens* (both agree the code
path is safe); they disagree about whether that settles the *documentation* question the original
dispatch asked. The absorbing record's report treated the code-level safety as sufficient grounds
to call the question closed; this record's text treats the documentation gap — the absence of an
explicit sentence analogous to the `resolution` one — as still open. Per
`cross-repo-task-migration.md`'s own framing ("the absorbing record may be treating as settled
something the duplicate treats as open"), this is exactly the shape of disagreement that
transplant item (ii) names, and it has not been discharged anywhere in writing before this report.

### The fail-safe this record is stuck on is already answered, locally

This record's disposition text treats "what to do when the absorbing record is already closed"
as an open question requiring a foreign repository's record to settle, because that repository's
number no longer resolves here after migration. But the governing document for exactly this
procedure, `agent-system/extensions/core/context/patterns/cross-repo-task-migration.md`, already
lives in this repository (it is the document migration itself was performed under) and states the
general rule directly, under "Duplicates: transplant before abandoning":

> If amending the absorbing record is not possible, do not abandon the duplicate. Report it and
> leave it open.

Task 373 is `[COMPLETED]`, a terminal state with no legal transition back to an amendable state
under this repository's status model — so amending it is indeed not possible, confirming the
precondition this record's text already named. No further record needs to resolve this: the rule
is unconditional on *why* amendment is impossible, and applies as written.

## Decisions

- The resolution-field remedy is confirmed correct and complete; no further code change to
  `orchestrate-conclusion-aggregate.sh`, `conclusion-stage.md`'s Filter Predicate, or
  `issue-log.md`'s `resolution` row is indicated.
- Transplant item (i) (independent second reproduction) is discharged by this report, via a fresh
  reproduction against a currently-live task rather than the now-unreachable originally-cited
  fixture.
- Transplant item (ii) (the `suggested_channel` disagreement) is confirmed as a genuine, narrower,
  still-open documentation gap — not merely re-asserted evidence — and is surfaced here as such
  rather than discarded, per `cross-repo-task-migration.md`'s own instruction.
- This record is not abandoned. Per the governing migration document's own rule, because its
  absorbing record is terminal and cannot be amended, this record stays open and this report
  discharges the "report it" half of that rule.
- The remaining scope for this record narrows from "decide and land one of three remedies" (the
  resolution-field question, already decided and landed by the absorbing record) to one
  documentation-only addition closing the `suggested_channel` sub-question.

## Recommendations

1. **Proceed to a plan phase with a narrowed scope**: add one explicit sentence to
   `conclusion-stage.md`'s "The Hint-Versus-Decision Rule" section stating that a null or omitted
   `suggested_channel` is acceptable by design, contributes nothing to a proposal's hints, and
   carries no override obligation — mirroring the sentence "The Filter Predicate" already carries
   for `resolution`. Add a parallel clause to `issue-log.md`'s `suggested_channel` field row. Both
   edits land at the core-extension source store
   (`agent-system/extensions/core/context/contracts/conclusion-stage.md` and
   `agent-system/extensions/core/context/formats/issue-log.md`), per this repository's
   source-store/deploy boundary, followed by a redeploy and a clean verification.
2. **Do not reopen or edit the archived absorbing record** (task 373) to carry this addition — it
   is terminal, and this repository's status model has no transition back into an editable state
   from `[COMPLETED]`. This record (562) is the correct and only place to land the remaining
   documentation addition.
3. **No writer-side change to `issue-record.sh` is warranted.** Requiring `--suggested-channel`
   at write time would be a larger, riskier change than the evidence calls for: the current
   null-tolerant design is already proven safe in two independent runs (the absorbing record's own
   fixture and this report's fresh task-436 reproduction), and tightening the writer would not by
   itself close the documentation gap that is the actual open question.
4. **Carry this report's two findings forward explicitly** into the next plan's rationale, rather
   than re-deriving them: the resolution-field fix is independently confirmed (not merely trusted),
   and the `suggested_channel` documentation gap is the one concretely actionable item remaining.

## Risks & Mitigations

- **Risk**: a future reader skims the absorbing record's "confirmed correct on inspection; no
  issue here" line and concludes `suggested_channel` needs no further action, re-closing this
  record without the documentation addition landing. **Mitigation**: this report states explicitly
  that the two records answer different questions (code-safety vs. documentation completeness),
  so the next phase should not treat the absorbing record's line as having already satisfied this
  record's narrower ask.
- **Risk**: a future dispatch tries to amend task 373 directly rather than landing the addition
  under task 562. **Mitigation**: this report states explicitly, with the status-model citation,
  why that path is unavailable.
- **Risk**: the proposed sentence is drafted in a way that uses task-number references or
  record-versioning language once it lands in `conclusion-stage.md` or `issue-log.md` (both
  outside `specs/**`, where that language is prohibited). **Mitigation**: the plan phase should
  phrase the addition purely in terms of field values and behavior (as the existing `resolution`
  sentences already do), with no reference to this or any other task number.

## Context Extension Recommendations

None. The relevant conventions (`cross-repo-task-migration.md`'s duplicate-transplant rule,
`status-markers.md`'s terminal-state model, and `report-format.md`'s own carried-figure
discipline) already cover this situation; no new context file is indicated.

## Appendix

- Live reproduction command: `bash .claude/scripts/orchestrate-conclusion-aggregate.sh --aggregate --session sess_research562_repro --tasks "436"` (read-only; no side effects).
- Byte-identity checks: `diff .claude/context/contracts/conclusion-stage.md agent-system/extensions/core/context/contracts/conclusion-stage.md`, same pattern for `issue-log.md` and `orchestrate-conclusion-aggregate.sh` — all three empty-diff.
- Absorbing record artifacts read in full: `specs/archive/373_null_resolution_entries_unreachable_by_conclusion_stage/.return-meta.json`, `summaries/01_null-resolution-remedy-summary.md`, `reports/01_null-resolution-filter-remedy.md` (lines 120-190), `issues.jsonl`.
- Governing migration document: `agent-system/extensions/core/context/patterns/cross-repo-task-migration.md`, "Duplicates: transplant before abandoning" section.
