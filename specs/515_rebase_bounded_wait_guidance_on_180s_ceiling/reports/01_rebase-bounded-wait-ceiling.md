# Research Report: Task #515

**Task**: 515 - Rebase the bounded-wait guidance on the measured foreground-backgrounding ceiling
**Started**: 2026-11-12T05:14:00Z
**Completed**: 2026-11-12T05:41:00Z
**Effort**: ~35 minutes (dominated by direct timed measurement, not file analysis)
**Dependencies**: None
**Sources/Inputs**:
- Direct empirical measurement in this session (six foreground Bash calls with `timeout` raised to `600000`, at 10s/170s/190s/350s/590s/620s)
- `agent-system/extensions/core/context/patterns/external-process-wait.md` (full read)
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` (full read)
- `~/Projects/BimodalLogic/specs/867_formalize_gabbay_separation_ztime/issues.jsonl`, entry `iss_1793996881041_SDZX8Y` (the cited defect record)
- `specs/state.json` (task 515 record), dispatch file `.dispatch/2.md`
**Artifacts**:
- This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The ~180s ceiling does not reproduce.** Six direct, timed foreground Bash calls in this
  session and harness (Claude Code 2.1.322), each issued with the tool's own `timeout` parameter
  raised to `600000`, completed synchronously at 10s, 170s, 190s, 350s, and 590s with no
  backgrounding at any point.
- **The real boundary measured is 600s, matching the documented figure exactly.** A seventh call
  at 620s (timeout parameter still `600000`) was moved to the background at the 600s mark, with
  the harness's own message citing "600s timeout" verbatim.
- **This is the "no-change" outcome the dispatch explicitly anticipates as a success case.**
  `external-process-wait.md` Rule 1 and `bounded-build-waiter.md`'s per-call pairing, both built
  on a `120000`ms default / `600000`ms ceiling model, are consistent with what was measured here
  and require no numeric correction.
- **The cited ~180s figure is a single self-report from a different repository, five days earlier
  in wall-clock time, with no corroborating measurement of its own** — see Findings for the exact
  text and a plausible (unconfirmed) account of how it could have arisen without the ceiling
  itself being 180s.
- **No propagation work is triggered.** The dispatch's propagation obligation (29-carrier bullet
  sync, `600000`-bearing prose in six named files) is conditioned on the guidance's numbers being
  wrong; since the measurement confirms them, that obligation does not activate.
- **Recommendation: close this record as no-change**, per the dispatch's own stated disposition
  for this outcome.

## Context & Scope

This task originated from a conclusion-stage proposal in a different repository
(`~/Projects/BimodalLogic`), carrying a citation that a dispatched agent's bounded foreground Bash
call was "forcibly backgrounded" at roughly 180 seconds, independent of the Bash tool's own
`timeout` parameter — contradicting this repository's `external-process-wait.md` and
`bounded-build-waiter.md`, both of which model the ceiling at 600s (`600000`ms) with a `120000`ms
default. The dispatch's first and controlling obligation was to re-measure the real boundary
empirically, in this harness, before editing anything; a confirmed 600s result was explicitly
pre-authorized as a valid "no-change" conclusion, not a failed dispatch. This report covers only
that measurement and its consequence for the two guidance files; it does not touch the
propagation inventory, the sibling-task ordering edges (#454, #439), or any other section of the
dispatch, because all of those are conditioned on the ceiling actually needing correction.

## Findings

### Direct Measurement (this session)

Harness: Claude Code 2.1.322 (`claude --version`), measured in this repository as a dispatched
`general-research-agent` subagent under `/orchestrate` — the same dispatch shape (a subagent
issuing a foreground Bash call) as the originating incident.

Six foreground Bash calls were issued, each wrapping `sleep N` with `echo` timestamps before and
after, each with the Bash tool's own `timeout` parameter explicitly set to `600000` (its
documented ceiling):

| N (sleep seconds) | Elapsed observed | Outcome |
|---|---|---|
| 10 | 11s | Completed synchronously, full output returned |
| 170 | 170s | Completed synchronously, full output returned |
| 190 | 190s | Completed synchronously, full output returned |
| 350 | 350s | Completed synchronously, full output returned |
| 590 | 590s | Completed synchronously, full output returned |
| 620 | — (backgrounded at ~600s) | Harness returned: "Command did not complete within its 600s timeout and was moved to the background" |

At no sleep duration up to and including 590s did the harness background the call or return
control early — the elapsed time printed by the command's own `date +%s` bracketing matched the
requested sleep duration exactly in every case (e.g. 350s requested, 350s observed; 590s
requested, 590s observed). Only the 620s call — the first to exceed the `600000`ms parameter
value itself — was moved to the background, and the harness's own message named "600s" as the
threshold, not ~180s. The backgrounded task was stopped via `TaskStop` once the boundary was
confirmed, rather than left running or awaited.

This directly refutes, for this harness version and this dispatch shape, the claim that
"a foreground Bash call is forcibly backgrounded once it exceeds roughly 180 seconds, REGARDLESS
of the value passed in that call's own `timeout` parameter" — the figure the dispatch description
carries from the cited entry. That figure is explicitly marked here as carried and now
re-derived:

> The harness backgrounds a foreground Bash call at ~180s regardless of the `timeout` parameter.
> [CARRIED-UNVERIFIED: `~/Projects/BimodalLogic/specs/867_formalize_gabbay_separation_ztime/issues.jsonl`, entry `iss_1793996881041_SDZX8Y`] — **re-derived in this session: refuted.** The measured boundary is 600s, matching the parameter's own documented ceiling, not ~180s.

### The Cited Entry, Read Directly

The full text of `iss_1793996881041_SDZX8Y` (BimodalLogic task 867, dispatch 17, phase implement,
class `tooling`, severity `costly`, timestamp 2026-11-06T20:28:01Z):

> "Dispatch 17 stalled: the harness forcibly backgrounds any foreground Bash call exceeding 180s
> regardless of the call's own timeout parameter, so the mandated single-call bounded-build-waiter
> idiom cannot complete in one call for a full lake build or a multi-gate sweep. The previous turn
> ended on an unresolved background wait, landing Phase 22.1's commit but none of its wrap-up
> artifacts. Worked around on the re-prompt by detaching the build with nohup plus a sentinel file
> and polling it in repeated sub-180s foreground calls."

This is a single agent's own self-report, written after the fact to explain a stall, with no
timed calibration calls of the kind run in this session — it records what the agent concluded
happened, not a measured boundary established by a deliberate probe at several durations. No
corroborating measurement from that repository or any other task is cited in this record or found
during this research pass.

**Plausible (unconfirmed) account for the discrepancy**: the BimodalLogic session ran five days
before this measurement (2026-11-06 vs. 2026-11-11/12), and the specific command stalled was a
`lake build` invocation rather than a bare `sleep`. Two explanations are consistent with the
measured data here without requiring the documented 600s ceiling to be wrong:
1. A harness version difference between the two sessions (not independently confirmed — the
   BimodalLogic session's exact harness version was not recorded in the cited entry, and is not
   re-derivable from this repository).
2. The stalled call may not have had the Bash tool's own `timeout` parameter actually raised to
   `600000` in that invocation, despite the guidance instructing it — in which case the harness's
   *default* (`120000`ms) would have governed, and the agent's own after-the-fact estimate of
   "around 180s" could be an imprecise recollection of a stall nearer the 120s default rather than
   a freshly-measured 180s boundary. This is speculative and is not asserted as the explanation,
   only as one account consistent with both records.

Neither explanation is verifiable from this repository, and resolving which (if either) is
correct is out of scope for this record: the dispatch's obligation was to establish the ceiling
that applies to *this* repository's guidance, which this measurement does directly.

### Current Guidance Content (re-derived, for the record)

Both files were read in full this session, not assumed from the dispatch description:

- `external-process-wait.md` Rule 1, step (2): requires raising the Bash tool's `timeout`
  parameter to `600000` from its documented `120000`ms default, with the "Why 540 < 600" paragraph
  explaining a 60-second margin under the 600s ceiling. Sub-case 3a/3b split is defined in terms
  of "fits under the 600s ceiling" / "cannot fit under the 600s ceiling at all."
- `bounded-build-waiter.md`'s "Sizing a Wait Near the Per-Call Ceiling" subsection and its
  "Canonical Agent-Contract Bullet" section's per-call pairing both state the same `120000`ms
  default / `600000`ms ceiling pairing, and the "Shape Taxonomy" section's shape 3a/3b split
  mirrors the same model.

Both files' numeric model (120s default, 600s ceiling, raise-the-parameter remedy, 540s inner
margin) is exactly what this session's direct measurement confirms. No numeric claim in either
file was contradicted by measurement.

## Decisions

- **The ~180s figure is refuted, not confirmed, for this repository's harness as measured in this
  session.** The measured boundary is 600s, matching the existing documentation.
- **No edits to `external-process-wait.md` or `bounded-build-waiter.md`.** Per the dispatch's own
  "FIRST OBLIGATION" section, a confirmed 600s result is grounds to close the record as
  no-change rather than make a numeric correction.
- **The propagation obligation (29-carrier bullet sync, the six named `600000`-bearing files) is
  not triggered.** It is explicitly conditioned on the numbers being wrong; a re-derivation of the
  carrier count or a byte-identical-bullet pin was therefore not performed, as doing so would have
  exercised machinery this outcome never calls for.
- **The sibling-ordering edges onto #454 and #439** (declared in the dispatch as depending on this
  record landing first, "so it reasons from a corrected premise") **are moot as ordering
  obligations**, because there is no corrected premise to reason from — this record changes
  nothing for either sibling to build on. Whether those edges should be removed (since there is no
  longer a correction for them to wait on) is a decision for the planning phase or an operator, not
  settled here.
- **The "WORKING REMEDY" (sentinel + liveness poll) and the propagation inventory were read and
  understood but not acted on**, since the numeric premise motivating them (a sub-180s ceiling
  under which "essentially every real `lake build` falls in 3b") did not hold up under
  measurement; the existing 3a/3b split already correctly treats the common case as 3a (fits under
  600s) rather than 3b, which is the inversion the dispatch worried about only under the ~180s
  premise.

## Recommendations

1. **Close task 515 as no-change**, carrying this report's measurement as the record. No
   implementation phase is needed against `external-process-wait.md` or `bounded-build-waiter.md`.
2. **Do not mechanically absorb this task's two sibling-ordering edges (#454, #439) into
   "no-op" without review.** Both edges were added on the premise that this record would correct
   a wrong number before those tasks build on it; since no correction occurred, an operator should
   confirm whether the ordering edge still serves a purpose (e.g. #439's propagation-architecture
   audit may still want to run after this record purely for sequencing hygiene, not because
   anything changed) before deciding to drop it.
3. **Optional follow-up, not part of this task**: if the discrepancy with the BimodalLogic
   citation is worth running down further, the right place is a task filed in *that* repository
   (per this repository's own `source-store-deploy-boundary.md` task-siting principle, a record
   about that repository's own session behavior does not belong here) — specifically, checking
   whether the stalled dispatch's actual Bash tool calls had the `timeout` parameter genuinely set
   to `600000`, and what harness version that session ran. This repository's guidance needs no
   change regardless of that outcome.

## Risks & Mitigations

- **Risk**: a single-session measurement (one harness version, one machine, six data points) could
  itself be an unrepresentative sample if the harness's backgrounding threshold is
  environment-sensitive (load, concurrent sessions, etc.). **Mitigation**: the measurement bracketed
  the claimed ~180s boundary from both sides (170s/190s completing, and separately pinned the true
  600s ceiling from both sides, 590s completing vs. 620s backgrounding) rather than relying on one
  data point, and the harness's own backgrounding message named "600s" explicitly, which is strong
  corroboration beyond timing alone.
- **Risk**: closing as no-change could be wrong if the BimodalLogic incident reflects a real,
  intermittent harness defect that simply didn't reproduce in six calls here. **Mitigation**: the
  recommendation above leaves that avenue open as a follow-up filed in the correct repository,
  without blocking this repository's guidance on an unconfirmed hypothesis.

## Context Extension Recommendations

None. This is a meta task type confirming existing guidance; no gap in `agent-system/**` context
documentation was identified.

## Appendix

- Search queries / commands used:
  - `claude --version` (harness version)
  - Six timed foreground Bash calls: `sleep 10`, `sleep 170`, `sleep 190`, `sleep 350`, `sleep 590`,
    `sleep 620`, each bracketed with `date +%s`, each issued with the Bash tool's `timeout`
    parameter set to `600000`
  - `TaskStop` on the 620s call's backgrounded task ID once the boundary was confirmed
  - `jq -c 'select(.entry_id=="iss_1793996881041_SDZX8Y")' ~/Projects/BimodalLogic/specs/867_formalize_gabbay_separation_ztime/issues.jsonl`
  - Full reads of `external-process-wait.md` and `bounded-build-waiter.md`
- References: `.dispatch/2.md` (this dispatch's full text), `specs/state.json` task 515 record
