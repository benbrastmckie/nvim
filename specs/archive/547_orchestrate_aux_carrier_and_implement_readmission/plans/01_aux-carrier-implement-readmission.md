# Implementation Plan: Task #547

- **Task**: 547 - Close the orchestrate aux blocker-research carrier defect and the implement-readmission gap
- **Status**: [COMPLETED]
- **Effort**: 7.5 hours
- **Dependencies**: None declared in this plan (the record's own cross-repo edge on `docs/architecture/orchestrate-state-machine.md` is carried at the task level, not the phase level)
- **Research Inputs**: specs/547_orchestrate_aux_carrier_and_implement_readmission/reports/01_aux-carrier-implement-readmission.md
- **Artifacts**: plans/01_aux-carrier-implement-readmission.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Close one mechanism that produced two defect classes in the orchestrate aux chain. Item 1: the
`blocker-research` carrier (`.blocker-research.json`) is written on instruction alone and its
pending obligation is discarded at emission time, so a fork that returns without writing silently
evaporates the chain. Item 2: nothing on the *deciding* side of the dispatch refuses an implement
round for a task that is still owed a plan revision. The research phase settled both open
decisions: Item 1 takes shape (a), confirm-then-clear, with shape (c)'s audibility bar layered on
at the escalation cap; Item 2 takes shape (ii), keying on chain state (`aux_pending`) rather than
on handoff prose, but placed in `orchestrate-cycle-plan.sh`'s own post-triage seam rather than
inside `orchestrate-triage-classify.sh`. Every edit lands in the resolved source store
(`agent-system/extensions/core`), each behavioral change is driven by a failing-first assertion in
an existing suite, and the final phase redeploys and runs the complete gate set.

### Research Integration

The report's seven Decisions are adopted as this plan's design; the phases below are their
execution order. Three findings reshape the work beyond the dispatch's own account and are carried
into specific phases:

1. **Hop 4 never sets `aux_clear_pending`** (report Finding 4, re-confirmed in this planning pass:
   `scripts/orchestrate-cycle-plan.sh` lines 1407-1415 contain no `aux_clear_pending` assignment).
   Moving the clear off hop 2 without adding it to hop 4 would create a new, symmetric defect — a
   confirmed carrier leaving a permanently stale `aux_pending[t]`. Phase 1 lands both halves
   together and tests both directions.
2. **`orchestrate-triage-classify.sh` cannot see `aux_pending`** (report's one correction to the
   dispatch's premise; recorded in this task's issue log as an `evidence-gap` entry). Its own
   header restricts its reads to `specs/state.json` and a candidate's own
   `.orchestrator-handoff.json`; `aux_pending` lives in the per-invocation multi-task state file
   loaded as `mt_json` inside `orchestrate-cycle-plan.sh`. Phase 4 therefore places the override in
   the post-triage seam, which also makes acceptance criterion 4 (live/fallback parity) structurally
   satisfied rather than separately defended.
3. **`next_action_hint` has zero live writers, not merely zero routing readers.** This is stronger
   than the dispatch's framing and is why hook shape (i) is rejected rather than merely deferred.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no roadmap phases are included.

### Premise Re-Validation (dispatch's Carried-Figure Discipline)

Every extracted premise line was checked against the live source store during this planning pass,
with `.extensions.core.source_dir` re-resolved from `.claude-extensions.json` to
`/home/benjamin/.config/nvim/agent-system/extensions/core`. Results:

| Premise | Result |
|---------|--------|
| Hop 2 clears `aux_pending[t]` unconditionally at emission | **Confirmed** — `orchestrate-cycle-plan.sh:1466`, inside the `blocker-research)` case arm, after the cap check |
| Hop 4 tests `[ -f "$aux_blocker_file" ] && jq empty "$aux_blocker_file"` and emits `plan-revision` | **Confirmed** — lines 1407-1415, sets `aux_consume_blocker_file[t]` and `continue`s |
| Hop 4 never sets `aux_clear_pending[t]` | **Confirmed** — no such assignment in that branch |
| `blocker_escalation_count[t]` increments only after a successful build+dispatch | **Confirmed** — lines 1572-1574, inside the live-dispatch loop |
| `MAX_BLOCKER_ESCALATIONS` is 2 | **Confirmed** — line 364 |
| The `blocker-research` prompt carries no insistence clause; `plan-revision` does | **Confirmed** — `orchestrate-build-aux-dispatch.sh:215` vs. the clause appended after line 230 |
| `revised_at` appears in no code path of `orchestrate-cycle-plan.sh` | **Confirmed** — no match in that file |
| The inline fallback table maps `blocked` unconditionally to `needs_human` | **Confirmed** — the `blocked)` row in the degraded-classifier `case` |
| The Group 13 parity fixture asserts only `not_started`/`researching`, never `blocked` | **Confirmed** — no `blocked` assertion in that group |
| Both named suites exist and must be extended, not replaced | **Confirmed** — `scripts/tests/test-orchestrate-cycle-plan.sh` (6274 lines, groups through 37) and `scripts/tests/test-orchestrate-build-aux-dispatch.sh` (259 lines) |
| `.claude/**` is a regenerated deploy artifact; `core`'s `source_dir` resolves per extension | **Confirmed** — there is no top-level `source_dir` key; the per-extension map resolves as above |

**One premise overturned, stated explicitly because it changes the work.** The dispatch and the
research report both describe Item 1's test work as *adding* a case. Measured in this planning
pass: `scripts/tests/test-orchestrate-cycle-plan.sh` Group 10 Case A (lines 998-1002) already
asserts the opposite of Decision 1 — `aux: blocker-research clears aux_pending and increments
blocker_escalation_count to 1`, reading `.aux_pending[$t] // "CLEARED"` and passing only when the
entry is gone. Decision 1 makes that assertion false by design. Phase 1 therefore **inverts an
existing assertion in place** as part of landing the remedy, in addition to adding the new cases;
an implementer who only adds cases will land a red suite and may misread it as a broken fix.
Group 10 Case B (the capped-out entry, lines 1014-1017) stays correct and unchanged, because
Decision 1 leaves the cap branch's own clear in place.

## Goals & Non-Goals

**Goals**:

- Make `aux_pending[t]` an honest cross-cycle "is there still an open obligation" signal for the
  `blocker-research` kind: cleared on confirmation or at the cap, never at emission.
- Make a chain that evaporates audible in the run's own output — a `blocked[]` row and an
  issue-log entry at the cap, alongside the existing stderr line.
- Give the `blocker-research` aux prompt the same kind of insistence the `plan-revision` prompt
  already carries, with a named carrier path.
- Withhold an `implement` dispatch from a `blocked`/`partial` candidate while a `blocker-research`
  obligation is still outstanding, without touching either routing table.
- Keep an explicit forcing flag admitting exactly one dispatch, and make that admission audible
  rather than silent when it bypasses an owed revision.
- Leave `docs/architecture/orchestrate-state-machine.md` able to predict both new behaviors from a
  read of that document alone.

**Non-Goals**:

- Changing `orchestrate-triage-classify.sh`'s own routing table or its blocked-discharge arm.
  The discharge check is by design (its own header says so); the override sits outside it.
- Converging the degraded fallback table's `blocked` row with the live classifier's. The
  divergence is already-documented design and the fallback is strictly more conservative.
- Any change to `context/schemas/orchestrator-handoff-schema.json`, `validate-handoff.sh`, or any
  handoff writer. Hook shape (i) is rejected; `next_action_hint` is left exactly as it is.
- Changing where `blocker_escalation_count[t]` increments, or adding a new counter.
- Re-use of `.plan-revised.json`'s `revised_at` as a cross-cycle planner input (hook shape (iii)).
- The plan-authoring half of the same observation, which the sibling record
  `plan_self_consistency_and_artifact_existence` owns. No prose here restates it.
- Any hand edit under `.claude/**`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Moving the clear off hop 2 without adding it to hop 4 leaves a confirmed carrier's `aux_pending[t]` stale forever — a new defect symmetric to the one being fixed | H | M | Phase 1 lands both halves in one phase and asserts both directions (stuck-when-unconfirmed, cleared-when-confirmed) before closing |
| An implementer adds new Group 10 cases without inverting Case A's existing clear assertion, reads the resulting red as a broken fix, and reverts a correct change | M | H | Called out in Premise Re-Validation above and as an explicit first task of Phase 1 |
| Phase 4's override masks a legitimately resolved blocker whose entry was never cleared, wedging a task at `needs_human` | H | L | Phase 4 depends on Phase 1; Phase 1's cleared-when-confirmed assertion is the precondition. The per-invocation reset of `blocker_escalation_count` plus the cap's clear bound any stuck entry to one invocation |
| The forcing-flag warning (Phase 5) regresses silently because it is stderr-only | M | M | Phase 5 asserts the warning text, not only the admitted dispatch |
| An `out_blocked_rows` entry added inside the aux block is emitted at an unexpected point in the cycle's JSON, or is dropped | M | L | Phase 2's first task confirms the aux block executes before `emit_and_exit` and that the row appears in the emitted `blocked[]`, before writing the assertion |
| Editing `orchestrate-cycle-plan.sh` has a wide blast radius (the suite selector returns 25 suites for that path) | M | M | Phases 1, 2, 4 and 5 declare `interface` and run the whole shell battery, not a narrow subset; Phase 6 runs the complete gate set |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2, 4 | 1 |
| 3 | 5 | 4 |
| 4 | 6 | 2, 3, 5 |

Phases within the same wave can execute in parallel. Note that phases 2 and 4 both edit
`scripts/orchestrate-cycle-plan.sh` in disjoint regions (the aux `case` arm around line 1459
versus the post-triage seam around line 1829); if they are run as literal parallel dispatches
rather than in sequence, they share file territory and must be serialized.

---

### Phase 1: Confirm-then-clear for the blocker-research carrier [COMPLETED]

**Goal**: `aux_pending[t].kind == "blocker-research"` survives a cycle in which no parseable
`.blocker-research.json` appears, and is cleared exactly when the carrier is confirmed (hop 4) or
when the escalation cap is reached — never at emission time.

**Tasks**:

- [x] Re-resolve `.extensions.core.source_dir` from `<project-root>/.claude-extensions.json` and
      confirm every line reference below still holds. If the source store is unreachable or
      ambiguous, stop and report rather than editing the deploy tree. *(completed)*
- [x] Extend `scripts/tests/test-orchestrate-cycle-plan.sh` Group 10 with a new case that seeds
      `aux_pending[t] = {kind: "blocker-research", ...}`, runs one cycle with no
      `.blocker-research.json` present, and asserts `aux_pending[t]` is **still present**
      afterward. Run it against the unmodified script and record that it fails. *(completed)*
- [x] Add a companion case asserting that a second cycle on the same unchanged state emits a fresh
      `blocker-research` aux row (re-emission). Record that it fails against the unmodified script. *(completed)*
- [x] Add a case asserting the cleared-when-confirmed direction: with a parseable
      `.blocker-research.json` present, one cycle emits the `plan-revision` row **and** leaves
      `aux_pending[t]` absent. Record whether it passes or fails pre-fix (it exercises the branch
      that gains the new clear). *(completed)*
- [x] Invert Group 10 Case A's existing assertion at lines 998-1002: after a blocker-research
      emission, `aux_pending[t]` is now expected to be **present**, while the
      `blocker_escalation_count[t] == 1` half of that assertion stays as it is. Update the pass and
      fail message strings to describe the new contract. *(completed)*
- [x] Remove the unconditional `aux_clear_pending[$t]="true"` at line 1466 (the `blocker-research)`
      case arm, after `aux_emit_blocker_desc` is set). Leave the cap branch's own clear at line
      1461 untouched. *(completed)*
- [x] Add `aux_clear_pending[$t]="true"` to the carrier-success branch (lines 1407-1415), alongside
      the existing `aux_consume_blocker_file[$t]="true"`. *(completed)*
- [x] Amend the consumption-loop comment above line 1578 ("a suppressed entry must not be
      re-evaluated every subsequent cycle of this SAME invocation") so it states the new
      `blocker-research` exception: that kind is deliberately re-evaluated until confirmed or
      capped. The comment as written now contradicts the landed behavior. *(completed)*
- [x] Sweep the remaining `aux_pending` references in the suite (around lines 1116, 1155 and 2659)
      and confirm none of them asserts a blocker-research clear that Decision 1 invalidates. *(completed)*
- [x] Re-run the suite and confirm every new and inverted assertion is green. *(completed)*

**Timing**: 1.75 hours

**Depends on**: none

**Verification Tier**: interface

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh` — the whole
shell battery, because `suite_selection_select` returns 25 suites for
`agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` and no honest `--only` subset is
narrower than running them all.

**Scope Hypothesis**: exactly one existing assertion (Group 10 Case A, lines 998-1002) contradicts
Decision 1 and must be inverted; Case B and every other `aux_pending` reference in the suite stay
valid. Confirm by grepping `aux_pending` across the suite and reading each hit's assertion before
editing, rather than trusting this count.

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - remove the emission-time
  clear in the `blocker-research)` arm; add the clear to the carrier-success branch; amend the
  consumption-loop comment
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - invert Group 10
  Case A's clear assertion; add the three new cases

**Verification**:

- Each new case was observed failing against the unmodified script before the fix landed, and the
  observation is recorded in the phase's own notes.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` is green.
- A manual read of the `blocker-research)` arm confirms `aux_clear_pending` is set on exactly two
  paths: the cap branch and the carrier-success branch.

---

### Phase 2: Audibility at the escalation cap [COMPLETED]

**Goal**: when `blocker_escalation_count[t]` reaches `MAX_BLOCKER_ESCALATIONS` without the carrier
ever appearing, the give-up is visible in the cycle's own JSON output and in the durable issue log,
not only on stderr.

**Tasks**:

- [x] Confirm, by reading the control flow, that the aux chain block executes before
      `emit_and_exit` and that an `out_blocked_rows` entry appended there reaches the emitted
      `blocked[]` array. Record the result before writing any assertion. *(completed)*
- [x] Extend `scripts/tests/test-orchestrate-cycle-plan.sh` Group 10 with a case that seeds
      `blocker_escalation_count[t]` at the cap alongside a `blocker-research` `aux_pending[t]`
      entry, and asserts a `blocked[]` row naming the task and the absent carrier path. Record that
      it fails against the unmodified script. *(completed)*
- [x] At the cap branch (line 1459-1461), append an `out_blocked_rows` entry whose reason names the
      cap, the task, and the absent `.blocker-research.json` path, following the existing
      `jq -n -c --argjson t ...` row idiom used by the `MAX_INFRA_FAILURES` and `MAX_CYCLES` sites. *(completed)*
- [x] At the same branch, add a non-fatal `issue-record.sh` call modelled on the
      `MAX_INFRA_FAILURES` site's own call shape (`--task "$t"`, `--kind issue`, a named class,
      `--severity`, `--resolution open`, `--suggested-channel agent_system`, `--session`, output
      discarded, `|| echo "Note: issue recording failed (non-fatal)" >&2`), guarded by the same
      `[ "$dry_run" != "true" ]` condition that site uses. *(completed)*
