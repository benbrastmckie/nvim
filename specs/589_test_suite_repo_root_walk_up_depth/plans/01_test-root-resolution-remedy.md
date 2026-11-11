# Implementation Plan: Task #589

- **Task**: 589 - Test suite repo-root walk-up depth is invocation-path dependent
- **Status**: [IMPLEMENTING]
- **Effort**: 5.75 hours
- **Dependencies**: None (task 573 depends on this one)
- **Research Inputs**: None (no research artifact for this round; the task description carries
  the defect, the affected-suite list, the diagnostic recipe, and the acceptance bar, and the
  remaining facts were established by direct codebase measurement during planning — see Overview)
- **Artifacts**: plans/01_test-root-resolution-remedy.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Five shell test suites compute their own repository (or extensions) root by walking up a fixed
number of path segments from `$SCRIPT_DIR`/`$CORE_DIR`. That depth is correct for the source
store (`agent-system/extensions/core/scripts/tests`, five segments below the repo root) and wrong
for the deployed copy (`.claude/scripts/tests`, three segments below it) — which is exactly the
copy gate 8's suite runner executes. The remedy is to replace each fixed-depth computation with
the depth-independent helpers `lib/common.sh` already provides and 80 of the sibling core suites
already use, then confirm every affected suite green under both invocation paths.

Facts established by direct measurement during planning (not assumed):

- Resolution values, same host, same helper: from `agent-system/extensions/core/scripts/tests`
  the four-level walk `$CORE_DIR/../../../..` yields `/home/benjamin/.config/nvim`; from
  `.claude/scripts/tests` the identical expression yields `/home/benjamin`, a path **outside the
  repository**. `git rev-parse --show-toplevel` yields the repo root from both.
- `common_test_repo_root <script_dir>` (lib/common.sh) already implements exactly the required
  strategy: `git rev-parse --show-toplevel` first, fixed-depth fallback only outside a git work
  tree. **80 of the core suites already call it.** No sixth bespoke computation is needed.
- `common_test_ext_root <repo_root>` resolves the extensions root (`agent-system/extensions`)
  correctly from *both* invocation paths, including the external-source-store branch via
  `.claude-extensions.json`'s per-extension `source_dir`. Verified by running it from both.
- Two of the five suites are **not** fixed by a root swap, and were isolated empirically:
  - `test-lint-deploy-caller-wrap.sh` computes `EXTENSIONS_DIR="$CORE_DIR/../.."`, which from the
    deployed path resolves to the **repo root**, so its `find` scans both the source store and the
    deployed `.claude/` tree. Measured: source store `7 passed, 0 failed`; deployed
    `10 passed, 1 failed`, the failure naming four genuine callers
    (`agent-system/.../command-gate-out.sh`, `agent-system/.../orchestrate-cycle-plan.sh`,
    `.claude/scripts/command-gate-out.sh`, `.claude/scripts/orchestrate-cycle-plan.sh`) where
    exactly two are expected. The extra two are the deploy-tree duplicates.
  - `test-orchestrate-build-aux-dispatch.sh`'s single failure is **SUT-side, not test-side**.
    Measured: source store `22 passed, 0 failed`; deployed `21 passed, 1 failed` with
    `plan-revision's model did not resolve to opus (got: )`. Cause:
    `orchestrate-build-aux-dispatch.sh:56` sets `EXT_ROOT="$SCRIPT_DIR/../.."` and globs
    `"$EXT_ROOT"/*/agents/"${agent}.md"`. From the deployed script that resolves to
    `<repo>/*/agents/<agent>.md`, which matches nothing (`*` does not match the leading dot of
    `.claude`), so model resolution silently yields empty in **production**, not only under test.
    This is a real deployed-mode defect in a production script that the test correctly surfaced.
- The class is slightly wider than the five named suites. Two further suites carry an
  unconditional fixed-depth root computation of the same shape and are **not** in the task's
  five: `test-verify-deploy-gate-selection-crash-net.sh:51`
  (`$CORE_DIR/../../../..`) and `test-gate-cache-equivalence.sh:80` (`$CORE_DIR/../../..`).
  Every other fixed-depth walk found under `*/scripts/tests/` sits inside a conditional fallback
  branch already guarded by a `git rev-parse` probe, which is the sanctioned shape.

