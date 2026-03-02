# Research Report: Task #104

**Task**: 104 - Fix /implement phase status live updates
**Date**: 2026-03-02
**Focus**: Detailed implementation specification for single plan-level Status + header-only phase status

## Summary

This report builds on research-001.md with a concrete implementation specification. The key finding is that there are **two competing format standards** for phase status in the codebase: artifact-formats.md uses a `**Status**: [STATUS]` metadata line per phase, while plan-format.md specifies `### Phase N: Name [STATUS]` heading-only status. The planner agent generates plans following plan-format.md (status in header) but ALSO adds a `**Status**: [STATUS]` metadata line, creating the dual-status problem. The fix requires aligning all files to the plan-format.md approach: phase status lives ONLY in the heading, and plan-level status lives ONLY in the top metadata block.

## Findings

### Finding 1: The Two Competing Format Standards

**artifact-formats.md** (`.claude/rules/artifact-formats.md`) at line 96-98 shows:
```markdown
### Phase 1: {Name}

**Estimated effort**: {hours}
**Status**: [NOT STARTED]
```

This template puts status OUTSIDE the heading, as a metadata line.

**plan-format.md** (`.claude/context/core/formats/plan-format.md`) at line 75 explicitly states:
```
### Phase N: {name} [STATUS]
```

And does NOT include a separate `**Status**:` line under each phase.

The planner agent (`.claude/agents/planner-agent.md`) follows plan-format.md and generates headings like `### Phase 1: Name [NOT STARTED]` -- but existing plans ALSO have `**Status**: [NOT STARTED]` metadata lines, creating the dual-status pattern observed in research-001.

### Finding 2: Concrete Evidence from Task 102 Plan

The task 102 plan (`specs/102_review_extensions_populate_missing_resources/plans/implementation-001.md`) demonstrates the dual-status issue. Every phase has status in BOTH locations:

| Line | Content |
|------|---------|
| 6 | `**Status**: [IMPLEMENTING]` (plan-level metadata) |
| 56 | `### Phase 1: Rename claudemd-section.md to EXTENSION.md [COMPLETED]` |
| 58 | `**Status**: [COMPLETED]` (redundant per-phase metadata) |
| 95 | `### Phase 2: Remove neovim/ Extension [COMPLETED]` |
| 97 | `**Status**: [COMPLETED]` (redundant per-phase metadata) |
| 238 | `### Phase 5: Populate Typst Extension [NOT STARTED]` |
| 240 | `**Status**: [NOT STARTED]` (redundant per-phase metadata) |

The plan-level status at line 6 says `[IMPLEMENTING]` while phases 1-4 are `[COMPLETED]` and phases 5-8 are `[NOT STARTED]`. The sed patterns in the skill preflight updated ALL `**Status**:` lines to `[IMPLEMENTING]` initially (Bug 1), but the heading status was left untouched.

### Finding 3: Complete Status Update Lifecycle

The status update flow involves three layers: command, skill, and agent. Here is the complete lifecycle with the proposed fix:

```
/implement N
  |
  +--> Command GATE IN
  |    - Validates task, loads plan, detects resume point
  |    - Reads phase heading status markers to find resume point
  |
  +--> Skill Preflight (Stage 2)
  |    - Updates state.json: status -> "implementing"
  |    - Updates TODO.md: [PLANNED] -> [IMPLEMENTING]
  |    - Updates plan file: plan-level **Status** -> [IMPLEMENTING]
  |    - Does NOT touch phase headings (correct behavior)
  |
  +--> Agent Execution (Stage 4 loop)
  |    For each phase:
  |      A. Edit plan heading: [NOT STARTED] -> [IN PROGRESS]
  |      B. Execute phase steps
  |      C. Verify phase completion
  |      D. Edit plan heading: [IN PROGRESS] -> [COMPLETED]
  |      E. Git commit phase
  |
  +--> Skill Postflight (Stage 7)
  |    - Updates state.json: status -> "completed" or keeps "implementing"
  |    - Updates TODO.md: [IMPLEMENTING] -> [COMPLETED]
  |    - Updates plan file: plan-level **Status** -> [COMPLETED] or [PARTIAL]
  |    - Does NOT touch phase headings (correct behavior)
  |
  +--> Command GATE OUT (defensive)
       - Verifies plan-level status was updated
       - Applies correction if needed (plan-level only)
```

### Finding 4: Exact sed Patterns Needed for Plan-Level Status

The current broken pattern in ALL 4 skills:
```bash
# BROKEN: matches ALL **Status**: lines in the file
sed -i "s/^\- \*\*Status\*\*: \[.*\]$/- **Status**: [IMPLEMENTING]/" "$plan_file"
sed -i 's/^\*\*Status\*\*: \[.*\]$/**Status**: [IMPLEMENTING]/' "$plan_file"
```

