# Implementation Summary: Task #554

- **Task**: 554 - file_scope external source store containment
- **Status**: [COMPLETED]
- **Started**: 2026-11-10T16:00:00Z
- **Completed**: 2026-11-10T21:30:00Z
- **Effort**: ~5.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_source-store-containment-remedy.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Implemented all six phases of the plan adopting design options (b) and (c) together: a shared
source-store path classification library; an out-of-repository pre-check and repository-naming
notice at the phase-commit site, textually distinct from the ordinary undeclared-scope message; a
single-pathspec, fail-open-unconditional second-repository commit mechanism; a shape-based refusal
of unexpanded-shell-variable `file_scope` entries at the harvest and plan-validation authoring
boundaries; and the matching documentation, manifest derivation, and deploy. All four acceptance
criteria are satisfied with test evidence; the inertness property (this repository classifies its
own `agent-system/**` paths `IN_REPO`, unaffected by any of this work) held across every one of
this task's own six phase commits.

## What Changed

- `agent-system/extensions/core/scripts/lib/source-store-path-lib.sh` — new library: exports
  `source_store_classify <repo_root> <path>` (prints `IN_REPO`, `SOURCE_STORE<TAB>...`, or
  `OUT_OF_REPO<TAB>...`) and `source_store_unexpanded_variable <string>`. Fail-soft on every
  missing dependency or malformed input; sets no shell options a caller inherits.
- `agent-system/extensions/core/scripts/tests/test-source-store-path-lib.sh` — new suite: 21
  assertions covering the relative and absolute source-store shapes, an unclaimed
  out-of-repository path, an ordinary in-repository path, the inertness guard, both symlink cases,
  every fail-soft input, and the unexpanded-variable predicate.
- `agent-system/extensions/core/scripts/plan-file-scope-harvest.sh` — added the
  unexpanded-variable refusal to the existing final refusal stage, composing with the existing
  deployed-tree refusal over the same merged array; consumes `source_store_unexpanded_variable`.
- `agent-system/extensions/core/scripts/validate-artifact.sh` — added the matching
  authoring-shape advisory (shape iv) beside the existing three, at the same advisory severity.
- `agent-system/extensions/core/scripts/git-commit-phase.sh` — sources the classification library
  early, fail-soft; classifies every derived `files_touched` entry BEFORE the existing Containment
  Self-Check; a `SOURCE_STORE`/`OUT_OF_REPO` verdict drops the path with repository-naming
  wording under a new `source store excursion` issue class (never `scope excursion`), never
  deposited into `proposed_file_scope`; wires a fail-open-unconditional invocation of
  `commit-source-store-path.sh` once per classified path, with an outcome-aware notice and a
  non-fatal issue-log record on every outcome.
- `agent-system/extensions/core/scripts/commit-source-store-path.sh` — new script: single-pathspec
  second-repository commit with up-front refusals (own-repository-root, not-a-git-tree, detached
  HEAD, in-progress merge/rebase/cherry-pick/bisect, existing `index.lock`, missing target file,
  empty diff) and its own exit-code vocabulary; documented as never fatal to any caller.
- `agent-system/extensions/core/scripts/tests/test-commit-source-store-path.sh` — new suite: 20
  cases covering the happy path (with the untouched-foreign-dirty-file assertion), the benign
  no-op, and all 6 refusal reasons plus the usage error.
- `agent-system/extensions/core/scripts/tests/test-plan-file-scope-harvest.sh` — +9 cases (26-29
  plus header updates) for the unexpanded-variable refusal.
