# Implementation Plan: Distill Combine Operation with Keyword Superset Guarantee

- **Task**: 451 - Implement distill combine operation with keyword superset guarantee
- **Status**: [IMPLEMENTING]
- **Effort**: 3.5 hours
- **Dependencies**: Task #449 (completed)
- **Research Inputs**: specs/451_implement_distill_combine_keyword_superset_guarantee/reports/01_distill-combine-research.md
- **Artifacts**: plans/01_distill-combine-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan implements the COMBINE/MERGE operation for `/distill --merge`, enabling identification of duplicate memories via pairwise keyword overlap, interactive selection by topic cluster, content merging with keyword superset enforcement, tombstoning of absorbed secondaries, cross-reference cleanup, and index regeneration. The research report confirms all supporting infrastructure exists (scoring engine, distill-log schema, command dispatch framework) and that the two files requiring modification are SKILL.md and distill.md within the memory extension.

### Research Integration

Key findings from the research report:
- The merge sub-mode is currently a placeholder returning "not yet implemented"
- The duplicate score formula (asymmetric overlap) is already defined in SKILL.md lines 1009-1019; for merge, use max of both directions per pair
- Topic-cluster grouping via `topic.split("/")[0]` exists at SKILL.md lines 1033-1043
- Tombstone pattern (`status: tombstoned`, `tombstoned_at`, `tombstone_reason`) is defined identically in task 450; implement independently since 450 may not land first
- The vault currently has only 1 memory, so edge case handling for insufficient memories is essential
- Three indexes require regeneration post-merge: memory-index.json, index.md, 10-Memories/README.md
- Distill-log schema already supports a `merge` operation type

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task does not directly advance any current ROADMAP.md items. It is part of the memory distillation system (tasks 449-454) which is an infrastructure feature for the memory extension.

## Goals & Non-Goals

**Goals**:
- Implement pairwise keyword overlap computation within topic clusters with 60% threshold
- Provide interactive merge candidate selection via AskUserQuestion per cluster
- Execute content merges with verified keyword superset guarantee (union of both keyword sets)
- Tombstone secondary memories with `merged_into:{primary_id}` reason
- Update cross-references across all non-tombstoned memories
- Regenerate all three memory indexes after merge completion
- Log each merge operation to distill-log.json with full before/after metrics
- Handle edge cases: fewer than 2 memories, no candidates above threshold, dry-run mode

**Non-Goals**:
- Implementing the purge, compress, or refine sub-modes (separate tasks 450, 452)
- Automatic merge without user confirmation
- Changing the existing scoring engine formulas
- Supporting merge of more than 2 memories at once (pairs only)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Keyword superset guarantee violated by implementation bug | H | L | Explicit assertion check before writing merged file; abort merge and preserve originals if violated |
| Cross-reference scan misses wiki-link references | M | L | Grep all `.memory/10-Memories/*.md` files for `[[{secondary_id}]]` pattern; log all replacements |
| Tombstone pattern conflicts with task 450 if it lands first | L | M | Both tasks define identical fields; whichever lands first establishes the pattern, second is a no-op |
| Index regeneration fails mid-operation | M | L | Complete all merges before regenerating indexes in a single pass |
| SKILL.md section placement conflicts with existing content | L | L | Carefully read surrounding sections before inserting; place after existing distill sub-mode docs |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Add merge sub-mode specification to SKILL.md [IN PROGRESS]

**Goal**: Define the complete merge algorithm, merge content template, tombstone pattern, cross-reference cleanup procedure, and logging schema in SKILL.md so the agent has full instructions when executing `/distill --merge`.

**Tasks**:
- [ ] Read current SKILL.md to identify exact insertion point (after existing distill sub-mode documentation, before the distill-log schema section)
- [ ] Write the `### Sub-Mode: merge` section containing:
  - Edge case checks (fewer than 2 non-tombstoned memories -> early exit with message)
  - Validate-on-read step before candidate identification
  - Pairwise keyword overlap algorithm within topic clusters using max of both asymmetric directions
  - 60% threshold filtering and descending overlap ranking
  - AskUserQuestion template per topic cluster with pair details (overlap %, shared keywords, retrieval counts)
  - Primary determination rule (higher retrieval_count; if equal, older created date)
  - Merged content template with frontmatter field merging rules (union keywords, union tags, combined retrieval_count, earliest created, max last_retrieved, recomputed token_count)
  - `## Merged From {secondary_id}` section format with original title, merge date, overlap score, secondary content
  - Connections section merging (union of both, with secondary self-references updated)
  - Keyword superset guarantee assertion: verify `set(merged.keywords) >= union(primary.keywords, secondary.keywords)` before writing; abort merge on failure
  - Tombstone application for secondary: add `status: tombstoned`, `tombstoned_at: {ISO8601}`, `tombstone_reason: "merged_into:{primary_id}"` while preserving existing frontmatter
  - Cross-reference update procedure: scan all non-tombstoned memories for `[[{secondary_id}]]`, replace with `[[{primary_id}]]`
  - Index regeneration trigger: after all merges complete, regenerate memory-index.json, index.md, 10-Memories/README.md
  - Dry-run mode: when `--dry-run` is set, compute and display candidates without writing any files
  - Distill-log entry schema for merge operations: primary, secondary, overlap_score, keywords_before (array of primary + secondary keyword counts), keywords_after (merged count), keyword_superset_verified (boolean), action: "merged"

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` - Add `### Sub-Mode: merge` section

