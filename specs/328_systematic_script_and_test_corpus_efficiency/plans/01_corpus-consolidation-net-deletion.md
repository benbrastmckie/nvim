# Implementation Plan: Task #328

- **Task**: 328 - Systematic top-to-bottom consolidation of the shell script and test corpus under `agent-system/extensions/**`
- **Status**: [NOT STARTED]
- **Effort**: 26 hours
- **Dependencies**: None live. Tasks 170 and 411 are both `completed` in `specs/state.json` (verified at plan time); task 416 is `implementing` at 10/13 phases and is a *coordination* surface, not a dependency — see "The 416 Overlap" below.
- **Research Inputs**: `specs/328_systematic_script_and_test_corpus_efficiency/reports/01_corpus-consolidation-research.md`
- **Artifacts**: plans/01_corpus-consolidation-net-deletion.md (this file)
- **Standards**:
  - `.claude/context/formats/plan-format.md`
  - `.claude/context/standards/status-markers.md`
  - `.claude/context/standards/artifact-management.md`
  - `.claude/context/standards/tasks.md`
  - `.claude/rules/source-store-deploy-boundary.md`
  - `.claude/rules/no-task-references-in-deliverables.md`
  - `.claude/rules/no-record-versioning-in-deliverables.md`
- **Type**: meta
- **Lean Intent**: false

## Overview

This task is the standing consumer of `scripts/script-inventory.sh`'s ranked output, chartered to
produce a **measured net reduction** in the shell-script and test corpus under
`agent-system/extensions/**` — not a speedup, and not a count of refactors performed. The plan
lands a cheap standing corpus-size probe first so every later phase's net figure is measured by
one instrument, derives each cluster's extractable volume mechanically before committing to a
target, then works the clusters in extract-a-lib order: the seven-script lint cluster, the
118-plus-suite test harness (the largest single target by volume), the two mutual pairs, and
`literature-search.sh`'s self-internal repetition. Definition of done: the full gate set is green,
every gate's finding set and every suite's assertion set is provably unchanged, and the two
running net figures (production-script lines, test-script lines) are both negative against the
Phase 1 baseline.

**The edit target is the source store**, `agent-system/extensions/**`, never `.claude/**` (a
disposable deploy artifact regenerated from the source store — see
`rules/source-store-deploy-boundary.md`). Phase 15 redeploys via `deploy-headless.sh`.

### Research Integration

The research report changes four things about how this plan is built, and each is load-bearing:

1. **Both declared blockers are discharged.** 170 and 411 are `completed`. The dispatch's "170
   blocks only the untested-script phases" framing is resolved context, not a live constraint. No
   phase below waits on a dependency.
2. **The five-lint cluster is mechanically a seven-script cluster.** Each of the five named lints
   lists **six** `duplicate_block_peers`, adding `lint-hook-registration-paths.sh` (614L) and
   `lint-shellcheck.sh` (296L). This plan scopes the first slice to all seven, per the research's
   own Decisions section.
3. **A plan-time correction to the research**: the report flagged those two extra members as
   `has_test=false`, which would have required characterization tests first. Hand-checked at plan
   time, **both have paired fixture suites** (`tests/test-lint-hook-registration-paths.sh`, 603
   lines; `tests/test-lint-shellcheck.sh`, 212 lines). The false negative is
   `script-inventory.sh`'s own documented `has_test` caveat: it resolves `tests/test-<basename>`
   relative to the candidate's own directory (`scripts/lint/tests/`), while the real suites live
   in `scripts/tests/`. All seven cluster members are already fixture-tested, so the whole first
   slice carries no characterization-test prerequisite.
4. **GAP 2 is substantially stale and GAP 3 is half-closed** by work already landed elsewhere.
   This plan does not re-target either; see "The 416 Overlap" and "Goals & Non-Goals".

### Prior Plan Reference

No prior plan. This is the task's first plan round.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context and no roadmap consultation
was performed.

### The 416 Overlap — Resolved Deliberately

The dispatch instructs that the overlap with the gate-cost-model task be resolved by absorbing,
superseding, or depending on its parked phases explicitly, rather than doing the work twice.
Re-checked at plan time: task 416 is `status: implementing` with phases 1-10 `[COMPLETED]` and
phases 11, 12, 13 `[NOT STARTED]`.

| 416 phase | State | This plan's disposition |
|-----------|-------|-------------------------|
| 1 Harden `measure-gate-costs.sh` | [COMPLETED] | **Adopt as baseline.** Satisfies the dispatch's measurement-discipline prerequisite; this plan does not re-harden it. |
| 6 Fixture-corpus shellcheck + hint coverage | [COMPLETED] | **Adopt as baseline.** |
| 8 Cut the two verify-deploy stragglers | [COMPLETED] | **Adopt as baseline, do not re-target.** Those two suites' costs fell 87% and 77%; the dispatch's 228,595ms / 160,340ms figures are superseded. |
| 10 Re-derive `JOBS_CAP` | [COMPLETED] | **Adopt as baseline.** The 1,016.6s pool figure in the dispatch is superseded by a 1,402.17s pool. |
| 11 Gate 3 post-invalidation measurement | [NOT STARTED] | **Leave to 416.** Out of scope here; this plan touches no gate-3 measurement decision. |
| 12 Gate 8 serialized isolation | [NOT STARTED] | **Leave to 416.** |
| 13 Redeploy + measured before/after | [NOT STARTED] | **Leave to 416.** This plan's own Phase 15 redeploy is independent and scoped to this task's own edits. |

**Standing coordination obligation**: Phases 12, 13 and 14 touch `tests/run-all.sh`,
`suite-cost-hints.txt`, `measure-gate-costs.sh`, or `context/standards/shell-script-testing.md` —
files 416 owns. Each of those phases opens by re-reading 416's live phase states (its plan file's
`### Phase` headings) and stops rather than editing if 416 has advanced into the same file since
this plan was written.

### Measurement Discipline

Every timing figure this task takes or reports must come from a verified-quiet host. Check the
1-, 5- **and** 15-minute load averages (not only the 1-minute figure that
`measure-gate-costs.sh` samples at start) and require all three under 2 before any timing run.
Structural counts (file counts, line counts, duplicate-block counts) are load-independent and
need no such gate. A timing run whose two repetitions disagree by more than 25% is discarded, not
averaged — the recorded incident of a 404s-vs-193s disagreement under unrelated sibling-build
contention is indistinguishable from a real regression.

### Running Net Figures — Two Populations, Never Blended

Progress is reported as two separate running net figures (insertions minus deletions), never one
blended total, because a lib extraction predictably shows a transient net-positive in one
population before migrations bring the other down, and blending would hide exactly the tradeoff
the acceptance criterion exists to expose:

| Figure | Population | Phase 1 baseline | Target |
|--------|------------|------------------|--------|
| NET-PROD | non-test `*.sh` under `agent-system/extensions/**` | captured in Phase 1 | declared in Phase 2 |
| NET-TEST | `test-*.sh` under `agent-system/extensions/**` | captured in Phase 1 | declared in Phase 2 |

Every phase below closes by recording its own delta against both figures. **A phase whose net is
positive must state, in its own closing note, why it is the cheapest available route to a later
negative net — or be reverted.** Phases 1, 2, 4, 12 and 14 are net-positive by construction and
each carries that statement in advance below.

### Plan-Time Measurements (re-derived, 2026-10-16)

Re-derived at plan-authoring time rather than carried from the dispatch or the report, both of
which the report itself shows drifting within a day:

```
non-test *.sh under agent-system/extensions/**:   237 files    91,802 lines
test-*.sh under agent-system/extensions/**:       155 files
core suites (extensions/core/scripts/tests/):     121 files    60,852 lines
markdown under agent-system/extensions/**:        943 files
gate-registry.data rows:                           23
```

Harness duplication across the 121 core suites, counted directly:

