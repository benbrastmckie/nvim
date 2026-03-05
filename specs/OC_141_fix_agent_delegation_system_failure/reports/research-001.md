# Task Registration: OC_141 - Fix Agent Delegation System Failure

**Task**: OC_141  
**Project Name**: fix_agent_delegation_system_failure  
**Status**: NOT STARTED → RESEARCHED  
**Created**: 2026-03-06  

---

## Problem Statement

When workflow commands (like `/plan`) attempt to invoke skills, the **skill specification is displayed instead of executed**. The delegation mechanism via `Task` tool with `subagent_type` is failing to trigger, causing the workflow to halt.

### Evidence from OC_138 Incident

```
→ Skill "skill-planner"
[Thinking output...]
→ Read specs/state.json
→ Read research-001.md
The skill-planner is now executing the planning workflow...
```

**Expected behavior**: The skill-planner should:
1. Load context files via `Read` tool
2. Execute preflight validation
3. **Call `Task` tool with `subagent_type="planner-agent"`**
4. Run postflight updates

**Actual behavior**: 
1. Skill specification content was output to terminal
2. No `Task` tool invocation occurred
3. No subagent was delegated to
4. Command halted

---

## Root Cause Hypotheses

### Hypothesis 1: Missing Tool Invocation in Command Specs
Commands like `plan.md` describe skill invocation but don't actually trigger the skill tool. The `→ Skill "skill-planner"` notation may be descriptive only.

### Hypothesis 2: Skill Loading vs Execution Gap
The `skill` tool may only **load** skill content for reference but not **execute** the workflow described in the skill's `<execution>` stages.

### Hypothesis 3: Context Injection Failure
Skills with `<context_injection>` may fail silently when context files are unavailable, causing fallback to content display rather than execution.

### Hypothesis 4: Subagent Configuration Issue
The `subagent_type="planner-agent"` (and other agents) may not be properly configured in the OpenCode system, causing delegation to fail.

---

## Files to Audit

### Command Specifications (all 12+ commands)
- `.opencode/commands/plan.md` - Should invoke skill-planner
- `.opencode/commands/implement.md` - Should invoke skill-implementer
- `.opencode/commands/research.md` - Should invoke skill-researcher
- `.opencode/commands/revise.md` - Should invoke skill-planner
- `.opencode/commands/meta.md` - Should invoke skill-meta
- `.opencode/commands/task.md` - Should invoke skill-orchestrator
- `.opencode/commands/learn.md` - Should invoke skill-learn
- `.opencode/commands/refresh.md` - Should invoke skill-refresh
- `.opencode/commands/remember.md` - Should invoke skill-remember
- `.opencode/commands/review.md` - Should invoke skill-reviewer
- `.opencode/commands/status.md` - Should invoke skill-status-sync
- `.opencode/commands/todo.md` - May invoke skill-todo

### Skill Definitions (all 11+ skills)
- `.opencode/skills/skill-planner/SKILL.md`
- `.opencode/skills/skill-implementer/SKILL.md`
- `.opencode/skills/skill-researcher/SKILL.md`
- `.opencode/skills/skill-meta/SKILL.md`
- `.opencode/skills/skill-learn/SKILL.md`
- `.opencode/skills/skill-refresh/SKILL.md`
- `.opencode/skills/skill-remember/SKILL.md`
- `.opencode/skills/skill-status-sync/SKILL.md`
- `.opencode/skills/skill-git-workflow/SKILL.md`
- `.opencode/skills/skill-orchestrator/SKILL.md`
- `.opencode/skills/skill-neovim-research/SKILL.md`
- `.opencode/skills/skill-neovim-implementation/SKILL.md`

### Subagent Definitions
- `.opencode/agent/subagents/planner-agent.md`
- `.opencode/agent/subagents/general-implementation-agent.md`
- `.opencode/agent/subagents/general-research-agent.md`
- `.opencode/agent/subagents/code-reviewer-agent.md`
- `.opencode/agent/subagents/neovim-implementation-agent.md`
- `.opencode/agent/subagents/neovim-research-agent.md`

### System Configuration
- `.opencode/AGENTS.md` - Agent registration and routing
- `.opencode/config.yaml` or similar - System configuration

---

## Impact Assessment

**Severity**: CRITICAL  
**Scope**: System-wide workflow failure  

All workflow commands that depend on skill delegation are broken:
- `/plan` - Cannot create implementation plans
- `/implement` - Cannot execute implementations
- `/research` - Cannot conduct research
- `/revise` - Cannot revise plans
- `/meta` - Cannot execute meta commands
- `/learn` - Cannot scan for learnings
- `/refresh` - Cannot refresh/cleanup
- `/remember` - Cannot store memories
- `/review` - Cannot review code
- `/status` - Cannot sync status

**Without this fix, the entire agent workflow system is non-functional.**

---

## Potential Solutions

### Option A: Add Explicit Skill Tool Calls
Update all command specifications to explicitly call the `skill` tool:

```markdown
## Step 6: Delegate to skill-planner

→ Tool: skill
→ Name: skill-planner
→ Arguments: {task_number: N, action: planning}
```

### Option B: Create Command Router Agent
Implement a router agent that interprets command specs and dispatches to appropriate skills/agents (as planned in OC_135).

### Option C: Fix Skill Execution Model
Ensure that when `skill` tool is called, it actually executes the `<execution>` stages rather than just returning content.

### Option D: Direct Agent Delegation
Bypass skills entirely and have commands directly delegate to agents via `Task` tool.

---

## Related Tasks

- **OC_135**: enforce_workflow_command_delegation - This task was supposed to fix command routing but clearly didn't solve the core issue
- **OC_137**: investigate_and_fix_planner_agent_format_compliance - Related to planner-agent issues
- **OC_138**: fix_plan_metadata_status_synchronization - The incident that revealed this bug

---

## Verification Checklist

- [ ] `/plan OC_N` successfully creates a plan file
- [ ] `/research OC_N` successfully creates research artifacts
- [ ] `/implement OC_N` successfully executes phases
- [ ] All skills execute their `<execution>` stages
- [ ] Subagents receive proper context injection
- [ ] No skill content is displayed to user (only execution results)

---

## Next Steps

1. **Research**: Audit command-to-skill routing mechanism
2. **Research**: Verify subagent registration and availability
3. **Research**: Test skill tool execution model
4. **Plan**: Design fix approach (likely Option C or D)
5. **Implement**: Fix delegation system
6. **Test**: Verify all workflow commands work

---

**Priority**: P0 - Critical System Failure  
**Estimated Effort**: 4-6 hours  
**Dependencies**: None (this is foundational)  
