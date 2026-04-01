# Research Report: Complete Slidev Deck System Design

**Task**: 345 - Port /deck command-skill-agent from Typst to Slidev
**Started**: 2026-04-01T00:00:00Z
**Completed**: 2026-04-01T01:30:00Z
**Effort**: Large
**Dependencies**: 01_slidev-port-research.md, 02_slidev-standards.md, 03_refactor-analysis.md, 05_deck-library-system.md, plans/02_implementation-plan.md
**Sources/Inputs**: All 5 prior research reports, 3 deck agent files, deck command, Slidev official docs, web search
**Artifacts**: specs/345_port_deck_typst_to_slidev/reports/03_slidev-system-design.md
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- The final Slidev deck system centers on a **reusable library at `.context/deck/`** with 6 subdirectories (themes, patterns, animations, styles, contents, components) indexed by a master `index.json` that agents query at planning time
- The **deck-planner-agent** is redesigned as a 5-step interactive workflow: (1) pattern selection, (2) theme selection, (3) content selection from library + new content identification, (4) slide ordering, (5) plan generation with import map
- The **content library** at `.context/deck/contents/` stores reusable markdown slide snippets with header comments documenting slot types, compatible layouts, and import instructions; the builder populates new content back to the library after each deck build
- The **deck-builder-agent** uses the plan's import map to assemble slides from content library files, apply theme/style presets, add animations per protocol, and generate the final `slides.md`
- This design supersedes the existing 5-phase implementation plan (02_implementation-plan.md) which focused only on a 1:1 Typst-to-Slidev port; this report defines the richer library-based architecture

---

## A. Library Architecture

### A.1 Directory Structure

```
.context/deck/
├── index.json                    # Master index for all library resources
├── themes/                       # Slidev theme configurations
│   ├── dark-blue.json           # Theme config: seriph + dark + navy palette
│   ├── minimal-light.json       # Theme config: seriph + light + clean palette
│   ├── premium-dark.json        # Theme config: seriph + dark + gold palette
│   ├── growth-green.json        # Theme config: seriph + light + green palette
│   └── professional-blue.json   # Theme config: seriph + light + corporate palette
├── patterns/                     # Deck structural patterns (slide sequences)
│   ├── yc-10-slide.json         # YC standard 10-slide investor pitch
│   ├── lightning-5-slide.json   # 5-minute lightning talk
│   ├── product-demo.json        # Product demonstration (8-12 slides)
│   ├── investor-update.json     # Quarterly investor update
│   └── partnership-proposal.json # Business partnership pitch
├── animations/                   # Reusable animation pattern definitions
│   ├── fade-in.md               # CSS fade entrance
│   ├── slide-in-below.md        # v-motion y-axis entrance
│   ├── metric-cascade.md        # Staggered v-motion for KPI slides
│   ├── rough-marks.md           # v-mark emphasis patterns
│   ├── staggered-list.md        # v-clicks with depth/every
│   └── scale-in-pop.md          # v-motion spring scale for CTAs
├── styles/                       # CSS presets (composable)
│   ├── colors/
│   │   ├── dark-blue-navy.css   # AI startup default
│   │   ├── dark-gold-premium.css # Luxury/fintech
│   │   ├── light-green-growth.css # Sustainability/biotech
│   │   └── light-blue-corp.css  # Enterprise/professional
│   ├── typography/
│   │   ├── montserrat-inter.css # Default: Montserrat headings + Inter body
│   │   ├── playfair-inter.css   # Serif headings + Inter body
│   │   └── inter-only.css       # All-sans clean look
│   └── textures/
│       ├── grid-overlay.css     # Subtle grid background
│       └── noise-grain.css      # Film grain SVG overlay
├── contents/                     # Reusable slide content library
│   ├── cover/
│   │   ├── cover-standard.md    # Standard title + tagline + round
│   │   └── cover-hero.md        # Full-bleed image cover variant
│   ├── problem/
│   │   ├── problem-statement.md # Bold single-sentence + 3 evidence points
│   │   └── problem-story.md     # Narrative problem framing
│   ├── solution/
│   │   ├── solution-two-col.md  # Two-column benefit/mechanism split
│   │   └── solution-demo.md     # Solution with screenshot/demo callout
│   ├── traction/
│   │   ├── traction-metrics.md  # 3-metric reveal with AutoFitText
│   │   └── traction-chart.md    # Bar chart growth visualization
│   ├── market/
│   │   ├── market-tam-sam-som.md # Mermaid TAM/SAM/SOM diagram
│   │   └── market-narrative.md  # Text-based market sizing
│   ├── team/
│   │   ├── team-two-col.md      # Two-column founder grid
│   │   └── team-grid.md         # Multi-member grid layout
│   ├── ask/
│   │   ├── ask-centered.md      # Centered raise + allocation breakdown
│   │   └── ask-milestone.md     # Raise + milestone timeline
│   ├── business-model/
│   │   ├── biz-model-pricing.md # Revenue model + unit economics
│   │   └── biz-model-saas.md    # SaaS-specific metrics layout
│   ├── why-us-now/
│   │   ├── why-us-now-split.md  # Two-column Why Us | Why Now
│   │   └── why-us-moat.md       # Technical moat emphasis
│   ├── closing/
│   │   ├── closing-standard.md  # Company name + contact
│   │   └── closing-cta.md       # Call-to-action with next steps
│   └── appendix/
│       ├── appendix-financials.md # Financial projections
│       ├── appendix-competition.md # Competitive landscape
│       └── appendix-roadmap.md  # Product roadmap timeline
└── components/                   # Reusable Vue components
    ├── MetricCard.vue           # value, label, delay, color
    ├── TeamMember.vue           # name, role, bio, photo, delay
    ├── TimelineItem.vue         # date, label, description, status
    └── ComparisonCol.vue        # title, points, color, highlight
```

### A.2 Location Rationale

