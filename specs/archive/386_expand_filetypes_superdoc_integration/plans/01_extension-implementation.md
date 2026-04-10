# Implementation Plan: Filetypes SuperDoc Extension

- **Task**: 386 - expand_filetypes_superdoc_integration
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: Task 385 (Zed + Claude Code guide)
- **Research Inputs**: reports/03_optimal-extension-design.md, reports/01_team-research.md, reports/02_word-reload-workflow.md
- **Artifacts**: plans/01_extension-implementation.md
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Expand the filetypes extension with a `/edit` command, `skill-docx-edit`, and `docx-edit-agent` for in-place DOCX editing via SuperDoc MCP. The agent implements a 5-step Word integration workflow (check Word state, save partner work via AppleScript, SuperDoc edit, reload document, confirm results) enabling zero-friction editing where the partner never closes Word. Two new context files document SuperDoc tools and Office editing patterns. The manifest gains SuperDoc and openpyxl MCP server declarations.

### Research Integration

Three research rounds inform this plan:
- **Round 1** (01_team-research.md): Established the direct skill-to-agent invocation pattern (bypassing filetypes-router-agent), confirmed `docx-edit-agent` naming, and identified the tool fallback chain (SuperDoc -> python-docx -> fail).
- **Round 2** (02_word-reload-workflow.md): Discovered macOS advisory locks allow concurrent SuperDoc access, and `Document.Reload` via AppleScript refreshes Word without closing it.
- **Round 3** (03_optimal-extension-design.md): Synthesized the complete component inventory: 1 command, 1 skill, 1 agent, 2 context files, plus manifest/index/EXTENSION.md updates.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROAD_MAP.md found.

## Goals & Non-Goals

**Goals**:
- Create `/edit` command for in-place Office document editing
- Create `skill-docx-edit` thin wrapper routing to `docx-edit-agent`
- Create `docx-edit-agent` with SuperDoc MCP integration and AppleScript Word automation
- Create `superdoc-integration.md` tool reference and `office-edit-patterns.md` workflow patterns
- Update `manifest.json` with SuperDoc and openpyxl MCP server declarations
- Update `index-entries.json`, `EXTENSION.md`, and existing context files

**Non-Goals**:
- Implementing xlsx-edit-agent or skill-xlsx-edit (deferred; openpyxl MCP only declared)
- Modifying filetypes-router-agent (editing bypasses the conversion router)
- Adding test infrastructure (no test directory exists in filetypes extension)
- Updating opencode-agents.json (low priority, separate task)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| SuperDoc npm package name unverified | H | M | Phase 1 verifies `npm show @superdoc-dev/mcp`; document fallback package names |
| AppleScript TCC permissions block Word automation | H | L | Document accessibility permission requirement in office-edit-patterns.md |
| Word `Document.Reload` unavailable on older versions | H | L | Agent falls back to close+reopen sequence; document version requirements |
| Partner types during SuperDoc edit window | L | M | Agent prints warning message before edit; window is 2-5 seconds |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Manifest and MCP Server Declarations [COMPLETED]

**Goal**: Update manifest.json with MCP servers and new component registrations, establishing the extension structure.

**Tasks**:
- [ ] Update `.claude/extensions/filetypes/manifest.json`:
  - Add `mcp_servers` block with `superdoc` (`npx -y @superdoc-dev/mcp`) and `openpyxl` (`npx -y @jonemo/openpyxl-mcp`) entries following founder extension pattern
  - Add `docx-edit-agent.md` to `provides.agents`
  - Add `skill-docx-edit` to `provides.skills`
  - Add `edit.md` to `provides.commands`
  - Bump version to `2.2.0`

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/filetypes/manifest.json` - Add MCP servers, register new components, bump version

**Verification**:
- manifest.json is valid JSON
- Both MCP server entries have `command`, `args`, `env` fields
- All three new components (agent, skill, command) listed in `provides`

---

### Phase 2: Context Files [COMPLETED]

**Goal**: Create the two new context documents that the agent will reference: SuperDoc tool inventory and Office editing workflow patterns.

**Tasks**:
- [ ] Create `.claude/extensions/filetypes/context/project/filetypes/tools/superdoc-integration.md`:
  - SuperDoc MCP server configuration (`npx @superdoc-dev/mcp`)
  - Complete tool inventory: `open_document`, `close_document`, `save_document`, `get_document_text`, `search_and_replace`, `search_and_replace_with_tracked_changes`, `add_paragraph`, `add_heading`, `add_table`, `create_document`
  - Fallback chain: SuperDoc -> python-docx -> fail with instructions
  - Comparison: markitdown (read-only) vs SuperDoc (read-write)
- [ ] Create `.claude/extensions/filetypes/context/project/filetypes/patterns/office-edit-patterns.md`:
  - 5-step Word integration workflow (check -> save -> edit -> reload -> confirm)
  - AppleScript commands for Word automation (check running, save, reload)
  - macOS advisory lock behavior (APFS, POSIX flock)
  - Tracked changes workflow with author attribution
  - OneDrive/SharePoint sync pause pattern
  - Edge cases: multiple docs open, Word not running, read-only mode, non-macOS platforms
  - Batch editing pattern (directory iteration, per-file reporting)
  - Document creation pattern (heading/paragraph/table composition)
- [ ] Update `.claude/extensions/filetypes/index-entries.json`:
  - Add entry for `superdoc-integration.md` with `load_when.agents: ["docx-edit-agent"]`, `load_when.commands: ["/edit"]`
  - Add entry for `office-edit-patterns.md` with same load_when
  - Add `"docx-edit-agent"` to existing tool-detection.md agent list
  - Add `"/edit"` to existing tool-detection.md and dependency-guide.md command lists

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/filetypes/context/project/filetypes/tools/superdoc-integration.md` - Create new (SuperDoc tool reference)
- `.claude/extensions/filetypes/context/project/filetypes/patterns/office-edit-patterns.md` - Create new (Office workflow patterns)
- `.claude/extensions/filetypes/index-entries.json` - Add 2 new entries, update existing entries

