# Filetypes Extension

File format conversion, manipulation, and in-place editing for documents, spreadsheets, presentations, and PDF annotations. Integrates MCP-backed tools (SuperDoc, openpyxl) with classical pipelines (markitdown, pandoc, python-pptx) through a router agent that dispatches by file type.

## Overview

This extension provides five commands for file manipulation tasks:

| Command | Purpose | Typical Inputs |
|---------|---------|----------------|
| `/convert` | Convert between document formats (PDF/DOCX/Markdown/HTML) | `.pdf`, `.docx`, `.md`, `.html` |
| `/table` | Convert spreadsheets to LaTeX or Typst table source | `.xlsx`, `.csv` |
| `/slides` | Convert presentations to Beamer, Polylux, or Touying | `.pptx`, `.key` |
| `/scrape` | Extract PDF annotations (highlights, comments) to Markdown/JSON | annotated `.pdf` |
| `/edit` | In-place Office document editing with tracked changes | `.docx` (SuperDoc MCP) |

## Installation

This extension is loaded via `<leader>ac` in Neovim. Once loaded, the commands above become available at the Claude Code prompt.

## MCP Tool Setup

Two MCP servers power the spreadsheet and DOCX editing flows. Both are installable via `npx`:

### SuperDoc (for `/edit`)

Provides tracked-changes editing for `.docx` files.

```bash
npx -y @superdoc-dev/mcp
```

Configured automatically in `manifest.json`. No API key required.

**Used by**: `docx-edit-agent` (for tracked-changes edits requested via `/edit`)

### openpyxl (for `/table`)

Provides spreadsheet access and cell-level manipulation.

```bash
npx -y @jonemo/openpyxl-mcp
```

Configured automatically in `manifest.json`. No API key required.

**Used by**: `spreadsheet-agent` (for reading `.xlsx` structure and formulas)

**Note**: Subagents cannot access project-scoped MCP servers. The SuperDoc and openpyxl servers must be configured in user scope (`~/.claude.json`) for `docx-edit-agent` and `spreadsheet-agent` to use them. The `manifest.json` entries declare the servers for the extension, but Claude Code's scoping rules still apply.

## Commands

### /convert

Convert between document formats using markitdown and pandoc pipelines.

**Syntax**:
```bash
/convert input.pdf                    # PDF -> Markdown (via markitdown)
/convert report.docx --to=html        # DOCX -> HTML (via pandoc)
/convert notes.md --to=pdf            # Markdown -> PDF (via pandoc + LaTeX)
```

**Agent**: Routed through `filetypes-router-agent` which dispatches to `document-agent`.

### /table

Convert spreadsheets to LaTeX or Typst table source with column alignment inference.

**Syntax**:
```bash
/table data.xlsx                      # Default target: LaTeX
/table data.csv --to=typst            # Typst table output
/table budget.xlsx --sheet="Q1"       # Specific sheet
```

**Agent**: `spreadsheet-agent` (uses `openpyxl` MCP for `.xlsx` reads)

### /slides

Convert slide decks to a LaTeX/Typst presentation framework.

**Syntax**:
```bash
/slides deck.pptx                     # Default: Beamer
/slides deck.pptx --to=polylux        # Polylux (Typst)
/slides deck.pptx --to=touying        # Touying (Typst)
```

**Agent**: `presentation-agent` (uses python-pptx for slide extraction)

### /scrape

Extract PDF annotations (highlights, comments, sticky notes) to structured formats.

**Syntax**:
```bash
/scrape paper.pdf                     # Markdown output
/scrape paper.pdf --format=json       # JSON output
```

**Agent**: `scrape-agent`

### /edit

In-place editing of Office documents with tracked-changes support.

**Syntax**:
```bash
/edit report.docx "Add an executive summary section at the top"
/edit memo.docx "Change all occurrences of 'Q4 2025' to 'Q1 2026'"
```

**Agent**: `docx-edit-agent` (uses `superdoc` MCP)

## Architecture

```
filetypes/
├── manifest.json              # Extension configuration (v2.2.0)
├── EXTENSION.md               # CLAUDE.md merge content
├── index-entries.json         # Context discovery entries
├── README.md                  # This file
│
├── commands/                  # Slash commands
│   ├── convert.md             # /convert command
│   ├── table.md               # /table command
│   ├── slides.md              # /slides command
│   ├── scrape.md              # /scrape command
│   └── edit.md                # /edit command
│
├── skills/                    # Skill wrappers
│   ├── skill-filetypes/       # Router skill (dispatches to document-agent)
│   ├── skill-spreadsheet/     # Spreadsheet conversion
│   ├── skill-presentation/    # Presentation conversion
│   ├── skill-scrape/          # PDF annotation extraction
│   └── skill-docx-edit/       # In-place DOCX editing
│
├── agents/                    # Agent definitions
│   ├── filetypes-router-agent.md   # Format detection and routing
│   ├── document-agent.md           # Document format conversion
│   ├── spreadsheet-agent.md        # Spreadsheet conversion
│   ├── presentation-agent.md       # Presentation conversion
│   ├── scrape-agent.md             # PDF annotation extraction
│   └── docx-edit-agent.md          # DOCX in-place editing
│
└── context/                   # Domain knowledge
    └── project/
        └── filetypes/
            └── ...            # Format-specific reference material
```