- [x] Confirm the existing `--dry-run` parity case in Group 10 still passes — the issue-record call
      must not fire under `--dry-run`. *(completed)*
- [x] Keep the existing stderr line at line 1460 unchanged; the new channels are additive. *(completed)*
- [x] Re-run the suite green. *(completed)*

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: interface

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh` — the whole
shell battery, because this phase changes the emitted `blocked[]` contract that the orchestrate
skill and the batch-admission suites both consume, and the selector returns 25 suites for this
path.

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - add the `out_blocked_rows`
  entry and the `issue-record.sh` call at the blocker-research cap branch
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - add the cap
  audibility case

**Verification**:

- The new case was observed failing pre-fix.
- A cycle driven to the cap emits a `blocked[]` row naming the absent carrier path, and the
  task's `issues.jsonl` gains one entry.
- `--dry-run` on the same fixture emits no issue-log entry.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` is green.

---

### Phase 3: Insistence clause on the blocker-research aux prompt [COMPLETED]

**Goal**: the `blocker-research` fork prompt states the carrier write is required regardless of
what the fork's own return text says, mirroring in spirit (not verbatim) the `plan-revision`
prompt's existing unconditional clause.

**Tasks**:

- [x] Extend `scripts/tests/test-orchestrate-build-aux-dispatch.sh` with an assertion on the
      `blocker-research` dispatch file, following the same grep-the-written-dispatch-file pattern
      the existing `plan-revision` sentinel assertions already use. Assert the clause names the
      `.blocker-research.json` carrier path and carries unconditional language. Record that it
      fails against the unmodified script. *(completed)*
