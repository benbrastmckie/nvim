# Implementation Plan: Upgrade /todo memory harvest with pre-classification and batch review

- **Task**: 447 - Upgrade /todo memory harvest with pre-classification and batch review
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: Task 446 (completed)
- **Research Inputs**: specs/447_upgrade_todo_memory_harvest_pre_classification/reports/01_todo-harvest-research.md
- **Artifacts**: plans/01_todo-harvest-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This task replaces the heuristic artifact-scanning approach in skill-todo's Stage 7 (HarvestMemories), Stage 9 sub-step 4 (InteractivePrompts), and Stage 14 (CreateMemories) with structured consumption of `memory_candidates` from state.json. The new pipeline reads pre-emitted candidates from agents (task 446 infrastructure), deduplicates against `memory-index.json`, applies three-tier classification (Tier 1 pre-selected, Tier 2 shown, Tier 3 hidden), presents them via AskUserQuestion multiSelect, and autonomously creates memory files with batch index regeneration. Only `.claude/skills/skill-todo/SKILL.md` requires modification.

### Research Integration

Key findings from the research report:
- The upstream pipeline (task 446) is complete and emits `memory_candidates` into state.json task entries with `// []` fallback
- Three-tier classification maps to AskUserQuestion multiSelect with pre-selection: Tier 1 (PATTERN/CONFIG, confidence >= 0.8), Tier 2 (WORKFLOW/TECHNIQUE, confidence >= 0.5), Tier 3 (INSIGHT or confidence < 0.5)
- Deduplication uses Jaccard-like keyword overlap against `memory-index.json` (>90% = NOOP, >60% = UPDATE warning, <=60% = CREATE)
- Stage 14 references `.opencode/memory/` which must be corrected to `.memory/`
- Memory creation should use skill-memory's slug generation and template patterns, with batch index regeneration after all files are written

### Roadmap Alignment

No ROADMAP.md items directly reference this task. However, this task is part of the memory system pipeline (tasks 444-454) which improves agent system quality, aligning with the "Agent System Quality" section of Phase 1 priorities.

## Goals & Non-Goals

**Goals**:
- Replace heuristic artifact scanning in Stage 7 with structured `memory_candidates` consumption from state.json
- Implement three-tier pre-classification with configurable confidence thresholds
- Present classified candidates via AskUserQuestion multiSelect with Tier 1 pre-selected
- Autonomously create memory files using skill-memory's template and slug patterns
- Batch-regenerate all three memory indexes after creation
- Deduplicate candidates against existing `memory-index.json` entries
- Fix `.opencode/memory/` path references to `.memory/`

**Non-Goals**:
- Modifying the upstream agent emission pipeline (task 446 scope)
- Implementing UPDATE operations for existing memories (deferred to `/learn --task N`)
- Adding new fields to the `memory_candidates` schema in return-metadata-file.md
- Modifying skill-memory itself

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| No tasks currently have `memory_candidates` populated, preventing live testing | M | H | Use `// []` fallback everywhere; validate logic structurally against schema |
| AskUserQuestion multiSelect may not support native pre-selection | M | M | Present Tier 1 candidates first with `[PRE-SELECTED]` label; user can deselect |
| Memory creation fails mid-batch leaving indexes inconsistent | L | L | Index regeneration is from-filesystem-state (self-healing); partial writes produce consistent indexes |
| Slug collision with existing memory files | L | L | Collision-check with numeric suffix fallback, matching skill-memory pattern |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Rewrite Stage 7 (HarvestMemories) [COMPLETED]

**Goal**: Replace heuristic artifact scanning with structured consumption of `memory_candidates` from state.json, including deduplication and three-tier classification.

**Tasks**:
- [ ] Replace the entire `<stage id="7" name="HarvestMemories">` block (lines 154-171) with the new structured pipeline
- [ ] Add candidate collection: for each completed task, read `memory_candidates // []` from the task's state.json entry, flatten into a single list with task number provenance
- [ ] Add deduplication step: validate-on-read `memory-index.json`, then compute keyword overlap for each candidate against all index entries (>90% = NOOP, >60% = UPDATE warning, <=60% = CREATE)
- [ ] Add three-tier classification logic: Tier 1 (category in [PATTERN, CONFIG] AND confidence >= 0.8), Tier 2 (category in [WORKFLOW, TECHNIQUE] AND confidence >= 0.5), Tier 3 (category == INSIGHT OR confidence < 0.5)
- [ ] Store the classified candidate list (with tier, dedup action, and provenance) for use by Stage 9

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-todo/SKILL.md` - Stage 7 block (lines 154-171)

**Verification**:
- Stage 7 block references `memory_candidates` from state.json, not artifact file scanning
- Dedup algorithm uses keyword overlap with 90%/60% thresholds
- Three tiers are defined with the correct category and confidence criteria
- Edge cases handled: no candidates (skip), empty memory-index.json (skip dedup), all NOOP after dedup (skip prompt)

---

### Phase 2: Rewrite Stage 9 sub-step 4 (InteractivePrompts) [COMPLETED]

**Goal**: Replace the simple multiSelect memory prompt with tiered AskUserQuestion presentation showing pre-selected Tier 1 candidates, visible Tier 2 candidates, and a "Show Tier 3" expansion option.

**Tasks**:
- [ ] Replace Stage 9 sub-step 4 (line 195) with the tiered AskUserQuestion block
- [ ] Format each option as: `[TIER N] [CATEGORY] Task {N}: {content summary} (confidence: {X.XX})` with dedup warnings for UPDATE candidates
- [ ] Add Tier 1 pre-selection: list Tier 1 candidates first with `[PRE-SELECTED]` label
- [ ] Add Tier 3 expansion: include a `Show {N} more candidates (Tier 3)` option at the bottom; if selected, re-prompt with all tiers visible
- [ ] Add skip logic: if no candidates remain after dedup filtering (all NOOP), skip this sub-step entirely
- [ ] Store user-approved candidates for Stage 14

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-todo/SKILL.md` - Stage 9 sub-step 4 (line 195)

