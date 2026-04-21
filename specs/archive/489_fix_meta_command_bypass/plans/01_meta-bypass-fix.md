# Implementation Plan: Task #489

- **Task**: 489 - Fix /meta prompt mode regression: model bypasses Skill delegation and implements changes directly instead of creating tasks via interactive picker
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/489_fix_meta_command_bypass/reports/01_meta-bypass-analysis.md
- **Artifacts**: plans/01_meta-bypass-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Mirror the proven anti-bypass enforcement pattern from /plan, /research, /implement onto the /meta command. This involves adding an explicit Anti-Bypass Constraint section to meta.md, creating a new PostToolUse hook that detects direct writes to `.claude/` paths, reinforcing delegation requirements in skill-meta and meta-builder-agent, and registering the new hook in settings.json. All changes apply to both the loaded `.claude/` files and the canonical extension source in `.claude/extensions/core/`.

### Research Integration

The research report identified four enforcement gaps: (1) missing Anti-Bypass section in meta.md, (2) no PostToolUse hook coverage for `.claude/` path writes, (3) outcome-focused rather than mechanism-focused prohibition language, and (4) extra delegation layer increasing bypass opportunity. The plan addresses all four with a layered fix matching the task-414 precedent.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This plan advances the "Agent System Quality" roadmap area by closing a structural enforcement gap that affects command reliability.

## Goals & Non-Goals

**Goals**:
- Prevent /meta from directly creating/modifying files in `.claude/` directories
- Add corrective context injection when bypass is attempted
- Mirror the proven anti-bypass pattern from /plan, /research, /implement
- Keep the hook advisory (additionalContext) rather than blocking, to avoid interfering with /implement

**Non-Goals**:
- Blocking all `.claude/` writes globally (that would break /implement)
- Refactoring the meta delegation chain to reduce hop count
- Creating a centralized anti-bypass documentation pattern file

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Hook fires during legitimate /implement writes to .claude/ | H | M | Make hook advisory-only (additionalContext), scope message to /meta context |
| Anti-bypass text ignored by model in long context | M | L | Three-layer reinforcement (command + hook + skill + agent) |
| Extension source sync missed | M | L | Phase 4 explicitly syncs both locations |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Add Anti-Bypass Constraint to meta.md [COMPLETED]

**Goal**: Add explicit mechanism-focused anti-bypass section to the /meta command definition