- [x] Append the insistence clause to the `blocker-research` prompt in
      `scripts/orchestrate-build-aux-dispatch.sh` (the `blocker-research)` case arm, around line
      215). Keep the existing field list (`summary`, `root_cause`, `solution_path`) unchanged; the
      clause is additive. *(completed)*
- [x] Add a short comment beside the clause recording why it exists — that the chain's follow-on
      `plan-revision` hop reads only this file, so a fork that returns prose without writing it
      leaves nothing for a later cycle to act on. Do not restate the `plan-revision` sentinel's own
      contract; that prompt's existing comment already carries it. *(completed)*
- [x] Re-run the suite green. *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
test-force-phases.sh,test-orchestrate-build-aux-dispatch.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-unwind-dispatch.sh` —
the exact union `suite_selection_select` returns for this phase's two touched paths.

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-build-aux-dispatch.sh` - append the insistence
  clause and its rationale comment to the `blocker-research` prompt
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-aux-dispatch.sh` - add the
  mirror assertion

**Verification**:

- The new assertion was observed failing pre-fix.
- The written `blocker-research` dispatch file contains the clause and still contains the original
  three-field write instruction.
- The named `--only` suite subset is green.

---

### Phase 4: Withhold implement readmission while a blocker-research obligation is outstanding [COMPLETED]

**Goal**: a `blocked` candidate whose `previous_status` was `implementing`, which today discharges
straight to the implement arm, instead routes to `needs_human` while
`aux_pending[t].kind == "blocker-research"` is still set.

**Tasks**:

- [x] Extend `scripts/tests/test-orchestrate-cycle-plan.sh` with a case built on today's exact
      discharge-eligible shape: status `blocked`, `previous_status` `implementing`, every entry in
      `dependencies[]` at `completed`, handoff `blockers[]` empty, plus a seeded
      `aux_pending[t] = {kind: "blocker-research", ...}`. Assert the task's verdict is
      `needs_human` with a reason naming the outstanding obligation, not an `implement` dispatch.
      Record that it fails against the unmodified script (which discharges to implement). *(completed)*
- [x] Add a negative-control case: the same fixture with **no** `aux_pending[t]` entry still
      discharges to `implement`. This must pass both before and after the change and pins that the
      override is narrow. *(completed)*
- [x] Insert the override loop in `scripts/orchestrate-cycle-plan.sh` at the seam immediately after
      the classification block closes (after the live/degraded `if`/`else` that populates
      `triage_group` and `triage_reason`, and before the `force_phases` consumption block). Read
      `mt_get --arg t "$t" '.aux_pending[$t].kind // ""'`; when it is `blocker-research` and
      `triage_group[$t]` is `implement`, set `triage_group[$t]="needs_human"` and set
      `triage_reason[$t]` to a reason naming the outstanding blocker-research escalation and the
      carrier path it is waiting on. *(completed)*
- [x] Add a comment at the seam recording why the override lives here and not in
      `orchestrate-triage-classify.sh`: that script reads only `specs/state.json` and a candidate's
      own `.orchestrator-handoff.json` per its own header, and never opens the per-invocation
      multi-task state file where `aux_pending` lives. Note that placing it here also applies it
      identically to whichever engine produced the base verdict, so neither routing table changes. *(completed)*
- [x] Confirm the Group 13 parity fixture still passes unchanged, and confirm no new `blocked`
      assertion was added to it. *(completed)*
- [x] Re-run the suite green. *(completed)*

**Timing**: 1.75 hours

**Depends on**: 1

**Verification Tier**: interface

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh` — the whole
shell battery, because this phase changes which tasks reach the `dispatch[]` array at all, a
surface the batch-admission, force-phases and triage-classify suites each consume, and the
selector returns 25 suites for this path.

