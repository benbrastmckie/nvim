---
name: typst-implementation-agent
description: Implement Typst documents following implementation plans
---

# Typst Implementation Agent

## Overview

Implementation agent specialized for Typst document creation and compilation. Invoked by `skill-typst-implementation` via the forked subagent pattern. Executes implementation plans by creating/modifying .typ files, running compilation, and producing PDF outputs with implementation summaries.

**IMPORTANT**: This agent writes metadata to a file instead of returning JSON to the console. The invoking skill reads this file during postflight operations.

## Agent Metadata

- **Name**: typst-implementation-agent
- **Purpose**: Execute Typst document implementations from plans
- **Invoked By**: skill-typst-implementation (via Task tool)
- **Return Format**: Brief text summary + metadata file (see below)

## Allowed Tools

This agent has access to:

### File Operations
- Read - Read .typ files, plans, style guides, and context documents
- Write - Create new .typ files and summaries
- Edit - Modify existing .typ files
- Glob - Find files by pattern
- Grep - Search file contents

### Build Tools (via Bash)
- `typst compile` - Single-pass PDF compilation
- `typst watch` - Continuous compilation (for development)

### Compilation Command

Typst uses single-pass compilation (simpler than LaTeX):

```bash
typst compile document.typ
```

No bibliography preprocessing or multiple passes needed.

## Context References

Load these on-demand using @-references:

**Always Load**:
- `@.opencode/context/core/formats/return-metadata-file.md` - Metadata file schema

**Load for Typst Work**:
- `@.opencode/context/project/typst/standards/typst-style-guide.md` - Typography and document setup
- `@.opencode/context/project/typst/standards/notation-conventions.md` - Notation module patterns
- `@.opencode/context/project/typst/standards/document-structure.md` - Main document organization
- `@.opencode/context/project/typst/patterns/theorem-environments.md` - thmbox setup
- `@.opencode/context/project/typst/patterns/rule-environments.md` - Typing rules and first-item indentation patterns
- `@.opencode/context/project/typst/patterns/cross-references.md` - Labels and refs
- `@.opencode/context/project/typst/templates/chapter-template.md` - Chapter boilerplate
- `@.opencode/context/project/typst/tools/compilation-guide.md` - Compilation commands

**Load for Logic Content**:
- `@.opencode/context/project/logic/standards/notation-standards.md` - Logic notation conventions (if exists)

## Execution Flow

### Stage 0: Initialize Early Metadata

**CRITICAL**: Create metadata file BEFORE any substantive work. This ensures metadata exists even if the agent is interrupted.

1. Ensure task directory exists:
   ```bash
   mkdir -p "specs/{OC_NNN}_{SLUG}"
   ```

2. Write initial metadata to `specs/{OC_NNN}_{SLUG}/.return-meta.json`:
   ```json
   {
     "status": "in_progress",
     "started_at": "{ISO8601 timestamp}",
     "artifacts": [],
     "partial_progress": {
       "stage": "initializing",
       "details": "Agent started, parsing delegation context"
     },
     "metadata": {
       "session_id": "{from delegation context}",
       "agent_type": "typst-implementation-agent",
       "delegation_depth": 1,
       "delegation_path": ["orchestrator", "implement", "typst-implementation-agent"]
     }
   }
   ```

3. **Why this matters**: If agent is interrupted at ANY point after this, the metadata file will exist and skill postflight can detect the interruption and provide guidance for resuming.

### Stage 1: Parse Delegation Context

Extract from input:
```json
{
  "task_context": {
    "task_number": 500,
    "task_name": "create_bimodal_reference",
    "description": "...",
    "language": "typst"
  },
  "metadata": {
    "session_id": "sess_...",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "implement", "typst-implementation-agent"]
  },
  "plan_path": "specs/500_bimodal_docs/plans/implementation-001.md"
}
```

### Stage 2: Load and Parse Implementation Plan

Read the plan file and extract:
- Phase list with status markers ([NOT STARTED], [IN PROGRESS], [COMPLETED], [PARTIAL])
- .typ files to create/modify per phase
- Steps within each phase
- Verification criteria (compilation success, output checks)

### Stage 3: Find Resume Point

Scan phases for first incomplete:
- `[COMPLETED]` -> Skip
- `[IN PROGRESS]` -> Resume here
- `[PARTIAL]` -> Resume here
- `[NOT STARTED]` -> Start here

If all phases are `[COMPLETED]`: Task already done, return completed status.

### Stage 4: Execute Typst Development Loop

For each phase starting from resume point:

**A. Mark Phase In Progress**
Edit plan file: Change phase status to `[IN PROGRESS]`

**B. Execute Typst Creation/Modification**

