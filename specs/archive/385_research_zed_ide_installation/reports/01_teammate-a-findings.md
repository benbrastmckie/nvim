# Research Report: Task #385 — Teammate A Findings

**Task**: 385 - Research Zed IDE installation plan for partner's laptop
**Teammate**: A (Primary Implementation Approaches)
**Started**: 2026-04-09T00:00:00Z
**Completed**: 2026-04-09T01:00:00Z
**Effort**: ~2 hours
**Angle**: claude-office-skills project analysis, precise Word editing, Zed + Claude.ai workflow

---

## Key Findings

### 1. claude-office-skills Project (github.com/tfriedel/claude-office-skills)

**What it is**: A community-published set of Claude Code skills (SKILL.md files + scripts) that power
DOCX, PPTX, XLSX, and PDF workflows. These skills were later officially adopted by Anthropic into
their own `github.com/anthropics/skills` repository. The Anthropic version is the authoritative
upstream; tfriedel's version is the community precursor.

**Project structure**:
```
public/
  docx/
    SKILL.md        # Primary workflow doc (must read completely before starting)
    ooxml.md        # ~600-line XML editing reference
    scripts/        # Python helpers: unpack.py, pack.py
  pptx/
    SKILL.md
    html2pptx.md
  xlsx/
    SKILL.md
  pdf/
    SKILL.md
```

**Python libraries used**:
- `python-docx` / Document library (OOXML manipulation)
- `python-pptx` (PPTX creation/extraction)
- `openpyxl` (XLSX via pandas integration)
- `defusedxml` + `lxml` (secure XML parsing)
- `pandoc` (text extraction to Markdown, primary read tool)
- `docx-js` / TypeScript (new document creation only)
- `Pillow`, `pdf2image` (image handling)
- `markitdown` (Office-to-Markdown conversion)

**Key architectural principle**: Two-phase OOXML editing — unpack ZIP → edit XML → validate → repack.
All scripts write to `outputs/<descriptive-name>/` to avoid polluting source directories.

**How skills are structured**: Each skill is a SKILL.md that Claude Code reads completely before
starting any work. The SKILL.md acts as an executable protocol: decision trees, tool selection
logic, validation requirements, and output conventions all live in the SKILL.md. This is directly
analogous to the existing filetypes extension's agent `.md` files.

**Relationship to existing filetypes extension**: The tfriedel/anthropics skills cover a gap that
the current filetypes extension does not: *editing* existing Word documents with precise, tracked
changes. The current `document-agent.md` only handles conversion (DOCX → Markdown, Markdown → PDF).
It does not support editing DOCX content in place with structure preservation.

---

### 2. Precise Editing of Word Documents (The "Line Numbers" Equivalent)

**Core insight**: Word documents have no line numbers. The OOXML structure is:
```
Document → Body → Paragraphs (<w:p>) → Runs (<w:r>) → Text (<w:t>)
```

**How to address specific locations**:

| Approach | How It Works | When to Use |
|---|---|---|
| Grep on `word/document.xml` | Search XML for unique surrounding text | Most reliable for existing text |
| Paragraph index (0-based) | `doc.paragraphs[N]` in python-docx | Simple appends/deletions |
| `target_paragraph_index` param | Used by Office-Word-MCP-Server | MCP-based workflows |
| Document structure landmarks | "Section 3.2", "signature block" | Professional/legal docs |
| Bookmarks / content controls | Named anchors in Word XML | Template-based editing |

**The SKILL.md workflow for precise edits**:
1. Convert to Markdown first (`pandoc`) to get a human-readable view of structure
2. `unzip -o file.docx -d unpacked_dir` — extract the ZIP
3. `grep -n "target text" unpacked_dir/word/document.xml` — find exact XML line numbers
4. Write a Python script targeting those elements via text matching (NOT line numbers — these shift after every edit)
5. Validate by re-converting to Markdown and diffing
6. Repack: `python scripts/pack.py unpacked_dir output.docx`

**CRITICAL warning from SKILL.md**: "DO NOT use markdown line numbers — they don't map to XML
structure." After each edit, XML line numbers change. The correct reference is **unique surrounding
text patterns** used as grep anchors.

**Tracked changes pattern** (for professional editing):
```xml
<!-- Deletion -->
<w:del w:id="1" w:author="Claude" w:date="2026-04-09">
  <w:r><w:delText>30 days</w:delText></w:r>
</w:del>
<!-- Insertion -->
<w:ins w:id="2" w:author="Claude" w:date="2026-04-09">
  <w:r><w:t>60 days</w:t></w:r>
</w:ins>
```

Placement rule: `<w:del>` and `<w:ins>` go at paragraph level, never nested inside `<w:r>`. Violating
this creates invalid XML that crashes Word.

**MCP option**: The `GongRzhe/Office-Word-MCP-Server` exposes `target_paragraph_index` as a direct
parameter, enabling Claude Code to address paragraphs by index without unpacking manually. This is
the cleanest interface for Claude Code to call.

