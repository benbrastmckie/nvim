# Implementation Plan: Task #584

- **Task**: 584 - Wire covering-suite selection into Gate 8 so an extension change runs the affected suites, not all 195
- **Status**: [IMPLEMENTING]
- **Effort**: 5.5 hours
- **Dependencies**: Task 505 (completed - per-extension source-store resolution in the selector)
- **Research Inputs**: specs/584_gate8_covering_suite_selection/reports/01_gate8-suite-selection.md, specs/584_gate8_covering_suite_selection/reports/02_gate8-suite-selection.md
- **Artifacts**: plans/02_gate8-suite-selection.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Gate 8 (`gate8_run()` in `verify-deploy.sh`) invokes `tests/run-all.sh` with no `--only`, so any
change anywhere under `agent-system/extensions/**` pays the full shell-test battery. The
selector that maps touched paths to their covering suites (`suite_selection_select` in
`lib/suite-selection-lib.sh`) already exists, is per-extension-aware, and is already load-bearing
in `validate-artifact.sh` - but `verify-deploy.sh` never calls it. This plan adds an opt-in
touched-paths input to Gate 8, narrows its `run-all.sh` invocation through the selector when that
input is supplied, and closes the cache-correctness hole that narrowing would otherwise open.
Definition of done: `--gate8-touched` narrows Gate 8's battery, a narrowed run can never write a
full-corpus cache entry, the flag's absence leaves output byte-identical to today, and a
dedicated regression suite pins all three.

### Research Integration

From `reports/02_gate8-suite-selection.md`:

- The gate cache cannot supply a touched-path list (it persists one opaque aggregate hash per
  gate, never a per-file map), so the input must be supplied by the caller - this plan makes it an
  explicit flag rather than deriving it.
- `verify-deploy.sh`'s generic `--skip-unchanged` cache-write block is gate-agnostic: a narrowed
  Gate 8 run that passes cleanly would write a cache entry keyed by the **full** `@extensions`
  corpus digest, letting a later run skip Gate 8 entirely on the strength of a narrow pass. The
  forced-dirty guard (Phase 2) therefore lands in the same phase as the narrowing itself, never
  as a follow-on.
- `--skip-slow` and suite-level narrowing are orthogonal: `gate8_run()`'s `SKIP_SLOW` branch
  returns before `run-all.sh` is reached at all, so the two reductions gate mutually exclusive
  code paths and cannot compose into a third, undocumented reduction.
- `orchestrate-cycle-plan.sh`'s `verify-deploy.sh` calls all pass `--skip-slow` and are therefore
  irrelevant to this work. The call sites that would benefit are `orchestrate-batch-gate.sh`'s
  Move 4 and Mechanism A's `--only-gate 8` directive - both outside this task's `file_scope`.

### Carried-Figure Re-Validation (dispatch premise)

The dispatch's Premise Re-Validation block flagged two description lines. Both were re-derived
live at plan-authoring time (2026-11-16), against the source store, not carried on trust:

| Carried claim | Live result | Verdict |
|---|---|---|
| "17 of 28 gates declare `@extensions`", ids `3,5,6,7,8,11,12,13,17,18,19,20,21,23,24,26,28` | 17 gates, **exactly that id set**; registry now holds **29** gates, not 28 | id set CONFIRMED; denominator DRIFTED (28 -> 29) |
| `grep -cE "suite_selection\|suite-selection" verify-deploy.sh` | `0` | CONFIRMED unchanged |
| "all 149 suites" (task title/description) | **195** `test-*.sh` files across all 23 extensions | CORRECTED (research report 02 already caught this) |
| "SOURCE STORE IS THE EDIT TARGET: `agent-system/extensions/core/**`" | `.claude-extensions.json` `.extensions.core.source_dir` = `/home/benjamin/.config/nvim/agent-system/extensions/core` | CONFIRMED |

Re-derivation commands: `awk -F'\t' '!/^#/ && NF>=9 {n++; if ($9 ~ /@extensions/) e++}' gate-registry.data`;
`grep -cE "suite_selection|suite-selection" verify-deploy.sh`; a per-extension `test-*.sh` tally
over `scripts/tests/` + `scripts/`; `jq -r '.extensions.core.source_dir' .claude-extensions.json`.

