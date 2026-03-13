# Implementation Plan: Task #199

- **Task**: 199 - Complete Summary Naming Migration Fix Validation Globs
- **Status**: [NOT STARTED]
- **Effort**: 2-3 hours
- **Dependencies**: Task #198 (predecessor)
- **Research Inputs**: [01_naming-migration-gaps.md](../reports/01_naming-migration-gaps.md)
- **Artifacts**: plans/01_naming-convention-migration.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Complete the artifact naming convention migration left incomplete by task 198. The research report identified 13 files across 6 categories requiring updates. The primary issues are broken glob patterns in validation.md that fail to match new-convention artifacts (MM_{short-slug}.md format), outdated examples in extension agents/skills, and inconsistent format specification examples.

Additionally, the artifact-formats.md rule has an ambiguous example that implies global cross-type sequencing (01, 02, 03 across reports/plans/summaries), while the text describes per-type independent sequences. This plan also clarifies that documentation and fixes examples to use per-type numbering (reports start at 01, plans start at 01, summaries start at 01 independently).

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
- Clarify artifact-formats.md to specify separate per-type sequences (reports/plans/summaries each start at 01)
- Fix validation.md glob patterns to match MM_{short-slug}.md format artifacts
- Update plan/summary discovery patterns in task.md and update-plan-status.sh
- Update all extension agent/skill example outputs to use new naming convention with correct per-type numbering
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

### Phase 1: Clarify Artifact Naming Convention Documentation [COMPLETED]

**Goal**: Fix the ambiguous example in artifact-formats.md that implies global cross-type sequencing

**Problem**: The current example shows:
```
- 01_research-findings.md
- 02_design-approach.md
- 03_execution-summary.md
```
This looks like a single global sequence, but the text says "Reports: 01, 02, 03... Plans: 01, 02, 03..." implying separate sequences.

**Tasks**:
- [ ] Read `.claude/rules/artifact-formats.md` to confirm exact current wording
- [ ] Update the "Per-Task Sequential Numbering" section example to clearly show separate per-type sequences:
  ```
  - reports/01_research-findings.md   (reports sequence starts at 01)
  - reports/02_supplemental-analysis.md  (second report, increments independently)
  - plans/01_implementation-plan.md   (plans sequence starts at 01, independent of reports)
  - plans/02_revised-plan.md          (second plan version)
  - summaries/01_execution-summary.md (summaries sequence starts at 01, independent)
  ```
- [ ] Update the "Summaries" bullet to remove "highest number + 1" wording which implies global numbering

**Timing**: 15 minutes

**Files to modify**:
- `.claude/rules/artifact-formats.md` (Per-Task Sequential Numbering section)

**Verification**:
- Section clearly documents independent sequences per artifact type

---

### Phase 2: Fix Critical Validation Globs [COMPLETED]

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
- Glob patterns match example artifacts: `01_research-findings.md`, `01_implementation-plan.md`, `01_execution-summary.md`

---

### Phase 3: Update Plan/Summary Discovery Scripts [COMPLETED]

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

### Phase 4: Update Extension Agent Examples [NOT STARTED]

**Goal**: Update example return text in extension implementation agents to use new naming format with per-type numbering

**Tasks**:
- [ ] Update `.claude/extensions/web/agents/web-implementation-agent.md`:
  - Lines 347, 791, 802: `implementation-summary-20260205.md` -> `01_about-page-summary.md`
- [ ] Update `.claude/extensions/nvim/agents/neovim-implementation-agent.md`:
  - Line 282: `implementation-summary-20260202.md` -> `01_lsp-config-summary.md`
- [ ] Update `.claude/extensions/nix/agents/nix-implementation-agent.md`:
  - Line 302: `implementation-summary-20260203.md` -> `01_nix-config-summary.md`

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/web/agents/web-implementation-agent.md` (lines 347, 791, 802)
- `.claude/extensions/nvim/agents/neovim-implementation-agent.md` (line 282)
- `.claude/extensions/nix/agents/nix-implementation-agent.md` (line 302)

**Verification**:
- Grep for `implementation-summary-` in extension agents returns no results

---

### Phase 5: Update Extension Skill Examples [NOT STARTED]

**Goal**: Update example return text in extension skills to use new naming format with per-type numbering

**Tasks**:
- [ ] Update `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md`:
  - Lines 335, 345: `implementation-summary-20260203.md` -> `01_nix-module-summary.md`
- [ ] Update `.claude/extensions/web/skills/skill-web-implementation/SKILL.md`:
  - Lines 336, 346: `implementation-summary-20260205.md` -> `01_web-feature-summary.md`

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md` (lines 335, 345)
- `.claude/extensions/web/skills/skill-web-implementation/SKILL.md` (lines 336, 346)

**Verification**:
- Grep for `implementation-summary-` in extension skills returns no results

---

### Phase 6: Update Format Specification Examples [NOT STARTED]

**Goal**: Fix examples in format documentation for consistency with new convention and per-type numbering

**Tasks**:
- [ ] Update `.claude/context/core/formats/command-output.md`:
  - Lines 103, 269, 343: `implementation-summary-20260312.md` -> `01_feature-summary.md`
- [ ] Update `.claude/context/core/formats/return-metadata-file.md`:
  - Lines 255, 289, 323, 357: `implementation-summary-20260118.md` -> `01_lsp-config-summary.md`

**Timing**: 25 minutes

**Files to modify**:
- `.claude/context/core/formats/command-output.md` (lines 103, 269, 343)
- `.claude/context/core/formats/return-metadata-file.md` (lines 255, 289, 323, 357)

**Verification**:
- Grep for `implementation-summary-` in format docs returns no results

---

### Phase 7: Update Pattern Examples and Task 198 Status [NOT STARTED]

**Goal**: Clean up remaining old pattern references and fix task 198 plan status

**Tasks**:
- [ ] Update `.claude/context/core/patterns/anti-stop-patterns.md`:
  - Line 164: `plans/implementation-002.md` -> `plans/01_task-plan.md`
- [ ] Update `.claude/extensions/memory/context/project/memory/knowledge-capture-usage.md`:
  - Line 106: `reports/research-002.md` -> `reports/01_research-findings.md`
  - Line 107: `plans/implementation-003.md` -> `plans/01_implementation-plan.md`
  - Line 108: `summaries/implementation-summary-20260305.md` -> `summaries/01_capture-summary.md`
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

### Phase 8: Final Verification [NOT STARTED]

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

- plans/01_naming-convention-migration.md (this file)
- summaries/01_naming-migration-summary.md (on completion)

## Rollback/Contingency

If validation patterns break artifact discovery:
1. Revert validation.md changes using git
2. Use more permissive globs (e.g., `*.md`)
3. Test incrementally before committing

All changes are to example text and documentation, so functional rollback is straightforward via git revert.
