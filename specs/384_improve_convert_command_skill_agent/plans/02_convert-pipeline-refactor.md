# Implementation Plan: Refactor /convert Pipeline for PyMuPDF

- **Task**: 384 - Improve /convert command-skill-agent
- **Status**: [IMPLEMENTING]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_convert-pipeline-analysis.md, reports/02_convert-status-review.md, reports/03_pymupdf-vs-markitdown.md
- **Artifacts**: plans/02_convert-pipeline-refactor.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Refactor the filetypes extension's document-agent to use pymupdf as the primary PDF extraction backend, replacing the markitdown-only approach. Add format-aware tool selection so PDF uses pymupdf while DOCX/PPTX/XLSX continue using markitdown. Update four supporting context files (tool-detection, conversion-tables, dependency-guide, document-agent) to align with the scrape-agent pattern that already uses pymupdf successfully.

### Research Integration

Three research reports inform this plan:
- **Report 01** (2026-04-09): Identified broken markitdown, mapped full pipeline architecture, catalogued all files needing changes, recommended pymupdf as primary PDF tool.
- **Report 02** (2026-04-13): Confirmed markitdown CLI self-healed (v0.1.5), narrowed scope to refactoring work only, verified all four context files still unchanged.
- **Report 03** (2026-04-13): Web research confirmed pymupdf4llm decisively outperforms markitdown for PDF quality (structure, tables, formatting). MarkItDown PDF rated 25% success in benchmarks. Validates pymupdf-first strategy.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task advances the "Agent System Quality" item under Phase 1 of the ROADMAP: ensuring agents follow established conventions. The scrape-agent already uses pymupdf as primary tool; aligning document-agent to match is a quality/consistency improvement.

## Goals & Non-Goals

**Goals**:
- Make pymupdf the primary PDF extraction tool in document-agent
- Add format-aware tool selection (PDF vs DOCX/PPTX/XLSX routing)
- Update tool-detection.md, conversion-tables.md, and dependency-guide.md to reflect new tool priorities
- Align document-agent patterns with scrape-agent (the reference implementation)

**Non-Goals**:
- Installing pymupdf4llm (optional enhancement, not blocking)
- Fixing markitdown Python import (only available in private venv, not a pipeline concern)
- Updating mcp-integration.md (low priority, can be a follow-up)
- Modifying the command, skill, or router layers (only the agent and context files change)
- Adding Marker or Docling integration (future upgrade path if needed)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Document-agent refactor breaks existing /convert usage | M | L | Changes are to markdown agent instructions, not code; easy to revert via git |
| pymupdf4llm not installed limits PDF-to-markdown quality | L | M | Base pymupdf get_text() with find_tables() produces adequate output; recommend installation as optional step |
| Markitdown venv breaks again on next Nix Python bump | L | H | pymupdf is now primary for PDF, so markitdown breakage is non-critical; document as known NixOS fragility |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Refactor document-agent.md [COMPLETED]

**Goal**: Restructure document-agent to use format-aware tool selection with pymupdf as primary PDF tool, following scrape-agent patterns.

**Tasks**:
- [ ] Read current document-agent.md (341 lines) and scrape-agent.md (519 lines) for reference
- [ ] Replace single markitdown-primary tool chain with format-aware routing tree:
  - PDF: pymupdf (primary) -> pandoc (fallback) -> markitdown (fallback)
  - DOCX/PPTX/XLSX: markitdown (primary) -> pandoc (fallback)
  - HTML: markitdown (primary) -> pandoc (fallback)
  - EPUB: pymupdf (primary) -> pandoc (fallback)
  - Images: pymupdf with OCR (primary) -> markitdown (fallback)
