# Implementation Summary: Create Finance Context and Templates

**Task**: 331
**Date**: 2026-03-31
**Session**: sess_1774927748_4g7z
**Status**: Completed

---

## Files Created

### 1. domain/financial-analysis.md (241 lines)

**Path**: `.claude/extensions/founder/context/project/founder/domain/financial-analysis.md`

Covers:
- Financial statement analysis (income statement, balance sheet, cash flow)
- Statement interconnection verification table
- Ratio analysis framework (liquidity, profitability, leverage, startup-specific)
- Verification methodology (three-way match, source document hierarchy)
- Red flag detection checklist (10 flags across 5 categories)
- Spreadsheet validation patterns (formula audit, common errors, sensitivity testing)
- Document types and review points (cap table, financial model, investor reports)

### 2. patterns/financial-forcing-questions.md (361 lines)

**Path**: `.claude/extensions/founder/context/project/founder/patterns/financial-forcing-questions.md`

Six forcing questions:
- Q1: Document Inventory - what documents are available
- Q2: Revenue Reality - verify revenue claims
- Q3: Expense Completeness - walk through all cost categories
- Q4: Cash Position - actual cash and burn rate
- Q5: Projection Basis - assumptions behind forecasts
- Q6: Discrepancy Detection - what doesn't add up

Includes mode selection (REVIEW/DILIGENCE/AUDIT/FORECAST), push-back patterns, data quality assessment, and JSON output format.

### 3. templates/financial-analysis.md (331 lines)

**Path**: `.claude/extensions/founder/context/project/founder/templates/financial-analysis.md`

Report template with sections for:
- Document inventory and completeness assessment
- Revenue, expense, and cash analysis tables
- Ratio analysis with benchmarks
- Verification cross-reference tables
- Red flags with risk assessment matrix
- Projection assessment with scenario analysis
- Mode-specific guidance and delivery checklist

---

## Design Decisions

- **No overlap with spreadsheet-frameworks.md**: Financial-analysis focuses on analysis and verification; spreadsheet-frameworks covers cost modeling and generation
- **Mode system**: REVIEW/DILIGENCE/AUDIT/FORECAST follows the established mode-selection pattern
- **Six questions**: Mirrors the structure of forcing-questions.md and cost-forcing-questions.md
- **No Typst template**: Out of scope for this task; can be added as follow-up

---

## Next Steps

- Task 332 will integrate these files into index-entries.json and manifest.json
