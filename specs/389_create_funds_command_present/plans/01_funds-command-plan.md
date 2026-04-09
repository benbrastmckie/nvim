# Implementation Plan: Create /funds Command for Present Extension

- **Task**: 389 - Create /funds command for present extension
- **Status**: [IMPLEMENTING]
- **Effort**: 4 hours
- **Dependencies**: None (sibling tasks 387, 388, 390 are parallel; 391 integrates all)
- **Research Inputs**: specs/389_create_funds_command_present/reports/01_funds-command-research.md
- **Artifacts**: plans/01_funds-command-plan.md (this file)
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
- **Type**: meta

## Overview

This plan creates the `/funds` command for the present extension, adapting the founder extension's `/finance` command for research funding analysis. The command provides four analysis modes (LANDSCAPE, PORTFOLIO, JUSTIFY, GAP) with structured forcing questions, delegating to a funds-agent via a thin-wrapper skill. Five files are created: command definition, skill definition, agent definition, domain context, and patterns context. The definition of done is all five files created following established extension patterns, with the command callable (manifest integration deferred to task 391).

### Research Integration

- Integrated report: `reports/01_funds-command-research.md` (plan version 1, 2026-04-09)
- Key findings: four-mode structure, five forcing questions, XLSX output design, workflow integration with /grant and /budget

## Goals & Non-Goals

- **Goals**:
  - Create `/funds` command with STAGE 0 forcing questions and hybrid mode detection
  - Create skill-funds thin wrapper following skill-grant pattern
  - Create funds-agent with four analysis modes and XLSX/JSON output capability
  - Create funding-analysis.md domain context for research funding concepts
  - Create funding-forcing-questions.md patterns context for mode-specific questions
- **Non-Goals**:
  - Manifest integration (task 391)
  - Actual web API integration testing (funder databases)
  - Modifying existing /grant command
  - Creating test files (no test infrastructure for extension commands)

## Risks & Mitigations

- Risk: Overlap with /grant funder_research workflow. Mitigation: Clearly delineate in agent context -- /funds is strategic funding landscape analysis, /grant funder_research is proposal-specific targeting.
- Risk: Mode confusion between LANDSCAPE and PORTFOLIO. Mitigation: Include clear descriptions and examples in mode selection prompt.
- Risk: XLSX generation dependency on openpyxl. Mitigation: Follow finance-agent pattern with graceful skip if unavailable.
- Risk: Inconsistent structure with existing present extension. Mitigation: Follow grant command/skill/agent patterns exactly, verified against source files.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Create /funds Command Definition [COMPLETED]

- **Goal:** Create the command file that defines `/funds` syntax, mode detection, STAGE 0 forcing questions, and task creation flow.
- **Tasks:**
  - [ ] Create `.claude/extensions/present/commands/funds.md` (~250 lines)
  - [ ] Define frontmatter: description, allowed-tools (Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Read, Edit, AskUserQuestion), argument-hint, model (claude-opus-4-5-20251101)
  - [ ] Define four modes: LANDSCAPE, PORTFOLIO, JUSTIFY, GAP with descriptions matching research report table
  - [ ] Implement STAGE 0 pre-task forcing questions: mode selection (Step 0.1) then five questions (Steps 0.2-0.6) adapted from finance command
  - [ ] Implement mode detection: description string (task creation), task number (resume via skill), --quick (legacy standalone)
  - [ ] Implement task creation flow: read next_project_number, set language="present", set task_type="funds", store forcing_data in metadata, create state.json entry, create TODO.md entry, git commit
  - [ ] Implement task number flow: validate task exists with task_type="funds", delegate to skill-funds
  - [ ] Follow /finance command structure for STAGE 0 and /grant command structure for task creation
- **Timing:** 1 hour
- **Depends on:** none

### Phase 2: Create skill-funds Thin Wrapper [COMPLETED]

- **Goal:** Create the skill file that routes /funds requests to funds-agent via Task tool, with internal postflight.
- **Tasks:**
  - [ ] Create `.claude/extensions/present/skills/skill-funds/SKILL.md` (~300 lines)
  - [ ] Define frontmatter: name (skill-funds), description, allowed-tools (Task, Bash, Edit, Read, Write, AskUserQuestion)
  - [ ] Define trigger conditions: task language="present" with task_type="funds", /funds command with task number
  - [ ] Implement execution flow stages following skill-grant pattern:
    - Stage 1: Input validation (task lookup, status check)
    - Stage 2: Preflight status update (update-task-status.sh)
    - Stage 3: Create postflight marker
    - Stage 3a: Calculate artifact number
    - Stage 4: Prepare delegation context (include forcing_data, mode, research_path)
    - Stage 4b: Read and inject format specification
    - Stage 5: Invoke funds-agent via Task tool
    - Stage 6: Parse subagent return (read .return-meta.json)
    - Stage 6a: Validate artifact content
    - Stage 7: Postflight status update
    - Stage 8: Link artifacts in state.json and TODO.md
    - Stage 9: Git commit
    - Stage 10: Cleanup marker and metadata files
    - Stage 11: Return brief summary
  - [ ] Include MUST NOT postflight boundary section
  - [ ] Include error handling section (metadata missing, git failure, jq parse failure)
- **Timing:** 45 minutes
- **Depends on:** 1

### Phase 3: Create Domain Context File [IN PROGRESS]

