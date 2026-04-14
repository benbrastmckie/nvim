---
name: skill-slide-critic
description: Interactive critique loop for slide presentations. Delegates to slide-critic-agent, presents findings to user, collects accept/reject/modify decisions, produces filtered critique report.
allowed-tools: Task, Bash, Edit, Read, Write, AskUserQuestion
context: fork
agent: slide-critic-agent
---

# Slide Critic Skill

Interactive critique feedback loop for academic presentations. Delegates to slide-critic-agent for
initial material review, parses the structured critique report, presents findings to the user grouped
by severity tier, collects accept/reject/modify decisions, loops until all issues are addressed, and
produces a final filtered critique report consumable by `/plan`.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns
and the interactive loop completes, this skill handles all postflight operations (status update,
artifact linking, git commit) before returning.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/formats/return-metadata-file.md` - Metadata file schema
- Path: `.claude/context/patterns/postflight-control.md` - Marker file protocol
- Path: `.claude/context/patterns/file-metadata-exchange.md` - File I/O helpers
- Path: `.claude/context/patterns/jq-escaping-workarounds.md` - jq escaping patterns (Issue #1132)

Note: This skill runs delegation then interactive Q&A. Context is loaded by the delegated agent.

## Trigger Conditions

This skill activates when:
- `/critique` command with task number input
- `/research` on a task with `task_type: "present:slides"` and `workflow_type: "slides_critique"`
- Present extension is available
- Task has existing slide materials to review (research reports, plans, or assembled slides)

---

## Input Parameters

### Required Parameters
- `task_number` - Task number (must exist in state.json with task_type containing "slides")
- `session_id` - Session ID from orchestrator

### Optional Parameters
- `focus_categories` - Subset of 6 rubric categories to prioritize (e.g., ["Narrative Flow", "Timing Balance"])
- `audience_context` - Audience description for calibrating review
- `materials_to_review` - Override default material discovery (array of file paths)

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- Verify task_type contains "slides" (supports "present:slides", "slides")

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
task_type=$(echo "$task_data" | jq -r '.task_type // ""')
status=$(echo "$task_data" | jq -r '.status')
project_name=$(echo "$task_data" | jq -r '.project_name')
description=$(echo "$task_data" | jq -r '.description // ""')
forcing_data=$(echo "$task_data" | jq -r '.forcing_data // {}')

# Validate task_type (supports "present:slides" or legacy "slides")
if [ "$task_type" != "present:slides" ] && [ "$task_type" != "slides" ]; then
  return error "Task $task_number is not a slides task (task_type=$task_type)"
fi

# Extract talk_type from forcing_data
talk_type=$(echo "$forcing_data" | jq -r '.talk_type // "CONFERENCE"')
```

---

### Stage 2: Preflight Status Update

Update task status to `researching` BEFORE invoking subagent.

```bash
padded_num=$(printf "%03d" "$task_number")
task_dir="specs/${padded_num}_${project_name}"
mkdir -p "$task_dir"

# Update state.json
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg sid "$session_id" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: "researching",
    last_updated: $ts,
    session_id: $sid
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

# Update TODO.md marker to [RESEARCHING]
```

Create postflight marker:

```bash
cat > "${task_dir}/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-slide-critic",
  "task_number": ${task_number},
  "operation": "slides_critique",
  "reason": "Postflight pending: status update, artifact linking, git commit",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "stop_hook_active": false
}
EOF
```

---

### Stage 3: Prepare Delegation Context

Discover materials to review (if not provided via `materials_to_review`):

```bash
# Auto-discover materials in task directory
report_files=$(ls -1 "${task_dir}/reports/"*.md 2>/dev/null)
plan_files=$(ls -1 "${task_dir}/plans/"*.md 2>/dev/null)

# Check for assembled slides
talk_dir="talks/${task_number}_${project_name}"
slide_files=$(ls -1 "${talk_dir}/slides.md" 2>/dev/null)
```

Build the materials array from discovered files, or use the `materials_to_review` parameter if provided.

**Delegation context**:

```json
{
  "session_id": "{session_id}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "critique", "skill-slide-critic", "slide-critic-agent"],
  "timeout": 3600,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "present:slides"
  },
  "workflow_type": "slides_critique",
  "forcing_data": {
    "talk_type": "{talk_type}",
    "materials_to_review": ["{discovered or provided paths}"],
    "focus_categories": "{focus_categories or omitted}",
    "audience_context": "{audience_context or omitted}"
  },
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

---

### Stage 4: Invoke Subagent

**CRITICAL**: Use the **Task** tool to spawn the slide-critic-agent. Do NOT use `Skill(...)`.

```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "slide-critic-agent"
  - prompt: [Include full delegation context from Stage 3]
  - description: "Critique presentation materials for task {N}"
