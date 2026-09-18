# Implementation Plan: Task #228

- **Task**: 228 - Establish batch orchestration as the documented default, with batch-selection criteria and an explicit conflict rule
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/228_establish_batch_orchestration_as_default/reports/01_batch-selection-criteria.md
- **Artifacts**: plans/01_batch-default-selection-guidance.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Documentation-only change in the source store (`agent-system/extensions/core/`, never
`.claude/**`). A new top-level section in `context/patterns/batch-orchestration-guardrails.md`
becomes the ONE canonical statement of the batch-as-default posture, the three selection
criteria, and an explicit rule for each pairwise conflict. `commands/orchestrate.md` and
`merge-sources/claudemd.md` gain one-line pointers (no restatement), and
`context/patterns/multi-task-operations.md`'s Overview stops naming single-task as "the common
case". No script, predicate, wave computation, or dispatch path is touched.

### Research Integration

The report settles the canonical home (guardrails file: principles-not-mechanisms register,
existing normative voice, and the collision-visibility argument extends its own "Three Existing
Admission Layers" analysis) and the dominance order **territory > topic > graph shape**. It
supplies drafted section text. Planning review of that draft found three defects the
implementation MUST fix rather than paste verbatim:

1. **Internal contradiction.** Draft rule 3 says to avoid a batch that is "neither fully connected
   nor fully independent", but the draft's own worked example (`A,B,C,D,E` with `C -> A` and
   `D`, `E` independent) is exactly such a mixed batch. Resolution: drop the "avoid mixed shape"
   clause. Wave dispatch handles mixed graphs correctly; graph shape is only a tie-breaker between
   otherwise-equal candidates (prefer the one that adds wave-1 width; always include a dependent
   whose prerequisite is already in the batch, since apart from it the dependent cannot proceed).
2. **"Situational" is not a rule.** The draft answers topic-vs-width with "Situational". The task
   requires a rule a reader can apply. Resolution: **topic beats width** — fill open slots with
   dispatch-safe same-topic candidates before any off-topic candidate. Off-topic candidates with
   no territory link to the batch may be added only as filler once every dispatch-safe
   same-topic candidate is already in. (Off-topic candidates that DO share territory are not
   filler. Rule 1 makes them mandatory.)
3. **Batch-size cap unaddressed.** `MAX_TASKS=8` TRIMS a larger request to its first 8 task
   numbers (`docs/architecture/orchestrate-state-machine.md`, `### Batch Size Cap (MAX_TASKS)`).
   The guidance must say: keep a batch at 8 or fewer; list territory-mandatory members first so
   trimming can never split a territory group; if a territory group alone exceeds 8, run it as
   consecutive batches in dependency order and accept (and say) that visibility across the
   split is lost.

Additionally, the guardrails file's opening paragraph scopes itself to "admission control"; it
must be widened by one clause to cover batch composition/selection, otherwise the new section
contradicts the file's own stated scope.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap consulted (no roadmap_path in dispatch).

## Goals & Non-Goals

**Goals**:
- Exactly one file (`batch-orchestration-guardrails.md`) states the posture, the three criteria,
  the dominance rule, and a rule for each of the three pairwise conflicts.
- The collision-visibility argument is carried explicitly as the primary justification.
- The territory criterion is labelled a human judgment, with the reason (declaration granularity
  is under revision in the file-scope-lifecycle topic) stated.
- A worked five-task, one-topic example resolves to one specific `/orchestrate` invocation.
- Pointers (not copies) in `commands/orchestrate.md` and `merge-sources/claudemd.md`.
- `multi-task-operations.md` Overview no longer frames single-task as the common case.

**Non-Goals**:
- Any change to scripts, admission predicates, wave computation, lock protocol, or dispatch.
- Shared-tree vs. isolated-worktree decision; concurrent-agent dispatch-brief content.
- `file_scope` granularity, backfill, or absent-scope admission posture (cited only, never
  specified).
- A full rewrite of `multi-task-operations.md` (sections 1-13 and its stale
  `/research`/`/plan`/`/implement` references beyond the Overview are left for separate work).
