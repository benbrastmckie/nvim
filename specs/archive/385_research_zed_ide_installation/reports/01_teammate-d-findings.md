# Research Report: Task #385 — Teammate D (Horizons)

**Task**: 385 - Research Zed IDE installation plan for partner's laptop
**Role**: Horizons Researcher — long-term strategic direction and unconventional approaches
**Started**: 2026-04-09T00:00:00Z
**Completed**: 2026-04-09T01:00:00Z
**Effort**: ~1 hour
**Sources/Inputs**: Codebase (filetypes extension), zed.dev, ACP docs, builder.io, vesence.com, superdoc.dev, braw.dev, techcommunity.microsoft.com
**Artifacts**: This report

---

## Executive Summary

- The existing filetypes extension already has the right architecture to become a comprehensive document layer; it needs MCP integration upgrades (SuperDoc, Office-Word-MCP) rather than a rewrite
- Zed's ACP protocol is a genuine paradigm shift: both Claude Code and OpenCode already run inside Zed; the `.claude/` system is portable across any ACP-compatible editor today
- Microsoft Copilot is becoming an "AI layer inside Office" (2026 Q1 agent mode); Claude's advantage is programmatic batch operations and cross-tool pipelines, not in-app editing
- The highest-leverage unconventional approach is a **two-tier workflow**: Claude Cowork for visual document work + Claude Code (via Zed/ACP) for batch/programmatic operations, with SuperDoc's MCP server as the bridge
- Round-trip DOCX editing via markdown is fundamentally lossy; SuperDoc's deterministic operation layer (180+ MCP tools) solves this correctly and runs locally

---

## 1. Strategic Vision: Filetypes Extension Evolution

### Current State

The filetypes extension (v2.1.0) is already a well-structured document manipulation layer with:
- Four specialized agents: filetypes-router-agent, document-agent, spreadsheet-agent, presentation-agent, scrape-agent
- Commands: `/convert`, `/table`, `/slides`, `/scrape`
- MCP integration documentation already exists at `context/project/filetypes/tools/mcp-integration.md`
- Current backend: markitdown (broken per task 384), pymupdf (working)

### The Round-Trip Problem

The vesence.com analysis crystallizes why naive approaches fail: Word documents are "compressed archives of XML files that encode styles, numbering, tables, margins, headers, footers, and thousands of formatting properties." Converting to markdown and back destroys this structure. The three flawed patterns are:
1. Markdown conversion (loses styles, page breaks, tracked changes)
2. python-docx/standard MCP servers (only partial OOXML spec coverage)
3. Direct XML editing (brittle at real document length)

### What "Document-Aware" Claude Code Should Look Like

The correct evolution is **SuperDoc's Document Engine** pattern: convert editing from a "generation problem" into a "tool-use problem." Instead of asking Claude to generate OOXML, provide it with 180+ atomic tools (find/replace with formatting preservation, tracked changes, comments, tables, sections) that operate deterministically on the `.docx` file. Claude decides *what* to change; the engine handles *how*.

Concretely, the filetypes extension should evolve in three stages:

**Stage 1 (Near-term)**: Fix task 384's broken markitdown pipeline; switch primary backend to pymupdf. This is already planned.

**Stage 2 (Medium-term)**: Add a `docx-mcp` skill to the filetypes extension that configures SuperDoc's MCP server (or the Office-Word-MCP-Server) as a local service. The document-agent would use MCP tools rather than shell commands for DOCX operations. This preserves all formatting and supports tracked changes natively.

**Stage 3 (Long-term)**: A "document-proxy" agent that bridges between Office's native formats and Claude Code's text-editing mental model. The agent would:
1. Accept a `.docx` file
2. Extract structure via MCP tools into a navigable "document outline" resource
3. Let Claude reason about changes at a semantic level (paragraph, heading, table cell)
4. Apply changes atomically via MCP, never touching raw XML

**Visual Diff Previews**: The extension architecture already supports subprocess execution. A future `document-diff` command could use pandoc or SuperDoc's comparison output to render a tracked-changes `.docx` that Word/LibreOffice can display visually — closer to a real document review workflow.

### Fit with .claude/ Extension Architecture

