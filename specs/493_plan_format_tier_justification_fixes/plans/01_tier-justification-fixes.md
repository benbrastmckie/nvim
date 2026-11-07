# Implementation Plan: Task #493

- **Task**: 493 - Plan format Tier Justification fixes
- **Status**: [IMPLEMENTING]
- **Effort**: 3.8 hours
- **Dependencies**: None
- **Research Inputs**: specs/493_plan_format_tier_justification_fixes/reports/01_tier-justification-fixes.md
- **Artifacts**: plans/01_tier-justification-fixes.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two defects in the `**Tier Justification**:` block of
`agent-system/extensions/core/context/formats/plan-format.md` are repaired in place, then backed
by a mechanical check. Defect 1 is a one-line prose repair: the suite-subset narrowing mechanism
currently hardcodes a source-store-only entry point that cannot resolve in a deploy-target
repository, and is fixed by naming both forms and pointing at the dual-form,
resolve-whichever-exists convention the same file's "Batch-aware deferral" section already owns.
Defect 2 is a standards ruling plus its enforcement: a Tier Justification naming a suite subset
or the `__FULL_SWEEP__` sentinel must quote the actual output of `suite_selection_select` over the
phase's touched paths, and that obligation lands as a new advisory-first check inside
`scripts/validate-artifact.sh`'s existing `plan` branch (which the existing
`hooks/validate-plan-write.sh` PostToolUse hook already invokes on every plan write, so no new
gate or hook wiring is needed), with a fixture pair proving a fabricated claim fails and a
measured one passes. The source store is the edit target throughout; the deployed tree is
regenerated in the final phase.

### Research Integration

The research report's two rulings are adopted unchanged: fix line 339 **by reference**, and
enforce the measurement obligation **mechanically** rather than by prose alone. Three of its
measurements are load-bearing here and were independently re-confirmed while composing this plan:

- `suite_selection_select specs/ROADMAP.md` returns `test-engine-written-state-paths-lib.sh` and
  `test-roadmap-generation.sh` — two real covering suites, not the `__FULL_SWEEP__` sentinel a
  prior plan asserted for that path. This is defect 2's evidence, and it is why the lint must
  police sentinel claims in **both** directions, not only fabricated suite names.
- The selector costs ~50ms and performs no build, no test execution, and no filesystem mutation.
  This is the fact that settles the dispatch's "weigh honestly" framing: a measurement
  requirement does not inherit a `full` gate's cost; it costs about what a grep costs.
- `scripts/validate-artifact.sh`'s `plan` branch already implements the advisory-first rollout
  pattern (warn by default, `--strict` escalates, with a recorded promotion criterion) twice
  over — for `**Verification Tier**:` presence and for `Files to modify` presence. The new check
  is a third instance of that same pattern, not a new enforcement posture.

**One correction to the research report's recommendation 3**, adopted deliberately: the report
proposes collecting a phase's touched paths from its steps' `**Files:**` bullets, with the task's
`file_scope` as fallback. The structured carrier for a phase's file list is
`**Files to modify**:`, not `**Files:**` — plan-format.md's own "Consumers of this field"
subsection states this, and `plan-file-scope-harvest.sh` reads only that field. The lint
therefore reads `**Files to modify**:` and reuses the harvester's existing grammar rather than
introducing a third parse of a different field (see Phase 3, Decision D2).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no `roadmap_flag` was set, so no roadmap
consultation was performed and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- `plan-format.md` line 339 names a suite-subset entry point that resolves in a deploy-target
  repository *and* in the source-store repository, governed by the dual-form convention the
  "Batch-aware deferral" section already states, referenced rather than restated.
- A grep of `plan-format.md` for the bare `agent-system/extensions/core/scripts/tests/run-all.sh`
  path returns only occurrences explicitly paired with the deploy form or explicitly labelled as
  the source-store-repository form.
- The measurement ruling is recorded in `plan-format.md` with its reasoning, stating explicitly
  that a lint was added and why a prose-only requirement was rejected.
- A new advisory-first check in `scripts/validate-artifact.sh` re-runs `suite_selection_select`
  over a non-final phase's touched paths and reports a mismatch against the phase's
  `**Tier Justification**:` claim.
