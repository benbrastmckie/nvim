# Implementation Plan: Task #444

- **Task**: 444 - Create skill-memory with /learn command and memory index infrastructure
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/444_create_skill_memory_learn_command_index_infrastructure/reports/01_skill-memory-research.md
- **Artifacts**: plans/01_skill-memory-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Research reveals that skill-memory SKILL.md, README.md, and the /learn command already exist in the memory extension at `.claude/extensions/memory/`. The implementation focuses on the genuinely missing pieces: creating `memory-index.json` (machine-queryable index), adding retrieval-tracking frontmatter fields to the memory template, backfilling the single existing memory file, updating the markdown index, and enhancing SKILL.md with JSON index regeneration logic. This is additive work on top of existing infrastructure, significantly reducing scope from the original task description.

### Research Integration

Key findings from the research report:
- skill-memory SKILL.md (848 lines), README.md, and /learn command all exist in `.claude/extensions/memory/`
- The `.memory/` vault has 4 directories with 1 existing memory (`MEM-plan-delegation-required.md`)
- Missing pieces: `memory-index.json`, template fields (`retrieval_count`, `last_retrieved`, `keywords`, `summary`), backfilling, SKILL.md enhancement for JSON index ops
- The existing Index Maintenance section in SKILL.md only covers `index.md` regeneration, not JSON index

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly correspond to memory system work. This task is standalone infrastructure that enables the memory system task chain (tasks 444-454).

## Goals & Non-Goals

**Goals**:
- Create `memory-index.json` with proper schema and initial entry for the existing memory
- Add retrieval-tracking fields to the memory template (`retrieval_count`, `last_retrieved`, `keywords`, `summary`)
- Backfill `MEM-plan-delegation-required.md` with the new frontmatter fields
- Update `index.md` to reflect accurate vault state (1 memory, not 0)
- Enhance SKILL.md with JSON index regeneration logic alongside existing markdown index logic
- Ensure downstream tasks (445, 449) have the `memory-index.json` they depend on

**Non-Goals**:
- Recreating skill-memory or /learn command (they already exist)
- Implementing two-phase auto-retrieval (task 445)
- Building the /distill command (task 449)
- Modifying extension manifest or command routing
- Adding new context index entries (existing 5 entries are sufficient)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| SKILL.md edit introduces inconsistency in 848-line file | M | M | Add a clearly delimited new section for JSON index; do not modify existing index.md logic |
| Template field changes break Obsidian rendering | L | L | Obsidian handles unknown YAML frontmatter gracefully; use standard syntax |
| memory-index.json schema diverges from downstream task expectations | H | L | Schema matches exactly what task 445 specifies for two-phase retrieval scoring |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Template and Schema Foundation [COMPLETED]

**Goal**: Establish the updated template with retrieval-tracking fields and create the memory-index.json schema with initial data.

