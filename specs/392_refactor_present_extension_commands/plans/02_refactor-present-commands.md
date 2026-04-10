# Implementation Plan: Refactor Present Extension Commands

- **Task**: 392 - Refactor present extension commands (/grant, /budget, /funds, /timeline, /talk)
- **Status**: [NOT STARTED]
- **Effort**: 4.5 hours
- **Dependencies**: 391 (completed - manifest integration)
- **Research Inputs**: reports/01_refactor-present-commands.md, reports/02_team-research.md
- **Artifacts**: plans/02_refactor-present-commands.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The present extension's 5 commands were built across 4 task creation waves, accumulating inconsistencies in language fields, model specifications, and structural patterns. Three commands (/grant, /budget, /timeline) create tasks with wrong language values, breaking manifest routing. This plan standardizes all mechanical fields, fixes routing and context index entries, adds pre-task intake to /grant, restructures /timeline questions to Stage 0, adds a --design flag to /talk, and aligns skill patterns with core conventions. Definition of done: all 5 commands create tasks with `language: "present"` and correct `task_type`, all context entries load correctly, and all three structural enhancements are in place.

### Research Integration

Two research rounds were integrated:
- **Round 1** (01_refactor-present-commands.md): Identified language and model inconsistencies across 9 files with ~25-30 changes.
- **Round 2** (02_team-research.md, 4 teammates): Expanded scope to 16-19 files and 45-55 changes. Teammate C identified agent file gaps, 17 index-entries.json entries needing language updates, and manifest implement routing dead code. Teammate A provided per-command flow analysis with improvement options. Team consensus on /grant pre-task intake (4 questions), /timeline Stage 0 restructure, and /talk --design flag (post-research confirmation).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROAD_MAP.md found (file does not exist at specs/ROAD_MAP.md).

## Goals & Non-Goals

**Goals**:
- Unify all 5 commands to use `language: "present"` with `task_type` for subtype differentiation
- Standardize model to `opus` across all commands, skills, and agents
- Update 17 grant-domain index-entries.json entries from `"languages": ["grant"]` to `"languages": ["present"]`
- Fix manifest.json implement routing (remove bare `"grant"` key)
- Add Stage 0 pre-task forcing questions to /grant (4 questions)
- Move /timeline forcing questions from research stage to pre-task Stage 0
- Add --design flag to /talk for post-research design confirmation
- Update skill validation and trigger conditions to match new language values

**Non-Goals**:
- Updating the present context README.md to cover all 5 capabilities (future task)
- Cross-command linking (grant-to-talk pipeline)
- Shared forcing-question framework extraction
- Expanding /budget forcing questions to reduce agent overlap
- Adding file path input support to /funds

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| 17 index-entries.json changes break grant context loading | H | M | Update all entries atomically in same phase; verify with jq query post-edit |
| Grant-agent dynamic context query returns zero results after index update | H | H | Update query in same phase as index entries; change from `languages == "grant"` to agent-based filter |
| Skills reject tasks after language change if updated non-atomically | H | L | Update commands and skills in same phase |
| Existing tasks with `language: "grant"` in state.json break | M | L | State.json shows zero active present-related tasks; no migration risk |
| Talk agent MUST NOT use AskUserQuestion, blocking design confirmation in agent | H | L | Design confirmation handled by command-level --design flag, not agent |
| Scope of 16-19 files increases implementation error risk | M | M | Phase the work: mechanical fixes first (Phase 1), enhancements later |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4, 5 | 2 |
| 4 | 6 | 1, 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Mechanical Standardization [NOT STARTED]

**Goal**: Fix language, task_type, and model across all commands, skills, and agents.