The correct pattern must target ONLY the first occurrence (the plan-level metadata). GNU sed provides the `0,/pattern/` address range:
```bash
# CORRECT: matches only the FIRST **Status**: line (plan metadata)
sed -i '0,/^\*\*Status\*\*: \[.*\]/{s/^\*\*Status\*\*: \[.*\]$/**Status**: [IMPLEMENTING]/}' "$plan_file"
```

For plans using bullet-prefix format (`- **Status**:`):
```bash
sed -i '0,/^\- \*\*Status\*\*: \[.*\]/{s/^\- \*\*Status\*\*: \[.*\]$/- **Status**: [IMPLEMENTING]/}' "$plan_file"
```

**Important**: Since the fix REMOVES the per-phase `**Status**:` lines, only the plan-level line will exist, making the first-match optimization technically unnecessary -- but it is a safety measure for backward compatibility with plans generated before the fix.

### Finding 5: Exact Edit Tool Patterns for Phase Header Status

The agents use the Edit tool (not sed) for phase-level status updates. The current agent instructions say:

> "Edit plan file: Change phase status to `[IN PROGRESS]`"

This is ambiguous. The precise pattern should be:

**To mark phase as in-progress**:
```
old_string: "### Phase 3: Populate Lean Extension [NOT STARTED]"
new_string: "### Phase 3: Populate Lean Extension [IN PROGRESS]"
```

**To mark phase as completed**:
```
old_string: "### Phase 3: Populate Lean Extension [IN PROGRESS]"
new_string: "### Phase 3: Populate Lean Extension [COMPLETED]"
```

This is inherently unique per phase (each heading contains the phase name), so the Edit tool will never accidentally match the wrong location.

### Finding 6: Complete File Change Inventory

The changes fall into 5 categories:

#### Category A: Plan Template (remove per-phase **Status**: line)

1. **`.claude/rules/artifact-formats.md`** (lines 96-98)
   - Remove `**Status**: [NOT STARTED]` from the phase template
   - Keep status in the heading: `### Phase 1: {Name} [NOT STARTED]`
   - The artifact-formats.md template currently lacks the `[NOT STARTED]` in the heading -- add it

2. **`.claude/context/core/formats/plan-format.md`** (already correct)
   - This file already specifies `### Phase N: {name} [STATUS]` (line 75)
   - No changes needed -- this IS the target format

3. **`.claude/agents/planner-agent.md`** (line 232)
   - The planner already generates `### Phase 1: {Name} [NOT STARTED]` in headings
   - Remove any instruction to also generate a `**Status**: [STATUS]` line per phase
   - If the planner currently generates the dual format, update to single-heading format

#### Category B: Skill Preflight (update plan-level status ONLY, first-match sed)

4. **`.claude/skills/skill-implementer/SKILL.md`** (line 96)
   - Current: `sed -i "s/^\- \*\*Status\*\*: \[.*\]$/- **Status**: [IMPLEMENTING]/" "$plan_file"`
   - Replace with first-match pattern targeting plan-level status only

5. **`.claude/skills/skill-neovim-implementation/SKILL.md`** (lines 88-89)
   - Current: two sed commands matching ALL status lines
   - Replace with first-match patterns

6. **`.claude/skills/skill-latex-implementation/SKILL.md`** (line 76)
   - Current: single sed command matching ALL status lines
   - Replace with first-match pattern

7. **`.claude/skills/skill-typst-implementation/SKILL.md`** (line 76)
   - Current: single sed command matching ALL status lines
   - Replace with first-match pattern

#### Category C: Skill Postflight (update plan-level status ONLY, first-match sed)

8. **`.claude/skills/skill-implementer/SKILL.md`** (lines 271-272 completed, lines 303-304 partial)
   - Current: sed commands matching ALL status lines
   - Replace with first-match patterns for both completed and partial cases

9. **`.claude/skills/skill-neovim-implementation/SKILL.md`** (lines 238-239 completed, lines 270-271 partial)
   - Same fix pattern

10. **`.claude/skills/skill-latex-implementation/SKILL.md`** (lines 288-289 completed, lines 320-321 partial)
    - Same fix pattern

11. **`.claude/skills/skill-typst-implementation/SKILL.md`** (lines 287-288 completed, lines 320-321 partial)
    - Same fix pattern

#### Category D: Command GATE OUT (defensive plan-level correction)

12. **`.claude/commands/implement.md`** (lines 141-143)
    - Current: sed commands matching ALL status lines
    - Replace with first-match patterns

#### Category E: Agent Instructions (clarify phase heading edits)

