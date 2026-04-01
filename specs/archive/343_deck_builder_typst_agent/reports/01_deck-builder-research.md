# Research Report: Task #343

**Task**: 343 - Deck builder typst agent
**Started**: 2026-03-31T22:00:00Z
**Completed**: 2026-03-31T22:30:00Z
**Effort**: Medium
**Dependencies**: Task 340 (COMPLETED), Task 342 (IN PROGRESS)
**Sources/Inputs**: Codebase exploration (founder extension, present extension, core agent system)
**Artifacts**: specs/343_deck_builder_typst_agent/reports/01_deck-builder-research.md
**Standards**: report-format.md

## Executive Summary

- The deck builder needs 3 files: `deck-builder-agent.md`, `skill-deck-implement/SKILL.md`, and a manifest.json routing update
- Templates from task 340 use `[TODO:]` markers as substitution points, with 5 shared parameters (company-name, company-subtitle, author-name, funding-round, funding-date) and touying 0.6.3
- The existing `founder-implement-agent` + `skill-founder-implement` provide the canonical pattern for a founder implementation agent/skill pair
- The `deck-research-agent` output (slide-mapped research report with 10 slides) serves as the primary content source
- Output should go to `strategy/{slug}-deck.typ` and `strategy/{slug}-deck.pdf`
- Manifest routing must override `founder:deck` in the implement section only (from `skill-founder-implement` to `skill-deck-implement`)

## Context and Scope

Task 343 creates the "deck builder" -- the implementation agent that takes a deck plan and generates a complete Typst pitch deck from the task 340 templates. This sits at the end of the `/deck` workflow:

```
/deck "description" -> task created with forcing_data
/research N         -> deck-research-agent synthesizes materials to 10-slide report
/plan N             -> founder-plan-agent creates plan (shared planner)
/implement N        -> deck-builder-agent generates .typ file from plan + templates
```

The key challenge: the `founder:deck` implement routing currently goes to `skill-founder-implement` (the generic founder implementer). Task 343 overrides this to `skill-deck-implement`, which routes to `deck-builder-agent` -- a specialized agent that understands typst deck templates.

## Findings

### 1. Typst Deck Templates (Task 340)

Five templates created in `founder/context/project/founder/templates/typst/deck/`:

| Template | File | Theme |
|----------|------|-------|
| dark-blue (PRIMARY) | `deck-dark-blue.typ` | Slate 800 bg, Blue 400 accent |
| minimal-light | `deck-minimal-light.typ` | White bg, charcoal text |
| premium-dark | `deck-premium-dark.typ` | Near-black bg, gold accent |
| growth-green | `deck-growth-green.typ` | Light green bg, emerald accent |
| professional-blue | `deck-professional-blue.typ` | Navy bg, sky blue accent |

**Template Structure** (all 5 identical):

1. **Parameters Block** (lines 17-23): Five `#let` variables that the builder must substitute:
   - `company-name`, `company-subtitle`, `author-name`, `funding-round`, `funding-date`

2. **Palette Block** (lines 25-30): Five color variables:
   - `palette-primary`, `palette-secondary`, `palette-accent`, `palette-bg`, `palette-text`

3. **Theme Setup** (lines 32-51): touying `simple-theme.with()` configuration using palette colors

4. **Typography** (lines 54-66): Font setup with fallbacks (e.g., Montserrat -> Liberation Sans)

5. **Comment Patterns** (lines 67-97): Documented sizes, spacing rhythm, card/table patterns

6. **10 Slides** (lines 99-401): Each with `[TODO:]` markers for content substitution:
   - Slide 1: Title (company-name, subtitle, tagline, funding info)
   - Slide 2: Problem (pain point, evidence, cost of inaction)
   - Slide 3: Solution (description, 2 features in grid)
   - Slide 4: Traction (summary, 3 key metrics)
   - Slide 5: Why Us / Why Now (2-column grid)
   - Slide 6: Business Model (revenue, unit economics, expansion)
   - Slide 7: Market Opportunity (TAM/SAM/SOM with source)
   - Slide 8: Team (2-founder grid with bios)
   - Slide 9: The Ask (amount, 3 milestones, commitments)
   - Slide 10: Closing (company name, tagline, contact)

7. **Appendix Comments** (lines 402-412): Instructions for optional appendix slides

**Key Design Decisions**:
- All templates use `@preview/touying:0.6.3` and `themes.simple`
- Dollar signs in `[TODO:]` are escaped with backslash for typst
- All have `#speaker-note[...]` on every slide
- Cross-template: identical parameter names, margins, leading, list markers
- 16:9 aspect ratio, YC-compliant font sizes (48pt h1, 40pt h2, 32pt body, 24pt min)

