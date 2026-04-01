# Research Report: Task #342

**Task**: 342 - deck_planner_interactive_questions
**Started**: 2026-03-31T00:00:00Z
**Completed**: 2026-03-31T00:30:00Z
**Effort**: 1 hour research
**Dependencies**: Task 340 (templates), Task 341 (deck command and research agent)
**Sources/Inputs**: Codebase exploration of existing agents, skills, commands, templates, and manifest
**Artifacts**: specs/342_deck_planner_interactive_questions/reports/01_deck-planner-research.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The founder extension currently routes `founder:deck` plan requests to the shared `skill-founder-plan` / `founder-plan-agent`. This task creates a dedicated `deck-planner-agent` and `skill-deck-plan` that override the shared plan routing for deck tasks.
- The deck planner introduces an interactive AskUserQuestion flow with three questions: template selection, slide content assignment, and slide ordering.
- Five Typst deck templates exist (task 340), the deck-research-agent produces a structured 10-slide content report (task 341), and the existing planner-agent/skill-planner pattern provides the architectural blueprint to follow.
- The implementation requires four files plus a manifest update.

## Context & Scope

Task 342 creates a specialized deck planner that sits between research (deck-research-agent) and implementation (founder-implement-agent) in the deck workflow. The standard founder workflow for decks is:

```
/deck "description"  -> task creation with forcing_data
/research N          -> deck-research-agent synthesizes materials into 10-slide mapping
/plan N              -> [currently: skill-founder-plan] -> [NEW: skill-deck-plan -> deck-planner-agent]
/implement N         -> founder-implement-agent generates Typst deck
```

The planner must consume the research report's slide-mapped content and interactively guide the user through three decisions before generating a plan artifact.

## Findings

### 1. Existing Deck System Architecture

#### Templates (Task 340)

Five Typst templates exist at `.claude/extensions/founder/context/project/founder/templates/typst/deck/`:

