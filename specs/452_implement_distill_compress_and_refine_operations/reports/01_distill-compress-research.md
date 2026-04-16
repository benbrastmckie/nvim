# Research Report: Task #452

**Task**: 452 - Implement distill compress and refine operations
**Started**: 2026-04-16T22:00:00Z
**Completed**: 2026-04-16T22:30:00Z
**Effort**: large
**Dependencies**: Tasks #450 (completed), #451 (completed)
**Sources/Inputs**: Codebase exploration (SKILL.md, distill.md, memory-index.json, memory files, distill-log.json, TODO.md, prior task reports/plans)
**Artifacts**: specs/452_implement_distill_compress_and_refine_operations/reports/01_distill-compress-research.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Three sub-modes need implementation in SKILL.md: `compress`, `refine`, and `auto`. All three are currently placeholders that return "not yet implemented" messages.
- The compress operation targets memories with `size_penalty > 0.5` (token_count > 600), following the same interactive pattern as purge/merge: candidate identification, AskUserQuestion multiSelect, content transformation, index regeneration, distill-log.json logging.
- The refine operation has two tiers: automatic fixes (keyword dedup, summary generation, topic normalization) that run without confirmation, and interactive fixes (keyword enrichment, category reclassification, topic correction) that require user selection.
- The `--auto` flag runs refine automatic fixes only, rebuilds memory-index.json, updates state.json, and skips all interactive operations. It does NOT run compress (which always requires user review of AI-generated summaries).
- The vault currently has 1 memory (302 tokens), which is below the 600-token compress threshold. Implementation must handle the "no candidates" edge case gracefully.
- All supporting infrastructure exists: scoring engine with size_penalty component, distill-log.json schema with compress/refine types, distill.md command with flag dispatch, and the established patterns from purge (task 450) and merge (task 451).

## Context & Scope

This task completes the distillation pipeline by implementing the final three sub-modes. After this task, all six sub-modes (report, purge, merge, compress, refine, gc) will be available. Task 453 depends on this task for full `/distill` integration with `/todo`.

### Scope

1. **Compress sub-mode** (`--compress`): Reduce oversized memories to key points while preserving keywords and code blocks
2. **Refine sub-mode** (`--refine`): Fix metadata quality issues (automatic + interactive tiers)
3. **Auto flag** (`--auto`): Run safe automatic operations without user interaction
4. Update distill.md command to mark these sub-modes as available
5. Update SKILL.md with full implementations
6. Update manifest.json and EXTENSION.md if needed

### Files to Modify

| File | Change |
|------|--------|
| `.claude/extensions/memory/skills/skill-memory/SKILL.md` | Add compress, refine, and auto sub-mode implementations |
| `.claude/extensions/memory/commands/distill.md` | Update availability status for compress, refine, auto |

## Findings

### Codebase Patterns

#### 1. Scoring Engine -- Size Penalty (Component 3)

Located in SKILL.md lines 1003-1012. The size penalty drives compress candidate identification:

```
size_penalty = max(0, (token_count - 600) / 600)
```

- Range: 0.0 (600 tokens or fewer) to unbounded (linear above 600)
- A 1200-token memory scores 1.0; a 300-token memory scores 0.0
- Compress candidates are flagged when `size_penalty > 0.5` (line 1057), which corresponds to `token_count > 900`

**Important correction**: The task description says candidates have `token_count > 600`, but the scoring engine flags compress candidates at `size_penalty > 0.5`. Since `size_penalty = max(0, (token_count - 600) / 600)`, a `size_penalty > 0.5` requires `token_count > 900`. The implementation should use the scoring engine threshold (`size_penalty > 0.5`) for consistency with the health report's "Compress Candidates" section.

#### 2. Existing Sub-Mode Patterns

All implemented sub-modes follow a consistent structure in SKILL.md:

1. **Edge case checks**: Validate-on-read, minimum memory count
2. **Candidate identification**: Score-based selection with filtering
3. **Dry-run mode**: Display candidates without writing files
4. **Interactive selection**: AskUserQuestion multiSelect with descriptive labels
5. **Execution**: Content transformation with invariant checks
6. **Index regeneration**: Batch regeneration after all operations complete
7. **Distill log entry**: Pre/post metrics with affected_memories list
8. **State integration**: Update memory_health in state.json

#### 3. Content Preservation Pattern (UPDATE Operation)

The SKILL.md UPDATE operation (lines 249-278) provides the template for compress's history preservation:

```markdown
## History

### Previous Version ({original_created})

{previous_content}
```

The compress operation should use a similar pattern:

