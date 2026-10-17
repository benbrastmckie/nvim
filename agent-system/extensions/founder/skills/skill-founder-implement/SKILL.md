---
name: skill-founder-implement
description: Execute founder plans and generate strategy reports
allowed-tools: Agent, Bash, Edit, Read, Write
---

# Founder Implement Skill

Routes founder-specific implementation requests to the `founder-implement-agent`, executing plans created by `skill-founder-plan` and generating detailed strategy reports.

## Context Pointers

Reference (do not load eagerly):
- Path: `.claude/context/formats/subagent-return.md`
- Purpose: Return validation
- Load at: Subagent execution only

Note: This skill is a thin wrapper. Context is loaded by the delegated agent, not this skill.

## Trigger Conditions

This skill activates when:

### Direct Invocation
- `/implement` command on a task with `language: founder`
- Extension routing lookup finds `routing.implement.founder`

### Task-Type-Based Routing
- Task type is "founder"
- `/implement {N}` where task {N} has language="founder"

### When NOT to trigger

Do not invoke for:
- Tasks with other language types (general, meta, neovim, etc.)
- Quick mode operations (`--quick` flag)
- Tasks in [NOT STARTED] status (need plan first)
- Tasks already [COMPLETED]

---

## Execution

### 1. Input Validation

Validate inputs from delegation context:
- `task_number` - Required, integer
- `plan_path` - Required, path to implementation plan
- `resume_phase` - Optional, phase number to resume from
- `session_id` - Required, string

```bash
# Validate task_number is present
if [ -z "$task_number" ]; then
  return error "task_number is required"
fi

# Validate session_id is present
if [ -z "$session_id" ]; then
  return error "session_id is required"
fi

# Validate plan_path exists
if [ -z "$plan_path" ] || [ ! -f "$plan_path" ]; then
  return error "plan_path is required and must exist. Run /orchestrate first."
fi
```

### 2 + 3. Preflight Status Update and Postflight Marker

Source `skill-base.sh` once, then follow `@.claude/context/patterns/skill-preflight-flow.md` in
full for Stage 2 (preflight status update) and Stage 3 (marker creation):

```bash
source .claude/scripts/skill-base.sh
padded_num=$(printf "%03d" "$task_number")
project_name=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .project_name' \
  specs/state.json)
task_dir="specs/${padded_num}_${project_name}"
mkdir -p "$task_dir"
skill_name="skill-founder-implement"
operation="implement"
```

### 4. Context Preparation

Extract task_type from state.json (null-safe):

```bash
# Extract task_type from state.json (null-safe)
task_type=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .task_type // null' \
  specs/state.json)
```

Prepare delegation context for agent:

```json
{
  "task_context": {
    "task_number": 234,
    "project_name": "market_sizing_fintech_payments",
    "description": "Market sizing: fintech payments",
    "task_type": "founder",
    "task_type": "market"
  },
  "plan_path": "specs/234_market_sizing_fintech_payments/plans/01_market-sizing-plan.md",
  "resume_phase": 1,
  "output_dir": "strategy/",
  "metadata_file_path": "specs/234_market_sizing_fintech_payments/.return-meta.json",
  "metadata": {
    "session_id": "sess_{timestamp}_{random}",
    "delegation_depth": 2,
    "delegation_path": ["orchestrator", "implement", "skill-founder-implement"]
  }
}
```

### 5. Invoke Agent

**CRITICAL**: You MUST use the **Agent** tool to spawn the agent.

**Required Tool Invocation**:
```
Tool: Agent (NOT Skill, NOT Plan)
Parameters:
  - subagent_type: "founder-implement-agent"
  - prompt: [Include task_context, plan_path, resume_phase, output_dir, metadata]
  - description: "Execute founder plan and generate strategy report"
```

The agent will:
- Load plan and detect resume point
- Execute phases (TAM -> SAM -> SOM -> Report -> Typst/PDF)
- Generate report artifact in `strategy/` directory (markdown)
- Generate typst/PDF in `founder/` directory (if typst installed)
- Create summary in task directory
- Write metadata file for postflight consumption
- Return brief text summary

**Note**: Phase 5 (Typst/PDF generation) is optional. Task completes successfully
even if typst is not installed or PDF generation fails.

### 5b. Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Agent tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent), you MUST write a
`.return-meta.json` file now before proceeding to postflight. Use the schema from
`return-metadata-file.md` with the appropriate status value for this operation.

If you DID use the Agent tool, skip this stage -- the subagent already wrote the metadata.

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 5b). Do NOT skip these stages for any reason.

### 6. Read Metadata File

Read the metadata file:

```bash
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"
metadata=$(cat "$metadata_file")
status=$(echo "$metadata" | jq -r '.status')
```

### 7. Postflight Status Update

If agent succeeded (status == "implemented"):

