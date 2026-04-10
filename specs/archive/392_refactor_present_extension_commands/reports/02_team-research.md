# Research Report: Task #392 (Team Research)

- **Task**: 392 - Refactor present extension commands (/grant, /budget, /funds, /timeline, /talk)
- **Started**: 2026-04-10T06:20:00Z
- **Completed**: 2026-04-10T06:35:00Z
- **Effort**: Team research (4 teammates, ~15 min wall clock)
- **Dependencies**: 391 (completed - manifest integration)
- **Sources/Inputs**:
  - All 5 present commands, skills, agents (15 files)
  - Present extension manifest.json, EXTENSION.md, README.md
  - Present extension index-entries.json (16+ grant context entries)
  - Core commands (task.md, research.md, plan.md, implement.md) for pattern comparison
  - Founder extension commands (market.md) for routing comparison
  - Core skills (skill-researcher, skill-planner) for thin-wrapper patterns
  - Round 1 research (01_refactor-present-commands.md)
  - Teammate findings: 02_teammate-{a,b,c,d}-findings.md
- **Artifacts**:
  - specs/392_refactor_present_extension_commands/reports/02_team-research.md (this file)
  - specs/392_refactor_present_extension_commands/reports/02_teammate-a-findings.md
  - specs/392_refactor_present_extension_commands/reports/02_teammate-b-findings.md
  - specs/392_refactor_present_extension_commands/reports/02_teammate-c-findings.md
  - specs/392_refactor_present_extension_commands/reports/02_teammate-d-findings.md
- **Standards**: report-format.md, artifact-management.md

## Executive Summary