```markdown
## History

### Pre-Compression ({date})

{original_content}
```

This matches the task description: "Move original content to `## History > ### Pre-Compression ({date})` section."

#### 4. Memory Template Frontmatter

From `.memory/30-Templates/memory-template.md`, the standard frontmatter fields are:

```yaml
title, created, tags, topic, source, modified, retrieval_count, last_retrieved, keywords, summary, token_count
```

Plus the optional tombstone fields: `status`, `tombstoned_at`, `tombstone_reason`.

The refine operation needs to inspect and fix: `keywords`, `summary`, `tags` (for category), and `topic`.

#### 5. Current Vault State

The vault has 1 memory (`MEM-plan-delegation-required`, 302 tokens). This memory:
- Is below the compress threshold (302 < 900 tokens)
- Has 5 keywords (above the sparse threshold of < 4)
- Has a summary field populated
- Has a topic field (`agent-system`)
- Has a category derived from tags (`enforcement`)

This means with the current vault state, compress will find no candidates and refine will find no automatic fix candidates. The implementation must handle "no candidates" gracefully.

#### 6. Distill Log Schema

From SKILL.md lines 1438-1481, the distill-log.json supports operation types `compress` and `refine`. The current distill-log.json (`.memory/distill-log.json`) has zero operations and tracking counters for `total_compressed` and `total_refined`.

Compress-specific log fields (from task description):
```json
{
  "type": "compress",
  "affected_memories": [
    {
      "id": "MEM-...",
      "tokens_before": 1200,
      "tokens_after": 450,
      "compression_ratio": 0.375,
      "keywords_preserved": true,
      "action": "compressed"
    }
  ]
}
```

Refine-specific log fields (to be designed):
```json
{
  "type": "refine",
  "affected_memories": [
    {
      "id": "MEM-...",
      "fixes_applied": ["keyword_dedup", "summary_generation"],
      "action": "refined"
    }
  ]
}
```

#### 7. Command Dispatch (distill.md)

The distill.md command file (`.claude/extensions/memory/commands/distill.md`) already has argument parsing for `--compress`, `--refine`, and `--auto` flags. The availability table needs updating from "Placeholder" to "Available" for these three sub-modes.

### External Resources

No external documentation needed. All patterns are established within the codebase by the prior tasks (449, 450, 451).

### Recommendations

#### Compress Sub-Mode Design

1. **Candidate identification**: Filter non-tombstoned memories where `size_penalty > 0.5` (token_count > 900). If none found, display "No compress candidates found" and return.

2. **Dry-run mode**: Display candidates with token counts and compression estimates without writing.

3. **Interactive selection**: AskUserQuestion multiSelect with:
   - Label: `{memory.id}`
   - Description: `Tokens: {token_count} | Size penalty: {size_penalty:.2f} | Topic: {topic} | Retrievals: {retrieval_count}`

4. **Compression execution** (for each selected memory):
   a. Read full memory content
   b. Generate compressed version:
      - Extract key points as bullet list
      - Preserve all code blocks and examples verbatim
      - Remove redundant prose, verbose explanations, repetitive context
      - Target: reduce to ~60% of original token count (guideline, not strict)
   c. Move original content to `## History > ### Pre-Compression ({today})` section
   d. Write compressed content as main body
   e. Recalculate `token_count` in frontmatter (word_count * 1.3, rounded down)
   f. Update `modified` to today
   g. **Keyword preservation check**: Verify all original keywords still apply to compressed content. If compression removed context for a keyword, keep it anyway (keywords are metadata, not content).

5. **Index regeneration**: After all compressions, regenerate memory-index.json, index.md, and 10-Memories/README.md.

6. **Distill log**: Log with `type: "compress"`, include `tokens_before`, `tokens_after`, `compression_ratio`, `keywords_preserved` per memory.

#### Refine Sub-Mode Design

Two tiers of fixes:

**Tier 1: Automatic Fixes** (no confirmation needed):
- **Keyword deduplication**: Remove duplicate keywords within each memory's `keywords` array (case-insensitive comparison, keep first occurrence)
- **Summary generation**: For memories with empty or missing `summary` field, generate from first line of content (truncate to ~100 characters)
- **Topic normalization**: Lowercase all topic paths, ensure consistent `/` separators (no backslashes, no trailing slashes)

**Tier 2: Interactive Fixes** (require AskUserQuestion):
- **Keyword enrichment**: For memories with < 4 keywords, suggest additional keywords based on content analysis (present 3-5 suggestions per memory)
- **Category reclassification**: For memories where tag-derived category does not match content, suggest new category
- **Topic path correction**: For memories with topic paths inconsistent with cluster patterns, suggest corrections

