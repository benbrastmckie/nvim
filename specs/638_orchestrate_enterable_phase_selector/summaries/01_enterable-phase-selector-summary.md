# Implementation Summary: Task #638

- **Task**: 638 - Make /orchestrate's hard-mode phase selector pick the first ENTERABLE phase, not the first heading that merely parses as open
- **Status**: [COMPLETED]
- **Started**: 2026-11-16T15:30:00Z
- **Completed**: 2026-11-17T00:39:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: Task 547 (`[COMPLETED]`; the shared-file edge on `orchestrate-cycle-plan.sh` was discharged)
- **Artifacts**: plans/01_enterable-phase-selector.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Replaced the H1 hard-mode phase selector's plain `grep PHASE_HEADING_ERE.*PHASE_STATUS_OPEN_ERE
| head -1` with a real enterability predicate: a new, narrower `PHASE_STATUS_ENTERABLE_ALT`
marker set (OPEN minus `BLOCKED`) combined with a `**Depends on**:` closure check, implemented
as four new functions in `phase-heading-patterns.sh` and wired into `orchestrate-cycle-plan.sh`
via a three-way exit contract (select an enterable phase / report a named "no enterable phase"
refusal / fall through exactly as before). `PHASE_STATUS_OPEN_ALT` is byte-identical and
unchanged for every other consumer.

## What Changed

- `agent-system/extensions/core/scripts/lib/phase-heading-patterns.sh` -- added
  `PHASE_STATUS_ENTERABLE_ALT`/`PHASE_STATUS_ENTERABLE_ERE`/`PHASE_HEADING_ENTERABLE_ERE` beside
  the untouched `PHASE_STATUS_OPEN_ALT`; widened the file header to record the scope split; added
  `phase_marker_of`, `phase_dependency_numbers` (both `**Depends on**:`/`**Depends on:**`
  spellings, `none`, comma-separated tokens validated against `PHASE_NUMBER_TOKEN_ERE`,
  all-or-nothing fallback to the all-prior default), `phase_is_enterable` (marker-plus-dependency
  predicate, one machine-readable reason token on refusal: `marker`, `unmet-dependency:<n>`,
  `dangling-dependency:<n>`), and `select_enterable_phase` (three-way exit contract: 0 =
  selected, 3 = open headings exist but none enterable, 4 = nothing open at all).
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` -- replaced the single
  `grep | head -1` call site with `select_enterable_phase`, branched on its three exit codes;
  exit 3 composes a new `H1: NO ENTERABLE PHASE` blocked-row reason naming the rejected count, a
  capped per-heading diagnostic list, and the `/revise`-or-close-the-gate remedy; exit 4 falls
  through to the pre-existing ordinary dispatch path unchanged.
- `agent-system/extensions/core/scripts/tests/test-phase-heading-patterns.sh` -- 22 new unit
  assertions covering the vocabulary split, `phase_marker_of`, both `Depends on` spellings,
  comma-spacing variants, a decimal sub-phase token, unparseable-prose and absent-field fallback,
  `phase_is_enterable`'s four outcomes, and one fixture per `select_enterable_phase` exit code.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` -- added Group 9
  Cases F-I (BLOCKED-first and unmet-dependency-first plans both select a later enterable phase;
  a plan with no enterable phase produces zero dispatch rows and one named blocked row;
  `--dry-run` parity). Cases A-E re-verified unmodified before and after the rewiring.
- `agent-system/extensions/core/context/formats/plan-format.md` -- documented that `Depends on`
  is now mechanically parsed (both spellings, enforced absence default) and that a `[BLOCKED]`
  heading is never a dispatch target under hard mode.
- `agent-system/extensions/core/index-entries.json` -- corrected `formats/plan-format.md`'s
  declared `line_count` (1254 -> 1269) after the prose addition.
- Deployed `.claude/` tree regenerated via `deploy-headless.sh` (not a source-store edit).

## Decisions

