# Implementation Plan: Task #240

- **Task**: 240 - Fix /market command forcing questions workflow
- **Status**: [IMPLEMENTING]
- **Effort**: 4-6 hours
- **Dependencies**: None
- **Research Inputs**: [01_market-workflow-research.md](../reports/01_market-workflow-research.md)
- **Artifacts**: plans/01_founder-workflow-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Restructure the founder extension commands (/market, /analyze, /strategy) to ask forcing questions BEFORE task creation, using gathered data to create richer task entries. Add a `task_type` field to enable type-based routing for finer-grained control over /research, /plan, and /implement behavior on founder tasks. This aligns founder commands with the pre-task data gathering pattern requested in tasks 233/234 but with reversed sequencing.

### Research Integration

Key findings from research report 01_market-workflow-research.md:
- Current implementation creates task FIRST, then runs forcing questions during research phase
- Requested workflow reverses this: forcing questions FIRST, then task creation with gathered data
- All three commands (/market, /analyze, /strategy) need the same restructuring
- manifest.json routing currently uses `language: "founder"` for all tasks, not differentiating types
- Type-based routing would enable /research to route to appropriate agent based on task_type

## Goals & Non-Goals

**Goals**:
- Restructure /market, /analyze, /strategy to ask forcing questions BEFORE task creation
- Store forcing question Q&A data in task metadata
- Add `task_type` field to state.json schema for founder tasks
- Update manifest.json routing to support task_type-based research routing
- Ensure uniform implementation across all three founder commands

**Non-Goals**:
- Adding new forcing questions (use existing questions)
- Changing the typst output generation (already working via task 238)
- Modifying /plan or /implement commands (they already work correctly)
- Adding new modes to the existing commands

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking existing quick mode (--quick) | Medium | Low | Preserve --quick path unchanged, only modify task workflow mode |
| Task creation fails after questions answered | High | Low | Capture Q&A in temp file before task creation, enable recovery |
| state.json schema change breaks existing tasks | High | Medium | Make task_type optional with null default for backward compatibility |
| Commands become too long/complex | Medium | Medium | Extract pre-task question flow to shared helper function |

## Implementation Phases

### Phase 1: Schema Update for task_type Field [COMPLETED]

**Goal**: Add `task_type` field to state.json schema and update documentation

**Tasks**:
- [ ] Update `.claude/rules/state-management.md` to document `task_type` field
- [ ] Add task_type to state.json Entry section (optional field, values: market|analyze|strategy|null)
- [ ] Update TODO.md Entry format to include task_type display

**Timing**: 30 minutes

**Files to modify**:
- `.claude/rules/state-management.md` - Add task_type field documentation

**Verification**:
- Documentation correctly describes task_type as optional field
- Values are constrained to market|analyze|strategy|null

---

### Phase 2: Update manifest.json Routing [COMPLETED]

**Goal**: Enable type-based routing for founder research tasks

