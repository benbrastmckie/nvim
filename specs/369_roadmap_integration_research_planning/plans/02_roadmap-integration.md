# Implementation Plan: Task #369

- **Task**: 369 - Integrate ROAD_MAP.md consultation into research and planning agents
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**:
  - specs/369_roadmap_integration_research_planning/reports/01_roadmap-integration-gaps.md
  - specs/369_roadmap_integration_research_planning/reports/02_team-research-roles.md
- **Artifacts**: plans/02_roadmap-integration.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add ROAD_MAP.md awareness across the research and planning pipeline. Single-agent research and planning agents gain a roadmap consultation stage. Team research (`--team`) gets restructured with mandatory Critic and Horizons teammate roles. Context index and delegation contexts are updated to make roadmap documentation available to all relevant agents.

### Research Integration

Report 01 identified that `general-research-agent.md` and `planner-agent.md` have zero ROAD_MAP.md references, and `context/index.json` scopes roadmap files exclusively to `/todo`. Report 02 analyzed the team research skill and recommends replacing the conditional C/D teammates (Risk Analysis, Devil's Advocate) with mandatory Critic and Horizons roles, fixing team_size at 4 for research.

## Goals & Non-Goals

**Goals**:
- Research agent reads ROAD_MAP.md for strategic context before beginning research
- Planner agent reads ROAD_MAP.md to align plan phases with roadmap priorities
- Context index makes roadmap docs available to research/planning agents
- Delegation contexts include roadmap path so agents don't hardcode it
- Team research always includes a Critic (gaps/shortcomings) and Horizons (long-term roadmap alignment) teammate

**Non-Goals**:
- Agents do not write/modify ROAD_MAP.md (that stays with /todo and /review)
- No changes to /todo, /review, or /implement workflows
- No changes to team-plan or team-implement skills
- No new context files -- only modifications to existing ones

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| ROAD_MAP.md doesn't exist in some projects | L | M | Guard with existence check, skip gracefully |
| Extra context bloats agent prompts | L | L | Agents extract only relevant sections, roadmap is compact |
| Agents accidentally modify ROAD_MAP.md | M | L | Explicit read-only instruction in stage text |
| 4 mandatory teammates increases cost | M | L | `--team` is already opt-in; user accepts cost by using it |
| Critic may overlap with Risk Analysis | L | M | Clear prompt differentiation: research quality vs implementation risks |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Update context/index.json and delegation contexts [NOT STARTED]

**Goal**: Make roadmap context files discoverable by research/planning agents and pass roadmap path in delegation contexts.

**Tasks**:
- [ ] Edit `context/index.json`: expand `formats/roadmap-format.md` `load_when` to add agents `["general-research-agent", "planner-agent"]` and commands `["/todo", "/research", "/plan"]`
- [ ] Edit `context/index.json`: expand `patterns/roadmap-update.md` `load_when` to add agents `["planner-agent"]` and commands `["/todo", "/plan"]`
- [ ] Edit `skill-researcher/SKILL.md` Stage 4 delegation context: add `"roadmap_path": "specs/ROAD_MAP.md"` field to the JSON block
- [ ] Edit `skill-planner/SKILL.md` Stage 4 delegation context: add `"roadmap_path": "specs/ROAD_MAP.md"` field to the JSON block
- [ ] Edit `skill-team-research/SKILL.md` Stage 5 delegation context: add `"roadmap_path": "specs/ROAD_MAP.md"` field to teammate delegation

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/context/index.json` - Expand `load_when` for two roadmap entries
- `.claude/skills/skill-researcher/SKILL.md` - Add roadmap_path to delegation context (Stage 4)
- `.claude/skills/skill-planner/SKILL.md` - Add roadmap_path to delegation context (Stage 4)
- `.claude/skills/skill-team-research/SKILL.md` - Add roadmap_path to teammate context (Stage 5)

**Verification**:
- jq query for `general-research-agent` returns `formats/roadmap-format.md`
- jq query for `planner-agent` returns both roadmap context files
- Delegation context JSON blocks in all three skills include `roadmap_path` field

---

### Phase 2: Add roadmap consultation stage to general-research-agent.md [NOT STARTED]

**Goal**: Research agent reads ROAD_MAP.md for strategic context before executing searches.

**Tasks**:
- [ ] Add new "Stage 1.5: Load Roadmap Context" between Stage 1 (Parse Delegation Context) and Stage 2 (Analyze Task)
- [ ] Stage reads `roadmap_path` from delegation context, checks file exists, extracts current phase priorities and items relevant to the task
- [ ] Add explicit read-only instruction: agent must never modify ROAD_MAP.md
- [ ] Update Stage 2 (Analyze Task) to reference roadmap context when determining search strategy
- [ ] Add `@.claude/context/formats/roadmap-format.md` to Context References section

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/agents/general-research-agent.md` - Add Stage 1.5, update Stage 2 and Context References

**Verification**:
- Agent file contains Stage 1.5 with roadmap reading logic
- Context References includes roadmap-format.md
- Read-only guard is explicitly stated

---

### Phase 3: Add roadmap alignment stage to planner-agent.md [NOT STARTED]

**Goal**: Planner agent reads ROAD_MAP.md to align plan phases with roadmap priorities and suggest roadmap_items.

**Tasks**:
- [ ] Add new "Stage 2.5: Load Roadmap Context" between Stage 2 (Load Research) and Stage 3 (Analyze Task Scope)
- [ ] Stage reads `roadmap_path` from delegation context, checks file exists, identifies which roadmap items the task advances
- [ ] Add explicit read-only instruction: agent must never modify ROAD_MAP.md
- [ ] Update Stage 4 (Decompose into Phases) to consider roadmap ordering when sequencing phases
- [ ] Update Stage 5 plan template to include a "Roadmap Alignment" subsection in Overview noting which roadmap items this plan advances
- [ ] Add `@.claude/context/formats/roadmap-format.md` to Context References section

**Timing**: 25 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/agents/planner-agent.md` - Add Stage 2.5, update Stages 4-5 and Context References

**Verification**:
- Agent file contains Stage 2.5 with roadmap reading logic
- Plan template includes Roadmap Alignment subsection
- Context References includes roadmap-format.md
- Read-only guard is explicitly stated

---

### Phase 4: Restructure team research teammate roles [NOT STARTED]

**Goal**: Replace conditional C/D teammates with mandatory Critic and Horizons roles so `--team` research always includes gap analysis and long-term roadmap alignment.

**Tasks**:
- [ ] Edit `skill-team-research/SKILL.md` Stage 1: change team_size clamp from `[2, 4]` to fixed `4`, change default from `2` to `4`
- [ ] Edit Stage 5 Teammate C prompt: replace "Risk Analysis" with "Critic" role -- focus on identifying gaps, shortcomings, unvalidated assumptions, and blind spots in the research. Runs in Wave 1 (no dependency on other teammates). Remove the `if team_size >= 3` guard so it always runs
- [ ] Edit Stage 5 Teammate D prompt: replace "Devil's Advocate" with "Horizons" role -- reads `specs/ROAD_MAP.md` (via `roadmap_path` from delegation context), assesses whether the task approach aligns with long-term project goals, identifies opportunities to advance adjacent roadmap items, thinks outside the box about improving the approach. Remove the `if team_size >= 4` guard and the "wait for other teammates" instruction so it runs in Wave 1
- [ ] Add existence guard for ROAD_MAP.md in Horizons prompt: if file doesn't exist, contribute general strategic thinking about project direction instead
- [ ] Update Stage 9 (Create Unified Report) template: rename "Risks and Blockers" section to "Gaps and Shortcomings (Critic)" and add "Strategic Horizons" section for Horizons findings
- [ ] Update `team-orchestration.md` wave diagram: change labels to show 4 fixed research roles (Primary, Alternatives, Critic, Horizons)

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-team-research/SKILL.md` - Restructure teammate roles C/D, fix team_size, update report template
- `.claude/context/patterns/team-orchestration.md` - Update wave diagram labels

**Verification**:
- Teammate C prompt contains "Critic" role description focused on gaps/shortcomings
- Teammate D prompt contains "Horizons" role with ROAD_MAP.md reading instruction
- Both C and D have no conditional guards (always spawn)
- team_size is fixed at 4 with no user override for research
- Horizons prompt includes ROAD_MAP.md existence guard
- Synthesis report template has Critic and Horizons sections

## Testing & Validation

- [ ] jq query `index.json` for `general-research-agent` returns roadmap format file
- [ ] jq query `index.json` for `planner-agent` returns both roadmap files
- [ ] `general-research-agent.md` contains Stage 1.5 with existence guard
- [ ] `planner-agent.md` contains Stage 2.5 with existence guard
- [ ] Both agent files have read-only ROAD_MAP.md instruction
- [ ] Delegation contexts in all three skills include `roadmap_path`
- [ ] `skill-team-research/SKILL.md` has 4 mandatory teammate roles
- [ ] Teammate C is "Critic", Teammate D is "Horizons" with roadmap reading
- [ ] No agent file contains instructions to write/modify ROAD_MAP.md
- [ ] `team-orchestration.md` diagram reflects new role names

## Artifacts & Outputs

- Modified: `.claude/context/index.json`
- Modified: `.claude/agents/general-research-agent.md`
- Modified: `.claude/agents/planner-agent.md`
- Modified: `.claude/skills/skill-researcher/SKILL.md`
- Modified: `.claude/skills/skill-planner/SKILL.md`
- Modified: `.claude/skills/skill-team-research/SKILL.md`
- Modified: `.claude/context/patterns/team-orchestration.md`

## Rollback/Contingency

All changes are to markdown instruction files with no runtime dependencies. Revert via `git checkout` on the 7 modified files.