### Prior Plan Reference

No prior plan. This is the task's first plan round.

### Roadmap Alignment

No `roadmap_path` was supplied in this dispatch; `specs/ROADMAP.md` was not consulted and is not
modified by this plan.

## Goals & Non-Goals

**Goals**:

- Give `gate8_run()` an opt-in `--gate8-touched PATH[,PATH...]` input that narrows its
  `run-all.sh` invocation to the touched paths' covering suites via `suite_selection_select`.
- Preserve byte-identical behavior and output on the flag's absence, for every caller that exists
  today.
- Guarantee a narrowed run can never become the basis for a future `--skip-unchanged` invocation
  skipping Gate 8 entirely (forced `GATE_DIRTY_LIST` membership on any narrowed run, pass or fail).
- Make a narrowed pass textually distinguishable from a full-battery pass in Gate 8's own output.
- Pin all of the above with a dedicated regression suite, and document the new input plus its
  coverage trade-off where a future reader will find it.

**Non-Goals**:

- Wiring any orchestrator call site to actually pass touched paths. `orchestrate-batch-gate.sh`
  (Move 4) and `orchestrate-build-dispatch.sh` (Mechanism A's directive) are outside this task's
  declared `file_scope` and inside concurrent sibling task 585's - see `## Decisions` D2.
- Narrowing Move 4's once-per-invocation battery. That is a coverage trade-off requiring a
  periodic full-sweep cadence that does not exist today - see `## Decisions` D3.
- Building any periodic/cadence full-sweep mechanism.
- Deriving touched paths inside `verify-deploy.sh` (from git, from the gate cache, or from
  `invocation_modified_files`). The input is caller-supplied, explicitly.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A narrowed clean pass writes a full-corpus `@extensions` cache entry, silently certifying suites that never ran | H | H (certain, absent the guard) | Phase 2 forces `gate8` onto `GATE_DIRTY_LIST` whenever `--only` was used, in the same phase (and same commit, via `atomic-batch`) as the narrowing |
| The selector resolves a suite basename `run-all.sh --only` then rejects as unknown | M | L | Both already share one discovery convention; Phase 3 pins a multi-extension narrowed invocation as a smoke test |
| Changing Gate 8's `pass()` string breaks existing assertions | M | M | Two suites assert the exact current string (`test-gate8-expected-new-distinction.sh`, `test-gate-lock.sh`); Phase 2 changes only the narrowed branch's message and leaves the unnarrowed string byte-identical |
| Sourcing the selector from the wrong tree gives roots that disagree with the `run-all.sh` being invoked | M | M | Source `$TARGET/agent-system/extensions/core/scripts/lib/suite-selection-lib.sh` (the library resolves its roots from its own `BASH_SOURCE[0]`), never `_VD_SCRIPT_DIR/lib/`, which is the deployed copy when verify-deploy.sh is invoked from `.claude/scripts/` |
| Machinery ships with no caller, delivering none of the stated cost benefit | M | M | Named explicitly as a non-goal, with the `dependencies[]` edge to 585 landed in Phase 5 so the follow-on is scheduled rather than assumed |
| A sibling task's concurrent edit to `verify-deploy.sh` collides | M | M | Re-read the file immediately before each edit; stage only this task's own hunks; never a directory or glob `git add` |

## Decisions

- **D1 - The input is an explicit CLI flag, not a derived value.** Research established the gate
  cache cannot supply a touched-path list, and the one real source
  (`invocation_modified_files`) lives in the orchestrator, outside this file. A flag keeps the
  whole change inside this task's `file_scope`, makes the default path provably inert, and passes
  through `deploy_findings_snapshot`'s existing verbatim argument forwarding unchanged when a
  caller is eventually wired.
- **D2 - Call-site wiring is deferred, with a scheduled edge rather than an implicit assumption.**
  `orchestrate-batch-gate.sh` and `orchestrate-build-dispatch.sh` are task 585's declared
  territory this same cycle. Phase 5 adds a `dependencies[]` edge so 585 runs after this
  machinery exists, per the territory contract's "add the edge, run as a sequence" rule.
- **D3 - Move 4 keeps full depth; the coverage trade-off is named, not defaulted into.** Narrowing
  Move 4 would end per-batch re-certification of the full battery, and no periodic full-sweep
  cadence exists to compensate. This plan therefore ships the machinery opt-in and leaves every
  current caller unnarrowed. Whoever wires Move 4 must either accept that trade-off explicitly or
  build the cadence first; neither is decided here.
- **D4 - A narrowed run is never cache-write-eligible.** Rather than teaching the generic
  `--skip-unchanged` write block about Gate 8's internals, Gate 8 marks itself dirty. This keeps
  the knowledge local to the gate that has it and leaves the gate-agnostic block untouched.

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Add the `--gate8-touched` input (parse and validate only) [COMPLETED]

**Goal**: `verify-deploy.sh` accepts and validates `--gate8-touched PATH[,PATH...]`, storing it in
a single variable that nothing yet reads - a parse-only, behavior-inert change.

**Tasks**:
- [x] Re-read `verify-deploy.sh`'s argument-parsing `while`/`case` loop immediately before editing
      (a sibling task may have touched the file this cycle). *(completed)*
- [x] Add a `GATE8_TOUCHED` variable beside the existing `GATE8_JOBS` declaration, defaulting to
      empty, and document it in the same block that documents `VERIFY_DEPLOY_GATE8_JOBS`.
      *(deviation: altered -- added a temporary `# shellcheck disable=SC2034`, to be removed in
      Phase 2 once gate8_run() reads GATE8_TOUCHED)*
- [x] Add a `--gate8-touched)` case arm: a missing or empty value exits 2 with a named error (and,
      under `--findings`, a `FINDING gate0` line), mirroring `--only-gate`'s own invalid-argument
      posture exactly. Accept a comma-separated list; do not validate path existence here (the
      selector's own fail-safe sentinel handles an unmappable or absent path). *(completed)*
- [x] Extend the file's usage line and add a header-doc section for the flag, stating: opt-in,
      defaults off, byte-identical output when absent, and that it narrows only Gate 8's internal
      `run-all.sh` invocation - never which gates run. *(completed)*
- [x] Confirm the inertness claim: with the flag absent, `GATE8_TOUCHED` is read nowhere, so no
      gate's behavior changes in this phase. *(completed: confirmed via smoke test -- flag parsed
      with a value and run proceeds byte-identically, exit 0)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Tier Justification**: Every hunk is confined to `verify-deploy.sh`'s own argument-parsing loop
and header documentation and changes no gate's behavior, so the covering check is
`bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 22 /home/benjamin/.config/nvim`
(shellcheck lint over the edited script) plus a direct `--gate8-touched` argument-handling smoke
run of the same script.

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` - new `GATE8_TOUCHED` variable, `--gate8-touched` case arm, usage line, header-doc section

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 22 /home/benjamin/.config/nvim` passes (shellcheck clean).
- `--gate8-touched` with no value exits 2 with the named error; with `--findings` it also emits a `FINDING gate0` line.
- `--gate8-touched a,b` parses and the run proceeds exactly as without it (flag still unread).

---

### Phase 2: Narrow Gate 8 through the selector, and forbid a narrowed run from writing a cache entry [COMPLETED]

**Goal**: `gate8_run()` resolves `GATE8_TOUCHED` through `suite_selection_select`, invokes
`run-all.sh --only <list>` when a real suite set comes back, falls back to today's unnarrowed
invocation on absence or the full-sweep sentinel, marks itself cache-ineligible whenever it
narrowed, and says so in its own output.

**Tasks**:
- [x] Re-read `gate8_run()` and the `--skip-unchanged` post-run cache write/invalidate block
      immediately before editing. *(completed)*
- [x] Inside `gate8_run()`'s `else` branch (the one that actually reaches `run-all.sh`), and only
      when `GATE8_TOUCHED` is non-empty: lazily source
      `$TARGET/agent-system/extensions/core/scripts/lib/suite-selection-lib.sh` - the TARGET copy,
      never `_VD_SCRIPT_DIR/lib/`, so the library's `BASH_SOURCE[0]`-derived roots match the
      `run-all.sh` this gate invokes. Mirror `validate-artifact.sh`'s lazy-source idiom. A missing
      library degrades to the unnarrowed invocation with a named `Note:` line; it never fails the
      gate (coordination/optimization failing is never a reason to skip verification).
      *(completed)*
- [x] Split `GATE8_TOUCHED` on commas into an array and call
      `mapfile -t _g8_suites < <(suite_selection_select "${_g8_paths[@]}")`.
      *(completed: named GATE8_TOUCHED_PATHS/GATE8_SUITES to match this phase's own variable
      prefix)*
- [x] If the result is exactly `$SUITE_SELECTION_FULL_SWEEP_SENTINEL` (or empty), run the existing
      unnarrowed invocation unchanged and set no narrowing marker. Otherwise set
      `GATE8_NARROWED=true` and append `--only "$(IFS=,; echo "${_g8_suites[*]}")"` to the existing
      `--quiet --jobs "$GATE8_JOBS" --fail-on-new` invocation. *(completed: discovered and fixed a
      real defect here -- "${GATE8_ONLY_ARGS[@]:-}" substitutes ONE empty-string word for a
      zero-element array under this file's set -uo pipefail, not zero words, which made every
      unnarrowed run pass a spurious empty argument to run-all.sh and fail with exit 2. Fixed by
      using the bare "${GATE8_ONLY_ARGS[@]}" form; see progress/phase-2-progress.json
      approaches_tried for the full reproduction)*
- [x] When `GATE8_NARROWED=true`, append `gate8` to `GATE_DIRTY_LIST` unconditionally - before the
      verdict branch, so it holds on pass, advisory-warn and fail alike. Add an inline comment
      naming the hazard it closes: the generic `--skip-unchanged` write block computes its key from
      the gate's **declared** `@extensions` corpus and has no knowledge of an internal `--only`.
      *(completed)*
- [x] Change **only** the narrowed branch's `pass()` message (e.g. naming the selected-suite count
      and stating this is not a full-battery pass). Leave the unnarrowed string
      `run-all.sh: all discovered suites passed` byte-identical - `test-gate8-expected-new-distinction.sh`
      and `test-gate-lock.sh` both assert it verbatim. *(completed: both suites directly re-run
      and confirmed passing against the fixed code)*