The library lives at `.context/deck/` (project context layer) rather than `.claude/extensions/founder/context/` (extension context layer) because:

1. **User-owned content**: The contents/ directory accumulates project-specific slide content over time -- this is project knowledge, not extension knowledge
2. **Cross-extension access**: Content written for one deck can be reused by any extension that generates presentations
3. **Separation of concerns**: Extensions define *how* to build decks (agents, skills, patterns); `.context/deck/` stores *what* to build with (themes, styles, reusable content)
4. **Matches context architecture**: Per `.claude/context/architecture/context-layers.md`, project conventions go in `.context/`, extension-specific patterns go in `.claude/extensions/`

The extension continues to own the agents, skills, command, and protocol definitions. The library is the shared resource pool they draw from.

### A.3 Relationship to Extension Context

```
.claude/extensions/founder/context/project/founder/
├── patterns/
│   ├── pitch-deck-structure.md      # YC 10-slide content rules (KEEP)
│   ├── slidev-deck-template.md      # Slidev syntax reference (NEW - replaces touying)
│   └── yc-compliance-checklist.md   # Validation rules (KEEP)
└── templates/slidev/deck/           # REMOVED - replaced by .context/deck/ library

.context/deck/                        # NEW - reusable library
├── index.json                        # Searchable by agents
├── themes/, patterns/, animations/, styles/, contents/, components/
```

The 5 Slidev templates from the original port plan are replaced by the combination of:
- `themes/*.json` (color/font configuration)
- `patterns/*.json` (slide sequence definitions)
- `contents/*/*.md` (reusable slide content)
- `styles/**/*.css` (composable style presets)

This is a more powerful and extensible architecture than 5 monolithic template files.

---

## B. Index Schema Design

### B.1 Master Index: `.context/deck/index.json`

```json
{
  "version": "1.0",
  "generated": "2026-04-01T00:00:00Z",
  "description": "Slidev deck library index for agent-driven deck construction",
  "categories": {
    "theme": {
      "description": "Slidev headmatter + themeConfig presets",
      "directory": "themes/"
    },
    "pattern": {
      "description": "Deck structural patterns defining slide sequences",
      "directory": "patterns/"
    },
    "animation": {
      "description": "Reusable animation pattern definitions with syntax examples",
      "directory": "animations/"
    },
    "style": {
      "description": "Composable CSS presets for colors, typography, textures",
      "directory": "styles/"
    },
    "content": {
      "description": "Reusable slide content markdown snippets",
      "directory": "contents/"
    },
    "component": {
      "description": "Reusable Vue components for slide construction",
      "directory": "components/"
    }
  },
  "entries": [
    {
      "id": "theme-dark-blue",
      "category": "theme",
      "name": "Dark Blue (AI Startup)",
      "path": "themes/dark-blue.json",
      "description": "Deep navy background with blue accents. Default for tech/AI presentations.",
      "tags": {
        "color_schema": "dark",
        "mood": ["professional", "technical", "modern"],
        "base_theme": "seriph"
      },
      "preview": {
        "primary": "#60a5fa",
        "background": "#1e293b",
        "text": "#e2e8f0"
      }
    },
    {
      "id": "theme-minimal-light",
      "category": "theme",
      "name": "Minimal Light",
      "path": "themes/minimal-light.json",
      "description": "Clean white background with blue accent. Best for data-heavy presentations.",
      "tags": {
        "color_schema": "light",
        "mood": ["clean", "minimal", "data-focused"],
        "base_theme": "seriph"
      },
      "preview": {
        "primary": "#3182ce",
        "background": "#ffffff",
        "text": "#2d3748"
      }
    },
    {
      "id": "theme-premium-dark",
      "category": "theme",
      "name": "Premium Dark (Gold)",
      "path": "themes/premium-dark.json",
      "description": "Near-black background with gold accents. Luxury/fintech positioning.",
      "tags": {
        "color_schema": "dark",
        "mood": ["luxury", "premium", "fintech"],
        "base_theme": "seriph"
      },
      "preview": {
        "primary": "#d4a574",
        "background": "#0f0f1a",
        "text": "#e8e0d4"
      }
    },
    {
      "id": "theme-growth-green",
      "category": "theme",
      "name": "Growth Green",
      "path": "themes/growth-green.json",
      "description": "Mint/white background with green accents. Sustainability, biotech, climate.",
      "tags": {
        "color_schema": "light",
        "mood": ["fresh", "sustainability", "biotech"],
        "base_theme": "seriph"
      },
      "preview": {
        "primary": "#38a169",
        "background": "#f0fdf4",
        "text": "#047857"
      }
    },
    {
      "id": "theme-professional-blue",
      "category": "theme",
      "name": "Professional Blue",
      "path": "themes/professional-blue.json",
      "description": "White background with navy/blue accents. Corporate, enterprise B2B.",
      "tags": {
        "color_schema": "light",
        "mood": ["corporate", "enterprise", "trustworthy"],
        "base_theme": "seriph"
      },
      "preview": {
        "primary": "#2b6cb0",
        "background": "#ffffff",
        "text": "#1a365d"
      }
    },
    {
      "id": "pattern-yc-10-slide",
      "category": "pattern",
      "name": "YC 10-Slide Investor Pitch",
      "path": "patterns/yc-10-slide.json",
      "description": "Standard Y Combinator 10-slide format: Title, Problem, Solution, Traction, Why Us/Now, Business Model, Market, Team, Ask, Closing.",
      "tags": {
        "deck_mode": ["INVESTOR"],
        "audience": ["investors", "VCs"],
        "slide_count": 10
      }
    },
    {
      "id": "pattern-lightning-5",
      "category": "pattern",
      "name": "Lightning Talk (5 slides)",
      "path": "patterns/lightning-5-slide.json",
      "description": "5-minute lightning talk: Cover, Problem+Solution, Traction, Demo, Ask.",
      "tags": {
        "deck_mode": ["LIGHTNING"],
        "audience": ["general", "conference"],
        "slide_count": 5
      }
    },
    {
      "id": "pattern-product-demo",
      "category": "pattern",
      "name": "Product Demo (8-12 slides)",
      "path": "patterns/product-demo.json",
      "description": "Product demonstration deck with screenshots, code, and live demo embeds.",
      "tags": {
        "deck_mode": ["DEMO"],
        "audience": ["technical", "product"],
        "slide_count": 10
      }
    },
    {
      "id": "pattern-investor-update",
      "category": "pattern",
      "name": "Investor Update",
      "path": "patterns/investor-update.json",
      "description": "Quarterly investor update: Highlights, Metrics, Financials, Runway, Priorities.",
      "tags": {
        "deck_mode": ["UPDATE"],
        "audience": ["existing-investors"],
        "slide_count": 8
      }
    },
    {
      "id": "pattern-partnership",
      "category": "pattern",
      "name": "Partnership Proposal",
      "path": "patterns/partnership-proposal.json",
      "description": "Business partnership pitch: Mutual value, problem/solution, market fit.",
      "tags": {
        "deck_mode": ["PARTNERSHIP"],
        "audience": ["partners", "enterprise"],
        "slide_count": 8
      }
    },
    {
      "id": "content-cover-standard",
      "category": "content",
      "name": "Standard Cover Slide",
      "path": "contents/cover/cover-standard.md",
      "description": "Title slide with company name, tagline, and funding round.",
      "tags": {
        "slide_type": "cover",
        "layout": "cover",
        "deck_mode": ["INVESTOR", "UPDATE", "PARTNERSHIP"]
      },
      "content_slots": ["company_name", "tagline", "funding_round", "date"]
    },
    {
      "id": "content-traction-metrics",
      "category": "content",
      "name": "Traction Metrics (3-up)",
      "path": "contents/traction/traction-metrics.md",
      "description": "Three key metrics with AutoFitText and progressive reveal.",
      "tags": {
        "slide_type": "traction",
        "layout": "fact",
        "deck_mode": ["INVESTOR", "LIGHTNING"]
      },
      "content_slots": ["metric_1_value", "metric_1_label", "metric_2_value", "metric_2_label", "metric_3_value", "metric_3_label", "context_note"]
    }
  ]
}
```

