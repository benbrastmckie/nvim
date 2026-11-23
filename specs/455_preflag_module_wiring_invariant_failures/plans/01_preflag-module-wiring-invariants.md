# Implementation Plan: Task #455

- **Task**: 455 - Preflag module-wiring invariant failures in generated-surface appending
- **Status**: [IMPLEMENTING]
- **Effort**: 2.25 hours
- **Dependencies**: 446 (landed, confirmed `completed`); 435, 448, 328 (serialization-only, operator-liftable)
- **Research Inputs**: specs/455_preflag_module_wiring_invariant_failures/reports/01_preflag-module-wiring-invariants.md
- **Artifacts**: plans/01_preflag-module-wiring-invariants.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The research report answers part (1) by direct reproduction and falsifies the dispatch's premise:
the generated-surface appending stage computes both claimed-missed surfaces correctly, and the
appended paths are persisted into the task's `file_scope` before implementation begins. The real
residual is a consumer-side visibility seam outside this record's two declared files. This plan
therefore does not change the stage's behaviour. It (a) re-validates the reproduction against
live state, (b) records the part-(1) finding and the part-(2) ruling durably in the one
agent-system file that owns the subject — `plan-file-scope-harvest.sh`'s own header, whose
current prevention claim is the thing the finding corrects — and (c) pins the cited wiring shape,
the inert case, and append-only behaviour with one new fixture in the existing suite, exactly as
the dispatch's VERIFY section asks. No widening of the append list, no edit outside the source
store's two declared files, nothing reaching into the consumer repository.

### Research Integration

- Part (1) is answered: both offered hypotheses are falsified. The archived consumer-repository
  plan DID harvest `.lean` paths, and the ancestor-chain walk DOES reach the repository root and
  DOES match the root README's `dir=FormalSystem` marker. The harvester's output for the cited
  plan is byte-identical to that task's own recorded final `file_scope`.
- Part (2) ruling is NO for all four exemplars (lint-suppression allowlist entry, identifier
  rename, suppression-reason comment, and the per-ledger-row doc-comment obligation), driven by a
  type mismatch: the stage appends PATHS a mechanical regeneration overwrites; all four are
  CONTENT obligations whose required content is not computable from the plan's declared paths.
- Part (3) boundary is upheld: no consumer-repository file is touched or proposed for edit here.
- The report's own Decisions section recommends no behavioural change to either declared file and
  flags the header's stated rationale as demonstrably overclaiming what the append prevents. That
  overclaim is a comment-accuracy defect inside a declared file, so correcting it is the in-scope
  durable record of the finding rather than scope growth.

### Premise Re-Validation (Carried-Figure Discipline)

Each line the dispatch flagged, checked at plan time (2026-11-22) against live state, with the
result stated explicitly even where it only confirms the description unchanged:

1. **"SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/**"** — CONFIRMED UNCHANGED.
   `.claude-extensions.json` resolves `extensions.core.source_dir` to
   `/home/benjamin/.config/nvim/agent-system/extensions/core`; both target files exist there, and
   `/.claude/` is gitignored (`git check-ignore -v` confirms), so the deploy tree is disposable as
   the description states.
2. **"Append only. The stage augments a plan's declared file_scope ... must never remove or
   narrow a planner's declared paths."** — CONFIRMED, WITH ONE PRECISION. The generated-surface
   stage itself is strictly additive (`MERGED = ($base + $extra) | unique`). The harvester's
   FINAL output is additionally filtered by two documented refusals (deployed-tree `.claude/**`
   paths, unexpanded `$VAR`-shaped entries) that DO drop declared entries. Those refusals are
   deliberate, separately documented, and already pinned by existing suite cases 24-29; they are
   not the generated-surface stage narrowing anything. The constraint holds as written for the
   stage this record is about.
3. **"committed=377507 live=377574, exactly the +67 lines"** — CARRIED-UNVERIFIED and NOT
   re-measurable from this repository, as the dispatch itself states. The incident occurred in
   the consumer repository; no attempt is made here to re-derive it, and nothing in this plan
   depends on the figure.

