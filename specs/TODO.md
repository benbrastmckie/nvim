---
next_project_number: 333
---

# TODO

## Task Order

*Updated 2026-03-31. 11 active tasks remaining.*

### Pending

- **330** [IMPLEMENTING] -- Create /finance command, skill, and agent
  - **Research**: [01_finance-command-research.md](330_create_finance_command_skill_agent/reports/01_finance-command-research.md)
  - **Plan**: [01_finance-command-plan.md](330_create_finance_command_skill_agent/plans/01_finance-command-plan.md)
- **331** [COMPLETED] -- Create finance context and templates
  - **Research**: [01_finance-context-research.md](331_create_finance_context_templates/reports/01_finance-context-research.md)
  - **Plan**: [01_finance-context-plan.md](331_create_finance_context_templates/plans/01_finance-context-plan.md)
  - **Summary**: [01_finance-context-summary.md](331_create_finance_context_templates/summaries/01_finance-context-summary.md)
- **332** [NOT STARTED] -- Integrate finance into founder extension (depends on 330, 331)
- **327** [COMPLETED] -- Pass task_type through founder delegation pipeline
- **328** [COMPLETED] -- Make Typst primary output in founder plan agent (depends on 327)
- **329** [COMPLETED] -- Make Typst primary output in founder implement agent (depends on 327)
  - **Summary**: [01_typst-primary-implement-summary.md](329_typst_primary_in_implement_agent/summaries/01_typst-primary-implement-summary.md)
- **326** [COMPLETED] -- Upgrade agent system for Claude Code v2.1.88+ compatibility
- **323** [COMPLETED] -- Fix jq query duplicates in agent context loading
- **324** [COMPLETED] -- Remove /plan from founder index entries
- **325** [COMPLETED] -- Audit all index.json command assignments (depends on 324)
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

### Completed (Ready for Archive)

- **322** [COMPLETED] -- Add REVIEW mode to /project command

## Tasks

### 332. Integrate finance into founder extension
- **Effort**: 1-2 hours
- **Status**: [NOT STARTED]
- **Language**: meta
- **Dependencies**: 330, 331
- **Created**: 2026-03-31

**Description**: Wire /finance into the founder extension: add finance-agent, skill-finance, and /finance command to manifest.json routing tables. Add context entries to index-entries.json. Update EXTENSION.md documentation. Optionally add financial-analysis.typ Typst template.

**Files to modify**:
- `.claude/extensions/founder/manifest.json` -- Add routing entries
- `.claude/extensions/founder/index-entries.json` -- Add context discovery entries
- `.claude/extensions/founder/EXTENSION.md` -- Add /finance documentation

---

### 331. Create finance context and templates
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Created**: 2026-03-31
- **Completed**: 2026-03-30
- **Research**: [01_finance-context-research.md](specs/331_create_finance_context_templates/reports/01_finance-context-research.md)
- **Plan**: [01_finance-context-plan.md](specs/331_create_finance_context_templates/plans/01_finance-context-plan.md)
- **Summary**: [01_finance-context-summary.md](specs/331_create_finance_context_templates/summaries/01_finance-context-summary.md)

**Description**: Create context files for the finance feature: domain/financial-analysis.md (frameworks for document analysis, verification methodology, spreadsheet validation patterns), patterns/financial-forcing-questions.md (question framework for financial document review), and templates/financial-analysis.md (report template for finance research output).

**Completion Summary**: Created 3 finance context files: domain/financial-analysis.md (241 lines, statement analysis, ratios, verification methodology), patterns/financial-forcing-questions.md (361 lines, 6 forcing questions with 4 modes), templates/financial-analysis.md (331 lines, report template with verification tables and scenario analysis).

---

