# Implementation Summary: Task #547

- **Task**: 547 - Close the orchestrate aux blocker-research carrier defect and the implement-readmission gap
- **Status**: [COMPLETED]
- **Started**: 2026-11-16T00:00:00Z
- **Completed**: 2026-11-16T03:00:00Z
- **Effort**: ~6 hours
- **Dependencies**: None
- **Artifacts**: plans/01_aux-carrier-implement-readmission.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closed one mechanism that produced two separately-reported defect classes in the orchestrate aux
chain. Item 1: the `blocker-research` carrier's pending obligation was discarded at emission time
rather than on confirmation, so a fork that returned without writing its carrier silently
evaporated the chain. Item 2: nothing on the deciding side of dispatch admission refused an
implement round for a task still owed a plan revision. All six plan phases landed with
failing-first regression tests in the existing suites, the source store redeployed clean, and the
complete gate set passed.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — confirm-then-clear for the
  `blocker-research` aux_pending obligation (cleared only on a confirmed carrier or at the
  escalation cap, never at emission); audibility at the cap (`blocked[]` row plus a durable
  issue-log entry, additive to the existing stderr line); a post-triage override that withholds
  an `implement` dispatch while a `blocker-research` obligation is outstanding, routing to
  `needs_human` instead; a stderr warning when an explicit forcing flag bypasses that override.
- `agent-system/extensions/core/scripts/orchestrate-build-aux-dispatch.sh` — an unconditional
  insistence clause on the `blocker-research` aux prompt, naming the `.blocker-research.json`
  carrier path, mirroring in spirit the `plan-revision` prompt's own existing clause.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — inverted Group 10
  Case A's pre-existing clear-at-emission assertion; added cases for still-present-when-
  unconfirmed, re-emission-on-second-cycle, cleared-when-confirmed, cap audibility (blocked[] row,
  issue-log entry, dry-run parity), the post-triage override (plus a negative control), and the
  forcing-flag override (admission plus warning). Added `issue-record.sh` to the suite's sandboxed
  script-copy set so the cap-audibility case could exercise the real script.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-aux-dispatch.sh` — an
  assertion that the `blocker-research` dispatch file carries the new unconditional clause.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — narrowed the
  `blocked`, discharged transition-table row with the new implement-withhold precondition;
  extended the Auxiliary Dispatch section with the carrier-confirmation, audibility, and
  forcing-flag-override behaviors.

## Decisions

- Item 1 took confirm-then-clear (shape (a)) with the audibility bar (shape (c)) layered on at
  the escalation cap, rather than synthesizing a minimal carrier from the fork's own return text.
- Item 2 keyed the withhold-implement predicate on `aux_pending` chain state (shape (ii)) rather
  than on handoff free-text (`next_action_hint`, rejected since it has no live writers and no
  routing readers) or on the `.plan-revised.json` sentinel directly (shape (iii), rejected since
  it would re-use a signal designed for a different consumer and risked deadlocking a task for
  which no revision was ever owed).
- The override lives in `orchestrate-cycle-plan.sh`'s own post-triage seam rather than inside
  `orchestrate-triage-classify.sh`, because that classifier never opens the per-invocation
  multi-task state file where `aux_pending` lives; placing it post-triage also applies it
  identically to both the live classifier and the degraded fallback table, so neither routing
  table changed and the two stay in agreement (the existing parity fixture passed unchanged).
- An explicit forcing flag still admits exactly one dispatch past the override (the forced branch
  never consults the classified group), with that admission made audible via a stderr warning
  rather than granted silently.

## Plan Deviations

- Phase 2: `issue-record.sh` was absent from `test-orchestrate-cycle-plan.sh`'s sandboxed
  script-copy set (both the `require_file` list and the `cp` loop), which the new cap-audibility
  case needed to exercise the real script rather than a stub. Added it to both lists.
- Phase 6: the complete gate set ran once, as an unavoidable side effect of the plan's own
  required `deploy-headless.sh` step (which always runs `verify-deploy.sh` internally,
  unflagged), rather than as a second, separately-invoked full `verify-deploy.sh` run. No
  redundant full sweep was performed.

## Verification

- Build: N/A (shell scripts and markdown)
- Tests: Passed — every new/inverted assertion was observed failing against the unmodified
  scripts before its corresponding fix landed; the full named suite pair
  (`test-orchestrate-cycle-plan.sh`, `test-orchestrate-build-aux-dispatch.sh`) and the 25-suite
  `suite_selection_select` set for `orchestrate-cycle-plan.sh` are green; the Group 13
  live/fallback parity fixture passed unchanged.
- Files verified: Yes
- `bash .claude/scripts/deploy-headless.sh` reported `RESULT=landed_verify_clean`; its internal
  complete gate set passed 43/43 checks.

## Impacts

- A `blocker-research` aux round that returns without writing its carrier no longer silently
  drops the chain — it re-emits next cycle, up to the escalation cap, and the give-up at the cap
  is now visible in `blocked[]`, in the issue log, and on stderr.
- A `blocked` candidate owed a plan revision from an outstanding `blocker-research` obligation no
  longer receives a wasted `implement` dispatch; it routes to `needs_human` until the obligation
  is confirmed or capped, unless an explicit forcing flag admits one dispatch (now audibly).
- `docs/architecture/orchestrate-state-machine.md` now documents both behaviors, so a reader of
  that document alone can predict the carrier-absence case and the implement-readmission case.

## Follow-ups

- None.

## References

- `specs/547_orchestrate_aux_carrier_and_implement_readmission/plans/01_aux-carrier-implement-readmission.md`
- `specs/547_orchestrate_aux_carrier_and_implement_readmission/reports/01_aux-carrier-implement-readmission.md`
- `specs/547_orchestrate_aux_carrier_and_implement_readmission/progress/phase-1-progress.json` through `phase-6-progress.json`
