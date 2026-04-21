# Research Report: Task #487

**Task**: 487 - Update stale meta sister files
**Started**: 2026-04-19T00:01:00Z
**Completed**: 2026-04-19T00:15:00Z
**Effort**: Medium (1-3h for implementation)
**Dependencies**: 485 (completed -- meta-guide.md rewrite)
**Sources/Inputs**:
- Codebase: all 6 files in `.claude/context/meta/`
- Codebase: `.claude/agents/*.md` frontmatter analysis
- Codebase: `.claude/context/index.json` entries
- Codebase: `.claude/extensions/core/context/meta/` (extension source copies)
- Codebase: grep for cross-references across `.claude/`
- specs/ROADMAP.md for alignment
**Artifacts**:
- `specs/487_update_stale_meta_sister_files/reports/01_meta-sister-files.md` (this report)
**Standards**: report-format.md

## Executive Summary

- All 5 sister files contain significant stale content: phantom components (status-sync-manager, git-workflow-manager), obsolete frontmatter fields (temperature, max_tokens, can_delegate_to), wrong paths, and `.opencode` references.
- **3 files should be deleted as redundant** with meta-guide.md: architecture-principles.md, standards-checklist.md, interview-patterns.md. Their useful content is either already in meta-guide.md or is phantom (describes things that never existed).
- **2 files should be rewritten**: domain-patterns.md (still has unique value as extension domain template reference) and context-revision-guide.md (useful operational guidance, just needs destalinization).
- No agents or skills directly reference any sister file by path -- they are only loaded via index.json `load_when` conditions for `task_type: meta`.
- The `status-sync-manager` and `git-workflow-manager` phantom components appear in 42 files beyond these sister files -- a separate sweep is needed (aligns with ROADMAP Phase 1 "zero stale references" goal).

## Context & Scope

Task 485 rewrote meta-guide.md as the authoritative reference for the `/meta` command and meta-builder-agent. That rewrite noted (in "Future Extensions" section 3) that the companion sister files contain stale references and should be updated or consolidated. This task researches each file to determine the correct action.

### Files Under Review

| File | Lines | index.json line_count | Status |
|------|-------|----------------------|--------|
| architecture-principles.md | 267 | 270 | Stale |
| standards-checklist.md | 379 | 379 | Stale |
| interview-patterns.md | 221 | 224 | Stale |
| domain-patterns.md | 256 | 259 | Partially relevant |
| context-revision-guide.md | 323 | 323 | Mostly accurate |
| meta-guide.md | 259 | 259 | Current (task 485) |

All files exist in both deployed (`.claude/context/meta/`) and extension source (`.claude/extensions/core/context/meta/`) locations. Line counts in index.json are close but not exact for some files.

## Findings

### 1. architecture-principles.md -- DELETE (redundant + heavily stale)

**Stale content (~70%)**:
- Line 3: References `.opencode` -- the project uses `.claude/`, not `.opencode`
- Lines 69-71: "Level 1/2/3 context model" (Level 1 Isolation, Level 2 Filtered, Level 3 Full) -- this 3-level context model never existed in the deployed system. Context loading uses `load_when` conditions in index.json, not numbered levels.
- Lines 130-133: References `status-sync-manager` and `git-workflow-manager` as Stage 7 components -- these do not exist. Status updates use `skill-status-sync` and git commits use `skill-git-workflow`.
- Lines 136-168: "Research-Backed XML Patterns" with XML `<context>`, `<role>`, `<task>`, `<workflow_execution>` structure -- agents do not use XML structure. They use markdown.
- Lines 180-228: "Frontmatter Delegation Principle" prescribes extensive YAML frontmatter (context_level, routing, context_loading with strategy/index/required/optional) -- actual agent frontmatter is minimal: `name`, `description`, optional `model`.
- Lines 264-266: Cross-references point to non-existent paths (`.claude/context/workflows/interview-patterns.md`, `.claude/context/standards/domain-patterns.md`, `.claude/context/templates/agent-templates.md`)

**Partially valid content (~30%)**:
- Modular Design Principle (lines 8-30): File size guidelines are reasonable but not enforced
- Hierarchical Organization (lines 34-59): Orchestrator/subagent pattern is loosely accurate
- Workflow-Driven Design (lines 102-114): 8-stage concept is referenced elsewhere but stages differ in practice

**Redundancy with meta-guide.md**: meta-guide.md covers the actual delegation chain, interview stages, multi-task creation standard, and dependency system authoritatively. architecture-principles.md describes a phantom architecture that was never built.

**Recommendation**: DELETE. The few valid principles (modularity, hierarchy) are self-evident and documented elsewhere (CLAUDE.md, agent files themselves).

### 2. standards-checklist.md -- DELETE (redundant + heavily phantom)

