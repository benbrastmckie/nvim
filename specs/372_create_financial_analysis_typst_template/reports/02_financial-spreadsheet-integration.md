# Research Report: Spreadsheet Integration for Financial Analysis Research

- **Task**: 372 - Create financial-analysis.typ template
- **Started**: 2026-04-07T14:00:00Z
- **Completed**: 2026-04-07T14:30:00Z
- **Effort**: Small
- **Dependencies**: None
- **Sources/Inputs**:
  - Codebase: `.claude/extensions/founder/commands/sheet.md` (sheet command)
  - Codebase: `.claude/extensions/founder/agents/spreadsheet-agent.md` (spreadsheet agent)
  - Codebase: `.claude/extensions/founder/skills/skill-spreadsheet/SKILL.md` (spreadsheet skill)
  - Codebase: `.claude/extensions/founder/skills/skill-finance/SKILL.md` (finance skill)
  - Codebase: `.claude/extensions/founder/context/project/founder/domain/spreadsheet-frameworks.md` (frameworks)
  - Codebase: `.claude/extensions/founder/context/project/founder/templates/financial-analysis.md` (markdown template)
  - Codebase: `.claude/extensions/founder/context/project/founder/templates/typst/cost-breakdown.typ` (typst template)
  - Codebase: `.claude/extensions/founder/manifest.json` (routing table)
- **Artifacts**:
  - `specs/372_create_financial_analysis_typst_template/reports/02_financial-spreadsheet-integration.md`
- **Standards**: report-format.md, artifact-management.md, tasks.md

## Executive Summary

- The `/sheet` command already has a complete spreadsheet pipeline: forcing questions -> XLSX with formulas (openpyxl) -> JSON metrics export -> Typst consumption via `json()` import
- The founder extension routing table already defines `founder:finance` -> `skill-finance` and `founder:sheet` -> `skill-spreadsheet`, but `/research` on financial analysis tasks does not currently produce spreadsheets
- The `cost-breakdown.typ` template demonstrates the proven pattern: Typst loads `cost-metrics.json` at compile time via `let data = json(data-file)`, making all numbers computable rather than hallucinated
- Three integration options exist: (A) extend `skill-finance` to invoke `spreadsheet-agent` as a sub-step, (B) create a `founder:financial-analysis` compound language that routes to a new skill combining finance + spreadsheet, or (C) add spreadsheet generation to the financial-analysis Typst template's research phase
- Option C (adding spreadsheet generation to the financial-analysis.typ research pipeline) is recommended -- it is the simplest path and directly solves the hallucination problem by ensuring all numerical data is user-provided via forcing questions before the template is populated

## Context & Scope

The user observed that when `/research` runs on financial analysis tasks, it produces prose reports with placeholder financial figures. These figures are then propagated through `/plan` and `/implement`, compounding inaccuracies. The `/sheet` command already solves this problem for cost breakdowns by:

1. Asking forcing questions to gather real numbers from the user
2. Generating an XLSX spreadsheet with native Excel formulas
3. Exporting a JSON metrics file that Typst templates consume at compile time

This research investigates how to extend this pattern to financial analysis tasks so that `/research` produces grounded numerical artifacts.

## Findings

### How the /sheet Pipeline Works

The pipeline has four key components:

1. **Pre-task forcing questions** (sheet.md Stage 0): Mode selection (ESTIMATE/BUDGET/FORECAST/ACTUALS), time period, entity scope -- gathered BEFORE task creation and stored as `forcing_data` in state.json
2. **Spreadsheet agent** (spreadsheet-agent.md): Asks 8 structured forcing questions one-at-a-time (personnel, infrastructure, marketing, operations, one-time vs recurring, contingency), pushes back on vague answers, generates XLSX via Python/openpyxl with blue input cells and black formula cells
3. **JSON metrics export**: Structured JSON with typed numbers (not strings) containing metadata, summary totals, category breakdowns, and line items -- consumable by Typst via `json()`
4. **Typst template consumption** (cost-breakdown.typ): Imports JSON at compile time with `let data = json(data-file)`, renders metric cards, tables, and charts using real data

