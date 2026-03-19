# Implementation Plan: Task #241

- **Task**: 241 - Add /spawn command, skill-spawn wrapper, and spawn-agent
- **Status**: [NOT STARTED]
- **Effort**: 4-6 hours
- **Dependencies**: None
- **Research Inputs**: [01_meta-research.md](../reports/01_meta-research.md)
- **Artifacts**: plans/01_spawn-workflow.md (this file)
- **Standards**:
  - .claude/context/core/formats/plan-format.md
  - .claude/context/core/formats/status-markers.md
  - .claude/context/core/system/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: meta

## Overview

Create the complete /spawn workflow for recovering from blocked implementations. The workflow enables users to invoke `/spawn N [prompt]` on a blocked task, which triggers blocker analysis, minimal task decomposition, and proper dependency management. Three components are needed: spawn-agent (analysis/decomposition), skill-spawn (thin wrapper with state management postflight), and /spawn command (user entry point).

### Research Integration

The research report (01_meta-research.md) provides complete specifications for:
- Command syntax and validation requirements
- Skill execution flow (12 stages) with state management
- Agent execution stages (0-5) with analysis methodology
- Return file schemas (.spawn-return.json format)
- Dependency update patterns for parent task linking

## Goals & Non-Goals

**Goals**:
- Enable recovery from blocked task implementations via `/spawn N [prompt]`
- Analyze blockers and decompose into minimal new tasks
- Establish proper parent-child task relationships with dependencies
- Update both state.json and TODO.md atomically
- Follow existing command/skill/agent patterns exactly

**Non-Goals**:
- Automatic blocker detection (requires explicit /spawn invocation)
- Modifying the /implement command (spawn is a separate workflow)
- Supporting spawn without a task number (task must exist)
- Recursive spawning (spawned tasks are independent, not nested spawns)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Dependency cycle creation | High | Low | Validation in postflight: new tasks depend ON parent, parent depends ONLY on existing deps |
| State desync between state.json and TODO.md | High | Medium | Atomic two-phase update pattern, rollback on failure |
| Agent creates too many tasks | Medium | Medium | Task Minimization Principle enforced in agent prompt, 2-4 task limit |
| Return file parsing fails | Medium | Low | Structured JSON schema with validation, fallback error handling |
| Topological sort fails on invalid deps | Medium | Low | Validate dependency graph before Kahn's algorithm |

## Implementation Phases

### Phase 1: Create spawn-agent [NOT STARTED]

**Goal**: Create the blocker analysis and task decomposition agent that researches blockers and proposes minimal new tasks.

**Tasks**:
- [ ] Create `.claude/agents/spawn-agent.md` with frontmatter (name, description, model, tools)
- [ ] Define 6 execution stages: early metadata, load context, analyze blocker, decompose tasks, write report, write return file
- [ ] Implement blocker analysis with root cause categories (missing prerequisite, external dependency, design ambiguity, scope creep, technical unknowns)
- [ ] Implement task minimization logic with explicit dependency reasoning
- [ ] Define report format for `specs/{NNN}_{SLUG}/reports/02_spawn-analysis.md`
- [ ] Define return file schema for `specs/{NNN}_{SLUG}/.spawn-return.json`
- [ ] Add critical requirements section (no state writes, only report and return file outputs)

**Timing**: 1.5 hours

**Files to create**:
- `.claude/agents/spawn-agent.md` - Full agent specification

**Verification**:
- Agent file exists with correct frontmatter fields
- All 6 stages documented with clear boundaries
- Task minimization principles explicitly stated
- Return file schema matches skill expectations

---

### Phase 2: Create skill-spawn [NOT STARTED]

**Goal**: Create the thin wrapper skill that delegates to spawn-agent and handles all state management in postflight.

