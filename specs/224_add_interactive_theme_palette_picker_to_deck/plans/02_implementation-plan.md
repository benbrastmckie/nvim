# Implementation Plan: Task #224

- **Task**: 224 - Add interactive theme and palette picker to /deck command
- **Status**: [NOT STARTED]
- **Effort**: 2-3 hours
- **Dependencies**: None
- **Research Inputs**: [01_interactive-picker-patterns.md](../reports/01_interactive-picker-patterns.md)
- **Artifacts**: plans/02_implementation-plan.md (this file)
- **Standards**: plan.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Add an interactive theme and color palette picker to the `/deck` command using AskUserQuestion. When users invoke `/deck` without specifying `--theme` and `--palette` flags, they will be prompted to select from a combined picker showing 20 options (5 Touying themes x 4 color palettes). The picker uses text labels with industry/use-case descriptions since AskUserQuestion does not support visual previews.

### Research Integration

Key findings from research report:
- AskUserQuestion supports single/multi-select with labels and descriptions only (no visual preview)
- Recommended: single combined picker with 20 theme+palette options grouped by theme
- Color palettes are defined in `shared-config.typ`: professional-blue, premium-dark, minimal-light, growth-green
- Palettes integrate via touying's `config-colors()` function

## Goals & Non-Goals

**Goals**:
- Add `--palette` flag to deck.md command
- Insert AskUserQuestion before skill delegation when flags not provided
- Pass palette through skill-deck to deck-agent
- Update deck-agent to apply palette colors via `config-colors()`
- Support CLI override (skip picker if flags provided)

**Non-Goals**:
- Visual preview of themes/palettes (AskUserQuestion limitation)
- Custom user-defined palettes
- Palette editing UI
- Modifying the palette definitions in shared-config.typ

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| 20 options may overwhelm users | Medium | Medium | Group by theme, add clear descriptions with use-case guidance |
| Some theme+palette combinations may look poor | Low | Low | All combinations tested in research; remove incompatible pairs if found |
| Breaking existing `--theme` behavior | High | Low | Keep `--theme` working exactly as before; only prompt for palette when not specified |
| touying `config-colors()` API changes | Medium | Low | Pin to touying 0.6.3 (already pinned) |

## Implementation Phases

### Phase 1: Add Picker to Command [NOT STARTED]

**Goal**: Insert AskUserQuestion in deck.md to capture theme+palette selection when flags not provided

**Tasks**:
- [ ] Add `--palette` to argument-hint frontmatter
- [ ] Add palette parsing in argument parsing section
- [ ] Add AskUserQuestion with 20 combined options after validation
- [ ] Parse selected option to extract theme and palette values
- [ ] Update skill invocation to pass palette parameter
- [ ] Handle CLI override: skip picker if `--theme` AND `--palette` provided; prompt for palette only if just `--theme` provided

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/present/commands/deck.md` - Add picker logic and palette flag

**Verification**:
- [ ] `/deck "prompt"` shows interactive picker
- [ ] `/deck "prompt" --theme simple --palette professional-blue` skips picker
- [ ] `/deck "prompt" --theme simple` prompts for palette only
- [ ] Selected values correctly parsed and passed to skill

---

### Phase 2: Update Skill to Pass Palette [NOT STARTED]

**Goal**: Modify skill-deck to accept and forward palette parameter to deck-agent

**Tasks**:
- [ ] Add palette to input validation section
- [ ] Add palette default ("professional-blue") if not provided
- [ ] Include palette in context preparation JSON
- [ ] Update agent invocation to include palette
- [ ] Update return format documentation to include palette

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/present/skills/skill-deck/SKILL.md` - Add palette parameter handling

**Verification**:
- [ ] Skill accepts palette parameter
- [ ] Palette included in delegation context to agent
- [ ] Return metadata includes palette value

---

### Phase 3: Implement Palette in Agent [NOT STARTED]

**Goal**: Update deck-agent to apply palette colors to generated Typst code

**Tasks**:
- [ ] Add palette to Stage 1 delegation context parsing
- [ ] Add palette color definitions map (5 colors per palette)
- [ ] Modify Stage 5 Typst generation to:
  - Define palette color variables
  - Apply via `config-colors()` in theme setup
- [ ] Update successful return JSON to include palette metadata
- [ ] Add palette to context references (shared-config.typ pattern)

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/present/agents/deck-agent.md` - Add palette color application

**Verification**:
- [ ] Generated .typ files include color variable definitions
- [ ] `config-colors()` call includes primary, secondary, tertiary
- [ ] Different palettes produce different color values
- [ ] Generated decks compile successfully with `typst compile`

---

### Phase 4: End-to-End Testing [NOT STARTED]

**Goal**: Verify the complete workflow functions correctly

**Tasks**:
- [ ] Test interactive picker flow with various input combinations
- [ ] Test CLI override with both flags
- [ ] Test partial override (--theme only)
- [ ] Test all 20 theme+palette combinations compile
- [ ] Verify speaker notes and TODO placeholders still work
- [ ] Test file input mode with palette selection

**Timing**: 30 minutes

**Files to modify**:
- None (testing only)

**Verification**:
- [ ] All 20 combinations produce valid Typst output
- [ ] Compiled PDFs show correct color schemes
- [ ] No regressions in existing functionality

## Testing & Validation

- [ ] Interactive picker appears when no flags provided
- [ ] CLI flags skip picker appropriately
- [ ] All 20 theme+palette combinations generate valid Typst
- [ ] Generated decks compile without errors
- [ ] Color values match palette definitions from shared-config.typ
- [ ] Existing `--theme` flag behavior unchanged

## Artifacts & Outputs

- plans/02_implementation-plan.md (this file)
- Modified: `.claude/extensions/present/commands/deck.md`
- Modified: `.claude/extensions/present/skills/skill-deck/SKILL.md`
- Modified: `.claude/extensions/present/agents/deck-agent.md`

## Rollback/Contingency

If implementation causes issues:
1. Revert changes to deck.md (remove picker and palette flag)
2. Revert changes to skill-deck/SKILL.md (remove palette parameter)
3. Revert changes to deck-agent.md (remove palette handling)
4. Original `--theme` functionality remains intact as fallback