- Fixtures in `scripts/tests/test-validate-artifact.sh` prove a fabricated selector result fails
  under `--strict` and a measured one passes.
- The deployed `.claude/` tree is regenerated so consumer repositories receive the fix.

**Non-Goals**:
- Changing the tier taxonomy, the final-phase `full` invariant, or the rule that the final phase
  carries no justification line.
- Weakening or removing the `__FULL_SWEEP__` documentation — it is correct and is what made
  defect 2 diagnosable.
- Copying the dual-form convention into a second location. The "Batch-aware deferral" section
  stays the single statement of that rule.
- Extending the lint to the gate-subset mechanism (`--only-gate N[,M,...]`). That mechanism is
  not grounded in `suite_selection_select` and neither filed defect implicates it; covering it
  would be inventing a third defect nobody measured.
- Promoting any of `validate-artifact.sh`'s existing advisory checks (`Verification Tier`
  presence, `Files to modify` presence) to errors. Their promotion criteria are unmet and
  out of scope.
- Updating `context/workflows/task-breakdown.md`'s worked examples or `agents/planner-agent.md`'s
  Tier Justification bullets. Both reference `plan-format.md` as the authority rather than
  restating the field spec, so the new obligation reaches them by reference. Recorded as a
  follow-up to re-check after deploy, not as work here.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The lint mis-parses a well-formed Tier Justification sentence and warns on an unrelated plan | M | M | Ship advisory-first (warn, not fail, outside `--strict`), exactly as the two existing `plan`-branch checks were rolled out; sweep the active-plan corpus in Phase 4 and record the measured residue in the enforcement-level subsection |
| A phase's `Files to modify` block carries a reserved sentinel (`__WHOLE_TREE__`) or a non-path placeholder (`- none planned ...`), which the selector would treat as unmapped and short-circuit to `__FULL_SWEEP__` for the whole phase | M | H | Decision D3: drop reserved sentinels and non-path entries before calling the selector, and skip the check entirely for a phase whose remaining path set is empty |
| Reusing `plan-file-scope-harvest.sh` on a single phase block does not work as expected (it is a whole-plan tool) | M | M | Phase 3 confirms this against a real phase block before building on it; the fallback is to call the harvester's `extract_paths()` awk grammar directly rather than to duplicate it |
| Concurrent sibling task 408 declares `__WHOLE_TREE__` in its own `file_scope`, and this plan's final phase does too | M | M | Serialize: the redeploy phase must not run while a sibling whole-tree regeneration is in flight; re-read every target file immediately before editing and stage only this task's own hunks |
| Open tasks 459, 328, 360, 385 and 420 carry mechanical overlap on `plan-format.md` | M | M | None of them addresses either defect; if any is dispatched concurrently the shared file is sequenced, never edited in parallel — re-read `plan-format.md` immediately before each edit |
| Line numbers cited in this plan (339, 420-429, 490, 502) drift if a sibling edits `plan-format.md` first | L | M | Every phase locates its edit target by anchor text, never by line number; the numbers here are navigational aids only |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |

Phases within the same wave can execute in parallel. This plan is a strict chain: phases 1 and 2
edit the same file and the same subsection, phase 3 enforces the contract phase 2 writes, phase 4
tests phase 3, and phase 5 deploys all of it.

### Phase 1: Repair the suite-subset entry point by reference [COMPLETED]

