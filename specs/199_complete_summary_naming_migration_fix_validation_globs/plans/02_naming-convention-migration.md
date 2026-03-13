# Implementation Plan: Task #199

- **Task**: 199 - Complete Summary Naming Migration Fix Validation Globs
- **Status**: [NOT STARTED]
- **Effort**: 2-3 hours
- **Dependencies**: Task #198 (predecessor)
- **Research Inputs**: [01_naming-migration-gaps.md](../reports/01_naming-migration-gaps.md)
- **Artifacts**: plans/02_naming-convention-migration.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Complete the artifact naming convention migration left incomplete by task 198. The research report identified 13 files across 6 categories requiring updates. The primary issues are broken glob patterns in validation.md that fail to match new-convention artifacts (MM_{short-slug}.md format), outdated examples in extension agents/skills, and inconsistent format specification examples.

### Research Integration

Key findings from research report:
- **Category 1 (CRITICAL)**: validation.md glob patterns fail to match new naming convention
- **Category 2 (HIGH)**: Plan discovery scripts in task.md and update-plan-status.sh use old patterns
- **Category 3-4 (MEDIUM)**: Extension agents and skills have outdated example outputs
- **Category 5 (MEDIUM)**: Format specification files have inconsistent examples
- **Category 6 (LOW)**: Pattern examples use old research-NNN/implementation-NNN format
- **Category 7 (LOW)**: Task 198 plan status inconsistency (phases complete, plan not marked complete)

## Goals & Non-Goals

**Goals**:
- Fix validation.md glob patterns to match MM_{short-slug}.md format artifacts
- Update plan/summary discovery patterns in task.md and update-plan-status.sh
- Update all extension agent/skill example outputs to use new naming convention
- Fix format specification examples for consistency
- Update remaining old pattern examples in documentation
- Mark task 198 plan as COMPLETED for status consistency

**Non-Goals**:
- Creating new validation infrastructure (out of scope)
- Modifying actual artifact files (only updating references/examples)
- Changing the naming convention itself (already established in task 198)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Validation globs too permissive | Medium | Low | Test patterns against actual artifact structure |
| Missed references in files | Low | Medium | Use grep to verify no old patterns remain after changes |
| Extension breakage | Medium | Low | Changes are example text only, not functional code |

## Implementation Phases

### Phase 1: Fix Critical Validation Globs [NOT STARTED]

**Goal**: Update validation.md glob patterns to match new naming convention

**Tasks**:
- [ ] Read `.claude/context/core/validation.md` to verify line numbers from research
- [ ] Update line 35: `specs/{NNN}_*/reports/research-*.md` -> `specs/{NNN}_*/reports/*.md`
- [ ] Update line 36: `specs/{NNN}_*/plans/implementation-*.md` -> `specs/{NNN}_*/plans/*.md`
- [ ] Update line 37: `specs/{NNN}_*/summaries/implementation-summary-*.md` -> `specs/{NNN}_*/summaries/*-summary.md`
- [ ] Verify the updated patterns are syntactically correct

**Timing**: 15 minutes

**Files to modify**:
- `.claude/context/core/validation.md` (lines 35-37)

**Verification**:
- Glob patterns match example artifacts: `01_research-findings.md`, `02_implementation-plan.md`, `03_execution-summary.md`

---

### Phase 2: Update Plan/Summary Discovery Scripts [NOT STARTED]

**Goal**: Fix plan file discovery patterns in scripts and commands

**Tasks**:
- [ ] Read `.claude/scripts/update-plan-status.sh` to verify line 44 context
- [ ] Update line 44: `implementation-*.md` -> `*.md` (or more specific MM pattern)
- [ ] Read `.claude/commands/task.md` to verify line 343 context
- [ ] Update line 343: `implementation-*.md` -> `*.md` (or more specific MM pattern)
- [ ] Test that discovery still works correctly with updated patterns

**Timing**: 20 minutes

**Files to modify**:
- `.claude/scripts/update-plan-status.sh` (line 44)
- `.claude/commands/task.md` (line 343)

**Verification**:
- Run grep to confirm no remaining `implementation-*.md` patterns in discovery code

---

### Phase 3: Update Extension Agent Examples [NOT STARTED]

**Goal**: Update example return text in extension implementation agents to use new naming format

**Tasks**:
- [ ] Update `.claude/extensions/web/agents/web-implementation-agent.md`:
  - Line 347: `implementation-summary-20260205.md` -> `03_about-page-summary.md`
  - Line 791: `implementation-summary-20260205.md` -> `03_about-page-summary.md`
  - Line 802: `implementation-summary-20260205.md` -> `03_about-page-summary.md`
- [ ] Update `.claude/extensions/nvim/agents/neovim-implementation-agent.md`:
  - Line 282: `implementation-summary-20260202.md` -> `03_lsp-config-summary.md`
