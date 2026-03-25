---
next_project_number: 277
---

# TODO

## Task Order

*Updated 2026-03-24. Task 272 completed (Task Order format specification). Created 5 tasks for /review Task Order management feature.*

**Goal**: Add Task Order section management to /review command.

### 1. Task Order Feature (dependency chain)

```
272 → 273 → 274 ─┐
           └ 275 ┴→ 276
```

1. **272** [COMPLETED] — Define Task Order schema and format specification
2. **273** [NOT STARTED] — Add Task Order parsing to /review command (depends: 272)
3. **274** [NOT STARTED] — Add Task Order pruning for completed/abandoned tasks (depends: 273)
4. **275** [NOT STARTED] — Add Task Order insertion for newly created tasks (depends: 273)
5. **276** [NOT STARTED] — Add interactive category placement and dependency management (depends: 274, 275)

### 2. Other Tasks

- **87** [RESEARCHED] — Investigate terminal directory change in wezterm
- **78** [PLANNED] — Fix Himalaya SMTP authentication failure

## Tasks

### 276. Add interactive Task Order management to /review
- **Effort**: 2 hours
- **Status**: [NOT STARTED]
- **Language**: meta
- **Dependencies**: Tasks #274, #275

**Description**: Add AskUserQuestion prompts to /review for interactive Task Order management. When creating new tasks, prompt user for category placement (Critical Path, Code Cleanup, Experimental, Deferred, Backlog). When updating existing tasks, prompt for dependency chain updates. Include option to skip Task Order updates for quick reviews.

---

### 275. Add Task Order insertion for newly created review tasks
- **Effort**: 1.5 hours
- **Status**: [NOT STARTED]
- **Language**: meta
- **Dependencies**: Task #273

**Description**: Extend /review to add newly created tasks to the Task Order section. After task creation (Section 5.6), insert new task numbers into appropriate Task Order categories based on severity and grouping. Update dependency chains if new tasks relate to existing ones. Maintain Task Order timestamp and goal statement.

---

### 274. Add Task Order pruning to /review
- **Effort**: 1 hour
- **Status**: [NOT STARTED]
- **Language**: meta
- **Dependencies**: Task #273

**Description**: Extend /review to remove completed, abandoned, and superseded tasks from the Task Order section. During review postflight, scan Task Order for task numbers whose status is [COMPLETED], [ABANDONED], or [EXPANDED], and remove them from category lists and dependency chains. Recompute dependency arrows after removal.

---

### 273. Add Task Order parsing to /review command
- **Effort**: 1.5 hours
- **Status**: [NOT STARTED]
- **Language**: meta
- **Dependencies**: Task #272

**Description**: Add Task Order section parsing to /review command. Read TODO.md and extract: update timestamp, goal statement, category sections (Critical Path, Code Cleanup, Experimental, Deferred, Backlog), dependency chains (arrow syntax), and per-task status markers. Store parsed data in `task_order_state` structure for manipulation by subsequent phases.

---

### 272. Define Task Order schema and format specification
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Plan**: [01_task-order-schema.md](272_task_order_schema_format/plans/01_task-order-schema.md)
- **Summary**: [01_task-order-schema-summary.md](272_task_order_schema_format/summaries/01_task-order-schema-summary.md)

**Description**: Create a context file defining the Task Order markdown format for TODO.md. Specify: section header format (`## Task Order`), update timestamp line, goal statement, category subsections (numbered headers), dependency chain syntax (arrow `→` notation), status markers, and task number references. Include parsing patterns and generation templates. Model after ProofChecker's TODO.md Task Order section.

---

### 271. Add ModelChecker domain context files to Python extension
- **Effort**: 30 minutes
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Plan**: [01_model-checker-context.md](271_add_model_checker_context_to_python_extension/plans/01_model-checker-context.md)
- **Summary**: [01_model-checker-context-summary.md](271_add_model_checker_context_to_python_extension/summaries/01_model-checker-context-summary.md)

**Description**: Replace the generic placeholder files in the Python extension with the project-specific ModelChecker context files, and update the extension's index entries accordingly.

**Source files** (restored in ModelChecker repo):
- `~/Projects/Logos/ModelChecker/.claude/context/project/python/domain/model-checker-api.md` — Package structure, key classes (SemanticDefaults, PropositionDefaults, ModelDefaults), import patterns, Z3 utilities, protocols
- `~/Projects/Logos/ModelChecker/.claude/context/project/python/domain/theory-lib-patterns.md` — Theory library directory structure, semantic/operator/example patterns, subtheory integration, settings dictionary

