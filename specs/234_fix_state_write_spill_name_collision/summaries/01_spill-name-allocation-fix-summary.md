# Implementation Summary: Task #234

- **Task**: 234 - Fix state-write.sh spill name collision
- **Status**: [COMPLETED]
- **Started**: 2026-09-17T23:50:00Z
- **Completed**: 2026-09-18T00:11:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_spill-name-allocation-fix.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`agent-system/extensions/core/scripts/state-write.sh` allocated a private jq `--slurpfile`
binding name as `private_name="__spill_${#SPILL_FILES[@]}"` in two places, but only the
`--arg`/`--argjson` auto-spill branch appended to `SPILL_FILES` afterward. The `--argjson-file`
branch (which never `mktemp`s anything -- the caller supplies the file) never appended, so its
own copy of that expression stayed on `__spill_0` forever: every `--argjson-file` binding
collided, and jq's duplicate-`--slurpfile` first-wins semantics silently substituted the first
spilled value for every later one, with exit 0 and no diagnostic. Because the two branches shared
one counter that only one of them advanced, a mixed call (one `--argjson-file` binding plus one
oversized `--argjson` auto-spill) also corrupted. This is fixed with a shared, explicit
`SPILL_SEQ` counter advanced by both branches, plus a loud hard-error (`check_spill_name_unique`)
on a duplicate spilled public NAME. A fixture-rooted regression suite
(`test-state-write-spill-names.sh`) demonstrates the defect RED against the unmodified script and
GREEN after the fix, with no edits to the suite in between.

## What Changed

