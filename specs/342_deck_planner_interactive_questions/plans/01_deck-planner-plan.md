# Implementation Plan: Deck Planner with Interactive Questions

- **Task**: 342 - deck_planner_interactive_questions
- **Status**: [IMPLEMENTING]
- **Effort**: 4 hours
- **Dependencies**: Task 340 (deck templates), Task 341 (deck command and research agent)
- **Research Inputs**: reports/01_deck-planner-research.md
- **Artifacts**: plans/01_deck-planner-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create a dedicated deck-planner-agent and skill-deck-plan for the founder extension that overrides the shared planning path for deck tasks. The agent introduces an interactive AskUserQuestion flow with three sequential questions (template selection, slide content assignment, slide ordering) before generating a plan artifact that specifies the Typst template, slide-by-slide content assignments, and appendix contents. The skill is a thin wrapper that handles preflight/postflight status management and delegates to the agent. The manifest, index entries, and extension documentation are updated to register the new components.

### Research Integration

**Research Report**: [01_deck-planner-research.md](../reports/01_deck-planner-research.md)

**Key Findings**:
- Five Typst deck templates exist at `.claude/extensions/founder/context/project/founder/templates/typst/deck/` (dark-blue, minimal-light, premium-dark, growth-green, professional-blue)
- The deck-research-agent produces a structured 10-slide report with per-slide content sections and appendix overflow
- The existing planner-agent and founder-plan-agent provide architectural blueprints to follow
- The manifest currently routes `founder:deck` plan requests to `skill-founder-plan`, which needs to change to `skill-deck-plan`
- AskUserQuestion patterns for single-select and multi-select are well-established in the codebase

## Goals & Non-Goals

**Goals**:
- Create `deck-planner-agent.md` with interactive 3-question AskUserQuestion flow
- Create `skill-deck-plan/SKILL.md` as thin wrapper with preflight/postflight pattern
- Update manifest routing so `founder:deck` plan requests use `skill-deck-plan`
- Update index-entries.json to include `deck-planner-agent` in relevant context entries
- Update EXTENSION.md to document the new skill-agent mapping

**Non-Goals**:
- Modifying the deck-research-agent or its output format
- Creating new templates or modifying existing Typst templates
- Implementing the actual deck generation (that is the implement phase)
- Adding new commands (the existing `/plan` command routes via manifest)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Research report slide numbering differs from YC standard | Medium | Medium | Agent normalizes to YC ordering when parsing research report |
| User selects 0 slides for main deck | Low | Low | Agent requires minimum 3 slides, warns if fewer than 5 |
| AskUserQuestion options formatting inconsistency | Medium | Low | Follow exact patterns from /deck STAGE 0 and /fix-it skill |
| Manifest routing override breaks shared plan path | Low | Low | Only change `founder:deck` key, leave other keys unchanged |

## Implementation Phases

### Phase 1: Create deck-planner-agent.md [COMPLETED]

**Goal**: Create the deck planner agent definition that runs the interactive AskUserQuestion flow and generates the deck plan artifact

**Tasks**:
- [ ] Create `.claude/extensions/founder/agents/deck-planner-agent.md` with frontmatter (name, description, model: opus)
- [ ] Define agent metadata section (name, purpose, invoked-by, return format)
- [ ] Define allowed tools section (AskUserQuestion, Read, Write, Glob, Bash)
- [ ] Define context references section (pitch-deck-structure.md, touying-pitch-deck-template.md, yc-compliance-checklist.md, plan-format.md, return-metadata-file.md)
- [ ] Implement Stage 0: Initialize early metadata (in_progress status)
- [ ] Implement Stage 1: Parse delegation context (task_context, research_path, session_id, artifact_number)
- [ ] Implement Stage 2: Load and parse research report (read slide content analysis, extract populated vs MISSING slides, extract appendix content)
- [ ] Implement Stage 3: Interactive Question 1 - Template Selection (single-select AskUserQuestion with 5 template options including color descriptions and "Best for" hints)
- [ ] Implement Stage 4: Interactive Question 2 - Slide Content Assignment (multi-select AskUserQuestion showing populated vs MISSING slides, defaulting checked for populated, unchecked for all-MISSING; include appendix content options)
- [ ] Implement Stage 5: Interactive Question 3 - Slide Ordering (single-select from 3 arrangement options: YC Standard, Story-First, Traction-Led)
- [ ] Implement Stage 6: Generate plan artifact conforming to plan-format.md with deck-specific "Deck Configuration" section (selected template, slide manifest with ordering, content assignments per slide, appendix contents, content gaps)
- [ ] Implement Stage 7: Verify plan format (8 metadata fields, 7 sections, phase format)
- [ ] Implement Stage 8: Write metadata file (status: planned)
- [ ] Implement Stage 9: Return brief text summary
- [ ] Define error handling section (no research report, user abandonment, all slides deselected)
- [ ] Define critical requirements section (MUST DO / MUST NOT lists)

