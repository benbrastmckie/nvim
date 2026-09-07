# Implementation Plan: Task #169

- **Task**: 169 - Add a positive-direction memory-pressure case to test-lake-build-guard.sh
- **Status**: [IMPLEMENTING]
- **Effort**: 1.75 hours
- **Dependencies**: None (builds on already-landed commit `878043472`)
- **Research Inputs**: `specs/169_lake_guard_pressure_detection_case/reports/01_pressure-detection-case.md`
- **Artifacts**: plans/01_pressure-detection-case.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Commit `878043472` isolated `test-lake-build-guard.sh` from ambient host memory state by
exporting `LAKE_BUILD_GUARD_PSI_PATH` / `LAKE_BUILD_GUARD_MEMINFO_PATH` suite-wide to clean
fixture files. That fix is correct and stays. It leaves one gap: with a clean fixture as the
suite-wide default and no case driving the pressured direction, a regression that disabled
pressure detection entirely would still show every case green. This plan adds a single new
numbered case that asserts the guard's preflight DOES fire on a pressured meminfo fixture, plus
a scripted mutation check proving the new case is non-vacuous, plus a robustness check that the
suite survives an ambient-pressured host. No file outside
`agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` is modified.

### Research Integration

Key findings carried into the phase design:

- The values to assert live in `agent-system/extensions/core/scripts/lake-build-guard.sh`:
  `cmd_preflight()` exits `11` and prints `lake-build-guard: memory pressure detected:` followed
  by one `  - {reason}` line per triggered reason; `check_memory_pressure()` builds those reason
  strings from `MEM_AVAILABLE_RATIO_THRESHOLD` and `SWAP_USED_RATIO_THRESHOLD`. These are read
  from the script under test at implementation time, never transcribed from prose.
- Case 11 (`LAKE_BUILD_GUARD_PSI_PATH="$WORKDIR/does-not-exist-psi" run_guard ...`) is the exact
  per-invocation local-override idiom to copy. Case 10 supplies the stderr-capture idiom
  (`2>"$WORKDIR/c10.err"`) the new case needs, since Case 11 discards stderr.
- Only `LAKE_BUILD_GUARD_MEMINFO_PATH` needs local overriding. Leaving `LAKE_BUILD_GUARD_PSI_PATH`
  at the suite-wide clean fixture yields exactly the dispatch's reference behavior: rc=11 with
  both the MemAvailable and the swap-in-use reason, and no PSI reason.
- Pressured fixture values must be derived from the guard's own threshold constants (grep'd out
  of `$GUARD` at run time), following the existing in-suite precedent of cases 12 and 13, which
  already grep facts out of `$GUARD` rather than hardcoding them.
- The suite's existing Mutation A-E block (`$MUTANT_DIR`, `sed`-patched guard copies) is the
  established, re-runnable mechanism for non-vacuousness. A new Mutation F neutering
  `check_memory_pressure()` fits that pattern exactly and never writes outside the mktemp workdir.
- Baseline confirmed live during research: `Passed: 27 / Failed: 0`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap path was supplied in the dispatch context; no ROADMAP.md was consulted.

## Goals & Non-Goals

**Goals**:
- Add one numbered case asserting `preflight` exits with the guard's documented pressure return
  code and names both meminfo-derived reasons when fed a pressured fixture.
- Derive the pressured fixture's values from the guard's own threshold constants, read at run
  time, so the case survives a deliberate threshold retune.
- Prove non-vacuousness with a scripted mutation that neuters pressure detection and turns only
  the new case red.
- Keep the suite green on a host that is itself under memory/swap pressure.
- Leave the suite's header comments accurate now that the "no case asserts pressure IS detected"
  statement is no longer true.

**Non-Goals**:
- Any change to `lake-build-guard.sh` — its logic, its reason strings, or its threshold constants.
- Any weakening, raising, or bypassing of `SWAP_USED_RATIO_THRESHOLD`,
  `MEM_AVAILABLE_RATIO_THRESHOLD`, or the PSI thresholds.
- Any edit under `.claude/**` (disposable deploy artifact; source store is
  `agent-system/extensions/core/**`).