### 330. Create /finance command, skill, and agent
- **Effort**: 3-4 hours
- **Status**: [IMPLEMENTING]
- **Language**: meta
- **Dependencies**: None
- **Created**: 2026-03-31
- **Research**: [01_finance-command-research.md](specs/330_create_finance_command_skill_agent/reports/01_finance-command-research.md)
- **Plan**: [01_finance-command-plan.md](specs/330_create_finance_command_skill_agent/plans/01_finance-command-plan.md)

**Description**: Create the /finance command (finance.md), research skill (skill-finance/SKILL.md), and research agent (finance-agent.md) for the founder extension. The command uses AUDIT/MODEL/FORECAST/VALIDATE modes with 5 forcing questions (mode, document scope, primary concern, time horizon, accuracy requirement). The skill follows the standard 11-stage execution pattern. The agent analyzes existing financial documents, extracts numbers, and creates verification spreadsheets (.xlsx with formulas) to confirm/improve calculations. Distinct from /sheet which creates cost breakdowns from scratch -- /finance works with existing documents containing financial data.

**Files to create**:
- `.claude/extensions/founder/commands/finance.md`
- `.claude/extensions/founder/skills/skill-finance/SKILL.md`
- `.claude/extensions/founder/agents/finance-agent.md`

---

### 329. Make Typst primary output in founder implement agent
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: 327
- **Created**: 2026-03-31
- **Completed**: 2026-03-30
- **Research**: [01_typst-primary-implement.md](specs/329_typst_primary_in_implement_agent/reports/01_typst-primary-implement.md)
- **Plan**: [01_typst-primary-implement.md](specs/329_typst_primary_in_implement_agent/plans/01_typst-primary-implement.md)
- **Summary**: [01_typst-primary-implement-summary.md](specs/329_typst_primary_in_implement_agent/summaries/01_typst-primary-implement-summary.md)

**Description**: Update founder-implement-agent Phase 4 to generate .typ files directly for ALL report types (like project-timeline already does), and Phase 5 to compile PDF. Currently Phase 4 writes markdown for non-project-timeline types and Phase 5 generates Typst as optional add-on. All founder types should follow the project-timeline pattern: Typst as primary output, markdown as fallback.

**Completion Summary**: Updated founder-implement-agent.md supporting sections (summary template, metadata template, return text summary, critical requirements) to consistently list Typst as primary output. Core Phase 4/5 and per-type sections were already updated by task 328.

---

### 328. Make Typst primary output in founder plan agent
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: 327
- **Created**: 2026-03-31
- **Completed**: 2026-03-30
- **Research**: [01_typst-primary-plan.md](specs/328_typst_primary_in_plan_agent/reports/01_typst-primary-plan.md)
- **Plan**: [01_typst-primary-plan.md](specs/328_typst_primary_in_plan_agent/plans/01_typst-primary-plan.md)
- **Summary**: [01_typst-primary-plan-summary.md](specs/328_typst_primary_in_plan_agent/summaries/01_typst-primary-plan-summary.md)

**Description**: Update founder-plan-agent so Phase 4 plans Typst as primary output for ALL founder types (not just project-timeline), and Phase 5 plans PDF compilation. Currently only project-timeline outputs Typst directly; all other types plan markdown as primary with Typst as optional Phase 5. The plan template's Phase 4 tasks, output paths, and artifacts section all need updating.

**Files to modify**:
- `.claude/extensions/founder/agents/founder-plan-agent.md` -- Phase 4/5 templates for all report types

---

### 327. Pass task_type through founder delegation pipeline
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Created**: 2026-03-31
- **Completed**: 2026-03-30
- **Summary**: [01_delegation-pipeline-fix-summary.md](specs/327_pass_task_type_through_delegation/summaries/01_delegation-pipeline-fix-summary.md)

**Description**: Update skill-founder-plan and skill-founder-implement to extract task_type from state.json and include it in the task_context passed to agents. Currently commands store task_type (e.g., "project", "market", "strategy") in state.json but both skills omit it from the delegation context, forcing agents to infer report type from keyword matching on research content.