Note: The full index would contain entries for all files. The above shows the schema pattern with representative entries. Each category follows the same structure: `id`, `category`, `name`, `path`, `description`, `tags`, and category-specific fields (e.g., `content_slots` for content, `preview` for themes).

### B.2 Controlled Vocabularies

To prevent tag drift, the index uses controlled vocabularies:

| Field | Allowed Values |
|-------|---------------|
| `color_schema` | `dark`, `light` |
| `deck_mode` | `INVESTOR`, `UPDATE`, `INTERNAL`, `PARTNERSHIP`, `LIGHTNING`, `DEMO` |
| `mood` | `professional`, `technical`, `modern`, `clean`, `minimal`, `data-focused`, `luxury`, `premium`, `fintech`, `fresh`, `sustainability`, `biotech`, `corporate`, `enterprise`, `trustworthy` |
| `slide_type` | `cover`, `problem`, `solution`, `traction`, `market`, `team`, `ask`, `business-model`, `why-us-now`, `closing`, `appendix`, `section-divider`, `demo`, `timeline`, `quote`, `comparison` |
| `layout` | `cover`, `default`, `center`, `statement`, `fact`, `two-cols`, `two-cols-header`, `end`, `image`, `image-right`, `image-left`, `quote`, `section` |
| `base_theme` | `seriph`, `default`, `apple-basic`, `dracula` |

### B.3 Agent Query Patterns

The deck-planner-agent queries the index using jq:

```bash
# Get all patterns for a deck mode
jq -r '.entries[] | select(.category == "pattern") | select(any(.tags.deck_mode[]?; . == "INVESTOR")) | "\(.id): \(.name) - \(.description)"' .context/deck/index.json

# Get all themes (for selection UI)
jq -r '.entries[] | select(.category == "theme") | "\(.id)|\(.name)|\(.description)|\(.preview.primary)|\(.tags.color_schema)"' .context/deck/index.json

# Get content for a slide type
jq -r '.entries[] | select(.category == "content") | select(any(.tags.slide_type; . == "traction")) | "\(.id): \(.name) - \(.description)"' .context/deck/index.json

# Get animations by complexity
jq -r '.entries[] | select(.category == "animation") | select(.tags.complexity == "low") | "\(.id): \(.name)"' .context/deck/index.json
```

---

## C. Planner Workflow

### C.1 Overview

The deck-planner-agent expands from 3 interactive steps to 5 steps. The existing 3-step workflow (template, content assignment, ordering) maps to steps 2, 3, and 4. New steps 1 and 5 add pattern selection and import-map generation.

A `--quick` bypass skips steps 1-2, using defaults (YC 10-slide + dark-blue theme).

### C.2 Step-by-Step Flow

#### Step 1: Pattern Selection (AskUserQuestion - single select)

The agent queries `index.json` for patterns matching the task's deck_mode (from forcing_data.purpose). Presents options with descriptions.

```
Select a deck pattern:

1. YC 10-Slide Investor Pitch - Standard Y Combinator format: Title, Problem,
   Solution, Traction, Why Us/Now, Business Model, Market, Team, Ask, Closing (10 slides)
2. Lightning Talk - 5-minute format: Cover, Problem+Solution, Traction, Demo, Ask (5 slides)
3. Product Demo - Screenshots, code, live demo embeds (8-12 slides)
```

**Output**: `selected_pattern` with slide sequence and slide_type hints.

**State saved**: Write `partial_progress.pattern_selected` to `.return-meta.json`.

#### Step 2: Theme Selection (AskUserQuestion - single select)

The agent queries `index.json` for all themes. Presents with color preview information.