```
suites defining their own pass():                 121 / 121
suites defining their own fail():                 121 / 121
suites redefining mktemp -d + trap cleanup:       115 / 121
suites open-coding SCRIPT_DIR resolution:         121 / 121
suites open-coding git rev-parse --show-toplevel:  64 / 121
suites redefining resolve_candidate():             22 / 121
suites sourcing ANY shared test harness:            0 / 121
```

Seven-script lint cluster, and the comment/blank share that bounds what extraction can reach:

```
lint-scoped-commit-boundary.sh       668 lines  (338 code, 330 comment/blank)
lint-task-lookup-adoption.sh         592 lines
lint-hook-registration-paths.sh      614 lines  (352 code, 262 comment/blank)
lint-branch-gated-sections.sh        398 lines
lint-directory-pathspec-boundary.sh  381 lines
lint-state-writer-boundary.sh        369 lines
lint-shellcheck.sh                   296 lines
                                   -----
                                   3,318 lines
```

Six of the seven carry the shared corpus-enumeration call-site block
(`lint-branch-gated-sections.sh` does not; it is a duplicate-block peer through the wider
skeleton — argument parsing, `SCAN_PATHS` collection, `VIOLATIONS` accounting, exit-code
convention — which all seven share). All seven already source `lib/common.sh`, and the helpers
themselves (`common_shared_corpus_available`, `common_shared_corpus_files`) are already correctly
defined once there. What remains duplicated is the call-site wrapper and the surrounding
skeleton, not the helpers.

### The Target Gap — Raised as a User Decision

The dispatch recommends a net-deletion floor of **-10,000 non-test lines**. The figures above
bound what the clusters the dispatch itself enumerates can actually yield well below that: the
lint cluster's extractable share is roughly a third of each file's ~340 *code* lines, and the
remaining three clusters total 3,310 lines between them. The deletable volume of -10,000
magnitude lives in the **test** corpus (60,852 lines with zero shared harness) and in the
markdown/context corpus the dispatch leaves explicitly untracked. Phase 2 derives the per-cluster
figures mechanically before any target is committed; the choice of what to do if they fall short
of the recommended floor is surfaced as a non-blocking decision on this dispatch's
`.return-meta.json` rather than silently resolved by lowering the bar.

## Goals & Non-Goals

**Goals**:
- A measured net reduction in both NET-PROD and NET-TEST against a Phase-1-captured baseline.
- A standing corpus-size probe emitting one cheap line per gate run — count and line total for
  non-test scripts, suite count, markdown file and line total — with **no new gate row**.
- One definition, one call site for the lint corpus-scan skeleton, pinned by a regression test.
- One shared test harness library that migrated suites source rather than redefine, pinned by a
  regression test.
- Every gate's finding set and every suite's assertion set provably unchanged across the whole task.
- A unit/integration classification for every suite, mechanically enforced, with a
  deliberately-violating fixture proving the enforcement fires.
- A cost-per-assertion figure on the standing probe, so a suite drifting into integration cost
  without integration value is visible in the run that causes it.
- Selection by class, tag and cost class layered on top of `run-all.sh`'s existing flags, with
  `--only`, `--jobs`, `--timings` and `--fail-on-new` behaving identically afterwards.

**Non-Goals**:
- **Markdown, context and rules consolidation is explicitly out of scope** (943 files / ~230,000
  lines). Every concrete cluster and gap the dispatch evidences is shell or test shell; folding in
  an open-ended markdown pass would dilute the net-deletion target with an unbounded second front.
  Revisit only if the Phase 2 decision above resolves toward widening scope.
- **Re-targeting the two verify-deploy stragglers, `JOBS_CAP`, `measure-gate-costs.sh` hardening,
  or hint coverage.** All four already landed elsewhere; re-deriving them against the dispatch's
  stale figures would duplicate completed work.
- **Gate 3's post-invalidation measurement decision and gate 8's serialized-isolation decision.**
  Both belong to task 416's remaining phases.
- A new gate row for the size probe. The dispatch's own constraint: this task must not become its
  own counterexample.
- Any speedup pursued for its own sake. A phase that makes the corpus faster without making it
  smaller does not advance this task's acceptance criterion.
- Rewriting the change-impact selection library (`scripts/lib/suite-selection-lib.sh`). Phase 14
  composes with it; it does not replace it.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Net-deletion target gaming: a phase shows a locally positive net while claiming it is the cheapest route to a later negative net, with no evidence — the 36:1 insert-to-delete outcome the dispatch cites as its motivating failure | H | M | Every phase records a measured per-phase net against both figures as a literal phase-closing item; the five net-positive-by-construction phases each state their justification in advance in this plan |
| A refactor silently changes a gate's finding set or a suite's assertion set | H | M | Each lint-touching phase diffs the lint's finding output over the whole corpus before and after; each suite-touching phase diffs the suite's assertion count and PASS/FAIL names before and after. A changed finding or assertion set fails the phase |
| The declared target proves unreachable from in-scope clusters, and scope silently creeps into markdown to compensate | H | M | Markdown is a stated non-goal; the shortfall is surfaced as a user decision at plan return rather than absorbed |
| File collision with task 416 on `run-all.sh`, `suite-cost-hints.txt`, `measure-gate-costs.sh`, `shell-script-testing.md` | M | M | Phases 12, 13, 14 re-read 416's live phase states before editing and stop rather than edit on a hit |
| Every figure in the dispatch, the report, and this plan is a snapshot; the corpus has demonstrated 30% drift in twelve days and ~7% in one | M | H | Each phase re-measures its own targets immediately before acting; carried figures carry a Scope Hypothesis naming the record they came from |
| Migrating 121 suites onto one harness in a single sweep produces an unreviewable diff and no safe rollback point | H | M | Migration is tranched (Phases 6, 7, 8) with a per-tranche assertion-set diff, so a regression localizes to at most one tranche |
| Timing measurements invalidated by mid-run host contention, indistinguishable from a real regression | M | M | All three load averages under 2 before any timing run; two repetitions disagreeing by >25% are discarded, not averaged |
| Extracting a shared harness could itself become a net-positive outcome if suites keep their old copies | H | L | The Phase 4 regression test pins that migrated suites source rather than redefine; a suite carrying both fails it |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4, 9, 10, 11 | 2 |
| 4 | 5 | 3 |
| 5 | 6 | 4, 5 |
| 6 | 7 | 6 |
| 7 | 8 | 7 |
| 8 | 12 | 1, 8 |
| 9 | 13 | 8, 12 |
| 10 | 14 | 12, 13 |
| 11 | 15 | 1-14 |

Phases within the same wave can execute in parallel. Wave 3 is genuinely parallel: its five
phases hold disjoint file territory (`scripts/lint/` + one new lib; `scripts/tests/` + one new
lib; `install-extension.sh`/`uninstall-extension.sh`; the typst pair; `literature-search.sh`).

---

### Phase 1: Capture the Baseline and Land the Standing Size Probe [NOT STARTED]

**Goal**: One cheap instrument, wired into the existing gate run with no new gate row, emitting
the corpus-size line every run — plus the authoritative baseline every later phase's net is
measured against.

**Paired-Test Coverage**: Already tested. `scripts/tests/test-script-inventory.sh` exists and
covers the probe including a reproducibility case; the verify-deploy summary surface is covered by
the `test-verify-deploy-*` suites.

**Tasks**:
- [ ] Add a `--size-line` mode to `script-inventory.sh` that emits exactly one line — non-test
      script count and line total, test-suite count, markdown file and line total — reusing the
      script's existing canonical corpus definition and **skipping the duplicate-block analysis**
      entirely. Measured at plan time: the counting work alone is ~41ms, genuinely free.
- [ ] Wire that single line into `verify-deploy.sh`'s summary block, immediately before the
      existing `PASS`/`FAIL` summary lines, as a `[verify-deploy] corpus: ...` line. No new gate
      row, no new check, no effect on `CHECKS`/`FAILURES`/`FINDINGS` accounting.
