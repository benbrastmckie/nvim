# Implementation Plan: Task #150

- **Task**: 150 - Research on demand: planner-first lifecycle with research only when the planner asks or --research forces it
- **Status**: [IMPLEMENTING]
- **Effort**: 9 hours
- **Dependencies**: Task 88 (completed - four-move engine is the only engine)
- **Research Inputs**: specs/150_research_on_demand/reports/01_research-on-demand-lifecycle.md
- **Artifacts**: plans/01_research-on-demand-lifecycle.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Flip the default `/orchestrate` lifecycle from research -> plan -> implement to plan -> implement,
and give the planner the authority to send a task back for research by returning a
`needs_research` verdict carrying a focused question list. The mechanism is almost entirely
reuse: `researching` is already a first-class resting state with an existing classifier row,
`orchestrate-build-dispatch.sh --focus` is already-built, already-phase-gated, currently-unused
plumbing, and `--file-scope-add` is a byte-for-byte structural template for the question-list
write-back. Done means a specification-shaped task reaches `[PLANNED]` without a research
dispatch, a planner that declines to plan routes to research with its questions in the dispatch
file and back to plan, `--research` still forces research first, and fixture tests cover both
routes with the full gate run green.

### Research Integration

The research report maps every DESIGN clause onto a concrete file and names the single
consequential hazard: a `needs_research` status with no dedicated postflight arm falls into the
off-schema catch-all, which sets `halt=true` and records an `OFF_SCHEMA_STATUS` system defect --
directly contradicting this task's own MUST NOT and aborting the whole invocation. The plan makes
that arm Phase 3 and gates the routing flip (Phase 4) behind it so the new default can never be
live while the catch-all is still reachable.

