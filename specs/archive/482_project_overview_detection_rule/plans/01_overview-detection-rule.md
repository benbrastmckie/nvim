# Implementation Plan: Task #482

- **Task**: 482 - project_overview_detection_rule
- **Status**: [IMPLEMENTING]
- **Effort**: 0.5 hours
- **Dependencies**: None (task 483 provides the generation workflow referenced by this rule)
- **Research Inputs**: [specs/482_project_overview_detection_rule/reports/01_overview-detection-rule.md]
- **Artifacts**: plans/01_overview-detection-rule.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create a detection rule that auto-applies when `project-overview.md` is accessed, instructing the agent to check for the `<!-- GENERIC TEMPLATE` marker and notify the user if found. The rule lives in the core extension source directory and is registered in the core manifest, then installed to the active rules directory.

### Research Integration

Key findings from research report:
- Rules use YAML frontmatter with `paths:` globs for auto-application (path-based, not content-based)
- The rule body must instruct the agent to check content since rules themselves cannot inspect file contents
- Target path: `.claude/context/repo/project-overview.md` (the active file agents load)
- The core extension manifest declares rules in `provides.rules` array

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task advances "Agent System Quality" in Phase 1 of the roadmap -- it automates detection of uncustomized project-overview.md files, reducing manual checking.

## Goals & Non-Goals

**Goals**:
- Create a detection rule that fires when project-overview.md is in context
- Rule instructs agent to check for generic template marker and notify user
- Register rule in core extension manifest
- Install rule to active rules directory

**Non-Goals**:
- Implementing the generation workflow itself (task 483)
- Modifying CLAUDE.md (existing passive detection remains as-is)
- Handling other file detection patterns

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Rule fires frequently on every project-overview.md access | L | M | Rule is conditional -- silent when marker absent |
| Manifest format mismatch | M | L | Research confirmed the array format in provides.rules |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Create Detection Rule [COMPLETED]

**Goal**: Write the rule file with YAML frontmatter and conditional detection instructions.

**Tasks**:
- [ ] Create `.claude/extensions/core/rules/project-overview-detection.md` with YAML frontmatter targeting `.claude/context/repo/project-overview.md`
- [ ] Rule body instructs agent to check first line for `<!-- GENERIC TEMPLATE` marker
- [ ] If marker found: notify user, suggest `/task "Generate project-overview.md for this repository"`
- [ ] If marker absent: no action needed
- [ ] Reference `.claude/context/repo/update-project.md` as generation guide

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/core/rules/project-overview-detection.md` - Create new rule file

**Verification**:
- File exists with correct YAML frontmatter `paths:` field
- Rule body contains conditional check logic and user notification

---

### Phase 2: Register and Install Rule [COMPLETED]

**Goal**: Add the rule to the core extension manifest and install to active rules directory.

**Tasks**:
- [ ] Add `"project-overview-detection.md"` to `provides.rules` array in `.claude/extensions/core/manifest.json`
- [ ] Copy/install rule to `.claude/rules/project-overview-detection.md`
- [ ] Verify the installed rule matches the source

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/core/manifest.json` - Add to provides.rules array
- `.claude/rules/project-overview-detection.md` - Install (copy from extension source)

**Verification**:
- `manifest.json` lists the new rule in provides.rules
- `.claude/rules/project-overview-detection.md` exists and matches source
- Rule path pattern is valid glob syntax

## Testing & Validation

- [ ] Rule file has valid YAML frontmatter with `paths:` field
- [ ] Rule path pattern matches `.claude/context/repo/project-overview.md`
- [ ] Rule body includes conditional check for `<!-- GENERIC TEMPLATE` marker
- [ ] Rule is listed in core manifest provides.rules
- [ ] Installed copy at `.claude/rules/` matches extension source

## Artifacts & Outputs

- `.claude/extensions/core/rules/project-overview-detection.md` - Rule source file
- `.claude/rules/project-overview-detection.md` - Installed active rule
- `.claude/extensions/core/manifest.json` - Updated manifest (provides.rules entry)

## Rollback/Contingency

Remove the three file changes:
1. Delete `.claude/extensions/core/rules/project-overview-detection.md`
2. Delete `.claude/rules/project-overview-detection.md`
3. Remove the `"project-overview-detection.md"` entry from manifest.json provides.rules