**Verification**:
- Both context files exist and contain all documented sections
- index-entries.json is valid JSON with correct load_when configurations
- `docx-edit-agent` appears in tool-detection.md's agent list

---

### Phase 3: Command and Skill [COMPLETED]

**Goal**: Create the `/edit` command file and `skill-docx-edit` skill that route user requests to the docx-edit-agent.

**Tasks**:
- [ ] Create `.claude/extensions/filetypes/commands/edit.md`:
  - Frontmatter: description, allowed-tools (`Skill, Bash(date:*), Bash(od:*), Bash(tr:*), Bash(test:*), Bash(dirname:*), Bash(basename:*), Bash(find:*), Read`), argument-hint
  - Arguments: `$1` file/directory path, `$2` natural language instruction, `--new` flag for creation
  - Usage examples covering all 4 workflows (edit, batch, create, spreadsheet future)
  - GATE IN logic: parse args, validate file exists (or --new), detect file type (.docx vs .xlsx)
  - Delegate to `skill-docx-edit` for .docx files
  - Future stub: delegate to `skill-xlsx-edit` for .xlsx (return error "xlsx editing not yet available")
  - GATE OUT: verify file modified, report summary
- [ ] Create `.claude/extensions/filetypes/skills/skill-docx-edit/SKILL.md`:
  - Frontmatter: name, description, `allowed-tools: Task`
  - Context pointers to subagent-return.md (lazy load)
  - Trigger conditions: `/edit` command with .docx file or directory of .docx files
  - Input validation: file path exists, is .docx (or directory for batch)
  - Context preparation: delegation JSON with file_path, instruction, session metadata
  - Agent invocation via Task tool to `docx-edit-agent`
  - Return validation against subagent-return.md schema
  - Status values: edited, created, partial, failed (never "completed")
  - MUST NOT section: no postflight, no return modification, no eager context loading

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/filetypes/commands/edit.md` - Create new (slash command)
- `.claude/extensions/filetypes/skills/skill-docx-edit/SKILL.md` - Create new (thin skill wrapper)

**Verification**:
- Command file has valid frontmatter with allowed-tools
- Skill file has `allowed-tools: Task` in frontmatter
- Skill delegates via Task tool (not Skill tool)
- All 4 guide workflows are covered in command usage examples

---

### Phase 4: Agent Implementation [COMPLETED]

**Goal**: Create the docx-edit-agent with the full 6-stage execution flow including SuperDoc MCP integration and AppleScript Word automation.

**Tasks**:
- [ ] Create `.claude/extensions/filetypes/agents/docx-edit-agent.md`:
  - Frontmatter: name, description
  - Agent metadata: name, purpose, invoked by, return format
  - Allowed tools: Read, Write, Edit, Glob, Grep, Bash (for AppleScript and SuperDoc)
  - Context references: superdoc-integration.md, office-edit-patterns.md, tool-detection.md, subagent-return.md
  - Stage 1: Parse delegation context (file_path, instruction, mode, session metadata)
  - Stage 2: Validate inputs (file exists or --new mode, .docx extension, check SuperDoc availability)
  - Stage 3: Detect tools (SuperDoc MCP available -> python-docx fallback -> fail with install instructions)
  - Stage 4: Execute edit workflow:
    - 4a: Check if Word is running and has file open (AppleScript on macOS; skip on other platforms)
    - 4b: If open, save partner's unsaved work via AppleScript
    - 4c: Perform SuperDoc operations (open_document, edit operations, save_document, close_document)
    - 4d: If Word had file open, trigger reload via AppleScript (`tell application "Microsoft Word" to reload active document`)
    - 4e: Confirm edit results (file modified, expected changes applied)
  - Stage 5: Validate output (file size changed, changes detectable)
  - Stage 6: Return JSON result with status, summary, artifacts, metadata
  - Batch mode: iterate .docx files in directory, apply instruction to each, aggregate results
  - Create mode: use `create_document`, `add_heading`, `add_paragraph`, `add_table`
  - Forced question pattern: ask about tracked changes preference and author name on first invocation
  - Non-macOS behavior: skip AppleScript steps, warn user to close document manually
  - Return status values: "edited", "created", "partial", "failed" (never "completed")

**Timing**: 1.5 hours

**Depends on**: 2, 3

**Files to modify**:
- `.claude/extensions/filetypes/agents/docx-edit-agent.md` - Create new (full agent definition)

**Verification**:
- Agent file has valid frontmatter
- All 6 stages documented with clear execution steps
- AppleScript commands match those in office-edit-patterns.md
- SuperDoc tool calls match those in superdoc-integration.md
- Return format matches subagent-return.md schema
- Forced question pattern included for tracked changes
- Both macOS and non-macOS paths documented

---

### Phase 5: Extension Documentation and Existing File Updates [COMPLETED]

**Goal**: Update EXTENSION.md, and existing context files (mcp-integration.md, conversion-tables.md, tool-detection.md) to integrate the new editing capability.

**Tasks**:
- [ ] Update `.claude/extensions/filetypes/EXTENSION.md`:
  - Add `skill-docx-edit | docx-edit-agent | In-place DOCX editing with tracked changes (SuperDoc MCP)` to skill-agent mapping table
  - Add `/edit | /edit file.docx "instruction" | Edit Office documents in-place` to commands table
- [ ] Update `.claude/extensions/filetypes/context/project/filetypes/tools/mcp-integration.md`:
  - Add SuperDoc MCP section alongside markitdown and pandoc
  - Document SuperDoc as read-write (vs markitdown read-only)
  - Include configuration snippet and tool list
- [ ] Update `.claude/extensions/filetypes/context/project/filetypes/domain/conversion-tables.md`:
  - Add "Edit Operations" section distinguishing in-place editing from format conversion
  - Document DOCX edit support with SuperDoc, future XLSX with openpyxl
- [ ] Update `.claude/extensions/filetypes/context/project/filetypes/tools/tool-detection.md`:
  - Add SuperDoc detection logic (`mcp_available("superdoc")` pattern)
  - Add python-docx fallback detection
  - Document the SuperDoc -> python-docx -> fail chain

**Timing**: 45 minutes

**Depends on**: 4

**Files to modify**:
- `.claude/extensions/filetypes/EXTENSION.md` - Add skill-agent mapping and command entry
- `.claude/extensions/filetypes/context/project/filetypes/tools/mcp-integration.md` - Add SuperDoc section
- `.claude/extensions/filetypes/context/project/filetypes/domain/conversion-tables.md` - Add edit operations section
- `.claude/extensions/filetypes/context/project/filetypes/tools/tool-detection.md` - Add SuperDoc detection

**Verification**:
- EXTENSION.md shows skill-docx-edit and /edit command
- mcp-integration.md has SuperDoc section with configuration
- conversion-tables.md distinguishes conversion from editing
- tool-detection.md includes SuperDoc in detection chain

---

## Testing & Validation

- [ ] All new files created in correct directories under `.claude/extensions/filetypes/`
- [ ] `manifest.json` is valid JSON and includes both MCP servers
- [ ] `index-entries.json` is valid JSON with correct load_when entries
- [ ] Command file `/edit` covers all 4 guide workflows in usage examples
- [ ] Skill file uses `allowed-tools: Task` and delegates via Task tool
- [ ] Agent file implements all 6 stages with AppleScript integration
- [ ] Agent handles macOS and non-macOS platforms gracefully
- [ ] Agent uses forced question pattern for tracked changes
- [ ] Context files cover all tool references and workflow patterns from research
- [ ] No modifications to `filetypes-router-agent` or existing `/convert` flow
- [ ] Return status values never include "completed"

## Artifacts & Outputs

New files (5):
- `.claude/extensions/filetypes/commands/edit.md`
- `.claude/extensions/filetypes/skills/skill-docx-edit/SKILL.md`
- `.claude/extensions/filetypes/agents/docx-edit-agent.md`
- `.claude/extensions/filetypes/context/project/filetypes/tools/superdoc-integration.md`
- `.claude/extensions/filetypes/context/project/filetypes/patterns/office-edit-patterns.md`

Updated files (6):
- `.claude/extensions/filetypes/manifest.json`
- `.claude/extensions/filetypes/index-entries.json`
- `.claude/extensions/filetypes/EXTENSION.md`
- `.claude/extensions/filetypes/context/project/filetypes/tools/mcp-integration.md`
- `.claude/extensions/filetypes/context/project/filetypes/domain/conversion-tables.md`
- `.claude/extensions/filetypes/context/project/filetypes/tools/tool-detection.md`

## Rollback/Contingency

All changes are within `.claude/extensions/filetypes/`. Rollback via `git checkout -- .claude/extensions/filetypes/` restores the pre-edit state. New files can be removed with `git clean -f .claude/extensions/filetypes/`. Existing conversion functionality (`/convert`, `/table`, `/slides`, `/scrape`) is not modified and will be unaffected.
