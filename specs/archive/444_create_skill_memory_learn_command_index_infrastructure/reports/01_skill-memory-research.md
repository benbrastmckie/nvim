# Research Report: Task #444

**Task**: 444 - Create skill-memory, /learn command, and memory index infrastructure
**Started**: 2026-04-16T12:00:00Z
**Completed**: 2026-04-16T12:15:00Z
**Effort**: Medium (research only)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `.memory/` vault structure (all files)
- Codebase: `.claude/extensions/memory/` (manifest, SKILL.md, learn.md, context files)
- Codebase: `.claude/skills/` (skill-researcher, skill-meta, skill-todo, skill-status-sync patterns)
- Codebase: `.claude/commands/` (research.md, plan.md, task.md patterns)
- Codebase: `.claude/context/index.json` (entry structure)
- Codebase: `.claude/context/formats/return-metadata-file.md`
- Codebase: `specs/ROADMAP.md`
**Artifacts**:
- `specs/444_create_skill_memory_learn_command_index_infrastructure/reports/01_skill-memory-research.md`
**Standards**: report-format.md, return-metadata-file.md

## Executive Summary

- The memory extension **already exists** at `.claude/extensions/memory/` with a fully specified `skill-memory/SKILL.md`, `commands/learn.md`, README, EXTENSION.md, manifest.json, context files, and index entries
- The `.memory/` vault structure is in place with 4 directories (00-Inbox, 10-Memories, 20-Indices, 30-Templates) and 1 existing memory file (MEM-plan-delegation-required.md)
- What is **missing** from the task description: `memory-index.json` (machine-queryable index), template frontmatter fields (retrieval_count, last_retrieved, keywords, summary), and backfilling of existing memories
- The task description assumes skill-memory and /learn need to be created from scratch, but they already exist in the extension -- the implementation should focus on the **additive gaps** only
- The /learn command exists in the extension at `.claude/extensions/memory/commands/learn.md` but is **not** in `.claude/commands/` (main commands directory); extension commands are loaded via the extension picker

## Context & Scope

The task description specifies creating foundational memory infrastructure: skill-memory, /learn command, memory-index.json, template updates, and backfilling. Research reveals that substantial infrastructure already exists within the memory extension. This report identifies what exists, what is missing, and recommends the implementation approach.

### Roadmap Context

The ROADMAP.md does not have explicit memory system items. This task is standalone infrastructure work.

## Findings

### Existing Memory Extension Infrastructure

The memory extension at `.claude/extensions/memory/` provides:

- **manifest.json**: Declares task_type "memory", routing for research/plan/implement, merge_targets for CLAUDE.md and index.json, MCP server config for Obsidian REST API
- **skills/skill-memory/SKILL.md**: 848-line comprehensive skill definition with 4 execution modes (text, file, directory, task), content mapping pipeline, memory search (MCP + grep fallback), overlap scoring (UPDATE/EXTEND/CREATE at 60%/30% thresholds), index maintenance, slug generation, git commit postflight
- **commands/learn.md**: 287-line command file with argument parsing (4-mode priority chain), delegation to skill-memory, error handling, state management
- **skills/skill-memory/README.md**: Brief skill overview
- **EXTENSION.md**: Extension description for CLAUDE.md merging
- **context/project/memory/**: 5 context files (learn-usage.md, memory-setup.md, knowledge-capture-usage.md, memory-troubleshooting.md, domain/memory-reference.md)
- **index-entries.json**: 5 entries for context discovery
- **data/.memory/**: Scaffold for the vault structure (templates, indices, inbox)

### Existing .memory/ Vault State

- `00-Inbox/`: Empty (README only)
- `10-Memories/`: 1 file -- `MEM-plan-delegation-required.md`
  - Frontmatter fields: title, created, tags (array), topic, source, modified
  - Missing fields per task spec: retrieval_count, last_retrieved, keywords, summary
- `20-Indices/`: `index.md` with empty "By Category" and "Statistics: Total memories: 0"
- `30-Templates/`: `memory-template.md` with Obsidian template syntax ({{title}}, {{date}}, etc.)
  - Template fields: title, created, tags, topic, source, modified
  - Missing fields per task spec: retrieval_count, last_retrieved, keywords, summary
- `.obsidian/`: Obsidian configuration (gitignored)
- `README.md`: Comprehensive vault documentation

### What the Task Description Asks For vs. What Exists

| Requested | Status | Location |
|-----------|--------|----------|
| skill-memory SKILL.md | EXISTS | `.claude/extensions/memory/skills/skill-memory/SKILL.md` |
| skill-memory README.md | EXISTS | `.claude/extensions/memory/skills/skill-memory/README.md` |
| /learn command | EXISTS | `.claude/extensions/memory/commands/learn.md` |
| memory-index.json | MISSING | Should be `.memory/memory-index.json` |
| Template update (new fields) | MISSING | `.memory/30-Templates/memory-template.md` needs new fields |
| Backfill existing memories | MISSING | `MEM-plan-delegation-required.md` needs new frontmatter |
| Update index.md | PARTIAL | Exists but shows 0 memories (stale) |

### Skill SKILL.md Patterns

Existing skills follow two patterns:

**Thin Wrapper Skills** (skill-researcher, skill-meta): Delegate to a subagent. YAML frontmatter with name, description, allowed-tools. Context references as lazy @-paths. Implement skill-internal postflight.

**Direct Execution Skills** (skill-todo, skill-status-sync, skill-memory): Execute inline without subagent. Same frontmatter pattern. Detailed stage-by-stage execution flow.

The existing skill-memory is a direct execution skill -- the most complete in the codebase at 848 lines.

### Command File Patterns

Commands use YAML frontmatter with description, allowed-tools, argument-hint, model. They follow a checkpoint-based lifecycle: GATE IN -> DELEGATE -> GATE OUT -> COMMIT. The /learn command follows a simpler pattern (no checkpoint gates) since it delegates directly to skill-memory.

### Memory Index Schema Design

The task requests a machine-queryable `memory-index.json` with schema:

```json
{
  "version": "1.0.0",
  "generated_at": "ISO8601",
  "entry_count": 1,
  "total_tokens": 0,
  "entries": [
    {
      "id": "MEM-plan-delegation-required",
      "path": "10-Memories/MEM-plan-delegation-required.md",
      "title": "Artifact Creation Must Use Skill Delegation",
      "summary": "",
      "topic": "agent-system",
      "category": "enforcement",
      "keywords": [],
      "token_count": 0,
      "created": "2026-04-13",
      "modified": "2026-04-13",
      "last_retrieved": null,
      "retrieval_count": 0
    }
  ]
}
```

This parallels `.claude/context/index.json` but is memory-specific. The `load_when` semantics from context/index.json do not apply; instead, keyword-based search drives retrieval.

### Context Index Entry Structure

Entries in `.claude/context/index.json` follow this pattern:

```json
{
  "path": "relative/path.md",
  "domain": "core",
  "subdomain": "category",
  "summary": "Description",
  "line_count": 100,
  "keywords": ["key1", "key2"],
  "topics": ["topic1"],
  "load_when": {
    "agents": ["agent-name"],
    "task_types": ["type"],
    "commands": ["/command"]
  }
}
```

The memory extension's `index-entries.json` provides 5 entries that get merged into the main index. No new entries are needed for this task since the existing entries already cover skill-memory and /learn contexts.

## Decisions

- **Do NOT recreate** skill-memory or /learn command -- they already exist in the extension and are comprehensive
- **Focus implementation** on the three genuinely missing pieces: memory-index.json, template field additions, and backfilling
- **Place memory-index.json** in `.memory/` (the vault root), consistent with the existing vault structure
- **Update template** to add retrieval_count, last_retrieved, keywords, summary as specified
- **Backfill** the single existing memory (MEM-plan-delegation-required.md) with new fields extracted from its content
- **Update index.md** to reflect actual memory count (1, not 0)
- **Consider updating SKILL.md** to add index regeneration operations that produce memory-index.json (currently SKILL.md only regenerates index.md)

## Recommendations

### Implementation Approach

1. **Phase 1: Template and Schema** (small)
   - Add retrieval_count, last_retrieved, keywords, summary to `.memory/30-Templates/memory-template.md`
   - Create `.memory/memory-index.json` with schema and initial entry for MEM-plan-delegation-required

2. **Phase 2: Backfill** (small)
   - Update `MEM-plan-delegation-required.md` frontmatter with new fields
   - Update `.memory/20-Indices/index.md` to reflect accurate counts and entries
   - Update `.memory/10-Memories/README.md` with file listing

3. **Phase 3: Skill Enhancement** (medium)
   - Add memory-index.json regeneration to skill-memory's Index Maintenance section
   - Ensure all CREATE/UPDATE/EXTEND operations update memory-index.json alongside index.md
   - Add validate-on-read pattern for memory-index.json

4. **Phase 4: Verification** (small)
   - Validate all files are consistent
   - Verify frontmatter fields match schema

### Files to Create

| File | Description |
|------|-------------|
| `.memory/memory-index.json` | Machine-queryable memory index |

### Files to Modify

| File | Change |
|------|--------|
| `.memory/30-Templates/memory-template.md` | Add retrieval_count, last_retrieved, keywords, summary fields |
| `.memory/10-Memories/MEM-plan-delegation-required.md` | Add new frontmatter fields |
| `.memory/20-Indices/index.md` | Update counts and entries to reflect actual state |
| `.memory/10-Memories/README.md` | Add file listing for MEM-plan-delegation-required |
| `.claude/extensions/memory/skills/skill-memory/SKILL.md` | Add memory-index.json regeneration to Index Maintenance section |

### Files NOT to Create (Already Exist)

| File | Location |
|------|----------|
| skill-memory SKILL.md | `.claude/extensions/memory/skills/skill-memory/SKILL.md` |
| skill-memory README.md | `.claude/extensions/memory/skills/skill-memory/README.md` |
| /learn command | `.claude/extensions/memory/commands/learn.md` |

## Risks & Mitigations

- **Risk**: Task description assumes files need creation from scratch, but they exist. The planner must reconcile the task description with actual codebase state.
  - **Mitigation**: This research report clearly documents what exists vs. what is missing. The plan should focus on the delta.
- **Risk**: Modifying SKILL.md (848 lines) to add memory-index.json support could introduce inconsistencies.
  - **Mitigation**: Add a new clearly delimited section for JSON index generation rather than modifying existing index.md regeneration logic.
- **Risk**: Template changes (adding fields) could break Obsidian template rendering.
  - **Mitigation**: Use standard YAML frontmatter syntax consistent with existing fields. Obsidian handles unknown frontmatter fields gracefully.

## Appendix

### Search Queries Used

- `find .memory/ -type f` -- vault structure discovery
- `find .claude/extensions/memory/ -type f` -- extension file discovery
- Grep for "memory" across `.claude/` -- cross-reference discovery
- Read of 3 skill SKILL.md files (researcher, meta, todo) for pattern analysis
- Read of 3 command files (research.md, plan.md, task.md) for format analysis
- Read of context/index.json for entry schema

### Key File Paths

- Extension root: `.claude/extensions/memory/`
- Skill definition: `.claude/extensions/memory/skills/skill-memory/SKILL.md`
- Command definition: `.claude/extensions/memory/commands/learn.md`
- Vault root: `.memory/`
- Existing memory: `.memory/10-Memories/MEM-plan-delegation-required.md`
- Template: `.memory/30-Templates/memory-template.md`
- Markdown index: `.memory/20-Indices/index.md`
