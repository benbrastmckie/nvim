# Research Report: Task #386

**Task**: Expand filetypes extension with SuperDoc MCP integration and partner Office workflows
**Date**: 2026-04-09
**Mode**: Team Research (4 teammates)

## Summary

The filetypes extension can be expanded with SuperDoc MCP integration for in-place DOCX editing, following patterns already established by the founder and lean extensions for MCP server declaration. The key architectural insight is that DOCX editing is a fundamentally different operation from format conversion -- it should use a new `/edit` command with a direct skill-to-agent delegation (bypassing the filetypes router), following the precedent set by `skill-scrape` and `skill-spreadsheet`. The SuperDoc npm package availability is unverified and must be confirmed before implementation. xlsx editing via openpyxl MCP should be deferred to a separate task due to uncertain tooling. Task 384 (broken markitdown/document-agent) should be treated as a soft dependency.

## Key Findings

### 1. Filetypes Extension Architecture (High Confidence)

The filetypes extension v2.1.0 uses a three-tier delegation pattern for conversion:

```
Skill (thin wrapper, allowed-tools: Task)
  -> Router Agent (format detection + sub-agent selection)
    -> Specialized Sub-Agent (actual conversion)
```

Current components: `skill-filetypes` + `filetypes-router-agent` + `document-agent`, `skill-spreadsheet` + `spreadsheet-agent`, `skill-presentation` + `presentation-agent`, `skill-scrape` + `scrape-agent`.

**Critical gap**: All existing agents handle format conversion only. None handles in-place document editing.

**Key structural facts**:
- The manifest has `"language": null` and **no routing block** -- filetypes uses command-based invocation, not language-based routing
- Skills are thin wrappers with `allowed-tools: Task`
- Agent files follow a strict 6-stage structure (parse -> validate -> detect tools -> execute -> validate output -> return JSON)
- Return status values must NEVER be "completed" (triggers Claude stop behavior); use "edited", "partial", "failed"

### 2. Extension Pattern from founder/ (High Confidence)

The founder extension reveals the user's preferred patterns:

- **MCP servers declared in manifest.json** with `command`, `args`, `env` fields (no `scope` field)
- **Domain-specific agents** for each work type (market-agent, legal-council-agent, etc.)
- **Forcing question pattern**: agents ask clarifying questions before proceeding
- **Self-contained**: no cross-extension dependencies (founder duplicates spreadsheet-agent independently)

For docx-edit, this means:
- The agent should ask: "Should changes be tracked? What author name? Is this an OneDrive file?"
- SuperDoc should be declared in manifest.json `mcp_servers`, NOT in agent code
- All new components must be self-contained within filetypes

### 3. Routing Decision: Direct Invocation, Not Router (High Confidence)

**Consensus across teammates**: `skill-docx-edit` should invoke `docx-edit-agent` **directly**, bypassing `filetypes-router-agent`.

Evidence:
- `skill-scrape` invokes `scrape-agent` directly
- `skill-spreadsheet` invokes `spreadsheet-agent` directly
- Only `skill-filetypes` uses the router (for multi-format conversion)
- The router has no `operation_type` parameter and modifying it risks breaking existing `/convert` flows

**Decision**: Do NOT modify `filetypes-router-agent`. New editing skills bypass the router.

### 4. A New `/edit` Command is Required (High Confidence)

The filetypes extension has `"language": null` and no routing block -- skills are only reachable via commands. Without a `/edit` command file, `skill-docx-edit` is orphaned and uninvocable.

The existing command pattern (`/convert`, `/table`, `/slides`, `/scrape`) shows each command has a narrow, single-responsibility scope. `/edit` should handle in-place Office file editing, separate from `/convert`.

### 5. Agent Naming: `docx-edit-agent` vs `document-edit-agent` (Medium Confidence)

**Conflict**: Teammate A proposes `docx-edit-agent` (format-specific); Teammate C argues for `document-edit-agent` (domain-based, matching `document-agent` convention).

**Resolution**: Use `docx-edit-agent` because SuperDoc only handles DOCX, not PDF/HTML/other document formats. The naming signals the format specificity accurately. If a future multi-format edit agent emerges, it can be named `document-edit-agent` at that time. Document this rationale in the agent file.

### 6. Tool Fallback Chain is Mandatory (High Confidence)

Every existing filetypes agent implements: primary MCP -> CLI fallback -> error. SuperDoc integration must follow:

```
if superdoc MCP available: use SuperDoc MCP tools
  else if python-docx available: use python-docx for basic edits (no tracked changes)
    else: fail with installation instructions
```

### 7. SuperDoc npm Package Availability is Unverified (Critical Risk)

The research cites GitHub, docs, and changelog but no npm registry confirmation that `npx @superdoc-dev/mcp` actually works. If the package is not published, the entire integration collapses.

**Required**: Verify `npm show @superdoc-dev/mcp` as Phase 1 of implementation. If unavailable, fall back to `dvejsada/mcp-ms-office-documents` (Docker-based, confirmed active) or python-docx script approach.

### 8. Context File Organization (High Confidence)

New context files follow the established pattern:

| File | Location | Purpose |
|------|----------|---------|
| `superdoc-integration.md` | `context/project/filetypes/tools/` | MCP server config, tool inventory, API reference |
| `office-edit-patterns.md` | `context/project/filetypes/patterns/` | Tracked changes workflows, SharePoint patterns, batch operations |

Each needs an `index-entries.json` entry scoped to the new agent.

### 9. xlsx Editing Should Be Deferred (High Confidence)