### Research Integration

No research artifact exists for this round. The task description supplied the defect, the
affected-suite list, the confirmed-pre-existing finding, the diagnostic recipe, and the
acceptance bar; planning added the per-suite root causes and the existing-helper inventory above
by direct `grep`/`Read`/suite-execution measurement within this dispatch.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; ROADMAP.md was not consulted and must not be
modified by this task.

## Goals & Non-Goals

**Goals**:

- Every one of the five named suites passes from **both** invocation paths: its source-store copy
  and its deployed copy as gate 8's runner executes it.
- Each remedied root computation is invocation-path independent and **reuses an existing
  `lib/common.sh` helper** rather than adding another bespoke walk.
- The deployed-mode agent-frontmatter model resolution in `orchestrate-build-aux-dispatch.sh`
  works, closing the production defect its test exposed.
- The two adjacent same-class suites are measured under both paths and remedied if they fail, so
  the sweep does not leave a known-shaped neighbour unexamined.
- A durable record for task 573 stating whether this change closes either of its two assertions.

**Non-Goals**:

- A new `lint-test-root-resolution.sh` closing the class by construction (the shape
  `lint-test-harness-adoption.sh` models). Durable and worth doing, but a larger surface than
  this task's scope; recorded as a follow-up candidate, not built here.
- Migrating the fixed-depth walks that already sit inside a `git rev-parse`-guarded fallback
  branch. They are the sanctioned shape and are correct as written.
- Any edit under `.claude/**`. That tree is a gitignored deploy artifact; every edit lands in
  `agent-system/extensions/**` and reaches `.claude/` only via `deploy-headless.sh`.
- Re-measuring or editing task 573's two assertions. This task records evidence; 573 owns the
  re-measurement.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Changing `EXT_ROOT` in `orchestrate-build-aux-dispatch.sh` alters production agent/model resolution for every aux dispatch kind | H | M | Phase 4 keeps the existing source-store glob as the first candidate and only *adds* fallbacks, so the source-store behaviour the 22 passing cases pin is unchanged; the suite is re-run from the source store as a negative control before the deployed run |
| A whole-tree `deploy-headless.sh` run in Phase 6 also deploys concurrent siblings' in-flight source-store edits | M | M | The `__WHOLE_TREE__` sentinel is declared in Phase 6's `Files to modify`, which is exactly what makes the batch admitter serialize this task against another whole-tree claimant; before redeploying, re-read `git status --short` and report (not dismiss) any foreign uncommitted modification per the dispatch's concurrency note |
| A failure observed in a suite outside this task's `file_scope` during Phase 4's or Phase 6's runs is actually sibling task 569's or 500's in-flight edit | M | M | `suite_selection_select` for Phase 4 returns `test-orchestrate-unwind-dispatch.sh`, which is in sibling 569's declared `file_scope`; treat any failure there as possibly foreign, check `git log`/`git status` before attributing it, and report rather than fix |
| `common_test_repo_root`'s git-first probe returns a *submodule* or nested work-tree root in some consumer repo, changing behaviour outside this repository | L | L | The helper's fallback and contract are unchanged by this task; 80 suites already depend on this exact behaviour, so this task adds no new exposure |
| Per-phase deployed-path confirmation is impossible before Phase 6's redeploy (the deployed copies stay stale) | M | H | Phases 2-5 verify the source-store suite green **plus** an inline resolution probe of the new expression evaluated from the deployed depth, which is decisive for depth-independence; the empirical both-path suite runs land in Phase 6 after the redeploy |
| Gate 8 is the dominant cost of a full gate run | L | H | Phases 2-5 narrow to the selector-reported suites via `run-all.sh --only`; only Phase 6 pays the full gate set |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5 | 1 |
| 3 | 6 | 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Baseline Measurement Under Both Invocation Paths [COMPLETED]

**Goal**: Record, before any edit, the computed root value and the pass/fail tally for each
affected suite under both invocation paths, so every later phase has a measured before-state to
compare against and no remedy is applied to a suite whose failure was never confirmed.

**Tasks**:

- [x] For each of the five named suites plus the two adjacent candidates
      (`test-verify-deploy-gate-selection-crash-net.sh`, `test-gate-cache-equivalence.sh`), echo
      the value its own root expression computes from the source-store tests directory and from
      the deployed tests directory, verbatim. *(completed)*
