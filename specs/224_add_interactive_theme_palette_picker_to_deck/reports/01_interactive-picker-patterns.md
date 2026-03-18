# Research Report: Task #224

**Task**: 224 - Add interactive theme and palette picker to /deck command
**Started**: 2026-03-17T00:00:00Z
**Completed**: 2026-03-17T00:15:00Z
**Effort**: 2-4 hours (implementation)
**Dependencies**: None
**Sources/Inputs**: Codebase analysis of deck.md, skill-deck/SKILL.md, deck-agent.md, shared-config.typ, interactive-selection.md, fix-it.md, meta.md
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Current `/deck` command has `--theme` flag but only supports Touying themes (simple, metropolis, dewdrop, university, stargazer) - no color palette selection
- The present extension has 4 professional color palettes defined in `shared-config.typ` (professional-blue, premium-dark, minimal-light, growth-green) that are NOT accessible via the command
- AskUserQuestion supports selection with labels and descriptions but NO preview/visual mode - must use text descriptions for visual elements
- Recommended: Single combined picker with theme+palette matrix (5 themes x 4 palettes = 20 options) presented in logical groups
- Files requiring modification: deck.md (command), skill-deck/SKILL.md (skill), deck-agent.md (agent)

## Context and Scope

The task requires adding interactive selection for themes and color palettes to the `/deck` command. Currently, users must specify `--theme NAME` at the command line, and there is no way to select color palettes.

**Research Questions**:
1. How does AskUserQuestion work for visual selection?
2. How are themes currently handled in the deck workflow?
3. What color palettes exist and how should they integrate?
4. Should theme and palette be combined or separate pickers?

## Findings

### 1. Current Theme Handling

**deck.md (command)**:
- Accepts `--theme` flag with values: simple, metropolis, dewdrop, university, stargazer
- Theme defaults to "simple" if not specified
- Theme is passed through to skill-deck via delegation args

**skill-deck/SKILL.md**:
- Receives theme as parameter
- Passes to deck-agent unchanged
- No validation or transformation

**deck-agent.md**:
- Applies theme via Touying import: `#import themes.simple: *`
- Uses `#show: simple-theme.with(...)` pattern
- No color palette awareness

### 2. Available Color Palettes

From `shared-config.typ`, four palettes are defined:

| Palette | Primary | Secondary | Accent | Background | Text |
|---------|---------|-----------|--------|------------|------|
| professional-blue | #1a365d | #2c5282 | #4299e1 | #ffffff | #1a202c |
| premium-dark | #1a1a2e | #16213e | #d4a574 | #0f0f1a | #e2e8f0 |
| minimal-light | #2d3748 | #4a5568 | #3182ce | #f7fafc | #1a202c |
| growth-green | #047857 | #065f46 | #34d399 | #f0fdf4 | #1a202c |

These palettes are currently only used in example files, NOT integrated into the generation workflow.

### 3. AskUserQuestion Capabilities

From `interactive-selection.md`:

```json
{
  "question": "string (required)",
  "header": "string (1-3 words, Title Case)",
  "multiSelect": "boolean (default: false)",
  "options": [
    {
      "label": "string (action phrase or descriptive noun)",
      "description": "string (consequence, details, or count)"
    }
  ]
}
```

**Key Constraints**:
- NO image preview support
- NO color swatch preview support
- Text-only labels and descriptions
- multiSelect for multiple choices, single-select for one choice

**Existing Patterns in Codebase**:
- `/fix-it`: Task type selection, then item selection (two-stage)
- `/meta`: Confirmation pattern
- `/todo`: Single-select for orphan handling
- `/task --review`: Multi-select for follow-up tasks

### 4. UX Design Options

**Option A: Two Separate Pickers (NOT recommended)**
- First picker for Touying theme
- Second picker for color palette
- Pro: Each picker is small
- Con: More clicks, user might not understand relationship

**Option B: Single Combined Picker (RECOMMENDED)**
- Group options by theme, showing palette variations
- User sees full picture in one selection
- Example structure:

```json
{
  "question": "Select a theme and color palette for your pitch deck:",
  "header": "Deck Style",
  "multiSelect": false,
  "options": [
    {
      "label": "Simple - Professional Blue",
      "description": "Clean minimal layout | Navy/blue tones | Best for fintech, B2B"
    },
    {
      "label": "Simple - Premium Dark",
      "description": "Clean minimal layout | Dark + gold | Best for luxury, premium tech"
    },
    {
      "label": "Simple - Minimal Light",
      "description": "Clean minimal layout | Charcoal/gray | Best for data, analytics"
    },
    {
      "label": "Simple - Growth Green",
      "description": "Clean minimal layout | Emerald tones | Best for sustainability, health"
    },
    {
      "label": "Metropolis - Professional Blue",
      "description": "Modern professional | Navy/blue tones | Best for fintech, B2B"
    }
    // ... etc for all combinations
  ]
}
```

**Option C: Hierarchical Selection (ALTERNATIVE)**
- First ask about presentation style (formal vs modern vs minimal)
- Then ask about color family (blue, dark, light, green)
- Maps to theme+palette combinations
- Pro: Guides user thinking
- Con: More complex to implement

### 5. Implementation Architecture

**Command Layer (deck.md)**:
- Add AskUserQuestion BEFORE delegating to skill
- Parse selection to extract theme and palette
- Pass both to skill via delegation args

**Skill Layer (skill-deck/SKILL.md)**:
- Add `palette` parameter alongside `theme`
- Pass both to deck-agent

**Agent Layer (deck-agent.md)**:
- Modify Typst generation to:
  1. Import palette colors from shared-config pattern
  2. Apply to theme configuration via `config-colors()`
  3. Use palette colors in text, backgrounds, accents

