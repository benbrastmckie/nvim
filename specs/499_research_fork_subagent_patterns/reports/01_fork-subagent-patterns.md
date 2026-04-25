# Research Report: Task #499

**Task**: 499 - Research FORK_SUBAGENT patterns and context: fork strategies
**Started**: 2026-04-25T12:00:00Z
**Completed**: 2026-04-25T12:45:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**:
- Codebase: all `.claude/skills/*/SKILL.md`, `.claude/agents/*.md`, `.claude/context/architecture/system-overview.md`, `.claude/context/patterns/thin-wrapper-skill.md`
- Official docs: https://code.claude.com/docs/en/sub-agents, https://code.claude.com/docs/en/skills, https://code.claude.com/docs/en/env-vars
- Community: buildthisnow.com fork subagent guide, trensee.com advanced patterns
- Extension loader: `lua/neotex/plugins/ai/shared/extensions/merge.lua`, `lua/neotex/plugins/ai/claude/extensions/picker.lua`
**Artifacts**:
- `specs/499_research_fork_subagent_patterns/reports/01_fork-subagent-patterns.md`
**Standards**: report-format.md, artifact-management.md

## Executive Summary

- **Two independent mechanisms exist**: `CLAUDE_CODE_FORK_SUBAGENT=1` (env var) enables conversation-forking subagents that inherit full parent context; `context: fork` (skill frontmatter) runs a skill's content as a subagent prompt in isolation. These are complementary, not redundant.
- **Prompt cache sharing is fork-exclusive**: Forked subagents share the parent's prompt cache prefix, yielding ~10x cost reduction per additional child (children 2-N). Named subagents (including those spawned via Task tool) get separate caches.
- **Current system deliberately avoids `context: fork`**: The system-overview.md explicitly states "Skills do NOT use `context: fork` or `agent:` frontmatter fields" -- delegation is explicit via Task tool. However, the thin-wrapper-skill.md template contradicts this by showing `context: fork` and `agent:` in frontmatter. One skill (skill-meta) uses `agent:` but not `context: fork`.
- **The fork env var and the existing Task-tool delegation are incompatible**: When `CLAUDE_CODE_FORK_SUBAGENT=1` is set, fork only fires when `subagent_type` is **omitted** from the Agent/Task tool call. Since all thin-wrapper skills explicitly specify `subagent_type` (e.g., "general-research-agent"), enabling the env var alone would NOT change their behavior.
- **Optimization opportunity exists for team mode**: Team skills spawn multiple parallel teammates where prompt cache sharing would yield the highest cost savings, but they use the TeammateTool (agent teams), not forked subagents.

## Context & Scope

### What Was Researched

1. How `CLAUDE_CODE_FORK_SUBAGENT=1` works at the Claude Code platform level
2. How `context: fork` works in skill frontmatter
3. The current agent system's delegation architecture (skills -> agents via Task tool)
4. Extension loader mechanics (`<leader>ac` Telescope picker)
5. Optimization opportunities for cost reduction through prompt cache sharing

### Constraints

- Fork mode is interactive-only (incompatible with headless/SDK mode)
- Forks cannot spawn further forks (no recursive forking)
- Fork only fires when subagent_type is omitted from the Agent tool call

## Findings

### 1. CLAUDE_CODE_FORK_SUBAGENT=1 (Environment Variable)

**What it does**: When enabled, Claude Code creates "forked" subagents that inherit the entire parent conversation (system prompt, message history, tools, model) instead of starting fresh. The fork's system prompt is byte-identical to the parent's, pulled from `override.systemPrompt` via `toolUseContext.renderedSystemPrompt`.

**Prompt cache mechanics**: Because the fork's system prompt bytes are identical to the parent's, the Anthropic API's prompt caching hits on the shared prefix. For a 48,500-token shared prefix:

| Scenario | Per-Child Input Cost |
|----------|---------------------|
| Without fork (fresh subagent) | ~48,700 tokens (full rebuild) |
| With fork (child 1) | ~48,700 tokens (cache miss) |
| With fork (children 2-N) | ~5,050 tokens (cache hit) |

For 5 parallel agents, this represents a reduction from ~243,500 to ~68,900 shared-prefix tokens.

**Key constraint**: Fork **only fires when `subagent_type` is omitted** from the Agent tool call. If the model specifies an explicit type (e.g., "general-research-agent", "Explore", "Plan"), the fork path does not trigger. Instead, a standard named subagent is created with a separate cache.

**Behavioral changes when enabled**:
- All subagent spawns run in background
- `/fork` spawns a forked subagent instead of being an alias for `/branch`
- Claude spawns a fork whenever it would use the general-purpose built-in subagent

