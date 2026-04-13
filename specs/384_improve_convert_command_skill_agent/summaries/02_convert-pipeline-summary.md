# Implementation Summary: Refactor /convert Pipeline for PyMuPDF

- **Task**: 384 - Improve /convert command-skill-agent
- **Status**: [COMPLETED]
- **Started**: 2026-04-13T12:00:00Z
- **Completed**: 2026-04-13T12:30:00Z
- **Effort**: 30 minutes
- **Dependencies**: None
- **Artifacts**: plans/02_convert-pipeline-refactor.md
- **Standards**: status-markers.md, artifact-management.md, tasks.md, summary-format.md

## Overview

Refactored the filetypes extension's document-agent and three supporting context files to use pymupdf as the primary PDF extraction backend, replacing the markitdown-only approach. The changes align document-agent's tool selection patterns with scrape-agent, which already uses pymupdf successfully.

## What Changed

- Replaced single markitdown-primary tool chain in document-agent.md with format-aware routing tree (PDF -> pymupdf, DOCX/PPTX/XLSX -> markitdown)
- Added pymupdf detection pattern (`python3 -c "import fitz"`) and pymupdf4llm optional enhancement to tool-detection.md
- Updated conversion-tables.md to show pymupdf as primary for PDF, EPUB, and Images; markitdown as primary for Office formats
- Added pymupdf and pymupdf4llm to dependency-guide.md with NixOS/Ubuntu/macOS installation instructions
- Added NixOS fragility note for markitdown in dependency-guide.md
- Added EPUB conversion support (pymupdf primary, pandoc fallback)

## Decisions

- pymupdf4llm is listed as optional enhancement (not required) since base pymupdf provides adequate output
- markitdown is demoted to last-resort for PDF but remains primary for DOCX/PPTX/XLSX/HTML
- EPUB support added as a new format, using pymupdf as primary tool
- Inline Python extraction code follows the same pattern as scrape-agent (fitz.open, get_text, find_tables)

## Impacts

- /convert with PDF input will now prefer pymupdf over markitdown, producing higher quality output
- No runtime code changes -- all modifications are to agent instruction markdown files
- Existing markitdown-based conversions for Office formats are unchanged
- Tool detection now includes pymupdf in the aggregated detection function

## Follow-ups

- Consider installing pymupdf4llm for enhanced PDF-to-markdown quality (optional)
- mcp-integration.md was not updated (low priority, deferred per plan non-goals)

## References

- `specs/384_improve_convert_command_skill_agent/plans/02_convert-pipeline-refactor.md`
- `specs/384_improve_convert_command_skill_agent/reports/01_convert-pipeline-analysis.md`
- `specs/384_improve_convert_command_skill_agent/reports/03_pymupdf-vs-markitdown.md`
- `.claude/extensions/filetypes/agents/scrape-agent.md` (reference implementation)
