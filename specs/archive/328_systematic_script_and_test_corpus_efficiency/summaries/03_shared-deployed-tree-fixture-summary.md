# Implementation Summary: Task #328 (Phase 13)

- **Task**: 328 - Systematic top-to-bottom consolidation of the shell script and test corpus under `agent-system/extensions/**`
- **Status**: [COMPLETED]
- **Started**: 2026-11-05T19:25:00Z
- **Completed**: 2026-11-05T20:05:00Z
- **Effort**: ~40 minutes
- **Dependencies**: None live (task 416, read as a coordination check, is archived/completed)
- **Artifacts**: plans/03_markdown-corpus-consolidation.md (Phase 13 section)
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closed Phase 13 of the plan (`[COMPLETED WITH EXCLUSIONS]`): built a shared deployed-tree test
fixture, constructed once by `run-all.sh` and lent read-only to declared consumer suites, instead
of each consumer rebuilding its own copy. Investigated the realistic consumer set directly
(rather than trusting `suite-classification.data`'s conservative textual-reference
classification) and found it to be exactly one core suite, not corpus-wide; migrated that suite,
built and regression-tested the enforcement mechanism, and recorded the rest as reasoned
exclusions with evidence.

## What Changed

- `agent-system/extensions/core/scripts/lib/common.sh` — added `common_test_fixture_overlay`, a
  copy-on-write (`cp -a --reflink=auto`) directory/file copy helper for a suite that must mutate a
  shared, read-only fixture without paying its construction cost again.
- `agent-system/extensions/core/scripts/tests/run-all.sh` — added a build/lend/enforce block:
  before any suite runs, if a declared consumer (`SHARED_FIXTURE_CONSUMERS`) is present in the
  discovered/narrowed suite set, builds one deployed tree via `deploy-headless.sh --skip-verify`,
  `chmod -R a-w`s it, exports `RUN_ALL_SHARED_FIXTURE`, and cleans it up (reversing the chmod
  first) on exit. Zero cost when no declared consumer is selected.
- `agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh` — migrated onto the shared
  fixture: overlays `.claude/`, `.claude-extensions.json`, and `.syncprotect` from
  `$RUN_ALL_SHARED_FIXTURE` when present, falling back to its own direct `deploy-headless.sh`
  call when run standalone.
- `agent-system/extensions/core/scripts/tests/test-run-all-shared-fixture.sh` — new regression
  suite (8 assertions) pinning: built exactly once when a consumer is selected; never built when
  no consumer is selected; a write attempt into the lent fixture is blocked.
- `agent-system/extensions/core/scripts/tests/test-common-lib.sh` — added 6 assertions covering
  `common_test_fixture_overlay`'s own contract (directory and single-file copy, independent
  writability, no hardlink-sharing hazard, both error paths) plus its single-definition check.
- `agent-system/extensions/core/scripts/tests/suite-classification.data` — classification row for
  the new suite (`integration`, invokes `run-all.sh`/`deploy-headless.sh`).
- `agent-system/extensions/core/context/standards/shell-script-testing.md` — new section
  documenting the shared-fixture contract, the consumer discriminator (why most `integration`
  rows are not candidates), the two-sibling-artifact overlay requirement, and the regression
  coverage.

## Decisions

- **The consumer discriminator is "needs a plain deployed tree as inert scaffolding," not
  "mentions `deploy-headless.sh`."** A suite whose own job is to verify
  `deploy-headless.sh`/`verify-deploy.sh`'s behavior across distinct invocations (fresh-vs-resync,
  a flag matrix, gate-cache equivalence) is excluded by construction: the variance across
  invocations is what it verifies, and a shared tree cannot substitute without changing that.
- **Overlay both project-root sibling artifacts, not just `.claude/`.** `find_orphans` resolves
  the active-extension set from `.claude-extensions.json` and the exclusion set from
  `.syncprotect`, both project-root siblings of `.claude/`. Omitting either made the entire
  deployed tree appear orphaned (743 false findings) — caught during migration, fixed before
  closing the phase.
