---
task: 408
title: Audit all implementation agents for Phase Checkpoint Protocol compliance
status: complete
---

# Research Report: Task #408

**Task**: 408 - Audit all implementation agents for Phase Checkpoint Protocol compliance
**Started**: 2026-04-12T12:10:00Z
**Completed**: 2026-04-12T12:30:00Z
**Effort**: ~30 minutes
**Dependencies**: None
**Sources/Inputs**: Codebase analysis of all agent files across core and extensions
**Artifacts**: This report
**Standards**: report-format.md

## Executive Summary

- 13 implementation agents identified across core and 10 extensions
- 7 agents have the full Phase Checkpoint Protocol (phase status tracking in headings + per-phase git commits)
- 3 agents have partial compliance (phase status tracking but NO per-phase git commits)
- 3 agents are completely non-compliant (no phase tracking protocol at all)
- The reference implementation in grant-agent is the gold standard; general-implementation-agent also has the full protocol

## Context & Scope

This audit examines every agent file across `.claude/agents/` and `.claude/extensions/*/agents/` to determine which are implementation agents (execute multi-phase plans during `/implement`) and whether they comply with the Phase Checkpoint Protocol.

## Findings

### 1. Reference Protocol (Gold Standard)

The Phase Checkpoint Protocol, as defined in `grant-agent.md` (lines 397-427) and `general-implementation-agent.md` (lines 190-213), consists of 6 mandatory steps per phase:

```
1. Read plan file, identify current phase
2. Update phase status to [IN PROGRESS] in plan file
   - Edit tool: old_string: "### Phase {P}: {Phase Name} [NOT STARTED]"
   -            new_string: "### Phase {P}: {Phase Name} [IN PROGRESS]"
   - Phase status lives ONLY in the heading
3. Execute phase steps as documented
4. Update phase status to [COMPLETED] or [BLOCKED] or [PARTIAL]
   - Edit tool: old_string: "### Phase {P}: {Phase Name} [IN PROGRESS]"
   -            new_string: "### Phase {P}: {Phase Name} [COMPLETED]"
5. Git commit with message: task {N} phase {P}: {phase_name}
   - git add -A && git commit -m "task {N} phase {P}: {phase_name}\n\nSession: {session_id}"
6. Proceed to next phase or return if blocked
```

**Critical properties**:
- Resume point is always discoverable from plan file headings
- Git history reflects phase-level progress
- Failed phases can be retried from beginning

### 2. Agent Inventory

| Extension | Agent | Type | Has Phase Checkpoint | Notes |
|-----------|-------|------|---------------------|-------|
| core | general-research-agent | research | N/A | Not an implementation agent |
| core | general-implementation-agent | implement | **Yes (Full)** | Full protocol in dedicated section + Stage 4 |
| core | planner-agent | plan | N/A | Not an implementation agent |
| core | meta-builder-agent | meta | N/A | Not an implementation agent |
| core | code-reviewer-agent | review | N/A | Not an implementation agent |
| core | reviser-agent | revise | N/A | Not an implementation agent |
| core | spawn-agent | spawn | N/A | Not an implementation agent |
| latex | latex-research-agent | research | N/A | Not an implementation agent |
| latex | latex-implementation-agent | implement | **Yes (Full)** | Full protocol: heading updates + git commit + dedicated section |
| typst | typst-research-agent | research | N/A | Not an implementation agent |
| typst | typst-implementation-agent | implement | **Yes (Full)** | Full protocol: heading updates + git commit + dedicated section |
| nvim | neovim-research-agent | research | N/A | Not an implementation agent |
| nvim | neovim-implementation-agent | implement | **Yes (Full)** | Full protocol: heading updates + git commit + dedicated section |
| nix | nix-research-agent | research | N/A | Not an implementation agent |
| nix | nix-implementation-agent | implement | **Yes (Full)** | Full protocol: heading updates + git commit + dedicated section |
| web | web-research-agent | research | N/A | Not an implementation agent |
| web | web-implementation-agent | implement | **Yes (Full)** | Full protocol: heading updates + git commit + dedicated section |
| lean | lean-research-agent | research | N/A | Not an implementation agent |
| lean | lean-implementation-agent | implement | **Yes (Full)** | Full protocol with explicit Edit instructions + dedicated section |
| python | python-research-agent | research | N/A | Not an implementation agent |
| python | python-implementation-agent | implement | **Partial** | Marks [IN PROGRESS]/[COMPLETED] but NO git commit per phase, NO dedicated section |
| z3 | z3-research-agent | research | N/A | Not an implementation agent |
| z3 | z3-implementation-agent | implement | **Partial** | Marks [IN PROGRESS]/[COMPLETED] but NO git commit per phase, NO dedicated section |
| epi | epi-research-agent | research | N/A | Not an implementation agent |
| epi | epi-implement-agent | implement | **No** | Has 5 fixed phases but NO plan heading updates, NO git commits per phase |
| present | grant-agent | implement | **Yes (Full)** | Original reference implementation |
| present | slides-agent | research | N/A | Research/synthesis agent, not implementation |
| present | budget-agent | other | N/A | Budget workflow agent, not plan-phase executor |
| present | timeline-agent | other | N/A | Timeline workflow agent, not plan-phase executor |
| present | funds-agent | other | N/A | Funds research agent |
| founder | founder-implement-agent | implement | **Partial** | Marks [IN PROGRESS]/[COMPLETED] but NO git commit per phase, NO dedicated protocol section |
| founder | deck-builder-agent | implement | **No** | Has resume support ([COMPLETED]/[IN PROGRESS] detection) but NO heading update instructions, NO git commits |
| founder | deck-research-agent | research | N/A | Not an implementation agent |
| founder | deck-planner-agent | plan | N/A | Not an implementation agent |
| founder | finance-agent | research | N/A | Research agent |
| founder | financial-analysis-agent | research | N/A | Research agent |
| founder | analyze-agent | research | N/A | Research agent |
| founder | market-agent | research | N/A | Research agent |
| founder | strategy-agent | research | N/A | Research agent |
| founder | legal-council-agent | research | N/A | Research agent |
| founder | meeting-agent | other | N/A | Meeting management agent |
| founder | project-agent | research | N/A | Research agent |
| founder | spreadsheet-agent | research | N/A | Research agent |
| formal | formal-research-agent | research | N/A | Not an implementation agent |
| formal | logic-research-agent | research | N/A | Not an implementation agent |
| formal | math-research-agent | research | N/A | Not an implementation agent |
| formal | physics-research-agent | research | N/A | Not an implementation agent |
| filetypes | filetypes-router-agent | router | N/A | Router, not implementation agent |
| filetypes | presentation-agent | other | N/A | Single-step conversion, not multi-phase |
| filetypes | spreadsheet-agent | other | N/A | Single-step conversion |
| filetypes | scrape-agent | other | N/A | Single-step scraping |
| filetypes | document-agent | other | N/A | Single-step conversion |
| filetypes | docx-edit-agent | other | N/A | Single-step editing |

