# Implementation Plan: Task #88

- **Task**: 88 - Delete the single-task engine and rewrite skill-orchestrate as the four-move loop
- **Status**: [NOT STARTED]
- **Effort**: 12 hours
- **Dependencies**: 148 (completed and archived; task is unblocked)
- **Research Inputs**: specs/088_mode_gate_skill_orchestrate_multi_task_section/reports/01_delete-single-task-engine.md
- **Artifacts**: plans/01_four-move-loop-rewrite.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`skills/skill-orchestrate/SKILL.md` currently carries two engines in one file (189,000 B measured
2026-09-08): a single-task state machine (Stages 0-8, ~129,640 B) that the feature-port
predecessor has already made unreachable, and a multi-task section (Stages MT-1..MT-5, ~54,255 B)
that has already been largely absorbed into three standalone cycle scripts. This plan deletes the
single-task engine outright, relocates the surviving narration into `docs/architecture/`, and
rewrites what remains as the four-move loop (`orchestrate-cycle-plan.sh` -> one pointer-prompt
`Agent` call per dispatch row in ONE message -> `orchestrate-cycle-postflight.sh` per returned
task -> branch), targeting a `<= 20,000 B` SKILL.md. It additionally builds the one genuinely new
mechanism the acceptance criteria demand — a batched `AskUserQuestion` relay writing
`specs/{NNN}_{slug}/.decisions.json`, read back by the dispatch builder into the next dispatch
file — and retargets every test and lint whose assertions scrape SKILL.md's internal structure.

**Edit target**: every non-`specs/**` edit in this plan lands in `agent-system/extensions/core/**`
(the source store), never in `.claude/**` (a gitignored, regenerated deploy artifact). See
`.claude/rules/source-store-deploy-boundary.md`.

### Research Integration

Findings from `reports/01_delete-single-task-engine.md` that shape this plan:

- **Scope supersession is settled**: the REVISED + ADDENDUM description (engine deletion) is
  authoritative; the ORIGINAL mode-gating description is explicitly superseded and MUST NOT be
  implemented. `state.json`'s own `title` field for this task records the revised scope.
- **The three cycle scripts already exist** and match the target absorption table:
  `orchestrate-cycle-plan.sh` (1,538 lines), `orchestrate-build-dispatch.sh` (404 lines),
  `orchestrate-cycle-postflight.sh` (1,008 lines). This task is overwhelmingly deletion and
  reorganization, not new script authoring.
- **The `<= 20,000 B` target is not reachable by deletion alone**: the MT section alone is
  ~54,255 B before any loop-control glue is added. MT-1's `mt_state_file` field-list narrative
  (~17,668 B) and MT-5's rendering-template prose (~13,747 B) must move to docs, which is why
  the docs-absorption phase is scheduled first and separately.
- **`AskUserQuestion` + `.decisions.json` does not exist yet**: both engines only `echo` the
  `ask_user` question to stderr today. Three pieces are missing — the lead's batched
  `AskUserQuestion` call, a `.decisions.json` write path, and a dispatch-file read path — and
  none has precedent in an autonomous multi-cycle loop in this codebase. Research recommended
  scoping it as its own phase; this plan splits it across the script-side read path (Phase 2) and
  the lead-side ask/write (Phase 4).
- **`--team` residue is already gone**; the ADDENDUM's own `orchestrate-team-fanout.sh` reference
  is stale (no such script exists, team mode was deleted by an earlier task). Only a residual
  phase-forcing comment remains to clean up. This plan therefore treats WORK item (6) as a small
  residual sweep, not a mechanism removal.
- **`lint-postflight-boundary.sh` fails open**: its `^### Stage [6-9]|^### Stage 1[0-9]` heading
  heuristic SKIPs (does not FAIL) when no match is found, so a rewrite that abandons Stage-N
  numbering would silently stop enforcing the postflight boundary on this file.
- **Test coupling runs deeper than path-grep suggests**: several suites extract specific `jq`
  filters and named sentinel regions out of SKILL.md prose. Where equivalent coverage is
  confirmed in `test-orchestrate-cycle-plan.sh` / `test-orchestrate-cycle-postflight.sh`, prefer
  deleting the brittle scraping assertion over retargeting it.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no `specs/ROADMAP.md` exists. The