- [x] Extend the narrowed branch's `warn_advisory`/`fail` remedy strings to name the narrowing, so
      a reader re-running for detail knows the roster was filtered. *(completed)*
- [x] Update `gate8_run()`'s header comment with the narrowing contract and the forced-dirty
      invariant. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: atomic-batch

**Scope Hypothesis**: `suite_selection_select` returns **31** covering suites for
`agent-system/extensions/core/scripts/verify-deploy.sh` (measured at plan-authoring time,
2026-11-16, source store), against **195** discovered suites total. Confirm at implementation
time by re-running the selector over the same path and comparing against
`bash agent-system/extensions/core/scripts/tests/run-all.sh` discovery; the ratio, not the exact
number, is what the narrowing is worth, and both figures drift as suites are added.

**Tier Justification**: Every hunk is inside `gate8_run()` and its `GATE_DIRTY_LIST` bookkeeping
in the one file, touching no other gate's surface, so the covering check is
`bash agent-system/extensions/core/scripts/verify-deploy.sh --only-gate 8 --gate8-touched agent-system/extensions/core/scripts/gate-registry.data /home/benjamin/.config/nvim`
(which exercises the changed path end-to-end, now narrowly) plus `--only-gate 22` for shellcheck.

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` - selector sourcing, narrowed `run-all.sh` invocation, forced `GATE_DIRTY_LIST` marking, narrowed-branch verdict messages, header contract

**Verification**:
- `--only-gate 8 --gate8-touched <a small, mappable path>` runs visibly fewer suites than the same invocation without the flag, and its pass line states it was narrowed. *(confirmed: `lib/suite-selection-lib.sh` resolves to 3 suites (31 for `verify-deploy.sh` itself, matching the plan's Scope Hypothesis exactly); narrowed `[PASS]` message confirmed naming the count and the narrowing)*
- `--only-gate 8 --gate8-touched <an unmappable path>` falls back to the full battery (sentinel path) and prints today's unnarrowed pass string. *(confirmed: a deliberately bogus path resolves to `__FULL_SWEEP__`, prints the `Note:` fallback line, and proceeds with GATE8_ONLY_ARGS empty)*
- `--only-gate 8` with no `--gate8-touched` produces output byte-identical to the pre-change script. *(confirmed by direct comparison against the completely unmodified, deployed `.claude/scripts/verify-deploy.sh` under the identical live-repo conditions: both produce the identical `[FAIL] run-all.sh reported failing or undiscoverable suites (exit 1)` output right now, which is PRE-EXISTING live-repo flakiness unrelated to this phase -- see progress/phase-2-progress.json's `notes` field)*
- Under `--skip-unchanged`, a clean narrowed run leaves **no** cache entry for gate 8 (entry invalidated, not written); a clean unnarrowed run still writes one. *(narrowed side confirmed directly: a clean 3-suite narrowed PASS left `specs/.gate-cache/gate8.json` absent. Unnarrowed-writes-an-entry is pre-existing, generic `--skip-unchanged` behavior this phase does not touch, and could not be re-confirmed live due to the same pre-existing full-battery flakiness noted above)*

---

### Phase 3: Dedicated regression suite [NOT STARTED]

**Goal**: A new standalone suite pins the narrowing, the sentinel fallback, the absent-flag
byte-identity, and the forced cache-ineligibility, so none of the four can regress silently.

**Tasks**:
- [ ] Create the new suite modelled structurally on `test-gate8-expected-new-distinction.sh`
      (pass/fail/info helpers, counters, `mktemp` workdir with `trap EXIT` cleanup) and resolve its
      roots via `common_test_repo_root` / `common_test_ext_root` from `lib/common.sh` - never a
      fixed-depth `cd ../../..` walk, which gate 29's root-resolution lint rejects.
- [ ] Case A: absent flag - assert the invocation reaches `run-all.sh` with no `--only` and emits
      today's exact pass string.
- [ ] Case B: mappable single path - assert `--only` is passed and carries exactly the selector's
      own output for that path.
- [ ] Case C: multi-extension path set - assert the union resolves and the narrowed invocation is
      accepted by `run-all.sh --only` (the smoke test research recommended against a
      discovery-rule divergence between the two scripts).
- [ ] Case D: unmappable path - assert the sentinel path falls back to a full, unnarrowed
      invocation rather than a zero-suite run.
- [ ] Case E: forced cache-ineligibility - under `--skip-unchanged`, a clean narrowed run must
      leave no gate 8 cache entry behind; the same run without the flag must leave one. This is the
      case that pins D4 and is the suite's load-bearing assertion.
- [ ] Case F: argument validation - empty/missing flag value exits 2 with the named error.
- [ ] Use a stub `run-all.sh` in the fixture where a case only needs to observe the arguments Gate
      8 constructs, following `test-gate-cache-equivalence.sh`'s existing stub precedent, so the
      suite does not recurse into the real 195-suite battery.
- [ ] Run the new suite directly and confirm it passes.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase adds exactly **one** new file and modifies no existing one.
Confirm at implementation time with `git status --short` before staging: anything beyond the one
new suite path means the phase grew and the extra path must be declared rather than quietly
committed.

**Tier Justification**: The phase adds one standalone regression suite and changes no production
code path, so the covering check is running that newly added suite file directly, plus
`bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 29,22 /home/benjamin/.config/nvim`
(test-suite root-resolution lint and shellcheck over the new file).

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-gate8-suite-selection.sh` - new regression suite (cases A-F above)