The filetypes extension's language-null design (no language routing restriction) is correct for a document layer. The natural extension point is adding a new `skill-docx-mcp` that wraps SuperDoc, alongside the existing `skill-filetypes`. The index-entries.json would gain entries for the new skill's context. This fits cleanly without disrupting other extensions.

---

## 2. Zed as a Platform Play

### Trajectory Assessment: Cautious Optimism, Not Dominance

Zed ($42M raised through Series B, Nov 2024) has grown significantly in 2026 among performance-conscious developers. Key data points:
- **ACP is real and open**: Apache-licensed protocol, 30+ agents now support it, adopted by JetBrains (2025.3+), Neovim plugins, Emacs, Obsidian, marimo
- **Windows support arrived**: Previously the main adoption barrier
- **VS Code gravity remains brutal**: Extension ecosystem is the primary moat; niche workflows still favor VSCode

The builder.io analysis cautions "worth monitoring but perhaps not an immediate wholesale commitment." A developer reallocating from $100/month Claude Code to $10 Zed + $90 OpenRouter credits (braw.dev) illustrates that Zed's value proposition is real but currently most compelling for model-flexibility seekers, not ecosystem completeness seekers.

**Verdict**: Zed is unlikely to become the dominant editor in 3 years but is strongly positioned as the premier AI-native performance editor. The risk of deep Zed-specific investment is low because of ACP portability.

### ACP Changes Everything: The .claude/ System is Already Portable

This is the single most important strategic finding. ACP functions like "LSP but for AI agents." From the official documentation:

- Claude Code runs in Zed via an adapter that translates Claude Code SDK interactions into ACP's JSON-RPC format
- OpenCode "works the same via ACP as it does in the terminal"
- Zed "automatically discovers CLAUDE.md configuration files in projects"

This means the user's sophisticated `.claude/` agent system — all skills, agents, commands, and extensions — works in Zed **today** without modification. The system is editor-agnostic by design (it runs in Claude Code's process, not the editor's). Zed just becomes a faster, more AI-native UI layer on top of the same infrastructure.

**Recommendation**: Invest in the `.claude/` system itself (which the user is already doing), not in Zed-specific integrations. ACP ensures this investment pays off regardless of which editor wins.

### Could This .claude/ System Work Across Zed and VSCode via ACP?

Yes, explicitly. VSCode supports Claude Code via the Claude Code extension. JetBrains now supports ACP. The `.claude/` system's portability is its core architectural advantage — it isn't coupled to any editor. The user can run the same agent workflows from Zed, VSCode, JetBrains, or the terminal without changes.

---

## 3. Microsoft Office + AI: The 2026 Landscape

### Microsoft Copilot's 2026 Direction

Copilot is evolving from "chat assistant" to "AI layer inside Office applications" with agent-mode iteration in Word, Excel, and PowerPoint. Key 2026 Q1 features:
- **Copilot Cowork**: Delegates work by grounding on emails, meetings, files, and SharePoint lists; "takes action, not just chat"
- **Agent mode in Word/Excel/PowerPoint**: Iterative refinement across multiple prompts, not one-shot generation
- **Enterprise grounding**: SharePoint and organizational data accessible via "/" in Copilot Chat

### Claude's Comparative Advantage

Claude's native file editing (DOCX, XLSX, PPTX, PDF) launched in late 2025. Claude Cowork (January 12, 2026, research preview) is the "desktop version of Claude's agentic capabilities, built for knowledge workers." Key differentiators:
- **Cross-application reach**: Copilot is locked to Microsoft 365; Claude Cowork reaches any application on the desktop
- **Batch operations**: Recognizes patterns, renames batches, applies workflows to folders
- **Programmatic pipelines**: Anthropic's official claude-office-skills (April 1, 2026) provides DOCX/XLSX/PPTX skills usable from Claude Code directly

### Is There an Opportunity to Beat Microsoft's Native AI?

Yes, but not by competing on in-document editing fidelity. Microsoft wins there by definition (native integration). The opportunity is in **cross-tool pipelines**:
- Batch operations across 50+ Office files (Copilot operates on one file at a time)
- Converting Office files into formats for specialized tools (LaTeX tables, Beamer slides) — exactly what the filetypes extension already does
- Integrating Office content into non-Microsoft workflows (academic writing, code documentation, research pipelines)

