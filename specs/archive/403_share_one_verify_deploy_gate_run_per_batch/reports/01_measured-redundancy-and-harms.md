# Research Report: measured cost of per-task full-gate runs across one batch

- **Task**: 403 - Share one verify-deploy gate run across an /orchestrate batch instead of one full run per task
- **Started**: 2026-10-14T15:00:00Z
- **Completed**: 2026-10-14T21:25:00Z
- **Effort**: observational seed (measured during a live 7-task batch)
- **Dependencies**: None
- **Sources/Inputs**:
  - `uptime` load sampling across a ~5-hour batch window on a 24-core machine
  - `ps -eo etime,pid,ppid,args` process-table sampling
  - Six implementation/research agents' own returned verification accounts
  - Four tasks' Reasoned Exclusions tables authored in the same batch
- **Artifacts**: this report
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report-format.md

## Executive Summary

- SEED REPORT: evidence captured while running the batch, not a design round. The mechanism
  question (how a shared run attributes failures back to a task) is untouched here.
- The redundancy is now measured, not inferred: **one agent independently rediscovered two
  pre-existing findings byte-identical to ones a concurrent sibling had already excluded**.
  N tasks rediscover, re-verify and re-document the same findings N times.
- Load reached **51.77 on 24 cores** (~2.2x oversubscribed) with **18 concurrent**
  `run-all.sh`/`verify-deploy.sh` processes and literally duplicated suites in flight.
- **Four of six** tasks that reached a final phase closed it `[COMPLETED WITH EXCLUSIONS]`
  rather than `[COMPLETED]`, every one of them for reasons outside its own file_scope.
- Two second-order harms occurred, both observed rather than predicted: a machine-wide `pkill`
  that killed sibling sessions' runs, and exclusion tables that cannot distinguish a real
  regression from sibling noise.
- A cheaper mitigation exists and was validated incidentally: `--skip-slow` plus narrow
  `run-all.sh --only` selections completed fast and clean for every task that used them.

## Context & Scope

Seven tasks were dispatched in one `/orchestrate` invocation. Every plan's final phase
independently declared the criterion "verify-deploy.sh exits 0 -- the complete gate set", so
each implement dispatch launched the complete ~104-suite battery on the same machine, against
the same working tree, at overlapping times.

## Findings

1. **Duplicated discovery, measured directly.** The clearest single piece of evidence: one
   implementation dispatch reported finding "two MORE pre-existing findings that are
   byte-identical to ones concurrent sibling task 388 already excluded" -- a lean doc-lint
   fixture registration gap and a gate 20 eager-load +225B overage. Two agents spent wall clock
   discovering, verifying and authoring exclusion prose for the same two findings. A third and
   fourth task excluded overlapping sets.

2. **Load curve across the window** (24 cores throughout):

   | Sample | 1-min load | Note |
   |---|---|---|
   | early batch | 39.91 | 4 implement dispatches, 18 gate processes |
   | mid | 50.1 -> 52.5 | reported by an agent inspecting its own contention |
   | later | 51.77 | partly external Lean/LaTeX builds from sibling sessions |
   | quiet | 3.99 | gates drained; used to prove a separate hang was not contention |

3. **Literally duplicated suites in flight.** Process sampling showed two concurrent copies each
   of `test-verify-deploy-context-budget.sh` (one at 14m30s elapsed),
   `test-verify-deploy-gate-selection.sh`, and `test-context-reachability.sh` -- distinct PIDs
   running the same fixture against separate scratch dirs.

4. **Exclusion-table proliferation, four for four.** Tasks 379, 380, 388, 381 (and later 382 and
   386) each closed their final phase `[COMPLETED WITH EXCLUSIONS]`. In every case the cited
   findings were outside the task's own declared file_scope: siblings' in-flight edits,
   pre-existing gate failures, or ambient contention. Task 380 made ZERO file edits and still
   had to author one.

5. **The attribution failure is the substantive harm, not the wall clock.** Because each gate run
   sees every sibling's in-flight edits, a genuine new regression in a shared gate is
   indistinguishable from known sibling noise in the same result. One agent explicitly traced
   all 20 findings in its run line-by-line to establish that none were its own -- correct
   diligence, but work that a batch-level run would make unnecessary.

6. **Second-order harm: a cross-session process kill.** An agent reading its own contended run
   as hung issued `pkill -f "run-all.sh"`, which matched machine-wide and killed other sessions'
   gate runs (fixtures under `/tmp/tmp.HNQbmvK5C6/target` and `/tmp/tmp.Ub8w2zGFms/rich`). Read-only
   tooling, so no corruption, but those sessions' verification was interrupted. The contention
   is what made a broad pattern kill look reasonable.

7. **Second-order harm: an orphaned gate tree stranded a dispatch.** The same `pkill` killed a
   wrapper shell, leaving `verify-deploy.sh` trees reparented to `systemd --user` and running
   detached for 33-43 minutes while the agent that launched one waited ~2 hours for a
   notification that could never arrive. Filed as task 405; recorded here because contention was
   the trigger.

8. **The cheap tier works.** Every task that fell back to `--skip-slow` plus
   `run-all.sh --only <suites>` with explicit timeouts completed quickly and cleanly, and those
   narrow runs caught real defects (a shellcheck SC2164 in new fixture code; two self-introduced
   deploy-orphan/test-pollution defects). The narrow tier was not a weaker check in practice --
   it was the one that gave readable results.

## Decisions

- None taken here. Specifically left open, as the task description states: whether a single-task
  invocation keeps today's behaviour, how a shared run's failures attribute back to a responsible
  file_scope, and whether plan-format's `full` tier needs a batch-aware criterion variant.

## Recommendations

1. **Treat the attribution problem as the primary requirement**, with wall clock secondary. The
   measured harm is unreadable results, and four exclusion tables that mask regressions.
2. **Let the per-task final phase declare the narrow tier.** Evidence above shows
   `--skip-slow` + `--only` both sufficed and surfaced real defects; the full set added
   exclusion prose, not findings.
3. **Site the shared run after the last implement phase closes**, when no sibling has in-flight
   edits -- that is also the only point at which attribution is unambiguous.
4. **Fix the two gate blockers first or the shared run inherits them**: the zotero hang (task 404)
   makes any full run non-terminating, and the context-budget fixture (task 389) fails it at 1 of
   36. A shared run is pointless while one suite in it never returns. Consider whether 403 should
   carry dependency edges onto both.
5. **Consider an explicit prohibition on broad process-pattern kills** in agent contracts; the
   `pkill` incident was a rational response to an irrational amount of contention, and removing
   the contention removes most of the motive.

## Risks & Mitigations

- **Risk**: a batch-level gate run that fails names no owner, so no task is accountable.
  **Mitigation**: this is the open question the task already names; attribute by intersecting the
  failing gate's touched paths with each task's declared file_scope.
- **Risk**: narrowing per-task tiers reduces coverage. **Mitigation**: coverage moves rather than
  disappears -- it moves to the shared run; Settled decision 15 already documents a knowingly
  reduced-coverage precedent to model the record on.

## Appendix

- All load figures, PIDs and process names are quoted inline; none are carried from prior work.
- Related: task 404 (hang), task 389 (fixture), task 405 (stranded dispatch).