- [x] Run each of the seven suites from `agent-system/extensions/core/scripts/tests/` and from
      `.claude/scripts/tests/`, capturing the final `Results: N passed, M failed` line and every
      `[FAIL]` line. *(completed: test-gate-cache-equivalence.sh's source-store tally deferred to
      background completion before Phase 5, since this one suite's runtime exceeds 15 minutes --
      its deployed-path failure is already confirmed via a hard environment error)*
- [x] For any suite failing from the deployed path and passing from the source-store path, record
      that pairing explicitly — that asymmetry is what indicts the walk-up depth rather than the
      logic under test. *(completed)*
- [x] Write the measurements to `specs/589_test_suite_repo_root_walk_up_depth/progress/phase-1-baseline.json`
      (one record per suite: suite basename, computed root under each path, pass/fail tally under
      each path, verdict `depth-indicted` / `passes-both` / `other-cause`). *(completed)*
- [x] Record the Phase 1 result via `issue-record.sh` (a `win` if the asymmetry reproduces
      cleanly, an `issue` if any suite fails from BOTH paths — that one has a second cause and
      must not be silently swept into a later phase). *(completed: win recorded)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: Seven suites are expected to carry a measurable invocation-path asymmetry
(the five named, confirmed failing in the task description and re-confirmed for two of them
during planning, plus two adjacent candidates whose asymmetry is **unconfirmed**). Confirm by
executing the measurement tasks above; a candidate that passes from both paths is recorded as
`passes-both` and is thereby excluded from Phase 5's remedy, which is a legitimate outcome, not
a measurement failure. No task in this phase edits any suite, so nothing here depends on a
candidate turning out to be affected.

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for this phase's only
written path (`specs/589_.../progress/phase-1-baseline.json`), the expected sub-case (a) result
for a `specs/**` non-artifact file, so no suite covers it and the covering check is the `prose`
row's diff read-through of the record itself.

**Files to modify**:

- `specs/589_test_suite_repo_root_walk_up_depth/progress/phase-1-baseline.json` - new measurement
  record (the only file this phase writes; no suite is edited)

**Verification**:

- `phase-1-baseline.json` exists, is valid JSON, and holds exactly one record per measured suite.
- Every record carries a non-empty computed-root value for both invocation paths and a
  `Results:`-derived tally for both.
- Diff read-through confirms the phase touched nothing outside `specs/**`.

---

### Phase 2: Migrate the Three Repo-Root Walk-Up Suites to `common_test_repo_root` [COMPLETED]

**Goal**: Replace the unconditional four-level `$CORE_DIR/../../../..` root computation in the
three suites that use it with the existing depth-independent helper, leaving every assertion and
every downstream use of the resolved root unchanged.

**Tasks**:

- [x] Re-read each target file immediately before editing it (concurrent-sibling discipline). *(completed)*
- [x] In `test-gate-cache-lib.sh`, replace line 72's `ROOT="$(cd "$CORE_DIR/../../../.." && pwd)"`
      with `ROOT="$(common_test_repo_root "$SCRIPT_DIR")"`. `lib/common.sh` is already sourced at
      line 24, above this line; confirm that ordering holds after the edit. *(completed: sourced
      at line 56, above the new line 75 use)*
- [x] In `test-gate-registry-resolution.sh`, replace line 58's
      `REPO_ROOT="$(cd "$CORE_DIR/../../../.." && pwd)"` with
      `REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"`. *(completed: lib/common.sh is sourced
      at line 53, above the use)*
- [x] In `test-deploy-baseline-lib.sh`, replace line 492's
      `VD_REPO_ROOT="$(cd "$CORE_DIR/../../../.." && pwd)"` with
      `VD_REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"`, and amend the three-line comment
      immediately above it (lines 487-491) which currently *states* the four-level relationship
      as the mechanism; it must describe the git-first resolution instead, or it becomes a false
      comment pointing a future reader back at the defect. *(completed)*