- [ ] Extend `tests/test-script-inventory.sh` with a `--size-line` case asserting the line's shape
      and that the mode emits exactly one line and exits 0.
- [ ] Confirm the existing `test-verify-deploy-*` suites still pass byte-identically on their
      PASS/FAIL summary assertions — the new line must not perturb them.
- [ ] Record the baseline: run `--size-line` and write both figures into this plan's Running Net
      Figures table as the NET-PROD and NET-TEST origins. Do **not** reuse the dispatch's figures
      or the research report's; both are superseded.

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: The plan-time figures above (237 non-test scripts / 91,802 lines; 155 test
suites; 943 markdown files) were derived by this plan's own `find`/`wc` pass, which uses different
predicates from `script-inventory.sh`'s own corpus definition — the report, using the probe,
reported 232 / 90,472. Confirm at implementation time by running `--size-line` and treating the
probe's own definition as canonical; the two derivations must be reconciled to one before any
baseline is recorded, and the plan-time numbers above are an estimate, not the baseline.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-script-inventory.sh,test-verify-deploy-gate-selection.sh,test-verify-deploy-context-budget.sh`
covers the changed module plus its enumerated direct dependents — the suites that assert on
`verify-deploy.sh`'s summary-line contract — and nothing outside that one-hop set is touched.

**Net-positive justification (declared in advance)**: This phase adds lines and deletes none. It
is the cheapest route to a later negative net because it is the only instrument that makes every
subsequent phase's net figure measurable at all, and the dispatch names it as a deliverable in its
own right: complexity that is not measured will not be resisted.

**Files to modify**:
- `agent-system/extensions/core/scripts/script-inventory.sh` - add `--size-line` fast-path mode
- `agent-system/extensions/core/scripts/verify-deploy.sh` - emit the one-line corpus figure in the summary block
- `agent-system/extensions/core/scripts/tests/test-script-inventory.sh` - add the `--size-line` case
- `specs/328_systematic_script_and_test_corpus_efficiency/plans/01_corpus-consolidation-net-deletion.md` - record the captured baseline

**Verification**:
- `script-inventory.sh --size-line` emits exactly one line and exits 0.
- `run-all.sh --only test-script-inventory.sh,test-verify-deploy-gate-selection.sh,test-verify-deploy-context-budget.sh` is green.
- The `[verify-deploy] corpus:` line appears once in a `verify-deploy.sh --skip-slow` run and the PASS/FAIL summary line is otherwise byte-identical to a pre-change run.
- The Running Net Figures table in this plan carries a recorded NET-PROD and NET-TEST origin.

---

### Phase 2: Derive Each Cluster's Extractable Volume and Declare the Two Targets [NOT STARTED]

**Goal**: Replace every estimate in this plan with a mechanically derived per-cluster extractable
volume, then declare the two net targets those figures actually support — before any refactor
begins.

**Paired-Test Coverage**: Not applicable. This phase is measurement and target declaration; it
modifies no executable file.

**Tasks**:
- [ ] Re-run `script-inventory.sh` fresh and re-read the ranked output for all five clusters
      (seven-lint, install/uninstall pair, typst pair, `literature-search.sh`, and the test
      corpus). Every figure in this plan is a snapshot and is to be treated as provisional.
- [ ] For each cluster, derive extractable volume mechanically rather than by eye: `comm -12` on
      sorted, comment-and-blank-stripped unique lines for each pair, and for
      `literature-search.sh` the probe's own self-internal duplicate-block spans. Record the
      shared-line count and the resulting bounded net per cluster.
- [ ] For the test corpus, derive the per-suite harness-boilerplate span (the `SCRIPT_DIR` /
      `REPO_ROOT` resolution block, `resolve_candidate`, the `PASSED`/`FAILED` + `pass`/`fail`/`info`
      helpers, and the `mktemp -d` + `trap cleanup` teardown) on a sample of at least 20 suites,
      and multiply out against the live suite count.
- [ ] Declare NET-PROD and NET-TEST targets from those derived figures, writing them into this
      plan's Running Net Figures table.
- [ ] Re-read task 416's live plan `### Phase` headings and record its current phase states in
      this plan, superseding the table in "The 416 Overlap" above if it has advanced.
- [ ] If the derived production-script total falls short of the dispatch's recommended -10,000
      floor, record the shortfall and the two options (accept the evidence-derived target with
      markdown out of scope, or widen scope to markdown/context) rather than silently lowering
      the bar.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: This plan asserts roughly -1,500 to -2,400 reachable production-script lines
and roughly -3,700 to -4,900 reachable test-script lines, carried from this plan's own
plan-authoring arithmetic over the Plan-Time Measurements block above, not from the dispatch or
the research report. Both ranges are hypotheses; this phase's `comm -12` and per-suite-span
derivations confirm or replace them, and no target is committed until they do.

**Tier Justification**: Every changed hunk lies inside this plan's own prose and tables under
`specs/**`, with no executable surface; per `plan-format.md`'s `__FULL_SWEEP__` sub-case (a), the
covering check is `bash .claude/scripts/validate-artifact.sh specs/328_systematic_script_and_test_corpus_efficiency/plans/01_corpus-consolidation-net-deletion.md plan`
together with the `prose` row's diff read-through.

**Net-positive justification (declared in advance)**: This phase changes no corpus line in either
direction (its only edit is to a `specs/**` plan file, outside both populations). It is the
cheapest route to a negative net because committing to a target before deriving what the clusters
can yield is precisely how a consolidation task ends up net-positive without anyone noticing.

**Files to modify**:
- `specs/328_systematic_script_and_test_corpus_efficiency/plans/01_corpus-consolidation-net-deletion.md` - record derived per-cluster volumes, the two declared targets, and 416's live phase states

**Verification**:
- Every cluster in the Plan-Time Measurements block has a derived shared-line count and a bounded net figure recorded.
- NET-PROD and NET-TEST targets are written into the Running Net Figures table with their derivation named.
- `bash .claude/scripts/validate-artifact.sh specs/328_systematic_script_and_test_corpus_efficiency/plans/01_corpus-consolidation-net-deletion.md plan` passes.

---

### Phase 3: Extract the Lint Corpus-Scan Library and Migrate Two Lints [NOT STARTED]

**Goal**: One definition and one call site for the shared corpus-enumeration wrapper, proven by a
regression test, with the two smallest cluster members migrated onto it as the first live proof.

**Paired-Test Coverage**: Already tested. `tests/test-lint-state-writer-boundary.sh` (203 lines)
and `tests/test-lint-directory-pathspec-boundary.sh` (340 lines) are both-polarity fixture suites
for exactly these two lints. No characterization test is needed first.

**Tasks**:
- [ ] Create `scripts/lib/lint-corpus-scan-lib.sh` exposing one function that takes the lint's
      default-scan path and its glob patterns and returns the file list — collapsing the
      byte-identical `if [[ ${#SCAN_PATHS[@]} -eq 1 ]] && ... common_shared_corpus_available`
      wrapper, its seven-line comment, and its `while IFS= read -r -d ''` loop into one place. The
      underlying helpers stay in `lib/common.sh`, already correctly defined once.
- [ ] Write `tests/test-lint-corpus-scan-lib.sh` pinning that the extracted helper has **exactly
      one definition** in the source store and that no lint file carries its own copy of the
      wrapper — a grep-based structural assertion, plus a behavioral case proving the helper
      returns the same file list the inline block did.
- [ ] Migrate `lint-state-writer-boundary.sh` and `lint-directory-pathspec-boundary.sh` to source
      the lib and call the helper, deleting their inline wrappers and the comment blocks that
      travelled with the copy-paste.
- [ ] Diff each migrated lint's finding output over the whole corpus before and after. The finding
      sets must be identical, not merely both-empty.
