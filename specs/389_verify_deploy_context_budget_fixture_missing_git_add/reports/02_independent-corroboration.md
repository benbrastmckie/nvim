# Research Report: independent corroboration that the fixture bug is live and load-bearing

- **Task**: 389 - Fix test-verify-deploy-context-budget.sh's fixture so the full verify-deploy gate set can pass
- **Started**: 2026-10-14T15:00:00Z
- **Completed**: 2026-10-14T21:35:00Z
- **Effort**: observational seed (captured while sibling tasks ran; this task's own research never completed)
- **Dependencies**: None
- **Sources/Inputs**:
  - Six sibling dispatches' returned verification accounts from the same batch
  - Four Reasoned Exclusions tables authored against this defect
  - Live `ps` sampling of the fixture suite under concurrent execution
  - This task's own `reports/01_recovered-agent-message.md` (a recovered fragment, not a report)
- **Artifacts**: this report
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report-format.md

## Executive Summary

- SEED REPORT, and a **status warning**: this task's research dispatch stranded and produced no
  report. The only other artifact here, `01_recovered-agent-message.md`, is a one-sentence
  recovered fragment -- NOT research. Treat this task as un-researched.
- The defect was independently re-confirmed as live by a sibling dispatch hours after this
  task's own research died, so the premise is current and does not need re-deriving from scratch.
- It is load-bearing, measured: **four tasks in one batch** each had to author a Reasoned
  Exclusions record citing it, including one task that made zero file edits.
- Its practical cost is now entangled with task 404's hang: together they make the complete gate
  set simultaneously non-terminating and non-passing, so no task in the batch could satisfy its
  own declared final-phase criterion.
- Observed under concurrency, the fixture suite runs in duplicate across sessions (two
  concurrent copies, one at 14m30s elapsed), so its cost is multiplied by batch width.

## Context & Scope

This task's description already states the mechanism (the fixture runs `git init` but never
`git add`, so gate 22 discovers files via `git ls-files` against an empty index, finds zero
`*.sh`, exits 2, and fails gate 8 and the full set at 1 of 36). This seed does not re-derive
that. It records only what the surrounding batch independently established about it.

## Findings

1. **This task has no research report.** Its research dispatch ended its turn awaiting a
   notification for a backgrounded fixture test and never returned; its `.return-meta.json`
   stayed `in_progress` and postflight charged it `failed` with `report_missing=true`. Its only
   return text was preserved verbatim as `reports/01_recovered-agent-message.md`:
   "Waiting for the Monitor notification that the fixture test has completed before finalizing
   the research report." The failure mode is filed as task 405. **Status is `researching`; a
   fresh research round is required.**

2. **Independently re-confirmed live.** A sibling implementation dispatch, hours later and
   without reference to this task's work, reported the git-add bug "still open" after checking
   it directly, and explicitly did not re-chase it. That corroboration matters because
   `ROADMAP.md` Standing rule 9 warns that a dispatch premise can go stale between creation and
   dispatch -- here it did not.

3. **Four independent exclusion records in one batch.** Tasks 379, 380, 388 and 381 each reached
   the complete gate set, each hit this failure, and each authored a Reasoned Exclusions entry
   attributing it as pre-existing and outside their own file_scope. Task 380 is the sharpest
   case: it made **zero** file edits (its deliverable already existed) and still could not close
   `[COMPLETED]`.

4. **Duplicated execution under concurrency.** Process sampling during the batch showed two
   concurrent copies of `test-verify-deploy-context-budget.sh`, one at 14m30s elapsed, running
   against separate scratch directories. Each full-gate run pays this suite's cost again.

5. **Compounded with task 404.** 404's suite hangs (never returns); this fixture fails (returns
   2). Together they mean the complete gate set neither terminates nor passes, which is why
   every task in the batch fell back to `--skip-slow` plus narrow `run-all.sh --only` selections.
   The `--skip-slow` path was reported clean, consistent with this task's own description.

6. **The masking risk is no longer hypothetical.** With four tasks concurrently excluding an
   overlapping set of findings, a genuine new regression in the same gate would have been
   indistinguishable from the known noise. One agent traced all 20 findings in its run
   line-by-line to establish none were its own -- correct, but evidence of how expensive the
   masking is.

## Decisions

- None. The fix direction stated in the task description (make the fixture stage its files so
  gate 22 has a populated index) is unchanged and unchallenged by this evidence.

## Recommendations

1. **Re-run research for this task** -- it has none. Do not mistake
   `01_recovered-agent-message.md` for a report.
2. **Skip re-deriving the premise.** Finding 2 corroborates it independently; spend the research
   round on the fix and its fixture instead.
3. **Verify narrowly, not with the full battery.** Finding 5 means a full-gate verification of
   this task's own fix will hang on task 404's suite. Use
   `run-all.sh --only test-verify-deploy-context-budget.sh` plus gate 22 directly, in the
   foreground with a bounded timeout.
4. **Assert the index is populated, not merely that the gate passes.** The defect is an empty
   `git ls-files` result; a fixture that passes because the gate was skipped or because files
   happened to be tracked would be vacuous. Prove the discovery step finds a nonzero `*.sh`
   count.
5. **Declare a `file_scope`.** This task currently declares none, which makes it serialize at
   implement time against any other absent-scope task in its batch. The fixture file is known
   precisely, so there is no reason to leave it undeclared.

## Risks & Mitigations

- **Risk**: fixing the fixture reveals further gate-22 failures that were masked by the early
  `exit 2`. **Mitigation**: expect it; capture a before/after finding count as the baseline
  `ROADMAP.md`'s checks section already asks for.
- **Risk**: verification of this fix is itself blocked by task 404. **Mitigation**: recommendation
  3; or sequence 404 first, which the current roadmap batch does by placing both in the same
  lead batch.

## Appendix

- Sibling accounts, exclusion-table counts and process samples are quoted inline; the recovered
  fragment is at `reports/01_recovered-agent-message.md`.
- Related: task 404 (the hang), task 403 (why four tasks each ran the full battery), task 405
  (the failure mode that destroyed this task's own research round).
