# Research Report: Task #379

**Task**: 379 - Create meeting-agent for investor meeting note processing
**Started**: 2026-04-08T00:00:00Z
**Completed**: 2026-04-08T00:00:00Z
**Effort**: Medium
**Dependencies**: Task 378 (meeting-format.md, csv-tracker.md context files)
**Sources/Inputs**: Codebase analysis of existing founder extension agents, context files, exemplar meeting files
**Artifacts**: specs/379_meeting_agent/reports/01_meeting-agent-research.md
**Standards**: report-format.md

## Executive Summary

- The meeting-agent should follow the established founder extension agent structure: YAML frontmatter, sections for overview/metadata/tools/context/execution-flow/error-handling/critical-requirements
- Unlike other founder agents (market, legal, finance), the meeting-agent does NOT use forcing questions -- it takes a file path as input and processes it autonomously with web research
- The agent needs two modes: default (full processing from raw notes) and `--update` (CSV-only sync from existing meeting file)
- All required patterns (meeting-format.md, csv-tracker.md) are already documented in task 378 context files

## Context & Scope

This research analyzes the exact design needed for a `meeting-agent` in the founder extension. The agent transforms raw investor meeting notes into structured meeting files (YAML frontmatter + formatted markdown body) and updates the CSV investor tracker.

### Scope Boundaries
- Agent definition only (`.claude/extensions/founder/agents/meeting-agent.md`)
- Corresponding skill definition (`skill-meeting/SKILL.md`)
- Routing and manifest updates
- Does NOT cover the `/meeting` command (separate task)

## Findings

### 1. Agent Structure Analysis

All founder extension agents follow an identical markdown structure:

```
---
name: {agent-name}
description: {one-line description}
---

# {Agent Title}

## Overview
## Agent Metadata
## Allowed Tools
## Context References
---
## Execution Flow
### Stage 0: Initialize Early Metadata
### Stage 1: Parse Delegation Context
### Stage 2+: Mode-specific stages
### Stage N-2: Write Metadata File
### Stage N-1: Return Brief Text Summary
---
## Error Handling
---
## Critical Requirements
```

**Key structural patterns observed across agents**:

| Pattern | legal-council-agent | finance-agent | market-agent |
|---------|-------------------|---------------|--------------|
| Frontmatter fields | name, description | name, description | name, description, mcp-servers |
| Interactive forcing questions | Yes (8 questions) | Yes (7 questions) | Yes (8+ questions) |
| Mode selection | REVIEW/NEGOTIATE/TERMS/DILIGENCE | AUDIT/MODEL/FORECAST/VALIDATE | VALIDATE/SIZE/SEGMENT/DEFEND |
| Web research | Yes (legal precedents) | Yes (benchmarks) | Yes (market data) |
| File output artifacts | Research report only | Report + XLSX + JSON | Research report only |
| Push-back patterns table | Yes | Yes | Yes |
| Error handling section | Yes (3 scenarios) | Yes (3 scenarios) | Yes (similar) |

**Meeting-agent divergence**: The meeting-agent breaks from the forcing-question pattern. It receives a file path (raw notes) and processes autonomously. No interactive questioning is needed -- the raw notes ARE the input data.

### 2. Recommended Tool List

| Tool | Purpose | Required |
|------|---------|----------|
| Read | Read raw meeting notes, existing meeting files, CSV tracker | Yes |
| Write | Create structured meeting file, update CSV | Yes |
| Edit | Update existing meeting file (follow-up meetings) | Yes |
| WebSearch | Research investor fund details, team, portfolio, thesis | Yes |
| WebFetch | Fetch specific investor website pages for detailed data | Yes |
| Glob | Find CSV file in meeting directory, find existing meeting files | Yes |
| Bash | CSV manipulation, file verification, YAML frontmatter extraction | Yes |
| AskUserQuestion | Clarification only (ambiguous notes, missing critical data) | Optional |

**Notable differences from other agents**:
- WebFetch is needed (other agents only use WebSearch) because investor websites must be scraped for fund details, team bios, and portfolio data
- AskUserQuestion is optional/fallback only -- not the primary interaction pattern
- No MCP servers needed

### 3. Stage-by-Stage Execution Flow Design

#### Stage 0: Initialize Early Metadata

Standard pattern -- create `specs/{NNN}_{SLUG}/.return-meta.json` with `"status": "in_progress"` before any work.

