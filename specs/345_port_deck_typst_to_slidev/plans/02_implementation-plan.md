# Implementation Plan: Port /deck from Typst to Slidev

- **Task**: 345 - Port /deck command-skill-agent from Typst to Slidev
- **Status**: [IMPLEMENTING]
- **Effort**: 6 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_slidev-port-research.md, reports/02_slidev-standards.md, reports/03_refactor-analysis.md
- **Artifacts**: plans/02_implementation-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: founder:deck
- **Lean Intent**: false

## Overview

Port the /deck command-skill-agent system from generating Typst/Touying pitch decks to Slidev markdown-based presentations. The system consists of 18 files across command, skills, agents, patterns, templates, and manifest/index layers. The refactoring replaces 5 `.typ` templates with 5 `.md` Slidev templates, creates a new Slidev pattern file replacing the Touying reference, rewrites the deck-builder-agent for Slidev markdown generation + `slidev export`, and updates all cross-references across skills, agents, and index entries. The core workflow (forcing questions, 3-phase research/plan/implement, YC 10-slide structure, 4 deck modes, early metadata, non-blocking compilation) is fully preserved.

### Research Integration

Three research reports were integrated:
- **Report 01** (slidev-port-research): System architecture analysis, Typst-to-Slidev mapping for templates/parameters/slides/typography/compilation, port strategy with file create/modify/delete lists
- **Report 02** (slidev-standards): Comprehensive Slidev syntax reference (1328 lines) covering headmatter, frontmatter, layouts, animations, themes, components, export -- used as the source of truth for new template content and builder agent generation rules
- **Report 03** (refactor-analysis): File-by-file change specification with exact line references, dependency graph, and 5-phase execution order -- used as the primary structural input for this plan

## Goals & Non-Goals

**Goals**:
- Replace all 5 Typst deck templates with Slidev markdown equivalents preserving the same palette names, color values, and [TODO:] marker structure
- Create a Slidev-specific pattern file replacing touying-pitch-deck-template.md with complete Slidev syntax reference
- Rewrite deck-builder-agent to emit Slidev markdown and run `slidev export` instead of `typst compile`
- Update all cross-references in agents, skills, command, and index-entries.json
- Delete obsolete Typst files after verification
- Maintain the complete /deck workflow end-to-end

**Non-Goals**:
- Custom Slidev theme creation (use built-in `seriph` theme with `themeConfig` customization)
- Installation of Slidev or playwright-chromium (handled by non-blocking pattern)
- Changes to the forcing questions workflow or 3-question planning flow
- Changes to the YC 10-slide content structure or validation rules
- Support for concurrent Typst and Slidev output

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Slidev `seriph` theme limitations for fine-grained styling | M | M | Each template includes scoped `<style>` blocks with exact hex values; theme ejection available if needed |
| `slidev export` requires playwright-chromium | L | H | Same non-blocking pattern as Typst: `.md` output always valid, PDF is optional |
| Font rendering differences between Typst and Slidev | L | M | Both use Montserrat/Inter from Google Fonts; CSS enforces minimum sizes |
| Breaking change for in-progress deck tasks | H | M | Complete or abandon any existing deck tasks before merging |
| `[TODO:]` markers parsed differently in markdown | M | L | Use plain text markers (not markdown links); verify grep pattern works |
| Two-column `::right::` slot less flexible than Typst `#grid` | L | L | Only used on Team and Why Us/Why Now slides; sufficient for pitch deck layout |

## Implementation Phases

### Phase 1: Create Slidev Templates and Pattern Files [NOT STARTED]

**Goal**: Create all new files that agents and index entries will reference. This phase has no dependencies and produces the foundation for all subsequent phases.

