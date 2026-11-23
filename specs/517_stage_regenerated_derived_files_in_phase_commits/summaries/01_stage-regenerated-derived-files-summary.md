# Implementation Summary: Task #517

- **Task**: 517 - Stage regenerated derived files in phase commits
- **Status**: [COMPLETED]
- **Started**: 2026-11-22T17:10:00Z
- **Completed**: 2026-11-23T01:50:00Z
- **Effort**: ~4.5 hours (matched estimate)
- **Dependencies**: #455 (semantic predecessor, completed); #513 (no edge, confirmed no shared
  files); #430 (shares `general-implementation-agent.md`, a single pointer line kept consistent)
- **Artifacts**: plans/01_stage-regenerated-derived-files.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Landed the execution half of the derived-surface-staleness friction first identified across four
recurrences in an external consumer repository: declaring a generated path does not regenerate
the file at it, and nothing in the phase-commit protocol told an implementing agent to re-run a
surface's regeneration entry point and stage its output inside the phase that staled it. All four
phases of the plan's decision (c) ruling landed: a generic, declaration-only obligation in the
commit protocol; a Site-2 staging-admission splice so a regenerated declared surface actually
survives the Containment Self-Check; a non-blocking staleness-detection backstop reusing the
already-built probe library; and a deploy/verify close with the companion-record recommendation
this record cannot itself discharge.

## What Changed

- `agent-system/extensions/core/context/checkpoints/checkpoint-commit.md` — added a 4-sentence
  obligation paragraph to `### 1. Determine Targeted Scope`: a phase that touches a declared
  derived-output surface must re-run that surface's own sanctioned, build-free regeneration entry
  point and stage the result in the same commit; names only the two `.claude-extensions.json`
  keys (`derived_artifact_probes`, `coupled_generated_surfaces`) and states the
  `coupled_generated_surfaces`-only asymmetry; a declaration-free repository owes nothing.
- `agent-system/extensions/core/agents/general-implementation-agent.md` — one pointer line in the
  Phase Checkpoint Protocol's step 5, pointing at the obligation's owning section.
- `agent-system/extensions/core/scripts/git-commit-phase.sh` — a third `file_scope_arr` splice
  (derived-output-prefix widening via `derived_probe_output_prefixes`) in the Phase-Commit
  Containment Self-Check, mirroring the widening Containment Sites 1 and 3 already carried; a
  non-blocking `derived_probe_run_all` staleness-backstop call sited after the
  second-repository-commit block and before the post-commit completeness check, with a named
  `warn()` and a `derived-surface staleness` issue-record class on a non-zero result, and
  exit-code invariance preserved; two new header subsections documenting both additions.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — recorded the
  derived-output-prefix member as a third per-site widening and the Site-2/Site-3 subsumption
  asymmetry (identical to the already-recorded own-task-directory asymmetry).
- `agent-system/extensions/core/context/standards/repo-level-declarations.md` — extended
  "Containment and the Derived-Output Exemption" to name all three Containment sites.
