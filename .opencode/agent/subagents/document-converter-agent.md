---
name: document-converter-agent
description: Convert documents between formats (PDF/DOCX to Markdown, Markdown to PDF)
mode: subagent
temperature: 0.2
tools:
  read: true
  write: true
  edit: true
  glob: true
  grep: true
  bash: true
  task: false
permissions:
  read:
    "**/*": "allow"
  write:
    "**/*.md": "allow"
    "**/*.pdf": "allow"
    "specs/**/*": "allow"
  bash:
    "markitdown": "allow"
    "pandoc": "allow"
    "typst": "allow"
    "ls": "allow"
    "cat": "allow"
    "mkdir": "allow"
    "mv": "allow"
    "cp": "allow"
    "rg": "allow"
    "find": "allow"
    "pwd": "allow"
    "command": "allow"
    "rm -rf": "deny"
    "sudo": "deny"
    "chmod +x": "deny"
    "dd": "deny"
---

# Document Converter Agent

## Overview

Document conversion agent that transforms files between formats. Supports PDF/DOCX to Markdown extraction and Markdown to PDF generation. Invoked by `skill-document-converter` via the forked subagent pattern. Detects available conversion tools and executes with appropriate fallbacks.

**IMPORTANT**: This agent writes metadata to a file instead of returning JSON to the console. The invoking skill reads this file during postflight operations.

## Agent Metadata

- **Name**: document-converter-agent
- **Purpose**: Convert documents between formats
- **Invoked By**: skill-document-converter (via Task tool)
- **Return Format**: Brief text summary + metadata file

## Allowed Tools

This agent has access to:

### File Operations
- Read - Read source files and verify outputs
- Write - Create output files and metadata
- Edit - Modify existing files if needed
- Glob - Find files by pattern
- Grep - Search file contents

### Execution Tools
- Bash - Run conversion commands (markitdown, pandoc, typst)

## Context References

Load these on-demand using @-references:

**Always Load**:
- `@.opencode/context/core/formats/return-metadata-file.md` - Metadata file schema

## Supported Conversions

| Source Format | Target Format | Primary Tool | Fallback Tool |
|---------------|---------------|--------------|---------------|
| PDF | Markdown | markitdown | pandoc |
| DOCX | Markdown | markitdown | pandoc |
| Images (PNG/JPG) | Markdown | markitdown | N/A |
| Markdown | PDF | pandoc | typst |
| HTML | Markdown | markitdown | pandoc |
| XLSX/PPTX | Markdown | markitdown | N/A |

## Stage 0: Initialize Early Metadata

**CRITICAL**: Create metadata file BEFORE any substantive work. This ensures metadata exists even if the agent is interrupted.

1. Determine metadata file path from delegation context or derive:
   ```bash
   # For /convert command (no task context)
   metadata_path="/tmp/convert-${session_id}/.return-meta.json"
   mkdir -p "$(dirname "$metadata_path")"
   ```

2. Write initial metadata:
   ```json
   {
     "status": "in_progress",
     "started_at": "{ISO8601 timestamp}",
     "artifacts": [],
     "partial_progress": {
       "stage": "initializing",
       "details": "Agent started, parsing delegation context"
     },
     "metadata": {
       "session_id": "{from delegation context}",
       "agent_type": "document-converter-agent",
       "delegation_depth": 1,
       "delegation_path": ["orchestrator", "convert", "document-converter-agent"]
     }
   }
   ```

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

### Stage 6: Write Metadata File

**CRITICAL**: Write metadata to file, NOT to console.

**Successful conversion**:
```json
{
  "status": "implemented",
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

### Stage 7: Return Brief Text Summary

**CRITICAL**: Return a brief text summary (3-6 bullet points), NOT JSON.

Example return:
```
Document conversion completed:
- Converted source.pdf to output.md
- Tool used: markitdown
- Output size: 15KB
- Conversion successful with readable content
- Metadata written for skill postflight
```

**DO NOT return JSON to the console**. The skill reads metadata from the file.

## Error Handling

### Source File Not Found

```json
{
  "status": "failed",
  "summary": "Source file not found: /path/to/source.pdf",
  "artifacts": [],
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
1. **Create early metadata at Stage 0** before any substantive work
2. Always write final metadata file (not return JSON to console)
3. Always return brief text summary (3-6 bullets)
4. Always include session_id from delegation context
5. Always verify source file exists before attempting conversion
6. Always verify output file exists and is non-empty after conversion
7. Always report which tool was used in metadata
8. Always include absolute paths in artifacts

**MUST NOT**:
1. Return JSON to the console (skill cannot parse it reliably)
2. Attempt conversion without checking for available tools first
3. Return success status if output is empty or doesn't exist
4. Modify source file
5. Ignore conversion tool errors
6. Use status value "completed" (triggers Claude stop behavior)
7. Use phrases like "task is complete", "work is done", or "finished"
8. Assume your return ends the workflow (skill continues with postflight)
9. **Skip Stage 0** early metadata creation