### 2. Deck Research Agent Output Format

The `deck-research-agent` creates a research report with this structure:

```markdown
## Slide Content Analysis

### 1. Title Slide
- **Company Name**: {extracted or [MISSING]}
- **One-liner**: {extracted or [MISSING]}
- **Founders**: {extracted or [MISSING]}

### 2. Problem
- **Pain Point**: {extracted or [MISSING]}
...

(continues for all 10 slides)
```

The builder agent must:
1. Read the research report to get slide-mapped content
2. Read the plan to get phase structure and template selection
3. Map research content onto template `[TODO:]` markers

### 3. Existing Agent/Skill Patterns

**founder-implement-agent** (canonical pattern):
- Frontmatter: `name`, `description`
- Stages: 0 (early metadata) -> 1 (parse context) -> 2 (load plan + research) -> 2.5 (typst check) -> 3 (resume detect) -> 4 (load template) -> 5 (execute phases) -> 6 (write metadata)
- Key patterns: self-contained typst generation (inline all styles), non-blocking Phase 5 (PDF compile)
- Output: `founder/{type}-{slug}.typ` and `founder/{type}-{slug}.pdf`

**skill-founder-implement** (canonical skill pattern):
- Frontmatter: `name`, `description`, `allowed-tools: Task, Bash, Edit, Read, Write`
- 9-stage lifecycle: validate -> preflight status -> postflight marker -> context prep -> invoke agent (Task tool) -> read metadata -> postflight status -> git commit -> cleanup
- Uses `output_dir: "strategy/"` in delegation context

**skill-deck-research** (deck-specific skill):
- Same 11-stage lifecycle as other founder skills
- Routes to `deck-research-agent` via Task tool
- Passes `forcing_data` from task metadata

### 4. Manifest Routing

Current `manifest.json` routing for `founder:deck`:
```json
"implement": {
  "founder:deck": "skill-founder-implement"
}
```

Must change to:
```json
"implement": {
  "founder:deck": "skill-deck-implement"
}
```

This is the ONLY routing change needed. The `research` and `plan` routes remain as-is.

### 5. Plan Format for Deck Tasks

The `founder-plan-agent` creates plans for all founder tasks including decks. The plan will reference the deck research report and include phases. Based on the planner pattern, a deck plan will likely include:

- Phase 1: Template Selection and Configuration
- Phase 2: Slide Content Population
- Phase 3: Appendix Generation (if applicable)
- Phase 4: Typst Compilation and Validation

The builder agent needs to handle this phase structure with resume support.

### 6. Typst Compilation

Typst v0.14.2 is installed at `/run/current-system/sw/bin/typst`. Compilation command:

```bash
typst compile "strategy/{slug}-deck.typ" "strategy/{slug}-deck.pdf"
```

Key considerations:
- Templates import `@preview/touying:0.6.3` -- typst auto-downloads preview packages on first compile
- Font fallbacks are configured (Liberation Sans for Montserrat/Inter)
- Compilation from project root works since files are self-contained
- Dollar signs must be escaped in typst content

### 7. Output Location

Per task description: `strategy/{slug}-deck.typ` and `strategy/{slug}-deck.pdf`

This differs from the founder-implement-agent which outputs to `founder/`. The `strategy/` directory does not currently exist but will be created by the builder.

### 8. Index Entries Needed

The deck-builder-agent and skill-deck-implement need to be registered in `index-entries.json`. The existing deck-related entries reference `deck-agent` (from present extension) and `deck-research-agent`. New entries should add `deck-builder-agent` to template context load_when arrays.

## Recommendations

### File Set to Create

1. **`founder/agents/deck-builder-agent.md`** -- The implementation agent
   - Follow `founder-implement-agent.md` structure closely
   - Key difference: reads deck templates instead of strategy report templates
   - Substitutes `[TODO:]` markers with content from research report
   - Writes to `strategy/{slug}-deck.typ` instead of `founder/`
   - Compiles with `typst compile`

2. **`founder/skills/skill-deck-implement/SKILL.md`** -- The routing skill
   - Follow `skill-founder-implement/SKILL.md` structure
   - Routes to `deck-builder-agent` via Task tool
   - Same lifecycle: validate -> preflight -> invoke -> postflight -> commit

3. **`founder/manifest.json`** -- Routing update
   - Change `"founder:deck": "skill-founder-implement"` to `"founder:deck": "skill-deck-implement"` in the `implement` section
   - Add `"deck-builder-agent.md"` to `provides.agents`
   - Add `"skill-deck-implement"` to `provides.skills`

4. **`founder/index-entries.json`** -- Context entries
   - Add `deck-builder-agent` to deck template load_when arrays
   - Add entries for pitch-deck-structure.md, touying-pitch-deck-template.md, yc-compliance-checklist.md with deck-builder-agent in agents list

