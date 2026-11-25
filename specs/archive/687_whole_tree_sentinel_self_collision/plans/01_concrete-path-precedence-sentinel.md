# Implementation Plan: Task #687

- **Task**: 687 - Whole-tree sentinel self-collision
- **Status**: [COMPLETED]
- **Effort**: 1.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/687_whole_tree_sentinel_self_collision/reports/01_sentinel-self-collision-fix.md
- **Artifacts**: plans/01_concrete-path-precedence-sentinel.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The dispatch's named deliverable is already satisfied in live code, and the premise re-validation
below records that measurement in full. What remains genuinely open is the dispatch's own
REGRESSION clause: a pair of tasks that each declare the reserved `__WHOLE_TREE__` sentinel AND
also genuinely collide on a concrete path is reported as a bare whole-tree claim whenever the
sentinel happens to precede the shared concrete path in the declared `file_scope` array. The
real-path collision -- the stronger finding -- is masked, and the operator's
`--allow-scope-collision` override silently stops applying to it. This plan closes exactly that
masking by giving a concrete-path overlap precedence over the reserved sentinel when both exist
between the same pair, pins the fix with the regression fixture the research report found absent,
and changes no decision, no deferral direction, and no other comparison shape.

### Premise Re-Validation (Carried-Figure Discipline)

Every trigger-class claim in the dispatch `## Description` was checked against live state. Two
central ones are **false**, and one is **confirmed**:

1. **FALSE -- "The fixture is therefore RED today."** Measured: `timeout 300 bash
   agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh` reports
   `Results: 15 passed, 0 failed`, with `[PASS] WHOLE-TREE-CODISPATCH` among them. The fixture is
   GREEN with its assertions unmodified.