**Verification**:
- Tier 1 candidates appear first and are labeled as pre-selected
- Tier 2 candidates appear after Tier 1 without pre-selection
- Tier 3 candidates are hidden behind an expansion option
- UPDATE-flagged candidates show a warning label
- Empty candidate list skips the prompt entirely

---

### Phase 3: Rewrite Stage 14 (CreateMemories) [COMPLETED]

**Goal**: Replace the stub memory creation with autonomous file creation using skill-memory's template and slug patterns, followed by batch index regeneration.

**Tasks**:
- [ ] Replace the entire `<stage id="14" name="CreateMemories">` block (lines 645-653) with the new creation pipeline
- [ ] Fix path references from `.opencode/memory/` to `.memory/`
- [ ] Add slug generation: use skill-memory's `generate_slug()` algorithm (topic + title, sanitized, collision-checked against `.memory/10-Memories/`)
- [ ] Add memory file creation: write `MEM-{slug}.md` using template at `.memory/30-Templates/memory-template.md` with field mapping: `content` -> body, `category` -> first tag, `suggested_keywords` -> keywords, `content` first 60 chars -> summary, `source_artifact` -> source, `retrieval_count: 0`, `last_retrieved: null`, `token_count: word_count * 1.3`
- [ ] Add batch index regeneration after ALL memories are created: regenerate `.memory/memory-index.json`, `.memory/20-Indices/index.md`, and `.memory/10-Memories/README.md`
- [ ] Add candidate cleanup note: `memory_candidates` field is implicitly cleaned when the task entry is moved to archive during Stage 10

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- `.claude/skills/skill-todo/SKILL.md` - Stage 14 block (lines 645-653)

**Verification**:
- Memory files are written to `.memory/10-Memories/MEM-{slug}.md` (not `.opencode/`)
- Template field mapping covers all candidate fields
- Slug collision check with numeric suffix fallback is specified
- Index regeneration happens once after all memories, not per-memory
- All three indexes are listed (memory-index.json, index.md, README.md)

---

### Phase 4: Update Supporting Stages and Validate Consistency [COMPLETED]

**Goal**: Update Stage 8 (DryRunOutput) and Stage 16 (OutputResults) to reflect the new tiered candidate model, and verify cross-stage data flow consistency.

**Tasks**:
- [ ] Update Stage 8 (DryRunOutput) to display tiered candidate counts instead of raw "suggestions count" (e.g., "Memory candidates: 3 Tier 1, 2 Tier 2, 1 Tier 3 (4 after dedup)")
- [ ] Update Stage 16 (OutputResults) to report tiered creation results (e.g., "Memory harvest: 3 created (2 Tier 1, 1 Tier 2), 1 skipped (NOOP)")
- [ ] Verify data flow: Stage 7 produces classified list -> Stage 8 reads it for dry run -> Stage 9 reads it for interactive prompt -> Stage 14 reads approved list for creation
- [ ] Verify edge case handling is consistent across all modified stages: no candidates, all NOOP, zero memories in vault
- [ ] Review the complete modified SKILL.md for internal consistency (variable names, stage references, checkpoint markers)

**Timing**: 30 minutes

**Depends on**: 3

**Files to modify**:
- `.claude/skills/skill-todo/SKILL.md` - Stage 8 (line 173-186) and Stage 16 (line 664-669)

**Verification**:
- Stage 8 dry run output includes tier breakdown
- Stage 16 results include tier-aware creation counts
- All four modified stages (7, 9, 14, 8/16) reference consistent variable names for the candidate list
- Edge cases produce sensible output in both dry run and live modes

## Testing & Validation

- [ ] Read the modified SKILL.md end-to-end and verify all stage cross-references are consistent
- [ ] Verify Stage 7 handles the case where `memory_candidates` is absent from a task entry (uses `// []` fallback)
- [ ] Verify Stage 9 handles zero candidates (skips prompt), all NOOP (skips prompt), and mixed tiers (shows tiered list)
- [ ] Verify Stage 14 path references use `.memory/` not `.opencode/memory/`
- [ ] Verify Stage 14 batch index regeneration covers all three index files
- [ ] Verify dedup thresholds match research report (90% NOOP, 60% UPDATE, below CREATE)
- [ ] Verify tier classification criteria match task description (Tier 1: PATTERN/CONFIG + confidence >= 0.8, Tier 2: WORKFLOW/TECHNIQUE + confidence >= 0.5, Tier 3: INSIGHT or confidence < 0.5)

## Artifacts & Outputs

- `specs/447_upgrade_todo_memory_harvest_pre_classification/plans/01_todo-harvest-plan.md` (this plan)
- `.claude/skills/skill-todo/SKILL.md` (modified file, single target)

## Rollback/Contingency

The modification is confined to a single file (`.claude/skills/skill-todo/SKILL.md`). If the implementation introduces regressions, revert the file using `git checkout HEAD -- .claude/skills/skill-todo/SKILL.md`. The old heuristic scanning approach and stub creation logic will be fully restored since no other files are affected.
