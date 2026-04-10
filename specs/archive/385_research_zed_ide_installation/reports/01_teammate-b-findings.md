# Research Report: Task #385 - Teammate B Findings

**Task**: 385 - Research Zed IDE installation plan for partner's laptop
**Angle**: Alternative Patterns and Prior Art for Office Document Workflows
**Started**: 2026-04-09T00:00:00Z
**Completed**: 2026-04-09T01:00:00Z
**Effort**: ~1 hour
**Sources**: WebSearch, WebFetch (GitHub, Zed docs, MCP registries, library docs)

---

## Executive Summary

- A rich ecosystem of MCP servers already exists for Office document manipulation (docx, xlsx, pptx), meaning Claude Code can interact with Office files today without any Zed-specific support
- Microsoft's own MarkItDown tool + MCP server provides the cleanest conversion path (20+ formats → Markdown), and pandoc handles the reverse (Markdown → docx) with acceptable fidelity
- Zed has **zero** native support for Office files and **no path to add it**: webview support (the only mechanism that could render Office previews) is explicitly unimplemented and has known blockers on Linux/Wayland
- VSCode Office extensions (Office Viewer, Syncfusion Document Viewer, Excel Viewer) cannot be ported to Zed — they rely on webview APIs Zed does not expose
- The practical pattern for a non-developer partner: use Zed + Claude Code for text/code tasks, use LibreOffice (or MS Office) as the companion app for Office files, with MCP-based conversion as the bridge
- Zed's performance advantage over VSCode is substantial (5x less RAM, 10x faster startup) but irrelevant if Office file handling is a core workflow requirement

---

## Key Findings

### 1. MCP Servers for Office Document Manipulation

Multiple MCP servers exist today that Claude Code can use directly, regardless of which editor is open:

| Server | Formats | Status | Notes |
|--------|---------|--------|-------|
| `GongRzhe/Office-Word-MCP-Server` | DOCX | Archived March 2026 | Full read/write, but abandoned |
| `dvejsada/mcp-ms-office-documents` | DOCX, XLSX, PPTX, EML | Active | Docker-based, template-driven |
| `GongRzhe/Office-PowerPoint-MCP-Server` | PPTX | Active | python-pptx based |
| `jenstangen1/pptx-xlsx-mcp` | PPTX, XLSX | Active | Minimal, focused |
| `microsoft/markitdown` (MCP) | 20+ formats incl. DOCX/XLSX/PPTX | Active | **Read-only**: converts to Markdown |
| Arcade Office 365 MCP | Full Office 365 suite | Active | Enterprise, 30+ tools |

**Critical distinction**: Most MCP servers for Office are **generation/creation** tools. For editing existing documents, the options narrow significantly. The MarkItDown MCP converts TO markdown (read direction), while dvejsada's server creates FROM markdown (write direction). A complete read-edit-write workflow requires combining tools.

**Confidence**: High — verified from GitHub repos and MCP registries.

### 2. The Pandoc / MarkItDown Roundtrip Pipeline

The most viable "edit Office files with Claude Code" pattern that already exists:

```
[existing .docx]
  → markitdown or pandoc → [.md file]
    → Claude Code edits markdown
      → pandoc → [new .docx]
```

**What pandoc preserves** (per vxlabs roundtrip experiment):
- Headings, paragraphs, lists, tables
- Code blocks with language labels (via Lua filters)
- LaTeX math, images (verified by md5sum)
- Basic document structure

**What pandoc loses**:
- Complex formatting (text boxes, columns, SmartArt)
- Track changes / comments (partially preserved)
- Exact font metrics and spacing
- Embedded macros or VBA

**Mammoth** (`python-mammoth`) is an alternative to pandoc for DOCX→HTML→Markdown, but its markdown output mode is deprecated; the recommended path is DOCX→HTML→markdown via markdownify.

**Microsoft's MarkItDown** (open source, pip installable, MCP server available) handles the docx→markdown direction cleanly and is actively maintained by Microsoft. This is superior to mammoth for the read direction.

**Practical verdict**: The pandoc roundtrip is suitable for documents that are primarily prose with simple formatting (reports, proposals, READMEs converted to docx). It is **not suitable** for complex formatted documents, spreadsheets with formulas, or presentations with custom layouts.

**Confidence**: High — tested approach with documented limitations.

### 3. VSCode Office Extensions — What Zed Cannot Match

VSCode extensions for Office files that exist and have **no Zed equivalent**:

