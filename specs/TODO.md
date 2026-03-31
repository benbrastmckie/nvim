---
next_project_number: 333
---

# TODO

## Task Order

*Updated 2026-03-31. 4 active tasks remaining.*

### Pending

- **330** [IMPLEMENTING] -- Create /finance command, skill, and agent
  - **Research**: [01_finance-command-research.md](330_create_finance_command_skill_agent/reports/01_finance-command-research.md)
  - **Plan**: [01_finance-command-plan.md](330_create_finance_command_skill_agent/plans/01_finance-command-plan.md)
- **332** [NOT STARTED] -- Integrate finance into founder extension (depends on 330, 331)
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

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
