# Implementation Plan: Task #602

- **Task**: 602 - Improve the conclusion stage's next-batch proposal quality
- **Status**: [IMPLEMENTING]
- **Effort**: 7 hours
- **Dependencies**: None
- **Research Inputs**: specs/602_conclusion_stage_next_batch_proposal_quality/reports/01_conclusion-stage-next-batch-proposal-quality.md
- **Artifacts**: plans/01_next-batch-proposal-quality.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/context/standards/artifact-management.md
  - .claude/context/standards/tasks.md
  - .claude/rules/source-store-deploy-boundary.md
  - .claude/rules/no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

An orchestration must end on something an operator can act on. Today the conclusion stage's
Step 7 can end on nothing but two-task collision sequences, because
`orchestrate-suggest-next-batch.sh`'s `suggest_from_pool()` consumes a colliding pair out of the
candidate pool before the admitted remainder can be offered as a batch, renders at most one
option, and never writes the edges it prints. This plan makes a collision pair *additive*
information alongside a probe-verified joint batch, renders up to three labelled batch options
(one per selection-doctrine criterion), gates an actual `--write-edges` call behind one explicit
approval backed by its own ledger key, and lands the roadmap-prune ruling. Every admissibility
fact continues to arrive as a field on an `orchestrate-batch-admit.sh` verdict — no overlap or
admission predicate is copied, forked, or approximated anywhere in this work.

### Research Integration

The research report confirms Defects 1-3 line-by-line in `suggest_from_pool()` /
`propose_edge_for_pair()` / `mode_next_batch()`, and establishes that Defect 4's premise has
dissolved: `roadmap-integration.sh --prune` is now a deprecated alias for `--regenerate`. It also
establishes that the remedy path for Defect 3 already exists end-to-end inside the script and the
gap is purely at the caller. Two findings beyond the report are folded in below: the edge-write
approval needs a ledger key the aggregate script does not yet accept, and
`postflight-tool-restrictions.md`'s Move 5 allowed-tool table does not currently permit the
`AskUserQuestion` this change introduces (nor does it list the suggester or the roadmap lint that
Step 7 and Step 5 already invoke).

### Premise Re-Validation

The dispatch's lexically-extracted trigger lines were each checked against live state. Results,
stated explicitly even where they confirm the description unchanged:

