# Implementation Plan: Task #418

- **Task**: 418 - Add postflight self-execution fallback to skill wrapper pattern
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/418_add_postflight_fallback_to_skill_wrapper/reports/01_postflight-fallback.md
- **Artifacts**: plans/01_postflight-fallback.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan restructures the three core skill wrappers (skill-implementer, skill-researcher, skill-planner) and the thin-wrapper-skill pattern documentation so that postflight stages always execute, regardless of whether a subagent was spawned via the Task tool. The fix adds a Stage 5b self-execution fallback that instructs the skill executor to write `.return-meta.json` if it performed work inline, and reframes Stages 6+ with unconditional "ALWAYS EXECUTE" language. Extension skills (~25 files) receive the same treatment via batch application of the pattern.

### Research Integration

The research report identified three approaches and recommended Approach A (unconditional postflight). Key findings integrated:
- All three core skills have identical conditional phrasing ("After subagent returns") that makes postflight contingent on subagent invocation (Finding 1).
- The SubagentStop hook cannot detect inline execution (Finding 2), so the fix must be instructional.
- The postflight marker creates an insufficient safety net -- it blocks future sessions but does not trigger postflight for the current operation (Finding 3).
- All ~25 extension wrapper skills share the same vulnerability (Finding 4).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this meta task.

## Goals & Non-Goals

**Goals**:
- Ensure postflight stages (status update, artifact linking, git commit, cleanup) always execute after Stage 5, whether work was done by subagent or inline
- Add Stage 5b self-execution fallback to all three core skills
- Reframe postflight stages with unconditional language
- Update thin-wrapper-skill.md pattern documentation to reflect the fallback
- Propagate the fix to extension wrapper skills
- Preserve existing SubagentStop hook behavior when subagents ARE properly spawned

**Non-Goals**:
- Building a programmatic enforcement mechanism (PostToolUse hook) -- future work per research Priority 4
- Changing the SubagentStop hook script itself
- Modifying the `update-task-status.sh` script or other postflight infrastructure
- Restricting skill tool access (Approach C, rejected by research)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Model ignores Stage 5b and still skips postflight | H | L | Unconditional framing of postflight stages makes skip less likely; bold warnings reinforce |
| Batch extension update introduces inconsistencies | M | M | Use consistent template text; verify with grep after applying |
| Self-written .return-meta.json has wrong schema | M | M | Stage 5b explicitly references return-metadata-file.md for schema |
| Increased SKILL.md length reduces instruction compliance | L | L | Stage 5b is ~10 lines; postflight reframing is cosmetic header change |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Add postflight fallback to the three core skills [COMPLETED]

**Goal**: Add Stage 5b (self-execution fallback) and reframe postflight stages in skill-researcher, skill-planner, and skill-implementer SKILL.md files.

**Tasks**:
- [ ] Edit `.claude/skills/skill-researcher/SKILL.md`:
  - Add Stage 5b after Stage 5 with self-execution fallback instructions
  - Add "MANDATORY" warning at Stage 5 reinforcing Task tool usage
  - Add "Postflight (ALWAYS EXECUTE)" header before Stage 6
  - Remove conditional "After subagent returns" phrasing from Stage 6
- [ ] Edit `.claude/skills/skill-planner/SKILL.md`:
  - Same changes as skill-researcher (Stage 5b, warning, unconditional header, remove conditional phrasing)
- [ ] Edit `.claude/skills/skill-implementer/SKILL.md`:
  - Same changes as skill-researcher (Stage 5b, warning, unconditional header, remove conditional phrasing)
  - Note: skill-implementer already has Stage 5a (return format validation) -- Stage 5b goes after that
- [ ] Verify all three files with grep: confirm "ALWAYS EXECUTE" header present, "After subagent returns" removed from Stage 6

**Stage 5b template** (adapt per skill for status value and artifact type):
```markdown
### Stage 5b: Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Task tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent), you MUST write a
`.return-meta.json` file now before proceeding to postflight. Use the schema from
`return-metadata-file.md` with the appropriate status value for this operation.

If you DID use the Task tool (Stage 5), skip this stage -- the subagent already wrote the metadata.
```

