# Research Report: Task #445

**Task**: 445 - Implement Two-Phase Auto-Retrieval for Memory System
**Started**: 2026-04-16T00:00:00Z
**Completed**: 2026-04-16T00:30:00Z
**Effort**: Medium (3-4 hours estimated implementation)
**Dependencies**: Task 444 (memory-index.json creation -- completed)
**Sources/Inputs**: Codebase analysis of skill files, memory extension, orchestrator routing
**Artifacts**: specs/445_implement_two_phase_auto_retrieval_memory/reports/01_auto-retrieval-research.md
**Standards**: report-format.md

---

## Executive Summary

- The memory-index.json schema (created in task 444) already contains all fields needed for scoring: keywords, topic, category, token_count, retrieval_count, last_retrieved
- The injection point for auto-retrieval is **Stage 4: Prepare Delegation Context** in each of the three skill files (skill-researcher, skill-planner, skill-implementer), between context preparation and subagent invocation
- A keyword-overlap + topic-match + recency scoring algorithm can be implemented inline within each skill's Stage 4 using jq and bash
- The `--clean` flag should follow the existing flag-parsing pattern in STAGE 1.5 of research.md/plan.md/implement.md commands
- Token budget enforcement should use the existing `token_count` field in memory-index.json with a configurable ceiling (recommended: 2000 tokens)

---

## Context & Scope

This research investigates how to make memory retrieval automatic for all `/research`, `/plan`, and `/implement` operations. Currently, memory retrieval requires the `--remember` flag on `/research` only (via the memory extension). The goal is to make retrieval the default behavior using a two-phase approach: score the JSON index to select top-K candidates, then read only selected memory files into context.

### Constraints
- Must not break existing skill execution flow
- Must be skippable via `--clean` flag
- Must respect token budgets (memory context should not overwhelm task context)
- Must update retrieval_count and last_retrieved in memory-index.json after retrieval

---

## Findings

### 1. Memory-Index.json Schema

The `.memory/memory-index.json` file has the following structure:

```json
{
  "version": "1.0.0",
  "generated_at": "2026-04-16",
  "entry_count": 1,
  "total_tokens": 302,
  "entries": [
    {
      "id": "MEM-plan-delegation-required",
      "path": ".memory/10-Memories/MEM-plan-delegation-required.md",
      "title": "Artifact Creation Must Use Skill Delegation",
      "summary": "When executing /plan, /research, or /implement commands...",
      "topic": "agent-system",
      "category": "enforcement",
      "keywords": ["delegation", "artifact", "skill", "bypass-prevention", "enforcement"],
      "token_count": 302,
      "created": "2026-04-13",
      "modified": "2026-04-13",
      "last_retrieved": null,
      "retrieval_count": 0
    }
  ]
}
```

Key fields for scoring:
- `keywords` (array of strings) -- primary matching dimension
- `topic` (string) -- secondary matching dimension
- `category` (string) -- tertiary matching dimension
- `token_count` (number) -- for budget enforcement
- `retrieval_count` and `last_retrieved` -- for retrieval tracking updates

The memory template frontmatter (`.memory/30-Templates/memory-template.md`) includes `retrieval_count: 0` and `last_retrieved: null` as defaults, confirming these fields are present on all memory files.

### 2. Injection Points in Skill Files

All three skills follow an identical structure. The injection point is between Stage 3a (Calculate Artifact Number) and Stage 4 (Prepare Delegation Context), or within Stage 4 itself as a new sub-stage.

#### skill-researcher/SKILL.md
- **Stage 4: Prepare Delegation Context** (lines 124-151)
- Delegation context JSON is assembled at this stage
- New sub-stage "Stage 4a: Memory Retrieval" would inject between Stage 3a and Stage 4
- Memory context would be added as a new field in the delegation context JSON

#### skill-planner/SKILL.md
- **Stage 4: Prepare Delegation Context** (lines 142-179)
- Same pattern -- delegation context assembled here
- Same injection point (new Stage 4a before existing Stage 4)

#### skill-implementer/SKILL.md
- **Stage 4: Prepare Delegation Context** (lines 137-165)
- Same pattern -- delegation context assembled here
- Same injection point (new Stage 4a before existing Stage 4)

### 3. Existing Memory Retrieval Patterns

The memory extension currently provides:
- **`--remember` flag** on `/research` -- opt-in memory search via MCP or grep fallback
- **skill-memory** -- handles CREATE/UPDATE/EXTEND operations with keyword matching
- **Overlap scoring** in skill-memory (lines 188-200): `|segment_terms intersect memory_terms| / |segment_terms|` with thresholds at 60% (HIGH), 30-60% (MEDIUM), <30% (LOW)
- **Validate-on-Read** pattern (lines 512-527): Before using memory-index.json, validate index matches filesystem (detect stale/orphaned entries)
- **Grep fallback** when MCP unavailable: keyword search through `.memory/10-Memories/*.md`

