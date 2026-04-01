# Teammate B Findings: Indexing System and Agent Search for Deck Library

**Task**: 345 - Port /deck command-skill-agent from Typst to Slidev
**Date**: 2026-04-01
**Focus**: Deck library index schema, deck-planner agent workflow, search query patterns, and deck summary format

---

## Executive Summary

The deck-planner-agent currently presents three hard-coded AskUserQuestion prompts (template, slide selection, ordering) drawn from a flat list of 5 templates. Extending the system to support a library of reusable slide patterns, animations, styling presets, and deck structures requires a `deck-library/index.json` that mirrors the existing `.claude/context/index.json` schema — extending it with deck-domain fields (category, visual_style, animation_complexity, content_slots, compatibility). The interactive workflow should expand from 3 to 6 sequential steps that progressively narrow the option space, terminating in a full deck plan that references named library entries. Query patterns can be implemented with straightforward `jq` one-liners that apply tag intersection and enum comparisons. A "deck summary" markdown file (the Deck Configuration section, already begun in the plan format) should be expanded into a richer commented document suitable for both human review and agent re-ingestion.

---

## 1. Index Schema Design

**Confidence: high** — schema is modeled directly on `.claude/context/index.json` (confirmed by reading the live file) with deck-domain extensions informed by 3D asset library metadata standards and Slidev addon/theme manifests.

### 1.1 Design Principles

The existing `index.json` schema uses four layers: path, domain/subdomain, summary/keywords/topics, and `load_when` (agents/languages/commands). For the deck library index, these translate to:

- `path` — file path to the pattern, template, or preset file
- `category` + `subcategory` — replaces `domain`/`subdomain`
- `summary` + `tags` — replaces `summary`/`keywords`/`topics`; tags are multi-dimensional (visual style, content type, deck mode, mood)
- `filter_when` — replaces `load_when`; supports `deck_mode`, `themes`, `content_types`, `complexity`

Key lessons from 3D asset library metadata (sloyd.ai) apply here:
- Use controlled vocabularies for style tags (prevent "dark", "Dark", "dark-mode" fragmentation)
- Hierarchical filtering: deck_mode > content_type > visual_style
- Modular schema: universal core fields + category-specific extensions

### 1.2 Top-Level Index Structure

```json
{
  "version": "1.0",
  "generated": "ISO8601",
  "schema": "deck-library/index.schema.json",
  "entries": []
}
```

### 1.3 Protocol Entry Schema

Protocols are slide construction patterns — reusable approaches for a given slide type (e.g., "metric callout with v-click reveal", "two-column team layout").

```json
{
  "id": "protocol-metric-callout",
  "path": "deck-library/protocols/metric-callout.md",
  "category": "protocol",
  "subcategory": "data-reveal",
  "name": "Metric Callout",
  "summary": "Large metric with supporting label and v-click reveal sequence",
  "tags": {
    "visual_style": ["minimal", "data-focused"],
    "mood": ["confident", "growth"],
    "content_type": ["traction", "financials", "market"],
    "deck_mode": ["pitch", "update", "demo"],
    "animation_complexity": "medium"
  },
  "required_layouts": ["fact", "center"],
  "content_slots": ["metric_value", "metric_label", "context_note"],
  "compatible_themes": ["seriph", "default", "dracula"],
  "example_preview_path": "deck-library/previews/protocol-metric-callout.png",
  "line_count": 45
}
```

### 1.4 Animation Entry Schema

```json
{
  "id": "anim-v-click-cascade",
  "path": "deck-library/animations/v-click-cascade.md",
  "category": "animation",
  "name": "v-click Cascade",
  "animation_type": "click",
  "complexity": "low",
  "summary": "Sequential v-click reveals for bullet lists, best for problem/solution framing",
  "tags": {
    "best_for": ["problem", "solution", "team"],
    "mood": ["structured", "methodical"],
    "deck_mode": ["pitch", "internal"]
  },
  "syntax_example": "<v-clicks>\n\n- Item one\n- Item two\n\n</v-clicks>",
  "line_count": 20
}
```

**Animation types (controlled vocabulary)**:
- `transition` — slide-level transitions (fade, slide-left, view-transition)
- `click` — v-click / v-clicks sequential reveals
- `motion` — v-motion with enter/leave/initial states
- `mark` — v-mark text highlighting (circle, underline, highlight)

