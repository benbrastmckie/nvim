# Teammate C Findings: Critic Analysis
# Task 386: Expand Filetypes Extension with SuperDoc MCP Integration

**Date**: 2026-04-09
**Role**: Teammate C - The Critic
**Focus**: Gaps, shortcomings, and blind spots in the task description and proposed approach

---

## Key Findings

### Finding 1: The filetypes manifest has NO routing block (HIGH CONFIDENCE)

The `founder/manifest.json` has a top-level `"routing"` key with research/plan/implement routing tables. The `filetypes/manifest.json` has **no routing block at all**. This means filetypes is not a language-based routing extension — it provides commands directly (`/convert`, `/table`, `/slides`, `/scrape`) rather than routing via `/research` / `/plan` / `/implement` language dispatch.

**Impact**: The task description's framing of adding `skill-docx-edit` as a routed skill in the manifest may be architecturally incorrect. The filetypes extension does NOT declare routing. Skills are invoked via commands, not via language routing. Adding a `skill-docx-edit` without a corresponding command is orphaned — nothing will invoke it through normal routing. **A new `/edit` command is required, not just a new skill/agent pair.**

**Evidence**: `manifest.json` line 49 shows `"mcp_servers": {}` and no `"routing"` key. Contrast with `founder/manifest.json` lines 47-85 which shows full routing tables.

---

### Finding 2: The task description conflates "docx-edit-agent" naming vs actual convention (HIGH CONFIDENCE)

The actual filetypes agents are named after their domain category: `document-agent`, `spreadsheet-agent`, `presentation-agent`, `scrape-agent`. The task proposes a new agent named `docx-edit-agent`.

This is an inconsistency. By existing convention, the agent should be named `document-edit-agent` (domain-based) rather than `docx-edit-agent` (format-specific). The existing `document-agent` handles PDF, DOCX, HTML, and images — if we add `docx-edit-agent`, we have an agent named for a format sitting alongside one named for a domain.

**Risk**: Naming inconsistency will cause confusion. If later an xlsx-edit-agent is also added, the naming becomes even more fragmented.

**Recommendation**: Name the new agent `document-edit-agent` following the `document-agent` convention. Or scope it as `docx-edit-agent` deliberately but document the rationale (DOCX-only because SuperDoc only handles DOCX, not PDF or HTML).

---

### Finding 3: SuperDoc MCP package publication status is unverified (HIGH CONFIDENCE — RISK)

The research in `02_superdoc-workflows.md` explicitly lists this risk:

> "SuperDoc MCP package not yet published to npm | Medium | High | Verify `npx @superdoc-dev/mcp` works before partner setup; fall back to CLI or SDK"

Neither the team research nor the SuperDoc workflow report confirms that `npx @superdoc-dev/mcp` actually resolves to a published package. The references point to GitHub, a changelog, and documentation — but not to an npm registry page or a confirmed `npm show @superdoc-dev/mcp` result.

If this package is not on npm, the entire integration architecture collapses. The task should require verification before implementation begins.

**Action required**: Run `npm show @superdoc-dev/mcp` or `npx @superdoc-dev/mcp --version` as the first implementation step. If the package is not published, fall back to `dvejsada/mcp-ms-office-documents` (Docker-based, confirmed active).

---

### Finding 4: The manifest format does NOT support MCP server scope declarations (MEDIUM CONFIDENCE)

The research proposes updating `manifest.json` with:

```json
"mcp_servers": {
  "superdoc": {
    "command": "npx",
    "args": ["@superdoc-dev/mcp"],
    "scope": "user"
  }
}
```

However, the existing `founder/manifest.json` MCP server entries (lines 98-110) do NOT include a `"scope"` field — they only have `command`, `args`, and `env`. There is no `"scope"` key in either the founder or filetypes manifests.

The `scope` concept is a Claude Code CLI flag (`--scope user`) applied during `claude mcp add`, not a manifest JSON field. Including it in the manifest may be silently ignored or may cause the extension loader to malfunction.

**Risk**: Implementation adds a non-standard field that either gets ignored or breaks manifest loading.

