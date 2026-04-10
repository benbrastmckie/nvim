# Teammate D: Strategic Horizons
## Task 386 - Expand Filetypes Extension with SuperDoc MCP Integration

**Role**: Strategic Horizons - Long-term alignment, project direction, creative approaches
**Focus**: Best practices from existing extensions, patterns from founder/, extension portability, strategic fit

---

## Key Findings

### 1. The Extension Portability Question is the Critical Strategic Decision

The task description says the partner's Zed/Claude Code setup will be built from scratch (task 385 guide). The question is whether this extension can ship to the partner's machine.

**Current extension architecture is NOT portable out of the box.** Extensions live at:
```
~/.config/nvim/.claude/extensions/filetypes/
```

This is inside the user's Neovim configuration repository. The partner would need:
- A copy of just the `.claude/` subtree, or
- A separate repository with only the `.claude/` configuration, or
- The partner to clone the same Neovim config (not appropriate)

**Confidence**: High. Verified by reading the extension loading mechanism in CLAUDE.md and `<leader>ac` keybinding reference.

**Strategic implication**: If the goal is for the partner to benefit from this extension, we need a portability story. Three options (ranked by alignment with existing patterns):

1. **Distribute the extension as a standalone .claude/ directory** -- partner clones or copies just `.claude/extensions/filetypes/` into their own project's `.claude/extensions/`. This requires the extension to be self-contained (no cross-extension references). The filetypes extension already satisfies this (no dependencies in manifest.json).

2. **Build a companion "partner-office" extension** -- a thin extension in the partner's machine that contains only the new Office-specific components (docx-edit-agent, skill-docx-edit, workflow patterns). This would be the smallest possible footprint.

3. **Document manual setup** -- the partner follows instructions to register SuperDoc MCP via `claude mcp add --scope user` and uses Claude's native capabilities without any formal extension. This is what the task 385 guide already does.

**Key insight**: The task 385 guide takes option 3 -- it has the partner register MCP servers directly with Claude Code, not via an extension. The extension adds agent specialization and patterns that make Claude more capable and consistent, but it is not required for basic Office editing.

### 2. filetypes is Conversion; the New Work is Manipulation -- These are Different Concepts

Reviewing the existing filetypes extension architecture:
- All current commands (/convert, /table, /slides, /scrape) are **one-way extractions or conversions**
- The `document-agent` explicitly does NOT modify source files
- The mental model is: "transform file A into file B"

SuperDoc-based editing is:
- **In-place modification** of the source file
- **Stateful** (open -> edit -> save -> close lifecycle)
- **Reversibility-aware** (tracked changes vs direct)
- **Identity-preserving** (the file is still the same file)

These are genuinely different conceptual operations. The question is whether to:

**Option A: Extend filetypes with a new capability class ("edit")**
- Pros: One extension, partner loads one thing, filetypes-router handles both
- Cons: Breaks the clean conceptual model; "filetypes" becomes a misnomer

**Option B: Create a new "office" extension**
- Pros: Clean separation of concerns; "office" extension handles Office-specific workflows; filetypes stays pure conversion
- Cons: Two extensions to load; more overhead; task 386 description explicitly says to extend filetypes

**Assessment**: The task description says to extend filetypes. But architecturally, the right long-term home is a separate "office" extension. A pragmatic compromise is to implement the work inside filetypes (as directed) while naming things to allow future extraction: the new components (docx-edit-agent, skill-docx-edit) should be fully self-contained with no coupling to existing filetypes routing. This way, extraction to an "office" extension later is a mechanical operation.

**Confidence**: High for the architectural observation; Medium for the compromise approach.

### 3. founder/ Extension Reveals the Preferred Pattern: Forcing Functions + Domain Agents

Studying the founder extension, the key design philosophy is:
- **Forcing question pattern**: Agents ask the user clarifying questions before proceeding (see `forcing_data` references in EXTENSION.md)
- **Domain-specific agents** for each work type (market-agent, legal-council-agent, project-agent) rather than one general agent
- **Shared implementation agent** (founder-implement-agent) with type-aware dispatch

For the docx-edit use case, this suggests:
- The **docx-edit-agent** should ask clarifying questions before editing: "Should changes be tracked? What author name should appear in tracked changes? Do you want a backup copy first?"
- Consider a **SharePoint-aware variant** that knows to prompt: "Is this file synced with OneDrive? If so, please pause OneDrive sync before I proceed."

