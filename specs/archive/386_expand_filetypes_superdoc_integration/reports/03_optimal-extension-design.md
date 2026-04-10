# Research Report: Optimal Filetypes Extension Design for SuperDoc Integration

- **Task**: 386 - expand_filetypes_superdoc_integration
- **Started**: 2026-04-09T20:00:00Z
- **Completed**: 2026-04-09T20:30:00Z
- **Effort**: Low-Medium
- **Dependencies**: Task 385 (Zed + Claude Code guide), Round 1 research (01_team-research.md), Round 2 research (02_word-reload-workflow.md)
- **Sources/Inputs**:
  - specs/385_research_zed_ide_installation/guide/zed-claude-office-guide.md (use case guide)
  - specs/386_expand_filetypes_superdoc_integration/reports/01_team-research.md (team research)
  - specs/386_expand_filetypes_superdoc_integration/reports/02_word-reload-workflow.md (Word reload workflow)
  - .claude/extensions/filetypes/ (existing extension: manifest, agents, skills, commands, context)
  - .claude/extensions/founder/manifest.json (MCP server declaration pattern)
- **Artifacts**:
  - specs/386_expand_filetypes_superdoc_integration/reports/03_optimal-extension-design.md
- **Standards**: report-format.md, artifact-management.md, tasks.md

## Executive Summary

- The guide in task 385 defines four core workflows: edit DOCX with tracked changes, update XLSX, batch edit multiple documents, and create new documents from scratch. The filetypes extension needs a `/edit` command with `skill-docx-edit` and `docx-edit-agent` to serve these workflows.
- The extension should declare `superdoc` as an MCP server in `manifest.json` following the founder extension pattern, with `openpyxl` as a second MCP server for spreadsheet editing.
- The `docx-edit-agent` must implement a 5-step workflow: check Word state, save unsaved partner work via AppleScript, perform SuperDoc edits, reload document in Word, and confirm results -- enabling a zero-friction experience where the partner never closes Word.
- Two new context files are needed: `superdoc-integration.md` (tool reference) and `office-edit-patterns.md` (workflow patterns including the AppleScript save/reload bracket).
- The design deliberately bypasses the existing `filetypes-router-agent` (following the `skill-scrape` and `skill-spreadsheet` direct-invocation precedent) to avoid breaking existing `/convert` flows.

## Context & Scope

The task 385 guide establishes a use case for a non-technical partner on macOS who will use Zed + Claude Code + SuperDoc MCP to edit Word documents and Excel spreadsheets. The guide defines four workflows (edit with tracked changes, update spreadsheet, batch edit, create new document) and currently tells the partner to "save and close" documents before editing.

Round 2 research discovered that macOS advisory locks allow SuperDoc to edit files while Word has them open, and that `Document.Reload` via AppleScript can refresh Word without closing it. This eliminates the "close Word first" requirement.

This report synthesizes the guide's workflows with the prior research to define the optimal set of commands, skills, agents, context files, and manifest updates for the filetypes extension.

## Findings

### 1. Workflows from the Guide Mapped to Extension Components

The guide defines these workflows that the extension must support:

| Guide Workflow | Extension Component | Command | Notes |
|---|---|---|---|
| Workflow 1: Edit DOCX with tracked changes | `docx-edit-agent` | `/edit` | Core workflow -- SuperDoc `search_and_replace_with_tracked_changes` |
| Workflow 2: Update spreadsheet | `xlsx-edit-agent` (deferred) | `/edit` | openpyxl MCP -- deferred per Round 1 consensus |
| Workflow 3: Batch edit multiple DOCX | `docx-edit-agent` (batch mode) | `/edit` | Agent iterates files in a directory |
| Workflow 4: Create new document | `docx-edit-agent` (create mode) | `/edit` | SuperDoc `create_document` + `add_paragraph`/`add_table` |

The `/edit` command handles all four workflows. The agent determines the operation type (edit existing, batch edit, create new) from the user's natural language request.

### 2. Complete Component Inventory

#### Commands (1 new)

**`/edit`** -- In-place Office document editing

```
/edit contract.docx "Replace ACME Corp with NewCo Inc. using tracked changes"
/edit budget.xlsx "Change Marketing Q2 from 5000 to 7500"
/edit ~/Documents/Contracts/ "Replace Old Company LLC with New Company LLC in all .docx files"
/edit --new memo.docx "Create Q2 Budget Review memo with department table"
```

