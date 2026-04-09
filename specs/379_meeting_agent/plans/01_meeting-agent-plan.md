# Implementation Plan: Create meeting-agent for investor meeting note processing

- **Task**: 379 - Create meeting-agent for investor meeting note processing
- **Status**: [NOT STARTED]
- **Effort**: 1 hour
- **Dependencies**: Task 378 (meeting-format.md, csv-tracker.md context files)
- **Research Inputs**: specs/379_meeting_agent/reports/01_meeting-agent-research.md
- **Artifacts**: plans/01_meeting-agent-plan.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create a single agent file (`meeting-agent.md`) in the founder extension that processes raw investor meeting notes into structured meeting files with YAML frontmatter and updates CSV trackers. The agent follows the established founder extension agent structure (frontmatter, overview, metadata, tools, context, execution flow, error handling, critical requirements) but diverges from the forcing-question pattern used by other founder agents -- it takes a file path as input and processes autonomously with web research.

### Research Integration

The research report (01_meeting-agent-research.md) provides:
- Complete 7-stage execution flow design with detailed field source classification
- Tool list analysis (Read, Write, Edit, WebSearch, WebFetch, Glob, Bash, AskUserQuestion)
- `--update` mode specification for CSV-only sync
- Error handling patterns (8 cases with status responses)
- Follow-up meeting handling (append to existing file rather than creating new)
- Context loading strategy (meeting-format.md and csv-tracker.md always loaded)

### Roadmap Alignment

No ROAD_MAP.md consulted for this plan.

## Goals & Non-Goals

**Goals**:
- Create `meeting-agent.md` matching the exact structural conventions of existing founder agents (legal-council-agent, finance-agent)
- Define a complete 7-stage execution flow that transforms raw notes into structured meeting files
- Specify the `--update` mode branch for CSV-only sync operations
- Document all 8 error cases with status responses and recovery strategies

**Non-Goals**:
- Creating the skill wrapper (`skill-meeting/SKILL.md`) -- separate task
- Creating the `/meeting` command -- separate task
- Updating `manifest.json` routing entries -- separate task
- Implementing the agent logic (this is the agent definition file only)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Agent structure drifts from existing conventions | Inconsistency in extension | L | Use legal-council-agent as structural template, match section ordering exactly |
| Missing frontmatter fields in stage specification | Incomplete meeting files when agent runs | M | Cross-reference all 27 fields from meeting-format.md in Stage 4 specification |
| `--update` mode edge cases underspecified | Agent fails on CSV-only updates | L | Research report covers the abbreviated flow; include YAML parse error handling |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Create meeting-agent.md [NOT STARTED]

**Goal**: Write the complete agent definition file at `.claude/extensions/founder/agents/meeting-agent.md`

**Tasks**:
- [ ] Create YAML frontmatter with `name: meeting-agent` and `description: Investor meeting note processor with web research and CSV tracking`
- [ ] Write Overview section explaining autonomous file-processing pattern (no forcing questions), advisory nature note, and two modes (default full processing, `--update` CSV sync)
- [ ] Write Agent Metadata section: name, purpose ("Meeting note processing with web research"), invoked by ("skill-meeting via Task tool"), return format
- [ ] Write Allowed Tools section with 8 tools organized by category:
  - File Operations: Read, Write, Edit, Glob
  - Web Research: WebSearch, WebFetch
  - Verification: Bash
  - Interactive (fallback only): AskUserQuestion
- [ ] Write Context References section:
  - Always Load: `@.claude/extensions/founder/context/project/founder/templates/meeting-format.md`, `@.claude/extensions/founder/context/project/founder/patterns/csv-tracker.md`
  - Load for Output: `@.claude/context/formats/return-metadata-file.md`
