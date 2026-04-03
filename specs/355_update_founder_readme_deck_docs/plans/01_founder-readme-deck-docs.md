# Implementation Plan: Update Founder README and Deck Docs

- **Task**: 355 - update_founder_readme_deck_docs
- **Status**: [NOT STARTED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/355_update_founder_readme_deck_docs/reports/01_team-research.md
- **Artifacts**: plans/01_founder-readme-deck-docs.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: founder
- **Lean Intent**: false

## Overview

The founder extension has two README files requiring documentation work. The main `README.md` (86 lines) is outdated -- it lists only 4 of 8 commands, omits the `deck/` subdirectory, and is missing references to 6 domain files, 7 pattern files, and 5 template files added in v3.0. The `deck/README.md` is completely empty (0 bytes) despite the deck sub-domain being the most complex part of the extension with 40+ files across 6 categories. Both files will be updated to provide complete, consistent, human-readable documentation following the rich README pattern used by other extensions.

### Research Integration

Team research (2 teammates) confirmed identical gaps with high confidence. Teammate A provided exhaustive structural analysis of all files. Teammate B cross-referenced documentation patterns from 8+ other extension READMEs and identified the rich README pattern (title, directory structure, loading strategy, configuration assumptions, key concepts, agent context loading). Both recommended the same content outlines. All findings are integrated into this plan.

## Goals and Non-Goals

**Goals**:
- Update `context/project/founder/README.md` to reflect all v3.0 content (8 commands, all domain/pattern/template files, deck subdirectory)
- Create comprehensive `context/project/founder/deck/README.md` documenting the deck library (6 categories, 40+ files, content slot system)
- Follow the rich README pattern used by other extensions (neovim, web, nix)
- Ensure both files cross-reference each other for navigation

**Non-Goals**:
- Modifying any code, configuration, or content files in the extension
- Changing `index-entries.json` or `deck/index.json`
- Creating documentation for individual deck library files
- Adding YAML frontmatter (prohibited by documentation conventions)

## Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Missing files in directory tree | M | L | Research enumerated all files; verify with `ls -R` before writing |
| Inconsistency between READMEs | M | L | Write main README second so it can reference deck README accurately |
| Stale command routing info | M | L | Cross-check manifest.json and command files during implementation |

## Implementation Phases

### Phase 1: Create Deck Library README [NOT STARTED]

**Goal**: Write comprehensive documentation for the deck sub-domain from scratch, covering all 6 categories, the content slot system, and agent navigation patterns.

**Tasks**:
- [ ] Read `deck/index.json` to extract category metadata, entry descriptions, and tags for accurate documentation
- [ ] Read 2-3 sample content files to document the content slot system (`[SLOT: ...]` markers) accurately
- [ ] Read 1 sample animation, 1 pattern, and 1 theme file to capture their structure for the categories section
- [ ] Write `deck/README.md` with these sections:
  - `# Deck Library` -- title and 2-sentence purpose statement
  - `## Overview` -- what the library enables, relationship to `index.json`, seed vs runtime copy pattern
  - `## Directory Structure` -- full annotated tree showing all 6 categories with file counts
  - `## Categories` -- subsection per category with tables:
    - Themes (5 files): id, name, mood/use case
    - Patterns (5 files): id, name, slide count, compatible modes
    - Animations (6 files): id, name, trigger type, complexity
    - Styles (9 files across 3 subdirectories): id, name, type (colors/typography/texture)
    - Components (4 Vue files): component name, props, usage context
    - Contents (23 files across 11 topic directories): topic, variants, slot types
  - `## Content Slot System` -- how structured comment-header metadata works, example of a content slot
  - `## Agent Navigation` -- how agents load `index.json` to select library items
  - `## Import Methods` -- `src` frontmatter vs direct copy approaches
  - `## Extending the Library` -- write-back mechanism for new content to runtime copy
  - `## Related Context` -- links to `pitch-deck-structure.md`, `slidev-deck-template.md`, `yc-compliance-checklist.md`
  - `## Navigation` -- back-link to `../README.md`

**Timing**: 1.5 hours

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/deck/README.md` -- write full content (currently empty)

**Verification**:
- File is non-empty and follows rich README pattern
- All 6 categories documented with accurate file counts
- Directory tree matches actual `ls -R` output
- Content slot system documented with concrete example
- Navigation links present (back to parent README)

---

### Phase 2: Update Main Founder README [NOT STARTED]

**Goal**: Bring the main README up to date with all v3.0 additions, including the complete command table, full directory tree, and deck subdirectory reference.

**Tasks**:
- [ ] Update the directory structure tree to include all current files:
  - Add `domain/financial-analysis.md`, `domain/legal-frameworks.md`, `domain/timeline-frameworks.md`, `domain/workflow-reference.md`, `domain/migration-guide.md`
  - Add `patterns/contract-review.md`, `patterns/legal-planning.md`, `patterns/project-planning.md`, `patterns/financial-forcing-questions.md`, `patterns/pitch-deck-structure.md`, `patterns/slidev-deck-template.md`, `patterns/yc-compliance-checklist.md`
  - Add `templates/contract-analysis.md`, `templates/financial-analysis.md` and all 7 Typst templates
  - Add `deck/` subdirectory entry with link to `deck/README.md`
- [ ] Update the Related Commands table from 4 to all 8 commands:
  - Add `/legal` -- `domain/legal-frameworks`, `patterns/contract-review`, `patterns/legal-planning`, `templates/contract-analysis`
  - Add `/project` -- `domain/timeline-frameworks`, `patterns/project-planning`
  - Add `/finance` -- `domain/financial-analysis`, `patterns/financial-forcing-questions`, `templates/financial-analysis`
  - Add `/deck` -- `deck/` library, `patterns/pitch-deck-structure`, `patterns/slidev-deck-template`
- [ ] Add a Context Discovery section explaining how `index-entries.json` enables automatic loading by agent, language, and command
- [ ] Add a Deck Library section with brief description and link to `deck/README.md`
- [ ] Verify cross-references: deck README back-link points to this file, this file's deck link points to deck README

**Timing**: 0.5 hours

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/README.md` -- update existing content

**Verification**:
- Directory tree matches actual file listing from `ls -R`
- All 8 commands present in Related Commands table
- `deck/` entry in directory tree with annotation linking to `deck/README.md`
- Context discovery section explains `index-entries.json` mechanism
- No broken cross-references between the two README files

## Testing and Validation

- [ ] Run `ls -R` on `context/project/founder/` and confirm every file appears in the main README directory tree
- [ ] Run `ls -R` on `context/project/founder/deck/` and confirm every file appears in the deck README directory tree
- [ ] Verify all 8 commands from `manifest.json` are documented in the main README
- [ ] Confirm no YAML frontmatter in either file
- [ ] Confirm no emojis in either file
- [ ] Verify cross-links between both README files resolve correctly

## Artifacts and Outputs

- `.claude/extensions/founder/context/project/founder/deck/README.md` -- new comprehensive deck library documentation
- `.claude/extensions/founder/context/project/founder/README.md` -- updated main founder context documentation
- `specs/355_update_founder_readme_deck_docs/plans/01_founder-readme-deck-docs.md` -- this plan
- `specs/355_update_founder_readme_deck_docs/summaries/01_founder-readme-deck-docs-summary.md` -- execution summary (post-implementation)

## Rollback/Contingency

Both files are tracked in git. If changes are unsatisfactory:
- `git checkout HEAD -- .claude/extensions/founder/context/project/founder/README.md` restores the original main README
- `git checkout HEAD -- .claude/extensions/founder/context/project/founder/deck/README.md` restores the empty deck README
- No other files are modified by this plan, so rollback is clean and isolated
