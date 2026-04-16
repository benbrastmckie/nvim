# Implementation Plan: /distill Command, Scoring Engine, and Health Report

- **Task**: 449 - Create /distill command with scoring engine and health report
- **Status**: [IMPLEMENTING]
- **Effort**: 4 hours
- **Dependencies**: Task 444 (completed)
- **Research Inputs**: specs/449_create_distill_command_scoring_engine_health_report/reports/01_distill-command-research.md
- **Artifacts**: plans/01_distill-command-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan implements the foundation for all distillation operations: the `/distill` command file, scoring engine (staleness, zero-retrieval, size, duplicate), health report generator, distill-log.json infrastructure, and the memory_health field in state.json. The scoring engine and health report are embedded in skill-memory's SKILL.md as a `mode=distill` section. Tasks 450-453 depend on this foundation.

### Research Integration

Key findings from the research report:
- memory-index.json (from task 444) provides all data fields needed for scoring (created, last_retrieved, retrieval_count, token_count, keywords)
- The `/learn` command pattern provides the closest template for `/distill` (Layer 2 command delegating to skill-memory)
- Validate-on-read must precede scoring to ensure index accuracy
- memory_health is a top-level state.json field parallel to repository_health

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Create `/distill` command file with argument parsing and skill delegation
- Implement four-component scoring engine (staleness, zero-retrieval, size, duplicate) in SKILL.md
- Build health report generator producing formatted vault health output
- Create distill-log.json schema and seed file
- Add memory_health field to state.json
- Register distill.md in manifest.json and update extension docs

**Non-Goals**:
- Implementing purge, merge, compress, or refine operations (tasks 450-452)
- Implementing --auto flag behavior (task 452)
- Integrating with /todo (task 453)
- Modifying memory-index.json schema (already complete from task 444)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| memory-index.json stale during scoring | Incorrect health scores | M | Mandatory validate-on-read step before scoring |
| Pairwise keyword comparison slow | Slow report for large vaults | L | N expected < 100; O(N^2) acceptable |
| SKILL.md becomes too large with distill mode | Readability degradation | M | Use clear section headers; distill mode is self-contained |
| state.json schema change breaks consumers | Parse failures | L | memory_health is additive (new field); no existing consumers affected |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Create /distill Command File and Register in Extension [COMPLETED]

**Goal**: Create the Layer 2 command file that parses arguments and delegates to skill-memory with mode=distill, and register it in the memory extension.

**Tasks**:
- [ ] Create `.claude/extensions/memory/commands/distill.md` with YAML frontmatter (description, allowed-tools, argument-hint, model)
- [ ] Define argument parsing: bare invocation (health report), placeholder flags for future sub-modes (--purge, --merge, --compress, --auto, --gc)
- [ ] Define execution flow: parse flags -> delegate to skill-memory mode=distill -> present results -> git commit
- [ ] Add error handling section
- [ ] Update `.claude/extensions/memory/manifest.json`: add `"distill.md"` to `provides.commands`
- [ ] Update `.claude/extensions/memory/EXTENSION.md`: add `/distill` to command reference table
- [ ] Update `.claude/extensions/memory/index-entries.json`: add distill-related context entry

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/extensions/memory/commands/distill.md` - Create new command file
- `.claude/extensions/memory/manifest.json` - Add distill.md to provides.commands
- `.claude/extensions/memory/EXTENSION.md` - Add /distill command documentation
- `.claude/extensions/memory/index-entries.json` - Add distill context entry

**Verification**:
- distill.md follows the same frontmatter pattern as learn.md
- manifest.json includes "distill.md" in provides.commands array
- EXTENSION.md has /distill in command table

---

### Phase 2: Implement Scoring Engine in SKILL.md [COMPLETED]

**Goal**: Add the four-component scoring engine to skill-memory's SKILL.md as part of the mode=distill section.

**Tasks**:
- [ ] Add `## Mode: distill` section header after existing modes in SKILL.md
- [ ] Document validate-on-read prerequisite (reference existing pattern from task 444)
- [ ] Implement staleness scoring: `min(1.0, days_since_last_retrieval / 90)` with FSRS adjustment (`-0.3` if retrieval_count > 0 AND days_since_created > 60, clamped to 0)
- [ ] Implement zero-retrieval penalty: `1.0` if `retrieval_count == 0 AND days_since_created > 30`, else `0.0`
- [ ] Implement size penalty: `max(0, (token_count - 600) / 600)` linear above 600 tokens
- [ ] Implement duplicate score: highest keyword overlap (Jaccard-like `|A intersect B| / |A|`) with any other memory
- [ ] Define composite formula: `(staleness * 0.3) + (zero_retrieval * 0.25) + (size * 0.2) + (duplicate * 0.25)` clamped 0-1
- [ ] Document topic-cluster grouping (first path segment as cluster key)
- [ ] Define sub-mode dispatch table (report for this task; purge/merge/compress/refine/gc as placeholders for 450-452)

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` - Add mode=distill section with scoring engine

**Verification**:
- All four scoring components documented with exact formulas
- Composite formula matches task specification
- Validate-on-read referenced before scoring
- Sub-mode dispatch table present with placeholder entries

---

### Phase 3: Build Health Report Generator and State Infrastructure [COMPLETED]

**Goal**: Define the health report output format in SKILL.md, create distill-log.json seed file, and add memory_health to state.json.

**Tasks**:
- [ ] Add health report template to SKILL.md mode=distill section with all sections: Overview, Category Distribution, Topic Clusters, Retrieval Statistics, Maintenance Candidates, Health Score
- [ ] Define health score formula: `100 - (purge * 3) - (merge * 5) - (compress * 2)` clamped [0, 100]
- [ ] Define status thresholds: healthy (80-100), manageable (60-79), concerning (40-59), critical (0-39)
- [ ] Create `.memory/distill-log.json` seed file with version, empty operations array, and zeroed summary
- [ ] Add `memory_health` field to `specs/state.json` as top-level sibling of repository_health with fields: last_distilled (null), distill_count (0), total_memories, never_retrieved, health_score (100), status ("healthy")
- [ ] Document distill-log.json schema in SKILL.md (operation types, pre/post metrics, summary fields)

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` - Add health report template and distill-log schema
- `.memory/distill-log.json` - Create seed file
- `specs/state.json` - Add memory_health top-level field