**Scope Hypothesis**: the override is confined to the post-triage seam and requires no edit to
`orchestrate-triage-classify.sh`, to the inline fallback table, or to the Group 13 parity fixture.
Confirm by running the parity fixture unchanged and by checking `git diff --stat` names neither
`orchestrate-triage-classify.sh` nor a changed `blocked)` row in the fallback `case`.

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - add the post-triage override
  loop and its placement-rationale comment
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - add the override
  case and the negative-control case

**Verification**:

- The override case was observed failing pre-fix, routing to `implement`.
- The negative control passes both before and after.
- The Group 13 parity fixture passes with no edit.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` is green.

---

### Phase 5: Forcing-flag override still admits one dispatch, audibly [COMPLETED]

**Goal**: an explicit forcing flag continues to admit exactly one dispatch against an outstanding
blocker-research obligation, and that admission is logged as an override rather than granted
silently.

**Tasks**:

- [x] Extend `scripts/tests/test-orchestrate-cycle-plan.sh` with a case on Phase 4's override
      fixture plus a forced implement phase, asserting (a) the implement dispatch still fires and
      (b) a stderr warning naming the bypassed obligation is present. Record which half fails
      pre-fix — half (a) is expected to pass already, since the forced-phase loop ignores
      `triage_group` entirely when `force_phases_remaining[t]` is non-empty; half (b) is the new
      assertion and must fail. *(completed)*
- [x] Emit the stderr warning at the point `forced_phase` is assigned in the `effective_group`
      loop, conditional on the task carrying an outstanding `aux_pending[t].kind ==
      "blocker-research"`. State plainly that the override is admitting one dispatch although a
      plan revision is owed. *(completed)*
- [x] Confirm by reading the loop that no code change is needed to preserve the admission itself —
      the forced branch never consults `triage_group`, so Phase 4's override is bypassed
      structurally. Record that confirmation rather than asserting it from this plan. *(completed)*
- [x] Re-run the suite green. *(completed)*

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: interface

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh` — the whole
shell battery, because the forced-phase admission path is exercised by the force-phases and
hold-override suites as well as the cycle-plan suite, and the selector returns 25 suites for this
path.

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - emit the override warning at
  the forced-phase assignment site
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - add the
  forcing-flag override case