- [ ] Add pymupdf detection: `python3 -c "import fitz"` (matching scrape-agent pattern)
- [ ] Add inline Python extraction code for PDF using pymupdf (text extraction + table detection)
- [ ] Update tool detection references to include pymupdf for document conversion
- [ ] Preserve existing error handling patterns and subagent-return format
- [ ] Keep markitdown as a fallback option (not removed, just demoted for PDF)

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/extensions/filetypes/agents/document-agent.md` - Major refactor of tool selection logic and extraction code

**Verification**:
- Document-agent has format-aware tool selection tree
- pymupdf is listed as primary for PDF extraction
- markitdown is listed as primary for DOCX/PPTX/XLSX
- Detection pattern matches scrape-agent (`python3 -c "import fitz"`)

---

### Phase 2: Update tool-detection.md and dependency-guide.md [COMPLETED]

**Goal**: Add pymupdf to the document conversion sections of tool detection and dependency documentation.

**Tasks**:
- [ ] Read current tool-detection.md (196 lines) and dependency-guide.md (298 lines)
- [ ] Add pymupdf to the document conversion tool detection section (currently only in scrape/annotation section)
- [ ] Add `has_pymupdf` check pattern for document conversion context
- [ ] Add pymupdf4llm as optional enhancement in tool detection
- [ ] Add pymupdf section to dependency-guide.md for document conversion use case (currently only listed for /scrape)
- [ ] Note NixOS markitdown fragility in dependency-guide.md

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/filetypes/context/project/filetypes/tools/tool-detection.md` - Add pymupdf detection for conversion
- `.claude/extensions/filetypes/context/project/filetypes/tools/dependency-guide.md` - Add pymupdf for conversion dependencies

**Verification**:
- tool-detection.md lists pymupdf for document conversion (not just scrape)
- dependency-guide.md includes pymupdf as a document conversion dependency
- Detection patterns are consistent with scrape-agent usage

---

### Phase 3: Update conversion-tables.md [NOT STARTED]

**Goal**: Update conversion tables to reflect new tool priorities with pymupdf as primary for PDF.

**Tasks**:
- [ ] Read current conversion-tables.md (140 lines)
- [ ] Update PDF -> Markdown row: primary=pymupdf, fallback1=pandoc, fallback2=markitdown
- [ ] Update DOCX -> Markdown row: primary=markitdown, fallback=pandoc
- [ ] Update HTML -> Markdown row: primary=markitdown, fallback=pandoc
- [ ] Add EPUB -> Markdown row: primary=pymupdf, fallback=pandoc
- [ ] Update Images -> Markdown row: primary=pymupdf (OCR), fallback=markitdown
- [ ] Ensure Markdown -> PDF row unchanged (pandoc primary, typst fallback)

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/filetypes/context/project/filetypes/domain/conversion-tables.md` - Update all document conversion rows

**Verification**:
- PDF row shows pymupdf as primary
- Non-PDF rows show markitdown or pandoc as primary (not pymupdf)
- EPUB row exists
- Table is internally consistent with document-agent routing

---

### Phase 4: Validation and Cross-Reference Check [NOT STARTED]

**Goal**: Verify all changes are consistent across files and the pipeline is coherent.

**Tasks**:
- [ ] Re-read all four modified files to verify internal consistency
- [ ] Verify tool names match across document-agent, tool-detection, conversion-tables, and dependency-guide
- [ ] Verify fallback chain order is consistent across all files
- [ ] Check that no references to removed/renamed patterns remain
- [ ] Verify document-agent frontmatter follows agent-frontmatter-standard.md

**Timing**: 15 minutes

**Depends on**: 2, 3

**Files to modify**:
- No new modifications expected (read-only verification pass)

**Verification**:
- All four files reference the same tool names and fallback order
- No stale markitdown-as-primary-for-PDF references remain
- Document-agent frontmatter is valid

## Testing & Validation

- [ ] All four modified files are syntactically valid markdown
- [ ] Document-agent has format-aware tool selection (not single-chain)
- [ ] pymupdf listed as primary for PDF in document-agent, conversion-tables, tool-detection
- [ ] markitdown listed as primary for DOCX/PPTX/XLSX in document-agent, conversion-tables
- [ ] Tool detection patterns are consistent between document-agent and scrape-agent
- [ ] No orphaned references to old tool chains remain

## Artifacts & Outputs

- `plans/02_convert-pipeline-refactor.md` (this file)
- Modified: `.claude/extensions/filetypes/agents/document-agent.md`
- Modified: `.claude/extensions/filetypes/context/project/filetypes/tools/tool-detection.md`
- Modified: `.claude/extensions/filetypes/context/project/filetypes/domain/conversion-tables.md`
- Modified: `.claude/extensions/filetypes/context/project/filetypes/tools/dependency-guide.md`

## Rollback/Contingency

All changes are to markdown files in the .claude/extensions/filetypes/ directory. Revert with `git checkout -- .claude/extensions/filetypes/` if any issues arise. No code, configuration, or runtime behavior is affected -- these are agent instruction files that are loaded fresh each session.