```
Select a visual theme:

1. Dark Blue (AI Startup) [dark] - Deep navy + blue accents (#60a5fa on #1e293b)
2. Minimal Light [light] - Clean white + blue accent (#3182ce on #fff)
3. Premium Dark (Gold) [dark] - Near-black + gold accents (#d4a574 on #0f0f1a)
4. Growth Green [light] - Mint/white + green accents (#38a169 on #f0fdf4)
5. Professional Blue [light] - White + navy/blue (#2b6cb0 on #fff)
```

**Output**: `selected_theme` with theme config and compatible styles.

**State saved**: Write `partial_progress.theme_selected` to `.return-meta.json`.

#### Step 3: Content Selection (AskUserQuestion - multi select + new content identification)

For each slide position in the selected pattern, the agent:
1. Queries content library for matching `slide_type` entries
2. Checks research report for available content
3. Presents existing library content + option to create new

```
Assign content for each slide position. For each, select from library or mark as NEW:

Slide 1 (cover):
  [x] cover-standard - Standard title + tagline + round
  [ ] cover-hero - Full-bleed image cover variant
  [ ] NEW - Create new cover content

Slide 2 (problem):
  [x] problem-statement - Bold single-sentence + 3 evidence points
  [ ] problem-story - Narrative problem framing
  [ ] NEW - Create new problem content

Slide 4 (traction):
  [ ] traction-metrics - 3-metric reveal with AutoFitText
  [x] NEW - Create new traction content (research has specific metrics)

Which slides should be MAIN vs APPENDIX?
Main: 1, 2, 3, 4, 5, 6, 7, 10
Appendix: 8, 9
```

**Output**: `content_manifest` mapping slide positions to content IDs or `NEW` markers, plus `main_slides` and `appendix_slides` lists.

**State saved**: Write `partial_progress.content_selected` to `.return-meta.json`.

#### Step 4: Slide Ordering (AskUserQuestion - single select)

```
Select slide ordering strategy:

1. YC Standard - Title, Problem, Solution, Traction, Why Us/Now, Business Model,
   Market, Team, Ask, Closing
2. Story-First - Title, Problem, Solution, Why Us/Now, Traction, Business Model,
   Market, Team, Ask, Closing
3. Traction-Led - Title, Traction, Problem, Solution, Why Us/Now, Market,
   Business Model, Team, Ask, Closing
```

**Output**: `ordering_strategy` and final `slide_order` array.

#### Step 5: Plan Generation

The agent generates an implementation plan with:

1. **Deck Configuration section** containing:
   - Selected pattern, theme, ordering
   - Content manifest (position -> content_id mapping)
   - Import map (which `.context/deck/contents/` files to import)
   - New content to create (listed with slot values from research)
   - Style composition (which CSS presets to import)
   - Animation assignments per slide

2. **Implementation phases**:
   - Phase 1: Populate new content in `.context/deck/contents/` (for `NEW` items)
   - Phase 2: Assemble `slides.md` from imports + new content
   - Phase 3: Apply theme headmatter, styles, animations
   - Phase 4: Export to PDF (non-blocking)

### C.3 Intermediate State (Full)

```json
{
  "stage": "complete",
  "selected_pattern": {
    "id": "pattern-yc-10-slide",
    "name": "YC 10-Slide Investor Pitch",
    "slide_sequence": [
      {"position": 1, "slide_type": "cover"},
      {"position": 2, "slide_type": "problem"},
      {"position": 3, "slide_type": "solution"},
      {"position": 4, "slide_type": "traction"},
      {"position": 5, "slide_type": "why-us-now"},
      {"position": 6, "slide_type": "business-model"},
      {"position": 7, "slide_type": "market"},
      {"position": 8, "slide_type": "team"},
      {"position": 9, "slide_type": "ask"},
      {"position": 10, "slide_type": "closing"}
    ]
  },
  "selected_theme": {
    "id": "theme-dark-blue",
    "config_path": "themes/dark-blue.json"
  },
  "content_manifest": {
    "1": {"content_id": "content-cover-standard", "source": "library"},
    "2": {"content_id": "content-problem-statement", "source": "library"},
    "3": {"content_id": "content-solution-two-col", "source": "library"},
    "4": {"content_id": null, "source": "new", "reason": "Custom metrics from research"},
    "5": {"content_id": "content-why-us-now-split", "source": "library"},
    "6": {"content_id": "content-biz-model-saas", "source": "library"},
    "7": {"content_id": "content-market-tam-sam-som", "source": "library"},
    "8": {"content_id": "content-team-two-col", "source": "library"},
    "9": {"content_id": "content-ask-centered", "source": "library"},
    "10": {"content_id": "content-closing-standard", "source": "library"}
  },
  "main_slides": [1, 2, 3, 4, 5, 6, 7, 10],
  "appendix_slides": [8, 9],
  "ordering": "YC Standard",
  "slide_order": [1, 2, 3, 4, 5, 6, 7, 10, 8, 9]
}
```

---

## D. Content Library System

### D.1 Content File Format

Each file in `.context/deck/contents/` is a self-contained Slidev markdown snippet with a header comment block documenting its metadata.

```markdown
<!-- CONTENT: cover-standard
     SLIDE_TYPE: cover
     LAYOUT: cover
     COMPATIBLE_MODES: INVESTOR, UPDATE, PARTNERSHIP
     CONTENT_SLOTS: company_name, tagline, funding_round, date
     ANIMATIONS: v-motion entrance (y + opacity)
     IMPORT: Use src frontmatter or copy directly into slides.md
     LAST_UPDATED: 2026-04-01
-->

---
layout: cover
---

# [SLOT: company_name]

<div class="text-xl opacity-80">
[SLOT: tagline]
</div>

<div class="abs-br m-6 text-sm opacity-50">
[SLOT: funding_round] | [SLOT: date]
</div>

<style>
h1 { font-family: 'Montserrat'; font-size: 3.5em; font-weight: 700; }
</style>

<!-- Speaker: Brief intro. State company name, what you do, why you're here. -->
```

