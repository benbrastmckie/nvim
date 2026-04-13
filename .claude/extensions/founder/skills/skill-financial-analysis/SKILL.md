---
name: skill-financial-analysis
description: Financial analysis with forcing questions and spreadsheet generation
allowed-tools: Task, Bash, Edit, Read, Write
---

# Financial Analysis Skill

Thin wrapper that routes financial analysis research requests to the `financial-analysis-agent`.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns,
this skill handles all postflight operations (status update, artifact linking, git commit) before returning.

## Context Pointers

Reference (do not load eagerly):
- Path: `.claude/context/formats/return-metadata-file.md` - Metadata file schema
- Path: `.claude/context/patterns/jq-escaping-workarounds.md` - jq escaping patterns (Issue #1132)

Note: This skill is a thin wrapper. Context is loaded by the delegated agent, not this skill.

## Trigger Conditions

This skill activates when:

### Direct Invocation
- User runs `/research` on a task with language `founder:financial-analysis`

### When NOT to trigger

Do not invoke for:
- Cost breakdown from scratch (use skill-spreadsheet)
- Market sizing (use skill-market)
- General business analysis (use skill-analyze)
- Document review without data gathering (use skill-finance)

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- `mode` - Optional, one of: REVIEW, DILIGENCE, AUDIT, FORECAST

```bash
# Lookup task
task_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)

# Validate exists
if [ -z "$task_data" ]; then
  return error "Task $task_number not found"
fi

# Extract fields
task_type=$(echo "$task_data" | jq -r '.task_type // "founder"')
status=$(echo "$task_data" | jq -r '.status')
project_name=$(echo "$task_data" | jq -r '.project_name')
description=$(echo "$task_data" | jq -r '.description // ""')
forcing_data=$(echo "$task_data" | jq -r '.forcing_data // null')
```

---

### Stage 2: Preflight Status Update

```bash
bash .claude/scripts/update-task-status.sh preflight "$task_number" research "$session_id"
```

---

### Stage 3: Create Postflight Marker

```bash
padded_num=$(printf "%03d" "$task_number")
mkdir -p "specs/${padded_num}_${project_name}"

cat > "specs/${padded_num}_${project_name}/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-financial-analysis",
  "task_number": ${task_number},
  "operation": "research",
  "reason": "Postflight pending: status update, artifact linking, git commit",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "stop_hook_active": false
}
EOF
```

---

### Stage 3a: Read Artifact Number

```bash
artifact_number=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .next_artifact_number // 1' \
  specs/state.json)

artifact_padded=$(printf "%02d" "$artifact_number")
```

---

### Stage 4: Prepare Delegation Context

```json
{
  "session_id": "{session_id}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "research", "skill-financial-analysis"],
  "timeout": 3600,
  "task_context": {
    "task_number": "{N}",
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "{task_type}"
  },
  "artifact_number": "{artifact_number}",
  "mode": "{mode if provided}",
  "forcing_data": "{forcing_data from state.json if present}",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

---

### Stage 5: Invoke Subagent

**CRITICAL**: Use the **Task** tool to spawn the subagent.

```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "financial-analysis-agent"
  - prompt: [Include task_context, delegation_context, forcing_data]
  - description: "Execute financial analysis for task {N}"
```

The subagent will:
- Ask forcing questions to gather financial data
- Generate XLSX spreadsheet with formulas
- Export financial-metrics.json for Typst integration
- Create research report
- Write metadata to .return-meta.json

---

### Stage 5b: Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Task tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent), you MUST write a
`.return-meta.json` file now before proceeding to postflight. Use the schema from
`return-metadata-file.md` with the appropriate status value for this operation.

If you DID use the Task tool, skip this stage -- the subagent already wrote the metadata.

---

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 5b). Do NOT skip these stages for any reason.

### Stage 6: Read Metadata File

```bash
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    # Extract artifacts array
else
    status="failed"
fi
```

---

### Stage 7: Update Task Status (Postflight)

```bash
if [ "$status" = "researched" ]; then
  bash .claude/scripts/update-task-status.sh postflight "$task_number" research "$session_id"

  # Increment next_artifact_number
  jq '(.active_projects[] | select(.project_number == '$task_number')).next_artifact_number =
      (((.active_projects[] | select(.project_number == '$task_number')).next_artifact_number // 1) + 1)' \
    specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

---

### Stage 8: Link Artifacts

Link all artifacts (research report, spreadsheet, metrics JSON) to state.json using two-step jq pattern.

**Update TODO.md**: Link artifact per `@.claude/context/patterns/artifact-linking-todo.md` with `field_name=**Research**`, `next_field=**Plan**`.

---

### Stage 9: Git Commit

```bash
git add -A
git commit -m "task ${task_number}: complete financial analysis research

Session: ${session_id}

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

### Stage 10: Cleanup

```bash
rm -f "specs/${padded_num}_${project_name}/.postflight-pending"
rm -f "specs/${padded_num}_${project_name}/.return-meta.json"
```

---

### Stage 11: Return Brief Summary

```
Financial analysis research complete for task {N}:
- Mode: {MODE}, forcing questions completed
- Generated XLSX, JSON metrics, and research report
- Status updated to [RESEARCHED]
```

---

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:

1. **Edit source files** - All work is done by agent
2. **Run build/test commands** - Verification is done by agent
3. **Use AskUserQuestion** - Interactive tools are for agent use only
4. **Analyze financial data** - Analysis is agent work
5. **Write reports or spreadsheets** - Artifact creation is agent work

The postflight phase is LIMITED TO:
- Reading agent metadata file
- Calling `update-task-status.sh` for status updates
- Incrementing `next_artifact_number` via jq
- Linking artifacts in state.json
- Git commit
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md