### Claude Desktop + Office Add-ins Ecosystem

Claude Cowork can interact with Office applications visually via desktop control. The claude-office-skills GitHub project (tfriedel) provides PPTX/DOCX/XLSX/PDF skills with automation support, usable from Claude Code. A GitHub issue (Jan 19, 2026, #19310) requested native XLSX/DOCX tools in Claude Code directly, acknowledging current workflows require generating Python/PowerShell scripts (+30-60s per operation).

---

## 4. Creative/Unconventional Approaches

### Approach A: SuperDoc MCP + filetypes Extension (Highest Confidence)

SuperDoc's Document Engine MCP server is the closest to production-ready solution for the "document proxy" pattern. It runs locally, never sends documents to external servers, and provides 180+ deterministic tools. Integration path:

1. Install SuperDoc MCP server locally (Node.js)
2. Add `mcp-superdoc` to `.claude/extensions/filetypes/context/project/filetypes/tools/mcp-integration.md`
3. Create `skill-docx-mcp` that initializes the server and delegates DOCX operations to it
4. Update document-agent to use MCP tools when SuperDoc is available, fall back to pandoc/pymupdf

This converts DOCX editing from "generate Python script → run script → hope it worked" to "call find-replace tool with formatting preservation → done."

### Approach B: Two-Tier Division of Labor

Explicitly separate visual and programmatic Office workflows:
- **Claude Cowork (Visual tier)**: Interactive document editing, tracked changes, formatting work, review cycles. Used when the partner needs to work with Office files visually.
- **Claude Code via Zed/ACP (Programmatic tier)**: Batch operations, format conversion, table extraction, slide export. Used for pipeline work.

This isn't a workaround — it's an architecturally clean separation that plays to each tool's strengths. Copilot does the same thing (Excel's agent mode for one-off edits; Power Automate for batch).

### Approach C: Custom Zed Extension for Office Preview

Technically feasible: Zed extensions are written in Rust compiled to WASM. The `process::exec` capability allows spawning external processes. A Zed extension could:
1. Detect `.docx`/`.xlsx`/`.pptx` files when opened
2. Shell out to LibreOffice's `--headless --convert-to html` command
3. Display the HTML in a Zed markdown preview panel

**Confidence**: Medium-low. This requires significant Rust development and LibreOffice dependency. Maintenance burden is high. The payoff is low since Claude Cowork provides better visual editing anyway. Not recommended as a near-term investment.

### Approach D: MCP Server as Document Navigator

An MCP server that exposes Office document structure as navigable resources (chapters, sections, slides, sheets) to Claude Code — not just text content but the document's semantic outline. Claude could then:
- Ask "what are the section headings in this document?"
- Navigate to specific content without reading entire file
- Apply targeted edits at section/paragraph/cell level

SuperDoc's MCP already provides most of this (180+ tools include content reading and search). The main gap is a "document resource" abstraction that Claude Code can browse like a filesystem. This is worth implementing as a thin wrapper around SuperDoc.

---

## Recommended Approach (Strategic Path)

### Immediate (Next 2 Weeks)
1. Complete task 384: fix the convert pipeline with pymupdf as primary backend
2. Install SuperDoc MCP server and validate it works with the existing document-agent
3. Add SuperDoc to `mcp-integration.md` in the filetypes extension context

### Near-term (1-2 Months)
4. Create `skill-docx-mcp` that uses SuperDoc's deterministic operations for DOCX editing
5. Update document-agent to prefer MCP tools over shell-command generation for DOCX
6. Install Zed on partner's laptop; configure Claude Code via ACP (the `.claude/` system works as-is)

### Long-term (3-6 Months)
7. Implement the two-tier workflow: Claude Cowork for visual, Claude Code/Zed for programmatic
8. Build a "document-proxy" agent that wraps SuperDoc's MCP into the filetypes routing architecture
9. Consider SuperDoc-powered document navigation resources for Claude Code

### What NOT to Do
- Do not build Zed-specific integrations (ACP makes them unnecessary)
- Do not invest in the markdown round-trip pattern for DOCX editing (architecturally lossy)
- Do not try to compete with Copilot on in-document editing (wrong battleground)
- Do not build a custom Zed Office preview extension (high cost, low value vs Cowork)

