# Implementation Summary: Task #418

- **Task**: 418 - Make the lint-fixture-test family's subject resolution explicit and self-declaring
- **Status**: [COMPLETED]
- **Started**: 2026-11-06T21:00:00Z
- **Completed**: 2026-11-07T05:40:00Z
- **Effort**: ~11 hours across all 8 phases
- **Dependencies**: None
- **Artifacts**: plans/01_explicit-subject-resolution.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

The lint-fixture-test family's deploy-tree-first/source-store-fallback subject resolution is
now explicit, mode-selectable, and self-declaring across the full measured 70-suite family.
`common_test_resolve_subject` (three modes: `deployed`, `source-store`, `deploy-tree-first`,
with a `CORE_TEST_SUBJECT_MODE` environment override that applies only to the preference case)
plus `common_test_declare_subject` (a mandatory `[SUBJECT] <absolute path>` declaration line)
replace every hand-duplicated local function, every inline `CANDIDATES`-array loop, and every
mode-implicit call to the old `common_test_resolve_candidate` helper. A new gate-27 content
lint (`lint-subject-resolution-declaration.sh`) mechanically blocks a new suite from
reintroducing any of the three undeclared shapes, with a Layer-2 allowlist that started at 70
migration-pending entries and now drains to exactly 8 permanent, individually-reasoned
exemptions. The default resolution order stays deploy-tree-first, preserving the Inter-Cycle
Redeploy Checkpoint's pre/post divergence signal — confirmed live, post-redeploy, that a
deploy-tree-first suite now declares the deployed copy while a hard-selected source-store suite
still declares the source-store copy regardless of deploy state.

## What Changed

- `agent-system/extensions/core/scripts/lib/common.sh` — added `common_test_resolve_subject` and
  `common_test_declare_subject`; corrected the stale population figure in
  `common_test_resolve_candidate`'s own header comment.
- `agent-system/extensions/core/scripts/tests/test-common-lib.sh` — mode, declaration, fallback,
  precedence, and checkpoint-property fixtures for the two new functions.
- `agent-system/extensions/core/scripts/lint/lint-subject-resolution-declaration.sh` — new
  two-layer content lint (gate 27): four structural checks (hand-duplicate function, inline
  array/loop, missing declaration, unmigrated implicit order) against a Layer-2 allowlist that
  now holds 8 permanent exemptions and zero migration-pending entries.
- `agent-system/extensions/core/scripts/tests/test-lint-subject-resolution-declaration.sh` — the
  new lint's own seeded-violation suite.
- `agent-system/extensions/core/scripts/gate-registry.data`, `verify-deploy.sh`,
  `manifest.json` — gate 27 registered and wired.
- 70 suites under `agent-system/extensions/core/scripts/tests/` migrated to the explicit
  mechanism, across three measured shapes: 20 shared-helper callers (Group A), 12
  hand-duplicated local functions (Group B), 38 inline `CANDIDATES`-array loops (Group C, in two
  19-suite batches). Each suite's effective resolution order was preserved exactly — the
  majority default to `deploy-tree-first`; a meaningful minority (confirmed via two
  genuinely-divergent fixture directions) hard-select `mode=source-store` or `mode=deployed`
  because they validate a pre-deploy source-store edit under active development, where a
  deploy-dependent fallback would silently test stale logic.
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — corrected
  the stale "73 files...41 use" sentence to the measured 70-suite/three-shape breakdown; the
  Inter-Cycle Redeploy Checkpoint's rejected-design rationale now states the divergence property
  rests on each suite's declared mode, not an implicit argument order.
- `agent-system/extensions/core/context/standards/shell-script-testing.md` — new "Explicit
  deployed/source-store subject resolution" section documenting the three historical shapes, the
  mode vocabulary, the `CORE_TEST_SUBJECT_MODE` precedence rule, the mandatory declaration, and
  gate 27 as the mechanical enforcement.
- `agent-system/extensions/core/index-entries.json` — line_count corrections for the two edited
  docs.
- A redeployed `.claude/` tree (two redeploys: one mid-Phase-8 discovery pass, one final).

## Decisions

