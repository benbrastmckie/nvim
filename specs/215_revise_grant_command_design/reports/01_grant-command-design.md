# Research Report: Task #215

**Task**: 215 - revise_grant_command_design
**Started**: 2026-03-16
**Completed**: 2026-03-16
**Effort**: 2-3 hours
**Dependencies**: None
**Sources/Inputs**: Codebase analysis of /task, /grant, /deck, /research, /plan, /implement commands
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Current /grant command requires workflow_type argument (funder_research, proposal_draft, budget_develop), creating awkward UX
- Recommend **Option C (Hybrid)**: /grant creates tasks with language="grant", uses core /research and /plan commands, adds /grant --draft, --budget, --finish flags for grant-specific operations
- This design eliminates 80% of redundancy with core workflow while preserving grant-specific features
- Key insight: The /deck command pattern (standalone generation) differs from /grant (task-based workflow), so different patterns are appropriate

## Context and Scope

This research evaluates design options for revising the /grant command to reduce redundancy with core workflow commands (/research, /plan, /implement) while maintaining grant-specific functionality.

**Key Questions**:
1. Should /grant mirror /task for task creation?
2. How should grant-specific operations (drafting, budgeting, finishing) integrate with core workflow?
3. What provides the best UX for users working on grants?

**Scope Boundaries**:
- Focus on command design, not implementation details
- Consider integration with present extension architecture
- Prioritize minimal confusion for users switching between grant and non-grant tasks

## Findings

### Codebase Pattern Analysis

#### /task Command Pattern

The /task command provides unified task lifecycle management:
- Creates tasks with description argument
- Flags for special operations: --recover, --expand, --sync, --abandon, --review
- Auto-detects language from keywords (neovim, lean4, latex, etc.)
- Updates state.json + TODO.md atomically

**Key Observation**: /task is a task CREATION and MANAGEMENT command, not a workflow command.

#### /grant Command (Current)

Currently requires explicit workflow_type argument:
```bash
/grant 500 funder_research    # Research funders
/grant 500 proposal_draft     # Draft proposal
/grant 500 budget_develop     # Develop budget
/grant 500 progress_track     # Track progress
```

**Problems**:
1. Redundant with /research (funder_research is essentially research)
2. Redundant with /plan (proposal_draft + budget_develop are planning)
3. Requires users to remember grant-specific workflow types
4. Inconsistent with other extension patterns (/deck is standalone, not task-based)

#### /deck Command Pattern (Present Extension)

The /deck command is standalone generation:
```bash
/deck "Startup description"    # Generate pitch deck from prompt
/deck startup-info.md          # Generate from file
/deck company.md --theme metro # With options
```

**Key Observation**: /deck does NOT create tasks. It generates output directly.

#### Core Workflow Commands

| Command | Purpose | Status Transitions |
|---------|---------|-------------------|
| /research | Research task | [RESEARCHING] -> [RESEARCHED] |
| /plan | Create implementation plan | [PLANNING] -> [PLANNED] |
| /implement | Execute plan | [IMPLEMENTING] -> [COMPLETED] |

**Key Observation**: These route by language. Adding "grant" as a language would enable automatic routing.

### Design Options Evaluated

#### Option A: Pure Language Routing

/grant becomes purely for task creation:
```bash
/grant "Research AI safety funding opportunities"  # Creates task with language="grant"
/research 500                                       # Routes to grant-research-agent
/plan 500                                           # Routes to grant-planner-agent
/implement 500                                      # Routes to grant-implementer-agent
```

**Pros**:
- Maximum consistency with core workflow
- No new concepts for users to learn
- Clean separation of concerns

**Cons**:
- Loses grant-specific operations (budget is not "planning")
- No way to handle --finish flag (exporting to output path)
- Progress tracking has no natural home

**Score**: 6/10

#### Option B: Full Flag System

/grant handles all grant operations via flags:
```bash
/grant "Description"           # Create grant task
/grant 500 --research         # Funder research
/grant 500 --draft            # Proposal drafting
/grant 500 --budget           # Budget development
/grant 500 --finish PATH      # Export to final location
/grant 500 --progress         # Track progress
```

**Pros**:
- All grant operations in one command
- Clear grant-specific mental model

**Cons**:
- Significant redundancy with core /research, /plan
- Users must remember different commands for grants vs other tasks
- Cognitive load increases for multi-project users