- [ ] Record the phase's NET-PROD delta.

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This plan asserts six of the seven cluster members carry the shared
corpus-enumeration wrapper (`lint-branch-gated-sections.sh` does not), derived from a plan-time
`grep -c common_shared_corpus_available` over all seven. Confirm by re-running that grep before
editing; a seventh hit, or a sixth miss, changes which files this phase and Phase 5 touch.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-state-writer-boundary.sh,test-lint-directory-pathspec-boundary.sh,test-lint-corpus-scan-lib.sh,test-common-lib.sh`
is the complete covering check — the two migrated lints are standalone executables whose only
consumers are the gate registry and their own fixture suites, and the new lib adds no symbol any
other module calls yet.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/lint-corpus-scan-lib.sh` - new shared corpus-scan wrapper
- `agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh` - source the lib, delete the inline wrapper
- `agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh` - source the lib, delete the inline wrapper
- `agent-system/extensions/core/scripts/tests/test-lint-corpus-scan-lib.sh` - new single-definition and behavioral regression test

**Verification**:
- `run-all.sh --only test-lint-state-writer-boundary.sh,test-lint-directory-pathspec-boundary.sh,test-lint-corpus-scan-lib.sh,test-common-lib.sh` is green.
- `grep -rc '<extracted helper name>() {' agent-system/extensions` returns exactly one definition site.
- Each migrated lint's whole-corpus finding output is byte-identical before and after.
- The phase's NET-PROD delta is recorded and negative.

---

### Phase 4: Extract the Shared Test Harness Library [NOT STARTED]

**Goal**: The single largest extract-a-lib target in the corpus gets its one definition — a shared
assert/fixture/teardown harness that suites source instead of reimplementing, with a regression
test pinning that they source rather than redefine.

**Paired-Test Coverage**: Not applicable to the new lib itself (it is created with its own suite in
this phase). No existing suite is modified here, so no existing coverage is disturbed.

**Tasks**:
- [ ] Create `scripts/lib/test-harness-lib.sh` covering the boilerplate measured across all 121
      core suites: `SCRIPT_DIR` resolution (121/121 open-code it), depth-independent `REPO_ROOT`
      resolution via `git rev-parse --show-toplevel` with a fixed-depth fallback (64/121),
      `resolve_candidate` deploy-tree-first / source-store-fallback lookup (22/121),
      `PASSED`/`FAILED` counters with `pass`/`fail`/`info` (121/121), and `mktemp -d` workdir plus
      `trap cleanup EXIT` teardown (115/121).
- [ ] Preserve the exact output strings the existing suites emit (`[PASS] `, `[FAIL] `, `[INFO] `)
      and the exit-code convention (0 all pass, 1 any fail, 2 environment error).
      `tests/run-all.sh` and its `--fail-on-new` classification parse `^[FAIL] ` lines; a changed
      prefix would silently break failure accounting.
- [ ] Write `tests/test-test-harness-lib.sh` pinning that the harness has exactly one definition
      and that a suite sourcing it does not also define `pass()`/`fail()` of its own — the
      anti-regression that stops this phase's extraction from becoming a net addition.
- [ ] Add the harness to `context/standards/shell-script-testing.md` as the required structural
      model for a new suite, replacing the current "copy an existing suite's helpers" practice.
- [ ] Record the phase's NET-TEST delta (expected positive; see justification).

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This plan asserts 121 core suites, 60,852 lines, and the per-category
redefinition counts in the Plan-Time Measurements block, derived from a plan-time
`grep -l`/`wc -l` pass. Phase 2 re-derives the per-suite boilerplate span; confirm the suite count
again here immediately before writing the harness, since the corpus added 10 suites in the single
day between the dispatch's snapshot and the research report's.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-test-harness-lib.sh`
is the complete covering check: this phase adds one new library and one new suite and migrates no
existing suite, so no existing assertion set has any path to change.

**Net-positive justification (declared in advance)**: This phase is net-positive on NET-TEST by
construction — it adds a library and a suite and deletes nothing. It is the cheapest route to a
negative net because it is the precondition for Phases 6, 7 and 8, which together remove the
boilerplate from 121 suites; extracting the harness in the same phase as any migration would make
the first tranche's diff unreviewable and leave no clean rollback point.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/test-harness-lib.sh` - new shared assert/fixture/teardown harness
- `agent-system/extensions/core/scripts/tests/test-test-harness-lib.sh` - new single-definition and no-redefinition regression test
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - name the harness as the required structural model for a new suite

**Verification**:
- `run-all.sh --only test-test-harness-lib.sh` is green.
- The harness's `pass`/`fail`/`info` output strings and exit-code convention match a pre-existing suite's byte-for-byte.
- `grep -rc 'pass() {' agent-system/extensions/core/scripts/lib/` shows the harness as the sole lib-level definition.
- The phase's NET-TEST delta is recorded, with its net-positive justification restated in the closing note.

---

### Phase 5: Migrate the Remaining Lint Cluster Members [NOT STARTED]

**Goal**: The shared corpus-scan wrapper exists in exactly one place across the whole lint corpus,
and the wider shared skeleton (argument parsing, `SCAN_PATHS` collection, `VIOLATIONS` accounting,
exit-code convention) is extracted for all seven cluster members.

**Paired-Test Coverage**: Already tested — all five. `tests/test-lint-scoped-commit-boundary.sh`
(376L), `test-lint-task-lookup-adoption.sh` (310L), `test-lint-branch-gated-sections.sh` (406L),
`test-lint-hook-registration-paths.sh` (603L), `test-lint-shellcheck.sh` (212L). The last two were
reported as untested by the probe; that is its documented `has_test` path-resolution caveat, not a
real gap, so no characterization test is required.

**Tasks**:
- [ ] Migrate the four remaining wrapper-carrying lints — `lint-scoped-commit-boundary.sh`,
      `lint-task-lookup-adoption.sh`, `lint-hook-registration-paths.sh`, `lint-shellcheck.sh` —
      onto `lint-corpus-scan-lib.sh`, deleting each inline wrapper and its travelling comment
      block. Note `lint-shellcheck.sh` guards on `${#SCAN_PATHS[@]} -eq 0` where the others guard
      on `-eq 1`; the lib must accommodate both, not force one.
- [ ] Extend `lint-corpus-scan-lib.sh` with the wider shared skeleton all seven share, and migrate
      `lint-branch-gated-sections.sh` onto that part (it carries no corpus-scan wrapper but is a
      duplicate-block peer of the other six through the skeleton).
- [ ] Delete the per-file duplicated comment blocks that explain the shared skeleton, leaving one
      explanation in the lib. Roughly half of each cluster file is comment or blank; duplicated
      explanation is corpus too.
- [ ] Diff each of the seven lints' finding output over the whole corpus before and after. All
      seven finding sets must be identical.
- [ ] Re-confirm the gate registry's rows for gates 12, 17, 18, 19, 21, 22, 23 still invoke the
      migrated lints unchanged.
- [ ] Record the phase's NET-PROD delta.

**Timing**: 2 hours

**Depends on**: 3

**Verification Tier**: interface

**Scope Hypothesis**: This plan asserts a shared skeleton of roughly 112 shared code lines per
cluster pair, carried from the research report's `comm -12` spot check between
`lint-scoped-commit-boundary.sh` and `lint-task-lookup-adoption.sh` (the dispatch cites a 115-132
range from an earlier measurement). Phase 2 re-derives this across all pairs; confirm the derived
figure here before committing to what the skeleton extraction removes.