**Timing**: 2 hours

**Files to create**:
- `.claude/extensions/founder/agents/deck-planner-agent.md` - Full agent specification

**Verification**:
- Agent file exists and has valid frontmatter with `model: opus`
- All 9 stages documented with clear instructions
- Three AskUserQuestion flows defined with correct single-select and multi-select patterns
- Plan output includes Deck Configuration section with template, slide manifest, appendix
- Error handling covers no-research, abandonment, and edge cases

---

### Phase 2: Create skill-deck-plan/SKILL.md [COMPLETED]

**Goal**: Create the thin wrapper skill that handles preflight/postflight status management and delegates to deck-planner-agent

**Tasks**:
- [ ] Create `.claude/extensions/founder/skills/skill-deck-plan/` directory
- [ ] Create `SKILL.md` with frontmatter (name: skill-deck-plan, description, allowed-tools: Task, Bash, Edit, Read, Write)
- [ ] Define trigger conditions section (direct: `/plan` on founder:deck tasks; language routing: task_type=deck; NOT trigger for other task types)
- [ ] Implement Stage 1: Input validation (task_number, session_id from delegation context)
- [ ] Implement Stage 2: Preflight status update (state.json -> "planning", TODO.md -> [PLANNING])
- [ ] Implement Stage 3: Create postflight marker file
- [ ] Implement Stage 4: Context preparation (extract task_type, research_path, prepare delegation context JSON for agent)
- [ ] Implement Stage 5: Invoke agent via Task tool (subagent_type: "deck-planner-agent", include task_context with task_type: "deck")
- [ ] Implement Stage 6: Parse subagent return (read .return-meta.json, extract status, artifact_path, summary)
- [ ] Implement Stage 7: Postflight status update (state.json -> "planned", TODO.md -> [PLANNED], link artifact)
- [ ] Implement Stage 8: Git commit with standard format
- [ ] Implement Stage 9: Cleanup (remove .postflight-pending, .postflight-loop-guard, .return-meta.json)
- [ ] Implement Stage 10: Return brief text summary
- [ ] Define error handling section (session ID missing, task not found, agent errors, user abandonment)

**Timing**: 1 hour

**Files to create**:
- `.claude/extensions/founder/skills/skill-deck-plan/SKILL.md` - Skill specification

**Verification**:
- Skill file exists with correct frontmatter
- 10-stage flow matches skill-founder-plan pattern
- Delegates to `deck-planner-agent` (not `founder-plan-agent`)
- Preflight sets [PLANNING], postflight sets [PLANNED]
- Cleanup removes all temporary files

---

### Phase 3: Update manifest, index entries, and documentation [NOT STARTED]

**Goal**: Register the new agent and skill in the founder extension manifest, update context index entries, and update extension documentation

