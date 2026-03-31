# Implementation Plan: /deck Command and Deck-Research-Agent Integration

- **Task**: 341 - /deck command and deck-research-agent integration
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: 340 (RESEARCHED)
- **Research Inputs**: specs/341_deck_command_and_research_agent/reports/01_deck-command-research.md
- **Artifacts**: plans/01_deck-command-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create the `/deck` command, `deck-research-agent`, and `skill-deck-research` within the founder extension, following the established founder command/skill/agent triplet pattern. The deck research agent differs from other founder agents in that it synthesizes input materials (files, prompts, task references) into slide-mapped content rather than conducting interactive forcing-question-based research. Update `manifest.json`, `index-entries.json`, and `EXTENSION.md` to register the new components.

### Research Integration

The research report (01_deck-command-research.md) identified 7 existing founder triplets as structural templates, documented the 11-stage skill flow, the agent stage pattern, and the specific differences between deck research (material synthesis) and other founder research (interactive Q&A). The report also identified the present extension's existing deck components which will be migrated separately in task 344.

## Goals & Non-Goals

**Goals**:
- Create `/deck` command following the founder STAGE 0 / GATE IN / DELEGATE / GATE OUT pattern
- Create `deck-research-agent` that synthesizes input materials into a slide-mapped research report
- Create `skill-deck-research` as a thin wrapper with the standard 11-stage flow
- Register `founder:deck` routing in `manifest.json`
- Add deck-specific index entries to `founder/index-entries.json`
- Update `EXTENSION.md` with the new skill-agent mapping and command entry

**Non-Goals**:
- Deck planning agent/skill (task 342)
- Deck implementation agent/skill (task 343)
- Migration of present extension deck components (task 344)
- Creating new context files for deck patterns (remain in present/ until task 344)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Index entries reference present/ context paths that may change | M | L | Use stable paths; task 344 will update references |
| Deck research agent output format may not align with planner expectations | M | M | Define clear report schema with [MISSING] markers; adjust in task 342 if needed |
| Conflict with present's existing /deck command when both extensions loaded | H | M | Founder /deck creates tasks; present /deck generates standalone; document distinction |
| Task reference parsing (pulling research from other tasks) adds complexity | M | M | Validate task existence; graceful fallback to prompt-only mode |

## Implementation Phases

### Phase 1: Create deck-research-agent [COMPLETED]

**Goal**: Create the agent definition following the founder agent pattern (market-agent.md as template), adapted for material synthesis instead of interactive Q&A.

**Tasks**:
- [ ] Create `founder/agents/deck-research-agent.md` with frontmatter (name, description, no mcp-servers)
- [ ] Define allowed tools: AskUserQuestion, Read, Write, Glob, Bash (no WebSearch or MCP)
- [ ] Add context references to present/ deck pattern files (pitch-deck-structure.md, touying-pitch-deck-template.md, yc-compliance-checklist.md)
- [ ] Implement Stage 0: Initialize early metadata with `in_progress` status
- [ ] Implement Stage 1: Parse delegation context (extract forcing_data with purpose, source_materials, context)
- [ ] Implement Stage 2: Material ingestion -- read files at paths, load referenced task research reports, process prompt text
- [ ] Implement Stage 3: Content extraction -- map extracted information to 10-slide YC structure
- [ ] Implement Stage 4: Gap analysis -- identify [MISSING] items for each slide
- [ ] Implement Stage 5: Optional follow-up -- ask 1-2 clarifying questions only for critical missing info
- [ ] Implement Stage 6: Generate research report with slide content analysis, source material summary, information gaps, and appendix content
- [ ] Implement Stage 7: Write research report to `specs/{NNN}_{SLUG}/reports/` path
- [ ] Implement Stage 8: Write final metadata file with `researched` status
- [ ] Implement Stage 9: Return brief text summary (not JSON)

**Timing**: 1.5 hours