**Execution flow**:
1. Run validate-on-read
2. Scan all non-tombstoned memories for quality issues
3. If `--auto` flag: apply Tier 1 fixes only, skip Tier 2, no AskUserQuestion
4. If standalone `--refine`: apply Tier 1 fixes first, then present Tier 2 candidates interactively
5. Regenerate indexes after all fixes
6. Log to distill-log.json with `type: "refine"` and per-memory `fixes_applied` list

#### Auto Flag Design

The `--auto` flag runs a safe, non-interactive maintenance pass:

1. Run validate-on-read (regenerate memory-index.json if stale)
2. Run Tier 1 refine fixes (keyword dedup, summary generation, topic normalization)
3. Rebuild memory-index.json from filesystem state
4. Update memory_health in state.json
5. Log to distill-log.json with `type: "refine"` and `notes: "auto mode"`
6. Display summary of changes made

**Auto does NOT include**:
- Compress (requires user review of AI-generated summaries)
- Purge (requires explicit user confirmation for data loss)
- Merge (requires user selection of pairs)
- Any interactive Tier 2 refine fixes

## Decisions

1. **Compress threshold**: Use `size_penalty > 0.5` (token_count > 900) from the scoring engine, not the raw `token_count > 600` from the task description. This is consistent with the health report's "Compress Candidates" section and ensures only meaningfully oversized memories are targeted.

2. **Keyword preservation is absolute**: Compressed content may not cover all original keywords contextually, but keywords are metadata that must be preserved. This mirrors the "keyword superset guarantee" from the merge operation.

3. **Auto flag scope**: Auto runs only Tier 1 refine fixes. Compress is explicitly excluded because AI-generated summaries need human review. This makes `--auto` safe for cron-like invocation.

4. **Refine standalone vs auto**: `--refine` without `--auto` runs both tiers (automatic first, then interactive). `--auto` alone runs only Tier 1. The flags are not combined -- `--auto` is its own sub-mode.

5. **Compression target**: ~60% of original token count as a soft guideline. The actual compression depends on content verbosity. No hard minimum compression ratio is enforced.

6. **History section placement**: Place `## History > ### Pre-Compression ({date})` before `## Connections` (if present), following the same placement logic as the UPDATE operation's history section.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Compressed content loses essential information | H | M | Preserve original in History section; keyword preservation check; user reviews compressed output |
| Refine auto-fix introduces bad keywords/summaries | M | L | Tier 1 only does safe operations (dedup, generation from content, normalization); no destructive changes |
| Empty vault (no candidates) crashes | M | L | Edge case checks before candidate identification; "no candidates" message and early return |
| Concurrent SKILL.md edits conflict | M | L | Task 452 depends on 450 and 451 (both completed); no concurrent edits expected |
| Compression ratio too aggressive | M | M | Soft ~60% target; preserving code blocks and examples limits over-compression |

## Context Extension Recommendations

None. All patterns are well-established within existing context files.

## Appendix

### Search Queries Used

- `Glob **/*distill*` -- Found all distill-related files across specs and memory extension
- `Glob **/skills/*memory*` -- Located skill-memory SKILL.md
- `Grep 452` in TODO.md -- Found task description and dependency chain
- Read: SKILL.md (full file, 1962 lines) -- Scoring engine, sub-mode dispatch, all existing implementations
- Read: distill.md command -- Flag dispatch and availability table
- Read: memory-index.json -- Current vault state (1 entry, 302 tokens)
- Read: MEM-plan-delegation-required.md -- Frontmatter quality patterns
- Read: memory-template.md -- Standard frontmatter schema
- Read: distill-log.json -- Current log state (empty)
- Read: Prior task reports (449, 450, 451) -- Pattern consistency

### SKILL.md Insertion Points

The compress, refine, and auto sub-mode implementations should be inserted after the existing GC sub-mode section (which ends at line 1962, the end of the file). The sub-mode dispatch table (lines 947-952) needs updating to change status from "Placeholder" to "Available".

### Distill Command Update Points

In `.claude/extensions/memory/commands/distill.md`:
- Line 25: `--compress` status from `[placeholder - task 452]` to `[available - task 452]`
- Line 26: `--refine` status from `[placeholder - task 452]` to `[available - task 452]`
- Line 28: `--auto` status from `[placeholder - task 452]` to `[available - task 452]`
- Lines 63-66 (workflow step 1): Update availability table
- Lines 76-79: Remove/update the placeholder response message to exclude compress, refine, auto
