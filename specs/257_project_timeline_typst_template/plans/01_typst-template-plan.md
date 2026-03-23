# Implementation Plan: Task #257

- **Task**: 257 - project_timeline_typst_template
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: None - self-contained template
- **Research Inputs**: specs/257_project_timeline_typst_template/reports/01_typst-template-research.md
- **Artifacts**: plans/01_typst-template-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create a self-contained Typst template for project timeline visualization, extending the existing founder extension strategy-template.typ. The template will integrate the gantty package for Gantt charts with dependency tracking, Fletcher for WBS hierarchy diagrams, and custom components for PERT three-point estimation and resource allocation. The navy color palette from strategy-template.typ will be reused for visual consistency.

### Research Integration

Key findings from the research report inform this plan:
- **Gantty package** (v0.5.1) selected over timeliney for real date support and built-in dependency tracking
- **Fletcher** (v0.5.8) identified for WBS tree diagrams and custom dependency arrows
- **Existing risk-matrix** pattern from contract-analysis.typ can be adapted for project risk visualization
- **Color palette** and page setup patterns established in strategy-template.typ provide the foundation

## Goals & Non-Goals

**Goals**:
- Create `project-timeline.typ` template with all required visualizations
- Reuse navy color palette and page setup from strategy-template.typ
- Implement Gantt chart with milestone markers, dependency arrows, and critical path highlighting
- Create custom PERT three-point estimation component with formula display
- Build resource allocation table with capacity tracking
- Implement WBS hierarchy using Fletcher tree diagrams
- Adapt existing risk-matrix for project risk visualization

**Non-Goals**:
- Creating a general-purpose project management system
- Interactive/dynamic timeline updates
- Export to other formats (PDF generation handled by Typst)
- Integration with external project management tools

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Gantty may not support custom critical path styling | Medium | Medium | Add post-processing overlay or use custom task fill colors |
| Fletcher + Gantty import conflicts | Low | Low | Test import compatibility early in Phase 2 |
| PERT formula rounding precision | Low | Low | Use calc.round() for display, full precision internally |
| WBS with many levels may overflow page | Medium | Low | Add horizontal scrolling or page-break support, document level limits |
| Color palette inheritance complexity | Low | Medium | Direct import of colors rather than template wrapper |

## Implementation Phases

### Phase 1: Template Foundation [COMPLETED]

**Goal**: Establish base template with color palette, page setup, and package imports

**Tasks**:
- [ ] Create `project-timeline.typ` file in founder templates directory
- [ ] Import strategy-template.typ for color palette and typography
- [ ] Add package imports: gantty (0.5.1), fletcher (0.5.8)
- [ ] Define additional timeline-specific colors (critical-path, milestone-marker, progress-complete)
- [ ] Create document wrapper function `project-timeline-doc()`
- [ ] Verify all imports work together without conflicts

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/templates/typst/project-timeline.typ` - New file

**Verification**:
- Template compiles without errors
- All packages import successfully
- Color palette available and renders correctly

---

### Phase 2: Gantt Chart Component [COMPLETED]

**Goal**: Create styled Gantt chart wrapper with navy theme and critical path support

**Tasks**:
- [ ] Create `project-gantt()` wrapper function around gantty
- [ ] Configure navy-themed task bars and milestone markers
- [ ] Implement critical path highlighting with `critical-path` color
- [ ] Add milestone marker styling using navy-dark
- [ ] Create helper function for common task configurations
- [ ] Test with sample multi-task project timeline

**Timing**: 1 hour

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/templates/typst/project-timeline.typ` - Add Gantt component

**Verification**:
- Gantt chart renders with correct navy styling
- Dependencies shown between tasks
- Critical path tasks visually distinguished
- Milestones display with correct markers

---

### Phase 3: PERT Estimation Component [COMPLETED]

**Goal**: Build custom three-point estimation visualization with PERT formula

