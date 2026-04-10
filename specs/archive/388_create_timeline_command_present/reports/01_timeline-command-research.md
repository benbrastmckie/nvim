# Research Report: Create /timeline Command for Present Extension

- **Task**: 388 - Create /timeline command for present extension
- **Started**: 2026-04-09T19:42:00Z
- **Completed**: 2026-04-09T19:55:00Z
- **Effort**: ~1 hour
- **Dependencies**: None (sibling tasks 387, 389, 390 are independent)
- **Sources/Inputs**:
  - `.claude/extensions/founder/commands/project.md` - Source /project command
  - `.claude/extensions/founder/skills/skill-project/SKILL.md` - Source skill pattern
  - `.claude/extensions/founder/agents/project-agent.md` - Source agent with WBS/PERT/CPM
  - `.claude/extensions/founder/context/project/founder/domain/timeline-frameworks.md` - WBS, PERT, CPM methodology
  - `.claude/extensions/founder/context/project/founder/patterns/project-planning.md` - Planning reference
  - `.claude/extensions/founder/context/project/founder/templates/typst/project-timeline.typ` - Typst template
  - `.claude/extensions/present/commands/grant.md` - Present extension command pattern
  - `.claude/extensions/present/skills/skill-grant/SKILL.md` - Present extension skill pattern
  - `.claude/extensions/present/agents/grant-agent.md` - Present extension agent pattern
  - `.claude/extensions/present/manifest.json` - Extension manifest structure
  - `.claude/extensions/present/EXTENSION.md` - Extension documentation pattern
- **Artifacts**: This report
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report.md

## Project Context

- **Upstream Dependencies**: Founder /project command (WBS/PERT/Gantt engine), present extension infrastructure (manifest, grant-agent patterns), Typst project-timeline.typ template
- **Downstream Dependents**: Task 391 (manifest integration), future research project management workflows
- **Alternative Paths**: Could use standalone scheduling tool; the extension command approach integrates with existing task system
- **Potential Extensions**: Integration with grant timelines for synchronized project/funding views

## Executive Summary

- The /timeline command adapts the founder /project command's WBS/PERT/Gantt capabilities for medical research project management within the present extension
- The founder /project command provides a complete reference implementation: command (project.md), skill (skill-project), agent (project-agent.md), Typst template (project-timeline.typ), and supporting context
- Medical research timelines require domain-specific adaptations: specific aims scheduling, regulatory milestone tracking (IRB, IACUC, DSMB), reporting periods, no-cost extensions, and multi-PI coordination
- The present extension already has an established pattern for commands (grant.md), skills (skill-grant), and agents (grant-agent.md) that the timeline command should follow
- All 7 deliverables are identified: command, skill, agent, and 4 context files (domain, patterns, templates, Typst template)

## Context & Scope

### What is Being Created

A `/timeline` command for the present extension that enables researchers to plan and track medical research project timelines. This adapts the founder extension's `/project` command -- which handles general business project timelines via WBS, PERT estimation, and Gantt charts -- for the specific needs of medical research.

### Constraints

- Must follow the present extension's established patterns (command/skill/agent structure)
- Must be compatible with the existing task system (/research, /plan, /implement lifecycle)
- Must reuse existing Typst template infrastructure from founder extension (project-timeline.typ)
- Language routing: will use "present" language, not "founder"
- The present extension manifest.json must be updated (handled by task 391)

## Findings

### 1. Founder /project Command Architecture

The founder /project command is a full-featured project timeline system with this structure:

**Command** (`commands/project.md`):
- Supports 4 modes: PLAN, TRACK, REPORT, REVIEW
- Pre-task forcing questions (Stage 0) gather data before task creation
- Task workflow mode resumes research on existing tasks
- Legacy `--quick` mode for standalone operation

**Skill** (`skills/skill-project/SKILL.md`):
- Thin wrapper following skill-internal postflight pattern
- Routes to project-agent via Task tool
- Passes pre-gathered forcing_data from task metadata
- Standard 11-stage execution flow (validate, preflight, marker, delegation, invoke, parse, postflight, link, commit, cleanup, return)

