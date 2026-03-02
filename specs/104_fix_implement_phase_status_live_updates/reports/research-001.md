# Research Report: Task #104

**Task**: 104 - Fix /implement phase status live updates
**Date**: 2026-03-02
**Focus**: Root cause analysis of redundant phase status tags and missing plan-level status update

## Summary

The `/implement` command has two distinct bugs in its plan file status update logic. Both bugs stem from the same root cause: the use of **overly broad `sed` patterns** that match ALL `**Status**: [...]` lines in a plan file, instead of targeting specific lines. The plan file has a dual-status-field architecture (a plan-level `**Status**` metadata field AND per-phase `**Status**` fields), but all sed commands treat them identically and update them all simultaneously.

## Findings

### Bug 1: Preflight Updates ALL Phase Status Lines to [IMPLEMENTING]

**Root Cause**: In the skill preflight (Stage 2), the sed command:
```bash
sed -i "s/^\- \*\*Status\*\*: \[.*\]$/- **Status**: [IMPLEMENTING]/" "$plan_file"
```

This regex `^\- \*\*Status\*\*: \[.*\]$` matches EVERY line that begins with `- **Status**: [...]` in the plan file. Since the plan metadata AND each phase both use the same pattern (`- **Status**: [NOT STARTED]` or `**Status**: [NOT STARTED]`), this single sed command replaces ALL of them to `[IMPLEMENTING]`.

**Evidence**: The `.claude/output/implementation-001.md` file (the plan after preflight but before implementation) shows:
- Plan-level status: `**Status**: [IMPLEMENTING]` (correct)
- Phase 1-8 headings: Still `[NOT STARTED]` (heading status is not touched)
- Phase 1-8 Status lines: ALL say `**Status**: [IMPLEMENTING]` (BUG - should all still be `[NOT STARTED]`)

**Affected Files** (all implementation skills):
- `.claude/skills/skill-implementer/SKILL.md` line 96
- `.claude/skills/skill-neovim-implementation/SKILL.md` lines 88-89
- `.claude/skills/skill-typst-implementation/SKILL.md` line 76
- `.claude/skills/skill-latex-implementation/SKILL.md` line 76

### Bug 2: Postflight Updates ALL Status Lines Instead of Just Plan-Level

**Root Cause**: In the skill postflight (Stage 7) and the `/implement` command GATE OUT (CHECKPOINT 2), the same overly-broad sed pattern is used to update the plan status to `[COMPLETED]`:
```bash
sed -i 's/^\- \*\*Status\*\*: \[.*\]$/- **Status**: [COMPLETED]/' "$plan_file"
sed -i 's/^\*\*Status\*\*: \[.*\]$/**Status**: [COMPLETED]/' "$plan_file"
```

This replaces ALL `**Status**: [...]` lines with `[COMPLETED]`, regardless of whether they are the plan-level status or per-phase status markers. This means even phases that are `[NOT STARTED]` get marked `[COMPLETED]`.

**However**, in the observed case (task 102), the plan status field was NOT updated at all. It still reads `[IMPLEMENTING]`. This suggests the postflight status update either:
1. Was never reached (implementation was partial/interrupted), OR
2. Failed silently due to the implementation returning "partial" status

**Affected Files** (same 4 implementation skills plus command):
- `.claude/skills/skill-implementer/SKILL.md` lines 271-272 (completed), 303-304 (partial)
- `.claude/skills/skill-neovim-implementation/SKILL.md` lines 238-239
- `.claude/skills/skill-typst-implementation/SKILL.md` lines 287-288
- `.claude/skills/skill-latex-implementation/SKILL.md` lines 288-289
- `.claude/commands/implement.md` lines 141-143 (defensive correction)

### Bug 3: Dual Status Location Creates Ambiguity

The plan file format uses status markers in TWO places per phase:

1. **Phase heading**: `### Phase 1: Phase Name [STATUS]`
2. **Status metadata line**: `**Status**: [STATUS]`

The implementation agent (general-implementation-agent.md, Stage 4) updates phase status using the Edit tool, which targets specific strings. The agent instructions say:
- "Edit plan file: Change phase status to `[IN PROGRESS]`" (step A)
- "Edit plan file: Change phase status to `[COMPLETED]`" (step D)

But it does NOT specify which of the two status locations to update. In practice, the agent likely updates only one (either the heading or the metadata line), leaving the other stale. This creates inconsistency between the two locations for the same phase.

### Architecture Analysis

The plan file has this structure:
```markdown
# Implementation Plan: Task #N

**Status**: [PLAN-LEVEL STATUS]         <-- Plan metadata (line ~6)
...

### Phase 1: Name [PHASE-LEVEL STATUS]  <-- Phase heading status
**Status**: [PHASE-LEVEL STATUS]        <-- Phase metadata status (redundant with heading)
...

### Phase 2: Name [PHASE-LEVEL STATUS]
**Status**: [PHASE-LEVEL STATUS]
...
```

The problem is that the sed patterns cannot distinguish between:
1. The plan-level `**Status**` (which should track overall plan progress)
2. The per-phase `**Status**` (which should track individual phase progress)

Both use the identical markdown format.

### Scope of Impact

**All 4 core implementation skills** are affected:
- `skill-implementer` (general/meta/markdown)
- `skill-neovim-implementation`
- `skill-latex-implementation`
- `skill-typst-implementation`

**The `/implement` command** GATE OUT defensive correction is also affected (lines 141-143).

**Extension-based skills** (lean, z3, python) in `.claude/extensions/` do NOT have this pattern, so they are not affected.

## Recommendations

### Fix Strategy: Targeted sed Patterns with Line Context

The fix should address all three bugs with a unified approach:

#### Recommendation 1: Use line-number-aware sed for plan-level status

