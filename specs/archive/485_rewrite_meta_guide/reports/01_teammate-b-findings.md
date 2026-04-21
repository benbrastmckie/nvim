# Research Report: Task #485 - Teammate B Findings

**Task**: 485 - Rewrite meta-guide.md to match current system
**Teammate**: B (Cross-Reference and Integration Analysis)
**Started**: 2026-04-19T00:00:00Z
**Completed**: 2026-04-19T01:00:00Z
**Effort**: Medium (2 hours)
**Dependencies**: None
**Sources/Inputs**: Codebase analysis of .claude/ system files
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- The current `meta-guide.md` is almost entirely fictional - it describes a system that does not exist (OpenCode paths, 12-question interview, marketing claims)
- The actual /meta system is a well-structured 3-mode command with a deeply-specified 7-stage interview, full multi-task creation standard compliance, and integration with the core agent pipeline
- The meta task_type routing is identical to general/markdown tasks in CLAUDE.md (both use `skill-researcher` and `skill-implementer`), but meta-builder-agent is only used by /meta, not /research
- The .memory/ system has clear integration hooks in skill-researcher that /meta does NOT yet use - this is an actionable gap
- meta-builder-agent diverges from other agents: it returns JSON to skill (not brief text), lacks postflight in skill-meta for status updates (correct - meta creates tasks, not research/plans), and does NOT use the return-metadata-file.md pattern that research/plan/implement agents do

---

## Context and Scope

This report analyzes /meta cross-system integration: how it interacts with other commands, how meta tasks flow through the pipeline, how task_type routing works, and integration opportunities with .memory/ and ROADMAP.md.

---

## Findings

### 1. How /meta-Created Tasks Flow Through the Pipeline

Meta tasks created by `/meta` have `task_type: "meta"` in state.json. Once created, they flow through the standard `/research -> /plan -> /implement` cycle identically to general tasks:

**From CLAUDE.md task routing table**:
```
meta | skill-researcher | skill-implementer | Read, Grep, Glob, Write, Edit
```

This means:
- `/research N` on a meta task routes to `skill-researcher` -> `general-research-agent` (same as general tasks)
- `/plan N` routes to `skill-planner` -> `planner-agent`
- `/implement N` routes to `skill-implementer` -> `general-implementation-agent`

There is NO special meta-specific research or implementation skill - meta tasks use the same agents as general tasks. The `meta-builder-agent` is ONLY invoked by `/meta` itself, not during research/plan/implement.

**Evidence**: From `research.md` STAGE 2, the extension routing logic checks manifests first, then falls back to `skill-researcher`. The core extension's `manifest.json` has `routing_exempt: true` and provides no routing entries for meta task_type, confirming fallback behavior.

**State.json entry format** (from actual data):
```json
{
  "project_number": 485,
  "project_name": "rewrite_meta_guide",
  "status": "researching",
  "task_type": "meta"
}
```

Meta tasks in state.json look identical to general tasks - no special fields.

### 2. How meta-builder-agent Differs from Other Agents

The meta-builder-agent is a significant outlier in the agent ecosystem:

| Property | general-research-agent | meta-builder-agent |
|----------|----------------------|-------------------|
| Invoked by | skill-researcher | skill-meta |
| Return format | Brief text + metadata file | JSON to skill |
| Uses return-metadata-file.md | Yes | Partially (documented, but Stage 5 shows JSON return) |
| Handles status updates | Via skill postflight | N/A (creates tasks, no status to update) |
| Memory retrieval | Yes (via skill Stage 4a) | No |
| ROADMAP.md consultation | Yes (roadmap_path in delegation context) | No |
| model: field in frontmatter | Yes (opus) | Not specified |
| AskUserQuestion usage | No | Yes (required for interactive mode) |
| Writes to specs/ only | Yes (reports) | Yes (task directories) |

**Critical discrepancy found**: The agent's Stage 5 returns JSON to the skill:
```json
{
  "status": "tasks_created",
  "summary": "Created 3 tasks...",
  ...
}
```

