# Research Report: Task #485 -- Teammate D (Horizons)

**Task**: 485 - Rewrite meta-guide.md to match current system
**Angle**: Strategic direction, long-term alignment, and memory integration
**Started**: 2026-04-19T00:00:00Z
**Completed**: 2026-04-19T00:30:00Z
**Effort**: 1 hour
**Sources/Inputs**: ROADMAP.md, .memory/ vault, skill-meta/SKILL.md, skill-researcher/SKILL.md, skill-planner/SKILL.md, meta-builder-agent.md, .claude/context/meta/* (all 5 files), .claude/scripts/memory-retrieve.sh
**Artifacts**: This report
**Standards**: report-format.md

---

## Executive Summary

- The current `meta-guide.md` documents a phantom system with wrong paths, fabricated statistics, and a 5-phase interview structure that does not exist in the deployed agent
- The rewrite must ground the document in the actual 3-mode / 7-stage interview system that `meta-builder-agent.md` implements
- Memory integration for `/meta` is conspicuously absent: all other major skills (researcher, planner, implementer) call `memory-retrieve.sh` during preflight; `/meta` does not -- this is the most consequential strategic gap
- The roadmap contains no `/meta`-specific items; the rewrite itself is the roadmap item, and the rewritten guide should anticipate future roadmap phases
- Three unconventional improvements could significantly lift task quality: memory-informed task suggestions, roadmap-aware prioritization hints, and a lightweight `--context` flag that auto-imports known past tasks on similar topics

---

## Context & Scope

Task 485 calls for a complete rewrite of `.claude/context/meta/meta-guide.md` (and its extension source at `.claude/extensions/core/context/meta/meta-guide.md`). The file is 462 lines. The current content was written for an earlier system and documents:

- A 5-phase, 12-question interview across "Domain & Purpose", "Use Cases & Workflows", "Complexity & Scale", "Integration & Tools", "Review & Confirmation"
- `.opencode/agent/subagents/` directory paths (wrong -- actual system uses `.claude/agents/`)
- Marketing-style accuracy claims: "+20% routing accuracy", "+25% consistency", "80% context efficiency", "+17% overall performance" (unverifiable; not reflected in any agent code)
- A "3-level context allocation" model (not implemented in any current agent)
- References to `.claude/context/standards/commands.md` (file may not exist at this path)

The actual system (read from `meta-builder-agent.md` and `skill-meta/SKILL.md`) operates as follows:

- **3 modes**: interactive, prompt, analyze
- **7-stage interview** (interactive mode): DetectExistingSystem, InitiateInterview, GatherDomainInfo, IdentifyUseCases (with AnalyzeTopics clustering at 3.5), AssessComplexity, ReviewAndConfirm, CreateTasks, DeliverSummary
- **AskUserQuestion with `options` arrays** -- NEVER plain text option lists
- **Topological sorting** (Kahn's algorithm) for dependency ordering before task creation
- **Linear vs. DAG visualization** with box-drawing characters
- **Multi-task creation standard** compliance (all 8 components)
- Artifacts: tasks in `specs/TODO.md` + `specs/state.json` only (no implementation files)

Both the context file at `.claude/context/meta/meta-guide.md` and the extension source at `.claude/extensions/core/context/meta/meta-guide.md` are identical and equally stale.

---

## Key Findings

### Finding 1: The Current Guide Is a Mismatch at Every Level

The guide describes a system that does not exist in the deployed code. Every major claim is wrong:

| Claim in current guide | Actual system |
|---|---|
| 5-phase, 12-question interview | 7-stage interview in interactive mode |
| `.opencode/agent/subagents/` paths | `.claude/agents/` |
| "Complete .opencode Structure" | Tasks only, no direct file creation |
| 3-level context allocation | Not implemented |
| "+20% routing accuracy" | No metrics, no measurement |
| `context_level`, `language` YAML fields | Not in current skill/command frontmatter |
| Reference to `commands.md` standard | That file may not exist in this project |

The rewrite must delete all of this and replace it with accurate descriptions of the 3-mode system.

### Finding 2: Memory Integration Is Completely Missing from /meta

By contrast with every other major skill in the system:

| Skill | Memory retrieval in preflight? |
|---|---|
| skill-researcher | YES -- Stage 4a, calls `memory-retrieve.sh` |
| skill-planner | YES -- Stage 4a (same pattern) |
| skill-implementer | YES (same pattern) |
| skill-meta | **NO -- zero memory integration** |

When a user runs `/meta` to create a task, they receive no benefit from past session knowledge stored in `.memory/`. This is a significant gap. The memory vault already contains at least one directly relevant memory (`MEM-plan-delegation-required.md`) about the delegation chain enforcement that was learned in task 414/416. This knowledge is exactly the kind of thing that should inform `/meta` task creation: if the user wants to create a skill that bypasses delegation, the memory system knows this causes format failures.

### Finding 3: The Memory System Is Mature Enough to Integrate

The `.memory/` vault infrastructure is well-developed:
- `memory-retrieve.sh` is a production-quality two-phase scorer (keyword overlap + topic match)
- It respects a `TOKEN_BUDGET=2000` and `MAX_ENTRIES=5` ceiling
- It updates retrieval counts for LRU-style health tracking
- It exits 0 with `<memory-context>` block on success, exits 1 cleanly on no match
- The `--clean` flag already exists on `/research`, `/plan`, `/implement` to suppress it

The integration pattern for skill-meta would be identical to skill-researcher Stage 4a:

```bash
# In skill-meta, after mode detection but before subagent invocation
if [ "$mode" = "interactive" ] || [ "$mode" = "prompt" ]; then
  memory_context=$(bash .claude/scripts/memory-retrieve.sh \
    "$prompt_or_description" "meta" "" 2>/dev/null) || memory_context=""
fi
```

The retrieved context would be injected into the meta-builder-agent's prompt alongside delegation context, giving the agent awareness of past patterns, mistakes, and conventions when creating new tasks.

### Finding 4: The Roadmap Has No /meta-Specific Items

Reading `specs/ROADMAP.md`:

**Phase 1 (Current Priorities)**:
- Documentation infrastructure (extension READMEs, marketplace metadata, CI enforcement)
- Agent system quality (extension slim standard lint, agent frontmatter validation, subagent-return reference cleanup)

**Phase 2 (Medium-Term)**:
- Extension hot-reload
- Context discovery caching

None of these items are specifically about `/meta` behavior. However, the "agent frontmatter validation" item in Phase 1 is adjacent: it calls for validating that every agent file uses the minimal frontmatter standard. This work was partially addressed by task 486 (just completed). The meta-guide rewrite (task 485) should document the current minimal frontmatter standard that task 486 enforced.

The roadmap's Phase 2 item "Context discovery caching" is relevant to `/meta` performance: when `meta-builder-agent` runs `ls .claude/commands/*.md`, `find .claude/skills -name "SKILL.md"`, and `ls .claude/agents/*.md` during DetectExistingSystem, this is repeated context discovery work that could eventually benefit from caching.

### Finding 5: The context/meta/ Directory Files Are Also Stale

Reading all 5 files under `.claude/context/meta/`:

| File | Issue |
|---|---|
| `meta-guide.md` | Primary problem file (see above) |
| `architecture-principles.md` | References `.opencode` system terms; describes "8-stage workflow" that meta agents don't follow; mentions `status-sync-manager` and `git-workflow-manager` which don't exist |
| `interview-patterns.md` | Mostly valid patterns, but checkpoint format uses plain text yes/no -- should note AskUserQuestion requirement |
| `domain-patterns.md` | References "Extension Domain Pattern" correctly, but `domain-patterns.md` refers to removed `agent-template.md` |
| `standards-checklist.md` | Describes XML frontmatter fields (`temperature`, `max_tokens`, `delegation.can_delegate_to`) that don't exist in current agents; scoring rubric targets different system |
| `context-revision-guide.md` | Generally accurate; references "status-sync-manager" and "git-workflow-manager" in revision workflow (outdated) |

The rewrite of `meta-guide.md` alone will leave readers confused if they follow cross-references into `architecture-principles.md` or `standards-checklist.md`. The strategic recommendation is to note these as follow-on tasks but not expand task 485's scope.

---

## Roadmap Alignment

The meta-guide rewrite serves the roadmap in two ways:

1. **Directly addresses "Agent System Quality"**: Accurate documentation of the actual agent system is a prerequisite for "agent frontmatter validation" (Phase 1) and any future linting scripts. A guide that describes non-existent fields would produce false positives in any lint check.

2. **Enables future /meta improvements**: Once the guide accurately describes the current system, future roadmap items can be scoped against it. Specifically:
   - Memory integration for /meta (currently absent) would be documented once implemented
   - Extension hot-reload (Phase 2) could inform a future `/meta` enhancement that detects newly-loaded extensions during the interview

**What the rewrite does NOT address** from the roadmap:
- CI enforcement (GitHub Actions) -- separate task
- Marketplace metadata -- separate task
- Context discovery caching -- separate task

The rewrite is the necessary foundation, not the destination.

---

## Memory Integration Opportunities

### Opportunity 1: Memory Retrieval During Task Creation (HIGH VALUE)

When `/meta` is run interactively or with a prompt, memory retrieval could inject:
- Past decisions about similar system components
- Known failure modes discovered in prior tasks
- Patterns that worked vs. patterns that caused problems

**Concrete example**: If the user runs `/meta "create a new skill for X"`, and the vault contains `MEM-plan-delegation-required.md` (which notes that bypassing delegation causes format failures), the agent could surface this: "Note: previous work established that skills must use the Task tool to spawn agents -- direct Write calls bypass validation."

**Implementation**: Add Stage 4a to skill-meta (identical to skill-researcher Stage 4a). Pass the user's prompt or the interview's gathered description as the query.

### Opportunity 2: Memory-Informed Task Description Quality (MEDIUM VALUE)

After a user finishes the interview, before CreateTasks, the agent could query memory for similar past task descriptions. If found, it could suggest description improvements: "A similar task (#414) benefited from explicitly noting the anti-bypass constraint -- should this task include that?" This is speculative but would leverage the growing vault.

### Opportunity 3: Suppress Memory for Analyze Mode (LOW VALUE / EASY WIN)

The `--clean` flag pattern is already established. Analyze mode does not create tasks and does not benefit from memory injection. The implementation should suppress memory retrieval for analyze mode, matching the `--clean` behavior of other commands.

### Implementation Notes from memory-retrieve.sh Analysis

The script is robust but has one relevant limitation: it only retrieves a maximum of 5 entries with a 2000-token budget. For /meta use cases, this is usually sufficient -- task creation context does not require deep recall. The `task_type="meta"` argument would give a topic match bonus (+2) to any memory entries whose `topic` field is `"meta"` or `"agent-system"`.

---

## Strategic Improvements

### Improvement 1: Accurate Mode Documentation

The rewrite must replace the 5-phase interview with the actual 3-mode system. The guide should be structured around the three modes, not a generic "interview process":

```
## Modes

### Interactive Mode (no arguments)
### Prompt Mode (/meta "description")
### Analyze Mode (/meta --analyze)
```

Each mode should describe its actual behavior from `meta-builder-agent.md`.

### Improvement 2: Document AskUserQuestion as Non-Negotiable

The current guide says nothing about the AskUserQuestion requirement. The agent definition is explicit: "ALL user choices MUST use AskUserQuestion with the `options` parameter." This should be surfaced prominently in the guide -- it is the most common failure mode for anyone writing a new agent that creates user interaction.

### Improvement 3: Document Multi-Task Creation Standard Compliance

The `meta-builder-agent.md` describes itself as "the reference implementation" of the multi-task creation standard. The guide should include a section on the 8 components:
1. Item Discovery
2. Interactive Selection
3. User Confirmation
4. State Updates
5. Topic Grouping
6. Dependency Declaration
7. Topological Sorting
8. Visualization

This is a key differentiator of the current system from the old system and deserves prominent documentation.

### Improvement 4: Topological Sorting and Dependency Visualization

The guide should explain that tasks are numbered in dependency order (foundational tasks get lower numbers) and that the visualization uses either linear chain format or layered DAG with box-drawing characters based on complexity detection. This is entirely absent from the current guide.

### Improvement 5: Remove All Unverifiable Performance Claims

"+20% routing accuracy", "+25% consistency", "80% context efficiency", "+17% overall performance" -- these claims have no basis in the deployed system and should be deleted entirely. They reduce trust in the document.

### Improvement 6: Fix Broken Cross-References

The current guide references:
- `.claude/context/standards/commands.md` -- verify this file exists and update path if not
- `.claude/agent/subagents/meta.md` -- does not exist; delete
- `.claude/README.md` -- verify exists

The rewrite should only link to files that actually exist and are part of the current system.

---

## Creative Approaches

### Approach 1: Memory-Informed Task Suggestion During Interview

During the interview's Stage 3 (IdentifyUseCases), the agent could optionally query memory for tasks with similar component types. If the user says "I want to create a new command for X", the agent could surface: "Similar commands created in the past include /fix-it (task 320) and /spawn (task 280). Their implementations might inform scope estimates." This requires no infrastructure change -- just a jq query on state.json for completed tasks with matching slugs.

### Approach 2: Roadmap-Aware Priority Hints

During ReviewAndConfirm (Stage 5), the agent could read `specs/ROADMAP.md` and check if any roadmap items match the task being created. If so, it could note: "This task relates to the Phase 1 roadmap item: 'Agent frontmatter validation'. Creating it here will track it through the standard research -> plan -> implement cycle." This gives the user roadmap traceability without requiring separate roadmap management.

**Implementation**: Add a jq query against ROADMAP.md in Stage 5 that looks for keyword overlap with the task title. Non-blocking -- if ROADMAP.md doesn't exist or no match found, proceed silently.

### Approach 3: Team Mode for Complex /meta Requests

Currently `/meta --team` is not a thing. However, for complex system redesigns (e.g., "I want to rebuild the entire extension system"), a team of meta-builder instances could be useful:
- Teammate A: analyze current system components
- Teammate B: research external patterns and best practices
- Teammate C: propose task breakdown

This is ambitious and would require changes beyond the guide rewrite, but the guide could note "For complex system redesigns, consider using /research with --team before /meta".

### Approach 4: `/meta --suggest` Subcommand

A `--suggest` mode that scans the codebase for TODO/FIX/NOTE tags (like `/fix-it`) and proposes meta-level improvements to the agent system itself. This would be a proactive mode that surfaces system health issues. Again, this is future work -- but the guide should leave room for it by not over-specifying what modes are possible.

---

## Confidence Level

**High confidence** (directly verified from source):
- The current guide is entirely inaccurate to the deployed system
- Memory integration is completely absent from `/meta`
- The memory-retrieve.sh infrastructure is mature and ready for integration
- The roadmap has no blocking dependencies on task 485

**Medium confidence** (reasoned from architecture):
- Memory integration for `/meta` would follow the skill-researcher Stage 4a pattern without modification
- The roadmap-aware priority hint approach is feasible with a simple text search
- The `context/meta/` sister files have related staleness issues requiring follow-on tasks

**Lower confidence** (speculative):
- Team mode for /meta would significantly increase task quality for complex redesigns
- The memory-informed task suggestion during interview would have measurable impact on task quality
- Whether the user experience improvements justify the complexity of a `--suggest` mode

---

## Decisions

1. The rewrite should be a ground-up replacement, not an incremental edit -- the structural mismatch is too deep for surgical fixes
2. Memory integration for `/meta` should be recommended as a follow-on task in the guide itself, not implemented as part of the rewrite
3. The guide should document the current system accurately first; future improvements (memory integration, roadmap awareness) should be noted as "Future Extensions" without blocking the core rewrite
4. The guide's primary audience is developers building on the system -- not end users -- so implementation details (Kahn's algorithm, AskUserQuestion constraints) should be retained

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Guide rewrite diverges from agent code | High -- misleads developers | Read meta-builder-agent.md as canonical source during rewrite |
| Related context files remain stale | Medium -- confusing cross-references | File follow-on task to update architecture-principles.md and standards-checklist.md |
| Memory integration recommendation lost | Low -- missed improvement | Document as "Future Extension" in guide; create separate task via /meta after 485 completes |
| Extension source and deployed copy diverge | High -- future reloads overwrite | Task description already calls for updating both copies |

---

## Context Extension Recommendations

- **Topic**: Memory integration for /meta skill
- **Gap**: No documentation of why /meta lacks memory retrieval while all other major skills include it; no guide for adding it
- **Recommendation**: After the rewrite, create `.claude/context/meta/memory-integration-guide.md` describing the pattern and the rationale for including/excluding memory in different command types

- **Topic**: Stale context/meta/* companion files
- **Gap**: `architecture-principles.md` and `standards-checklist.md` describe the old XML frontmatter system with non-existent fields (`temperature`, `max_tokens`, `delegation.can_delegate_to`)
- **Recommendation**: File a follow-on /meta task to update these files after 485 is complete

---

## Appendix: Key File Locations

- Source to rewrite: `/home/benjamin/.config/nvim/.claude/extensions/core/context/meta/meta-guide.md`
- Deployed copy: `/home/benjamin/.config/nvim/.claude/context/meta/meta-guide.md`
- Canonical agent (source of truth): `/home/benjamin/.config/nvim/.claude/agents/meta-builder-agent.md`
- Skill wrapper: `/home/benjamin/.config/nvim/.claude/skills/skill-meta/SKILL.md`
- Memory script: `/home/benjamin/.config/nvim/.claude/scripts/memory-retrieve.sh`
- Roadmap: `/home/benjamin/.config/nvim/specs/ROADMAP.md`
- Memory vault: `/home/benjamin/.config/nvim/.memory/`

## Appendix: Search Queries Used

- Read: `specs/ROADMAP.md`
- Read: `.claude/context/meta/meta-guide.md` (both copies)
- Read: `.claude/agents/meta-builder-agent.md`
- Read: `.claude/skills/skill-meta/SKILL.md`
- Read: `.claude/skills/skill-researcher/SKILL.md`
- Read: `.claude/skills/skill-planner/SKILL.md`
- Read: `.claude/scripts/memory-retrieve.sh`
- Read: `.memory/README.md`, `.memory/memory-index.json`
- Read: `.memory/10-Memories/MEM-plan-delegation-required.md`
- Read: All 5 files under `.claude/context/meta/`
- Grep: `specs/TODO.md` for meta-related tasks