Instead of matching ALL `**Status**: [...]` lines, the preflight/postflight should update ONLY the first occurrence (the plan-level metadata):

```bash
# Update only the FIRST Status line (plan metadata, typically line 4-8)
sed -i '0,/^\*\*Status\*\*: \[.*\]/{s/^\*\*Status\*\*: \[.*\]$/**Status**: [IMPLEMENTING]/}' "$plan_file"
# Also handle bullet variant
sed -i '0,/^\- \*\*Status\*\*: \[.*\]/{s/^\- \*\*Status\*\*: \[.*\]$/- **Status**: [IMPLEMENTING]/}' "$plan_file"
```

The `0,/pattern/{s/pattern/replacement/}` sed idiom replaces only the first match.

#### Recommendation 2: Standardize on single phase status location

Eliminate the dual-status ambiguity. Choose ONE canonical location for phase status:

**Option A (Recommended): Phase heading only**
```markdown
### Phase 1: Name [STATUS]

**Estimated effort**: 0.5 hours
```
Remove the redundant `**Status**: [STATUS]` line from per-phase sections. This is cleaner, more readable, and eliminates the sed collision entirely.

**Option B: Metadata line only**
```markdown
### Phase 1: Name

**Status**: [STATUS]
**Estimated effort**: 0.5 hours
```
Remove the status from the heading. Less visually scannable but works.

**Why Option A is preferred**: Phase headings are immediately visible in markdown outline views and editors. Plan-level status remains in the metadata block, clearly separated from phase-level status.

#### Recommendation 3: Update agent instructions for precise edits

The implementation agents should use precise Edit tool operations that target specific strings. When updating phase status, the agent should:

1. Read the plan file first
2. Construct the exact old_string (including phase name for uniqueness)
3. Use Edit with the precise old_string and new_string

Example for heading-based status:
```
old_string: "### Phase 3: Populate Lean Extension [NOT STARTED]"
new_string: "### Phase 3: Populate Lean Extension [IN PROGRESS]"
```

This is inherently phase-specific and cannot accidentally update other phases.

#### Recommendation 4: Update the artifact-formats.md plan template

Remove the redundant `**Status**: [STATUS]` line from the phase template in artifact-formats.md. The template currently shows:
```markdown
### Phase 1: {Name}

**Estimated effort**: {hours}
**Status**: [NOT STARTED]
```

It should become:
```markdown
### Phase 1: {Name} [NOT STARTED]

**Estimated effort**: {hours}
```

#### Recommendation 5: Update all affected files

Files requiring changes:

**Plan template (remove redundant status line)**:
- `.claude/rules/artifact-formats.md` - Remove `**Status**: [NOT STARTED]` from phase template

**Skill preflight (target only plan-level status)**:
- `.claude/skills/skill-implementer/SKILL.md` - Stage 2 sed command
- `.claude/skills/skill-neovim-implementation/SKILL.md` - Stage 2 sed commands
- `.claude/skills/skill-typst-implementation/SKILL.md` - Stage 2 sed command
- `.claude/skills/skill-latex-implementation/SKILL.md` - Stage 2 sed command

**Skill postflight (target only plan-level status)**:
- `.claude/skills/skill-implementer/SKILL.md` - Stage 7 sed commands (both completed and partial)
- `.claude/skills/skill-neovim-implementation/SKILL.md` - Stage 7 sed commands
- `.claude/skills/skill-typst-implementation/SKILL.md` - Stage 7 sed commands
- `.claude/skills/skill-latex-implementation/SKILL.md` - Stage 7 sed commands

**Command GATE OUT (target only plan-level status)**:
- `.claude/commands/implement.md` - CHECKPOINT 2 defensive correction sed commands

**Agent instructions (clarify phase status editing)**:
- `.claude/agents/general-implementation-agent.md` - Phase Checkpoint Protocol
- `.claude/agents/neovim-implementation-agent.md` - Phase Checkpoint Protocol
- `.claude/agents/latex-implementation-agent.md` - Phase Checkpoint Protocol
- `.claude/agents/typst-implementation-agent.md` - Phase Checkpoint Protocol

**Planner agent (generate correct format)**:
- Planner agent or planner skill may need updates to generate plans with heading-only status

### Implementation Complexity

This is a systematic but straightforward fix:
- **14 files** need modification
- All changes follow the same pattern (sed first-match + remove redundant status line)
- No logic changes needed, only pattern refinement
- Risk is low since the fix narrows the scope of existing operations

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Existing plans have dual status format | Medium | Agent should handle both formats gracefully during transition |
| First-match sed syntax varies across platforms | Low | GNU sed `0,/pat/` syntax is standard on Linux (NixOS target) |
| Planner still generates old format | Medium | Update planner template simultaneously |
| Extension-based skills get same bug later | Low | Document the correct pattern in a shared reference |

## References

- `.claude/skills/skill-implementer/SKILL.md` - Primary affected skill (general/meta/markdown)
- `.claude/skills/skill-neovim-implementation/SKILL.md` - Neovim implementation skill
- `.claude/skills/skill-typst-implementation/SKILL.md` - Typst implementation skill
- `.claude/skills/skill-latex-implementation/SKILL.md` - LaTeX implementation skill
- `.claude/commands/implement.md` - /implement command definition
- `.claude/agents/general-implementation-agent.md` - General implementation agent
- `.claude/rules/artifact-formats.md` - Plan template with Phase Status Markers
- `.claude/output/implementation-001.md` - Concrete evidence of Bug 1 (all phases set to [IMPLEMENTING])
- `specs/102_review_extensions_populate_missing_resources/plans/implementation-001.md` - Concrete evidence of plan still showing [IMPLEMENTING] after partial completion

## Next Steps

Run `/plan 104` to create an implementation plan based on these findings.