```bash
# Update state.json to completed
bash .claude/scripts/state-write.sh \
   '(.active_projects[] | select(.project_number == $num)) += {
     status: "completed",
     last_updated: $ts
   }' \
   --session-id "$session_id" \
   --argjson num "$task_number" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Read typst metadata fields to determine which artifacts exist
typst_source=$(echo "$metadata" | jq -r '.metadata.typst_source_generated // false')
pdf_compiled=$(echo "$metadata" | jq -r '.metadata.pdf_compiled // false')

# Link artifacts in state.json with typst-primary ordering:
#   1. .typ source file (primary, always generated)
#   2. .pdf compiled output (conditional on pdf_compiled)
#   3. .md markdown report (fallback, always generated)
#   4. summary artifact (always generated)
artifacts=$(echo "$metadata" | jq '.artifacts')
for i in $(seq 0 $(($(echo "$artifacts" | jq 'length') - 1))); do
  artifact_type=$(echo "$artifacts" | jq -r ".[$i].type")
  artifact_path=$(echo "$artifacts" | jq -r ".[$i].path")
  artifact_summary=$(echo "$artifacts" | jq -r ".[$i].summary")

  # Skip PDF artifact if pdf_compiled is false
  if [ "$pdf_compiled" = "false" ] && echo "$artifact_path" | grep -q '\.pdf$'; then
    continue
  fi

  bash .claude/scripts/state-write.sh \
     '(.active_projects[] | select(.project_number == $num)).artifacts += [{
       type: $type,
       path: $path,
       summary: $summary
     }]' \
     --session-id "$session_id" \
     --argjson num "$task_number" \
     --arg type "$artifact_type" \
     --arg path "$artifact_path" \
     --arg summary "$artifact_summary"
done
```

Update TODO.md status marker to [COMPLETED], add Completed date, and link summary artifact per `@.claude/context/patterns/artifact-linking-todo.md` with `field_name=**Summary**`, `next_field=**Description**`.

If partial (status == "partial"):
- Keep status as "implementing"
- Note resume point in metadata

### 8. Git Commit

Apply the `implement` scope from `.claude/context/standards/git-staging-scope.md` — targeted
staging, never a repo-wide add:

```bash
stage_paths=("${task_dir}/" "specs/TODO.md" "specs/state.json")
metadata_file="${task_dir}/.return-meta.json"
while IFS= read -r f; do
  [ -n "$f" ] && stage_paths+=("$f")
done < <(jq -r '.modified_files[]? // empty' "$metadata_file" 2>/dev/null)
bash .claude/scripts/git-commit-scoped.sh \
  --message "task {N}: complete implementation" \
  --session "{session_id}" \
  --honest-index-rows {N} \
  -- "${stage_paths[@]}"
```

### 9. Cleanup and Return

Follow `@.claude/context/patterns/skill-postflight-flow.md`'s Stage 9 (cleanup):

```bash
skill_cleanup "$padded_num" "$project_name"
```

Return brief text summary to caller.

---

## MUST NOT (Postflight Boundary)

After the agent returns -- whether with status implemented, partial, or failed -- this skill MUST proceed immediately to postflight (Stage 6). The skill MUST NOT:

1. **Edit strategy/report files** - All implementation work is done by agent
2. **Run calculations** - Analysis is done by agent
3. **Use MCP tools** - Domain tools are for agent use only
4. **Analyze or grep source** - Analysis is agent work
5. **Write summary/reports** - Artifact creation is done by agent

> **PROHIBITION**: If the subagent returned partial or failed status, the lead skill MUST NOT attempt to continue, complete, or "fill in" the subagent's work. Report the partial/failed status and let the user re-run `/implement` to resume.

The postflight phase is LIMITED TO:
- Reading agent metadata file
- Updating state.json via jq
- Updating TODO.md status marker via Edit
- Linking artifacts in state.json
- Git commit
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md

---

## Return Format

Brief text summary (NOT JSON).

Expected successful return (with PDF compiled):
```
Founder implementation completed for task {N}:
- Phases {phases_completed}/{phases_total} executed
- TAM: {tam}, SAM: {sam}, SOM Y1: {som_y1}
- Typst source: founder/{report-type}-{slug}.typ (primary)
- PDF report: founder/{report-type}-{slug}.pdf (compiled)
- Markdown: strategy/{report-type}-{slug}.md (fallback)
- Summary: specs/{NNN}_{SLUG}/summaries/01_{short-slug}-summary.md
- Status updated to [COMPLETED]
- Changes committed with session {session_id}
- Next: Review report and validate assumptions
```

Expected successful return (without PDF - typst CLI not installed):
```
Founder implementation completed for task {N}:
- Phases {phases_completed}/{phases_total} executed (PDF skipped - typst not installed)
- TAM: {tam}, SAM: {sam}, SOM Y1: {som_y1}
- Typst source: founder/{report-type}-{slug}.typ (primary)
- Markdown: strategy/{report-type}-{slug}.md (fallback)
- Summary: specs/{NNN}_{SLUG}/summaries/01_{short-slug}-summary.md
- Status updated to [COMPLETED]
- Changes committed with session {session_id}
- Next: Install typst for PDF output, or review typst source / markdown report
```

**Note**: Typst source is always generated in Phase 4 regardless of typst CLI availability.
Phase 5 (PDF compilation) is optional -- if typst CLI is not installed or compilation fails,
the task still completes successfully. The `.typ` source file remains the primary artifact.

Expected partial return (core phase failure):
```
Founder implementation partially completed for task {N}:
- Phases {phases_completed}/{phases_total} executed
- Data gathered: {brief summary of progress}
- Resume phase: {resume_phase}
- Status remains [IMPLEMENTING]
- Next: Run /orchestrate {N} to resume from phase {resume_phase}
```

---

## Error Handling

### Session ID Missing
Return immediately with failed status.

### Plan Not Found
Return error with guidance to run /plan first.

### Task Not Found
Return error with guidance to check task number.

### Agent Errors
Pass through the agent's error return verbatim.

### Build/Calculation Errors
Return partial status with progress made.

### Phase 5 Typst/PDF Errors
Phase 5 failures do NOT block task completion:
- **Typst not installed**: Task completes with markdown output only
- **Compilation error**: Keep .typ file for debugging, task completes
- **PDF empty**: Keep .typ file, task completes

Postflight should check `metadata.typst_source_generated` and `metadata.pdf_compiled` to determine what artifacts to report.
