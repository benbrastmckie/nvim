# Research Report: Task #384 (Follow-up)

**Task**: 384 - Improve /convert command-skill-agent
**Started**: 2026-04-13T19:20:00Z
**Completed**: 2026-04-13T19:35:00Z
**Effort**: small
**Dependencies**: None
**Sources/Inputs**:
- Previous research report (01_convert-pipeline-analysis.md)
- Live tool verification (markitdown CLI, pymupdf, pandoc)
- Current filetypes extension files (document-agent, tool-detection, conversion-tables, dependency-guide)
- specs/state.json task status
- specs/ROADMAP.md
**Artifacts**:
- `specs/384_improve_convert_command_skill_agent/reports/02_convert-status-review.md`
**Standards**: report-format.md, artifact-management.md

## Executive Summary

- Markitdown CLI has self-healed: running `markitdown` recreated the stale venv with the current Python 3.12.13 interpreter. The CLI now works for PDF-to-Markdown conversion (v0.1.5).
- Markitdown Python import (`import markitdown`) still fails from the system Python because the package is installed only inside markitdown's private venv (`~/.local/share/markitdown-venv/`), not in the system site-packages.
- PyMuPDF has been upgraded from v1.27.1 to v1.27.2 and remains fully functional.
- The core architecture issues identified in the first report (document-agent hardcoded to markitdown, no pymupdf references, stale conversion tables) remain unfixed.
- pymupdf4llm is still not installed.
- The task remains valid but should be narrowed: the "fix broken markitdown" portion is largely resolved (CLI self-healed), so the remaining work is a focused refactoring of the document-agent and supporting context files to add pymupdf as primary PDF tool and restructure fallback chains.

## Context & Scope

This follow-up research re-evaluates the task after the original report identified markitdown as broken. The focus question is: "Is this task still needed, and what remains to be done?"

### Changes Since First Research (2026-04-09)

| Item | Then | Now |
|------|------|-----|
| markitdown CLI | Broken (dead venv symlink) | Working (venv auto-recreated, v0.1.5) |
| markitdown Python import | Broken | Still broken (not in system Python) |
| PyMuPDF version | 1.27.1 | 1.27.2 |
| pymupdf4llm | Not installed | Still not installed |
| document-agent.md | markitdown-only | Unchanged (still markitdown-only) |
| conversion-tables.md | markitdown as primary | Unchanged |
| tool-detection.md | No pymupdf for conversion | Unchanged |
| dependency-guide.md | No pymupdf for conversion | Unchanged |

## Findings

### 1. Markitdown Is Now Functional (CLI Only)

Running `markitdown` triggered the wrapper script to recreate the venv:
```
Setting up markitdown virtual environment...
Successfully installed markitdown-0.1.5
```

The CLI successfully converts PDF to markdown. However, the NixOS fragility issue persists -- the next Python version bump in Nix will break the venv again. This is an inherent limitation of the wrapper-script-plus-venv approach on NixOS.

The Python import (`import markitdown`) still fails because the package lives only in the private venv, not in the system Python environment.

### 2. Document Agent Still Needs Refactoring

The document-agent (341 lines) still:
- Lists markitdown as the primary tool for ALL conversions (PDF, DOCX, HTML, images)
- Has no mention of pymupdf anywhere
- Uses `command -v markitdown` for detection (CLI check only)
- Has no format-aware tool selection (single fallback chain for all formats)
- Has no table detection capability

### 3. Context Files Still Need Updates

All four context files identified in the first report remain unchanged:
- **tool-detection.md**: No pymupdf in document conversion section (only in scrape/annotation section)
- **conversion-tables.md**: markitdown listed as primary for all document conversions
- **dependency-guide.md**: pymupdf not listed for document conversion use cases
- **mcp-integration.md**: Not critical, can be deferred

### 4. Roadmap Alignment

