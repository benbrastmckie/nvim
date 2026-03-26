# Implementation Plan: Fix Stale context/core/ References

## Task 293 - Plan

### Overview

Fix 3 stale `context/core/` path references in `.claude/docs/guides/context-loading-best-practices.md`. These are bash commands in diagnostic examples that still use the old `context/core/` path from before the task 288 flatten.

### Phase 1: Fix Stale References [NOT STARTED]

**Target file**: `.claude/docs/guides/context-loading-best-practices.md`

**Changes** (3 edits, all `find` commands):

1. **Line ~772**: Change `find .claude/context/core -name "*.md"` to `find .claude/context -name "*.md"`
2. **Line ~826**: Same fix
3. **Line ~854**: Same fix

**Verification**: After edits, confirm no remaining `context/core` references in the file:
```bash
grep -n "context/core" .claude/docs/guides/context-loading-best-practices.md
```

### Risk Assessment

- **Risk**: None. These are example commands in documentation, not executed code.
- **Rollback**: Git revert.