- The present extension is the most domain-rich extension in the system with 5 commands, 5 agents, 5 skills, and 45+ context files, but suffers from inconsistencies accumulated across 4 task creation waves
- **Scope is larger than round 1 estimated**: 15-18 files and 45-55 discrete changes (vs. round 1's estimate of 9 files, 25-30 changes), primarily due to agent files, index-entries.json (16 grant entries), and manifest implement routing
- Three commands (/grant, /budget, /timeline) use wrong language values, breaking manifest routing; two (/funds, /talk) are correct and serve as the reference pattern
- The user's core vision -- `{extension}:{command}` task type designation, interactive pre-task intake for /grant, design confirmation for /talk, progressive context disclosure -- requires both mechanical fixes AND structural enhancements
- The `/market` command (founder extension) is the gold standard for extension command architecture; `/talk` already follows this pattern, while the other 4 present commands need to catch up

## Context & Scope

Task 391 integrated all five present commands into a unified manifest with `present:{subtype}` routing keys. However, the commands themselves were created in separate waves (grant first in task ~205, then budget/timeline/funds/talk in tasks 387-390) and accumulated significant inconsistencies. This team research investigates the full scope of changes needed to create a cohesive, high-quality product suite.

The user's vision goes beyond mechanical fixes to include:
1. Task type designation via `{extension}:{command}` format
2. Unity in architecture where motivated, differences where distinct purposes demand them
3. Interactive pre-task intake for /grant (content paths, regulatory materials, guidelines)
4. Design confirmation for /talk (themes, content, order) before planning
5. Progressive context disclosure throughout the workflow
6. High quality, consistent product following top standards

## Findings

### 1. Language Field Inconsistencies (CRITICAL -- All Teammates Agree)

The manifest routing uses `present:{subtype}` compound keys, but commands create tasks with inconsistent language values:

| Command | Current `language` | Current `task_type` | Correct `language` | Correct `task_type` |
|---------|-------------------|--------------------|--------------------|---------------------|
| /grant | `"grant"` | missing | `"present"` | `"grant"` |
| /budget | `"budget"` | `"budget"` | `"present"` | `"budget"` |
| /timeline | `"timeline"` | missing | `"present"` | `"timeline"` |
| /funds | `"present"` | `"funds"` | `"present"` (correct) | `"funds"` (correct) |
| /talk | `"present"` | `"talk"` | `"present"` (correct) | `"talk"` (correct) |

**Impact**: Tasks with `language: "grant"` routed through `/research N` hit `skill-grant` only because the command directly invokes the skill. But if the orchestrator routes by language, `"grant"` does not match any manifest key -- the manifest expects `"present:grant"`.

**Teammate B adds**: The `/market` (founder) command uses the same pattern -- `language: "founder"` with `task_type: "market"`. The compound key is only in the routing table, not the task metadata. This is the established convention.

### 2. Expanded Scope: Files the Round 1 Report Missed (CRITICAL -- Teammate C)

The Critic identified that the refactor scope is approximately 50% larger than round 1 estimated:

**Agent files (3 files need updating)**:
- `grant-agent.md`: Delegation context example shows `"language": "grant"`, dynamic context jq query searches `languages[]? == "grant"`
- `budget-agent.md`: Delegation context example shows `"language": "budget"`
- `timeline-agent.md`: Delegation context example shows `"language": "timeline"`

**Index-entries.json (16+ entries need updating)**:
- All grant-domain context entries use `"languages": ["grant"]` in `load_when`
- After unifying to `language: "present"`, these entries won't match language-based context discovery queries
- Budget/timeline/funds/talk entries already use `"languages": ["present"]` (correct)

**Manifest implement routing (1 entry)**:
- `"grant": "skill-grant:assemble"` is a bare key that becomes dead code after refactor
- Should be `"present:grant": "skill-grant:assemble"`

**Grant-agent Co-Authored-By in git commit template** (not in command files)

**Revised file count**: 15-18 files, 45-55 discrete changes.

### 3. Pre-Task Forcing Questions: Current State (Teammate A)

| Command | Has Stage 0? | Questions | Timing | Pattern Quality |
|---------|-------------|-----------|--------|----------------|
| /grant | **NO** | 0 | N/A | Missing entirely |
| /budget | Yes | 3 | Pre-task | Good but overlaps with agent |
| /funds | Yes | 5 | Pre-task | Best implementation |
| /timeline | Partial | 3 | **In research** (wrong) | Misplaced + duplicates agent |
| /talk | Yes | 3 | Pre-task | Good |

**Double-questioning problem (Teammate A)**:
- Timeline: Command asks 3 questions, then agent asks 8 more including overlapping mechanism and aims questions
- Budget: Command asks 3, agent asks 8 more with partial overlap on mode and project period

### 4. /grant Pre-Task Intake (User Requirement -- All Teammates Agree)

The user explicitly wants `/grant` to begin with interactive questions before creating the task. Currently `/grant "description"` creates a bare task with no stored context.

**Recommended Stage 0 questions for /grant** (synthesized from Teammates A + D):

```
Q1: Grant mechanism and funder
    "What type of grant? (e.g., NIH R01, NSF CAREER, foundation)"

Q2: Existing content paths
    "Existing content to draw from?
    - File paths to aims, manuscripts, papers
    - Task references (task:N) for prior grants
    - 'none' to start fresh"

Q3: Regulatory and compliance materials
    "Relevant regulatory materials?
    - Funder PA/FOA URL or path
    - Institutional guidelines/templates
    - IRB/IACUC protocols to reference
    - 'none' if not yet identified"

Q4: Grant constraints
    "Key constraints?
    - Page limits, required sections
    - Due date and internal deadline
    - Budget ceiling"
```

Store as `forcing_data` accessible to all subsequent `--draft`, `--budget`, `--revise` invocations.

### 5. /talk Design Confirmation (User Requirement -- All Teammates Agree)

The user wants the plan agent to present choices of themes, content, and order to confirm design BEFORE proposing a plan.

**Key constraint (Teammate A)**: The talk-agent MUST NOT use AskUserQuestion (explicit critical requirement in talk-agent.md). Design confirmation must happen at the command/skill level.

**Open question resolved**: Should confirmation be synchronous (Stage 0) or asynchronous (post-research)?

**Team consensus**: Asynchronous is better. The agent needs to have analyzed source materials before it can propose a meaningful structure. Two viable approaches:

**Option B1 (explicit flag -- Recommended by Teammate A)**:
```
/talk "description"  -> Stage 0 questions -> task creation -> STOP
/research N          -> talk research -> slide-mapped report
/talk N --design     -> reads report, presents theme/order/emphasis choices -> stores design_decisions
/plan N              -> uses design_decisions in plan creation
/implement N         -> assembles Slidev presentation
```

**Option B2 (implicit in /plan -- Teammate A alternative)**:
```
/plan N on a talk task with no design_decisions:
  -> Read research report
  -> AskUserQuestion for theme/order/emphasis
  -> Store as design_decisions
  -> Invoke skill-planner with design_decisions
```

**Teammate D's creative addition**: "Talk Architect" mode offering two structural approaches:
- Methods-forward (show how before what was found)
- Results-forward (lead with impact, reveal methods as needed)

### 6. Skill Pattern Deviations (Teammate B)

Present extension skills deviate from core skill patterns in several ways:

| Pattern | Core Skills | Present Skills |
|---------|------------|----------------|
| Status updates | `update-task-status.sh` | Inline jq (skill-grant) |
| Artifact validation | Stage 6a: `validate-artifact.sh --fix` | Missing (skill-grant) |
| Model specification | `model: opus` | `claude-opus-4-5-20251101` or none |
| Co-Authored-By | `Claude Opus 4.6 (1M context)` | Mixed (3 outdated) |

### 7. Context Index Organization (Teammates B + C)

The `index-entries.json` has a split language problem:
- 16 grant-domain entries: `"languages": ["grant"]` -- will fail to load after language unification
- All other entries: `"languages": ["present"]` -- correct

**Resolution**: Update grant entries to `"languages": ["present"]`. The `load_when.agents` arrays (which reference `"grant-agent"`) will continue to work as a secondary matching dimension.

**Grant-agent dynamic context query** also needs updating:
```bash
# Current (will break):
select(.load_when.languages[]? == "grant")

# After fix:
select(.load_when.languages[]? == "present" and .load_when.agents[]? == "grant-agent")
```

### 8. Strategic Vision: Product Cohesion (Teammate D)

The present extension should feel like a cohesive product suite, not 5 independent tools. Key cohesion opportunities:

1. **Consistent Stage 0 arc**: All 5 commands should have pre-task forcing questions. Different domains, identical pattern.
2. **Cross-command linking**: `/talk` can accept `task:N` where N is a grant task, drawing from its narratives
3. **Progressive context disclosure**: When `/grant N --draft` is invoked, display the stored forcing_data context
4. **Shared forcing-question framework**: Extract common documentation patterns (quality assessment, push-back patterns)

## Decisions

1. **Language unification**: All commands use `language: "present"` with `task_type` for subtype differentiation
2. **task_type values**: Use simple form (`"grant"`, `"budget"`, etc.) not compound (`"present:grant"`). The compound form is for manifest routing keys only.
3. **Model standardization**: All commands use `model: opus`
4. **Co-Authored-By**: All commands and agents use `Claude Opus 4.6 (1M context) <noreply@anthropic.com>`
5. **Grant intake**: Add Stage 0 pre-task forcing questions (4 questions)
6. **Timeline restructure**: Move forcing questions to pre-task Stage 0, extend to 5-6 questions
7. **Talk design confirmation**: Add `--design` flag to `/talk` command for post-research design choices
8. **Skill alignment**: Update present skills to use `update-task-status.sh` and `validate-artifact.sh`
9. **Index entries**: Update all grant-domain entries from `"languages": ["grant"]` to `"languages": ["present"]`
10. **Grant-specific modes preserved**: Draft, budget, revise, fix-it modes on /grant are domain-specific and should remain

## Recommendations

### Phase 1: Mechanical Standardization (Highest Priority)

**All 5 commands**: Fix language, model, Co-Authored-By, add task_type where missing.
**All 5 skills**: Update language validation from specific values to `"present"`.
**All 5 agents**: Update delegation context examples.
**Index-entries.json**: Update 16 grant entries from `"languages": ["grant"]` to `"languages": ["present"]`.
**Manifest**: Fix implement routing bare `"grant"` key.
**EXTENSION.md**: Update routing table with task_type column.

Estimated changes: ~40 discrete edits across 15+ files.

### Phase 2: /grant Pre-Task Intake (High Value)

Add Stage 0 forcing questions (4 questions) to grant command. Update skill-grant to pass forcing_data to agent. Update grant-agent to use pre-gathered data (skip redundant questions).

### Phase 3: /timeline Structural Alignment (Medium Value)

Move forcing questions from research stage to pre-task Stage 0. Extend from 3 to 5-6 questions. Wire skip logic in timeline-agent to bypass pre-gathered answers.

### Phase 4: /talk Design Confirmation (High Value, User Vision)

Add `--design` flag to /talk command. Read research report, present theme/order/emphasis choices via AskUserQuestion. Store as `design_decisions` in task metadata. Update /plan flow to use design_decisions.

### Phase 5: Skill Pattern Alignment (Medium Priority)

Update skill-grant (and other present skills as needed) to use `update-task-status.sh` for preflight/postflight. Add Stage 6a artifact validation.

### Future Considerations (Not in Scope)

- Cross-command linking (grant-to-talk pipeline)
- Shared forcing-question framework documentation
- README.md expansion to cover all 5 capabilities
- Progressive context disclosure improvements

## Risks & Mitigations

- **Risk**: 16 index-entries.json changes could break grant context loading if done incorrectly
  - **Mitigation**: Update all entries atomically in a single phase; verify with test jq query
- **Risk**: Agent dynamic context queries (grant-agent) will break if index is updated but queries are not
  - **Mitigation**: Update both in the same phase
- **Risk**: Existing tasks with `language: "grant"` would break after refactor
  - **Mitigation**: State.json shows zero active present-related tasks -- no migration risk
- **Risk**: Talk agent MUST NOT use AskUserQuestion, so design confirmation must be at command/skill level
  - **Mitigation**: Design confirmation uses a separate `--design` flag handled by the command, not the agent
- **Risk**: Scope expansion to 15+ files increases implementation complexity
  - **Mitigation**: Phase the work: mechanical fixes first (Phase 1), enhancements second (Phases 2-4)

## Synthesis

### Conflicts Resolved

1. **task_type format** -- Teammate B suggested using compound `"present:grant"` as task_type value; Teammate A used simple `"grant"`. **Resolution**: Simple form (`"grant"`) matches the established pattern from `/market` (founder extension) which uses `task_type: "market"`, not `"founder:market"`. The compound form is for routing keys only.

2. **Talk design confirmation timing** -- Teammate A proposed explicit `--design` flag; Teammate D suggested it could be Stage 0.4 (synchronous). **Resolution**: Asynchronous (post-research) is preferred because the agent needs analyzed content to propose meaningful structure. The `--design` flag approach is cleaner.

3. **Index entry language values** -- Teammate C asked whether grant entries should stay `["grant"]` for backwards compatibility. **Resolution**: Update to `["present"]`. No active tasks use `language: "grant"`, and keeping stale values would prevent context loading for correctly-created tasks.

### Gaps Identified

1. **No testing strategy**: No smoke tests or manual validation checklist defined for the refactor. The planner should include a validation phase.
2. **README.md scope**: The present context README only covers grants. After unification, it becomes the landing page for all present tasks but doesn't document budget/timeline/funds/talk. Low priority but worth noting.
3. **opencode-agents.json**: Agent keys are not language-based, so no changes needed. Confirmed by Critic.

## Teammate Contributions

| Teammate | Angle | Status | Confidence | Key Contribution |
|----------|-------|--------|------------|-----------------|
| A | Primary analysis | completed | high | Per-command flow analysis, improvement options, design confirmation architecture |
| B | Alternative patterns | completed | high | Gold standard comparison (/market), skill pattern deviations, context index issues |
| C | Critic | completed | high | Scope expansion (9->15+ files), agent file gaps, index-entries.json 16 entries |
| D | Horizons | completed | high | Product cohesion vision, creative proposals, strategic recommendations |

## Appendix

### Complete File Change List (Revised)

**Commands** (5 files):
1. `.claude/extensions/present/commands/grant.md` -- language, model, co-authored-by, task_type, Stage 0 intake
2. `.claude/extensions/present/commands/budget.md` -- language fix, model, co-authored-by
3. `.claude/extensions/present/commands/timeline.md` -- language fix, task_type, model, co-authored-by, move questions to Stage 0
4. `.claude/extensions/present/commands/funds.md` -- model fix, co-authored-by
5. `.claude/extensions/present/commands/talk.md` -- model fix, co-authored-by, add --design flag

**Skills** (5 files):
6. `.claude/extensions/present/skills/skill-grant/SKILL.md` -- validate present, use update-task-status.sh, add Stage 6a
7. `.claude/extensions/present/skills/skill-budget/SKILL.md` -- validate present
8. `.claude/extensions/present/skills/skill-timeline/SKILL.md` -- validate present
9. `.claude/extensions/present/skills/skill-funds/SKILL.md` -- verify (may already be correct)
10. `.claude/extensions/present/skills/skill-talk/SKILL.md` -- verify, add --design workflow

**Agents** (3-5 files):
11. `.claude/extensions/present/agents/grant-agent.md` -- delegation context, dynamic query, co-authored-by
12. `.claude/extensions/present/agents/budget-agent.md` -- delegation context
13. `.claude/extensions/present/agents/timeline-agent.md` -- delegation context, add task_type

**Extension metadata** (3 files):
14. `.claude/extensions/present/EXTENSION.md` -- routing table update
15. `.claude/extensions/present/manifest.json` -- implement routing fix (bare "grant" key)
16. `.claude/extensions/present/index-entries.json` -- 16 grant entries language update

**Optional** (1-2 files):
17. `.claude/extensions/present/context/project/present/README.md` -- scope expansion (future)
18. `.claude/extensions/present/agents/funds-agent.md` -- verify (likely correct)
19. `.claude/extensions/present/agents/talk-agent.md` -- verify (likely correct)

### Estimated Change Counts
- Total files: 16-19
- Discrete edits: 45-55
- Complexity: Medium (mechanical replacements + 3 structural additions: grant intake, timeline restructure, talk design)

### Teammate Report Locations
- Teammate A: `specs/392_refactor_present_extension_commands/reports/02_teammate-a-findings.md`
- Teammate B: `specs/392_refactor_present_extension_commands/reports/02_teammate-b-findings.md`
- Teammate C: `specs/392_refactor_present_extension_commands/reports/02_teammate-c-findings.md`
- Teammate D: `specs/392_refactor_present_extension_commands/reports/02_teammate-d-findings.md`