| VSCode Extension | Capability | Zed Equivalent |
|-----------------|-----------|----------------|
| `cweijan.vscode-office` (Office Viewer) | In-editor preview + WYSIWYG for docx, xlsx | None (requires webview) |
| `GrapeCity.gc-excelviewer` (Excel Viewer) | View/edit XLSX with formatting preserved | None |
| `Muhammad-Ahmad.xlsx-viewer` | XLSX, CSV, TSV editor | None |
| `SyncfusionInc.Document-Viewer-VSCode-Extensions` | PDF, Word, Excel view+edit | None |
| `ShahilKumar.docxreader` (Docx/ODT Viewer) | DOCX/ODT rendering | None |

**Root cause**: All these extensions use VSCode's webview API to render an HTML/web-based document viewer inside the editor panel. Zed does not implement webview support, and the open GitHub issue (#21208) confirms:
- Webview support is not planned in the near term
- A proof-of-concept exists but has two blocking problems: rendering priority issues and Linux/Wayland incompatibility
- No timeline for resolution

**Conclusion**: Any VSCode extension that renders Office documents is **categorically impossible** to port to Zed with the current extension model.

**Confidence**: High — confirmed via Zed GitHub issues and extension architecture review.

### 4. Zed's Extension Model Limitations

Zed extensions are written in WebAssembly (WASM) and are deliberately sandboxed. Current extension capabilities:
- Language support (syntax highlighting, LSP integration)
- Themes
- Snippets
- Slash commands
- Basic context providers

Extensions **cannot**:
- Render custom document views (no webview)
- Access the file system arbitrarily
- Launch subprocesses
- Register custom editor tabs for binary formats

This is a fundamental architectural difference from VSCode's Node.js-based extension host.

**Confidence**: High — verified from official Zed extension documentation.

### 5. LibreOffice CLI as Programmatic Companion

LibreOffice provides robust headless/batch capabilities that Claude Code can invoke via shell commands:

```bash
# Convert docx to PDF
libreoffice --headless --convert-to pdf document.docx

# Convert docx to html (for text extraction)
libreoffice --headless --convert-to html document.docx

# Run a macro headlessly
soffice --headless --nofirststartwizard \
  "macro:///Standard.Module1.EditDocument()"
```

**Supported conversions**: docx, odt, pdf, html, txt, epub, and more.

**Macro automation**: LibreOffice Basic or Python (via UNO API) can programmatically edit documents, though the setup is complex and brittle.

**Practical use**: Claude Code can call LibreOffice CLI to convert formats for processing, but direct editing via macros is not user-friendly enough for a non-developer.

**Confidence**: Medium — LibreOffice CLI is well-documented but macro execution in headless mode has known quirks.

### 6. OnlyOffice Document Builder API

OnlyOffice provides a standalone Document Builder tool (not a full office suite) for programmatic document generation:
- JavaScript-based API
- Runs from command line as `.js` scripts
- Generates DOCX, XLSX, PPTX
- Python SDK available
- Active development (v9.2 in 2025 expanded API significantly)

This is a **generation** tool, not an editing tool for existing documents. Useful for creating new documents from templates, not for modifying existing partner files.

**Confidence**: Medium — suitable for structured document generation workflows.

### 7. Zed Installation Methods by OS

| OS | Method | Command |
|----|--------|---------|
| macOS | Homebrew (recommended) | `brew install --cask zed` |
| macOS | Direct download | https://zed.dev/download |
| Windows | WinGet | `winget install -e --id ZedIndustries.Zed` |
| Windows | Direct download | https://zed.dev/download |
| Linux | Install script (recommended) | `curl -f https://zed.dev/install.sh \| sh` |
| Linux | Flatpak (community-maintained) | via Flathub (not officially supported) |

**System Requirements**:
- macOS 11+
- Windows 1903+ (64-bit)
- Linux: Vulkan 1.3 driver required (important for older hardware)

**Linux Flatpak caveat**: The Flatpak package is community-maintained and not supported by Zed Industries. The install script is the recommended approach. For Ubuntu/Debian-based systems, Vulkan support is typically included but worth verifying on older laptops.

**Confidence**: High — from official Zed installation documentation.

### 8. Zed Performance vs VSCode

| Metric | Zed | VSCode | Source |
|--------|-----|--------|--------|
| RAM (typical project) | ~142-200 MB | ~730 MB - 1.2 GB | Multiple 2025/2026 benchmarks |
| Cold startup | 0.12s | 1.2s | Markaicode 2025 |
| Power usage | ~471 units | ~1217 units (2.58x more) | Power profiling study |
| Input latency | <10ms | 15-25ms | Markaicode 2025 |

**Why this matters for a non-developer partner's laptop**: If the laptop has limited RAM (8GB or less), VSCode's memory footprint can cause noticeable slowdowns, especially with Office apps running simultaneously. Zed's footprint is dramatically smaller.

**Confidence**: High — benchmarks from multiple independent sources.

### 9. Zed + Claude Code Integration (ACP)