**Verification**:

- The warning assertion was observed failing pre-fix.
- The forced fixture still produces exactly one implement dispatch.
- The warning text names the outstanding obligation.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` is green.

---

### Phase 6: State-machine documentation, deploy, and full-gate acceptance [COMPLETED]

**Goal**: a reader of `docs/architecture/orchestrate-state-machine.md` alone can predict both the
carrier-absence case and the implement-readmission case; the source store is redeployed and the
complete gate set is green.

**Tasks**:

- [x] Narrow the `blocked, discharged` row of that document's transition table in place, adding the
      new discharge precondition: a discharge to `implement` is withheld while a blocker-research
      escalation is outstanding. Keep the row's existing dependency/handoff-blockers conditions. *(completed)*
- [x] Extend the `### Auxiliary Dispatch (aux_dispatch[])` section with the carrier-confirmation
      behavior: the pending obligation is cleared on a confirmed, parseable carrier or at the
      escalation cap, never at emission; an unconfirmed obligation is retried up to the cap and
      then surfaced in `blocked[]` and in the issue log. *(completed)*
- [x] State the forcing-flag behavior in the same section, in the shape the research recommends:
      an explicit forcing flag admits one dispatch regardless of an outstanding blocker-research
      escalation, and the admission is logged as an override rather than silently granted. *(completed)*
