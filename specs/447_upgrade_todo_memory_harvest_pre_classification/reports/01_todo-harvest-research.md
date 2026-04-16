# Research Report: Task #447

**Task**: 447 - Upgrade /todo memory harvest with pre-classification and batch review
**Started**: 2026-04-16T19:24:06Z
**Completed**: 2026-04-16T19:30:00Z
**Effort**: large
**Dependencies**: Task #446 (completed)
**Sources/Inputs**: skill-todo/SKILL.md, state.json, memory-index.json, skill-memory/SKILL.md, return-metadata-file.md, state-management-schema.md, task 446 summary
**Artifacts**: specs/447_upgrade_todo_memory_harvest_pre_classification/reports/01_todo-harvest-research.md
**Standards**: report-format.md, return-metadata-file.md

## Executive Summary

- The upstream pipeline (task 446) is complete: agents emit `memory_candidates` into `.return-meta.json`, and skill postflight propagates them into state.json task entries with append semantics
- skill-todo Stage 7 (HarvestMemories) currently scans artifact files heuristically for memory candidates; this must be replaced with structured consumption of `memory_candidates` from state.json
- The three-tier pre-classification (Tier 1 pre-selected, Tier 2 presented, Tier 3 hidden) maps cleanly onto AskUserQuestion multiSelect with pre-selection
- Deduplication against `memory-index.json` keywords uses the same overlap algorithm already implemented in skill-memory's merge sub-mode (Jaccard-like ratio)
- Memory creation can reuse skill-memory's CREATE template and index regeneration patterns but must bypass the per-segment interactive flow

## Context & Scope

Task 447 upgrades `/todo` to consume structured memory candidates emitted by agents (via task 446) instead of heuristically scanning artifacts. The scope includes:
1. Rewriting Stage 7 (HarvestMemories) to read `memory_candidates` from state.json
2. Adding a deduplication step against `memory-index.json`
3. Modifying Stage 9 (InteractivePrompts) to present classified candidates in batch
4. Modifying Stage 14 (CreateMemories) to write memory files autonomously

Only `skill-todo/SKILL.md` needs modification.

## Findings

### 1. Current Stage 7 (HarvestMemories) -- Lines 154-171

The current implementation in skill-todo scans artifact files (reports/, plans/, summaries/) for each completed task and extracts "potential memory candidates" based on general applicability. It generates a suggestions list with source file path, brief description, and suggested category. This is entirely heuristic and will be replaced.

### 2. Memory Candidates in state.json

Task 446 established the data pipeline. The `memory_candidates` field is an optional array on task entries in state.json with append semantics. Each candidate has:
- `content` (string, ~300 tokens max)
- `category` (TECHNIQUE | PATTERN | CONFIG | WORKFLOW | INSIGHT)
- `source_artifact` (path)
- `confidence` (float 0-1)
- `suggested_keywords` (array of strings)

Currently no tasks in state.json have `memory_candidates` populated (the feature was just built), but the `// []` fallback is used everywhere for backward compatibility.

### 3. Three-Tier Classification Mapping

The task description specifies:

| Tier | Criteria | AskUserQuestion Behavior |
|------|----------|--------------------------|
| Tier 1 | PATTERN or CONFIG, confidence >= 0.8 | Pre-selected in multiSelect |
| Tier 2 | WORKFLOW or TECHNIQUE, confidence >= 0.5 | Shown but not pre-selected |
| Tier 3 | INSIGHT or confidence < 0.5 | Hidden by default |

AskUserQuestion supports multiSelect with pre-selection via the standard Claude Code tool interface. Tier 3 candidates can be shown via a secondary "Show all candidates" option in the list.

### 4. Deduplication Against memory-index.json

The deduplication algorithm mirrors skill-memory's overlap scoring:
- For each candidate, compute keyword overlap against every entry in `memory-index.json`
- `overlap = |candidate.suggested_keywords intersect entry.keywords| / |candidate.suggested_keywords|`
- If overlap > 90%: mark as NOOP (exclude entirely)
- If overlap > 60%: mark as potential UPDATE (present with warning)
- If overlap <= 60%: mark as CREATE (standard new memory)

Current memory-index.json has 1 entry with keywords `["delegation", "artifact", "skill", "bypass-prevention", "enforcement"]`. The validate-on-read pattern should be run before dedup to ensure consistency.

### 5. Memory Creation Pattern (Stage 14)

The current Stage 14 references `.opencode/memory/10-Memories/` (OpenCode path). This must be updated to `.memory/10-Memories/` for Claude Code.

The autonomous creation path should:
1. Generate slug using skill-memory's `generate_slug()` algorithm (topic + title, sanitized, collision-checked)
2. Write MEM-{slug}.md using the template at `.memory/30-Templates/memory-template.md`
3. Map candidate fields to template fields:
   - `content` -> body content
   - `category` -> first tag (e.g., `tags: [PATTERN]`)
   - `suggested_keywords` -> `keywords:` frontmatter field
   - `content` (first line or 60 chars) -> `summary:` frontmatter field
   - `source_artifact` -> `source:` frontmatter field
   - Set `retrieval_count: 0`, `last_retrieved: null`, `token_count: word_count * 1.3`