repository's plan-of-record for this work is `specs/PATH.md`, whose "Target design: the thin
lead" section is cited by the task description as the reference design and whose Stage A.6 row
is exactly this task. `PATH.md`'s own Progress and "Chain progress, 2026-09-03" narrative is
stale (it still describes the two predecessor tasks as pending though both completed and
archived on 2026-09-07); Phase 6 refreshes it.

## Goals & Non-Goals

**Goals**:

- Delete single-task Stages 0-8 from `skills/skill-orchestrate/SKILL.md` outright, leaving one
  engine on disk.
- Rewrite the remainder as the four-move loop, with Context References citing only the three
  cycle scripts and the state-machine doc.
- Bring `SKILL.md` to `<= 20,000 B` measured, with both `## MUST NOT` sections reduced to a
  combined list of at most ~1,500 B.
- Relocate narration, incident history, and exception taxonomies into
  `docs/architecture/orchestrate-state-machine.md` and `docs/architecture/handoff-schema.md`
  without losing content.
- Build the batched `AskUserQuestion` -> `.decisions.json` -> next-dispatch-file path end to end.
- Retarget or retire every test and lint that asserts on `SKILL.md`'s internal structure, and
  update `context/reference/orchestrator-critical-paths.json`.

**Non-Goals**:

- Changing any decision the three cycle scripts make. This is a transport and organization
  change on the lead; script behavior is out of scope except for the additive `.decisions.json`
  read path in `orchestrate-build-dispatch.sh`.
- Implementing the superseded mode-gating premise from the ORIGINAL description.
- Research-on-demand phase reordering. The loop must dispatch whatever phase the cycle plan
  names and MUST NOT hardcode research-first anywhere; the reordering itself is a later task.
- Re-deciding anything `PATH.md`'s "Target design" section already records as decided
  (batch-of-one, no team mode, no `--no-ask` flag).
- Reintroducing inline `jq` beyond what the four-move loop itself needs.
- The `Workflow`-tool spike, which `PATH.md` files as Stage E, after this task lands.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Fence-interior heading trap: naive `^## `/`^### ` section splitting matches headings inside fenced code blocks and silently truncates | H | M | Run a fence-state-aware scan before any deletion and confirm no heading lies inside a fence; delete bottom-up (Stage 8 -> Stage 0) so earlier line numbers never drift; re-measure headings after each deletion |
| `<= 20,000 B` target missed because deletion alone leaves ~54 KB | H | H | Docs absorption (Phase 1) is scheduled first and separately, and Phase 4 carries an explicit byte gate; if the target is still missed, move MT-5's rendering templates to the existing `context/patterns/orchestrate-batch-results-template.md` pointer rather than restating them |
| `lint-postflight-boundary.sh` silently stops checking this file (SKIP, not FAIL) after the heading rewrite | M | H | Phase 5 either keeps a heading the lint's regex matches or extends the heuristic; a targeted assertion is added that this file is not SKIPped |
| Brittle test retargeting churns without adding coverage | M | M | For each scraping assertion, first confirm whether `test-orchestrate-cycle-plan.sh` / `test-orchestrate-cycle-postflight.sh` already cover the behavior; delete the duplicate rather than retarget |
| `AskUserQuestion` is not in the skill's `allowed-tools` (currently `Agent, Bash, Read, Edit`), so the new relay would fail at runtime | H | H | Phase 4 adds it to the skill frontmatter and checks `commands/orchestrate.md`'s own `allowed-tools`; Phase 7 demonstrates the path live rather than asserting it statically |
| Writer/reader disagreement on the `.decisions.json` shape | M | M | Phase 2 fixes the schema in `docs/architecture/handoff-schema.md` before either side is written, and the reader ships first so the writer has a fixed target |
| `orchestrator-critical-paths.json` is itself a `recursion_guard: true` critical path; edits can regress the guard | M | L | Phase 6 verifies the edit against `verify-deploy.sh`'s self-reference handling before committing |
| Hand-editing `.claude/**` instead of the source store — the edit appears to succeed and is wiped by the next regeneration | H | M | Every phase names its target under `agent-system/extensions/core/**`; regeneration is manual-only, so Phase 7 performs the deploy explicitly before live verification |
| Task-number references leak into non-`specs/**` deliverables | M | M | Cite durable anchors (script names, section headings) in all rewritten prose; the repo lint (`check-task-references.sh`) runs in the Phase 7 gate |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 1, 2, 3 |
| 3 | 5, 6 | 4 |
| 4 | 7 | 5, 6 |