**Typst Generation Pattern**:
```typst
// Import base theme
#import themes.simple: *

// Define palette colors
#let primary = rgb("#1a365d")
#let secondary = rgb("#2c5282")
#let accent = rgb("#4299e1")

// Apply to theme
#show: simple-theme.with(
  aspect-ratio: "16-9",
  config-colors(
    primary: primary,
    secondary: secondary,
    tertiary: accent,
  ),
)
```

### 6. Handling CLI Override

When user provides `--theme` flag explicitly, skip the picker:
- If `--theme` AND `--palette` provided: use directly
- If only `--theme` provided: prompt for palette only
- If neither provided: show full picker

## Recommendations

### Implementation Approach

1. **Add palette argument** to command, skill, and agent
2. **Insert AskUserQuestion** in command GATE IN phase, BEFORE skill delegation
3. **Use combined picker** (Option B) with 20 options (5 themes x 4 palettes)
4. **Group visually** in picker by theme for scanability
5. **Update Typst generation** to apply palette colors via `config-colors()`

### Picker Design

```json
{
  "question": "Select a visual style for your pitch deck:",
  "header": "Deck Style",
  "multiSelect": false,
  "options": [
    {"label": "Simple + Professional Blue", "description": "Minimal layout, navy tones | Fintech, enterprise B2B"},
    {"label": "Simple + Premium Dark", "description": "Minimal layout, dark + gold | Luxury, premium tech"},
    {"label": "Simple + Minimal Light", "description": "Minimal layout, charcoal/gray | Data, analytics"},
    {"label": "Simple + Growth Green", "description": "Minimal layout, emerald | Sustainability, health"},
    {"label": "Metropolis + Professional Blue", "description": "Modern professional, navy | Corporate presentations"},
    {"label": "Metropolis + Premium Dark", "description": "Modern professional, dark + gold | Evening events"},
    {"label": "Metropolis + Minimal Light", "description": "Modern professional, gray | Versatile corporate"},
    {"label": "Metropolis + Growth Green", "description": "Modern professional, emerald | Environmental tech"},
    {"label": "Dewdrop + Professional Blue", "description": "Light airy layout, navy | Creative tech"},
    {"label": "Dewdrop + Premium Dark", "description": "Light airy layout, dark + gold | Creative luxury"},
    {"label": "Dewdrop + Minimal Light", "description": "Light airy layout, gray | Startup pitches"},
    {"label": "Dewdrop + Growth Green", "description": "Light airy layout, emerald | Health startups"},
    {"label": "University + Professional Blue", "description": "Academic style, navy | Research presentations"},
    {"label": "University + Premium Dark", "description": "Academic style, dark + gold | Evening lectures"},
    {"label": "University + Minimal Light", "description": "Academic style, gray | Conference talks"},
    {"label": "University + Growth Green", "description": "Academic style, emerald | Environmental research"},
    {"label": "Stargazer + Professional Blue", "description": "Dark mode, navy accents | Tech demos"},
    {"label": "Stargazer + Premium Dark", "description": "Dark mode, gold accents | VIP presentations"},
    {"label": "Stargazer + Minimal Light", "description": "Dark mode, blue accents | Technical talks"},
    {"label": "Stargazer + Growth Green", "description": "Dark mode, green accents | Sustainability demos"}
  ]
}
```

### Files to Modify

| File | Changes |
|------|---------|
| `.claude/extensions/present/commands/deck.md` | Add AskUserQuestion in GATE IN, add --palette flag, parse selection |
| `.claude/extensions/present/skills/skill-deck/SKILL.md` | Add palette parameter, pass to agent |
| `.claude/extensions/present/agents/deck-agent.md` | Add palette handling, modify Typst generation |
| `.claude/extensions/present/examples/shared-config.typ` | No changes needed (palettes already defined) |

## Decisions

1. **Use single combined picker** rather than two-stage selection - reduces clicks and shows full matrix
2. **Insert picker at command level** (deck.md), not skill or agent - maintains command as user interface
3. **Support CLI override** - when --theme/--palette provided, skip corresponding prompts
4. **Keep palette structure from shared-config.typ** - 5-color tuples (primary, secondary, accent, background, text)

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| 20 options may overwhelm user | Group by theme in picker, add descriptions with use-case guidance |
| Some theme+palette combinations may look poor | Test all combinations, possibly exclude incompatible pairs |
| Breaking existing --theme flag behavior | Keep --theme working as before, only add palette prompt when palette not specified |
| Typst config-colors API changes | Pin to specific touying version (0.6.3) |

## Context Extension Recommendations

None - this is a meta task; context documentation should focus on implementation details rather than research-time knowledge.

## Appendix

### Search Queries Used
- Glob patterns: `**/*deck*.md`, `**/AskUserQuestion*`, `**/shared-config.typ`, `**/examples/*-pitch.typ`
- Grep patterns: `AskUserQuestion`, `theme|palette|color`

### Key Files Analyzed
- `/home/benjamin/.config/nvim/.claude/extensions/present/commands/deck.md` - Command definition
- `/home/benjamin/.config/nvim/.claude/extensions/present/skills/skill-deck/SKILL.md` - Skill wrapper
- `/home/benjamin/.config/nvim/.claude/extensions/present/agents/deck-agent.md` - Agent implementation
- `/home/benjamin/.config/nvim/.claude/extensions/present/examples/shared-config.typ` - Palette definitions
- `/home/benjamin/.config/nvim/.claude/context/core/standards/interactive-selection.md` - AskUserQuestion schema
- `/home/benjamin/.config/nvim/.claude/commands/fix-it.md` - AskUserQuestion usage example
- `/home/benjamin/.config/nvim/.claude/extensions/present/README.md` - Theme gallery documentation
