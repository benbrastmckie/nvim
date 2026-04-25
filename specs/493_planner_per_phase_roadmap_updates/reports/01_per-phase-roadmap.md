# Research Report: Task #493

- **Task**: 493 - planner_per_phase_roadmap_updates
- **Started**: 2026-04-25T00:00:00Z
- **Completed**: 2026-04-25T00:05:00Z
- **Effort**: 30 minutes
- **Dependencies**: Task 490 (wired --roadmap flag through /plan to planner-agent)
- **Sources/Inputs**:
  - `.claude/agents/planner-agent.md` (Stage 2.5, 2.6, full execution flow)
  - `.claude/context/formats/plan-format.md` (phase structure)
  - `.claude/context/formats/roadmap-format.md` (ROADMAP.md structure)
  - `.claude/context/patterns/roadmap-update.md` (update process)
  - `specs/ROADMAP.md` (actual roadmap content)
  - `.claude/agents/general-implementation-agent.md` (how phases are executed)
  - `.claude/skills/skill-planner/SKILL.md` (delegation context for roadmap_flag)
- **Artifacts**: specs/493_planner_per_phase_roadmap_updates/reports/01_per-phase-roadmap.md
- **Standards**: report-format.md, status-markers.md, artifact-management.md, tasks.md

## Executive Summary

- The planner-agent's Stage 2.6 currently generates a bookend pattern: a Phase 1 "Review and Snapshot ROADMAP.md" and a final phase "Update ROADMAP.md". No intermediate phases touch the roadmap.
- Phase 1 is labeled "Review and Snapshot" -- it only reads current state and records the before-state. It does not make any updates even when items can be confidently marked at plan time.
- The implementation agent (`general-implementation-agent.md`) has no roadmap-specific logic; it simply executes whatever phases/tasks appear in the plan. This means all roadmap update instructions must be embedded in the plan phases themselves.
- The required changes are confined to a single file: `.claude/agents/planner-agent.md` Stage 2.6. No changes to plan-format.md, roadmap-format.md, or the implementation agent are needed.

## Context & Scope

Task 490 wired the `--roadmap` flag from `/plan` through skill-planner to planner-agent. When `roadmap_flag=true`, the planner-agent generates additional phases for roadmap integration. This task strengthens that behavior in two ways:

1. **Phase 1 upgrade**: Change from passive "Review and Snapshot" to active "Update ROADMAP.md with confident items" -- items that can be marked at plan time (e.g., items the task directly addresses) should be updated immediately in Phase 1.
2. **Per-phase roadmap steps**: Each core implementation phase should include a roadmap update step at phase end, not just the final phase.

## Findings

### Finding 1: Current Stage 2.6 Text (Exact)

The current Stage 2.6 in `planner-agent.md` (lines 78-89) reads:

```markdown
### Stage 2.6: Evaluate Roadmap Flag

If `roadmap_flag` is `true` in the delegation context:

1. **ROADMAP.md must exist** - If it was not loaded in Stage 2.5 (file missing), log a warning
   and proceed without roadmap phases. The flag has no effect without an existing ROADMAP.md.
2. When ROADMAP.md exists, the plan MUST include two additional phases:
   - **First phase**: "Review and Snapshot ROADMAP.md" - Read current ROADMAP.md state,
     identify which items this task will advance, record the before-state for comparison
   - **Last phase**: "Update ROADMAP.md" - Mark completed items with `- [x]` and completion
     annotation `*(Completed: Task {N}, {DATE})*`, add any new items discovered during
     implementation, update phase progress
3. These roadmap phases wrap the core implementation phases. The dependency chain is:
   roadmap-review (Phase 1) -> core phases -> roadmap-update (final phase, depends on all
   core phases)
4. All other plan construction proceeds as usual (Stages 3-5)

If `roadmap_flag` is `false` or not present, skip this stage entirely. Plan construction is
unchanged.
```

### Finding 2: Phase Structure in Plans

From `plan-format.md`, each phase contains:
- `**Goal:**` short statement
- `**Tasks:**` bullet checklist (`- [ ] ...`)
- `**Timing:**` expected duration
- `**Depends on:**` phase numbers
- `**Files to modify:**` (from planner-agent template)
- `**Verification:**` completion criteria

The roadmap update step should be added as a checklist item within the `**Tasks:**` section of each phase. This is the natural place -- it does not require any new structural element.

### Finding 3: Roadmap Update Mechanics

From `roadmap-update.md`, the update process involves:
- Converting `- [ ] {item}` to `- [x] {item} *(Completed: Task {N}, {DATE})*`
- Safety rules: never remove content, skip already-annotated items, one edit per item
- Matching strategy: exact (Task N reference), title match, file path match

The implementation agent needs no special awareness of roadmap updates. It reads phases, executes tasks (including "Edit ROADMAP.md to mark item X complete"), and moves on. The Edit tool is sufficient for roadmap modifications.

### Finding 4: Implementation Agent Interaction

The `general-implementation-agent.md` Stage 4 loop simply:
1. Marks phase `[IN PROGRESS]`
2. Executes each step (Read files, Create/modify files, Verify)
3. Marks phase `[COMPLETED]`

It treats all phases identically. A task item like "Update ROADMAP.md: mark item X as complete with annotation" is a standard Edit operation. No agent changes needed.

### Finding 5: What "Confident Items" Means for Phase 1

At plan time, the planner knows:
- The task description (what will be done)
- The roadmap items (from Stage 2.5 loading)
- Which roadmap items this task directly addresses

