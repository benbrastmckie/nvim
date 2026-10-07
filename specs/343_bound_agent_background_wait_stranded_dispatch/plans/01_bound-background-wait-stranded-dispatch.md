# Implementation Plan: Task #343

- **Task**: 343 - Bound agent background wait / stranded dispatch
- **Status**: [IMPLEMENTING]
- **Effort**: 5 hours
- **Dependencies**: 337 (declared in state.json; no edge was created for any file_scope overlap — see Scope Decision below)
- **Research Inputs**: specs/343_bound_agent_background_wait_stranded_dispatch/reports/01_background-wait-stranded-dispatch.md
- **Artifacts**: plans/01_bound-background-wait-stranded-dispatch.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The defect is an implementation agent that detaches a verification process through the harness's
own asynchronous mechanism, then ends its turn waiting for a completion notification that nothing
guarantees will arrive — stranding the dispatch with committed work on disk and none of its three
closing artifacts written. Research established that both halves of the fix already exist in
part: the agent-side prohibition is written (and has been violated three times, once with the
text restated verbatim in the dispatch prompt), and the orchestrator-side detection is fully
implemented and tested in `orchestrate-cycle-postflight.sh` as the advisory `stall_suspected`
field. What is missing is a *mechanism* mandate on the agent side (the existing text states only
the outcome, not how to issue the wait) and a *consumer* on the loop side (`stall_suspected` is
computed, emitted, tested, and documented as a loop obligation, but `skill-orchestrate/SKILL.md`
never reads it). This plan rules on all three scope items and lands both halves, plus the
explicit `[COMPLETED WITH EXCLUSIONS]`-vs-`[PARTIAL]` fork at the deadline-reached moment, and a
grep-based regression test so a computed-but-dead signal cannot recur silently.

All edits target the source store (`agent-system/extensions/**`), never `.claude/**`, per
`rules/source-store-deploy-boundary.md`. No file written into the source store may cite a task
number (`rules/no-task-references-in-deliverables.md`); the related work named below is referred
to by durable anchor only.

### Research Integration

The research report's seven findings drive this plan directly:

- **Detection already exists** (`orchestrate-cycle-postflight.sh:1779-1810`, commit `49f88cfc1`),
  is a `git log --since` commit-count probe only — so it already satisfies the Context Flatness
  Constraint — and is already exercised by four assertions (S1-S4) in
  `scripts/tests/test-orchestrate-cycle-postflight.sh`. **Scope item (3)'s question "can the
  orchestrator detect this at all" is therefore already answered yes.** No new detection
  mechanism is authored here; Phase 4 records the ruling and its boundary instead.
- **The signal has no consumer.** `skills/skill-orchestrate/SKILL.md` Move 3 extracts
  `dispatch_status`, `persisted_status`, `verdict`, `halt`, `infra_exempt_cycle`, and
  `report_missing` from the postflight JSON and never reads `stall_suspected` (verified: zero
  hits for the string in that file). The "Loop obligation" written in
  `docs/architecture/orchestrate-state-machine.md` is real and sound but nothing executes it.
  Phase 3 wires it.
- **The agent contract is outcome-only.** `agents/general-implementation-agent.md:165-180` already
  says "MUST NOT end the turn on an unresolved local background wait" and "MUST ... read its
  output/log file and its writer's liveness DIRECTLY." That text predates the measured incident
  by five days and did not prevent it, nor the two further reproductions in the same batch. The
  missing half is the mechanism: `context/patterns/bounded-build-waiter.md`'s canonical idiom is
  a *single foreground-blocking Bash call* that never surfaces a notification-wait choice point,
  and nothing currently mandates using exactly that shape or forbids reaching for
  `Bash(run_in_background: true)` / a `Monitor` for a local gate. Phase 1 closes that.
- **`[COMPLETED WITH EXCLUSIONS]` needs no new rule**, only an explicit fork stated where the
  deadline is actually reached. `status-markers.md`'s five-condition admission test already
  governs; a deadline reached with the writer still alive fails condition 5. Phase 2 states the
  fork and records the non-admission at the exclusion contract's own home.
- **IDENTICAL DISPATCH HALT is a separate, fully implemented concern** —
  `orchestrate-cycle-plan.sh`'s cross-cycle convergence/churn guard, keyed on the composed
  dispatch file's content hash, orthogonal to within-dispatch liveness. Phase 4 states this
  distinction in prose so a future reader cannot conflate the two.
- **Two findings are deliberately NOT acted on here** and are carried forward as recorded
  observations only (Non-Goals below): `lean-implementation-agent.md` instructs the
  defect-producing pattern verbatim two sentences after correctly citing
  `bounded-build-waiter.md`, and ten other implementation agents carry no background-wait
  discipline at all.

### Prior Plan Reference

