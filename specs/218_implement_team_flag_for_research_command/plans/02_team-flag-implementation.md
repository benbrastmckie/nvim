# Implementation Plan: Task #218

- **Task**: 218 - implement_team_flag_for_research_command
- **Status**: [NOT STARTED]
- **Effort**: 12-16 hours
- **Dependencies**: None
- **Research Inputs**: [01_team-flag-research.md](../reports/01_team-flag-research.md)
- **Artifacts**: plans/02_team-flag-implementation.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Implement the `--team` flag for `/research`, `/plan`, and `/implement` commands to enable parallel multi-agent research using the experimental Claude Code agent teams feature. The implementation adds flag parsing stages to existing commands, creates three new team skills (team-research, team-plan, team-implement), and supporting infrastructure for wave-based parallel execution with synthesis.

### Research Integration

The research report identified:
- ProofChecker has a complete reference implementation
- Current nvim commands lack any flag parsing
- Experimental feature requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
- Graceful degradation to single-agent is mandatory
- Team mode uses ~5x token cost (default team_size=2 minimizes cost)

## Goals & Non-Goals

**Goals**:
- Add `--team` and `--team-size N` flags to `/research`, `/plan`, `/implement` commands
- Create team skills that orchestrate parallel teammates with synthesis
- Implement graceful degradation when experimental feature unavailable
- Support wave-based execution with optional Wave 2 for gap filling
- Integrate with existing language-based routing

**Non-Goals**:
- Successor teammate pattern (follow-up task for context exhaustion)
- Extension language support for team mode (extensions handle their own team logic)
- Advanced conflict resolution algorithms (start with simple synthesis)
- Wave 2 automation (manual trigger only in v1)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Experimental feature instability | H | M | Mandatory graceful degradation to single-agent |
| Token cost increase (~5x) | M | H | Default team_size=2, document cost implications |
| Synthesis quality | M | M | Start with Wave 1 only, simple synthesis logic |
| Command complexity increase | L | M | Clean flag parsing pattern, reusable helpers |

## Implementation Phases

### Phase 1: Flag Parsing Infrastructure [COMPLETED]

**Goal**: Add STAGE 1.5: PARSE FLAGS to all three commands with shared patterns

**Tasks**:
- [ ] Add Options section to research.md documenting `--team` and `--team-size N` flags
- [ ] Add STAGE 1.5: PARSE FLAGS between CHECKPOINT 1 and STAGE 2 in research.md
- [ ] Extract flags from remaining args, clean focus_prompt
- [ ] Add team routing override logic (when --team, route to skill-team-research)
- [ ] Add Options section and STAGE 1.5 to plan.md
- [ ] Add team routing override to plan.md (when --team, route to skill-team-plan)
- [ ] Add Options section and STAGE 1.5 to implement.md
- [ ] Add team routing override to implement.md (when --team, route to skill-team-implement)

**Timing**: 2-3 hours

**Files to modify**:
- `.claude/commands/research.md` - Add options, flag parsing, team routing
- `.claude/commands/plan.md` - Add options, flag parsing, team routing
- `.claude/commands/implement.md` - Add options, flag parsing, team routing

**Verification**:
- Commands accept --team and --team-size flags
- Flags are extracted from args (not passed as focus text)
- Without --team, commands behave identically to current

---

### Phase 2: Team Research Skill [COMPLETED]

**Goal**: Create skill-team-research to orchestrate parallel research teammates

**Tasks**:
- [ ] Create `.claude/skills/skill-team-research/` directory
- [ ] Create SKILL.md with teammate prompts for angles A-D
- [ ] Implement graceful degradation check for CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS
- [ ] Add language-aware routing (meta vs general prompts differ)
- [ ] Implement Wave 1 parallel execution pattern
- [ ] Implement synthesis logic to combine teammate findings
- [ ] Add run-scoped artifact naming (e.g., research-001-teammate-a-findings.md)
- [ ] Handle teammate failures and partial results
- [ ] Return unified research report with team metadata

**Timing**: 3-4 hours

**Files to create**:
- `.claude/skills/skill-team-research/SKILL.md` - Team research orchestration (~400 lines)

**Verification**:
- `--team` flag invokes skill-team-research
- Graceful degradation works (falls back to skill-researcher)
- Multiple teammates produce findings
- Synthesis creates unified report

---

### Phase 3: Team Plan Skill [NOT STARTED]

**Goal**: Create skill-team-plan for parallel plan generation with trade-off analysis

**Tasks**:
- [ ] Create `.claude/skills/skill-team-plan/` directory
- [ ] Create SKILL.md with planning teammate prompts (A: incremental, B: alternative)
- [ ] Implement graceful degradation to skill-planner
- [ ] Add optional risk analyst teammate (size >= 3)
- [ ] Implement synthesis with trade-off comparison
- [ ] Generate unified plan with alternatives documented
- [ ] Add plan metadata for team execution tracking

**Timing**: 2-3 hours

