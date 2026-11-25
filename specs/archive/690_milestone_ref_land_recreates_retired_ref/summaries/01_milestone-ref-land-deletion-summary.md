# Implementation Summary: Task #690

- **Task**: 690 - Delete the orphaned milestone-ref-land.sh utility and its references
- **Status**: [COMPLETED]
- **Started**: 2026-11-23
- **Completed**: 2026-11-23
- **Effort**: ~2 hours
- **Dependencies**: None
- **Artifacts**: plans/01_milestone-ref-land-deletion.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`milestone-ref-land.sh` had no lifecycle caller in this source store and its retirement as a
landing mechanism was already complete at the wiring level; the two records previously assigned
the delete-or-reuse decision had both finished, leaving the file unowned. This implementation
deleted the script, its dedicated test suite, and every machine-read declaration of either (two
manifest rows and one `suite-classification.data` row), then re-pointed the two context documents
that still cited the script as the ref-plumbing idiom's worked implementation to
`review-stack-prepare.sh`, which already exercises the identical `git commit-tree` plus
compare-and-swap `git update-ref` primitives at its review-ref build and restack sites.

## What Changed

- `agent-system/extensions/core/scripts/milestone-ref-land.sh` — deleted
- `agent-system/extensions/core/scripts/tests/test-milestone-ref-land.sh` — deleted
- `agent-system/extensions/core/manifest.json` — removed the two rows naming the deleted files
- `agent-system/extensions/core/scripts/tests/suite-classification.data` — removed the row for
  the deleted suite, preserving the tab-separated shape of every surviving row
- `agent-system/extensions/core/context/patterns/ref-plumbing-landing.md` — re-pointed the
  Audience line and the Landing Mechanism sentence to `review-stack-prepare.sh`; the Idiom,
  Concurrency-Safety Property, Compare-And-Swap Obligation, and Prohibition sections are
  byte-unchanged
- `agent-system/extensions/core/context/standards/git-workflow-narrative.md` — restated the
  landing-section sentence to describe the current design plainly, naming the same script
- `agent-system/extensions/core/scripts/tests/test-milestone-review-handoff.sh` — reworded the
  header comment to describe the sandbox convention on its own terms, crediting no file
  (comment-only change)
- `agent-system/extensions/core/index-entries.json` — reconciled `ref-plumbing-landing.md`'s
  `line_count` (98 -> 99)
- Deployed `.claude/` tree — regenerated via `deploy-headless.sh`; the deploy's own orphan
  handling initially left the deployed copies of the two deleted files in place, which were then
  removed explicitly per the plan's own anticipated fallback

## Decisions

- The ref-plumbing document retains the TECHNIQUE and changes only its implementation citation:
  the Idiom, Concurrency-Safety Property, Compare-And-Swap Obligation, and Prohibition sections
  are script-agnostic and name no implementation outside the Audience line and one Landing
  Mechanism sentence, both of which now cite `review-stack-prepare.sh`.
- The two context documents were treated as part of the fix, not cosmetic cleanup trailing it,
  per the task description's hypothesis that they were the invocation vector for the unexplained
  ref advances observed in a consumer repository.
- `suite-classification.data`'s row was removed in the same phase as the deletion, even though a
  stale row there is `[INFO]`-only and would not fail `lint-unit-integration-boundary.sh`'s exit
  verdict, to avoid drift between the data and the discovered corpus.
- No dependency edge was added for `test-milestone-review-handoff.sh`: the records owning
  handoff printing of the review stack are all complete and none touched the edited comment
  line, so there was no live race to order behind.

## Plan Deviations

- None of substance. One verification path differed from the plan's literal text without
  changing its intent: Phase 3's first `deploy-headless.sh` run reported `landed_verify_red` on
  the anticipated orphan finding; a scoped `verify-deploy.sh --only-gate 13,3,5 --skip-unchanged`
  re-check confirmed clean immediately after removing the orphan files, and a second
  `deploy-headless.sh` run then confirmed the literal "clean verify" criterion
  (`RESULT=landed_verify_clean`, `PASS -- 41 check(s), 0 failure(s)`).

## Verification

- Build: N/A (shell script repository; no build step)
- Tests: `test-milestone-review-handoff.sh` green; `bash .claude/scripts/verify-touched.sh`'s
  primary 121-suite named battery passed clean except two confirmed pre-existing/unrelated
  failures (`test-gate-cache-equivalence.sh`, a 600s timeout; `test-orchestrate-conclusion-roadmap.sh`
  Case H, a missing-fixture-file issue, both reproduced independent of this task's edits).
  `verify-touched.sh`'s own secondary OWED-fallback sweep stalled on a stale, confirmed-dead
  gate-lock from an unrelated session and hit its bounded timeout; recorded as environmental via
  `issue-record.sh`, not a finding against this task. The complete, once-per-invocation full
  gate set is deferred to the orchestration batch close per this dispatch's Batch Gate Deferral
  directive.
- Files verified: Yes — `grep -rn "milestone-ref-land"` returns nothing in either
  `agent-system/` or `.claude/`; `jq -e .` on `manifest.json` parses; `generate-context-line-counts.sh
  --check` passes clean; the redeploy reports a clean verify.

## Impacts

- Removes a dead utility and its entire reference surface, closing the open delete-or-reuse
  decision this task inherited from two now-finished records.
- The ref-plumbing idiom documentation keeps a live, runnable implementation citation
  (`review-stack-prepare.sh`) instead of pointing at a script with no caller, removing what the
  task description identified as the most plausible invocation vector for the unexplained ref
  advances observed in a consumer repository.

## Follow-ups

- Identifying and unwiring the consumer repository's own live ref writer is out of scope for
  this task (per the source-store-deploy-boundary siting rule) and belongs to that repository's
  own work.
- None within this repository.

## References

- `specs/690_milestone_ref_land_recreates_retired_ref/plans/01_milestone-ref-land-deletion.md`
- `specs/690_milestone_ref_land_recreates_retired_ref/reports/01_milestone-ref-land-deletion-scope.md`
- `specs/690_milestone_ref_land_recreates_retired_ref/progress/phase-1-progress.json`,
  `phase-2-progress.json`, `phase-3-progress.json`
- `specs/690_milestone_ref_land_recreates_retired_ref/handoffs/phase-1-handoff-20261123T010000Z.md`,
  `phase-2-handoff-20261123T015000Z.md`, `phase-3-handoff-20261123T030000Z.md`
