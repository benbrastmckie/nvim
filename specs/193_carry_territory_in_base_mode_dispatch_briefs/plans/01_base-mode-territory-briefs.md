# Implementation Plan: Task #193

- **Task**: 193 - Carry concurrent-sibling territory in base-mode dispatch briefs
- **Status**: [IMPLEMENTING]
- **Effort**: 5 hours
- **Dependencies**: None (197 and 213 already landed; 165 is a coordination target, not a blocker)
- **Research Inputs**: specs/193_carry_territory_in_base_mode_dispatch_briefs/reports/01_base-mode-territory-population.md
- **Artifacts**: plans/01_base-mode-territory-briefs.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Multi-task `/orchestrate` in base mode dispatches concurrent siblings onto one working tree
without telling any of them that the others exist. The rendering half already works: the
`## Territory` section in `orchestrate-build-dispatch.sh` is gated only on `[ -n "$territory" ]`.
Two upstream gates keep it from appearing in base mode. (a) `orchestrate-cycle-plan.sh` fills
`$territory` only from the hard-mode-only `h1_territory[$t]`. (b) `territory.md` gets pulled in as
a contract only inside the hard-mode `core_contracts` block. This plan adds a sibling-territory
payload that is built in every mode from `probed_dispatch_post_h1`, plus each sibling's
`file_scope` read from `$STATE_FILE`. Each sibling scope entry carries an explicit granularity
label, and an undeclared scope gets its own sentinel. The plan also adds a contract pointer that
does not depend on hard mode, a fixture for the observed batch shape, and documentation in both
script headers and in `territory.md`. All edits land in the source store
(`agent-system/extensions/core/**`), never `.claude/**`.

### Research Integration

Report 01 is integrated in full:
- Finding 1/Rec 1: the contract-pointer fix in build-dispatch is a separate branch, not a reuse
  of `core_contracts`/`<hard-mode-contracts>`.
- Finding 2/Rec 2: the sibling set is `probed_dispatch_post_h1`, and no new discovery mechanism
  is needed.
- Finding 3/Rec 3: `orchestrate-batch-admit.sh` stays untouched. Admission and brief content are
  separate concerns.
- Finding 4/Rec 4: the `concurrency_note` wording is adapted from the existing H1 string.
- Finding 5: explicit sentinel for an undeclared scope, plus (from the RECURRED addendum) an
  explicit per-entry granularity label.
- Finding 6/Rec 5: the payload is emitted for every phase group. See Decisions.
- Finding 8/Rec 6: new test groups are appended to the two existing test files.
- Context Extension Recommendation: a new "Cross-Task Territory (Base Mode)" section in
  `territory.md`.
- Risk row on `aux_dispatch[]` is resolved in Phase 1 (see Scope Hypothesis there).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided for this dispatch.

## Decisions

1. **Emit in every mode, including hard mode.** The payload does not depend on hard mode. When an
   H1 territory literal is also present for a hard-mode implement candidate, the sibling payload
   is merged into that same JSON object under a `concurrent_siblings` key rather than replacing
   it. This way hard mode also gains the cross-task fact that it lacks today, and the new
   behaviour is not a hard-mode-only feature under another name.
2. **Emit for every phase group** (research/plan/implement), and list every sibling with its
   phase. It costs nothing, keeps one code path, and a research or plan sibling's scope is still
   useful for an implementer to know. The payload is only emitted when at least one sibling
   exists. A single-task cycle therefore produces a byte-identical brief, which is the regression
   guard.
3. **Granularity is explicit.** Each sibling `file_scope` entry is classified as `file`,
   `directory` (trailing `/` or an existing directory relative to the repo root), or `glob`
   (contains `*`, `?`, or `[`). Each sibling gets a roll-up `scope_granularity` of `file`,
   `coarse` (any directory or glob entry) or `undeclared`. A key that is absent, `null`, or `[]`
   renders as `"file_scope": null, "scope_declared": false, "scope_granularity": "undeclared"`.
   It is never dropped from the list. A `coarse` or `undeclared` sibling carries a note telling
   the agent that it could touch any file.
4. **No admission-posture decision.** The payload only represents absence. Whether an absent or
   coarse `file_scope` should defer admission is owned by the separate absent-file_scope
   admission work in `orchestrate-batch-admit.sh`. This plan consumes whatever that work rules and
   states so in the header comment and in `territory.md`. `orchestrate-batch-admit.sh` is not
   edited.
