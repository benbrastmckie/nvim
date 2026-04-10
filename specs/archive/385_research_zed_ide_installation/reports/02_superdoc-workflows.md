# Research Report: Task #385 (Round 2)

**Task**: 385 - Research Zed IDE installation: SuperDoc MCP workflow deep-dive
**Started**: 2026-04-09T12:00:00Z
**Completed**: 2026-04-09T12:45:00Z
**Effort**: Medium
**Dependencies**: Round 1 research (01_team-research.md)
**Sources/Inputs**:
- SuperDoc official documentation (docs.superdoc.dev)
- SuperDoc GitHub repository (superdoc-dev/superdoc)
- SuperDoc Document Engine changelog (2026-03-22)
- Claude Code MCP documentation (code.claude.com/docs/en/mcp)
- Zed ACP documentation (zed.dev/docs/ai/external-agents)
- npm package registry (@superdoc-dev/mcp, @superdoc-dev/cli, @superdoc-dev/sdk)
- dvejsada/mcp-ms-office-documents GitHub
- openpyxl MCP server documentation
- Microsoft OneDrive support documentation
- Existing filetypes extension codebase
**Artifacts**:
- specs/385_research_zed_ide_installation/reports/02_superdoc-workflows.md

## Executive Summary

- SuperDoc MCP is an **open-source (AGPLv3)** Node.js package installable via `npx @superdoc-dev/mcp`; it provides 180+ deterministic tools for .docx manipulation with full tracked changes support
- Installation on macOS requires only Node.js 18+; one command (`claude mcp add superdoc -- npx @superdoc-dev/mcp`) registers it with Claude Code, and ACP in Zed automatically inherits Claude Code's MCP servers
- The tool inventory covers document lifecycle (open/save/close), content search/replace with formatting preservation, tracked changes via `--change-mode tracked`, comments, tables, lists, sections, and batch mutations
- For spreadsheet (.xlsx) editing, the **openpyxl MCP server** (`jonemo/openpyxl-excel`) is the recommended companion, providing read/write/format capabilities
- SharePoint/OneDrive file locking is mitigable via a **copy-edit-replace** pattern with optional OneDrive sync pause
- Integration with the existing filetypes extension requires adding a new `skill-docx-edit` / `docx-edit-agent` pair alongside the existing conversion-only `document-agent`

## Context & Scope

This report is the second research round for task 385. Round 1 (01_team-research.md) established that SuperDoc Document Engine MCP is the recommended backend for programmatic DOCX editing. This round provides:

1. Concrete installation and configuration steps for macOS
2. SuperDoc MCP tool inventory analysis
3. Claude Code MCP configuration mechanics (project vs user scope)
4. Five detailed step-by-step workflows for common Office operations
5. SharePoint file locking mitigation strategies
6. Filetypes extension integration architecture
7. Fallback alternatives if SuperDoc is insufficient

**Partner context**: macOS user, Microsoft Word with tracked changes, spreadsheets, SharePoint/OneDrive.

## Findings

### 1. SuperDoc MCP Installation and Configuration

#### Package Ecosystem

| Package | Install Command | Purpose |
|---------|----------------|---------|
| `@superdoc-dev/mcp` | `npx @superdoc-dev/mcp` | MCP server for AI agents |
| `@superdoc-dev/cli` | `npm install -g @superdoc-dev/cli` | CLI for shell/scripts |
| `@superdoc-dev/sdk` | `npm install @superdoc-dev/sdk` | Node.js SDK |
| `superdoc-sdk` | `pip install superdoc-sdk` | Python SDK |
| `@superdoc-dev/create` | `npx @superdoc-dev/create` | Project scaffolding (generates AGENTS.md) |

#### System Requirements (macOS)

- **Node.js 18+** (LTS recommended)
- **npm** (bundled with Node.js)
- No Docker required -- runs locally as a Node.js process
- No cloud dependency -- documents never leave the machine