Phases within the same wave can execute in parallel. Waves 1's three phases touch disjoint file
sets (docs only / one script plus its test / `SKILL.md` only).

---

### Phase 1: Absorb narration into the architecture docs [NOT STARTED]

**Goal**: Give every piece of narration that must survive the rewrite a home in
`docs/architecture/` before any of it is deleted from `SKILL.md`, so the later trim is pure
removal rather than a judgment call under time pressure.

**Tasks**:

- [ ] Record the measured "before" byte count of
      `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (expected 189,000 B) and
      of `docs/architecture/orchestrate-state-machine.md` (expected 35,268 B) into the
      implementation progress record — this is acceptance evidence, not a nicety.
- [ ] Restructure `docs/architecture/orchestrate-state-machine.md` so the `## MT Mode:
      Multi-Task Orchestration` content becomes simply *the* design (one engine, batch of one),
      and any single-task narration worth keeping is folded in as historical background rather
      than a parallel live path.
- [ ] Move Stage MT-1's `mt_state_file` field-list documentation (the in-flight session
      registry, the upstream-review cross-reference, and the historical hard-mode note) out of
      the skill's future scope and into the state-machine doc.
- [ ] Move Stage MT-5's consolidated-output rendering narrative into the state-machine doc,
      pointing at the already-existing
      `context/patterns/orchestrate-batch-results-template.md` for the template itself rather
      than restating it.
- [ ] Move the branch enumerations and incident history currently carried by the two
      `## MUST NOT` sections (Context Flatness Constraint, Postflight Boundary) into the
      state-machine doc and `docs/architecture/handoff-schema.md` as appropriate, leaving behind
      only the imperative list items the later phase will keep.
- [ ] Verify no content was dropped: for each relocated block, confirm the destination carries
      the same claims (spot-check by heading and by distinctive phrase).

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:

- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - promote MT
  mode to the sole design; receive MT-1 field-list, MT-5 rendering narrative, and MUST NOT
  branch enumerations
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - receive the postflight
  boundary narrative that belongs with the handoff contract

**Verification**:

- Both docs still render as coherent documents (headings sequential, no orphaned cross-reference
  to a `SKILL.md` Stage that this task will delete).
- Every relocated block is findable in its destination by a distinctive phrase from the source.
- No edit lands outside the two doc files; `git diff --stat` confirms.

---

### Phase 2: Add the `.decisions.json` read path to the dispatch builder [NOT STARTED]

**Goal**: Fix the `.decisions.json` schema and ship the *reader* first, so the lead-side writer
built in Phase 4 has a stable, already-tested target to write against.

**Tasks**:

- [ ] Define the `specs/{NNN}_{slug}/.decisions.json` schema and record it in
      `docs/architecture/handoff-schema.md` as a named section: an array of entries carrying at
      minimum the question text, the chosen answer, the answering cycle, and a timestamp.
      Nothing else in the repo defines this file today (the only existing references are three
      comments stating the postflight script never writes it).
- [ ] Extend `scripts/orchestrate-build-dispatch.sh` to emit a new `## Prior Decisions` section
      into the written dispatch file when the task's `.decisions.json` exists and is non-empty,
      following the same section-emission convention as the existing `## Identity`,
      `## Description`, `## Artifact Round`, `## Research Artifact`, `## Handoff`, and
      `## User-Decision Contract` sections.
- [ ] Preserve the script's byte-identical-when-absent property: a dispatch built for a task with
      no `.decisions.json` must be byte-identical to one built before this change, matching the
      precedent the `--compare` flag already set.
