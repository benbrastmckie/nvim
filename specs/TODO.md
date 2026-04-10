---
next_project_number: 394
---

# TODO

## Task Order

*Updated 2026-04-09. 10 active tasks remaining.*

### Pending

- **387** [COMPLETED] -- Create /budget command for present extension
- **388** [COMPLETED] -- Create /timeline command for present extension
- **389** [COMPLETED] -- Create /funds command for present extension
- **390** [COMPLETED] -- Create /talk command for present extension
- **391** [COMPLETED] -- Integrate new commands into present extension manifest (depends: 387-390)
- **384** [RESEARCHED] -- Improve /convert command-skill-agent pipeline in filetypes extension
- **382** [COMPLETED] -- Simplify /revise command with command + skill + agent architecture
- **383** [COMPLETED] -- Simplify /plan command, remove status gates, reference prior plan
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

### 393. Unify routing field: replace separate language and task_type with single extension:task_type format
- **Effort**: TBD
- **Status**: [NOT STARTED]
- **Language**: meta

**Description**: Instead of both 'language' and 'task-type' fields for tasks, use a single routing field in the form '{extension-or-language}:{task-type}'. Systematically study the .claude/ agent system, the extension system, and best practices to improve uniformity and consistency throughout.

### 392. Refactor present extension commands (/grant, /budget, /funds, /timeline, /talk)
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Language**: meta
- **Research**:
  - [01_refactor-present-commands.md](specs/392_refactor_present_extension_commands/reports/01_refactor-present-commands.md)
  - [02_team-research.md](specs/392_refactor_present_extension_commands/reports/02_team-research.md)
- **Plan**: [02_refactor-present-commands.md](specs/392_refactor_present_extension_commands/plans/02_refactor-present-commands.md)

**Description**: Make systematic changes to all present extension commands: /grant, /budget, /funds, /timeline, /talk. Research what each command currently does, identify what needs to change, then plan and implement a systematic refactor across all five commands.

---

### 391. Integrate new commands into present extension manifest
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Tasks 387, 388, 389, 390

**Description**: Integrate /budget, /timeline, /funds, /talk into present extension: update manifest.json routing, index-entries.json context entries, EXTENSION.md skill-agent table, README.md documentation.
- **Research**: [01_manifest-integration.md](391_integrate_new_commands_present_manifest/reports/01_manifest-integration.md)
- **Plan**: [01_manifest-integration-plan.md](391_integrate_new_commands_present_manifest/plans/01_manifest-integration-plan.md)

### 390. Create /talk command for present extension
- **Effort**: 3-5 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Research**: [01_talk-command-research.md](390_create_talk_command_present/reports/01_talk-command-research.md)
- **Plan**: [01_talk-command-plan.md](390_create_talk_command_present/plans/01_talk-command-plan.md)

**Description**: Create /talk command for research presentations via Slidev: conference talks, poster sessions, grant defense, research seminars, journal clubs. Adapts founder /deck command material synthesis and slide library for medical research presentations. Deliverables: command, skill (skill-talk), agent (talk-agent), context files (domain, patterns, templates for research presentations).

### 389. Create /funds command for present extension
- **Effort**: 3-5 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Research**: [01_funds-command-research.md](389_create_funds_command_present/reports/01_funds-command-research.md)
- **Plan**: [01_funds-command-plan.md](389_create_funds_command_present/plans/01_funds-command-plan.md)
- **Summary**: [01_funds-command-summary.md](389_create_funds_command_present/summaries/01_funds-command-summary.md)

**Description**: Create /funds command for funding landscape analysis: funder portfolio mapping, cost-effectiveness analysis, budget justification verification, funding gap analysis. Adapts founder /finance command audit/model/forecast modes for research funding. Deliverables: command, skill (skill-funds), agent (funds-agent), context files (domain, patterns, templates for funding analysis).

### 388. Create /timeline command for present extension
- **Effort**: 3-5 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Research**: [01_timeline-command-research.md](388_create_timeline_command_present/reports/01_timeline-command-research.md)
- **Plan**: [01_timeline-command-plan.md](388_create_timeline_command_present/plans/01_timeline-command-plan.md)

**Description**: Create /timeline command for research project timelines: specific aims schedules, regulatory milestones (IRB, IACUC), reporting periods, no-cost extensions. Adapts founder /project command WBS/PERT/Gantt for medical research. Deliverables: command, skill (skill-timeline), agent (timeline-agent), context files (domain, patterns, templates for research timelines).

### 387. Create /budget command for present extension
- **Effort**: 3-5 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Research**: [01_budget-command-research.md](387_create_budget_command_present/reports/01_budget-command-research.md)
- **Plan**: [01_budget-command-plan.md](387_create_budget_command_present/plans/01_budget-command-plan.md)
- **Summary**: [01_budget-command-summary.md](387_create_budget_command_present/summaries/01_budget-command-summary.md)

**Description**: Create /budget command for grant budget spreadsheets: NIH modular/detailed formats, NSF budgets, F&A rates, cost-sharing, sub-awards, personnel effort. Adapts founder /sheet command forcing questions and XLSX generation for medical research grant budgets. Deliverables: command, skill (skill-budget), agent (budget-agent), context files (domain, patterns, templates for grant budgets).

