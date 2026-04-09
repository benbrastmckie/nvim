# Research Report: Task #380

**Task**: 380 - Create skill-meeting and meeting.md command
**Started**: 2026-04-08T00:00:00Z
**Completed**: 2026-04-08T00:00:00Z
**Effort**: 1-2 hours
**Dependencies**: meeting-agent.md (exists)
**Sources/Inputs**: skill-legal/SKILL.md, legal.md, finance.md, meeting-agent.md
**Artifacts**: specs/380_meeting_skill_command/reports/01_skill-command-research.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- skill-meeting follows the exact same 11-stage SKILL.md pattern as skill-legal, but with simpler input (no forcing_data, no mode selection)
- meeting.md command is significantly simpler than legal.md: no STAGE 0 forcing questions, no legacy --quick mode, just file path routing with optional --update flag
- The meeting-agent is autonomous (file-processing), so the command's job is input detection, task creation, and delegation -- not interactive questioning

## Context & Scope

Research the exact file structures needed for `skill-meeting/SKILL.md` and `commands/meeting.md` by analyzing existing patterns in the founder extension (skill-legal, legal.md, finance.md) and the already-written meeting-agent.md.

## Findings

### 1. Skill Structure Analysis (SKILL.md)

The skill-legal SKILL.md follows an 11-stage execution flow that skill-meeting must replicate:

**Frontmatter**:
```yaml
---
name: skill-meeting
description: Investor meeting note processing with task integration
allowed-tools: Task, Bash, Edit, Read, Write
---
```

**Sections in order**:
1. Title + description paragraph (thin wrapper explanation)
2. IMPORTANT note about skill-internal postflight pattern
3. Context Pointers (lazy-load references)
4. Trigger Conditions (direct + implicit invocation patterns)
5. Execution Flow (11 stages)

**11 Stages**:

| Stage | Purpose | Key Differences from skill-legal |
|-------|---------|----------------------------------|
| 1. Input Validation | Validate task_number exists | No contract_type, primary_concern, mode fields. Instead: `notes_path` (required), `update_only` (optional boolean) |
| 2. Preflight Status Update | Set status to "researching" | Identical pattern |
| 3. Create Postflight Marker | Write .postflight-pending | Identical pattern |
| 4. Prepare Delegation Context | Build JSON for agent | Different fields: `notes_path`, `update_only` instead of `contract_type`, `primary_concern`, `mode`, `forcing_data` |
| 5. Invoke Agent | Task tool to meeting-agent | `subagent_type: "meeting-agent"`, description: "Meeting note processing with web research" |
| 6. Parse Subagent Return | Read .return-meta.json | Identical pattern |
| 7. Update Task Status | Set "researched" | Identical pattern |
| 8. Link Artifacts | Add artifact to state.json | Identical pattern |
| 9. Git Commit | Commit changes | Identical pattern, message: "task {N}: complete research" |
| 10. Cleanup | Remove marker files | Identical pattern |
| 11. Return Brief Summary | Text summary | Different fields: investor_name, meeting_date, action_items, csv status |

**Delegation Context for skill-meeting** (Stage 4):
```json
{
  "task_context": {
    "task_number": N,
    "project_name": "{project_name}",
    "description": "{description}",
    "language": "founder",
    "task_type": "meeting"
  },
  "notes_path": "{absolute path to meeting notes file}",
  "update_only": false,
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json",
  "metadata": {
    "session_id": "sess_{timestamp}_{random}",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "meeting", "skill-meeting"]
  }
}
```

Key difference from skill-legal: No `forcing_data` block. The meeting-agent is autonomous and does not use forcing questions. Instead it takes `notes_path` and `update_only`.

**Trigger Conditions for skill-meeting**:

Direct:
- User runs `/meeting` command with task number
- User runs `/research` on a founder task with `task_type: "meeting"`

Implicit (plan step language patterns):
- "Process meeting notes"
- "Create investor profile"
- "Update investor CSV"
- "Meeting file processing"

When NOT to trigger:
- Contract review (use skill-legal)
- Financial analysis (use skill-finance)
- Market research (use skill-market)