- [x] Check every edited sentence against the two deliverable rules: no task numbers, no
      record-versioning language. State the landed behavior as what the system does, never as a
      narration of a past run. Cite only the durable anchors the record sanctions (script and
      document names, aux kinds, carrier filenames, field names, counter names). *(completed)*
- [x] Determine whether any file this task edited has a `line_count` entry in core's
      `index-entries.json`. If one does, update the count to match the file as landed and confirm
      the file still parses with `jq`. *(completed)*
- [x] Run `bash .claude/scripts/deploy-headless.sh` and confirm it reports
      `RESULT=landed_verify_clean`. *(completed)*
- [x] Confirm `git status --short` shows no hand-authored file under `.claude/**` — every landed
      edit is in the source store at its mirroring path, and any `.claude/**` change is the
      deploy's own regeneration. *(completed)*
- [x] Run the complete gate set and confirm green. *(completed)*

**Timing**: 1 hour

**Depends on**: 2, 3, 5

**Verification Tier**: full

**Scope Hypothesis**: no file edited by this task carries a `line_count` entry in core's
`index-entries.json` — a query of that file for the state-machine doc's path returned nothing
during planning, and the remaining edits are to `scripts/**`, which is not indexed. Confirm by
re-querying `index-entries.json` for every path in this plan's combined `Files to modify` set
before concluding the step is a no-op; if any hit appears, acceptance criterion 8 applies and the
count must be corrected.