**Tasks**:
- [ ] Add `## Anti-Bypass Constraint` section to `.claude/commands/meta.md` between "Constraints" and "Execution" sections
- [ ] Use mechanism-focused language: "MUST NOT create or modify files in `.claude/` directly using Write or Edit tools"
- [ ] Reference the PostToolUse hook that will provide corrective context
- [ ] Include "Why" explanation matching /plan pattern

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/commands/meta.md` - Add Anti-Bypass Constraint section after line 34

**Verification**:
- Grep for "Anti-Bypass Constraint" in meta.md confirms section exists
- Section contains "PROHIBITION", "Write or Edit tools", and "Skill tool" keywords

---

### Phase 2: Create validate-meta-write.sh PostToolUse hook [COMPLETED]

**Goal**: Create a PostToolUse hook that detects and injects corrective context when Write/Edit targets `.claude/` paths

**Tasks**:
- [ ] Create `.claude/hooks/validate-meta-write.sh` following the pattern from `validate-plan-write.sh`
- [ ] Parse `file_path` from tool input (stdin JSON or CLAUDE_TOOL_INPUT env)
- [ ] Match paths: `.claude/commands/*`, `.claude/skills/*`, `.claude/agents/*`, `.claude/rules/*`, `.claude/context/*`, `*/CLAUDE.md`
- [ ] Return `additionalContext` (advisory, not blocking) with corrective message
- [ ] Exclude `specs/` paths from matching (those are legitimate)
- [ ] Make hook executable (`chmod +x`)
- [ ] Register hook in `.claude/settings.json` under PostToolUse with matcher `Write|Edit`

**Timing**: 40 minutes

**Depends on**: none

**Files to modify**:
- `.claude/hooks/validate-meta-write.sh` - NEW file
- `.claude/settings.json` - Add hook entry to PostToolUse array

**Verification**:
- Hook file exists and is executable
- `bash .claude/hooks/validate-meta-write.sh` with test input returns expected JSON
- settings.json is valid JSON after modification

---

### Phase 3: Reinforce delegation in skill-meta and meta-builder-agent [COMPLETED]

**Goal**: Add explicit anti-bypass language to the skill and agent definitions

**Tasks**:
- [ ] Add `## Anti-Bypass Constraint` section to `.claude/skills/skill-meta/SKILL.md` after "Trigger Conditions" section
- [ ] Add `**SCOPE BOUNDARY**` statement at the top of the Constraints section in `.claude/agents/meta-builder-agent.md`
- [ ] Ensure language is mechanism-focused ("MUST NOT write to .claude/ paths using Write or Edit tools")

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-meta/SKILL.md` - Add Anti-Bypass section
- `.claude/agents/meta-builder-agent.md` - Add SCOPE BOUNDARY statement

**Verification**:
- Grep for "Anti-Bypass" in SKILL.md
- Grep for "SCOPE BOUNDARY" in meta-builder-agent.md

---

### Phase 4: Sync extension sources [COMPLETED]

**Goal**: Copy all changes to the canonical extension source files so they survive sync operations

**Tasks**:
- [ ] Sync `.claude/commands/meta.md` to `.claude/extensions/core/commands/meta.md`
- [ ] Sync `.claude/skills/skill-meta/SKILL.md` to `.claude/extensions/core/skills/skill-meta/SKILL.md`
- [ ] Sync `.claude/agents/meta-builder-agent.md` to `.claude/extensions/core/agents/meta-builder-agent.md`
- [ ] Copy `.claude/hooks/validate-meta-write.sh` to `.claude/extensions/core/hooks/validate-meta-write.sh` (if extension hooks dir exists)
- [ ] Verify all pairs are identical with diff

**Timing**: 20 minutes

**Depends on**: 1, 2, 3

**Files to modify**:
- `.claude/extensions/core/commands/meta.md` - Sync from loaded version
- `.claude/extensions/core/skills/skill-meta/SKILL.md` - Sync from loaded version
- `.claude/extensions/core/agents/meta-builder-agent.md` - Sync from loaded version

**Verification**:
- `diff .claude/commands/meta.md .claude/extensions/core/commands/meta.md` returns no output
- `diff .claude/skills/skill-meta/SKILL.md .claude/extensions/core/skills/skill-meta/SKILL.md` returns no output
- `diff .claude/agents/meta-builder-agent.md .claude/extensions/core/agents/meta-builder-agent.md` returns no output

## Testing & Validation

- [ ] `jq . .claude/settings.json` exits 0 (valid JSON)
- [ ] `bash .claude/hooks/validate-meta-write.sh` with mock `.claude/commands/test.md` input returns additionalContext
- [ ] `bash .claude/hooks/validate-meta-write.sh` with mock `specs/489_test/plans/01.md` input returns `{}`
- [ ] Grep confirms "Anti-Bypass Constraint" present in meta.md, SKILL.md
- [ ] Grep confirms "SCOPE BOUNDARY" present in meta-builder-agent.md
- [ ] All extension source/loaded pairs are identical

## Artifacts & Outputs

- `.claude/commands/meta.md` - Updated with Anti-Bypass section
- `.claude/hooks/validate-meta-write.sh` - NEW PostToolUse hook
- `.claude/settings.json` - Hook registration added
- `.claude/skills/skill-meta/SKILL.md` - Reinforced with anti-bypass
- `.claude/agents/meta-builder-agent.md` - SCOPE BOUNDARY added
- Extension source copies synced

## Rollback/Contingency

If the hook causes false positives during /implement:
1. Remove the hook entry from `.claude/settings.json` (immediate fix)
2. Narrow the path matching in validate-meta-write.sh
3. The Anti-Bypass sections in command/skill/agent remain useful regardless of hook status

Git revert of the implementation commit restores all files to pre-fix state.