#### Stage 1: Parse Delegation Context

```json
{
  "task_context": {
    "task_number": N,
    "project_name": "{project_name}",
    "description": "Meeting notes: {investor_name}",
    "language": "founder",
    "task_type": "meeting"
  },
  "notes_path": "/absolute/path/to/raw-notes.md",
  "mode": null,
  "update_only": false,
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json",
  "metadata": {
    "session_id": "sess_...",
    "delegation_depth": 2,
    "delegation_path": ["orchestrator", "meeting", "skill-meeting"]
  }
}
```

**Key fields**:
- `notes_path` -- absolute path to the raw meeting notes file (required)
- `update_only` -- boolean, if true skip to CSV update stage (for `--update` mode)
- `mode` is not used for mode selection (unlike other agents); kept for consistency but always null

#### Stage 2: Read and Analyze Raw Meeting Notes

1. Read the file at `notes_path` using Read tool
2. Extract key information:
   - Investor name (from notes content or filename)
   - Meeting date (from notes content or filename)
   - Attendees (ours and theirs)
   - Meeting format/type
   - Raw feedback and discussion points
   - Action items mentioned
3. Determine the output directory (same directory as input file)
4. Generate the output filename: `YYYY-MM-DD_slug.md` using slug derivation rules from meeting-format.md
5. Check if a meeting file already exists for this investor (follow-up meeting scenario)

#### Stage 3: Web Research on Investor

1. **WebSearch**: Search for investor fund name to find:
   - Official website URL
   - Fund size and number
   - Investment stage focus
   - Geography
   - Team members and their backgrounds
   - Portfolio companies

2. **WebFetch**: Fetch the investor's website to extract:
   - Detailed team bios
   - Investment thesis
   - Portfolio highlights with raise amounts
   - Fund structure description
   - Check size range (if published)

3. **Compile profile data**: Map web research findings to the 27 frontmatter fields defined in meeting-format.md

**Field source classification** (from meeting-format.md):
- User-provided (from notes): `investor_name`, `primary_contact`, `meetings[]`, `next_action`
- Web research required: `website`, `fund_size`, `fund_number`, `portfolio_size`, `check_size_min`, `check_size_max`, `structure`, `team[]`, `geography`, `focus`
- Agent-computed: `fit_score`, `likely_role`, `strengths[]`, `gaps[]`, `open_actions`, `priority_action`, `tags[]`
- Defaults: `warm_intro` (false), `referral_source` (""), `pipeline_stage` ("post-meeting")

#### Stage 4: Generate Structured Meeting File

1. **Build YAML frontmatter** with all 27 required fields
2. **Build markdown body** following the body template from meeting-format.md:
   - Investor Profile table (from web research)
   - Team bios (from web research)
   - Thesis paragraph
   - Portfolio highlights table
   - Relationship Status table
   - Investor Fit Assessment (strengths, gaps, likely role)
   - Meeting Log with themed feedback sections
   - Action Items table (extracted from notes + agent-identified)
   - Strategic Notes (higher-order analysis)
   - Raw Notes section (verbatim original content)
3. **Run pre-delivery checklist** (from meeting-format.md):
   - All 27 frontmatter fields populated
   - `meetings[]` array complete
   - `open_actions` count matches NOT DONE items
   - `priority_action` matches most important action
   - `last_touchpoint` matches meeting date
   - Tags are lowercase kebab-case
   - Team bios sourced from web research
   - Raw Notes preserve complete original input

4. **Write the file** to `{directory}/YYYY-MM-DD_slug.md`

#### Stage 5: CSV Tracker Update

1. **Discover CSV**: Look for `*.csv` in the same directory as the meeting file
2. **If no CSV exists**: Create one with the 22-column header from csv-tracker.md
3. **Parse YAML frontmatter** from the just-written meeting file
4. **Check for existing row**: Match by `investor_name` (column 1)
   - If no existing row: append new row
   - If existing row: replace all 22 column values
5. **Compute derived columns**: `Meeting Count` = len(meetings[]), `Last Meeting` = meetings[-1].date
6. **Apply quoting rules**: RFC 4180 for fields containing commas
7. **Re-sort by Last Touchpoint** (column 12) descending
8. **Write updated CSV**

#### Stage 6: Write Metadata File