**Agent** (`agents/project-agent.md`):
- Interactive forcing-question-driven research agent
- 10 stages: early metadata, parse context, project definition (Q1-Q3), phase elicitation (Q4-Q6), task decomposition (Q7-Q8), PERT estimation, resource allocation, schedule calculation, report generation, metadata write
- Produces structured research report with WBS, PERT tables, resource allocation, critical path, risk register, and raw JSON data blocks
- Also supports REVIEW mode (R1-R5 stages) for analyzing existing timelines

**Context files**:
- `domain/timeline-frameworks.md` - WBS, PERT, CPM, resource allocation, risk matrix methodology
- `patterns/project-planning.md` - Terminology, validation rules, calculation formulas
- `templates/typst/project-timeline.typ` - Typst template with Gantt charts, PERT visualization, resource matrices, WBS trees, risk registers

### 2. Present Extension Patterns

The present extension uses consistent patterns across its components:

**Command pattern** (from grant.md):
- Hybrid command: task creation mode + workflow-specific modes (--draft, --budget, --revise, --fix-it)
- Mode detection via argument parsing
- GATE IN / DELEGATE / GATE OUT lifecycle
- Language set to extension-specific value ("grant" for /grant)

**Skill pattern** (from skill-grant):
- Thin wrapper with postflight
- Routes by workflow_type to subagent
- Standard status transitions per workflow type
- Context loaded by subagent, not skill

**Agent pattern** (from grant-agent):
- Multi-workflow support with branching execution
- Early metadata initialization (Stage 0)
- Dynamic context discovery via index.json
- WebSearch/WebFetch for research workflows
- File-based metadata return

### 3. Medical Research Timeline Domain Adaptations

The /timeline command must adapt WBS/PERT/Gantt for medical research. Key domain differences:

**Specific Aims as Phase Structure**:
- NIH grants organize around 2-4 Specific Aims, each with sub-aims
- Aims map naturally to WBS phases; sub-aims to tasks
- Cross-aim dependencies are common (e.g., Aim 2 depends on Aim 1 mouse model)

**Regulatory Milestones** (not present in business project management):
- IRB (Institutional Review Board) - human subjects protocol approval
- IACUC (Institutional Animal Care and Use Committee) - animal protocol approval
- DSMB (Data Safety Monitoring Board) - oversight for clinical trials
- IND/IDE submissions (FDA regulatory for drugs/devices)
- ClinicalTrials.gov registration
- These are zero-duration milestones with external dependencies and lead times

**Reporting Periods**:
- NIH: Annual RPPR (Research Performance Progress Report)
- NSF: Annual and Final Project Reports
- NIH closeout: Final FFR, Final Invention Statement, Final RPPR
- Progress reports drive renewal/continuation decisions

**No-Cost Extensions (NCEs)**:
- Standard 1-year NCE (automatic for NIH, PI-initiated)
- Second NCE requires agency approval with justification
- Budget carryover implications
- Timeline extension affects all downstream milestones

**Multi-PI Coordination**:
- Multiple PI (MPI) grants have co-investigators at different institutions
- Resource allocation across sites
- Subcontract timelines with different fiscal years

**Budget Period Alignment**:
- NIH modular budgets: 5-year periods, annual modules
- Budget periods constrain resource availability
- Personnel effort (calendar months, person-months) rather than percentage allocation

### 4. Forcing Questions Adaptation

The founder /project agent asks 8+ forcing questions. The /timeline agent needs research-specific questions:

| Founder Question | /timeline Adaptation |
|-----------------|----------------------|
| Project name + completion criteria | Grant mechanism + project period (e.g., "R01, 5-year, Aug 2026-Jul 2031") |
| Target completion date | Award end date + NCE possibility |
| Key stakeholders | PI, co-Is, Program Officer, IRB/IACUC contacts |
| Major phases | Specific Aims (with sub-aim structure) |
| Phase dependencies | Cross-aim dependencies + regulatory prerequisites |
| Deliverables per phase | Publications, datasets, models, reports per aim |
| Tasks within phases | Experiments, analyses, recruitment milestones per aim |
| Task dependencies within phases | Experimental sequence, analysis prerequisites |
| Three-point estimates | Per-experiment or per-milestone duration ranges |
| Team members | Key personnel with effort (calendar months) |
| Availability | Effort allocation by budget year |
| Task assignments | Personnel assignments by aim |