Two further figures carried by the research report were re-derived live at plan time rather than
trusted: the harvester run against the archived consumer plan still emits
`["FormalSystem/OpenLanguage/OpenTruth.lean","FormalSystem/OpenLanguage/OpenValidity.lean","FormalSystem/OpenLanguage/README.md","FormalSystem/README.md","README.md","docs/theorem-index.md","typst/generated/status.typ"]`
(byte-identical to the report's figure), and `grep -c file_scope` against
`orchestrate-build-dispatch.sh` still returns exactly 1 (the sibling-batch comment), so the
dispatch-prompt channel is still blind. Phase 1 re-runs both at implementation time because
figures and line numbers move.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no roadmap flag is set; no roadmap
consultation applies.

## Goals & Non-Goals

**Goals**:
- Record the part-(1) finding durably in the agent-system file that owns the subject, correcting
  the header's claim about what the append prevents.
- Record the part-(2) ruling (NO, for all four exemplars) in the same place, with the reason and
  the two sanctioned alternatives, so it is not re-litigated from scratch.
- Pin the cited wiring shape, the capability-gate-closed inert case, and append-only behaviour
  with one new fixture case in the existing suite.
- Keep the stage's behaviour byte-identical: no output change for any input.

**Non-Goals**:
- No change to `generated_surfaces_available()`'s gating or to `generated_inventory_readmes()`'s
  BEGIN_RE/fence/`dir=` parsing, and no drift in the comment recording that it deliberately
  mirrors the gate's parsing but not its rendering semantics.
- No widening of the append list to lint, naming, suppression-reason, or ledger-row obligations
  (that is the ruling, recorded rather than implemented).
- No edit to any consumer-repository file (part (3)'s boundary), including its
  `.claude-extensions.json`, its gate scripts, and its wiring documentation.
- No edit to `context/formats/plan-format.md` or any other `context/**` file. The plan-prose
  channel obligation already lives there as the coupled-generated-surface declaration
  obligation; the header record points AT it in one direction only, so no second copy can drift.
- No new task is created from this plan. The residual dispatch-prompt visibility seam is recorded
  as a follow-up recommendation in the summary and the issue log, not filed autonomously.
- No regeneration or hand-edit of `scripts/tests/suite-cost-hints.txt` (see Risks).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A header edit drifts the grammar comment away from `plan-format.md`'s "Files to modify" field definition, which it mirrors verbatim by contract | H | L | The edit is confined to the `Generated-surface appending:` subsection and one new short paragraph; the Grammar-accepted block and the `generated_inventory_readmes()` mirroring comment are not touched. Phase 2 verification greps both to confirm they are unchanged |
| The recorded finding reads as draft history ("no longer", "previously", "the earlier claim") and trips the record-versioning rule in a file under `agent-system/**` | M | M | The record states the current design positively — what the stage does, what it does not reach, and where the plan-prose channel comes from — and never narrates the header's own revision. Phase 2 verification greps for the forbidden phrasings and for task-number references |
| Adding a test case moves the suite's advisory wall-clock hint row in `suite-cost-hints.txt` | L | H | Deliberately not declared and not regenerated. That file is mechanically generated by `measure-gate-costs.sh --regen-hints`, is advisory-only, affects nothing but `--jobs` scheduling order, and its own header licenses staleness; regenerating it would re-measure every suite in the repository for a sub-100ms delta against a 1094ms hint. Established practice in this repository is that plans adding test cases do not declare it. Recorded here as a judgment, not an oversight |
| The ruling is read as "the friction is acceptable", closing the subject including the residual visibility seam | M | M | The header record names the residual explicitly as out of this stage's reach rather than as solved, and the summary carries the follow-up recommendation |
| Re-running the reproduction at implementation time disagrees with the plan-time figure (consumer checkout moved) | M | L | Phase 1 is a go/no-go: a disagreement stops the plan before any edit and is recorded in the issue log, since the ruling's wording depends on the reproduction |
| A serialization-only predecessor (435, 448, 328) blocks dispatch although it does not touch either declared file | L | M | Operator-liftable with `update-task-status.sh --depends-on-remove`; no plan change needed |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Re-validate the Reproduction and the Visibility Seam [COMPLETED]

**Goal**: Confirm, against live state rather than carried figures, that the generated-surface
stage still computes both claimed-missed surfaces and that the dispatch-prompt channel is still
blind — the two facts the part-(1) record and the part-(2) ruling both rest on. A disagreement
here stops the plan before any edit.

**Tasks**:
- [x] Re-run the real-incident reproduction read-only:
      `PLAN_FILE_SCOPE_HARVEST_ROOT=/home/benjamin/Projects/BimodalLogic bash agent-system/extensions/core/scripts/plan-file-scope-harvest.sh /home/benjamin/Projects/BimodalLogic/specs/archive/833_stab_definable_from_open_modals/plans/01_stab-definable-from-open-modals.md`
      and confirm the output contains both `typst/generated/status.typ` and the bare `README.md`.
      *(completed: byte-identical 7-entry array, matches plan-time figure exactly)*
- [x] Confirm the root marker the walk matches is still the plain `dir=` form:
      `grep -n "BEGIN GENERATED: inventory" /home/benjamin/Projects/BimodalLogic/README.md`.
      *(completed: `dir=FormalSystem rows=totals desc=no`)*
- [x] If the consumer checkout is absent or the archived plan has moved, fall back to a synthetic
      capable fixture whose root README carries the same marker spelling, and record in the issue
      log that the real-tree leg was unavailable — never silently substitute the synthetic result
      for the real one. *(completed: checkout and archived plan were both available; fallback not
      needed)*
- [x] Re-confirm the dispatch-prompt channel: `grep -c file_scope agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`
      returns 1, and that one hit is a sibling-batch comment, not a read of the dispatching task's
      own `file_scope`. *(completed: count is 1, confirmed sibling-batch comment)*
- [x] Re-derive the edit sites before Phase 2 touches them: `grep -n "happened twice" agent-system/extensions/core/scripts/plan-file-scope-harvest.sh`
      and `grep -on "Case [0-9]\+" agent-system/extensions/core/scripts/tests/test-plan-file-scope-harvest.sh | sed 's/.*Case //' | sort -n | tail -1`.
      *(completed: sentence at line 81; highest existing case is 29, so new case is 30)*
- [x] Record the outcome (agreement or disagreement, and the unavailable-leg case if it fires) via
      `bash .claude/scripts/issue-record.sh --task-dir ... --kind win|issue --class architecture --severity minor --phase implement --dispatch-seq <seq>`.
      *(completed: win recorded, full agreement, no disagreement)*
- [x] On disagreement with the plan-time figures: stop, record, and return `blocked` rather than
      proceeding to Phase 2 with a record the reproduction no longer supports. *(completed: no
      disagreement found; proceeding to Phase 2)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: Read-only re-validation whose only write is to the task's own `specs/**`
issue log, which maps to no suite; per plan-format.md's `__FULL_SWEEP__` sub-case (a) the covering
check is the `prose` row's diff read-through of the recorded entries, not a gate subset.

**Scope Hypothesis**: The reproduction output is expected to be byte-identical to the array quoted
in this plan's Premise Re-Validation section, the `orchestrate-build-dispatch.sh` `file_scope`
count is expected to be exactly 1, and the suite's highest existing case number is expected to be
29. All three are hypotheses to confirm with the commands above, not facts; line numbers in
particular move.

**Files to modify**:
- none planned (read-only re-validation; findings are recorded in the task's own `specs/**` issue
  log via `issue-record.sh`)

**Verification**:
- The reproduction's output contains both `typst/generated/status.typ` and `README.md`, and
  matches the plan-time array (or the disagreement is recorded and the dispatch returns blocked).
- The `file_scope` grep against `orchestrate-build-dispatch.sh` returns 1.
- Diff read-through of the recorded issue-log entries confirms each states a measured result, not
  a restatement of the carried figure.

---

### Phase 2: Record the Finding and the Ruling, and Pin the Wiring Shape [NOT STARTED]

**Goal**: Land the record and the fixture. The header of `plan-file-scope-harvest.sh` gains an
accurate statement of what the generated-surface stage reaches and a short record of the
deliberately-not-appended classes; the suite gains one new case pinning the cited wiring shape,
the inert case against that same fixture, and append-only behaviour as a named assertion. No
executable line of the harvester changes.

**Tasks**:
- [ ] In `plan-file-scope-harvest.sh`'s `Generated-surface appending:` header subsection, replace
      the sentence that asserts an outcome the stage does not produce (the "either blocks on the
      pre-commit gate or fails the INV check mid-implementation -- this has happened twice
      independently. This stage appends them so the plan's declared `file_scope` already carries
      what the edit will force." pair, re-located by grep in Phase 1) with a statement of the
      stage's actual reach: it appends the forced surfaces into the harvested array, which the
      plan-postflight `--file-scope-add` write path persists into the task's `file_scope` in
      `specs/state.json` at the `[PLANNING] -> [PLANNED]` transition.
- [ ] In the same subsection, state what the append does NOT reach: this script only reads a plan
      and never writes back into a plan's own per-phase `**Files to modify**:` prose, and the
      implement-dispatch composer does not read the dispatching task's own `file_scope` — so a
      correct append is not by itself a mid-phase cue to an implementer, and the gate collision
      the stage anticipates can still occur with the append working exactly as designed. State
      any recurrence count as carried from the consumer repository's own issue log and not
      re-measurable here, or omit the count rather than overstate it.
- [ ] In the same subsection, name where the plan-prose channel actually comes from: the
      planner-side coupled-generated-surface declaration obligation in
      `context/formats/plan-format.md` (declare the derived surface in the phase that moves its
      input). Point at it by name in one direction only; do not restate its content.
- [ ] Add a short `Deliberately not appended:` paragraph recording the ruling: lint-suppression
      allowlist entries, identifier renames, suppression-reason comments, and per-ledger-row
      doc-comment obligations are NOT appended, because this stage appends PATHS a mechanical
      regeneration overwrites while those are CONTENT obligations whose required content is not
      computable from a plan's declared paths (determining it would require running the lint,
      naming, or ledger check itself). Name the two sanctioned alternatives: a repository's own
      `coupled_generated_surfaces` declaration (`context/standards/repo-level-declarations.md`,
      read advisory-only by `validate-artifact.sh` at plan-acceptance time) for a genuine
      trigger-glob-to-path coupling, and the consumer repository's own human-facing wiring
      documentation for a content obligation.
- [ ] Keep the whole header addition inside a ~25-line budget, and leave the `Contract:`,
      `Grammar accepted`, deployed-tree-refusal, unexpanded-variable-refusal, and
      `generated_inventory_readmes()` mirroring comments untouched.
- [ ] Add Case 30 to `test-plan-file-scope-harvest.sh`, after Case 29, reusing the existing
      `make_fake_repo`, `make_bare_repo`, and `assert_json_array_eq` helpers: a capable fake repo
      with `typst/generated/status.typ` present; a root `README.md` carrying the consumer
      repository's real marker spelling `<!-- BEGIN GENERATED: inventory dir=FormalSystem rows=totals desc=no -->`
      (the `desc=no` option is not modelled by any existing case); `FormalSystem/README.md` with
      `dir=FormalSystem`; `FormalSystem/OpenLanguage/README.md` with
      `dir=FormalSystem/OpenLanguage`; and a two-phase fixture plan declaring
      `FormalSystem/OpenLanguage/OpenTruth.lean` in one phase and
      `FormalSystem/OpenLanguage/README.md` plus `docs/theorem-index.md` in another — the cited
      wiring shape.
- [ ] Assert in Case 30 that the harvested set equals exactly
      `["FormalSystem/OpenLanguage/OpenTruth.lean","FormalSystem/OpenLanguage/README.md","FormalSystem/README.md","README.md","docs/theorem-index.md","typst/generated/status.typ"]`
      — pinning that both claimed-missed surfaces ARE appended for this shape, which is the
      behaviour the ruling selects.
- [ ] Add an explicit append-only assertion inside Case 30: iterate the fixture plan's three
      declared paths and fail naming any that is absent from the output, so append-only is pinned
      as a named behaviour rather than implied by the equality assertion alone.
- [ ] Add an inert-case assertion inside Case 30: the same fixture plan under `make_bare_repo`
      (capability gate closed) yields exactly the three declared paths and no appended surface.
- [ ] Add Case 30 to the suite header's numbered case list, matching the existing entries' style.
- [ ] Grep both edited files for task-number references and for record-versioning phrasings
      (`no longer`, `previously`, `formerly`, `used to`, `supersedes`, `withdrawn`) and remove any
      the edit introduced.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: Comment-only in the harvester plus an additive case in its own suite, with
no signature or behaviour change, so the cheapest covering check is
`bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/plan-file-scope-harvest.sh agent-system/extensions/core/scripts/tests/test-plan-file-scope-harvest.sh`,
whose selector maps this phase's declared set to `test-backfill-file-scope.sh`,
`test-lean-plan-compliance-check.sh`, `test-plan-file-scope-harvest.sh`,
`test-skill-base-lifecycle.sh`, and `test-validate-artifact.sh`.

**Scope Hypothesis**: Exactly one new case (Case 30) is added, needing no new helper function,
and the header addition fits in roughly 25 lines inside the existing
`Generated-surface appending:` subsection. Confirm the next free case number and the edit site's
current line numbers with Phase 1's greps before editing; if the suite already carries a Case 30,
use the next free number instead and keep the header list in step.

**Files to modify**:
- `agent-system/extensions/core/scripts/plan-file-scope-harvest.sh` - header record: what the
  generated-surface stage reaches, what it does not, where the plan-prose channel comes from, and
  the deliberately-not-appended ruling. Comments only; no executable line changes
- `agent-system/extensions/core/scripts/tests/test-plan-file-scope-harvest.sh` - new Case 30
  (wiring shape, append-only assertion, inert case) plus its header case-list entry

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-plan-file-scope-harvest.sh` exits 0 and
  reports `Failed: 0` with Case 30's assertions among the passes. The suite drives the
  source-store copy directly (no `deploy-root-guard.sh` dependency, per its own header), so this
  runs before the deploy in Phase 3.
- `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/plan-file-scope-harvest.sh agent-system/extensions/core/scripts/tests/test-plan-file-scope-harvest.sh`
  is green over the five suites named in the Tier Justification.
- Behaviour is unchanged: Phase 1's real-incident reproduction, re-run after the edit, emits a
  byte-identical array.
- `git diff` of the harvester shows changed hunks only inside comment lines, with the
  `Grammar accepted` block and the `generated_inventory_readmes()` mirroring comment untouched.
- Neither edited file contains a task-number reference or a record-versioning phrasing.

---

### Phase 3: Deploy and Discharge the Gate [NOT STARTED]

**Goal**: Regenerate the deploy tree so the deployed copies match the source store, then
discharge this task's verification obligation.

**Tasks**:
- [ ] Run `bash .claude/scripts/deploy-headless.sh` from the repository root.
- [ ] Confirm the deployed copies match the source store:
      `diff agent-system/extensions/core/scripts/plan-file-scope-harvest.sh .claude/scripts/plan-file-scope-harvest.sh`
      and the same for the test suite, both empty.
- [ ] Run the dispatch's named scoped narrowing against the deployed tree:
      `bash .claude/scripts/tests/run-all.sh --only test-plan-file-scope-harvest.sh`.
- [ ] Discharge the full tier: under `/orchestrate`, run the scoped touched-path check
      `bash .claude/scripts/verify-touched.sh agent-system/extensions/core/scripts/plan-file-scope-harvest.sh agent-system/extensions/core/scripts/tests/test-plan-file-scope-harvest.sh`
      and record explicitly in the phase's verification notes that the complete gate set is
      deferred to the orchestration close rather than independently run. Standalone (no
      orchestration close to defer to): run `bash .claude/scripts/verify-deploy.sh` directly.
- [ ] Record the part-(1) finding, the part-(2) ruling, and the residual dispatch-prompt
      visibility seam as a follow-up recommendation in the task summary; create no task from this
      dispatch.

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed `.claude/` tree; the
  reserved sentinel declares that whole-tree claim (the tree itself is gitignored and commits
  nothing)

**Verification**:
- `deploy-headless.sh` exits 0 and both `diff` invocations are empty.
- `bash .claude/scripts/tests/run-all.sh --only test-plan-file-scope-harvest.sh` is green.
- The scoped touched-path check is green and the deferral of the complete gate set to the
  orchestration close is recorded in the phase's verification notes (or, standalone,
  `verify-deploy.sh` is green).

## Testing & Validation

- [ ] `test-plan-file-scope-harvest.sh` passes from the source store with Case 30 present.
- [ ] Case 30 pins all three VERIFY bullets from the dispatch: the cited wiring shape (both
      claimed-missed surfaces appended), the inert case (capability gate closed yields no appended
      surface), and append-only (every declared path survives).
- [ ] The harvester's output for the real archived consumer plan is byte-identical before and
      after the edit.
- [ ] `run-all.sh --only test-plan-file-scope-harvest.sh` is used as the scoped narrowing; the
      unfiltered aggregator is not invoked as this task's own criterion.
- [ ] No consumer-repository file is modified (`git status` in that checkout stays clean).

## Artifacts & Outputs

- Updated `agent-system/extensions/core/scripts/plan-file-scope-harvest.sh` (header record only).
- Updated `agent-system/extensions/core/scripts/tests/test-plan-file-scope-harvest.sh` (Case 30).
- Regenerated deployed `.claude/` tree (gitignored).
- Task summary carrying the part-(1) finding, the part-(2) ruling, and the follow-up
  recommendation for the dispatch-prompt visibility seam.

## Rollback/Contingency

Both edits are additive and comment- or test-only. To revert, restore the two source-store files
from HEAD (`git checkout HEAD -- <the two paths>`, after a `git-snapshot.sh 455 --no-revert`
checkpoint if the tree is dirty) and re-run `deploy-headless.sh` to bring the deploy tree back in
step. No state, schema, or behaviour change needs undoing. If Phase 1's re-validation disagrees
with the plan-time figures, no edit has been made yet and the correct contingency is to stop and
return `blocked` with the disagreement recorded, since the record and the ruling both rest on that
reproduction.