**Target location** (Python extension):
- `~/.config/nvim/.claude/extensions/python/context/project/python/domain/`

**Steps**:
1. Copy `model-checker-api.md` and `theory-lib-patterns.md` into the extension's domain directory, replacing `application-api-patterns.md` and `library-patterns.md`
2. Remove the old generic files (`application-api-patterns.md`, `library-patterns.md`)
3. Update `~/.config/nvim/.claude/extensions/python/index-entries.json` — replace the two domain entries:
   - `application-api-patterns.md` -> `model-checker-api.md` with description "ModelChecker package structure, key classes, import patterns, and Z3 utilities" and tags `["python", "model-checker", "api", "semantics"]`
   - `library-patterns.md` -> `theory-lib-patterns.md` with description "Theory library directory structure, semantic/operator/example patterns, subtheory integration" and tags `["python", "theory-lib", "patterns", "semantics"]`
4. Update the extension's `context/project/python/README.md` key files and loading sections to reference the new filenames

**Note**: After updating the extension source, any repo that loads the python extension via `<leader>ac` will get the ModelChecker-specific context files merged into its `.claude/context/index.json` automatically.

---


### 262. Refactor project-agent to generate research report instead of timeline
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_meta-research.md](262_refactor_project_agent_research_report/reports/01_meta-research.md)
- **Plan**: [01_refactor-project-agent.md](262_refactor_project_agent_research_report/plans/01_refactor-project-agent.md)
- **Summary**: [01_refactor-project-agent-summary.md](262_refactor_project_agent_research_report/summaries/01_refactor-project-agent-summary.md)

**Description**: Refactored project-agent from 913-line monolithic 3-mode agent to 540-line research-only agent. Removed TRACK/REPORT modes, Typst generation, PDF compilation. Added research report output with Raw Data JSON blocks for planner-agent consumption.

---

### 263. Update skill-project for research-only workflow
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Task #262
- **Research**: [01_meta-research.md](263_skill_project_research_workflow/reports/01_meta-research.md)
- **Plan**: [01_skill-project-workflow.md](263_skill_project_research_workflow/plans/01_skill-project-workflow.md)
- **Summary**: [01_skill-project-workflow-summary.md](263_skill_project_research_workflow/summaries/01_skill-project-workflow-summary.md)

**Description**: Modify skill-project to route to project-agent for research only, creating a research report at specs/{NNN}_{SLUG}/reports/ and stopping at [RESEARCHED] status. Remove timeline generation and PLANNED/TRACKED/REPORTED status handling.

---

### 264. Add legal support to founder-plan-agent
- **Effort**: 1.5 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_meta-research.md](264_project_planning_context/reports/01_meta-research.md)
- **Plan**: [01_legal-plan-support.md](264_project_planning_context/plans/01_legal-plan-support.md)
- **Summary**: [01_legal-plan-support-summary.md](264_project_planning_context/summaries/01_legal-plan-support-summary.md)

**Description**: Add contract-review keyword detection and phase structure to founder-plan-agent. Currently the agent only handles market-sizing, competitive-analysis, and gtm-strategy report types. Legal tasks that complete research via legal-council-agent fail at /plan because no keyword detection or phase structure exists for contract review.

---

### 265. Add legal support to founder-implement-agent
- **Effort**: 2.5 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Task #264
- **Research**: [01_meta-research.md](265_founder_implement_project_timeline/reports/01_meta-research.md)
- **Plan**: [01_legal-implement-support.md](265_founder_implement_project_timeline/plans/01_legal-implement-support.md)
- **Summary**: [01_legal-implement-support-summary.md](265_founder_implement_project_timeline/summaries/01_legal-implement-support-summary.md)

**Description**: Add contract-review type support to founder-implement-agent. The agent currently handles market-sizing, competitive-analysis, and gtm-strategy phase flows but has no legal support. Add contract-review type detection and a 5-phase flow: Clause-by-Clause Analysis, Risk Assessment Matrix, Negotiation Strategy, Report Generation, and Typst/PDF generation.

---

### 266. Add project support to founder-plan-agent
- **Effort**: 1.5 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Task #262
- **Research**: [01_meta-research.md](266_project_command_documentation/reports/01_meta-research.md)
- **Plan**: [01_project-plan-support.md](266_project_command_documentation/plans/01_project-plan-support.md)
- **Summary**: [01_project-plan-support-summary.md](266_project_command_documentation/summaries/01_project-plan-support-summary.md)

**Description**: Extend founder-plan-agent to handle project-timeline report type. Add keyword detection for project/timeline/WBS/PERT/milestone/Gantt/deliverable. Add 5-phase project-timeline plan structure: Timeline Structure, PERT Calculations, Resource Allocation, Gantt Visualization, PDF Compilation. Depends on task 262 refactoring project-agent to produce research reports.