- **`--skip-verify` for the shared build.** A plain deploy's own inline fast-gate verify fails
  gate 14 against a bare scratch repo with no pre-seeded `.gitignore` — irrelevant to what any
  consumer suite itself checks. Exit 0 or 4 (its own documented `landed_verify_skipped` success
  code) both accepted, matching `test-gate-cache-equivalence.sh`'s existing precedent.
- **`cp -a --reflink=auto`, never `cp -al`.** A hardlink shares the source's inode; `chmod` on the
  copy would also un-protect the shared read-only source.

## Plan Deviations

- **Migrate the integration-class suites identified in Phase 12 onto the shared fixture**:
  altered. Investigated all 38 core `integration`-classified suites directly; only
  `test-deploy-orphans.sh` fits the pattern. `test-deploy-propagation.sh`,
  `test-gate-cache-equivalence.sh`, and `test-deploy-verify-wiring.sh` are excluded with evidence
  (each drives real, distinct invocations whose variance is the thing under test); the remaining
  rows are the classification file's own documented textual-reference over-count or (the two
  dispatch-named stragglers) already migrated by task 416 onto an unrelated rsync-based fixture.
  Recorded as `#### Reasoned Exclusions` in the plan; phase closed `[COMPLETED WITH EXCLUSIONS]`.
- **Record the phase's NET-TEST delta and negative**: altered. Recorded (NET-PROD +109, NET-TEST
  +267, NET-MD +51) but net-POSITIVE, not negative. Justified in the plan's own closing note: the
  realistic consumer set does not exist at the scale the net-deletion target assumed, and the
  infrastructure is reusable future-growth-prevention machinery (the same justification class
  Phase 14 carries in advance).

## Verification

- Build: N/A (shell scripts; `bash -n` syntax-checked and `shellcheck -S warning` clean on every
  touched/new file)
- Tests: `test-common-lib.sh` (54 assertions), `test-deploy-orphans.sh` (8/8 standalone, 8/8 under
  `run-all.sh` with the shared fixture — identical case-name list both ways), and
  `test-run-all-shared-fixture.sh` (8/8) all green, at both `--jobs 1` and default `--jobs auto`.
  `lint-unit-integration-boundary.sh` and `lint-test-harness-adoption.sh` both clean.
- Full redeploy + full `verify-deploy.sh` battery run twice (before committing and again to
  confirm): 39 checks, 0 failures both times, including gate 8's complete shell-suite battery.
- Files verified: Yes

## Impacts

- Any future suite needing "a deployed tree" as scaffolding can opt into
  `SHARED_FIXTURE_CONSUMERS`/`common_test_fixture_overlay` at zero additional infrastructure
  cost, rather than re-deriving a construction-sharing mechanism from scratch.
- No change to any gate's finding set or any existing suite's assertion set (migrated suite's
  case-name list proven identical).

## Follow-ups

- None within this phase's own charter (the exclusions are final, not deferred). A future suite
  that genuinely needs only a plain deployed tree (not one of the three excluded invocation-
  variance shapes) can be added to `SHARED_FIXTURE_CONSUMERS` directly.
- A mid-phase `run-all.sh --jobs auto` battery run surfaced 6 transient failures traced to a
  concurrent sibling process live-mutating `specs/state.json`/`TODO.md` during the run (host-state
  contention, logged via `issue-record.sh`, unrelated to this phase's own edits — not reproduced
  on the two full `deploy-headless.sh` verification runs taken afterward).

## References

- Plan: `specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md` (Phase 13 section, including `#### Reasoned Exclusions`)
- Progress: `specs/328_systematic_script_and_test_corpus_efficiency/progress/phase-13-progress.json`
- Handoff: `specs/328_systematic_script_and_test_corpus_efficiency/handoffs/phase-13-handoff-20261105T195859Z.md`
- Standard: `agent-system/extensions/core/context/standards/shell-script-testing.md` ("The shared deployed-tree fixture: built once, lent read-only")
