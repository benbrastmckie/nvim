# Teammate B Findings: Alternative Patterns and Prior Art

**Task**: 486 - Align skill-meta and agent frontmatter/references
**Focus**: Cross-reference consistency, canonical patterns from other skills/agents
**Date**: 2026-04-19

---

## Key Findings

### 1. Frontmatter Pattern Deviations

**Canonical frontmatter** (from skill-researcher, skill-planner, skill-implementer, skill-reviser):
```yaml
---
name: skill-{name}
description: {brief description}. Invoke for {command/use-case}.
allowed-tools: Task, Bash, Edit, Read, Write
---
```

**skill-meta frontmatter** (actual):
```yaml
---
name: skill-meta
description: Interactive system builder. Invoke for /meta command to create tasks for .claude/ system changes.
allowed-tools: Task, Bash, Edit, Read, Write
# Original context (now loaded by subagent):
#   - .claude/docs/guides/component-selection.md
#   - .claude/docs/guides/creating-commands.md
#   - .claude/docs/guides/creating-skills.md
#   - .claude/docs/guides/creating-agents.md
# Original tools (now used by subagent):
#   - Read, Write, Edit, Glob, Grep, Bash(git, jq, mkdir), AskUserQuestion
---
```

**Deviation**: skill-meta has commented-out "Original context" and "Original tools" blocks in frontmatter. Other thin-wrapper skills have stripped these. skill-researcher and skill-planner also have these legacy comments but skill-implementer and skill-reviser do not, making this inconsistent.

**Affected files**:
- `/home/benjamin/.config/nvim/.claude/skills/skill-meta/SKILL.md` - has legacy comments
- `/home/benjamin/.config/nvim/.claude/skills/skill-researcher/SKILL.md` - has legacy comments (lines 5-8)
- `/home/benjamin/.config/nvim/.claude/skills/skill-planner/SKILL.md` - has legacy comments (lines 5-9)

### 2. Return Format Reference: subagent-return.md vs return-metadata-file.md

**Critical discrepancy**: skill-meta references the **wrong** metadata file.

**skill-meta SKILL.md** references:
- Section 4 (Return Validation): `subagent-return.md` schema (v1, console-based JSON)
- Return Format section: References `subagent-return.md`

**All other thin-wrapper skills** (skill-researcher, skill-implementer, skill-planner, skill-reviser, skill-nix-research, skill-neovim-research) reference:
- Context References block: `return-metadata-file.md` (v2, file-based)

**What subagent-return.md says about itself**: "The file-based metadata format supersedes the earlier console-based subagent-return.md pattern. See that file for historical context only." It is explicitly deprecated as a primary reference.

**What return-metadata-file.md is**: The current v2 protocol where agents write `.return-meta.json` and return brief text (not JSON) to console.

**Conclusion**: skill-meta's Return Validation step (Stage 4) validates for v1 JSON console return, but the agent (meta-builder-agent) is supposed to use v2 file-based protocol. This creates a fundamental protocol mismatch.

### 3. meta-builder-agent Return Format: v1 Console JSON vs v2 File-Based

**meta-builder-agent AGENT.md Stage 5**: Instructs agent to "Return ONLY valid JSON matching this schema" and shows three JSON examples (tasks_created, analyzed, cancelled).

**All other agents** (via their coordinating skills): Write `.return-meta.json` file and return brief text.

**What skill-meta actually does in postflight (Stage 4)**: Validates return against `subagent-return.md` (v1 JSON schema). No Stage 6 to read a metadata file exists - it just passes through the JSON verbatim.

**Deviation**: meta-builder-agent is the only agent still using v1 console JSON return. All research/planner/implementer/reviser agents use v2 file-based protocol.

**Evidence**: The postflight pattern in skill-meta has no metadata file reading stage. Other skills (researcher, planner, implementer, reviser) all have a Stage 6 that reads `.return-meta.json` via jq.

### 4. Postflight Completeness: skill-meta is Missing Standard Stages

**Standard postflight** (skill-researcher, skill-planner, skill-implementer, skill-reviser):
- Stage 6: Read `.return-meta.json` metadata file
- Stage 6a: Validate artifact content
- Stage 7: Update task status (postflight)
- Stage 8: Link artifacts in state.json + TODO.md
- Stage 9: Git commit
- Stage 10: Cleanup (rm marker + metadata files)
- Stage 11: Return brief text summary