```

The slide-critic-agent will:
1. Load the critique rubric and priority matrix
2. Read all review materials
3. Evaluate against 6 rubric categories (or focus_categories)
4. Write a critique report to `specs/{NNN}_{SLUG}/reports/{MM}_slide-critique.md`
5. Write metadata to `specs/{NNN}_{SLUG}/.return-meta.json`

**DO NOT** use `Skill(...)` - this will FAIL. Always use `Task`.

---

### Stage 4b: Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Task tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent), you MUST write a
`.return-meta.json` file now before proceeding. Use the schema from `return-metadata-file.md`
with status `researched`.

If you DID use the Task tool, skip this stage -- the subagent already wrote the metadata.

---

## Interactive Critique Loop (Stages 5-7)

### Stage 5: Parse Critique Report

After the subagent returns, read the critique report and extract findings.

1. **Read metadata file** to get the critique report path:
   ```bash
   metadata_file="${task_dir}/.return-meta.json"
   meta_status=$(jq -r '.status' "$metadata_file")
   critique_report_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
   findings_count=$(jq -r '.metadata.findings_count // {}' "$metadata_file")
   ```

2. **If agent failed or no findings**: Skip the interactive loop. Proceed directly to postflight with the agent's status.

3. **Read the critique report** and parse findings using these patterns:

   **Per-slide heading**: `### Slide N ({slide_type})`
   **Finding line**: `- [{severity}] {category}: {description}`
   **Suggestion line**: `Suggested improvement: {text}` (indented under finding)
   **General heading**: `### General (Cross-Cutting)`
   **Recommendation tiers**: `### Must Fix`, `### Should Fix`, `### Nice to Fix`

4. **Build numbered issue list**:
   ```
   issues = [
     { id: 1, slide: "Slide 3", severity: "Critical", category: "Narrative Flow",
       description: "...", suggestion: "...", tier: "Must Fix" },
     { id: 2, slide: "Slide 7", severity: "Critical", category: "Audience Alignment",
       description: "...", suggestion: "...", tier: "Must Fix" },
     { id: 3, slide: "General", severity: "Major", category: "Timing Balance",
       description: "...", suggestion: "...", tier: "Should Fix" },
     ...
   ]
   ```

   Assign tier based on severity:
   - Critical -> "Must Fix"
   - Major -> "Should Fix"
   - Minor -> "Nice to Fix"

5. **If no findings found in report** (agent found no issues): Report success with zero findings. Skip interactive loop.

---

### Stage 6: Interactive Critique Loop

Present all findings grouped by severity tier in a single consolidated AskUserQuestion.
Collect user decisions and loop until all issues are addressed or user exits.

**AskUserQuestion format**:

```
Critique findings for your {talk_type} presentation ({N} total issues):

=== MUST FIX ({count}) ===

 1. [Critical] {category} - {slide}: {description}
    Suggested: {suggestion}

 2. [Critical] {category} - {slide}: {description}
    Suggested: {suggestion}

=== SHOULD FIX ({count}) ===

 3. [Major] {category} - {slide}: {description}
    Suggested: {suggestion}

 4. [Major] {category} - {slide}: {description}
    Suggested: {suggestion}

=== NICE TO FIX ({count}) ===

 5. [Minor] {category} - {slide}: {description}
    Suggested: {suggestion}

---
For each issue, respond with its number and action:
  1: A          (accept as-is)
  3: R          (reject/dismiss)
  5: M add comparison to Smith 2024  (modify the suggestion)

Shortcuts: "accept all", "reject all minor", "done" (accept remaining)
```

**Response parsing grammar**:

Parse user response line by line. Each line matches one of:

| Pattern | Action | Effect |
|---------|--------|--------|
| `{N}: A` | Accept issue N | Mark as accepted, use original suggestion |
| `{N}: R` | Reject issue N | Mark as rejected/dismissed |
| `{N}: M {text}` | Modify issue N | Mark as modified, store user's text |
| `accept all` | Bulk accept | Accept all unaddressed issues |
| `reject all minor` | Bulk reject minor | Reject all Minor severity issues |
| `reject all` | Bulk reject | Reject all unaddressed issues |
| `done` | Finish | Accept all remaining unaddressed issues |

Track decisions per issue:
```
decisions = {
  1: { action: "accepted", modification: null },
  3: { action: "rejected", modification: null },
  5: { action: "modified", modification: "add comparison to Smith 2024" },
  ...
}
```

**Loop continuation**:

After processing responses:
- If all issues are addressed (each has an accepted/rejected/modified decision): proceed to Stage 7
- If unaddressed issues remain AND user did not say "done": re-present ONLY unaddressed issues in a follow-up AskUserQuestion
- Maximum 3 loop iterations to prevent infinite cycles. After 3 iterations, auto-accept all remaining unaddressed issues.

---

### Stage 7: Generate Filtered Critique Report