- [ ] Write Stage 0 (Initialize Early Metadata) -- standard pattern, create `.return-meta.json` with `status: "in_progress"`
- [ ] Write Stage 1 (Parse Delegation Context) -- extract `notes_path`, `update_only` boolean, task context, session metadata. Include the `--update` mode branch: if `update_only` is true, skip to Stage 5
- [ ] Write Stage 2 (Read and Analyze Raw Meeting Notes) -- Read file at `notes_path`, extract investor name, meeting date, attendees, format, raw feedback, action items. Determine output directory (same as input), generate output filename (`YYYY-MM-DD_slug.md` per slug derivation rules). Check for existing meeting file (follow-up scenario)
- [ ] Write Stage 3 (Web Research on Investor) -- WebSearch for fund details, WebFetch investor website. Compile profile data mapping web findings to the 27 frontmatter fields per field source classification table (user-provided, web-research-required, agent-computed, defaults)
- [ ] Write Stage 4 (Generate Structured Meeting File) -- Build YAML frontmatter (all 27 fields), build markdown body following the body template (Investor Profile table, Team bios, Thesis, Portfolio highlights, Relationship Status, Fit Assessment, Meeting Log with themed feedback, Action Items table, Strategic Notes, Raw Notes verbatim). Run pre-delivery checklist (9 items from meeting-format.md). Write file. Include follow-up meeting handling: if existing file found, append to `meetings[]` array, update `last_touchpoint`, merge action items, preserve existing content
- [ ] Write Stage 5 (CSV Tracker Update) -- Discover CSV via Glob, create if missing with 22-column header. Parse YAML frontmatter, check for existing row by `investor_name`. Compute derived columns (`Meeting Count`, `Last Meeting`). Apply RFC 4180 quoting. Re-sort by Last Touchpoint descending. Write CSV
- [ ] Write Stage 6 (Write Metadata File) -- Write `.return-meta.json` with `status: "researched"`, artifacts array, metadata including `investor_name`, `meeting_date`, `action_items_count`, `csv_updated`, `web_research_sources`
- [ ] Write Stage 7 (Return Brief Text Summary) -- 8-line summary template: investor name, meeting date, file path, frontmatter field count, action items count, CSV status, web research source count, metadata confirmation
- [ ] Write Error Handling section as table with 8 cases: notes_path not found (failed), CSV not found (create new, continue), WebSearch no results (continue with "Unknown" fields, data_quality: "low"), WebFetch fails (fall back to WebSearch-only), existing meeting file for same investor (append to meetings[]), YAML parse error in --update mode (failed), raw notes too short (AskUserQuestion or partial), CSV write fails (researched with csv_updated: false)
- [ ] Write Critical Requirements section with MUST DO list (early metadata at Stage 0, load meeting-format.md and csv-tracker.md before processing, preserve raw notes verbatim, validate all 27 frontmatter fields, handle follow-up meetings by appending) and MUST NOT list (fabricate investor data not from web research, create new files for follow-up meetings with same investor, skip pre-delivery checklist, use "completed" status)

**Timing**: 1 hour

**Depends on**: none

**Files to create**:
- `.claude/extensions/founder/agents/meeting-agent.md` - Complete agent definition (~300-400 lines)

**Verification**:
- File exists at the correct path
- YAML frontmatter has `name` and `description` fields
- All 7 stages (0-7, where 0 is early metadata) are present
- Allowed Tools section lists all 8 tools
- Context References section lists meeting-format.md and csv-tracker.md
- Error Handling section covers all 8 error cases
- `--update` mode branch is documented in Stage 1 with skip-to-Stage-5 logic
- Section ordering matches legal-council-agent structure: Overview, Agent Metadata, Allowed Tools, Context References, ---, Execution Flow (Stages 0-7), ---, Error Handling, ---, Critical Requirements

## Testing & Validation

- [ ] Verify file structure matches legal-council-agent pattern (frontmatter, sections, horizontal rules)
- [ ] Verify all 27 frontmatter fields from meeting-format.md are referenced in Stage 4
- [ ] Verify all 22 CSV columns from csv-tracker.md are referenced in Stage 5
- [ ] Verify `--update` mode skips Stages 2-4 and goes directly to Stage 5
- [ ] Verify error handling table covers all 8 cases from research report
- [ ] Verify no forcing-question pattern is used (unlike other founder agents)

## Artifacts & Outputs

- `.claude/extensions/founder/agents/meeting-agent.md` - The agent definition file

## Rollback/Contingency

Delete the single file if the implementation is incorrect:
```bash
rm .claude/extensions/founder/agents/meeting-agent.md
```
No other files are modified by this task.
