# Implementation Plan: Task #651

- **Task**: 651 - Make the orchestration, not the task, the unit that closes on the full gate battery, for every invocation shape including a batch of one
- **Status**: [IMPLEMENTING]
- **Effort**: 10 hours
- **Dependencies**: 610 (COMPLETED), 650 (COMPLETED); 599 (NOT STARTED — Phase 6 territory edge, see Risks); 564 (adjacent tier-check edit, see Risks)
- **Research Inputs**: specs/651_orchestration_close_owns_full_battery/reports/01_orchestration-close-owns-battery.md
- **Artifacts**: plans/01_orchestration-close-owns-battery.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The orchestration engine already relocates the complete gate battery to a once-per-invocation
Move 4 close for every invocation shape, including a batch of one — that mechanism shipped with
the gate-ceiling-fit work and the touched-path verification entry point. What has not moved is
everything built around it: the plan-authoring vocabulary still tells a planner the final phase
runs the battery itself, the batch-gate contract narrates its own design history instead of
stating the current design, a red close battery binds nothing to the tasks it covers, an
orchestration that never reaches Move 4 leaves an undischarged obligation nobody reports, and a
consumer repository's own closing gate has a reserved declaration field with no reader. This plan
closes those five gaps in a linear chain, ending with a redeploy and the orchestration-close
battery itself.

### Premise Re-Validation

Checked each flagged line of the dispatch description against the research report and live state,
per the Carried-Figure Discipline:

- **"Mechanism A is gated on `.task_numbers | length > 1`"** — STALE, confirmed by direct read.
  `scripts/orchestrate-cycle-plan.sh:2864-2878` appends `--batch-gate-deferral` for every
  `implement`-phase dispatch with no task-count condition, and the file's own comment at line 3212
  states the gate is gone. Deliverable 1's mechanical half needs no edit; what remains is a prose
  surface that still narrates the removal as history rather than stating the design (Phase 1).
- **"Settle the vocabulary in research"** — settled: `full` stays the single top tier token, its
  meaning amended, no fifth tier value. `scripts/validate-artifact.sh:602` matches
  `^(prose|local|interface|full)$`, so the amended invariant needs zero enum change (Phase 2).
- **"Depends on the touched-path verification entry point record"** — satisfied: that task is
  `[COMPLETED]`, `scripts/verify-touched.sh` exists and is the named scoped check.
- **"SOURCE STORE IS THE EDIT TARGET"** — holds. Every edit below names a path under
  `agent-system/extensions/core/**`; the final phase redeploys.
- **`verification_scope.closing_gate` reserved for this record** — confirmed present at
  `context/standards/repo-level-declarations.md:132` and in `scripts/lib/verification-scope-lib.sh`'s
  header, unread by any function (Phase 6).

Two findings beyond the research report, from this planning pass:

- `context/contracts/batch-gate-stage.md`'s invariance paragraph states the current design but
  does so in version-relative phrasing ("no longer gated on", "superseded a task-count-gated
  predecessor", "the gap the task-count gate used to leave open"), which
  `rules/no-record-versioning-in-deliverables.md` forbids for any file landing under
  `agent-system/**`. Deliverable 1's "rewrite to state the current design only" is therefore
  genuinely owed, not discharged.
- `context/patterns/orchestrate-batch-results-template.md:166` still says the batch-gate result is
  "absent entirely on ... a single-task batch that never deferred" — a shape that no longer
  exists. Same sweep, Phase 1.

### Research Integration

The plan adopts all five research Decisions verbatim: vocabulary option (a) for Deliverable 2; the
`^FINDING `-emission contract for a declared `closing_gate`; Deliverable 3 resolved by observation
with an implementation-time re-verification step rather than a new fallback mechanism; and
Deliverable 4's durable-record floor plus attributed-cause-only status binding, with the
hold-every-implicated-task alternative recorded as rejected. Deliverables 1 and 6 are treated as
mechanically complete, with Phase 1 confined to the prose surfaces that still misdescribe them and
a read-only confirmation that the owed-sweep fields exist.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; `specs/ROADMAP.md` was not consulted.

## Goals & Non-Goals

**Goals**:

- Every surface that tells a planner, a reviser, or an implementation agent how the final phase
  verifies states the amended invariant: the complete gate set is owed once per orchestration,
  discharged at Move 4, never forgiven.
- A red close battery leaves a durable, attributed, per-task record with an explicit operator
  remedy, visible in the consolidated output.
- A task that is itself the attributed cause of a red close does not stay `[COMPLETED]` on the
  strength of its own scoped check alone.
- An orchestration that ends without reaching Move 4 leaves an open, reported obligation that a
  later clean close discharges.
- A consumer repository's own declared closing gate is what Move 4 runs there.
- Every prose surface describing the above states the current design only, with no version-relative
  phrasing and no task-number references under `agent-system/**`.

**Non-Goals**:

- Removing or weakening the battery. This plan relocates ownership; the battery still runs at
  least once per invocation that implemented anything.
- Building a non-orchestrated implementation fallback path. No such live path exists (Phase 1
  re-verifies this); the interrupted-invocation case is handled in Phase 5 instead.
- Introducing a fifth verification tier value.
- Editing `scripts/orchestrate-build-dispatch.sh` or `scripts/tests/test-orchestrate-build-dispatch.sh`
  at all — that territory belongs to the project-sources narrowing record, and Phase 6 is designed
  to consume its declaration surface without touching its files.
- Narrowing Move 4's own run with `--gate8-touched`. The close stays the invocation's one
  unconditional full-coverage signal.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Phase 4's `[COMPLETED]` demotion is a second sanctioned exception to a terminal state; a bug there could demote a task that is not the attributed cause | H | M | Gate the demotion on a four-way conjunction (nonzero `gate_exit_code`, non-empty per-task attributed set, not `--dry-run`, task present in this invocation's `completed_tasks`); implement it in a sibling script with its own test suite rather than inside the gate script; model the record and the status-markers entry on the existing commit-landing demotion precedent |