**Verification**:
- The merge sub-mode section exists in SKILL.md with all required subsections
- The keyword superset guarantee is documented with explicit assertion logic
- The tombstone pattern matches the purge pattern from task 450 description
- The AskUserQuestion template includes cluster name, pair names, overlap %, shared keywords

---

### Phase 2: Update distill.md command dispatch [NOT STARTED]

**Goal**: Enable the `/distill --merge` command to route through to the merge sub-mode instead of returning the "not yet implemented" placeholder.

**Tasks**:
- [ ] Read current distill.md to locate the sub-mode availability table and placeholder check
- [ ] Update the sub-mode availability table to mark `merge` as "Available"
- [ ] Update the placeholder check (around lines 76-80) to allow `merge` through to skill delegation
- [ ] Verify the `--dry-run` flag is already parsed and passed through (research confirms it is)
- [ ] Ensure the delegation to `skill-memory mode=distill, sub_mode=merge` includes all necessary context (dry_run flag, session_id)

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/memory/commands/distill.md` - Update availability table and remove merge placeholder

**Verification**:
- The `merge` sub-mode is listed as "Available" in the availability table
- The placeholder check no longer blocks `merge`
- Running `/distill --merge` would route to skill-memory with `sub_mode=merge`
- Running `/distill --merge --dry-run` passes the dry-run flag through

---

### Phase 3: Validation and edge case testing [NOT STARTED]

**Goal**: Verify the implementation is correct by reading both modified files end-to-end, checking cross-references, and confirming edge case handling.

**Tasks**:
- [ ] Re-read the complete merge sub-mode section in SKILL.md and verify:
  - All 10 task description requirements are addressed (candidate identification, interactive selection, primary determination, content merge, keyword superset guarantee, frontmatter updates, tombstone secondary, cross-reference cleanup, index regeneration, logging)
  - The pairwise overlap algorithm matches the research recommendation (max of both asymmetric directions)
  - Edge cases documented: fewer than 2 memories, no pairs above threshold, dry-run mode, empty keyword arrays
- [ ] Re-read distill.md and verify dispatch routes correctly
- [ ] Verify no references to the merge sub-mode were missed in other sections of SKILL.md (e.g., the health report scoring section should not need changes since it already computes duplicate scores)
- [ ] Check that the distill-log schema section in SKILL.md accommodates the merge operation type (research confirms it does, but verify the fields match what Phase 1 defined)
- [ ] Verify tombstone pattern is consistent with task 450's description (both should define identical frontmatter fields)

**Timing**: 0.5 hours

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` - Fix any issues found during validation
- `.claude/extensions/memory/commands/distill.md` - Fix any issues found during validation

**Verification**:
- All 10 explicit requirements from the task description are traceable to SKILL.md sections
- No inconsistencies between distill.md dispatch and SKILL.md merge sub-mode
- Edge cases have documented handling with user-friendly messages
- Tombstone fields match task 450 specification exactly

## Testing & Validation

- [ ] SKILL.md contains a `### Sub-Mode: merge` section with complete algorithm
- [ ] Keyword superset guarantee has explicit assertion documented with abort-on-failure behavior
- [ ] Pairwise overlap uses max of both asymmetric directions with 60% threshold
- [ ] AskUserQuestion template includes topic cluster name, pair names, overlap %, shared keywords
- [ ] Primary determination: higher retrieval_count wins, older created date as tiebreaker
- [ ] Merged content template includes `## Merged From {secondary_id}` section
- [ ] Tombstone fields: `status: tombstoned`, `tombstoned_at`, `tombstone_reason: "merged_into:{primary_id}"`
- [ ] Cross-reference update scans all non-tombstoned memories for `[[{secondary_id}]]`
- [ ] Index regeneration triggers after all merges (not after each individual merge)
- [ ] Dry-run mode computes and displays without writing
- [ ] Edge case: fewer than 2 memories exits with informative message
- [ ] Edge case: no pairs above threshold exits with informative message
- [ ] distill.md marks `merge` as Available and removes placeholder block
- [ ] Distill-log entry includes keyword_superset_verified boolean flag

## Artifacts & Outputs

- `specs/451_implement_distill_combine_keyword_superset_guarantee/plans/01_distill-combine-plan.md` (this plan)
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` (modified -- merge sub-mode section added)
- `.claude/extensions/memory/commands/distill.md` (modified -- merge availability enabled)

## Rollback/Contingency

Both modified files are under git version control. If the implementation introduces issues:
- `git checkout HEAD -- .claude/extensions/memory/skills/skill-memory/SKILL.md` to restore SKILL.md
- `git checkout HEAD -- .claude/extensions/memory/commands/distill.md` to restore distill.md
- The merge sub-mode is isolated from other sub-modes, so removal does not affect purge, compress, or refine operations
- No runtime code is modified (only markdown skill/command definitions), so rollback carries no risk of breaking running systems