**Complexity levels**: `low` | `medium` | `high`
- low: single v-clicks list, no JavaScript
- medium: v-motion with one axis, v-mark on key phrase
- high: coordinated v-motion + v-click + view-transition

### 1.5 Styling Preset Entry Schema

```json
{
  "id": "preset-dark-blue-navy",
  "path": "deck-library/presets/dark-blue-navy.md",
  "category": "preset",
  "name": "Dark Blue Navy",
  "summary": "Deep navy background with blue accent, Inter body, Montserrat headings",
  "color_scheme": {
    "background": "#1e293b",
    "primary": "#60a5fa",
    "text": "#e2e8f0",
    "accent": "#38bdf8"
  },
  "font_pairing": {
    "heading": "Montserrat",
    "body": "Inter"
  },
  "background_type": "solid",
  "tags": {
    "mood": ["professional", "confident", "technical"],
    "visual_style": ["dark", "minimal"],
    "deck_mode": ["pitch", "demo"]
  },
  "base_theme": "seriph",
  "color_schema": "dark",
  "line_count": 35
}
```

### 1.6 Slide Template Entry Schema

```json
{
  "id": "template-cover-dark-blue",
  "path": "deck-library/templates/cover-dark-blue.md",
  "category": "template",
  "protocol_id": "protocol-cover-statement",
  "preset_id": "preset-dark-blue-navy",
  "name": "Cover Slide — Dark Blue",
  "summary": "Full-bleed cover with company name, subtitle, and v-motion entrance",
  "content_slots": ["company_name", "tagline", "presenter_name", "date"],
  "tags": {
    "slide_type": ["cover", "title"],
    "visual_style": ["dark", "minimal"],
    "mood": ["bold", "confident"]
  },
  "example_preview_path": "deck-library/previews/template-cover-dark-blue.png",
  "line_count": 40
}
```

### 1.7 Deck Structure Entry Schema

```json
{
  "id": "structure-yc-10-slide",
  "path": "deck-library/structures/yc-10-slide.md",
  "category": "structure",
  "name": "YC 10-Slide",
  "summary": "Standard YC pitch format: Title, Problem, Solution, Market, BizModel, Traction, Team, Competition, Financials, Ask",
  "deck_mode": "pitch",
  "slide_sequence": [
    {"position": 1, "slide_type": "cover",        "protocol_hint": "protocol-cover-statement"},
    {"position": 2, "slide_type": "problem",      "protocol_hint": "protocol-problem-framing"},
    {"position": 3, "slide_type": "solution",     "protocol_hint": "protocol-solution-reveal"},
    {"position": 4, "slide_type": "market",       "protocol_hint": "protocol-market-size"},
    {"position": 5, "slide_type": "biz-model",    "protocol_hint": "protocol-revenue-table"},
    {"position": 6, "slide_type": "traction",     "protocol_hint": "protocol-metric-callout"},
    {"position": 7, "slide_type": "team",         "protocol_hint": "protocol-team-two-col"},
    {"position": 8, "slide_type": "competition",  "protocol_hint": "protocol-comparison-matrix"},
    {"position": 9, "slide_type": "financials",   "protocol_hint": "protocol-metric-callout"},
    {"position": 10,"slide_type": "ask",          "protocol_hint": "protocol-ask-statement"}
  ],
  "required_protocols": [
    "protocol-cover-statement",
    "protocol-metric-callout",
    "protocol-team-two-col"
  ],
  "tags": {
    "deck_mode": ["pitch"],
    "audience": ["investor", "vc"],
    "style_compatibility": ["dark", "minimal", "professional"]
  },
  "line_count": 55
}
```

### 1.8 Index Schema Summary

| Category | Key Extension Fields | Query Axes |
|----------|---------------------|------------|
| `protocol` | content_slots, required_layouts, compatible_themes | content_type, visual_style, deck_mode |
| `animation` | animation_type, complexity, syntax_example | complexity, best_for, deck_mode |
| `preset` | color_scheme, font_pairing, base_theme | mood, visual_style, color_schema |
| `template` | protocol_id, preset_id, content_slots | slide_type, visual_style, mood |
| `structure` | slide_sequence, required_protocols | deck_mode, audience |

---

## 2. Deck-Planner Agent Workflow

**Confidence: high** — current 3-step workflow fully documented in `deck-planner-agent.md` (read directly); expansion to 6 steps is additive and does not break any existing fields.

