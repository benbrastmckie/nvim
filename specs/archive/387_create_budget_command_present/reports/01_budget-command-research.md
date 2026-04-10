# Research Report: Create /budget Command for Present Extension

- **Task**: 387 - Create /budget command for present extension
- **Started**: 2026-04-09T19:42:00Z
- **Completed**: 2026-04-09T19:55:00Z
- **Effort**: 3-5 hours (estimated implementation)
- **Dependencies**: None (task 391 depends on this)
- **Sources/Inputs**:
  - Founder extension /sheet command (`commands/sheet.md`)
  - Founder skill-spreadsheet (`skills/skill-spreadsheet/SKILL.md`)
  - Founder spreadsheet-agent (`agents/spreadsheet-agent.md`)
  - Founder cost-forcing-questions pattern (`patterns/cost-forcing-questions.md`)
  - Founder spreadsheet-frameworks domain (`domain/spreadsheet-frameworks.md`)
  - Present extension /grant command (`commands/grant.md`)
  - Present skill-grant (`skills/skill-grant/SKILL.md`)
  - Present grant-agent (`agents/grant-agent.md`)
  - Present budget-patterns (`patterns/budget-patterns.md`)
  - Present budget-justification template (`templates/budget-justification.md`)
  - Present funder-types domain (`domain/funder-types.md`)
  - Present manifest.json and index-entries.json
  - Present EXTENSION.md
- **Artifacts**: `specs/387_create_budget_command_present/reports/01_budget-command-research.md`
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report.md

## Project Context

- **Upstream Dependencies**: Present extension infrastructure (manifest.json, index-entries.json, EXTENSION.md), existing /grant command and skill-grant/grant-agent pipeline, founder /sheet command pattern (adaptation source)
- **Downstream Dependents**: Task 391 (manifest integration), future grant workflows that use /budget for standalone budget development
- **Alternative Paths**: Budget development is already partially supported via `/grant N --budget`, which routes through skill-grant to grant-agent with workflow_type=budget_develop
- **Potential Extensions**: Integration with filetypes extension for XLSX editing via SuperDoc MCP

## Executive Summary

- The /budget command for the present extension should adapt the founder /sheet command pattern (forcing questions, XLSX generation, JSON metrics export) for grant budget spreadsheets specific to medical research
- Key differentiator from founder /sheet: grant-specific budget categories (personnel effort/salary/fringe, equipment, travel, participant support, other direct costs, F&A/indirect), funder-specific formats (NIH modular vs detailed, NSF standard), and compliance requirements (cost-sharing, sub-awards, salary caps)
- The present extension already has extensive budget domain knowledge in `patterns/budget-patterns.md` and `templates/budget-justification.md` that the new budget-agent should leverage
- Deliverables: 1 command file, 1 skill file, 1 agent file, and 2-4 context files (domain: grant-budget-frameworks, patterns: budget-forcing-questions, templates: budget-spreadsheet-templates)
- The command should be standalone (`/budget`) rather than a subcommand of `/grant`, following the same pattern as the other new commands (tasks 388-390)

## Context & Scope

### What Exists Today

The present extension currently handles budgets through two mechanisms:

1. **`/grant N --budget`**: Routes through skill-grant to grant-agent with `workflow_type=budget_develop`. This is a narrative-focused budget workflow that creates markdown budget documents in `specs/{NNN}_{SLUG}/budgets/`. It does not generate XLSX spreadsheets.

2. **Budget patterns context**: `patterns/budget-patterns.md` contains comprehensive budget format templates for NSF, NIH (modular and detailed), Foundation, and SBIR budgets. This is reference material for the grant-agent.

### What the Founder Extension Provides (Adaptation Source)

The founder extension's /sheet command provides the architectural pattern to adapt:

| Component | Founder Path | Purpose |
|-----------|-------------|---------|
| Command | `commands/sheet.md` | Pre-task forcing questions, mode selection, task creation |
| Skill | `skills/skill-spreadsheet/SKILL.md` | Thin wrapper with postflight |
| Agent | `agents/spreadsheet-agent.md` | Forcing questions, XLSX generation, JSON export |
| Domain | `domain/spreadsheet-frameworks.md` | Cost structure, formulas, conventions |
| Patterns | `patterns/cost-forcing-questions.md` | Question framework, push-back patterns |

### Scope of Adaptation

The /budget command must transform the generic startup cost breakdown model into a grant-budget-specific model:

| Founder Concept | Present Adaptation |
|-----------------|-------------------|
| Mode: ESTIMATE/BUDGET/FORECAST/ACTUALS | Mode: MODULAR/DETAILED/FOUNDATION/SBIR |
| Categories: Personnel/Infrastructure/Marketing/Operations | Categories: Personnel/Equipment/Travel/Participant Support/Other Direct/Indirect |
| Unit cost model: qty x unit_cost | Effort model: % effort x salary + fringe rate |
| Single period | Multi-year with inflation |
| One entity | PI + Co-PIs + sub-awards |
| Contingency buffer | F&A rate (negotiated indirect cost rate) |

