# Tool Detection Patterns

Shared tool detection patterns for all filetypes agents. Reference this file to ensure consistent tool availability checking across agents.

## CLI Tool Detection

### Standard Pattern
```bash
# Check if a CLI tool is available
command -v TOOL_NAME >/dev/null 2>&1
```

### Available Tools Check
```bash
# Document conversion tools
has_markitdown=$(command -v markitdown >/dev/null 2>&1 && echo "yes" || echo "no")
has_pandoc=$(command -v pandoc >/dev/null 2>&1 && echo "yes" || echo "no")
has_typst=$(command -v typst >/dev/null 2>&1 && echo "yes" || echo "no")
has_pdflatex=$(command -v pdflatex >/dev/null 2>&1 && echo "yes" || echo "no")

# Spreadsheet tools
has_xlsx2csv=$(command -v xlsx2csv >/dev/null 2>&1 && echo "yes" || echo "no")

# Image tools (for presentations)
has_convert=$(command -v convert >/dev/null 2>&1 && echo "yes" || echo "no")  # ImageMagick
```

## Python Package Detection

### Import Check Pattern
```bash
# Check if a Python package is importable
python3 -c "import PACKAGE_NAME" 2>/dev/null && echo "yes" || echo "no"
```

### Available Packages Check
```bash
# PDF/document extraction packages
has_pymupdf=$(python3 -c "import fitz" 2>/dev/null && echo "yes" || echo "no")
has_pymupdf4llm=$(python3 -c "import pymupdf4llm" 2>/dev/null && echo "yes" || echo "no")

# Spreadsheet packages
has_pandas=$(python3 -c "import pandas" 2>/dev/null && echo "yes" || echo "no")
has_openpyxl=$(python3 -c "import openpyxl" 2>/dev/null && echo "yes" || echo "no")

# Presentation packages
has_pptx=$(python3 -c "import pptx" 2>/dev/null && echo "yes" || echo "no")

# Conversion packages
has_markitdown_py=$(python3 -c "import markitdown" 2>/dev/null && echo "yes" || echo "no")
```

## Version Detection

### Get Tool Versions
```bash
# Get version strings for compatibility checking
markitdown_version=$(markitdown --version 2>/dev/null || echo "unknown")
pandoc_version=$(pandoc --version 2>/dev/null | head -n1 | cut -d' ' -f2 || echo "unknown")
typst_version=$(typst --version 2>/dev/null | cut -d' ' -f2 || echo "unknown")
```

## MCP Server Detection

### SuperDoc MCP

SuperDoc is an MCP server for DOCX editing. Detection differs from CLI tools because MCP tools are accessed through the MCP protocol rather than the filesystem.

```bash
# Check if python-docx is available as fallback
has_python_docx=$(python3 -c "import docx" 2>/dev/null && echo "yes" || echo "no")
```

**MCP availability check**: Attempt to call `open_document` with a test path. If the MCP tool responds (even with an error about the file), SuperDoc is available. If the tool is not found, fall back to python-docx.

```python
# Conceptual detection logic
def detect_docx_editor():
    if mcp_available("superdoc"):  # open_document tool responds
        return "superdoc"
    elif python_import("docx"):     # python-docx installed
        return "python-docx"
    else:
        return None
```

## Tool Fallback Chains

### Document Conversion (to Markdown)

**PDF/EPUB/Images**:
1. **Primary**: pymupdf4llm (best PDF-to-markdown quality, structured output)
2. **Secondary**: pymupdf / fitz (text extraction + table detection)
3. **Fallback**: pandoc (limited PDF support)
4. **Last resort**: markitdown (25% success rate on PDF benchmarks)

**DOCX/PPTX/XLSX/HTML**:
1. **Primary**: markitdown (best Office format support)
2. **Fallback**: pandoc (good HTML/DOCX support)
3. **Basic**: N/A - require at least one tool

### Markdown to PDF
1. **Primary**: pandoc with pdflatex engine
2. **Fallback**: typst compile
3. **Basic**: N/A - require at least one tool

### Spreadsheet to Table
1. **Primary**: pandas + openpyxl (full Excel support, DataFrame.to_latex())
2. **Fallback**: xlsx2csv + manual table formatting
3. **Basic**: markitdown (extracts tables as markdown)