- [ ] Update `.claude/extensions/nix/agents/nix-implementation-agent.md`:
  - Line 302: `implementation-summary-20260203.md` -> `03_nix-config-summary.md`

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/web/agents/web-implementation-agent.md` (lines 347, 791, 802)
- `.claude/extensions/nvim/agents/neovim-implementation-agent.md` (line 282)
- `.claude/extensions/nix/agents/nix-implementation-agent.md` (line 302)

**Verification**:
- Grep for `implementation-summary-` in extension agents returns no results

---

### Phase 4: Update Extension Skill Examples [NOT STARTED]

**Goal**: Update example return text in extension skills to use new naming format

**Tasks**:
- [ ] Update `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md`:
  - Line 335: `implementation-summary-20260203.md` -> `03_nix-module-summary.md`
  - Line 345: `implementation-summary-20260203.md` -> `03_nix-module-summary.md`
- [ ] Update `.claude/extensions/web/skills/skill-web-implementation/SKILL.md`:
  - Line 336: `implementation-summary-20260205.md` -> `03_web-feature-summary.md`
  - Line 346: `implementation-summary-20260205.md` -> `03_web-feature-summary.md`

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md` (lines 335, 345)
- `.claude/extensions/web/skills/skill-web-implementation/SKILL.md` (lines 336, 346)

**Verification**:
- Grep for `implementation-summary-` in extension skills returns no results

---

### Phase 5: Update Format Specification Examples [NOT STARTED]

**Goal**: Fix examples in format documentation for consistency with new convention

**Tasks**:
- [ ] Update `.claude/context/core/formats/command-output.md`:
  - Line 103: `implementation-summary-20260312.md` -> `03_feature-summary.md`
  - Line 269: `implementation-summary-20260312.md` -> `03_feature-summary.md`
  - Line 343: `implementation-summary-20260312.md` -> `03_feature-summary.md`
- [ ] Update `.claude/context/core/formats/return-metadata-file.md`:
  - Line 255: `implementation-summary-20260118.md` -> `03_lsp-config-summary.md`
  - Line 289: `implementation-summary-20260118.md` -> `03_lsp-config-summary.md`
  - Line 323: `implementation-summary-20260118.md` -> `03_lsp-config-summary.md`
  - Line 357: `implementation-summary-20260118.md` -> `03_lsp-config-summary.md`

**Timing**: 25 minutes

**Files to modify**:
- `.claude/context/core/formats/command-output.md` (lines 103, 269, 343)
- `.claude/context/core/formats/return-metadata-file.md` (lines 255, 289, 323, 357)

**Verification**:
- Grep for `implementation-summary-` in format docs returns no results

---

### Phase 6: Update Pattern Examples and Task 198 Status [NOT STARTED]

**Goal**: Clean up remaining old pattern references and fix task 198 plan status

**Tasks**:
- [ ] Update `.claude/context/core/patterns/anti-stop-patterns.md`:
  - Line 164: `plans/implementation-002.md` -> `plans/02_task-plan.md`
- [ ] Update `.claude/extensions/memory/context/project/memory/knowledge-capture-usage.md`:
  - Line 106: `reports/research-002.md` -> `reports/02_research-findings.md`
  - Line 107: `plans/implementation-003.md` -> `plans/03_implementation-plan.md`
  - Line 108: `summaries/implementation-summary-20260305.md` -> `summaries/04_capture-summary.md`
- [ ] Update `specs/198_review_recent_claude_commits_consistency/plans/02_complete-naming-migration.md`:
  - Line 4: `[NOT STARTED]` -> `[COMPLETED]`

**Timing**: 20 minutes

**Files to modify**:
- `.claude/context/core/patterns/anti-stop-patterns.md` (line 164)
- `.claude/extensions/memory/context/project/memory/knowledge-capture-usage.md` (lines 106-108)
- `specs/198_review_recent_claude_commits_consistency/plans/02_complete-naming-migration.md` (line 4)

**Verification**:
- Grep confirms no `research-NNN` or `implementation-NNN` patterns remain
- Task 198 plan shows consistent status

---

### Phase 7: Final Verification [NOT STARTED]

**Goal**: Verify all old naming patterns have been migrated

**Tasks**:
- [ ] Run comprehensive grep for remaining old patterns:
  - `implementation-summary-` in .claude/ and specs/
  - `research-[0-9]` pattern
  - `implementation-[0-9]` pattern
- [ ] Document any remaining intentional exceptions
- [ ] Create implementation summary

**Timing**: 15 minutes

**Verification**:
- No unexpected old pattern matches
- All changes documented in summary

## Testing & Validation

- [ ] Grep verification: no `implementation-summary-YYYYMMDD` patterns in .claude/ (excluding archives)
- [ ] Grep verification: no `research-NNN.md` patterns in .claude/ (excluding archives)
- [ ] Grep verification: no `implementation-NNN.md` patterns in .claude/ (excluding archives)
- [ ] Validation.md glob patterns syntactically correct
- [ ] Plan discovery scripts function correctly with new patterns

## Artifacts & Outputs

- plans/02_naming-convention-migration.md (this file)
- summaries/03_naming-migration-summary.md (on completion)

## Rollback/Contingency

If validation patterns break artifact discovery:
1. Revert validation.md changes using git
2. Use more permissive globs (e.g., `*.md`)
3. Test incrementally before committing

All changes are to example text and documentation, so functional rollback is straightforward via git revert.