**Stale content (~80%)**:
- Lines 16-19: Prescribes frontmatter fields `temperature`, `max_tokens` -- no agent uses these. Actual frontmatter is `name`, `description`, optional `model`.
- Lines 20-21: `tools`, `permissions` fields -- not used in any agent frontmatter
- Lines 23-29: `context_loading` with `strategy`, `index`, `required`, `optional`, `max_context_size` -- not used
- Lines 33-36: `delegation.can_delegate_to`, `delegation.timeout_default`, `delegation.timeout_max` -- not used
- Lines 39-41: `lifecycle.stage`, `lifecycle.return_format` -- not used
- Lines 44-70: XML structure validation (`<context>`, `<role>`, `<task>`, `<workflow_execution>`, `<constraints>`, `<validation_checks>`) -- agents use markdown, not XML
- Lines 82-86: Stage 7/8 references `status-sync-manager`, `git-workflow-manager`, `subagent-return.md` -- first two are phantom, last exists but the format described here does not match reality
- Lines 96-98: `@ symbol pattern` for delegation, `Context levels` -- neither is used in practice
- Lines 100-105: File size targets (Orchestrators 300-600, Subagents 200-600, Commands <300) -- not enforced

**Partially valid content (~20%)**:
- Context file standards (lines 139-169): File size 50-200 lines, single responsibility -- reasonable guidelines
- General validation workflow concept (lines 195-234) -- scoring idea is sound but implementation is fictional

**Redundancy with meta-guide.md**: meta-guide.md does not cover standards-checklist content because these "standards" describe a system that does not exist. The actual standards are documented in `agent-frontmatter-standard.md` and CLAUDE.md.

**Recommendation**: DELETE. This file actively misleads agents by prescribing phantom frontmatter fields and XML structures. The valid context file guidelines are covered by context-revision-guide.md.

### 3. interview-patterns.md -- DELETE (redundant with meta-guide.md)

**Stale content (~40%)**:
- Lines 14-29: "Stage Progression" references Stages 2-6 with generic questions (domain, use cases, technical details, validation) -- actual stages are documented precisely in meta-guide.md (DetectExistingSystem, InitiateInterview, GatherDomainInfo, etc.)
- Lines 218-220: Cross-references to non-existent paths (`.claude/context/workflows/interview-patterns.md`, `.claude/context/standards/domain-patterns.md`, `.claude/context/templates/agent-templates.md`)

**Valid content (~60%)**:
- Progressive Disclosure Pattern (lines 9-39): Valid interview technique
- Adaptive Questioning Pattern (lines 43-76): Valid but generic
- Example-Driven Questioning (lines 79-115): Valid but generic
- Validation Checkpoint (lines 118-151): Valid concept, but actual checkpoints differ from what is described
- Error Recovery Pattern (lines 155-184): Valid interview error recovery
- Context Building Pattern (lines 188-215): Valid concept

**Redundancy with meta-guide.md**: meta-guide.md documents the actual 7-stage interview in detail (stages 0-7), including what questions are asked, what options are presented, and how validation works. interview-patterns.md describes generic patterns that could apply to any interview -- it is a "how to interview" guide, not specific to the `/meta` command.

**Recommendation**: DELETE. The generic interview patterns are not actionable for agents (they follow the specific stages in meta-guide.md, not abstract patterns). If generic interview guidance is ever needed, it can be recreated. No agents reference this file directly.

### 4. domain-patterns.md -- REWRITE (unique value, needs update)

**Stale content (~25%)**:
- Lines 250-252: Cross-references to non-existent paths
- Lines 256: "Maintained By: Development Team" -- phantom attribution
- Some domain examples (Business, Hybrid) are not relevant to this project

**Valid and unique content (~75%)**:
- Extension Domain Pattern template (lines 133-171): Directly relevant to extension development, shows recommended agent structure and context organization for new extensions
- Domain Type Detection (lines 176-197): Useful keyword indicators for task type classification
- Agent Count Guidelines (lines 202-224): Practical sizing guidance
- Context File Guidelines (lines 228-248): File count recommendations by complexity
- Development Domain Pattern (lines 8-47): Applicable to this project

**Redundancy with meta-guide.md**: Low overlap. meta-guide.md covers the `/meta` command workflow; domain-patterns.md covers domain classification and extension architecture templates. Different concerns.

