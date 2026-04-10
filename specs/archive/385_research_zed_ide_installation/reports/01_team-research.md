# Research Report: Task #385

**Task**: Research Zed IDE installation plan for partner's laptop
**Date**: 2026-04-09
**Mode**: Team Research (4 teammates)

## Summary

Zed IDE is a viable VSCode replacement for AI-assisted workflows thanks to ACP (Agent Client Protocol), which enables Claude Code, OpenCode, and Codex to run natively inside Zed without modification. The existing `.claude/` agent system is already ACP-portable and will work in Zed immediately. However, Zed **cannot** open or render Microsoft Office files and never will (webview support is blocked), so a companion app (LibreOffice or MS Office) is mandatory. For programmatic Office document editing, the recommended path is **SuperDoc's MCP server** (180+ deterministic tools, local execution, formatting preservation) rather than the lossy markdown round-trip approach. For visual/interactive Office editing, **Claude Cowork** (Claude Desktop's agentic mode) is the best complement. The "precise location editing" concept for Word documents is feasible via text anchors and paragraph indices, but paragraph indices are unstable (they shift on insert/delete) — bookmarks or unique text patterns are the reliable addressing mechanism.

## Key Findings

### 1. Zed + AI Tool Integration (High Confidence)

All three AI tools work in Zed via ACP:

| Tool | Integration | Status |
|------|------------|--------|
| Claude Code | Native ACP agent, runs in Agent Panel with diff review UI | Public beta (Sep 2025) |
| OpenCode | ACP adapter, documented support | Production |
| Codex | ACP adapter, out-of-box in Zed | Production (Oct 2025) |

The `.claude/` agent system (skills, agents, commands, extensions) works in Zed today without modification. ACP automatically discovers CLAUDE.md files in projects. Investment should target the `.claude/` system itself, not Zed-specific integrations.

### 2. Office Document Editing Architecture (High Confidence)

Three tiers of Office file manipulation exist, each suited to different use cases:

**Tier 1 — Visual editing (Claude Cowork / Claude Desktop)**:
- Interactive upload → describe changes → download cycle
- Cross-application desktop control
- Best for: one-off edits, formatting-sensitive work, document review
- Limitation: no scripted repeatability, 30MB file size limit

**Tier 2 — Deterministic MCP tools (SuperDoc Document Engine)**:
- 180+ atomic tools: find/replace with formatting preservation, tracked changes, comments, tables
- Local execution, no cloud dependency
- Preserves all formatting, styles, and document structure
- Best for: precise editing, batch operations, tracked changes
- Recommended as primary backend for filetypes extension evolution

**Tier 3 — Script generation (python-docx / OOXML manipulation)**:
- Unpack ZIP → grep XML → Python script → repack pattern
- Used by claude-office-skills (tfriedel) and anthropics/skills (official)
- Best for: custom operations not covered by MCP tools
- Limitations: cannot write tracked changes, no .docm support, round-trip fidelity issues

**NOT recommended**: Markdown round-trip (docx → markdown → edit → docx). This is architecturally lossy — destroys styles, tracked changes, page breaks, and formatting. Acceptable only for prose-only documents where formatting loss is tolerable.

### 3. Precise Location Editing in Word Documents (Medium-High Confidence)

Word has **no line numbers**. Addressing options, ranked by reliability:

| Method | Stability | Tool Support | Best For |
|--------|-----------|-------------|----------|
| Unique text patterns (grep anchors) | High — survives edits | claude-office-skills, any MCP | Most editing operations |
| Bookmarks (`<w:bookmarkStart>`) | High — persistent IDs | python-docx (via XML), SuperDoc | Template-based workflows |
| Paragraph index (0-based) | Low — shifts on insert/delete | Office-Word-MCP-Server, python-docx | Single-pass operations only |
| Structure landmarks ("Section 3.2") | Medium — semantic, not positional | Claude reasoning | Professional/legal documents |
| Content controls | High — named anchors | Word UI, limited python-docx | Form-like documents |

**Critical insight from Critic**: Paragraph indices are positional, not persistent. Insert one paragraph and all subsequent indices shift. Any production workflow must use text anchors or bookmarks, not indices. Additionally, tables, headers, footnotes, and textboxes contain paragraphs that are NOT in the body paragraph list — counting only body paragraphs silently misses content.

### 4. Zed Cannot Render Office Files (High Confidence)