### Current Routing Architecture

The founder extension manifest defines these research routes:

| Language Key | Skill |
|--------------|-------|
| `founder` | `skill-market` |
| `founder:sheet` | `skill-spreadsheet` |
| `founder:finance` | `skill-finance` |
| `founder:analyze` | `skill-analyze` |

Task 372 has language `meta` (not `founder`), so it routes to `skill-researcher` (generic). Even if it were `founder`, it would route to `skill-market` (default) or `skill-finance` (if `founder:finance`). Neither produces spreadsheets.

### The Financial Analysis Template's Numerical Sections

The markdown template at `financial-analysis.md` contains 12+ sections requiring specific numerical data:

- **Revenue Analysis**: ARR, MRR, growth rates, concentration
- **Expense Analysis**: Personnel, infrastructure, marketing, operations with monthly/annual/percentage
- **Cash Position**: Balance, burn rate, runway
- **Ratio Analysis**: Gross margin, operating margin, current ratio, quick ratio, burn multiple, Rule of 40, LTV:CAC
- **Verification Results**: Cross-reference checks with specific dollar amounts
- **Scenario Analysis**: Upside/base/downside with revenue, expenses, runway
- **Projection Assessment**: Assumptions with specific values

Every one of these sections contains `${amount}` placeholders that, without forcing questions, will be hallucinated by the agent.

### How cost-breakdown.typ Consumes JSON

```typst
#let cost-doc(
  title: "Cost Breakdown Analysis",
  data-file: "cost-metrics.json",
  doc,
) = {
  let data = json(data-file)
  // data.summary.total_monthly, data.categories[0].monthly, etc.
}
```

This pattern is directly applicable to a `financial-analysis.typ` template. The template would load a `financial-metrics.json` file containing all numerical data.

### Skill-Finance vs Skill-Spreadsheet Boundaries

- `skill-finance`: Routes to `finance-agent` for document analysis and verification -- assumes financial documents already exist and need review
- `skill-spreadsheet`: Routes to `spreadsheet-agent` for cost breakdown generation from scratch via forcing questions

Financial analysis for a startup creating projections needs the spreadsheet approach (gathering real numbers) rather than the finance approach (analyzing existing documents).

## Decisions