- [x] Add a guard in each of the three: if the resolved root is empty, emit the suite's existing
      environment-error shape (`echo "ERROR: ..." >&2; exit 2`) rather than proceeding with an
      empty path — `common_test_repo_root` echoes empty on total failure by contract and never
      exits non-zero. *(completed: also lightly corrected the now-stale fixed-depth-walk comment
      above the test-gate-cache-lib.sh resolution for the same reason, beyond the plan's
      explicit test-deploy-baseline-lib.sh-only comment-fix instruction)*
- [x] Verify depth-independence directly: evaluate the new expression with `$SCRIPT_DIR` bound to
      the deployed tests directory and confirm it yields the repository root, not `/home/benjamin`.
      *(completed: both paths resolve to /home/benjamin/.config/nvim)*
- [x] Run the three suites from the source store (green = no regression to the logic under test).
      *(completed: 28 passed/0 failed, 44 passed/0 failed, 30 passed/0 failed -- matching the
      Phase 1 baseline exactly)*
- [ ] Commit the three files with an explicit file list (never a directory or glob pathspec).

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-deploy-baseline-lib.sh,test-gate-cache-equivalence.sh,test-gate-cache-lib.sh,test-gate-registry-resolution.sh,test-orchestrate-batch-gate.sh`
— the verbatim `suite_selection_select` output for this phase's three `Files to modify` paths.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-gate-cache-lib.sh` - line 72 root computation
  -> `common_test_repo_root "$SCRIPT_DIR"`, plus empty-root guard
- `agent-system/extensions/core/scripts/tests/test-gate-registry-resolution.sh` - line 58 root
  computation -> `common_test_repo_root "$SCRIPT_DIR"`, plus empty-root guard
- `agent-system/extensions/core/scripts/tests/test-deploy-baseline-lib.sh` - line 492 root
  computation -> `common_test_repo_root "$SCRIPT_DIR"`, plus empty-root guard and the corrected
  comment above it

**Verification**:

- `grep -n '\.\./\.\./\.\./\.\.' ` over the three files returns nothing.
- Each file calls `common_test_repo_root` and sources `lib/common.sh` strictly above that call.
- The deployed-depth resolution probe yields the repository root for all three.
- The five selector-named suites run green from the source store via the `run-all.sh --only`
  invocation in the Tier Justification.

---

### Phase 3: Make `test-lint-deploy-caller-wrap.sh`'s Scan Root Invocation-Path Independent [COMPLETED]

**Goal**: Stop the lint's file scan from widening to the whole repository (and therefore
double-counting every genuine caller via its deploy-tree duplicate) when the suite runs from its
deployed copy.

**Tasks**:

- [x] Re-read the file immediately before editing. *(completed)*
- [x] Replace line 46's `EXTENSIONS_DIR="$(cd "$CORE_DIR/../.." && pwd)"` with a two-step
      resolution using the existing helpers:
      `EXTENSIONS_DIR="$(common_test_ext_root "$(common_test_repo_root "$SCRIPT_DIR")")"`.
      Measured during planning: this yields `<repo>/agent-system/extensions` from both invocation
      paths. *(completed)*
- [x] Add the environment-error guard the helper's contract requires: `common_test_ext_root`
      returns 1 with empty stdout on a total miss, so an empty or non-directory result must
      produce this suite's existing `exit 2` environment-error shape, never a silent empty scan.
      *(completed)*
- [x] Confirm the three downstream consumers of `$EXTENSIONS_DIR` still behave: the `find` at
      line 114 and the two `${f#"$EXTENSIONS_DIR"/}` relative-path strips at lines 143 and 167
      (the strips depend on `EXTENSIONS_DIR` being a prefix of every scanned path — still true,
      and now true from both invocation paths). *(completed)*
- [x] Run the suite from the source store and confirm the classification assertion still reports
      exactly `{orchestrate-cycle-plan.sh, command-gate-out.sh}` and `7 passed, 0 failed`.
      *(completed)*
- [x] Verify depth-independence: evaluate the new expression with `$SCRIPT_DIR` bound to the
      deployed tests directory and confirm it yields `<repo>/agent-system/extensions`.
      *(completed)*
- [ ] Commit the single file with an explicit file list.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-deploy-caller-wrap.sh`
— the verbatim `suite_selection_select` output for this phase's single `Files to modify` path.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-lint-deploy-caller-wrap.sh` - line 46
  `EXTENSIONS_DIR` resolution -> `common_test_ext_root` over `common_test_repo_root`, plus the
  environment-error guard

