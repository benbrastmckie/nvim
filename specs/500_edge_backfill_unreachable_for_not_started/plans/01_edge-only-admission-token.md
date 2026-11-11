# Implementation Plan: Task #500

- **Task**: 500 - edge_backfill_unreachable_for_not_started
- **Status**: [IMPLEMENTING]
- **Effort**: 4 hours
- **Dependencies**: 328, 430, 446, 448 (all four have completed and archived -- see Prior Plan Reference; 500 is unblocked today)
- **Research Inputs**: specs/500_edge_backfill_unreachable_for_not_started/reports/01_depends-on-add-not-started-gap.md
- **Artifacts**: plans/01_edge-only-admission-token.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`update-task-status.sh --depends-on-add` is structurally unreachable for a `not_started` task
because its status-no-op restriction requires an `operation:target_status` pair that resolves to
the task's own current status, and `map_status()`'s twelve arms never emit `not_started`. This
plan closes the gap by the dispatch's shape **(a)**: one new no-op-only `operation:target_status`
pair, `preflight:edge_only`, resolving `STATE_STATUS="not_started"`, refused outright unless
`--depends-on-add` accompanies it. Every existing guarantee (no transition with an edge add,
mandatory write-time cycle refusal via `validate-state.sh --deep`, value/self-edge/
missing-predecessor refusals, union-merge idempotence, caller-owned drain confirmation) is
preserved untouched because the new arm feeds the identical downstream code path. The one
consumer that already works around this gap, `orchestrate-suggest-next-batch.sh`'s
`resolve_noop_token()`, gains the matching one-line case so its "add the edge by hand" fallback
stops firing for `not_started`.

### Research Integration

The research report's findings were re-verified against the live source store during this
planning dispatch and are carried forward in full:

- `map_status()`'s twelve arms and the absence of any `not_started`-resolving pair -- confirmed
  by direct read (`scripts/update-task-status.sh` lines 461-503).
- The reproduction error string at line 647 -- confirmed verbatim.
- The write-time cycle refusal block (lines 651-689) reusing `validate-state.sh --deep` against a
  scratch copy, with its fail-closed guard -- confirmed, and confirmed to fire *before* and
  independently of the status-no-op check, so it is reached identically on the new path.
- `orchestrate-suggest-next-batch.sh`'s `resolve_noop_token()` (lines 493-509, no `not_started`
  case) and `propose_edge_for_pair()`'s named propose-only fallback (lines 511-566) -- confirmed,
  including the header comment that calls this "the genuine `not_started` gap".
- The research's recommendation of shape (a) over (b) and (c) is adopted, with its reasoning:
  shape (b) would require special-casing every `target_status`-gated block in the same file
  (confirmed live at lines 354, 370, 382, 393, 557-561, 578, 590, 773, 846, 1243, 1326) and
  would restructure `resolve_noop_token()` for all ten currently-handled statuses rather than
  adding one; shape (c) splits one primitive across two entry points.

Two research claims are **corrected** here (see Decisions):

1. The research proposed the literal token `backfill` on the basis that `grep` for it "returned
   no hits". That is false as stated: `backfill` already carries two unrelated senses in this
   same source store (`scripts/backfill-file-scope.sh`, and `dispatch-metrics.sh --backfill`).
   This plan selects `edge_only` instead, which has no existing sense as a CLI token.
2. The research's description of `resolve_noop_token()` is accurate, but note it also has no
   `completed`/`needs_research` arm -- the `not_started` omission is the only one that matters
   here, and the fix adds exactly one case.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context, so no roadmap consultation
was performed and no roadmap phases are included.

### Premise Re-Validation (dispatch Carried-Figure Discipline)

Every extracted line was checked against the live tree during this dispatch. Results, stated
explicitly even where unchanged:

| Carried claim | Verdict |
|---|---|
| `--depends-on-add` cannot fire on a `not_started` task | **Confirmed unchanged.** No `map_status()` arm emits `not_started`; the gate at line 646 is unconditional. |
| Source store is the edit target (`agent-system/extensions/core/**`) | **Confirmed.** `jq -r '.extensions.core.source_dir' .claude-extensions.json` -> `/home/benjamin/.config/nvim/agent-system/extensions/core`. |
| The status-no-op restriction is stated in the script's own header | **Confirmed unchanged** at lines 147-157. |
| `update-task-status.sh` is the only sanctioned edge-add path | **Confirmed.** No `manage-dependencies.sh` or equivalent exists; the only other file carrying an executable `--depends-on-add` invocation is `orchestrate-suggest-next-batch.sh`, which shells out to this same script. |
| Value validation = JSON array of NUMBERS, hard error | **Confirmed unchanged** at lines 403-407. |
| Write-time cycle refusal fires, and fails closed when `validate-state.sh` cannot run | **Confirmed unchanged** at lines 651-689 (fail-closed guard at 662-664). |
| Malformed / self-edge / missing-predecessor all exit 1; repeated call idempotent | **Confirmed unchanged** (403-407, 408-413, 446-458; `unique` at the no-op write site line ~1112 and the real-write site line ~1171). |
| Twelve `map_status()` arms | **Confirmed: exactly 12.** Note the separate dynamic `preflight:unhold` resolution path (lines 511-527) is *not* a thirteenth arm and cannot supply a `not_started` no-op either -- its resolved value is a held task's recorded `prior_status`, and a held task's current status is `hold`, never `not_started`, so the no-op check still refuses. |
| Task 328 is "currently `implementing`, a live writer" | **CHANGED.** 328 has completed and archived, as have 430, 446, and 448. The dispatch's live-writer concern for `test-update-task-status.sh` no longer applies to 328. |
| Two live edges blocked by the gap | **PARTIALLY CHANGED.** 438 (`not_started`) -> 500 remains live and realizable. The 421 edge's intended predecessor, 497 (`promote_telemetry_submodes_to_core`), has completed and archived out of `active_projects`, so that edge is moot and literally unaddable -- see Phase 5 step 4. |
| 421 and 438 are still `not_started` | **Confirmed** (`421 not_started deps=[312,402]`, `438 not_started deps=[312,313,401,446,458]`). |

## Goals & Non-Goals

**Goals**:
- Make `--depends-on-add` reachable for a `not_started` task via one new no-op-only
  `operation:target_status` pair, `preflight:edge_only`.
- Refuse `preflight:edge_only` outright on any call that is not an edge-only call (no
  `--depends-on-add`), so the new token can never read or act as a settable lifecycle target.
- Preserve every one of the dispatch's six named guarantees unchanged, and cover each of them on
  the new `not_started` path in the test suite.
- Remove the now-dead `not_started` workaround in `orchestrate-suggest-next-batch.sh` by adding
  the matching `resolve_noop_token()` case, and correct the header comment that calls the gap
  genuine.
- Prove the fix end-to-end on the one real edge that remains realizable (438 -> 500), and record
  the 421 -> 497 edge as moot with evidence.

