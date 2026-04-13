---
task: 403
title: Split slides-agent into 3 specialized agents with Phase Checkpoint Protocol
status: complete
---

# Research Report: Task #403

**Task**: 403 - Split slides-agent into 3 specialized agents with Phase Checkpoint Protocol
**Started**: 2026-04-12T12:00:00Z
**Completed**: 2026-04-12T12:15:00Z
**Effort**: Research phase
**Dependencies**: None (unblocks 405, 407)
**Sources/Inputs**: Existing slides-agent.md, zed new agents, grant-agent Phase Checkpoint Protocol, DIFF.md, artifact-formats.md
**Artifacts**: This report
**Standards**: report-format.md

## Executive Summary

- The monolithic `slides-agent.md` (300 lines) must be replaced by 3 specialized agents from zed: `slides-research-agent.md`, `pptx-assembly-agent.md`, and `slidev-assembly-agent.md`
- Both assembly agents are **missing the Phase Checkpoint Protocol** that grant-agent implements (plan heading updates, per-phase commits, resume discovery)
- The research agent does NOT need phase tracking (single-stage research workflow)
- Context references in the zed agents use `.claude/context/` paths that must be rewritten to `.claude/extensions/present/context/` for the nvim extension structure

## Current State

### Existing slides-agent.md

Located at `/home/benjamin/.config/nvim/.claude/extensions/present/agents/slides-agent.md` (300 lines).

**Characteristics**:
- Handles both `slides_research` and `assemble` workflow types in a single agent
- 8-stage execution flow (Stage 0-8)
- Uses metadata-file return pattern (`.return-meta.json`)
- References talk pattern files, content templates, and talk modes
- No Phase Checkpoint Protocol -- no plan heading updates, no per-phase commits
- No output format distinction (no PPTX vs Slidev routing)

**What will be deleted**: The entire file. All functionality is covered by the 3 new agents.

### Current skill-slides SKILL.md

Located at `/home/benjamin/.config/nvim/.claude/extensions/present/skills/skill-slides/SKILL.md` (337 lines).

**Key routing details**:
- Currently routes all workflows to single `slides-agent`
- Has `slides_research` and `assemble` workflow types
- Extracts `output_format` from `forcing_data` but passes it to the single agent
- Task 405 will update this to multi-agent dispatch (not part of this task)

### Current manifest.json

Lists `slides-agent.md` in `provides.agents`. Task 407 will update this (not part of this task).

## New Agent Analysis

### 1. slides-research-agent.md (304 lines in zed)

**Source**: `/home/benjamin/.config/zed/.claude_NEW/agents/slides-research-agent.md`

**Purpose**: Material synthesis for research talks. Handles `workflow_type == "slides_research"` only.

**Key differences from old slides-agent**:
- Frontmatter: `name: slides-research-agent`, same `model: opus`
- Overview explicitly states format-agnostic -- produces same report regardless of final output format
- Stage 1 delegation context includes `output_format` field (not used by this agent, but preserved for downstream)
- Agent type in metadata: `slides-research-agent`
- Delegation path: `["orchestrator", "slides", "skill-slides", "slides-research-agent"]`
- **MUST NOT** items include loading PPTX context (items 8-9) and Slidev context
- Otherwise nearly identical to the research portion of old slides-agent

**Phase Checkpoint Protocol needed?**: NO. This agent runs a single-stage research workflow, not a multi-phase plan. Research produces one artifact and returns.

**What to copy verbatim**: Entire file from zed.

**Path adjustments needed**: Context references use `.claude/context/project/present/` which is correct for the extension's merged context paths (these get resolved via index.json, not direct filesystem access). No path changes needed.

### 2. pptx-assembly-agent.md (332 lines in zed)

**Source**: `/home/benjamin/.config/zed/.claude_NEW/agents/pptx-assembly-agent.md`

**Purpose**: PowerPoint generation via python-pptx. Handles `workflow_type == "assemble"` with `output_format == "pptx"`.

**Key features**:
- Reads slide-mapped research report from `specs/{NNN}_{SLUG}/reports/`
- Resolves design decisions (theme) from state.json or research report
- Maps slide types to PPTX components using `pptx-generation.md` patterns
- Generates self-contained Python script (`generate_deck.py`)
- Executes script to produce `.pptx` file
- Handles errors: python-pptx install, script failures, missing images, SVG limitations, large tables
- Stages: 0, 1, A1-A8 (8 assembly-specific stages)