5. **Sequencing rationale is generic, not per-pair.** Nothing in the codebase computes
   non-idempotence between two tasks. The payload carries one fixed procedural instruction:
   - re-read any file a sibling may also touch immediately before editing and before committing;
   - stage only this task's own hunks;
   - never run a reverting `git-snapshot.sh`;
   - treat a build failure in a file outside your scope as possibly a sibling's in-flight edit;
   - STOP and report on foreign work, reporting only after checking `git log` for your own
     commits.

   The STOP-and-report framing is adapted from the H1 `concurrency_note`.
6. **Over-inclusion is acceptable.** A dispatch file is built before later siblings in the same
   loop acquire their locks. If a later sibling ends up deferred in the live loop, the brief may
   name it. The note says "scheduled concurrently this cycle", not "running". This is safer than
   under-informing.
7. **Mid-flight message delivery is out of scope.** The design does not depend on it. A fact
   known at dispatch time belongs in the brief, whether or not mid-flight delivery works.

## Goals & Non-Goals

**Goals**:
- A multi-task brief (in base mode, and also in hard mode) names every concurrently scheduled
  sibling task, with its phase, its declared `file_scope`, and explicit granularity/undeclared
  markers.
- `territory.md` is referenced in the brief whenever territory is set, including base mode.
- A fixture reproduces the observed batch shape: two concurrent implement dispatches, one narrow
  scope and one undeclared. It proves the brief now carries the missing facts.
- Both script headers and `territory.md` document the behaviour. Both scripts are shellcheck
  clean.

**Non-Goals**:
- Changing `orchestrate-batch-admit.sh` or deciding the absent-file_scope admission posture.
- Serializing multi-task dispatch.
- Fixing mid-flight mailbox delivery.
- Working-tree or build isolation between concurrent dispatches. That is owned by the separate
  isolation-posture work, and the payload here is a necessary but partial remedy.
- Informing agents about tasks running in other, independent `/orchestrate` sessions.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Base-mode payload accidentally triggers `<hard-mode-contracts>` rendering | M | L | Contract pointer is a separate line inside the existing `if [ -n "$territory" ]` block; the Phase 2 test asserts there is no `<hard-mode-contracts>` in a base-mode brief |
| Single-task briefs change (regression) | M | L | Payload is emitted only when the sibling count is at least 1; the Phase 3 test asserts there is no `## Territory` in a single-task cycle |
| Hard-mode H1 territory is clobbered by the sibling payload | H | L | jq merge (`. + {concurrent_siblings: ...}`) into the H1 object; the Phase 3 test covers the hard-mode case |
| `aux_dispatch[]` rows are concurrent but absent from `probed_dispatch_post_h1` | L | M | Phase 1 confirms the aux rows are already built before the live loop (`out_aux_dispatch_rows`) and includes them as siblings with `phase: "aux:<kind>"` if so; otherwise it documents the exclusion |
| Agents over-react to informational territory with spurious breach reports | M | L-M | Wording requires a `git log` self-check before reporting and frames the section as "may touch", never "will conflict" |
| Payload JSON breaks on odd paths (quotes, spaces) | M | L | Build entirely with `jq -n --arg`/`--argjson`, never by string concatenation |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel. Phases 1 and 2 touch different files.

### Phase 1: Build the sibling territory payload in orchestrate-cycle-plan.sh [COMPLETED]

**Goal**: Populate `--territory` for every dispatch in a cycle with at least one concurrent
sibling, in every mode.

**Tasks**:
- [x] Add a local helper `build_sibling_territory <t> <sibling-task>...`. For each sibling other
      than `<t>`, it reads `file_scope` from `$STATE_FILE` with one jq call, or one batched call
      keyed by the sibling list, following the `compose_focus()` style. It classifies each entry
      and emits a compact JSON object:
      `{"concurrent_siblings": [{"task_number", "phase", "file_scope", "scope_declared",
      "scope_granularity", "entries": [{"path", "granularity"}]}], "concurrency_note": "..."}`
      (the field list is final; the key order is the implementer's choice). *(completed: reuses
      `lookup_project` instead of a second hand-written jq query, per Finding 2/Rec 2)*
