# Teammate C (Critic) Findings: Task 486

**Role**: Critic - gaps, blind spots, and risks
**Date**: 2026-04-19

---

## Key Findings

### Finding 1: `context: fork` Is The Right Value But skill-meta Is NOT a Pure Thin Wrapper

The `thin-wrapper-skill.md` template specifies `context: fork` exactly for skills that delegate to forked subagents. So the value itself is correct. However, skill-meta is **not** a pure thin wrapper: its `allowed-tools` includes `Task, Bash, Edit, Read, Write` rather than just `Task`. The template specifies `allowed-tools: Task` only for thin wrappers.

This raises a question: does adding `context: fork` to a skill that also has `Bash`, `Edit`, `Read`, `Write` create a contradiction? The `context: fork` signal is meant to tell the system "do NOT load context eagerly" and "this skill only wraps a subagent." But skill-meta performs postflight operations (git commit) directly using `Bash`. If `context: fork` suppresses context loading that postflight needs, that could be a regression.

**Risk**: If the system uses `context: fork` to restrict available tools or context to just what a thin wrapper needs, adding it to skill-meta (which does real postflight work) could silently break the git commit step.

**Unvalidated assumption**: Does `context: fork` have runtime enforcement (tool restriction, context suppression) or is it purely a documentation signal today?

### Finding 2: `subagent-return.md` Is NOT Deprecated - It Is Still Active

The task description says to "fix stale `subagent-return.md` references to `return-metadata-file.md`." However, `subagent-return.md` is **not** a dead file:

- It explicitly states (line 1-6): "As of Task 600, agents write metadata to **files** instead of returning JSON to the console. See `return-metadata-file.md` for the file-based protocol."
- It still defines the JSON **schema** that is now written to `.return-meta.json` files.
- Its header says: "The JSON schema below is still used, but now written to a file instead of console output."
- `return-metadata-file.md` (line 418) says: "The file-based metadata format supersedes the earlier console-based `subagent-return.md` pattern. See that file for historical context only."

So `subagent-return.md` is partially deprecated (console return pattern is gone), but the schema itself is still referenced. The files serve complementary, not duplicate, purposes:
- `subagent-return.md`: Schema definition (what fields, what values)
- `return-metadata-file.md`: Protocol definition (where to write, how to read)

**Risk**: Replacing all `subagent-return.md` references with `return-metadata-file.md` in skill-meta's "Return Validation" section (step 4) could mislead the skill into looking for a `.return-meta.json` file when validating the return. But skill-meta uses the file-based pattern (its "Context References" section already points to `return-metadata-file.md`). The remaining `subagent-return.md` references in skill-meta are in the body text, not the frontmatter.

**Specific stale references found**:
- `skill-meta/SKILL.md` line 109: "Validate return matches `subagent-return.md` schema"
- `skill-meta/SKILL.md` line 123: "See `.claude/context/formats/subagent-return.md` for full specification."
- `meta-builder-agent.md` line 93 (Mode-Context Matrix): `| subagent-return.md | Always | Always | Always |` - this says to load `subagent-return.md` but the agent's "Context References" section (line 61) says to load `return-metadata-file.md` instead. This is a genuine contradiction.

### Finding 3: The `latex` in DetectDomainType Is NOT the Only Hardcoded Domain

The task identifies `latex` as a hardcoded domain type to remove from `DetectDomainType`. But examining the agent (line 238-242):

```
- Keywords: "command", "skill", "agent", "meta", ".claude/" -> task_type = "meta"
- Keywords: "latex", "document", "pdf", "tex" -> task_type = "latex"
- Otherwise -> task_type = "general"
```

