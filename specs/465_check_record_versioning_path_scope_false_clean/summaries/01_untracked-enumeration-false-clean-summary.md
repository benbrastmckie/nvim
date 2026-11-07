# Implementation Summary: Task #465

- **Task**: 465 - check-record-versioning.sh PATH_SCOPE mode reports false-clean on a file present on disk but not git-tracked
- **Status**: [COMPLETED]
- **Started**: 2026-11-07T00:16:00Z
- **Completed**: 2026-11-07T01:50:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_untracked-enumeration-false-clean.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Fixed a false-clean defect shared by `check-record-versioning.sh` and `check-task-references.sh`:
both lints enumerated their `PATH_SCOPE` scan corpus via a bare `git ls-files`, which returns
zero rows for a file that exists on disk but is not yet git-tracked, so the scan silently
iterated zero times and reported a clean verdict for a file it never examined. Extracted a
single shared enumeration library (`git-corpus-enum-lib.sh`) that scans the tracked-plus-untracked
union (gitignored content still excluded via `--exclude-standard`) and wired both lints to it,
adding three stderr-only diagnostics so "clean" and "not examined" can never be confused again.

## What Changed

- `agent-system/extensions/core/scripts/lib/git-corpus-enum-lib.sh` — new shared library:
  `git_corpus_enum` (tracked+untracked union enumeration), `git_corpus_unenumerated_report`
  (per-file loud-skip for excluded on-disk files in `PATH_SCOPE` mode), `git_corpus_untracked_count`.
  Header records the full sibling-enumeration-site audit the task required.
- `agent-system/extensions/core/scripts/tests/test-git-corpus-enum-lib.sh` — new fixture suite,
  10 cases, all passing.
