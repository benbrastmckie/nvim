# Implementation Summary: Task #447

- **Task**: 447 - Upgrade /todo memory harvest with pre-classification and batch review
- **Status**: [COMPLETED]
- **Started**: 2026-04-16
- **Completed**: 2026-04-16
- **Effort**: 3 hours (estimated), ~45 minutes (actual)
- **Artifacts**: summaries/01_todo-harvest-summary.md (this file)
- **Standards**: summary-format.md, plan-format.md

## Overview

Replaced the heuristic artifact-scanning approach in skill-todo's memory harvest pipeline with structured consumption of `memory_candidates` from state.json. The new pipeline reads pre-emitted candidates from agents (task 446 infrastructure), deduplicates against `memory-index.json`, applies three-tier classification, presents them via tiered AskUserQuestion multiSelect, and autonomously creates memory files with batch index regeneration.

## What Changed

All modifications were confined to a single file: `.claude/skills/skill-todo/SKILL.md`.

### Stage 7 (HarvestMemories) -- Complete Rewrite
- Replaced heuristic artifact scanning (reports/, plans/, summaries/) with structured consumption of `memory_candidates // []` from state.json task entries
- Added Jaccard-like keyword overlap deduplication against `.memory/memory-index.json` with three thresholds: >90% NOOP, >60% UPDATE warning, <=60% CREATE
- Added three-tier classification: Tier 1 (PATTERN/CONFIG, confidence >= 0.8), Tier 2 (WORKFLOW/TECHNIQUE, confidence >= 0.5), Tier 3 (INSIGHT or confidence < 0.5)
- Edge cases: no candidates (skip), empty memory-index.json (skip dedup), all NOOP (skip)

### Stage 9 sub-step 4 (InteractivePrompts) -- Complete Rewrite
- Replaced simple multiSelect with tiered presentation: Tier 1 pre-selected, Tier 2 shown, Tier 3 hidden behind expansion option
- Added UPDATE warning labels for candidates with >60% keyword overlap
- Added Tier 3 expansion: "Show N more candidates" triggers re-prompt with all tiers visible
- Output stored as `approved_memories` for Stage 14

### Stage 14 (CreateMemories) -- Complete Rewrite
- Fixed path references from `.opencode/memory/` to `.memory/`
- Added slug generation with collision-check and numeric suffix fallback
- Added template-based memory file creation using `.memory/30-Templates/memory-template.md`
- Added field mapping: content, category, keywords, source_artifact, confidence -> frontmatter fields
- Added batch index regeneration after all files created: memory-index.json, index.md, README.md

### Stage 8 (DryRunOutput) -- Updated
- Replaced "Memory harvest suggestions count" with tiered breakdown format: "Memory candidates: T1 Tier 1, T2 Tier 2, T3 Tier 3 (N after dedup, M NOOP excluded)"

### Stage 16 (OutputResults) -- Updated
- Replaced single-line memory count with tier-aware creation results: "Memory harvest: N created (T1 Tier 1, T2 Tier 2, T3 Tier 3), M skipped (NOOP), K declined"

## Decisions

1. **Dedup before classification**: Deduplication runs before tier assignment so NOOP candidates are excluded from tier counts and prompt entirely
2. **Tier 3 expansion pattern**: Hidden by default with opt-in expansion rather than a separate prompt, reducing interaction steps
3. **Batch index regeneration**: Indexes rebuilt once after all memory files are written, not per-file, for consistency and efficiency
4. **Implicit cleanup**: `memory_candidates` are cleaned when task entries move to archive in Stage 10, requiring no explicit cleanup step

## Impacts

- **Upstream dependency**: Requires task 446 infrastructure (memory_candidates emission pipeline) to produce candidates; without candidates, the pipeline gracefully no-ops
- **No breaking changes**: Empty `memory_candidates` array is handled via `// []` fallback at every stage
- **Memory system**: New memories are created at `.memory/10-Memories/MEM-{slug}.md` using the standard template

## Follow-ups

- No immediate follow-ups required; the pipeline is complete
- UPDATE operations for existing memories (dedup_action == "UPDATE") are deferred to `/learn --task N` (separate task scope)

## References

- Plan: `specs/447_upgrade_todo_memory_harvest_pre_classification/plans/01_todo-harvest-plan.md`
- Research: `specs/447_upgrade_todo_memory_harvest_pre_classification/reports/01_todo-harvest-research.md`
- Modified file: `.claude/skills/skill-todo/SKILL.md`
