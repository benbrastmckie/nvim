# Implementation Summary: Task #584

- **Task**: 584 - Wire covering-suite selection into Gate 8 so an extension change runs the affected suites, not all of them
- **Status**: [COMPLETED]
- **Started**: 2026-11-16T00:00:00Z
- **Completed**: 2026-11-16T05:30:00Z
- **Effort**: ~5.5 hours
- **Dependencies**: Task 505 (completed - per-extension source-store resolution in the selector)
- **Artifacts**: plans/02_gate8-suite-selection.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Wired `lib/suite-selection-lib.sh`'s existing covering-suite selector into `verify-deploy.sh`'s
Gate 8 (the shell test suite runner) via a new, opt-in `--gate8-touched PATH[,PATH...]` input.
When supplied, Gate 8 narrows its internal `run-all.sh` invocation to exactly the suite(s)
covering the given path(s); absent the flag, every caller's behavior and output stay
byte-identical to before this input existed. A forced cache-ineligibility invariant guarantees a
narrowed run, pass or fail, can never become the basis for a `--skip-unchanged` cache write that
would otherwise silently certify a full `@extensions` corpus from a subset result. All five
planned phases landed, including a dedicated regression suite, documentation, the source-store
redeploy, and the call-site sequencing edge to task 585.

## What Changed

- `agent-system/extensions/core/scripts/verify-deploy.sh` - new `GATE8_TOUCHED` variable (declared
  before the argument-parsing loop) and `--gate8-touched` case arm; `gate8_run()` resolves it
  through `suite_selection_select`, narrows the `run-all.sh --only <list>` invocation when a real
  suite set comes back, falls back to the unnarrowed invocation on the full-sweep sentinel or a
  missing library, forces `gate8` onto `GATE_DIRTY_LIST` unconditionally when narrowed, and
  distinguishes the narrowed `[PASS]`/remedy text from the unnarrowed strings two other suites
  assert verbatim.
