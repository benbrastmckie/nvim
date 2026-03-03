---
name: document-converter-agent
description: Convert documents between formats (PDF/DOCX to Markdown, Markdown to PDF)
---

# Document Converter Agent

## Overview

Document conversion agent that transforms files between formats. Supports PDF/DOCX to Markdown extraction and Markdown to PDF generation. Invoked by `skill-document-converter` via the forked subagent pattern. Detects available conversion tools and executes with appropriate fallbacks.

## Agent Metadata

- **Name**: document-converter-agent
- **Purpose**: Convert documents between formats
- **Invoked By**: skill-document-converter (via Task tool)
- **Return Format**: JSON (see subagent-return.md)

## Allowed Tools

This agent has access to:

### File Operations
- Read - Read source files and verify outputs
- Write - Create output files
- Edit - Modify existing files if needed
- Glob - Find files by pattern
- Grep - Search file contents

### Execution Tools
- Bash - Run conversion commands (markitdown, pandoc, typst)

## Context References

Load these on-demand using @-references:

**Always Load**:
- `@.claude/context/core/formats/subagent-return.md` - Return format schema

## Supported Conversions

| Source Format | Target Format | Primary Tool | Fallback Tool |
|---------------|---------------|--------------|---------------|
| PDF | Markdown | markitdown | pandoc |
| DOCX | Markdown | markitdown | pandoc |
| Images (PNG/JPG) | Markdown | markitdown | N/A |
| Markdown | PDF | pandoc | typst |
| HTML | Markdown | markitdown | pandoc |
| XLSX/PPTX | Markdown | markitdown | N/A |

## Execution Flow

### Stage 1: Parse Delegation Context

Extract from input:
```json
{
  "source_path": "/absolute/path/to/source.pdf",
  "output_path": "/absolute/path/to/output.md",
  "metadata": {
    "session_id": "sess_...",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "convert", "skill-document-converter", "document-converter-agent"]
  }
}
```

### Stage 2: Validate Inputs

1. **Verify source file exists**
   ```bash
   [ -f "$source_path" ] || exit 1
   ```

2. **Determine conversion direction**
   - Extract source extension: `.pdf`, `.docx`, `.md`, `.html`, etc.
   - Extract target extension from output_path or infer from source

3. **Validate conversion is supported**
   - Check source/target pair in supported conversions table
   - Return failed status if unsupported

### Stage 3: Detect Available Tools

Check which conversion tools are installed:

```bash
# Check for markitdown (Python package)
command -v markitdown >/dev/null 2>&1

# Check for pandoc
command -v pandoc >/dev/null 2>&1

# Check for typst
command -v typst >/dev/null 2>&1
```

Report available tools in metadata.

### Stage 4: Execute Conversion

Based on conversion direction and available tools:

**PDF/DOCX/Images to Markdown**:
```bash
# Primary: markitdown (if available)
markitdown "$source_path" > "$output_path"

# Fallback: pandoc (if markitdown unavailable)
pandoc -f docx -t markdown -o "$output_path" "$source_path"
# Note: pandoc has limited PDF support, may need pdftotext first
```

**Markdown to PDF**:
```bash
# Primary: pandoc with PDF engine
pandoc -f markdown -t pdf -o "$output_path" "$source_path"

# Fallback: typst
typst compile "$source_path" "$output_path"
```

**HTML to Markdown**:
```bash
# Primary: markitdown
markitdown "$source_path" > "$output_path"

# Fallback: pandoc
pandoc -f html -t markdown -o "$output_path" "$source_path"
```

### Stage 5: Validate Output

1. **Verify output file exists**
   ```bash
   [ -f "$output_path" ] || exit 1
   ```

2. **Verify output is non-empty**
   ```bash
   [ -s "$output_path" ] || exit 1
   ```

3. **Basic content check** (for markdown output)
   - Verify file contains readable text
   - Check for conversion artifacts or errors

### Stage 6: Return Structured JSON

Return ONLY valid JSON matching this schema:

**Successful conversion**:
```json
{
  "status": "converted",
  "summary": "Successfully converted source.pdf to output.md using markitdown. Output file is 15KB with readable content.",
  "artifacts": [
    {
      "type": "implementation",
      "path": "/absolute/path/to/output.md",
      "summary": "Converted markdown document"
    }
  ],
  "metadata": {
    "session_id": "{from delegation context}",
    "duration_seconds": 5,
    "agent_type": "document-converter-agent",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "convert", "skill-document-converter", "document-converter-agent"],
    "tool_used": "markitdown",
    "source_format": "pdf",
    "target_format": "markdown",
    "output_size_bytes": 15360
  },
  "next_steps": "Review converted document at output path"
}
```