| Phase 6 and the project-sources narrowing record both want `verification_scope`'s schema prose | M | M | Phase 6 adds only the `closing_gate` row and the missing `Decisions Settled` heading; it never edits the directive composer or its test. If that record lands first, re-read the schema section before editing |
| Phase 2's edits touch the same tier check region as the validate-artifact tier-justification false-positive record | M | L | Phase 2 makes no functional change to `scripts/validate-artifact.sh` — comment-audit only — so the two records cannot collide on behavior |
| A declared `closing_gate` command that does not emit `^FINDING ` lines silently yields an empty finding set, reading as clean | H | M | Phase 6 fails loud rather than open on a declared-but-unusable command: a nonzero exit with no parseable `FINDING ` line becomes a batch-level unattributed finding, never a clean verdict |
| Editing any `context/**` markdown moves a `line_count` that `index-entries.json` declares and `check-extension-docs.sh` Rule R fails on by default | M | H | Every phase that edits a `context/**`, `rules/**`, or `agents/**` file declares `agent-system/extensions/core/index-entries.json` in its own `Files to modify` and runs `generate-context-line-counts.sh --write` in that same phase |
| The Deliverable 3 "no live non-orchestrated path" finding is a claim about two directories that any later addition can invalidate | M | L | Phase 1 re-runs the two greps before recording the finding and treats a new hit as cause to re-open the deliverable rather than trusting the report |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |
| 7 | 7 | 6 |

Phases within the same wave can execute in parallel. This plan is a deliberate single chain:
Phases 1, 3, 5, and 6 all edit `context/contracts/batch-gate-stage.md`, Phases 3, 5, and 6 all
edit `scripts/orchestrate-batch-gate.sh` and `scripts/tests/test-orchestrate-batch-gate.sh`, and
every documentation phase edits `index-entries.json`. Running any two of them concurrently would
be a two-writer collision on the same files, so no wave carries more than one phase.

---

### Phase 1: State the Shipped Deferral's Current Design [COMPLETED]

**Goal**: Every prose surface describing the batch-gate deferral states the design as it is, with
no version-relative narration; the settled answer for the non-orchestrated path is recorded; the
owed-sweep discharge fields are confirmed present.

**Tasks**:
- [x] Re-run the two scope greps before writing anything: every implementation-agent name
      (`general-implementation-agent`, `email-implementation-agent`, `lean-implementation-agent`,
      `nix-implementation-agent`, `neovim-implementation-agent`) across
      `agent-system/extensions/*/skills/*/SKILL.md` and `agent-system/extensions/*/commands/*.md`,
      and `command-route-agent.sh`'s own call sites. Record the counts in the phase's verification
      notes. If any hit appears outside `skill-orchestrate`, STOP and re-open the non-orchestrated
      path question rather than recording the settled finding below. *(completed: implementation-agent
      name hits confined to skills/skill-orchestrate/SKILL.md and one documentation pointer in
      skills/skill-git-workflow/SKILL.md referencing general-implementation-agent.md by filename,
      not a dispatch call site; command-route-agent.sh's only call site is
      orchestrate-cycle-plan.sh:2347. Zero hits outside skill-orchestrate's own Move loop; settled
      finding confirmed, not re-opened.)*
- [x] Rewrite `context/contracts/batch-gate-stage.md`'s "Single-task invariance" paragraph to state
      the current design only: `orchestrate-cycle-plan.sh`'s `build_args` composition appends
      `--batch-gate-deferral` for every `implement`-phase dispatch; a batch of one defers to this
      stage exactly like a multi-task batch; the batch-gate-pending marker plus the two entry
      guards are what make that safe. Remove every version-relative construction ("no longer",
      "superseded a ... predecessor", "used to leave open", "as a fallback for that one shape").
      *(completed)*
