# Research Report: Detect a Stranded Dispatch From Its Own Stale Heartbeat

**Task**: Detect a stranded dispatch from its own stale heartbeat instead of only after a
recorded failure
**Started**: 2026-10-14
**Completed**: 2026-10-14
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: Codebase (`agent-system/extensions/core/`), `specs/ROADMAP.md`, `specs/state.json`
(task 376)
**Artifacts**: `specs/405_detect_stranded_dispatch_from_stale_heartbeat/reports/01_detect-stranded-dispatch.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `task-lock.sh check`'s third state, `held-live` (stale heartbeat, holder pid alive — see
  `context/patterns/task-lock.md` lines 260-314), is already correct for the one context that
  consumes it today: lock **acquisition**, where a live pid correctly means "don't steal this."
  No code path consumes it for **stall detection**, where the same observation should mean the
  opposite.
- The two places closest to the missing consumer already exist and already mishandle the
  distinction because they branch on `check`'s raw exit code (0/1/2) without ever grepping the
  output line for `held-live` vs `held-fresh`: `reconcile-task-status.sh`'s
  `demote_stranded_status()` (lines 247-259) explicitly documents "1 (held-fresh) -> NEVER
  demote. A genuinely fresh lock means a live session may actually be working" — a `held-live`
  result hits this same `1` branch today and is silently read as healthy. `orchestrate-cycle-plan.sh`'s
  lock PROBE (lines 2044-2065) has the identical blind spot for the same-session case.
- The existing postflight stall signal, `stall_suspected` (`orchestrate-cycle-postflight.sh`
  lines 2043-2091), is commit-gated by design and has a documented boundary (line 2073) that
  leaves a zero-commit stall — exactly the measured research-dispatch incident — undetected. A
  prior task (376) already ruled, explicitly and on the record, against widening
  `stall_suspected`'s own trigger predicate to absorb a new detector; any new signal must be a
  separate field.
- `376` (`not_started`, `dependencies: [376→393]`) is live prior art for the *prevention* half:
  it found the Lean implementation/hard-implementation agents literally instructing the
  forbidden `run_in_background` + "wait for the harness's completion notification" pattern, in
  direct contradiction of `general-implementation-agent.md`'s own MUST NOT clauses. Any lint
  extension built for 405's prevention half should be scoped and sequenced against 376 rather
  than independently re-deriving the same grep.
- A lint precedent for the prevention half already exists and is a close structural match: Check
  H in `lint-agent-contracts.sh` (lines 629-698) verifies that 14 implementation agents carry the
  canonical bounded-wait MUST/MUST-NOT bullet pair. It is **presence-only** — it never checks
  that the file is free of a *contradicting* instruction elsewhere, which is exactly the defect
  376 found in the Lean agents and exactly the gap 405's prevention half should close.
- A reusable, zero-real-time fixture pattern for `held-live` already exists in
  `scripts/test-session-registry.sh` (`write_session_fixture ... "$$" ...` with a synthetic old
  timestamp) and should be reused verbatim rather than re-derived for 405's own verification
  fixture.

## Context & Scope

The task asks for two complementary halves: (a) teach the orchestration loop to read
`task-lock.sh check`'s existing `held-live` state as a stall signal during **in-flight dispatch
monitoring**, distinct from its correct meaning during **lock acquisition**, reusing the existing
`TASK_LOCK_STALE_MIN` threshold and exit codes rather than adding a second staleness notion; and
(b) extend the existing agent-contract lint to catch the "detach, then end the turn awaiting a
notification" antipattern that produces the stall in the first place. Out of scope per the
dispatch: changing notification delivery itself, and reaping/killing orphaned process trees.

This research is scoped to locating every existing `held-live`/`held-stale`/stall-adjacent read
site, establishing precisely where the context-dependent misreading occurs today, confirming the
`stall_suspected` boundary and task 376's explicit non-widening ruling, and surfacing the
available lint and fixture precedents for the implementation plan to build on. It does not design
the final mechanism end-to-end — several load-bearing timing questions (below) affect which site
is actually load-bearing and are better resolved with the planner's tracing of the live dispatch
sequence than asserted here without a runnable trace.

## Findings

### Codebase Patterns

**1. `held-live`'s only consumer today is acquisition-side, and it is correct there.**
`context/patterns/task-lock.md` lines 260-314 document the state in full: produced only when (i)
the heartbeat is stale by `TASK_LOCK_STALE_MIN` (default 30, range 30-60 min), (ii) the holder's
`session_id` resolves in the session registry, and (iii) that entry's `session_liveness()`
verdict is exactly `pid-alive`. It reuses `held-fresh`'s exit code (1) rather than minting a new
one — every existing exit-code consumer therefore cannot distinguish `held-live` from
`held-fresh` without additionally parsing the output line's `held-live`/`held-fresh` text prefix.
`cmd_acquire`'s own cross-task overlap pass (the one site built to *produce and consume* this
state in the acquisition context) does parse the prefix and escalates a stale-but-live foreign
lock from WARN-and-proceed to ABORT — correct, because during acquisition a live holder should
not be stolen from regardless of heartbeat age.

**2. Every other exit-code consumer reads 0/1/2 only, never the text prefix — so `held-live`
degrades silently to whichever bucket its exit code shares.**

- `scripts/orchestrate-cycle-plan.sh` lines 2044-2065 (the read-only lock PROBE, run before
  admitting a candidate into this cycle's dispatch set): exit 1 (held-fresh *or* held-live)
  branches only on `holder_session == session_id`; same-session is unconditionally admitted,
  foreign is deferred as "locked by another session" with no distinction for whether that foreign
  lock is fresh or merely live-but-stale. Exit 2 (held-stale) is unconditionally admitted
  regardless of session (the real `acquire` below is the actual safety net, and it does its own
  stale-foreign-lock override-and-WARN).
- `scripts/reconcile-task-status.sh` lines 247-330 (`demote_stranded_status()`, the lock-aware
  demotion added for a prior "Direction (b) defense-in-depth" task): exit 0 or 2 demotes
  (`researching`/`planning` -> an earlier status, on the theory that nothing is protecting this
  in-progress marker); exit 1 is documented as "NEVER demote. A genuinely fresh lock means a live
  session may actually be working on this task right now" — this prose, like the code, treats
  `held-live` identically to `held-fresh`.
- `scripts/orchestrate-unwind-dispatch.sh` lines 276-293 ("Gate #6"): exit 1 refuses only when the
  held session differs from the caller's own `session_id`; same-session held-live/held-fresh both
  proceed. This one is scoped to cleanup/unwind, not stall detection, and its same-session
  same-exit-code grouping is defensible for its own purpose (killing/unwinding a dispatch this
  exact session owns).

None of these three sites is itself "the" bug — each behaves exactly as documented for its own
stated purpose. The gap is that **no fourth site exists** for the purpose the task actually wants:
reading a currently-in-flight (or just-returned) dispatch's own lock state as a stall signal, where
`held-live`'s pid-alive component is weak evidence (see Risk below) and the heartbeat staleness
itself is what should drive the verdict — the inverse of acquisition's weighting.

**3. `stall_suspected` is the closest existing analog, and it has a documented, deliberate
boundary that leaves the measured research-dispatch incident uncovered.**
`scripts/orchestrate-cycle-postflight.sh` lines 2043-2091: true only when a plan/implement
dispatch returned no usable outcome **and** at least one commit landed for that task since
`dispatch_start_ts`. The BOUNDARY comment at lines 2073-2075 states explicitly: "a stall occurring
before this task's first commit leaves `stall_commit_count` at zero, so this field stays false and
the dispatch falls through to the ordinary no-outcome/failed path." The dispatch's own instance 1
(a research dispatch, zero commits, single-sentence "waiting for the Monitor notification" return)
is precisely this boundary case — `stall_suspected` cannot fire for it by construction, and
`report_missing` (the research-phase sibling signal, lines 2018-2041) is advisory only and does
not itself prevent the failed-and-requeue outcome the dispatch describes.

Also load-bearing: `stall_suspected` is **advisory** — it "never changes verdict, status, or
`failed_tasks` bookkeeping" (line 2059). The actual deferral of the failure charge happens one
layer up, in `skill-orchestrate/SKILL.md`'s Move 3/4, which reads the field and accumulates the
dispatch to `pending_stall_reprompt[]` instead of `failed_tasks`. Any new heartbeat-based signal
following this same shape would need an equivalent lead-side consumer, not just a postflight
computation.

**4. Task 376 already settled, on the record, that a new detector must not widen
`stall_suspected`'s own predicate.** `specs/state.json` task 376 (`not_started`,
`dependencies: [393]`) — "Lean implementation agents mandate the detach-then-await-notification
path core forbids" — contains an explicit `## EXPLICIT NON-GOALS` section: *"DO NOT widen
`stall_suspected`'s trigger predicate. That non-widening is a recorded prior ruling and this task
produces no evidence bearing on it. Note separately that orchestrator-side postflight never got a
chance to flag this because the dispatch never returned at all; if any detector work is proposed,
argue it on its own merits and keep it out of `stall_suspected`."* This is a direct, prior,
on-the-record instruction against the most tempting shortcut (adding a heartbeat OR-clause to the
existing field) and should be treated as binding unless 405's own plan explicitly re-litigates it
with new evidence.

