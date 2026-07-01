# Creating Commands Guide

This guide walks through creating a new slash command in the Claude Code agent system. Commands are the user-facing entry points; they route work to skills, which delegate to agents.

## Prerequisites

Before creating a command, understand:

1. **Checkpoint-based execution**: Every command follows GATE IN -> DELEGATE -> GATE OUT -> COMMIT
2. **Task-number arguments**: Most commands operate on task numbers from `specs/TODO.md`, not free-form topics
3. **Skill delegation**: Commands invoke skills via the Skill tool; skills spawn agents via the Agent tool
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
| `model` | No | Preferred model (`opus`, `sonnet`, or omit for default). See Model Selection below |

### Model Selection

Commands that dispatch to agents should use `model: sonnet` in their frontmatter. The agent's own frontmatter model takes precedence during execution, so the command-level model primarily affects the command's own preflight/postflight reasoning.

| Command Type | Recommended Model | Rationale |
|-------------|-------------------|-----------|
| Dispatch commands (`/research`, `/plan`, `/implement`) | `sonnet` | Lightweight routing; agent model takes precedence |
| Direct-execution commands (`/todo`, `/meta`, `/review`) | `opus` | Command itself does the reasoning work |
| Utility commands (`/refresh`, `/tag`) | `opus` or omit | Simple operations; model matters less |

See `.claude/docs/reference/standards/agent-frontmatter-standard.md` for the full tiered model policy.

### Step 4: Implement the Four Checkpoint Stages

Commands use shared infrastructure scripts in `.claude/scripts/` for checkpoint execution. These scripts handle session generation, task validation, status updates, and artifact verification — commands should not reimplement this logic inline.

#### STAGE 0: PARSE TASK NUMBERS

```bash
source .claude/scripts/parse-command-args.sh "$ARGUMENTS"
# Exports: TASK_NUMBERS, REMAINING_ARGS, TEAM_MODE, TEAM_SIZE,
#          EFFORT_FLAG, MODEL_FLAG, CLEAN_FLAG, FORCE_FLAG, FOCUS_PROMPT
```

`parse-command-args.sh` extracts task numbers (single, comma-separated, or ranges), flags (`--team`, `--fast`, `--hard`, `--clean`, `--force`), model selectors (`--haiku`, `--sonnet`, `--opus`), and remaining text as `FOCUS_PROMPT`.

#### CHECKPOINT 1: GATE IN (Preflight)

```bash
source .claude/scripts/command-gate-in.sh "$task_number" "<operation>"
# Exports: SESSION_ID, TASK_TYPE, TASK_STATUS, PROJECT_NAME, DESCRIPTION, PADDED_NUM
# Displays: [OPERATION] Task {N}: {project_name}
# Aborts if task not found or in terminal status
```

`command-gate-in.sh` generates the session ID, validates the task exists, checks status allows the operation, and updates status to the in-progress variant. Commands should not generate session IDs or validate tasks manually.

#### STAGE 2: DELEGATE

```bash
source .claude/scripts/command-route-skill.sh "<operation>" "$TASK_TYPE" "skill-<default>"
skill_name="$SKILL_NAME"
```

`command-route-skill.sh` resolves the task type to the appropriate skill name using extension manifests and fallback defaults. Then invoke the skill:

```
Skill: "{skill_name}"
Args: "task_number={N} session_id={SESSION_ID} ..."
```

#### CHECKPOINT 2: GATE OUT (Postflight)

```bash
bash .claude/scripts/command-gate-out.sh "$task_number" "<operation>" "$SESSION_ID"
# Reads .return-meta.json; applies defensive status correction if needed
# Runs validate-artifact.sh --fix (non-blocking)
```

`command-gate-out.sh` reads the return metadata file, validates artifacts exist, and applies defensive status corrections to both state.json and TODO.md if needed.

#### CHECKPOINT 3: COMMIT

```bash
git add -A
git commit -m "$(cat <<'EOF'
task {N}: {action}

Session: {SESSION_ID}

EOF
)"
```

Commit failure is non-blocking (log and continue).

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
