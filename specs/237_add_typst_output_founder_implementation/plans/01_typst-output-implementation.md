# Implementation Plan: Task #237

- **Task**: 237 - add_typst_output_founder_implementation
- **Status**: [NOT STARTED]
- **Effort**: 4-6 hours
- **Dependencies**: None
- **Research Inputs**: [01_typst-output-research.md](../reports/01_typst-output-research.md)
- **Artifacts**: plans/01_typst-output-implementation.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Enhance the founder extension to generate professional typst documents as PDF outputs. This involves creating typst templates for each report type (market-sizing, competitive-analysis, gtm-strategy), updating the founder-implement-agent with a Phase 5 for typst generation, and updating the founder-plan-agent to include typst output in generated plans. The founder extension remains self-contained, not dependent on the typst extension.

### Research Integration

Key findings from research report:
- Templates should be in `.claude/extensions/founder/context/project/founder/templates/typst/`
- Use direct generation (Option A): Generate typst directly from context, not by parsing markdown
- Output location: `founder/` directory at repository root (separate from `strategy/` markdown)
- Phase structure: Add Phase 5 to existing 4-phase structure
- Template inheritance: Use shared `strategy-template.typ` for common styles

## Goals & Non-Goals

**Goals**:
- Create professional typst templates for all three founder report types
- Add Phase 5 (Typst Document Generation) to founder-implement-agent
- Update founder-plan-agent to include Phase 5 in generated plans
- Generate PDF output to `founder/` directory
- Maintain founder extension independence (no typst extension dependency)

**Non-Goals**:
- Converting existing markdown reports to typst (new generations only)
- Creating complex visualizations requiring external typst packages
- Real-time preview or editing capabilities
- Integration with external typst cloud services

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Typst not installed on system | High | Medium | Check availability at Phase 5 start, skip with warning if unavailable |
| Complex table formatting | Medium | Medium | Use simple Typst table syntax, avoid nested structures |
| Template maintenance burden | Low | Medium | Use shared strategy-template.typ for common styles |
| Typst compilation errors | Medium | Low | Validate templates during development, provide helpful error messages |

## Implementation Phases

### Phase 1: Create Base Typst Template [NOT STARTED]

**Goal**: Create the shared strategy-template.typ with common styles and functions

**Tasks**:
- [ ] Create `.claude/extensions/founder/context/project/founder/templates/typst/` directory
- [ ] Create `strategy-template.typ` with:
  - Document setup (page size, margins, fonts)
  - Heading styles (h1, h2, h3)
  - Table styling functions
  - Title page layout function
  - Executive summary block style
  - Callout/highlight box for key metrics

**Timing**: 1 hour

**Files to create**:
- `.claude/extensions/founder/context/project/founder/templates/typst/strategy-template.typ`

**Verification**:
- Template file exists and is valid typst syntax
- Can compile a minimal test document importing the template

---

### Phase 2: Create Report-Type Templates [NOT STARTED]

**Goal**: Create specific templates for each founder report type

**Tasks**:
- [ ] Create `market-sizing.typ`:
  - Import strategy-template.typ
  - TAM/SAM/SOM section layouts
  - Concentric circle diagram (simple Typst shapes)
  - Methodology comparison table
  - Assumptions highlight box
  - Investor one-pager section
- [ ] Create `competitive-analysis.typ`:
  - Import strategy-template.typ
  - Competitor landscape table
  - 2x2 positioning map (simple grid)
  - Competitor profile cards
  - Feature comparison matrix
  - Battle card layout
- [ ] Create `gtm-strategy.typ`:
  - Import strategy-template.typ
  - ICP profile section
  - Channel prioritization table
  - 90-day timeline layout
  - Metrics dashboard section
  - Positioning statement callout

**Timing**: 1.5 hours

**Files to create**:
- `.claude/extensions/founder/context/project/founder/templates/typst/market-sizing.typ`
- `.claude/extensions/founder/context/project/founder/templates/typst/competitive-analysis.typ`
- `.claude/extensions/founder/context/project/founder/templates/typst/gtm-strategy.typ`

**Verification**:
- Each template compiles successfully with test data
- Templates produce professional-looking output
- Imports from strategy-template.typ work correctly

---

