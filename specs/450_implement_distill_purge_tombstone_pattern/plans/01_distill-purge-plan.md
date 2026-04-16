# Implementation Plan: Distill Purge with Tombstone Pattern

- **Task**: 450 - Implement distill purge operation with tombstone pattern
- **Status**: [IMPLEMENTING]
- **Effort**: 3.5 hours
- **Dependencies**: Task #449 (completed)
- **Research Inputs**: specs/450_implement_distill_purge_tombstone_pattern/reports/01_distill-purge-research.md
- **Artifacts**: plans/01_distill-purge-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Implement the purge sub-mode and gc sub-mode in the distill pipeline. The purge operation identifies stale or zero-retrieval memories using the existing scoring engine, presents candidates interactively, and applies a tombstone pattern (frontmatter mutation) rather than deleting files. The gc operation performs hard deletion of tombstoned memories past a 7-day grace period. Both operations include link-scan warnings and distill-log.json logging.

### Research Integration

Key findings from research report:
- Purge candidate criteria are OR-based: `zero_retrieval_penalty == 1.0` OR `staleness_score > 0.8`
- Category-aware TTL thresholds (CONFIG: 180d, WORKFLOW: 365d, PATTERN: 540d, TECHNIQUE: 270d, INSIGHT: none) affect ranking only, not automatic action
- Tombstone adds three frontmatter fields (`status: tombstoned`, `tombstoned_at`, `tombstone_reason`) without file deletion or index removal
- memory-index.json needs a `status` field (default: "active") for efficient filtering
- Retrieval exclusion is a post-filter on both MCP search and grep fallback paths
- GC should use multiSelect for consistency with purge selection pattern
- Link-scan targets `[[MEM-{slug}]]` patterns in Connections sections of non-tombstoned memories

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly correspond to this task. This is part of the memory distillation pipeline (tasks 449-454) which is an extension-level feature not yet tracked on the project roadmap.

## Goals & Non-Goals

**Goals**:
- Implement `--purge` sub-mode that identifies, presents, and tombstones stale memories
- Implement `--gc` sub-mode that hard-deletes tombstoned memories past 7-day grace period
- Update retrieval paths to exclude tombstoned memories
- Add link-scan warnings for stale `[[MEM-{slug}]]` references
- Log all operations to distill-log.json with pre/post metrics

**Non-Goals**:
- Merge/combine operation (task 451)
- Compress/refine operations (task 452)
- Integration with /todo suggestions (task 453)
- Automatic purging without user interaction
- Modifying referencing memories to remove stale links (warnings only)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Tombstoned memory accidentally retrieved | H | L | Post-filter on status field in both search paths; scoring engine exclusion |
| Index regeneration drops status field | H | M | Update JSON Index Maintenance section to include status field explicitly |
| Grace period miscalculation deletes too early | H | L | Strict ISO8601 comparison with 7-day threshold; gc requires explicit confirmation |
| SKILL.md edit conflicts with concurrent task 451 | M | M | Task 451 depends on 449, not 450; different SKILL.md sections; sequential execution expected |
| Large memory vault slow during link-scan | L | L | Link-scan is grep-based, O(n) over memory files; acceptable for expected vault sizes |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Purge Sub-Mode -- Candidate Identification and Tombstone Application [IN PROGRESS]

**Goal**: Implement the core purge pipeline in SKILL.md: candidate identification using scoring engine output, category-aware TTL ranking, AskUserQuestion interactive selection, and tombstone frontmatter mutation.

