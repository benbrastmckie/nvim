---
name: skill-typst-research
description: Research Typst documentation tasks using domain context and codebase exploration. Invoke for typst-language research involving document structure, theorem environments, cross-references, compilation, and Typst best practices.
allowed-tools: Task, Bash, Edit, Read, Write
# Research tools used by subagent:
#   - Glob, Grep, Read (codebase exploration)
#   - WebSearch, WebFetch (external research)
#   - Context loading via @-references
---

# Typst Research Skill

Thin wrapper that delegates Typst documentation research to `typst-research-agent` subagent.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns,
this skill handles all postflight operations (status update, artifact linking, git commit) before returning.
This eliminates the "continue" prompt issue between skill return and orchestrator.

## Context References

Reference (do not load eagerly):
- Path: `.opencode/context/core/formats/return-metadata-file.md` - Metadata file schema
- Path: `.opencode/context/core/patterns/postflight-control.md` - Marker file protocol
- Path: `.opencode/context/core/patterns/jq-escaping-workarounds.md` - jq escaping patterns (Issue #1132)
- Path: `.opencode/context/core/templates/context-knowledge-template.md` - Context knowledge extraction template

Note: This skill is a thin wrapper with internal postflight. Context is loaded by the delegated agent.

## Trigger Conditions

This skill activates when:
- Task language is "typst"
- Research involves document structure, theorem environments, cross-references, compilation, or Typst best practices
- Domain context files are needed for Typst documentation

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- `focus_prompt` - Optional focus for research direction

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
language=$(echo "$task_data" | jq -r '.language // "general"')
status=$(echo "$task_data" | jq -r '.status')
project_name=$(echo "$task_data" | jq -r '.project_name')
description=$(echo "$task_data" | jq -r '.description // ""')
```

---

### Stage 2: Preflight Status Update

Update task status to "researching" BEFORE invoking subagent.

**Update state.json**:
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "researching" \
   --arg sid "$session_id" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    session_id: $sid
  }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

**Update TODO.md**: Use Edit tool to change status marker from `[NOT STARTED]` or `[RESEARCHED]` to `[RESEARCHING]`.

---

### Stage 3: Create Postflight Marker

Create the marker file to prevent premature termination:

```bash
# Ensure task directory exists
mkdir -p "specs/$(printf '%03d' ${task_number})_${project_name}"

cat > "specs/$(printf '%03d' ${task_number})_${project_name}/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-typst-research",
  "task_number": ${task_number},
  "operation": "research",
  "reason": "Postflight pending: status update, artifact linking, git commit",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "stop_hook_active": false
}
EOF
```

---

### Stage 4: Prepare Delegation Context

Prepare delegation context for the subagent:

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "research", "skill-typst-research"],
  "timeout": 3600,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "language": "typst"
  },
  "focus_prompt": "{optional focus}",
  "metadata_file_path": "specs/{OC_NNN}_{SLUG}/.return-meta.json"
}
```

---

### Stage 5: Invoke Subagent

**CRITICAL**: You MUST use the **Task** tool to spawn the subagent.

**Required Tool Invocation**:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "typst-research-agent"
  - prompt: [Include task_context, delegation_context, focus_prompt, metadata_file_path]
  - description: "Execute Typst research for task {N}"
```

**DO NOT** use `Skill(typst-research-agent)` - this will FAIL.

The subagent will:
- Load domain context files from `.opencode/context/project/typst/`
- Search codebase (Typst chapters, notation modules) for existing patterns
- Execute web research for Typst documentation and best practices
- Analyze findings and synthesize recommendations
- Create research report in `specs/{OC_NNN}_{SLUG}/reports/`
- Write metadata to `specs/{OC_NNN}_{SLUG}/.return-meta.json`
- Return a brief text summary (NOT JSON)

---

### Stage 6: Parse Subagent Return (Read Metadata File)

After subagent returns, read the metadata file:

```bash
metadata_file="specs/$(printf '%03d' ${task_number})_${project_name}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    artifact_type=$(jq -r '.artifacts[0].type // ""' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
else
    echo "Error: Invalid or missing metadata file"
    status="failed"
