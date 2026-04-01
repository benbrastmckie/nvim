# Research Report: Task #345 - Complete Refactoring Analysis

**Task**: 345 - Port /deck command-skill-agent from Typst to Slidev
**Started**: 2026-03-31T16:00:00Z
**Completed**: 2026-03-31T17:30:00Z
**Effort**: Large
**Dependencies**: 01_slidev-port-research.md, 02_slidev-standards.md
**Sources/Inputs**: All 18 files in the /deck system (command, 3 skills, 3 agents, 2 patterns, 5 templates, manifest, index-entries)
**Artifacts**: specs/345_port_deck_typst_to_slidev/reports/03_refactor-analysis.md
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- The /deck system consists of 18 files across command, skills, agents, patterns, templates, and manifest/index layers
- 15 files require modification, 7 new files must be created, and 6 files must be deleted
- The core workflow (forcing questions, 3-phase research/plan/implement, YC 10-slide structure) is fully preserved
- Changes are concentrated in the builder agent (heaviest rewrite), templates (full replacement), and pattern files (replace Typst reference with Slidev reference)
- The refactoring can be executed in 5 ordered phases with clear dependency boundaries

---

## 1. File-by-File Change Analysis

### 1.1 Command: `.claude/extensions/founder/commands/deck.md`

**Current purpose**: Entry point for /deck command. Handles 4 input types (description, task number, file path, --quick), runs pre-task forcing questions (STAGE 0), creates task, delegates to skill-deck-research.

**Action**: MODIFY (minor)

**Specific changes**:
- Line 288: Change "final Typst pitch deck" to "final Slidev pitch deck" in the Next Steps display
- Line 372: Change "final Typst pitch deck" to "final Slidev pitch deck" in the Gate Out display
- Line 136: Remove `.typ$` from file path detection regex (line `grep -qE '^\.|^/|^~|\.md$|\.txt$|\.typ$'`); replace `.typ$` with nothing (`.md` is already present and is the Slidev format)
- Line 463: Change "generates final Typst pitch deck" to "generates final Slidev pitch deck" in workflow summary
- Lines 448-449: Update Output Artifacts section -- the research report location stays the same; note that final deck is `.md` not `.typ`

**Rationale**: The command is workflow orchestration only. It does not reference Typst templates or compilation directly. Changes are limited to user-facing text strings.

---

### 1.2 Skill: `.claude/extensions/founder/skills/skill-deck-research/SKILL.md`

**Current purpose**: Thin wrapper that routes research to deck-research-agent. Handles preflight (status -> RESEARCHING), delegation, postflight (status -> RESEARCHED, artifact linking, git commit).

**Action**: MODIFY (minimal)

**Specific changes**:
- Line 249: Return format mentions "Run /plan {N} to create deck implementation plan" -- keep as-is (format-neutral)
- Line 294: Return example mentions "Next: Run /plan 234 to create deck implementation plan" -- keep as-is

**Net change**: No functional changes required. The skill is format-agnostic -- it handles status transitions and artifact linking. The research phase does not interact with templates or output formats.

**Rationale**: Research produces a slide-mapped content report regardless of output format. The skill's routing, preflight, postflight, and cleanup logic is entirely unchanged.

---

### 1.3 Skill: `.claude/extensions/founder/skills/skill-deck-plan/SKILL.md`

**Current purpose**: Thin wrapper that routes planning to deck-planner-agent. Handles preflight (status -> PLANNING), delegation, postflight (status -> PLANNED, artifact linking, git commit).

**Action**: MODIFY (minimal)

**Specific changes**:
- Line 249: Return format says "Next: Run /implement {N} to generate the Typst pitch deck" -- change to "Next: Run /implement {N} to generate the Slidev pitch deck"

**Net change**: One string replacement. The skill is format-agnostic in all functional code.

**Rationale**: The planning skill orchestrates the interactive flow (template selection, slide assignment, ordering) and does not reference Typst/Slidev specifics beyond the return message.

---

### 1.4 Skill: `.claude/extensions/founder/skills/skill-deck-implement/SKILL.md`

**Current purpose**: Routes implementation to deck-builder-agent for Typst generation. Handles preflight, delegation with template_palette, postflight, artifact linking.

**Action**: MODIFY (moderate)