**Tier Justification**: The lib's call signature is now consumed by seven call sites across seven
files, so verification spans the changed module plus its enumerated direct dependents:
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-corpus-scan-lib.sh,test-lint-scoped-commit-boundary.sh,test-lint-task-lookup-adoption.sh,test-lint-branch-gated-sections.sh,test-lint-hook-registration-paths.sh,test-lint-shellcheck.sh,test-lint-state-writer-boundary.sh,test-lint-directory-pathspec-boundary.sh`
plus `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 12,17,18,19,21,22,23 <source_dir>`
for the gate rows that invoke them.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/lint-corpus-scan-lib.sh` - absorb the wider shared skeleton
- `agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh` - migrate onto the lib
- `agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh` - migrate onto the lib
- `agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh` - migrate onto the lib
- `agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` - migrate onto the lib, preserving its `-eq 0` guard
- `agent-system/extensions/core/scripts/lint/lint-branch-gated-sections.sh` - migrate onto the skeleton portion
- `agent-system/extensions/core/scripts/tests/test-lint-corpus-scan-lib.sh` - extend the single-definition assertion to all seven

**Verification**:
- The eight-suite `--only` selection above is green.
- `verify-deploy.sh --skip-slow --only-gate 12,17,18,19,21,22,23 <source_dir>` is green with a non-zero check count.
- All seven lints' whole-corpus finding output is byte-identical before and after.
- No lint file still contains the inline corpus-scan wrapper (`grep -L` over the seven returns all seven).
- The phase's NET-PROD delta is recorded and negative.

---

### Phase 6: Harness Migration Tranche A — The Lint Suites [NOT STARTED]

**Goal**: The first tranche of suites sources the harness instead of redefining it, proving the
migration pattern on the suites this task has just finished exercising.

**Paired-Test Coverage**: These suites *are* the tests. Their own coverage is the assertion-set
diff below: each suite's assertion count and its PASS/FAIL case names must be identical before and
after migration.

**Tasks**:
- [ ] Migrate the seven `test-lint-*.sh` suites paired with the Phase 3/5 cluster onto
      `test-harness-lib.sh`, deleting each suite's own `SCRIPT_DIR`/`REPO_ROOT` resolution,
      `resolve_candidate`, counters, `pass`/`fail`/`info`, and `mktemp -d` + `trap cleanup` block.
- [ ] Migrate a further tranche of the smallest remaining suites, chosen by line count from the
      Phase 2 derivation, to bring this tranche to roughly 25 suites total.
- [ ] For every migrated suite, diff its assertion count and its emitted PASS/FAIL case-name list
      before and after. Both must be identical — a suite that passes with fewer assertions has
      silently lost coverage.
- [ ] Confirm no migrated suite still defines `pass()` or `fail()` of its own; the Phase 4
      regression test must pass over the migrated set.
- [ ] Record the phase's NET-TEST delta.

**Timing**: 2 hours

**Depends on**: 4, 5

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts a roughly 25-suite tranche and a per-suite boilerplate
span of roughly 30-40 lines, carried from Phase 2's derivation. Confirm the actual per-suite
deletion against the first three migrated suites before continuing through the tranche; if the
realized span is materially below the derived figure, the NET-TEST target declared in Phase 2 must
be revised rather than quietly missed.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only <the migrated tranche's basenames>,test-test-harness-lib.sh`
is the complete covering check — each migrated suite is a standalone executable with no consumer
beyond `run-all.sh`'s own discovery, and no production script changes in this phase.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-lint-scoped-commit-boundary.sh` - source the harness
- `agent-system/extensions/core/scripts/tests/test-lint-task-lookup-adoption.sh` - source the harness
- `agent-system/extensions/core/scripts/tests/test-lint-branch-gated-sections.sh` - source the harness
- `agent-system/extensions/core/scripts/tests/test-lint-directory-pathspec-boundary.sh` - source the harness
- `agent-system/extensions/core/scripts/tests/test-lint-state-writer-boundary.sh` - source the harness
- `agent-system/extensions/core/scripts/tests/test-lint-hook-registration-paths.sh` - source the harness
- `agent-system/extensions/core/scripts/tests/test-lint-shellcheck.sh` - source the harness
- `agent-system/extensions/core/scripts/tests/` - a further ~18 smallest suites, enumerated at implementation time from Phase 2's derivation

**Verification**:
- The tranche's `--only` selection plus `test-test-harness-lib.sh` is green.
- Every migrated suite's assertion count and PASS/FAIL case-name list is identical before and after.
- No migrated suite defines `pass()`/`fail()`/`info()` locally.
- The phase's NET-TEST delta is recorded and negative.

---

### Phase 7: Harness Migration Tranche B [NOT STARTED]

**Goal**: The bulk of the mid-size suites source the harness, carrying the largest single share of
this task's test-corpus net deletion.

**Paired-Test Coverage**: These suites are the tests; their coverage is the per-suite assertion-set
diff, as in Phase 6.

**Tasks**:
- [ ] Migrate roughly 45 mid-size suites onto `test-harness-lib.sh`, following Phase 6's
      established pattern.
- [ ] Per-suite assertion-count and PASS/FAIL case-name diff, as in Phase 6.
- [ ] Handle the suites that resolve candidates by a non-standard path shape individually rather
      than forcing them into the harness's `resolve_candidate` — only 22 of 121 define it today,
      so the harness must not assume a shape the other 99 never used.
- [ ] Record the phase's NET-TEST delta and the running NET-TEST figure.

**Timing**: 2 hours

**Depends on**: 6

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts a roughly 45-suite tranche. The suite count is live and
drifting (155 repo-wide at plan time, up from 145 twelve days earlier and 147 the day before);
enumerate the actual tranche from a fresh `ls` at phase start rather than from this figure.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only <the migrated tranche's basenames>,test-test-harness-lib.sh`
is the complete covering check, for the same reason as Phase 6: migrated suites are standalone
executables and no production script changes.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/` - roughly 45 mid-size suites, enumerated at implementation time from a fresh listing

**Verification**:
- The tranche's `--only` selection plus `test-test-harness-lib.sh` is green.
- Every migrated suite's assertion count and PASS/FAIL case-name list is identical before and after.
- The running NET-TEST figure is recorded and negative.

---

### Phase 8: Harness Migration Tranche C — Complete the Corpus [NOT STARTED]

**Goal**: Every suite in the corpus sources the harness or carries a recorded, reasoned exemption;
no suite reimplements the boilerplate.

**Paired-Test Coverage**: These suites are the tests; their coverage is the per-suite assertion-set
diff, as in Phase 6.

**Tasks**:
- [ ] Migrate the remaining suites, including the two largest
      (`test-orchestrate-cycle-plan.sh` and `test-orchestrate-cycle-postflight.sh`), onto the
      harness. These two are the highest-value single migrations by line count and the most
      delicate by assertion count — the former carries several hundred assertions.
- [ ] Record a reasoned exemption, in `shell-script-testing.md`, for any suite that genuinely
      cannot source the harness, with the specific reason. An unexplained holdout is a future
      copy-paste source and defeats the extraction.
- [ ] Per-suite assertion-count and PASS/FAIL case-name diff for every migration in the tranche.
- [ ] Run the full suite battery (`run-all.sh`, no `--only`) and confirm the total assertion count
      across the whole corpus is unchanged from the Phase 1 baseline.
- [ ] Record the phase's NET-TEST delta and confirm the running NET-TEST figure meets the Phase 2
      target.

**Timing**: 2 hours

**Depends on**: 7

**Verification Tier**: interface

**Scope Hypothesis**: This plan asserts the two largest suites are
`test-orchestrate-cycle-plan.sh` (5,517 lines, 779 assertions) and
`test-orchestrate-cycle-postflight.sh` (3,760 lines), carried from the dispatch's 2026-10-15
figures. Both have been edited since by other work; re-measure their line and assertion counts at
phase start before using either figure.

**Tier Justification**: This phase completes the harness's consumer set, so verification spans the
lib plus every suite that now depends on it — `bash agent-system/extensions/core/scripts/tests/run-all.sh`
with no `--only`, which is the enumerated full dependent set for this one library, short of the
non-test gates the final phase covers.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/` - all remaining suites, enumerated at implementation time
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - record any reasoned non-migration exemption