The auto-retrieval system should reuse these patterns but operate on the JSON index rather than reading all memory files.

### 4. Flag Parsing Pattern (--clean)

The existing flag parsing follows a consistent pattern across commands. In `research.md` STAGE 1.5 (lines 265-309):

```
1. Extract team options (--team, --team-size N)
2. Extract effort flags (--fast, --hard)
3. Extract model flags (--haiku, --sonnet, --opus)
4. Remaining text = focus_prompt
```

The `--clean` flag should be added as step 2.5 in this sequence. It mirrors the lean extension's `--clean` flag pattern:

```bash
--clean) clean=true ;;
```

The flag needs to be parsed at the **command level** (research.md, plan.md, implement.md) and passed through to the skill via the delegation context. The skill then skips Stage 4a (Memory Retrieval) when `clean_flag=true`.

### 5. Scoring Algorithm Design

#### Phase 1: Score (operates on memory-index.json only)

Given a task description and optional focus prompt, score each memory entry:

```
score(entry) = keyword_score * 0.5 + topic_score * 0.3 + recency_score * 0.2

Where:
  keyword_score = |task_keywords intersect entry.keywords| / max(|task_keywords|, 1)
  topic_score = 1.0 if entry.topic matches task_type or description keywords, else 0.0
  recency_score = 1.0 if modified within 30 days, 0.5 if within 90 days, 0.0 otherwise
```

Keyword extraction from task description:
1. Lowercase the description
2. Remove stop words (the, a, is, are, to, for, of, in, on, with, and, or, not, this, that)
3. Extract words > 3 characters
4. Deduplicate
5. Take top 10 by frequency

#### Phase 2: Retrieve (reads selected files)

1. Sort entries by score descending
2. Select top-K entries where cumulative token_count <= budget
3. Read each selected memory file
4. Format as memory-context block for injection into delegation context
5. Update retrieval_count and last_retrieved in memory-index.json

#### Implementation Approach

The scoring can be done entirely with jq and bash within the skill's execution flow:

```bash
# Extract keywords from task description
task_keywords=$(echo "$description $focus_prompt" | tr '[:upper:]' '[:lower:]' | \
  tr -cs '[:alpha:]' '\n' | sort -u | grep -v '^.\{1,3\}$' | \
  grep -vxf <(echo -e "the\na\nis\nare\nto\nfor\nof\nin\non\nwith\nand\nor\nnot\nthis\nthat") | \
  head -10)

# Score entries using jq
scored_entries=$(jq -r --arg keywords "$task_keywords" --arg task_type "$task_type" '
  .entries[] |
  ... scoring logic ...
' .memory/memory-index.json)
```

However, complex scoring in jq is fragile. A simpler approach: extract keywords in bash, then use jq to filter entries that have any keyword overlap, sorted by overlap count.

### 6. Token Budget Strategy

Recommended approach:
- **Default budget**: 2000 tokens (roughly 1500 words)
- **Budget source**: Sum of `token_count` fields from selected entries
- **Selection**: Greedy -- add entries in score order until budget exhausted
- **Minimum threshold**: Score > 0.1 (at least some keyword overlap)
- **Maximum entries**: 5 (even if budget allows more, limit cognitive load)

The budget should be configurable but not exposed as a command flag initially. A constant in the skill file is sufficient for v1.

### 7. Memory Context Block Format

The retrieved memory content should be injected into the delegation context as a structured block:

```json
{
  "session_id": "...",
  "delegation_depth": 1,
  "task_context": { ... },
  "memory_context": {
    "entries_scored": 1,
    "entries_selected": 1,
    "total_tokens": 302,
    "memories": [
      {
        "id": "MEM-plan-delegation-required",
        "title": "Artifact Creation Must Use Skill Delegation",
        "summary": "When executing /plan, /research, or /implement...",
        "relevance_score": 0.72,
        "content": "... full file content ..."
      }
    ]
  }
}
```

Alternatively, the content can be injected as a text block in the prompt (similar to how format specifications are injected in Stage 4b):

```
<memory-context>
## Relevant Memories (auto-retrieved)

### MEM-plan-delegation-required (score: 0.72)
[full content of memory file]

</memory-context>
```

The prompt-injection approach is simpler and more consistent with existing patterns (Stage 4b format injection).

### 8. Retrieval Count Update

After selecting memories, update the frontmatter of each retrieved memory file:
- Increment `retrieval_count` by 1
- Set `last_retrieved` to today's date (ISO format)

Also update the corresponding entry in `memory-index.json`:
- Same field updates

This should be done AFTER the delegation context is prepared but BEFORE the subagent is invoked (still within Stage 4a). The update is lightweight (sed on frontmatter fields + jq on index).

