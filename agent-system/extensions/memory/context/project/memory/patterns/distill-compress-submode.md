# Sub-Mode: compress

This file is the COMPLETE and ONLY specification for skill-distill's `--compress` sub-mode execution. It MUST be followed exactly -- there is no fuller version of this content anywhere else. The `Sub-Mode: compress` section of `skill-distill/SKILL.md` was extracted here per `context/patterns/mode-gated-section-loading.md`; the pointer at that section's former location in `SKILL.md` sends an agent here whenever `--compress` is dispatched.

Reduce oversized memories to key points while preserving essential information. The compress operation identifies memories with high size penalty, presents them interactively, generates compressed versions, preserves originals in a History section, and ensures keyword preservation. Follows the Shared Sub-Mode Skeleton in `skill-distill/SKILL.md`; deltas below.

## Edge Case Checks

Before candidate identification, validate:

```
1. Run validate-on-read to ensure memory-index.json is consistent
2. Count non-tombstoned memories (status != "tombstoned" or status absent)
3. If no non-tombstoned memories:
   Display: "No memories in vault to compress."
   Return early.
```

## Compress Candidate Identification

After scoring all memories via the Scoring Engine, select compress candidates:

```
compress_candidates = []
for each memory in scored_memories:
  if memory.status == "tombstoned":
    skip  # Already tombstoned
  if memory.size_penalty > 0.5:  # token_count > 900
    compress_candidates.append(memory)

Sort by size_penalty descending (largest memories first)
```

**Edge Case**: If `compress_candidates` is empty, display:
```
No compress candidates found. All memories are within size limits (token_count <= 900).
```
Then exit the compress sub-mode without further action.

## Dry-Run Behavior

When `--dry-run` is active, show candidates with estimates without writing any files:

```
## Compress Candidates (Dry Run)

| Memory | Tokens | Size Penalty | Topic | Est. Compressed |
|--------|--------|-------------|-------|-----------------|
| {id} | {token_count} | {size_penalty:.2f} | {topic} | ~{token_count * 0.4} |

{count} compress candidate(s) found.
Run /distill --compress without --dry-run to execute.
```

Return early after display. No files are modified.

## Interactive Selection -- MANDATORY STOP

**MANDATORY STOP (Shared Sub-Mode Skeleton, Interactive Selection step). Do NOT compress any memories without explicit user selection.**

Present candidates via AskUserQuestion multiSelect:

```json
{
  "question": "Select memories to compress. Original content will be preserved in a History section.",
  "header": "Compress Candidates ({count} found)",
  "multiSelect": true,
  "options": [
    {
      "label": "{memory.id}",
      "description": "Tokens: {token_count} | Size penalty: {size_penalty:.2f} | Topic: {topic} | Retrievals: {retrieval_count}"
    }
  ]
}
```

If the user selects no memories, display:
```
No memories selected for compression. Operation cancelled.
```
Then exit without changes.

## Compression Execution

For each selected memory, compress following these steps:

```
1. Read the full memory file (.memory/10-Memories/MEM-{slug}.md)
2. Parse frontmatter and content sections
3. Extract original keywords from frontmatter

4. Generate compressed content:
   - Extract key points as bullet list
   - Preserve code blocks and examples verbatim
   - Remove redundant prose, verbose explanations, and filler
   - Target ~60% reduction (soft guideline, not enforced)
   - Maintain the core information and actionable details

5. Move original content to History section:
   - Insert before ## Connections section (if present), or at end of file
   - Use heading: ## History > ### Pre-Compression ({today})
   - Include full original content (between title heading and ## Connections)

6. Write compressed content as main body (between title heading and ## History)

7. Update frontmatter:
   - Recalculate token_count: word_count * 1.3, rounded down
   - Update modified to today (ISO date)
   - Preserve all other frontmatter fields unchanged

8. Keyword preservation check:
   original_keywords = set(memory.keywords)
   compressed_keywords = extract_keywords(compressed_content)
   missing = original_keywords - keywords_in_compressed_content

   If missing keywords found:
     - Add missing keywords explicitly to the compressed content
       (append "**Keywords**: {missing_keywords}" line if needed)
     - Log: "Keyword preservation: added {N} missing keywords to compressed content"

9. Write the updated memory file
```

## Compressed Content Template

```markdown
---
{preserved frontmatter with updated token_count and modified}
---

# {title}

{compressed content - key points as bullet list, preserved code blocks}

## History

### Pre-Compression ({today})

{original content that was between title heading and ## Connections}

## Connections
{preserved connections section}
```

## Batch Index Regeneration

After ALL compressions in the batch are complete (not after each individual compression):

```
1. Regenerate memory-index.json using "JSON Index Maintenance" procedure
   - Updated token_count values will be reflected
2. Regenerate index.md using "Index Regeneration Pattern"
3. Regenerate .memory/10-Memories/README.md
```

## Compress Log Entry

Log the compress operation to `.memory/distill-log.json`:

```json
{
  "id": "distill_{timestamp}",
  "timestamp": "ISO8601",
  "type": "compress",
  "session_id": "sess_...",
  "pre_metrics": {
    "total_memories": N,
    "total_tokens": N,
    "health_score": N,
    "purge_candidates": N,
    "merge_candidates": N,
    "compress_candidates": N
  },
  "post_metrics": {
    "total_memories": N,
    "total_tokens": N,
    "health_score": N,
    "purge_candidates": N,
    "merge_candidates": N,
    "compress_candidates": N
  },
  "affected_memories": [
    {
      "id": "{memory.id}",
      "tokens_before": N,
      "tokens_after": N,
      "compression_ratio": 0.42,
      "keywords_preserved": true,
      "action": "compressed"
    }
  ],
  "notes": "Compressed {N} memories. Total tokens saved: {tokens_saved}"
}
```

The `compression_ratio` is `tokens_after / tokens_before` (lower means more compression). The `keywords_preserved` boolean confirms all original keywords are present in the compressed content.

Update the distill-log.json `summary.total_compressed` counter by incrementing it by the number of compressed memories.