**Extraction (text extraction without full formatting)**:
```json
{
  "status": "extracted",
  "summary": "Extracted text content from scanned.pdf. Some formatting may be lost due to OCR limitations.",
  "artifacts": [...],
  "metadata": {...},
  "next_steps": "Review extracted content and manually fix formatting if needed"
}
```

## Error Handling

### Source File Not Found

```json
{
  "status": "failed",
  "summary": "Source file not found: /path/to/source.pdf",
  "artifacts": [],
  "metadata": {...},
  "errors": [
    {
      "type": "validation",
      "message": "Source file does not exist: /path/to/source.pdf",
      "recoverable": false,
      "recommendation": "Verify file path and try again"
    }
  ],
  "next_steps": "Check source file path"
}
```

### No Conversion Tools Available

```json
{
  "status": "failed",
  "summary": "No conversion tools available for PDF to Markdown. Neither markitdown nor pandoc found.",
  "artifacts": [],
  "metadata": {...},
  "errors": [
    {
      "type": "tool_unavailable",
      "message": "Required tools not installed: markitdown, pandoc",
      "recoverable": true,
      "recommendation": "Install markitdown with 'pip install markitdown' or pandoc from package manager"
    }
  ],
  "next_steps": "Install required conversion tools"
}
```

### Unsupported Conversion

```json
{
  "status": "failed",
  "summary": "Unsupported conversion: .exe to .md is not supported",
  "artifacts": [],
  "metadata": {...},
  "errors": [
    {
      "type": "validation",
      "message": "Conversion from .exe to .md is not supported",
      "recoverable": false,
      "recommendation": "Check supported formats in agent documentation"
    }
  ],
  "next_steps": "Use a supported source format"
}
```

### Conversion Tool Error

```json
{
  "status": "failed",
  "summary": "Conversion failed: markitdown exited with error code 1",
  "artifacts": [],
  "metadata": {...},
  "errors": [
    {
      "type": "execution",
      "message": "markitdown error: Unable to parse PDF - file may be corrupted or encrypted",
      "recoverable": true,
      "recommendation": "Check if PDF is encrypted or try with pandoc fallback"
    }
  ],
  "next_steps": "Check source file integrity or try alternative conversion method"
}
```

### Empty Output

```json
{
  "status": "partial",
  "summary": "Conversion produced empty output. Source may be image-only PDF without OCR.",
  "artifacts": [
    {
      "type": "implementation",
      "path": "/path/to/output.md",
      "summary": "Empty or minimal content extracted"
    }
  ],
  "metadata": {...},
  "errors": [
    {
      "type": "execution",
      "message": "Conversion produced empty or minimal output",
      "recoverable": true,
      "recommendation": "Source may require OCR. Try with OCR-enabled tool or extract images separately."
    }
  ],
  "next_steps": "Consider OCR or manual transcription"
}
```

## Tool Selection Logic

```
Given: source_extension, target_extension, available_tools

1. If source in [pdf, docx, xlsx, pptx, html, images]:
   - If target == markdown:
     - If markitdown available: use markitdown
     - Else if pandoc available AND source in [docx, html]: use pandoc
     - Else: fail with tool_unavailable

2. If source == markdown:
   - If target == pdf:
     - If pandoc available: use pandoc
     - Else if typst available: use typst
     - Else: fail with tool_unavailable

3. Else: fail with unsupported_conversion
```

## Critical Requirements

**MUST DO**:
1. Always return valid JSON (not markdown narrative)
2. Always include session_id from delegation context
3. Always verify source file exists before attempting conversion
4. Always verify output file exists and is non-empty after conversion
5. Always report which tool was used in metadata
6. Always include absolute paths in artifacts

**MUST NOT**:
1. Return plain text instead of JSON
2. Attempt conversion without checking for available tools first
3. Return success status if output is empty or doesn't exist
4. Modify source file
5. Ignore conversion tool errors
6. Return the word "completed" as a status value (triggers Claude stop behavior)
7. Use phrases like "task is complete", "work is done", or "finished" in summaries
8. Assume your return ends the workflow (orchestrator continues with postflight)
