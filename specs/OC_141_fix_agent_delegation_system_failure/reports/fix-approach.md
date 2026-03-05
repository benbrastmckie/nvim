# Fix Approach Design Report

**Task**: OC_141 - Fix Agent Delegation System Failure  
**Phase**: 4 - Design Fix Approach  
**Date**: 2026-03-06  
**Status**: COMPLETED

---

## Problem Analysis

The delegation chain is:
```
User → Command → Skill → Task → Agent
       ↑           ↑
       |           |
    BROKEN      WORKS (if invoked)
```

Commands describe skill invocation but don't execute skills. The skill tool exists and skills are correctly designed, but the command-to-skill handoff is broken.

## Option Analysis

### Option A: Add Explicit Skill Tool Calls to Commands
**Description**: Update all 12+ command specifications to explicitly invoke the skill tool.

**Pros:**
- Minimal change to existing architecture
- Clear, explicit invocation
- Skills continue to work as designed
- Easier to debug and trace

**Cons:**
- Requires updating 12+ command files
- Command specs become longer

**Implementation:**
Add to each command after Step 5:
```markdown
### 6. Invoke Skill

Based on command type, invoke appropriate skill:

**Tool**: skill
**Parameters**:
- name: skill-{name}
- prompt: Task number N
```

### Option B: Create Command Router Agent
**Description**: Create a router agent that interprets command specs and dispatches to skills.

**Pros:**
- Centralized routing logic
- Commands stay thin

**Cons:**
- More complex
- Additional layer of indirection
- Requires new agent

### Option C: Fix Skill Execution Model
**Description**: Ensure skill tool actually executes stages instead of just returning content.

**Pros:**
- No changes to command specs
- Skills work as intended

**Cons:**
- Requires changing tool behavior at system level
- May break other uses of skill tool

### Option D: Direct Agent Delegation
**Description**: Bypass skills entirely, have commands directly use Task tool to invoke agents.

**Pros:**
- Eliminates one layer
- Direct delegation

**Cons:**
- Loses skill benefits (context injection, lifecycle management)
- Duplicates logic across commands

## Recommended Approach: Option A

**Rationale:**
1. Least invasive change
2. Skills are already correctly designed
3. Command specs already describe what should happen
4. Just need to add the explicit tool call
5. Skills provide value (context injection, validation, status management)

## Implementation Design

### Changes Required

1. **Update 12 command specifications** to add explicit skill tool invocation
2. **No changes needed to**: Skills, Agents, or system architecture
3. **Add skill tool call** after command validation steps

### Updated Command Flow

```
Command (/plan N)
  ├── Parse Input
  ├── Look up task
  ├── Validate status
  ├── Display header
  ├── Read research
  ├── INVOKE SKILL (skill-planner) ← NEW STEP
  │   └── Skill handles:
  │       ├── Load Context
  │       ├── Preflight
  │       ├── Task tool → planner-agent
  │       ├── Postflight
  │       └── Return results
  └── Report results
```

### Skill Tool Invocation Pattern

All workflow commands should use:
- Tool: skill
- Name: skill-{purpose}
- Prompt: Task context (task number, etc.)

## Affected Commands

| Command | Current | Fix |
|---------|---------|-----|
| /plan | Describes skill | Add skill tool call |
| /implement | Describes skill | Add skill tool call |
| /research | Describes skill | Add skill tool call |
| /revise | Describes skill | Add skill tool call |
| /meta | Describes skill | Add skill tool call |
| /learn | Describes skill | Add skill tool call |
| /refresh | Describes skill | Add skill tool call |
| /remember | Describes skill | Add skill tool call |
| /review | Describes skill | Add skill tool call |
| /status | Describes skill | Add skill tool call |
| /todo | Describes skill | Add skill tool call |
| /task | Describes skill | Add skill tool call |

## Verification Plan

After implementing Option A:
1. Test /plan on OC_139 (existing researched task)
2. Verify skill-planner executes its stages
3. Verify Task tool invokes planner-agent
4. Verify plan file is created
5. Test all other workflow commands

## Conclusion

**APPROACH SELECTED**: Option A - Add explicit skill tool calls to commands

This is the minimal, safest fix that:
- Leverages existing correct skill designs
- Requires only command spec updates
- Maintains all existing functionality
- Can be implemented incrementally (one command at a time)