**Postflight header template**:
```markdown
## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent (Stage 5) or inline (Stage 5b). Do NOT skip these stages for any reason.
```

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md` - Add Stage 5b, reframe postflight header, strengthen Stage 5 warning
- `.claude/skills/skill-planner/SKILL.md` - Same changes
- `.claude/skills/skill-implementer/SKILL.md` - Same changes (after existing Stage 5a)

**Verification**:
- Each SKILL.md contains "Stage 5b: Self-Execution Fallback"
- Each SKILL.md contains "Postflight (ALWAYS EXECUTE)" header
- No SKILL.md contains "After subagent returns" in Stage 6 heading or description
- Stage numbering is consistent (no gaps or duplicates)

---

### Phase 2: Update pattern documentation [COMPLETED]

**Goal**: Update thin-wrapper-skill.md and postflight-control.md to document the self-execution fallback pattern so future skills are created with it.

**Tasks**:
- [ ] Edit `.claude/context/patterns/thin-wrapper-skill.md`:
  - Add a "Self-Execution Fallback" section after section 3 (Invoke Subagent)
  - Explain the vulnerability and the fallback pattern
  - Update the example skill template to include Stage 5b
  - Add note to "When NOT to Use This Pattern" that direct-execution skills do not need the fallback
- [ ] Edit `.claude/context/patterns/postflight-control.md`:
  - Add a section documenting that postflight runs unconditionally
  - Note that the marker file is created before Stage 5 and cleaned up at Stage 10 regardless of execution path
  - Clarify that the SubagentStop hook is a complementary safety net, not the primary postflight trigger

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/context/patterns/thin-wrapper-skill.md` - Add fallback pattern section, update example
- `.claude/context/patterns/postflight-control.md` - Add unconditional postflight documentation

**Verification**:
- thin-wrapper-skill.md contains "Self-Execution Fallback" section
- postflight-control.md documents unconditional execution
- No contradictions with existing content (e.g., no remaining "only runs after subagent" claims)

---

### Phase 3: Propagate fallback to extension wrapper skills [COMPLETED]

**Goal**: Apply the Stage 5b / unconditional postflight pattern to the ~25 extension skills that use the thin-wrapper delegation pattern.

**Tasks**:
- [ ] Identify all extension SKILL.md files using the thin-wrapper pattern (grep for "Task tool" or "Invoke Subagent" in `.claude/extensions/*/skills/*/SKILL.md`)
- [ ] For each extension skill, apply the same three changes:
  1. Add Stage 5b self-execution fallback after the subagent invocation stage
  2. Add unconditional postflight header before the metadata reading stage
  3. Remove any conditional "After subagent returns" phrasing
- [ ] Verify consistency across all modified files with grep

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- ~25 extension SKILL.md files in `.claude/extensions/*/skills/*/SKILL.md`

**Verification**:
- All modified extension skills contain "Self-Execution Fallback" or equivalent
- All modified extension skills contain unconditional postflight language
- No extension skill contains "After subagent returns" in its postflight header
- Total count of modified extension files matches the identified set

---

## Testing & Validation

- [ ] All 3 core SKILL.md files contain Stage 5b and unconditional postflight header
- [ ] No core or extension SKILL.md contains conditional "After subagent returns" in postflight section headers
- [ ] thin-wrapper-skill.md documents the fallback pattern
- [ ] postflight-control.md documents unconditional execution
- [ ] Run `/research` or `/plan` on a test task to verify the skill still works end-to-end with subagent path
- [ ] Stage numbering is consistent in all modified files (no gaps or duplicates)

## Artifacts & Outputs

- Modified: `.claude/skills/skill-researcher/SKILL.md`
- Modified: `.claude/skills/skill-planner/SKILL.md`
- Modified: `.claude/skills/skill-implementer/SKILL.md`
- Modified: `.claude/context/patterns/thin-wrapper-skill.md`
- Modified: `.claude/context/patterns/postflight-control.md`
- Modified: ~25 extension SKILL.md files

## Rollback/Contingency

All changes are to markdown instruction files with no runtime code dependencies. Rollback is a simple `git revert` of the implementation commit. If individual skills break, the changes can be reverted per-file since each SKILL.md is independent. The SubagentStop hook and all scripts remain untouched by this plan.