#### Installation Steps

```bash
# 1. Ensure Node.js is installed
node --version  # must be >= 18

# 2. Register SuperDoc MCP with Claude Code (one-time)
claude mcp add superdoc -- npx @superdoc-dev/mcp

# 3. Verify registration
claude mcp list
```

This creates an entry in the MCP configuration that Claude Code reads on startup. The `npx` approach means no global install is needed; npm downloads and caches the package automatically.

#### Licensing

- **Open source**: AGPLv3 for community/open-source use
- **Commercial**: Enterprise license available for proprietary deployments
- **Dual licensed**: Free for open-source projects; commercial license needed if shipping proprietary software that embeds SuperDoc

For the partner's use case (personal document editing via Claude Code), the AGPLv3 license is sufficient -- no proprietary distribution is involved.

#### MCP Configuration Location

Claude Code stores MCP server configs at three scopes:

| Scope | File | Shared? | Command |
|-------|------|---------|---------|
| Local (default) | `.mcp.json` in project root | Per-project, per-user | `claude mcp add superdoc -- npx @superdoc-dev/mcp` |
| Project | `.mcp.json` in project root | Checked into VCS | `claude mcp add --scope project superdoc -- npx @superdoc-dev/mcp` |
| User | `~/.claude.json` | All projects | `claude mcp add --scope user superdoc -- npx @superdoc-dev/mcp` |

**Recommendation for partner**: Use `--scope user` so SuperDoc is available across all projects without per-project configuration.

```bash
claude mcp add --scope user superdoc -- npx @superdoc-dev/mcp
```

### 2. SuperDoc MCP Tool Inventory

SuperDoc exposes 180+ tools organized by the document lifecycle pattern: **open -> read/search -> edit -> save -> close**.

#### Core Lifecycle Tools

| Tool | Purpose |
|------|---------|
| `superdoc_open` | Open a .docx file for editing (params: file path, user name) |
| `superdoc_get_content` | Read document content (full or by section) |
| `superdoc_search` | Find text by pattern (returns match handles) |
| `superdoc_save` | Write changes back to disk |
| `superdoc_close` | Release the document handle |

#### Content Manipulation

| Category | Capabilities |
|----------|-------------|
| **Find/Replace** | Text pattern search, targeted replacement using match handles, regex support |
| **Insert/Delete** | Insert text at position, delete ranges, paragraph operations |
| **Formatting** | Bold, italic, underline, font size/family, color, alignment, spacing |
| **Structure** | Headings, paragraphs, lists (ordered/unordered), sections, page breaks |

#### Tracked Changes

The key design: any mutating operation accepts `--change-mode tracked` to apply the edit as a tracked change rather than a direct modification.

```
superdoc replace \
  --target-json '{"type": "text", "pattern": "ACME Corp"}' \
  --text "NewCo Inc." \
  --change-mode tracked
```

This produces a proper Word tracked change that appears in Word's Review pane, with the original text shown as deleted and the new text as inserted.

#### Tables, Lists, Sections

| Category | Operations |
|----------|-----------|
| **Tables** | Create, add/remove rows/columns, merge cells, set cell content, apply formatting |
| **Lists** | Create ordered/unordered, set levels, convert between types |
| **Sections** | Create sections, set headers/footers, page orientation, margins |
| **Comments** | Add, resolve, reply to comments with author attribution |

#### Batch Operations

Multiple edits can be grouped into a single atomic mutation using `expectedRevision` for optimistic concurrency:

```
superdoc batch \
  --operations '[
    {"type": "replace", "target": {...}, "text": "new value 1"},
    {"type": "replace", "target": {...}, "text": "new value 2"}
  ]' \
  --change-mode tracked
```

All operations apply together or none apply -- no partial states.

### 3. Claude Code MCP Configuration for Zed ACP

#### How ACP Inherits MCP Servers

When Claude Code runs inside Zed via ACP (Agent Client Protocol):

