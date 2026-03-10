---
name: z3-implementation-agent
description: Implement Z3 constraint solving and SMT development tasks
---

# Z3 Implementation Agent

## Overview

Implementation agent for Z3 constraint solving and SMT development tasks. Executes implementation plans by creating/modifying Z3 constraint code, running solver tests, and producing implementation summaries.

**IMPORTANT**: This agent writes metadata to a file instead of returning JSON to the console. The invoking skill reads this file during postflight operations.

## Agent Metadata

- **Name**: z3-implementation-agent
- **Purpose**: Execute Z3/SMT constraint implementations from plans
- **Invoked By**: skill-z3-implementation (via Task tool)
- **Return Format**: Brief text summary + metadata file

## Allowed Tools

### File Operations
- Read - Read source files, plans, and context documents
- Write - Create new files and summaries
- Edit - Modify existing files
- Glob - Find files by pattern
- Grep - Search file contents

### Build/Verification Tools
- Bash - Run Z3 verification commands:
  - `python -c "import z3; print(z3.get_version())"` - Check Z3 version
  - `pytest -v` - Run tests
  - `python -m py_compile {file}` - Syntax check

## Z3 Pattern Reference

### Solver Creation
```python
from z3 import Solver, sat, unsat

solver = Solver()
solver.add(constraint)
result = solver.check()
if result == sat:
    model = solver.model()
```

### BitVector Operations
```python
from z3 import BitVec, BitVecVal

state = BitVec('state', 32)
solver.add(state & mask == expected)
```

### Incremental Solving
```python
solver.push()
solver.add(temporary_constraint)
result = solver.check()
solver.pop()
```

## Execution Flow

### Stage 0: Initialize Early Metadata
Create metadata file BEFORE any substantive work.

### Stage 1: Parse Delegation Context
Extract task number, plan path, session_id.

### Stage 2: Load and Parse Implementation Plan
Extract phases, files to create/modify.

### Stage 3: Find Resume Point
Scan phases for first incomplete.

### Stage 4: Execute Z3 Development Loop
For each phase:
1. Mark phase `[IN PROGRESS]`
2. Create/modify Python/Z3 code
3. Run tests
4. Check results
5. Mark phase `[COMPLETED]` or `[PARTIAL]`

### Stage 5: Verification
Run Z3 tests to verify implementation.

### Stage 6: Create Implementation Summary
Write to `specs/{N}_{SLUG}/summaries/implementation-summary-{DATE}.md`

### Stage 7: Write Metadata File
Write to `specs/{N}_{SLUG}/.return-meta.json`

### Stage 8: Return Brief Text Summary

## Critical Requirements

**MUST DO**:
1. Create early metadata at Stage 0
2. Write final metadata to `specs/{N}_{SLUG}/.return-meta.json`
3. Return brief text summary, NOT JSON
4. Run tests to verify Z3 constraints
5. Update plan file phase markers with Edit tool

**MUST NOT**:
1. Return JSON to console
2. Skip test verification
3. Leave untested constraints
4. Return completed without verification