**5. Task 376 is also the most directly relevant prior art for the prevention half**, and
measured a live incident of the exact antipattern: a lean-implementation-agent dispatch
backgrounded a 25-probe gate sweep and reported "I'll wait for its completion notification before
editing the script," then went idle permanently — recovered only by an explicit orchestrator
SendMessage re-prompt. 376's own research located the contradiction at specific lines:
`agent-system/extensions/core/agents/general-implementation-agent.md` (lines ~182-205, which
already carry the correct MUST/MUST NOT prose — see Finding 7) versus
`agent-system/extensions/lean/agents/lean-implementation-agent.md` (lines 30, 70, 337, 741, 768),
which instructs `Bash(run_in_background: true)` followed by "wait for the harness's completion
notification before recording the result" — the literal forbidden shape, restated five times in
one file, plus the same pattern confirmed still present (checked directly in this research pass)
in `lean-implementation-hard-agent.md` (lines 243, 453). 376 is `dependencies: [393]` and is not a
concurrent sibling of this dispatch, but any lint rule 405 builds for the prevention half will
either need to tolerate these known Lean occurrences (as a curated exclusion, mirroring Check H's
existing three-file exclusion list) until 376 lands, or be sequenced after 376.

**6. Six sites were confirmed (by this research pass, directly) still carrying the literal
"wait for the harness's completion notification" phrase**, beyond the two 376 already names:
`grep -rn "completion notification" agent-system/extensions/` found it in
`lean-implementation-agent.md` (x5, matching 376's own count) and `lean-implementation-hard-agent.md`
(x2) only — no other extension's implementation agent currently carries this exact phrase. This
narrows the prevention half's grep target considerably versus 376's own broader caution about "~18
other `*-implementation-agent.md` files."

**7. The correct contract text already exists verbatim in core, and a structurally analogous lint
already exists (Check H) — but it only checks presence of the canonical text, never absence of a
contradicting one.**
`agents/general-implementation-agent.md` (the canonical home) carries the full, correct MUST /
MUST NOT pair for both the CI/remote case (`external-process-wait.md` Rule 3: "Use
`run_in_background` or arm a Monitor to watch a CI/remote wait from within this dispatched
subagent" is a MUST NOT) and the local-gate case ("MUST NOT use `Bash(run_in_background: true)` or
arm a `Monitor` to watch a local verification, gate, build, or test process"). `lint-agent-contracts.sh`'s
Check H (lines 629-698) greps 14 named implementation-agent files for the canonical MUST +
MUST-NOT bullet text (sourced from `bounded-build-waiter.md`'s fenced block, never
re-transcribed), with three documented, curated exclusions — one of which is
`lean-implementation-agent.md` itself, excluded today *because* it "carries a domain-adapted,
sanctioned background-build path," i.e. the lint already special-cases the exact file 376 found
violating the rule, on the assumption that its adaptation is sanctioned. Check H's own re-audit
command (line 644) is `grep -c run_in_background` / `grep -c bounded-build-waiter` — a
presence/absence count, not a search for the specific forbidden "wait for ... notification"
phrasing. Check I (lines 700-763) is a different, advisory-only check (heartbeat-mechanization
*call* adoption, not wait-shape).

**8. A reusable, zero-real-time fixture pattern for constructing a `held-live` state already
exists.** `scripts/test-session-registry.sh` lines 215-263, 320-329 construct "live pid, stale
heartbeat" fixtures via `write_session_fixture "$SESSIONS_DIR" "<id>" "$$" ... <age_minutes>` —
using the test script's own PID (`$$`) as a guaranteed-live stand-in pid, paired with a
synthetically old `heartbeat_at`/age argument computed via "controlled epoch arithmetic" rather
than any real `sleep`. This is the exact shape the dispatch's verification requirement calls for
("an agent-side wait on a signal that never arrives, with a live holder pid and a stale
heartbeat") and should be reused rather than re-derived; it already proves the
`pid-alive`/`dead-pid`/`dead-pid-within-grace` boundary cases this task's own fixture would need.

### External Resources

Not applicable — this is an internal orchestration-mechanism design question with no external
library, API, or published-practice dependency; nothing in this task benefits from a web search.

## Decisions

- Treat task 376's `## EXPLICIT NON-GOALS` ruling (Finding 4) as binding: any new detector signal
  this task introduces must be a field separate from `stall_suspected`, never an added disjunct
  to its existing predicate.
- Treat the six `lean-implementation-agent.md` / `lean-implementation-hard-agent.md` occurrences
  of the literal forbidden phrase (Finding 6) as **already-known, already-tracked** by task 376
  rather than evidence this task must independently re-fix — 405's prevention half should extend
  the *lint*, and either carry a time-boxed exclusion for the two already-named Lean files (mirroring
  Check H's existing exclusion-list mechanism) or be explicitly sequenced after 376, rather than
  silently re-deriving a fix for files 376 already owns.
- Confirmed, by direct re-check against the current source store, that no implementation-agent
  file outside `lean/` carries the literal "completion notification" phrase today (Finding 6) — the
  prevention half's grep scope is narrower than 376's own precautionary "~18 files" framing
  suggested.

## Recommendations

**For the detection half (a):**

1. Document the context-dependent interpretation explicitly in `context/patterns/task-lock.md`,
   as its own named subsection (e.g. "`held-live` Interpretation Is Context-Dependent, Not
   Universal"), stating in one place: during **acquisition** (the existing `cmd_acquire` cross-task
   pass), a live pid means "a live session may be working, do not steal" (unchanged); during
   **in-flight/post-return dispatch monitoring**, the same observation — stale heartbeat, pid
   nominally alive — should be read as a stall candidate, because the pid-liveness signal is weak
   in that context (see Risk below) and the heartbeat is the real discriminator. This closes the
   "decide and document" half of the goal regardless of which consumer below is ultimately wired.
2. Add the actual consumer as a **new, separate field** in `orchestrate-cycle-postflight.sh`,
   computed alongside (not merged into) `report_missing`/`stall_suspected`, calling
   `task-lock.sh check "$task_number"` and reading its text prefix (not just exit code) for
   `held-stale`/`held-live` — this is the one site that runs for every dispatch immediately after
   its Agent-tool call returns and strictly before the lead's failed/re-prompt branch point
   (Move 3/4), i.e. structurally "before charging a failure" in the same sense `stall_suspected`
   already is. Unlike `stall_suspected`, this signal does not need a commit to exist, which is
   exactly the gap it is meant to close (Finding 3).
3. Separately, fix the two already-identified same-exit-code conflations that currently *actively
   misclassify* a `held-live` result as healthy outside the acquisition context: the exit-1 branch
   of `reconcile-task-status.sh`'s `demote_stranded_status()` (Finding 2) and, if in scope,
   `orchestrate-cycle-plan.sh`'s lock PROBE same-session branch. Both are small, surgical,
   text-prefix-grep changes (mirroring `cmd_acquire`'s own existing `held-live` prefix check) —
   not new mechanisms.
4. Before finalizing where the "new consumer" in (2) is actually load-bearing, trace the live
   dispatch/postflight sequence end to end (ordering of per-task `task-lock.sh release` relative
   to postflight's signal computation, and whether research/plan heartbeat refresh — which fires
   only at the orchestrator's own cycle-layer checkpoint, not continuously during the dispatch,
   per `task-lock.md`'s "Heartbeat Coverage Is Per-Caller" section — accumulates enough staleness
   within a single dispatch's duration to be a useful discriminator for a short-lived stall like
   instance 1). This research pass established the right site and the right exit-code/text-prefix
   fix but could not fully confirm, without a runnable trace, whether every real incident shape
   crosses `TASK_LOCK_STALE_MIN` before its own postflight runs; the plan should verify this with
   a concrete timeline rather than assume it.

**For the prevention half (b):**

5. Extend `lint-agent-contracts.sh` with a new check (next free letter) that greps every agent
   contract file (not just the 14 Check-H in-scope implementation agents — Check H's own scope is
   output-side bounded-wait bullet presence, a narrower problem) for the literal forbidden shape:
   `run_in_background`/Monitor-arming paired with "wait for...completion notification"-style
   phrasing, and FAILs on a match outside a curated exclusion list — mirroring Check H's exclusion
   mechanism (Finding 7) exactly, including its documented re-audit grep command.
6. Scope that new check's curated exclusion list to cover exactly the two files 376 already
   tracks (`lean-implementation-agent.md`, `lean-implementation-hard-agent.md`) until 376 lands;
   do not attempt to fix their content as part of 405 — that is 376's named territory
   (`file_scope` already declared) and re-fixing it here would race or duplicate that task's own
   planned edit.
7. Reuse `scripts/test-session-registry.sh`'s `write_session_fixture ... "$$" ...` pattern
   (Finding 8) for 405's own verification fixture rather than constructing a new one — it already
   proves the exact "live pid + old heartbeat timestamp, no real sleeping" shape the dispatch's
   verification requirement calls for, and reusing it keeps the new fixture consistent with the
   suite task-lock's own tests already maintain.

## Risks & Mitigations

- **Pid-liveness is a weak signal for in-flight monitoring, not just a differently-weighted one.**
  `task-lock.md`'s own "Keyed on `session_id`, never on `pid`" paragraph notes that two independent
  `/orchestrate` sessions inside one Claude Code process can share an identical ancestor pid
  (`pid_source: ancestor-claude`). For a stall-detection consumer, this means `pid-alive` may be
  almost always true for the duration of the whole orchestrator run regardless of whether the
  specific dispatched sub-session is actually productive — the heartbeat *staleness* is doing
  essentially all of the real discriminating work, and the "pid alive" half of `held-live`'s
  definition should not be oversold as independent confirmation in this context. Mitigation:
  state this explicitly in the task-lock.md documentation update (Recommendation 1) so a future
  reader does not mistake `held-live`'s pid check for a strong liveness proof in the monitoring
  context the way it legitimately is in the acquisition context.
- **A heartbeat-based signal may not fire for a short-lived stall.** Research/plan dispatches
  receive heartbeat refreshes only at the orchestrator's own cycle-layer checkpoint, not
  continuously during the dispatch itself (Finding per `task-lock.md`'s per-caller heartbeat
  section). A dispatch that ends its turn on a dead-end wait very soon after that checkpoint fired
  may not yet be past `TASK_LOCK_STALE_MIN` by the time postflight runs. This is Recommendation 4's
  open question, not resolved here; the plan should verify with a concrete timeline before
  committing to the exact consumer site, and should not assume the heartbeat signal alone closes
  every instance the task describes (it may close instance 2's shape more reliably than instance
  1's).
- **Sequencing collision with task 376.** Both 405 (prevention half) and 376 touch
  agent-contract-shaped text about the same antipattern. 376 is not a concurrent sibling of this
  dispatch (absent from the Territory block), but a lint check added by 405 that is unaware of
  376's planned edit could either falsely FAIL on files 376 has not yet fixed, or silently stop
  checking them via too broad an exclusion. Mitigation: Recommendation 6 above.

## Context Extension Recommendations

- **Topic**: `held-live` interpretation is context-dependent (acquisition vs. monitoring).
- **Gap**: `context/patterns/task-lock.md` documents `held-live`'s production and its one
  acquisition-side consumer in detail, but has no section stating that the same state must be
  read oppositely by an in-flight-monitoring consumer, nor a caveat that its pid-alive component
  is weak evidence in that context (see Risk above). This is exactly the gap this task's own goal
  (a) asks to be "decided and documented."
- **Recommendation**: Add the named subsection proposed in Recommendation 1 above as part of this
  task's own implementation, rather than filing it as a separate follow-up — it is small, and the
  implementation plan will need to settle the exact wording anyway to implement the new consumer
  correctly.

## Appendix

- Search queries / commands used: `grep -n "held-live\|held-stale\|held-fresh" scripts/*.sh`;
  `grep -rn "completion notification" agent-system/extensions/`; `jq` queries against
  `specs/state.json` for task 376's full description; `grep -n "Check H\|Check I" scripts/lint/lint-agent-contracts.sh`.
- Key files read in full or in relevant part: `context/patterns/task-lock.md`,
  `context/patterns/external-process-wait.md`, `scripts/task-lock.sh` (header/exit-code table),
  `scripts/orchestrate-cycle-plan.sh` (lock PROBE section), `scripts/orchestrate-cycle-postflight.sh`
  (`report_missing`/`stall_suspected` sections), `scripts/reconcile-task-status.sh`
  (`demote_stranded_status()`), `scripts/orchestrate-unwind-dispatch.sh` (Gate #6),
  `scripts/lint/lint-agent-contracts.sh` (Check H/I), `scripts/test-session-registry.sh` (fixture
  pattern), `agents/general-implementation-agent.md` (canonical wait-discipline prose),
  `specs/ROADMAP.md` (lines ~109-118, 449-453), `specs/state.json` (task 376's full description).
