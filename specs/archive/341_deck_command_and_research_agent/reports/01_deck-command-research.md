# Research Report: Task #341

**Task**: 341 - /deck command and deck-research-agent integration
**Started**: 2026-03-31T00:20:00Z
**Completed**: 2026-03-31T00:45:00Z
**Effort**: Medium
**Dependencies**: 340 (RESEARCHED)
**Sources/Inputs**: Codebase exploration (founder extension, present extension, core agents/skills/commands)
**Artifacts**: specs/341_deck_command_and_research_agent/reports/01_deck-command-research.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The founder extension already has 7 working command/skill/agent triplets (market, analyze, strategy, legal, project, sheet, finance) that provide a clear, well-established pattern for adding `/deck`
- An existing `/deck` command and `deck-agent` in the `present/` extension handle standalone deck generation (no task workflow); these will be migrated in task 344 but inform the design
- The new `/deck` command must follow the founder pattern: STAGE 0 forcing questions -> task creation -> `/research N` delegates to `deck-research-agent` via `skill-deck-research`
- The deck-research-agent differs fundamentally from other founder research agents: it synthesizes input materials (files, prompts, existing research) rather than asking forcing questions about markets/strategy
- Routing is via `founder:deck` in manifest.json, matching the existing `founder:market`, `founder:analyze`, etc. pattern

## Context & Scope

Task 341 is part of a 5-task deck integration series (340-344). This task creates the research-phase components: the `/deck` command, `deck-research-agent`, and `skill-deck-research`. The command creates tasks and the research agent produces structured reports that the deck-planner (task 342) will consume.

### Constraints

- All files go in `.claude/extensions/founder/` (founder extension owns the deck workflow)
- Must follow existing founder command/skill/agent patterns for consistency
- Must integrate with the existing task system (state.json, TODO.md, /research routing)
- Research agent output must be structured enough for deck-planner to consume
- Context files for deck patterns remain in `present/` until task 344 migrates them

## Findings

### 1. Founder Command Pattern (from market.md, finance.md, etc.)

All founder commands share this structure:

```
---
description: [purpose]
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Read, Edit, AskUserQuestion
argument-hint: "[description]" | TASK_NUMBER | /path/to/file.md | --quick [args]
---

STAGE 0: PRE-TASK FORCING QUESTIONS (for new tasks only)
  - Mode selection via AskUserQuestion
  - Essential forcing questions (one at a time)
  - Store forcing_data

CHECKPOINT 1: GATE IN
  - Generate session_id
  - Detect input type (description | task_number | file_path | --quick)
  - Handle each input type
  - Create task in state.json + TODO.md (if new)
  - Git commit task creation
  - STOP for new tasks

STAGE 2: DELEGATE
  - Invoke skill via Skill tool
  - Skill handles preflight/postflight

CHECKPOINT 2: GATE OUT
  - Verify research completed
  - Display result
```

**Key insight**: The `/deck` command should follow this exact pattern but with deck-specific forcing questions and modes.

### 2. Founder Skill Pattern (from skill-market/SKILL.md)

All founder skills follow this structure:

```
---
name: skill-{type}
description: [purpose]
allowed-tools: Task, Bash, Edit, Read, Write
---

Stage 1: Input Validation (lookup task in state.json)
Stage 2: Preflight Status Update (set RESEARCHING)
Stage 3: Create Postflight Marker
Stage 4: Prepare Delegation Context (include forcing_data)
Stage 5: Invoke Agent (via Task tool, NOT Skill tool)
Stage 6: Parse Subagent Return (read .return-meta.json)
Stage 7: Update Task Status (set RESEARCHED, postflight)
Stage 8: Link Artifacts
Stage 9: Git Commit
Stage 10: Cleanup (remove markers)
Stage 11: Return Brief Summary
```

**Key insight**: `skill-deck-research` should implement this exact 11-stage flow.

### 3. Founder Agent Pattern (from market-agent.md)

All founder research agents follow:

```
---
name: {type}-agent
description: [purpose]
mcp-servers: [optional list]
---

Allowed Tools: AskUserQuestion, Read, Write, Glob, WebSearch, Bash
Context References: @-references to domain and pattern files

Stage 0: Initialize Early Metadata (in_progress)
Stage 1: Parse Delegation Context
Stage 2: Mode Selection (if not pre-selected)
Stage 3-5: Forcing Questions (domain-specific)
Stage 6: Generate Research Report
Stage 7: Write Research Report
Stage 8: Write Metadata File
Stage 9: Return Brief Text Summary
```

### 4. Deck-Research-Agent: Key Differences from Other Founder Agents

The deck-research-agent has a fundamentally different research flow:

| Aspect | Other Founder Agents | Deck Research Agent |
|--------|---------------------|---------------------|
| Primary input | User forcing question answers | Files, prompts, task references |
| Research method | Interactive Q&A (8+ questions) | Material synthesis + analysis |
| Output structure | Domain-specific (TAM/SAM, BATNA, etc.) | Slide-mapped content extraction |
| Web research | SEC EDGAR, market data | Not typically needed |
| MCP servers | sec-edgar, firecrawl | None |

The deck-research-agent should:
1. Read input materials (files at paths, prompts, referenced task research reports)
2. Extract structured information mapped to the 10 YC slides
3. Identify information gaps (mark as `[MISSING: ...]`)
4. Synthesize a research report that the deck-planner can directly consume
5. Ask minimal follow-up questions only for critical missing information

### 5. Routing Configuration

The manifest.json routing table uses `language:task_type` keys:

```json
"routing": {
  "research": {
    "founder": "skill-market",           // default
    "founder:market": "skill-market",
    "founder:analyze": "skill-analyze",
    "founder:deck": "skill-deck-research" // NEW
  },
  "plan": {
    "founder:deck": "skill-deck-plan"     // task 342
  },
  "implement": {
    "founder:deck": "skill-deck-implement" // task 343
  }
}
```

### 6. Index Entries Pattern

Index entries use the structure from `index-entries.json`. Deck-specific entries should follow the pattern of existing deck entries in `present/index-entries.json`, but with `deck-research-agent` added to the agents array:

```json
{
  "path": "project/present/patterns/pitch-deck-structure.md",
  "load_when": {
    "agents": ["deck-agent", "deck-research-agent"],
    "languages": ["deck", "founder"],
    "task_types": ["deck"],
    "commands": ["/deck"]
  }
}
```

**Note**: The actual context files remain in `present/` until task 344. The index entries in `founder/index-entries.json` should reference the same paths but add the new agents to the load_when.

### 7. Existing Present Extension Deck Components

The present extension has:
- **Command**: `present/commands/deck.md` -- standalone generation, no task workflow
- **Skill**: `present/skills/skill-deck/SKILL.md` -- thin wrapper to deck-agent
- **Agent**: `present/agents/deck-agent.md` -- generates Typst directly from input

These are fundamentally different from what task 341 needs:
- Present's deck is a standalone generator (input -> output)
- Founder's deck needs task integration (input -> research report -> plan -> implementation)

The existing present components will be removed in task 344. The new founder components serve a different purpose.

### 8. Deck Command Input Types

Following the founder command pattern, `/deck` should accept:

| Input | Behavior |
|-------|----------|
| Description string | Extract key info, ask brief clarifying questions, create task |
| Task number | Run research on existing task |
| File path | Read file as primary input material, create task |
| Multiple file paths | Read all files as input materials |
| `--quick "prompt"` | Legacy: delegate to present's skill-deck for standalone generation |

**Unique to /deck**: The command should also accept references to other task research reports (e.g., from /market, /analyze, /strategy tasks) as source materials.

### 9. Deck Forcing Questions (STAGE 0)

Unlike other founder commands that ask 4-8 domain-specific questions, the deck command should ask minimal questions focused on deck configuration:

**Question 1: Deck Purpose**
```
What is this deck for?
- INVESTOR: Fundraising pitch to investors (YC 10-slide format)
- UPDATE: Progress update for existing investors
- INTERNAL: Strategy presentation for team
- PARTNERSHIP: Business partnership proposal
```

**Question 2: Source Materials**
```
What materials should inform the deck content?
- Task references (e.g., "use research from task 234")
- File paths to documents
- "None - I'll provide details in the prompt"
```

**Question 3: Company/Project Context (if no source materials)**
```
Briefly describe your company/project and what problem it solves.
```

Store as `forcing_data` with fields: `purpose`, `source_materials`, `context`.

### 10. Research Report Structure for Deck

The research report should be structured to map directly to the 10-slide YC structure, making it easy for the deck-planner to consume:

```markdown
## Slide Content Analysis

### 1. Title Slide
- **Company Name**: [extracted or MISSING]
- **One-liner**: [extracted or MISSING]

### 2. Problem
- **Pain Point**: [extracted or MISSING]
- **Evidence**: [extracted or MISSING]

### 3. Solution
- **Description**: [extracted or MISSING]
- **Differentiator**: [extracted or MISSING]

... (all 10 slides)

## Source Material Summary
- [List of materials analyzed with key extractions]

## Information Gaps
- [List of MISSING items with recommendations]

## Additional Content for Appendix
- [Content that doesn't fit in 10 slides but may be useful]
```

## Decisions