Additional research-specific questions:
- Regulatory requirements (which protocols needed, current status)
- Reporting schedule (annual RPPRs, supplement reports)
- Milestone definitions (for milestone-driven awards)
- Recruitment targets (for clinical/human subjects research)
- Data sharing timeline (DMSP compliance)

### 5. Deliverables Inventory

Based on the founder /project pattern and present extension conventions:

| Deliverable | Path | Adapts From |
|-------------|------|-------------|
| Command | `.claude/extensions/present/commands/timeline.md` | `founder/commands/project.md` |
| Skill | `.claude/extensions/present/skills/skill-timeline/SKILL.md` | `founder/skills/skill-project/SKILL.md` |
| Agent | `.claude/extensions/present/agents/timeline-agent.md` | `founder/agents/project-agent.md` |
| Domain context | `.claude/extensions/present/context/project/present/domain/research-timelines.md` | `founder/context/project/founder/domain/timeline-frameworks.md` |
| Patterns context | `.claude/extensions/present/context/project/present/patterns/timeline-patterns.md` | `founder/context/project/founder/patterns/project-planning.md` |
| Template (Typst) | `.claude/extensions/present/context/project/present/templates/typst/research-timeline.typ` | `founder/context/project/founder/templates/typst/project-timeline.typ` |
| Template (markdown) | `.claude/extensions/present/context/project/present/templates/timeline-template.md` | New (research report structure) |

### 6. Mode Design

The /timeline command should support modes analogous to /project:

| Mode | Syntax | Purpose | Adaptation |
|------|--------|---------|------------|
| Task creation | `/timeline "description"` | Create task with language="present" | Same as /grant pattern |
| PLAN | `/timeline N --plan` | Research + build timeline | Adapts /project PLAN with research aims |
| TRACK | `/timeline N --track` | Update progress | Track aim completion, regulatory status |
| REPORT | `/timeline N --report` | Generate status summary | RPPRs, progress reports |
| REVIEW | `/timeline N --review` | Analyze timeline | Check feasibility against award period |

Alternative: simpler design matching /grant pattern with fewer modes:
- `/timeline "description"` - task creation
- `/timeline N` - research/build timeline (equivalent to PLAN)
- Defer TRACK/REPORT/REVIEW to future iterations

**Recommendation**: Start with the simpler /grant-like pattern (task creation + single research mode). The full PLAN/TRACK/REPORT/REVIEW can be added later. This keeps the initial implementation manageable and follows the present extension's existing conventions.

### 7. Language and Routing

Two options for language routing:

**Option A**: Use "present" language (shared with /grant)
- Pro: Simpler manifest, fewer routing entries
- Con: Requires workflow_type routing within skill
- Pattern: Same as /grant which uses "grant" language

**Option B**: Use "timeline" language (dedicated)
- Pro: Clean routing, independent skill invocation
- Con: More manifest entries, language proliferation

**Recommendation**: Use "timeline" language for clean separation, following the pattern where /grant uses "grant" language. The skill-timeline handles all timeline workflows. Core commands route by language:
- `/research N` routes to skill-timeline (timeline research)
- `/plan N` routes to skill-planner (standard planner, reads research)
- `/implement N` routes to skill-timeline (generate Typst output)

### 8. Typst Template Adaptation

The founder's `project-timeline.typ` provides reusable components:
- `project-gantt()` - Gantt chart via gantty package
- `pert-table()` / `pert-estimate()` - PERT estimation visualization
- `resource-matrix()` - Team allocation matrix
- `wbs-tree()` / `wbs-boxes()` - WBS hierarchy
- `project-risk-matrix()` / `risk-register()` - Risk assessment
- `project-summary()` - Dashboard card

The research-timeline.typ should:
- Import and reuse these base components (or copy and adapt)
- Add research-specific components:
  - `regulatory-timeline()` - IRB/IACUC/DSMB milestone track
  - `aims-gantt()` - Specific aims view with cross-aim dependencies
  - `reporting-schedule()` - RPPR and report due dates
  - `effort-allocation()` - Personnel effort in calendar months by budget year
  - `recruitment-tracker()` - Enrollment milestones (for clinical studies)