The founder extension also shows that **MCP servers are declared in manifest.json** with full configuration. This is the pattern to follow for SuperDoc and openpyxl.

**Confidence**: High. This is directly observable from founder/manifest.json and EXTENSION.md.

### 4. The "Document Proxy" Creative Approach Has Architectural Merit

A "document proxy" pattern would work as follows:
1. User asks to edit a .docx
2. docx-edit-agent extracts semantic structure via SuperDoc's `superdoc_get_content`
3. Agent edits semantically (understanding paragraphs, sections, tables as objects)
4. Agent applies changes back as tracked changes

This is essentially what SuperDoc enables natively -- it already models documents structurally, not as raw bytes. The agent design should lean into this: rather than treating a docx as "a file to modify", the agent should treat it as "a structured document with sections, tables, and formatting to manipulate."

**Implication for agent design**: The docx-edit-agent's context file (`patterns/docx-editing.md`) should document the semantic document model (not just tool names), including how to navigate to a specific paragraph, how to reference a table cell, and how tracked changes appear.

**Confidence**: Medium. Depends on SuperDoc's actual API surface, which is documented in task 385 research.

### 5. The Partner-Specific Context is the Unique Value

The task 385 guide is explicitly tuned to the partner's setup:
- macOS, not Linux
- Microsoft Word with tracked changes
- SharePoint/OneDrive for file sharing
- Non-technical user workflow (plain English prompts)

The extension should encode this domain knowledge as context files, not just as agent instructions. Specifically:
- `patterns/docx-editing.md` should include the OneDrive/SharePoint workflows
- The agent should know that `~/OneDrive/` and `~/Documents/` are the expected file locations
- The agent should default to tracked changes unless the user says otherwise (partner uses Word review workflow)

This "partner-specific context" is the long-term value: the agent gets smarter about this specific use case over time.

**Confidence**: High. This is the primary purpose of the extension system.

---

## Long-term Alignment Assessment

### Aligns With Project Direction

1. **Extension system maturation**: The project has been building out the extension system (founder, filetypes, latex, etc.) to encode domain knowledge. Adding SuperDoc support continues this trajectory and demonstrates that the system can handle real-world document workflows.

2. **Partner workflow**: The system already has a user (the partner) with specific needs (Office editing). This task is a direct response to that user's actual use case, which is stronger alignment than hypothetical capabilities.

3. **Meta-system patterns**: The agent system's philosophy is to build specialized agents with deep domain knowledge rather than general agents with broad knowledge. A dedicated docx-edit-agent follows this pattern well.

### Potential Misalignment

1. **Scope creep risk**: The task description lists many deliverables (new agent, new skills, updated manifests, new context files, SharePoint patterns). The risk is building a large surface area that becomes hard to maintain. Mitigation: keep each component minimal and focused.

2. **MCP dependency**: The extension will only work if SuperDoc MCP is registered. The filetypes extension currently has no MCP dependencies (CLI tools only). Adding MCP dependencies changes the operational profile. The manifest.json `mcp_servers` field exists (founder uses it) but the extension loader presumably needs to handle the case where the MCP server isn't available. Graceful degradation is important.

---

## Creative / Unconventional Approaches

### A. Hybrid Workflow: Extract-Edit-Merge

Rather than treating docx editing as a standalone operation, expose a workflow that bridges the user's text editing preference with Word's native format:

```
/edit-flow contract.docx
  Step 1: /convert contract.docx -> contract.md  (existing document-agent)
  Step 2: User edits contract.md in Zed
  Step 3: docx-edit-agent reads the diff between original.md and contract.md
  Step 4: Applies the diff as tracked changes to contract.docx via SuperDoc
```

This lets the user stay in Zed for editing while delivering a proper Word file with tracked changes. It is especially appropriate for the partner who prefers plain text editing but needs Word output.

**Feasibility**: Medium. Requires a diff-to-tracked-changes translation step, which is non-trivial but the 5-workflow architecture in task 385 hints at this (Workflow E).

### B. docx-edit-agent as Structured Document Editor (Format Agnostic)

