# Research Report: Task #134

**Task**: OC_134 - Fix workflow command header not showing task number and name
**Date**: 2026-03-04
**Language**: meta
**Focus**: Root cause analysis of header display issue

## Summary

The root cause of the missing workflow command headers is a specification-to-implementation gap. All four workflow command specifications (research.md, implement.md, plan.md, revise.md) include Step 3 "Display task header" with a visual box showing task number and name, but this step is not implemented in the actual execution chain. The skills that execute these commands (skill-researcher, skill-implementer, skill-planner) do not include header display logic in their preflight stages, resulting in the headers never being shown to users.

## Findings

### Command Specifications Include Header Display Step

All four workflow command files include identical Step 3 instructions to display a task header:

**research.md** (lines 42-53):
```
### 3. Display task header

Print a visual header showing the active task:

```
╔══════════════════════════════════════════════════════════╗
║  Task OC_N: <project_name>                               ║
║  Action: RESEARCHING                                     ║
╚══════════════════════════════════════════════════════════╝
```

This header appears at the start of the research command to clearly indicate which task is being worked on.
```

**implement.md** (lines 43-54): Same pattern with "Action: IMPLEMENTING"
**plan.md** (lines 42-53): Same pattern with "Action: PLANNING"
**revise.md**: Delegates to planner-agent or task-expander

### Execution Chain Does Not Implement Header Display

The workflow execution flows through multiple layers, but none implement the header display:

**Layer 1: Command Files** (`.opencode/commands/*.md`)
- These are specification documents only
- They describe WHAT should happen but contain no executable code
- Step 3 is documented but not enforced

**Layer 2: Skills** (`.opencode/skills/skill-*/SKILL.md`)
- skill-researcher: 4 stages (LoadContext, Preflight, Delegate, Postflight)
- skill-implementer: 5 stages (LoadContext, Preflight, Delegate, Postflight, PostflightVerification)
- skill-planner: 4 stages (LoadContext, Preflight, Delegate, Postflight)
- None of these stages include header display logic

**Layer 3: Subagents** (`.opencode/agent/subagents/*.md`)
- general-research-agent: 7 stages (Initialize Early Metadata through Return Summary)
- general-implementation-agent: Not examined but follows similar pattern
- planner-agent: Not examined but focuses on plan creation
- These agents do the actual work but start after header should be shown

### Preflight Stage Is Ideal Location for Header Display

The skill execution stages show a clear pattern:

1. **LoadContext**: Read injected context files
2. **Preflight**: Validate task and prepare for delegation
3. **Delegate**: Invoke subagent with context
4. **Postflight**: Update state and link artifacts

The Preflight stage is the perfect location for header display because:
- Task validation is complete (task number and name are confirmed)
- Status is about to be updated to in-progress
- Delegation hasn't started yet (clean separation point)
- User needs immediate visual feedback that command is processing

### Existing Status Update Logic

Current Preflight stage in skills:
- Validates task exists in state.json
- Validates status allows the operation
- Updates status to in-progress (researching, implementing, planning)
- Creates postflight marker file
- Does NOT display header

The status update happens but without the visual header that should accompany it.

## Recommendations

### 1. Add Header Display to Skill Preflight Stages

Update all three workflow skills to display the header during Preflight:

**skill-researcher/SKILL.md**:
- Add to Preflight stage: Display header with "RESEARCHING" action
- Use task_number and project_name from state.json

**skill-implementer/SKILL.md**:
- Add to Preflight stage: Display header with "IMPLEMENTING" action
- Use task_number and project_name from state.json

**skill-planner/SKILL.md**:
- Add to Preflight stage: Display header with "PLANNING" action
- Use task_number and project_name from state.json

### 2. Standardize Header Format

Use consistent header format across all skills:

```
╔══════════════════════════════════════════════════════════╗
║  Task OC_N: <project_name>                               ║
║  Action: <ACTION>                                        ║
╚══════════════════════════════════════════════════════════╝
```

Where ACTION is one of: RESEARCHING, IMPLEMENTING, PLANNING, REVISING

### 3. Implement Using Plain Text Output

The header should be displayed using simple text output (echo/print) in the skill's preflight stage, not as part of the agent prompt. This ensures:
- Header appears immediately when command starts
- Header is not duplicated in agent responses
- User sees clear indication of which task is being processed

### 4. Update Command Specifications to Match

The command specifications should be updated to clarify that:
- Step 3 (Display task header) is implemented by the skill, not the subagent
- The skill displays the header during Preflight stage
- This provides consistent UX across all workflow commands

## Risks & Considerations

- **Consistency**: Must ensure all three skills implement header display identically
- **Timing**: Header should display after validation but before status update
- **Format**: Use exact box-drawing characters from command specifications
- **Testing**: Verify headers appear correctly for all workflow commands

## Next Steps

Run `/plan OC_134` to create an implementation plan for adding header display logic to skill-researcher, skill-implementer, and skill-planner preflight stages.