- Editing `index-entries.json` by default (outside this task's `file_scope` and inside a
  concurrent sibling's declared scope; see Phase 3).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Readers infer a machine check enforces co-batching on territory | M | M | Explicit "human judgment, not machine derivation" subsection naming the owning topic |
| Draft text pasted verbatim, carrying the three defects above | H | M | Phase 1 tasks name each fix; Phase 3 verification checks them |
| `index-entries.json` `line_count` for the guardrails entry drifts (1097 -> ~1200) | L | H | Phase 3: run `generate-context-line-counts.sh --check`; edit only if the file is free of concurrent-sibling work, else record as follow-up |
| Concurrent siblings edit the same shared tree | M | L | Re-read each file immediately before editing; stage explicit file paths / own hunks only; never reverting `git-snapshot.sh` |
| Task numbers leak into deliverables (e.g. in the worked example) | M | L | Use letter placeholders `A`..`E`; run `check-task-references.sh` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Write canonical selection section in batch-orchestration-guardrails.md [COMPLETED]

**Goal**: Add the single canonical statement of the batch-as-default posture and selection rule.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
      immediately before editing (concurrent siblings share this tree). *(completed)*
- [x] Widen the opening paragraph by one clause so the file's stated scope covers batch
      composition (which tasks to propose together) as well as admission; keep "defines no new
      behavior". *(completed)*
- [x] Insert a new `## Batching Is the Default: Selection Criteria and Conflict Resolution`
      section after the opening paragraph and before `## The Three Existing Admission Layers`,
      based on the report's drafted text, with these required subsections:
      posture statement (batch-of-one is the same mechanism, unpenalized); "Why batch-as-default"
      (collision visibility: admission gates -- `orchestrate-batch-admit.sh`, the runtime
      wave-split check, the lock protocol -- compare only tasks they can see together; two related
      tasks in separate sessions are mutually invisible); the three criteria; the dominance rule;
      the pairwise-conflict table (three rows, each with a definite winner); the batch-size-cap
      rule; the territory-is-human-judgment scope note; the worked example. *(completed)*
- [x] Apply the three research-draft fixes from this plan's Research Integration section
      (remove "avoid mixed shape"; replace "Situational" with "topic beats width" as a crisp rule;
      add the `MAX_TASKS=8` trim/ordering rule citing `orchestrate-state-machine.md`'s
      `### Batch Size Cap (MAX_TASKS)`). *(completed)*
- [x] Make the worked example deterministic: five open same-topic tasks `A`..`E`, state each
      inclusion with the rule that admits it, give the exact invocation (`/orchestrate A,B,C,D,E`
      with territory-mandatory members listed first) and the resulting wave shape. Add a second
      one-line variant showing an off-topic task that shares territory with `A` being pulled in
      (territory beats topic) so the example exercises every conflict rule at least once.
      *(completed: added task `F` variant)*
- [x] Verify cited anchors exist: `multi-task-creation-standard.md` `### 4a.`,
      `orchestrate-state-machine.md` `### Batch Size Cap (MAX_TASKS)`,
      `scripts/orchestrate-batch-admit.sh`, `task-lock.md`. *(completed: all four confirmed present)*
- [x] Commit (explicit path only): `task 228 phase 1: add canonical batch selection section`.
      *(completed: commit 625afda1f)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Roughly 90-120 added lines in one file. Confirm with `git diff --stat`
after editing; a diff touching any other file in this phase is a scope error.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - new section
  and one-clause scope widening in the opening paragraph

**Verification**:
- `grep -c "^## Batching Is the Default" ...guardrails.md` returns 1.
- Conflict table has exactly three rows, none with a winner of "Situational" or equivalent.
- `grep -n "neither" ` finds no "avoid a batch that is neither connected nor independent" clause.
- `MAX_TASKS` and the trim behaviour are mentioned in the new section.
- No task numbers in the added text (`bash agent-system/extensions/core/scripts/check-task-references.sh`
  on the file, or its repo-wide mode, reports no new hit).

---

### Phase 2: Pointer edits and multi-task-operations.md Overview reframe [COMPLETED]

**Goal**: Point the two entry-point files at the canonical section and remove the contradicting
"common case" framing.

**Tasks**:
- [x] Re-read each file immediately before editing. *(completed)*
- [x] `commands/orchestrate.md` Constraints (currently line 24, "uniformly for a batch of one task
      or many"): append a pointer sentence -- batching related tasks is the default; see
      `context/patterns/batch-orchestration-guardrails.md`'s "Batching Is the Default" section for
      which tasks to batch. No criteria restated. *(completed)*
- [x] `merge-sources/claudemd.md` "Multi-task syntax" paragraph (currently line 116): append one
      pointer sentence to the same section. No criteria restated. Do NOT edit `.claude/CLAUDE.md`
      (regenerated from this merge source). *(completed)*
- [x] `context/patterns/multi-task-operations.md` Overview:
      - Replace the design-principle bullet "(zero overhead for common case)" with wording that
        keeps the technical claim but drops the framing (e.g. "no special-casing overhead for a
        batch of one").
      - Reframe the Overview's first sentence ("traditionally accept a single task number") so it
        does not present single-task as the norm, and add one pointer sentence to the canonical
        section for batch-selection guidance. Keep it to the Overview only. *(completed)*
- [x] Commit with explicit paths: `task 228 phase 2: point entry docs at batch selection guidance`.
      *(completed: commit ea849d410)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: Three files, each a 1-5 line change. Confirm with `git diff --stat`.

**Files to modify**:
- `agent-system/extensions/core/commands/orchestrate.md` - one pointer sentence
- `agent-system/extensions/core/merge-sources/claudemd.md` - one pointer sentence
- `agent-system/extensions/core/context/patterns/multi-task-operations.md` - Overview wording and
  pointer

**Verification**:
- `grep -n "common case" multi-task-operations.md` returns nothing.
- `grep -n "Batching Is the Default"` hits exactly: the guardrails heading, and one pointer each in
  `orchestrate.md`, `claudemd.md`, `multi-task-operations.md`.
- Neither pointer file contains the words "dominance", "territory >", or a conflict table
  (no second copy).

---

### Phase 3: Cross-file verification and index line_count handling [NOT STARTED]

**Goal**: Confirm the acceptance criteria end to end and handle the index metadata drift safely.

**Tasks**:
- [ ] Acceptance walk: read the new section as a user with five open same-topic tasks and confirm
      it yields one specific invocation with no interpretation required; confirm each of the
      three pairwise conflicts has a stated winner.
- [ ] Confirm no file outside the four in `file_scope` was modified by this task
      (`git log --stat` over this task's commits), and no script/predicate/dispatch file changed.
- [ ] Run `bash agent-system/extensions/core/scripts/check-task-references.sh` and
      `bash agent-system/extensions/core/scripts/check-extension-docs.sh` (if runnable in this
      repo); fix any new finding in the four touched files.
- [ ] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check`.
      If the guardrails entry's `line_count` is stale: check whether
      `agent-system/extensions/core/index-entries.json` has uncommitted changes or is claimed by an
      in-flight sibling (its `file_scope`/lock). If clean and unclaimed, update ONLY that entry's
      `line_count` (and optionally add `selection`/`batch-composition` keywords) as a single
      hunk and commit it with an explicit path. Otherwise do not touch it; record the drift in the
      implementation summary as a follow-up for `generate-context-line-counts.sh --write`.
- [ ] Commit any fixes with explicit paths.

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: full

**Files to modify**:
- None expected; conditionally `agent-system/extensions/core/index-entries.json` (one entry) and
  small fixes in Phase 1-2 files

**Verification**:
- All Phase 1 and Phase 2 verification greps still pass.
- `check-task-references.sh` reports no new hits in the touched files.
- `line_count` either corrected or explicitly recorded as deferred follow-up.

## Testing & Validation

- [ ] Exactly one file contains the posture, criteria, and conflict rules.
- [ ] Each pairwise conflict (territory/topic, territory/width, topic/width) has a definite winner.
- [ ] Collision-visibility argument names the admission gates and the separate-sessions blind spot.
- [ ] Territory criterion labelled human judgment, citing declaration granularity under revision.
- [ ] Pointers in `orchestrate.md` and `claudemd.md`, no restated criteria.
- [ ] `multi-task-operations.md` Overview no longer says "common case".
- [ ] No script, predicate, or dispatch path modified; no task numbers in deliverables.

## Artifacts & Outputs

- Modified: `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
- Modified: `agent-system/extensions/core/commands/orchestrate.md`
- Modified: `agent-system/extensions/core/merge-sources/claudemd.md`
- Modified: `agent-system/extensions/core/context/patterns/multi-task-operations.md`
- Conditional: `agent-system/extensions/core/index-entries.json` (one `line_count`)
- Summary: `specs/228_establish_batch_orchestration_as_default/summaries/01_batch-default-selection-guidance-summary.md`

## Rollback/Contingency

All changes are documentation in committed, per-phase commits. Revert with `git revert <sha>` of
the specific phase commit(s); never a reverting `git-snapshot.sh` on the shared tree while
siblings are in flight.