Design notes:
- Accepts a file path (or directory for batch) and a natural language instruction
- The `--new` flag signals document creation rather than editing
- Routes to `skill-docx-edit` for .docx files
- Future: routes to `skill-xlsx-edit` for .xlsx files
- Follows the existing command pattern (`/scrape`, `/convert`) with GATE IN, DELEGATE, GATE OUT, COMMIT checkpoints

#### Skills (1 new, 1 future)

**`skill-docx-edit`** -- Thin wrapper routing to `docx-edit-agent`

Following the `skill-scrape` pattern (direct invocation, NOT through the router):
- `allowed-tools: Task`
- Validates input: file path exists, is .docx (or directory for batch)
- Prepares delegation context with file path, instruction, session metadata
- Spawns `docx-edit-agent` via Task tool
- Validates return matches subagent-return.md schema

**`skill-xlsx-edit`** (future/deferred) -- Thin wrapper routing to `xlsx-edit-agent`

#### Agents (1 new, 1 future)

**`docx-edit-agent`** -- In-place DOCX editing with SuperDoc MCP

6-stage execution flow following existing agent pattern:

```
Stage 1: Parse delegation context (file_path, instruction, session metadata)
Stage 2: Validate inputs (file exists, is .docx, SuperDoc MCP available)
Stage 3: Detect tools (SuperDoc MCP -> python-docx fallback -> fail)
Stage 4: Execute edit workflow
  4a: Check if Word is running and has file open (AppleScript)
  4b: If open, save partner's unsaved work (AppleScript)
  4c: Perform SuperDoc operations (open, edit, save, close)
  4d: If Word had file open, trigger reload (AppleScript)
Stage 5: Validate output (file modified, changes applied)
Stage 6: Return JSON result
```

Key design decisions from prior research:
- Named `docx-edit-agent` (not `document-edit-agent`) because SuperDoc is DOCX-specific
- Direct invocation from `skill-docx-edit`, bypassing `filetypes-router-agent`
- Implements forced question pattern (from founder extension): "Should changes be tracked? What author name for tracked changes?"
- Tool fallback chain: SuperDoc MCP -> python-docx -> fail with install instructions
- Return status values: "edited", "created", "partial", "failed" (never "completed")

**AppleScript integration** (macOS only):
```bash
# Check if Word is running
osascript -e 'tell application "System Events" to (name of processes) contains "Microsoft Word"'

# Save partner's unsaved changes
osascript -e 'tell application "Microsoft Word" to save active document'

# Reload after SuperDoc edit
osascript -e 'tell application "Microsoft Word" to reload active document'
```

On non-macOS platforms, the AppleScript steps are skipped and the agent warns the user to close the document manually before editing.

**Batch mode behavior**:
- When given a directory path, the agent iterates all .docx files
- Applies the same instruction to each file
- Reports per-file results with change counts
- Follows guide Workflow 3 pattern

**Create mode behavior**:
- When `--new` flag is set or file does not exist
- Uses SuperDoc `create_document`, `add_paragraph`, `add_table`, `add_heading`
- Follows guide Workflow 4 pattern

**`xlsx-edit-agent`** (future/deferred) -- In-place XLSX editing with openpyxl MCP

#### Context Files (2 new)

**`project/filetypes/tools/superdoc-integration.md`**

Content should cover:
- SuperDoc MCP server configuration (`npx @superdoc-dev/mcp`)
- Available SuperDoc tools inventory:
  - `open_document(path)` -- Open a DOCX file
  - `close_document(doc_id)` -- Close and release document
  - `save_document(doc_id, path?)` -- Save to disk
  - `get_document_text(doc_id)` -- Read full text
  - `search_and_replace(doc_id, find, replace)` -- Find and replace
  - `search_and_replace_with_tracked_changes(doc_id, find, replace, author?)` -- With tracking
  - `add_paragraph(doc_id, text, style?)` -- Add text
  - `add_heading(doc_id, text, level)` -- Add heading
  - `add_table(doc_id, rows, cols, data?)` -- Add table
  - `create_document(path)` -- Create new empty document
- Fallback chain documentation (SuperDoc -> python-docx -> fail)
- Comparison with markitdown (read-only conversion) vs SuperDoc (read-write editing)
- Load when: `agents: ["docx-edit-agent"]`, `commands: ["/edit"]`

