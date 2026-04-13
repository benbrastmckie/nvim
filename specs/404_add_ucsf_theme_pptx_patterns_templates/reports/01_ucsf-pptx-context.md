---
task: 404
title: Add UCSF theme, PPTX patterns, and templates to present/ context
status: complete
---

# Research Report: Task #404

**Task**: 404 - Add UCSF theme, PPTX patterns, and templates to present/ context
**Started**: 2026-04-12T00:00:00Z
**Completed**: 2026-04-12T00:30:00Z
**Effort**: 1-2 hours (implementation estimate)
**Dependencies**: None (independent of agent split tasks 403/405)
**Sources/Inputs**: DIFF.md section 4, zed .claude_NEW context files, existing nvim present/ extension
**Artifacts**: - specs/404_add_ucsf_theme_pptx_patterns_templates/reports/01_ucsf-pptx-context.md
**Standards**: report-format.md

## Executive Summary

- 10 new files need to be created (1 theme, 2 patterns, 7 template files)
- 4 existing files need updates (2 themes get footer sections, 1 content file gets footer, 1 index.json gets rewritten)
- 1 binary file (UCSF .pptx template) to be copied
- 8 new index-entries.json entries needed for context discovery
- talk-structure.md needs 5 appended lines for format-specific notes

## Context & Scope

This task ports the PPTX generation support and UCSF institutional theme from the zed configuration into the nvim present/ extension. The changes are entirely within the `context/project/present/talk/` subtree and `index-entries.json`. No agents, skills, or commands are modified (those are covered by tasks 403, 405-407).

## Findings

### 1. New Files to Create

All target paths are relative to `/home/benjamin/.config/nvim/.claude/extensions/present/`.

#### 1.1 Theme: ucsf-institutional.json