**Verification**:
- `run-all.sh` (full battery, no `--only`) is green.
- Corpus-wide total assertion count is unchanged from the Phase 1 baseline.
- No suite outside the recorded exemption list defines `pass()`/`fail()` locally.
- The running NET-TEST figure meets the Phase 2 target.

---

### Phase 9: Deduplicate the Extension Install/Uninstall Pair [NOT STARTED]

**Goal**: The mutual duplication between `install-extension.sh` and `uninstall-extension.sh`
collapses into one shared helper set.

**Paired-Test Coverage**: Confirm at phase start. Neither script was verified as fixture-tested at
plan time. If no paired suite exists, write a characterization test asserting both scripts'
observable behavior **before** any refactor — a large script with no paired test cannot be safely
refactored, and that constraint is about test coverage, not about any dependency.

**Tasks**:
- [ ] Re-run `script-inventory.sh` and confirm the pair's duplicate-block count and mutual-peer
      relation before acting.
- [ ] Determine whether a paired suite exists; if not, write a characterization test first.
- [ ] Extract the shared blocks into one helper set — either a new
      `lib/extension-install-lib.sh` or, where the logic already belongs there, `lib/common.sh`.
- [ ] Diff both scripts' observable behavior (install then uninstall round-trip on a scratch
      fixture tree) before and after. The resulting tree state must be identical.
- [ ] Record the phase's NET-PROD delta.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This plan asserts `install-extension.sh` at 300 lines / 35 duplicate blocks
and `uninstall-extension.sh` at 243 lines / 35, carried from the research report (the dispatch
cited 299/33 and 237/33). Re-run the probe at phase start; the pair's real extractable volume is
derived in Phase 2 and that figure, not these, is the one to act on.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only <the pair's suite(s), or the characterization test written in this phase>`
plus the install/uninstall round-trip on a scratch fixture tree is the complete covering check —
the pair's only consumers are the extension picker and the deploy path, neither of which depends
on an internal signature this phase changes.

**Files to modify**:
- `agent-system/extensions/core/scripts/install-extension.sh` - call the shared helpers
- `agent-system/extensions/core/scripts/uninstall-extension.sh` - call the shared helpers
- `agent-system/extensions/core/scripts/lib/extension-install-lib.sh` - new shared helper set (path confirmed at implementation time)
- `agent-system/extensions/core/scripts/tests/` - the pair's characterization test, if none exists

**Verification**:
- The install-then-uninstall round-trip on a scratch fixture tree produces an identical tree state before and after the refactor.
- The pair's suite (existing or newly written) is green.
- The phase's NET-PROD delta is recorded and negative.

---

### Phase 10: Deduplicate the Typst Script Pair [NOT STARTED]

**Goal**: The 44 mutual duplicate blocks between `chapter-quality-check.sh` and
`typst-element-lint.sh` collapse into one shared helper set within the typst extension.

**Paired-Test Coverage**: Confirm at phase start, as in Phase 9. If either script has no paired
suite, write a characterization test before refactoring it.

**Tasks**:
- [ ] Re-run `script-inventory.sh` and confirm the pair's duplicate-block count before acting.
- [ ] Determine paired-test coverage; write characterization tests first where absent.
- [ ] Extract the shared blocks into a typst-extension-local shared helper. Keep it inside the
      typst extension — a cross-extension lib would couple the typst extension to core for no
      gain, and extension independence is a deliberate property of the layout.
- [ ] Diff both scripts' finding output over a representative typst fixture tree before and after.
- [ ] Record the phase's NET-PROD delta.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This plan asserts `chapter-quality-check.sh` at 763 lines and
`typst-element-lint.sh` at 370, each with 44 duplicate blocks, carried from the research report
(the dispatch cited 754 and 372). Re-run the probe at phase start and act on Phase 2's derived
figure.

**Tier Justification**: The two scripts and their new helper are confined to the typst extension
with no symbol crossing out of it; the covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only <the pair's typst suite(s)>`
plus both scripts' finding-output diff over a typst fixture tree.

**Files to modify**:
- `agent-system/extensions/typst/scripts/chapter-quality-check.sh` - call the shared helpers
- `agent-system/extensions/typst/scripts/typst-element-lint.sh` - call the shared helpers
- `agent-system/extensions/typst/scripts/lib/` - new typst-local shared helper (exact path confirmed at implementation time)
- `agent-system/extensions/typst/scripts/tests/` - characterization tests, if absent

**Verification**:
- Both scripts' finding output over a representative typst fixture tree is byte-identical before and after.
- The pair's suites (existing or newly written) are green.
- The phase's NET-PROD delta is recorded and negative.

---

### Phase 11: Collapse literature-search.sh's Self-Internal Repetition [NOT STARTED]

**Goal**: The 172 duplicate blocks *inside* one 1,634-line file collapse into local helpers — a
different defect class from the cross-file clusters, and the densest single-file duplication the
probe reports.

**Paired-Test Coverage**: Confirm at phase start. `peers=0` means no cross-file relation; a paired
suite may or may not exist. 172 duplicate blocks in one file is the highest-risk refactor in this
plan, so a characterization test is mandatory before any edit if none exists.

**Tasks**:
- [ ] Re-run `script-inventory.sh` and confirm the duplicate-block count and the `peers=0`
      self-internal classification before acting.
- [ ] Write or confirm a characterization test covering the script's search modes and output
      shapes. Do not edit before it is green on the unmodified script.
- [ ] Extract the repeated blocks into file-local functions. Keep them file-local: with `peers=0`
      there is no second consumer, so promoting them to a lib would add an import surface for no
      deduplication gain.
- [ ] Diff the script's output across every search mode before and after against a fixture
      literature index.
- [ ] Record the phase's NET-PROD delta.

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This plan asserts `literature-search.sh` at 1,634 lines with 172
self-internal duplicate blocks and `peers=0`, carried from the research report (the dispatch cited
1,635/172). Re-run the probe at phase start; a changed `peers` value would mean the
file-local-helpers decision above needs revisiting.

**Tier Justification**: The extraction is confined to one file with no externally visible
signature change (the helpers are file-local by design), so the covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only <the script's suite, or the characterization test written in this phase>`
plus the per-search-mode output diff against a fixture literature index.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-search.sh` - extract repeated blocks into file-local helpers
- `agent-system/extensions/literature/scripts/tests/` - characterization test, if absent

**Verification**:
- The script's output in every search mode is byte-identical before and after against a fixture literature index.
- The characterization test is green both before (on the unmodified script) and after.
- The phase's NET-PROD delta is recorded and negative.

---

### Phase 12: Classify Every Suite and Enforce the Unit/Integration Boundary [NOT STARTED]

**Goal**: A unit-class suite mechanically cannot spawn `deploy-headless.sh`, `verify-deploy.sh` or
`run-all.sh`, and the standing size probe reports cost-per-assertion so a suite drifting into
integration cost without integration value is visible in the run that causes it.

**Paired-Test Coverage**: The new lint gets a deliberately-violating fixture suite in this phase —
a fixture that *should* trip the lint, proving the enforcement actually fires rather than passing
vacuously.

**Tasks**:
- [ ] **Re-read task 416's live plan `### Phase` headings first.** This phase touches
      `suite-cost-hints.txt` and `shell-script-testing.md`; stop rather than edit if 416 has
      advanced into either since Phase 2's check.
- [ ] Classify every suite as unit-class or integration-class, recording the classification in a
      declarative data file rather than in prose — adding a suite must be a data edit, not a
      documentation edit.
- [ ] Add a lint enforcing that a unit-class suite does not invoke `deploy-headless.sh`,
      `verify-deploy.sh` or `run-all.sh`. Ride an existing gate row rather than adding one, per
      this task's own no-new-gate-row constraint.
- [ ] Write the lint's both-polarity fixture suite, including a deliberately-violating fixture that
      must trip it.
