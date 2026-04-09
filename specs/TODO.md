---
next_project_number: 384
---

# TODO

## Task Order

*Updated 2026-04-08. 4 active tasks remaining.*

### Pending

- **382** [PLANNED] -- Simplify /revise command with command + skill + agent architecture
- **383** [PLANNED] -- Simplify /plan command, remove status gates, reference prior plan
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

### 382. Simplify /revise command with command + skill + agent architecture
- **Effort**: TBD
- **Status**: [PLANNED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_simplify-revise-command.md](382_simplify_revise_command/reports/01_simplify-revise-command.md)
- **Plan**: [01_simplify-revise-command.md](382_simplify_revise_command/plans/01_simplify-revise-command.md)

**Description**: Refactor the /revise command to use a full command + skill + agent architecture (matching /plan's structure). Remove all status-based ABORT rules so /revise always works regardless of task state. The reviser-agent should: (1) find and load the existing plan if one exists, (2) discover all research reports created since the plan was last modified, (3) synthesize the best of the prior plan with new research findings into a revised plan, (4) revise the task description if appropriate. If no plan exists, revise the description only. Files: .claude/commands/revise.md, .claude/skills/skill-reviser/SKILL.md, new .claude/agents/reviser-agent.md.

---

### 383. Simplify /plan command, remove status gates, reference prior plan
- **Effort**: TBD
- **Status**: [PLANNED]
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

*No pending implementation tasks.*