### D.2 File Naming Convention

```
contents/{slide_type}/{slide_type}-{variant}.md
```

Examples:
- `contents/cover/cover-standard.md`
- `contents/traction/traction-metrics.md`
- `contents/team/team-two-col.md`
- `contents/appendix/appendix-financials.md`

### D.3 Slot Syntax

Content files use `[SLOT: slot_name]` markers (distinct from `[TODO:]` used in the old Typst templates). This distinction is intentional:

- `[SLOT: ...]` = Template placeholder in the reusable library, to be filled by the builder agent using research data
- `[TODO: ...]` = Gap marker in generated output indicating missing information

The builder replaces `[SLOT: ...]` with actual content and only uses `[TODO: ...]` when research data is missing.

### D.4 Import Mechanism in Slidev

Slidev supports two methods for importing content from library files:

**Method 1: `src` frontmatter (recommended for full slides)**

```yaml
---
src: ../../.context/deck/contents/cover/cover-standard.md
---
```

This imports the entire slide (frontmatter + content) from the external file. The main `slides.md` frontmatter takes precedence for duplicate keys (frontmatter merging).

**Method 2: Direct copy (recommended for customized slides)**

When slides need customization beyond slot filling, the builder copies the content directly into `slides.md` and modifies in-place. This is the primary method since most slides need content-specific modifications.

**Recommended approach**: The builder uses Method 2 (direct copy) as the default. The content library serves as a *starting template* that the builder reads, fills slots, and writes into the final deck. The `src` import is used only for boilerplate slides that need zero customization (e.g., closing slides, section dividers).

### D.5 How the Builder Populates New Content Back to the Library

When the planner marks a slide as `NEW`, the builder:

1. Creates the slide content in `slides.md` based on research data
2. After successful deck generation, extracts the new slide content
3. Generalizes it by replacing specific values with `[SLOT: ...]` markers
4. Writes the generalized version to `.context/deck/contents/{slide_type}/{slide_type}-{variant}.md`
5. Adds an entry to `index.json` with appropriate tags
6. Includes a comment in the generated slide: `<!-- Content saved to library: contents/{path} -->`

This "write-back" mechanism grows the library over time. Each deck build potentially contributes reusable content.

### D.6 Comment Format for Imports

When the builder imports content from the library, it adds a comment at the top of each slide section:

```markdown
---
layout: fact
---

<!-- Imported from: .context/deck/contents/traction/traction-metrics.md -->
<!-- Slots filled: metric_1_value=$2.5M ARR, metric_1_label=Annual Recurring Revenue, ... -->

# Traction

<AutoFitText :max="48" :min="24">
$2.5M ARR | 150% MoM | 10K Users
</AutoFitText>
```

These comments serve as:
- Audit trail for where content came from
- Quick reference for manual editing
- Input for future library deduplication

---

## E. Theme Configuration Files

### E.1 Theme JSON Format

Each theme file in `.context/deck/themes/` contains the complete Slidev headmatter configuration and associated style presets.

```json
{
  "id": "theme-dark-blue",
  "name": "Dark Blue (AI Startup)",
  "headmatter": {
    "theme": "seriph",
    "colorSchema": "dark",
    "aspectRatio": "16/9",
    "canvasWidth": 980,
    "fonts": {
      "sans": "Inter",
      "serif": "Montserrat"
    },
    "transition": "fade",
    "themeConfig": {
      "primary": "#60a5fa"
    },
    "download": true
  },
  "style_presets": [
    "styles/colors/dark-blue-navy.css",
    "styles/typography/montserrat-inter.css"
  ],
  "css_variables": {
    "--slidev-bg": "#1e293b",
    "--slidev-text": "#e2e8f0",
    "--slidev-text-secondary": "#cbd5e1",
    "--slidev-text-muted": "#94a3b8",
    "--slidev-accent": "#60a5fa",
    "--slidev-accent-light": "#93c5fd"
  },
  "scoped_css_template": "h1 { font-family: 'Montserrat'; font-size: 3em; font-weight: 700; color: var(--slidev-text); }\nh2 { font-family: 'Montserrat'; font-size: 2.25em; font-weight: 600; color: var(--slidev-text-secondary); }\np, li { font-size: 1.5em; line-height: 1.4; color: var(--slidev-text-secondary); }"
}
```

### E.2 How the Builder Uses Theme Files

1. Read `themes/{id}.json`
2. Merge `headmatter` values into the first `---` block of `slides.md`
3. Add `title`, `author`, `info`, `exportFilename` from task/research data
4. Generate `styles/index.css` importing the `style_presets` paths
5. Apply `scoped_css_template` to each slide's `<style>` block (or to a global style file)
6. Set CSS variables in `styles/index.css` from `css_variables`

---

## F. Pattern Configuration Files

### F.1 Pattern JSON Format