**Tasks**:
- [ ] Replace the purge placeholder in SKILL.md `mode=distill` sub-mode dispatch with full purge implementation
- [ ] Add purge candidate identification logic: select memories where `zero_retrieval_penalty == 1.0` OR `staleness_score > 0.8`
- [ ] Add category-aware TTL advisory thresholds table (CONFIG: 180d, WORKFLOW: 365d, PATTERN: 540d, TECHNIQUE: 270d, INSIGHT: no TTL)
- [ ] Implement TTL-based ranking: memories past their category TTL sorted to top, then by composite score descending
- [ ] Define AskUserQuestion multiSelect presentation format with score, created date, retrieval count, token count, category per candidate
- [ ] Implement tombstone application: add `status: tombstoned`, `tombstoned_at: ISO8601`, `tombstone_reason: "purge"` to selected memories' YAML frontmatter
- [ ] Update memory-index.json schema to include `status` field (default: "active", tombstoned entries get "tombstoned")
- [ ] Update the JSON Index Maintenance section in SKILL.md to document the `status` field and its handling during validate-on-read
- [ ] Handle edge case: zero purge candidates found (display "No purge candidates" message and exit)
- [ ] Handle `--dry-run` flag: show candidates and scores without applying tombstones

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` - Add purge sub-mode section with candidate identification, selection, and tombstone application

**Verification**:
- Purge sub-mode section exists in SKILL.md with complete candidate identification logic
- AskUserQuestion format matches existing patterns in SKILL.md
- Tombstone frontmatter fields are documented with exact field names and values
- memory-index.json status field schema is documented
- Dry-run behavior is specified

---

### Phase 2: Retrieval Exclusion and Link-Scan [NOT STARTED]

**Goal**: Update retrieval paths to skip tombstoned memories and implement the link-scan warning step that runs after tombstone application.

**Tasks**:
- [ ] Add tombstone post-filter to MCP Search Path section in SKILL.md: after results returned, exclude entries where memory-index.json `status == "tombstoned"`
- [ ] Add tombstone post-filter to Grep Fallback Path section: check frontmatter `status: tombstoned` and exclude from results
- [ ] Update Health Report template to add "Tombstoned Memories" section showing count and list of tombstoned entries
- [ ] Exclude tombstoned memories from composite scoring in the scoring engine (skip entries with `status: "tombstoned"`)
- [ ] Implement link-scan step: after tombstoning, grep all non-tombstoned `.memory/10-Memories/MEM-*.md` files for `[[MEM-{affected-slug}]]` patterns
- [ ] Display link-scan warnings to user (file path + referenced tombstoned slug); no automatic modification
- [ ] Include link-scan warnings in the purge operation's distill-log.json notes field

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` - Update Memory Search section (MCP + grep), Health Report template, scoring engine, add link-scan procedure

**Verification**:
- Both retrieval paths have explicit tombstone exclusion instructions
- Health report template includes tombstoned memories section
- Scoring engine specifies tombstoned exclusion
- Link-scan procedure uses correct `[[MEM-{slug}]]` grep pattern
- Warnings are display-only with no file modification

---

### Phase 3: GC Sub-Mode -- Hard Deletion [NOT STARTED]

**Goal**: Implement the `--gc` sub-mode that identifies tombstoned memories past the 7-day grace period and performs hard deletion with user confirmation.