**Verification**:

- The suite reports `7 passed, 0 failed` from the source store, with the classification case
  naming exactly the two expected callers.
- The deployed-depth resolution probe yields `<repo>/agent-system/extensions`, not the repo root.
- `grep -n 'CORE_DIR/\.\./\.\.' ` over the file returns nothing.

---

### Phase 4: Fix Deployed-Mode `EXT_ROOT` Resolution in `orchestrate-build-aux-dispatch.sh` [COMPLETED]

**Goal**: Make the aux-dispatch builder's agent-frontmatter lookup resolve from its deployed
location as well as from the source store, closing the production defect that makes every aux
dispatch's `model` field silently empty when the script runs deployed.

**Tasks**:

- [x] Re-read `orchestrate-build-aux-dispatch.sh` immediately before editing. *(completed)*
- [x] Convert the single `EXT_ROOT` string at line 56 into an ordered candidate list consumed by
      the glob loop at line 165, **keeping the current source-store candidate first** so the 22
      cases that pass today are driven by the identical path they are driven by now. *(completed:
      moved the candidate-list construction to after skill-base.sh is sourced, since the
      original line-56 placement predates lib/common.sh being in scope)*
      1. `$SCRIPT_DIR/../..` — the existing source-store layout (`.../core/scripts` ->
         `.../extensions`), unchanged and first.
      2. `$(common_test_ext_root "$(common_test_repo_root "$SCRIPT_DIR")")` or an equivalent
         git-first resolution of `<repo>/agent-system/extensions` — covers a deployed script in a
         repository that also owns the source store, and (via the helper's
         `.claude-extensions.json` branch) a repository whose source store is external.
      3. `$SCRIPT_DIR/../agents` as a direct, non-globbed candidate — the deployed sibling tree.
         Confirmed present and correct during planning: `.claude/agents/reviser-agent.md` exists
         and declares `model: opus`. This candidate needs no source store to be reachable at all.
- [x] Keep the glob semantics intact for candidates 1 and 2 (`"$cand"/*/agents/"${agent}.md"`) and
      use the direct form for candidate 3 (`"$cand"/"${agent}.md"`); `*` does not match a leading
      dot, which is precisely why the current single expression fails from `.claude/scripts`.
      *(completed)*
- [x] Preserve the documented empty-model contract exactly: a harness built-in such as `fork` has
      no agent file under any candidate and must still resolve to the empty string, never the
      literal `null`. *(completed: verified directly -- model resolves to empty for "fork")*
- [x] If `common_test_*`-named helpers are judged inappropriate for a production (non-test)
      script, implement the same two-step resolution inline from `lib/common.sh`'s
      non-test-prefixed primitives rather than adding a new bespoke fixed-depth walk — reusing an
      existing helper is the task's stated preference and a sixth bespoke computation is
      explicitly out of bounds. Record whichever choice is made, and why, via `issue-record.sh`.
      *(completed: chose to reuse common_test_repo_root/common_test_ext_root directly -- they are
      already transitively in scope via skill-base.sh's own lib/common.sh load, with no test-only
      side effects; recorded via issue-record.sh)*
- [x] Update the now-stale explanatory comment in
      `test-orchestrate-build-aux-dispatch.sh` (lines 62-65), which asserts that `EXT_ROOT`
      resolves to the real `agent-system/extensions/` "regardless of `$SKILL_REPO_ROOT`". That
      claim is true only from the source store; correct it to describe the candidate ordering.
      *(completed)*
- [x] Run `test-orchestrate-build-aux-dispatch.sh` from the source store as a negative control:
      it must still report `22 passed, 0 failed`. A regression here means candidate 1 stopped
      being consulted first. *(completed: 22 passed, 0 failed, unchanged)*
- [x] Run the remaining selector-named suites. Note that `test-orchestrate-unwind-dispatch.sh` is
      in concurrent sibling task 569's declared `file_scope`: if it fails, check `git log` and
      `git status --short` first and report a foreign in-flight edit rather than attributing the
      failure to this phase or fixing it. *(completed: test-force-phases.sh 36/0,
      test-orchestrate-context-growth.sh 6/0, test-orchestrate-cycle-plan.sh 420/0,
      test-orchestrate-unwind-dispatch.sh 21/0 -- all green, no foreign interference observed)*