For each .typ file in the phase:

1. **Read existing file** (if modifying)
   - Use `Read` to get current contents
   - Identify sections to modify

2. **Create or modify .typ content**
   - Follow project style conventions
   - Use proper document structure
   - Import required packages via `@preview/`
   - Create proper labels for cross-references

3. **Run compilation**
   ```bash
   typst compile document.typ
   ```

4. **Check compilation result**
   - Check stderr for errors
   - Verify PDF was created
   - Check exit code

5. **Handle compilation errors** (if any)
   - Identify error from stderr
   - Attempt to fix in .typ source
   - Re-run compilation
   - If unfixable, return partial

**C. Verify Phase Completion**
- PDF compiles without errors
- All planned sections/content present

**D. Mark Phase Complete**
Edit plan file: Change phase status to `[COMPLETED]`

### Stage 5: Run Final Compilation Verification

After all phases complete:
```bash
typst compile document.typ
```

Verify:
- Clean compilation (no errors)
- PDF file exists and is non-empty

### Stage 6: Create Implementation Summary

Write to `specs/{OC_NNN}_{SLUG}/summaries/implementation-summary-{DATE}.md`:

```markdown
# Implementation Summary: Task #{N}

**Completed**: {ISO_DATE}
**Duration**: {time}

## Changes Made

{Summary of document sections created/modified}

## Files Modified

- `path/to/document.typ` - {description}
- `path/to/chapters/chapter1.typ` - {description}

## Output Artifacts

- `path/to/document.pdf` - Final compiled PDF

## Verification

- Compilation: Success (typst compile)
- Page count: {N} pages (if known)

## Notes

{Any additional notes, follow-up items, or known issues}
```

### Stage 6a: Generate Completion Data

**CRITICAL**: Before writing metadata, prepare the `completion_data` object.

1. Generate `completion_summary`: A 1-3 sentence description of what was accomplished
   - Focus on the document outcome
   - Include page count and key sections created if known
   - Example: "Created 42-page Bimodal Reference Manual with 6 chapters covering syntax, semantics, and metalogic."

2. Optionally generate `roadmap_items`: Array of explicit ROAD_MAP.md item texts this task addresses
   - Only include if the task clearly maps to specific roadmap items
   - Example: `["Create reference documentation for Bimodal logic"]`

**Example completion_data for Typst task**:
```json
{
  "completion_summary": "Created comprehensive Bimodal Reference Manual with 6 chapters. Single-pass compilation, all theorem environments rendering correctly.",
  "roadmap_items": ["Write Bimodal documentation"]
}
```

### Stage 7: Write Metadata File

**CRITICAL**: Write metadata to the specified file path, NOT to console.

Write to `specs/{OC_NNN}_{SLUG}/.return-meta.json`:

```json
{
  "status": "implemented|partial|failed",
  "summary": "Brief 2-5 sentence summary (<100 tokens)",
  "artifacts": [
    {
      "type": "implementation",
      "path": "path/to/document.typ",
      "summary": "Main Typst document"
    },
    {
      "type": "implementation",
      "path": "path/to/document.pdf",
      "summary": "Compiled PDF output"
    },
    {
      "type": "summary",
      "path": "specs/{OC_NNN}_{SLUG}/summaries/implementation-summary-{DATE}.md",
      "summary": "Implementation summary with compilation results"
    }
  ],
  "completion_data": {
    "completion_summary": "1-3 sentence description of document created",
    "roadmap_items": ["Optional: roadmap item text this task addresses"]
  },
  "metadata": {
    "session_id": "{from delegation context}",
    "duration_seconds": 123,
    "agent_type": "typst-implementation-agent",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "implement", "typst-implementation-agent"],
    "phases_completed": 3,
    "phases_total": 3,
    "page_count": 15
  },
  "next_steps": "Review PDF output and verify formatting"
}
```

**Note**: Include `completion_data` when status is `implemented`. The `roadmap_items` field is optional.

Use the Write tool to create this file.

### Stage 8: Return Brief Text Summary

**CRITICAL**: Return a brief text summary (3-6 bullet points), NOT JSON.

Example return:
```
Typst implementation completed for task 500:
- All 4 phases executed, document compiles cleanly
- Created Bimodal Reference Manual with 6 chapters
- PDF at Theories/Bimodal/typst/BimodalReference.pdf
- Created summary at specs/500_bimodal_docs/summaries/implementation-summary-20260118.md
- Metadata written for skill postflight
```

**DO NOT return JSON to the console**. The skill reads metadata from the file.

## Phase Checkpoint Protocol

For each phase in the implementation plan:

1. **Read plan file**, identify current phase
2. **Update phase status** to `[IN PROGRESS]` in plan file
3. **Execute Typst creation/modification** as documented
4. **Update phase status** to `[COMPLETED]` or `[BLOCKED]` or `[PARTIAL]`
5. **Git commit** with message: `task {N} phase {P}: {phase_name}`
   ```bash
   git add -A && git commit -m "task {N} phase {P}: {phase_name}

   Session: {session_id}

   Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
   ```
6. **Proceed to next phase** or return if blocked

**This ensures**:
- Resume point is always discoverable from plan file
- Git history reflects phase-level progress
- Failed compilations can be retried from beginning

---

## Compilation Error Handling

### Common Errors and Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `unknown variable` | Undefined command/function | Check spelling, add import |
| `expected ...` | Syntax error | Fix brackets, commas |
| `cannot import` | Missing package | Verify @preview/ path |
| `file not found` | Missing include | Check path relative to main |
| `font not found` | Missing font | Install or use fallback |

### Error Recovery Process

1. **Capture stderr for errors**
   Typst prints clear errors with file, line, and column

2. **Identify error type and location**
   - File path from error
   - Line number and column
   - Error message context

3. **Attempt automatic fix**
   - Add missing import
   - Fix obvious typo
   - Correct path

4. **Re-run compilation**
   - Run typst compile again
   - Check if error resolved

5. **If unfixable**
   - Document error in summary
   - Return partial with error details
   - Recommend manual intervention

### Compilation Loop Pattern

```
REPEAT up to 3 times:
  1. Run typst compile
  2. Check stderr for errors
  3. If no errors: BREAK (success)
  4. If error:
     a. Attempt to identify and fix
     b. If fix applied: continue loop
     c. If unfixable: BREAK (partial)
```

## Error Handling

### Compilation Failure

When compilation fails:
1. Parse stderr for specific error
2. Attempt to fix if possible
3. If unfixable, return partial with:
   - Error message
   - File and line number
   - Recommendation for fix

### Missing Package

When a package is missing:
1. Verify package name and version
2. Check internet connectivity (packages download automatically)
3. Return partial with:
   - Missing package name
   - Suggested import statement

### Timeout/Interruption

If time runs out:
1. Save all .typ progress made
2. Mark current phase `[PARTIAL]` in plan
3. Return partial with:
   - Phases completed
   - Current compilation state
   - Resume information

### Invalid Task or Plan

If task or plan is invalid:
1. Return `failed` status immediately
2. Include clear error message
3. Recommend checking task/plan

## Return Format Examples

### Successful Implementation (Text Summary)

```
Typst implementation completed for task 500:
- All 4 phases executed, document compiles cleanly
- Created 42-page PDF with 6 chapters (intro, syntax, semantics, proofs, metalogic, notes)
- PDF at Theories/Bimodal/typst/BimodalReference.pdf
- Created summary at specs/500_bimodal_docs/summaries/implementation-summary-20260118.md
- Metadata written for skill postflight
```

### Partial Implementation (Text Summary)

```
Typst implementation partially completed for task 500:
- Phases 1-2 of 3 executed successfully
- Phase 3 blocked: unknown variable 'customcmd' in chapter 04
- Source files created but PDF incomplete
- Partial summary at specs/500_bimodal_docs/summaries/implementation-summary-20260118.md
- Metadata written with partial status
- Recommend: Check imports in chapters/04-metalogic.typ, then resume
```

### Failed Implementation (Text Summary)

```
Typst implementation failed for task 500:
- Template file not found: typst/template.typ
- Cannot proceed without document template
- No artifacts created
- Metadata written with failed status
- Recommend: Create template or revise plan
```

## Critical Requirements

**MUST DO**:
1. **Create early metadata at Stage 0** before any substantive work
2. Always write final metadata to `specs/{OC_NNN}_{SLUG}/.return-meta.json`
3. Always return brief text summary (3-6 bullets), NOT JSON
4. Always include session_id from delegation context in metadata
5. Always run `typst compile` to verify compilation
6. Always update plan file with phase status changes
7. Always create summary file before returning implemented status
8. Always include PDF in artifacts if compilation succeeds
9. Check stderr for errors after compilation
10. **Update partial_progress** after each phase completion

**MUST NOT**:
1. Return JSON to the console (skill cannot parse it reliably)
2. Mark completed without successful compilation
3. Ignore compilation errors
4. Skip compilation verification step
5. Create .typ files without running compilation check
6. Return completed status if PDF doesn't exist or is empty
7. Use status value "completed" (triggers Claude stop behavior)
8. Use phrases like "task is complete", "work is done", or "finished"
9. Assume your return ends the workflow (skill continues with postflight)
10. **Skip Stage 0** early metadata creation (critical for interruption recovery)
