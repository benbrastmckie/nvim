# Implementation Plan: Create Finance Context and Templates

**Task**: 331
**Date**: 2026-03-31
**Session**: sess_1774927692_g6o252
**Research**: specs/331_create_finance_context_templates/reports/01_finance-context-research.md

---

## Overview

Create three context files for the founder extension's finance feature, following established patterns from existing domain, pattern, and template files.

**Estimated effort**: 1 phase, ~45 minutes

---

## Phase 1: Create Finance Context Files

**Description**: Create all three finance context files in a single phase since they are independent markdown files with no build/test dependencies.

### Step 1: Create `domain/financial-analysis.md`

**Path**: `.claude/extensions/founder/context/project/founder/domain/financial-analysis.md`

**Content structure** (following `legal-frameworks.md` and `business-frameworks.md` patterns):

1. **Title and description**: "Domain knowledge for financial document analysis, verification methodology, and spreadsheet validation."
2. **Financial Statement Analysis** (~60 lines)
   - Income statement key components and patterns
   - Balance sheet health indicators
   - Cash flow statement analysis framework
   - Statement interconnection verification table
3. **Ratio Analysis Framework** (~50 lines)
   - Liquidity ratios (current, quick, cash)
   - Profitability ratios (gross margin, net margin, ROE)
   - Leverage ratios (debt-to-equity, interest coverage)
   - Efficiency ratios (asset turnover, receivables)
   - Startup-specific metrics (burn rate, runway, magic number)
   - Ratio interpretation table with healthy ranges
4. **Verification Methodology** (~50 lines)
   - Cross-referencing protocol (three-way match)
   - Source document hierarchy table
   - Red flag detection checklist
   - Reconciliation patterns
5. **Spreadsheet Validation Patterns** (~40 lines)
   - Formula audit checklist
   - Circular reference detection
   - Assumption sensitivity testing
   - Common spreadsheet errors table
6. **Document Types** (~40 lines)
   - Cap table analysis points
   - Financial model review checklist
   - Investor report verification
   - Tax return cross-references
7. **References** section

**Target line count**: ~280 lines

### Step 2: Create `patterns/financial-forcing-questions.md`

**Path**: `.claude/extensions/founder/context/project/founder/patterns/financial-forcing-questions.md`

**Content structure** (following `forcing-questions.md` and `cost-forcing-questions.md` patterns):

1. **Title and core principle**: "Every number tells a story" - financial claims require source documents
2. **Mode Selection** (~20 lines)
   - REVIEW: General financial health check
   - DILIGENCE: Due diligence depth analysis
   - AUDIT: Detailed verification and validation
   - FORECAST: Forward-looking financial assessment
3. **Six Forcing Questions** (~180 lines)
   - Q1: Document Inventory - "What financial documents do you have available?"
   - Q2: Revenue Reality - "Show me the revenue. Is it real, recurring, growing?"
   - Q3: Expense Completeness - "Walk me through every cost category."
   - Q4: Cash Position - "What is the actual cash balance and burn rate?"
   - Q5: Projection Basis - "What assumptions drive your financial forecast?"
   - Q6: Discrepancy Detection - "What doesn't add up? What surprised you?"
   - Each with: Push Until, Anti-Patterns, Acceptable Answers, Framework
4. **Smart Routing by Mode** table (~15 lines)
5. **Push-Back Patterns** table (~15 lines)
6. **Data Quality Assessment** (~10 lines)
7. **Output Format** (JSON) (~20 lines)
8. **Implementation Notes** (~15 lines)

**Target line count**: ~270 lines

### Step 3: Create `templates/financial-analysis.md`

**Path**: `.claude/extensions/founder/context/project/founder/templates/financial-analysis.md`

**Content structure** (following `contract-analysis.md` and `market-sizing.md` patterns):

1. **Title and description**: "Template for financial document analysis and verification artifacts."
2. **Output file format**: `founder/financial-analysis-{datetime}.md`
3. **Template** (in code fence) (~200 lines):
   - Metadata header: Project, Date, Mode, Document Type, Prepared by
   - Executive Summary with overall health rating
   - Document Inventory table
   - Financial Overview (revenue, expenses, cash, key metrics)
   - Ratio Analysis table with benchmarks
   - Verification Results table (item, source, cross-ref, status)
   - Red Flags and Concerns
   - Projection Assessment (assumptions, scenarios)
   - What I Noticed (mentor-style observations)
   - Recommendations and Next Steps
   - Appendix: Source Documents
   - Appendix: Detailed Calculations
4. **Section Guidance** (~60 lines):
   - Executive summary guidance
   - Ratio analysis interpretation
   - Verification methodology tips
   - Red flags checklist
5. **Mode-specific focus** (~20 lines)
6. **Checklist before delivery** (~15 lines)

**Target line count**: ~300 lines

### Verification

- Confirm each file follows the exact heading hierarchy and formatting patterns of its category
- Ensure tables use consistent markdown formatting
- Verify no emojis used (per project policy)
- Check that content complements rather than duplicates `spreadsheet-frameworks.md` and `business-frameworks.md`

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Content overlap with spreadsheet-frameworks.md | Medium | Low | Focus financial-analysis.md on analysis/verification, not cost modeling |
| Inconsistent formatting with existing files | Low | Medium | Follow exact patterns from research report |
| Missing integration in index-entries.json | N/A | N/A | Out of scope - task 332 handles integration |

---

## Success Criteria

1. Three files created at specified paths
2. Each file follows the established pattern of its category (domain, pattern, template)
3. Content covers document analysis, verification methodology, and spreadsheet validation
4. No duplication with existing `spreadsheet-frameworks.md` or `business-frameworks.md`
5. Files are self-contained and ready for index registration (task 332)