- **Source**: `/home/benjamin/.config/zed/.claude_NEW/context/project/present/talk/themes/ucsf-institutional.json`
- **Target**: `context/project/present/talk/themes/ucsf-institutional.json`
- **Lines**: 50
- **Content**: UCSF institutional theme with navy (#052049) / Pacific Blue (#0093D0) palette, Garamond serif headings, Arial body font, footer section with flow positioning guidance.

#### 1.2 Pattern: pptx-generation.md

- **Source**: `/home/benjamin/.config/zed/.claude_NEW/context/project/present/talk/patterns/pptx-generation.md`
- **Target**: `context/project/present/talk/patterns/pptx-generation.md`
- **Lines**: 829
- **Content**: Comprehensive python-pptx API reference documenting: imports/setup, slide creation, theme application, 5 component helpers (DataTable, FigurePanel, CitationBlock, StatResult, FlowDiagram), speaker notes, export, error handling (missing images, font fallback, table overflow), and complete deck assembly pattern.

#### 1.3 Pattern: slidev-pitfalls.md

- **Source**: `/home/benjamin/.config/zed/.claude_NEW/context/project/present/talk/patterns/slidev-pitfalls.md`
- **Target**: `context/project/present/talk/patterns/slidev-pitfalls.md`
- **Lines**: 254
- **Content**: Practical Slidev implementation gotchas: project setup (pnpm, lz-string ESM shim, version alignment), inline code black boxes (Shiki CSS override), Vue components in markdown tables, footer positioning overlap, mermaid diagrams, pre-Playwright validation, NixOS workaround, required Playwright verification phase template.

#### 1.4 Template: playwright-verify.mjs

- **Source**: `/home/benjamin/.config/zed/.claude_NEW/context/project/present/talk/templates/playwright-verify.mjs`
- **Target**: `context/project/present/talk/templates/playwright-verify.mjs`
- **Lines**: 128
- **Content**: Playwright slide verification script. Starts dev server, visits each slide, checks for visible errors / console errors / blank slides, optional screenshots. Exit 0 = all pass.

#### 1.5 Template: pptx-project/generate_deck.py

- **Source**: `/home/benjamin/.config/zed/.claude_NEW/context/project/present/talk/templates/pptx-project/generate_deck.py`
- **Target**: `context/project/present/talk/templates/pptx-project/generate_deck.py`
- **Lines**: 291
- **Content**: Theme-aware PowerPoint skeleton script demonstrating titled slides, bullet slides, and table slides. Includes all helper functions (add_titled_slide, apply_body_style, add_pptx_table, add_pptx_figure, etc.). CLI with --theme and --output args.

#### 1.6 Template: pptx-project/theme_mappings.json

- **Source**: `/home/benjamin/.config/zed/.claude_NEW/context/project/present/talk/templates/pptx-project/theme_mappings.json`
- **Target**: `context/project/present/talk/templates/pptx-project/theme_mappings.json`
- **Lines**: 125
- **Content**: python-pptx theme constants for all three themes (academic-clean, clinical-teal, ucsf-institutional). Translates CSS-based theme JSONs to python-pptx values (pt sizes instead of rem, first font name instead of fallback chain, inch-based spacing).

#### 1.7 Template: pptx-project/README.md

- **Source**: `/home/benjamin/.config/zed/.claude_NEW/context/project/present/talk/templates/pptx-project/README.md`
- **Target**: `context/project/present/talk/templates/pptx-project/README.md`
- **Lines**: 84
- **Content**: Usage instructions for pptx-assembly-agent. Documents theme table, component equivalents (Vue -> python-pptx), slide dimensions, dependencies.

#### 1.8 Template: slidev-project/README.md

- **Source**: `/home/benjamin/.config/zed/.claude_NEW/context/project/present/talk/templates/slidev-project/README.md`
- **Target**: `context/project/present/talk/templates/slidev-project/README.md`
- **Lines**: 37
- **Content**: Slidev project template scaffold instructions.

#### 1.9 Template: slidev-project/package.json, vite.config.ts, lz-string-esm.js, .npmrc

These 4 files are copied as-is from the source:

| File | Source | Target | Lines |
|------|--------|--------|-------|
| `package.json` | `slidev-project/package.json` | `context/project/present/talk/templates/slidev-project/package.json` | 22 |
| `vite.config.ts` | `slidev-project/vite.config.ts` | `context/project/present/talk/templates/slidev-project/vite.config.ts` | 11 |
| `lz-string-esm.js` | `slidev-project/lz-string-esm.js` | `context/project/present/talk/templates/slidev-project/lz-string-esm.js` | 509 |
| `.npmrc` | `slidev-project/.npmrc` | `context/project/present/talk/templates/slidev-project/.npmrc` | 1 |

### 2. Existing Files to Update

#### 2.1 academic-clean.json -- Add footer section

**File**: `context/project/present/talk/themes/academic-clean.json`

**Change**: Add `"footer"` object after `"borders"` block, before closing `}` and `"slidev_config"`:

```json
// After the "borders" block, add:
"footer": {
    "custom_footer_style": "margin-top: 1.5rem; font-size: 0.8rem; color: #6b7280; display: flex; justify-content: space-between;",
    "positioning": "flow (margin-top), sits above Slidev built-in footer bar"
},
```

**Exact edit**: Insert after line 36 (`"table_header": "2px solid #3b5998"`) and before line 37 (`}`), adding a comma to the `"table_header"` line and the new footer block.

Old (lines 35-38):
```json
    "accent_bar": "3px solid #3b5998",
    "table_header": "2px solid #3b5998"
  },
  "slidev_config": {
```

New:
```json
    "accent_bar": "3px solid #3b5998",
    "table_header": "2px solid #3b5998"
  },
  "footer": {
    "custom_footer_style": "margin-top: 1.5rem; font-size: 0.8rem; color: #6b7280; display: flex; justify-content: space-between;",
    "positioning": "flow (margin-top), sits above Slidev built-in footer bar"
  },
  "slidev_config": {
```

#### 2.2 clinical-teal.json -- Add footer section

**File**: `context/project/present/talk/themes/clinical-teal.json`

**Change**: Same structure as academic-clean but with color `#64748b`.

Old (lines 35-38):
```json
    "accent_bar": "3px solid #0d9488",
    "table_header": "2px solid #0d9488"
  },
  "slidev_config": {
```

New:
```json
    "accent_bar": "3px solid #0d9488",
    "table_header": "2px solid #0d9488"
  },
  "footer": {
    "custom_footer_style": "margin-top: 1.5rem; font-size: 0.8rem; color: #64748b; display: flex; justify-content: space-between;",
    "positioning": "flow (margin-top), sits above Slidev built-in footer bar"
  },
  "slidev_config": {
```

#### 2.3 talk-structure.md -- Append format-specific notes

**File**: `context/project/present/patterns/talk-structure.md`

**Change**: Append 5 lines at end of file:

```markdown

### Format-Specific Implementation Notes
- **Slidev**: See `talk/patterns/slidev-pitfalls.md` for setup, footer positioning, and mermaid gotchas
- **PowerPoint**: See `talk/patterns/pptx-generation.md` for python-pptx API patterns and component helpers
- Theme JSON files include a `footer` section with correct positioning guidance for custom footers
```

#### 2.4 conclusions-takeaway.md -- Append custom footer section

**File**: `context/project/present/talk/contents/conclusions/conclusions-takeaway.md`

**Change**: Append ~14 lines at end of file:

```markdown

## Custom Footer (optional)

If the slide needs a custom footer (e.g., repo links, receipt pointers), use a flow-positioned div at the end of the slide content:

```html
<div style="margin-top: 1.5rem; font-size: 0.8rem; color: var(--ac-muted);
     display: flex; justify-content: space-between;">
  <span>Left text</span>
  <span>Right text</span>
</div>
```

This sits above Slidev's built-in footer bar via normal document flow.
```

#### 2.5 talk/index.json -- Rewrite with new entries

**File**: `context/project/present/talk/index.json`

**Change**: Replace entire file with the new version that includes:
1. Description changed: "Slidev-based academic talks" -> "Slidev and PowerPoint academic talks"
2. Themes array: add ucsf-institutional entry
3. Patterns array: add slidev-pitfalls and pptx-generation entries
4. New `"templates"` category added with playwright-verify and pptx-project entries

The complete replacement content is the 70-line JSON from the zed source at `/home/benjamin/.config/zed/.claude_NEW/context/project/present/talk/index.json`.

### 3. UCSF Template Integration

**Source file**: `/home/benjamin/.config/zed/examples/test-files/UCSF_ZSFG_Template_16x9.pptx` (3,046,296 bytes, confirmed exists)

**Target path**: `context/project/present/talk/templates/pptx-project/UCSF_ZSFG_Template_16x9.pptx`

**Integration approach**:
- Copy the binary .pptx file into the pptx-project template directory
- This template serves as the institutional starting point when `output_format=pptx` and theme is `ucsf-institutional`
- The pptx-assembly-agent can use `Presentation("UCSF_ZSFG_Template_16x9.pptx")` instead of `Presentation()` to inherit UCSF slide masters, logos, and layout presets
- The `theme_mappings.json` already contains ucsf-institutional constants that match this template's color palette
- Add a note to `pptx-project/README.md` about the UCSF template (one additional line in the Files table)

**Note**: The .pptx is ~3MB. Git will track it as a binary. Consider adding it to .gitattributes as `*.pptx binary` if not already present.

### 4. Index Entry Additions

The following 8 entries need to be added to `index-entries.json` at `/home/benjamin/.config/nvim/.claude/extensions/present/index-entries.json`.

All paths are relative to the context root (`context/`).

```json
{
  "path": "project/present/talk/patterns/slidev-pitfalls.md",
  "domain": "project",
  "subdomain": "present",
  "topics": ["slidev", "pitfalls", "footer", "mermaid", "pdf-export"],
  "keywords": ["slidev", "pitfalls", "footer"],
  "summary": "Slidev implementation gotchas (footer, Mermaid, PDF export, lz-string)",
  "line_count": 254,
  "load_when": {
    "task_types": ["present"],
    "agents": ["slides-research-agent", "slidev-assembly-agent"],
    "commands": ["/slides"]
  }
},
{
  "path": "project/present/talk/patterns/pptx-generation.md",
  "domain": "project",
  "subdomain": "present",
  "topics": ["pptx", "python-pptx", "powerpoint", "generation"],
  "keywords": ["pptx", "python-pptx", "powerpoint"],
  "summary": "python-pptx API patterns for PPTX slide creation, theme application, component helpers, speaker notes, and error handling",
  "line_count": 829,
  "load_when": {
    "task_types": ["present"],
    "agents": ["pptx-assembly-agent"],
    "commands": ["/slides"]
  }
},
{
  "path": "project/present/talk/index.json",
  "domain": "project",
  "subdomain": "present",
  "topics": ["talk", "library", "index", "themes", "patterns"],
  "keywords": ["talk", "library", "index"],
  "summary": "Talk library index with theme, pattern, component, and template registrations",
  "line_count": 70,
  "load_when": {
    "task_types": ["present"],
    "agents": ["slides-research-agent", "pptx-assembly-agent", "slidev-assembly-agent"],
    "commands": ["/slides"]
  }
},
{
  "path": "project/present/talk/templates/playwright-verify.mjs",
  "domain": "project",
  "subdomain": "present",
  "topics": ["playwright", "verification", "slides", "testing"],
  "keywords": ["playwright", "verify", "slides"],
  "summary": "Playwright slide verification script for Slidev decks",
  "line_count": 128,
  "load_when": {
    "task_types": ["present"],
    "agents": ["slidev-assembly-agent"],
    "commands": ["/slides"]
  }
},
{
  "path": "project/present/talk/templates/pptx-project/theme_mappings.json",
  "domain": "project",
  "subdomain": "present",
  "topics": ["pptx", "theme", "colors", "fonts", "mappings"],
  "keywords": ["pptx", "theme", "colors"],
  "summary": "Theme constants for python-pptx generation (colors, fonts, sizes for all themes)",
  "line_count": 125,
  "load_when": {
    "task_types": ["present"],
    "agents": ["pptx-assembly-agent"],
    "commands": ["/slides"]
  }
},
{
  "path": "project/present/talk/templates/pptx-project/generate_deck.py",
  "domain": "project",
  "subdomain": "present",
  "topics": ["pptx", "generate", "python-pptx", "skeleton"],
  "keywords": ["pptx", "generate", "python-pptx"],
  "summary": "Skeleton PowerPoint generation script with theme-aware helpers",
  "line_count": 291,
  "load_when": {
    "task_types": ["present"],
    "agents": ["pptx-assembly-agent"],
    "commands": ["/slides"]
  }
},
{
  "path": "project/present/talk/templates/pptx-project/README.md",
  "domain": "project",
  "subdomain": "present",
  "topics": ["pptx", "project", "template", "usage"],
  "keywords": ["pptx", "project", "template"],
  "summary": "PowerPoint generation template usage instructions and component equivalents",
  "line_count": 84,
  "load_when": {
    "task_types": ["present"],
    "agents": ["pptx-assembly-agent"],
    "commands": ["/slides"]
  }
},
{
  "path": "project/present/talk/templates/slidev-project/README.md",
  "domain": "project",
  "subdomain": "present",
  "topics": ["slidev", "project", "template", "scaffold"],
  "keywords": ["slidev", "project", "template"],
  "summary": "Slidev project scaffold template with pnpm/vite/lz-string configuration",
  "line_count": 37,
  "load_when": {
    "task_types": ["present"],
    "agents": ["slidev-assembly-agent"],
    "commands": ["/slides"]
  }
}
```

**Note on agent names**: The index entries reference `slides-research-agent`, `pptx-assembly-agent`, and `slidev-assembly-agent`. These agents do not exist yet in the nvim extension (they are created by task 403). The index entries should use these future agent names to be correct when all tasks are complete. The existing `slides-agent` entries in index-entries.json should be left unchanged for now (task 407 handles the manifest/metadata updates).

### 5. File Inventory Summary

| # | File | Action | Source | Lines |
|---|------|--------|--------|-------|
| 1 | `talk/themes/ucsf-institutional.json` | CREATE | zed themes/ | 50 |
| 2 | `talk/patterns/pptx-generation.md` | CREATE | zed patterns/ | 829 |
| 3 | `talk/patterns/slidev-pitfalls.md` | CREATE | zed patterns/ | 254 |
| 4 | `talk/templates/playwright-verify.mjs` | CREATE | zed templates/ | 128 |
| 5 | `talk/templates/pptx-project/generate_deck.py` | CREATE | zed templates/pptx-project/ | 291 |
| 6 | `talk/templates/pptx-project/theme_mappings.json` | CREATE | zed templates/pptx-project/ | 125 |
| 7 | `talk/templates/pptx-project/README.md` | CREATE | zed templates/pptx-project/ | 84 |
| 8 | `talk/templates/pptx-project/UCSF_ZSFG_Template_16x9.pptx` | COPY | zed examples/test-files/ | binary |
| 9 | `talk/templates/slidev-project/README.md` | CREATE | zed templates/slidev-project/ | 37 |
| 10 | `talk/templates/slidev-project/package.json` | CREATE | zed templates/slidev-project/ | 22 |
| 11 | `talk/templates/slidev-project/vite.config.ts` | CREATE | zed templates/slidev-project/ | 11 |
| 12 | `talk/templates/slidev-project/lz-string-esm.js` | CREATE | zed templates/slidev-project/ | 509 |
| 13 | `talk/templates/slidev-project/.npmrc` | CREATE | zed templates/slidev-project/ | 1 |
| 14 | `talk/themes/academic-clean.json` | UPDATE | add footer section | +4 lines |
| 15 | `talk/themes/clinical-teal.json` | UPDATE | add footer section | +4 lines |
| 16 | `talk/patterns/talk-structure.md` (in `patterns/`) | UPDATE | append format notes | +5 lines |
| 17 | `talk/contents/conclusions/conclusions-takeaway.md` | UPDATE | append custom footer | +14 lines |
| 18 | `talk/index.json` | UPDATE | rewrite with new entries | 70 lines |
| 19 | `index-entries.json` (extension root) | UPDATE | add 8 new entries | +~80 lines |

**Total**: 13 new files created, 1 binary copied, 5 existing files updated.

All source paths are under `/home/benjamin/.config/zed/.claude_NEW/context/project/present/talk/`.
All target paths are under `/home/benjamin/.config/nvim/.claude/extensions/present/context/project/present/talk/` (except index-entries.json which is at the extension root).

## Decisions

- UCSF .pptx template placed inside `pptx-project/` subdirectory alongside generate_deck.py and theme_mappings.json, keeping all PPTX-related template files together
- Index entries use future agent names (slides-research-agent, pptx-assembly-agent, slidev-assembly-agent) rather than current slides-agent, since the entries must be correct when task 403 completes
- The slidev-project template files (lz-string-esm.js at 509 lines) are copied as-is despite being large, since they are vendored dependencies needed by Slidev projects

## Risks & Mitigations

- **Binary .pptx in git**: The 3MB UCSF template will increase repo size. Mitigation: this is a one-time addition and the file is unlikely to change frequently.
- **Agent name mismatch**: Index entries reference agents that don't exist until task 403 completes. Mitigation: the extension loader merges index entries only when the extension is loaded, and the new agents will exist before the extension is reloaded.
- **Large pptx-generation.md**: At 829 lines, this is a substantial context file. Mitigation: it is only loaded for pptx-assembly-agent, not for all present tasks.

## Appendix

### Search Queries Used
- Read DIFF.md for complete change inventory
- Read all zed .claude_NEW source files for exact content
- Read existing nvim present/ files for diff targets
- Verified UCSF .pptx template existence at zed examples path
- Listed templates directory structure

### References
- DIFF.md section 4 (Talk Library Context Files): lines 148-232
- DIFF.md section 7 (Context Index): lines 274-295