### 3. Non-Compliant Implementation Agents

#### 3a. Completely Non-Compliant (No Protocol)

**epi-implement-agent** (`extensions/epidemiology/agents/epi-implement-agent.md`)
- Has 5 hardcoded analysis phases (data prep, EDA, primary analysis, sensitivity, reporting)
- Tracks `phases_completed` in metadata partial_progress
- Does NOT update plan file headings with status markers
- Does NOT do git commits per phase
- Does NOT have a Phase Checkpoint Protocol section
- **Gap**: No resume from plan headings; no per-phase git history

**deck-builder-agent** (`extensions/founder/agents/deck-builder-agent.md`)
- Has basic resume detection (checks for [COMPLETED]/[IN PROGRESS] in plan)
- Does NOT provide Edit tool instructions for updating headings
- Does NOT do git commits per phase
- Does NOT have a Phase Checkpoint Protocol section
- **Gap**: Resume detection exists but no active heading management; no per-phase commits

#### 3b. Partially Compliant (Status Tracking but No Git Commits)

**python-implementation-agent** (`extensions/python/agents/python-implementation-agent.md`)
- Stage 4 lists: "Mark phase [IN PROGRESS]" and "Mark phase [COMPLETED] or [PARTIAL]"
- Does NOT show Edit tool instructions with old_string/new_string
- Does NOT include git commit per phase step
- Does NOT have a dedicated Phase Checkpoint Protocol section
- **Gap**: Mentions phase markers informally but lacks explicit Edit instructions and git commits

**z3-implementation-agent** (`extensions/z3/agents/z3-implementation-agent.md`)
- Identical structure to python-implementation-agent
- Stage 4 lists: "Mark phase [IN PROGRESS]" and "Mark phase [COMPLETED] or [PARTIAL]"
- Does NOT show Edit tool instructions with old_string/new_string
- Does NOT include git commit per phase step
- Does NOT have a dedicated Phase Checkpoint Protocol section
- **Gap**: Same as python agent -- informal mention, no Edit instructions, no git commits

**founder-implement-agent** (`extensions/founder/agents/founder-implement-agent.md`)
- Marks phases [IN PROGRESS] and [COMPLETED] in plan headings
- Has resume point detection from plan markers
- Does NOT include git commit per phase step
- Does NOT have a dedicated Phase Checkpoint Protocol section
- **Gap**: Missing per-phase git commits; otherwise structurally close to compliant

### 4. Recommended Fix Template

The following markdown section can be inserted into non-compliant agents to add the Phase Checkpoint Protocol. Place it after the execution flow stages and before the error handling section:

```markdown
## Phase Checkpoint Protocol

For each phase in the implementation plan:

1. **Read plan file**, identify current phase
2. **Update phase status** to `[IN PROGRESS]` in plan file
   - Use Edit tool with:
     - old_string: `### Phase {P}: {Phase Name} [NOT STARTED]`
     - new_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`
   - Phase status lives ONLY in the heading
3. **Execute phase steps** as documented
4. **Update phase status** to `[COMPLETED]` or `[BLOCKED]` or `[PARTIAL]`
   - Use Edit tool with:
     - old_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`
     - new_string: `### Phase {P}: {Phase Name} [COMPLETED]`