- [x] Write the `concurrency_note` and the per-sibling coarse/undeclared note (Decision 3/5
      wording), adapted from the H1 note at `h1_territory`. Cite `context/contracts/territory.md`
      and `context/patterns/dispatch-report-not-termination.md`. *(completed)*
- [x] In the live per-task loop, compute the sibling list: `probed_dispatch_post_h1` minus `$t`,
      each tagged with `effective_group`, plus aux rows if confirmed (see Scope Hypothesis). When
      the list is non-empty, set `sibling_territory`. *(completed: aux rows deliberately excluded,
      documented in the header block -- see Scope Hypothesis note below)*
- [x] Rework the `--territory` append. If `h1_next_phase[$t]` is set, merge `sibling_territory`
      into `h1_territory[$t]` via jq before passing it. Otherwise pass `sibling_territory` alone
      when it is non-empty (empty value skips the flag). *(completed)*
- [x] Replace the stale comment ("absent from every base-mode call") with an accurate one.
      *(completed)*
- [x] Add a header contract block describing the base-mode territory payload, the granularity
      labels, the undeclared sentinel, the phase-agnostic emission, and the explicit deferral to
      the absent-file_scope admission posture in `orchestrate-batch-admit.sh`. Name that script
      and its concern, never a task number. *(completed)*
- [ ] Optionally surface a `territory_siblings` count on `--dry-run` rows only if trivial; not
      required. *(deviation: skipped — optional per plan text; --dry-run rows do not build
      dispatch files and adding a count would require duplicating the sibling-list computation
      into the dry-run branch for no consumer benefit)*

**Timing**: 1.75 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: Hypothesis: the only edit sites are the header block, one new helper, and
the live loop around the existing `h1_next_phase` append (about line 1880), and `aux_dispatch[]`
rows are built before the live loop (`out_aux_dispatch_rows`, about lines 1048-1150). Confirm with
`grep -n "out_aux_dispatch_rows\|probed_dispatch_post_h1\|h1_territory"` before editing, and
record whether aux rows are included or deliberately excluded (with the reason) in the header
block.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`: helper, live-loop wiring,
  header block, comment fix

**Verification**:
- `shellcheck agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` is clean.
- The existing `tests/test-orchestrate-cycle-plan.sh` still passes in full, including Group 9
  (the H1 territory assertions).

---

### Phase 2: Reference territory.md from base-mode briefs in orchestrate-build-dispatch.sh [COMPLETED]

**Goal**: Pull in the territory contract whenever `$territory` is set, without routing base mode
through the hard-mode contract machinery.

**Tasks**:
- [x] Inside the existing `if [ -n "$territory" ]` block that renders `## Territory`, add a
      pointer line ("Read context/contracts/territory.md (Cross-Task Territory section) before
      editing any file.") when the contract is not already listed by `core_contracts`. That
      means not (`hard_mode = true` and `phase = implement`). *(completed)*
- [x] Add a header contract block next to the existing `--territory`/`--phase-number` comments.
      It must state that `--territory` is now populated in base mode by the cycle planner for
      multi-task cycles, what the payload contains, and that the section and pointer render
      phase-agnostically. *(completed)*
- [x] Add a test group to `tests/test-orchestrate-build-dispatch.sh`, following Groups 5-6. With
      a base-mode `--territory` payload: `## Territory` is present, the `territory.md` pointer is
      present, and `<hard-mode-contracts>` is absent. Without `--territory`: the output is
      byte-identical to before (no pointer). *(completed: Group 13, Cases A-D, plus hard-mode
      research and hard-mode-implement no-duplicate-pointer cases; required inverting this test
      file's SUT resolution to source-store-first, since it was previously validating the stale
      deployed `.claude/scripts/` copy against this exact source-store edit)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`: pointer line, header
  block
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh`: new group

**Verification**:
- `shellcheck` is clean on the script and the test file.
- `bash tests/test-orchestrate-build-dispatch.sh` passes, including the new group.

---

### Phase 3: Fixture reproducing the observed batch shape [NOT STARTED]

**Goal**: Show that the brief now carries what the concurrent agents lacked.

**Tasks**:
- [ ] Append a new group to `tests/test-orchestrate-cycle-plan.sh`, following the Group 9 and
      Group 23 conventions. The fixture `state.json` has two `planned` tasks, so both resolve to
      the `implement` group. Task A has `file_scope: ["FormalSystem/Metalogic/Soundness.lean"]`
      (narrow). Task B has the `file_scope` key omitted entirely (the tree-wide rename case). Run
      in base mode (no `--hard`), live.
- [ ] Case A: A's `.dispatch/N.md` has `## Territory`, names B's task number, and shows
      `"scope_declared": false` / `"undeclared"` plus the territory.md pointer.
- [ ] Case B: B's brief names A with A's exact file and `"granularity": "file"`.
- [ ] Case C: coarse scope. A sibling with `file_scope: ["docs/"]` renders
      `"granularity": "directory"` and `"scope_granularity": "coarse"`. `file_scope: []` renders
      the same as absent.
- [ ] Case D: a single-task cycle produces no `## Territory` section (regression guard).
- [ ] Case E: in hard mode, an H1 implement candidate with a sibling keeps its H1 `owned_files`
      and also gains `concurrent_siblings`.
- [ ] Case F (only if aux rows were included in Phase 1): an aux-dispatched sibling appears with
      its `aux:` phase label.

**Timing**: 1.25 hours

**Depends on**: 1, 2

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh`: new group

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` passes, with
  every new case green and no pre-existing group regressed.
- `shellcheck` is clean on the test file.

---

### Phase 4: Contract documentation and final gate [NOT STARTED]

**Goal**: Document the cross-task payload in the territory contract and run the full gate.

**Tasks**:
- [ ] Add a `## Cross-Task Territory (Base Mode)` section to `territory.md`, mirroring the
      structure of `## File Territory`. It covers:
      - payload shape, with an example;
      - granularity labels and the undeclared sentinel, stated plainly: a coarse or undeclared
        sibling can touch anything;
      - agent obligations (the Decision 5 procedure);
      - its relationship to H7 within-task territory, to the absent-file_scope admission posture
        owned by `orchestrate-batch-admit.sh`, and to the separate working-tree isolation
        concern.
- [ ] Update the contract's opening paragraph so it names both consumers (hard-mode H1 and the
      multi-task cycle planner in every mode). Keep the "Explicit removal note" intact.
