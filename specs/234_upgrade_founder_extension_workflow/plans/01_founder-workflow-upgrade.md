# Implementation Plan: Task #234

- **Task**: 234 - upgrade_founder_extension_workflow
- **Status**: [IN PROGRESS]
- **Effort**: 8-12 hours
- **Dependencies**: Task #233 (current founder/ extension implementation)
- **Research Inputs**:
  - [01_task-integration-research.md](../reports/01_task-integration-research.md)
  - [02_plan-implement-workflow.md](../reports/02_plan-implement-workflow.md)
- **Artifacts**: plans/01_founder-workflow-upgrade.md (this file)
- **Standards**:
  - .claude/context/core/formats/plan-format.md
  - .claude/context/core/standards/status-markers.md
  - .claude/context/core/system/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: meta

## Overview

Overhaul the founder/ extension to integrate with the task management system. The `/market`, `/analyze`, and `/strategy` commands will create tasks, produce report artifacts in `specs/{NNN}_{SLUG}/` directories, and implement a three-phase forcing questions workflow. This requires adding `plan` routing to the extension manifest, creating new skills and agents for task-integrated workflows, and updating standalone commands to become task shortcuts with optional `--quick` legacy mode.

### Research Integration

Key findings integrated from research reports:
- Language-based routing requires adding `plan` and `implement` keys to manifest.json
- Three-phase workflow: Initial Context -> Interactive Forcing Questions -> Synthesis/Report
- Commands become task shortcuts that create task, run `/plan`, then `/implement`
- Reports output to `strategy/{report-type}.md` by default with plan data in `specs/{NNN}_{SLUG}/`
- Skill-internal postflight pattern handles state management

## Goals & Non-Goals

**Goals**:
- Integrate founder commands with task management system
- Implement three-phase forcing questions workflow during planning
- Support flexible input types: file path, task number, or no argument
- Produce detailed report artifacts in proper task directories
- Maintain backward compatibility with `--quick` flag for standalone mode
- Add `plan` routing to extension manifest for language-based routing

**Non-Goals**:
- Changing the core forcing questions methodology
- Modifying the report templates (market-sizing.md, etc.)
- Changing the `/plan` or `/implement` core commands (only adding extension routing lookup)
- Creating new MCP servers or external integrations

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking existing workflows | High | Medium | Add `--quick` flag to preserve legacy standalone mode |
| `/plan` command modification complexity | High | Low | Test extensively; fallback to skill-planner if routing fails |
| Forcing questions workflow too long | Medium | Medium | Allow `--mode` pre-selection to skip mode question |
| Extension routing not discovered | Medium | Low | Clear error message if extension not loaded |
| Report output path conflicts | Low | Low | Check file exists, prompt user if overwriting |

## Implementation Phases

### Phase 1: Create New Skills [COMPLETED]

**Goal**: Create the new skills for founder-specific planning and implementation workflows.

**Tasks**:
- [ ] Create `skill-founder-plan/SKILL.md` with three-phase workflow support
- [ ] Create `skill-founder-implement/SKILL.md` for executing founder plans
- [ ] Add skill-internal postflight pattern to both skills
- [ ] Include metadata file exchange protocol

**Timing**: 1.5 hours

**Files to create**:
- `.claude/extensions/founder/skills/skill-founder-plan/SKILL.md`
- `.claude/extensions/founder/skills/skill-founder-implement/SKILL.md`

**Verification**:
- Skills follow SKILL.md template format
- Include preflight/postflight sections
- Reference correct agents

---

### Phase 2: Create New Agents [NOT STARTED]

**Goal**: Create the founder-plan-agent and founder-implement-agent with full execution flows.

**Tasks**:
- [ ] Create `founder-plan-agent.md` with:
  - Context parsing from input type (file/task/interactive)
  - Interactive forcing questions for data gathering
  - Plan generation with gathered context stored
  - Metadata file writing
- [ ] Create `founder-implement-agent.md` with:
  - Plan loading and resume point detection
  - Phase execution (TAM -> SAM -> SOM -> Report)
  - Report artifact generation to `strategy/` directory
  - Summary artifact generation to task directory
  - Metadata file writing

**Timing**: 2.5 hours

**Files to create**:
- `.claude/extensions/founder/agents/founder-plan-agent.md`
- `.claude/extensions/founder/agents/founder-implement-agent.md`

**Verification**:
- Agents follow agent frontmatter standard
- Include all execution stages
- Handle error cases and partial completion
- Generate proper metadata files

---

### Phase 3: Update Manifest with Routing [NOT STARTED]

**Goal**: Update manifest.json to include `plan` routing and register new skills/agents.

**Tasks**:
- [ ] Add `plan` routing key: `"founder": "skill-founder-plan"`
- [ ] Update `implement` routing: `"founder": "skill-founder-implement"`
- [ ] Add `research` routing if not using existing skill
- [ ] Register new agents in `provides.agents` array
- [ ] Register new skills in `provides.skills` array
- [ ] Bump version to 2.0.0

**Timing**: 0.5 hours

**Files to modify**:
- `.claude/extensions/founder/manifest.json`

**Verification**:
- JSON is valid
- All new skills/agents registered
- Routing keys correct

---

### Phase 4: Update /plan Command for Extension Routing [NOT STARTED]

**Goal**: Modify the core `/plan` command to check extension routing before defaulting to skill-planner.

**Tasks**:
- [ ] Add extension routing lookup in STAGE 2: DELEGATE
- [ ] Check loaded extension manifests for `routing.plan[language]`
- [ ] Fall back to `skill-planner` if no extension routing found
- [ ] Preserve existing behavior for non-extension languages

**Timing**: 1 hour

