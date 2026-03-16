## Filetypes Extension

This project includes comprehensive file format conversion and manipulation via the filetypes extension.

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-filetypes | filetypes-router-agent | Format detection and routing to specialized agents |
| skill-filetypes | document-agent | Document format conversion (PDF/DOCX/Markdown) |
| skill-spreadsheet | spreadsheet-agent | Spreadsheet to LaTeX/Typst table conversion |
| skill-presentation | presentation-agent | Presentation extraction and slide generation |

### Supported Conversions

#### Document Conversions (via /convert)

| Source | Target | Primary Tool | Fallback |
|--------|--------|--------------|----------|
| PDF | Markdown | markitdown | pandoc |
| DOCX | Markdown | markitdown | pandoc |
| HTML | Markdown | markitdown | pandoc |
| Images | Markdown | markitdown | - |
| Markdown | PDF | pandoc | typst |

#### Spreadsheet Conversions (via /table)

| Source | Target | Primary Tool | Fallback |
|--------|--------|--------------|----------|
| XLSX | LaTeX table | pandas + openpyxl | xlsx2csv |
| XLSX | Typst table | pandas -> CSV -> Typst csv() | xlsx2csv |
| CSV | LaTeX table | pandas | manual |
| CSV | Typst table | Typst csv() | manual |
| ODS | LaTeX/Typst table | pandas | - |

#### Presentation Conversions (via /slides)

| Source | Target | Primary Tool | Fallback |
|--------|--------|--------------|----------|
| PPTX | Beamer | python-pptx + pandoc | markitdown |
| PPTX | Polylux (Typst) | python-pptx | markitdown |
| PPTX | Touying (Typst) | python-pptx | markitdown |
| Markdown | PPTX | pandoc | - |

### Command Usage

```bash
# Document conversion (format inferred)
/convert document.pdf                    # -> document.md
/convert report.docx notes.md            # -> notes.md
/convert README.md README.pdf            # -> README.pdf

# Spreadsheet to table
/table data.xlsx                         # -> data.tex (LaTeX)
/table data.xlsx output.typ --format typst
/table budget.csv budget.tex --format latex

# Presentation conversion
/slides presentation.pptx                # -> presentation.tex (Beamer)
/slides deck.pptx slides.typ --format polylux
/slides talk.pptx talk.typ --format touying
```

### Prerequisites

Install conversion tools based on your needs:

**Document Conversion**:
- `markitdown`: `pip install markitdown`
- `pandoc`: Install from package manager
- `typst`: Install for Typst output

**Spreadsheet Conversion**:
- `pandas`: `pip install pandas`
- `openpyxl`: `pip install openpyxl` (for XLSX support)
- `xlsx2csv`: `pip install xlsx2csv` (fallback)

**Presentation Conversion**:
- `python-pptx`: `pip install python-pptx`
- `pandoc`: For Beamer output

See `context/project/filetypes/tools/dependency-guide.md` for platform-specific installation instructions.

### NixOS Quick Install

```nix
# home.nix
home.packages = with pkgs; [
  pandoc typst
  (python3.withPackages (ps: with ps; [
    markitdown openpyxl pandas python-pptx xlsx2csv
  ]))
];
```

### Dependency Summary

| Tool | Purpose | Required For |
|------|---------|--------------|
| markitdown | Office to Markdown | /convert |
| pandoc | Universal converter | /convert, /slides |
| typst | Typst compiler | /convert (typst output) |
| pandas | DataFrame handling | /table |
| openpyxl | XLSX support | /table (xlsx) |
| python-pptx | PPTX extraction | /slides |
| xlsx2csv | XLSX fallback | /table (fallback) |
| pdflatex | LaTeX compilation | Beamer PDF output |

### Context Documentation

| File | Description |
|------|-------------|
| `tools/tool-detection.md` | Shared tool availability patterns |
| `tools/dependency-guide.md` | Platform-specific installation |
| `tools/mcp-integration.md` | MCP server configuration |
| `patterns/spreadsheet-tables.md` | Table conversion patterns |
| `patterns/presentation-slides.md` | Slide generation patterns |