## Findings

### 1. Command File (`commands/budget.md`)

The /budget command should follow the /sheet command's hybrid pattern with pre-task forcing questions:

**Syntax**:
- `/budget "NIH R01 budget for AI interpretability project"` -- Ask forcing questions, create task
- `/budget N` -- Resume research on existing task (delegates to skill-budget)
- `/budget --quick MODULAR` -- Legacy standalone mode

**Pre-task forcing questions (STAGE 0)**:
1. **Funder type selection**: NIH Modular, NIH Detailed, NSF, Foundation, SBIR (replaces ESTIMATE/BUDGET/FORECAST/ACTUALS modes)
2. **Project period**: Number of years, start date
3. **Direct cost cap**: Total annual direct costs (determines NIH modular vs detailed: under $250K = modular)

**Key differences from /sheet**:
- Language is set to `"budget"` (new language) or reuse `"grant"` -- Recommendation: use `"meta"` since this is a meta task creating .claude/ files; the budget-agent itself will handle grant-domain logic
- The command creates tasks the same way as /grant and /sheet

### 2. Skill File (`skills/skill-budget/SKILL.md`)

Follow the thin-wrapper postflight pattern exactly as skill-spreadsheet:
- Stage 1: Input validation (task exists, language matches)
- Stage 2: Preflight status update (researching)
- Stage 3: Postflight marker
- Stage 4: Delegation context with forcing_data
- Stage 5: Invoke budget-agent via Task tool
- Stage 6-11: Standard postflight (parse metadata, update status, link artifacts, git commit, cleanup, return summary)

### 3. Agent File (`agents/budget-agent.md`)

The budget-agent adapts the spreadsheet-agent pattern with grant-specific modifications:

**Forcing Questions (Grant-Adapted)**:

| Stage | Question | Grant-Specific Aspect |
|-------|----------|----------------------|
| Mode Selection | Funder format | NIH Modular, NIH Detailed, NSF, Foundation, SBIR |
| Scope | Project period + years | Multi-year budget (typically 3-5 years) |
| Personnel | Effort and salary | % effort, institutional base salary, fringe rate, salary cap (NIH) |
| Equipment | Items > $5,000 | Threshold varies by institution; excluded from MTDC |
| Travel | Domestic + international | Conference travel, site visits, collaborator meetings |
| Participant Support | Stipends, travel, subsistence | Often excluded from indirect costs |
| Other Direct | Supplies, publication, sub-awards | Sub-award first $25K subject to indirect |
| Indirect | F&A rate | Negotiated rate, MTDC base calculation |

**XLSX Generation**:
- Multi-year layout (Year 1, Year 2, ... Year N columns)
- Personnel effort section with salary cap enforcement (NIH $221,900 for FY2026)
- Automatic fringe benefit calculation
- F&A/indirect cost calculation with MTDC base
- Modular budget rounding ($25K modules for NIH)
- Sub-award splitting (first $25K vs remainder for indirect purposes)

**Output Artifacts**:
- `grant-budget.xlsx` -- XLSX with native Excel formulas
- `budget-metrics.json` -- JSON metrics for Typst integration
- Research report in `reports/01_budget-research.md`

### 4. Context Files

**New context files needed**:

| File | Location | Purpose | Estimated Lines |
|------|----------|---------|-----------------|
| `domain/grant-budget-frameworks.md` | `present/context/project/present/domain/` | Grant-specific cost structures, F&A calculation, salary caps, multi-year conventions | ~200 |
| `patterns/budget-forcing-questions.md` | `present/context/project/present/patterns/` | Grant-adapted forcing question framework | ~250 |

**Existing context files to leverage** (no changes needed):
- `patterns/budget-patterns.md` -- Already has NSF/NIH/Foundation/SBIR format templates
- `templates/budget-justification.md` -- Already has personnel/equipment/travel justification templates
- `domain/funder-types.md` -- Already has funder characteristics

### 5. Relationship with Existing `/grant --budget`

The `/grant N --budget` workflow produces a narrative budget document (markdown). The new `/budget` command produces a spreadsheet (XLSX). These are complementary:

| Aspect | `/grant --budget` | `/budget` |
|--------|-------------------|-----------|
| Output format | Markdown narrative | XLSX spreadsheet |
| Purpose | Budget justification text | Numerical budget with formulas |
| Interaction | Prompt-guided drafting | Forcing questions (one at a time) |
| Artifacts | `budgets/MM_line-item-budget.md` | `grant-budget.xlsx` + `budget-metrics.json` |
| Status change | researching -> planned | researching -> researched |