But the general-research-agent writes to `.return-meta.json` and returns brief text. The `skill-meta/SKILL.md` Stage 4 does validate JSON return, NOT read a metadata file. This is an intentional architectural difference because meta is task-creation, not task-execution.

**However**, `meta-builder-agent.md` Stage 5 says "Return ONLY valid JSON" as a CRITICAL REQUIREMENT - but `skill-meta/SKILL.md` says "This skill implements the skill-internal postflight pattern." This is consistent but unusual compared to the research/plan/implement pattern.

### 3. Pattern Comparison: /meta vs /research -> /plan -> /implement

**Command Structure**:
- `/research`, `/plan`, `/implement` all follow identical structure: STAGE 0 (parse args) -> STAGE 1.5 (flags) -> STAGE 2 (delegate) -> CHECKPOINT 2 (gate out) -> CHECKPOINT 3 (commit)
- `/meta` follows: Mode Detection -> Delegate to skill-meta (which spawns meta-builder-agent)

**Key Pattern Violations by /meta**:
1. `/meta` does NOT implement GATE IN / GATE OUT / COMMIT checkpoint structure
2. `/meta` does NOT parse task numbers (correct - it creates tasks, not operates on existing ones)
3. `/meta` does NOT accept `--team`, `--fast/--hard`, `--haiku/--sonnet/--opus` flags
4. `/meta` does NOT support multi-task syntax in arguments
5. `/meta` does NOT pass `session_id` to skill via args (skill generates its own)

**Things /meta does correctly**:
1. Delegates to skill via Skill tool (not direct implementation)
2. Returns based on skill result (tasks created / cancelled / analyzed)
3. Uses AskUserQuestion for interactive mode (via agent)
4. Creates task directories under specs/

### 4. Memory Integration Analysis

The memory system (`memory-retrieve.sh`) is invoked in `skill-researcher` Stage 4a:
```bash
memory_context=$(bash .claude/scripts/memory-retrieve.sh "$description" "$task_type" "$focus_prompt" 2>/dev/null) || memory_context=""
```

The script uses keyword overlap scoring against `memory-index.json` and injects relevant memories as `<memory-context>` blocks into the research agent's prompt.

**Current /meta memory integration: NONE**

The `skill-meta/SKILL.md` has no Stage 4a equivalent. The `meta-builder-agent.md` has no memory retrieval step. `/meta` benefits from memories only accidentally (via the broader Claude Code memory system at the conversation level).

**Integration opportunity**: Before the meta-builder-agent conducts its interview, `skill-meta` could call `memory-retrieve.sh` with the user's prompt or the domain they indicate. This would inject relevant past memories about:
- Previous component creation patterns
- Common dependency structures identified in past meta sessions
- Anti-patterns to avoid (documented in memory as INSIGHT or PATTERN categories)

The `.memory/memory-index.json` exists and has entries. The script is already in `.claude/scripts/`. Integration would require only 5-10 lines added to `skill-meta/SKILL.md` Stage 2.

**Non-blocking dependency requirement**: The integration should be optional (fail-gracefully). The `memory-retrieve.sh` already exits 1 silently on failure, making this safe to add.

### 5. ROADMAP.md Relationship

The `skill-researcher` delegation context includes `roadmap_path: "specs/ROADMAP.md"`. The general-research-agent reads this to understand current phase priorities. The `meta-builder-agent` receives no such context.

**Current ROADMAP.md priorities** (Phase 1, relevant to /meta):
- Agent System Quality section mentions: agent frontmatter validation, subagent-return reference cleanup
- Documentation Infrastructure: manifest-driven README generation

These are exactly the kinds of changes /meta would create tasks for. Including roadmap context in the meta-builder-agent's delegation would help it:
1. Detect when a proposed change is already a roadmap priority
2. Suggest tasks that align with current phase priorities
3. Potentially link new tasks to roadmap items (like other agents do via `roadmap_items` field)

**How other agents use it**: The general-research-agent's Stage 1.5 loads the roadmap file and extracts current phase priorities if `roadmap_path` is provided. This is READ-ONLY consultation.

### 6. Extension System Integration