**Goal**: Line 339's suite-subset bullet names a form that resolves in both repository shapes,
under the convention the "Batch-aware deferral" section already states.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/context/formats/plan-format.md` immediately before
      editing (concurrent siblings may have touched it), locating the bullet by its anchor text
      `a suite subset within Gate 8:` rather than by line number. *(completed)*
- [x] Rewrite that bullet so the deploy form `bash .claude/scripts/tests/run-all.sh --only SUITE[,SUITE,...]`
      is named first, the source-store form
      `bash agent-system/extensions/core/scripts/tests/run-all.sh --only SUITE[,SUITE,...]` is
      named second and explicitly labelled as the form for the agent-system source-store
      repository, and the choice between them is delegated to the "Batch-aware deferral"
      section's resolve-whichever-exists rule **by name** — one short pointer clause, no restated
      copy of that rule. *(completed)*
- [x] Keep the bullet's existing `suite_selection_select` pointer and its
      `context/standards/shell-script-testing.md` cross-reference intact; this edit changes the
      command form only. *(completed)*
- [x] Verify the acceptance grep: every occurrence of the bare
      `agent-system/extensions/core/scripts/tests/run-all.sh` path in the file is either paired
      with the deploy form or explicitly labelled as the source-store form. *(completed)*

**Timing**: 0.4 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `suite_selection_select agent-system/extensions/core/context/formats/plan-format.md`
measured this dispatch returns `test-lean-challenge-snapshot.sh test-phase-heading-patterns.sh
test-plan-file-scope-harvest.sh test-resume-scan-nonconformance.sh` (not the `__FULL_SWEEP__`
sentinel), so the covering check is `bash .claude/scripts/tests/run-all.sh --only test-lean-challenge-snapshot.sh,test-phase-heading-patterns.sh,test-plan-file-scope-harvest.sh,test-resume-scan-nonconformance.sh`
plus the acceptance grep below.

**Files to modify**:
- `agent-system/extensions/core/context/formats/plan-format.md` - rewrite the suite-subset
  narrowing bullet to name both forms and reference the existing dual-form convention

**Verification**:
- `grep -n "run-all.sh" agent-system/extensions/core/context/formats/plan-format.md` shows the
  repaired bullet naming the deploy form, and every bare source-store occurrence paired or
  labelled.
- `bash .claude/scripts/tests/run-all.sh --only test-lean-challenge-snapshot.sh,test-phase-heading-patterns.sh,test-plan-file-scope-harvest.sh,test-resume-scan-nonconformance.sh`
  passes (the measured covering subset for this path).
- Diff read-through confirms the "Batch-aware deferral" section itself is byte-unchanged — the
  convention is referenced, not copied.

---

### Phase 2: Record the measurement ruling in the standard [NOT STARTED]

**Goal**: `plan-format.md` states the measurement obligation for a Tier Justification naming a
suite subset or the `__FULL_SWEEP__` sentinel, and records the ruling that it is enforced
mechanically rather than by prose alone, with its reasoning.

**Tasks**:
- [ ] Re-read `plan-format.md` immediately before editing.
- [ ] In the `**Tier Justification**:` subsection, add the measurement obligation to the bullet
      governing a non-final phase declaring a tier below `full`: a justification naming a suite
      subset or invoking `__FULL_SWEEP__` is honest only if the author ran
      `suite_selection_select` over the phase's `Files to modify` paths and the line's claim
      matches that output. State the requirement in the subsection's existing one-sentence idiom;
      do not expand it into a procedure.
- [ ] Extend the `__FULL_SWEEP__` paragraph with the measurement obligation's sentinel half only
      — that claiming the sentinel is itself a measurable claim — without altering, weakening, or
      reordering the three existing sub-cases (a), (b), (c), which stay exactly as written.
- [ ] Add a new `### Enforcement level (Tier Justification measurement)` subsection after the
      existing `### Enforcement level (Files to modify)` subsection, modelled on it: name
      `scripts/validate-artifact.sh` as the enforcing consumer, state the advisory-first posture
      (warn by default, `--strict` enforces), record the promotion criterion, and record the
      ruling itself — that a mechanical lint was chosen over a prose-only requirement because the
      filed defect is precisely the failure a prose-only rule cannot prevent (an author asserted
      the selector's output without running it, and the assertion was false), while the
      re-derivation costs about what a grep costs rather than what a gate run costs.
- [ ] State in the same subsection that the check's scope is bounded to
      `suite_selection_select`-grounded claims and explicitly does not extend to the
      `--only-gate N[,M,...]` gate-subset mechanism.
- [ ] Confirm no task-number references and no record-versioning language entered the file.

**Timing**: 0.6 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: Same measured selector output as Phase 1 for the one file this phase
touches (`test-lean-challenge-snapshot.sh test-phase-heading-patterns.sh
test-plan-file-scope-harvest.sh test-resume-scan-nonconformance.sh`), so the covering check is
that same `run-all.sh --only` subset plus gates 3 and 4 for the prose itself.

**Files to modify**:
- `agent-system/extensions/core/context/formats/plan-format.md` - add the measurement obligation
  to the Tier Justification subsection and the new enforcement-level subsection recording the
  ruling

**Verification**:
- The tier table, the final-phase definition, the final-phase `full` invariant, the
  no-justification-on-final-phase rule, and the three `__FULL_SWEEP__` sub-cases are unchanged in
  the diff.
- `bash .claude/scripts/validate-artifact.sh` is not applicable to this file; instead
  `bash <repo_root>/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 <repo_root>`
  passes (doc-lint and task-reference lint, run with the source-store repository's own root as
  `TARGET` per the sub-case (b) requirement this file itself documents).
- `bash .claude/scripts/tests/run-all.sh --only test-lean-challenge-snapshot.sh,test-phase-heading-patterns.sh,test-plan-file-scope-harvest.sh,test-resume-scan-nonconformance.sh`
  passes.

---

### Phase 3: Implement the measurement lint in validate-artifact.sh [NOT STARTED]

**Goal**: `scripts/validate-artifact.sh`'s `plan` branch re-derives the covering suites for each
non-final phase's touched paths and reports a mismatch against that phase's
`**Tier Justification**:` claim, advisory by default and enforced under `--strict`.

**Tasks**:
- [ ] Confirm the phase-block path-extraction mechanism before building on it (see Scope
      Hypothesis): write one real phase block to a temp file, run
      `bash scripts/plan-file-scope-harvest.sh` on it, and confirm it emits that phase's
      `Files to modify` paths as a JSON array. If it does not, call the harvester's
      `extract_paths()` awk grammar directly instead — never duplicate the grammar in this script.
- [ ] Source `scripts/lib/suite-selection-lib.sh` using the `${BASH_SOURCE[0]}`-relative
      `$_validate_script_dir/lib/...` resolution this script already uses for
      `phase-heading-patterns.sh` and `plan-status-line.sh`, so it resolves in both the source
      store and the deployed tree. Treat a missing library as an environment error consistent
      with how the two existing libraries are handled, never as a silent skip.
- [ ] Inside the existing per-phase loop (which already computes `phase_block` and `phase_num`),
      extract the phase's `**Tier Justification**:` line, accepting both punctuation conventions
      (`**Tier Justification**:` and `**Tier Justification:**`) exactly as the
      `**Verification Tier**` extraction above it already does.
- [ ] Parse the claim from that line: either a `--only SUITE[,SUITE,...]` suite list, or a
      mention of the `__FULL_SWEEP__` sentinel. A line naming neither is out of this check's
      scope and is passed over silently (it is the `full`-tier or cross-cutting-surface shape,
      which this check does not police).
- [ ] Collect the phase's touched paths, dropping reserved sentinels (`__WHOLE_TREE__`) and
      non-path placeholder entries (Decision D3). If the remaining set is empty, skip the check
      for that phase without emitting anything.
- [ ] Call `suite_selection_select` on the remaining paths and compare (Decision D4): a
      sentinel claim requires the selector to return exactly `__FULL_SWEEP__`; a suite-list claim
      requires set equality after `sort -u`, with distinct messages for the two failure
      directions — a covering suite the selector returns but the line omits (under-verification)
      and a suite the line names but the selector does not return (fabrication).
- [ ] Emit via `log_warn` so default mode stays advisory and the existing
      `total_issues=$((errors + warnings))` `--strict` branch enforces it, with no change to the
      summary block.
- [ ] Skip the final phase (the highest-numbered phase), which carries no justification line by
      standard; its absence must never warn.
- [ ] Write the check's own header comment recording the path-source precedence, the sentinel and
      placeholder exclusions, the comparison semantics, and the bounded scope (no `--only-gate`
      coverage), mirroring the comment style the two neighbouring checks use.
- [ ] Confirm the new code is safe under the script's `set -euo pipefail` posture — the library
      sets no shell options and never calls `exit`, per its own header contract.

**Timing**: 1.3 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `suite_selection_select agent-system/extensions/core/scripts/validate-artifact.sh`
measured this dispatch returns `test-gate-out-derived-staleness.sh
test-gate-out-repair-reporting.sh test-orchestrate-cycle-postflight.sh
test-validate-artifact.sh` (not the sentinel), so the covering check is
`bash .claude/scripts/tests/run-all.sh --only test-gate-out-derived-staleness.sh,test-gate-out-repair-reporting.sh,test-orchestrate-cycle-postflight.sh,test-validate-artifact.sh`
plus `shellcheck` on the edited script.

**Scope Hypothesis**: `plan-file-scope-harvest.sh` run against a single phase block written to a
temp file is expected to emit exactly that phase's `Files to modify` paths, letting the lint reuse
the harvester's `strip_marker()`/`extract_paths()` grammar verbatim instead of duplicating it. The
implementer confirms this with a real phase block as the phase's first step and falls back to
calling `extract_paths()` directly if the whole-file tool proves unusable on a fragment.

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-artifact.sh` - add the Tier Justification
  measurement check inside the existing `plan`-branch per-phase loop, plus the
  `suite-selection-lib.sh` sourcing

**Verification**:
- `bash -n agent-system/extensions/core/scripts/validate-artifact.sh` parses, and `shellcheck`
  reports no new findings on the edited script (exit status checked, not only a stdout diff).
- Running the validator against this plan file itself (`validate-artifact.sh <this plan> plan`)
  exits 0 and reports no Tier Justification mismatch — this plan's own justifications quote
  measured selector output, so it is the first live positive fixture.
- A hand-edited copy of this plan file with one suite name corrupted produces exactly one
  mismatch warning in default mode and a non-zero exit under `--strict`.
- `bash .claude/scripts/tests/run-all.sh --only test-gate-out-derived-staleness.sh,test-gate-out-repair-reporting.sh,test-orchestrate-cycle-postflight.sh,test-validate-artifact.sh`
  passes (pre-existing suites still green before the new fixtures land in Phase 4).

---

### Phase 4: Fixture pair and corpus sweep [NOT STARTED]

**Goal**: `scripts/tests/test-validate-artifact.sh` proves a Tier Justification carrying a
fabricated selector result fails and one carrying the measured result passes, and the measured
warning residue across the active-plan corpus is recorded.

**Tasks**:
- [ ] Add a fixture builder for a two-phase plan whose non-final phase carries a
      `**Files to modify**` entry with a known selector resolution and a parameterizable
      `**Tier Justification**:` line, following `make_two_phase_ftm_fixture()`'s existing shape
      and the file's `mktemp --tmpdir="$WORKDIR"` convention.
- [ ] Add the negative fixture: a justification naming a suite list that does not match the
      selector's output for the fixture's touched path. Assert one mismatch warning in default
      mode and a non-zero exit under `--strict`.
- [ ] Add the positive fixture: a justification naming the actual measured output for the same
      path. Assert no mismatch warning and exit 0.
- [ ] Add a sentinel-direction fixture pair covering defect 2's own shape: a justification
      claiming `__FULL_SWEEP__` for a path the selector actually maps to real suites (must warn),
      and one claiming the sentinel for a genuinely unmapped path (must pass).
- [ ] Add a skip-case fixture: a phase whose `Files to modify` block holds only `__WHOLE_TREE__`
      or a `- none planned ...` placeholder must produce no mismatch warning at all.
- [ ] Sweep the active-plan corpus: run the validator in default mode over every non-terminal
      plan under `specs/` and count the plans and phases the new check warns on. Record that
      measured residue in the Phase 2 enforcement-level subsection as its promotion criterion's
      baseline, re-reading `plan-format.md` immediately before that edit.
- [ ] Confirm the suite's own `PASSED`/`FAILED` counters and exit contract are unchanged.

**Timing**: 0.9 hours

**Depends on**: 3

**Verification Tier**: local

**Tier Justification**: `suite_selection_select agent-system/extensions/core/scripts/tests/test-validate-artifact.sh`
measured this dispatch returns exactly `test-validate-artifact.sh` (not the sentinel), so the
covering check is `bash .claude/scripts/tests/run-all.sh --only test-validate-artifact.sh`; the
corpus-sweep residue edit to `plan-format.md` is additionally covered by that file's own measured
subset named in Phase 2.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` - add the fixture
  builders and the positive/negative/sentinel/skip-case assertions
- `agent-system/extensions/core/context/formats/plan-format.md` - record the measured warning
  residue as the new check's promotion-criterion baseline

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` exits 0 with the
  new assertions counted in `PASSED` and `FAILED` at 0.
- The negative fixture demonstrably fails under `--strict` and the positive one passes — the
  task's own acceptance criterion, shown by the assertion output rather than asserted.
- `bash .claude/scripts/tests/run-all.sh --only test-validate-artifact.sh` passes.
- The corpus sweep's measured counts appear in `plan-format.md`'s new enforcement-level
  subsection.

---

### Phase 5: Redeploy and full gate battery [NOT STARTED]

**Goal**: The repaired standard and its enforcement reach the deployed `.claude/` tree, and the
complete gate set is observed green.

**Tasks**:
- [ ] Confirm no sibling whole-tree regeneration is in flight before regenerating (concurrent
      sibling task 408 declares `__WHOLE_TREE__` in its own scope). If one is, wait and re-check
      rather than regenerating concurrently.
- [ ] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh` to regenerate the
      deployed tree from the source store.
- [ ] Confirm the deployed copies carry the change:
      `.claude/context/formats/plan-format.md`, `.claude/scripts/validate-artifact.sh`, and
      `.claude/scripts/tests/test-validate-artifact.sh` all reflect the source-store edits.
- [ ] Re-run the acceptance grep against the deployed copy of `plan-format.md` as well as the
      source-store copy.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (every gate it
      aggregates, not a hand-picked subset), checking its exit status.
- [ ] Record any issue or win encountered during this dispatch chain via
      `bash .claude/scripts/issue-record.sh`, non-fatally.

**Timing**: 0.6 hours

**Depends on**: 1, 2, 3, 4

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed `.claude/` tree. This
  reserved sentinel is the whole declaration for this phase: the individual regenerated deploy
  paths are deliberately NOT listed, because they are disposable deploy artifacts this phase
  never hand-authors, and naming them in `file_scope` would both duplicate what the sentinel
  already covers and misrepresent `.claude/**` files as edit targets.

**Verification**:
- `bash agent-system/extensions/core/scripts/deploy-headless.sh` exits 0.
- `bash .claude/scripts/verify-deploy.sh` — the complete gate set, with its exit status checked —
  passes.
- `grep -n "run-all.sh" .claude/context/formats/plan-format.md` shows the repaired bullet in the
  deployed tree, confirming a consumer repository will receive a resolvable entry point.
- `bash .claude/scripts/tests/test-validate-artifact.sh` passes from the deployed tree.

## Testing & Validation

- [ ] Every bare `agent-system/extensions/core/scripts/tests/run-all.sh` occurrence in
      `plan-format.md` is paired with the deploy form or explicitly labelled as the source-store
      form (acceptance criterion 1 and 2).
- [ ] The measurement ruling, including why a lint was chosen over prose, is present in
      `plan-format.md` (acceptance criterion 3).
- [ ] A fixture with a fabricated selector result fails and one with the measured result passes
      (acceptance criterion 4).
- [ ] The tier taxonomy, final-phase `full` invariant, no-justification-on-final-phase rule, and
      `__FULL_SWEEP__` documentation are unchanged (hard constraints).
- [ ] The "Batch-aware deferral" section is byte-unchanged — referenced, never copied (hard
      constraint).
- [ ] `bash agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` passes.
- [ ] `bash .claude/scripts/verify-deploy.sh` passes after redeploy.
- [ ] No task-number references and no record-versioning language in any file landing under
      `agent-system/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/context/formats/plan-format.md` — repaired entry point, the
  measurement obligation, and the new enforcement-level subsection.
- `agent-system/extensions/core/scripts/validate-artifact.sh` — the Tier Justification
  measurement check.
- `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` — the fixture pair plus
  sentinel and skip-case coverage.
- A regenerated deployed `.claude/` tree.
- `specs/493_plan_format_tier_justification_fixes/summaries/01_tier-justification-fixes-summary.md`
  at implementation terminus.

## Rollback/Contingency

Every edit is confined to three source-store files plus a regenerable deploy tree. To revert,
restore the three files from `HEAD` (targeted, explicit-file-list checkout only, after a
`bash .claude/scripts/git-snapshot.sh 493` if the tree is dirty) and re-run
`deploy-headless.sh` to regenerate the deployed tree from the restored source store. The lint is
advisory by default, so an unexpectedly noisy check can be neutralized by reverting Phase 3 alone
while keeping Phases 1 and 2's prose repairs, which have no runtime effect. Phase 5's redeploy is
idempotent and can be re-run at any time.
