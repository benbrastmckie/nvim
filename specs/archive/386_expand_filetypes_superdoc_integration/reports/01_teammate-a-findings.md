# Teammate A Findings: Primary Patterns for SuperDoc/openpyxl MCP Integration

**Task**: 386 — Expand filetypes extension with SuperDoc MCP integration and partner Office workflows
**Teammate**: A — Primary Approach
**Focus**: Existing extension patterns + new component identification
**Date**: 2026-04-09

---

## Key Findings

### 1. Filetypes Extension Architecture (High Confidence)

The filetypes extension version 2.1.0 uses a **three-tier delegation pattern**:

```
Skill (thin wrapper)
  -> Router Agent (format detection + sub-agent selection)
    -> Specialized Sub-Agent (actual conversion/manipulation)
```

**Current components**:
- `skill-filetypes` + `filetypes-router-agent` + `document-agent` (DOCX/PDF -> Markdown, Markdown -> PDF)
- `skill-spreadsheet` + `spreadsheet-agent` (XLSX/CSV -> LaTeX/Typst tables)
- `skill-presentation` + `presentation-agent` (PPTX -> Beamer/Polylux/Touying)
- `skill-scrape` + `scrape-agent` (PDF annotation extraction)

**Critical gap**: All existing agents handle **format conversion** (one format to another). None handles **in-place document editing** (find/replace, tracked changes, content manipulation within .docx/.xlsx).

### 2. Extension Pattern Analysis (High Confidence)