13. **`.claude/agents/general-implementation-agent.md`** (Stage 4, Phase Checkpoint Protocol)
    - Clarify that "change phase status to [IN PROGRESS]" means editing the HEADING line
    - Add explicit Edit tool example with old_string/new_string pattern
    - Remove any mention of per-phase `**Status**:` metadata line updates

14. **`.claude/agents/neovim-implementation-agent.md`** (Stage 4, Phase Checkpoint Protocol)
    - Same clarification

15. **`.claude/agents/latex-implementation-agent.md`** (Stage 4, Phase Checkpoint Protocol)
    - Same clarification

16. **`.claude/agents/typst-implementation-agent.md`** (Stage 4, Phase Checkpoint Protocol)
    - Same clarification

### Finding 7: Backward Compatibility Considerations

Existing plans (like task 102) have the dual-status format. The fix must handle both:

1. **New plans** (generated after the fix): Will have status ONLY in the heading. The per-phase `**Status**:` line will not exist. The first-match sed in preflight/postflight will correctly target only the plan-level metadata.

2. **Old plans** (generated before the fix): Still have per-phase `**Status**:` lines. The first-match sed in preflight/postflight will still correctly target only the FIRST `**Status**:` line (the plan-level metadata). The per-phase lines will be ignored (stale but harmless).

3. **Resume scenarios**: Agents read phase status from HEADINGS (which are already the canonical location for the `[NOT STARTED]`, `[IN PROGRESS]`, `[COMPLETED]` markers). The per-phase `**Status**:` lines in old plans are redundant and will naturally become stale but will not break resume detection.

**No migration of existing plans is needed**. The fix is forward-compatible.

### Finding 8: Phase Status Markers vs Plan-Level Status Markers

These are distinct sets:

**Plan-level status markers** (in `**Status**: [STATUS]` metadata line):
- `[NOT STARTED]` - Plan created, not yet executing
- `[IMPLEMENTING]` - Implementation in progress
- `[COMPLETED]` - All phases done
- `[PARTIAL]` - Some phases done, interrupted
- `[BLOCKED]` - Cannot proceed

**Phase-level status markers** (in `### Phase N: Name [STATUS]` heading):
- `[NOT STARTED]` - Phase not yet started
- `[IN PROGRESS]` - Phase currently executing
- `[COMPLETED]` - Phase finished
- `[PARTIAL]` - Phase partially complete (interrupted)
- `[BLOCKED]` - Phase cannot proceed

Note: Plan-level uses `[IMPLEMENTING]` while phase-level uses `[IN PROGRESS]`. This distinction is intentional -- the plan-level marker mirrors the task state machine (`implementing` status), while the phase-level marker is more granular.

### Finding 9: Resume Detection Logic

The `/implement` command GATE IN (Stage 5 in implement.md) and the agent Stage 3 both scan for resume points. Currently they look for status markers in phase headings:

```
- [COMPLETED] -> Skip
- [IN PROGRESS] -> Resume here
- [PARTIAL] -> Resume here
- [NOT STARTED] -> Start here
```

This is already correct for the heading-only approach. The agents read phase headings, not `**Status**:` metadata lines, to determine resume points. No change needed in resume detection logic.

### Finding 10: Planner Agent Phase Format Analysis

The planner agent generates this format (from planner-agent.md line 232):
```markdown
### Phase 1: {Name} [NOT STARTED]

**Goal**: {What this phase accomplishes}

**Tasks**:
- [ ] {Task 1}

**Timing**: {X hours}
```

There is NO `**Status**: [NOT STARTED]` line in the planner's template. However, the actual generated plan (task 102) has BOTH the heading status AND the `**Status**:` line. This means either:
1. The planner adds it despite the template (unlikely given the template), OR
2. The plan format was manually edited or generated by an earlier version that included it, OR
3. The planner loads artifact-formats.md which has the `**Status**:` line and follows that instead

Looking at artifact-formats.md, it has:
```markdown
### Phase 1: {Name}

**Estimated effort**: {hours}
**Status**: [NOT STARTED]
```

Note artifact-formats.md has the heading WITHOUT `[NOT STARTED]` but HAS the `**Status**:` line. This is the opposite of plan-format.md. The planner appears to merge both formats, producing the dual-status pattern.

**Resolution**: Update artifact-formats.md to match plan-format.md (heading WITH status, NO separate `**Status**:` line).

## Recommendations

### Recommended Approach: Heading-Only Phase Status

Align everything to plan-format.md's approach:

1. Phase status lives ONLY in the heading: `### Phase N: Name [STATUS]`
2. Plan-level status lives ONLY in the top metadata: `**Status**: [STATUS]`
3. Remove per-phase `**Status**: [STATUS]` metadata lines from templates
4. Use first-match sed for plan-level updates (safety measure)
5. Use Edit tool with heading-specific old_string for phase updates

