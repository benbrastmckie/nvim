# Creating Commands Guide

This guide walks through creating a new slash command in the Claude Code agent system. Commands are the user-facing entry points; they route work to skills, which delegate to agents.

## Prerequisites

Before creating a command, understand:

1. **Checkpoint-based execution**: Every command follows GATE IN -> DELEGATE -> GATE OUT -> COMMIT
2. **Task-number arguments**: Most commands operate on task numbers from `specs/TODO.md`, not free-form topics
3. **Skill delegation**: Commands invoke skills via the Skill tool; skills spawn agents via the Task tool
4. **Separation of concerns**: Commands parse arguments and validate; skills prepare context; agents execute

**Required reading**:
- [Command Template](../templates/command-template.md)
- [Component Selection](component-selection.md)
- [Creating Skills](creating-skills.md)
- [Creating Agents](creating-agents.md)
- `.claude/context/workflows/command-lifecycle.md`

## When to Create a Command

Create a new command when:
- There is a user-facing operation that warrants a dedicated entry point
- The operation is distinct from existing commands in terms of workflow or artifacts
- The operation needs argument parsing and preflight validation

Do NOT create a command when:
- An existing command can handle the use case with an additional flag
- The work is internal to a skill or agent
- The operation is a one-off script that can live in `.claude/scripts/`

## Step-by-Step Process

### Step 1: Choose a Name and Check for Conflicts

Commands are invoked as `/<name>`. Pick a short, verb-oriented name. Check `.claude/commands/` for existing conflicts.

### Step 2: Start from the Command Template

Copy `.claude/docs/templates/command-template.md` to `.claude/commands/<name>.md` and replace the placeholders.

### Step 3: Define Frontmatter

All commands use this frontmatter format:

```yaml
---
description: <one-line description>
allowed-tools: <comma-separated tool list>
argument-hint: "<required>" [--flag]
model: opus
---
```

| Field | Required | Purpose |
|-------|----------|---------|
| `description` | Yes | One-line summary shown in `/help` output |
| `allowed-tools` | Yes | Scoped tool allowlist (e.g., `Read(specs/*), Bash(git:*)`) |
| `argument-hint` | Yes | Usage hint shown to the user |
| `model` | No | Preferred model (`opus`, `sonnet`, or omit for default) |

### Step 4: Implement the Four Checkpoint Stages

#### GATE IN (Preflight)

```markdown
## GATE IN

1. Parse $ARGUMENTS to extract task_number(s) and flags
2. Validate task exists in state.json and TODO.md
3. Check status allows this operation
4. Generate session_id: `sess_{timestamp}_{random}`
5. Invoke skill-status-sync to move status to in-progress variant
```

#### DELEGATE

```markdown
## DELEGATE

Invoke the appropriate skill via the Skill tool:

Skill: skill-<name>
Arguments: {
  "task_number": <N>,
  "session_id": "<session_id>",
  "task_context": { ... }
}
```

The skill invokes the agent via the Task tool and receives a return-metadata file path.

#### GATE OUT (Postflight)

```markdown
## GATE OUT

1. Read return-metadata file from `specs/{NNN}_{SLUG}/.return-meta.json`
2. Validate artifacts exist on disk
3. Invoke skill-status-sync to move status to completed variant
```

#### COMMIT

```markdown
## COMMIT

Invoke skill-git-workflow to create the commit:
  - Message: `task {N}: {action}`
  - Body: `Session: {session_id}`
```

### Step 5: Document Artifacts

List every artifact the command creates, using absolute paths with placeholders:

```markdown
## Artifacts

- `specs/{NNN}_{SLUG}/reports/MM_{short-slug}.md` - Research report
- `specs/{NNN}_{SLUG}/plans/MM_{short-slug}.md` - Implementation plan
```

See `.claude/rules/artifact-formats.md` for naming conventions.

### Step 6: Add Error Handling

Document the recovery paths:

```markdown
## Error Handling

- **Task not found**: Exit with error, preserve no state
- **Delegation failure**: Keep task in current status, log to errors.json
- **Timeout**: Mark phase [PARTIAL] in plan, next invocation resumes
```

See `.claude/rules/error-handling.md` for the general patterns.

### Step 7: Register the Command

1. Add the command to the command reference table in `.claude/README.md`
2. Add the command to the command reference table in `.claude/CLAUDE.md`
3. If the command introduces a new skill or agent, update the skill-to-agent mapping in `.claude/context/reference/skill-agent-mapping.md`

### Step 8: Test

Test the command with:
- Valid task number and arguments
- Invalid task number (should error cleanly)
- Timeout simulation (Ctrl-C mid-execution)
- Resume from partial state

## Command File Size Targets

- **Target**: under 250 lines
- **Maximum**: 300 lines
- **Rationale**: Commands should delegate, not execute. Long commands indicate that logic should move into a skill or agent.

## Example Commands to Study

| Command | Why read it |
|---------|-------------|
| `.claude/commands/task.md` | Simple argument-mode dispatch |
| `.claude/commands/research.md` | Multi-task routing and skill delegation |
| `.claude/commands/implement.md` | Resume support and phase-level progress |
| `.claude/commands/todo.md` | Direct skill execution (no agent delegation) |

## Related Documentation

- [Command Template](../templates/command-template.md)
- [Creating Skills](creating-skills.md)
- [Creating Agents](creating-agents.md)
- [Component Selection](component-selection.md)
- `.claude/context/workflows/command-lifecycle.md`
- `.claude/rules/artifact-formats.md`
- `.claude/rules/state-management.md`