### Presentation Extraction
1. **Primary**: python-pptx (full slide/notes/image access)
2. **Fallback**: markitdown (text extraction only)
3. **Basic**: N/A - require at least one tool

### DOCX Editing (in-place)
1. **Primary**: SuperDoc MCP (full read-write, tracked changes, document creation)
2. **Fallback**: python-docx (basic read-write, no tracked changes)
3. **Basic**: N/A - require at least one tool

## Error Messages with Installation Guidance

### NixOS
```bash
echo "Missing tool: $TOOL_NAME"
echo ""
echo "Install with nix-shell (ephemeral):"
echo "  nix-shell -p $NIX_PACKAGE"
echo ""
echo "Or add to home-manager (persistent):"
echo "  home.packages = with pkgs; [ $NIX_PACKAGE ];"
```

### Ubuntu/Debian
```bash
echo "Missing tool: $TOOL_NAME"
echo ""
echo "Install with apt:"
echo "  sudo apt install $APT_PACKAGE"
echo ""
echo "Or with pip (Python packages):"
echo "  pip install $PIP_PACKAGE"
```

### macOS
```bash
echo "Missing tool: $TOOL_NAME"
echo ""
echo "Install with Homebrew:"
echo "  brew install $BREW_PACKAGE"
echo ""
echo "Or with pip (Python packages):"
echo "  pip install $PIP_PACKAGE"
```

## Package Name Mappings

| Tool | NixOS Package | apt Package | Homebrew Package | pip Package |
|------|---------------|-------------|------------------|-------------|
| markitdown | python3Packages.markitdown | - | - | markitdown |
| pymupdf | python3Packages.pymupdf | - | - | pymupdf |
| pymupdf4llm | - | - | - | pymupdf4llm |
| pandoc | pandoc | pandoc | pandoc | - |
| typst | typst | - | typst | - |
| pdflatex | texlive.combined.scheme-basic | texlive-base | mactex-no-gui | - |
| pandas | python3Packages.pandas | python3-pandas | - | pandas |
| openpyxl | python3Packages.openpyxl | python3-openpyxl | - | openpyxl |
| python-pptx | python3Packages.python-pptx | - | - | python-pptx |
| xlsx2csv | python3Packages.xlsx2csv | - | - | xlsx2csv |
| superdoc | - | - | - | @superdoc-dev/mcp (npx) |
| python-docx | python3Packages.python-docx | python3-python-docx | - | python-docx |

## Aggregated Detection Function

```bash
# Detect all available tools and return JSON
detect_tools() {
  cat <<EOF
{
  "cli": {
    "markitdown": $(command -v markitdown >/dev/null 2>&1 && echo "true" || echo "false"),
    "pandoc": $(command -v pandoc >/dev/null 2>&1 && echo "true" || echo "false"),
    "typst": $(command -v typst >/dev/null 2>&1 && echo "true" || echo "false"),
    "pdflatex": $(command -v pdflatex >/dev/null 2>&1 && echo "true" || echo "false"),
    "xlsx2csv": $(command -v xlsx2csv >/dev/null 2>&1 && echo "true" || echo "false")
  },
  "python": {
    "pymupdf": $(python3 -c "import fitz" 2>/dev/null && echo "true" || echo "false"),
    "pymupdf4llm": $(python3 -c "import pymupdf4llm" 2>/dev/null && echo "true" || echo "false"),
    "pandas": $(python3 -c "import pandas" 2>/dev/null && echo "true" || echo "false"),
    "openpyxl": $(python3 -c "import openpyxl" 2>/dev/null && echo "true" || echo "false"),
    "pptx": $(python3 -c "import pptx" 2>/dev/null && echo "true" || echo "false"),
    "markitdown": $(python3 -c "import markitdown" 2>/dev/null && echo "true" || echo "false")
  }
}
EOF
}
```

## Agent Integration

All filetypes agents should:

1. **Reference this file** at the start of tool detection:
   ```markdown
   @context/project/filetypes/tools/tool-detection.md
   ```

2. **Use consistent patterns** from this file for tool checking

3. **Provide platform-specific installation guidance** when tools are missing

4. **Report detected tools in metadata** for debugging and transparency