**Specific changes**:
- Line 1 (frontmatter description): Change "typst pitch deck generation" to "slidev pitch deck generation"
- Line 9: Change "generating typst pitch decks" to "generating Slidev pitch decks"
- Line 115: Template palette extraction logic stays the same (palette names are preserved)
- Line 161-163 (delegation context): Change description from "Generate typst pitch deck from plan and research" to "Generate Slidev pitch deck from plan and research"
- Lines 168-175: Update agent description comments from "Generate complete `.typ` file" to "Generate complete `.md` Slidev file"; change "typst compile" references to "slidev export"
- Line 174: Change "Note: Typst compilation (PDF generation) is optional" to "Note: Slidev PDF export is optional"
- Line 259: Change template reference from "deck-{palette}.typ" to "deck-{palette}.md"
- Line 267: Change "Typst source" to "Slidev source" and `.typ` to `.md`
- Line 268: Update PDF note from "typst not installed" to "slidev/playwright not installed"
- Lines 308-313: Error handling section -- rename "Typst/PDF Errors" to "Slidev/PDF Errors"; change "Typst not installed" to "Slidev or playwright-chromium not installed"; change "Compilation error" to "Export error"; change `.typ` references to `.md`
- Line 313: Change `metadata.typst_generated` to `metadata.pdf_generated`

**Rationale**: This skill passes `template_palette` and `output_dir` to the builder agent and handles return metadata. The palette names stay the same; only the output format references change.

---

### 1.5 Agent: `.claude/extensions/founder/agents/deck-research-agent.md`

**Current purpose**: Reads source materials, maps content to 10-slide YC structure, produces research report with [MISSING] markers, asks max 1-2 follow-up questions.

**Action**: MODIFY (minor)

**Specific changes**:
- Line 42: Change context reference from `touying-pitch-deck-template.md` to `slidev-deck-template.md` (the new pattern file)
- Line 289: Change "final Typst pitch deck" to "final Slidev pitch deck" in the Next Steps section of the report template

**Net change**: Two string replacements. The research agent does not generate output files -- it reads materials and writes a markdown research report. Its output format is identical regardless of whether Typst or Slidev is the target.

**Rationale**: The only Typst-specific reference is the touying pattern file loaded for context. Switching this to the Slidev pattern gives the agent awareness of the target format for more relevant gap analysis.

---

### 1.6 Agent: `.claude/extensions/founder/agents/deck-planner-agent.md`

**Current purpose**: Interactive planning with 3 AskUserQuestion interactions (template selection, slide content assignment, slide ordering). Generates plan artifact with Deck Configuration section.

**Action**: MODIFY (moderate)

**Specific changes**:

**Context references** (lines 42-43):
- Change `touying-pitch-deck-template.md` reference to `slidev-deck-template.md`

**Stage 3 - Template Selection** (lines 120-140):
- Template descriptions stay the same (Dark Blue, Minimal Light, etc.) -- same palette names
- Change file mapping from `.typ` to `.md`:
  - "Dark Blue" -> `deck-dark-blue.md` (was `.typ`)
  - "Minimal Light" -> `deck-minimal-light.md` (was `.typ`)
  - "Premium Dark" -> `deck-premium-dark.md` (was `.typ`)
  - "Growth Green" -> `deck-growth-green.md` (was `.typ`)
  - "Professional Blue" -> `deck-professional-blue.md` (was `.typ`)

**Stage 6 - Plan Generation** (lines 206-335):
- Line 226: Change "Generate a Typst pitch deck" to "Generate a Slidev pitch deck"
- Line 232-233: Update template file reference path from `templates/typst/deck/{template_file}` to `templates/slidev/deck/{template_file}`
- Line 234: Update file extension in slide manifest table
- Lines 284-293: Phase 1 tasks: Change "Copy selected template to working directory" to "Load selected Slidev template as base structure"
- Lines 296-300: Phase 2 tasks: Same content generation tasks (format-neutral)
- Lines 303-309: Phase 3 tasks: Change "Compile Typst file to verify no errors" to "Validate Slidev markdown structure"; add "Export to PDF via slidev export (requires playwright-chromium)"
- Lines 312-315: Testing section: Change "Typst file compiles without errors" to "Slidev markdown is well-formed"; change "Template styling applied correctly" to "Theme and frontmatter configured correctly"
- Lines 323-326: Artifacts section: Change `.typ` to `.md` and `typst compile` to `slidev export`

**Rationale**: The planner's interactive flow (3 questions) is identical. Changes are concentrated in the plan template's file references and compilation steps.

---

