# Implementation Plan: Task #564

- **Task**: 564 - Fix validate-artifact.sh Tier Justification false-positive (sentinel domination in `suite_selection_select`)
- **Status**: [IMPLEMENTING]
- **Effort**: 5 hours
- **Dependencies**: 505 (`suite_selection_non_core_extension_paths`) -- already archived/[COMPLETED]; satisfied, no remaining blocker
- **Research Inputs**: specs/564_fix_validateartifactsh_tier_justification_false_po/reports/01_tier-justification-sentinel-domination.md
- **Artifacts**: plans/01_compositional-suite-selection-union.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`suite_selection_select` short-circuits: the moment any one given path resolves to no suite, it
emits the `__FULL_SWEEP__` sentinel and returns, discarding every suite already accumulated for
the paths processed before it. A touched set mixing a suite-covered file with an uncovered one
therefore collapses to the sentinel, so `validate-artifact.sh`'s Tier Justification check reads
an honest narrow claim as fabricated (and, symmetrically, reads a per-path-composed claim as
under-verifying). This plan makes the aggregation compositional -- the sentinel becomes a floor
contributed by its own member rather than a ceiling imposed on the set -- then adapts the two
production call sites that detect "no suite covers this" via the now-invalid
`[ #out -eq 1 ] && [ out[0] = sentinel ]` idiom, updates the authoring contract text, and pins
the new semantics with fixtures run from both a source-store and a deployed vantage point.

The layer-ownership ruling required by the task's point (2) is: **the selector layer owns the
fix.** `plan-format.md`'s own "Enforcement level (Tier Justification measurement)" subsection
bounds the check's scope to "claims grounded in `suite_selection_select`", and the required
fixtures (a)/(b) pin that function's direct return value, not a filtered derivative; the
asymmetry is also observable from the library alone with no plan and no validator present. The
consumer-side edits in Phase 2 are *necessary adaptations to a changed API*, not a second,
independent fix of the same defect -- `validate-artifact.sh` gains no set-semantics logic of its
own, it only drops a non-claimable token from an existing comparison. **This ruling must be
restated in the implementing commit message for Phase 1**, per point (2).

### Research Integration

- The defect was freshly reproduced against the live source store: `lint/lint-agent-contracts.sh`
  alone resolves to 10 real suites, `scripts/audit-deletion-references.sh` alone correctly
  escalates to the sentinel, and the two together collapse to pure `__FULL_SWEEP__`.
  `suite_selection_unmapped` over the same pair correctly names only the uncovered path.
- The production call-site census found exactly two raw multi-path callers:
  `validate-artifact.sh` (Tier Justification, advisory) and `verify-deploy.sh` (Gate 8
  `--gate8-touched` narrowing, execution-critical). Every other consumer already routes through
  `suite_resolver_resolve`, which deliberately calls the selector one path at a time.
- `suite-resolver-lib.sh`'s header already documents this exact collapse and works around it by
  per-path invocation -- an existing, already-tested compositional precedent, though not a
  drop-in substitute backend for the Tier Justification check (it also folds in the declared
  backend and the explicit map, which would broaden what the check measures).
- `tests/test-run-all-selection.sh` Case 3 currently pins the pre-fix behavior as correct and
  must be flipped as part of this work, not treated as an unrelated regression.

### Carried-Figure Re-Validation

The dispatch flagged four description lines for re-check. Results, stated explicitly even where
they only confirm the description unchanged:

1. **Source store resolution** -- CONFIRMED live today:
   `jq -r '.extensions.core.source_dir' .claude-extensions.json` yields
   `/home/benjamin/.config/nvim/agent-system/extensions/core`, and every file this plan names was
   confirmed present under it.
2. **ORIGIN / filing-precedent narrative** -- historical provenance; not mechanically
   re-checkable and not relied on by any step below. Unchanged, no action.
3. **"Second, distinct escalation mode" vs. the non-core selection record** -- CONFIRMED and
   now strengthened: that record has landed (archived/[COMPLETED]), its mapping-walk change is
   live in the library measured here, and the defect still reproduces against the post-change
   library. The record's own "land it first, then re-derive before editing" ordering requirement
   is therefore discharged.
4. **Territory edge from `validate_artifact_corpus_resolution`** -- CONFIRMED live:
   `specs/state.json` shows task 652 (`validate_artifact_corpus_resolution`) with
   `dependencies: [650, 564]`, status `not_started`. Its own fix remains disjoint from this one.