**`project/filetypes/patterns/office-edit-patterns.md`**

Content should cover:
- The 5-step Word integration workflow (check -> save -> edit -> reload -> confirm)
- AppleScript commands for Word automation
- OneDrive/SharePoint sync pause pattern for batch edits
- Tracked changes workflow with author attribution
- File locking behavior on macOS (advisory only)
- Edge cases: multiple documents open, Word not running, read-only mode
- Batch editing pattern (directory iteration with per-file reporting)
- Document creation pattern (heading/paragraph/table composition)
- Load when: `agents: ["docx-edit-agent"]`, `commands: ["/edit"]`

### 3. Manifest Updates

The `manifest.json` needs these changes:

```json
{
  "mcp_servers": {
    "superdoc": {
      "command": "npx",
      "args": ["-y", "@superdoc-dev/mcp"],
      "env": {}
    },
    "openpyxl": {
      "command": "npx",
      "args": ["-y", "@jonemo/openpyxl-mcp"],
      "env": {}
    }
  },
  "provides": {
    "agents": ["..existing..", "docx-edit-agent.md"],
    "skills": ["..existing..", "skill-docx-edit"],
    "commands": ["..existing..", "edit.md"]
  }
}
```

Notes:
- Both MCP servers declared following the founder extension pattern (command + args + env)
- openpyxl declared now even though xlsx-edit is deferred, so the MCP server is available for manual use
- `"language": null` remains unchanged -- filetypes uses command-based invocation, not language routing

### 4. Index Entries Updates

Two new entries for `index-entries.json`:

```json
[
  {
    "path": "project/filetypes/tools/superdoc-integration.md",
    "description": "SuperDoc MCP server configuration and tool inventory for DOCX editing",
    "line_count": 120,
    "load_when": {
      "agents": ["docx-edit-agent"],
      "languages": [],
      "commands": ["/edit"]
    },
    "domain": "project",
    "subdomain": "filetypes",
    "summary": "SuperDoc MCP server configuration and tool inventory for DOCX editing"
  },
  {
    "path": "project/filetypes/patterns/office-edit-patterns.md",
    "description": "Office document editing patterns: Word AppleScript integration, tracked changes, batch editing",
    "line_count": 150,
    "load_when": {
      "agents": ["docx-edit-agent"],
      "languages": [],
      "commands": ["/edit"]
    },
    "domain": "project",
    "subdomain": "filetypes",
    "summary": "Office document editing patterns: Word AppleScript integration, tracked changes, batch editing"
  }
]
```

### 5. EXTENSION.md Updates

Add to the skill-agent mapping table:

```markdown
| skill-docx-edit | docx-edit-agent | In-place DOCX editing with tracked changes (SuperDoc MCP) |
```

Add to the commands table:

```markdown
| `/edit` | `/edit file.docx "instruction"` | Edit Office documents in-place |
```

### 6. Files That Need Updating (Existing)

| File | Change | Priority |
|---|---|---|
| `mcp-integration.md` | Add SuperDoc section alongside markitdown and pandoc | MEDIUM |
| `conversion-tables.md` | Add "Edit Operations" table distinguishing conversion from editing | MEDIUM |
| `tool-detection.md` | Add SuperDoc detection logic (`mcp_available("superdoc")`) | MEDIUM |
| `dependency-guide.md` | Add SuperDoc/openpyxl npm installation instructions | LOW |

### 7. What the Extension Does NOT Need

Based on analysis of the guide and existing patterns:

- **No language routing block** -- filetypes remains `"language": null`, command-invoked only
- **No modification to `filetypes-router-agent`** -- editing bypasses the conversion router
- **No new rules files** -- the agent's behavior is fully defined by the agent file and context
- **No test infrastructure** -- no test directory exists in the filetypes extension; out of scope
- **No xlsx-edit implementation** -- deferred per Round 1 consensus; openpyxl MCP is declared but no skill/agent/command routes to it yet
- **No opencode-agents.json update** -- LOW priority, can be added later

## Decisions

1. **Single `/edit` command handles all four guide workflows** -- the agent determines operation type (edit, batch, create) from context rather than requiring separate commands. This matches the guide's philosophy of "type what you need in plain English."