### 1.7 Agent: `.claude/extensions/founder/agents/deck-builder-agent.md`

**Current purpose**: Core generation agent. Reads plan + research, selects Typst template, populates [TODO:] markers with content, compiles via `typst compile`. Outputs to `strategy/{slug}-deck.typ` + `.pdf`.

**Action**: MODIFY (heavy rewrite -- this is the most changed file)

**Specific changes**:

**Frontmatter and overview** (lines 1-11):
- Change description: "Generate Slidev markdown pitch decks from plans and research by populating slide templates"
- Change all references from "Typst" to "Slidev" in overview paragraph
- Change output from `strategy/{slug}-deck.typ` to `strategy/{slug}-deck.md`

**Context references** (lines 37-49):
- Line 38: Change `touying-pitch-deck-template.md` to `slidev-deck-template.md`
- Lines 42-46: Change all 5 template references from `.typ` to `.md` and path from `templates/typst/deck/` to `templates/slidev/deck/`

**Stage 2 - Load Plan and Research** (lines 109-140):
- No structural changes needed. Research report parsing is format-neutral.

**Stage 2.5 - Tool Detection** (lines 136-149):
- Replace Typst detection with Slidev + playwright detection:
  ```bash
  slidev_available=false
  if command -v slidev &> /dev/null || npx slidev --version &> /dev/null 2>&1; then
    slidev_available=true
  fi
  playwright_available=false
  if npx playwright --version &> /dev/null 2>&1; then
    playwright_available=true
  fi
  ```
- Change install guidance from `nix profile install nixpkgs#typst` to `npm i -g @slidev/cli && npx playwright install chromium`

**Stage 3 - Resume Detection** (lines 152-170):
- Change `existing_typ` to `existing_md` and `.typ` to `.md`

