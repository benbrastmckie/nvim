# Research Report: Task #278

**Task**: 278 - Create scrape-agent for PDF annotation extraction
**Generated**: 2026-03-25
**Source**: /meta interview (auto-generated)
**Status**: Pre-populated from interview context

---

## Context Summary

**Purpose**: Create a scrape-agent following the document-agent pattern for PDF annotation extraction
**Scope**: New agent in filetypes extension
**Affected Components**: `.claude/extensions/filetypes/agents/scrape-agent.md`
**Domain**: filetypes extension
**Language**: meta

## Task Requirements

Create `scrape-agent.md` in `.claude/extensions/filetypes/agents/` that:

1. Follows the `document-agent.md` pattern exactly (stages: Parse Context -> Validate -> Detect Tools -> Execute -> Validate Output -> Return JSON)
2. Detects available annotation extraction tools with fallback chain
3. Supports multiple output formats (markdown, JSON)
4. Handles annotation type filtering (highlights, comments, notes, etc.)
5. Returns structured JSON matching `subagent-return.md` schema

### Pattern Reference: document-agent.md

The document-agent follows this execution flow:
- **Stage 1**: Parse delegation context (source_path, output_path, metadata with session_id)
- **Stage 2**: Validate inputs (file exists, conversion supported)
- **Stage 3**: Detect available tools (`command -v` checks)
- **Stage 4**: Execute conversion (primary tool -> fallback)
- **Stage 5**: Validate output (exists, non-empty, content check)
- **Stage 6**: Return structured JSON

### Scrape-Agent Specific Features

**Tool Detection**:
```bash
# Primary: pdfannots
command -v pdfannots >/dev/null 2>&1

# Fallback: python3 with PyMuPDF (based on research from Task 277)
python3 -c "import fitz" 2>/dev/null
```

**Execution Options**:
- Output format: `--format {md,json}` (pdfannots native) or custom formatting
- Annotation filtering: highlight, comment, note, underline, strikeout
- Column detection for multi-column PDFs
- Section grouping/ungrouping

**Output Formats**:
- Markdown (default): Grouped by page/section with annotation text
- JSON: Structured data with annotation type, page, position, content, author

### Agent Metadata

```yaml
---
name: scrape-agent
description: Extract annotations and comments from PDF files
---
```

## Integration Points

- **Component Type**: Agent
- **Affected Area**: `.claude/extensions/filetypes/agents/`
- **Action Type**: Create
- **Related Files**:
  - `.claude/extensions/filetypes/agents/document-agent.md` (pattern to follow)
  - `.claude/context/core/formats/subagent-return.md` (return format)
  - `after/ftplugin/tex.lua` (existing pdfannots usage for reference)

## Dependencies

- Task #277: Research results determine which tools to use as primary/fallback

## Interview Context

### User-Provided Information
- Agent should follow document-agent.md pattern exactly
- Must integrate with filetypes-router-agent dispatch
- Tool detection with fallback chain is required
- Structured JSON return format mandatory

### Effort Assessment
- **Estimated Effort**: 1-2 hours
- **Complexity Notes**: Moderate - pattern is well-established from document-agent, main work is adapting for annotation-specific features

---

*This research report was auto-generated during task creation via /meta command.*
*For deeper investigation, run `/research 278 [focus]` with a specific focus prompt.*