### 2.1 Workflow Overview

The current agent asks 3 AskUserQuestion interactions. The expanded library-aware workflow adds 3 upstream steps before the existing slide-selection and ordering steps:

```
Step 1: Style Selection      (NEW) — pick aesthetic / mood
Step 2: Deck Structure       (NEW) — pick deck type / mode
Step 3: Pattern Selection    (NEW) — pick protocols per slide
Step 4: Slide Selection      (existing Stage 4) — main vs appendix
Step 5: Slide Ordering       (existing Stage 5) — arrangement strategy
Step 6: Plan Generation      (existing Stage 6) — produce plan
```

### 2.2 Step 1: Style Selection

**What the agent queries from the index**:
```bash
jq -r '.entries[] | select(.category == "preset") | .id + " | " + .name + " | " + (.tags.mood | join(", "))' deck-library/index.json
```

**What is presented to the user** (AskUserQuestion, single-select):
```
question: "What aesthetic should your deck have?"
options:
  - "Dark Blue Navy -- Deep navy, confident, technical. Best for: investor pitches, demo day"
  - "Minimal Light -- Clean white, structured, precise. Best for: update decks, internal reviews"
  - "Premium Dark -- Near-black with gold, bold, premium. Best for: keynotes, Series A+"
  - "Growth Green -- Mint and green, energetic, growth-stage. Best for: traction-focused pitches"
  - "Professional Blue -- Corporate navy, trustworthy. Best for: B2B, partnership decks"
```

**How selection narrows subsequent options**: The chosen `preset_id` is stored in intermediate state. Steps 2-3 filter protocols by `compatible_themes` matching the preset's `base_theme`.

**Intermediate state after Step 1**:
```json
{
  "selected_preset_id": "preset-dark-blue-navy",
  "selected_preset_name": "Dark Blue Navy",
  "base_theme": "seriph",
  "color_schema": "dark"
}
```

### 2.3 Step 2: Deck Structure Selection

**What the agent queries from the index**:
```bash
jq -r '.entries[] | select(.category == "structure") | .id + " | " + .name + " | " + .deck_mode' deck-library/index.json
```

**What is presented to the user** (AskUserQuestion, single-select):
```
question: "What type of deck are you building?"
options:
  - "YC 10-Slide -- Standard investor pitch: Title → Problem → Solution → Market → BizModel → Traction → Team → Competition → Financials → Ask"
  - "Lightning 5-Slide -- Fast 5-minute pitch: Title → Problem → Solution → Traction → Ask"
  - "Demo Day 7-Slide -- Accelerator demo: Title → Problem → Solution → Traction → Team → Market → Ask"
  - "Partnership One-Pager -- Single-page overview: Company → Value Prop → How It Works → Why Partner"
```

**How selection narrows subsequent options**: The chosen structure's `slide_sequence` defines which slide types appear in Step 3. The `protocol_hint` fields pre-populate protocol recommendations.

**Intermediate state after Step 2**:
```json
{
  "selected_preset_id": "preset-dark-blue-navy",
  "selected_structure_id": "structure-yc-10-slide",
  "deck_mode": "pitch",
  "slide_sequence": [
    {"position": 1, "slide_type": "cover", "protocol_hint": "protocol-cover-statement"},
    ...
  ]
}
```

### 2.4 Step 3: Pattern Selection

**What the agent queries from the index**: For each slide type in the structure's `slide_sequence`, find matching protocols filtered by preset compatibility:

```bash
# For each slide_type in the structure:
jq -r --arg slide_type "traction" --arg theme "seriph" '
  .entries[] | select(
    .category == "protocol" and
    any(.tags.content_type[]?; . == $slide_type) and
    any(.compatible_themes[]?; . == $theme)
  ) | .id + " | " + .name + " | Complexity: " + .tags.animation_complexity
' deck-library/index.json
```

**What is presented to the user** (AskUserQuestion, multi-select per slide type or grouped):

Instead of per-slide questions (too granular), present a grouped summary with protocol alternatives for slides that have multiple options:

```
question: "Review the pattern assignments for your deck. Select any you'd like to change:"
options:
  - "[Slide 1: Cover]  Using: Cover Statement (minimal entrance). Change?"
  - "[Slide 4: Market] Using: TAM/SAM/SOM Bubble (medium complexity). Change to: Simple Market Fact?"
  - "[Slide 6: Traction] Using: Metric Callout (v-click reveal). Change to: Traction Timeline?"
  - "[Slide 7: Team] Using: Two-Column Team (standard). Change to: Team Grid (dense)?"
  - "Keep all defaults (no changes)"
multiSelect: true
```

