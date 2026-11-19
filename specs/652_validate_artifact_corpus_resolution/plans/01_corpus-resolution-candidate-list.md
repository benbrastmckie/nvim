# Implementation Plan: Task #652

- **Task**: 652 - Resolve validate-artifact.sh's Tier-Justification corpus against the repository under validation, not the deployed agent-system tree
- **Status**: [NOT STARTED]
- **Effort**: 5.5 hours
- **Dependencies**: Tasks 650 and 564 (both `[COMPLETED]`, re-confirmed live in `specs/state.json` at plan authoring)
- **Research Inputs**: specs/652_validate_artifact_corpus_resolution/reports/01_validate-artifact-corpus-resolution.md
- **Artifacts**: plans/01_corpus-resolution-candidate-list.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`validate-artifact.sh`'s advisory per-phase Tier-Justification scan sources its suite-selection
backend from exactly one script-relative path, so every verdict it issues is measured against the
agent system's own deployed suite corpus — even when the plan under validation runs against a
consumer repository's own copied suite tree. This plan extends the script's existing ordered
candidate-list idiom with the repository-under-validation's declared project suite root(s) ahead
of today's single entry, makes every advisory warning name the corpus it was measured against and
where that corpus was resolved from, and covers the declared / undeclared / declared-but-absent
cases in the script's own suite. Done when a declaring repository is measured against its own
corpus, a non-declaring repository behaves byte-identically to today, and no warning is silenced.

### Research Integration

The research report establishes the three facts this plan builds on, each re-derived live at plan
authoring:

- The resolution site is a one-element `_suite_selection_lib_candidates` array followed by the
  script's standard first-found-wins loop and loud `exit 5` miss branch (live: array at lines
  358-360, loop 362-367, miss branch 368-374, source at line 376). It is the only site in the
  script that sources `suite-selection-lib.sh`; the Tier-Justification block is its sole consumer.
- `suite-selection-lib.sh` fixes `_SSL_SCRIPTS_ROOT`/`_SSL_TESTS_DIR` at source time from its own
  `${BASH_SOURCE[0]}` location (live: line 199 computes `${_SSL_SELF_DIR}/..`, line 200 appends
  `/tests`). There is no published root override, so the only non-invasive way to re-root the
  unmodified engine is to source a different on-disk copy that lives inside the target corpus.
  The library sources nothing else, so a planted standalone copy is viable.
- `verification_scope_project_suite_roots <repo_root>` already exists in
  `scripts/lib/verification-scope-lib.sh` (live: lines 131-145) and fails open to empty output on
  every absence/malformed case. `validate-artifact.sh` does not source that library today.

### Prior Plan Reference

No prior plan. This is the task's first planning round.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context, and no roadmap flag was set,
so no roadmap phases are added and no roadmap items are claimed.

### Premise Re-Validation (Carried-Figure Discipline)

The dispatch flagged three description lines for re-validation. Each was checked against live
state at plan authoring:

- **"SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/\*\*"** — CONFIRMED unchanged.
  `agent-system/extensions/core/scripts/validate-artifact.sh` exists (1029 lines live) and the
  repository root carries `.claude-extensions.json`, so the deploy-boundary rule applies as
  described. The script does not source `deploy-root-guard.sh`, so its source-store copy is
  directly runnable pre-redeploy — which is why the existing suite already drives new-check cases
  through `$VALIDATE_SRC`.
- **Deliverable 2 ("Name the corpus in the warning text")** — CONFIRMED still actionable and still
  four warning sites: `log_warn` calls live at lines 850, 855, 889, 892 (false-sentinel,
  fabricated-suite-list, under-verifies, fabricates-coverage). No site has been removed or
  converted to `log_error`.
- **"The record that owns the repo-level verification_scope declaration ... is a HARD
  prerequisite"** — CONFIRMED satisfied. `verification_scope_project_suite_roots` is live in the
  source store and deployed, and `specs/state.json` shows tasks 650 and 564 both `completed`, with
  652's own `dependencies` recorded as `[650, 564]`.

Two carried figures from the research report were found to have drifted and are corrected here:
the report's "Five existing cases" for the Tier-Justification fixture family is an undercount
(live: 13 `common_test_pass "TJ..."` assertions across 8 labeled case families), and the candidate
block is at lines 358-376 rather than the report's "~353-376" (line 353 begins its comment).
Neither drift changes the design.

