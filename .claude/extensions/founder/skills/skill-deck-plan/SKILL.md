---
name: skill-deck-plan
description: Pitch deck planning with interactive template, content, and ordering selection
allowed-tools: Task, Bash, Edit, Read, Write, Glob, AskUserQuestion
---

# Deck Plan Skill

Interactive pitch deck planning skill that gathers user preferences (pattern, theme, content, ordering) via AskUserQuestion pickers before delegating plan generation to `deck-planner-agent`. Handles preflight/postflight status management and all interactive selection.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns,
this skill handles all postflight operations (status update, artifact linking, git commit) before returning.

## Context Pointers

Reference (do not load eagerly):
- Path: `.claude/context/formats/subagent-return.md`
- Purpose: Return validation
- Load at: Subagent execution only
- Path: `.context/deck/index.json`
- Purpose: Library index for building AskUserQuestion options
- Load at: Stage 4.1 (Library Initialization)

## Trigger Conditions

This skill activates when:

### Direct Invocation
- `/plan` command on a task with `language: founder` and `task_type: deck`
- Extension routing lookup finds `routing.plan["founder:deck"]`

### Task-Type-Based Routing
- Task type is "founder" AND task_type is "deck"
- `/plan {N}` where task {N} has language="founder" and task_type="deck"

### When NOT to trigger

Do not invoke for:
- Non-deck founder tasks (use skill-founder-plan)
- Tasks with other language types (general, meta, neovim, etc.)
- Tasks already in [PLANNED] or [COMPLETED] status

**Note**: The `--quick` flag is handled inside this skill (skips pattern and theme questions, uses defaults). It is NOT a reason to skip this skill.

---

## Execution

### Stage 1: Input Validation

Validate inputs from delegation context:
- `task_number` - Required, integer
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
```

### Stage 2: Preflight Status Update

Update task status to "planning" in state.json:

```bash
jq --argjson num "$task_number" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '(.active_projects[] | select(.project_number == $num)) += {
     status: "planning",
     last_updated: $ts
   }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

Update TODO.md status marker to [PLANNING].

### Stage 3: Create Postflight Marker

Create marker file to signal postflight operations needed:

```bash
padded_num=$(printf "%03d" "$task_number")
project_name=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .project_name' \
  specs/state.json)
task_dir="specs/${padded_num}_${project_name}"
mkdir -p "$task_dir"

cat > "$task_dir/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-deck-plan",
  "task_number": ${task_number},
  "operation": "plan",
  "reason": "Postflight pending: status update, artifact linking, git commit",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
```

### Stage 4: Context Preparation

Extract task_type and research_path from state.json:

```bash
# Extract task_type from state.json (null-safe)
task_type=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .task_type // null' \
  specs/state.json)

# Find research report path
research_path=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .artifacts[] | select(.type == "research") | .path' \
  specs/state.json 2>/dev/null | head -1)
```

Prepare base delegation context (enhanced in Stage 4.4):

```json
{
  "task_context": {
    "task_number": 234,
    "project_name": "{project_name}",
    "description": "{description}",
    "task_type": "founder",
    "task_type": "deck"
  },
  "research_path": "specs/{NNN}_{SLUG}/reports/01_{short-slug}.md",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json",
  "metadata": {
    "session_id": "sess_{timestamp}_{random}",
    "delegation_depth": 2,
    "delegation_path": ["orchestrator", "plan", "skill-deck-plan"]
  }
}
```

### Stage 4.1: Library Initialization

If `.context/deck/index.json` does not exist, initialize the deck library from the extension seed:

```bash
if [ ! -f .context/deck/index.json ]; then
  mkdir -p .context/deck
  cp -r .claude/extensions/founder/context/project/founder/deck/* .context/deck/
  echo "Initialized deck library from extension seed"
fi
```

This ensures the reusable deck library is available for building AskUserQuestion options.

### Stage 4.2: Load Research Report

Read the research report at `research_path`. Extract:

1. **Slide Content Analysis**: For each slide, whether content is populated or MISSING
2. **Appendix Content**: Any content listed under "Additional Content for Appendix"
3. **Information Gaps**: Critical vs nice-to-have gaps
4. **Purpose**: Deck purpose (INVESTOR, UPDATE, INTERNAL, PARTNERSHIP)

If no research report exists, return with status "failed" and message: "No research report found. Run /research {N} first."

### Stage 4.3: Interactive Questions

Execute 4 sequential AskUserQuestion calls to gather user preferences. Each question uses the structured JSON format.

**`--quick` flag handling**: If `--quick` flag is set in the command arguments, skip questions 1 and 2 (pattern and theme). Use defaults: `pattern = "yc-10-slide"`, `theme = "dark-blue"`. Still execute questions 3 and 4 (content and ordering).

#### Question 1: Pattern Selection (single select)

Query the library index for available patterns:

```bash
jq -r '.entries[] | select(.category == "pattern") | "\(.id)|\(.name)|\(.description)"' .context/deck/index.json
```

Present via AskUserQuestion:

```json
{
  "question": "Select a deck pattern for your pitch deck:",
  "header": "Deck Pattern",
  "multiSelect": false,
  "options": [
    {
      "label": "YC 10-Slide Investor Pitch",
      "description": "Standard Y Combinator format (10 slides) [yc-10-slide]"
    },
    {
      "label": "Lightning Talk",
      "description": "5-minute format (5 slides) [lightning-talk]"
    },
    {
      "label": "Product Demo",
      "description": "Screenshots, code, demo (8-12 slides) [product-demo]"
    },
    {
      "label": "Investor Update",
      "description": "Quarterly update (8 slides) [investor-update]"
    },
    {
      "label": "Partnership Proposal",
      "description": "Business partnership (8 slides) [partnership-proposal]"
    }
  ]
}
```

Build options dynamically from `index.json` entries where `category == "pattern"`.

Store `selected_pattern` with the pattern id and slide sequence from the pattern JSON.

#### Question 2: Theme Selection (single select)

Query the library index for available themes:

```bash
jq -r '.entries[] | select(.category == "theme") | "\(.id)|\(.name)|\(.description)|\(.tags.color_schema)"' .context/deck/index.json
```

Present via AskUserQuestion:

```json
{
  "question": "Select a visual theme:",
  "header": "Visual Theme",
  "multiSelect": false,
  "options": [
    {
      "label": "Dark Blue (AI Startup)",
      "description": "Deep navy + blue accents [dark] [dark-blue]"
    },
    {
      "label": "Minimal Light",
      "description": "Clean white + blue accent [light] [minimal-light]"
    },
    {
      "label": "Premium Dark (Gold)",
      "description": "Near-black + gold accents [dark] [premium-dark]"
    },
    {
      "label": "Growth Green",
      "description": "Mint/white + green accents [light] [growth-green]"
    },
    {
      "label": "Professional Blue",
      "description": "White + navy/blue [light] [professional-blue]"
    }
  ]
}
```

Build options dynamically from `index.json` entries where `category == "theme"`.

Store `selected_theme` with theme id and config path.

#### Question 3: Content Selection (multi select per slide position)

For each slide position in the selected pattern:
1. Query content library for matching `slide_type` entries
2. Check research report for available content
3. Present existing library content + option to create NEW

Present via AskUserQuestion:

```json
{
  "question": "Assign content for each slide position. Select library content or mark as NEW.\n\nSlide 1 (cover): cover-standard, cover-hero, NEW\nSlide 2 (problem): problem-statement, problem-story, NEW\n...",
  "header": "Slide Content Assignment",
  "multiSelect": true,
  "options": [
    {
      "label": "Slide 1 (cover): cover-standard",
      "description": "Standard title + tagline + round"
    },
    {
      "label": "Slide 1 (cover): NEW",
      "description": "Create new cover content from research"
    },
    {
      "label": "Slide 2 (problem): problem-statement",
      "description": "Bold single-sentence + 3 evidence points"
    },
    {
      "label": "Slide 2 (problem): NEW",
      "description": "Create new problem content from research"
    }
  ]
}
```

Build options dynamically per slide position from index.json content entries + NEW option.

Also ask which slides should be MAIN vs APPENDIX. If the pattern defines default main/appendix split, present that as the default selection.

**Validation**: If fewer than 3 main slides selected, present a confirmation question:
```json
{
  "question": "You selected fewer than 3 main slides. A deck needs at least 3 slides to be useful. Would you like to restart slide selection?",
  "header": "Slide Count Warning",
  "multiSelect": false,
  "options": [
    {"label": "Yes, let me select slides again", "description": "Return to content selection"},
    {"label": "No, continue with current selection", "description": "Proceed with fewer slides"}
  ]
}
```

If "Yes": Repeat Question 3.

Store:
- `content_manifest`: Mapping of slide positions to content IDs or `NEW` markers
- `main_slides`: Slide positions for the main deck
- `appendix_slides`: Slide positions for appendix

#### Question 4: Slide Ordering (single select)

Present ordering strategies from the selected pattern:

```json
{
  "question": "Select slide ordering strategy:",
  "header": "Slide Ordering",
  "multiSelect": false,
  "options": [
    {
      "label": "YC Standard",
      "description": "Title, Problem, Solution, Traction, Why Us/Now, Business Model, Market, Team, Ask, Closing"
    },
    {
      "label": "Story-First",
      "description": "Title, Problem, Solution, Why Us/Now, Traction, Business Model, Market, Team, Ask, Closing"
    },
    {
      "label": "Traction-Led",
      "description": "Title, Traction, Problem, Solution, Why Us/Now, Market, Business Model, Team, Ask, Closing"
    }
  ]
}
```