- No webview API in Zed (GitHub issue #21208 — blocked by Linux/Wayland incompatibility and GPUI rendering priority)
- All VSCode Office extensions (Office Viewer, Excel Viewer, Syncfusion) rely on webview — **categorically impossible** to port to Zed
- Zed extensions are WASM-sandboxed: no custom editor tabs, no arbitrary filesystem access, no subprocess launching

**Workaround**: Zed Tasks (`.zed/tasks.json`) can invoke `xdg-open` or `libreoffice` to open files in external apps:

```json
// .zed/tasks.json
[{
  "label": "Open in LibreOffice",
  "command": "xdg-open",
  "args": ["$ZED_FILE"],
  "reveal": "never",
  "hide": "always"
}]
```

With keybinding: `alt-o` → opens selected file in system default application.

### 5. claude-office-skills and Filetypes Extension (High Confidence)

**claude-office-skills** (tfriedel → adopted by anthropics/skills):
- SKILL.md-per-format architecture: docx/, pptx/, xlsx/, pdf/ each with SKILL.md + scripts/
- Libraries: python-docx, python-pptx, openpyxl, defusedxml, lxml, pandoc, markitdown
- Two-phase OOXML editing: unpack ZIP → edit XML → validate → repack
- Key principle: "DO NOT use markdown line numbers — they don't map to XML structure"

**Gap in existing filetypes extension**: The current `document-agent.md` only handles conversion (DOCX → Markdown, Markdown → PDF). It does NOT support editing DOCX content in place with structure preservation. A new `docx-edit-agent` and `skill-docx-edit` would fill this gap.

**Recommended evolution** (from Teammate D):
1. **Stage 1**: Fix task 384 (broken markitdown → pymupdf)
2. **Stage 2**: Add `skill-docx-mcp` using SuperDoc or Office-Word-MCP as local MCP service
3. **Stage 3**: "Document proxy" agent — extracts navigable structure, enables semantic-level edits via MCP

### 6. Installation Requirements (High Confidence)

| OS | Install Command | Requirements |
|----|----------------|-------------|
| macOS | `brew install --cask zed` | macOS 11+ |
| Linux | `curl -f https://zed.dev/install.sh \| sh` | Vulkan 1.3 driver |
| Windows | `winget install -e --id ZedIndustries.Zed` | Windows 1903+, DirectX 11 |

**Windows caveat**: Zed's Windows support has 5 known unresolved issues (key bindings, SSH remoting, WSL, extension compatibility, performance parity). The Zed team's own blog states it is "not yet ready for general release."

**Performance advantage**: Zed uses ~142-200MB RAM vs VSCode's ~730MB-1.2GB. Starts in 0.12s vs 1.2s. Significant on laptops with 8GB RAM or less.

### 7. MCP Server Landscape for Office (High Confidence)

| Server | Formats | Status | Notes |
|--------|---------|--------|-------|
| SuperDoc Document Engine | DOCX (180+ tools) | Active | Recommended — local, deterministic, format-preserving |
| microsoft/markitdown-mcp | 20+ formats → Markdown | Active | Read-only direction; `pip install markitdown-mcp` |
| dvejsada/mcp-ms-office-documents | DOCX, XLSX, PPTX, EML | Active | Docker-based, template-driven |
| GongRzhe/Office-Word-MCP-Server | DOCX | **Archived** March 2026 | Was functional, no longer maintained |
| GongRzhe/Office-PowerPoint-MCP-Server | PPTX | Active | python-pptx based |

## Synthesis

### Conflicts Resolved

1. **python-docx vs SuperDoc for DOCX editing**
   - Teammate A recommends python-docx unpack-grep-repack workflow
   - Teammate C warns about python-docx limitations (no tracked changes, no .docm, fidelity issues)
   - Teammate D recommends SuperDoc MCP as the correct solution
   - **Resolution**: SuperDoc is the preferred backend for format-preserving edits. python-docx/OOXML manipulation remains as fallback for operations SuperDoc doesn't cover. The claude-office-skills unpack-grep pattern is useful for understanding the problem but is not the production answer.

2. **Pandoc roundtrip viability**
   - Teammate B: "viable for prose documents"
   - Teammate D: "fundamentally lossy and should be avoided"
   - **Resolution**: Both are correct for their scope. Pandoc roundtrip is acceptable for plain prose (reports, essays) where formatting loss is tolerable. It should NOT be used for documents with complex formatting, tracked changes, or collaborative review.

3. **Office-Word-MCP-Server status**
   - Teammate A references it as providing paragraph_index addressing
   - Teammate B notes it was archived March 2026
   - **Resolution**: The project provides useful architectural patterns but is no longer maintained. SuperDoc is the active alternative.

### Gaps Identified

1. **Partner's OS is unknown** — Installation steps differ significantly between macOS (stable), Linux (check Vulkan), and Windows (risky). Must confirm before proceeding.
2. **Partner's actual Office workflow is unknown** — Casual writing vs collaborative tracked-changes review vs template/macro workflows require fundamentally different tooling.
3. **Cost implications not estimated** — Every AI-assisted Office edit consumes API tokens. Frequent editing could be expensive.
4. **Accessibility not researched** — Zed's screen reader, font scaling, and high-contrast support are unknown. VSCode's accessibility is substantially more mature.
5. **Cloud storage integration** — If documents are on OneDrive/SharePoint, file locking and sync conflicts become serious operational concerns.

### Recommendations

**Recommended workflow (two-tier)**:

```
Visual/Interactive Office Work    Programmatic/Batch Operations
┌─────────────────────────┐       ┌──────────────────────────┐
│  Claude Cowork          │       │  Zed + Claude Code (ACP) │
│  (Claude Desktop)       │       │  + SuperDoc MCP          │
│                         │       │  + filetypes extension   │
│  - One-off edits        │       │  - Batch edits           │
│  - Formatting work      │       │  - Format conversion     │
│  - Document review      │       │  - Table extraction      │
│  - Tracked changes      │       │  - Slide export          │
│    (visual)             │       │  - Precise text changes  │
└─────────────────────────┘       └──────────────────────────┘
         │                                    │
         └──────── LibreOffice/Word ──────────┘
                  (companion viewer)
```

**Before proceeding to plan, validate**:
1. What OS does the partner use?
2. What is the partner's primary Office workflow? (writing, reviewing, spreadsheets, presentations?)
3. Is Microsoft Office or LibreOffice installed/preferred?
4. Are documents stored locally or on OneDrive/SharePoint?

## Teammate Contributions

| Teammate | Angle | Status | Confidence | Key Contribution |
|----------|-------|--------|------------|------------------|
| A | Primary approaches | Completed | High | claude-office-skills analysis, OOXML addressing patterns, Zed Tasks workaround |
| B | Alternative patterns | Completed | High | MCP server landscape, pandoc roundtrip limits, VSCode extension gap analysis, installation steps |
| C | Critic | Completed | High | Paragraph index instability, python-docx limitations, Windows maturity risks, missing validation items |
| D | Strategic horizons | Completed | High | SuperDoc recommendation, ACP portability insight, two-tier workflow architecture, filetypes evolution roadmap |

## References

### Primary Sources
- [claude-office-skills (tfriedel)](https://github.com/tfriedel/claude-office-skills)
- [anthropics/skills (official)](https://github.com/anthropics/skills)
- [SuperDoc Document Engine](https://www.superdoc.dev/changelog/2026-03-22-document-engine)
- [Zed ACP Documentation](https://zed.dev/acp)
- [Zed Claude Code ACP Blog](https://zed.dev/blog/claude-code-via-acp)
- [OpenCode ACP Support](https://opencode.ai/docs/acp/)

### MCP Servers
- [Microsoft MarkItDown](https://github.com/microsoft/markitdown)
- [dvejsada/mcp-ms-office-documents](https://github.com/dvejsada/mcp-ms-office-documents)
- [GongRzhe/Office-Word-MCP-Server](https://github.com/GongRzhe/Office-Word-MCP-Server) (archived)
- [GongRzhe/Office-PowerPoint-MCP-Server](https://github.com/GongRzhe/Office-PowerPoint-MCP-Server)

### Zed
- [Zed Installation Docs](https://zed.dev/docs/installation)
- [Zed Windows Progress Report](https://zed.dev/blog/windows-progress-report)
- [Zed Webview Issue #21208](https://github.com/zed-industries/zed/issues/21208)
- [Zed File Association Issues #14137, #28827](https://github.com/zed-industries/zed/issues/14137) (closed)

### Claude / Office
- [Claude Code DOCX Issues #2213, #9631, #35911](https://github.com/anthropics/claude-code/issues/35911)
- [python-docx Tracked Changes Issue #340](https://github.com/python-openxml/python-docx/issues/340)
- [Microsoft Copilot Q1 2026](https://techcommunity.microsoft.com/blog/microsoft365copilotblog/what%E2%80%99s-new-in-microsoft-365-copilot--january-2026/4488916)
- [How AI Edits Word Documents (vesence.com)](https://www.vesence.com/blog/ai-edit-word-documents)

### Comparisons
- [Zed vs VSCode 2026](https://markaicode.com/vs/zed-editor-vs-vs-code/)
- [Pandoc roundtrip (vxlabs)](https://vxlabs.com/2024/02/11/pandoc-roundtrip-from-markdown-to-docx-and-back/)