## Decisions

- Follow the /grant command pattern (hybrid task creation + workflow modes) rather than the full /project 4-mode pattern for initial implementation
- Use "timeline" as the language identifier for routing
- Create research-timeline.typ that adapts rather than imports from the founder template (to avoid cross-extension dependencies)
- Forcing questions will be adapted for research context (specific aims, regulatory milestones, reporting periods)
- Start with PLAN equivalent only; defer TRACK/REPORT/REVIEW modes to future tasks

## Recommendations

1. **Phase 1 - Domain context**: Create `research-timelines.md` domain file documenting medical research timeline concepts (regulatory milestones, reporting periods, NCEs, specific aims structure, effort allocation)

2. **Phase 2 - Command + Skill**: Create `timeline.md` command following /grant pattern and `skill-timeline/SKILL.md` following skill-grant pattern. Simpler than /project: task creation mode + single research delegation mode

3. **Phase 3 - Agent**: Create `timeline-agent.md` adapting project-agent.md. Replace business forcing questions with research-specific ones. Keep WBS/PERT/CPM calculation logic. Add regulatory milestone and reporting schedule sections to report

4. **Phase 4 - Templates and patterns**: Create `timeline-patterns.md` (research timeline validation rules), `timeline-template.md` (report structure), and `research-timeline.typ` (Typst template adapting project-timeline.typ components for research)

5. **Note**: Manifest integration is handled by task 391 -- this task should NOT modify manifest.json, index-entries.json, or EXTENSION.md

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Cross-extension dependency on founder Typst template | Medium | Medium | Copy and adapt rather than import; self-contained template |
| Overly complex forcing questions for researchers | Medium | Medium | Start with minimal questions; make regulatory/reporting optional |
| Language routing conflicts with existing "present" language | Low | High | Use dedicated "timeline" language for clean separation |
| Scope creep into TRACK/REPORT/REVIEW modes | Medium | Low | Explicitly defer to future tasks; keep initial scope to PLAN equivalent |

## Appendix

### File Structure (After Implementation)

```
.claude/extensions/present/
  commands/
    timeline.md                    # /timeline command
  skills/
    skill-timeline/
      SKILL.md                     # Thin wrapper skill
  agents/
    timeline-agent.md              # Research agent with forcing questions
  context/project/present/
    domain/
      research-timelines.md        # Domain knowledge
    patterns/
      timeline-patterns.md         # Validation rules, calculation patterns
    templates/
      timeline-template.md         # Report structure template
      typst/
        research-timeline.typ      # Typst template for timeline output
```

### Key Differences: /project vs /timeline

| Aspect | /project (founder) | /timeline (present) |
|--------|-------------------|---------------------|
| Phase model | Generic phases | Specific Aims |
| Milestones | Business milestones | Regulatory (IRB, IACUC, DSMB) |
| Time units | Days/weeks | Months/years (grant periods) |
| Resources | Team members + % allocation | Key personnel + calendar months effort |
| Reporting | Generic status reports | RPPR, NSF annual reports |
| Extensions | N/A | No-cost extensions (NCEs) |
| Dependencies | Internal task deps | Regulatory approvals, cross-site coordination |
| Output | strategy/timelines/*.typ | TBD (grants/? or strategy/timelines/?) |
| Language | founder | timeline |

### Research Timeline Milestone Categories

| Category | Examples | Duration | External? |
|----------|----------|----------|-----------|
| Regulatory | IRB approval, IACUC approval, IND submission | 1-6 months | Yes |
| Scientific | Aim 1 completion, preliminary data, model validation | Variable | No |
| Reporting | RPPR, supplement report, final report | Fixed schedule | Yes |
| Publication | Manuscript submission, revision, acceptance | 3-12 months | Partially |
| Personnel | Postdoc hire, student graduation, sabbatical | Variable | Partially |
| Funding | Supplement request, NCE request, renewal application | Fixed deadlines | Yes |