1. **Follow the founder command pattern exactly** -- `/deck` mirrors `/market`, `/analyze`, etc. with STAGE 0 forcing questions + GATE IN/OUT checkpoints
2. **Minimal forcing questions (2-3)** -- deck research is primarily material synthesis, not Q&A
3. **Research agent focuses on material synthesis** -- reads files, extracts slide-mapped content, identifies gaps
4. **Index entries reference present/ context paths** -- until task 344 migrates them
5. **Support task references as source materials** -- e.g., `/deck "Seed round pitch" --sources 234,235` to pull from prior research
6. **No MCP servers needed** for deck research agent
7. **Skill uses standard 11-stage flow** matching skill-market pattern

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Context files in present/ may change before task 344 | Index entries break | Use stable paths, coordinate with task 344 |
| Research report format too rigid for varied inputs | Planner receives incomplete data | Use flexible [MISSING] markers, allow extra sections |
| Conflict with present's /deck command | Confusion during migration | Founder's /deck creates tasks; present's generates standalone |
| Source material references to other tasks | Complex parsing, missing tasks | Validate task existence, graceful fallback |
| Agent needs access to files outside .claude/ | Permission or path issues | Use Read tool with absolute paths |

## Implementation Artifacts

### Files to Create

1. **`founder/commands/deck.md`** -- /deck command definition
   - STAGE 0: Forcing questions (purpose, sources, context)
   - CHECKPOINT 1: GATE IN (input detection, task creation)
   - STAGE 2: DELEGATE to skill-deck-research
   - CHECKPOINT 2: GATE OUT (verify research)
   - Estimated: ~300 lines (based on market.md at ~497 lines, deck is simpler)

2. **`founder/agents/deck-research-agent.md`** -- Research agent
   - Material synthesis focused (not forcing-question focused)
   - Reads files, prompts, task references
   - Outputs slide-mapped research report
   - Estimated: ~250 lines (based on market-agent at ~403 lines)

3. **`founder/skills/skill-deck-research/SKILL.md`** -- Research skill
   - Standard 11-stage flow matching skill-market
   - Routes to deck-research-agent via Task tool
   - Handles preflight/postflight
   - Estimated: ~200 lines (based on skill-market at ~336 lines)

### Files to Modify

4. **`founder/manifest.json`** -- Add routing entries
   - `routing.research["founder:deck"]`: "skill-deck-research"
   - `provides.agents`: add "deck-research-agent.md"
   - `provides.skills`: add "skill-deck-research"
   - `provides.commands`: add "deck.md"

5. **`founder/index-entries.json`** -- Add deck context entries
   - Reference pitch-deck-structure.md, touying-pitch-deck-template.md, yc-compliance-checklist.md
   - Add `deck-research-agent` to agents lists
   - Add `founder` to languages, `deck` to task_types
   - Add `/deck` to commands

6. **`founder/EXTENSION.md`** -- Add deck to skill-agent mapping and command table

## Appendix

### Search Queries Used
- Glob for `*founder*/**/*` -- extension structure
- Read of manifest.json, index-entries.json, EXTENSION.md
- Read of market.md, market-agent.md, skill-market/SKILL.md -- command/agent/skill patterns
- Read of present/commands/deck.md, present/agents/deck-agent.md, present/skills/skill-deck/SKILL.md -- existing deck system
- Read of present/manifest.json, present/index-entries.json -- present extension structure
- Read of present/context/project/present/domain/deck-workflow.md -- deck workflow
- Read of task 340 research report -- template decisions and prior findings
- Read of general-research-agent.md -- agent frontmatter pattern
- Read of return-metadata-file.md -- metadata schema
- Grep for deck-related tasks in TODO.md

### References
- `.claude/extensions/founder/manifest.json` -- routing configuration
- `.claude/extensions/founder/commands/market.md` -- canonical command pattern
- `.claude/extensions/founder/agents/market-agent.md` -- canonical agent pattern
- `.claude/extensions/founder/skills/skill-market/SKILL.md` -- canonical skill pattern
- `.claude/extensions/founder/index-entries.json` -- index entry format
- `.claude/extensions/present/commands/deck.md` -- existing standalone deck command
- `.claude/extensions/present/agents/deck-agent.md` -- existing deck generation agent
- `.claude/extensions/present/skills/skill-deck/SKILL.md` -- existing deck skill
- `.claude/extensions/present/manifest.json` -- present extension routing
- `specs/340_create_typst_deck_templates/reports/01_typst-deck-templates.md` -- task 340 findings
- `.claude/context/formats/return-metadata-file.md` -- metadata schema
- `.claude/agents/general-research-agent.md` -- agent frontmatter pattern