- [ ] Extend the Phase 1 size-probe line with a cost-per-assertion figure, derived from the live
      hint pool and per-suite assertion counts. Keep it on the same single line.
- [ ] Record the phase's NET-PROD and NET-TEST deltas.

**Timing**: 2 hours

**Depends on**: 1, 8

**Verification Tier**: local

**Scope Hypothesis**: This plan carries, unverified, the dispatch's heavyweight-operation counts
(101 `deploy-headless.sh` invocations, 31 `verify-deploy.sh`, 24 `run-all.sh`, 37 `git init`, 266
`mktemp -d`) alongside the research report's differently-derived file counts (17, 24, 16, 39, 270).
**The two are not comparable as written** — one counts invocations, the other counts files. Re-derive
both consistently (`grep -c` for invocations, `grep -l` for files) at phase start before either is
used as a classification input or a baseline.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only <the new lint's fixture suite>,test-script-inventory.sh`
plus `bash <source_dir>/scripts/verify-deploy.sh --skip-slow --only-gate <the host gate row> <source_dir>`
is the complete covering check — the new lint is a standalone executable and the probe-line change
is confined to `script-inventory.sh`'s own output.

**Net-positive justification (declared in advance)**: This phase adds a classification data file, a
lint, and a fixture suite. It is the cheapest route to a negative net because Phase 13's
single-shared-fixture consolidation needs the classification to know which suites may legitimately
build a deployed tree, and because an unenforced classification drifts back within days — the
dispatch's own ratio finding (sixteen additive tasks against three reductive ones) is what an
unenforced boundary produces.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/` - new suite-classification data file and the new lint's fixture suite
- `agent-system/extensions/core/scripts/lint/` - new unit-class spawn-boundary lint
- `agent-system/extensions/core/scripts/script-inventory.sh` - add cost-per-assertion to the `--size-line` output
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - document the classification and the boundary

**Verification**:
- The deliberately-violating fixture trips the new lint (non-zero exit); the conforming fixtures do not.
- The lint reports zero findings over the live corpus after classification.
- The size-probe line carries a cost-per-assertion figure and is still one line.
- `run-all.sh --only <the lint's fixture suite>,test-script-inventory.sh` is green.
- Both net deltas are recorded, with the net-positive justification restated in the closing note.

---

### Phase 13: Build the Deployed-Tree Fixture Once and Lend It Read-Only [NOT STARTED]

**Goal**: The expensive deployed-tree fixture is constructed once per run and lent read-only to
every suite that needs it, instead of being reconstructed per suite. This is net deletion, not
merely a speedup — many fixture-construction blocks collapse into one.

**Paired-Test Coverage**: Already tested after Phase 8 — every consuming suite is migrated onto the
harness and has a recorded pre-migration assertion set, so the shared-fixture change is verified by
the same assertion-set diff.

**Tasks**:
- [ ] **Re-read task 416's live plan `### Phase` headings first**; this phase touches
      `tests/run-all.sh`.
- [ ] Build the shared deployed-tree fixture once at `run-all.sh` startup and expose it read-only
      to suites via the harness, with a per-suite scratch overlay for anything a suite must write.
- [ ] Migrate the integration-class suites identified in Phase 12 onto the shared fixture,
      deleting their own construction blocks.
- [ ] Enforce read-only lending: a suite that mutates the shared fixture must fail loudly rather
      than silently corrupting a sibling's fixture. A shared mutable fixture under `--jobs auto`
      is a cross-suite contamination source, which is precisely the host-state coupling an earlier
      task was chartered to remove.
- [ ] Per-suite assertion-set diff for every migrated suite.
- [ ] Record the phase's NET-TEST delta.

**Timing**: 2 hours