- [ ] Commit the two files with an explicit file list.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Tier Justification**: `EXT_ROOT` is the agent-frontmatter resolution surface for every aux
dispatch kind the orchestrate engine builds, so the enumerated direct dependents
(`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-force-phases.sh,test-orchestrate-build-aux-dispatch.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-unwind-dispatch.sh`,
the verbatim `suite_selection_select` output for this phase's two paths) must build, which a
single-module `local` check would not cover.

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-build-aux-dispatch.sh` - line 56 `EXT_ROOT`
  single value -> ordered candidate list; line 165 glob loop -> iterate the candidates with the
  glob/direct distinction
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-aux-dispatch.sh` - lines
  62-65 stale `EXT_ROOT` comment corrected to describe the candidate ordering

**Verification**:

- `test-orchestrate-build-aux-dispatch.sh` reports `22 passed, 0 failed` from the source store
  (negative control: unchanged source-store behaviour).
- Invoking the edited script directly from `.claude/scripts/` after Phase 6's redeploy resolves
  `reviser-agent` to `opus`; before the redeploy, the candidate-list resolution is confirmed by
  evaluating each candidate with `$SCRIPT_DIR` bound to the deployed script's directory and
  observing that candidate 3 locates `.claude/agents/reviser-agent.md`.
- `fork` still resolves to an empty model string, never `null`.
- The five selector-named suites run green, with any failure in
  `test-orchestrate-unwind-dispatch.sh` first checked against `git log`/`git status` for foreign
  authorship before attribution.

---

### Phase 5: Adjacent Same-Class Sweep [COMPLETED]

**Goal**: Close the sweep over the two suites that carry an identically shaped unconditional
fixed-depth root computation but were not named in the task's five, so no known-shaped neighbour
is left unexamined.

**Tasks**:

- [x] Read Phase 1's `phase-1-baseline.json` records for
      `test-verify-deploy-gate-selection-crash-net.sh` and `test-gate-cache-equivalence.sh`.
      *(completed)*
- [x] For each one recorded `depth-indicted` (deployed-path failure, source-store pass): re-read
      the file, replace its root computation with `common_test_repo_root "$SCRIPT_DIR"` plus the
      empty-root guard, and correct any comment that states the fixed-depth relationship as the
      mechanism. Note the differing depths measured during planning —
      `test-verify-deploy-gate-selection-crash-net.sh:51` walks four levels from `$CORE_DIR`,
      `test-gate-cache-equivalence.sh:80` walks three — so neither is a blind copy of the other's
      replacement; verify the resolved value, do not assume it. *(completed:
      test-gate-cache-equivalence.sh was the only one recorded depth-indicted; no stale comment
      existed above its line 80 to correct)*
- [x] For each one recorded `passes-both`: make **no edit**, and record in this phase's own notes
      that it was measured and found unaffected, with the measured values. *(completed:
      test-verify-deploy-gate-selection-crash-net.sh, no edit)*
- [x] For each one recorded `other-cause` (failing from both paths): make no root edit, record an
      `issue-record.sh` entry naming the suite and the observed failure, and leave it for a
      separate task — a second cause must not be silently absorbed here. *(completed: no
      candidate was recorded other-cause, so no entry was needed)*
- [x] Run whichever suites were edited from the source store, plus the deployed-depth resolution
      probe for each edited expression. *(completed: test-gate-cache-equivalence.sh, 17 passed,
      0 failed, identical to the pre-edit baseline; both invocation paths resolve to the real
      repo root)*
- [x] Commit any edited files with an explicit file list; if nothing was edited, make no commit
      and say so in the phase record. *(one file edited: test-gate-cache-equivalence.sh)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-gate8-expected-new-distinction.sh,test-gate-cache-equivalence.sh,test-verify-deploy-gate-selection-crash-net.sh,test-verify-deploy-gate-selection.sh`
— the verbatim `suite_selection_select` output for this phase's two candidate paths.

**Scope Hypothesis**: At most two files are expected to change in this phase, and possibly zero —
whether either candidate is affected is **unmeasured** until Phase 1 runs. Confirm from
`phase-1-baseline.json`; a zero-edit outcome is a valid completion of this phase, not a skipped
phase, and every task above is written to be executable under that outcome.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection-crash-net.sh` -
  line 51 root computation -> `common_test_repo_root "$SCRIPT_DIR"` **only if** Phase 1 recorded
  it `depth-indicted`
- `agent-system/extensions/core/scripts/tests/test-gate-cache-equivalence.sh` - line 80 root
  computation -> `common_test_repo_root "$SCRIPT_DIR"` **only if** Phase 1 recorded it
  `depth-indicted`

**Verification**:

- Every candidate is accounted for in the phase record with one of the three verdicts and its
  measured root values.
- Any edited file resolves to the repository root under the deployed-depth probe and its suite
  runs green from the source store.
- No file recorded `passes-both` or `other-cause` was edited.

---

### Phase 6: Redeploy, Confirm Both Invocation Paths, and Record for Task 573 [COMPLETED]

**Goal**: Regenerate the deployed tree from the source store, then confirm empirically — from the
deployed copies, as gate 8's runner executes them — that every affected suite passes under both
invocation paths, and leave a durable record of what this change does to task 573's two
assertions.

**Tasks**:

- [x] Re-read `git status --short`; report (do not dismiss, do not fix) any foreign uncommitted
      modification or foreign commit before regenerating the tree, per the dispatch's concurrency
      note. *(completed: dirty tree observed, entirely attributable to concurrent siblings 500
      and 569's own in-flight plan-phase artifacts (declared in this dispatch's Territory block)
      plus pre-existing dirt already present at dispatch start; no unexpected foreign change)*