- `agent-system/extensions/core/scripts/tests/test-gate8-suite-selection.sh` - new standalone
  regression suite (22 cases): absent-flag byte-identity, a mappable single path, a multi-path
  union, the unmappable-path sentinel fallback, the forced cache-ineligibility invariant, and
  `--gate8-touched` argument validation.
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - new "Gate 8's own
  touched-paths narrowing" section (the contract, the sentinel fallback, the forced-dirty
  invariant, the not-full-coverage honesty constraint); removed a now-stale declined-alternative
  bullet this phase directly contradicts ("a `verify-deploy.sh` pass-through for `--only` -- not
  built").
- `agent-system/extensions/core/context/contracts/batch-gate-stage.md` - new "Suite-Level
  Narrowing Convergence (Gate 8)" subsection recording that Mechanism A's scoped `--only-gate 8`
  can compose with `--gate8-touched` for genuine suite-level narrowing, while Move 4's
  once-per-invocation run stays unnarrowed by design.
- `agent-system/extensions/core/manifest.json` - one-line `provides.scripts` registration for
  the new suite file (doc-lint caught the omission; without it `deploy-headless.sh` would never
  deploy the suite).
- `agent-system/extensions/core/index-entries.json` - regenerated `line_count` values, via
  `deploy-headless.sh`'s automatic run.
- `specs/state.json` - added a `dependencies[]` edge sequencing task 585 after 584.
- Deployed tree (`.claude/**`) regenerated via `deploy-headless.sh` (gitignored, not itself a
  tracked change).

## Decisions

- Kept the lazy-source degrade-safe idiom (a missing `suite-selection-lib.sh` copy degrades to
  the unnarrowed invocation with a `Note:` line, never a gate failure) -- coordination or
  optimization machinery failing is never a reason to skip verification.
- Removed, rather than merely annotated, the stale "not built" declined-alternative bullet in
  `shell-script-testing.md`, since this phase's own work makes that statement false; replaced it
  with a section describing the mechanism that now exists, worded to the current design only.
- Case C ("multi-extension path set" in the plan's wording) tested as a multi-path union within
  one fixture extension rather than two literal `agent-system/extensions/*` directories -- same
  functional coverage of the union-resolution and `run-all.sh --only` basename-acceptance smoke
  test, less fixture complexity.

## Plan Deviations

- **Phase 1**: `GATE8_TOUCHED`'s default declaration cannot literally sit "beside `GATE8_JOBS`"
  as the plan's task text specified -- that site runs AFTER the argument-parsing `while` loop and
  silently clobbers the value the `--gate8-touched` case arm just set. Fixed by declaring the
  default before the loop instead, alongside `GATES_FILTER`/`JOBS`.
- **Phase 2**: discovered and fixed a real defect not anticipated by the plan's own pseudocode:
  `"${GATE8_ONLY_ARGS[@]:-}"` substitutes ONE empty-string word for a zero-element array under
  this file's `set -uo pipefail` (confirmed by direct reproduction), not zero words, so every
  unnarrowed run was passing a spurious empty argument to `run-all.sh`, which rejected it with
  `exit 2`. Fixed by using the bare `"${GATE8_ONLY_ARGS[@]}"` form.
- **Phase 3**: Case E's cache-write assertions initially failed for an unanticipated reason --
  `gate-cache-lib.sh`'s implementation-digest component requires a copy of `verify-deploy.sh`
  physically present under the TARGET fixture (to hash `gate8_run()`'s own function body) and a
  real, committed git repository (the `@extensions` corpus resolution shells out to
  `git ls-files`). Fixed by adding both to the fixture builder.
- **Phase 3**: Case C narrowed to a multi-path union within one extension (see Decisions above).
- **Phase 4**: added a one-line `manifest.json` registration fix, outside this task's declared
  `file_scope`, for the reason given under What Changed.
- **Phase 5**: the sequencing-edge call used `postflight 585 plan <session_id>` rather than
  `preflight edge_only`, since `edge_only` requires `operation:target_status` to resolve to the
  task's CURRENT status (a no-op replay) and 585 was `planned`, not `not_started`.
- **Phase 5**: ran the complete, unnarrowed gate set directly (not deferred to a scoped tier) per
  the dispatch's own UNMAPPABLE CRITERION carve-out -- this phase's own verification criterion
  specifically demands the unnarrowed battery, which no narrowing invocation can express without
  defeating its purpose.

## Verification

- Build: N/A (shell scripts, markdown, JSON)
- Tests: `test-gate8-suite-selection.sh` -- 22/22 passed. `test-gate8-expected-new-distinction.sh`
  and `test-gate-lock.sh` (the two suites asserting Gate 8's unnarrowed pass string verbatim) --
  both pass cleanly against the fixed code.
- Files verified: Yes -- deployed tree regenerated (`RESULT=landed_verify_clean`); deployed
  `verify-deploy.sh` carries 14 `--gate8-touched` references; deployed selector library and new
  suite file both present.
- Complete gate set (unnarrowed, no `--skip-slow`, no `--only-gate`): 41/44 checks passed. The 3
  failures are NOT regressions from this task -- see Impacts below.

### Measured wall-clock (Gate 8, this host, concurrent sibling load present throughout)

| Invocation | Suites run | Wall-clock |
|---|---|---|
| Unnarrowed full battery | 196 | 660.6s (11m 0.6s) |
| Narrowed to `verify-deploy.sh`'s own covering set | 32 | 628.8s (10m 28.8s, ~4.8% faster) |
| Narrowed to a lighter, more typical touched path (`suite-selection-lib.sh`) | 3 | 17.5s (~97.3% faster, ~37.8x) |

**Honest reading, not smoothed over**: `verify-deploy.sh`'s own covering set happens to include
the corpus's single heaviest suite (`test-verify-deploy-context-budget.sh`), so narrowing to it
specifically saves little -- exactly the same non-tuned, many-to-one fan-out caveat
`shell-script-testing.md` already documents for the general selector. The lighter touched path is
the representative case this mechanism exists for; a caller touching a file whose covering set
happens to include the corpus's heaviest suite will see a correspondingly smaller saving, by
construction, not by defect.

## Impacts

- A future caller supplying touched paths to Gate 8 (an orchestrator batch-gate call site, for
  example) can now reach a result genuinely narrower than "run only Gate 8" -- narrower than any
  mechanism that existed before this task. Wiring an actual caller is separate, not-yet-built
  work (named explicitly as a non-goal; the `dependencies[]` edge to task 585 sequences that
  follow-on after this task).
- Two gate-set failures observed during Phase 5's full-battery run trace to a concurrent sibling
  task's in-flight, uncommitted edit to `agent-system/extensions/core/scripts/lib/continuation-pointer-lib.sh`
  (confirmed outside this task's `file_scope` via `git log`/`git status`) -- not an impact of this
  task's own work, reported per the territory contract rather than reverted.
- One gate-set failure (`test-gate-lock.sh` classified NEW) reproduces a pre-existing,
  environment-dependent flake: that suite's own nested fixtures inherit the real
  `GATE_MUTEX_HELD=1` a genuinely-top-level `gate8_run()` exports, when Gate 8's full unnarrowed
  battery is run as a top-level invocation holding the real `specs/.gate-lock` mutex. Confirmed
  pre-existing (unrelated to this task) by reproducing the identical symptom against the
  completely unmodified deployed `verify-deploy.sh`.

## Follow-ups

- Wire an actual caller (an orchestrator batch-gate call site) to supply touched paths to
  `--gate8-touched` -- the `dependencies[]` edge already sequences task 585 after this one for
  exactly that reason.
- `test-gate-lock.sh`'s sensitivity to an inherited `GATE_MUTEX_HELD=1` when run nested under a
  genuinely-top-level Gate 8 invocation is a pre-existing environmental flake, not caused by this
  task; it remains unfixed and un-triaged beyond what this task's own issue log records.
- The sibling task's in-flight edit to `continuation-pointer-lib.sh` will resolve on its own once
  that task commits and redeploys; no action needed from this task.

## References

- Plan: `specs/584_gate8_covering_suite_selection/plans/02_gate8-suite-selection.md`
- Research: `specs/584_gate8_covering_suite_selection/reports/01_gate8-suite-selection.md`,
  `specs/584_gate8_covering_suite_selection/reports/02_gate8-suite-selection.md`
- Issues: `specs/584_gate8_covering_suite_selection/issues.jsonl`
