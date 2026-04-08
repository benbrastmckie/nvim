# Research Report: Task #372

**Task**: 372 - Create financial-analysis.typ template
**Started**: 2026-04-07T12:00:00Z
**Completed**: 2026-04-07T12:15:00Z
**Effort**: Small-Medium
**Dependencies**: None (strategy-template.typ already exists)
**Sources/Inputs**:
- Codebase: `templates/financial-analysis.md` (markdown template)
- Codebase: `templates/typst/strategy-template.typ` (base components)
- Codebase: `templates/typst/market-sizing.typ` (reference adaptation)
- Codebase: `templates/typst/cost-breakdown.typ` (reference adaptation with financial components)
- Codebase: `templates/typst/contract-analysis.typ` (reference adaptation with risk/assessment patterns)
**Artifacts**:
- `specs/372_create_financial_analysis_typst_template/reports/01_financial-analysis-template.md`
**Standards**: report-format.md, artifact-management.md, tasks.md

## Executive Summary

- The markdown template at `financial-analysis.md` defines a comprehensive financial analysis report with 12 major sections covering revenue, expenses, cash position, ratios, verification, red flags, projections, and recommendations
- `strategy-template.typ` provides all necessary base components: `metric-callout`, `metric-row`, `highlight-box`, `warning-box`, `success-box`, `callout`, `strategy-table`, `executive-summary`, `comparison-block`, `section-divider`, and `appendix`
- Existing typst templates follow a consistent pattern: import strategy-template, define a document wrapper function, then define section-specific component functions that compose base components
- The `cost-breakdown.typ` template already provides directly reusable patterns: `runway-block`, `scenario-table`, `assumption-box`, and `category-table` -- these can be referenced or adapted for the financial analysis template
- The financial-analysis.typ template should define approximately 10-12 custom components beyond the base, organized around financial health assessment, verification results, ratio analysis, and scenario modeling

## Context & Scope

This research identifies the structure, components, and patterns needed to create `financial-analysis.typ` -- a Typst template that renders professional financial analysis reports. The template must:

1. Mirror the sections and content structure of the existing markdown template (`financial-analysis.md`)
2. Import and build upon `strategy-template.typ` base components
3. Follow the same architectural pattern as sibling templates (market-sizing, cost-breakdown, contract-analysis)
4. Add financial-domain-specific visual components

## Findings

### Markdown Template Section Mapping

The markdown template has 12 logical sections that need typst equivalents:

| # | Markdown Section | Typst Approach | Key Components Needed |
|---|-----------------|----------------|----------------------|
| 1 | Executive Summary | `executive-summary` from base + custom health badge | `health-badge`, metric pills |
| 2 | Document Inventory | `strategy-table` from base | `completeness-table` (custom) |
| 3 | Revenue Analysis | `strategy-table` + `metric-row` | `revenue-metrics-row` |
| 4 | Expense Analysis | `strategy-table` + category bar (from cost-breakdown pattern) | `expense-table` |
| 5 | Cash Position | `metric-row` + `runway-block` pattern from cost-breakdown | `cash-position-block` |
| 6 | Ratio Analysis | `strategy-table` with benchmark coloring | `ratio-table`, `startup-metrics-table` |
| 7 | Verification Results | `strategy-table` with pass/fail coloring | `verification-table`, `discrepancy-table` |
| 8 | Red Flags & Concerns | `warning-box` from base + risk matrix pattern from contract-analysis | `severity-badge`, `risk-matrix` |
| 9 | Projection Assessment | `strategy-table` + `callout` | `assumption-table` |
| 10 | Scenario Analysis | `scenario-table` pattern from cost-breakdown | Reuse/adapt |
| 11 | Recommendations | `highlight-box` from base + `strategy-table` | `monitoring-table` |
| 12 | Appendices | `appendix` from base | Direct reuse |

### Available Base Components (from strategy-template.typ)

Components that can be used directly without modification:

- **`strategy-doc`**: Document wrapper (page setup, typography, title page) -- used by all templates
- **`metric`**: Inline navy pill with label:value -- for title page key metrics
- **`metric-callout`**: Large centered metric display -- for key financial figures
- **`metric-row`**: Side-by-side metrics -- for summary cards
- **`executive-summary`**: Bordered summary block -- for executive summary
- **`highlight-box`**: Left-bordered insight box -- for key findings, "What I Noticed"
- **`warning-box`**: Left-bordered warning box -- for red flags, critical issues
- **`success-box`**: Left-bordered green box -- for validation passes, healthy signals
- **`callout`**: Generic left-bordered box -- for assumptions, notes
- **`strategy-table`**: Styled table with header -- for all data tables
- **`comparison-block`**: Dark navy side-by-side -- for before/after or source comparisons
- **`section-divider`**: Horizontal line separator
- **`appendix`**: Page-breaking appendix section

### Patterns from Existing Templates

**Document wrapper pattern** (all templates follow this):
```typst
#import "strategy-template.typ": *

#let financial-analysis-doc(
  title: "Financial Analysis Report",
  project: "",
  date: "",
  mode: "REVIEW",
  // ... domain-specific parameters
  doc,
) = {
  show: strategy-doc.with(
    title: title,
    project: project,
    date: date,
    mode: mode,
  )
  // Title page extras (metric pills, callouts)
  // ...
  pagebreak()
  doc
}
```

**Custom component pattern** (from cost-breakdown.typ and contract-analysis.typ):
- Each template defines 8-15 domain-specific components
- Components accept structured data (arrays of dictionaries) as parameters
- Components compose base components (tables, boxes, badges)
- Conditional coloring based on data values (e.g., risk levels, thresholds)