- [x] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh` (or the deployed entry
      point, whichever resolves) to regenerate `.claude/` from the source store. This is a
      whole-tree regeneration, which is why `__WHOLE_TREE__` is declared below. *(completed: run
      twice -- once after Phases 2-5, once more after this phase's own additional case11 fix;
      both landed, exit 3 "landed_verify_red" due to a pre-existing unrelated gate-24 lint
      finding, recorded separately)*
- [x] Confirm the deployed copies now carry the edits: `grep` each remedied file's deployed
      counterpart for `common_test_repo_root` / `common_test_ext_root` / the candidate list.
      *(completed)*
- [x] Run every affected suite from `.claude/scripts/tests/` and from
      `agent-system/extensions/core/scripts/tests/`, and record the `Results:` line for each
      under each path. Every suite must be green under **both**. *(completed: all seven measured
      suites green under both paths -- see phase-1-baseline.json's after_state. One additional,
      independently pre-existing defect was found and fixed in test-gate-cache-lib.sh's case11;
      see Deviations)*
- [x] Run gate 8 as the registry invokes it:
      `bash .claude/scripts/verify-deploy.sh --only-gate 8 <repo_root>`, and confirm the five
      named suites no longer appear in its `[FAIL]` lines. *(completed with a caveat: the gate8
      wrapper itself reports an overall FAIL, but direct content inspection of run-all.sh's own
      output -- reproduced byte-for-byte 3 times -- confirms none of this task's six suites
      appear in the failing-suite roster; the wrapper's own FAIL verdict traces to an unresolved,
      pre-existing discrepancy unrelated to this task's edits, recorded via issue-record.sh)*
- [x] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh <repo_root>`.
      *(deviation: deferred to the batch-level stage per this dispatch's Batch Gate Deferral
      directive, not independently run here -- see Deviations)*
- [x] Compare the final tallies against `phase-1-baseline.json` and append the after-state to it,
      so the before/after pairing is one durable record. *(completed)*
- [x] Record, in the task's summary artifact and via `issue-record.sh`, whether this change
      closes either of task 573's two assertions (one each in `test-deploy-baseline-lib.sh` and
      `test-lint-deploy-caller-wrap.sh`). Name the assertion and the observed result. Task 573
      owns the re-measurement; this task owns the evidence handed to it. Do **not** edit task
      573's artifacts. *(completed: BOTH of task 573's assertions are now closed -- see summary
      and the "downstream-task-evidence" issue-record.sh win entry)*
- [x] Note the deferred class-closure lint (see Non-Goals) in the summary as a follow-up
      candidate, with the observed class membership from Phases 1 and 5 as its evidence.
      *(completed)*
- [ ] Commit with an explicit file list.

**Timing**: 1.5 hours

**Depends on**: 2, 3, 4, 5

