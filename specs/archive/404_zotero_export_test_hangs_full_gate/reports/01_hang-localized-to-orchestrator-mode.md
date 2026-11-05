# Research Report: zotero export test hang localized to the script under --orchestrator-mode

- **Task**: 404 - Fix test-zotero-generate-export.sh hanging indefinitely and breaking every full verify-deploy.sh run
- **Started**: 2026-10-14T17:40:00Z
- **Completed**: 2026-10-14T21:20:00Z
- **Effort**: observational seed (no code read; evidence captured during an unrelated batch)
- **Dependencies**: None
- **Sources/Inputs**:
  - Live `ps -eo etime,pid,ppid,args` process-table sampling during a concurrent 7-task batch
  - Two independent in-isolation reproductions by implementation agents on separate dispatches
  - `uptime` load sampling across the same window
- **Artifacts**: this report
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report-format.md

## Executive Summary

- SEED REPORT. This is observational evidence captured incidentally while other tasks ran; it is
  not a substitute for this task's own research round. No source file was read.
- The hang is localized: during a 24-minute live stall the test harness had exactly ONE live
  descendant, `zotero-generate-export.sh --orchestrator-mode true`. The fault is in that script
  under that flag, not in the test harness's control flow.
- Reproduced in isolation at zero contention, twice, hours apart, by two different agents:
  `timeout 60` and `timeout 90` both expire after the suite passes its first case.
- Contention is ruled out as the cause: the isolated reproductions ran with the machine
  otherwise quiet, and the hang persisted when system load had fallen to 3.99 on 24 cores.
- Consequence measured in the same window: four separate tasks each had to close their final
  phase `[COMPLETED WITH EXCLUSIONS]` and author a Reasoned Exclusions table naming this hang,
  because the complete gate set never terminates.

## Context & Scope

Evidence was gathered while orchestrating an unrelated 7-task batch whose plans each declared
the final-phase criterion "verify-deploy.sh exits 0 -- the complete gate set". Every attempt at
that criterion reached gate 8 (`run-all.sh`), which reaches this suite, which does not return.

Scope of this seed: what was directly observed. It does NOT diagnose the stall's mechanism
inside the script, which requires reading `zotero-generate-export.sh` and is this task's own
research job.

## Findings

1. **Single-descendant localization (the load-bearing finding).** Process-table sampling during
   the stall showed the harness and exactly one child:

   ```
   23:40  4097120  bash .../literature/scripts/tests/test-zotero-generate-export.sh
   00:24   586693  bash .../literature/scripts/zotero-generate-export.sh --orchestrator-mode true
   ```

   `ps --ppid 4097120` confirmed 586693 as its only child. The harness was not looping, forking
   repeatedly, or waiting on multiple children -- it was blocked on one script invocation.

2. **No spawn loop.** Sampling the same PIDs 10 seconds apart showed the identical PIDs with
   elapsed times advancing in lockstep (`00:34 -> 00:44`, `23:50 -> 24:00`). Nothing was being
   respawned; the single child was simply not returning. This rules out a retry loop.

3. **Reproduced in isolation, twice, by independent agents.**
   - First: `timeout 60 bash .../test-zotero-generate-export.sh` -- passes one case, then stalls
     past the timeout. Run with the machine uncontended.
   - Second, hours later and independently: `timeout 90` against the same suite, same result,
     explicitly re-confirmed as still live.

4. **Not a contention artifact.** The suite was still stalled at the moment system load had
   dropped to 3.99 on a 24-core machine. Separately, the two isolated reproductions above were
   run with no competing gate load. Slowness under contention and this hang are distinguishable
   and were distinguished.

5. **It terminates eventually, or is reaped, but far outside any usable bound.** The 24-minute
   instance did exit on its own between two samples. That makes it a pathological wait rather
   than a strict deadlock -- but 24 minutes against a ~10-minute full-gate budget is
   indistinguishable from a hang in practice, and a `540s` bounded wait SIGTERMs mid-run.

6. **Blast radius confirmed at four tasks in one batch.** Tasks 379, 380, 388 and 381 each
   independently reached this suite and each authored an exclusion record for it. One of them
   also re-derived the isolation reproduction rather than trusting a sibling's claim.

## Decisions

- None. A seed report records evidence; the design decisions (bounded wait vs. non-interactive
  path vs. both) belong to this task's own research and plan rounds.

## Recommendations

1. **Start from the flag, not the harness.** The single-descendant evidence says the harness is
   innocent. Read `zotero-generate-export.sh`'s `--orchestrator-mode true` path first.
2. **Check the two candidate causes named in the task description before any others**: a read
   from stdin with no redirect (an interactive prompt reached in a non-interactive context),
   and an unbounded wait on a Zotero API/socket call with no timeout. The single-child,
   zero-CPU, eventually-returns profile is consistent with either.
3. **Do not reproduce under load.** Both isolated reproductions were cheap and unambiguous;
   reproducing during a contended batch wastes wall clock and muddies the signal.
4. **Make the test's own bound part of the fix.** A suite that can stall for 24 minutes should
   fail loudly at a wall-clock bound regardless of what the script does, so a future regression
   of this shape is a readable FAIL rather than a hang.

## Risks & Mitigations

- **Risk**: the eventual self-exit makes a naive fixture flaky -- a generous timeout may pass by
  luck. **Mitigation**: assert the bound itself (the run must terminate under N seconds), and
  verify the fixture fails against a deliberately-stalled stub.
- **Risk**: fixing only the test's timeout leaves the script's unbounded wait in place, so every
  other caller of `zotero-generate-export.sh` keeps the hazard. **Mitigation**: the task
  description already scopes both halves; keep them both.

## Appendix

- Process samples, load figures and the two reproduction commands are quoted inline above.
- Related, filed separately: task 389 (the other reason the complete gate set does not pass),
  task 403 (why N concurrent tasks each run the full battery), task 405 (the stranded-dispatch
  failure mode that cost this batch two dispatches).