**Non-Goals**:
- The per-edge semantic/serialization rationale discriminator (task 438's own work).
- Any change to `dependencies[]`'s flat integer-array schema.
- An auto-invoked drain check (`orchestrate-cycle-plan.sh --dry-run` stays the caller's job).
- Any change to the status vocabulary in `state-management.md`'s transition model --
  `not_started` is already a member of the closed 13-value enum in `lib/status-vocabulary.sh`
  (rank 0, TODO marker `NOT STARTED`), so no schema or library change is required.
- Restructuring `resolve_noop_token()`'s per-status token construction, or minting a *universal*
  edge-only token that resolves dynamically to any current status (considered and rejected -- see
  Decisions).

## Decisions

**D1. Shape (a), not (b) or (c).** Adopted on the two axes the dispatch named.
*Call sites*: shape (a) is additive in four files with small diffs. Shape (b) (a standalone
operation with no `operation`/`target_status` positionals) must additionally special-case or
bypass eleven live `target_status`-gated blocks in the same script (lines 354, 370, 382, 393,
557-561, 578, 590, 773, 846, 1243, 1326) and rewrite `resolve_noop_token()`/
`propose_edge_for_pair()` for every status, not just one.
*One-sentence describability*: shape (b) reads marginally cleaner, but the dispatch asks the axes
be weighed together, and the call-site asymmetry dominates. Shape (b) is also, by the dispatch's
own framing, the "second vehicle" the script's header declined to invent; the call-site evidence
gives no forcing reason to overturn that stated decision.
Shape (c) is rejected for the reason the dispatch states: it splits one primitive across two
entry points, the duplicate-mechanism outcome this codebase's consolidation bias argues against.

**D2. Token literal: `edge_only`, paired as `preflight:edge_only`.**
- `edge_only` names the call's only legal purpose and is not a phase name, satisfying the
  dispatch's "unmistakably no-op-only" requirement at the call site itself.
- It is unused as a CLI token anywhere in the source store (the only textual occurrence of the
  string in the whole tree is an unrelated test-fixture session name, `sess_edge_only`, in
  `scripts/test-conflict-predicate.sh`).
- `backfill` (the research's suggestion) is rejected: the word already means two other things
  here (`backfill-file-scope.sh`; `dispatch-metrics.sh --backfill`), so it would read
  ambiguously at the call site.
- `not_started` as the literal is rejected: every other `target_status` literal names something
  a caller can genuinely request, so a literal naming the status itself invites exactly the
  misreading shape (a) is warned about.
- `preflight`, not `postflight`, follows the established precedent in this same file: `hold`/
  `unhold` are preflight-only because they are human-initiated rather than derived from a
  dispatch outcome. An edge backfill is likewise operator/tooling-initiated.

**D3. Rejected alternative: a universal, dynamically-resolving edge-only token.** A variant was
considered in which `edge_only` resolves `STATE_STATUS` to whatever the task's *current* status
is (the pattern `preflight:unhold` already establishes in this file), making it a single
status-agnostic edge vehicle. Rejected: it would mint a second way to express the status no-op
for all ten already-reachable statuses, which is the duplicate-mechanism outcome D1 rejects
shape (c) for, while the gap being closed exists at exactly one status. A fixed-`not_started`
arm closes the gap and adds no alternative to the existing per-status vehicle.

**D4. The existing refusal message is preserved byte-for-byte for every previously-reachable
status.** The status-no-op refusal (line 647) gains one *additional* sentence naming
`preflight <n> edge_only` as the correct call, emitted **only** when the task's current status is
`not_started`. Acceptance criterion 2's "with its existing error text" therefore holds exactly:
no previously-reachable status sees any change to that message.

**D5. Acceptance criterion 5 is executed as one edge plus one recorded mootness finding**, not
two edges -- see Phase 5 step 4 and the Premise Re-Validation table.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The new token is later invoked without `--depends-on-add` and read as a "reset to not_started" lifecycle action | H | M | Hard refusal guard (Phase 2 step 4), mirroring the existing `preflight:hold` requires `--hold-reason` precedent; negative test case in Phase 2 step 7 |
| The appended hint sentence breaks a test or caller matching the existing refusal text | M | L | D4 scopes the addition to `current_state_status == "not_started"` only; Phase 2 step 8 re-runs Case 17g unchanged to confirm |
| A concurrent sibling (589, 569) edits a core script or regenerates the whole tree mid-phase | M | M | Territory contract: re-read each file immediately before editing; stage only this task's own hunks by explicit file list; 589 claims `__WHOLE_TREE__`, so if a foreign redeploy or foreign commit is observed, STOP and report rather than proceeding (Phase 5 step 1) |
| `test-orchestrate-suggest-next-batch.sh` resolves its subjects **deploy-tree-first**, so a source-store-only edit is invisible to it pre-redeploy | M | H | Confirmed live: `common_test_resolve_subject` honors `CORE_TEST_SUBJECT_MODE`. Phase 3 runs that suite with `CORE_TEST_SUBJECT_MODE=source-store`; Phase 5 re-runs it from the deployed tree after redeploy |
| Attempting the moot 421 -> 497 edge wastes a cycle on a call that cannot succeed | L | M | D5 and Phase 5 step 4 pre-empt it: record the mootness with evidence, do not issue the call |
| A vault operation renumbers tasks between this plan and implementation | M | L | Phase 1 re-derives every task number from `specs/state.json` before any edge is issued |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Re-verify the premise and fix the token literal [COMPLETED]

**Goal**: Discharge the dispatch's acceptance item 7 against the tree as it then stands, before
any edit, and confirm the chosen literal is still collision-free.

**Tasks**:
- [x] Resolve the source store: `jq -r '.extensions.core.source_dir' .claude-extensions.json`. *(completed: /home/benjamin/.config/nvim/agent-system/extensions/core)*
- [x] Count `map_status()`'s case arms directly and confirm no arm resolves to `not_started`. *(completed: exactly 12 arms, none resolves to not_started)*
- [x] Confirm the status-no-op refusal message and the write-time-cycle-refusal fail-closed
      message are still verbatim as quoted in this plan's Premise Re-Validation table. *(completed: both byte-identical)*
- [x] Confirm the `target_status` validation list and the two usage lines still enumerate exactly
      `research | plan | implement | pr_ready | needs_research | partial | blocked | hold | unhold`. *(completed: 9-value list unchanged)*
- [x] Confirm `edge_only` is still unused as a CLI token (`grep -rn 'edge_only' agent-system/`);
      if a collision has appeared, pick the next candidate (`depends_only`) and record the
      substitution in the progress file rather than proceeding with a colliding literal. *(completed: no collision; only hit is unrelated fixture name sess_edge_only)*
- [x] Re-read `specs/state.json` for the live status and `dependencies[]` of 421, 438, and 500,
      and re-confirm 497's archived/completed disposition in `specs/archive/state.json`. *(completed: 421/438 not_started, 500 implementing, 497 completed+archived)*
- [x] Write the findings to `specs/500_edge_backfill_unreachable_for_not_started/progress/phase-1-premise.json`
      (one object: `arm_count`, `error_strings_verbatim`, `token_literal`, `task_statuses`,
      `deviations`), so Phase 5's report cites measured values rather than this plan's. *(completed)*

**Timing**: 0.3 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: this plan asserts 12 `map_status()` arms, 11 `target_status`-gated blocks,
and a 9-value `target_status` validation list. All three are hypotheses measured during planning;
this phase re-measures each and records the actual values in the progress file, which Phase 5's
report then cites.

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for the only path this
phase writes (a `specs/**` progress JSON), and per plan-format.md's sub-case (a) a `specs/**`
non-artifact file's honest check is the `prose` row's diff read-through, which this phase's
read-only measurements plus a `jq .` parse of the written file discharge.

**Files to modify**:
- `specs/500_edge_backfill_unreachable_for_not_started/progress/phase-1-premise.json` - created by this phase; if the `progress/` directory does not exist, create it

**Verification**:
- `jq . specs/500_edge_backfill_unreachable_for_not_started/progress/phase-1-premise.json`
  parses and every field is populated with a measured value (no placeholders).
- `deviations` is an explicit array -- empty if the premise held, otherwise naming each changed
  figure.

---

### Phase 2: Add the `preflight:edge_only` arm and its full test coverage [NOT STARTED]

**Goal**: Make `--depends-on-add` reachable for a `not_started` task through one new no-op-only
pair that is refused on any non-edge-only call, and cover every dispatch-named guarantee on the
new path.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/scripts/update-task-status.sh` immediately before
      editing (concurrent siblings are live on this tree).
- [ ] Add the arm to `map_status()`:
      `preflight:edge_only) STATE_STATUS="not_started"; TODO_STATUS="NOT STARTED" ;;` with a
      comment stating it is no-op-only, exists solely as the `--depends-on-add` vehicle for a
      pre-lifecycle task, and is refused without that flag.
- [ ] Add `edge_only` to the `target_status` validation list and to both usage lines (the header
      usage comment and the runtime `Usage:` echo), annotated `edge_only is preflight-only and
      requires --depends-on-add`.
- [ ] Add `edge_only` to the existing preflight-only guard alongside `hold`/`unhold`, so
      `postflight edge_only` is a hard validation error.
- [ ] Add the edge-only refusal guard, placed with the other flag-restriction guards and
      mirroring the `preflight:hold` requires `--hold-reason` precedent: when
      `operation:target_status == preflight:edge_only` and `DEPENDS_ON_ADD_LEN == 0`, exit 1 with
      a named error distinct from the pre-existing no-op-restriction message.
- [ ] Append the `not_started`-only hint sentence to the status-no-op refusal per D4 (guarded on
      `current_state_status == "not_started"`, leaving the message byte-identical for every other
      status).
- [ ] Extend the `--depends-on-add` header-comment section to document the new pair, its
      no-op-only character, and the refusal; state that it changes none of the six guarantees
      already documented there.
- [ ] Add a fourth, `not_started` entry to `build_multi_task_fixture_repo()` in
      `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` (giving a
      `not_started` dependent plus existing predecessors to point at).
- [ ] Add a Case 18 cluster to that suite: (a) `preflight <n> edge_only <sid>
      --depends-on-add=[...]` against the `not_started` entry succeeds, merges the edge, and
      leaves status `not_started`; (b) the same call without `--depends-on-add` is refused with
      the new named error and writes nothing; (c) `postflight <n> edge_only` is refused by the
      preflight-only guard; (d) a cycle-closing edge onto the `not_started` entry is refused by
      the write-time cycle check, on the real path and under `--dry-run`, with state unchanged;
      (e) malformed value, self-edge, and missing-predecessor each exit nonzero with state
      unchanged on this new path; (f) a repeated identical call is a byte-for-byte no-op;
      (g) `edge_only` against a NON-`not_started` task is refused by the pre-existing no-op check.
- [ ] Re-run the pre-existing Case 17 block unchanged to confirm no regression in the
      previously-reachable paths (notably 17g, the status-transition refusal).

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase assumes the fail-closed cycle-refusal block, the value/self-edge/
missing-predecessor guards, and the union-merge write sites all sit *upstream or downstream* of
the status-no-op gate and therefore need no change. Confirm at implementation time by reading the
block order around the gate before editing; if any guard turns out to be gated on a specific
`target_status`, add it to this phase's task list rather than silently bypassing it.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-backfill-file-scope.sh,test-force-phases.sh,test-gate-out-derived-staleness.sh,test-gate-out-repair-reporting.sh,test-gate-out-self-attribution.sh,test-handoff-dispatch-identity.sh,test-lint-agent-contracts.sh,test-lint-lifecycle-status-var.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-recover-message-findings.sh,test-orchestrate-suggest-next-batch.sh,test-orchestrate-unwind-dispatch.sh,test-postflight-deploy-gate.sh,test-reconcile-handoff-status.sh,test-redeploy-checkpoint-promotion.sh,test-resume-scan-nonconformance.sh,test-skill-base-lifecycle.sh,test-update-task-status.sh` is the covering check -- that list is `suite_selection_select`'s verbatim output for `scripts/update-task-status.sh`, and the test file's own 5-suite output is a subset of it.

**Files to modify**:
- `agent-system/extensions/core/scripts/update-task-status.sh` - new `preflight:edge_only` arm, `target_status` validation + both usage lines, preflight-only guard entry, the edge-only refusal guard, the `not_started`-only hint sentence, header-comment documentation
- `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` - fourth `not_started` fixture entry; new Case 18 cluster (a)-(g)

**Verification**:
- `bash -n` clean on both files, and
  `bash .claude/scripts/lint/lint-shellcheck.sh agent-system/extensions/core/scripts/update-task-status.sh agent-system/extensions/core/scripts/tests/test-update-task-status.sh`
  exits 0 (the repository's sanctioned shellcheck entry point; check its exit status, not a
  stdout diff).
- `bash agent-system/extensions/core/scripts/tests/test-update-task-status.sh` passes with zero
  failures, including the whole pre-existing Case 17 block (the suite already overrides
  `update-task-status.sh` from the source store, so this exercises the pre-deploy edit directly).
- The `run-all.sh --only` suite list named in Tier Justification passes.
- `git diff` on the status-no-op refusal shows the existing sentence unchanged and the new
  sentence reachable only under `current_state_status == "not_started"`.

---

### Phase 3: Teach the suggester the new token [NOT STARTED]

**Goal**: Retire the `not_started` propose-only workaround in
`orchestrate-suggest-next-batch.sh` so a colliding `not_started` pair gets its edge written
automatically, and correct the header comment that now misdescribes the system.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh`
      immediately before editing.
- [ ] Add `not_started) echo "preflight edge_only" ;;` to `resolve_noop_token()`, with a comment
      naming the no-op-only, edge-only character of that pair.
- [ ] Update `resolve_noop_token()`'s own header comment, which currently states that
      `not_started` is "the real, closed-vocabulary case for" having no resolving token, and
      `propose_edge_for_pair()`'s header comment, which calls it "the genuine `not_started` gap":
      both now misdescribe the system. Keep the fallback branch itself (it still guards the
      terminal statuses and any future unmapped status) and say so in the revised comment.
- [ ] Add a case to `agent-system/extensions/core/scripts/tests/test-orchestrate-suggest-next-batch.sh`
      mirroring the existing case (b) shape, but with both colliding fixture tasks at
      `not_started`: assert the edge is written under `--write-edges`, that both members re-probe
      to `admit`, that `dependencies[]` carries the edge in the scratch `state.json`, and that
      neither task's status moved off `not_started`.

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-suggest-next-batch.sh` is the covering check -- `suite_selection_select` returns exactly that single suite for both paths this phase touches.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh` - new `not_started` case in `resolve_noop_token()`; corrected header comments on `resolve_noop_token()` and `propose_edge_for_pair()`
- `agent-system/extensions/core/scripts/tests/test-orchestrate-suggest-next-batch.sh` - new `not_started` colliding-pair case under `--write-edges`

**Verification**:
- `bash -n` clean on both files, and
  `bash .claude/scripts/lint/lint-shellcheck.sh agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh agent-system/extensions/core/scripts/tests/test-orchestrate-suggest-next-batch.sh`
  exits 0.
- `CORE_TEST_SUBJECT_MODE=source-store bash agent-system/extensions/core/scripts/tests/test-orchestrate-suggest-next-batch.sh`
  passes with zero failures. The env override is required because this suite resolves its
  subjects deploy-tree-first and the fix is not yet deployed.
- `grep -n 'genuine' agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh`
  returns no surviving claim that the `not_started` gap is still real.

---

### Phase 4: Record the token in the one context doc that prescribes the primitive [NOT STARTED]

**Goal**: Make the new token discoverable from the doc that already names `--depends-on-add` as
the default move for backfilling a serializing edge, so a future reader does not have to derive
it from a script comment.

**Tasks**:
- [ ] Re-read the `--depends-on-add` passage in
      `agent-system/extensions/core/context/patterns/multi-task-operations.md` (confirmed present
      at the "The default move here is to add the serializing edge" paragraph and the
      "Direction cannot be inferred from task numbering" paragraph that follows it).
- [ ] Add one or two sentences naming `preflight <n> edge_only <session_id>
      --depends-on-add=[...]` as the call shape for a task still at `not_started`, and stating
      that it is no-op-only and refused without `--depends-on-add`. Do not restate the six
      guarantees -- cite the flag's own header as their home.
- [ ] Leave `index-entries.json` untouched unless the addition changes the file's topical summary
      (a one-sentence call-shape addition does not).

**Timing**: 0.25 hours

**Depends on**: 2

**Verification Tier**: prose

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for this path -- no suite covers it -- so per plan-format.md's sub-case (b) the honest check is `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim` (the repository root holding both the deployed tree and the source store), run together with the `prose` row's diff read-through.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/multi-task-operations.md` - one-to-two-sentence addition naming the `edge_only` call shape; the file exists and the target passage was confirmed present during planning. If the passage has been restructured by the time this phase runs, attach the sentences to whichever passage then prescribes `--depends-on-add`, and record the relocation in the phase's completion note.

**Verification**:
- Diff read-through confirms every changed hunk is prose, with no task-number reference (the file
  is outside `specs/**`) and no record-versioning language.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  reports no new finding against the pre-edit baseline.

---

### Phase 5: Redeploy, run the full gate set, and prove the fix end-to-end [NOT STARTED]

**Goal**: Land the change in the deployed tree, clear the complete gate set, and discharge the
dispatch's acceptance list on live state.

**Tasks**:
- [ ] Territory check first: `git log --oneline -5` and `git status --short` to confirm no foreign
      commit or foreign uncommitted modification has appeared in the core scripts tree. Sibling
      task 589 declares `__WHOLE_TREE__` this same cycle, so if a redeploy is already running
      that this dispatch did not start, STOP and report rather than starting a second one.
- [ ] Redeploy via the bounded-wait idiom: `timeout 540 bash .claude/scripts/deploy-headless.sh`
      with the Bash tool timeout raised to 600000. Never hand-patch a deployed file.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (no `--skip-slow`),
      `bash .claude/scripts/tests/run-all.sh` in full, and `bash .claude/scripts/validate-state.sh`
      over the live `specs/state.json`. Re-run both suites touched by Phases 2 and 3 from the
      deployed tree (no `CORE_TEST_SUBJECT_MODE` override) to confirm the deployed copy carries
      the fix.
- [ ] Acceptance item 5, the realizable half: issue
      `bash .claude/scripts/update-task-status.sh preflight 438 edge_only <session_id> --depends-on-add=[500]`,
      first with `--dry-run` to preview the union-merge, then for real. Confirm 438's status is
      still `not_started` afterward and report its resulting `dependencies[]` array verbatim.
      Re-derive both task numbers from `specs/state.json` first (Phase 1's progress file records
      them) rather than trusting this plan's literals.
- [ ] Acceptance item 5, the moot half: do NOT issue the 421 edge. Record in the summary that the
      intended predecessor (497, `promote_telemetry_submodes_to_core`) has completed and archived
      out of `active_projects`; that `--depends-on-add`'s missing-predecessor refusal is scoped to
      `active_projects` and would refuse the call regardless of this fix; and that the
      RELOCATE-FIRST ordering the edge existed to enforce is already satisfied in fact. Report
      421's unchanged `dependencies[]` as evidence nothing was written.
- [ ] Confirm `validate-state.sh` passes over the post-edge `specs/state.json` with zero
      failures, and that `specs/TODO.md` regenerated consistently (the write path passes
      `--regen-todo`).
- [ ] Walk the dispatch's acceptance list 1-7 explicitly in the summary, each with the command
      run and its observed result, citing Phase 1's measured figures rather than this plan's.

**Timing**: 1.25 hours

**Depends on**: 3, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts that adding `500` to 438's `dependencies[]` closes no
cycle (438's predecessors do not reach 500) and that 500 is present in `active_projects`. Both
are confirmed by the `--dry-run` preview and the mandatory write-time cycle check *before* any
write; if either refuses, stop and report rather than editing `state.json` by hand.

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes `deploy-headless.sh`, regenerating the entire deployed tree; declared per plan-format.md's whole-tree-claim rule
- `specs/state.json` - task 438 gains the `500` dependency edge, written only via `update-task-status.sh` (never by hand)
- `specs/TODO.md` - regenerated as a side effect of the state write's `--regen-todo`

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0 with no findings.
- `bash .claude/scripts/tests/run-all.sh` passes in full, zero failures.
- `bash .claude/scripts/validate-state.sh` passes over the post-edge `specs/state.json` with zero
  failures (acceptance item 6).
- 438's `dependencies[]` contains `500` and 438's status reads `not_started`
  (acceptance item 1 and 5).
- `jq` confirms 421's `dependencies[]` is unchanged, evidencing the moot edge was not attempted.
- Every acceptance item 1-7 is addressed in the summary with its command and observed result.

## Testing & Validation

- [ ] `preflight <n> edge_only <sid> --depends-on-add=[...]` succeeds on a `not_started` fixture
      task, merges the edge, and leaves status `not_started` (acceptance 1).
- [ ] `preflight <n> edge_only` without `--depends-on-add` is refused with a named error, writing
      nothing.
- [ ] `postflight <n> edge_only` is refused by the preflight-only guard.
- [ ] `edge_only` against a non-`not_started` task is refused by the pre-existing no-op check,
      whose message is byte-identical to its pre-change form (acceptance 2).
- [ ] `--depends-on-add` combined with a real status transition is still refused with its existing
      error text (pre-existing Case 17g, unchanged) (acceptance 2).
- [ ] The write-time cycle refusal fires on a cycle-closing candidate edge against a
      `not_started` target, on the real path and under `--dry-run`, and still fails closed when
      `validate-state.sh` is absent or non-executable (acceptance 3).
- [ ] Malformed value, self-edge, and missing-predecessor refusals each exit 1 with their existing
      messages on the new path; a repeated identical call is a byte-for-byte no-op (acceptance 4).
- [ ] A `not_started` colliding pair in `orchestrate-suggest-next-batch.sh --write-edges` writes
      the edge and re-probes both members to `admit`.
- [ ] No auto-invoked drain check was added (`grep` for `orchestrate-cycle-plan.sh` inside
      `update-task-status.sh` still returns nothing).
- [ ] `dependencies[]` is still a flat array of integers; `status-vocabulary.sh` and
      `state-schema.json` are unmodified.
- [ ] Full gate set green after redeploy (acceptance 6).

## Artifacts & Outputs

- `specs/500_edge_backfill_unreachable_for_not_started/progress/phase-1-premise.json`
- Modified: `agent-system/extensions/core/scripts/update-task-status.sh`
- Modified: `agent-system/extensions/core/scripts/tests/test-update-task-status.sh`
- Modified: `agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh`
- Modified: `agent-system/extensions/core/scripts/tests/test-orchestrate-suggest-next-batch.sh`
- Modified: `agent-system/extensions/core/context/patterns/multi-task-operations.md`
- Modified: `specs/state.json` (438 gains the 500 edge), `specs/TODO.md` (regenerated)
- Regenerated: the deployed `.claude/` tree
- An execution summary walking acceptance items 1-7 with observed results, including 438's
  resulting `dependencies[]` and the recorded mootness of the 421 edge

## Rollback/Contingency

Every change is additive and confined to five source-store files plus one machine-written
`dependencies[]` entry.

- **Script or test regression**: revert the specific hunks in the affected source-store file and
  redeploy. The new arm is reachable only through the new `edge_only` literal, so reverting the
  `map_status()` arm and the validation-list entry restores the pre-change behaviour exactly; no
  existing call shape changes meaning at any point.
- **An unexpected refusal during the end-to-end edge add**: no write occurs (the cycle check and
  every guard refuse before the write), so there is nothing to roll back. Report the refusal
  rather than editing `state.json` by hand -- a hand edit bypasses the write-time cycle refusal
  and is not an acceptable workaround.
- **An unwanted edge was written**: `--depends-on-add` is additive-only and has no removal
  counterpart, so removal is a separate, deliberate `state-write.sh` operation; record it as a
  finding rather than improvising.
- **Before any risky step**, take a non-reverting checkpoint:
  `bash .claude/scripts/git-snapshot.sh 500 --no-revert`. Never the default reverting form while
  sibling tasks are live on this working tree.