### Phase 3: Update founder-implement-agent [NOT STARTED]

**Goal**: Add Phase 5 for typst document generation to the implementation agent

**Tasks**:
- [ ] Add Phase 5 section to agent specification:
  - Determine report type from plan context
  - Load appropriate typst template path
  - Generate typst content directly from gathered context
  - Write .typ file to `founder/{report-type}-{slug}.typ`
  - Compile to PDF using `typst compile`
  - Verify PDF exists and is non-empty
- [ ] Add template selection logic (case statement for report types)
- [ ] Add error handling for typst compilation failures:
  - Check if typst is installed
  - Capture compilation errors
  - Mark Phase 5 as [PARTIAL] on failure
  - Keep .typ file for debugging
- [ ] Update metadata generation to include typst artifacts
- [ ] Update context references to include typst templates

**Timing**: 1.5 hours

**Files to modify**:
- `.claude/extensions/founder/agents/founder-implement-agent.md`

**Verification**:
- Agent spec includes complete Phase 5 documentation
- Template selection logic covers all three report types
- Error handling covers typst unavailable and compilation failure scenarios

---

### Phase 4: Update founder-plan-agent [NOT STARTED]

**Goal**: Include Phase 5 in plans generated by the planning agent

**Tasks**:
- [ ] Add Phase 5 to plan template structure:
  - Phase 5: Typst Document Generation [NOT STARTED]
  - Objectives: Generate typst document, compile to PDF
  - Template reference: appropriate typst template path
  - Output specification: `founder/{report-type}-{slug}.pdf`
- [ ] Update phase count in plan metadata (4 -> 5)
- [ ] Add typst output to Report Output section of plan template
- [ ] Update estimated hours to account for Phase 5

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-plan-agent.md`

**Verification**:
- Generated plans include Phase 5
- Phase 5 references correct template path
- Output paths use `founder/` directory

---

### Phase 5: Update Extension Metadata and Testing [NOT STARTED]

**Goal**: Update manifest and index entries, verify end-to-end functionality

**Tasks**:
- [ ] Update `manifest.json` to include typst templates in provides
- [ ] Update `index-entries.json` with entries for new typst template files
- [ ] Create minimal test case:
  - Sample market-sizing data
  - Verify typst compilation
  - Check PDF output
- [ ] Verify founder extension loads correctly with new files

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/founder/manifest.json`
- `.claude/extensions/founder/index-entries.json`

**Verification**:
- Extension loads without errors
- Context discovery finds typst templates
- Sample compilation produces valid PDF

---

## Testing & Validation

- [ ] Each typst template compiles standalone with test content
- [ ] strategy-template.typ functions work when imported
- [ ] founder-implement-agent Phase 5 executes correctly
- [ ] founder-plan-agent generates plans with Phase 5
- [ ] End-to-end: `/market`, `/plan`, `/implement` produces PDF in `founder/`
- [ ] Error handling: Graceful failure when typst unavailable
- [ ] Error handling: Graceful failure on compilation errors

## Artifacts & Outputs

- `.claude/extensions/founder/context/project/founder/templates/typst/strategy-template.typ` - Base template
- `.claude/extensions/founder/context/project/founder/templates/typst/market-sizing.typ` - Market sizing template
- `.claude/extensions/founder/context/project/founder/templates/typst/competitive-analysis.typ` - Competitive analysis template
- `.claude/extensions/founder/context/project/founder/templates/typst/gtm-strategy.typ` - GTM strategy template
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Updated with Phase 5
- `.claude/extensions/founder/agents/founder-plan-agent.md` - Updated plan structure
- `.claude/extensions/founder/manifest.json` - Updated provides section
- `.claude/extensions/founder/index-entries.json` - New template entries
- `specs/237_add_typst_output_founder_implementation/summaries/01_typst-output-summary.md` - Implementation summary

## Rollback/Contingency

If implementation fails:
1. Revert agent modifications (founder-implement-agent.md, founder-plan-agent.md)
2. Remove typst template directory
3. Revert manifest.json and index-entries.json changes
4. Founder extension continues to work with markdown-only output

If typst unavailable at runtime:
- Phase 5 skips with warning message
- Markdown report still generated (Phases 1-4)
- User advised to install typst and re-run `/implement`