The ROADMAP.md does not have a specific item for this task, but it falls under "Agent System Quality" in Phase 1, which includes ensuring agents follow established conventions. The scrape-agent already uses pymupdf as primary -- aligning document-agent to match is a quality improvement.

### 5. Scope Assessment

The original task description mentions three goals:
1. "Fix or replace the broken markitdown integration" -- **Partially resolved** (CLI self-healed, but Python import still broken)
2. "Refactor to use pymupdf as the primary extraction backend" -- **Still needed** (no changes made)
3. "Ensure the command-skill-agent architecture follows established .claude/ conventions" -- **Still needed** (document-agent diverges from scrape-agent patterns)

## Decisions

- The task remains valid and should proceed to planning/implementation.
- The scope should be narrowed to focus on the refactoring work (goals 2 and 3), since the markitdown CLI fix happened organically.
- The markitdown NixOS fragility should be documented as a known issue but is not a blocker.
- pymupdf should become the primary tool for PDF extraction; markitdown should be repositioned as a secondary/fallback option (since it works but is fragile on NixOS).
- For non-PDF formats (DOCX, HTML, PPTX), markitdown and pandoc should remain the primary tools since pymupdf cannot handle those formats.

## Recommendations

### Recommended Scope (Narrowed)

**Keep in scope** (still needed):
1. Restructure document-agent with format-aware tool selection tree
2. Add pymupdf as primary PDF extraction tool in document-agent
3. Update tool-detection.md with pymupdf for document conversion
4. Update conversion-tables.md with new tool priorities
5. Update dependency-guide.md to list pymupdf for document conversion

**Deprioritize/Remove**:
- Fix markitdown venv (already self-healed)
- Install pymupdf4llm (optional enhancement, not blocking)
- Update mcp-integration.md (low priority, can be a follow-up)

### Implementation Effort

The remaining work is a straightforward refactoring of 4-5 markdown files:
- document-agent.md: Major rewrite of tool selection logic (~50 lines changed)
- tool-detection.md: Add pymupdf detection for conversion (~10 lines added)
- conversion-tables.md: Update PDF row and add EPUB (~5 lines changed)
- dependency-guide.md: Add pymupdf section for conversion (~15 lines added)

Estimated effort: **small-to-medium** (mostly text/markdown edits, no code changes).

### Task Description Update

The task description should be updated to reflect the narrowed scope:
> Refactor the filetypes extension's document-agent to use pymupdf as primary PDF extraction backend, add format-aware tool selection, and update supporting context files (tool-detection, conversion-tables, dependency-guide) to align with scrape-agent patterns.

## Risks & Mitigations

- **Risk**: Markitdown venv may break again on next Nix Python update
  - **Mitigation**: Documenting pymupdf as primary for PDF means this is non-critical; markitdown becomes a nice-to-have fallback
- **Risk**: Changing tool priorities in context files could confuse agents that have cached old context
  - **Mitigation**: Context files are loaded fresh each session; no caching issue

## Appendix

### Tool Verification Results (2026-04-13)

| Tool | Status | Version | Notes |
|------|--------|---------|-------|
| markitdown CLI | Working | 0.1.5 | Venv auto-recreated |
| markitdown Python | Broken | N/A | Not in system Python |
| pymupdf | Working | 1.27.2 | Upgraded since last check |
| pymupdf4llm | Not installed | N/A | Optional enhancement |
| pandoc | Working | 3.7.0.2 | Unchanged |
| python3 | Working | 3.12.13 | Unchanged |

### Files Still Requiring Changes

1. `.claude/extensions/filetypes/agents/document-agent.md` (341 lines) -- major refactor
2. `.claude/extensions/filetypes/context/project/filetypes/tools/tool-detection.md` (196 lines) -- add pymupdf section
3. `.claude/extensions/filetypes/context/project/filetypes/domain/conversion-tables.md` (140 lines) -- update priorities
4. `.claude/extensions/filetypes/context/project/filetypes/tools/dependency-guide.md` (298 lines) -- add pymupdf