- [x] Add a short subsection to the same file recording the settled scope answer: every
      implement-phase dispatch for every task type routes through `skill-orchestrate`'s Move loop,
      so there is no separate non-orchestrated implementation path owing its own inline battery;
      the residual case is an orchestration that never reaches Move 4, owned by the obligation
      mechanism (Phase 5). State the re-verification trigger explicitly: a new skill or command
      that dispatches an implementation agent re-opens this question. *(completed)*
- [x] Correct `context/patterns/orchestrate-batch-results-template.md`'s rendering note so it no
      longer claims the batch-gate result is absent on a single-task batch; the result renders
      whenever an implement dispatch occurred. *(completed)*
- [x] Confirm, read-only, that `scripts/orchestrate-batch-gate.sh` carries
      `owed_discharged_count`, `owed_open_count`, and `owed_open_roster` in its `batch_gate`
      record and that the results template renders the owed-sweep sub-result. Record the
      confirmation; make no edit if both hold. *(completed: both confirmed present at
      scripts/orchestrate-batch-gate.sh:243-245 and
      context/patterns/orchestrate-batch-results-template.md:195-211; no edit made.)*
- [x] Reconcile `index-entries.json` line counts for every edited context file:
      `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write`.
      *(completed: 2 line_count values reconciled.)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over the two
edited markdown files and `index-entries.json` is the covering check — it resolves each path,
classifies whatever it cannot resolve, and runs the narrowed pass itself.

