# Implementation Plan: Slidev Deck Library System

- **Task**: 345 - Port /deck command-skill-agent from Typst to Slidev
- **Status**: [NOT STARTED]
- **Effort**: 8 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_slidev-port-research.md, reports/02_slidev-standards.md, reports/03_refactor-analysis.md, reports/03_slidev-system-design.md, reports/05_deck-library-system.md
- **Artifacts**: plans/03_slidev-system-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: founder:deck
- **Lean Intent**: false

## Overview

This plan replaces the original 5-phase Typst-to-Slidev port plan (02_implementation-plan.md) with a richer library-based architecture designed in report 03_slidev-system-design.md. The system centers on a reusable content library at `.context/deck/` with 6 subdirectories (themes, patterns, animations, styles, contents, components) indexed by a master `index.json`. The deck-planner-agent is redesigned as a 5-step interactive workflow querying this library. The deck-builder-agent assembles slides from library imports rather than populating monolithic templates. All Typst/Touying references are removed and replaced with Slidev conventions. The core workflow (forcing questions, YC 10-slide structure, 4 deck modes, 3-question planning flow, early metadata, non-blocking compilation) is fully preserved.

### Research Integration

Five research reports and one prior plan were integrated:
- **Report 01** (slidev-port-research): System architecture analysis, Typst-to-Slidev mapping, file create/modify/delete lists
- **Report 02** (slidev-standards): Comprehensive Slidev syntax reference (headmatter, frontmatter, layouts, animations, themes, components, export)
- **Report 03** (refactor-analysis): File-by-file change specification with exact line references, dependency graph
- **Report 03** (slidev-system-design): Complete library architecture, index schema, planner workflow, builder integration, content format specification -- primary input for this plan
- **Report 05** (deck-library-system): Team research on reusable library protocols, animations, styling presets, index schema, 6-step workflow
- **Plan 02** (implementation-plan): Original 5-phase port plan -- superseded by this plan

## Goals & Non-Goals

**Goals**:
- Create `.context/deck/` library with themes, patterns, animations, styles, contents, and components subdirectories
- Populate `index.json` master index with controlled vocabularies and agent query patterns
- Create 5 theme JSON configs, 5 pattern JSON definitions, 6 animation docs, 9 CSS presets, ~20 content markdown snippets, 4 Vue components
- Rewrite deck-planner-agent for 5-step library-aware interactive workflow (pattern, theme, content, ordering, plan generation)
- Rewrite deck-builder-agent for library-based assembly with slot filling, style composition, and library write-back
- Create `slidev-deck-template.md` pattern file replacing `touying-pitch-deck-template.md`
- Update skills, command, and index entries for Slidev terminology
- Delete all obsolete Typst files

**Non-Goals**:
- Custom Slidev theme package creation (use seriph with themeConfig customization)
- Installation of Slidev CLI or playwright-chromium (handled by non-blocking pattern)
- Changes to forcing questions workflow, 3-question planning flow, or YC 10-slide content rules
- Concurrent Typst and Slidev output support
- Full population of every possible content variant (library grows organically via write-back)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Library infrastructure too complex for initial implementation | H | M | Seed with minimal viable set: 5 themes, 2 patterns (YC + lightning), ~20 content files; grow via write-back |
| Content library paths break when deck output directory varies | M | M | Use direct copy (Method 2) as default import; `src` import only for zero-customization boilerplate |
| 5-step planner workflow feels heavy for quick decks | M | M | `--quick` flag skips steps 1-2 using YC 10-slide + dark-blue defaults |
| `slidev export` requires playwright-chromium | L | H | Same non-blocking pattern as Typst: .md output always valid, PDF optional |
| Vue components require Slidev project initialization | M | M | Builder generates minimal `package.json` with `@slidev/cli` dependency |
| CSS preset composition conflicts between themes | M | L | Presets use namespaced CSS variables; specificity rules documented |
| Breaking change for in-progress deck tasks | H | M | Complete or abandon existing deck tasks before merging |
| index.json grows unbounded with duplicate content | M | L | Builder checks for similar content before write-back; periodic dedup |