Items that can be confidently updated at Phase 1 (plan-time knowledge):
- Items whose completion is the stated goal of the task (the task exists to do this)
- Items that are prerequisites already completed by dependency tasks

Items that should NOT be updated in Phase 1:
- Items that depend on implementation success (must wait for phase completion)
- Items discovered during implementation

Therefore, Phase 1 should be renamed to something like "Initial ROADMAP.md Update" and should update items that are known-complete from dependencies or that the task description explicitly states will be accomplished (marking them as in-progress rather than complete).

**Revised approach**: Phase 1 should actually just identify and record which roadmap items will be addressed, since nothing is truly "complete" before implementation. The confidence here is about identification, not completion. The per-phase updates handle actual completion marking.

## Decisions

1. **Single file change**: Only `.claude/agents/planner-agent.md` Stage 2.6 needs modification.
2. **Per-phase roadmap step**: Add as a checklist item (`- [ ] Update ROADMAP.md: ...`) within each phase's `**Tasks:**` section, not as a separate phase.
3. **Phase 1 rename and strengthen**: Rename from "Review and Snapshot" to "Roadmap Assessment and Initial Update". Phase 1 should: (a) identify all roadmap items this task advances, (b) update any items that can be confidently marked based on dependency completions or prior work, (c) add task-reference annotations to items that will be addressed in subsequent phases.
4. **Final phase retained**: Keep the final "Update ROADMAP.md" phase for final reconciliation (mark remaining items, add newly discovered items, update phase progress counts).
5. **No implementation agent changes**: The implementation agent executes plan tasks generically; roadmap edits are just Edit operations.

## Recommendations

### Primary: Rewrite Stage 2.6 in planner-agent.md

Replace the current Stage 2.6 with:

```markdown
### Stage 2.6: Evaluate Roadmap Flag

If `roadmap_flag` is `true` in the delegation context:

1. **ROADMAP.md must exist** - If it was not loaded in Stage 2.5 (file missing), log a warning
   and proceed without roadmap phases. The flag has no effect without an existing ROADMAP.md.
2. When ROADMAP.md exists, the plan MUST include roadmap integration at three levels:

   **a. First phase: "Roadmap Assessment and Initial Update"**
   - Read current ROADMAP.md state and identify which items this task will advance
   - Update items that can be confidently marked based on already-completed dependencies
     or prior work (use `- [x]` with completion annotation)
   - Add planning annotations for items that will be addressed in subsequent phases
   - Record the before-state for final reconciliation

   **b. Per-phase roadmap step in each core phase**
   - Each core implementation phase MUST include a final checklist item:
     `- [ ] Update ROADMAP.md: mark any items completed by this phase`
   - The item should reference specific roadmap items when known at plan time
   - Example: `- [ ] Update ROADMAP.md: mark "Agent frontmatter validation" complete`
   - If a phase does not advance any roadmap items, the step reads:
     `- [ ] Update ROADMAP.md: no items to update (verify)`

   **c. Last phase: "Final ROADMAP.md Reconciliation"**
   - Verify all completed items are properly annotated with
     `*(Completed: Task {N}, {DATE})*`
   - Add any new roadmap items discovered during implementation
   - Update phase progress (count completed vs total items per phase)
   - Ensure no items were missed by per-phase updates

3. These roadmap phases wrap the core implementation phases. The dependency chain is:
   roadmap-assessment (Phase 1) -> core phases (with per-phase roadmap steps) ->
   roadmap-reconciliation (final phase, depends on all core phases)
4. All other plan construction proceeds as usual (Stages 3-5)

If `roadmap_flag` is `false` or not present, skip this stage entirely. Plan construction is
unchanged.
```

### Secondary: No changes needed elsewhere

- `plan-format.md` -- No structural changes needed. Per-phase roadmap steps are regular checklist items.
- `roadmap-format.md` -- Already documents the annotation format used.
- `roadmap-update.md` -- Already documents the matching strategy and safety rules.
- `general-implementation-agent.md` -- Executes phases generically; no awareness of roadmap needed.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Per-phase roadmap steps add noise to simple phases | Low | Medium | Include "no items to update (verify)" for phases without roadmap items, keeping it minimal |
| Phase 1 updates items prematurely (before implementation proves success) | Medium | Low | Phase 1 only marks items from completed dependencies; per-phase steps handle current-task completions |
| Implementation agent misinterprets roadmap update instructions | Medium | Low | Use concrete, specific task text (e.g., "mark X complete") rather than abstract instructions |
| Redundant updates between per-phase steps and final reconciliation | Low | Medium | Final phase is reconciliation/verification, not duplication; it catches missed items |

## Appendix

### Files to Change

| File | Change |
|------|--------|
| `.claude/agents/planner-agent.md` | Rewrite Stage 2.6 (lines 78-89) with the three-level roadmap integration pattern |

### Roadmap Annotation Format Reference

```markdown
- [x] {item text} *(Completed: Task {N}, {DATE})*
```

### Example Per-Phase Roadmap Step

```markdown
### Phase 2: Implement Agent Frontmatter Validation [NOT STARTED]

**Goal**: Create validation script for agent frontmatter fields

**Tasks**:
- [ ] Read all agent files in .claude/agents/ and .claude/extensions/*/agents/
- [ ] Implement frontmatter field validation logic
- [ ] Create validation report output
- [ ] Update ROADMAP.md: mark "Agent frontmatter validation" complete

**Timing**: 1.5 hours
**Depends on**: 1
```