### Implementation Order

The changes should be applied in this order to minimize risk:

1. **artifact-formats.md** - Fix the template (source of truth for plan format)
2. **Planner agent** - Ensure it generates heading-only status
3. **4 skill preflights** - First-match sed for plan-level status
4. **4 skill postflights** - First-match sed for plan-level status (completed + partial)
5. **Command GATE OUT** - First-match sed for defensive correction
6. **4 agent instructions** - Clarify heading-based phase status edits

Total: 16 files, all following the same pattern.

### Specific sed Replacement Patterns

**For preflight (plan -> IMPLEMENTING)**:
```bash
# Replace ALL current sed commands with these two:
sed -i '0,/^\*\*Status\*\*: \[.*\]/{s/^\*\*Status\*\*: \[.*\]$/**Status**: [IMPLEMENTING]/}' "$plan_file"
sed -i '0,/^\- \*\*Status\*\*: \[.*\]/{s/^\- \*\*Status\*\*: \[.*\]$/- **Status**: [IMPLEMENTING]/}' "$plan_file"
```

**For postflight completed (plan -> COMPLETED)**:
```bash
sed -i '0,/^\*\*Status\*\*: \[.*\]/{s/^\*\*Status\*\*: \[.*\]$/**Status**: [COMPLETED]/}' "$plan_file"
sed -i '0,/^\- \*\*Status\*\*: \[.*\]/{s/^\- \*\*Status\*\*: \[.*\]$/- **Status**: [COMPLETED]/}' "$plan_file"
```

**For postflight partial (plan -> PARTIAL)**:
```bash
sed -i '0,/^\*\*Status\*\*: \[.*\]/{s/^\*\*Status\*\*: \[.*\]$/**Status**: [PARTIAL]/}' "$plan_file"
sed -i '0,/^\- \*\*Status\*\*: \[.*\]/{s/^\- \*\*Status\*\*: \[.*\]$/- **Status**: [PARTIAL]/}' "$plan_file"
```

### Agent Edit Tool Instructions

Replace ambiguous "change phase status" with explicit:

```markdown
**A. Mark Phase In Progress**
Edit plan file: Change the phase heading status marker.
Use the Edit tool with:
- old_string: `### Phase {P}: {Phase Name} [NOT STARTED]`
- new_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`

**D. Mark Phase Complete**
Edit plan file: Change the phase heading status marker.
Use the Edit tool with:
- old_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`
- new_string: `### Phase {P}: {Phase Name} [COMPLETED]`
```

This ensures the Edit tool targets the heading line (unique per phase) rather than a generic `**Status**:` line.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Old plans have dual-status format | Low | First-match sed safely targets only plan-level; stale per-phase lines are harmless |
| Planner generates dual-status despite template fix | Medium | Update both artifact-formats.md AND planner-agent.md; verify with test plan generation |
| GNU sed `0,/pat/` not available on all platforms | Low | Project targets NixOS Linux where GNU sed is standard |
| Agent fails to construct correct Edit old_string | Medium | Agent reads plan file first; heading text is unique per phase |
| Extension-based skills (lean, z3, python) need same fix later | Low | They do not currently have implementation skills; document the pattern in a shared reference |

## References

- `.claude/rules/artifact-formats.md` - Plan format template (needs update)
- `.claude/context/core/formats/plan-format.md` - Canonical plan format (already correct)
- `.claude/agents/planner-agent.md` - Plan generation agent
- `.claude/skills/skill-implementer/SKILL.md` - General implementation skill
- `.claude/skills/skill-neovim-implementation/SKILL.md` - Neovim implementation skill
- `.claude/skills/skill-latex-implementation/SKILL.md` - LaTeX implementation skill
- `.claude/skills/skill-typst-implementation/SKILL.md` - Typst implementation skill
- `.claude/commands/implement.md` - /implement command definition
- `.claude/agents/general-implementation-agent.md` - General implementation agent
- `.claude/agents/neovim-implementation-agent.md` - Neovim implementation agent
- `.claude/agents/latex-implementation-agent.md` - LaTeX implementation agent
- `.claude/agents/typst-implementation-agent.md` - Typst implementation agent
- `specs/102_review_extensions_populate_missing_resources/plans/implementation-001.md` - Evidence of dual-status in real plan
- `specs/104_fix_implement_phase_status_live_updates/reports/research-001.md` - Prior research report

## Next Steps

Run `/plan 104` to create an implementation plan based on these findings. The plan should have 3-4 phases:
1. Fix plan templates (artifact-formats.md)
2. Fix skill preflight/postflight sed patterns (4 skills + command)
3. Fix agent instructions (4 agents)
4. Verification phase (generate test plan, verify sed patterns)