**Stage 4 - Template Selection and Content Generation** (lines 172-282):
- **4a**: Change all template paths from `templates/typst/deck/deck-{palette}.typ` to `templates/slidev/deck/deck-{palette}.md`
- **4b**: COMPLETE REWRITE. Instead of reading Typst template structure (imports, #let params, touying theme, #show rules, slides with [TODO:] markers), read Slidev markdown template structure:
  - Headmatter block (YAML frontmatter with theme, title, colorSchema, fonts, themeConfig)
  - Per-slide frontmatter blocks with `---` separators
  - Markdown content with `::right::` slot markers
  - `<!-- notes -->` for speaker notes (replacing `#speaker-note[...]`)
  - `[TODO:]` markers (same marker format, different surrounding syntax)
- **4c**: COMPLETE REWRITE of content generation logic:
  - Instead of `#let company-name = [...]` substitution, update YAML `title:`, `author:`, `info:` fields in headmatter
  - Instead of replacing Typst markup like `#text(size: 32pt, fill: palette-accent)[TODO: ...]`, replace markdown content within slide sections
  - Dollar sign escaping changes: Slidev uses standard markdown, so `$` is used for LaTeX math. Financial amounts should use plain text or escaped as needed
  - Grid layouts (`#grid(columns: (1fr, 1fr), ...)`) become `::right::` slot syntax
  - `#speaker-note[...]` blocks become `<!-- ... -->` HTML comments at slide end
  - `#v(0.4em)` spacing becomes blank lines
  - `#text(size: Xpt, ...)` formatting becomes CSS classes or heading levels
  - `#align(center)[...]` becomes `layout: center` frontmatter or HTML center tags
- **4d**: Appendix generation uses the same markdown format as main slides
- **4e**: Change output file from `.typ` to `.md`; change grep pattern for TODO count

**Stage 5 - Compilation** (lines 284-320):
- Replace `typst compile` with `slidev export`:
  ```bash
  if [ "$slidev_available" = "true" ] && [ "$playwright_available" = "true" ]; then
    pdf_file="${output_dir}${slug}-deck.pdf"
    npx slidev export "$md_file" --output "$pdf_file" 2>&1
  fi
  ```
- Same non-blocking pattern: export failure does not block task completion

**Stage 6 - Summary** (lines 322-363):
- Change all `.typ` references to `.md`
- Change "Typst source" to "Slidev source"
- Change "PDF compilation" to "PDF export"

**Stage 7 - Metadata** (lines 365-404):
- Change artifact paths from `.typ` to `.md`
- Change `template_palette` field name stays the same
- Rename `typst_generated` to `pdf_generated`

**Stage 8 - Return summary** (lines 410-422):
- Update all `.typ` to `.md`, "Typst" to "Slidev"

**Critical Requirements section** (lines 479-503):
- Replace all Typst-specific requirements with Slidev equivalents:
  - "Preserve template infrastructure (imports, theme, typography, palette)" becomes "Preserve template headmatter (theme, fonts, themeConfig, colorSchema)"
  - "Escape dollar signs as `\$`" becomes "Use text for financial amounts (avoid bare `$` which triggers LaTeX math)"
  - "`typst compile`" becomes "`slidev export`"
  - "Use `#import`" becomes N/A (Slidev has no import system for templates)

**Rationale**: The builder agent is where Typst-specific logic is concentrated. Every content generation pattern must change from Typst markup to Slidev markdown syntax.

---

### 1.8 Pattern: `.claude/extensions/founder/context/project/founder/patterns/pitch-deck-structure.md`

**Current purpose**: Defines YC 10-slide structure, 3 design principles (Legibility, Simplicity, Obviousness), content density rules, typography enforcement, anti-patterns, validation checklists.

**Action**: MODIFY (minor)

**Specific changes**:
- Lines 287-300 (Typst Implementation subsection): Replace entire Typst code block with Slidev equivalent:
  ```markdown
  ### Slidev Implementation

  When generating Slidev slides, enforce these via headmatter and scoped CSS:

  ```yaml
  fonts:
    sans: Montserrat
    serif: Inter
  ```

  ```html
  <style>
  h1 { font-size: 3em; font-weight: bold; }
  h2 { font-size: 2.5em; font-weight: bold; }
  p, li { font-size: 1.5em; }
  </style>
  ```
  ```
- Line 406: Change "See `touying-pitch-deck-template.md`" to "See `slidev-deck-template.md`"

**Rationale**: The YC content and design principles are format-neutral. Only the implementation code example and cross-reference need updating.

---

### 1.9 Pattern: `.claude/extensions/founder/context/project/founder/patterns/touying-pitch-deck-template.md`

**Current purpose**: Complete Touying 0.6.3 template reference with Typst code, theme customization, animation patterns, two-column layouts, compilation instructions.

**Action**: DELETE (replaced by new `slidev-deck-template.md`)

**Rationale**: This file is entirely Typst/Touying-specific. Every code example, every pattern, every customization instruction is Typst syntax. A new Slidev-specific pattern file is needed instead.

---

### 1.10 Templates (5 files): `.claude/extensions/founder/context/project/founder/templates/typst/deck/deck-*.typ`

**Current purpose**: Five color-themed Typst templates, each containing:
- Header with palette comment, touying import, 5 `#let` parameters
- Palette color definitions (5 `#let` color variables)
- Touying simple theme setup with `config-info`, `config-colors`, `config-page`
- Typography setup (Montserrat headings, Inter body, font sizes)
- 10 slides with `[TODO:]` markers
- Speaker notes via `#speaker-note[...]`
- Appendix comment section

**Action**: DELETE all 5 `.typ` files (replaced by 5 new `.md` Slidev templates)

Files to delete:
1. `templates/typst/deck/deck-dark-blue.typ`
2. `templates/typst/deck/deck-minimal-light.typ`
3. `templates/typst/deck/deck-premium-dark.typ`
4. `templates/typst/deck/deck-growth-green.typ`
5. `templates/typst/deck/deck-professional-blue.typ`

**Rationale**: Typst syntax is completely incompatible with Slidev markdown. Templates must be recreated from scratch in the target format.

---

### 1.11 Manifest: `.claude/extensions/founder/manifest.json`

**Current purpose**: Registers all founder extension agents, skills, commands, routing, context paths, merge targets, MCP servers.

**Action**: MODIFY (minor)

**Specific changes**: None to the manifest itself. The routing entries (`founder:deck` -> `skill-deck-research/plan/implement`) are unchanged. Agent names, skill names, and command names are unchanged. The `provides.context` entry `["project/founder"]` is a directory reference that covers both old and new template paths.

**Rationale**: The manifest registers components by name, not by file content. Since we keep the same agent names, skill names, and routing keys, no manifest changes are needed. The context directory reference (`project/founder`) automatically covers new files placed there.

---

### 1.12 Index Entries: `.claude/extensions/founder/index-entries.json`

**Current purpose**: Context discovery entries for all founder extension context files. Contains entries for each of the 5 `.typ` template files and the `touying-pitch-deck-template.md` pattern.

**Action**: MODIFY (moderate)

**Specific changes**:

**Replace touying pattern entry** (lines 601-625):
```json
{
  "path": "project/founder/patterns/slidev-deck-template.md",
  "summary": "Slidev markdown template structure for pitch deck slide generation",
  "line_count": 250,
  "load_when": {
    "agents": ["deck-research-agent", "deck-planner-agent", "deck-builder-agent", "founder-plan-agent", "founder-implement-agent"],
    "languages": ["founder"],
    "task_types": ["deck"],
    "commands": ["/deck"]
  },
  "domain": "project",
  "subdomain": "founder"
}
```

**Replace 5 template entries** (lines 651-745): Change each entry's:
- `path`: from `project/founder/templates/typst/deck/deck-{palette}.typ` to `project/founder/templates/slidev/deck/deck-{palette}.md`
- `summary`: from "... typst template with touying theme ..." to "... Slidev markdown template with seriph theme ..."
- `line_count`: Update to reflect new file sizes (estimated ~120-150 lines each vs ~410 for Typst)

**Rationale**: The index entries must point to the new file paths and have accurate summaries for context discovery.

---

## 2. New Files to Create

### 2.1 Slidev Pattern File

**Path**: `.claude/extensions/founder/context/project/founder/patterns/slidev-deck-template.md`

**Purpose**: Complete Slidev markdown template reference for pitch deck generation. Replaces `touying-pitch-deck-template.md`.

**Content outline**:
- Template Overview: Slidev framework, seriph theme, 16:9 aspect, markdown format
- Complete Template: Full annotated Slidev markdown deck with all 10 slides, headmatter, per-slide frontmatter, slot syntax, speaker notes
- Template Customization: Theme config changes, color schema switching, font overrides, scoped CSS
- Slide Separator Rules: `---` with blank lines, frontmatter blocks
- Speaker Notes: `<!-- ... -->` HTML comment syntax
- Two-Column Layouts: `::right::` slot syntax (Team slide only)
- Animation Guidelines: `<v-clicks>` for bullet lists, `v-mark` for emphasis
- Export Commands: `slidev export` for PDF, `--format pptx` for PowerPoint
- Design Checklist: Adapted from touying version for Slidev constraints
- Prohibited Patterns: Slidev-specific anti-patterns (over-animation, complex Vue components, etc.)

**Source of content**: Derived from `touying-pitch-deck-template.md` structure + Slidev standards from report 02. Every Typst code block becomes a Slidev markdown equivalent.

---

### 2.2-2.6 Slidev Markdown Templates (5 files)

**Base path**: `.claude/extensions/founder/context/project/founder/templates/slidev/deck/`

Each template follows this structure:

```markdown
---
# Headmatter (deck-wide configuration)
theme: seriph
title: "Your Company Name"
author: "Founder Name"
info: "One-line description of what you do"
colorSchema: dark|light
aspectRatio: "16/9"
fonts:
  sans: Inter
  serif: Montserrat
transition: slide-left
themeConfig:
  primary: '#XXXXXX'
exportFilename: company-deck
download: true
---

# Your Company Name

<div class="text-xl opacity-80">
[TODO: One-line description]
</div>

<!-- Speaker notes here -->

---
layout: default
---

# The Problem

...10 slides with [TODO:] markers...

---

## Appendix slides follow
```

#### 2.2 `deck-dark-blue.md`

**Purpose**: Default dark theme. Deep navy with blue accents.
**Key headmatter**: `colorSchema: dark`, `themeConfig.primary: '#60a5fa'`
**Scoped CSS**: Background override to `#1e293b`, text colors `#e2e8f0` (headings), `#cbd5e1` (body), `#94a3b8` (subtitles)

#### 2.3 `deck-minimal-light.md`

**Purpose**: Clean light theme for data/analytics presentations.
**Key headmatter**: `colorSchema: light`, `themeConfig.primary: '#3182ce'`
**Scoped CSS**: White/light background, dark text `#2d3748` (headings), `#1a202c` (body)

#### 2.4 `deck-premium-dark.md`

**Purpose**: Luxury dark theme with gold accents.
**Key headmatter**: `colorSchema: dark`, `themeConfig.primary: '#d4a574'`
**Scoped CSS**: Near-black background `#0f0f1a`, gold accent headings, light body text

#### 2.5 `deck-growth-green.md`

**Purpose**: Fresh green theme for sustainability/climate tech.
**Key headmatter**: `colorSchema: light`, `themeConfig.primary: '#38a169'`
**Scoped CSS**: Mint background `#f0fdf4`, green headings `#047857`, green accent `#34d399`

#### 2.6 `deck-professional-blue.md`

**Purpose**: Corporate blue for fintech/enterprise B2B.
**Key headmatter**: `colorSchema: light`, `themeConfig.primary: '#2b6cb0'`
**Scoped CSS**: White background, navy headings `#1a365d`, blue accent `#4299e1`

**Source of content for all 5**: Direct translation from the corresponding `.typ` templates. Each template preserves:
- Same palette name and color values
- Same 10-slide structure with same [TODO:] markers
- Same speaker notes content (converted from `#speaker-note[...]` to `<!-- ... -->`)
- Same typography intent (via CSS instead of Typst `#set text`)
- Same grid/two-column patterns (via `::right::` instead of `#grid`)

**Slidev standards applied**: Per report 02 sections A.1-A.6 (separator rules, headmatter, per-slide frontmatter, named slots, presenter notes).

---

### 2.7 Slidev Template Directory

**Path**: `.claude/extensions/founder/context/project/founder/templates/slidev/deck/`

**Purpose**: Directory to hold the 5 new `.md` templates. The `slidev/` directory parallels the existing `typst/` directory structure.

---

## 3. Files to Delete

| File | Reason | Dependencies Check |
|------|--------|--------------------|
| `patterns/touying-pitch-deck-template.md` | Replaced by `slidev-deck-template.md` | Referenced by 3 agents (deck-research, deck-planner, deck-builder) and index-entries.json -- all updated in this port |
| `templates/typst/deck/deck-dark-blue.typ` | Replaced by `templates/slidev/deck/deck-dark-blue.md` | Referenced by deck-builder-agent and index-entries.json -- both updated |
| `templates/typst/deck/deck-minimal-light.typ` | Replaced by `.md` equivalent | Same as above |
| `templates/typst/deck/deck-premium-dark.typ` | Replaced by `.md` equivalent | Same as above |
| `templates/typst/deck/deck-growth-green.typ` | Replaced by `.md` equivalent | Same as above |
| `templates/typst/deck/deck-professional-blue.typ` | Replaced by `.md` equivalent | Same as above |

**Note**: The `templates/typst/deck/` directory itself can be removed if empty after deletion. Other `typst/` templates (strategy-template.typ, market-sizing.typ, etc.) remain in `templates/typst/` and are NOT affected by this port.

**Verification**: No other files outside the /deck system reference these deleted files. Confirmed by checking:
- Other agents (market-agent, analyze-agent, etc.) do not reference deck templates
- Other skills do not reference touying pattern
- No rules reference these files
- The yc-compliance-checklist.md and pitch-deck-structure.md reference touying by cross-reference text only (updated in section 1.8)

---

## 4. Manifest and Index Changes

### 4.1 Manifest (`manifest.json`)

**No changes required.** The manifest is fully component-name-based:
- Agent names: unchanged (deck-research-agent, deck-planner-agent, deck-builder-agent)
- Skill names: unchanged (skill-deck-research, skill-deck-plan, skill-deck-implement)
- Command name: unchanged (deck.md)
- Routing keys: unchanged (`founder:deck` -> same skills)
- Context directory: `["project/founder"]` -- covers both old and new paths

### 4.2 Index Entries (`index-entries.json`)

**6 entries to update**:

| Current Entry | New Entry |
|--------------|-----------|
| `project/founder/patterns/touying-pitch-deck-template.md` | `project/founder/patterns/slidev-deck-template.md` |
| `project/founder/templates/typst/deck/deck-dark-blue.typ` | `project/founder/templates/slidev/deck/deck-dark-blue.md` |
| `project/founder/templates/typst/deck/deck-minimal-light.typ` | `project/founder/templates/slidev/deck/deck-minimal-light.md` |
| `project/founder/templates/typst/deck/deck-premium-dark.typ` | `project/founder/templates/slidev/deck/deck-premium-dark.md` |
| `project/founder/templates/typst/deck/deck-growth-green.typ` | `project/founder/templates/slidev/deck/deck-growth-green.md` |
| `project/founder/templates/typst/deck/deck-professional-blue.typ` | `project/founder/templates/slidev/deck/deck-professional-blue.md` |

For each entry, update:
- `path` field (new file location)
- `summary` field (replace "typst" with "Slidev", "touying" with "seriph theme")
- `line_count` field (updated to match new file sizes)

All `load_when` fields remain identical (same agents, languages, task_types, commands).

---

## 5. Preserved vs Changed Behaviors

| Preserved (No Change) | Changed |
|------------------------|---------|
| Pre-task forcing questions (STAGE 0) | Output format: `.md` instead of `.typ` |
| 4 deck modes (INVESTOR/UPDATE/INTERNAL/PARTNERSHIP) | Compilation: `slidev export` instead of `typst compile` |
| YC 10-slide structure (Title through Closing) | Template syntax: Markdown+YAML instead of Typst markup |
| Material synthesis approach (read, extract, map) | Speaker notes: `<!-- -->` instead of `#speaker-note[...]` |
| [MISSING] marker pattern for gaps | Two-column layout: `::right::` instead of `#grid(columns: ...)` |
| 3-question planning flow (template, slides, ordering) | Typography: CSS classes instead of `#set text(size: Xpt)` |
| 5 color palette names (dark-blue, minimal-light, etc.) | Color theming: `themeConfig` + `colorSchema` instead of `#let palette-*` |
| Early metadata pattern | Dollar sign handling: plain text instead of `\$` escaping |
| Non-blocking PDF generation | PDF tool chain: playwright-chromium instead of typst binary |
| Skill routing via `founder:deck` key | Template file extension: `.md` instead of `.typ` |
| Task creation, status transitions, artifact linking | Template directory: `templates/slidev/` instead of `templates/typst/` |
| 3-phase research/plan/implement workflow | Pattern file: `slidev-deck-template.md` instead of `touying-pitch-deck-template.md` |
| Git commit conventions and session tracking | Metadata field: `pdf_generated` instead of `typst_generated` |
| AskUserQuestion interactions in planner | Install guidance: npm packages instead of nix typst |
| [TODO:] marker format in generated output | Output path: `strategy/{slug}-deck.md` instead of `strategy/{slug}-deck.typ` |
| Appendix slide generation | Additional export formats: PPTX and PNG available via Slidev |

---

## 6. Dependency Graph

```
Phase 1 (independent -- no dependencies between items):
  [1a] Create templates/slidev/deck/ directory
  [1b] Create 5 Slidev markdown templates (deck-dark-blue.md, etc.)
  [1c] Create patterns/slidev-deck-template.md
  [1d] Update patterns/pitch-deck-structure.md (Typst -> Slidev code example)

Phase 2 (depends on Phase 1 -- agents reference new templates/patterns):
  [2a] Update deck-research-agent.md (pattern reference)
  [2b] Update deck-planner-agent.md (pattern reference + template paths + plan format)
  [2c] Update deck-builder-agent.md (heavy rewrite: template loading, content generation, compilation)

Phase 3 (depends on Phase 2 -- skills reference agent behaviors):
  [3a] Update skill-deck-plan/SKILL.md (return message)
  [3b] Update skill-deck-implement/SKILL.md (format references, metadata fields)
  [3c] Update commands/deck.md (user-facing text)

Phase 4 (depends on Phase 1 -- index points to new files):
  [4a] Update index-entries.json (6 entries: paths + summaries + line counts)

Phase 5 (depends on Phase 1-4 verified -- cleanup):
  [5a] Delete patterns/touying-pitch-deck-template.md
  [5b] Delete 5 templates/typst/deck/deck-*.typ files
  [5c] Remove templates/typst/deck/ directory (if now empty)
```

**Dependency DAG visualization**:

```
Layer 0:  [1a] [1b] [1c] [1d]      (all independent)
             \   |   /      |
Layer 1:   [2a] [2b] [2c]  |       (depend on 1b, 1c)
              \   |   /     |
Layer 2:    [3a] [3b] [3c]  |      (depend on 2a-c)
                             |
Layer 3:        [4a]  -------+      (depends on 1b, 1c)
                  |
Layer 4:    [5a] [5b] [5c]         (depends on everything above verified)
```

---

## 7. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| **Slidev theme `seriph` does not support all customizations** | Medium | Medium | Use scoped `<style>` blocks per slide for fine-grained control; consider theme ejection (`slidev theme eject`) if needed |
| **Color palette CSS does not match Typst precision** | Medium | Low | Each template includes scoped CSS with exact hex values; test with `slidev dev` before committing |
| **Speaker notes `<!-- -->` syntax conflicts with HTML comments in content** | Low | Low | Document that `<!-- -->` is reserved for notes; content HTML comments should use different patterns |
| **`slidev export` requires playwright-chromium** | High | Low | Same non-blocking pattern as Typst: `.md` output is always valid; PDF is optional. Document playwright as optional dependency |
| **Font loading in Slidev differs from Typst** | Medium | Low | Slidev uses Google Fonts via `fonts:` headmatter; fallback fonts specified; Montserrat and Inter are both Google Fonts |
| **Two-column `::right::` slot syntax is less flexible than Typst `#grid`** | Low | Low | Pitch decks only use two-column on Team and Why Us/Why Now slides; `::right::` covers these cases |
| **[TODO:] markers in markdown may be parsed differently** | Low | Medium | Use plain text `[TODO: ...]` (not markdown links); verify grep pattern works with new format |
| **Templates significantly shorter than Typst versions** | High | None | Expected: Slidev markdown is more concise (~120-150 lines vs ~410 lines for Typst). This is a feature, not a bug |
| **Breaking change for existing deck tasks in progress** | Medium | High | Any task already in PLANNED or IMPLEMENTING status with `.typ` artifacts will break. Mitigation: complete or abandon existing deck tasks before merging |

---

## Appendix

### A. Search Queries and File Inventory

All 18 files in the /deck system were read in full:

| Category | File | Lines | Read Status |
|----------|------|-------|-------------|
| Command | commands/deck.md | 486 | Complete |
| Skill | skills/skill-deck-research/SKILL.md | 331 | Complete |
| Skill | skills/skill-deck-plan/SKILL.md | 266 | Complete |
| Skill | skills/skill-deck-implement/SKILL.md | 314 | Complete |
| Agent | agents/deck-research-agent.md | 418 | Complete |
| Agent | agents/deck-planner-agent.md | 467 | Complete |
| Agent | agents/deck-builder-agent.md | 503 | Complete |
| Pattern | patterns/pitch-deck-structure.md | 407 | Complete |
| Pattern | patterns/touying-pitch-deck-template.md | 424 | Complete |
| Template | templates/typst/deck/deck-dark-blue.typ | 412 | Complete |
| Template | templates/typst/deck/deck-minimal-light.typ | 406 | Headers |
| Template | templates/typst/deck/deck-premium-dark.typ | 410 | Headers |
| Template | templates/typst/deck/deck-growth-green.typ | 407 | Headers |
| Template | templates/typst/deck/deck-professional-blue.typ | 407 | Headers |
| Manifest | manifest.json | 102 | Complete |
| Index | index-entries.json | 747 | Complete |
| Prior Report | reports/01_slidev-port-research.md | 395 | Complete |
| Prior Report | reports/02_slidev-standards.md | ~500 | Complete |

### B. Template Correspondence Table

| Typst Construct | Slidev Equivalent | Notes |
|-----------------|-------------------|-------|
| `#import "@preview/touying:0.6.3": *` | `theme: seriph` in headmatter | No import needed |
| `#let company-name = [...]` | `title: "..."` in headmatter | YAML string |
| `#let palette-primary = rgb("#...")` | `themeConfig: { primary: '#...' }` | In headmatter |
| `#set text(size: 32pt)` | `<style> p { font-size: 1.5em; } </style>` | Scoped CSS |
| `#show heading.where(level: 1): set text(size: 48pt)` | `<style> h1 { font-size: 3em; } </style>` | Scoped CSS |
| `= Title` / `== Subtitle` | `# Title` / `## Subtitle` | Markdown headings |
| `#grid(columns: (1fr, 1fr), ...)` | `layout: two-cols` + `::right::` | Named slot syntax |
| `#speaker-note[...]` | `<!-- ... -->` | HTML comment at slide end |
| `#v(0.6em)` | Blank line | Natural markdown spacing |
| `#text(fill: palette-accent)[...]` | `<span class="text-blue-400">...</span>` | UnoCSS utility or scoped CSS |
| `#align(center)[...]` | `layout: center` or `<div class="text-center">` | Frontmatter or CSS |
| `[TODO: ...]` | `[TODO: ...]` | Identical marker format |
| `typst compile deck.typ` | `slidev export deck.md` | Different CLI tool |
| `\$2M` (escaped dollar) | `$2M` or `2M USD` | No escaping needed for plain text |