---

### 267. Add project support to founder-implement-agent
- **Effort**: 2.5 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Task #263, Task #266
- **Research**: [01_meta-research.md](267_project_implement_agent_support/reports/01_meta-research.md)
- **Plan**: [01_project-implement-support.md](267_project_implement_agent_support/plans/01_project-implement-support.md)
- **Summary**: [01_project-implement-support-summary.md](267_project_implement_agent_support/summaries/01_project-implement-support-summary.md)

**Description**: Move Typst timeline generation from project-agent to founder-implement-agent. Add project-timeline type detection and 5-phase flow: Timeline Structure & WBS Generation, PERT Calculations & Critical Path, Resource Allocation Matrix, Gantt Chart & Typst Visualization, PDF Compilation. Handle PLAN/TRACK/REPORT modes during implementation.

---

### 268. Update manifest.json routing table with per-type keys
- **Effort**: 30 min
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Task #264, Task #265, Task #266, Task #267
- **Research**: [01_meta-research.md](268_founder_manifest_routing/reports/01_meta-research.md)
- **Plan**: [01_manifest-routing.md](268_founder_manifest_routing/plans/01_manifest-routing.md)
- **Summary**: [01_manifest-routing-summary.md](268_founder_manifest_routing/summaries/01_manifest-routing-summary.md)

**Description**: Add per-type routing keys to manifest.json for plan and implement phases. Currently only research has per-type keys (founder:market, founder:analyze, etc.). Plan and implement use a single "founder" key. Add explicit keys for all 5 task types in plan and implement sections to enable proper routing.

---

### 269. Normalize skill consistency across founder extension
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Completed**: 2026-03-24
- **Language**: meta
- **Dependencies**: Task #263
- **Research**: [01_meta-research.md](269_founder_skill_consistency/reports/01_meta-research.md)
- **Plan**: [01_skill-consistency.md](269_founder_skill_consistency/plans/01_skill-consistency.md)
- **Summary**: [01_skill-consistency-summary.md](269_founder_skill_consistency/summaries/01_skill-consistency-summary.md)

**Description**: Fix inconsistencies between research skills and plan/implement skills: return format (JSON vs text), postflight marker format (JSON object vs string), cleanup completeness (.return-meta.json, .postflight-loop-guard), delegation_depth values. Align all 7 skills to a consistent pattern.

---

### 270. Update founder extension documentation for phased workflow
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Task #262, Task #263, Task #264, Task #265, Task #266, Task #267, Task #268, Task #269
- **Research**: [01_meta-research.md](270_founder_extension_documentation/reports/01_meta-research.md)
- **Plan**: [01_extension-documentation.md](270_founder_extension_documentation/plans/01_extension-documentation.md)
- **Summary**: [01_extension-documentation-summary.md](270_founder_extension_documentation/summaries/01_extension-documentation-summary.md)

**Description**: Update /project command, README.md, EXTENSION.md, and manifest documentation to reflect the new standard phased workflow for all commands. Document that all 5 task types (market, analyze, strategy, legal, project) follow /research -> /plan -> /implement lifecycle with proper per-type routing.

---

### 87. Investigate terminal directory change when opening neovim in wezterm
- **Effort**: TBD
- **Status**: [RESEARCHED]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Language**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](087_investigate_wezterm_terminal_directory_change/reports/research-001.md)

**Description**: Investigate why the terminal working directory changes to a project root when opening neovim sessions in wezterm from the home directory (~). Determine whether this behavior is caused by neovim or wezterm (configured in ~/.dotfiles/config/). Identify if any functionality depends on this behavior before modifying it. Goal is to avoid changing the terminal directory unless necessary.

---

### 78. Fix Himalaya SMTP authentication failure when sending emails
- **Effort**: 1-2 hours
- **Status**: [PLANNED]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Planning Started**: 2026-02-13
- **Planning Completed**: 2026-02-13
- **Language**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](078_fix_himalaya_smtp_authentication_failure/reports/research-001.md)
- **Plan**: [implementation-001.md](078_fix_himalaya_smtp_authentication_failure/plans/implementation-001.md)

**Description**: Fix Gmail SMTP authentication failure when sending emails via Himalaya (<leader>me). Error: "Authentication failed: Code: 535, Enhanced code: 5.7.8, Message: Username and Password not accepted". The error occurs with TLS connection attempts and persists through multiple retry attempts. Identify and fix the root cause of the SMTP credential configuration.

---

