# Implementation Plan: Task #693

- **Task**: 693 - Merge command stack mode
- **Status**: [BLOCKED]
- **Effort**: 0.2 hours (recording and hand-off only; no deliverable remains to build)
- **Dependencies**: 695 (`slice_command_design_and_consolidation`, completed). That record's
  ruling is what empties this one; no other edge matters now.
- **Research Inputs**:
  - specs/693_merge_command_stack_mode/reports/01_merge-command-stack-mode.md
  - specs/decisions/slice-command-one-path-to-review.md (the ruling; decided 2026-11-24 UTC)
  - specs/decisions/review-slices-are-declared-tasks.md (the earlier, narrower amendment named in
    this record's own description, now itself superseded in the parts quoted below)
- **Artifacts**: plans/01_merge-stack-mode.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

**This record has no deliverable left to build, and this plan instructs no edit to any file under
`agent-system/**` or `.claude/**`.** `specs/decisions/slice-command-one-path-to-review.md` rules
`/merge` removed rather than fixed and `/merge --stack` never built, deletes
`commands/merge.md` (485 lines) outright, and sends this record to Abandon by name. The whole of
the prior plan — a `## Stack Mode` section with `--stack`/`--only`/`--retarget` in
`commands/merge.md`, plus a redeploy phase — would build, into a file the same record deletes,
a mode the same record says is never built.

The single phase below exists so that an implement dispatch landing on this plan reads an
instruction to stop, rather than an instruction to build. Its whole content is: change nothing,
record the supersession, and return the operator's own worklist line.

### Research Integration

Newly integrated inputs for this revision:

- **`specs/decisions/slice-command-one-path-to-review.md`** (decided 2026-11-24 UTC by
  `slice_command_design_and_consolidation`, 695, since completed; session
  `sess_1795478339_253676`). Lines verified live in that file for this revision:
  - Line 5 of its six-line ruling: "`/merge` is removed, not fixed. `/merge --stack` is never
    built."
  - Its "One survivor, and what is deleted" table: row 4 marks `commands/merge.md` **Deleted**,
    and the next row marks "`/merge --stack` (planned by `merge_command_stack_mode`, 693)"
    **Never built**.
  - Its "Verdict on each open record" table: `merge_command_stack_mode` (693), status read
    `planned`, verdict **Abandon**, reason "`/merge` is removed and `--stack` is never built.
    Nothing of its deliverable survives."
  - Its "Operator worklist": "Abandon 693 | `/task --abandon 693`", and "Two dispatches in
    flight | 692 and 693 are `planned` against the overturned ruling and depend on 695. Their
    plans must not be implemented as written."
  - Its "What is discarded" section, under "Planned, and now not to be built": "`/merge --stack`
    (693)."
  - Its "Assertions amended" table overturns the clause this record's own description leaned on:
    "What is retained from the inference route | The resolvers, the manifest, `show`,
    `record-request` and `restack` are retained and still wired | **Overturned.** Nothing of
    `review-stack-prepare.sh` is retained."
- **The prior research report** (`reports/01_merge-command-stack-mode.md`) is not contradicted on
  its own terms — the manifest schema it documented, the already-proven grant revocation, the
  bottom-up `entries[]` ordering and the integer-`ordinal` comparison were all correct findings
  about the live tree at the time. They are simply findings about a script and a command file that
  are now both scheduled for deletion, so none of them yields a task.

Both phases of the prior plan are covered by the ruling, not only the `/merge` phase:

- The description's second ownership paragraph (Phase 4, `restack`) was already an expansion
  artifact — the prior plan's own Premise Re-Validation item 2 confirmed it was out of
  `file_scope` and ignored it. It is doubly moot now: `restack` was built by
  `restack_review_stack_when_parent_merges` (691, completed), and the ruling deletes
  `review-stack-prepare.sh` including that subcommand.
- The Phase 6 (`/merge` stack mode) deliverable is the one the ruling names explicitly.

### Premise Re-Validation (Carried-Figure Discipline)

Each figure this revision rests on, checked against live state rather than carried:

1. **The ruling file exists and says what is quoted above** — CONFIRMED by reading
   `specs/decisions/slice-command-one-path-to-review.md` directly for this revision; the quoted
   rows were located in its "One survivor, and what is deleted", "Verdict on each open record",
   "Operator worklist" and "What is discarded" sections.
2. **693's status is still live, not already abandoned** — CONFIRMED: `specs/state.json`'s entry
   for `project_number: 693` reads `status: "implementing"` with `task_type: "meta"`. The
   operator's `/task --abandon 693` has not been run. This plan therefore still has to instruct a
   stop; it cannot assume the task is already closed.
3. **No edit has landed from the prior plan** — CONFIRMED: the preceding implement dispatch's
   `.return-meta.json` records `status: "blocked"`, `modified_files: []`, `phases_completed: 0`,
   and both phases of the prior plan stood at `[NOT STARTED]`. There is nothing to preserve and
   nothing to revert.
4. **The description's own superseding note is stale** — CONFIRMED and important. That note points
   only at `review-slices-are-declared-tasks.md` and asserts "This record's own deliverable
   SURVIVES the amendment intact", citing that record's "What is retained from the inference
   route" section. The later ruling overturns exactly that section by name (see the amended-
   assertions quote above). The description's survival claim is void; this plan supersedes it.