No prior plan. This is round 1 for this task.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context and no roadmap flag was set,
so no roadmap phases are included and no roadmap item is claimed.

## Goals & Non-Goals

**Goals**:

- Rule scope item (1): backgrounding a local verification/gate process stays **permitted**, but
  only through `bounded-build-waiter.md`'s single-call idiom; the harness-asynchronous
  detach-then-await-notification path is forbidden outright for a local gate. Record the mandate
  as a mechanism, not only an outcome.
- Rule scope item (2): a bounded-wait deadline reached with no result is **not**, by itself,
  grounds for `[COMPLETED WITH EXCLUSIONS]`. State the three-way fork at the point the deadline
  is reached, and record the non-admission where the exclusion contract lives.
- Rule scope item (3): a cheap post-return staleness check **does** belong in
  `orchestrate-cycle-postflight.sh`, already exists there, and respects both named constraints.
  Close the real gap — give the already-computed signal a consumer in the loop — and record the
  ruling, the signal's boundary, and the postflight/loop-level division of labour.
- Make the fix self-guarding: a regression test that fails if the signal loses its consumer again.

**Non-Goals**:

- Making any gate faster, or dropping any gate from the `full` tier. The gate-runtime question
  belongs to the gate-runtime work that already owns it; this task is about the parking failure
  mode being reachable at all. An instantaneous process that failed to notify produces the
  identical stall.
- Editing `agent-system/extensions/lean/agents/lean-implementation-agent.md`, or any of the ten
  implementation agents that carry no background-wait discipline. Both are durable, verified
  findings recorded in the research report and are left for a follow-up that can act on them
  without re-deriving them.
- Widening `stall_suspected`'s trigger condition. See Phase 4's ruling: the commit-gated
  conjunction is what gives the field its discrimination, and an OR against a stale
  `dispatch_seq` would destroy it.
- Authoring any new detection mechanism. Detection exists; consumption does not.

### Scope Decision: Three Files Outside the Declared `file_scope`

The dispatch declares four `file_scope` entries. This plan touches three further files, and the
expansion is deliberate and recorded here rather than silent:

| File | Why it is unavoidable |
|------|----------------------|
| `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` | The only place the `stall_suspected` consumer can live. Scope item (3) cannot be closed actionably without it — ruling "detection belongs in postflight" while leaving the signal dead would be a hollow deliverable. |
| `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` | Owns the `mt_state_file` field reference and the "Loop obligation" narrative. Phase 3 introduces three new fields; leaving them undocumented there would create exactly the documentation/implementation split that produced this defect. |
| `agent-system/extensions/core/context/standards/status-markers.md` | Scope item (2) says in its own words "Record the ruling where the exclusion contract lives." That is this file's `[COMPLETED WITH EXCLUSIONS]` section. |

**Overlap consequence.** `scripts/orchestrate-batch-admit.sh` scans every non-terminal task in
`specs/state.json`, so these additions change the collision surface. Verified at plan time:
`skill-orchestrate/SKILL.md` is additionally declared by four non-terminal tasks (all currently
`not_started`), `orchestrate-state-machine.md` by two (both `not_started`), and
`status-markers.md` by none. No dependency edge is created for any of them, matching the
dispatch's own standing decision for the original four; the consequence is only that this task
should be dispatched alone or alongside tasks whose `file_scope` excludes these seven paths.

