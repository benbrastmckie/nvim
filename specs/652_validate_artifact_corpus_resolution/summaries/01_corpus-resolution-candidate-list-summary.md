# Implementation Summary: Task #652

- **Task**: 652 - Resolve validate-artifact.sh's Tier-Justification corpus against the repository under validation, not the deployed agent-system tree
- **Status**: [COMPLETED]
- **Started**: 2026-11-19T18:00:00Z
- **Completed**: 2026-11-19T19:20:00Z
- **Effort**: ~5.5 hours
- **Dependencies**: Tasks 650 and 564 (both completed prior to this task)
- **Artifacts**: plans/01_corpus-resolution-candidate-list.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`validate-artifact.sh`'s advisory per-phase Tier-Justification scan previously sourced its
suite-selection backend from exactly one script-relative path, so every verdict was measured
against the agent system's own deployed suite corpus — even when the plan under validation runs
against a consumer repository's own copied suite tree. This implementation extends the script's
existing ordered candidate-list idiom with the repository-under-validation's declared project
suite root(s) ahead of today's single entry, names the resolved corpus in every advisory warning,
adds declared/undeclared/declared-but-absent test coverage, documents the new consumer in the
`verification_scope` schema doc, and redeploys. A declaring repository is now measured against
its own corpus; a non-declaring repository (this one) is byte-for-byte unaffected.

## What Changed

- `agent-system/extensions/core/scripts/validate-artifact.sh` — resolves the Tier-Justification
  scan's suite-selection backend through an ordered candidate list (declared
  `verification_scope.project_suite_roots` entries first, then today's single deployed/sibling
  path as fallback); every advisory `log_warn` now names the corpus kind and the library path it
  was measured against; added a one-time, run-level warning for a declared-but-unresolvable root.
- `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` — added
  `make_tj_scope_fixture` (a scratch-root fixture builder) and three new cases: TJ-scope(A)
  declared-resolvable (plants a mirror-shaped corpus, confirms the warning names the declared
  root, and confirms removing the planted library flips the measured corpus to the fallback),
  TJ-scope(B) undeclared (explicit regression-guard re-assertion), and TJ-scope(C)
  declared-but-absent (confirms the per-phase outcome matches the undeclared case plus exactly
  one run-level warning). Also fixed a shellcheck SC1090 finding in the new helper.
- `agent-system/extensions/core/context/standards/repo-level-declarations.md` — records
  `scripts/validate-artifact.sh` as a `project_suite_roots` consumer (both occurrences) and
  documents the `lib/`+`tests/` mirror-shape expectation this one consumer depends on.
- `agent-system/extensions/core/index-entries.json` — `line_count` reconciled for
  `standards/repo-level-declarations.md` (298 → 311), applied as a scoped, single-field
  follow-up commit on top of `HEAD` rather than the whole-file regeneration `deploy-headless.sh`
  produced locally, to avoid pulling other concurrently-live dispatches' in-flight line-count
  drift into this task's own commit.
- Deployed tree regenerated via `deploy-headless.sh` (gitignored deploy artifact, not itself a
  committed deliverable).

## Decisions

- Relocated the suite-selection-lib candidate-array block to sit after the existing, unmoved
  `_cgs_repo_root` assignment, rather than literally hoisting the assignment above the block as
  the plan's Phase 1 task list worded it — the two repo-root functions are defined textually
  after that block, so the literal wording is bash-impossible under `set -euo pipefail`. Net
  ordering and the single-assignment invariant both hold.
- Declined to make the new run-level warning fire when `verification-scope-lib.sh` itself is
  unavailable ("includes the reader-unavailable case", per the plan's risk-mitigation table) —
  doing so would require a second, ad hoc read of the `verification_scope` key, which this task's
  own Hard Constraints forbid. The reader-unavailable case stays silently inert instead.
- Computed the corpus-attribution text once per run in a single `_suite_selection_corpus_descriptor`
  variable, reused verbatim by all four Tier-Justification `log_warn` call sites.
- Reconciled `index-entries.json` via a targeted single-field edit on top of `HEAD` instead of
  committing `deploy-headless.sh`'s full local regeneration, which also reflected unrelated,
  concurrently-live sibling dispatches' own uncommitted line-count drift.

## Plan Deviations

- **Phase 1, task 2** altered: a literal hoist of the `_cgs_repo_root` assignment above the
  candidate-list block, with the `_cgs_find_repo_root`/`_cgs_resolve_repo_root` function
  definitions left in place, is bash-impossible (the functions are defined textually after that
  block). Relocated the candidate-array block after the unmoved assignment instead — same net
  ordering, same single-assignment invariant, neither function body touched.
- **Phase 2, task 5** altered: implemented the run-level warning's firing condition narrower than
  the risk-mitigation table's own more ambitious framing ("includes the reader-unavailable
  case"), to avoid a second declaration-presence read this task's Hard Constraints forbid.
- **Phase 5, task 1** altered: the first `deploy-headless.sh` run failed `verify-deploy`'s
  shellcheck lint gate on an SC1090 finding introduced in Phase 3; fixed forward within Phase 5
  and re-ran to a clean landing.

## Verification

- Build: N/A (shell scripts, no build step)
- Tests: Passed — `test-validate-artifact.sh` 157/157 (148 pre-existing + 9 new); `run-all.sh
  --only test-validate-artifact.sh` passes against the deployed tree; `lint-shellcheck.sh`
  reports 0 findings across 507 files; `deploy-headless.sh` landed clean
  (`RESULT=landed_verify_clean`, 41/41 checks)
- Files verified: Yes — deployed `.claude/scripts/validate-artifact.sh` confirmed byte-identical
  to the edited source-store copy; `index-entries.json` line_count for the edited standards file
  confirmed reconciled with no residual drift

## Impacts

- A consumer repository (such as the sf1-engine repository this task's research originated from)
  that declares `verification_scope.project_suite_roots` in `.claude-extensions.json` now gets
  every Tier-Justification advisory verdict measured against its own declared corpus, with every
  warning naming which corpus was used — closing the durable, per-plan authoring tax the research
  report identified (a dedicated decision explaining four false-positive warnings purely so a
  later implementer would not "fix" a correct suite name).
- This repository (which declares no `verification_scope` key) is byte-for-byte unaffected.

## Follow-ups

- None. The complete gate set is deferred to the once-per-invocation orchestration close per
  this dispatch's Batch Gate Deferral directive, not a follow-up owed by this task.
- Two foreign, non-blocking observations were recorded during this task's own scoped
  verification runs (unrelated `test-lint-state-writer-boundary.sh` and
  `test-stall-reprompt-wiring.sh` failures, attributable to other concurrently-live dispatches'
  in-flight uncommitted work in this shared working tree) — see
  `specs/652_validate_artifact_corpus_resolution/issues.jsonl`. Not this task's to fix.

## References

- Plan: `specs/652_validate_artifact_corpus_resolution/plans/01_corpus-resolution-candidate-list.md`
- Research report: `specs/652_validate_artifact_corpus_resolution/reports/01_validate-artifact-corpus-resolution.md`
