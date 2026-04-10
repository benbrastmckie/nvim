# Teammate B Findings: Alternative Patterns for SuperDoc MCP Integration

**Task**: 386 - Expand filetypes extension with SuperDoc MCP integration and partner Office workflows
**Role**: Teammate B - Alternative Approaches
**Focus**: Prior art, routing patterns, architectural alternatives

---

## Key Findings

### Finding 1: MCP Servers Belong in manifest.json, Not in Agent Code

**Confidence**: HIGH

The system already has a clear pattern for how MCP servers are wired. Looking at the lean and founder extensions:

```json
// lean/manifest.json
"mcp_servers": {
  "lean-lsp": {
    "command": "npx",
    "args": ["-y", "lean-lsp-mcp@latest"]
  }
}

// founder/manifest.json
"mcp_servers": {
  "sec-edgar": { "command": "npx", "args": [...] },
  "firecrawl":  { "command": "npx", "args": [...], "env": { "FIRECRAWL_API_KEY": "..." } }
}
```

The filetypes extension currently has `"mcp_servers": {}` (empty) in its manifest.json. SuperDoc should be wired there, not inside agent logic. This keeps the config declarative and lets the extension loader handle server lifecycle.

A key constraint: **custom subagents cannot access project-scoped MCP servers (`.mcp.json`)** — they can only use user-scope servers (`~/.claude.json`). The README.md documents this explicitly. SuperDoc must be configured at user scope for agents to use it.

---

### Finding 2: "Convert vs. Edit" Are Fundamentally Different Operations

**Confidence**: HIGH

The current `filetypes-router-agent` routing table maps exclusively on source-format -> target-format conversion:

```
PDF/DOCX -> Markdown   => document-agent
XLSX/CSV -> LaTeX      => spreadsheet-agent
PPTX -> Beamer         => presentation-agent
```

Partner Office workflows require a *different* operation model: **edit-in-place** (open a DOCX with track changes, apply edits, save). This is not a format conversion — the source and destination format are the same. The router's current logic cannot distinguish:

- "Convert report.docx to report.md" (document-agent)
- "Edit report.docx: fix the grammar in section 2" (office-edit-agent, new)

**Recommended routing discriminator**: Add an `operation` field to the delegation context:
- `operation: "convert"` -> existing routing
- `operation: "edit"` -> new office-edit-agent routing

Without this, a new `/edit` command should set `operation: "edit"` so the router selects the correct sub-agent instead of trying to find a format-to-format match.

---

### Finding 3: Separate Extension vs. Expanding Filetypes

**Confidence**: MEDIUM-HIGH

The founder extension sets a strong precedent for how capability domains should be scoped. It has:
- 14 agents, each with a narrow purpose
- 14 skills (one-to-one with agents)
- 9 commands

The filetypes extension is much leaner: 5 agents, 4 skills, 4 commands — all centered on format *conversion*. SuperDoc capabilities are distinct:
- Reading DOCX/XLSX with structural awareness (tracked changes, formulae)
- Writing DOCX with formatting preserved
- SharePoint-aware operations

**Alternative A: Expand filetypes extension**
- Add `superdoc` to filetypes `manifest.json` `mcp_servers`
- Add new agents inside filetypes (`office-read-agent`, `office-edit-agent`)
- Extend the router with `operation: "edit"` routing

**Alternative B: Create separate `office` extension**
- Mirrors the founder extension model: new manifest, new agents, new commands
- Cleaner separation; `filetypes` stays pure-conversion
- Requires an `office` language key in routing

**Recommendation**: Expand filetypes. The partner workflows are intimate with the existing filetypes skillset (the same tools—markitdown, pandoc—are involved in read paths). A separate extension makes sense only if Office edit workflows grow to be a standalone domain (many commands, distinct language). At launch, keeping it co-located reduces wiring overhead and keeps the user-facing surface simpler.

---

### Finding 4: Operation Dispatch Pattern (Thin Wrapper + Router)

**Confidence**: HIGH

The filetypes extension uses a two-level delegation pattern that is already proven:

```
Command (/convert)
  -> skill-filetypes  (thin wrapper: validates, sets context)
    -> filetypes-router-agent  (detects format, selects sub-agent)
      -> document-agent | spreadsheet-agent | presentation-agent
```

This same pattern should apply to Office edit workflows:

```
Command (/edit)  [new]
  -> skill-office  [new]  (validates source path, operation type)
    -> filetypes-router-agent  (extended: routes by operation field)
      -> office-edit-agent  [new]  (uses SuperDoc MCP)
```

Alternatively, a dedicated `office-router-agent` could be used instead of extending the existing router. But since the existing router already handles the format detection cleanly, extending it with an `operation` field is simpler than a whole new router.

---

### Finding 5: Single Agent vs. Separate docx/xlsx Agents

**Confidence**: MEDIUM

Looking at how agents are currently split:
- `document-agent` handles PDF, DOCX, HTML, Markdown — multiple formats, unified around "text documents"
- `spreadsheet-agent` handles XLSX, CSV, ODS — unified around "tabular data"

The same pattern would suggest:
- `office-edit-agent`: handles DOCX/XLSX edits (both are "Office file edits")

However, DOCX edits (tracked changes, commenting, paragraph formatting) and XLSX edits (formula management, cell ranges, named tables) are different enough that separate agents may be warranted if SuperDoc exposes distinct tool surfaces for each. If the MCP API is unified (same tools work on both), one agent is fine.

**Recommended pattern**: Start with one `office-edit-agent`. If it grows beyond ~300 lines or the DOCX vs. XLSX branches are larger than 50% of the code, split into `docx-edit-agent` and `xlsx-edit-agent`.

