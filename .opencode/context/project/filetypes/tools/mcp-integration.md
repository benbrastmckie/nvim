# MCP Server Integration for File Conversion

Model Context Protocol (MCP) servers that provide document conversion capabilities. When available, MCP servers offer tighter Claude integration than CLI tools.

## Available MCP Servers

### markitdown-mcp

**Repository**: `g4titanx/markitdown-mcp`

Wraps Microsoft's markitdown library for MCP access.

**Capabilities**:
- Convert Office documents (DOCX, XLSX, PPTX) to Markdown
- Convert PDF to Markdown
- Convert HTML to Markdown
- Image to Markdown (with OCR if available)

**Configuration** (claude_desktop_config.json):
```json
{
  "mcpServers": {
    "markitdown": {
      "command": "uvx",
      "args": ["markitdown-mcp"]
    }
  }
}
```

**Alternative (npx)**:
```json
{
  "mcpServers": {
    "markitdown": {
      "command": "npx",
      "args": ["-y", "@anthropics/markitdown-mcp"]
    }
  }
}
```

### mcp-pandoc

**Repository**: `vivekVells/mcp-pandoc`

Wraps pandoc for universal format conversion.

**Capabilities**:
- Convert between Markdown, HTML, LaTeX, DOCX, etc.
- Generate Beamer slides from Markdown
- Apply templates and filters
- Citation processing with citeproc

**Configuration**:
```json
{
  "mcpServers": {
    "pandoc": {
      "command": "uvx",
      "args": ["mcp-pandoc"]
    }
  }
}
```

**Supported Conversions**:
- Markdown -> PDF, DOCX, HTML, LaTeX
- DOCX -> Markdown, HTML, LaTeX
- LaTeX -> PDF, HTML
- Markdown -> Beamer slides

### md-converter

**Functionality**: Markdown to Office format conversion

Converts Markdown to DOCX, XLSX, or PPTX for sharing with non-technical collaborators.

**Note**: Complements markitdown-mcp by providing reverse direction conversions.

## MCP vs CLI Decision

### Use MCP When:
- Running in Claude Desktop or similar MCP-enabled environment
- Need tighter integration with Claude conversation
- MCP server provides better error handling
- Converting multiple files in a conversation

### Use CLI When:
- MCP servers not configured
- Need specific CLI flags not exposed by MCP
- Running in environments without MCP support
- Need to capture detailed conversion logs

## Fallback Pattern

The filetypes agents implement a fallback pattern:

```
1. Check if MCP server is available for the conversion
2. If MCP available: Use MCP server
3. If MCP unavailable: Fall back to CLI tools
4. If no tools available: Return error with installation instructions
```

### Detection Logic

```python
def get_conversion_tool(source_format, target_format):
    # Check MCP availability (hypothetical)
    if mcp_available("markitdown"):
        if target_format == "markdown":
            return "mcp:markitdown"

    if mcp_available("pandoc"):
        if target_format in ["pdf", "docx", "latex", "beamer"]:
            return "mcp:pandoc"

    # Fall back to CLI
    if command_exists("markitdown"):
        return "cli:markitdown"

    if command_exists("pandoc"):
        return "cli:pandoc"

    return None
```

## Integration Notes

### markitdown-mcp

Best for:
- Office -> Markdown conversions
- PDF -> Markdown (text extraction)
- Image -> Markdown (with descriptions)

Limitations:
- One-way conversion (to Markdown only)
- No output format options
- May not preserve all formatting

### mcp-pandoc

Best for:
- Universal format conversion
- Academic documents (citations, math)
- Beamer slide generation
- Template-based conversions

Limitations:
- Requires pandoc installation
- PDF output requires LaTeX
- Complex filter syntax

## Configuration Examples

### Full MCP Setup

```json
{
  "mcpServers": {
    "markitdown": {
      "command": "uvx",
      "args": ["markitdown-mcp"]
    },
    "pandoc": {
      "command": "uvx",
      "args": ["mcp-pandoc"]
    }
  }
}
```

### With Environment Variables

```json
{
  "mcpServers": {
    "pandoc": {
      "command": "uvx",
      "args": ["mcp-pandoc"],
      "env": {
        "PANDOC_PATH": "/usr/local/bin/pandoc",
        "PDF_ENGINE": "xelatex"
      }
    }
  }
}
```

## Troubleshooting

### "MCP server not responding"

1. Check server is running: `ps aux | grep mcp`
2. Verify configuration in claude_desktop_config.json
3. Check logs for startup errors
4. Try running the server command manually

### "uvx: command not found"

uvx is part of uv (Python package manager):
```bash
pip install uv
# or
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### "MCP tool not available"

Some conversions may not be exposed as MCP tools. Check the server documentation for available tools and fall back to CLI when needed.