**Mechanism.** No manual `specs/state.json` edit is needed. `plan-file-scope-harvest.sh` harvests
the deduplicated union of every phase's `**Files to modify**` field and the postflight writes it
back additively via `update-task-status.sh --file-scope-add`, so naming each file in its phase
below is what amends `file_scope`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Prose strengthening alone fails a fourth time — the existing text already failed three times, once restated verbatim | M | H | Treat Phases 1 and 3 as a pair, never alternatives: the contract reduces how often the strand happens, the loop wiring bounds its cost when it happens anyway. A fourth occurrence after Phase 1 alone would be evidence the pair is incomplete, not that Phase 1 was wrong. |
| The re-prompt is sited inside Move 3 and violates the Postflight Boundary, which limits the per-dispatch postflight to reading the handoff, driving the transition, and cleanup | H | M | Phase 3 sites the re-prompt at the loop-level branch move, beside the existing batched `AskUserQuestion` relay that already runs "after every task's Move 3 has run this cycle" — the exact architectural precedent. Move 3 only reads the field and accumulates; it issues no Agent call. Move 2's "never interleaved with dispatch" rule stays intact. |
| A re-prompt loop: a stalled dispatch that stalls again on re-prompt re-prompts forever | H | M | `stall_reprompted[]` is keyed on `{task, dispatch_seq}`, so exactly one re-prompt is ever spent per dispatch, per the state machine's existing "Only one re-prompt is owed" rule. A second no-outcome return on the same dispatch takes the ordinary `failed_tasks` path. |
| A concurrent sibling edits one of the seven files mid-phase (three siblings are dispatched this same cycle on this same tree) | M | M | Re-read every file immediately before editing it; stage and commit only this task's own hunks with an explicit file list, never a directory or glob pathspec; never run `git-snapshot.sh` in its reverting default mode. Treat a failure in a file outside this task's scope as possibly a sibling's in-flight edit and report it rather than "fixing" it. |
| `lint-postflight-boundary.sh`'s scanned region starts at `### Move 3: Postflight` and runs to the next `## MUST NOT`, so Move 4 additions are inside it | M | L | Verified at plan time: that lint flags only build commands, `grep` on source files, and MCP tool references. An Agent call and `jq` state writes are not in any of its three patterns. Phase 5 runs it to confirm. |
| Widening `stall_suspected` to catch a stall that strands before its first commit | M | L | Explicitly ruled out in Phase 4. A stale `dispatch_seq` cannot distinguish a stall from a dead dispatch; ORing it in would destroy the very discrimination the field exists for. The boundary is recorded instead: a dispatch with zero commits has no committed work at stake, so it correctly falls through to the genuine-failure path. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2, 4 | 1 (for 2), 3 (for 4) |
| 3 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel. Phases 1 and 3 touch disjoint files. Phase 2
edits the same file region as Phase 1 and must follow it. Phase 4 documents the fields Phase 3
introduces and must follow it.

---

### Phase 1: Mandate the wait mechanism, not only its outcome [COMPLETED]

**Goal**: Rule scope item (1) in the agent contract. Backgrounding a local verification/gate
process stays permitted, but only via `bounded-build-waiter.md`'s single foreground-blocking
call; the harness-asynchronous detach-then-await-notification path is forbidden for a local gate,
mirroring the MUST NOT that already covers the remote/CI case directly above it.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/agents/general-implementation-agent.md` lines 145-185
      in full immediately before editing (a sibling task declares this same file). *(completed)*
- [x] In the **Local Long-Running Command Discipline** subsection, add a **MUST** requiring the
      canonical idiom from `context/patterns/bounded-build-waiter.md` verbatim — a captured
      `pid=$!`, a `kill -0 "$pid"` liveness loop, an outer `timeout N`, all inside **one** Bash
      call that does not return control until the wait resolves — and state plainly why that
      shape is load-bearing: it never surfaces a "wait for a notification" choice point, so there
      is no point at which the turn could end mid-wait. *(completed)*
- [x] Add a **MUST NOT** against using `Bash(run_in_background: true)` or arming a `Monitor` for a
      local verification, gate, build, or test process at all. Word it as a sibling of the
      existing remote/CI MUST NOT ("Use `run_in_background` or arm a Monitor to watch a CI/remote
      wait from within this dispatched subagent") so the two cases read as one rule with two
      instances, not two unrelated prohibitions. *(completed)*
- [x] Add a **MUST** preferring the plain foreground form `timeout N cmd` whenever the command
      plausibly fits the Bash tool's own ceiling, reaching for detach-plus-waiter only when it
      does not — `bounded-build-waiter.md`'s own stated preference, restated here because this is
      where the choice is actually made. *(completed)*
- [x] State the ruling explicitly in one sentence so a future reader does not re-derive it: the
      defect is not that backgrounding is unsafe, it is that the harness-async detach-then-notify
      path is unsafe for a dispatched subagent, because nothing re-enters a terminated turn
      (cross-reference `context/patterns/dispatch-report-not-termination.md`). *(completed)*
- [x] Verify no task number appears in any added text. *(completed: check-task-references.sh
      reports 0 occurrences)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Files to modify**:

- `agent-system/extensions/core/agents/general-implementation-agent.md` - strengthen the Local
  Long-Running Command Discipline subsection from outcome-only to mechanism-mandating: add the
  canonical-idiom MUST, the local-case `run_in_background`/`Monitor` MUST NOT, the
  foreground-preference MUST, and the one-sentence ruling.

**Verification**:

- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` passes for this file.
- `grep -c 'run_in_background' agent-system/extensions/core/agents/general-implementation-agent.md`
  returns at least 2 (the pre-existing CI MUST NOT plus the new local-case one).
- `grep -n 'kill -0' agent-system/extensions/core/agents/general-implementation-agent.md` shows
  the captured-PID liveness test is now named in the agent contract, not only referenced by
  pointer.
- `bash .claude/scripts/check-task-references.sh` reports no new occurrence.
- Diff read-through confirming every changed hunk lies inside the intended subsection.

---

### Phase 2: State the deadline fork, and record the non-admission where the exclusion contract lives [COMPLETED]