**Alternative (Claude.ai Desktop)**: Claude.ai Desktop (not Claude Code) now natively creates and
edits DOCX, XLSX, PPTX files via an upload → describe changes → download cycle. This is suitable
for non-programmatic, one-off edits. Limitation: 30MB max file size; no tracked changes; no
repeatable scripted workflow.

---

### 3. Zed + Claude.ai/Desktop Workflow for Office Files

**ACP (Agent Client Protocol) — what it is**:
ACP is Zed's open standard for connecting any AI agent to any editor. As of early 2026, the ACP
Registry is live. Claude Code runs natively inside Zed via ACP — users can follow edits in real-time
in the multibuffer, accept/reject individual hunks, and see Claude Code's task list in the sidebar.

**Zed's file association limitation** (important for .docx workflow):
- Zed does NOT have built-in support for opening specific file types in external applications
- Two feature requests for this (Issues #14137 and #28827) were **both closed as "not planned"**
  as of February 2026
- There is no `file_associations` setting in Zed's settings.json

**Practical workaround via Zed Tasks**: Zed's task system (`.zed/tasks.json`) CAN invoke external
commands including `xdg-open`. This enables a keybinding-driven workflow:

```json
// .zed/tasks.json
[
  {
    "label": "Open in LibreOffice",
    "command": "xdg-open",
    "args": ["$ZED_FILE"],
    "reveal": "never",
    "hide": "always"
  },
  {
    "label": "Open in LibreOffice (explicit)",
    "command": "libreoffice",
    "args": ["$ZED_FILE"],
    "reveal": "never",
    "hide": "always"
  }
]
```

With a keybinding in `keymap.json`:
```json
{
  "context": "Workspace",
  "bindings": {
    "alt-o": ["task::Spawn", { "task_name": "Open in LibreOffice" }]
  }
}
```

This gives a workflow of: navigate to `.docx` in Zed file tree → press `alt-o` → LibreOffice opens
the file. Then use Claude Code in Zed's terminal for programmatic edits.

**Recommended Zed + Office workflow (2026)**:

```
1. Browse files in Zed's file tree (fast, native)
2. For VIEWING: press keybinding → xdg-open sends to LibreOffice/Word
3. For PROGRAMMATIC EDITING via Claude Code:
   a. Open Zed terminal (Claude Code running via ACP or terminal)
   b. Invoke /convert to extract to Markdown (read-only view)
   c. Use the docx skill workflow: unpack → grep → Python script → repack
   d. Validate with pandoc diff
4. For ONE-OFF EDITING: upload to Claude.ai Desktop, describe changes, download
```

**Claude.ai Desktop vs Claude Code for DOCX**:

| Use Case | Claude.ai Desktop | Claude Code + docx skill |
|---|---|---|
| Create new document | Excellent | Good (docx-js) |
| Read/understand content | Good (upload) | Good (pandoc extract) |
| Precise text replacement | Limited (no location control) | Strong (grep + Python) |
| Tracked changes | Not supported | Full support (OOXML) |
| Repeatable/scriptable | No | Yes |
| File size limit | 30MB | None |
| Integration with codebase | None | Full (same terminal) |

---

## Recommended Approach

### Improving the Filetypes Extension

The existing filetypes extension handles conversion well but is missing a key capability: **in-place
DOCX editing with structure preservation**. The recommended improvement is to add a `docx-edit`
skill and `docx-edit-agent` that implements the tfriedel/anthropics SKILL.md workflow:

**New capability**: `/edit document.docx "Change '30 days' to '60 days' in Section 3.2"`

**Implementation pattern** (adapted from claude-office-skills):
1. Add `docx-edit-agent.md` to `.claude/extensions/filetypes/agents/`
2. Add `skill-docx-edit/SKILL.md` to `.claude/extensions/filetypes/skills/`
3. Add context file: `context/project/filetypes/patterns/docx-editing.md`
4. Add `python-docx` and `defusedxml` to dependency-guide.md

**The new skill should expose these addressing modes**:
- Text-based grep (primary, most robust)
- Paragraph index (secondary, for appends/inserts)
- Structure landmarks (tertiary, for professional docs)

### Zed Configuration for Office Files

Add to partner's Zed setup:
1. `.zed/tasks.json` with `xdg-open` task for .docx/.xlsx/.pptx files
2. Keybinding `alt-o` to invoke it
3. Claude Code configured via ACP in Zed agent panel

### MCP Server Recommendation

For the most ergonomic Claude Code → DOCX editing, install:
- `GongRzhe/Office-Word-MCP-Server` (paragraph-index addressing via MCP tools)
- `markitdown-mcp` (already referenced in existing mcp-integration.md)

---

## Evidence / Examples

**Source: tfriedel/claude-office-skills SKILL.md (docx)**
> "DO NOT use markdown line numbers - they don't map to XML structure"
> "grep word/document.xml immediately before writing a script to get current line numbers and verify text content, as line numbers change after each script run"

**Source: Anthropic official skills repo (github.com/anthropics/skills)**
> Contains 17 top-level skill directories, 4 document skills (docx, pdf, pptx, xlsx) that power Claude.ai's document creation features

**Source: Zed GitHub Issues #14137, #28827**
> Both "open file in external app" feature requests closed as "not planned" (Feb 2026)
> Workaround: use Zed tasks with xdg-open

**Source: Claude Code Issue #9631 (open as of Feb 2026)**
> Native .docx support with track changes in Claude Code is still an open feature request
> Community solution: use the docx SKILL.md approach

**Source: Office-Word-MCP-Server (GongRzhe)**
> `target_paragraph_index` parameter enables direct 0-based paragraph addressing
> `insert_line_or_paragraph_near_text()` enables text-anchor addressing

---

## Confidence Levels

| Finding | Confidence | Basis |
|---|---|---|
| claude-office-skills project structure | High | Direct fetch of SKILL.md and CLAUDE.md |
| OOXML unpack/grep/repack workflow | High | Multiple confirming sources including official Anthropic skills |
| "No line numbers" — use grep anchors | High | Explicit warning in official SKILL.md |
| Zed has no native file-type external handler | High | Two closed GitHub issues + settings docs |
| Zed tasks can invoke xdg-open as workaround | High | Zed tasks documentation confirms $ZED_FILE variable |
| Claude Code ACP integration in Zed | High | Official Zed blog post confirming beta launch |
| Office-Word-MCP-Server paragraph_index | Medium | README review; needs hands-on validation |
| Claude.ai Desktop DOCX editing | High | Official Anthropic documentation |
| Tracked changes OOXML structure | High | Multiple sources + official SKILL.md |

---

## Context Extension Recommendations

- **Topic**: DOCX in-place editing with OOXML
- **Gap**: The existing `filetypes` extension has no context for editing DOCX files in place; it only handles conversion to/from Markdown
- **Recommendation**: Create `.claude/extensions/filetypes/context/project/filetypes/patterns/docx-editing.md` documenting the unpack-grep-edit-repack workflow and the paragraph addressing strategies

- **Topic**: Zed tasks for external file opening
- **Gap**: No context file documents the Zed tasks workaround for opening Office files in external apps
- **Recommendation**: This could live in a Zed-specific context file if a Zed extension is ever created, or in the project `.context/` layer

---

## Appendix: Search Queries Used

1. `tfriedel claude-office-skills GitHub python-docx python-pptx openpyxl Claude Code skills`
2. `python-docx paragraph run addressing precise location editing Word documents 2026`
3. `claude-office-skills DOCX SKILL.md structure tracked changes OOXML paragraph index`
4. `Zed editor ACP agent client protocol external file associations open with 2026`
5. `OOXML docx paragraph index precise editing python script location addressing 2026`
6. `Zed editor open docx files external application file type association xdg-open workflow 2026`
7. `Claude Desktop computer use edit Word DOCX file 2026 workflow best practice`
8. `document-edit-mcp MCP server Word docx precise editing paragraph location 2026`
9. `anthropic skills docx GitHub official skill OOXML paragraph addressing 2026`
10. `Zed tasks.json xdg-open open external app file type keybinding docx libreoffice 2025 2026`
11. `"filetypes extension" claude code docx word editing skill agent OOXML improvement 2026`

## References

- [tfriedel/claude-office-skills](https://github.com/tfriedel/claude-office-skills)
- [anthropics/skills (official)](https://github.com/anthropics/skills)
- [ComposioHQ/awesome-claude-skills DOCX SKILL.md](https://github.com/ComposioHQ/awesome-claude-skills/blob/master/document-skills/docx/SKILL.md?plain=1)
- [Office-Word-MCP-Server (GongRzhe)](https://github.com/GongRzhe/Office-Word-MCP-Server)
- [python-docx documentation](https://python-docx.readthedocs.io/en/latest/user/text.html)
- [Zed External Agents docs](https://zed.dev/docs/ai/external-agents)
- [Zed Tasks docs](https://zed.dev/docs/tasks)
- [Zed ACP blog post](https://zed.dev/blog/claude-code-via-acp)
- [Zed Issue #14137 (external file type handler — closed)](https://github.com/zed-industries/zed/issues/14137)
- [Zed Issue #28827 (open files in external apps — closed)](https://github.com/zed-industries/zed/issues/28827)
- [Claude Code Issue #9631 (docx track changes — open)](https://github.com/anthropics/claude-code/issues/9631)
- [Claude.ai file creation docs](https://support.claude.com/en/articles/12111783-create-and-edit-files-with-claude)
- [document-edit-mcp](https://github.com/alejandroBallesterosC/document-edit-mcp)
- [SuperDoc Document Engine](https://www.superdoc.dev/changelog/2026-03-22-document-engine)
