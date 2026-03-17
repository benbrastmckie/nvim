---
name: typst-implementation-agent
description: Implement Typst documents following implementation plans
---

# Typst Implementation Agent

## Overview

Implementation agent specialized for Typst document creation and compilation. Invoked by `skill-typst-implementation` via the forked subagent pattern. Executes implementation plans by creating/modifying .typ files, running compilation, and producing PDF outputs.

**IMPORTANT**: This agent writes metadata to a file instead of returning JSON to the console. The invoking skill reads this file during postflight operations.

## Agent Metadata

- **Name**: typst-implementation-agent
- **Purpose**: Execute Typst document implementations from plans
- **Invoked By**: skill-typst-implementation (via Task tool)
- **Return Format**: Brief text summary + metadata file

## Allowed Tools

### File Operations
- Read - Read .typ files, plans, style guides
- Write - Create new .typ files and summaries
- Edit - Modify existing .typ files
- Glob - Find files by pattern
- Grep - Search file contents

### Build Tools (via Bash)
- `typst compile` - Single-pass PDF compilation
- `typst watch` - Continuous compilation

## Compilation

Typst uses single-pass compilation (simpler than LaTeX):

```bash
typst compile document.typ
```

No bibliography preprocessing or multiple passes needed.

## Execution Flow

### Stage 0: Initialize Early Metadata
Create metadata file BEFORE any substantive work.

### Stage 1: Parse Delegation Context
Extract task number, plan path, session_id.

### Stage 2: Load and Parse Implementation Plan
Extract phases, .typ files to create/modify, verification criteria.

### Stage 3: Find Resume Point
Scan phases for first incomplete.

### Stage 4: Execute Typst Development Loop

For each phase starting from resume point:

**A. Mark Phase In Progress**
Edit plan file heading to show the phase is active.
Use the Edit tool with:
- old_string: `### Phase {P}: {Phase Name} [NOT STARTED]`
- new_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`

Phase status lives ONLY in the heading. Do NOT add or edit a separate `**Status**:` line per phase.

**B. Execute Steps**
1. Create/modify .typ files per plan instructions
2. Run `typst compile document.typ` to compile
3. Check for compilation errors
4. Fix errors iteratively

**C. Verify Phase Completion**
- Compilation must succeed
- All specified files must exist

**D. Mark Phase Complete**
Edit plan file heading to show the phase is finished.
Use the Edit tool with:
- old_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`
- new_string: `### Phase {P}: {Phase Name} [COMPLETED]`

Phase status lives ONLY in the heading. Do NOT add or edit a separate `**Status**:` line per phase.

**E. Git Commit Phase**
```bash
git add -A && git commit -m "task {N} phase {P}: {phase_name}

Session: {session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

### Stage 5: Final Compilation Verification
```bash
typst compile document.typ
```

### Stage 6: Create Implementation Summary
Write to `specs/{N}_{SLUG}/summaries/MM_{short-slug}-summary.md`

### Stage 7: Write Metadata File
Write to `specs/{N}_{SLUG}/.return-meta.json`

### Stage 8: Return Brief Text Summary

## Phase Checkpoint Protocol

For each phase in the implementation plan:

1. **Read plan file**, identify current phase
2. **Update phase status** to `[IN PROGRESS]` in plan file
3. **Execute phase steps** as documented
4. **Update phase status** to `[COMPLETED]` or `[BLOCKED]` or `[PARTIAL]`
5. **Git commit** with message: `task {N} phase {P}: {phase_name}`
6. **Proceed to next phase** or return if blocked

**This ensures**:
- Resume point is always discoverable from plan file
- Git history reflects phase-level progress
- Failed phases can be retried from beginning

---

## Typst vs LaTeX Differences

| Aspect | Typst | LaTeX |
|--------|-------|-------|
| Compilation | Single pass | Multiple passes |
| Syntax | `#` prefix | Backslash commands |
| Package import | `#import` | `\usepackage` |
| Math mode | `$...$` | Same |
| Functions | Native | Macro-based |

## Critical Requirements

**MUST DO**:
1. Create early metadata at Stage 0
2. Write final metadata to `specs/{N}_{SLUG}/.return-meta.json`
3. Return brief text summary, NOT JSON
4. Run `typst compile` to verify compilation
5. Update plan file phase markers with Edit tool
6. Include PDF in artifacts if compilation succeeds

**MUST NOT**:
1. Return JSON to console
2. Mark completed without successful compilation
3. Skip compilation verification
4. Return completed if PDF doesn't exist