**Files to modify**:
- `.claude/extensions/founder/skills/skill-founder-plan/SKILL.md` -- Add task_type to context preparation (Stage 4)
- `.claude/extensions/founder/skills/skill-founder-implement/SKILL.md` -- Add task_type to context preparation (Stage 4)

---

### 326. Upgrade agent system for Claude Code v2.1.88+ compatibility
- **Effort**: 2-4 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Created**: 2026-03-30
- **Description**: Migrate agent system to work with Claude Code v2.1.88+. Commands in .claude/commands/ are not loading (no autocomplete or invocation). Root causes: (1) stale model IDs in frontmatter (claude-opus-4-5-20251101 no longer valid), (2) commands-to-skills unification may require format changes, (3) SlashCommand tool replaced by Skill tool, (4) description budget constraints. Scope: update all 14 command files, verify 15 skill files, update model references in agents, test autocomplete and invocation.
- **Report**: [01_command-loading-fix.md](specs/326_upgrade_agent_system_for_claude_code_v2/reports/01_command-loading-fix.md)
- **Plan**: [01_implementation-plan.md](specs/326_upgrade_agent_system_for_claude_code_v2/plans/01_implementation-plan.md)
- **Summary**: [01_execution-summary.md](specs/326_upgrade_agent_system_for_claude_code_v2/summaries/01_execution-summary.md)

### 325. Audit all index.json command assignments
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: 324
- **Created**: 2026-03-30

**Description**: Full audit of all 181 index.json entries to ensure commands are appropriately scoped to their domains. Verify no domain-specific files have generic commands like /plan, /implement, /research. Create validation script to detect future regressions.

---

### 324. Remove /plan from founder index entries
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Created**: 2026-03-30

**Description**: Remove generic commands (/plan, /implement) from 15+ founder domain files in index.json. These files should only match when task language='founder', not for all planning/implementation tasks. Currently causes 15+ irrelevant founder files to load for every /plan command.

---

### 323. Fix jq query duplicates in agent context loading
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Created**: 2026-03-30

**Description**: Fix jq query in planner-agent.md (line 57-64) and other agents to use `any()` function instead of `[]?` with OR. Current query causes duplicate results when entries match multiple conditions (e.g., both commands and agents match). Example: forcing-questions.md appears 6 times because it matches `/plan` command AND `founder-plan-agent` agent. Query returns 87 files with 34 duplicates instead of 53 unique files.

---

### 322. Add REVIEW mode to /project command for timeline analysis
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Started**: 2026-03-30
- **Research Completed**: 2026-03-30
- **Planning Completed**: 2026-03-30
- **Implementation Completed**: 2026-03-30
- **Research**: [01_review-mode-design.md](322_add_review_mode_to_project_command/reports/01_review-mode-design.md)
- **Plan**: [01_implementation-plan.md](322_add_review_mode_to_project_command/plans/01_implementation-plan.md)
- **Summary**: [01_execution-summary.md](322_add_review_mode_to_project_command/summaries/01_execution-summary.md)

**Description**: Add a fourth REVIEW mode to the `/project` command that critically analyzes project timelines for gaps, issues, weaknesses, and improvement opportunities. Must support both external timeline files (e.g., `.typ`, `.md`) and existing task artifacts (research/plan reports). Analysis should cover: timeline gaps, feasibility issues, risk weaknesses, resource concerns, critical path vulnerabilities, missing dependencies, and unrealistic estimates. Update `project.md` command, `project-agent.md` agent, and create review-specific context/criteria as needed.

**Completion Summary**: Added REVIEW mode to /project command with 5 forcing questions (primary concern, changed constraints, validity window, risk tolerance, review depth), 7-category analysis framework with 30+ detection rules, 4-tier severity system (Critical/High/Medium/Low), and comprehensive review report generation. Modified project.md (+120 lines) and project-agent.md (+295 lines).

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