| Carried claim | Result |
|---|---|
| Source store is `agent-system/extensions/core/**`, redeploy via `deploy-headless.sh` | **Confirmed.** `.claude-extensions.json` resolves `core.source_dir` to `/home/benjamin/.config/nvim/agent-system/extensions/core`; `.claude/scripts/deploy-headless.sh` exists |
| `suggest_from_pool()` "returned success having never once reached the joint-batch branch" | **Confirmed.** The joint-batch render is gated on `${#dropped_other[@]} -eq 0` AND `${#handled_pair_members[@]} -eq 0`; the fall-through returns 0 whenever `any_sequence_rendered = true` |
| "a collision pair must be ADDITIVE ... never a replacement" | Requirement, not a figure; carried unchanged and adopted as Phase 1's acceptance shape |
| "the conclusion stage's Step 7 never passes `--write-edges`" | **Confirmed.** `conclusion-stage.md`'s Step 7 invokes `--next-batch --session-id "$session_id"` only, and is documented INFORMATIONAL with no gate |
| "Decision 2: never mutate `specs/state.json` unasked" | **Confirmed.** The script's header disposition (d) states exactly this; the plan therefore gates rather than unconditionally writing |
| The separate batch-lint record "must never author, suggest or rank a batch" | **Confirmed as a live boundary.** `lint-roadmap-batch-proposals.sh` is invoked advisorily from Step 5 over the regenerated file; this plan adds nothing to it and reads nothing from it |
| "three other open records" declare `conclusion-stage.md`; "never to exclude them" | **CORRECTED to two.** A live `specs/state.json` query for non-terminal tasks declaring `conclusion-stage.md` in `file_scope` returns exactly 558 and 562. The third record named by the Territory Note is completed and archived. The never-exclude disposition stands, against a two-task group |
| "MEASURED LIVE against a 138-task ready pool: 4 lines rendered, 0 joint batches, 4 pair sequences" | **CARRIED-UNVERIFIED** (source: the task description's own measurement session). Re-deriving `build_ready_pool()`'s documented predicate against live `specs/state.json` yields **75** ready tasks, not 138 — the pool has changed since the measurement, so the pool-size figure is stale. The 4-sequences/0-batches *shape* is not re-measured here (it would consume the live probe budget mid-orchestration); it is instead reproduced as Phase 1's deterministic fixture, which is what the acceptance criterion actually requires |
| `--prune` is "built and working" but excluded | **CORRECTED, measured live.** `roadmap-integration.sh`'s `mode_prune()` prints a deprecation note, reassigns `MODE="regenerate"`, and calls `mode_regenerate`; `PRUNED_COUNT` is hard-coded 0. Defect 4 resolves as a ruling plus a stale-rationale correction, not a code change |

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch, and no roadmap phases are included (the
roadmap flag is not set).

## Goals & Non-Goals

**Goals**:

- A collision pair renders as an ordered sequence **and** a probe-verified joint batch renders
  alongside it, in the same output, for a pool whose selected candidates are entirely pairs.
- Up to three distinct, probe-verified batch options render per Mode A invocation, each labelled
  with the coherence criterion that makes it cohere (shared territory / topic cohesion / graph
  width) and each carrying its own admission evidence.
- `MAX_PROBE_INVOCATIONS` stays at its current value, stays a single shared counter, and the
  cap-reached condition stays explicitly rendered — never a silent truncation of the option list.
- The conclusion stage can actually write the proposed edges, through the existing
  `--write-edges` path, behind one explicit approval with its own fail-closed ledger key; a
  declined approval leaves `specs/state.json` byte-identical.
- The roadmap-prune question is settled with its grounds recorded, and Step 5's stale rationale
  is corrected to the current fact.
- A test companion covers each of the four defects; shellcheck clean.

**Non-Goals**:

- No second copy, fork, or approximation of the admission or overlap predicate. Every overlap
  fact arrives as a verdict field (`defer_reason`, `collision_scope`, `colliding_task_number`,
  `overlapping_path`), exactly as today.
- No authoring-time batch *validator*. The advisory lint over hand-authored ROADMAP.md batch
  blocks is a separate record; this work proposes machine-derived batches and never validates
  hand-authored ones. Neither side's code is touched by the other.
- No change to `roadmap-integration.sh` itself. Its `--prune`/`--regenerate` equivalence is
  already correct; the defect was in the conclusion stage's recorded reason for excluding it.
- No new roadmap-generator flag, no new agent type, no change to `orchestrate-batch-admit.sh`.
- Multi-option rendering is scoped to Mode A (`--next-batch`). Mode B (`--alternatives`) keeps
  its single-pool behavior: its pool is already queue-filtered and its purpose is to find *any*
  disjoint set, not to offer a menu.
- The time-stamped-claim convention is unchanged: every rendered option still states it was
  admissible when suggested and must be re-verified at dispatch.

## Decisions

- **D1 — option count is 3, one per doctrine criterion.** A named constant
  `MAX_BATCH_OPTIONS=3` bounds Mode A's option loop, mapping one-to-one onto the three criteria
  `select_candidates()` already implements as Pass 1/2/3. Bounded, more than one, each
  independently probe-verified. An option whose rendered task set duplicates an
  already-rendered option's set is skipped rather than printed twice.
- **D2 — the probe budget is not raised.** `MAX_PROBE_INVOCATIONS` stays 20 and stays one shared
  counter across every probe in the invocation. When the cap is reached partway through a
  multi-option render, the existing explicit cap-reached line fires and the loop stops; options
  already rendered are retained and the output says plainly that the option list was cut short by
  the cap.
- **D3 — the edge-write approval gets its own ledger key, not a fourth channel.** Step 7 remains
  NOT a channel: it derives from `specs/state.json`, not `issues.jsonl`, and the
  Exactly-One-Channel and Hint-Versus-Decision rules still do not apply to it. The approval is
  recorded and checked under a dedicated key (`edges`) added to
  `orchestrate-conclusion-aggregate.sh`'s closed `--channel` vocabulary, so the per-key
  fail-closed read gives Step 7 its own independent gate and no channel can fire on it (or it on
  any channel's approval).
- **D4 — the roadmap-prune exclusion is kept, on new grounds (a reasoned no).** Not because the
  original caution outweighs the need, but because the need no longer exists: `--regenerate`
  renders `## Next` and `## Open work` wholly from `specs/state.json`, so a terminal task is
  never written into the file and there is nothing for a prune pass to remove — `--prune` is a
  deprecated alias for `--regenerate`. Step 5's recorded rationale, which still cites
  "removes content outright", is corrected to state this current fact.
- **D5 — `propose_edge_for_pair()` is never called twice for the same pair in one invocation,
  and no colliding pair is ever silently dropped.** An invocation-scoped reported-pairs set
  enforces both halves, preserving the script header's existing "neither form may ever silently
  drop a colliding pair" constraint across the new second-pass probe Phase 1 introduces.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The conflict-free-subset probe Phase 1 adds consumes extra probes, exhausting the shared cap on a dense pool before any option renders | M | M | D2's cap-reached line is wired to fire from the new code path too, and Phase 2's test case drives the cap deliberately to prove the message still appears rather than a silent truncation |
| The multi-option loop re-renders the same task set under two different labels, making the output look like more choice than it offers | M | M | D1's duplicate-set skip, pinned by a test case asserting no two rendered options carry the identical task list |
| A new `AskUserQuestion` at Step 7 is miswired to fire on channel (a)'s approval, breaking the "no channel fires on another channel's approval" invariant | H | L | D3's dedicated ledger key plus a test case asserting cross-key isolation in both directions (`edges` yes does not satisfy `a`; `a` yes does not satisfy `edges`); the gate is a `--check-approval` call for its own key, never a reuse of channel (a)'s |
| A declined approval still mutates `specs/state.json` because the non-`--write-edges` run already fired somewhere on the path | H | L | Step 7's first invocation is the default (propose-only) form, which the script header documents as never mutating state; the write happens only in a second invocation reached after the gate passes. Phase 6 verifies byte-identity of `specs/state.json` across a declined run |
| Editing `conclusion-stage.md` collides with the two other open records declaring the same file | M | M | Their edits are in different sections (siting/phrasing convention; "The Filter Predicate") from this task's (Step 5's rationale, Step 7's body). Per the guardrails' Rule 1 the right disposition is to batch them or serialize them with an explicit edge — never exclude. Recorded for the next orchestration's admission decision; it does not block any phase here |
| `postflight-tool-restrictions.md`'s Move 5 table is edited more widely than this change needs | M | L | Phase 4 adds exactly what this change requires (the Step 7 `AskUserQuestion` scope, the suggester in the Bash row) plus the already-invoked roadmap lint the table omits; nothing else in that file is touched |
| `deploy-headless.sh`'s full gate surfaces pre-existing, unrelated failures and they are read as this task's regression | M | M | Phase 6 requires every red finding to be attributed: either it names a file this task touched (a real defect) or it is demonstrably pre-existing and recorded via `issue-record.sh`, never silently accepted |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2, 4 | 1 (for 2); 3 (for 4) |
| 3 | 5 | 2, 4 |
| 4 | 6 | 1, 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Additive Joint Batch Alongside Pair Sequences [COMPLETED]

**Goal**: A pool whose selected candidates are entirely collision pairs renders at least one
probe-verified joint batch line in addition to the ordered-sequence lines.

**Tasks**:

- [x] In `suggest_from_pool()`, add an invocation-scoped reported-pairs set (an associative
      array keyed by `"${lower}:${higher}"`) consulted before every `propose_edge_for_pair()`
      call, so no pair is reported twice across the rounds and the second pass below, and none is
      silently dropped (D5). *(completed)*
- [x] Replace the fall-through `[ "$any_sequence_rendered" = true ] && return 0` with a
      **conflict-free-subset second pass**: when the round loop exits having rendered sequences
      but no joint batch, build the candidate subset from (a) every member admitted in any round
      and (b) the LOWER member of each reported pair, deduped and ascending. *(completed)*
- [x] Probe that subset through the existing `probe_candidate_set()` — never a local overlap
      comparison — and render it as a joint `/orchestrate a, b, c` line with
      `render_verdict_evidence()` and the existing time-stamped-claim footer once every verdict
      is `admit`. *(completed)*
- [x] When the subset's own probe still defers a member: shrink by the same rule the main loop
      uses (drop the deferred member) and re-probe; report any NEW in_batch collision pair
      through `propose_edge_for_pair()` (subject to the reported-pairs set) rather than dropping
      it silently. *(completed)*
- [x] Wire the reserved return code 9 (cap reached) from the new probe calls to the same explicit
      cap-reached line the main loop already prints, retaining anything already rendered. *(completed)*
- [x] Return 0 when any sequence line and/or any joint batch line was rendered; return 1 only
      when nothing at all could be suggested from the pool. *(completed)*
- [x] Extend `test-orchestrate-suggest-next-batch.sh` with case (h): a ready pool whose selected
      candidates are exactly four exact-`file_scope`-colliding pairs. Assert four ordered-sequence
      lines AND at least one `/orchestrate` joint-batch line in the same output, and assert the
      joint line's members are all `admit` in the rendered evidence. *(completed)*
- [x] Assert in case (h) that `specs/state.json` in the scratch tree is byte-identical before and
      after the default (non-`--write-edges`) run. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash /home/benjamin/.config/nvim/.claude/scripts/tests/run-all.sh --only test-orchestrate-suggest-next-batch.sh`
is the covering check — `suite_selection_select` over this phase's two paths returns exactly
`test-orchestrate-suggest-next-batch.sh`.

**Scope Hypothesis**: the fixture reproduces the description's measured 4-pair-sequences /
0-joint-batches shape (the pool-size figure of 138 is stale — the live ready pool re-derives to 75
— so the fixture pins the shape, not the pool size). Confirm at implementation time by running
case (h) against the pre-change script and observing zero joint-batch lines, then against the
changed script and observing at least one.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh` - reported-pairs set, conflict-free-subset second pass, cap-reached wiring in the new path
- `agent-system/extensions/core/scripts/tests/test-orchestrate-suggest-next-batch.sh` - new case (h): all-pairs pool renders sequences AND a joint batch

**Verification**:
- `bash /home/benjamin/.config/nvim/.claude/scripts/tests/run-all.sh --only test-orchestrate-suggest-next-batch.sh`
  exits 0 with every case passing, case (h) included.
- `shellcheck` is clean on both touched files per `context/standards/shell-strict-mode.md`.
- `grep` over the changed script finds no directory-prefix comparison, no overlap-helper
  sourcing, and no new field derived locally rather than read off a verdict — case (f)'s
  existing no-forked-predicate regression still passes.

---

### Phase 2: Several Labelled, Probe-Verified Batch Options [COMPLETED]

**Goal**: Mode A renders up to three distinct batch options, each labelled with its coherence
criterion and carrying its own admission evidence, within the unchanged shared probe budget.

**Tasks**:

- [x] Refactor `select_candidates()`'s three passes into one parameterized helper
      (`select_candidates_for_criterion <territory|topic|width> <ready...>`) emitting that
      criterion's own ordered, `MAX_TASKS`-truncated candidate list. `select_candidates()` keeps
      its current behavior by composing the three — no pass logic is duplicated. *(completed)*
- [x] Add the named constant `MAX_BATCH_OPTIONS=3` with a comment recording D1 (one option per
      doctrine criterion; bounded; each independently probe-verified). *(completed)*
- [x] In `mode_next_batch()`, loop the three criteria in doctrine order (shared territory, topic
      cohesion, graph width), calling the Phase 1 engine once per criterion with that criterion's
      label, and print each rendered option under a header naming the criterion and why it
      coheres. *(completed)*
- [x] Skip a criterion whose candidate pool is empty, and skip an option whose rendered task set
      is identical to an already-rendered option's set (D1's duplicate guard). *(completed)*
- [x] Keep `PROBE_INVOCATION_COUNT` / `MAX_PROBE_INVOCATIONS` as the one shared counter across
      all three options; on reaching the cap mid-render, print the existing explicit cap-reached
      line, state that the option list was cut short by the cap, retain the options already
      rendered, and stop (D2). *(completed)*
- [x] Leave `mode_alternatives()` on the single-pool path, with a comment recording that the
      multi-option loop is deliberately Mode A only. *(completed)*
- [x] Extend the test suite with case (i): a ready pool shaped so that the territory, topic, and
      width criteria yield different sets; assert two or more distinct labelled options render,
      each with its own `admit` evidence, and no two options carry the identical task list. *(completed)*
- [x] Extend the test suite with case (j): drive the shared cap to exhaustion during a
      multi-option render (a low `--max-tasks` with many candidates, mirroring existing case
      (g)'s technique) and assert the cap-reached line appears verbatim while the
      already-rendered options remain in the output. *(completed: used case (g)'s own
      MAX_PROBE_INVOCATIONS sed-override technique directly, set to 1, rather than a low
      --max-tasks -- a more direct and deterministic way to exhaust the cap mid-multi-option
      render with a 4-task fixture; the acceptance behavior asserted is identical)*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash /home/benjamin/.config/nvim/.claude/scripts/tests/run-all.sh --only test-orchestrate-suggest-next-batch.sh`
is the covering check — `suite_selection_select` over this phase's two paths returns exactly
`test-orchestrate-suggest-next-batch.sh`.

**Scope Hypothesis**: three options is asserted as the right bound (D1), one per criterion the
selection doctrine already names. Confirm at implementation time that each of the three criteria
can in fact produce a distinct non-empty pool from case (i)'s fixture; if one criterion
structurally cannot (e.g. the width pool is always a superset of the others for the fixture
shape), record that in the phase's notes and state the effective option count rather than
claiming three.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh` - parameterized criterion selector, `MAX_BATCH_OPTIONS`, Mode A option loop, duplicate-set skip, cap-reached handling
- `agent-system/extensions/core/scripts/tests/test-orchestrate-suggest-next-batch.sh` - new cases (i) multiple distinct labelled options and (j) cap reached mid-multi-option-render

**Verification**:
- `bash /home/benjamin/.config/nvim/.claude/scripts/tests/run-all.sh --only test-orchestrate-suggest-next-batch.sh`
  exits 0, cases (i) and (j) included.
- Case (g)'s existing cap assertion still passes unchanged, proving the counter stayed shared
  rather than becoming per-option.
- `shellcheck` is clean on both touched files.

---

### Phase 3: A Dedicated Fail-Closed Approval Key for the Edge Write [NOT STARTED]

**Goal**: `orchestrate-conclusion-aggregate.sh` accepts and gates a dedicated `edges` approval
key, fully isolated from channels (a), (b), and (c) in both directions.

**Tasks**:

- [ ] Extend the closed `--channel` vocabulary in both `--record-approval` and
      `--check-approval` from `a|b|c` to `a|b|c|edges`, updating the two `case` arms and both
      error messages so an unrecognized value still fails loudly.
- [ ] Update the script's usage header and its ledger-shape comment to describe the key set,
      stating explicitly that `edges` is a non-channel approval key for the conclusion stage's
      next-batch edge write and NOT a fourth channel.
- [ ] Leave the fail-closed read semantics untouched: an absent record, a `no`, or a malformed
      ledger all read as not approved for `edges` exactly as for `a`/`b`/`c`.
- [ ] Extend `test-orchestrate-conclusion-aggregate.sh`'s approval-isolation case with the
      `edges` key: recording `yes` for `edges` leaves `a`, `b`, `c` not-approved; recording `yes`
      for `a` leaves `edges` not-approved; an unrecorded `edges`, a recorded `no`, and a
      malformed ledger each read as not-approved.
- [ ] Assert an invalid `--channel` value is still rejected with the documented exit status.

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash /home/benjamin/.config/nvim/.claude/scripts/tests/run-all.sh --only test-orchestrate-conclusion-aggregate.sh,test-orchestrate-suggest-next-batch.sh`
is the covering check — `suite_selection_select` over this phase's two paths returns exactly
those two suite names.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-conclusion-aggregate.sh` - `edges` added to the closed key vocabulary in both modes; usage header and ledger-shape comment updated
- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-aggregate.sh` - `edges` cross-key isolation assertions added to the approval-isolation case

**Verification**:
- `bash /home/benjamin/.config/nvim/.claude/scripts/tests/run-all.sh --only test-orchestrate-conclusion-aggregate.sh,test-orchestrate-suggest-next-batch.sh`
  exits 0 with every case passing.
- The pre-existing per-channel isolation assertions for `a`/`b`/`c` pass unchanged.
- `shellcheck` is clean on both touched files.

---

### Phase 4: Gate the Edge Write at Step 7 [NOT STARTED]

**Goal**: The conclusion stage presents the proposed edges, takes one explicit approval, and only
then invokes the existing `--write-edges` path; a declined approval mutates nothing.

**Tasks**:

- [ ] Rewrite `conclusion-stage.md`'s Step 7 body as: (1) invoke the suggester in its default,
      non-`--write-edges` form; (2) when that output contains at least one proposed edge, ask one
      `AskUserQuestion` presenting the proposed edges and their ordered-sequence lines only; (3)
      record the answer via `--record-approval --channel edges`; (4) gate on
      `--check-approval --channel edges`; (5) only when that gate passes, re-invoke the suggester
      with `--write-edges` and fold its re-probe evidence into the Step 6 report.
- [ ] State in Step 7 that a zero-proposed-edge run is never asked about and skips the gate
      entirely (no ledger record, no second invocation), mirroring channel (a)'s
      zero-proposal posture.
- [ ] State in Step 7 that a declined approval leaves `specs/state.json` byte-identical, because
      the default invocation never mutates state and the write lives only in the gated second
      invocation.
- [ ] Keep Step 7's existing standing as NOT a fourth channel explicit, and state that the
      `edges` key is an independent approval key, so no channel fires on it and it fires on no
      channel's approval.
- [ ] In `postflight-tool-restrictions.md`'s Move 5 Allowed Tool Surface table: widen the
      `AskUserQuestion` row to cover Step 7's edge-write gate alongside channel (a)'s gate, and
      add `orchestrate-suggest-next-batch.sh` (both the default and `--write-edges` forms) and
      `lint/lint-roadmap-batch-proposals.sh` to the `Bash` row, which omits both scripts the
      stage body already invokes.
- [ ] Add one Prohibited bullet mirroring channel (a)'s: no edge write without a
      `--check-approval` pass for the `edges` key specifically.

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` over this phase's two paths returns
`__FULL_SWEEP__` — no suite covers either file, both being pure-guidance source-store markdown —
so the covering check is the source-store gate subset
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
run together with the `local` row's diff read-through.

**Files to modify**:
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` - Step 7 rewritten as a gated edge-write step; its not-a-fourth-channel standing and the `edges` key's independence stated
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` - Move 5 `AskUserQuestion` and `Bash` rows widened; one Prohibited bullet added

**Verification**:
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  exits 0 with neither gate reporting SKIP (both resolve in this repository, which is
  simultaneously the deploy consumer and the source store).
- Diff read-through confirms every changed hunk in both files is prose or table content, and that
  Step 7's rendered command strings name `--channel edges`, never `--channel a`.
- `bash /home/benjamin/.config/nvim/.claude/scripts/check-task-references.sh` reports no
  task-number reference in either file.

---

### Phase 5: Land the Prune Ruling and the Render Contract [NOT STARTED]

**Goal**: The roadmap-prune ruling is recorded with its current grounds, and the report template
describes the additive, multi-option, gated-edge-write render instead of the superseded
either/or behavior.

**Tasks**:

- [ ] Replace Step 5's recorded rationale for excluding `--prune` with the current fact (D4):
      `--regenerate` renders `## Next` and `## Open work` wholly from `specs/state.json`, so no
      terminal task is ever written into the file and `--prune` is a deprecated alias for
      `--regenerate` — there is nothing left for a prune pass to remove, which is why this stage
      calls `--regenerate` alone. Cite `roadmap-integration.sh`'s own header as the source of
      truth.
- [ ] Rewrite `orchestrate-batch-results-template.md`'s `**Suggested next batch**:` block: a
      colliding pair renders as its own ordered-sequence line **in addition to**, never instead
      of, a joint batch line; up to three labelled options render, each naming its coherence
      criterion and carrying its own admission evidence; the cap-reached line appears verbatim
      when the shared probe budget cuts the option list short; the proposed edges and the
      approval outcome (approved-and-written with re-probe evidence, declined, or
      not-asked-because-empty) are rendered; the no-suggestible-batch case is still omitted with
      an explicit reason rather than left blank.
- [ ] Add one sentence to `context/patterns/roadmap-update.md` recording the
      `--prune`/`--regenerate` equivalence and pointing at `roadmap-integration.sh`'s header as
      the source of truth, so the next reader does not re-derive it from the script.
- [ ] Re-read the three edited files for record-versioning language and task-number references,
      both prohibited under `agent-system/**`.

**Timing**: 1 hour

**Depends on**: 2, 4

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` over this phase's three paths returns
`__FULL_SWEEP__` — all three are pure-guidance source-store markdown with no mapped suite — so
the covering check is
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
run together with the `local` row's diff read-through.

**Files to modify**:
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` - Step 5's prune rationale corrected to the current fact
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` - `**Suggested next batch**:` block rewritten for the additive, multi-option, gated-edge-write render
- `agent-system/extensions/core/context/patterns/roadmap-update.md` - one sentence recording the `--prune`/`--regenerate` equivalence

**Verification**:
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  exits 0 with neither gate reporting SKIP.
- `grep` over the three files finds no occurrence of the superseded "instead of a plain joint
  list" phrasing and no "removes content outright" rationale.
- `bash /home/benjamin/.config/nvim/.claude/scripts/check-task-references.sh` reports no
  task-number reference in any of the three files.
- Diff read-through confirms every changed hunk is prose, and that no deliverable states its own
  draft history.

---

### Phase 6: Deploy, Full Gate, and End-to-End Approval Proof [NOT STARTED]

**Goal**: The source-store changes are deployed, the complete gate set is green, and the declined-
approval invariant is proven end-to-end against a real declined run.

**Tasks**:

- [ ] Record `git rev-parse HEAD:specs/state.json` (the pre-run blob hash) for the byte-identity
      check below.
- [ ] Run `timeout 540 bash /home/benjamin/.config/nvim/.claude/scripts/deploy-headless.sh` and
      require `RESULT=landed_verify_clean`.
- [ ] Run the complete gate set: `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh`
      (standalone, if the deploy path skipped it for any reason).
- [ ] Run the full shell suite: `bash /home/benjamin/.config/nvim/.claude/scripts/tests/run-all.sh`.
- [ ] From the DEPLOYED copy, exercise the gated path in both directions: a declined
      (`--record-approval --channel edges --answer no`) outcome must leave the `edges` gate
      refusing and `specs/state.json`'s blob hash unchanged from the recorded pre-run value; an
      approved outcome must reach the `--write-edges` re-probe and render both members flipping
      to `admit`.
- [ ] Attribute every red finding from the gate run: either it names a file this task touched (a
      real defect, fixed forward) or it is demonstrably pre-existing, recorded via
      `issue-record.sh`, and listed in a `#### Reasoned Exclusions` table — never silently
      accepted.
- [ ] Confirm `specs/state.json`'s `next_project_number` is unchanged by any part of this work.
- [ ] Record the measured net line count across all touched files and the gate outcome in the
      implementation summary.

**Timing**: 1 hour

**Depends on**: 1, 2, 3, 4, 5

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed `.claude/` tree from the source store; this phase claims whole-tree regeneration and declares the reserved sentinel so a concurrently-admitted task that would also regenerate the tree is serialized against it
- `specs/602_conclusion_stage_next_batch_proposal_quality/summaries/` - the implementation summary carrying the measured net line count and the gate outcome

**Verification**:
- `bash /home/benjamin/.config/nvim/.claude/scripts/deploy-headless.sh` emits
  `[deploy-headless] RESULT=landed_verify_clean` and exits 0.
- The complete gate set is green: `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh`
  exits 0 (or every red gate is attributed as above).
- `bash /home/benjamin/.config/nvim/.claude/scripts/tests/run-all.sh` passes, including
  `test-orchestrate-suggest-next-batch.sh` cases (h), (i), (j) and
  `test-orchestrate-conclusion-aggregate.sh`'s `edges` isolation assertions, all from the
  deployed copy.
- `specs/state.json`'s blob hash is byte-identical across the declined-approval run, and
  `next_project_number` is unchanged.
- `git diff --numstat` across all touched files yields a reported net line count.

---

## Testing & Validation

- [ ] Case (h): an all-collision-pairs pool renders every ordered-sequence line AND at least one
      probe-verified joint batch line in the same output (Defect 1).
- [ ] Case (i): two or more distinct labelled batch options render, each naming its coherence
      criterion and carrying its own `admit` evidence, with no two options sharing an identical
      task list (Defect 2).
- [ ] Case (j): the shared probe cap, driven to exhaustion mid-multi-option-render, produces the
      explicit cap-reached line and retains the options already rendered (Defect 2's budget
      constraint).
- [ ] `edges` approval-key isolation: `yes` for `edges` leaves `a`/`b`/`c` not-approved and `yes`
      for `a` leaves `edges` not-approved; absent, `no`, and malformed all read not-approved
      (Defect 3).
- [ ] The declined-approval invariant: `specs/state.json` is byte-identical across a run whose
      `edges` approval was declined (Defect 3).
- [ ] Defect 4's ruling is recorded in `conclusion-stage.md` Step 5 with its current grounds, and
      `roadmap-integration.sh` is byte-identical to its pre-task state.
- [ ] Case (f)'s no-forked-predicate regression still passes: the changed script contains no
      directory-prefix overlap comparison, no overlap-helper sourcing, and no locally derived
      overlap field.
- [ ] `shellcheck` is clean on all touched shell files per
      `context/standards/shell-strict-mode.md`.
- [ ] No file landed under `agent-system/**` by this task contains a task-number reference or
      record-versioning language.
- [ ] `bash /home/benjamin/.config/nvim/.claude/scripts/tests/run-all.sh` passes in full from the
      deployed tree.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh` — additive joint
  batch, up to three labelled probe-verified options, reported-pairs dedup, cap-reached wiring.
- `agent-system/extensions/core/scripts/orchestrate-conclusion-aggregate.sh` — the `edges`
  approval key in the closed vocabulary of both approval modes.
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` — Step 7's gated
  edge-write body; Step 5's corrected prune rationale.
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` — Move 5
  allowed-tool rows covering the Step 7 gate and the two already-invoked scripts.
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` — the
  rewritten `**Suggested next batch**:` render contract.
- `agent-system/extensions/core/context/patterns/roadmap-update.md` — the
  `--prune`/`--regenerate` equivalence note.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-suggest-next-batch.sh` — cases
  (h), (i), (j).
- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-aggregate.sh` — the
  `edges` cross-key isolation assertions.
- The regenerated deployed `.claude/` tree (a deploy artifact, never hand-authored).
- `specs/602_conclusion_stage_next_batch_proposal_quality/summaries/01_*-summary.md`.

## Rollback/Contingency

Every phase is committed per green sub-step, so the smallest rollback is a revert of the
offending commit. The changes are additive and behind existing seams: Phase 3's vocabulary
extension is backward-compatible (the three existing keys behave identically), and Phase 4's gate
defaults to refusing, so an incomplete Phase 4 leaves the stage behaving as it does today —
proposing edges without writing them — rather than writing unapproved edges.

Should a genuine rollback of uncommitted work be needed, follow
`context/contracts/recovery.md`'s rollback rung for the exact `git-snapshot.sh` invocation shape
(including its out-of-scope override flag for the deliberate whole-tree case) before any
destructive git command; do not emit a bare reverting snapshot as a routine precaution. For an
ordinary defensive checkpoint before Phase 1's or Phase 2's edits, use
`bash .claude/scripts/git-snapshot.sh 602 --no-revert`, which is durable without reverting the
working tree.

If Phase 6's deploy cannot reach `landed_verify_clean` for a reason attributable to this task, fix
forward in the source store and redeploy — never discard uncommitted changes to reach a passing
gate.