**Verification**:
- The new suite passes when run directly.
- `--only-gate 29,22` passes (root-resolution lint and shellcheck clean on the new file).
- The suite is discovered by `run-all.sh` (it appears in the discovered-suite tally).

---

### Phase 4: Document the narrowing and its coverage trade-off [NOT STARTED]

**Goal**: The new input, its forced-dirty invariant, and the deliberately unnarrowed Move 4 are
recorded where a future reader finds them without reconstructing the reasoning from two task
directories.

**Tasks**:
- [ ] In `context/standards/shell-script-testing.md`'s suite-selection section, document Gate 8's
      opt-in `--gate8-touched` input: what it narrows, the sentinel fallback, and the invariant
      that a narrowed run is never cache-write-eligible.
- [ ] State explicitly that a narrowed Gate 8 pass is **not** evidence of full-battery coverage -
      the same honesty constraint the standard already applies to `--skip-slow` and `--only`.
- [ ] In `context/contracts/batch-gate-stage.md`, add the convergence subsection research
      recommended: Mechanism A's `--only-gate 8` can now be made genuinely suite-narrow by a caller
      supplying touched paths, while Move 4's once-per-invocation run remains unnarrowed and is the
      batch's only unconditional signal, pending the decision recorded as D3 above.
- [ ] Verify both files exist before editing (both confirmed present at plan-authoring time,
      2026-11-16); if either has been renamed or retired by then, record the deviation and place
      the content in its replacement rather than recreating the old path.