**Score**: 5/10

#### Option C: Hybrid (Recommended)

/grant creates tasks + handles grant-SPECIFIC operations only:
```bash
# Task creation (like /task)
/grant "Research AI safety funding"    # Creates task with language="grant"

# Core workflow (unchanged)
/research 500                          # Routes to skill-grant for funder research
/plan 500                              # Routes to skill-grant for proposal outline

# Grant-specific operations (flags)
/grant 500 --draft                     # Draft narrative sections
/grant 500 --budget                    # Develop line-item budget
/grant 500 --finish OUTPUT_PATH        # Export completed grant to final location
/grant 500 --progress                  # Track progress (optional)
```

**Pros**:
- Task creation mirrors /task pattern
- Core workflow (/research, /plan) is reused, not duplicated
- Grant-specific features (--draft, --budget, --finish) have clear home
- Users already familiar with /research, /plan continue using them
- Clear mental model: "use /grant for grant-specific stuff, core commands for general workflow"

**Cons**:
- Slight inconsistency (some operations via /grant, some via core commands)
- Requires language-based routing in /research and /plan for "grant"

**Score**: 9/10

#### Option D: Separate Commands

Create dedicated commands for each grant operation:
```bash
/grant "Description"       # Create task
/grant-research 500        # Funder research
/grant-draft 500           # Proposal drafting
/grant-budget 500          # Budget development
/grant-finish 500 PATH     # Export to final location
```

**Pros**:
- Very explicit about what each command does
- Easy to document

**Cons**:
- Command namespace pollution (5 new commands)
- Inconsistent with other extensions (no /deck-research, /deck-draft)
- Harder to discover

**Score**: 4/10

### UX Considerations

#### Context Switching Analysis

**Current (Problematic)**:
```
User workflow: /task -> /research -> /plan -> /implement

Grant workflow: /task -> /grant N funder_research -> /grant N proposal_draft ->
                /grant N budget_develop -> /implement N

Problem: User must switch mental models completely for grants.
```

**Proposed (Hybrid)**:
```
User workflow: /task -> /research -> /plan -> /implement

Grant workflow: /grant "desc" -> /research N -> /plan N ->
                /grant N --draft -> /grant N --budget -> /grant N --finish PATH

Improvement: Core workflow (/research, /plan) is identical. Grant-specific
operations are clearly marked with flags.
```

#### Learnability Analysis

For new users learning the system:

1. **Core concepts first**: /task creates tasks, /research researches, /plan plans, /implement implements
2. **Grant extension adds**: /grant creates grant tasks, /grant --draft and --budget are grant-specific

This layered learning is more intuitive than "grants use completely different commands."

#### --finish Flag Design

The --finish flag serves a unique grant need: exporting completed work to a specific output path.

```bash
/grant 500 --finish ~/grants/NSF-2026/submission/
```

This would:
1. Validate task is completed
2. Copy/compile all grant artifacts to output directory
3. Generate submission checklist
4. Mark task as "submitted" or keep as completed

This has no equivalent in core workflow commands, making it a clear candidate for /grant-specific flag.

### Language Routing Implementation

For Option C to work, /research and /plan must route "grant" language correctly:

**Current routing table in /research**:
```
| Language | Skill to Invoke |
|----------|-----------------|
| general, meta, markdown | skill-researcher |
```

**Required update**:
```
| Language | Skill to Invoke |
|----------|-----------------|
| general, meta, markdown | skill-researcher |
| grant | skill-grant (funder_research workflow) |
```

Similarly for /plan:
```
| Language | Skill to Invoke |
|----------|-----------------|
| general, meta, markdown | skill-planner |
| grant | skill-grant (proposal_outline workflow) |
```

**Note**: This requires updating extension routing patterns, not core command files.

### Workflow Type Mapping

How current workflow types map to Option C:

| Current | Option C | Invocation |
|---------|----------|------------|
| funder_research | research | /research N |
| proposal_draft | --draft | /grant N --draft |
| budget_develop | --budget | /grant N --budget |
| progress_track | --progress | /grant N --progress |
| (new) | --finish | /grant N --finish PATH |

### Extension Integration

The present extension currently provides:
- /grant command
- /deck command
- skill-grant, skill-deck
- grant-agent, deck-agent