**Files to modify**:
- `.claude/commands/plan.md`

**Verification**:
- `/plan` on founder task routes to `skill-founder-plan`
- `/plan` on general/meta tasks still routes to `skill-planner`
- Extension not loaded gracefully falls back to default

---

### Phase 5: Update /implement Command for Extension Routing [NOT STARTED]

**Goal**: Ensure the `/implement` command checks extension routing (may already be implemented).

**Tasks**:
- [ ] Verify extension routing lookup exists in STAGE 2: DELEGATE
- [ ] If not present, add similar pattern to Phase 4
- [ ] Ensure founder tasks route to `skill-founder-implement`
- [ ] Preserve existing behavior for other languages

**Timing**: 0.5 hours

**Files to modify**:
- `.claude/commands/implement.md` (if needed)

**Verification**:
- `/implement` on founder task routes to `skill-founder-implement`
- Other languages route correctly

---

### Phase 6: Transform Standalone Commands [NOT STARTED]

**Goal**: Convert `/market`, `/analyze`, `/strategy` from standalone commands to task-creating shortcuts.

**Tasks**:
- [ ] Update `/market` command:
  - Add input type detection (file path, task number, no argument)
  - Create task in state.json and TODO.md
  - Invoke `/plan {task_number}` for three-phase workflow
  - Invoke `/implement {task_number}` for report generation
  - Add `--quick` flag for legacy standalone mode
- [ ] Update `/analyze` command (same pattern)
- [ ] Update `/strategy` command (same pattern)
- [ ] Ensure proper session ID propagation through workflow

**Timing**: 2.5 hours

**Files to modify**:
- `.claude/extensions/founder/commands/market.md`
- `.claude/extensions/founder/commands/analyze.md`
- `.claude/extensions/founder/commands/strategy.md`

**Verification**:
- `/market "fintech payments"` creates task and runs workflow
- `/market 234` operates on existing task
- `/market /path/to/file.md` uses file as context
- `/market --quick fintech` uses legacy standalone mode
- All three commands follow same pattern

---

### Phase 7: Update EXTENSION.md Documentation [NOT STARTED]

**Goal**: Update extension documentation to reflect new workflow and capabilities.

**Tasks**:
- [ ] Update overview section with task integration description
- [ ] Document new workflow phases
- [ ] Document input type handling
- [ ] Document `--quick` flag for legacy mode
- [ ] Update skill-to-agent mapping table
- [ ] Add migration notes from v1.0 to v2.0

**Timing**: 1 hour

**Files to modify**:
- `.claude/extensions/founder/EXTENSION.md`
- `.claude/extensions/founder/README.md`

**Verification**:
- Documentation accurately describes new workflow
- Examples are updated and correct
- Migration path is clear

---

### Phase 8: Update Context and Index [NOT STARTED]

**Goal**: Update context files and index entries for new agents and skills.

**Tasks**:
- [ ] Update `index-entries.json` with new agents and skills
- [ ] Add load_when conditions for new agents
- [ ] Update `forcing-questions.md` with context-aware question patterns if needed
- [ ] Ensure all new files are discoverable via context index

**Timing**: 0.5 hours

**Files to modify**:
- `.claude/extensions/founder/index-entries.json`
- `.claude/extensions/founder/context/project/founder/patterns/forcing-questions.md` (optional)

**Verification**:
- New agents discoverable via index.json queries
- Context files load correctly for founder-plan-agent

---

## Testing & Validation

- [ ] `/market "fintech payments"` creates task and produces plan + report
- [ ] `/market 234` operates on existing founder task correctly
- [ ] `/market /path/to/context.md` reads file and uses as context
- [ ] `/market --quick fintech` works as legacy standalone mode
- [ ] `/plan {founder_task}` routes to skill-founder-plan
- [ ] `/implement {founder_task}` routes to skill-founder-implement
- [ ] Three-phase forcing questions flow works correctly
- [ ] Report artifacts appear in `strategy/` directory
- [ ] Plan artifacts appear in `specs/{NNN}_{SLUG}/plans/`
- [ ] Task status updates correctly through workflow
- [ ] Git commits created at appropriate checkpoints
- [ ] Error handling preserves partial progress

## Artifacts & Outputs

### Files to Create
- `.claude/extensions/founder/skills/skill-founder-plan/SKILL.md`
- `.claude/extensions/founder/skills/skill-founder-implement/SKILL.md`
- `.claude/extensions/founder/agents/founder-plan-agent.md`
- `.claude/extensions/founder/agents/founder-implement-agent.md`

### Files to Modify
- `.claude/extensions/founder/manifest.json`
- `.claude/extensions/founder/commands/market.md`
- `.claude/extensions/founder/commands/analyze.md`
- `.claude/extensions/founder/commands/strategy.md`
- `.claude/extensions/founder/EXTENSION.md`
- `.claude/extensions/founder/README.md`
- `.claude/extensions/founder/index-entries.json`
- `.claude/commands/plan.md`
- `.claude/commands/implement.md` (if needed)

### Final Outputs
- Plans stored in: `specs/{NNN}_{SLUG}/plans/`
- Reports stored in: `strategy/{report-type}-{topic}.md`
- Summaries stored in: `specs/{NNN}_{SLUG}/summaries/`

## Rollback/Contingency

If implementation fails or causes regressions:

1. **Revert manifest.json** to remove new routing entries
2. **Keep legacy skills** (skill-market, skill-analyze, skill-strategy) - they remain functional
3. **Remove new skills/agents** if they cause issues
4. **Commands revert** to original standalone behavior by removing task creation code
5. **Version 1.0.0** behavior preserved via `--quick` flag throughout

The design intentionally keeps existing skills/agents intact, making rollback straightforward.