**skill-meta postflight** (actual):
- Stage 4: Validate return against subagent-return.md (v1)
- Stage 5: Return propagation (pass through JSON verbatim)
- Git commit: buried in subagent (Stage 6 of meta-builder-agent)
- No marker file cleanup
- No .return-meta.json read
- No artifact linking in state.json via the skill

**Implications**: The meta pipeline has a different architecture from all other pipelines. This is partly intentional (/meta doesn't operate on existing tasks), but the return protocol mismatch (v1 vs v2) is a genuine bug.

### 5. Extension Skills Are Architecturally Behind Core Skills

**skill-nix-research** and **skill-neovim-research** compared to skill-researcher:

| Feature | skill-researcher | skill-nix-research | skill-neovim-research |
|---------|------------------|--------------------|-----------------------|
| Memory retrieval (Stage 4a) | Yes | No | No |
| Artifact number calculation (Stage 3a) | Yes | No | No |
| Format spec injection (Stage 4b) | Yes | No | No |
| Validate artifact (Stage 6a) | Yes | No | No |
| Centralized update-task-status.sh | Yes | Inline jq | Inline jq |
| loop-guard cleanup | Yes | No | No |

Extension skills use older-style inline jq for preflight status updates instead of calling `update-task-status.sh` centralized script. The nix/neovim research skills also reference an older TODO linking pattern (`artifact-linking-todo.md`) while skill-researcher uses `link-artifact-todo.sh` script.

**Stage 2 Preflight discrepancy**: skill-nix-research and skill-neovim-research use raw inline jq + Edit tool for status update:
```bash
jq ... specs/state.json > specs/tmp/state.json && mv ...
# Edit tool to change status in TODO.md
```
While skill-researcher uses:
```bash
.claude/scripts/update-task-status.sh preflight "$task_number" research "$session_id"
```

### 6. Delegation Path Inconsistency in skill-meta

**skill-meta delegation_path** (in delegation context JSON):
```json
"delegation_path": ["orchestrator", "meta", "skill-meta"]
```

**All other skills delegation_path**:
```json
"delegation_path": ["orchestrator", "research", "skill-researcher"]
"delegation_path": ["orchestrator", "plan", "skill-planner"]
"delegation_path": ["orchestrator", "implement", "skill-implementer"]
```

The pattern is consistent: `["orchestrator", "{operation}", "{skill-name}"]`. skill-meta follows this pattern correctly.

**meta-builder-agent expected delegation_path** (Stage 5 JSON example):
```json
"delegation_path": ["orchestrator", "meta", "meta-builder-agent"]
```

But the skill passes `delegation_path: ["orchestrator", "meta", "skill-meta"]` to the agent. The agent is one level deeper and should see `skill-meta` in the path, not replace it. This is correct behavior - the agent extends the path.

### 7. DetectDomainType in meta-builder-agent vs Other Agents

Other agents (researcher, planner, implementer) do NOT have domain detection logic - they accept `task_type` from the delegation context and act on it without reclassifying.

meta-builder-agent Interview Stage 2.5 has explicit `DetectDomainType`:
```
- Keywords: "command", "skill", "agent", "meta", ".claude/" -> task_type = "meta"
- Keywords: "latex", "document", "pdf", "tex" -> task_type = "latex"
- Otherwise -> task_type = "general"
```

This classification is specific to the /meta workflow (where the agent creates new tasks and needs to assign task_type). It is NOT a general agent pattern and the other agents correctly don't replicate it.

### 8. Context References: subagent-return.md Still Referenced in meta-builder-agent

**meta-builder-agent** "Always Load" context:
```
- `@.claude/context/formats/return-metadata-file.md` - Metadata file schema
- `@.claude/context/patterns/anti-stop-patterns.md`
```

But the agent's execution returns v1 console JSON (Stage 5 examples show JSON return to console). The agent correctly loads `return-metadata-file.md` but then doesn't use the v2 file-based protocol. The Mode-Context Matrix table (line ~95) references `subagent-return.md` under "Always Load":
```
| subagent-return.md | Always | Always | Always |
```

This is a direct contradiction: the context matrix says load `subagent-return.md` but the "Always Load" list says load `return-metadata-file.md`. The matrix is stale and incorrect.

---

## Recommended Approach

### Fix 1: Remove legacy comments from skill frontmatter (skill-meta, skill-researcher, skill-planner)
Remove the `# Original context` and `# Original tools` comment blocks from all skill frontmatter. They are remnants of the pre-thin-wrapper architecture and add no value.

### Fix 2: Migrate skill-meta to v2 return protocol
Replace skill-meta's Stages 3-5 (invoke + validate JSON + propagate) with the standard thin-wrapper pattern:
- Add Stage 3: Create postflight marker
- Keep Stage 3 (invoke): Keep Task tool invocation
- Add Stage 6: Read `.return-meta.json`
- Add Stage 9: Git commit if tasks created (currently happens inside agent)
- Add Stage 10: Cleanup marker and metadata files

### Fix 3: Migrate meta-builder-agent to v2 file-based return
Change Stage 5 from "Return ONLY valid JSON" to "Write `.return-meta.json` and return brief text". Use `tasks_created` as status value in the file.

### Fix 4: Fix meta-builder-agent's Mode-Context Matrix
Update the matrix to reference `return-metadata-file.md` (not `subagent-return.md`).

### Fix 5: Align extension skill preflight to use update-task-status.sh
Update skill-nix-research and skill-neovim-research Stage 2 to call the centralized script instead of inline jq + Edit. This is lower priority but improves consistency.

---

## Evidence/Examples

### Canonical Return Pattern (v2, from skill-researcher Stage 6):
```bash
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"
if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    ...
```

### skill-meta's Broken Pattern (Stage 4 "Return Validation"):
Validates against `subagent-return.md` - Status must be one of: `completed, partial, failed, blocked` (v1 enum). But the v2 protocol uses `tasks_created`, `analyzed`, `cancelled` - none of which appear in the v1 enum.

### meta-builder-agent Stage 5 Return Examples - All Return Console JSON:
```json
{
  "status": "tasks_created",
  ...
}
```
No file writing, no brief text return - pure v1 pattern.

### return-metadata-file.md explicit statement (last line):
> "Note: The file-based metadata format supersedes the earlier console-based subagent-return.md pattern. See that file for historical context only."

---

## Files Examined

1. `/home/benjamin/.config/nvim/.claude/skills/skill-researcher/SKILL.md` - Canonical thin-wrapper (has legacy frontmatter comments)
2. `/home/benjamin/.config/nvim/.claude/skills/skill-implementer/SKILL.md` - Clean thin-wrapper (no legacy comments)
3. `/home/benjamin/.config/nvim/.claude/skills/skill-planner/SKILL.md` - Has legacy frontmatter comments
4. `/home/benjamin/.config/nvim/.claude/skills/skill-reviser/SKILL.md` - Clean thin-wrapper
5. `/home/benjamin/.config/nvim/.claude/skills/skill-nix-research/SKILL.md` - Extension skill, architecturally behind core
6. `/home/benjamin/.config/nvim/.claude/skills/skill-neovim-research/SKILL.md` - Extension skill, architecturally behind core
7. `/home/benjamin/.config/nvim/.claude/context/formats/subagent-return.md` - Exists, v1 (deprecated, historical context only)
8. `/home/benjamin/.config/nvim/.claude/context/formats/return-metadata-file.md` - Exists, v2 (current canonical)
9. `/home/benjamin/.config/nvim/.claude/agents/meta-builder-agent.md` - Uses v1 console JSON return
10. `/home/benjamin/.config/nvim/.claude/skills/skill-meta/SKILL.md` - References v1, missing standard postflight

---

## Confidence Level

**High** (90%) for findings 1-4 (frontmatter comments, return protocol mismatch, postflight gap, meta-builder-agent v1 return).

**Medium** (70%) for finding 5 (extension skill architectural lag) - the extension skills may intentionally have a simpler architecture given their domain scope. The functional behavior is correct even if the implementation pattern is older-style.

**High** (85%) for finding 8 (mode-context matrix contradiction in meta-builder-agent) - the conflict between the matrix table and the Always Load list is clearly present in the file.

---

## Summary Table: Which Files Follow Canonical Pattern

| File | Frontmatter Clean | v2 Return Protocol | Postflight Complete | update-task-status.sh |
|------|:-----------------:|:------------------:|:-------------------:|:---------------------:|
| skill-researcher | No (legacy comments) | Yes | Yes | Yes |
| skill-planner | No (legacy comments) | Yes | Yes | Yes |
| skill-implementer | Yes | Yes | Yes | Yes |
| skill-reviser | Yes | Yes | Yes | Yes |
| skill-nix-research | Yes | Yes | Partial | No (inline jq) |
| skill-neovim-research | Yes | Yes | Partial | No (inline jq) |
| skill-meta | No (legacy comments) | No (v1) | No (missing stages) | N/A |
| meta-builder-agent | N/A | No (v1 JSON return) | N/A | N/A |
