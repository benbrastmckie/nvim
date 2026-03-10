# Implementation Plan: Task #171

- **Task**: 171 - Re-audit agent systems after core reload and extension re-load
- **Date**: 2026-03-10
- **Feature**: Fix OPENCODE.md missing core content after extension reload
- **Status**: [COMPLETED]
- **Estimated Hours**: 0.25-0.5 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
- **Research Reports**: [research-001.md](../reports/research-001.md)
- **Type**: meta
- **Lean Intent**: false

## Overview

The research audit found that after reloading extensions, OPENCODE.md in `/home/benjamin/Projects/Logos/Vision/.opencode/` starts directly with extension sections and is missing core content (Quick Start, System Overview, Command Reference, etc.). This plan fixes that issue.

**Note**: Per user clarification, `project-overview.md` is intentionally excluded from this fix. The @-reference in CLAUDE.md/OPENCODE.md already documents that this file is optional and provides guidance for creating it when needed.

### Research Integration

- OPENCODE.md starts with `<!-- SECTION: extension_oc_epidemiology -->` instead of core content
- Core content from `.opencode_core/README.md` needs to be merged before extension sections
- This is the same fix applied in task 170 Phase 2

## Goals & Non-Goals

**Goals**:
- Merge core README.md content into OPENCODE.md before extension sections
- Verify OPENCODE.md has both core content and all 11 extension sections

**Non-Goals**:
- Recreating project-overview.md (intentionally excluded per user request)
- Modifying extension loader behavior (architectural change, separate task)
- Modifying .claude/ system (CLAUDE.md is correct)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Overwriting extension sections | H | L | Append extension content to core, not replace |

## Implementation Phases

### Phase 1: Merge Core Content into OPENCODE.md [COMPLETED]

**Goal**: OPENCODE.md should have core README.md content followed by extension sections.

**Tasks**:
- [ ] Read current OPENCODE.md (contains only extension sections)
- [ ] Read .opencode_core/README.md (contains core content)
- [ ] Create new OPENCODE.md: core content + "## Extension Sections" header + current extension content
- [ ] Verify new file has both core sections and all 11 extension sections

**Timing**: 10 minutes

**Files to modify**:
- `/home/benjamin/Projects/Logos/Vision/.opencode/OPENCODE.md` - Merge core content before extension sections

**Verification**:
- `head -30 .opencode/OPENCODE.md` shows "# OpenCode Agent System" at top
- `grep -c "extension_oc_" .opencode/OPENCODE.md` shows 22 (11 sections x 2 markers)
- `grep "## Quick Start" .opencode/OPENCODE.md` returns match
- `grep "## Extension Sections" .opencode/OPENCODE.md` returns match

---

### Phase 2: Final Validation [COMPLETED]

**Goal**: Confirm the fix is complete and system is functional.

**Tasks**:
- [ ] Verify OPENCODE.md has all expected sections (core + 11 extensions)
- [ ] Verify no other regressions in .opencode/ system
- [ ] Confirm core agents and skills still present

**Timing**: 5 minutes

**Files to modify**: None (validation only)

**Verification**:
- OPENCODE.md starts with core content (# OpenCode Agent System)
- OPENCODE.md has 22 extension markers (11 sections)
- Core agents present: general-implementation, general-research, meta-builder, planner, code-reviewer
- Core skills present: skill-researcher, skill-implementer, skill-planner, skill-meta

---

## Testing & Validation

- [ ] OPENCODE.md has core content at top (not extension sections)
- [ ] OPENCODE.md has all 11 extension sections preserved
- [ ] .opencode/ system has all 33 agents, 41 skills, 20 commands

## Artifacts & Outputs

- Updated `/home/benjamin/Projects/Logos/Vision/.opencode/OPENCODE.md`

## Rollback/Contingency

If the merge fails:
1. OPENCODE.md.backup exists from task 170 (if not deleted)
2. Extension content can be extracted from current OPENCODE.md
3. Core content is always available in `.opencode_core/README.md`