- **Argument-order correctness over copy-paste convenience**: `common_test_resolve_subject`'s
  mode=source-store/deployed branches read a FIXED positional slot (`$4` for source-store, `$3`
  for deployed), not "whichever candidate the old helper tried first." A Phase 3 migration bug
  (both confirmed non-default-order callers silently declaring the DEPLOYED copy instead of the
  intended source-store copy, because the old helper's try-order was copied into the new
  function's fixed slots without re-mapping) was found and fixed before Phase 4 began, via
  empirical `[SUBJECT]`-output verification rather than trusting the plan's own prior
  verification note.
- **The gate-27 allowlist, not a fresh grep, is the authoritative per-phase roster.** A naive
  `grep -l '.claude/scripts' | grep -L resolve_candidate` over-matches badly against an
  already-partially-migrated corpus. Every batch's membership was confirmed against the lint's
  own Layer-2 data instead.
- **A directory resolution derives from a resolved file's directory**, never a second parallel
  directory-candidate loop (which would re-trip the lint's own structural checks). Two suites
  needed a whole-tree copy source rather than one named file; both now take `dirname` of a
  representative resolved file.
- **Content-gated resolution (10 sites in one suite) consolidated into one file-local helper**
  (`resolve_content_gated` in `test-validate-state.sh`) built on `common_test_resolve_subject`,
  rather than ten duplicated custom loops — `common_test_resolve_subject`'s pure existence check
  cannot express "resolved AND contains this check's identifier," so the helper adds exactly that
  gate on top of the shared primitive.
- **Comment-induced false positives are a confirmed, recurring hazard**: gate 27's
  `MISSING_DECLARATION` check is a naive whole-file substring count of
  `common_test_resolve_subject` vs `common_test_declare_subject`. An explanatory comment naming
  the resolver function by its literal identifier — without an equal-count mention of the
  declare function — trips a false-positive violation. Hit and fixed 5 times across Phases 4-6
  by saying "the shared resolve-subject helper" in prose instead.

## Plan Deviations

- None against any phase's own task list. All deviations the plan anticipated (the two
  non-default-order Group A callers, `test-task-type-detect.sh`'s non-subject-resolution
  exemption, `test-deploy-root-guard.sh`'s confirmed migration-family membership) were resolved
  exactly as the plan's own contingencies described.

## Verification

- Build: N/A (shell corpus, no compiled build step)
- Tests: Passed — every one of the 70 migrated suites, plus the new lint's own suite, produces
  its prior verdict unchanged on the freshly-redeployed tree (confirmed via a scoped
  `run-all.sh --only` run over all 71 basenames: 67 passed, 4 failed, all 4 confirmed
  pre-existing and unrelated to this task — see Follow-ups)
- Files verified: Yes
- Gate 27 (`verify-deploy.sh --only-gate 27` and the full gate set alike): RUN, never SKIP,
  "Total violations: 0" in every post-migration check
- Checkpoint divergence property reconfirmed live, post-redeploy: a deploy-tree-first suite
  (`test-issue-record.sh`) now declares the deployed copy; a hard-selected source-store suite
  (`test-gate-out-derived-staleness.sh`) still declares the source-store copy regardless of
  deploy state
- `grep -c '\[SUBJECT\]'` across all 71 suites run individually: 164 declaration lines total,
  confirming every suite in the family declares its subject
- `bash .claude/scripts/verify-deploy.sh "$(git rev-parse --show-toplevel)"` (full gate set,
  explicit source-store TARGET, final run): 3 of 42 checks failed, all three pre-existing and
  unrelated (see Follow-ups); every other gate, including the new gate 27, passed

## Impacts

- A green run of any suite in this family can no longer be silently vacuous: the printed
  `[SUBJECT] <path>` line always names the exact copy that was actually exercised, closing the
  originating defect class (editing the source store, then running the test suite before a
  redeploy, silently testing the stale deployed copy instead of the change under test).
- A new suite under `scripts/tests/` reintroducing any of the three undeclared/implicit-order
  shapes is now mechanically blocked by gate 27 rather than relying on review discipline alone.
- The Inter-Cycle Redeploy Checkpoint's pre/post divergence signal is unchanged in its default
  behavior and now additionally documented as depending on each suite's declared mode rather
  than an implicit, unstated convention.

## Follow-ups

- Four pre-existing, unrelated failures were newly discovered during this task's own
  verification passes, none caused by or attributable to this task's own edits (confirmed via
  git-history bisection and/or `git stash push -- <path>` isolation for each):
  - Gate 8 `test-postflight-deploy-gate.sh` and `test-redeploy-checkpoint-promotion.sh`: both
    already red on the pristine, pre-migration committed tree (confirmed by stashing this task's
    own edit out, re-running, and restoring); verdict unchanged by this task's migration.
  - Gate 8 `test-task-type-detect.sh`: its permanently-exempted `REAL_EXT_ROOT` fallback branch
    calls a helper that tests `[ -f ]` against a path that is always a directory, so the branch
    always fails when reached (confirmed byte-identical in the pre-task-418 commit history).
  - Gate 8 `test-lint-unit-integration-boundary.sh`: 3 `suite-classification.data` mismatches,
    none touching any file this task edited.
  - Gate 22 (shellcheck, `agent-system/extensions/lean/scripts/lean-plan-compliance-check.sh`)
    and Gate 24 (dead-command-recommendation, two `/ide` references in
    `agent-system/extensions/memory/context/project/memory/`): both in extensions this task's
    file_scope never touches.
  - None of the five were fixed here, per this task's own explicit directive to attribute
    nothing from pre-existing, unrelated failures. A future task may want to fold the newly
    discovered four into the repository's durable known-unrelated-failures record alongside the
    three the task description already enumerated (`test-detect-noop-bash.sh`,
    `test-four-tier-conflict.sh`, `test-guard-git-push.sh`).
- The checkpoint-coverage follow-up `batch-orchestration-guardrails.md` recommends ("running
  only the ~40 deploy-tree-first suites against gate 8 post-deploy, cheaply") remains explicitly
  out of scope, per the task description, and was not folded in or created from here.

## References

- Plan: `specs/418_explicit_lint_fixture_test_subject_resolution/plans/01_explicit-subject-resolution.md`
- Progress files: `specs/418_explicit_lint_fixture_test_subject_resolution/progress/phase-{1..8}-progress.json`
- Handoffs: `specs/418_explicit_lint_fixture_test_subject_resolution/handoffs/phase-{3,4,5,6,7}-handoff-*.md`
- Originating issue log entry: `specs/411_refactor_verify_deploy_gate_framework/issues.jsonl`,
  `iss_1792085973348_eyqwMs`