---

## Evidence and Examples

**ACP portability confirmed**: Zed documentation states Claude Agent "automatically discovers CLAUDE.md configuration files in projects" — the user's `.claude/` system is already Zed-compatible.

**SuperDoc's scale**: 180+ MCP tools covering content reading, search, editing, formatting, tables, lists, sections, comments, tracked changes. Local execution, no cloud dependency.

**Round-trip failure documented**: "When you convert a .docx to markdown or plain text and back, all of that structure gets nuked" (SuperDoc changelog, March 2026). python-docx "only covers a fraction of the OOXML spec."

**Microsoft's direction**: Copilot Cowork grounding on SharePoint + agent mode in Word/Excel is a 2026 Q1 release. Microsoft is betting on deep integration, not portability.

**Community validation**: GitHub issue #19310 (Claude Code, Jan 19 2026) explicitly requests native DOCX/XLSX tools because current script-generation workflow adds 30-60s per operation.

---

## Confidence Levels

| Finding | Confidence |
|---------|------------|
| ACP portability: .claude/ system works in Zed today | High |
| SuperDoc MCP solves the DOCX round-trip problem | High |
| Two-tier workflow (Cowork + Claude Code) is optimal division | High |
| Round-trip markdown editing is lossy and should be avoided | High |
| Zed will not become dominant editor in 3 years | Medium |
| Custom Zed Office preview extension is high-cost low-value | Medium |
| Microsoft Copilot wins on in-document editing fidelity | High |
| Claude's advantage is cross-tool batch pipelines | High |

---

## Context Extension Recommendations

- **Topic**: SuperDoc Document Engine MCP integration
- **Gap**: The filetypes extension's `mcp-integration.md` documents markitdown-mcp and mcp-pandoc but not SuperDoc, which is the correct solution for faithful DOCX editing
- **Recommendation**: Add SuperDoc to `context/project/filetypes/tools/mcp-integration.md` as the preferred tool for DOCX editing operations; document its 180+ tool API surface

- **Topic**: ACP (Agent Client Protocol) portability documentation
- **Gap**: No existing context documents that the `.claude/` system works across editors via ACP
- **Recommendation**: Add a note to `.claude/context/repo/project-overview.md` or create `.claude/context/patterns/editor-portability.md` documenting that ACP enables the agent system to run in Zed, JetBrains, and other editors without modification

---

## Appendix: Sources

- [Zed ACP Documentation](https://zed.dev/acp)
- [Zed External Agents Documentation](https://zed.dev/docs/ai/external-agents)
- [Zed: Is It Ready for AI Power Users in 2026?](https://www.builder.io/blog/zed-ai-2026)
- [Claude Code Beta in Zed via ACP](https://zed.dev/blog/claude-code-via-acp)
- [OpenCode ACP Support](https://opencode.ai/docs/acp/)
- [SuperDoc Document Engine Changelog (March 2026)](https://www.superdoc.dev/changelog/2026-03-22-document-engine)
- [How AI Edits Word Documents Without Breaking Formatting](https://www.vesence.com/blog/ai-edit-word-documents)
- [What's New in Microsoft 365 Copilot Q1 2026](https://techcommunity.microsoft.com/blog/microsoft365copilotblog/what%E2%80%99s-new-in-microsoft-365-copilot--january-2026/4488916)
- [Copilot Cowork Announcement](https://www.microsoft.com/en-us/microsoft-365/blog/2026/03/09/copilot-cowork-a-new-way-of-getting-work-done/)
- [Claude Office Skills (GitHub)](https://github.com/tfriedel/claude-office-skills)
- [Office Word MCP Server (GitHub)](https://github.com/GongRzhe/Office-Word-MCP-Server)
- [Reallocating from Claude Code to Zed + OpenRouter](https://braw.dev/blog/2026-04-06-reallocating-100-month-claude-spend/)
- [ACP Agent Registry in JetBrains](https://blog.jetbrains.com/ai/2026/01/acp-agent-registry/)
- [Claude Cowork Guide](https://o-mega.ai/articles/claude-cowork-the-ultimate-autonomous-desktop-guide-2026)