- [ ] Do **not** hand-edit `index-entries.json`'s `line_count` values; Phase 5's redeploy
      regenerates them (see the declaration note below).

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: Both target docs are indexed in
`agent-system/extensions/core/index-entries.json` with `line_count` values of 1341
(`standards/shell-script-testing.md`) and 202 (`contracts/batch-gate-stage.md`) as measured at
plan-authoring time. Editing either moves its count, so the index file is declared below as a
coupled generated surface. Confirm at implementation time by re-reading those two entries before
and after the edits; the check that detects the drift (`check-extension-docs.sh` Rule R) is not
commit-blocking in this repository, so reconciliation is legitimately deferred to Phase 5's
regeneration.

**Tier Justification**: Both edits are markdown with no executable surface and no doctest or
pragma, so the covering check is
`bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
(doc-lint and task-reference lint, run with the source-store repository root as TARGET) together
with a diff read-through confirming every hunk lies in prose.

**Files to modify**:
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - Gate 8 narrowing contract, sentinel fallback, forced-dirty invariant, not-full-coverage honesty note
- `agent-system/extensions/core/context/contracts/batch-gate-stage.md` - suite-selection convergence subsection; Move 4 stays unnarrowed
- `agent-system/extensions/core/index-entries.json` - coupled generated surface: both docs' `line_count` entries move; regenerated in Phase 5, not hand-edited

**Verification**:
- `--only-gate 3,4` with the repository root as TARGET passes (doc-lint and task-reference lint clean).
- Diff read-through confirms every changed hunk is prose.
- Neither document asserts that a narrowed Gate 8 pass equals a full-battery pass.

---

### Phase 5: Redeploy, schedule the call-site follow-on, and run the full gate set [NOT STARTED]

**Goal**: The source-store change is deployed into `.claude/`, the sequencing edge to the
call-site task is recorded, and the complete gate set passes against the real tree.

**Tasks**:
- [ ] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh /home/benjamin/.config/nvim`
      to regenerate the deployed tree (this also reconciles Phase 4's `index-entries.json`
      `line_count` drift).