**Recommendation**: Do not add `"scope"` to the manifest. Document user-scope registration as a manual setup step in the context file or `/edit` command, not in the manifest schema.

---

### Finding 5: Task 384 (broken markitdown) is unresolved and blocks document-agent (HIGH CONFIDENCE)

Task 384 status is `"researched"` — it has a research report but no implementation plan and no completion. The research identifies that `markitdown` is completely broken (dead Nix store symlink) and that `document-agent.md` still lists markitdown as the primary tool.

Task 386 proposes adding `docx-edit-agent` which would use SuperDoc, but the **existing `document-agent`** (which handles DOCX conversion) is still broken. Any user who runs `/convert contract.docx` will get a failure from the broken markitdown path.

**Risk**: Shipping SuperDoc editing capability while /convert is broken creates an incoherent user experience. The partner can edit DOCX in place but cannot convert DOCX to Markdown.

**Assessment**: Task 384 should be planned and implemented BEFORE or CONCURRENTLY with task 386, not left in `researched` status. The task description for 386 mentions 384 as context but does not treat it as a hard dependency.

---

### Finding 6: openpyxl MCP server package name is uncertain (MEDIUM CONFIDENCE)

The research mentions `@jonemo/openpyxl-mcp` as the package name for the openpyxl MCP server. However:

1. The reference citation in `02_superdoc-workflows.md` is `playbooks.com/mcp/jonemo-openpyxl-excel` — not the npm registry
2. The existing `spreadsheet-agent` uses `python-openpyxl` (direct Python library), not an MCP server
3. No `npm show @jonemo/openpyxl-mcp` verification was performed

The task description risks adding a `skill-xlsx-edit` that depends on a package that may not exist as an npm package.

**Recommendation**: Treat xlsx editing as a stretch goal or Python-fallback-first. The existing `spreadsheet-agent` already handles xlsx → LaTeX/Typst via openpyxl directly; the edit path can use the same Python-script approach before adding an unverified MCP dependency.

---

### Finding 7: The extension manifest currently declares `"language": null` (MEDIUM CONFIDENCE)

`filetypes/manifest.json` line 6: `"language": null`

The `founder/manifest.json` line 6: `"language": "founder"`

This means the filetypes extension does not participate in language-based routing at all. This is consistent with finding #1 (no routing block), but it also means:
- There is no `"filetypes"` language to dispatch via `/research 386 filetypes`
- The extension cannot be routed to via the standard `/research N [focus]` mechanism

The task description uses language `"meta"` (as seen in `state.json`). This is correct for the implementation task itself, but any new command created by task 386 would need its own command file, not language routing.

---

### Finding 8: No test considerations in the proposed approach (HIGH CONFIDENCE — MISSING ELEMENT)

The proposed approach covers: skill, agent, context files, manifest, command. There is no mention of:

1. How to test SuperDoc integration without an actual .docx file
2. Whether a test fixture docx should be committed to the extension
3. How to test tracked changes workflow end-to-end
4. Whether the existing `document-agent` tests (if any) would break

The filetypes extension has no `tests/` directory. Given that SuperDoc MCP depends on external npm package availability and a running MCP server, integration testing is non-trivial.

**Risk**: The implementation ships with zero test coverage for a completely new capability.

---

## Assumptions Not Validated

1. **`@superdoc-dev/mcp` is published to npm** — The research cites GitHub and docs but does not confirm npm availability with a package registry query.

2. **SuperDoc's MCP tool names are `superdoc_open`, `superdoc_search`, `superdoc_replace`** — These names are cited from documentation but tool names change between versions. The implementation should treat them as to-be-confirmed at implementation time.

3. **The manifest loader handles `mcp_servers` for lazy registration** — How the extension loader actually registers MCP servers from `manifest.json` is not documented. The founder extension declares MCP servers (sec-edgar, firecrawl) but these require API keys set via environment variables. SuperDoc runs locally and has no API key; the loader behavior may differ.

4. **`skill-docx-edit` will be invocable without a new command** — Currently, filetypes skills are only invocable via commands (`/convert` -> `skill-filetypes`). There is no documented mechanism for a user to invoke `skill-docx-edit` without a `/edit` command wiring it up.