```json
{
  "status": "researched",
  "summary": "Processed meeting notes for {investor_name}. Created structured meeting file with {N} frontmatter fields, {M} action items. Updated CSV tracker.",
  "artifacts": [
    {
      "type": "report",
      "path": "{meeting_file_path}",
      "summary": "Structured investor meeting file for {investor_name}"
    }
  ],
  "metadata": {
    "session_id": "{from delegation context}",
    "agent_type": "meeting-agent",
    "delegation_depth": 2,
    "delegation_path": ["orchestrator", "meeting", "skill-meeting", "meeting-agent"],
    "investor_name": "{investor_name}",
    "meeting_date": "{YYYY-MM-DD}",
    "action_items_count": N,
    "csv_updated": true,
    "web_research_sources": ["website", "crunchbase", ...]
  },
  "next_steps": "Review meeting file and verify web research accuracy"
}
```

#### Stage 7: Return Brief Text Summary

```
Meeting notes processed for task {N}:
- Investor: {investor_name}
- Meeting date: {YYYY-MM-DD}
- Meeting file: {path/to/YYYY-MM-DD_slug.md}
- Frontmatter: 27 fields populated
- Action items: {N} extracted
- CSV tracker: Updated ({new row|existing row updated})
- Web research: {N} sources consulted
- Metadata written for skill postflight
```

### 4. --update Mode Specification

When `update_only: true` is passed in delegation context:

**Purpose**: Re-sync the CSV tracker from an existing meeting file without regenerating the meeting file itself. Useful when the user manually edits frontmatter fields.

**Abbreviated flow**:
1. Stage 0: Early metadata (same)
2. Stage 1: Parse delegation context (same)
3. Stage 2: Read existing meeting file at `notes_path` (which is now the meeting file itself, not raw notes)
4. Skip Stage 3 (no web research needed)
5. Skip Stage 4 (no file generation needed)
6. Stage 5: CSV update from existing frontmatter (same as full mode)
7. Stage 6: Write metadata with `"mode": "update"` field
8. Stage 7: Return summary noting update-only mode

**Edge case**: If the meeting file at `notes_path` does not have valid YAML frontmatter, return `"status": "failed"` with error message.

### 5. Context Loading Strategy

**Always Load** (at agent start):
- `@.claude/extensions/founder/context/project/founder/templates/meeting-format.md` -- Meeting file template with frontmatter schema, body template, and pre-delivery checklist
- `@.claude/extensions/founder/context/project/founder/patterns/csv-tracker.md` -- CSV column schema, update patterns, quoting rules

**Load for Output**:
- `@.claude/context/formats/return-metadata-file.md` -- Metadata file schema

**Not Loaded** (different from other founder agents):
- No forcing-questions pattern file (not interactive)
- No domain-specific framework file (meeting processing is self-contained)

### 6. Error Handling Patterns

| Error Case | Response | Status |
|------------|----------|--------|
| `notes_path` file not found | Return failed with file path in error | `failed` |
| CSV file not found in directory | Create new CSV with header row, continue | n/a (handled) |
| WebSearch returns no results for investor | Continue with notes-only data, mark web research fields as "Unknown" in frontmatter, note limitation | `researched` (with data_quality: "low") |
| WebFetch fails on investor website | Fall back to WebSearch-only data | `researched` |
| Existing meeting file found for same investor (follow-up) | Append to `meetings[]` array instead of creating new file | n/a (handled) |
| YAML frontmatter parse error (--update mode) | Return failed with parse error details | `failed` |
| Raw notes too short / no useful content | AskUserQuestion to clarify, or return partial | `partial` |
| CSV write fails (permissions, disk) | Return researched with `csv_updated: false` in metadata | `researched` |

**Error handling section format** (from existing agents):
```json
{
  "status": "partial|failed",
  "summary": "Error description",
  "artifacts": [],
  "partial_progress": {
    "stage": "web_research",
    "details": "Meeting file generated but web research incomplete"
  },
  "errors": [{
    "type": "execution",
    "message": "WebSearch returned no results for investor",
    "recoverable": true,
    "recommendation": "Manually add fund details to frontmatter, then run --update"
  }]
}
```

### 7. Skill and Routing Requirements

**New skill**: `skill-meeting/SKILL.md`
- Follows the thin-wrapper pattern from `skill-market/SKILL.md`
- Stages: Input validation -> Preflight status update -> Create postflight marker -> Prepare delegation context -> Invoke agent (Task tool) -> Parse return -> Postflight status update -> Artifact linking -> Git commit -> Cleanup -> Return

