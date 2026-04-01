# Implementation Plan: Task #343

- **Task**: 343 - Deck builder typst agent
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: Task 340 (COMPLETED), Task 342 (NOT STARTED - deck planner)
- **Research Inputs**: specs/343_deck_builder_typst_agent/reports/01_deck-builder-research.md
- **Artifacts**: plans/01_deck-builder-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create the deck builder agent (`deck-builder-agent.md`) and its routing skill (`skill-deck-implement/SKILL.md`) within the founder extension. The builder reads a deck plan and research report, selects the specified typst template from task 340's 5 templates, populates slide content by replacing `[TODO:]` markers, generates a complete `.typ` file with 10 main slides plus optional appendix slides, and compiles to PDF via `typst compile`. The manifest routing for `founder:deck` implement is overridden from `skill-founder-implement` to `skill-deck-implement`.

### Research Integration

Key findings from research:
- Templates use 5 shared `#let` parameters (company-name, company-subtitle, author-name, funding-round, funding-date) and consistent `[TODO:]` markers across all 10 slides
- The `founder-implement-agent` + `skill-founder-implement` provide the canonical pattern to follow
- Builder should generate a complete new `.typ` file from template structure rather than fragile string replacement
- Output goes to `strategy/{slug}-deck.typ` and `strategy/{slug}-deck.pdf` (not `founder/`)
- PDF compilation should be non-blocking (same as founder-implement-agent Phase 5 pattern)
- The deck-research-agent output provides slide-mapped content with `[MISSING]` markers for gaps

## Goals & Non-Goals

**Goals**:
- Create `deck-builder-agent.md` that reads plan + research and generates populated typst deck files
- Create `skill-deck-implement/SKILL.md` that routes `/implement` for deck tasks to the builder agent
- Update `manifest.json` to override `founder:deck` implement routing
- Update `index-entries.json` with context discovery entries for the new agent
- Update `EXTENSION.md` skill-agent mapping table
- Register new agent and skill in `manifest.json` provides arrays

**Non-Goals**:
- Modifying the existing 5 typst templates (task 340 output)
- Creating the deck planner (task 342)
- Adding new slide types beyond the 10-slide YC structure
- Interactive template selection UI (template comes from plan)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Task 342 (deck planner) not yet complete -- plan format unknown | M | H | Builder accepts flexible plan format; follows founder-plan-agent conventions |
| Template `[TODO:]` markers may vary slightly between templates | M | L | Builder generates complete file from template structure, not string-replace |
| Research report may have `[MISSING]` markers for some slides | M | M | Builder preserves `[TODO:]` for missing content, logs count of gaps |
| Typst compilation may fail (missing fonts, package download) | L | L | Non-blocking Phase 5; `.typ` source preserved; summary notes compilation status |
| `strategy/` directory does not exist yet | L | H | Builder creates via `mkdir -p strategy/` |
| Dollar sign escaping in typst content | M | M | Templates already escape with backslash; builder must maintain this pattern |

## Implementation Phases

### Phase 1: Create deck-builder-agent.md [COMPLETED]

**Goal**: Create the core agent definition that generates typst pitch decks from plans and research

**Tasks**:
- [ ] Create `founder/agents/deck-builder-agent.md` following `founder-implement-agent.md` structure
- [ ] Define agent frontmatter (name, description)
- [ ] Define allowed tools (Read, Write, Edit, Glob, Bash)
- [ ] Define context references (deck templates, pitch-deck-structure, touying template, YC checklist, return-metadata-file)
- [ ] Implement Stage 0: Early metadata initialization
- [ ] Implement Stage 1: Parse delegation context (task_number, plan_path, template selection, session_id)
- [ ] Implement Stage 2: Load plan and research report, extract slide-mapped content
- [ ] Implement Stage 2.5: Typst availability check (`typst --version`)
- [ ] Implement Stage 3: Resume detection (check for existing partial `.typ` file)
- [ ] Implement Stage 4: Template selection and content generation
  - Read selected template from `founder/context/project/founder/templates/typst/deck/deck-{palette}.typ`
  - Default to `deck-dark-blue.typ` if no palette specified
  - Generate complete `.typ` file: replicate template infrastructure (imports, theme, typography) with actual content replacing `[TODO:]` markers
  - Set 5 parameter variables from research data
  - Preserve `[TODO:]` for any `[MISSING]` research content
  - Generate optional appendix slides from research "Additional Content for Appendix" section
  - Write to `strategy/{slug}-deck.typ`
- [ ] Implement Stage 5: Non-blocking typst compilation (`typst compile` to PDF)
- [ ] Implement Stage 6: Create implementation summary artifact
- [ ] Implement Stage 7: Write return metadata file

**Timing**: 1.5 hours

**Files to modify**:
- `.claude/extensions/founder/agents/deck-builder-agent.md` - CREATE new agent definition

**Verification**:
- Agent file exists with correct frontmatter
- All 8 stages defined (0-7)
- Context references include deck templates and present extension patterns
- Template selection logic handles all 5 templates plus default fallback
- Content substitution covers all 10 slides plus appendix
- Resume support for interrupted builds
- Non-blocking compilation pattern matches founder-implement-agent

---

### Phase 2: Create skill-deck-implement [COMPLETED]

**Goal**: Create the routing skill that delegates deck implementation to the builder agent