1. Zed spawns Claude Code as a subprocess via the `claude-agent-acp` adapter
2. Claude Code reads its own MCP configuration (`.mcp.json`, `~/.claude.json`)
3. MCP servers registered with Claude Code are available to the agent automatically
4. No separate Zed-side MCP configuration is needed for Claude Code's servers

**Key insight**: Zed has its own `context_servers` configuration (in `~/.config/zed/settings.json`) for Zed's native AI features, but Claude Code running via ACP uses its own MCP config. They are independent.

#### Configuration Architecture

```
Zed Editor
  |
  +-- Zed Native AI (uses context_servers in zed settings.json)
  |     |
  |     +-- Zed MCP servers (separate from Claude Code)
  |
  +-- Claude Code via ACP (uses .mcp.json / ~/.claude.json)
        |
        +-- SuperDoc MCP (registered with claude mcp add)
        +-- Other MCP servers (markitdown, etc.)
```

#### Setup for Partner

```bash
# One-time setup (run in terminal, not in Zed)
claude mcp add --scope user superdoc -- npx @superdoc-dev/mcp

# Verify
claude mcp list

# Now open Zed, use Claude Code via Agent Panel (Cmd+?)
# SuperDoc tools are automatically available
```

### 4. Detailed Step-by-Step Workflows

#### Workflow A: Edit Word Document with Tracked Changes

**Scenario**: Partner has `contract.docx` open in Word. Wants Claude to replace "ACME Corp" with "NewCo Inc." throughout, appearing as tracked changes.

**Prerequisites**: SuperDoc MCP registered, file accessible on local filesystem.

```
Step 1: Partner saves and closes the document in Word
        (or at minimum saves -- SuperDoc can work with saved files
         even if Word has them open, but closing avoids lock conflicts)

Step 2: Partner opens Zed, starts Claude Code via Agent Panel (Cmd+?)

Step 3: Partner types:
        "In ~/Documents/contract.docx, replace all instances of
         'ACME Corp' with 'NewCo Inc.' using tracked changes"

Step 4: Claude Code invokes SuperDoc MCP tools:
        a) superdoc_open("~/Documents/contract.docx", user="Partner Name")
        b) superdoc_search(type="text", pattern="ACME Corp")
           -> returns list of matches with handles
        c) For each match:
           superdoc_replace(target=handle, text="NewCo Inc.",
                           change_mode="tracked")
        d) superdoc_save()
        e) superdoc_close()

Step 5: Partner opens contract.docx in Word
        -> Sees tracked changes: "ACME Corp" struck through,
           "NewCo Inc." inserted, attributed to "Partner Name"
        -> Can Accept/Reject each change individually or in bulk
```

**Timing**: Steps 4a-4e happen in seconds (no human interaction needed).

**Edge cases**:
- If Word has the file locked: Claude reports the error; partner closes Word first
- If text appears in headers/footers: SuperDoc handles all document parts, not just body
- If text is inside a table cell: SuperDoc searches across all content containers

#### Workflow B: Update Spreadsheet Data

**Scenario**: Partner has `budget.xlsx` with monthly expense data. Wants to update Q2 figures and add a new row.

**Option 1: openpyxl MCP Server** (recommended for data manipulation)

```bash
# One-time setup
claude mcp add --scope user openpyxl -- npx @jonemo/openpyxl-mcp
```

```
Step 1: Partner saves budget.xlsx

Step 2: In Zed/Claude Code:
        "In ~/Documents/budget.xlsx, update the April column:
         - Row 'Marketing': change from 5000 to 7500
         - Row 'Engineering': change from 12000 to 14000
         - Add a new row 'Cloud Services' with values 3000, 3200, 3500
         - Update the Q2 Total formula"

Step 3: Claude uses openpyxl MCP tools to:
        a) Open the workbook
        b) Navigate to the correct sheet
        c) Find cells by header/row labels
        d) Update values
        e) Insert new row with data
        f) Verify/update formulas
        g) Save

Step 4: Partner opens in Excel -- sees updated data
```

