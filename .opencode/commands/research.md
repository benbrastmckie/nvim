---
description: Research a task and create a research report
---

Research the given task and write a research report. Do NOT implement anything.

**Input**: $ARGUMENTS

---

## Parse Input

- First token: task number — accepts `OC_N` or `N` (strip `OC_` prefix to get integer N)
- `--remember` flag: include memory vault search in research context
- Remaining tokens: optional focus prompt
- If invalid: "Usage: /research <OC_N> [--remember] [focus]"

---

## Steps

### 1. Look up task

Strip `OC_` prefix, find task in `specs/state.json`:
```bash
jq --arg n "N" '.active_projects[] | select(.project_number == ($n | tonumber))' specs/state.json
```
If not found: "Task OC_N not found in state.json"

Extract: `language`, `status`, `project_name`, `description`

Zero-pad N to 3 digits for paths: `NNN` (e.g. 174 → 174, keep as-is if already ≥3 digits... use printf "%03d")

Directory: `specs/OC_NNN_<project_name>/`

### 2. Validate status

- `not_started`, `partial`, `researched`: proceed
- `researching`: warn "already researching, proceeding anyway"
- `abandoned`: error "task is abandoned, use /task --recover first"
- `completed`: warn "already completed, re-researching"

### 3. Display task header

The skill displays a visual header during its Preflight stage to show the active task:

```
╔══════════════════════════════════════════════════════════╗
║  Task OC_N: <project_name>                               ║
║  Action: RESEARCHING                                     ║
╚══════════════════════════════════════════════════════════╝
```

This header appears at the start of the research command (after validation, before delegation) to clearly indicate which task is being worked on. The header is displayed by the skill-researcher before invoking the general-research-agent subagent.

### 4. Execute Preflight

**CRITICAL**: Commands must execute preflight BEFORE delegating to agents. The skill tool only loads skill definitions but does NOT execute workflows.

**Display task header**:
```
╔══════════════════════════════════════════════════════════╗
║  Task OC_N: <project_name>                               ║
║  Action: RESEARCHING                                     ║
╚══════════════════════════════════════════════════════════╝
```

**Update state.json to researching**:
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "researching" \
  '(.active_projects[] | select(.project_number == N)) |= . + {
    status: $status,
    last_updated: $ts,
    researching: $ts
  }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

**Update TODO.md to [RESEARCHING]**:
- Edit file: `specs/TODO.md`
- Find line: `- **Status**: [NOT STARTED]` (or current status) for task OC_N
- Change to: `- **Status**: [RESEARCHING]`

**Create postflight marker file**:
```bash
touch "specs/OC_NNN_<project_name>/.postflight-pending"
```

### 5. Memory Search (if --remember flag present)

If `--remember` was passed in arguments:

**Build search query**:
- Extract keywords from task description
- Add focus prompt keywords if provided
- Limit to 3-5 most significant terms

**Query memory vault**:
- Use MCP tool: `search_notes`
- Query: extracted keywords
- Limit: 5 results

**Process results**:
- If results found: Read full content of top 3 memories
- If no results: Note "No relevant memories found"

**Include in research context**:
- Add "## Prior Knowledge from Memory Vault" section to research report
- Include memory summaries (truncated to 1000 chars each)
- List memory IDs for reference
- Mark report as "memory_augmented: true"

**Graceful degradation**:
- If MCP unavailable: Skip memory search, continue with standard research
- If no memories found: Note in report, continue

### 6. Delegate to Research Agent

**Call skill tool** to load skill context and delegate to research agent:

```
→ Tool: skill
→ Name: skill-researcher
→ Prompt: Research task {N} with language {language} and focus {focus}. Include memory context: {memory_results}
```

The skill-researcher will:
1. Load context files (report-format.md, status-markers.md)
2. **Call Task tool with `subagent_type="general-research-agent"`** (or specialized agent based on language)
3. Return results (subagent writes .return-meta.json)

**CRITICAL**: The skill tool ONLY loads skill definitions. It does NOT execute preflight/postflight workflows. This command MUST execute status updates before and after delegation.

**Research strategy** (handled by agent based on language):
- **meta**: Focus on existing `.opencode/` files, conventions, patterns
- **lean**: Search codebase for existing proofs, check Lean/Mathlib patterns
- **typst/latex**: Read existing documents, check style and structure
- **general**: Web search + codebase exploration

### 7. Execute Postflight

**CRITICAL**: Commands must execute postflight AFTER agents return. The skill tool does NOT execute workflows.

**Step 7a: Read metadata file**:
```bash
metadata_file="specs/OC_NNN_<project_name>/.return-meta.json"
if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    artifact_type=$(jq -r '.artifacts[0].type // ""' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
fi
```

**Step 7b: Update state.json to researched**:
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "researched" \
  '(.active_projects[] | select(.project_number == N)) |= . + {
    status: $status,
    last_updated: $ts,
    researched: $ts
  }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

**Step 7c: Update TODO.md**:
- Edit file: `specs/TODO.md`
- Find line: `- **Status**: [RESEARCHING]` for task OC_N
- Change to: `- **Status**: [RESEARCHED]`

**Step 7d: Link artifacts in state.json**:
```bash
# Step 1: Filter out existing research artifacts
jq '(.active_projects[] | select(.project_number == N)).artifacts =
    [(.active_projects[] | select(.project_number == N)).artifacts // [] | .[] | select(.type == "research" | not)]' \
  specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json

# Step 2: Add new research artifact
jq --arg path "$artifact_path" \
   --arg type "$artifact_type" \
   --arg summary "$artifact_summary" \
  '(.active_projects[] | select(.project_number == N)).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
  specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

**Step 7e: Add artifact to TODO.md**:
- Edit file: `specs/TODO.md`
- Find "Artifacts" section for task OC_N
- Add line: `- [$artifact_path]($artifact_path) - $artifact_summary`

**Step 7f: Git commit**:
```bash
git add -A
git commit -m "task N: complete research

Session: ${session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

**Step 7g: Cleanup**:
```bash
rm -f "specs/OC_NNN_<project_name>/.postflight-pending"
rm -f "specs/OC_NNN_<project_name>/.postflight-loop-guard"
rm -f "specs/OC_NNN_<project_name>/.return-meta.json"
```

### 8. Report results

Show a brief summary:
- Task researched
- Key findings (3-5 bullets)
- Report path
- Next step: `/plan OC_N`

---

## Rules

- This command executes preflight (status → researching) BEFORE delegating to skill-researcher
- This command executes postflight (status → researched, link artifacts) AFTER skill-researcher returns
- The skill-researcher only loads context and delegates to general-research-agent — it does NOT execute workflows
- Write the report BEFORE updating status to RESEARCHED
- Never fabricate findings — only report what you actually discovered
- Keep the report focused and actionable
- Directories use 3-digit padded number: `OC_174_slug` not `OC_17_slug`
- Commit changes after completing research (non-blocking — log warning if commit fails)

## Critical Notes

**The skill tool only loads SKILL.md content — it does NOT execute preflight/postflight workflows.**

Commands must execute these workflows themselves:
1. **Preflight** (Step 4): Display header, update state.json to "researching", TODO.md to [RESEARCHING], create marker file
2. **Memory Search** (Step 5): Search memory vault if --remember flag present
3. **Delegation** (Step 6): Call skill-researcher to load context and invoke general-research-agent
4. **Postflight** (Step 7): Read .return-meta.json, update state.json to "researched", update TODO.md to [RESEARCHED], link artifacts, commit, cleanup

This pattern ensures status updates happen automatically without orchestrator intervention.