**Incompatibilities**: Print mode (non-interactive), coordinator mode, SDK/headless.

### 2. `context: fork` (Skill Frontmatter Field)

**What it does**: When a skill has `context: fork` in its frontmatter, invoking that skill runs its content in an isolated subagent context. The skill's markdown body becomes the subagent's task prompt. The subagent does NOT inherit conversation history -- it starts fresh.

**Combined with `agent:` field**: The `agent` frontmatter field specifies which subagent type executes the forked context. Options include built-in agents (`Explore`, `Plan`, `general-purpose`) or custom agents from `.claude/agents/`. If omitted, uses `general-purpose`.

**Key difference from fork env var**: `context: fork` creates isolation (fresh context), while `CLAUDE_CODE_FORK_SUBAGENT=1` creates inheritance (full parent context). They solve opposite problems:

| Aspect | `context: fork` | `FORK_SUBAGENT=1` |
|--------|-----------------|-------------------|
| Context | Fresh (isolated) | Full parent history |
| System prompt | Agent type's prompt | Parent's prompt |
| Prompt cache | Separate | Shared with parent |
| Use case | Skill-driven task in isolation | Side tasks needing parent context |
| Invocation | Skill frontmatter | Environment variable |

### 3. Current Agent System Architecture

**Delegation pattern**: Commands -> Skills -> Agents (via Task tool).

The system uses "thin wrapper" skills that explicitly spawn named agents via the Task tool:

```
skill-researcher -> Task(subagent_type="general-research-agent", prompt=...)
skill-planner -> Task(subagent_type="planner-agent", prompt=...)
skill-implementer -> Task(subagent_type="general-implementation-agent", prompt=...)
```

**Current skill frontmatter inventory** (22 skills total):

| Pattern | Skills | Uses `context: fork`? | Uses `agent:`? |
|---------|--------|----------------------|----------------|
| Delegating (Task tool) | skill-researcher, skill-planner, skill-implementer, skill-neovim-*, skill-nix-*, skill-reviser, skill-spawn | No | No |
| Delegating with agent: | skill-meta | No | Yes (`meta-builder-agent`) |
| Direct execution | skill-fix-it, skill-git-workflow, skill-memory, skill-orchestrator, skill-status-sync, skill-refresh, skill-tag, skill-todo, skill-project-overview | No | No |
| Team orchestration | skill-team-research, skill-team-plan, skill-team-implement | No | No |

**Notable inconsistency**: The `system-overview.md` states "Skills do NOT use `context: fork` or `agent:` frontmatter fields" but:
1. `skill-meta` uses `agent: meta-builder-agent`
2. The `thin-wrapper-skill.md` template shows `context: fork` and `agent:` as standard frontmatter
3. Two extension skills (skill-slide-planning, skill-slide-critic) use `context: fork`

### 4. Extension Loader Analysis

The `<leader>ac` keymap opens a Telescope picker (`lua/neotex/plugins/ai/claude/extensions/picker.lua`) that wraps the shared picker (`lua/neotex/plugins/ai/shared/extensions/picker.lua`).

**What loads at extension activation time**:
- CLAUDE.md sections (injected via `merge.inject_section()` with markers)
- Context index entries (merged via `merge.merge_settings()` into `index.json`)
- Skills, agents, rules, commands (copied to `.claude/` directories)
- Settings fragments (merged into `settings.json`)

**What loads at agent spawn time**:
- Agent-specific context from `index.json` (via `load_when` queries)
- Task-specific context (delegation prompt, format specs, memory, roadmap)

This means: extensions expand the available context pool at activation, but agents still load context lazily at spawn time. The fork env var would not affect this architecture because context loading happens within agent execution, not at the skill level.

### 5. How the Two Mechanisms Could Interact

**Scenario A: Enable FORK_SUBAGENT=1 without changes**
- No effect on thin-wrapper skills because they all specify `subagent_type` in Task tool calls
- Would affect Claude's automatic subagent spawning (e.g., when Claude decides to explore codebase on its own)
- All subagent spawns would run in background (potential UX change)

**Scenario B: Add `context: fork` to thin-wrapper skills**
- Skills would run in isolated subagent context instead of using the Task tool
- The `agent:` field would determine which agent type runs
- CLAUDE.md and skill content would still load, but conversation history would NOT
- This would break the current delegation context pattern (session_id, depth, path, task_context) because the subagent would not receive the structured prompt