**Tasks**:
- [ ] Replace the gc placeholder in SKILL.md `mode=distill` sub-mode dispatch with full gc implementation
- [ ] Implement grace period scan: find memory-index.json entries where `status == "tombstoned"` and `tombstoned_at` is older than 7 days from current date
- [ ] Present eligible memories via AskUserQuestion multiSelect (consistent with purge pattern) showing slug, tombstoned date, original score, reason
- [ ] On confirmation: delete the `.md` file from `.memory/10-Memories/`
- [ ] On confirmation: remove the entry from `memory-index.json`
- [ ] On confirmation: regenerate `index.md` and `.memory/10-Memories/README.md`
- [ ] On confirmation: update `memory_health` in state.json (decrement `total_memories`)
- [ ] Handle edge case: no tombstoned memories past grace period (display message and exit)
- [ ] Handle `--dry-run` flag: show eligible memories without deleting

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` - Add gc sub-mode section with grace period scan, confirmation, deletion, and index regeneration

**Verification**:
- GC sub-mode section exists with 7-day grace period calculation
- Deletion sequence covers file removal, index update, README regeneration, and state.json update
- multiSelect confirmation pattern is consistent with purge selection
- Dry-run behavior is specified

---

### Phase 4: Command File Update and Distill-Log Integration [NOT STARTED]

**Goal**: Update distill.md command file to reflect implemented status, ensure distill-log.json logging is complete for both operations, and verify cross-references.

**Tasks**:
- [ ] Update `.claude/extensions/memory/commands/distill.md` purge entry from "Placeholder (task 450)" to "Available (task 450)"
- [ ] Update `.claude/extensions/memory/commands/distill.md` gc entry from "Placeholder (task 452)" to "Available (task 450)" (gc for purge cleanup only; task 452 extends gc scope)
- [ ] Verify purge log entry format in SKILL.md matches distill-log.json schema: type "purge", pre/post metrics, affected_memories, notes with link-scan warnings
- [ ] Verify gc log entry format in SKILL.md matches distill-log.json schema: type "gc", pre/post metrics (total_memories decremented), affected_memories
- [ ] Verify purge post_metrics correctly show unchanged total_memories/total_tokens (tombstone preserves files) but decremented purge_candidates
- [ ] Verify gc post_metrics correctly show decremented total_memories and total_tokens
- [ ] Update distill-log.json summary schema reference: `memories_purged` counter incremented for tombstoned count, separate from gc hard-delete count
- [ ] Cross-reference check: ensure SKILL.md purge/gc sections reference the correct distill-log.json field names

**Timing**: 0.5 hours

**Depends on**: 2, 3

**Files to modify**:
- `.claude/extensions/memory/commands/distill.md` - Update placeholder entries to available
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` - Verify and finalize log entry formats (minor adjustments from phases 1-3)

**Verification**:
- distill.md dispatch table shows purge and gc as available
- Log entry examples in SKILL.md match distill-log.json schema exactly
- Pre/post metric semantics are correct for tombstone (no count change) vs gc (count decremented)
- All cross-references between SKILL.md sections are consistent

## Testing & Validation

- [ ] Purge candidate identification logic correctly applies OR condition on zero_retrieval_penalty and staleness_score
- [ ] Category TTL thresholds only affect ranking, not automatic selection
- [ ] Tombstone frontmatter fields are added to correct location in YAML (after summary, before token_count)
- [ ] memory-index.json status field defaults to "active" when absent
- [ ] MCP search path excludes tombstoned memories from results
- [ ] Grep fallback path excludes tombstoned memories from results
- [ ] Health report lists tombstoned memories separately from active
- [ ] Scoring engine skips tombstoned memories
- [ ] Link-scan finds `[[MEM-{slug}]]` references in non-tombstoned memories only
- [ ] GC grace period calculation correctly uses 7-day threshold
- [ ] GC deletion sequence removes file, index entry, regenerates README, updates state.json
- [ ] Dry-run mode shows candidates without applying changes for both purge and gc
- [ ] distill-log.json entries have correct type, metrics, and affected_memories fields

## Artifacts & Outputs

- `specs/450_implement_distill_purge_tombstone_pattern/plans/01_distill-purge-plan.md` (this file)
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` (modified -- purge sub-mode, gc sub-mode, retrieval exclusion, link-scan)
- `.claude/extensions/memory/commands/distill.md` (modified -- placeholder status updates)

## Rollback/Contingency

All changes are confined to SKILL.md instruction text and distill.md command routing. No runtime code or data files are modified during planning/implementation. To revert:
1. `git revert` the implementation commit to restore SKILL.md and distill.md to pre-task-450 state
2. memory-index.json schema addition (status field) is backward-compatible; existing entries without status default to "active"
3. Any memories tombstoned during testing can be un-tombstoned by removing the three frontmatter fields manually
