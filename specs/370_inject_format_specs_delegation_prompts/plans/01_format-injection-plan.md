# Implementation Plan: Inject Format Specs into Delegation Prompts

- **Task**: 370 - Inject artifact format specifications into skill delegation prompts
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/370_inject_format_specs_delegation_prompts/reports/01_format-injection-research.md
- **Artifacts**: plans/01_format-injection-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Artifact-producing skills (skill-planner, skill-researcher, skill-implementer) rely on advisory `@` references in agent definitions to communicate format requirements, but these are not auto-resolved by the runtime. This plan adds a new Stage 4b to each skill that reads the relevant format file and injects its content as a clearly-delimited section in the delegation prompt passed to the subagent, ensuring format compliance without depending on the agent's initiative to read the file.

### Research Integration

Research report (01_format-injection-research.md) confirmed: all three skills share an identical Stage 4/Stage 5 pattern; format files are small (59-169 lines, ~400-1200 tokens); Option B (separate prompt section with XML delimiters) is preferred over JSON embedding for salience. Extension skills are deferred to a follow-up task.

### Roadmap Alignment

No ROAD_MAP.md found.

## Goals & Non-Goals

**Goals**:
- Ensure subagents always receive the full format specification for their output artifact
- Add a new Stage 4b to skill-planner, skill-researcher, and skill-implementer that reads and injects format content
- Update Stage 5 prompt instructions to reference the injected format specification
- Establish the pattern for future extension skill updates

**Non-Goals**:
- Updating extension skills (deferred to follow-up task)
- Modifying agent definitions (the `@` references remain as documentation/fallback)
- Changing the format files themselves

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Increased prompt token usage | L | L | Format files are 59-169 lines (~400-1200 tokens), negligible vs agent context |
| Duplicate format content if agent also reads the file | L | M | Harmless reinforcement; agents may skip their own Read when content is provided |
| Stage numbering disruption in skill files | M | L | Insert as Stage 4b between existing Stage 4 and Stage 5; no renumbering needed |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Update skill-planner [NOT STARTED]

**Goal**: Add format file injection to skill-planner's delegation flow.

**Tasks**:
- [ ] Insert Stage 4b after Stage 4 in `.claude/skills/skill-planner/SKILL.md` that reads `.claude/context/formats/plan-format.md` and includes it in the prompt
- [ ] Update Stage 5 prompt instructions to include the format specification as a delimited section
- [ ] Verify the stage numbering and cross-references remain consistent

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-planner/SKILL.md` - Add Stage 4b (Read plan-format.md), update Stage 5 prompt to include format section

**Verification**:
- Stage 4b exists between Stage 4 and Stage 5
- Stage 5 prompt parameter includes a `## CRITICAL: Plan Format Requirements` section (or similar) with XML-delimited format content
- Existing Stage 4 and Stage 5 content is preserved

---

### Phase 2: Update skill-researcher [NOT STARTED]

**Goal**: Add format file injection to skill-researcher's delegation flow.

**Tasks**:
- [ ] Insert Stage 4b after Stage 4 in `.claude/skills/skill-researcher/SKILL.md` that reads `.claude/context/formats/report-format.md` and includes it in the prompt
- [ ] Update Stage 5 prompt instructions to include the format specification as a delimited section
- [ ] Verify the stage numbering and cross-references remain consistent

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md` - Add Stage 4b (Read report-format.md), update Stage 5 prompt to include format section

**Verification**:
- Stage 4b exists between Stage 4 and Stage 5
- Stage 5 prompt parameter includes format content for report-format.md
- Existing Stage 4 and Stage 5 content is preserved

---

### Phase 3: Update skill-implementer [NOT STARTED]

**Goal**: Add format file injection to skill-implementer's delegation flow.

**Tasks**:
- [ ] Insert Stage 4b after Stage 4 in `.claude/skills/skill-implementer/SKILL.md` that reads `.claude/context/formats/summary-format.md` and includes it in the prompt
- [ ] Update Stage 5 prompt instructions to include the format specification as a delimited section
- [ ] Verify the stage numbering and cross-references remain consistent

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-implementer/SKILL.md` - Add Stage 4b (Read summary-format.md), update Stage 5 prompt to include format section

**Verification**:
- Stage 4b exists between Stage 4 and Stage 5
- Stage 5 prompt parameter includes format content for summary-format.md
- Existing Stage 4 and Stage 5 content is preserved

## Testing & Validation

- [ ] Each of the three skill files contains a Stage 4b with a Read instruction for the correct format file
- [ ] Each Stage 5 prompt section includes a format specification block with XML delimiters
- [ ] No existing stage content was lost or corrupted
- [ ] Stage numbering is consistent (4 -> 4b -> 5) across all three files
- [ ] The format file paths referenced in Stage 4b match the actual file locations

## Artifacts & Outputs

- `.claude/skills/skill-planner/SKILL.md` - Updated with Stage 4b (plan-format.md injection)
- `.claude/skills/skill-researcher/SKILL.md` - Updated with Stage 4b (report-format.md injection)
- `.claude/skills/skill-implementer/SKILL.md` - Updated with Stage 4b (summary-format.md injection)
- `specs/370_inject_format_specs_delegation_prompts/summaries/01_format-injection-summary.md` - Execution summary

## Rollback/Contingency

All changes are to markdown skill definition files tracked in git. Revert with `git checkout HEAD -- .claude/skills/skill-planner/SKILL.md .claude/skills/skill-researcher/SKILL.md .claude/skills/skill-implementer/SKILL.md` to restore the pre-change state.