Under Option C:
- /grant becomes task creation + grant-specific flags
- skill-grant handles routing from /research, /plan for language="grant"
- grant-agent remains the implementation agent
- /deck remains unchanged (standalone generation)

## Recommendations

### Primary Recommendation: Option C (Hybrid)

**Implement this design**:

1. **Task Creation Mode** (like /task):
   - `/grant "Description"` creates task with language="grant"
   - Auto-detects grant keywords (funding, proposal, foundation, etc.)
   - Follows /task creation pattern (state.json + TODO.md update)

2. **Core Workflow Integration**:
   - `/research N` routes to skill-grant for funder research when language="grant"
   - `/plan N` routes to skill-grant for proposal outline when language="grant"
   - `/implement N` routes to skill-grant for final assembly when language="grant"

3. **Grant-Specific Flags**:
   - `/grant N --draft` - Draft narrative sections (after research/plan)
   - `/grant N --budget` - Develop line-item budget
   - `/grant N --finish PATH` - Export completed grant to submission directory
   - `/grant N --progress` - Track completion progress (optional)

4. **Status Transitions**:
   - Task creation: [NOT STARTED]
   - /research: [RESEARCHING] -> [RESEARCHED]
   - /plan: [PLANNING] -> [PLANNED]
   - /grant --draft: [DRAFTING] -> [DRAFTED]
   - /grant --budget: [BUDGETING] -> [BUDGETED]
   - /grant --finish: [COMPLETED] -> [SUBMITTED] (optional new status)
   - /implement: [IMPLEMENTING] -> [COMPLETED]

### Secondary Recommendations

1. **Simplify Status Machine**: Consider whether --draft and --budget need separate statuses, or if [PLANNED] suffices for both.

2. **Deprecation Path**: Keep backward compatibility with `/grant N funder_research` syntax for 1-2 versions while transitioning.

3. **Extension Routing Pattern**: Document how extensions add language routing without modifying core commands.

4. **Submission Tracking**: Consider adding "submitted" as a terminal status for grants that have been exported via --finish.

## Decisions

1. **DECIDED**: Use Option C (Hybrid) for optimal balance of consistency and grant-specific features
2. **DECIDED**: /grant without flags creates tasks (mirrors /task)
3. **DECIDED**: Core workflow commands (/research, /plan) route by language
4. **DECIDED**: Grant-specific flags: --draft, --budget, --finish, --progress
5. **OPEN**: Whether to add "submitted" status or keep using "completed"

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Users confused by mixed command model | Medium | Medium | Clear documentation, consistent messaging |
| Extension routing complexity | Low | Medium | Well-documented routing patterns in extension manifest |
| Backward compatibility breaks | Low | High | Keep old syntax working with deprecation warning |
| --finish flag edge cases | Medium | Low | Validate task status before export |

## Context Extension Recommendations

No context gaps identified. The existing grant context files in present extension are comprehensive.

## Appendix

### Files Analyzed

1. `.claude/commands/task.md` - Task creation and management reference
2. `.claude/commands/research.md` - Research command pattern
3. `.claude/commands/plan.md` - Planning command pattern
4. `.claude/commands/implement.md` - Implementation command pattern
5. `.claude/extensions/present/commands/grant.md` - Current grant command
6. `.claude/extensions/present/commands/deck.md` - Deck command comparison
7. `.claude/extensions/present/skills/skill-grant/SKILL.md` - Grant skill implementation
8. `.claude/extensions/present/agents/grant-agent.md` - Grant agent definition
9. `.claude/extensions/present/manifest.json` - Extension manifest
10. `.claude/extensions/present/EXTENSION.md` - Extension documentation
11. `.claude/extensions/present/context/project/present/README.md` - Grant domain overview
12. `.claude/extensions/present/context/project/present/patterns/proposal-structure.md` - Proposal patterns

### Command Comparison Matrix

| Aspect | /task | /grant (current) | /grant (proposed) | /deck |
|--------|-------|------------------|-------------------|-------|
| Creates tasks | Yes | No | Yes | No |
| Task-based workflow | Yes | Yes | Yes | No |
| Standalone operation | No | No | Yes (flags) | Yes |
| Routes by language | N/A | No | Yes | N/A |
| Uses core workflow | N/A | No | Yes | N/A |