Write the final filtered report incorporating user decisions.

Determine artifact number:
```bash
next_num=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .next_artifact_number // 2' \
  specs/state.json)
# Use next available number for the filtered report
filtered_num=$(printf "%02d" "$next_num")
```

Write to `specs/{NNN}_{SLUG}/reports/{MM}_filtered-critique.md`:

```markdown
# Filtered Critique Report: {title}

- **Task**: {N} - {description}
- **Talk Type**: {talk_type}
- **Original Findings**: {total} ({critical} critical, {major} major, {minor} minor)
- **Accepted**: {accepted_count} ({modified_count} with modifications)
- **Rejected**: {rejected_count}

## Accepted Issues

### Must Fix ({count})

- Slide {N}: [{severity}] {category}: {description}
  Suggested: {original suggestion}
  {If modified: "User modification: {user text}"}

### Should Fix ({count})

- Slide {N}: [{severity}] {category}: {description}
  Suggested: {original suggestion}

### Nice to Fix ({count})

- Slide {N}: [{severity}] {category}: {description}
  Suggested: {original suggestion}

## Rejected Issues ({count})

{Listed for reference but marked as dismissed}

- Slide {N}: [{severity}] {category}: {description} -- DISMISSED

## User Notes

{Any freeform feedback captured during the loop, or "None"}

## Source Critique Report

Original critique: {critique_report_path}
```

Update `.return-meta.json` with final artifact info:
```json
{
  "status": "researched",
  "artifacts": [
    {
      "type": "report",
      "path": "specs/{NNN}_{SLUG}/reports/{MM}_filtered-critique.md",
      "summary": "Filtered critique: {accepted_count} accepted, {rejected_count} rejected of {total} findings"
    }
  ],
  "metadata": {
    "findings_count": {
      "total": N,
      "accepted": N,
      "rejected": N,
      "modified": N
    }
  }
}
```

---

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline. Do NOT skip these stages for any reason.

### Stage 8: Read Metadata File

```bash
metadata_file="${task_dir}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    meta_status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    artifact_type=$(jq -r '.artifacts[0].type // ""' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
else
    echo "Error: Invalid or missing metadata file"
    meta_status="failed"
fi
```

---

### Stage 9: Update Task Status (Postflight)

| Meta Status | Final state.json | Final TODO.md |
|-------------|-----------------|---------------|
| researched | researched | [RESEARCHED] |
| partial | researching | [RESEARCHING] |
| failed | (keep preflight) | (keep preflight marker) |

---

### Stage 10: Link Artifacts

Add artifact to state.json with summary. Use the two-step jq pattern to avoid Issue #1132.

**Update TODO.md**: Link artifact per `@.claude/context/patterns/artifact-linking-todo.md` with `field_name=**Report**`, `next_field=**Description**`.

---

### Stage 11: Git Commit

```bash
git add -A
git commit -m "task ${task_number}: complete slide critique

Session: ${session_id}"
```

---

### Stage 12: Cleanup

```bash
rm -f "${task_dir}/.postflight-pending"
rm -f "${task_dir}/.postflight-loop-guard"
rm -f "${task_dir}/.return-meta.json"
```

---

### Stage 13: Return Brief Summary

**Success**:
```
Slide critique completed for task {N}:
- Evaluated materials against {category_count} rubric categories
- Talk type: {talk_type}
- Original findings: {critical} critical, {major} major, {minor} minor
- User decisions: {accepted} accepted ({modified} modified), {rejected} rejected
- Filtered report: specs/{NNN}_{SLUG}/reports/{MM}_filtered-critique.md
- Status updated to [RESEARCHED]
- Changes committed with session {session_id}
```

**No findings**:
```
Slide critique completed for task {N}:
- No issues found by slide-critic-agent
- Materials appear well-structured for {talk_type} presentation
- Status updated to [RESEARCHED]
- Changes committed with session {session_id}
```

**Partial**:
```
Slide critique partially completed for task {N}:
- Agent produced findings but interactive loop was interrupted
- Run critique again to resume (existing report preserved)
```

---

## Error Handling

### Task not found
```
Slide critique error for task {N}:
- Task not found in state.json
- No status changes made
```

### Wrong task type
```
Slide critique error for task {N}:
- Task is not a slides task (task_type={task_type})
- No status changes made
```

### Metadata file missing after agent
Keep status at preflight level (researching) for resume.

### No findings from agent
Not an error. Report "no issues found" as success. Skip interactive loop. Write researched status.

### User abandons mid-loop
Accept all remaining unaddressed issues. Proceed to filtered report generation. Note in report that some issues were auto-accepted due to early exit.

### Git commit failure
Non-blocking. Log failure but continue.

---

## Return Format

This skill returns a **brief text summary** (NOT JSON). The JSON metadata is written to the file and processed internally.