### Prior Plan Reference

The prior plan at this same path proposed two phases: a `## Stack Mode` section plus three flags
in `agent-system/extensions/core/commands/merge.md` (Phase 1, `local` tier, 1 hour), and a
`deploy-headless.sh` redeploy (Phase 2, `full` tier, 20 minutes). Both stood at `[NOT STARTED]`.
Neither is carried forward: the file Phase 1 would edit is deleted by the ruling, and Phase 2
existed only to deploy Phase 1's edit.

`specs/685_stack_pr_submission_from_integration_branch/plans/01_stack-pr-submission.md` remains
readable as the design history of the inference route, but it is no longer an authoritative design
record for anything to be built: 685 is `expanded` and the ruling deletes the script its
PD1-PD12 govern.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context and no `roadmap_flag` is set,
so no roadmap consultation applies.

## Goals & Non-Goals

**Goals**:

- An implement dispatch reading this plan changes no file under `agent-system/**` or `.claude/**`
  and opens no edit to `commands/merge.md`.
- The supersession is recorded where the next reader will find it: an issue-log entry, the return
  metadata, and the dispatch's own returned text, each naming
  `specs/decisions/slice-command-one-path-to-review.md` and its Abandon verdict.
- The operator is handed the exact worklist line the ruling specifies — `/task --abandon 693` —
  and told that it is theirs to run, not an agent's.

**Non-Goals**:

- Building `--stack`, `--only` or `--retarget`, in `commands/merge.md` or anywhere else. Ruled
  never built.
- Deleting `commands/merge.md`, `scripts/review-stack-prepare.sh`, or its suite. Those deletions
  are real, but they belong to the ruling's successors 3 and 5 — successor 5 is explicitly ordered
  "only after `/slice` has opened one real pull request". Doing them here would widen a record
  that is being emptied into a record that destroys 2,000+ lines ahead of its gate.