Claude Code is available as a **native integration in Zed** via the Agent Client Protocol (ACP), in public beta as of early 2026:
- Runs Claude Code inside Zed's interface (no separate terminal)
- Multi-file diff view with accept/reject per change
- Task list visible in sidebar
- Custom slash commands work
- MCP servers connected to Claude Code are available within Zed

**Gaps in the beta**:
- Some built-in slash commands lack SDK support
- Plan mode was added after initial beta
- Not all Claude Code workflows are fully polished yet

**Conclusion for this task**: A non-developer can use Claude Code from within Zed without needing to know terminal commands — the ACP integration provides a GUI for Claude Code operations.

**Confidence**: High — verified from official Zed blog post and documentation.

### 10. Other AI Editors and Office Files

Cursor, Windsurf, and Cody are all **VSCode-based** AI editors that inherit VSCode's extension ecosystem. This means:
- They can use vscode-office, Excel Viewer, and other Office extensions
- They have the same webview-based rendering capability
- A non-developer using Cursor gets Office file preview "for free"

However, these tools are significantly heavier than Zed and primarily designed for developers. They are not recommended as "lightweight" options for a non-developer partner.

**Confidence**: Medium — confirmed from general comparison research.

---

## Recommended Approach

### For Office File Workflows: MCP-Assisted Roundtrip Pattern

The cleanest approach that works today without waiting for Zed features:

**Setup**:
1. Install `markitdown-mcp` (Microsoft): `pip install markitdown-mcp`
2. Configure in Claude Code's MCP settings
3. Install pandoc for markdown→docx conversion
4. Keep LibreOffice installed as viewer/companion app

**Workflow for editing an existing docx**:
1. Partner opens Claude Code (or Zed with Claude Code ACP)
2. Partner says: "Edit my report.docx to add a conclusion section"
3. Claude Code calls markitdown MCP to convert docx → markdown
4. Claude Code edits the markdown
5. Claude Code calls pandoc to regenerate the docx
6. Partner opens result in LibreOffice to verify/tweak formatting

**Workflow for creating new Office documents**:
1. Partner describes the document to Claude Code
2. Claude Code creates markdown content
3. Claude Code calls pandoc to generate docx
4. Partner opens in LibreOffice or MS Office for final review

**What the partner still needs LibreOffice (or MS Office) for**:
- Documents with complex formatting (tables, images, columns)
- Spreadsheets with formulas and charts
- Presentations with custom layouts
- Final visual review before sending

### For Installation (Linux Laptop)

```bash
# Install Zed
curl -f https://zed.dev/install.sh | sh

# Install pandoc
sudo apt install pandoc  # or equivalent

# Install LibreOffice (if not present)
sudo apt install libreoffice

# Install markitdown MCP
pip install markitdown-mcp

# Install python-docx for direct manipulation
pip install python-docx
```

**Verify Vulkan support first**:
```bash
vulkaninfo 2>/dev/null | head -5  # or: glxinfo | grep OpenGL
```

### For Installation (macOS)

```bash
brew install --cask zed
brew install pandoc
brew install --cask libreoffice
pip install markitdown-mcp
```

### For Installation (Windows)

```powershell
winget install -e --id ZedIndustries.Zed
winget install JohnMacFarlane.Pandoc
# Download LibreOffice from libreoffice.org
pip install markitdown-mcp
```

---

## Evidence / Examples

### MCP Server Landscape Evidence

- **dvejsada/mcp-ms-office-documents**: Docker-based server creating DOCX/XLSX/PPTX from markdown. Templates with placeholders become AI tools. Active development.
- **microsoft/markitdown**: Official Microsoft tool. MCP server added April 2025. Converts 20+ formats → Markdown. `pip install markitdown-mcp`.
- **GongRzhe/Office-Word-MCP-Server**: Full-featured Word editing via MCP. Archived March 2026 (no more development), but functional.

### Pandoc Roundtrip Evidence

The vxlabs.com article documents a working pandoc roundtrip with:
- Lua filter to preserve code block language labels
- Image preservation verified by md5sum
- LaTeX math preserved
- Author conclusion: "pretty happy with how close the roundtripped markdown is to the original"

### Zed Webview Blocker Evidence

From GitHub issue #21208 on zed-industries/zed:
- Status: "Fresh Unscoped Features" (not in active development)
- Known blocker: Wry library cannot function as child window on Linux/Wayland
- Known blocker: Webviews render above GPUI elements, breaking UI
- No timeline for resolution provided

---

## Confidence Assessment