**Scenario C: Switch thin-wrappers to omit subagent_type (to enable fork)**
- Would require removing explicit agent names from Task tool calls
- Fork would inherit full conversation including all CLAUDE.md and loaded context
- But it would lose the specialized agent prompt (the agent's markdown body)
- Prompt cache sharing would work but the agent would be "general-purpose" only

**Scenario D: Use `context: fork` + `agent:` together (template pattern)**
- The template (`thin-wrapper-skill.md`) shows this as standard
- Skill body becomes the task prompt, agent body becomes the system prompt
- But this conflicts with the system-overview.md assertion
- The present extension skills (slide-planning, slide-critic) use this pattern

## Decisions

1. **The env var and skill frontmatter are independent mechanisms** that solve different problems. They are not alternatives.
2. **The current Task-tool delegation pattern is immune to FORK_SUBAGENT** because it always specifies `subagent_type`.
3. **The thin-wrapper template and system-overview are inconsistent** and need reconciliation.

## Recommendations

### Priority 1: Reconcile Documentation

The `system-overview.md` assertion that skills "do NOT use `context: fork` or `agent:` frontmatter fields" is contradicted by:
- `thin-wrapper-skill.md` template (shows both)
- `skill-meta` (uses `agent:`)
- Present extension skills (use `context: fork`)

**Action**: Update `system-overview.md` to reflect actual usage. Either:
- (a) Acknowledge that `agent:` is used in some skills, or
- (b) Remove `agent:` from skill-meta and rely purely on Task tool delegation

### Priority 2: Consider `context: fork` for Extension Skills

Extension skills that delegate to specialized agents could benefit from `context: fork` if:
- They don't need conversation history in the subagent
- The agent body provides sufficient system prompt
- The skill body provides sufficient task prompt

This is the pattern already used by present extension skills (slide-planning, slide-critic). It eliminates the need for explicit Task tool invocation in the skill body.

**Cost/benefit**:
- Pro: Simpler skill body (no Task tool invocation logic)
- Pro: Claude Code handles subagent lifecycle
- Con: Less control over delegation context (session_id, depth, path)
- Con: Cannot inject memory_context, roadmap_context, format_spec into prompt
- Con: Prompt cache is separate (not shared with parent)

### Priority 3: Evaluate FORK_SUBAGENT for Team Mode

Team mode (skill-team-research, skill-team-plan, skill-team-implement) spawns 2-4 parallel teammates. If these could use forked subagents instead of separate agent teams, prompt cache sharing would yield significant cost savings (2-4x reduction in shared prefix costs).

**Caveat**: Team mode uses `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` and the TeammateTool, which is a separate system from subagent forking. These may not be compatible.

### Priority 4: Do Not Enable Fork by Default

Enabling `CLAUDE_CODE_FORK_SUBAGENT=1` globally would:
- Force all subagent spawns to run in background (changing existing UX)
- Not affect thin-wrapper skills (they specify subagent_type)
- Only affect Claude's automatic subagent usage (Explore, general-purpose)
- Add complexity without clear benefit for the current architecture

Fork is best suited for ad-hoc user workflows, not the structured skill/agent pipeline.

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Context pollution in fork (full history) | Medium | Only use fork for short sessions or targeted tasks |
| Stale context in long sessions | Medium | Fork cost scales with session length; monitor token usage |
| Template/overview inconsistency causes confusion | Low | Reconcile documentation (Priority 1) |
| Fork incompatible with headless/SDK | Low | Only enable in interactive sessions |
| Breaking delegation context if switching to `context: fork` | High | Keep Task tool pattern for core skills that need structured delegation |

## Appendix

### Search Queries Used

1. `CLAUDE_CODE_FORK_SUBAGENT environment variable documentation 2026`
2. `Claude Code "context: fork" skill frontmatter subagent prompt cache sharing 2026`
3. Codebase grep: `context:\s*fork|FORK_SUBAGENT|context: fork` in `.claude/`
4. Codebase grep: `<leader>ac|extension.*picker|load.*extension` in `lua/`

### Key Source Files

- `.claude/context/architecture/system-overview.md` (lines 91-117) - Layer 2 skill architecture
- `.claude/context/patterns/thin-wrapper-skill.md` (lines 24-39) - Template with `context: fork`
- `.claude/skills/skill-researcher/SKILL.md` - Full thin-wrapper implementation
- `.claude/skills/skill-meta/SKILL.md` - Uses `agent:` but not `context: fork`
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - Extension loader merge logic

### References

- [Official: Create custom subagents](https://code.claude.com/docs/en/sub-agents)
- [Official: Extend Claude with skills](https://code.claude.com/docs/en/skills)
- [Official: Environment variables](https://code.claude.com/docs/en/env-vars)
- [Build This Now: Fork Subagents in Claude Code](https://www.buildthisnow.com/blog/guide/mechanics/claude-code-fork-subagent)
- [Trensee: Claude Code Advanced Patterns](https://www.trensee.com/en/blog/explainer-claude-code-skills-fork-subagents-2026-03-31)