**Phase Checkpoint Protocol**: **MISSING**. See gap analysis below.

### 3. slidev-assembly-agent.md (362 lines in zed)

**Source**: `/home/benjamin/.config/zed/.claude_NEW/agents/slidev-assembly-agent.md`

**Purpose**: Slidev project generation. Handles `workflow_type == "assemble"` with `output_format == "slidev"`.

**Key features**:
- Reads slide-mapped research report
- Resolves design decisions (theme)
- Scaffolds Slidev project from template (package.json, .npmrc, vite.config.ts)
- Maps slide types to Slidev markdown with Vue components
- Generates slides.md with frontmatter, layouts, speaker notes
- Generates style.css from theme JSON
- Verifies output and optionally runs pnpm install
- Stages: 0, 1, S1-S9 (9 assembly-specific stages)

**Phase Checkpoint Protocol**: **MISSING**. See gap analysis below.

## Phase Checkpoint Gap Analysis

### Reference Implementation: grant-agent.md

The Phase Checkpoint Protocol is documented in grant-agent.md at lines 397-427. The protocol consists of 6 steps:

1. **Read plan file**, identify current phase
2. **Update phase status** to `[IN PROGRESS]` in plan heading using Edit tool
3. **Execute phase steps** as documented
4. **Update phase status** to `[COMPLETED]` (or `[BLOCKED]`/`[PARTIAL]`) in plan heading
5. **Git commit** with message: `task {N} phase {P}: {phase_name}` (with session ID in body)
6. **Proceed to next phase** or return if blocked

**Key grant-agent properties**:
- Phase status lives ONLY in the plan heading (e.g., `### Phase 1: Validate Prerequisites [NOT STARTED]`)
- Uses Edit tool with exact old_string/new_string patterns
- Per-phase git commits enable granular history
- Resume point is always discoverable from plan file (find first `[NOT STARTED]` or `[IN PROGRESS]`)
- Protocol note: applies primarily to the `assemble` workflow

### What pptx-assembly-agent is MISSING

The pptx-assembly-agent has stages A1-A8 but:

1. **No plan file reading**: Does not look for or read a plan file in `specs/{NNN}_{SLUG}/plans/`
2. **No phase heading updates**: Does not update `### Phase {P}: {Name} [STATUS]` markers
3. **No per-phase git commits**: Does not commit after each stage/phase
4. **No resume discovery**: Cannot determine where to resume from if interrupted mid-assembly
5. **No phase-to-stage mapping**: Stages A1-A8 are internal to the agent but not linked to plan phases

### What slidev-assembly-agent is MISSING

Identical gaps as pptx-assembly-agent -- stages S1-S9 have no plan integration:

1. **No plan file reading**
2. **No phase heading updates**
3. **No per-phase git commits**
4. **No resume discovery**
5. **No phase-to-stage mapping**

### artifact-formats.md Phase Status Markers

From the rules file, valid phase status markers are:
- `[NOT STARTED]` - Phase not begun
- `[IN PROGRESS]` - Currently executing
- `[COMPLETED]` - Phase finished
- `[PARTIAL]` - Partially complete (interrupted)
- `[BLOCKED]` - Cannot proceed

These are the exact markers that must appear in plan headings.

## Implementation Specification

### Agent 1: slides-research-agent.md

**Action**: Copy verbatim from zed.

**Source**: `/home/benjamin/.config/zed/.claude_NEW/agents/slides-research-agent.md`
**Target**: `/home/benjamin/.config/nvim/.claude/extensions/present/agents/slides-research-agent.md`

**Modifications needed**: None. The file is ready to use as-is.

**Phase Checkpoint Protocol**: Not applicable (research workflow, not multi-phase assembly).

### Agent 2: pptx-assembly-agent.md

**Action**: Copy from zed, then ADD Phase Checkpoint Protocol section and modify execution flow.

**Source**: `/home/benjamin/.config/zed/.claude_NEW/agents/pptx-assembly-agent.md`
**Target**: `/home/benjamin/.config/nvim/.claude/extensions/present/agents/pptx-assembly-agent.md`

**What to copy verbatim**: Everything except the execution flow section needs the Phase Checkpoint Protocol injected.

**Phase Checkpoint Protocol to ADD** (insert as a new section between Stage 1 and Stage A1):

