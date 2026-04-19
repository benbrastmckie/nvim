# Teammate D Findings: Horizons (Strategic Alignment)

**Task**: 486 - Align skill-meta and agent frontmatter/references
**Role**: Horizons - Long-term alignment and strategic direction
**Artifact**: 01_teammate-d-findings.md

---

## Key Findings

### 1. The Four Specific Fixes Are Well-Scoped

The task description is precise. The four fixes needed are:

1. **Add `context: fork` and `agent: meta-builder-agent` to skill-meta frontmatter** - Currently missing. The `creating-skills.md` guide and `meta.md` command both show `context: fork` as a required field for thin-wrapper skills. No existing skill in `.claude/skills/` uses `context: fork` in its frontmatter (they all omit it). This is a systemic gap, but the task is correctly scoped to fix only `skill-meta`.

2. **Fix stale `subagent-return.md` references in skill-meta** - `skill-meta/SKILL.md` references `subagent-return.md` at lines 109 and 123. It should reference `return-metadata-file.md` (the canonical location). The meta-builder-agent's Mode-Context Matrix (line 93) also references `subagent-return.md`. Both deployed and extension source copies need updating.

3. **Remove hardcoded `latex` domain type from DetectDomainType** - Lines 240 and 1151 in `meta-builder-agent.md` hard-code latex routing. With the extension system in place, this creates false classification for any user mentioning "document" or "tex" who is not using the latex extension. Should fall back to `general` or reference the loaded extension's task types.

4. **All changes in extension source copies under `.claude/extensions/core/`** - Both `skill-meta/SKILL.md` and `agents/meta-builder-agent.md` exist in the extension source at `.claude/extensions/core/skills/` and `.claude/extensions/core/agents/`. The deployed copies at `.claude/skills/` and `.claude/agents/` must mirror these changes.

### 2. Interaction With Task 485 (meta-guide.md Rewrite)

Task 485 (rewrite `meta-guide.md`) is a separate, larger task marked `[NOT STARTED]`. The current `meta-guide.md` is severely outdated - it describes a phantom 12-question system with `.opencode/agent/subagents/` paths, marketing claims ("+20% routing accuracy"), and a 3-level context allocation model that does not exist in the codebase.

**Task 486 and 485 are complementary but independent**:
- Task 486 fixes frontmatter/references in the skill and agent implementation files
- Task 485 rewrites the guide document that explains how to use /meta
- No dependency between them - both can be fixed without the other
- Doing 486 first is appropriate since it is smaller and targeted

### 3. Memory Integration Gap

The user's question about whether `skill-meta` should integrate `memory-retrieve` is strategically important.

**Current state**: `skill-researcher/SKILL.md`, `skill-planner/SKILL.md`, and `skill-implementer/SKILL.md` all call `memory-retrieve.sh` during preflight to inject relevant memories into agent context. `skill-meta` does not.

**Assessment**: Memory integration in `skill-meta` is *not* part of task 486's scope as described, but it is a legitimate enhancement. The rationale for adding it:
- `/meta` interviews the user about system changes; knowing about past system decisions (what worked, what was removed) could improve task creation quality
- The memory vault likely contains entries about past `/meta` decisions

**However**, the task description does not include this. Adding it to task 486 would scope-creep a "small" task into a "medium" one. The strategic recommendation is to note it as a roadmap item but keep task 486 focused.

### 4. Roadmap Alignment

The ROADMAP.md Phase 1 "Agent System Quality" section includes:

> **Agent frontmatter validation**: Add a check that every file in `.claude/agents/` and `.claude/extensions/*/agents/` uses the minimal frontmatter standard (`name`, `description`, optional `model`) with no obsolete fields.

Task 486 is a prerequisite for this roadmap item. By fixing `skill-meta`'s frontmatter to include the standard `context: fork` and `agent:` fields, and ensuring `meta-builder-agent.md` frontmatter is correct, task 486 makes these files compliant *before* the validation lint script is written.

The ROADMAP also mentions:
> **Subagent-return reference cleanup**: Sweep remaining `subagent-return-format.md` references in `.claude/context/`

Fix (2) in task 486 addresses the `subagent-return.md` references specifically in skill-meta and meta-builder-agent. Broader context-level cleanup remains a separate roadmap item.

### 5. The `context: fork` Field Is Missing System-Wide

This is the most strategically significant finding. The creating-skills guide documents `context: fork` as **critical** for token efficiency: "Without it, context would be loaded into the skill's conversation, wasting tokens." Yet **no deployed skill** currently uses `context: fork` in its frontmatter.

This suggests either:
- The field is aspirational/documentation-only and not actually enforced by Claude Code
- The field was planned but never added during the thin-wrapper refactoring
- The field is enforced implicitly by some other mechanism

