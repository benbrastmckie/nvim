# Implementation Plan: Memory System Documentation and End-to-End Validation

- **Task**: 454 - Memory system documentation and end-to-end validation
- **Status**: [NOT STARTED]
- **Effort**: 4 hours
- **Dependencies**: Tasks #448, #453 (both completed)
- **Research Inputs**: specs/454_memory_system_documentation_end_to_end_validation/reports/01_memory-docs-research.md
- **Artifacts**: plans/01_memory-docs-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This capstone task closes the memory system (tasks 444-453) by filling all documentation gaps and performing end-to-end validation. Research identified five documentation deliverables: a missing CLAUDE.md Memory Extension section, incomplete skill-memory README (no distill mode), missing context/index entries, a missing distill-usage.md context file, and stale EXTENSION.md placeholder markers. The plan also includes a structured validation pass covering 26 test cases across self-learning, distillation, and cross-cutting concerns. Definition of done: all documentation deliverables written, EXTENSION.md placeholders removed, index-entries.json corrected, and validation checklist documented with results.

### Research Integration

Key findings from the research report:
- Finding 1: CLAUDE.md has no Memory Extension section; merge_targets in manifest.json has never been executed.
- Finding 2: skill-memory README.md documents only standard and task modes; distill mode is absent.
- Finding 3: context/index.json has zero memory entries; index-entries.json has 6 entries with issues (duplicate, missing distill context).
- Finding 4: No distill-usage.md context file exists.
- Finding 5: `--reindex` does not exist as a feature; validate-on-read is the automatic equivalent.
- Finding 6: EXTENSION.md has stale "(placeholder)" markers for purge, merge, compress; missing refine, gc, auto entries.
- Finding 7: Auto-retrieval uses TOKEN_BUDGET=2000 (not 3000 as task description states).
- Finding 10: Tombstone exclusion is integrated in retrieval, scoring, and grep fallback.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task does not directly advance any current ROADMAP.md items. However, it contributes to the "Agent System Quality" theme by ensuring memory extension documentation is complete and consistent, which benefits future doc-lint enforcement and extension validation efforts.

## Goals & Non-Goals

**Goals**:
- Create CLAUDE.md Memory Extension section with commands, skill mapping, and lifecycle documentation
- Add distill mode documentation to skill-memory README.md
- Create distill-usage.md context file with sub-mode workflows and maintenance cadence
- Fix index-entries.json (deduplicate, add distill entries)
- Remove stale EXTENSION.md placeholder markers and add missing sub-modes
- Document validate-on-read as the reindex mechanism (no --reindex command)
- Produce documented validation results for 26 test cases

**Non-Goals**:
- Implementing new features (e.g., --reindex command)
- Changing TOKEN_BUDGET from 2000 to 3000 (document as-is; budget change is out of scope)
- Running live end-to-end tests (validation is documentation-based inspection, not runtime execution)
- Modifying ROADMAP.md

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| CLAUDE.md Memory Extension section conflicts with recent edits from task 455 | M | M | Read CLAUDE.md fresh before editing; insert section in a clean location |
| EXTENSION.md content drift since research was conducted | L | L | Re-read EXTENSION.md at implementation time; verify line content matches |
| index-entries.json schema inconsistency with core index.json | M | L | Verify entry format against existing core entries before writing |
| Validation checklist may reveal undocumented bugs | M | M | Log any discovered issues as follow-up tasks rather than blocking this task |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: EXTENSION.md Cleanup and CLAUDE.md Memory Section [NOT STARTED]

**Goal**: Fix stale EXTENSION.md placeholders and create the Memory Extension section in CLAUDE.md.

**Tasks**:
- [ ] Read current EXTENSION.md and remove "(placeholder)" markers from purge, merge, compress entries
- [ ] Add missing sub-mode entries to EXTENSION.md: --refine, --gc, --auto
- [ ] Update EXTENSION.md descriptions to reflect implemented behavior (e.g., "Tombstone stale memories" instead of "Remove low-value memories")
- [ ] Read current .claude/CLAUDE.md to identify insertion point for Memory Extension section
- [ ] Create Memory Extension section in CLAUDE.md covering: /learn and /distill commands in Command Reference table, skill-memory in Skill-to-Agent Mapping table, auto-retrieval with --clean opt-out, memory candidate lifecycle, memory_health state.json field, full memory lifecycle (/learn -> retrieval -> /todo harvest -> /distill)
- [ ] Document that --reindex does not exist; validate-on-read provides automatic equivalent

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/memory/EXTENSION.md` - Remove placeholders, add missing sub-modes
- `.claude/CLAUDE.md` - Add Memory Extension section

**Verification**:
- EXTENSION.md has no "(placeholder)" text
- EXTENSION.md lists all 7 distill sub-modes (report, purge, merge, compress, refine, gc, auto)
- CLAUDE.md contains a Memory Extension section with /learn, /distill, skill-memory references
- No mention of --reindex as a command; validate-on-read documented instead

---

### Phase 2: skill-memory README and distill-usage.md [NOT STARTED]

**Goal**: Complete skill-memory README with distill mode documentation and create the new distill-usage.md context file.

**Tasks**:
- [ ] Read current skill-memory README.md
- [ ] Add Distill Mode section documenting: all 7 sub-modes (bare report, --purge, --merge, --compress, --refine, --gc, --auto), scoring engine parameters and composite formula, tombstone pattern and --gc lifecycle, distill-log.json schema, relationship between /learn, /todo harvest, and /distill
- [ ] Add flag reference subsection: --dry-run, --verbose
- [ ] Create `.claude/extensions/memory/context/project/memory/distill-usage.md` with: sub-mode workflow examples, scoring formula explanation, recommended maintenance cadence, --dry-run and --verbose usage, lifecycle diagram (create -> use -> capture -> maintain)
- [ ] Correct outdated --remember references in README (auto-retrieval is the default; --clean suppresses it)

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/memory/skills/skill-memory/README.md` - Add distill mode section, fix --remember references
- `.claude/extensions/memory/context/project/memory/distill-usage.md` - New file: distill usage guide

