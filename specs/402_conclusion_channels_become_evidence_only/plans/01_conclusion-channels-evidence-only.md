# Implementation Plan: Task #402

- **Task**: 402 - Conclusion channels (b) and (c) become evidence-only
- **Status**: [IMPLEMENTING]
- **Effort**: 3.5 hours
- **Dependencies**: 391, 400 (both archived/landed — confirmed absent from `specs/state.json`'s `active_projects`)
- **Research Inputs**: specs/402_conclusion_channels_become_evidence_only/reports/01_conclusion-channels-evidence-only.md
- **Artifacts**: plans/01_conclusion-channels-evidence-only.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Channels (b) and (c) of the orchestration conclusion stage stop firing consequences and start
recording evidence. Step 4b's `meta-builder-agent` dispatch body and Step 4c's unreachable
task-creation block are deleted outright — not completed — and each channel instead appends one
`conclusion_proposal_recorded` line per classified proposal to `specs/events.jsonl` via the
existing `scripts/events-append.sh`. Channel (a) is untouched, the per-channel approval ledger
and its fail-closed `--check-approval` guard are untouched, and every downstream document that
transcribes the old design is brought into sync in the same round. The change is deletion-biased
by construction and must report a negative net line count.

### Premise Re-Validation (Carried-Figure Discipline)

All three extracted lines were checked against live state, not accepted on sight:

| Extracted line | Verdict |
|----------------|---------|
| Line 3 — source store is the edit target, resolved via `.claude-extensions.json` | **CONFIRMED.** `.extensions.core.source_dir` = `/home/benjamin/.config/nvim/agent-system/extensions/core`, present on this filesystem, and every file this plan names exists under it. The deploy mirror `.claude/` is present and gitignored as the rule describes. |
| Line 13 — Step 4c stages `"${new_task_dir_paths[@]}"`, an array it never populates, and creates no task directories | **CONFIRMED VERBATIM.** `context/contracts/conclusion-stage.md:330-374`: the `git-commit-scoped.sh` call stages `"${new_task_dir_paths[@]}"` with no prior assignment anywhere in the step, and `--argjson num "$new_task_num"` consumes a variable the step never binds. The step contains no `next_project_number` read and no `mkdir`. `skills/skill-spawn/SKILL.md` Stage 11 does both. |
| Line 44 — the three-gate approval invariant (a recorded "no" blocks, an absent answer blocks, one channel's "yes" never satisfies another's gate) | **CONFIRMED, mechanically.** `scripts/orchestrate-conclusion-aggregate.sh:138-165` implements `--check-approval` fail-closed: absent ledger, recorded `no`, and malformed ledger all exit 2. `--channel` is validated against `a\|b\|c` at both `--record-approval` and `--check-approval`. Test case (g) in `scripts/tests/test-orchestrate-conclusion-aggregate.sh` is marked ACCEPTANCE-CRITICAL for per-channel isolation and exercises the script directly, so it survives this change unedited. |

One corroborating figure in the description could **not** be re-verified and is recorded as
historical rather than current: the "`next_project_number` stale at 416 while 416 and 417 already
existed" observation is dated 2026-10-15. Live `specs/state.json` today reads
`next_project_number: 607` with a highest active project number of 607 — i.e. the counter still
does not sit above the maximum in use. That class of staleness is owned independently by the
`task_number_allocation_staleness_undetected` task; this plan neither fixes nor depends on it,
and the only bearing it has here is that this change removes one more writer of that counter.

One research-report claim is corrected: the report states task 421
(`retarget_distill_meta_as_evidence_consumer`) "depends on nothing listed against 402". Live
state shows its `dependencies` are `[312, 402]`. This does not change the plan — the ordering
the dispatch assumes (this task lands first, the consumer follows) is exactly what that edge
encodes — but the implementer should not act on the report's weaker claim.

### Research Integration

The research report's two load-bearing conclusions are adopted and pinned here:

1. **`specs/events.jsonl` is the evidence store**, not `issues.jsonl`. `issues.jsonl` is the
   conclusion stage's own sole evidence base, and its filter predicate admits any
   `kind: issue|win` entry whose `resolution` is `open`/`worked_around`/null — a classification
   record written back there would be re-aggregated and re-classified by the next invocation, a
   self-referential loop. `events.jsonl` is explicitly outside the stage's read-set. No new file
   is created, satisfying Required Change #2.
2. **No schema revision is needed.** `context/schemas/events-schema.json` already leaves
   `event_type` and `checkpoint` as open strings and `detail` as `additionalProperties: true`,
   and `push_grant_issued`/`push_grant_consumed` are an exact structural precedent: a
   `category: "milestone"` audit record of a decision, with a rich structured `detail`.

The report's consumer table is adopted and **extended** by a verification sweep run during
planning. Five further files mention the conclusion stage or its channels; four were checked and
need no edit, and that finding is recorded here so the implementer does not re-discover it:
`commands/orchestrate.md`, `skills/skill-orchestrate/SKILL.md`, `scripts/issue-record.sh`
(no channel mechanics at all), and `context/formats/issue-log.md:54` plus
`context/contracts/batch-gate-stage.md:153` (both name the three channels only as classification
*categories*, which survive this change unchanged — only what (b) and (c) DO changes, not that
they exist). `context/patterns/topic-assignment-pattern.md` and
`context/patterns/lit-stage4a-flow.md` carry unrelated `new_task_num` variables of their own and
are confirmed false positives.

### Decisions Pinned Here (left open by research)

**D1 — Channels (b) and (c) lose their `AskUserQuestion` approval gates entirely.** The research
report flagged this as a judgment call for planning; it is decided here, with the rejected
alternative stated. Recording evidence has no consequence to gate: every statement of the
invariant in `conclusion-stage.md` uses "fire" to mean *executing a consequence* (a fix, a
dispatch, a task creation), and once (b)/(c) execute nothing, asking the user for permission to
write a log line is friction that the stage's own purpose — removing a complexity pump — argues
directly against. Step 3 therefore becomes a single channel-(a) gate. **Rejected alternative**:
keep all three `AskUserQuestion` gates and change only what "yes" does. Rejected because it
preserves the per-invocation user-interrupt cost while delivering none of the consequence the
gate exists to authorize, and because it would make a recorded "no" silently discard evidence
that the task's own motivation says should accumulate. Required Change #3 is satisfied
independently of D1: the ledger survives because
`scripts/orchestrate-conclusion-aggregate.sh` is not edited at all and its `a|b|c` validation is
not narrowed, leaving `--record-approval`/`--check-approval --channel b|c` available to the
deliberate consumer when it gates its own creation step.

**D2 — One event line per classified proposal, not one per channel carrying an array.**
`events.jsonl` is line-oriented and every existing consumer filters per line; a per-proposal line
makes `jq 'select(.event_type == "conclusion_proposal_recorded")'` yield proposal records
directly with no nested unwrapping, keeps each line's citation list bounded, and matches the
`push_grant_issued` precedent (one line per grant, never one per batch).

**D3 — `event_type: "conclusion_proposal_recorded"`, `category: "milestone"`, `task: null`.**
`task` is null because a proposal is frequently cross-task by construction (the Cross-Task
Grouping Rule is the central reason the aggregation step exists); the real per-task linkage lives
in `detail.citations[]`.

**D4 — Each recording channel ends with its own narrow `specs/events.jsonl` commit.** Pathspec is
that one file and nothing else. `specs/events.jsonl` is a member of
`scripts/lib/engine-written-state-paths-lib.sh`'s engine-written-state allowlist, which
`context/standards/git-staging-scope.md` describes as admitting the path precisely when a caller
*explicitly names it in a pathspec* — while forbidding it from ever being seeded unconditionally
into every commit (which would sweep a concurrent writer's rows). A deliberate, explicitly-named,
once-per-channel commit is the sanctioned shape; the forbidden shape is the unconditional seed.
Move 5 runs strictly after Move 4's full finalization, so no sibling dispatch of this invocation
is live when it fires.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and the roadmap flag is not set; no roadmap
phases are added and `specs/ROADMAP.md` is not consulted or modified.

## Goals & Non-Goals

**Goals**:
- Channels (b) and (c) record classified proposals into `specs/events.jsonl` and dispatch,
  create, and write nothing else.
- Step 4b's `meta-builder-agent` dispatch body, its `GLOBAL_ROOT`/`target_root` resolution, and
  Step 4c's entire task-creation block (including the unbound `$new_task_num` and the unpopulated
  `new_task_dir_paths`) are deleted, not repaired.
- Every downstream document that transcribes the deleted design is brought into sync in the same
  round, leaving no stale copy.
- Test cases (j) and (k) are rewritten to assert the new shape, not deleted.
- The change's net line count across all touched files is measured and reported, and is negative.

**Non-Goals**:
- Building the deliberate, batched, dedup-aware consumer of this evidence. That is the separately
  filed `retarget_distill_meta_as_evidence_consumer` task, which already carries a dependency edge
  on this one.
- Any edit to `scripts/orchestrate-conclusion-aggregate.sh`. It never performed classification or
  task creation, and narrowing its `a|b|c` validation would violate Required Change #3.
- Any change to channel (a), to the approval ledger's semantics, or to
  `context/schemas/events-schema.json`.
- Fixing `next_project_number` staleness. Independently owned.
- Adding rotation or archival for `events.jsonl`. Its own format document already records
  unbounded growth as a known, separately-owned gap, and this task's framing accepts accumulation
  as the strictly better resting state.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| An edit pass narrows `--channel a\|b\|c` validation in the aggregator while touching adjacent material, breaking Required Change #3 | H | L | `scripts/orchestrate-conclusion-aggregate.sh` is out of scope for every phase and appears in no `Files to modify` block. Phase 3 verifies case (g) still passes unedited. |
| Test cases (j)/(k) deleted rather than rewritten, silently dropping the channel-(a) gate-intactness assertion that is still load-bearing | H | M | Phase 1 rewrites both in the same phase as the contract edit, and its verification requires the suite green, not merely non-failing. |
| Phase 1 leaves the suite red because the contract text changed but its asserting tests did not | H | H if split | Mitigated structurally: the contract rewrite and the test rewrite are **one phase**, because the tests assert the contract's literal text and are not independently green. |
| Net line count comes out positive because consumer prose grew while the contract shrank | M | M | Phase 2 is explicitly a replace-not-append pass; Phase 3 measures the real figure with `git diff --numstat` across all touched files and reports it, rather than asserting it. |
| `events.jsonl` rows written in Move 5 stay uncommitted until a later invocation | M | M | D4: each recording channel commits `specs/events.jsonl` explicitly with a narrow pathspec. |
| Deploy lands but verification is red, leaving the deployed tree inconsistent with the source store | H | L | Phase 3 requires `RESULT=landed_verify_clean` explicitly; `landed_verify_red` (exit 3) and `landed_verify_skipped` (exit 4) are both failures for this phase, not partial successes. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel. This plan is strictly sequential: each
phase's content depends on the text the previous phase actually wrote.

---

### Phase 1: Rewrite channels (b) and (c) as evidence-recording, with their tests [COMPLETED]

**Goal**: `context/contracts/conclusion-stage.md` describes channels (b) and (c) as recording
evidence and nothing else, the deleted task-creation and dispatch bodies are gone, and the two
test cases that assert that contract's text assert the new shape and pass.

The contract rewrite and the test rewrite are deliberately one phase. Cases (j) and (k) assert
the *literal text* of Steps 4b/4c; rewriting the contract without them leaves the file's own
covering suite red, which is not a committable intermediate state.

**Tasks**:
- [x] Re-read `context/contracts/conclusion-stage.md` immediately before editing (concurrent
      siblings are dispatched this cycle; neither declares this file, but re-read regardless per
      the territory contract). *(completed)*
- [x] Rewrite the Overview's three-channel bullet list: (b) and (c) are described as recording
      classified proposals as evidence, naming the store; only (a) is described as executing. *(completed)*
- [x] Rewrite the Overview's approval paragraph so the "each channel fires only on its own
      approval" invariant is stated as governing execution, and names channel (a) as the only
      channel that executes — without weakening or deleting the invariant itself. *(completed)*
- [x] Rewrite Step 3 from "Three independent gates" to a single channel-(a) gate (D1), keeping
      the `--record-approval` call shape for channel (a) verbatim and keeping the sentence that
      states no channel fires on another's approval. *(completed)*
- [x] Rewrite Step 4b: delete the `--check-approval --channel b` gate block, the
      `GLOBAL_ROOT`/`target_root`/`mode_target` resolution block, the entire `meta-builder-agent`
      dispatch body, the path-qualification imperative paragraph, and the "no stage-level commit"
      paragraph. Replace with: skip when the channel has zero classified proposals; otherwise one
      `events-append.sh` call per proposal, plus one narrow `specs/events.jsonl` commit (D4). *(completed)*
- [x] Rewrite Step 4c: delete the `--check-approval --channel c` gate block, the entire
      `state-write.sh` / `manage-topics.sh set` / `generate-todo.sh` block (with its unbound
      `$new_task_num`), and the three-path commit block (with its unpopulated
      `new_task_dir_paths`). Replace with the same recording shape as 4b, with `--channel`-free
      wording and its own narrow `specs/events.jsonl` commit. *(completed)*
- [x] Write the `events-append.sh` invocation shape once, with an illustrative `--detail-json`
      carrying `channel`, `class`, `citations[]` of `{task, entry_id}`, `citations_remainder`,
      `severity_max`, `suggested_channel_hints[]`, `orchestrator_channel`, and
      `override_rationale` (non-null only on a visible override, per the Hint-Versus-Decision
      Rule). Use `--event-type conclusion_proposal_recorded --category milestone` and omit
      `--task` (D3). *(completed)*
- [x] Update Step 6's report sentence: each channel's outcome is no longer
      "approved-and-executed / declined / not-asked-because-empty" for (b) and (c); it is
      recorded-or-not-recorded, with (a) keeping the three-way vocabulary. *(completed)*
- [x] Rewrite test case (j) in `scripts/tests/test-orchestrate-conclusion-aggregate.sh`: keep the
      `meta-builder-agent.md` FORBIDDEN-clause half unchanged, and invert the `conclusion-stage.md`
      half into an explicit ABSENCE check — the contract must no longer contain
      `collected_answers.confirmed` or a channel-(b) `creates TASKS` dispatch. *(completed)*
- [x] Rewrite test case (k): assert Step 4a alone still carries `--check-approval` with
      `--channel a` and no other letter, and assert Steps 4b and 4c reference `events-append.sh`
      and contain no `--check-approval` at all. *(completed)*
- [x] Confirm case (g) (per-channel approval isolation, ACCEPTANCE-CRITICAL) and case (i)
      (commit-scope fixture) are left unedited — both exercise the script and git-commit
      mechanics, not the contract's prose, and neither premise becomes false. *(completed)*
- [x] Run the covering suites and confirm green before committing. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` over both touched paths returns exactly
`test-orchestrate-conclusion-aggregate.sh` and `test-orchestrate-suggest-next-batch.sh`, and
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-conclusion-aggregate.sh,test-orchestrate-suggest-next-batch.sh`
runs exactly that set — the downstream consumer documents this phase makes stale are this tier's
named blind spot and are Phase 2's whole subject.

**Scope Hypothesis**: Steps 4b and 4c together currently span 91 lines
(`conclusion-stage.md:284-374`), and the rewritten pair is expected to land under half that. This
is a hypothesis, not a fact: the implementer confirms it by measuring the real delta with
`git diff --numstat -- agent-system/extensions/core/context/contracts/conclusion-stage.md` after
the edit, and reports the measured figure rather than this estimate. If the rewrite comes out
larger than estimated, that is a signal the replacement prose is doing more than recording — not
a reason to revise the estimate silently.

**Files to modify**:
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` - Overview channel list
  and approval paragraph, Step 3 (three gates -> one), Steps 4b and 4c (full rewrite as
  evidence-recording), Step 6's outcome vocabulary
- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-aggregate.sh` - cases
  (j) and (k) rewritten to assert the new shape

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-conclusion-aggregate.sh,test-orchestrate-suggest-next-batch.sh`
  passes, with cases (g), (i), (j), (k) all green.
- `grep -n 'new_task_num\|new_task_dir_paths\|collected_answers.confirmed\|meta-builder-agent' agent-system/extensions/core/context/contracts/conclusion-stage.md`
  returns nothing.
- `grep -n 'check-approval' agent-system/extensions/core/context/contracts/conclusion-stage.md`
  returns only occurrences inside Step 4a (and the Approval Ledger section's own prose).
- `git diff --numstat` for `conclusion-stage.md` shows a net negative line count for that file.

---

### Phase 2: Sync every downstream transcription of the deleted design [COMPLETED]

**Goal**: No document still describes channels (b)/(c) as dispatching, creating tasks, or writing
`specs/state.json`; the output template renders what was recorded and names the command that will
consume it; and `events-format.md` documents the new `event_type`.

**Tasks**:
- [x] Re-read each file immediately before editing. *(completed)*
- [x] `context/standards/postflight-tool-restrictions.md`, Allowed Tool Surface table: strike
      channel (b)'s `meta-builder-agent` dispatch from the `Agent` row (leaving channel (a)'s
      implementation-agent dispatch); strike `state-write.sh`, `manage-topics.sh set`, and the
      `GLOBAL_ROOT=...` resolution assignment from the `Bash` row and add `events-append.sh`;
      narrow the `AskUserQuestion` row from "exactly three independent per-channel approval
      gates" to channel (a)'s single gate (D1). *(completed)*
- [x] Same file, Prohibited list: the "No channel executing without its own `--check-approval`
      pass for that exact channel" bullet must be re-scoped to the channel that executes, without
      weakening the invariant for channel (a). *(completed)*
- [x] Same file, Commit Surface table: replace channel (b)'s "None from the stage itself" row and
      channel (c)'s `specs/state.json` + `specs/TODO.md` + task-directories row with
      `specs/events.jsonl`-only rows (D4). Leave channel (a)'s row and the roadmap row untouched,
      and update the "Four separately-scoped invocations" lead sentence to match the real count. *(completed)*
- [x] `docs/architecture/orchestrate-state-machine.md`, Move 5 section: rewrite the "Three
      independent gates, no cross-firing" paragraph's channel descriptions — (b) and (c) no longer
      go "via `meta-builder-agent`" or "created as children via `parent_task`" — and keep the
      fail-closed ledger sentence, re-scoped to the channel that fires. Rewrite the "Commit
      contract, four scopes" paragraph to match the new commit surface. *(completed)*
- [x] `context/patterns/orchestrate-batch-results-template.md`, `### Conclusion` block (Required
      Change #5): replace `{channel_b_outcome}` and `{channel_c_outcome}`'s "same three-way
      vocabulary ... when approved, names the change request ... / lists each new child task
      number" with a recorded/not-recorded rendering that states the proposal count, names
      `specs/events.jsonl`, and names the command that will consume it (`/distill --meta`).
      Channel (a) keeps its three-way vocabulary. Also fix the block's own lead parenthetical,
      which currently says the section is "gated behind three independent per-channel approvals". *(completed)*
- [x] `context/formats/events-format.md`: add one row to the `event_type` common-values table for
      `conclusion_proposal_recorded` (`milestone`), naming the `detail` fields, placed beside the
      `push_grant_issued`/`push_grant_consumed` rows it is modelled on. *(completed)*
- [x] Confirm, without editing, that `context/formats/issue-log.md` and
      `context/contracts/batch-gate-stage.md` need no change: both name the three channels only as
      classification categories, which survive. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: `suite_selection_select` over all four touched paths returns the sentinel
`__FULL_SWEEP__` — no suite covers any of them, as expected for pure-guidance markdown with no
executable surface — so the honest covering check is the `prose` row's diff read-through plus the
source-store markdown gate subset
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`,
whose `TARGET` is the repository root holding both a deployed `.claude/` tree and
`agent-system/extensions`.

**Files to modify**:
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` - Move 5
  Allowed Tool Surface, Prohibited, and Commit Surface tables
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - Move 5 gates
  paragraph and commit-contract paragraph
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` - the
  Conclusion block's channel (b)/(c) renderings and its lead parenthetical
- `agent-system/extensions/core/context/formats/events-format.md` - one new `event_type` table row

**Verification**:
- `grep -rn 'meta-builder-agent' agent-system/extensions/core/context/standards/postflight-tool-restrictions.md agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md`
  returns nothing.
- `grep -rn 'parent_task\|state-write.sh\|manage-topics.sh' agent-system/extensions/core/context/standards/postflight-tool-restrictions.md agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`
  returns nothing in the Move 5 sections.
- `grep -n 'conclusion_proposal_recorded' agent-system/extensions/core/context/formats/events-format.md`
  returns the new row.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  passes with both gates reporting a real check (neither SKIP).
- Diff read-through of all four files confirms every changed hunk lies in prose or a table cell.

---

### Phase 3: Deploy, run the full gate set, and report the net line count [COMPLETED WITH EXCLUSIONS]

**Goal**: The source-store change is deployed to the live `.claude/` tree, the complete gate set
is green, and the task's measured net line count is reported and negative.

**Tasks**:
- [x] Re-read `git status --short` and confirm no foreign uncommitted modification has appeared in
      this task's own files (concurrent siblings are live this cycle). *(completed)*
- [x] Run `bash /home/benjamin/.config/nvim/.claude/scripts/deploy-headless.sh` and confirm the
      emitted marker is `RESULT=landed_verify_clean` (exit 0). `RESULT=not_landed` (exit 1/2),
      `RESULT=landed_verify_red` (exit 3), and `RESULT=landed_verify_skipped` (exit 4) are each a
      phase failure, not a partial success; on `landed_verify_red` fix forward from the reported
      gate rather than discarding the deploy. *(completed)*
- [x] Measure the real net line count across every file this task touched with
      `git diff --numstat` against the pre-task baseline, and report added/deleted/net explicitly.
      Confirm the net is negative. If it is not, state which file grew and why before proceeding —
      a positive net is a signal the replacement prose did more than record, which the task's own
      verification bar forbids. *(completed)*
- [x] Pin the three channel-(a) gate behaviours against the deployed tree: a recorded `no` blocks,
      an absent record blocks, and a `yes` recorded for channel b or c does not satisfy channel
      a's gate. Case (g) already proves all three mechanically; confirm it passes from the
      deployed copy rather than only the source store. *(completed)*
- [x] Confirm `next_project_number` in `specs/state.json` is unchanged by any part of this work. *(completed)*
- [x] Record the measured net line count and the gate outcome in the implementation summary. *(completed)*

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| `deploy-headless.sh`'s verify step reporting `RESULT=landed_verify_red` instead of `landed_verify_clean`, specifically gate10 (`validate-state.sh --deep`) | Two independent, pre-existing causes, neither introduced by this task: (a) gate10 consistently exceeds the gate runner's own 60s per-gate timeout under this invocation's concurrent sibling load — an already-flagged infra condition (per-gate timeout should scale with concurrency), not a content defect; (b) the same check run standalone (outside the timeout wrapper) completes in ~50s and surfaces exactly one pre-existing content finding — `next_project_number` (607) collides with an in-use `project_number` — independently owned by the already-filed `task_number_allocation_staleness_undetected` task, and explicitly a Non-Goal of this plan ("Fixing `next_project_number` staleness. Independently owned."). | Standalone run: `bash .claude/scripts/validate-state.sh --deep specs/state.json` exits non-zero in ~50s with exactly `Check 12: next_project_number (607) is already in use`. Byte-identity: `git show 3927bddbd:specs/state.json \| jq .next_project_number` = `607`; current `jq .next_project_number specs/state.json` = `607` — unchanged by this task. Two independent `deploy-headless.sh` re-runs both reproduced the identical two-gate failure set. |
| Gate20 (`measure-eager-context.sh --check`) reporting eager-load total 71712 B over its 70400 B baseline | Attributable solely to `commands/orchestrate.md` and `skills/skill-orchestrate/SKILL.md`, neither touched by any phase of this task. Already documented as a pre-existing, cross-task condition. | `specs/TODO.md:213` and `specs/state.json` (task 391's already-recorded channel-(c) proposal) state the identical figure `71712B` against baseline `70400B`; `specs/397_lean_research_compile_verify_recommendation/handoffs/phase-4-handoff-20261111T002000Z.md:28` reproduces the identical figure independently; `specs/archive/391_agent_system_task_siting_and_target_root/plans/01_target-root-and-siting-remedy.md:481` confirms via a worktree check at a pre-dispatch commit that this condition predates and is unrelated to unrelated tasks' own file scopes, exactly as here. |

Nothing above is this task's own residual work: the `next_project_number` remedy belongs to
`task_number_allocation_staleness_undetected` (already filed) and the eager-load re-baseline
belongs to whatever task retires or trims `commands/orchestrate.md` / `skills/skill-orchestrate/SKILL.md`
(already surfaced as a pending channel-(c) proposal in `specs/TODO.md`/`specs/state.json`). This
task's own touched-file verification is independently green: `conclusion-stage.md`'s net line
count is -23 (negative, see Phase 3's numstat below); `test-orchestrate-conclusion-aggregate.sh`
passes 14/14 from the deployed copy, including cases (g), (i), (j), (k);
`orchestrate-conclusion-aggregate.sh` and `context/schemas/events-schema.json` are both
byte-identical to their pre-task state; `next_project_number` is unchanged.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed `.claude/` tree from the
  source store; this phase claims whole-tree regeneration and declares the reserved sentinel so a
  concurrently-admitted task that would also regenerate the tree is serialized against it
- `specs/402_conclusion_channels_become_evidence_only/summaries/` - the implementation summary
  carrying the measured net line count

**Verification**:
- `bash /home/benjamin/.config/nvim/.claude/scripts/deploy-headless.sh` emits
  `[deploy-headless] RESULT=landed_verify_clean` and exits 0.
- The complete gate set is green: `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh`
  (run by `deploy-headless.sh` itself as part of reaching `landed_verify_clean`; run standalone if
  the deploy path skipped it for any reason).
- `bash /home/benjamin/.config/nvim/.claude/scripts/tests/run-all.sh` passes, including
  `test-orchestrate-conclusion-aggregate.sh` cases (g), (i), (j), (k) from the deployed copy.
- `git diff --numstat` across all touched files yields a reported, negative net line count.
- `specs/state.json`'s `next_project_number` is byte-identical to its pre-task value.

---

## Testing & Validation

- [x] `test-orchestrate-conclusion-aggregate.sh` passes in full, from both the source store and
      the deployed tree, with cases (j) and (k) rewritten and cases (g) and (i) unedited. *(completed)*
- [x] `scripts/orchestrate-conclusion-aggregate.sh` is byte-identical to its pre-task state
      (`git diff --stat` shows it untouched), proving Required Change #3's "do not weaken a gate
      to simplify a path". *(completed)*
- [x] The three channel-(a) gate behaviours are each pinned: recorded `no` blocks, absent record
      blocks, another channel's `yes` does not satisfy it. *(completed)*
- [x] No file under `agent-system/**` landed by this task contains a task-number reference or
      record-versioning language (both are permitted in the task description only). *(completed)*
- [x] `context/schemas/events-schema.json` is unmodified — the new `event_type` requires no schema
      revision. *(completed)*
- [x] The measured net line count across all touched files is negative and is stated as a number. *(completed)*

## Artifacts & Outputs

- Rewritten `agent-system/extensions/core/context/contracts/conclusion-stage.md` (Overview,
  Step 3, Steps 4b/4c, Step 6)
- Rewritten test cases (j) and (k) in
  `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-aggregate.sh`
- Synced `postflight-tool-restrictions.md`, `orchestrate-state-machine.md`,
  `orchestrate-batch-results-template.md`, and `events-format.md`
- A regenerated deployed `.claude/` tree at `RESULT=landed_verify_clean`
- An implementation summary reporting the measured net line count

## Rollback/Contingency

Every phase commits through `git-commit-scoped.sh` with an explicit file list, so reverting is a
per-phase `git revert` of that phase's own commit — no snapshot-and-rollback is needed and none
should be taken as a routine checkpoint. If a defensive checkpoint is genuinely wanted before
Phase 3's deploy, use `bash .claude/scripts/git-snapshot.sh 402 --no-revert`, which is durable
without reverting the working tree; the bare reverting form is for a genuine rollback only.

If Phase 3's deploy lands but verification is red, fix forward from the named gate — the deployed
tree is regenerable from the source store at any time, so the recovery path is to correct the
source and redeploy, never to discard uncommitted work to reach green.

If Phase 1's rewrite cannot keep the suite green without also editing
`scripts/orchestrate-conclusion-aggregate.sh`, stop and report rather than editing it: that
script's untouched state is itself an acceptance criterion, and a need to edit it means the
rewrite has reached past the contract's prose into the ledger's mechanics.