- [ ] Confirm the deployed `.claude/scripts/verify-deploy.sh` carries the new flag
      (`grep -c gate8-touched`) and that the deployed selector library is present.
- [ ] Read `specs/state.json` to determine task 585's current status, then add the sequencing edge
      with `bash .claude/scripts/update-task-status.sh preflight 585 <its current status> <session_id> --depends-on-add='[584]'`
      (or `preflight edge_only` when 585 is `not_started`), per that flag's direction rule: the
      positional task number is the dependent. Skip the call if 585 is terminal or already carries
      the edge (the call is idempotent either way).
- [ ] Confirm the batch still drains:
      `bash .claude/scripts/orchestrate-cycle-plan.sh --dry-run --state-file specs/state.json 584 585`.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh /home/benjamin/.config/nvim`
      with no `--skip-slow`, no `--only-gate`, and no `--gate8-touched` - the unnarrowed full
      battery, including Gate 8's own 195 suites. A narrowed or skipped run does not satisfy this
      phase.
- [ ] Record the measured wall-clock of a narrowed versus unnarrowed Gate 8 invocation in the
      implementation summary, so the lever's actual value is evidence rather than projection.

**Timing**: 1.25 hours (dominated by the unnarrowed Gate 8 battery)

**Depends on**: 3, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase regenerates the whole deployed tree, so its real footprint is the
entire `.claude/**` mirror plus `index-entries.json` - declared via the reserved
`__WHOLE_TREE__` sentinel below rather than by enumerating deploy outputs. Confirm at
implementation time with `git status --short` after the deploy; `.claude/**` is gitignored, so the
only tracked residue should be `index-entries.json`.

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed tree
- `agent-system/extensions/core/index-entries.json` - regenerated `line_count` values reconciling Phase 4's edits

**Verification**:
- `bash .claude/scripts/verify-deploy.sh /home/benjamin/.config/nvim` (complete gate set, no `--skip-slow`, no `--only-gate`, no narrowing) exits 0 with zero FAILURES.
- The deployed `verify-deploy.sh` contains the `--gate8-touched` arm.
- `orchestrate-cycle-plan.sh --dry-run` confirms the batch drains with the new edge in place.
- `specs/state.json` shows task 585 depending on 584 (or a recorded reason why the edge was skipped).

## Testing & Validation

- [ ] Absent-flag path is byte-identical to the pre-change script (Phase 2/3 Case A).
- [ ] A mappable touched path narrows the battery and the `--only` list matches `suite_selection_select`'s own output exactly (Case B).
- [ ] A multi-extension touched set resolves and is accepted by `run-all.sh --only` (Case C).
- [ ] An unmappable touched path falls back to the full battery via the sentinel, never a zero-suite run (Case D).
- [ ] A clean narrowed run under `--skip-unchanged` leaves no gate 8 cache entry (Case E).
- [ ] Invalid/empty flag value exits 2 with a named error and a `FINDING gate0` line under `--findings` (Case F).
- [ ] `test-gate8-expected-new-distinction.sh` and `test-gate-lock.sh` still pass (unnarrowed pass string unchanged).
- [ ] Complete gate set passes unnarrowed in Phase 5.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/verify-deploy.sh` - `--gate8-touched` input, selector-narrowed Gate 8, forced cache-ineligibility on narrowing
- `agent-system/extensions/core/scripts/tests/test-gate8-suite-selection.sh` - new regression suite
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - narrowing contract and honesty note
- `agent-system/extensions/core/context/contracts/batch-gate-stage.md` - convergence subsection
- `agent-system/extensions/core/index-entries.json` - regenerated line counts
- `specs/584_gate8_covering_suite_selection/summaries/02_gate8-suite-selection-summary.md` - implementation summary, including the measured narrowed-versus-unnarrowed Gate 8 wall-clock
- A `dependencies[]` edge in `specs/state.json` sequencing the call-site task after this one

## Rollback/Contingency

Every phase is additive and opt-in: absent `--gate8-touched`, `gate8_run()` behaves exactly as it
does today, so reverting is low-risk at any point.

- Phases 1-4 are committed per phase on the source store; revert the offending phase's commit and
  redeploy (`deploy-headless.sh`) to restore the prior deployed tree.
- If the forced-dirty guard (Phase 2) cannot be made to hold, revert the narrowing in the same
  commit: narrowing without the guard must never be left in the tree, which is why that phase is
  declared `atomic-batch`.
- If a rollback must discard uncommitted work, take a durable checkpoint first - see
  `context/contracts/recovery.md`'s rollback rung for the exact `git-snapshot.sh` invocation shape
  and its out-of-scope override flag. Do not emit a bare reverting snapshot as a routine
  start-of-phase precaution; `--no-revert` is the right form for an ordinary defensive checkpoint.
- Concurrency caveat: a sibling task may hold uncommitted edits in this same working tree. Never
  revert the tree wholesale; revert only this task's own commits, by sha.
