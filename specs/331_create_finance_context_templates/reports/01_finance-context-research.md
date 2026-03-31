# Research Report: Create Finance Context and Templates

**Task**: 331
**Date**: 2026-03-31
**Session**: sess_1774927603_u6bf

---

## Objective

Create three new context files for the founder extension's finance feature:
1. `domain/financial-analysis.md` - Document analysis frameworks, verification methodology, spreadsheet validation
2. `patterns/financial-forcing-questions.md` - Question framework for financial document review
3. `templates/financial-analysis.md` - Report template for finance research output

---

## Research Findings

### Existing Pattern Analysis

Examined all existing founder extension context files to understand conventions:

**Domain files** (e.g., `business-frameworks.md`, `legal-frameworks.md`, `spreadsheet-frameworks.md`):
- Start with title and one-line description
- Use `##` sections for major topics, `###` for subtopics
- Heavy use of tables for structured data (Framework | Description | Best For)
- Include calculation examples in code blocks
- Include ASCII/Unicode visualizations where appropriate
- End with `## References` section with links
- Line counts: 240-290 lines typical

**Pattern files** (e.g., `forcing-questions.md`, `cost-forcing-questions.md`):
- Start with core principle in bold quote
- Structured around numbered questions (Q1, Q2, etc.)
- Each question has: Question, Push Until, Anti-Patterns to Reject, Acceptable Answers
- Include push-back trigger tables
- Include smart routing by stage/mode
- Include output format (JSON) for structured data capture
- Include implementation notes about one-question-at-a-time
- Line counts: 220-315 lines typical

**Template files** (e.g., `market-sizing.md`, `contract-analysis.md`, `competitive-analysis.md`):
- Start with title and one-line description
- Specify output file location format
- Template wrapped in triple-backtick markdown code fence
- Template includes: metadata header, executive summary, structured sections, appendices
- After template: section guidance with tables
- End with checklist before delivery
- Line counts: 250-350 lines typical

### Finance Domain Content Scope

The financial-analysis domain file should cover:
1. **Financial Statement Analysis** - Income statement, balance sheet, cash flow patterns
2. **Ratio Analysis** - Liquidity, profitability, leverage, efficiency ratios
3. **Verification Methodology** - Cross-referencing, source document validation, red flag detection
4. **Spreadsheet Validation** - Formula audit patterns, circular reference detection, assumption testing
5. **Startup Financial Health** - Burn rate, runway, unit economics verification
6. **Document Types** - Cap tables, financial models, investor reports, tax returns

The financial forcing questions should cover:
1. **Document Identification** - What documents are available?
2. **Revenue Reality** - Is revenue real, recurring, growing?
3. **Expense Scrutiny** - Are costs properly categorized and complete?
4. **Cash Position** - What is the actual cash situation?
5. **Projections Basis** - What assumptions drive the forecast?
6. **Red Flags** - Any unusual patterns or discrepancies?

The template should support modes:
- **REVIEW** - General financial health check
- **DILIGENCE** - Due diligence depth analysis
- **AUDIT** - Detailed verification and validation
- **FORECAST** - Forward-looking financial assessment

### Integration Points

- New files will be loaded by a future `finance-agent` (task 330 dependency)
- Should be registered in `index-entries.json` (task 332 handles integration)
- Template follows same output location pattern: `founder/financial-analysis-{datetime}.md`
- Domain file complements existing `spreadsheet-frameworks.md` (cost modeling) with analysis/verification focus

---

## Key Decisions

1. **Domain file scope**: Focus on analysis and verification, not cost modeling (that's `spreadsheet-frameworks.md`)
2. **Forcing questions**: Six questions mirroring the pattern from `forcing-questions.md` and `cost-forcing-questions.md`
3. **Template modes**: REVIEW, DILIGENCE, AUDIT, FORECAST - matching the mode-selection pattern
4. **No Typst template**: Task scope is markdown context files only; Typst can be a follow-up

---

## Files to Create

| File | Type | Est. Lines | Content |
|------|------|-----------|---------|
| `domain/financial-analysis.md` | Domain | ~280 | Analysis frameworks, ratios, verification, validation |
| `patterns/financial-forcing-questions.md` | Pattern | ~270 | Six forcing questions for financial document review |
| `templates/financial-analysis.md` | Template | ~300 | Report template with modes and sections |

---

## Next Steps

- Create implementation plan with 3 files as single phase (all are independent context files)
- Follow exact patterns from existing files for consistency