**Goal**: Rule scope item (2). Reaching a bounded-wait deadline with no result is not by itself
grounds for `[COMPLETED WITH EXCLUSIONS]`. State the three-way fork at the moment the deadline is
reached, and record the non-admission in the exclusion contract's own home so a future reader
need not reconstruct it from two separate documents.

**Tasks**:

- [x] Re-read the Local Long-Running Command Discipline subsection as Phase 1 left it. *(completed)*
- [x] Add an explicit three-branch fork at the deadline-reached point in
      `general-implementation-agent.md`:
      1. **Writer still alive** at the deadline (`kill -0 "$pid"` succeeds) — the result a future
         dispatch still needs is genuinely outstanding, so condition 5 of the five-condition
         admission test fails. Close the phase `[PARTIAL]`, write the handoff with the concrete
         foreground resume command, return `status: "partial"`. This restates the existing MUST
         rather than replacing it.
      2. **Writer dead with a conclusive result** (`kill -0` fails; log and exit status read
         directly) — this is not an exclusion case at all. The result is now known; use it
         normally, taking `[COMPLETED]` or the ordinary failure-handling path.
      3. **A specific, enumerated verification requirement excluded on its own merits** (for
         example a gate provably not applicable to this phase's changes, with evidence) —
         `[COMPLETED WITH EXCLUSIONS]` plus a full `#### Reasoned Exclusions` record, admitted by
         `context/standards/status-markers.md`'s five-condition test. Cross-reference that test;
         do not restate it. *(completed)*
- [x] Re-read `agent-system/extensions/core/context/standards/status-markers.md`'s
      `#### [COMPLETED WITH EXCLUSIONS]` section (verified at plan time: no other non-terminal
      task declares this file). *(completed)*
- [x] Add a short named non-admission note to that section: a bounded-wait deadline reached with
      no result is not an admissible exclusion on its own — it fails condition 5 while the writer
      is still alive, and needs no exclusion once the writer is dead and the result is readable.
      Point at the agent contract's fork for the operational detail rather than duplicating it,
      so the two files cannot drift. *(completed)*
- [x] Verify no task number appears in either file's added text, and that the measured incident is
      referred to by durable anchor (the agent contract, the waiter pattern) rather than by number.
      *(completed: check-task-references.sh reports 0 occurrences; both files cite the agent
      contract and bounded-build-waiter.md by durable anchor only)*

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Files to modify**:

- `agent-system/extensions/core/agents/general-implementation-agent.md` - add the explicit
  three-branch deadline fork (`[PARTIAL]` / use-the-result / `[COMPLETED WITH EXCLUSIONS]`) at the
  point the deadline is reached.
- `agent-system/extensions/core/context/standards/status-markers.md` - add a named non-admission
  note to the `[COMPLETED WITH EXCLUSIONS]` section: a bounded-wait deadline reached with no
  result is not an admissible exclusion by itself, with a pointer to the agent contract's fork.

**Verification**:

- `grep -n 'COMPLETED WITH EXCLUSIONS' agent-system/extensions/core/agents/general-implementation-agent.md`
  shows the marker named at the deadline fork, and the surrounding text cross-references
  `status-markers.md` rather than restating the five conditions.
- `grep -n -A6 'bounded-wait deadline' agent-system/extensions/core/context/standards/status-markers.md`
  shows the non-admission note inside the `[COMPLETED WITH EXCLUSIONS]` section.
- The marker text added to `status-markers.md` introduces no new phase-heading marker string, so
  `update-task-status.sh`'s `count_plan_phases()` `[A-Z][A-Z ]*` character class is unaffected —
  confirm by reading the diff, since this file documents that constraint.
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` still passes.
- `bash .claude/scripts/check-task-references.sh` reports no new occurrence.

---

### Phase 3: Give `stall_suspected` a consumer in the loop [COMPLETED]

**Goal**: Close the real gap behind scope item (3). The signal is computed, emitted in both output
arms, tested by four assertions, and documented as a loop obligation — and nothing reads it. Wire
Move 3 to read it and Move 4's branch move to act on it exactly once per dispatch, without
crossing the Postflight Boundary.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` Moves 3 and 4 in
      full immediately before editing (four non-terminal tasks declare this file). *(completed)*
- [x] In Move 3's per-row bash block, extract the field alongside its existing siblings:
      `stall_suspected=$(echo "$postflight_json" | jq -r '.stall_suspected // false')`. *(completed)*
- [x] Guard the existing `failed_tasks` append so a suspected stall does not accept the verdict on
      its first occurrence. The current `elif [ "$verdict" = "failed" ] && [ "$halt" != "true" ]`
      arm appends unconditionally; add the condition that `stall_suspected` is false **or** a
      re-prompt has already been spent on this task's current `dispatch_seq`. Leave the
      `infra_exempt_cycle` arm untouched — it answers a different question. *(completed)*
- [x] On a first-occurrence suspected stall, accumulate rather than act. Append one entry to
      `pending_stall_reprompt[]` in `mt_state_file`, shaped
      `{"task": <int>, "dispatch_seq": <int>, "phase": <string>, "cycle": <int>}`, following the
      exact `jq ... > tmp && mv` shape the adjacent `pending_ask_user` accumulation already uses.
      Also append one entry to `stall_ledger[]` — an append-only observation log that mirrors
      `defer_ledger`'s MUST NOT: never read by any eligibility, admission, all-terminal, circuit
      breaker, or convergence check, and never merged into `defer_ledger`.
      *(deviation: altered — the entry additionally carries an `agent` field, captured from Move
      3's existing per-row `agent` loop variable, since Move 4's relay task below requires
      re-dispatching to "the same subagent_type that dispatch used" and no other field carries
      that value; no new state field or read was introduced to get it)*
- [x] Add a one-line `[orchestrate]` stderr notice at the accumulation site so the suspected stall
      is never a silent no-op, matching the style of the existing `detected_defects` queue notice.
      *(completed)*
- [x] Issue **no** Agent call inside Move 3. Record in the surrounding prose that this is
      deliberate: Move 2's "never interleaved with dispatch" rule and the Postflight Boundary's
      enumeration both forbid it, which is why the relay is sited at the branch move instead.
      *(completed)*
- [x] In Move 4, add a **batched stall re-prompt relay** directly beside the existing batched
      `AskUserQuestion` relay, carrying the same "after every task's Move 3 has run this cycle"
      siting. For each `pending_stall_reprompt[]` entry: issue exactly one Agent call to the same
      `subagent_type` that dispatch used, with a prompt carrying the four instructions the state
      machine already documents — (a) re-run the verification it was waiting on in the foreground
      with a bounded `timeout`, redirecting to a file and grepping that file, never awaiting a
      harness notification; (b) attribute each failure to its own edits or to pre-existing
      breakage with `git log`/`git status` overlap evidence; (c) close every phase with an
      explicit verdict, leaving none open; (d) write all three closing artifacts and commit them.
      *(completed)*
- [x] After each relay Agent call returns, run `orchestrate-cycle-postflight.sh` once for that
      task with the same invocation shape Move 3 uses, and apply the ordinary verdict handling to
      its result — including the `failed_tasks` append, which is now reachable because the
      re-prompt has been spent. *(completed)*
- [x] Move the entry from `pending_stall_reprompt[]` to `stall_reprompted[]` keyed on
      `{task, dispatch_seq}`, so exactly one re-prompt is ever owed per dispatch and a second
      no-outcome return on the same dispatch takes the ordinary path. State that invariant inline.
      *(completed)*
- [x] Record in Move 4's prose that this relay, like the `AskUserQuestion` relay it sits beside,
      never runs mid-cycle and never runs once per task inside Move 3's loop. *(completed)*

**Timing**: 1 hour 15 minutes

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts that **three** new `mt_state_file` fields are needed
(`pending_stall_reprompt`, `stall_reprompted`, `stall_ledger`) and that Move 3's `failed_tasks`
append is the **single** suppression site. Confirm at implementation time by grepping
`SKILL.md` for every `failed_tasks` write (`grep -n 'failed_tasks' SKILL.md`) before editing: if
more than the one `elif` arm appends on a `failed` verdict outside the infra path, the
suppression must cover each of them, and the field count may differ. Do not assume the counts
above; report the measured ones in the phase's own verification output.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Move 3: extract
  `stall_suspected`, guard the `failed_tasks` append, accumulate `pending_stall_reprompt[]` and
  `stall_ledger[]`, emit the stderr notice. Move 4: add the batched stall re-prompt relay beside
  the `AskUserQuestion` relay, with its one-re-prompt-per-`dispatch_seq` invariant.

**Verification**:

- `grep -c 'stall_suspected' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
  returns a non-zero count (it was 0 before this phase — this is the phase's defining assertion).
- `grep -n 'pending_stall_reprompt' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
  shows at least one writer in Move 3 and one reader in Move 4.
- `grep -n 'stall_reprompted' .../SKILL.md` shows the key is consulted in Move 3's suppression
  guard and written in Move 4's relay, so the one-re-prompt bound is expressed in both places.
- No Agent call appears between `### Move 3: Postflight` and `### Move 4: Branch` — confirm by
  reading that region of the diff.
- `bash agent-system/extensions/core/scripts/lint/lint-postflight-boundary.sh` passes (its
  scanned region covers Move 4; verified at plan time that its three patterns — build commands,
  `grep` on source, MCP tools — are untouched by this phase).
- `bash agent-system/extensions/core/scripts/lint/lint-json-channel-discipline.sh` passes, since
  this phase adds `jq` reads of a script's JSON output.

---

### Phase 4: Record the three rulings and the signal's boundary [COMPLETED]

**Goal**: Put the scope item (3) ruling, the postflight/loop-level division of labour, the
`dispatch_seq`-staleness signal's role and weakness, the `stall_suspected` boundary, and the
IDENTICAL-DISPATCH-HALT distinction into the four files that own them — so the next reader does
not re-derive any of it, and so the fields Phase 3 introduced are documented where the
`mt_state_file` reference lives.

**Tasks**:

- [x] Re-read each of the four files immediately before editing; two of them are declared by
      other non-terminal tasks. *(completed)*
- [x] `context/standards/postflight-tool-restrictions.md`: add to **Allowed Operations** that a
      read-only, count-only liveness or staleness probe is permitted during postflight —
      specifically a `git log --since` commit count scoped to the task directory, and an mtime /
      `dispatch_seq` read of `specs/{NNN}_*/.return-meta.json`. State why it is not the prohibited
      class: it reads no report, plan, summary, or source content, so the Context Flatness
      Constraint holds, and it is a count/identity probe rather than verification or source
      analysis. Add the complementary ruling to the same file: **acting** on such a signal — the
      re-prompt — is a loop-level branch-move action, never a per-dispatch postflight action, and
      a per-dispatch postflight body still MUST NOT issue a dispatch. *(completed)*
- [x] `docs/architecture/handoff-schema.md`, in or adjacent to **Readers MUST check freshness**:
      record that an unfinished dispatch leaves `.return-meta.json` and
      `.orchestrator-handoff.json` carrying the **prior** dispatch's `dispatch_seq`, which makes a
      returned-but-stale-seq observation the cheapest and most direct stranded-dispatch signal.
      Then record its weakness plainly: a stale seq cannot distinguish an abandoned wrap-up from a
      dispatch that died instantly, so it is used for rejection and recovery attribution, never as
      the re-prompt trigger — that discrimination is `stall_suspected`'s commit-gated conjunction.
      *(completed)*
- [x] `docs/architecture/handoff-schema.md`, **Postflight Boundary** section: name the stall
      re-prompt relay as a loop-level branch-move action sited beside the `AskUserQuestion` relay,
      so the section's "the per-dispatch postflight phase is limited to ..." enumeration stays
      accurate rather than silently contradicted by Phase 3's wiring. This is a clarification of
      where the action lives, not a sixth prohibited operation and not a second exception
      alongside item 5's verbatim-recovery carve-out. *(completed)*
- [x] `scripts/orchestrate-cycle-postflight.sh`: update the `stall_suspected` contract comment in
      the output-contract header and the field's own inline block. Name the now-real consumer site
      (the loop's Move 3 read plus the branch move's relay) in place of the present
      "the lead re-prompts" phrasing that describes an obligation nothing executed. Record the
      boundary: a stall occurring before the dispatch's first commit leaves the count at zero, so
      the field stays false and the dispatch falls through to the ordinary no-outcome path —
      correct, because a dispatch with zero commits has no committed work at stake. Record the
      ruling that the trigger is deliberately **not** widened with an OR against a stale
      `dispatch_seq`, because that would destroy the field's only discrimination. Comment-only:
      change no executable line. *(completed: confirmed comment-only via
      `git diff ... | grep -E '^\+' | grep -vE '^\+\s*#|^\+\+\+'` returning nothing)*
- [x] `docs/architecture/orchestrate-state-machine.md`: add `pending_stall_reprompt`,
      `stall_reprompted`, and `stall_ledger` to the **Loop-Owned Runtime State: `mt_state_file`
      Field Reference** section, with `stall_ledger` carrying `defer_ledger`'s exact MUST NOT
      (never read by any eligibility/admission/convergence decision, never merged into another
      ledger). Update the **Loop obligation** subsection of "Abandoned Wrap-Up" to name the
      relay's actual site and the one-re-prompt-per-`dispatch_seq` key, replacing the unsited
      "re-prompt the same dispatch once" prose. *(completed)*
- [x] `docs/architecture/orchestrate-state-machine.md`: add a short explicit non-conflation note
      distinguishing the two near-synonymous mechanisms — IDENTICAL DISPATCH HALT is
      `orchestrate-cycle-plan.sh`'s cross-cycle convergence guard, keyed on the composed dispatch
      file's content hash and answering "the same instructions keep being re-issued and nothing
      changes"; `stall_suspected` is a within-dispatch liveness signal answering "this one agent
      went idle mid-turn without finishing." Neither substitutes for the other. *(completed)*
- [x] State the related-but-not-blocking relationships in deliverable prose by durable anchor
      only: the per-dispatch cost-and-timing record would make a stall visible after the fact but
      neither prevents nor detects one; the cross-batch session-liveness work addresses liveness
      between concurrent batches, not within a single dispatch. Use no task numbers. *(completed:
      stated in orchestrate-state-machine.md's "Related work, not relied on here" paragraph,
      durable-anchor only, no task numbers)*
- [x] Verify no task number appears in any of the four files' added text. *(completed:
      check-task-references.sh reports 0 occurrences)*