2. **Declare both MCP servers now, implement one** -- SuperDoc and openpyxl are both declared in `manifest.json` `mcp_servers`, but only `docx-edit-agent` is implemented. This lets the partner use openpyxl via direct Claude interaction while the formal xlsx-edit agent is deferred.

3. **AppleScript Word integration is mandatory on macOS** -- The zero-friction workflow (save -> edit -> reload) is not optional; it is the primary differentiator from the guide's current "close Word first" instruction. On non-macOS, skip gracefully with a warning.

4. **Forced questioning pattern from founder extension** -- The agent should ask about tracked changes preference and author name on first invocation, following the founder extension's pattern of clarifying before proceeding.

5. **Direct skill-to-agent invocation, no router** -- Following `skill-scrape` and `skill-spreadsheet` precedent. The router handles format detection for conversion; editing is a different operation that does not need format routing.

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| SuperDoc npm package unavailable | Medium | Critical | Verify `npm show @superdoc-dev/mcp` as Phase 1 of implementation; fall back to `dvejsada/mcp-ms-office-documents` or python-docx |
| `Document.Reload` not available on partner's Word version | Low | High | Test on partner's machine; fall back to close+reopen sequence |
| macOS TCC blocks AppleScript | Low | High | First run prompts for accessibility permission; document in guide |
| Partner types during SuperDoc edit window (2-5 sec) | Medium | Low | Agent can warn "editing document, please wait..." |
| openpyxl MCP package name unverified | Medium | Low | Only declared in manifest, not wired to agent; low impact if wrong |

## Appendix

### Complete File Inventory for Implementation

Files to create:
1. `.claude/extensions/filetypes/commands/edit.md`
2. `.claude/extensions/filetypes/skills/skill-docx-edit/SKILL.md`
3. `.claude/extensions/filetypes/agents/docx-edit-agent.md`
4. `.claude/extensions/filetypes/context/project/filetypes/tools/superdoc-integration.md`
5. `.claude/extensions/filetypes/context/project/filetypes/patterns/office-edit-patterns.md`

Files to update:
6. `.claude/extensions/filetypes/manifest.json` (mcp_servers, provides)
7. `.claude/extensions/filetypes/index-entries.json` (2 new entries)
8. `.claude/extensions/filetypes/EXTENSION.md` (skill-agent mapping, commands table)
9. `.claude/extensions/filetypes/context/project/filetypes/tools/mcp-integration.md` (SuperDoc section)
10. `.claude/extensions/filetypes/context/project/filetypes/domain/conversion-tables.md` (edit operations)
11. `.claude/extensions/filetypes/context/project/filetypes/tools/tool-detection.md` (SuperDoc detection)

### Workflow Sequence Diagram

```
User types in Zed Agent Panel
  |
  v
/edit contract.docx "Replace ACME with NewCo using tracked changes"
  |
  v
[GATE IN: parse args, validate .docx exists]
  |
  v
[DELEGATE: skill-docx-edit]
  |
  v
[Task: docx-edit-agent]
  |
  +---> Check: Is Word running? Has file open?
  |       |
  |       v (yes)
  +---> AppleScript: Save partner's unsaved work
  |
  +---> SuperDoc: open_document(path)
  +---> SuperDoc: search_and_replace_with_tracked_changes(doc_id, "ACME", "NewCo")
  +---> SuperDoc: save_document(doc_id)
  +---> SuperDoc: close_document(doc_id)
  |
  +---> AppleScript: Reload document in Word
  |
  v
[Return: {status: "edited", summary: "Replaced 3 instances..."}]
  |
  v
[GATE OUT: verify file modified]
  |
  v
User sees tracked changes appear in Word automatically
```

### References

- Task 385 guide: `specs/385_research_zed_ide_installation/guide/zed-claude-office-guide.md`
- Round 1 research: `specs/386_expand_filetypes_superdoc_integration/reports/01_team-research.md`
- Round 2 research: `specs/386_expand_filetypes_superdoc_integration/reports/02_word-reload-workflow.md`
- Existing extension: `.claude/extensions/filetypes/`
- Founder extension MCP pattern: `.claude/extensions/founder/manifest.json`
- Scrape skill/agent pattern: `.claude/extensions/filetypes/skills/skill-scrape/SKILL.md`, `.claude/extensions/filetypes/agents/scrape-agent.md`
