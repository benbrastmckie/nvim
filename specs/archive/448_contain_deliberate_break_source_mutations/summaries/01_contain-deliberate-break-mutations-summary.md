# Implementation Summary: Task #448

- **Task**: 448 - Contain the regression-anchor source-store mutation so a concurrent session cannot observe or inherit it
- **Status**: [COMPLETED]
- **Started**: 2026-11-09T22:49:00Z
- **Completed**: 2026-11-10T07:41:49Z
- **Effort**: ~7 hours
- **Dependencies**: 328 (satisfied, archived)
- **Artifacts**: plans/01_contain-deliberate-break-mutations.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closed a concurrency hazard in `test-orchestrate-cycle-postflight.sh`'s regression-anchor check,
which previously mutated the real source-store file in place (via a deliberately-false
`while false &&` re-gate) while relying on a backup/restore pair and an `EXIT` trap, leaving the
mutated file observable by any concurrently running session for the whole fixture's duration.
The fix reorders the mutation onto the already-copied sandbox file (`$SUT`), eliminating the
source-store write outright, and pairs it with a new mechanical detector (gate 28), its own
suite, in-suite byte-identity invariants, and a stated rule in the testing standard.

## What Changed

- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — relocated
  the regression-anchor's deliberate-false mutation from `$CORE_DIR` (the real source store) to
  `$SUT` (the sandbox copy `setup_sandbox()` produces), removed the backup/trap/restore
  machinery, added a non-vacuousness assertion confirming the `sed` actually applied, and added
  two unconditional end-of-run invariant cases (source-store byte-identity, `*.anchor-bak`
  absence).
- `agent-system/extensions/core/scripts/lint/lint-deliberate-break-residue.sh` — new detector:
  reports an anchored-start `while false &&` guard or a leftover `*.anchor-bak` file anywhere
  under `agent-system/extensions/`. Advisory/gate-level by construction; the anchored-start regex
  (not a path exclusion) is what separates a real guard from the existing `sed` replacement
  string containing the same phrase.
- `agent-system/extensions/core/scripts/tests/test-lint-deliberate-break-residue.sh` — new suite:
  four cases (planted guard, planted `*.anchor-bak`, negative control against the real source
  store, clean-tree quoted-phrase control), with the planted fixture line assembled from two
  separate shell variables so the suite's own source never trips the detector it tests.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — `gate28_run()`, added immediately
  after `gate27_run()`, following the same template (source-store-scoped SKIP branch,
  `--verbose` invocation, `FINDINGS_LIST` population).
- `agent-system/extensions/core/scripts/gate-registry.data` — gate 28 row (9 TAB-separated
  fields, contiguous with gate 27).
- `agent-system/extensions/core/scripts/tests/suite-classification.data` — classification row
  for the new suite (`unit`).
- `agent-system/extensions/core/manifest.json` — two new `provides.scripts` entries
  (`lint/lint-deliberate-break-residue.sh`, `tests/test-lint-deliberate-break-residue.sh`).
- `agent-system/extensions/core/context/standards/shell-script-testing.md` — new subsection
  under `## Fixture convention` stating the sandbox-copy rule, naming the two existing safe-copy
  precedents in this corpus, pointing at the new detector as the mechanical guard, and
  cross-referencing the sibling exact-pid parallelism-safety rule.
- Deployed `.claude/` tree regenerated via `deploy-headless.sh` to carry all of the above.

## Decisions

- Adopted the research's reorder recommendation as the primary containment: no new
  test-harness override-source infrastructure was built, since `test-harness-lib.sh` (the
  dispatch's candidate home for it) does not exist and the reorder closes the concurrency window
  outright with a smaller diff.
- Chose an anchored-start regex (`^[[:space:]]*while false[[:space:]]*&&`) over a path exclusion
  to solve the detector's self-exclusion problem, since a path exclusion would blind the detector
  to a real mutation planted directly in a test file — exactly where the anti-pattern's source
  lives.
- Did not pursue the dispatch's option (2) (holding a repository-level lock for the mutation
  window): it only shrinks the observation window rather than removing it, and the reorder
  removes it outright at no added runtime cost.
- Recorded `test-validate-no-task-references.sh` as audited-with-no-action: its own "regression
  anchor" operates on in-memory fixture strings, never a file mutation.
- Applied the dispatch's Batch Gate Deferral directive to the final phase: the complete
  independent `verify-deploy.sh`/`tests/run-all.sh` pool run was deferred to the once-per-batch
  stage; this phase discharged against a scoped tier (direct gate 28 run, a four-suite `run-all.sh
  --only` invocation covering the anchor case and the new suite, plus direct checksum/residue
  checks) instead.

## Plan Deviations

- **Task 7.4** altered: ran a scoped-tier verification instead of the full gate set and full test
  pool, per the dispatch file's Batch Gate Deferral directive (the full pool runs once for the
  whole batch at the end of the invocation, not independently in this dispatch).

## Verification

- Build: N/A (shell scripts; shellcheck clean on every new/edited file)
- Tests: scoped tier green — the regression-anchor case, the non-vacuousness assertion, the
  source-store byte-identity invariant, the `*.anchor-bak`-absence invariant, and the new
  detector's own four-case suite all PASS. `test-orchestrate-cycle-postflight.sh`'s suite-level
  result carries 25 pre-existing, HEAD-confirmed-unmodified failures unrelated to this task
  (status-demotion logic, unrelated to the regression-anchor block).
- Files verified: Yes — gate 28 registered, structurally valid (`lint-gate-registry.sh` 7/7),
  selectable via `--only-gate 28`, runs against the source store post-deploy and passes.
- `deploy-headless.sh` completed; `verify-deploy.sh` landed with 3 pre-existing, unrelated
  failures (eager-load budget drift; a shellcheck finding in files this task never touched; a
  dead-command-recommendation finding in two memory-extension docs), each confirmed untouched by
  this dispatch via `git status --porcelain`/`git log`.

## Impacts

- A future author of a deliberate-break regression-anchor fixture now has a stated rule (in
  `shell-script-testing.md`) and a mechanical guardrail (gate 28) rather than having to re-derive
  the hazard from first principles or copy the nearest (previously unsafe) example.
- The concurrency hazard the cited incident exercised — a concurrent reader observing a mutated
  collaborator script mid-fixture — is closed outright for this one site; the corpus-wide audit
  in Phase 6 found no other source-store-mutating suite.

## Follow-ups

- None.

## References

- Plan: `specs/448_contain_deliberate_break_source_mutations/plans/01_contain-deliberate-break-mutations.md`
- Report: `specs/448_contain_deliberate_break_source_mutations/reports/01_contain-deliberate-break-mutations.md`
- Phase handoffs: `specs/448_contain_deliberate_break_source_mutations/handoffs/phase-{1..7}-handoff-*.md`