4. After ALL memories created, regenerate indexes (batch, not per-memory):
   - `.memory/memory-index.json` using JSON Index Maintenance procedure
   - `.memory/20-Indices/index.md` using Index Regeneration Pattern
   - `.memory/10-Memories/README.md` using the README regeneration procedure

### 6. Stage 9 Integration

The current Stage 9 (InteractivePrompts) already has a memory harvest prompt at sub-step 4. This needs to be replaced with the tiered AskUserQuestion:
- Options should show: `[TIER 1] [PATTERN] Task 449: Scoring engine composite formula (confidence: 0.85)`
- Pre-selected items use a mechanism compatible with AskUserQuestion's multiSelect
- A "Show Tier 3 candidates ({N} hidden)" option at the bottom expands the list

### 7. Candidate Cleanup After Archival

After memory creation succeeds, the `memory_candidates` field should be removed from the task entry in state.json before the entry is moved to archive. The archive entry does not need to carry candidates since they have been processed. This is handled implicitly since archival moves the entry to `specs/archive/state.json` and the active entry is deleted from `specs/state.json`.

### 8. Edge Cases

- **No candidates**: If no completed tasks have `memory_candidates`, skip Stages 7 and the memory portion of Stage 9 entirely
- **All NOOP after dedup**: If every candidate has >90% overlap, skip the memory prompt
- **Zero memories in vault**: First-time use; skip dedup entirely since no index entries exist
- **Mixed CREATE/UPDATE**: UPDATE candidates should note which existing memory would be affected

## Decisions

- **Replace heuristic scanning entirely**: The structured candidates from agents are more reliable than file scanning. The old heuristic approach in Stage 7 is removed, not kept as fallback.
- **Batch index regeneration**: Regenerate all three indexes (memory-index.json, index.md, README.md) once after all memories are created, not after each individual creation. This matches skill-memory's merge sub-mode pattern.
- **UPDATE candidates presented as warnings, not automatic**: When dedup detects >60% overlap, the candidate is presented with a warning label but the user decides whether to CREATE or SKIP. Full UPDATE operations (modifying existing memory content) are deferred to `/learn --task N` for proper interactive review.
- **Path correction**: Stage 14 references to `.opencode/memory/` must be updated to `.memory/` for Claude Code compatibility.

## Risks & Mitigations

- **Risk**: No tasks currently have `memory_candidates` populated, so the new code path cannot be tested against real data immediately.
  **Mitigation**: Use `// []` fallback everywhere; the old heuristic approach was also untested for most runs.

- **Risk**: AskUserQuestion multiSelect may not support pre-selection natively.
  **Mitigation**: Present Tier 1 candidates first with `[PRE-SELECTED]` label and document that they are recommended; user can deselect any.

- **Risk**: Memory creation could fail mid-batch (e.g., disk error), leaving indexes inconsistent.
  **Mitigation**: Index regeneration is from-filesystem-state (self-healing). A partial creation followed by regeneration will produce a consistent index reflecting whatever was written.

## Recommendations

### Implementation Approach

Modify a single file: `.claude/skills/skill-todo/SKILL.md`

**Stage 7 (HarvestMemories)** -- Complete rewrite:
1. For each completed task, read `memory_candidates // []` from state.json entry
2. Flatten all candidates into a single list with task provenance
3. Run dedup against `memory-index.json` (validate-on-read first)
4. Apply three-tier classification
5. Store classified list for Stage 9

**Stage 9 (InteractivePrompts)** -- Modify sub-step 4:
1. Present tiered AskUserQuestion if any candidates exist
2. Tier 1 pre-selected, Tier 2 shown, Tier 3 available on request
3. Store user selections for Stage 14

**Stage 14 (CreateMemories)** -- Complete rewrite:
1. For each approved candidate:
   a. Generate slug using semantic algorithm
   b. Write MEM-{slug}.md with full frontmatter from template
   c. Map candidate fields to template fields
2. Batch index regeneration (memory-index.json, index.md, README.md)
3. Update `.memory_health` in state.json (increment total_memories, recalculate)

## Appendix

### Search Queries Used
- Codebase: `memory_candidates` across `.claude/` (7 files)
- Codebase: skill-todo/SKILL.md full read (670 lines)
- Codebase: skill-memory/SKILL.md full read (1962 lines)
- Codebase: return-metadata-file.md, state-management-schema.md
- Codebase: memory-index.json, memory template, index.md
- Codebase: Task 446 summary for upstream pipeline confirmation

### Key File Paths
- Target file: `.claude/skills/skill-todo/SKILL.md`
- Memory template: `.memory/30-Templates/memory-template.md`
- Memory index: `.memory/memory-index.json`
- Index (markdown): `.memory/20-Indices/index.md`
- Memories dir: `.memory/10-Memories/`
- State: `specs/state.json` (memory_candidates field on task entries)
- Schema: `.claude/context/reference/state-management-schema.md`