**Files to modify**:
- `.claude/extensions/founder/agents/deck-research-agent.md` - CREATE (~250 lines)

**Verification**:
- Agent file exists with correct frontmatter (name: deck-research-agent, no mcp-servers)
- All 10 stages are defined with clear instructions
- Context references point to existing present/ pattern files
- Report output format includes slide-mapped structure with [MISSING] markers

---

### Phase 2: Create skill-deck-research [COMPLETED]

**Goal**: Create the thin skill wrapper following the 11-stage pattern from skill-market, routing to deck-research-agent via Task tool.

**Tasks**:
- [ ] Create `founder/skills/skill-deck-research/SKILL.md` with frontmatter (name: skill-deck-research, allowed-tools: Task, Bash, Edit, Read, Write)
- [ ] Implement Stage 1: Input validation (lookup task in state.json, verify language: founder, task_type: deck)
- [ ] Implement Stage 2: Preflight status update (set RESEARCHING)
- [ ] Implement Stage 3: Create postflight marker file
- [ ] Implement Stage 4: Prepare delegation context (include forcing_data with purpose, source_materials, context)
- [ ] Implement Stage 5: Invoke deck-research-agent via Task tool (NOT Skill tool)
- [ ] Implement Stage 6: Parse subagent return (read .return-meta.json)
- [ ] Implement Stage 7: Update task status (set RESEARCHED, postflight)
- [ ] Implement Stage 8: Link artifacts in TODO.md
- [ ] Implement Stage 9: Git commit with standard format
- [ ] Implement Stage 10: Cleanup (remove markers and metadata file)
- [ ] Implement Stage 11: Return brief summary

**Timing**: 0.75 hours

**Files to modify**:
- `.claude/extensions/founder/skills/skill-deck-research/SKILL.md` - CREATE (~200 lines)

**Verification**:
- Skill file exists with correct frontmatter
- All 11 stages present and match the skill-market pattern
- Delegates to `deck-research-agent` (not another agent)
- Postflight handles status update, artifact linking, git commit, cleanup

---

### Phase 3: Create /deck command [COMPLETED]

**Goal**: Create the command definition following the founder command pattern (market.md as template), with deck-specific forcing questions and input handling.

**Tasks**:
- [ ] Create `founder/commands/deck.md` with frontmatter (description, allowed-tools, argument-hint)
- [ ] Define syntax section: `/deck "description"`, `/deck N`, `/deck /path/to/file`, `/deck --quick "prompt"`
- [ ] Define input types table matching the founder pattern
- [ ] Define modes: INVESTOR, UPDATE, INTERNAL, PARTNERSHIP
- [ ] Implement STAGE 0: Pre-task forcing questions
  - [ ] Question 1: Deck purpose (INVESTOR/UPDATE/INTERNAL/PARTNERSHIP)
  - [ ] Question 2: Source materials (task references, file paths, or none)
  - [ ] Question 3: Company/project context (if no source materials)
  - [ ] Store as forcing_data with fields: purpose, source_materials, context
- [ ] Implement CHECKPOINT 1: GATE IN
  - [ ] Generate session_id
  - [ ] Detect input type (description, task_number, file_path, --quick)
  - [ ] Handle each input type
  - [ ] Create task in state.json with language: founder, task_type: deck
  - [ ] Update TODO.md
  - [ ] Git commit task creation
  - [ ] STOP for new tasks (user runs /research next)
- [ ] Implement STAGE 2: DELEGATE to skill-deck-research via Skill tool
- [ ] Implement CHECKPOINT 2: GATE OUT (verify research completed, display result)

**Timing**: 0.5 hours

**Files to modify**:
- `.claude/extensions/founder/commands/deck.md` - CREATE (~300 lines)