- [ ] Update the script's own header comment to document the new section and its trigger.
- [ ] Extend `scripts/tests/test-orchestrate-build-dispatch.sh` with cases for: absent file
      (byte-identical output), present-and-empty file, and present-with-entries file (section
      emitted, content faithful).

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - `## Prior Decisions`
  emission and header documentation
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` - three new
  cases
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - `.decisions.json` schema
  section

**Verification**:

- `bash scripts/tests/test-orchestrate-build-dispatch.sh` passes, including the new cases.
- A dispatch built for a task with no `.decisions.json` is byte-identical to the pre-change
  output (diff of two generated files).

---

### Phase 3: Delete single-task Stages 0-8 [NOT STARTED]

**Goal**: Remove the unreachable engine from `SKILL.md` in one deliberate, fence-safe,
bottom-up pass, leaving the multi-task section as the file's only execution flow.

**Tasks**:

- [ ] Run a fence-state-aware scan of `SKILL.md` confirming no `^## ` or `^### ` heading lies
      inside a fenced code block, and record the result. This is the documented hazard the task
      description flags; do not skip it because a prior measurement said it was clean.
- [ ] Delete, bottom-up so earlier line numbers never drift: Stage 8, Stage 7, Stage 6,
      Stage 5b, Stage 5a, Stage 5, Stage 4, Stage 3.5 (already a stub), Stage 3, Stage 2b,
      Stage 2, Stage 1b, Stage 1, Stage 0.
- [ ] Remove the mode branch entirely: with Stage 0 gone there is no `multi_task_mode` detection
      and no "skip Stages 1-8" instruction anywhere in the file.
- [ ] Confirm nothing outside the deleted region referenced a deleted stage by name from within
      `SKILL.md` itself; fix any internal cross-reference that now dangles.
- [ ] Record the measured byte count after deletion.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: full

**Commit Mode**: atomic-batch

**Scope Hypothesis**: The single-task region is asserted at ~129,640 B across Stages 0-8, and the
post-deletion file is expected to be on the order of 59,000 B. Confirm at implementation time by
re-measuring the per-stage line ranges before deleting (the ranges in the research report were
taken 2026-09-08 and may have drifted) and by `wc -c` before and after. If the measured region
differs materially from the hypothesis, stop and re-derive the ranges rather than deleting to
the recorded line numbers.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - delete Stages 0-8

**Verification**:

- `grep -n '^#\{2,3\} ' SKILL.md` shows no `### Stage [0-8]` heading and no
  `### Stage 0: Multi-Task Mode Detection`.
- `grep -c 'multi_task_mode' SKILL.md` is 0, or every remaining occurrence is a deliberate,
  reviewed mention.
- Measured `wc -c` recorded and materially below the pre-phase baseline.

---

### Phase 4: Rewrite the remainder as the four-move loop [NOT STARTED]

**Goal**: Turn what is left of `SKILL.md` into the four-move loop and nothing else, at
`<= 20,000 B`, including the batched `AskUserQuestion` relay that writes `.decisions.json`.

**Tasks**:

- [ ] Rewrite `## Context References` to cite only `orchestrate-cycle-plan.sh`,
      `orchestrate-build-dispatch.sh`, `orchestrate-cycle-postflight.sh`, and
      `docs/architecture/orchestrate-state-machine.md`. The task description's mention of a
      fan-out script is stale — team mode and `orchestrate-team-fanout.sh` no longer exist — so
      no fan-out reference is added.
- [ ] Write the loop as four moves: (1) one call to `orchestrate-cycle-plan.sh` returning the
      cycle JSON; (2) one pointer-prompt `Agent` call per `dispatch[]` row, all rows issued in
      ONE message; (3) one `orchestrate-cycle-postflight.sh` call per returned task; (4) branch —
      continue, relay, or stop.
- [ ] Preserve the existing pointer-prompt and `context` shapes verbatim from the current MT-4
      dispatch composition; this is a transport-preserving move, not a redesign of what a
      dispatched agent receives.
- [ ] Keep the `aux_dispatch[]` rows and the MUST NOT that an aux row never reaches
      `orchestrate-cycle-postflight.sh`, and keep the hard-mode burnout gate call to
      `orchestrate-churn.sh --burnout-signal`, both as short list items.
- [ ] Implement the ask relay: accumulate every `ask_user` verdict returned by postflight during
      the cycle; after every other task's postflight has run, call `AskUserQuestion` once per
      accumulated question; write each answer to `specs/{NNN}_{slug}/.decisions.json` in the
      Phase 2 schema. A non-blocking decision proceeds on the agent's recommendation and is
      surfaced in the consolidated output rather than asked.