### 386. Expand filetypes extension with SuperDoc MCP integration and partner Office workflows
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Language**: meta
- **Research**:
  - [01_team-research.md](specs/386_expand_filetypes_superdoc_integration/reports/01_team-research.md)
  - [02_word-reload-workflow.md](specs/386_expand_filetypes_superdoc_integration/reports/02_word-reload-workflow.md)
  - [03_optimal-extension-design.md](specs/386_expand_filetypes_superdoc_integration/reports/03_optimal-extension-design.md)
- **Plan**: [01_extension-implementation.md](specs/386_expand_filetypes_superdoc_integration/plans/01_extension-implementation.md)
- **Summary**: [03_implementation-summary.md](specs/386_expand_filetypes_superdoc_integration/summaries/03_implementation-summary.md)

**Description**: Expand filetypes extension with SuperDoc MCP integration and partner Office workflows: add skill-docx-edit + docx-edit-agent for in-place DOCX editing with tracked changes via SuperDoc MCP, add skill-xlsx-edit for spreadsheet editing via openpyxl MCP, update manifest.json with new MCP server declarations and routing entries, update conversion-tables.md and mcp-integration.md context files, create docx-editing patterns context file, and add SharePoint/OneDrive workflow patterns. Build on research from task 385 (reports 01_team-research.md and 02_superdoc-workflows.md which detail SuperDoc tool inventory, 5 workflows, and integration architecture).

---

### 385. Research Zed IDE installation plan for partner's laptop
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Language**: general
- **Research**:
  - [01_team-research.md](specs/385_research_zed_ide_installation/reports/01_team-research.md)
  - [02_superdoc-workflows.md](specs/385_research_zed_ide_installation/reports/02_superdoc-workflows.md)
- **Plan**: [01_zed-installation-guide.md](specs/385_research_zed_ide_installation/plans/01_zed-installation-guide.md)
- **Summary**: [02_zed-guide-summary.md](specs/385_research_zed_ide_installation/summaries/02_zed-guide-summary.md)

**Description**: Research Zed IDE as a VSCode replacement for partner's laptop: evaluate integration with Claude Code, OpenCode, and Codex; assess MS Office workflow options including Zed limitations, Claude Code Office file editing, and companion apps (LibreOffice, OnlyOffice); determine OS-specific installation steps; compare extension ecosystem gaps vs VSCode; produce installation recommendation with prerequisites and configuration steps.

---

### 384. Improve /convert command-skill-agent pipeline in filetypes extension
- **Effort**: TBD
- **Status**: [RESEARCHED]
- **Language**: meta
- **Research**: [01_convert-pipeline-analysis.md](specs/384_improve_convert_command_skill_agent/reports/01_convert-pipeline-analysis.md)

**Description**: Improve the /convert command-skill-agent according to best practices while conforming to current .claude/ patterns. The markitdown pipeline is currently broken (bad Python interpreter); pymupdf text extraction works and is the recommended extraction tool. Refactor the filetypes/ extension's convert pipeline to use pymupdf as the primary extraction backend, fix or replace the broken markitdown integration, and ensure the command-skill-agent architecture follows established .claude/ conventions.

---

### 382. Simplify /revise command with command + skill + agent architecture
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_simplify-revise-command.md](382_simplify_revise_command/reports/01_simplify-revise-command.md)
- **Plan**: [01_simplify-revise-command.md](382_simplify_revise_command/plans/01_simplify-revise-command.md)

**Description**: Refactor the /revise command to use a full command + skill + agent architecture (matching /plan's structure). Remove all status-based ABORT rules so /revise always works regardless of task state. The reviser-agent should: (1) find and load the existing plan if one exists, (2) discover all research reports created since the plan was last modified, (3) synthesize the best of the prior plan with new research findings into a revised plan, (4) revise the task description if appropriate. If no plan exists, revise the description only. Files: .claude/commands/revise.md, .claude/skills/skill-reviser/SKILL.md, new .claude/agents/reviser-agent.md.

---

### 383. Simplify /plan command, remove status gates, reference prior plan
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_simplify-plan-command.md](383_simplify_plan_command/reports/01_simplify-plan-command.md)
- **Plan**: [01_simplify-plan-command.md](383_simplify_plan_command/plans/01_simplify-plan-command.md)

**Description**: Simplify the /plan command to always create a fresh plan from any task state (remove status restrictions). When a prior plan exists, pass it to the planner-agent as reference context so it can learn from what worked/didn't, but always create a clean start. Follow research more closely than the prior plan when both exist. If no prior plan exists, only research informs the new plan. Files: .claude/commands/plan.md, .claude/skills/skill-planner/SKILL.md, .claude/agents/planner-agent.md.

---

### 87. Investigate terminal directory change when opening neovim in wezterm
 **Effort**: TBD
 **Status**: [RESEARCHED]
 **Research Started**: 2026-02-13
 **Research Completed**: 2026-02-13
 **Language**: neovim
 **Dependencies**: None
 **Research**: [research-001.md](087_investigate_wezterm_terminal_directory_change/reports/research-001.md)

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

## Recommended Order

1. **385** [RESEARCHED] -> plan (independent)
*No pending implementation tasks.*