**Tasks**:
- [ ] Update `.claude/extensions/founder/manifest.json` routing section
- [ ] Add task_type-based routing under research key
- [ ] Map market -> skill-market, analyze -> skill-analyze, strategy -> skill-strategy
- [ ] Preserve fallback to skill-market for tasks without task_type (backward compatibility)

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/manifest.json` - Update routing structure

**Verification**:
- manifest.json is valid JSON
- Routing structure supports both language and task_type lookup

---

### Phase 3: Restructure /market Command [COMPLETED]

**Goal**: Move forcing questions BEFORE task creation in /market command

**Tasks**:
- [ ] Create new STAGE 0: PRE-TASK FORCING QUESTIONS section
- [ ] Move mode selection (AskUserQuestion) to STAGE 0
- [ ] Add abbreviated forcing questions for essential data gathering in STAGE 0
- [ ] Store Q&A responses in temporary variables for task creation
- [ ] Update Step 4 (task creation) to include task_type: "market" and forcing_data metadata
- [ ] Update STAGE 2 delegation to pass pre-gathered data to skill-market
- [ ] Update skill-market to use pre-gathered data instead of running full forcing questions

**Timing**: 1.5 hours

**Files to modify**:
- `.claude/extensions/founder/commands/market.md` - Restructure command flow
- `.claude/extensions/founder/skills/skill-market/SKILL.md` - Accept pre-gathered data

**Verification**:
- /market without args prompts for mode and essential questions before creating task
- Task is created with task_type: "market" in state.json
- --quick mode still works without pre-task questions

---

### Phase 4: Restructure /analyze Command [COMPLETED]

**Goal**: Apply same pre-task forcing questions pattern to /analyze command

**Tasks**:
- [ ] Create new STAGE 0: PRE-TASK FORCING QUESTIONS section
- [ ] Add mode selection (LANDSCAPE|DEEP|POSITION|BATTLE) to STAGE 0
- [ ] Add essential competitor questions before task creation
- [ ] Store Q&A responses for task creation
- [ ] Update Step 4 to include task_type: "analyze" and forcing_data metadata
- [ ] Update STAGE 2 delegation to pass pre-gathered data to skill-analyze
- [ ] Update skill-analyze to use pre-gathered data

**Timing**: 1 hour

**Files to modify**:
- `.claude/extensions/founder/commands/analyze.md` - Restructure command flow
- `.claude/extensions/founder/skills/skill-analyze/SKILL.md` - Accept pre-gathered data

**Verification**:
- /analyze without args prompts for mode and essential questions before creating task
- Task is created with task_type: "analyze" in state.json
- --quick mode unchanged

---

### Phase 5: Restructure /strategy Command [COMPLETED]

**Goal**: Apply same pre-task forcing questions pattern to /strategy command

**Tasks**:
- [ ] Create new STAGE 0: PRE-TASK FORCING QUESTIONS section
- [ ] Add mode selection (LAUNCH|SCALE|PIVOT|EXPAND) to STAGE 0
- [ ] Add essential GTM questions before task creation
- [ ] Store Q&A responses for task creation
- [ ] Update Step 4 to include task_type: "strategy" and forcing_data metadata
- [ ] Update STAGE 2 delegation to pass pre-gathered data to skill-strategy
- [ ] Update skill-strategy to use pre-gathered data

**Timing**: 1 hour

**Files to modify**:
- `.claude/extensions/founder/commands/strategy.md` - Restructure command flow
- `.claude/extensions/founder/skills/skill-strategy/SKILL.md` - Accept pre-gathered data

**Verification**:
- /strategy without args prompts for mode and essential questions before creating task
- Task is created with task_type: "strategy" in state.json
- --quick mode unchanged

---

### Phase 6: Update /research Command Type-Based Routing [COMPLETED]

**Goal**: Enable /research to route founder tasks by task_type

**Tasks**:
- [ ] Update `.claude/commands/research.md` to check for task_type field
- [ ] Add routing logic: if language == "founder" AND task_type exists, use task_type for routing
- [ ] Update extension routing lookup to use task_type from state.json
- [ ] Preserve fallback to language-only routing for backward compatibility

**Timing**: 45 minutes

**Files to modify**:
- `.claude/commands/research.md` - Add task_type routing logic

**Verification**:
- /research on task with task_type: "market" routes to skill-market
- /research on task with task_type: "analyze" routes to skill-analyze
- /research on task with task_type: "strategy" routes to skill-strategy
- /research on founder task without task_type uses default skill-market (backward compatible)

---

### Phase 7: Documentation and Testing [NOT STARTED]

**Goal**: Update extension documentation and verify end-to-end workflows

**Tasks**:
- [ ] Update `.claude/extensions/founder/EXTENSION.md` to document new workflow
- [ ] Document task_type field in extension documentation
- [ ] Create test workflow: run /market -> verify pre-task questions -> verify task creation
- [ ] Verify /plan and /implement work correctly with task_type field present
- [ ] Verify --quick mode continues to work for all three commands

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/founder/EXTENSION.md` - Update workflow documentation

**Verification**:
- Full workflow /market -> /plan -> /implement produces expected typst output
- All three commands maintain backward compatibility
- --quick mode bypasses pre-task questions correctly

---

## Testing & Validation

- [ ] /market "description" asks mode + essential questions BEFORE task creation
- [ ] /analyze "description" asks mode + essential questions BEFORE task creation
- [ ] /strategy "description" asks mode + essential questions BEFORE task creation
- [ ] Task created includes task_type field in state.json
- [ ] /research {N} routes correctly based on task_type
- [ ] --quick mode bypasses pre-task questions for all commands
- [ ] Existing tasks without task_type continue to work (backward compatibility)
- [ ] /plan and /implement unaffected by changes

## Artifacts & Outputs

- Updated commands: market.md, analyze.md, strategy.md
- Updated skills: skill-market/SKILL.md, skill-analyze/SKILL.md, skill-strategy/SKILL.md
- Updated manifest: manifest.json
- Updated documentation: state-management.md, EXTENSION.md
- Updated /research: research.md

## Rollback/Contingency

If pre-task forcing questions prove disruptive:
1. Revert commands to original flow (task first, questions in research)
2. Keep task_type field (harmless addition)
3. Consider making pre-task questions optional via a flag (--quick-task)

The key safety net is that --quick mode remains unchanged, providing an escape hatch for users who prefer the old flow.