One correction to the dispatch's appended corroboration, carried forward from research: the
command it cites (`suite_selection_select context/contracts/phase-closure.md
scripts/lib/suite-selection-lib.sh` returning `__FULL_SWEEP__`) **no longer reproduces** --
`phase-closure.md` is now mappable (it resolves to `test-orchestrate-build-dispatch.sh`), so the
pair now returns a real union. The underlying defect is unaffected; only that particular
smoke-test invocation went stale. Do not replay it as a reproduction; use the research report's
freshly-verified pair instead.

One correction to the dispatch's declared territory: `specs/state.json`'s own `file_scope` for
this task is already wider than the description's prose ("the same two files"), listing
`suite-selection-lib.sh`, `validate-artifact.sh`, `tests/test-validate-artifact.sh` and
`tests/test-run-all-selection.sh`. `verify-deploy.sh` and `context/formats/plan-format.md` are
genuinely new and are widened into scope by this plan's own `Files to modify` declarations (the
postflight harvest forwards them).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided for this dispatch; ROADMAP.md was not consulted and is not
modified by this plan.

## Goals & Non-Goals

**Goals**:
- Make `suite_selection_select`'s multi-path aggregation compositional: the union of what its
  members require, with the sentinel contributed as one more member rather than replacing the set.
- Preserve both existing invariants: an all-mappable set resolves to exactly the suites it
  resolves to today; an all-unmappable set still returns `__FULL_SWEEP__` alone.
- Preserve Gate 8's fail-safe: a `--gate8-touched` set containing any unmappable path still falls
  back to the full, unnarrowed battery.
- Stop the false "fabricated claim" warning for an honest mixed-set Tier Justification *without*
  the author dropping any real path from `Files to modify`, and without introducing a new false
  "under-verifies" warning in its place.
- Pin all of the above with fixtures that run from both a source-store and a deployed vantage
  point, and leave the library's own caller-facing header consistent with the new contract.

**Non-Goals**:
- No hand-authored file under any deployed `.claude/**` tree (Phase 5's redeploy is the only
  thing that writes there).
- No broadening of what `__FULL_SWEEP__` means for a genuinely repo-wide change.
- No change to the non-core mapping walk owned by the already-landed non-core selection record.
- No substitution of `suite_resolver_resolve` as the Tier Justification check's backend.
- No fix of the corpus-resolution escalation mode owned by `validate_artifact_corpus_resolution`,
  nor of the stop-word ceiling-check defect owned by the ceiling-check record.
- No task-number references and no record-versioning language in any file landing under
  `agent-system/**` (both are permitted in this plan, which lives under `specs/**`).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Gate 8's `-eq 1 && ==sentinel` detection silently stops firing for a mixed set, skipping real coverage | H | H if unaddressed | Phase 2 converts it to a "contains the sentinel anywhere" test; Phase 4 adds a regression fixture over a mixed `--gate8-touched` set |
| The library header's canonical Usage snippet keeps advising the old idiom, so a future caller hands `run-all.sh --only` the literal token `__FULL_SWEEP__` | M | H if unaddressed | Phase 1 rewrites the snippet and the PUBLIC API return-contract paragraph in the same commit as the behavior change |
| Stripping the sentinel in the suitelist branch of `validate-artifact.sh` turns today's false "fabricated" warning into a new false "under-verifies" warning | M | M | Phase 2 strips the token before computing missing/extra; Phase 4 fixture (c) asserts 0 warnings over a mixed-set plan with the bookkeeping path retained |
| Case 3 of `test-run-all-selection.sh` pins the pre-fix behavior and fails honestly after Phase 1 | L | Certain | Phase 4 flips Case 3 deliberately and states why; Phase 1's own verification expects that one failure and no other |
| A hardcoded fixture path becomes self-referential via the library's stratum-(b) grep once committed | M | M | Reuse the file's existing dynamic derivation loops and `test-validate-artifact.sh`'s PID-suffix precaution; never hardcode a basename |
| Source-store and deployed copies diverge mid-task, so "both vantage points" is measured against different code | M | L | Phase 5 redeploys first, then runs the suite from both roots in the same phase |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 1, 2 |
| 4 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Compositional union in `suite_selection_select` [COMPLETED]

**Goal**: The selector accumulates every path's resolution into the union instead of
short-circuiting, with the sentinel contributed as a member; the library header documents the new
contract and warns against per-path composition.