## Implementation Phases

### Phase 1: Library Foundation -- Directory Structure and Index [COMPLETED]

**Goal**: Create the `.context/deck/` directory structure, master `index.json`, and update `.context/index.json` to register the library. This phase produces the foundation that all subsequent phases depend on.

**Tasks**:
- [ ] Create directory tree: `.context/deck/{themes,patterns,animations,styles/colors,styles/typography,styles/textures,contents/cover,contents/problem,contents/solution,contents/traction,contents/market,contents/team,contents/ask,contents/business-model,contents/why-us-now,contents/closing,contents/appendix,components}`
- [ ] Create `.context/deck/index.json` with version, generated timestamp, description, categories object (6 categories), and entries array (initially empty -- populated in Phase 2)
- [ ] Update `.context/index.json` to add deck library entry with `load_when` targeting `deck-planner-agent`, `deck-builder-agent`, language `founder`, command `/deck`

**Timing**: 30 minutes

**Files to create/modify**:
- `.context/deck/index.json` -- CREATE (skeleton with categories, empty entries)
- `.context/index.json` -- MODIFY (add deck library entry)

**Verification**:
- `jq . .context/deck/index.json` parses without error
- `jq . .context/index.json` parses without error
- All 18+ subdirectories exist under `.context/deck/`
- `.context/index.json` contains entry for `deck/index.json`

---

### Phase 2: Library Content -- Themes, Patterns, Styles, Animations, Components [COMPLETED]

**Goal**: Populate the library with all non-content resources (themes, patterns, CSS presets, animation docs, Vue components) and add their index entries. This phase depends on Phase 1 for directory structure.