fi
```

---

### Stage 7: Update Task Status (Postflight)

If status is "researched", update state.json and TODO.md:

**Update state.json**:
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "researched" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    researched: $ts
  }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

**Update TODO.md**: Use Edit tool to change status marker from `[RESEARCHING]` to `[RESEARCHED]`.

**On partial/failed**: Keep status as "researching" for resume.

---

### Stage 8: Link Artifacts

Add artifact to state.json with summary.

**IMPORTANT**: Use two-step jq pattern to avoid Issue #1132 escaping bug. See `jq-escaping-workarounds.md`.

```bash
if [ -n "$artifact_path" ]; then
    # Step 1: Filter out existing research artifacts (use "| not" pattern to avoid != escaping - Issue #1132)
    jq '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
        [(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "research" | not)]' \
      specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json

    # Step 2: Add new research artifact
    jq --arg path "$artifact_path" \
       --arg type "$artifact_type" \
       --arg summary "$artifact_summary" \
      '(.active_projects[] | select(.project_number == '$task_number')).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
      specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
fi
```

**Update TODO.md**: Add research artifact link:
```markdown
- **Research**: [research-{NNN}.md]({artifact_path})
```

---

### Stage 9: Git Commit

Commit only the changed files with session ID:

```bash
# Get list of changed files (targeted commit, not git add -A)
git status --porcelain | awk '{print $NF}' > /tmp/changed_files_$$.txt
changed_files=$(cat /tmp/changed_files_$$.txt | tr '\n' ' ')

if [ -n "$changed_files" ]; then
    git add $changed_files
    git commit -m "task ${task_number}: complete research

Session: ${session_id}

Co-Authored-By: OpenCode <noreply@opencode.ai>" || echo "Warning: Commit failed but research completed"
fi

# Cleanup temp file
rm -f /tmp/changed_files_$$.txt
```

---

### Stage 10: Cleanup

Remove marker and metadata files:

```bash
rm -f "specs/$(printf '%03d' ${task_number})_${project_name}/.postflight-pending"
rm -f "specs/$(printf '%03d' ${task_number})_${project_name}/.postflight-loop-guard"
rm -f "specs/$(printf '%03d' ${task_number})_${project_name}/.return-meta.json"
```

---

### Stage 11: Return Brief Summary

Return a brief text summary (NOT JSON). Example:

```
Research completed for task {N}:
- Found existing patterns in Typst chapters and notation modules
- Loaded domain context for document structure and theorem environments
- Created report at specs/{OC_NNN}_{SLUG}/reports/research-{NNN}.md
- Status updated to [RESEARCHED]
- Changes committed
```

---

## Error Handling

### Input Validation Errors
Return immediately with error message if task not found.

### Metadata File Missing
If subagent didn't write metadata file:
1. Keep status as "researching"
2. Do not cleanup postflight marker
3. Report error to user

### Git Commit Failure
Non-blocking: Log failure but continue with success response.

### Subagent Timeout
Return partial status if subagent times out (default 3600s).
Keep status as "researching" for resume.

---

## Return Format

This skill returns a **brief text summary** (NOT JSON). The JSON metadata is written to the file and processed internally.

Example successful return:
```
Research completed for task 412:
- Found existing document patterns in Theories/Bimodal/typst/chapters/
- Loaded document-structure.md and typst-style-guide.md context
- Created report at specs/412_document_theorem_environments/reports/research-001.md
- Status updated to [RESEARCHED]
- Changes committed with session sess_1736700000_abc123
```

Example partial return:
```
Research partially completed for task 412:
- Found patterns in 3 Typst chapters before timeout
- Partial report created at specs/412_document_theorem_environments/reports/research-001.md
- Status remains [RESEARCHING] - run /research 412 to continue
```