**Option 2: Python script via Bash** (fallback)

```python
import openpyxl
wb = openpyxl.load_workbook('budget.xlsx')
ws = wb.active
# ... manipulate cells ...
wb.save('budget.xlsx')
```

Claude can write and execute this script directly if the openpyxl MCP server is not installed.

**Limitation**: Neither approach supports Excel tracked changes (Excel's "Track Changes" feature was deprecated by Microsoft in favor of co-authoring). Changes are direct edits.

#### Workflow C: Batch-Edit SharePoint-Synced Documents

**Scenario**: Partner has 5 contract templates in `~/OneDrive/Contracts/` that need a company name change across all files.

```
Step 1: Pause OneDrive sync
        macOS: Click OneDrive icon in menu bar -> Settings ->
               "Pause Syncing" -> select duration (2/8/24 hours)

        Alternative (command line):
        killall OneDrive  # stops sync entirely

Step 2: In Zed/Claude Code:
        "In all .docx files in ~/OneDrive/Contracts/,
         replace 'Old Company LLC' with 'New Company LLC'
         using tracked changes. Show me a summary of changes."

Step 3: Claude iterates:
        For each .docx file in the directory:
          a) superdoc_open(file_path)
          b) superdoc_search("Old Company LLC")
          c) superdoc_replace(matches, "New Company LLC",
                             change_mode="tracked")
          d) superdoc_save()
          e) superdoc_close()

        Returns summary: "Updated 5 files, 23 total replacements"

Step 4: Resume OneDrive sync
        macOS: Click OneDrive icon -> "Resume Syncing"

        Alternative: open -a OneDrive

Step 5: OneDrive uploads modified files to SharePoint
        -> Other users see tracked changes when they open the docs
```

**Conflict prevention**:
- Pausing sync prevents OneDrive from detecting mid-edit states
- The copy-edit-replace pattern (see Section 5) is safer for critical documents
- If a colleague has a file open in SharePoint, the upload creates a conflict copy -- partner must manually resolve

#### Workflow D: Create New Document from Scratch

**Scenario**: Partner describes a memo they need. Claude creates a properly formatted .docx.

```
Step 1: In Zed/Claude Code:
        "Create a new Word document at ~/Documents/memo.docx:
         - Title: 'Q2 Budget Review'
         - Date: April 9, 2026
         - From: [Partner Name], Finance Director
         - To: Executive Team
         - Body: [partner provides content or asks Claude to draft]
         - Include a summary table with 4 columns
         - Use professional formatting with company header"

Step 2: Claude uses SuperDoc MCP:
        a) superdoc_open("~/Documents/memo.docx", create=true)
        b) Insert heading with title
        c) Insert metadata (date, from, to) with formatting
        d) Insert body paragraphs
        e) Create and populate table
        f) Apply styles (heading levels, body text, table formatting)
        g) superdoc_save()
        h) superdoc_close()

Step 3: Partner opens memo.docx in Word
        -> Fully formatted document ready for review/sending
```

**Template support**: If partner has a template (.dotx), SuperDoc can open it as the base and populate content into the template's structure.

**Alternative for complex formatting**: If the document requires features SuperDoc does not cover (e.g., embedded charts, SmartArt), Claude can generate a python-docx script as a fallback.

#### Workflow E: Convert Between Formats

**Scenario**: Partner needs to convert documents between formats, integrating with the existing `/convert` command.

```
DOCX -> Markdown (for editing in Zed):
  /convert contract.docx
  -> Uses markitdown or pandoc (existing document-agent)
  -> Produces contract.md for text editing

Markdown -> DOCX (for sharing with Word users):
  /convert notes.md notes.docx
  -> Uses pandoc with reference doc for styling
  -> Or SuperDoc to create .docx from content

DOCX -> PDF (for distribution):
  /convert report.docx report.pdf
  -> pandoc with PDF engine, OR
  -> libreoffice --headless --convert-to pdf report.docx

Markdown -> DOCX with tracked changes (hybrid):
  Step 1: /convert original.docx original.md  (extract)
  Step 2: Edit original.md in Zed              (modify)
  Step 3: Use SuperDoc to apply the diff as tracked changes
          to original.docx                     (merge back)
```

**Integration with /convert**: The existing `/convert` command handles format conversion via `document-agent`. SuperDoc would extend this with a new capability: **editing** the .docx in place, which `/convert` currently cannot do.

### 5. SharePoint File Locking Mitigation

#### The Problem

SharePoint/OneDrive places exclusive locks on files being edited:
- Lock acquired when Word opens a file from OneDrive
- Lock held for the editing session + 10-minute timeout after close
- Lock prevents other apps (including SuperDoc) from saving to the same path
- Crashed sessions can leave orphaned locks (10-minute auto-release)

#### Strategy 1: Pause-Edit-Resume (Recommended for batch ops)

```
1. Pause OneDrive sync (menu bar or killall OneDrive)
2. Edit files with SuperDoc (files are local, no lock contention)
3. Resume OneDrive sync (open -a OneDrive)
4. OneDrive uploads changes on next sync cycle
```

**Risk**: If someone else modified the file on SharePoint while sync was paused, a conflict copy is created. Low risk for files only the partner edits.

#### Strategy 2: Copy-Edit-Replace (Safest)

```
1. Copy file to a working directory outside OneDrive:
   cp ~/OneDrive/doc.docx ~/workspace/doc.docx

2. Edit the copy with SuperDoc:
   superdoc_open("~/workspace/doc.docx")
   ... edits ...
   superdoc_save()
   superdoc_close()

3. Replace the original:
   mv ~/workspace/doc.docx ~/OneDrive/doc.docx

4. OneDrive detects change and uploads
```

**Advantage**: Never touches the synced file during editing. The `mv` is atomic on macOS (same filesystem).

#### Strategy 3: Close-Word-First (Simplest)

```
1. Partner saves and closes the document in Word
2. Wait 10 seconds for lock release
3. Edit with SuperDoc
4. Partner reopens in Word
```

**Best for**: Single-file edits where partner is actively collaborating with Claude.

#### Strategy 4: Conflict Detection

Before editing, check if the file is locked:

```bash
# Check if file is in use (macOS)
lsof ~/OneDrive/document.docx

# Check OneDrive sync status
# (no reliable CLI for this on macOS)
```

Claude can check `lsof` before attempting to open with SuperDoc and warn the partner if the file appears locked.

### 6. Filetypes Extension Integration Path

#### Current Architecture

```
/convert command
  -> skill-filetypes (routing)
    -> filetypes-router-agent (format detection)
      -> document-agent (PDF/DOCX/MD conversion only)
      -> spreadsheet-agent (XLSX -> LaTeX/Typst tables)
      -> presentation-agent (PPTX -> Beamer/slides)
      -> scrape-agent (PDF annotation extraction)
```

The current `document-agent` only handles **format conversion** (DOCX -> Markdown, Markdown -> PDF). It does NOT support in-place DOCX editing, tracked changes, or content manipulation.

#### Proposed Extension

Add new components for DOCX editing alongside existing conversion:

```
New command: /edit (or extend /convert)
  -> skill-docx-edit (new skill)
    -> docx-edit-agent (new agent)
      -> SuperDoc MCP tools

Existing: /convert (unchanged)
  -> skill-filetypes
    -> filetypes-router-agent
      -> document-agent (conversion only)
```

#### New Components Needed

**1. `skill-docx-edit` (new skill)**

```
Location: .claude/extensions/filetypes/skills/skill-docx-edit/SKILL.md
Purpose: Route DOCX editing operations to docx-edit-agent
Trigger: "edit document", "tracked changes", "find/replace in docx"
MCP dependency: superdoc (must be registered)
```

**2. `docx-edit-agent` (new agent)**

```
Location: .claude/extensions/filetypes/agents/docx-edit-agent.md
Purpose: Execute DOCX editing operations via SuperDoc MCP
Tools: SuperDoc MCP tools (superdoc_open, superdoc_search, etc.)
Capabilities:
  - Find/replace with formatting preservation
  - Tracked changes (insert, delete, replace)
  - Comment management
  - Table editing
  - Batch operations
  - Template population
```

**3. `skill-xlsx-edit` (new skill, optional)**

```
Location: .claude/extensions/filetypes/skills/skill-xlsx-edit/SKILL.md
Purpose: Route XLSX editing operations
MCP dependency: openpyxl MCP server
```

**4. Updated manifest.json**

Add new agents, skills, and MCP server declarations:

```json
{
  "mcp_servers": {
    "superdoc": {
      "command": "npx",
      "args": ["@superdoc-dev/mcp"],
      "scope": "user"
    }
  },
  "provides": {
    "agents": [..., "docx-edit-agent.md"],
    "skills": [..., "skill-docx-edit"]
  }
}
```

**5. Updated conversion-tables.md**

Add editing operations table:

```
| Operation | Tool | MCP Server |
|-----------|------|------------|
| DOCX edit (tracked changes) | SuperDoc | superdoc |
| DOCX edit (direct) | SuperDoc | superdoc |
| XLSX edit | openpyxl | openpyxl |
```

#### Router Integration

The `filetypes-router-agent` needs a new routing branch:

```
If operation_type == "edit" AND format == "docx":
  -> delegate to docx-edit-agent
If operation_type == "convert":
  -> existing routing (document-agent, etc.)
```

### 7. Alternatives to SuperDoc

If SuperDoc is commercial/unavailable/insufficient:

| Alternative | Format | Tracked Changes | Strengths | Weaknesses | Status |
|-------------|--------|----------------|-----------|------------|--------|
| **SuperDoc MCP** | DOCX | Yes (native) | 180+ tools, format-preserving, local | AGPLv3 license | Active, recommended |
| **python-docx + docx-revisions** | DOCX | Partial (read-only) | Pure Python, no deps | Cannot write tracked changes | Active |
| **hongkongkiwi/docx-mcp** | DOCX | No | Simple MCP wrapper | Limited operations | Active |
| **dvejsada/mcp-ms-office-documents** | DOCX, XLSX, PPTX, EML | No | Multi-format, Docker, templates | Docker dependency, creation-focused | Active |
| **GongRzhe/Office-Word-MCP-Server** | DOCX | No | Good API design | Archived March 2026 | Archived |
| **pandoc roundtrip** | DOCX | No | Universal, mature | Lossy -- destroys formatting | Active |
| **python-docx direct** | DOCX | No (write) | Full OOXML access | Complex, no tracked changes | Active |
| **libreoffice --headless** | All Office | Via macros | Full Office compatibility | Slow, heavy dependency | Active |

#### Ranked Alternatives

1. **SuperDoc MCP** -- best overall, recommended
2. **dvejsada/mcp-ms-office-documents** -- good for document creation from templates; complement to SuperDoc for multi-format needs
3. **python-docx via Bash** -- fallback for operations SuperDoc does not cover; Claude writes and executes Python scripts
4. **libreoffice --headless** -- nuclear option for complex documents; can apply VBA macros
5. **pandoc roundtrip** -- acceptable only for plain prose documents

## Decisions

1. **SuperDoc MCP is the primary DOCX editing backend** -- it is open source (AGPLv3), runs locally, provides tracked changes, and requires only Node.js
2. **openpyxl MCP server for spreadsheets** -- complements SuperDoc for .xlsx editing
3. **User-scope MCP registration** -- partner should use `--scope user` for cross-project availability
4. **Copy-edit-replace for SharePoint files** -- safest pattern for OneDrive-synced documents
5. **New skill/agent pair needed** -- `skill-docx-edit` + `docx-edit-agent` extend the filetypes extension without modifying existing conversion functionality

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| SuperDoc MCP package not yet published to npm | Medium | High | Verify `npx @superdoc-dev/mcp` works before partner setup; fall back to CLI or SDK |
| AGPLv3 license incompatibility | Low | Low | Partner use case (personal editing) does not trigger AGPL distribution requirements |
| SharePoint lock conflicts | Medium | Medium | Use copy-edit-replace pattern; check `lsof` before editing |
| SuperDoc tool coverage gaps | Low | Medium | Fall back to python-docx scripts for edge cases |
| Node.js version mismatch on partner's Mac | Low | Low | Install via `brew install node@20` |
| Tracked changes attribution | Low | Low | SuperDoc `user-name` parameter sets the author; verify it matches partner's Word identity |
| Large document performance | Low | Medium | SuperDoc runs locally; 180+ tools are deterministic (no LLM overhead per operation) |

## Context Extension Recommendations

- **Topic**: MCP server configuration patterns for Office document editing
- **Gap**: The filetypes extension `mcp-integration.md` documents markitdown-mcp and mcp-pandoc but has no entry for SuperDoc or openpyxl MCP servers
- **Recommendation**: Update `.claude/extensions/filetypes/context/project/filetypes/tools/mcp-integration.md` to include SuperDoc and openpyxl MCP server configuration

- **Topic**: DOCX editing patterns (distinct from conversion)
- **Gap**: No context file documents in-place document editing workflows; existing patterns cover only format conversion
- **Recommendation**: Create `.claude/extensions/filetypes/context/project/filetypes/patterns/docx-editing.md` covering tracked changes, find/replace, and batch edit patterns

## Appendix

### Search Queries Used

1. "SuperDoc Document Engine MCP server install configure 2026"
2. "SuperDoc MCP tools list tracked changes find replace paragraph docx editing"
3. "@superdoc-dev/mcp npm package tools API documentation"
4. "Claude Code MCP configuration .claude/settings.json project level server add"
5. "Claude Code ACP Zed MCP servers inherited picked up automatically"
6. "SharePoint OneDrive file locking conflict resolution programmatic editing workaround"
7. "openpyxl xlsx editing MCP server spreadsheet Claude AI agent 2026"
8. "dvejsada/mcp-ms-office-documents MCP tools docx xlsx features Docker"

### References

- [SuperDoc GitHub](https://github.com/superdoc-dev/superdoc)
- [SuperDoc Documentation](https://docs.superdoc.dev/getting-started/introduction)
- [SuperDoc Document Engine Changelog](https://www.superdoc.dev/changelog/2026-03-22-document-engine)
- [Claude Code MCP Documentation](https://code.claude.com/docs/en/mcp)
- [Zed External Agents (ACP)](https://zed.dev/docs/ai/external-agents)
- [Claude Code ACP in Zed](https://zed.dev/acp/agent/claude-code)
- [dvejsada/mcp-ms-office-documents](https://github.com/dvejsada/mcp-ms-office-documents)
- [openpyxl MCP Server](https://playbooks.com/mcp/jonemo-openpyxl-excel)
- [hongkongkiwi/docx-mcp](https://github.com/hongkongkiwi/docx-mcp)
- [OneDrive Pause/Resume](https://support.microsoft.com/en-us/office/how-to-pause-and-resume-sync-in-onedrive-2152bfa4-a2a5-4d3a-ace8-92912fb4421e)
- [Configuring MCP in Claude Code](https://scottspence.com/posts/configuring-mcp-tools-in-claude-code)
- [docx-editing-superdoc skill](https://skills.rest/skill/docx-editing-superdoc)