| Template File | Palette | Best For | Background |
|---------------|---------|----------|------------|
| `deck-dark-blue.typ` | dark-blue | General/default, technology, professional | Dark (#1e293b) |
| `deck-minimal-light.typ` | minimal-light | Data/analytics, enterprise, clean | Light (#f7fafc) |
| `deck-premium-dark.typ` | premium-dark | Luxury tech, premium products, fintech | Near-black (#0f0f1a) |
| `deck-growth-green.typ` | growth-green | Sustainability, health, climate tech | Mint (#f0fdf4) |
| `deck-professional-blue.typ` | professional-blue | Fintech, enterprise SaaS, B2B | White (#ffffff) |

All templates use Touying 0.6.3, simple theme, 16:9 aspect ratio, YC-compliant font sizes (24pt+ minimum). The `deck-dark-blue.typ` is marked as PRIMARY/DEFAULT.

Each template has substitutable parameters: `company-name`, `company-subtitle`, `author-name`, `funding-round`, `funding-date`.

#### Research Agent (Task 341)

The `deck-research-agent` at `.claude/extensions/founder/agents/deck-research-agent.md`:
- Reads source materials (files, task references, prompts)
- Maps content to the 10-slide YC structure
- Marks gaps as `[MISSING: description]`
- Produces a structured report with per-slide content sections
- Includes "Additional Content for Appendix" section for overflow material
- Asks at most 1-2 follow-up questions

The research report structure includes:
- Slide Content Analysis (10 sections, each with bullet fields)
- Source Material Summary table
- Information Gaps (Critical / Nice-to-Have)
- Additional Content for Appendix

#### Command (Task 341)

The `/deck` command at `.claude/extensions/founder/commands/deck.md`:
- STAGE 0: Pre-task forcing questions (purpose, source materials, context)
- Task creation with `task_type: "deck"` and `forcing_data`
- Routes to `skill-deck-research` for research
- Stops at [RESEARCHED] -- user then runs `/plan N` separately

#### Current Plan Routing

The manifest at `.claude/extensions/founder/manifest.json` currently routes:
```json
"plan": {
  "founder:deck": "skill-founder-plan"
}
```

This needs to change to `"skill-deck-plan"` to use the new specialized planner.

### 2. Planner Patterns to Follow

#### Agent Pattern (planner-agent.md)

The core `planner-agent` at `.claude/agents/planner-agent.md` follows this flow:
1. Stage 0: Initialize early metadata (`in_progress`)
2. Stage 1: Parse delegation context
3. Stage 2: Load research report
4. Stage 3: Analyze task scope/complexity
5. Stage 4: Decompose into phases
6. Stage 5: Create plan file (plan-format.md structure)
7. Stage 6: Verify plan and write metadata
8. Stage 7: Return brief text summary

The deck-planner-agent should insert interactive questions between Stage 2 (load research) and Stage 4 (decompose).

#### Skill Pattern (skill-planner/SKILL.md and skill-founder-plan/SKILL.md)

Both skill wrappers follow the same pattern:
1. Input validation (task_number, session_id)
2. Preflight status update (state.json -> "planning", TODO.md -> [PLANNING])
3. Create postflight marker
4. Prepare delegation context (task_context, research_path, metadata)
5. Invoke agent via Task tool
6. Parse subagent return (read .return-meta.json)
7. Postflight status update ("planned", [PLANNED])
8. Link artifact in state.json
9. Git commit
10. Cleanup (remove markers and metadata files)
11. Return brief text summary

The new `skill-deck-plan` should follow this same 11-step pattern.

#### Plan Format (plan-format.md)

Required metadata fields: Task, Status, Effort, Dependencies, Research Inputs, Artifacts, Standards, Type.

Required sections: Overview, Goals & Non-Goals, Risks & Mitigations, Implementation Phases (each with Goal/Tasks/Timing/Files/Verification), Testing & Validation, Artifacts & Outputs, Rollback/Contingency.

### 3. AskUserQuestion Patterns

The codebase uses AskUserQuestion extensively for interactive flows. Key patterns observed:

**Single-select with options list**: Used in `/deck` STAGE 0 for purpose selection, `/fix-it` for grouping mode. Presents options and stores the selected value.

**Multi-select with options list**: Used in `/fix-it` for TODO/QUESTION selection, `/review` for task proposals, `/meta` for task selection. Presents checkboxes, returns array of selected items.

**Sequential questions**: The `/deck` command already demonstrates a 3-question flow (purpose, sources, context) with conditional logic (Step 0.3 only asks if sources are "none").

For the deck planner, three sequential AskUserQuestion calls are needed:
1. Template selection (single-select from 5 templates)
2. Slide content selection (multi-select or assignment from research findings)
3. Slide ordering (single-select from arrangement options)

### 4. Deck Research Report Content Available to Planner

The research report provides:
- Per-slide content with structured fields (e.g., Problem: Pain Point, Who Experiences It, Current Workarounds, Evidence)
- `[MISSING: ...]` markers for gaps
- "Additional Content for Appendix" section with overflow material
- Information gap analysis (Critical vs Nice-to-Have)

The planner consumes this to:
- Present populated slides vs sparse slides for user to prioritize
- Offer appendix assignment for overflow content
- Generate slide-by-slide content assignments in the plan

### 5. 10-Slide YC Structure Reference

From `pitch-deck-structure.md`, the standard ordering is:
1. Title
2. Problem
3. Solution
4. Traction (note: YC places traction before market)
5. Market
6. Team
7. Business Model
8. Competition
9. Vision/Plan
10. Ask/Fundraise

This ordering may differ from the deck-research-agent's mapping (which uses Market Opportunity at slide 4 and Traction at slide 6). The planner should offer ordering variants.

### 6. Manifest and Index Updates Required

**manifest.json** changes:
- Add `"deck-planner-agent.md"` to `provides.agents`
- Add `"skill-deck-plan"` to `provides.skills`
- Change `routing.plan["founder:deck"]` from `"skill-founder-plan"` to `"skill-deck-plan"`

**index-entries.json** changes:
- Add entries for any new context files the deck-planner-agent needs
- The existing deck-related entries (pitch-deck-structure, touying-pitch-deck-template, yc-compliance-checklist) already include `founder-plan-agent` in their `agents` arrays -- the new `deck-planner-agent` should be added

## Recommendations

### Interactive Question Design

**Question 1: Template Selection** (single-select)

Present the 5 templates with visual descriptions:
```
Select a visual style for your pitch deck:

1. Dark Blue (DEFAULT) - Dark navy background, blue accents. Best for: technology, professional
2. Minimal Light - Clean white background, blue accents. Best for: enterprise, data-heavy
3. Premium Dark - Near-black background, gold accents. Best for: luxury, fintech
4. Growth Green - Mint background, green accents. Best for: sustainability, health, climate
5. Professional Blue - White background, deep blue. Best for: B2B, institutional investors
```

**Question 2: Slide Content Assignment** (multi-select + assignment)

Parse the research report, identify slides with content vs [MISSING]. Present:
```
The research report populated {M}/10 slides. Select which slides to include in your main deck vs appendix:

Main Deck (checked = include, unchecked = move to appendix):
[x] 1. Title - Company Name, One-liner, Founders
[x] 2. Problem - Pain point, target user, evidence
[x] 3. Solution - Product description, differentiator
[ ] 4. Market Opportunity - [MISSING: TAM/SAM/SOM data]
[x] 5. Business Model - Revenue model, pricing
...

Additional appendix content available:
- {item from Additional Content for Appendix}
```

Slides with all-[MISSING] fields should be unchecked by default. Slides with partial content should be checked with a note.

**Question 3: Slide Ordering** (single-select)

Offer 2-3 ordering arrangements:
```
Select slide arrangement:

A. YC Standard: Title > Problem > Solution > Traction > Market > Team > Model > Competition > Vision > Ask
B. Story-First: Title > Problem > Solution > Market > Model > Traction > Team > Competition > Vision > Ask
C. Traction-Led: Title > Traction > Problem > Solution > Market > Model > Team > Competition > Vision > Ask
```

### Plan Output Structure

The plan should be a standard plan-format.md artifact with deck-specific additions:

- **Template**: Which .typ file to use
- **Slide Manifest**: Ordered list of slides with content assignment per slide
- **Appendix Slides**: What goes in appendix
- **Content Gaps**: What [MISSING] items need to be fabricated or omitted

The implementation phases in the plan would typically be:
1. Phase 1: Template setup and parameter substitution
2. Phase 2: Main slide content population (slides 1-10)
3. Phase 3: Appendix slides
4. Phase 4: Compilation and verification

### File Structure

```
.claude/extensions/founder/
  agents/deck-planner-agent.md          # NEW: interactive deck planner agent
  skills/skill-deck-plan/SKILL.md       # NEW: thin wrapper skill
  manifest.json                         # MODIFY: add agent/skill, update routing
  index-entries.json                    # MODIFY: add deck-planner-agent to relevant entries
```

## Decisions

1. **Separate agent vs extending founder-plan-agent**: Create a dedicated `deck-planner-agent` because the interactive question flow is unique to decks and would add complexity to the shared planner.

2. **Three questions, not more**: The task specifies exactly three questions (template, content selection, ordering). This keeps the flow focused and avoids the forcing-question fatigue seen in other founder workflows.

3. **Override routing, not the command**: The `/plan` command already supports extension routing. Changing the manifest routing entry from `skill-founder-plan` to `skill-deck-plan` is the cleanest approach.

4. **Plan format compliance**: The deck planner must produce a standard plan-format.md artifact. Deck-specific data (template, slide manifest) goes in a "Deck Configuration" section within the plan.

5. **Agent model**: The deck-planner-agent should use `model: opus` in frontmatter, consistent with the planner-agent pattern for superior reasoning during interactive flows.

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Research report may have different slide numbering than pitch-deck-structure.md | Medium | Normalize to YC standard ordering when parsing research report |
| User may select 0 slides for main deck | Low | Require at least 3 slides in main deck, warn if < 5 |
| Template selection needs visual preview | Low | Include color descriptions and "Best for" hints in options |
| AskUserQuestion options format may vary | Medium | Follow exact patterns from /deck STAGE 0 and /fix-it skill |

## Appendix

### Search Queries Used
- Glob: `.claude/extensions/founder/**` for all founder extension files
- Glob: `deck/*.typ` for template files
- Grep: `AskUserQuestion` across `.claude/` for interactive patterns
- Grep: `multiSelect` for multi-select patterns
- Read: planner-agent.md, skill-planner, skill-founder-plan, deck-research-agent, deck command, manifest, EXTENSION.md, plan-format.md, pitch-deck-structure.md, all 5 template headers

### Key File References
- Agent pattern: `/home/benjamin/.config/nvim/.claude/agents/planner-agent.md`
- Skill pattern: `/home/benjamin/.config/nvim/.claude/skills/skill-planner/SKILL.md`
- Founder skill pattern: `/home/benjamin/.config/nvim/.claude/extensions/founder/skills/skill-founder-plan/SKILL.md`
- Deck research agent: `/home/benjamin/.config/nvim/.claude/extensions/founder/agents/deck-research-agent.md`
- Deck command: `/home/benjamin/.config/nvim/.claude/extensions/founder/commands/deck.md`
- Manifest: `/home/benjamin/.config/nvim/.claude/extensions/founder/manifest.json`
- Templates: `/home/benjamin/.config/nvim/.claude/extensions/founder/context/project/founder/templates/typst/deck/`
- Plan format: `/home/benjamin/.config/nvim/.claude/context/formats/plan-format.md`
- Pitch deck structure: `/home/benjamin/.config/nvim/.claude/extensions/present/context/project/present/patterns/pitch-deck-structure.md`
- Index entries: `/home/benjamin/.config/nvim/.claude/extensions/founder/index-entries.json`