**Tasks**:
- [ ] Create `founder/skills/skill-deck-implement/` directory
- [ ] Create `founder/skills/skill-deck-implement/SKILL.md` following `skill-founder-implement/SKILL.md` structure
- [ ] Define skill frontmatter (name, description, allowed-tools: Task, Bash, Edit, Read, Write)
- [ ] Implement input validation (task_number, plan_path, session_id)
- [ ] Implement preflight status update (task -> implementing)
- [ ] Implement postflight marker creation
- [ ] Implement delegation context preparation (include output_dir: "strategy/", template palette from plan)
- [ ] Implement Task tool invocation to `deck-builder-agent`
- [ ] Implement metadata file reading and validation
- [ ] Implement postflight status update
- [ ] Implement git commit step
- [ ] Implement cleanup

**Timing**: 0.75 hours

**Files to modify**:
- `.claude/extensions/founder/skills/skill-deck-implement/SKILL.md` - CREATE new skill definition

**Verification**:
- Skill file exists with correct frontmatter and allowed-tools
- Lifecycle follows standard 9-stage pattern matching skill-founder-implement
- Delegation context passes output_dir, template palette, and forcing_data
- Routes to `deck-builder-agent` via Task tool

---

### Phase 3: Update manifest.json, index-entries.json, and EXTENSION.md [COMPLETED]

**Goal**: Register the new agent and skill in the founder extension's configuration files

**Tasks**:
- [ ] Update `founder/manifest.json`:
  - Add `"deck-builder-agent.md"` to `provides.agents` array
  - Add `"skill-deck-implement"` to `provides.skills` array
  - Change `routing.implement["founder:deck"]` from `"skill-founder-implement"` to `"skill-deck-implement"`
- [ ] Update `founder/index-entries.json`:
  - Add `deck-builder-agent` to `agents` arrays of relevant existing entries (deck template entries, pitch-deck-structure, touying-pitch-deck-template, yc-compliance-checklist)
  - Add new entries if needed for deck-builder-specific context
- [ ] Update `founder/EXTENSION.md`:
  - Add row to skill-agent mapping table: `skill-deck-implement | deck-builder-agent | Pitch deck typst generation from plan`

**Timing**: 0.5 hours

**Files to modify**:
- `.claude/extensions/founder/manifest.json` - UPDATE routing and provides
- `.claude/extensions/founder/index-entries.json` - UPDATE agent references
- `.claude/extensions/founder/EXTENSION.md` - UPDATE skill-agent table

**Verification**:
- `manifest.json` routing shows `"founder:deck": "skill-deck-implement"` in implement section
- `manifest.json` provides arrays include new agent and skill
- `index-entries.json` has `deck-builder-agent` in appropriate load_when.agents arrays
- `EXTENSION.md` table includes the new skill-deck-implement row

---

### Phase 4: Integration Validation [COMPLETED]

**Goal**: Verify the complete deck builder pipeline is correctly wired and all files are consistent

**Tasks**:
- [ ] Verify routing chain: `/implement N` (deck task) -> skill-deck-implement -> deck-builder-agent
- [ ] Verify all file cross-references are consistent (agent name in skill, skill name in manifest, etc.)
- [ ] Verify context references in agent point to existing files (deck templates, present extension patterns)
- [ ] Verify the agent handles all 5 template variants (dark-blue, minimal-light, premium-dark, growth-green, professional-blue)
- [ ] Verify output path convention: `strategy/{slug}-deck.typ` and `strategy/{slug}-deck.pdf`
- [ ] Verify non-blocking compilation pattern
- [ ] Verify resume support handles partial `.typ` files
- [ ] Review for consistency with existing founder agents (naming, structure, error handling)

**Timing**: 0.25 hours

**Files to modify**:
- (Read-only verification, no file changes expected)
- Minor edits to any files if inconsistencies are found

**Verification**:
- All cross-references resolve correctly
- No broken context file paths
- Routing chain complete from command to agent
- Agent, skill, manifest, index, and extension doc are all mutually consistent

## Testing & Validation

- [ ] `deck-builder-agent.md` exists at `.claude/extensions/founder/agents/deck-builder-agent.md`
- [ ] `skill-deck-implement/SKILL.md` exists at `.claude/extensions/founder/skills/skill-deck-implement/SKILL.md`
- [ ] `manifest.json` routing for `founder:deck` implement points to `skill-deck-implement`
- [ ] `manifest.json` provides lists include new agent and skill
- [ ] `index-entries.json` references `deck-builder-agent` in deck-related entries
- [ ] `EXTENSION.md` skill-agent table includes `skill-deck-implement` row
- [ ] Agent handles all 5 templates with correct path construction
- [ ] Agent generates `.typ` output to `strategy/` directory
- [ ] Agent uses non-blocking `typst compile` for PDF generation
- [ ] Skill follows standard 9-stage lifecycle

## Artifacts & Outputs

- `.claude/extensions/founder/agents/deck-builder-agent.md` - New agent definition
- `.claude/extensions/founder/skills/skill-deck-implement/SKILL.md` - New skill definition
- `.claude/extensions/founder/manifest.json` - Updated routing and provides
- `.claude/extensions/founder/index-entries.json` - Updated agent references
- `.claude/extensions/founder/EXTENSION.md` - Updated documentation

## Rollback/Contingency

If implementation fails:
1. Remove `founder/agents/deck-builder-agent.md`
2. Remove `founder/skills/skill-deck-implement/` directory
3. Revert `manifest.json` routing change (restore `"founder:deck": "skill-founder-implement"`)
4. Revert `index-entries.json` agent reference additions
5. Revert `EXTENSION.md` table row addition
6. All changes are in `.claude/extensions/founder/` so a targeted `git checkout` of that directory suffices
