# Research Report: the stranding discriminator is a conjunction, and re-prompting cannot recover it

- **Task**: 405 - Detect a stranded dispatch from its own stale heartbeat instead of only after a recorded failure
- **Started**: 2026-10-14T18:00:00Z
- **Completed**: 2026-10-14T21:30:00Z
- **Effort**: observational seed (measured across one live batch, including a successful recovery)
- **Dependencies**: None
- **Sources/Inputs**:
  - `task-lock.sh check` output for four separate tasks, two stranded and two healthy
  - `ps -eo pid,ppid,etime,args` ancestry walks; `uptime` load sampling
  - `orchestrate-cycle-postflight.sh` stderr for the stranded task
  - A successful hand recovery, and a failed remedy attempt that preceded it
- **Artifacts**: this report
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report-format.md

## Executive Summary

- SEED REPORT: field evidence, not a design round. It does, however, invalidate two premises a
  naive implementation would start from, so it should be read before planning.
- **Stale heartbeat alone is NOT a sufficient signal.** Two perfectly healthy tasks were
  simultaneously `held-live` at 32 and 41 minutes past a 30-minute threshold. A
  staleness-only rule false-positives on them.
- **The working discriminator is a conjunction**: stale heartbeat AND no live descendant of the
  session process AND no artifact mtime movement. Idle system load while the agent reports
  `running` was the clinching tell.
- **"Reparented to systemd" is NOT a stranding signal.** The sanctioned `nohup`-plus-poll idiom
  produces exactly that parentage by design; a healthy `deploy-headless.sh` was observed with
  `ppid=2614`.
- **The documented remedy does not work.** Re-prompting a stranded agent via a message is
  unreachable: messages drain at the receiver's next tool round, and a stranded agent takes none.
- **What did work**: `TaskStop` -> postflight -> fresh dispatch at the same `dispatch_seq`.
  Recovered a task with 5 of 6 phases committed, with no work redone and no failure charged.
- The existing postflight stall detector is better than the task description credits: it fired
  correctly, named the signature, and actively refused the failure charge.

## Context & Scope

Two dispatches in one batch stranded on background waits. One (a research dispatch) was lost
outright. One (an implementation dispatch) was recovered by hand. Two further dispatches in the
same batch crossed the staleness threshold while entirely healthy, which is what produced the
false-positive finding below.

## Findings

1. **The confirmed stranding instance, fully instrumented.** `task-lock.sh check 381` returned:

   ```
   held-live session=sess_... heartbeat_age_min=128 threshold_min=30
              never_heartbeated=false liveness_reason=pid-alive
   exit=0
   ```

   128 minutes against a 30-minute threshold, and the check exited **0** -- "proceed". This is
   the asymmetry the task describes, reproduced verbatim: the state is classified correctly and
   its only consumer reads it as healthy because the PID is alive.

2. **THE FALSE-POSITIVE FINDING -- the most important content in this report.** Later in the same
   batch, two healthy tasks reported:

   ```
   #382: held-live heartbeat_age_min=32 threshold_min=30 liveness_reason=pid-alive
   #386: held-live heartbeat_age_min=41 threshold_min=30 liveness_reason=pid-alive
   ```

   Both were mid-final-phase and both completed normally minutes later (6/6 and 5/5 phases). The
   heartbeat pulses at phase and dispatch boundaries, so a long final phase legitimately exceeds
   the threshold. **A detector keyed on `held-live` plus threshold alone would have flagged two
   healthy dispatches as stranded.**

3. **The discriminator that actually separated the cases.** For the healthy pair:
   - a live descendant of the session's own `claude` PID, freshly started (`etime 00:00`);
   - active grandchildren doing visible work (`shellcheck -S warning`, `verify-deploy.sh`);
   - system load high (41.79).

   For the stranded one:
   - no live descendant attributable to the dispatch;
   - zero artifact mtime movement for ~2 hours;
   - system load fallen to **3.99 on 24 cores** while the agent still reported `running`.

   The idle-machine-plus-running-agent combination was unambiguous and cheap to check.