**Scope Hypothesis**: exactly two prose surfaces still misdescribe the shipped deferral
(`batch-gate-stage.md`'s invariance paragraph and
`orchestrate-batch-results-template.md`'s rendering note). Confirm with
`grep -rn "length > 1\|never deferred\|no longer gated" agent-system/extensions/core/context/`
before editing, and widen the edit set rather than the claim if a third surface appears.

**Files to modify**:
- `agent-system/extensions/core/context/contracts/batch-gate-stage.md` - invariance paragraph
  rewritten to state the current design; new settled-scope subsection for the non-orchestrated path
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` - stale
  single-task-absence claim corrected
- `agent-system/extensions/core/index-entries.json` - `line_count` reconciliation for both edited
  context files (coupled generated surface; `check-extension-docs.sh` Rule R fails on drift by
  default)

**Verification**:
- Both greps re-run and their results recorded in the phase notes, including the zero-hits-outside-
  `skill-orchestrate` confirmation.
- `grep -rn "no longer gated\|superseded a task-count\|used to leave open" agent-system/extensions/core/context/contracts/batch-gate-stage.md`
  returns nothing.
- `bash agent-system/extensions/core/scripts/verify-touched.sh <the three paths>` exits 0.
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` reports no Rule R drift for
  the edited files.

---

### Phase 2: Amend the Final-Phase Invariant Vocabulary [COMPLETED]

**Goal**: No authoring surface tells a planner or an implementation agent to run the complete gate
set inside a task. `full` remains the top tier token; its stated meaning under `/orchestrate` is
discharge at the orchestration close.

**Tasks**:
- [x] Amend `context/formats/plan-format.md`'s `## Verification Tiers` section: the `full` row's
      "Nothing is deferred past this tier" cell, the "`**Tier Justification**:`" subsection's "The
      final phase's `full` is mandated by the invariant below" sentence, and the non-negotiable
      invariant paragraph. The invariant that survives: the complete gate set runs once before the
      invocation's tasks are done, deferred and never forgiven. What changes is who discharges it —
      under `/orchestrate`, a final phase declares `full` and its own in-dispatch obligation is the
      scoped touched-path check plus an explicit statement of deferral to the orchestration close.
      Keep the existing "not a fifth tier" and "`--skip-slow` is never a tier" rulings intact.
- [x] Amend the paragraph that says "A phase declaring `full` names `bash .claude/scripts/verify-deploy.sh`
      ... in its own verification criteria" so the deferred form is the documented shape for an
      orchestrated dispatch, and the direct form is what a standalone, non-orchestrated run meets.
- [x] Update `rules/plan-format-enforcement.md`'s per-phase-fields checklist so its pointer text
      matches the amended wording, keeping its honest advisory-enforcement-level statements.
      *(completed: confirmed, read-only -- this file carries no restatement of the final-phase/
      battery invariant, only a pointer to plan-format.md's section; no edit required.)*
- [x] Edit `agents/planner-agent.md` at both stale sites: the Stage 4 MUST-NOT bullet that reads
      "the full gate set still runs before a phase closes and before the task completes", and
      Stage 6a's instruction that "the final phase itself declares `**Verification Tier**: full`,
      names the complete gate set in its own verification criteria". Replace with the
      deferral-aware obligation: the final phase still declares `full`, and its own verification
      criteria name the scoped check plus the explicit deferral to the orchestration close, never
      an independent full-battery invocation as the phase's own criterion.
- [x] Edit `agents/general-implementation-agent.md`'s "Batch Gate Deferral" subsection and its
      matching MUST-NOT bullet: drop the "(final phase only)" scoping, which is false whenever an
      intermediate phase also declares `full` — the directive names every qualifying phase.
- [x] Confirm `agents/reviser-agent.md` carries no duplicate copy of the final-phase contract and
      still defers correctly by reference; edit only if a stale restatement is found.
- [x] Audit comments around `scripts/validate-artifact.sh`'s tier check and its
      Tier-Justification-measurement check for any inline comment restating the pre-amendment
      meaning of `full`. Comment-only; make no functional change to the accepted-value enum.
- [x] Reconcile `index-entries.json` line counts.
- [x] Run `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` and
      `bash agent-system/extensions/core/scripts/tests/test-validate-artifact.sh`. *(completed: lint 0
      failed/12 pre-existing warnings; test-validate-artifact.sh 146 passed, 0 failed; an extra hit
      discovered beyond the Scope Hypothesis -- docs/guides/user-guide.md:439 -- was also amended,
      per the hypothesis's own widen-the-edit-set instruction.)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over the
edited paths is the covering check, together with
`bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh`, the agent-contract lint
the two agent-file edits are subject to.

**Scope Hypothesis**: five authoring surfaces carry the pre-amendment framing — `plan-format.md`
(two sites), `rules/plan-format-enforcement.md`, `agents/planner-agent.md` (two sites), and
`agents/general-implementation-agent.md` — with `agents/reviser-agent.md` and
`scripts/validate-artifact.sh` needing confirmation only. Confirm with
`grep -rn "names the complete gate set\|final phase itself declares\|mandated by the invariant\|before a phase closes and before\|final phase only" agent-system/extensions/core/`
before editing, and treat an extra hit as an extra edit site rather than adjusting the claim.

**Files to modify**:
- `agent-system/extensions/core/context/formats/plan-format.md` - `full` tier row, the
  Tier-Justification subsection's final-phase sentence, the non-negotiable invariant paragraph, and
  the "names `verify-deploy.sh` in its own criteria" paragraph
- `agent-system/extensions/core/rules/plan-format-enforcement.md` - checklist pointer text aligned
  to the amended vocabulary
- `agent-system/extensions/core/agents/planner-agent.md` - the two stale final-phase instructions
- `agent-system/extensions/core/agents/general-implementation-agent.md` - deferral subsection and
  MUST-NOT bullet de-scoped from final-phase-only
- `agent-system/extensions/core/scripts/validate-artifact.sh` - comment audit only, no functional
  change
- `agent-system/extensions/core/index-entries.json` - `line_count` reconciliation

**Verification**:
- `grep -rn "names the complete gate set\|final phase only" agent-system/extensions/core/agents/`
  returns nothing.
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` exits 0.
- `bash agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` passes, with the
  pre-existing accepted-value enum unchanged.
- `bash agent-system/extensions/core/scripts/verify-touched.sh <the edited paths>` exits 0.
- A hand-check that `scripts/validate-artifact.sh` still rejects an untiered phase and accepts a
  final phase written in the amended form (one fixture each, run directly).

---

### Phase 3: Durable Attributed Per-Task Record for a Red Close [NOT STARTED]

**Goal**: A red close battery writes a durable, append-only, attributed record per implicated task,
rendered in the consolidated output with an explicit operator remedy.

**Tasks**:
- [ ] Add a per-task red-close record writer to `scripts/orchestrate-batch-gate.sh`, sited
      immediately after the Attribute step (which already holds each task's attributed finding set,
      so no new attribution logic is added). For every task with a non-empty attributed set when
      `gate_exit_code` is nonzero and this is not `--dry-run`, append one row to that task's
      `records/close-battery-red.jsonl`, resolving the task directory with the same
      `find specs -maxdepth 1 -type d -name "${padded}_*"` glob the owed-sweep step already uses.
- [ ] Declare the row shape as a deliberate sibling of `records/full-sweep-owed.jsonl`'s, not a
      divergent copy: same `recorded_ts` / `discharged_ts`-null-until-paid convention, plus
      `session_id`, `gate_exit_code`, and the attributed `findings` array. Append-only; never
      deleted; the only mutation ever applied is a later clean close's discharge stamp.
- [ ] Make the append idempotent per session: a re-run of the same session's close does not
      duplicate an open row for the same task, mirroring `unmapped-fallback-lib.sh`'s own
      open-row-exists no-op.
- [ ] Carry the new counts in the `batch_gate` record: `close_red_recorded_count` and a
      `close_red_roster` array of `{task, path, finding_count}`.
- [ ] Add a "Red-Close Per-Task Record" section to `context/contracts/batch-gate-stage.md`
      documenting the schema, the write gate, and the discharge rule; amend that file's
      "no task's own state is touched" item so it states what this stage now writes (a per-task
      record under the task's own `records/`) and what it still does not touch (that task's
      `state.json` entry — Phase 4 moves that boundary, and this phase's edit must not claim it
      early).
- [ ] Extend `context/patterns/orchestrate-batch-results-template.md`'s Batch Gate Stage Result
      with a red-close sub-result: the per-task roster and the explicit operator remedy (re-run the
      named scoped check for that task's own files, fix, then re-run the close to discharge the
      row).
- [ ] Extend `scripts/tests/test-orchestrate-batch-gate.sh`: a seeded red close writes exactly one
      row per attributed task and none for an unattributed-only finding; a `--dry-run` red close
      writes nothing; a clean close writes nothing; a repeat close does not duplicate an open row.
- [ ] Reconcile `index-entries.json` line counts.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over the
edited script, its suite, and the two context files is the covering check — it resolves
`orchestrate-batch-gate.sh` to its own suite and runs that narrowed pass itself.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-batch-gate.sh` - per-task red-close record
  writer and the two new `batch_gate` fields
- `agent-system/extensions/core/scripts/tests/test-orchestrate-batch-gate.sh` - four new cases
- `agent-system/extensions/core/context/contracts/batch-gate-stage.md` - new record section; the
  no-status-touch item amended to match what is now written
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` - red-close
  sub-result and operator remedy
- `agent-system/extensions/core/index-entries.json` - `line_count` reconciliation

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-batch-gate.sh` passes,
  including the four new cases.
- A seeded red close in a scratch fixture produces exactly one `close-battery-red.jsonl` row for
  the attributed task, with `discharged_ts: null`, and the `batch_gate` record carries
  `close_red_recorded_count` matching the roster length.
- `bash agent-system/extensions/core/scripts/verify-touched.sh <the edited paths>` exits 0.

---

### Phase 4: Bind the Close Battery's Verdict to the Attributed Task [NOT STARTED]

**Goal**: A task that is itself the attributed cause of a red close does not remain `[COMPLETED]`
on the strength of its own scoped check; every other implicated task keeps its status and carries
Phase 3's record. The rejected alternative is recorded.

**Tasks**:
- [ ] Add a sibling script `scripts/orchestrate-close-status-bind.sh`, invoked in Move 4
      immediately after the batch gate stage (the same foreground, sub-second siting
      `orchestrate-conclusion-roadmap.sh` already uses). It reads `batch_gate.attributed` and
      `batch_gate.close_red_roster` from the multi-task state file and performs the status binding
      through the sanctioned status writer — keeping `orchestrate-batch-gate.sh`'s own "never reads
      or writes `specs/state.json`" contract intact. Implementing the binding as a script rather
      than as a Move 4 prose instruction is deliberate: advisory prose is not a mechanism.
- [ ] Gate the demotion on a four-way conjunction: `gate_exit_code` nonzero, that task's own
      attributed finding set non-empty, not `--dry-run`, and the task present in this invocation's
      `completed_tasks`. A task attributed to nothing, or implicated only through the batch-level
      unattributed set, keeps `[COMPLETED]` and carries Phase 3's record.
- [ ] Demote a qualifying task to `[PARTIAL]` with a named reason naming the close battery and the
      attributed findings, following the shape of the existing commit-landing demotion rather than
      inventing a new status value or a new writer.
- [ ] Record the second sanctioned exception in `context/standards/status-markers.md`'s
      `[COMPLETED]` subsection, alongside the existing commit-landing exception: same structure,
      the gate stated explicitly, and the statement that every other outcome leaves `[COMPLETED]`
      untouched.
- [ ] Record the rejected alternative in `context/contracts/batch-gate-stage.md`: holding every
      implicated task's completion open pending a green close, rejected because it couples one
      task's completion to unrelated siblings' files under concurrency — the attribution hazard the
      shared-capture design already argues against.
- [ ] Extend `context/patterns/orchestrate-batch-results-template.md` so a demotion is visible in
      the consolidated output, not only in `state.json`.
- [ ] Update `skills/skill-orchestrate/SKILL.md`'s Move 4 to invoke the new script at the stated
      siting.
- [ ] Add `scripts/tests/test-orchestrate-close-status-bind.sh`: an attributed-cause completed task
      is demoted; an unattributed-only task is not; a clean close demotes nothing; a `--dry-run`
      demotes nothing; a task not in `completed_tasks` is untouched.
- [ ] Register the new script and the new suite wherever this repository requires registration
      (extension manifest script list via `sync-manifest-scripts.sh`, and the suite inventory
      `run-all.sh` reads), then reconcile `index-entries.json` line counts.

**Timing**: 2 hours

**Depends on**: 3

**Verification Tier**: interface

**Tier Justification**: the new script's call site spans `skill-orchestrate/SKILL.md` and the
manifest/suite registration surfaces, so the covering check is
`bash agent-system/extensions/core/scripts/verify-touched.sh` over every edited path plus
`bash agent-system/extensions/core/scripts/check-extension-docs.sh` for the registration surfaces.

**Scope Hypothesis**: a new script in this extension requires registration in exactly two places
(the extension manifest's script list and the test-suite inventory). Confirm by reading
`sync-manifest-scripts.sh`'s own contract and `run-all.sh`'s suite discovery before adding the
script, and reconcile whatever registration those two actually require rather than assuming this
count.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-close-status-bind.sh` - new: the gated
  demotion executor
- `agent-system/extensions/core/scripts/tests/test-orchestrate-close-status-bind.sh` - new suite
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Move 4 invocation at the
  stated siting
- `agent-system/extensions/core/context/standards/status-markers.md` - the second sanctioned
  exception to the completed terminal state
- `agent-system/extensions/core/context/contracts/batch-gate-stage.md` - status-binding boundary and
  the rejected alternative
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` - demotion
  rendering
- `agent-system/extensions/core/manifest.json` - new-script registration
- `agent-system/extensions/core/index-entries.json` - `line_count` reconciliation

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-close-status-bind.sh` passes
  all five cases.
- A seeded red close against a scratch fixture demotes only the attributed-cause task, and
  `--dry-run` over the same fixture mutates nothing.
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` reports no missing-script or
  Rule R drift.
- `bash agent-system/extensions/core/scripts/verify-touched.sh <the edited paths>` exits 0.

---

### Phase 5: Report and Discharge an Interrupted Orchestration's Obligation [NOT STARTED]

**Goal**: An orchestration that ends without running its close battery leaves an open, reported
obligation; a later clean close discharges it and says so.

**Tasks**:
- [ ] Add a roster reader to `scripts/lib/batch-gate-marker-lib.sh` — one function returning every
      marker under the repository with its session, age, and declared `task_numbers`, split by the
      staleness window. Keep the library's fail-safe contract: no `exit`, no shell options, every
      malformed read treated as stale.
- [ ] Surface a stale, undischarged marker as an open obligation at the invocation's own start,
      where `orchestrate-cycle-plan.sh` already sources the marker library and writes this
      session's marker: record the roster into the multi-task state file (a
      `close_battery_obligations` key) rather than only logging it, so the consolidated output can
      render it.
- [ ] Discharge at Move 4: in `scripts/orchestrate-batch-gate.sh`, when `gate_exit_code` is 0 and
      this is not `--dry-run`, the complete unnarrowed run just performed covers the whole tree, so
      remove every STALE foreign marker as paid and report what was owed and that it was paid —
      alongside the owed-sweep line this stage already prints. Never remove a non-stale marker: a
      live sibling session still owns it.
- [ ] Discharge Phase 3's open `close-battery-red.jsonl` rows on the same clean-close condition,
      stamping `discharged_ts` exactly as the owed-sweep step does, and report them in the same
      consolidated line.
- [ ] Extend `context/contracts/batch-gate-stage.md` with an "Open Close Obligations" section: what
      an interrupted invocation leaves behind, who reports it, who discharges it, and why removal
      is the discharger's job alone.
- [ ] Extend `context/patterns/orchestrate-batch-results-template.md` to render the obligation
      roster and its discharge.
- [ ] Extend `scripts/tests/test-batch-gate-pending-marker.sh` (roster reader, staleness split) and
      `scripts/tests/test-orchestrate-batch-gate.sh` (stale foreign marker removed on a clean
      close; left in place on a red close, a `--dry-run`, and when non-stale).
- [ ] Reconcile `index-entries.json` line counts.

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over the
edited library, the two scripts, their two suites, and the two context files is the covering
check — it resolves each to its own suite and runs that narrowed pass.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/batch-gate-marker-lib.sh` - roster reader
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - record the obligation roster
  into the multi-task state file at the marker-writing point
- `agent-system/extensions/core/scripts/orchestrate-batch-gate.sh` - stale-marker and red-row
  discharge on a clean close, with reporting
- `agent-system/extensions/core/scripts/tests/test-batch-gate-pending-marker.sh` - roster cases
- `agent-system/extensions/core/scripts/tests/test-orchestrate-batch-gate.sh` - discharge cases
- `agent-system/extensions/core/context/contracts/batch-gate-stage.md` - Open Close Obligations
  section
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` - obligation
  rendering
- `agent-system/extensions/core/index-entries.json` - `line_count` reconciliation

**Verification**:
- Both suites pass, including the new roster and discharge cases.
- A scratch fixture with a seeded stale foreign marker: a clean close removes it and reports it as
  paid; a red close, a `--dry-run`, and a non-stale marker each leave it in place.
- An open `close-battery-red.jsonl` row from a prior red close is stamped by the next clean close
  and reported.
- `bash agent-system/extensions/core/scripts/verify-touched.sh <the edited paths>` exits 0.

---

### Phase 6: Run the Consumer Repository's Own Declared Closing Gate [NOT STARTED]

**Goal**: Move 4 runs what the repository declares. `verification_scope.closing_gate` gains a
reader and a consumer, with the same fail-open posture every sibling field already has.

**Tasks**:
- [ ] Re-read `context/standards/repo-level-declarations.md`'s `verification_scope` section before
      editing, in case the project-sources narrowing record landed its own `project_gates` row
      first.
- [ ] Add `verification_scope_closing_gate` to `scripts/lib/verification-scope-lib.sh`: prints the
      declared command string, or nothing when absent or malformed. Keep the library's absolute
      fail-open posture and its `_vsl_`-prefixed internals; update the header's function inventory
      and drop `closing_gate` from the reserved-but-unread list.
- [ ] Consume it in `scripts/orchestrate-batch-gate.sh`: when a `closing_gate` command is declared
      for the resolved project root, both the Capture and the Confirm snapshots run that command
      instead of `verify-deploy.sh --findings`; when absent, behavior is byte-for-byte today's.
      Keep the existing Capture/Confirm/Attribute pipeline unmodified — the declared command's
      `^FINDING `-prefixed output is what makes that possible.
- [ ] Fail loud, not open, on a declared-but-unusable command: a nonzero exit producing no
      parseable `FINDING ` line becomes a batch-level unattributed finding naming the declared
      command, never a clean verdict. Record this as the one deliberate exception to the
      declaration surface's otherwise-absolute fail-open posture, and say why: a silently empty
      finding set from a repository's own closing gate reads as green.
- [ ] Document the field in `context/standards/repo-level-declarations.md`: a `closing_gate` schema
      bullet, a row in the `verification_scope` fail-open table, the `^FINDING `-emission contract,
      and the loud-failure exception. Add the missing `## Decisions Settled` heading that section's
      existing cross-reference already points at, recording the `project_gates`/`closing_gate`
      reservation decisions — or remove the dangling pointer if the heading is not worth adding.
- [ ] Note the consumption in `context/contracts/batch-gate-stage.md`'s Evidence Base section: what
      the stage runs is the repository's declared closing gate, defaulting to `verify-deploy.sh`.
- [ ] Extend `scripts/tests/test-verification-scope-lib.sh` (declared / absent / malformed /
      non-string) and `scripts/tests/test-orchestrate-batch-gate.sh` (a declared stub command whose
      `^FINDING ` lines attribute exactly as `verify-deploy.sh`'s do; a declared command exiting
      nonzero with no findings becomes an unattributed finding).
- [ ] Reconcile `index-entries.json` line counts.

**Timing**: 1.5 hours

**Depends on**: 5

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over the
edited library, script, two suites, and two context files is the covering check — it resolves each
edited path to its own suite and runs that narrowed pass.

**Scope Hypothesis**: `closing_gate` has no reader today, so this phase adds the first one and no
existing consumer changes behavior when the key is absent. Confirm with
`grep -rn "closing_gate" agent-system/extensions/core/` before editing; a pre-existing reader
would mean the project-sources record already moved this ground and the phase's edits must be
reconciled against it by hand.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/verification-scope-lib.sh` - the new reader and header
  inventory
- `agent-system/extensions/core/scripts/orchestrate-batch-gate.sh` - declared-command consumption
  for both snapshots, with the loud-failure path
- `agent-system/extensions/core/scripts/tests/test-verification-scope-lib.sh` - reader cases
- `agent-system/extensions/core/scripts/tests/test-orchestrate-batch-gate.sh` - declared-command
  cases
- `agent-system/extensions/core/context/standards/repo-level-declarations.md` - `closing_gate`
  schema bullet, fail-open row, emission contract, and the missing `Decisions Settled` heading
- `agent-system/extensions/core/context/contracts/batch-gate-stage.md` - Evidence Base note
- `agent-system/extensions/core/index-entries.json` - `line_count` reconciliation

**Verification**:
- Both suites pass, including the new reader and declared-command cases.
- With no `closing_gate` declared, a close run in a scratch fixture is byte-for-byte identical to
  the pre-phase behavior.
- With a stub `closing_gate` emitting two `FINDING ` lines naming a task's own file, both lines
  attribute to that task.
- `grep -n "Decisions Settled" agent-system/extensions/core/context/standards/repo-level-declarations.md`
  resolves to a real heading, or the pointer is gone.
- `bash agent-system/extensions/core/scripts/verify-touched.sh <the edited paths>` exits 0.

---

### Phase 7: Redeploy and Close on the Orchestration Battery [NOT STARTED]

**Goal**: The source-store changes reach the deployed tree, and the complete gate set discharges
once for this orchestration — written in the amended form this plan itself establishes.

**Tasks**:
- [ ] Redeploy the source store: `bash .claude/scripts/deploy-headless.sh` (which also runs
      `generate-context-line-counts.sh` before deploying, reconciling any `line_count` drift left
      by the earlier phases).
- [ ] Confirm the deployed tree carries every amended surface: the deployed `plan-format.md`,
      `plan-format-enforcement.md`, `planner-agent.md`, `general-implementation-agent.md`,
      `batch-gate-stage.md`, `orchestrate-batch-results-template.md`, `status-markers.md`,
      `repo-level-declarations.md`, the two edited libraries, the three scripts, and the new
      status-bind script and suite.
- [ ] Verify the dispatch's own VERIFY clause end to end against the deployed tree: a single-task
      `/orchestrate` emits the deferral directive and runs the complete gate set exactly once at
      Move 4; a seeded red close produces an attributed per-task record and the documented remedy;
      an interrupted invocation leaves a reported open obligation; `validate-artifact.sh` accepts a
      final phase written under the amended invariant and still rejects an untiered phase.
- [ ] Write the task summary under `specs/651_orchestration_close_owns_full_battery/summaries/`.

**Timing**: 1 hour

**Depends on**: 6

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - the deploy regenerates the entire deployed `.claude/` tree, an implicit scope
  claim over it that no real declared path expresses
- `agent-system/extensions/core/index-entries.json` - any residual `line_count` reconciliation the
  deploy's own pre-step writes

**Verification**:
- The complete gate set for the repository, discharged once for this orchestration at Move 4's
  batch gate stage — `bash .claude/scripts/verify-deploy.sh` run unnarrowed and green, including
  Gate 8's full suite battery. Per the amended invariant this plan establishes, this phase's own
  in-dispatch obligation is the scoped touched-path check
  (`bash agent-system/extensions/core/scripts/verify-touched.sh` over this phase's own touched
  paths) plus this explicit statement of deferral: the complete set is owed once, at the
  orchestration close, and is never forgiven. Under a standalone, non-orchestrated run of this
  phase there is no Move 4, so the complete set runs here directly instead.
- The four VERIFY-clause checks above each recorded with their observed result, not asserted.
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` clean.

---

## Testing & Validation

- [ ] `test-orchestrate-batch-gate.sh` passes, including the red-close record, discharge,
      stale-marker, and declared-closing-gate cases.
- [ ] `test-orchestrate-close-status-bind.sh` passes all five gating cases.
- [ ] `test-batch-gate-pending-marker.sh` passes, including the roster reader cases.
- [ ] `test-verification-scope-lib.sh` passes, including the `closing_gate` reader cases.
- [ ] `test-validate-artifact.sh` passes with the tier enum unchanged; a final phase in the amended
      form is accepted and an untiered phase still rejected.
- [ ] `lint-agent-contracts.sh` exits 0 after the agent-contract edits.
- [ ] `check-extension-docs.sh` reports no Rule R `line_count` drift and no unregistered script.
- [ ] The complete gate set, green, once, at this orchestration's Move 4 close.
- [ ] No task-number reference and no version-relative phrasing in any file landing under
      `agent-system/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-close-status-bind.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-close-status-bind.sh` (new)
- A `records/close-battery-red.jsonl` row shape, documented in `batch-gate-stage.md` as a sibling
  of `records/full-sweep-owed.jsonl`'s
- `verification_scope.closing_gate`: reader, consumer, schema documentation, and fail-open row
- The amended final-phase invariant across `plan-format.md`, `plan-format-enforcement.md`,
  `planner-agent.md`, and `general-implementation-agent.md`
- `specs/651_orchestration_close_owns_full_battery/summaries/01_*-summary.md`

## Rollback/Contingency

Every phase is a scoped commit of its own, so rollback is per-phase `git revert` of that commit
plus a redeploy. The two phases with real behavioral blast radius have independent off-switches:
Phase 4's demotion is confined to one new script invoked from one Move 4 line, so removing that
invocation restores today's "no task status is touched by the close" behavior without reverting
anything else; Phase 6's consumption is gated on a declared `closing_gate` key that no repository
sets today, so its absence is byte-for-byte the current path. Phases 1, 2, 3, and 5 are additive
documentation and additive record-writing; a revert loses the record, never a gate. If the full
battery is red at Phase 7 for reasons attributable to this task's own work, the honest outcome is
`[PARTIAL]` with the red close's own per-task record attached — exactly the mechanism Phases 3 and
4 build.
