# Implementation Summary: Task #244

- **Task**: 244 - check-task-references.sh: scan repo-appropriate roots instead of a hard-coded nvim-repo TREE_ROOTS list
- **Status**: [COMPLETED]
- **Started**: 2026-09-29T02:10:00Z
- **Completed**: 2026-09-29T04:20:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_repo-appropriate-scan-roots.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Fixed two independent defects absorbed into one task. `check-task-references.sh` enumerated a
hard-coded `TREE_ROOTS` list encoding this repo's own layout, so a consumer repo (Verification,
ModelChecker) got a silent zero-finding scan instead of real coverage; it now enumerates the
whole git-tracked repository minus `specs/**` via one `git ls-files` walk, and an explicit
`PATH_SCOPE` anywhere in the repo is scanned instead of exiting 2. `validate-wiring.sh` hard-
failed on a missing `.opencode` (or `.claude`) tree instead of treating an undeployed system as
normal; it now emits a `[SKIP]` line per absent tree arm. Both fixes ship with new fixture-driven
regression suites, and the enforcement narrative in `task-reference-exemptions.md` no longer
asserts the old four-root model.

## What Changed

- `agent-system/extensions/core/scripts/check-task-references.sh` — replaced hard-coded
  `TREE_ROOTS`/`TREE_COUNT`/`REPORT_KEYS` with a single repo-wide `git ls-files` scan (label
  `"repo (excluding specs/)"`, enum path `"."`); dropped the `PATH_SCOPE`-must-fall-under-
  `TREE_ROOTS` validation and its `exit 2`; changed the existence guard from `-d` to `-e` so a
  single-file `PATH_SCOPE` is scanned rather than incorrectly skipped; rewrote the header comment
  contract. Per-finding line format (`  $rel:$finding`, the `verify-deploy.sh` gate 4 parsing
  contract) preserved verbatim.
