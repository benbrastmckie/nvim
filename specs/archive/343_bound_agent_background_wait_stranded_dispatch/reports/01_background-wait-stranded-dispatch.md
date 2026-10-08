# Research Report: Task #343

**Task**: 343 - Bound agent background wait / stranded dispatch
**Started**: 2026-10-05
**Completed**: 2026-10-05
**Effort**: medium
**Dependencies**: None (deliberately un-sequenced file_scope overlap with tasks 273, 284, 299, 304, 335, 336, 337 — dispatch alone, per dispatch file)
**Sources/Inputs**: Codebase (agent-system/extensions/core source store), git history/blame, committed test suites
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Detection already exists and is production-grade.** `orchestrate-cycle-postflight.sh`
  already computes a `stall_suspected` field (added by commit `49f88cfc1`, *before* the
  task-341 incident this task's dispatch cites) that distinguishes "no outcome, no commit" (a
  genuine failure) from "no outcome, but a commit landed in the dispatch window" (an abandoned
  wrap-up — exactly this task's defect). It is a `git log --since` commit-count probe only, so it
  respects the Context Flatness Constraint, and it is purely advisory (never touches `verdict`,
  `persisted_status`, or `failed_tasks`). `orchestrate-recover-outcome.sh` separately implements
  a `.return-meta.json` `dispatch_seq`-mismatch/staleness check (`META_DISPATCH_SEQ_MISMATCH`,
  `META_STALE`) feeding `RECOVERY_DECLINED`/`HANDOFF_STALE_OR_ABSENT` defect records — the exact
  mechanism the dispatch names as a "candidate signal." **Scope item (3)'s question "can the
  orchestrator detect this at all" is already answered yes, mechanically, today.**
- **The detected signal is not consumed by the loop that is supposed to act on it.** The
  obligation — "on `stall_suspected = true`, re-prompt the same dispatch once" — is written only
  in `docs/architecture/orchestrate-state-machine.md`'s narrative. `skills/skill-orchestrate/SKILL.md`'s
  actual Move 3 bash block reads `dispatch_status`, `verdict`, `halt`, `infra_exempt_cycle`, and
  `report_missing` from `postflight_json` — it never reads `stall_suspected` at all. **This is the
  single most actionable, verifiable gap this research found: a fully computed, already-tested
  signal with no consumer.** It explains why the orchestrator had to notice and re-prompt by hand
  (ad hoc reasoning) in all three reproductions the dispatching message describes, rather than the
  loop doing it mechanically.
- **The prose agent-side contract already exists and has already failed empirically, twice, at
  different times.** `general-implementation-agent.md`'s "Local Long-Running Command Discipline"
  (added 2026-09-30, commit `fe19a30ca`) already states "MUST NOT end the turn on an unresolved
  local background wait" and "MUST ... read its output/log file and its writer's liveness
  DIRECTLY ... rather than waiting to be told." The task-341 incident (2026-10-05) violated this
  written rule two days after it was committed. The three further reproductions in this same
  batch — one of which had the prohibition "restated verbatim in its own dispatch prompt" and
  still parked a third time — prove prose MUST/MUST NOT text is not sufficient on its own; a
  mechanical constraint on *how* the wait is issued (single blocking call, no harness-notification
  dependency) is needed in addition, not instead.
- **A sibling agent file actively teaches the wrong pattern.** `lean-implementation-agent.md`
  (same core agent family, same "implementation agent" routing concept) instructs: run the build
  "via `Bash(run_in_background: true)` ... and wait for the harness's completion notification
  before recording the result." This is the textbook defect shape the dispatching incident
  describes, written as a MUST elsewhere in the same system. It is outside this task's declared
  `file_scope`, but it is direct evidence that the defect is not isolated to one agent file and
  that "the other implementation agents that would carry the same guidance" (per the dispatch's
  own Sites note) currently do not — several carry none at all, and one carries the opposite.
- **"IDENTICAL DISPATCH HALT" is a separate, already-fully-implemented concern, not this task's
  detection mechanism.** It is `orchestrate-cycle-plan.sh`'s Fix 2 convergence/churn guard: it
  halts a task when the *composed dispatch file's content* hashes identically to the previous
  cycle's, twice in a row — a cross-cycle non-convergence signal, unrelated to whether a single
  dispatched agent went idle mid-turn. It is fully implemented and green (the 1-vs-6 reference
  count the dispatching message observed is test-assertion density, not a missing implementation).
- **The `[COMPLETED WITH EXCLUSIONS]` vs `[PARTIAL]` question (scope item 2) is already answered
  by existing, general rules** — `status-markers.md`'s five-condition admission test, combined
  with the Local Long-Running Command Discipline's own existing fork ("if the wait genuinely
  cannot be resolved ... return `status: partial`"). No new rule is needed; what is missing is
  making the *fork itself* explicit at the deadline-reached moment (see Recommendations).

## Context & Scope

This is a research-only dispatch (task_type `meta`) investigating whether an implementation
agent may safely background a verification/gate process mid-dispatch, what it should do when a
bounded wait's deadline is reached with no result, and whether the orchestrator can mechanically
detect that a dispatch went idle without finishing its work. The explicit non-goal is the
runtime/performance of any particular gate (owned elsewhere, by durable anchor: the gate-runtime
work and the self-dispatch-time record). The explicit deliverable constraint is no task-number
references in any file written to the source store; this report lives under `specs/**`, where
task numbers are permitted, so that constraint does not bind this file itself, but is noted here
for the planning phase's benefit.

Four files are the declared `file_scope`, each independently shared with other non-terminal
tasks and not dependency-linked:
`agent-system/extensions/core/agents/general-implementation-agent.md`,
`agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`,
`agent-system/extensions/core/context/standards/postflight-tool-restrictions.md`,
`agent-system/extensions/core/docs/architecture/handoff-schema.md`.

A fifth file this research identified as load-bearing — `skills/skill-orchestrate/SKILL.md`
(Move 3) — is **not** in the declared `file_scope`. See Risks & Mitigations and Recommendations
below for why this matters to the planning phase.

## Findings

### Codebase Patterns

**1. The detection mechanism already exists, twice over, at two different layers.**

- `orchestrate-cycle-postflight.sh:1779-1810` computes `stall_suspected`: true only when
  `phase` is `plan`/`implement`, `have_outcome` is false (no recoverable `.return-meta.json`
  or handoff), and `git log --since=@<dispatch_start_ts> -- <task_dir>` finds at least one
  commit. This is a commit-count probe, never artifact prose — Context Flatness is preserved.
  It is advisory only: it is emitted in the final JSON (`stall_suspected: $stall_suspected`)
  alongside `report_missing`, and never changes `verdict`/`persisted_status`/`failed_tasks`.
  Introduced by commit `49f88cfc1` ("meta: detect an abandoned wrap-up mechanically instead of
  relying on prose", 2026-10-03), whose commit message describes this exact defect class,
  including the detail that it "was violated by two dispatches in one batch, one of which had
  the rule restated verbatim in its own prompt" — i.e. this is the *second* documented
  occurrence of the pattern the dispatching message's live evidence is the *third*.
- `orchestrate-recover-outcome.sh` separately implements a `.return-meta.json`
  freshness/identity check: `META_STALE` (mtime predates the dispatch window) and
  `META_DISPATCH_SEQ_MISMATCH` (the file's own `dispatch_seq` field does not match the
  orchestrator-minted value for this cycle — the exact "candidate signal" the dispatch names
  as cheapest/most direct). Both feed into `orchestrate-cycle-postflight.sh`'s
  `RECOVERY_DECLINED`/`HANDOFF_STALE_OR_ABSENT` defect-recording path
  (`scripts/orchestrate-cycle-postflight.sh:877-954`), which calls `system-defect-record.sh`
  and `issue-record.sh` with full attribution (`--dispatched-agent`, decline reason, direction
  of mismatch). This script is read-only by its own documented contract (it reads only
  `.return-meta.json`, never report/plan/summary/handoff content) and explicitly forbids
  calling any state-mutating script itself — the same boundary `postflight-tool-restrictions.md`
  states generally.

**2. The detected signal has no consumer in the actual loop.**

`docs/architecture/orchestrate-state-machine.md`'s "Abandoned Wrap-Up: Re-Prompt Once Before
Accepting a No-Outcome Verdict" section states the "Loop obligation": on `stall_suspected =
true`, re-prompt the same dispatch once, instructing it to finish in the foreground and write
its three closing artifacts. But `skills/skill-orchestrate/SKILL.md`'s Move 3 — the actual
executable procedure — only extracts `dispatch_status`, `persisted_status`, `verdict`, `halt`,
`infra_exempt_cycle`, and `report_missing` from `$postflight_json`
(`skills/skill-orchestrate/SKILL.md:190-198`). `stall_suspected` is never read there. The
documented obligation is real and sound, but nothing currently executes it mechanically; the
orchestrator only acted on it in the cited incidents because a reasoning agent happened to read
the stderr notice and improvise the re-prompt by hand.

**3. The agent-side prose contract already exists and is already proven insufficient by itself.**

`agents/general-implementation-agent.md`'s "Local Long-Running Command Discipline"
(`agents/general-implementation-agent.md:165-180`, added by commit `fe19a30ca`,
2026-09-30) already states, in MUST/MUST NOT form:
- MUST NOT end the turn on an unresolved local background wait.
- MUST, when a local command has been detached and its outcome is not yet known, read its
  output/log file and its writer's liveness DIRECTLY (`kill -0 "$pid"`) rather than waiting to
  be told.
- MUST, if the wait genuinely cannot be resolved within the dispatch, write a handoff and return
  `status: "partial"` — never a bare stop.

This text existed, committed, five days before the task-341 incident (2026-10-05) that this
task's dispatch describes as "MEASURED LIVE," and the incident violated it anyway. The three
further reproductions in the same orchestration batch that produced this dispatch — one of which
had the MUST NOT restated verbatim in its own dispatch prompt and still parked a third time —
are the second and third empirical demonstrations that a written prohibition, however explicit,
does not reliably prevent this failure mode. The mechanism that keeps failing is specifically:
the agent uses the harness's own asynchronous backgrounding (`Bash(run_in_background: true)`,
or arming a `Monitor`), which hands control back to the agent immediately but defers the actual
result to a later, separately-delivered notification — and the agent then chooses to end its
turn "waiting for" that notification instead of continuing in the same turn. Because a dispatched
subagent that ends its turn terminates (`dispatch-report-not-termination.md`), the eventual
notification either arrives at nothing, or forces an operator/orchestrator to notice and resume
by hand.

**4. `bounded-build-waiter.md`'s own canonical idiom structurally avoids this failure, but
nothing in the agent contract *mandates* using exactly that idiom.**

`context/patterns/bounded-build-waiter.md`'s "Canonical Idiom" is a single, foreground-blocking
Bash call:
```bash
cmd >log 2>&1 & pid=$!
timeout 3000 bash -c 'while kill -0 "$1" 2>/dev/null; do sleep 10; done' _ "$pid"
```
This never uses the harness's `run_in_background` tool parameter at all — the `&` is ordinary
shell backgrounding *inside one blocking tool call* that does not return control to the agent
until the wait is over (or the outer `timeout` fires). There is no notification to wait for,
and therefore no point at which the agent could choose to end its turn mid-wait. The file
explicitly defers the "MUST NOT end the turn" prohibition to the agent-contract layer ("this
file states only the waiter model both symptoms are missing" — `bounded-build-waiter.md`'s "Two
Symptoms, One Missing Affordance" section) — i.e. it already anticipated that the waiter model
alone would not be self-enforcing without a contract-layer mandate, and current repo state shows
that anticipation was correct: the contract layer states the *outcome* ("must not end turn," "must
check directly") but not the *mechanism* (use the single-call idiom above, and specifically do not
reach for `Bash(run_in_background: true)` / `Monitor` for this purpose at all).

**5. A sibling agent file instructs the opposite of the general contract, for the same job.**

`agent-system/extensions/lean/agents/lean-implementation-agent.md:326-330` (Final Verification
Stage, "Verify build passes"):
> Run this via `Bash(run_in_background: true)` — a foreground call can livelock past the tool's
> own timeout on a long build. ... and wait for the harness's completion notification before
> recording the result.

This is, verbatim, the defect-producing pattern: detach via the harness's async mechanism, then
wait for its notification rather than blocking on a captured PID inside one call. It sits beside
a *correct* reference to `bounded-build-waiter.md` two sentences later ("Any waiter armed on this
build follows `context/patterns/bounded-build-waiter.md`"), so the file is internally
inconsistent — it names the correct waiter pattern and then instructs the harness-notification
pattern the waiter pattern exists to avoid. This file is outside the declared `file_scope` for
this task and this research does not recommend editing it here, but it is material evidence that
(a) the defect is not unique to `general-implementation-agent.md`'s wording, and (b) "the other
implementation agents that would carry the same guidance" named in the dispatch's Sites section
is not a hypothetical — it names a real, currently-wrong instance.

**6. Most other implementation agents carry no guidance on this at all.**
`python-implementation-agent.md`, `web-implementation-agent.md`, `cslib-implementation-agent.md`,
`pr-review-implementation-agent.md`, `latex-implementation-agent.md`, `typst-implementation-agent.md`,
`rust-implementation-agent.md`, `z3-implementation-agent.md`, `email-implementation-agent.md`,
`neovim-implementation-agent.md`, and `nix-implementation-agent.md` contain zero mentions of
background/notification/`kill -0`/`run_in_background` discipline. Only
`general-implementation-agent.md` and `general-research-agent.md` (core) and
`lean-implementation-agent.md`/`lean-implementation-hard-agent.md` (lean) carry any of this
discipline today; `books-implementation-agent.md` has one incidental pointer. Any of these other
agents backgrounding a verification step today would do so with no contract at all governing it.

**7. "IDENTICAL DISPATCH HALT" is a verified separate concern.**
`orchestrate-cycle-plan.sh`'s Fix 2 (`identical_dispatch_streak`/`identical_dispatch_halted`,
lines ~2491-2579) detects when the *composed dispatch file content* for a task hashes
byte-identically to the previous cycle's dispatch for that same task, twice in a row, and halts
further dispatch of that task for the rest of the run. This answers "the orchestrator keeps
re-issuing the same instructions and nothing is changing" (a convergence/churn signal across
*cycles*), which is orthogonal to "a single dispatched agent went idle mid-turn without
finishing" (a liveness signal within *one* dispatch). The mechanism is fully implemented,
exercised by Groups 27-29 in `scripts/tests/test-orchestrate-cycle-plan.sh`, and currently green
in the working tree (the literal string `IDENTICAL DISPATCH HALT` appears once at its emission
site in `orchestrate-cycle-plan.sh:2561` and six times across the test file's several exercised
scenarios/arms — a 1:6 implementation:assertion ratio, not an unimplemented surface).

### External Resources

Not applicable — this is a pure codebase/contract-archaeology research task; no external
documentation was consulted.

## Decisions

- **Scope item (1) — backgrounding stays permitted, but only via the single-call waiter idiom,
  never via the harness's async `run_in_background`/`Monitor` mechanism for a local verification
  gate.** `bounded-build-waiter.md`'s canonical idiom already structurally prevents the stranding
  failure because it never surfaces a "wait for a notification" choice point to the agent. The
  defect is not "backgrounding is unsafe" — it is "the harness-async detach-then-notify path is
  unsafe for a dispatched subagent, because nothing re-enters a terminated turn." Foregoing
  backgrounding entirely (always run in the foreground, accept a hard timeout) remains available
  per `bounded-build-waiter.md`'s own stated preference ("prefer the simpler foreground form ...
  reach for the detach-plus-waiter shape only when it does not [fit]") and is the right default
  for anything that plausibly fits the tool's own ceiling.
- **Scope item (2) — reaching a bounded-wait deadline with no result is not, by itself, grounds
  for `[COMPLETED WITH EXCLUSIONS]`.** `status-markers.md`'s five-condition admission test
  (decision not abandonment, tightly scoped, documented reason, evidenced, no residual work)
  governs this exactly as it governs every other exclusion. A deadline reached while the writer
  (`kill -0 "$pid"`) is *still alive* fails condition 5 (a future dispatch would still need the
  result) — that case is `[PARTIAL]` with a handoff, per the existing MUST in
  `general-implementation-agent.md:176-180`. A deadline reached where direct inspection
  (`kill -0` fails, log/PID checked) reveals the writer already finished with a conclusive
  pass/fail is not an exclusion case at all — the result is now known and is used normally
  (`[COMPLETED]`, or the ordinary failure-handling path). `[COMPLETED WITH EXCLUSIONS]` is
  reserved for the narrower case where a *specific, enumerated* verification requirement is
  deliberately and evidentially excluded (e.g. "this gate is not applicable to this phase's
  changes," evidenced) — not as a generic fallback for "I hit my deadline and still don't know."
  No new status-marker rule is required; what is missing is stating this fork explicitly at the
  point `general-implementation-agent.md`'s existing deadline-handling text already lives, so a
  future reader does not have to re-derive it from two separate documents (see Recommendations).
- **Scope item (3) — a cheap post-return staleness check already belongs in, and already exists
  in, `orchestrate-cycle-postflight.sh`, respecting both named constraints.** `stall_suspected`
  (git-commit-count probe) and `orchestrate-recover-outcome.sh`'s `dispatch_seq`/mtime checks
  are both read-only/count-only, both already pass the Context Flatness Constraint (no
  report/plan/summary prose is ever read), and both already stay inside
  `postflight-tool-restrictions.md`'s allowed-operations list. The open question this research
  surfaces is not "should such a check exist" (it already does) but "does anything act on it" —
  and the answer found here is no: `skill-orchestrate/SKILL.md`'s Move 3 never reads
  `stall_suspected`. The planning phase should treat wiring that consumption as the primary
  actionable item for scope item (3), not authoring a new detection mechanism.
- **"IDENTICAL DISPATCH HALT" is unrelated to this task** and should not be conflated with or
  substituted for the `stall_suspected`/`dispatch_seq`-staleness mechanisms above in whatever the
  plan produces. State this relationship explicitly in the plan so a future reader does not
  merge the two convergence/liveness concerns.

## Recommendations

1. **Wire `stall_suspected` into `skill-orchestrate/SKILL.md`'s Move 3.** This is the highest-
   leverage fix found: the detection already exists, is already tested, and is already
   documented as an obligation in `orchestrate-state-machine.md` — only the consuming loop step
   is missing. Reading the field and performing the documented one-time re-prompt (foreground
   re-run, bounded timeout, close every phase, write all three artifacts) converts an already-
   computed advisory signal into the mechanical recovery the live incidents currently require a
   human or an improvising orchestrator-agent to perform by hand. Because `SKILL.md` is not in
   this task's declared `file_scope`, the planning phase should explicitly decide whether to
   request a scope amendment (recommended, given how directly this closes scope item 3) or to
   hand this specific finding to whichever task already owns `skill-orchestrate/SKILL.md`.
2. **Strengthen `general-implementation-agent.md`'s Local Long-Running Command Discipline from an
   outcome-only contract ("must not end turn," "must check directly") to a mechanism-mandating
   one**: require the single-call idiom from `bounded-build-waiter.md` verbatim, and add an
   explicit MUST NOT against using `Bash(run_in_background: true)` or arming a `Monitor` for a
   local verification/gate process at all (mirroring the existing CI-case MUST NOT at
   `general-implementation-agent.md:162`, which currently only covers the remote/CI case). This
   directly targets the mechanism that produced three reproductions in one batch despite the
   existing outcome-only prose.
3. **State the `[COMPLETED WITH EXCLUSIONS]` vs `[PARTIAL]` fork explicitly at the point the
   deadline is reached**, inside the same Local Long-Running Command Discipline section: writer
   still alive at deadline → `[PARTIAL]` + handoff (already stated); writer dead with a
   conclusive result → use that result normally, no exclusion needed; a specific, evidenced,
   enumerated requirement excluded on its own merits → `[COMPLETED WITH EXCLUSIONS]` per
   `status-markers.md`'s five-condition test, cross-referenced rather than restated.
4. **Flag, for a follow-up (not this task)**: `lean-implementation-agent.md`'s internally
   inconsistent instruction (names `bounded-build-waiter.md` and then instructs the opposite
   pattern two sentences later) and the complete absence of this discipline from ten other
   implementation agents. Both are outside this task's declared `file_scope` and should not be
   edited under this dispatch, but both are durable, verifiable findings a future task can act on
   without re-deriving them.
5. **Keep the "IDENTICAL DISPATCH HALT" / `stall_suspected` distinction explicit in the plan's
   own prose**, since both are near-synonymous-sounding "the orchestrator noticed something was
   wrong" mechanisms that a future reader could otherwise conflate.

## Risks & Mitigations

- **Risk**: The highest-leverage recommendation (wiring `stall_suspected` into `SKILL.md` Move 3)
  touches a file outside this task's declared `file_scope`, which was deliberately left
  un-sequenced against several other non-terminal tasks that *do* declare
  `orchestrate-cycle-postflight.sh`/`handoff-schema.md`/`general-implementation-agent.md`.
  **Mitigation**: the plan should state this as an explicit scope decision (amend `file_scope` to
  add `skills/skill-orchestrate/SKILL.md`, or defer the Move 3 wiring to a named follow-up) rather
  than silently expanding scope or silently dropping the highest-leverage fix.
- **Risk**: strengthening the agent contract (Recommendation 2) only changes what is *written*;
  the three reproductions in this same batch happened despite an existing, explicit, even
  verbatim-restated prohibition. A fourth occurrence after this task's fix would not be surprising
  on its own and should not be read as proof the fix was wrong — it would be evidence that prose
  strengthening alone, absent the Move 3 wiring (Recommendation 1), is still an incomplete fix.
  **Mitigation**: treat Recommendations 1 and 2 as a pair, not alternatives — the contract
  reduces how often the strand happens; the loop wiring bounds the cost when it happens anyway.
- **Risk**: `stall_suspected`'s trigger condition requires at least one commit landing inside the
  dispatch window. A stall that occurs before any phase's first commit (e.g. during phase 1,
  before its own commit) would not set `stall_suspected=true` and would fall through to the
  ordinary no-commit/no-outcome "genuine failure" path, discarding nothing (there is nothing yet
  to discard) but also not benefiting from the one-re-prompt recovery. **Mitigation**: none
  required for correctness — a dispatch with zero commits genuinely has no committed work at
  stake — but the planning phase should note this boundary rather than assume `stall_suspected`
  covers every stall shape.

## Context Extension Recommendations

- **Topic**: cross-agent consistency of the background-wait discipline.
- **Gap**: `context/patterns/bounded-build-waiter.md` and `context/patterns/external-process-wait.md`
  are canonical and well-written, but only 3 of 14 implementation-agent files actually reference
  either, and one of the three (`lean-implementation-agent.md`) references the correct pattern
  and then instructs the opposite one two sentences later.
- **Recommendation**: a future task (not this one) should either (a) extend the core discipline
  text into a single shared, literally-included snippet every implementation agent sources rather
  than each restating it, or (b) audit and correct every extension implementation agent's own
  copy. This research report is sufficient grounding for that follow-up to skip re-discovery.

## Appendix

### Search queries / investigation steps used
- `grep -n -i "background\|notification\|wait-loop\|parked\|parking\|bounded.wait\|monitor" agents/general-implementation-agent.md`
- `git log -S "end the turn on an unresolved local background wait"` / `-S "stall_suspected"` on
  `agents/general-implementation-agent.md` and `scripts/orchestrate-cycle-postflight.sh`
  respectively, to date-order the existing contract against the cited incident
- `grep -rn "IDENTICAL DISPATCH HALT\|identical.dispatch"` across `orchestrate-cycle-plan.sh` and
  its test file, plus a literal-string count comparison, to resolve the dispatch's explicit
  "verify whether this is the same mechanism" question
- `grep -n "stall_suspected" skills/skill-orchestrate/SKILL.md` (zero hits) vs. its presence in
  `orchestrate-cycle-postflight.sh` and `docs/architecture/orchestrate-state-machine.md`, to
  locate the consumption gap
- Read in full: `context/patterns/external-process-wait.md`, `context/patterns/bounded-build-waiter.md`,
  `context/patterns/anti-stop-patterns.md`, `context/patterns/dispatch-report-not-termination.md`,
  `context/standards/status-markers.md` (`[COMPLETED WITH EXCLUSIONS]` section),
  `context/standards/postflight-tool-restrictions.md`, relevant sections of
  `docs/architecture/handoff-schema.md` and `docs/architecture/orchestrate-state-machine.md`,
  `scripts/orchestrate-recover-outcome.sh` (full header/contract comment)
- Cross-checked implementation-agent file coverage across all loaded extensions
  (`core`, `lean`, `nix`, `nvim`, `email`, `python`, `web`, `cslib`, `latex`, `typst`, `rust`,
  `z3`, `books`) via `grep -c -i "background\|notification\|kill -0\|run_in_background"`

### References
- `agent-system/extensions/core/agents/general-implementation-agent.md:145-180`
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh:1779-1810` (`stall_suspected`)
- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` (full file header)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md:172-240` (Move 3)
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` ("Abandoned
  Wrap-Up: Re-Prompt Once Before Accepting a No-Outcome Verdict")
- `agent-system/extensions/core/docs/architecture/handoff-schema.md:179-194` (`dispatch_seq`)
- `agent-system/extensions/core/context/standards/status-markers.md:256-321`
  (`[COMPLETED WITH EXCLUSIONS]`)
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md`
- `agent-system/extensions/core/context/patterns/external-process-wait.md`
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh:2491-2579` (Fix 2,
  identical-dispatch halt)
- `agent-system/extensions/lean/agents/lean-implementation-agent.md:322-340` (conflicting
  instruction, outside this task's `file_scope`)
- Commits: `fe19a30ca` (2026-09-30, Local Long-Running Command Discipline authored),
  `49f88cfc1` (2026-10-03, `stall_suspected` authored)