- `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` — +2 cases (FTM-shape(g)
  positive, (h) negative) for the matching advisory.
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` — +6 cases (29-34): the
  disjoint-repository classification and wording, the genuinely-out-of-repository-unclaimed case,
  the acceptance-criterion-3 regression pin, the in-this-repository inertness case, and the
  Phase 4 end-to-end landing/fail-open cases, plus a new `build_source_store_repo()` fixture
  helper.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — new section documenting
  the different-repository containment nuance, the classification, the single-pathspec
  second-repository commit's fail-open posture, and the named residuals.
- `agent-system/extensions/core/context/formats/plan-format.md` — `Files to modify` field
  definition extended with the sanctioned source-store path form and the unexpanded-variable
  prohibition.
- `agent-system/extensions/core/agents/planner-agent.md` — new phase-authoring obligation (item
  10; items 11/12 renumbered).
- `agent-system/extensions/core/manifest.json` — `provides.scripts` entries for the 4 new scripts.
- `agent-system/extensions/core/index-entries.json` — regenerated `line_count` rows for the two
  edited context files.
- A regenerated deployed tree under `.claude/**`, produced by `deploy-headless.sh` alone; every
  one of this task's source-store files confirmed byte-identical to its deployed copy.

## Decisions

- The research report's recommendation 1 (a payload-bearing reserved marker,
  `__SOURCE_STORE__:<extension>/<path>`) was rejected: the existing `__WHOLE_TREE__` sentinel is
  safe precisely because it is slashless and inert against every real-path predicate; a
  slash-and-colon marker gives up that inertness and reproduces the original defect in sanctioned
  clothing. The source-store-relative path form already in universal use needs no new notation.
- `source_store_classify`'s fourth field (for a `SOURCE_STORE` verdict) is the tested path
  expressed relative to the resolved source repository's TOPLEVEL, not relative to `source_dir` —
  this is what makes the emitted path directly usable as a `git add` pathspec inside the second
  repository. A first implementation emitted the wrong (source_dir-relative) field; caught and
  fixed by this task's own end-to-end Phase 4 test before landing (see Plan Deviations).
- The repository-containment rule reuses `git-commit-scoped.sh`'s V9 parent-only resolution
  predicate verbatim in spirit (never resolving a pathspec's final component), preserving the
  measured leaf-symlink-safety property.
- The second-repository commit mechanism is fail-open unconditionally: its own exit code never
  propagates into the committing repository's commit or exit code, and every outcome (success,
  benign no-op, failure) is recorded non-fatally in the issue log.

## Plan Deviations

- **Phase 4** (bugfix, not a design deviation): the classification library's SOURCE_STORE
  attribution originally emitted the fourth field relative to `source_dir` rather than relative to
  `source_toplevel` as the library's own documented contract requires. Found and fixed during
  Phase 4's own end-to-end verification (the second-repository commit failed with "file does not
  exist" until corrected); `test-source-store-path-lib.sh`'s Cases 1/2 were corrected to match.
- **Phase 5**: the phase's own stated `verify-deploy.sh --skip-slow --only-gate 3,4` exits-0
  criterion did not hold at Phase 5's own close, because gate 3 correctly flagged the 4 scripts
  created in Phases 1/4 as undeclared in `manifest.json` — explicitly Phase 6's own job, not
  Phase 5's. Resolved by proceeding to Phase 6, which performs the manifest derivation and re-runs
  the complete gate set.
- **Phase 6**: the complete, unscoped `verify-deploy.sh` gate run was contended mid-dispatch by a
  concurrently-dispatched sibling task's own in-flight edits and, later, its own live test run
  holding the shared `specs/.gate-lock` mutex (confirmed via `ps`, git log, and git diff —
  every contended path traced to the sibling's own declared scope or to pre-existing, unrelated
  conditions). This task's own test suites were verified directly, bypassing the shared lock, and
  all 309 assertions across 5 suites pass. See the issue log for the full per-finding attribution.

## Verification

- Build: N/A (shell scripts; `bash -n` and `shellcheck -S warning` clean on every new/edited
  script).
- Tests: Passed — test-source-store-path-lib.sh 21/21, test-commit-source-store-path.sh 20/20,
  test-plan-file-scope-harvest.sh 48/48, test-validate-artifact.sh 136/136,
  test-git-commit-phase.sh 84/84 (309 assertions total, all directly run).
- Files verified: Yes — every source-store edit confirmed byte-identical to its deployed `.claude/`
  copy after `deploy-headless.sh`; `index-entries.json` line counts exact; `manifest.json`
  declares exactly the 4 new scripts and nothing foreign.
- `check-record-versioning.sh` and `check-task-references.sh`: 0 BLOCKING findings on every
  edited markdown file.

## Impacts

- A dispatched agent's phase commit against an external source-store path now either lands there
  automatically or produces an unambiguous, repository-naming notice — no more silent,
  indistinguishable-from-an-ordinary-excursion drop.
- A planner (or any other authoring surface) that writes an unexpanded shell variable into a
  `Files to modify` entry is warned at harvest time and advised at plan-acceptance time, rather
  than silently losing the entry.
- Both mechanisms are provably inert in a repository that owns its own source store (this
  repository), confirmed operationally across every one of this task's own phase commits.

## Follow-ups

- Named residuals (deliberately out of this task's scope): the whole-task completion commit site
  (`orchestrate-cycle-postflight.sh`) and `git-commit-scoped.sh`'s own V9 out-of-repository guard
  keep their existing behaviour; the direct `--file-scope-add` write path does not gain the
  unexpanded-variable refusal (its own test suite sits in a separately declared scope).
- The regenerated-derived-surface and declared-vs-true-blast-radius classes (a different defect:
  declared scope narrower than the scope a change mechanically forces, entirely within one
  repository) belong to the three open records that already own them, cited in the plan's
  Non-Goals.
- Gate 24's 2 pre-existing `/ide` dead-command references in the memory extension remain
  unresolved — outside this task's declared scope.

## References

- Plan: `specs/554_file_scope_external_source_store_containment/plans/01_source-store-containment-remedy.md`
- Research: `specs/554_file_scope_external_source_store_containment/reports/01_source-store-containment-research.md`
- Progress files: `specs/554_file_scope_external_source_store_containment/progress/phase-{1..6}-progress.json`
- Handoffs: `specs/554_file_scope_external_source_store_containment/handoffs/phase-{1..5}-handoff-*.md`