2. **FALSE -- "`scopes_overlap_first()` ... does not special-case the sentinel against itself, so
   ... `orchestrate-batch-admit.sh` emits `decision=defer` carrying `defer_reason`
   `file_scope_collision` with `overlapping_path` `__WHOLE_TREE__`."** Measured: the
   sentinel-relabeling branch exists at `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh`
   lines 1070-1105 and already emits `defer_reason: "whole_tree_claim"` together with
   `claim_sentinel`, `colliding_task_number`, `colliding_task_status` and `collision_scope`. A
   direct probe of the fixture's own shape (two in-batch candidates, disjoint real scope, both
   declaring the sentinel) returns exactly the asserted verdict. The dispatch's stated
   DELIVERABLE ("make the sentinel-versus-sentinel in-batch verdict emit defer_reason
   whole_tree_claim with the claim_sentinel, colliding_task_number and collision_scope fields
   ... so that fixture goes green") is therefore **already met before this plan runs**. Nothing
   in this plan re-does it.
3. **CONFIRMED, and measurably UNMET -- the REGRESSION clause** ("two sentinel-declaring tasks
   whose CONCRETE paths also genuinely intersect must still be held in conflict, and must still
   report the concrete overlapping path rather than being relabelled as a bare whole-tree
   claim"). Probed directly against a byte-for-byte copy of the live script in an isolated temp
   root, two in-batch candidates each declaring `__WHOLE_TREE__` plus the SAME concrete path
   `scope/shared`:
   - concrete path declared FIRST in both arrays -> higher candidate defers with
     `defer_reason: "file_scope_collision"`, `overlapping_path: "scope/shared"` (correct);
   - sentinel declared FIRST in both arrays -> higher candidate defers with
     `defer_reason: "whole_tree_claim"`, `claim_sentinel: "__WHOLE_TREE__"`, and NO
     `overlapping_path` at all (the masking the clause forbids).

   The verdict is thus **declaration-order-dependent**, and `plan-format.md`'s whole-tree-claim
   declaration rule places no constraint on where the sentinel sits in a phase's
   `Files to modify` block, so both orderings are reachable from ordinary authoring.
4. **CONFIRMED -- the no-co-admission posture is deliberate and pinned.** The
   `WHOLE-TREE-CODISPATCH` fixture's own comment states the target posture, and
   `docs/architecture/batch-admit-schema.md`'s "NEW in v7" precedence paragraph records it. This
   plan preserves that posture exactly and edits none of the three named documents.
5. **CONFIRMED -- the source store is the edit target.** `.extensions.core.source_dir` in
   `/home/benjamin/.config/nvim/.claude-extensions.json` resolves to
   `/home/benjamin/.config/nvim/agent-system/extensions/core`, which exists on this filesystem.
   The deploy-freshness notice in the dispatch is also confirmed: `core` is stale, so a redeploy
   is owed (Phase 3).

### Research Integration

The research report is the authority for the fix LOCUS and is adopted on that point: it verified
by reading both call sites that `scopes_overlap_first` in
`agent-system/extensions/core/scripts/lib/file-scope-overlap.sh` is the single comparator both
`orchestrate-batch-admit.sh` and `scripts/lint/lint-roadmap-batch-proposals.sh` read, that the
former splices it as `$FILE_SCOPE_OVERLAP_JQ_DEFS` text, and that no other sentinel touchpoint
(`plan-file-scope-harvest.sh`, `git-commit-scoped.sh`, `git-commit-phase.sh`,
`validate-artifact.sh`, `source-store-path-lib.sh`) calls that predicate at all. Its single
most useful finding for this plan is its last Findings bullet: **no existing fixture pins the
regression the dispatch requires** -- which the probe above independently confirms by exhibiting
the masking.

The report's Recommendations 1, 2, 3, 5 (first bullet) and 6 are **not adopted**. They were
written under the pre-narrowing framing and propose reversing the no-co-admission posture:
excluding the sentinel-vs-sentinel case from `scopes_overlap_first`'s match clause, flipping
`WHOLE-TREE-CODISPATCH` to assert `admit` for both candidates, retiring the relabeling branch as
dead code, and editing the three documents that record the posture. The dispatch forbids every
one of those. Recommendation 4 is moot for the same reason: the `whole_tree_claim` case arm in
`orchestrate-cycle-plan.sh` keeps firing and keeps its ledger shape, untouched.

One report claim was checked and found to need a correction that matters to this plan: the report
states `file_scope_collision` and `whole_tree_claim` are alike in having no `--allow-X` bypass.
Measured at `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` lines 2041-2047:
`file_scope_collision` DOES have one -- `--allow-scope-collision`, gated to
`collision_scope == "cross_batch"` -- while `whole_tree_claim` has none. The masking therefore
also removes an operator override that should apply, which is why it is worth closing rather
than leaving as a cosmetic label difference.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and no `roadmap_flag` is set, so no
roadmap consultation was performed and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Make a concrete-path overlap take precedence over the reserved `__WHOLE_TREE__` sentinel when
  the SAME pair of tasks overlaps on both, so the verdict reports `file_scope_collision` with the
  concrete `overlapping_path` and carries no `claim_sentinel`.
- Make that outcome independent of where the sentinel sits in either task's declared `file_scope`
  array.
- Pin the behavior with a new fixture in `test-orchestrate-batch-admit.sh`, added alongside the
  four existing whole-tree fixtures without editing any of their assertions.
- Keep `WHOLE-TREE-CODISPATCH`, `WHOLE-TREE-PHASE-EXEMPT`, `WHOLE-TREE-NO-SENTINEL`,
  `WHOLE-TREE-INERT-PATH`, `SCHEMA-LITERAL` and Cases 1-3 green with assertions untouched.
- Redeploy the stale `core` extension so the deployed tree matches the source store.

**Non-Goals**:
- **Reversing the no-co-admission posture.** Two sentinel-declaring tasks with strictly disjoint
  real scope still are not co-admitted, still defer under `whole_tree_claim`, and still carry
  `claim_sentinel`. This plan narrows nothing about that case.
- **Editing `context/patterns/file-footprint-overlap.md`,
  `context/patterns/batch-orchestration-guardrails.md`, or
  `docs/architecture/batch-admit-schema.md`.** Forbidden by the dispatch, and unnecessary: the
  schema doc's precedence paragraph says the `whole_tree_claim` shape fires "when `$hit`'s
  overlapping path is the reserved `__WHOLE_TREE__` sentinel", which remains exactly true after
  this change.
- **Changing `scopes_overlap_first` itself.** Its exact-match and slashless-inertness properties
  are pinned by `WHOLE-TREE-INERT-PATH` and relied on by `task-lock.sh` and the roadmap lint. The
  new precedence is expressed as a separate, additive def composed from it.
- **Changing WHICH PEER is selected as `$hit`.** A candidate overlapping peer A on the sentinel
  only and peer B on a concrete path still reports peer A when A sorts first -- the same
  cross-peer masking class, one level up. Closing it would change which peer `$hit` names, which
  `docs/architecture/batch-admit-schema.md`'s precedence paragraph explicitly asserts is
  unchanged ("no change to which peer is selected or why") and which the dispatch's "every other
  comparison shape MUST be preserved exactly" forbids. Phase 2 records it via `issue-record.sh`
  as a separate observation rather than acting on it.
- **A `$schema` version bump.** No field is added, removed or re-typed, and no `defer_reason`
  changes meaning; one input case is reclassified onto the shape the schema doc already defines
  for it (`overlapping_path` = "first overlapping path, from the COLLIDING task's declared
  `file_scope`"; `claim_sentinel` = the token "both this candidate and the colliding task
  declared"). A bump would additionally require editing the forbidden schema doc and the
  `SCHEMA-LITERAL` fixture's v7 pin, which must stay untouched.
- **`scripts/lint/lint-roadmap-batch-proposals.sh` and its findings.** Batch-FORMATION advisories
  whose remedy is an authored `dependencies[]` edge; explicitly not owned here. It keeps calling
  `scopes_overlap_first` unchanged. Phase 2 only verifies its suite stays green.
- **Whether the no-co-admission posture is the right design at all.** A live question owned
  elsewhere, not a defect.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A new def added to `FILE_SCOPE_OVERLAP_JQ_DEFS` perturbs a consumer that splices the whole text (`orchestrate-batch-admit.sh`, the roadmap lint) | H | L | The def is additive and unreferenced by other consumers; Phase 2 runs `test-lint-roadmap-batch-proposals.sh` and `test-task-lock-liveness.sh`/`test-task-lock-queue.sh` explicitly, not only the selector-chosen set |
| The filtered-scope call silently changes the no-sentinel concrete-vs-concrete path | H | L | With no sentinel present the filter is the identity, so the call reduces to today's single `scopes_overlap_first`; Cases 1-3 and `WHOLE-TREE-NO-SENTINEL` pin this and must stay green with assertions untouched |
| `WHOLE-TREE-CODISPATCH` regresses because its pair's concretes are disjoint and the filtered call returns nothing | H | M | The def falls back to the unfiltered `scopes_overlap_first` when the concrete comparison yields no hit, which is the sentinel; Phase 1's RED baseline and Phase 2's green run both assert this fixture explicitly |
| `empty`-vs-`null` return-convention mismatch at the comprehension's `as $ov_path` binding silently drops a candidate's whole verdict | H | M | The new def mirrors `scopes_overlap_first`'s documented `empty` convention (see that def's own NOTE on why `self_mod_match` deliberately differs); Phase 2 verifies every candidate still emits exactly one NDJSON verdict line |
| The redeploy rewrites the already-dirty tracked `.claude-extensions.json` and the phase commit drops it as out-of-scope | M | M | Phase 3 declares `.claude-extensions.json` in its own `Files to modify` block alongside the sentinel; if it is still dropped, recover via the designed `proposed_file_scope` -> `git-commit-scoped.sh` route, never a second `git-commit-phase.sh` call |
| An added code comment introduces task-number or record-versioning language under `agent-system/**` | M | M | Every phase's comment text names durable anchors (fixture names, def names, file paths) only; Phase 3's gate includes the task-reference and doc lints |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Pin the concrete-path masking with a new fixture [COMPLETED]

**Goal**: Add one new fixture to `test-orchestrate-batch-admit.sh` that exercises the dispatch's
REGRESSION clause in BOTH declaration orderings and asserts the target posture, establishing a
RED-for-the-right-reason baseline before any production code changes. This suite's own documented
TDD convention is to write the final-form target-posture assertion first and record the
pre-fix output; follow it.

**Tasks**:
- [x] Add a fixture `WHOLE-TREE-REAL-PATH-PRECEDENCE` after the existing `WHOLE-TREE-INERT-PATH`
      block (and before the Summary block), using fresh task numbers not already used in the file
      (409/410 and 411/412 are the next free pairs above `WHOLE-TREE-INERT-PATH`'s 407/408 --
      confirm by grep before using them). *(completed: confirmed 409-412 free by grep before use)*
- [x] Sub-case A: two in-batch candidates, scopes `["scope/shared", "__WHOLE_TREE__"]` and
      `["scope/shared", "__WHOLE_TREE__"]` (concrete entry first). Assert the lower-numbered
      candidate admits; the higher-numbered defers with `defer_reason == "file_scope_collision"`,
      `overlapping_path == "scope/shared"`, `collision_scope == "in_batch"`,
      `colliding_task_number ==` the lower number, `has("claim_sentinel") == false`, and
      `whole_tree_claim == true` (the annotation field stays, per its own "hazard stays visible"
      convention). *(completed: passed on first run)*
- [x] Sub-case B: the identical pair with the sentinel entry FIRST in both arrays
      (`["__WHOLE_TREE__", "scope/shared"]`). Assert the IDENTICAL verdict shape as sub-case A --
      this is the order-independence property, and the one assertion that is RED today.
      *(completed: failed exactly as predicted on defer_reason/overlapping_path/claim_sentinel)*
- [x] Write the fixture's header comment to state the target posture and the measured pre-fix
      output for sub-case B (`defer_reason: "whole_tree_claim"`, `claim_sentinel` present,
      `overlapping_path` absent), in the same narrate-target-posture-inline style the four
      existing whole-tree fixture comments already use. Name durable anchors only -- no task
      numbers, no record-versioning phrasing. *(completed)*
- [x] Clean up the fixture's injected `active_projects` entries at the end of the block, matching
      the `jq ... map(select(.project_number != ...))` teardown every neighbouring fixture uses.
      *(completed: separate teardown after each sub-case)*
- [x] Run the suite and record the RED baseline in the phase notes: sub-case A passing, sub-case B
      failing on `defer_reason`/`overlapping_path`/`claim_sentinel`, and all 15 pre-existing cases
      still passing. *(completed: "Results: 15 passed, 1 failed"; only WHOLE-TREE-REAL-PATH-PRECEDENCE
      failed, and only on the three predicted fields for sub-case B)*
- [x] Record an `issue-record.sh` entry for the premise invalidation measured during planning if
      one is not already present for this phase's own findings. *(completed: a premise-invalidation
      entry was already recorded during planning; recorded a supplementary win entry for this
      phase's RED-baseline measurement instead of duplicating it)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh
agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh` -- the selector maps
this phase's single touched path to exactly `test-orchestrate-batch-admit.sh`, the suite this
phase edits, and no other file is touched.

**Scope Hypothesis**: this phase touches exactly one file and adds no production code; task
numbers 409-412 are hypothesised free in that file. Confirm with
`grep -n 'NUM_WT\|=40[0-9]\|=41[0-9]' agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh`
before writing, and pick the next free pairs if they are not.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh` - add the new
  precedence fixture covering both declaration orderings; no existing assertion edited

**Verification**:
- `timeout 300 bash agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh`
  runs to completion and exits 1, with the ONLY failing case being the new fixture's sub-case B.
  A non-zero exit is this phase's EXPECTED outcome and is what closes it green against its own
  criterion: the phase's deliverable is a RED-for-the-right-reason baseline, per this suite's own
  documented TDD convention. An exit 0 here means the fixture does not actually exercise the
  masking and must be corrected before Phase 2 begins.
- The 15 pre-existing case names all still appear as `[PASS]`, verified by name in the output, not
  merely by the count.
- `git diff` over the file shows additions only inside the new fixture block plus its teardown --
  zero lines removed or changed inside any existing fixture.

---

### Phase 2: Give a concrete-path overlap precedence over the reserved sentinel [COMPLETED]

**Goal**: Add an additive, concrete-preferring overlap def to `file-scope-overlap.sh`, switch
`orchestrate-batch-admit.sh`'s per-peer overlap computation to it, and take the new fixture green
with every pre-existing assertion untouched.

**Tasks**:
- [x] In `agent-system/extensions/core/scripts/lib/file-scope-overlap.sh`, inside the
      `FILE_SCOPE_OVERLAP_JQ_DEFS` quoted heredoc and immediately after `scopes_overlap_first`,
      add a new def -- `scopes_overlap_first_preferring_concrete(own_scope; other_scope)` -- that
      (a) compares both scopes with every entry equal to `whole_tree_claim_sentinel` filtered
      out, and (b) falls back to an unfiltered `scopes_overlap_first(own_scope; other_scope)` only
      when that filtered comparison yields no hit. Leave `scopes_overlap_first` itself
      byte-identical. *(completed)*
- [x] Mirror `scopes_overlap_first`'s `empty`-on-no-hit convention exactly, not `null` -- the one
      consumer binds the result with `as $ov_path` inside an array comprehension. Read that def's
      own NOTE (on why `self_mod_match` deliberately returns `null` instead) before choosing, and
      state the chosen convention in the new def's comment. *(completed: internal filtered-hit
      binding converts empty->null via `[...] | first`, matching self_mod_match's own idiom, so
      the fallback branch still runs; the def's own final result follows scopes_overlap_first's
      empty convention)*
- [x] Write the new def's comment to explain WHY concrete beats sentinel: a real-path collision is
      the stronger, more specific finding, it is the shape that carries an operator remedy
      (`--allow-scope-collision`, cross-batch only), and a bare whole-tree claim must not stand in
      for it. Name durable anchors only. *(completed)*
- [x] In `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh`, replace the single
      `scopes_overlap_first($c_scope; ($other.file_scope // [])) as $ov_path |` line inside the
      `$overlaps` comprehension (around line 1019) with a call to the new def. Change nothing else
      in that comprehension: the `$comparison_set` construction, the admitted-set-only `in_batch`
      narrowing `select(...)`, the `$hit` / `$idle_overlap` selections and the
      `$overlaps` record shape all stay exactly as they are. *(completed: single line replaced at
      line 1019, confirmed via git diff -- no other line in the comprehension changed)*
- [x] Add a short note to the script's own header block (the `whole_tree_claim` `defer_reason`
      paragraph around lines 255-278) recording that a sentinel-shaped verdict fires only when the
      pair has no concrete overlap, since a concrete overlap is reported as
      `file_scope_collision` with its real path. State the current design only -- no "previously"
      or "no longer" phrasing, no task numbers. *(completed)*