**Consensus**: The openpyxl MCP package name (`@jonemo/openpyxl-mcp`) is unverified. The existing `spreadsheet-agent` already uses openpyxl via Python directly. xlsx editing via MCP adds uncertain dependency for marginal benefit.

**Decision**: Defer xlsx-edit to a separate task. The partner can use Claude's native capabilities with openpyxl Python scripts for spreadsheet editing (already documented in task 385 guide).

### 10. Partner Extension Portability (Medium Confidence)

The extension lives inside the user's Neovim config repo. The partner doesn't have Neovim. Three portability options:

1. Copy `.claude/extensions/filetypes/` to partner's `.claude/extensions/` (requires extension loader)
2. Create a minimal standalone `office/` extension for the partner
3. Rely on direct MCP registration (what task 385 guide already does)

**Decision**: Build correctly inside filetypes first. Keep new components self-contained and decoupled from existing conversion routing, enabling future extraction. Partner portability is a separate deliverable.

## Synthesis

### Conflicts Resolved

1. **Direct invocation vs router extension**: Teammates A and B initially disagreed (A: bypass router; B: extend router with `operation` field). Resolved in favor of direct invocation based on existing precedent (`skill-scrape`, `skill-spreadsheet`) and risk of breaking existing `/convert` flows.

2. **Agent naming (`docx-edit-agent` vs `document-edit-agent`)**: Teammate C advocated domain-based naming for consistency. Resolved as `docx-edit-agent` because SuperDoc is DOCX-only; the name accurately reflects scope.

3. **Expand filetypes vs new extension**: Teammates B and D noted the conceptual difference between conversion and editing. Resolved: extend filetypes as directed, but keep new components decoupled for future extraction.

### Gaps Identified

1. **No `/edit` command file** in task description -- required for invocability
2. **EXTENSION.md update** not mentioned -- needed for skill-agent mapping table
3. **index-entries.json update** not mentioned -- needed for context discovery
4. **opencode-agents.json update** not mentioned -- needed for OpenCode compatibility
5. **Test plan** absent -- no test fixtures or integration test strategy
6. **Task 384 dependency** -- broken markitdown/document-agent creates incoherent UX

### Recommendations

**Components to create (in priority order)**:

| Priority | Component | File |
|----------|-----------|------|
| HIGH | `/edit` command | `.claude/extensions/filetypes/commands/edit.md` |
| HIGH | `skill-docx-edit` | `.claude/extensions/filetypes/skills/skill-docx-edit/SKILL.md` |
| HIGH | `docx-edit-agent` | `.claude/extensions/filetypes/agents/docx-edit-agent.md` |
| HIGH | SuperDoc context | `.claude/extensions/filetypes/context/project/filetypes/tools/superdoc-integration.md` |
| HIGH | Edit patterns context | `.claude/extensions/filetypes/context/project/filetypes/patterns/office-edit-patterns.md` |
| HIGH | manifest.json update | Add `superdoc` to `mcp_servers`, new agents/skills to `provides` |
| HIGH | index-entries.json | Register new context files |
| MEDIUM | mcp-integration.md update | Add SuperDoc entry |
| MEDIUM | conversion-tables.md update | Add editing operations table |
| MEDIUM | EXTENSION.md update | Add skill-agent mapping |
| LOW | opencode-agents.json | Add docx-edit-agent entry |

**Explicitly out of scope**:
- xlsx editing via openpyxl MCP (defer to separate task)
- Partner-specific extension packaging (separate deliverable)
- filetypes-router-agent modification (editing bypasses router)
- Test infrastructure (no test directory exists in extension)

## Teammate Contributions

| Teammate | Angle | Status | Confidence | Key Contribution |
|----------|-------|--------|------------|------------------|
| A | Primary patterns | Completed | High | 3-tier architecture analysis, direct invocation decision, full component inventory |
| B | Alternative approaches | Completed | High | Convert vs edit distinction, tool fallback chain, /edit command necessity, context storage locations |
| C | Critic | Completed | High | SuperDoc npm risk, missing /edit command, naming inconsistency, task 384 dependency, scope concerns |
| D | Strategic horizons | Completed | High | Extension portability analysis, founder patterns (forcing questions), conversion vs manipulation concepts, partner-specific context value |

## References

### Existing Extension Files Studied
- `.claude/extensions/filetypes/manifest.json` - Extension configuration
- `.claude/extensions/filetypes/agents/document-agent.md` - Conversion agent pattern
- `.claude/extensions/filetypes/agents/filetypes-router-agent.md` - Router pattern
- `.claude/extensions/filetypes/skills/skill-scrape/SKILL.md` - Direct invocation pattern
- `.claude/extensions/filetypes/skills/skill-spreadsheet/SKILL.md` - Direct invocation pattern
- `.claude/extensions/filetypes/context/project/filetypes/tools/mcp-integration.md` - MCP config docs
- `.claude/extensions/filetypes/context/project/filetypes/domain/conversion-tables.md` - Format tables
- `.claude/extensions/filetypes/index-entries.json` - Context discovery index
- `.claude/extensions/founder/manifest.json` - MCP server declaration pattern
- `.claude/extensions/founder/EXTENSION.md` - Skill-agent mapping pattern
- `.claude/extensions/lean/manifest.json` - MCP server pattern

### Task 385 Research
- `specs/385_research_zed_ide_installation/reports/01_team-research.md` - SuperDoc recommendation, MCP landscape
- `specs/385_research_zed_ide_installation/reports/02_superdoc-workflows.md` - SuperDoc tools, 5 workflows, SharePoint mitigation
