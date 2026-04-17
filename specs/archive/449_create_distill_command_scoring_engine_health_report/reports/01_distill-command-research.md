# Research Report: Task #449

**Task**: 449 - Create /distill command with scoring engine and health report
**Started**: 2026-04-16T21:00:00Z
**Completed**: 2026-04-16T21:15:00Z
**Effort**: large
**Dependencies**: Task #444 (completed)
**Sources/Inputs**: Codebase exploration (memory extension, command files, state.json schema, SKILL.md)
**Artifacts**: specs/449_create_distill_command_scoring_engine_health_report/reports/01_distill-command-research.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The memory extension at `.claude/extensions/memory/` provides skill-memory with four modes (text, file, directory, task); a new `mode=distill` section must be added to SKILL.md
- The `/distill` command file should follow the established pattern: YAML frontmatter, argument parsing, workflow delegation to skill-memory with `mode=distill`
- The scoring engine has four components (staleness, zero-retrieval, size, duplicate) with well-defined formulas already specified in the task description
- `memory-index.json` (created by task 444) provides the machine-queryable data source for all scoring; validate-on-read must precede scoring
- `memory_health` is a new top-level field in state.json, sibling to `repository_health`
- `distill-log.json` lives at `.memory/distill-log.json` within the vault directory structure

## Context & Scope

This task creates the foundation for all distillation operations. Tasks 450-453 depend on this foundation to implement purge, combine, compress, and refine operations. The research focused on understanding existing infrastructure to determine where each new component fits.

### Files to Create

| File | Purpose |
|------|---------|
| `.claude/commands/distill.md` | Command file with argument parsing and skill delegation |
| `.memory/distill-log.json` | Operation log for all distill actions |

### Files to Modify

| File | Change |
|------|--------|
| `.claude/extensions/memory/skills/skill-memory/SKILL.md` | Add `mode=distill` section with scoring engine and health report |
| `specs/state.json` | Add `memory_health` top-level field |
| `.claude/extensions/memory/manifest.json` | Add `distill.md` to `provides.commands` |
| `.claude/extensions/memory/EXTENSION.md` | Add `/distill` to command reference |
| `.claude/extensions/memory/index-entries.json` | Add distill-related context entry |

## Findings

### 1. Memory Extension Structure

The memory extension at `.claude/extensions/memory/` has this structure:

```
.claude/extensions/memory/
  manifest.json         -- declares task_type "memory", commands ["learn.md"], skills ["skill-memory"]
  EXTENSION.md          -- section merged into .claude/CLAUDE.md
  README.md             -- extension documentation
  index-entries.json    -- context entries merged into .claude/context/index.json
  commands/learn.md     -- /learn command file (Layer 2)
  skills/skill-memory/SKILL.md  -- direct-execution skill with 4 modes
  context/project/memory/       -- domain context files
  data/.memory/                 -- vault directory template
```

**Key finding**: The manifest currently declares only `["learn.md"]` in `provides.commands`. A new `distill.md` command must be added here. The routing section in manifest.json maps `memory` task type to `skill-memory` for both research and implementation -- distill will use the same skill but with `mode=distill`.

### 2. Command File Structure Pattern

Analyzed `/research`, `/learn`, and `/todo` commands. The established pattern is:

```markdown
---
description: Short description
allowed-tools: Tool1, Tool2, ...
argument-hint: ARGS [--flags]
model: opus
---

# /command-name Command

## Arguments
- Flag definitions with defaults

## Execution
### CHECKPOINT / STAGE pattern
  1. Parse arguments
  2. Delegate to skill
  3. Postflight validation
  4. Git commit

## Error Handling
```

**For /distill specifically**:
- Layer 2 command file (argument parsing, delegates to skill)
- `allowed-tools`: `Skill, Bash(jq:*), Read, Edit, AskUserQuestion`
- The `/learn` command provides the closest template since it also delegates to skill-memory
- No checkpoint gates needed (unlike /research) since this is a standalone maintenance command
- Simpler structure: parse flags -> delegate to skill-memory mode=distill -> present results -> git commit

### 3. Scoring Engine Design

The task description specifies four scoring components. Research confirmed the data sources are all available in `memory-index.json`:

**Data Fields Available per Entry** (from memory-index.json schema):