- [ ] Add `AskUserQuestion` to the skill's `allowed-tools` frontmatter (currently
      `Agent, Bash, Read, Edit`) and check whether `commands/orchestrate.md`'s own
      `allowed-tools` needs the same addition for the relay to be reachable.
- [ ] Do NOT conflate this with the unrelated `detected_defects` mechanism, which is
      accumulate-then-render by design and must never call `AskUserQuestion`.
- [ ] Make the stop branch print the consolidated output (pointing at
      `context/patterns/orchestrate-batch-results-template.md`) and exit.
- [ ] Reduce both `## MUST NOT` sections to a combined list of at most ~1,500 B, pointing at the
      Phase 1 doc homes for the reasoning.
- [ ] Retire the residual phase-forcing "accepted-and-ignored" comment and confirm by grep that
      no `--team` / `team_size` / fan-out residue remains.
- [ ] Confirm nothing in the rewritten file hardcodes research-first: the loop dispatches
      whatever phase the cycle plan names.
- [ ] Measure `wc -c` and confirm `<= 20,000`.

**Timing**: 2 hours

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: `SKILL.md` is asserted to reach `<= 20,000 B` after this phase. Confirm by
`wc -c` at phase close. If the measured size exceeds the target, do not close the phase by
relaxing the number — identify the largest remaining prose block and either relocate it to the
Phase 1 doc homes or replace it with a pointer, then re-measure.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - the four-move loop,
  `allowed-tools` frontmatter, trimmed MUST NOT sections
- `agent-system/extensions/core/commands/orchestrate.md` - `allowed-tools`, only if the relay
  requires it

**Verification**:

- `wc -c SKILL.md` is `<= 20,000`.
- Combined byte size of the two `## MUST NOT` sections is `<= ~1,500`.
- `grep -c 'AskUserQuestion' SKILL.md` is non-zero and the frontmatter lists the tool.
- `grep -iE 'team|fan-?out' SKILL.md` returns nothing live.
- No text in the file asserts research runs first.

---

### Phase 5: Retarget the tests and lints coupled to SKILL.md structure [NOT STARTED]

**Goal**: Make every suite that asserts on `SKILL.md`'s internal structure either test the
script that now owns the behavior, or stop asserting on a structure that no longer exists —
without silently losing coverage.

**Tasks**:

- [ ] Re-run the enumeration sweep (`grep -rln 'skill-orchestrate/SKILL.md' scripts/tests
      scripts/lint`) and reconcile it against the list below before editing; the sweep, not this
      list, is authoritative at implementation time.
- [ ] `test-loop-guard-budget-override.sh`: delete or repoint Target 1, whose stated premise
      ("the single-task engine stays live and stays the default path") this task invalidates.
      Target 2 already exercises `orchestrate-cycle-plan.sh` directly and is unaffected.
- [ ] `test-routing-resolution.sh`: retarget the ">= 3 `command-route-agent.sh` invocations in
      SKILL.md" assertion onto wherever routing now resolves, and re-check the "no case-table or
      sed-derivation pattern" assertion against the thin file.
- [ ] `test-loop-guard-staleness.sh` and `test-handoff-dispatch-identity.sh`: their line-anchored
      `awk` sentinel-region extraction targets deleted Stages. For each, first confirm whether
      `test-orchestrate-cycle-plan.sh` / `test-orchestrate-cycle-postflight.sh` already cover the
      behavior; delete the duplicate scraping assertion where they do, retarget onto the script
      where they do not.
- [ ] `test-handoff-reader-parity.sh`: its `grep -c == 1` uniqueness checks extract specific `jq`
      filters from SKILL.md prose. Retarget onto `orchestrate-cycle-postflight.sh`, which owns
      handoff reading.
- [ ] `test-resume-scan-nonconformance.sh`: verify its Site A / Site B design still makes sense
      with Stages 0-8 gone.