**Tasks**:
- [ ] Create `pert-estimate()` function with optimistic, likely, pessimistic parameters
- [ ] Implement PERT formula calculation: E = (O + 4M + P) / 6
- [ ] Add standard deviation calculation: SD = (P - O) / 6
- [ ] Design visual layout with three input values in labeled boxes
- [ ] Display expected value prominently
- [ ] Optional: Add confidence interval display (E +/- 2*SD for 95%)
- [ ] Create `pert-table()` for multiple estimates in tabular format

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/templates/typst/project-timeline.typ` - Add PERT component

**Verification**:
- PERT formula calculates correctly for test inputs
- Visual display shows all three estimates clearly
- Expected value and standard deviation render properly
- Table variant works for multiple task estimates

---

### Phase 4: Resource Allocation Table [COMPLETED]

**Goal**: Create resource allocation matrix showing team assignments and capacity

**Tasks**:
- [ ] Create `resource-matrix()` function with team members and time periods
- [ ] Use existing table styling patterns (alternating rows, navy headers)
- [ ] Add colored cells for task assignments
- [ ] Implement capacity percentage row calculation
- [ ] Add overallocation warning styling (fill-warning color)
- [ ] Support configurable time periods (days, weeks, months)

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/templates/typst/project-timeline.typ` - Add resource matrix

**Verification**:
- Resource matrix displays team members and assignments
- Capacity percentages calculate correctly
- Overallocation highlighted visually
- Table styling consistent with strategy-template.typ

---

### Phase 5: WBS Hierarchy Visualization [COMPLETED]

**Goal**: Implement Work Breakdown Structure tree diagram using Fletcher

**Tasks**:
- [ ] Create `wbs-tree()` function accepting hierarchical task data
- [ ] Configure Fletcher diagram with navy color scheme
- [ ] Style nodes by level (project, phase, task, subtask)
- [ ] Add connecting edges with appropriate arrows
- [ ] Support variable tree depth (2-4 levels typical)
- [ ] Add optional task status indicators in nodes

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/templates/typst/project-timeline.typ` - Add WBS component

**Verification**:
- WBS tree renders with correct hierarchical structure
- Node colors match navy palette by level
- Edges connect parent to child nodes properly
- Tree handles variable depth without visual issues

---

### Phase 6: Risk Matrix Adaptation [COMPLETED]

**Goal**: Adapt contract-analysis.typ risk matrix for project risk management

**Tasks**:
- [ ] Create `project-risk-matrix()` based on existing risk-matrix pattern
- [ ] Update terminology: Impact vs Likelihood (project context)
- [ ] Configure color-coded quadrants (red/orange/yellow/green)
- [ ] Support custom risk categories beyond high/low
- [ ] Add risk count badges for each quadrant
- [ ] Create `risk-register()` companion table for detailed risk listing

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/templates/typst/project-timeline.typ` - Add risk matrix

**Verification**:
- Risk matrix displays 2x2 grid correctly
- Quadrant colors match severity levels
- Risk items appear in correct quadrants
- Risk register table renders with proper styling

---

### Phase 7: Integration and Documentation [COMPLETED]

**Goal**: Integrate all components and add usage documentation

**Tasks**:
- [ ] Create example document using all components together
- [ ] Add inline documentation comments for each function
- [ ] Test complete template compilation
- [ ] Verify component interactions (especially Gantt + WBS together)
- [ ] Add parameter documentation for all public functions
- [ ] Create brief usage guide at top of template file

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/templates/typst/project-timeline.typ` - Complete integration

**Verification**:
- Full template compiles without warnings
- Example document renders all components correctly
- Documentation comments explain usage
- All public functions have clear parameter descriptions

## Testing & Validation

- [ ] Template compiles in Typst CLI (`typst compile project-timeline.typ`)
- [ ] All package imports resolve (gantty, fletcher, strategy-template)
- [ ] Gantt chart renders multi-phase project with dependencies
- [ ] PERT formula produces correct expected value for test inputs
- [ ] Resource matrix calculates capacity percentages accurately
- [ ] WBS tree displays 3-level hierarchy correctly
- [ ] Risk matrix colors match severity levels
- [ ] Combined document with all components renders without errors

## Artifacts & Outputs

- `.claude/extensions/founder/context/project/founder/templates/typst/project-timeline.typ` - Main template file with all components
- Implementation summary at `specs/257_project_timeline_typst_template/summaries/01_typst-template-summary.md`

## Rollback/Contingency

If implementation fails or template has critical issues:
1. Delete `project-timeline.typ` file
2. No changes to existing templates (strategy-template.typ unchanged)
3. Packages (gantty, fletcher) are external - no rollback needed
4. Task can be re-attempted with revised approach based on learnings