**Recommendation**: Task 486 should add `context: fork` and `agent: meta-builder-agent` to `skill-meta` frontmatter as specified, but the implementer should verify whether this field has any actual runtime effect before adding it. If it does not, a separate task should audit whether the pattern documentation is accurate.

---

## Recommended Approach

### Scope Discipline

Keep task 486 strictly to the four described fixes. Do not add memory integration or sweep other skills. The task is labeled "Small" - keep it that way.

### Implementation Order

1. Fix extension source copies first: `.claude/extensions/core/skills/skill-meta/SKILL.md` and `.claude/extensions/core/agents/meta-builder-agent.md`
2. Mirror changes to deployed copies: `.claude/skills/skill-meta/SKILL.md` and `.claude/agents/meta-builder-agent.md`
3. Verify no other files in the /meta pipeline reference stale paths

### Changes Required

**In `skill-meta/SKILL.md` (both copies)**:
```yaml
---
name: skill-meta
description: Interactive system builder. Invoke for /meta command to create tasks for .claude/ system changes.
allowed-tools: Task, Bash, Edit, Read, Write
context: fork
agent: meta-builder-agent
---
```

**In `skill-meta/SKILL.md` (return validation section)**:
- Line 109: Change "subagent-return.md" to "return-metadata-file.md"
- Line 123: Change "subagent-return.md" to "return-metadata-file.md"

**In `meta-builder-agent.md` (Mode-Context Matrix)**:
- Line 93: Change "subagent-return.md" reference
- Lines 237-241 (DetectDomainType): Remove `latex` hardcoding, replace with `general` fallback or extension-aware lookup

### Strategic Opportunity (Roadmap Item)

After task 486 completes, consider creating a follow-up task for:
- **Memory integration in skill-meta**: Add `memory-retrieve.sh` call during preflight to inject past /meta decisions as context for the meta-builder-agent interview
- **Audit context: fork runtime behavior**: Verify whether the `context: fork` frontmatter field is actually respected by the Claude Code runtime

---

## Evidence/Examples

### skill-meta frontmatter (current, both copies identical)
```
/home/benjamin/.config/nvim/.claude/skills/skill-meta/SKILL.md:2: name: skill-meta
/home/benjamin/.config/nvim/.claude/skills/skill-meta/SKILL.md:3: description: Interactive system builder...
/home/benjamin/.config/nvim/.claude/skills/skill-meta/SKILL.md:4: allowed-tools: Task, Bash, Edit, Read, Write
# Missing: context: fork, agent: meta-builder-agent
```

### meta-builder-agent frontmatter (correct, no issue here)
```
/home/benjamin/.config/nvim/.claude/agents/meta-builder-agent.md:2: name: meta-builder-agent
/home/benjamin/.config/nvim/.claude/agents/meta-builder-agent.md:3: description: Interactive system builder for .claude/ architecture changes
/home/benjamin/.config/nvim/.claude/agents/meta-builder-agent.md:4: model: opus
```

### Stale subagent-return.md references
```
/home/benjamin/.config/nvim/.claude/skills/skill-meta/SKILL.md:109: Validate return matches `subagent-return.md` schema:
/home/benjamin/.config/nvim/.claude/skills/skill-meta/SKILL.md:123: See `.claude/context/formats/subagent-return.md` for full specification.
/home/benjamin/.config/nvim/.claude/agents/meta-builder-agent.md:93: | subagent-return.md | Always | Always | Always |
```

### latex hardcoding in DetectDomainType
```
/home/benjamin/.config/nvim/.claude/agents/meta-builder-agent.md:240:
- Keywords: "latex", "document", "pdf", "tex" -> task_type = "latex"
```

### Memory integration present in peer skills, absent in skill-meta
```
skill-researcher/SKILL.md:133: memory_context=$(bash .claude/scripts/memory-retrieve.sh ...)
skill-planner/SKILL.md:151:  memory_context=$(bash .claude/scripts/memory-retrieve.sh ...)
skill-implementer/SKILL.md:146: memory_context=$(bash .claude/scripts/memory-retrieve.sh ...)
skill-meta/SKILL.md: [no memory-retrieve call]
```

---

## Confidence Level

**High** for the four specific fixes (all confirmed by direct file inspection).

**Medium** for the strategic recommendations around `context: fork` runtime behavior - this field may or may not be enforced.

**Low** for the memory integration suggestion - it is speculative about whether past meta decisions are actually in the memory vault, and the user has not requested this as part of task 486.

---

## Summary

Task 486 is well-defined and appropriately scoped. All four fixes are confirmed by direct inspection. The task directly advances the "Agent frontmatter validation" roadmap item. The interaction with task 485 (meta-guide.md rewrite) is clean - both tasks are independent and complementary. The strategic opportunity around memory integration in skill-meta is noted but out of scope for this task.

The implementer should focus on: (1) extension source copies first, (2) mirroring to deployed copies, (3) verifying no other stale references remain in the /meta pipeline.