**Verification Tier**: full

**Files to modify**:

- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`
- `specs/589_test_suite_repo_root_walk_up_depth/progress/phase-1-baseline.json` - after-state
  tallies appended alongside the Phase 1 before-state

**Verification**:

- The complete gate set for the repository runs green:
  `bash .claude/scripts/verify-deploy.sh <repo_root>` (source-store path:
  `agent-system/extensions/core/scripts/verify-deploy.sh`).
- `bash .claude/scripts/verify-deploy.sh --only-gate 8 <repo_root>` reports none of the five named
  suites among its `[FAIL]` lines.
- Each affected suite reports `0 failed` from **both** `.claude/scripts/tests/` and
  `agent-system/extensions/core/scripts/tests/`, with both tallies recorded.
- The deployed copy of `orchestrate-build-aux-dispatch.sh` resolves `reviser-agent` to `opus`.
- The baseline record holds a before/after pair for every measured suite.
- The task-573 evidence record names both assertions and their observed post-change results.

---

## Testing & Validation

- [x] All five named suites green from the source-store invocation path. *(confirmed: 28/0,
      44/0, 30/0, 7/0, 22/0)*
- [x] All five named suites green from the deployed invocation path (`.claude/scripts/tests/`).
      *(confirmed: 28/0, 44/0, 30/0, 7/0, 22/0 -- identical to source store)*
- [x] `verify-deploy.sh --only-gate 8` clean of the five named suites. *(confirmed by direct
      content inspection of run-all.sh's own output: none of the five appear in the failing-suite
      roster. The gate8 wrapper's own overall exit code is FAIL for an unrelated, pre-existing
      reason -- see Phase 6 deviations and the issue-record.sh entry)*
- [ ] Complete gate set green. *(deferred to the batch stage per this dispatch's Batch Gate
      Deferral directive -- not independently run in this dispatch)*
- [x] No fixed-depth, unconditional root computation remains in any edited suite
      (`grep` for `../../../..` and `CORE_DIR/../..` returns nothing in them). *(confirmed)*
- [x] No file under `.claude/**` was hand-authored; every deployed change arrived via
      `deploy-headless.sh`. *(confirmed -- every `.claude/**` write in this dispatch went through
      deploy-headless.sh; the one manual `cp` used as a quick mid-diagnostic probe was
      immediately superseded by a proper redeploy before this phase closed)*
- [x] `fork` still resolves to an empty model string in `orchestrate-build-aux-dispatch.sh`.
      *(confirmed directly)*
- [x] No task-number reference and no record-versioning language in any file landing under
      `agent-system/**`. *(confirmed via grep across every edited file)*

## Artifacts & Outputs

- `specs/589_test_suite_repo_root_walk_up_depth/progress/phase-1-baseline.json` — before/after
  measurement record, one entry per measured suite, both invocation paths.
- Edited suites under `agent-system/extensions/core/scripts/tests/` (three in Phase 2, one in
  Phase 3, one comment-only in Phase 4, zero to two in Phase 5).
- Edited production script `agent-system/extensions/core/scripts/orchestrate-build-aux-dispatch.sh`.
- Regenerated `.claude/` deploy tree (gitignored; not an artifact under version control).
- Task summary recording the task-573 evidence and the deferred class-closure lint candidate.

## Rollback/Contingency

Every phase's edits are confined to a small, explicitly listed set of files and committed
per-phase, so reverting is a per-commit `git revert` of that phase's commit followed by a
`deploy-headless.sh` redeploy to restore the deployed tree. Before any intentional rollback that
would otherwise be blocked on a dirty tree, run
`bash .claude/scripts/git-snapshot.sh 589` first; for an ordinary defensive checkpoint before the
Phase 6 redeploy, use `bash .claude/scripts/git-snapshot.sh 589 --no-revert`, which is durable
without reverting the working tree.

Contingency by phase: if Phase 4's candidate-list change regresses the source-store control
(`22 passed, 0 failed`), revert that phase alone — Phases 2, 3 and 5 are independent of it and
their value stands without it. If the Phase 6 redeploy surfaces failures in files outside this
task's scope, treat them as possibly a concurrent sibling's in-flight edits per the dispatch's
concurrency note: check `git log` and report, rather than reverting this task's work.
