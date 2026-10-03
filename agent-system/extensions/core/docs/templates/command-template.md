---
description: <one-line description of what this command does>
allowed-tools: Skill, Agent, Bash(jq:*), Bash(git:*), Read, Edit
argument-hint: "<required-arg>" [--flag]
model: sonnet
---

# /<command-name> Command

<Brief description of what this command does and when to use it.>

**Use this command when you need to**: <specific use case>

## Arguments

- `$1` - Task number(s) (required). Supports single task, comma-separated lists, and ranges.
- Remaining args - Optional focus/prompt (applies to all tasks in multi-task mode)

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `--fast` | Low-effort mode | false |
| `--hard` | High-effort mode | false |

## Execution

### STAGE 0: PARSE TASK NUMBERS

```bash
source .claude/scripts/parse-command-args.sh "$ARGUMENTS"
# Exports: TASK_NUMBERS, REMAINING_ARGS,
#          EFFORT_FLAG, MODEL_FLAG, CLEAN_FLAG, FORCE_FLAG, FOCUS_PROMPT
```

If `len(TASK_NUMBERS) > 1`: dispatch to multi-task batch flow.
If `len(TASK_NUMBERS) == 1`: fall through to CHECKPOINT 1.

### CHECKPOINT 1: GATE IN

```bash
source .claude/scripts/command-gate-in.sh "$task_number" "<operation>"
# Exports: SESSION_ID, TASK_TYPE, TASK_STATUS, PROJECT_NAME, DESCRIPTION, PADDED_NUM
# Displays: [OPERATION] Task {N}: {project_name}
# Aborts if task not found or in terminal status
```

**On GATE IN success**: Task validated. **IMMEDIATELY CONTINUE** to STAGE 2.

### STAGE 2: DELEGATE

```bash
source .claude/scripts/command-route-agent.sh "<operation>" "$TASK_TYPE" "<default-agent>" "${effort_flag:-}"
agent_name="$AGENT_NAME"
```

**Invoke the Agent tool NOW** with:
```
Agent({
  subagent_type: "{agent_name}",
  prompt: "task_number={N} session_id={SESSION_ID} effort_flag={EFFORT_FLAG} model_flag={MODEL_FLAG} clean_flag={CLEAN_FLAG} orchestrator_mode=false"
})
```

**On DELEGATE success**: **IMMEDIATELY CONTINUE** to CHECKPOINT 2.

### CHECKPOINT 2: GATE OUT

```bash
bash .claude/scripts/command-gate-out.sh "$task_number" "<operation>" "$SESSION_ID"
# Reads .return-meta.json; applies defensive status correction if needed
# Runs validate-artifact.sh --fix (non-blocking)
```

**On GATE OUT success**: **IMMEDIATELY CONTINUE** to CHECKPOINT 3.

### CHECKPOINT 3: COMMIT

Apply the task-scoped staging pattern from `.claude/context/standards/git-staging-scope.md` —
under-stage, never over-stage, and never a repo-wide add:

```bash
padded_num=$(printf "%03d" "$task_number")
project_name=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .project_name' \
  specs/state.json)
bash .claude/scripts/git-commit-scoped.sh \
  --message "task {N}: <action>" \
  --session "{SESSION_ID}" \
  --honest-index-rows "{N}" \
  -- "specs/${padded_num}_${project_name}/" "specs/TODO.md" "specs/state.json"
```

Commit failure is non-blocking (log and continue).

## Output

```
<Operation> completed for Task #{N}

Artifact: specs/{NNN}_{SLUG}/<type>/MM_{short-slug}.md

Status: [<STATUS>]
Next: /<next-command> {N}
```

## Error Handling

- **GATE IN Failure**: Task not found or invalid status -- return error with guidance
- **DELEGATE Failure**: Keep in-progress status, log error; timeout preserves partial progress
- **GATE OUT Failure**: Missing artifacts -- log warning, continue with available

## Related Documentation

- [Creating Commands](../guides/creating-commands.md) - Step-by-step command creation
- [Command Lifecycle](../../context/workflows/command-lifecycle.md) - Checkpoint stage details
- [Return Format](../../context/formats/subagent-return.md) - Agent return-metadata schema
