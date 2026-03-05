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

### 4. Update status to RESEARCHING

Edit `specs/state.json`: set `status` to `"researching"` and update `last_updated` for this task.

Edit `specs/TODO.md`: change `[NOT STARTED]` (or current status marker) to `[RESEARCHING]` on the `### OC_N.` entry.

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

### 6. Execute research

Based on `language`:
- **meta**: Focus on existing `.opencode/` files, conventions, patterns
- **lean**: Search codebase for existing proofs, check Lean/Mathlib patterns
- **typst/latex**: Read existing documents, check style and structure
- **general**: Web search + codebase exploration

Research strategy (always in this order):
1. Read task description carefully — understand what needs to be built
2. Explore codebase: use Glob/Grep/Read to find related files and patterns
3. Read relevant context files in `.opencode/context/` if applicable
4. Web search for external best practices if needed
5. Synthesize findings into actionable recommendations

If a focus prompt was given, prioritize that aspect.

### 7. Write research report

Create directory: `mkdir -p specs/OC_NNN_<project_name>/reports/`

Write `specs/OC_NNN_<project_name>/reports/research-001.md`:

```markdown
# Research Report: Task #N

**Task**: OC_N - <title>
**Date**: YYYY-MM-DD
**Language**: <language>
**Focus**: <focus or "general">

## Summary

<2-3 sentence overview of findings and recommended approach>

## Findings

### <Topic 1>
<Details>

### <Topic 2>
<Details>

## Prior Knowledge from Memory Vault

*This section appears when --remember flag is used and relevant memories are found*

**Relevant Memories**:
- **MEM-YYYY-MM-DD-001**: Title (truncated content summary)
- **MEM-YYYY-MM-DD-002**: Title (truncated content summary)

**Memory-Augmented**: true

## Recommendations

1. <Actionable recommendation>
2. <Actionable recommendation>

## Risks & Considerations

- <Risk or consideration>

## Next Steps

Run `/plan OC_N` to create an implementation plan.
```

### 8. Update status to RESEARCHED

Edit `specs/state.json`:
- Set `status` to `"researched"`
- Update `last_updated`
- Add to `artifacts` array:
```json
{
  "type": "research",
  "path": "specs/OC_NNN_<project_name>/reports/research-001.md",
  "summary": "<one sentence>"
}
```

Edit `specs/TODO.md` on the `### OC_N.` entry:
- Change `[RESEARCHING]` to `[RESEARCHED]`
- Add line: `- **Research**: [research-001.md](OC_NNN_<project_name>/reports/research-001.md)`

### 9. Commit changes

Create a targeted commit with only the changed files:

```bash
# Generate session ID
session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"

# Get list of changed files
git status --porcelain | awk '{print $NF}' > /tmp/changed_files_$$.txt
changed_files=$(cat /tmp/changed_files_$$.txt | tr '\n' ' ')

# Commit if there are changes
if [ -n "$changed_files" ]; then
    git add $changed_files
    git commit -m "task OC_${N}: complete research

Session: ${session_id}

Co-Authored-By: OpenCode <noreply@opencode.ai>" || echo "Warning: Commit failed but research completed"
fi

# Cleanup
rm -f /tmp/changed_files_$$.txt
```

**Files committed**:
- `specs/OC_NNN_<project_name>/reports/research-001.md` - Research report
- `specs/state.json` - Status and artifact updates
- `specs/TODO.md` - Status marker and research link

**Error handling**: Commit failures are non-blocking. Log a warning and continue.

### 9. Report to user

Show a brief summary:
- Task researched
- Key findings (3-5 bullets)
- Report path
- Next step: `/plan OC_N`

---

## Rules

- Write the report BEFORE updating status to RESEARCHED
- Never fabricate findings — only report what you actually discovered
- Keep the report focused and actionable
- Directories use 3-digit padded number: `OC_174_slug` not `OC_17_slug`
- Commit changes after completing research (non-blocking — log warning if commit fails)