**Routing additions to manifest.json**:
```json
{
  "routing": {
    "research": {
      "founder:meeting": "skill-meeting"
    },
    "implement": {
      "founder:meeting": "skill-founder-implement"
    }
  }
}
```

**Note**: Meeting tasks go through research (meeting-agent creates the file) but may not need a separate plan phase. Implementation could be used for follow-up processing or batch operations.

**Manifest.json updates**:
- Add `"meeting-agent.md"` to `provides.agents`
- Add `"skill-meeting"` to `provides.skills`
- Add `"meeting.md"` to `provides.commands` (if a command is created)
- Add routing entries as above

### 8. Follow-Up Meeting Handling

When the agent detects an existing meeting file for the same investor (by checking `{directory}/*_{slug}.md`):

1. Read the existing meeting file
2. Parse existing YAML frontmatter
3. Append a new entry to the `meetings[]` array
4. Update `last_touchpoint` to new meeting date
5. Update `pipeline_stage` if appropriate (e.g., "post-meeting" -> "follow-up" -> "active")
6. Append new feedback themes to the Meeting Log section
7. Merge new action items into the Action Items table
8. Update `open_actions` count
9. Recalculate `priority_action`
10. Preserve all existing content (profile, fit assessment, etc.)
11. Update CSV tracker row

This matches the meeting-format.md guidance: "Do not create a new file for follow-up meetings with the same investor."

## Decisions

1. **No forcing questions**: Unlike all other founder agents, the meeting-agent processes file input directly. The raw notes themselves serve as the forcing question answers. AskUserQuestion is reserved only for genuine ambiguity in the notes.

2. **WebFetch inclusion**: Added WebFetch to the tool list (not present in other founder agents) because investor websites need direct fetching for team bios, portfolio data, and thesis extraction.

3. **Single-phase operation**: The meeting-agent produces the final output directly (no separate plan/implement cycle needed). The `/research` route creates the meeting file as its primary artifact, and the task can be marked complete after research.

4. **--update mode as boolean flag**: Rather than a full mode selection (REVIEW/NEGOTIATE/etc.), the meeting-agent uses a simple boolean `update_only` flag. This keeps the interface minimal since there is only one alternative mode.

5. **Status "researched" not "implemented"**: Even though the agent creates a final output file, it returns "researched" status for consistency with the skill-agent pattern. The skill postflight handles the status lifecycle.

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Web research returns stale/inaccurate fund data | Incorrect frontmatter values | Include confidence notes in body; user reviews before acting |
| Raw notes lack investor name | Cannot derive filename or research | AskUserQuestion fallback for critical missing data |
| CSV column order drift | Data corruption | Validate CSV header matches expected 22-column schema before update |
| Large raw notes exceed context | Agent truncates important content | Read full file; Raw Notes section preserves verbatim input |
| Follow-up detection false positive (similar investor names) | Wrong file updated | Match by exact `investor_name` frontmatter field, not filename pattern |

## Appendix

### Files Analyzed
- `/home/benjamin/.config/nvim/.claude/extensions/founder/agents/legal-council-agent.md` (420 lines)
- `/home/benjamin/.config/nvim/.claude/extensions/founder/agents/finance-agent.md` (610 lines)
- `/home/benjamin/.config/nvim/.claude/extensions/founder/agents/market-agent.md` (first 150 lines)
- `/home/benjamin/.config/nvim/.claude/extensions/founder/context/project/founder/templates/meeting-format.md` (245 lines)
- `/home/benjamin/.config/nvim/.claude/extensions/founder/context/project/founder/patterns/csv-tracker.md` (128 lines)
- `/home/benjamin/.config/nvim/.claude/context/formats/return-metadata-file.md` (503 lines)
- `/home/benjamin/.config/nvim/.claude/extensions/founder/skills/skill-market/SKILL.md` (337 lines)
- `/home/benjamin/.config/nvim/.claude/extensions/founder/manifest.json` (107 lines)

### Exemplar Meeting Files
- `/home/benjamin/Projects/Logos/Vision/shared/investors/VC/2026-04-07_halcyon.md` (Halcyon Ventures)
- `/home/benjamin/Projects/Logos/Vision/shared/investors/VC/2026-04-08_celero.md` (Celero Ventures)
- `/home/benjamin/Projects/Logos/Vision/shared/investors/VC/VC-spreadsheet.csv` (3 rows including header)