**Return Summary Template**:
```
Meeting note processing completed for task {N}:
- Investor: {investor_name}
- Meeting date: {meeting_date}
- Meeting file: specs/{NNN}_{SLUG}/reports/01_{short-slug}.md
- Action items: {count}
- CSV tracker: {updated|created}
- Web research: {source_count} sources
- Status updated to [RESEARCHED]
- Changes committed
- Next: Review meeting file for accuracy
```

### 2. Command Structure Analysis (meeting.md)

**Frontmatter**:
```yaml
---
description: Investor meeting note processing with task integration
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Read, Edit, AskUserQuestion
argument-hint: /path/to/notes.md | TASK_NUMBER | --update /path/to/meeting-file.md
---
```

**Critical difference from /legal**: The /meeting command has NO STAGE 0 forcing questions. The meeting-agent is autonomous -- it reads a file and processes it. The command's job is:
1. Detect input type (file path, task number, --update flag)
2. Create task if needed
3. Delegate to skill-meeting

**Input Types** (3 types, compared to /legal's 4):

| Input | Behavior |
|-------|----------|
| File path (`/path/to/notes.md`) | Create task, delegate with notes_path, full processing |
| Task number (`382`) | Load existing task, delegate to skill-meeting |
| `--update /path/to/file.md` | Create task (or use existing), delegate with update_only=true |

Note: No description-only input type (unlike /legal). Meeting always requires a file. No --quick legacy mode.

**Input Type Detection Logic**:
```bash
# Check for --update flag
if echo "$ARGUMENTS" | grep -qE '^--update'; then
  input_type="update"
  file_path=$(echo "$ARGUMENTS" | sed 's/^--update *//')

# Check for task number
elif echo "$ARGUMENTS" | grep -qE '^[0-9]+$'; then
  input_type="task_number"
  task_number="$ARGUMENTS"

# Default: treat as file path
else
  input_type="file_path"
  file_path="$ARGUMENTS"
fi
```

**STAGE 0**: Not applicable. Skip entirely. No forcing questions.

**CHECKPOINT 1: GATE IN**:

Display header:
```
[Meeting] Investor Meeting Note Processor
```

Steps:
1. Generate session_id
2. Detect input type (see above)
3. Handle input type:
   - **file_path**: Verify file exists, read filename for description, extract investor name if possible, create task with `task_type: "meeting"`, then delegate
   - **task_number**: Load existing task, validate language=founder, delegate
   - **update**: Verify file exists, verify file has YAML frontmatter (starts with `---`), create task or use existing, delegate with `update_only: true`
4. Create task (if needed) -- simpler than /legal because no forcing_data to store
5. Update TODO.md (if new task)
6. Git commit task creation
7. **Do NOT stop after task creation** -- unlike /legal, proceed directly to STAGE 2 delegation

**Key behavioral difference from /legal**: The /legal command STOPS after task creation (user must run `/research N` separately). The /meeting command should proceed directly to delegation because there are no forcing questions to gather -- the file IS the input. The command creates the task and immediately delegates.

**Task Creation Fields** (state.json):
```json
{
  "project_number": N,
  "project_name": "meeting_{investor_slug}",
  "status": "not_started",
  "language": "founder",
  "task_type": "meeting",
  "description": "Investor meeting: {investor_name_from_filename}",
  "created": "{ISO timestamp}",
  "artifacts": []
}
```

Note: No `forcing_data` field (unlike /legal tasks).

**TODO.md Entry** (simpler than /legal):
```markdown
### {task_number}. Investor meeting: {description}
- **Effort**: 1-2 hours
- **Status**: [NOT STARTED]
- **Language**: founder
- **Type**: meeting
- **Dependencies**: None
- **Started**: {ISO timestamp}

**Description**: Process meeting notes from {filename}
```

**STAGE 2: DELEGATE**:

Invoke skill-meeting:
```
skill: "skill-meeting"
args: "task_number={task_number} notes_path={file_path} update_only={true|false} session_id={session_id}"
```

**CHECKPOINT 2: GATE OUT**:

1. Verify status is "researched"
2. Get research artifact path
3. Display result:
```
Meeting notes processed for Task #{N}

Meeting File: {meeting_file_path}
CSV Tracker: {updated|created}

Investor: {investor_name}
Meeting Date: {date}
Action Items: {count}

Status: [RESEARCHED]

Next Steps:
- Review meeting file for accuracy and completeness
- Verify investor data from web research
- Run /plan {N} if further analysis needed
```

### 3. Key Differences from /legal Pattern

| Aspect | /legal | /meeting |
|--------|--------|----------|
| STAGE 0 | 4 forcing questions + mode selection | None -- autonomous processing |
| Input types | 4 (description, task#, file, --quick) | 3 (file path, task#, --update file) |
| Legacy mode | --quick (standalone, no task) | None |
| After task creation | STOPS -- user runs /research N | CONTINUES directly to delegation |
| forcing_data | Stored in state.json task entry | Not applicable |
| Mode selection | REVIEW/NEGOTIATE/TERMS/DILIGENCE | None (or implicit: full vs update) |
| Delegation context | contract_type, primary_concern, mode, forcing_data | notes_path, update_only |
| Agent interaction | Forcing questions (interactive) | File processing (autonomous) |
| Default file type | .md, .txt, .pdf (contracts) | .md (meeting notes) |

### 4. Delegation Context Specification

**From command to skill** (via Skill tool args string):
- `task_number` -- integer
- `notes_path` -- absolute file path to raw meeting notes (or structured file for --update)
- `update_only` -- boolean, true only when --update flag used
- `session_id` -- generated session ID

**From skill to agent** (via Task tool prompt JSON):
```json
{
  "task_context": {
    "task_number": 382,
    "project_name": "meeting_halcyon_ventures",
    "description": "Investor meeting: Halcyon Ventures",
    "language": "founder",
    "task_type": "meeting"
  },
  "notes_path": "/absolute/path/to/raw-notes.md",
  "update_only": false,
  "metadata_file_path": "specs/382_meeting_halcyon_ventures/.return-meta.json",
  "metadata": {
    "session_id": "sess_1736700000_abc123",
    "delegation_depth": 2,
    "delegation_path": ["orchestrator", "meeting", "skill-meeting", "meeting-agent"]
  }
}
```

### 5. Input Type Detection Logic

The command must handle three input patterns:

1. **`/meeting /path/to/notes.md`** -- Most common. File path to raw meeting notes.
   - Detection: Does not start with `--update`, not purely numeric
   - Validation: File must exist
   - Action: Create task, delegate with `update_only: false`

2. **`/meeting 382`** -- Resume/re-run on existing task.
   - Detection: Purely numeric input
   - Validation: Task exists in state.json, language is "founder"
   - Action: Load task, extract notes_path from task description or artifacts, delegate

3. **`/meeting --update /path/to/meeting-file.md`** -- CSV-only sync from existing structured file.
   - Detection: Starts with `--update`
   - Validation: File exists AND has YAML frontmatter (starts with `---`)
   - Action: Create task, delegate with `update_only: true`

Edge case for task number input: When resuming by task number, the `notes_path` must be recoverable. Options:
- Store `notes_path` in state.json task entry at creation time
- Or extract from artifact path in state.json
- Recommendation: Store `notes_path` as a field in the state.json task entry at creation time

## Decisions

- No STAGE 0 forcing questions for /meeting -- the file is the input, no interactive questioning needed
- No --quick legacy mode -- meeting processing always creates a task
- Command proceeds directly to delegation after task creation (unlike /legal which stops)
- Store `notes_path` in state.json task entry for resume-by-task-number support
- The `--update` flag maps to `update_only: true` in delegation context

## Risks & Mitigations

- **Risk**: Task number resume without stored notes_path. **Mitigation**: Store notes_path in state.json at task creation time.
- **Risk**: User passes non-existent file path. **Mitigation**: Validate file exists before task creation.
- **Risk**: --update file lacks YAML frontmatter. **Mitigation**: Check for `---` prefix, return clear error.

## Appendix

### Files Analyzed
- `/home/benjamin/.config/nvim/.claude/extensions/founder/skills/skill-legal/SKILL.md` -- 11-stage skill wrapper pattern (338 lines)
- `/home/benjamin/.config/nvim/.claude/extensions/founder/commands/legal.md` -- Command with STAGE 0 forcing questions (509 lines)
- `/home/benjamin/.config/nvim/.claude/extensions/founder/commands/finance.md` -- Another command with forcing questions (100 lines read)
- `/home/benjamin/.config/nvim/.claude/extensions/founder/agents/meeting-agent.md` -- Target agent (380 lines)