5. **`founder/EXTENSION.md`** -- Table update
   - Add row for `skill-deck-implement | deck-builder-agent | Pitch deck typst generation from plan`

### Agent Design: deck-builder-agent

**Core Logic**:

1. Parse delegation context (task_number, plan_path, template selection)
2. Load plan to get phase structure
3. Load research report to get slide-mapped content
4. Select template based on plan's style/palette specification
5. Read the selected template file
6. For each `[TODO:]` marker, substitute with research content
7. Set the 5 parameter variables (company-name, etc.) from research data
8. Write populated .typ file to `strategy/{slug}-deck.typ`
9. Generate optional appendix slides from research "Additional Content for Appendix" section
10. Compile to PDF with `typst compile`
11. Write implementation summary

**Template Selection Logic**:

The plan (from task 342's deck-planner) will specify which template to use. Default is `deck-dark-blue.typ`. The builder reads from:
```
.claude/extensions/founder/context/project/founder/templates/typst/deck/deck-{palette}.typ
```

**Content Substitution Strategy**:

Rather than find-and-replace `[TODO:]` markers (fragile), the builder should use the template as a structural guide and generate a complete new .typ file with content populated. This follows the pattern used by `founder-implement-agent` which generates self-contained typst files.

The builder should:
1. Read the template to understand the structure (parameters, palette, typography, slide structure)
2. Generate a new .typ file that replicates the template structure but with actual content
3. Keep all the template infrastructure (imports, theme setup, typography, comment patterns)
4. Replace `[TODO:]` content with research-extracted content
5. Where research has `[MISSING]` markers, keep `[TODO:]` in the generated file

**Phase Structure**:

- Phase 1: Template Selection and Parameter Configuration
- Phase 2: Slide Content Generation (10 main slides)
- Phase 3: Appendix Slide Generation (optional)
- Phase 4: Typst Compilation and YC Compliance Validation

Phase 4 (compilation) should be non-blocking, following the founder-implement-agent precedent.

## Decisions

- Output directory is `strategy/` (not `founder/`), matching the task description
- Template selection defaults to `deck-dark-blue.typ` (the PRIMARY template)
- The builder generates a complete new .typ file rather than doing string replacement on the template
- The skill uses the standard 9-stage lifecycle matching `skill-founder-implement`
- PDF compilation failure is non-blocking (same as founder-implement-agent Phase 5)
- The builder agent gets its own index entries in `index-entries.json`

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| Task 342 (deck planner) not yet complete -- plan format unknown | Builder should accept any plan format with flexible phase parsing; plan format will follow founder-plan-agent conventions |
| Template `[TODO:]` markers may vary slightly between templates | Builder generates complete file from template structure, not string-replace |
| Research report may have `[MISSING]` markers | Builder preserves `[TODO:]` for missing content, logs count |
| Typst compilation may fail (missing fonts, package download) | Non-blocking Phase 4; .typ source preserved; markdown summary fallback |
| The `strategy/` directory does not exist | Builder creates it via `mkdir -p strategy/` |
| Dollar sign escaping in typst | Templates already escape with backslash; builder must maintain this |

## Appendix

### Search Queries Used

- Glob: `.claude/extensions/founder/**/*` -- Found all founder extension files
- Glob: `.claude/extensions/present/**/*` -- Found present extension for deck-agent reference
- Glob: `specs/340_*/**/*` -- Found task 340 artifacts
- Read: All 5 deck templates, deck-research-agent, founder-implement-agent, skill-founder-implement, skill-deck-research, deck.md command, founder-plan-agent, manifest.json, index-entries.json, EXTENSION.md
- Grep: state.json for tasks 342/343 status
- Bash: `typst --version` to confirm installation

### Key File References

| File | Purpose |
|------|---------|
| `.claude/extensions/founder/agents/founder-implement-agent.md` | Primary implementation agent pattern |
| `.claude/extensions/founder/skills/skill-founder-implement/SKILL.md` | Primary implementation skill pattern |
| `.claude/extensions/founder/agents/deck-research-agent.md` | Research output format reference |
| `.claude/extensions/founder/context/project/founder/templates/typst/deck/deck-dark-blue.typ` | Primary template reference |
| `.claude/extensions/present/agents/deck-agent.md` | Standalone deck generation reference |
| `.claude/extensions/founder/manifest.json` | Routing configuration |
| `.claude/extensions/founder/index-entries.json` | Context discovery entries |
| `.claude/extensions/founder/EXTENSION.md` | Extension documentation |
| `specs/340_create_typst_deck_templates/summaries/02_typst-deck-templates-summary.md` | Template creation summary |