**Tasks**:
- [ ] Create directory `.claude/extensions/founder/context/project/founder/templates/slidev/deck/`
- [ ] Create `deck-dark-blue.md` -- Slidev template with `colorSchema: dark`, `themeConfig.primary: '#60a5fa'`, scoped CSS for navy background `#1e293b`, text colors `#e2e8f0`/`#cbd5e1`/`#94a3b8`, all 10 YC slides with `[TODO:]` markers, `<!-- -->` speaker notes, `::right::` slot syntax for Team/Why Us slides
- [ ] Create `deck-minimal-light.md` -- Slidev template with `colorSchema: light`, `themeConfig.primary: '#3182ce'`, white/light background, dark text `#2d3748`/`#1a202c`
- [ ] Create `deck-premium-dark.md` -- Slidev template with `colorSchema: dark`, `themeConfig.primary: '#d4a574'`, near-black background `#0f0f1a`, gold accents
- [ ] Create `deck-growth-green.md` -- Slidev template with `colorSchema: light`, `themeConfig.primary: '#38a169'`, mint background `#f0fdf4`, green headings `#047857`
- [ ] Create `deck-professional-blue.md` -- Slidev template with `colorSchema: light`, `themeConfig.primary: '#2b6cb0'`, white background, navy headings `#1a365d`
- [ ] Create `patterns/slidev-deck-template.md` -- Complete Slidev markdown template reference covering: framework overview, annotated full template, customization guide (themeConfig, colorSchema, fonts, scoped CSS), slide separator rules, speaker notes syntax, two-column layouts, animation guidelines (`<v-clicks>`, `v-mark`), export commands (`slidev export`), design checklist, prohibited patterns
- [ ] Update `patterns/pitch-deck-structure.md` -- Replace Typst Implementation subsection with Slidev equivalent (headmatter fonts config + scoped CSS example); update cross-reference from `touying-pitch-deck-template.md` to `slidev-deck-template.md`

**Timing**: 2 hours

**Files to create/modify**:
- `context/project/founder/templates/slidev/deck/deck-dark-blue.md` -- CREATE (~130 lines)
- `context/project/founder/templates/slidev/deck/deck-minimal-light.md` -- CREATE (~130 lines)
- `context/project/founder/templates/slidev/deck/deck-premium-dark.md` -- CREATE (~130 lines)
- `context/project/founder/templates/slidev/deck/deck-growth-green.md` -- CREATE (~130 lines)
- `context/project/founder/templates/slidev/deck/deck-professional-blue.md` -- CREATE (~130 lines)
- `context/project/founder/patterns/slidev-deck-template.md` -- CREATE (~250 lines)
- `context/project/founder/patterns/pitch-deck-structure.md` -- MODIFY (replace Typst code block + cross-reference)

All paths are relative to `.claude/extensions/founder/`.

**Verification**:
- All 5 `.md` templates exist with valid YAML headmatter (parseable), `---` separators with blank lines, 10 slide sections with `[TODO:]` markers
- `slidev-deck-template.md` covers all sections listed above
- `pitch-deck-structure.md` references `slidev-deck-template.md` and contains Slidev code example

---

### Phase 2: Update Agents [NOT STARTED]

**Goal**: Update all three deck agents to reference new Slidev templates and patterns. The deck-builder-agent receives a heavy rewrite for Slidev markdown generation and export.