**Timing**: 1 hour 15 minutes

**Depends on**: 3

**Verification Tier**: interface

**Commit Mode**: per-substep

**Files to modify**:

- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` - add the
  allowed read-only/count-only liveness-and-staleness probe, and the ruling that acting on the
  signal is loop-level, not postflight.
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - record the stale-`dispatch_seq`
  stranded-dispatch signal, its weakness relative to `stall_suspected`, and the stall re-prompt
  relay's loop-level siting in the Postflight Boundary section.
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - comment-only: name the
  now-real `stall_suspected` consumer, record the pre-first-commit boundary, and record the
  deliberate non-widening of the trigger.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - document the
  three new `mt_state_file` fields, site the Loop obligation's relay, and add the
  IDENTICAL-DISPATCH-HALT non-conflation note.

**Verification**:

- `git diff -- agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh | grep -E '^\+' | grep -vE '^\+\s*#|^\+\+\+'`
  returns nothing — proving the script change is comment-only.
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` passes,
  with the four `stall_suspected` assertions (S1-S4) still green.
- `grep -n 'pending_stall_reprompt\|stall_reprompted\|stall_ledger' agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`
  returns all three field names.
- `grep -n 'IDENTICAL DISPATCH HALT' agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`
  shows the non-conflation note.
