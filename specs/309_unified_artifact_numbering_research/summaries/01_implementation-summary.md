# Implementation Summary: Task #309

**Completed**: 2026-03-27
**Duration**: All 6 phases executed

## Changes Made

Implemented unified artifact numbering across the agent system, where all artifact types (reports, plans, summaries) share a single sequence number per task within a "round" of work. Research advances the sequence while plan and summary inherit the current round number.

Added team mode artifact naming conventions where parallel teammates use the same artifact number with a letter suffix (a, b, c, d), and synthesis artifacts use the base number without suffix.

## Files Modified

### Documentation (Phase 1)
- `.claude/context/reference/state-management-schema.md` - Added `next_artifact_number` field schema, semantics, round concept, and backward compatibility
- `.claude/rules/artifact-formats.md` - Changed from "Per-Type Sequential Numbering" to "Unified Sequential Numbering" with team mode examples

### Single-Agent Skills (Phase 2)
- `.claude/skills/skill-researcher/SKILL.md` - Added Stage 3a to read `next_artifact_number`, added artifact_number to delegation context, added postflight increment
- `.claude/skills/skill-planner/SKILL.md` - Added Stage 3a to calculate (current-1), added artifact_number to delegation context
- `.claude/skills/skill-implementer/SKILL.md` - Added Stage 3a to calculate (current-1), added artifact_number to delegation context

### Team Skills (Phase 3)
- `.claude/skills/skill-team-research/SKILL.md` - Updated Stage 5a to use unified numbering, added teammate_letter to delegation context, added postflight increment
- `.claude/skills/skill-team-plan/SKILL.md` - Updated Stage 5a to use (current-1) unified numbering, added teammate_letter to delegation context
- `.claude/skills/skill-team-implement/SKILL.md` - Added Stage 4b to calculate (current-1), uses unified numbering
- `.claude/utils/team-wave-helpers.md` - Added Artifact Numbering Helpers section with read patterns for research vs plan/implement

### Agents (Phase 4)
- `.claude/agents/general-research-agent.md` - Added artifact_number and optional teammate_letter to delegation context parsing, updated path construction
- `.claude/agents/planner-agent.md` - Added artifact_number and optional teammate_letter to delegation context, updated path construction
- `.claude/agents/general-implementation-agent.md` - Added artifact_number to delegation context, updated summary path construction
- `.claude/agents/spawn-agent.md` - Changed from hardcoded 02 to using artifact_number from delegation context

### Commands (Phase 5)
- `.claude/commands/revise.md` - Added note about same-round semantics (revision doesn't change artifact number)

## Key Changes

1. **New Field**: `next_artifact_number` added to task entries in state.json (initial value: 1)
2. **Research Advances Sequence**: Only research operations increment `next_artifact_number` in postflight
3. **Plan/Implement Stay in Round**: Use `(next_artifact_number - 1)` to stay in same round as research
4. **Team Mode Naming**: Teammates use `{NN}_teammate-{letter}-findings.md`, synthesis uses `{NN}_{slug}.md`
5. **Backward Compatibility**: Directory scanning fallback when field is missing

## Verification

- All skill files correctly distinguish research (increments) vs plan/implement (uses current-1)
- All agent files accept artifact_number from delegation context
- Team mode skills pass both artifact_number and teammate_letter to teammates
- Documentation is consistent across schema, rules, and helpers

## Notes

- Existing tasks without `next_artifact_number` will use fallback directory scanning
- No migration needed for existing artifact files (historical artifacts remain unchanged)
- The /revise command creates new plan versions within the same round
