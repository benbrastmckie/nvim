# Implementation Plan: Create /talk Command for Present Extension

- **Task**: 390 - Create /talk command for present extension
- **Status**: [COMPLETED]
- **Effort**: 5 hours
- **Dependencies**: None (sibling tasks 387-389 are independent)
- **Research Inputs**: specs/390_create_talk_command_present/reports/01_talk-command-research.md
- **Artifacts**: plans/01_talk-command-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Create the /talk command within the present extension, adapting the founder /deck command architecture for academic research presentations. The implementation creates a command file, skill, agent, and context library (patterns, content templates, components, themes) for generating Slidev-based research talks in five modes: CONFERENCE, SEMINAR, DEFENSE, POSTER, and JOURNAL_CLUB. The command follows the same pre-task forcing questions pattern as /deck, gathering talk type, source materials, and audience context before task creation.

### Research Integration

Key findings from the research report:
- The founder /deck architecture (command -> skill -> agent with forcing questions) is the proven pattern to adapt
- Five talk modes map to academic presentation types, with CONFERENCE as the primary use case
- Research presentations need fundamentally different content templates (methods, results, discussion) vs. pitch decks
- New Vue components needed: FigurePanel, DataTable, CitationBlock, StatResult, FlowDiagram
- Most founder deck themes can be reused; only 2 academic-specific themes needed
- Single talk-agent for research (simpler than founder's dual agent approach)

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROAD_MAP.md found.

## Goals & Non-Goals

**Goals**:
- Create `/talk` command with pre-task forcing questions for talk type, source materials, and audience context
- Create `skill-talk` as a thin wrapper skill routing to `talk-agent` for research
- Create `talk-agent` for material synthesis into slide-mapped research reports
- Create talk library context with patterns, content templates, components, and themes
- Support all five talk modes (CONFERENCE, SEMINAR, DEFENSE, POSTER, JOURNAL_CLUB)
- Follow the exact same architectural patterns as the founder /deck command

**Non-Goals**:
- Implementing Slidev rendering or build tooling (handled by existing Slidev infrastructure)
- Creating present-specific plan/implement agents (standard planner/implementer suffice)
- Duplicating founder deck themes (reference existing themes, only add academic-specific ones)
- Building a poster layout engine (POSTER mode gets a minimal pattern definition)
- Creating index-entries.json or manifest updates (covered by task 391)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Scope creep from 5 mode patterns | H | M | Phase 2 creates CONFERENCE pattern first; other patterns in Phase 3 as P1/P2 priority |
| Content template volume (17+ templates) | M | M | Group by slide category; use consistent structure across templates |
| Component complexity (Vue files) | M | M | Create component specifications (props/purpose), not full Vue implementations |
| Inconsistency with /deck command structure | H | L | Directly reference and follow /deck command file structure during implementation |
| talk-agent scope ambiguity | M | L | Clearly scope agent to research/synthesis only; planning and implementation use standard agents |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Command File and Core Architecture [COMPLETED]

**Goal**: Create the /talk command file with pre-task forcing questions and task creation logic, establishing the core command interface.

**Tasks**:
- [ ] Create `commands/talk.md` with frontmatter (description, allowed-tools, argument-hint)
- [ ] Implement Stage 0 forcing questions: Step 0.1 (talk type selection from 5 modes), Step 0.2 (source materials with task references and file paths), Step 0.3 (audience context with topic, audience, time limit, emphasis)
- [ ] Implement task creation with `language: "present"`, `task_type: "talk"`, and `forcing_data` metadata storage in state.json
- [ ] Implement task number input handling (resume research on existing task)
- [ ] Implement file path input handling (read file as primary source, then ask questions)
- [ ] Document all input types and modes in command overview section

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/present/commands/talk.md` - New file: /talk command definition

**Verification**:
- Command file has complete frontmatter matching /deck pattern
- All three forcing question steps defined with AskUserQuestion
- Task creation logic stores forcing_data in state.json metadata
- All four input types handled (description, task number, file path, modes)

---

### Phase 2: Talk Library Context - Patterns and Content Templates [COMPLETED]

**Goal**: Create the talk library directory structure with slide patterns and content templates for all talk modes.

**Tasks**:
- [ ] Create `context/project/present/talk/index.json` with categories: themes, patterns, animations, styles, content, components
- [ ] Create `context/project/present/talk/patterns/conference-standard.json` (12-slide CONFERENCE pattern with slide types, required flags, content focus)
- [ ] Create `context/project/present/talk/patterns/journal-club.json` (12-slide JOURNAL_CLUB pattern)
- [ ] Create `context/project/present/talk/patterns/seminar-deep-dive.json` (35-slide SEMINAR pattern)
- [ ] Create `context/project/present/talk/patterns/defense-grant.json` (30-slide DEFENSE pattern)
- [ ] Create title content templates: `contents/title/title-standard.md`, `contents/title/title-institutional.md`
- [ ] Create motivation content templates: `contents/motivation/motivation-gap.md`, `contents/motivation/motivation-clinical.md`
- [ ] Create methods content templates: `contents/methods/methods-study-design.md`, `contents/methods/methods-flowchart.md`, `contents/methods/methods-analysis.md`
- [ ] Create results content templates: `contents/results/results-table.md`, `contents/results/results-figure.md`, `contents/results/results-forest-plot.md`, `contents/results/results-kaplan-meier.md`
- [ ] Create discussion/conclusions templates: `contents/discussion/discussion-comparison.md`, `contents/conclusions/conclusions-takeaway.md`, `contents/conclusions/limitations-standard.md`
- [ ] Create other templates: `contents/acknowledgments/acknowledgments-funding.md`, `contents/acknowledgments/questions-contact.md`
- [ ] Create `context/project/present/patterns/talk-structure.md` (research talk structure guide)

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/present/context/project/present/talk/index.json` - New: talk library index
- `.claude/extensions/present/context/project/present/talk/patterns/*.json` - New: 4 slide pattern files
- `.claude/extensions/present/context/project/present/talk/contents/**/*.md` - New: ~17 content template files
- `.claude/extensions/present/context/project/present/patterns/talk-structure.md` - New: talk structure guide

**Verification**:
- index.json has all categories with correct paths
- CONFERENCE pattern has 12 slides with type, required, and content_focus fields
- Each content template has Slidev-compatible markdown structure with content_slots
- talk-structure.md documents all 5 mode structures

---

### Phase 3: Components, Themes, and Domain Context [COMPLETED]

**Goal**: Create Vue component specifications, academic-specific themes, and domain reference documentation.

**Tasks**:
- [ ] Create `context/project/present/talk/components/FigurePanel.vue` with props: src, caption, source, scale
- [ ] Create `context/project/present/talk/components/DataTable.vue` with props: headers, rows, highlight_row, caption
- [ ] Create `context/project/present/talk/components/CitationBlock.vue` with props: author, year, journal, finding
- [ ] Create `context/project/present/talk/components/StatResult.vue` with props: test, value, p_value, ci, significance
- [ ] Create `context/project/present/talk/components/FlowDiagram.vue` with props: stages, counts, excluded
- [ ] Create `context/project/present/talk/themes/academic-clean.json` (white bg, muted blue accents, serif headings)
- [ ] Create `context/project/present/talk/themes/clinical-teal.json` (white bg, teal/medical accents)
- [ ] Create `context/project/present/domain/presentation-types.md` (academic presentation types reference)

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/present/context/project/present/talk/components/*.vue` - New: 5 Vue component files
- `.claude/extensions/present/context/project/present/talk/themes/*.json` - New: 2 theme files
- `.claude/extensions/present/context/project/present/domain/presentation-types.md` - New: domain reference

**Verification**:
- Each Vue component has complete props definition and template structure
- Theme JSON files have color palette, typography, and spacing definitions
- presentation-types.md covers all 5 modes with audience, duration, and structure details

---

### Phase 4: Skill and Agent Definitions [COMPLETED]

**Goal**: Create skill-talk and talk-agent definitions following the established thin-wrapper skill and research agent patterns.

**Tasks**:
- [ ] Create `skills/skill-talk/SKILL.md` with frontmatter (name, description, allowed-tools)
- [ ] Implement skill-talk as thin wrapper with internal postflight pattern (matching skill-deck-research structure)
- [ ] Define trigger conditions: `/talk` with task number, `/research` on present task with `task_type: "talk"`
- [ ] Implement routing to talk-agent via Task tool for research phase
- [ ] Implement postflight: status update, artifact linking, git commit, cleanup
- [ ] Create `agents/talk-agent.md` with frontmatter (name, description, model: opus)
- [ ] Define agent context references: talk library index, patterns, content templates, forcing questions data
- [ ] Implement agent execution flow: parse delegation context, load source materials, map content to slide structure, create slide-mapped research report
- [ ] Define minimal follow-up questions (1-2 max) for clarifying slide content gaps
- [ ] Include talk mode routing logic (select pattern based on mode from forcing_data)

**Timing**: 1.5 hours

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/present/skills/skill-talk/SKILL.md` - New: talk research/implement skill
- `.claude/extensions/present/agents/talk-agent.md` - New: talk material synthesis agent

**Verification**:
- Skill frontmatter matches skill-deck-research pattern
- Skill delegates to talk-agent via Task tool (not Skill tool)
- Agent loads talk library context files from Phase 2
- Agent execution flow covers material synthesis and slide mapping
- Agent writes .return-meta.json with proper schema

---

### Phase 5: Integration and Cross-References [COMPLETED]

**Goal**: Update present extension EXTENSION.md with new skill-agent mappings and verify all cross-references are consistent.

**Tasks**:
- [ ] Update `.claude/extensions/present/EXTENSION.md` to add skill-talk and talk-agent to skill-agent mapping table
- [ ] Add /talk command to the extension's command reference section
- [ ] Add talk routing entry documentation (routing.implement.talk and routing.research.talk)
- [ ] Verify all file paths in talk-agent context references point to files created in Phases 2-3
- [ ] Verify talk library index.json paths are consistent with actual file structure
- [ ] Verify command file references to skill-talk and talk-agent use correct names

**Timing**: 0.5 hours

**Depends on**: 3, 4

**Files to modify**:
- `.claude/extensions/present/EXTENSION.md` - Update: add talk skill-agent mapping and command reference

**Verification**:
- EXTENSION.md has talk-agent in agents list and skill-talk in skills list
- All context reference paths in talk-agent.md resolve to existing files
- index.json entries match actual file structure
- No dangling references or missing files

## Testing & Validation

- [ ] All new files exist at documented paths
- [ ] Command file has complete frontmatter and all 3 forcing question steps
- [ ] Skill follows thin-wrapper pattern with correct Task tool delegation
- [ ] Agent has proper context references and execution flow
- [ ] CONFERENCE pattern JSON validates as proper JSON with 12 slide entries
- [ ] All content templates have Slidev-compatible markdown with content_slots
- [ ] EXTENSION.md tables are consistent with new files
- [ ] No orphaned references in any file

## Artifacts & Outputs

- `plans/01_talk-command-plan.md` (this file)
- `summaries/01_talk-command-summary.md` (after implementation)
- All files listed in per-phase "Files to modify" sections

## Rollback/Contingency

All changes are within the `.claude/extensions/present/` directory. Rollback is straightforward:
- Remove new files: `commands/talk.md`, `skills/skill-talk/`, `agents/talk-agent.md`, `context/project/present/talk/`, `context/project/present/domain/presentation-types.md`, `context/project/present/patterns/talk-structure.md`
- Revert EXTENSION.md edits to remove talk references
- No changes to core system files or other extensions