---

### Finding 6: Tool Detection Fallback Pattern Already Exists

**Confidence**: HIGH

Every existing filetypes agent follows this exact fallback pattern (from `document-agent.md`):

```
if MCP server available: use MCP server
  else if CLI tool available: use CLI fallback
    else: fail with installation instructions
```

The `context/project/filetypes/tools/tool-detection.md` file provides shared tool detection patterns. SuperDoc MCP should follow this same pattern:

```
if superdoc MCP available: use superdoc MCP tools
  else if python-docx available: use python-docx for basic edit
    else if markitdown available: use markitdown for read-only extraction
      else: fail with installation instructions
```

This degrades gracefully. A partner without SuperDoc configured still gets a read-only workflow using existing tools.

---

### Finding 7: The /convert Command Should NOT Be Extended

**Confidence**: HIGH

Looking at the `/convert` command design, it explicitly documents:
> "For spreadsheet-to-table conversions, use /table. For presentation conversions, use /slides."

This scoping pattern is intentional — each command has a narrow purpose. The `/convert` command should remain pure-conversion (format A to format B). Office editing should be a new `/edit` command. Mixing them would violate the single-responsibility principle already established by the existing commands.

---

### Finding 8: Context Storage Location for Office Patterns

**Confidence**: HIGH

Per the extension-slim-standard, context files go in:
```
.claude/extensions/filetypes/context/project/filetypes/
  tools/          # SuperDoc MCP config, API docs
  patterns/       # Office edit workflow patterns
  domain/         # Tracked changes concepts, SharePoint structure
```

New files needed:
- `tools/superdoc-integration.md` - MCP server config, available tools, API reference
- `patterns/office-edit-patterns.md` - tracked-changes patterns, format-preserving edit patterns
- `domain/office-file-structure.md` - DOCX XML structure, XLSX workbook model (for agent reference)

Each needs an `index-entries.json` entry scoped to `office-edit-agent`.

---

## Recommended Approach

**Expand the filetypes extension** with SuperDoc MCP using this architecture:

1. **Add SuperDoc to `filetypes/manifest.json` `mcp_servers`** (declarative wiring, user-scope only)
2. **Add `operation` field to router delegation context** (`"convert"` | `"edit"`)
3. **Extend `filetypes-router-agent`** with an `operation: "edit"` branch routing to `office-edit-agent`
4. **Create `office-edit-agent`** using the thin-wrapper pattern, with SuperDoc MCP as primary and python-docx as fallback
5. **Create a `/edit` command** that sets `operation: "edit"` and validates Office file paths
6. **Create `skill-office`** as the thin wrapper invoking the router for edit operations
7. **Add context files** in `tools/superdoc-integration.md` and `patterns/office-edit-patterns.md`
8. **Register all new context files** in `index-entries.json`

**What NOT to do**:
- Do not extend `/convert` with edit operations
- Do not create a new `office` extension (premature separation)
- Do not wire SuperDoc in agent code rather than manifest.json
- Do not create a second router agent (extend the existing one)

---

## Evidence / Examples

### Founder Extension MCP Pattern (manifest.json)

```json
"mcp_servers": {
  "sec-edgar": {
    "command": "npx",
    "args": ["-y", "@stefanoamorelli/sec-edgar-mcp"],
    "env": {}
  },
  "firecrawl": {
    "command": "npx",
    "args": ["-y", "firecrawl-mcp"],
    "env": {
      "FIRECRAWL_API_KEY": "${FIRECRAWL_API_KEY}"
    }
  }
}
```

SuperDoc would follow the same pattern. Environment variable injection supports API keys.

### Current Router Routing Table (filetypes-router-agent.md)

```
if source in [pdf, docx, html, images] AND target == markdown:
  -> document-agent

if source == markdown AND target == pdf:
  -> document-agent

if source in [xlsx, csv, ods] AND target in [latex, typst, markdown]:
  -> spreadsheet-agent

if source == pptx AND target in [latex, typst]:
  -> presentation-agent
```

Extension would add:

```
if operation == "edit" AND source in [docx, xlsx]:
  -> office-edit-agent
```

### Tool Fallback Chain Pattern (from document-agent.md)

```bash
# Primary: markitdown (if available)
markitdown "$source_path" > "$output_path"

# Fallback: pandoc (if markitdown unavailable)
pandoc -f docx -t markdown -o "$output_path" "$source_path"
```

Office edit agent would mirror this:

```bash
# Primary: SuperDoc MCP
use mcp__superdoc__edit_document(...)

# Fallback: python-docx
python3 -c "from docx import Document; ..."

# Read-only fallback: markitdown extraction
markitdown "$source_path" > "$tmp_path"
```

---

## Confidence Summary

| Finding | Confidence | Basis |
|---------|------------|-------|
| MCP servers in manifest.json | HIGH | Explicit pattern in lean/founder extensions |
| Convert vs. Edit distinction | HIGH | Router logic analysis, command design principles |
| Expand filetypes vs. new extension | MEDIUM-HIGH | Scope analysis, founder comparison |
| Operation dispatch pattern | HIGH | Existing two-level delegation confirmed |
| Single vs. split docx/xlsx agents | MEDIUM | Depends on SuperDoc API surface |
| Tool detection fallback | HIGH | Used in all 4 existing filetypes agents |
| Don't extend /convert | HIGH | Single-responsibility established by /table, /slides split |
| Context file locations | HIGH | extension-slim-standard.md explicit guidance |
