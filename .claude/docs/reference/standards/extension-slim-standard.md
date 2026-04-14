# EXTENSION.md Slim-Down Standard

## Purpose

EXTENSION.md files are injected into CLAUDE.md context when loaded via `<leader>ac`. Large EXTENSION.md files waste context window budget on documentation that agents rarely need during routing. This standard defines maximum size and required content for EXTENSION.md files.

## Size Limit

**Maximum: 60 lines** for any EXTENSION.md file.

Current total across 14 extensions: ~1,111 lines. Target after migration: ~350 lines (~68% reduction).

## Required Sections

EXTENSION.md must contain only these four sections:

| Section | Lines | Content |
|---------|-------|---------|
| **Header** | 3-5 | Extension name, version, one-line description |
| **Routing Table** | 5-15 | Skill-to-agent mappings (primary purpose of EXTENSION.md) |
| **Command List** | 5-15 | Command name, usage, one-line description per row |
| **Context Pointers** | 3-5 | Lazy @-references to context files (max 5 pointers) |

See the Migration Template below for a concrete example of all four sections.

## Sections That Must Move to Context Files

The following content types do NOT belong in EXTENSION.md:

| Content Type | Move To | Example |
|---|---|---|
| Detailed usage examples | `context/project/{ext}/patterns/` | Command workflows, input/output examples |
| Architecture documentation | `context/project/{ext}/domain/` | System design, component relationships |
| Conversion/compatibility tables | `context/project/{ext}/domain/` | Format support matrices with fallbacks |
| Migration guides | `context/project/{ext}/domain/` | Version upgrade instructions |
| Troubleshooting | `context/project/{ext}/domain/` | Error resolution, debugging tips |
| Prerequisites/installation | `context/project/{ext}/tools/` | Dependency lists, platform setup |
| MCP tool integration | `context/project/{ext}/tools/` | Server config, API keys |
| Forcing data schemas | `context/project/{ext}/patterns/` | JSON structures, data formats |
| Mode descriptions | `context/project/{ext}/domain/` | Operational mode details |

## Context File Location

New context files go in the extension's existing context directory structure:

```
.claude/extensions/{ext}/
  context/project/{ext}/
    domain/       # Domain knowledge, reference tables
    patterns/     # Workflow patterns, usage examples
    tools/        # Tool setup, dependencies
    templates/    # Output templates
```

## Index Integration

Every new context file must have an entry in the extension's `index-entries.json`:

```json
{
  "path": "context/project/{ext}/domain/conversion-tables.md",
  "description": "Format conversion support matrix with fallback chains",
  "line_count": 45,
  "load_when": {
    "agents": ["relevant-agent"],
    "languages": ["{ext}"]
  }
}
```

## Migration Template

### Before (143 lines - filetypes example)

```markdown
## Filetypes Extension
[3 lines description]
### Skill-Agent Mapping       -- KEEP (routing)
[8 lines]
### Supported Conversions     -- MOVE (detail tables)
[35 lines across 4 subsections]
### Command Usage             -- SLIM (keep table, move examples)
[22 lines with code blocks]
### Prerequisites             -- MOVE (installation docs)
[20 lines]
### NixOS Quick Install       -- MOVE (platform-specific)
[8 lines]
### Dependency Summary        -- MOVE (reference table)
[16 lines]
### Context Documentation     -- KEEP as pointers
[8 lines]
```

### After (~40 lines)

```markdown
## Filetypes Extension

File format conversion and manipulation: documents, spreadsheets, presentations, PDF annotations.

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-filetypes | filetypes-router-agent | Format detection and routing |
| skill-filetypes-spreadsheet | filetypes-spreadsheet-agent | Spreadsheet to LaTeX/Typst |
| skill-presentation | presentation-agent | Slide extraction and generation |
| skill-scrape | scrape-agent | PDF annotation extraction |

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| /convert | `/convert file.pdf` | Convert between document formats (incl. `/convert deck.pptx --format beamer`) |
| /table | `/table data.xlsx` | Convert spreadsheets to LaTeX/Typst tables |
| /scrape | `/scrape paper.pdf` | Extract PDF annotations to Markdown/JSON |

### Context

- @context/project/filetypes/domain/conversion-tables.md - Format support matrices
- @context/project/filetypes/tools/dependency-guide.md - Installation instructions
- @context/project/filetypes/patterns/spreadsheet-tables.md - Table conversion patterns
- @context/project/filetypes/patterns/presentation-slides.md - Slide generation patterns
```

## Verification Checklist

After slimming an EXTENSION.md:

1. [ ] File is under 60 lines
2. [ ] Header with name and description present
3. [ ] Routing table includes all skill-agent mappings
4. [ ] Command table lists all commands with usage
5. [ ] Context pointers reference moved content (max 5 lines)
6. [ ] Moved content exists in context files
7. [ ] New context files have index-entries.json entries
8. [ ] Extension loads without errors via `<leader>ac`
9. [ ] Commands still route correctly after changes