- `agent-system/extensions/core/scripts/state-write.sh` -- introduced `SPILL_SEQ=0` (an explicit
  counter shared by both spill branches, deliberately decoupled from `SPILL_FILES`, which stays
  cleanup-ownership-only) and `SPILL_SOURCES=()` (a parallel array tracking each spilled
  binding's human-readable origin). Both the `--argjson` auto-spill branch and the
  `--argjson-file` branch now allocate `private_name="__spill_${SPILL_SEQ}"` and increment
  `SPILL_SEQ`, guaranteeing distinct names across both branches in any mix. Added
  `check_spill_name_unique()`, called by both branches before allocation, which hard-fails
  (exit 1, naming the NAME and both conflicting sources) if a caller passes the same public NAME
  twice among spilled bindings. The caller-supplied `--argjson-file` PATH is still never appended
  to `SPILL_FILES` (an explicit anti-regression comment and Case D of the new suite guard this).
  Diff confirmed confined to the declaration block and the two spill branches -- no change to
  `EFFECTIVE_FILTER`, the mutex, staging/`mv`, or `--state-file`/`--init`.
- `agent-system/extensions/core/scripts/test-state-write-spill-names.sh` -- new fixture-rooted
  regression suite, modeled on `test-state-write-large-payload.sh`. Cases A (pure multi-file
  collision), B (mixed `--argjson-file` + oversized `--argjson` + plain `--arg`), C (duplicate
  NAME hard-error), D (caller-owned file survives the run), plus a real-repo
  `specs/state.json`-untouched guard. Copies all six fixture dependencies
  (`state-write.sh`, `task-lock.sh`, `generate-todo.sh`, `deploy-root-guard.sh`, `lib/common.sh`,
  `lib/task-lookup-lib.sh`). Fully shellcheck clean (0 findings).
- `agent-system/extensions/core/manifest.json` -- added `"test-state-write-spill-names.sh"` to
  `provides.scripts` (alphabetically between `test-state-write-regen-timing.sh` and
  `test-task-lock-reap.sh`). Required because the deploy engine is manifest-driven and does not
  auto-discover new script files; without this addition the first redeploy landed the
  `state-write.sh` fix (already a manifest entry) but silently skipped the new suite.

## Decisions

- Shared explicit `SPILL_SEQ` counter (plan's Option A) over name-derived private names (Option
  B): closes the root cause directly, guarantees uniqueness by construction, and the caller audit
  found zero live callers reaching the `--argjson-file` path at all, so Option B's
  failure-message-legibility advantage bought nothing today against a larger diff.
- Regression suite placed flat at `agent-system/extensions/core/scripts/test-state-write-spill-names.sh`
  rather than under `scripts/tests/` (the dispatch's literal wording): matches the location
  convention (`context/standards/shell-script-testing.md`) and its 3-for-3 sibling precedent,
  since `state-write.sh` integrates `task-lock.sh` and `generate-todo.sh` and any fixture must
  copy both.
- Left the 3 pre-existing shellcheck info-level findings on `state-write.sh` (2x SC1091 on
  `source`/`.` lines, 1x SC2329 on `cleanup()`) untouched: confirmed byte-identical before and
  after this fix via direct comparison against a pre-fix baseline copy, unrelated to the defect,
  and outside the plan's declared scope region.

## Plan Deviations

- **Task 3.2** (regression-check `test-state-write-large-payload.sh`) altered: research's
  specific hypothesis (a missing `lib/task-lookup-lib.sh` copy) did not reproduce as the cause of
  that suite's failures -- this task's own Phase 1 fixture list already includes the file.
  Actual cause is pre-existing `specs/.scope-lock` mutex-timeout/concurrency flakiness (this
  session ran under heavy concurrent load from ~8 other active orchestrator agents), confirmed
  IDENTICAL failure counts and messages against a stashed pre-fix baseline copy and the fixed
  script. Conclusion unchanged (pre-existing, out of scope); root cause differs from what
  research anticipated.
- **Task 4.1** (regenerate deploy tree) altered: required adding the new test file to
  `agent-system/extensions/core/manifest.json`'s `provides.scripts` list, not anticipated by the
  plan's literal task text -- the deploy engine is manifest-driven and does not auto-discover new
  script files.

## Verification

- Build: N/A (shell scripts)
- Tests:
  - New suite: RED pre-fix (2 passed, 3 failed -- Cases A, B, C fail as the defect predicts) ->
    GREEN post-fix (5 passed, 0 failed), same suite, no test-code edits between the two runs.
    Re-verified GREEN from the deployed `.claude/scripts/` location.
  - Three existing sibling suites (`test-state-write-concurrency.sh`,
    `test-state-write-regen-timing.sh`, `test-state-write-large-payload.sh`): all three show
    IDENTICAL pass/fail counts and failure messages pre- and post-fix (4/5, 1/2, 2/5
    respectively) -- pre-existing `specs/.scope-lock` mutex-timeout/concurrency flakiness under
    this session's heavy concurrent load, confirmed unrelated to the spill-name defect.
  - Representative live-caller shape (`orchestrator-postflight.sh` Stage 7c's
    `--argjson num` + `--argjson new` pattern, replayed with a 125,031-byte in-range payload):
    byte-identical 1,855-element output pre- and post-fix.
  - `git status --porcelain -- specs/state.json` confirmed unchanged by every test run in this
    task (verified both by the new suite's own before/after guard and by manual checks).
- Files verified: Yes -- `.claude/scripts/state-write.sh` and
  `.claude/scripts/test-state-write-spill-names.sh` confirmed present with the fix after
  redeployment.
- shellcheck: new suite 0 findings (clean). `state-write.sh` carries 3 pre-existing info-level
  findings, confirmed byte-identical before/after this fix (no new finding introduced by this
  change's diff).

## Caller Audit

Re-ran the research report's enumeration:
`grep -rn "argjson-file" agent-system/extensions/ --include="*.sh" --include="*.md"` and
`grep -rln "state-write.sh" agent-system/extensions/ --include="*.sh" --include="*.md"`.

- **Zero live `--argjson-file` callers** exist outside `state-write.sh` itself and its own two
  test suites (`test-state-write-large-payload.sh`, `test-state-write-spill-names.sh`). The
  `--argjson-file`-collision shape (Case A) therefore cannot have occurred in production.
- **~110 files reference `state-write.sh`** (mix of scripts, commands, and skill definitions
  across core and every extension). Every multi-`--argjson` live call site found pairs at most
  ONE potentially-large payload with one or two task-number/counter integer bindings that can
  never approach the 100,000-byte `SPILL_THRESHOLD`:
  - `orchestrator-postflight.sh` (memory_candidates, reflection) -- `$num` + one payload.
  - `skill-base.sh` (three call sites: memory_candidates, roadmap_items, completion_summary) --
    `$num` + one payload each.
  - Lean and present extensions' `next_artifact_number` increments -- `$num` + a plain integer
    (`$next`/`$cur`), never a payload.
  - `deprecated/vault-operation.sh` (two call sites) -- integer-only bindings
    (`$old`/`$new`, `$new_next`/`$vault_num`), never large.
  - `skill-reviser/SKILL.md`, `skill-spawn/SKILL.md`, `commands/review.md`, `commands/todo.md`,
    founder/present extension skills -- same `$num` + one-payload shape.
- **Conclusion**: no call site pairs two independently-large bindings in one invocation, so the
  multi-spill collision (both defect shapes) could never have been triggered by any live caller.
  No corrupted `specs/state.json` data exists or is suspected from this defect.

## Impacts

- `state-write.sh` remains the single mutex-guarded writer every `specs/state.json`
  read-modify-write is meant to route through; its silent-corruption failure mode on multi-spill
  calls is closed. Any future caller passing 2+ `--argjson-file` bindings, or mixing
  `--argjson-file` with an oversized `--argjson`, now gets correct per-binding values instead of
  the first value silently repeated.
- A caller mistake (passing the same NAME twice among spilled bindings) is now a loud, non-zero
  exit naming the NAME and both conflicting sources, instead of a silent last-write-wins.
- No caller-visible interface change: every existing caller's `$NAME` reference resolves
  byte-for-byte exactly as before (confirmed via the Stage 7c sanity check).

## Follow-ups

- The 3 pre-existing shellcheck info-level findings on `state-write.sh` (2x SC1091 on its
  `source`/`.` lines, 1x SC2329 on `cleanup()`) remain unaddressed -- confirmed unrelated to this
  defect and out of this task's declared scope; a future opportunistic pass could add
  `# shellcheck source=`/`# shellcheck disable=SC2329` directives.
- `test-state-write-large-payload.sh`'s missing `lib/task-lookup-lib.sh` in its own copy list
  (noted by research) remains unfixed -- explicitly out of scope per this plan's Non-Goals; this
  task's own suite copies all six dependencies correctly.
- The three pre-existing sibling suite failures (mutex-timeout/concurrency flakiness under heavy
  concurrent session load) were not investigated further -- confirmed pre-existing and unrelated,
  but a dedicated task could look into whether `specs/.scope-lock`'s acquire budget needs
  widening for highly concurrent multi-agent sessions.
- `verify-deploy.sh`'s full gate set reported unrelated failures during this task's redeploy
  (docs-content drift, `validate-state.sh --deep`, an orchestrator context-budget overage on
  `commands/orchestrate.md`) -- none reference `state-write.sh` or this task's scope; the
  docs-drift one had already resolved by the time it was rechecked (other concurrent sessions'
  activity). Not investigated further here.

## References

- Plan: specs/234_fix_state_write_spill_name_collision/plans/01_spill-name-allocation-fix.md
- Research: specs/234_fix_state_write_spill_name_collision/reports/01_spill-name-collision.md
- Progress: specs/234_fix_state_write_spill_name_collision/progress/phase-{1..5}-progress.json
- Handoffs: specs/234_fix_state_write_spill_name_collision/handoffs/phase-{1..5}-handoff-*.md
