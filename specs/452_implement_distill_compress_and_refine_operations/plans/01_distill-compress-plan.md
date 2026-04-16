# Implementation Plan: Distill Compress and Refine Operations

- **Task**: 452 - Implement distill compress and refine operations
- **Status**: [IMPLEMENTING]
- **Effort**: 4 hours
- **Dependencies**: Tasks #450 (completed), #451 (completed)
- **Research Inputs**: specs/452_implement_distill_compress_and_refine_operations/reports/01_distill-compress-research.md
- **Artifacts**: plans/01_distill-compress-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Implement the final three sub-modes of the `/distill` command: compress (reduce oversized memories to key points), refine (fix metadata quality issues in two tiers), and auto (safe non-interactive maintenance). All three are currently placeholders in SKILL.md returning "not yet implemented" messages. The implementation follows the established patterns from purge (task 450) and merge (task 451): candidate identification, interactive selection via AskUserQuestion, content transformation, index regeneration, and distill-log.json logging.

### Research Integration

Key findings from the research report:
- Compress threshold should use `size_penalty > 0.5` (token_count > 900), not the raw `token_count > 600` from the task description, for consistency with the scoring engine
- The UPDATE operation's history section pattern provides the template for compress's `## History > ### Pre-Compression` section
- Refine has two tiers: automatic (keyword dedup, summary generation, topic normalization) and interactive (keyword enrichment, category reclassification, topic correction)
- Auto flag runs only Tier 1 refine fixes; compress is excluded because AI-generated summaries need human review
- Current vault has 1 memory (302 tokens), below all thresholds -- "no candidates" edge case must be handled

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items are directly advanced by this task. This is part of the memory system pipeline (tasks 444-454) which is independent of the current roadmap priorities.

## Goals & Non-Goals

**Goals**:
- Implement compress sub-mode with candidate identification, interactive selection, content compression, history preservation, and keyword preservation
- Implement refine sub-mode with Tier 1 automatic fixes and Tier 2 interactive fixes
- Implement auto flag that runs Tier 1 refine fixes non-interactively
- Update distill.md command to mark compress, refine, and auto as available
- Handle "no candidates" edge cases gracefully for all sub-modes
- Log all operations to distill-log.json with correct schema

**Non-Goals**:
- Implementing GC sub-mode (already done in task 450)
- Modifying the scoring engine or health report (task 449)
- Integrating with /todo suggestions (task 453)
- Implementing tombstone filtering in retrieval (task 453)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Compressed content loses essential information | H | M | Preserve original in History section; keyword preservation check; user reviews via AskUserQuestion |
| Refine auto-fix introduces bad data | M | L | Tier 1 only does safe operations (dedup, generation from content, normalization) |
| Empty vault yields no candidates | M | L | Edge case check before candidate identification; graceful "no candidates" message |
| Large SKILL.md file becomes unwieldy | M | L | Follow existing section structure; keep sub-mode implementations focused |
| Compression ratio too aggressive | M | M | Soft ~60% target guideline; preserve code blocks and examples verbatim |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1 |
| 4 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Compress Sub-Mode [COMPLETED]

**Goal**: Implement the compress operation in SKILL.md following established sub-mode patterns.

**Tasks**:
- [ ] Add compress sub-mode section after existing GC section in SKILL.md
- [ ] Implement candidate identification: filter non-tombstoned memories where `size_penalty > 0.5` (token_count > 900)
- [ ] Add "no candidates" early return with informative message
- [ ] Implement dry-run display showing candidates with token counts and compression estimates
- [ ] Implement AskUserQuestion multiSelect with labels: `{memory.id}` and descriptions: `Tokens: {token_count} | Size penalty: {size_penalty:.2f} | Topic: {topic} | Retrievals: {retrieval_count}`
- [ ] Implement compression execution per selected memory:
  - Read full memory content
  - Generate compressed version: extract key points as bullet list, preserve code blocks and examples verbatim, remove redundant prose
  - Move original content to `## History > ### Pre-Compression ({date})` section (before `## Connections` if present)
  - Write compressed content as main body
  - Recalculate `token_count` in frontmatter (word_count * 1.3, rounded down)
  - Update `modified` to today
  - Keyword preservation check: verify all original keywords still present
- [ ] Add batch index regeneration after all compressions (memory-index.json, index.md, 10-Memories/README.md)
- [ ] Add distill-log.json entry with `type: "compress"`, per-memory `tokens_before`, `tokens_after`, `compression_ratio`, `keywords_preserved`
- [ ] Update `total_compressed` counter in distill-log.json summary
- [ ] Update sub-mode dispatch table status from "Placeholder" to "Available" for compress

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` - Add compress sub-mode implementation section

**Verification**:
- Compress section exists in SKILL.md with complete execution flow
- Candidate identification uses `size_penalty > 0.5` threshold
- History preservation pattern matches UPDATE operation style
- Keyword preservation check is explicit
- Index regeneration follows purge/merge pattern
- Distill-log schema includes compress-specific fields

---

### Phase 2: Refine Sub-Mode [COMPLETED]

**Goal**: Implement the refine operation with Tier 1 automatic fixes and Tier 2 interactive fixes.

**Tasks**:
- [ ] Add refine sub-mode section after compress section in SKILL.md
- [ ] Implement candidate scanning: iterate all non-tombstoned memories for quality issues
- [ ] Implement "no issues found" early return with informative message
- [ ] Implement Tier 1 automatic fixes (no confirmation needed):
  - Keyword deduplication: remove duplicate keywords (case-insensitive, keep first occurrence)
  - Summary generation: for memories with empty/missing `summary`, generate from first line of content (truncate ~100 chars)
  - Topic normalization: lowercase all topic paths, ensure `/` separators, no trailing slashes
- [ ] Implement Tier 2 interactive fixes (require AskUserQuestion):
  - Keyword enrichment: for memories with < 4 keywords, suggest 3-5 additional keywords based on content
  - Category reclassification: for memories where tag-derived category may not match content, suggest alternatives
  - Topic path correction: for memories with topic paths inconsistent with cluster patterns, suggest corrections
- [ ] Implement execution flow: run Tier 1 first, then present Tier 2 candidates interactively
- [ ] Add batch index regeneration after all fixes
- [ ] Add distill-log.json entry with `type: "refine"`, per-memory `fixes_applied` list and `action: "refined"`
- [ ] Update `total_refined` counter in distill-log.json summary
- [ ] Update sub-mode dispatch table status from "Placeholder" to "Available" for refine

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` - Add refine sub-mode implementation section

