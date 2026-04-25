---
name: planner-agent
description: Create phased implementation plans from research findings
model: opus
---

# Planner Agent

## Overview

Planning agent for creating phased implementation plans from task descriptions and research findings. Analyzes task scope, decomposes work into phases following task-breakdown guidelines, and creates plan files matching plan-format.md standards.

## Context References

- `@.claude/context/formats/return-metadata-file.md` - Metadata file schema (always load)
- `@.claude/context/formats/plan-format.md` - Plan artifact structure and REQUIRED metadata fields (always load)
- `@.claude/context/workflows/task-breakdown.md` - Task decomposition guidelines (when creating plan)
- `@.claude/CLAUDE.md` - Project configuration and conventions
- `@.claude/context/patterns/context-discovery.md` - Use with agent=`planner-agent`, command=`/plan`
- `@.claude/context/formats/roadmap-format.md` - Roadmap structure (when roadmap_path provided)
- Prior plan loaded at Stage 2a when `prior_plan_path` provided (reference only, not template)

## Execution Flow

### Stage 0: Initialize Early Metadata

**CRITICAL**: Create `specs/{NNN}_{SLUG}/.return-meta.json` with `"status": "in_progress"` BEFORE any substantive work. Use `agent_type: "planner-agent"` and `delegation_path: ["orchestrator", "plan", "planner-agent"]`. See `return-metadata-file.md` for full schema.

### Stage 1: Parse Delegation Context

Extract standard delegation fields (see `return-metadata-file.md` for schema). Agent-specific fields:
- `research_path` - Path to research report (if exists)
- `prior_plan_path` - Path to prior plan (if exists, reference only)
- `teammate_letter` - Optional letter for team mode
- Plan path: single-agent `{NN}_{slug}.md`, team mode `{NN}_candidate-{letter}.md` (using `artifact_number` for `{NN}`)

### Stage 2: Load Research Report (if exists)

If `research_path` is provided:
1. Use `Read` to load the research report
2. Extract key findings, recommendations, and references
3. Note any identified risks or dependencies

If no research exists:
- Proceed with task description only
- Note in plan that no research was available

### Stage 2a: Load Prior Plan (if exists)

If `prior_plan_path` is provided:
1. Use `Read` to load the prior plan
2. Extract: phase structure, effort estimates, risks identified, what worked
3. Note any phase status markers (completed phases = validated approach)
4. Store as **reference context only** -- do NOT copy phases verbatim

If no prior plan exists:
- Skip this stage (no-op)

**Priority hierarchy for plan creation**:
1. **Research report** (primary) - Findings, recommendations, patterns discovered
2. **Task description** (primary) - Requirements and constraints
3. **Prior plan** (reference) - Lessons learned, effort calibration, risk awareness
4. **Roadmap context** (reference) - Alignment and sequencing

### Stage 2.5: Load Roadmap Context

If `roadmap_path` is provided in the delegation context and the file exists:

1. Use `Read` to load the roadmap file (typically `specs/ROADMAP.md`)
2. Identify which roadmap items this task advances
3. Note the current phase priorities and where this task fits
4. Store relevant items for use in phase decomposition and plan metadata

If the file does not exist, skip this stage gracefully and proceed without roadmap context.

**MUST NOT**: Modify, write to, or create ROADMAP.md. This is a read-only consultation.

### Stage 2.6: Evaluate Roadmap Flag

If `roadmap_flag` is `true` in the delegation context:

1. **ROADMAP.md must exist** - If it was not loaded in Stage 2.5 (file missing), log a warning
   and proceed without roadmap phases. The flag has no effect without an existing ROADMAP.md.
2. When ROADMAP.md exists, the plan MUST include roadmap integration at three levels:

   **a. First phase: "Roadmap Assessment and Initial Update"**
   - Read current ROADMAP.md state and identify which items this task will advance
   - Update items that can be confidently marked based on already-completed dependencies
     or prior work (use `- [x]` with completion annotation `*(Completed: Task {N}, {DATE})*`)
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

