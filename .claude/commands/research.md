---
description: Research a task and create reports
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Read, Edit
argument-hint: TASK_NUMBER [FOCUS] [--team [--team-size N]]
model: opus
---

# /research Command

Conduct research for a task by delegating to the appropriate research skill/subagent.

## Arguments

- `$1` - Task number (required)
- Remaining args - Optional focus/prompt for research direction

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `--team` | Enable multi-agent parallel research with multiple teammates | false |
| `--team-size N` | Number of teammates to spawn (2-4) | 2 |

When `--team` is specified, research is delegated to `skill-team-research` which spawns multiple research agents working in parallel on different aspects of the task. Each teammate produces a research report, and the lead synthesizes findings into a final comprehensive report.

**Note**: Team mode requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` environment variable. If unavailable, gracefully degrades to single-agent research.

## Execution

**Note**: Delegate to skills for language-specific research.

### CHECKPOINT 1: GATE IN

**Display header**:
```
[Researching] Task {N}: {project_name}
```

1. **Generate Session ID**
   ```
   session_id = sess_{timestamp}_{random}
   ```

2. **Lookup Task**
   ```bash
   task_data=$(jq -r --arg num "$task_number" \
     '.active_projects[] | select(.project_number == ($num | tonumber))' \
     specs/state.json)

   # Extract language and task_type for routing
   language=$(echo "$task_data" | jq -r '.language // "general"')
   task_type=$(echo "$task_data" | jq -r '.task_type // null')
   ```

3. **Validate**
   - Task exists (ABORT if not)
   - Status allows research: not_started, planned, partial, blocked, researched
   - If completed/abandoned: ABORT with recommendation

**ABORT** if any validation fails.

**On GATE IN success**: Task validated. **IMMEDIATELY CONTINUE** to STAGE 1.5 below.

### STAGE 1.5: PARSE FLAGS

**Parse arguments to determine team mode and focus prompt.**

1. **Extract Team Options**
   Check remaining args (after task number) for team flags:
   - `--team` -> `team_mode = true`
   - `--team-size N` -> `team_size = N` (clamp 2-4)

   If no team flag found: `team_mode = false`, `team_size = 2`

2. **Validate Team Size**
   ```bash
   # Clamp team_size to valid range
   team_size=${team_size:-2}
   [ "$team_size" -lt 2 ] && team_size=2
   [ "$team_size" -gt 4 ] && team_size=4
   ```

3. **Extract Focus Prompt**
   Remove all recognized flags from remaining args:
   - Remove `--team`
   - Remove `--team-size N` (flag and its value)

   Remaining text is `focus_prompt`.

**On STAGE 1.5 success**: Flags parsed. **IMMEDIATELY CONTINUE** to STAGE 2 below.

### STAGE 2: DELEGATE

**EXECUTE NOW**: After STAGE 1.5 completes, immediately invoke the Skill tool.

**Team Mode Routing** (when `--team` flag present):

If `team_mode == true`:
- Route to `skill-team-research` regardless of language
- Pass `team_size` parameter

**Language-Based Routing** (when `--team` flag NOT present):

| Language | Skill to Invoke |
|----------|-----------------|
| `general`, `meta`, `markdown` | `skill-researcher` |

**Extension Languages**: When extensions are loaded (via `<leader>ac` in Neovim), additional language-specific skills become available. Extension skills follow the pattern `skill-{lang}-research` and are discovered automatically. See `.claude/extensions/*/manifest.json` for available extensions.

**Note**: Extension skills are located in `.claude/extensions/{ext}/skills/`. Claude Code should automatically discover these skills when extensions are installed.

**Type-Based Routing for Extensions**: Some extensions support finer-grained routing via `task_type` field. When a task has both `language` (extension) and `task_type` set, use the composite key `{language}:{task_type}` for routing lookup.

Example for founder extension:
| language | task_type | Routing Key | Skill |
|----------|-----------|-------------|-------|
| founder | market | founder:market | skill-market |
| founder | analyze | founder:analyze | skill-analyze |
| founder | strategy | founder:strategy | skill-strategy |
| founder | (null) | founder | skill-market (default) |

**Skill Selection Logic**:
```
if team_mode:
  skill_name = "skill-team-research"
else:
  # Check for task_type-based routing (extensions with sub-types)
  task_type = task_data.task_type  # may be null

  if task_type is not null:
    # Try composite key first: "{language}:{task_type}"
    composite_key = "{language}:{task_type}"
    if composite_key in extension_routing:
      skill_name = extension_routing[composite_key]
    else:
      # Fallback to language-only routing
      skill_name = {language-based routing}
  else:
    skill_name = {language-based routing from table above}
```

**Invoke the Skill tool NOW** with:
```
# For team mode:
skill: "skill-team-research"
args: "task_number={N} focus={focus_prompt} team_size={team_size} session_id={session_id}"

# For single-agent mode:
skill: "{skill-name from table above}"
args: "task_number={N} focus={focus_prompt} session_id={session_id}"
```

The skill will spawn the appropriate agent(s) to conduct research and create a report.

**On DELEGATE success**: Research complete. **IMMEDIATELY CONTINUE** to CHECKPOINT 2 below.

### CHECKPOINT 2: GATE OUT

1. **Validate Return**
   Required fields: status, summary, artifacts

2. **Verify Artifacts**
   Check each artifact path exists on disk

3. **Verify Status Updated**
   The skill handles status updates internally (preflight and postflight).
   Confirm status is now "researched" in state.json.

**RETRY** skill if validation fails.

**On GATE OUT success**: Artifacts verified. **IMMEDIATELY CONTINUE** to CHECKPOINT 3 below.

### CHECKPOINT 3: COMMIT

```bash
git add -A
git commit -m "$(cat <<'EOF'
task {N}: complete research

Session: {session_id}

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

Commit failure is non-blocking (log and continue).

## Output

```
Research completed for Task #{N}

Report: specs/{NNN}_{SLUG}/reports/MM_{short-slug}.md

Status: [RESEARCHED]
Next: /plan {N}
```

## Error Handling

### GATE IN Failure
- Task not found: Return error with guidance
- Invalid status: Return error with current status

### DELEGATE Failure
- Skill fails: Keep [RESEARCHING], log error
- Timeout: Partial research preserved, user can re-run

### GATE OUT Failure
- Missing artifacts: Log warning, continue with available
- Link failure: Non-blocking warning