## Goals & Non-Goals

**Goals**:
- Resolve the Tier-Justification scan's corpus through an ordered candidate list: the
  repository-under-validation's own declared project suite root(s) first, then today's single
  script-relative path as the fallback.
- Make every advisory Tier-Justification warning name the corpus it was measured against and
  where that corpus was resolved from.
- Emit one named, run-level warning when a declared root exists but resolves to no usable
  library, rather than falling back silently or failing hard.
- Leave a repository that declares nothing byte-for-byte unaffected.
- Cover the declared, undeclared, and declared-but-absent cases in
  `scripts/tests/test-validate-artifact.sh`.

**Non-Goals**:
- No change to `scripts/lib/suite-selection-lib.sh`. It remains the default backend, unmodified,
  and its `_SSL_`-prefixed internals are never read or written from the caller.
- No second declaration surface, resolver, or corpus-discovery engine. `verification_scope` is the
  declaration point and its existing reader is the only reader.
- No second repo-root resolution mechanism. The existing `_cgs_find_repo_root` /
  `_cgs_resolve_repo_root` pair is reused and its result computed once per run.
- No change to the scan's advisory posture or exit-code contract. It does not gain blocking power.
- No weakening or removal of the fabricated-claim detection, and no outcome in which a genuine
  finding is silenced rather than attributed.
- No reuse of `suite-resolver-lib.sh`'s resolver-command union/replace machinery, which composes
  resolution commands rather than selecting which corpus the one unchanged backend walks.
- No reclassification of `test-validate-artifact.sh` away from `integration` in
  `scripts/tests/suite-classification.data`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A declared root that is not shaped as a `lib/` + `tests/` mirror yields no candidate and silently falls through to the fallback corpus | M | H | Phase 2's one-time, run-level named warning covers exactly this case: the reader sees which declared root failed to resolve and which corpus is in use instead |