The `latex` branch is the only non-core hardcoded extension domain. The keywords `"command"`, `"skill"`, `"agent"`, `"meta"`, `".claude/"` for `task_type = "meta"` are appropriate because `meta` IS a core task type (listed in CLAUDE.md's core task types table). Only `latex` is extension-specific and should be removed.

**Unasked question**: What should `task_type` be set to when a latex task is discussed with `/meta`? After removing the `latex` branch, those keywords would fall through to `"general"`. Is `general` the right fallback for latex-style tasks, or should the agent use `neovim`/`nix`/etc. for extension types? The answer depends on what task_type is used for in `/meta` context: since `/meta` creates tasks for `.claude/` changes (not domain work), `general` is probably correct.

**Risk**: Removing `latex` may cause a small behavior change: previously a user saying "I want to add latex support" would get a task typed `latex`. After removal, it becomes `general`. This is acceptable since `/meta` creates system tasks, not domain tasks. But this trade-off is not explicitly documented in the task description.

### Finding 4: The `agent: meta-builder-agent` Field Is Already Referenced in skill-meta Body But Missing from Frontmatter

The skill body (line 82-83) says: "The `agent` field in this skill's frontmatter specifies the target: `meta-builder-agent`" - but the current frontmatter has NO `agent:` field. This means the body text is already lying about what's in the frontmatter.

Adding `agent: meta-builder-agent` to the frontmatter would make the body text accurate. This is a correctness fix, not just a pattern alignment.

### Finding 5: Source and Deployed Copies Are Identical - No Drift Detected

Both pairs are byte-for-byte identical:
- `.claude/skills/skill-meta/SKILL.md` == `.claude/extensions/core/skills/skill-meta/SKILL.md`
- `.claude/agents/meta-builder-agent.md` == `.claude/extensions/core/agents/meta-builder-agent.md`

This is expected since the task says all changes should be made in the extension source under `.claude/extensions/core/`. The sync mechanism presumably copies extension sources to deployed locations. All 4 changes should therefore be made only in `.claude/extensions/core/` files.

### Finding 6: skill-meta's `allowed-tools` May Be Wider Than Needed

The template specifies thin-wrapper skills should only need `Task`. skill-meta has `Task, Bash, Edit, Read, Write`. The postflight git commit requires `Bash`. But `Edit`, `Read`, and `Write` are listed without clear justification in the skill itself (those are agent tools, not skill tools). This is pre-existing but worth noting: the task description does not address `allowed-tools` cleanup.

### Finding 7: The Mode-Context Matrix Table Reference Is Inconsistent with "Always Load" Section

In `meta-builder-agent.md`, two sections conflict:
- **"Always Load (All Modes)"** section (line 62-63): Lists `return-metadata-file.md`
- **Mode-Context Matrix table** (line 93): Lists `subagent-return.md` in the "Always" column

This is the clearest inconsistency. The matrix table is a stale reference that should be updated to `return-metadata-file.md`.

---

## Recommended Approach

1. **Add `context: fork` and `agent: meta-builder-agent`**: Safe to add. The `context: fork` signal is appropriate since context IS loaded by the subagent. However, verify that `context: fork` does not suppress tools skill-meta uses in postflight (Bash for git). If it does, the fix should be to either keep postflight tools in frontmatter explicitly or move postflight to the agent.

2. **Fix `subagent-return.md` references**: Be surgical - do NOT replace all references. Specifically:
   - In `skill-meta/SKILL.md`: Replace body text references in steps 4 and at "Return Format" (lines 109, 123) with `return-metadata-file.md`
   - In `meta-builder-agent.md`: Update the Mode-Context Matrix table row (line 93) from `subagent-return.md` to `return-metadata-file.md`
   - Do NOT update the "Always Load" section in the agent (line 62) - it already correctly references `return-metadata-file.md`

3. **Remove `latex` from DetectDomainType**: Safe. The `latex` task_type is extension-specific. The fallback to `general` is appropriate for `/meta` context. Document the trade-off in the implementation.

4. **Make changes in extension source only**: Confirmed - `.claude/extensions/core/` is the right location. Deployed copies are synced from there.

---

## Evidence/Examples

**`context: fork` is the correct value per template** (thin-wrapper-skill.md lines 26-37):
```yaml
allowed-tools: Task
context: fork
agent: {subagent-name}
```

**skill-meta currently lacks `context` and `agent` fields** (skill-meta/SKILL.md lines 1-11):
```yaml
name: skill-meta
allowed-tools: Task, Bash, Edit, Read, Write
# (no context: or agent: fields)
```

**Body already references `agent` field as existing** (skill-meta/SKILL.md line 82):
> "The `agent` field in this skill's frontmatter specifies the target: `meta-builder-agent`"

**Matrix table has stale reference** (meta-builder-agent.md line 93):
> `| subagent-return.md | Always | Always | Always |`

**"Always Load" section already correct** (meta-builder-agent.md line 62):
> `@.claude/context/formats/return-metadata-file.md` - Metadata file schema

**`subagent-return.md` is still active** (subagent-return.md lines 1-6):
> "As of Task 600, agents write metadata to files... See `return-metadata-file.md` for the file-based protocol... The JSON schema below is still used, but now written to a file instead of console output."

---

## Confidence Level

| Finding | Confidence | Basis |
|---------|-----------|-------|
| `context: fork` is right value | High | Direct match to template spec |
| `context: fork` won't break postflight | Medium | `Bash` is still in allowed-tools; unclear if `context: fork` restricts runtime |
| `subagent-return.md` not fully deprecated | High | File self-describes its current role |
| Mode-Context Matrix row is stale | High | Contradicts "Always Load" section in same file |
| `latex` is the only extension domain to remove | High | Only 3 task_type branches, `meta` and `general` are core |
| Source == deployed, changes in extensions/core/ | High | Glob + file comparison shows identical content |
| `agent:` field absence makes body text inaccurate | High | Body says field exists; frontmatter shows it doesn't |