```markdown
## Phase Checkpoint Protocol

For assembly tasks with implementation plans (always for `assemble` workflow):

1. **Read plan file**, identify current phase
   ```bash
   plan_file=$(ls -t specs/{NNN}_{SLUG}/plans/*.md | head -1)
   ```
   - Parse plan headings for `### Phase {P}: {Name} [{STATUS}]`
   - Find first phase with `[NOT STARTED]` or `[IN PROGRESS]` status
   - If all phases are `[COMPLETED]`, skip to final metadata

2. **Before executing each phase**, update status to `[IN PROGRESS]`:
   - Use Edit tool:
     - old_string: `### Phase {P}: {Phase Name} [NOT STARTED]`
     - new_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`

3. **Execute the phase** (map plan phases to agent stages A1-A8)

4. **After completing each phase**, update status to `[COMPLETED]`:
   - Use Edit tool:
     - old_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`
     - new_string: `### Phase {P}: {Phase Name} [COMPLETED]`
   - On failure: `[PARTIAL]` or `[BLOCKED]`

5. **Git commit** per phase:
   ```bash
   git add -A && git commit -m "task {N} phase {P}: {phase_name}

   Session: {session_id}"
   ```

6. **Proceed to next phase** or return if blocked

**Phase-to-Stage Mapping** (typical plan structure):

| Plan Phase | Agent Stage(s) | Description |
|------------|---------------|-------------|
| Phase 1: Read Research Report | A1 | Parse slide-mapped report |
| Phase 2: Resolve Design | A2 | Theme and configuration |
| Phase 3: Map Slides to PPTX | A3 | Component mapping |
| Phase 4: Generate Script | A4 | Python assembly script |
| Phase 5: Execute and Verify | A5-A6 | Run script, verify output |

**Resume behavior**: When invoked on an interrupted task, read the plan file to find the first non-completed phase and resume from there. Skip already-completed stages.
```

**Additional modifications to existing content**:
1. In Stage A1, add a preamble step: "Before processing slides, read the plan file and update the current phase to [IN PROGRESS]"
2. In Stage A7 (Write Final Metadata), change the commit approach: per-phase commits replace the single final commit
3. Add to Critical Requirements MUST DO: "Follow Phase Checkpoint Protocol for all assembly operations"
4. Add to Critical Requirements MUST DO: "Update plan phase headings before and after each phase"
5. Add to Critical Requirements MUST DO: "Create per-phase git commits with session ID"

### Agent 3: slidev-assembly-agent.md

**Action**: Copy from zed, then ADD Phase Checkpoint Protocol section and modify execution flow.

**Source**: `/home/benjamin/.config/zed/.claude_NEW/agents/slidev-assembly-agent.md`
**Target**: `/home/benjamin/.config/nvim/.claude/extensions/present/agents/slidev-assembly-agent.md`

**What to copy verbatim**: Everything except the execution flow section needs the Phase Checkpoint Protocol injected.

**Phase Checkpoint Protocol to ADD** (insert as a new section between Stage 1 and Stage S1):

```markdown
## Phase Checkpoint Protocol

For assembly tasks with implementation plans (always for `assemble` workflow):

1. **Read plan file**, identify current phase
   ```bash
   plan_file=$(ls -t specs/{NNN}_{SLUG}/plans/*.md | head -1)
   ```
   - Parse plan headings for `### Phase {P}: {Name} [{STATUS}]`
   - Find first phase with `[NOT STARTED]` or `[IN PROGRESS]` status
   - If all phases are `[COMPLETED]`, skip to final metadata

2. **Before executing each phase**, update status to `[IN PROGRESS]`:
   - Use Edit tool:
     - old_string: `### Phase {P}: {Phase Name} [NOT STARTED]`
     - new_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`

3. **Execute the phase** (map plan phases to agent stages S1-S9)

4. **After completing each phase**, update status to `[COMPLETED]`:
   - Use Edit tool:
     - old_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`
     - new_string: `### Phase {P}: {Phase Name} [COMPLETED]`
   - On failure: `[PARTIAL]` or `[BLOCKED]`

5. **Git commit** per phase:
   ```bash
   git add -A && git commit -m "task {N} phase {P}: {phase_name}

   Session: {session_id}"
   ```

6. **Proceed to next phase** or return if blocked

**Phase-to-Stage Mapping** (typical plan structure):

| Plan Phase | Agent Stage(s) | Description |
|------------|---------------|-------------|
| Phase 1: Read Research Report | S1 | Parse slide-mapped report |
| Phase 2: Resolve Design | S2 | Theme and configuration |
| Phase 3: Scaffold Project | S3 | Copy template files |
| Phase 4: Map and Generate Slides | S4-S5 | Content mapping and slides.md |
| Phase 5: Style and Verify | S6-S7 | CSS generation and verification |

**Resume behavior**: When invoked on an interrupted task, read the plan file to find the first non-completed phase and resume from there. Skip already-completed stages.
```

**Additional modifications to existing content**:
1. In Stage S1, add a preamble step: "Before processing slides, read the plan file and update the current phase to [IN PROGRESS]"
2. In Stage S8 (Write Final Metadata), change the commit approach: per-phase commits replace the single final commit
3. Add to Critical Requirements MUST DO: "Follow Phase Checkpoint Protocol for all assembly operations"
4. Add to Critical Requirements MUST DO: "Update plan phase headings before and after each phase"
5. Add to Critical Requirements MUST DO: "Create per-phase git commits with session ID"

### File Operations Summary

| Action | File | Notes |
|--------|------|-------|
| DELETE | `extensions/present/agents/slides-agent.md` | Replaced by 3 new agents |
| CREATE | `extensions/present/agents/slides-research-agent.md` | Copy from zed verbatim |
| CREATE | `extensions/present/agents/pptx-assembly-agent.md` | Copy from zed + add Phase Checkpoint Protocol |
| CREATE | `extensions/present/agents/slidev-assembly-agent.md` | Copy from zed + add Phase Checkpoint Protocol |

### Git Commit Convention for Per-Phase Commits

Per user preference documented in auto-memory (`feedback_no_coauthored_by.md`), the per-phase commit messages in the Phase Checkpoint Protocol should omit the `Co-Authored-By` trailer. The grant-agent reference implementation includes this trailer, but for the nvim system, commits should use:

```
task {N} phase {P}: {phase_name}

Session: {session_id}
```

This matches the git commit conventions in `.claude/CLAUDE.md`.

## Risks and Considerations

### 1. Plan Structure Assumption
The Phase Checkpoint Protocol assumes plans will have `### Phase {P}: {Name} [STATUS]` headings. The planner-agent must generate plans in this format for assembly agents. This is already the standard format per `artifact-formats.md`, but the plan workflow for slides tasks (task 405) must ensure this.

### 2. Phase-to-Stage Mapping Flexibility
The mapping tables provided are "typical" -- actual plan phases may differ depending on what the planner generates. The agents should parse actual plan headings rather than assuming a fixed number of phases. The mapping is a guide for the planner, not a constraint on the agent.

### 3. Downstream Dependencies
- Task 405 (skill-slides multi-agent dispatch) depends on these agents existing
- Task 407 (manifest update) depends on the agent filenames being finalized
- Both are blocked on this task

### 4. Context Reference Paths
The zed agents use paths like `@.claude/context/project/present/...` which resolve correctly in both the zed and nvim systems because the extension loader merges extension context into the main index. No path changes are needed.

### 5. Metadata File Return Pattern
All 3 agents use the `.return-meta.json` metadata file pattern. This is consistent with the existing slides-agent and grant-agent implementations. The skill-slides SKILL.md already knows how to read this file.

### 6. Assembly Agent Status Value
Both assembly agents write `"status": "assembled"` to metadata. This is distinct from `"completed"` (which triggers Claude stop behavior) and is consistent with the grant-agent's assemble workflow.

## Appendix

### Search Queries and Files Examined
- `/home/benjamin/.config/nvim/.claude/extensions/present/agents/slides-agent.md` (current, to be deleted)
- `/home/benjamin/.config/zed/.claude_NEW/agents/slides-research-agent.md` (new, copy verbatim)
- `/home/benjamin/.config/zed/.claude_NEW/agents/pptx-assembly-agent.md` (new, copy + augment)
- `/home/benjamin/.config/zed/.claude_NEW/agents/slidev-assembly-agent.md` (new, copy + augment)
- `/home/benjamin/.config/nvim/.claude/extensions/present/agents/grant-agent.md` (Phase Checkpoint Protocol reference, lines 397-427)
- `/home/benjamin/.config/nvim/.claude/rules/artifact-formats.md` (phase status markers)
- `/home/benjamin/.config/zed/DIFF.md` (full change summary)
- `/home/benjamin/.config/nvim/.claude/extensions/present/skills/skill-slides/SKILL.md` (current routing)
- `/home/benjamin/.config/nvim/.claude/extensions/present/manifest.json` (current agent listing)
