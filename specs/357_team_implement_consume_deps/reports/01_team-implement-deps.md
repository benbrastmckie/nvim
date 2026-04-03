# Research Report: Task #357

**Task**: 357 - Update skill-team-implement to consume plan dependency analysis
**Started**: 2026-04-03
**Completed**: 2026-04-03
**Dependencies**: 356 (completed)
**Sources/Inputs**: skill-team-implement/SKILL.md (Stage 5-6), plan-format.md (updated in task 356)

## Executive Summary

skill-team-implement Stage 5 and Stage 6 currently use heuristic inference to determine phase dependencies and wave groupings. Task 356 added explicit `**Depends on**:` fields and a `**Dependency Analysis**` wave table to the plan format. This task updates Stage 5 and 6 to prefer the explicit plan data, with fallback to heuristic inference for backward compatibility with older plans.

## Current State

### Stage 5: Analyze Phase Dependencies (lines 183-212)

Three dependency sources listed:
1. "Explicit dependencies from plan metadata" -- now available via `**Depends on**:` fields
2. "Implicit dependencies from file modifications" -- heuristic fallback
3. "Cross-phase imports or references" -- heuristic fallback

The pseudocode builds a dependency graph from `phase.dependencies` and `phase.files_modified`. The code structure already expects explicit dependencies but had nothing to read before task 356.

### Stage 6: Calculate Implementation Waves (lines 215-231)

Computes waves from scratch using a topological sort approach. With the new plan format, the `**Dependency Analysis**` wave table provides pre-computed waves that can be read directly.

## Proposed Changes

### Stage 5: Prefer Explicit Dependencies

Replace the three-source heuristic approach with:
1. **Primary**: Parse `**Depends on**:` fields from each phase in the plan
2. **Fallback**: If no `Depends on` fields found, use existing heuristic inference (file overlap analysis)

The pseudocode should check for explicit dependency data first and only fall back to heuristics when plans lack the new fields.

### Stage 6: Read Wave Table When Available

Replace the compute-from-scratch approach with:
1. **Primary**: Parse the `**Dependency Analysis**` wave table from the plan
2. **Fallback**: If no wave table found, compute waves from dependency graph (existing logic)

## Files to Modify

1. `.claude/skills/skill-team-implement/SKILL.md` -- Stage 5 and Stage 6

## Backward Compatibility

- Plans without `Depends on` fields: Heuristic inference continues working (no change)
- Plans without wave table: Stage 6 computes waves from dependency graph (no change)
- Plans with both: Explicit data takes priority, heuristics skipped
