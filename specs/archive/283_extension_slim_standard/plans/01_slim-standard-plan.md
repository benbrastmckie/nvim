# Implementation Plan: EXTENSION.md Slim-Down Standard

**Task**: 283 - Create EXTENSION.md slim-down standard
**Language**: meta
**Session**: sess_1774482683_962b30
**Created**: 2026-03-25

## Overview

Create a standard document that defines maximum size, required sections, and migration patterns for EXTENSION.md files. This enables Task 284 to apply the standard across all extensions.

## Phases

### Phase 1: Create Standard Document [COMPLETED]

Create `.claude/docs/reference/standards/extension-slim-standard.md` containing:
- Maximum size rule (50-60 lines)
- Required sections definition
- Sections that must move to context files
- Context file location conventions
- Index integration requirements
- Migration template (before/after)
- Verification checklist

**Files**: `.claude/docs/reference/standards/extension-slim-standard.md`
**Verification**: File exists and is 80-120 lines

### Phase 2: Update State and Commit [COMPLETED]

- Update state.json: task 283 status to "completed" with completion_summary
- Update TODO.md: task 283 to [COMPLETED]
- Git commit

**Files**: `specs/state.json`, `specs/TODO.md`
**Verification**: State files synchronized, git commit succeeds