- **Goal:** Create funding-analysis.md with research funding domain knowledge for the funds-agent.
- **Tasks:**
  - [ ] Create `.claude/extensions/present/context/project/present/domain/funding-analysis.md` (~250 lines)
  - [ ] Document research funding lifecycle: pre-award, award, post-award phases
  - [ ] Document federal funding: NIH (R01, R21, R03, K-awards, T-awards, U-awards, P-awards), NSF (standard, CAREER, RAPID), DOD, DOE, USDA
  - [ ] Document foundation funding: private foundations, community foundations, corporate foundations, giving patterns
  - [ ] Document cost-effectiveness analysis frameworks: cost per DALY, ICER, budget impact analysis
  - [ ] Document F&A (indirect cost) rate structures: on-campus, off-campus, negotiated rates, MTDC base
  - [ ] Document effort reporting: person-months, percent effort, salary cap calculations (NIH, NSF)
  - [ ] Document cost-sharing and matching requirements
  - [ ] Document subaward vs subcontract distinctions
  - [ ] Document budget categories: personnel, fringe, equipment, travel, supplies, contractual, other, indirect
  - [ ] Complement (not duplicate) existing funder-types.md and grant-terminology.md
- **Timing:** 45 minutes
- **Depends on:** 1

### Phase 4: Create Patterns Context File [NOT STARTED]

- **Goal:** Create funding-forcing-questions.md with mode-specific question routing and push-back patterns.
- **Tasks:**
  - [ ] Create `.claude/extensions/present/context/project/present/patterns/funding-forcing-questions.md` (~300 lines)
  - [ ] Define mode-specific question routing for each mode:
    - LANDSCAPE: research area, current funding, target agencies, budget range, decision context
    - PORTFOLIO: target funder, research alignment, prior awards from funder, budget constraints, strategic goals
    - JUSTIFY: budget document path, funder guidelines, cost categories, personnel justification, F&A rate
    - GAP: research portfolio, current awards, unfunded priorities, timeline, strategic plan reference
  - [ ] Define push-back patterns for vague answers (adapted from financial-forcing-questions.md):
    - "Some grants" -> push for specific award numbers, amounts, dates
    - "Federal funding" -> push for specific agencies, mechanisms, programs
    - "Standard budget" -> push for specific dollar range, known constraints
  - [ ] Define data quality assessment rubric for funding information
  - [ ] Define output format templates for structured funding data (JSON schema for each mode)
  - [ ] Include cross-references to existing present extension patterns (budget-patterns.md, evaluation-patterns.md)
- **Timing:** 45 minutes
- **Depends on:** 2

### Phase 5: Create funds-agent Definition [NOT STARTED]

- **Goal:** Create the agent definition with full execution flow for all four analysis modes, XLSX output, and metadata return.
- **Tasks:**
  - [ ] Create `.claude/extensions/present/agents/funds-agent.md` (~450 lines)
  - [ ] Define frontmatter: name (funds-agent), description, model (opus)
  - [ ] Define allowed tools: AskUserQuestion, Read, Write, Edit, Glob, Grep, WebSearch, WebFetch, Bash
  - [ ] Define context references: funding-analysis.md (always load), funding-forcing-questions.md (always load), return-metadata-file.md (load for output)
  - [ ] Implement execution flow:
    - Stage 0: Initialize early metadata (.return-meta.json with status "in_progress")
    - Stage 1: Parse delegation context (task_context, forcing_data, mode, research_path)
    - Stage 2: Mode-specific analysis execution:
      - LANDSCAPE: Web research for funding opportunities, funder database queries, opportunity mapping
      - PORTFOLIO: Funder-specific research, past awards analysis, priority alignment scoring
      - JUSTIFY: Budget document parsing, guideline cross-check, variance analysis
      - GAP: Portfolio mapping, funded vs needed analysis, strategic opportunity identification
    - Stage 3: Generate XLSX output (Python/openpyxl) with mode-specific sheets per research report design
    - Stage 4: Generate JSON metrics export
    - Stage 5: Write research report to specs/{NNN}_{SLUG}/reports/
    - Stage 6: Write final metadata to .return-meta.json
    - Stage 7: Return brief text summary
  - [ ] Include web resource references: NIH Reporter, NSF Award Search, ProPublica Nonprofit Explorer, Grants.gov
  - [ ] Include error handling: web resource unavailable (graceful degradation), openpyxl missing (skip XLSX), timeout handling
  - [ ] Follow finance-agent structure for XLSX generation and grant-agent structure for report format
- **Timing:** 1.5 hours
- **Depends on:** 3, 4

## Testing & Validation

- [ ] Verify all five files exist at correct paths
- [ ] Verify command frontmatter matches /grant command pattern (allowed-tools, model field)
- [ ] Verify skill follows skill-grant thin-wrapper pattern (all 11 stages present)
- [ ] Verify agent follows finance-agent pattern (early metadata, XLSX generation, mode routing)
- [ ] Verify domain context complements (does not duplicate) existing funder-types.md and grant-terminology.md
- [ ] Verify patterns context includes all four modes with complete question sets
- [ ] Verify cross-references between files are consistent (agent references skill, skill references agent, both reference context files)

## Artifacts & Outputs

- `.claude/extensions/present/commands/funds.md` - Command definition
- `.claude/extensions/present/skills/skill-funds/SKILL.md` - Skill thin wrapper
- `.claude/extensions/present/agents/funds-agent.md` - Agent definition
- `.claude/extensions/present/context/project/present/domain/funding-analysis.md` - Domain context
- `.claude/extensions/present/context/project/present/patterns/funding-forcing-questions.md` - Patterns context
- `specs/389_create_funds_command_present/summaries/01_funds-command-summary.md` - Execution summary

## Rollback/Contingency

- All five files are new additions with no existing file modifications, so rollback is simply deleting the created files
- If any phase fails, subsequent phases can still be attempted independently since they share only structural patterns, not runtime dependencies
- The /funds command is not callable until task 391 integrates it into the manifest, providing a natural gate before user exposure