| Hoisting the repo-root computation is mis-implemented as a second independent call, leaving two walks that can disagree | M | M | Phase 1 moves the single assignment only and asserts afterward that exactly one `_cgs_repo_root=` assignment remains in the file; the function definitions are not moved |
| A new declared-root test case computes its expected suite names from the repository's own `SUITE_SELECTION_LIB` instead of the planted copy, recreating inside the test the exact bug this task fixes | H | M | Phase 3 requires the declared-root case to source the planted copy in a subshell for its expected-value computation and forbids reusing the suite-level `SUITE_SELECTION_LIB` variable there |
| Appending a corpus descriptor to the four existing `log_warn` lines is read as changing their contract and breaks existing assertions | M | L | Every existing TJ assertion matches only the substring `Tier Justification` via `grep -qF`/`grep -cF`; Phase 2 appends a suffix and re-runs the suite to confirm all 13 existing TJ assertions still pass |
| An untracked `agent-system/extensions/core/.claude-extensions.json` sits inside the source store, so an upward walk started from a source-store path would resolve it as a "repo root" | L | L | Not on this code path (the walk starts from the artifact's own directory, and artifacts live under `specs/`), but Phase 3's scratch fixtures must plant their own roots under the suite's `mktemp -d` workdir and never rely on an upward walk reaching the real repository root |
| The fail-soft source of `verification-scope-lib.sh` masks a genuinely broken library, leaving the feature inert with no signal | L | M | Phase 1 guards every use with `command -v verification_scope_project_suite_roots`; Phase 2's run-level warning fires whenever a declaration exists but no candidate resolves, which includes the reader-unavailable case |

## Decisions

- Re-root the corpus by sourcing a different on-disk copy of the unmodified
  `suite-selection-lib.sh`, selected through the script's existing ordered candidate list, rather
  than by adding a root-override parameter to the library or reaching into its `_SSL_` internals
  from the caller. This keeps the selection engine genuinely singular, at the cost of only working
  for a declared root laid out as a `lib/` + `tests/` mirror — acceptable because a non-mirrored
  root degrades to the existing fallback with a named warning.
- Reuse the already-computed `_cgs_repo_root` rather than adding a second
  `.claude-extensions.json` walk, which requires hoisting that one assignment ahead of the
  candidate-list block in file order.
- Source `verification-scope-lib.sh` fail-soft, following the `source-store-path-lib.sh`
  precedent, rather than with the loud `exit 5` idiom used for the three libraries this check
  cannot run without — `verification_scope` is an optional, fail-open surface and the whole check
  stays advisory.
- Carry two distinct warning shapes rather than collapsing them: a per-finding corpus-attribution
  suffix on each existing `log_warn` ("which corpus was THIS finding measured against?"), and a
  separate one-time run-level warning for a declared-but-unresolvable root ("did a declaration
  fail to resolve at all?").
- Record `validate-artifact.sh` as a consumer of `project_suite_roots` in
  `context/standards/repo-level-declarations.md`, and record the `lib/` + `tests/` mirror-shape
  expectation there, because that field's own schema text deliberately does not require any
  particular directory shape and a future declarer would otherwise have no way to know this
  consumer needs one.

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Resolve the Corpus Through an Ordered Candidate List [NOT STARTED]

**Goal**: The Tier-Justification scan sources its suite-selection backend from the
repository-under-validation's own declared project suite root when one is declared and resolvable,
falling back to today's single script-relative path otherwise, and records which corpus won for
the warning text Phase 2 adds.

**Tasks**:
- [ ] Re-derive the resolution site before editing. Confirm `_suite_selection_lib_candidates` is
      still a single-element array followed by the first-found-wins loop and the loud `exit 5`
      miss branch, and that this is still the only site in the script sourcing
      `suite-selection-lib.sh`. If either has moved, re-read the surrounding block rather than
      applying the edits below positionally.
- [ ] Hoist the single `_cgs_repo_root` assignment (`_cgs_repo_root="$(_cgs_resolve_repo_root
      "$(dirname "$artifact_path")")"`) to run before the candidate-list block. Move the
      assignment only: leave the `_cgs_find_repo_root` / `_cgs_resolve_repo_root` function
      definitions where they are, and leave the existing `coupled_generated_surfaces` consumer
      reading the same variable rather than recomputing it.
- [ ] Confirm after the move that exactly one `_cgs_repo_root=` assignment exists in the file and
      that the hoisted assignment precedes both consumers in file order.
- [ ] Add a fail-soft source of `verification-scope-lib.sh` from the fixed sibling path
      `"$_validate_script_dir/lib/verification-scope-lib.sh"`, following the
      `source-store-path-lib.sh` precedent (`2>/dev/null || true`). Do not use the loud `exit 5`
      idiom for it.
- [ ] Guard every use of the reader with `command -v verification_scope_project_suite_roots`, so a
      missing or broken library degrades to today's behaviour instead of aborting.
- [ ] For each line printed by `verification_scope_project_suite_roots "$_cgs_repo_root"`, in
      declared order, derive `"$_cgs_repo_root/$(dirname "$line")/lib/suite-selection-lib.sh"` and
      place it in `_suite_selection_lib_candidates` ahead of today's single
      `"$_validate_script_dir/lib/suite-selection-lib.sh"` entry. Leave the first-found-wins loop
      and the `exit 5` miss branch textually unchanged.
- [ ] Skip the derivation entirely when `_cgs_repo_root` is empty, the reader is unavailable, or
      the reader prints nothing, so an undeclared repository's candidate array is identical to
      today's single-element array.
- [ ] Record, where the winning candidate is chosen, the two values Phase 2 consumes: the winning
      candidate's own path, and a corpus kind distinguishing a declared project suite root (naming
      the declared root it was derived from) from the deployed/sibling fallback.
- [ ] Confirm no new `log_error` call, no new non-zero exit path, and no change to the pre-existing
      `exit 5` library-missing branch, so the scan's advisory posture and the script's exit-code
      contract are untouched (deliverable 3).

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `suite_selection_select agent-system/extensions/core/scripts/validate-artifact.sh` returns `test-gate-out-derived-staleness.sh test-gate-out-repair-reporting.sh test-orchestrate-cycle-postflight.sh test-run-all-selection.sh test-validate-artifact.sh`, so the covering check is `bash .claude/scripts/verify-touched.sh agent-system/extensions/core/scripts/validate-artifact.sh`.

**Scope Hypothesis**: This phase assumes the candidate-list block occupies lines 358-376 (array
358-360, loop 362-367, miss branch 368-374, source 376), that the single `_cgs_repo_root`
assignment sits at line 511, and that `validate-artifact.sh` is 1029 lines — all measured live at
plan authoring. Confirm each with `grep -n '_suite_selection_lib_candidates\|_cgs_repo_root='` on
the source-store copy before editing, and treat a mismatch as "re-read the block", never as
"apply the edit at the recorded line number".

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-artifact.sh` - hoist the `_cgs_repo_root` assignment; fail-soft source `verification-scope-lib.sh`; prepend declared-root-derived candidates to `_suite_selection_lib_candidates`; record the winning corpus path and kind

**Verification**:
- `bash agent-system/extensions/core/scripts/validate-artifact.sh specs/652_validate_artifact_corpus_resolution/plans/01_corpus-resolution-candidate-list.md plan` runs to completion and exits 0, exercising the edited source-store copy directly (the script sources no deploy-root guard, so this invocation is valid pre-redeploy).
- `bash .claude/scripts/verify-touched.sh agent-system/extensions/core/scripts/validate-artifact.sh` reports a green verdict over the five suites named in the Tier Justification above.
- `grep -c '_cgs_repo_root=' agent-system/extensions/core/scripts/validate-artifact.sh` returns exactly 1.
- Against this repository, which declares no `verification_scope` key in `.claude-extensions.json` (confirmed live at plan authoring), the script's output on a known plan fixture is unchanged from the pre-edit output captured before the first task above.

---

### Phase 2: Name the Corpus in Every Advisory Warning [NOT STARTED]

**Goal**: Every Tier-Justification advisory line states which corpus it was measured against and
where that corpus was resolved from, and a declared-but-unresolvable root draws one named
run-level warning instead of a silent fallback — with no finding silenced and no change to the
exit-code contract.

**Tasks**:
- [ ] Re-derive the four `log_warn` sites inside the Tier-Justification block (live at plan
      authoring: lines 850, 855, 889, 892 — the false-sentinel, fabricated-suite-list,
      under-verifies, and fabricates-coverage branches) before editing.
- [ ] Append a parenthesized corpus descriptor to each of those four messages, built from the two
      values Phase 1 recorded, in one consistent shape: the corpus kind, the declared root it came
      from when applicable, and the library path actually sourced.
- [ ] Keep every existing message's leading text, including the substring `Tier Justification`,
      byte-identical so the 13 existing TJ assertions (which match only on that substring via
      `grep -qF` / `grep -cF`) continue to pass.
- [ ] Add one run-level `log_warn`, emitted at most once per invocation and outside the per-phase
      loop, for the case where the reader printed at least one declared root but no derived
      candidate existed on disk: name the declared root(s) that failed to resolve and the fallback
      corpus now in use for every phase's measurement this run.
- [ ] Confirm the run-level warning does not fire for an undeclared repository, for a repository
      whose declared root resolved successfully, or when the reader is unavailable with nothing
      declared.
- [ ] Confirm no finding is suppressed, reworded away, or made conditional on corpus kind: the
      fabricated-claim and under-verification branches fire on exactly the same conditions as
      before, with only their message text extended.
- [ ] Confirm every addition uses `log_warn` and never `log_error`, so default-mode validation
      still exits 0 on a warning alone and `--strict` promotion continues to flow through the
      pre-existing `total_issues = errors + warnings` branch untouched.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `suite_selection_select agent-system/extensions/core/scripts/validate-artifact.sh` returns `test-gate-out-derived-staleness.sh test-gate-out-repair-reporting.sh test-orchestrate-cycle-postflight.sh test-run-all-selection.sh test-validate-artifact.sh`, so the covering check is `bash .claude/scripts/verify-touched.sh agent-system/extensions/core/scripts/validate-artifact.sh`.

**Scope Hypothesis**: This phase asserts there are exactly four `log_warn` sites inside the
Tier-Justification block and exactly 13 existing `common_test_pass "TJ..."` assertions in
`scripts/tests/test-validate-artifact.sh` — both measured live at plan authoring. Confirm with
`grep -n 'Tier Justification' agent-system/extensions/core/scripts/validate-artifact.sh` and
`grep -c 'common_test_pass "TJ' agent-system/extensions/core/scripts/tests/test-validate-artifact.sh`
before editing, and extend the task list to cover any additional site found rather than editing
only four.

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-artifact.sh` - append a corpus descriptor to each Tier-Justification `log_warn` message; add the one-time declared-but-unresolvable run-level warning

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` exits 0 with all pre-existing TJ assertions still passing, confirming the suffix append broke no existing fixture.
- A deliberately fabricated Tier-Justification fixture validated through the edited source-store copy emits a warning whose text names the corpus and the library path it was resolved from.
- `bash .claude/scripts/verify-touched.sh agent-system/extensions/core/scripts/validate-artifact.sh` reports a green verdict over the five suites named in the Tier Justification above.
- `grep -c 'log_error' agent-system/extensions/core/scripts/validate-artifact.sh` is unchanged from its pre-edit value.

---

### Phase 3: Cover the Declared, Undeclared, and Declared-but-Absent Cases [NOT STARTED]

**Goal**: `scripts/tests/test-validate-artifact.sh` pins all three resolution outcomes — a
declaring repository measured against its own corpus, an undeclared repository resolving exactly
as before, and a declared-but-absent root degrading to the fallback with one named warning — while
staying an `integration` suite.

**Tasks**:
- [ ] Add a scratch-root fixture builder alongside the existing `make_tj_fixture`, modelled on
      `test-verification-scope-lib.sh`'s `plant_scope` helper: it plants a root under the suite's
      existing `mktemp -d` workdir containing a `.claude-extensions.json` declaring
      `verification_scope.project_suite_roots`, and writes the plan fixture *inside* that root so
      `_cgs_resolve_repo_root` finds it by walking up from the artifact's own directory rather than
      falling through to `$(pwd)`.
- [ ] For the declared, resolvable case, plant a mirror-shaped corpus: a copy of
      `suite-selection-lib.sh` at `<root>/<proj>/scripts/lib/suite-selection-lib.sh` and at least
      one `test-*.sh` file at `<root>/<proj>/scripts/tests/`, with the declared root recorded as
      the repo-root-relative `<proj>/scripts/tests`. Confirm live, not by assumption, whether the
      planted tree also needs a minimal `tests/suite-classification.data` for
      `suite_selection_select` to answer, and plant one if so.
- [ ] Compute that case's expected suite name by sourcing the *planted* copy in a subshell. Do not
      reuse the suite-level `SUITE_SELECTION_LIB` variable for this computation: that variable
      deliberately points at the repository's own source-store sibling, and reusing it here would
      reproduce inside the test the very corpus mismatch this task fixes.
- [ ] Assert for that case that the Tier-Justification verdict matches the planted corpus's own
      resolution, and that the warning text names the declared root rather than the fallback.
- [ ] For the undeclared case, assert the existing `make_tj_fixture` cases' outcomes are unchanged
      — a regression guard that the new candidate derivation is inert when nothing is declared,
      not a new behaviour.
- [ ] For the declared-but-absent case, plant a `.claude-extensions.json` whose declared root
      derives a candidate library path that does not exist on disk. Assert (a) the
      Tier-Justification outcome matches the undeclared case exactly, and (b) exactly one
      additional warning appears naming the unresolvable declared root and the fallback corpus now
      in use — never a non-zero exit.
- [ ] Drive all three new cases through `$VALIDATE_SRC`, not `$VALIDATE`, matching the suite's own
      documented convention for a check that lives only in the source store until this plan's own
      redeploy phase lands it.
- [ ] Confirm `scripts/tests/suite-classification.data` still classifies
      `test-validate-artifact.sh` as `integration` and leave that row untouched: these are
      additions to an existing suite, not a new suite, and the suite must not be converted to a
      unit suite as a side effect.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `suite_selection_select agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` returns `test-run-all-selection.sh test-validate-artifact.sh`, so the covering check is `bash .claude/scripts/verify-touched.sh agent-system/extensions/core/scripts/tests/test-validate-artifact.sh`.

**Scope Hypothesis**: This phase assumes three new cases suffice for the three declared/undeclared/
declared-but-absent outcomes, that the suite is 1025 lines live, and that
`suite-classification.data` line 223 classifies it `integration` with
`invokes:deploy-headless.sh,verify-deploy.sh,run-all.sh` — all measured live at plan authoring.
Confirm the classification row before editing and split a case in two if a single fixture cannot
carry both of the declared-but-absent assertions cleanly.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` - add a scratch-root fixture builder and three cases covering declared-resolvable, undeclared, and declared-but-absent corpus resolution

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` exits 0 with the three new cases passing and every pre-existing case still passing.
- The declared-resolvable case fails as expected when its planted library copy is removed, confirming it genuinely measures against the planted corpus rather than coincidentally agreeing with the repository's own.
- `bash .claude/scripts/verify-touched.sh agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` reports a green verdict over the two suites named in the Tier Justification above.
- `grep -n 'test-validate-artifact.sh' agent-system/extensions/core/scripts/tests/suite-classification.data` still shows the `integration` classification, unmodified.

---

### Phase 4: Record validate-artifact.sh as a project_suite_roots Consumer [NOT STARTED]

**Goal**: `context/standards/repo-level-declarations.md` names `validate-artifact.sh` among
`project_suite_roots`' consumers and records the `lib/` + `tests/` mirror-shape expectation that
this consumer alone depends on, so a future declarer is not left to infer it from a schema line
that deliberately promises no particular directory shape.

**Tasks**:
- [ ] Confirm the correction target exists before editing: `context/standards/repo-level-declarations.md`
      is live at 303 lines with the "One object, one key" consumer list naming
      `scripts/verify-touched.sh`, `scripts/lib/suite-resolver-lib.sh`, and
      `scripts/report-suite-coverage.sh` (lines 137-141 at plan authoring). If that list has moved
      or already names `validate-artifact.sh`, re-read the section and amend only what is actually
      missing rather than appending a duplicate.
- [ ] Add `scripts/validate-artifact.sh` to that consumer list.
- [ ] Extend the `project_suite_roots` bullet with the mirror-shape note: this one consumer derives
      a sibling `lib/suite-selection-lib.sh` from the declared root's parent directory, so a
      declared root that is not shaped that way degrades to the deployed-tree fallback with a named
      warning — stated as the consumer's own requirement, never as a new constraint on the field's
      schema, which remains deliberately shape-agnostic for its other consumers.
- [ ] Keep the edit free of task-number references and of record-versioning language, per the
      repository rules that apply to everything landing under `agent-system/**`.
- [ ] Note that this edit moves this file's `line_count` in `index-entries.json`, whose Rule R
      check is advisory in this repository and is auto-repaired by `deploy-headless.sh`; the
      reconciliation is scheduled in Phase 5 rather than here, and the declaration below records
      the coupling.

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: prose

**Tier Justification**: `suite_selection_select agent-system/extensions/core/context/standards/repo-level-declarations.md agent-system/extensions/core/index-entries.json` returns `test-context-reachability.sh test-deploy-orphans.sh test-index-entries-schema.sh test-install-uninstall-extension.sh test-manifest-scripts-sync.sh test-roadmap-command-registration.sh`, so the covering check is `bash .claude/scripts/verify-touched.sh agent-system/extensions/core/context/standards/repo-level-declarations.md agent-system/extensions/core/index-entries.json`.

**Scope Hypothesis**: This phase asserts the file is 303 lines live and that
`index-entries.json` records `line_count: 303` for `standards/repo-level-declarations.md` — both
measured live at plan authoring, and the pair is currently consistent. Confirm with `wc -l` and a
`jq` read of that entry before editing, so the post-edit drift is a known delta rather than a
surprise.

**Files to modify**:
- `agent-system/extensions/core/context/standards/repo-level-declarations.md` - add `validate-artifact.sh` to the `project_suite_roots` consumer list and record the mirror-shape expectation
- `agent-system/extensions/core/index-entries.json` - declared as the coupled generated surface whose `line_count` for this file moves with the edit above; reconciled by Phase 5's regeneration

**Verification**:
- The consumer list in `context/standards/repo-level-declarations.md` names `validate-artifact.sh`, and the `project_suite_roots` bullet states the mirror-shape expectation and the degrade-to-fallback outcome.
- The diff read-through confirms every changed hunk lies in prose, with no executable or schema-example surface altered.
- `bash .claude/scripts/verify-touched.sh agent-system/extensions/core/context/standards/repo-level-declarations.md agent-system/extensions/core/index-entries.json` reports a green verdict over the six suites named in the Tier Justification above.
- No task-number reference and no record-versioning phrasing appears in the edited hunks.

---

### Phase 5: Redeploy and Close [NOT STARTED]

**Goal**: The edited source-store content is regenerated into the deployed tree, the coupled
`index-entries.json` line count is reconciled, and the full behaviour is confirmed from the
deployed vantage point.

**Tasks**:
- [ ] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh` to regenerate the deployed
      tree from the source store, which also auto-repairs the `index-entries.json` `line_count`
      drift Phase 4 introduced.
- [ ] Confirm the deployed `.claude/scripts/validate-artifact.sh` now carries the candidate-list
      and warning-text changes, and that the deployed
      `.claude/scripts/lib/verification-scope-lib.sh` sibling the script fail-soft sources is
      present.
- [ ] Re-run `bash .claude/scripts/tests/run-all.sh --only test-validate-artifact.sh` against the
      deployed tree so the suite exercises `$VALIDATE` (deploy-tree-first) as well as
      `$VALIDATE_SRC`, confirming the redeploy actually landed.
- [ ] Validate this plan artifact itself through the deployed script
      (`bash .claude/scripts/validate-artifact.sh specs/652_validate_artifact_corpus_resolution/plans/01_corpus-resolution-candidate-list.md plan`)
      and confirm the Tier-Justification advisory lines, if any fire, name the corpus they were
      measured against.
- [ ] Confirm `index-entries.json` reports no residual `line_count` drift for
      `standards/repo-level-declarations.md`.
- [ ] Run the scoped touched-path check over this task's own touched files and record, in this
      phase's verification notes, that the complete gate set is deferred to the orchestration close
      rather than independently run here.

**Timing**: 0.75 hours

**Depends on**: 3, 4

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`, an implicit scope claim over the entire deployed tree
- `agent-system/extensions/core/index-entries.json` - `line_count` reconciliation for the Phase 4 edit, performed as a side effect of regeneration

**Verification**:
- `bash agent-system/extensions/core/scripts/deploy-headless.sh` completes successfully and the deployed `.claude/scripts/validate-artifact.sh` differs from its pre-deploy state in exactly the regions Phases 1 and 2 edited.
- `bash .claude/scripts/tests/run-all.sh --only test-validate-artifact.sh` passes against the deployed tree.
- `bash .claude/scripts/verify-touched.sh agent-system/extensions/core/scripts/validate-artifact.sh agent-system/extensions/core/scripts/tests/test-validate-artifact.sh agent-system/extensions/core/context/standards/repo-level-declarations.md agent-system/extensions/core/index-entries.json` reports a green verdict — this is this phase's own in-dispatch scoped obligation.
- The complete gate set is explicitly deferred to the once-per-invocation orchestration close (`context/contracts/batch-gate-stage.md`), not run independently in this dispatch; this deferral is recorded in the phase's verification notes. Under a standalone, non-orchestrated run with no orchestration close to defer to, run `bash .claude/scripts/verify-deploy.sh` directly instead.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` exits 0 with the three new cases passing and all 13 pre-existing Tier-Justification assertions still passing.
- [ ] A declaring scratch repository's plan is measured against its own planted corpus, and the warning text names that declared root.
- [ ] An undeclared repository's output is unchanged from the pre-edit baseline captured in Phase 1.
- [ ] A declared-but-absent root draws exactly one additional named warning and no non-zero exit.
- [ ] `bash .claude/scripts/validate-artifact.sh <plan> plan` exits 0 in default mode on a warning-only run, confirming the advisory posture is intact.
- [ ] `bash .claude/scripts/tests/run-all.sh --only test-validate-artifact.sh` passes against the deployed tree after redeploy.
- [ ] `scripts/tests/suite-classification.data` still classifies `test-validate-artifact.sh` as `integration`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/validate-artifact.sh` - corpus resolution through an ordered candidate list; corpus-named advisory warnings; one-time declared-but-unresolvable warning
- `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` - scratch-root fixture builder and three new coverage cases
- `agent-system/extensions/core/context/standards/repo-level-declarations.md` - `validate-artifact.sh` recorded as a `project_suite_roots` consumer, with the mirror-shape expectation
- `agent-system/extensions/core/index-entries.json` - reconciled `line_count` for the edited standards file
- Regenerated deployed tree under `.claude/` (a disposable deploy artifact, not a committed deliverable)

## Rollback/Contingency

Each phase is a single-file edit with its own green commit, so the cheapest contingency is to
revert the offending phase's commit and redeploy. If an intentional rollback would discard
uncommitted work, take a snapshot first per `context/contracts/recovery.md`'s rollback rung, then
run the destructive command; use `git-snapshot.sh --no-revert` for an ordinary defensive
checkpoint before the Phase 5 regeneration, which touches the whole deployed tree. Because the
whole feature is gated on a declaration this repository does not carry, a partial landing is
inert here rather than harmful: if Phase 1 lands and Phase 2 does not, a declaring consumer
repository would be measured correctly but without attribution — recoverable by completing Phase
2, and never by reverting the corpus resolution and leaving the original defect in place.