---

## Decisions

1. **Injection as new Stage 4a** -- Insert between artifact number calculation and delegation context preparation in each skill
2. **Prompt-based injection** -- Use text block injection (like format specs) rather than JSON field in delegation context
3. **Keyword overlap scoring** -- Simple and robust, avoids complex jq logic
4. **Budget of 2000 tokens** -- Enough for 3-6 typical memories without overwhelming context
5. **--clean flag at command level** -- Parsed alongside --fast/--hard/--team, passed to skill as clean_flag field
6. **Validate-on-read** -- Reuse the existing pattern from skill-memory before scoring

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| memory-index.json missing or empty | Medium | Low | Graceful skip -- if file missing or entry_count=0, skip retrieval silently |
| jq scoring logic too complex | Medium | Medium | Keep scoring in bash (keyword extraction) with simple jq filtering (keyword overlap count) |
| Token budget exceeded | Low | Medium | Hard cap at 2000 tokens with greedy selection |
| Stale index | Medium | Low | Validate-on-read pattern detects and regenerates stale index |
| Performance impact on skill startup | Low | Low | Phase 1 (score) is fast -- just jq on a small JSON file; Phase 2 (read) reads only selected files |
| Breaking existing --remember flag | Low | Medium | Auto-retrieval is independent of --remember; both can coexist. --remember uses MCP search (broader), auto-retrieval uses index scoring (faster, index-only) |

---

## Recommendations

### Implementation Approach

1. **Create a shared retrieval script** at `.claude/scripts/memory-retrieve.sh` that encapsulates both phases. This avoids duplicating the scoring logic across three skill files. Each skill calls the script and receives memory content on stdout.

2. **Script interface**:
   ```bash
   # Usage: memory-retrieve.sh <description> <task_type> [focus_prompt]
   # Output: Memory context block (text) on stdout, empty if no matches
   # Side effect: Updates retrieval_count and last_retrieved
   # Exit code: 0 = memories found, 1 = no matches or index missing
   ```

3. **Skill integration** (identical in all three skills):
   ```bash
   # Stage 4a: Memory Retrieval
   memory_context=""
   if [ "$clean_flag" != "true" ]; then
     memory_context=$(bash .claude/scripts/memory-retrieve.sh "$description" "$task_type" "$focus_prompt" 2>/dev/null) || true
   fi
   ```

4. **Prompt injection** in Stage 5 (alongside format injection):
   ```
   <memory-context>
   {memory_context from Stage 4a}
   </memory-context>
   ```

### Files to Modify

| File | Change |
|------|--------|
| `.claude/scripts/memory-retrieve.sh` | **NEW** -- Shared retrieval script |
| `.claude/skills/skill-researcher/SKILL.md` | Add Stage 4a, inject memory in Stage 5 prompt |
| `.claude/skills/skill-planner/SKILL.md` | Add Stage 4a, inject memory in Stage 5 prompt |
| `.claude/skills/skill-implementer/SKILL.md` | Add Stage 4a, inject memory in Stage 5 prompt |
| `.claude/commands/research.md` | Parse --clean flag in STAGE 1.5, pass to skill |
| `.claude/commands/plan.md` | Parse --clean flag, pass to skill |
| `.claude/commands/implement.md` | Parse --clean flag, pass to skill |
| `.claude/CLAUDE.md` | Document --clean flag in command reference table |

### Phased Implementation

- **Phase 1**: Create memory-retrieve.sh script with scoring + retrieval + tracking updates
- **Phase 2**: Add Stage 4a to all three skills with script integration
- **Phase 3**: Add --clean flag parsing to all three commands
- **Phase 4**: Update CLAUDE.md documentation and test end-to-end

---

## Appendix

### Search Queries Used

- Glob: `.memory/**/*.md`, `.claude/extensions/memory/**`, `.claude/skills/skill-*/SKILL.md`
- Grep: `--clean|--skip|--no-`, `--remember|memory.*retriev`
- Files read: memory-index.json, skill-researcher/SKILL.md, skill-planner/SKILL.md, skill-implementer/SKILL.md, skill-memory/SKILL.md, memory extension manifest.json, EXTENSION.md, research.md command, skill-orchestrator/SKILL.md, memory-template.md, context-discovery.md, MEM-plan-delegation-required.md

### References

- `.memory/memory-index.json` -- Machine-queryable memory index (task 444)
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` -- Overlap scoring algorithm (lines 188-200), validate-on-read (lines 512-527)
- `.claude/commands/research.md` -- Flag parsing pattern (STAGE 1.5, lines 265-309)
- `.claude/extensions/lean/skills/skill-lake-repair/SKILL.md` -- `--clean` flag precedent
- `.claude/context/patterns/context-discovery.md` -- Context query patterns