**From `filetypes` extension** (the base we're extending):

1. **Skill files are thin wrappers** with `allowed-tools: Task` — they validate input, set up delegation context, invoke the agent via Task tool, validate return, and propagate result. Context is loaded lazily by the sub-agents, not the skill.

2. **Agent files follow a strict stage structure**:
   - Stage 1: Parse Delegation Context (extract JSON from input)
   - Stage 2: Validate Inputs (file exists, format supported)
   - Stage 3: Detect Available Tools (CLI + Python package checks)
   - Stage 4: Execute Operation
   - Stage 5: Validate Output
   - Stage 6: Return Structured JSON

3. **Return format is always JSON** with fields: `status`, `summary`, `artifacts`, `metadata`, `next_steps`, and optional `errors`.

4. **Status values**: `converted`, `extracted`, `partial`, `failed` — NEVER "completed" (triggers Claude stop behavior).

5. **Context files** are organized into `domain/`, `patterns/`, and `tools/` subdirectories:
   - `domain/` — reference tables, matrices (e.g., conversion-tables.md)
   - `patterns/` — how-to guides for specific operations (e.g., spreadsheet-tables.md)
   - `tools/` — tool detection, dependency guides, MCP integration docs

6. **MCP servers declared in manifest.json**: The `mcp_servers` field currently is `{}` (empty) for filetypes. The founder extension uses this field for `sec-edgar` and `firecrawl`.

**From `founder` extension** (user's preferred pattern for richer skills):

1. **Skills can have richer postflight**: The founder `skill-spreadsheet` has `allowed-tools: Task, Bash, Edit, Read, Write` (not just `Task`) and handles status updates, artifact linking, and git commit internally. This "skill-internal postflight" pattern is used for interactive/research skills.

2. **Forcing questions pattern**: founder agents use `AskUserQuestion` in a one-at-a-time mode. This is used for ESTIMATE/BUDGET/FORECAST mode selection in cost breakdowns. Not directly applicable to docx-edit, but the interactive pattern exists.

3. **Routing structure**: The founder manifest uses a `"routing"` field with `research`/`plan`/`implement` sub-keys mapping language variants to skills. The filetypes extension has NO routing field — it uses a different invocation model (command-based, not task-language-based).

4. **`mcp_servers` in manifest with env vars**: Founder uses `"env": {"FIRECRAWL_API_KEY": "${FIRECRAWL_API_KEY}"}`. For SuperDoc (no API key needed), env can be `{}`.

5. **Early metadata initialization**: Founder agents create a `.return-meta.json` file immediately on start (Stage 0). This prevents loss of progress on interruption. The filetypes agents do NOT use this pattern — they return JSON directly. Given the new `docx-edit-agent` will be interactive and longer-running, early metadata may be appropriate.

### 3. What the Research Reports Say is Needed (High Confidence)

From `specs/385_research_zed_ide_installation/reports/02_superdoc-workflows.md`:

**New components explicitly identified**:

1. **`skill-docx-edit`** (new skill)
   - Location: `.claude/extensions/filetypes/skills/skill-docx-edit/SKILL.md`
   - Purpose: Route DOCX editing to `docx-edit-agent`
   - MCP dependency: SuperDoc must be registered
   - Trigger patterns: "edit document", "tracked changes", "find/replace in docx"

2. **`docx-edit-agent`** (new agent)
   - Location: `.claude/extensions/filetypes/agents/docx-edit-agent.md`
   - Purpose: Execute DOCX editing via SuperDoc MCP tools
   - Operations: find/replace, tracked changes, comments, tables, batch, template population
   - Tools: SuperDoc MCP (superdoc_open, superdoc_search, superdoc_replace, etc.)

3. **`skill-xlsx-edit`** (optional, lower priority)
   - Location: `.claude/extensions/filetypes/skills/skill-xlsx-edit/SKILL.md`
   - MCP dependency: openpyxl MCP server (`@jonemo/openpyxl-mcp`)

4. **`xlsx-edit-agent`** (optional, lower priority)
   - Location: `.claude/extensions/filetypes/agents/xlsx-edit-agent.md`
   - Purpose: Execute XLSX cell/row/formula editing via openpyxl MCP

**Context updates identified**:
- Update `mcp-integration.md` with SuperDoc + openpyxl MCP entries
- Create new `patterns/docx-editing.md` with tracked changes patterns, SharePoint workflows
- Update `domain/conversion-tables.md` to add editing operations table

**Manifest updates**:
- Add `superdoc` (and optionally `openpyxl`) to `mcp_servers`
- Add new agents/skills to `provides`

**Router updates**:
- Add `operation_type == "edit" AND format == "docx"` routing branch to `filetypes-router-agent`

### 4. Routing Model Decision (High Confidence)

There is an architectural choice: should DOCX editing go through `filetypes-router-agent`, or should `skill-docx-edit` invoke `docx-edit-agent` directly (bypassing the router)?

**Evidence**:
- `skill-scrape` invokes `scrape-agent` directly (not via router) — see SKILL.md: `subagent_type: "scrape-agent"`
- `skill-spreadsheet` invokes `spreadsheet-agent` directly (not via router)
- Only `skill-filetypes` uses the router (because it handles multiple formats)

**Decision**: `skill-docx-edit` should invoke `docx-edit-agent` **directly**, not through the router. The router is for conversion routing only. Editing is a dedicated skill.

### 5. `filetypes-router-agent` Extension Decision (Medium Confidence)

The router currently handles only conversion. The research report proposes adding an edit routing branch. However:

- The router currently has no `operation_type` parameter in its input schema
- Adding `operation_type` would require updating all callers and the router's delegation context schema
- The simpler approach is a separate `skill-docx-edit` skill that bypasses the router entirely

**Recommendation**: Do NOT modify `filetypes-router-agent`. The direct invocation pattern is already used by `skill-scrape` and `skill-spreadsheet`. This keeps concerns separated.

### 6. MCP Server Declaration in manifest.json (Medium Confidence)

The existing filetypes `manifest.json` has `"mcp_servers": {}`. The founder extension shows the pattern for declaring MCP servers:

```json
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
}
```

**Key question**: Is the `-y` flag appropriate for `npx` here? The founder extension uses `-y` for `firecrawl-mcp`. This flag auto-confirms install prompts and is correct for `npx`-based MCP servers that may not be cached.

**Concern from research report**: SuperDoc may not yet be published to npm as `@superdoc-dev/mcp`. This should be validated. If the package name differs, the `args` array needs updating.

### 7. New Context File: `patterns/docx-editing.md` (High Confidence)

Based on the research report's Section 4 (workflows) and Section 5 (SharePoint mitigation), this file should contain:

- SuperDoc MCP tool lifecycle pattern (open → search → edit → save → close)
- Tracked changes workflow (with `--change-mode tracked`)
- SharePoint file locking strategies (pause-edit-resume, copy-edit-replace, close-word-first)
- Batch operations with `expectedRevision` for atomicity
- Text anchoring vs paragraph index (use text anchors; paragraph indices are unstable)
- Template population pattern

### 8. openpyxl MCP for xlsx-edit (Medium Confidence)

The openpyxl MCP server (`@jonemo/openpyxl-mcp`) is listed as the recommended approach for XLSX editing. However:

- The existing `spreadsheet-agent` already uses openpyxl (via `python3 -c "import openpyxl"`)
- The difference is direct Python vs MCP-wrapped access
- The research report says "Option 2: Python script via Bash (fallback)" — implying the MCP is preferable but scripted openpyxl is an acceptable fallback

For the `xlsx-edit-agent`, the pattern should be:
1. Check if openpyxl MCP server is registered → use MCP tools
2. Fallback: write + execute Python script via Bash using `import openpyxl`

This is consistent with existing tool-detection patterns (MCP → CLI → Python package fallback chain).

---

## Recommended Approach

### Files to Create

| File | Priority | Purpose |
|------|----------|---------|
| `.claude/extensions/filetypes/agents/docx-edit-agent.md` | HIGH | Core editing agent using SuperDoc MCP |
| `.claude/extensions/filetypes/skills/skill-docx-edit/SKILL.md` | HIGH | Thin wrapper routing to docx-edit-agent |
| `.claude/extensions/filetypes/context/project/filetypes/patterns/docx-editing.md` | HIGH | SuperDoc workflows, SharePoint patterns, tracked changes |
| `.claude/extensions/filetypes/agents/xlsx-edit-agent.md` | MEDIUM | XLSX editing via openpyxl MCP |
| `.claude/extensions/filetypes/skills/skill-xlsx-edit/SKILL.md` | MEDIUM | Thin wrapper routing to xlsx-edit-agent |

### Files to Modify

| File | Change | Priority |
|------|--------|----------|
| `.claude/extensions/filetypes/manifest.json` | Add SuperDoc + openpyxl to `mcp_servers`; add new agents/skills to `provides` | HIGH |
| `.claude/extensions/filetypes/context/project/filetypes/tools/mcp-integration.md` | Add SuperDoc + openpyxl MCP server entries with configuration examples | HIGH |
| `.claude/extensions/filetypes/context/project/filetypes/domain/conversion-tables.md` | Add editing operations table (DOCX edit, XLSX edit) | HIGH |
| `.claude/extensions/filetypes/index-entries.json` | Add index entries for new context files + new agent context loads | HIGH |
| `.claude/extensions/filetypes/EXTENSION.md` | Add new skill-agent entries to the mapping table | MEDIUM |

### What NOT to Change

- `filetypes-router-agent.md` — editing bypasses the router
- `document-agent.md` — conversion-only; editing is a separate concern
- `spreadsheet-agent.md` — table conversion; xlsx editing is separate
- Existing skill files — no modification needed

---

## Evidence/Examples

### Pattern: Skill thin wrapper (from skill-scrape/SKILL.md)

```
---
name: skill-scrape
description: PDF annotation extraction routing
allowed-tools: Task
---
```

Skills are named in SKILL.md frontmatter with `allowed-tools: Task`. The new `skill-docx-edit` should follow this pattern.

### Pattern: Agent frontmatter (from document-agent.md)

```
---
name: document-agent
description: Convert documents between formats (PDF/DOCX to Markdown, Markdown to PDF)
---
```

Agents have a name and description in frontmatter. No `mcp-servers` field in filetypes agents (unlike founder agents which have `mcp-servers: []`). For `docx-edit-agent`, we should likely add `mcp-servers: [superdoc]` in frontmatter to indicate the dependency.

### Pattern: MCP servers in manifest (from founder/manifest.json)

```json
"mcp_servers": {
  "sec-edgar": {
    "command": "npx",
    "args": ["-y", "@stefanoamorelli/sec-edgar-mcp"],
    "env": {}
  }
}
```

### Pattern: Direct agent invocation in skill (from skill-spreadsheet/SKILL.md)

```
### 3. Invoke Agent
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "spreadsheet-agent"
  - description: "Convert {source_path} to {output_format} table"
```

The `skill-docx-edit` should follow the same direct invocation pattern.

### Pattern: Return status values (from document-agent.md)

```
MUST NOT:
6. Return the word "completed" as a status value (triggers Claude stop behavior)
```

The `docx-edit-agent` should use `"edited"`, `"partial"`, or `"failed"` — NOT "completed".

### Pattern: Tool detection chain (from tool-detection.md)

```bash
# Check Python package
has_openpyxl=$(python3 -c "import openpyxl" 2>/dev/null && echo "yes" || echo "no")
```

For SuperDoc MCP detection:
```bash
# Check if SuperDoc MCP is registered with Claude Code
claude mcp list 2>/dev/null | grep -q "superdoc" && echo "yes" || echo "no"
```

### Routing Decision Evidence (from skill-scrape/SKILL.md)

```
### 3. Invoke Agent
...
subagent_type: "scrape-agent"    # direct — NOT via filetypes-router-agent
```

This confirms the precedent: specialized skills invoke their agents directly.

---

## Confidence Summary

| Finding | Confidence | Reasoning |
|---------|-----------|-----------|
| Current architecture (3-tier delegation) | High | Read all existing agents/skills |
| New components needed (docx-edit + xlsx-edit) | High | Explicitly specified in research reports |
| Direct invocation (skip router) | High | scrape and spreadsheet skills both do this |
| MCP declaration format in manifest | High | Founder extension provides clear example |
| `docx-editing.md` content | High | Research report Section 4-5 provides detail |
| openpyxl MCP server name `@jonemo/openpyxl-mcp` | Medium | From research report; should be verified |
| SuperDoc npm package name `@superdoc-dev/mcp` | Medium | Research report warns it may not be published |
| Whether to add routing field to manifest.json | Medium | Filetypes has no routing field; may not need one |
| xlsx-edit priority vs docx-edit | High | Research report calls xlsx-edit "optional" |
