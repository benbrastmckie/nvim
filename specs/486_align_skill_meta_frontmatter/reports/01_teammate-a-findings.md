# Teammate A Findings: Task 486 - Align skill-meta and agent frontmatter/references

**Date**: 2026-04-19
**Teammate**: A (Primary Analysis)
**Artifact**: 01

---

## Key Findings

### Issue 1: skill-meta frontmatter missing `context: fork` and `agent:` fields

**Affected files** (both deployed and extension source are identical):
- `.claude/skills/skill-meta/SKILL.md` (deployed)
- `.claude/extensions/core/skills/skill-meta/SKILL.md` (source)

**Current frontmatter** (lines 1-5 in both files):
```yaml
---
name: skill-meta
description: Interactive system builder. Invoke for /meta command to create tasks for .claude/ system changes.
allowed-tools: Task, Bash, Edit, Read, Write
# Original context (now loaded by subagent):
#   - .claude/docs/guides/component-selection.md
...
---
```

**Required frontmatter** per `thin-wrapper-skill.md`:
```yaml
---
name: skill-meta
description: Interactive system builder. Invoke for /meta command to create tasks for .claude/ system changes.
allowed-tools: Task
context: fork
agent: meta-builder-agent
---
```

**Changes needed**:
1. Add `context: fork` field
2. Add `agent: meta-builder-agent` field
3. Change `allowed-tools: Task, Bash, Edit, Read, Write` -> `allowed-tools: Task` (thin wrappers only need Task tool for delegation)
4. Remove the commented-out original context/tools block (lines 5-11) — it's stale documentation noise

**Note on allowed-tools**: The thin-wrapper-skill.md standard says `allowed-tools: Task` only. The extra tools (Bash, Edit, Read, Write) suggest the skill may have originally done work directly. Since it's now a thin wrapper, these extra tools should be removed. However, the skill body does reference using `Bash` for mode detection in Section 1 — but that bash block is pseudocode documentation, not actual tool invocation. The skill delegates all real work to the agent. Removing extra tools is safe.

---

### Issue 2: Stale `subagent-return.md` reference in skill-meta (Section 4 and Return Format section)

**Affected files** (both deployed and extension source are identical):
- `.claude/skills/skill-meta/SKILL.md` line 109
- `.claude/skills/skill-meta/SKILL.md` line 123
- `.claude/extensions/core/skills/skill-meta/SKILL.md` line 109
- `.claude/extensions/core/skills/skill-meta/SKILL.md` line 123

**Current text at line 109**:
```
Validate return matches `subagent-return.md` schema:
```

**Current text at line 123**:
```
See `.claude/context/formats/subagent-return.md` for full specification.
```

**Required replacement** (line 109):
```
Validate return matches `return-metadata-file.md` schema:
```

**Required replacement** (line 123):
```
See `.claude/context/formats/return-metadata-file.md` for full specification.
```

**Evidence**: The `return-metadata-file.md` itself states at line 418:
> "The file-based metadata format supersedes the earlier console-based `subagent-return.md` pattern. See that file for historical context only."

The `subagent-return.md` file at its top (line 4) also confirms:
> "As of Task 600, agents write metadata to files instead of returning JSON to the console... See `.claude/context/formats/return-metadata-file.md` for the file-based protocol."

---

### Issue 3: Stale `subagent-return.md` reference in meta-builder-agent Mode-Context Matrix

**Affected files** (both deployed and extension source are identical):
- `.claude/agents/meta-builder-agent.md` line 94
- `.claude/extensions/core/agents/meta-builder-agent.md` line 94

**Current text** (in the Mode-Context Matrix table):
```
| subagent-return.md | Always | Always | Always |
```

**Required replacement**:
```
| return-metadata-file.md | Always | Always | Always |
```

**Additional note**: The agent's Context References section (lines 60-62) already correctly references `return-metadata-file.md`:
```
**Always Load (All Modes)**:
- `@.claude/context/formats/return-metadata-file.md` - Metadata file schema
```

So only the Mode-Context Matrix table row needs updating — the inline context reference is already correct.

---

### Issue 4: Hardcoded `latex` domain in DetectDomainType (meta-builder-agent)