| Field | Scoring Use |
|-------|-------------|
| `created` | Calculate days_since_created |
| `modified` | Supplementary age signal |
| `last_retrieved` | Calculate days_since_last_retrieval (null = never) |
| `retrieval_count` | Zero-retrieval penalty, FSRS adjustment |
| `token_count` | Size penalty |
| `keywords` | Duplicate/overlap scoring |

**Scoring Formulas** (as specified in task):

1. **Staleness**: `min(1.0, days_since_last_retrieval / 90)` with FSRS adjustment: `if retrieval_count > 0 AND days_since_created > 60: staleness -= 0.3` (clamped to 0)
2. **Zero-retrieval penalty**: `1.0` if `retrieval_count == 0 AND days_since_created > 30`, else `0.0`
3. **Size penalty**: `max(0, (token_count - 600) / 600)` (linear above 600 tokens)
4. **Duplicate score**: Highest keyword overlap with any other memory (Jaccard-like: `|A intersect B| / |A|`)
5. **Composite**: `(staleness * 0.3) + (zero_retrieval * 0.25) + (size * 0.2) + (duplicate * 0.25)` clamped 0-1

**Implementation note**: Duplicate scoring requires pairwise comparison of all memory keyword sets. For N memories, this is O(N^2) but N is expected to be small (< 100). The SKILL.md already defines overlap scoring for memory search (the 60%/30% thresholds); the same algorithm should be reused.

**Topic-cluster grouping**: Group by topic prefix (first path segment, e.g., `neovim/plugins/telescope` -> cluster `neovim`). Score within clusters first, then produce aggregate.

### 4. Health Report Format

The health report is the output of bare `/distill` (no flags). Based on the task description and existing output patterns in the codebase:

```
Memory Vault Health Report
==========================

Overview:
  Total memories: {N}
  Total tokens: {N}
  Average tokens/memory: {N}

Category Distribution:
  PATTERN:    {N} ({pct}%)
  CONFIG:     {N} ({pct}%)
  WORKFLOW:   {N} ({pct}%)
  TECHNIQUE:  {N} ({pct}%)
  INSIGHT:    {N} ({pct}%)

Topic Clusters:
  {topic}: {N} memories
  ...

Retrieval Statistics:
  Retrieved at least once: {N} ({pct}%)
  Never retrieved: {N} ({pct}%)
  Most retrieved: MEM-{slug} ({count} times)
  Least retrieved: MEM-{slug} ({count} times)

Maintenance Candidates:
  Purge candidates (zero-retrieval > 30d): {N}
  Merge candidates (overlap > 60%):        {N}
  Compress candidates (> 600 tokens):       {N}

Health Score: {score}/100 ({status})

Formula: 100 - (purge * 3) - (merge * 5) - (compress * 2), clamped [0, 100]
```

**Health status thresholds** (to align with repository_health pattern):
- 80-100: `healthy`
- 60-79: `manageable`
- 40-59: `concerning`
- 0-39: `critical`

### 5. Distill-Log Schema

Location: `.memory/distill-log.json` (inside vault, gittracked with .memory/)

```json
{
  "version": 1,
  "operations": [
    {
      "timestamp": "ISO8601",
      "session_id": "sess_...",
      "operation": "purge|merge|compress|refine|report",
      "memories_affected": ["MEM-slug-1", "MEM-slug-2"],
      "details": {},
      "pre_metrics": {
        "total_memories": 0,
        "total_tokens": 0,
        "health_score": 100
      },
      "post_metrics": {
        "total_memories": 0,
        "total_tokens": 0,
        "health_score": 100
      }
    }
  ],
  "summary": {
    "total_operations": 0,
    "last_distilled": null,
    "memories_purged": 0,
    "memories_merged": 0,
    "memories_compressed": 0,
    "memories_refined": 0
  }
}
```

**Design note**: The `operations` array provides an append-only audit log. The `summary` provides O(1) access to aggregate counts. Both are updated on each operation. The `report` operation type logs health report generation (bare `/distill`) for tracking when the vault was last assessed.

### 6. state.json memory_health Field

The field should be a top-level sibling of `repository_health`, following the same pattern:

```json
{
  "version": "1.0.0",
  "next_project_number": 456,
  "active_projects": [...],
  "repository_health": {
    "last_assessed": "ISO8601",
    "status": "healthy"
  },
  "memory_health": {
    "last_distilled": null,
    "distill_count": 0,
    "total_memories": 1,
    "never_retrieved": 1,
    "health_score": 100,
    "status": "healthy"
  },
  "vault_count": 0,
  "vault_history": []
}
```

**Placement rationale**: Top-level field parallel to `repository_health` because:
- Both are system-wide health metrics (not per-task)
- Both have `status` fields with the same vocabulary (healthy/manageable/concerning/critical)
- Both are updated by maintenance commands (/review for repo, /distill for memory)
- Consistent with the existing schema pattern in state-management-schema.md

**Update trigger**: `memory_health` is updated after every `/distill` invocation (including bare report). Only `distill_count` and `last_distilled` are incremented for non-bare invocations that perform actual operations.

### 7. Validate-on-Read Requirement

SKILL.md already defines a validate-on-read pattern for memory-index.json (added by task 444). The distill scoring engine MUST run this validation before scoring:

1. List all MEM-*.md files in `.memory/10-Memories/`
2. Compare against entries in memory-index.json
3. If stale: regenerate index before proceeding
4. If valid: proceed with scoring

This ensures scoring operates on accurate data even if memories were manually edited.

### 8. Skill-Memory SKILL.md Integration

The SKILL.md currently has these execution modes:

| Mode | Description |
|------|-------------|
| `text` | Add text as memory |
| `file` | Add file as memory |
| `directory` | Scan directory |
| `task` | Review task artifacts |

A new `distill` mode will be added with sub-modes mapped from flags:

| Sub-mode | Flag | Task |
|----------|------|------|
| `report` | bare (no flags) | 449 (this task) |
| `purge` | `--purge` | 450 |
| `merge` | `--merge` | 451 |
| `compress` | `--compress` | 452 |
| `refine` | `--auto` | 452 |
| `gc` | `--gc` | 450 |

For this task (449), only `report` sub-mode is implemented. The scoring engine is shared infrastructure used by all sub-modes.

## Decisions

1. **Command file location**: `.claude/commands/distill.md` (not inside the extension commands/ directory) -- consistent with how /learn is placed in `.claude/extensions/memory/commands/learn.md`. Actually, following the /learn pattern, distill.md should go in `.claude/extensions/memory/commands/distill.md`.
2. **Scoring in SKILL.md, not separate file**: The scoring engine lives inside skill-memory's SKILL.md as a `mode=distill` section, consistent with how all other modes are documented there.
3. **Health status thresholds**: Reuse the same vocabulary as repository_health (healthy/manageable/concerning/critical) for consistency.
4. **Distill-log location**: `.memory/distill-log.json` lives in the vault root, tracked by git alongside memory files.
5. **memory_health as top-level field**: Parallel to repository_health, not nested inside it.

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| memory-index.json stale during scoring | Incorrect scores | Mandatory validate-on-read before scoring |
| Pairwise keyword comparison slow with many memories | Slow health report | N expected < 100; O(N^2) acceptable; can optimize later |
| Distill-log grows unbounded | File bloat | Can add log rotation in future; low priority with < 100 operations expected |
| state.json schema change breaks existing consumers | Parse failures | memory_health is additive (new field); no existing consumers affected |

## Appendix

### Search Queries Used

1. `Glob .claude/extensions/memory/**/*` -- Extension file structure
2. `Read SKILL.md` -- Existing skill modes, scoring patterns, index maintenance
3. `Read learn.md` -- Command file structure pattern
4. `Read manifest.json` -- Extension declaration, routing
5. `Read memory-index.json` -- Index schema from task 444
6. `Read research.md` -- Command checkpoint pattern
7. `Read state.json` -- Current schema, repository_health placement
8. `Read state-management-schema.md` -- Full schema reference
9. `Read TODO.md` (grep for 449-453) -- Full task descriptions for dependency chain
10. `Read memory-template.md` -- Frontmatter fields available for scoring

### Downstream Task Dependencies

```
449 (this task) -- scoring engine, health report, command, distill-log, memory_health
  |
  +-- 450 (purge + tombstone + --gc)
  |
  +-- 451 (combine/merge + keyword superset)
       |
       +-- 452 (compress + refine + --auto)
            |
            +-- 453 (integrate with /todo + tombstone filtering)
                 |
                 +-- 454 (end-to-end validation)
```