- [ ] Grep the source store for docs that claim territory is hard-mode-only (for example
      `grep -rn "territory" agent-system/extensions/core/skills/skill-orchestrate/
      agent-system/extensions/core/docs/`) and correct any stale claim found. Record findings;
      no edits are required if nothing is stale.
- [ ] Run the task-reference lint (`check-task-references.sh`) over the touched deliverables.
- [ ] Full gate: `shellcheck` on both scripts and both test files, per
      `context/standards/shell-strict-mode.md`, and both test suites in full.

**Timing**: 1 hour

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Scope Hypothesis**: Hypothesis: `territory.md` is the only prose doc that needs changing. The
grep task confirms or refutes this. Any additional stale doc it finds is fixed in this phase.

**Files to modify**:
- `agent-system/extensions/core/context/contracts/territory.md`: new section and intro update
- Any stale doc surfaced by the grep (conditional)

**Verification**:
- All gates listed above pass.
- No task numbers appear in any deliverable outside `specs/**`.

## Testing & Validation

- [ ] `shellcheck` is clean on `orchestrate-cycle-plan.sh`, `orchestrate-build-dispatch.sh`, and
      both test files.
- [ ] `tests/test-orchestrate-cycle-plan.sh` passes in full, including the new batch-shape group
      (narrow + undeclared, coarse, single-task regression, hard-mode merge).
- [ ] `tests/test-orchestrate-build-dispatch.sh` passes in full, including the new base-mode
      pointer group.
- [ ] A base-mode multi-task brief names its siblings, their scopes and granularity, and
      references `territory.md`.
- [ ] A single-task brief is unchanged.
- [ ] `check-task-references.sh` is clean on the touched files.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (modified)
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` (modified)
- `agent-system/extensions/core/context/contracts/territory.md` (modified)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` (new group)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` (new group)
- `specs/193_carry_territory_in_base_mode_dispatch_briefs/summaries/01_base-mode-territory-briefs-summary.md`

## Rollback/Contingency

Each phase is committed separately, so any phase can be reverted with `git revert <sha>` on its
own commit. That leaves the pre-existing hard-mode H1 territory path intact, because Phase 1's
merge is additive. If a whole-tree rollback of uncommitted work is ever needed, follow
`context/contracts/recovery.md`'s rollback rung for the snapshot invocation shape. Do not take
routine reverting snapshots.
