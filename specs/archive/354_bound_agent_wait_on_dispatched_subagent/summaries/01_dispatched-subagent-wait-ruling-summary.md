# Implementation Summary: Task #354

- **Task**: 354 - Decide whether general-implementation-agent.md's Local Long-Running Command
  Discipline needs a third case covering an agent that dispatches a subagent and waits on it
- **Status**: [COMPLETED]
- **Started**: 2026-10-12T09:00:00Z
- **Completed**: 2026-10-12T17:15:00Z
- **Effort**: ~2.5 hours (across two dispatch rounds)
- **Dependencies**: None
- **Artifacts**: plans/01_dispatched-subagent-wait-ruling.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closed the textual gap in `general-implementation-agent.md`'s Local Long-Running Command
Discipline: the mandate named the CI/remote case and the local-gate case but was silent on an
agent dispatching a subagent and waiting on it. The ruling adopted is the refined middle
position recommended by research: synchronous nested `Agent`-tool delegation is explicitly
blessed as outside the discipline (it is the normal, intended delegation primitive, with no
turn-ending choice point), while issuing an async/backgrounded subagent dispatch and then ending
the turn to await its result is prohibited outright -- not bounded with a deadline, because
unlike the CI case (`gh run view`) and the local-gate case (`kill -0` on a captured PID), a
backgrounded subagent dispatch exposes no PID or status primitive the dispatching agent can poll
from inside its own turn. This is a documentation-only change across four source-store files,
followed by a redeploy and the repository's full gate set.

## What Changed

- `agent-system/extensions/core/agents/general-implementation-agent.md` -- new **Dispatched-
  Subagent Wait Discipline** subsection in the Local Long-Running Command Discipline block,
  stating the permitted synchronous-delegation carve-out, the MUST NOT on an unresolved
  async/backgrounded dispatch, and why no bounded-poll allowance is offered.
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` -- new ruling-record
  subsection (sibling to the file's existing ruling records, not nested under the canonical
  generated-copy bullet pair) recording which of the three candidate positions was taken and
  why, plus a `## Related Documentation` pointer to the new subsection.
- `agent-system/extensions/core/context/patterns/external-process-wait.md` -- a
  `## Related Documentation` pointer to the same subsection, noting the CI-status-poll idiom
  does not apply to the subagent-dispatch case.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` -- new
  **Diagnosing Dispatch Liveness: A Probe for External Watchers** subsection (inserted between
  "Abandoned Wrap-Up" and "Loop-Owned Runtime State"), documenting artifact mtimes and live
  child-process trees as the discriminating signals, naming the handoff-absence false signal
  explicitly, and affirming `stall_suspected`'s trigger predicate is unchanged.
- Regenerated `.claude/**` deploy tree (gitignored, not committed) via `deploy-headless.sh`; all
  four deployed copies confirmed byte-identical to their source-store counterparts.

## Decisions

- Adopted the middle position (bless synchronous delegation, prohibit unresolved
  async/backgrounded waits outright) rather than extending the three-way deadline fork
  verbatim, because no foreground-pollable liveness or status primitive exists for a
  backgrounded `Agent`-tool dispatch -- a deadline-and-poll clause would describe a mechanism
  that does not exist.
- Grounded the new MUST NOT in the demonstrated capability (a dispatched agent has already
  issued a nested async/backgrounded `Agent` fork-probe call) rather than in the one incident
  that looked like evidence of stranding, which was retracted as a misdiagnosis (artifact
  mtimes showed the dispatch actively working throughout).
- Left `stall_suspected`'s trigger predicate unchanged -- this is an explicit non-goal, since
  no new evidence was produced that would justify reopening task 343's non-widening ruling, and
  widening it with an OR against handoff-absence would destroy its only discriminating signal.
- Did not propagate the new MUST NOT to other implementation agents (`lint-agent-contracts.sh`'s
  `BOUNDED_WAIT_IN_SCOPE_RELATIVE_PATHS` set), fold it into `bounded-build-waiter.md`'s canonical
  generated-copy bullet pair, or add a standalone note on the harness-level async/"teammate"
  `Agent` mode -- all explicit non-goals carried from the plan.

## Plan Deviations

- None in the implemented work. One procedural stumble during Phase 4 execution (this round): an
  early attempt to background-and-poll the baseline `verify-deploy.sh` run without capturing its
  real PID in the same foreground call led to a duplicate run writing to the same log file
  concurrently; recovered by killing both chains and restarting cleanly with a single
  `nohup ... & disown; echo $! > pidfile` call. No deliverable was affected.

## Verification

- Build: N/A (documentation-only change)
- Tests: `lint-agent-contracts.sh` exits 0 (its two grepped Check-H strings in
  `bounded-build-waiter.md` each still occur exactly once); `check-task-references.sh` exits 0
  (0 occurrences under `agent-system/**`); `stall_suspected`'s trigger predicate confirmed
  byte-identical (`git diff` empty across this task's commits for
  `orchestrate-cycle-postflight.sh`)
- Files verified: Yes -- all four deployed copies diff-empty against their source-store
  counterparts

### Full Gate Set (verify-deploy.sh)

- **Baseline (pre-deploy, full/non-skip-slow run)**: 3 of 36 failed -- gate 3 (doc-lint), gate 5
  (manifest content-hash mismatch on `scripts/tests/test-verify-deploy-context-budget.sh`),
  gate 8 (`run-all.sh`). All three were traceable to a concurrent sibling task's
  then-uncommitted edits to `verify-deploy.sh` and `test-verify-deploy-context-budget.sh` --
  exactly the failure pattern the dispatch flagged in advance as attributable to sibling work,
  not to this task's four files.
- **`deploy-headless.sh`**: `RESULT=landed_verify_clean`; its inline `--skip-slow` verification
  passed 35/35.
- **Post-deploy (full/non-skip-slow run)**: 1 of 36 failed -- gate 8 (`run-all.sh`) only. Gates 3
  and 5 cleared between the two runs because the sibling landed its own commit in the interim.
  **No new failure was introduced by this task's changes.**
- The repository's test/gate suite ran under heavy concurrent load from several sibling
  orchestrated dispatches each running their own `verify-deploy.sh`/`run-all.sh` instances in
  parallel, so each full gate-set run took roughly 9-10 minutes against a documented ~2.8-minute
  baseline. This was a wall-clock/host-contention effect, not a correctness issue.

## Impacts

- `general-implementation-agent.md`'s wait-discipline mandate now covers all three shapes an
  implementation agent's long-running wait can take (CI/remote, local gate, dispatched
  subagent), closing a previously silent gap without forbidding ordinary nested delegation.
- Future readers diagnosing whether an externally-watched dispatch is stranded or merely slow
  now have a documented probe (artifact mtimes, live child processes) and an explicit warning
  against the handoff-absence false signal.

## Follow-ups

- None required by this task. The report's Context Extension Recommendation (a standalone note
  on the harness-level async/"teammate" `Agent` mode) and propagating the new MUST NOT to other
  implementation agents were both explicit non-goals, left for a future task if nested
  async/backgrounded subagent use grows beyond the single measured fork-probe case.

## References

- Plan: `specs/354_bound_agent_wait_on_dispatched_subagent/plans/01_dispatched-subagent-wait-ruling.md`
- Research report: `specs/354_bound_agent_wait_on_dispatched_subagent/reports/01_dispatched-subagent-wait.md`
- Progress files: `specs/354_bound_agent_wait_on_dispatched_subagent/progress/phase-{1,2,3,4}-progress.json`
- Handoffs: `specs/354_bound_agent_wait_on_dispatched_subagent/handoffs/`