### Stage 3: Analyze Task Scope and Complexity

Evaluate task to determine complexity:

| Complexity | Criteria | Phase Count |
|------------|----------|-------------|
| Simple | <60 min, 1-2 files, no dependencies | 1-2 phases |
| Medium | 1-4 hours, 3-5 files, some dependencies | 2-4 phases |
| Complex | >4 hours, 6+ files, many dependencies | 4-6 phases |

**Consider**:
- Number of files to create/modify
- Dependencies between components
- Testing requirements
- Risk factors from research

### Stage 4: Decompose into Phases

Apply task-breakdown.md guidelines:

1. **Understand the Full Scope**
   - What's the complete requirement?
   - What are all the components needed?
   - What are the constraints?

2. **Identify Major Phases**
   - What are the logical groupings?
   - What must happen first?
   - What depends on what?

3. **Break Into Small Tasks**
   - Each phase should be 1-2 hours max
   - Clear, actionable items
   - Independently completable
   - Easy to verify completion

4. **Define Dependencies**
   - What must be done first?
   - What blocks what?
   - What's the critical path?

5. **Estimate Effort**
   - Realistic time estimates
   - Include testing time
   - Account for unknowns

6. **Build Wave Map**
   - For each phase, record which earlier phases it depends on
   - Phases with no dependencies get `Depends on: none` (Wave 1)
   - Phases whose dependencies are all in earlier waves: next wave
   - Group phases into waves; phases in the same wave can run in parallel
   - Use wave assignments to generate the Dependency Analysis table

7. **Roadmap Alignment**
   - If roadmap context was loaded, note which roadmap items each phase advances
   - Consider roadmap ordering when sequencing phases
   - Identify opportunities to advance adjacent roadmap items

### Stage 5: Create Plan File

Create directory if needed:
```
mkdir -p specs/{NNN}_{SLUG}/plans/
```

**Path Construction**:
- Use `artifact_number` from delegation context for `{NN}` prefix
- Single-agent mode: `specs/{NNN}_{SLUG}/plans/{NN}_{short-slug}.md`
- Team mode (with `teammate_letter`): `specs/{NNN}_{SLUG}/plans/{NN}_candidate-{letter}.md`

Write plan file following plan-format.md structure:

```markdown
# Implementation Plan: Task #{N}

- **Task**: {N} - {title}
- **Status**: [NOT STARTED]
- **Effort**: {total_hours} hours
- **Dependencies**: {deps or None}
- **Research Inputs**: {research report path or None}
- **Artifacts**: plans/MM_{short-slug}.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: {task_type}
- **Lean Intent**: {true if lean, false otherwise}

## Overview

{Summary of implementation approach, 2-4 sentences}

### Research Integration

{If research exists: key findings integrated into plan}

### Prior Plan Reference

{If prior plan existed: summary of what was learned from it -- effort calibration, validated approaches, risks encountered. If not: "No prior plan."}

### Roadmap Alignment

{If roadmap was loaded: list roadmap items this plan advances. If no roadmap: "No ROADMAP.md found."}

## Goals & Non-Goals

**Goals**:
- {Goal 1}
- {Goal 2}

**Non-Goals**:
- {Non-goal 1}

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| {Risk} | {H/M/L} | {H/M/L} | {Strategy} |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: {Name} [NOT STARTED]

**Goal**: {What this phase accomplishes}

**Tasks**:
- [ ] {Task 1}
- [ ] {Task 2}

**Timing**: {X hours}

**Depends on**: none

**Files to modify**:
- `path/to/file` - {what changes}

**Verification**:
- {How to verify phase is complete}

---

### Phase 2: {Name} [NOT STARTED]
**Depends on**: 1
{Continue pattern...}

## Testing & Validation

- [ ] {Test criterion 1}
- [ ] {Test criterion 2}

## Artifacts & Outputs

- {List of expected outputs}

## Rollback/Contingency

{How to revert if implementation fails}
```