The docx-edit-agent uses SuperDoc's semantic document model. In principle, the same patterns (find/replace, insert, tracked changes) could apply to any OOXML format (DOCX, XLSX, PPTX). SuperDoc focuses on DOCX; openpyxl covers XLSX.

A future "document workspace" concept could unify these under a single `/edit` command:
```
/edit contract.docx         -> routes to docx-edit-agent (SuperDoc)
/edit budget.xlsx           -> routes to xlsx-edit-agent (openpyxl)
/edit presentation.pptx     -> routes to pptx-edit-agent (future)
```

This is a natural extension of the existing `/convert` router pattern. The filetypes-router-agent already dispatches by format -- adding an "edit" operation type alongside "convert" is architecturally clean.

### C. OneDrive State Agent

A lightweight agent that knows how to:
- Detect if a file is in an OneDrive-synced folder
- Check if the file is locked (`lsof`)
- Pause/resume OneDrive sync

This could be invoked as a pre-flight check by the docx-edit-agent, making the SharePoint workflow invisible to the user ("I noticed this file is in OneDrive. I'll pause sync, edit, then resume sync automatically.").

**Feasibility**: High for macOS. `lsof` is available; OneDrive menu bar interaction is harder to script but pause via `killall OneDrive` / resume via `open -a OneDrive` is documented in task 385 research.

---

## Extension Portability Analysis

### Current State

The filetypes extension has `"dependencies": []` in manifest.json, making it theoretically portable. The extension loads context files via relative paths within the extension tree. Agents reference context via `@context/project/filetypes/...` which resolves relative to the extension root.

**Portability requires**: The extension to be copied to the target machine's `.claude/extensions/filetypes/` and loaded via the extension loader (`<leader>ac` equivalent on the partner's machine).

### Partner Machine Challenge

The partner's machine will have a fresh Claude Code installation (per the task 385 guide). The partner does NOT have a Neovim configuration. So `<leader>ac` (Neovim keybinding to load extensions) is not available.

**Options for partner portability**:

1. **Self-contained extension package**: Package the filetypes extension (or just the new Office components) as a directory that the partner copies to `~/.claude/extensions/filetypes/`. The partner would need a way to load extensions -- which means they need either a CLAUDE.md that imports the extension, or a standalone activation mechanism.

2. **Bake context into CLAUDE.md**: Rather than using the extension system, put the key agent instructions and patterns directly into the partner's `~/.claude/CLAUDE.md` or project-level `CLAUDE.md`. Simpler but less organized.

3. **MCP server registration + inline prompts**: The task 385 approach -- register SuperDoc MCP and rely on Claude's general capabilities. The agent specialization provided by the extension is valuable but not strictly necessary for the core workflows.

**Recommendation**: For the immediate task, build the extension in the standard way (inside filetypes). For partner portability, create a separate deliverable: a minimal `office/` extension or a standalone CLAUDE.md snippet that provides just the docx-edit-agent and workflow patterns in a form the partner can install without the full Neovim config system.

### Cross-Extension Dependencies

The filetypes extension has no cross-extension dependencies today. The founder extension's `spreadsheet-agent` duplicates some spreadsheet capability that also exists in filetypes -- this is intentional isolation. The pattern is: **no cross-extension dependencies**. Each extension is self-contained.

This means:
- docx-edit-agent should NOT reference founder extension context
- skill-docx-edit should be defined within the filetypes extension
- If openpyxl MCP logic is added, it goes inside filetypes (not imported from elsewhere)

**Confidence**: High. manifest.json `dependencies: []` and the duplication of spreadsheet-agent in both founder and filetypes confirms this design decision.

---

## Confidence Summary

| Finding | Confidence | Notes |
|---------|-----------|-------|
| Extension is NOT portable to partner without work | High | Verified architecture |
| filetypes (conversion) vs office editing are different concepts | High | Conceptual clarity |
| founder/ pattern: forcing questions + domain agents | High | Directly observable |
| Document proxy approach is valid | Medium | Depends on SuperDoc API |
| Partner-specific context is the long-term value | High | Clear use case |
| Hybrid extract-edit-merge workflow | Medium | Non-trivial implementation |
| OneDrive state agent feasibility | High | macOS tooling available |
| Cross-extension dependencies should be avoided | High | Design pattern confirmed |
| New work should be self-contained for future extraction | Medium | Pragmatic recommendation |