**Files to modify**:

- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - narrow the
  `blocked, discharged` row; extend the auxiliary-dispatch section with the carrier-confirmation,
  audibility, and forcing-flag behaviors
- `agent-system/extensions/core/index-entries.json` - only if the preceding query finds a
  `line_count` entry for an edited file
- `__WHOLE_TREE__` - this phase runs `deploy-headless.sh`, which regenerates the entire deployed
  tree

**Verification**:

- `bash .claude/scripts/verify-deploy.sh` — the complete gate set for the repository — is green.
- `bash .claude/scripts/deploy-headless.sh` reports `RESULT=landed_verify_clean`.
- A read of the edited document alone predicts both the carrier-absence case and the
  implement-readmission case, including what a forcing flag does against an owed revision.
- No file under `.claude/**` was hand-authored.

## Testing & Validation

- [ ] Every new assertion in `test-orchestrate-cycle-plan.sh` and
      `test-orchestrate-build-aux-dispatch.sh` was observed failing against the unmodified scripts
      before its fix landed, and each observation is recorded in the owning phase's notes.
- [ ] Both suites were extended, never replaced.
- [ ] A cycle in which the blocker-research aux round leaves no parseable carrier re-emits on the
      next cycle rather than dropping the chain, and the give-up at the cap is visible in
      `blocked[]`, in the issue log, and on stderr.
- [ ] A `blocked` candidate with `previous_status` `implementing` and an outstanding
      blocker-research obligation receives no implement dispatch; the same candidate without the
      obligation still discharges to implement.
- [ ] The live classifier and the inline fallback table still agree, with the existing Group 13
      parity fixture passing unchanged.
- [ ] An explicit forcing flag still admits one dispatch, and the override warning is asserted.
- [ ] `bash .claude/scripts/verify-deploy.sh` is green and
      `bash .claude/scripts/deploy-headless.sh` reports `RESULT=landed_verify_clean`.

## Artifacts & Outputs

- Modified: `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`
- Modified: `agent-system/extensions/core/scripts/orchestrate-build-aux-dispatch.sh`
- Modified: `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh`
- Modified: `agent-system/extensions/core/scripts/tests/test-orchestrate-build-aux-dispatch.sh`
- Modified: `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`
- Conditionally modified: `agent-system/extensions/core/index-entries.json`
- Regenerated (not hand-authored): the deployed `.claude/**` tree

## Rollback/Contingency

Each phase closes with its own commit, so reverting is per-phase rather than wholesale. If Phase 4
or Phase 5 proves unsound, reverting those two commits leaves Phases 1-3 standing: confirm-then-
clear plus audibility is a coherent, self-contained improvement that closes Item 1 on its own, and
Item 2's override is the only part that depends on it. Reverting Phase 1 alone is not safe once
Phase 4 has landed, because the override reads the signal Phase 1 makes honest — revert Phase 4
first, in that order. Before any rollback that would discard uncommitted work, take a defensive
checkpoint with `bash .claude/scripts/git-snapshot.sh 547 --no-revert`, and reserve the default
reverting form for a genuine rollback. After any revert, redeploy and reconfirm
`RESULT=landed_verify_clean`, since the deployed tree mirrors whatever the source store last held.
