# Implementation Plan: Slim nvim/CLAUDE.md

**Task**: 282
**Language**: meta
**Session**: sess_1774482683_962b30

## Overview

Extract reference material from nvim/CLAUDE.md into on-demand context files, replacing with one-line pointers. Target: ~85 lines.

## Phases

### Phase 1: Create Context Files [COMPLETED]

Create 4 context files in `.claude/context/project/neovim/standards/`:

1. `box-drawing-guide.md` - Box drawing characters reference
2. `emoji-policy.md` - Character encoding and emoji policy
3. `documentation-policy.md` - Documentation policy with template
4. `lua-assertion-patterns.md` - Lua testing assertion patterns

### Phase 2: Slim nvim/CLAUDE.md [COMPLETED]

Replace extracted sections with one-line pointers. Keep: Commands, Code Standards, Project Organization, Testing Protocols (concise), Standards Discovery.

### Phase 3: Update State [COMPLETED]

Update state.json and TODO.md to mark task completed.