**Tasks**:
- [ ] Update grant.md: change `language: "grant"` to `language: "present"`, add `task_type: "grant"`, change `model: claude-opus-4-5-20251101` to `model: opus`
- [ ] Update budget.md: change `language: "budget"` to `language: "present"`, add `model: opus` to frontmatter
- [ ] Update timeline.md: change `language: "timeline"` to `language: "present"`, add `task_type: "timeline"`, change model to `opus`
- [ ] Update funds.md: change `model: claude-opus-4-5-20251101` to `model: opus` (language and task_type already correct)
- [ ] Update talk.md: change `model: claude-opus-4-5-20251101` to `model: opus`
- [ ] Update skill-grant/SKILL.md: change all `language="grant"` references to `language="present"`, update validation to check `language == "present"`, update trigger conditions, update fix-it task creation to use `language: "present"` with `task_type: "grant"`
- [ ] Update skill-budget/SKILL.md: change `language "budget"` references to `language "present"`, update delegation context example
- [ ] Update skill-timeline/SKILL.md: change all `language="timeline"` references to `language="present"`, update validation and trigger conditions
- [ ] Update grant-agent.md: change delegation context example `"language": "grant"` to `"language": "present"`, add `"task_type": "grant"`, update dynamic context discovery query from `languages == "grant"` to `languages == "present" and agents == "grant-agent"`
- [ ] Update budget-agent.md: change delegation context example `"language": "budget"` to `"language": "present"`, add `"task_type": "budget"` if missing, add `model: opus` to frontmatter
- [ ] Update timeline-agent.md: change delegation context example `"language": "timeline"` to `"language": "present"`, add `"task_type": "timeline"`

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/extensions/present/commands/grant.md` - language, task_type, model
- `.claude/extensions/present/commands/budget.md` - language, model
- `.claude/extensions/present/commands/timeline.md` - language, task_type, model
- `.claude/extensions/present/commands/funds.md` - model
- `.claude/extensions/present/commands/talk.md` - model
- `.claude/extensions/present/skills/skill-grant/SKILL.md` - validation, fix-it tasks
- `.claude/extensions/present/skills/skill-budget/SKILL.md` - validation
- `.claude/extensions/present/skills/skill-timeline/SKILL.md` - validation
- `.claude/extensions/present/agents/grant-agent.md` - delegation context, dynamic query
- `.claude/extensions/present/agents/budget-agent.md` - delegation context, model frontmatter
- `.claude/extensions/present/agents/timeline-agent.md` - delegation context

**Verification**:
- All 5 commands reference `language: "present"` and include `task_type`
- All skills validate `language == "present"`
- All agents show correct delegation context examples
- All model specifications are `opus`

---

### Phase 2: Index and Manifest Routing Fixes [NOT STARTED]

**Goal**: Update 17 grant-domain index entries and fix manifest implement routing so context discovery and command routing work correctly with the new `language: "present"` values.

**Tasks**:
- [ ] Update all 17 grant-domain entries in index-entries.json from `"languages": ["grant"]` to `"languages": ["present"]`
- [ ] Verify no other entries reference `"grant"` as a language value
- [ ] Fix manifest.json implement routing: remove bare `"grant": "skill-grant:assemble"` key (dead code after Phase 1)
- [ ] Update EXTENSION.md language routing table: change grant row from `grant | - |` to `present | grant |`
- [ ] Verify jq query `jq 'map(select(.load_when.languages[]? == "present")) | length'` returns expected count (all present entries including former grant entries)

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/present/index-entries.json` - 17 language field updates
- `.claude/extensions/present/manifest.json` - remove bare `"grant"` implement routing key
- `.claude/extensions/present/EXTENSION.md` - routing table update

**Verification**:
- `jq 'map(select(.load_when.languages[]? == "grant")) | length'` returns 0
- `jq 'map(select(.load_when.languages[]? == "present")) | length'` returns count including former grant entries
- Manifest implement routing has no bare `"grant"` key
- EXTENSION.md routing table shows all rows with `present` language

---

### Phase 3: Grant Pre-Task Intake [NOT STARTED]

**Goal**: Add Stage 0 forcing questions to /grant command so it gathers grant mechanism, existing content paths, regulatory materials, and constraints before creating the task.

**Tasks**:
- [ ] Add Stage 0 section to grant.md with 4 AskUserQuestion calls:
  - Q1: Grant mechanism and funder (e.g., NIH R01, NSF CAREER, foundation)
  - Q2: Existing content paths (file paths, task references, or "none")
  - Q3: Regulatory and compliance materials (PA/FOA URL, institutional guidelines, IRB/IACUC protocols)
  - Q4: Grant constraints (page limits, required sections, due date, budget ceiling)
- [ ] Store responses as `forcing_data` object in task metadata during task creation
- [ ] Add `AskUserQuestion` to grant.md frontmatter allowed-tools (currently missing)
- [ ] Update skill-grant to pass `forcing_data` to grant-agent via delegation context
- [ ] Update grant-agent to check for pre-gathered `forcing_data` and skip redundant questions

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/present/commands/grant.md` - add Stage 0 questions, store forcing_data
- `.claude/extensions/present/skills/skill-grant/SKILL.md` - pass forcing_data in delegation context
- `.claude/extensions/present/agents/grant-agent.md` - use pre-gathered forcing_data

**Verification**:
- Grant command asks 4 forcing questions before creating task
- Task metadata includes `forcing_data` with mechanism, content_paths, regulatory_materials, constraints
- Skill passes forcing_data to agent
- Agent detects pre-gathered data and skips redundant questions

---

### Phase 4: Timeline Structural Alignment [NOT STARTED]

**Goal**: Move /timeline forcing questions from the research stage to pre-task Stage 0, extend to 5-6 questions, and wire skip logic in the agent.

**Tasks**:
- [ ] Move 3 existing forcing questions from timeline.md research mode to a new Stage 0 section before task creation
- [ ] Extend forcing questions from 3 to 5-6:
  - Q1: Grant mechanism (existing, with options: R01/R21/K-series/U01/Other)
  - Q2: Project period with start/end dates (existing, refined)
  - Q3: Number of specific aims (new)
  - Q4: Key completion criteria / milestone targets (new)
  - Q5: Regulatory requirements expected (new, multiSelect: IRB/IACUC/FDA/None)
  - Q6: Existing aims document path (new, path or "none")
- [ ] Store as `forcing_data` in task metadata during task creation
- [ ] Add `AskUserQuestion` to timeline.md frontmatter allowed-tools if not present
- [ ] Update skill-timeline to pass `forcing_data` to timeline-agent via delegation context
- [ ] Update timeline-agent to check for pre-gathered `forcing_data` and skip Q1-Q5 equivalents (mechanism, period, aims)

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/present/commands/timeline.md` - move questions to Stage 0, extend set
- `.claude/extensions/present/skills/skill-timeline/SKILL.md` - pass forcing_data
- `.claude/extensions/present/agents/timeline-agent.md` - skip pre-gathered questions