- `grep -niE 'task [0-9]+|tasks [0-9]+' <each of the four files>` returns nothing new; and
  `bash .claude/scripts/check-task-references.sh` reports no new occurrence.
- `bash agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh` passes.

---

### Phase 5: Regression-test the wiring, then run the full gate [NOT STARTED]

**Goal**: Make the fix self-guarding. The defect this task found was a *computed, tested,
documented signal with no consumer* — a class of defect no existing test could catch, because
every existing test exercises the producer. Add a grep-based consistency test that fails if the
consumer disappears again, register it, and close the task behind the full gate set.

**Tasks**:

- [ ] Write `agent-system/extensions/core/scripts/tests/test-stall-reprompt-wiring.sh`, following
      the shape of the existing SKILL.md-asserting tests (`test-handoff-dispatch-identity.sh`,
      `test-orchestrate-context-growth.sh`) for its pass/fail helpers and exit-code convention
      (0 all pass, 1 at least one failure, 2 environment error).
- [ ] Assert the producer/consumer pairing holds in both directions: every field
      `orchestrate-cycle-postflight.sh` emits in its JSON output contract that the state machine
      documents as a loop obligation has at least one read in `skill-orchestrate/SKILL.md`. At
      minimum assert `stall_suspected` explicitly by name, since it is the field that was dead.