- [x] Record via `issue-record.sh` the cross-peer masking case named in this plan's Non-Goals (a
      candidate overlapping one peer on the sentinel and a different peer on a concrete path),
      as a separate observation left deliberately unclosed with its reason. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: interface

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh
agent-system/extensions/core/scripts/lib/file-scope-overlap.sh
agent-system/extensions/core/scripts/orchestrate-batch-admit.sh
agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh` -- the selector maps
this phase's three touched paths to 24 real suites and no `__FULL_SWEEP__`, which is the
enumerated one-hop dependent set for a change to the spliced comparator text: test-audit-task-proposals.sh,
test-conflict-predicate.sh, test-deploy-ledger-lib.sh, test-dispatch-strand-probe.sh,
test-force-phases.sh, test-four-tier-conflict.sh, test-gate-lock-host-scope.sh, test-gate-lock.sh,
test-lint-fixture-dependency-declaration.sh, test-lint-json-channel-discipline.sh,
test-orchestrate-batch-admit.sh, test-orchestrate-conclusion-roadmap.sh,
test-orchestrate-context-growth.sh, test-orchestrate-cycle-plan.sh,
test-orchestrate-cycle-postflight.sh, test-orchestrate-predispatch-review.sh,
test-orchestrate-suggest-next-batch.sh, test-orchestrate-unwind-dispatch.sh,
test-phase-heartbeat.sh, test-postflight-deploy-gate.sh, test-redeploy-checkpoint-promotion.sh,
test-system-defect-record-signal-b.sh, test-task-lock-liveness.sh, test-task-lock-queue.sh.

**Scope Hypothesis**: the production change is hypothesised to be one new def plus exactly one
changed call-site line, with no other executable line altered. Confirm by reading
`git diff --stat` and then `git diff` over both production files: anything beyond one added def
block, one replaced call-site line, and comment text means the hypothesis was wrong and the
approach needs re-examination before committing.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/file-scope-overlap.sh` - add the new
  concrete-preferring def; the existing overlap predicate itself stays unchanged
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` - switch the `$overlaps`
  comprehension's per-peer overlap call to the new def; header note on sentinel-shape precedence
- `agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh` - only if the
  Phase 1 fixture's own wiring needs a correction the green run exposes; no pre-existing
  assertion edited

**Verification**:
- `timeout 300 bash agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh`
  reports 0 failures, with `WHOLE-TREE-REAL-PATH-PRECEDENCE` passing in BOTH sub-cases and all
  four pre-existing `WHOLE-TREE-*` case names plus `SCHEMA-LITERAL` and Cases 1-3 still passing
  by name.
- `git diff agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh` shows no
  change to any assertion line written before Phase 1. An assertion that had to be edited to pass
  is evidence the change is wrong, not progress -- stop and reconsider rather than commit.
- `timeout 300 bash agent-system/extensions/core/scripts/tests/test-lint-roadmap-batch-proposals.sh`
  passes. Run it explicitly: the roadmap lint splices the same `FILE_SCOPE_OVERLAP_JQ_DEFS` text
  but the selector does NOT map it from `file-scope-overlap.sh`, so the narrowed pass above would
  miss it.
- `timeout 300 bash agent-system/extensions/core/scripts/verify-touched.sh <the three paths>`
  prints a green narrowed verdict.
- Re-probe both declaration orderings from this plan's premise re-validation against the patched
  script and confirm the two verdicts are now identical in shape and name `scope/shared`.
- Confirm every candidate in a multi-candidate invocation still emits exactly one NDJSON verdict
  line (guards the `empty`-vs-`null` risk).

---

### Phase 3: Redeploy and close the gate [COMPLETED]

**Goal**: Regenerate the deployed tree from the source store so the `core` staleness the dispatch
reported is cleared, and discharge this task's verification obligation.

**Tasks**:
- [x] Run the redeploy with the bounded-wait idiom required by
      `context/patterns/external-process-wait.md` Rule 1: `timeout 540 bash
      .claude/scripts/deploy-headless.sh`, with the Bash tool's own `timeout` parameter raised to
      600000 (not its 120000 default). *(completed: RESULT=landed_verify_clean)*
- [x] Confirm the deploy reports success and that `core` is no longer stale. *(completed)*
- [x] Confirm the deployed copies of the two changed production files match their source-store
      originals (`diff` each pair) -- the deploy is the only sanctioned way they get there; never
      hand-patch under `.claude/**`. *(completed: diff reported no differences for both files,
      plus the test file)*
- [x] Inspect `git status --short` for the tracked files the regeneration rewrote, `.claude-extensions.json`
      among them, and stage deliberately per `context/standards/git-staging-scope.md`. If the
      phase commit drops `.claude-extensions.json` as out-of-scope, recover it through the designed
      route -- the dropped path lands in `.return-meta.json`'s `proposed_file_scope`, followed by a
      scoped `git-commit-scoped.sh` follow-up -- never a second `git-commit-phase.sh` call, which
      re-runs the same check and drops it again. *(completed: `.claude-extensions.json` was the
      only tracked file outside the deployed tree the regeneration rewrote, matching the Scope
      Hypothesis; it is declared in this phase's Files to modify, so no drop was expected)*
- [x] Re-run the two suites from Phase 2 against the deployed tree as well as the source store, so
      the green result is attested on the artifact that actually executes. *(completed: both
      green against `.claude/scripts/tests/...` post-deploy, in addition to the source-store runs
      already captured in the Phase 2 handoff)*

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: full

**Scope Hypothesis**: `.claude-extensions.json` is hypothesised to be the only TRACKED file
outside the gitignored deployed tree that the regeneration rewrites. Confirm with
`git status --short` immediately after the deploy and before staging; any other tracked path that
appears is an undeclared surface and must be declared and reasoned about, not staged silently.

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`
- `.claude-extensions.json` - a tracked file the regeneration rewrites; declared here so the phase
  commit can admit it

**Verification**:
- The redeploy exits 0 within the bounded wait and reports `core` fresh.
- `timeout 300 bash .claude/scripts/tests/test-orchestrate-batch-admit.sh` and
  `timeout 300 bash .claude/scripts/tests/test-lint-roadmap-batch-proposals.sh` both pass against
  the deployed tree.
- Scoped touched-path check over this task's touched paths:
  `bash .claude/scripts/verify-touched.sh agent-system/extensions/core/scripts/lib/file-scope-overlap.sh
  agent-system/extensions/core/scripts/orchestrate-batch-admit.sh
  agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh` prints a green
  narrowed verdict.
- The complete gate set is owed once per orchestration invocation and is explicitly DEFERRED to
  the orchestration close (Move 4) under `/orchestrate`; this phase does not invoke an independent
  full battery. Run as a standalone, non-orchestrated phase instead, it runs
  `bash .claude/scripts/verify-deploy.sh` directly.

---

## Testing & Validation

- [ ] `WHOLE-TREE-REAL-PATH-PRECEDENCE` passes in both declaration orderings.
- [ ] `WHOLE-TREE-CODISPATCH` still passes with its assertions byte-identical -- the
      sentinel-vs-sentinel disjoint-scope pair is still not co-admitted and still reports
      `whole_tree_claim` with `claim_sentinel`.
- [ ] `WHOLE-TREE-PHASE-EXEMPT`, `WHOLE-TREE-NO-SENTINEL`, `WHOLE-TREE-INERT-PATH`,
      `SCHEMA-LITERAL` and Cases 1-3 all still pass, assertions untouched.
- [ ] `test-lint-roadmap-batch-proposals.sh` passes; the roadmap lint's own code is unchanged.
- [ ] The sentinel-vs-concrete and concrete-vs-concrete comparison shapes behave identically to
      the pre-change probe output.
- [ ] `$schema` still reads `orchestrate-batch-admit-v7`.
- [ ] No file under `agent-system/**` gained a task-number reference or record-versioning phrasing.

## Artifacts & Outputs

- `scopes_overlap_first_preferring_concrete` in
  `agent-system/extensions/core/scripts/lib/file-scope-overlap.sh`
- A one-line call-site change plus a header precedence note in
  `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh`
- The `WHOLE-TREE-REAL-PATH-PRECEDENCE` fixture in
  `agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh`
- A regenerated deployed tree with `core` fresh
- `issue-record.sh` entries for the premise invalidation and for the deliberately-unclosed
  cross-peer masking case

## Rollback/Contingency

Each phase is a separate commit, so `git revert` of the Phase 2 commit alone restores the previous
comparator behavior while leaving the new fixture in place as a RED pin of the open defect --
which is the preferable partial state if the fix proves wrong. Before any destructive recovery,
take a durable checkpoint with `bash .claude/scripts/git-snapshot.sh 687 --no-revert`; the
default reverting form belongs only to a genuine rollback. If the redeploy in Phase 3 leaves the
deployed tree inconsistent, re-run `deploy-headless.sh` rather than hand-patching anything under
`.claude/**`.