**Verification**:
- README.md documents all 7 distill sub-modes
- README.md mentions scoring engine with component weights
- distill-usage.md exists with workflow examples for each sub-mode
- No stale --remember references remain in README

---

### Phase 3: Index Entries and Context Registration [NOT STARTED]

**Goal**: Fix index-entries.json and ensure all memory context files are discoverable.

**Tasks**:
- [ ] Read current index-entries.json
- [ ] Deduplicate memory-reference.md entry (currently listed twice with different descriptions)
- [ ] Add entry for new distill-usage.md context file with appropriate load_when targeting /distill command and skill-memory agent
- [ ] Verify all 6+ existing entries have correct paths, descriptions, and load_when conditions
- [ ] Add entry tagged for general-research-agent (memory retrieval context awareness)
- [ ] Verify entry format matches the schema used by other extension index-entries.json files

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/memory/index-entries.json` - Deduplicate, add distill-usage.md entry, fix load_when tags

**Verification**:
- No duplicate entries in index-entries.json
- distill-usage.md has a corresponding index entry
- At least one entry references the general-research-agent for retrieval context
- JSON is valid and parseable

---

### Phase 4: Validation Sweep and Summary [NOT STARTED]

**Goal**: Execute the 26-item validation checklist via documentation inspection, record results, and note any discrepancies as follow-up items.

**Tasks**:
- [ ] Walk through self-learning validation items 1-8 (research report checklist) by inspecting relevant source files
- [ ] Walk through distillation validation items 9-23 by inspecting SKILL.md, distill.md, memory-retrieve.sh, distill-log.json
- [ ] Walk through cross-cutting validation items 24-26 by inspecting manifest.json, memory-retrieve.sh
- [ ] Document validation results: pass/fail/note for each item
- [ ] Note TOKEN_BUDGET discrepancy (2000 in code vs 3000 in task description) as documented finding
- [ ] Record any discovered issues that need follow-up tasks
- [ ] Verify all Phase 1-3 deliverables are present and consistent with each other

**Timing**: 30 minutes

**Depends on**: 2, 3

**Files to modify**:
- No new files; validation results recorded in the execution summary

**Verification**:
- All 26 checklist items have a documented result
- Any blocking issues are flagged for follow-up
- Cross-references between CLAUDE.md, EXTENSION.md, README.md, and index-entries.json are consistent

## Testing & Validation

- [ ] EXTENSION.md contains no "(placeholder)" text and lists all 7 distill sub-modes
- [ ] CLAUDE.md Memory Extension section references /learn, /distill, skill-memory, auto-retrieval, --clean
- [ ] skill-memory README.md documents distill mode with all sub-modes and scoring engine
- [ ] distill-usage.md exists with lifecycle documentation and sub-mode workflows
- [ ] index-entries.json has no duplicate entries and includes distill-usage.md
- [ ] No stale --remember references in README.md
- [ ] 26-item validation checklist fully documented with results
- [ ] All modified files are valid (no JSON parse errors, no broken markdown)

## Artifacts & Outputs

- `specs/454_memory_system_documentation_end_to_end_validation/plans/01_memory-docs-plan.md` (this file)
- `specs/454_memory_system_documentation_end_to_end_validation/summaries/01_memory-docs-summary.md` (post-implementation)
- Modified: `.claude/extensions/memory/EXTENSION.md`
- Modified: `.claude/CLAUDE.md`
- Modified: `.claude/extensions/memory/skills/skill-memory/README.md`
- Created: `.claude/extensions/memory/context/project/memory/distill-usage.md`
- Modified: `.claude/extensions/memory/index-entries.json`

## Rollback/Contingency

All changes are to documentation files with no runtime impact. If any change introduces inconsistencies, revert individual files via git checkout. The memory system itself (scripts, hooks, skills) is not modified by this task.
