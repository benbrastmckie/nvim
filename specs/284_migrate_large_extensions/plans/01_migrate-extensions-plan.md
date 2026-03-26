# Implementation Plan: Migrate Large Extensions to Slim Pattern

**Task**: 284
**Language**: meta
**Created**: 2026-03-25

## Overview

Migrate 5 large EXTENSION.md files to comply with the slim standard (max 60 lines). Extract detailed documentation to context files, keeping only routing tables, command lists, and context pointers.

## Phases

### Phase 1: Migrate Founder Extension [COMPLETED]

**Target**: `.claude/extensions/founder/EXTENSION.md` (234 -> ~55 lines)

Extract to context files:
- `context/project/founder/domain/workflow-reference.md` - Pre-task forcing questions, unified phased workflow, input types, forcing data storage, key patterns, output locations
- `context/project/founder/domain/migration-guide.md` - Breaking changes from v2.x, migration from v2.1/v2.0/v1.0

Keep in EXTENSION.md:
- Header with description
- Skill-Agent Mapping table (7 rows)
- Commands table (10 rows)
- Language routing table (condensed)
- Context pointers

### Phase 2: Migrate Present Extension [COMPLETED]

**Target**: `.claude/extensions/present/EXTENSION.md` (216 -> ~55 lines)

Extract to context files:
- `context/project/present/domain/grant-workflow.md` - Detailed command usage (task creation, draft, budget, revise, legacy modes), recommended workflow, grant output directory, revision workflow, grant writing components
- `context/project/present/domain/deck-workflow.md` - Deck generation workflow, key components

Keep in EXTENSION.md:
- Header with description
- Skill-Agent Mapping table (grant + deck)
- Commands table (/grant, /deck)
- Language routing tables (grant, deck)
- Context pointers

### Phase 3: Migrate Filetypes Extension [COMPLETED]

**Target**: `.claude/extensions/filetypes/EXTENSION.md` (143 -> ~45 lines)

Extract to context files:
- `context/project/filetypes/domain/conversion-tables.md` - All supported conversion tables (document, spreadsheet, presentation, PDF annotation)
- Already has dependency-guide.md in context

Keep in EXTENSION.md:
- Header with description
- Skill-Agent Mapping table
- Commands table (/convert, /table, /slides, /scrape)
- Context pointers

### Phase 4: Migrate Memory Extension [COMPLETED]

**Target**: `.claude/extensions/memory/EXTENSION.md` (91 -> ~40 lines)

Extract to context files:
- `context/project/memory/domain/memory-reference.md` - MCP integration details, vault structure, memory classification, memory operations, topic organization

Keep in EXTENSION.md:
- Header with description
- Skill-Agent Mapping table
- Commands table (/learn)
- Memory-augmented research note
- Context pointers

### Phase 5: Migrate Web Extension [COMPLETED]

**Target**: `.claude/extensions/web/EXTENSION.md` (80 -> ~40 lines)

Extract to context files:
- `context/project/web/domain/web-reference.md` - Key technologies details, build verification commands, context categories, deployment version tracking

Keep in EXTENSION.md:
- Header with description
- Skill-Agent Mapping table
- Commands table (/tag)
- Language routing table
- Context pointers

### Phase 6: Update Index Entries and Verify [COMPLETED]

- Add new context files to each extension's index-entries.json
- Verify all 5 EXTENSION.md files are under 60 lines
- Verify no routing information was lost

## Verification

- [ ] All 5 EXTENSION.md files under 60 lines
- [ ] All routing tables preserved
- [ ] All command lists preserved
- [ ] Context files created with extracted content
- [ ] Index entries updated for new context files