## Skill-Agent Mapping

| Skill | Agent(s) | Purpose |
|-------|----------|---------|
| skill-filetypes | filetypes-router-agent, document-agent | Format detection; dispatches to document-agent for document conversion |
| skill-spreadsheet | spreadsheet-agent | Spreadsheet to LaTeX/Typst table conversion |
| skill-presentation | presentation-agent | Slide deck extraction and framework generation |
| skill-scrape | scrape-agent | PDF annotation extraction |
| skill-docx-edit | docx-edit-agent | DOCX in-place editing (SuperDoc MCP) |

**Dual-agent dispatch note**: `skill-filetypes` is unusual in that it maps to two agents. The skill first invokes `filetypes-router-agent` to detect the file type; for document-category files (PDF/DOCX/Markdown/HTML), routing forwards to `document-agent` within the same skill execution. Other categories (spreadsheet, presentation, etc.) are served by their own dedicated skills listed above.

## Language Routing

This extension is file-type-driven rather than task-type-driven. The `task_type` field in `manifest.json` is `null`; the router agent performs runtime detection based on file extension and MIME type.

| File category | Extensions | Target agent |
|---------------|-----------|--------------|
| Document | `.pdf`, `.docx`, `.md`, `.html`, `.rtf` | `document-agent` |
| Spreadsheet | `.xlsx`, `.xls`, `.csv`, `.ods` | `spreadsheet-agent` |
| Presentation | `.pptx`, `.ppt`, `.key`, `.odp` | `presentation-agent` |
| Annotated PDF | `.pdf` with annotations | `scrape-agent` |
| DOCX edit | `.docx` (edit mode) | `docx-edit-agent` |

## Workflow

```
User invokes /{command} <file>
    |
    v
[1] Skill parses arguments, validates file exists
    |
    v
[2] filetypes-router-agent (for /convert) OR dedicated agent
    |  detects file type, selects pipeline
    v
[3] Agent calls tool pipeline:
    |  - markitdown (PDF/DOCX/HTML -> Markdown)
    |  - pandoc (general conversion)
    |  - python-pptx (PPTX extraction)
    |  - openpyxl MCP (XLSX read)
    |  - SuperDoc MCP (DOCX edit)
    v
[4] Agent writes output artifact, returns summary
    |
    v
Output written to same directory as input (or user-specified path)
```

## Output Artifacts

| Command | Output Location | Format |
|---------|-----------------|--------|
| `/convert` | Same directory as input (or `--output=` path) | Target format |
| `/table` | Same directory, `.tex` or `.typ` | LaTeX or Typst table source |
| `/slides` | Same directory, `.tex` or `.typ` | Beamer/Polylux/Touying source |
| `/scrape` | Same directory, `.md` or `.json` | Structured annotations |
| `/edit` | Edits input file in place, creates `.bak` backup | Modified DOCX |

## Key Patterns

### Router Dispatch
The `filetypes-router-agent` is a thin routing layer that inspects the input file and selects the appropriate downstream agent. It does not perform conversion itself; it exists so `/convert` can accept any document-category file without the command having to enumerate extensions.

### MCP + Classical Tool Fallback
Where an MCP server is available (SuperDoc, openpyxl), agents prefer it for rich operations. For read-only or simpler operations, classical CLI tools (pandoc, markitdown, python-pptx) are used directly. This keeps the extension usable when MCP servers are unavailable.

### In-Place Editing Safety
`/edit` always creates a `.bak` backup before modifying a DOCX file. SuperDoc MCP tracks changes so the user can review edits in Word.

## Tool Dependencies

| Tool | Purpose | Install |
|------|---------|---------|
| [markitdown](https://github.com/microsoft/markitdown) | Document -> Markdown conversion | `pip install markitdown` |
| [pandoc](https://pandoc.org/) | General document conversion | System package (`apt install pandoc`, `brew install pandoc`) |
| [python-pptx](https://python-pptx.readthedocs.io/) | PPTX parsing | `pip install python-pptx` |
| [openpyxl MCP](https://www.npmjs.com/package/@jonemo/openpyxl-mcp) | XLSX manipulation | `npx -y @jonemo/openpyxl-mcp` |
| [SuperDoc MCP](https://www.npmjs.com/package/@superdoc-dev/mcp) | DOCX editing with tracked changes | `npx -y @superdoc-dev/mcp` |

## References

- [SuperDoc MCP documentation](https://github.com/superdoc-dev/mcp)
- [openpyxl MCP documentation](https://github.com/jonemo/openpyxl-mcp)
- [markitdown project](https://github.com/microsoft/markitdown)
- [pandoc user guide](https://pandoc.org/MANUAL.html)