**How selection narrows subsequent options**: Selected overrides are resolved before Step 4. The final `protocol_manifest` (slide_position -> protocol_id) feeds the slide-content-slot mapping in Step 4.

**Intermediate state after Step 3**:
```json
{
  "selected_preset_id": "preset-dark-blue-navy",
  "selected_structure_id": "structure-yc-10-slide",
  "protocol_manifest": {
    "1": "protocol-cover-statement",
    "2": "protocol-problem-framing",
    "6": "protocol-metric-callout"
  }
}
```

### 2.5 Step 4: Slide Content Assignment (existing Stage 4, extended)

Carries over from the current `deck-planner-agent.md` Stage 4 without structural changes. The content options are built dynamically from the research report. The protocol_manifest is appended to the intermediate state.

### 2.6 Step 5: Slide Ordering (existing Stage 5, unchanged)

Carries over from the current Stage 5 without changes (YC Standard / Story-First / Traction-Led).

### 2.7 Step 6: Plan Generation (existing Stage 6, extended Deck Configuration section)

The plan's "Deck Configuration" section is expanded to include library references (see Section 4 below for the full deck summary format).

### 2.8 Intermediate State Structure (Full)

```json
{
  "stage": "complete",
  "selected_preset": {
    "id": "preset-dark-blue-navy",
    "name": "Dark Blue Navy",
    "base_theme": "seriph",
    "color_schema": "dark"
  },
  "selected_structure": {
    "id": "structure-yc-10-slide",
    "name": "YC 10-Slide",
    "deck_mode": "pitch"
  },
  "protocol_manifest": {
    "1": {"protocol_id": "protocol-cover-statement", "slide_type": "cover"},
    "2": {"protocol_id": "protocol-problem-framing", "slide_type": "problem"},
    "3": {"protocol_id": "protocol-solution-reveal", "slide_type": "solution"},
    "4": {"protocol_id": "protocol-market-size", "slide_type": "market"},
    "5": {"protocol_id": "protocol-revenue-table", "slide_type": "biz-model"},
    "6": {"protocol_id": "protocol-metric-callout", "slide_type": "traction"},
    "7": {"protocol_id": "protocol-team-two-col", "slide_type": "team"},
    "8": {"protocol_id": "protocol-comparison-matrix", "slide_type": "competition"},
    "9": {"protocol_id": "protocol-metric-callout", "slide_type": "financials"},
    "10": {"protocol_id": "protocol-ask-statement", "slide_type": "ask"}
  },
  "main_slides": [1, 2, 3, 4, 5, 6, 7, 10],
  "appendix_slides": [8, 9],
  "ordering": "YC Standard",
  "slide_order": [1, 2, 3, 4, 5, 6, 7, 10]
}
```

---

## 3. Search Query Patterns