**Affected files** (both deployed and extension source are identical):
- `.claude/agents/meta-builder-agent.md` lines 237-242
- `.claude/extensions/core/agents/meta-builder-agent.md` lines 237-242

**Current text** (Interview Stage 2.5: DetectDomainType):
```
**Classification Logic**:
- Keywords: "command", "skill", "agent", "meta", ".claude/" -> task_type = "meta"
- Keywords: "latex", "document", "pdf", "tex" -> task_type = "latex"
- Otherwise -> task_type = "general"
```

**Problem**: The `latex` domain type is a hardcoded extension-specific type. If the latex extension is not loaded, tasks created with `task_type = "latex"` will fail routing. The meta agent should not hardcode extension domain types — extensions declare their own routing.

**Required replacement** (extension-aware pattern):
```
**Classification Logic**:
- Keywords: "command", "skill", "agent", "meta", ".claude/" -> task_type = "meta"
- Otherwise -> task_type = "general"
```

**Rationale**: The routing table in CLAUDE.md shows `latex` is an extension task type, only available when that extension is loaded. The meta agent operates without knowing which extensions are loaded. Defaulting unknown domains to `general` is safe — users can manually specify task_type in the description if needed, or the domain detection can be enhanced later with extension-awareness. Removing the `latex` hardcoding avoids incorrect routing.

**Alternative considered**: Making it extension-aware by querying which extensions are loaded. This would be complex (requires reading extension manifests). The simpler approach — removing the hardcoded line and defaulting to `general` — is safer and aligns with the task description's suggested approach.

---

## Recommended Approach

### Changes to make (in order):

**File 1: `.claude/extensions/core/skills/skill-meta/SKILL.md`** (source of truth)
1. Replace frontmatter block (lines 1-12) with proper thin-wrapper frontmatter
2. Replace line 109 `subagent-return.md` reference with `return-metadata-file.md`
3. Replace line 123 `subagent-return.md` reference with `return-metadata-file.md`

**File 2: `.claude/skills/skill-meta/SKILL.md`** (deployed copy — mirror identical changes)

**File 3: `.claude/extensions/core/agents/meta-builder-agent.md`** (source of truth)
1. Replace Mode-Context Matrix row with `return-metadata-file.md`
2. Remove the `latex` hardcoded domain detection line

**File 4: `.claude/agents/meta-builder-agent.md`** (deployed copy — mirror identical changes)

---

## Evidence/Examples

### Thin-wrapper frontmatter standard (from `thin-wrapper-skill.md` lines 26-33):
```yaml
---
name: skill-{name}
description: {One-line description}
allowed-tools: Task
context: fork
agent: {agent-name}
---
```

### Return metadata file is authoritative (from `return-metadata-file.md` line 418):
> "The file-based metadata format supersedes the earlier console-based `subagent-return.md` pattern."

### Extension task types are extension-owned (from CLAUDE.md):
> "Extension Task Types (available when extensions are loaded via the extension picker)"
> Extensions provide: `lean4, latex, typst, python, nix, web, z3, epi, formal, founder, present, etc.`

### Deployed vs extension copies
Both deployed (`.claude/`) and extension source (`.claude/extensions/core/`) copies are character-for-character identical — confirmed by reading both. All 4 changes must be applied to both copies.

---

## Confidence Level

**High confidence** on all 4 issues:

| Issue | Confidence | Notes |
|-------|------------|-------|
| Missing `context: fork` and `agent:` frontmatter | High | thin-wrapper-skill.md is unambiguous |
| Stale `subagent-return.md` in skill-meta | High | Two references, both clearly stale |
| Stale `subagent-return.md` in agent matrix | High | One reference, context already correct above it |
| Hardcoded `latex` domain type | High | Extension types are owned by extensions; meta agent can't know what's loaded |

**Risk**: Low. All changes are documentation/metadata fixes in frontmatter and text descriptions, not behavioral logic changes. The `allowed-tools` change (removing Bash/Edit/Read/Write) is the only potentially impactful change — but since skill-meta is a thin wrapper that delegates to the agent, these tools are not used for real work and can be safely removed.

**Scope**: 4 files total (2 skill copies, 2 agent copies). Extension source and deployed copies must both be updated.