5. **Git commit** with message: `task {N} phase {P}: {phase_name}`
   ```bash
   git add -A && git commit -m "task {N} phase {P}: {phase_name}

   Session: {session_id}"
   ```
6. **Proceed to next phase** or return if blocked

**This ensures**:
- Resume point is always discoverable from plan file
- Git history reflects phase-level progress
- Failed phases can be retried from beginning
```

**Additional changes needed per agent**:

For **python-implementation-agent** and **z3-implementation-agent**:
- Replace the informal Stage 4 bullet list with explicit A/B/C/D substeps matching the pattern in `general-implementation-agent.md` (Mark In Progress -> Execute -> Verify -> Mark Complete)
- Add the Phase Checkpoint Protocol section above

For **epi-implement-agent**:
- Add plan heading update steps around each of the 5 fixed phases
- Add git commit after each phase
- Add the Phase Checkpoint Protocol section
- This agent has a unique structure (fixed 5-phase R workflow) so the protocol integration needs to wrap each existing phase section

For **founder-implement-agent**:
- Add git commit step after each phase mark-complete
- Add the Phase Checkpoint Protocol section

For **deck-builder-agent**:
- Add explicit Edit tool instructions for phase heading updates
- Add git commit step per phase
- Add the Phase Checkpoint Protocol section

### 5. Priority Order

Ordered by usage frequency and risk of lost progress:

| Priority | Agent | Reason |
|----------|-------|--------|
| 1 | **founder-implement-agent** | Closest to compliant (only missing git commits). High usage for market sizing, competitive analysis, GTM reports. |
| 2 | **python-implementation-agent** | Common task type. Fix is straightforward -- expand existing informal mentions. |
| 3 | **z3-implementation-agent** | Same template as python, fix simultaneously. |
| 4 | **epi-implement-agent** | More complex fix due to unique 5-phase structure. Lower frequency but high-value (R analysis scripts). |
| 5 | **deck-builder-agent** | Founder pitch deck assembly. Needs full protocol addition. |

## Decisions

- Classified agents as "implementation" only if they execute multi-phase plans from `/implement` command
- Single-step agents (filetypes converters, budget/timeline workflow agents) are N/A
- Research and planning agents are N/A
- The slides-agent is classified as research (produces slide-mapped reports, not multi-phase plan execution)
- Grant-agent's Phase Checkpoint Protocol section (lines 397-427) is the canonical reference

## Risks & Mitigations

- **Risk**: Non-compliant agents lose progress on interruption because plan file does not reflect current phase
  - **Mitigation**: Priority fix for most-used agents first
- **Risk**: Without per-phase git commits, `/implement` resume cannot rely on git history
  - **Mitigation**: Plan heading markers provide primary resume capability even without commits
- **Risk**: Epi-implement-agent has unique structure that may resist template application
  - **Mitigation**: Wrap existing phase sections rather than restructuring the agent

## Appendix

### Files Examined

**Core agents** (7 total):
- `.claude/agents/general-implementation-agent.md` - COMPLIANT
- `.claude/agents/general-research-agent.md` - N/A (research)
- `.claude/agents/planner-agent.md` - N/A (planning)
- `.claude/agents/meta-builder-agent.md` - N/A (meta)
- `.claude/agents/code-reviewer-agent.md` - N/A (review)
- `.claude/agents/reviser-agent.md` - N/A (revise)
- `.claude/agents/spawn-agent.md` - N/A (spawn)

**Extension agents** (43 total across 10 extensions):
- latex (2): implementation-agent COMPLIANT, research-agent N/A
- typst (2): implementation-agent COMPLIANT, research-agent N/A
- nvim (2): implementation-agent COMPLIANT, research-agent N/A
- nix (2): implementation-agent COMPLIANT, research-agent N/A
- web (2): implementation-agent COMPLIANT, research-agent N/A
- lean (2): implementation-agent COMPLIANT, research-agent N/A
- python (2): implementation-agent PARTIAL, research-agent N/A
- z3 (2): implementation-agent PARTIAL, research-agent N/A
- epi (2): implement-agent NON-COMPLIANT, research-agent N/A
- present (5): grant-agent COMPLIANT, slides/budget/timeline/funds N/A
- founder (13): founder-implement-agent PARTIAL, deck-builder-agent NON-COMPLIANT, rest N/A
- formal (4): all research agents N/A
- filetypes (5): all single-step/router agents N/A

### Compliance Summary

| Status | Count | Agents |
|--------|-------|--------|
| Full compliance | 8 | general-implementation, latex-impl, typst-impl, nvim-impl, nix-impl, web-impl, lean-impl, grant-agent |
| Partial (no git commits) | 3 | python-impl, z3-impl, founder-implement |
| Non-compliant | 2 | epi-implement, deck-builder |
| N/A (not implementation) | 37 | All research, plan, review, meta, router, single-step agents |
