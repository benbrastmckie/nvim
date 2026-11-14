# Implementation Summary: Task #601

- **Task**: 601 - Close the class of invocation-path-dependent repo-root resolution in test suites with a durable lint
- **Status**: [COMPLETED]
- **Started**: 2026-11-12T06:30:00Z
- **Completed**: 2026-11-12T14:40:00Z
- **Effort**: ~6 hours (plan estimated 5.75h)
- **Dependencies**: None
- **Artifacts**: plans/01_root-walkup-closure-lint.md, summaries/01_root-walkup-closure-lint-summary.md (this file)
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Built `lint-test-root-resolution.sh`, a durable, deploy-time-enforced lint (gate 29) that forbids
an unconditional fixed-depth parent walk used to compute a test suite's own repo root or
extensions root — the defect class where a suite's source-store copy and its deployed mirror sit
at different depths below the repository root, so a fixed-depth walk is correct from at most one
invocation path. The three previously-named live violating instances were migrated onto the
existing `common_test_repo_root` / `common_test_ext_root` helpers before the lint landed, so it
launches at zero violations. The lint is registered as gate 29, documented in
`context/standards/shell-script-testing.md`, and the source store has been redeployed.

## What Changed

- `agent-system/extensions/core/scripts/test-state-write-spill-names.sh` — root computation migrated to `common_test_repo_root`
- `agent-system/extensions/core/scripts/tests/test-source-store-path-lib.sh` — root computation migrated to `common_test_repo_root`
- `agent-system/extensions/core/scripts/tests/test-orchestrate-context-growth.sh` — three walk-up use sites migrated to a single `common_test_repo_root`-derived variable
- `agent-system/extensions/core/scripts/lint/lint-test-root-resolution.sh` — new standalone lint (gate 29's implementation), with a file-location-aware safe-depth boundary, anchor-offset tracking for the one recognized `CORE_DIR` indirection idiom, three detection shapes (single-line cd+pwd assignment, two-statement cd-then-pwd, bare inline use), two sanctioned guard shapes (first-attempt-then-fallback, validated candidate), a heredoc-body exclusion, and one reasoned allowlist entry
- `agent-system/extensions/core/scripts/tests/test-lint-test-root-resolution.sh` — new fixture suite (15 assertions, 7 fixture cases)
- `agent-system/extensions/core/scripts/tests/suite-classification.data` — one `unit` row for the new fixture suite
- `agent-system/extensions/core/scripts/gate-registry.data` — one appended row for gate 29
- `agent-system/extensions/core/scripts/verify-deploy.sh` — new `gate29_run()` function
- `agent-system/extensions/core/manifest.json` — registered both new scripts in `provides.scripts`
- `agent-system/extensions/core/context/standards/shell-script-testing.md` — new subsection stating the sanctioned-vs-forbidden root-resolution discriminator
- `specs/state.json` — task 601's own `file_scope` refined to include `manifest.json` (descriptive refinement, not a violation)
- Deployed `.claude/` tree — regenerated via `deploy-headless.sh`

## Decisions

- Detection computes a per-file SAFE_LEVELS boundary (1 for a flat `scripts/*.sh` file, 2 for a
  `scripts/tests/*.sh` or `scripts/lint/*.sh` file) rather than a fixed "any 2+-level walk is
  forbidden" rule — the latter was tried first and found to false-positive on a real, safe,
  currently-live 2-level walk (`test-manage-topics-create-order.sh`'s `TREE_ROOT`, which
  correctly resolves the extension-root boundary, not the repo root).
- Guard (a) was generalized from "git-rev-parse-specific" to "any enclosing
  `if [[ -z "$VAR" ]]` fallback block" after a cross-extension corpus dry run surfaced a real,
  safe, non-git ancestor-search fallback (`literature/test-lit-pipeline.sh`) that a narrower
  git-specific guard would have false-positived on.
- Guard (b) (validated candidate) was extended to recognize an assign-then-validate-shortly-after
  variant and a validate-then-assign-moments-ago variant, after a second corpus hit
  (`sapience/test-sapience-capture.sh`) exercised both.
- A fast-path pre-check (`grep -qE '\$(SCRIPT_DIR|CORE_DIR)(/\.\.){2,}'`) was added after an
  initial full-corpus run under deploy-time invocation came close to gate 29's own 30s declared
  timeout; the fast path narrows the expensive per-line analysis to the ~45 files that could
  possibly match, cutting a 195-file corpus run from ~25s to ~4s.
- Heredoc bodies are excluded from detection, since the lint's own fixture suite necessarily
  writes synthetic violating examples as literal text that would otherwise be mis-scanned as real
  violations in the suite's own source (the lint scans itself as an ordinary corpus member).

## Plan Deviations

- **Manifest registration** (Phase 4): not named in the plan's original Files to modify list;
  added after `test-verify-deploy-context-budget.sh` surfaced real gate3/gate13 findings against
  the two new, previously-unregistered scripts.
- **Detection/guard design generalized beyond the plan's literal prose** (Phase 2): see Decisions
  above; both extensions were required to avoid false positives against the live cross-extension
  corpus, not merely the core extension the plan's own research/planning had inspected.
- **Full gate set discharged via Batch Gate Deferral** (Phase 5): per this dispatch's own
  directive, a scoped selector narrowing was run instead of an independent full `verify-deploy.sh`
  battery; the full gate set runs once for the whole batch at the end of this `/orchestrate`
  invocation.
- **`deploy-headless.sh` invocation corrected mid-phase** (Phase 5): the bare invocation (no
  explicit `TARGET_REPO`), run from a non-repository-root cwd, resolved its default target
  incorrectly; caught immediately and re-run with the explicit repository-root argument.

## Verification

- Build: N/A (shell scripts)
- Tests: `test-lint-test-root-resolution.sh` — 15/15 assertions pass. Full corpus scan via
  `lint-test-root-resolution.sh` — 0 violations across 195 files (both source-store and deployed
  copies). `lint-gate-registry.sh` — 7/7. `--only-gate 29` and `--only-gate 3,13` against the
  deployed target — PASS. Selector-scoped `run-all.sh --only` checks across all three
  implementation phases plus the final documentation phase — every suite passes or is a
  pre-existing, `known-failures.txt`-documented EXPECTED/0-NEW failure unrelated to this task.
- Files verified: Yes

## Impacts

- Future test suites authored under `scripts/tests/` or `scripts/lint/` (in any extension) that
  reach for a fixed-depth parent walk to compute a repo root or extensions root will now be
  caught at deploy time by gate 29, rather than silently passing from one invocation path and
  failing (or worse, falsely passing) from the other.
- `agent-system/extensions/core/manifest.json`'s `provides.scripts` list is now the authoritative
  record of both new scripts; any future script addition must update it or trip gate3/gate13.

## Follow-ups

- None required for this task's own closure. The dispatch's stated Non-Goals remain open
  candidates for a future task: the five `zotero-*.sh` production scripts carrying the same
  underlying defect class (outside the "test suites" scan scope this lint deliberately targets),
  and any new helper needs in `scripts/lib/common.sh` (none arose here).
- Two pre-existing, unrelated defects were observed and recorded in this task's issue log but not
  fixed (out of scope): five suites missing a `suite-classification.data` row entirely
  (`test-commit-source-store-path.sh`, `test-lint-roadmap-batch-proposals.sh`,
  `test-mcp-merge-target.sh`, `test-source-store-path-lib.sh`,
  `test-validate-no-python-state-write.sh`), and `test-verify-deploy-context-budget.sh`'s
  eager-load-baseline/gate24 finding against `skill-orchestrate/SKILL.md` (owned by unrelated
  prior tasks).

## References

- `agent-system/extensions/core/scripts/lint/lint-test-root-resolution.sh`
- `agent-system/extensions/core/scripts/tests/test-lint-test-root-resolution.sh`
- `agent-system/extensions/core/context/standards/shell-script-testing.md`
- `specs/601_root_walkup_class_closure_lint/plans/01_root-walkup-closure-lint.md`
- `specs/601_root_walkup_class_closure_lint/reports/01_root-walkup-closure-lint.md`