**Verification**:
- Timeline command asks 5-6 forcing questions before creating task
- Task metadata includes `forcing_data` with mechanism, period, aims_count, milestones, regulatory, aims_path
- Agent skips questions that were pre-gathered (no double-asking)

---

### Phase 5: Talk Design Confirmation [NOT STARTED]

**Goal**: Add --design flag to /talk command for post-research design confirmation, allowing the user to choose themes, content ordering, and emphasis before planning begins.

**Tasks**:
- [ ] Add `--design` mode to talk.md mode detection and mode table
- [ ] Implement design confirmation flow: read research report, present via AskUserQuestion:
  - Theme choices (3-4 visual descriptions)
  - Key message ordering (confirm or reorder the 3 key messages from research)
  - Slide count and section emphasis (which sections to expand vs compress)
- [ ] Store user choices as `design_decisions` in task metadata (via state.json update)
- [ ] Update skill-talk to recognize --design workflow type and handle design_decisions storage
- [ ] Update /plan flow awareness: when planning a talk task, check for and use `design_decisions` from metadata

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/present/commands/talk.md` - add --design flag, design confirmation flow
- `.claude/extensions/present/skills/skill-talk/SKILL.md` - add design workflow type
- `.claude/extensions/present/agents/talk-agent.md` - no changes needed (design happens at command level per MUST NOT use AskUserQuestion constraint)

**Verification**:
- `/talk N --design` reads research report and presents theme/order/emphasis choices
- User selections stored as `design_decisions` in task metadata
- `/plan N` for talk tasks uses `design_decisions` when available

---

### Phase 6: Validation and Cleanup [NOT STARTED]

**Goal**: Verify all changes work together and clean up any remaining inconsistencies.

**Tasks**:
- [ ] Run jq validation queries to confirm:
  - Zero entries with `"languages": ["grant"]` in index-entries.json
  - All present entries load correctly with `"languages": ["present"]` query
  - Grant-agent dynamic context query returns grant-specific entries
- [ ] Verify manifest routing table is complete and has no dead keys
- [ ] Spot-check each command file for any remaining references to old language values
- [ ] Verify EXTENSION.md routing table matches manifest.json routing
- [ ] Confirm all 5 skills have consistent trigger conditions referencing `language: "present"`

**Timing**: 0.5 hours

**Depends on**: 1, 2, 3, 4, 5

**Files to modify**:
- Any files with remaining inconsistencies found during validation

**Verification**:
- All jq validation queries pass
- No remaining references to `language: "grant"`, `language: "budget"`, or `language: "timeline"` in any present extension file (except in documentation describing the migration)
- EXTENSION.md and manifest.json are consistent

## Testing & Validation

- [ ] jq query: `map(select(.load_when.languages[]? == "grant")) | length` returns 0 on index-entries.json
- [ ] jq query: `map(select(.load_when.languages[]? == "present")) | length` returns full count on index-entries.json
- [ ] Grep: no present extension file contains `"language": "grant"` or `"language": "budget"` or `"language": "timeline"` in task creation or validation code
- [ ] Grep: no model field uses `claude-opus-4-5-20251101` in present extension
- [ ] Verify grant.md frontmatter includes `AskUserQuestion` in allowed-tools
- [ ] Verify manifest.json has no bare `"grant"` key in implement routing

## Artifacts & Outputs

- `specs/392_refactor_present_extension_commands/plans/02_refactor-present-commands.md` (this file)
- 13-16 modified files across commands/, skills/, agents/, and extension metadata
- `specs/392_refactor_present_extension_commands/summaries/02_refactor-present-commands-summary.md` (post-implementation)

## Rollback/Contingency

All changes are to markdown and JSON files under version control. If the refactor causes issues:
1. `git revert` the implementation commits to restore the pre-refactor state
2. No database migrations or external system changes involved
3. State.json has zero active present-related tasks, so no in-flight work will be affected
4. Individual phases can be reverted independently since each phase is committed separately
