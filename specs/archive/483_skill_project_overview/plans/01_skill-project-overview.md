# Implementation Plan: Task #483

- **Task**: 483 - Create skill-project-overview
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: Task 482 (completed - detection rule)
- **Research Inputs**: specs/483_skill_project_overview/reports/01_skill-project-overview.md
- **Artifacts**: plans/01_skill-project-overview.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Implement skill-project-overview as a direct-execution skill in the core extension that automates repository analysis and project-overview.md generation through a 3-stage workflow: auto-scan, interactive interview, and task+artifact creation. The skill creates a task with a research artifact summarizing findings, then guides the user to continue with the normal task lifecycle (/plan, /implement) rather than writing project-overview.md directly.

### Research Integration

Key findings from research report:
- Direct-execution pattern (like skill-todo/skill-fix-it) is appropriate -- no subagent needed
- Core extension placement at `extensions/core/skills/skill-project-overview/`
- AskUserQuestion for interactive multi-turn dialogue
- Task-creation approach means the skill does NOT write project-overview.md directly
- Detection rule (task 482) should be updated to suggest `/project-overview`

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task does not directly advance any current ROADMAP.md items, though it improves agent system quality by automating a manual process documented in CLAUDE.md ("New repository setup" section).

## Goals & Non-Goals

**Goals**:
- Create a working `/project-overview` command that auto-scans the repository
- Implement interactive verification via AskUserQuestion
- Create a task + research artifact with gathered findings
- Register the skill and command in the core extension manifest
- Update the detection rule to suggest the new command

**Non-Goals**:
- The skill does NOT write project-overview.md directly (that happens via /implement)
- No new agent creation
- No changes to the project-overview.md template itself
- No changes to update-project.md guide

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Skill exceeds direct-execution complexity | M | L | Keep scan logic simple (bash one-liners, glob counts) |
| AskUserQuestion flow feels clunky | M | M | Limit to 2-3 focused questions, provide good defaults |
| Detection rule update breaks existing workflow | L | L | Keep `/task "Generate..."` as fallback alongside `/project-overview` |
| Manifest JSON edit introduces syntax error | H | L | Validate with jq after edit |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Create the SKILL.md [COMPLETED]

**Goal**: Implement the core skill file with 3-stage workflow logic

**Tasks**:
- [ ] Create directory `extensions/core/skills/skill-project-overview/`
- [ ] Write `SKILL.md` with frontmatter (name, description, allowed-tools including AskUserQuestion, context: direct)
- [ ] Implement Stage 1: Auto-scan logic (detect languages by extension count, find config files, identify frameworks, build tools, CI, testing, key files)
- [ ] Implement Stage 2: Interactive interview (present findings for confirmation, ask about project purpose, development workflow, additional components)
- [ ] Implement Stage 3: Task + artifact creation (create task in state.json + TODO.md, write research artifact, display next-step guidance)

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/core/skills/skill-project-overview/SKILL.md` - Create new file

**Verification**:
- SKILL.md has valid frontmatter with `context: direct`
- All three stages are documented with clear execution flow
- AskUserQuestion usage follows interactive-selection.md patterns
- Task creation follows state-management patterns

---

### Phase 2: Create the command file [COMPLETED]

**Goal**: Create the user-facing `/project-overview` command that invokes the skill

**Tasks**:
- [ ] Create `extensions/core/commands/project-overview.md`
- [ ] Define command that invokes skill-project-overview
- [ ] Include brief usage description and examples

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/core/commands/project-overview.md` - Create new file

**Verification**:
- Command file exists and references skill-project-overview
- Format matches other command files in extensions/core/commands/

---

### Phase 3: Register in manifest [COMPLETED]

**Goal**: Add skill and command to core extension manifest

**Tasks**:
- [ ] Add `skill-project-overview` to `provides.skills` array in manifest.json
- [ ] Add `project-overview.md` to `provides.commands` array in manifest.json
- [ ] Validate manifest JSON with jq

**Timing**: 15 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/core/manifest.json` - Add provides entries

**Verification**:
- `jq . .claude/extensions/core/manifest.json` succeeds (valid JSON)
- Skill and command appear in appropriate provides arrays

---

### Phase 4: Update detection rule [COMPLETED]

**Goal**: Update the project-overview-detection rule to suggest `/project-overview` command

**Tasks**:
- [ ] Read current `.claude/rules/project-overview-detection.md`
- [ ] Update suggestion text to recommend `/project-overview` as primary action
- [ ] Keep `/task "Generate..."` as fallback option for environments without the extension

**Timing**: 15 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/rules/project-overview-detection.md` - Update suggestion text

**Verification**:
- Rule mentions `/project-overview` as primary suggestion
- Fallback path still documented

## Testing & Validation

- [ ] SKILL.md loads without errors (valid frontmatter, no syntax issues)
- [ ] Command file is properly structured
- [ ] manifest.json validates with jq
- [ ] Detection rule references new command
- [ ] Skill workflow covers all 3 stages (scan, interview, create)

## Artifacts & Outputs

- `.claude/extensions/core/skills/skill-project-overview/SKILL.md`
- `.claude/extensions/core/commands/project-overview.md`
- `.claude/extensions/core/manifest.json` (modified)
- `.claude/rules/project-overview-detection.md` (modified)

## Rollback/Contingency

Revert by removing the new skill directory and command file, then reverting manifest.json and detection rule changes via git:
```bash
git checkout -- .claude/extensions/core/manifest.json .claude/rules/project-overview-detection.md
rm -rf .claude/extensions/core/skills/skill-project-overview/
rm -f .claude/extensions/core/commands/project-overview.md
```