4. **False-positive guard: systemd parentage is expected.** A healthy `deploy-headless.sh` ran
   with `ppid=2614` (`systemd --user`) because `external-process-wait.md` Rule 1 prescribes
   `nohup ... &` plus a `kill -0` poll. Detaching from the shell is the sanctioned idiom. So
   orphan-parentage cannot be used as a stranding signal on its own -- which is precisely why
   the conjunction in finding 3 is necessary rather than merely more accurate.

5. **The documented remedy is unreachable in the case it is written for.** `specs/ROADMAP.md`'s
   unfiled observation prescribes "re-prompt the agent directly". A message was sent to the
   stranded agent; it was accepted into the inbox and never read. Messages drain at the
   receiver's next tool round, and a stranded agent takes no further tool round. The remedy is
   structurally self-sealing. **Any fix that routes recovery through a message to the stuck
   agent will not work.**

6. **The recovery path that did work**, in order: `TaskStop` on the agent; then
   `orchestrate-cycle-postflight.sh`; then a FRESH `Agent` dispatch at the same `dispatch_seq`
   with explicit instructions to verify in the foreground. The replacement closed the final
   phase without redoing any of the five committed phases.

7. **The existing stall detector already does the hard part.** Postflight emitted:

   > STALL SUSPECTED ... no usable outcome was recovered, yet 6 commit(s) for this task landed
   > during this dispatch window. This is the abandoned-wrap-up signature ... Do NOT charge this
   > to failed_tasks without that re-prompt: the committed work is intact and only the wrap-up is
   > missing.

   It correctly identified the signature, correctly refused to charge a failure, and correctly
   named the remedy -- except that the remedy it names (re-prompt the same dispatch) is the one
   finding 5 shows cannot be delivered as a message. The gap is narrower than "no detection":
   detection at postflight works; what is missing is (a) detection BEFORE postflight, and (b) a
   remedy that does not require the stuck agent to cooperate.

8. **The research-dispatch instance was a total loss.** Its only return text was one sentence:
   "Waiting for the Monitor notification that the fixture test has completed before finalizing
   the research report." No report, `.return-meta.json` stuck at `in_progress`, postflight
   `failed` with `report_missing=true`. That text was preserved via
   `orchestrate-recover-message-findings.sh`. Its task remains at `researching` and must be
   re-run from scratch -- the cost difference versus the recovered instance is the argument for
   detecting earlier.

## Decisions

- None. Two premises are invalidated (findings 2 and 5); the design response is this task's own
  planning job.

## Recommendations

1. **Do not key the detector on heartbeat staleness alone.** Require the conjunction from
   finding 3. Finding 2 is a ready-made regression fixture for the false-positive case.
2. **Add a healthy-but-slow fixture alongside the stranded fixture.** A detector that only has a
   positive case will ship the false positive measured here.
3. **Do not route recovery through a message to the stuck agent.** Finding 5 closes that path.
   Model recovery on the sequence in finding 6, which is already composed of existing primitives.
4. **Reuse the postflight detector's own logic rather than writing a second one.** Finding 7
   shows the signature test (no usable outcome + commits landed in the window) already exists and
   is correct; the task is to run that class of check earlier and to fix the remedy it names.
5. **Correct the roadmap's unfiled observation** when this lands, since it currently prescribes a
   remedy that cannot work.

## Risks & Mitigations

- **Risk**: an over-eager detector kills healthy long-phase dispatches -- the measured
  false-positive case. **Mitigation**: conjunction plus the finding-2 fixture.
- **Risk**: `TaskStop`-then-redispatch loses in-context work not yet written to disk.
  **Mitigation**: the stranded instance had everything committed except wrap-up, which is what
  made recovery cheap; the detector should report what is on disk before any stop is issued.
- **Risk**: treating `held-live` as unhealthy in the monitoring context could leak into the
  lock-acquisition context, where a live PID genuinely means healthy. **Mitigation**: the task
  description already requires documenting the per-context interpretation; keep the two readers
  explicitly separate.

## Appendix

- All lock-check output, PIDs, parentage walks and load figures are quoted inline from live
  samples taken 2026-10-14; none are carried.
- Related: task 403 (contention was the trigger for the orphaning), task 404 and task 389 (the
  two gate obstructions that lengthened every final phase and widened the window).
