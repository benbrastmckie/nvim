# Research Report: Task #485 - Teammate A Findings

**Task**: 485 - Rewrite meta-guide.md to match current system
**Role**: Teammate A - Primary /meta System Analysis
**Started**: 2026-04-19T00:00:00Z
**Completed**: 2026-04-19T00:30:00Z
**Effort**: ~1 hour
**Sources/Inputs**: Local codebase (no web search needed - all evidence in filesystem)
**Artifacts**: This report

---

## Executive Summary

The current `meta-guide.md` is severely outdated and describes a DIFFERENT system than the one actually deployed. It documents a generic "multi-domain AI system builder" (e.g., e-commerce systems, data pipelines) when the real `/meta` command is a **task creation tool for `.claude/` system changes**. Every major section is wrong. The document needs to be completely rewritten from scratch, not revised.

Key findings:
1. The current guide describes a system that generates agents, workflows, and commands for user domains (e-commerce, etc.). The real system ONLY creates TODO.md tasks.
2. The 4-phase interview (Domain, Use Cases, Complexity, Integration) does not exist - the real interview has 7 stages focused on task planning.
3. The "What You Get" section describes output files (orchestrators, subagents, workflows) that are never created by `/meta`.
4. Three operating modes (interactive, prompt, analyze) are entirely absent from the guide.
5. The task dependency system (Kahn's algorithm, DAG visualization) is completely undocumented.
6. Critical behavioral constraint ("never implements directly, only creates tasks") is never stated.

---

## Key Findings: What Is Wrong With Current meta-guide.md

### Finding 1: Fundamental Purpose Misrepresentation (CRITICAL)

**Current guide claims** (line 7-8):
> "The `/meta` command provides an interactive system builder that creates agents and commands tailored to your needs."

**Reality** (from meta-builder-agent.md, line 12):
> "System building agent that handles the `/meta` command for creating tasks related to .claude/ system changes... This agent NEVER implements changes directly - it only creates tasks."

The guide portrays `/meta` as something that directly generates agents, commands, workflows, context files, and READMEs. The actual system is a **task creator** that feeds into the standard `/research -> /plan -> /implement` lifecycle.

### Finding 2: Phantom Output Structure (CRITICAL)

**Current guide describes** (lines 27-47):
```
.claude/
├── agent/
│   ├── {domain}-orchestrator.md
│   └── subagents/
├── .claude/context/
│   ├── domain/
│   ├── processes/
├── workflows/
├── command/
└── README.md
```

**Reality**: `/meta` writes ONLY to `specs/TODO.md` and `specs/state.json`. It creates task directory stubs (e.g., `specs/NNN_slug/`). It NEVER creates `.claude/` files, agents, commands, workflows, or READMEs. Those are created later by `/implement`.

### Finding 3: Fake Interview Questions (CRITICAL)

**Current guide documents a 4-phase interview with 12 questions**:
- Phase 1: Domain & Purpose (Questions 1-3: industry, purpose, users)
- Phase 2: Use Cases & Workflows (Questions 4-6: use cases, complexity, dependencies)
- Phase 3: Complexity & Scale (Questions 7-9: agents needed, knowledge types, state)
- Phase 4: Integration & Tools (Questions 10-12: external tools, file ops, commands)

**Reality from meta-builder-agent.md**: The real interview has 7 stages:
- Stage 0: DetectExistingSystem - inventory `.claude/` components
- Stage 1: InitiateInterview - explain the task planning process
- Stage 2: GatherDomainInfo - what to accomplish, which part of `.claude/` is affected
- Stage 3: IdentifyUseCases - can this be broken into tasks? collect task list, dependencies
- Stage 3.5: AnalyzeTopics - topic clustering for consolidation
- Stage 4: AssessComplexity - effort estimates per task
- Stage 5: ReviewAndConfirm - mandatory confirmation before creating tasks
- Stage 6: CreateTasks - write to TODO.md + state.json using topological sort
- Stage 7: DeliverSummary - show DAG visualization and next steps

The questions are entirely different. The real questions ask: "What do you want to accomplish?" (with options: add command, add skill/agent, fix existing, create docs) - not "What is your industry?"

### Finding 4: Three Operating Modes Not Documented

**Current guide**: Never mentions operating modes.

**Reality from meta.md (command) and skill-meta/SKILL.md**:
- **Interactive mode** (no args): Full 7-stage interview via AskUserQuestion
- **Prompt mode** (with text arg): Abbreviated flow - parse intent, propose tasks, confirm
- **Analyze mode** (--analyze flag): Read-only inventory of `.claude/` components; no tasks created

Example: `/meta "add a new command for exporting logs"` triggers prompt mode with an abbreviated flow.

### Finding 5: Non-Existent Performance Claims

**Current guide asserts** (lines 50-55):
```
- +20% routing accuracy (LLM-based decisions with @ symbol routing)
- +25% consistency (XML structure with optimal component ordering)
- 80% context efficiency (3-level context allocation)
- +17% overall performance (position-sensitive component sequencing)
```

**Reality**: These statistics appear in `architecture-principles.md` and `standards-checklist.md` as aspirational design goals for system-generated agents. They are not documented results of `/meta` itself. `/meta` doesn't generate agents at all - it creates tasks. The performance claims are irrelevant to what `/meta` does.

### Finding 6: Task Dependency System Entirely Missing

The real `/meta` has a sophisticated dependency management system:
- Users specify internal task dependencies (linear chain or custom DAG)
- Users can declare external dependencies on existing task numbers
- Dependency validation: self-reference check, valid index check, circular dependency check (DFS)
- Topological sorting using Kahn's algorithm before number assignment
- Complexity detection: linear chain vs. DAG determines visualization style
- Two visualization modes: simple vertical chain, layered graph with box-drawing characters
- Parallel execution annotation for tasks at same dependency depth

None of this exists in the current meta-guide.md.

### Finding 7: Topic Clustering (Stage 3.5) Not Documented

The real system includes an optional topic consolidation step:
- Extracts topic indicators from each task (key terms, component type, affected area, action type)
- Clusters tasks by shared indicators
- Offers user a choice: accept suggested groupings, keep separate, customize
- Applies effort scaling formula for consolidated tasks

This is never mentioned in the current guide.

### Finding 8: Critical Constraint Missing

**From meta-builder-agent.md (FORBIDDEN section)**:
```
MUST NOT:
- Directly create commands, skills, rules, or context files
- Directly modify CLAUDE.md or README.md
- Implement any work without user confirmation
- Write any files outside specs/
- Present choices as plain text (A/B/C, 1/2/3)
```

**From meta-builder-agent.md (REQUIRED section)**:
```
MUST:
- Use AskUserQuestion with options array for EVERY user choice point
- Track all work via tasks in TODO.md + state.json
- Require explicit user confirmation before creating any tasks
```

The current guide never states that `/meta` cannot create files directly, that AskUserQuestion is used for all choices, or that confirmation is mandatory before any task creation.

### Finding 9: Wrong Resource Links

**Current guide "Resources" section** (lines 449-452):
```
- Meta Agent: `.claude/agent/subagents/meta.md`
```

**Reality**: The meta agent is at `.claude/agents/meta-builder-agent.md`. There is no `.claude/agent/` directory (that is the `.opencode/` path naming pattern). The actual agent location uses plural form.

### Finding 10: .opencode Structure Label is Wrong

**Current guide header** (line 27): `### Complete .opencode Structure`

This appears to reference `.opencode/` (the OpenCode system) but then shows `.claude/` paths. The label is wrong. This is a copy-paste artifact from a different system (OpenCode). The correct system uses `.claude/`.

### Finding 11: "Subagent Types" Do Not Apply to /meta

**Current guide lists subagent types** (lines 270-280):
- Research Agent, Validation Agent, Processing Agent, Generation Agent, Integration Agent

These are types of agents that get created in user-built systems. They are not components of `/meta` itself. The actual agents in the system are: general-research-agent, planner-agent, general-implementation-agent, meta-builder-agent, etc. - and `/meta` doesn't generate any of these.

### Finding 12: Testing Section Describes Wrong Artifacts

**Current guide "Testing Your System"** describes testing orchestrators, subagents, workflows, context files, and custom commands. Since `/meta` doesn't generate any of these artifacts directly, this section doesn't apply. The actual "after /meta" workflow is: run `/research N`, then `/plan N`, then `/implement N` for each created task.

### Finding 13: Context File Paths Wrong

**Current guide** (lines 223-238):
```
Domain Knowledge (.claude/context/domain/)
Process Knowledge (.claude/context/processes/)
Standards Knowledge (.claude/context/standards/)
Template Knowledge (.claude/context/templates/)
```

**Reality**: The actual context structure in this project is:
```
.claude/context/
├── meta/          (meta patterns)
├── formats/       (return schemas)
├── patterns/      (workflow patterns)
├── standards/     (interactive selection, etc.)
├── architecture/  (context layer docs)
├── guides/        (extension development)
└── repo/          (project overview)
```

The generic subdirectory layout described does not match the deployed system.

### Finding 14: Outdated Context Supplementary Files

The existing companion files in `.claude/context/meta/` also have issues:

**interview-patterns.md**: Documents patterns for a generic AI system interview (domain, use cases, agents). These patterns align with the OLD interview questions, not the real 7-stage task-creation interview. Stage references (Stage 2-6) point to the wrong interview stages. Should be revised to reflect task planning interview patterns.

**architecture-principles.md**: Contains "Design for .opencode system architectures" in the purpose line. Should say `.claude/`. The principles themselves (modular design, context efficiency, 8-stage workflow, XML patterns) are reasonable but are presented as guidance for generated systems, not as guidance for the systems users create tasks to build.

**standards-checklist.md**: References to `status-sync-manager` and `git-workflow-manager` as delegation targets appear to be legacy (current system uses skill-status-sync and skill-git-workflow). The frontmatter requirements listed (temperature, max_tokens, lifecycle.stage, delegation.can_delegate_to, etc.) are more complex than what actual agent frontmatter shows - actual agents use simpler frontmatter (name, description, model).

**domain-patterns.md**: Documents e-commerce, data, business domains for user-built systems. The Extension Domain Pattern section is newer and more relevant. The entire file serves as reference for what kinds of systems users might want to build AFTER tasks are created, not for the `/meta` interview itself.

**context-revision-guide.md**: Most accurate of all companion files. Describes how to revise context files without bloat. Generally accurate to current system. The `.claude/context/meta/` path in its "Project Meta" section is correct.

---

## Actual /meta System: How It Really Works

### Command Entry Point: `.claude/commands/meta.md`

Arguments accepted:
- No args -> interactive mode
- `PROMPT` (text) -> prompt mode
- `--analyze` -> analyze mode (read-only)

Constraints (FORBIDDEN):
- Cannot directly create commands, skills, rules, or context files
- Cannot modify CLAUDE.md or README.md
- Cannot implement work without user confirmation
- Cannot write files outside `specs/`

### Delegation Chain

```
User runs /meta
    |
    v
meta.md (command) detects mode
    |
    v
skill-meta/SKILL.md (thin wrapper, spawns via Task tool)
    |
    v
meta-builder-agent.md (does all the real work)
    |
    v
Output: entries in specs/TODO.md + specs/state.json
        task directories in specs/NNN_slug/
```

Note: The skill uses the **Task tool** (not the Skill tool) to spawn the agent. This is a forked subagent pattern.

### Real Interactive Mode: 7-Stage Interview

**Stage 0: DetectExistingSystem**
- Inventories current `.claude/` components (commands, skills, agents, rules, active tasks)
- Shows counts to orient the user

**Stage 1: InitiateInterview**
- Explains the 5-10 minute process
- Sets expectation: "you get task entries, not implementation"

**Stage 2: GatherDomainInfo**
- Question: "What do you want to accomplish?"
  - Options (via AskUserQuestion): Add command, Add skill/agent, Fix existing, Create docs, Something else
- Question: "What part of the .claude/ system is affected?"
- Context loading: loads creating-commands.md or creating-skills.md based on selection

**Stage 2.5: DetectDomainType**
- Auto-classifies to task_type "meta" or "general" based on keywords

**Stage 3: IdentifyUseCases**
- "Can this be broken into smaller tasks?" (Yes/No/Help me)
- If yes: gather task list from user
- If multiple tasks: ask about dependencies (None/Linear chain/Custom DAG)
- Dependency validation: self-reference, valid index, circular dependency checks
- Optional: ask about external dependencies on existing task numbers

**Stage 3.5: AnalyzeTopics (Optional)**
- Only if 2+ tasks share topic indicators
- Offers consolidation suggestions with effort scaling

**Stage 4: AssessComplexity**
- Per-task effort estimates: Small (<1h), Medium (1-3h), Large (3-6h), Very Large (>6h)

**Stage 5: ReviewAndConfirm**
- Present task summary table with dependencies
- MANDATORY AskUserQuestion: "Yes, create tasks" / "Revise" / "Cancel"

**Stage 6: CreateTasks**
- Topological sort (Kahn's algorithm) assigns task numbers in dependency order
- Creates entries in state.json (with dependencies array)
- Batch inserts all entries into TODO.md (foundational tasks first)
- Creates task directories

**Stage 7: DeliverSummary**
- Linear chain or layered DAG visualization
- Execution order with parallel annotations
- Next steps: "Run /research N"

### Real Prompt Mode

Abbreviated flow for direct requests like `/meta "add export command"`:
1. Parse keywords and intent from the prompt
2. Check state.json for related existing tasks
3. Propose task breakdown
4. Clarify ambiguities via AskUserQuestion (with options, never plain text)
5. Confirm and create

### Real Analyze Mode (`/meta --analyze`)

Read-only inventory:
- Lists all commands, skills, agents, rules
- Shows active task counts
- Provides recommendations
- NO tasks created

### Memory System Integration

The `.memory/` directory exists (`/home/benjamin/.config/nvim/.memory/`) with:
- `00-Inbox/` - Pending memories
- `10-Memories/` - Active memories
- `20-Indices/` - Search indices
- `30-Templates/` - Memory templates
- `memory-index.json`

The meta-guide.md currently has NO mention of `.memory/`. The focus prompt for this task mentions "keying into the .memory/ system as appropriate." The appropriate integration: when `/meta` is run, if the memory extension is loaded, memory retrieval could provide context about past system decisions. However, the meta-builder-agent itself does not currently load memory context - this would be a potential improvement to document.

### ROADMAP.md Consideration

The focus prompt mentions keying into `specs/ROADMAP.md`. The meta-guide.md currently doesn't mention ROADMAP.md at all. The ROADMAP file is relevant as context for what kinds of tasks might be needed - but the meta-agent itself doesn't read ROADMAP.md during its interview. This could be noted as an improvement: the analyze mode could surface ROADMAP items as candidate tasks.

---

## Recommended Content for the Rewrite

The rewritten `meta-guide.md` should contain:

### 1. Accurate Overview (Replace lines 1-55)

```markdown
## Overview

The `/meta` command is an interactive task creator for `.claude/` system changes.
It conducts a guided interview to understand what changes you need, then creates
structured tasks in TODO.md. Those tasks then follow the standard lifecycle:
/research -> /plan -> /implement.

**Critical distinction**: /meta NEVER directly creates commands, skills, agents,
rules, or context files. It only creates tasks. Implementation happens later via /implement.
```

### 2. Three Modes (New section)

Document interactive, prompt, and analyze modes with examples.

### 3. Real Interview Stages (Replace Phase 1-5 description)

Document the actual 7 stages with the real questions and AskUserQuestion pattern.

### 4. Task Dependency System (New section)

Document:
- Linear chain vs custom DAG dependencies
- External dependencies on existing tasks
- Dependency validation (circular check)
- Topological sort and number assignment
- Visualization output (linear chain / layered DAG)

### 5. Topic Clustering (New section)

Explain Stage 3.5 consolidation behavior.

### 6. Output: What You Actually Get (Replace "What You Get")

```markdown
## What You Get

After running /meta, you receive:
- Task entries in specs/TODO.md
- Machine state in specs/state.json
- Task directories at specs/NNN_slug/
- A dependency visualization showing execution order
- Next steps pointing to /research N for the first task
```

### 7. After /meta: The Lifecycle (Replace "Next Steps")

Explain that implementation happens in a separate phase via /research, /plan, /implement.

### 8. Remove or Correct

- All phantom output structure descriptions
- All fake interview questions (Domain, Use Cases, Integration)
- All unverifiable performance statistics (+20%, +25%, etc.)
- The "Testing Your System" section (not applicable to /meta)
- "Customization after generation" section (wrong - /meta generates tasks, not artifacts)
- Resource link to `.claude/agent/subagents/meta.md` (wrong path)

### 9. Accurate Resource Links

```markdown
## Resources

- **Command spec**: `.claude/commands/meta.md`
- **Skill**: `.claude/skills/skill-meta/SKILL.md`
- **Agent**: `.claude/agents/meta-builder-agent.md`
- **Component guides**: `.claude/docs/guides/creating-commands.md`, `creating-skills.md`, `creating-agents.md`
- **Multi-task standard**: `.claude/docs/reference/standards/multi-task-creation-standard.md`
- **Context index**: `.claude/context/index.json`
```

### 10. Memory and ROADMAP Integration Notes

Optional section noting:
- Memory context may be injected by the memory extension into related commands
- ROADMAP.md can inform what kinds of changes are needed (consult it before running /meta)
- Neither is required; /meta works without them

---

## Evidence/Examples

### Evidence A: The agent's forbidden list proves it doesn't create files

From `.claude/agents/meta-builder-agent.md` lines 27-31:
```
MUST NOT:
- Directly create commands, skills, rules, or context files
- Directly modify CLAUDE.md or README.md
- Write any files outside specs/
```

### Evidence B: The skill's allowed tools confirms the scope

From `.claude/skills/skill-meta/SKILL.md` frontmatter:
```yaml
allowed-tools: Task, Bash, Edit, Read, Write
```
No WebSearch, no WebFetch. The skill only creates local task entries.

### Evidence C: Stage 6 output proves only TODO/state.json are written

From meta-builder-agent.md Stage 6 (CreateTasks):
- `state.json Entry` - writes to specs/state.json
- `TODO.md Entry Format` - writes to specs/TODO.md
- No other file creation mentioned

### Evidence D: Actual interview questions are task-focused, not domain-focused

From meta-builder-agent.md Stage 2, Question 1:
```json
{
  "question": "What do you want to accomplish with this change?",
  "options": [
    {"label": "Add a new command"},
    {"label": "Add a new skill or agent"},
    {"label": "Fix or enhance existing component"},
    {"label": "Create documentation or rules"},
    {"label": "Something else"}
  ]
}
```

Compare to current guide's Question 1: "What is your primary domain or industry?" (with options like E-commerce, Healthcare, Financial services). These are completely different systems.

### Evidence E: Three modes in command spec

From `.claude/commands/meta.md` lines 12-15:
```
- No args: Start interactive interview (7 stages)
- PROMPT - Direct analysis of change request (abbreviated flow)
- --analyze - Analyze existing .claude/ structure (read-only)
```

Current guide never mentions modes at all.

### Evidence F: The wrong path in Resources

Current guide (line 450): `.claude/agent/subagents/meta.md`
Actual path: `.claude/agents/meta-builder-agent.md`
The "agent" (singular) subdirectory does not exist in this project.

---

## Companion Files Assessment

| File | Status | Issues |
|------|--------|--------|
| `meta-guide.md` | Completely wrong | Describes different system entirely |
| `interview-patterns.md` | Outdated | Interview stages reference old system; generic AI patterns not task planning |
| `architecture-principles.md` | Partially relevant | Good for generated-system design; says ".opencode" in purpose line |
| `standards-checklist.md` | Partially outdated | Frontmatter requirements too complex vs. actual agent frontmatter |
| `domain-patterns.md` | Tangentially relevant | E-commerce/business domains only matter post-task-creation |
| `context-revision-guide.md` | Mostly accurate | Generally correct guidance for meta tasks |

---

## Confidence Level

**High confidence** on all findings above. All conclusions are based on direct file reading:

- `meta-guide.md` vs. `meta-builder-agent.md`: The interview stages, outputs, and constraints directly contradict each other
- `meta.md` (command): Confirms three modes, argument syntax
- `skill-meta/SKILL.md`: Confirms thin wrapper pattern, allowed tools, delegation to Task tool
- `meta-builder-agent.md`: Complete authoritative specification of actual behavior

No speculation was required. The discrepancies are literal contradictions between the guide and the deployed implementation files.

**Specific high-confidence findings:**
1. /meta creates tasks only (not implementations) - CERTAIN
2. Three modes exist - CERTAIN
3. Real interview has 7 stages, not 4 phases with 12 questions - CERTAIN
4. Kahn's algorithm and DAG visualization are real features - CERTAIN
5. Performance statistics (+20%, etc.) are not verifiable outcomes of /meta - CERTAIN
6. Resource path `.claude/agent/subagents/meta.md` is wrong - CERTAIN

---

## Appendix: File Locations Verified

All files read during this research:

1. `/home/benjamin/.config/nvim/.claude/context/meta/meta-guide.md` - Current deployed guide (458 lines, fully wrong)
2. `/home/benjamin/.config/nvim/.claude/extensions/core/context/meta/meta-guide.md` - Extension source (identical to deployed)
3. `/home/benjamin/.config/nvim/.claude/agents/meta-builder-agent.md` - Authoritative agent spec (1405 lines)
4. `/home/benjamin/.config/nvim/.claude/commands/meta.md` - Command entry point (211 lines)
5. `/home/benjamin/.config/nvim/.claude/skills/skill-meta/SKILL.md` - Skill wrapper (228 lines)
6. `/home/benjamin/.config/nvim/.claude/context/meta/interview-patterns.md` - Companion file (222 lines)
7. `/home/benjamin/.config/nvim/.claude/context/meta/architecture-principles.md` - Companion file (266 lines)
8. `/home/benjamin/.config/nvim/.claude/context/meta/standards-checklist.md` - Companion file (380 lines)
9. `/home/benjamin/.config/nvim/.claude/context/meta/domain-patterns.md` - Companion file (256 lines)
10. `/home/benjamin/.config/nvim/.claude/context/meta/context-revision-guide.md` - Companion file (324 lines)
