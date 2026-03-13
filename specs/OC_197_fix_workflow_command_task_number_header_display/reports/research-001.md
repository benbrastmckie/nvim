# Research Report: Task #197

**Task**: OC_197 - Fix workflow command task number header display
**Started**: 2025-03-13T00:00:00Z
**Completed**: 2025-03-13T00:30:00Z
**Effort**: 0.5 hours
**Dependencies**: None
**Sources/Inputs**: Codebase analysis of .opencode/commands/, .opencode/context/core/formats/
**Artifacts**: - This research report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

The workflow command header display bug is caused by missing "Display header" instructions in the preflight sections of command files.

**Key Findings:**
- The `description:` field in command frontmatter is static and doesn't include task numbers
- "Critical Notes" sections mention preflight should "Display header" but actual step instructions don't include this step
- `implement.md` is missing "Display header" even in its Critical Notes
- The command files lack explicit header display instructions with task number substitution

**Root Cause:**
The workflow commands reference "OC_NNN" placeholder in examples/pseudocode, but never explicitly display a header with the actual task number at the start of execution. OpenCode displays the static `description:` from frontmatter instead of a dynamic header.

## Context & Scope

This research investigates why workflow command headers show "OC_NNN" placeholder instead of actual task numbers like "OC_193".

**Commands Affected:**
- `/research` (`.opencode/commands/research.md`)
- `/plan` (`.opencode/commands/plan.md`)
- `/implement` (`.opencode/commands/implement.md`)

**Files Examined:**
- `.opencode/commands/research.md`
- `.opencode/commands/plan.md`
- `.opencode/commands/implement.md`
- `.opencode/context/core/formats/command-output.md`
- `.opencode/context/core/workflows/command-lifecycle.md`
- `.opencode/skills/skill-researcher/SKILL.md`
- `.opencode/skills/skill-planner/SKILL.md`

## Findings

### 1. Command File Structure

All workflow command files follow this pattern:

**Frontmatter (static description):**
```yaml
---
description: Research a task and create a research report
---
```

The description field contains static text without task number placeholders.

### 2. Preflight Section Analysis

**research.md (Line 43):**
```markdown
### 3. Execute Preflight

**CRITICAL**: Commands must execute preflight BEFORE delegating to agents...

**Update state.json to researching**:
**Update TODO.md to [RESEARCHING]**:
**Create postflight marker file**:
```

**plan.md (Line 42):**
Similar structure - updates state.json, TODO.md, creates marker file.

**implement.md (Line 51):**
Similar structure - updates state.json, TODO.md, creates marker file.

**Critical Finding:** None of the preflight sections include an explicit "Display header" step!

### 3. Critical Notes Discrepancy

**research.md Line 296:**
```markdown
1. **Preflight** (Step 4): Display header, update state.json to "researching"...
```

**plan.md Line 205:**
```markdown
1. **Preflight** (Step 4): Display header, update state.json to "planning"...
```

**implement.md Line 277:**
```markdown
1. **Preflight** (Step 4): Update state.json to "implementing"...
```

**Bug:** `implement.md` is missing "Display header" even in the Critical Notes summary!

### 4. OC_NNN Placeholder Usage

The placeholder "OC_NNN" appears in command files for:
- Directory paths: `specs/OC_NNN_<project_name>/`
- Metadata file paths: `specs/OC_NNN_<project_name>/.return-meta.json`
- Documentation examples

These are meant as placeholders in documentation/pseudocode, but the actual header display doesn't substitute them with real task numbers.

### 5. Expected Header Format

Per `.opencode/context/core/formats/command-output.md` (Line 14-34):

```
Task: {task_number}

{summary}
```

Example:
```
Task: 258

Research completed for modal logic proof automation...
```

But the workflow commands don't explicitly display this header format at the start of execution.

## Root Cause Analysis

The bug has two components:

### Component 1: Missing Header Display Step
The preflight sections in all three workflow commands (research.md, plan.md, implement.md) lack an explicit instruction to display a header with the actual task number. The "Critical Notes" sections mention that preflight should "Display header" but the actual step-by-step instructions don't include this.

### Component 2: implement.md Omission
The `implement.md` command's Critical Notes section is missing "Display header" entirely (line 277), while `research.md` and `plan.md` at least mention it in their summaries.

## Files Requiring Modification

### Primary Fix Files:
1. **`.opencode/commands/research.md`** (Line 43)
   - Add explicit "Display header" step at start of "### 3. Execute Preflight"
   - Header should show: "Researching task OC_{N}: {project_name}"

2. **`.opencode/commands/plan.md`** (Line 42)
   - Add explicit "Display header" step at start of "### 3. Execute Preflight"
   - Header should show: "Planning task OC_{N}: {project_name}"

3. **`.opencode/commands/implement.md`** (Line 51)
   - Add explicit "Display header" step at start of "### 4. Execute Preflight"
   - Header should show: "Implementing task OC_{N}: {project_name}"
   - Also update Critical Notes to include "Display header"

### Fix Pattern:
Add at the start of each preflight section:
```markdown
**Display header**:
```
Researching task OC_{N}: {project_name}
```
```

Where `{N}` is the actual task number and `{project_name}` is extracted from state.json.

## Decisions

1. **Header Format:** Use "[Action] task OC_{N}: {project_name}" format for consistency
2. **Location:** Add header display as the FIRST step in each preflight section
3. **Format:** Use code block format for visibility

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Inconsistent header formats | Low | Use standardized pattern across all three files |
| Missing task number context | Medium | Extract from state.json at start of preflight |
| Placeholder not substituted | High | Ensure actual values are used, not "OC_NNN" |

## Context Extension Recommendations

**None** - This is a straightforward bug fix that doesn't require new context documentation.

## Appendix

### Search Queries Used:
- `grep -r "OC_NNN" .opencode/ --include="*.md"` - Found placeholder usage
- `grep -r "Display header" .opencode/commands/ --include="*.md"` - Found discrepancy
- `grep -r "description:" .opencode/commands/ --include="*.md"` - Analyzed frontmatter

### Related Standards:
- `.opencode/context/core/formats/command-output.md` - Defines expected output format
- `.opencode/context/core/formats/command-structure.md` - Defines command file anatomy
- `.opencode/context/core/workflows/command-lifecycle.md` - Describes preflight pattern

### Verification Steps for Implementation:
1. After fix, run `/research OC_198` and verify header shows "Researching task OC_198: ..."
2. After fix, run `/plan OC_198` and verify header shows "Planning task OC_198: ..."
3. After fix, run `/implement OC_198` and verify header shows "Implementing task OC_198: ..."
4. Confirm "OC_NNN" placeholder no longer appears in displayed headers
