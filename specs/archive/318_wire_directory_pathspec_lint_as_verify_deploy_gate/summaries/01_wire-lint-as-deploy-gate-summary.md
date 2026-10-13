# Implementation Summary: Task #318

- **Task**: 318 - Wire the directory-pathspec boundary lint into `verify-deploy.sh` as a numbered gate
- **Status**: [COMPLETED]
- **Started**: 2026-10-12
- **Completed**: 2026-10-12
- **Effort**: ~2.5 hours
- **Dependencies**: 265, 304 (both complete)
- **Artifacts**: plans/01_wire-lint-as-deploy-gate.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Wired `lint-directory-pathspec-boundary.sh` into `verify-deploy.sh` as a new, blocking,
**trailing gate 23** — appended after gate 22 rather than inserted beside its sibling gate 17, to
avoid renumbering gates 18-22 and invalidating the heavy by-number citations those gates carry
elsewhere (gate 20 alone is cited in over a hundred files). The `--only-gate` accepted range
widened from `1-22` to `1-23` via in-place text substitution (no lines added), the dependent
gate-selection test suite was updated for a 23-gate battery, and the `git-staging-scope.md`
cross-reference bullet was rewritten to state the gate-23 wiring and its no-renumbering
rationale, replacing the superseded "not yet wired / gate 17 is the natural wiring point"
sentence.

## What Changed