**Tasks**:
- [ ] Create 5 theme JSON files in `.context/deck/themes/`:
  - `dark-blue.json` -- seriph + dark + navy palette (#60a5fa primary, #1e293b bg, #e2e8f0 text)
  - `minimal-light.json` -- seriph + light + clean (#3182ce primary, #fff bg, #2d3748 text)
  - `premium-dark.json` -- seriph + dark + gold (#d4a574 primary, #0f0f1a bg, #e8e0d4 text)
  - `growth-green.json` -- seriph + light + green (#38a169 primary, #f0fdf4 bg, #047857 text)
  - `professional-blue.json` -- seriph + light + corporate (#2b6cb0 primary, #fff bg, #1a365d text)
- [ ] Create 5 pattern JSON files in `.context/deck/patterns/`:
  - `yc-10-slide.json` -- 10-slide investor pitch with slide_sequence, constraints, appendix_suggestions
  - `lightning-5-slide.json` -- 5-slide lightning talk
  - `product-demo.json` -- 8-12 slide product demo
  - `investor-update.json` -- 8-slide quarterly update
  - `partnership-proposal.json` -- 8-slide partnership pitch
- [ ] Create 6 animation markdown files in `.context/deck/animations/`:
  - `fade-in.md`, `slide-in-below.md`, `metric-cascade.md`, `rough-marks.md`, `staggered-list.md`, `scale-in-pop.md`
- [ ] Create 4 color CSS presets in `.context/deck/styles/colors/`:
  - `dark-blue-navy.css`, `dark-gold-premium.css`, `light-green-growth.css`, `light-blue-corp.css`
- [ ] Create 3 typography CSS presets in `.context/deck/styles/typography/`:
  - `montserrat-inter.css`, `playfair-inter.css`, `inter-only.css`
- [ ] Create 2 texture CSS presets in `.context/deck/styles/textures/`:
  - `grid-overlay.css`, `noise-grain.css`
- [ ] Create 4 Vue components in `.context/deck/components/`:
  - `MetricCard.vue` (value, label, delay, color props)
  - `TeamMember.vue` (name, role, bio, photo, delay props)
  - `TimelineItem.vue` (date, label, description, status props)
  - `ComparisonCol.vue` (title, points, color, highlight props)
- [ ] Add all entries to `.context/deck/index.json` entries array (5 themes + 5 patterns + 6 animations + 9 styles + 4 components = 29 entries)

**Timing**: 2 hours

**Files to create**:
- `.context/deck/themes/dark-blue.json` -- CREATE
- `.context/deck/themes/minimal-light.json` -- CREATE
- `.context/deck/themes/premium-dark.json` -- CREATE
- `.context/deck/themes/growth-green.json` -- CREATE
- `.context/deck/themes/professional-blue.json` -- CREATE
- `.context/deck/patterns/yc-10-slide.json` -- CREATE
- `.context/deck/patterns/lightning-5-slide.json` -- CREATE
- `.context/deck/patterns/product-demo.json` -- CREATE
- `.context/deck/patterns/investor-update.json` -- CREATE
- `.context/deck/patterns/partnership-proposal.json` -- CREATE
- `.context/deck/animations/fade-in.md` -- CREATE
- `.context/deck/animations/slide-in-below.md` -- CREATE
- `.context/deck/animations/metric-cascade.md` -- CREATE
- `.context/deck/animations/rough-marks.md` -- CREATE
- `.context/deck/animations/staggered-list.md` -- CREATE
- `.context/deck/animations/scale-in-pop.md` -- CREATE
- `.context/deck/styles/colors/dark-blue-navy.css` -- CREATE
- `.context/deck/styles/colors/dark-gold-premium.css` -- CREATE
- `.context/deck/styles/colors/light-green-growth.css` -- CREATE
- `.context/deck/styles/colors/light-blue-corp.css` -- CREATE
- `.context/deck/styles/typography/montserrat-inter.css` -- CREATE
- `.context/deck/styles/typography/playfair-inter.css` -- CREATE
- `.context/deck/styles/typography/inter-only.css` -- CREATE
- `.context/deck/styles/textures/grid-overlay.css` -- CREATE
- `.context/deck/styles/textures/noise-grain.css` -- CREATE
- `.context/deck/components/MetricCard.vue` -- CREATE
- `.context/deck/components/TeamMember.vue` -- CREATE
- `.context/deck/components/TimelineItem.vue` -- CREATE
- `.context/deck/components/ComparisonCol.vue` -- CREATE
- `.context/deck/index.json` -- MODIFY (add 29 entries)

**Verification**:
- All 29 files exist on disk
- `jq '.entries | length' .context/deck/index.json` returns 29
- Each theme JSON has `headmatter`, `style_presets`, `css_variables`, `scoped_css_template` fields
- Each pattern JSON has `slide_sequence` array with position, slide_type, required, default_content fields
- Each animation .md has syntax examples
- Each CSS preset defines CSS custom properties with `--slidev-` namespace
- Each Vue component has props defined and renders with v-motion/v-click directives

---

### Phase 3: Content Library -- Reusable Slide Markdown Snippets [COMPLETED]

**Goal**: Populate `.context/deck/contents/` with ~20 reusable slide markdown snippets following the content file format (header comment block with CONTENT/SLIDE_TYPE/LAYOUT/COMPATIBLE_MODES/CONTENT_SLOTS/ANIMATIONS/IMPORT metadata, then Slidev markdown with `[SLOT: ...]` markers). Add content entries to index.json.

**Tasks**:
- [ ] Create cover slides (2 files):
  - `contents/cover/cover-standard.md` -- layout: cover, slots: company_name, tagline, funding_round, date
  - `contents/cover/cover-hero.md` -- layout: cover with full-bleed image variant
- [ ] Create problem slides (2 files):
  - `contents/problem/problem-statement.md` -- layout: statement, bold single sentence + 3 evidence v-clicks
  - `contents/problem/problem-story.md` -- layout: default, narrative problem framing
- [ ] Create solution slides (2 files):
  - `contents/solution/solution-two-col.md` -- layout: two-cols, benefits left + mechanism right
  - `contents/solution/solution-demo.md` -- layout: image-right, solution with screenshot callout
- [ ] Create traction slides (2 files):
  - `contents/traction/traction-metrics.md` -- layout: fact, 3-metric AutoFitText with v-clicks
  - `contents/traction/traction-chart.md` -- layout: default, bar chart growth visualization
- [ ] Create market slides (2 files):
  - `contents/market/market-tam-sam-som.md` -- layout: default, Mermaid TAM/SAM/SOM diagram
  - `contents/market/market-narrative.md` -- layout: default, text-based market sizing
- [ ] Create team slides (2 files):
  - `contents/team/team-two-col.md` -- layout: two-cols, two-column founder grid
  - `contents/team/team-grid.md` -- layout: default, multi-member grid
- [ ] Create ask slides (2 files):
  - `contents/ask/ask-centered.md` -- layout: center, raise amount + allocation breakdown
  - `contents/ask/ask-milestone.md` -- layout: default, raise + milestone timeline
- [ ] Create business-model slides (2 files):
  - `contents/business-model/biz-model-pricing.md` -- layout: default, revenue model + unit economics
  - `contents/business-model/biz-model-saas.md` -- layout: default, SaaS-specific metrics
- [ ] Create why-us-now slides (2 files):
  - `contents/why-us-now/why-us-now-split.md` -- layout: two-cols, Why Us left + Why Now right
  - `contents/why-us-now/why-us-moat.md` -- layout: default, technical moat emphasis
- [ ] Create closing slides (2 files):
  - `contents/closing/closing-standard.md` -- layout: end, company name + contact
  - `contents/closing/closing-cta.md` -- layout: center, call-to-action with next steps
- [ ] Create appendix slides (3 files):
  - `contents/appendix/appendix-financials.md` -- layout: default, financial projections
  - `contents/appendix/appendix-competition.md` -- layout: default, competitive landscape
  - `contents/appendix/appendix-roadmap.md` -- layout: default, product roadmap timeline
- [ ] Add ~23 content entries to `.context/deck/index.json` with content_slots metadata

**Timing**: 2 hours

**Files to create**:
- 23 markdown files in `.context/deck/contents/` (listed above)
- `.context/deck/index.json` -- MODIFY (add ~23 content entries, total entries ~52)

**Verification**:
- All 23 content files exist
- Each file has the header comment block with CONTENT, SLIDE_TYPE, LAYOUT, COMPATIBLE_MODES, CONTENT_SLOTS, ANIMATIONS, IMPORT fields
- Each file contains valid Slidev markdown with `---` separator, layout frontmatter, and `[SLOT: ...]` markers
- Each file includes a `<!-- Speaker: ... -->` note
- `jq '.entries | length' .context/deck/index.json` returns ~52
- Content entries have `content_slots` arrays matching the `[SLOT: ...]` markers in their files

---

### Phase 4: Extension Context -- Slidev Pattern File [NOT STARTED]

**Goal**: Create the new `slidev-deck-template.md` pattern file replacing `touying-pitch-deck-template.md`, and update `pitch-deck-structure.md` cross-references. These files live in the extension context layer (`.claude/extensions/founder/context/project/founder/patterns/`).

**Tasks**:
- [ ] Create `patterns/slidev-deck-template.md` covering:
  - Framework overview (Slidev markdown-based, seriph theme, scoped CSS)
  - Annotated full template example showing headmatter, slide separators, layouts, v-clicks, speaker notes
  - Customization guide (themeConfig, colorSchema, fonts, scoped CSS, `<style>` blocks)
  - Slide separator rules (`---` with blank lines)
  - Speaker notes syntax (`<!-- -->` comments with Speaker: prefix)
  - Two-column layout syntax (`::right::` slot)
  - Animation guidelines (`<v-clicks>`, `v-mark`, `v-motion`, `v-click` with depth/every)
  - Component usage (AutoFitText, MetricCard, TeamMember)
  - Library integration patterns (how to import from `.context/deck/`)
  - Export commands (`slidev export`)
  - Design checklist and prohibited patterns
- [ ] Update `patterns/pitch-deck-structure.md`:
  - Replace Typst Implementation subsection with Slidev equivalent
  - Update cross-reference from `touying-pitch-deck-template.md` to `slidev-deck-template.md`
  - Add reference to `.context/deck/` library

**Timing**: 1 hour

**Files to create/modify** (relative to `.claude/extensions/founder/context/project/founder/`):
- `patterns/slidev-deck-template.md` -- CREATE (~250 lines)
- `patterns/pitch-deck-structure.md` -- MODIFY (replace Typst subsection + cross-reference)

**Verification**:
- `slidev-deck-template.md` exists with all sections listed above
- `pitch-deck-structure.md` references `slidev-deck-template.md` (not `touying-pitch-deck-template.md`)
- `pitch-deck-structure.md` mentions `.context/deck/` library
- No Typst/touying references remain in either file

---

### Phase 5: Agent Rewrites [NOT STARTED]

**Goal**: Rewrite the three deck agents for the library-based Slidev architecture. The planner gets the 5-step library-aware workflow. The builder gets library-based assembly with slot filling and write-back. The research agent gets minor updates.

**Tasks**:
- [ ] Rewrite `deck-planner-agent.md`:
  - Replace context references: `touying-pitch-deck-template.md` -> `slidev-deck-template.md`
  - Add context reference for `.context/deck/index.json` (library access)
  - Replace 3-step workflow with 5-step flow:
    - Step 1: Pattern selection (query index.json for patterns by deck_mode, AskUserQuestion single select)
    - Step 2: Theme selection (query index.json for all themes, AskUserQuestion single select with color preview)
    - Step 3: Content selection (per slide position, query matching content by slide_type, AskUserQuestion multi select with NEW option, main vs appendix assignment)
    - Step 4: Slide ordering (AskUserQuestion single select from strategy presets)
    - Step 5: Plan generation with import map, style composition, animation assignments
  - Add `--quick` flag bypass logic (skip steps 1-2, use YC 10-slide + dark-blue defaults)
  - Update plan output format to include Deck Configuration section with content_manifest, import map, style_presets, animation assignments
  - Update intermediate state (partial_progress) to save after each step
  - Remove all Typst template path references
  - Remove all `.typ` file extension references
- [ ] Rewrite `deck-builder-agent.md`:
  - Replace frontmatter description: "typst" -> "Slidev"
  - Replace all context references: remove 5 `.typ` template refs, add library refs
  - Add context reference for `slidev-deck-template.md`
  - Rewrite Stage 2.5 tool detection: `typst` -> `slidev` CLI + `playwright-chromium` check
  - Rewrite Stage 3 resume: `.typ` -> `.md` detection
  - Rewrite Stage 4 completely for library-based assembly:
    - 4a: Load theme config from `.context/deck/themes/{theme_id}.json`
    - 4b: Generate headmatter from theme + task metadata
    - 4c: For each slide in slide_order, read content from library, replace `[SLOT:]` markers, add import comments
    - 4d: Apply animations per pattern assignments
    - 4e: Add appendix slides with `hideInToc: true`
    - 4f: Write complete `slides.md`
  - Add Stage 5: Style assembly (generate `styles/index.css`, copy CSS presets)
  - Add Stage 6: Component copy (from `.context/deck/components/` to output)
  - Add Stage 7: Library write-back (generalize new content, write to library, update index.json)
  - Rewrite Stage 8: `typst compile` -> `slidev export slides.md --output {slug}-deck.pdf`
  - Update output directory structure: `strategy/{slug}-deck/` with `slides.md`, `styles/`, `components/`, `public/`
  - Update Critical Requirements: replace Typst rules with Slidev equivalents
- [ ] Update `deck-research-agent.md`:
  - Replace context reference: `touying-pitch-deck-template.md` -> `slidev-deck-template.md`
  - Replace "final Typst pitch deck" with "final Slidev pitch deck" in Next Steps

**Timing**: 2 hours

**Files to modify** (relative to `.claude/extensions/founder/`):
- `agents/deck-planner-agent.md` -- MODIFY (heavy rewrite: 5-step workflow, library queries)
- `agents/deck-builder-agent.md` -- MODIFY (heavy rewrite: library assembly, new stages 5-7)
- `agents/deck-research-agent.md` -- MODIFY (2 string replacements)

**Verification**:
- No remaining references to `touying`, `typst`, or `.typ` in any of the 3 agent files
- Planner agent references `.context/deck/index.json` and has 5-step flow documentation
- Planner agent includes `--quick` flag documentation
- Builder agent has Stages 4-7 for library assembly, style, components, write-back
- Builder agent uses `slidev export` for PDF generation
- Builder agent output goes to `strategy/{slug}-deck/slides.md` (not `.typ`)
- Research agent references `slidev-deck-template.md`

---

### Phase 6: Skills, Command, Index Updates and Typst Cleanup [NOT STARTED]

**Goal**: Update skill wrappers, command entry point, and extension index entries for Slidev. Delete all obsolete Typst files. This is the final phase because it depends on all new files and agent rewrites being in place.

**Tasks**:
- [ ] Update `skills/skill-deck-plan/SKILL.md`:
  - Change "Typst pitch deck" to "Slidev pitch deck" in return message
- [ ] Update `skills/skill-deck-implement/SKILL.md`:
  - Update frontmatter description to "Slidev pitch deck generation"
  - Update delegation context descriptions
  - Change template references from `.typ` to `.md`
  - Change "typst compile" to "slidev export"
  - Rename `typst_generated` metadata field to `pdf_generated`
  - Update error handling section terminology
- [ ] Update `commands/deck.md`:
  - Change "final Typst pitch deck" to "final Slidev pitch deck" in Next Steps and Gate Out
  - Remove `.typ$` from file path detection regex
  - Update workflow summary and Output Artifacts section
- [ ] Update `index-entries.json`:
  - Replace `project/founder/patterns/touying-pitch-deck-template.md` entry with `project/founder/patterns/slidev-deck-template.md` (updated summary, line_count)
  - Replace 5 template entries: `templates/typst/deck/deck-{palette}.typ` paths removed entirely (no Slidev templates in extension context -- library replaces them)
  - Add note that deck content now lives in `.context/deck/` (project context layer)
  - Verify all `load_when` fields are correct
- [ ] Delete obsolete Typst files (relative to `.claude/extensions/founder/context/project/founder/`):
  - Delete `patterns/touying-pitch-deck-template.md`
  - Delete `templates/typst/deck/deck-dark-blue.typ`
  - Delete `templates/typst/deck/deck-minimal-light.typ`
  - Delete `templates/typst/deck/deck-premium-dark.typ`
  - Delete `templates/typst/deck/deck-growth-green.typ`
  - Delete `templates/typst/deck/deck-professional-blue.typ`
  - Remove `templates/typst/deck/` directory (do NOT remove `templates/typst/` parent -- it has non-deck templates)
- [ ] Run verification greps to confirm no stale references remain

**Timing**: 1 hour

**Files to modify** (relative to `.claude/extensions/founder/`):
- `skills/skill-deck-plan/SKILL.md` -- MODIFY (1 string replacement)
- `skills/skill-deck-implement/SKILL.md` -- MODIFY (~10 changes)
- `commands/deck.md` -- MODIFY (~5 string replacements)
- `index-entries.json` -- MODIFY (remove/replace 6 entries)

**Files to delete** (relative to `.claude/extensions/founder/context/project/founder/`):
- `patterns/touying-pitch-deck-template.md` -- DELETE
- `templates/typst/deck/deck-dark-blue.typ` -- DELETE
- `templates/typst/deck/deck-minimal-light.typ` -- DELETE
- `templates/typst/deck/deck-premium-dark.typ` -- DELETE
- `templates/typst/deck/deck-growth-green.typ` -- DELETE
- `templates/typst/deck/deck-professional-blue.typ` -- DELETE
- `templates/typst/deck/` -- REMOVE directory

**Verification**:
- `grep -r "touying" .claude/extensions/founder/` returns no results
- `grep -r "\.typ" .claude/extensions/founder/` returns no deck-related hits (only non-deck Typst references remain)
- `grep -r "typst compile" .claude/extensions/founder/` returns no deck-related hits
- `grep -r "templates/typst/deck/" .claude/extensions/founder/` returns no results
- `jq . .claude/extensions/founder/index-entries.json` parses without error
- `ls .claude/extensions/founder/context/project/founder/templates/typst/deck/` returns "No such file or directory"
- Other `templates/typst/` content (strategy-template.typ, etc.) is unaffected
- No references to `typst_generated` remain (replaced by `pdf_generated`)

## Testing & Validation

- [ ] `.context/deck/index.json` parses with `jq` and contains ~52 entries across 6 categories
- [ ] All 5 theme JSONs have `headmatter`, `style_presets`, `css_variables`, `scoped_css_template` fields
- [ ] All 5 pattern JSONs have `slide_sequence` arrays with correct slide_type values from controlled vocabulary
- [ ] All ~23 content files have header comment blocks with required metadata fields
- [ ] All content `[SLOT: ...]` markers match the `content_slots` in their index entry
- [ ] `slidev-deck-template.md` covers headmatter, layouts, animations, components, export, library integration
- [ ] `pitch-deck-structure.md` references Slidev (not Typst)
- [ ] No remaining references to `touying`, `typst compile`, or `.typ` in deck-related agent/skill/command files
- [ ] All 6 deleted Typst files are gone; `templates/typst/deck/` directory removed
- [ ] `index-entries.json` has no stale paths (all entries point to existing files)
- [ ] `.context/index.json` has deck library entry
- [ ] The `/deck` command flow documentation still describes the complete forcing questions -> research -> plan -> implement pipeline
- [ ] Builder agent documents library write-back mechanism (generalize + save new content)
- [ ] Planner agent documents `--quick` flag bypass

## Artifacts & Outputs

- `specs/345_port_deck_typst_to_slidev/plans/03_slidev-system-plan.md` (this file)
- `.context/deck/` library directory with ~55 files across 6 subdirectories
- `.context/deck/index.json` master index with ~52 entries
- 1 new pattern file: `patterns/slidev-deck-template.md`
- 3 modified agent files (planner heavy rewrite, builder heavy rewrite, research minor)
- 2 modified skill files, 1 modified command file
- 1 modified index-entries.json
- 1 modified `.context/index.json`
- 1 modified `patterns/pitch-deck-structure.md`
- 7 deleted Typst files + 1 removed directory

## Rollback/Contingency

All changes span two directory trees: `.context/deck/` (new library, entirely new) and `.claude/extensions/founder/` (modified agents/skills/command, deleted Typst files).

1. **Full rollback**: `git revert` implementation commits in reverse order restores all files
2. **Phase 5 deletions**: Recoverable via git history
3. **Partial failure safety**: If Phases 1-3 succeed but Phase 5 fails, the library exists but agents still point to Typst -- system remains functional on old path. If Phase 5 succeeds but Phase 6 fails, agents reference library but skills/command still say Typst -- functional but cosmetically inconsistent
4. **Critical dependency**: Phases 1-3 (library) must complete before Phase 5 (agent rewrites) because agents will reference library paths
5. **In-progress deck tasks**: Must be completed or abandoned before merging to avoid broken `.typ` artifact references