`/meta` lives entirely in the `core` extension (`manifest.json` lists `meta.md` in commands, `skill-meta` in skills, `meta-builder-agent.md` in agents). The core extension has `routing_exempt: true`, meaning it provides base infrastructure but not task-type routing entries.

**Interaction with other extensions**: When a user runs `/meta` to create tasks for a new extension (e.g., adding a new `python` extension), the meta-builder-agent creates `task_type: "meta"` tasks (or potentially `task_type: "general"` if the user doesn't indicate system work). However, meta-builder-agent has a hardcoded DetectDomainType classification:

```
# From meta-builder-agent.md Stage 2.5
Keywords: "command", "skill", "agent", "meta", ".claude/" -> task_type = "meta"
Otherwise -> task_type = "general"
```

This means tasks created by `/meta` for extension development could be type "general" unless the keywords trigger the meta classification. Task 486 already identified this as a bug (hardcoded `latex` type - now removed by task 486).

**No extension contributes to /meta routing**: Unlike neovim or nix extensions that add their own research/implement skills, no extension adds to /meta's behavior. The meta system is purely core infrastructure.

### 7. Multi-Task Creation Standard Compliance

`meta.md` explicitly states: "**Reference Implementation**: This command is the reference implementation for the multi-task creation standard."

The 8-component compliance table from `meta.md`:

| Component | Status | Implementation |
|-----------|--------|----------------|
| Discovery | Yes | Interview Stage 2-3 |
| Selection | Yes | Interview Stage 5 (ReviewAndConfirm) |
| Grouping | Yes | User-defined in Stage 3 |
| Dependencies | Full | Stage 3 Question 5 (internal + external) |
| Ordering | Yes | Stage 6 (Kahn's algorithm) |
| Visualization | Yes | Stage 7 (linear chain / layered DAG) |
| Confirmation | Yes | Stage 5 (mandatory) |
| State Updates | Yes | Stage 6 (batch insertion) |

The `multi-task-creation-standard.md` document explicitly names `/meta` as the reference implementation: "The `/meta` command and `meta-builder-agent` serve as the reference implementation."

### 8. What the Current meta-guide.md Gets Wrong

The current `meta-guide.md` (462 lines) describes a completely different system:

| What meta-guide.md says | What actually exists |
|------------------------|---------------------|
| `.opencode/agent/subagents/` paths | `.claude/agents/` and `.claude/skills/` |
| 12-question interview across 5 phases | 7-stage interview in meta-builder-agent |
| "Phase 1: Domain & Purpose" etc. | Stage 3A: Interactive Interview stages 0-7 |
| Creates complete `.opencode/` structure | Creates tasks only (specs/TODO.md, state.json) |
| "+20% routing accuracy" | No such claim anywhere in current system |
| "3-level context allocation" | Context loaded lazily by agents |
| Questions about "how many agents" | Questions about task breakdown and dependencies |
| Generate README.md, workflows/, etc. | Creates task entries with dependency visualization |
| `.claude/context/standards/commands.md` | Broken reference - file does NOT exist |
| Reference to `.claude/agent/subagents/meta.md` | File does NOT exist |

The file is from a completely different era of the system (likely an early `.opencode/` era before the current `.claude/` agent system was built).

---

## Integration Opportunities

### Opportunity 1: Memory Retrieval for /meta (High Value, Low Cost)

Add memory retrieval to `skill-meta` Stage 2, before spawning `meta-builder-agent`. Pass the user's prompt (or "meta system building" as description) with `task_type: "meta"` to `memory-retrieve.sh`. If memories are found, inject them into the delegation context.

**Benefit**: Agents that have been used before to create similar tasks can surface past decisions, anti-patterns, and successful patterns. E.g., if /meta was previously used to create commands for export functionality, memories about that experience can inform new export-related tasks.

**Implementation**: ~10 lines in skill-meta, already has the infrastructure.

### Opportunity 2: ROADMAP.md Context for meta-builder-agent (Medium Value, Low Cost)

Pass `roadmap_path: "specs/ROADMAP.md"` in the delegation context from `skill-meta` to `meta-builder-agent`. Add a Stage 1.5 to meta-builder-agent that reads ROADMAP.md when in interactive or prompt mode, extracts Phase 1 items, and uses them to:
1. Warn if a proposed new task duplicates a roadmap item
2. Suggest tasks that fill roadmap gaps
3. Optionally set `roadmap_items` when creating tasks

**Benefit**: Keeps /meta-created tasks aligned with project priorities. Non-blocking - fail gracefully if ROADMAP.md doesn't exist.

### Opportunity 3: No --team Mode (Intentional Gap)

`/meta` correctly does NOT support `--team` mode. Team mode for task creation would be confusing. This is not a gap - it's correct design.

---

## Pattern Comparisons

### Command Pattern: /meta vs /research

```
/research:
  STAGE 0 (parse task#) -> STAGE 1.5 (flags) -> STAGE 2 (delegate skill) -> CHECKPOINT 2 (gate out) -> CHECKPOINT 3 (commit)

/meta:
  Mode detection -> Delegate to skill-meta (thin wrapper) -> Present results
```

/meta is intentionally simpler because:
- It doesn't operate on existing tasks (no task# to parse)
- It doesn't need status lifecycle (no RESEARCHING -> RESEARCHED)
- It is itself the beginning of a task lifecycle

### Skill Pattern: skill-meta vs skill-researcher

```
skill-researcher:
  Stage 1 (validate) -> Stage 2 (preflight status) -> Stage 3 (postflight marker) ->
  Stage 3a (artifact number) -> Stage 4a (MEMORY RETRIEVAL) -> Stage 4 (delegation context) ->
  Stage 4b (format injection) -> Stage 5 (invoke agent) -> Postflight (stages 6-10)

skill-meta:
  Input Validation -> Context Preparation -> Invoke Subagent -> Return Validation -> Return Propagation
```

`skill-meta` is dramatically simpler. It does NOT:
- Update task status (correct - it creates tasks, not operates on them)
- Retrieve memories (gap - should be added)
- Increment artifact numbers (correct - no artifacts in meta mode)
- Link artifacts to TODO.md (correct)
- Validate artifact content (N/A)

### Agent Pattern: meta-builder-agent vs general-research-agent

`general-research-agent` follows the 8-stage flow from its system prompt and writes to `.return-meta.json`. `meta-builder-agent` follows a 7-stage interview workflow and returns JSON directly. These are fundamentally different patterns that serve different purposes.

The meta-builder-agent's JSON return is intentional: the skill needs to know how many tasks were created to generate the git commit message and present output. Research/plan/implement agents don't need this - the skill reads the metadata file.

---

## Evidence and Examples

### Evidence 1: meta task_type routing to skill-researcher

From `research.md` STAGE 2 extension routing code:
```bash
# Fallback to default researcher if no extension routing found
skill_name=${skill_name:-"skill-researcher"}
```

From `skill-researcher/SKILL.md` trigger conditions:
```
This skill activates when:
- Task type is "general", "meta", "markdown", "latex", or "typst"
```

This confirms meta tasks use skill-researcher for research.

### Evidence 2: meta tasks in state.json

Confirmed from live state.json inspection - tasks 485, 486, 482, 483, 484 all have `"task_type": "meta"` and no special fields distinguishing them from general tasks. They use the same status fields, the same artifact linking, and the same completion workflow.

### Evidence 3: Memory retrieval gap

`skill-meta/SKILL.md` has no reference to `memory-retrieve.sh`. Searching the skill file reveals no Stage 4a equivalent. The memory system documentation in CLAUDE.md states "Memory retrieval is automatic: when the memory extension is loaded, `/research`, `/plan`, and `/implement` preflight stages call `memory-retrieve.sh`" - notably, `/meta` is NOT listed.

### Evidence 4: ROADMAP.md not passed to meta-builder-agent

`skill-meta/SKILL.md` Stage 2 delegation context:
```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "meta", "skill-meta"],
  "timeout": 7200,
  "mode": "interactive|prompt|analyze",
  "prompt": "{user prompt if mode=prompt, null otherwise}"
}
```

No `roadmap_path` field. Compare to `skill-researcher/SKILL.md`:
```json
{
  ...
  "roadmap_path": "specs/ROADMAP.md",
  ...
}
```

### Evidence 5: The /meta command output says wrong things about next steps

From `meta.md` output template:
```
Next Steps:
1. Review tasks in TODO.md
2. Run /research {N} to begin research on first task
3. Progress through /research -> /plan -> /implement cycle
```

This IS accurate and correctly describes the flow. The broken part is `meta-guide.md`, not `meta.md`.

### Evidence 6: meta-builder-agent.md documents the wrong return pattern

In `meta-builder-agent.md` Stage 5, it documents a JSON return format. But the current `skill-meta/SKILL.md` says "This skill implements the skill-internal postflight pattern" and validates "Status is one of: completed, partial, failed, blocked" - which is the return-metadata-file.md schema, not the task_created/cancelled/analyzed schema documented in meta-builder-agent.md Stage 5.

This is a minor inconsistency: the skill validates for one schema while the agent returns another. This warrants documentation alignment.

---

## Decisions

1. The new meta-guide.md should document the ACTUAL system: 3 modes, 7-stage interview, multi-task creation standard
2. The new guide should accurately describe the command/skill/agent triple
3. The new guide should document how meta tasks flow through /research -> /plan -> /implement
4. The new guide should mention the memory integration opportunity WITHOUT describing it as current behavior
5. The ROADMAP.md consultation should be documented as recommended practice for the agent

---

## Risks and Mitigations

- **Risk**: meta-builder-agent return schema inconsistency (JSON vs return-metadata-file.md) may confuse implementers
  - **Mitigation**: Document the intentional difference in meta-guide.md - meta returns task_created/cancelled/analyzed, not researched/implemented
- **Risk**: Adding memory retrieval to /meta could slow the interactive interview
  - **Mitigation**: Memory retrieval is async-safe and already fails gracefully (exit 1 = skip)
- **Risk**: ROADMAP.md context could bias meta toward roadmap items inappropriately
  - **Mitigation**: Read-only consultation; agent decides whether roadmap context is relevant

---

## Context Extension Recommendations

- **Topic**: Current /meta system documentation vs phantom system
- **Gap**: meta-guide.md documents a completely different system from what exists
- **Recommendation**: Full rewrite is the correct approach (as task 485 specifies)

- **Topic**: Memory integration for /meta
- **Gap**: No context file documents how /meta could integrate with .memory/ system
- **Recommendation**: Add brief mention in new meta-guide.md describing the integration opportunity

---

## Appendix

### Files Examined
- `/home/benjamin/.config/nvim/.claude/commands/meta.md`
- `/home/benjamin/.config/nvim/.claude/skills/skill-meta/SKILL.md`
- `/home/benjamin/.config/nvim/.claude/agents/meta-builder-agent.md`
- `/home/benjamin/.config/nvim/.claude/commands/research.md`
- `/home/benjamin/.config/nvim/.claude/commands/plan.md`
- `/home/benjamin/.config/nvim/.claude/commands/implement.md`
- `/home/benjamin/.config/nvim/.claude/skills/skill-researcher/SKILL.md`
- `/home/benjamin/.config/nvim/.claude/context/standards/interactive-selection.md`
- `/home/benjamin/.config/nvim/.claude/scripts/memory-retrieve.sh`
- `/home/benjamin/.config/nvim/specs/ROADMAP.md`
- `/home/benjamin/.config/nvim/.claude/extensions/core/manifest.json`
- `/home/benjamin/.config/nvim/.claude/context/meta/meta-guide.md`
- `/home/benjamin/.config/nvim/.claude/docs/reference/standards/multi-task-creation-standard.md`
- `/home/benjamin/.config/nvim/specs/state.json` (meta task entries)
- `/home/benjamin/.config/nvim/specs/TODO.md` (task 485, 486 entries)
- `/home/benjamin/.config/nvim/.claude/context/index.json`

### Key Search Queries Used
- jq on state.json for meta task_type entries
- Codebase grep for memory-retrieve.sh references in skills
- Comparison of skill-researcher and skill-meta stage structures
