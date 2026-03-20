# Implementation Plan: Task #251

- **Task**: 251 - Improve context efficiency via progressive disclosure
- **Status**: [IMPLEMENTING]
- **Effort**: 4-6 hours
- **Dependencies**: None
- **Research Inputs**: [01_team-research.md](../reports/01_team-research.md)
- **Artifacts**: plans/01_context-efficiency-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

The Claude Code agent system currently loads ~24,276 tokens of always-on context before task work begins (~12% of a 200k window). Research identified 5 high-impact optimizations targeting ~9,346 token savings (38% reduction). This plan implements those optimizations in order of impact and risk, with verification at each phase.

### Research Integration

Key findings integrated from team research:
- 9 Quick Reference sections in root CLAUDE.md embed 200-900 tokens each that duplicate linked documents (~4,080 tokens reducible)
- State-management rule contains 237 lines of schema that should be on-demand context (~2,000 tokens)
- Legacy .claude/CLAUDE.md duplicates nvim/.claude/CLAUDE.md with 39-94% content similarity (~1,581 tokens)
- Worktree metadata header adds ~185 tokens to always-loaded context
- Artifact-formats and workflows rules contain process diagrams and templates that should be on-demand (~1,500 tokens)

## Goals & Non-Goals

**Goals**:
- Reduce always-loaded context by ~38% (~9,346 tokens)
- Convert CLAUDE.md Quick Reference sections to pointer-only format
- Split reference schemas from behavioral rules into on-demand context
- Consolidate or eliminate duplicate CLAUDE.md files
- Maintain all functionality (no content lost, just relocated)

**Non-Goals**:
- Restructuring command/agent files (deferred per research)
- Implementing command-scope rules (requires system changes)
- Creating tiered agent files (high complexity, medium benefit)
- Changing index.json infrastructure

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| @-references not followed | High | Low | Test each section with agent invocation before/after |
| Broken internal links | Medium | Medium | Run validate-links-quick.sh after each phase |
| Removed content needed | Medium | Low | Preserve in authoritative docs, verify before deletion |
| Token counts inaccurate | Low | Medium | Measure actual tokens per file before/after |

## Implementation Phases

### Phase 1: Strip Quick Reference from Root CLAUDE.md [COMPLETED]

**Goal**: Remove inline Quick Reference content from 9 sections, leaving only pointer links. This is the highest-impact, lowest-risk change.

**Tasks**:
- [ ] Measure baseline token count for ~/.config/CLAUDE.md
- [ ] Identify all 9 sections with Quick Reference blocks (Code Standards, Non-Interactive Testing, Code Quality Enforcement, Error Logging, Concurrent Execution, Plan Metadata, Hierarchical Agent Architecture, Skills Architecture, Documentation Policy)
- [ ] For each section:
  - [ ] Verify linked document contains the Quick Reference content
  - [ ] Remove Quick Reference block, keeping only `[Used by:]` and `See [...]` pointer
- [ ] Measure post-change token count
- [ ] Run link validation to ensure no broken references

**Timing**: 1.5 hours

**Files to modify**:
- `~/.config/CLAUDE.md` - Strip 9 Quick Reference sections

**Verification**:
- Token count reduction of ~4,000 tokens
- All internal links resolve correctly
- Agent invocations still find referenced documentation via @-references

---

### Phase 2: Split State-Management Rule [NOT STARTED]

**Goal**: Separate behavioral constraints (auto-loaded) from reference schemas (on-demand). Consolidate with existing state-json-schema.md to eliminate divergent duplicates.

**Tasks**:
- [ ] Measure baseline token count for .claude/rules/state-management.md
- [ ] Identify Category A content (behavioral constraints, ~60 lines):
  - Status transitions
  - Two-phase update pattern
  - Error handling
- [ ] Identify Category B content (reference schemas, ~300 lines):
  - state.json field schemas
  - TODO.md entry format
  - Artifact object schema
- [ ] Create new context file: .claude/context/core/reference/state-management-schema.md
- [ ] Consolidate with existing state-json-schema.md (eliminate 140 unique/38 overlapping lines divergence)
- [ ] Update state-management.md to reference new schema file
- [ ] Add new file to index.json with appropriate load_when triggers

**Timing**: 1.5 hours

**Files to modify**:
- `.claude/rules/state-management.md` - Keep behavioral constraints only
- `.claude/context/core/reference/state-management-schema.md` - New consolidated schema file
- `.claude/context/core/reference/state-json-schema.md` - Delete or merge
- `.claude/context/index.json` - Add new entry