**Workflow integration**: Users can use both in sequence -- `/budget N` for the numbers, then `/grant N --budget` for the narrative justification referencing those numbers.

### 6. Architecture Decision: Language and Routing

**Option A**: New language `"budget"` with dedicated routing
- Pro: Clean separation, explicit routing
- Con: Another language to manage, more manifest complexity

**Option B**: Use existing `"grant"` language with workflow_type routing
- Pro: Consistent with existing /grant --budget pattern
- Con: Overloads the grant language, routing ambiguity

**Recommendation**: Use **Option A** -- new language `"budget"`. This follows the pattern of tasks 388-390 where each gets a dedicated command, skill, and agent. The `/budget` command is standalone, not a subcommand of `/grant`. Task 391 will integrate all four new commands into the manifest.

### 7. File Structure Summary

```
.claude/extensions/present/
  commands/
    budget.md                          # NEW: /budget command
  skills/
    skill-budget/
      SKILL.md                         # NEW: thin wrapper skill
  agents/
    budget-agent.md                    # NEW: budget agent
  context/project/present/
    domain/
      grant-budget-frameworks.md       # NEW: grant budget domain knowledge
    patterns/
      budget-forcing-questions.md      # NEW: grant-adapted forcing questions
```

### 8. Mode-Specific XLSX Layout

**NIH Modular** (< $250K/year direct costs):
- Single summary sheet with direct cost modules ($25K increments)
- Personnel justification section
- Consortium costs if applicable

**NIH Detailed** (>= $250K/year direct costs):
- Per-year worksheets (Year 1 through Year N)
- Standard NIH categories: Personnel, Equipment, Travel, Participant Support, Other Direct
- Cumulative budget sheet
- F&A calculation sheet

**NSF Standard**:
- NSF budget categories (A through J)
- MTDC calculation
- Cost-sharing sheet (if required)

**Foundation/SBIR**:
- Simplified format following funder requirements
- Overhead rate application

## Decisions

- The /budget command will be standalone (not a /grant subcommand), creating tasks with a dedicated `"budget"` language
- The budget-agent adapts the spreadsheet-agent pattern with grant-specific forcing questions
- Multi-year budgets with inflation escalation (typically 3% annually) are the default for federal grants
- XLSX generation uses openpyxl (same as founder /sheet), with multi-year column layout
- F&A rates are input values (blue cells) since they are institution-specific
- NIH salary cap is enforced programmatically in formulas
- Two new context files are needed; existing budget-patterns and budget-justification templates are reused

## Recommendations

1. **Implement budget-agent first** -- It contains the core logic (forcing questions, XLSX generation). The command and skill are thin wrappers
2. **Reuse existing context** -- `budget-patterns.md` and `budget-justification.md` already cover format templates; new context files should focus on computational aspects (F&A calculation, salary cap rules, MTDC exclusions)
3. **Support sub-awards** -- Sub-awards are common in medical research grants and have specific indirect cost rules (first $25K subject to indirect)
4. **Include cost-sharing** -- Some grants require institutional cost-sharing; include as optional section
5. **Generate budget justification skeleton** -- After XLSX generation, output a markdown budget justification skeleton that references the spreadsheet numbers

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| openpyxl not available | Cannot generate XLSX | Check availability early, provide pip install guidance |
| Multi-year XLSX complexity | Complex formula generation | Start with Year 1 template, extend to multi-year |
| Funder-specific format variations | Incomplete coverage | Start with NIH and NSF (most common), add others iteratively |
| Salary cap changes annually | Outdated cap values | Make salary cap an input parameter, document current value |
| F&A rate complexity (on/off campus) | Incorrect calculations | Accept rate as input, do not hardcode institutional rates |

## Appendix

### NIH Salary Cap Reference

The NIH salary cap for FY2026 is $221,900 (Executive Level II). This means:
- If PI salary is $250,000 at 25% effort, the grant can only charge 25% x $221,900 = $55,475
- The institution must cover the difference ($250,000 - $221,900) x 25% = $7,025

### MTDC Exclusions (Standard)

Modified Total Direct Costs (MTDC) typically excludes:
- Equipment (> $5,000)
- Participant support costs
- Sub-award amounts exceeding $25,000
- Patient care costs
- Tuition remission
- Rental costs of off-site facilities

### Key Formulas for XLSX

```
Personnel Cost = Base Salary x min(1, Salary_Cap / Base_Salary) x Effort%
Fringe Benefits = Personnel Cost x Fringe_Rate%
Total Direct Costs = Personnel + Equipment + Travel + Participant + Other
MTDC = TDC - Equipment - Participant - SubAward_Over_25K
Indirect Costs = MTDC x F&A_Rate%
Total Project Cost = TDC + Indirect
```
