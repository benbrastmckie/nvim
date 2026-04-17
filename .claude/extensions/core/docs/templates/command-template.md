---
description: <one-line description of what this command does>
allowed-tools: Read, Edit, Write, Bash(git:*), Bash(jq:*), AskUserQuestion
argument-hint: "<required-arg>" [--flag]
model: opus
---

# /<command-name> Command

<Brief description of what this command does and when to use it.>

**Use this command when you need to**: <specific use case>

## Arguments

- `<required-arg>`: <description>
- `[--flag]`: <description> (optional)

## Examples

```
/<command-name> "example value"
/<command-name> "example value" --flag
```

## Checkpoint-Based Execution

All commands follow the four-stage checkpoint pattern:

### 1. GATE IN (Preflight)

- Parse arguments from $ARGUMENTS
- Validate task exists and status allows the operation
- Generate session ID: `sess_{timestamp}_{random}`
- Update task status to in-progress variant via `skill-status-sync`
- Load decision context from state.json

### 2. DELEGATE

Invoke the appropriate skill via the Skill tool:

```
Skill: skill-<name>
Arguments: {
  "task_number": <N>,
  "session_id": "sess_...",
  "task_context": { ... }
}
```

The skill prepares delegation context and spawns a subagent through the Task tool. The agent does the real work (research, planning, implementation, etc.) and writes artifacts and a return-metadata file.

### 3. GATE OUT (Postflight)

- Read the return-metadata file written by the agent
- Validate artifacts exist on disk
- Update task status to completed variant via `skill-status-sync`
- Invoke `skill-git-workflow` for the commit

### 4. COMMIT

The git-workflow skill creates a scoped commit following the `task {N}: {action}` convention with the session ID in the commit body.

## Artifacts

<List artifact paths this command creates, using the `specs/{NNN}_{SLUG}/...` convention.>

- `specs/{NNN}_{SLUG}/reports/MM_{short-slug}.md` - research report
- `specs/{NNN}_{SLUG}/plans/MM_{short-slug}.md` - implementation plan
- `specs/{NNN}_{SLUG}/summaries/MM_{short-slug}-summary.md` - execution summary

## Error Handling

On failure:
- Keep task in current status (do not regress)
- Log error to `specs/errors.json` with session_id
- Return partial metadata with `status: "partial"` if progress was made
- The next invocation can resume from the partial progress marker

## Related Documentation

- [Creating Commands](../guides/creating-commands.md) - Step-by-step command creation
- [Command Lifecycle](../../context/workflows/command-lifecycle.md) - Checkpoint stage details
- [Return Format](../../context/formats/subagent-return.md) - Agent return-metadata schema