- `agent-system/extensions/core/scripts/verify-deploy.sh` — appended blocking gate 23
  (directory-pathspec boundary lint), modeled line-for-line on gate 17's shape (same `[SKIP]`
  source-store guard, same `fail`-on-nonzero blocking tier, same `[VIOLATION]`-scraping findings
  accumulation under `--findings`, variable prefix `dir_pathspec_lint_*`); widened the
  `--only-gate` accepted range from `1-22` to `1-23` at all 6 text sites (four `1-22`, one
  `twenty-two`, one `-gt 22`), in place, adding no lines.
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh` — updated for
  a 23-gate battery: `invalid_cases` list changed `23`→`24` (the load-bearing fix, since gate 23
  is now valid), both `seq 1 22` loops widened to `seq 1 23`, and every count-bearing
  prose/pass-message string updated to 23.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — rewrote the closing
  sentence of the `lint-directory-pathspec-boundary.sh` cross-reference bullet to state the
  gate-23 wiring and the deliberately-trailing placement rationale; the sibling gate-17 bullet is
  untouched.
- `agent-system/extensions/core/index-entries.json` — companion one-entry fix (not foreseen at
  plan time): corrected the `standards/git-staging-scope.md` entry's `line_count` from 673 to
  748, the mechanical Rule R consequence of the bullet edit above adding net lines to that file.
  `file_scope` was widened at implement time to include this path.

## Decisions

- **Trailing placement, gate 23, never inserted beside gate 17**: the plan's own citation-sweep
  measured a 210-site renumbering blast radius across gates 18-22 if inserted next to gate 17;
  appending costs zero renumbering and zero citation fixes.
- **Blocking, not advisory**: matches gate 17 and every other lint gate; the lint reports 0
  violations across the whole source store (re-verified live at Phase 1, re-verified again in
  Phase 5's full sweep).
- **Source-store `[SKIP]` guard retained** (unlike gate 4's recent de-guarding): this lint's
  default scan root is `$PROJECT_ROOT/agent-system/extensions` and it exits 2 with
  `ERROR: default scan root not found` when that directory is absent, so — unlike
  `check-task-references.sh` — it genuinely cannot run in a deploy-consumer tree. The new gate's
  comment states this explicitly.
- **A `--skip-slow` baseline/final-sweep comparison, not a full non-skip-slow one**: both Phase
  1's pre-change baseline and Phase 5's post-change sweep hit the inner 540s bounded-wait timeout
  inside gate 8's shell suite runner on the full (non-skip-slow) battery; each phase fell back to
  `--skip-slow` once, per Phase 1's own pre-declared contingency, for a like-with-like
  comparison. Under `--skip-slow`, the total check count rose from 35 (baseline) to 36 (final),
  exactly the expected `+1`.
- **No source-store deploy performed.** The dispatch's literal "run
  `bash .claude/scripts/verify-deploy.sh`" was deliberately read as the deployed copy, which only
  carries gate 23 after a redeploy; this task runs the source-store copy directly as its
  authoritative evidence instead, leaving the actual redeploy to the orchestrator's own next
  redeploy checkpoint, consistent with the plan's own Non-Goal against hand-deploying.
- **A first, unscoped `generate-context-line-counts.sh --write` run was reverted down to one
  entry.** The script recomputes `line_count` for every entry in every extension's
  `index-entries.json`; because this is a shared, actively multi-tasked working tree, a first
  `--write` run picked up 10 additional entries that had drifted out of sync due to concurrent
  sibling-task edits landing between the `--check` and `--write` invocations. Those 10 were
  manually reverted via `sed` before committing, keeping the commit confined to this task's own
  one entry.

## Plan Deviations

- **Phase 1 and Phase 5**: the full (non-`--skip-slow`) `verify-deploy.sh` battery hit the inner
  540s bounded-wait timeout inside gate 8 both times; each phase fell back to a `--skip-slow` run
  once, per Phase 1's own pre-declared contingency step. Not a regression — a pre-anticipated
  fallback.
- **Phase 4** closed `[COMPLETED WITH EXCLUSIONS]`: the doc-gate subset's literal "exit 0, two
  non-SKIP `[PASS]` lines" expectation could not be met because gate 3 (doc-lint) fails for two
  causes outside this task's scope — (1) deployed-vs-source content drift for this task's own 3
  edited files, pending the next redeploy; (2) ten `index-entries.json` `line_count` mismatches
  on context docs owned by concurrently-dispatched sibling tasks, confirmed absent at Phase 1's
  baseline. This bullet's own entry is confirmed correctly reconciled. See the phase's own
  Reasoned Exclusions table for full evidence.
- **Phase 5** closed `[COMPLETED WITH EXCLUSIONS]`: the full-battery comparison against Phase 1's
  baseline shows 2 new FAILs (gate 3; gate 5 gains 3 findings), and
  `test-verify-deploy-context-budget.sh`'s baseline-sanity case fails (exit 1) — both
  attributable to the same deploy-staleness/content-drift class documented in Phase 4, now also
  compounded by task 281's concurrent in-flight edit to `scripts/lib/record-version-patterns.sh`.
  Gate 23 itself is independently confirmed `[PASS]` with zero findings in every context it ran,
  including a standalone reproduction of the context-budget suite's own fixture. See the phase's
  own Reasoned Exclusions table for full evidence.

## Verification

- Build: N/A (shell scripts; `bash -n` clean on every edited `.sh` file)
- Tests:
  - `lint-directory-pathspec-boundary.sh`: 0 violations, exit 0 (1303 files checked), both before
    and after wiring.
  - `test-lint-directory-pathspec-boundary.sh`: 14 passed, 0 failed (Phase 1 and Phase 5).
  - `test-verify-deploy-gate-selection.sh`: 9 passed, 0 failed (Phase 3 and Phase 5).
  - `verify-deploy.sh --only-gate 23`: exit 0, one gate header, `PASS -- 1 check(s)`.
  - `verify-deploy.sh --only-gate 24`: exit 2, named `1-23` range error.
  - `verify-deploy.sh` full battery (`--skip-slow`): 36 checks total (baseline 35 + 1), gate 23
    `[PASS]`; 2 FAILs beyond baseline, both attributed (see Plan Deviations).
  - `test-verify-deploy-context-budget.sh`: 14 of 15 assertions pass; the baseline-sanity case
    fails on deploy-staleness noise unrelated to gate 23 (see Plan Deviations).
- Files verified: Yes — `grep -c 'CURRENT_GATE="gate'` returns 24 (gate0 through gate23); no
  stale `1-22`/`twenty-two`/`gt 22` text remains in `verify-deploy.sh`.

## Impacts

- The directory-pathspec boundary rule is now enforced on every `verify-deploy.sh` invocation,
  closing the asymmetry with its sibling `lint-scoped-commit-boundary.sh` (gate 17): a regression
  of either rule now fails the deploy gate, not just a manual lint run.
- `git-staging-scope.md`'s cross-reference is now accurate and will not mislead a future reader
  into thinking gate 17 is the intended insertion point for this lint.
- The deployed `.claude/` copy of `core` is now stale relative to the 3 source-store files this
  task edited (`verify-deploy.sh`, `test-verify-deploy-gate-selection.sh`,
  `git-staging-scope.md`). The completion-deploy gate is expected to refuse marking this task
  `[COMPLETED]` until the orchestrator's next redeploy checkpoint resolves that staleness — this
  is expected, not a defect, and requires no manual workaround.

## Follow-ups

- Out of scope, flagged but not fixed per the plan's own Non-Goals: `verify-deploy.sh`'s header
  Findings-mode paragraph still says "all eighteen gates (gate0 through gate17)", and
  `context/standards/shell-script-testing.md:138` still says "the full 20-gate battery" — both
  were already wrong before this task (true count was 22, now 23). This task's own change makes
  the first sentence marginally more wrong (eighteen vs. the now-correct 24 including gate0), but
  fixing either was deliberately not bundled, to avoid pulling files outside this task's scope
  into a batch where sibling tasks are live.
- Ten `index-entries.json` `line_count` mismatches, discovered during Phase 4, are owned by
  concurrently-dispatched sibling tasks (their edits to `plan-format.md`,
  `return-metadata-file.md`, `context-discovery.md`, `external-process-wait.md`,
  `bounded-build-waiter.md`, `state-management-schema.md`, `conclusion-stage.md`,
  `task-reference-exemptions.md`, `orchestrate-batch-results-template.md`,
  `task-abandon-mode.md`) — not fixed here; belongs to whichever task next touches those files,
  or a dedicated maintenance pass.
- The lint's coverage is one-sided by design (flags a pathspec that is too WIDE; cannot detect
  one that is too NARROW) — recorded in the dispatch as an open question for a possible future
  task, not actioned here.

## References

- Plan: `specs/318_wire_directory_pathspec_lint_as_verify_deploy_gate/plans/01_wire-lint-as-deploy-gate.md`
- Research: `specs/318_wire_directory_pathspec_lint_as_verify_deploy_gate/reports/01_wire-lint-as-deploy-gate.md`
- Phase handoffs: `specs/318_wire_directory_pathspec_lint_as_verify_deploy_gate/handoffs/`
