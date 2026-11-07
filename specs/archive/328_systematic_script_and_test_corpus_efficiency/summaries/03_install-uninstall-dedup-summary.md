# Implementation Summary: Task #328

- **Task**: 328 - Systematic script and test corpus efficiency
- **Status**: [IN PROGRESS]
- **Started**: 2026-11-05T02:50:00Z
- **Completed**: 2026-11-05T03:20:00Z
- **Effort**: ~1 hour
- **Dependencies**: 170 (scoped; not binding on this phase — see below), 411 (gate-framework refactor; unaffected by this phase)
- **Artifacts**: plans/03_markdown-corpus-consolidation.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closed Phase 9 of the plan ("Deduplicate the Extension Install/Uninstall Pair"): extracted the
mutual duplication between `install-extension.sh` and `uninstall-extension.sh` into a new shared
library, after first writing a characterization test since neither script had any prior test
coverage. Twelve of twenty plan phases remain `[NOT STARTED]` (Phase 10 next); this dispatch
closes a single clean phase boundary, not a context-exhaustion handoff.

## What Changed

- `agent-system/extensions/core/scripts/lib/extension-install-lib.sh` — new shared library:
  the argument/EXT_DIR/manifest validation preamble plus colored logging
  (`extlib_log_info/_warn/_error`, `extlib_usage_and_exit`, `extlib_resolve_ext_dir`,
  `extlib_validate_extension`), and two generic helpers (`extlib_install_symlinks`,
  `extlib_remove_symlinks`) that collapse what were six near-identical per-type symlink loop
  bodies (commands/skills/agents x install/remove) into parameterized calls.
- `agent-system/extensions/core/scripts/install-extension.sh` — 300 → 163 lines; now calls the
  shared library instead of hand-rolling validation, logging, and three symlink-creation loops.
- `agent-system/extensions/core/scripts/uninstall-extension.sh` — 243 → 107 lines; same
  consolidation on the removal side.
- `agent-system/extensions/core/scripts/tests/test-install-uninstall-extension.sh` — new
  characterization suite (17 cases), written and verified green against the pre-refactor
  scripts before any production edit, then re-verified green unchanged after the refactor.
- `agent-system/extensions/core/manifest.json` — registered the new lib and the new test file
  in the scripts array (alphabetical slots).
- `specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md`
  — Phase 9 heading marked `[COMPLETED]`, all five task-checklist items checked off with
  completion notes, and the Verification section annotated with confirmation notes.

## Decisions

- Widened the shared-lib extraction beyond the header/validation preamble to the six per-type
  symlink loops after the header-only version landed a positive NET-PROD (+13) with no later
  phase queued to pay it back (unlike the lint-library precedent, which had further migrations
  queued). The widened extraction landed NET-PROD -70.
- Preserved a genuine pre-existing behavioral discrepancy rather than normalizing it away:
  `install_agents` never checked an existing symlink's target before this extraction (unlike
  `install_commands`/`install_skills`); `extlib_install_symlinks`'s `check_target` parameter
  reproduces this exactly per call site.
- Left `merge_index_entries`/`remove_index_entries` untouched — their jq pipelines differ
  substantively (merge vs. filter) and are not part of the pair's mutual duplication; the
  post-refactor duplicate-block count (35/35 → 6/6) confirms the remaining overlap is no longer
  a meaningful target.

## Plan Deviations

- None (implementation followed the plan's stated tasks and verification exactly).

## Verification

- Build: N/A (shell scripts)
- Tests: Passed — `run-all.sh --only test-install-uninstall-extension.sh` 17/17; `shellcheck -x
  -S warning` clean on all touched/new files; full-corpus `lint-shellcheck.sh --verbose` 0
  findings across 415 files; `test-manifest-scripts-sync.sh` green (confirms manifest.json
  additions)
- Files verified: Yes
- Full redeploy/gate battery: deliberately NOT run this phase, per the plan's own declared
  Verification Tier (`local`) and Tier Justification — deferred to a later full-tier phase
  (Phase 20), consistent with Phase 8's `interface` tier being the reason THAT phase, unlike
  this one, included a redeploy check.

## Impacts

- Duplicate-block count for the install/uninstall pair dropped from 35/35 to 6/6
  (script-inventory.sh re-measure), removing it from the corpus's high-duplication ranking.
- NET-PROD this phase: -70 lines (`git diff --numstat`: 231 insertions, 301 deletions across the
  three touched production files).
- NET-TEST this phase: +274 lines (the wholly new characterization suite — a one-time
  test-infrastructure cost required by the zero-prior-coverage precondition, not a
  duplication-deepening positive-net).
- A recurring commit-pipeline defect (git-commit-phase.sh's containment self-check drops a
  legitimate path when a file_scope entry ends in a trailing slash, due to a double-slash bug)
  hit this phase's closing commit too (previously recorded against Phases 7 and 8); recovered
  via the established follow-up-commit pattern. Recommend a direct fix to
  `is_contained()` in `git-commit-phase.sh` (strip the trailing `/` before appending `/*`).

## Follow-ups

- Phase 10 next: "Deduplicate the Typst Script Pair" (`chapter-quality-check.sh` /
  `typst-element-lint.sh`). Re-measure via `script-inventory.sh --size-line` before acting.
- Minor, non-blocking: `script-inventory.sh`'s `has_test` detection still reports `false` for
  the install/uninstall pair and the new lib despite the new suite covering all three — a
  probe-accuracy gap for multi-target suites, not a correctness issue.
- Minor, non-blocking: `merge_index_entries`/`remove_index_entries` both assume a CWD-relative
  `specs/tmp/` scratch path (works in real invocations, which always run from the repo root;
  surfaced only because the test fixture initially ran from a scratch workdir). Worth hardening
  to an absolute or `$PROJECT_ROOT`-qualified path in a future hygiene pass.
- Recommend fixing `git-commit-phase.sh`'s recurring double-slash containment bug directly
  rather than continuing to rely on a follow-up commit every time it is hit.

## References

- Plan: `specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md`, Phase 9 section
- Progress: `specs/328_systematic_script_and_test_corpus_efficiency/progress/phase-9-progress.json`
- Handoff: `specs/328_systematic_script_and_test_corpus_efficiency/handoffs/phase-9-handoff-20261105T031308Z.md`