**Files to create**:
- `.claude/skills/skill-team-plan/SKILL.md` - Team planning orchestration (~350 lines)

**Verification**:
- `--team` flag invokes skill-team-plan
- Multiple plan versions generated
- Synthesis compares approaches
- Final plan includes trade-off analysis

---

### Phase 4: Team Implement Skill [NOT STARTED]

**Goal**: Create skill-team-implement for parallel phase execution

**Tasks**:
- [ ] Create `.claude/skills/skill-team-implement/` directory
- [ ] Create SKILL.md for parallel independent phase execution
- [ ] Implement phase dependency analysis (identify parallel-safe phases)
- [ ] Add debugger teammate pattern (spawned on error)
- [ ] Implement graceful degradation to skill-implementer
- [ ] Handle per-phase commits from parallel teammates
- [ ] Coordinate phase completion ordering
- [ ] Add implementation metadata for team tracking

**Timing**: 3-4 hours

**Files to create**:
- `.claude/skills/skill-team-implement/SKILL.md` - Team implementation orchestration (~450 lines)

**Verification**:
- `--team` flag invokes skill-team-implement
- Independent phases execute in parallel
- Dependent phases wait appropriately
- Debugger spawns on build errors

---

### Phase 5: Supporting Infrastructure [NOT STARTED]

**Goal**: Create reusable helpers and documentation

**Tasks**:
- [ ] Create `.claude/utils/team-wave-helpers.md` with reusable wave patterns
- [ ] Create `.claude/context/core/patterns/team-orchestration.md` documenting coordination
- [ ] Create `.claude/context/core/formats/team-metadata-extension.md` schema
- [ ] Update CLAUDE.md Skill-to-Agent Mapping with team skills
- [ ] Document CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS requirement
- [ ] Add team skills to index.json for context discovery
- [ ] Create test scenarios for team mode validation

**Timing**: 2-3 hours

**Files to create**:
- `.claude/utils/team-wave-helpers.md` - Reusable wave execution patterns (~200 lines)
- `.claude/context/core/patterns/team-orchestration.md` - Coordination documentation (~150 lines)
- `.claude/context/core/formats/team-metadata-extension.md` - Metadata schema (~80 lines)

**Files to modify**:
- `.claude/CLAUDE.md` - Add team skills to mapping table
- `.claude/context/index.json` - Add team context entries

**Verification**:
- Utils are importable by team skills
- Documentation is clear and complete
- index.json entries enable context discovery
- CLAUDE.md reflects new capabilities

---

### Phase 6: Integration Testing [NOT STARTED]

**Goal**: Validate end-to-end team mode functionality

**Tasks**:
- [ ] Test research.md with --team flag (with env var set)
- [ ] Test research.md with --team flag (graceful degradation, no env var)
- [ ] Test plan.md with --team flag
- [ ] Test implement.md with --team flag on independent phases
- [ ] Test --team-size N parsing (clamp 2-4)
- [ ] Verify teammate artifacts are created
- [ ] Verify synthesis reports are complete
- [ ] Test error recovery (teammate failure)
- [ ] Verify metadata extension fields populated
- [ ] Document any discovered edge cases

**Timing**: 2-3 hours

**Verification**:
- All commands work with --team flag
- Graceful degradation functional
- Artifacts correctly named and placed
- Metadata includes team execution data

## Testing & Validation

- [ ] `/research 218 --team` produces multi-teammate research
- [ ] `/research 218 --team` without env var falls back gracefully
- [ ] `/plan 218 --team` produces plan with alternatives
- [ ] `/implement 218 --team` parallelizes independent phases
- [ ] `--team-size 3` spawns 3 teammates
- [ ] `--team-size 5` clamps to 4 teammates
- [ ] Synthesis detects and resolves conflicts
- [ ] Team metadata appears in return-meta.json

## Artifacts & Outputs

- `.claude/commands/research.md` (modified)
- `.claude/commands/plan.md` (modified)
- `.claude/commands/implement.md` (modified)
- `.claude/skills/skill-team-research/SKILL.md` (new)
- `.claude/skills/skill-team-plan/SKILL.md` (new)
- `.claude/skills/skill-team-implement/SKILL.md` (new)
- `.claude/utils/team-wave-helpers.md` (new)
- `.claude/context/core/patterns/team-orchestration.md` (new)
- `.claude/context/core/formats/team-metadata-extension.md` (new)
- `.claude/CLAUDE.md` (modified)
- `.claude/context/index.json` (modified)
- `specs/218_implement_team_flag_for_research_command/summaries/03_team-flag-summary.md` (generated)

## Rollback/Contingency

If team mode causes issues:
1. Commands still work without --team flag (existing paths unchanged)
2. Remove team routing overrides from STAGE 2 in commands
3. Team skills can be deleted without affecting core functionality
4. Graceful degradation ensures single-agent always available

If experimental feature is removed from Claude Code:
1. Graceful degradation already handles this
2. Document deprecation in CLAUDE.md
3. Remove team flag documentation from commands