**Verification**:
- Command file exists with correct frontmatter and argument-hint
- All four stages (STAGE 0, CHECKPOINT 1, STAGE 2, CHECKPOINT 2) defined
- Forcing questions are minimal (2-3) compared to other founder commands
- Task creation sets language: founder and task_type: deck
- --quick mode delegates to present's skill-deck for standalone generation

---

### Phase 4: Register components in manifest, index, and EXTENSION.md [IN PROGRESS]

**Goal**: Wire the new components into the founder extension's configuration files so routing, context loading, and documentation all reflect the new deck capabilities.

**Tasks**:
- [ ] Update `founder/manifest.json`:
  - [ ] Add `"deck-research-agent.md"` to `provides.agents`
  - [ ] Add `"skill-deck-research"` to `provides.skills`
  - [ ] Add `"deck.md"` to `provides.commands`
  - [ ] Add `"founder:deck": "skill-deck-research"` to `routing.research`
  - [ ] Add `"founder:deck": "skill-founder-plan"` to `routing.plan` (placeholder for task 342)
  - [ ] Add `"founder:deck": "skill-founder-implement"` to `routing.implement` (placeholder for task 343)
- [ ] Update `founder/index-entries.json`:
  - [ ] Add entry for pitch-deck-structure.md with deck-research-agent in agents, founder in languages, deck in task_types, /deck in commands
  - [ ] Add entry for touying-pitch-deck-template.md with same load_when pattern
  - [ ] Add entry for yc-compliance-checklist.md with same load_when pattern
- [ ] Update `founder/EXTENSION.md`:
  - [ ] Add skill-deck-research / deck-research-agent row to Skill-Agent Mapping table
  - [ ] Add `/deck` row to Commands table
  - [ ] Note that planning/implementation use shared founder agents until tasks 342-343

**Timing**: 0.25 hours

**Files to modify**:
- `.claude/extensions/founder/manifest.json` - MODIFY (add routing, provides entries)
- `.claude/extensions/founder/index-entries.json` - MODIFY (add 3 deck context entries)
- `.claude/extensions/founder/EXTENSION.md` - MODIFY (add table rows)

**Verification**:
- `jq '.routing.research["founder:deck"]' manifest.json` returns `"skill-deck-research"`
- `jq '.provides.agents | index("deck-research-agent.md")' manifest.json` returns non-null
- `jq '.provides.skills | index("skill-deck-research")' manifest.json` returns non-null
- `jq '.provides.commands | index("deck.md")' manifest.json` returns non-null
- Index entries reference present/ context paths with deck-research-agent in agents array
- EXTENSION.md tables include /deck and skill-deck-research rows

## Testing & Validation

- [ ] Verify all 3 new files created in correct locations under `founder/`
- [ ] Verify manifest.json is valid JSON after modifications
- [ ] Verify index-entries.json is valid JSON after modifications
- [ ] Verify `founder:deck` routing resolves to `skill-deck-research` in manifest
- [ ] Verify deck-research-agent references context files that exist in present/ extension
- [ ] Verify skill-deck-research delegates to deck-research-agent (not another agent)
- [ ] Verify /deck command creates tasks with language: founder, task_type: deck
- [ ] Verify EXTENSION.md tables are well-formatted with new entries

## Artifacts & Outputs

- `.claude/extensions/founder/commands/deck.md` - /deck command definition
- `.claude/extensions/founder/agents/deck-research-agent.md` - Research agent
- `.claude/extensions/founder/skills/skill-deck-research/SKILL.md` - Research skill
- `.claude/extensions/founder/manifest.json` - Updated routing and provides
- `.claude/extensions/founder/index-entries.json` - Updated with deck context entries
- `.claude/extensions/founder/EXTENSION.md` - Updated documentation tables

## Rollback/Contingency

All changes are additive (new files + new entries in existing config files). Rollback by:
1. Deleting the 3 new files (deck.md, deck-research-agent.md, SKILL.md)
2. Reverting manifest.json, index-entries.json, and EXTENSION.md to pre-implementation state via `git checkout`
