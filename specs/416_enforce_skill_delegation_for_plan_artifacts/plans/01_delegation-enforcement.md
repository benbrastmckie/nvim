# Implementation Plan: Enforce Skill Delegation for Plan Artifacts

- **Task**: 416 - enforce_skill_delegation_for_plan_artifacts
- **Status**: [NOT STARTED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/416_enforce_skill_delegation_for_plan_artifacts/reports/01_skill-delegation-enforcement.md
- **Artifacts**: plans/01_delegation-enforcement.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The /plan command occasionally bypasses skill-planner delegation and writes plan files directly, producing artifacts that violate the plan format standard. This plan implements a layered defense: a PostToolUse validation hook that catches non-conforming artifact writes at the infrastructure level, hardened anti-bypass language in command specs, and a local .memory/ entry that persists the lesson across sessions. The hook extends to all artifact types (plans, reports, summaries), not just plans.

### Research Integration

Research confirmed that all existing enforcement (plan-format-enforcement.md rule, validate-artifact.sh script, format injection in skill-planner) depends on skill-planner being invoked. The PostToolUse hook closes this gap by operating outside the model's context. The hook uses stdin for input (per official docs) with env var fallback for robustness. PreToolUse was rejected because it cannot distinguish legitimate from bypass writes without fragile delegation-depth markers.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This plan advances the "Agent System Quality" priority in Phase 1 of ROADMAP.md. It directly improves artifact format enforcement, which is related to the subagent-return reference cleanup and agent frontmatter validation items.

## Goals & Non-Goals

**Goals**:
- Create a PostToolUse hook that validates plan, report, and summary artifacts after Write/Edit
- Harden plan.md, research.md, and implement.md command specs with anti-bypass constraints
- Create a .memory/ entry documenting the delegation requirement
- Ensure all three mechanisms work independently (defense in depth)

**Non-Goals**:
- Implementing PreToolUse blocking (rejected due to inability to distinguish legitimate writes)
- Modifying validate-artifact.sh itself (it already has sufficient coverage)
- Adding CI/CD enforcement (out of scope for this task)
- Changing the skill-planner or skill-researcher internals

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Hook adds latency to all Write/Edit calls | L | M | Early path-match exit for non-artifact files (~1ms) |
| Hook stdin format changes in future Claude Code versions | M | L | Handle both stdin and env var inputs |
| Model ignores corrective context from hook | M | L | additionalContext is injected as system-level context with high authority |
| .memory/ files not reliably loaded in all sessions | L | M | .memory/ is tertiary defense; hook is primary |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: PostToolUse Validation Hook [NOT STARTED]

**Goal**: Create the hook script and register it in settings.json so that any Write/Edit to artifact paths triggers validation.

**Tasks**:
- [ ] Create `.claude/hooks/validate-plan-write.sh` with stdin-based input parsing
- [ ] Implement path matching for `specs/*/plans/*.md`, `specs/*/reports/*.md`, and `specs/*/summaries/*.md`
- [ ] Map each path pattern to the correct artifact type for validate-artifact.sh (plan, report, summary)
- [ ] Return `additionalContext` with corrective message on validation failure
- [ ] Handle both stdin and `$CLAUDE_TOOL_INPUT` env var inputs for robustness
- [ ] Add PostToolUse entry to settings.json matching `Write|Edit` (extend existing PostToolUse array)
- [ ] Make script executable with `chmod +x`
- [ ] Test hook with a deliberately malformed plan file path check

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/hooks/validate-plan-write.sh` - New file: PostToolUse hook script
- `.claude/settings.json` - Add PostToolUse hook entry for Write|Edit matcher

**Verification**:
- Hook script exists and is executable
- settings.json contains PostToolUse entry with `Write|Edit` matcher
- Script correctly identifies artifact paths and skips non-artifact files
- Script calls validate-artifact.sh with correct type argument

---

### Phase 2: Command Spec Hardening [NOT STARTED]

**Goal**: Add explicit anti-bypass constraint sections to plan.md, research.md, and implement.md command specs.

**Tasks**:
- [ ] Add "Anti-Bypass Constraint" section to `.claude/commands/plan.md` before STAGE 0
- [ ] Add "Anti-Bypass Constraint" section to `.claude/commands/research.md` before execution stages
- [ ] Add "Anti-Bypass Constraint" section to `.claude/commands/implement.md` before execution stages
- [ ] Each section must: state the prohibition, explain consequences (hook detection, missing fields), and direct to Skill invocation
- [ ] Verify wording is consistent across all three command specs

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/commands/plan.md` - Add anti-bypass constraint section
- `.claude/commands/research.md` - Add anti-bypass constraint section
- `.claude/commands/implement.md` - Add anti-bypass constraint section

**Verification**:
- All three command specs contain the "Anti-Bypass Constraint" section
- Section appears before execution stages in each file
- Wording explicitly prohibits direct artifact writes
- Consequences (hook detection) are referenced

---

### Phase 3: Memory Entry [NOT STARTED]

**Goal**: Create a .memory/ entry that persists the delegation requirement as a learned lesson across sessions.

**Tasks**:
- [ ] Create `.memory/10-Memories/MEM-plan-delegation-required.md` with proper YAML frontmatter
- [ ] Include incident context (task 414, 2026-04-13)
- [ ] State the rule: always invoke Skill tools for artifact creation
- [ ] Reference the PostToolUse hook as the enforcement mechanism
- [ ] Follow the .memory/ template format (title, created, tags, topic, source, modified fields)

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `.memory/10-Memories/MEM-plan-delegation-required.md` - New file: memory entry

**Verification**:
- File exists with valid YAML frontmatter
- Contains incident context and enforcement rule
- Tags include relevant keywords (enforcement, delegation, bypass-prevention)

---

### Phase 4: Integration Verification [NOT STARTED]

**Goal**: Verify all three enforcement mechanisms are in place and functioning correctly as a system.

**Tasks**:
- [ ] Run validate-artifact.sh against a known-good plan file to confirm it passes
- [ ] Verify settings.json is valid JSON after modifications
- [ ] Verify the hook script handles edge cases: non-artifact paths exit cleanly, missing validate-artifact.sh fails gracefully
- [ ] Check that the existing PostToolUse hook for state.json validation still works alongside the new hook
- [ ] Review all modified files for consistency

**Timing**: 15 minutes

**Depends on**: 2, 3

**Files to modify**:
- No new files; verification only

**Verification**:
- settings.json parses as valid JSON
- validate-plan-write.sh exits 0 for non-artifact paths
- validate-plan-write.sh calls validate-artifact.sh correctly for artifact paths
- All three command specs have anti-bypass sections
- Memory entry exists with correct format

## Testing & Validation

- [ ] Hook correctly identifies plan files at `specs/*/plans/*.md` and triggers validation
- [ ] Hook correctly identifies report files at `specs/*/reports/*.md` and triggers validation
- [ ] Hook correctly identifies summary files at `specs/*/summaries/*.md` and triggers validation
- [ ] Hook returns empty JSON `{}` for non-artifact file writes (no false positives)
- [ ] Hook returns `additionalContext` with corrective message when validation fails
- [ ] settings.json remains valid JSON with new PostToolUse entry
- [ ] Existing state.json PostToolUse hook continues to function
- [ ] All three command specs contain anti-bypass constraint sections
- [ ] Memory entry follows .memory/ template format

## Artifacts & Outputs

- `.claude/hooks/validate-plan-write.sh` - PostToolUse hook script
- `.claude/settings.json` - Updated with new PostToolUse hook entry
- `.claude/commands/plan.md` - Updated with anti-bypass constraint
- `.claude/commands/research.md` - Updated with anti-bypass constraint
- `.claude/commands/implement.md` - Updated with anti-bypass constraint
- `.memory/10-Memories/MEM-plan-delegation-required.md` - Memory entry

## Rollback/Contingency

To revert all changes:
1. Remove the PostToolUse hook entry from settings.json (the second entry in the PostToolUse array)
2. Delete `.claude/hooks/validate-plan-write.sh`
3. Revert the anti-bypass sections from plan.md, research.md, and implement.md using `git checkout`
4. Delete `.memory/10-Memories/MEM-plan-delegation-required.md`

All changes are additive and independent of each other. Any single mechanism can be removed without affecting the others.