- [ ] Assert the suppression guard exists: Move 3's `failed_tasks` append on a `failed` verdict is
      conditioned on `stall_suspected` or `stall_reprompted`.
- [ ] Assert the relay siting: `pending_stall_reprompt` has a writer in the Move 3 region and a
      reader in the Move 4 region, and the Move 3 region contains no Agent call.
- [ ] Assert the three new fields appear in `orchestrate-state-machine.md`'s `mt_state_file` field
      reference, so an implementation/documentation split cannot reopen silently.
- [ ] Register the test in `agent-system/extensions/core/scripts/tests/run-all.sh` following the
      file's existing registration pattern, and add a cost hint to `suite-cost-hints.txt` if that
      file's convention requires one for every registered suite (check before assuming).
- [ ] Run the new test; confirm it passes against the Phase 1-4 tree and fails against a
      deliberately reverted `stall_suspected` read (verify the negative arm by a scratch copy of
      `SKILL.md`, never by reverting the real file).
- [ ] Run the full gate set in the **foreground**, with a bounded `timeout`, redirecting to a file
      and grepping that file — never via `Bash(run_in_background: true)`, never awaiting a harness
      notification. This phase's own conduct is the first test of Phase 1's mandate:
      `timeout 3000 bash .claude/scripts/verify-deploy.sh > "$log" 2>&1; echo "exit=$?" >> "$log"`,
      then read `$log`.
- [ ] Attribute any gate finding to this task's own edits or to pre-existing breakage, with
      `git log` / `git status` overlap evidence, before treating it as a regression. Three sibling
      tasks are live on this same tree this cycle.
- [ ] Write the execution summary and the three closing artifacts, then commit.

