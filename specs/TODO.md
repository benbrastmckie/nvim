---
next_project_number: 386
---

# TODO

## Task Order

*Updated 2026-04-09. 5 active tasks remaining.*

### Pending

- **384** [RESEARCHED] -- Improve /convert command-skill-agent pipeline in filetypes extension
- **382** [COMPLETED] -- Simplify /revise command with command + skill + agent architecture
- **383** [COMPLETED] -- Simplify /plan command, remove status gates, reference prior plan
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

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