- `agent-system/extensions/core/scripts/lib/derived-artifact-probe-lib.sh` — header consumer list
  now names `git-commit-phase.sh` as a third consumer and no longer asserts exactly two
  postflight engines; no behavioral change.
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` — `lib/derived-artifact-probe-lib.sh`
  added to `REQUIRED_SCRIPTS`/`build_repo`'s sandbox; five new fixture cases (35: admit, 36:
  inert, 37: failing probe with exit-code invariance, 38: passing probe, 39: no-probes inert
  case). 97 cases pass in total.
- `agent-system/extensions/core/scripts/tests/test-derived-artifact-probe-lib.sh` — one new case
  pinning `derived_probe_run_all`'s fail-open/build-free posture under the phase-commit notice
  prefix on both an absent and an empty declaration. 15 cases pass in total.
- Deployed tree (`.claude/**`) regenerated via `deploy-headless.sh`; `index-entries.json`'s
  `line_count` pins for the three moved files reconciled as the deploy's own side effect.

## Decisions

- Phase 2's splice mirrors the engine-written-state splice's strict validation shape (`jq -e
  'type == "array" and (all(.[]; type == "string"))'`) rather than Site 3's looser,
  unvalidated shape, per the plan's explicit instruction.
- Phase 3's backstop sources the probe library idempotently: reuses it if Phase 2's splice
  already ran (inside the non-empty `file_scope_arr` guard), and falls back to sourcing it
  itself when that guard never ran (e.g. no declared `file_scope` at all), so the backstop
  reaches every phase commit regardless of whether `file_scope` was declared.
- Case 35/36's admit/inert fixtures in Phase 2 initially installed the probe library ad hoc
  per-fixture (since the formal `REQUIRED_SCRIPTS` declaration was explicitly Phase 3's own
  task); once Phase 3 landed that declaration, the ad hoc per-case copy was removed as redundant.

## Plan Deviations

- **Phase 4** (deploy step) altered: the first `deploy-headless.sh` run failed its own full
  verification gate on a `lint-scoped-commit-boundary.sh` PIPE-VIOLATION in Phase 3's Case 37 —
  a piped `grep` assertion whose pattern happened to embed the literal substring
  `git-commit-phase.sh:` (from the warn() message text under test), tripping that lint's
  naive line-level heuristic even though no real script invocation was piped on that line.
  Fixed by loosening the grep pattern to drop the literal script-name substring (still uniquely
  distinguishing); re-verified the suite (97/97 green) and the lint (0 violations) before
  re-running the deploy, which then landed clean (41/41 checks). This was a Phase 3 oversight
  caught and closed within Phase 4's own verification step, not a change to Phase 4's declared
  scope.

## Verification

- Build: N/A (meta task; no application build)
- Tests: `test-git-commit-phase.sh` 97/97, `test-git-commit-scoped.sh` 87/87,
  `test-derived-artifact-probe-lib.sh` 15/15 (verified against the edited source-store copy via
  `CORE_TEST_SUBJECT_MODE=source-store`) — all passed
- Lints: `lint-agent-contracts.sh`, `lint-anchor-pointer-collapse.sh`, `lint-shellcheck.sh`,
  `lint-scoped-commit-boundary.sh`, `lint-fixture-dependency-declaration.sh` — all clean
- `verify-touched.sh` over all 9 task-touched paths: 98 passed, 0 failed, 24 suites selected, 2
  owed (markdown-only files with no mapped suite, non-blocking)
- `deploy-headless.sh`: `RESULT=landed_verify_clean`, 41 checks / 0 failures
- `check-extension-docs.sh`: PASS for all 25 extensions; `index-entries.json` line_count pins
  for `checkpoint-commit.md` (130), `git-staging-scope.md` (1207), and
  `repo-level-declarations.md` (315) all reconciled
- Files verified: Yes
- Full gate set deferred to the batch-level `/orchestrate` close per this dispatch's Batch Gate
  Deferral directive, attributed back to this task by its own `modified_files`

## Impacts

- An implementing agent in ANY repository declaring `derived_artifact_probes` or
  `coupled_generated_surfaces` now has a standing, generic obligation (and a mechanical
  staging admission plus a non-blocking staleness backstop) to keep a declared derived surface
  in sync with the phase commit that staled it.
- A repository declaring neither key (including this one, and the originating consumer
  repository as of this writing) sees zero behavioral change — every new mechanism is strictly
  additive and fail-open.
- The companion-record recommendation below is necessary for the originating incident to
  actually stop recurring; this record alone does not close that loop.

## Follow-ups

- A companion record must be created in `~/Projects/BimodalLogic` (the originating consumer
  repository) declaring `derived_artifact_probes` and/or `coupled_generated_surfaces` for the
  FormalSystem inventory READMEs and `typst/generated/status.typ` — out of this repository's
  boundary to create or edit. Recorded via `issue-record.sh` (entry
  `iss_1795398220168_QgrK2I`) in addition to this summary.
- None beyond the companion record above.

## References

- Plan: `specs/517_stage_regenerated_derived_files_in_phase_commits/plans/01_stage-regenerated-derived-files.md`
- Research report: `specs/517_stage_regenerated_derived_files_in_phase_commits/reports/01_stage-regenerated-derived-files.md`
- Progress files: `specs/517_stage_regenerated_derived_files_in_phase_commits/progress/phase-{1,2,3,4}-progress.json`
- Handoffs: `specs/517_stage_regenerated_derived_files_in_phase_commits/handoffs/phase-{1,2,3}-handoff-*.md`
- Issue log: `specs/517_stage_regenerated_derived_files_in_phase_commits/issues.jsonl`
