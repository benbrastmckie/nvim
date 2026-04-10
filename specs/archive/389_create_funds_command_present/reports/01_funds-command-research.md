# Research Report: Create /funds Command for Present Extension

- **Task**: 389 - Create /funds command for present extension
- **Started**: 2026-04-09T19:42:30Z
- **Completed**: 2026-04-09T19:45:00Z
- **Effort**: 3-5 hours (estimated for implementation)
- **Dependencies**: None (sibling tasks 387, 388, 390 are parallel; 391 integrates all)
- **Sources/Inputs**:
  - `.claude/extensions/founder/commands/finance.md` - Source command to adapt
  - `.claude/extensions/founder/skills/skill-finance/SKILL.md` - Source skill pattern
  - `.claude/extensions/founder/agents/finance-agent.md` - Source agent pattern
  - `.claude/extensions/founder/context/project/founder/domain/financial-analysis.md` - Financial frameworks
  - `.claude/extensions/founder/context/project/founder/patterns/financial-forcing-questions.md` - Forcing question framework
  - `.claude/extensions/present/commands/grant.md` - Existing present extension command
  - `.claude/extensions/present/skills/skill-grant/SKILL.md` - Existing present extension skill
  - `.claude/extensions/present/agents/grant-agent.md` - Existing present extension agent
  - `.claude/extensions/present/context/project/present/` - Present domain context files
- **Artifacts**: This report
- **Standards**: report-format.md, artifact-formats.md, state-management.md

## Project Context

- **Upstream Dependencies**: Present extension (`grant-agent`, `skill-grant`, `/grant` command); founder extension `/finance` command as adaptation source
- **Downstream Dependents**: Task 391 (manifest integration); grant workflow users needing funding analysis
- **Alternative Paths**: Could extend `/grant` with `--funds` flag, but separate command provides cleaner separation of concerns
- **Potential Extensions**: Integration with web-based funder databases, 990 form analysis automation

## Executive Summary

- The `/funds` command adapts the founder extension's `/finance` command for research funding contexts, replacing startup financial analysis with grant-specific funding landscape analysis
- Four analysis modes map from founder (AUDIT/MODEL/FORECAST/VALIDATE) to present (LANDSCAPE/PORTFOLIO/JUSTIFY/GAP) reflecting research funding workflows
- The implementation requires 5 deliverables: command file, skill file, agent file, domain context file, and patterns context file
- The existing present extension provides a well-established pattern (grant command/skill/agent) to follow for structural consistency
- Forcing questions must be adapted from startup financial metrics (burn rate, CAC, LTV) to research funding metrics (direct/indirect costs, effort allocation, cost-effectiveness ratios)

## Context & Scope

Task 389 creates a `/funds` command within the present extension. The present extension currently supports grant proposal writing through the `/grant` command. The `/funds` command adds a complementary capability: analyzing the funding landscape, mapping funder portfolios, verifying budget justifications, and identifying funding gaps.

The founder extension's `/finance` command provides the architectural template. That command supports AUDIT/MODEL/FORECAST/VALIDATE modes with forcing questions, XLSX spreadsheet generation, and JSON metrics export. These capabilities must be recontextualized for research funding rather than startup finance.

### Key Differences Between Domains

| Aspect | Founder /finance | Present /funds |
|--------|-----------------|----------------|
| **Users** | Startup founders | Researchers, PIs, grant managers |
| **Documents** | P&L, cap table, projections | Budget justifications, 990 forms, award letters |
| **Metrics** | Burn rate, CAC, LTV, runway | Direct/indirect costs, effort %, F&A rate, cost-effectiveness |
| **Analysis** | Financial health, investor readiness | Funder fit, budget compliance, gap analysis |
| **Output** | Investor-ready financials | Funder landscape maps, budget verification |
| **Verification** | Revenue vs Stripe vs contracts | Budget vs actuals vs agency guidelines |

## Findings

### 1. Command Structure Analysis

The founder `/finance` command follows a hybrid pattern with STAGE 0 pre-task forcing questions:

1. **STAGE 0**: Ask forcing questions before task creation (mode selection, 5 questions)
2. **Task creation**: Store forcing_data in task metadata
3. **Task number input**: Resume research on existing task via skill delegation

The `/funds` command should follow this same hybrid pattern but with research-funding-specific questions.

**Proposed modes for /funds**:

| Mode | Purpose | Analogous to Founder |
|------|---------|---------------------|
| **LANDSCAPE** | Map funding opportunities for a research area | AUDIT (survey/verify) |
| **PORTFOLIO** | Analyze a funder's portfolio and priorities | MODEL (build understanding) |
| **JUSTIFY** | Verify budget justification against funder guidelines | VALIDATE (stress test) |
| **GAP** | Identify unfunded areas and strategic opportunities | FORECAST (project forward) |

### 2. Forcing Questions Design

Adapted from founder financial forcing questions for research funding context:

**Q1: Research Area / Project**
- "What research project or area needs funding analysis?"
- Push for: Specific aims, methodology, discipline
- Reject: "My research" or "the project"

**Q2: Funding History / Current Awards**
- "What current or past funding do you have? List each award, funder, amount, and period."
- Push for: Specific award numbers, amounts, dates
- Reject: "We have some grants" or "NIH-funded"

**Q3: Target Funders**
- "Which funders or programs are you targeting? Or should we survey the landscape?"
- Push for: Specific mechanisms (R01, R21), foundations, programs
- Reject: "Federal funding" without specifics

**Q4: Budget Parameters**
- "What is the budget range you need? Any cost constraints (salary caps, F&A limits)?"
- Push for: Specific dollar range, known constraints
- Reject: "Standard funding levels"

**Q5: Decision Context**
- "What funding decision does this analysis inform?"
- Examples: "Whether to pursue K99/R00 vs R21", "Resubmission strategy after A1 triage", "Which institute to target"

### 3. Agent Design

The funds-agent should follow the grant-agent pattern:

- **Name**: funds-agent
- **Model**: opus (consistent with research agents)
- **Invoked by**: skill-funds (via Task tool)
- **Return format**: Brief text summary + metadata file

**Tools needed**:
- AskUserQuestion - One-at-a-time forcing questions
- Read/Write/Edit/Glob/Grep - File operations
- WebSearch/WebFetch - Funder database research, 990 lookup, NIH Reporter, NSF Awards
- Bash - Python/openpyxl for XLSX generation

**Key web resources for automated research**:
- NIH Reporter (reporter.nih.gov) - Past NIH awards
- NSF Award Search (nsf.gov/awardsearch) - Past NSF awards
- ProPublica Nonprofit Explorer - 990 forms for foundations
- Grants.gov - Federal funding opportunities
- Foundation Directory Online - Foundation giving patterns

### 4. Skill Design

The skill-funds follows the thin-wrapper pattern established by skill-grant and skill-finance:

- Preflight: Update status to "researching"
- Create postflight marker
- Prepare delegation context with forcing_data
- Invoke funds-agent via Task tool
- Postflight: Parse metadata, update status to "researched", link artifacts, commit, cleanup

### 5. Context Files Needed

**Domain context** (`context/project/present/domain/funding-analysis.md`):
- Research funding lifecycle (pre-award, award, post-award)
- Federal vs foundation vs industry funding comparison
- Cost-effectiveness analysis frameworks for research
- F&A rate structures and negotiation
- Effort reporting and certification
- Salary cap calculations (NIH, NSF)
- Cost-sharing and matching requirements
- Subaward vs subcontract distinctions

**Patterns context** (`context/project/present/patterns/funding-forcing-questions.md`):
- Mode-specific question routing (LANDSCAPE/PORTFOLIO/JUSTIFY/GAP)
- Push-back patterns for vague funding answers
- Data quality assessment for funding information
- Output format for structured funding data

### 6. Spreadsheet Output Design

Adapted from finance-agent XLSX generation:

**Sheet 1: Funding Landscape**
- Columns: Funder, Program, Range, Deadline, Fit Score, Notes
- Input cells (blue) for user-provided data
- Formula cells for fit scoring

**Sheet 2: Budget Verification**
- Columns: Category, Requested, Guideline Max, Variance, Status
- Cross-check formulas against funder guidelines
- Conditional formatting for over-limit items

**Sheet 3: Gap Analysis**
- Columns: Research Area, Funded Amount, Needed Amount, Gap, Priority
- Summary formulas for total funding gap

**JSON metrics export** for potential Typst integration:
```json
{
  "metadata": { "project": "...", "date": "...", "mode": "LANDSCAPE" },
  "summary": {
    "funders_analyzed": 12,
    "opportunities_identified": 5,
    "total_potential_funding": 2500000,
    "funding_gap": 750000
  },
  "funders": [...],
  "budget_verification": {...},
  "gap_analysis": {...}
}
```

### 7. Existing Present Extension Integration Points