**Depends on**: 8, 12

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts that the integration-class suites identified in Phase 12
are the complete consumer set for the shared fixture. Confirm by re-deriving the
`deploy-headless.sh` invocation count (consistently, per Phase 12's note) after migration: it must
drop to the single shared construction site plus any recorded exemption.

**Tier Justification**: The shared fixture changes a surface every integration-class suite now
depends on, so verification spans `run-all.sh` plus its enumerated dependent set —
`bash agent-system/extensions/core/scripts/tests/run-all.sh` with no `--only`, run once at
`--jobs auto` and once at `--jobs 1`, since the read-only-lending contract is only exercised under
concurrency.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/run-all.sh` - construct the shared deployed-tree fixture once and lend it read-only
- `agent-system/extensions/core/scripts/lib/test-harness-lib.sh` - expose the shared fixture plus a per-suite write overlay
- `agent-system/extensions/core/scripts/tests/` - the integration-class suites, migrated off their own construction blocks
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - document the shared-fixture contract

**Verification**:
- `run-all.sh` is green at both `--jobs auto` and `--jobs 1`.
- Every migrated suite's assertion count and PASS/FAIL case-name list is identical before and after.
- A suite deliberately attempting to mutate the shared fixture fails loudly.
- The `deploy-headless.sh` invocation count inside test files drops to the single shared site plus recorded exemptions.
- The phase's NET-TEST delta is recorded and negative.

---

### Phase 14: Add Class, Tag and Cost-Class Selection to run-all.sh [NOT STARTED]

**Goal**: Running an appropriate subset no longer requires knowing and typing exact filenames, so
the corpus's volume stops being a cost paid in full on every task.

**Paired-Test Coverage**: Already tested. `tests/test-run-all-selection.sh` covers the existing
change-impact selection library, and `run-all.sh`'s own flag behavior is asserted by the suites
that invoke it.

**Tasks**:
- [ ] **Re-read task 416's live plan `### Phase` headings first**; this phase touches
      `tests/run-all.sh` and 416's phase 13 is a redeploy of the same file's area.
- [ ] Add selection by class (unit/integration, from Phase 12's data file), by tag, and by cost
      class, layered **on top of** the existing flags.
- [ ] Preserve `--only`, `--jobs`, `--timings` and `--fail-on-new` behavior byte-identically. The
      existing `--only` contract — every token must match a discovered suite or the run refuses
      loudly, and a narrowed run's accounting inherits the narrowing — is the model the new
      selectors must follow, including the "a selected-subset pass is not evidence of a full pass"
      honesty clause.
- [ ] Compose with `scripts/lib/suite-selection-lib.sh` rather than replacing it; it is a working
      change-impact selector with its own regression suite and its `__FULL_SWEEP__` escalation
      sentinel is relied on by the verification-tier contract.
- [ ] Extend `tests/test-run-all-selection.sh` with cases for each new selector, including the
      refuse-loudly case for an unmatched selector value.
- [ ] Record the phase's NET-PROD and NET-TEST deltas.

**Timing**: 2 hours

**Depends on**: 12, 13

**Verification Tier**: interface

**Scope Hypothesis**: This plan asserts `run-all.sh` exposes exactly
`--quiet / --timings / --jobs / --only / --fail-on-new` today (743 lines at plan time), carried
from the research report and re-confirmed by a plan-time grep of the file's own usage block.
Re-confirm at phase start — 416 may have added a flag since.

**Tier Justification**: New selector flags change `run-all.sh`'s argument-parsing surface, which
every gate-8 invocation and several suites depend on, so verification spans the changed module plus
its enumerated direct dependents: `run-all.sh --only test-run-all-selection.sh` for the selector
cases, plus `bash <source_dir>/scripts/verify-deploy.sh --skip-slow --only-gate 8 <source_dir>`
for the one gate row that invokes it.

**Net-positive justification (declared in advance)**: This phase adds a selection surface and
deletes little. It is the cheapest route to a later negative net because it is the mechanism that
makes the smaller corpus *stay* smaller: the dispatch's own diagnosis is that with only a literal
basename filter available, agents and humans default to running everything, which is what makes
corpus volume a cost paid on every task rather than occasionally. Without a selection surface, the
pressure that produced the growth this task is counterweighting returns immediately.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/run-all.sh` - add class, tag and cost-class selection on top of the existing flags
- `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh` - expose the new selectors for composition, without changing existing behavior
- `agent-system/extensions/core/scripts/tests/test-run-all-selection.sh` - cases for each new selector and the refuse-loudly case
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - document the new selectors

**Verification**:
- `run-all.sh --only test-run-all-selection.sh` is green, including the new selector cases.
- `--only`, `--jobs`, `--timings` and `--fail-on-new` produce byte-identical output to a pre-change run on the same selection.
- An unmatched selector value refuses loudly and exits non-zero, matching `--only`'s existing contract.
- `verify-deploy.sh --skip-slow --only-gate 8 <source_dir>` is green.
- Both net deltas are recorded, with the net-positive justification restated in the closing note.

---

### Phase 15: Redeploy, Full Gate Set, and the Measured Net Accounting [NOT STARTED]

**Goal**: The source-store work reaches the deployed tree, the complete gate set is green, and the
task's acceptance criterion is discharged with measured figures — a net reduction in corpus size
with every gate's finding set and every suite's assertion set provably unchanged.

**Paired-Test Coverage**: The whole corpus. This phase runs the full battery and the complete gate
set; no narrowing applies.

**Tasks**:
- [ ] Redeploy via `deploy-headless.sh` so the deployed `.claude/` tree reflects the source store.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (source-store path:
      `agent-system/extensions/core/scripts/verify-deploy.sh`) with no `--skip-slow`, no
      `--only-gate`, and no `--max-cost`. Every gate must be green with a non-zero check count.
- [ ] Verify the finding-set invariant across the whole task: every gate's finding set over the
      live corpus is identical to the Phase 1 baseline. A gate that now finds less has lost
      coverage, which fails this phase.
- [ ] Verify the assertion-set invariant: the corpus-wide total assertion count and every suite's
      PASS/FAIL case-name list match their pre-task values.
- [ ] On a verified-quiet host (1-, 5- and 15-minute load averages all under 2), run the standing
      size probe and record the final NET-PROD and NET-TEST figures against the Phase 1 baseline.
      Both must be negative and must meet the Phase 2 targets.
- [ ] If either figure misses its target, record the shortfall and its cause explicitly rather than
      restating the target. The acceptance criterion is a measured net reduction, reported as a
      running net figure — never as a count of refactors performed.
- [ ] Confirm no file landing under `agent-system/**` carries a task-number reference or
      record-versioning language (both are permitted in this plan and the task description, and in
      neither case under `agent-system/**`).

**Timing**: 2 hours

**Depends on**: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts the Phase 2 targets are met. Those targets are themselves
derived rather than given, so confirm at phase start that the Phase 2 derivation was recorded and
that the final probe run uses the same canonical corpus definition the Phase 1 baseline used — a
baseline and a final figure taken with different predicates are not comparable, which is the exact
trap the dispatch's and the research report's non-comparable counts illustrate.

**Files to modify**:
- `specs/328_systematic_script_and_test_corpus_efficiency/plans/01_corpus-consolidation-net-deletion.md` - record the final net figures and the invariant results
- `.claude/` - regenerated by `deploy-headless.sh`, not hand-edited

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` (complete gate set, no `--skip-slow`, no `--only-gate`, no `--max-cost`) is green with a non-zero check count.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` (full battery) is green.
- Every gate's finding set over the live corpus is identical to the Phase 1 baseline.
- Corpus-wide total assertion count and per-suite PASS/FAIL case-name lists match pre-task values.
- Final NET-PROD and NET-TEST figures are recorded, both negative, both measured on a verified-quiet host with the Phase 1 baseline's own corpus definition.
- `bash .claude/scripts/check-task-references.sh` reports no finding under `agent-system/**`.

---

## Testing & Validation

- [ ] Every lint's finding set over the live corpus is identical before and after each phase that touches it — not merely both-empty.
- [ ] Every migrated suite's assertion count and PASS/FAIL case-name list is identical before and after migration.
- [ ] `tests/test-lint-corpus-scan-lib.sh` pins exactly one definition of the extracted corpus-scan helper and no inline copy in any lint file.
- [ ] `tests/test-test-harness-lib.sh` pins exactly one harness definition and that no migrated suite redefines `pass()`/`fail()`.
- [ ] The new unit-class spawn-boundary lint's deliberately-violating fixture trips it; its conforming fixtures do not.
- [ ] `run-all.sh`'s `--only`, `--jobs`, `--timings` and `--fail-on-new` produce byte-identical output to a pre-task run on the same selection.
- [ ] A suite attempting to mutate the shared read-only fixture fails loudly, at both `--jobs auto` and `--jobs 1`.
- [ ] The standing size probe emits exactly one line, carries the cost-per-assertion figure, and adds no gate row (`gate-registry.data` row count unchanged from the 23 recorded at plan time).
- [ ] The complete gate set is green at Phase 15 with a non-zero check count.
- [ ] Both running net figures are negative against the Phase 1 baseline and meet the Phase 2 targets.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/lint-corpus-scan-lib.sh` - shared lint corpus-scan skeleton (new)
- `agent-system/extensions/core/scripts/lib/test-harness-lib.sh` - shared test assert/fixture/teardown harness (new)
- `agent-system/extensions/core/scripts/lib/extension-install-lib.sh` - shared install/uninstall helpers (new; exact path confirmed in Phase 9)
- `agent-system/extensions/core/scripts/lint/` - new unit-class spawn-boundary lint
- `agent-system/extensions/core/scripts/script-inventory.sh` - `--size-line` standing probe mode with cost-per-assertion
- `agent-system/extensions/core/scripts/verify-deploy.sh` - one-line corpus-size figure in the summary block, no new gate row
- `agent-system/extensions/core/scripts/tests/run-all.sh` - shared deployed-tree fixture plus class/tag/cost-class selection
- `agent-system/extensions/core/scripts/tests/` - suite-classification data file, new regression and fixture suites, and the migrated suite corpus
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - harness as required structural model, classification and boundary, shared-fixture contract, new selectors
- The seven lint cluster members, the install/uninstall pair, the typst pair, and `literature-search.sh`, all deduplicated
- `specs/328_systematic_script_and_test_corpus_efficiency/plans/01_corpus-consolidation-net-deletion.md` - this plan, carrying the baseline, the declared targets, and the final net accounting
- A redeployed `.claude/` tree (generated by `deploy-headless.sh`, never hand-edited)

## Rollback/Contingency

Each phase is independently revertible: the plan's phase boundaries follow file-territory
boundaries, so a phase's edits are confined to the files its **Files to modify** list names, and
the commit-per-green-substep mandate means a failed phase leaves its predecessors committed and
green.

- **Before a risky phase** (Phase 8's two largest-suite migrations, Phase 11's 172-block
  single-file extraction, Phase 13's shared-fixture change), take a durable non-reverting
  checkpoint with `bash .claude/scripts/git-snapshot.sh 328 --no-revert`. This records the tree
  without touching it, which is what an ordinary defensive checkpoint needs.
- **For a genuine rollback** that must discard uncommitted work, follow
  `.claude/context/contracts/recovery.md`'s rollback rung for the exact invocation shape,
  including its out-of-scope override flag for the deliberate whole-tree case. Do not reach for a
  reverting snapshot as a routine precaution.
- **Phase-level contingency**: a phase whose finding-set or assertion-set invariant fails is
  reverted, not patched forward. A lost finding or a lost assertion is indistinguishable from a
  successful refactor by any other signal, which is why those two invariants are the hard gate.
- **Net-positive contingency**: a phase whose net is positive and which cannot state why it is the
  cheapest available route to a later negative net is reverted, per the dispatch's acceptance
  criterion.
- **Deploy contingency**: the deployed `.claude/` tree is a disposable artifact. If a redeploy
  produces a broken tree, re-run `deploy-headless.sh` from a known-good source-store commit; no
  hand-editing of `.claude/**` is ever part of a recovery.