**Tasks**:
- [ ] Create `.claude/skills/skill-spawn/SKILL.md` with frontmatter (name, description, version, author)
- [ ] Implement 14-stage execution flow from research spec
- [ ] Stage 1: Parse delegation context
- [ ] Stage 2: Preflight status update (set parent to blocked)
- [ ] Stage 3: Update TODO.md parent status
- [ ] Stage 4: Delegate to spawn-agent via Task tool
- [ ] Stage 5: Read return metadata from .spawn-return.json
- [ ] Stage 6: Get next task numbers from state.json
- [ ] Stage 7: Apply topological sort (Kahn's algorithm)
- [ ] Stage 8: Create new task directories with research artifact stubs
- [ ] Stage 9: Update state.json with new tasks (parent_task, dependencies, artifacts)
- [ ] Stage 10: Update TODO.md with new task entries
- [ ] Stage 11: Update parent task dependencies in state.json
- [ ] Stage 12: Update parent task dependencies in TODO.md
- [ ] Stage 13: Git commit with session ID
- [ ] Stage 14: Cleanup .spawn-return.json

**Timing**: 2 hours

**Files to create**:
- `.claude/skills/skill-spawn/SKILL.md` - Full skill specification

**Verification**:
- Skill file exists with correct frontmatter
- All 14 stages documented with jq commands
- Two-phase state update pattern used
- Issue #1132 workarounds applied (use "| not" pattern)
- MUST NOT section clearly defines postflight boundaries

---

### Phase 3: Create /spawn command [NOT STARTED]

**Goal**: Create the user-facing command that validates input and delegates to skill-spawn.

**Tasks**:
- [ ] Create `.claude/commands/spawn.md` with frontmatter (description, allowed-tools, argument-hint, model)
- [ ] Implement CHECKPOINT 1: GATE IN with session ID generation
- [ ] Validate task exists in state.json
- [ ] Validate status allows spawn (implementing, partial, blocked, planned, researched)
- [ ] Reject completed and abandoned tasks with clear error messages
- [ ] Extract optional blocker prompt from arguments
- [ ] Load task context and latest plan path
- [ ] Implement STAGE 2: DELEGATE to skill-spawn
- [ ] Implement CHECKPOINT 2: GATE OUT with return validation
- [ ] Implement CHECKPOINT 3: COMMIT (note: skill handles commit, command verifies)
- [ ] Define output format showing spawned tasks and next steps

**Timing**: 1 hour

**Files to create**:
- `.claude/commands/spawn.md` - Full command specification

**Verification**:
- Command file exists with correct frontmatter
- All 3 checkpoints documented (GATE IN, DELEGATE, GATE OUT)
- Status validation covers all edge cases
- Output format shows dependency graph visualization

---

### Phase 4: Update CLAUDE.md [NOT STARTED]

**Goal**: Add skill-spawn to agent mapping and command reference.

**Tasks**:
- [ ] Add `skill-spawn -> spawn-agent` to Skill-to-Agent Mapping table
- [ ] Add `/spawn` to Command Reference table with syntax `/spawn N [prompt]`
- [ ] Update "Standard actions" in git commit conventions if needed

**Timing**: 15 minutes

**Files to modify**:
- `.claude/CLAUDE.md` - Add to Skill-to-Agent Mapping table
- `.claude/CLAUDE.md` - Add to Command Reference table

**Verification**:
- Skill-to-Agent Mapping table includes skill-spawn entry
- Command Reference table includes /spawn entry
- No duplicate entries

---

### Phase 5: Verification and Testing [NOT STARTED]

**Goal**: Verify the complete workflow functions correctly.

**Tasks**:
- [ ] Verify spawn-agent can be loaded (syntax check)
- [ ] Verify skill-spawn can be loaded (syntax check)
- [ ] Verify /spawn command appears in command list
- [ ] Test validation: `/spawn 999` should fail (task not found)
- [ ] Test validation: completed task should be rejected
- [ ] Test validation: abandoned task should be rejected
- [ ] Verify CLAUDE.md entries are correctly formatted
- [ ] Run linter on new files: `bash .claude/scripts/validate-all-standards.sh --staged`

**Timing**: 30 minutes

**Files to verify**:
- `.claude/agents/spawn-agent.md`
- `.claude/skills/skill-spawn/SKILL.md`
- `.claude/commands/spawn.md`
- `.claude/CLAUDE.md`

**Verification**:
- All files pass syntax validation
- Linter reports no errors
- Command is discoverable via `/help`
- Error messages are clear and actionable

---

## Testing & Validation

- [ ] Agent file has valid frontmatter YAML
- [ ] Skill file has valid frontmatter YAML
- [ ] Command file has valid frontmatter YAML
- [ ] jq commands use "| not" pattern (no bare `!=` operators)
- [ ] All state updates use two-phase pattern (write to tmp, mv to target)
- [ ] All bash blocks under 400 lines
- [ ] No emojis in file content
- [ ] Session ID propagation through delegation chain
- [ ] Linter passes on all new files

## Artifacts & Outputs

- `.claude/agents/spawn-agent.md` - Blocker analysis agent
- `.claude/skills/skill-spawn/SKILL.md` - Thin wrapper skill with postflight
- `.claude/commands/spawn.md` - User-facing command
- `.claude/CLAUDE.md` - Updated with new entries (Skill-to-Agent Mapping, Command Reference)

## Rollback/Contingency

If implementation fails:
1. Delete created files: `rm -f .claude/agents/spawn-agent.md .claude/skills/skill-spawn/SKILL.md .claude/commands/spawn.md`
2. Revert CLAUDE.md changes: `git checkout .claude/CLAUDE.md`
3. Remove task directory if empty: `rmdir .claude/skills/skill-spawn`
4. Task remains at [PLANNED] status for retry

No state modifications are made to specs/ during implementation, so no risk of corrupting task state.