```json
{
  "id": "pattern-yc-10-slide",
  "name": "YC 10-Slide Investor Pitch",
  "deck_mode": "INVESTOR",
  "description": "Standard Y Combinator 10-slide format for fundraising pitches.",
  "constraints": {
    "max_slides": 12,
    "max_bullets_per_slide": 5,
    "max_words_per_slide": 30,
    "min_font_size_px": 24,
    "animation_budget": "rich",
    "transition": "fade"
  },
  "slide_sequence": [
    {
      "position": 1,
      "slide_type": "cover",
      "required": true,
      "default_content": "content-cover-standard",
      "default_layout": "cover",
      "default_animation": "fade-in",
      "notes": "Company name, one-line description, tagline"
    },
    {
      "position": 2,
      "slide_type": "problem",
      "required": true,
      "default_content": "content-problem-statement",
      "default_layout": "statement",
      "default_animation": "staggered-list",
      "notes": "Pain point + 3 supporting evidence points"
    },
    {
      "position": 3,
      "slide_type": "solution",
      "required": true,
      "default_content": "content-solution-two-col",
      "default_layout": "two-cols",
      "default_animation": "staggered-list",
      "notes": "Benefits (not features) + how it works"
    },
    {
      "position": 4,
      "slide_type": "traction",
      "required": true,
      "default_content": "content-traction-metrics",
      "default_layout": "fact",
      "default_animation": "metric-cascade",
      "notes": "3 key metrics with AutoFitText"
    },
    {
      "position": 5,
      "slide_type": "why-us-now",
      "required": true,
      "default_content": "content-why-us-now-split",
      "default_layout": "two-cols",
      "default_animation": "staggered-list",
      "notes": "Why Us (left) | Why Now (right)"
    },
    {
      "position": 6,
      "slide_type": "business-model",
      "required": true,
      "default_content": "content-biz-model-pricing",
      "default_layout": "default",
      "default_animation": "staggered-list",
      "notes": "Revenue model, unit economics, pricing"
    },
    {
      "position": 7,
      "slide_type": "market",
      "required": true,
      "default_content": "content-market-tam-sam-som",
      "default_layout": "default",
      "default_animation": "staggered-list",
      "notes": "TAM/SAM/SOM with Mermaid diagram"
    },
    {
      "position": 8,
      "slide_type": "team",
      "required": true,
      "default_content": "content-team-two-col",
      "default_layout": "two-cols",
      "default_animation": "staggered-list",
      "notes": "Founder bios + key hires"
    },
    {
      "position": 9,
      "slide_type": "ask",
      "required": true,
      "default_content": "content-ask-centered",
      "default_layout": "center",
      "default_animation": "scale-in-pop",
      "notes": "Raise amount, valuation, allocation breakdown"
    },
    {
      "position": 10,
      "slide_type": "closing",
      "required": true,
      "default_content": "content-closing-standard",
      "default_layout": "end",
      "default_animation": "fade-in",
      "notes": "Thank you, contact info"
    }
  ],
  "appendix_suggestions": [
    {"slide_type": "appendix", "content_hint": "appendix-financials"},
    {"slide_type": "appendix", "content_hint": "appendix-competition"},
    {"slide_type": "appendix", "content_hint": "appendix-roadmap"}
  ]
}
```

---

## G. Builder Integration

### G.1 Builder Execution Flow (Revised)

The deck-builder-agent's execution flow changes substantially from the original Typst builder:

```
Stage 0: Early metadata (unchanged)
Stage 1: Parse delegation context (unchanged)
Stage 2: Load plan + research report
  - Extract content_manifest, selected_theme, selected_pattern, slide_order
  - Extract research content mapped to slide positions
Stage 2.5: Tool detection
  - Check for slidev CLI and playwright-chromium
  - Non-blocking: .md output always valid
Stage 3: Resume detection
  - Check for existing slides.md in output directory
  - If exists, validate completeness vs plan
Stage 4: Content Assembly (NEW - replaces template substitution)
  4a: Load theme config from .context/deck/themes/{theme_id}.json
  4b: Generate headmatter block from theme + task metadata
  4c: For each slide in slide_order:
      - If content_manifest[position].source == "library":
        Read .context/deck/contents/{path}
        Replace [SLOT: ...] markers with research data
        Add import comment
      - If content_manifest[position].source == "new":
        Generate slide content from research data
        Use pattern's default_layout and default_animation
        Mark for library write-back
  4d: Apply animations per pattern's animation assignments
  4e: Add appendix slides (hideInToc: true)
  4f: Write complete slides.md
Stage 5: Style Assembly (NEW)
  5a: Generate styles/index.css importing theme's style_presets
  5b: Copy required CSS preset files to output directory
  5c: Generate uno.config.ts with design tokens (if using custom components)
Stage 6: Component Copy (NEW - optional)
  - If plan uses custom components (MetricCard, TeamMember, etc.)
  - Copy from .context/deck/components/ to output's components/
Stage 7: Library Write-Back (NEW)
  - For each "new" content slide successfully generated:
    Generalize content (replace specific values with [SLOT:] markers)
    Write to .context/deck/contents/{slide_type}/{variant}.md
    Add entry to .context/deck/index.json
Stage 8: PDF Export (non-blocking)
  - slidev export slides.md --output {slug}-deck.pdf
  - Failure does not block completion
Stage 9: Summary + Metadata (unchanged pattern)
```

### G.2 Output Directory Structure

For a task with slug `neotex-seed-pitch`:

```
strategy/neotex-seed-pitch-deck/
├── slides.md              # Main presentation file
├── package.json           # Generated with slidev dependency
├── styles/
│   └── index.css          # Imports from .context/deck/styles/
├── components/            # Copied from .context/deck/components/ (if needed)
│   └── MetricCard.vue
├── public/
│   └── images/            # Any referenced images
└── neotex-seed-pitch-deck.pdf  # Optional PDF export
```

### G.3 Assembled slides.md Example

