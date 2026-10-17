---
name: skill-deck-implement
description: Route deck implementation to deck-builder-agent for Slidev pitch deck generation
allowed-tools: Agent, Bash, Edit, Read, Write
---

# Deck Implement Skill

Routes deck-specific implementation requests to the `deck-builder-agent`, generating Slidev pitch decks from plans created by `skill-deck-plan` and research from `skill-deck-research`.

## Context Pointers

Reference (do not load eagerly):
- Path: `.claude/context/formats/subagent-return.md`
- Purpose: Return validation
- Load at: Subagent execution only

Note: This skill is a thin wrapper. Context is loaded by the delegated agent, not this skill.

## Trigger Conditions

This skill activates when:

### Direct Invocation
- `/implement` command on a task with `language: founder` and `task_type: deck`
- Extension routing lookup finds `routing.implement["founder:deck"]`

### Task-Type-Based Routing
- Task type is "founder" AND task_type is "deck"
- `/implement {N}` where task {N} has language="founder", task_type="deck"

### When NOT to trigger

Do not invoke for:
- Tasks with other task_types (market, analyze, strategy, legal, project, sheet, finance)
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
skill_name="skill-deck-implement"
operation="implement"
```

### 4. Context Preparation

Extract template palette from the plan file:

```bash
# Extract template palette from plan (look for "palette:" or "template:" in plan metadata)
template_palette=$(grep -oP '(?:palette|template):\s*\K[\w-]+' "$plan_path" | head -1)
template_palette="${template_palette:-dark-blue}"

# Extract forcing_data from state.json if available
forcing_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .forcing_data // null' \
  specs/state.json)
```

Prepare delegation context for agent:

```json
{
  "task_context": {
    "task_number": 234,
    "project_name": "seed_round_pitch_deck",
    "description": "Seed round pitch deck",
    "task_type": "founder",
    "task_type": "deck"
  },
  "plan_path": "specs/234_seed_round_pitch_deck/plans/01_deck-plan.md",
  "resume_phase": 1,
  "output_dir": "strategy/",
  "template_palette": "dark-blue",
  "forcing_data": {
    "purpose": "INVESTOR",
    "source_materials": ["task:233"]
  },
  "metadata_file_path": "specs/234_seed_round_pitch_deck/.return-meta.json",
  "metadata": {
    "session_id": "sess_{timestamp}_{random}",
    "delegation_depth": 2,
    "delegation_path": ["orchestrator", "implement", "skill-deck-implement"]
  }
}
```

### 5. Invoke Agent

**CRITICAL**: You MUST use the **Agent** tool to spawn the agent.

**Required Tool Invocation**:
```
Tool: Agent (NOT Skill, NOT Plan)
Parameters:
  - subagent_type: "deck-builder-agent"
  - prompt: [Include task_context, plan_path, resume_phase, output_dir, template_palette, forcing_data, metadata]
  - description: "Generate Slidev pitch deck from plan and research"
```

The agent will:
- Load plan and research report
- Load theme config from `.context/deck/themes/`
- Assemble `slides.md` from library content with slot filling
- Compose CSS styles and copy Vue components
- Attempt non-blocking `slidev export` for PDF
- Write-back new content to library
- Create summary in task directory
- Write metadata file for postflight consumption
- Return brief text summary

**Note**: Slidev export (PDF generation) is optional. Task completes successfully
even if slidev is not installed or PDF generation fails. The `slides.md` source is preserved.

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

# Link artifacts in state.json (deck files and summary)
artifacts=$(echo "$metadata" | jq '.artifacts')
for i in $(seq 0 $(($(echo "$artifacts" | jq 'length') - 1))); do
  artifact_type=$(echo "$artifacts" | jq -r ".[$i].type")
  artifact_path=$(echo "$artifacts" | jq -r ".[$i].path")
  artifact_summary=$(echo "$artifacts" | jq -r ".[$i].summary")
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

1. **Edit slides/deck files** - All deck generation is done by agent
2. **Run slidev commands** - Export/build is done by agent
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

Expected successful return (with PDF):
```
Deck implementation completed for task {N}:
- Theme: {theme_name}, Pattern: {pattern_name}
- Slides populated: {M}/{total} from research
- Slidev source: strategy/{slug}-deck/slides.md
- PDF: strategy/{slug}-deck/{slug}-deck.pdf
- Summary: specs/{NNN}_{SLUG}/summaries/01_{short-slug}-summary.md
- Status updated to [COMPLETED]
- Changes committed with session {session_id}
- Next: Review deck and fill remaining [TODO:] markers
```

Expected successful return (without PDF):
```
Deck implementation completed for task {N}:
- Theme: {theme_name}, Pattern: {pattern_name}
- Slides populated: {M}/{total} from research
- Slidev source: strategy/{slug}-deck/slides.md
- PDF: skipped (slidev not installed)
- Summary: specs/{NNN}_{SLUG}/summaries/01_{short-slug}-summary.md
- Status updated to [COMPLETED]
- Changes committed with session {session_id}
- Next: Install slidev for PDF export, or review slides.md source
```

Expected partial return:
```
Deck implementation partially completed for task {N}:
- Template selected but content generation incomplete
- Resume phase: {resume_phase}
- Status remains [IMPLEMENTING]
- Next: Run /orchestrate {N} to resume
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

### Slidev/PDF Errors
PDF export failures do NOT block task completion:
- **Slidev not installed**: Task completes with `slides.md` source only
- **Export error**: Keep `slides.md` for debugging, task completes
- **PDF empty**: Keep `slides.md`, task completes

Postflight should check `metadata.pdf_generated` to determine what artifacts to report.