| Finding | Confidence | Reasoning |
|---------|-----------|-----------|
| MCP servers for Office exist | High | Verified 5+ repos on GitHub/MCP registries |
| Pandoc roundtrip viability | High | Documented experiment with specific results |
| Zed cannot display Office files | High | Confirmed via GitHub issues + architecture |
| VSCode extensions won't port to Zed | High | Extension model incompatibility confirmed |
| LibreOffice CLI capabilities | Medium | Documented but headless macro execution is finicky |
| Performance comparison numbers | High | Multiple independent benchmark sources |
| Zed installation steps | High | From official Zed documentation |
| OnlyOffice Document Builder | Medium | Good for generation, not tested for complex edits |
| ACP/Claude Code in Zed beta | High | Official Zed blog post + documentation |

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Pandoc roundtrip destroys complex formatting | High | High | Limit use to prose-heavy documents; keep originals |
| Vulkan not available on partner's Linux laptop | Medium | High | Check hardware before recommending Zed on Linux |
| markitdown-mcp requires Python setup | Low | Medium | Use pipx for isolated install |
| Partner finds Zed too unfamiliar | Medium | High | Offer VSCode as fallback with Office extensions intact |
| MCP server for Office needs Docker | Medium | Medium | dvejsada server requires Docker; markitdown does not |

---

## Gaps Not Covered (For Teammate A's Complement)

This research did NOT cover:
- The claude-office-skills project specifically (Teammate A's focus)
- Zed's built-in AI features (Zed AI, not Claude Code ACP)
- OpenCode and Codex specific integration details
- Detailed Zed configuration for a non-developer (vim mode, keymap, etc.)

---

## Context Extension Recommendations

- **Topic**: MCP servers for Office document manipulation
- **Gap**: No existing context documents the MCP server landscape for Office files
- **Recommendation**: Create `.claude/context/tools/office-mcp-servers.md` with a curated list of viable MCP servers and their capabilities/limitations

- **Topic**: Pandoc as a Claude Code workflow tool
- **Gap**: Pandoc's role as a document conversion bridge for AI editing workflows is undocumented
- **Recommendation**: Add pandoc patterns to any document workflow context files

---

## Appendix: Search Queries Used

1. `MCP server Office documents docx xlsx pptx manipulation 2025 2026`
2. `pandoc docx markdown roundtrip workflow Claude Code editing 2025`
3. `VSCode extensions Office files docx xlsx viewer editor 2025`
4. `Zed editor extensions Office documents docx xlsx 2025 2026`
5. `LibreOffice command line headless macro batch document editing automation`
6. `Zed editor vs VSCode RAM CPU performance comparison 2025`
7. `Zed editor installation Linux Windows package manager flatpak winget 2025`
8. `Cursor Windsurf Cody AI editor Office files docx workflow non-developer`
9. `OnlyOffice Document Builder API programmatic document creation editing 2025`
10. `Zed editor non-developer workflow companion app Office documents 2025 2026`
11. `python-docx mammoth docx markdown conversion programmatic editing script`
12. `microsoft markitdown docx xlsx conversion tool Claude MCP 2025`
13. `Zed extension model limitations vs VSCode webview binary file extensions impossible 2025`
14. `Claude Code OpenCode AI coding assistant Office document editing workflow integration 2025`
15. `Zed editor Claude Code integration MCP tools 2025 2026`
16. `"Zed editor" "minimal config" non-technical user setup guide 2025`

## References

- [Office-Word-MCP-Server (GongRzhe)](https://github.com/GongRzhe/Office-Word-MCP-Server)
- [mcp-ms-office-documents (dvejsada)](https://github.com/dvejsada/mcp-ms-office-documents)
- [Microsoft MarkItDown](https://github.com/microsoft/markitdown)
- [pptx-xlsx-mcp (jenstangen1)](https://github.com/jenstangen1/pptx-xlsx-mcp)
- [pandoc roundtrip article (vxlabs)](https://vxlabs.com/2024/02/11/pandoc-roundtrip-from-markdown-to-docx-and-back/)
- [Zed Webview Issue #21208](https://github.com/zed-industries/zed/issues/21208)
- [Zed Installation Docs](https://zed.dev/docs/installation)
- [Zed Claude Code ACP Blog](https://zed.dev/blog/claude-code-via-acp)
- [Zed vs VSCode Performance (markaicode)](https://markaicode.com/vs/zed-editor-vs-vs-code/)
- [Office Viewer VSCode Extension](https://marketplace.visualstudio.com/items?itemName=cweijan.vscode-office)
- [LibreOffice Command Line Guide](https://opensource.com/article/21/3/libreoffice-command-line)
- [OnlyOffice Document Builder API](https://api.onlyoffice.com/docs/document-builder/get-started/overview/)
- [Arcade Office 365 MCP Servers](https://www.arcade.dev/blog/microsoft-office-365-mcp-servers-launch)