- `agent-system/extensions/core/scripts/check-record-versioning.sh` — consumes the shared
  enumeration (replacing the bare `git ls-files` call in `scan_tree`), adds a
  `CORPUS_LIB_CANDIDATES` resolution block + required-function check (loud `exit 2` on a
  missing/stale library, matching the script's existing not-found-severity convention), emits
  the three stderr diagnostics, header updated. Exit codes and stdout line formats unchanged.
- `agent-system/extensions/core/scripts/tests/test-check-record-versioning.sh` — fixture now also
  carries `git-corpus-enum-lib.sh`; added the acceptance case (an untracked, on-disk BLOCKING
  file is scanned and yields exit 1) plus 3 supporting cases (gitignored-file loud-skip,
  `--quiet` survival, zero-enumeration diagnostic). 22/22 cases pass.
- `agent-system/extensions/core/scripts/check-task-references.sh` — identical wiring. This
  script had NO prior required-function loop at all, so one was added fresh. Exit codes and
  stdout line formats unchanged (gate 4's findings extractor is unaffected).
- `agent-system/extensions/core/scripts/tests/test-check-task-references.sh` — mirrored
  acceptance + 2 supporting cases added. 17/17 cases pass.
- `agent-system/extensions/core/manifest.json`, `agent-system/extensions/core/scripts/tests/suite-classification.data`
  — registered the two new files (`provides.scripts` entries, one new `unit` suite row).
- `agent-system/extensions/core/manifest.json` — continuation dispatch: added the missing
  `"gate-cost-model.csv"` entry to `provides.scripts` (via `sync-manifest-scripts.sh --write`),
  resolving the gate-3 finding the redeploy checkpoint held this task open for.
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` — corrected the
  check-record-versioning.sh entry to describe the union enumeration and loud-skip behavior.
- `agent-system/extensions/core/scripts/measure-gate-costs.sh`,
  `agent-system/extensions/core/scripts/gate-cost-model.csv` — repo-wide triage fix: the one
  untracked non-`specs/**` file in the repo carried a genuine new ADVISORY finding (bare
  "previously" vocabulary) once the union enumeration included it; reworded at the generator's
  two printf template sites and the already-generated CSV's matching header line.

## Decisions

- One shared library, not two copies: both lints must share enumeration semantics exactly
  (the task's own stated goal), so a single `git-corpus-enum-lib.sh` is sourced by both rather
  than inlining the union logic twice.
- The three stderr diagnostics are never routed through either script's `info()` helper, so
  `--quiet` cannot suppress them — verified by a dedicated test case in each suite.
- `git_corpus_unenumerated_report` fires only in `PATH_SCOPE` mode (never for a repo-wide `"."`
  scan), per the plan's Non-Goals — a repo-wide run never dumps the whole gitignored `.claude/`
  deploy tree to stderr.
- The sibling-enumeration audit (which other `git ls-files`-based scripts share the defect, which
  don't, and why) lives once in the new library's own header comment, not duplicated into the
  inventory doc.
- The one genuine new finding the fix surfaced (gate-cost-model.csv) was resolved by rewording
  its generator's prose, not by adding a `version-ok` marker — it is ordinary generated prose,
  not a literal detector-pattern test fixture.

## Plan Deviations

- Two additional fixes, neither a plan-checklist item, both corrections to this task's own new
  deliverable discovered only during Phase 4's post-redeploy verification: (1) a
  subject-resolution-declaration lint violation in the task's own new `test-git-corpus-enum-lib.sh`
  (it used an inline `LIB_CANDIDATES` for-loop; a concurrently in-flight sibling task's lint now
  requires `common_test_resolve_subject`/`common_test_declare_subject` — migrated in place);
  (2) that same new test file was missing its executable bit (a Phase 1 oversight), fixed with
  `chmod +x`. Both required a second/third `deploy-headless.sh` pass to carry the fixes into the
  deployed tree.

## Verification

- Build: N/A (shell scripts)
- Tests: `test-git-corpus-enum-lib.sh` 10/10, `test-check-record-versioning.sh` 22/22,
  `test-check-task-references.sh` 17/17 — all passing, including every pre-existing case
  unmodified.
- `lint-shellcheck.sh` clean over all touched shell files.
- Direct acceptance reproduction (source-store and deployed-copy): an untracked, on-disk file
  with a BLOCKING/task-reference occurrence under `PATH_SCOPE` yields exit 1, naming the file.
- Repo-wide `--quiet` comparison against the pre-change scripts: `check-record-versioning.sh`
  tracked-only and union enumeration now report byte-identical 3 BLOCKING / 833 ADVISORY (the
  one genuine delta was triaged and fixed); `check-task-references.sh` exit status unchanged
  (0 -> 0; the 13 newly-included untracked files carry no task-reference citations).
- Files verified: Yes (all new/modified files exist, are non-empty, pass shellcheck).
- Batch Gate Deferral (per dispatch): the full `verify-deploy.sh`/`run-all.sh` battery is
  deferred to the once-per-batch-invocation stage. This task's own scoped discharge:
  `run-all.sh --only test-git-corpus-enum-lib.sh,test-check-record-versioning.sh,test-check-task-references.sh`
  (3 passed, 0 failed) and `verify-deploy.sh --only-gate 4` (PASS, 1 check, 0 failures).
  `check-extension-docs.sh` (not a deferred tool) run directly: all extensions PASS.

## Impacts

- Any future lint or write-time hook that scans a file it has just created, before committing
  it, now gets a meaningful verdict under `PATH_SCOPE` mode instead of a false clean — the exact
  self-hygiene gap that motivated this task.
- `verify-deploy.sh` gate 4 (`check-task-references.sh`) is unaffected in exit-code/format terms,
  so no downstream gate-4 consumer needs any change.
- Two unrelated, pre-existing gate failures were observed and recorded (not fixed, out of
  scope): a load-induced gate10 timeout (confirmed green standalone) and 2 pre-existing
  `/ide` dead-command references in `agent-system/extensions/memory/**`.

## Follow-ups

- `check-extension-docs.sh:623`'s adjacent enumeration blind spot (a newly-written but uncommitted
  script is invisible to the manifest-declaration-parity check) was named during planning as a
  separate, deliberately out-of-scope record (different contract, different gate).
- The two pre-existing gate failures noted above (gate10 timeout, dead-command-recommendation in
  `agent-system/extensions/memory/**`) remain open for whichever task owns that territory.
- The full `verify-deploy.sh`/`run-all.sh` battery, deferred here per the dispatch's Batch Gate
  Deferral, still runs once at the end of the enclosing multi-task `/orchestrate` batch.
- **Continuation dispatch (gate-3 resolution)**: the redeploy checkpoint's self-attribution
  screen held this task open for `FINDING gate3 [core] FAIL: script file on disk NOT in
  provides.scripts: scripts/gate-cost-model.csv`, surfaced because this task's own
  `modified_files` named `gate-cost-model.csv`. Root cause unrelated to this task's own
  enumeration fix: `check-extension-docs.sh` Rule Q requires every file under an extension's
  `scripts/` tree to be declared in that extension's `provides.scripts`, independent of file
  type — the same precedent already followed by `gate-registry.data`,
  `tests/suite-classification.data`, and `tests/suite-cost-hints.txt` — and `gate-cost-model.csv`
  had simply never been added to that list. Resolved with the sanctioned repair tool,
  `sync-manifest-scripts.sh --write`, which added the single missing entry to
  `agent-system/extensions/core/manifest.json`. The two files this continuation was asked to
  reconcile (`measure-gate-costs.sh`, `gate-cost-model.csv`) were found to already be committed
  (prior dispatch's `task 465 phase 4: triage fix` commit) — nothing was dangling. Redeployed and
  confirmed `verify-deploy.sh --only-gate 3` PASS for core, with no new finding introduced beyond
  the two already-confirmed pre-existing ones (gate10 timeout, memory `/ide` dead-command
  findings).

## References

- Plan: `specs/465_check_record_versioning_path_scope_false_clean/plans/01_untracked-enumeration-false-clean.md`
- Phase handoffs: `specs/465_check_record_versioning_path_scope_false_clean/handoffs/`
- Progress files: `specs/465_check_record_versioning_path_scope_false_clean/progress/`