5. **The `filetypes-router-agent` should be modified to add an `operation_type == "edit"` branch** — This is proposed in `02_superdoc-workflows.md`, but it changes an existing agent's routing logic. That modification could break existing `/convert` workflows if the branch detection is flawed.

---

## Scope Concerns

### Over-scoped (risks becoming too large):

The research proposes ALL of the following in a single task:
1. New `skill-docx-edit`
2. New `docx-edit-agent`
3. New `skill-xlsx-edit` (marked "optional")
4. Updated `manifest.json`
5. Updated `conversion-tables.md`
6. Updated `mcp-integration.md`
7. New `docx-editing.md` context file
8. Modified `filetypes-router-agent.md` (routing branch)
9. New `/edit` command (implied but not stated)
10. Partner-facing workflow documentation (from task 385 guide)

This is 8-10 file changes across agents, skills, context, manifest, and documentation. For a meta task implementing a new capability in an extension, this scope is on the heavy side.

**Recommendation**: Decompose into two tasks:
- **386a**: Add SuperDoc MCP editing capability (skill + agent + manifest + command + context)
- **386b**: xlsx editing via openpyxl MCP (contingent on package verification)

Or at minimum, mark xlsx editing as explicitly out of scope for 386 and create task 387 for it.

### Under-scoped (missing items):

1. **No `/edit` command file** — Without a command file, users cannot invoke the new capability via `/edit`. The proposed architecture is incomplete.
2. **No EXTENSION.md update** — The extension's CLAUDE.md section needs the new skill/agent/command added to its Skill-Agent Mapping table.
3. **No index-entries.json update** — New context files (`docx-editing.md`) require new entries in `index-entries.json` for proper agent context loading.
4. **No opencode-agents.json update** — If OpenCode integration is maintained, the new `docx-edit-agent` needs an entry here too.

---

## Missing Elements

| Element | Status in Task Description | Risk if Missing |
|---------|---------------------------|-----------------|
| `/edit` command file | Not mentioned | Users cannot invoke the capability |
| EXTENSION.md update | Not mentioned | CLAUDE.md section is stale |
| index-entries.json update | Not mentioned | New context file won't load for agents |
| opencode-agents.json update | Not mentioned | OpenCode integration breaks |
| npm package verification step | Not mentioned | Blocks entire integration if package doesn't exist |
| Test fixtures / test plan | Not mentioned | Zero test coverage for new capability |
| Task 384 dependency declaration | Mentioned as context, not dependency | Incoherent UX if 384 stays broken |

---

## Confidence Levels Summary

| Finding | Confidence | Severity |
|---------|-----------|----------|
| 1. No routing block in filetypes manifest | High | Medium — affects architecture correctness |
| 2. Agent naming inconsistency | High | Low — cosmetic but affects maintainability |
| 3. SuperDoc npm publication unverified | High | Critical — blocks implementation |
| 4. Manifest `scope` field non-standard | Medium | Low — silently ignored or minor breakage |
| 5. Task 384 unresolved, creates broken UX | High | High — user-facing incoherence |
| 6. openpyxl MCP package name uncertain | Medium | Medium — blocks xlsx editing scope |
| 7. Extension has `language: null` | High | Low — informational, confirms routing approach |
| 8. No test considerations | High | Medium — long-term maintainability risk |

---

## Recommendations for Plan

1. **Verify SuperDoc npm availability first** — make this Phase 1 (or a pre-condition gate) in the implementation plan
2. **Add `/edit` command** — this is required for the skill to be invocable
3. **Update EXTENSION.md, index-entries.json, and opencode-agents.json** — these are required for system coherence
4. **Treat 384 as a hard dependency** — either implement 384 first or include the markitdown fix in 386's scope
5. **Descope xlsx editing to a separate task** — keep 386 focused on DOCX/SuperDoc; xlsx editing is a separate problem with uncertain tooling
6. **Adopt `document-edit-agent` naming** — consistent with `document-agent` convention, or explicitly document why format-specific naming was chosen
7. **Remove `scope` from manifest mcp_servers** — follow founder extension's schema which has no `scope` field
