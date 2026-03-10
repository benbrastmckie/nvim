# Filetypes Extension Context

Documentation and patterns for file format conversion operations.

## Overview

The filetypes extension provides comprehensive file format conversion capabilities for documents, spreadsheets, and presentations. This context directory contains patterns and tool documentation used by the extension's agents.

## Directory Structure

```
context/project/filetypes/
  README.md                           # This file
  patterns/
    spreadsheet-tables.md            # Spreadsheet to LaTeX/Typst table patterns
    presentation-slides.md           # PPTX extraction and slide generation patterns
  tools/
    tool-detection.md                # Shared tool availability checking patterns
    dependency-guide.md              # Platform-specific installation instructions
    mcp-integration.md               # MCP server integration documentation
```

## Conversion Capabilities

### Documents (/convert)

| From | To | Tools |
|------|----|----|
| PDF | Markdown | markitdown, pandoc |
| DOCX | Markdown | markitdown, pandoc |
| HTML | Markdown | markitdown, pandoc |
| Images | Markdown | markitdown |
| Markdown | PDF | pandoc, typst |

### Spreadsheets (/table)

| From | To | Tools |
|------|----|----|
| XLSX | LaTeX table | pandas + openpyxl |
| XLSX | Typst table | pandas, csv() |
| CSV | LaTeX table | pandas |
| CSV | Typst table | Typst csv() |
| ODS | LaTeX/Typst | pandas |

### Presentations (/slides)

| From | To | Tools |
|------|----|----|
| PPTX | Beamer | python-pptx + pandoc |
| PPTX | Polylux | python-pptx |
| PPTX | Touying | python-pptx |
| Markdown | PPTX | pandoc |

## Agent Context Loading

Agents reference context files using @-includes:

```markdown
@context/project/filetypes/tools/tool-detection.md
@context/project/filetypes/patterns/spreadsheet-tables.md
@context/project/filetypes/patterns/presentation-slides.md
```

## Quick Reference

### Check Tool Availability

```bash
# All CLI tools
command -v markitdown pandoc typst pdflatex

# Python packages
python3 -c "import pandas, openpyxl, pptx"
```

### Common Conversions

```bash
# PDF to Markdown
markitdown document.pdf > document.md

# XLSX to LaTeX table
python3 -c "import pandas as pd; print(pd.read_excel('data.xlsx').to_latex())"

# Markdown to Beamer
pandoc -t beamer -o slides.tex slides.md
```

## Related Documentation

- **EXTENSION.md**: Extension overview and skill-agent mapping
- **tool-detection.md**: Detailed tool checking patterns
- **dependency-guide.md**: Installation instructions for all platforms
- **mcp-integration.md**: MCP server configuration