**Verification**:
- Health report template includes all sections from research
- distill-log.json is valid JSON with correct schema
- state.json has memory_health field parallel to repository_health
- Health status thresholds match repository_health vocabulary

---

### Phase 4: Integration and Cross-Reference Sweep [COMPLETED]

**Goal**: Ensure all components are wired together and cross-references are consistent across the extension.

**Tasks**:
- [ ] Verify SKILL.md mode=distill references the distill-log.json path correctly
- [ ] Verify SKILL.md documents the memory_health state.json update trigger
- [ ] Verify distill.md command file correctly references mode=distill delegation
- [ ] Verify manifest.json routing is correct for distill operations
- [ ] Check all file paths in SKILL.md match actual filesystem locations
- [ ] Run `.claude/scripts/check-extension-docs.sh` to validate extension documentation

**Timing**: 0.25 hours

**Depends on**: 2, 3

**Files to modify**:
- Any files needing cross-reference corrections (discovered during sweep)

**Verification**:
- check-extension-docs.sh passes without errors
- All internal cross-references resolve to existing files/sections
- Command delegates to correct skill mode

---

### Phase 5: End-to-End Validation [COMPLETED]

**Goal**: Verify the complete /distill pipeline works from command invocation through report generation.

**Tasks**:
- [ ] Read distill.md and trace execution flow through SKILL.md mode=distill
- [ ] Verify scoring engine formulas match research specification exactly
- [ ] Verify health report template includes all required sections
- [ ] Verify distill-log.json schema supports all planned operation types (report, purge, merge, compress, refine, gc)
- [ ] Verify memory_health field in state.json has correct initial values
- [ ] Confirm downstream tasks 450-453 have clear extension points in the sub-mode dispatch table

**Timing**: 0.25 hours

**Depends on**: 4

**Files to modify**:
- None expected (read-only validation)

**Verification**:
- All scoring formulas match: staleness (0.3 weight), zero-retrieval (0.25), size (0.2), duplicate (0.25)
- Health score formula: 100 - (purge * 3) - (merge * 5) - (compress * 2)
- Status thresholds: healthy >= 80, manageable >= 60, concerning >= 40, critical < 40
- Sub-mode dispatch table has entries for all 450-453 operations

## Testing & Validation

- [ ] distill.md has valid YAML frontmatter with correct allowed-tools
- [ ] manifest.json is valid JSON with distill.md in provides.commands
- [ ] SKILL.md mode=distill section contains all four scoring components
- [ ] Composite scoring formula weights sum to 1.0 (0.3 + 0.25 + 0.2 + 0.25)
- [ ] distill-log.json is valid JSON with correct seed structure
- [ ] state.json is valid JSON with memory_health field
- [ ] check-extension-docs.sh passes
- [ ] All cross-references between command, skill, log, and state files are consistent

## Artifacts & Outputs

- `.claude/extensions/memory/commands/distill.md` - /distill command file
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` - Updated with mode=distill (scoring engine, health report, distill-log schema)
- `.claude/extensions/memory/manifest.json` - Updated with distill.md registration
- `.claude/extensions/memory/EXTENSION.md` - Updated with /distill documentation
- `.claude/extensions/memory/index-entries.json` - Updated with distill context entry
- `.memory/distill-log.json` - Seed file for distillation operation log
- `specs/state.json` - Updated with memory_health field

## Rollback/Contingency

All changes are additive (new files or new fields in existing files). Rollback involves:
1. Remove `.claude/extensions/memory/commands/distill.md`
2. Remove mode=distill section from SKILL.md
3. Remove "distill.md" from manifest.json provides.commands
4. Remove /distill row from EXTENSION.md
5. Remove distill entry from index-entries.json
6. Remove `.memory/distill-log.json`
7. Remove memory_health field from state.json

Git revert of the implementation commit(s) accomplishes all of the above.