**Verification**:
- Tier 1 fixes run without user interaction
- Tier 2 fixes use AskUserQuestion for selection
- All fix types (keyword dedup, summary gen, topic normalize, keyword enrich, category reclassify, topic correct) are implemented
- Index regeneration runs after all fixes
- Distill-log entry includes per-memory fix list

---

### Phase 3: Auto Flag Implementation [COMPLETED]

**Goal**: Implement the `--auto` flag that runs safe non-interactive maintenance (Tier 1 refine only).

**Tasks**:
- [ ] Add auto sub-mode section in SKILL.md (or integrate as a branch within refine flow)
- [ ] Implement auto execution flow:
  - Run validate-on-read (regenerate memory-index.json if stale)
  - Run Tier 1 refine fixes only (keyword dedup, summary generation, topic normalization)
  - Rebuild memory-index.json from filesystem state
  - Update memory_health in state.json
  - Skip all interactive operations (no AskUserQuestion calls)
- [ ] Add distill-log.json entry with `type: "refine"` and `notes: "auto mode"` to distinguish from interactive refine
- [ ] Display summary of changes made (e.g., "Deduplicated keywords in 2 memories, generated 1 summary")
- [ ] Handle "no changes needed" case gracefully
- [ ] Update sub-mode dispatch table status from "Placeholder" to "Available" for auto

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` - Add auto flag execution flow

**Verification**:
- Auto mode runs without any AskUserQuestion calls
- Only Tier 1 fixes are applied
- Compress, purge, merge are explicitly excluded
- State.json memory_health is updated
- Change summary is displayed to user
- "No changes needed" edge case handled

---

### Phase 4: Command File Updates and Validation [COMPLETED]

**Goal**: Update distill.md command to reflect availability of compress, refine, and auto sub-modes, and verify the complete implementation.

**Tasks**:
- [ ] Update distill.md `--compress` status from `[placeholder - task 452]` to available
- [ ] Update distill.md `--refine` status from `[placeholder - task 452]` to available
- [ ] Update distill.md `--auto` status from `[placeholder - task 452]` to available
- [ ] Update workflow step 1 availability table in distill.md
- [ ] Remove/update placeholder response messages for compress, refine, auto in distill.md
- [ ] Cross-reference SKILL.md dispatch table entries match distill.md availability
- [ ] Verify all three sub-modes handle the current vault state (1 memory, 302 tokens) with "no candidates" messages
- [ ] Verify distill-log.json schema supports compress and refine operation types

**Timing**: 0.5 hours

**Depends on**: 1, 2, 3

**Files to modify**:
- `.claude/extensions/memory/commands/distill.md` - Update availability status and remove placeholder messages

**Verification**:
- All three sub-modes show as available in distill.md
- Dispatch table in SKILL.md is consistent with distill.md
- No remaining "placeholder" or "not yet implemented" references for compress, refine, or auto
- Running `/distill --compress` on current vault shows "No compress candidates found"
- Running `/distill --refine` on current vault shows "No issues found" or applies any applicable Tier 1 fixes
- Running `/distill --auto` on current vault completes without errors

## Testing & Validation

- [ ] Verify compress candidate identification uses `size_penalty > 0.5` threshold correctly
- [ ] Verify compress preserves original content in `## History > ### Pre-Compression` section
- [ ] Verify compress preserves all original keywords after compression
- [ ] Verify compress recalculates token_count correctly
- [ ] Verify refine Tier 1 fixes run without user interaction
- [ ] Verify refine Tier 2 fixes present AskUserQuestion
- [ ] Verify auto mode skips all interactive operations
- [ ] Verify auto mode excludes compress, purge, and merge
- [ ] Verify distill-log.json entries have correct schema for compress and refine types
- [ ] Verify "no candidates" edge case is handled for all three sub-modes
- [ ] Verify index regeneration runs after operations in all sub-modes
- [ ] Verify state.json memory_health is updated after auto mode

## Artifacts & Outputs

- `specs/452_implement_distill_compress_and_refine_operations/plans/01_distill-compress-plan.md` (this file)
- `specs/452_implement_distill_compress_and_refine_operations/summaries/01_distill-compress-summary.md` (post-implementation)
- Modified: `.claude/extensions/memory/skills/skill-memory/SKILL.md`
- Modified: `.claude/extensions/memory/commands/distill.md`

## Rollback/Contingency

All changes are confined to two files within the memory extension. Rollback via `git checkout` of:
- `.claude/extensions/memory/skills/skill-memory/SKILL.md`
- `.claude/extensions/memory/commands/distill.md`

No database migrations, no external service changes, no configuration file format changes. The distill-log.json schema already supports compress and refine types (defined in task 449), so no schema migration is needed.