**Tasks**:
- [ ] Update `deck-research-agent.md` -- Change context reference from `touying-pitch-deck-template.md` to `slidev-deck-template.md`; change "final Typst pitch deck" to "final Slidev pitch deck" in Next Steps
- [ ] Update `deck-planner-agent.md` -- Change context reference to `slidev-deck-template.md`; update template file extensions from `.typ` to `.md` in Stage 3 selection; update template paths from `templates/typst/deck/` to `templates/slidev/deck/` in Stage 6 plan generation; update Phase 1/3 task descriptions and Testing section from Typst to Slidev terminology; update Artifacts section extensions
- [ ] Rewrite `deck-builder-agent.md` -- This is the heaviest change:
  - Frontmatter/overview: all Typst references to Slidev
  - Context references: `slidev-deck-template.md` + 5 new `.md` template paths under `templates/slidev/deck/`
  - Stage 2.5 tool detection: replace `typst` binary check with `slidev` CLI + `playwright-chromium` check
  - Stage 3 resume: `.typ` to `.md` file extension
  - Stage 4a template paths: `templates/typst/deck/` to `templates/slidev/deck/`
  - Stage 4b template parsing: complete rewrite from Typst markup parsing to Slidev markdown structure (headmatter YAML, `---` separators, `::right::` slots, `<!-- notes -->`)
  - Stage 4c content generation: complete rewrite from Typst substitution (`#let`, `#text`, `#grid`, `#speaker-note`) to Slidev substitution (YAML fields, markdown content, slot syntax, HTML comments)
  - Stage 4e output: `.typ` to `.md`
  - Stage 5 compilation: `typst compile` to `slidev export` with playwright check
  - Stage 6-8: all `.typ` to `.md`, "Typst" to "Slidev" terminology
  - Critical Requirements: replace Typst-specific rules with Slidev equivalents

**Timing**: 2 hours

**Files to modify** (all relative to `.claude/extensions/founder/`):
- `agents/deck-research-agent.md` -- MODIFY (2 string replacements)
- `agents/deck-planner-agent.md` -- MODIFY (moderate: ~15 changes across template selection, plan generation, testing)
- `agents/deck-builder-agent.md` -- MODIFY (heavy rewrite: ~50+ changes across all stages)

**Verification**:
- No remaining references to `touying`, `typst`, or `.typ` in any of the 3 agent files (except potentially in explanatory comments about the migration)
- All template paths point to `templates/slidev/deck/deck-{palette}.md`
- All pattern references point to `slidev-deck-template.md`
- Builder agent uses `slidev export` for PDF generation
- Builder agent outputs to `strategy/{slug}-deck.md`

---

### Phase 3: Update Skills and Command [NOT STARTED]

**Goal**: Update the thin skill wrappers and command entry point with Slidev terminology. These depend on agent behavior being correct (Phase 2).

**Tasks**:
- [ ] Update `skills/skill-deck-plan/SKILL.md` -- Change "generate the Typst pitch deck" to "generate the Slidev pitch deck" in return message
- [ ] Update `skills/skill-deck-implement/SKILL.md` -- Change frontmatter description; update delegation context descriptions; change template reference from `.typ` to `.md`; change "typst compile" to "slidev export"; update error handling section terminology; rename `typst_generated` metadata field to `pdf_generated`
- [ ] Update `commands/deck.md` -- Change "final Typst pitch deck" to "final Slidev pitch deck" in Next Steps and Gate Out displays; remove `.typ$` from file path detection regex; update workflow summary and Output Artifacts section

**Timing**: 45 minutes

**Files to modify** (all relative to `.claude/extensions/founder/`):
- `skills/skill-deck-plan/SKILL.md` -- MODIFY (1 string replacement)
- `skills/skill-deck-implement/SKILL.md` -- MODIFY (moderate: ~10 changes)
- `commands/deck.md` -- MODIFY (minor: ~5 string replacements)

**Verification**:
- No remaining references to "Typst" or `.typ` in skill or command files
- skill-deck-implement references `slidev export` and `pdf_generated` metadata field
- deck.md command no longer matches `.typ$` in file path detection

---

### Phase 4: Update Index Entries [NOT STARTED]

**Goal**: Update context discovery index to point to new file paths so agents load the correct templates and patterns.

**Tasks**:
- [ ] Update `index-entries.json` -- Replace 6 entries:
  - `project/founder/patterns/touying-pitch-deck-template.md` -> `project/founder/patterns/slidev-deck-template.md` with updated summary and line_count
  - 5 template entries: `project/founder/templates/typst/deck/deck-{palette}.typ` -> `project/founder/templates/slidev/deck/deck-{palette}.md` with updated summaries ("Slidev markdown template with seriph theme") and line_counts (~130 each)