**Recommendation**: REWRITE. Remove stale cross-references and phantom attribution. Update the Extension Domain Pattern to match current extension manifest format. Remove or slim down Business/Hybrid domain patterns (not relevant to this project's extensions). Keep Development Domain Pattern and detection indicators. Target ~150 lines.

### 5. context-revision-guide.md -- REWRITE (mostly accurate, needs cleanup)

**Stale content (~15%)**:
- Lines 88-89, 96-97, 103-104: References to directories that use old naming (`.claude/context/standards/`, `.claude/context/templates/`, `.claude/context/workflows/`) -- some of these paths still exist but the examples may be outdated
- Lines 111-113: References architecture-principles.md, domain-patterns.md, interview-patterns.md as examples of "Project Meta" files -- will need updating if those files are deleted
- Lines 250-253, 259-264: Anti-patterns use emoji characters (violates emoji policy)
- Lines 206-207, 229-230: Example references to files/paths that may not match current structure

**Valid content (~85%)**:
- When to Revise (lines 8-40): Solid decision framework
- How to Revise Without Bloat (lines 44-82): Practical checklist
- Context File Types and Revision Patterns (lines 86-121): Useful categorization
- Revision Workflow (lines 124-195): Good 4-stage process
- Common Revision Scenarios (lines 199-244): Practical examples
- Anti-Patterns (lines 248-278): Valid warnings (despite emoji use)
- Metrics (lines 282-302): Reasonable thresholds

**Redundancy with meta-guide.md**: No overlap. Different concerns entirely (meta-guide = how `/meta` works; context-revision-guide = how to maintain context files).

**Recommendation**: REWRITE. Fix stale directory references, update examples to reference current files, remove emoji characters from anti-pattern headers, update line references if sister files are deleted. Keep the same structure. Target ~280 lines.

### Cross-Cutting: Phantom Component Contamination

The `status-sync-manager` and `git-workflow-manager` terms appear in 42 files across `.claude/`. These are phantom names for what is actually `skill-status-sync` and `skill-git-workflow`. This is a broader cleanup issue beyond the scope of task 487 but aligns with ROADMAP Phase 1 "zero stale references" goal.

### Cross-Cutting: index.json Updates Needed

When files are deleted or rewritten:
- Remove deleted file entries from `.claude/context/index.json`
- Remove deleted file entries from `.claude/extensions/core/index-entries.json`
- Update `line_count` for rewritten files
- Update entries in `.claude/extensions.json` (deployed_files and context_files arrays)
- Update references in `.claude/docs/guides/context-loading-best-practices.md` (3 instances reference these files)

### Cross-Cutting: Extension Source Sync

Both deployed (`.claude/context/meta/`) and extension source (`.claude/extensions/core/context/meta/`) copies must be kept in sync. Deletions and rewrites must happen in both locations.

## Decisions

- **architecture-principles.md**: Delete -- 70% stale, describes phantom architecture
- **standards-checklist.md**: Delete -- 80% stale, prescribes phantom frontmatter and XML
- **interview-patterns.md**: Delete -- redundant with meta-guide.md's detailed stage documentation
- **domain-patterns.md**: Rewrite -- 75% valid, unique extension template value
- **context-revision-guide.md**: Rewrite -- 85% valid, useful operational guide

## Recommendations

1. **Phase 1: Delete 3 files** (architecture-principles.md, standards-checklist.md, interview-patterns.md) from both deployed and extension source locations
2. **Phase 2: Rewrite domain-patterns.md** -- slim to ~150 lines, focus on extension domain template and development domain; remove business/hybrid domains and stale references
3. **Phase 3: Rewrite context-revision-guide.md** -- update examples, fix paths, remove emoji, update sister file references; target ~280 lines
4. **Phase 4: Update index files** -- remove deleted entries from index.json, index-entries.json, extensions.json; update line_counts for rewritten files
5. **Phase 5: Update cross-references** -- fix references in context-loading-best-practices.md and meta-guide.md "Future Extensions" section 3
6. **Separate task recommended**: Sweep `status-sync-manager` / `git-workflow-manager` phantom names from 42 files across `.claude/` (ROADMAP alignment)

## Risks & Mitigations

- **Risk**: Deleting files that are loaded during `/meta` could reduce context quality for meta-builder-agent
  - **Mitigation**: meta-guide.md (259 lines) already provides comprehensive, accurate context. The deleted files were providing inaccurate context that could mislead the agent.
- **Risk**: Other projects sharing the core extension may depend on these files
  - **Mitigation**: Extension source copies are synced. Other projects would get the same updates on next sync. Files are meta-system specific and unlikely to be referenced by domain-specific agents.
- **Risk**: Line count mismatches in index.json after rewrites
  - **Mitigation**: Phase 4 explicitly updates all index files.

## Appendix

### File Reference Counts (beyond self-references and index files)

| File | Referenced By |
|------|--------------|
| architecture-principles.md | context-loading-best-practices.md (3x), context-revision-guide.md (1x), meta-guide.md (1x) |
| standards-checklist.md | (none beyond index files) |
| interview-patterns.md | context-loading-best-practices.md (1x) |
| domain-patterns.md | context-loading-best-practices.md (3x), context-revision-guide.md (1x) |
| context-revision-guide.md | (none beyond index files) |

### Phantom Components Found in Sister Files

| Phantom | Actual | Files Affected (total) |
|---------|--------|----------------------|
| `status-sync-manager` | `skill-status-sync` | 42 files |
| `git-workflow-manager` | `skill-git-workflow` | 42 files |
| `temperature` frontmatter | Not used | standards-checklist.md only |
| `max_tokens` frontmatter | Not used | standards-checklist.md only |
| `can_delegate_to` frontmatter | Not used | standards-checklist.md only |
| Level 1/2/3 context model | `load_when` in index.json | architecture-principles.md only |
| `.opencode` | `.claude/` | architecture-principles.md only |

### Actual Agent Frontmatter (all agents)

Every agent in `.claude/agents/` uses this minimal frontmatter:
```yaml
---
name: agent-name
description: Agent description
model: opus  # optional
---
```

No agent uses `version`, `mode`, `agent_type`, `temperature`, `max_tokens`, `tools`, `permissions`, `context_loading`, `delegation`, or `lifecycle` fields.