Adopted from the report's recommendations: `researching` (not `not_started`) as the resting state
for a `needs_research` verdict, because it reuses the existing `researching -> research`
classifier row and needs no new classifier row (findings #2, #4); Option A for the status write
(a new `postflight:needs_research` target-status token in `update-task-status.sh` mapping to
`STATE_STATUS="researching"`, plus an extended `skill_postflight_update()` whitelist) over Option
B's semantically confusing preflight-call-from-postflight (finding #6); `state.json` rather than
`mt_state_file` as the durable carrier for the question list, since `mt_state_file` is minted
fresh per invocation and would lose the list across a crashed or budget-exhausted session
(finding #8).

**Three gate sites the report did not reach, confirmed by this plan's own grounding pass** --
these are the reason Phase 1 exists and runs before everything else:

1. `orchestrate-recover-outcome.sh` is the decisive one. Base-mode research/plan/implement
   dispatches write no handoff, so the postflight recovers `dispatch_status` from
   `.return-meta.json` through this script. Its `case "$status"` accepts only
   `researched|planned|implemented`; anything else falls to `*)`, which emits
   `STATUS_NOT_SUCCESS` and exits 1. A `needs_research` verdict therefore never reaches the
   postflight status switch as `needs_research` at all -- recovery fails first, `dispatch_status`
   stays empty, and the empty value hits the same off-schema catch-all by a different road. The
   postflight arm alone (the report's fix) is necessary but not sufficient.
2. `validate-return-meta.sh` holds a closed `valid_statuses` array
   (`in_progress researched planned implemented partial failed blocked`) and fails validation on
   any other value. Its artifacts non-empty rule is already correct for this case: `needs_research`
   would land in the permissive `*)` arm, so an empty artifacts array (correct -- the planner
   writes no plan) is legal without further change.
3. `reconcile-task-status.sh` treats every on-enum value that does not match the expected phase
   status as genuine negative evidence and refuses promotion. Reached only via a handoff, which
   base-mode never writes, so this is expected to be inert -- but it is enumerated and checked
   rather than assumed.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found in this repository. `specs/PATH.md` is the governing sequence document; this
task is its Stage A.8, landing after Task 88.

## Goals & Non-Goals

**Goals**:
- Default `not_started` routing becomes `plan`, in lockstep across the live classifier, the
  blocked-discharge re-routing table, the degraded-classifier fallback, and the state-machine doc
  (table and ASCII diagram).
- `needs_research` exists as a peer value in the `.return-meta.json` status vocabulary, survives
  every recovery and validation gate between the planner and the postflight status switch, and
  resolves to a `needs_research` verdict with `halt=false` and no recorded defect.
- A `needs_research` verdict writes `researching` to `state.json` and durably persists the
  planner's question list on the task record.
- The persisted question list is read at research-dispatch build time and passed through the
  existing `orchestrate-build-dispatch.sh --focus` flag into the dispatch file.
- `planner-agent.md` gains a mandatory opening assessment step with an explicit, narrow bar for
  requesting research.
- Fixture tests cover the `not_started -> plan` default and the
  `needs_research -> researching + question-list-carried -> research` round trip.

**Non-Goals**:
- Changing what `--research` does. It already forces the research phase first through the
  existing `force_phases_remaining` queue, independent of the classifier default; it is verified,
  not rebuilt.
- Weakening any plan-format.md requirement to make planning-without-research easier.
- Letting the orchestrator decide whether research is needed. The classifier only routes on the
  recorded verdict; the judgment is the planner's alone.
- Introducing a per-domain planner agent. `resolve_agent()` hardcodes `planner-agent` for
  `op == "plan"` and stays that way.
- Adding a `postflight-verdict-vocabulary.md` context file. The report flags this as worth doing
  if the verdict enum grows again; it is not done here.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `needs_research` reaches the postflight off-schema catch-all, setting `halt=true` and recording an `OFF_SCHEMA_STATUS` defect -- violating this task's own MUST NOT and aborting the whole invocation | H | H (certain if any one gate is missed) | Phase 1 clears every gate upstream of the switch (`orchestrate-recover-outcome.sh`, `validate-return-meta.sh`) before Phase 3 adds the arm; Phase 4's routing flip is gated behind both; Phase 6 pins `halt=false` and no-defect-recorded as explicit assertions |
| The routing flip lands while the postflight arm does not exist, making every planner-declined task halt the run | H | M | Hard dependency ordering: Phase 4 depends on Phases 2 and 3; the flip is the last behavioral change before tests |
| The four `not_started -> research` sites drift out of sync (two jq/bash, one bash case, one prose doc with an ASCII diagram) | M | M | All four flip inside Phase 4, single phase, single commit boundary; Phase 6 adds a fixture pinning the degraded-fallback table specifically, which the classifier's own "one code path" header discipline does not currently cover |
| A `needs_research` postflight under `--plan` force sets `clamp_mode=monotonic-max`, and `status_vocabulary_would_regress` skips the `planning`(rank 3) -> `researching`(rank 1) write, silently stranding the task at `planning` | M | M | Phase 3 decides and records the intended interaction explicitly; Phase 6 adds a force-invoked fixture asserting the recorded behavior rather than leaving it to chance |
| The extension planner sweep required by DESIGN (d) has zero targets and reads as a skipped requirement | L | M | Phase 5 runs the grep and records "checked, none found" with the command and its empty output in the phase notes, per the report's finding #10 |
| Question-list field grows unbounded across repeated `needs_research` cycles on a stubborn task | L | L | Overwrite-on-write semantics, not append -- mirroring how `proposed_file_scope` is fully replaced each research postflight even though its merge target is additive |
| Doc mirrors of the six-value status string drift from the scripts | L | M | Phase 1 enumerates the mirrors by grep and updates them in the same phase as the scripts |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3, 5 | 1, 2 |
| 3 | 4 | 2, 3 |
| 4 | 6 | 3, 4, 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Admit `needs_research` to the status vocabulary and its upstream gates [COMPLETED]

**Goal**: Make `needs_research` a legal `.return-meta.json` status that survives recovery and
validation intact, so it can reach the postflight status switch at all.

**Tasks**:
- [x] Append `|needs_research` to the status enum line in
      `context/formats/return-metadata-file.md`, and add a short field note stating that
      `needs_research` is a planner-only outcome, carries an empty `artifacts` array by design
      (no plan is written), and requires the question-list field described in Phase 2. *(completed: also added a dedicated `research_questions (optional)` field-spec section)*
- [x] Add a `needs_research` arm to `orchestrate-recover-outcome.sh`'s `case "$status"`, placed
      alongside `researched|planned|implemented` but NOT sharing their artifacts-evidence logic:
      an empty artifacts array is the correct and expected shape here, so the arm must emit
      `recovered=true` with `evidence_suspect=false` and must not raise
      `ARTIFACTS_SHAPE_MISMATCH` on the empty array. *(completed)*
- [x] Add `"needs_research"` to `validate-return-meta.sh`'s `valid_statuses` array. Confirm the
      artifacts non-empty rule leaves it in the permissive `*)` arm so an empty array validates. *(completed: confirmed by fixture run, see Verification)*
- [x] Add `"needs_research"` to `validate-handoff.sh`'s `valid_statuses` array for vocabulary
      symmetry, so a hard-mode path that does write a handoff is not blocked by a stale enum. *(completed)*
- [x] Check `reconcile-task-status.sh`'s on-enum refusal set and its off-schema warning string:
      decide and record whether `needs_research` joins the on-enum list. Expected finding is that
      this path is unreachable for base-mode planning (no handoff is written); record that
      conclusion in the phase notes rather than changing behavior on speculation. *(completed: confirmed via docs/architecture/handoff-schema.md's Handoff Writers table that planner-agent never writes a handoff -- recorded as an inline comment in reconcile-task-status.sh; on-enum set left unchanged)*
- [x] Update the doc mirrors of the six-value vocabulary string found by grep:
      `context/patterns/metadata-file-return.md`, `context/architecture/system-overview.md`,
      `context/patterns/system-defect-discrimination.md`, and `context/formats/subagent-return.md`
      (whose list already carries extra values and needs the new one inserted consistently). *(completed)*
- [x] Update the two off-schema operator messages that quote the vocabulary inline
      (`orchestrate-cycle-postflight.sh` and `orchestrate-stage5-postflight.sh`) so the message a
      user sees names the full current enum. Confirm at implementation time whether
      `orchestrate-stage5-postflight.sh` is still a live path before editing it. *(completed: confirmed orchestrate-stage5-postflight.sh has no call site in skill-orchestrate/SKILL.md -- not a live orchestrate path, only unit-tested directly by test-force-phases.sh -- updated its message anyway for consistency)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the vocabulary lives in exactly 4 script sites
(`orchestrate-recover-outcome.sh`, `validate-return-meta.sh`, `validate-handoff.sh`,
`reconcile-task-status.sh`), 2 operator-message sites, and 4 doc mirrors. Confirm at
implementation time by re-running
`grep -rn 'researched|planned|implemented' agent-system/extensions/` and reconciling every hit
against this list before editing; a hit not on this list is a scope expansion to record, not to
silently absorb.

**Files to modify**:
- `agent-system/extensions/core/context/formats/return-metadata-file.md` - add `needs_research`
  to the status enum plus a field note
- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` - new `needs_research`
  case arm with empty-artifacts-is-correct semantics
- `agent-system/extensions/core/scripts/validate-return-meta.sh` - extend `valid_statuses`
- `agent-system/extensions/core/scripts/validate-handoff.sh` - extend `valid_statuses`
- `agent-system/extensions/core/scripts/reconcile-task-status.sh` - checked; edit only if the
  recorded finding warrants it
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - off-schema message
  string only (the case arms are Phase 3)
- `agent-system/extensions/core/scripts/orchestrate-stage5-postflight.sh` - off-schema message
  string, if still live
- `agent-system/extensions/core/context/patterns/metadata-file-return.md`,
  `context/architecture/system-overview.md`, `context/patterns/system-defect-discrimination.md`,
  `context/formats/subagent-return.md` - doc mirrors

**Verification**:
- A hand-written `.return-meta.json` with `"status": "needs_research"` and `"artifacts": []`
  passes `validate-return-meta.sh` with no failures.
- `orchestrate-recover-outcome.sh` run against that file exits 0, emits `recovered=true`,
  `status=needs_research`, `evidence_suspect=false`.
- The vocabulary grep returns no site still listing the old six values as complete.

---

### Phase 2: Status-write and question-list write-back plumbing [COMPLETED]

**Goal**: Give the system a sanctioned way to write `researching` from a postflight call and to
persist the planner's question list durably on the task record.

**Tasks**:
- [x] Add `postflight:needs_research) STATE_STATUS="researching"; TODO_STATUS="RESEARCHING"` to
      `update-task-status.sh`'s `map_status()`, keeping the token name distinct from the existing
      `preflight:research` producer of the same state value so `git blame` and grep
      self-document which producer wrote it. *(completed)*
- [x] Add a `--research-questions=<json-array>` flag to `update-task-status.sh`, structurally
      copying `--file-scope-add`: same argument-parsing shape, same malformed-value-is-a-hard-error
      validation (a non-array or non-string-element value fails loudly, never silently), same
      operation/target-status restriction (valid only with `operation=postflight` and
      `target_status=needs_research`), and riding along inside the same state-write invocation. *(completed: verified via fixture -- malformed value and wrong-combo both exit 1)*
- [x] Write the value to a new durable `research_questions` task-record field in `state.json`,
      with **overwrite-on-write** semantics (fully replaced each time), not append. Choose the
      JSON-array shape over a joined string so the list survives structural inspection; joining
      happens at the `--focus` call site in Phase 4. *(completed: verified overwrite, not accumulation, across two successive calls; also added research_questions to context/schemas/state-schema.json's additionalProperties: false shape, a necessary correctness addition not named in this task's file list -- see Plan Deviations)*
- [x] Extend `skill_postflight_update()`'s status whitelist in `skill-base.sh` to accept
      `needs_research` alongside `researched|planned|implemented`, and add the
      `_fsa_args`-shaped block that reads `research_questions` out of the just-returned
      `.return-meta.json` and forwards it as `--research-questions=<json>`. *(completed: smoke-tested by sourcing skill-base.sh against an isolated fixture)*
- [x] Decide and record the `clamp_mode=monotonic-max` interaction: under a forced `--plan`
      dispatch, `status_vocabulary_would_regress` would skip the `planning` -> `researching`
      write. Record the intended behavior explicitly in the function's comment block -- either an
      exemption for `needs_research` or an accepted, documented limitation. Do not leave it
      undecided. *(completed: needs_research is deliberately absent from STATUS_VOCABULARY_LIFECYCLE_RANK, so the clamp can never skip its write -- confirmed by fixture test)*
- [x] Document the new `research_questions` field in
      `context/reference/state-management-schema.md` alongside `file_scope`, including its
      overwrite-on-write semantics and its single consumer. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/scripts/update-task-status.sh` - `map_status()` arm, flag parse,
  validation, state write
- `agent-system/extensions/core/scripts/skill-base.sh` - whitelist extension, question-list
  forwarding, clamp-interaction comment
- `agent-system/extensions/core/context/reference/state-management-schema.md` - document
  `research_questions`

**Verification**:
- `update-task-status.sh postflight <n> needs_research <sess> --dry-run` reports a
  `researching`/`RESEARCHING` transition and no error.
- `--research-questions` with a malformed value (non-array, or array of non-strings) exits
  non-zero with a named error.
- `--research-questions` passed with any other operation/target-status combination is rejected,
  matching `--file-scope-add`'s restriction behavior.
- After a dry-run-disabled invocation against a fixture `state.json`, the task record carries
  `research_questions` as an array; a second invocation with a different list replaces rather
  than appends.

---

### Phase 3: Postflight `needs_research` arms [COMPLETED]

**Goal**: Make a `needs_research` dispatch outcome resolve to a clean, non-halting verdict that
writes `researching` and persists the question list -- never touching the off-schema catch-all.

**Tasks**:
- [x] Insert a `needs_research)` arm into `orchestrate-cycle-postflight.sh`'s status-transition
      switch, positioned **before** the `*)` catch-all and after the
      `partial|failed|blocked)` arm. It calls `skill_postflight_update` with the
      `needs_research` target status and must not set `offschema_dispatch_status=true` or reach
      `system-defect-record.sh`. *(completed: verified end-to-end via fixture -- no OFF_SCHEMA_STATUS defect recorded, no off-schema stderr mention)*
- [x] Add a `needs_research)` arm to the verdict-resolution switch, resolving to a new sixth
      verdict value `needs_research` -- not `defer`, whose established meaning ("in-flight, retry
      the same phase next cycle") is semantically wrong here because the phase changes from plan
      to research. *(completed)*
- [x] Extend the verdict enum documented in the script's header comment block (the sole
      authoritative listing of `ok|defer|blocked|failed|ask_user`) to include `needs_research`,
      with a one-line description matching the existing entries' style, and extend the `halt`
      field's documentation to state that `needs_research` leaves `halt=false`. *(completed)*
- [x] Confirm the `next_artifact_number` advance logic treats `needs_research` correctly: no plan
      artifact was produced, so the round must not advance. Verify the existing condition
      (which advances on `researched`, or on force-invoked `planned`/`implemented`) already
      excludes `needs_research` and record that it does. *(completed: confirmed by code reading and by fixture -- next_artifact_number stayed 1 after a live needs_research postflight)*
- [x] Add a commit-message arm for `needs_research` in the postflight commit switch, or record
      explicitly why none is needed if no artifact is written. *(completed: added an arm -- state.json IS written on this path even though no plan artifact is, so a commit is needed)*
- [x] Confirm the thin lead consuming this verdict handles the new value: check
      `skill-orchestrate/SKILL.md`'s handling of the verdict field and extend it if it switches on
      the enum exhaustively. *(completed: SKILL.md's Move 3 loop uses independent if/elif guards on specific verdict values, not an exhaustive case/esac -- needs_research falls through harmlessly and the loop proceeds normally; no change needed)*

**Timing**: 1.5 hours

**Depends on**: 1, 2

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - status-transition arm,
  verdict arm, header vocabulary, commit-message arm
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - verdict handling, if it
  switches exhaustively

**Verification**:
- A fixture `.return-meta.json` with `status: needs_research` driven through
  `orchestrate-cycle-postflight.sh --dry-run` yields `verdict=needs_research`, `halt=false`.
- No `OFF_SCHEMA_STATUS` defect is recorded and `offschema_dispatch_status` stays false.
- The reported would-be state write is `researching`, and `next_artifact_number` is not advanced.

---

### Phase 4: Flip the default route and wire the question list into the research dispatch [COMPLETED]

**Goal**: Make `plan` the default first dispatch for a fresh task everywhere it is decided, and
carry the planner's questions into the follow-up research dispatch file.

**Tasks**:
- [x] Flip `orchestrate-triage-classify.sh`'s live jq classifier: `not_started` routes to `plan`,
      with its `reason` string updated to say so. *(completed)*
- [x] Flip the same `not_started` row in the `blocked`-discharge re-routing table, which reuses
      the identical status ladder against `previous_status`. *(completed)*
- [x] Flip the degraded-classifier fallback table in `orchestrate-cycle-plan.sh`: `not_started`
      moves out of the `research` arm into the `plan` arm. Leave `researching` in the `research`
      arm -- that row is now load-bearing for the `needs_research` return path. Note that
      splitting the previously-combined `not_started|researching)` case is the point of this edit. *(completed)*
- [x] Update the header comment table in `orchestrate-triage-classify.sh` documenting the
      `not_started` row, and extend the file header's "one code path" discipline note to name the
      degraded fallback table in `orchestrate-cycle-plan.sh` as a fourth site that must move in
      lockstep -- the header does not currently mention it, which is exactly how the drift risk
      arises. *(completed)*
- [x] Update `docs/architecture/orchestrate-state-machine.md`'s Complete State Table: the
      `not_started` row becomes `dispatch(plan, task_n)`, the `researching` row keeps
      `dispatch(research, task_n)` with a note naming its second producer, and a footnote
      describes the `needs_research` fork. *(completed: also added a dedicated "The needs_research Fork" subsection and a matching worked-example flow)*
- [x] Update the ASCII State Transition Diagram in the same doc: the left branch becomes
      `dispatch plan`, with a new branch drawing the `needs_research` fork from plan back to
      research and onward to plan again. *(completed)*
- [x] In `orchestrate-cycle-plan.sh`'s per-task dispatch loop, when and only when building a
      `research`-phase dispatch, read the task's `research_questions` array from `state.json`,
      join it into a single string, and pass it as `--focus "<joined>"` to
      `orchestrate-build-dispatch.sh`. No change inside `orchestrate-build-dispatch.sh` is needed:
      `--focus` is already parsed, already rendered into the dispatch body, and already
      phase-gated to `research` for the memory-retrieve hand-off. *(completed: verified end-to-end via fixture -- the joined questions reach orchestrate-build-dispatch.sh's argv as --focus, and a task with no research_questions passes no flag)*
- [x] Verify `--research` still forces research first through the existing
      `force_phases_remaining` queue, independent of the classifier default and of any
      `needs_research` machinery. This is a verification step, not a code change; record the
      evidence. *(completed: confirmed by code reading -- effective_group[$t] is set from force_phases_remaining when non-empty, unconditionally overriding triage_group[$t])*

**Timing**: 1.5 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Commit Mode**: atomic-batch

**Scope Hypothesis**: This phase asserts exactly four `not_started -> research` decision sites
(the classifier's live jq logic, the classifier's blocked-discharge table, the degraded fallback
in `orchestrate-cycle-plan.sh`, and the state-machine doc's table plus its ASCII diagram). Confirm
at implementation time with
`grep -rn 'not_started' agent-system/extensions/core/scripts/ agent-system/extensions/core/docs/`
and reconcile every hit before declaring the flip complete; an unlisted decision site is a scope
expansion to record.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` - jq classifier row,
  blocked-discharge row, header table and discipline note
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - degraded fallback table,
  `--focus` wiring at the research-dispatch build call
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - state table,
  ASCII diagram, `needs_research` footnote

**Verification**:
- `orchestrate-triage-classify.sh` against a `not_started` fixture emits group `plan`.
- The same fixture with the classifier forced to degrade emits group `plan` from the fallback
  table.
- A task with a populated `research_questions` field, dispatched to `research`, produces a
  dispatch file containing a `User focus:` block with the joined questions.
- `--research` on a fresh task still dispatches research first.

---

### Phase 5: Planner contract, extension sweep, and status prose [COMPLETED]

**Goal**: Give the planner an explicit assessment step with a narrow bar for requesting research,
and bring the status documentation in line with the two-phase default.

**Tasks**:
- [x] Add an opening assessment stage to `agents/planner-agent.md`, ahead of the existing plan
      construction stages: assess whether the task description plus what the agent can read in
      the codebase suffices to write a plan meeting plan-format.md. If yes, plan as today. If no,
      write no plan at all and return `status: needs_research` with a focused
      `research_questions` array. Explicitly forbid partial planning on the `needs_research`
      path -- it is one outcome or the other. *(completed: new Stage 1.5)*
- [x] State the bar for asking, narrowly: research is requested only when the plan would
      otherwise rest on guesses about facts an agent can establish -- external APIs, unfamiliar
      code paths, literature. Add negative examples: a description that already carries the
      defect, the evidence, the work list and the acceptance bar is a specification and needs no
      research; unfamiliarity that a targeted grep would resolve is not grounds to ask. *(completed)*
- [x] Document the `needs_research` return shape in the agent's terminal-metadata example:
      `status: "needs_research"`, empty `artifacts` array, populated `research_questions`. *(completed: new Stage 6c)*
- [x] Note in the agent contract that `needs_research` is distinct from `user_decision` -- one is
      a question for an agent to answer, the other a judgment only the user can make. *(completed: covered in Stage 1.5's negative examples, Stage 6c, and a MUST NOT bullet)*
- [x] Run the extension planner sweep required by DESIGN (d):
      `grep -rln 'planner' agent-system/extensions/*/agents/` and any manifest
      `routing_agents`/`routing_agents_hard` plan entries. The expected result is zero
      extension-declared planner agents -- `resolve_agent()` hardcodes `planner-agent` for
      `op == "plan"` regardless of task type. **Record "checked, none found" with the command and
      its empty output in the phase notes**; do not silently omit the step, and do not invent a
      target. *(completed: grep found deck-planner-agent.md/slide-planner-agent.md, but a manifest scan of every extension's routing_agents/routing_agents_hard for a "plan" op key found none naming them, and resolve_agent() itself hardcodes planner-agent for op=="plan" before ever consulting task_type -- confirmed unreachable, see progress notes)*
- [x] Update `context/standards/status-markers.md` to describe the two-phase default with
      research on demand, and note `[RESEARCHING]`'s second producer (a planner that declined to
      plan) alongside the existing `preflight:research` producer. Cross-reference
      `orchestrate-state-machine.md` for the routing detail rather than duplicating the state
      table. *(completed)*
- [x] Confirm the research-agent contract needs no change beyond acknowledging that its dispatch
      file may now carry a `User focus:` question list. Make that acknowledgement explicit if the
      contract enumerates the dispatch file's sections. *(completed: doesn't enumerate sections, but the existing focus_prompt delegation field got an explicit acknowledgement of its new source)*

**Timing**: 1.5 hours

**Depends on**: 1, 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts that zero extension-declared planner agents exist, so the
"sweep extension planner agents" instruction has an empty address space. Confirm with the grep
named above before allocating any budget to editing extension agents; if the grep returns a hit,
that is a scope expansion to record and handle, not to absorb silently.

**Files to modify**:
- `agent-system/extensions/core/agents/planner-agent.md` - assessment stage, bar for asking,
  return shape, `needs_research` vs `user_decision` distinction
- `agent-system/extensions/core/context/standards/status-markers.md` - two-phase default,
  `[RESEARCHING]`'s second producer
- `agent-system/extensions/core/agents/general-research-agent.md` - dispatch-file section
  acknowledgement, only if it enumerates sections

**Verification**:
- `lint-agent-contracts.sh` passes on the edited agent files, including Check F's
  artifacts-template comparison.
- The extension sweep command and its output are recorded in the phase notes.
- `status-markers.md` no longer describes research as an unconditional first phase.

---

### Phase 6: Fixture tests and full gate run [COMPLETED]

**Goal**: Pin both routes with fixtures in the existing paired-fixture style, and run the full
gate green.

**Tasks**:
- [x] In `tests/test-orchestrate-triage-classify.sh`, add fixtures asserting `not_started` routes
      to `plan` (live jq path) and `researching` still routes to `research`. Follow the existing
      paired sandbox-probe / mt-engine fixture convention so both code paths see the same status,
      rather than introducing a new fixture style. *(completed: fixed the sandbox probe + fixture 105's expected group; the pre-existing researching->research mutation-check fixture already covered the surviving row; also added a dedicated blocked-discharge previous_status=not_started fixture)*
- [x] Add a fixture pinning the degraded-classifier fallback table specifically -- the path taken
      only when the classifier script exits non-zero. This is the drift risk the classifier's own
      header discipline does not currently cover. *(completed: Group 13 in test-orchestrate-cycle-plan.sh, stubs orchestrate-triage-classify.sh to exit non-zero)*
- [x] In `tests/test-orchestrate-cycle-postflight.sh`, add the hazard fixture: a
      `needs_research` `.return-meta.json` must yield `verdict=needs_research`, `halt=false`, no
      `OFF_SCHEMA_STATUS` defect recorded, a `researching` state write, and no
      `next_artifact_number` advance. Read the existing `researched` fixture first and use it as
      the direct template. *(completed: Acceptance (6), modeled on Acceptance (4a))*
- [x] Add the force-invoked variant of that fixture, asserting whichever clamp behavior Phase 3
      recorded as intended. *(completed: Acceptance (7))*
- [x] In `tests/test-orchestrate-cycle-plan.sh`, add a fixture asserting that a task carrying
      `research_questions` and dispatched to `research` produces a dispatch file with a
      `User focus:` block containing the joined questions, and that a task without the field
      passes no `--focus`. Read the existing `not_started`/`researched` fixtures first as the
      template. *(completed: Group 14, tests the wiring into --focus's argv; the flag's own rendering into "User focus:" is orchestrate-build-dispatch.sh's own contract, already covered by test-orchestrate-build-dispatch.sh)*
- [x] Add an end-to-end assertion for the acceptance criterion: a specification-shaped task goes
      `not_started -> planned` in one dispatch with a plan that passes `validate-artifact.sh`. *(completed: Acceptance (8) in test-orchestrate-cycle-postflight.sh)*
- [x] Run the full gate set: the three modified test scripts, `validate-artifact.sh` on this
      plan, `lint-agent-contracts.sh`, `check-task-references.sh`, and any repo-level shell lint
      the gate normally includes. All green before the phase closes. *(completed: 38+96+57=191 fixture passes across the three suites, validate-artifact.sh passes on this plan, lint-agent-contracts.sh 101/101, check-task-references.sh 0 occurrences, and 8 additional lint-*.sh scripts under scripts/lint/ all green -- see progress notes)*
- [x] Confirm no task-number reference was introduced anywhere under `agent-system/**` --
      deliverables cite durable anchors (filenames, section headings), never task numbers. *(completed: check-task-references.sh's deployed copy scans agent-system/extensions directly -- 0 unexempted occurrences)*

**Timing**: 2 hours

**Depends on**: 3, 4, 5

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts three test files carry all the fixtures needed. Confirm
by reading each file's existing `not_started` and `researched` cases before writing new ones; if a
fourth test file turns out to cover any of these paths, that is a scope expansion to record.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh` - default-flip
  and degraded-fallback fixtures
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - hazard
  fixture and force-invoked variant
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - focus-wiring
  fixtures

**Verification**:
- All three test scripts exit 0.
- `bash .claude/scripts/validate-artifact.sh` passes on this plan.
- `lint-agent-contracts.sh` and `check-task-references.sh` pass.
- The full gate run is green with no skipped suites.

---

## Testing & Validation

- [x] A `.return-meta.json` with `status: needs_research` and empty artifacts passes
      `validate-return-meta.sh` and is recovered by `orchestrate-recover-outcome.sh` with
      `recovered=true`, `evidence_suspect=false`. *(verified: fixture in Phase 1, plus the manual
      end-to-end scratch fixture reproduced in Phase 3's progress notes)*
- [x] `orchestrate-cycle-postflight.sh` on that outcome yields `verdict=needs_research`,
      `halt=false`, no `OFF_SCHEMA_STATUS` defect, and a `researching` state write. *(verified:
      Phase 6's Acceptance (6)/(7) fixtures in test-orchestrate-cycle-postflight.sh)*
- [x] `orchestrate-triage-classify.sh` routes `not_started` to `plan` on both the live jq path
      and the degraded fallback path. *(verified: test-orchestrate-triage-classify.sh's sandbox
      probe/fixture 105, plus Group 13 in test-orchestrate-cycle-plan.sh for the fallback path)*
- [x] A task carrying `research_questions` produces a research dispatch file with a `User focus:`
      block containing the joined questions. *(verified: Group 14 in test-orchestrate-cycle-plan.sh
      for the wiring; the rendering itself is orchestrate-build-dispatch.sh's own pre-existing,
      already-tested contract)*
- [x] `--research` on a fresh task dispatches research first, unchanged. *(verified by code
      reading: effective_group[$t] is sourced from force_phases_remaining when non-empty,
      unconditionally overriding the classifier's triage_group[$t] -- see Phase 4's progress notes)*
- [x] A specification-shaped task reaches `[PLANNED]` in one dispatch with a plan passing
      `validate-artifact.sh`, and `[COMPLETED]` in a second. *(the [PLANNED] half is verified by
      Phase 6's Acceptance (8); the [PLANNED] -> [COMPLETED] implement-phase transition is
      entirely pre-existing, unmodified code this task never touches, and is already covered by
      the repo's own pre-existing implement-phase test coverage)*
- [x] `lint-agent-contracts.sh`, `check-task-references.sh`, and the full gate run are green.
      *(verified: see Phase 6's progress notes for the full gate-run enumeration and results)*

## Artifacts & Outputs

- `agent-system/extensions/core/context/formats/return-metadata-file.md` - `needs_research` in
  the status enum with a field note
- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh`,
  `validate-return-meta.sh`, `validate-handoff.sh` - vocabulary gates admit the new value
- `agent-system/extensions/core/scripts/update-task-status.sh`, `skill-base.sh` -
  `postflight:needs_research` mapping and the `--research-questions` write-back
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - status arm, verdict
  arm, extended verdict enum
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh`,
  `orchestrate-cycle-plan.sh` - default routing flip and `--focus` wiring
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - updated state
  table and diagram
- `agent-system/extensions/core/agents/planner-agent.md` - assessment stage and asking bar
- `agent-system/extensions/core/context/standards/status-markers.md`,
  `context/reference/state-management-schema.md`, and four vocabulary doc mirrors
- Three extended fixture test scripts under
  `agent-system/extensions/core/scripts/tests/`

## Rollback/Contingency

Every phase commits separately, so `git revert` of individual phase commits is the primary
rollback. The safe partial-revert order is the reverse of the dependency order: revert Phase 4
first to restore the `not_started -> research` default, which alone returns the system to its
current behavior even if the `needs_research` machinery from Phases 1-3 stays in place (unused
plumbing that nothing invokes, since no planner will return the verdict until Phase 5's contract
lands). Reverting Phase 5 without Phase 4 is also safe for the same reason. Never revert Phase 3
while Phase 4 is live -- that combination reintroduces the halting off-schema hazard on the very
first planner-declined task. If the flip must be disabled urgently mid-implementation, reverting
the single `not_started` row in the live classifier plus the degraded fallback table is the
minimal change that restores the old default.
