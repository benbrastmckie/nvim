# Research Report: Task #485

**Task**: Rewrite meta-guide.md to match current system
**Date**: 2026-04-19
**Mode**: Team Research (4 teammates)

## Summary

The current `meta-guide.md` (462 lines) is entirely fictional: it describes a phantom 5-phase/12-question interview, `.opencode/agent/subagents/` paths, fabricated performance statistics (+20% routing accuracy), and a 3-level context allocation model that does not exist. The actual `/meta` system is a 3-mode command (interactive/prompt/analyze) with a 7-stage interview, AskUserQuestion enforcement, Kahn's topological sorting for dependencies, and DAG visualization. The file requires a complete ground-up rewrite, not incremental editing.

Two significant ancillary findings: (1) `/meta` is the only major command lacking memory integration -- skill-researcher, skill-planner, and skill-implementer all call `memory-retrieve.sh`, but skill-meta does not; (2) meta-builder-agent uses v1 console JSON return while all other agents use v2 file-based protocol, making skill-meta's claimed postflight non-functional. Both are out of scope for the rewrite itself but should be documented as known gaps.

## Key Findings

### Primary Analysis (from Teammate A)

**14 specific inaccuracies identified** in the current meta-guide.md:

1. **Fundamental purpose wrong**: Guide says /meta "creates agents and commands." Reality: /meta ONLY creates tasks in TODO.md/state.json. Implementation happens later via /implement.
2. **Phantom output structure**: Guide describes `.claude/agent/{domain}-orchestrator.md`, `subagents/`, `workflows/`, `command/` -- none created by /meta.
3. **Fake interview**: Guide documents 4 phases with 12 questions (Domain, Use Cases, Complexity, Integration). Real system has 7 stages: DetectExistingSystem, InitiateInterview, GatherDomainInfo, IdentifyUseCases, AnalyzeTopics, AssessComplexity, ReviewAndConfirm, CreateTasks, DeliverSummary.
4. **Three modes undocumented**: Interactive (no args), Prompt (with text), Analyze (--analyze) never mentioned.
5. **Performance claims fabricated**: "+20% routing accuracy", "+25% consistency", "80% context efficiency" have no basis in deployed code.
6. **Task dependency system missing**: Kahn's algorithm, DAG visualization, dependency validation -- completely undocumented.
7. **Topic clustering (Stage 3.5) missing**: Optional consolidation step never mentioned.
8. **Critical constraint missing**: /meta MUST NOT create files directly, MUST use AskUserQuestion for all choices, MUST get confirmation before task creation.
9. **Wrong resource links**: Guide points to `.claude/agent/subagents/meta.md` (doesn't exist). Actual path: `.claude/agents/meta-builder-agent.md`.
10. **`.opencode` label**: Header says "Complete .opencode Structure" but shows `.claude/` paths -- copy-paste artifact from different system.
11. **Wrong subagent types**: Lists "Research Agent, Validation Agent, Processing Agent" -- not components of /meta.
12. **Wrong testing section**: Describes testing orchestrators, subagents, workflows -- /meta creates none of these.
13. **Wrong context paths**: Generic `domain/`, `processes/` layout doesn't match actual `meta/`, `formats/`, `patterns/`, `architecture/` structure.
14. **Stale companion files**: interview-patterns.md references old stages, architecture-principles.md says ".opencode", standards-checklist.md lists non-existent frontmatter fields.

### Cross-References and Integration (from Teammate B)

**How /meta interacts with the broader system**:

- Meta tasks route through standard pipeline: `/research` -> skill-researcher, `/plan` -> skill-planner, `/implement` -> skill-implementer. No special meta-specific agents for these phases -- meta-builder-agent is ONLY used by `/meta` itself.
- Meta tasks in state.json look identical to general tasks (same fields, same status lifecycle).
- The core extension has `routing_exempt: true` -- no task-type routing entries. Meta tasks fall through to default skills.

**Pattern comparison with other command/skill/agent triples**:

| Property | /research | /meta |
|----------|-----------|-------|
| Checkpoint structure | GATE IN/GATE OUT/COMMIT | Mode detection -> delegate |
| Status lifecycle | RESEARCHING -> RESEARCHED | N/A (creates tasks, doesn't operate on them) |
| Memory retrieval | Yes (Stage 4a) | **No** |
| ROADMAP.md context | Yes (roadmap_path) | **No** |
| Return protocol | v2 file-based (.return-meta.json) | **v1 console JSON** |
| Postflight | Full (10+ stages) | **Minimal (git commit in agent, not skill)** |
| Artifact linking | Yes | N/A |
| --team/--fast/--hard flags | Yes | **No** |

**Multi-task creation standard**: /meta is documented as the reference implementation with all 8 components (Discovery, Selection, Confirmation, State Updates, Grouping, Dependencies, Ordering, Visualization).

### Gaps and Shortcomings (from Critic)

**5 system shortcomings identified**:

1. **v1 return protocol mismatch (High)**: Agent header claims v2 file-based return; body says "Return ONLY valid JSON." Agent writes no `.return-meta.json`. Skill-meta's postflight validation reads from a file the agent never writes. Git commits happen inside the agent (Stage 6), not in skill-meta's declared postflight. The "skill-internal postflight" claim is fiction.

2. **meta-guide.md loaded as always-available context (High)**: CLAUDE.md line 300 lists it as a core context import. 462 lines of phantom documentation pollute context for EVERY agent, not just meta tasks. The index.json correctly scopes it to meta contexts, but CLAUDE.md overrides this.

3. **Broken `commands.md` reference (Medium)**: meta-guide.md line 9 references `.claude/context/standards/commands.md` which does not exist.

4. **skill-meta has no postflight mechanism (Medium)**: No `.postflight-pending` marker creation, no `update-task-status.sh` call, no artifact linking code. Intentional architectural difference (meta creates tasks, not artifacts), but the "skill-internal postflight" label is misleading.

5. **DetectDomainType is vestigial (Low)**: After task 486 removed the hardcoded `latex` branch, the function only distinguishes "meta" vs "general" based on keywords. Every `/meta` invocation is about the `.claude/` system by definition, making the classification mostly redundant.

**5 rewrite risks identified**:

1. Documenting aspirational v2 protocol as if it works (when agent body still says v1)
2. Scope creep into system redesign vs documenting current state
3. Reproducing pseudocode blocks (Kahn's algorithm) as "actual behavior" when they're LLM guidance
4. Failing to update CLAUDE.md's always-available import alongside the rewrite
5. Only updating deployed copy while extension source diverges (task description correctly calls for both)

### Strategic Horizons (from Teammate D)

**Roadmap alignment**: No /meta-specific roadmap items exist. The rewrite serves as foundation for "Agent System Quality" (Phase 1) -- accurate documentation enables future frontmatter validation and lint scripts. The rewrite does not block or depend on any roadmap items.

**Memory integration opportunities** (ordered by value):

1. **Memory retrieval during task creation (HIGH)**: Add Stage 4a to skill-meta (identical to skill-researcher). When user runs `/meta "create skill for X"`, retrieved memories about past similar work (patterns, anti-patterns, decisions) inform the interview. Implementation: ~10 lines, uses existing `memory-retrieve.sh`, fails gracefully.

2. **Roadmap-aware priority hints (MEDIUM)**: Pass `roadmap_path` in delegation context. During ReviewAndConfirm (Stage 5), agent checks if proposed tasks align with roadmap priorities. Non-blocking -- fail silently if ROADMAP.md doesn't exist.

3. **Suppress memory for analyze mode (LOW/EASY)**: Analyze mode doesn't create tasks and doesn't benefit from memory. Match `--clean` behavior.

**Stale sister files**: `architecture-principles.md` and `standards-checklist.md` reference non-existent frontmatter fields (`temperature`, `max_tokens`, `delegation.can_delegate_to`) and removed tools (`status-sync-manager`, `git-workflow-manager`). Follow-on tasks needed after 485.

## Synthesis

### Conflicts Resolved

**Conflict 1: Scope -- document current state vs. improve the system**
- Teammates A/B: Document the actual 7-stage system accurately
- Teammate C: Warns about scope creep into redesign
- Teammate D: Wants to incorporate memory/roadmap improvements
- **Resolution**: The rewrite MUST document current system accurately first. Include a "Known Limitations" section listing v1 protocol, missing postflight, and missing memory integration. Include a "Future Extensions" section for memory/roadmap opportunities. Do NOT implement any system changes as part of the guide rewrite.

**Conflict 2: v2 return protocol -- document as current or note the mismatch?**
- Teammate B: Notes intentional architectural difference (agent returns JSON for task count feedback)
- Teammate C: Flags as split-brain bug (header says v2, body says v1)
- **Resolution**: Document the ACTUAL behavior (v1 console JSON return, git commit inside agent). Note the mismatch between agent header and body. Do NOT document v2 as current. The v1-to-v2 migration is a separate task.

**Conflict 3: Memory integration -- implement now or defer?**
- Teammates B/D: Integration is ~10 lines, low risk, high value
- Teammate C: Out of scope for a documentation rewrite
- **Resolution**: Document memory integration as a specific improvement opportunity in the guide's "Future Extensions" section. Do NOT implement it in task 485. Create a follow-on task for the actual integration work.

### Gaps Identified

1. **CLAUDE.md cleanup**: The always-available import of meta-guide.md in CLAUDE.md must be removed or conditioned alongside the rewrite. This is an essential companion change, not optional.
2. **Sister file staleness**: `architecture-principles.md`, `standards-checklist.md`, and `interview-patterns.md` have related but separate staleness issues. Follow-on tasks needed.
3. **Analyze mode verification**: No evidence of `--analyze` mode being used in practice. The rewrite should document it as specified but note it's the least-tested mode.
4. **Commit format gap**: meta-builder-agent uses `meta: create {N} tasks for {domain}` commit format, which is not listed in `skill-git-workflow/SKILL.md`'s format table.

### Recommendations

1. **Complete ground-up rewrite** -- structural mismatch is too deep for surgical editing
2. **Structure around 3 modes** (interactive/prompt/analyze) as primary organization
3. **Document the actual 7-stage interview** at conceptual level (what each stage does, what questions are asked) -- do NOT reproduce pseudocode from agent file
4. **Document multi-task creation standard compliance** prominently (all 8 components)
5. **Include "Known Limitations" section** for v1 protocol, missing postflight, missing memory
6. **Include "Future Extensions" section** for memory integration and roadmap awareness
7. **Update CLAUDE.md** to remove meta-guide.md from always-available imports (index.json already has correct conditional loading)
8. **Update both copies**: extension source (`.claude/extensions/core/context/meta/meta-guide.md`) and deployed copy (`.claude/context/meta/meta-guide.md`)
9. **Fix the broken reference** to `.claude/context/standards/commands.md`
10. **Note follow-on tasks** for sister file updates (architecture-principles.md, standards-checklist.md)

### Recommended Guide Structure

```
# Meta Guide: /meta Command Reference

## Overview
- Purpose: interactive task creator for .claude/ system changes
- Critical distinction: creates tasks, not implementations
- Delegation chain: command -> skill-meta -> meta-builder-agent -> TODO.md/state.json

## Modes
### Interactive Mode (no arguments)
### Prompt Mode (/meta "description")
### Analyze Mode (/meta --analyze)

## Interactive Interview (7 Stages)
- Stage 0-7 with actual questions and AskUserQuestion patterns

## Task Dependency System
- Dependency types (none, linear chain, custom DAG, external)
- Validation (self-reference, circular dependency)
- Topological sorting (Kahn's algorithm)
- Visualization (linear chain vs layered DAG)

## Multi-Task Creation Standard
- All 8 components documented
- /meta as reference implementation

## What You Get
- Task entries in TODO.md and state.json
- Task directories in specs/NNN_slug/
- Dependency visualization
- Next steps: /research N

## After /meta: The Lifecycle
- /research -> /plan -> /implement cycle
- Meta tasks route through standard skills (no special agents)

## Known Limitations
- v1 return protocol (agent returns console JSON, not file-based)
- Minimal postflight (git commit inside agent, not skill)
- No memory integration (unlike research/plan/implement)

## Future Extensions
- Memory retrieval during task creation
- Roadmap-aware priority hints
- Sister file updates needed

## Resources
- Actual file paths to command, skill, agent
```

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | Primary /meta system analysis | completed | high |
| B | Cross-reference and integration | completed | high |
| C | Critic (gaps and risks) | completed | high |
| D | Strategic horizons | completed | high |

## References

- `.claude/context/meta/meta-guide.md` -- current phantom guide (to be rewritten)
- `.claude/agents/meta-builder-agent.md` -- canonical source of truth for actual behavior
- `.claude/skills/skill-meta/SKILL.md` -- skill wrapper
- `.claude/commands/meta.md` -- command entry point
- `.claude/context/meta/interview-patterns.md` -- companion file (stale)
- `.claude/context/meta/architecture-principles.md` -- companion file (stale)
- `.claude/context/meta/standards-checklist.md` -- companion file (stale)
- `.claude/context/meta/domain-patterns.md` -- companion file (partially relevant)
- `.claude/context/meta/context-revision-guide.md` -- companion file (mostly accurate)
- `.claude/scripts/memory-retrieve.sh` -- memory integration infrastructure
- `specs/ROADMAP.md` -- project roadmap
- `.claude/docs/reference/standards/multi-task-creation-standard.md` -- multi-task standard
- `.claude/context/standards/interactive-selection.md` -- interactive selection patterns
