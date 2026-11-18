# Settled Disposition: null-resolution and null-suggested_channel contract gap

This note is the durable carrier for this record's settled disposition. The task description
still carries a stale "DISPOSITION PENDING 2026-11-04 — DO NOT DISPATCH, DO NOT ABANDON YET"
block; that block is superseded by this note. A reader who encounters the description first
should be directed here rather than re-deriving the status from scratch.

## 1. The `resolution`-field defect is fixed, live, and verified

The original defect — a null-`resolution` issue-log entry reaching no channel in the conclusion
stage — is fixed and deployed. Confirmed by direct inspection, not by trusting any summary:

- `context/contracts/conclusion-stage.md`'s "The Filter Predicate" section states explicitly that
  a null or omitted `resolution` is read identically to `open`, and documents an informational
  `implicit_open_count` tally alongside it.
- `context/formats/issue-log.md`'s `resolution` field row states the same null-handling rule in
  the field table.
- `scripts/orchestrate-conclusion-aggregate.sh` implements the coercion
  (`(.resolution // "open")`) in its candidate filter and computes `implicit_open_count` from
  entries whose `resolution` is null.
- All three files are byte-identical between the core-extension source store
  (`agent-system/extensions/core/`) and the deployed `.claude/` mirror — no stale-deploy gap.

## 2. Transplant item (i) — independent second reproduction — discharged

The duplicate-transplant obligation required an independent second reproduction from a run
different than the one originally cited, including one entry at `costly` severity, plus the
proposal-volume datum that this class of gap can meaningfully move proposal counts.

Re-derived fresh (not carried forward from the originally-cited fixture, which does not exist in
this repository): `specs/436_orient_command_with_scout_agent_retire_review/issues.jsonl` holds 12
entries — 9 `kind: "issue"`, 3 `kind: "win"` — all 12 with `resolution: null` and
`suggested_channel: null`, with issue severities of 1 `costly` and 8 `minor`. Running
`orchestrate-conclusion-aggregate.sh --aggregate` read-only against this fixture produced
`implicit_open_count: 9`, `proposals: 7` (one class grouping 3 of the 9 entries into a single
proposal, the remaining 6 classes each contributing one proposal), `wins: 3`, with the `costly`
severity surfacing correctly on the grouped proposal. This independently satisfies both named
requirements of item (i): a second reproduction from a different run, and inclusion of a
`costly`-severity entry.

## 3. Transplant item (ii) — the `suggested_channel` disagreement — resolved, not discarded

This item required surfacing a live disagreement rather than extra evidence: whether a null
`suggested_channel` is acceptable by design is a documentation question this record's own text
raised, distinct from the code-safety question the absorbing record settled.

The disagreement was real. The absorbing record's own research treated the question as closed at
the level of code behavior (the aggregator already filters null hints out of the hints list
safely) and never wrote an explicit sentence into either governing document addressing the
null/omitted case — unlike the explicit sentence both documents carry for `resolution`. This
record's text asked the narrower documentation question and found it genuinely unanswered in
writing.

That gap is now closed. `context/contracts/conclusion-stage.md`'s "The Hint-Versus-Decision Rule"
section now states explicitly that a null or omitted `suggested_channel` is acceptable by design,
contributes nothing to a proposal's hint list, and carries no override obligation — and names the
deliberate asymmetry with `resolution`: a null `resolution` is read as a positive value because
dropping the entry would hide it, whereas a missing hint hides nothing and is absorbed rather
than defaulted. `context/formats/issue-log.md`'s `suggested_channel` field row carries the
parallel clause. A reader of either document can now predict the other's behavior for this field,
exactly as they already could for `resolution`.

## 4. Why this record is not abandoned

The record this task's description names as the absorbing duplicate —
`null_resolution_entries_unreachable_by_conclusion_stage` — is archived in this repository at
`specs/archive/373_null_resolution_entries_unreachable_by_conclusion_stage/`, with status
`implemented` (terminal `[COMPLETED]`). This repository's status-transition model admits no
transition out of a terminal state, so that record cannot be amended to carry the two transplant
items above.

`context/patterns/cross-repo-task-migration.md`'s duplicate-transplant section states the
governing rule directly: if amending the absorbing record is not possible, do not abandon the
duplicate — report it and leave it open. Because amendment is impossible here (the absorbing
record is terminal), that fail-safe applies as written. Both transplant items are now discharged
in writing — item (i) in section 2 above, item (ii) resolved by the documentation addition in
section 3 above — but discharging them does not itself authorize abandonment; the absorbing
record remains unamendable, so this record stays open under the rule's own fail-safe. This is the
complete and sufficient disposition: the defect is fixed, both transplant items are discharged,
and the record remains open by design rather than by oversight.