**Conditional fill coloring** (from contract-analysis.typ clause-analysis-table):
- Row colors change based on severity/risk level in the data
- Pattern: `fill: (x, y) => { if y == 0 { fill-header } else { ... check data ... } }`

**Badge pattern** (from contract-analysis.typ risk-badge):
- Small colored pills for categorical status values
- Used for: risk levels, health status, verification status

### Custom Components to Create

Based on the markdown template sections and patterns from existing templates:

1. **`health-badge(level)`** -- Colored badge for financial health status (Healthy/Adequate/Concerning/Critical), following `risk-badge` pattern from contract-analysis.typ

2. **`verification-badge(status)`** -- Colored badge for verification status (Verified/Supported/Unverified/Match/Discrepancy), same pattern

3. **`financial-analysis-doc(...)`** -- Document wrapper with financial-specific parameters (project, date, mode, document-type) and title page metric pills

4. **`document-inventory-table(documents)`** -- Table for document listing with quality badges

5. **`completeness-table(items)`** -- Table for document completeness assessment with Available/Missing/Partial coloring

6. **`revenue-table(metrics)`** -- Table for revenue metrics with trend indicators and verification source

7. **`expense-table(categories)`** -- Table for expense breakdown (monthly, annual, % of total, trend)

8. **`cash-position-block(cash, burn, runway, ...)`** -- Adapts `runway-block` from cost-breakdown.typ for broader cash position display

9. **`ratio-table(ratios)`** -- Table with benchmark comparison and conditional coloring (healthy/watch/concerning)

10. **`verification-matrix(items)`** -- Cross-reference verification table with match/discrepancy coloring

11. **`discrepancy-table(items)`** -- Table for discrepancies with magnitude and status

12. **`scenario-comparison(scenarios)`** -- Table for upside/base/downside scenarios with key driver column, adapting `scenario-table` from cost-breakdown.typ

13. **`assumption-table(assumptions)`** -- Table with confidence and sensitivity ratings, adapting from market-sizing.typ

14. **`monitoring-table(metrics)`** -- Table for monitoring plan with frequency and threshold triggers

15. **`interconnection-check(connections)`** -- Table for statement interconnection checks with Pass/Fail badges

### Mode Support

The markdown template defines four modes that affect depth and focus:
- **REVIEW**: Health snapshot, traffic-light ratings
- **DILIGENCE**: Comprehensive, line-item verification
- **AUDIT**: Verification-focused, reconciliation workpapers
- **FORECAST**: Projection credibility, assumption analysis

The typst template should accept `mode` as a parameter (passed to `strategy-doc`) but does not need to conditionally render sections -- that is the responsibility of the agent populating the template. The mode value appears on the title page.

### File Structure

Following the established pattern, the file should be organized as:
1. Header comment block (purpose, imports, usage)
2. Import statement
3. Optional additional color definitions (if needed beyond base palette)
4. Document wrapper function
5. Badge/indicator components (small, reusable)
6. Section-specific table/block components (ordered by report flow)
7. Example usage comment block
8. Optional JSON data schema reference comment block

## Decisions

1. **Import strategy-template.typ only** -- Do not import cost-breakdown.typ or contract-analysis.typ. Instead, recreate needed patterns (runway-block, scenario-table, risk-badge) within financial-analysis.typ to maintain independence between templates.

2. **Use parameterized document wrapper** -- Follow market-sizing.typ pattern with a `financial-analysis-doc` wrapper that accepts all major section data as parameters, enabling both parameter-driven and content-driven usage.

3. **Support both usage modes** -- The wrapper accepts data parameters for programmatic use, but content can also be written inline using the exported components (as in cost-breakdown.typ example usage). Include an example usage comment block.

4. **No JSON data loading** -- Unlike cost-breakdown.typ which loads JSON at compile time, keep this template pure-parameter. Financial analysis data varies too much for a fixed schema.

5. **Approximately 15 custom components** -- Beyond the base, define components specifically for financial health assessment, verification, ratio analysis, and scenario modeling.

## Risks & Mitigations

- **Risk**: Template becomes too large (>500 lines) and hard to maintain
  - **Mitigation**: Keep components focused and composable. Use base components wherever possible rather than rebuilding.

- **Risk**: Conditional coloring logic becomes complex for ratio benchmarks
  - **Mitigation**: Define simple threshold-based helper functions (e.g., `health-color(assessment)`) that map string values to colors.

- **Risk**: Typst compilation errors from complex table fill functions
  - **Mitigation**: Follow the exact patterns proven in contract-analysis.typ and cost-breakdown.typ for conditional fills.

## Appendix

### Search Queries Used
- `Glob: .claude/extensions/founder/context/project/founder/templates/typst/*.typ`
- Read: financial-analysis.md, strategy-template.typ, market-sizing.typ, cost-breakdown.typ, contract-analysis.typ

### Component Reuse Summary

| Base Component | Times Used in New Template | Sections |
|---------------|---------------------------|----------|
| strategy-doc | 1 (wrapper) | Document setup |
| metric | 3-5 (title page) | Title page pills |
| metric-callout | 2-3 | Key financial figures |
| metric-row | 2 | Summary cards, cash position |
| executive-summary | 1 | Executive summary |
| strategy-table | 5-7 | Most data tables |
| highlight-box | 2-3 | Key findings, "What I Noticed" |
| warning-box | 1-2 | Red flags, critical issues |
| success-box | 1 | Healthy signals |
| callout | 2-3 | Assumptions, notes |
| comparison-block | 1 | Source comparison |
| appendix | 2 | Detailed calculations, sources |
