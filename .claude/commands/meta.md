---
description: Interactive system builder that creates TASKS for agent architecture changes (never implements directly)
allowed-tools: Skill
argument-hint: [PROMPT] | --analyze
model: opus
---

# /meta Command

Interactive system builder that delegates to `skill-meta` for creating TASKS for .claude/ system changes. This command NEVER implements changes directly - it only creates tasks.

**Reference Implementation**: This command is the reference implementation for the multi-task creation standard. See `.claude/docs/reference/standards/multi-task-creation-standard.md` for the complete standard specification.

## Arguments

- No args: Start interactive interview (7 stages)
- `PROMPT` - Direct analysis of change request (abbreviated flow)
- `--analyze` - Analyze existing .claude/ structure (read-only)

## Constraints

**FORBIDDEN** - This command MUST NOT:
- Directly create commands, skills, rules, or context files
- Directly modify CLAUDE.md or README.md
- Implement any work without user confirmation
- Write any files outside specs/

**REQUIRED** - This command MUST:
- Track all work via tasks in TODO.md + state.json
- Require explicit user confirmation before creating any tasks
- Create task directories for each task
- Delegate execution to skill-meta

## Execution

### 1. Mode Detection

Determine mode from arguments:

```
if $ARGUMENTS is empty:
    mode = "interactive"
elif $ARGUMENTS == "--analyze":
    mode = "analyze"
else:
    mode = "prompt"
    prompt = $ARGUMENTS
```

### 2. Delegate to Skill

Invoke skill-meta via Skill tool with:
- Mode (interactive, prompt, or analyze)
- Prompt (if provided)

The skill will:
1. Validate inputs
2. Prepare delegation context
3. Invoke meta-builder-agent
4. Return standardized JSON result

### 3. Present Results

Based on agent return:
- **Interactive/Prompt modes**: Display created tasks and next steps
- **Analyze mode**: Display component inventory and recommendations
- **Cancelled**: Acknowledge user cancellation

## Modes Summary

### Interactive Mode (no arguments)

Full 7-stage interview:
1. DetectExistingSystem - Inventory current components
2. InitiateInterview - Explain process
3. GatherDomainInfo - Purpose and scope questions
4. IdentifyUseCases - Task breakdown
5. AssessComplexity - Effort and priority
6. ReviewAndConfirm - Mandatory confirmation
7. CreateTasks - Update TODO.md and state.json

Uses AskUserQuestion for multi-turn conversation.

### Prompt Mode (with text argument)

Abbreviated flow:
1. Parse prompt for keywords and intent
2. Check for related existing tasks
3. Propose task breakdown
4. Confirm with user
5. Create tasks

Example: `/meta "add a new command for exporting logs"`

### Analyze Mode (--analyze)

Read-only system analysis:
- Inventory all commands, skills, agents, rules
- Count active tasks
- Provide recommendations
- No tasks created

Example: `/meta --analyze`

## Output

### Tasks Created

```
Tasks Created

Created {N} task(s) for {domain}:

High Priority:
- Task #{N}: {title}
  Path: specs/{NNN}_{slug}/

Next Steps:
1. Review tasks in TODO.md
2. Run /research {N} to begin research on first task
3. Progress through /research -> /plan -> /implement cycle
```

### Analysis Output

```
## Current .claude/ Structure

**Commands ({N})**:
- /{command} - {description}

**Skills ({N})**:
- {skill} - {description}

**Agents ({N})**:
- {agent}

**Active Tasks ({N})**:
- #{N}: {title} [{status}]

**Recommendations**:
1. {suggestion}
```

### User Cancelled

```
Task creation cancelled. No tasks were created.
Run /meta again when ready.
```

## Reference Templates

These templates are provided for reference when creating tasks. Actual file creation happens during `/implement`, not `/meta`.

### Command Template Reference

```markdown
---
description: {description}
allowed-tools: {tools}
argument-hint: {hint}
model: opus
---

# /{command} Command

{documentation}
```

### Skill Template Reference

```markdown
---
name: {skill-name}
description: {when to invoke}
allowed-tools: Task
context: fork
agent: {agent-name}
---

# {Skill Name}

## Trigger Conditions
## Execution
## Return Format
```

### Agent Template Reference

See `.claude/docs/guides/creating-agents.md` for full 8-stage workflow template.

## Standards Reference

This command implements all 8 components of the multi-task creation standard.

**Compliance Level**: Full (reference implementation)

| Component | Status | Implementation |
|-----------|--------|----------------|
| Discovery | Yes | Interview Stage 2-3 |
| Selection | Yes | Interview Stage 5 (ReviewAndConfirm) |
| Grouping | Yes | User-defined in Stage 3 |
| Dependencies | Full | Stage 3 Question 5 (internal + external) |
| Ordering | Yes | Stage 6 (Kahn's algorithm) |
| Visualization | Yes | Stage 7 (linear chain / layered DAG) |
| Confirmation | Yes | Stage 5 (mandatory) |
| State Updates | Yes | Stage 6 (batch insertion) |

See `meta-builder-agent.md` for complete implementation details.