- Building any part of `/slice` (the ruling's successor 1). That is a new record for the operator
  to create, not a redirection of this one.
- Editing `skills/skill-git-workflow/SKILL.md`. It is in this record's `file_scope`, and the prior
  plan already established it carries no merge-mode wiring; the ruling assigns its `/merge` mention
  to the `/merge` removal successor regardless.
- Abandoning the task from inside a dispatch. `[ABANDONED]` is a terminal state and the ruling puts
  `/task --abandon 693` on the *operator* worklist. An agent that abandons its own record removes
  the operator's decision point.
- Editing any other task's record, plan, description or dependency edges. The ruling's `/revise 692`,
  `/revise 694`, `/revise 655` and the edge replacement on 694 are separate operator lines.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| An implement dispatch reads a stale excerpt of the prior plan and starts editing `commands/merge.md` anyway | H | M | The revision sentinel at `specs/693_merge_command_stack_mode/.plan-revised.json` is written by this revision; the reader obligation in `context/patterns/plan-revision-notification.md` is a phase-section re-read immediately before the first edit of a phase. The single phase below leads with the stop instruction so a partial read still hits it |
| The emptied record is left `implementing` forever, re-admitted every cycle and re-dispatched to no purpose | M | H | The phase's own completion condition is the hand-off of `/task --abandon 693` to the operator, stated in the returned text and the return metadata, not buried in an artifact |
| Scope creep into the ruling's successors — deleting the files, or starting `/slice` | H | M | Named as Non-Goals above, with the ruling's own ordering constraint quoted (successor 5 is gated on `/slice` having opened one real pull request) |
| A future reader treats the description's "deliverable SURVIVES the amendment intact" note as still binding | M | M | Premise Re-Validation item 4 above records that the note is stale and names the clause the later ruling overturns |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Single phase; no parallelism applies.

### Phase 1: Record the supersession and hand the abandonment to the operator [NOT STARTED]

**Goal**: No file under `agent-system/**` or `.claude/**` is changed, and the supersession plus the
operator's abandonment line are recorded in the issue log, the return metadata and the returned
text.

**Tasks**:

- [ ] Change nothing under `agent-system/**` or `.claude/**`. This phase has no edit site. If any
      instruction elsewhere in this record's description still reads as a build order for
      `--stack`/`--only`/`--retarget`, it is superseded by this plan and by
      `specs/decisions/slice-command-one-path-to-review.md`; do not act on it.
- [ ] Re-read `specs/decisions/slice-command-one-path-to-review.md`'s "Verdict on each open
      record" table and its "Operator worklist" before reporting, to confirm the Abandon verdict
      and the `/task --abandon 693` line still read as quoted in this plan's Research Integration
      section. If either has since changed, report the difference instead of the quote.
- [ ] Record one issue-log entry via `bash .claude/scripts/issue-record.sh` naming the ruling file,
      the Abandon verdict, and the fact that no edit was made. If the preceding blocked implement
      dispatch already recorded an equivalent entry (its return metadata says it did), confirm that
      entry is present in `specs/693_merge_command_stack_mode/issues.jsonl` and do not duplicate it.
- [ ] Write return metadata recording `blocked`, `modified_files: []`, and a blocker entry whose
      `why_it_failed` names `specs/decisions/slice-command-one-path-to-review.md` and its verdict.
- [ ] Return, as the dispatch's own text, the operator line verbatim: `/task --abandon 693`, with
      one sentence of ground (the ruling's reason column: "`/merge` is removed and `--stack` is
      never built. Nothing of its deliverable survives"). State plainly that the line is the
      operator's to type and was not run by the dispatch.

**Timing**: 10 minutes

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: The phase's whole deliverable is a recorded report and an unchanged tree;
there is no code path, no deployed artifact and no suite to exercise. The specific covering check
is the emptiness of `git status --short` over `agent-system/**` and `.claude/**` for this dispatch,
which is a direct observation rather than a test invocation.

**Files to modify**:

- None under `agent-system/**` or `.claude/**`. Writes are confined to this record's own
  `specs/693_merge_command_stack_mode/` directory (`issues.jsonl`, `.return-meta.json`), which is
  this task's own metadata, not a deliverable.

**Verification**:

- `git status --short -- agent-system/ .claude/` shows nothing attributable to this dispatch.
- `git diff -- agent-system/extensions/core/commands/merge.md` is empty, and that file contains no
  occurrence of `--stack`, `--only` or `--retarget`
  (`grep -nE -- '--stack|--only|--retarget' agent-system/extensions/core/commands/merge.md`
  returns nothing).
- `specs/693_merge_command_stack_mode/issues.jsonl` carries an entry naming
  `specs/decisions/slice-command-one-path-to-review.md`.
- The returned text contains the literal string `/task --abandon 693` and attributes it to the
  operator.

## Testing & Validation

- [ ] No file under `agent-system/**` or `.claude/**` was changed by the dispatch
      (`git status --short -- agent-system/ .claude/`).
- [ ] `agent-system/extensions/core/commands/merge.md` still contains no stack-mode flag.
- [ ] The ruling's Abandon verdict and its `/task --abandon 693` worklist line were re-read live
      and confirmed, or any divergence reported.
- [ ] The supersession appears in the issue log and in the return metadata, each naming the ruling
      file by path.
- [ ] `/task --abandon 693` is present in the returned text as an operator action, and was not run
      by an agent.

## Artifacts & Outputs

- This revised plan, which is the record's substantive output: it replaces a build plan with a
  stop instruction and preserves the evidence for why.
- One issue-log entry in `specs/693_merge_command_stack_mode/issues.jsonl`.
- Return metadata recording `blocked` with an empty `modified_files`.
- No source-store change, no deployed-tree change, and no commit touching `agent-system/**`.

## Rollback/Contingency

Nothing to roll back: the plan instructs no edit, and the preceding dispatch made none
(`modified_files: []`, both prior phases `[NOT STARTED]`).

Contingency, if the ruling itself is later reversed: this plan's Research Integration section
quotes the exact rows that empty the record, so a reversal can be checked against them line by
line. A reversal would not revive this plan — it would require a fresh record against whatever
command then exists, since `commands/merge.md` is scheduled for deletion by the ruling's successor
5 and the prior plan's insertion points (STEP 1-7, the `## Options` table, `## Agent Restrictions`)
would no longer be there to edit.