- The financial-analysis.typ template (task 372's primary deliverable) should follow the same pattern as cost-breakdown.typ: import a JSON metrics file at compile time
- A new JSON schema (`financial-metrics.json`) is needed, broader than `cost-metrics.json`, covering revenue, expenses, cash position, ratios, scenarios, and projections
- The research phase for financial analysis tasks should produce this JSON file alongside the XLSX spreadsheet

## Recommendations

### 1. Define financial-metrics.json Schema (Priority: High)

Create a JSON schema that covers all numerical sections of the financial-analysis.md template:

```json
{
  "metadata": {
    "project": "", "date": "", "mode": "", "currency": "USD"
  },
  "revenue": {
    "arr": 0, "mrr": 0, "growth_yoy_pct": 0,
    "top_customer_pct": 0, "recurring_pct": 0
  },
  "expenses": {
    "categories": [
      {"name": "Personnel", "monthly": 0, "annual": 0, "pct_of_total": 0}
    ],
    "total_monthly": 0, "total_annual": 0
  },
  "cash": {
    "balance": 0, "monthly_net_burn": 0, "gross_burn": 0,
    "runway_months": 0
  },
  "ratios": {
    "gross_margin_pct": 0, "operating_margin_pct": 0,
    "current_ratio": 0, "burn_multiple": 0,
    "ltv_cac_ratio": 0, "cac_payback_months": 0
  },
  "scenarios": {
    "upside": {"revenue": 0, "expenses": 0, "runway_months": 0},
    "base": {"revenue": 0, "expenses": 0, "runway_months": 0},
    "downside": {"revenue": 0, "expenses": 0, "runway_months": 0}
  }
}
```

### 2. Create a Financial Analysis Spreadsheet Agent or Extend Existing (Priority: High)

Two options:

**Option A**: Create `financial-analysis-agent.md` that extends the spreadsheet-agent pattern with financial-analysis-specific forcing questions (revenue, expenses, cash, ratios, scenarios). This is a superset of the cost-breakdown forcing questions.

**Option B**: Extend `spreadsheet-agent.md` with a `mode` parameter that switches between cost-breakdown questions and financial-analysis questions. This keeps one agent for all spreadsheet work.

**Recommendation**: Option A (separate agent) -- the forcing question sets are distinct enough that a combined agent would be complex.

### 3. Add `founder:financial-analysis` Routing Key (Priority: Medium)

Add a new compound language key to the founder manifest:

```json
"research": {
  "founder:financial-analysis": "skill-financial-analysis"
}
```

This routes `/research` on financial analysis tasks to a skill that invokes the financial analysis agent with forcing questions, producing XLSX + JSON + research report.

### 4. Design financial-analysis.typ to Consume JSON (Priority: High)

The Typst template (task 372's deliverable) should follow cost-breakdown.typ's pattern:

```typst
#let financial-doc(
  title: "Financial Analysis Report",
  data-file: "financial-metrics.json",
  doc,
) = {
  let data = json(data-file)
  // Use data.revenue.arr, data.expenses.total_monthly, etc.
}
```

All numerical display components should read from the JSON data, not from hardcoded values.

### 5. Planning Phase Integration (Priority: Medium)

When `/plan` runs on a financial analysis task:
- The plan should reference the JSON metrics file as a data source
- Phase steps should say "render revenue section using financial-metrics.json" rather than "write revenue analysis with ARR of $X"
- The implementation agent reads JSON values and passes them to Typst template components

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Forcing questions are too burdensome for users | Medium | High | Provide ESTIMATE mode with fewer required fields; allow "unknown" with explicit marking |
| JSON schema doesn't cover all template sections | Low | Medium | Design schema from template sections (bottom-up); validate coverage before implementation |
| Agent hallucinating numbers despite forcing questions | Low | High | Push-back patterns (from spreadsheet-agent) prevent vague answers; data quality assessment flags low-confidence entries |
| Scope creep beyond task 372 | High | Medium | Task 372 is the Typst template; spreadsheet integration is a separate task. This report informs both but they should remain separate tasks |

## Appendix

### Existing Spreadsheet Pipeline Files

| Component | Path |
|-----------|------|
| /sheet command | `.claude/extensions/founder/commands/sheet.md` |
| Spreadsheet skill | `.claude/extensions/founder/skills/skill-spreadsheet/SKILL.md` |
| Spreadsheet agent | `.claude/extensions/founder/agents/spreadsheet-agent.md` |
| Spreadsheet frameworks | `.claude/extensions/founder/context/project/founder/domain/spreadsheet-frameworks.md` |
| Cost forcing questions | `.claude/extensions/founder/context/project/founder/patterns/cost-forcing-questions.md` |
| Cost-breakdown Typst | `.claude/extensions/founder/context/project/founder/templates/typst/cost-breakdown.typ` |

### Existing Finance Pipeline Files

| Component | Path |
|-----------|------|
| Finance skill | `.claude/extensions/founder/skills/skill-finance/SKILL.md` |
| Financial analysis template | `.claude/extensions/founder/context/project/founder/templates/financial-analysis.md` |

### Typst JSON Import Pattern

```typst
// At document level
#let data = json("financial-metrics.json")

// In component functions
#let revenue-table(data) = {
  table(
    columns: (auto, auto, auto),
    [Metric], [Value], [Trend],
    [ARR], [\$$#{data.revenue.arr}], [#{data.revenue.growth_yoy_pct}%],
    [MRR], [\$$#{data.revenue.mrr}], [],
  )
}
```