**Tasks**:
- [x] Re-read `suite_selection_select` (the loop that `echo`s the sentinel and `return`s on the
      first empty `_ssl_resolve_one` result) and confirm the short-circuit is still shaped as the
      research report describes before editing. *(completed: confirmed shape unchanged before editing)*
- [x] Replace the short-circuit: on an empty per-path resolution, push
      `$SUITE_SELECTION_FULL_SWEEP_SENTINEL` into the accumulator and continue the loop. Leave the
      trailing `sort -u` emission unchanged, so an all-unmappable set collapses to the sentinel
      alone and an all-mappable set is provably untouched (no code path to the sentinel runs).
      *(completed: direct probe confirmed all-mappable output byte-identical to pre-edit capture)*
- [x] Update the PUBLIC API paragraph for `suite_selection_select` to state the new return
      contract: the sorted, de-duplicated union of resolved suite basenames across every given
      path, with the sentinel present as one more line whenever at least one path was unmappable;
      the sentinel alone when no path mapped. *(completed)*
- [x] Rewrite the header's canonical Usage snippet from the `-eq 1 && == sentinel` idiom to a
      "does the output CONTAIN the sentinel" test, with the `--only` branch running over the
      output with the sentinel token removed. *(completed)*
- [x] Add one sentence to the PUBLIC API header, immediately after the `suite_selection_select`
      entry, stating that composing per-path invocations and unioning the results by hand is not
      equivalent to one multi-path call (the two agree when no member is unmappable and can
      legitimately differ when one is), modeled on `suite-resolver-lib.sh`'s own header framing.
      *(completed)*
- [x] Check `suite_selection_select_annotated`, which wraps both functions and today emits "the
      sentinel alone, or one row per selected suite": make it consistent with the new contract
      (a mixed set must not lose its real suites' rows), and update its header entry if its
      behavior changes. *(completed: mixed set now emits a bare sentinel line plus classified rows
      for every real suite; header entry updated)*
- [x] Write the point-(2) layer-ownership ruling and its reasoning into this phase's commit
      message body. *(completed: see phase-closing commit message)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: the research report's census found exactly two production call sites for the
raw multi-path `suite_selection_select` (`validate-artifact.sh`, `verify-deploy.sh`) plus the
library's own header snippet, with `suite_resolver_resolve` and every other consumer immune by
per-path construction. Confirm at implementation time with
`grep -rn 'suite_selection_select' agent-system/extensions/core` before editing; if a third
production caller has appeared, stop and fold it into Phase 2 rather than leaving it on the old
idiom.

**Tier Justification**: measured -- `suite_selection_select` over this phase's touched path
returns `test-gate8-suite-selection.sh`, `test-gate-slow-bucket-split.sh`,
`test-orchestrate-build-dispatch.sh`, `test-run-all-selection.sh`, `test-suite-resolver-lib.sh`,
`test-validate-artifact.sh` and `test-verify-touched.sh`, which `bash
agent-system/extensions/core/scripts/verify-touched.sh
agent-system/extensions/core/scripts/lib/suite-selection-lib.sh` runs as a narrowed pass.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh` - compositional accumulation
  in `suite_selection_select`; PUBLIC API return-contract paragraph, Usage snippet, and
  per-path-composition warning in the header; `suite_selection_select_annotated` consistency.

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/lib/suite-selection-lib.sh`
  runs the seven suites named above. Exactly one failure is expected and acceptable at this
  phase: `test-run-all-selection.sh` Case 3, which pins the pre-fix behavior and is flipped in
  Phase 4. Any other failure blocks the phase.
- Direct probes, sourcing the edited library: a mixed set (one suite-covered path plus one
  genuinely uncovered path) returns the covered path's real suites plus the sentinel; an
  all-uncovered set returns the sentinel alone; an all-covered set returns byte-identical output
  to the pre-edit library (capture the pre-edit output first and `diff` it).

---

### Phase 2: Adapt the two production call sites to the new contract [NOT STARTED]

**Goal**: Gate 8's fail-safe fallback and the Tier Justification comparison both behave correctly
under a mixed sentinel-plus-suites return.

**Tasks**:
- [ ] `verify-deploy.sh`, Gate 8 `--gate8-touched` narrowing: change the detection from "the array
      is exactly `[sentinel]`" to "the array CONTAINS the sentinel anywhere", and fall back to the
      full unnarrowed battery whenever it does. Keep the existing zero-suite fallback branch and
      the existing `say` notices, adjusting their wording to match what is now being detected.
- [ ] `validate-artifact.sh`, Tier Justification check: keep the `sentinel`-claim branch meaning
      "the selector returned the sentinel and nothing else" (restated as a contains-check plus a
      length test), so a sentinel-only claim over a mixed set is correctly flagged as unmeasured.
- [ ] `validate-artifact.sh`, suitelist-claim branch: strip the sentinel token from the actual-set
      array before computing missing/extra. The sentinel is not a claimable suite name; leaving it
      in would replace today's false "fabricated claim" warning with an equally false
      "under-verifies" warning for the same honest mixed-set claim.
- [ ] Re-read the surrounding comment block in `validate-artifact.sh` that describes the check's
      own semantics and bring it into line with the stripping behavior.
- [ ] Confirm no other branch in either file reads the selector's output positionally (by index or
      by array length) in a way the new contract invalidates.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh
agent-system/extensions/core/scripts/validate-artifact.sh
agent-system/extensions/core/scripts/verify-deploy.sh` is the covering check for this phase's two
touched paths -- it resolves and runs the narrowed suite set for both files itself, including the
gate-selection and validate-artifact suites that exercise the two edited branches.

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` - Gate 8 `--gate8-touched` sentinel
  detection becomes a contains-check preserving the fail-safe fallback.
- `agent-system/extensions/core/scripts/validate-artifact.sh` - Tier Justification check: sentinel
  stripped from the actual set before the suitelist comparison; sentinel-claim branch restated as
  a contains-plus-length test; surrounding comment updated.

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/validate-artifact.sh agent-system/extensions/core/scripts/verify-deploy.sh`
  passes, with the single expected Case 3 failure from Phase 1 still the only tolerated failure
  until Phase 4 lands.
- Manual probe: run `verify-deploy.sh --gate8-touched` over a comma pair of one suite-covered and
  one uncovered path and observe the "falling back to the full, unnarrowed battery" notice (use
  `--skip-slow` and a gate subset to keep the probe cheap).
- Manual probe: run `validate-artifact.sh` over a scratch plan whose phase mixes a suite-covered
  path with an uncovered one and whose Tier Justification names only the real suites; observe no
  Tier Justification warning in either direction.

---

### Phase 3: Bring the authoring contract text into line [NOT STARTED]

**Goal**: `plan-format.md`'s Tier Justification contract describes the mixed-set case, so an
author measuring with the fixed selector knows what to name and what to leave out.

**Tasks**:
- [ ] In the `**Tier Justification**:` subsection, qualify the "match that output verbatim"
      obligation: when the selector's output contains the sentinel alongside real suite names, the
      honest claim names the real suites and does not reproduce the sentinel token, which is not a
      claimable suite name.
- [ ] In the `__FULL_SWEEP__` case bullet, state that the sentinel is the honest claim only when
      it is the selector's *entire* output for the phase's touched paths -- a mixed set is a
      suite-list claim, not a sentinel claim.
- [ ] Add the per-path-composition warning in the author-facing voice: run the selector once over
      the whole `Files to modify` set, never once per path with the results unioned by hand, since
      the check itself makes a single multi-path call.
- [ ] Verify the "Enforcement level (Tier Justification measurement)" subsection's description of
      what the check compares still matches `validate-artifact.sh` after Phase 2, and correct it
      if not.
- [ ] Keep the edit free of task-number references and record-versioning language (this file lands
      under `agent-system/**`): state the current contract only, with no "previously"/"no longer"
      framing.

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: measured -- `suite_selection_select` over this phase's touched path
returns `test-lean-challenge-snapshot.sh`, `test-orchestrate-build-dispatch.sh`,
`test-phase-heading-patterns.sh`, `test-plan-file-scope-harvest.sh` and
`test-resume-scan-nonconformance.sh`, run as a narrowed pass by `bash
agent-system/extensions/core/scripts/verify-touched.sh
agent-system/extensions/core/context/formats/plan-format.md`. That list is the deployed-corpus
resolution; the source-store copy of the library omits the first entry -- a live instance of the
corpus-resolution divergence a separate record owns, noted here so the implementer is not
surprised by a one-suite difference between vantage points.

**Files to modify**:
- `agent-system/extensions/core/context/formats/plan-format.md` - updates the Tier
  Justification subsection, the full-sweep-sentinel case bullet, and the enforcement-level
  subsection for mixed-set selector output.

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/context/formats/plan-format.md`
  runs the four suites named above and passes.
- Read-through of the diff confirming no task-number reference and no record-versioning phrasing
  entered the file.

---

### Phase 4: Pin the new semantics with fixtures [NOT STARTED]

**Goal**: The suites that own this library and this check assert the compositional contract, the
preserved sentinel case, the preserved all-mappable case, Gate 8's fail-safe, and the end-to-end
0-warning validation over an honest mixed-set plan.

**Tasks**:
- [ ] `tests/test-run-all-selection.sh` Case 3: flip the assertion. A mixed call (the existing
      dynamically-derived lint fixture plus the existing dynamically-derived zero-reference
      candidate) must now return the lint fixture's real suites, and must additionally contain the
      sentinel. Update the case's comment to describe the compositional rule it now pins.
- [ ] Add fixture (a): a mixed set of one sentinel-mapped bookkeeping-shaped path and one narrow
      real target resolves to the narrow target's suite(s). Derive both inputs live, following the
      file's existing derivation loops; never hardcode a basename.
- [ ] Add fixture (b): an all-sentinel set still returns `__FULL_SWEEP__` alone (reuse Case 1's
      `ZERO_REF_CANDIDATE` derivation, with a second independently-derived uncovered path so the
      case genuinely exercises more than one member).
- [ ] Add a fixture asserting the preserved invariant explicitly: an all-mappable multi-path set's
      output is exactly the union of its members' per-path outputs, with no sentinel present.
- [ ] Add fixture (c): build a synthetic two-phase plan whose phase mixes a bookkeeping path with
      a real narrow target and whose Tier Justification honestly names the narrow target's suites,
      invoke `validate-artifact.sh` on it as a subprocess, and assert 0 Tier Justification
      warnings -- with the bookkeeping path still present in `Files to modify`. Model the builder
      on `test-validate-artifact.sh`'s existing `make_tj_fixture`/`TJ_UNMAPPED_PATH` pattern,
      including its PID-suffix precaution against stratum-(b) self-matching; do not promote the
      builder to a shared helper on this first reuse.
- [ ] Add a Gate 8 fail-safe regression: a `--gate8-touched` set mixing a mapped and an unmapped
      path still falls back to the full unnarrowed battery. Place it in whichever of
      `test-run-all-selection.sh` or `test-verify-deploy-gate-selection.sh` the surrounding
      conventions make it belong to; if it lands in the latter, add that file to this phase's
      touched set and re-measure the Tier Justification before committing.
- [ ] `tests/test-validate-artifact.sh`: add a Tier Justification case over a mixed touched set
      asserting that neither the "fabricated claim" nor the "under-verifies" warning fires for an
      honest suite-list claim, and that a sentinel-only claim over a mixed set *does* warn.
- [ ] Guard every new case so it reports a clean skip rather than a failure when run from a
      deployed vantage point where the derivation inputs do not exist, matching the existing
      `EXT_PARENT` guard discipline in this file.

**Timing**: 1.5 hours

**Depends on**: 1, 2

**Verification Tier**: interface

**Scope Hypothesis**: Case 3 is asserted to be the only existing case in
`tests/test-run-all-selection.sh` that pins the pre-fix short-circuit behavior (36/36 baseline at
research time). Confirm by running the suite immediately after Phase 1 and before editing: the
set of failures observed there is the complete set of cases needing an expectation flip. If more
than Case 3 fails, widen this phase's task list rather than silently adjusting assertions.

**Tier Justification**: measured -- `suite_selection_select` over this phase's two touched paths
returns `test-lint-shellcheck-parallel.sh`, `test-measure-gate-costs.sh`,
`test-run-all-selection.sh`, `test-validate-artifact.sh`,
`test-verify-deploy-gate-selection.sh` and `test-verify-touched.sh`, run as a narrowed pass by
`bash agent-system/extensions/core/scripts/verify-touched.sh` over those same two paths.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-run-all-selection.sh` - Case 3 flipped;
  fixtures (a), (b), the all-mappable invariant case, fixture (c), and the Gate 8 fail-safe case.
- `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` - mixed-touched-set Tier
  Justification cases (honest suite-list claim clean; sentinel-only claim warns).

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-run-all-selection.sh` passes with zero
  failures (the Phase 1 Case 3 failure is now resolved) and its total case count has grown by the
  number of cases added.
- `bash agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` passes with zero
  failures.
- `bash agent-system/extensions/core/scripts/verify-touched.sh` over both touched paths passes.

---

### Phase 5: Redeploy and verify from both vantage points [NOT STARTED]

**Goal**: The deployed tree carries the fixed library, check and contract text, and the pinning
suites pass when run from a deployed root as well as from the source store.

**Tasks**:
- [ ] Confirm the working tree is clean of unrelated staged changes, then run the redeploy with
      the bounded-wait idiom: `timeout 540 bash .claude/scripts/deploy-headless.sh`, with the Bash
      tool timeout raised to 600000 (not its 120000 default), per the external-process-wait
      pattern. This is a whole-tree regeneration.
- [ ] Confirm source-store/deployed parity for the four edited scripts and the edited contract
      file by diffing each source-store copy against its deployed counterpart.
- [ ] Run `bash .claude/scripts/tests/test-run-all-selection.sh` (deployed vantage point) and
      confirm it passes, with any vantage-point-dependent cases reporting a clean skip rather than
      a failure.
- [ ] Run `bash agent-system/extensions/core/scripts/tests/test-run-all-selection.sh`
      (source-store vantage point) and confirm it passes.
- [ ] Run the scoped touched-path check over every path this task actually modified:
      `bash .claude/scripts/verify-touched.sh <each modified path>`.
- [ ] Record the complete-gate-set obligation as explicitly deferred to the orchestration close
      (Move 4) rather than invoking the full battery as this phase's own criterion.

**Timing**: 1 hour

**Depends on**: 2, 3, 4

**Verification Tier**: full

**Scope Hypothesis**: this phase asserts that the only deployed-tree writes in this task come from
`deploy-headless.sh`. Confirm by checking that no earlier phase's commits touched a path under
`.claude/**`; if any did, that is a boundary violation to be reverted at the source-store level
and redeployed, not patched in place.

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed `.claude/` tree; no
  file under it is hand-authored by this task.

**Verification**:
- The redeploy completes within its bound and reports success.
- Both vantage-point runs of `test-run-all-selection.sh` pass with zero failures.
- `bash .claude/scripts/verify-touched.sh` over the task's modified paths passes.
- The complete gate set is owed once per orchestration invocation and is discharged at the
  orchestration close; this phase defers to it explicitly and does not invoke an independent full
  battery of its own.

## Testing & Validation

- [ ] A mixed touched set returns the union of its members' suites plus the sentinel, never the
      sentinel alone.
- [ ] An all-unmappable touched set still returns `__FULL_SWEEP__` alone.
- [ ] An all-mappable touched set returns byte-identical output to the pre-change library.
- [ ] `--gate8-touched` over a mixed set still falls back to the full, unnarrowed battery.
- [ ] An honest suite-list Tier Justification over a mixed-set phase validates with 0 warnings
      with the bookkeeping path retained in `Files to modify`.
- [ ] A sentinel-only Tier Justification over a mixed-set phase is correctly warned.
- [ ] `test-run-all-selection.sh` and `test-validate-artifact.sh` both pass with zero failures
      from both a source-store and a deployed vantage point.

## Artifacts & Outputs

- Modified: `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh`
- Modified: `agent-system/extensions/core/scripts/validate-artifact.sh`
- Modified: `agent-system/extensions/core/scripts/verify-deploy.sh`
- Modified: `agent-system/extensions/core/context/formats/plan-format.md`
- Modified: `agent-system/extensions/core/scripts/tests/test-run-all-selection.sh`
- Modified: `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh`
- Regenerated: the deployed `.claude/` tree, via `deploy-headless.sh`
- A Phase 1 commit message body carrying the point-(2) layer-ownership ruling

## Rollback/Contingency

Each phase commits independently, so a failed phase reverts by reverting its own commit and
redeploying. If the selector change proves unsafe in a way Phase 2 cannot absorb -- for example a
third production caller surfaces that genuinely depends on the short-circuit's suppression -- the
contingency is to revert Phase 1 and Phase 2 together (the contract change and its adaptations
are a unit), leave Phases 3-4's documentation and fixtures reverted alongside them, redeploy, and
record the blocking caller in the task's issue log before re-planning. Before any intentional
rollback that would otherwise be refused on a dirty tree, take a snapshot first with
`bash .claude/scripts/git-snapshot.sh 564`.