```markdown
---
theme: seriph
title: "NeoTex"
author: "Benjamin Brast-McKie"
info: "Seed Round Investor Pitch - AI-powered academic publishing"
aspectRatio: "16/9"
canvasWidth: 980
colorSchema: dark
fonts:
  sans: Inter
  serif: Montserrat
transition: fade
themeConfig:
  primary: '#60a5fa'
exportFilename: neotex-seed-pitch-deck
download: true
---

<!-- Imported from: .context/deck/contents/cover/cover-standard.md -->
<!-- Slots filled: company_name=NeoTex, tagline=AI-powered academic publishing -->

# NeoTex

<div class="text-xl opacity-80">
AI-powered academic publishing that turns research into publication-ready documents
</div>

<div class="abs-br m-6 text-sm opacity-50">
Seed Round | April 2026
</div>

<style>
h1 { font-family: 'Montserrat'; font-size: 3.5em; font-weight: 700; }
</style>

<!-- Speaker: "We're NeoTex. We make academic publishing fast and painless with AI." -->

---
layout: statement
---

<!-- Imported from: .context/deck/contents/problem/problem-statement.md -->

# Researchers spend 40% of their time on formatting, not research

<v-clicks>

- Average paper takes 3 weeks of formatting after writing
- LaTeX has a steep learning curve that excludes many researchers
- Journal submission requirements differ wildly and change frequently

</v-clicks>

<!-- Speaker: Establish urgency. Every researcher has lost weeks to formatting. -->

---
layout: two-cols
---

<!-- Imported from: .context/deck/contents/solution/solution-two-col.md -->

# The Solution

NeoTex automates the entire formatting pipeline

<v-clicks>

- Write in plain markdown, get publication-ready output
- AI handles citation formatting, figure placement, bibliography
- One-click submission to any journal format

</v-clicks>

::right::

## How It Works

Upload your manuscript. Select your target journal. NeoTex handles the rest.

<!-- Speaker: Demo walkthrough goes here if time permits. -->

---
layout: fact
---

<!-- NEW CONTENT - saved to library: contents/traction/traction-neotex.md -->

# Traction

<AutoFitText :max="48" :min="24">
$180K ARR | 340% QoQ | 2,400 researchers
</AutoFitText>

<v-clicks>

- 2,400 active researchers across 15 universities
- 340% quarter-over-quarter revenue growth
- 94% monthly retention rate

</v-clicks>

<!-- Speaker: Lead with ARR. We hit $180K in 8 months with zero paid marketing. -->
```

---

## H. Agent/Skill File Changes

### H.1 deck-planner-agent.md Changes

The planner agent requires a significant rewrite to support the 5-step library-aware workflow:

**Context References (replace)**:
```markdown
**Always Load**:
- `@.claude/extensions/founder/context/project/founder/patterns/pitch-deck-structure.md` - YC content rules (KEEP)
- `@.claude/extensions/founder/context/project/founder/patterns/slidev-deck-template.md` - Slidev syntax reference (NEW)
- `@.claude/extensions/founder/context/project/founder/patterns/yc-compliance-checklist.md` - Validation (KEEP)
- `@.claude/context/formats/plan-format.md` - Plan format (KEEP)

**Load for Library Access (NEW)**:
- `@.context/deck/index.json` - Master library index for querying themes, patterns, content
```

**Execution Flow Changes**:
- Stage 2: Load research report (unchanged)
- Stage 3: Replace single "template selection" with Step 1 (pattern) + Step 2 (theme) using library queries
- Stage 4: Replace "slide assignment" with Step 3 (content selection from library)
- Stage 5: Keep "ordering" as Step 4
- Stage 6: Extend plan generation (Step 5) to include import map, style composition, animation assignments

**Key New Logic**:
- jq queries against `.context/deck/index.json` for each step
- Content manifest generation with library paths
- Import map section in plan output
- `--quick` flag bypass (uses pattern defaults)

### H.2 deck-builder-agent.md Changes

The builder is the heaviest rewrite, as detailed in Section G.1 above. Key structural changes:

**Context References (replace)**:
```markdown
**Always Load**:
- `@.claude/extensions/founder/context/project/founder/patterns/pitch-deck-structure.md`
- `@.claude/extensions/founder/context/project/founder/patterns/slidev-deck-template.md` (NEW)
- `@.claude/extensions/founder/context/project/founder/patterns/yc-compliance-checklist.md`

**Load from Library (dynamic, based on plan)**:
- Theme config: `.context/deck/themes/{selected_theme}.json`
- Content files: `.context/deck/contents/{slide_type}/{variant}.md` (per content_manifest)
- Style presets: `.context/deck/styles/**/*.css` (per theme's style_presets)
- Components: `.context/deck/components/*.vue` (if plan references custom components)
```

**Removed**:
- All Typst template references (`.typ` files)
- `touying-pitch-deck-template.md` reference
- `typst compile` logic
- Typst-specific content substitution (`#let`, `#grid`, `#speaker-note`, `#text`)

**Added**:
- Library read/write logic (Stages 4-7 in Section G.1)
- Slidev headmatter generation from theme JSON
- `[SLOT: ...]` marker replacement
- `styles/index.css` generation
- Component copying
- Library write-back
- `slidev export` for PDF

### H.3 deck-research-agent.md Changes

Minimal changes (same as original plan):
- Replace `touying-pitch-deck-template.md` context reference with `slidev-deck-template.md`
- Replace "final Typst pitch deck" with "final Slidev pitch deck" in output text

### H.4 deck.md Command Changes

Minimal changes (same as original plan):
- Replace "Typst" with "Slidev" in user-facing text
- Remove `.typ$` from file path detection regex
- Update workflow summary

### H.5 Skill File Changes

**skill-deck-plan/SKILL.md**: One string replacement ("Typst" -> "Slidev")

**skill-deck-implement/SKILL.md**: Moderate changes:
- Description: "Slidev pitch deck generation"
- Delegation context: "Generate Slidev pitch deck"
- Template references: `.md` not `.typ`
- Error handling: "slidev/playwright" not "typst"
- Metadata field: `pdf_generated` not `typst_generated`

### H.6 New Files Needed

| File | Purpose |
|------|---------|
| `.context/deck/index.json` | Master library index |
| `.context/deck/themes/*.json` (5) | Theme configurations |
| `.context/deck/patterns/*.json` (5) | Pattern definitions |
| `.context/deck/animations/*.md` (6) | Animation pattern docs |
| `.context/deck/styles/colors/*.css` (4) | Color presets |
| `.context/deck/styles/typography/*.css` (3) | Typography presets |
| `.context/deck/styles/textures/*.css` (2) | Texture presets |
| `.context/deck/contents/*/*.md` (~20) | Initial content library |
| `.context/deck/components/*.vue` (4) | Reusable Vue components |
| `patterns/slidev-deck-template.md` | Slidev syntax reference (extension context) |

### H.7 Files to Delete (unchanged from original plan)

- `patterns/touying-pitch-deck-template.md`
- 5 `templates/typst/deck/deck-*.typ` files
- `templates/typst/deck/` directory

### H.8 index-entries.json Updates

Replace 6 entries as specified in the original plan, plus add a new entry for `.context/deck/index.json`:

```json
{
  "path": "project/founder/patterns/slidev-deck-template.md",
  "summary": "Slidev markdown template structure for pitch deck generation",
  "line_count": 250,
  "load_when": {
    "agents": ["deck-research-agent", "deck-planner-agent", "deck-builder-agent"],
    "languages": ["founder"],
    "task_types": ["deck"],
    "commands": ["/deck"]
  }
}
```

### H.9 .context/index.json Update

Add the deck library to the project context index:

```json
{
  "path": "deck/index.json",
  "summary": "Slidev deck library index for agent-driven deck construction",
  "line_count": 200,
  "load_when": {
    "agents": ["deck-planner-agent", "deck-builder-agent"],
    "languages": ["founder"],
    "commands": ["/deck"]
  }
}
```

---

## I. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Library too complex for initial implementation | Medium | High | Seed with minimal set: 5 themes, 2 patterns (YC 10-slide + lightning), 10 content files. Grow organically via write-back |
| `src` import paths break when deck output directory differs | Medium | Medium | Use Method 2 (direct copy) as default; `src` only for boilerplate slides |
| Content library grows unbounded with duplicates | Low | Medium | Builder checks for similar content before write-back; periodic dedup via `/review` |
| jq queries on large index.json slow down planner | Low | Low | Index starts small (~50 entries); jq is fast for this scale |
| Vue components require Slidev project initialization | Medium | Medium | Builder generates minimal `package.json` with `@slidev/cli` dependency |
| CSS preset composition conflicts | Low | Medium | Presets use namespaced CSS variables; specificity rules documented |
| Planner's 5 steps feel heavy for quick decks | Medium | Medium | `--quick` flag skips steps 1-2, uses YC 10-slide + dark-blue defaults |
| Breaking change for existing deck tasks | Medium | High | Complete or abandon in-progress tasks before merging |

---

## J. Implementation Phasing (Revised)

The original 5-phase plan needs to expand to accommodate the library architecture:

```
Phase 1: Library Foundation (NEW)
  - Create .context/deck/ directory structure
  - Create index.json with schema
  - Create 5 theme JSON files
  - Create 5 pattern JSON files
  - Create initial content library (~20 markdown snippets)
  - Create 4 Vue components
  - Create CSS preset files
  - Update .context/index.json

Phase 2: Extension Context (matches original Phase 1)
  - Create slidev-deck-template.md pattern
  - Update pitch-deck-structure.md

Phase 3: Agent Rewrites (matches original Phase 2, expanded)
  - Rewrite deck-planner-agent.md (5-step library workflow)
  - Rewrite deck-builder-agent.md (library-based assembly)
  - Update deck-research-agent.md (minor)

Phase 4: Skills, Command, Index (matches original Phases 3+4)
  - Update skill-deck-plan, skill-deck-implement
  - Update deck.md command
  - Update index-entries.json

Phase 5: Cleanup (matches original Phase 5)
  - Delete Typst files
  - Remove templates/typst/deck/ directory
  - Verification grep tests
```

---

## Appendix

### Search Queries Used

1. "Slidev reusable slide content library import markdown snippets 2026"
2. "Slidev src frontmatter importing slides from external markdown files reuse"
3. "Slidev project structure best practices components layouts styles organization"
4. "Slidev theme seriph themeConfig customization options dark colorSchema"

### Sources

- [Slidev Importing Slides](https://sli.dev/features/importing-slides)
- [Slidev Import Code Snippets](https://sli.dev/features/import-snippet)
- [Slidev Directory Structure](https://sli.dev/custom/directory-structure)
- [Slidev Frontmatter Merging](https://sli.dev/features/frontmatter-merging)
- [Slidev Writing Themes](https://sli.dev/guide/write-theme)
- [Slidev Theme Gallery](https://sli.dev/resources/theme-gallery)
- [@slidev/theme-seriph (npm)](https://www.npmjs.com/package/@slidev/theme-seriph)
- [Slidev Syntax Guide](https://sli.dev/guide/syntax)
- [Slidev Animations](https://sli.dev/guide/animations)
- [Slidev Components](https://sli.dev/guide/component)
- [Slidev Layouts](https://sli.dev/guide/layout)

### Existing Reports Referenced

- `specs/345_port_deck_typst_to_slidev/reports/01_slidev-port-research.md` - Initial architecture analysis and Typst-to-Slidev mapping
- `specs/345_port_deck_typst_to_slidev/reports/02_slidev-standards.md` - Comprehensive Slidev syntax, layout, animation, theme, export reference
- `specs/345_port_deck_typst_to_slidev/reports/03_refactor-analysis.md` - File-by-file change analysis with dependency graph
- `specs/345_port_deck_typst_to_slidev/reports/05_deck-library-system.md` - Team research on reusable library: protocols, animations, styling presets, index schema, 6-step workflow
- `specs/345_port_deck_typst_to_slidev/plans/02_implementation-plan.md` - Original 5-phase port plan (superseded by this design)

### Existing Agent Files Referenced

- `.claude/extensions/founder/commands/deck.md` - Command entry point (486 lines)
- `.claude/extensions/founder/agents/deck-planner-agent.md` - Current 3-step planner (467 lines)
- `.claude/extensions/founder/agents/deck-builder-agent.md` - Current Typst builder (503 lines)
- `.claude/extensions/founder/agents/deck-research-agent.md` - Research agent (418 lines)
