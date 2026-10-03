# Sub-Mode: refine

This file is the COMPLETE and ONLY specification for skill-distill's `--refine` sub-mode execution. It MUST be followed exactly -- there is no fuller version of this content anywhere else. The `Sub-Mode: refine` section of `skill-distill/SKILL.md` was extracted here per `context/patterns/mode-gated-section-loading.md`; the pointer at that section's former location in `SKILL.md` sends an agent here whenever `--refine` is dispatched.

Improve memory metadata quality through two tiers of fixes. Tier 1 fixes are safe automatic corrections that require no user interaction. Tier 2 fixes are interactive improvements that require user confirmation via AskUserQuestion. Follows the Shared Sub-Mode Skeleton in `skill-distill/SKILL.md`; deltas below. (Tier 1 has no Interactive Selection step by design -- see Tier 1 below for the exemption.)

## Edge Case Checks

Before candidate scanning, validate:

```
1. Run validate-on-read to ensure memory-index.json is consistent
2. Count non-tombstoned memories (status != "tombstoned" or status absent)
3. If no non-tombstoned memories:
   Display: "No memories in vault to refine."
   Return early.
```

## Quality Issue Scanning

Iterate all non-tombstoned memories and scan for quality issues:

```
tier1_fixes = []   # Automatic, no confirmation needed
tier2_fixes = []   # Interactive, require AskUserQuestion

for each memory in non_tombstoned_memories:
  # Read full memory file for content analysis

  # --- Tier 1: Automatic Fixes ---

  # 1. Keyword deduplication
  if memory.keywords has duplicates (case-insensitive):
    tier1_fixes.append({
      "memory": memory.id,
      "fix": "keyword_dedup",
      "description": "Remove duplicate keywords (case-insensitive, keep first occurrence)",
      "before": memory.keywords,
      "after": deduplicated_keywords
    })

  # 2. Summary generation
  if memory.summary is empty or missing:
    generated_summary = first_line_of_content[:100]  # Truncate to ~100 chars
    tier1_fixes.append({
      "memory": memory.id,
      "fix": "summary_gen",
      "description": "Generate summary from first line of content",
      "before": "",
      "after": generated_summary
    })

  # 3. Topic normalization
  if memory.topic has uppercase letters OR missing "/" separators OR trailing slashes:
    normalized_topic = memory.topic.lower().strip("/")
    tier1_fixes.append({
      "memory": memory.id,
      "fix": "topic_normalize",
      "description": "Normalize topic path (lowercase, clean separators)",
      "before": memory.topic,
      "after": normalized_topic
    })

  # --- Tier 2: Interactive Fixes ---

  # 4. Keyword enrichment
  if len(memory.keywords) < 4:
    suggested_keywords = extract_keywords_from_content(memory.content, 5)
    new_keywords = [k for k in suggested_keywords if k not in memory.keywords]
    if new_keywords:
      tier2_fixes.append({
        "memory": memory.id,
        "fix": "keyword_enrich",
        "description": "Add suggested keywords based on content analysis",
        "current_keywords": memory.keywords,
        "suggested_additions": new_keywords[:5]
      })

  # 5. Category reclassification
  # Skip entirely when the memory has an explicit frontmatter `category:` field
  # (email-to-memory-preferences.md design §3.4) -- an explicit category is authoritative and
  # never content-inferred; this
  # only fires for the tags-derivation fallback path (pre-822 memories, and any future memory
  # without a `category:` field).
  if not memory.has_explicit_category_field:
    content_category = infer_category_from_content(memory.content)
    if content_category != memory.category:
      tier2_fixes.append({
        "memory": memory.id,
        "fix": "category_reclassify",
        "description": "Category may not match content",
        "current_category": memory.category,
        "suggested_category": content_category
      })

  # 6. Topic path correction
  cluster_topics = get_topic_patterns_from_cluster(memory.topic)
  if memory.topic not consistent with cluster_topics:
    tier2_fixes.append({
      "memory": memory.id,
      "fix": "topic_correct",
      "description": "Topic path inconsistent with cluster patterns",
      "current_topic": memory.topic,
      "suggested_topic": corrected_topic
    })
```

## "No Issues Found" Early Return

If both `tier1_fixes` and `tier2_fixes` are empty:
```
No quality issues found. All memories have clean metadata.
```
Then exit without further action.

## Tier 1 Execution (Automatic)

Tier 1 fixes run without user interaction:

```
1. Display summary of Tier 1 fixes to be applied:
   ## Tier 1 Automatic Fixes

   | Memory | Fix | Description |
   |--------|-----|-------------|
   | {id} | keyword_dedup | Removed {N} duplicate keywords |
   | {id} | summary_gen | Generated summary from content |
   | {id} | topic_normalize | Normalized topic path |

2. Apply each fix:
   - keyword_dedup: Rewrite keywords array in frontmatter (case-insensitive dedup, keep first)
   - summary_gen: Add/update summary field in frontmatter
   - topic_normalize: Update topic field in frontmatter

3. Update modified date to today for each affected memory
```

## Tier 2 Interactive Selection -- MANDATORY STOP

**MANDATORY STOP (Shared Sub-Mode Skeleton, Interactive Selection step), if Tier 2 fixes exist. Do NOT apply Tier 2 fixes without explicit user selection.**

If `tier2_fixes` is not empty, present via AskUserQuestion multiSelect:

```json
{
  "question": "Select quality improvements to apply (Tier 2 - interactive fixes):",
  "header": "Refine Candidates ({count} issues found)",
  "multiSelect": true,
  "options": [
    {
      "label": "{memory.id}: {fix_type}",
      "description": "{description} | Current: {current_value} | Suggested: {suggested_value}"
    }
  ]
}
```

If the user selects no fixes, display:
```
No Tier 2 fixes selected. Only Tier 1 automatic fixes were applied.
```

## Tier 2 Execution

For each selected Tier 2 fix:

```
- keyword_enrich: Append suggested keywords to frontmatter keywords array
- category_reclassify: Update first tag in frontmatter tags array
- topic_correct: Update topic field in frontmatter

Update modified date to today for each affected memory.
```

## Batch Index Regeneration

After ALL fixes (Tier 1 and Tier 2) are complete:

```
1. Regenerate memory-index.json using "JSON Index Maintenance" procedure
2. Regenerate index.md using "Index Regeneration Pattern"
3. Regenerate .memory/10-Memories/README.md
```

## Refine Log Entry

Log the refine operation to `.memory/distill-log.json`:

```json
{
  "id": "distill_{timestamp}",
  "timestamp": "ISO8601",
  "type": "refine",
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
      "fixes_applied": ["keyword_dedup", "summary_gen"],
      "action": "refined"
    }
  ],
  "notes": "Refined {N} memories. Tier 1: {T1_count} fixes, Tier 2: {T2_count} fixes"
}
```

Update the distill-log.json `summary.total_refined` counter by incrementing it by the number of refined memories.