**Timing**: 45 minutes

**Depends on**: 1, 2, 3, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-stall-reprompt-wiring.sh` - new: grep-based
  producer/consumer consistency suite for the stall signal and its relay.
- `agent-system/extensions/core/scripts/tests/run-all.sh` - register the new suite.
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt` - add a cost hint only if the
  file's own convention requires one per registered suite.

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-stall-reprompt-wiring.sh` exits 0.
- The same suite exits 1 against a scratch `SKILL.md` with the `stall_suspected` read removed,
  proving the assertion is live rather than vacuously true.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` shows the new suite registered and
  passing, with no previously-passing suite newly red.
- `timeout 3000 bash .claude/scripts/verify-deploy.sh` completes with no new finding attributable
  to this task's edits; every pre-existing finding is named with its `git log`/`git status`
  attribution evidence.
- Every phase heading in this plan carries a terminal marker — `[COMPLETED]`, or
  `[COMPLETED WITH EXCLUSIONS]` with a full `#### Reasoned Exclusions` record. None left
  `[IN PROGRESS]` or `[NOT STARTED]`.
- `.return-meta.json` and `.orchestrator-handoff.json` both carry **this** dispatch's
  `dispatch_seq`, not a prior one — the very staleness signal this task documents, applied to its
  own closing artifacts.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-stall-reprompt-wiring.sh` passes, and
      demonstrably fails when the consumer is removed from a scratch copy.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`
      passes with the four `stall_suspected` assertions (S1-S4) still green — Phase 4's comment
      edits changed no executable line.
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-postflight-boundary.sh` passes, with
      `skill-orchestrate/SKILL.md` still carrying its `## MUST NOT (Postflight Boundary)` heading.
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` and
      `lint-contract-compliance.sh` and `lint-json-channel-discipline.sh` all pass.
- [ ] `bash .claude/scripts/check-task-references.sh` reports no new occurrence anywhere under
      `agent-system/**`.
- [ ] `timeout 3000 bash .claude/scripts/verify-deploy.sh`, run in the foreground with output
      redirected to a file, reports no new finding attributable to this task's edits.
- [ ] No file under `.claude/**` was modified: `git status --short -- .claude/` is empty.

## Artifacts & Outputs

- `agent-system/extensions/core/agents/general-implementation-agent.md` — mechanism-mandating
  background-wait contract plus the explicit deadline fork.
- `agent-system/extensions/core/context/standards/status-markers.md` — the bounded-wait-deadline
  non-admission note in the `[COMPLETED WITH EXCLUSIONS]` section.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — the `stall_suspected`
  consumer in Move 3 and the batched stall re-prompt relay in Move 4.
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` — the
  allowed read-only/count-only liveness probe, and the loop-level-not-postflight ruling on acting
  on it.
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — the stale-`dispatch_seq`
  stranded-dispatch signal, its weakness, and the relay's boundary siting.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — the three new
  `mt_state_file` fields, the sited Loop obligation, and the IDENTICAL-DISPATCH-HALT
  non-conflation note.
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — comment-only contract
  correction naming the real consumer and recording the trigger's boundary.
- `agent-system/extensions/core/scripts/tests/test-stall-reprompt-wiring.sh` (new) and its
  registration in `run-all.sh`.
- `specs/343_bound_agent_background_wait_stranded_dispatch/summaries/01_*-summary.md` — execution
  summary.

## Rollback/Contingency

Every phase is a prose or comment edit to a markdown/shell file plus one new test script; nothing
changes executable behaviour except `SKILL.md`'s procedure, which the loop interprets rather than
executes directly. Each phase commits independently, so reverting a single phase is a single
`git revert` of its own commit.

If Phase 3's relay siting proves unworkable at implementation time — for example if the branch
move cannot reach a `subagent_type` for the stalled row — the contingency is to land Phases 1, 2,
4, and 5 and close Phase 3 `[PARTIAL]` with a handoff naming the obstruction concretely. That
leaves the ruling recorded and the agent-side mandate in force while the loop wiring remains
outstanding. It is explicitly **not** acceptable to substitute an in-Move-3 Agent call to get the
relay landed: that would cross the Postflight Boundary and trade this defect for a worse one.

If a sibling task's concurrent edit collides on any of the seven files, rebase this task's hunks
onto the sibling's version rather than reverting either side; the regions this plan touches (the
background-wait contract, the stall signal's consumer, the exclusion non-admission) are disjoint
from the handoff-field and excursion-advisory work the overlapping tasks pursue.

Before any intentional rollback that a dirty tree would otherwise block, take a non-reverting
checkpoint first: `bash .claude/scripts/git-snapshot.sh 343 --no-revert`. Do not invoke
`git-snapshot.sh` in its default reverting mode as a routine checkpoint.