**Tasks**:
- [ ] Update `manifest.json`: Add `"deck-planner-agent.md"` to `provides.agents` array
- [ ] Update `manifest.json`: Add `"skill-deck-plan"` to `provides.skills` array
- [ ] Update `manifest.json`: Change `routing.plan["founder:deck"]` from `"skill-founder-plan"` to `"skill-deck-plan"`
- [ ] Update `index-entries.json`: Add `"deck-planner-agent"` to the agents arrays for `pitch-deck-structure.md`, `touying-pitch-deck-template.md`, and `yc-compliance-checklist.md` entries
- [ ] Update `EXTENSION.md`: Add `skill-deck-plan | deck-planner-agent | Pitch deck planning with interactive questions` row to Skill-Agent Mapping table
- [ ] Update `EXTENSION.md`: Update "Language Routing" section to note that deck tasks use a dedicated planner

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/manifest.json` - Add agent, skill, update routing
- `.claude/extensions/founder/index-entries.json` - Add deck-planner-agent to deck-related entries
- `.claude/extensions/founder/EXTENSION.md` - Document new skill-agent mapping

**Verification**:
- `jq '.provides.agents' manifest.json` includes `deck-planner-agent.md`
- `jq '.provides.skills' manifest.json` includes `skill-deck-plan`
- `jq '.routing.plan["founder:deck"]' manifest.json` returns `skill-deck-plan`
- `jq '.entries[] | select(.path | contains("pitch-deck")) | .load_when.agents' index-entries.json` includes `deck-planner-agent`
- EXTENSION.md table includes skill-deck-plan row

---

### Phase 4: Verification and cross-validation [NOT STARTED]

**Goal**: Validate all files created, routing works correctly, and cross-reference with existing deck components

**Tasks**:
- [ ] Verify `deck-planner-agent.md` exists and has valid markdown structure with frontmatter
- [ ] Verify `skill-deck-plan/SKILL.md` exists and has valid markdown structure with frontmatter
- [ ] Verify manifest.json is valid JSON after edits
- [ ] Verify index-entries.json is valid JSON after edits
- [ ] Cross-reference: deck-planner-agent context references point to existing files (pitch-deck-structure.md, templates, etc.)
- [ ] Cross-reference: skill-deck-plan delegates to `deck-planner-agent` (matching agent name in agents/ directory)
- [ ] Cross-reference: manifest routing chain is complete (routing.plan["founder:deck"] -> skill-deck-plan -> deck-planner-agent)
- [ ] Cross-reference: deck-research-agent output format matches what deck-planner-agent expects to parse
- [ ] Verify no broken references in EXTENSION.md

**Timing**: 30 minutes

**Files to verify**:
- `.claude/extensions/founder/agents/deck-planner-agent.md`
- `.claude/extensions/founder/skills/skill-deck-plan/SKILL.md`
- `.claude/extensions/founder/manifest.json`
- `.claude/extensions/founder/index-entries.json`
- `.claude/extensions/founder/EXTENSION.md`

**Verification**:
- All files exist and are syntactically valid
- JSON files parse without errors
- Routing chain is complete and consistent
- No dangling references to nonexistent files or agents

## Testing & Validation

- [ ] `deck-planner-agent.md` contains all 9 execution stages
- [ ] `deck-planner-agent.md` defines 3 AskUserQuestion interactions (template, content, ordering)
- [ ] `skill-deck-plan/SKILL.md` follows the 10-stage skill pattern
- [ ] `manifest.json` passes `jq empty` validation
- [ ] `index-entries.json` passes `jq empty` validation
- [ ] Routing chain: `/plan N` (founder:deck task) -> skill-deck-plan -> deck-planner-agent
- [ ] Agent produces plan with Deck Configuration section (template, slide manifest, appendix)
- [ ] No existing deck components (deck-research-agent, /deck command) are modified

## Artifacts & Outputs

- `plans/01_deck-planner-plan.md` (this plan)
- `.claude/extensions/founder/agents/deck-planner-agent.md` (new agent)
- `.claude/extensions/founder/skills/skill-deck-plan/SKILL.md` (new skill)
- `.claude/extensions/founder/manifest.json` (modified)
- `.claude/extensions/founder/index-entries.json` (modified)
- `.claude/extensions/founder/EXTENSION.md` (modified)

## Rollback/Contingency

If implementation fails:
1. Remove `.claude/extensions/founder/agents/deck-planner-agent.md`
2. Remove `.claude/extensions/founder/skills/skill-deck-plan/` directory
3. Revert `manifest.json` to restore `"founder:deck": "skill-founder-plan"` in routing.plan
4. Revert `index-entries.json` to remove `deck-planner-agent` from agent arrays
5. Revert `EXTENSION.md` to remove skill-deck-plan row
6. All changes are additive except the routing override, so partial rollback is straightforward