**Verification**:
- Token count reduction of ~2,000 tokens in auto-loaded rules
- Schema content preserved and accessible via @-reference
- No duplicate schema definitions across files

---

### Phase 3: Consolidate Legacy .claude/CLAUDE.md [NOT STARTED]

**Goal**: Eliminate the duplicate .claude/CLAUDE.md file which shares 12 section titles with 39-94% content similarity to nvim/.claude/CLAUDE.md.

**Tasks**:
- [ ] Compare .claude/CLAUDE.md vs nvim/.claude/CLAUDE.md section by section
- [ ] Identify any unique content in legacy file that needs preservation
- [ ] Option A: Delete .claude/CLAUDE.md if nvim/.claude/CLAUDE.md covers all content
- [ ] Option B: Replace with minimal pointer file if project-root CLAUDE.md is required
- [ ] Update any references to .claude/CLAUDE.md

**Timing**: 0.5 hours

**Files to modify**:
- `.claude/CLAUDE.md` - Delete or replace with pointer

**Verification**:
- Token count reduction of ~1,581 tokens
- No broken references to deleted file
- All functionality preserved

---

### Phase 4: Externalize Worktree Metadata Header [NOT STARTED]

**Goal**: Move the worktree task metadata header out of always-loaded CLAUDE.md context.

**Tasks**:
- [ ] Identify worktree metadata location (~/.config/CLAUDE.md lines 1-26)
- [ ] Create worktree metadata file: .worktree-meta.md or move to gitignored location
- [ ] Update worktree creation tooling to use new location
- [ ] Remove worktree header from root CLAUDE.md

**Timing**: 0.5 hours

**Files to modify**:
- `~/.config/CLAUDE.md` - Remove worktree header (lines 1-26)
- `.worktree-meta.md` - New file for worktree metadata (if needed)

**Verification**:
- Token count reduction of ~185 tokens
- Worktree functionality preserved
- No impact on worktree-aware commands

---

### Phase 5: Split Artifact-Formats and Workflows Rules [NOT STARTED]

**Goal**: Apply the same Category A/B/C split pattern to remaining rules files, moving format templates and process diagrams to on-demand context.

**Tasks**:
- [ ] Measure baseline token counts for artifact-formats.md (~1,818 tokens) and workflows.md (~1,510 tokens)
- [ ] Identify Category A content (behavioral rules) vs Category C (process diagrams/templates)
- [ ] Create context files for extracted content:
  - `.claude/context/core/reference/artifact-templates.md` - Format templates
  - `.claude/context/core/reference/workflow-diagrams.md` - Process diagrams
- [ ] Update rules files to reference extracted content
- [ ] Add new files to index.json

**Timing**: 1.5 hours

**Files to modify**:
- `.claude/rules/artifact-formats.md` - Keep behavioral rules only
- `.claude/rules/workflows.md` - Keep behavioral rules only
- `.claude/context/core/reference/artifact-templates.md` - New file
- `.claude/context/core/reference/workflow-diagrams.md` - New file
- `.claude/context/index.json` - Add new entries

**Verification**:
- Token count reduction of ~1,500 tokens in auto-loaded rules
- Process diagrams and templates preserved and accessible
- All artifact creation still works correctly

---

## Testing & Validation

- [ ] Baseline measurement: Total tokens loaded before changes (~24,276)
- [ ] Per-phase token measurements documented
- [ ] Final measurement: Total tokens loaded after all changes (target: ~14,930)
- [ ] Link validation passes after each phase
- [ ] Representative agent invocations work correctly (/research, /plan, /implement)
- [ ] No "file not found" errors when agents load context

## Artifacts & Outputs

- plans/01_context-efficiency-plan.md (this file)
- Modified: ~/.config/CLAUDE.md (stripped Quick References, no worktree header)
- Modified: .claude/rules/state-management.md (behavioral only)
- Modified: .claude/rules/artifact-formats.md (behavioral only)
- Modified: .claude/rules/workflows.md (behavioral only)
- Deleted: .claude/CLAUDE.md (consolidated)
- New: .claude/context/core/reference/state-management-schema.md
- New: .claude/context/core/reference/artifact-templates.md
- New: .claude/context/core/reference/workflow-diagrams.md
- Modified: .claude/context/index.json (new entries)

## Rollback/Contingency

Each phase is independently reversible via git:
- Phase changes are committed separately
- If @-references don't work as expected, content can be restored inline
- If token reduction doesn't meet targets, specific sections can be kept inline
- Backup: `git diff HEAD~N` to see exactly what changed per phase