- Reverting, redoing, or reshaping commit `878043472`'s suite-wide clean-fixture isolation.
- Adding PSI-derived pressure assertions (out of scope; the meminfo pair is sufficient and is the
  dispatch's stated reference behavior).
- Committing the neutered guard as a file — the mutant exists only in `$MUTANT_DIR` at run time.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Fixture ratios land exactly on a threshold boundary due to integer-truncating `$(( ))` division | M | M | Use `MemTotal`/`SwapTotal` that are exact multiples of 100; target ratios `THRESH/2` and `(THRESH+100)/2` so both sit comfortably past the boundary, never on it |
| Reason strings or return code transcribed from the dispatch/report prose instead of the script | H | M | Phase 1 reads them out of `lake-build-guard.sh` directly and records the literals; assertions match on substrings taken from that reading |
| Mutation F's `sed` pattern silently fails to match, making the mutation a false-negative no-op | M | L | Follow the Mutation A-E precedent: assert the OPPOSITE outcome and report "inconclusive (sed pattern did not match)" via `fail()` rather than a silent skip |
| The new case accidentally mutates the suite-wide exports instead of overriding per-invocation | H | L | Copy Case 11's env-var-prefix-on-the-invocation-line shape verbatim; Phase 2 verification greps that lines 104-105 are unchanged |
| Temptation to adjust a guard threshold to make the case pass | H | L | Explicit non-goal; Phase 2 and Phase 5 verification both include a `git diff --stat` check that `lake-build-guard.sh` is untouched |
| Final pass count differs from the dispatch's "expect 28/28 or more" floor | L | M | Treat the count as a hypothesis (see Scope Hypothesis lines), confirm empirically, and reconcile the header comment's case count in Phase 5 |

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

### Phase 1: Ground-Truth Confirmation and Baseline Capture [COMPLETED]

**Goal**: Read the exact return code, reason-string literals, and threshold constant names out of
`lake-build-guard.sh` itself, and record the suite's current pass/fail baseline. No edits.

**Tasks**:
- [x] Read `check_memory_pressure()` in
      `agent-system/extensions/core/scripts/lake-build-guard.sh` and record the two
      meminfo-derived reason-string templates verbatim, along with the exact names and current
      values of `MEM_AVAILABLE_RATIO_THRESHOLD` and `SWAP_USED_RATIO_THRESHOLD`. *(completed: MEM_AVAILABLE_RATIO_THRESHOLD=10, SWAP_USED_RATIO_THRESHOLD=50)*
- [x] Read `cmd_preflight()` and record the exact pressure exit code and the exact header line it
      prints to stderr. *(completed: exit 11, header 'lake-build-guard: memory pressure detected:')*
- [x] Confirm which meminfo keys `check_memory_pressure()` actually reads (so the fixture supplies
      those and only those). *(completed: MemTotal, MemAvailable, SwapTotal, SwapFree)*
- [x] Confirm the grep-extractable shape of both threshold assignments (anchored `^NAME=` at line
      start), so the test can read them at run time. *(completed)*
- [x] Run `bash agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` and record the
      exact `Passed:` / `Failed:` numbers as the baseline. *(completed: Passed: 27 / Failed: 0)*

**Timing**: 0.25 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Research reports the baseline as `Passed: 27 / Failed: 0`, exit code `11`,
thresholds `10` and `50`. Every one of these is a hypothesis. Confirm each by direct reading of
`lake-build-guard.sh` and by an actual suite run before Phase 2 consumes them; if any differs,
Phase 2 uses the observed value, not the value written here.

**Files to modify**: none (read-only phase).

**Verification**:
- The recorded reason-string templates, exit code, and threshold names are quoted from the script,
  not paraphrased.
- The baseline `Passed:`/`Failed:` line is captured from a real run.
- `git status --short` shows no modifications.

---

### Phase 2: Add Pressured Fixture and the Positive-Direction Case [COMPLETED]

**Goal**: Add one new numbered case to `test-lake-build-guard.sh` that writes a pressured meminfo
fixture into the existing mktemp workdir, overrides `LAKE_BUILD_GUARD_MEMINFO_PATH` on a single
`run_guard ... preflight` invocation only, and asserts the guard's documented pressure return code
plus both meminfo-derived reason substrings on stderr.

**Tasks**:
- [x] At the new case's own site (not up with the suite-wide clean fixtures), grep both threshold
      constants out of `$GUARD` at run time into local variables. *(completed)*
- [x] Derive target ratios from those constants: available-ratio target `THRESH/2` (strictly below
      the MemAvailable threshold), swap-used-ratio target `(THRESH+100)/2` (strictly above the
      swap threshold). Guard against a degenerate/unreadable grep result with a loud `fail()`
      rather than a silent fallback. *(completed: targets 5% and 75%)*
- [x] Write the pressured meminfo fixture (e.g. `$WORKDIR/fixture-meminfo-pressured`) using
      `MemTotal`/`SwapTotal` values that are exact multiples of 100 so the ratio arithmetic
      round-trips exactly, computing `MemAvailable` and `SwapFree` from the derived targets. *(completed)*
- [x] Build a fresh package root for the case via the suite's existing `build_fixture` helper. *(completed)*
- [x] Invoke the guard with a per-invocation env prefix in Case 11's shape:
      `LAKE_BUILD_GUARD_MEMINFO_PATH="$PRESSURED" run_guard "$ROOT" preflight`, capturing stderr to
      a workdir file in Case 10's shape and the exit code into a variable. *(completed)*
- [x] Assert the exit code equals the pressure return code recorded in Phase 1, and that the
      captured stderr contains both the MemAvailable reason and the swap-in-use reason, matched
      against substrings derived from the Phase 1 literals. *(completed: verified 28/28)*
- [x] Add a short comment above the case explaining that it is the positive-direction counterpart
      to the suite-wide clean default, and why the override is per-invocation. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts it adds exactly one new numbered case to exactly one file
and raises the pass count by exactly one. Confirm by diffing the file (single-file change) and by
comparing the post-change `Passed:` count against the Phase 1 baseline; if the delta is not
exactly +1, investigate before proceeding rather than accepting the number.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` - add the pressured
  fixture construction and the new numbered case, placed after the existing numbered cases and
  before the mutation section.

**Verification**:
- Full suite run passes with zero failures and a pass count exactly one greater than the Phase 1
  baseline.
- `grep -n '^export LAKE_BUILD_GUARD_' test-lake-build-guard.sh` still shows only the two original
  suite-wide exports, unchanged, pointing at the clean fixtures.
- `git diff --stat` shows `test-lake-build-guard.sh` as the only modified file;
  `lake-build-guard.sh` is untouched.
- The new case's assertion literals trace back to Phase 1's readings of the guard, and no
  threshold constant appears as a bare hardcoded number in the fixture math.

---

### Phase 3: Add Mutation F and Demonstrate Non-Vacuousness [COMPLETED]

**Goal**: Add a scripted mutation, in the existing Mutation A-E shape, that neuters
`check_memory_pressure()` so it always reports "no pressure", and assert that the new case's
pressured invocation then fails to detect pressure. Then run the full suite against the mutant to
demonstrate that only the new case goes red.

**Tasks**:
- [x] Add Mutation F to the existing mutation section: `sed`-patch a copy of `$GUARD` into
      `$MUTANT_DIR` so `check_memory_pressure()` unconditionally reports no pressure (clearing
      `PRESSURE_REASONS` and returning the no-pressure status), following Mutation B's
      function-shadowing shape. *(completed)*
- [x] Invoke the mutant against a fresh fixture root with the pressured meminfo fixture and assert
      the OPPOSITE of the real case's outcome (preflight now exits 0 with no reasons), so a
      matching mutation is a `pass()` and a non-matching `sed` is a loud, recorded `fail()` marked
      inconclusive — never a silent skip. *(completed)*
- [x] Perform the acceptance demonstration: build the same neutered guard once out-of-band, run the
      FULL suite against it, and confirm the new case — and only the new case — reports failure. *(completed: 28 passed / 1 failed, sole failure is case 22)*
- [x] Capture the demonstration's output (the failure line and the summary counts) for the
      implementation summary. *(completed)*
- [x] Confirm nothing neutered persists: no modified `lake-build-guard.sh` in the working tree, and
      no mutant file outside the suite's mktemp workdir. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts that exactly one case (the Phase 2 case) fails under the
neutered guard. Confirm by reading the full mutant-run output and enumerating every reported
failure, not by assuming; if any other case also fails, the mutation is too broad and must be
narrowed before the demonstration is recorded.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` - add Mutation F to the
  mutation section.

**Verification**:
- Full suite run passes with zero failures and a pass count one greater than the Phase 2 count.
- The out-of-band full-suite run against the neutered guard shows exactly one failure, and it is
  the new case.
- `git status --short` shows only `test-lake-build-guard.sh` modified; `lake-build-guard.sh` is
  clean.
- The demonstration output is captured verbatim for the summary.

---

### Phase 4: Ambient-Pressure Robustness Verification [COMPLETED]

**Goal**: Empirically confirm the dispatch's third acceptance bullet — that the suite still passes
on a host whose real memory state is pressured above the guard's own threshold — rather than
relying on an argument from construction alone.

**Tasks**:
- [x] Write a pressured meminfo file and a pressured PSI file outside the suite (in the session
      scratchpad) representing a host over the guard's thresholds. *(completed)*
- [x] Run the full suite with `LAKE_BUILD_GUARD_MEMINFO_PATH` and `LAKE_BUILD_GUARD_PSI_PATH`
      pre-set in the invoking environment to those pressured files, simulating the ambient
      condition that produced the original defect. *(completed)*
- [x] Confirm the suite's own suite-wide exports win and every case, including the new one, still
      passes with the same counts as the clean-environment run. *(completed: both runs 29/0)*
- [x] Record the two runs' summary lines side by side as the robustness evidence. *(completed)*

**Timing**: 0.25 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This phase assumes the suite-wide `export`s unconditionally override an
inherited environment value for both variables. Confirm empirically via the pressured-environment
run; if any case regresses, the isolation is weaker than believed and that finding is recorded
rather than worked around.

**Files to modify**: none (verification-only phase; scratch fixtures live in the session
scratchpad, never in the repository).

**Verification**:
- The pressured-environment full-suite run reports the same pass count and zero failures as the
  ordinary run.
- `git status --short` shows no additional modifications from this phase.

---

### Phase 5: Header-Comment Accuracy and Final Count Reconciliation [COMPLETED]

**Goal**: Update the suite's now-stale header comments so they describe the file as it actually is,
and reconcile the documented case count with the observed pass count.

**Tasks**:
- [x] Update the ambient-host-isolation comment block's closing statement — currently "No case in
      this suite asserts that pressure IS detected. Any future case that wants to test the positive
      direction must override these two variables locally..." — to state that the positive
      direction IS now covered, naming the new case and preserving the local-override guidance for
      future cases. *(completed)*
- [x] Update the file's top-of-script "Covers N acceptance-mapped cases" line to the new count. *(completed: 21 -> 22)*
- [x] Reconcile the header's stated case count against the observed `Passed:` total, noting in a
      comment how numbered cases and mutation checks each contribute, so the two numbers are no
      longer silently inconsistent. *(completed: 29 = 23 case-level passes (22 cases, case 12 splits into 12a/12b) + 6 mutation checks)*
- [x] Re-run the full suite one final time and record the final `Passed:` / `Failed:` line. *(completed: Passed: 29 / Failed: 0)*

**Timing**: 0.25 hours

**Depends on**: 3, 4

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts the final pass count is at least 28 (dispatch floor) and
most likely 29 (27 baseline + 1 case + 1 mutation). Confirm the actual number from the final suite
run and write that observed number into the header comment; never write the predicted number.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` - comment-only edits to the
  top-of-script header block and the ambient-host-isolation block.

**Verification**:
- Diff read-through confirms every changed hunk in this phase lies inside a `#` comment line.
- Final full-suite run passes with zero failures and a pass count meeting or exceeding the
  dispatch's 28 floor.
- The header's stated count matches the observed run.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` passes with zero
      failures and a pass count at or above the dispatch's 28 floor.
- [ ] The new case fails, and only the new case fails, when the guard's pressure detection is
      neutered (demonstrated by a full-suite run against a mutant guard).
- [ ] The suite passes with a pressured meminfo/PSI pair inherited from the invoking environment,
      confirming ambient-host isolation survives the addition.
- [ ] `lake-build-guard.sh` is byte-identical to its pre-task state (`git diff --stat` shows it
      untouched); no threshold constant was changed.
- [ ] No file under `.claude/**` was hand-authored or edited.
- [ ] The suite-wide `export LAKE_BUILD_GUARD_PSI_PATH` / `export LAKE_BUILD_GUARD_MEMINFO_PATH`
      lines still point at the clean fixtures and were not reassigned.

## Artifacts & Outputs

- Modified: `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` (one new numbered
  case, one new pressured fixture, one new scripted mutation, comment updates).
- Implementation summary at `specs/169_lake_guard_pressure_detection_case/summaries/01_*.md`,
  containing: the guard literals read in Phase 1, the before/after pass counts, the verbatim
  non-vacuousness demonstration output from Phase 3, and the ambient-pressure robustness evidence
  from Phase 4.

## Rollback/Contingency

All work is confined to a single test file with no production-code changes, so rollback is
`git checkout` of that one path (taking a snapshot first per the destructive-git rule if the tree
is dirty). Partial-failure contingencies:

- If the derived pressured fixture cannot trigger both reasons simultaneously (e.g. a future
  threshold combination makes them mutually exclusive), fall back to asserting the return code plus
  whichever reasons the guard actually emits, and record the divergence from the dispatch's stated
  reference behavior in the summary rather than adjusting any threshold.
- If Mutation F's `sed` cannot be made to match reliably, keep the new case (which is the actual
  deliverable) and record the non-vacuousness demonstration as a documented manual run in the
  summary instead of a scripted mutation, noting the limitation.
- If the ambient-pressure robustness run reveals a leak, stop and record the finding; do not patch
  around it inside this task's scope.
