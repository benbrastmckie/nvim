---
task_number: 285
task_name: slim_parent_claudemd
language: meta
plan_version: 1
phases: 2
estimated_effort: "30 minutes"
session_id: "sess_1774482683_962b30"
---

# Implementation Plan: Slim Parent CLAUDE.md

## Overview

Convert `~/.config/CLAUDE.md` (224 lines) to a slim pointer file (~15-20 lines), matching the pattern already established by `~/.config/.claude/CLAUDE.md` (15 lines).

## Rationale

The parent CLAUDE.md currently contains 20+ sections that are all just "See [doc link]" pointers to `.claude/docs/` files. These are already discoverable through `.claude/docs/README.md` and documented in `nvim/.claude/CLAUDE.md`. Loading 224 lines into every project under `~/.config/` wastes context.

## Phases

### Phase 1: Convert Parent CLAUDE.md [COMPLETED]

**Files**: `~/.config/CLAUDE.md`

Replace 224-line file with slim pointer (~15-20 lines):
1. Keep title and brief description
2. Point to `nvim/CLAUDE.md` for Neovim guidelines
3. Point to `.claude/CLAUDE.md` for agent system
4. Point to `.claude/docs/README.md` for standards index
5. Keep Standards Discovery section (generic, useful cross-project)

**Verification**: File is valid markdown, under 25 lines.

### Phase 2: Update Task State [COMPLETED]

**Files**: `specs/state.json`, `specs/TODO.md`

1. Update state.json: status -> "completed", add completion_summary
2. Update TODO.md: mark [COMPLETED]

**Verification**: Both files consistent.