- [ ] Verify all `load_when` fields remain unchanged (same agents, languages, task_types, commands)

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/index-entries.json` -- MODIFY (6 entry updates: path, summary, line_count fields)

**Verification**:
- No remaining references to `typst/deck/` or `touying` in index-entries.json
- All 6 new paths correspond to files that exist (created in Phase 1)
- `load_when` fields unchanged for all 6 entries
- JSON is valid (parseable with `jq`)

---

### Phase 5: Delete Obsolete Typst Files [NOT STARTED]

**Goal**: Remove all Typst-specific files that have been replaced. This is the final phase because it depends on all references being updated first.

**Tasks**:
- [ ] Verify no remaining references to deleted files exist in the codebase (grep for each filename)
- [ ] Delete `patterns/touying-pitch-deck-template.md`
- [ ] Delete `templates/typst/deck/deck-dark-blue.typ`
- [ ] Delete `templates/typst/deck/deck-minimal-light.typ`
- [ ] Delete `templates/typst/deck/deck-premium-dark.typ`
- [ ] Delete `templates/typst/deck/deck-growth-green.typ`
- [ ] Delete `templates/typst/deck/deck-professional-blue.typ`
- [ ] Remove `templates/typst/deck/` directory if empty (do NOT remove `templates/typst/` parent -- it contains other non-deck templates)

**Timing**: 15 minutes

**Files to delete** (all relative to `.claude/extensions/founder/context/project/founder/`):
- `patterns/touying-pitch-deck-template.md` -- DELETE
- `templates/typst/deck/deck-dark-blue.typ` -- DELETE
- `templates/typst/deck/deck-minimal-light.typ` -- DELETE
- `templates/typst/deck/deck-premium-dark.typ` -- DELETE
- `templates/typst/deck/deck-growth-green.typ` -- DELETE
- `templates/typst/deck/deck-professional-blue.typ` -- DELETE
- `templates/typst/deck/` -- REMOVE directory (if empty)

**Verification**:
- `grep -r "touying-pitch-deck-template" .claude/extensions/founder/` returns no results
- `grep -r "templates/typst/deck/" .claude/extensions/founder/` returns no results
- `ls .claude/extensions/founder/context/project/founder/templates/typst/deck/` returns "No such file or directory"
- Other `templates/typst/` content (strategy-template.typ, market-sizing.typ, etc.) is unaffected

## Testing & Validation

- [ ] All 5 Slidev templates have valid YAML headmatter (test with `head -20 | yq`)
- [ ] All 5 templates contain exactly 10 main slides plus appendix section marker
- [ ] `grep -r "\.typ" .claude/extensions/founder/` returns no deck-related hits (only non-deck Typst references should remain)
- [ ] `grep -r "touying" .claude/extensions/founder/` returns no results
- [ ] `grep -r "typst compile" .claude/extensions/founder/` returns no deck-related hits
- [ ] `jq . .claude/extensions/founder/index-entries.json` parses without error
- [ ] All 6 index entry paths correspond to files that exist on disk
- [ ] The `/deck` command flow description still documents the full forcing questions -> research -> plan -> implement pipeline
- [ ] No references to deleted files remain anywhere in the founder extension

## Artifacts & Outputs

- `specs/345_port_deck_typst_to_slidev/plans/02_implementation-plan.md` (this file)
- 5 new Slidev templates in `templates/slidev/deck/`
- 1 new pattern file `patterns/slidev-deck-template.md`
- 12 modified files (3 agents, 2 skills, 1 command, 1 pattern, 1 index-entries)
- 6 deleted Typst files + 1 removed directory

## Rollback/Contingency

All changes are within the `.claude/extensions/founder/` directory tree. Rollback strategy:
1. `git revert` the implementation commits in reverse order
2. Phase 5 deletions are recoverable via git history
3. If partial failure occurs, the system remains functional as long as Phase 1 (new files) and Phase 4 (index updates) are applied together -- agents will find the files they reference
4. In-progress deck tasks should be completed or abandoned before applying this change to avoid broken `.typ` artifact references
