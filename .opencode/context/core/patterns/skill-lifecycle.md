# Self-Contained Skill Lifecycle Pattern

## Overview

Skills should be self-contained workflows that own their complete lifecycle:
- **Preflight**: Update task status before starting work
- **Delegate**: Invoke agent to perform actual work
- **Postflight**: Update task status after completion
- **Return**: Return standardized JSON result

This pattern eliminates the need for multiple skill invocations per workflow command, reducing halt risk.

## Architecture (Current Standard)

```
/research N
├── VALIDATE: Inline task lookup
├── DELEGATE: Skill(skill-researcher)
│   ├── 0. Preflight: Inline status update
│   ├── 1-4. Agent delegation and work
│   ├── 5. Postflight: Inline status update
│   └── Return: JSON with artifacts
└── COMMIT: Bash
```

**Benefits**: Single skill invocation reduces halt boundaries from 3-4 to 1 per command.

### Legacy Pattern (Deprecated)

The previous 3-skill pattern is deprecated and should not be used in new implementations:
```
/research N
├── GATE IN: Skill(skill-status-sync)    ← HALT RISK
├── DELEGATE: Skill(skill-researcher)     ← HALT RISK
├── GATE OUT: Skill(skill-status-sync)   ← HALT RISK
└── COMMIT: Bash
```

## Skill Structure

### Frontmatter Requirements

Skills that manage lifecycle need these tools.

**Workflow Skills** (delegate to subagent with inline status updates):
```yaml
---
name: skill-{name}
description: {description}
allowed-tools: Task, Bash, Edit, Read
---
```

**Direct Execution Skills** (inline execution, no subagent):
```yaml
---
name: skill-{name}
description: {description}
allowed-tools: Bash, Edit, Read
---
```

Note: skill-status-sync is for standalone use only. Workflow skills now handle their own status updates.

### Section Organization

```markdown
## Execution

### 0. Preflight Status Update

Update task status before starting work.
See: @.opencode/context/core/patterns/inline-status-update.md

### 1. Input Validation
### 2. Context Preparation
### 3. Invoke Subagent
### 4. Return Validation

### 5. Postflight Status Update

Update task status after successful completion.
See: @.opencode/context/core/patterns/inline-status-update.md

### 6. Return Propagation
```

## Status Transitions by Workflow Type

| Workflow | Preflight Status | Postflight Status | Artifact Type |
|----------|------------------|-------------------|---------------|
| Research | researching | researched | research |
| Planning | planning | planned | plan |
| Implementation | implementing | completed/implementing | summary |

## Error Handling

### Preflight Errors
- If preflight fails, abort immediately
- Do not invoke agent
- Return error to caller

### Agent Errors
- If agent returns error/partial, do NOT run postflight
- Keep status in preflight state (e.g., "researching")
- Return agent error to caller

### Postflight Errors
- Log error but don't fail the workflow
- Artifacts were created, status can be fixed manually
- Return success with warning

## Benefits

1. **Single Skill Invocation**: Reduces halt risk from 3 to 1
2. **Clear Ownership**: Skill owns entire workflow lifecycle
3. **Simplified Commands**: Commands become thin routers
4. **Consistent State**: Preflight and postflight always run together

## Exclusion Criteria

Not all skills need inline status updates. Skills that match these patterns are excluded:

| Pattern | Description | Example Skills |
|---------|-------------|----------------|
| **Utility** | Provides utility function, no task state management | skill-git-workflow, skill-document-converter |
| **Task Creation** | Creates new tasks, does not transition existing tasks | skill-meta |
| **Routing** | Routes only, delegates state management to invoked skill | skill-orchestrator |
| **Terminal State** | Operates only on completed/abandoned tasks | (archive operations) |
| **Non-Task** | Operates on different data like errors or reviews | (error/review skills) |
| **Mechanism** | IS the status update mechanism itself | skill-status-sync |

### Workflow Skills (Require Inline Status Updates)

These skills manage task lifecycle transitions:
- skill-researcher (not_started/researched -> researching -> researched)
- skill-planner (researched -> planning -> planned)
- skill-implementer (planned -> implementing -> completed)
- skill-lean-research (same as researcher)
- skill-lean-implementation (same as implementer)
- skill-latex-implementation (same as implementer)

### Non-Workflow Skills (Excluded from Pattern)

These skills are intentionally excluded:
- skill-status-sync: IS the mechanism, used for standalone operations
- skill-git-workflow: Creates commits, no task state
- skill-orchestrator: Routes to workflow skills which handle state
- skill-meta: Creates tasks via interview, no transitions
- skill-document-converter: Standalone file conversion utility

## References

- Inline patterns: `@.opencode/context/core/patterns/inline-status-update.md`
- Anti-stop patterns: `@.opencode/context/core/patterns/anti-stop-patterns.md`
- Subagent return format: `@.opencode/context/core/formats/subagent-return.md`