**Confidence: high** — jq patterns derived from existing `.claude/context/index.json` query patterns documented in `CLAUDE.md`; adapted for deck-library schema using `| not` safety pattern (Claude Code Issue #1132).

### 3.1 Find Protocols by Tag and Theme Compatibility

```bash
# Find all protocols tagged 'traction' that work with 'seriph' theme
jq -r --arg content "traction" --arg theme "seriph" '
  .entries[] | select(
    .category == "protocol" and
    (any(.tags.content_type[]?; . == $content)) and
    (any(.compatible_themes[]?; . == $theme))
  ) | {id, name, animation_complexity: .tags.animation_complexity, content_slots}
' deck-library/index.json
```

### 3.2 List Deck Structures by Mode

```bash
# List deck structures for 'pitch' mode
jq -r --arg mode "pitch" '
  .entries[] | select(
    .category == "structure" and
    .deck_mode == $mode
  ) | .id + " | " + .name + " (" + (.slide_sequence | length | tostring) + " slides)"
' deck-library/index.json
```

### 3.3 Animations by Complexity Ceiling

```bash
# Show animations with complexity 'low' or 'medium' (exclude 'high')
jq -r '
  .entries[] | select(
    .category == "animation" and
    (.complexity == "high" | not)
  ) | .id + " | " + .name + " | " + .complexity + " | best_for: " + (.tags.best_for | join(", "))
' deck-library/index.json
```

### 3.4 Find Templates with Specific Content Slots

```bash
# Find slide templates with content slots matching 'team_member'
jq -r --arg slot "team_member" '
  .entries[] | select(
    .category == "template" and
    any(.content_slots[]?; . == $slot)
  ) | .id + " | " + .name + " | slots: " + (.content_slots | join(", "))
' deck-library/index.json
```

### 3.5 Find All Presets for a Visual Style

```bash
# Find dark, minimal presets
jq -r --arg style1 "dark" --arg style2 "minimal" '
  .entries[] | select(
    .category == "preset" and
    any(.tags.visual_style[]?; . == $style1) and
    any(.tags.visual_style[]?; . == $style2)
  ) | .id + " | " + .name
' deck-library/index.json
```

### 3.6 Compatibility Check — Protocols for a Structure

```bash
# Check which protocols are required by a given structure
jq -r --arg struct_id "structure-yc-10-slide" '
  .entries[] | select(.id == $struct_id) |
  .required_protocols[]
' deck-library/index.json
```

### 3.7 Combined Context Load Query (Agent Pattern)

```bash
# Load all entries relevant to deck-planner-agent
jq -r --arg agent "deck-planner-agent" '
  .entries[] | select(
    (.load_when.always == true) or
    (any(.load_when.agents[]?; . == $agent))
  ) | .path
' deck-library/index.json
```

---

## 4. Deck Summary Markdown Format

**Confidence: medium** — format is designed as an extension of the existing "Deck Configuration" section in `deck-planner-agent.md` Stage 6, expanded to support library references and build instructions. No exact precedent exists in the current codebase for a standalone deck summary file; the design is inferred from the pattern of `pitch-deck-structure.md` and the plan format standard.

The deck summary serves two audiences: (1) a human reviewer who wants to understand every ingredient in the deck before building it, and (2) the deck-builder-agent that needs to re-ingest it to generate Slidev markdown. It should be self-contained.

### 4.1 File Location

```
specs/{NNN}_{SLUG}/plans/{NN}_{short-slug}-deck-summary.md
```

Example: `specs/345_port_deck_typst_to_slidev/plans/05_deck-summary.md`

### 4.2 Full Format

```markdown
# Deck Summary: {Company Name} — {Deck Purpose}

<!-- Auto-generated by deck-planner-agent. Human-editable. -->

**Task**: {N}
**Generated**: ISO8601 timestamp
**Structure**: {structure_name} ({slide_count} slides)
**Mode**: {deck_mode}

---

## 1. Styling Decisions

<!-- Why this preset was chosen: mood match, audience, color schema. -->

| Field | Value | Reasoning |
|-------|-------|-----------|
| Preset | {preset_name} ({preset_id}) | {one-sentence justification} |
| Base Theme | {base_theme} | {e.g., "seriph chosen for serif typography gravitas"} |
| Color Schema | dark / light | {e.g., "dark for AI startup aesthetic"} |
| Primary Color | #{hex} | {e.g., "Blue accent for trust"} |
| Font: Heading | {font} | |
| Font: Body | {font} | |

---

## 2. Protocol Selections

<!-- Which protocol was chosen for each slide and why. -->

| Position | Slide Type | Protocol ID | Protocol Name | Rationale |
|----------|-----------|-------------|---------------|-----------|
| 1 | cover | protocol-cover-statement | Cover Statement | Full-bleed with v-motion entrance, company name prominent |
| 2 | problem | protocol-problem-framing | Problem Framing | v-click cascade for 3 pain points |
| 3 | solution | protocol-solution-reveal | Solution Reveal | Split layout with icon + text |
| ... | ... | ... | ... | ... |

---

## 3. Animation Choices Per Slide

<!-- Animation decisions made by protocol selection + any overrides. -->

| Position | Slide Type | Animation ID | Type | Complexity | Notes |
|----------|-----------|--------------|------|------------|-------|
| 1 | cover | anim-v-motion-entrance | motion | low | Company name slides up on load |
| 2 | problem | anim-v-click-cascade | click | low | Three problems reveal one-by-one |
| 6 | traction | anim-v-click-metric | click | medium | Metric number + v-mark on growth % |
| ... | ... | ... | ... | ... | ... |

---

## 4. Slide Manifest and Content Slot Mappings

<!-- Full slide inventory with content status and slot -> value mappings. -->

### Main Deck ({N} slides)

#### Slide 1: Cover
- **Layout**: `cover`
- **Protocol**: protocol-cover-statement
- **Content Slots**:
  - `company_name` → "Acme AI"
  - `tagline` → "Autonomous agents for logistics"
  - `presenter_name` → "Jane Smith"
  - `date` → "April 2026"
- **Status**: Populated

#### Slide 6: Traction
- **Layout**: `fact`
- **Protocol**: protocol-metric-callout
- **Content Slots**:
  - `metric_value` → "$2.4M ARR"
  - `metric_label` → "Annual Recurring Revenue"
  - `context_note` → "3× YoY growth"
- **Status**: Populated
- **Animation Override**: v-mark on "3×"

#### Slide {N}: {Slide Name}
<!-- ... repeat for each main slide ... -->

### Appendix ({M} slides)

| Position | Slide Type | Protocol | Reason Deselected |
|----------|-----------|----------|-------------------|
| 8 | competition | protocol-comparison-matrix | Insufficient data — 3 fields MISSING |
| 9 | financials | protocol-metric-callout | User deselected — will add manually |

---

## 5. Content Gaps

<!-- Gaps identified in research phase with handling strategy. -->

| Slide | Gap | Severity | Strategy |
|-------|-----|----------|----------|
| 4 (Market) | SAM/SOM breakdown missing | Critical | Use [TODO: add SAM/SOM breakdown] placeholder |
| 8 (Competition) | Competitor pricing not extracted | Nice-to-have | Move to appendix |

---

## 6. Build and Export Instructions

<!-- How to generate and export the final deck. -->

### Prerequisites
```bash
# Install Slidev (if not already installed)
npm install -g @slidev/cli

# Install theme
npm install slidev-theme-seriph

# Install playwright for PDF export (optional)
npx playwright install chromium
```

### Generate and Preview
```bash
# Navigate to deck output directory
cd strategy/{slug}-deck/

# Start dev server
slidev slides.md

# Export to PDF (requires playwright-chromium)
slidev export slides.md --format pdf --output {slug}-deck.pdf

# Export to static site
slidev build slides.md
```

### Output Files
- `strategy/{slug}-deck/slides.md` — Main Slidev presentation (primary output)
- `strategy/{slug}-deck/{slug}-deck.pdf` — PDF export (optional, requires chromium)
- `strategy/{slug}-deck/dist/` — Static site export (optional)

---

## 7. Revision Notes

<!-- Track changes from original plan if this summary has been revised. -->

| Version | Date | Change | Reason |
|---------|------|--------|--------|
| v1 | {date} | Initial generation | deck-planner-agent output |

```

### 4.3 Key Design Decisions

1. **Human-readable rationale columns** — Every selection includes a "Reasoning" or "Rationale" field. This enables the human reviewer to spot mismatch (e.g., "dark theme chosen but I need a light one for a morning client meeting") before build.

2. **Content slot mapping as table rows** — The deck-builder-agent can parse this directly with a structured grep or jq-over-YAML approach, without re-reading the research report.

3. **Appendix table with reason** — Explicitly records *why* slides were deselected, which matters if a user later wants to re-include one.

4. **Gap handling strategy** — Not just "gap exists" but "how the builder should handle it" (`[TODO:]` placeholder vs. move to appendix vs. use fallback content).

5. **Build instructions section** — Self-contained reproduction instructions, including the non-blocking pattern (PDF is optional, `.md` is always valid).

---

## 5. Fit with Existing Architecture

**Confidence: high** — analyzed directly against `deck-planner-agent.md` and `.claude/context/index.json`.

### 5.1 Where the Index Lives

The deck library index should live at:
```
.claude/extensions/founder/context/project/founder/deck-library/index.json
```

This follows the existing pattern where extension context lives under `.claude/extensions/{ext}/context/`. The index is discoverable via the extension context loader and can be merged into the main `context/index.json` via the `load_when` mechanism.

### 5.2 Index Entry in Context Index

Add an entry to the founder extension's `index-entries.json`:

```json
{
  "path": "context/project/founder/deck-library/index.json",
  "domain": "founder",
  "subdomain": "deck-library",
  "summary": "Deck library index: protocols, animations, presets, templates, structures",
  "line_count": 250,
  "keywords": ["deck", "slide", "protocol", "animation", "preset", "template"],
  "topics": ["deck-generation", "slidev"],
  "load_when": {
    "agents": ["deck-planner-agent", "deck-builder-agent"],
    "languages": ["founder"],
    "commands": ["/deck"]
  }
}
```

### 5.3 Minimal Impact on Current System

The 6-step workflow is backward-compatible with the current 3-step workflow:
- Steps 1-3 (new) can be made optional with a `--quick` flag matching the existing `/deck --quick` shortcut
- If `--quick` is passed, skip Steps 1-3 and use defaults (first preset, first structure, all protocol hints from structure)
- Steps 4-6 are identical to the current Stages 4-6 in `deck-planner-agent.md`

---

## 6. Observations from AI Presentation Tool Research

**Confidence: medium** — based on web search results and documentation fetches; exact internal schemas not publicly available for commercial tools.

### 6.1 Gamma's Step-Wise Selection Workflow

Gamma uses a 4-path entry: Generate from prompt, Paste text, Generate from template, Import file. The key insight from Gamma's interaction design:

- **Format selection before content** — users pick output format (Presentation, Document, Webpage) before any content is input
- **Theme selection is a dedicated screen** — 100+ theme options presented visually, not as text list
- **AI reskins entire deck in one click** — after initial generation, style changes are applied globally

For the deck-planner-agent, this suggests: present preset selection (Step 1) in a richer format showing color swatches and typography samples (feasible via AskUserQuestion description text).

### 6.2 Beautiful.ai SmartSlide Categorization

Beautiful.ai organizes slide templates by "SmartSlide type" (timeline, Venn, flowchart, bar graph, team, etc.) — which maps closely to the `protocol` category in the proposed index. The types are content-driven (what you're communicating) rather than visual-driven (how it looks). This validates the decision to tag protocols by `content_type` rather than just `visual_style`.

### 6.3 Slidev Addon Manifest Pattern

Slidev theme packages declare capabilities in `package.json` under a `slidev` block:
```json
{
  "slidev": {
    "defaults": { "transition": "slide-left" },
    "colorSchema": "dark"
  }
}
```

This is structurally similar to the proposed preset entries (preset declares `base_theme`, `color_schema`, `defaults`). The deck library index essentially externalizes this metadata from the theme package into a queryable JSON catalog.

---

## 7. Recommendations for Implementation

1. **Start with the index schema file** (`deck-library/index.schema.json`) before populating entries — define the controlled vocabularies upfront to prevent tag drift.

2. **Seed with 5 presets, 10 protocols, 3 structures, 5 animations** — matching the existing 5 templates and 3 orderings, ensuring zero regression on current behavior.

3. **Add `--quick` bypass flag** — the 6-step flow is richer but longer; `--quick` skips Steps 1-3 and uses `structure-yc-10-slide` + the preset matching the template the user would have selected in the old flow.

4. **Store intermediate state to metadata file** — write the `intermediate_state` JSON to `.return-meta.json` after each AskUserQuestion step. If the agent is interrupted mid-workflow, the next `/plan` invocation can detect the partial state and resume.

5. **Deck summary as standalone file** — generate `{NN}_{short-slug}-deck-summary.md` alongside the plan, so the builder agent can load the summary directly without parsing the full plan for configuration data.

---

## Sources

- [Slidev Directory Structure](https://sli.dev/custom/directory-structure)
- [Slidev Component Guide](https://sli.dev/guide/component)
- [Slidev Writing Themes](https://sli.dev/guide/write-theme)
- [Slidev Writing Addons](https://sli.dev/guide/write-addon)
- [Slidev Animation Docs](https://sli.dev/guide/animations.html)
- [Slidev Theme Gallery](https://sli.dev/resources/theme-gallery)
- [Sloyd.ai: Metadata Schema for 3D Asset Libraries](https://www.sloyd.ai/blog/metadata-schema-for-3d-asset-libraries)
- [Gamma.app AI Presentation Maker](https://gamma.app/)
- [Gamma Review 2026](https://max-productive.ai/ai-tools/gamma/)
- [Beautiful.ai Smart Slides](https://www.beautiful.ai/smart-slides)
- [Presenton Open Source AI Presentation Generator](https://github.com/presenton/presenton)
- [Slidev Addon Components (estruyf)](https://github.com/estruyf/slidev-addon-components)
- [DeepWiki: Slidev Animation and Transitions](https://deepwiki.com/slidevjs/slidev/4.2-animation-and-transitions)