- `agent-system/extensions/core/scripts/validate-wiring.sh` — `main()`'s `.claude` and `.opencode`
  arms each now guard on `[[ -d "$PROJECT_ROOT/{.claude,.opencode}" ]]` before calling
  `validate_core_system`/`validate_extensions_loaded`, emitting a `log_info "[SKIP] ... does not
  exist under $PROJECT_ROOT"` line (mirroring `check-task-references.sh`'s own `[SKIP]` wording)
  instead of cascading `[FAIL]` rows when a tree is genuinely undeployed.
- `agent-system/extensions/core/scripts/tests/test-check-task-references.sh` (new) — 11-assertion
  fixture-driven suite: a consumer-repo-shaped `git init` fixture (`docs/`, `README.md`, `code/`,
  `.github/`, `specs/`, no `agent-system/extensions`/`lua`/`.memory`/`.opencode`) proves `docs/`,
  source-dir, and `README.md` citations are found; `specs/**` and `task-ref-ok`-marked and
  gitignored citations are not; `PATH_SCOPE` scoping, non-existent-scope `[SKIP]`, and single-
  file-scope cases all behave correctly; the gate 4 finding-line regex is asserted directly; and
  a lint/hook scope-agreement case proves `check-task-references.sh` and
  `validate-no-task-references.sh` never diverge on which files are in scope. Verified against a
  reverted (pre-fix) copy of the script: the docs/source-dir/PATH_SCOPE/gate-4-regex/agreement
  assertions all correctly FAIL, proving the suite exercises the actual fix.
- `agent-system/extensions/core/scripts/tests/test-validate-wiring.sh` (new) — 6-assertion
  fixture-driven suite covering `.claude`-present/`.opencode`-absent (SKIP naming `.opencode`, no
  `.opencode`-attributed FAIL, clean exit 0, a deliberately-broken `.claude` file still exits 1
  attributed to `.claude`), the mirror case, and the closest achievable equivalent of "both trees
  absent" (see Plan Deviations). Also verified to correctly FAIL against a reverted (pre-fix)
  copy of the script.
- `agent-system/extensions/core/context/standards/task-reference-exemptions.md` — Enforcement
  section's two four-root assertions rewritten to describe the repo-wide-minus-`specs/**` scan;
  added a sentence recording that the lint and the write-time hook now share exactly one scope
  predicate (`is_exempt_path`); added a new "Design Principle: Default to Repo-Wide Scope, Never
  a Hard-Coded Directory List" subsection capturing the research report's Context Extension
  Recommendation.
- `agent-system/extensions/core/rules/no-task-references-in-deliverables.md` — verified only, no
  edit needed; its "entire repository EXCEPT `specs/**/*`" claim is now backed by the lint rather
  than merely asserted.
- `agent-system/extensions/core/manifest.json` — registered the two new test scripts in
  `provides.scripts` (found missing via doc-lint/`verify-deploy.sh` gate 5 during Phase 6
  verification; not anticipated in the plan).
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt` — two advisory rows added for
  the new suites (measured wall time).

## Decisions

- Option (a), coverage, chosen over option (b), carve-out (requirement 7): the repo-wide scan is
  measured byte-identical (0/0) to the old four-tree scan in this repo, so closing the gap costs
  nothing here.
- `git ls-files` used directly rather than a per-repo config file or nvim-layout detection: it
  already respects `.gitignore`, producing the measured equivalence with no new exemption
  machinery.
- `scripts/lib/task-reference-patterns.sh` and `hooks/validate-no-task-references.sh` left
  unmodified (requirements 4, 8) — both were already correctly scoped; only the *enumeration* in
  the batch lint was wrong. A dedicated test asserts they agree.
- `check-task-references.sh`'s existence guard changed from `-d` to `-e` (not stated verbatim in
  the plan's task list, but required by the plan's own goal that a single-file `PATH_SCOPE` be
  scannable rather than skipped).

## Plan Deviations

- **Phase 5, Assertion (e)** altered: literal "both trees absent gives exit 0 with two `[SKIP]`
  lines" cannot be constructed via subprocess invocation, because `deploy-root-guard.sh` requires
  the running `validate-wiring.sh` copy's own parent-of-parent directory to be literally `.claude`
  or `.opencode` (no `REPO_ROOT`-style override exists for this script, unlike
  `check-task-references.sh`) — the tree hosting the runner necessarily exists on disk. Realized
  the closest achievable equivalent instead: a runner-hosting `.claude` tree with zero real
  payload, `.opencode` genuinely absent, invoked with `--opencode` so the `.claude` arm's
  conditional is never entered — proving the same underlying guarantee (requesting an undeployed
  tree yields SKIP and zero failures) without the literal double-absence. Documented in the
  suite's header and in the plan's own checklist annotation.
- **Phase 6**: registering the two new test scripts in `manifest.json`'s `provides.scripts` was
  not an explicit plan task but was required — doc-lint and `verify-deploy.sh` gate 5 both flag
  an undeclared script file on disk as a FAIL. Added as a necessary correction within Phase 6's
  scope (full gate run).

## Verification

- Build: N/A (shell scripts)
- Tests: `test-check-task-references.sh` (11/11 pass), `test-validate-wiring.sh` (6/6 pass), both
  confirmed to correctly FAIL against a reverted pre-fix copy of their respective target script.
  Full `run-all.sh`: 83 passed, 10 failed, 93 total — every one of the 10 failures traced to
  files outside this task's `file_scope` (concurrent sibling tasks 139/163/199/43/207/162 landing
  changes into the same shared tree during this dispatch; e.g. `test-common-lib.sh`'s single
  failure names `backfill-file-scope.sh`, owned by a sibling task). Neither of this task's two
  new suites, nor `check-task-references.sh`/`validate-wiring.sh` themselves, appear among the
  failures.
- `verify-deploy.sh --only-gate 3,4,5 --findings`: gate 4 (task-reference lint) PASS. Gate 3
  (doc-lint) and gate 5 (manifest parity) each show exactly one FAIL, both confined entirely to
  the `literature` extension's concurrent, in-flight `zotero-generate-export.sh` work (a
  different task's file_scope) — the `core` extension section of doc-lint shows a clean `OK`
  (only an unrelated pre-existing `README.md older than manifest.json` WARN).
- shellcheck: unavailable in this environment (broken `/nix/store` symlink); could not be run for
  either the modified or the baseline version of either script, so no regression could be
  introduced or ruled out by this tool specifically. `bash -n` clean on both.
- Files verified: Yes (all new/modified files confirmed on disk, non-empty).
- Requirement 1 (nvim repo scan equivalence): confirmed empty-diff three times — Phase 1 baseline,
  immediately post-Phase-2, and immediately before the final Phase 6 commit.
- Requirement 2 (consumer repo scan coverage): confirmed via fixture (`docs/`, `README.md`,
  `code/` all found).
- Requirement 3 (`PATH_SCOPE` outside old TREE_ROOTS never exits 2): confirmed via fixture and
  direct manual runs (`after`, `README.md`, a non-existent scope — all exit 0 or 1, never 2).
- Requirement 4 (shared library untouched): confirmed —
  `scripts/lib/task-reference-patterns.sh` was not modified.
- Requirement 8 (lint/hook agreement, no drift): confirmed via the dedicated fixture assertion;
  `hooks/validate-no-task-references.sh` was not modified.

## Impacts

- Any future consumer repo deploying this agent-system (regardless of its own directory layout)
  now gets a genuinely repo-wide task-reference lint instead of a silently-empty one.
- `validate-wiring.sh all` no longer produces a misleading FAIL cascade in a consumer that has
  never deployed OpenCode (or, symmetrically, Claude Code) — its exit status now reflects only
  the trees actually present.
- The Enforcement narrative in `task-reference-exemptions.md` now accurately describes what the
  lint does, closing the drift between the rule's stated repo-wide reach and its prior
  four-tree-only implementation.

## Follow-ups

- None required by this task's scope. The research report's other Context Extension
  Recommendation (a cross-cutting standard capturing the general repo-wide-default principle) was
  folded directly into `task-reference-exemptions.md` rather than deferred.

## References

- `specs/244_check_task_references_repo_appropriate_roots/reports/01_repo_appropriate_scan_roots.md`
- `specs/244_check_task_references_repo_appropriate_roots/plans/01_repo-appropriate-scan-roots.md`
- `agent-system/extensions/core/scripts/check-task-references.sh`
- `agent-system/extensions/core/scripts/validate-wiring.sh`
- `agent-system/extensions/core/scripts/tests/test-check-task-references.sh`
- `agent-system/extensions/core/scripts/tests/test-validate-wiring.sh`
- `agent-system/extensions/core/context/standards/task-reference-exemptions.md`
