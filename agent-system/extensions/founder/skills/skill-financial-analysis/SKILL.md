---
name: skill-financial-analysis
description: Financial analysis with forcing questions and spreadsheet generation
allowed-tools: Agent, Bash, Edit, Read, Write
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

### Stage 2 + Stage 3: Preflight Status Update and Postflight Marker

Source `skill-base.sh` once, then follow `@.claude/context/patterns/skill-preflight-flow.md` in
full for Stage 2 (preflight status update) and Stage 3 (marker creation):

```bash
source .claude/scripts/skill-base.sh
padded_num=$(printf "%03d" "$task_number")
skill_name="skill-financial-analysis"
operation="research"
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

**CRITICAL**: Use the **Agent** tool to spawn the subagent.

```
Tool: Agent (NOT Skill, NOT Plan)
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

See `context/patterns/thin-wrapper-skill.md` § "3b. Self-Execution Fallback" for the full
obligation: if you performed the work above WITHOUT using the Agent tool, write
`.return-meta.json` now per `return-metadata-file.md`'s schema before proceeding to postflight.
If you DID use the Agent tool, skip this stage.

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
  bash .claude/scripts/state-write.sh \
    '(.active_projects[] | select(.project_number == $num)).next_artifact_number =
      (((.active_projects[] | select(.project_number == $num)).next_artifact_number // 1) + 1)' \
    --session-id "$session_id" \
    --argjson num "$task_number"
fi
```

---

### Stage 8: Link Artifacts

Link all artifacts (research report, spreadsheet, metrics JSON) to state.json using two-step jq pattern.

**Update TODO.md**: Link artifact per `@.claude/context/patterns/artifact-linking-todo.md` with `field_name=**Research**`, `next_field=**Plan**`.

---

### Stage 9: Git Commit

Apply the `research` scope from `.claude/context/standards/git-staging-scope.md` — targeted
staging, never a repo-wide add:

```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task ${task_number}: complete financial analysis research" \
  --session "${session_id}" \
  --honest-index-rows "${task_number}" \
  -- "specs/${padded_num}_${project_name}/reports/" \
     "specs/${padded_num}_${project_name}/.return-meta.json" \
     "specs/TODO.md" \
     "specs/state.json"
```

---

### Stage 10: Cleanup

Follow `@.claude/context/patterns/skill-postflight-flow.md`'s Stage 9 (cleanup):

```bash
skill_cleanup "$padded_num" "$project_name"
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