- Added a NEW alternation (`PHASE_STATUS_ENTERABLE_ALT`) rather than narrowing the existing
  `PHASE_STATUS_OPEN_ALT`, per the dispatch's own stated preference -- confirmed via live grep
  that the OPEN alternation has exactly one real consumer, so the blast radius of this change is
  the single H1 selector call site.
- The absence/unparseable `Depends on` default is strict ("depends on all prior phases"), not
  lenient -- an under-gated default is the exact failure mode this task exists to remove.
- `[BLOCKED]` is excluded from the ENTERABLE set unconditionally, without attempting to
  disambiguate a pre-decided decision gate from an ordinary temporarily-blocked phase (the marker
  text carries no such distinction).

## Plan Deviations

- Phase 1's unit-test fixture for "a value that embeds digits but is not a phase-number list"
  uses the literal text "Items 593 (shared utilities), 594 (skill base)" rather than the
  dispatch's own "Tasks 593 (...)" example, because the word "Tasks" followed by a number is
  itself a pattern the repo's own task-reference guard blocks under `agent-system/**`. Wrapped in
  a `task-ref-ok` exempt region as a backstop regardless; the substance of the assertion is
  unchanged.
- Phase 3 required an unplanned side-fix to `agent-system/extensions/core/index-entries.json`
  (not in that phase's named "Files to modify" list), to correct a `line_count` staleness the
  prose addition tripped in doc-lint.
- Phase 4's verification criterion "`verify-deploy.sh` passes in full" was not met in the strict
  all-green sense: 43 of 44 checks passed; Gate 8 (shell test-suite battery) failed on two
  suites, both excluded with evidence via a `#### Reasoned Exclusions` record on the Phase 4
  heading -- `test-gate-cache-equivalence.sh` is a pre-existing, repo-wide, already-known-failing
  gate-infrastructure meta-test (tracked in `known-failures.txt`, unrelated to this task), and
  `test-lake-build-guard.sh` is a confirmed transient concurrency flake (passed 51/0 in isolation
  immediately after the full-battery run). Phase 4 closed `[COMPLETED WITH EXCLUSIONS]`.

## Verification

- Build: N/A (bash scripts; `bash -n` and `shellcheck` clean on both touched scripts, diffed
  line-for-line against the pre-change deployed copies to confirm zero new findings)
- Tests: Passed -- `test-phase-heading-patterns.sh` 58/0, `test-orchestrate-cycle-plan.sh` 441/0
  (Group 9 Cases A-I), both from the deployed tree (`.claude/scripts/tests/`); each phase's own
  named `run-all.sh --only ...` covering-check subset passed in full (20 + 25 suites, 0 failures)
- Files verified: Yes -- `diff -q` silent between source and deploy for all five touched files
- `check-task-references.sh agent-system/` reports 0 unexempted occurrences

## Impacts

- A hard-mode (`--hard`) `/orchestrate` implement dispatch into a plan with a closed `[BLOCKED]`
  decision gate, or an unmet `Depends on` prerequisite, as its first open-by-marker heading will
  now select a later genuinely-enterable phase instead of repeatedly re-dispatching into the
  closed route.
- A plan with open headings but no enterable phase now produces a named, diagnostic blocked row
  ("H1: NO ENTERABLE PHASE", naming each rejected heading and its reason) instead of silently
  falling through to an unscoped dispatch.
- Plan authors now have a mechanical, not merely advisory, reason to keep `Depends on` fields
  accurate and to place a pre-decided `[BLOCKED]` gate with `Depends on: none` per
  `plan-format.md`'s existing authoring guidance.

## Follow-ups

- None owed by this task. `test-gate-cache-equivalence.sh`'s standing failure is tracked
  separately (consistent with the existence of a distinct, already-filed task on making the full
  gate viable under batch concurrency).

## References

- Report: `specs/638_orchestrate_enterable_phase_selector/reports/01_enterable_phase_selector.md`
- Plan: `specs/638_orchestrate_enterable_phase_selector/plans/01_enterable-phase-selector.md`
- Handoffs: `specs/638_orchestrate_enterable_phase_selector/handoffs/`
