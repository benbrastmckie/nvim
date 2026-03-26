# Research Report: Task #277

**Task**: 277 - Research PDF annotation extraction tools
**Generated**: 2026-03-25
**Source**: /meta interview (auto-generated)
**Status**: Pre-populated from interview context

---

## Context Summary

**Purpose**: Research and compare PDF annotation extraction tools to determine the best option for the /scrape command
**Scope**: Tool evaluation and comparison
**Affected Components**: scrape-agent tool selection logic
**Domain**: filetypes extension
**Language**: meta

## Task Requirements

Evaluate PDF annotation extraction tools to determine which tool(s) the scrape-agent should use as primary and fallback options. The current implementation in `after/ftplugin/tex.lua` uses `pdfannots` via the `PdfAnnots()` function.

### Current Implementation

The existing `<leader>la` keymap in `after/ftplugin/tex.lua` (lines 49-70) uses `pdfannots`:
- Extracts annotations from a PDF referenced via vimtex context
- Outputs to markdown format in an `Annotations/` directory
- Simple invocation: `pdfannots -o "output.md" "input.pdf"`

### Tools to Evaluate

1. **pdfannots** (current) - Python tool for extracting PDF annotations
   - Already installed at `/run/current-system/sw/bin/pdfannots`
   - Supports markdown and JSON output formats (`-f {md,json}`)
   - Options: column detection (`-n`), section grouping, progress output
   - Annotation types: highlights, comments, notes, underlines, strikeouts

2. **PyMuPDF (fitz)** - Python library for PDF manipulation
   - Full annotation API via `page.annots()`
   - Supports all annotation types including stamps, links, widgets
   - Can extract annotation content, author, date, color, position
   - Also provides text extraction, image extraction, page rendering

3. **pdfplumber** - Python library for PDF text/table extraction
   - Focused on text and table extraction rather than annotations
   - May not have first-class annotation support
   - Better suited for document conversion than annotation scraping

4. **poppler-utils** - System utilities for PDF manipulation
   - `pdftotext` for text extraction, not annotation-specific
   - Limited annotation support compared to dedicated tools

5. **pdf-annotate** - Python library for adding annotations to PDFs
   - Focused on writing annotations, not reading them
   - Not suitable for extraction use case

### Evaluation Criteria

- Annotation type coverage (highlights, comments, notes, underlines, strikeouts, stamps)
- Output format flexibility (markdown, JSON, structured data)
- Ease of integration (CLI vs library)
- Fallback chain compatibility with document-agent pattern
- NixOS availability
- Performance on large PDFs
- Active maintenance

## Integration Points

- **Component Type**: Agent tool selection
- **Affected Area**: `.claude/extensions/filetypes/agents/scrape-agent.md`
- **Action Type**: Research/evaluate
- **Related Files**:
  - `after/ftplugin/tex.lua` (current pdfannots usage)
  - `.claude/extensions/filetypes/agents/document-agent.md` (pattern reference)
  - `.claude/extensions/filetypes/context/project/filetypes/tools/tool-detection.md`

## Dependencies

None - this task can be started independently.

## Interview Context

### User-Provided Information
- User currently uses pdfannots for PDF annotation extraction
- Wants to evaluate alternatives for potential improvement
- Integration target is the filetypes extension of the .claude/ agent system
- Tool must work on NixOS (pdfannots already available via nix)

### Effort Assessment
- **Estimated Effort**: 1-2 hours
- **Complexity Notes**: Straightforward tool comparison; main effort is testing each tool's annotation type coverage

---

*This research report was auto-generated during task creation via /meta command.*
*For deeper investigation, run `/research 277 [focus]` with a specific focus prompt.*
