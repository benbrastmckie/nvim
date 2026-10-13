# Implementation Summary: Task #373

- **Task**: 373 - Issue-log entries with a null resolution are permanently invisible to the conclusion stage that exists to act on them
- **Status**: [COMPLETED]
- **Started**: 2026-10-11T00:00:00Z
- **Completed**: 2026-10-12T02:35:00Z
- **Effort**: 3 hours
- **Dependencies**: None
- **Artifacts**: plans/01_null-resolution-remedy.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

A `kind: "issue"` entry written without `--resolution` landed in `issues.jsonl` as an explicit
JSON `null`, which the conclusion stage's aggregator filter coerced to `""` and silently dropped
— making the entry permanently unreachable by the only consumer built to act on it. This task
widened the filter to read a null/omitted `resolution` on a non-win entry as `"open"`, added an
informational `implicit_open_count` tally so the provenance of a null-sourced candidate stays
visible, updated both `issue-log.md` and `conclusion-stage.md` to state explicitly what null
means, closed the test-coverage gap with a dedicated regression case, and proved the fix against
the real BimodalLogic 739/740 fixture entries that originally surfaced the defect.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-conclusion-aggregate.sh` — widened the
  `$candidates` coalesce default from `(.resolution // "")` to `(.resolution // "open")`; added
  an `implicit_open_count` binding and output key between `unknown_classes` and
  `no_contribution_tasks`; updated the `--help` usage block to document both.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-aggregate.sh` — added
  Case (l): a null-resolution `kind: "issue"` entry now reaches `proposals[]`, the
  `implicit_open_count` tally is asserted, and the `kind: "win"` exemption is asserted intact
  with a null resolution (non-regression).
- `agent-system/extensions/core/context/formats/issue-log.md` — the `resolution` row's Notes
  column now states that a null/omitted value is treated identically to `"open"`, so no
  schema-legal `kind: "issue"` entry can be permanently unreachable.
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` — "The Filter Predicate"
  section now covers all four possible field states (`open`, `worked_around`, `fixed_inline`,
  null/omitted); Step 1 and Step 2 extended to parse and carry `implicit_open_count`; a new
  sibling section "The Implicit-Open Tally" documents the field as informational-only.
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` — one new
  rendered line for the implicit-open count in the `### Conclusion` block.
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` — the
  `issue-record.sh` entry now notes that an omitted `--resolution` writes a null the conclusion
  stage reads as `open`.
- `specs/373_null_resolution_entries_unreachable_by_conclusion_stage/plans/01_null-resolution-remedy.md` —
  all four phases checked off and closed (Phase 4 as `[COMPLETED WITH EXCLUSIONS]` with a full
  Reasoned Exclusions record).

## Decisions

- **Widen the reader, not the writer** (research-selected remedy, re-confirmed at implementation
  time): `--resolution` stays optional for every `--kind` in `issue-record.sh`. The six
  already-written BimodalLogic fixture entries are append-only and this task is barred from
  retroactive edits, so a writer-side tightening alone would leave the mandated regression
  fixture still returning zero proposals. Coalescing null to `"open"` is the one remedy that
  makes them reachable without any retroactive edit.
- **Compose with a tally, not a silent merge**: `implicit_open_count` preserves the provenance
  signal (how many candidates arrived via the null path) that a bare filter widening would
  otherwise discard, documented as informational-only — parallel to `unknown_classes[]`'s
  existing framing that this stage never acts on a tally unilaterally.
- **Phase 4's pre-fix baseline was reconstructed from git history, not the live deployed tree**:
  this dispatch resumed Phase 4 after an earlier, interrupted attempt had already run
  `deploy-headless.sh` (confirmed by uncommitted `TODO.md`/`state.json` drift and a stray issue
  entry found on disk at dispatch start). Since the currently-deployed aggregator script already
  carried the fix, the pre-fix script was pulled from `79b0786a6~1` (the commit immediately
  before Phase 1's own fix) instead — functionally identical to copying the pre-deploy deployed
  copy, which is no longer available to copy.

## Plan Deviations

- **Phase 4, verification bullet "`verify-deploy.sh` exits 0"** altered: 34 of 36 checks passed.
  Two failures are pre-existing and unrelated to this task's four-file scope — a
  `check-evidence-probes.sh` reference-drift defect in `check-extension-docs.sh` already filed
  by sibling task 372 against files this task never touched, and a load-sensitive wall-clock
  timing assertion in `test-four-tier-conflict.sh` (unrelated script, testing task-lock
  acquire-retry timing, reproducibly over its 1000ms budget under concurrent sibling-task load).
  A third suite named by `run-all.sh`'s parallel battery, `test-orchestrate-recover-outcome.sh`,
  was confirmed to be a parallel-battery flake (passed 7/7 standalone) and required no exclusion.
  Phase 4 closed `[COMPLETED WITH EXCLUSIONS]` with a full Reasoned Exclusions record satisfying
  the five-condition admission test. See the plan's Phase 4 section for the complete table and
  evidence.

## Verification

- Build: N/A (shell/markdown task)
- Tests: Passed — `test-orchestrate-conclusion-aggregate.sh` (12/12 including new Case (l)) and
  `test-orchestrate-build-dispatch.sh` both green; `lint-shellcheck.sh --verbose` clean.
- Files verified: Yes — all six source-store files plus the plan are confirmed deployed
  byte-identical to `.claude/**`.
- Regression fixture: the real BimodalLogic 739/740 `issues.jsonl` entries now yield exactly 3
  proposals / 6 citations (`tooling`=3, `proof-repair`=1, `gate-collision`=2),
  `implicit_open_count`=6, `wins`=9 — matching the plan's pre-derived figures exactly. Pre-fix
  re-run of the identical fixture confirmed `proposals`=0, reproducing the original defect.
  `~/Projects/BimodalLogic` is byte-unchanged (`specs/archive/` untouched).

## Impacts

- A recorded `kind: "issue"` entry with an omitted `--resolution` is no longer silently
  unreachable by the orchestration conclusion stage; it now surfaces as an `open`-equivalent
  candidate, with its provenance visible via `implicit_open_count`.
- No change to `issue-record.sh`, the three-channel derivation contract, the per-channel
  approval gates, the approval ledger, or the `kind: "win"` exemption.
- No retroactive edit to any already-written `issues.jsonl` entry in any repo.

## Follow-ups

- None owed by this task. The `check-evidence-probes.sh` gate-3 defect remains tracked under
  sibling task 372's existing issue-log entry (`iss_1791742848757_BcRCvu`), not duplicated here.
  The `test-four-tier-conflict.sh` timing-budget flake is recorded in this task's own issue log
  (`iss_1791772186495_xUT0PY`) as informational; it names no owning task and is left for a
  future `/distill` or `/errors` sweep to triage if it recurs.

## References

- `specs/373_null_resolution_entries_unreachable_by_conclusion_stage/reports/01_null-resolution-filter-remedy.md`
- `specs/373_null_resolution_entries_unreachable_by_conclusion_stage/plans/01_null-resolution-remedy.md`
- `specs/372_conclusion_stage_report_block_and_caller_split/issues.jsonl` (gate-3 cross-reference)