Build options from selected pattern's `ordering_strategies`. Filter to only include slides in `main_slides`.

Store `ordering_strategy` and final `slide_order`.

**User Abandonment**: If the user cancels any AskUserQuestion interaction (empty response or explicit cancel), return with partial status:

```
Deck planning interrupted by user. No plan created.
Status remains [PLANNING]. Run /plan {N} again to restart.
```

### Stage 4.4: Prepare Enhanced Delegation Context

Bundle all user selections into the delegation context for the agent:

```json
{
  "task_context": {
    "task_number": 234,
    "project_name": "{project_name}",
    "description": "{description}",
    "task_type": "founder",
    "task_type": "deck"
  },
  "research_path": "specs/{NNN}_{SLUG}/reports/01_{short-slug}.md",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json",
  "metadata": {
    "session_id": "sess_{timestamp}_{random}",
    "delegation_depth": 2,
    "delegation_path": ["orchestrator", "plan", "skill-deck-plan"]
  },
  "user_selections": {
    "pattern": {"id": "yc-10-slide", "name": "YC 10-Slide Investor Pitch"},
    "theme": {"id": "dark-blue", "name": "Dark Blue (AI Startup)"},
    "content_manifest": {"cover": "cover-standard", "problem": "NEW", "solution": "solution-overview"},
    "main_slides": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    "appendix_slides": [11, 12],
    "ordering": "yc-standard"
  }
}
```

### Stage 5: Invoke Agent

**CRITICAL**: You MUST use the **Task** tool to spawn the agent.

**Required Tool Invocation**:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "deck-planner-agent"
  - prompt: [Include task_context, research_path, metadata_file_path, metadata, user_selections]
  - description: "Pitch deck plan generation from user-selected pattern, theme, content, and ordering"
```

The agent will:
- Parse user_selections from delegation context (no interactive questions)
- Read the deck research report for content details
- Generate plan artifact with Deck Configuration section
- Write metadata file for postflight consumption
- Return brief text summary

### Stage 5b: Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Task tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent), you MUST write a
`.return-meta.json` file now before proceeding to postflight. Use the schema from
`return-metadata-file.md` with the appropriate status value for this operation.

If you DID use the Task tool, skip this stage -- the subagent already wrote the metadata.

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 5b). Do NOT skip these stages for any reason.

### Stage 6: Read Metadata File

```bash
padded_num=$(printf "%03d" "$task_number")
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    artifact_type=$(jq -r '.artifacts[0].type // ""' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
else
    status="failed"
fi
```

### Stage 7: Postflight Status Update

If agent succeeded (status == "planned"):

```bash
# Update state.json
jq --argjson num "$task_number" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '(.active_projects[] | select(.project_number == $num)) += {
     status: "planned",
     last_updated: $ts
   }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

# Link artifact in state.json
plan_path=$(echo "$metadata" | jq -r '.artifacts[0].path')
plan_summary=$(echo "$metadata" | jq -r '.artifacts[0].summary')
jq --argjson num "$task_number" \
   --arg path "$plan_path" \
   --arg summary "$plan_summary" \
   '(.active_projects[] | select(.project_number == $num)).artifacts += [{
     type: "plan",
     path: $path,
     summary: $summary
   }]' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

Update TODO.md status marker to [PLANNED] and add Plan link.

### Stage 8: Git Commit

```bash
git add -A
git commit -m "$(cat <<'EOF'
task {N}: create implementation plan

Session: {session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

### Stage 9: Cleanup

Remove postflight markers and metadata:

```bash
rm -f "$task_dir/.postflight-pending"
rm -f "$task_dir/.postflight-loop-guard"
rm -f "$task_dir/.return-meta.json"
```

### Stage 10: Return Brief Summary

Return brief text summary to caller.

---

## Return Format

Brief text summary (NOT JSON).

Expected successful return:
```
Deck plan created for task {N}:
- Pattern: {pattern_name} ({slide_count} slides)
- Theme: {theme_name} ({color_schema})
- Main slides: {N} slides in {ordering_name} order
- Appendix: {M} slides
- Content from library: {L}, New content to create: {C}
- Content gaps: {G} identified
- Plan: specs/{NNN}_{SLUG}/plans/{NN}_{short-slug}.md
- Status updated to [PLANNED]
- Changes committed with session {session_id}
- Next: Run /implement {N} to generate the Slidev pitch deck
```

---

## Error Handling

### Session ID Missing
Return immediately with failed status.

### Task Not Found
Return error with guidance to check task number.

### Agent Errors
Pass through the agent's error return verbatim.

### User Abandonment (during AskUserQuestion)
If user cancels any interactive question, return partial status with progress made. Keep status as "planning" so the user can re-run `/plan {N}` to restart.

### All Slides Deselected (during content selection)
If user deselects all slides in Question 3, present a confirmation question offering to restart slide selection or cancel planning.