- [ ] `lint-contract-compliance.sh`: retarget Check C (keyed off "SKILL.md Stage 1b") and
      Check D (keyed off a hard-mode branch's convergence-policing fields) onto the loop's
      per-row dispatch and the surviving hard-mode fields.
- [ ] `lint-postflight-boundary.sh`: close the fail-open gap — either keep a heading its
      `^### Stage [6-9]|^### Stage 1[0-9]` regex matches, or extend the heuristic to recognize
      the loop's heading shape. Add an assertion that this file is not reported as SKIPped.
- [ ] Check the remaining lints named in this task's `file_scope`
      (`lint-branch-gated-sections.sh`, `lint-lifecycle-status-var.sh`,
      `lint-scoped-commit-boundary.sh`, `lint-state-writer-boundary.sh`,
      `lint-task-lookup-adoption.sh`) and the remaining tests
      (`test-corroborate-phase-counts.sh`, `test-deploy-propagation.sh`,
      `test-double-loading-check.sh`, `test-lint-branch-gated-sections.sh`,
      `test-lint-task-lookup-adoption.sh`, `test-skill-base-lifecycle.sh`) for structural
      assumptions the rewrite breaks.
- [ ] Run the full test suite in `scripts/tests/` and confirm green.

**Timing**: 2 hours

**Depends on**: 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: Six test files and two lint files are asserted to carry deep structural
coupling, within a `file_scope` naming 11 tests and 7 lints. Confirm at implementation time by
re-running the grep sweep and by reading each hit's assertion body — path-grep membership alone
undercounts the coupling (several of the deepest couplings surfaced only from reading file
bodies). Record the confirmed count against this hypothesis before closing the phase.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-loop-guard-budget-override.sh`
- `agent-system/extensions/core/scripts/tests/test-routing-resolution.sh`
- `agent-system/extensions/core/scripts/tests/test-loop-guard-staleness.sh`
- `agent-system/extensions/core/scripts/tests/test-handoff-dispatch-identity.sh`
- `agent-system/extensions/core/scripts/tests/test-handoff-reader-parity.sh`
- `agent-system/extensions/core/scripts/tests/test-resume-scan-nonconformance.sh`
- `agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh`
- `agent-system/extensions/core/scripts/lint/lint-postflight-boundary.sh`
- plus any additional test/lint the re-run sweep surfaces

**Verification**:

- Every test in `scripts/tests/` passes.
- `lint-postflight-boundary.sh` reports a real result (not SKIP) for
  `skills/skill-orchestrate/SKILL.md`.
- No test asserts on a `SKILL.md` Stage heading that no longer exists.

---

### Phase 6: Update the pointer and registry surface [NOT STARTED]

**Goal**: Bring every file that describes or points at `SKILL.md`'s structure into agreement with
the thin loop, including the critical-paths registry and the plan-of-record.

**Tasks**:

- [ ] Update `context/reference/orchestrator-critical-paths.json`'s label for
      `skills/skill-orchestrate/SKILL.md`, which currently describes the pre-rewrite
      merged-but-dual-engine state.
- [ ] Add `orchestrate-build-dispatch.sh` and `orchestrate-cycle-postflight.sh` entries to that
      registry; `orchestrate-cycle-plan.sh` is already present, and all three are now what the
      lead's entire runtime behavior reduces to.
- [ ] Verify the registry edit against `verify-deploy.sh`'s self-reference handling — this file
      is itself a `recursion_guard: true` critical path.
- [ ] Sweep the non-test files that reference `skill-orchestrate/SKILL.md` (the sweep found
      roughly two dozen under `context/` and `docs/`) and repoint any citation of a deleted
      Stage name onto the loop's move names or the state-machine doc. Cite durable anchors —
      section headings and script names — never task numbers, since these are deliverables
      outside `specs/**`.
- [ ] Refresh `specs/PATH.md`'s Progress table and "Chain progress" narrative, which still
      describe this task's two predecessors as pending though both completed and archived. This
      file is under `specs/**`, so task numbers are permitted there.

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Roughly two dozen non-test files under `context/` and `docs/` reference
`skill-orchestrate/SKILL.md`. Confirm by re-running the sweep and reading each hit; most are
expected to be plain path references needing no change, and only those citing a deleted Stage
name need editing. Record the confirmed changed-file count.

**Files to modify**:

- `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json` - label and
  two new script entries
- `specs/PATH.md` - Progress and Chain-progress refresh
- plus the subset of `context/**` and `docs/**` files whose Stage citations the sweep confirms
  are now dangling

**Verification**:

- `jq . orchestrator-critical-paths.json` parses and the three cycle scripts are all present.
- `verify-deploy.sh` runs clean over the registry edit.
- No surviving reference to a deleted Stage name outside `specs/**`.
- `check-task-references.sh` reports no task-number references in the edited deliverables.

---

### Phase 7: Acceptance verification and full gate run [NOT STARTED]

**Goal**: Produce the evidence each acceptance criterion names, live rather than asserted.

**Tasks**:

- [ ] Redeploy the source store to `.claude/` (regeneration is manual-only in this repo) so the
      live verification exercises the rewritten skill rather than the stale deploy.
- [ ] Report measured `SKILL.md` bytes before and after against the recorded 189,000 B baseline.
- [ ] Run a live 5-task batch end to end and measure the lead's per-cycle context growth —
      cycle-plan JSON plus pointer prompts plus postflight JSON — against the target of roughly
      1 KB per task per cycle.
- [ ] Run a single-task-number invocation and confirm it completes through the same batch-of-one
      path with no second engine involved.
- [ ] Demonstrate an agent-surfaced `user_decision` reaching `AskUserQuestion`, and its answer
      reaching the next dispatch file via `.decisions.json` and the Phase 2 `## Prior Decisions`
      section. This cannot be hand-waved: the acceptance criterion demands the live path.
- [ ] Run every orchestrate test and confirm green.
- [ ] Run the full gate suite (`scripts/tests/run-all.sh` and the lint set) and confirm green.
- [ ] Record all measurements in the implementation summary.

**Timing**: 2 hours

**Depends on**: 5, 6

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:

- Fixes arising from the gate run only; no planned edits

**Verification**:

- Every acceptance criterion has a recorded measurement or a described live demonstration.
- Full gate run green.

---

## Testing & Validation

- [ ] `bash scripts/tests/test-orchestrate-build-dispatch.sh` passes, including the three new
      `.decisions.json` cases.
- [ ] A dispatch file built for a task with no `.decisions.json` is byte-identical to the
      pre-change output.
- [ ] Every test under `scripts/tests/` passes; the full gate suite is green.
- [ ] `lint-postflight-boundary.sh` produces a real verdict (not SKIP) for
      `skills/skill-orchestrate/SKILL.md`.
- [ ] `wc -c` on `SKILL.md` is `<= 20,000`; the two `## MUST NOT` sections total `<= ~1,500 B`.
- [ ] A live 5-task batch completes end to end; per-cycle lead context growth measured.
- [ ] A single-task-number invocation completes through the batch-of-one path.
- [ ] An agent-surfaced `user_decision` is observed reaching `AskUserQuestion`, and its answer is
      observed in the next dispatch file.
- [ ] `check-task-references.sh` clean.

## Artifacts & Outputs

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — rewritten as the four-move
  loop, `<= 20,000 B`
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — `## Prior Decisions`
  section emission
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` — three new
  cases
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — MT mode
  promoted to the sole design; absorbed narration
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — `.decisions.json` schema;
  absorbed postflight-boundary narrative
- `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json` — updated
  label; two added script entries
- Retargeted tests and lints under `agent-system/extensions/core/scripts/tests/` and
  `scripts/lint/`
- `specs/PATH.md` — refreshed Progress and Chain-progress
- `specs/088_mode_gate_skill_orchestrate_multi_task_section/summaries/01_*.md` — implementation
  summary carrying every measurement

## Rollback/Contingency

Every phase commits separately, so any single phase reverts with `git revert` of its commits
without disturbing the others. The two highest-risk reversion points:

- **Phase 3 (deletion)** is a single `atomic-batch` commit against one file, so reverting it
  restores the dual-engine file exactly.
- **Phase 4 (rewrite)** leaves the deployed `.claude/` copy stale until Phase 7 redeploys; if the
  live verification in Phase 7 fails in a way that cannot be fixed forward within the phase,
  revert Phases 3 and 4 and redeploy, which restores the working engine while leaving the
  additive Phase 1, 2, and 6 work (docs, the `.decisions.json` reader, the registry) in place —
  all three are backward-compatible with the old engine.

If the `<= 20,000 B` target proves unreachable without cutting behavior, stop and surface the
trade-off rather than deleting runtime instruction to hit a number: the byte ceiling is a means
to the context-budget goal, and a functional 24 KB loop is a better outcome than a 19 KB one that
drops a gate.