The `/funds` command complements `/grant` by providing pre-proposal analysis:

- **Workflow**: `/funds` (analyze landscape) -> `/grant` (write proposal) -> `/budget` (task 387, create budget XLSX)
- **Shared context**: Both use funder-types.md, budget-patterns.md, grant-terminology.md
- **Distinct roles**: `/funds` = strategic funding analysis; `/grant` = proposal writing; `/budget` = budget spreadsheet creation

### 8. File Inventory for Implementation

| Deliverable | Path | Lines (est.) |
|-------------|------|-------------|
| Command | `.claude/extensions/present/commands/funds.md` | ~250 |
| Skill | `.claude/extensions/present/skills/skill-funds/SKILL.md` | ~300 |
| Agent | `.claude/extensions/present/agents/funds-agent.md` | ~450 |
| Domain context | `.claude/extensions/present/context/project/present/domain/funding-analysis.md` | ~250 |
| Patterns context | `.claude/extensions/present/context/project/present/patterns/funding-forcing-questions.md` | ~300 |

Total estimated: ~1,550 lines across 5 files.

## Decisions

- **Command name**: `/funds` (not `/funding` or `/finance`) -- matches task description, avoids collision with founder `/finance`
- **Four modes**: LANDSCAPE/PORTFOLIO/JUSTIFY/GAP -- maps to research funding workflows rather than reusing founder's AUDIT/MODEL/FORECAST/VALIDATE
- **Separate command**: Not a flag on `/grant` -- different concern (analysis vs writing), different agent, different forcing questions
- **XLSX output**: Include spreadsheet generation for funding landscape and budget verification -- consistent with founder pattern
- **Agent model**: opus -- consistent with all research agents in the system

## Recommendations

1. **Follow the /finance command pattern closely** for structural consistency. Adapt the STAGE 0 forcing questions and hybrid mode detection, but replace all startup financial concepts with research funding concepts.

2. **Reuse existing present extension context** (funder-types.md, budget-patterns.md, grant-terminology.md) rather than duplicating. The new funding-analysis.md and funding-forcing-questions.md should complement, not overlap, with existing context.

3. **Design for workflow integration** with the existing `/grant` command. The funds-agent should be aware that users may run `/funds` before `/grant` and produce output that informs proposal strategy.

4. **Include web research capability** for automated funder lookup. NIH Reporter, NSF Award Search, and ProPublica 990 data are freely available and can provide concrete portfolio data during PORTFOLIO mode.

5. **Implementation phasing**: Start with the command and skill (structural), then the agent (functional), then context files (domain knowledge). This matches the standard implementation pattern for extension commands.

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Overlap with /grant funder_research workflow | Medium | Medium | Clearly delineate: /funds = strategic analysis, /grant funder_research = specific proposal targeting |
| Web API changes for funder databases | Low | Low | Graceful degradation when web resources unavailable |
| Mode confusion (LANDSCAPE vs PORTFOLIO) | Medium | Low | Clear descriptions in mode selection prompt; provide examples |
| XLSX generation dependency (openpyxl) | Low | Low | Follow finance-agent pattern: skip XLSX gracefully if unavailable |

## Appendix

### Reference: Founder /finance Command Structure

```
/finance command
  |-> STAGE 0: Pre-task forcing questions (5 questions)
  |-> Mode detection: description | task_number | file_path | --quick
  |-> Task creation with forcing_data stored in metadata
  |-> Delegate to skill-finance -> finance-agent
  |-> Agent outputs: research report + XLSX + JSON metrics
```

### Reference: Present Extension Current Structure

```
present extension
  |-> /grant command (task creation + --draft + --budget + --fix-it + --revise)
  |-> skill-grant (thin wrapper, routes to grant-agent)
  |-> grant-agent (funder research, proposal draft, budget develop, assemble)
  |-> context/project/present/ (domain, patterns, standards, templates, tools)
```

### Reference: Proposed /funds Integration

```
present extension (after task 389 + 391)
  |-> /grant command (existing)
  |-> /funds command (new - task 389)
  |     |-> STAGE 0: Funding analysis forcing questions
  |     |-> Mode: LANDSCAPE | PORTFOLIO | JUSTIFY | GAP
  |     |-> Delegate to skill-funds -> funds-agent
  |     |-> Outputs: research report + XLSX landscape + JSON metrics
  |-> /budget command (new - task 387)
  |-> /timeline command (new - task 388)
  |-> /talk command (new - task 390)
```