**Tasks**:
- [ ] Update `.memory/30-Templates/memory-template.md` to add `retrieval_count: 0`, `last_retrieved: null`, `keywords: []`, `summary: ""` fields to frontmatter
- [ ] Backfill `.memory/10-Memories/MEM-plan-delegation-required.md` with new frontmatter fields: `retrieval_count: 0`, `last_retrieved: null`, `keywords` extracted from existing tags (`enforcement`, `delegation`, `bypass-prevention`, `artifacts`, `plans`), `summary` from first content sentence, `token_count` computed from word count * 1.3
- [ ] Create `.memory/memory-index.json` with version 1.0.0 schema containing the single existing memory entry (id, path, title, summary, topic, category, keywords, token_count, created, modified, last_retrieved, retrieval_count)
- [ ] Update `.memory/20-Indices/index.md` to reflect 1 memory (not 0), add entry under "By Category" for enforcement, update "Recent Memories" with MEM-plan-delegation-required, and document the new JSON index

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.memory/30-Templates/memory-template.md` - Add retrieval_count, last_retrieved, keywords, summary fields
- `.memory/10-Memories/MEM-plan-delegation-required.md` - Backfill with new frontmatter fields
- `.memory/20-Indices/index.md` - Update counts, categories, recent memories, document JSON index

**Files to create**:
- `.memory/memory-index.json` - Machine-queryable memory index with initial entry

**Verification**:
- Template contains all 10 frontmatter fields (title, created, tags, topic, source, modified, retrieval_count, last_retrieved, keywords, summary)
- MEM-plan-delegation-required.md has all new fields with correct values
- memory-index.json is valid JSON with version, generated_at, entry_count=1, entries array
- index.md shows "Total memories: 1" and lists the existing memory

---

### Phase 2: SKILL.md JSON Index Enhancement [COMPLETED]

**Goal**: Add memory-index.json regeneration logic to the existing skill-memory SKILL.md so that all CREATE/UPDATE/EXTEND operations maintain both index.md and memory-index.json.

**Tasks**:
- [ ] Add a new "### JSON Index Maintenance" subsection after the existing "### Index Regeneration Pattern" section in SKILL.md
- [ ] Define the JSON index regeneration procedure: scan `MEM-*.md` files, extract frontmatter, compute token_count, build entries array, write `memory-index.json` with version/generated_at/entry_count/total_tokens metadata
- [ ] Update the existing "### Index Maintenance" section header comment to note that both index.md AND memory-index.json must be updated after each operation
- [ ] Add a "### Validate-on-Read" subsection describing the mismatch detection pattern: before using the index, check all listed files exist and no unlisted `MEM-*.md` files are present; if mismatch, regenerate
- [ ] Update Context References section to add `@.memory/memory-index.json` as a lazy reference

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` - Add JSON Index Maintenance section, Validate-on-Read section, update Index Maintenance header, add context reference

**Verification**:
- SKILL.md contains "JSON Index Maintenance" section with regeneration procedure
- SKILL.md contains "Validate-on-Read" section with mismatch detection logic
- Index Maintenance section references both index.md and memory-index.json
- Context References includes memory-index.json path

---

### Phase 3: Validation and Consistency Check [COMPLETED]

**Goal**: Verify all files are internally consistent, frontmatter matches the JSON index, and the memory system is ready for downstream tasks (445, 449).

**Tasks**:
- [ ] Read memory-index.json and verify its entry matches MEM-plan-delegation-required.md frontmatter exactly (title, topic, keywords, created, modified, token_count)
- [ ] Verify template fields are a superset of MEM-plan-delegation-required.md fields
- [ ] Verify SKILL.md JSON index regeneration procedure would produce the same memory-index.json if run against current vault state
- [ ] Verify index.md statistics match memory-index.json entry_count
- [ ] Fix any inconsistencies found during validation

**Timing**: 0.5 hours

**Depends on**: 2

**Files to modify**:
- Any files with inconsistencies found during validation

**Verification**:
- All frontmatter fields in MEM-plan-delegation-required.md match memory-index.json entry
- Template has all fields that appear in the memory entry
- index.md count matches memory-index.json entry_count
- No validation errors remain

## Testing & Validation

- [ ] memory-index.json is valid JSON (parseable by jq)
- [ ] memory-index.json entry_count matches actual MEM-*.md file count in 10-Memories/
- [ ] MEM-plan-delegation-required.md frontmatter includes all required fields
- [ ] Template includes all fields present in memory entries
- [ ] SKILL.md includes JSON index regeneration procedure
- [ ] SKILL.md includes validate-on-read pattern
- [ ] index.md statistics are accurate

## Artifacts & Outputs

- `.memory/memory-index.json` - New machine-queryable memory index
- `.memory/30-Templates/memory-template.md` - Updated template with retrieval-tracking fields
- `.memory/10-Memories/MEM-plan-delegation-required.md` - Backfilled with new frontmatter
- `.memory/20-Indices/index.md` - Updated with accurate counts and JSON index documentation
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` - Enhanced with JSON index regeneration and validate-on-read

## Rollback/Contingency

All changes are additive (new fields, new file, new SKILL.md sections). Rollback strategy:
- Delete `.memory/memory-index.json` to remove the JSON index
- Revert frontmatter additions in MEM-plan-delegation-required.md and template via git
- Revert SKILL.md additions via git
- No existing functionality is removed or modified, so partial rollback is safe