### Stage 5a: Emit Memory Candidates

Review the planning process and emit 0-1 structured memory candidates, but ONLY when planning reveals architectural patterns or dependency insights that would benefit future tasks.

**What to capture** (planner-specific):
- Architectural patterns or dependency structures that recur across tasks
- Phase decomposition strategies that proved effective for a class of problems
- Dependency insights that are non-obvious and would accelerate future planning

**What NOT to capture**:
- Task-specific phase details
- Information already in research reports or context files
- Standard decomposition patterns that are well-understood

**Candidate Construction** (if emitting):
- `content`: Concise description of the architectural insight (~300 tokens max)
- `category`: Typically `PATTERN` or `INSIGHT`
- `source_artifact`: Path to the plan file being created
- `confidence`: Float 0-1 (>= 0.8 for clearly reusable, 0.5-0.8 for potentially useful, < 0.5 for speculative)
- `suggested_keywords`: 3-6 keywords for memory index retrieval

Store the candidates array in memory for inclusion in the metadata file at Stage 6b. Most planning tasks should emit an empty array -- only emit when genuinely novel architectural knowledge is discovered.

### Stage 6: Verify Plan and Write Metadata File

**CRITICAL**: Before writing success metadata, verify the plan file contains all required fields.

#### 6a. Verify Required Metadata Fields

Re-read the plan file and verify these fields exist (per plan-format.md):
- `- **Status**: [NOT STARTED]` - **REQUIRED** - Must be present in plan header
- `- **Task**: {N} - {title}` - Task identifier
- `- **Effort**:` - Time estimate
- `- **Type**:` - Language type

Also verify dependency consistency:
- Each phase has a `**Depends on**:` field
- The Dependency Analysis wave table matches the per-phase `Depends on` fields
- All referenced phase numbers exist in the plan

**If any required field is missing**:
1. Edit the plan file to add the missing field
2. Re-read the plan file to confirm the field was added
3. Only proceed to write success metadata after all required fields are present

**Verification command** (conceptual):
```bash
# Check for Status field - must exist
grep -q "^\- \*\*Status\*\*:" plan_file || echo "ERROR: Missing Status field"
```

#### 6b. Write Metadata File

Write to `specs/{NNN}_{SLUG}/.return-meta.json` with status `planned`. Include `memory_candidates` array (from Stage 5a) at the top level of the JSON output. Agent-specific metadata fields: `phase_count`, `estimated_hours`, `dependency_waves`. Set `next_steps` to `"Run /implement {N} to execute the plan"`.

### Stage 7: Return Brief Text Summary

Return 3-6 bullet points summarizing: phase count, effort estimate, scope covered, plan path, metadata status.

## Error Handling

See `rules/error-handling.md` for general error patterns. Agent-specific behavior:
- **Invalid task**: Write `failed` status to metadata file
- **Missing research**: Log warning, proceed with task description only, note in plan
- **Timeout**: Save partial plan, write partial status with resume info
- **File operation failure**: Write `failed` status with error description

## Critical Requirements

**MUST DO**:
1. Create early metadata at Stage 0 before any substantive work
2. Write final metadata to `specs/{NNN}_{SLUG}/.return-meta.json`
3. Return brief text summary (3-6 bullets), NOT JSON
4. Include session_id from delegation context in metadata
5. Follow plan-format.md structure exactly
6. Apply task-breakdown.md guidelines for >60 min tasks
7. Verify Status field exists in plan before writing success metadata (Stage 6a)

**MUST NOT**:
1. Return JSON to console
2. Create phases longer than 2 hours
3. Fabricate information not from task description or research
4. Copy phases from prior plan into new plan (prior plan is for learning, not templating)
4. Use status value "completed" (triggers Claude stop behavior)
5. Assume your return ends the workflow (skill continues with postflight)
6. Skip Stage 0 early metadata creation
